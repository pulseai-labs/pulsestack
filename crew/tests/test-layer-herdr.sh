#!/usr/bin/env bash
#
# crew — the herdr mechanics contract, mechanical facts only.
#
# herdr --skill documents CLI syntax. This reference states only what that
# guide cannot: the seat launch sequence built from agents.md's command:, the
# two readiness paths, the report-file completion contract, and placement.
#
# Counting is one awk index() pass, hoisted to _helpers.sh with the pin/present
# wrappers (#514, L1): `grep -c` counts LINES, and `… | grep -q` can fail on a
# true match under pipefail.
#
# Usage: bash crew/tests/test-layer-herdr.sh
# Deps:  bash 3.2+, awk.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REF="$PLUGIN_ROOT/skills/orchestrate/references/layers/herdr.md"
COMP="$PLUGIN_ROOT/skills/orchestrate/references/completion.md"
ROLES="$PLUGIN_ROOT/skills/orchestrate/references/roles.md"
LIFE="$PLUGIN_ROOT/skills/orchestrate/references/lifecycle.md"
SKILL_MD="$PLUGIN_ROOT/skills/orchestrate/SKILL.md"
# 235, raised from 204 during T3 (2026-09-22): the pilot measured eight mechanics the file
# had wrong or missing — the two detection events, the worktree path's workspace label and
# `result.root_pane.pane_id` and its source-repo `--cwd`, the source-repo workspace that
# `worktree remove` leaves open, the undetected caveat's remedy, the doorbell's generation
# rule and a detected coordinator's `--until blocked` wait beside it, `enter` as the submit
# key, and which ask governs the completion wait. Every addition is a clause: the file went
# 201 -> 233 lines (+32: numstat 56 insertions, 24 deletions) and the gate rose 204 -> 235
# (+31). The gate still fails over the limit; #574's widened doorbell predicate and #575's
# mutually-cancelling companion wait spent the two-line slack (233 -> 235, 2026-09-24).
#
# 204, raised from 200 during PR #513's review rounds: this file's budget is this
# port's own invention (orca-crew has no mechanics reference), and the rounds' P1
# fixes — the run workspace's per-server allocation, the first seat's cwd, the
# agent_blocked re-send — needed room that eight content-neutral trades could not
# keep finding.
# 237, raised from 235 during #574/#575's fix round (2026-09-24): the review's three
# completions — the dispatch-time step now notes what the doorbell compares (the hash and
# the file's identity), the doorbell paragraph refers back to that note instead of
# restating the rule, and a detected coordinator's answered dialog re-arms the pair — added
# two lines, 235 -> 237, to a file that entered the round at its gate (233 -> 235 having
# spent the previous slack). The two lines are mechanics the file exists to state, so the
# gate rose with them; it still fails over the limit.
# 0.2.2 (seat-mods) added the guarded-seat paragraph to the launch's step 2 — the two
# --env flags, the scratch directory and who never gets them: six lines, 237 -> 243,
# again mechanics the file exists to state. The operator-facing rule (never in settings.json)
# first lived only in seat-mods' README. The final review restored it here (spec §5 binds
# both places) with an ossify implementer's handoff directory: two lines, 243 -> 245.
# 0.2.3 (#640) added the worker ping and the heartbeat backstop: the ping line, the
# generation-first consumption rules — including what deduplication does NOT suppress, a
# live dialog and the tick's health check — the wrong-path refusal, and the heartbeat's
# classification and kill points. +27 lines on insertion, traded back 12 (detection events,
# the wait-output caveat, the typed-wait set, the two-dead-ends and doorbell paragraphs, the
# launch intro and steps 1/3/5, and the teardown close paragraph) to land at 260. The gate
# rose with the mechanics the file exists to state and still fails over the limit.
# 0.2.5 (#651 part 5) made step 2 state the guard's own reach — a coordinator's child
# seats and every replacement launch — and list the coordinator classes as unguarded,
# with the status line read at the model read: four lines, 260 -> 264. Fix round 1 put the
# guard in its pane-run form, where the launcher's own shell cannot arm itself, and added
# the replaces: rule: two lines, 264 -> 266.
# 0.2.7 (seat-mods 0.2.0) rewrote step 2 as seat marking — the two free roles' exports, the
# operator's own top, and the #658 fold-ins (<run dir>, the banner status read, the
# missing-status-line route and disposition): the paragraph grew with the mechanics it
# exists to state and the gate rose with it, 266 -> 272. Fix round 1 added the operator-role
# class (guarded as implementer, with its report and scratch directories in SEAT_MODS_ALLOW)
# and the once-only dsh carve-out, deleted the vestigial 0.2.5 binding sentence and reworded
# the guarded sentence's actor: 272 -> 275. The adjacent control runs the same predicate on a
# file one line over the real reference and, when that is accepted, names the remedy (lower
# REF_BUDGET to the real file's count) instead of reading as an over-budget failure.
REF_BUDGET=223  # 2026-10-18 (D1): -16 — the #867 tag paragraphs (the tag rule, what stays
# untagged, the role words) moved to completion.md, where the ping contract is stated once
# for every layer — an Orca seat's ping reaches the top as the same text. The layer's `Send`
# keeps the send itself, its bullets and the turn-start check. 239 -> 223.
# 2026-10-18 (merge of origin/main, crew 0.3.1): +16 — `## Send` gains the
# #867 tag paragraphs (the tag rule, what stays untagged, the role words): 223 -> 239.
# 2026-10-18 (V13 fix): -1 — the Machines step dropped the halt it restated
# for an unknown `host:` value (`config.md` owns it); the label mapping stays. 224 -> 223.
# 2026-10-18 (Task 13): +4 — the machine file's `host:` key now maps to this
# layer's labels in `## Machines`, and that Machines names the cross-machine report read a
# known limit (the route is measured on the Orca layer only).
# 2026-10-18 (T11 ruling A): the layer-neutral OMP-host rules moved to SKILL.md
# §3, where they are stated once with the skill, so the count went 227 -> 220.
# 2026-10-18 (crew 0.3.1, #867 fix round, main's own count): `## Send`'s tag scope, its
# untagged list and the `orchestrator` role word were four lines there, 239 -> 243.
# 2026-10-18 (round 3): the machine-file key left 0.3.0 for 0.4.0 and took the
# `## Machines` pointer to it with it (one line), so the count went 228 -> 227.
# 2026-10-17: crew 0.3.0 Task 4 — the `## Send` section gained the PING_SEND
# slot definition and its one-line statement (3 lines), so the count went 225 -> 228.

