#!/usr/bin/env bash
# tests/test-enumerate-plugin-layout.sh — #825: the enabled set and the plugin
# paths as Claude Code writes them. enabledPlugins is an object map
# (`"plugin@marketplace": true`), plugins live in cache/<marketplace>/<plugin>/
# <version>/, and installed_plugins.json records where. Every fixture is written
# by hand into a temp HOME; nothing here reads the host's real install.
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/redact.sh"
source "$CSA_LIB_DIR/fingerprint.sh"
source "$CSA_LIB_DIR/enumerate-targets.sh"

_csa_failed=0
_T="$(mktemp -d "${TMPDIR:-/tmp}/csa-layout.XXXXXX")"
trap 'rm -rf "$_T"' EXIT
_n=0

# _mk <name> — fresh HOME ($_H) and project ($_P) for one test.
_mk() {
  _n=$((_n + 1))
  _H="$_T/$_n/home"; _P="$_T/$_n/project"
  mkdir -p "$_H/.claude/plugins/cache" "$_P/.claude"
}

# _install <key-dir-path-under-cache> <file> — a plugin version dir with one file.
_install() { # $1 = marketplace/plugin/version, $2 = file name
  mkdir -p "$_H/.claude/plugins/cache/$1"
  printf '# %s\n' "$2" > "$_H/.claude/plugins/cache/$1/$2"
}

_enabled() { HOME="$_H" csa_enum_enabled_plugins "$_P" 2>/dev/null; }

# --- 1. the enabled set -------------------------------------------------------

test_object_map_true_keys_only() {
  _mk
  printf '%s\n' '{"enabledPlugins":{"a@m":true,"b@m":false,"c@m":"yes","d@m":1,"e@m":null,"f@m":{"x":true}}}' > "$_H/.claude/settings.json"
  local out; out="$(_enabled)"
  assert_eq "a@m" "$out" "only the boolean true key is enabled; false and non-boolean values are not"
}

test_array_form_still_reads() {
  _mk
  printf '%s\n' '{"enabledPlugins":["p1","p2",7,null]}' > "$_P/.claude/settings.json"
  assert_eq $'p1\np2' "$(_enabled)" "array of names; non-strings ignored"
}

test_both_shapes_across_two_files_later_file_wins() {
  _mk
  printf '%s\n' '{"enabledPlugins":["u@m","keep@m"]}' > "$_H/.claude/settings.json"
  printf '%s\n' '{"enabledPlugins":{"u@m":false,"p@m":true}}' > "$_P/.claude/settings.json"
  assert_eq $'keep@m\np@m' "$(_enabled)" "a project false disables the user's array-form true" || return 1
  # Adjacent control: the same two files with the order of authority reversed.
  printf '%s\n' '{"enabledPlugins":{"u@m":false}}' > "$_H/.claude/settings.json"
  printf '%s\n' '{"enabledPlugins":["u@m"]}' > "$_P/.claude/settings.json"
  assert_eq "u@m" "$(_enabled)" "a project true enables what the user disabled"
}

test_local_settings_is_read_and_wins() {
  _mk
  printf '%s\n' '{"enabledPlugins":{"u@m":true,"w@m":false}}' > "$_H/.claude/settings.json"
  printf '%s\n' '{"enabledPlugins":{"u@m":false,"p@m":true}}' > "$_P/.claude/settings.json"
  printf '%s\n' '{"enabledPlugins":{"u@m":true,"p@m":false,"w@m":true}}' > "$_P/.claude/settings.local.json"
  assert_eq $'u@m\nw@m' "$(_enabled)" "user, then project, then settings.local.json: the last writer of each key wins" || return 1
  rm -f "$_P/.claude/settings.local.json"
  assert_eq "p@m" "$(_enabled)" "without the local file the project's values stand"
}

