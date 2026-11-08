#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/state.sh"
source "$CSA_LIB_DIR/apply-fix.sh"

_csa_failed=0

_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"
trap 'rm -rf "$_CSA_TMP"' EXIT

# ---------------------------------------------------------------------------
# Helper: set up a tmp project with a rule and a finding in state.
# _setup_apply_fixture <tmp> <rule_id> <auto> <mech> <target_rel>
# Sets FIXTURE_FUID and FIXTURE_RULE_PATH in caller scope (via stdout trick).
# ---------------------------------------------------------------------------
_setup_apply_fixture() {
  local tmp="$1"; local rule_id="$2"; local auto="$3"; local mech="$4"; local target_rel="$5"

  mkdir -p "$tmp/project/.claude/audits"
  mkdir -p "$tmp/rules/test"

  cat > "$tmp/rules/test/${rule_id}.sh" << 'RULEEOF'
RULE_ID="__RULEID__"
RULE_AUTO_FIXABLE="__AUTO__"
RULE_MECHANICALLY_FIXABLE="__MECH__"
RULE_REMEDIATION="test"
detect() { :; }
fix() {
  local target="$1"
  printf 'FIXED\n' > "$target"
}
RULEEOF

  # Substitute placeholders (bash 3.2 safe).
  local rule_file="$tmp/rules/test/${rule_id}.sh"
  sed -i.bak \
    -e "s/__RULEID__/${rule_id}/g" \
    -e "s/__AUTO__/${auto}/g" \
    -e "s/__MECH__/${mech}/g" \
    "$rule_file"
  rm -f "${rule_file}.bak"

  # Bootstrap target file (if not under a non-existent dir).
  local target_dir; target_dir="$(dirname "$tmp/project/$target_rel")"
  mkdir -p "$target_dir"
  touch "$tmp/project/$target_rel"

  # Seed state.json as recorded run 1 leaves it (a display id resolves only in the latest run).
  local fuid="FUID-test1234"
  csa_state_init "$tmp/project"
  local state_path; state_path="$(csa_state_path "$tmp/project")"

  jq \
    --arg fuid "$fuid" \
    --arg rid "$rule_id" \
    --arg f "$target_rel" \
    --arg disp "SA-X-001" \
    --arg rp "$tmp/rules/test/${rule_id}.sh" \
    '.findings[$fuid] = {
      rule_id: $rid,
      severity: "low",
      file: $f,
      first_seen: "2026-01-01T00:00:00Z",
      last_seen: "2026-01-01T00:00:00Z",
      seen_in_runs: 1,
      last_run_index: 1,
      last_display_id: $disp,
      rule_path: $rp
    } | .audit_history = [{run_index: 1, focus: "all"}]' \
    "$state_path" > "$state_path.tmp" && mv "$state_path.tmp" "$state_path"

  # Export values so caller can use them.
  FIXTURE_FUID="$fuid"
  FIXTURE_RULE_PATH="$tmp/rules/test/${rule_id}.sh"
}

# ---------------------------------------------------------------------------
# 1. success — valid rule, both flags true, fix() writes FIXED
# ---------------------------------------------------------------------------
test_success() {
  local tmp="$_CSA_TMP/t01"
  mkdir -p "$tmp"
  _setup_apply_fixture "$tmp" "TEST-001" "true" "true" ".gitignore"

  local out
  out="$(csa_apply_run "$tmp/project" "FUID-test1234" 2>&1)"
  local ec=$?

  [[ "$ec" -eq 0 ]] || { printf '    expected exit 0, got %d. out=%s\n' "$ec" "$out" >&2; return 1; }

  # Target file must contain FIXED.
  local content; content="$(cat "$tmp/project/.gitignore")"
  assert_eq "FIXED" "$content" "target file must contain FIXED" || return 1

  # applied_fixes must have an entry.
  local state_path; state_path="$(csa_state_path "$tmp/project")"
  local fix_count; fix_count="$(jq '[.applied_fixes[] | select(.finding_uid == "FUID-test1234")] | length' "$state_path")"
  assert_eq "1" "$fix_count" "applied_fixes must have 1 entry" || return 1

  # stdout must contain "Applied".
  assert_contains "$out" "Applied" "stdout must contain Applied" || return 1
}

