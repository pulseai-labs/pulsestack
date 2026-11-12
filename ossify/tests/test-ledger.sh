#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/manifest.sh"
. "$HERE/../lib/ledger.sh"; . "$HERE/../lib/entities.sh"; . "$HERE/../lib/registries.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
# #272/#310 Task 5: oss_ledger_add_patch's omitted-repo-key default now routes
# through _oss_default_repo_key (manifest.sh, sourced above), which needs a
# discoverable manifest even for the 2-arg calls already in this file - same
# fixture shape as test-entities.sh's Task 4 fixture. $S is passed explicitly
# throughout this file, so the fixture only needs to be DISCOVERABLE.
mkdir -p "$TMP/.ossify"
cat > "$TMP/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"canonical":{"root":"$TMP/canon"}},"well_known_paths":{}}
JSON
cd "$TMP"
oss_state_init "$S" ledger-demo >/dev/null

# Mint the spine that the demo lines are keyed to. ledger_add_auto/add_user now
# validate the source_spine exists (Codex P2 finding #1) — a demo line against
# a nonexistent spine is silently skipped at close.
oss_entity_add_release "$S" "demo release" "goal" >/dev/null
oss_entity_add_spine "$S" r0 "demo spine" bone canonical >/dev/null

t_capture oss_ledger_add_auto "$S" r0.s1 "backtest CLI smoke" "true" "exit:0" active
t_assert_rc 0 "auto line added"; t_assert_eq "d1" "$T_OUT" "counter-minted id"
t_capture oss_ledger_add_auto "$S" r0.s1 "bad expected" "true" "somehow:fine"
t_assert_rc 2 "invalid expected grammar rejected"

t_capture oss_ledger_add_user "$S" r0.s1 "Type a strategy idea and run a backtest from the chat panel" "results table visible" active
t_assert_rc 0 "user journey line added"; t_assert_eq "d2" "$T_OUT" "second id"
t_capture oss_ledger_add_user "$S" r0.s1 "Inspect the pulse.db schema" "schema visible"
t_assert_rc 2 "inspector phrasing banned"

# Codex P2 finding #1: a demo line keyed to a nonexistent spine journals
# silently and is never exercised at close. Both add_auto and add_user must
# reject an unknown spine with rc 7 before mutating.
t_capture oss_state_read "$S" '.demo_ledger | length'
BEFORE="$T_OUT"
t_capture oss_ledger_add_auto "$S" r9.s99 "phantom" "true" "exit:0"
t_assert_rc 7 "add_auto rejects unknown spine"
t_capture oss_ledger_add_user "$S" r9.s99 "phantom user line" "phantom outcome"
t_assert_rc 7 "add_user rejects unknown spine"
t_capture oss_state_read "$S" '.demo_ledger | length'
t_assert_eq "$BEFORE" "$T_OUT" "no phantom demo line journaled after unknown-spine refusal"

# D1: <by-spine> is now the join key apply_pending matches on, and is validated
# against known spines - this file predates entities.sh and used the free-text
# id "r1.s2"; mint a real release+spine to amend against instead.
t_capture oss_entity_add_release "$S" "amend test" "goal"
t_assert_rc 0 "setup: release minted for the amendment fixture"; REL="$T_OUT"
t_capture oss_entity_add_spine "$S" "$REL" "amending spine" flesh canonical
t_assert_rc 0 "setup: spine minted for the amendment fixture"; SP="$T_OUT"

t_capture oss_ledger_supersede "$S" d1 "$SP" "flow redesigned"
t_assert_rc 0 "supersede ok"
t_capture oss_state_read "$S" '.demo_ledger[0].status'
t_assert_eq "active" "$T_OUT" "status stays ACTIVE until close applies the pending amendment (D1)"
t_capture oss_state_read "$S" '.demo_ledger[0].pending_amendments[0].status'
t_assert_eq "superseded" "$T_OUT" "supersede records a pending amendment (F1: a list entry, not a scalar)"
t_capture oss_state_read "$S" '.demo_ledger[0].pending_amendments[0].by'
t_assert_eq "$SP" "$T_OUT" "...keyed to the planning spine"
t_capture oss_ledger_active_auto "$S"
t_assert_eq "1" "$(printf '%s' "$T_OUT" | jq 'length')" "a pending amendment does not drop the line from the live set"
t_capture oss_ledger_apply_pending "$S" "$SP"
t_assert_rc 0 "apply_pending ok"
t_capture oss_state_read "$S" '.demo_ledger[0].status'; t_assert_eq "superseded" "$T_OUT" "status archived after close applies it"
t_capture oss_state_read "$S" '.demo_ledger[0].pending_amendments'
t_assert_eq "[]" "$T_OUT" "pending amendment consumed by apply"
t_capture oss_ledger_active_auto "$S"
t_assert_eq "[]" "$(printf '%s' "$T_OUT" | jq -c .)" "superseded line not active after close"