test_unrecognized_shape_warns_and_is_empty() {
  _mk
  local err rc=0
  printf '%s\n' '{"enabledPlugins":"everything"}' > "$_P/.claude/settings.json"
  err="$(HOME="$_H" csa_enum_enabled_plugins "$_P" 2>&1 >/dev/null)" || rc=1
  assert_contains "$err" "unrecognized shape (string)" "a string value warns, naming the shape" || rc=1
  assert_contains "$err" "$_P/.claude/settings.json" "the warning names the file" || rc=1
  printf '%s\n' '{"enabledPlugins":[1,2]}' > "$_P/.claude/settings.json"
  err="$(HOME="$_H" csa_enum_enabled_plugins "$_P" 2>&1 >/dev/null)" || rc=1
  assert_contains "$err" "unrecognized shape (array)" "an array with no strings warns" || rc=1
  printf '%s\n' '{"enabledPlugins":{"a@m":"on"}}' > "$_P/.claude/settings.json"
  err="$(HOME="$_H" csa_enum_enabled_plugins "$_P" 2>&1 >/dev/null)" || rc=1
  assert_contains "$err" "unrecognized shape (object)" "an object with no boolean value warns" || rc=1
  # Adjacent controls: these empty sets are legitimate and stay quiet.
  local quiet
  for quiet in '{"enabledPlugins":{"a@m":false}}' '{"enabledPlugins":[]}' '{"enabledPlugins":{}}' '{}' '{ not json'; do
    printf '%s\n' "$quiet" > "$_P/.claude/settings.json"
    err="$(HOME="$_H" csa_enum_enabled_plugins "$_P" 2>&1 >/dev/null)" || rc=1
    assert_eq "" "$err" "no warning for $quiet" || rc=1
  done
  return "$rc"
}

# --- 2. resolving a path ------------------------------------------------------

_record() { # $1 = JSON body of .plugins
  printf '{"version":2,"plugins":%s}\n' "$1" > "$_H/.claude/plugins/installed_plugins.json"
}

test_record_picks_the_recorded_version_over_the_newest() {
  _mk
  _install m/p/1.0.0 a.sh; _install m/p/2.0.0 a.sh
  _record '{"p@m":[{"scope":"user","installPath":"'"$_H"'/.claude/plugins/cache/m/p/1.0.0","version":"1.0.0"}]}'
  local out rc=0
  out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_P")" || rc=$?
  assert_eq "0" "$rc" "resolves" || return 1
  assert_eq "$_H/.claude/plugins/cache/m/p/1.0.0" "$out" "the recorded path, not a derived one"
}

test_record_scope_precedence_and_other_projects() {
  _mk
  local c="$_H/.claude/plugins/cache/m/p" out
  _install m/p/1.0.0 a.sh; _install m/p/2.0.0 a.sh; _install m/p/3.0.0 a.sh
  mkdir -p "$_T/$_n/other"
  _record '{"p@m":[
    {"scope":"user","installPath":"'"$c"'/1.0.0"},
    {"scope":"project","projectPath":"'"$_T/$_n/other"'","installPath":"'"$c"'/3.0.0"},
    {"scope":"project","projectPath":"'"$_P"'","installPath":"'"$c"'/2.0.0"}]}'
  out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_P")"
  assert_eq "$c/2.0.0" "$out" "this project's entry beats the user's; another project's is ignored" || return 1
  out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_T/$_n/other")"
  assert_eq "$c/3.0.0" "$out" "the other project gets its own entry" || return 1
  out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_T/$_n")"
  assert_eq "$c/1.0.0" "$out" "a project with no entry gets the user entry" || return 1
  _record '{"p@m":[
    {"scope":"project","projectPath":"'"$_P"'","installPath":"'"$c"'/2.0.0"},
    {"scope":"local","projectPath":"'"$_P"'","installPath":"'"$c"'/3.0.0"}]}'
  out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_P")"
  assert_eq "$c/3.0.0" "$out" "local beats project" || return 1
  # A trailing slash and a symlinked spelling of the project compare equal.
  ln -s "$_P" "$_T/$_n/link"
  _record '{"p@m":[{"scope":"project","projectPath":"'"$_T/$_n/link/"'","installPath":"'"$c"'/2.0.0"}]}'
  out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_P")"
  assert_eq "$c/2.0.0" "$out" "physical paths are compared"
}

