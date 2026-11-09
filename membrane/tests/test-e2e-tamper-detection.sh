#!/usr/bin/env bash
# tests/test-e2e-tamper-detection.sh — Adversarial: T1-F tamper detection.
# Tests TAMPER-001 (state.json mtime drift), TAMPER-002 (suppressions.json mtime drift),
# TAMPER-003 (git-tracked status drift).
# Phase 7 Task 7.2.

set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/state.sh"
source "$CSA_LIB_DIR/suppress.sh"

_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-tamper.XXXXXX")"
trap 'rm -rf "$_CSA_TMP"' EXIT

_csa_failed=0
_test_n=0

_next_scratch() {
  _test_n=$((_test_n + 1))
  mkdir -p "$_CSA_TMP/t$_test_n"
}

# ---------------------------------------------------------------------------
# test_tamper_001_state_json_mtime_drift
# T1-F: init state, update_self_integrity, manually touch state.json to change
# its mtime, call check_tamper, assert TAMPER-001 in output.
# ---------------------------------------------------------------------------
test_tamper_001_state_json_mtime_drift() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"

  csa_state_init "$project"
  csa_state_update_self_integrity "$project"

  # Wait a moment so touch produces a different mtime.
  sleep 1

  # Change state.json mtime to a timestamp in the past (not matching recorded mtime).
  local state_file; state_file="$(csa_state_path "$project")"
  touch -t 200001010000 "$state_file"

  local out; out="$(csa_state_check_tamper "$project" 2>/dev/null)"
  assert_contains "$out" "TAMPER-001" "should detect TAMPER-001 on state.json mtime drift" || return 1
}

# ---------------------------------------------------------------------------
# test_tamper_002_suppressions_json_mtime_drift
# T1-F: init state + suppressions, update_self_integrity, change suppressions.json mtime,
# call check_tamper, assert TAMPER-002 in output.
# ---------------------------------------------------------------------------
test_tamper_002_suppressions_json_mtime_drift() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"

  csa_state_init "$project"
  csa_suppress_init "$project"
  csa_state_update_self_integrity "$project"

  sleep 1

  # Change suppressions.json mtime.
  local sup_file; sup_file="$(csa_suppressions_path "$project")"
  touch -t 200001010000 "$sup_file"

  local out; out="$(csa_state_check_tamper "$project" 2>/dev/null)"
  assert_contains "$out" "TAMPER-002" "should detect TAMPER-002 on suppressions.json mtime drift" || return 1
}

# ---------------------------------------------------------------------------
# test_tamper_003_git_tracked_status_drift
# T1-F: record state as git-tracked=true in self_integrity, then change the recorded
# value so it disagrees with current git status → TAMPER-003.
# If git is unavailable, skip gracefully (DONE_WITH_CONCERNS noted in comments).
# ---------------------------------------------------------------------------
test_tamper_003_git_tracked_status_drift() {
  # Skip if git is unavailable.
  if ! command -v git >/dev/null 2>&1; then
    printf '    SKIP: git not available\n' >&2
    return 0
  fi

  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"

  csa_state_init "$project"
  csa_state_update_self_integrity "$project"

  # Determine the CURRENT actual tracked status of state.json.
  local state_file; state_file="$(csa_state_path "$project")"
  local actual_tracked=false
  if git -C "$project" ls-files --error-unmatch "$state_file" >/dev/null 2>&1; then
    actual_tracked=true
  fi

  # Flip the recorded tracked value to the OPPOSITE of reality.
  local flipped_tracked
  if [[ "$actual_tracked" == "true" ]]; then
    flipped_tracked=false
  else
    flipped_tracked=true
  fi

  local tmp; tmp="$scratch/state_tamper.json"
  jq --argjson v "$flipped_tracked" \
    '.self_integrity.git_tracked_check.state_json_tracked = $v' \
    "$state_file" > "$tmp" && mv "$tmp" "$state_file"

  local out; out="$(csa_state_check_tamper "$project" 2>/dev/null)"
  assert_contains "$out" "TAMPER-003" "should detect TAMPER-003 on git-tracked status drift" || return 1
}

# ---------------------------------------------------------------------------
# test_record_matches_an_untouched_state_json, through bin/csa
# state.json last written on 2020-01-01, then recorded and checked: the recorded mtime is the mtime of the file it is
# written into, so the check reports nothing; a later touch of the same file is still a TAMPER-001 (control).
# ---------------------------------------------------------------------------
test_record_matches_an_untouched_state_json() {
  _next_scratch; local project="$_CSA_TMP/t$_test_n/project" csa="$CSA_PLUGIN_ROOT/bin/csa"
  mkdir -p "$project/.claude/audits"
  local sf="$project/.claude/audits/state.json" out
  (cd "$project" && "$csa" state_init "$project") || return 1
  touch -t 202001010000 "$sf"
  (cd "$project" && GIT_CEILING_DIRECTORIES="$_CSA_TMP" "$csa" state_update_self_integrity "$project" </dev/null) || return 1
  assert_eq "$(csa_file_mtime "$sf")" "$(jq -r '.self_integrity.state_mtime_at_last_audit' "$sf")" "the record is state.json's own mtime" || return 1
  out="$(cd "$project" && GIT_CEILING_DIRECTORIES="$_CSA_TMP" "$csa" state_check_tamper "$project" </dev/null 2>&1)"
  assert_eq "" "$out" "an untouched state.json is no TAMPER-001" || return 1
  touch -t 202101010000 "$sf"
  out="$(cd "$project" && GIT_CEILING_DIRECTORIES="$_CSA_TMP" "$csa" state_check_tamper "$project" </dev/null 2>&1)"
  assert_contains "$out" "TAMPER-001" "a later touch is still a TAMPER-001" || return 1
}