# shellcheck source=/dev/null
. "$SCRIPT_DIR/_helpers.sh"

# occurrences, occurrences_flat, count_of, pin and present are _helpers.sh's
# (#514, L1). The counter here had its own copy, and the flat one its own
# signature — it took the needle alone and bound $REF itself — so the two copies
# of the squeezed-line counter had already diverged between this suite and the
# ossify one. What is left here is this suite's own: nothing.

printf '%screw herdr layer contract%s\n\n' "$DIM" "$RST"

if [ ! -f "$REF" ]; then
  fail "layers/herdr.md exists" "no such file"
  report; exit $?
fi

section "the launch sequence"
for v in 'herdr workspace create' 'herdr tab create' 'herdr pane run' 'herdr pane read' 'herdr agent prompt'; do
  present "$REF" "$v" "the sequence names $v"
done
present "$REF" 'herdr worktree create' "a worktree seat names herdr worktree create"

section "the two readiness paths"
present "$REF" 'herdr agent wait' "the detected path names agent wait"
present "$REF" 'herdr pane wait-output' "the undetected path names pane wait-output"
present "$REF" '--until done --until idle --until blocked' "the typed wait names all three settled states"
present "$REF" "--match '<expected_model:>'" "the undetected path waits on the seat's own expected_model:"
pin "$REF" 'herdr agent list' "the discriminator is named once"
pin "$REF" 'a match on the echoed command line does not count' "#751-herdr-echo: a wait-output match on the echoed launch command is not the model read" flat
c="$(count_of "$REF" 'Caveat: it searches existing output' flat)"
if [ "$c" -eq 0 ]; then pass "#751-herdr-caveat: the echoed-command warning is a rule, not a caveat"
else fail "#751-herdr-caveat: the echoed-command warning is a rule, not a caveat" "the caveat is back ($c)"; fi
pin "$REF" 'must show `expected_model:` on a line the command cannot produce' "#751-herdr-read: the model read confirms expected_model: off the command line" flat
pin "$REF" 'reported upward and never worked around' "#751-herdr-mismatch: a model mismatch is reported upward, never worked around" flat
pin "$REF" 'Only `The model` read decides' "B2: the model read, never the wait's match, decides the launch" flat
pin "$REF" 'wait with `--regex` on it plus banner text the command lacks' "B2: the undetected wait keeps a remedy for the echoed command" flat
pin "$REF" "shows the TUI is up only on a line the command cannot produce" "B2: the match shows the TUI is up only off the command line" flat
pin "$REF" "or neither once the readiness wait's bound ends is a failed launch" "B2: a screen showing neither result at the bound is a failed launch" flat