test_record_entry_for_another_project_only_falls_back_to_cache() {
  _mk
  _install m/p/1.0.0 a.sh
  mkdir -p "$_T/$_n/other"
  _record '{"p@m":[{"scope":"project","projectPath":"'"$_T/$_n/other"'","installPath":"/etc"}]}'
  local out rc=0
  out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_P")" || rc=$?
  assert_eq "0" "$rc" "another project's entry is not this project's record" || return 1
  assert_eq "$_H/.claude/plugins/cache/m/p/1.0.0" "$out" "the one-version cache fallback"
}

test_install_path_guard() {
  _mk
  local rc=0 out
  _install m/p/1.0.0 a.sh
  mkdir -p "$_T/$_n/outside" "$_T/$_n/home/.claude/plugins/cache/m/q"
  printf 'x\n' > "$_T/$_n/outside/e.sh"
  ln -s "$_T/$_n/outside" "$_H/.claude/plugins/cache/m/q/9.9.9"
  : > "$_H/.claude/plugins/cache/m/file"
  local bad
  for bad in "$_T/$_n/outside" \
             "$_H/.claude/plugins/../../outside" \
             "$_H/.claude/plugins/cache/m/p/1.0.0/../../../../../outside" \
             "$_H/.claude/plugins/cache/m/q/9.9.9" \
             "$_H/.claude/plugins" \
             "$_H/.claude/plugins/cache/m/file" \
             "$_H/.claude/plugins/cache/m/missing" \
             "cache/m/p/1.0.0" \
             "/etc"; do
    _record '{"p@m":[{"scope":"user","installPath":"'"$bad"'"}]}'
    out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_P")"
    local grc=$?
    if [[ "$grc" -ne 1 ]]; then
      printf '    installPath %s: rc %s, wanted 1 (printed %s)\n' "$bad" "$grc" "$out" >&2
      rc=1
    fi
    assert_contains "$out" "installPath" "reason for $bad names the installPath" || rc=1
  done
  # The guard's refusal must not fall through to the cache path and succeed.
  _record '{"p@m":[{"scope":"user","installPath":"/etc"}]}'
  out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_P")" && { printf '    /etc resolved: %s\n' "$out" >&2; rc=1; }
  # Adjacent control: an installPath that does resolve inside the tree passes.
  _record '{"p@m":[{"scope":"user","installPath":"'"$_H"'/.claude/plugins/cache/m/../m/p/1.0.0"}]}'
  out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_P")" || { printf '    inside path refused: %s\n' "$out" >&2; rc=1; }
  assert_eq "$_H/.claude/plugins/cache/m/p/1.0.0" "$out" "an inside path is returned normalised" || rc=1
  return "$rc"
}

