#!/usr/bin/env bash
# The DISPATCHER SURFACE, not any one lib: every `oss <verb>` invoked with too
# few arguments must answer with the rc-2 usage error the taxonomy defines
# (lib/commands.sh's header note — "1 generic, 2 usage, 3 lock, ...") and never with bash's
# raw `unbound variable` diagnostic at rc 1.
#
# WHY THIS FILE RUNS THE REAL DISPATCHER AND BUILDS A REAL PROJECT:
#
# 1. `bin/oss` runs `set -euo pipefail`; every other suite sources the libs
#    directly and is therefore NON-strict. An unguarded `"$1"` is invisible to a
#    sourced-function test and fatal through the dispatcher. Only `bash "$OSS"`
#    sees it.
# 2. The fixture MUST have a pairing manifest and an initialized state. Run from
#    a directory with neither, 46 of the 61 verbs short-circuit on
#    `_oss_resolve_state`'s manifest error BEFORE ever touching `$1` — which
#    measures 13 leaking verbs instead of the real 44. That is not a
#    hypothetical: it is the mis-measurement this test was written to prevent.
#
# The loop is over the LIVE verb list from `oss help`, not a hand-maintained
# array, so a verb added later is covered the day it ships.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
OSS="$HERE/../bin/oss"

TMP="$(mktemp -d)"
mkdir -p "$TMP/ws/.workspace" "$TMP/canon"
git -C "$TMP/canon" init -q
git -C "$TMP/canon" config user.email t@t; git -C "$TMP/canon" config user.name t
echo seed > "$TMP/canon/f.txt"
git -C "$TMP/canon" add .; git -C "$TMP/canon" commit -qm seed
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
cd "$TMP/ws"

bash "$OSS" init arity-demo >/dev/null 2>&1

# --- setup sanity, BEFORE any arity assertion ------------------------------
# If init silently failed, every verb below returns the manifest/state error
# instead of an arity error, the loop finds zero leaks, and the whole file
# passes while measuring nothing. Assert the precondition is real first.
t_capture bash "$OSS" doctor
t_assert_rc 0 "setup: the fixture is a REAL initialized project (doctor green) - without this every assertion below is vacuous"

VERBS="$(bash "$OSS" help 2>&1 | awk '$1 == "oss" {print $2}')"
t_assert_ge_local() { if [ "$2" -ge "$1" ]; then T_PASS=$((T_PASS+1)); else T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (wanted >= $1, got $2)"; fi; }
t_assert_ge_local 55 "$(printf '%s\n' "$VERBS" | grep -c .)" "setup: the verb list is live and populated (not an empty glob)"

# --- the sweep -------------------------------------------------------------
LEAKED=""; BAD_RC=""
for v in $VERBS; do
  out="$(bash "$OSS" "$v" 2>&1)"; rc=$?
  case "$out" in
    *"unbound variable"*) LEAKED="$LEAKED $v"; continue ;;
  esac
  # A verb that legitimately takes no arguments may succeed (rc 0) or answer
  # with any diagnostic it likes. What none of them may do is die on a raw
  # parameter expansion. Where a verb DID need arguments, the rc must be the
  # taxonomy's 2 = usage, so a caller can branch on it.
  case "$out" in
    *"needs "*" argument"*) [ "$rc" -eq 2 ] || BAD_RC="$BAD_RC $v:rc$rc" ;;
  esac
done

t_assert_eq "" "$LEAKED" "no dispatcher verb leaks a raw bash 'unbound variable' diagnostic${LEAKED:+ -- leaked:$LEAKED}"
t_assert_eq "" "$BAD_RC" "every arity refusal uses the taxonomy's rc 2 = usage${BAD_RC:+ -- wrong rc:$BAD_RC}"

# --- the usage message is actionable, not just present ---------------------
# A guard that fires with an empty message is a guard that moved the problem
# rather than fixing it: the caller still cannot tell what was missing.
t_capture bash "$OSS" bone_add
t_assert_rc 2 "a representative multi-arg verb refuses at rc 2"
t_assert_contains "$T_OUT" "oss bone_add" "the refusal names the verb"
t_assert_contains "$T_OUT" "<adr>" "the refusal names the missing arguments, not just the count"

