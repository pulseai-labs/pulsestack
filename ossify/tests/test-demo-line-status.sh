#!/usr/bin/env bash
# Demo-line status: planned, deferred, escaped (ossify 1.16.0; #363, #726, #710).
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/manifest.sh"
. "$HERE/../lib/entities.sh"; . "$HERE/../lib/ledger.sh"; . "$HERE/../lib/verify.sh"
. "$HERE/../lib/worktree.sh"; . "$HERE/../lib/demo.sh"; . "$HERE/../lib/registries.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
mkdir -p "$TMP/.workspace" "$TMP/canon"
cat > "$TMP/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
cd "$TMP"
oss_state_init "$S" line-status >/dev/null
oss_entity_add_release "$S" "r" "goal" >/dev/null
oss_entity_add_spine "$S" r0 "spine one" bone canonical >/dev/null
oss_entity_add_spine "$S" r0 "spine two" flesh canonical >/dev/null

# --- Task 1: the journal op writes the new fields only for their own status
oss_ledger_add_user "$S" r0.s1 "export an album with its captions" "captions survive" >/dev/null
oss_state_mutate "$S" set_demo_line_status '{"id":"d1","status":"deferred","by":"r0.s1","reason":"operator: no device today","until":"r2"}'
t_capture oss_state_read "$S" '.demo_ledger[0].deferred_until_release'
t_assert_eq "r2" "$T_OUT" "deferred writes deferred_until_release"
t_capture oss_state_read "$S" '.demo_ledger[0] | has("escape_clause")'
t_assert_eq "false" "$T_OUT" "deferred does not create escape_clause"
oss_state_mutate "$S" set_demo_line_status '{"id":"d1","status":"escaped","by":"r0.s1","reason":"operator: negative result accepted","clause":"SPINE.md: close on a written negative result"}'
t_capture oss_state_read "$S" '.demo_ledger[0].escape_clause'
t_assert_eq "SPINE.md: close on a written negative result" "$T_OUT" "escaped writes escape_clause"
oss_ledger_add_auto "$S" r0.s1 "plain" "true" "exit:0" >/dev/null
oss_state_mutate "$S" set_demo_line_status '{"id":"d2","status":"quarantined","by":"quarantine","reason":"x","release":"r1"}'
t_capture oss_state_read "$S" '.demo_ledger[1] | (has("deferred_until_release") or has("escape_clause"))'
t_assert_eq "false" "$T_OUT" "a quarantine creates neither new key (old-journal replay shape)"
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay clean across the new fields"

# --- Task 2: default planned, explicit active, anything else refused
t_capture oss_ledger_add_auto "$S" r0.s2 "a planned line" "false" "exit:0"
t_assert_rc 0 "add_auto with no status ok"; P1="$T_OUT"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$P1\")][0].status"
t_assert_eq "planned" "$T_OUT" "a new auto line defaults to planned"
t_capture oss_ledger_add_user "$S" r0.s2 "cancel an order and see it leave the list" "order gone"
P2="$T_OUT"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$P2\")][0].status"
t_assert_eq "planned" "$T_OUT" "a new user line defaults to planned"
t_capture oss_ledger_add_auto "$S" r0.s2 "bad status" "true" "exit:0" live
t_assert_rc 2 "an unknown initial status is refused"
t_capture oss_ledger_add_user "$S" r0.s2 "x" "y" deferred
t_assert_rc 2 "a new line cannot start deferred"

