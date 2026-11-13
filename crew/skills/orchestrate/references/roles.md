# Roles

One session owns each active role. A session's name or suffix is not its identity: when
resuming, ask each candidate to state its role and assignment and wait for the reply
before sending work.

The seat names below are examples: the project file (`.crew/roles.md`,
`references/config.md`) is the authority for which agent fills each role.

| Role | Seat | Effort | Lifetime | Class |
|---|---|---|---|---|
| Orchestrator | you — the operator launched this session | | one per run | |
| Implementer, planned | `strong-coder` | the seat's — a marked item or a retry fills a higher-effort seat the project file's conditions name, and the machine entry is the only source of effort: never the same command edited | retained across work items and the PR's fix rounds, to the threshold below | `contract`: an interface, schema, contract, or architectural change, or a plan gate; the default when the item is not `bounded` |
| Implementer, fast | `fast-coder` | the seat's | retained if a fix round follows, else released | `bounded` only when the item is one-file, mechanical, or read-only |
| Reviewer | `sonnet-review` — once per PR; first task its review command (`/code-review <PR> <LEVEL>` by default, `config.md` `review:`); never implements | the seat's | disposable; released after its report file validates | |
| Verifier | `strong-coder` — the work-item verify; `fast-coder` for read-only probes and mechanical runs outside it (a suite, a count, a fact) | the seat's | retained until its item passes or escalates to the operator | |
| Operator | the human — the merge word, and decisions no session can own | | | |

The layer's own answer decides a seat's wait path, so where the project file offers a choice,
prefer an agent the layer detects (a `claude-*` lane, `pi`) for the implementer and
verifier roles: the typed wait then covers a live state instead of the report file alone. An
undetected seat stays legal — it is waited on through its report file and pings like any
other — and no profile field declares the path: detection is read live at launch.

## The launch

A seat is a name, never `--model`. The command it resolves to lives in the operator's
machine file; run-time surfaces carry the name only, and a name neither file defines
halts the run. **Both files must exist before this sequence is run**: a seat's role
resolves through the project file and its launch command through the machine file, so
with either absent there is nothing to resolve — that state is `config.md`'s, its
"When a file is missing", not a decision this sequence makes. The launch is this sequence
of the layer's steps, and only the layer's file holds their commands and flags:

1. **Run workspace** — the run's workspace, once per run per server that hosts a seat.
2. **Seat worktree** — the seat's tab, and a new worktree where the seat needs one.
3. **Seat launch** — the tab's pane, the launch environment below, and the seat's command.
4. **Readiness** — the wait the pane's kind takes.
5. **Read** — the model read that confirms `expected_model:`.
6. **Send** — the brief, as `brief_delivery` says.

**A seat on another machine.** A machine entry that names a `host:` (`config.md`) runs
every step above on that machine, through the layer's Machines step: its workspace, its
worktree, its pane and its report file all live there, and its report is read where it was
written. A seat with no `host:` runs here.

**The launch environment.** `Seat marking` writes these into the seat's pane, before the seat's
command, in one export; every layer sets the same names and meanings, because the mods read
them and never ask which layer set them. A guarded seat — implementer, verifier or reviewer —
is marked by its launcher, before its command, with

    SEAT_MODS_ROLE=<role> SEAT_MODS_ALLOW=<REPORT_PATH's directory>:<its scratch directory> MOLT_HANDOFF=parent MOLT_STATUS_PATH=<REPORT_PATH>.molt-status

The names mean:

- `SEAT_MODS_ROLE` — the seat's role: `implementer`, `verifier` or `reviewer` for a guarded
  seat, `coordinator` for a coordinator seat, `orchestrator` for the top's rotation successor.
  A project-file role whose `replaces:` names one of those guarded roles is guarded as that role;
  one with no `replaces:` is a guarded `implementer`, its own report directory and its
  scratch directory in its `SEAT_MODS_ALLOW`.
