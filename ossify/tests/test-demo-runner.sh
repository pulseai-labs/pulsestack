#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
# manifest+verify+worktree added for Task 6: the runner now resolves its
# workdir via _oss_repo_root (worktree.sh, which itself calls oss_manifest_get
# from manifest.sh) and checks vacuous-green via oss_verify_zero_tests_guard
# (verify.sh). ANY new test file that CALLS the demo runner (not merely
# sources demo.sh) needs this same trio - see the criterion note below.
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/manifest.sh"
. "$HERE/../lib/entities.sh"; . "$HERE/../lib/ledger.sh"; . "$HERE/../lib/verify.sh"; . "$HERE/../lib/worktree.sh"; . "$HERE/../lib/demo.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
# Task 6: `oss_demo_run_auto` now resolves its working directory via a
# pairing manifest (composition root when set, the sole declared repo's root
# otherwise - #272/#310 Task 4 routed this through the sole-repo default rule,
# never a literal `canonical`) -
# a BEHAVIORAL CHANGE from "runs in the caller's cwd". Every call below that
# omits the explicit workdir argument needs one on the walk-up path, so the
# fixture goes in BEFORE the first such call (all eight pre-existing calls
# in this file included). ai_workspace.root is $TMP itself (not $TMP/ws) so
# the manifest is discoverable once we `cd "$TMP"` - oss_manifest_discover
# walks UP from $PWD, never down.
mkdir -p "$TMP/.workspace" "$TMP/canon"
cat > "$TMP/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
cd "$TMP"
oss_state_init "$S" demo-run >/dev/null
# Mint the spines demo lines are keyed to (ledger validates source_spine exists).
oss_entity_add_release "$S" "demo" "goal" >/dev/null
oss_entity_add_spine "$S" r0 "demo spine" bone canonical >/dev/null
oss_entity_add_spine "$S" r0 "second spine" flesh canonical >/dev/null

oss_ledger_add_auto "$S" r0.s1 "always true" "true" "exit:0" active >/dev/null
oss_ledger_add_auto "$S" r0.s1 "greets" "echo hello-world" "contains:hello" active >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 0 "all green"; t_assert_contains "$T_OUT" "PASS 2" "pass count"

oss_ledger_add_auto "$S" r0.s1 "always false" "false" "exit:0" active >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 1 "halt on first fail"; t_assert_contains "$T_OUT" "FAIL d3" "failing line named"

oss_ledger_quarantine "$S" d3 "flaky env, fix by r1 close" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 0 "quarantined line skipped"; t_assert_contains "$T_OUT" "SKIP" "skip reported"

oss_ledger_add_auto "$S" r0.s1 "vacuous suite" "echo 'collected 0 items' # pytest" "exit:0" active >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 1 "vacuous green caught"; t_assert_contains "$T_OUT" "vacuous-green" "guard named"

# Take the vacuous line (d4) out of the active run so the halt-on-first-fail run
# can reach the next assertion. D1 (Plan C1 Task 2) made retire a PLANNING verb
# that only records a pending amendment - applied by a spine's close, and now
# validated against a real spine id - so it no longer clears d4 out of the
# active set on the spot, and this fixture defines no spine to amend against.
# Quarantine is the immediate verb (a close/doctor-time action on a line that
# actually fails, requiring only that the line exist - see d3 above) and is
# what this fixture actually needs: d4 out of the run immediately, no spine.
oss_ledger_quarantine "$S" d4 "test cleanup" >/dev/null

# A legitimate demo line that merely mentions a zero-tests phrase in its output —
# but is NOT a test runner — must NOT be flagged vacuous-green (AND-gate precision).
oss_ledger_add_auto "$S" r0.s1 "legit zero-passing mention" "echo '0 passing warnings remain'" "contains:0 passing" active >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 0 "non-runner output mentioning a zero-tests phrase is NOT vacuous-green"