# --- Task 3: activation
t_capture oss_ledger_activate "$S" "$P1"
t_assert_rc 0 "activate a planned line"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$P1\")][0].status"
t_assert_eq "active" "$T_OUT" "planned -> active"
t_capture oss_ledger_activate "$S" "$P1"
t_assert_rc 2 "activating an active line is refused"
t_assert_contains "$T_OUT" "active" "the refusal names the current status"
t_capture oss_ledger_activate "$S" d999
t_assert_rc 7 "activate an unknown line is rc 7"
# activate_spine touches only that spine's PLANNED lines; a deferred line stays deferred
oss_ledger_add_auto "$S" r0.s2 "second planned" "true" "exit:0" >/dev/null
oss_ledger_add_auto "$S" r0.s1 "other spine planned" "true" "exit:0" >/dev/null; O1="$(oss_state_read "$S" '.demo_ledger[-1].id')"
oss_ledger_add_user "$S" r0.s2 "rename a playlist and find it by its new name" "found" active >/dev/null; U1="$(oss_state_read "$S" '.demo_ledger[-1].id')"
oss_state_mutate "$S" set_demo_line_status "{\"id\":\"$U1\",\"status\":\"deferred\",\"by\":\"r0.s2\",\"reason\":\"operator: later\",\"until\":\"r1\"}"
t_capture oss_ledger_activate_spine "$S" r0.s2
t_assert_rc 0 "activate_spine ok"; t_assert_contains "$T_OUT" "activated 2" "both planned lines of r0.s2 (P2 and the second planned auto line)"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.source_spine==\"r0.s2\" and .status==\"planned\")] | length"
t_assert_eq "0" "$T_OUT" "no planned line left on r0.s2"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$O1\")][0].status"
t_assert_eq "planned" "$T_OUT" "another spine's planned line is untouched"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$U1\")][0].status"
t_assert_eq "deferred" "$T_OUT" "a deferred line is not undone by activate_spine (Review Focus 3)"
t_capture oss_ledger_activate_spine "$S" r0.s2
t_assert_rc 0 "a second activate_spine is fine"; t_assert_contains "$T_OUT" "activated 0" "zero is not an error"
t_capture oss_ledger_activate_spine "$S" r9.s9
t_assert_rc 7 "unknown spine is rc 7"
t_capture oss_ledger_activate "$S" "$U1"
t_assert_rc 0 "a deferred line can be activated (walked now)"

# --- Task 4: deferral
oss_ledger_add_user "$S" r0.s2 "share a playlist and a friend opens it" "it opens" active >/dev/null; D1="$(oss_state_read "$S" '.demo_ledger[-1].id')"
t_capture oss_ledger_defer "$S" "$D1" r0.s2 "operator: the share server is down until next week" r2
t_assert_rc 0 "defer own user line"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$D1\")][0] | [.status, .deferred_until_release, .status_reason] | join(\"|\")"
t_assert_eq "deferred|r2|operator: the share server is down until next week" "$T_OUT" "deferral records status, release and the operator's words"
t_capture oss_ledger_defer "$S" "$D1" r0.s2 "operator: still down" r3
t_assert_rc 0 "re-defer ok"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$D1\")][0].deferred_until_release"
t_assert_eq "r3" "$T_OUT" "re-defer moves the due release (Review Focus 5)"
t_capture oss_ledger_defer "$S" "$D1" r0.s2 "   " r3
t_assert_rc 2 "whitespace-only words refused (Review Focus 1)"
t_capture oss_ledger_defer "$S" "$D1" r0.s2 "" r3
t_assert_rc 2 "empty words refused"
for bad in R3 3 r r3x; do t_capture oss_ledger_defer "$S" "$D1" r0.s2 "op" "$bad"; t_assert_rc 2 "release '$bad' refused (Review Focus 2)"; done
t_capture oss_ledger_defer "$S" "$D1" r0.s2 "op: padded" r03
t_assert_rc 0 "r03 is r<digits>, accepted"
t_capture oss_ledger_defer "$S" "$D1" r0.s1 "op" r3
t_assert_rc 2 "another spine cannot defer this spine's line"
t_capture oss_ledger_defer "$S" "$P1" r0.s2 "op" r3
t_assert_rc 2 "an auto line cannot be deferred"
t_capture oss_ledger_defer "$S" d999 r0.s2 "op" r3
t_assert_rc 7 "unknown line rc 7"
t_capture oss_ledger_defer "$S" "$D1" r9.s9 "op" r3
t_assert_rc 7 "unknown spine rc 7"