# ---------------------------------------------------------------------------
# 2. finding-not-found — bogus FUID → non-zero + "not found"
# ---------------------------------------------------------------------------
test_finding_not_found() {
  local tmp="$_CSA_TMP/t02"
  mkdir -p "$tmp/project/.claude/audits"
  csa_state_init "$tmp/project"

  local err_out; err_out="$(csa_apply_run "$tmp/project" "FUID-bogus" 2>&1)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    expected non-zero exit\n' >&2; return 1; }
  assert_contains "$err_out" "not found" "stderr must contain 'not found'" || return 1
}

# ---------------------------------------------------------------------------
# 3. rule-AUTO=false refuses
# ---------------------------------------------------------------------------
test_auto_false_refuses() {
  local tmp="$_CSA_TMP/t03"
  mkdir -p "$tmp"
  _setup_apply_fixture "$tmp" "TEST-003" "false" "true" ".gitignore"

  local err_out; err_out="$(csa_apply_run "$tmp/project" "FUID-test1234" 2>&1)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    expected non-zero exit for AUTO=false\n' >&2; return 1; }
  # Must mention allowlist or safe-write.
  if [[ "$err_out" != *"allowlist"* && "$err_out" != *"safe-write"* && "$err_out" != *"RULE_AUTO_FIXABLE"* ]]; then
    printf '    stderr must mention allowlist/safe-write/RULE_AUTO_FIXABLE: %s\n' "$err_out" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# 4. rule-MECH=false refuses
# ---------------------------------------------------------------------------
test_mech_false_refuses() {
  local tmp="$_CSA_TMP/t04"
  mkdir -p "$tmp"
  _setup_apply_fixture "$tmp" "TEST-004" "true" "false" ".gitignore"

  local err_out; err_out="$(csa_apply_run "$tmp/project" "FUID-test1234" 2>&1)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    expected non-zero exit for MECH=false\n' >&2; return 1; }
  # Must mention judgment or manual.
  if [[ "$err_out" != *"judgment"* && "$err_out" != *"manual"* && "$err_out" != *"RULE_MECHANICALLY_FIXABLE"* ]]; then
    printf '    stderr must mention judgment/manual/RULE_MECHANICALLY_FIXABLE: %s\n' "$err_out" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# 5. target-outside-safe-write refuses — file not in allowlist
# ---------------------------------------------------------------------------
test_target_outside_allowlist_refuses() {
  local tmp="$_CSA_TMP/t05"
  mkdir -p "$tmp"
  _setup_apply_fixture "$tmp" "TEST-005" "true" "true" ".claude/hooks-handlers/x.sh"

  local err_out; err_out="$(csa_apply_run "$tmp/project" "FUID-test1234" 2>&1)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    expected non-zero exit for disallowed target\n' >&2; return 1; }
  assert_contains "$err_out" "allowlist" "stderr must mention allowlist" || return 1
}

# ---------------------------------------------------------------------------
# 6. fix-fails records failed entry
# ---------------------------------------------------------------------------
test_fix_fails_records_failed() {
  local tmp="$_CSA_TMP/t06"
  mkdir -p "$tmp/project/.claude/audits"
  mkdir -p "$tmp/rules/test"
  mkdir -p "$tmp/project"

  # Rule that always fails.
  cat > "$tmp/rules/test/TEST-006.sh" << 'EOF'
RULE_ID="TEST-006"
RULE_AUTO_FIXABLE="true"
RULE_MECHANICALLY_FIXABLE="true"
RULE_REMEDIATION="test"
detect() { :; }
fix() {
  return 1
}
EOF

  touch "$tmp/project/.gitignore"
  local fuid="FUID-test1234"
  csa_state_init "$tmp/project"
  local state_path; state_path="$(csa_state_path "$tmp/project")"
  jq \
    --arg fuid "$fuid" \
    --arg rp "$tmp/rules/test/TEST-006.sh" \
    '.findings[$fuid] = {
      rule_id: "TEST-006",
      severity: "low",
      file: ".gitignore",
      first_seen: "2026-01-01T00:00:00Z",
      last_seen: "2026-01-01T00:00:00Z",
      seen_in_runs: 1,
      last_run_index: 1,
      last_display_id: "SA-X-001",
      rule_path: $rp
    }' \
    "$state_path" > "$state_path.tmp" && mv "$state_path.tmp" "$state_path"

  local err_out; err_out="$(csa_apply_run "$tmp/project" "$fuid" 2>&1)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    expected non-zero exit when fix() fails\n' >&2; return 1; }

  # applied_fixes entry must have status="failed".
  local failed_status; failed_status="$(jq -r \
    --arg fuid "$fuid" \
    '[.applied_fixes[] | select(.finding_uid == $fuid)] | last | .status' \
    "$state_path")"
  assert_eq "failed" "$failed_status" "applied_fixes entry status must be failed" || return 1
}

# ---------------------------------------------------------------------------
# 7. double-apply refused
# ---------------------------------------------------------------------------
test_double_apply_refused() {
  local tmp="$_CSA_TMP/t07"
  mkdir -p "$tmp"
  _setup_apply_fixture "$tmp" "TEST-007" "true" "true" ".gitignore"

  # First apply should succeed.
  csa_apply_run "$tmp/project" "FUID-test1234" >/dev/null 2>&1
  local ec1=$?
  [[ "$ec1" -eq 0 ]] || { printf '    first apply must succeed (got %d)\n' "$ec1" >&2; return 1; }

  # Second apply must be refused.
  local err_out; err_out="$(csa_apply_run "$tmp/project" "FUID-test1234" 2>&1)"
  local ec2=$?
  [[ "$ec2" -ne 0 ]] || { printf '    second apply must be refused\n' >&2; return 1; }
  assert_contains "$err_out" "already" "stderr must mention already" || return 1
}

# ---------------------------------------------------------------------------
# 8. T2-H: malicious-rule-lies-about-AUTO
# Rule reports AUTO=true at detection time, then is overwritten to AUTO=false.
# apply_run must re-source and REFUSE.
# ---------------------------------------------------------------------------
test_t2h_malicious_rule_lies_about_auto() {
  local tmp="$_CSA_TMP/t08"
  mkdir -p "$tmp/project/.claude/audits"
  mkdir -p "$tmp/rules/test"
  mkdir -p "$tmp/project"

  # Rule v1: AUTO=true (what detection time saw).
  cat > "$tmp/rules/test/TEST-008.sh" << 'EOF'
RULE_ID="TEST-008"
RULE_AUTO_FIXABLE="true"
RULE_MECHANICALLY_FIXABLE="true"
RULE_REMEDIATION="test"
detect() { :; }
fix() {
  printf 'FIXED\n' > "$1"
}
EOF

  touch "$tmp/project/.gitignore"
  local fuid="FUID-test1234"
  csa_state_init "$tmp/project"
  local state_path; state_path="$(csa_state_path "$tmp/project")"
  jq \
    --arg fuid "$fuid" \
    --arg rp "$tmp/rules/test/TEST-008.sh" \
    '.findings[$fuid] = {
      rule_id: "TEST-008",
      severity: "low",
      file: ".gitignore",
      first_seen: "2026-01-01T00:00:00Z",
      last_seen: "2026-01-01T00:00:00Z",
      seen_in_runs: 1,
      last_run_index: 1,
      last_display_id: "SA-X-001",
      rule_path: $rp
    }' \
    "$state_path" > "$state_path.tmp" && mv "$state_path.tmp" "$state_path"

  # OVERWRITE rule_file with rule_v2: AUTO=false (malicious swap after detection).
  cat > "$tmp/rules/test/TEST-008.sh" << 'EOF'
RULE_ID="TEST-008"
RULE_AUTO_FIXABLE="false"
RULE_MECHANICALLY_FIXABLE="true"
RULE_REMEDIATION="test"
detect() { :; }
fix() {
  printf 'PWNED\n' > "$1"
}
EOF

  # apply_run must re-validate and REFUSE.
  local err_out; err_out="$(csa_apply_run "$tmp/project" "$fuid" 2>&1)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    T2-H: expected non-zero exit after rule swap AUTO→false\n' >&2; return 1; }

  # Target must NOT have been written (fix should never have run).
  local content; content="$(cat "$tmp/project/.gitignore" 2>/dev/null || true)"
  if [[ "$content" == "PWNED" ]]; then
    printf '    T2-H: fix() ran despite malicious AUTO=false rule — SECURITY FAILURE\n' >&2
    return 1
  fi

  printf '    T2-H malicious-rule-lies-about-AUTO: correctly refused\n'
}

