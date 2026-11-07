#!/usr/bin/env bash
# tests/test-suppress-remove-stale.sh — csa suppress_remove and csa suppress_stale,
# run through the bin/csa dispatcher (which sets -euo pipefail, as the skill does).
set -u
source "$(dirname "$0")/_helpers.sh"
CSA="$CSA_PLUGIN_ROOT/bin/csa"

_csa_failed=0
_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-sup-rm.XXXXXX")"
trap 'rm -rf "$_CSA_TMP"' EXIT
_n=0

# _mk_root: sets $root to a fresh project dir with .claude/audits/.
_mk_root() { _n=$((_n + 1)); root="$_CSA_TMP/t$_n"; mkdir -p "$root/.claude/audits"; }

# _write_sup <root> <uid>... : a suppressions.json with one entry per uid, distinct notes.
_write_sup() {
  local r="$1"; shift
  local u arr='[]'
  for u in "$@"; do
    arr="$(jq -c --arg u "$u" '. + [{finding_uid:$u,suppressed_by:"tester",suppressed_at:"2026-01-01T00:00:00Z",note:("note for " + $u)}]' <<<"$arr")"
  done
  jq -n --argjson a "$arr" '{schema_version:1,suppressions:$a}' > "$r/.claude/audits/suppressions.json"
}

_scan() { # <project> <focus> > raw jsonl
  HOME=/nonexistent CSA_PROJECT_ROOT="$1" "$CSA" rule_engine_scan_all "$1" "$2" 2>/dev/null
}

# ---- remove ----------------------------------------------------------------

test_remove_keeps_other_entries_byte_for_byte() {
  _mk_root
  _write_sup "$root" FUID-aaaaaaaa FUID-bbbbbbbb FUID-cccccccc
  local before_a before_c
  before_a="$(jq -c '.suppressions[0]' "$root/.claude/audits/suppressions.json")"
  before_c="$(jq -c '.suppressions[2]' "$root/.claude/audits/suppressions.json")"
  "$CSA" suppress_remove "$root" FUID-bbbbbbbb || { printf '    remove failed\n' >&2; return 1; }
  assert_eq "2" "$(jq '.suppressions | length' "$root/.claude/audits/suppressions.json")" "two entries remain" || return 1
  assert_eq "$before_a" "$(jq -c '.suppressions[0]' "$root/.claude/audits/suppressions.json")" "first entry untouched" || return 1
  assert_eq "$before_c" "$(jq -c '.suppressions[1]' "$root/.claude/audits/suppressions.json")" "last entry untouched" || return 1
  assert_eq "1" "$(jq '.schema_version' "$root/.claude/audits/suppressions.json")" "schema_version kept" || return 1
  # Adjacent control: the removed uid is the only one gone.
  assert_eq "0" "$(jq '[.suppressions[] | select(.finding_uid == "FUID-bbbbbbbb")] | length' "$root/.claude/audits/suppressions.json")" "removed uid is gone" || return 1
}

test_remove_absent_uid_rc1_file_untouched() {
  _mk_root
  _write_sup "$root" FUID-aaaaaaaa
  local f="$root/.claude/audits/suppressions.json"
  touch -t 202001010000 "$f"
  local m1; m1="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")"
  local sum1; sum1="$(cksum < "$f")"
  local rc=0; "$CSA" suppress_remove "$root" FUID-zzzzzzzz 2>/dev/null || rc=$?
  assert_eq "1" "$rc" "absent uid is rc 1" || return 1
  assert_eq "$m1" "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")" "mtime unchanged" || return 1
  assert_eq "$sum1" "$(cksum < "$f")" "content unchanged" || return 1
}

test_remove_malformed_file_rc2() {
  _mk_root
  printf '{ not json' > "$root/.claude/audits/suppressions.json"
  local rc=0 err; err="$("$CSA" suppress_remove "$root" FUID-aaaaaaaa 2>&1)" || rc=$?
  assert_eq "2" "$rc" "malformed file is rc 2" || return 1
  assert_contains "$err" "not a valid suppressions file" "message names why" || return 1
  assert_eq "{ not json" "$(cat "$root/.claude/audits/suppressions.json")" "malformed file left as it was" || return 1
}

test_remove_no_file_rc1_creates_nothing() {
  _mk_root
  local rc=0; "$CSA" suppress_remove "$root" FUID-aaaaaaaa 2>/dev/null || rc=$?
  assert_eq "1" "$rc" "no file is rc 1" || return 1
  [[ ! -e "$root/.claude/audits/suppressions.json" ]] || { printf '    remove created a file\n' >&2; return 1; }
}

