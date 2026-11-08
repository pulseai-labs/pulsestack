#!/usr/bin/env bash
# tests/test-registry-reader.sh — every reader of state.json's `findings` registry, through the
# bin/csa dispatcher (set -euo pipefail, as the skill runs): an entry that is not an object, a
# registry that is not an object, malformed fields, and the display-id lookup.
set -u
source "$(dirname "$0")/_helpers.sh"
CSA="$CSA_PLUGIN_ROOT/bin/csa"

_csa_failed=0
_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-reg.XXXXXX")"
trap 'rm -rf "$_CSA_TMP"' EXIT
_n=0

_mk_root() { _n=$((_n + 1)); root="$_CSA_TMP/t$_n"; mkdir -p "$root/.claude/audits"; st="$root/.claude/audits/state.json"; }
_c() { ( cd "$root" && HOME=/nonexistent CSA_PROJECT_ROOT="$root" "$CSA" "$@" ); }

# A healthy entry, last seen at run 1, first seen long ago.
_good='{"rule_id":"PERM-002","severity":"high","file":".claude/settings.json","first_seen":"2026-01-01T00:00:00Z","last_seen":"2026-01-01T00:00:00Z","seen_in_runs":1,"last_run_index":1,"last_display_id":"SA-2026-01-01-01-001","suppressed":false}'

# _state <registry-json> [<runs>] : a state.json with that registry and <runs> full runs (default 1) in its history.
_state() {
  jq -n --argjson r "$1" --argjson h "${2:-1}" '{schema_version:2,last_audit:null,
    self_integrity:{state_mtime_at_last_audit:0,suppressions_mtime_at_last_audit:0},
    findings:$r, audit_history:[range(1; $h + 1) | {run_index:., focus:"all"}], applied_fixes:[]}' > "$st"
}

# _line <uid> <display_id> : one High finding line.
_line() {
  printf '{"rule_id":"PERM-002","severity":"high","file":".claude/settings.json","line":1,"offset":0,"preview":"p","finding_uid":"%s","display_id":"%s"}\n' "$1" "$2"
}

# _no_tmp : no state.json.tmp.<pid> is left in the audits directory.
_no_tmp() {
  local left; left="$(cd "$root/.claude/audits" && ls -a | grep '^state\.json\.tmp\.' || true)"
  assert_eq "" "$left" "no state.json.tmp file left ($1)"
}

_keys() { jq -c '.findings | keys' "$st"; }

# ---- an entry that is not an object ----------------------------------------------------------