# ---------------------------------------------------------------------------
# 9. T2-H: malicious-rule-targets-symlink
# .gitignore on disk is a symlink → apply_validate_target must detect + REFUSE.
# ---------------------------------------------------------------------------
test_t2h_symlink_target_refused() {
  local tmp="$_CSA_TMP/t09"
  mkdir -p "$tmp/project/.claude/audits"
  mkdir -p "$tmp/rules/test"
  mkdir -p "$tmp/project"

  cat > "$tmp/rules/test/TEST-009.sh" << 'EOF'
RULE_ID="TEST-009"
RULE_AUTO_FIXABLE="true"
RULE_MECHANICALLY_FIXABLE="true"
RULE_REMEDIATION="test"
detect() { :; }
fix() {
  printf 'FIXED\n' > "$1"
}
EOF

  # Create a real file in tmp, then make .gitignore a symlink to it.
  local real_file="$tmp/real-target.txt"
  printf 'original\n' > "$real_file"
  ln -s "$real_file" "$tmp/project/.gitignore"

  local fuid="FUID-test1234"
  csa_state_init "$tmp/project"
  local state_path; state_path="$(csa_state_path "$tmp/project")"
  jq \
    --arg fuid "$fuid" \
    --arg rp "$tmp/rules/test/TEST-009.sh" \
    '.findings[$fuid] = {
      rule_id: "TEST-009",
      severity: "low",
      file: ".gitignore",
      first_seen: "2026-01-01T00:00:00Z",
      last_seen: "2026-01-01T00:00:00Z",
      seen_in_runs: 1,
      last_run_index: 1,
      last_display_id: "SA-X-001",
      rule_path: $rp
    }' \
    "$state_path" > "$state_path.tmp" && mv "$state_path.tmp" "$state_path"

  local err_out; err_out="$(csa_apply_run "$tmp/project" "$fuid" 2>&1)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    T2-H: expected non-zero exit for symlink target\n' >&2; return 1; }
  assert_contains "$err_out" "symlink" "stderr must mention symlink" || return 1

  # Real file must be untouched.
  local content; content="$(cat "$real_file")"
  assert_eq "original" "$content" "real file must not have been written" || return 1

  printf '    T2-H malicious-rule-targets-symlink: correctly refused\n'
}

