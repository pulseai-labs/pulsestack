# ossify spine execution — assignments, seats, and who owns what

A spine's work items each deserve their own model and effort; one dispatched lane driver
cannot give them that, because whatever it spawns inherits its runtime.

> **Editing note.** This file, `ossify-nested-run.md` and `ossify-briefs.md` are asserted
> to hold no subagent invocation form and to stay under 200 lines. Never paste the
> call shape.

## 1. Activation

Four facts, **all** of them, and each about the session you are in right now:

1. crew is the current top orchestrator;
2. the run's `run.json` is bound;
3. this session has just completed `/ossify:plan-spine` — **or it resumed a handoff whose
   `SEATS` block and spine plan the handoff carries, which is how a rotated top inherits the
   activation: the handoff is the marker, and a resumed top satisfies this fact by having it**;
4. a concrete spine directory exists on disk.

Absent any one, this file does not apply and ossify runs as `SKILL.md` §6 says.
**None of these activates it**: mere installation, an environment variable, a
spine section in the project file, a `/plan-spine` in a session that is not the
top. Discovery is not authority — the phase begins because *this* session
planned *this* spine.

## 2. Four seats, one voice

| Layer | Owns | Never |
|---|---|---|
| **Top orchestrator** (you) | agreeing one implementer/verifier seat per item and the three coordinator seats — spine, close, work-PR — with the operator into the project file, injecting them into the spine session's brief as its SEATS block, launching the spine session from that seat's resolved profile, verbatim — marked `coordinator` before its command (the layer's `Seat marking`); a model mismatch is a failed launch, exactly as for an item row — approving or amending each relayed worker plan, deciding the reviewer and PR-fix seats at the PR transition, dispatching the close and one work-PR session per returned PR, each launched from its project-file seat — marked `coordinator` before its command (the layer's `Seat marking`) — with the model confirmed as an item row's, assigning each work-PR dispatch's merge executor (`MERGE_EXECUTOR`) and supplying its `PRIOR_REVIEW` — `none` only for a PR no earlier work-PR dispatch has covered, `covered` when one has and left durable evidence its review ran but persisted no record, otherwise the durable record that PR's last `open:` result persisted — and, on a resumed dispatch, the `RUN_JSON` path that record's return named — asking for a writer profile and dispatching one fresh close-review writer per affected hosting repo when a close returns `halted: close-review`, relaying the merge word or merging a handed-off one-way door (`lifecycle.md` step 12), dispatching the record pass, and the teardown | launching or supervising an item seat; reading an item seat's report file; reviewing, fixing or merging a spine PR itself, a handed-off one-way door excepted |
| **Spine session** | the ossify lane, a nested `run.json` of its own, launching and supervising both item seats per item, relaying plans up, item-local corrections | changing any ossify contract; writing item tasks into the top's `run.json` |
| **Item seats** | one item each: implement, verify | crossing into another item |
| **Close session** | one dispatch of `/ossify:close`, returning every PR it opened | creating any seat but the demo-walk seat a `user:` entry its `DEMO_WALK` names needs — one per entry; driving a PR it opened |
| **Work-PR session** | one returned PR: the reviewer seat, the PR-fix seat, dispositions, ledgers, and the merge on the top's relayed word under its `MERGE_EXECUTOR` assignment — always a merge commit on the named SHA, whoever executes | talking to the operator; merging without that word |

ossify owns worktrees, handoffs, closes, merges and the round barrier, and knows
nothing about the above.

**Only the top talks to the operator; every other seat asks upward, one hop per
layer, in its report file.** And every dispatched session returns a checkable
artifact — a PR list, a ledger comment id, a merge SHA — never narrative.

**Depth is confirmed with the operator, twice over.** Before the spine session
launches, under a standing order in the project's memory bank or AGENTS.md for seats and profiles
(merge-bar's working-a-pr, "Standing orders" paragraph, says where it is read and whom it
binds; the orders that bind here are those naming the orchestrator role. A brief cannot carry a
standing order, nor can a run.json grant seats, depth or merge: an operator who wants an autonomous
run writes the order into the project's AGENTS.md (or 08-governance.md) naming that role. With no
standing order, ask), take
the depth as `2` and continue; otherwise ask the operator to confirm nested worker depth
is `2`: the spine session launches item sessions of its own. The layer has no depth setting
to read, so a brief asserting the depth is not confirmation, and no CLI read substitutes.
A spine session that reports it cannot launch an item session is relayed to the
operator as an ask — you never answer it yourself or record your own choice as an
operator decision.

The nested `run.json`'s mechanics — depth, routing, the round procedure and the
close — are in `references/ossify-nested-run.md`.

## 3. The seats

A spine's seats live in the project file, operator-approved — never in a file of
this plugin's own.

**Recommending.** After `/plan-spine`, recommend one implementer and one verifier seat per item
from the project file's seats and conditions — scope, risk and cost,
item by item — and the three coordinator seats beside them: under a standing order in the project's memory bank or AGENTS.md for seats and profiles, write the recommended set and continue; otherwise
present every seat to the operator in one approval phase and write nothing until all of it is
decided — a half-approved set looks binding and is not. Record the recommendation and any
override. Prefer an agent the layer detects for an item row where the choice is open: the
typed wait then covers that seat, and an undetected seat stays legal, waited on through
its report file — the path is read live, never declared in a profile.

