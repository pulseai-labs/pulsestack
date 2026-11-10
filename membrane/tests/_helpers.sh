#!/usr/bin/env bash
# tests/_helpers.sh — shared assertion primitives for security-audit test suite.
# Mirrors architect-critic's bash test harness convention.

set -u

# Cross-platform sha256: sha256sum on Linux, shasum -a 256 on macOS.
csa_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  fi
}

# csa_test_run <test_function_name>
# Prints PASS/FAIL with the function name.
csa_test_run() {
  local fn="$1"
  if "$fn"; then
    printf '  PASS  %s\n' "$fn"
    return 0
  else
    printf '  FAIL  %s\n' "$fn" >&2
    return 1
  fi
}

# assert_eq <expected> <actual> [<message>]
assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-assert_eq}"
  if [[ "$expected" != "$actual" ]]; then
    printf '    %s: expected=%q actual=%q\n' "$msg" "$expected" "$actual" >&2
    return 1
  fi
}

# assert_contains <haystack> <needle> [<message>]
assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-assert_contains}"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf '    %s: needle=%q not found in haystack=%q\n' "$msg" "$needle" "$haystack" >&2
    return 1
  fi
}

# assert_exits_with <expected_exit_code> <command...>
assert_exits_with() {
  local expected_ec="$1"; shift
  local actual_ec=0
  "$@" >/dev/null 2>&1 || actual_ec=$?
  if [[ "$actual_ec" -ne "$expected_ec" ]]; then
    printf '    assert_exits_with: expected_ec=%d actual_ec=%d cmd=%q\n' "$expected_ec" "$actual_ec" "$*" >&2
    return 1
  fi
}

# csa_tmpdir — a sandbox tempdir inside this test file's temp scope (csa_tmp_scope below), removed with it.
csa_tmpdir() {
  mktemp -d "$TMPDIR/csa-test.XXXXXX"
}

# Resolve plugin root regardless of CWD or BASH_SOURCE quirks (architect-critic
# v0.1.3 issue #3 noted; we resolve eagerly here to avoid the same bug).
CSA_PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CSA_PLUGIN_ROOT
export CSA_LIB_DIR="$CSA_PLUGIN_ROOT/lib"
export CSA_RULES_DIR="$CSA_LIB_DIR/rules"
export CSA_FIXTURES_DIR="$CSA_PLUGIN_ROOT/fixtures"

# Every temp dir a test file makes, and every one bin/csa makes under it, lands in one directory that one trap removes
# on EXIT, INT, TERM and HUP: lib/helpers.sh's csa_tmp_scope, the helper bin/csa uses. A test file sets no EXIT trap of
# its own (tests/test-helpers.sh checks), since that would replace this one.
# shellcheck source=/dev/null
source "$CSA_LIB_DIR/helpers.sh"
csa_tmp_scope test || { printf 'tests/_helpers.sh: cannot create a temp directory\n' >&2; exit 1; }

# csa_audit_harness <project_root> [focus]
# The audit's lib calls in this shell, not the skill's steps: scan, tag NEW/PERSISTED, filter suppressions, record
# the run. No display ids, report or bin/csa; errors are swallowed. Emits the filtered findings JSONL on stdout.
# _first_audit in test-suppress-remove-stale.sh runs
# the skill's steps as written. Sets CSA_PROJECT_ROOT = project_root so libs that look at it pick it up.
csa_audit_harness() {
  local root="$1"; local focus="${2:-all}"
  export CSA_PROJECT_ROOT="$root"
  # Source the orchestration libs (idempotent in this subshell).
  source "$CSA_LIB_DIR/helpers.sh"
  source "$CSA_LIB_DIR/redact.sh"
  source "$CSA_LIB_DIR/fingerprint.sh"
  source "$CSA_LIB_DIR/severity.sh"
  source "$CSA_LIB_DIR/enumerate-targets.sh"
  source "$CSA_LIB_DIR/rule-engine.sh"
  source "$CSA_LIB_DIR/state.sh"
  source "$CSA_LIB_DIR/baseline.sh"
  source "$CSA_LIB_DIR/suppress.sh"
  source "$CSA_LIB_DIR/report-render.sh"

  # Ensure state is initialized.
  if [[ ! -f "$(csa_state_path "$root")" ]]; then
    csa_state_init "$root"
  fi

  # 1. Scan
  local raw_findings; raw_findings="$(mktemp)"
  trap "rm -f '$raw_findings'" RETURN
  csa_rule_engine_scan_all "$root" "$focus" > "$raw_findings" 2>/dev/null

  # 2. Tag NEW/PERSISTED
  local tagged; tagged="$(mktemp)"
  trap "rm -f '$raw_findings' '$tagged'" RETURN
  csa_baseline_tag "$raw_findings" "$root" > "$tagged" 2>/dev/null

  # 3. Filter suppressions
  local filtered; filtered="$(mktemp)"
  trap "rm -f '$raw_findings' '$tagged' '$filtered'" RETURN
  csa_suppress_filter "$tagged" "$root" > "$filtered" 2>/dev/null

  # 4. Update state with this run
  local run_index; run_index=$(jq -r '.audit_history | length // 0' "$(csa_state_path "$root")" 2>/dev/null || echo 0)
  run_index=$((run_index + 1))
  local findings_content; findings_content="$(cat "$tagged")"
  csa_state_record_audit "$root" "$run_index" ".claude/audits/run-$run_index.md" "$findings_content" "$focus" >/dev/null 2>&1 || true

  # Emit final findings JSONL
  cat "$filtered"

  rm -f "$raw_findings" "$tagged" "$filtered"
}