test_non_object_entry_is_skipped_by_readers_and_dropped_by_writers() {
  local bad rc out
  for bad in '"x"' 5 '[]' null false true; do
    _mk_root
    # Run 13 records a new finding: the bad entry is dropped, the healthy one (unseen for 12 runs) ages out.
    _state "{\"FUID-bad00001\":$bad,\"FUID-good0001\":$_good}" 12
    _line FUID-ccccccc1 SA-2026-01-02-01-001 > "$root/f1"
    rc=0; _c state_record_audit "$root" 13 "$root/.claude/audits/2026-01-02-01.md" "$root/f1" all >/dev/null 2>&1 || rc=$?
    assert_eq 0 "$rc" "record_audit beside $bad" || return 1
    assert_eq '["FUID-ccccccc1"]' "$(_keys)" "GC ran: $bad dropped, the aged entry evicted, the new one kept" || return 1
    assert_eq 13 "$(jq '.audit_history | last | .run_index' "$st")" "the run is recorded beside $bad" || return 1
    _no_tmp "record_audit beside $bad" || return 1

    # GC on its own drops the bad entry and keeps the healthy one, still within its window.
    _state "{\"FUID-bad00001\":$bad,\"FUID-good0001\":$_good}"
    rc=0; _c state_gc_findings "$root" 2 >/dev/null 2>&1 || rc=$?
    assert_eq 0 "$rc" "standalone GC beside $bad" || return 1
    assert_eq '["FUID-good0001"]' "$(_keys)" "standalone GC drops $bad, keeps the healthy entry" || return 1
    _no_tmp "GC beside $bad" || return 1

    # A sighting of the bad uid re-creates it as a new entry.
    _state "{\"FUID-bad00001\":$bad,\"FUID-good0001\":$_good}"
    _line FUID-bad00001 SA-2026-01-02-01-001 > "$root/f2"
    rc=0; _c state_record_audit "$root" 2 "$root/.claude/audits/2026-01-02-01.md" "$root/f2" all >/dev/null 2>&1 || rc=$?
    assert_eq 0 "$rc" "re-sighting the uid of $bad" || return 1
    assert_eq '1 SA-2026-01-02-01-001' "$(jq -r '.findings["FUID-bad00001"] | "\(.seen_in_runs) \(.last_display_id)"' "$st")" "re-created as a new entry ($bad)" || return 1
    [[ "$(jq -r '.findings["FUID-bad00001"].first_seen' "$st")" != 2026-01-01* ]] || { printf '    first_seen kept over %s\n' "$bad" >&2; return 1; }

    _state "{\"FUID-bad00001\":$bad,\"FUID-good0001\":$_good}"
    rc=0; out="$(_c baseline_tag "$root/f2" "$root" 2>/dev/null)" || rc=$?
    assert_eq 0 "$rc" "baseline_tag on the uid of $bad" || return 1
    assert_eq NEW "$(jq -r .state <<<"$out")" "baseline_tag: $bad reads NEW" || return 1
    _line FUID-good0001 SA-2026-01-02-01-002 > "$root/f3"
    assert_eq PERSISTED "$(_c baseline_tag "$root/f3" "$root" | jq -r .state)" "control: the healthy entry beside $bad is PERSISTED" || return 1

    rc=0; out="$(_c apply_resolve_id "$root" SA-2026-01-01-01-001 2>/dev/null)" || rc=$?
    assert_eq "0 FUID-good0001" "$rc $out" "apply_resolve_id gets past $bad" || return 1
    rc=0; out="$(_c apply_run "$root" FUID-bad00001 2>&1)" || rc=$?
    assert_eq 1 "$rc" "apply_run on the uid of $bad" || return 1
    assert_contains "$out" "Finding not found in state: FUID-bad00001" "apply_run reads $bad as not found" || return 1

    # suppress_add keeps its own reading: an entry it cannot read is exit 1, an absent one exit 3.
    rc=0; _c suppress_add "$root" FUID-bad00001 n >/dev/null 2>&1 || rc=$?
    case "$bad" in
      null|false) assert_eq 3 "$rc" "suppress_add on $bad" || return 1 ;;
      *)          assert_eq 1 "$rc" "suppress_add on $bad" || return 1 ;;
    esac
  done
  # Control: a healthy registry still ages its entries, so GC was not switched off.
  _mk_root; _state "{\"FUID-good0001\":$_good}" 12
  _line FUID-ccccccc1 SA-1 > "$root/f1"
  _c state_record_audit "$root" 13 "$root/.claude/audits/2026-01-02-01.md" "$root/f1" all >/dev/null 2>&1 || return 1
  assert_eq '["FUID-ccccccc1"]' "$(_keys)" "control: the aged entry is evicted" || return 1
}

# ---- a registry that is not an object --------------------------------------------------------

test_registry_that_is_not_an_object_reads_as_empty() {
  local v rc out
  for v in '"x"' 5 '[]'; do
    _mk_root; _state "$v"
    _line FUID-ddddddd1 SA-2026-01-02-01-001 > "$root/f1"
    rc=0; _c state_gc_findings "$root" 2 >/dev/null 2>&1 || rc=$?
    assert_eq 0 "$rc" "GC on findings=$v" || return 1
    _no_tmp "GC on findings=$v" || return 1
    _state "$v"
    rc=0; out="$(_c baseline_tag "$root/f1" "$root" 2>/dev/null)" || rc=$?
    assert_eq "0 NEW" "$rc $(jq -r .state <<<"$out")" "baseline_tag on findings=$v" || return 1
    rc=0; _c apply_resolve_id "$root" SA-2026-01-01-01-001 >/dev/null 2>&1 || rc=$?
    assert_eq 1 "$rc" "apply_resolve_id on findings=$v is not found" || return 1
    rc=0; _c apply_run "$root" FUID-ddddddd1 >/dev/null 2>&1 || rc=$?
    assert_eq 1 "$rc" "apply_run on findings=$v is not found" || return 1
    rc=0; _c suppress_add "$root" FUID-ddddddd1 n >/dev/null 2>&1 || rc=$?
    assert_eq 2 "$rc" "suppress_add on findings=$v keeps exit 2" || return 1
    rc=0; _c state_record_audit "$root" 2 "$root/.claude/audits/2026-01-02-01.md" "$root/f1" all >/dev/null 2>&1 || rc=$?
    assert_eq 0 "$rc" "record_audit on findings=$v" || return 1
    assert_eq '["FUID-ddddddd1"]' "$(_keys)" "the registry restarts from this run ($v)" || return 1
    _no_tmp "record_audit on findings=$v" || return 1
  done
}