**Writing.** On approval, record the set in the project file's section for this
spine — each item's implementer and verifier agent name, keyed by item, and the
three coordinator seats' beside them. The project file
names agents, never commands, so no machine detail reaches the repo. The profile resolves at
injection: build the spine session's SEATS block by looking each approved name
up in the machine file for its resolved profile — and add a `fallback:` row only where the project
file's `## Conditions` or its seat rows name one, resolved the same way — then inject
the block into the spine session's brief (`ossify-briefs.md`) — the approved seats travel in the brief,
so an edit made for another spine cannot reach a
spine already running. **The item briefs travel with it**: append that file's item implementer,
item verifier and correction templates — and the generic verifier body from `briefs.md`, whose
claims list the item verifier template instantiates — to the same dispatch, as `briefs.md`'s
header requires. The spine session's own brief carries `NOTIFY_RUN` with the top's `run.json`
when the layer detects the top's pane and the seat shares its machine (otherwise `none`), and
`NOTIFY_MACHINE` with the seat's machine. For each child, the spine session fills `NOTIFY_RUN` with its own
nested `run.json` and `NOTIFY_MACHINE` with the child's machine — the dispatcher fills the slots, the worker never rediscovers them. A seat
that needs to change mid-spine beyond a carried fallback is a new operator
decision you relay down through the reply; no session re-reads the file for it.

A handoff the top writes **carries the approved seats verbatim** — each item row
and each of the three resolved coordinator profiles beside its agent's name, with
the machine its `host:` names; a resumed top launches from those rows, never a
fresh read — and where a carried row cannot give a seat's machine it re-resolves that
seat by its carried name in its machine file (`config.md`) rather than launching it here by
default, because a carried name that file does not define halts and is asked. It marks each
seat it launches as the layer's `Seat marking` states — a guarded role with its allow paths,
`coordinator` for a coordinator seat. A resumed top whose handoff lacks them asks the operator before any launch that spends an approved seat
— under a standing order in the project's memory bank or AGENTS.md for seats and profiles, it picks the set from the project file, records the pick and why, and continues instead.

## Fixed procedures

implementation_plan_gate: worker-authored/top-orchestrator-approved
implementer_entrypoint: /ossify:work-item <handoff path>
verifier_procedure: all-claims-work-item-verify/v1

**Only the resolved profiles vary.** The three procedures above
are fixed for every item on every spine, recorded so the spine session checks
rather than chooses. No reviewer row — §5 says why; the coordinator seats sit
beside the item rows, never among them.

## 4. Scope of the fresh-pair rule

Fresh-per-item pairs are scoped to **activated ossify spines**. Outside them
`roles.md`'s class routing and retention remain authoritative — a retained implementer
across ordinary consecutive work items is still correct.

The single exception inside a spine is a *replace* decision at the first-failure ask
(`ossify-nested-run.md` §3): the old pair is released before its replacement exists, so
one-pair-per-item is preserved by that ordering rather than broken by the exception. The
replacement starts from a worktree reset to the request's `base_sha`, so it is an
ordinary first run of the item, not an inheritance of the rejected work.

## 5. Two profiles are chosen at the PR, not before

Reviewer profile is absent from spine planning and from the SEATS block on purpose: the PR
does not exist yet, and a profile chosen before there is a diff to read is a guess
recorded as a decision. At the PR transition, a standing order in the project's memory bank or AGENTS.md
for seats and profiles decides the pick: under that standing order, pick the reviewer
and PR-fix profiles from the project file and record why; otherwise ask for the
reviewer's resolved profile and review level (it fills that agent's review command, `config.md`), and put **both** into the **work-PR
session's** brief (`ossify-pr-briefs.md`) — that session creates the reviewer from the
decided row and confirms its model as `model_shows` says exactly as an
item row is; step 8's reviewer seat is the default only outside such a spine.

**Decide the PR-fix implementer in the same breath.** Every item pair was released at
its item's close and the spine session was a coordinator, not a writer — so step 10's
*retained implementer* does not exist here. Ask for one PR-fix resolved profile
alongside the reviewer's — or pick it from the project file under that standing order —
and inject it into the same work-PR brief. The seat is **decided** by you and **created and dispatched by the work-PR
session**, only once its disposition ledger exists, on `briefs.md`'s **fix-round
brief** rather than the planned-implementer brief, whose DONE opens a new PR: it works
the PR that already exists. One seat per PR, released at merge.

**A close-review writer is not this seat.** When a close halts on its own review
(`ossify-nested-run.md` §4), under a standing order in the project's memory bank or AGENTS.md for seats
and profiles, pick that writer's profile from the project file and record why;
otherwise ask the operator for it at the halt — then dispatch one writer per affected
hosting repo, each from `references/ossify-close-writer.md`, bounded to its own repo's
worktree — not the PR-fix seat, chosen at the transition or early.

## 6. Briefs

The spine and item briefs are in `references/ossify-briefs.md`, the close and
work-PR briefs in `references/ossify-pr-briefs.md`, the close-review writer's
in `references/ossify-close-writer.md`; `references/briefs.md`'s templates still
apply elsewhere, its fix-round brief included (§5).