pin "$REF" '`agent get`/`agent wait` answer `agent_not_found`: ask again for up to five seconds, then take the not-detected path' "a detection ask before the record is retried, then bounded (#845)" flat

section "the rules that must survive a rewording"
pin "$REF" 'never `pane split`' "the no-split rule survives"
pin "$REF" 'invoked by name' "the lane-by-name rule survives"
pin "$COMP" 'the file is the contract' "the report-file contract survives"
pin "$COMP" 'placed outside every seat'"'"'s worktree' \
  "every file the run keeps lives outside every seat's worktree (R39)"
pin "$COMP" 'and so is a coordinator'"'"'s' \
  "a coordinator seat is waited on through its report file (R41)"
pin "$REF" 'A local slash command (`/context`, `/clear`) settles without a turn' \
  "a local slash command is sent without the turn-start check (R42)"

# #574: the doorbell's predicate. Both halves are pinned — a revert to the hash alone kills
# the first, and dropping the comparison leaves the identity remedy recorded but unread,
# which is the half the issue exists for.
pin "$COMP" 'the identity noted beside it differs' \
  "the doorbell's wait compares the noted identity, not the hash alone (#574)"
pin "$COMP" 'Both are compared, not merely recorded' \
  "the noted identity is compared, not merely recorded (#574)"

# #575: the detected coordinator's companion wait, made mutually cancelling — each wake
# disarms the other, so a dispatch leaves at most one armed wait.
pin "$COMP" 'and it ends the doorbell' \
  "the companion's blocked wake ends the doorbell (#575)"
pin "$COMP" "The doorbell's return — a new report or its timeout — ends the companion" \
  "the doorbell's return ends the companion: one armed wait per dispatch (#575)"

# The fix round's completions. #574's dispatch-time step now notes the identity the
# doorbell compares — and "note the file's identity" is stated once, so the doorbell
# paragraph refers back to that note rather than restating the identity tuple.
pin "$COMP" "and the file's identity" \
  "the dispatch-time note records the file's identity beside the hash (#574)"
# Count flat so a restatement split at a markdown wrap still counts twice.
pin "$COMP" 'inode with mtime' \
  "#587g: the identity tuple always includes the inode and is defined once" flat
pin "$COMP" 'the identity noted at dispatch' \
  "the doorbell paragraph refers back to the dispatch-time note (#574)"
# #650 R1-1: one generation rule. The typed wake's novelty test must be the same
# hash-or-identity comparison the ping and the doorbell use; hash alone is the old
# form, and it read a byte-identical atomic replacement as a false wake.
pin "$COMP" 'a different hash or identity' \
  "the typed wake's novelty is the same hash-or-identity generation (#650 R1-1)" flat

# #575: the pair is re-armed, not restarted, after a dialog the operator answered.
pin "$COMP" "The companion's own timeout, while the doorbell is still armed, is no checkpoint" \
  "a companion timeout under a live doorbell lapses silently (#651 B)" flat
pin "$COMP" '**A stall** is the one exception to a silent `working`' \
  "the heartbeat names the stall rule (#651 D)" flat
