#!/usr/bin/env bash
# lib/state.sh — state persistence, tamper detection, and GC for membrane.
# Requires: lib/helpers.sh (csa_sha256, csa_realpath, csa_sed_inplace)
# Bash 3.2+ compatible (macOS portability).

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# csa_file_mtime <path> — print epoch seconds of file mtime (BSD + GNU portable). A symlink gives its target's mtime
# (`-L`), the one `touch -r` copies and an edit through the link moves.
csa_file_mtime() {
  local f="$1"
  if stat -L -f %m "$f" >/dev/null 2>&1; then
    stat -L -f %m "$f"
  else
    stat -L -c %Y "$f" 2>/dev/null || echo 0
  fi
}

# csa_iso_now — print current UTC ISO-8601 timestamp.
csa_iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

# csa_state_path <project_root> — echo absolute path to state.json.
csa_state_path() {
  local root="$1"
  printf '%s/.claude/audits/state.json' "$root"
}

# csa_suppressions_path <project_root> — echo absolute path to suppressions.json.
csa_suppressions_path() {
  local root="$1"
  printf '%s/.claude/audits/suppressions.json' "$root"
}

# ---------------------------------------------------------------------------
# Init + Read
# ---------------------------------------------------------------------------

# csa_state_init <project_root> — create dir + write empty schema_version=2 file.
csa_state_init() {
  local root="$1"
  local state_file; state_file="$(csa_state_path "$root")"
  mkdir -p "$(dirname "$state_file")"
  jq -n '{
    schema_version: 2,
    last_audit: null,
    self_integrity: {
      state_mtime_at_last_audit: 0,
      suppressions_mtime_at_last_audit: 0,
      git_tracked_check: {
        state_json_tracked: false,
        suppressions_json_tracked: false,
        checked_at: null
      }
    },
    findings: {},
    audit_history: [],
    applied_fixes: []
  }' > "$state_file"
}

# csa_state_read <project_root> — cat file; if missing, echo '{}'.
csa_state_read() {
  local root="$1"
  local state_file; state_file="$(csa_state_path "$root")"
  if [[ -f "$state_file" ]]; then
    cat "$state_file"
  else
    printf '{}\n'
  fi
}

# ---------------------------------------------------------------------------
# Record audit
# ---------------------------------------------------------------------------

# _csa_state_rules_dir — the shipped rule tree (one directory per aspect).
_csa_state_rules_dir() {
  printf '%s' "${CSA_RULES_DIR:-$(dirname "${BASH_SOURCE[0]}")/rules}"
}

# _csa_state_rule_aspects — JSON object mapping each shipped RULE_ID to the
# aspect directory its rule file sits in (#429).
_csa_state_rule_aspects() {
  local f id
  for f in "$(_csa_state_rules_dir)"/*/*.sh; do
    [[ -f "$f" ]] || continue
    id="$(grep -m1 '^RULE_ID=' "$f" 2>/dev/null | sed 's/^RULE_ID=//' | tr -d '"'\')"
    [[ -n "$id" ]] && printf '%s\t%s\n' "$id" "$(basename "$(dirname "$f")")"
  done | jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {key: .[0], value: .[1]}) | from_entries'
}

# _csa_state_rule_severities — RULE_ID -> RULE_SEVERITY from the shipped rule files, as one JSON object.
_csa_state_rule_severities() {
  local f id sev
  for f in "$(_csa_state_rules_dir)"/*/*.sh; do
    [[ -f "$f" ]] || continue
    id="$(grep -m1 '^RULE_ID=' "$f" 2>/dev/null | sed 's/^RULE_ID=//' | tr -d '"'\')"
    sev="$(grep -m1 '^RULE_SEVERITY=' "$f" 2>/dev/null | sed 's/^RULE_SEVERITY=//' | tr -d '"'\')"
    [[ -n "$id" && -n "$sev" ]] && printf '%s\t%s\n' "$id" "$sev"
  done | jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {key: .[0], value: .[1]}) | from_entries'
}