t_capture bash "$OSS" bone_add ADR-1 title
t_assert_rc 2 "a PARTIALLY-supplied verb is still rc 2 (2 of 3 args is still short)"

t_capture bash "$OSS" bone_add ADR-1 title src/a
t_assert_rc 0 "the happy path is untouched by the guard"

# The optional-argument boundary: a verb whose last parameter is optional must
# accept the short form. A guard that counted the optional arg as required
# would break every caller that omits it, and the happy-path assertion above
# would not see it.
t_capture bash "$OSS" bone_add ADR-2 title2 src/b "revisit when X"
t_assert_rc 0 "the optional 4th argument is still accepted"

# --- work_item_pr (1.26.0): exactly two arguments ---------------------------
t_capture bash "$OSS" work_item_pr r0.s1.w1
t_assert_rc 2 "work_item_pr with 1 argument is rc 2"
t_capture bash "$OSS" work_item_pr r0.s1.w1 https://github.com/o/r/pull/7 extra
t_assert_rc 2 "work_item_pr with 3 arguments is rc 2"

# --- #530: a SPLIT glob list is refused, not silently shrunk ---------------
# `_oss_need` counts with `-ge`, so a caller who space-splits a glob list
# instead of using the documented CSV grammar got rc 0 and a ONE-glob surface -
# and because a re-point REPLACES the list, the coverage the caller believed they
# re-stated was gone, silently. These verbs take exactly two arguments and the
# refusal names the grammar, not just the count.
t_capture bash "$OSS" bone_set_touch ADR-1 "src/a/**" "src/b/**"
t_assert_rc 2 "bone_set_touch refuses a third argument at rc 2"
t_assert_contains "$T_OUT" "comma-separated" "...and names the CSV grammar the caller missed"
t_capture bash "$OSS" risk_gate_set_touch g1 "src/a/**" "src/b/**"
t_assert_rc 2 "risk_gate_set_touch refuses a third argument at rc 2"
t_assert_contains "$T_OUT" "comma-separated" "...and names the CSV grammar too"
# #524: the third corrective append, same defect - a space-split controls list
# shrinks the checklist silently, and this verb REPLACES the list as well.
t_capture bash "$OSS" risk_gate_set_controls g1 "ctl-a" "ctl-b"
t_assert_rc 2 "risk_gate_set_controls refuses a third argument at rc 2"
t_assert_contains "$T_OUT" "comma-separated" "...and names the CSV grammar"
# #530 arm 2 at the MINT, where the verb is FIXED arity (no optional trailing
# parameter), so exact arity is a drop-in: without it a space-split controls list
# minted a gate whose checklist was silently one entry short.
t_capture bash "$OSS" risk_gate_add g-split "src/a/**" "ctl-a" "ctl-b"
t_assert_rc 2 "risk_gate_add refuses a fourth argument at rc 2"
t_assert_contains "$T_OUT" "comma-separated" "...and names the CSV grammar the caller missed"
# ADJACENT CONTROL: the two-argument form reaches the VERB, so the guard above is
# the extra argument and not the verb. Two rows, because this fixture already
# minted ADR-1 above: the KNOWN ref must still succeed (rc 0 - the re-point runs),
# and an UNKNOWN one must answer the verb's own rc 7. An assertion of "rc != 0"
# would not separate the arity guard from either.
t_capture bash "$OSS" bone_set_touch ADR-1 "src/a/**,src/b/**"
t_assert_rc 0 "the two-argument form on a known ref still re-points"
t_capture bash "$OSS" bone_set_touch ADR-9 "src/a/**"
t_assert_rc 7 "the two-argument form on an unknown ref answers the verb's rc 7, not the arity guard"
t_capture bash "$OSS" risk_gate_set_touch g1 "src/a/**"
t_assert_rc 7 "the gate verb's two-argument form does too"