pin "$COMP" 'is a seat failure, not a failed task' "a stall is a seat failure, never a task failure (#651 D)" flat
pin "$COMP" "then launch the fallback the project file's" "a stall launches the declared fallback (#651 D)" flat
pin "$COMP" 'stall with no fallback named, is reported to the operator once' "no declared fallback goes to the operator (#651 D)" flat
pin "$COMP" 'Settle its dispatch first (stop its report-file wait and companion by job id' "a stalled dispatch is settled before its fallback launches (#651 D, round 1)" flat
pin "$COMP" 'Stop a wait, companion or heartbeat by its job id: OMP `write proc://<job id>/kill`, Claude Code `TaskStop`, a shell process this session started by its exact PID or job id; never a process listing' "each host's job stop is named, never a listing fed to kill (#1099)" flat
present "$SKILL_MD" 'Never signal processes by listing them' "the orchestrator rules forbid a listing-fed kill (#1099)" flat
pin "$COMP" 'the seat'"'"'s last report when it wrote one' "a stall before any report still has a brief (#651 D, round 1)" flat
pin "$COMP" 'A seat a fresh session cannot resume (the cuts the molt paragraph below lists) gets no fallback' "a non-resumable seat is never auto-replaced (#651 D, round 1)" flat
pin "$REF" "a timeout is the checkpoint \`completion.md\` states (a doorbell companion's excepted: it lapses)" "the typed wait carries the companion's exception (#651 B, round 1)" flat
pin "$COMP" "*A timeout is a checkpoint* (but a doorbell companion's, which lapses;" "the dead-end definition carries the companion's exception (#651 B, round 1)" flat
pin "$LIFE" "the two dead ends, the ping and the heartbeat are \`completion.md\`'s, stated there once" "lifecycle step 5 points at completion.md for the wake's meaning (#651 B, round 1)" flat
pin "$COMP" 'An answered dialog re-arms the pair' \
  "an answered dialog re-arms the pair (#575)"
pin "$COMP" 'the doorbell and its companion again, not one wait' \
  "the fresh wait after an answer is the pair again, not one wait (#575)"

pin "$LIFE" 'a detected coordinator re-arms the pair (`completion.md`)' "#587a: dialog re-arm distinguishes the coordinator pair" flat
pin "$LIFE" 'then one fresh bounded wait; a detected coordinator' "B2: a detected leaf dialog re-arms one fresh bounded wait" flat
pin "$COMP" 'Before dispatch, clear or move an acknowledged report' "#587b: report clearance is an instruction" flat
pin "$COMP" 'never a second settled-state wait (the coordinator' "#587c: false-wake rule permits the blocked companion" flat
pin "$COMP" 'An answered dialog re-arms the pair: the doorbell' "#587f: dialog rule names the pair directly" flat
pin "$REF" "--regex '[0-9.]+[kKmM]? */ *[0-9.]+[kKmM]? tokens' --source visible --timeout 5000" "#515herdr: context waits on a rendered figure with a bound" flat
pin "$REF" 'accept only a figure that differs from the pre-send screen' "#515fresh: only a changed figure proves freshness" flat
pin "$REF" 'at most 5 times, with `sleep 1` between reads' "C6: herdr rereads have a count and spacing" flat
pin "$REF" 'No changed figure or a wait timeout means figure unavailable, treated as past half: the next item goes to a fresh seat' "C6: herdr exhaustion or timeout rotates the next item" flat
pin "$ROLES" "the layer's Send owns its bounded figure read and unavailable result" "#515roles: retention routes to the layer probe" flat
pin "$LIFE" "use the layer's bounded \`/context\` reads and unavailable result" "C5: lifecycle routes to the layer probe and its unavailable result" flat
pin "$SKILL_MD" "the layer's bounded \`/context\` reads and unavailable result" "C5: the read licence permits the layer probe reads" flat
pin "$REF" "--regex '<pattern>' --source visible --timeout <ms>\` for \`/context\`" "N3: the Read list names the rendered context regex" flat
pin "$REF" 'submits text and Enter as one submission' "N7: the detected send remains one submission" flat

