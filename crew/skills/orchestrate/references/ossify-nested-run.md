# The nested run — mechanics of an activated ossify spine

The contract these mechanics serve is `references/ossify-execution.md`.

## 1. Nested depth is a prerequisite, not a fallback

Nested worker depth must be `2`: you launch the spine session, and the spine session
launches item sessions of its own, from its own pane. The layer has no depth setting and
no CLI read that proves one — its one nesting key, `[experimental] allow_nested`,
governs launching the layer's own CLI inside a pane, not the commands a seat runs —
so get the operator's confirmation before starting the spine session; its first item
launch is the runtime proof.

If the spine session cannot launch an item session, it stays the lane owner, writes
the blocker to its report file, and waits for an operator decision. It does not
substitute a Claude subagent, record item tasks in the top's `run.json`, create a
replacement writer, or restart the lane. The report goes up as an ask the top relays
to the operator — the top does not answer a launch refusal itself.

## 2. The nested `run.json`

Your brief gives the spine session its identities explicitly (`ossify-briefs.md`) —
the layer prepends nothing to a brief — among them `RUN_JSON`, the path of a `run.json`
it writes and owns, separate from yours. dagr keeps one run per file and
links no run to another, so *nested* names the session hierarchy, not anything
dagr records. The spine session is that file's single writer and you never write
it; its writes take `lifecycle.md` step 1's loop.

- every item task, and each round's barrier, is recorded in `RUN_JSON`, never in your `run.json`;
- the spine session is the orchestrator of its own run, so it launches, sends to, waits
  on and releases its item seats as the layer file says, each in the worktree ossify
  prepared for the item;
- plan, gap, depth and other spine-level questions come up in its report file, and
  you answer by sending it its next message;
- an item seat's question reaches the spine session the same way, in that seat's
  report file;
- its final report goes in its report file like everything else, naming `RUN_JSON`;
- the spine session is the only waiter on its item seats; you wait on the spine session
  as on a coordinator seat (`completion.md`, Completion).

The nested run keeps item plans and item reports away from you: you read a batched
plan relay, genuine spine-level decisions, and one final report.

**Teardown is the pairs and their workspace, not the `run.json`.** The spine session
releases every item pair and closes the workspace it created, as
`roles.md`'s Teardown order and the layer's Teardown say, before its final report. Nothing closes a
`run.json`: dagr never writes one, and the file stays as the spine's record.

## 3. The round procedure, as the spine session runs it

1. Validate `SPINE.md` and the round's item set against the **SEATS block your
   brief injected** (`ossify-execution.md` §3): every planned item has exactly
   one primary implementer row and one primary verifier row, and no row names an item the plan
   does not. A failure halts — ask, never substitute.
   **Every item launch spends its SEATS row verbatim** — the whole resolved
   profile. A seat the block does not list, or lists twice as primary, halts that item
   and asks; you **never re-read the project file** or invent a value. A fallback row
   is spent as `ossify-briefs.md` says; when the
   top changes a seat, its reply carries the replacement rows, and those become
   the block.
2. Invoke the ossify lane in external-executor mode. ossify prepares every
   same-round worktree and handoff first, then hands over one request per item.
3. For each item, launch a **fresh implementer seat** from its SEATS row's
   exact command — the verifier is not created yet; it has nothing to verify until
   step 5 — and deliver its brief as its row's `brief_delivery` says. Guard it
   before its command as the layer's `Seat marking` says — role `implementer`,
   its scratch directory created first under your own run directory.
4. Each implementer confirms its model, reads, and writes a detailed plan to its
   report file, then waits. Gather the round's plans into **one** ordered ask to you;
   return an independent approve-or-amend per item; the spine session sends each
   implementer its item's decision, before which no edit starts.
5. On each complete return, capture the item's identity as the result declares it — `head_oid`,
   `tree_oid`, `report_oid` and `spec_oid`, the four ids the external-executor result envelope
   declares (`ossify/skills/work-item/references/external-executor.md` §4) — then create and
   dispatch that item's **fresh verifier seat** from its SEATS row's exact
   command, in the same worktree, against the fixed all-claims procedure. Guard it
   before its command as the layer's `Seat marking` says — role `verifier`.
   `cannot determine` = fail.