# ---- stale -----------------------------------------------------------------

# _record_run <root> <findings-file> : records the findings as audit run 1 through the dispatcher,
# as step 9 does, then backdates every first_seen past the 60 s suppression window.
_record_run() {
  local r="$1" f="$_CSA_TMP/state-tmp$_n.json" st="$1/.claude/audits/state.json"
  [[ -f "$st" ]] || HOME=/nonexistent CSA_PROJECT_ROOT="$r" "$CSA" state_init "$r" >/dev/null
  HOME=/nonexistent CSA_PROJECT_ROOT="$r" "$CSA" state_record_audit "$r" 1 ".claude/audits/r.md" "$2" all >/dev/null \
    || { printf '    state_record_audit failed\n' >&2; return 1; }
  jq '.findings |= map_values(.first_seen = "2026-01-01T00:00:00Z")' "$st" > "$f" && mv "$f" "$st"
}

# Copies permissions-issue into $root and sets $live to one uid its full scan reports.
_perm_project() {
  _mk_root
  cp -R "$CSA_FIXTURES_DIR/issues/permissions-issue/." "$root/"
  mkdir -p "$root/.claude/audits"
  _scan "$root" all > "$_CSA_TMP/raw$_n.jsonl"
  live="$(jq -r 'select(.finding_uid != null) | .finding_uid' "$_CSA_TMP/raw$_n.jsonl" | head -1)"
  [[ -n "$live" ]] || { printf '    fixture scan has no finding\n' >&2; return 1; }
}

test_stale_lists_only_the_uid_the_scan_lacks() {
  local root live; _perm_project || return 1
  _write_sup "$root" "$live" FUID-deadbeef
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/raw$_n.jsonl" "$root" all)" || { printf '    stale failed\n' >&2; return 1; }
  assert_eq "FUID-deadbeef" "$(jq -r '.finding_uid' <<<"$out")" "the bogus uid is listed" || return 1
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c .)" "one line" || return 1
  # Control: the live suppression is not listed.
  [[ "$out" != *"$live"* ]] || { printf '    live uid %s listed as stale\n' "$live" >&2; return 1; }
}

test_stale_focused_scan_refuses() {
  local root live; _perm_project || return 1
  _write_sup "$root" "$live" FUID-deadbeef
  local rc=0 out
  out="$("$CSA" suppress_stale "$_CSA_TMP/raw$_n.jsonl" "$root" secrets 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || { printf '    focused scan did not refuse\n' >&2; return 1; }
  assert_contains "$out" "full scan" "message names why" || return 1
  [[ "$out" != *"FUID-deadbeef"* ]] || { printf '    refusal still listed uids\n' >&2; return 1; }
}

test_stale_scanner_finding_refuses() {
  local root live; _perm_project || return 1
  _write_sup "$root" "$live" FUID-deadbeef
  cp "$_CSA_TMP/raw$_n.jsonl" "$_CSA_TMP/partial$_n.jsonl"
  printf '%s\n' '{"rule_id":"SCANNER-003","severity":"medium","file":"x"}' >> "$_CSA_TMP/partial$_n.jsonl"
  local rc=0 out
  out="$("$CSA" suppress_stale "$_CSA_TMP/partial$_n.jsonl" "$root" all 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || { printf '    partial scan did not refuse\n' >&2; return 1; }
  assert_contains "$out" "SCANNER" "message names why" || return 1
  [[ "$out" != *"FUID-deadbeef"* ]] || { printf '    refusal still listed uids\n' >&2; return 1; }
}

test_stale_clean_scan_lists_all() {
  _mk_root
  cp -R "$CSA_FIXTURES_DIR/clean/empty-project/." "$root/"
  mkdir -p "$root/.claude/audits"
  _scan "$root" all > "$_CSA_TMP/raw$_n.jsonl"
  assert_eq "0" "$(jq -s '[.[] | select(.finding_uid != null)] | length' "$_CSA_TMP/raw$_n.jsonl")" "fixture scan is clean" || return 1
  _write_sup "$root" FUID-aaaaaaaa FUID-bbbbbbbb
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/raw$_n.jsonl" "$root" all)" || return 1
  assert_eq "2" "$(printf '%s\n' "$out" | grep -c .)" "both listed" || return 1
}

