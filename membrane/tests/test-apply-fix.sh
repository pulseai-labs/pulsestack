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
# Sets FIXTURE_FUID and FIXTURE_RULE_PATH in caller scope. The rule is found by its RULE_ID under <tmp>/rules
# (_apply); the registry entry holds no rule path, as membrane writes it.
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
    '.findings[$fuid] = {
      rule_id: $rid,
      severity: "low",
      file: $f,
      first_seen: "2026-01-01T00:00:00Z",
      last_seen: "2026-01-01T00:00:00Z",
      seen_in_runs: 1,
      last_run_index: 1,
      last_display_id: $disp
    } | .audit_history = [{run_index: 1, focus: "all"}]' \
    "$state_path" > "$state_path.tmp" && mv "$state_path.tmp" "$state_path"

  # Export values so caller can use them.
  FIXTURE_FUID="$fuid"
  FIXTURE_RULE_PATH="$tmp/rules/test/${rule_id}.sh"
}

# _apply <tmp> <id> — csa_apply_run on <tmp>/project with <tmp>/rules as the shipped rules dir.
_apply() { CSA_RULES_DIR="$1/rules" csa_apply_run "$1/project" "$2"; }

# ---------------------------------------------------------------------------
# 1. success — valid rule, both flags true, fix() writes FIXED
# ---------------------------------------------------------------------------
test_success() {
  local tmp="$_CSA_TMP/t01"
  mkdir -p "$tmp"
  _setup_apply_fixture "$tmp" "TEST-001" "true" "true" ".gitignore"

  local out
  out="$(_apply "$tmp" "FUID-test1234" 2>&1)"
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

  local err_out; err_out="$(_apply "$tmp" "FUID-bogus" 2>&1)"
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

  local err_out; err_out="$(_apply "$tmp" "FUID-test1234" 2>&1)"
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

  local err_out; err_out="$(_apply "$tmp" "FUID-test1234" 2>&1)"
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

  local err_out; err_out="$(_apply "$tmp" "FUID-test1234" 2>&1)"
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
    '.findings[$fuid] = {
      rule_id: "TEST-006",
      severity: "low",
      file: ".gitignore",
      first_seen: "2026-01-01T00:00:00Z",
      last_seen: "2026-01-01T00:00:00Z",
      seen_in_runs: 1,
      last_run_index: 1,
      last_display_id: "SA-X-001"
    }' \
    "$state_path" > "$state_path.tmp" && mv "$state_path.tmp" "$state_path"

  local err_out; err_out="$(_apply "$tmp" "$fuid" 2>&1)"
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
  _apply "$tmp" "FUID-test1234" >/dev/null 2>&1
  local ec1=$?
  [[ "$ec1" -eq 0 ]] || { printf '    first apply must succeed (got %d)\n' "$ec1" >&2; return 1; }

  # Second apply must be refused.
  local err_out; err_out="$(_apply "$tmp" "FUID-test1234" 2>&1)"
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
    '.findings[$fuid] = {
      rule_id: "TEST-008",
      severity: "low",
      file: ".gitignore",
      first_seen: "2026-01-01T00:00:00Z",
      last_seen: "2026-01-01T00:00:00Z",
      seen_in_runs: 1,
      last_run_index: 1,
      last_display_id: "SA-X-001"
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
  local err_out; err_out="$(_apply "$tmp" "$fuid" 2>&1)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    T2-H: expected non-zero exit after rule swap AUTO→false\n' >&2; return 1; }
  # Refused for the swap itself: the rule was found, re-read, and its AUTO flag is false.
  assert_contains "$err_out" 'RULE_AUTO_FIXABLE="false"' "refused on the swapped AUTO flag" || return 1

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
    '.findings[$fuid] = {
      rule_id: "TEST-009",
      severity: "low",
      file: ".gitignore",
      first_seen: "2026-01-01T00:00:00Z",
      last_seen: "2026-01-01T00:00:00Z",
      seen_in_runs: 1,
      last_run_index: 1,
      last_display_id: "SA-X-001"
    }' \
    "$state_path" > "$state_path.tmp" && mv "$state_path.tmp" "$state_path"

  local err_out; err_out="$(_apply "$tmp" "$fuid" 2>&1)"
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
    --arg traversal "$traversal_path" \
    '.findings[$fuid] = {
      rule_id: "TEST-010",
      severity: "low",
      file: $traversal,
      first_seen: "2026-01-01T00:00:00Z",
      last_seen: "2026-01-01T00:00:00Z",
      seen_in_runs: 1,
      last_run_index: 1,
      last_display_id: "SA-X-001"
    }' \
    "$state_path" > "$state_path.tmp" && mv "$state_path.tmp" "$state_path"

  local err_out; err_out="$(_apply "$tmp" "$fuid" 2>&1)"
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
  out="$(_apply "$tmp" "SA-X-001" 2>&1)"
  local ec=$?

  [[ "$ec" -eq 0 ]] || { printf '    display_id resolve must succeed (got %d). out=%s\n' "$ec" "$out" >&2; return 1; }
  assert_contains "$out" "Applied" "stdout must contain Applied" || return 1
  assert_contains "$out" "FUID-test1234" "stdout must contain the resolved FUID" || return 1
}

