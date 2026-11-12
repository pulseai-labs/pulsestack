#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/registries.sh"
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"; S="$TMP/state.json"
oss_state_init "$S" reg-demo >/dev/null

t_capture oss_reg_add_bone "$S" ADR-0002 "hexagonal domain boundary" "src/domain/**,src/lib.rs" "revisit at v1"
t_assert_rc 0 "bone added"
t_capture oss_reg_add_risk_gate "$S" live-money "src/adapters/broker/**" "paper-env,kill-switch,human-confirm,audit-trail"
t_assert_rc 0 "risk gate added"
t_capture oss_reg_add_fake "$S" "coach-llm" fake "shell for skeleton" "first real strategy iteration" r1
t_assert_rc 0 "fake added"
t_capture oss_reg_add_feature "$S" "paper trading loop" "user places a paper trade and sees P&L move" flesh journey-map
t_assert_rc 0 "feature added"

# --- #305 item 1: the add verbs refuse a ref that already exists -----------
# The ADR ref (and the gate name) is the key every reader uses - touch_check, the
# doctor shape gate, the registry doc - and the writer did not enforce it: a
# second bone_add for ADR-013 minted a second row for one ref (the PulseDB adopt
# pilot, 2026-08-23), after which bone_set_touch refuses the ref at rc 7 and the
# operator holds a surface they cannot repair. Nothing detects a duplicate, so the
# writer is the only place the mint can be refused.
t_capture oss_reg_add_bone "$S" ADR-0002 "a second row for one ref" "src/other/**" ""
t_assert_rc 7 "bone_add refuses an ADR ref that already exists"
t_assert_contains "$T_OUT" "already exists" "...and says the ref is already there"
t_assert_contains "$T_OUT" "bone_set_touch" "...and names the repair for an existing surface"
t_assert_contains "$T_OUT" "#305" "...and names the issue"
t_capture jq '[.bones[] | select(.adr=="ADR-0002")] | length' "$S"
t_assert_eq "1" "$T_OUT" "...and no second row was minted"
t_capture oss_reg_add_risk_gate "$S" live-money "src/other/**" "ctl"
t_assert_rc 7 "risk_gate_add refuses a name that already exists"
t_assert_contains "$T_OUT" "already exists" "...and says so"
t_assert_contains "$T_OUT" "risk_gate_set_touch" "...and names the repair"
t_capture jq '[.risk_gates[] | select(.name=="live-money")] | length' "$S"
t_assert_eq "1" "$T_OUT" "...and no second gate was minted"
# ADJACENT CONTROL: a DISTINCT ref is still added, and bone_add still admits an
# empty surface - the asymmetry with the re-point verbs is deliberate and pinned
# below (a bone with no surface is legitimate at mint; a re-point to nothing is
# not a repair).
t_capture oss_reg_add_bone "$S" ADR-0011 "a different decision" "" ""
t_assert_rc 0 "a distinct ADR ref is still added, with an empty surface"
t_capture jq -c '.bones[] | select(.adr=="ADR-0011") | .touch' "$S"
t_assert_eq '[]' "$T_OUT" "...and its empty surface is recorded as such"

