#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/state.sh"
# G3/G4 build a REAL project (release + spine + bone) to prove restore does not
# eat one. Those entity/registry helpers live outside state.sh, so they must be
# sourced here or the fixture builds nothing and the guard assertions are vacuous.
. "$HERE/../lib/id.sh"
. "$HERE/../lib/entities.sh"
. "$HERE/../lib/registries.sh"
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"; S="$TMP/state.json"

oss_state_init "$S" replay-demo >/dev/null
oss_state_mutate "$S" set_posture '{"posture":"open-core"}'
oss_state_mutate "$S" set_posture '{"posture":"fully-private"}'

t_capture oss_state_replay "$S"
t_assert_rc 0 "replay reproduces live state"

jq '.project.posture = "tampered"' "$S" > "$S.x" && mv "$S.x" "$S"   # out-of-band edit
t_capture oss_state_replay "$S"
t_assert_rc 5 "tamper detected as drift"
t_assert_contains "$T_OUT" "drift" "drift named in output"

# Final review finding 5: the drift message used to end "Run 'oss doctor' and
# repair from journal". doctor is replay's ONLY caller, so that told an operator
# running doctor to run doctor — and no repair/restore/recover verb exists in
# this build's subcommand inventory at all. A remediation string naming a command
# that cannot repair is worse than naming none: the obvious next move becomes
# deleting the state file, which destroys the append-only journal living inside
# it. The message must state only what is true today.
case "$T_OUT" in
  *"repair from journal"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: drift message still points at a repair path that does not exist";;
  *) T_PASS=$((T_PASS+1));;
esac
t_assert_contains "$T_OUT" "oss state_restore" "drift message names the verb that can actually repair it"
t_assert_contains "$T_OUT" "Do NOT delete" "drift message guards the journal against the obvious wrong next move"
t_assert_contains "$T_OUT" "base.json" "drift message names the intact base snapshot the state is still derivable from"

