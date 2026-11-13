# ossify spine briefs

The four briefs `ossify-execution.md` needs. Same rules as `briefs.md`: a brief
is the whole contract its reader will ever see, angle brackets are slots, fill
every slot and delete nothing else.

> **Editing note.** Asserted to contain no subagent invocation form
> (`tests/test-ossify-spine-contract.sh`): say the prohibition, never the call shape.

---

## Spine session (one per spine, dispatched by the top orchestrator)

The lane driver, launched **from the `spine session` seat the project file names** —
the top copies its approved profile in — and marked `coordinator` before its command
(the layer's `Seat marking`). A coordinator too, so it carries scope identities.

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

ROLE: ossify spine session and nested coordinator.

PLACEMENT: <abs path of the repo or worktree the lane runs from>.

INJECTED IDENTITIES — use these verbatim; do not rediscover them:
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report coordinator] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
RUN_JSON=<abs path of the run.json you write and own — never the top's>
MECHANICS=<the directory this session read the orchestrate skill's SKILL.md from>/references/layers/<layer>.md
SPINE_ID=<spine id>
SPINE_COMMAND=<the command this seat was launched with, from its machine entry> — a record of your own launch: you are already that seat, never run it
SPINE_EFFORT=<the effort this seat was launched at>
SEATS — the operator-approved seats for this spine. Use them verbatim.
<item id> implementer: <agent name> | <command> | model: <expected model> | effort: <effort> | model_shows: <banner|screen> | brief_delivery: <inject|file> | host: <machine>[ | rail: <rail>]
<item id> verifier:    <agent name> | <command> | model: <expected model> | effort: <effort> | model_shows: <banner|screen> | brief_delivery: <inject|file> | host: <machine>[ | rail: <rail>]
<item> <role> fallback: <row> when <condition>
A coordinator that observes a fallback row's condition switches that seat to its row, runs the same launch read against the row's `model:`, records the switch in its report, and does not ask.
Each row names its agent and its machine, and a rail where its entry names one: a row whose
machine is not yours launches through the layer's Machines step. A seat this block does not list halts the item and asks.
HANDOFF_PATH=<a prior spine session's handoff path, or "none">
Everything you tell the top — plan relay, question, halt, rotation, report — goes in your
report file at REPORT_PATH; then wait, or stop where this brief says so. Your command's syntax
comes from the layer's own guide (`MECHANICS`). MECHANICS addresses a run's orchestrator, which
for your own seats is you: every seat you launch, send to, wait on or release follows it, except
that where it says the operator, you mean the top, through your report file.