# ---------------------------------------------------------------------------
# 12. The rule is found by its RULE_ID among the shipped rules, never by a path in state.json
# ---------------------------------------------------------------------------

# _seed_entry <project> <fuid> <json-object> — state.json with one registry entry of recorded run 1.
_seed_entry() {
  csa_state_init "$1"
  local sp; sp="$(csa_state_path "$1")"
  jq --arg fuid "$2" --argjson e "$3" \
    '.findings[$fuid] = ({severity: "low", first_seen: "2026-01-01T00:00:00Z", last_seen: "2026-01-01T00:00:00Z",
       seen_in_runs: 1, last_run_index: 1, last_display_id: "SA-X-001"} + $e) | .audit_history = [{run_index: 1, focus: "all"}]' \
    "$sp" > "$sp.tmp" && mv "$sp.tmp" "$sp"
}

# A registry entry whose rule_path names a file outside the shipped rules is never sourced, through bin/csa, by uid
# and by display id: the marker that file's top-level code would write stays absent and the call exits non-zero.
# With a shipped rule_id the refusal is that rule's own (PERM-002 is not mechanically fixable); with an unknown
# rule_id it is "no shipped rule".
test_forged_rule_path_is_never_sourced() {
  local tmp="$_CSA_TMP/t12" rid id out rc
  mkdir -p "$tmp/project"; touch "$tmp/project/.gitignore"
  printf 'printf "top-level\\n" >> %q\nRULE_AUTO_FIXABLE="false"\n' "$tmp/MARKER" > "$tmp/evil.sh"
  for rid in PERM-002 NO-SUCH-001; do
    _seed_entry "$tmp/project" FUID-0000beef "$(jq -nc --arg r "$rid" --arg p "$tmp/evil.sh" '{rule_id: $r, file: ".gitignore", rule_path: $p}')"
    for id in FUID-0000beef SA-X-001; do
      rc=0; out="$(cd "$tmp/project" && HOME="$tmp/home" "$CSA_PLUGIN_ROOT/bin/csa" apply_run "$tmp/project" "$id" 2>&1)" || rc=$?
      [[ "$rc" -ne 0 ]] || { printf '    %s/%s: expected a refusal, got rc 0: %s\n' "$rid" "$id" "$out" >&2; return 1; }
      [[ ! -e "$tmp/MARKER" ]] || { printf '    %s/%s: the rule_path file was sourced: %s\n' "$rid" "$id" "$(cat "$tmp/MARKER")" >&2; return 1; }
      case "$rid" in
        PERM-002) assert_contains "$out" 'RULE_MECHANICALLY_FIXABLE="false"' "$id: refused for the shipped rule's own reason" || return 1 ;;
        *) assert_contains "$out" "No shipped rule has rule_id=NO-SUCH-001" "$id: refused as no shipped rule" || return 1 ;;
      esac
    done
  done
}

