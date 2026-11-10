#!/usr/bin/env bash
# lib/report-render.sh — chat summary + markdown report file for membrane.
# Requires: lib/helpers.sh; lib/fingerprint.sh (csa_normalize_path), used only to group findings.

# The plugin root, for the footer's version: CSA_PLUGIN_ROOT (bin/csa sets it from its own location), else this file's.
_CSA_RENDER_ROOT="${BASH_SOURCE[0]%/*}/.."
# Bash 3.2+ compatible (macOS portability).

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _csa_count_sev <findings_jsonl> <severity> <state_filter>
# Print count of findings matching severity and state ("NEW"|"PERSISTED"|"SUPPRESSED"|"*").
_csa_count_sev() {
  local findings_jsonl="$1"
  local severity="$2"
  local state_filter="$3"

  if [[ -z "$findings_jsonl" ]]; then
    printf '0'
    return
  fi

  local count=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local sev st
    sev="$(printf '%s' "$line" | jq -r '.severity // empty')"
    st="$(printf '%s' "$line" | jq -r '.state // "NEW"')"
    [[ "$sev" == "$severity" ]] || continue
    if [[ "$state_filter" == "*" ]] || [[ "$st" == "$state_filter" ]]; then
      count=$((count + 1))
    fi
  done <<< "$findings_jsonl"

  printf '%d' "$count"
}

# _csa_severity_label <severity> — title-case label for severity.
_csa_severity_label() {
  case "$1" in
    critical) printf 'Critical' ;;
    high)     printf 'High'     ;;
    medium)   printf 'Medium'   ;;
    low)      printf 'Low'      ;;
    info)     printf 'Info'     ;;
    *)        printf '%s' "$1"  ;;
  esac
}

