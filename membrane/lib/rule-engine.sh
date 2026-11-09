#!/usr/bin/env bash
# lib/rule-engine.sh — runs rule files against target files.
# Per SPEC §8.1 (rule contract) and §12 (T2-G rule-load failure visibility).
# Requires: lib/helpers.sh (_csa_re_bytes; without it the plugin hook-entry tests are a silent false) and
# lib/fingerprint.sh (csa_normalize_path). bin/csa sources every lib.

# The structural hook-entry reader (#427); bin/csa sources every lib, a test may not.
if ! declare -F csa_hook_entries >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  source "${CSA_LIB_DIR:-$(dirname "${BASH_SOURCE[0]:-$0}")}/hook-entries.sh" 2>/dev/null || true
fi

# csa_rule_run_one <rule_file> <target_file>
# Sources rule in a subshell, calls detect, emits findings JSONL on stdout.
# On source failure: emits SCANNER-001 (High).
# Empty output with exit 1 means no match (grep-compatible detector contract).
# Any other non-zero result emits SCANNER-002 (High), including exit 1 with
# output because a detector must not mix findings with a no-match status.
# SCANNER-003 (Medium) is the engine's own: a target no rule could read, emitted once
# per target by csa_rule_engine_scan_all (_csa_unreadable_targets_findings), or a
# directory the enumeration could not read (_csa_enum_stderr_to_findings).
csa_rule_run_one() {
  local rule_file="$1"; local target_file="$2"
  local rule_id; rule_id="$(basename "$rule_file" .sh)"
  (
    set -u
    if ! source "$rule_file" 2>/dev/null; then
      jq -nc --arg rid "SCANNER-001" --arg f "$rule_file" \
        '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "rule failed to load", severity: "high", context: {failed_rule: $f}}'
      return 0
    fi
    if ! declare -f detect >/dev/null; then
      jq -nc --arg rid "SCANNER-001" --arg f "$rule_file" \
        '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "rule has no detect() function", severity: "high"}'
      return 0
    fi
    local out ec=0
    out="$(detect "$target_file" 2>/dev/null)" || ec=$?
    if [[ "$ec" -eq 1 && -z "$out" ]]; then
      return 0
    fi
    if [[ "$ec" -ne 0 ]]; then
      jq -nc --arg rid "SCANNER-002" --arg f "$target_file" --arg r "$rule_file" \
        '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "detect() failed", severity: "high", context: {failed_rule: $r, exit_code: '"$ec"'}}'
      return 0
    fi
    printf '%s\n' "$out"
  )
}

# _csa_hook_target_mode <target> — print `wrapped`, `plugin-hooks` or
# `plugin-manifest` when the target is a JSON file whose hook entries are read
# structurally (#427); print nothing otherwise. EXACT matches only: the project's
# own .claude/settings.json and .claude/settings.local.json by full path (never a
# nested copy), and an enabled plugin's hooks/hooks.json (whose `modules` list is
# read too) or .claude-plugin/plugin.json by normalized id. A plugin's fixtures/
# or tests/ copy, or a layout that does not normalize to
# @plugin:<plugin>@<marketplace>: (a local/ plugin, an installPath outside the
# cache), is not walked.
_csa_hook_target_mode() {
  local t="$1" root="${_CSA_ENGINE_ROOT:-${CSA_PROJECT_ROOT:-}}" n
  if [[ -n "$root" ]]; then
    root="${root%/}"
    if [[ "$t" == "$root/.claude/settings.json" || "$t" == "$root/.claude/settings.local.json" ]]; then
      printf 'wrapped'
      return 0
    fi
  fi
  [[ "$t" == *.json ]] || return 0
  declare -F csa_normalize_path >/dev/null 2>&1 || return 0
  n="$(csa_normalize_path "$t")"
  local re_h='^@plugin:[^:/]+@[^:/]+:hooks/hooks\.json$'
  local re_m='^@plugin:[^:/]+@[^:/]+:\.claude-plugin/plugin\.json$'
  if _csa_re_bytes "$n" "$re_h"; then
    printf 'plugin-hooks'
  elif _csa_re_bytes "$n" "$re_m"; then
    printf 'plugin-manifest'
  fi
  return 0
}