# A forged rule_path file that declares both flags true and defines fix() is not sourced and its fix() never runs:
# rc non-zero, no marker, the target unchanged, and nothing logged in applied_fixes.
test_forged_rule_path_with_both_flags_and_fix_never_runs() {
  local tmp="$_CSA_TMP/t13" out rc=0
  mkdir -p "$tmp/project"; printf 'keep\n' > "$tmp/project/.gitignore"
  cat > "$tmp/evil.sh" <<EOF
printf 'top-level\n' >> $(printf '%q' "$tmp/MARKER")
RULE_ID="TEST-FORGED-001"
RULE_AUTO_FIXABLE="true"
RULE_MECHANICALLY_FIXABLE="true"
fix() { printf 'fix(%s)\n' "\$1" >> $(printf '%q' "$tmp/MARKER"); }
EOF
  _seed_entry "$tmp/project" FUID-0000beef "$(jq -nc --arg p "$tmp/evil.sh" '{rule_id: "TEST-FORGED-001", file: ".gitignore", rule_path: $p}')"
  out="$(cd "$tmp/project" && HOME="$tmp/home" "$CSA_PLUGIN_ROOT/bin/csa" apply_run "$tmp/project" FUID-0000beef 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || { printf '    expected a refusal, got rc 0: %s\n' "$out" >&2; return 1; }
  [[ ! -e "$tmp/MARKER" ]] || { printf '    the forged file ran: %s\n' "$(cat "$tmp/MARKER")" >&2; return 1; }
  assert_eq "keep" "$(cat "$tmp/project/.gitignore")" "the target is unchanged" || return 1
  assert_eq "0" "$(jq '.applied_fixes | length' "$(csa_state_path "$tmp/project")")" "nothing is logged" || return 1
}

# The registry's rule_id is compared whole against each rule file's RULE_ID line: a glob (`*`) and a prefix of a
# fixable rule's id (TEST-00 for TEST-001) are refused, and the target is not written.
test_rule_id_glob_or_prefix_is_refused() {
  local tmp rid sp n=0
  for rid in '*' 'TEST-00' 'TEST-0?1'; do
    n=$((n + 1)); tmp="$_CSA_TMP/t14-$n"; mkdir -p "$tmp"
    _setup_apply_fixture "$tmp" "TEST-001" "true" "true" ".gitignore"
    sp="$(csa_state_path "$tmp/project")"
    jq --arg r "$rid" '.findings["FUID-test1234"].rule_id = $r' "$sp" > "$sp.tmp" && mv "$sp.tmp" "$sp"
    local out rc=0; out="$(_apply "$tmp" FUID-test1234 2>&1)" || rc=$?
    [[ "$rc" -ne 0 ]] || { printf '    rule_id %s: expected a refusal, got rc 0: %s\n' "$rid" "$out" >&2; return 1; }
    assert_contains "$out" "No shipped rule has rule_id=" "rule_id $rid: no shipped rule" || return 1
    assert_eq "" "$(cat "$tmp/project/.gitignore")" "rule_id $rid: the target is not written" || return 1
  done
}

# A rule whose file name is a slug and whose id has two words before its number (the shape of PROMPT-INJ-001) is
# found by its RULE_ID line and applied.
test_slug_named_two_segment_rule_resolves() {
  local tmp="$_CSA_TMP/t15"
  mkdir -p "$tmp/project" "$tmp/rules/test"; touch "$tmp/project/.gitignore"
  printf '%s\n' 'RULE_ID="TEST-TWO-001"' 'RULE_AUTO_FIXABLE="true"' 'RULE_MECHANICALLY_FIXABLE="true"' \
    'fix() { printf '"'"'FIXED\n'"'"' > "$1"; }' > "$tmp/rules/test/two-segment-slug.sh"
  _seed_entry "$tmp/project" FUID-test1234 '{"rule_id":"TEST-TWO-001","file":".gitignore"}'
  local out rc=0; out="$(_apply "$tmp" FUID-test1234 2>&1)" || rc=$?
  assert_eq "0" "$rc" "applied: $out" || return 1
  assert_eq "FIXED" "$(cat "$tmp/project/.gitignore")" "the slug-named rule's fix ran" || return 1
}