# D3: a `contains:` line whose command prints the needle and then exits 127 (not
# invocable) FAILS - the shell's error text can carry the needle, and a plain
# `contains:` row reads no exit status at all, so it would pass on a command that
# never ran. The adjacent control keeps a refusal that exits 1 passing.
oss_ledger_add_auto "$S" r0.s1 "not invocable" "echo still-there; exit 127" "contains:still-there" active >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 1 "contains: on a command that cannot run (rc 127) fails"
t_assert_contains "$T_OUT" "not invocable here" "the failure names the rc-127 non-invocability"
oss_ledger_quarantine "$S" d6 "test cleanup" >/dev/null
oss_ledger_add_auto "$S" r0.s1 "refusal that exits 1" "echo refused-here; exit 1" "contains:refused-here" active >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 0 "control: a contains: line that prints its needle and exits 1 still passes"
oss_ledger_quarantine "$S" d7 "test cleanup" >/dev/null

# Fix 3: a missing/unreadable state file must be a guarded rc-1 error, not an
# unguarded jq exit-2 abort under the dispatcher's `set -e` (which collides
# with the rc-2 "usage error" convention). Exercised through the real
# dispatcher (bin/oss), not the bare lib function, so `set -e` is actually in
# effect the way it is in production use.
t_capture "$HERE/../bin/oss" demo_run /nonexistent/state.json
t_assert_rc 1 "missing state file is rc 1, not rc 2, via dispatcher"
t_assert_contains "$T_OUT" "cannot read state" "error message names the problem"

# --- Final review finding 1 (runner half). The ledger is APPEND-ONLY, so a line
# whose `expected` slipped past an older, looser validator is re-run and
# re-reported at every future close. The runner must therefore FAIL CLOSED on an
# operand it cannot compare, not fall out of the `case` (or let `[` exit 2, which
# the `if` reads as false) and count the line as passed. Injected straight into
# state because the validator now correctly refuses to create such a line.
T2="$(mktemp -d)"; S2="$T2/state.json"
oss_state_init "$S2" demo-malformed >/dev/null
oss_entity_add_release "$S2" "demo" "goal" >/dev/null
oss_entity_add_spine "$S2" r0 "demo spine" bone canonical >/dev/null
oss_ledger_add_auto "$S2" r0.s1 "legacy line, malformed operand" "exit 1" "exit:0" active >/dev/null
jq '.demo_ledger[0].expected = "exit:0 (tests green)"' "$S2" > "$S2.x" && mv "$S2.x" "$S2"
t_capture oss_demo_run_auto "$S2"
t_assert_rc 1 "malformed exit: operand FAILS the line (was: silently counted as PASS)"
t_assert_contains "$T_OUT" "FAIL d1" "the malformed line is named"

# An `expected` the runner recognizes not at all must also fail closed. The
# command here exits 0, so a rc 0 can only come from the fall-through — this is
# the assertion that distinguishes "fails closed" from "the command happened to
# fail" above.
jq '.demo_ledger[0].expected = "under 40ms" | .demo_ledger[0].command = "true"' "$S2" > "$S2.x" && mv "$S2.x" "$S2"
t_capture oss_demo_run_auto "$S2"
t_assert_rc 1 "unrecognized expected grammar FAILS the line (fail closed, not fall through)"
t_assert_contains "$T_OUT" "FAIL d1" "the unrecognized-grammar line is named"
rm -rf "$T2"

# --- Task 6: composition-root workdir, scoped vacuous-green guard, user-line
# surfacing, durable close records. ---