test_name_with_slash_or_dotdot_is_refused() {
  _mk
  local rc=0 out grc key
  # If the refusal were absent these keys would resolve to real directories
  # inside the tree: plugins/p/1.0.0 and plugins/cache/m/p/1.0.0.
  mkdir -p "$_H/.claude/plugins/p/1.0.0" "$_H/.claude/plugins/cache/m/p/1.0.0"
  printf 'x\n' > "$_H/.claude/plugins/p/1.0.0/a.sh"
  # Slash-only keys (no `..`) that would resolve inside the tree if `/` were allowed.
  mkdir -p "$_H/.claude/plugins/cache/m/r/s/1.0.0" "$_H/.claude/plugins/cache/m/u/t/1.0.0" "$_H/.claude/plugins/cache/r/s/1.0.0" "$_H/.claude/plugins/cache/p/1.0.0"
  for key in 'r/s@m' 't@m/u' 'r/s' 'p@..' '..@m' 'p@m/../m' 'p/../p@m' 'a/b@m' 'p@m/x' '../p' 'p/x' '..' '.' 'p@.' '@m' 'p@' '...@m' 'p..x@m'; do
    out="$(HOME="$_H" csa_enum_resolve_plugin_path "$key" "$_P")"; grc=$?
    if [[ "$grc" -ne 1 ]]; then
      printf '    key %q: rc %s, wanted 1 (printed %s)\n' "$key" "$grc" "$out" >&2
      rc=1
    fi
  done
  # Adjacent control: the plain keys do resolve.
  out="$(HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_P")" || { printf '    p@m refused\n' >&2; rc=1; }
  assert_eq "$_H/.claude/plugins/cache/m/p/1.0.0" "$out" "p@m resolves" || rc=1
  return "$rc"
}

test_bare_name_logic_and_local_dir() {
  _mk
  local out
  mkdir -p "$_H/.claude/plugins/cache/flat/1.0.0" "$_H/.claude/plugins/cache/act/1.0.0" "$_H/.claude/plugins/cache/act/2.0.0" "$_H/.claude/plugins/local/dev"
  printf '2.0.0' > "$_H/.claude/plugins/cache/act/.active"
  out="$(HOME="$_H" csa_enum_resolve_plugin_path flat "$_P")"
  assert_eq "$_H/.claude/plugins/cache/flat/1.0.0" "$out" "single version" || return 1
  out="$(HOME="$_H" csa_enum_resolve_plugin_path act "$_P")"
  assert_eq "$_H/.claude/plugins/cache/act/2.0.0" "$out" ".active names the version" || return 1
  out="$(HOME="$_H" csa_enum_resolve_plugin_path dev "$_P")"
  assert_eq "$_H/.claude/plugins/local/dev" "$out" "local-dev directory" || return 1
  mkdir -p "$_H/.claude/plugins/cache/two/1.0.0" "$_H/.claude/plugins/cache/two/2.0.0"
  if out="$(HOME="$_H" csa_enum_resolve_plugin_path two "$_P")"; then
    printf '    two versions and no .active resolved: %s\n' "$out" >&2; return 1
  fi
}

test_unreadable_or_malformed_record_is_rc2_absent_is_not() {
  _mk
  _install m/p/1.0.0 a.sh
  printf '%s\n' '{"enabledPlugins":{"p@m":true}}' > "$_H/.claude/settings.json"
  local rc=0 body
  # Absent: the cache fallback works.
  HOME="$_H" csa_enum_targets_all "$_P" >/dev/null 2>&1 || { printf '    absent record failed the scan\n' >&2; rc=1; }
  for body in '{ not json' '[]' '{"plugins":[]}' '{"version":2}' '{"plugins":{"p@m":"x"}}' ''; do
    printf '%s\n' "$body" > "$_H/.claude/plugins/installed_plugins.json"
    local trc=0 prc=0 rrc=0 out
    out="$(HOME="$_H" csa_enum_targets_all "$_P" 2>/dev/null)" || trc=$?
    HOME="$_H" CSA_PROJECT_ROOT="$_P" csa_enum_paranoid_candidates >/dev/null 2>&1 || prc=$?
    HOME="$_H" csa_enum_resolve_plugin_path "p@m" "$_P" >/dev/null 2>&1 || rrc=$?
    assert_eq "2" "$trc" "record '$body': targets_all rc 2" || rc=1
    assert_eq "2" "$prc" "record '$body': paranoid rc 2" || rc=1
    assert_eq "2" "$rrc" "record '$body': resolve rc 2" || rc=1
    [[ "$out" != *"@plugin:"* ]] || { printf '    record %q: scan emitted plugin targets\n' "$body" >&2; rc=1; }
  done
  # A record that is a directory.
  rm -f "$_H/.claude/plugins/installed_plugins.json"; mkdir "$_H/.claude/plugins/installed_plugins.json"
  trc=0; HOME="$_H" csa_enum_targets_all "$_P" >/dev/null 2>&1 || trc=$?
  assert_eq "2" "$trc" "record is a directory: rc 2" || rc=1
  return "$rc"
}

