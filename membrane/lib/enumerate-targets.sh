#!/usr/bin/env bash
# lib/enumerate-targets.sh — scan target enumeration per SPEC §6.3 (T2-J pin).
# Requires: lib/helpers.sh (csa_printable, csa_escape, csa_root_ok, csa_is_version_name).
#
# The narrowed input (0.9.0). A path below an audited tree (the project's .claude/, .opencode/ and .codex/, a file the
# project-wide name walks find, a single named file at the root, each enabled plugin's directory) is read only when
#   - every byte of it below the tree is printable ASCII (0x20-0x7E),
#   - it is a regular file, reached through no symlink, and
#   - it is 1 MiB (1048576 bytes) or smaller.
# Anything else is one stop that names the path (escaped) and is not read: one HOOK-005 line below a hooks dir (a
# plugin's hooks/, the project's .claude/hooks/; not below a node_modules/ there), one SCANNER-003 line elsewhere,
# printed on stderr for the engine (_csa_enum_stderr_to_findings). A symlink or a file that is not regular is a stop
# wherever it sits in a walked tree; a name or a size is a stop only for a path the walk would read. The walks are
# NUL-delimited, so no name can split a target line.
# Skill-first: the predicate is question 2 (a fixed alphabet, file kinds, a size bound); each stop is question 3.

_CSA_SIZE_MAX=1048576

# _csa_enum_glob_quote <string> — the string with the glob metacharacters
# `\ * ? [` backslash-escaped, so `find -path` matches it literally.
_csa_enum_glob_quote() {
  local s="$1" o="" c i
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      '\'|'*'|'?'|'[') o="$o\\$c" ;;
      *) o="$o$c" ;;
    esac
  done
  printf '%s' "$o"
}

# _csa_enum_stop <id> <plugin-key> <path> <why> — one stop line, for stderr: `finding: <id><TAB><key><TAB><path><TAB>
# <why>`, key and path escaped (csa_escape) so neither holds a tab. <why> is symlink, kind, name or size.
_csa_enum_stop() {
  printf 'finding: %s\t%s\t%s\t%s\n' "$1" "$(csa_escape "$2")" "$(csa_escape "$3")" "$4"
}