# _csa_hook_entries_file <target> <mode> — print the path of a file holding the
# walked entries of one target. With a run cache (_CSA_HOOK_CACHE_DIR, set by
# csa_rule_engine_scan_all) the target is walked once per run, however many rules
# read it; the run cleans the cache up. Without one the file is a temp the
# caller removes (printed second line `tmp`).
_csa_hook_entries_file() {
  local target="$1" mode="$2" cf
  if [[ -n "${_CSA_HOOK_CACHE_DIR:-}" ]]; then
    cf="$_CSA_HOOK_CACHE_DIR/$(csa_sha256 "$target")"
    if [[ ! -f "$cf" ]]; then
      # A failed or partial walk is rc 1 and is never cached: the cache is run-wide, so a
      # partial one would silence the file for every rule (#1089). Skill-first question 3.
      if ! csa_hook_entries "$target" "$mode" > "$cf.tmp" 2>/dev/null; then
        rm -f "$cf.tmp"
        return 1
      fi
      mv "$cf.tmp" "$cf" || { rm -f "$cf.tmp"; return 1; }
      # The .target file feeds only the coverage line: a failed write costs that line a count,
      # never the walk that succeeded.
      { printf '%s\n' "$target" > "$cf.target"; } 2>/dev/null || rm -f "$cf.target" 2>/dev/null
    fi
    printf '%s\n' "$cf"
  else
    cf="$(mktemp "${TMPDIR:-/tmp}/csa-hook-entries.XXXXXX")" || return 1
    if ! csa_hook_entries "$target" "$mode" > "$cf" 2>/dev/null; then
      rm -f "$cf"
      return 1
    fi
    printf '%s\ntmp\n' "$cf"
  fi
}

# _csa_rule_run_text <rule_file> <target> <mode>
# Runs in the rule's subshell (detect_text is defined). Feeds each walked entry
# to detect_text; a rule that sets RULE_TEXT_SCOPE=file gets all of the file's
# entries in one call. Same result contract as detect: exit 1 with no output is
# no match; any other non-zero is SCANNER-002.
_csa_rule_run_text() {
  local rule_file="$1" target="$2" mode="$3" info cf tmp="" entry out ec
  # A failed mktemp or walk is a SCANNER-002 for the target, not a skip (#1089). Skill-first question 3.
  if ! info="$(_csa_hook_entries_file "$target" "$mode")"; then
    jq -nc --arg rid "SCANNER-002" --arg f "$target" --arg r "$rule_file" \
      '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "hook entries could not be read", severity: "high", context: {failed_rule: $r, exit_code: 1}}'
    return 0
  fi
  cf="$(printf '%s\n' "$info" | sed -n 1p)"
  [[ "$(printf '%s\n' "$info" | sed -n 2p)" == "tmp" ]] && tmp="$cf"
  if [[ "${RULE_TEXT_SCOPE:-entry}" == "file" ]]; then
    entry="$(cat "$cf")"
    if [[ -n "$entry" ]]; then
      _csa_rule_text_once "$rule_file" "$target" "$entry"
    fi
  else
    while LC_ALL=C IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      _csa_rule_text_once "$rule_file" "$target" "$entry"
    done < "$cf"
  fi
  [[ -n "$tmp" ]] && rm -f "$tmp"
  return 0
}