# ---------------------------------------------------------------------------
# 10. T2-H: malicious-rule-path-traversal
# finding.file contains path traversal (../etc/passwd style).
# csa_realpath normalizes; validate_target detects outside-root → REFUSE.
# ---------------------------------------------------------------------------
test_t2h_path_traversal_refused() {
  local tmp="$_CSA_TMP/t10"
  mkdir -p "$tmp/project/.claude/audits"
  mkdir -p "$tmp/rules/test"
  mkdir -p "$tmp/project"

  cat > "$tmp/rules/test/TEST-010.sh" << 'EOF'
RULE_ID="TEST-010"
RULE_AUTO_FIXABLE="true"
RULE_MECHANICALLY_FIXABLE="true"
RULE_REMEDIATION="test"
detect() { :; }
fix() {
  printf 'PWNED\n' > "$1"
}
EOF

  # Traversal path: tries to escape project root.
  # We use a relative traversal that would resolve to $tmp (parent of project/).
  local traversal_path="../pwned-file.txt"
  # Touch the traversal target so csa_realpath can resolve through parent.
  touch "$tmp/pwned-file.txt"

  local fuid="FUID-test1234"
  csa_state_init "$tmp/project"
  local state_path; state_path="$(csa_state_path "$tmp/project")"
  jq \
    --arg fuid "$fuid" \
    --arg rp "$tmp/rules/test/TEST-010.sh" \
    --arg traversal "$traversal_path" \
    '.findings[$fuid] = {
      rule_id: "TEST-010",
      severity: "low",
      file: $traversal,
      first_seen: "2026-01-01T00:00:00Z",
      last_seen: "2026-01-01T00:00:00Z",
      seen_in_runs: 1,
      last_run_index: 1,
      last_display_id: "SA-X-001",
      rule_path: $rp
    }' \
    "$state_path" > "$state_path.tmp" && mv "$state_path.tmp" "$state_path"

  local err_out; err_out="$(csa_apply_run "$tmp/project" "$fuid" 2>&1)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    T2-H: expected non-zero exit for path traversal\n' >&2; return 1; }
  # Must refuse due to allowlist (traversal path is not .gitignore etc.) OR traversal detection.
  if [[ "$err_out" != *"allowlist"* && "$err_out" != *"traversal"* && "$err_out" != *"outside"* ]]; then
    printf '    T2-H: stderr must mention allowlist/traversal/outside: %s\n' "$err_out" >&2
    return 1
  fi

  # Traversal target must not have been written.
  local content; content="$(cat "$tmp/pwned-file.txt" 2>/dev/null || true)"
  if [[ "$content" == "PWNED" ]]; then
    printf '    T2-H: fix() ran despite path traversal — SECURITY FAILURE\n' >&2
    return 1
  fi

  printf '    T2-H malicious-rule-path-traversal: correctly refused\n'
}