# F3: apply_pending against an unknown spine is a reject-before-mutate rc 7,
# not a silent rc-0 no-op (which would let a typo'd close report success while
# applying nothing).
t_capture oss_state_read "$S" '.mutations | length'; MUT_BEFORE="$T_OUT"
t_capture oss_ledger_apply_pending "$S" "r9.s9"
t_assert_rc 7 "apply_pending against an unknown spine is rc 7"
t_capture oss_state_read "$S" '.mutations | length'
t_assert_eq "$MUT_BEFORE" "$T_OUT" "no phantom mutation journaled after unknown-spine refusal"

# F1.3: unplan now takes the spine, and rejects a spine with nothing pending
# on the line (ambiguity a list makes possible that a single slot never had).
t_capture oss_ledger_supersede "$S" d2 "$SP" "second amendment for the unplan test"
t_assert_rc 0 "setup: second pending amendment for the unplan test"
t_capture oss_ledger_unplan "$S" d2 "r9.s9"
t_assert_rc 7 "unplan rejects a spine with no pending amendment on the line"
t_capture oss_ledger_unplan "$S" d2 "$SP"
t_assert_rc 0 "unplan clears the calling spine's own pending amendment"
t_capture oss_state_read "$S" '.demo_ledger[1].pending_amendments'
t_assert_eq "[]" "$T_OUT" "pending amendment cleared"
t_capture oss_ledger_unplan "$S" d999 "$SP"
t_assert_rc 7 "unplan against an unknown line id is rc 7"

# --- F9 / named risk 3: a demo line written before this task (no
# `pending_amendments` key AT ALL - not even a migrated empty []) must survive
# apply_demo_pending BYTE-IDENTICAL when the calling spine has nothing pending
# on it. Hand-built, not `oss_state_init`-derived: a fresh init writes the
# CURRENT shape and proves nothing about an upgrade input. Compared with
# `jq -S -c` (sorted keys) on both sides per the brief's explicit instruction -
# reading the jq is not proof, only a diff on the actual output is.
LEGACY_LINE='{"id":"d1","status":"active","status_reason":null,"status_by":null}'
LEGACY_STATE="$(jq -n --argjson l "$LEGACY_LINE" '{demo_ledger:[$l]}')"
LEGACY_AFTER="$(printf '%s' "$LEGACY_STATE" | _oss_apply_op apply_demo_pending '{"spine":"r0.s1"}')"
IN_SORTED="$(printf '%s' "$LEGACY_STATE" | jq -S -c '.demo_ledger[0]')"
OUT_SORTED="$(printf '%s' "$LEGACY_AFTER" | jq -S -c '.demo_ledger[0]')"
t_assert_eq "$IN_SORTED" "$OUT_SORTED" "a legacy demo line with no pending_amendments key at all survives apply_demo_pending byte-identical"

t_capture oss_ledger_add_patch "$S" abc1234 "bump serde patch version"
t_assert_rc 0 "patch record added"
t_capture oss_state_read "$S" '.patch_records | length'; t_assert_eq "1" "$T_OUT" "patch recorded"
# #272/#310 Task 5: a 2-arg call (repo key omitted) under a one-repo topology
# (this file's $TMP fixture declares only "canonical") stores the sole repo's
# name via _oss_default_repo_key, not a hardcoded literal.
t_capture oss_state_read "$S" '.patch_records[-1].repo'
t_assert_eq "canonical" "$T_OUT" "omitted repo key defaults to the sole declared repo"

# An explicit repo key is stored verbatim.
t_capture oss_ledger_add_patch "$S" deadbeef "text" ui
t_assert_rc 0 "explicit repo key accepted"
t_capture oss_state_read "$S" '.patch_records[-1].repo'
t_assert_eq "ui" "$T_OUT" "explicit repo key is stored on the patch record"