# expired_deferrals: due at or before the release (<=), numeric, anchorless blocks
t_capture oss_ledger_expired_deferrals "$S" r2
t_assert_rc 0 "D1 due at r3 is not due at r2"
t_capture oss_ledger_expired_deferrals "$S" r3
t_assert_rc 1 "due at its own release (<=)"; t_assert_contains "$T_OUT" "$D1" "the due line is named"
t_capture oss_ledger_expired_deferrals "$S" r10
t_assert_rc 1 "numeric, not lexicographic: r3 <= r10"
# a FRESH line: U1 still carries Task 3's deferred_until_release, and the op never clears that key
oss_ledger_add_user "$S" r0.s2 "pin a playlist and find it pinned" "pinned" active >/dev/null; U2="$(oss_state_read "$S" '.demo_ledger[-1].id')"
oss_state_mutate "$S" set_demo_line_status "{\"id\":\"$U2\",\"status\":\"deferred\",\"by\":\"r0.s2\",\"reason\":\"no anchor\"}"
t_capture oss_ledger_expired_deferrals "$S" r0
t_assert_rc 1 "an anchorless deferral blocks"; t_assert_contains "$T_OUT" "no-release-anchor" "marked no-release-anchor"
oss_ledger_activate "$S" "$U2" >/dev/null
oss_ledger_retire "$S" "$D1" r0.s2 "operator: sharing is dropped" >/dev/null
t_capture oss_ledger_expired_deferrals "$S" r3
t_assert_rc 0 "a pending retire by an OPEN spine is reported, not blocking"; t_assert_contains "$T_OUT" "amendment pending -> r0.s2" "reported as amendment pending"
oss_entity_set_spine_status "$S" r0.s2 closed >/dev/null
t_capture oss_ledger_expired_deferrals "$S" r3
t_assert_rc 1 "a pending retire owned by a CLOSED spine never applies, so the line still blocks (Codex PR #127)"
oss_entity_set_spine_status "$S" r0.s2 planned >/dev/null   # later tasks in this file still use r0.s2 as an open spine
t_capture oss_ledger_expired_deferrals "$S" bogus
t_assert_rc 2 "a malformed release is could-not-check"
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay clean after deferrals"

# --- #759: both release gates take r<digits> only. expired_quarantines used to take
# `${rel#r}`, so a bare `3` passed there and refused on expired_deferrals.
# Every spelling below is refused alike by all three gates (r1 review C3): a space or newline
# before or after the digits, a sign, a doubled prefix, a bare number, a case change, and a decimal
# or exponent that jq's tonumber would read as 3 (r2 review C6). The message pin makes the shape
# check itself the thing under test: a later jq failure also exits 2.
for bad in '' r 3 R3 r3x 'r 3' ' r3' 'r3 ' r-3 r+3 rr3 $'r3\n' 03 r3.0 r3e0 r3E0; do
  t_capture oss_ledger_expired_quarantines "$S" "$bad"
  t_assert_rc 2 "expired_quarantines refuses release '$bad' (could-not-check, rc 2)"
  t_assert_contains "$T_OUT" "expired_quarantines needs a release id of the form r<N>" "...by the shape check, not by a later jq failure (jq-version proof)"
  t_capture oss_ledger_expired_deferrals "$S" "$bad"
  t_assert_rc 2 "expired_deferrals refuses release '$bad' (rc 2)"
  t_assert_contains "$T_OUT" "expired_deferrals needs a release id of the form r<N>" "...by the shape check, not by a later jq failure (jq-version proof)"
  t_capture oss_reg_expired_fakes "$S" "$bad"
  t_assert_rc 2 "expired_fakes refuses release '$bad' (rc 2): the third gate on the same grammar"
  t_assert_contains "$T_OUT" "expired_fakes needs a release id of the form r<N>" "...by the shape check, not by a later jq failure (jq-version proof)"