# _CSA_JQ_REGISTRY — THE one reader of state.json's `findings` registry, as a jq def that each reader
# and writer prepends to its program. `csa_registry` is the registry's object entries only: a
# registry that is not an object reads as {}, and an entry that is not an object (a string, a
# number, an array, null, a boolean) is left out. No reader can act on such an entry, so readers
# skip it and the writers (state_record_audit, state_gc_findings) drop it. suppress_add keeps its
# own entry read, so such an entry stays its exit 1 there.
# Skill-first question 2: membrane's own state file, a closed shape.
_CSA_JQ_REGISTRY='def csa_registry: ((.findings | objects) // {}) | with_entries(select(.value | type == "object"));'

# _csa_registry_resolve_display_id <state_json> <display_id>
# Print the finding_uid that holds <display_id>, or nothing; exit 0 either way. THE one display-id
# lookup (suppress_add, apply_resolve_id). An entry holds every id the latest run printed for it,
# in last_display_ids (one uid can be several findings: a rule firing on the same text on two lines),
# and last_display_id, the last of them, as before 0.7.2. A display id names a line of the latest
# recorded run's report, so only an entry seen in that run (last_run_index equal to the newest
# audit_history run_index) can match. An id an older run's entry still holds matches nothing: its
# number may have come round again (a report file was deleted) and now name a SCANNER finding,
# which is never registered. An empty id, a state with no recorded run, and an id two entries of
# that run hold (only a hand edit makes one) match nothing.
_csa_registry_resolve_display_id() {
  local state_json="$1" did="$2"
  [[ -n "$did" ]] || return 0
  printf '%s' "$state_json" | jq -r --arg did "$did" "$_CSA_JQ_REGISTRY"'
    ((.audit_history | arrays | last | objects | .run_index | numbers) // null) as $latest
    | [csa_registry | to_entries[]
       | select($latest != null and .value.last_run_index == $latest
               and (.value.last_display_id == $did
                    or (((.value.last_display_ids | arrays) // []) | any(.[]; . == $did))))]
    | if length == 1 then .[0].key else empty end' 2>/dev/null || true
}

# _csa_suppressed_uid_set <suppressions_file>
# Print the suppressed uids as one JSON array, always, and exit 0. A missing, empty or
# whitespace-only file is []. A file that is anything but one object with a suppressions array
# (not JSON, two documents, {}, null) is also []: an unreadable file suppresses nothing.
# Entries that are not objects, and uids that are not strings, are skipped.
_csa_suppressed_uid_set() {
  local f="$1" set
  set="$( { [[ -f "$f" ]] && jq -s -c '
    if length == 0 then []
    elif length == 1 and (.[0] | type) == "object" and (.[0].suppressions | type) == "array"
      then [.[0].suppressions[] | objects | .finding_uid | strings]
    else error("unreadable") end' "$f"; } 2>/dev/null)" || set='[]'
  [[ "$set" == \[*\] ]] || set='[]'
  printf '%s\n' "$set"
}

# csa_state_record_audit <project_root> <run_index> <report_path> <findings_jsonl> [<focus>]
# Append to audit_history, update last_audit, update findings registry, run GC.
# findings_jsonl: newline-delimited JSON objects (the content, or the path of a file holding
#   them); each must have: finding_uid, rule_id, severity, file, display_id
# A registry entry keeps the run's display ids for its uid in last_display_ids: reset at the run's
# first sighting of the uid, appended on later sightings in the same run. It creates
# .claude/audits/ when missing (exit 5, nothing written, when it cannot).
# Every finding it is given is registered with findings[uid].suppressed, which this function
# computes from suppressions.json (never from the input's state) and which is false for a
# critical finding, since suppress_filter never hides one; so a suppressed finding that
# still fires keeps its registry entry current and does not age out. finding_counts counts the
# findings not marked suppressed, per severity, plus a `suppressed` total.
# focus: the aspect the run scanned, or `all` (the default) for a full audit.
# The history entry records it as `focus`; an unknown aspect is refused
# (exit 2) before any write.
csa_state_record_audit() {
  local root="$1"
  local run_index="$2"
  local report_path="$3"
  local findings_jsonl="$4"
  local focus="${5-all}"
  # A path to a findings file is read; anything else is the findings themselves.
  if [[ -n "$findings_jsonl" && "$findings_jsonl" != "{"* && -f "$findings_jsonl" ]]; then
    findings_jsonl="$(cat "$findings_jsonl")" || return 5
  fi
  # The suppression set, read here so the mark never depends on the skill's filter. An unreadable
  # file marks nothing suppressed: the mark is informational and approves nothing.
  local sup_uids; sup_uids="$(_csa_suppressed_uid_set "$(csa_suppressions_path "$root")")"
  local counts_suppressed=0

  if [[ "$focus" != "all" ]] && ! [[ -n "$focus" && "$focus" != */* && "$focus" != .* \
        && -d "$(_csa_state_rules_dir)/$focus" ]]; then
    printf 'Unknown rule aspect: %s\n' "$focus" >&2
    return 2
  fi

  local state_file; state_file="$(csa_state_path "$root")"
  local now; now="$(csa_iso_now)"

  # Read existing state (or empty object).
  local state; state="$(csa_state_read "$root")"

  # If state is '{}' (missing file), bootstrap a minimal structure for jq. Then keep only the
  # registry entries a reader can use (csa_registry), before this run's sightings.
  state="$(printf '%s' "$state" | jq "$_CSA_JQ_REGISTRY"'
    (if . == {} then {
      schema_version: 2,
      last_audit: null,
      self_integrity: {
        state_mtime_at_last_audit: 0,
        suppressions_mtime_at_last_audit: 0,
        git_tracked_check: {
          state_json_tracked: false,
          suppressions_json_tracked: false,
          checked_at: null
        }
      },
      findings: {},
      audit_history: [],
      applied_fixes: []
    } else . end) | .findings = csa_registry
  ')"

  # Build finding counts and findings registry updates from findings_jsonl.
  local counts_critical=0 counts_high=0 counts_medium=0 counts_low=0 counts_info=0
  # The enabled set this audit saw, as [{"name": "plugin@marketplace"}, ...]:
  # the SessionStart reminder compares it with the current set. An unreadable
  # set is unknown, not empty, so it refuses the write (#424).
  local enabled_plugins_snapshot="[]" enabled_names
  if ! declare -F csa_enum_enabled_plugins >/dev/null 2>&1 && [[ -f "${CSA_LIB_DIR:-}/enumerate-targets.sh" ]]; then
    # shellcheck source=/dev/null
    source "${CSA_LIB_DIR}/enumerate-targets.sh"
  fi
  if declare -F csa_enum_enabled_plugins >/dev/null 2>&1; then
    enabled_names="$(csa_enum_enabled_plugins "$root" 2>/dev/null)" || {
      printf 'csa: cannot read the enabled-plugin set; no audit state written\n' >&2
      return 2
    }
    enabled_plugins_snapshot="$(printf '%s\n' "$enabled_names" | jq -R -s -c 'split("\n") | map(select(length > 0) | {name: .})')" || return 2
  fi

  # Parse findings_jsonl: update findings registry in state.
  if [[ -n "$findings_jsonl" ]]; then
    while IFS= read -r finding_json; do
      [[ -z "$finding_json" ]] && continue

      local fuid rule_id severity file display_id
      fuid="$(printf '%s' "$finding_json" | jq -r '.finding_uid // empty')"
      rule_id="$(printf '%s' "$finding_json" | jq -r '.rule_id // empty')"
      severity="$(printf '%s' "$finding_json" | jq -r '.severity // empty')"
      file="$(printf '%s' "$finding_json" | jq -r '.file // empty')"
      display_id="$(printf '%s' "$finding_json" | jq -r '.display_id // empty')"

      [[ -z "$fuid" ]] && continue
      # Marked when suppress_filter would hide it (listed, not critical), whether or not this run
      # passed --show-suppressed: a listed Critical is always shown, so it is never marked.
      local is_sup; is_sup="$(jq -n --argjson s "$sup_uids" --arg k "$fuid" --arg sev "$severity" \
        'any($s[]; . == $k) and $sev != "critical"')"

      # Increment counts.
      if [[ "$is_sup" == "true" ]]; then counts_suppressed=$((counts_suppressed + 1)); else
      case "$severity" in
        critical) counts_critical=$((counts_critical + 1)) ;;
        high)     counts_high=$((counts_high + 1)) ;;
        medium)   counts_medium=$((counts_medium + 1)) ;;
        low)      counts_low=$((counts_low + 1)) ;;
        info)     counts_info=$((counts_info + 1)) ;;
      esac
      fi

      # Update findings registry entry.
      state="$(printf '%s' "$state" | jq \
        --arg fuid "$fuid" \
        --arg rule_id "$rule_id" \
        --arg severity "$severity" \
        --arg file "$file" \
        --arg now "$now" \
        --arg display_id "$display_id" \
        --argjson sup "$is_sup" \
        --argjson run_index "$run_index" '
        if .findings[$fuid] then
          (.findings[$fuid].last_run_index == $run_index) as $same_run |
          .findings[$fuid].rule_id = $rule_id |
          .findings[$fuid].severity = $severity |
          .findings[$fuid].file = $file |
          .findings[$fuid].suppressed = $sup |
          (if $display_id != "" then .findings[$fuid].last_display_id = $display_id else . end) |
          .findings[$fuid].last_display_ids =
            ((if $same_run then ((.findings[$fuid].last_display_ids | arrays) // []) else [] end)
             + (if $display_id != "" then [$display_id] else [] end)) |
          .findings[$fuid].last_seen = $now |
          .findings[$fuid].seen_in_runs = (((.findings[$fuid].seen_in_runs | numbers) // 0) + 1) |
          .findings[$fuid].last_run_index = $run_index
        else
          .findings[$fuid] = {
            rule_id: $rule_id,
            severity: $severity,
            file: $file,
            first_seen: $now,
            last_seen: $now,
            seen_in_runs: 1,
            last_run_index: $run_index,
            last_display_id: $display_id,
            last_display_ids: (if $display_id != "" then [$display_id] else [] end),
            suppressed: $sup
          }
        end
      ')"
    done <<< "$findings_jsonl"
  fi

  # Build finding_counts object.
  local finding_counts; finding_counts="$(jq -n \
    --argjson c "$counts_critical" \
    --argjson h "$counts_high" \
    --argjson m "$counts_medium" \
    --argjson l "$counts_low" \
    --argjson i "$counts_info" \
    --argjson s "$counts_suppressed" \
    '{critical: $c, high: $h, medium: $m, low: $l, info: $i, suppressed: $s}')"

  # Derive display_id_prefix from report_path (SA-YYYY-MM-DD-NN).
  local report_basename; report_basename="$(basename "$report_path" .md)"
  local display_id_prefix="SA-${report_basename}"

  # Update last_audit and append to audit_history.
  # The snapshot grows with the enabled set, so it reaches jq on stdin after the
  # state, never as an argv value (#424).
  state="$(printf '%s\n%s\n' "$state" "$enabled_plugins_snapshot" | jq -s \
    --arg now "$now" \
    --arg report_path "$report_path" \
    --arg display_id_prefix "$display_id_prefix" \
    --argjson finding_counts "$finding_counts" \
    --arg focus "$focus" \
    --argjson run_index "$run_index" '
    .[1] as $enabled_plugins_snapshot | .[0] |
    .last_audit = {
      date: $now,
      report_path: $report_path,
      report_path_display_id_prefix: $display_id_prefix,
      finding_counts: $finding_counts,
      enabled_plugins_snapshot: $enabled_plugins_snapshot
    } |
    .audit_history += [{
      run_index: $run_index,
      date: $now,
      report_path: $report_path,
      finding_counts: $finding_counts,
      focus: $focus
    }]
  ')"

  # Write atomically. A project's first audit: .claude/audits/ may not exist yet.
  local audits_dir; audits_dir="$(dirname "$state_file")"
  mkdir -p "$audits_dir" 2>/dev/null || { printf 'csa: cannot create %s; no audit state written\n' "$audits_dir" >&2; return 5; }
  local tmp; tmp="$audits_dir/state.json.tmp.$$"
  printf '%s\n' "$state" > "$tmp"
  mv "$tmp" "$state_file"

  # Run GC.
  csa_state_gc_findings "$root" "$run_index"
}

# ---------------------------------------------------------------------------
# GC
# ---------------------------------------------------------------------------

# csa_state_gc_findings <project_root> <current_run_index>
# Evict findings absent for more than 10 runs that scanned their aspect (#429):
# (current_run_index - last_run_index) minus the recorded runs in that window
# that were focused on another aspect. A run with focus `all`, or with no focus
# (written by 0.1.6 and earlier), is a full run and counts for every finding. A
# finding whose rule_id maps to no shipped rule has no aspect and ages on every
# run. The registry is read through csa_registry, so an entry that is not an object is dropped;
# an entry whose last_run_index is not a number cannot be aged and is evicted; a rule_id that is
# not a string maps to no rule. A failed run leaves state.json as it was and no tmp file.
csa_state_gc_findings() {
  local root="$1"
  local current_run_index="$2"
  local state_file; state_file="$(csa_state_path "$root")"
  [[ -f "$state_file" ]] || return 0

  local rule_aspects; rule_aspects="$(_csa_state_rule_aspects)"
  local tmp rc=0; tmp="$(dirname "$state_file")/state.json.tmp.$$"
  jq \
    --argjson current "$current_run_index" \
    --argjson rule_aspects "$rule_aspects" \
    "$_CSA_JQ_REGISTRY"'if .findings then
      (.audit_history // []) as $hist |
      .findings = (csa_registry | with_entries(
        select((.value.last_run_index | type) == "number") |
        .value.last_run_index as $last |
        ($rule_aspects[(.value.rule_id | strings) // ""] // null) as $aspect |
        ([$hist[]
          | select(.run_index > $last and .run_index <= $current)
          | select($aspect != null
                   and (.focus // "all") != "all"
                   and .focus != $aspect)
         ] | length) as $skipped |
        select(($current - $last - $skipped) <= 10)
      ))
    else . end' \
    "$state_file" > "$tmp" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    rm -f "$tmp"
    return "$rc"
  fi
  mv "$tmp" "$state_file"
}

# ---------------------------------------------------------------------------
# Self-integrity
# ---------------------------------------------------------------------------

# csa_state_update_self_integrity <project_root>
# Record mtimes + git-tracked status of state.json + suppressions.json.
csa_state_update_self_integrity() {
  local root="$1"
  local state_file; state_file="$(csa_state_path "$root")"
  [[ -f "$state_file" ]] || return 0

  local suppressions_file; suppressions_file="$(csa_suppressions_path "$root")"
  local now; now="$(csa_iso_now)"

  # state.json's mtime (a symlink's target's), recorded inside state.json: the rewrite below gets this same mtime back
  # (`touch -r` from the file it replaces; `mv` keeps it), so the record matches the file it is written into (#1164).
  local state_mtime; state_mtime="$(csa_file_mtime "$state_file")"

  # Get suppressions.json mtime (0 if missing).
  local suppressions_mtime=0
  if [[ -f "$suppressions_file" ]]; then
    suppressions_mtime="$(csa_file_mtime "$suppressions_file")"
  fi

  # Git-tracked check. git runs in the audited project and reads its config. `-c core.fsmonitor=` (empty means no
  # hook; `false` would name a hook path on git before 2.36) stops the one key that runs a command on this read,
  # measured on git 2.53, wherever it is set: .git/config, include.path, includeIf, a .git file's gitdir. The
  # redirects keep a configured pager from running. Skill-first question 3: it only removes a command.
  local state_tracked=false suppressions_tracked=false
  if command -v git >/dev/null 2>&1; then
    if git -c core.fsmonitor= -C "$root" ls-files --error-unmatch "$state_file" >/dev/null 2>&1; then
      state_tracked=true
    fi
    if [[ -f "$suppressions_file" ]] && git -c core.fsmonitor= -C "$root" ls-files --error-unmatch "$suppressions_file" >/dev/null 2>&1; then
      suppressions_tracked=true
    fi
  fi

  local tmp; tmp="$(dirname "$state_file")/state.json.tmp.$$"
  jq \
    --argjson state_mtime "$state_mtime" \
    --argjson suppressions_mtime "$suppressions_mtime" \
    --argjson state_tracked "$state_tracked" \
    --argjson suppressions_tracked "$suppressions_tracked" \
    --arg now "$now" \
    '.self_integrity.state_mtime_at_last_audit = $state_mtime |
     .self_integrity.suppressions_mtime_at_last_audit = $suppressions_mtime |
     .self_integrity.git_tracked_check.state_json_tracked = $state_tracked |
     .self_integrity.git_tracked_check.suppressions_json_tracked = $suppressions_tracked |
     .self_integrity.git_tracked_check.checked_at = $now' \
    "$state_file" > "$tmp" && touch -r "$state_file" "$tmp" && mv "$tmp" "$state_file"
}

# ---------------------------------------------------------------------------
# Tamper detection
# ---------------------------------------------------------------------------

# csa_state_check_tamper <project_root>
# Emit TAMPER-001/002/003 findings JSONL if drift detected.
# Silent on first run (no state.json yet, or self_integrity not populated).
csa_state_check_tamper() {
  local root="$1"
  local state_file; state_file="$(csa_state_path "$root")"

  # First run: no state file → skip silently.
  [[ -f "$state_file" ]] || return 0

  local state; state="$(cat "$state_file")"
  local recorded_state_mtime; recorded_state_mtime="$(printf '%s' "$state" | jq -r '.self_integrity.state_mtime_at_last_audit // 0')"

  # If recorded mtime is 0, treat as first run — skip silently.
  [[ "$recorded_state_mtime" == "0" || "$recorded_state_mtime" == "null" ]] && return 0

  local now; now="$(csa_iso_now)"

  # TAMPER-001: state.json mtime drift.
  local actual_state_mtime; actual_state_mtime="$(csa_file_mtime "$state_file")"
  if [[ "$actual_state_mtime" != "$recorded_state_mtime" ]]; then
    jq -nc \
      --arg now "$now" \
      --arg file "$state_file" \
      '{
        rule_id: "TAMPER-001",
        severity: "high",
        file: $file,
        finding_uid: "FUID-tamper01",
        display_id: "TAMPER-001",
        message: "state.json mtime changed since last audit — possible tampering",
        first_seen: $now,
        last_seen: $now
      }'
  fi

  # TAMPER-002: suppressions.json mtime drift.
  local suppressions_file; suppressions_file="$(csa_suppressions_path "$root")"
  local recorded_suppressions_mtime; recorded_suppressions_mtime="$(printf '%s' "$state" | jq -r '.self_integrity.suppressions_mtime_at_last_audit // 0')"

  # Only check if we recorded a non-zero mtime (meaning suppressions.json existed at last audit).
  if [[ "$recorded_suppressions_mtime" != "0" && "$recorded_suppressions_mtime" != "null" ]]; then
    local actual_suppressions_mtime=0
    if [[ -f "$suppressions_file" ]]; then
      actual_suppressions_mtime="$(csa_file_mtime "$suppressions_file")"
    fi
    if [[ "$actual_suppressions_mtime" != "$recorded_suppressions_mtime" ]]; then
      jq -nc \
        --arg now "$now" \
        --arg file "$suppressions_file" \
        '{
          rule_id: "TAMPER-002",
          severity: "high",
          file: $file,
          finding_uid: "FUID-tamper02",
          display_id: "TAMPER-002",
          message: "suppressions.json mtime changed since last audit — possible tampering",
          first_seen: $now,
          last_seen: $now
        }'
    fi
  elif [[ -f "$suppressions_file" ]]; then
    # suppressions.json was not present at last audit but now exists.
    jq -nc \
      --arg now "$now" \
      --arg file "$suppressions_file" \
      '{
        rule_id: "TAMPER-002",
        severity: "high",
        file: $file,
        finding_uid: "FUID-tamper02",
        display_id: "TAMPER-002",
        message: "suppressions.json appeared since last audit — possible tampering",
        first_seen: $now,
        last_seen: $now
      }'
  fi

  # TAMPER-003: git-tracked status drift. `-c core.fsmonitor=` as in csa_state_update_self_integrity.
  local checked_at; checked_at="$(printf '%s' "$state" | jq -r '.self_integrity.git_tracked_check.checked_at // empty')"
  if [[ -n "$checked_at" ]] && command -v git >/dev/null 2>&1; then
    local recorded_state_tracked; recorded_state_tracked="$(printf '%s' "$state" | jq -r '.self_integrity.git_tracked_check.state_json_tracked // false')"
    local recorded_suppressions_tracked; recorded_suppressions_tracked="$(printf '%s' "$state" | jq -r '.self_integrity.git_tracked_check.suppressions_json_tracked // false')"

    local current_state_tracked=false
    if git -c core.fsmonitor= -C "$root" ls-files --error-unmatch "$state_file" >/dev/null 2>&1; then
      current_state_tracked=true
    fi

    local current_suppressions_tracked=false
    if [[ -f "$suppressions_file" ]] && git -c core.fsmonitor= -C "$root" ls-files --error-unmatch "$suppressions_file" >/dev/null 2>&1; then
      current_suppressions_tracked=true
    fi

    if [[ "$current_state_tracked" != "$recorded_state_tracked" || "$current_suppressions_tracked" != "$recorded_suppressions_tracked" ]]; then
      jq -nc \
        --arg now "$now" \
        --arg file "$state_file" \
        '{
          rule_id: "TAMPER-003",
          severity: "high",
          file: $file,
          finding_uid: "FUID-tamper03",
          display_id: "TAMPER-003",
          message: "Git-tracked status of audit files changed since last audit — possible tampering",
          first_seen: $now,
          last_seen: $now
        }'
    fi
  fi
}

# ---------------------------------------------------------------------------
# Applied fixes
# ---------------------------------------------------------------------------

# csa_state_record_applied_fix <project_root> <finding_uid> <display_id> <rule_id> <applied_by> <summary>
csa_state_record_applied_fix() {
  local root="$1"
  local finding_uid="$2"
  local display_id="$3"
  local rule_id="$4"
  local applied_by="$5"
  local summary="$6"

  local state_file; state_file="$(csa_state_path "$root")"
  [[ -f "$state_file" ]] || return 1

  local now; now="$(csa_iso_now)"
  local tmp; tmp="$(dirname "$state_file")/state.json.tmp.$$"
  jq \
    --arg finding_uid "$finding_uid" \
    --arg display_id "$display_id" \
    --arg rule_id "$rule_id" \
    --arg applied_by "$applied_by" \
    --arg summary "$summary" \
    --arg now "$now" \
    '.applied_fixes += [{
      finding_uid: $finding_uid,
      display_id_at_apply: $display_id,
      rule_id: $rule_id,
      applied_at: $now,
      applied_by: $applied_by,
      summary: $summary
    }]' \
    "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}

# ---------------------------------------------------------------------------
# Gitignore bootstrap (T1-D)
# ---------------------------------------------------------------------------

# csa_state_bootstrap_gitignore <project_root>
# First-audit gitignore mechanism per auto-fix-policy.md §T1-D.
csa_state_bootstrap_gitignore() {
  local root="$1"
  local gitignore="$root/.gitignore"
  local entry=".claude/audits/"
  local comment_block
  comment_block="$(printf '\n# claude-security-audit\n%s\n' "$entry")"

  if [[ -f "$gitignore" ]]; then
    # Check if entry already present.
    if grep -q "$entry" "$gitignore" 2>/dev/null; then
      # Already present — do nothing silently.
      return 0
    fi
    # Append entry.
    printf '%s' "$comment_block" >> "$gitignore"
    printf 'Added .claude/audits/ to your .gitignore\n'
  else
    # No .gitignore — check if a .git directory exists anywhere up the tree.
    local dir="$root"
    local git_root=""
    while [[ "$dir" != "/" ]]; do
      if [[ -d "$dir/.git" ]]; then
        git_root="$dir"
        break
      fi
      dir="$(dirname "$dir")"
    done

    if [[ -n "$git_root" ]]; then
      # Create .gitignore at git root.
      printf '# claude-security-audit\n%s\n' "$entry" > "$git_root/.gitignore"
      printf 'Created .gitignore with .claude/audits/ entry\n'
    else
      printf 'Info: No git repository found; .claude/audits/ will not be gitignored\n'
    fi
  fi
}