# Under N>1 declared repos, an omitted repo key must refuse (rc 2), never
# silently pick - same fail-safe shape as every other Task 4 default-repo
# site. Separate TMP dir, deliberately not $TMP (which stays single-repo for
# the rest of this file).
PTMP="$(mktemp -d)"
mkdir -p "$PTMP/.ossify"
cat > "$PTMP/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"canonical":{"root":"$PTMP/canon"},"ui":{"root":"$PTMP/ui"}},"well_known_paths":{}}
JSON
PS="$PTMP/state.json"
cd "$PTMP"
oss_state_init "$PS" patch-multi-demo >/dev/null
t_capture oss_ledger_add_patch "$PS" cafef00d "no repo key under N>1"
t_assert_rc 2 "omitted repo key under N>1 declared repos refuses"
t_assert_contains "$T_OUT" "canonical, ui" "refusal lists both declared repos"
t_capture oss_state_read "$PS" '.patch_records | length'
t_assert_eq "0" "$T_OUT" "no phantom patch record journaled after the N>1 refusal"
cd "$TMP"
rm -rf "$PTMP"

# --- #272/#310 Task 5 review fix (Important 2): the whole justification for
# NOT bumping the patch_records schema is that replaying an OLD journal
# reproduces old-shape records untouched and readers absorb the missing
# `repo` as `canonical`. That claim had no committed assertion - only a
# manual check outside the suite. Same LEGACY_LINE / LEGACY_STATE
# byte-identical-survival shape as above, but through the REAL journal +
# oss_state_replay against this file's live $S (not a synthetic
# _oss_apply_op call on an isolated fragment) - replay-through-the-journal is
# the actual mechanism the no-schema-bump decision rests on, so it is the one
# that must be pinned. Injected via oss_state_mutate directly, bypassing
# oss_ledger_add_patch, to simulate exactly what a pre-Task-5 journal entry
# looks like: no `repo` key at all.
LEGACY_PATCH='{"commit":"legacy5150","text":"pre-task5 shape, no repo key","at":"2020-01-01T00:00:00Z"}'
t_capture oss_state_mutate "$S" add_patch_record "$LEGACY_PATCH"
t_assert_rc 0 "setup: legacy-shape patch record journaled"
IN_SORTED="$(printf '%s' "$LEGACY_PATCH" | jq -S -c .)"
BEFORE_SORTED="$(jq -S -c '.patch_records[-1]' "$S")"
t_assert_eq "$IN_SORTED" "$BEFORE_SORTED" "legacy patch record stored with no repo key, exactly as given"
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay stays clean with a legacy no-repo patch record in the journal"
AFTER_SORTED="$(jq -S -c '.patch_records[-1]' "$S")"
t_assert_eq "$IN_SORTED" "$AFTER_SORTED" "a legacy patch record with no repo key at all survives replay byte-identical"

# §5.3 floor guard must not be bypassable by leading whitespace: a leading
# space/tab before inspector phrasing is the same banned phrasing, just padded.
t_capture oss_ledger_add_user "$S" r0.s1 " Open the file" "file contents visible"
t_assert_rc 2 "leading-space inspector phrasing banned"
t_capture oss_ledger_add_user "$S" r0.s1 "$(printf '\tInspect the schema')" "schema visible"
t_assert_rc 2 "leading-tab inspector phrasing banned"
# ...but the trim must not over-reject a legitimate leading-space journey line.
t_capture oss_ledger_add_user "$S" r0.s1 " Type a strategy idea and run a backtest" "results visible" active
t_assert_rc 0 "leading-space legitimate journey line still accepted"

# --- Final review finding 1: the `expected` validator was the glob `exit:[0-9]*`
# = "exit:" + ONE digit + anything. A well-prefixed but malformed operand was
# accepted here, and the runner USED `[ "$rc" -ne "${expected#exit:}" ]` (now the
# fail-closed `! [ -eq ]`, 1.39.0), which exits 2 on the non-numeric operand — the
# enclosing `if` read that as FALSE, so the FAIL branch never ran and the line counted as passed.
# The pre-existing negatives above ("somehow:fine") only probe PREFIX failures;
# these probe the operand, which is where the silent pass lived.
for bad in "exit:0 (tests green)" "exit:0abc" "exit:0 # x" "exit:0|contains:x" "exit:" "exit:1 "; do
  t_capture oss_ledger_add_auto "$S" r0.s1 "malformed operand" "true" "$bad"
  t_assert_rc 2 "malformed exit: operand rejected: '$bad'"
done
# ...and the tightening must not over-reject a well-formed multi-digit code.
t_capture oss_ledger_add_auto "$S" r0.s1 "multi-digit exit code" "true" "exit:127" active
t_assert_rc 0 "well-formed multi-digit exit: operand still accepted"