# Two rule files that declare the same RULE_ID resolve to neither, and a rule file that is a symlink is not a shipped
# rule: both are refused and the target is not written. Control: the same rule as a regular file applies.
test_duplicate_or_symlinked_rule_is_refused() {
  local tmp="$_CSA_TMP/t16" body out rc
  body="$(printf '%s\n' 'RULE_AUTO_FIXABLE="true"' 'RULE_MECHANICALLY_FIXABLE="true"' 'fix() { printf '"'"'FIXED\n'"'"' > "$1"; }')"
  mkdir -p "$tmp/project" "$tmp/rules/a" "$tmp/rules/b" "$tmp/elsewhere"; touch "$tmp/project/.gitignore"
  printf 'RULE_ID="TEST-DUP-001"\n%s\n' "$body" > "$tmp/rules/a/one.sh"
  printf 'RULE_ID="TEST-DUP-001"\n%s\n' "$body" > "$tmp/rules/b/two.sh"
  printf 'RULE_ID="TEST-LNK-001"\n%s\n' "$body" > "$tmp/elsewhere/real.sh"
  ln -s ../../elsewhere/real.sh "$tmp/rules/a/link.sh"
  local rid
  for rid in TEST-DUP-001 TEST-LNK-001; do
    _seed_entry "$tmp/project" FUID-test1234 "$(jq -nc --arg r "$rid" '{rule_id: $r, file: ".gitignore"}')"
    rc=0; out="$(_apply "$tmp" FUID-test1234 2>&1)" || rc=$?
    [[ "$rc" -ne 0 ]] || { printf '    %s: expected a refusal, got rc 0\n' "$rid" >&2; return 1; }
    assert_contains "$out" "No shipped rule has rule_id=$rid" "$rid: refused" || return 1
    assert_eq "" "$(cat "$tmp/project/.gitignore")" "$rid: the target is not written" || return 1
  done
  rm "$tmp/rules/a/link.sh"; cp "$tmp/elsewhere/real.sh" "$tmp/rules/a/real.sh"
  rc=0; out="$(_apply "$tmp" FUID-test1234 2>&1)" || rc=$?
  assert_eq "0" "$rc" "control: a regular rule file applies: $out" || return 1
}

# A registry entry whose file is an absolute path under a project root holding glob characters (`[`, `\`) is
# placed inside that root, so the allowlisted target applies.
test_absolute_target_under_a_glob_bearing_root_applies() {
  local name tmp out rc
  for name in 'p[r]j' 'p\rj'; do
    tmp="$_CSA_TMP/t17/$name"; mkdir -p "$tmp"
    _setup_apply_fixture "$tmp" "TEST-017" "true" "true" ".gitignore"
    local sp; sp="$(csa_state_path "$tmp/project")"
    jq --arg f "$tmp/project/.gitignore" '.findings["FUID-test1234"].file = $f' "$sp" > "$sp.tmp" && mv "$sp.tmp" "$sp"
    rc=0; out="$(_apply "$tmp" FUID-test1234 2>&1)" || rc=$?
    assert_eq "0" "$rc" "root $name: applied: $out" || return 1
    assert_eq "FIXED" "$(cat "$tmp/project/.gitignore")" "root $name: the target was written" || return 1
  done
}

# ---------------------------------------------------------------------------
# 13. Through bin/csa (set -euo pipefail): a fix() that fails is reported and its entry marked failed; an audit trail
# that is not a list, or that cannot be written, refuses before fix() runs.
# ---------------------------------------------------------------------------

# _bin_fixture <tmp> <fix-body> — a rule TEST-901 under <tmp>/rules with both flags true and `fix() { <fix-body>; }`,
# a project with an empty .gitignore, and a registry entry FUID-test1234 (SA-X-001) for it. fix() sees $MARK, a
# marker file under <tmp>.
_bin_fixture() {
  mkdir -p "$1/rules/test" "$1/project" "$1/home"
  printf '%s\n' 'RULE_ID="TEST-901"' 'RULE_AUTO_FIXABLE="true"' 'RULE_MECHANICALLY_FIXABLE="true"' \
    "fix() { $2; }" > "$1/rules/test/bin-rule.sh"
  : > "$1/project/.gitignore"
  _seed_entry "$1/project" FUID-test1234 '{"rule_id":"TEST-901","file":".gitignore"}'
}

# _bin_apply <tmp> — bin/csa apply_run FUID-test1234 on <tmp>/project; sets _out (stdout and stderr) and _rc.
_bin_apply() {
  _rc=0
  _out="$(cd "$1/project" && HOME="$1/home" MARK="$1/marker" CSA_RULES_DIR="$1/rules" \
    "$CSA_PLUGIN_ROOT/bin/csa" apply_run "$1/project" FUID-test1234 2>&1)" || _rc=$?
}

# _trail <tmp> — the statuses of applied_fixes as a JSON list, or applied_fixes itself when it is not a list.
_trail() { jq -c '.applied_fixes | if type == "array" then map(.status) else . end' "$(csa_state_path "$1/project")"; }

# _ran <tmp> — how many times fix() wrote the marker.
_ran() { if [[ -f "$1/marker" ]]; then wc -l < "$1/marker" | tr -d ' '; else printf '0'; fi; }

# _tmpfiles <tmp> — how many state.json.tmp.* files are left in .claude/audits/.
_tmpfiles() { find "$1/project/.claude/audits" -name 'state.json.tmp.*' | wc -l | tr -d ' '; }