# ---------------------------------------------------------------------------
# Finding groups (#1034). Two kinds of finding are folded into one count line in chat; the markdown
# report still lists them at full severity, tagged with the group. Nothing here changes a count, a
# severity, a state or a uid.
#
# _csa_finding_group <file> — prints the group tag of a finding's file, or nothing. THE one definition:
#   "plugin fixtures/tests"  an enabled plugin's file with a `fixtures` or `tests` directory segment
#                            anywhere in its path inside the plugin tree (csa_normalize_path's
#                            @plugin:<plugin>[@<marketplace>]:<rest>; a file merely NAMED tests is not
#                            in it). A plugin whose layout does not normalize (a local plugin, an
#                            installPath outside the cache) is not grouped, so it stays listed.
#   "agent scratch"          a file under the project's own `.dagr/scratch/` (project root:
#                            CSA_PROJECT_ROOT, else the working directory; its physical path too, which
#                            the engine's file paths start with).
# A project's own `tests/` or `fixtures/` is NOT in a group. Anything that does not match is listed in
# chat as before, and if csa_normalize_path is not loaded no plugin file is grouped (listed, never hidden).
# Skill-first question 2: our own path shapes, a closed set.
# ---------------------------------------------------------------------------
_csa_finding_group() {
  local f="$1" norm rest root="${CSA_PROJECT_ROOT:-$PWD}" rootp
  if declare -F csa_normalize_path >/dev/null 2>&1; then
    norm="$(csa_normalize_path "$f")"
    if [[ "$norm" == @plugin:* ]]; then
      rest="${norm#@plugin:}"; rest="${rest#*:}"
      if [[ "/$rest" == */fixtures/* || "/$rest" == */tests/* ]]; then
        printf 'plugin fixtures/tests'
        return 0
      fi
      return 0
    fi
  fi
  while [[ "$root" == ?*/ ]]; do root="${root%/}"; done
  if [[ "$f" == .dagr/scratch/* || "$f" == "$root"/.dagr/scratch/* ]]; then
    printf 'agent scratch'
  elif [[ "$f" == /*/.dagr/scratch/* ]] && rootp="$(cd -P -- "$root" 2>/dev/null && pwd -P)" \
    && rootp="$(_csa_lead_slash "$rootp")" && [[ "$f" == "${rootp%/}"/.dagr/scratch/* ]]; then
    printf 'agent scratch'
  fi
  return 0
}

# _csa_group_count_line <findings_jsonl> — one line, or nothing when no non-suppressed finding is in a group.
_csa_group_count_line() {
  local findings_jsonl="$1" line file sev st n=0 c=0 h=0 m=0 l=0 i=0 o=0 g
  [[ -n "$findings_jsonl" ]] || return 0
  # Same extraction as the chat list (jq -r .file per line), so a finding is counted here exactly when it is not listed there.
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    st="$(printf '%s' "$line" | jq -r '.state // "NEW"')"
    [[ "$st" != "SUPPRESSED" ]] || continue
    file="$(printf '%s' "$line" | jq -r '.file // ""')"
    g="$(_csa_finding_group "$file")"
    [[ -n "$g" ]] || continue
    sev="$(printf '%s' "$line" | jq -r '.severity // empty')"
    n=$((n + 1))
    case "$sev" in
      critical) c=$((c + 1)) ;; high) h=$((h + 1)) ;; medium) m=$((m + 1)) ;;
      low) l=$((l + 1)) ;; info) i=$((i + 1)) ;;
      *) o=$((o + 1)) ;;   # a missing or unknown severity: the total stays the sum of what is printed
    esac
  done <<< "$findings_jsonl"
  [[ "$n" -gt 0 ]] || return 0
  local extra=""
  [[ "$l" -eq 0 ]] || extra="$extra, $l low"
  [[ "$i" -eq 0 ]] || extra="$extra, $i info"
  [[ "$o" -eq 0 ]] || extra="$extra, $o other"
  printf '%d %s in plugin fixtures/tests and agent scratch copies (%d critical, %d high, %d medium%s); listed in the report\n\n' \
    "$n" "$([[ "$n" -eq 1 ]] && printf finding || printf findings)" "$c" "$h" "$m" "$extra"
}

# _csa_findings_arg <findings_jsonl or path> — print the findings and exit 0, or exit 4 with one message.
# THE one reader of the three report functions' findings argument, read the way state_record_audit
# reads its own: a non-empty argument that does not start with `{` and names a file is read, and
# anything else is the findings themselves. Every non-blank line must be exactly one JSON object, or
# nothing is rendered: a line jq cannot read could be a Critical, so it is refused, never skipped or
# counted as zero. A line of only spaces or tabs is blank: it is not printed, so no caller counts,
# renders or numbers it. Empty or blank input is no findings. Exit 4 is suppress_stale's code for the
# same input. Skill-first question 2: membrane's own findings files, a closed shape.
_csa_findings_arg() {
  local x="$1" src="the findings"
  if [[ -n "$x" && "$x" != "{"* && -f "$x" ]]; then
    src="$x"
    x="$(cat "$x" 2>/dev/null)" || { printf 'csa: cannot read %s; nothing rendered\n' "$src" >&2; return 4; }
  elif [[ -n "$x" && "$x" != "{"* && "$x" != *$'\n'* ]]; then
    src="$x"   # one line that is not an object: most likely a path that does not exist
  fi
  [[ "$x" == *[![:space:]]* ]] || return 0
  # One pass: the non-blank lines, printed only when every one of them is one JSON object.
  local lines
  if ! lines="$(printf '%s\n' "$x" | jq -r -R -s '
      split("\n") | map(select(test("\\S")))
      | if all(.[]; (try fromjson catch null) | type == "object") then .[] else error("not findings JSONL") end' \
      2>/dev/null)"; then
    printf 'csa: %s is missing or is not findings JSONL (one JSON object per line); nothing rendered\n' "$src" >&2
    return 4
  fi
  printf '%s\n' "$lines"
}

# _csa_plugin_version — membrane's version from its own .claude-plugin/plugin.json, or `(version unknown)`.
_csa_plugin_version() {
  local v
  v="$(jq -r '.version | strings' "${CSA_PLUGIN_ROOT:-$_CSA_RENDER_ROOT}/.claude-plugin/plugin.json" 2>/dev/null)" || v=""
  [[ -n "$v" ]] && printf 'v%s' "$v" || printf '(version unknown)'
}

# _csa_suppression_lines <findings_jsonl> <project_root> — the lines chat and the report always print about
# suppressions.json: how many findings it hid (state SUPPRESSED, set by csa_suppress_filter; a number, 0 included),
# and, when <project_root>'s .claude/audits/state.json records no audit of the project while suppressions.json is
# there, a warning to read it first. A checkout that ships a state.json with an audit history silences the warning
# (the count still shows). Skill-first question 2: membrane's own files.
_csa_suppression_lines() {
  local findings_jsonl="$1" root="$2" n state recorded=0
  n="$(printf '%s\n' "$findings_jsonl" | jq -s '[.[] | objects | select(.state == "SUPPRESSED")] | length' 2>/dev/null)" || n=""
  if [[ -z "$n" ]]; then
    printf 'Suppressed: the count could not be read; pass --show-suppressed to see every finding.\n'
  else
    printf 'Suppressed: %d %s hidden by .claude/audits/suppressions.json%s.\n' "$n" \
      "$([[ "$n" -eq 1 ]] && printf finding || printf findings)" \
      "$([[ "$n" -eq 0 ]] || printf ' (counted in the table, not listed in chat; the report lists each, marked SUPPRESSED)')"
  fi
  while [[ "$root" == ?*/ ]]; do root="${root%/}"; done
  state="$root/.claude/audits/state.json"
  if [[ -f "$state" ]] && jq -e '((.audit_history | arrays | length) // 0) > 0' "$state" >/dev/null 2>&1; then
    recorded=1
  fi
  if [[ "$recorded" -eq 0 && ( -e "$root/.claude/audits/suppressions.json" || -L "$root/.claude/audits/suppressions.json" ) ]]; then
    printf '**Warning:** .claude/audits/suppressions.json is here, and .claude/audits/state.json records no audit of this project. So no `/security-audit --suppress` after a recorded audit here wrote it, unless state.json was removed since: it may have come with the checkout or been written by hand. Read it before you trust what it hides.\n'
  fi
}