# The runner executes in the COMPOSITION ROOT (canonical when unset), not the
# caller's cwd. A relative-path demo command is the whole point of the ledger.
mkdir -p "$TMP/canon"; echo marker > "$TMP/canon/marker.txt"
t_capture oss_ledger_add_auto "$S" r0.s1 "marker present" "test -f marker.txt" "exit:0" active
cd "$TMP"   # deliberately NOT the demo working dir
# Explicit workdir: this suite has no pairing manifest, so the manifest leg
# cannot resolve. That is the whole reason oss_demo_workdir takes an explicit
# argument — see the note on its precedence.
t_capture oss_demo_run_auto "$S" "$TMP/canon"
t_assert_rc 0 "a relative-path demo command resolves against the given workdir, not \$PWD"
# NOT `t_capture` for this check: t_capture wraps the call in `$(...)`, which
# bash ALWAYS forks a subshell for - so it absorbs an insufficiently-contained
# internal `cd` regardless of whether demo.sh's own subshell containment is
# correct, making a t_capture'd assertion here a tautology. Verified: mutating
# the runner's `cd "$wd" && bash -c ...` (inside its OWN "$(...)") to a bare
# `cd "$wd"` ahead of it does NOT red a t_capture'd version of this assertion.
# Calling the function as a plain statement (output redirected, not
# substituted) runs it directly in THIS shell, so a leaked `cd` shows up here.
oss_demo_run_auto "$S" "$TMP/canon" >/dev/null 2>&1
t_assert_eq "$TMP" "$PWD" "the runner's subshell cd did NOT mutate the process cwd"

# oss_demo_workdir's composition_root leg (precedence tier 2, between explicit
# and bare-canonical), for BOTH a relative and an absolute value - neither had
# any test coverage anywhere in the suite before this task (the one existing
# composition_root test, test-dispatcher-ops.sh, only proves the value is
# STORED, never that the demo runner resolves against it).
mkdir -p "$TMP/canon/sub"; echo sub-marker > "$TMP/canon/sub/sub-marker.txt"
oss_state_mutate "$S" set_composition "$(jq -n --arg c sub '{composition_root:$c}')" >/dev/null
t_capture oss_demo_workdir "$S"
t_assert_eq "$TMP/canon/sub" "$T_OUT" "a relative composition_root resolves against the canonical root"

mkdir -p "$TMP/elsewhere"
oss_state_mutate "$S" set_composition "$(jq -n --arg c "$TMP/elsewhere" '{composition_root:$c}')" >/dev/null
t_capture oss_demo_workdir "$S"
t_assert_eq "$TMP/elsewhere" "$T_OUT" "an absolute composition_root is used verbatim, not joined onto the canonical root"

# --- #272/#310 Task 4: oss_demo_workdir routes through the sole-repo default
# rule, not a literal `canonical`. Precedence: explicit > composition_root >
# sole-declared-repo > refuse listing repos. Two fresh topology fixtures,
# deliberately NOT $TMP (single-repo "canonical" pairing manifest, which every
# other assertion in this file depends on) - this block must not perturb it.

# (1) N=1, but the sole repo is NOT named canonical - exactly the case the OLD
# literal default could never resolve (it always looked up "canonical" by
# name, so a workspace whose only repo was named something else refused even
# though exactly one candidate existed). This is the direct fix this task
# ships, and a fixture the old code would have refused (RED against the old
# body: `_oss_repo_root canonical` fails because "core", not "canonical", is
# declared).
TMP3="$(mktemp -d)"
mkdir -p "$TMP3/.ossify"
cat > "$TMP3/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMP3/core"}},"well_known_paths":{}}
JSON
S3="$TMP3/state.json"; echo '{}' > "$S3"
cd "$TMP3"
t_capture oss_demo_workdir "$S3"
t_assert_rc 0 "sole repo resolves even when it is not literally named canonical"
t_assert_eq "$TMP3/core" "$T_OUT" "workdir is the sole declared repo's root"

t_capture oss_demo_workdir "$S3" "$TMP3/explicit-wd"
t_assert_rc 0 "explicit workdir still wins ahead of the default-repo tier"
t_assert_eq "$TMP3/explicit-wd" "$T_OUT" "explicit workdir echoed verbatim, no repo resolution attempted"
cd "$TMP"
rm -rf "$TMP3"

