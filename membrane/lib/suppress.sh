#!/usr/bin/env bash
# lib/suppress.sh — suppression management for membrane.
# Requires: lib/helpers.sh, lib/state.sh
# Bash 3.2+ compatible (macOS portability).

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _csa_iso_to_epoch <iso8601>
# Convert ISO-8601 UTC timestamp (YYYY-MM-DDTHH:MM:SSZ) to epoch seconds.
# Supports BSD (macOS) and GNU date.
_csa_iso_to_epoch() {
  local iso="$1"
  # BSD (macOS): use TZ=UTC to ensure the literal timestamp is parsed as UTC.
  if TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null; then return; fi
  # GNU date fallback.
  TZ=UTC date -d "$iso" +%s 2>/dev/null
}

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

# csa_suppress_path <project_root>
# Echo absolute path to suppressions.json.
csa_suppress_path() {
  local root="$1"
  printf '%s/.claude/audits/suppressions.json' "$root"
}

# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

# csa_suppress_init <project_root>
# Create .claude/audits/suppressions.json with schema_version=1 and empty suppressions array.
csa_suppress_init() {
  local root="$1"
  local sup_file; sup_file="$(csa_suppress_path "$root")"
  mkdir -p "$(dirname "$sup_file")"
  jq -n '{schema_version: 1, suppressions: []}' > "$sup_file"
}

# ---------------------------------------------------------------------------
# Add
# ---------------------------------------------------------------------------

