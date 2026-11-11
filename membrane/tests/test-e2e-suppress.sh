#!/usr/bin/env bash
# tests/test-e2e-suppress.sh — E2E suppression tests.
# Phase 7 Task 7.1.

set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/redact.sh"
source "$CSA_LIB_DIR/fingerprint.sh"
source "$CSA_LIB_DIR/severity.sh"
source "$CSA_LIB_DIR/enumerate-targets.sh"
source "$CSA_LIB_DIR/rule-engine.sh"
source "$CSA_LIB_DIR/state.sh"
source "$CSA_LIB_DIR/baseline.sh"
source "$CSA_LIB_DIR/suppress.sh"

_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e-sup.XXXXXX")"

_csa_failed=0
_test_n=0

# Do NOT call inside $() — subshell loses counter increment.
# Usage: _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
_next_scratch() {
  _test_n=$((_test_n + 1))
  mkdir -p "$_CSA_TMP/t$_test_n"
}

# ---------------------------------------------------------------------------
# test_e2e_suppress_medium_disappears_next_run
# Audit permissions-issue (has PERM-001 Medium), suppress it, re-audit;
# the suppressed finding is marked SUPPRESSED in the filtered output.
# ---------------------------------------------------------------------------
test_e2e_suppress_medium_disappears_next_run() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  cp -R "$CSA_FIXTURES_DIR/issues/permissions-issue/." "$project/"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"
  csa_state_init "$project"

  # Run 1: get findings.
  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw1.jsonl" 2>/dev/null
  csa_baseline_tag "$scratch/raw1.jsonl" "$project" > "$scratch/tagged1.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged1.jsonl" "$project" > "$scratch/fil1.jsonl" 2>/dev/null
  local findings1; findings1="$(cat "$scratch/fil1.jsonl")"

  # Find a suppressible (non-critical) finding.
  local medium_fuid; medium_fuid="$(printf '%s\n' "$findings1" | jq -r 'select(.severity == "medium" or .severity == "low" or .severity == "info") | .finding_uid' | head -1)"
  [[ -n "$medium_fuid" ]] || { printf '    no medium/low/info finding in permissions-issue run1\n' >&2; return 1; }

  # Record run1 in state.
  csa_state_record_audit "$project" 1 ".claude/audits/run-1.md" "$findings1" >/dev/null 2>&1 || true

  # Backdate first_seen to bypass the 60-second race-window check.
  local state_file; state_file="$(csa_state_path "$project")"
  local old_ts; old_ts="$(date -u -v-120S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -d '120 seconds ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || printf '2000-01-01T00:00:00Z')"
  jq --arg fuid "$medium_fuid" --arg ts "$old_ts" \
    '.findings[$fuid].first_seen = $ts' \
    "$state_file" > "$scratch/state_patched.json" \
    && mv "$scratch/state_patched.json" "$state_file"

  csa_suppress_add "$project" "$medium_fuid" "e2e test suppression" 2>/dev/null
  local sup_ec=$?
  [[ "$sup_ec" -eq 0 ]] || { printf '    csa_suppress_add failed ec=%d\n' "$sup_ec" >&2; return 1; }

  # Run 2: re-audit; the suppressed fuid is marked SUPPRESSED.
  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw2.jsonl" 2>/dev/null
  csa_baseline_tag "$scratch/raw2.jsonl" "$project" > "$scratch/tagged2.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged2.jsonl" "$project" > "$scratch/fil2.jsonl" 2>/dev/null
  local out2; out2="$(cat "$scratch/fil2.jsonl")"

  local st; st="$(printf '%s\n' "$out2" | jq -r --arg u "$medium_fuid" 'select(.finding_uid == $u) | .state' | sort -u)"
  assert_eq "SUPPRESSED" "$st" "run 2 marks the suppressed finding SUPPRESSED, so it is counted and not listed" || return 1
}

# ---------------------------------------------------------------------------
# test_e2e_suppress_critical_refused
# Record a run that holds a Critical finding, then try to suppress it, naming no severity and
# then naming medium → rc 1 each time, "critical" in stderr, nothing written.
# ---------------------------------------------------------------------------
test_e2e_suppress_critical_refused() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  cp -R "$CSA_FIXTURES_DIR/issues/secrets-issue/." "$project/"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"
  csa_state_init "$project"

  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw.jsonl" 2>/dev/null

  local critical_fuid; critical_fuid="$(jq -r 'select(.severity == "critical") | .finding_uid' "$scratch/raw.jsonl" | head -1)"
  [[ -n "$critical_fuid" ]] || { printf '    no critical finding in secrets-issue\n' >&2; return 1; }
  HOME=/nonexistent csa_audit_harness "$project" all >/dev/null 2>&1
  [[ "$(jq -r --arg k "$critical_fuid" '.findings[$k].severity // empty' "$(csa_state_path "$project")")" == "critical" ]] \
    || { printf '    the recorded run does not hold the Critical finding; setup is vacuous\n' >&2; return 1; }

  local stderr_out ec=0
  stderr_out="$(csa_suppress_add "$project" "$critical_fuid" "should fail" 2>&1 >/dev/null)" || ec=$?
  assert_eq "1" "$ec" "a recorded Critical finding is refused" || return 1
  local lower_err; lower_err="$(printf '%s' "$stderr_out" | tr '[:upper:]' '[:lower:]')"
  assert_contains "$lower_err" "critical" "error should mention critical" || return 1
  ec=0; csa_suppress_add "$project" "$critical_fuid" "medium" "claims medium" >/dev/null 2>&1 || ec=$?
  assert_eq "1" "$ec" "the same finding passed as medium is refused too" || return 1
  assert_eq "0" "$(csa_suppress_list "$project" | wc -l | tr -d ' ')" "nothing was written" || return 1
}