# _csa_hook_commands_section <metadata_json> — the report's list of the hook commands the scan read
# (metadata.hook_commands: the file csa_rule_engine_scan_all wrote), each in its own fenced block.
_csa_hook_commands_section() {
  local f entries n line loc cmd fence run
  printf '## Hook commands read\n\n'
  printf 'These commands run automatically (at session start, around tool calls, and so on). A finding above means one of the common patterns matched; no finding does not mean a command is safe. Read each one.\n\n'
  f="$(printf '%s' "$1" | jq -r '.hook_commands // "" | strings' 2>/dev/null)" || f=""
  if [[ -z "$f" ]]; then
    printf '_Not listed: the scan'"'"'s hook-command list was not passed to the report._\n\n'
    return 0
  fi
  if ! entries="$(jq -c 'select(type == "object") | {file: (.file | tostring), json_path: (.json_path | tostring), command: (.command | tostring)}' "$f" 2>/dev/null)"; then
    printf '_Not listed: the hook-command list %s could not be read._\n\n' "$(csa_escape "$f")"
    return 0
  fi
  n=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    n=$((n + 1))
    loc="$(printf '%s' "$line" | jq -r '.file + "#" + .json_path')"
    cmd="$(printf '%s' "$line" | jq -r '.command')"
    # A fence longer than any backtick run in the command, so the command cannot end it.
    fence='```'; run='```'
    while [[ "$cmd" == *"$run"* ]]; do run="$run\`"; fence="$run"; done
    printf -- '- %s\n\n%s\n%s\n%s\n\n' "$(csa_escape "$loc")" "$fence" "$cmd" "$fence"
  done <<< "$entries"
  [[ "$n" -gt 0 ]] || printf 'No hook command was read in this scan.\n\n'
}

# ---------------------------------------------------------------------------
# csa_report_next_run_of_day <project_root>
# Count today's report files in .claude/audits/ (YYYY-MM-DD-*.md), return N+1 as 2-digit padded.
# ---------------------------------------------------------------------------
csa_report_next_run_of_day() {
  local root="$1"
  local today; today="$(date +%Y-%m-%d)"
  local audits_dir; audits_dir="$root/.claude/audits"
  local count=0

  if [[ -d "$audits_dir" ]]; then
    local f
    for f in "$audits_dir/${today}"-*.md; do
      [[ -f "$f" ]] && count=$((count + 1))
    done
  fi

  printf '%02d' $((count + 1))
}