# --- #705: the rail folds the ADR ref ASCII case-insensitively -------------
# adopt C3 step 1a folds under LC_ALL=C; a case variant is the same reference.
t_capture oss_reg_add_bone "$S" ADR-0007 "first of a case pair" "src/a/**" ""
t_assert_rc 0 "#705 setup: ADR-0007 mints"
t_capture oss_reg_add_bone "$S" adr-0007 "the case variant" "src/b/**" ""
t_assert_rc 7 "#705: a case variant of an existing ADR ref refuses (rc 7)"
t_assert_contains "$T_OUT" "as 'ADR-0007'" "#705: ...naming the existing row's spelling"
t_capture jq '[.bones[] | select(.adr | ascii_downcase == "adr-0007")] | length' "$S"
t_assert_eq "1" "$T_OUT" "#705: ...and one row is left"
t_capture oss_reg_add_bone "$S" ADR-0007 "same spelling" "src/b/**" ""
t_assert_rc 7 "#705 control: the exact same spelling still refuses"
case "$T_OUT" in *" as '"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: #705: an identical spelling must not say 'as'" ;; *) T_PASS=$((T_PASS+1)) ;; esac
t_capture oss_reg_add_bone "$S" adr-0010 "lower-case first" "src/d/**" ""
t_assert_rc 0 "#705 setup: adr-0010 mints"
t_capture oss_reg_add_bone "$S" ADR-0010 "the upper-case variant" "src/e/**" ""
t_assert_rc 7 "#705: the fold is symmetric - ADR-0010 after adr-0010 refuses too"
t_assert_contains "$T_OUT" "as 'adr-0010'" "#705: ...naming the stored lower-case spelling"
t_capture oss_reg_add_bone "$S" ADR-0008 "a distinct number" "src/c/**" ""
t_assert_rc 0 "#705 control: ADR-0007 then ADR-0008 still mints"
# A stored .adr that is not a string must not let the rail pass: it fails closed.
S705="$TMP/non-string-adr.json"; oss_state_init "$S705" ns >/dev/null
oss_state_mutate "$S705" add_bone \
  "$(jq -n --arg ts "$(_oss_now)" '{adr:7,title:"numeric adr",touch:["src/x/**"],revisit_trigger:null,at:$ts}')" >/dev/null
t_capture oss_reg_add_bone "$S705" ADR-0009 "behind a numeric row" "src/y/**" ""
if [ "$T_RC" -ne 0 ]; then T_PASS=$((T_PASS+1)); else T_FAIL=$((T_FAIL+1)); echo "FAIL: #705: a non-string stored .adr let the rail pass (rc 0)"; fi
t_capture jq '.bones | length' "$S705"
t_assert_eq "1" "$T_OUT" "#705: ...and nothing was minted behind the unreadable row"

# --- #305 item 1, the atomic half: the rail runs INSIDE the mutation lock ----
# The refusals above are only half the rail. The count they refuse on was a read
# in the VERB, before oss_state_mutate acquires its lock - so two ceremonies could
# both read "no such ref", serialize on the lock, and the second would append a
# second row for one key: the unrepairable state this rail exists to prevent,
# entered by two conforming callers. Measured against that version: two concurrent
# `oss bone_add ADR-Rn` each exited 0 and left two rows for ADR-Rn.
#
# A concurrency test would be a TIMING test - green on a lucky schedule, so it
# cannot pin this. The structural property is what the rail needs and what is
# decidable: the guard must be unable to answer before the lock is held, so with
# the lock HELD a duplicate add answers the LOCK (rc 3), never the duplicate
# (rc 7). A verb-side count answers 7 while the lock is held, which is what makes
# these rows RED against that spelling.
mkdir "$S.lock"
t_capture oss_reg_add_bone "$S" ADR-0002 "a third row for one ref" "src/other/**" ""
t_assert_rc 3 "a duplicate add while the lock is held answers rc 3, not rc 7 - the rail is inside the lock"
t_capture oss_reg_add_risk_gate "$S" live-money "src/other/**" "ctl"
t_assert_rc 3 "...and the gate rail is too"
# ADJACENT CONTROL, same held lock, a ref that does NOT exist: also rc 3. Without
# it, a rc 3 arriving for any other reason would read as proof of atomicity.
t_capture oss_reg_add_bone "$S" ADR-0004 "a fourth decision" "src/other/**" ""
t_assert_rc 3 "...and an add for a NEW ref answers rc 3 under the same lock"
rmdir "$S.lock"
# Released again, and both verdicts are the ones the rows above already pinned:
# the duplicate still refuses at rc 7, the new ref still mints.
t_capture oss_reg_add_bone "$S" ADR-0002 "a third row for one ref" "src/other/**" ""
t_assert_rc 7 "...and once the lock is released the duplicate refuses at rc 7 as before"
t_capture jq '[.bones[] | select(.adr=="ADR-0002")] | length' "$S"
t_assert_eq "1" "$T_OUT" "...with still one row for that ref"
t_capture oss_reg_add_bone "$S" ADR-0004 "a fourth decision" "src/other/**" ""
t_assert_rc 0 "...and the new ref mints at rc 0"

# --- #530 at the MINT: a contaminated entry is refused before it lands -------
# The re-point verbs refuse an entry with surrounding whitespace; the two ADD
# verbs journaled one at rc 0. A bone minted from a CRLF-composed csv declared a
# surface that touch_check then answered CLEAN on, from mint day, with nothing to
# review and no refusal to notice. Measured before this rail:
# `bone_add ADR-C "t" "$(printf 'src/c/**\r')"` -> rc 0, and touch_check on
# src/c/load.py -> rc 1 (clean) - the #530 harm, at the boundary that creates the
# registry rather than the one that repairs it.
for csv in "$(printf 'src/c/**\r')" "$(printf '\tsrc/c/**')" "$(printf 'src/c/**\xc2\xa0')"; do
  _hex="$(printf '%s' "$csv" | od -An -tx1 | tr -d ' ')"
  t_capture oss_reg_add_bone "$S" ADR-C "contaminated mint" "$csv" ""
  t_assert_rc 2 "bone_add refuses an entry with surrounding whitespace ($_hex)"
  t_assert_contains "$T_OUT" "leading or trailing whitespace" "...and diagnoses the entry ($_hex)"
done
t_capture jq '[.bones[] | select(.adr=="ADR-C")] | length' "$S"
t_assert_eq "0" "$T_OUT" "...and no bone was minted by any refused call"
t_capture oss_reg_add_risk_gate "$S" ctrl-gate "$(printf 'src/c/**\r')" "ctl-one"
t_assert_rc 2 "risk_gate_add refuses a contaminated touch glob"
t_capture oss_reg_add_risk_gate "$S" ctrl-gate "src/c/**" "$(printf 'ctl-one\r')"
t_assert_rc 2 "...and a contaminated control phrase"
t_capture jq '[.risk_gates[] | select(.name=="ctrl-gate")] | length' "$S"
t_assert_eq "0" "$T_OUT" "...and no gate was minted either"
# ADJACENT CONTROLS. The mint keeps every tolerance it had: an interior space and
# an escaped comma still pass, and an EMPTY surface is still admitted - the
# registry declares a surface at spec time, before the code exists, and the
# refusal belongs to the corrective append, which REPLACES a surface. Without
# these rows the rails above could be over-refusing and nothing would say so.
t_capture oss_reg_add_bone "$S" ADR-C2 "interior space" "src/my file.py,src/ok/**" ""
t_assert_rc 0 "an entry with an interior space is still minted"
t_capture jq -c '.bones[] | select(.adr=="ADR-C2") | .touch' "$S"
t_assert_eq '["src/my file.py","src/ok/**"]' "$T_OUT" "...with the interior space intact"
t_capture oss_reg_add_risk_gate "$S" ctrl-gate "src/c/**" ""
t_assert_rc 0 "an empty controls list is still admitted at mint"
t_capture jq -c '.risk_gates[] | select(.name=="ctrl-gate") | .controls' "$S"
t_assert_eq '[]' "$T_OUT" "...and recorded as empty, not refused"

# --- the edge class is `[\s\p{Cf}]`, not `\s` alone (round 2) ----------------
# `\s` is Unicode White_Space, which covers the CR/tab/VT/NBSP/U+3000 rows above
# - but NOT the format characters, and a UTF-8 BOM (U+FEFF) or a zero-width space
# (U+200B) sits on line 1 of exactly the composed-from-a-Windows-file input this
# rail exists for. Measured before the extension: a BOM-prefixed and a
# ZWSP-suffixed glob were journaled at rc 0 at the MINT and on the re-point
# alike, and touch_check answered CLEAN on the covered path - the #530 harm one
# invisible character wide of the guard.
for csv in "$(printf '\xef\xbb\xbfsrc/bom/**')" "$(printf 'src/zwsp/**\xe2\x80\x8b')" \
           "$(printf 'src/zwnj/**\xe2\x80\x8c')" "$(printf 'src/softhyphen/**\xc2\xad')"; do
  _hex="$(printf '%s' "$csv" | od -An -tx1 | tr -d ' ')"
  t_capture oss_reg_add_bone "$S" ADR-F "format char" "$csv" ""
  t_assert_rc 2 "bone_add refuses an invisible format character at the edge ($_hex)"
  t_capture oss_reg_set_bone_touch "$S" ADR-0002 "$csv"
  t_assert_rc 2 "...and the re-point verb refuses it too ($_hex)"
done
t_capture jq '[.bones[] | select(.adr=="ADR-F")] | length' "$S"
t_assert_eq "0" "$T_OUT" "...and no bone was minted by any refused call"
# ADJACENT CONTROL, the same rule the interior-space row states: the guard is
# EDGES only. An interior zero-width space stays legal, so this row goes RED if
# the predicate is ever widened to "contains a format character anywhere".
t_capture oss_reg_add_bone "$S" ADR-F2 "interior format char" "$(printf 'src/a\xe2\x80\x8bb.py')" ""
t_assert_rc 0 "an entry with an INTERIOR zero-width space is still accepted"
t_capture jq -c '.bones[] | select(.adr=="ADR-F2") | .touch' "$S"
t_assert_eq '["src/a​b.py"]' "$T_OUT" "...and it survives into the journaled surface"

# --- the mint takes the ONE-LIST arm too (round 2) --------------------------
# A csv wrapped over two lines emits two JSON values, so --argjson cannot parse
# it. The re-point path has answered that with "not one list" since 1.11.0, and
# its own comment calls the arms' separation deliberate. Calling the contaminated
# arm directly at the mint put it back in front of an unparseable list: measured,
# `bone_add` printed jq's raw `invalid JSON text passed to --argjson` on stderr
# and then mislabelled the failure "cannot read the touch list" - the retry-loop
# false cause this file's corrupt-state rows exist to prevent, one verb over.
t_capture oss_reg_add_bone "$S" ADR-NL "wrapped csv" "$(printf 'src/a/**\nsrc/b/**')" ""
t_assert_rc 2 "bone_add refuses a two-line touch-csv"
t_assert_contains "$T_OUT" "not one list" "...and reports two lists, not an unreadable one"
case "$T_OUT" in
  *"parse error"*|*"jq: error"*|*"invalid JSON"*)
    T_FAIL=$((T_FAIL+1)); echo "FAIL: bone_add leaks jq's raw error into its refusal - the one-list arm is not running first" ;;
  *) T_PASS=$((T_PASS+1)) ;;
esac
t_capture oss_reg_add_risk_gate "$S" nl-gate "src/a/**" "$(printf 'ctl-a\nctl-b')"
t_assert_rc 2 "...and risk_gate_add refuses a two-line controls-csv the same way"
t_assert_contains "$T_OUT" "not one list" "...with the same diagnosis, not a jq error"
t_capture jq '[.risk_gates[] | select(.name=="nl-gate")] | length' "$S"
t_assert_eq "0" "$T_OUT" "...and no gate was minted by either refused call"

# --- D1 fake lifecycle (Task 2, named risk 7): oss_reg_set_fake_status must
# leave expiry_release ALONE when the 5th arg (new expiry) is omitted.
# test-ledger.sh only exercises the WITH-a-new-expiry (renew) path, so that
# half of the contract has no coverage without this.
t_capture oss_reg_set_fake_status "$S" "coach-llm" replaced "swapped for a real model"
t_assert_rc 0 "fake status change without a new expiry ok"
t_capture jq -r '.fakes[] | select(.boundary=="coach-llm") | .status' "$S"
t_assert_eq "replaced" "$T_OUT" "status actually changed"
t_capture jq -r '.fakes[] | select(.boundary=="coach-llm") | .expiry_release' "$S"
t_assert_eq "r1" "$T_OUT" "expiry_release is UNCHANGED when the 5th arg is omitted"

# --- #125: fake_add refuses a boundary that is already in the ledger ---------
# `boundary` is the key fake_status matches on, and it rewrites EVERY record it
# matches, so a second record for one boundary can never be changed on its own.
# Measured before the fix: two fake_add calls for one boundary, both rc 0, two
# records. coach-llm is in the ledger (now `replaced`); a later spine re-adding
# it in ANY channel - the old prose's "retained" and "built real" re-records -
# is refused, and the refusal names the verb that records those instead.
for ch in fake real deferred; do
  t_capture oss_reg_add_fake "$S" "coach-llm" "$ch" "a later spine" "a trigger" r2
  t_assert_rc 7 "#125: fake_add refuses an existing boundary (channel $ch)"
done
t_assert_contains "$T_OUT" "already in the ledger" "#125: ...and says the boundary is already recorded"
t_assert_contains "$T_OUT" "fake_status coach-llm renewed" "#125: ...and names the retain route"
t_assert_contains "$T_OUT" "fake_status coach-llm replaced" "#125: ...and the built-real route"
t_capture jq '[.fakes[] | select(.boundary=="coach-llm")] | length' "$S"
t_assert_eq "1" "$T_OUT" "#125: ...and no second record was minted"
# In the lock, like the bone and gate rails: with the lock HELD a duplicate
# answers rc 3, never rc 7 - a verb-side count would answer 7 here.
mkdir "$S.lock"
t_capture oss_reg_add_fake "$S" "coach-llm" fake "a later spine" "a trigger" r2
t_assert_rc 3 "#125: a duplicate fake_add while the lock is held answers rc 3 - the rail is inside the lock"
t_capture oss_reg_add_fake "$S" "brand-new-boundary" fake "why" "when" r2
t_assert_rc 3 "#125 control: ...and so does a NEW boundary under the same lock"
rmdir "$S.lock"
# ADJACENT CONTROL: a distinct boundary still mints (the dispatcher-path row is
# in test-dispatcher-ops.sh, which owns a dispatcher-resolved state).
t_capture oss_reg_add_fake "$S" "email-sender" deferred "not wired yet" "the first real user" r2
t_assert_rc 0 "#125 control: a distinct boundary is still added"
# Replay stays permissive: a journal from an older build that already holds a
# duplicate still applies, because the rail is the VERB's, not _oss_apply_op's.
t_capture oss_state_mutate "$S" add_fake \
  "$(jq -n --arg ts "$(_oss_now)" '{boundary:"coach-llm",channel:"fake",reason:"old journal",replacement_trigger:"t",expiry_release:"r1",status:"active",at:$ts}')"
t_assert_rc 0 "#125 control: the raw op (the replay path) still applies a duplicate - replay is not refused"

t_capture oss_reg_touch_check "$S" src/domain/dsl/compile.rs
t_assert_rc 0 "domain path matches a bone"; t_assert_contains "$T_OUT" "bone ADR-0002" "bone named"
t_capture oss_reg_touch_check "$S" src/adapters/broker/order.rs
t_assert_rc 0 "broker path matches risk gate"; t_assert_contains "$T_OUT" "risk_gate live-money" "gate named"
t_capture oss_reg_touch_check "$S" README.md
t_assert_rc 1 "clean path matches nothing"

# Fix 2: a bone/risk-gate with no touch surface is legitimate — empty CSV must
# yield an empty [] touch array, not a raw jq --argjson parse failure (rc 4).
t_capture oss_reg_add_bone "$S" ADR-9 "no-touch bone" "" ""
t_assert_rc 0 "no-touch bone added"
t_capture jq -c '.bones[] | select(.adr=="ADR-9") | .touch' "$S"
t_assert_eq "[]" "$T_OUT" "no-touch bone's touch is []"

# --- Final review finding 3: touch_check must distinguish "clean" from "could
# not check". Both were rc 1 with no stdout and no stderr — byte-identical — and
# every documented call site is `if oss touch_check …; then HIT; else CLEAN; fi`,
# so an unreadable state silently classified the spine as `flesh`, the permissive
# class. The judge failed OPEN. rc 2 (usage, the established code in these libs)
# now means inconclusive; rc 0 = matched and rc 1 = clean are unchanged — that
# inversion is deliberate and every caller depends on it.
t_capture oss_reg_touch_check "$S"
t_assert_rc 2 "zero paths is rc 2 (usage), not rc 1 (clean)"
t_assert_contains "$T_OUT" "at least one path" "zero-path usage error names the problem"

printf 'THIS IS NOT VALID JSON\n' > "$TMP/corrupt.json"
t_capture oss_reg_touch_check "$TMP/corrupt.json" src/domain/dsl/compile.rs
t_assert_rc 2 "corrupt state is rc 2 (could not check), not rc 1 (clean)"
t_assert_contains "$T_OUT" "cannot read" "unreadable state says so instead of answering clean"

t_capture oss_reg_touch_check "$TMP/nonexistent.json" src/domain/dsl/compile.rs
t_assert_rc 2 "nonexistent state file is rc 2, not rc 1"

jq 'del(.bones)' "$S" > "$TMP/nobones.json"
t_capture oss_reg_touch_check "$TMP/nobones.json" src/domain/dsl/compile.rs
t_assert_rc 2 "state missing .bones is rc 2, not rc 1"

jq 'del(.risk_gates)' "$S" > "$TMP/nogates.json"
t_capture oss_reg_touch_check "$TMP/nogates.json" src/domain/dsl/compile.rs
t_assert_rc 2 "state missing .risk_gates is rc 2, not rc 1"

# ...and the tightening must NOT turn a legitimately empty registry into
# "inconclusive": a fresh project with no bones and no gates is genuinely CLEAN.
T5="$(mktemp -d)"; S5="$T5/state.json"
oss_state_init "$S5" reg-empty >/dev/null
t_capture oss_reg_touch_check "$S5" src/domain/dsl/compile.rs
t_assert_rc 1 "empty-but-valid registries are CLEAN (rc 1), not inconclusive"
rm -rf "$T5"


# --- #340: the CSV grammar — bare "," separates; "\," is a literal comma ----
# The pilot defect: a phrase control split into fragments that no supported
# path could repair (append-only journal, no set verb). These pin the escape
# round-trip for BOTH verbs (gate controls, bone/gate touch globs) and the
# corrective-append repair verb.
t_capture _oss_csv_to_json "paper env,audit trail: record image\, mounts\, egress,kill switch"
t_assert_eq '[
  "paper env",
  "audit trail: record image, mounts, egress",
  "kill switch"
]' "$T_OUT" "escaped commas keep one phrase as ONE control"
t_capture _oss_csv_to_json "src/{exec\,api}/**,src/broker/**"
t_assert_eq '[
  "src/{exec,api}/**",
  "src/broker/**"
]' "$T_OUT" "brace-glob comma written through the escape round-trips to the literal glob"
t_capture _oss_csv_to_json "a\, b,c ,d\,"
t_assert_eq '[
  "a, b",
  "c",
  "d,"
]' "$T_OUT" "trim happens around restored commas, not inside them"
t_capture _oss_csv_to_json "plain\\path\,still-one,x"
t_assert_eq '[
  "plain\\path,still-one",
  "x"
]' "$T_OUT" "a backslash NOT before a comma passes through untouched"

t_capture oss_reg_add_risk_gate "$S" phrase-gate "src/exec/**" "paper env,audit trail: record image\, mounts,kill switch"
t_assert_rc 0 "gate with an escaped phrase control added"
t_capture jq -c '.risk_gates[] | select(.name=="phrase-gate") | .controls' "$S"
t_assert_eq '["paper env","audit trail: record image, mounts","kill switch"]' "$T_OUT" "minted controls hold the phrase whole"

# Corrective append: repair, not history edit — replay stays authoritative.
t_capture oss_reg_set_risk_gate_controls "$S" phrase-gate "paper env,human confirm,audit trail: record image\, mounts\, egress,kill switch"
t_assert_rc 0 "set_controls appends the correction"
t_capture jq -c '.risk_gates[] | select(.name=="phrase-gate") | .controls' "$S"
t_assert_eq '["paper env","human confirm","audit trail: record image, mounts, egress","kill switch"]' "$T_OUT" "controls replaced through the verb"
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay reproduces the corrected state — the journal is authoritative"
t_capture _oss_csv_to_json "$(printf 'a\357\200\200b,c')"
t_assert_rc 2 "a raw private-use codepoint in input refuses (fail-closed)"
t_assert_contains "$T_OUT" "private-use codepoint" "the refusal names the codepoint family"
MUT_BEFORE="$(jq '.mutations | length' "$S")"
t_capture oss_reg_add_risk_gate "$S" pua-gate "src/**" "$(printf 'paper env\357\200\200x')"
t_assert_rc 2 "private-use through the VERB refuses cleanly (no jq noise, rc 2)"
t_capture jq '.risk_gates | map(select(.name=="pua-gate")) | length' "$S"
t_assert_eq "0" "$T_OUT" "the refused gate minted NO mutation"
t_capture oss_reg_set_risk_gate_controls "$S" phrase-gate "$(printf 'a\357\200\200b')"
t_assert_rc 2 "set_controls propagates the refusal rc too"
t_capture oss_reg_add_bone "$S" ADR-78 "pua bone" "$(printf 'src/\357\200\200**')" ""
t_assert_rc 2 "bone_add propagates the refusal rc too"
t_capture jq '.mutations | length' "$S"
t_assert_eq "$MUT_BEFORE" "$T_OUT" "every refusal above left the JOURNAL unchanged - rc 2 after a silent append reads identical from the pass count"
t_capture oss_reg_set_risk_gate_controls "$TMP/nonexistent-state.json" g1 "x"
t_assert_rc 1 "stateless project answers the init message, not a raw jq error"
t_assert_contains "$T_OUT" "oss init" "the message names the remedy verb"
t_capture oss_reg_set_risk_gate_controls "$S" no-such-gate "x"
t_assert_rc 7 "unknown gate name refuses"
t_assert_contains "$T_OUT" "unknown risk gate" "the unknown-name refusal names the gate"
# The duplicate row is built with the RAW op now, because the add rail refuses to
# mint one - and that is a STRONGER fixture than the verb was: it proves the set
# verbs refuse a duplicate that arrived through a path no shipped verb can create
# any more (a journal written by an older build). The check-to-append race is no
# longer such a path either: the add rails run INSIDE the mutation lock, which
# the "#305 item 1, the atomic half" rows above pin.
oss_state_mutate "$S" add_risk_gate \
  "$(jq -n --arg ts "$(_oss_now)" '{name:"phrase-gate",touch:["src/**"],controls:["dup"],at:$ts}')" >/dev/null
t_capture oss_reg_set_risk_gate_controls "$S" phrase-gate "x"
t_assert_rc 7 "duplicate gate names refuse rather than guess"
t_assert_contains "$T_OUT" "#305" "the duplicate refusal names the issue"
# #525's byte-identity claim, PINNED, because nothing pinned it and it drifted:
# `read-plural` and `count-noun` are separate parameters for exactly this - the
# read messages say "risk gates" while the duplicate message said "gates", so
# collapsing the two labels silently reworded both gate verbs' duplicate refusal.
# The whole clause is asserted, not just "#305", so a future reword goes RED.
t_assert_contains "$T_OUT" "matches 2 gates - duplicate names" "...with the count-noun the extraction promised to keep byte-identical"

# bone_add shares the splitter: a brace-glob touch entry stays one entry.
t_capture oss_reg_add_bone "$S" ADR-77 "brace touch" "src/{exec\,api}/**" ""
t_assert_rc 0 "bone with brace-glob touch added"
t_capture jq -c '.bones[] | select(.adr=="ADR-77") | .touch' "$S"
t_assert_eq '["src/{exec,api}/**"]' "$T_OUT" "bone touch holds the literal brace glob"

# --- 1.11.0: re-pointing a touch surface (#469/#369/#411/#305) -------------
# bone_add and risk_gate_add set a touch surface once. When code moves (into a
# packages/ tree, say) the registered globs match nothing and touch_check goes
# silently CLEAN on every affected bone and gate - reclassification and the
# release-close docs trigger stop firing with no error. The repair is a
# corrective append, like set_controls (#340): replay stays authoritative.
# The op names and payload keys are a compatibility contract - live journals
# already carry set_bone_touch {adr,touch} and set_risk_gate_touch {name,touch}.
ST="$TMP/touch.json"
oss_state_init "$ST" touch-demo >/dev/null
oss_reg_add_bone "$ST" ADR-0003 "silver layer" "src/silver/**,src/ingestion/**" "" >/dev/null
oss_reg_add_risk_gate "$ST" gold-correctness "src/gold/**" "golden-set" >/dev/null
t_capture oss_reg_touch_check "$ST" packages/ma/silver/load.py packages/ma/gold/build.py
t_assert_rc 1 "setup: code moved under packages/ matches no registered glob - the silent-clean defect"

N0="$(jq '.mutations | length' "$ST")"
t_capture oss_reg_set_bone_touch "$ST" ADR-0003 "packages/ma/silver/**,packages/ma/ingestion/**"
t_assert_rc 0 "bone_set_touch appends the correction"
t_capture jq -c '.bones[] | select(.adr=="ADR-0003") | .touch' "$ST"
t_assert_eq '["packages/ma/silver/**","packages/ma/ingestion/**"]' "$T_OUT" "the bone's touch surface is replaced, not extended"
t_capture jq -c '.mutations[-1] | [.op, .payload]' "$ST"
t_assert_eq '["set_bone_touch",{"adr":"ADR-0003","touch":["packages/ma/silver/**","packages/ma/ingestion/**"]}]' "$T_OUT" "journaled as set_bone_touch with payload exactly {adr,touch}"
t_capture oss_reg_touch_check "$ST" packages/ma/silver/load.py
t_assert_rc 0 "touch_check hits the new glob"
t_assert_contains "$T_OUT" "bone ADR-0003" "...and names the re-pointed bone"
t_capture oss_reg_touch_check "$ST" src/silver/load.py
t_assert_rc 1 "touch_check is clean on the old glob - it was replaced"

t_capture oss_reg_set_risk_gate_touch "$ST" gold-correctness "packages/ma/gold/**,notebooks/gold_build.py"
t_assert_rc 0 "risk_gate_set_touch appends the correction"
t_capture jq -c '.risk_gates[] | select(.name=="gold-correctness") | .touch' "$ST"
t_assert_eq '["packages/ma/gold/**","notebooks/gold_build.py"]' "$T_OUT" "the gate's touch surface is replaced"
t_capture jq -c '.risk_gates[] | select(.name=="gold-correctness") | .controls' "$ST"
t_assert_eq '["golden-set"]' "$T_OUT" "the gate's controls are untouched by a touch re-point"
t_capture jq -c '.mutations[-1] | [.op, .payload]' "$ST"
t_assert_eq '["set_risk_gate_touch",{"name":"gold-correctness","touch":["packages/ma/gold/**","notebooks/gold_build.py"]}]' "$T_OUT" "journaled as set_risk_gate_touch with payload exactly {name,touch}"
t_capture oss_reg_touch_check "$ST" packages/ma/gold/build.py
t_assert_rc 0 "touch_check hits the gate's new glob"
t_assert_contains "$T_OUT" "risk_gate gold-correctness" "...and names the re-pointed gate"
t_capture oss_reg_touch_check "$ST" src/gold/build.py
t_assert_rc 1 "touch_check is clean on the gate's old glob"

t_capture jq '.mutations | length' "$ST"
t_assert_eq "$((N0 + 2))" "$T_OUT" "one journaled mutation per accepted call"
t_capture oss_state_replay "$ST"
t_assert_rc 0 "replay reproduces the re-pointed state - the journal is authoritative"

# Refusals. None may journal: rc 2 after a silent append reads identical from
# the pass count, so the journal length is re-checked after all of them.
N1="$(jq '.mutations | length' "$ST")"
for v in oss_reg_set_bone_touch oss_reg_set_risk_gate_touch; do
  t_capture "$v" "$TMP/nonexistent-state.json" x "src/**"
  t_assert_rc 1 "$v: a stateless project answers the init message"
  t_assert_contains "$T_OUT" "oss init" "$v: the message names the remedy verb"
done
t_capture oss_reg_set_bone_touch "$ST" ADR-0404 "src/**"
t_assert_rc 7 "bone_set_touch: an unknown ADR refuses"
t_assert_contains "$T_OUT" "unknown bone 'ADR-0404'" "...and names the bone"
t_capture oss_reg_set_risk_gate_touch "$ST" no-such-gate "src/**"
t_assert_rc 7 "risk_gate_set_touch: an unknown gate refuses"
t_assert_contains "$T_OUT" "unknown risk gate 'no-such-gate'" "...and names the gate"
# An empty touch list is refused: [] makes touch_check clean on every path,
# forever - the very defect this verb exists to repair. bone_add still admits
# an empty surface (a bone with none is legitimate); a RE-POINT to nothing is
# not a repair. Whitespace-only and comma-only lists collapse to [] in the
# splitter, so they are the same case.
for csv in "" "   " " , ,"; do
  t_capture oss_reg_set_bone_touch "$ST" ADR-0003 "$csv"
  t_assert_rc 2 "bone_set_touch refuses an empty touch list ('$csv')"
  t_assert_contains "$T_OUT" "at least one glob" "...and says what it needs ('$csv')"
  t_capture oss_reg_set_risk_gate_touch "$ST" gold-correctness "$csv"
  t_assert_rc 2 "risk_gate_set_touch refuses an empty touch list ('$csv')"
  t_assert_contains "$T_OUT" "at least one glob" "...and says what it needs ('$csv')"
done
# ADJACENT CONTROL for that guard (Codex P2 and the GLM seat, round 1 on
# PR #520). The loop above pins SPACE-only emptiness - which the old
# `length > 0` form already caught, so it proves nothing about the loosening.
# The splitter trims literal spaces only, so a tab-, CR-, VT- or NBSP-only
# entry SURVIVES as a "glob" that can never match a real path, reproducing the
# exact silent-clean defect the verb exists to repair (measured: it journaled
# `["\t"]` at rc 0 and touch_check went clean). These rows are what goes RED
# under the array-length form.
for csv in "$(printf '\t')" "$(printf '\r')" "$(printf '\v')" "$(printf '\xc2\xa0')" "$(printf '　')"; do
  t_capture oss_reg_set_bone_touch "$ST" ADR-0003 "$csv"
  t_assert_rc 2 "bone_set_touch refuses a blank-lookalike list (non-space whitespace, $(printf '%s' "$csv" | od -An -tx1 | tr -d ' '))"
  t_assert_contains "$T_OUT" "at least one glob" "...and says what it needs"
  t_capture oss_reg_set_risk_gate_touch "$ST" gold-correctness "$csv"
  t_assert_rc 2 "risk_gate_set_touch refuses a blank-lookalike list (non-space whitespace, $(printf '%s' "$csv" | od -An -tx1 | tr -d ' '))"
  t_assert_contains "$T_OUT" "at least one glob" "...and says what it needs"
done
# #530: a REAL glob carrying one non-space whitespace character passes the blank
# guard above - that guard only requires SOME entry with a non-whitespace
# character, and the splitter trims literal spaces only. Measured on 602565f:
# `bone_set_touch ADR-0003 "$(printf 'src/silver/**\r')"` returned rc 0,
# journaled a CR-terminated glob, and touch_check went CLEAN on the very path the
# re-point was meant to cover - the defect these verbs exist to repair, entered
# through their own argument handling. The realistic vector is a csv composed
# from a CRLF file through `while IFS= read -r` (strips \n, keeps \r).
for csv in "$(printf 'src/silver/**\r')" "$(printf 'src/silver/**\v')" "$(printf '\tsrc/silver/**')" "$(printf 'src/silver/**\xc2\xa0')" "$(printf 'src/silver/**　')"; do
  _hex="$(printf '%s' "$csv" | od -An -tx1 | tr -d ' ')"
  t_capture oss_reg_set_bone_touch "$ST" ADR-0003 "$csv"
  t_assert_rc 2 "bone_set_touch refuses an entry with surrounding whitespace ($_hex)"
  t_assert_contains "$T_OUT" "leading or trailing whitespace" "...and says what is wrong with the entry ($_hex)"
  t_capture oss_reg_set_risk_gate_touch "$ST" gold-correctness "$csv"
  t_assert_rc 2 "risk_gate_set_touch refuses it too ($_hex)"
  t_assert_contains "$T_OUT" "leading or trailing whitespace" "...with the same diagnosis ($_hex)"
done
# The message NAMES the offending entry, and renders it escaped (@json), because
# a CR on a terminal is invisible - an operator told only "trailing whitespace"
# cannot find which entry to fix.
t_capture oss_reg_set_bone_touch "$ST" ADR-0003 "$(printf 'src/silver/**\r')"
t_assert_contains "$T_OUT" 'src/silver/**\r' "...and names the entry with its whitespace escaped, not literally"
t_capture jq -c '.bones[] | select(.adr=="ADR-0003") | .touch' "$ST"
t_assert_eq '["packages/ma/silver/**","packages/ma/ingestion/**"]' "$T_OUT" "...and the refused call left the accepted surface in place"
# The OTHER input the splitter mishandles: jq -R is LINE-oriented, so a csv
# wrapped over two lines emits TWO JSON values and --argjson cannot parse them.
# Fail-closed either way, but the diagnostic must not say "empty" - that is a
# false cause, and an agent following its remedy retries and stays stuck.
t_capture oss_reg_set_bone_touch "$ST" ADR-0003 "$(printf 'src/a/**\nsrc/b/**')"
t_assert_rc 2 "bone_set_touch refuses a two-line touch-csv"
t_assert_contains "$T_OUT" "not one list" "...and reports two lists, not an empty one"
t_capture oss_reg_set_risk_gate_touch "$ST" gold-correctness "$(printf 'src/a/**\nsrc/b/**')"
t_assert_rc 2 "risk_gate_set_touch refuses a two-line touch-csv"
t_assert_contains "$T_OUT" "not one list" "...and reports two lists, not an empty one"
t_capture oss_reg_set_bone_touch "$ST" ADR-0003 "$(printf 'src/\357\200\200**')"
t_assert_rc 2 "bone_set_touch propagates the private-use refusal"
t_capture oss_reg_set_risk_gate_touch "$ST" gold-correctness "$(printf 'src/\357\200\200**')"
t_assert_rc 2 "risk_gate_set_touch propagates the private-use refusal"
printf '{not json' > "$TMP/touch-corrupt.json"
t_capture oss_reg_set_bone_touch "$TMP/touch-corrupt.json" ADR-0003 "src/**"
t_assert_rc 2 "bone_set_touch: an unreadable state is rc 2, not a raw jq error"
t_capture oss_reg_set_risk_gate_touch "$TMP/touch-corrupt.json" gold-correctness "src/**"
t_assert_rc 2 "risk_gate_set_touch: an unreadable state is rc 2, not a raw jq error"
# #525: the ladder's `2>/dev/null` is a LEARNED fix, not cosmetic noise
# suppression - it is what keeps a corrupt state's refusal OURS. Without it jq's
# raw parse error lands in the same captured output as the "cannot read" line,
# and the operator (or an agent) reading the first line sees a jq failure
# instead of the remedy. The arm had no assertion before this extraction, which
# is exactly the "line a fourth hand-copy drops" the issue names - so it is
# pinned here, on all three verbs that share the ladder now.
for _v in oss_reg_set_bone_touch oss_reg_set_risk_gate_touch oss_reg_set_risk_gate_controls; do
  case "$_v" in
    oss_reg_set_bone_touch)         _a="ADR-0003";         _msg="cannot read bones" ;;
    oss_reg_set_risk_gate_touch)    _a="gold-correctness"; _msg="cannot read risk gates" ;;
    oss_reg_set_risk_gate_controls) _a="phrase-gate";      _msg="cannot read risk gates" ;;
  esac
  t_capture "$_v" "$TMP/touch-corrupt.json" "$_a" "src/**"
  t_assert_rc 2 "$_v: a corrupt state refuses at rc 2"
  t_assert_contains "$T_OUT" "$_msg" "$_v: the refusal is the verb's own message"
  case "$T_OUT" in
    *"parse error"*|*"jq: error"*)
      T_FAIL=$((T_FAIL+1)); echo "FAIL: $_v leaks jq's raw error into the refusal - the ladder's 2>/dev/null routing is gone" ;;
    *) T_PASS=$((T_PASS+1)) ;;
  esac
done
t_capture jq '.mutations | length' "$ST"
t_assert_eq "$N1" "$T_OUT" "every refusal above left the journal unchanged"
# ADJACENT CONTROL for #530's per-entry guard: an INTERIOR space is not
# surrounding whitespace - a path can contain one, so refusing it would be a
# guard stricter than the operation it protects. This row is what goes RED if the
# check is written as "any whitespace in the entry" instead of "leading or
# trailing".
t_capture oss_reg_set_bone_touch "$ST" ADR-0003 "src/my file.py,src/ok/**"
t_assert_rc 0 "an entry with an interior space is still accepted"
t_capture jq -c '.bones[] | select(.adr=="ADR-0003") | .touch' "$ST"
t_assert_eq '["src/my file.py","src/ok/**"]' "$T_OUT" "...and the interior space survives into the journaled surface"
t_capture oss_reg_set_bone_touch "$ST" ADR-0003 "packages/ma/silver/**,packages/ma/ingestion/**"
t_assert_rc 0 "...and the surface is re-pointable again afterwards"
# #524: set_controls took an empty list at rc 0 and journaled controls: [] - the
# gate's downstream checklist silently emptied for every later spine that touches
# its surface. The 1.11.0 touch verbs refuse a list with no glob in it; the guard
# sat one function away and did not cover its sibling. risk-gates.md §6: a gate
# with no controls "is a worry, not a gate".
N2="$(jq '.mutations | length' "$ST")"
t_capture oss_reg_set_risk_gate_controls "$ST" gold-correctness ""
t_assert_rc 2 "set_controls refuses an empty list at rc 2"
t_assert_contains "$T_OUT" "at least one control" "...and says what a gate needs"
t_assert_contains "$T_OUT" "risk-gates.md" "...and cites the rule it protects"
for csv in "   " " , ," "$(printf '\t')" "$(printf '\xc2\xa0')"; do
  t_capture oss_reg_set_risk_gate_controls "$ST" gold-correctness "$csv"
  t_assert_rc 2 "set_controls refuses a blank-lookalike list ($(printf '%s' "$csv" | od -An -tx1 | tr -d ' '))"
  t_assert_contains "$T_OUT" "at least one control" "...and names controls, not globs"
done
# The shared guard gives set_controls the per-entry refusal too (#530's arm, same
# helper): a control phrase carrying a trailing CR is not the phrase the caller
# wrote, and the CSV grammar exists to make that unambiguous.
t_capture oss_reg_set_risk_gate_controls "$ST" gold-correctness "$(printf 'ctl-one\r')"
t_assert_rc 2 "set_controls refuses an entry with surrounding whitespace"
t_assert_contains "$T_OUT" "leading or trailing whitespace" "...and diagnoses the entry"
t_capture jq '.mutations | length' "$ST"
t_assert_eq "$N2" "$T_OUT" "every set_controls refusal above left the journal unchanged"
# ADJACENT CONTROL: replace semantics are untouched - a non-empty list still
# replaces wholesale - and the noun in the message is what tells the two verbs'
# refusals apart (a controls refusal must not say "at least one glob").
t_capture oss_reg_set_risk_gate_controls "$ST" gold-correctness "ctl-a,ctl-b"
t_assert_rc 0 "a non-empty controls list still replaces wholesale"
t_capture jq -c '.risk_gates[] | select(.name=="gold-correctness") | .controls' "$ST"
t_assert_eq '["ctl-a","ctl-b"]' "$T_OUT" "...and lands in the journal"
# Duplicates (#305 shape) refuse rather than guess which entry to re-point. Both
# rows are minted with the RAW op: the add rails (added with #305 item 1) refuse
# to create a duplicate, so a fixture built through the verb would be impossible -
# and this way the set verbs are proven against a duplicate that only an older
# journal can produce (the add rails are now in-lock, so not even a
# check-to-append race mints one).
oss_state_mutate "$ST" add_bone \
  "$(jq -n --arg ts "$(_oss_now)" '{adr:"ADR-0003",title:"silver layer, minted twice",touch:["src/x/**"],revisit_trigger:null,at:$ts}')" >/dev/null
oss_state_mutate "$ST" add_risk_gate \
  "$(jq -n --arg ts "$(_oss_now)" '{name:"gold-correctness",touch:["src/y/**"],controls:["dup"],at:$ts}')" >/dev/null
t_capture oss_reg_set_bone_touch "$ST" ADR-0003 "src/**"
t_assert_rc 7 "bone_set_touch: a duplicate ADR refuses"
t_assert_contains "$T_OUT" "#305" "...and names the issue"
t_capture oss_reg_set_risk_gate_touch "$ST" gold-correctness "src/**"
t_assert_rc 7 "risk_gate_set_touch: a duplicate gate name refuses"
t_assert_contains "$T_OUT" "#305" "...and names the issue"

# The dispatcher path: bin/oss runs `set -euo pipefail`, which the sourced
# calls above do not. A verb that works sourced can still die there.
SD="$TMP/touch-dispatch.json"
oss_state_init "$SD" touch-dispatch >/dev/null
oss_reg_add_bone "$SD" ADR-0003 "silver layer" "src/silver/**" "" >/dev/null
oss_reg_add_risk_gate "$SD" gold-correctness "src/gold/**" "golden-set" >/dev/null
t_capture env OSS_STATE_FILE="$SD" bash "$OSS" bone_set_touch ADR-0003 "packages/ma/silver/**"
t_assert_rc 0 "oss bone_set_touch works through the strict dispatcher"
t_capture env OSS_STATE_FILE="$SD" bash "$OSS" risk_gate_set_touch gold-correctness "packages/ma/gold/**"
t_assert_rc 0 "oss risk_gate_set_touch works through the strict dispatcher"
t_capture jq -c '[.bones[0].touch, .risk_gates[0].touch]' "$SD"
t_assert_eq '[["packages/ma/silver/**"],["packages/ma/gold/**"]]' "$T_OUT" "both re-points landed through the dispatcher"
t_capture env OSS_STATE_FILE="$SD" bash "$OSS" bone_set_touch ADR-0003 ""
t_assert_rc 2 "the dispatcher returns the lib's rc 2 on an empty list, not an errexit abort"
t_assert_contains "$T_OUT" "at least one glob" "...and it is the lib's refusal, not an unknown-verb usage error"
t_capture env OSS_STATE_FILE="$SD" bash "$OSS" risk_gate_set_touch no-such-gate "src/**"
t_assert_rc 7 "the dispatcher returns the lib's rc 7 on an unknown gate"

# --- 1.22.0 (#305 item 2): a bone's title and revisit trigger amend -----------
# Corrective appends like bone_set_touch: pre-lock single-row read, first()-
# targeted apply, exact arity. The op names and payload keys are a compatibility
# contract from this release on, pinned here exactly as set_bone_touch is.
SB="$TMP/bone-amend.json"
oss_state_init "$SB" bone-amend >/dev/null
oss_reg_add_bone "$SB" ADR-0005 "event store" "src/store/**" "" >/dev/null
oss_reg_add_bone "$SB" ADR-0006 "neighbour" "src/n/**" "when n grows" >/dev/null
NB0="$(jq '.mutations | length' "$SB")"
B_BEFORE="$(jq -c '.bones[] | select(.adr=="ADR-0005") | del(.title)' "$SB")"
t_capture env OSS_STATE_FILE="$SB" bash "$OSS" bone_set_title ADR-0005 "event store schema"
t_assert_rc 0 "305: bone_set_title accepts"
t_assert_eq "event store schema" "$(jq -r '.bones[] | select(.adr=="ADR-0005") | .title' "$SB")" "305: ...and the title changed"
t_assert_eq "$B_BEFORE" "$(jq -c '.bones[] | select(.adr=="ADR-0005") | del(.title)' "$SB")" "305: ...and nothing else on the bone did"
t_assert_eq '["set_bone_title",{"adr":"ADR-0005","title":"event store schema"}]' "$(jq -c '.mutations[-1] | [.op, .payload]' "$SB")" "305: journaled as set_bone_title with payload exactly {adr,title}"
t_capture env OSS_STATE_FILE="$SB" bash "$OSS" bone_set_revisit ADR-0005 "when a second writer appears"
t_assert_rc 0 "305: bone_set_revisit accepts"
t_assert_eq "when a second writer appears" "$(jq -r '.bones[] | select(.adr=="ADR-0005") | .revisit_trigger' "$SB")" "305: ...and the trigger changed"
t_assert_eq '["set_bone_revisit",{"adr":"ADR-0005","revisit_trigger":"when a second writer appears"}]' "$(jq -c '.mutations[-1] | [.op, .payload]' "$SB")" "305: journaled as set_bone_revisit with payload exactly {adr,revisit_trigger}"
t_capture env OSS_STATE_FILE="$SB" bash "$OSS" bone_set_revisit ADR-0005 ""
t_assert_rc 0 "305: an empty trigger is accepted"
t_assert_eq "null" "$(jq -c '.bones[] | select(.adr=="ADR-0005") | .revisit_trigger' "$SB")" "305: ...and clears to null, as bone_add records an absent one"
t_assert_eq '["set_bone_revisit",{"adr":"ADR-0005","revisit_trigger":null}]' "$(jq -c '.mutations[-1] | [.op, .payload]' "$SB")" "305: ...journaled with a null trigger"
t_assert_eq '"neighbour","when n grows"' "$(jq -r '.bones[] | select(.adr=="ADR-0006") | [.title, .revisit_trigger] | map(tojson) | join(",")' "$SB")" "305: the neighbouring bone is untouched"
t_assert_eq "$((NB0 + 3))" "$(jq '.mutations | length' "$SB")" "305: one journaled mutation per accepted call"
t_capture oss_state_replay "$SB"
t_assert_rc 0 "305: replay reproduces the amended bones"
NB1="$(jq '.mutations | length' "$SB")"
t_capture env OSS_STATE_FILE="$SB" bash "$OSS" bone_set_title ADR-0404 "x"
t_assert_rc 7 "305: bone_set_title refuses an unknown ADR"
t_assert_contains "$T_OUT" "unknown bone 'ADR-0404'" "305: ...and names the bone"
t_capture env OSS_STATE_FILE="$SB" bash "$OSS" bone_set_revisit ADR-0404 "x"
t_assert_rc 7 "305: bone_set_revisit refuses an unknown ADR"
t_capture env OSS_STATE_FILE="$SB" bash "$OSS" bone_set_title ADR-0005 event store
t_assert_rc 2 "305: bone_set_title refuses an unquoted multi-word title instead of truncating it"
t_capture env OSS_STATE_FILE="$SB" bash "$OSS" bone_set_revisit ADR-0005
t_assert_rc 2 "305: bone_set_revisit refuses a missing trigger (clear it with \"\")"
t_assert_eq "$NB1" "$(jq '.mutations | length' "$SB")" "305: none of the refusals journaled"

# --- #631: feature_add records the intake issue on the feature entry ---------
# Operator rulings of 2026-10-12 and 2026-10-15: an optional 5th argument, stored
# as payload key `issue` (a JSON number). `N` and `#N` are accepted and normalised
# to N; anything else is refused at rc 2 before any write. Empty, or not given, is
# absent - no `issue` key at all - so a journal written before 1.23.0 replays
# byte-identical.
TF="$(mktemp -d)"; SF="$TF/state.json"
oss_state_init "$SF" intake-demo >/dev/null
t_capture oss_reg_add_feature "$SF" "export csv" "export a run as csv" flesh intake 42
t_assert_rc 0 "631: feature_add accepts an issue number"
t_assert_eq '["add_feature",{"name":"export csv","value":"export a run as csv","class_guess":"flesh","source":"intake","issue":42}]' \
  "$(jq -c '.mutations[-1] | [.op, (.payload | del(.at))]' "$SF")" "631: journaled as add_feature with issue as a number"
t_capture oss_reg_add_feature "$SF" "import csv" "import a run" flesh intake "#7"
t_assert_rc 0 "631: feature_add accepts #N"
t_assert_eq "7" "$(jq -c '.feature_map[-1].issue' "$SF")" "631: #N is normalised to N"
t_capture oss_reg_add_feature "$SF" "plain" "no issue" flesh journey-map
t_assert_rc 0 "631: feature_add without an issue still works"
t_assert_eq "false" "$(jq -c '.feature_map[-1] | has("issue")' "$SF")" "631: no issue argument leaves no issue key"
t_capture oss_reg_add_feature "$SF" "plain2" "empty issue" flesh journey-map ""
t_assert_rc 0 "631: an empty issue argument is accepted as absent"
t_assert_eq "false" "$(jq -c '.feature_map[-1] | has("issue")' "$SF")" "631: an empty issue leaves no issue key"
NF1="$(jq '.mutations | length' "$SF")"
for bad in 0 -3 05 abc 4a "#" "##4" "4 5" " 4" "1.5"; do
  t_capture oss_reg_add_feature "$SF" "bad" "bad issue" flesh intake "$bad"
  t_assert_rc 2 "631: feature_add refuses issue '$bad' at rc 2"
done
t_assert_contains "$T_OUT" "issue" "631: the refusal names the issue argument"
t_assert_eq "$NF1" "$(jq '.mutations | length' "$SF")" "631: no refused issue journaled"
# Codex round 1 on PR #821: an issue on a non-intake entry would send spine
# planning to an unrelated request. Only source `intake` takes one; the empty
# issue on a journey-map entry above stays accepted (the adjacent control).
NF2="$(jq '.mutations | length' "$SF")"
t_capture oss_reg_add_feature "$SF" "notintake" "a journey item" flesh journey-map 123
t_assert_rc 2 "631: feature_add refuses an issue on a non-intake source"
t_assert_contains "$T_OUT" "intake" "631: the non-intake refusal names the intake source"
t_assert_eq "$NF2" "$(jq '.mutations | length' "$SF")" "631: no non-intake issue journaled"
# The dispatcher path runs under set -euo pipefail; the same contract holds there.
t_capture env OSS_STATE_FILE="$SF" bash "$OSS" feature_add "cli" "a cli" flesh intake "#12"
t_assert_rc 0 "631: oss feature_add takes the issue as its 5th argument"
t_assert_eq "12" "$(jq -c '.feature_map[-1].issue' "$SF")" "631: the dispatcher records it normalised"
t_capture env OSS_STATE_FILE="$SF" bash "$OSS" feature_add "cli2" "a cli" flesh intake abc
t_assert_rc 2 "631: oss feature_add refuses a bad issue at rc 2"
t_capture env OSS_STATE_FILE="$SF" bash "$OSS" feature_add "cli4" "a cli" flesh journey-map 9
t_assert_rc 2 "631: oss feature_add refuses an issue on a non-intake source"
t_capture env OSS_STATE_FILE="$SF" bash "$OSS" feature_add "cli3" "a cli" flesh intake 3 extra
t_assert_rc 2 "631: oss feature_add refuses a 6th argument rather than dropping it"
t_capture env OSS_STATE_FILE="$SF" bash "$OSS" feature_list
t_assert_eq "[42,7,null,null,12]" "$(printf '%s' "$T_OUT" | jq -c '[.[].issue]')" "631: feature_list shows the issue on each entry"
t_capture oss_state_replay "$SF"
t_assert_rc 0 "631: replay is clean with issue-bearing and issue-less entries"
# Upgrade input class: a journal written by 1.22.0 - add_feature with no issue key.
TL="$(mktemp -d)"; SL="$TL/state.json"
oss_state_init "$SL" legacy-demo >/dev/null
oss_state_mutate "$SL" add_feature '{"name":"legacy","value":"v","class_guess":"flesh","source":"intake","at":"2026-01-01T00:00:00Z"}' >/dev/null
t_capture oss_state_replay "$SL"
t_assert_rc 0 "631: a pre-1.23.0 add_feature (no issue key) replays clean"
t_assert_eq "false" "$(jq -c '.feature_map[0] | has("issue")' "$SL")" "631: ...and gains no issue key"
rm -rf "$TF" "$TL"

# #872: no topology on the walk-up path is "could not check". The resolver's refusal
# is rc 1, which is touch_check's "clean" and the expired gates' "blocking".
mkdir -p "$TMP/no-topology"
for verb in "touch_check src/x.rs" "expired_fakes r0" "expired_quarantines r0" "expired_deferrals r0"; do
  # shellcheck disable=SC2086
  t_capture env -u OSS_STATE_FILE bash -c 'cd "$1" && shift && exec bash "$@"' _ "$TMP/no-topology" "$OSS" $verb
  t_assert_rc 2 "#872: $verb with no topology is rc 2, could not check"
  t_assert_contains "$T_OUT" "topology declaration" "#872: $verb still prints the refusal"
done
printf '{"bones":[],"risk_gates":[]}\n' > "$TMP/empty-reg.json"
t_capture env OSS_STATE_FILE="$TMP/empty-reg.json" bash "$OSS" touch_check src/x.rs
t_assert_rc 1 "#872 control: a readable state with no match is still rc 1, clean"

rm -rf "$TMP"
t_summary