# _csa_enum_hooks_rel <mode> <rel> — rc 0 when <rel>, a path below the walked tree, sits in a hooks dir the HOOK
# rules read: `hooks/…` of a plugin, `hooks/…` of the project's .claude/, and not below a node_modules/ there.
_csa_enum_hooks_rel() {
  case "$1" in plugin|claude) : ;; *) return 1 ;; esac
  case "$2" in hooks|hooks/*) : ;; *) return 1 ;; esac
  case "/$2" in */node_modules/*) return 1 ;; esac
  return 0
}

# _csa_enum_candidate <mode> <rel> <path> — rc 0 when the walk would read <path> (<rel> below the tree) as a target.
#   claude:   .md .json .sh .py .js .ts .mjs .cjs .tsx .jsx .mts .cts; below hooks/ also any executable file.
#   codex:    the same suffixes and .toml.
#   opencode: every file but package.json, package-lock.json, bun.lock and .gitignore at the top.
#   plugin, name, single: every file.
_csa_enum_candidate() {
  local mode="$1" rel="$2" path="$3"
  case "$mode" in
    claude|codex)
      case "${rel##*/}" in
        *.md|*.json|*.sh|*.py|*.js|*.ts|*.mjs|*.cjs|*.tsx|*.jsx|*.mts|*.cts) return 0 ;;
        *.toml) [[ "$mode" == codex ]] && return 0 ;;
      esac
      [[ "$mode" == claude && "$rel" == hooks/* && -x "$path" ]]
      ;;
    opencode)
      case "$rel" in package.json|package-lock.json|bun.lock|.gitignore) return 1 ;; esac
      return 0
      ;;
    *) return 0 ;;
  esac
}

# _csa_enum_classify <mode> <key> <tree> <path> <oversize-list> — print <path> as a target line on stdout, or one stop
# line on stderr, or nothing (a file the walk does not read). <oversize-list> holds the tree's regular files over
# 1 MiB, one per line between newlines; only a printable path is ever looked up in it.
_csa_enum_classify() {
  local mode="$1" key="$2" tree="$3" path="$4" big="$5" rel id=SCANNER-003
  rel="${path#"$tree"/}"
  _csa_enum_hooks_rel "$mode" "$rel" && id=HOOK-005
  if [[ -L "$path" ]]; then
    _csa_enum_stop "$id" "$key" "$path" symlink >&2
    return 0
  fi
  if [[ ! -f "$path" ]]; then
    _csa_enum_stop "$id" "$key" "$path" kind >&2
    return 0
  fi
  _csa_enum_candidate "$mode" "$rel" "$path" || return 0
  if ! csa_printable "$rel"; then
    _csa_enum_stop "$id" "$key" "$path" name >&2
    return 0
  fi
  if [[ "$big" == *$'\n'"$path"$'\n'* ]]; then
    _csa_enum_stop "$id" "$key" "$path" size >&2
    return 0
  fi
  if [[ "$mode" == plugin ]]; then
    printf '@plugin:%s:%s\t%s\n' "$key" "$rel" "$path"
  else
    printf '%s\n' "$path"
  fi
}

# _csa_enum_walk <mode> <key> <tree> [<pruned-path>...] — every entry below <tree> that is not a directory, classified
# (_csa_enum_classify). <tree> that is a symlink is one stop and is not walked. A pruned path is left out with what is
# below it. rc 0 always: a dir find cannot read is _csa_enum_unreadable_dirs' stop, and bin/csa's
# `set -euo pipefail` never ends the enumeration here.
_csa_enum_walk() {
  local mode="$1" key="$2" tree="$3" p f big=$'\n'
  shift 3
  if [[ -L "$tree" ]]; then
    _csa_enum_stop SCANNER-003 "$key" "$tree" symlink >&2
    return 0
  fi
  [[ -d "$tree" ]] || return 0
  local -a prune=()
  for p in "$@"; do prune+=( -path "$(_csa_enum_glob_quote "$p")" -prune -o ); done
  while LC_ALL=C IFS= read -r -d '' f; do
    csa_printable "$f" && big="$big$f"$'\n'
  done < <(find "$tree" ${prune[@]+"${prune[@]}"} -type f -size +"${_CSA_SIZE_MAX}c" -print0 2>/dev/null || :)
  while LC_ALL=C IFS= read -r -d '' f; do
    _csa_enum_classify "$mode" "$key" "$tree" "$f" "$big"
  done < <(find "$tree" ${prune[@]+"${prune[@]}"} ! -type d -print0 2>/dev/null || :)
  return 0
}

# _csa_enum_linked_part <root> <rel> — rc 0, printing the path, when a directory on the way from <root> to <rel>
# (<rel> itself not included) is a symlink; rc 1 otherwise.
_csa_enum_linked_part() {
  local p="$1" part rest="$2"
  while [[ "$rest" == */* ]]; do
    part="${rest%%/*}"; rest="${rest#*/}"
    p="$p/$part"
    if [[ -L "$p" ]]; then printf '%s' "$p"; return 0; fi
  done
  return 1
}

# _csa_enum_single <root> <rel> — one named file at the project root (`.mcp.json`, `AGENTS.md`…): a target line, a
# stop for it or for a symlinked directory on its way, or nothing when it is absent.
_csa_enum_single() {
  local root="$1" rel="$2" l f="$1/$2" big=$'\n'
  if l="$(_csa_enum_linked_part "$root" "$rel")"; then
    _csa_enum_stop SCANNER-003 "" "$l" symlink >&2
    return 0
  fi
  [[ -e "$f" || -L "$f" ]] || return 0
  [[ -f "$f" && ! -L "$f" && -n "$(find "$f" -prune -type f -size +"${_CSA_SIZE_MAX}c" -print 2>/dev/null)" ]] \
    && big="$big$f"$'\n'
  _csa_enum_classify single "" "$root" "$f" "$big"
}

# _csa_enum_named <root> <find-test>... — the project-wide name walk (every CLAUDE.md, every
# .codex-plugin/plugin.json below the root, at any depth; nothing pruned): each match that is not a directory,
# classified. A symlinked directory is not followed, so a match below one is not found.
_csa_enum_named() {
  local root="$1" f big=$'\n'
  shift
  while LC_ALL=C IFS= read -r -d '' f; do
    csa_printable "$f" && big="$big$f"$'\n'
  done < <(find "$root" "$@" -type f -size +"${_CSA_SIZE_MAX}c" -print0 2>/dev/null || :)
  while LC_ALL=C IFS= read -r -d '' f; do
    _csa_enum_classify name "" "$root" "$f" "$big"
  done < <(find "$root" "$@" ! -type d -print0 2>/dev/null || :)
}

