#!/usr/bin/env bash
# lib/enumerate-targets.sh — scan target enumeration per SPEC §6.3 (T2-J pin).
# Requires: lib/helpers.sh.

csa_enum_codex_project_targets() {
  local root="$1"
  local has_codex_surface=0
  [[ -f "$root/AGENTS.md" ]] && { has_codex_surface=1; printf '%s\n' "$root/AGENTS.md"; }

  if [[ -d "$root/.codex" ]]; then
    has_codex_surface=1
    find "$root/.codex" -type f \
         \( -name '*.md' -o -name '*.json' -o -name '*.toml' -o -name '*.sh' \
            -o -name '*.py' -o -name '*.js' -o -name '*.ts' \
            -o -name '*.mjs' -o -name '*.cjs' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.mts' -o -name '*.cts' \) 2>/dev/null
    find "$root/.codex" -type l 2>/dev/null | while LC_ALL=C read -r sl; do
      printf 'info: symlink at %s not followed\n' "$sl" >&2
    done
  fi

  [[ -f "$root/.agents/plugins/marketplace.json" ]] && { has_codex_surface=1; printf '%s\n' "$root/.agents/plugins/marketplace.json"; }
  local codex_manifests
  codex_manifests="$(find "$root" -path '*/.codex-plugin/plugin.json' -type f 2>/dev/null)"
  [[ -n "$codex_manifests" ]] && { has_codex_surface=1; printf '%s\n' "$codex_manifests"; }

  if [[ "$has_codex_surface" -eq 1 && -f "${HOME}/.codex/config.toml" ]]; then
    printf '%s\n' "${HOME}/.codex/config.toml"
  fi
}

csa_enum_opencode_project_targets() {
  local root="$1"
  if [[ -L "$root/package.json" ]]; then
    printf 'info: symlink at %s not followed\n' "$root/package.json" >&2
  elif [[ -f "$root/package.json" ]]; then
    printf '%s\n' "$root/package.json"
  fi

  [[ -e "$root/.opencode" || -L "$root/.opencode" ]] || return 0
  local oq; oq="$(_csa_enum_glob_quote "$root/.opencode")"
  find "$root/.opencode" \
       \( -path "$oq/node_modules" -o -path "$oq/audits" \) -prune -o \
       -type f \
       -not -path "$oq/package.json" \
       -not -path "$oq/package-lock.json" \
       -not -path "$oq/bun.lock" \
       -not -path "$oq/.gitignore" \
       -print 2>/dev/null
  find "$root/.opencode" \
       \( -path "$oq/node_modules" -o -path "$oq/audits" \) -prune -o \
       -type l -print 2>/dev/null | while LC_ALL=C read -r sl; do
    printf 'info: symlink at %s not followed\n' "$sl" >&2
  done
}

# _csa_enum_unlisted_hook_handlers <project-root>
# Emit every regular file under .claude/hooks/ whose suffix the main pass below
# does not list and that is either executable (extensionless, hidden, or an
# unlisted dotted suffix such as `preflight.tool`, #426) or handler code by its
# suffix whatever its mode (.mjs .cjs .tsx .jsx .mts .cts, which settings run as
# `node .claude/hooks/x.mjs`). A name holding a newline or tab cannot be one
# target line: an executable one refuses the whole enumeration (rc 2, #426); a
# non-executable code file is left out and reported as one HOOK-005. Listed
# suffixes are skipped here so the main pass emits them exactly once: keep this
# case list equal to its -name list.
_csa_enum_unlisted_hook_handlers() {
  local root="$1" hooks="$1/.claude/hooks" code unread=""
  [[ -d "$hooks" ]] || return 0

  # The HOOK-005 lines are held until the walk ends, so a refusal prints only its own message.
  find "$hooks" -type f -print0 2>/dev/null | { while LC_ALL=C IFS= read -r -d '' handler; do
    case "${handler##*/}" in
      *.md|*.json|*.sh|*.py|*.js|*.ts) : ;;
      *) code=0
         case "${handler##*/}" in *.mjs|*.cjs|*.tsx|*.jsx|*.mts|*.cts) code=1 ;; esac
         if [[ "$code" -eq 1 || -x "$handler" ]]; then
           if [[ "$handler" == *$'\n'* || "$handler" == *$'\t'* ]]; then
             if [[ -x "$handler" ]]; then
               printf 'refusing newline-or-tab-containing executable hook handler\n' >&2
               return 2
             fi
             # Not executable: unread and reported as one HOOK-005, the audit goes on.
             unread="$unread$(_csa_enum_unread_hook_file "" "$handler")"$'\n'
             continue
           fi
           printf '%s\n' "$handler"
         else
           :
         fi
         ;;
    esac
  done
  [[ -z "$unread" ]] || printf '%s' "$unread" >&2; }
}