# --- #305 item 1: the uniqueness rail through the REAL dispatcher ------------
# The rail runs INSIDE oss_state_mutate's critical section, and that body is
# invoked in `|| rc=$?` context with errexit suspended - while every other suite
# sources the libs and is non-strict anyway. So the guard's own error handling is
# exercised nowhere except here, under `set -euo pipefail`, where one unguarded
# failing assignment hard-exits the whole dispatcher instead of answering rc 7.
t_capture bash "$OSS" bone_add ADR-1 "a second row for one ref" "src/other/**"
t_assert_rc 7 "bone_add refuses an existing ADR ref at rc 7 through the dispatcher"
t_assert_contains "$T_OUT" "already exists" "...and it is the rail's own message, not a shell abort"
t_capture jq '[.bones[] | select(.adr=="ADR-1")] | length' "$TMP/ws/.ossify/project-state.json"
t_assert_eq "1" "$T_OUT" "...and the refused call minted no second row"
t_capture bash "$OSS" risk_gate_add g1 "src/a/**" "ctl-one"
t_assert_rc 0 "...and a fresh gate name still mints"
t_capture bash "$OSS" risk_gate_add g1 "src/other/**" "ctl-two"
t_assert_rc 7 "...and re-adding that gate name refuses at rc 7"
t_assert_contains "$T_OUT" "already exists" "...with the rail's own message, not a shell abort"

# --- an uninitialised project is told to init, not to retry a lock ---------
# Lock-acquire conflated "lock held" with "state file missing", so a project
# that had never run `oss init` was told to "retry or run 'oss doctor'" at rc 3.
# doctor itself says `fail: state - not found`, so the two disagreed about the
# same condition and the remedy sent the user in a circle.
TMP2="$(mktemp -d)"
mkdir -p "$TMP2/ws/.workspace" "$TMP2/canon"
git -C "$TMP2/canon" init -q
cat > "$TMP2/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP2/ws"},"canonical":{"root":"$TMP2/canon"},"well_known_paths":{}}
EOF
cd "$TMP2/ws"
# setup sanity: a manifest EXISTS (so we are past that gate) and state does NOT
[ -f "$TMP2/ws/.workspace/pairing.json" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: setup: uninitialised fixture has no manifest"; }
[ -f "$TMP2/ws/.ossify/project-state.json" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: setup: fixture is initialized; the assertion below cannot fail"; } || T_PASS=$((T_PASS+1))

t_capture bash "$OSS" posture_set private
t_assert_rc 1 "an uninitialised project is rc 1 (not found), not rc 3 (lock held)"
t_assert_contains "$T_OUT" "oss init" "...and the remedy named is 'oss init', not 'retry or run doctor'"
case "$T_OUT" in
  *"state locked"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: an uninitialised project is still reported as a held lock" ;;
  *) T_PASS=$((T_PASS+1)) ;;
esac

# --- retired verbs stay retired --------------------------------------------
# The skill-first conversions deleted these verbs together with the surfaces
# they carried (rules_validate's --file shell-source path; harvest_apply's
# write path; interop_check's 175-line read-out). A partial revert or a
# copy-paste revival would reintroduce a surface the prose now says does not
# exist — and the suite would stay green, because nothing else checks verb
# ABSENCE. Same guard test-worktree.sh pins on worktree_list and
# test-manifest.sh pins on manifest_get.
#
# BOTH assertions are load-bearing. rc 2 alone cannot prove absence: the exact
# deleted wrappers open with `_oss_need … || return 2`, so a verbatim revert
# answers rc 2 too — with a USAGE message. Only the dispatcher's own
# "unknown subcommand" diagnostic separates "gone" from "revived and asking
# for arguments". (Codex P2, PR #187 round 2.)
for v in interop_check harvest_dir harvest_apply rules_types rules_validate; do
  t_capture bash "$OSS" "$v"
  t_assert_rc 2 "the retired '$v' verb answers rc 2"
  t_assert_contains "$T_OUT" "unknown subcommand" "the retired '$v' verb is UNKNOWN to the dispatcher, not merely short of arguments"
done

cd /; rm -rf "$TMP" "$TMP2"
t_summary