test_stale_no_file_lists_nothing() {
  _mk_root
  : > "$_CSA_TMP/empty$_n.jsonl"
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/empty$_n.jsonl" "$root" all)" || { printf '    stale failed with no file\n' >&2; return 1; }
  assert_eq "" "$out" "nothing listed" || return 1
  [[ ! -e "$root/.claude/audits/suppressions.json" ]] || { printf '    stale created a file\n' >&2; return 1; }
}

test_stale_excludes_tamper_uids() {
  _mk_root
  : > "$_CSA_TMP/empty$_n.jsonl"
  _write_sup "$root" FUID-tamper01 FUID-tamper02 FUID-tamper03 FUID-bbbbbbbb
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/empty$_n.jsonl" "$root" all)" || return 1
  assert_eq "FUID-bbbbbbbb" "$(jq -r '.finding_uid' <<<"$out")" "only the non-tamper uid is listed" || return 1
}

# A suppression whose uid moves (the finding's file is renamed, so its path and uid change)
# is stale, and the same finding under its new uid reads NEW.
test_e2e_uid_move_old_stale_new_is_new() {
  local root live; _perm_project || return 1
  local old; old="$(jq -r 'select(.rule_id == "PERM-001") | .finding_uid' "$_CSA_TMP/raw$_n.jsonl")"
  [[ -n "$old" ]] || { printf '    no PERM-001 in fixture\n' >&2; return 1; }
  _record_run "$root" "$_CSA_TMP/raw$_n.jsonl" || return 1
  "$CSA" suppress_add "$root" "$old" "e2e" || { printf '    suppress_add failed\n' >&2; return 1; }
  mv "$root/.claude/settings.json" "$root/.claude/settings.local.json"
  _scan "$root" all > "$_CSA_TMP/rescan$_n.jsonl"
  local new; new="$(jq -r 'select(.rule_id == "PERM-001") | .finding_uid' "$_CSA_TMP/rescan$_n.jsonl")"
  [[ -n "$new" && "$new" != "$old" ]] || { printf '    rename did not move the uid; setup is vacuous\n' >&2; return 1; }
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/rescan$_n.jsonl" "$root" all)" || return 1
  assert_eq "$old" "$(jq -r '.finding_uid' <<<"$out")" "old uid is stale" || return 1
  # The moved finding is no longer hidden: the rescan still emits the new uid through the filter.
  "$CSA" suppress_filter "$_CSA_TMP/rescan$_n.jsonl" "$root" > "$_CSA_TMP/filtered$_n.jsonl" || return 1
  assert_eq "1" "$(jq -r --arg u "$new" 'select(.finding_uid == $u) | .finding_uid' "$_CSA_TMP/filtered$_n.jsonl" | grep -c .)" "new uid passes the filter" || return 1
  # Control: before the move the same suppression does hide the old uid.
  "$CSA" suppress_filter "$_CSA_TMP/raw$_n.jsonl" "$root" > "$_CSA_TMP/filtered-old$_n.jsonl" || return 1
  assert_eq "0" "$(jq -r --arg u "$old" 'select(.finding_uid == $u) | .finding_uid' "$_CSA_TMP/filtered-old$_n.jsonl" | grep -c . || true)" "old uid is hidden by its suppression" || return 1
}