# ---- malformed fields ------------------------------------------------------------------------

test_gc_and_resighting_read_malformed_fields() {
  local rc v
  # GC: an entry whose last_run_index is not a number cannot be aged, so it is evicted.
  for v in 'del(.last_run_index)' '.last_run_index = "1"' '.last_run_index = null'; do
    _mk_root; _state "{\"FUID-nolri001\":$(jq -c "$v" <<<"$_good"),\"FUID-good0001\":$_good}"
    rc=0; _c state_gc_findings "$root" 2 >/dev/null 2>&1 || rc=$?
    assert_eq 0 "$rc" "GC on an entry with $v" || return 1
    assert_eq '["FUID-good0001"]' "$(_keys)" "the entry with $v is evicted, the healthy one kept" || return 1
    _no_tmp "GC on $v" || return 1
  done
  # GC: a rule_id that is not a string is read as no rule, so the entry ages on every run.
  _mk_root; _state "{\"FUID-rid00001\":$(jq -c '.rule_id = 5' <<<"$_good"),\"FUID-good0001\":$_good}"
  rc=0; _c state_gc_findings "$root" 2 >/dev/null 2>&1 || rc=$?
  assert_eq 0 "$rc" "GC on a number rule_id" || return 1
  assert_eq '["FUID-good0001","FUID-rid00001"]' "$(_keys)" "both live entries kept" || return 1
  _state "{\"FUID-rid00001\":$(jq -c '.rule_id = {"a":1}' <<<"$_good")}" 12
  rc=0; _c state_gc_findings "$root" 12 >/dev/null 2>&1 || rc=$?
  assert_eq "0 []" "$rc $(_keys)" "an object rule_id unseen for 11 runs ages out" || return 1
  # Re-sighting: a seen_in_runs that is not a number counts from 0.
  _mk_root; _state "{\"FUID-good0001\":$(jq -c '.seen_in_runs = "x"' <<<"$_good")}"
  _line FUID-good0001 SA-1 > "$root/f1"
  rc=0; _c state_record_audit "$root" 2 "$root/r.md" "$root/f1" all >/dev/null 2>&1 || rc=$?
  assert_eq 0 "$rc" "re-sighting an entry with a string seen_in_runs" || return 1
  assert_eq 1 "$(jq '.findings["FUID-good0001"].seen_in_runs' "$st")" "a string seen_in_runs counts from 0" || return 1
  assert_eq "2026-01-01T00:00:00Z" "$(jq -r '.findings["FUID-good0001"].first_seen' "$st")" "the entry keeps its first_seen" || return 1
  # Control: a numeric seen_in_runs still adds one.
  _state "{\"FUID-good0001\":$(jq -c '.seen_in_runs = 4' <<<"$_good")}"
  _c state_record_audit "$root" 2 "$root/r.md" "$root/f1" all >/dev/null 2>&1 || return 1
  assert_eq 5 "$(jq '.findings["FUID-good0001"].seen_in_runs' "$st")" "control: 4 becomes 5" || return 1
}

# A GC that cannot read the state leaves no tmp file behind, and the state as it was.
test_failed_gc_leaves_no_tmp_file() {
  _mk_root; _state "{\"FUID-good0001\":$_good}"
  jq '.audit_history = "x"' "$st" > "$st.w" && mv "$st.w" "$st"
  local before; before="$(cat "$st")"
  local rc=0; _c state_gc_findings "$root" 2 >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] || { printf '    GC on an unreadable history exits 0\n' >&2; return 1; }
  _no_tmp "failed GC" || return 1
  assert_eq "$before" "$(cat "$st")" "state.json unchanged" || return 1
}

# ---- the display-id lookup -------------------------------------------------------------------