done
t_capture oss_reg_expired_fakes "$S" 3
t_assert_contains "$T_OUT" "expired_fakes needs a release id of the form r<N> (got '3')" "the fakes gate's bare-number refusal keeps its own message"
t_capture oss_ledger_expired_quarantines "$S" 3
t_assert_contains "$T_OUT" "needs a release id of the form r<N> (got '3')" "the bare-number refusal keeps its message"
# Adjacent controls: the spellings both gates accept still work, and the gates agree.
t_capture oss_ledger_expired_quarantines "$S" r3
t_assert_rc 1 "control: r3 still reads the ledger on the quarantine gate (d2, quarantined at r1, is owed)"
t_assert_contains "$T_OUT" "d2" "...and names the owed line"
for ok in r3 r03 r10 r0; do
  t_capture oss_ledger_expired_quarantines "$S" "$ok"; qrc=$T_RC
  t_capture oss_ledger_expired_deferrals "$S" "$ok"; drc=$T_RC
  t_capture oss_reg_expired_fakes "$S" "$ok"; frc=$T_RC
  [ "$qrc" != 2 ] && [ "$drc" != 2 ] && [ "$frc" != 2 ] && t_assert_eq 1 1 "all three gates accept '$ok'" || t_assert_eq "not 2/not 2/not 2" "$qrc/$drc/$frc" "all three gates accept '$ok'"
done

# --- #761 item 6: the expired_deferrals TSV carries source_spine as column 5, after the
# reason, so release close can name the owner `oss ledger_defer` needs for a re-defer.
# The amendment's `by` (r0.s1) is deliberately NOT the line's owner (r0.s2): a column 5
# built from the wrong field reads r0.s1 there.
S4="$TMP/state4.json"; oss_state_init "$S4" owner-col >/dev/null
oss_entity_add_release "$S4" "r" "g" >/dev/null
oss_entity_add_spine "$S4" r0 "one" bone canonical >/dev/null; oss_entity_add_spine "$S4" r0 "two" flesh canonical >/dev/null
oss_ledger_add_user "$S4" r0.s2 "restore a backup and see the data" "data back" active >/dev/null; OA="$(oss_state_read "$S4" '.demo_ledger[-1].id')"
oss_ledger_add_user "$S4" r0.s2 "export a report and open it" "opens" active >/dev/null; OB="$(oss_state_read "$S4" '.demo_ledger[-1].id')"
oss_ledger_add_user "$S4" r0.s1 "invite a teammate and see them join" "joined" active >/dev/null; OC="$(oss_state_read "$S4" '.demo_ledger[-1].id')"
oss_ledger_defer "$S4" "$OA" r0.s2 "operator: no backup host" r1 >/dev/null
oss_ledger_defer "$S4" "$OB" r0.s2 "operator: report tool down" r1 >/dev/null
oss_state_mutate "$S4" set_demo_line_status "{\"id\":\"$OC\",\"status\":\"deferred\",\"by\":\"r0.s1\",\"reason\":\"no anchor\"}"
oss_ledger_retire "$S4" "$OB" r0.s1 "operator: reports are dropped" >/dev/null
_col() { printf '%s\n' "$T_OUT" | awk -F'\t' -v id="$1" -v c="$2" '$1 == id { print $c }'; }
t_capture oss_ledger_expired_deferrals "$S4" r1
t_assert_rc 1 "a due row still blocks (the awk \$3 == due verdict is unchanged)"
t_assert_eq "5" "$(printf '%s\n' "$T_OUT" | awk -F'\t' '{ print NF }' | sort -u)" "every row has exactly five columns"
t_assert_eq "r0.s2" "$(_col "$OA" 5)" "a due row's column 5 is the owning spine"
t_assert_eq "due" "$(_col "$OA" 3)" "...column 3 is still the verdict"
t_assert_eq "operator: no backup host" "$(_col "$OA" 4)" "...and column 4 is still the reason"
t_assert_eq "r0.s2" "$(_col "$OB" 5)" "an amendment-pending row's column 5 is the line's owner, not the amendment's spine"
t_assert_eq "amendment pending -> r0.s1" "$(_col "$OB" 3)" "...column 3 still names the amendment's spine"
t_assert_eq "operator: report tool down" "$(_col "$OB" 4)" "...and column 4 is still the reason"
t_assert_eq "r0.s1" "$(_col "$OC" 5)" "an anchorless row's column 5 is the owning spine too"
S5="$TMP/state5.json"; oss_state_init "$S5" owner-col-nonblocking >/dev/null
oss_entity_add_release "$S5" "r" "g" >/dev/null
oss_entity_add_spine "$S5" r0 "one" bone canonical >/dev/null; oss_entity_add_spine "$S5" r0 "two" flesh canonical >/dev/null
oss_ledger_add_user "$S5" r0.s2 "export a report and open it" "opens" active >/dev/null; OD="$(oss_state_read "$S5" '.demo_ledger[-1].id')"
oss_ledger_defer "$S5" "$OD" r0.s2 "operator: report tool down" r1 >/dev/null
oss_ledger_retire "$S5" "$OD" r0.s1 "operator: reports are dropped" >/dev/null
t_capture oss_ledger_expired_deferrals "$S5" r1
t_assert_rc 0 "only an amendment-pending row: reported, not blocking"
t_assert_eq "r0.s2" "$(_col "$OD" 5)" "...and its column 5 is the owner"