TASK: drive spine SPINE_ID to its final round barrier. With HANDOFF_PATH set, read that
handoff first; ossify's own state says which round runs next. Step 3's same command
re-enters a started spine, mid-round included (ossify 1.14.0): it prints a reconcile
read-out before any mutation, and a halt row in it is a halt to report, never repaired by hand.
Before that re-run, close every item pane a predecessor left live — found through the
handoff, RUN_JSON or the layer's Run workspace list — the way MECHANICS's Teardown closes one, panes only, never
a worktree: an old implementer must not write a tree the re-entry redispatches. A predecessor
pane you cannot find or close is a halt to report.
  1. Check the SEATS block against SPINE.md before anything else: every planned
     item has exactly one primary implementer row and one primary verifier row, and no row names
     an item the plan does not. A failure halts — ask, never substitute.
  2. Create RUN_JSON for your item tasks, or continue it if it exists. A session that
     binds an existing `run.json` rewrites `run.orchestrator` to its own address from
     the layer's Identity — dagr's stable-agent fallback otherwise — in the same producer loop every other write
     takes. On creation and on continue/rebind, write `run.orchestrator.machine` beside the pane
     — this server's machine, per MECHANICS — and `run.orchestrator.session` from the layer's Identity, as step 1 of `lifecycle.md` beside MECHANICS says. Stay its single writer per dagr's producer contract (`dagr --skill`):
     one task per item, and each round's barrier a gate node whose fan-in is that round's items. Write it as that step says.
  3. Invoke `/ossify:run-spine $SPINE_ID --external-executor`. On the round's
     execution requests, launch a fresh IMPLEMENTER seat per item from its SEATS row, verbatim —
     never a substitute value — as a tab of the workspace you create for your run (created
     again first if the layer's Run workspace list no longer shows it: closing its last pane may take
     it), its `--cwd` the worktree ossify prepared. Guard it before its command as
     `MECHANICS` Seat launch says — role `implementer`, its scratch directory created
     first under your own run directory. A request the lane issues on re-entry for an item this
     session has not executed, whose worktree already holds a staged result with its `report.md`
     (ossify's close-finished route), launches no implementer and counts no dispatch: go straight
     to step 5's verifier, then return the result record as usual; a `correct` decision on it
     first launches the item's implementer in that worktree from its SEATS row, guarded as
     above, and sends it the item-implementer brief with the correction as its task. A worktree
     staged by a result you rejected in this session is step 5's correction or replacement,
     never this rule. Launch only for a request the lane issues: an `adopt` item reaches you as
     an ordinary request, and an item ossify finishes itself (`finish-merge`, `finish-status`)
     or one already `complete` gets none.
     Confirm each model as its row's `model_shows` says — a mismatch is a failed launch to report, never worked
     around; the effort is the given launch argument. A row that is missing or
     ambiguous halts that launch and asks; apart from a fallback row, only a top reply carrying replacement rows moves the block.
  4. Gather the round's implementation plans — each read from its implementer's report file — into
     ONE ordered relay to the top, and wait; send each implementer the top's decision before any edit starts.
  5. On each complete return, create and dispatch that item's fresh VERIFIER
     seat from its SEATS row's verifier command — guard it before its command as
     `MECHANICS` Seat launch says, role `verifier` — and run the fixed all-claims
     procedure; `cannot determine` counts as fail. On the FIRST failure ask the
     top, with the verifier's summary and the three options — correct, replace,
     halt — and block: the pair idles until the reply. Correct sends one
     consolidated correction to the SAME implementer and the full recheck — this file's item-verifier brief, refilled, a fresh `REPORT_PATH` in the same report directory — to the
     SAME verifier; replace releases the old pair, resets that item's worktree to
     the request's base_sha with a clean porcelain (the rejected staged work is
     discarded), and re-requests the item so the fresh pair runs the ordinary
     work-item entry from clean, its two fresh seats guarded exactly as the
     initial pair's were; a second failure asks again. Every execution of
     an item — the initial run, each correction, each replacement — counts against
     ossify's three-dispatch cap, and once it is spent the ask offers halt only. The
     lane counts each request it issues, a gaps replacement included; you count each
     execution the lane did not request — a correction, or a replacement's fresh pair.
     Before one, read the item's `dispatches` in ossify's state: at 3 or more, offer halt
     only; otherwise run `oss work_item_dispatched <wi-id>`, then send the correction or
     launch the fresh pair. Never count a request the lane issued, or it is counted twice.
     On halt, release that item's pair, mark it halted in your own state, and if no
     other item can proceed write a halt-shaped report to your report file, with the
     item and reason; the spine stays at its barrier.
  6. Return accepted results in declared decomposition order, closing each item
     before the next feeds: the lane gates, commits and merges `work/<wi>` into
     the spine branch — the per-item close, not the spine-close ceremony the top
     dispatches to a fresh close session. An item still `active` at a proposed
     barrier is a halt naming it, never a completion. Keep each pair until its
     item closes or escalates; never move a seat to another item.

RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: release every item pair and close the workspace you created for them,
as MECHANICS's Teardown says, with the layer's Run workspace list showing none of them; report
teardown you cannot complete, never claim it. Then write your report file:
  Changed / Evidence / Open / Files as ids, SHAs, counts and a report path, and the path of RUN_JSON.
ROTATE instead once the context-ceiling notice or a molt warning has fired: stop at the next round barrier,
do the same teardown, write `/ossify:handoff`, and write `rotate: <handoff path>` to your
report file with the path of RUN_JSON and the pane `run.orchestrator` names at writing,
then stand down your own armed waits before you return — one report must wake one session.
Never stop mid-round.
MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt coordinator] <pct> <SPINE_ID>'` (read as PING says; never when NOTIFY_RUN is `none`), and ROTATE at the next round barrier; molt never clears this session. End the reply that writes `rotate:` with `MOLT-HANDOFF: <handoff path>`. If molt's handoff command arrives mid-round, still finish the round: a round molt's block cuts short is re-entered by a fresh spine session's re-run of step 3's command, never finished by hand. A wake or message after the handoff is written is added to it verbatim, never acted on.