# A display id names a line of the latest recorded run's report: it resolves only to an entry whose
# last_run_index is the newest audit_history run. An id an older run's entry still holds matches
# nothing, in both key orders, so the answer cannot come from the order the entries are stored in.
test_display_id_resolves_only_in_the_latest_run() {
  local older newer order rc out
  older="$(jq -c '.last_run_index = 1' <<<"$_good")"; newer="$(jq -c '.last_run_index = 3' <<<"$_good")"
  for order in old-first new-first; do
    _mk_root
    if [[ "$order" == old-first ]]; then _state "{\"FUID-a0000old\":$older,\"FUID-b0000new\":$newer}" 3
    else _state "{\"FUID-b0000new\":$newer,\"FUID-a0000old\":$older}" 3; fi
    assert_eq FUID-b0000new "$(_c apply_resolve_id "$root" SA-2026-01-01-01-001)" "the latest run's entry, $order" || return 1
    _state "{\"FUID-a0000old\":$older}" 3
    rc=0; out="$(_c apply_resolve_id "$root" SA-2026-01-01-01-001 2>/dev/null)" || rc=$?
    assert_eq "1 " "$rc $out" "an id only an older run's entry holds, apply_resolve_id, $order" || return 1
    rc=0; _c suppress_add "$root" SA-2026-01-01-01-001 n >/dev/null 2>&1 || rc=$?
    assert_eq 3 "$rc" "an id only an older run's entry holds, suppress_add, $order" || return 1
    [[ ! -e "$root/.claude/audits/suppressions.json" ]] || { printf '    suppress_add wrote a file\n' >&2; return 1; }
  done
  # Control: a FUID still reaches the older entry.
  assert_eq FUID-a0000old "$(_c apply_resolve_id "$root" FUID-a0000old)" "control: the older entry by FUID" || return 1
  # Two entries holding one id in the latest run (only a hand edit makes this) name no one finding.
  _state "{\"FUID-a0000one\":$newer,\"FUID-b0000two\":$newer}" 3
  rc=0; out="$(_c apply_resolve_id "$root" SA-2026-01-01-01-001 2>/dev/null)" || rc=$?
  assert_eq "1 " "$rc $out" "an id two latest-run entries hold, apply_resolve_id" || return 1
  rc=0; _c suppress_add "$root" SA-2026-01-01-01-001 n >/dev/null 2>&1 || rc=$?
  assert_eq 3 "$rc" "an id two latest-run entries hold, suppress_add" || return 1
}

# A same-day rerun after the day's report file is gone numbers its findings from -01- again. When
# a SCANNER finding (never registered) takes the number a stale High still holds, --suppress on
# that number must not store the High's uid.
test_reused_display_id_does_not_reach_a_stale_entry() {
  _mk_root
  local out rc
  _state "{\"FUID-0ld00001\":$(jq -c '.last_display_id = "SA-2026-01-02-01-002"' <<<"$_good")}"
  { printf '%s\n' '{"rule_id":"PERM-001","severity":"medium","file":".claude/settings.json","line":2,"offset":0,"preview":"p","finding_uid":"FUID-new00001"}'
    printf '%s\n' '{"rule_id":"SCANNER-002","severity":"high","file":".claude/settings.json","line":0,"offset":0,"preview":"rule check failed"}'; } > "$root/raw"
  _c baseline_tag "$root/raw" "$root" > "$root/base" || return 1
  _c report_assign_display_ids "$root/base" 2026-01-02-01 > "$root/tagged" || return 1
  _c state_record_audit "$root" 2 "$root/.claude/audits/2026-01-02-01.md" "$root/tagged" all >/dev/null 2>&1 || return 1
  assert_eq SA-2026-01-02-01-002 "$(jq -r 'select(.rule_id == "SCANNER-002") | .display_id' "$root/tagged")" "the SCANNER finding took the number" || return 1
  assert_eq "SA-2026-01-02-01-002 1" "$(jq -r '.findings["FUID-0ld00001"] | "\(.last_display_id) \(.last_run_index)"' "$st")" "the stale High still holds it" || return 1
  rc=0; out="$(_c suppress_add "$root" SA-2026-01-02-01-002 "scanner noise" 2>&1)" || rc=$?
  assert_eq 3 "$rc" "suppress_add on the reused number" || return 1
  assert_contains "$out" "names no registered finding in the latest audit" "the message says the display id names no registered finding" || return 1
  [[ ! -e "$root/.claude/audits/suppressions.json" ]] || { printf '    suppressions.json written: %s\n' "$(cat "$root/.claude/audits/suppressions.json")" >&2; return 1; }
  rc=0; _c apply_resolve_id "$root" SA-2026-01-02-01-002 >/dev/null 2>&1 || rc=$?
  assert_eq 1 "$rc" "apply_resolve_id on the reused number" || return 1
  # Control: this run's registered finding resolves by its number.
  assert_eq FUID-new00001 "$(_c apply_resolve_id "$root" SA-2026-01-02-01-001)" "control: this run's finding" || return 1
}