# A fix() that returns 1 is reported, exit 1, and its entry is marked failed; a second apply_run is not refused as
# already applied: fix() runs again and a second failed entry is added.
test_bin_failing_fix_is_reported_and_marked_failed() {
  local tmp="$_CSA_TMP/t18"
  _bin_fixture "$tmp" 'printf "ran\n" >> "$MARK"; return 1'
  _bin_apply "$tmp"
  assert_eq "1" "$_rc" "exit 1: $_out" || return 1
  assert_contains "$_out" "ERROR: fix() failed for SA-X-001 (FUID-test1234)" "the failure is reported" || return 1
  assert_eq '["failed"]' "$(_trail "$tmp")" "the entry is marked failed" || return 1
  _bin_apply "$tmp"
  assert_eq "1" "$_rc" "retry: exit 1: $_out" || return 1
  [[ "$_out" != *"already been applied"* ]] || { printf '    the retry was refused as already applied\n' >&2; return 1; }
  assert_eq "2" "$(_ran "$tmp")" "fix() ran on the retry" || return 1
  assert_eq '["failed","failed"]' "$(_trail "$tmp")" "the retry adds a failed entry" || return 1
}

# A fix() whose first command fails stops there: the command after it does not run, exit 1, the entry is failed.
test_bin_fix_stops_at_its_first_failing_command() {
  local tmp="$_CSA_TMP/t19"
  _bin_fixture "$tmp" 'false; printf "after\n" >> "$MARK"; return 0'
  _bin_apply "$tmp"
  assert_eq "1" "$_rc" "exit 1: $_out" || return 1
  assert_contains "$_out" "ERROR: fix() failed for SA-X-001" "the failure is reported" || return 1
  assert_eq "0" "$(_ran "$tmp")" "nothing after the failing command ran" || return 1
  assert_eq '["failed"]' "$(_trail "$tmp")" "the entry is marked failed" || return 1
}

# Control: a fix() that succeeds applies, exit 0, one applied entry, no tmp file left.
test_bin_succeeding_fix_applies() {
  local tmp="$_CSA_TMP/t20"
  _bin_fixture "$tmp" 'printf "ran\n" >> "$MARK"; return 0'
  _bin_apply "$tmp"
  assert_eq "0" "$_rc" "exit 0: $_out" || return 1
  assert_contains "$_out" "Applied SA-X-001 (FUID-test1234)" "applied" || return 1
  assert_eq "1" "$(_ran "$tmp")" "fix() ran once" || return 1
  assert_eq '["applied"]' "$(_trail "$tmp")" "one applied entry" || return 1
  assert_eq "0" "$(_tmpfiles "$tmp")" "no tmp file left" || return 1
}

# applied_fixes that is an object or a string is refused before fix() runs: exit 1, the refusal names it, fix() does
# not run, applied_fixes is unchanged and no tmp file is left. Absent or null reads as an empty list and applies.
test_bin_applied_fixes_not_a_list_is_refused() {
  local tmp af n=0 sp
  for af in '{}' '"x"' 'null' 'absent'; do
    n=$((n + 1)); tmp="$_CSA_TMP/t21-$n"
    _bin_fixture "$tmp" 'printf "ran\n" >> "$MARK"; return 0'
    sp="$(csa_state_path "$tmp/project")"
    if [[ "$af" == absent ]]; then jq 'del(.applied_fixes)' "$sp" > "$sp.t"
    else jq --argjson af "$af" '.applied_fixes = $af' "$sp" > "$sp.t"; fi
    mv "$sp.t" "$sp"
    _bin_apply "$tmp"
    case "$af" in
      null|absent)
        assert_eq "0" "$_rc" "applied_fixes $af: applies: $_out" || return 1
        assert_eq '["applied"]' "$(_trail "$tmp")" "applied_fixes $af: one applied entry" || return 1 ;;
      *)
        assert_eq "1" "$_rc" "applied_fixes $af: exit 1: $_out" || return 1
        assert_contains "$_out" "applied_fixes is not a list" "applied_fixes $af: the refusal names it" || return 1
        assert_eq "0" "$(_ran "$tmp")" "applied_fixes $af: fix() did not run" || return 1
        assert_eq "$af" "$(_trail "$tmp")" "applied_fixes $af: unchanged" || return 1
        assert_eq "0" "$(_tmpfiles "$tmp")" "applied_fixes $af: no tmp file left" || return 1 ;;
    esac
  done
}