6. On the **first** verifier failure, write one question to its own report file with
   the verifier's summary and three options —
   correct with the same pair, replace the pair, halt — and it **blocks: the pair idles**
   and nothing on that item moves until the reply. *Correct* is one consolidated
   correction to the same implementer, then the full recheck — `ossify-briefs.md`'s item-verifier
   brief, refilled, a fresh `REPORT_PATH` in the same report directory — to the same verifier.
   *Replace* is the one exception to one pair per item: the old pair is released first,
   the item's worktree is **reset to the request's `base_sha` with a clean porcelain**
   — the rejected staged work is discarded, which is what replacing means — and the
   item is re-requested as a fresh `external_execution_request` carrying the original
   `branch` and `worktree_path`. The fresh pair then runs the ordinary
   `/ossify:work-item` entry from clean, because that entry's pre-flight requires an
   empty porcelain and no fresh session may adopt another's staged tree. Both
   replacement seats are guarded exactly as the first pair's were.
   The correction packet is for *correct* only — it is same-executor by
   construction, and never two pairs live on one item. A replacement at a **different**
   seat is the operator's call — the top relays the approved row and it becomes the
   block's value for that item. A second failure asks again, with the
   same three options — except that **every execution of an item counts against
   ossify's three-iteration cap**, the initial run and each correction and each
   replacement alike, so once it is spent the ask offers halt only.
   *Halt* is terminal for that item: release its pair, mark it halted in your own
   state, and when no other item can proceed write a **halt-shaped report** to its
   own report file, carrying the item and the reason. The top settles that
   dispatch and the spine stays at its current round barrier — no close is
   dispatched off a halt.
7. Initial gaps are handled inside the spine session: it asks you for the operator's
   answers, remains the handoff writer, appends clarifications, and re-requests the item
   within ossify's three-iteration cap.
8. Feed accepted results into the lane in declared decomposition order, **closing each
   item before the next feeds**: the lane gates the result, commits it in the worktree
   and merges `work/<wi>` into the spine branch — the per-item close, driven from here
   and not the spine-close ceremony §4 dispatches. An item whose close has not landed
   (still `active`, nothing merged) is not accepted. Keep each pair until its own item
   closes or escalates, then release it. **No seat is ever transferred to another
   item.**

Same-round pairs may run concurrently. Closes and merges stay serial and the
round barrier is ossify's, unchanged. `RUN_JSON` only records it: each round's
barrier is a gate node (`kind: gate`) whose fan-in is that round's item tasks, which
dagr renders as a state-bearing join. dagr infers no promotion, so when the round's
last item closes the spine session records the gate's `promoted` event itself, as
dagr's producer contract requires.

## 4. The spine close is dispatched, and it comes next

The spine session stops at the final round barrier — where `/ossify:run-spine` hands
the baton to `/ossify:close <spine-id>` — and never runs the close on its own
initiative.