# --- 3. targets on the real layout --------------------------------------------

test_targets_all_real_layout() {
  _mk
  _install mk/alpha/1.0.0 a.sh; _install mk/alpha/0.9.0 old.sh; _install mk/beta/2.0.0 b.sh
  _install mk/off/1.0.0 off.sh
  _record '{"alpha@mk":[{"scope":"user","installPath":"'"$_H"'/.claude/plugins/cache/mk/alpha/1.0.0"}],
            "beta@mk":[{"scope":"user","installPath":"'"$_H"'/.claude/plugins/cache/mk/beta/2.0.0"}]}'
  printf '%s\n' '{"enabledPlugins":{"alpha@mk":true,"beta@mk":true,"off@mk":false,"gone@mk":true}}' > "$_H/.claude/settings.json"
  local out err
  out="$(HOME="$_H" csa_enum_targets_all "$_P" 2>"$_T/err")"; err="$(<"$_T/err")"
  assert_contains "$out" "@plugin:alpha@mk:a.sh"$'\t'"$_H/.claude/plugins/cache/mk/alpha/1.0.0/a.sh" "label carries the whole key" || return 1
  assert_contains "$out" "@plugin:beta@mk:b.sh" "second plugin" || return 1
  [[ "$out" != *old.sh* ]] || { printf '    an unrecorded old version was scanned\n' >&2; return 1; }
  [[ "$out" != *off.sh* ]] || { printf '    a false plugin was scanned\n' >&2; return 1; }
  assert_contains "$err" "PROVENANCE-002 plugin gone@mk enabled but not installed" "unresolved plugin is named by its whole key" || return 1
  [[ "$err" != *alpha* ]] || { printf '    alpha reported: %s\n' "$err" >&2; return 1; }
}

test_same_plugin_name_in_two_marketplaces_stays_distinct() {
  _mk
  _install m1/dup/1.0.0 one.sh; _install m2/dup/1.0.0 two.sh
  printf '%s\n' '{"enabledPlugins":{"dup@m1":true,"dup@m2":true}}' > "$_P/.claude/settings.json"
  local out; out="$(HOME="$_H" csa_enum_targets_all "$_P" 2>/dev/null)"
  assert_contains "$out" "@plugin:dup@m1:one.sh" "first marketplace" || return 1
  assert_contains "$out" "@plugin:dup@m2:two.sh" "second marketplace"
}

test_targets_all_rc2_is_not_swallowed_by_the_output_pipeline() {
  _mk
  _install m/p/1.0.0 a.sh
  printf '%s\n' '{"enabledPlugins":{"p@m":true}}' > "$_P/.claude/settings.json"
  printf '{ broken\n' > "$_H/.claude/plugins/installed_plugins.json"
  local out rc=0
  out="$(set -o pipefail; HOME="$_H" csa_enum_targets_all "$_P" 2>/dev/null)" || rc=$?
  assert_eq "2" "$rc" "rc 2" || return 1
  assert_eq "" "$out" "no targets emitted for an unknown set"
}

# --- 4. paranoid candidates ---------------------------------------------------

