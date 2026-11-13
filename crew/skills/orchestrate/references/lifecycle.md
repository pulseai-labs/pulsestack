# The run

One run per objective. The orchestrator drives these thirteen steps and nothing else.
Every command's syntax comes from the layer's guide.

1. **Orient.** Take every command's syntax from the layer's own guide
   (`references/layers/<layer>.md`). Single-command probes only: branch,
   `git status`, open PRs, the run's `run.json` (and its `dagr check --strict`
   lint), and the layer's health check. Then bind or create the run's `run.json` for the
   objective — **binding** an existing one is naming its path, with no CLI call,
   and you continue from the one the operator names when resuming. **Creating**
   one is dagr's producer contract, never a bare write: with no `dagr` validator
   (`dagr --skill`), start no run file at all. That contract is the rule for every
   write of the file, not only its first, and `crew-run` runs it (`crew-run help`):
   `open` an attempt, `settle` one, `send-back`, or `commit <file>` for one you built.
   With no `crew-run` on PATH (Codex has no plugin `bin/`), or a file not `"dagr": 3`,
   write the loop by hand: the complete document to a temp file beside the target,
   `dagr check --strict` it, and the rename over `run.json` — `mv`,
   which this command allows — lands only once that check is clean. A created run records
   `run.merge_word` — `standing` unless the brief or the operator sets a merge gate for this run,
   then `operator` (step 12). A session that
   binds an existing `run.json` rewrites `run.orchestrator` to its own address from
   the layer's Identity — dagr's stable-agent fallback otherwise — in the same producer
   loop every other write takes.
   Every creation and every bind writes `run.orchestrator.machine` beside its pane — this server's
   machine, per the layer's Identity — and `run.orchestrator.session` from the layer's Identity, the
   agent session for that pane as `{agent, id}`; with none returned, none is written.
   A hard stop's resume finds the dead top's transcript by it (#810).
   Binding a run another top drove through a rotation runs **The resume** (Rotation past the context ceiling) first; its step 2 is this rebind. Binding one whose top died with no handoff runs **A hard stop**'s three steps before it.
1b. **Ossify spine planned here?** If this session just completed `/ossify:plan-spine`
   against a concrete spine directory with a run bound, step 2 is replaced by
   `references/ossify-execution.md`: agree one implementer/verifier seat per work
   item and the three coordinator seats with the operator into the project file,
   inject them as the spine session's SEATS block, ask the
   operator to confirm nested worker depth is 2, and
   start **one** spine session — marked `coordinator` before its command
   (the layer's `Seat marking`) — that creates a nested `run.json` of its own and launches every
   item pair. You approve relayed worker plans and wait on that one completion; you
   launch no item pane. **That completion is the final round barrier, not a PR.** When
   it lands you **dispatch** `/ossify:close <spine-id>` to a **fresh** close session —
   launched from the project file's close-session seat, marked `coordinator` before its
   command (the layer's `Seat marking`) — never
   the spine driver's pane, and wait on its report file, which returns **every** PR
   it opened, one per remote product hosting repo — a remote-less repo lands
   locally and is never a PR; an AI-workspace record arm is not one —
   or `closed`; `close` is a dispatched command (§6),
   not one you run here. Then **dispatch a work-PR session** per returned PR, in that
   PR's own hosting-repo worktree, launched from the project file's work-PR
   seat, marked `coordinator` before its command (the layer's `Seat marking`),
   carrying the reviewer **and** PR-fix profiles you
   decide now, the merge-executor assignment, `PRIOR_REVIEW` (`none` for a PR no
   earlier work-PR dispatch has covered, `covered` when one has and left durable
   evidence its review ran but no record,
   otherwise the record its last `open:` result
   persisted), the `RUN_JSON` path that PR's last `open:` return named (a resumed
   dispatch continues and rebinds that file; a first dispatch names a fresh one), and
   the child templates it will construct, verbatim as `briefs.md`'s
   dispatch matrix lists them for a work-PR session: steps 8-12 are that session's loop,
   and you relay the merge word to it rather than merging yourself — except that a
   `handed off: one-way <OID>` return makes you the merge holder, merging it by step 12's
   one-way rule pinned to that OID, with no word relayed back. Once every returned
   PR has merged, dispatch the record pass — a second close, marked `coordinator` before
   its command (the layer's `Seat marking`) — and only then tear down:
   **step 12's worker release and branch deletion wait for that pass** — the work-PR
   session's own reviewer and PR-fix seats are exempt: it releases them when their work
   finishes, and the hold covers the top's spine-level teardown, not seats in a work-PR
   session's `run.json`; post-merge product fixes take a new PR and fresh seats.
   **But a closed return skips the record pass**
   and goes straight to teardown: the pass exists to record PRs, and that return named
   none. Absent any of those four facts, continue at step 2.
2. **Decompose.** One task per brief in the run's `run.json`, its `deps` the task ids it
   waits on (the run is a DAG), each carrying the complexity class the orchestrator
   derives from the work item's spec and its spine's bone/flesh class: `contract` if it
   touches an interface, schema, or contract, or belongs to a bone spine; `bounded` only
   when the item is one-file, mechanical, or read-only; everything else — including an
   item that classifies nowhere — is `contract`. One implementer per worktree. Items
   within a round may run in parallel; their merges are serial.
3. **Launch.** The seat launch — pane creation, the readiness wait, the banner read that
   confirms the model, then the brief delivered as `brief_delivery` says (`file`,
   unless the entry states `inject`) on the send route the layer file fixes after that read — from its second
   detection ask where the layer has one — is `roles.md`'s "The launch," with any
   undetected-seat path in the layer file. An implementer, verifier or reviewer seat's launch also
   runs the guarded-seat export `roles.md`'s launch block states, before its
   command. The run's workspace can
   go before the run does — a first seat's release may take it — so a later launch
   whose workspace the layer's Run workspace no longer shows
   creates it again first and binds the id that call returns, the clause the spine
   session's brief already carries. The "state your model" line is the worker's own second check: a
   model that is not `SEAT_EXPECTED_MODEL` is a failed launch it writes to its report file
   and stops on. Wrong model at the banner read: release the seat and report it.
   Every brief this session dispatches names this run's `run.json` in its `NOTIFY_RUN` slot and the
   seat's machine in `NOTIFY_MACHINE` — `NOTIFY_RUN` is the sentinel `none` when the layer does not detect
   this pane or the seat is on another machine — so an eligible worker's ping comes to whichever pane
   `run.orchestrator` names when it renames; a coordinator fills its children's slots with its own
   nested `run.json` the same way, and an operator's `brief:` is sent as a copy carrying the slots and the ping step, never edited in place (`briefs.md`).
   The full locator records `pane`, `machine` (a local seat's too), `report` and molt's `status` path,
   so an attempt whose brief never arrived never looks live.
   Every dispatch — a launch or a new brief to a retained seat — opens its attempt (`crew-run open`) with `phase: recorded`
   and its full locator before the brief goes, notes the generation the doorbell compares
   (`completion.md`), and sets `phase: delivered` once the send is confirmed.
4. **Plan gate, planned work only.** The planned implementer's brief says: write your
   plan to your report file, then wait for a reply before implementing. The
   orchestrator reads the plan from that file when its bounded wait wakes or the plan's
   ping arrives, the same doorbell as completion (`completion.md`), and approves or
   amends it by sending the seat its next message. The final report later overwrites the
   plan in the same file. Fast briefs skip this.
5. **Wait.** One bounded wait per dispatch, run in the background as the layer's Wait
   states it: the layer's typed wait for a detected seat that is not a coordinator, over
   the states that step lists; for a seat the layer does not detect, and for a coordinator
   seat, the report-file wait. Either is one call that
   returns once: whatever polling it does happens inside that call, never a rolling poll
   by the orchestrator.
   What a wake means — the file the doorbell reads, the generation check, the two dead ends,
   the ping and the heartbeat are `completion.md`'s, stated there once; this step only names
   the wait. A `blocked` wake is a dialog: read it (the layer's Read), put it to the operator,
   answer it as the layer's `Wait` states, then one fresh bounded wait; a detected coordinator re-arms the pair (`completion.md`).
   A loop of waits, and restarting a wait after an empty timeout, both stay forbidden.
   Before any question to the operator the top writes `run.question` before it asks and removes it on
   the answer — `{text, asked_at, task, message_id?}` (`message_id` only when the question answers or
   relays a dagr operator message) — so a question survives the top.
   A read only on a `blocked` wake, a missing or malformed report, a timeout's checkpoint,
   the false wake's own read, or the heartbeat tick's one check per live seat — never to
   watch progress.
   A round's N parallel items are N bounded background waits, one per pane, each waking the
   session when it exits — not the forbidden loop, since each targets a different
   pane rather than re-entering the one that just timed out. What persists is the
   report file, not the state a finished pane has since moved to, so a pane that
   finishes while another item still works loses nothing; the round's barrier
   closes when every item's report file is in hand. A timed-out pane does not hold the
   round: that item's report file is not yet in hand, so the barrier closes on a later
   turn, once it is on disk — woken by another item's still-running wait, or by the
   operator's word to wait on that pane again — never by the orchestrator's own re-entry.
   At each task
   boundary for a retained implementer whose profile can run a local slash command and
   whose send route carries one, use the layer's bounded `/context` reads and unavailable result
   before attaching the next task; the threshold and ineligible-seat rule are in `roles.md`.
6. **Implementer finishes.** Its report file carries the completion body its
   brief defined — the commit SHAs and file count, each test command's pass and
   fail counts with the full output, the PR it opened with
   its head SHA, and any open ids. `<owner/repo>` is the repository the call targets, read from its own checkout: `gh repo view "$(git -C "<repo-root>" remote get-url origin)" --json nameWithOwner -q .nameWithOwner`. `<repo-root>` is that repository's checkout, not the directory you are in: a PR lives in the canonical even when you run from the AI workspace. Never build the name from a folder name: an AI workspace's folder and its GitHub repo often differ. Check the PR with one
   `gh pr view <number> --repo <owner/repo>` and read CI from
   `commits/<sha>/check-runs` plus the commit statuses when the repo's CI reports
   through the Status API instead of Checks, never the status rollup, both fetched
   against `--repo <owner/repo>`. These reads are the floor's PR-gate probes — identity
   and state from the first, CI for the named SHA from the rest — and anything beyond
   reading them becomes a verifier dispatch.
7. **Verify, once per work item.** One verifier session per work item, one brief
   listing every claim: each acceptance criterion of the work item's spec, the
   mutation of any new test, and the diff against the requirement. The suite result
   on the head is not a claim — the orchestrator reads that SHA's check-runs before
   dispatching the verifier. The verifier seat runs at the effort its machine
   entry names — the claims include judgment, and `cannot determine` counts as fail.
   On a fail, attach a fix task to the retained implementer by sending it the
   fast-implementer brief with the verifier's claims for a TASK (`briefs.md`;
   the layer file says how), wait for its report file
   naming the new head SHA, read that SHA's check-runs, then re-check on the retained
   verifier — its brief sent again, every slot refilled (`briefs.md`); a second fail on the
   same item goes to the operator. The verifier is released only at pass or escalation.
   A calibration fixture — a seeded defect the verifier must report `fail` — is the top's
   own worktree mutation, never a worker's task and never on the PR branch: a detached
   worktree at the item head, seeded only by `git checkout <base> -- <path>` on a path the
   implementer's report names, re-checked without saying what was seeded, then removed.
   Its `fail` is the expected answer, never counted toward a second fail; the item passes
   only on a re-check of its real head after it.
8. **Review.** A review runs exactly once per PR: the reviewer seat in a fresh worktree
   at the PR head, brief its review command (`config.md`, `review:`; `/code-review <PR> <LEVEL>` by default), every finding returned in the report file.
   **A fixed head is revalidated, never re-reviewed whole**: the reviewer is re-dispatched from
   its seat over the fix range alone — one scoped delta re-review; a `/merge-bar:review-pr`
   reviewer is a fresh seat running `/merge-bar:review-pr <PR_URL> --round <n> --previous
   <previous report path>` — and its findings enter the
   disposition baseline like any other, so a repository whose bot does not review a push still
   reaches a complete signal on the head it asks about. Every finding returned in the report file
   as file, line, severity, claim, or as that report's classes. The reviewer posts nothing to GitHub and edits
   nothing, so that file is the sole copy of the review. Release the reviewer only
   after its report file validates — findings lines present in the stated schema, or
   `Findings: none` on a clean review, or a `/merge-bar:review-pr` report with its
   `## Coverage` table and a `Bar:` line on every `### C<n>` class (no class is a clean
   review; a class blocks unless its `Bar:` is `non-blocking` or it carries `Closes:`, and a
   `Still open:` class keeps its `Bar:`), with the reviewed head —
   that report's `Head:` — equal to the PR head; on
   a malformed report, send one bounded correction request
   before release.
9. **Disposition.** Each finding becomes **fix**, **defer** as a tracked issue, or
   **reject** with a reason. Post that list as one PR comment — the disposition
   ledger — so it survives the session.
10. **Fix rounds.** The retained implementer — on an activated ossify spine (1b) this
    whole step runs inside that PR's work-PR session, which creates the PR-fix seat from
    the profile the top decided at step 8's transition and dispatches its fix task here
    once step 9's ledger exists; no implementer is retained into a spine PR — gets
    the fix list plus the GitHub thread stream (Codex, CodeRabbit, humans) and works
    to zero unresolved threads by GraphQL `reviewThreads` count, pushing as it goes.
    The unit that reaches a terminal state
    is each finding, including each finding inside a review body or PR comment: every
    finding ends **fixed**, resolved only after the fix is on the head the reviewer
    can see; **deferred**, resolved with a comment linking the tracked issue; or
    **rejected**, resolved with the evidence. After each fix round's report file,
    and after each later-finding disposition, edit the disposition comment so every
    finding's terminal state is recorded there — fixed in <sha>, deferred →
    #<issue>, rejected with the reason. A signal is clean when every finding in it
    has a terminal state so recorded. P0 and P1 findings are never deferred. A new
    bot or human finding that arrives after the disposition returns to the
    orchestrator, and the implementer waits — it
    resolves the finding only after the orchestrator's decision (#410). No second
    review. Bot comments after each push stay in this stream, and review
    bodies and top-level PR conversation comments are part of it too —
    `reviewThreads` does not return them — refreshed after each push alongside the
    thread count. With ossify installed, this
    dispatch is `/ossify:work-pr <PR> --repo-root <worktree holding the PR branch>`
    with the disposition embedded as a third signal.
11. **Round stop.** When the work-PR dispatch runs merge-bar's `working-a-pr` (directly,
    or through `/ossify:work-pr` where merge-bar is installed), that skill owns the stop:
    the PR body's Merge bar decides what blocks (`working-a-pr` adds one before round 1
    if the body has none), a blocking finding is never deferred, and its round stop
    decides when rounds end. Agree no separate stopping rule there, and never write one
    into the bar. Otherwise the default holds: when a round does not shrink or fixes
    generate new findings, stop fixing and defer the remaining P2s and P3s as tracked
    issues; P0 and P1 are never deferred. Either way, a PR that reaches round five halts
    the deferrable work and examines process, not code; blocking remediation continues
    past round five until each finding is fixed or rejected with evidence.
12. **Merge gate.** Fetch the full gate set against `--repo <owner/repo>` for the head
    SHA immediately before deciding: `isDraft`, `mergeable`, `mergeStateStatus`, every
    relevant check-run and status context — all must be successful — the unresolved
    threads, and the non-thread signals of review bodies and PR conversation comments,
    which are clean when every finding in them has a terminal state recorded in the
    disposition comment (step 10).
    Act only when every one is clean: a non-mergeable state is surfaced to the operator
    as the blocker, and a new actionable finding returns to step 10.
    The run's `run.merge_word` decides where the merge word comes from. With `standing` (the default),
    read the project's standing orders on the base branch (merge-bar's working-a-pr, "Standing orders"
    paragraph, says where it is read and whom it binds). Only an order that names the orchestrator role
    and grants it merge authority counts: with one, a clean gate set on that SHA is the word, so merge
    with no ask, naming that order in the disposition comment; with none, ask the operator for the
    merge word naming that SHA and say no standing order grants this role merge authority.
    A one-way door — a `handed off: one-way <OID>` return, or where merge-bar's `working-a-pr` runs a
    body with `Door: one-way` or no `Door:` line — follows merge-bar's
    `skills/working-a-pr/references/one-way-door.md` under either word, `standing` included: its
    reads and its clean install are a verifier dispatch, and the merge below is pinned to that OID.
    With `operator`, the ask says that this run's brief or the operator set an operator merge gate:
    ask for the merge word naming that SHA. Under either word, a dispatch whose
    merge executor is the operator (`MERGE_EXECUTOR=operator`) still goes to the operator: tell them the word and the
    SHA, and they land it.
    Merge only on that word, as a merge commit, never a squash, bound to that
    SHA: re-fetch the same full gate set for that SHA once more, then
    `gh pr merge <number> --repo <owner/repo> --merge --match-head-commit <sha>` —
    the orchestrator often sits outside the PR's repository, so every
    read and the merge name the repo. The read and merge are two
    operations — a signal can still land between them: the ruleset
    requires conversation resolution, GitHub refuses the merge while any thread
    is open, and a refusal returns to step 10, never a retry. Then
    release every worker and delete the branch only after confirming a merged PR
    exists whose head OID equals the branch tip — on an activated ossify spine (1b) the
    merge lands on the word you relay under that dispatch's `MERGE_EXECUTOR`
    assignment — always a merge commit on the named SHA, session or operator —
    and that wait covers the top's spine-level teardown alone — work-PR seats
    released when their work finished. **A closed spine has no PR to confirm**,
    so its teardown validates the close's own result instead — the local landing it
    recorded in each hosting repo — and waits for no record pass.
13. **Handoff.** If the run outlives the session, write a handoff naming the run's
    `run.json` path, the pane `run.orchestrator` names at writing, and the next step,
    the head SHA, and, per live seat, the last molt status line noted.
    The run file holds those files’ paths, not the read cursors.
    Also carry what the run file cannot hold — why a choice was made, what the operator said.
    Every seat's pane, machine, report path, last consumed generation and molt
    status path are in `run.json` (steps 1, 3 and 5), so the handoff does not copy them. On an
    activated ossify spine, also the spine's approved `SEATS` block, the resolved coordinator
    profiles and the accumulated close-review ledger (oldest first). With
    ossify installed, that is `/ossify:handoff`.

## Roles of the operator's own

A role the operator defines in the project file (`config.md`) runs at a named point of
the run above: `after-implementer` (after step 6), `before-review` (before step 8),
`after-disposition` (after step 9), `before-merge-ask` (before step 12's merge word, whether asked or granted there),
`at-teardown` (step 12's teardown — release and branch deletion, not step 13's
handoff). `at: on-demand` has no fixed point, dispatched when wanted — its seat
counts against the allowance the project file declares, one by default. A declared
role's seat lives for its dispatch — launched at its point or on demand, released on
return — never a standing seat. A role with `blocks: yes` holds the run at its point
until it passes or the operator overrules it — the orchestrator relays its summary,
the operator's word settles it, anything else is advice in the disposition. A role
with `replaces:` takes a plugin step — `implementer`, `verifier`, `reviewer`:
the named seat is not launched, the role runs at its point in its place, and the
handoff says which step was the operator's. A declared role with no `replaces:` is marked a guarded `implementer` — its report
directory and its scratch directory in `SEAT_MODS_ALLOW` (the layer's `Seat marking`);
it runs under implementer rails. Every point above is the top's own — a
declared role is not yet carried into a delegated spine or work-PR session, so a
`before-merge-ask` role does not fire on an activated spine (issue #500 holds it).

## Rotation past the context ceiling

crew's hook tells a session its own context figure once it reaches the ceiling (the
plugin setting `context_ceiling`, default 500000 tokens). The top, the spine session and the
work-PR session act on it; a close session and every leaf seat simply finish their unit.
Where molt runs, its warnings take the notice's place: every seat but the top hands off to
its parent (`completion.md`, "A child past molt's warnings"), and the top molts in place
(below).
Past the ceiling a seat finishes the unit in hand and starts no new one, never stopping
mid-item. At its next boundary it settles its dispatch with a return that carries its state
forward, and its parent launches a fresh seat to resume, marked `coordinator` before its
command as the layer's `Seat marking` says: the spine session writes
`/ossify:handoff`, returns `rotate: <handoff path>`, and resumes from the same
project-file seat with that path as `HANDOFF_PATH`; a work-PR session returns `open: <PR url> at
<head sha>` with its review record and the `RUN_JSON` path it continued, and its successor
resumes from `PRIOR_REVIEW` with that same `RUN_JSON` — it takes no `HANDOFF_PATH`.
A figure the hook reports as unavailable is relayed upward once,
never guessed. Both sessions' boundaries and returns are in their briefs
(`ossify-briefs.md`, `ossify-pr-briefs.md`); a spine `rotate:` is
`ossify-nested-run.md` §4.

**Your own rotation.** Your boundary is a fully acknowledged delivery with no operator question in flight. Write the handoff
step 13 states, plus a resolved profile beside a launch command for each host — this top's and the other host's
(Claude Code and OMP: `omp-seat orchestrator --via omp-glm`), the other host's profile resolved from its machine-file
entry like any seat's (`config.md`) — ask the operator once when there is none. The handoff restates no operator gate:
a line copied from this skill becomes an instruction to the successor, which outranks a standing order. For the merge
it points at step 12 and `run.merge_word`. `/ossify:handoff` with ossify installed (`skill://handoff` on OMP), the same
file by hand without it. Open a new tab and pane with the launch command the handoff recorded — ask the operator once
when none did; an alias carries provider settings `ps` does not show — in the workspace
the layer's Identity names, the top's own, never the run's. **Launch it as the seat launch the layer file states** — marked `orchestrator`
before its command (the layer's `Seat marking`) — using the destination host's recorded profile for the readiness
path and model read, then the layer file's send route (its second detection ask where it has one), and send its resume on that route: with ossify,
`skill://handoff-resume <path>` to an OMP top and `/ossify:handoff-resume <path>` to a Claude Code top; without it,
the path as its first instruction on either. From the handoff on, this session writes nothing to the run file and
takes no dispatch action; a wake that reaches it before it stands down is handed to the successor, never acted on.
Confirm its turn started, then **stand down**: stop this session's armed
background waits and its heartbeat by job id (OMP `write proc://<id>/kill`, Claude Code `TaskStop`), write nothing more to the run file and take no dispatch action. One report must
wake one top. A worker pings whichever pane `run.orchestrator` names, so after the rebind a worker on the successor's machine pings the successor. A stale ping — tagged `[crew report <role>]`, or the legacy `REPORT READY: <task id> <kind> <path>`
from a brief older than 0.3.1 — that reaches this pane after the rebind, like a `[DAGR OPERATOR MESSAGE]` envelope dagr queued here before the rebind, is read and handed to the successor, never acted on.
Then tell the operator which tab to use and that this one can close.
**A hard stop** — the top died with no handoff (#810) — is resumed only on the operator's word that it died, after
three steps a rotation does not need:
1. Read `run.orchestrator` — pane, machine, session — before any write: the resume's rebind overwrites it.
2. Stand the old top down. If the layer's Identity still finds the pane on its machine, the old top may still hold
   armed waits: ask the operator to confirm it is dead and to close its pane, or close it on the operator's word,
   before binding. Never two tops on one run. A pane already gone needs no ask.
3. Read its transcript, found by `run.orchestrator.session` on its machine: Claude `~/.claude/projects/*/<id>.jsonl`,
   OMP `~/.omp/agent/sessions/*/*_<id>.jsonl`. Read back from the end to the last step it named: that step, the task
   or PR in hand, operator words and decisions since its last handoff, and the last action it started. It is context:
   where it and `run.json` disagree on a fact, `run.json` wins. With no session recorded, no file found, or the old top
   on another machine, ask the operator once for the transcript path or the next step.

Then **The resume** runs with the transcript in the fresh handoff's place: step 1 reads the file and the transcript,
and step 6 continues at the step the transcript shows. A dispatch whose attempt the run records is never sent again: step 4
settles it (an attempt is recorded before its send). Any other action it shows started but not confirmed — an answer or message to a worker, a merge, a tag, a
branch delete — is checked for its effect first (the worker's pane for a send, GitHub for the rest) and redone only
when the effect is absent.

**The resume.** The new top resumes by naming the parent's `run.json` path — there is no CLI call:
1. It reads the file and the fresh handoff.
2. A session that binds an existing `run.json` rewrites `run.orchestrator` to its own address from the layer's Identity — dagr's stable-agent fallback otherwise — in the same producer loop every other write takes.
   It writes `run.orchestrator.machine` and `.session` beside the pane (lifecycle step 1).
   From here every worker's next ping comes to this pane.
3. If `run.question` is present, ask again only if the hard-stop transcript has no answer; otherwise apply the recorded answer and remove `run.question`.
4. Per working attempt, first run the generation check against `locator.seen`, for both `phase: recorded` and
   `phase: delivered`. A new report generation proves delivery: set a recorded attempt `delivered`, then read the
   generation once, record it and act on it by kind. With no new generation and `phase: recorded`, treat the attempt
   as `delivered` and re-arm it like any delivered attempt. Never relaunch it automatically. The re-armed wait’s timeout
   checkpoint (lifecycle step 5) reports a worker that never started to the operator, who decides on a relaunch; never run two
   workers on one attempt.
   Re-arm lifecycle step 5’s waits only for an attempt still live after its generation check; a final report consumed on resume
   settles that dispatch, so it gets no wait. The waits are on the pane (a detected coordinator's companion included)
   through `locator.machine`; every later operation on that pane carries `locator.machine` (the layer file, Machines).
5. It arms one fresh heartbeat only if at least one dispatch is still live.
6. It continues at the fresh handoff's next step. A `done` task is never re-run.

A run file older than 0.2.21 lacks these fields: an attempt with no `phase` counts as `delivered`; with no
`locator.report`, the path comes from a handoff, or the operator once; no `merge_word` follows step 12 as
`standing` unless the run's brief sets an operator gate. For a live dispatch with no `seen` and no
fresh handoff generation, the existing report is ambiguous: the top reads it but does not act on it until the operator
confirms it belongs to the live attempt. A fresh handoff's noted hash and identity, where present, are the baseline.
A live worker dispatched under 0.2.20 or earlier keeps pinging its fixed pane until that dispatch ends; the heartbeat
covers it.

**Where molt runs, you molt in place instead.** The top is molt's root: it is never marked a
molt child, and molt's active marker silences this plugin's hook (0.2.6). molt's two warnings
(40% and 50% of the window by default) mean: take your next fully acknowledged delivery with
no operator question in flight, or hand off at once when nothing is in flight. Its handoff
command (65%) means now: past its block threshold (75%) every other command is refused.
Write the handoff your own rotation writes, and add to it the id of every background task you
have running — each live dispatch's wait and companion, and the heartbeat — and, verbatim, any
operator question you are holding. Start no dispatch after it; a wake or message that reaches
you after it is added to it verbatim, never acted on, and end that reply with
`MOLT-HANDOFF: <path>`. molt runs `/clear` in this pane and seeds the fresh session with the
handoff. There is no stand-down and no successor launch: the pane, its address from the layer's
Identity, its seat marking (the layer's `Seat marking`, "A molt is not a launch") and, on Claude
Code, every armed wait survive the clear, and every worker's ping still reaches this pane, which
`run.orchestrator` still names. The resumed top
reads the handoff and confirms `run.orchestrator` names its own address from the layer's Identity, rewriting it
only where it does not; it always rewrites `run.orchestrator.session` (lifecycle step 1), since molt's `/clear` starts a new session in this pane. On Claude Code it arms no wait and no heartbeat the handoff lists: they keep running,
and their notifications are its own. A heartbeat tick the handoff carries means that heartbeat
has ended: the resumed top arms a fresh one. It runs the generation check once per live
dispatch against the attempt's `locator.seen`, a carried wake included, so a report
that landed across the clear is acted on once and retires its listed wait by id (`TaskStop`); the later
notification for that generation retires nothing. On OMP the clear cancels every background job the old session
ran, and molt's seed says so (#855): after that check the resumed top re-arms the wait of each dispatch still live
and one fresh heartbeat; there is no listed wait left to retire. With `/molt off` the marker goes, the hook
speaks again, and the rotation above applies.
