#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/state.sh"
source "$CSA_LIB_DIR/baseline.sh"

_csa_failed=0

_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"

# ---------------------------------------------------------------------------
# 1. no prior state → all tagged NEW
# ---------------------------------------------------------------------------
test_no_state_all_new() {
  local root="$_CSA_TMP/t01"
  mkdir -p "$root"
  # No state.json — csa_state_read returns '{}'

  local findings_file="$_CSA_TMP/findings-t01.jsonl"
  printf '%s\n' \
    '{"finding_uid":"FUID-aaa","rule_id":"PERM-001","severity":"medium","file":"f.json"}' \
    '{"finding_uid":"FUID-bbb","rule_id":"PERM-002","severity":"low","file":"g.json"}' \
    > "$findings_file"

  local out; out="$(csa_baseline_tag "$findings_file" "$root")"

  local count_new; count_new="$(printf '%s\n' "$out" | jq -r 'select(.state == "NEW")' | jq -r '.state' | wc -l | tr -d ' ')"
  assert_eq "2" "$count_new" "both findings must be NEW when no state exists" || return 1

  local count_persisted; count_persisted="$(printf '%s\n' "$out" | jq -r 'select(.state == "PERSISTED")' | jq -r '.state' | wc -l | tr -d ' ')"
  assert_eq "0" "$count_persisted" "no findings must be PERSISTED when no state exists" || return 1
}

# ---------------------------------------------------------------------------
# 2. all findings in state → all tagged PERSISTED
# ---------------------------------------------------------------------------
test_all_persisted() {
  local root="$_CSA_TMP/t02"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  # Seed state.json with both finding_uids.
  local state_file; state_file="$(csa_state_path "$root")"
  local now="2026-01-15T10:00:00Z"
  jq \
    --arg now "$now" \
    '.findings = {
      "FUID-ccc": {rule_id:"PERM-001",severity:"medium",file:"f.json",first_seen:$now,last_seen:$now,seen_in_runs:1,last_run_index:1,last_display_id:"SA-X-001"},
      "FUID-ddd": {rule_id:"PERM-002",severity:"low",file:"g.json",first_seen:$now,last_seen:$now,seen_in_runs:1,last_run_index:1,last_display_id:"SA-X-002"}
    }' "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"

  local findings_file="$_CSA_TMP/findings-t02.jsonl"
  printf '%s\n' \
    '{"finding_uid":"FUID-ccc","rule_id":"PERM-001","severity":"medium","file":"f.json"}' \
    '{"finding_uid":"FUID-ddd","rule_id":"PERM-002","severity":"low","file":"g.json"}' \
    > "$findings_file"

  local out; out="$(csa_baseline_tag "$findings_file" "$root")"

  local count_persisted; count_persisted="$(printf '%s\n' "$out" | jq -r 'select(.state == "PERSISTED")' | jq -r '.state' | wc -l | tr -d ' ')"
  assert_eq "2" "$count_persisted" "both findings must be PERSISTED when state has both" || return 1

  # Also verify first_seen is carried through.
  local fs; fs="$(printf '%s\n' "$out" | jq -r 'select(.finding_uid == "FUID-ccc") | .first_seen')"
  assert_eq "$now" "$fs" "first_seen must be propagated from state" || return 1
}

# ---------------------------------------------------------------------------
# 3. mixed: one in state (PERSISTED), one not (NEW)
# ---------------------------------------------------------------------------
test_mixed_new_and_persisted() {
  local root="$_CSA_TMP/t03"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  local state_file; state_file="$(csa_state_path "$root")"
  local now="2026-02-20T08:00:00Z"
  # Only FUID-eee is in state.
  jq \
    --arg now "$now" \
    '.findings = {
      "FUID-eee": {rule_id:"PERM-001",severity:"high",file:"x.json",first_seen:$now,last_seen:$now,seen_in_runs:2,last_run_index:3,last_display_id:"SA-Y-001"}
    }' "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"

  local findings_file="$_CSA_TMP/findings-t03.jsonl"
  printf '%s\n' \
    '{"finding_uid":"FUID-eee","rule_id":"PERM-001","severity":"high","file":"x.json"}' \
    '{"finding_uid":"FUID-fff","rule_id":"PERM-003","severity":"low","file":"y.json"}' \
    > "$findings_file"

  local out; out="$(csa_baseline_tag "$findings_file" "$root")"

  local state_eee; state_eee="$(printf '%s\n' "$out" | jq -r 'select(.finding_uid == "FUID-eee") | .state')"
  assert_eq "PERSISTED" "$state_eee" "FUID-eee must be PERSISTED" || return 1

  local state_fff; state_fff="$(printf '%s\n' "$out" | jq -r 'select(.finding_uid == "FUID-fff") | .state')"
  assert_eq "NEW" "$state_fff" "FUID-fff must be NEW" || return 1
}

# ---------------------------------------------------------------------------
# 4. lookup keys on finding_uid, not dedup_fingerprint
# ---------------------------------------------------------------------------
test_lookup_uses_finding_uid_not_fingerprint() {
  local root="$_CSA_TMP/t04"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  local state_file; state_file="$(csa_state_path "$root")"
  local now="2026-03-10T12:00:00Z"
  # State has FUID-ggg but not a matching dedup_fingerprint key.
  jq \
    --arg now "$now" \
    '.findings = {
      "FUID-ggg": {rule_id:"PERM-004",severity:"medium",file:"z.json",first_seen:$now,last_seen:$now,seen_in_runs:1,last_run_index:1,last_display_id:"SA-Z-001"}
    }' "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"

  local findings_file="$_CSA_TMP/findings-t04.jsonl"
  # finding has BOTH finding_uid AND dedup_fingerprint; state only has the finding_uid key.
  printf '%s\n' \
    '{"finding_uid":"FUID-ggg","dedup_fingerprint":"fp-different-value","rule_id":"PERM-004","severity":"medium","file":"z.json"}' \
    > "$findings_file"

  local out; out="$(csa_baseline_tag "$findings_file" "$root")"

  local state_ggg; state_ggg="$(printf '%s\n' "$out" | jq -r '.state')"
  assert_eq "PERSISTED" "$state_ggg" "finding with matching finding_uid must be PERSISTED (not keyed on dedup_fingerprint)" || return 1
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
csa_test_run test_no_state_all_new                          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_all_persisted                             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_mixed_new_and_persisted                   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_lookup_uses_finding_uid_not_fingerprint   || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