# --- Task 5: escape
oss_ledger_add_user "$S" r0.s2 "certify a strategy and trade it live" "certified" active >/dev/null; E1="$(oss_state_read "$S" '.demo_ledger[-1].id')"
t_capture oss_ledger_escape "$S" "$E1" r0.s2 "SPINE.md §1: if nothing certifies in 2 weeks, close on a written negative result" "operator: accept the negative result"
t_assert_rc 0 "escape own user line"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$E1\")][0] | [.status, .escape_clause, .status_reason] | join(\"|\")"
t_assert_eq "escaped|SPINE.md §1: if nothing certifies in 2 weeks, close on a written negative result|operator: accept the negative result" "$T_OUT" "escape records clause and words"
t_capture oss_ledger_escape "$S" "$E1" r0.s2 "c" "w"
t_assert_rc 2 "escaped is terminal"
t_capture oss_ledger_activate "$S" "$E1"
t_assert_rc 2 "an escaped line cannot be activated"
t_capture oss_ledger_escape "$S" "$P1" r0.s2 "c" "w"
t_assert_rc 2 "an auto line cannot escape"
oss_ledger_add_user "$S" r0.s2 "another journey to escape" "seen" active >/dev/null; E2="$(oss_state_read "$S" '.demo_ledger[-1].id')"
t_capture oss_ledger_escape "$S" "$E2" r0.s2 "  " "w"
t_assert_rc 2 "an empty escape clause is refused"
t_capture oss_ledger_escape "$S" "$E2" r0.s2 "c" ""
t_assert_rc 2 "empty operator words are refused"
t_capture oss_ledger_escape "$S" "$E2" r0.s2 "c" "   "
t_assert_rc 2 "whitespace-only operator words are refused (the clause's sibling guard, Review Focus 1)"
t_capture oss_ledger_escape "$S" "$E2" r0.s1 "c" "w"
t_assert_rc 2 "another spine cannot escape this spine's line"
t_capture oss_demo_user_lines "$S" r0.s2
t_assert_eq "false" "$(printf '%s' "$T_OUT" | jq --arg e "$E1" 'any(.[]; .id == $e)')" "an escaped line is never walked"