# csa_suppress_add <project_root> <finding_uid_or_display_id> <note>
#   (legacy: <project_root> <id> <severity> <note>; the severity argument is ignored)
# The finding must be in state.json's registry (a recorded run produced it); its
# severity is the higher of the registry's and the shipped rule's RULE_SEVERITY.
# rc 1 critical, an entry whose severity cannot be read, or first_seen < 60s; rc 2 no or unreadable
# state.json, or a suppressions.json that is not one object with a suppressions array; rc 3 no run
# produced the id.
csa_suppress_add() {
  local root="$1" id_arg="$2" note
  if [[ $# -ge 4 ]]; then note="$4"; else note="${3-}"; fi
  local state_file; state_file="$(csa_state_path "$root")"
  local state_json
  state_json="$(jq -c 'if (.findings | type) == "object" then . else error("no registry") end' "$state_file" 2>/dev/null)" || {
    printf 'csa: no readable audit state at %s; run /security-audit first\n' "$state_file" >&2
    return 2
  }
  local fuid="$id_arg" resolved=""
  if [[ -n "$id_arg" ]]; then
    resolved="$(_csa_registry_resolve_display_id "$state_json" "$id_arg")"
  fi
  [[ -n "$resolved" ]] && fuid="$resolved"
  local entry; entry="$(printf '%s' "$state_json" | jq -c --arg k "$fuid" '.findings[$k] // empty')"
  if [[ -z "$entry" ]]; then
    if [[ "$id_arg" == SA-* ]]; then
      printf 'csa: %s names no registered finding in the latest audit (a display id names a line of the latest report, and a SCANNER finding is never registered); nothing suppressed. Use the finding_uid (FUID-...) from the report.\n' "$id_arg" >&2
    else
      printf 'csa: %s is not a finding any recorded audit produced; nothing suppressed\n' "$id_arg" >&2
    fi
    return 3
  fi
  local sevmap; sevmap="$(_csa_state_rule_severities)"
  local severity; severity="$(printf '%s' "$entry" | jq -r --argjson m "$sevmap" '
    def norm: if type == "string" then ascii_downcase else "" end
      | if . == "high" or . == "medium" or . == "low" or . == "info" then . else "critical" end;
    def rank: {"critical":5,"high":4,"medium":3,"low":2,"info":1}[.];
    if type != "object" then "critical" else
      [(.severity | norm), ((if (.rule_id | type) == "string" then $m[.rule_id] else null end) // "info" | norm)]
      | max_by(rank) end')"
  # Only a severity read as one of these four may be suppressed; anything else (critical, or an
  # entry jq could not read) is refused.
  if ! [[ "$severity" =~ ^(high|medium|low|info)$ ]]; then
    printf 'ERROR: Cannot suppress a critical-severity finding.\n' >&2
    return 1
  fi

  # Race-window check: refuse if first_seen < 60s ago.
  local first_seen; first_seen="$(printf '%s' "$entry" | jq -r '.first_seen // empty')"
  if [[ -n "$first_seen" ]]; then
    local fs_epoch; fs_epoch="$(_csa_iso_to_epoch "$first_seen")"
    local now_epoch; now_epoch="$(date -u +%s)"
    if [[ -n "$fs_epoch" && -n "$now_epoch" ]]; then
      local age=$(( now_epoch - fs_epoch ))
      if [[ "$age" -lt 60 ]]; then
        printf 'ERROR: Cannot suppress finding %s — less than 60s since first_seen (%s). Wait and retry.\n' \
          "$fuid" "$first_seen" >&2
        return 1
      fi
    fi
  fi

  local sup_file; sup_file="$(csa_suppress_path "$root")"
  # A missing, empty or whitespace-only file holds no suppressions: start it. Anything else must be
  # one object with a suppressions array, or nothing is written.
  if [[ ! -f "$sup_file" ]] || ! grep -q '[^[:space:]]' "$sup_file"; then csa_suppress_init "$root"; fi
  if ! jq -s -e 'length == 1 and (.[0] | type == "object" and (.suppressions | type) == "array")' \
      "$sup_file" >/dev/null 2>&1; then
    printf 'csa: %s is not a valid suppressions file; nothing suppressed\n' "$sup_file" >&2
    return 2
  fi
  # Idempotent: skip if finding_uid already in suppressions.
  local already; already="$(jq -r --arg k "$fuid" \
    '.suppressions[] | select(.finding_uid == $k) | .finding_uid' "$sup_file" | head -1)"
  if [[ -n "$already" ]]; then
    return 0
  fi

  # Append suppression entry.
  local suppressed_by="${USER:-unknown}"
  local now; now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local tmp; tmp="$(dirname "$sup_file")/suppressions.json.tmp.$$"
  jq \
    --arg fuid "$fuid" \
    --arg note "$note" \
    --arg by "$suppressed_by" \
    --arg at "$now" \
    '.suppressions += [{finding_uid: $fuid, suppressed_by: $by, suppressed_at: $at, note: $note}]' \
    "$sup_file" > "$tmp" && mv "$tmp" "$sup_file"
}

# ---------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------

# csa_suppress_list <project_root>
# Emit each suppression as a JSONL line on stdout.
csa_suppress_list() {
  local root="$1"
  local sup_file; sup_file="$(csa_suppress_path "$root")"
  [[ -f "$sup_file" ]] || return 0
  jq -c '.suppressions[]' "$sup_file"
}

# ---------------------------------------------------------------------------
# Filter
# ---------------------------------------------------------------------------

# csa_suppress_filter <findings_jsonl_file> <project_root>
# Emit only findings whose finding_uid is NOT in suppressions.json. A finding whose severity
# is critical is always emitted, whatever suppressions.json says.
csa_suppress_filter() {
  local findings_file="$1"
  local root="$2"
  local sup_file; sup_file="$(csa_suppress_path "$root")"

  # The suppressed uids as one JSON array; an unreadable file is [] (it hides nothing).
  local suppressed_uids; suppressed_uids="$(_csa_suppressed_uid_set "$sup_file")"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local fuid; fuid="$(printf '%s' "$line" | jq -r '.finding_uid // empty')"
    if [[ -z "$fuid" ]]; then
      printf '%s\n' "$line"
      continue
    fi
    local is_suppressed; is_suppressed="$(printf '%s' "$suppressed_uids" | jq \
      --arg k "$fuid" 'any(.[]; . == $k)')"
    if [[ "$is_suppressed" == "true" ]] \
        && [[ "$(printf '%s' "$line" | jq -r '.severity // empty')" == "critical" ]]; then
      is_suppressed="false"
    fi
    # Only a clear "true" hides a line: an empty or unreadable suppressions file hides nothing.
    if [[ "$is_suppressed" != "true" ]]; then
      printf '%s\n' "$line"
    fi
  done < "$findings_file"
}

# ---------------------------------------------------------------------------
# Remove
# ---------------------------------------------------------------------------

# csa_suppress_remove <project_root> <finding_uid>
# Remove the suppression for finding_uid; every other entry is kept as jq emits it.
# rc 0 removed; rc 1 no such suppression or no file (nothing is written, no file is
# created); rc 2 suppressions.json is not a suppressions file; rc 5 the write failed (the
# file is as it was). Atomic tmp+mv write.
csa_suppress_remove() {
  local root="$1"
  local fuid="$2"
  local sup_file; sup_file="$(csa_suppress_path "$root")"

  if [[ ! -f "$sup_file" ]]; then
    printf 'csa: no suppressions file at %s\n' "$sup_file" >&2
    return 1
  fi

  local present
  present="$(jq -r --arg k "$fuid" \
    'if (.suppressions | type) == "array" then any(.suppressions[]; .finding_uid == $k) else error("no suppressions array") end' \
    "$sup_file" 2>/dev/null)" || present=""
  if [[ -z "$present" ]]; then
    printf 'csa: %s is not a valid suppressions file\n' "$sup_file" >&2
    return 2
  fi
  if [[ "$present" != "true" ]]; then
    printf 'csa: %s is not suppressed\n' "$fuid" >&2
    return 1
  fi

  local tmp; tmp="$(dirname "$sup_file")/suppressions.json.tmp.$$"
  { jq --arg k "$fuid" '.suppressions |= map(select(.finding_uid != $k))' \
      "$sup_file" > "$tmp" && mv "$tmp" "$sup_file"; } 2>/dev/null || {
    rm -f "$tmp" 2>/dev/null
    printf 'csa: could not write %s; the suppression was not removed\n' "$sup_file" >&2
    return 5
  }
}

# ---------------------------------------------------------------------------
# Stale
# ---------------------------------------------------------------------------

# csa_suppress_stale <raw_findings_jsonl_file> <project_root> <focus>
# Emit, as JSONL, {"finding_uid": …} for each suppression whose finding_uid is absent from the raw (unfiltered)
# scan output. Deletes nothing. A suppression can match nothing for reasons outside the
# file (another branch, a disabled plugin), so the caller words the list accordingly.
# rc 0 listed (possibly nothing); rc 2 focus is not "all", or suppressions.json is not a
# suppressions file; rc 3 the scan holds a SCANNER-* or PROVENANCE-002 finding (a rule or
# target failed, or an enabled plugin was not resolved, so uids may be missing from the
# scan and not from the project); rc 4 the findings file is missing or is not JSONL.
# The caller must also run it only when the scan exited 0 with no `csa: warning` on stderr:
# a failed scan prints nothing, and this function cannot see that.
# The fixed FUID-tamper01..03 uids never appear in a scan and are not listed.
csa_suppress_stale() {
  local findings_file="$1"
  local root="$2"
  local focus="$3"
  local sup_file; sup_file="$(csa_suppress_path "$root")"

  if [[ "$focus" != "all" ]]; then
    printf 'csa: stale suppressions need a full scan (no focus); this scan was focused on %s\n' "$focus" >&2
    return 2
  fi
  local partial
  partial="$(jq -s 'any(.[]; (.rule_id // "") | (startswith("SCANNER-") or . == "PROVENANCE-002"))' "$findings_file" 2>/dev/null)" || {
    printf 'csa: %s is missing or is not findings JSONL; stale list not computed\n' "$findings_file" >&2
    return 4
  }
  if [[ "$partial" == "true" ]]; then
    printf 'csa: the scan holds a SCANNER or PROVENANCE-002 finding, so it may be partial; stale list not computed\n' >&2
    return 3
  fi
  [[ -f "$sup_file" ]] || return 0
  if ! jq -e '(.suppressions | type) == "array" and all(.suppressions[]; (.finding_uid | type) == "string")' \
      "$sup_file" >/dev/null 2>&1; then
    printf 'csa: %s is not a valid suppressions file\n' "$sup_file" >&2
    return 2
  fi

  jq -c --slurpfile f "$findings_file" \
    '([$f[] | .finding_uid // empty]) as $live
     | .suppressions[]
     | select(.finding_uid as $u
              | (["FUID-tamper01","FUID-tamper02","FUID-tamper03"] | index($u) | not)
                and ($live | index($u) | not))
     | {finding_uid}' \
    "$sup_file"
}