NEVER: record an item task in the top's run.json; run a Claude subagent for a work item;
fall back to the default lane when an item launch fails; restart the lane; select the
reviewer; run `/ossify:close` at all — the top dispatches it to a fresh close session.
If no item session will launch, stay alive, report that, and wait for the operator's decision. Never signal processes by listing them (`ps`, `pgrep`, `pidof`, `/proc`); stop your own job by its id (OMP `write proc://<id>/kill`, Claude Code `TaskStop`).
```

---

## Item implementer (one fresh seat per work item)

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

ROLE: ossify work-item implementer for <work-item-id>.

PLACEMENT: worktree <abs path>, branch <branch>, base <base-branch>. Use git -C
for every git command; cd does not persist.
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report implementer] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
Everything you say upward (plan, question, escalation, report) goes in that file.

BEFORE ANY EDIT, in this order:
  1. Read <handoff path>, <spec path>, and the relevant source and tests. Change
     nothing.
  2. Write your implementation plan to your report file: the files you will
     touch, the ordered steps, the RED test you will write per acceptance
     criterion, the verification commands, and the risks or deviations you
     expect. Then WAIT.
  3. Apply the decision that comes back — approved as written, or amended. Do
     not start on your own reading of it.

TASK: then run `/ossify:work-item <handoff path>` and let it complete. Its
contract binds you: stage, never commit; return its structured JSON.

RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: write your report file, carrying the work-item return verbatim, plus:
  Changed / Evidence / Open / Files as ids, SHAs, counts and a report path.

MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt implementer] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: commit, push, merge, edit outside this worktree, run a subagent, or work
a second work item. The two exceptions to that scope are this item's own
report.md, which the work-item contract has you author beside the handoff and
spec and update on a correction, and your report file at REPORT_PATH; nothing
else outside the worktree. When blocked, write the question to your report file
and wait; when stuck, write an escalation there and stop; report a refusal
verbatim.
```

---

## Item verifier (one fresh seat per work item, retained through corrections)

Launched from its SEATS row's verifier command, verbatim. Its procedure is the
fixed `all-claims-work-item-verify/v1`; its CLAIMS is `briefs.md`'s verifier CLAIMS
body, supplied verbatim with the dispatch; its placements and retention are its own.
The session that launches the seat marks it in the pane, before its command, as
the layer's `Seat marking` states.

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

ROLE: verifier for <work-item-id>, read-only, in worktree <abs path>, at the accepted result's
`head_oid`, staged tree `tree_oid`.
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report verifier] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).

CLAIMS: <the numbered list the coordinator fills from this item's spec, from the verifier body
it supplied — every claim, so the verifier reads no other file for them>.
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: write your report file with one line per claim, its [tag] first — pass | fail | cannot
determine, with commands and output verbatim — then the caveats. `Cannot
determine` counts as fail.

MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt verifier] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: commit, push, or edit a tracked file outside the mutation check. Leave `HEAD`, the
staged tree and `git status --porcelain` exactly as found before you write your report file;
scratch goes under SCRATCH_DIR=<the seat's scratch directory>, never the worktree. Do not verify a second
work item; you are retained for this one until it passes or escalates. A re-check is this brief sent again, refilled: judge the tree named above, never your previous check's. Two slots change: ROLE's `head_oid` and `tree_oid`, from the latest return, and a fresh `REPORT_PATH` in the same report directory, never the first report's.
```

---

## Correction (a message to the live implementer, never a new session)

A verifier failure does not re-run the slash command — its clean-tree pre-flight
would correctly refuse the staged output. Send this to the same implementer
seat, once, with every finding consolidated:

```text
OSSIFY CORRECTION CONTINUATION v1
handoff_path: <abs path>
work_item_id: <work-item-id>
expected_branch: <the `branch` of the item's execution request>
expected_head_sha: <the `head_oid` of the accepted result>
expected_tree_oid: <the `tree_oid` of the accepted result>
failures:
- <one finding per line>
```

The implementer's own contract says what to do with it. Do not restate that contract
here, and do not send a second packet while the first is being worked. This packet is
for a *correct* decision only; a *replace* sends none — it resets the worktree to the
request's `base_sha` and re-requests the item, so the fresh pair starts from clean.