# --- #770: the combined form exit:<n>+contains:<str> (the demo twin of #747's AC form).
# Split at the FIRST `+contains:` after the digits, so a needle may itself hold `+` or
# `contains:`. The new arm sits BEFORE `exit:*`, which would refuse it as non-digits.
for good in "exit:0+contains:ok" "exit:1+contains:a+contains:b" "exit:127+contains:x" "exit:0+contains:a+contains:" "exit:0+contains:+x" "exit:0+contains:x "; do
  t_capture oss_ledger_add_auto "$S" r0.s1 "combined form" "true" "$good" active
  t_assert_rc 0 "combined exit-and-contains accepted: '$good'"
done
t_capture oss_state_read "$S" '.demo_ledger[-1].expected'
t_assert_eq "exit:0+contains:x " "$T_OUT" "the combined expected is stored verbatim"
# Adjacent controls: each of these must still refuse - the loosening may not widen past the form.
for bad in "exit:+contains:x" "exit:0+contains:" "exit:0x+contains:y" "exit:0 +contains:x" "exit:0+contain:x" "exit:0+contains" "exit:0+Contains:x" "exit:+contains:" "exit:0|contains:x"; do
  t_capture oss_ledger_add_auto "$S" r0.s1 "bad combined form" "true" "$bad" active
  t_assert_rc 2 "malformed combined form rejected: '$bad'"
done
# A contains: needle may itself hold `+exit:0`: that is a plain contains: line, not a malformed combined one.
t_capture oss_ledger_add_auto "$S" r0.s1 "needle with plus" "true" "contains:x+exit:0" active
t_assert_rc 0 "control: contains:x+exit:0 is a plain contains: line"
t_capture oss_ledger_add_auto "$S" r0.s1 "bad" "true" "somehow:fine" active
t_assert_contains "$T_OUT" "exit:<n>+contains:<str>" "the unrecognized-grammar refusal lists the combined form"

L1=d1   # this file uses literal demo-line ids
# Quarantine stays IMMEDIATE (it is a close/doctor-time verb applied when a line
# actually fails, not a planned amendment) and now records WHICH release, so
# §6.1's "fixed or retired by the next release close" has an anchor.
t_capture oss_ledger_quarantine "$S" "$L1" "upstream CI image broken" "r1"
t_assert_rc 0 "quarantine ok"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$L1\")][0].status"
t_assert_eq "quarantined" "$T_OUT" "quarantine applies immediately"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$L1\")][0].quarantined_in_release"
t_assert_eq "r1" "$T_OUT" "quarantine records the release it was raised in"

# --- G2 test 2: anchor preservation. Re-quarantining the SAME line WITHOUT a
# release must not erase the already-recorded one - the unconditional
# pre-F2 write ("r0" -> "") destroyed §6.1's parking-ticket anchor.
t_capture oss_ledger_quarantine "$S" "$L1" "re-examined, still broken"
t_assert_rc 0 "re-quarantine without a release ok"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$L1\")][0].quarantined_in_release"
t_assert_eq "r1" "$T_OUT" "re-quarantining without a release does not erase the original anchor"

# Fake lifecycle: a fake can be replaced or explicitly renewed with a NEW expiry.
t_capture oss_reg_add_fake "$S" "broker" "fake" "no sandbox yet" "the first live order" "r1"
t_capture oss_reg_set_fake_status "$S" "broker" "renewed" "sandbox still unavailable" "r2"
t_assert_rc 0 "fake renew ok"
t_capture oss_state_read "$S" '[.fakes[] | select(.boundary=="broker")][0].expiry_release'
t_assert_eq "r2" "$T_OUT" "renewal moves the expiry"
t_capture oss_reg_set_fake_status "$S" "broker" "bogus" "x"
t_assert_rc 2 "fake status rejects an unknown value"
t_capture oss_reg_set_fake_status "$S" "nosuch" "replaced" "x"
t_assert_rc 7 "fake status on an unknown boundary is rc 7"

# set_fake_status is one of Task 2's four new _oss_apply_op cases and is the
# only one of the four with no replay coverage elsewhere (test-spine-planning.sh
# covers set_demo_line_pending/apply_demo_pending/clear_demo_pending but never
# calls fake_status). Close that gap here.
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay stays clean across set_fake_status (and this file's pending/apply/quarantine ops)"

cd "$HERE"
rm -rf "$TMP"
t_summary