# ---------------------------------------------------------------------------
# 11. display-id resolves to finding-uid
# ---------------------------------------------------------------------------
test_display_id_resolves() {
  local tmp="$_CSA_TMP/t11"
  mkdir -p "$tmp"
  _setup_apply_fixture "$tmp" "TEST-011" "true" "true" ".gitignore"
  # FUID-test1234 has last_display_id="SA-X-001" (set by _setup_apply_fixture).

  local out
  out="$(csa_apply_run "$tmp/project" "SA-X-001" 2>&1)"
  local ec=$?

  [[ "$ec" -eq 0 ]] || { printf '    display_id resolve must succeed (got %d). out=%s\n' "$ec" "$out" >&2; return 1; }
  assert_contains "$out" "Applied" "stdout must contain Applied" || return 1
  assert_contains "$out" "FUID-test1234" "stdout must contain the resolved FUID" || return 1
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
csa_test_run test_success                              || _csa_failed=$((_csa_failed + 1))
csa_test_run test_finding_not_found                    || _csa_failed=$((_csa_failed + 1))
csa_test_run test_auto_false_refuses                   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_mech_false_refuses                   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_target_outside_allowlist_refuses     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_fix_fails_records_failed             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_double_apply_refused                 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_t2h_malicious_rule_lies_about_auto   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_t2h_symlink_target_refused           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_t2h_path_traversal_refused           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_display_id_resolves                  || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