# Every `csa <fn> ...` call SKILL.md documents, bare ones included, runs through the dispatcher
# with its placeholders filled, and does not abort on arity. The `csa <fn-suffix>` contract
# mention and `csa --list` name no function and are not matched.
test_documented_csa_calls_run_through_dispatcher() {
  _mk_root
  local skill="$CSA_PLUGIN_ROOT/skills/auditing-claude-configs/SKILL.md" calls call ran=0
  : > "$_CSA_TMP/empty$_n.jsonl"
  calls="$(grep -oE '`csa [a-z_]+( [^`]*)?`' "$skill" | tr -d '`')"
  [[ -n "$calls" ]] || { printf '    SKILL.md documents no csa call with arguments\n' >&2; return 1; }
  while IFS= read -r call; do
    call="${call//\"\$PWD\"/\"$root\"}"
    call="${call//\"\$focus\"/all}"
    call="${call//\"<finding-id>\"/FUID-aaaaaaaa}"
    call="${call//\"<FUID>\"/FUID-aaaaaaaa}"
    call="${call//\"<id>\"/FUID-aaaaaaaa}"
    call="${call//\"<note>\"/note}"
    call="${call//<run-index>/1}"
    call="${call//<report-path>/$root/.claude/audits/r.md}"
    call="${call//<metadata-json>/\{\}}"
    call="${call//<findings>/$_CSA_TMP/empty$_n.jsonl}"
    call="${call//<tagged>/$_CSA_TMP/empty$_n.jsonl}"
    call="${call//<raw-file>/$_CSA_TMP/empty$_n.jsonl}"
    [[ "$call" != *"<"* ]] || { printf '    unfilled placeholder in: %s\n' "$call" >&2; return 1; }
    local out rc=0
    out="$(cd "$root" && HOME=/nonexistent CSA_PROJECT_ROOT="$root" eval "\"$CSA\" ${call#csa }" 2>&1)" || rc=$?
    # A call that records a run must succeed and write it: the file argument it documents is read.
    if [[ "$call" == "csa state_record_audit "* ]]; then
      [[ "$rc" -eq 0 ]] || { printf '    documented call exits %s: %s -> %s\n' "$rc" "$call" "$out" >&2; return 1; }
      assert_eq "1" "$(jq '.audit_history | length' "$root/.claude/audits/state.json")" "documented state_record_audit wrote its run" || return 1
    fi
    [[ "$out" != *"unbound variable"* && "$out" != *"Unknown function"* && "$out" != *"Usage:"* ]] \
      || { printf '    documented call aborts: %s -> %s\n' "$call" "$out" >&2; return 1; }
    ran=$((ran + 1))
  done <<<"$calls"
  [[ "$ran" -ge 12 ]] || { printf '    only %s documented calls ran\n' "$ran" >&2; return 1; }
}

# ---- exit codes and exact matching -----------------------------------------

test_remove_empty_file_rc2() {
  _mk_root
  : > "$root/.claude/audits/suppressions.json"
  local rc=0; "$CSA" suppress_remove "$root" FUID-aaaaaaaa 2>/dev/null || rc=$?
  assert_eq "2" "$rc" "0-byte file is rc 2" || return 1
}

test_remove_object_without_suppressions_array_rc2() {
  _mk_root
  printf '{}' > "$root/.claude/audits/suppressions.json"
  local rc=0; "$CSA" suppress_remove "$root" FUID-aaaaaaaa 2>/dev/null || rc=$?
  assert_eq "2" "$rc" "{} is rc 2" || return 1
  assert_eq "{}" "$(cat "$root/.claude/audits/suppressions.json")" "file left as it was" || return 1
}

test_remove_matches_the_uid_exactly() {
  _mk_root
  _write_sup "$root" FUID-ab12 FUID-ab123 FUID-xab12
  "$CSA" suppress_remove "$root" FUID-ab12 || return 1
  assert_eq "FUID-ab123 FUID-xab12" "$(jq -r '[.suppressions[].finding_uid] | join(" ")' "$root/.claude/audits/suppressions.json")" "only the exact uid is gone" || return 1
}

test_stale_matches_the_uid_exactly() {
  _mk_root
  printf '%s\n' '{"rule_id":"PERM-001","finding_uid":"FUID-ab123"}' > "$_CSA_TMP/raw$_n.jsonl"
  _write_sup "$root" FUID-ab12 FUID-ab123
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/raw$_n.jsonl" "$root" all)" || return 1
  assert_eq "FUID-ab12" "$(jq -r '.finding_uid' <<<"$out")" "a longer live uid does not hide a shorter one" || return 1
}

test_stale_malformed_suppressions_rc2() {
  _mk_root
  : > "$_CSA_TMP/empty$_n.jsonl"
  local f="$root/.claude/audits/suppressions.json" rc out
  for body in '{}' '{"suppressions":[{"note":"no uid"}]}' '{ not json'; do
    printf '%s' "$body" > "$f"; rc=0
    out="$("$CSA" suppress_stale "$_CSA_TMP/empty$_n.jsonl" "$root" all 2>&1)" || rc=$?
    assert_eq "2" "$rc" "malformed suppressions ($body) is rc 2" || return 1
    assert_contains "$out" "not a valid suppressions file" "message names why ($body)" || return 1
  done
}

test_stale_missing_findings_file_rc4() {
  _mk_root
  _write_sup "$root" FUID-aaaaaaaa
  local rc=0 out; out="$("$CSA" suppress_stale "$_CSA_TMP/does-not-exist.jsonl" "$root" all 2>&1)" || rc=$?
  assert_eq "4" "$rc" "missing findings file is rc 4, not the focus refusal's 2" || return 1
  assert_contains "$out" "not findings JSONL" "message names why" || return 1
  printf 'csa: warning: some stderr text\n' > "$_CSA_TMP/notjsonl$_n.txt"
  rc=0; "$CSA" suppress_stale "$_CSA_TMP/notjsonl$_n.txt" "$root" all >/dev/null 2>&1 || rc=$?
  assert_eq "4" "$rc" "stderr text piped in as the findings file is rc 4" || return 1
}