# (2) N>1, and one of the declared repos IS literally named canonical - the
# fail-safe case this task exists for. The OLD literal default resolved this
# SILENTLY (canonical happened to be declared, so it "worked" while ignoring
# the sibling repo entirely - precisely the wrong-repo risk #272/#310 names).
# The new rule must refuse rather than pick WHEN THE DEFAULT-REPO TIER IS
# ACTUALLY NEEDED. Spec section 3's precedence is EXPLICIT > composition_root >
# sole-declared-repo > refuse: an ABSOLUTE composition_root is a complete
# answer on its own and outranks the sole-declared-repo tier entirely, so it
# resolves even under N>1 (lib/demo.sh short-circuits on it before ever
# consulting the default-repo key). A RELATIVE composition_root still joins
# onto the DEFAULT repo's root (recorded deviation 2), so it still needs the
# lookup and still refuses under N>1, same as no composition_root at all.
TMP4="$(mktemp -d)"
mkdir -p "$TMP4/.ossify"
cat > "$TMP4/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"canonical":{"root":"$TMP4/canon"},"ui":{"root":"$TMP4/ui"}},"well_known_paths":{}}
JSON
S4="$TMP4/state.json"; echo '{}' > "$S4"
cd "$TMP4"
t_capture oss_demo_workdir "$S4"
t_assert_rc 2 "N>1 refuses (no composition_root) even though one declared repo is literally named canonical (no silent pick)"
t_assert_contains "$T_OUT" "canonical, ui" "refusal lists both declared repos"

jq -n --arg c "$TMP4/abs-comp" '{project:{composition_root:$c}}' > "$S4"
t_capture oss_demo_workdir "$S4"
t_assert_rc 0 "an ABSOLUTE composition_root outranks the sole-declared-repo tier - resolves even under N>1 (spec section 3)"
t_assert_eq "$TMP4/abs-comp" "$T_OUT" "the absolute composition_root is returned verbatim, no repo root ever consulted"

jq -n --arg c "rel-comp" '{project:{composition_root:$c}}' > "$S4"
t_capture oss_demo_workdir "$S4"
t_assert_rc 2 "a RELATIVE composition_root still needs the default repo's root, so N>1 still refuses"
t_assert_contains "$T_OUT" "canonical, ui" "same refusal, same listing"
cd "$TMP"
rm -rf "$TMP4"

# Clear it back to unset so the rest of this file's explicit-workdir calls
# keep resolving against $TMP/canon as they did before this sub-block.
oss_state_mutate "$S" set_composition "$(jq -n '{composition_root:null}')" >/dev/null

# The unscoped vacuous-green guard used to fail this: a recognized runner that
# legitimately exits 1 is NOT vacuous green. `# pytest` is NOT a no-op comment
# here for the purpose of this test: oss_verify_zero_tests_guard greps the RAW
# COMMAND STRING (not what actually executes) for a runner name, so without it
# this command is never recognized as a runner at all and the guard would stay
# silent regardless of scoping - proving nothing. Verified: mutating the guard
# back to unscoped does NOT red this assertion unless the command string
# itself matches a runner pattern AND the output shows a zero-tests phrase.
t_capture oss_ledger_add_auto "$S" r0.s1 "suite fails as expected" "bash -c 'echo 0 passing; exit 1' # pytest" "exit:1" active
t_capture oss_demo_run_auto "$S" "$TMP/canon"
t_assert_rc 0 "a recognized runner legitimately expecting exit:1 is not flagged vacuous"

# user: lines are surfaceable, and scopeable to one spine.
t_capture oss_ledger_add_user "$S" r0.s1 "reschedule a delivery and see the new window" "the slot moves" active
t_capture oss_ledger_add_user "$S" r0.s2 "cancel an order from the ticket" "the order clears" active
t_capture oss_demo_user_lines "$S" r0.s1
t_assert_eq "1" "$(printf '%s' "$T_OUT" | jq 'length')" "user lines scope to one spine (the §6.1 spine-close set)"
t_capture oss_demo_user_lines "$S"
t_assert_eq "2" "$(printf '%s' "$T_OUT" | jq 'length')" "unscoped returns every accumulated user line (the §6.2 walkthrough set)"