csa_enum_project_targets() {
  local root="$1" hq f
  if [[ -d "$root/.claude" ]]; then
    if ! _csa_enum_unlisted_hook_handlers "$root"; then
      return 2
    fi
    # A symlink below .claude/hooks/, or .claude/hooks/ as one, is not followed:
    # one HOOK-005 each.
    _csa_enum_hook_symlinks "" "$root/.claude/hooks" >&2
    # split: a .py .js .ts file, in any mode, whose name below .claude/hooks/
    # holds a newline or tab. It would split as a target line, so the main pass
    # leaves it out and it is one HOOK-005; one predicate for both, so a file
    # left out is always reported. A .sh .md .json one is listed as before.
    # Skill-first question 3: it only adds a stop.
    hq="$(_csa_enum_glob_quote "$root/.claude/hooks")"
    local -a split=( \( -path "$hq/*"$'\n'"*" -o -path "$hq/*"$'\t'"*" \)
                     \( -name '*.py' -o -name '*.js' -o -name '*.ts' \) )
    find "$root/.claude/hooks" -type f "${split[@]}" -print0 2>/dev/null \
      | while LC_ALL=C IFS= read -r -d '' f; do _csa_enum_unread_hook_file "" "$f" >&2; done || :
    # Exclude .claude/audits/ — it holds audit state/reports and must not be scanned. The root is glob-quoted (#1148).
    # The six module suffixes below .claude/hooks/ are emitted by _csa_enum_unlisted_hook_handlers, so not here (#1141).
    local aq; aq="$(_csa_enum_glob_quote "$root/.claude/audits")"
    # A dir below .claude/ that find cannot read makes it exit 1. enum_targets_all and the engine call this inside
    # `if !`, where errexit is off, so that does not end them; `|| :` only keeps a caller outside `if` from ending at
    # this find. The dir is one SCANNER-003 line (#1149). A direct `bin/csa
    # enum_project_targets` call still ends at the next unguarded find, and an unreadable dir under .claude/hooks/
    # still refuses the audit (exit 2) through _csa_enum_unlisted_hook_handlers, as in 0.8.0.
    find "$root/.claude" -type f \
         -not -path "$aq/*" \
         \( -name '*.md' -o -name '*.json' -o -name '*.sh' \
            -o -name '*.py' -o -name '*.js' -o -name '*.ts' \
            -o \( \( -name '*.mjs' -o -name '*.cjs' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.mts' -o -name '*.cts' \) \
                  ! -path "$hq/*" \) \) \
         ! \( "${split[@]}" \) 2>/dev/null || :
    find "$root/.claude" -type l \
         -not -path "$aq/*" 2>/dev/null | while LC_ALL=C read -r sl; do
      printf 'info: symlink at %s not followed\n' "$sl" >&2
    done
    _csa_enum_unreadable_dirs "" "$root/.claude" "$aq" >&2
  fi
  find "$root" -name 'CLAUDE.md' -type f 2>/dev/null
  [[ -f "$root/.claude-plugin/marketplace.json" ]] && printf '%s\n' "$root/.claude-plugin/marketplace.json"
  csa_enum_opencode_project_targets "$root"
  csa_enum_codex_project_targets "$root"
}

# _csa_enum_oneline <string> — the string with newline, carriage return and tab
# escaped, so a name or path from untrusted input stays on one output line.
_csa_enum_oneline() {
  local s="$1"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

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

# _csa_enum_unread_hook_file <plugin-key> <path> [symlink] — the line, for
# stderr, that the rule engine turns into one High HOOK-005 for a hook file that
# is not read: by default because its name holds a newline or tab (it cannot be
# one line of the target list), with `symlink` because it is a symlink, which is
# never followed. The key is empty for a project file. Both are escaped onto one
# line; the optional third field is the word `symlink`.
_csa_enum_unread_hook_file() {
  if [[ "${3-}" == symlink ]]; then
    printf 'finding: HOOK-005\t%s\t%s\tsymlink\n' "$(_csa_enum_oneline "$1")" "$(_csa_enum_oneline "$2")"
  else
    printf 'finding: HOOK-005\t%s\t%s\n' "$(_csa_enum_oneline "$1")" "$(_csa_enum_oneline "$2")"
  fi
}

# _csa_enum_hook_symlinks <plugin-key> <hooks-dir> — for stderr, one HOOK-005
# line (_csa_enum_unread_hook_file ... symlink) for <hooks-dir> when it is a
# symlink itself, else one per symlink below it, to a file or to a directory,
# except below a node_modules/ under <hooks-dir> (package-manager links into
# code that is never read there, #1150; the test is relative to <hooks-dir>, so
# a root that itself sits below a node_modules/ keeps its stops). A symlink is
# never followed, so what it points at is not read; the stop says so.
# Skill-first question 3: it only adds a stop. A missing <hooks-dir> is no line
# and rc 0, and a find that fails part way still returns 0, so the caller's
# `set -euo pipefail` (bin/csa) never ends the enumeration here.
_csa_enum_hook_symlinks() {
  local key="$1" dir="$2" l q
  if [[ -L "$dir" ]]; then
    _csa_enum_unread_hook_file "$key" "$dir" symlink
    return 0
  fi
  q="$(_csa_enum_glob_quote "$dir")"
  find "$dir" -mindepth 1 -type l ! -path "$q/node_modules/*" ! -path "$q/*/node_modules/*" -print0 2>/dev/null \
    | while LC_ALL=C IFS= read -r -d '' l; do _csa_enum_unread_hook_file "$key" "$l" symlink; done || :
  return 0
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
  find "$dir" ${skip[@]+"${skip[@]}"} -type d -print0 2>/dev/null | while LC_ALL=C IFS= read -r -d '' d; do
    [[ -r "$d" && -x "$d" ]] \
      || printf 'finding: SCANNER-003\t%s\t%s\n' "$(_csa_enum_oneline "$key")" "$(_csa_enum_oneline "$d")"
  done || :
  return 0
}

# _csa_enum_settings_plugin_list <settings-file> — the file's enabledPlugins as
# one compact JSON object, plugin key to boolean. Claude Code writes an object
# map (`{"plugin@marketplace": true}`); only boolean values are kept. An array
# of names (fixtures, older files) reads as each name `true`. An absent file,
# malformed JSON (SETTINGS-PARSE is the rule engine's concern) or an absent key
# reads as {}. A value that holds entries yet yields none (a string, a number,
# an array of non-strings, an object of non-booleans) also reads as {}, but
# warns on stderr naming the shape: an audit that silently skips every plugin
# reads as a clean one. A path that exists but is not a regular file, or cannot
# be read, is NOT an empty set: rc 2 (#424).
_csa_enum_settings_plugin_list() {
  local f="$1" out list warn
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
  # were usable, else empty.
  out="$(jq -r '
    .enabledPlugins as $e
    | (if ($e | type) == "object" then $e | with_entries(select((.value | type) == "boolean"))
       elif ($e | type) == "array" then [$e[] | select(type == "string") | {key: ., value: true}] | from_entries
       else {} end) as $m
    | ($m | tojson),
      (if ($m | length) == 0 and (($e | type) == "string" or ($e | type) == "number" or $e == true
            or ((($e | type) == "object" or ($e | type) == "array") and ($e | length) > 0))
       then ($e | type) else "" end)
  ' "$f" 2>/dev/null)" || out=$'{}\n'
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
  project_map="$(_csa_enum_settings_plugin_list "$root/.claude/settings.json")" || return 2
  local_map="$(_csa_enum_settings_plugin_list "$root/.claude/settings.local.json")" || return 2
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
# `/.claude/plugins/` shape survives a symlinked home. rc 1 prints why not.
# A project under audit is hostile input and the install record is read from
# the user's home: neither may point the scan at /etc or at another project.
_csa_enum_guard_dir() {
  local p="$1" proot phys
  if [[ "$p" != /* ]]; then
    printf 'installPath %s is not absolute' "$(_csa_enum_oneline "$p")"
    return 1
  fi
  if ! proot="$(cd -- "${HOME}/.claude/plugins" 2>/dev/null && pwd -P)"; then
    printf 'installPath %s cannot be checked: %s/.claude/plugins is missing' "$(_csa_enum_oneline "$p")" "$HOME"
    return 1
  fi
  if [[ ! -d "$p" ]]; then
    printf 'installPath %s is not a directory' "$(_csa_enum_oneline "$p")"
    return 1
  fi
  if ! phys="$(cd -- "$p" 2>/dev/null && pwd -P)"; then
    printf 'installPath %s cannot be entered' "$(_csa_enum_oneline "$p")"
    return 1
  fi
  case "$phys" in
    "$proot"/?*) : ;;
    *)
      printf 'installPath %s resolves outside %s' "$(_csa_enum_oneline "$p")" "$proot"
      return 1
      ;;
  esac
  if [[ "$phys" == *$'\n'* || "$phys" == *$'\t'* ]]; then
    printf 'installPath %s holds a tab or newline' "$(_csa_enum_oneline "$p")"
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
  # A file below a plugin's hooks/ whose path there holds a newline or tab would
  # split or truncate as a target line (the rules gate on the hooks/ layout,
  # which a fragment loses), so it is left out of the list and reported as one
  # HOOK-005 naming the plugin and the file. A symlink below hooks/, or hooks/
  # as one, is never followed and is one HOOK-005 too. Skill-first question 3:
  # each only adds a stop. Every other file is listed as before.
  local hpat f
  {
    [[ -n "$project_targets" ]] && printf '%s\n' "$project_targets"
    while LC_ALL=C IFS=$'\t' read -r plugin_name plugin_path; do
      [[ -z "$plugin_name" ]] && continue
      hpat="$(_csa_enum_glob_quote "$plugin_path")/hooks/*"
      _csa_enum_hook_symlinks "$plugin_name" "$plugin_path/hooks" >&2
      # A plugin with no hooks/ makes this find fail: `|| :` keeps that from
      # ending the group under bin/csa's `set -euo pipefail`.
      find "$plugin_path/hooks" -type f \( -path "$hpat"$'\n'"*" -o -path "$hpat"$'\t'"*" \) -print0 2>/dev/null \
        | while LC_ALL=C IFS= read -r -d '' f; do _csa_enum_unread_hook_file "$plugin_name" "$f" >&2; done || :
      # A dir find cannot read makes it exit 1: `|| :` keeps that from ending the group under bin/csa's
      # `set -euo pipefail` and dropping the plugins after this one, and each such dir is one SCANNER-003 (#1149).
      find "$plugin_path" -type f ! -path "$hpat"$'\n'"*" ! -path "$hpat"$'\t'"*" 2>/dev/null \
        | CSA_LABEL="$plugin_name" CSA_PREFIX="$plugin_path/" awk '
            BEGIN { l = ENVIRON["CSA_LABEL"]; p = ENVIRON["CSA_PREFIX"]; n = length(p) }
            { rel = (substr($0, 1, n) == p) ? substr($0, n + 1) : $0
              printf "@plugin:%s:%s\t%s\n", l, rel, $0 }' || :
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