_csa_rule_text_once() {
  local rule_file="$1" target="$2" entry="$3" out jp ec=0
  out="$(detect_text "$entry" "$target" 2>/dev/null)" || ec=$?
  if [[ "$ec" -eq 1 && -z "$out" ]]; then
    return 0
  elif [[ "$ec" -ne 0 ]]; then
    # context.json_path names the entry when the call was for one (a file-scope
    # call has several), so the coverage line can stop counting it as checked.
    jp="$(printf '%s\n' "$entry" | jq -rs 'if length == 1 then (.[0].json_path? // "") else "" end' 2>/dev/null)" || jp=""
    jq -nc --arg rid "SCANNER-002" --arg f "$target" --arg r "$rule_file" --arg jp "$jp" \
      '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "detect_text() failed", severity: "high", context: ({failed_rule: $r, exit_code: '"$ec"'} + (if $jp == "" then {} else {json_path: $jp} end))}'
  elif [[ -n "$out" ]]; then
    printf '%s\n' "$out"
  fi
}

# _csa_unreadable_targets_findings <targets_file> <rules_dir>
# One SCANNER-003 (Medium) per enumerated target this process cannot read (#1089), when
# a rule in <rules_dir> (all rules, or the focused aspect's) would have read it. It is
# emitted here, once per target, and not in csa_rule_run_many: that runs once per rule, so
# it would repeat the finding for every rule that skipped the file, and 22 rules skip it
# silently on `[[ -r ]] || return 0`. Skill-first question 3: it can only add a stop; it
# never removes or approves a finding. SCANNER-003 is not a rule failure, so it stays out
# of the SCANNER-002 count that drives the "rule(s) failed" banner.
_csa_unreadable_targets_findings() {
  local target_line target rule_file aspect
  while LC_ALL=C IFS= read -r target_line; do
    [[ -z "$target_line" ]] && continue
    target="${target_line##*$'\t'}"
    [[ -r "$target" ]] && continue
    while LC_ALL=C read -r rule_file; do
      [[ -z "$rule_file" ]] && continue
      aspect="$(_csa_rule_aspect_from_file "$rule_file")"
      if [[ -z "$aspect" ]] || _csa_target_matches_aspect "$target" "$aspect"; then
        jq -nc --arg rid "SCANNER-003" --arg f "$target" \
          '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "target could not be read; rules skipped it", severity: "medium"}'
        break
      fi
    done < <(find "$2" -name '*.sh' -type f 2>/dev/null)
  done < "$1"
}

# csa_rule_run_many <rule_file> <targets_file>
# Source rule ONCE in a subshell, iterate targets_file, call detect per target.
# More efficient than calling csa_rule_run_one per target (amortizes source cost).
csa_rule_run_many() {
  local rule_file="$1"; local targets_file="$2"
  (
    set -u
    if ! source "$rule_file" 2>/dev/null; then
      jq -nc --arg rid "SCANNER-001" --arg f "$rule_file" \
        '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "rule failed to load", severity: "high", context: {failed_rule: $f}}'
      return 0
    fi
    if ! declare -f detect >/dev/null; then
      jq -nc --arg rid "SCANNER-001" --arg f "$rule_file" \
        '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "rule has no detect() function", severity: "high"}'
      return 0
    fi
    local has_text=0
    declare -f detect_text >/dev/null && has_text=1
    while LC_ALL=C IFS= read -r target_line; do
      [[ -z "$target_line" ]] && continue
      local target="${target_line##*$'\t'}"
      local out ec=0 mode=""
      # A hook-bearing JSON target goes to detect_text, one decoded entry at a
      # time (#427). Any other target, or a rule with no detect_text, is detect.
      if [[ "$has_text" -eq 1 ]]; then
        mode="$(_csa_hook_target_mode "$target")"
      fi
      if [[ -n "$mode" ]]; then
        _csa_rule_run_text "$rule_file" "$target" "$mode"
        continue
      fi
      out="$(detect "$target" 2>/dev/null)" || ec=$?
      if [[ "$ec" -eq 1 && -z "$out" ]]; then
        continue
      elif [[ "$ec" -ne 0 ]]; then
        jq -nc --arg rid "SCANNER-002" --arg f "$target" --arg r "$rule_file" \
          '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "detect() failed", severity: "high", context: {failed_rule: $r, exit_code: '"$ec"'}}'
      else
        printf '%s\n' "$out"
      fi
    done < "$targets_file"
  )
}