# _one_second_back <file> : moves <file>'s mtime one second back, with POSIX `touch -t` (the stamp from GNU or BSD
# date), so a row can put a write one second before the next without sleeping.
_one_second_back() {
  local m s; m="$(csa_file_mtime "$1")" || return 1; m=$((m - 1))
  s="$(TZ=UTC0 date -d "@$m" +%Y%m%d%H%M.%S 2>/dev/null || TZ=UTC0 date -r "$m" +%Y%m%d%H%M.%S)" || return 1
  TZ=UTC0 touch -t "$s" "$1"
}

# ---------------------------------------------------------------------------
# test_record_a_second_after_the_audit, through bin/csa
# The audit's write (state_record_audit) lands one second before the record: the record still matches the file it is
# written into, so the check reports nothing.
# ---------------------------------------------------------------------------
test_record_a_second_after_the_audit() {
  _next_scratch; local project="$_CSA_TMP/t$_test_n/project" csa="$CSA_PLUGIN_ROOT/bin/csa"
  mkdir -p "$project/.claude/audits"
  local sf="$project/.claude/audits/state.json" out m
  mkdir -p "$_CSA_TMP/t$_test_n/home"
  (cd "$project" && "$csa" state_init "$project" \
     && HOME="$_CSA_TMP/t$_test_n/home" "$csa" state_record_audit "$project" 1 .claude/audits/run-1.md "" all >/dev/null) || return 1
  assert_eq 1 "$(jq '.audit_history | length' "$sf")" "the audit is recorded" || return 1
  m="$(csa_file_mtime "$sf")"; _one_second_back "$sf" || return 1
  assert_eq "$((m - 1))" "$(csa_file_mtime "$sf")" "the audit's write is one second back" || return 1
  (cd "$project" && GIT_CEILING_DIRECTORIES="$_CSA_TMP" "$csa" state_update_self_integrity "$project" </dev/null) || return 1
  assert_eq "$((m - 1))" "$(jq -r '.self_integrity.state_mtime_at_last_audit' "$sf")" "the record holds the audit's mtime" || return 1
  out="$(cd "$project" && GIT_CEILING_DIRECTORIES="$_CSA_TMP" "$csa" state_check_tamper "$project" </dev/null 2>&1)"
  assert_eq "" "$out" "the check reports nothing" || return 1
  assert_eq "$((m - 1))" "$(csa_file_mtime "$sf")" "state.json keeps that mtime" || return 1
}

# ---------------------------------------------------------------------------
# test_a_later_membrane_write_is_reported, through bin/csa
# Both files recorded, then a membrane write to suppressions.json after the record (suppress_init): the check reports
# TAMPER-002 for it, and no TAMPER-001, since state.json was not written after the record.
# ---------------------------------------------------------------------------
test_a_later_membrane_write_is_reported() {
  _next_scratch; local project="$_CSA_TMP/t$_test_n/project" csa="$CSA_PLUGIN_ROOT/bin/csa"
  mkdir -p "$project/.claude/audits"
  (cd "$project" && "$csa" state_init "$project" && "$csa" suppress_init "$project") || return 1
  touch -t 202001010000 "$project/.claude/audits/state.json" "$project/.claude/audits/suppressions.json"
  (cd "$project" && GIT_CEILING_DIRECTORIES="$_CSA_TMP" "$csa" state_update_self_integrity "$project" </dev/null) || return 1
  (cd "$project" && "$csa" suppress_init "$project") || return 1
  local out; out="$(cd "$project" && GIT_CEILING_DIRECTORIES="$_CSA_TMP" "$csa" state_check_tamper "$project" </dev/null 2>&1)"
  assert_contains "$out" "TAMPER-002" "a membrane write after the record is reported" || return 1
  [[ "$out" != *TAMPER-001* ]] || { printf '    TAMPER-001 for a state.json not written after the record: %s\n' "$out" >&2; return 1; }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

csa_test_run test_tamper_001_state_json_mtime_drift        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tamper_002_suppressions_json_mtime_drift  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tamper_003_git_tracked_status_drift      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_matches_an_untouched_state_json   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_a_second_after_the_audit          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_a_later_membrane_write_is_reported       || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