# Task 5 (crew 0.3.0): the identity reads live in the layer's `Identity`; the shared files
# name the step and hold the rules, so a shared file carries no env var name and the layer
# file is where a rotation's workspace and the agent session are read from.
section "orchestrator identity through the layer"
present "$REF" 'HERDR_PANE_ID' "the layer's Identity names the pane env var"
present "$REF" 'HERDR_WORKSPACE_ID' "the layer's Identity names the workspace env var"
pin "$REF" '.result.pane.agent_session.agent' "the layer's Identity names the agent-session read once"
pin "$LIFE" 'and `run.orchestrator.session` from the layer'"'"'s Identity' \
  "step 1 takes the session from the layer's Identity" flat
present "$LIFE" 'names its own address from the layer'"'"'s Identity' \
  "a molted-in-place top confirms its address from the layer's Identity" flat
# The rebind rule is stated once and carried to its two lifecycle sites — step 1's bind and
# The resume's step 2 — so a reword that drops the layer's Identity from either one fails
# here. Counted flat: the rule may break at any point in either copy.
rebind_sites="$(count_of "$LIFE" 'A session that binds an existing `run.json` rewrites `run.orchestrator` to its own address from the layer'"'"'s Identity' flat)" \
  || rebind_sites=failed
if [ "$rebind_sites" = failed ]; then
  fail "lifecycle binds through the layer's Identity at step 1 and The resume" \
    "count failed — unreadable file or empty needle"
elif [ "$rebind_sites" -eq 2 ]; then
  pass "lifecycle binds through the layer's Identity at step 1 and The resume (2)"
else
  fail "lifecycle binds through the layer's Identity at step 1 and The resume" \
    "found $rebind_sites, expected 2"
fi

section "placement"
present "$REF" '--cwd' "a seat's tree is set with --cwd"
present "$REF" '--label' "a seat's tab is labelled"
present "$REF" '--base <base-branch>' "a worktree seat's base is a slot, not a literal"

# The one gate: both the real check and its control go through this predicate, so the
# control cannot re-implement a comparison this suite may have changed (#651 fix round 1,
# N4). An unreadable file is refused, not counted.
within_budget() { # <file>
  [ -r "$1" ] || return 2
  [ "$(wc -l < "$1" | tr -d ' ')" -le "$REF_BUDGET" ]
}

section "molt children (0.2.8)"
pin "$ROLES" '**The launch environment.**' "roles.md holds the marking clause" flat
pin "$ROLES" 'MOLT_HANDOFF=parent MOLT_STATUS_PATH=<REPORT_PATH>.molt-status' \
  "the launch block names the child marking exactly" flat
pin "$ROLES" 'every guarded seat, every coordinator seat and every operator-declared role' \
  "the launch block marks every child kind" flat
pin "$ROLES" 'The operator'"'"'s first top and the top'"'"'s rotation successor are roots and take neither' \
  "the launch block never marks the top" flat
pin "$ROLES" '**A molt is not a launch.**' "a molt keeps the top's marking" flat
pin "$ROLES" 'A respawned child is a launch: this runs again in full' \
  "a respawn re-runs the marking, the allow list and the status-line read (Review Focus 6)" flat
pin "$COMP" '## A child past molt'"'"'s warnings' "completion.md holds the parent rules once" flat
# crew 0.3.1 (#867): the send is tagged; completion.md names the tag and keeps the legacy
# form accepted for briefs older than 0.3.1.
pin "$COMP" '[crew molt <role>] <pct> <task id>' "the tagged ping text is named" flat
pin "$COMP" 'MOLT WARNING <pct> <task id>' "the legacy ping text stays accepted" flat
pin "$COMP" 'per tick, per live seat, also reads its recorded status file' \
  "the heartbeat reads each child's status file (Review Focus 2)" flat
pin "$COMP" 'note it and send that seat no new unit' "a warned child gets no new unit" flat
pin "$COMP" 'launched from the same row, marked the same, with a fresh `REPORT_PATH`' \
  "a respawn takes a fresh REPORT_PATH, so a fresh status file (Review Focus 1)" flat