# state_restore: replay detects drift AND can now repair it. The recovered state
# is written through the same temp+rename path every other write uses, under the
# lock - NOT from inside oss_state_replay, which is deliberately lock-free so
# doctor can call it freely.
t_capture oss_state_replay "$S"; t_assert_rc 5 "replay still reports drift before restore"
t_capture oss_state_restore "$S"
t_assert_rc 0 "state_restore repairs a drifted state"
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay is clean after restore"
# A clean replay is NOT evidence that restore worked. Replay re-derives its
# "expected" value from the same `.mutations` array restore just wrote, so a
# restore that discards the journal produces a state replay calls clean:
# base+nothing == base, and the agreement is structurally guaranteed rather than
# earned. Neutering the rebuild loop in _oss_state_restore_body wipes posture,
# releases and the journal, and every rc/substring assertion above still passes.
# Only a CONCRETE surviving value separates a real rebuild from a silent reset.
t_capture oss_state_read "$S" '.project.posture'
t_assert_eq "fully-private" "$T_OUT" "restore rebuilt the DERIVED state, not merely an internally-consistent one"
t_capture oss_state_read "$S" '.mutations | length'
t_assert_eq "2" "$T_OUT" "restore preserved the journal it rebuilt from"
# -d, NOT -f: the lock is a DIRECTORY (mkdir-based, state.sh:127). `[ -f ]` on it
# is always false, so an -f assertion passes unconditionally and can never detect
# the leak it exists to detect.
[ -d "$S.lock" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: state_restore leaked the lock"; } || T_PASS=$((T_PASS+1))
ls "$S".tmp.* >/dev/null 2>&1 && { T_FAIL=$((T_FAIL+1)); echo "FAIL: state_restore orphaned a temp"; } || T_PASS=$((T_PASS+1))

# Restoring a state that is ALREADY clean is a no-op, not a rewrite.
t_capture oss_state_restore "$S"
t_assert_rc 0 "restore on a clean state is a no-op"
t_assert_contains "$T_OUT" "clean" "...and says so"

# Dispatcher-path: state_restore must survive REAL `set -euo pipefail`, not just
# a sourced call - _oss_state_restore_body runs several command substitutions
# between lock-acquire and lock-release (repo lesson: strict-mode-only faults
# are structurally invisible to a sourced-only test, since this test file never
# enables `set -e` itself). Independent fixture so it does not disturb `$S`.
DRTMP="$TMP/drestore"; mkdir -p "$DRTMP"; DRS="$DRTMP/state.json"
export OSS_STATE_FILE="$DRS"
"$OSS" init drestore-demo >/dev/null
"$OSS" posture_set open-core >/dev/null
jq '.project.posture = "tampered"' "$DRS" > "$DRS.x" && mv "$DRS.x" "$DRS"
t_capture "$OSS" state_restore
t_assert_rc 0 "dispatcher: state_restore repairs drift through the real binary"
t_capture "$OSS" doctor
t_assert_contains "$T_OUT" "ok: replay" "dispatcher: doctor reports replay clean after dispatcher-driven restore"
[ -d "$DRS.lock" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: dispatcher state_restore leaked the lock"; } || T_PASS=$((T_PASS+1))
ls "$DRS".tmp.* >/dev/null 2>&1 && { T_FAIL=$((T_FAIL+1)); echo "FAIL: dispatcher state_restore orphaned a temp"; } || T_PASS=$((T_PASS+1))
unset OSS_STATE_FILE

# Fix 5 (test coverage): missing base snapshot is the rc-1 path, previously
# only documented in the function's prose comment.
rm -f "$S.base.json"
t_capture oss_state_replay "$S"
t_assert_rc 1 "missing base snapshot is rc 1"
t_assert_contains "$T_OUT" "no base snapshot" "missing-base message named"

# --- G1 (2nd Task-2 fix round): clear_demo_pending's back-compat fallback for
# a payload with no `spine` key (written by a build before the op gained that
# argument). CRITICAL: "live" here is hand-built by literal jq assignment, NOT
# by calling _oss_apply_op - a live state built by calling the same function
# replay reconstructs with is tautological (it will match replay's output
# regardless of whether the guard is correct or broken), which is exactly how
# this guard shipped with zero coverage last round despite the suite being
# green. Live must independently encode the INTENDED result: falling back to
# clear-every-entry, matching the pre-spine-argument build's actual behavior.
G1BASE="$TMP/g1base.json"
jq -n '{schema_version:4,
  project:{name:"g1",posture:null,composition_root:null,overlay_wiring:null},
  counters:{demo_line:1},
  releases:[],spines:[],work_items:[],
  demo_ledger:[{id:"d1",type:"auto",status:"active",status_reason:null,status_by:null,
    pending_amendments:[{status:"superseded",by:"r0.s1",reason:"pre-spine-arg plan",at:"2026-01-01T00:00:00Z"}]}],
  bones:[],risk_gates:[],fakes:[],
  feature_map:[],patch_records:[],class_overrides:[],veto_dispositions:[],
  close_records:[],mutations:[]}' > "$G1BASE"
cp "$G1BASE" "$G1BASE.base.json"
G1MUT='{"seq":0,"op":"clear_demo_pending","ts":"2026-02-01T00:00:00Z","payload":{"id":"d1"}}'
jq --argjson m "$G1MUT" \
  '.mutations += [$m] | (.demo_ledger[] | select(.id=="d1")) |= (.pending_amendments = [])' \
  "$G1BASE" > "$G1BASE.tmp" && mv "$G1BASE.tmp" "$G1BASE"
t_capture oss_state_replay "$G1BASE"
t_assert_rc 0 "replay reconstructs a spine-less clear_demo_pending payload as clear-everything (G1)"
# Same fixture through the REAL dispatcher (strict mode), matching how the
# controller's own reproduction of this bug was phrased: "oss doctor -> fail:
# replay". Here it must be "ok: replay". No subshell around t_capture - the
# harness sets T_OUT/T_RC as plain vars, and a subshell would lose them on
# exit (the same trap the plan's Global Constraints name for `pipeline | { }`).
export OSS_STATE_FILE="$G1BASE"
t_capture "$OSS" doctor
unset OSS_STATE_FILE
t_assert_contains "$T_OUT" "ok: replay" "dispatcher: oss doctor reports replay clean on the G1 fixture too"

# --- G2 test 1: F2's set_demo_line_status guard (quarantined_in_release only
# ever written for an actual quarantine call that carries a release) has NO
# replay coverage anywhere in the suite - every existing fixture builds "live"
# by calling _oss_apply_op, which is the same tautology trap as G1 above. Live
# is hand-built here too: exactly what a build predating the guard's very
# existence produced for a quarantine payload with no `release` key at all -
# status/status_reason/status_by set, quarantined_in_release never referenced.
G2BASE="$TMP/g2base.json"
jq -n '{schema_version:4,
  project:{name:"g2",posture:null,composition_root:null,overlay_wiring:null},
  counters:{demo_line:1},
  releases:[],spines:[],work_items:[],
  demo_ledger:[{id:"d1",type:"auto",status:"active",status_reason:null,status_by:null,pending_amendments:[]}],
  bones:[],risk_gates:[],fakes:[],
  feature_map:[],patch_records:[],class_overrides:[],veto_dispositions:[],
  close_records:[],mutations:[]}' > "$G2BASE"