# a close leaves a durable record.
t_capture oss_demo_record_close "$S" spine r0.s1 true 2 "clean"
t_assert_rc 0 "close record written"
t_capture oss_state_read "$S" '.close_records[-1].scope'; t_assert_eq "spine" "$T_OUT" "scope recorded"
t_capture oss_state_read "$S" '.close_records[-1].demo_passed'; t_assert_eq "true" "$T_OUT" "demo outcome recorded"

# add_close_record round-trips through replay like every other op in
# _oss_apply_op: rebuilt-from-base+journal must equal live, not merely
# "the write succeeded". The id/timestamp are baked into the payload BEFORE
# journaling (see oss_demo_record_close), so a replay that reapplies the same
# journaled payload reproduces the record verbatim.
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay stays clean across add_close_record (and this file's other demo-ledger ops)"

# --- #269: the floor is on EXECUTED lines, not ledger lines. `n` counts
# active OR quarantined auto lines, so an empty ledger, a user-lines-only
# ledger, and an all-quarantined ledger each execute zero lines - and must
# report a distinct non-pass verdict at rc != 0, never `PASS 0 lines` rc 0.
# The `PASS 2` assertions above are the adjacent positive control: a run
# with real executed lines still passes. ---
TE="$(mktemp -d)"; SE="$TE/state.json"
oss_state_init "$SE" demo-empty >/dev/null
oss_entity_add_release "$SE" "demo" "goal" >/dev/null
oss_entity_add_spine "$SE" r0 "demo spine" bone canonical >/dev/null
t_capture oss_demo_run_auto "$SE" "$TMP/canon"
t_assert_rc 1 "#269: an EMPTY demo ledger is not a pass"
case "$T_OUT" in *"PASS 0"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: #269: vacuous 'PASS 0 lines' still emitted";; *) T_PASS=$((T_PASS+1));; esac
t_assert_contains "$T_OUT" "zero" "...and the verdict names the zero-execution"

oss_ledger_add_user "$SE" r0.s1 "look at the dashboard" "it loads" active >/dev/null
t_capture oss_demo_run_auto "$SE" "$TMP/canon"
t_assert_rc 1 "#269: a user-lines-only ledger still executes zero auto lines"

oss_ledger_add_auto "$SE" r0.s1 "flaky line" "true" "exit:0" active >/dev/null
# The user line above minted d1, so the auto line is d2 - select by type
# rather than hardcoding, so the fixture survives an id-scheme change.
oss_ledger_quarantine "$SE" "$(jq -r '[.demo_ledger[] | select(.type=="auto")][0].id' "$SE")" "quarantined for the fixture" >/dev/null
t_capture oss_demo_run_auto "$SE" "$TMP/canon"
t_assert_rc 1 "#269: an all-quarantined ledger executed zero lines - not a pass"
t_assert_contains "$T_OUT" "SKIP" "...the quarantined line is still reported as skipped"
rm -rf "$TE"

cd /
rm -rf "$TMP"

# ===========================================================================
# TOPOLOGY TWIN (#272/#310 Task 11, spec decision O1): the opening fixture's
# implicit-workdir demo-run sequence (all green / halt on first fail /
# quarantine skip / vacuous-green catch), run again from a SOLE-repo
# .ossify/topology.json named "core" - never "canonical". Every call below
# OMITS the workdir argument, so each one re-resolves
# `_oss_default_repo_key -> _oss_repo_root` through the topology shape
# exactly as the opening fixture resolves it through the translated pairing
# shape. TMP3/TMP4 further up already pin oss_demo_workdir's sole-repo/N>1
# rule directly (added by #272/#310 Task 4); this proves the FULL RUNNER -
# ledger read, halt, quarantine, vacuous-green - threads that resolution end
# to end, which is what the opening fixture actually demonstrates and TMP3/
# TMP4 do not (they call oss_demo_workdir alone, never oss_demo_run_auto).
#
# A fresh mktemp tree: none of this reuses $TMP (already rm -rf'd above) or
# TMP3/TMP4 (already rm -rf'd earlier in this file).
# ===========================================================================
TMPD="$(mktemp -d)"
mkdir -p "$TMPD/ws/.ossify" "$TMPD/core"
cat > "$TMPD/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPD/core"}},"well_known_paths":{}}
JSON
cd "$TMPD/ws"
SD="$TMPD/ws/.ossify/project-state.json"
oss_state_init "$SD" demo-run-twin >/dev/null
oss_entity_add_release "$SD" "demo" "goal" >/dev/null
oss_entity_add_spine "$SD" r0 "demo spine" bone core >/dev/null