# --- Task 6: demo_run and planned lines
S2="$TMP/state2.json"; oss_state_init "$S2" run >/dev/null
oss_entity_add_release "$S2" "r" "g" >/dev/null; oss_entity_add_spine "$S2" r0 "a" bone canonical >/dev/null
oss_ledger_add_auto "$S2" r0.s1 "not built yet" "false" "exit:0" >/dev/null
t_capture oss_demo_run_auto "$S2"
t_assert_rc 1 "all-planned ledger still fails the zero-lines floor (Review Focus 4)"
t_assert_contains "$T_OUT" "PENDING d1 (planned -> r0.s1)" "the planned line is reported, not run"
t_assert_contains "$T_OUT" "1 pending" "the floor message names the pending count"
oss_ledger_add_auto "$S2" r0.s1 "built" "true" "exit:0" active >/dev/null
t_capture oss_demo_run_auto "$S2"
t_assert_rc 0 "a planned failing line no longer reddens the run"
t_assert_contains "$T_OUT" "PASS 1 lines" "only the active line ran"
t_assert_contains "$T_OUT" "1 pending" "pending count printed beside PASS"

# --- Task 7: every new verb through the real dispatcher (set -euo pipefail there)
OSS="$HERE/../bin/oss"
DTMP="$(mktemp -d)"; export OSS_STATE_FILE="$DTMP/state.json"
mkdir -p "$DTMP/.ossify"
cat > "$DTMP/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"canonical":{"root":"$DTMP/canon"}},"well_known_paths":{"project_state":"$OSS_STATE_FILE"}}
JSON
cd "$DTMP"
t_capture "$OSS" init line-status-cli
t_assert_rc 0 "cli init"
"$OSS" release_add "R" "goal" >/dev/null
"$OSS" spine_add r0 "s" bone >/dev/null
t_capture "$OSS" ledger_add_user r0.s1 "send a message and see it delivered" "delivered"
t_assert_rc 0 "cli add_user"; CL="$T_OUT"
t_capture "$OSS" get "[.demo_ledger[] | select(.id==\"$CL\")][0].status"
t_assert_eq "planned" "$T_OUT" "cli default planned"
t_capture "$OSS" ledger_activate_spine r0.s1
t_assert_contains "$T_OUT" "activated 1" "cli activate_spine"
t_capture "$OSS" ledger_defer "$CL" r0.s1 "operator: later" r1
t_assert_rc 0 "cli defer"
t_capture "$OSS" expired_deferrals r1
t_assert_rc 1 "cli expired_deferrals blocks"
t_capture "$OSS" ledger_activate "$CL"
t_assert_rc 0 "cli activate"
t_capture "$OSS" ledger_escape "$CL" r0.s1 "SPINE.md: escape" "operator: accept"
t_assert_rc 0 "cli escape"
t_capture "$OSS" ledger_add_auto r0.s1 "x" "true" "exit:0" active
t_assert_rc 0 "cli add_auto with explicit active"
t_capture "$OSS" ledger_add_auto r0.s1 "combined form (#770)" "echo ok" "exit:0+contains:ok" active
t_assert_rc 0 "cli add_auto takes exit:<n>+contains:<str> under the dispatcher's strict mode"
t_capture "$OSS" ledger_add_auto r0.s1 "combined form, empty needle" "echo ok" "exit:0+contains:" active
t_assert_rc 2 "cli add_auto refuses an empty needle in the combined form (rc 2)"
t_capture "$OSS" expired_quarantines 3
t_assert_rc 2 "cli expired_quarantines refuses a bare release number (#759)"
cd "$HERE"; rm -rf "$DTMP"; unset OSS_STATE_FILE