- `SEAT_MODS_ALLOW` — the colon-separated paths a guarded seat may write: its report directory
  and its scratch directory. A coordinator seat — the spine, close or work-PR session, the
  doctor session, the lane driver — exports the same list with `SEAT_MODS_ROLE=coordinator` **in
  place of** `<role>` and no `SEAT_MODS_ALLOW`: every other assignment on it is unchanged. The
  top's rotation successor's is that variant with `SEAT_MODS_ROLE=orchestrator`. The operator's
  own first top is not launched here — the operator starts it through a `claude-orch` alias
  that sets `orchestrator`. A coordinator takes none, except an OMP coordinator (`config.md`),
  which adds each hosting repo's `.worktrees` root.
- `MOLT_HANDOFF=parent` and `MOLT_STATUS_PATH=<REPORT_PATH>.molt-status` — every guarded seat, every coordinator seat and every operator-declared role. The operator's first top and the top's rotation successor are roots and take neither. What the marking does is `completion.md`'s ("A child past molt's warnings").

Never in `settings.json`'s `env`, a shell profile or a `command:` line. The scratch directory,
created first, is `<run dir>/scratch/<role>-<n>` — `<run dir>` the directory holding the run's
`run.json`, outside every worktree — with no `:` or space in either directory, as `:` separates
the list. An ossify implementer's list adds its handoff's directory; a brief with scratch work
names it `SCRATCH_DIR`. The layer's `Seat launch` says how its own command sets all of this.

**The model read's status line.** The model read of a guarded seat also reads its status line
for `seat: <role>`; its absence there means no guards — unless the seat's row names a `rail:`
(`config.md`), whose check the launching session runs instead, once per launch at the model
read (a molt is not a launch, below): a pass records that rail, a fail no guards. A coordinator records that in its report
file (to the top), the top records one from its own launches to the operator, and a missing
status line halts no seat, re-launches none and is never silently dropped. The layer's step says
which read carries it.

**A molt is not a launch.** The top's in-place molt (`lifecycle.md`, "Where molt runs") keeps
the pane's process and its exports, so its `orchestrator` marking stands across the clear, and
seat-mods reads the role from the environment on every tool call. The status-line check belongs
to the launch read; a later read that finds no `seat: <role>` after a molt is not a missing
marking. A respawned child is a launch: this runs again in full — a fresh export naming its new
`MOLT_STATUS_PATH`, its `SEAT_MODS_ALLOW` rebuilt, and the status-line read, a missing
`seat: <role>` recorded as at any launch.

This file states only the role table and retention. Acceptance of input is not the start of a
turn: the send's own check confirms the turn started in the same call, and the layer's Send
says what to do when it did not. A stalled or timed-out send is never sent again to prove
delivery — a stall does not prove non-delivery — and the state it left is read instead. A wrong model is a failed launch: release the seat and report
it upward, never working around it.

## Retention follows artifacts

The session that built the PR fixes the PR, and an implementer is retained across
consecutive work items. No ownership transfer exists: retain a seat by keeping its
pane and sending it the next task's brief (the layer file says how). At each task
boundary the context probe is `/context`, for a seat whose profile can run a local slash
command (`can: slash-commands`, `config.md`); the layer's Send owns its bounded figure read and unavailable result.
Past half its window, as `/context` reports, or an auto-compact, the next item goes to a fresh implementer. That
probe is the mechanism for the seats that can answer it, and a seat is sent one only when
both hold: its profile can run a local slash command, and the send route that reaches it —
the layer file's send route (`layers/<layer>.md`; its second detection ask's answer where it
has one) — carries one. A seat failing either condition — a profile without the capability,
or a route that cannot carry the command —
is never sent the probe, and rotates at its item boundary instead, on the run's own record:
the item it has just finished, not a probe it cannot answer. The
implementer returns its handoff inputs in its report file; the orchestrator writes the
handoff into the next brief. Rotation happens between work items, never mid-PR: the
retained implementer finishes the PR's fix rounds unless the harness auto-compacts or molt
warns it (`completion.md`, "A child past molt's warnings").
The reviewer owns nothing durable and is released the moment its report file is
processed; the verifier seat is retained across a fail-and-fix cycle on the same item
— the re-check attaches its task to the same verifier — and is released only when the
item passes or goes to the operator. A seat is released as the Teardown order below says —
the same section that states the source repository's workspace a worktree seat leaves open,
which the run did not create and does not close.