# ---------------------------------------------------------------------------
# csa_report_assign_display_ids <findings_jsonl or path> <report-name>
# Read JSONL, augment each line with "display_id": "SA-<report-name>-<NNN>". The skill passes the
# report's name, <date>-<NN>, so the id is SA-<date>-<NN>-<NNN>: the prefix state_record_audit
# records from the report path. Prints augmented JSONL to stdout; exit 4 on input that is not
# findings JSONL (_csa_findings_arg).
# ---------------------------------------------------------------------------
csa_report_assign_display_ids() {
  local findings_jsonl date="$2"
  local ordinal=0
  findings_jsonl="$(_csa_findings_arg "$1")" || return 4

  if [[ -z "$findings_jsonl" ]]; then
    return
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    ordinal=$((ordinal + 1))
    local display_id
    display_id="$(printf 'SA-%s-%03d' "$date" "$ordinal")"
    printf '%s' "$line" | jq -c --arg did "$display_id" '. + {display_id: $did}'
  done <<< "$findings_jsonl"
}

# ---------------------------------------------------------------------------
# _csa_build_summary_table <findings_jsonl> [verbose]
# Print the markdown summary table.
# ---------------------------------------------------------------------------
_csa_build_summary_table() {
  local findings_jsonl="$1"
  local verbose="${2:-false}"

  local severities="critical high medium low info"
  local labels="Critical High Medium Low Info"

  printf '| Severity | NEW | Persisted | Suppressed | Total visible |\n'
  printf '|---|---|---|---|---|\n'

  local sev label
  local i=0
  for sev in $severities; do
    i=$((i + 1))
    # Extract label by position
    label="$(_csa_severity_label "$sev")"

    if [[ "$sev" == "info" && "$verbose" != "true" ]]; then
      printf '| %s | (suppressed; pass --verbose) | | | |\n' "$label"
      continue
    fi

    local n_new n_pers n_supp n_visible
    n_new="$(_csa_count_sev "$findings_jsonl" "$sev" "NEW")"
    n_pers="$(_csa_count_sev "$findings_jsonl" "$sev" "PERSISTED")"
    n_supp="$(_csa_count_sev "$findings_jsonl" "$sev" "SUPPRESSED")"
    n_visible=$((n_new + n_pers))

    printf '| %s | %d | %d | %d | %d |\n' "$label" "$n_new" "$n_pers" "$n_supp" "$n_visible"
  done
}