# --- F2 (PR #760): the status guard runs inside the journal op, under the lock
S3="$TMP/state3.json"; oss_state_init "$S3" guard >/dev/null
oss_entity_add_release "$S3" "r" "g" >/dev/null; oss_entity_add_spine "$S3" r0 "a" bone canonical >/dev/null
oss_ledger_add_user "$S3" r0.s1 "share a playlist and a friend opens it" "it opens" active >/dev/null; G1="$(oss_state_read "$S3" '.demo_ledger[-1].id')"
oss_state_mutate "$S3" set_demo_line_status "{\"id\":\"$G1\",\"status\":\"deferred\",\"by\":\"r0.s1\",\"reason\":\"operator: later\",\"until\":\"r1\"}"
# 1. a from-guarded op whose set does not hold the line's current status changes nothing
oss_state_mutate "$S3" set_demo_line_status "{\"id\":\"$G1\",\"status\":\"active\",\"by\":\"guard-probe\",\"reason\":null,\"from\":[\"planned\"]}"
t_capture oss_state_read "$S3" "[.demo_ledger[] | select(.id==\"$G1\")][0] | [.status, .status_by, (.deferred_until_release // \"-\")] | join(\"|\")"
t_assert_eq "deferred|r0.s1|r1" "$T_OUT" "a from-guarded op leaves a line outside its set byte-identical"
# ...and one whose set DOES hold it still writes
oss_state_mutate "$S3" set_demo_line_status "{\"id\":\"$G1\",\"status\":\"deferred\",\"by\":\"r0.s1\",\"reason\":\"operator: still later\",\"until\":\"r2\",\"from\":[\"deferred\"]}"
t_capture oss_state_read "$S3" "[.demo_ledger[] | select(.id==\"$G1\")][0].deferred_until_release"
t_assert_eq "r2" "$T_OUT" "a from-guarded op whose set holds the line's status writes"
# 2. no `from` at all is the pre-1.16 payload shape, and it still writes
oss_state_mutate "$S3" set_demo_line_status "{\"id\":\"$G1\",\"status\":\"active\",\"by\":\"unconditional\",\"reason\":null}"
t_capture oss_state_read "$S3" "[.demo_ledger[] | select(.id==\"$G1\")][0].status"
t_assert_eq "active" "$T_OUT" "an op with no from still writes (old journals replay unchanged)"
# 3. the race shape: the defer lands after a snapshot that still held the line planned
oss_state_mutate "$S3" set_demo_line_status "{\"id\":\"$G1\",\"status\":\"deferred\",\"by\":\"r0.s1\",\"reason\":\"operator: later\",\"until\":\"r1\"}"
oss_ledger_add_auto "$S3" r0.s1 "still planned" "true" "exit:0" >/dev/null
t_capture oss_ledger_activate_spine "$S3" r0.s1
t_assert_rc 0 "activate_spine runs over a set holding a deferred line"
t_assert_contains "$T_OUT" "activated 1" "the count excludes the deferred line and counts the one that went live"
t_capture oss_state_read "$S3" "[.demo_ledger[] | select(.id==\"$G1\")][0].status"
t_assert_eq "deferred" "$T_OUT" "the deferred line is not undone by the spine activation"
t_capture oss_ledger_activate "$S3" "$G1"
t_assert_rc 0 "a deferred line still activates explicitly (walked now)"
# ...and a defer-shaped guard cannot move an escaped line (terminal, under the lock)
oss_state_mutate "$S3" set_demo_line_status "{\"id\":\"$G1\",\"status\":\"escaped\",\"by\":\"r0.s1\",\"reason\":\"op: negative result\",\"clause\":\"SPINE.md: escape\"}"
oss_state_mutate "$S3" set_demo_line_status "{\"id\":\"$G1\",\"status\":\"deferred\",\"by\":\"r0.s1\",\"reason\":\"op: late\",\"until\":\"r9\",\"from\":[\"active\",\"planned\",\"deferred\"]}"
t_capture oss_state_read "$S3" "[.demo_ledger[] | select(.id==\"$G1\")][0].status"
t_assert_eq "escaped" "$T_OUT" "the defer guard leaves an escaped line where it is"
# 4. replay across the from-guarded writes
t_capture oss_state_replay "$S3"
t_assert_rc 0 "replay clean across from-guarded writes"

cd "$HERE"; rm -rf "$TMP"
t_summary