**A `rotate: <handoff path>` completion is not the final barrier.** The spine session stopped
at an earlier round barrier past the ceiling (`lifecycle.md`). Confirm the handoff resolves,
then dispatch a fresh spine session on the same spine-session seat — marked `coordinator`
before its command as the layer's `Seat marking` says — the same approved SEATS
block injected again — with `HANDOFF_PATH` set and the same `RUN_JSON`, which it continues,
rebinding `run.orchestrator` to its own pane (its brief's step 2 says). On that rebind it writes
`run.orchestrator.machine` beside the pane — this server's machine, per the layer file — and `run.orchestrator.session` (`lifecycle.md` step 1). The close waits for a
completion at the final barrier. A spine session that rotated on a molt warning returns the same
`rotate:`; one cut mid-round returns none and is respawned the same way, its handoff as
`HANDOFF_PATH`: ossify 1.14.0's run-spine re-enters the round from recorded state, and only a
halt in its reconcile read-out goes to the operator (`completion.md`, "A child past
molt's warnings").

When its final report lands, **you dispatch** `/ossify:close <spine-id>` to a close
session that is **always a fresh seat** you create, never the spine driver's — marked
`coordinator` before its command (the layer's `Seat marking`): it
creates nothing, runs the close, and returns what the close opened
(`ossify-pr-briefs.md`). You do not run it here — SKILL.md §6 lists `close` among the
dispatched commands, and the delegation floor keeps suites out of your session.

**Before reporting the barrier, the spine session verifies every item of the spine is
closed** — no `active` item, each merge landed on the spine branch. An item still
active at the proposed barrier is a halt naming the item and the missing close, never
success; remediation is the top's to decide, and a fresh spine-level completion is
required before this section runs.

**The first close opens one PR per remote hosting repo and halts while any is open**,
recording nothing (`close/references/spine-close.md`); its report file names **every**
PR it opened, repo and number — or the single word `closed`, when every hosting repo
was remote-less and it recorded the spine outright.

**Hosting repo means a declared product `target_repo`** — the distinct product repos
the spine's work items declare. An AI workspace carrying the spine's ceremony records
is not one: the close writes its records where ossify resolves `ai_workspace`, and
committing and integrating them follow that repo's own policy — no ossify ceremony
governs that repo — outside the PR list this lane returns; nobody pushes them to
its `main` directly, and no session claims ossify opened a PR there. Ossify's own
landing rule — a repo with a remote lands by PR, a remote-less one merges locally —
is unchanged and decides each product repo's arm.

A multi-repo close can also open a PR in one repo and then halt on a later one, so it
returns `halted:` naming what it opened so far. **Dispatch nothing downstream — no
work-PR session, no record pass — until a close returns a complete PR list or `closed`.**
A halt settles that dispatch only: remediate the blocker it names, then dispatch a
**fresh** close session — marked `coordinator` before its command (the layer file,
Seat launch) — as many times as that takes.

**A close that halts on its own review returns `halted: close-review` with the
ledger.** The ceremony's accumulated-diff review is the close seat's to run, never to
fix: a `fix now` disposition ends that dispatch. The top asks the operator for a
writer profile — or, under a standing order in the project's memory bank or AGENTS.md for seats and
profiles, picks that profile from the project file and records why — and dispatches
one writer per affected hosting repo — each in
that repo's own spine worktree with a bounded edit scope, per
`references/ossify-close-writer.md` — carrying
the accepted findings whose `target_repo` is that repo — then dispatches a
fresh close, which re-runs the review over every amended diff. Neither the
close nor the work-PR session applies these fixes, and no seat is created for
this permanently.

**Then one work-PR session per returned PR**, each created in that PR's hosting-repo
worktree, launched from the project file's `work-PR session` seat — marked `coordinator`
before its command (the layer's `Seat marking`) — and briefed with the
two profiles you decided at the PR transition (`ossify-execution.md` §5), the
merge-executor assignment, `PRIOR_REVIEW` — `none` for a PR no earlier work-PR dispatch
has covered, `covered` when one has and left durable evidence its review ran but no
record, otherwise the durable record that PR's last `open:` result persisted — and the
`RUN_JSON` path that return named: a resumed successor continues and rebinds that file,
a first dispatch names a fresh one. On creation and on continue/rebind it writes `run.orchestrator.machine`
beside the pane — this server's machine, per the layer file — and `run.orchestrator.session` (`lifecycle.md` step 1). It owns both PR seats in a `run.json` of its own,
relays one summary per round, and asks you for the merge word; you answer as `lifecycle.md`
step 12's `run.merge_word` says; the merge lands under the reply's executor — a merge commit on the named SHA, session or
operator alike. A `handed off: one-way <OID>` return asks no word: you merge it by step 12's
one-way rule. `lifecycle.md` steps 8-12 are that session's loop, not yours.

**Then, once every returned PR has merged, one record pass** — a second
`/ossify:close <spine-id>`, to another fresh close session — marked `coordinator` before
its command (the layer's `Seat marking`). **Hold step 12's teardown —
worker release, branch deletion — until that pass returns:** it resolves the spine
branch again. That hold is the top's spine-level teardown; the work-PR
session's own seats released when their work finished (#448).

That second dispatch is **conditional and single**: it happens
only when the first returned at its open-PR halt naming at least one PR, and only once
every one of those has merged — one SUCCESSFUL record pass per spine, never a
scheduled step; a close that halted consumed nothing and is simply re-dispatched. A
first close that returned `closed` — every hosting repo remote-less, so it landed and
recorded outright — is the whole ceremony, and dispatching a second one against it is
a wrong turn, not a safety net.
