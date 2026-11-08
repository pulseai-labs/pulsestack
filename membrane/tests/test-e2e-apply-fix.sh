#!/usr/bin/env bash
# tests/test-e2e-apply-fix.sh — E2E apply-fix wiring tests.
# Uses a synthetic AUTO=true/MECH=true test rule since all v0.1 production rules
# have RULE_MECHANICALLY_FIXABLE=false (by design — no auto-writes).
# Exercises the full apply-fix path (scan → state-record → apply) end-to-end.
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
source "$CSA_LIB_DIR/apply-fix.sh"

_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e-fix.XXXXXX")"
trap 'rm -rf "$_CSA_TMP"' EXIT

_csa_failed=0
_test_n=0

# Do NOT call inside $() — subshell loses counter increment.
# Usage: _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
_next_scratch() {
  _test_n=$((_test_n + 1))
  mkdir -p "$_CSA_TMP/t$_test_n"
}

# Write a synthetic AUTO+MECH=true rule into <dir>/test/TEST-AUTO.sh.
# BASH_SOURCE-based lib path resolution (same pattern as production rules).
_write_synthetic_rule() {
  local rules_dir="$1"
  mkdir -p "$rules_dir/test"
  cat > "$rules_dir/test/TEST-AUTO.sh" << 'RULEEOF'
#!/usr/bin/env bash
RULE_ID="TEST-AUTO"
RULE_NAME="test-auto-fix"
RULE_ASPECT="test"
RULE_SEVERITY="low"
RULE_DESCRIPTION="Synthetic rule for e2e apply-fix wiring test."
RULE_AUTO_FIXABLE="true"
RULE_MECHANICALLY_FIXABLE="true"
RULE_REMEDIATION="Remove the CSA_E2E_SENTINEL line."
RULE_REFERENCES=""

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  _RULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
  _RULE_DIR="${CSA_LIB_DIR:-}"
fi
source "$_RULE_DIR/fingerprint.sh" 2>/dev/null || true
source "$_RULE_DIR/helpers.sh" 2>/dev/null || true

detect() {
  local target_file="$1"
  [[ -f "$target_file" ]] || return 0
  grep -n 'CSA_E2E_SENTINEL' "$target_file" 2>/dev/null | while IFS=: read -r line_no match; do
    local fuid; fuid="$(csa_finding_uid "TEST-AUTO" "$target_file" "$match")"
    jq -nc \
      --arg rid "TEST-AUTO" \
      --arg f "$target_file" \
      --argjson ln "$line_no" \
      --arg prev "$match" \
      --arg sev "low" \
      --arg fuid "$fuid" \
      '{rule_id: $rid, file: $f, line: $ln, offset: 0, preview: $prev, severity: $sev, finding_uid: $fuid}'
  done
}

fix() {
  local target="$1"
  local tmp; tmp="$(mktemp)"
  grep -v 'CSA_E2E_SENTINEL' "$target" > "$tmp" && mv "$tmp" "$target"
}
RULEEOF
}

# ---------------------------------------------------------------------------
# test_e2e_apply_fix_records_in_state
# Full path: set up project + synthetic rule → scan → state-record → apply-fix.
# Verify state.applied_fixes has the entry and CLAUDE.md no longer has sentinel.
# ---------------------------------------------------------------------------
test_e2e_apply_fix_records_in_state() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  local rules_dir="$scratch/rules"

  mkdir -p "$project/.claude/audits"
  printf '# My project\nCSA_E2E_SENTINEL remove me\n' > "$project/CLAUDE.md"

  _write_synthetic_rule "$rules_dir"

  export CSA_PROJECT_ROOT="$project"
  csa_state_init "$project"

  # Scan using the synthetic rules dir.
  local saved_rules="$CSA_RULES_DIR"
  export CSA_RULES_DIR="$rules_dir"
  csa_rule_engine_scan_all "$project" "all" > "$scratch/raw.jsonl" 2>/dev/null
  export CSA_RULES_DIR="$saved_rules"

  csa_baseline_tag "$scratch/raw.jsonl" "$project" > "$scratch/tagged.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged.jsonl" "$project" > "$scratch/filtered.jsonl" 2>/dev/null

  local findings_content; findings_content="$(cat "$scratch/filtered.jsonl")"
  local fuid; fuid="$(printf '%s\n' "$findings_content" | jq -r '.finding_uid // empty' | head -1)"
  [[ -n "$fuid" ]] || { printf '    no finding emitted by synthetic rule scan\n' >&2; return 1; }

  csa_state_record_audit "$project" 1 ".claude/audits/run-1.md" "$findings_content" >/dev/null 2>&1

  # apply-fix finds the synthetic rule by its RULE_ID in the same rules dir the scan used.
  local state_file; state_file="$(csa_state_path "$project")"
  CSA_RULES_DIR="$rules_dir" csa_apply_run "$project" "$fuid" >/dev/null 2>&1
  local apply_ec=$?
  [[ "$apply_ec" -eq 0 ]] || { printf '    csa_apply_run failed with ec=%d\n' "$apply_ec" >&2; return 1; }

  # Verify state.applied_fixes has an entry.
  local fix_count; fix_count="$(jq --arg k "$fuid" '[.applied_fixes[] | select(.finding_uid == $k)] | length' "$state_file" 2>/dev/null || echo 0)"
  [[ "$fix_count" -gt 0 ]] || { printf '    state.applied_fixes empty after apply\n' >&2; return 1; }

  # Verify sentinel is gone from CLAUDE.md.
  grep -q 'CSA_E2E_SENTINEL' "$project/CLAUDE.md" && {
    printf '    sentinel still present in CLAUDE.md after fix\n' >&2; return 1
  }
  return 0
}

# ---------------------------------------------------------------------------
# test_e2e_apply_fix_refuses_non_auto_rule
# Verify apply-fix validation refuses a rule with RULE_AUTO_FIXABLE=false.
# ---------------------------------------------------------------------------
test_e2e_apply_fix_refuses_non_auto_rule() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  mkdir -p "$scratch/rules/test"

  cat > "$scratch/rules/test/TEST-NOAUTO.sh" << 'RULEEOF'
#!/usr/bin/env bash
RULE_ID="TEST-NOAUTO"
RULE_NAME="test-no-auto"
RULE_ASPECT="test"
RULE_SEVERITY="medium"
RULE_AUTO_FIXABLE="false"
RULE_MECHANICALLY_FIXABLE="true"
RULE_REMEDIATION="Manual fix required."
detect() { return 0; }
fix() { return 0; }
RULEEOF

  local err_out
  err_out="$(csa_apply_validate_rule "$scratch/rules/test/TEST-NOAUTO.sh" 2>&1)"
  local ec=$?
  [[ "$ec" -ne 0 ]] || { printf '    expected non-zero exit from validate_rule, got 0\n' >&2; return 1; }
  local lower_err; lower_err="$(printf '%s' "$err_out" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower_err" == *"auto"* || "$lower_err" == *"fixable"* ]] || {
    printf '    error message did not mention auto/fixable: %s\n' "$err_out" >&2; return 1
  }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

csa_test_run test_e2e_apply_fix_records_in_state      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_apply_fix_refuses_non_auto_rule  || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
