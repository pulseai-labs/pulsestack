#!/usr/bin/env bash
#
# crew — the Orca layer contract, mechanical facts only.
#
# `orca skills get orca-cli` and its --help text are the command reference.
# This reference states only what that guide cannot: the seat launch sequence
# built from agents.md's command:, the one wait, the send, the read, teardown
# and machines — and the traps the 2026-10-18 probes measured.
#
# Several pins are EXACTLY ONCE by design: the launch export carries the child
# marking (`MOLT_HANDOFF=parent`) once (#666/#667 would return with a second
# copy or none), the PING_SEND slot is one send, and the typed wait is one
# call — so a restatement fails its pin rather than passing twice.
#
# Counting is one awk index() pass, hoisted to _helpers.sh with the pin/present
# wrappers (#514, L1): `grep -c` counts LINES, and `… | grep -q` can fail on a
# true match under pipefail.
#
# Usage: bash crew/tests/test-layer-orca.sh
# Deps:  bash 3.2+, awk.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REF="$PLUGIN_ROOT/skills/orchestrate/references/layers/orca.md"

# shellcheck source=/dev/null
. "$SCRIPT_DIR/_helpers.sh"

printf '%screw orca layer contract%s\n\n' "$DIM" "$RST"

if [ ! -f "$REF" ]; then
  fail "layers/orca.md exists" "no such file — the layer these pins read cannot come from a file that is not there"
  report; exit $?
fi

section "identity (probes §1)"
pin "$REF" 'ORCA_TERMINAL_HANDLE' "the own-handle variable is named exactly once"
present "$REF" 'ORCA_WORKTREE_ID' "the worktree id is recorded beside it"
present "$REF" 'ORCA_RUNTIME_SOURCE_INCARNATION' "the runtime incarnation is recorded beside it"
pin "$REF" 'terminal_handle_stale' "the stale-handle refusal is named exactly once"
present "$REF" 'no agent session id' "the terminal-show limit is stated as the evidence shows it"
present "$REF" 'terminal show' "the stand-down read is the terminal-show call"
present "$REF" 'incarnation' "an incarnation mismatch is the staleness test"

section "run workspace and worktrees (probes §0)"
pin "$REF" 'orca worktree set' "the workspace-status call is named exactly once"
pin "$REF" 'orca worktree create' "the worktree step names the create call exactly once"
present "$REF" '--no-parent' "the probed lineage flag survives"
present "$REF" 'terminal_worktree_mismatch' "the selector trap is named"
present "$REF" 'default shell' "the tab worktree create opens is accounted for"
present "$REF" 'orca worktree rm' "the worktree release is named"

section "seat launch (probes §2)"
pin "$REF" 'MOLT_HANDOFF=parent' "the child marking is in the launch export exactly once (#666/#667)"
present "$REF" 'SEAT_MODS_ROLE=' "the export's role variable is named"
present "$REF" 'MOLT_STATUS_PATH=' "the export's status path is named"
present "$REF" 'MOLT_STATUS_PATH=<REPORT_PATH>.molt-status; <lane>' "the export ends at the molt marking, then the lane"
present "$REF" 'exec <lane>' "the never-exec-a-lane trap is stated"
present "$REF" 'expected_model:' "the model read checks the expected model"

section "the one wait (probes §3, §4)"
pin "$REF" '--for tui-idle' "the typed wait is named exactly once"
pin "$REF" 'as a background job' "the completion wait runs as a background job exactly once"
present "$REF" '--timeout-ms' "the wait is bounded"
present "$REF" 'not of the work' "a turn's end is not the work's end"
present "$REF" 'blockedReason' "the dialog wake is named"

section "send (probes §3)"
pin "$REF" 'PING_SEND=orca terminal send --terminal <that terminal> --enter --text' "the PING_SEND slot is the probed send exactly once"
pin "$REF" '--wait-submit' "the turn-start proof is named exactly once"
pin "$REF" '--retry-request' "the transport-failure retry is named exactly once, never a resend"
present "$REF" 'not probed' "the one-host limit is stated where the form is"
pin "$REF" 'at most 5 times, with `sleep 1` between reads' "C6: Orca rereads have a count and spacing" flat
pin "$REF" 'accept only a figure that differs from the pre-send screen' "#515orcafresh: only a changed figure proves freshness" flat
pin "$REF" 'No changed figure means figure unavailable, treated as past half: the next item goes to a fresh seat' "C6: Orca exhaustion rotates the next item" flat

section "read (probes §3)"
pin "$REF" '--screen' "the rendered read is named exactly once"
present "$REF" 'tail[]' "the read paths the receipt's tail"
present "$REF" 'raw newlines' "the raw-newline trap is stated"

section "teardown (probes §Teardown)"
present "$REF" 'orca terminal close' "the terminal close is named"
present "$REF" '--all' "the worktree-wide close is named"
present "$REF" 'shared checkout' "the shared-checkout exception is stated"

section "machines (probes §5)"
pin "$REF" '--environment' "the environment selector is named exactly once"
present "$REF" 'orca host list' "the listing that names what to pass is named"
present "$REF" '--host' "the wrong-target selector is named"

section "no personal name ships"
hits=0
for needle in claude-glm claude-glm-flash claude-sol glm-5.3 Fable draco; do
  hits=$((hits + $(occurrences "$REF" "$needle")))
done
if [ "$hits" -eq 0 ]; then pass "no personal name or host in layers/orca.md"
else fail "no personal name or host in layers/orca.md" "$hits occurrence(s)"; fi

section "the hoisted counters are not re-copied"
assert_hoisted_counters

report
