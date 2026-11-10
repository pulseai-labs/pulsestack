#!/usr/bin/env bash
# tests/test-e2e-baseline.sh — E2E baseline (NEW/PERSISTED) tagging tests.
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

_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e-bl.XXXXXX")"

_csa_failed=0
_test_n=0

# Do NOT call _next_scratch inside $() — that creates a subshell where
# _test_n increments are lost; all calls would get the same dir.
# Usage: _next_scratch; scratch="$_CSA_TMP/t$_test_n"
_next_scratch() {
  _test_n=$((_test_n + 1))
  mkdir -p "$_CSA_TMP/t$_test_n"
}

# ---------------------------------------------------------------------------
# test_e2e_baseline_repeat_run_persisted
# Audit the hook-injection fixture twice (no changes between runs).
# Second run's findings must be tagged PERSISTED.
# ---------------------------------------------------------------------------
test_e2e_baseline_repeat_run_persisted() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  cp -R "$CSA_FIXTURES_DIR/issues/hook-injection/." "$project/"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"
  csa_state_init "$project"

  # Run 1: scan + tag + filter + state-record.
  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw1.jsonl" 2>/dev/null
  csa_baseline_tag "$scratch/raw1.jsonl" "$project" > "$scratch/tagged1.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged1.jsonl" "$project" > "$scratch/fil1.jsonl" 2>/dev/null
  local out1; out1="$(cat "$scratch/fil1.jsonl")"
  [[ -n "$out1" ]] || { printf '    run1 produced no findings\n' >&2; return 1; }
  csa_state_record_audit "$project" 1 ".claude/audits/run-1.md" "$out1" >/dev/null 2>&1 || true

  # Run 2 (no changes).
  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw2.jsonl" 2>/dev/null
  csa_baseline_tag "$scratch/raw2.jsonl" "$project" > "$scratch/tagged2.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged2.jsonl" "$project" > "$scratch/fil2.jsonl" 2>/dev/null
  local out2; out2="$(cat "$scratch/fil2.jsonl")"
  [[ -n "$out2" ]] || { printf '    run2 produced no findings\n' >&2; return 1; }

  # All run2 findings must be PERSISTED.
  local non_persisted; non_persisted="$(printf '%s\n' "$out2" | jq -r 'select(.state != "PERSISTED") | .finding_uid')"
  [[ -z "$non_persisted" ]] || {
    printf '    run2 has non-PERSISTED findings: %s\n' "$non_persisted" >&2; return 1
  }
}

# ---------------------------------------------------------------------------
# test_e2e_baseline_whitespace_edit_persisted
# Audit hook-injection; add trailing whitespace to the hook script;
# re-audit; same finding_uid still present as PERSISTED (proves T2-I).
# ---------------------------------------------------------------------------
test_e2e_baseline_whitespace_edit_persisted() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  cp -R "$CSA_FIXTURES_DIR/issues/hook-injection/." "$project/"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"
  csa_state_init "$project"

  # Run 1: capture finding_uid.
  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw1.jsonl" 2>/dev/null
  csa_baseline_tag "$scratch/raw1.jsonl" "$project" > "$scratch/tagged1.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged1.jsonl" "$project" > "$scratch/fil1.jsonl" 2>/dev/null
  local out1; out1="$(cat "$scratch/fil1.jsonl")"
  [[ -n "$out1" ]] || { printf '    run1 produced no findings\n' >&2; return 1; }
  local fuid1; fuid1="$(printf '%s\n' "$out1" | jq -r '.finding_uid' | head -1)"
  [[ -n "$fuid1" ]] || { printf '    no finding_uid in run1\n' >&2; return 1; }
  csa_state_record_audit "$project" 1 ".claude/audits/run-1.md" "$out1" >/dev/null 2>&1 || true

  # Add trailing whitespace to the hook script (cosmetic edit).
  printf ' \n' >> "$project/.claude/hooks-handlers/session-start.sh"

  # Run 2.
  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw2.jsonl" 2>/dev/null
  csa_baseline_tag "$scratch/raw2.jsonl" "$project" > "$scratch/tagged2.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged2.jsonl" "$project" > "$scratch/fil2.jsonl" 2>/dev/null
  local out2; out2="$(cat "$scratch/fil2.jsonl")"
  [[ -n "$out2" ]] || { printf '    run2 produced no findings after whitespace edit\n' >&2; return 1; }

  # The same fuid must appear and be PERSISTED.
  local found_persisted; found_persisted="$(printf '%s\n' "$out2" | jq -r --arg k "$fuid1" 'select(.finding_uid == $k and .state == "PERSISTED") | .finding_uid')"
  [[ -n "$found_persisted" ]] || {
    printf '    fuid1=%s not found as PERSISTED in run2 (T2-I regression)\n' "$fuid1" >&2
    printf '    run2 output: %s\n' "$out2" >&2
    return 1
  }
}