# ---------------------------------------------------------------------------
# test_e2e_suppressed_finding_stays_current_in_registry
# A suppressed finding that still fires keeps updating its registry entry through 12 runs
# (it does not age out), is marked suppressed and counted apart from the severity buckets, and
# once unsuppressed reads PERSISTED with the first_seen it had before it was suppressed.
# ---------------------------------------------------------------------------
test_e2e_suppressed_finding_stays_current_in_registry() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  cp -R "$CSA_FIXTURES_DIR/issues/permissions-issue/." "$project/"
  mkdir -p "$project/.claude/audits" "$scratch/home/.claude"
  export CSA_PROJECT_ROOT="$project"
  export HOME="$scratch/home"
  csa_state_init "$project"
  local state_file; state_file="$(csa_state_path "$project")"

  csa_audit_harness "$project" all > "$scratch/out1.jsonl" 2>/dev/null
  local uid; uid="$(jq -r 'select(.severity == "medium") | .finding_uid' "$scratch/out1.jsonl" | head -1)"
  [[ -n "$uid" ]] || { printf '    no medium finding in permissions-issue\n' >&2; return 1; }
  local before; before="$(jq -r '.audit_history[-1].finding_counts.medium' "$state_file")"
  local first="2026-01-01T00:00:00Z"
  jq --arg u "$uid" --arg t "$first" '.findings[$u].first_seen = $t' "$state_file" > "$scratch/s.json" && mv "$scratch/s.json" "$state_file"
  csa_suppress_add "$project" "$uid" "e2e" || { printf '    suppress_add refused\n' >&2; return 1; }

  local i
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    csa_audit_harness "$project" all > "$scratch/out-r$i.jsonl" 2>/dev/null
  done
  assert_eq "SUPPRESSED" "$(jq -r --arg u "$uid" 'select(.finding_uid == $u) | .state' "$scratch/out-r12.jsonl" | sort -u)" "the report output still marks it suppressed" || return 1
  assert_eq "13" "$(jq -r --arg u "$uid" '.findings[$u].last_run_index // "evicted"' "$state_file")" "registry entry is current after 12 more runs" || return 1
  assert_eq "true" "$(jq -r --arg u "$uid" '.findings[$u].suppressed' "$state_file")" "entry is marked suppressed" || return 1
  assert_eq "$first" "$(jq -r --arg u "$uid" '.findings[$u].first_seen' "$state_file")" "first_seen kept" || return 1
  assert_eq "$((before - 1))" "$(jq -r '.audit_history[-1].finding_counts.medium' "$state_file")" "severity bucket excludes it" || return 1
  assert_eq "1" "$(jq -r '.audit_history[-1].finding_counts.suppressed' "$state_file")" "suppressed total counts it" || return 1

  csa_suppress_remove "$project" "$uid" || { printf '    suppress_remove failed\n' >&2; return 1; }
  csa_audit_harness "$project" all > "$scratch/out-after.jsonl" 2>/dev/null
  local row; row="$(jq -c --arg u "$uid" 'select(.finding_uid == $u)' "$scratch/out-after.jsonl")"
  assert_eq "PERSISTED" "$(jq -r '.state' <<<"$row")" "unsuppressed finding reads PERSISTED, not NEW" || return 1
  assert_eq "$first" "$(jq -r '.first_seen' <<<"$row")" "with its original first_seen" || return 1
  assert_eq "false" "$(jq -r --arg u "$uid" '.findings[$u].suppressed' "$state_file")" "mark cleared once unsuppressed" || return 1
}

# ---------------------------------------------------------------------------
# test_e2e_suppress_race_window_refused
# Record a finding with first_seen=now in state; immediately try to suppress
# → refused (60s race window).
# ---------------------------------------------------------------------------
test_e2e_suppress_race_window_refused() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  cp -R "$CSA_FIXTURES_DIR/issues/permissions-issue/." "$project/"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"
  csa_state_init "$project"

  # Inject a synthetic medium finding with first_seen=now (within race window).
  local fuid="FUID-racetest01"
  local now; now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local state_file; state_file="$(csa_state_path "$project")"
  jq --arg fuid "$fuid" --arg now "$now" \
    '.findings[$fuid] = {rule_id: "PERM-001", severity: "medium", file: ".claude/settings.json", first_seen: $now, last_seen: $now, seen_in_runs: 1, last_run_index: 1, last_display_id: "SA-run-1-001"}' \
    "$state_file" > "$scratch/state_race.json" && mv "$scratch/state_race.json" "$state_file"

  local stderr_out; stderr_out="$(csa_suppress_add "$project" "$fuid" "medium" "race test" 2>&1 >/dev/null)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    expected non-zero exit (race window), got 0\n' >&2; return 1; }
  local lower_err; lower_err="$(printf '%s' "$stderr_out" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower_err" == *"60"* || "$lower_err" == *"race"* || "$lower_err" == *"wait"* ]] || {
    printf '    expected 60s/race/wait in error, got: %s\n' "$stderr_out" >&2; return 1
  }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

csa_test_run test_e2e_suppress_medium_disappears_next_run || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_suppress_critical_refused           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_suppressed_finding_stays_current_in_registry || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_suppress_race_window_refused        || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