pin "$COMP" 'RESUME FROM: <handoff path>' "the respawned brief names the handoff" flat
pin "$COMP" 'it reuses its predecessor'"'"'s scratch directory' \
  "a respawn keeps the report and scratch directories writable (Review Focus 6)" flat
pin "$COMP" 'run-spine re-enters a started spine, mid-round included, so respawn it as a `rotate:` is' \
  "a spine cut mid-round is respawned under ossify 1.14.0, not relayed (#674)" flat
pin "$COMP" 'only that halt goes to the operator' "a re-entry halt still goes to the operator (#674)" flat
c="$(count_of "$COMP" 'relay it to the operator with its handoff path: a spine session' flat)"
if [ "$c" -eq 0 ]; then pass "the relayed-cut list no longer names the spine session (#674)"
else fail "the relayed-cut list no longer names the spine session (#674)" "$c left"; fi
pin "$COMP" 'relay it to the operator with its handoff path' "a skill-run cut is relayed" flat
# Final review (0.2.8) — each pin is one finding.
pin "$COMP" 'not a report ping: it names no path' "the tagged molt ping gets no correction request" flat
pin "$COMP" 'Record that path per seat at launch' "a retained seat's status file is the launch one" flat
pin "$COMP" 'its next unit (a fix round, a re-check, the next item) goes to a fresh seat' \
  "a warned seat's next unit goes to a fresh seat, so the run never stalls" flat
pin "$COMP" 'never a new `worktree create`' "a respawned implementer keeps its predecessor's worktree" flat
pin "$COMP" 'Close the predecessor'"'"'s pane only after the new tab exists' "the old pane outlives the new tab" flat
pin "$COMP" 'every respawn, after `rotate:` and `open:` included' "a rotate/open respawn takes a fresh REPORT_PATH too" flat
pin "$COMP" 'whose seat has returned no `rotate:`, `open:` or `handoff:`' \
  "a handed-off line that is a return's own respawns nothing twice" flat
# PR #671 round 1.
pin "$COMP" 'Before a retained seat'"'"'s next unit, read its recorded status file' \
  "an idle retained seat's status is read before it gets another unit" flat
pin "$COMP" 'a reviewer that hands off before its report validates' \
  "a reviewer cut mid-review goes to the operator, never a second review" flat
# PR #671 round 2.
pin "$COMP" 'settle the predecessor'"'"'s dispatch first' "a status-only handoff retires the old wait before the respawn" flat
pin "$COMP" 'a work-PR session that hands off with no `open:`' "a work-PR cut mid-round goes to the operator" flat
pin "$ROLES" 'SEAT_MODS_ALLOW=<REPORT_PATH'"'"'s directory>:<its scratch directory> MOLT_HANDOFF=parent MOLT_STATUS_PATH=<REPORT_PATH>.molt-status' \
  "the launch block's quoted guarded export carries the molt marking" flat

section "the launch export carries no retired-plugin variable"
RETIRED='AUTO''NOMIC'
c="$(count_of "$ROLES" "$RETIRED" flat)"
if [ "$c" -eq 0 ]; then pass "roles.md names no retired-plugin variable"
else fail "roles.md names no retired-plugin variable" "$c left"; fi
pin "$ROLES" 'MOLT_HANDOFF=parent MOLT_STATUS_PATH=<REPORT_PATH>.molt-status The names mean:' "the guarded export ends at the molt marking" flat
c="$(count_of "$ROLES" "MOLT_STATUS_PATH=<REPORT_PATH>.molt-status AUTO""NOMIC" flat)"
if [ "$c" -eq 0 ]; then pass "the guarded export ends at the molt marking"
else fail "the guarded export ends at the molt marking" "$c left"; fi
c="$(count_of "$COMP" "child's pain" flat)"
if [ "$c" -eq 0 ]; then pass "completion.md has no child-pain paragraph"
else fail "completion.md has no child-pain paragraph" "$c left"; fi