# ---------------------------------------------------------------------------
# test_e2e_baseline_new_finding_tagged_new
# Audit a clean fixture; add a CLAUDE.md with a secret; re-audit;
# new finding tagged NEW.
# ---------------------------------------------------------------------------
test_e2e_baseline_new_finding_tagged_new() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  cp -R "$CSA_FIXTURES_DIR/clean/minimal-project/." "$project/"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"
  csa_state_init "$project"

  # Run 1: clean — expect zero findings.
  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw1.jsonl" 2>/dev/null
  csa_baseline_tag "$scratch/raw1.jsonl" "$project" > "$scratch/tagged1.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged1.jsonl" "$project" > "$scratch/fil1.jsonl" 2>/dev/null
  local out1; out1="$(cat "$scratch/fil1.jsonl")"
  csa_state_record_audit "$project" 1 ".claude/audits/run-1.md" "$out1" >/dev/null 2>&1 || true
  [[ -z "$out1" ]] || { printf '    run1 on clean fixture has findings: %s\n' "$out1" >&2; return 1; }

  # Add a CLAUDE.md with a secret.
  printf '# Project\nAPI key: sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' > "$project/CLAUDE.md"

  # Run 2: must find SECRETS-001 tagged NEW.
  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw2.jsonl" 2>/dev/null
  csa_baseline_tag "$scratch/raw2.jsonl" "$project" > "$scratch/tagged2.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged2.jsonl" "$project" > "$scratch/fil2.jsonl" 2>/dev/null
  local out2; out2="$(cat "$scratch/fil2.jsonl")"
  [[ -n "$out2" ]] || { printf '    run2 found no findings after adding secret\n' >&2; return 1; }

  local secrets_new; secrets_new="$(printf '%s\n' "$out2" | jq -r 'select(.rule_id == "SECRETS-001" and .state == "NEW") | .finding_uid')"
  [[ -n "$secrets_new" ]] || {
    printf '    SECRETS-001 not tagged NEW in run2; output: %s\n' "$out2" >&2; return 1
  }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# test_e2e_focused_scans_keep_other_aspects_persisted (#429)
# A full audit records permissions and secrets findings; 11 secrets-only audits
# follow; the next full audit still tags the permissions findings PERSISTED with
# their original first_seen.
# ---------------------------------------------------------------------------
test_e2e_focused_scans_keep_other_aspects_persisted() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  mkdir -p "$project"
  cp -R "$CSA_FIXTURES_DIR/issues/permissions-issue/." "$project/"
  cp "$CSA_FIXTURES_DIR/issues/secrets-issue/CLAUDE.md" "$project/"

  HOME=/nonexistent csa_audit_harness "$project" all > "$scratch/run1.jsonl"
  local perm1; perm1="$(jq -c 'select(.rule_id | startswith("PERM-")) | {finding_uid}' "$scratch/run1.jsonl" | sort)"
  [[ -n "$perm1" ]] || { printf '    run1 produced no permissions findings\n' >&2; return 1; }
  local seen1; seen1="$(jq -c '.findings | with_entries(select(.value.rule_id | startswith("PERM-"))) | map_values(.first_seen)' "$(csa_state_path "$project")")"

  local i
  for i in 1 2 3 4 5 6 7 8 9 10 11; do
    HOME=/nonexistent csa_audit_harness "$project" secrets > /dev/null
  done

  HOME=/nonexistent csa_audit_harness "$project" all > "$scratch/run13.jsonl"
  local perm13; perm13="$(jq -c 'select(.rule_id | startswith("PERM-")) | {finding_uid}' "$scratch/run13.jsonl" | sort)"
  assert_eq "$perm1" "$perm13" "the same permissions findings come back" || return 1
  local relabelled; relabelled="$(jq -r 'select(.rule_id | startswith("PERM-")) | select(.state != "PERSISTED") | .finding_uid' "$scratch/run13.jsonl")"
  assert_eq "" "$relabelled" "permissions findings must stay PERSISTED after secrets-only audits" || return 1
  local seen13; seen13="$(jq -c '.findings | with_entries(select(.value.rule_id | startswith("PERM-"))) | map_values(.first_seen)' "$(csa_state_path "$project")")"
  assert_eq "$seen1" "$seen13" "permissions findings keep their first_seen" || return 1
}

csa_test_run test_e2e_baseline_repeat_run_persisted      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_baseline_whitespace_edit_persisted  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_baseline_new_finding_tagged_new     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_focused_scans_keep_other_aspects_persisted || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