csa_enum_codex_project_targets() {
  local root="$1"
  local has_codex_surface=0 out
  [[ -e "$root/AGENTS.md" || -L "$root/AGENTS.md" ]] && has_codex_surface=1
  _csa_enum_single "$root" AGENTS.md
  if [[ -e "$root/.codex" || -L "$root/.codex" ]]; then
    has_codex_surface=1
    _csa_enum_walk codex "" "$root/.codex"
  fi
  [[ -e "$root/.agents/plugins/marketplace.json" || -L "$root/.agents/plugins/marketplace.json" || -L "$root/.agents" ]] \
    && has_codex_surface=1
  _csa_enum_single "$root" .agents/plugins/marketplace.json
  out="$(_csa_enum_named "$root" -path '*/.codex-plugin/plugin.json')"
  [[ -n "$out" ]] && { has_codex_surface=1; printf '%s\n' "$out"; }

  if [[ "$has_codex_surface" -eq 1 && ( -e "${HOME}/.codex/config.toml" || -L "${HOME}/.codex/config.toml" ) ]]; then
    _csa_enum_single "${HOME}/.codex" config.toml
  fi
}

csa_enum_opencode_project_targets() {
  local root="$1"
  _csa_enum_single "$root" package.json
  [[ -e "$root/.opencode" || -L "$root/.opencode" ]] || return 0
  _csa_enum_walk opencode "" "$root/.opencode" "$root/.opencode/node_modules" "$root/.opencode/audits"
}

# _csa_enum_hooks_unreadable <hooks-dir> — rc 2, with one `csa:` line, when <hooks-dir> or a directory below it cannot
# be read or entered: a handler there could not be listed, so the audit is refused (as since 0.8.0).
_csa_enum_hooks_unreadable() {
  local dir="$1" d
  [[ -d "$dir" && ! -L "$dir" ]] || return 0
  while LC_ALL=C IFS= read -r -d '' d; do
    if [[ ! -r "$d" || ! -x "$d" ]]; then
      printf 'csa: cannot read the directory %s below .claude/hooks/; refusing the audit\n' "$(csa_escape "$d")" >&2
      return 2
    fi
  done < <(find "$dir" -type d -print0 2>/dev/null || :)
  return 0
}

csa_enum_project_targets() {
  local root="$1" aq
  csa_root_ok "$root" || return 2
  while [[ "$root" == ?*/ ]]; do root="${root%/}"; done
  if [[ -e "$root/.claude" || -L "$root/.claude" ]]; then
    _csa_enum_hooks_unreadable "$root/.claude/hooks" || return 2
    # Exclude .claude/audits/ — it holds audit state/reports and must not be scanned.
    _csa_enum_walk claude "" "$root/.claude" "$root/.claude/audits"
    if [[ ! -L "$root/.claude" ]]; then
      aq="$(_csa_enum_glob_quote "$root/.claude/audits")"
      _csa_enum_unreadable_dirs "" "$root/.claude" "$aq" >&2
    fi
  fi
  _csa_enum_named "$root" -name CLAUDE.md
  _csa_enum_single "$root" .claude-plugin/marketplace.json
  _csa_enum_single "$root" .mcp.json
  csa_enum_opencode_project_targets "$root"
  csa_enum_codex_project_targets "$root"
}

# _csa_enum_unreadable_dirs <plugin-key> <dir> [<pruned-path>] — for stderr, one
# `finding: SCANNER-003<TAB><key><TAB><dir>` line for <dir> and for each dir
# below it that this process cannot read or enter, so nothing below it was
# listed (#1149). The key is empty for a project dir. <pruned-path>, already
# glob-quoted, is skipped with what is below it. A test on the mode bits the
# shell sees (no GNU -readable, no parsing of find's stderr). Skill-first
# question 3: it only adds a stop. rc 0 always, so bin/csa's
# `set -euo pipefail` never ends the enumeration here.
_csa_enum_unreadable_dirs() {
  local key="$1" dir="$2" prune="${3-}" d
  local -a skip=()
  [[ -z "$prune" ]] || skip=( -path "$prune" -prune -o )
  while LC_ALL=C IFS= read -r -d '' d; do
    [[ -r "$d" && -x "$d" ]] \
      || printf 'finding: SCANNER-003\t%s\t%s\n' "$(csa_escape "$key")" "$(csa_escape "$d")"
  done < <(find "$dir" ${skip[@]+"${skip[@]}"} -type d -print0 2>/dev/null || :)
  return 0
}