section "OMP top (0.2.19)"
pin "$REF" '## Host: OMP' "the layer file carries the OMP host mapping"
# T11 ruling A: the host substitutions shared with every layer moved to SKILL.md.
# Their pins read the shared file, and the layer file must not restate them.
pin "$SKILL_MD" 'crew'"'"'s `hooks.json` does not run on omp' "the ceiling notice on omp comes from molt (SKILL.md)" flat
present "$SKILL_MD" 'A send'"'"'s slash command is text on omp' "the send-as-text mapping lives with the skill" flat
c="$(count_of "$SKILL_MD" 'New enrolled OMP path only' flat)"
if [ "$c" -eq 0 ]; then pass "the enrolled-OMP authority rules are gone from the skill"
else fail "the enrolled-OMP authority rules are gone from the skill" "$c left"; fi
for moved in 'text on omp'; do
  c="$(count_of "$REF" "$moved" flat)" || c=failed
  if [ "$c" = "0" ]; then pass "the layer file does not restate: $moved"
  else fail "the layer file does not restate: $moved" "$c left"; fi
done
pin "$LIFE" 'a launch command for each host' "the rotation handoff records both hosts' launch commands"
pin "$LIFE" 'a resolved profile beside a launch command for each host' "the rotation handoff records each host's resolved profile"
pin "$LIFE" 'using the destination host'"'"'s recorded profile for the readiness path and model read' "the successor uses its destination host's profile" flat

pin "$LIFE" 'without it, the path as its first instruction on either' "a cross-host resume keeps the no-ossify route" flat
pin "$LIFE" '(`skill://handoff` on OMP)' "an OMP top writes its handoff with the OMP skill spelling"
pin "$LIFE" 'the other host'"'"'s profile resolved from its machine-file entry like any seat'"'"'s' "the other host's profile comes from its machine-file entry" flat
pin "$LIFE" 'a detected coordinator'"'"'s companion included' "a new top re-arms a coordinator's companion wait" flat
pin "$REF" 'pass `timeout: 0` on every one' "OMP async waits disable the command deadline (#845)" flat
pin "$REF" 'never pass `name:`, which puts omp'"'"'s bash in service mode' "OMP async waits never pass name: (#845)" flat
pin "$REF" '0 disables it), so herdr'"'"'s `--timeout` bounds the wait' "OMP: timeout 0 is why herdr's --timeout bounds the wait (#845)" flat

section "budget"
n="$(wc -l < "$REF" | tr -d ' ')"
if within_budget "$REF"; then pass "layers/herdr.md within the reference budget ($n lines)"
else fail "layers/herdr.md within the reference budget" "$n lines, over by $((n - REF_BUDGET))"; fi
# Adjacent control (#651, fix round 1 N4): the fixture is one line longer than the REAL
# reference file and the SAME predicate must refuse it. A REF_BUDGET-derived fixture
# cannot see the constant move — raise REF_BUDGET and budget+1 scales with it, leaving the
# control green — so this one is derived from the file: a gate rebuilt around a raised
# constant accepts the fixture and fails here.
ctl="$(mktemp)"
awk -v n="$(( $(wc -l < "$REF" | tr -d ' ') + 1 ))" 'BEGIN { for (i = 0; i < n; i++) print "x" }' > "$ctl"
if within_budget "$ctl"; then
  fail "control: one line over the real reference file is refused" "accepted $(wc -l < "$ctl" | tr -d ' ') lines at REF_BUDGET=$REF_BUDGET — the real reference is $n lines; lower REF_BUDGET to $n"
else
  pass "control: one line over the real reference file is refused"
fi
rm -f "$ctl"

section "no personal name ships"
hits=0
for needle in claude-glm claude-glm-flash claude-sol glm-5.3 Fable; do
  hits=$((hits + $(occurrences "$REF" "$needle")))
done
if [ "$hits" -eq 0 ]; then pass "no personal name in layers/herdr.md"
else fail "no personal name in layers/herdr.md" "$hits occurrence(s)"; fi

# #514, L1: the shape, asserted rather than assumed — a counter re-copied into any
# suite shadows the hoisted one and keeps passing.
section "the hoisted counters are not re-copied"
assert_hoisted_counters

report