test_paranoid_real_layout() {
  _mk
  _install mk/alpha/1.0.0 a.sh; _install mk/beta/1.0.0 b.sh; _install mk/off/1.0.0 off.sh
  _install flat/1.0.0 f.sh
  mkdir -p "$_H/.claude/plugins/cache/temp_git_123/somerepo/1.0.0" "$_H/.claude/plugins/cache/temp_git_456/1.0.0"
  _record '{"alpha@mk":[],"ghost@other":[{"scope":"user","installPath":"/nowhere"}]}'
  printf '%s\n' '{"enabledPlugins":{"alpha@mk":true,"off@mk":false}}' > "$_P/.claude/settings.json"
  local out rc=0
  out="$(HOME="$_H" CSA_PROJECT_ROOT="$_P" csa_enum_paranoid_candidates)" || rc=$?
  assert_eq "0" "$rc" "rc" || return 1
  assert_eq $'beta@mk\nflat\nghost@other\noff@mk' "$out" "installed or cached, minus the true keys; false is a candidate; temp_git_* is not; sorted"
}

test_paranoid_marketplace_dir_is_not_a_plugin() {
  _mk
  _install mk/alpha/1.0.0 a.sh
  local out; out="$(HOME="$_H" CSA_PROJECT_ROOT="$_P" csa_enum_paranoid_candidates)"
  assert_eq "alpha@mk" "$out" "the marketplace directory itself is not listed"
}

# --- 5. fingerprint -----------------------------------------------------------

test_normalize_path_layouts() {
  local base="/home/u/.claude/plugins/cache" rc=0
  assert_eq "@plugin:p@m:hooks/h.sh" "$(csa_normalize_path "$base/m/p/1.2.3/hooks/h.sh")" "three-level, semver" || rc=1
  assert_eq "@plugin:p@m:hooks/h.sh" "$(csa_normalize_path "$base/m/p/2.0.0/hooks/h.sh")" "version bump keeps the id" || rc=1
  assert_eq "@plugin:p@m:h.sh" "$(csa_normalize_path "$base/m/p/a0b04d9ddcca/h.sh")" "three-level, digest version" || rc=1
  assert_eq "@plugin:p@m:h.sh" "$(csa_normalize_path "$base/m/p/unknown/h.sh")" "three-level, unknown version" || rc=1
  assert_eq "@plugin:p:hooks/h.sh" "$(csa_normalize_path "$base/p/0.1.0/hooks/h.sh")" "array-era two-level stays" || rc=1
  assert_eq "@plugin:p:h.sh" "$(csa_normalize_path "$base/p/0.1.0/h.sh")" "array-era two-level, file at the top" || rc=1
  # A version with an unusual name still drops out of the id, and a flat path keeps its own shape.
  assert_eq "@plugin:p@m:h.sh" "$(csa_normalize_path "$base/m/p/1/h.sh")" || rc=1
  assert_eq "@plugin:p@m:h.sh" "$(csa_normalize_path "$base/m/p/latest/h.sh")" || rc=1
  assert_eq "@plugin:p@m:d/h.sh" "$(csa_normalize_path "$base/m/p/2026-11-02/d/h.sh")" || rc=1
  # A version-named segment followed by another one is read as a plugin dir holding a version dir.
  assert_eq "@plugin:1.0.0@p:h.sh" "$(csa_normalize_path "$base/p/1.0.0/2.0/h.sh")" || rc=1
  [[ "$(csa_normalize_path "$base/m/p/1.2.3/h.sh")" != "$(csa_normalize_path "$base/m2/p/1.2.3/h.sh")" ]] \
    || { printf '    two marketplaces share an id\n' >&2; rc=1; }
  return "$rc"
}