cp "$G2BASE" "$G2BASE.base.json"
G2MUT='{"seq":0,"op":"set_demo_line_status","ts":"2026-01-01T00:00:00Z",
  "payload":{"id":"d1","status":"quarantined","reason":"pre-guard shaped payload, no release key","by":"quarantine"}}'
jq --argjson m "$G2MUT" \
  '.mutations += [$m]
   | (.demo_ledger[] | select(.id=="d1")) |=
       (.status="quarantined" | .status_reason=$m.payload.reason | .status_by="quarantine")' \
  "$G2BASE" > "$G2BASE.tmp" && mv "$G2BASE.tmp" "$G2BASE"
t_capture oss_state_replay "$G2BASE"
t_assert_rc 0 "replay reconstructs a release-less set_demo_line_status payload without manufacturing quarantined_in_release (G2)"
t_capture oss_state_read "$G2BASE" '.demo_ledger[0] | has("quarantined_in_release")'
t_assert_eq "false" "$T_OUT" "setup sanity: the hand-built live state never had the key either (G2)"
export OSS_STATE_FILE="$G2BASE"
t_capture "$OSS" doctor
unset OSS_STATE_FILE
t_assert_contains "$T_OUT" "ok: replay" "dispatcher: oss doctor reports replay clean on the G2 fixture too"

# --- 1.36.0 (#434): set_work_item_exec's spec_oid is SET-IF-GIVEN. Live states are
# hand-built by literal jq (the G1/G2 rule: never by calling _oss_apply_op, which would
# be a tautology). An entry journaled BEFORE 1.36.0 has no spec_oid key and must replay
# to a record with no spec_oid key at all (an unconditional assignment would add a null);
# an entry that carries one must replay to a record that holds it; and a later entry
# without one must leave the recorded value alone.
H1BASE="$TMP/h1base.json"
jq -n '{schema_version:4,
  project:{name:"h1",posture:null,composition_root:null,overlay_wiring:null},
  counters:{demo_line:1},
  releases:[],spines:[],
  work_items:[{id:"r0.s1.w1",spine:"r0.s1",title:"t",target_repo:"canonical",status:"planned"}],
  demo_ledger:[],bones:[],risk_gates:[],fakes:[],
  feature_map:[],patch_records:[],class_overrides:[],veto_dispositions:[],
  close_records:[],mutations:[]}' > "$H1BASE"
cp "$H1BASE" "$H1BASE.base.json"
H1OLD='{"seq":0,"op":"set_work_item_exec","ts":"2026-01-01T00:00:00Z","payload":{"work_item":"r0.s1.w1","branch":"work/a","worktree_path":"/wt/a","base_sha":"b1"}}'
jq --argjson m "$H1OLD" '.mutations += [$m] | (.work_items[0]) |= (.branch="work/a" | .worktree_path="/wt/a" | .base_sha="b1")' \
  "$H1BASE" > "$H1BASE.tmp" && mv "$H1BASE.tmp" "$H1BASE"
t_capture oss_state_replay "$H1BASE"
t_assert_rc 0 "replay reconstructs a pre-1.36.0 set_work_item_exec payload with no spec_oid key and adds none (#434)"
t_capture oss_state_read "$H1BASE" '.work_items[0] | has("spec_oid")'
t_assert_eq "false" "$T_OUT" "setup sanity: the hand-built live record never had the key either (#434)"
H1NEW='{"seq":1,"op":"set_work_item_exec","ts":"2026-01-02T00:00:00Z","payload":{"work_item":"r0.s1.w1","branch":"work/b","worktree_path":"/wt/b","base_sha":"b2","spec_oid":"0123456789abcdef0123456789abcdef01234567"}}'
jq --argjson m "$H1NEW" '.mutations += [$m] | (.work_items[0]) |= (.branch="work/b" | .worktree_path="/wt/b" | .base_sha="b2" | .spec_oid="0123456789abcdef0123456789abcdef01234567")' \
  "$H1BASE" > "$H1BASE.tmp" && mv "$H1BASE.tmp" "$H1BASE"
