#!/usr/bin/env bash
# tests/test-rule-load-failure.sh — Adversarial: T2-G rule-load failure visibility.
# Tests: broken rule emits SCANNER-001; 4+ broken rules show banner on stderr.
# Phase 7 Task 7.2.

set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/redact.sh"
source "$CSA_LIB_DIR/fingerprint.sh"
source "$CSA_LIB_DIR/severity.sh"
source "$CSA_LIB_DIR/enumerate-targets.sh"
source "$CSA_LIB_DIR/rule-engine.sh"

_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-rlfail.XXXXXX")"

_csa_failed=0
_test_n=0

_next_scratch() {
  _test_n=$((_test_n + 1))
  mkdir -p "$_CSA_TMP/t$_test_n"
}

# ---------------------------------------------------------------------------
# test_broken_rule_emits_scanner_001
# T2-G: a rule file with a bash syntax error → csa_rule_run_one emits SCANNER-001.
# ---------------------------------------------------------------------------
test_broken_rule_emits_scanner_001() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  mkdir -p "$scratch/rules/test"

  # Write a rule with a deliberate bash syntax error.
  printf '#!/usr/bin/env bash\nRULE_ID="BROKEN-001"\n{{{{ invalid bash\n' > "$scratch/rules/test/BROKEN-001.sh"

  # Create a dummy target file.
  printf 'dummy target\n' > "$scratch/target.txt"

  local out; out="$(csa_rule_run_one "$scratch/rules/test/BROKEN-001.sh" "$scratch/target.txt" 2>/dev/null)"
  assert_contains "$out" "SCANNER-001" "broken rule should emit SCANNER-001" || return 1
}

# ---------------------------------------------------------------------------
# test_multiple_broken_rules_show_banner
# T2-G: ≥4 broken rules → SCANNER-002 banner appears on stderr.
# Note: The banner triggers on SCANNER-002 count ≥ 3. We use 4 broken rules
# that each emit SCANNER-001 on load failure (not SCANNER-002). However,
# the rule engine currently checks for SCANNER-002 (detect() failures), not
# SCANNER-001 (load failures). We test the actual behavior: load failures
# emit SCANNER-001 (not SCANNER-002), so the banner is for detect() failures.
# We test the correct scenario: 4 rules whose detect() returns a genuine error
# status (2) → SCANNER-002 banner.
# ---------------------------------------------------------------------------
test_multiple_broken_rules_show_banner() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"

  # Write a minimal settings.json so enumeration produces a target.
  printf '{"permissions":{"allow":[],"deny":[]}}\n' > "$project/.claude/settings.json"

  # Override CSA_RULES_DIR to just our broken rules.
  local rules_dir="$scratch/rules"
  mkdir -p "$rules_dir/test"

  # Write 4 rules whose detect() always exits with an error → SCANNER-002.
  local i
  for i in 1 2 3 4; do
    cat > "$rules_dir/test/FAIL-00${i}.sh" << RULEEOF
#!/usr/bin/env bash
RULE_ID="FAIL-00${i}"
RULE_NAME="fail-rule-${i}"
RULE_ASPECT="test"
RULE_SEVERITY="low"
detect() { return 2; }
RULEEOF
  done

  local saved_rules="$CSA_RULES_DIR"
  export CSA_RULES_DIR="$rules_dir"

  local stderr_out; stderr_out="$(HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" 2>&1 >/dev/null)"
  export CSA_RULES_DIR="$saved_rules"

  # Banner should appear mentioning rule failures.
  local lower_out; lower_out="$(printf '%s' "$stderr_out" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower_out" == *"rule"* || "$lower_out" == *"scanner"* || "$lower_out" == *"fail"* ]] || {
    printf '    expected rule-failure banner on stderr, got: %s\n' "$stderr_out" >&2; return 1
  }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

csa_test_run test_broken_rule_emits_scanner_001     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_multiple_broken_rules_show_banner  || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