# _csa_enum_settings_plugin_list <settings-file> [<project-root>] — the file's enabledPlugins as
# one compact JSON object, plugin key to boolean. Claude Code writes an object
# map (`{"plugin@marketplace": true}`); only boolean values are kept. An array
# of names (fixtures, older files) reads as each name `true`. An absent file
# or an absent key reads as {}. A value that holds entries yet yields none (a
# string, a number, an array of non-strings, an object of non-booleans) also
# reads as {}, but warns on stderr naming the shape: an audit that silently
# skips every plugin reads as a clean one. A path that exists but is not a
# regular file, cannot be read, or is not valid JSON (#1092) is NOT an empty set:
# rc 2 (#424). With <project-root>, the file sits in the audited .claude/: a
# symlink at it or on the way to it is never followed, so its set is unknown, rc 2.
_csa_enum_settings_plugin_list() {
  local f="$1" root="${2-}" out list warn l
  if [[ -n "$root" ]]; then
    if l="$(_csa_enum_linked_part "$root" "${f#"$root"/}")" || { [[ -L "$f" ]] && l="$f"; }; then
      printf 'csa: %s is a symlink, which is never followed; the enabled-plugin set is unknown\n' "$(csa_escape "$l")" >&2
      return 2
    fi
  fi
  if [[ ! -e "$f" ]]; then
    printf '{}\n'
    return 0
  fi
  if [[ ! -f "$f" ]]; then
    # A FIFO would block jq forever; a directory holds no settings.
    printf 'csa: %s is not a regular file; the enabled-plugin set is unknown\n' "$f" >&2
    return 2
  fi
  if [[ ! -r "$f" ]]; then
    printf 'csa: cannot read %s; the enabled-plugin set is unknown\n' "$f" >&2
    return 2
  fi
  # Line 1: the map. Line 2: the shape's type when it held entries but none
  # were usable, else empty. `input` (not `.`), so an empty file is an error too.
  out="$(jq -n -r 'input
    | .enabledPlugins as $e
    | (if ($e | type) == "object" then $e | with_entries(select((.value | type) == "boolean"))
       elif ($e | type) == "array" then [$e[] | select(type == "string") | {key: ., value: true}] | from_entries
       else {} end) as $m
    | ($m | tojson),
      (if ($m | length) == 0 and (($e | type) == "string" or ($e | type) == "number" or $e == true
            or ((($e | type) == "object" or ($e | type) == "array") and ($e | length) > 0))
       then ($e | type) else "" end)
  ' "$f" 2>/dev/null)" || {
    printf 'csa: cannot read %s; the enabled-plugin set is unknown\n' "$f" >&2
    return 2
  }
  list="$(printf '%s\n' "$out" | sed -n 1p)"
  warn="$(printf '%s\n' "$out" | sed -n 2p)"
  if [[ -n "$warn" ]]; then
    printf 'csa: warning: %s has an enabledPlugins value of an unrecognized shape (%s) with no usable entries; its plugins are NOT scanned\n' "$f" "$warn" >&2
  fi
  [[ -n "$list" ]] || list='{}'
  printf '%s\n' "$list"
}

# _csa_enum_enabled_json <project-root> — the merged enabled map as one JSON
# object, plugin key to boolean. Files merge by key, later wins: the user's
# settings.json, then the project's, then the project's settings.local.json, so
# a project `false` disables a user `true`. The maps reach jq on stdin, never
# as an argv value, so no OS per-argument limit can empty them (#424); a
# failure is rc 2, never {}.
_csa_enum_enabled_json() {
  local root="$1" user_map project_map local_map merged
  user_map="$(_csa_enum_settings_plugin_list "${HOME}/.claude/settings.json")" || return 2
  while [[ "$root" == ?*/ ]]; do root="${root%/}"; done
  project_map="$(_csa_enum_settings_plugin_list "$root/.claude/settings.json" "$root")" || return 2
  local_map="$(_csa_enum_settings_plugin_list "$root/.claude/settings.local.json" "$root")" || return 2
  if ! merged="$(printf '%s\n%s\n%s\n' "$user_map" "$project_map" "$local_map" | jq -sc 'add // {}')"; then
    printf 'csa: could not merge the enabled-plugin sets\n' >&2
    return 2
  fi
  printf '%s\n' "$merged"
}