t_capture oss_state_replay "$H1BASE"
t_assert_rc 0 "replay reconstructs a set_work_item_exec payload that carries spec_oid (#434)"
H1KEEP='{"seq":2,"op":"set_work_item_exec","ts":"2026-01-03T00:00:00Z","payload":{"work_item":"r0.s1.w1","branch":"work/c","worktree_path":"/wt/c","base_sha":"b3"}}'
jq --argjson m "$H1KEEP" '.mutations += [$m] | (.work_items[0]) |= (.branch="work/c" | .worktree_path="/wt/c" | .base_sha="b3")' \
  "$H1BASE" > "$H1BASE.tmp" && mv "$H1BASE.tmp" "$H1BASE"
t_capture oss_state_replay "$H1BASE"
t_assert_rc 0 "replay keeps a recorded spec_oid across a later entry that carries none (#434)"
t_capture oss_state_read "$H1BASE" '.work_items[0].spec_oid'
t_assert_eq "0123456789abcdef0123456789abcdef01234567" "$T_OUT" "setup sanity: the hand-built live record kept the value too (#434)"
# CONTROL: the comparison can fail - a live record that DROPPED the value is drift (rc 5).
jq '(.work_items[0]) |= del(.spec_oid)' "$H1BASE" > "$H1BASE.tmp" && mv "$H1BASE.tmp" "$H1BASE"
t_capture oss_state_replay "$H1BASE"
t_assert_rc 5 "...and a live record missing the kept spec_oid is drift, so the replay checks above can fail (#434)"

# ---------------------------------------------------------------------------
# G3: a CORRUPT JOURNAL must never be rebuilt into the empty base skeleton.
#
# `jq '.mutations | length'` exits 0 and yields the DIGIT 0 for a state whose
# .mutations key is missing, and yields EMPTY OUTPUT for a 0-byte file. Neither
# was validated, so the rebuild loop was skipped and `cat "$base"` — the pristine
# init skeleton — was committed over a live project, at rc 0, with a success
# message. `doctor` then reported all four checks green, so nothing downstream
# could see the loss. Assert CONCRETE SURVIVING VALUES, not just rc: an rc-only
# assertion here passes against a state that has been emptied.
# ---------------------------------------------------------------------------
g3_build() { # $1=dest ; a real project: posture + release + spine + bone, 4 ops
  local d="$1"
  # NOT silenced on stderr: a builder that fails quietly makes every assertion
  # below vacuous, which is exactly how a guard test ends up unable to fail.
  oss_state_init "$d" g3proj >/dev/null
  oss_state_mutate "$d" set_posture "$(jq -n '{posture:"private"}')" >/dev/null
  oss_entity_add_release "$d" skeleton "goal" >/dev/null
  oss_entity_add_spine "$d" r0 s1 bone canonical >/dev/null
  oss_reg_add_bone "$d" ADR-1 "b" "src/a" >/dev/null
}