oss_ledger_add_auto "$SD" r0.s1 "always true" "true" "exit:0" active >/dev/null
oss_ledger_add_auto "$SD" r0.s1 "greets" "echo hello-world" "contains:hello" active >/dev/null
t_capture oss_demo_run_auto "$SD"
t_assert_rc 0 "topology twin: all green"
t_assert_contains "$T_OUT" "PASS 2" "topology twin: pass count"

oss_ledger_add_auto "$SD" r0.s1 "always false" "false" "exit:0" active >/dev/null
t_capture oss_demo_run_auto "$SD"
t_assert_rc 1 "topology twin: halt on first fail"
t_assert_contains "$T_OUT" "FAIL d3" "topology twin: failing line named"

oss_ledger_quarantine "$SD" d3 "flaky env, fix by r1 close" >/dev/null
t_capture oss_demo_run_auto "$SD"
t_assert_rc 0 "topology twin: quarantined line skipped"
t_assert_contains "$T_OUT" "SKIP" "topology twin: skip reported"

oss_ledger_add_auto "$SD" r0.s1 "vacuous suite" "echo 'collected 0 items' # pytest" "exit:0" active >/dev/null
t_capture oss_demo_run_auto "$SD"
t_assert_rc 1 "topology twin: vacuous green caught"
t_assert_contains "$T_OUT" "vacuous-green" "topology twin: guard named"

# Take the vacuous line (d4) out of the active run so the AND-gate-precision
# check below can reach it - same reason the opening fixture quarantines its
# own d4 before this exact assertion (review round 1, finding 3: the twin
# had stopped one assertion short of the legacy sequence at :60-64).
oss_ledger_quarantine "$SD" d4 "test cleanup" >/dev/null
oss_ledger_add_auto "$SD" r0.s1 "legit zero-passing mention" "echo '0 passing warnings remain'" "contains:0 passing" active >/dev/null
t_capture oss_demo_run_auto "$SD"
t_assert_rc 0 "topology twin: non-runner output mentioning a zero-tests phrase is NOT vacuous-green (AND-gate precision)"

cd "$HERE"
rm -rf "$TMPD"

# ===========================================================================
# #770: the combined form `exit:<n>+contains:<str>`. A line passes only when its rc
# equals <n> AND its output holds the needle; each failure names the half that failed.
# One fresh state per case (halt-on-first-fail would mask a second case in one ledger),
# the line injected straight into state so these pins do not lean on the validator.
# ===========================================================================
T5="$(mktemp -d)"; mkdir -p "$T5/canon"; N5=0
_run_combined() { # $1=command $2=expected -> sets T_OUT/T_RC from oss_demo_run_auto
  N5=$((N5+1)); local sf="$T5/s$N5.json"
  oss_state_init "$sf" combined >/dev/null
  oss_entity_add_release "$sf" "demo" "goal" >/dev/null
  oss_entity_add_spine "$sf" r0 "demo spine" bone canonical >/dev/null
  oss_ledger_add_auto "$sf" r0.s1 "combined line" "$1" "exit:0" active >/dev/null
  jq --arg e "$2" '.demo_ledger[0].expected = $e' "$sf" > "$sf.x" && mv "$sf.x" "$sf"
  t_capture oss_demo_run_auto "$sf" "$T5/canon"
}
# End to end through the validator: add a combined line, run it.
SC="$T5/e2e.json"; oss_state_init "$SC" e2e >/dev/null
oss_entity_add_release "$SC" "demo" "goal" >/dev/null
oss_entity_add_spine "$SC" r0 "demo spine" bone canonical >/dev/null
t_capture oss_ledger_add_auto "$SC" r0.s1 "prints ok and exits 0" "echo ok" "exit:0+contains:ok" active
t_assert_rc 0 "a combined line is accepted by the validator"
t_capture oss_demo_run_auto "$SC" "$T5/canon"
t_assert_rc 0 "the accepted combined line runs and passes"; t_assert_contains "$T_OUT" "PASS 1" "...counted as passed"