# csa_enum_enabled_plugins <project-root> — the keys left at true, one per line,
# sorted. A key's newline, carriage return and tab are escaped so it stays one
# line (it can never resolve to a plugin).
csa_enum_enabled_plugins() {
  local merged
  merged="$(_csa_enum_enabled_json "$1")" || return 2
  printf '%s\n' "$merged" | jq -r '
    [to_entries[] | select(.value == true) | .key | gsub("\n"; "\\n") | gsub("\r"; "\\r") | gsub("\t"; "\\t")]
    | sort | .[]' || return 2
}

# _csa_enum_record_file — path of Claude Code's install record.
_csa_enum_record_file() {
  printf '%s\n' "${HOME}/.claude/plugins/installed_plugins.json"
}

# _csa_enum_record_lookup <key> <project-root> — the installPath that
# installed_plugins.json records for <key> in this project's scope: a `local`
# entry whose projectPath is this project, else a `project` one, else the
# `user` one. rc 0 prints it; rc 1: no record file, or no entry for this key
# and project (the caller falls back to the cache layout); rc 2: the record
# exists but cannot be read, is not JSON, or is not the shape this code knows.
_csa_enum_record_lookup() {
  local key="$1" root="$2" rec rows scope ppath ipath phys_root pp
  rec="$(_csa_enum_record_file)"
  [[ -e "$rec" || -L "$rec" ]] || return 1
  if [[ ! -f "$rec" || ! -r "$rec" ]]; then
    printf 'csa: cannot read %s; where plugins are installed is unknown\n' "$rec" >&2
    return 2
  fi
  # `input` (not `.`) so an empty file is an error, not an empty answer. A row is its three fields joined by a tab,
  # raw, so a `\` in a path survives (`@tsv` writes it `\\`). A row whose field holds a tab, newline or CR keeps
  # `@tsv`'s escaped form, so it cannot split into extra rows or fields; its path then names the directory with that
  # escaped name (`\t` as two characters), as before, and is refused when none exists. _csa_enum_guard_dir refuses a
  # real tab or newline in any case.
  rows="$(jq -n -r --arg k "$key" 'input |
    if (.plugins | type) != "object" then error("no plugins object")
    elif ((.plugins[$k] // []) | type) != "array" then error("entry is not a list")
    else
      [ (.plugins[$k] // [])[] | select(type == "object")
        | select((.scope | type) == "string" and (.installPath | type) == "string")
        | {scope, installPath, projectPath: (if (.projectPath | type) == "string" and (.projectPath | length) > 0 then .projectPath else "-" end)}
        | select(.scope == "user" or .projectPath != "-") ]
      | (map(select(.scope == "local")) + map(select(.scope == "project")) + map(select(.scope == "user")))[]
      | [.scope, .projectPath, .installPath] | if any(.[]; test("[\t\n\r]")) then @tsv else join("\t") end
    end' "$rec" 2>/dev/null)" || {
    printf 'csa: %s is not the expected installed-plugins record (JSON with a plugins object of lists); where plugins are installed is unknown\n' "$rec" >&2
    return 2
  }
  phys_root="$(cd -- "$root" 2>/dev/null && pwd -P)" || phys_root="${root%/}"
  while LC_ALL=C IFS=$'\t' read -r scope ppath ipath; do
    [[ -n "$scope" ]] || continue
    if [[ "$scope" == user ]]; then
      printf '%s\n' "$ipath"
      return 0
    fi
    [[ "$ppath" == /* ]] || continue
    pp="$(cd -- "$ppath" 2>/dev/null && pwd -P)" || pp="${ppath%/}"
    if [[ "$pp" == "$phys_root" ]]; then
      printf '%s\n' "$ipath"
      return 0
    fi
  done <<< "$rows"
  return 1
}

# _csa_enum_guard_dir <path> — rc 0 prints <path> as a directory physically
# inside ~/.claude/plugins, rewritten under $HOME/.claude/plugins so its
# `/.claude/plugins/` shape survives a symlinked home. rc 1 prints why not. The
# path prefixes every target line of the plugin, so it may hold no control byte.
# A project under audit is hostile input and the install record is read from
# the user's home: neither may point the scan at /etc or at another project.
_csa_enum_guard_dir() {
  local p="$1" proot phys
  if [[ "$p" != /* ]]; then
    printf 'installPath %s is not absolute' "$(csa_escape "$p")"
    return 1
  fi
  if ! proot="$(cd -- "${HOME}/.claude/plugins" 2>/dev/null && pwd -P)"; then
    printf 'installPath %s cannot be checked: %s/.claude/plugins is missing' "$(csa_escape "$p")" "$HOME"
    return 1
  fi
  if [[ ! -d "$p" ]]; then
    printf 'installPath %s is not a directory' "$(csa_escape "$p")"
    return 1
  fi
  if ! phys="$(cd -- "$p" 2>/dev/null && pwd -P)"; then
    printf 'installPath %s cannot be entered' "$(csa_escape "$p")"
    return 1
  fi
  case "$phys" in
    "$proot"/?*) : ;;
    *)
      printf 'installPath %s resolves outside %s' "$(csa_escape "$p")" "$proot"
      return 1
      ;;
  esac
  if ! _csa_re_bytes "$phys" '^[^[:cntrl:]]*$'; then
    printf 'installPath %s holds a control character' "$(csa_escape "$p")"
    return 1
  fi
  printf '%s/.claude/plugins/%s\n' "$HOME" "${phys#"$proot"/}"
}

# _csa_enum_safe_segment <name> — rc 0 if <name> is one safe path segment: not
# empty, no `/`, no `..`, not `.`, no newline.
_csa_enum_safe_segment() {
  local n="$1"
  [[ -n "$n" && "$n" != "." && "$n" != *"/"* && "$n" != *".."* && "$n" != *$'\n'* ]]
}

# _csa_enum_pick_version <plugin-dir> — the one version directory to scan:
# the one `.active` names, else the only version directory. rc 1 if neither.
_csa_enum_pick_version() {
  local dir="$1" v c count=0 only=""
  [[ -d "$dir" ]] || return 1
  if [[ -f "$dir/.active" ]]; then
    v="$(cat "$dir/.active" 2>/dev/null)" || return 1
    [[ -n "$v" ]] || return 1
    printf '%s/%s\n' "$dir" "$v"
    return 0
  fi
  while LC_ALL=C IFS= read -r c; do
    [[ -n "$c" ]] || continue
    count=$((count + 1))
    only="$c"
  done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
  if [[ "$count" -eq 1 ]]; then
    printf '%s\n' "$only"
    return 0
  fi
  return 1
}

# csa_enum_resolve_plugin_path <plugin-key> [<project-root>] — where one enabled
# plugin lives. rc 0 prints the directory; rc 1 prints, on stdout, the reason it
# did not resolve (the PROVENANCE-002 text); rc 2: the install record is
# unreadable, so where plugins live is unknown.
#   1. installed_plugins.json: this project's local/project entry, else user's.
#      Its installPath is used only if it is a directory inside ~/.claude/plugins.
#   2. No record entry, key `plugin@marketplace`: cache/<marketplace>/<plugin>/,
#      its .active version or its only version.
#   3. A bare name: cache/<name>/ the same way, then local/<name>/.
# Any name part holding `/` or `..` is refused. The default project root is
# CSA_PROJECT_ROOT, else the working directory.
csa_enum_resolve_plugin_path() {
  local key="$1" root="${2:-${CSA_PROJECT_ROOT:-$PWD}}"
  local pdir="${HOME}/.claude/plugins" ip rc=0 cand out plugin mkt
  # The key is passed to jq as an argument, so a long one could only fail
  # there. No plugin id comes near this length.
  if [[ "${#key}" -gt 1024 ]]; then
    printf 'not installed at expected path (name too long)'
    return 1
  fi

  ip="$(_csa_enum_record_lookup "$key" "$root")" || rc=$?
  case "$rc" in
    0)
      if out="$(_csa_enum_guard_dir "$ip")"; then
        printf '%s\n' "$out"
        return 0
      fi
      printf '%s' "$out"
      return 1
      ;;
    1) : ;;
    *) return 2 ;;
  esac

  if [[ "$key" == *@* ]]; then
    plugin="${key%@*}"
    mkt="${key##*@}"
    if ! _csa_enum_safe_segment "$plugin" || ! _csa_enum_safe_segment "$mkt"; then
      printf 'not installed at expected path (name is not a safe path segment)'
      return 1
    fi
    if cand="$(_csa_enum_pick_version "$pdir/cache/$mkt/$plugin")" && out="$(_csa_enum_guard_dir "$cand")"; then
      printf '%s\n' "$out"
      return 0
    fi
  else
    if ! _csa_enum_safe_segment "$key"; then
      printf 'not installed at expected path (name is not a safe path segment)'
      return 1
    fi
    if cand="$(_csa_enum_pick_version "$pdir/cache/$key")" && out="$(_csa_enum_guard_dir "$cand")"; then
      printf '%s\n' "$out"
      return 0
    fi
    if [[ -d "$pdir/local/$key" ]] && out="$(_csa_enum_guard_dir "$pdir/local/$key")"; then
      printf '%s\n' "$out"
      return 0
    fi
  fi
  printf 'not installed at expected path'
  return 1
}

csa_enum_targets_all() {
  local root="$1" project_targets
  csa_root_ok "$root" || return 2
  while [[ "$root" == ?*/ ]]; do root="${root%/}"; done
  if ! project_targets="$(csa_enum_project_targets "$root")"; then
    return 2
  fi
  # Captured first: a process substitution would drop the rc 2 of an
  # unreadable settings file and scan as if no plugin were enabled (#424).
  local enabled_plugins
  if ! enabled_plugins="$(csa_enum_enabled_plugins "$root")"; then
    return 2
  fi
  # Resolve every plugin in this shell, not inside the output pipeline below: an
  # unreadable install record is rc 2, which a pipeline subshell would drop.
  local resolved="" plugin_name plugin_path rc
  while LC_ALL=C IFS= read -r plugin_name; do
    [[ -z "$plugin_name" ]] && continue
    rc=0
    plugin_path="$(csa_enum_resolve_plugin_path "$plugin_name" "$root")" || rc=$?
    case "$rc" in
      0) resolved="${resolved}${plugin_name}"$'\t'"${plugin_path}"$'\n' ;;
      1) printf 'finding: PROVENANCE-002 plugin %s enabled but %s\n' "$plugin_name" "$plugin_path" >&2 ;;
      *) return 2 ;;
    esac
  done <<< "$enabled_plugins"
  # Every file of each enabled plugin, through the one predicate (_csa_enum_walk): a target line, or one stop. A
  # plugin key holds no tab or newline (csa_enum_enabled_plugins escapes them) and its path none either
  # (_csa_enum_guard_dir), so each target line is `@plugin:<key>:<rel><TAB><path>`.
  {
    [[ -n "$project_targets" ]] && printf '%s\n' "$project_targets"
    while LC_ALL=C IFS=$'\t' read -r plugin_name plugin_path; do
      [[ -z "$plugin_name" ]] && continue
      _csa_enum_walk plugin "$plugin_name" "$plugin_path"
      _csa_enum_unreadable_dirs "$plugin_name" "$plugin_path" >&2
    done <<< "$resolved"
  } | awk -F '\t' '!seen[$NF]++'
}