for variant in del-key null-key zero-byte; do
  G3="$TMP/g3-$variant.json"; g3_build "$G3"
  # setup sanity: the guard's precondition is real — there IS something to lose
  t_capture oss_state_read "$G3" '.releases[0].id'
  t_assert_eq "r0" "$T_OUT" "G3/$variant setup: a real release exists before corruption"

  case "$variant" in
    del-key)   jq 'del(.mutations)' "$G3" > "$G3.t" && mv "$G3.t" "$G3" ;;
    null-key)  jq '.mutations = null' "$G3" > "$G3.t" && mv "$G3.t" "$G3" ;;
    zero-byte) : > "$G3" ;;
  esac

  t_capture oss_state_restore "$G3"
  [ "$T_RC" -ne 0 ] && T_PASS=$((T_PASS+1)) \
    || { T_FAIL=$((T_FAIL+1)); echo "FAIL: G3/$variant: state_restore returned 0 over a corrupt journal (it must refuse)"; }
  t_assert_contains "$T_OUT" "journal" "G3/$variant: the refusal names the journal as the corrupt thing"

  # THE LOAD-BEARING ASSERTIONS — concrete values must survive the refusal.
  if [ "$variant" != "zero-byte" ]; then
    t_capture oss_state_read "$G3" '.releases[0].id'
    t_assert_eq "r0" "$T_OUT" "G3/$variant: the release SURVIVED - restore did not overwrite with the base skeleton"
    t_capture oss_state_read "$G3" '.project.posture'
    t_assert_eq "private" "$T_OUT" "G3/$variant: the posture SURVIVED"
    t_capture oss_state_read "$G3" '.bones[0].adr'
    t_assert_eq "ADR-1" "$T_OUT" "G3/$variant: the bone SURVIVED"
  fi
done

# G4: replay must not tell the operator "Nothing is lost" and route them to
# state_restore when the journal itself is what is corrupt — that message sends
# them at the one command that would complete the loss.
G4="$TMP/g4.json"; g3_build "$G4"
jq 'del(.mutations)' "$G4" > "$G4.t" && mv "$G4.t" "$G4"
t_capture oss_state_replay "$G4"
[ "$T_RC" -ne 0 ] && T_PASS=$((T_PASS+1)) \
  || { T_FAIL=$((T_FAIL+1)); echo "FAIL: G4: replay returned 0 on a corrupt journal"; }
case "$T_OUT" in
  *"Nothing is lost"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: G4: replay still claims 'Nothing is lost' when the journal is the corrupt thing" ;;
  *) T_PASS=$((T_PASS+1)) ;;
esac
case "$T_OUT" in
  *state_restore*) T_FAIL=$((T_FAIL+1)); echo "FAIL: G4: replay routes the operator to state_restore, which would complete the data loss" ;;
  *) T_PASS=$((T_PASS+1)) ;;
esac

# --- #340: legacy-format repair through the corrective append ---------------
# The pre-#340 world journaled add_risk_gate payloads with SPLIT control
# fragments (the CSV splitter had no escape). A journal like that is healthy —
# replay reproduces the fragments faithfully — and the repair is a journaled
# set_risk_gate_controls, never a history edit. This is the migration-path
# input: a LEGACY-format journal, not a fresh derivation.
T6="$(mktemp -d)"; S6="$T6/state.json"
oss_state_init "$S6" legacy-repair >/dev/null
# The legacy fragment payload, as the old splitter actually wrote it:
oss_state_mutate "$S6" add_risk_gate \
  '{"name":"live-order-execution","touch":["src/exec/**"],"controls":["paper env","human confirm","audit trail: record image","mounts","egress allowlist and exit status per bootstrap","kill switch"],"at":"2026-08-25T00:00:00Z"}'
t_capture oss_state_replay "$S6"
t_assert_rc 0 "legacy journal with split fragments replays faithfully"
t_capture oss_state_read "$S6" '.risk_gates[0].controls | length'
t_assert_eq "6" "$T_OUT" "the corruption reproduces: one phrase became three fragments"
t_capture oss_reg_set_risk_gate_controls "$S6" live-order-execution "paper env,human confirm,audit trail: record image\, mounts\, egress allowlist and exit status per bootstrap,kill switch"
t_assert_rc 0 "corrective append lands on the legacy state"
t_capture oss_state_replay "$S6"
t_assert_rc 0 "replay derives the CORRECTED state from base+journal"
t_capture oss_state_read "$S6" '.risk_gates[0].controls | length'
t_assert_eq "4" "$T_OUT" "repaired controls hold the phrase whole (4, not 6)"
t_capture oss_state_read "$S6" '.risk_gates[0].controls[2]'
t_assert_eq "audit trail: record image, mounts, egress allowlist and exit status per bootstrap" "$T_OUT" "the repaired control holds the phrase TEXT, not just a count"
t_capture oss_state_read "$S6" '.mutations | length'
t_assert_eq "2" "$T_OUT" "the journal kept BOTH mutations - append, not edit"
rm -rf "$T6"