# A plugin named like a version (`unknown`, 7 to 40 lowercase hex, a version string) whose version dir is a version
# is the plugin: `@plugin:<plugin>@<marketplace>:`, each with its own id. Control: a two-level path whose version dir
# holds no version-named dir stays two-level.
test_normalize_path_version_named_plugin() {
  local base="/home/u/.claude/plugins/cache" rc=0
  assert_eq "@plugin:unknown@m:hooks/h.sh" "$(csa_normalize_path "$base/m/unknown/1.0.0/hooks/h.sh")" "unknown, semver" || rc=1
  assert_eq "@plugin:deadbeef@m:hooks/x.ts" "$(csa_normalize_path "$base/m/deadbeef/a0b04d9ddcca/hooks/x.ts")" "hex, digest" || rc=1
  assert_eq "@plugin:1234567@m:h.sh" "$(csa_normalize_path "$base/m/1234567/unknown/h.sh")" "hex, unknown" || rc=1
  assert_eq "@plugin:v1.2@m:h.sh" "$(csa_normalize_path "$base/m/v1.2/2.0.0/h.sh")" "version string, semver" || rc=1
  [[ "$(csa_normalize_path "$base/m/unknown/1.0.0/hooks/y.sh")" != "$(csa_normalize_path "$base/m/deadbeef/1.0.0/hooks/y.sh")" ]] \
    || { printf '    two version-named plugins of one marketplace share an id\n' >&2; rc=1; }
  assert_eq "@plugin:p:hooks/h.sh" "$(csa_normalize_path "$base/p/0.1.0/hooks/h.sh")" "control: two-level stays" || rc=1
  assert_eq "@plugin:deadbeef:hooks/h.sh" "$(csa_normalize_path "$base/deadbeef/0.1.0/hooks/h.sh")" "control: two-level, hex name" || rc=1
  return "$rc"
}

# The paranoid list reads a marketplace dir holding a version-named plugin the same way: each plugin is listed as
# `<plugin>@<marketplace>`, not the marketplace as one flat plugin. Control: a flat cache/<plugin>/<version>/ dir
# stays a bare name.
test_paranoid_version_named_plugin_is_not_a_version() {
  _mk
  _install mk/deadbeef/1.0.0 d.sh; _install mk/alpha/1.0.0 a.sh; _install mk/unknown/a0b04d9ddcca u.sh
  _install flat/1.0.0 f.sh
  local out rc=0
  out="$(HOME="$_H" CSA_PROJECT_ROOT="$_P" csa_enum_paranoid_candidates)" || rc=$?
  assert_eq "0" "$rc" "rc" || return 1
  assert_eq $'alpha@mk\ndeadbeef@mk\nflat\nunknown@mk' "$out" "each plugin of mk, and the flat dir"
}

test_is_version_name() {
  local v rc=0
  for v in 1.0.0 v2.1 0.1.8 1.0.0-beta.1 a0b04d9ddcca 58267944f921 unknown; do
    csa_is_version_name "$v" || { printf '    %s should be a version\n' "$v" >&2; rc=1; }
  done
  for v in hooks skills agents ossify membrane 1 latest ''; do
    csa_is_version_name "$v" && { printf '    %s should not be a version\n' "$v" >&2; rc=1; }
  done
  return "$rc"
}

for t in test_object_map_true_keys_only test_array_form_still_reads \
         test_both_shapes_across_two_files_later_file_wins test_local_settings_is_read_and_wins \
         test_unrecognized_shape_warns_and_is_empty \
         test_record_picks_the_recorded_version_over_the_newest test_record_scope_precedence_and_other_projects \
         test_record_entry_for_another_project_only_falls_back_to_cache test_install_path_guard \
         test_name_with_slash_or_dotdot_is_refused test_bare_name_logic_and_local_dir \
         test_unreadable_or_malformed_record_is_rc2_absent_is_not test_targets_all_real_layout \
         test_same_plugin_name_in_two_marketplaces_stays_distinct \
         test_targets_all_rc2_is_not_swallowed_by_the_output_pipeline \
         test_paranoid_real_layout test_paranoid_marketplace_dir_is_not_a_plugin \
         test_normalize_path_layouts test_is_version_name \
         test_normalize_path_version_named_plugin test_paranoid_version_named_plugin_is_not_a_version; do
  csa_test_run "$t" || _csa_failed=$((_csa_failed + 1))
done

[[ "$_csa_failed" -eq 0 ]] || exit 1