# _csa_enum_is_flat_plugin_dir <dir> — rc 0 if a plugin cache directory holds a
# version directory directly (the older cache/<plugin>/<version> layout),
# rc 1 if it is a marketplace directory holding plugin directories. A
# version-named child that itself holds a version-named directory is a plugin
# named like a version (`unknown`, `deadbeef`), not a version: the reading
# csa_normalize_path gives the same path (#1147).
_csa_enum_is_flat_plugin_dir() {
  local d="$1" c g pair
  [[ -f "$d/.active" ]] && return 0
  for c in "$d"/*; do
    [[ -d "$c" ]] || continue
    csa_is_version_name "${c##*/}" || continue
    pair=0
    for g in "$c"/*; do
      [[ -d "$g" ]] && csa_is_version_name "${g##*/}" && { pair=1; break; }
    done
    [[ "$pair" -eq 1 ]] || return 0
  done
  return 1
}

# _csa_enum_record_keys — the install record's plugin keys as a JSON array;
# [] if there is no record. A record that exists but cannot be read or has an
# unknown shape is rc 2.
_csa_enum_record_keys() {
  local rec; rec="$(_csa_enum_record_file)"
  if [[ ! -e "$rec" && ! -L "$rec" ]]; then
    printf '[]\n'
    return 0
  fi
  if [[ ! -f "$rec" || ! -r "$rec" ]]; then
    printf 'csa: cannot read %s; the installed plugins are unknown\n' "$rec" >&2
    return 2
  fi
  jq -n -c 'input | if (.plugins | type) == "object" and ([.plugins[] | type] | all(. == "array")) then .plugins | keys else error("no plugins object of lists") end' "$rec" 2>/dev/null || {
    printf 'csa: %s is not the expected installed-plugins record (JSON with a plugins object of lists); the installed plugins are unknown\n' "$rec" >&2
    return 2
  }
}