# --- 1.11.0: the touch re-point ops and `abandoned`, on REAL journal records -
# set_bone_touch {adr,touch}, set_risk_gate_touch {name,touch} and the
# work-item status `abandoned` are a compatibility contract: live estate
# journals already carry them, from a local-only build that shipped them before
# this release. The payloads below are VERBATIM .payload values from those
# journals (seqs noted), written through oss_state_mutate - the path the verbs
# take - so this is the migration-path input, not a fresh derivation. Without
# the two _oss_apply_op cases the first touch record fails on "unknown op"
# (rc 4), which is exactly what 1.10.0 does to those estates' doctor replay.
T7="$(mktemp -d)"; S7="$T7/state.json"
oss_state_init "$S7" touch-replay >/dev/null
oss_state_mutate "$S7" add_bone '{"adr":"ADR-0003","title":"silver + ingestion layer","touch":["src/silver/**","src/ingestion/**"],"revisit_trigger":null,"at":"2026-08-30T00:00:00Z"}' >/dev/null
for g in project-identity pii-disclosure gold-correctness; do
  oss_state_mutate "$S7" add_risk_gate "{\"name\":\"$g\",\"touch\":[\"src/$g/**\"],\"controls\":[\"control-$g\"],\"at\":\"2026-08-30T00:00:00Z\"}" >/dev/null
done
oss_state_mutate "$S7" add_work_item '{"id":"r0.s1.w5","spine":"r0.s1","title":"minted then withdrawn","target_repo":"canonical","status":"planned","created_at":"2026-09-01T00:00:00Z"}' >/dev/null
t_capture oss_state_replay "$S7"
t_assert_rc 0 "setup: the add-only journal replays clean before any re-point"

# marketplace-analytics seq 64, then seqs 83 and 107 (the same bone, twice), then 138.
t_capture oss_state_mutate "$S7" set_work_item_status '{"work_item":"r0.s1.w5","status":"abandoned","at":"2026-09-08T18:27:23Z"}'
t_assert_rc 0 "seq 64 (set_work_item_status abandoned) applies"
t_capture oss_state_mutate "$S7" set_bone_touch '{"adr":"ADR-0003","touch":["src/silver/**","src/ingestion/**","packages/marketplace-analytics/src/marketplace_analytics/silver/**","packages/marketplace-analytics/src/marketplace_analytics/ingestion/**"]}'
t_assert_rc 0 "seq 83 (set_bone_touch) applies"
t_capture oss_state_mutate "$S7" set_bone_touch '{"adr":"ADR-0003","touch":["src/silver/**","src/ingestion/**","packages/marketplace-analytics/src/marketplace_analytics/silver/**","packages/marketplace-analytics/src/marketplace_analytics/ingestion/**","packages/google-analytics/src/google_analytics/silver/**","packages/google-analytics/src/google_analytics/ingestion/**"]}'
t_assert_rc 0 "seq 107 (set_bone_touch, same bone again) applies"
t_capture oss_state_mutate "$S7" set_risk_gate_touch '{"name":"gold-correctness","touch":["packages/wabash-ga-lakehouse/src/wabash_ga_lakehouse/gold/**","notebooks/gold_build.py"]}'
t_assert_rc 0 "seq 138 (set_risk_gate_touch) applies"
# agent-framework seqs 354 and 355.
t_capture oss_state_mutate "$S7" set_risk_gate_touch '{"name":"project-identity","touch":["packages/waf-tools/src/waf_tools/server/**","packages/waf-core/src/waf_core/shapes/chat/auth*","packages/waf-tools/src/waf_tools/client/**","packages/waf-core/src/waf_core/composition/host/**"]}'
t_assert_rc 0 "seq 354 (set_risk_gate_touch) applies"
t_capture oss_state_mutate "$S7" set_risk_gate_touch '{"name":"pii-disclosure","touch":["packages/waf-compute/src/waf_compute/redaction/**","packages/waf-core/src/waf_core/hooks/**","packages/waf-log/src/waf_log/writer/**","packages/waf-compute/src/waf_compute/templates/batch.py"]}'
t_assert_rc 0 "seq 355 (set_risk_gate_touch) applies"