# ---------------------------------------------------------------------------
# csa_report_render_chat <findings_jsonl or path> [<report_path>] [verbose] [<project_root>]
# Emit chat-summary markdown to stdout; exit 4, printing nothing, on input that is not findings
# JSONL (_csa_findings_arg). The project root (default: the working directory) is read only for the
# suppressions.json lines (_csa_suppression_lines).
# ---------------------------------------------------------------------------
csa_report_render_chat() {
  local findings_jsonl report_path="${2:-}"
  local verbose="${3:-false}" root="${4:-$PWD}"
  findings_jsonl="$(_csa_findings_arg "$1")" || return 4

  # Also check environment variable.
  if [[ "${CSA_VERBOSE:-}" == "1" ]]; then
    verbose="true"
  fi

  # Count total visible findings (non-suppressed).
  local total_visible=0
  if [[ -n "$findings_jsonl" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local st
      st="$(printf '%s' "$line" | jq -r '.state // "NEW"')"
      if [[ "$st" != "SUPPRESSED" ]]; then
        total_visible=$((total_visible + 1))
      fi
    done <<< "$findings_jsonl"
  fi

  # Date and run number from the first display id, or today and run #01.
  local date run_of_day
  date="$(date +%Y-%m-%d)"
  run_of_day="01"

  if [[ -n "$findings_jsonl" ]]; then
    local first_did
    first_did="$(printf '%s\n' "$findings_jsonl" | jq -r -n '[inputs | .display_id | strings | select(length > 0)] | first // empty')"
    if [[ -n "$first_did" ]]; then
      # SA-<date>-<NN>-<NNN> as the skill assigns it, or SA-<date>-<NNN> (no run number: run #01).
      local stripped="${first_did#SA-}" run_re='^[0-9]{4}-[0-9]{2}-[0-9]{2}-([0-9]{2})-[0-9]{3}$'
      date="${stripped:0:10}"
      if [[ "$stripped" =~ $run_re ]]; then
        run_of_day="${BASH_REMATCH[1]}"
      fi
    fi
  fi

  printf '## Security audit — %s (run #%s) — %d findings\n\n' "$date" "$run_of_day" "$total_visible"

  _csa_build_summary_table "$findings_jsonl" "$verbose"

  printf '\n'
  _csa_suppression_lines "$findings_jsonl" "$root"
  printf '\n'

  # HOOK-006 is Info, so the table hides it; say that hooks went unchecked (#1059).
  if [[ "$verbose" != "true" && -n "$findings_jsonl" ]]; then
    local n_unchecked
    if n_unchecked="$(printf '%s\n' "$findings_jsonl" | jq -s '[.[] | select(.rule_id == "HOOK-006" and (.state // "NEW") != "SUPPRESSED")] | length' 2>/dev/null)"; then
      if [[ "${n_unchecked:-0}" -gt 0 ]]; then
        printf '%d %s hooks the audit does not inspect (HOOK-006, Info; pass --verbose).\n\n' "$n_unchecked" \
          "$([[ "$n_unchecked" -eq 1 ]] && printf 'file declares' || printf 'files declare')"
      fi
    else
      # A failed count is not zero (#1072 C7): say so, so an unchecked hook is not hidden.
      printf 'HOOK-006 count unavailable (the findings could not be counted; pass --verbose to list them).\n\n'
    fi
  fi

  # The group's findings are one count line, not listed one by one; --verbose lists them in full.
  if [[ "$verbose" != "true" ]]; then
    _csa_group_count_line "$findings_jsonl"
  fi

  # List critical + high findings explicitly (non-suppressed only, unless verbose).
  local show_severities="critical high"
  if [[ "$verbose" == "true" ]]; then
    show_severities="critical high medium low info"
  fi

  for sev in $show_severities; do
    local label; label="$(_csa_severity_label "$sev")"
    # Collect non-suppressed findings of this severity.
    local sev_findings=()
    if [[ -n "$findings_jsonl" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local fsev fst
        fsev="$(printf '%s' "$line" | jq -r '.severity // empty')"
        fst="$(printf '%s' "$line" | jq -r '.state // "NEW"')"
        [[ "$fsev" == "$sev" ]] || continue
        if [[ "$verbose" == "true" ]] || [[ "$fst" != "SUPPRESSED" ]]; then
          if [[ "$verbose" != "true" && -n "$(_csa_finding_group "$(printf '%s' "$line" | jq -r '.file // ""')")" ]]; then
            continue
          fi
          sev_findings+=("$line")
        fi
      done <<< "$findings_jsonl"
    fi

    local count="${#sev_findings[@]}"
    if [[ "$count" -gt 0 ]]; then
      printf '### %s (%d)\n' "$label" "$count"
      local f
      for f in "${sev_findings[@]}"; do
        local did rule_id file line_no jpath
        did="$(printf '%s' "$f" | jq -r '.display_id // "SA-unknown"')"
        rule_id="$(printf '%s' "$f" | jq -r '.rule_id // ""')"
        file="$(printf '%s' "$f" | jq -r '.file // ""')"
        line_no="$(printf '%s' "$f" | jq -r '.line // ""')"
        jpath="$(printf '%s' "$f" | jq -r '(.context | objects | .json_path) // ""')"
        if [[ -n "$jpath" ]]; then
          printf -- '- %s \xe2\x80\x94 %s at %s#%s\n' "$did" "$rule_id" "$file" "$jpath"
        elif [[ -n "$line_no" && "$line_no" != "0" ]]; then
          printf -- '- %s \xe2\x80\x94 %s at %s:%s\n' "$did" "$rule_id" "$file" "$line_no"
        else
          printf -- '- %s \xe2\x80\x94 %s at %s\n' "$did" "$rule_id" "$file"
        fi
      done
      printf '\n'
    fi
  done

  if [[ -n "$report_path" ]]; then
    printf 'Full report: %s\n' "$report_path"
  fi
}

# ---------------------------------------------------------------------------
# csa_report_render_markdown <findings_jsonl or path> <metadata_json> <output_path> [<project_root>]
# Write full markdown report to output_path. On input that is not findings JSONL
# (_csa_findings_arg) it exits 4 before output_path is opened, so no report file is written.
# metadata_json: {project, date, run_of_day, duration_seconds, scope_summary, hook_commands}; hook_commands is the
# file csa_rule_engine_scan_all wrote. The project root (default: the working directory) is read only for the
# suppressions.json lines (_csa_suppression_lines).
# ---------------------------------------------------------------------------
csa_report_render_markdown() {
  local findings_jsonl metadata_json="$2"
  local output_path="$3" root="${4:-$PWD}"
  findings_jsonl="$(_csa_findings_arg "$1")" || return 4

  # Parse metadata.
  local project date run_of_day duration scope_summary
  if [[ -n "$metadata_json" ]]; then
    project="$(printf '%s' "$metadata_json" | jq -r '.project // "unknown"')"
    date="$(printf '%s' "$metadata_json" | jq -r '.date // ""')"
    run_of_day="$(printf '%s' "$metadata_json" | jq -r '.run_of_day // 1')"
    duration="$(printf '%s' "$metadata_json" | jq -r '.duration_seconds // 0')"
    scope_summary="$(printf '%s' "$metadata_json" | jq -r '.scope_summary // ""')"
  else
    project="unknown"
    date="$(date +%Y-%m-%d)"
    run_of_day="1"
    duration="0"
    scope_summary=""
  fi

  [[ -z "$date" ]] && date="$(date +%Y-%m-%d)"
  local run_padded; run_padded="$(printf '%02d' "$run_of_day")"

  # A project's first report: .claude/audits/ may not exist yet.
  local out_dir; out_dir="$(dirname "$output_path")"
  mkdir -p "$out_dir" 2>/dev/null || { printf 'csa: cannot create %s; no report written\n' "$out_dir" >&2; return 5; }

  # Build output.
  {
    printf '# Security audit — %s (run #%s)\n\n' "$date" "$run_padded"
    printf '**Project:** %s\n' "$project"
    printf '**Audit scope:** %s\n' "$scope_summary"
    printf '**Duration:** %ss\n\n' "$duration"

    printf '## Summary\n\n'
    _csa_build_summary_table "$findings_jsonl" "true"
    printf '\n'
    _csa_suppression_lines "$findings_jsonl" "$root"
    printf '\n'

    printf '## Findings\n\n'

    # Emit each finding as a section.
    if [[ -n "$findings_jsonl" ]]; then
      while IFS= read -r finding; do
        [[ -z "$finding" ]] && continue
        local did rule_id file line_no offset preview fuid state sev jpath
        did="$(printf '%s' "$finding" | jq -r '.display_id // "SA-unknown"')"
        rule_id="$(printf '%s' "$finding" | jq -r '.rule_id // ""')"
        file="$(printf '%s' "$finding" | jq -r '.file // ""')"
        line_no="$(printf '%s' "$finding" | jq -r '.line // ""')"
        offset="$(printf '%s' "$finding" | jq -r '.offset // ""')"
        preview="$(printf '%s' "$finding" | jq -r '.preview // ""')"
        fuid="$(printf '%s' "$finding" | jq -r '.finding_uid // ""')"
        state="$(printf '%s' "$finding" | jq -r '.state // "NEW"')"
        sev="$(_csa_severity_label "$(printf '%s' "$finding" | jq -r '.severity // ""')")"

        printf -- '### [%s] %s (%s) \xe2\x80\x94 %s\n\n' "$state" "$did" "$sev" "$rule_id"
        printf '**Rule:** %s\n' "$rule_id"
        jpath="$(printf '%s' "$finding" | jq -r '(.context | objects | .json_path) // ""')"
        if [[ -n "$jpath" ]]; then
          printf '**File:** %s#%s\n' "$file" "$jpath"
        elif [[ "$line_no" == "0" ]]; then
          # Line 0 means the finding has no line (#1072 r2 C12): the bare file, not file:0:0.
          printf '**File:** %s\n' "$file"
        else
          printf '**File:** %s:%s:%s\n' "$file" "$line_no" "$offset"
        fi
        local grp; grp="$(_csa_finding_group "$file")"
        [[ -z "$grp" ]] || printf '**Group:** %s\n' "$grp"
        printf '**Preview:** `%s`\n' "$preview"
        printf '**finding_uid:** `%s`\n\n' "$fuid"
        printf -- '---\n\n'
      done <<< "$findings_jsonl"
    else
      printf '_No findings._\n\n'
    fi

    _csa_hook_commands_section "$metadata_json"

    printf '## Acknowledgements\n\n'
    printf 'This report was generated by membrane %s, an independent MIT-licensed audit tool inspired by AgentShield in Everything Claude Code (Mustafa, 2026).\n' "$(_csa_plugin_version)"
  } > "$output_path"
}