_run_combined 'echo ok; exit 1' 'exit:0+contains:ok'
t_assert_rc 1 "#747's wrong-green: the needle printed but rc 1 when 0 is expected FAILS"
t_assert_contains "$T_OUT" "rc=1, wanted 0" "...and the failure names the exit half"
case "$T_OUT" in *PASS*) T_FAIL=$((T_FAIL+1)); echo "FAIL: a wrong-rc combined line printed PASS";; *) T_PASS=$((T_PASS+1));; esac
_run_combined 'true' 'exit:0+contains:ok'
t_assert_rc 1 "rc 0 without the needle FAILS"
t_assert_contains "$T_OUT" "output missing 'ok'" "...and the failure names the output half"
_run_combined 'echo ok' 'exit:0+contains:ok'
t_assert_rc 0 "rc and needle both right PASSES"; t_assert_contains "$T_OUT" "PASS 1" "...counted"
_run_combined "echo 'collected 0 items' # pytest" 'exit:0+contains:collected'
t_assert_rc 1 "exit:0+contains: on a recognised runner that ran zero tests FAILS"
t_assert_contains "$T_OUT" "vacuous-green" "...as vacuous-green"
_run_combined "bash -c 'echo 0 passing; exit 1' # pytest" 'exit:1+contains:0 passing'
t_assert_rc 0 "control: the guard is for <n> = 0 only - a runner expecting exit:1 with its needle passes"
_run_combined 'echo ok; exit 3' 'exit:3+contains:ok'
t_assert_rc 0 "a non-zero <n> matched with the needle passes"
_run_combined 'echo ok; exit 3' 'exit:2+contains:ok'
t_assert_rc 1 "a non-zero <n> that is not the rc FAILS even with the needle"; t_assert_contains "$T_OUT" "rc=3, wanted 2" "...naming the rc"
_run_combined 'echo a+contains:b' 'exit:0+contains:a+contains:b'
t_assert_rc 0 "the needle splits at the FIRST +contains: (it may hold +contains: itself)"
_run_combined 'echo b' 'exit:0+contains:a+contains:b'
t_assert_rc 1 "control: output holding only the tail of that needle FAILS"
_run_combined 'echo y' 'exit:99999999999999999999+contains:y'
t_assert_rc 1 "an exit operand past the integer range fails the line (an erroring test is not a pass)"
t_assert_contains "$T_OUT" "wanted 99999999999999999999" "...naming the exit half"
_run_combined 'true' 'exit:99999999999999999999'
t_assert_rc 1 "a PLAIN exit: operand past the integer range fails the line (was a silent PASS)"
t_assert_contains "$T_OUT" "wanted 99999999999999999999" "...naming the exit half"
_run_combined 'exit 3' 'exit:3'
t_assert_rc 0 "control: a plain exit:3 on a command that exits 3 still passes"
_run_combined 'echo y' 'exit:0x+contains:y'
t_assert_rc 1 "a non-digit operand before + fails closed"; t_assert_contains "$T_OUT" "malformed" "...as malformed"
_run_combined 'echo y' 'exit:0+contains:'
t_assert_rc 1 "an empty needle fails closed"
_run_combined 'echo y' 'exit:+contains:y'
t_assert_rc 1 "an empty exit operand fails closed"
_run_combined 'true' 'under 40ms'
t_assert_rc 1 "an unrecognised expected still fails closed"; t_assert_contains "$T_OUT" "exit:<n>+contains:<str>" "...and the grammar list names the combined form"