# _skip_as_root — rc 0 (and a note) when run as root, where every directory is writable.
_skip_as_root() { [[ "$(id -u)" -eq 0 ]] && { printf '    skipped: root writes every directory\n'; return 0; }; return 1; }

# When the audit-trail entry cannot be written (.claude/audits/ is not writable), apply_run refuses before fix()
# runs: exit 1, the refusal says so, and the target is untouched.
test_bin_unwritable_audit_trail_refuses_before_fix() {
  _skip_as_root && return 0
  local tmp="$_CSA_TMP/t22" rc=0
  _bin_fixture "$tmp" 'printf "ran\n" >> "$MARK"; printf "FIXED\n" > "$1"; return 0'
  chmod a-w "$tmp/project/.claude/audits"
  _bin_apply "$tmp"
  chmod u+w "$tmp/project/.claude/audits"
  assert_eq "1" "$_rc" "exit 1: $_out" || rc=1
  assert_contains "$_out" "could not write the audit-trail entry for FUID-test1234" "the refusal says why" || rc=1
  assert_eq "0" "$(_ran "$tmp")" "fix() did not run" || rc=1
  assert_eq "" "$(cat "$tmp/project/.gitignore")" "the target is untouched" || rc=1
  assert_eq "[]" "$(_trail "$tmp")" "nothing is logged" || rc=1
  return "$rc"
}

# A fix() that fails after .claude/audits/ stops being writable: exit 1, and the message says the entry could not be
# marked failed (it stays applied).
test_bin_failed_mark_that_cannot_be_written_is_reported() {
  _skip_as_root && return 0
  local tmp="$_CSA_TMP/t23" rc=0
  _bin_fixture "$tmp" 'chmod a-w "${1%/*}/.claude/audits"; return 1'
  _bin_apply "$tmp"
  chmod u+w "$tmp/project/.claude/audits"
  assert_eq "1" "$_rc" "exit 1: $_out" || rc=1
  assert_contains "$_out" "fix() failed for SA-X-001 (FUID-test1234), and its audit-trail entry could not be marked failed" \
    "the message names both failures" || rc=1
  assert_eq '["applied"]' "$(_trail "$tmp")" "the entry is still applied" || rc=1
  return "$rc"
}

# csa_apply_run gives its caller back the errexit setting it had. Called with `set -e`: errexit is still on after a
# fix() that succeeds, and a fix() that fails ends the caller at the call (nothing after it runs). Called without:
# errexit is still off after either.
test_apply_run_restores_the_callers_errexit() {
  local tmp="$_CSA_TMP/t24" body flag got want
  for body in 'return 0' 'return 1'; do
    for flag in -e +e; do
      rm -rf "$tmp"; _bin_fixture "$tmp" "$body"
      got="$(cd "$tmp/project" && CSA_RULES_DIR="$tmp/rules" bash -c '
        source "$1/helpers.sh"; source "$1/state.sh"; source "$1/apply-fix.sh"
        set '"$flag"'
        csa_apply_run "$2" FUID-test1234 >/dev/null 2>&1
        [[ $- == *e* ]] && echo on || echo off' _ "$CSA_LIB_DIR" "$tmp/project" 2>/dev/null)"
      case "$flag $body" in
        "-e return 0") want=on ;;
        "-e return 1") want="" ;;
        *) want=off ;;
      esac
      assert_eq "$want" "$got" "fix() '$body', caller set $flag" || return 1
    done
  done
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
csa_test_run test_forged_rule_path_is_never_sourced    || _csa_failed=$((_csa_failed + 1))
csa_test_run test_forged_rule_path_with_both_flags_and_fix_never_runs || _csa_failed=$((_csa_failed + 1))
csa_test_run test_rule_id_glob_or_prefix_is_refused     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_slug_named_two_segment_rule_resolves  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_duplicate_or_symlinked_rule_is_refused || _csa_failed=$((_csa_failed + 1))
csa_test_run test_absolute_target_under_a_glob_bearing_root_applies || _csa_failed=$((_csa_failed + 1))

csa_test_run test_bin_failing_fix_is_reported_and_marked_failed || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bin_fix_stops_at_its_first_failing_command || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bin_succeeding_fix_applies || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bin_applied_fixes_not_a_list_is_refused || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bin_unwritable_audit_trail_refuses_before_fix || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bin_failed_mark_that_cannot_be_written_is_reported || _csa_failed=$((_csa_failed + 1))
csa_test_run test_apply_run_restores_the_callers_errexit || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