## The activated-ossify-spine exception

On a spine this session planned (`ossify-execution.md`), two rows above are
superseded **for that spine's work items only**: the implementer and the verifier
are launched from the spine's operator-approved SEATS rows, whose values may name
a native `claude --model <id> --effort <level>` command rather than an alias; the
model is confirmed as the row's `model_shows` says, exactly
as *The launch* requires; and each item gets a
**fresh** pair, retained across that item's corrections and released when it closes or
escalates. A pair never crosses work items there. The session that launches the seat
marks it in the pane, before its command, as the layer's `Seat marking` states.

Everything else on this page — the class routing, the retention rule, the placement
and writer rules, and the budget below — is unchanged and still governs every session
outside such a spine. The spine session itself is launched **from the `spine session` seat the project file names**
for that spine — marked `coordinator` before its command (the layer's `Seat marking`) —
so the generic lane-driver policy does not select it.

## Session budget

One implementer seat and one verifier seat per work item; one reviewer per PR. A fix
round may re-use the verifier seat, and a context-rotation replacement occupies the
seat it replaces. Any session outside those seats is a planning defect: stop and
re-plan the item. A further read-only question goes to the existing verifier or
implementer as a send, never to a new session.

One further seat the budget admits on declaration, and only for its declared span:
a role the operator pins to a named point occupies a seat for that point's
dispatch — launched when the run reaches the point, released when the role
returns, blocking or advisory — and an `at: on-demand` role occupies a seat for
the dispatch it was wanted for, against the allowance the project file declares,
one at once by default. A declared role past that allowance, or a declared-role
seat lingering past its span, is the planning defect the rule still catches.

**Activated ossify spines add four seats, all outside the per-item budget above:
the spine session, one per spine; a close
session, a fresh tab and pane per close dispatch; a work-PR session, one per returned
PR — each launched from its own seat in the project file (`spine session`,
`close session`, `work-PR session`), marked `coordinator` before its command
(the layer's `Seat marking`), the model confirmed as its profile's
`model_shows` says, as an item row's is — and a close-review writer,
one per affected hosting repo at a `halted: close-review`, launched from the profile the operator
names at that halt (`ossify-close-writer.md`), never a seat the file pre-defines.** The
work-PR session owns the reviewer and the
PR-fix seat inside a `run.json` of
its own, so those two are budgeted there rather than here — the top decides both
profiles at the PR transition and injects them, and neither survives the merge. No
implementer is retained into a spine PR: every item pair was released at its item's
close. None of these seats exists anywhere else. A `doctor session` — one fresh
tab and pane per `/ossify:doctor` dispatch, released on return — sits outside the
budget too, launched from the project-file seat of the same name, marked `coordinator`
before its command (the layer's `Seat marking`).

## Placement

In a dual-repo workspace, the orchestrator and implementers launch from the AI workspace
and address canonical worktrees explicitly, because a session launched inside the
canonical repo never loads the workspace's rules, memory, or handoffs. Reviewer and
verifier may launch inside a canonical worktree for a fresh frame, which is why their
briefs are self-contained. Single-repo projects launch everything in the repo or a
worktree of it.

## Writers

- **One writer per artifact.** A correction to a peer's file travels as a send, never as
  a direct edit.
- **One implementer per worktree.** Two writers never share a checkout. Parallel items
  get parallel worktrees.
- **The orchestrator writes briefs, dispositions, and handoffs.** It writes no product
  file.

## Teardown order

Close only what the run created: a seat's pane or worktree, and the run's own workspace
closes last, after every workspace linked to it. A worktree seat is released once its branch's
work is safe — the implementer's after `lifecycle.md` step 12's merged-branch check, the
reviewer's (it edits nothing) once its report file validates (step 8). Read every receipt — a
failed call reports on stderr and exits nonzero — and confirm against the layer's listing,
never assume: a last pane's close may take its tab and workspace too, and a target already gone
is information, not failure. A refused remove goes to the operator, never a forced one. The
source repository's workspace a worktree seat leaves open was not created by the run and the
operator closes it, never the run (in the dual-repo case the canonical checkout). The layer's
`Teardown` step holds the commands.
