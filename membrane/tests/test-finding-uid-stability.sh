#!/usr/bin/env bash
# tests/test-finding-uid-stability.sh — Adversarial: T2-I finding_uid stability.
# Whitespace edits must not change the uid; different content must.
# Phase 7 Task 7.2.

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

_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-uid-stab.XXXXXX")"

_csa_failed=0
_test_n=0

_next_scratch() {
  _test_n=$((_test_n + 1))
  mkdir -p "$_CSA_TMP/t$_test_n"
}

# ---------------------------------------------------------------------------
# test_uid_stable_across_whitespace_edit
# T2-I: write a settings.json with extra whitespace; audit → get fuid.
# Rewrite with trimmed whitespace; re-audit → same fuid.
# Uses permissions-issue (PERM-001) as the trigger.
# ---------------------------------------------------------------------------
test_uid_stable_across_whitespace_edit() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"
  csa_state_init "$project"

  # Write settings.json with padded whitespace in the allow value.
  printf '{"permissions":{"allow":[  "Bash(*)"  ],"deny":[]}}\n' > "$project/.claude/settings.json"

  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw1.jsonl" 2>/dev/null
  csa_baseline_tag "$scratch/raw1.jsonl" "$project" > "$scratch/tagged1.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged1.jsonl" "$project" > "$scratch/fil1.jsonl" 2>/dev/null

  local fuid1; fuid1="$(jq -r '.finding_uid' "$scratch/fil1.jsonl" | grep -v '^$' | head -1)"
  [[ -n "$fuid1" ]] || { printf '    no PERM finding with padded whitespace\n' >&2; return 1; }

  csa_state_record_audit "$project" 1 ".claude/audits/run-1.md" "$(cat "$scratch/fil1.jsonl")" >/dev/null 2>&1 || true

  # Rewrite with compact (no extra whitespace).
  printf '{"permissions":{"allow":["Bash(*)"],"deny":[]}}\n' > "$project/.claude/settings.json"

  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw2.jsonl" 2>/dev/null
  csa_baseline_tag "$scratch/raw2.jsonl" "$project" > "$scratch/tagged2.jsonl" 2>/dev/null
  csa_suppress_filter "$scratch/tagged2.jsonl" "$project" > "$scratch/fil2.jsonl" 2>/dev/null

  local fuid2; fuid2="$(jq -r '.finding_uid' "$scratch/fil2.jsonl" | grep -v '^$' | head -1)"
  [[ -n "$fuid2" ]] || { printf '    no PERM finding after whitespace-trim rewrite\n' >&2; return 1; }

  assert_eq "$fuid1" "$fuid2" "finding_uid must be stable across whitespace edit (T2-I)" || return 1
}

# ---------------------------------------------------------------------------
# test_uid_changes_for_different_content
# T2-I: two different secrets in CLAUDE.md get different finding_uids.
# ---------------------------------------------------------------------------
test_uid_changes_for_different_content() {
  _next_scratch; local scratch="$_CSA_TMP/t$_test_n"
  local project="$scratch/project"
  mkdir -p "$project/.claude/audits"
  export CSA_PROJECT_ROOT="$project"
  csa_state_init "$project"

  # First: a CLAUDE.md with one Anthropic key.
  printf '# Proj\nKey: sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' > "$project/CLAUDE.md"
  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw1.jsonl" 2>/dev/null
  local fuid1; fuid1="$(jq -r '.finding_uid' "$scratch/raw1.jsonl" | grep -v '^$' | head -1)"
  [[ -n "$fuid1" ]] || { printf '    no finding for first secret\n' >&2; return 1; }

  # Second: replace with a different OpenAI key (different content → different fuid).
  printf '# Proj\nKey: sk-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB\n' > "$project/CLAUDE.md"
  HOME=/nonexistent csa_rule_engine_scan_all "$project" "all" > "$scratch/raw2.jsonl" 2>/dev/null
  local fuid2; fuid2="$(jq -r '.finding_uid' "$scratch/raw2.jsonl" | grep -v '^$' | head -1)"
  [[ -n "$fuid2" ]] || { printf '    no finding for second secret\n' >&2; return 1; }

  [[ "$fuid1" != "$fuid2" ]] || {
    printf '    fuid should differ for different content, got same: %s\n' "$fuid1" >&2; return 1
  }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

csa_test_run test_uid_stable_across_whitespace_edit  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_uid_changes_for_different_content   || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