t_capture oss_state_replay "$S7"
t_assert_rc 0 "a journal carrying the estates' real records replays to the exact live state"
# Replay equality alone is a round trip through one transform; these pin the
# VALUES the records must produce, independently of that transform.
t_capture oss_state_read "$S7" '.bones[0].touch | length'
t_assert_eq "6" "$T_OUT" "ADR-0003 carries seq 107's six globs - the later re-point wins"
t_capture oss_state_read "$S7" '.bones[0].touch[5]'
t_assert_eq "packages/google-analytics/src/google_analytics/ingestion/**" "$T_OUT" "...and holds seq 107's text, not seq 83's"
t_capture oss_state_read "$S7" '[.risk_gates[] | "\(.name)=\(.touch | length):\(.touch[0])"] | join(" ")'
t_assert_eq "project-identity=4:packages/waf-tools/src/waf_tools/server/** pii-disclosure=4:packages/waf-compute/src/waf_compute/redaction/** gold-correctness=2:packages/wabash-ga-lakehouse/src/wabash_ga_lakehouse/gold/**" "$T_OUT" "each gate's touch surface is its own record's, and no other gate moved"
t_capture oss_state_read "$S7" '[.risk_gates[].controls[0]] | join(",")'
t_assert_eq "control-project-identity,control-pii-disclosure,control-gold-correctness" "$T_OUT" "a touch re-point leaves every gate's controls alone"
t_capture oss_state_read "$S7" '.work_items[] | select(.id=="r0.s1.w5") | .status'
t_assert_eq "abandoned" "$T_OUT" "r0.s1.w5 reads abandoned after replay"
t_capture oss_state_read "$S7" '.mutations | length'
t_assert_eq "11" "$T_OUT" "the journal holds all eleven mutations - append, never edit"
# The doctor path the estates run: its replay line must be ok, not fail.
t_capture env OSS_STATE_FILE="$S7" bash "$OSS" doctor
t_assert_contains "$T_OUT" "ok: replay" "oss doctor reports replay ok on the estates' records"
case "$T_OUT" in
  *"fail: replay"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: oss doctor reports 'fail: replay' on the estates' records" ;;
  *) T_PASS=$((T_PASS+1)) ;;
esac
rm -rf "$T7"

# work_item_pr (1.26.0): the journal reproduces pr_url on replay.
SP="$TMP/pr-state.json"
oss_state_init "$SP" pr-replay >/dev/null
oss_state_mutate "$SP" add_work_item '{"id":"r0.s1.w1","spine":"r0.s1","title":"pr","target_repo":"canonical","status":"active","created_at":"2026-10-22T00:00:00Z"}' >/dev/null
# A second item, so a reducer that drops its select(.id == ...) is visible: the
# PR must land on r0.s1.w1 alone.
oss_state_mutate "$SP" add_work_item '{"id":"r0.s1.w2","spine":"r0.s1","title":"other","target_repo":"canonical","status":"active","created_at":"2026-10-22T00:00:00Z"}' >/dev/null
oss_state_mutate "$SP" set_work_item_pr '{"work_item":"r0.s1.w1","pr_url":"https://github.com/o/r/pull/7"}' >/dev/null
t_capture oss_state_replay "$SP"
t_assert_rc 0 "set_work_item_pr replays to the exact live state"
t_capture oss_state_read "$SP" '.work_items[0].pr_url'
t_assert_eq "https://github.com/o/r/pull/7" "$T_OUT" "replay reproduces pr_url"
t_capture oss_state_read "$SP" '[.work_items[] | select(.pr_url != null) | .id] | join(",")'
t_assert_eq "r0.s1.w1" "$T_OUT" "set_work_item_pr gives pr_url to the named item only"

_restore_read_only_state() {
  local sf="$TMP/restore-pty.json"
  OSS_STATE_FILE="$sf" "$OSS" init restore-pty || return 1
  OSS_STATE_FILE="$sf" "$OSS" posture_set open-core || return 1
  jq '.project.posture = "tampered"' "$sf" > "$sf.x" && mv "$sf.x" "$sf" || return 1
  chmod 444 "$sf" || return 1
  t_on_pty env OSS_STATE_FILE="$sf" "$OSS" state_restore || return $?
  jq -e '.project.posture == "open-core" and [.mutations[].op] == ["set_posture"]' "$sf"
}

if t_pty_available; then
  t_capture _restore_read_only_state
  t_assert_rc 0 "#1256: restore replaces read-only state on a PTY: $T_OUT"
fi

rm -rf "$TMP"
t_summary