test_empty_display_id_matches_nothing() {
  _mk_root
  # Every entry holds an empty display id, as the skill flow wrote before it assigned them.
  _state "{\"FUID-blank001\":$(jq -c '.last_display_id = ""' <<<"$_good"),\"FUID-blank002\":$(jq -c '.last_display_id = ""' <<<"$_good")}"
  local rc=0 out
  out="$(_c apply_resolve_id "$root" "" 2>/dev/null)" || rc=$?
  assert_eq "1 " "$rc $out" "apply_resolve_id on an empty id" || return 1
  rc=0; out="$(_c apply_run "$root" "" 2>&1)" || rc=$?
  assert_eq 1 "$rc" "apply_run on an empty id" || return 1
  assert_contains "$out" "Finding not found" "apply_run reports no finding" || return 1
  rc=0; _c suppress_add "$root" "" n >/dev/null 2>&1 || rc=$?
  assert_eq 3 "$rc" "suppress_add on an empty id" || return 1
  [[ ! -e "$root/.claude/audits/suppressions.json" ]] || { printf '    suppress_add wrote a file\n' >&2; return 1; }
  # Control: a FUID still resolves to itself, and a held display id still resolves.
  assert_eq FUID-blank002 "$(_c apply_resolve_id "$root" FUID-blank002)" "control: a FUID" || return 1
  _state "{\"FUID-blank001\":$(jq -c '.last_display_id = ""' <<<"$_good"),\"FUID-good0001\":$_good}"
  assert_eq FUID-good0001 "$(_c apply_resolve_id "$root" SA-2026-01-01-01-001)" "control: a held display id" || return 1
  # One entry of the latest run holds an empty id, so only the empty-id rule stops a match.
  rc=0; out="$(_c apply_resolve_id "$root" "" 2>/dev/null)" || rc=$?
  assert_eq "1 " "$rc $out" "apply_resolve_id on an empty id, one blank holder" || return 1
  rc=0; _c suppress_add "$root" "" n >/dev/null 2>&1 || rc=$?
  assert_eq 3 "$rc" "suppress_add on an empty id, one blank holder" || return 1
}

# A state with no recorded run has no latest report, so no display id resolves; a FUID still does.
test_display_id_without_a_recorded_run_matches_nothing() {
  _mk_root
  _state "{\"FUID-good0001\":$_good}" 0
  assert_eq 0 "$(jq '.audit_history | length' "$st")" "the state has no recorded run" || return 1
  local rc=0 out
  out="$(_c apply_resolve_id "$root" SA-2026-01-01-01-001 2>/dev/null)" || rc=$?
  assert_eq "1 " "$rc $out" "apply_resolve_id with no recorded run" || return 1
  rc=0; _c suppress_add "$root" SA-2026-01-01-01-001 n >/dev/null 2>&1 || rc=$?
  assert_eq 3 "$rc" "suppress_add with no recorded run" || return 1
  assert_eq FUID-good0001 "$(_c apply_resolve_id "$root" FUID-good0001)" "control: the FUID" || return 1
}

csa_test_run test_non_object_entry_is_skipped_by_readers_and_dropped_by_writers || _csa_failed=$((_csa_failed + 1))
csa_test_run test_registry_that_is_not_an_object_reads_as_empty                || _csa_failed=$((_csa_failed + 1))
csa_test_run test_gc_and_resighting_read_malformed_fields                       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_failed_gc_leaves_no_tmp_file                                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_display_id_resolves_only_in_the_latest_run                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_reused_display_id_does_not_reach_a_stale_entry               || _csa_failed=$((_csa_failed + 1))
csa_test_run test_empty_display_id_matches_nothing                              || _csa_failed=$((_csa_failed + 1))
csa_test_run test_display_id_without_a_recorded_run_matches_nothing             || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