test_stale_provenance_finding_refuses() {
  _mk_root
  _write_sup "$root" FUID-aaaaaaaa
  printf '%s\n' '{"rule_id":"PROVENANCE-002","severity":"high","file":"@plugin:x@y","finding_uid":"FUID-11111111"}' > "$_CSA_TMP/prov$_n.jsonl"
  local rc=0 out; out="$("$CSA" suppress_stale "$_CSA_TMP/prov$_n.jsonl" "$root" all 2>&1)" || rc=$?
  assert_eq "3" "$rc" "a PROVENANCE-002 scan is rc 3" || return 1
  assert_contains "$out" "PROVENANCE-002" "message names why" || return 1
  [[ "$out" != *"FUID-aaaaaaaa"* ]] || { printf '    refusal still listed uids\n' >&2; return 1; }
}

test_remove_write_failure_rc5() {
  _mk_root
  _write_sup "$root" FUID-aaaaaaaa FUID-bbbbbbbb
  local f="$root/.claude/audits/suppressions.json" before; before="$(cksum < "$f")"
  chmod a-w "$root/.claude/audits"
  # Not a failure of the code: a process that ignores directory modes (root) cannot reach this branch.
  if touch "$root/.claude/audits/.probe" 2>/dev/null; then
    rm -f "$root/.claude/audits/.probe"; chmod u+w "$root/.claude/audits"
    printf '    SKIP: directory modes are not enforced for this user (running as root?)\n'
    return 0
  fi
  local rc=0 err; err="$("$CSA" suppress_remove "$root" FUID-aaaaaaaa 2>&1)" || rc=$?
  chmod u+w "$root/.claude/audits"
  assert_eq "5" "$rc" "write failure is rc 5" || return 1
  assert_contains "$err" "could not write" "message names the write failure" || return 1
  assert_eq "1" "$(printf '%s\n' "$err" | grep -c .)" "the csa line is the only stderr line" || return 1
  assert_eq "$before" "$(cksum < "$f")" "file left as it was" || return 1
}

test_stale_emits_only_the_uid() {
  _mk_root
  : > "$_CSA_TMP/empty$_n.jsonl"
  _write_sup "$root" FUID-aaaaaaaa
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/empty$_n.jsonl" "$root" all)" || return 1
  assert_eq '{"finding_uid":"FUID-aaaaaaaa"}' "$out" "one object with the uid and nothing else" || return 1
}

test_stale_tamper_exclusion_is_exact() {
  _mk_root
  : > "$_CSA_TMP/empty$_n.jsonl"
  _write_sup "$root" "FUID-tamper01" $'FUID-tamper01\n' "FUID-tamper04"
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/empty$_n.jsonl" "$root" all)" || return 1
  assert_eq "2" "$(printf '%s\n' "$out" | grep -c .)" "two listed" || return 1
  # Control: the tamper uid itself is not listed; the one with a trailing newline is.
  [[ "$(jq -c '.finding_uid' <<<"$out" | paste -sd' ' -)" == '"FUID-tamper01\n" "FUID-tamper04"' ]] \
    || { printf '    wrong listing: %s\n' "$out" >&2; return 1; }
}

csa_test_run test_remove_keeps_other_entries_byte_for_byte  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_absent_uid_rc1_file_untouched      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_malformed_file_rc2                 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_no_file_rc1_creates_nothing        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_lists_only_the_uid_the_scan_lacks   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_focused_scan_refuses                || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_scanner_finding_refuses             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_clean_scan_lists_all                || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_no_file_lists_nothing               || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_excludes_tamper_uids                || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_uid_move_old_stale_new_is_new         || _csa_failed=$((_csa_failed + 1))
csa_test_run test_documented_csa_calls_run_through_dispatcher || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_empty_file_rc2                     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_object_without_suppressions_array_rc2 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_matches_the_uid_exactly            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_matches_the_uid_exactly             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_malformed_suppressions_rc2          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_missing_findings_file_rc4           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_provenance_finding_refuses          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_write_failure_rc5                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_emits_only_the_uid                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_tamper_exclusion_is_exact           || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