# ===========================================================================
# #761 item 5: demo_run and demo_user_lines check the schema before their first ledger
# read. A newer schema may carry line statuses this build does not know, and the run
# would report green over lines it never walked.
# ===========================================================================
SF0="$T5/future-base.json"; oss_state_init "$SF0" future >/dev/null
oss_entity_add_release "$SF0" "demo" "goal" >/dev/null
oss_entity_add_spine "$SF0" r0 "demo spine" bone canonical >/dev/null
oss_ledger_add_auto "$SF0" r0.s1 "would pass" "true" "exit:0" active >/dev/null
oss_ledger_add_user "$SF0" r0.s1 "walk the journey and see it" "seen" active >/dev/null
FUT=$((OSS_STATE_SCHEMA_VERSION + 1))
SFUT="$T5/future.json"; jq --argjson v "$FUT" '.schema_version = $v' "$SF0" > "$SFUT"
t_capture oss_demo_run_auto "$SFUT" "$T5/canon"
t_assert_rc 6 "demo_run on a state one schema above this build fails closed (rc 6, the check's own)"
t_assert_contains "$T_OUT" "requires a newer ossify" "...with the schema check's own message"
case "$T_OUT" in *PASS*) T_FAIL=$((T_FAIL+1)); echo "FAIL: demo_run printed PASS over a newer schema";; *) T_PASS=$((T_PASS+1));; esac
# A newer schema may reshape the ledger itself: the version check must answer BEFORE the
# first ledger read, or the read's own error ("cannot read state", rc 1) masks it.
SFUT2="$T5/future-reshaped.json"; jq --argjson v "$FUT" '.schema_version = $v | .demo_ledger = {"future": 1}' "$SF0" > "$SFUT2"
t_capture oss_demo_run_auto "$SFUT2" "$T5/canon"
t_assert_rc 6 "a newer schema with a reshaped ledger still answers with the version check, not the read error"
t_assert_contains "$T_OUT" "requires a newer ossify" "...naming the newer ossify"
t_capture oss_demo_user_lines "$SFUT"
t_assert_rc 6 "demo_user_lines on a newer schema fails closed too"
t_assert_contains "$T_OUT" "requires a newer ossify" "...with the check's message"
case "$T_OUT" in *journey*) T_FAIL=$((T_FAIL+1)); echo "FAIL: demo_user_lines listed lines from a newer schema";; *) T_PASS=$((T_PASS+1));; esac
# Adjacent controls: the current schema still runs and lists; the check does not cry wolf.
t_capture oss_demo_run_auto "$SF0" "$T5/canon"
t_assert_rc 0 "control: a current-schema state still runs"; t_assert_contains "$T_OUT" "PASS 1" "...and passes"
t_capture oss_demo_user_lines "$SF0"
t_assert_rc 0 "control: a current-schema state still lists its user lines"; t_assert_contains "$T_OUT" "journey" "...with the line"
# An older schema is refused with the same check's migrate message (every mutator already does).
SOLD="$T5/older.json"; jq --argjson v "$((OSS_STATE_SCHEMA_VERSION - 1))" '.schema_version = $v' "$SF0" > "$SOLD"
t_capture oss_demo_run_auto "$SOLD" "$T5/canon"
t_assert_rc 6 "demo_run on an older schema refuses too, naming migrate"; t_assert_contains "$T_OUT" "oss migrate" "...the check's own remedy"
# Dispatcher path (bin/* runs set -euo pipefail; the libs above are sourced without it).
OSSX="$HERE/../bin/oss"
t_capture "$OSSX" demo_run "$SFUT" "$T5/canon"
t_assert_rc 6 "dispatcher: demo_run on a newer schema is rc 6"; t_assert_contains "$T_OUT" "requires a newer ossify" "dispatcher: the check's message"
t_capture env "OSS_STATE_FILE=$SFUT" "$OSSX" demo_user_lines
t_assert_rc 6 "dispatcher: demo_user_lines on a newer schema is rc 6"
t_capture "$OSSX" demo_run "$SF0" "$T5/canon"
t_assert_rc 0 "dispatcher control: a current-schema state still runs"
rm -rf "$T5"

t_summary