# csa_rule_engine_scan_files <rule_file> <target_file_1> [<target_file_2> ...]
csa_rule_engine_scan_files() {
  local rule_file="$1"; shift
  for t in "$@"; do
    csa_rule_run_one "$rule_file" "$t"
  done
}

# _csa_rule_aspect_from_file <rule_file>
# Extract RULE_ASPECT via grep (no subshell source — fast metadata read).
_csa_rule_aspect_from_file() {
  grep -m1 '^RULE_ASPECT=' "$1" 2>/dev/null | sed 's/^RULE_ASPECT=//' | tr -d '"'\'
}

# _csa_target_matches_aspect <target_path> <aspect>
# Returns 0 (match) or 1 (skip) based on aspect-to-file-extension heuristic.
# Secrets rules run on any text file; aspect-specific rules filter tightly.
_csa_target_matches_aspect() {
  local target="$1"
  local aspect="$2"
  local base; base="$(basename "$target")"
  case "$aspect" in
    permissions)
      [[ "$base" == "settings.json" || "$base" == "settings.local.json" ]] && return 0
      return 1
      ;;
    hooks)
      # OpenCode code outside bin/ (lib/, plugin/) runs too (#127).
      if [[ "$target" == *.sh || "$target" == */.opencode/bin/* \
            || "$target" == */.opencode/*.js || "$target" == */.opencode/*.ts \
            || "$target" == */.opencode/*.mjs ]]; then
        return 0
      fi
      [[ "$target" == */.claude/hooks/* && -x "$target" ]] && return 0
      # Hook handler code under a plugin's hooks/ or the project's .claude/hooks/, and an executable plugin
      # hooks/ file with no code suffix (lib/hook-entries.sh, csa_hook_handler_file).
      csa_hook_handler_file "$target" && return 0
      # Hook entries declared in JSON: settings, a plugin's hooks.json / plugin.json (#427).
      [[ -n "$(_csa_hook_target_mode "$target")" ]] && return 0
      return 1
      ;;
    marketplace)
      [[ "$base" == "marketplace.json" ]] && return 0
      return 1
      ;;
    mcp)
      [[ "$target" == *.json ]] && return 0
      return 1
      ;;
    claude-md)
      [[ "$base" == "CLAUDE.md" ]] && return 0
      return 1
      ;;
    prompt-injection)
      [[ "$target" == *.md ]] && return 0
      return 1
      ;;
    secrets)
      # Secrets rules scan text-like files and executable Claude hook handlers.
      # TOML, YAML and JSONC configs are enumerated, so they are scanned too (#121), and so is node module
      # code, .mjs .cjs .tsx .jsx .mts .cts (#1141).
      [[ "$target" == *.md || "$target" == *.json || "$target" == *.sh \
         || "$target" == *.toml || "$target" == *.yaml || "$target" == *.yml \
         || "$target" == *.jsonc \
         || "$target" == *.py || "$target" == *.js || "$target" == *.ts \
         || "$target" == *.mjs || "$target" == *.cjs || "$target" == *.tsx || "$target" == *.jsx \
         || "$target" == *.mts || "$target" == *.cts \
         || "$target" == */.opencode/bin/* ]] && return 0
      [[ "$target" == */.claude/hooks/* && -x "$target" ]] && return 0
      return 1
      ;;
    test)
      # Synthetic test rules: run on everything (used by e2e tests).
      return 0
      ;;
    *)
      # Unknown aspect: run on everything (conservative fallback).
      return 0
      ;;
  esac
}

# _csa_rule_engine_validate_focus <focus>
# Accept all or an aspect directory shipped in CSA_RULES_DIR.
_csa_rule_engine_validate_focus() {
  local focus="$1" aspect_dir
  [[ "$focus" == "all" ]] && return 0
  for aspect_dir in "$CSA_RULES_DIR"/*; do
    [[ -d "$aspect_dir" ]] || continue
    [[ "$(basename "$aspect_dir")" == "$focus" ]] && return 0
  done
  printf 'Unknown rule aspect: %s\n' "$focus" >&2
  return 2
}

# _csa_enum_stderr_to_findings <enumeration-stderr>
# Turns each `finding: PROVENANCE-002 plugin <key> enabled but <reason>` line,
# and each `finding: HOOK-005` line for a hook file whose name holds a newline or
# tab or that is a symlink, into a High finding JSONL record on stdout, each
# `finding: SCANNER-003` line for a directory the enumeration could not read into
# a Medium one, and passes every `csa:` line on to stderr. Other lines (info
# notes) are dropped, as they always were on success.
_csa_enum_stderr_to_findings() {
  local line rest key reason fuid file why head tab=$'\t'
  while LC_ALL=C IFS= read -r line; do
    case "$line" in
      "finding: PROVENANCE-002 plugin "*" enabled but "*)
        rest="${line#finding: PROVENANCE-002 plugin }"
        key="${rest%% enabled but *}"
        reason="${rest#* enabled but }"
        file="@plugin:$key"
        fuid=""
        if declare -F csa_finding_uid_raw >/dev/null 2>&1; then
          fuid="$(csa_finding_uid_raw "PROVENANCE-002" "$file" "$key")"
        fi
        jq -nc --arg key "$key" --arg reason "$reason" --arg file "$file" --arg fuid "$fuid" '
          {rule_id: "PROVENANCE-002", file: $file, line: 0, offset: 0,
           preview: ("plugin " + $key + " is enabled but " + $reason),
           severity: "high", context: {plugin: $key, reason: $reason}}
          + (if $fuid == "" then {} else {finding_uid: $fuid} end)'
        ;;
      "finding: HOOK-005$tab"*"$tab"*)
        # A hook file left unread (_csa_enum_unread_hook_file): `finding:
        # HOOK-005<TAB><plugin key or empty><TAB><path>` because its name holds
        # a newline or tab, with `<TAB>symlink` after the path because it is a
        # symlink. Key and path are escaped onto one line, so neither holds a tab.
        rest="${line#"finding: HOOK-005$tab"}"
        key="${rest%%"$tab"*}"
        file="${rest#*"$tab"}"
        # why: the uid's excerpt; reason and head: the record's text.
        why="name holds a newline or tab"
        reason="name holds a newline or tab; not read"
        head="hook file not read: its name holds a newline or tab"
        if [[ "$file" == *"${tab}symlink" ]]; then
          file="${file%"${tab}symlink"}"
          why="symlink; not followed"
          reason="symlink; not followed"
          head="hook path not read: it is a symlink, which is never followed"
        fi
        fuid=""
        if declare -F csa_finding_uid_raw >/dev/null 2>&1; then
          fuid="$(csa_finding_uid_raw "HOOK-005" "$file" "$why")"
        fi
        jq -nc --arg key "$key" --arg file "$file" --arg fuid "$fuid" --arg reason "$reason" --arg head "$head" '
          {rule_id: "HOOK-005", file: $file, line: 0, offset: 0,
           preview: ($head + (if $key == "" then "" else " (plugin " + $key + ")" end)),
           severity: "high",
           context: ({reason: $reason}
                     + (if $key == "" then {} else {plugin: $key} end))}
          + (if $fuid == "" then {} else {finding_uid: $fuid} end)'
        ;;
      "finding: SCANNER-003$tab"*"$tab"*)
        # A dir find could not read (_csa_enum_unreadable_dirs, #1149): `finding: SCANNER-003<TAB><plugin key or
        # empty><TAB><dir>`. No uid: a SCANNER finding is reported on every run and never registered.
        rest="${line#"finding: SCANNER-003$tab"}"
        key="${rest%%"$tab"*}"
        file="${rest#*"$tab"}"
        jq -nc --arg key "$key" --arg file "$file" '
          {rule_id: "SCANNER-003", file: $file, line: 0, offset: 0,
           preview: ("directory could not be read; nothing below it was scanned"
                     + (if $key == "" then "" else " (plugin " + $key + ")" end)),
           severity: "medium",
           context: ({reason: "directory not readable"} + (if $key == "" then {} else {plugin: $key} end))}'
        ;;
      "csa: "*) printf '%s\n' "$line" >&2 ;;
    esac
  done <<< "${1-}"
  return 0
}

# _csa_hook_coverage_line <cache_dir> <findings_file>
# Prints `csa: hook-coverage checked=N flagged=N not-inspected=N unreadable=N modules=N` on stderr.
# checked: command entries read and matched against the HOOK patterns by every
# rule; flagged: those of them with at least one finding; not-inspected: entries
# of another type; unreadable: entries (or files) that could not be read, plus
# command entries whose match failed in a rule (SCANNER-002 naming the entry's
# json_path), which are not checked. flagged is a subset of checked (#1072 C5,
# orchestrator ruling): an entry one rule flags and another rule fails on counts
# as unreadable, so it is not flagged either, though its finding still prints.
# modules: a plugin hooks/hooks.json's `modules` paths that resolved to handler
# code inside its hooks/ dir (each module file is read as a target of its own);
# a modules path that did not resolve is an inconclusive line, so unreadable.
# A clean count cannot come from the
# findings, so it travels as this line and the skill hands it to the report header.
_csa_hook_coverage_line() {
  local cache="$1" findings="$2" all t target c
  all="$(mktemp "${TMPDIR:-/tmp}/csa-hook-cov.XXXXXX")"
  for t in "$cache"/*.target; do
    [[ -f "$t" ]] || continue
    target="$(cat "$t")"
    c="${t%.target}"
    jq -c --arg f "$target" '. + {file: $f}' "$c" >> "$all" 2>/dev/null
  done
  if ! jq -nr --slurpfile e "$all" --slurpfile f "$findings" '
      def key: .file + "\u001f" + .context.json_path;
      def named: objects | select((.context | objects | .json_path? // null) != null);
      ([$f[] | named | select(.rule_id == "SCANNER-002") | key] | map({key: ., value: true}) | from_entries) as $failed
      | ([$f[] | named | key] | map({key: ., value: true}) | from_entries) as $flagged
      | [$e[] | select(.type == "command" and has("text"))] as $cmd
      | [$cmd[] | select($failed[.file + "\u001f" + .json_path] | not)] as $ok
      | "csa: hook-coverage checked=\($ok | length)"
        + " flagged=\([$ok[] | select($flagged[.file + "\u001f" + .json_path])] | length)"
        + " not-inspected=\([$e[] | select(has("inconclusive") | not) | select(has("module") | not) | select(.type != "command")] | length)"
        + " unreadable=\([$e[] | select(has("inconclusive"))] | length + ($cmd | length) - ($ok | length))"
        + " modules=\([$e[] | select(has("inconclusive") | not) | select(has("module"))] | length)"' >&2 2>/dev/null; then
    printf 'csa: hook-coverage unavailable\n' >&2
  fi
  rm -f "$all"
}

# csa_rule_engine_scan_all <project_root> [<focus>]
# Discovers all rule files (filtered by focus aspect), runs the matrix.
# Uses aspect-based pre-filtering to reduce rule×target cross-product.
# Emits SCANNER-002 banner on stderr if 3+ SCANNER-002 findings emerge.
csa_rule_engine_scan_all() {
  local root="$1"; local focus="${2:-all}"
  # Trailing slashes off: targets are enumerated as "$root/.claude/...", and
  # _csa_hook_target_mode compares them to that exact path (#1059 C2). Holds for any root
  # other than "/"; for "/" itself the settings hooks are still skipped, as before 0.3.1.
  while [[ "$root" == ?*/ ]]; do root="${root%/}"; done
  if ! _csa_rule_engine_validate_focus "$focus"; then
    return 2
  fi
  local rules_glob="$CSA_RULES_DIR"
  if [[ "$focus" != "all" ]]; then
    rules_glob="$CSA_RULES_DIR/$focus"
  fi
  local scanner_002_count=0
  local findings_out; findings_out="$(mktemp)"
  # Pre-collect targets once (avoids re-running enumeration per rule).
  local targets_file; targets_file="$(mktemp)"
  local enum_error
  if ! enum_error="$(csa_enum_targets_all "$root" 2>&1 > "$targets_file")"; then
    printf '%s\n' "$enum_error" >&2
    rm -f "$findings_out" "$targets_file"
    return 2
  fi
  # Hook entries walked by the hooks aspect are cached per target for this run.
  _CSA_ENGINE_ROOT="$root"
  _CSA_HOOK_CACHE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/csa-hook-cache.XXXXXX")"
  # On success enumeration's stderr still carries two things that must not be
  # lost: PROVENANCE-002 lines (an enabled plugin that did not resolve is a
  # High finding, not a note) and `csa:` warnings (an enabledPlugins shape the
  # reader could not use).
  _csa_enum_stderr_to_findings "$enum_error" >> "$findings_out"
  _csa_unreadable_targets_findings "$targets_file" "$rules_glob" >> "$findings_out"
  while LC_ALL=C read -r rule_file; do
    [[ -z "$rule_file" ]] && continue
    local aspect; aspect="$(_csa_rule_aspect_from_file "$rule_file")"
    # Build a filtered targets file for this rule's aspect.
    local rule_targets_file
    if ! rule_targets_file="$(mktemp)"; then
      # No target list for this rule: a SCANNER-002 for the rule, not a silent skip (#1089).
      jq -nc --arg rid "SCANNER-002" --arg f "$rule_file" --arg r "$rule_file" \
        '{rule_id: $rid, file: $f, line: 0, offset: 0, preview: "targets could not be listed for this rule", severity: "high", context: {failed_rule: $r, exit_code: 1}}' >> "$findings_out"
      continue
    fi
    if [[ -n "$aspect" ]]; then
      while LC_ALL=C IFS= read -r target_line; do
        [[ -z "$target_line" ]] && continue
        local target="${target_line##*$'\t'}"
        if _csa_target_matches_aspect "$target" "$aspect"; then
          printf '%s\n' "$target_line"
        fi
      done < "$targets_file" > "$rule_targets_file"
    else
      cp "$targets_file" "$rule_targets_file"
    fi
    # Source rule once and iterate all matching targets.
    csa_rule_run_many "$rule_file" "$rule_targets_file" >> "$findings_out"
    rm -f "$rule_targets_file"
  done < <(find "$rules_glob" -name '*.sh' -type f 2>/dev/null)
  cat "$findings_out"
  if [[ "$focus" == "all" || "$focus" == "hooks" ]]; then
    _csa_hook_coverage_line "$_CSA_HOOK_CACHE_DIR" "$findings_out"
  fi
  rm -rf "$_CSA_HOOK_CACHE_DIR"
  unset _CSA_HOOK_CACHE_DIR _CSA_ENGINE_ROOT
  scanner_002_count="$(grep -c 'SCANNER-002' "$findings_out" 2>/dev/null || true)"
  if [[ "$scanner_002_count" -ge 3 ]]; then
    printf '⚠ %d rule(s) failed during scan; results incomplete. See SCANNER-002 findings.\n' "$scanner_002_count" >&2
  fi
  rm -f "$findings_out" "$targets_file"
}