# csa_enum_paranoid_candidates — installed or cached plugins that are not
# enabled, as `plugin@marketplace` (a bare name for the older flat cache
# layout), one per line, sorted by codepoint. Candidates are the install
# record's keys plus each cache/<marketplace>/<plugin> directory, minus the keys
# left at true; a `false` key is a candidate. `temp_git_*` is a clone in
# progress and is skipped. Read/report only: it lists candidates and never
# approves anything. Each identity is compared whole against the enabled set
# inside jq (NUL-delimited in, no word splitting, #425). A candidate whose name
# holds a newline cannot be one output line, so the enumeration refuses with
# rc 2 and emits nothing rather than split it.
csa_enum_paranoid_candidates() {
  local cache="${HOME}/.claude/plugins/cache" rec
  rec="$(_csa_enum_record_file)"
  [[ -d "$cache" || -e "$rec" || -L "$rec" ]] || return 0
  local enabled_json keys_json top_file sub_file names_file rc=0 a b base
  enabled_json="$(_csa_enum_enabled_json "${CSA_PROJECT_ROOT:-$PWD}")" || return 2
  keys_json="$(_csa_enum_record_keys)" || return 2
  top_file="$(mktemp "${TMPDIR:-/tmp}/csa-cache-top.XXXXXX")" || return 2
  sub_file="$(mktemp "${TMPDIR:-/tmp}/csa-cache-sub.XXXXXX")" || { rm -f "$top_file"; return 2; }
  names_file="$(mktemp "${TMPDIR:-/tmp}/csa-cache-names.XXXXXX")" || { rm -f "$top_file" "$sub_file"; return 2; }
  if [[ -d "$cache" ]]; then
    if ! find "$cache" -maxdepth 1 -mindepth 1 -type d -print0 > "$top_file" 2>/dev/null; then
      printf 'csa: cannot list the plugin cache %s\n' "$cache" >&2
      rm -f "$top_file" "$sub_file" "$names_file"
      return 2
    fi
    while LC_ALL=C IFS= read -r -d '' a; do
      base="${a##*/}"
      case "$base" in temp_git_*) continue ;; esac
      if _csa_enum_is_flat_plugin_dir "$a"; then
        printf '%s\0' "$base" >> "$names_file"
        continue
      fi
      if ! find "$a" -maxdepth 1 -mindepth 1 -type d -print0 > "$sub_file" 2>/dev/null; then
        printf 'csa: cannot list the plugin cache %s\n' "$a" >&2
        rm -f "$top_file" "$sub_file" "$names_file"
        return 2
      fi
      while LC_ALL=C IFS= read -r -d '' b; do
        printf '%s@%s\0' "${b##*/}" "$base" >> "$names_file"
      done < "$sub_file"
    done < "$top_file"
  fi
  printf '%s\n' "$enabled_json" | jq -r --rawfile names "$names_file" --slurpfile rk <(printf '%s\n' "$keys_json") '
    ([to_entries[] | select(.value == true) | {(.key): true}] | add // {}) as $enabled
    | ([ $names | split("\u0000")[] | select(length > 0) ] + [ ($rk[0] // [])[] | select(type == "string") ])
    | unique
    | map(select($enabled[.] | not))
    | if any(.[]; contains("\n"))
      then "csa: refusing a plugin cache name that contains a newline\n" | halt_error(2)
      else .[]
      end' || rc=2
  rm -f "$top_file" "$sub_file" "$names_file"
  return "$rc"
}
