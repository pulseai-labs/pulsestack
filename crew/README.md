# crew

The orchestrator/worker session model over herdr or Orca. One prose skill, one small bash writer for the run file (`bin/crew-run`), no runtime library.

One orchestrator session keeps its context for decisions and dispatches everything else
to worker sessions launched by seat name through the project's layer — the seats defined in the
operator's own files, not in this plugin. A planned-work seat and a bounded-work seat
implement by complexity class, one reviewer seat runs its review command (`/code-review` by default) once per PR and
returns its findings through its report file, the retained implementer works GitHub
threads to zero, and the merge waits for the operator's word or the project's standing order.

Every layer's command syntax comes from its own guide: herdr's from `herdr --skill`, the
binary's own version-matched guide; Orca's from `orca skills get orca-cli`. This plugin
states what a seat is and who does what; it does not re-type either.
`skills/orchestrate/references/layers/herdr.md` and
`skills/orchestrate/references/layers/orca.md` are the two files that record each layer's
half — the launch, the readiness wait, the send and its turn-start check, the waits, the
typed completion states, the teardown commands, and the machines — and each wins where it
differs from its guide. What a finished seat means is layer-neutral and lives in
`references/completion.md`.

## What ships

| Surface | What it carries |
|---|---|
| `orchestrate` (the skill) | The orchestrator session's playbook: the delegation floor and its decidable test, the role list, the run by reference, the briefs, the ossify seam, and the refusals. |
| `references/layers/herdr.md` | herdr's own half, under the thirteen fixed step headings every layer file carries: the run workspace and the seat worktree, the pane and its command, the two readiness paths, the typed wait, the turn-start check on a send, the health read, the teardown commands and the machine labels. The rules every layer obeys stay in the shared files; this file holds herdr's commands, flags and ids. It overrides the guide's default placement. |
| `references/layers/orca.md` | Orca's own half, under the same thirteen fixed step headings: the run workspace and the seat worktree, the terminal and its command, the readiness wait and its screen read, the typed completion state, the turn-start check on a send, the health read, the teardown commands and the hosts it can target. The rules every layer obeys stay in the shared files; this file holds Orca's commands, flags and ids. It says where it overrides the guide's default. |
| `references/completion.md` | How a run learns a seat finished, stated once for every layer: the report-file contract and the dispatch-time generation note, the doorbell and its generation check, the two dead ends, the worker's ping and the heartbeat backstop, a child past molt's warnings, and a child's pain. The layer's `Completion signal` step says how its own state is typed. |
| `references/roles.md` | The role table and the seats that fill it, the launch sequence and the launch environment every layer sets, retention, the session budget, placement for the dual-repo case, the writers rules, and the teardown order. |
| `references/lifecycle.md` | The thirteen-step run, the operator's own roles and the named points they run at, and rotation past the context ceiling. |
| `references/config.md` | The operator's two files, the agent entries and their fields, the resolved profile and where each value travels, the project file's three sections, and what happens when a file is missing. |
| `references/briefs.md` | Ten dispatched brief templates — the generic five (planned implementer, fast implementer, reviewer, verifier, fix round) and the five dedicated dispatch templates the ossify dispatches use (lane driver, doctor dispatch, direct work-item, non-spine close, demo walk) — plus the correction-request message template, which is a send and not a session; the file's header states the whole-contract rule and the dispatch matrix. |
| `references/ossify-execution.md` | The spine execution-assignment contract: the four activation facts, the seats and the layers that own them, the approved block injected into the spine session's brief, and the three fixed procedures. |
| `references/ossify-nested-run.md` | The activated spine's nested run: the required worker depth, the nested `run.json`, the round procedure and its gate, the close, and rotation. |
| `references/ossify-pr-briefs.md` | The two PR-lane briefs: the close session's, and the work-PR session's with the merge bind and its return shapes. |
| `references/ossify-briefs.md` | The four blocks an activated spine's dispatches need: the spine session's brief, the item implementer's, the item verifier's, and the correction message to a live implementer. |
| `references/ossify-close-writer.md` | The close-review writer: one per affected hosting repo at a `halted: close-review`, a profile the operator names at the halt rather than a project-file seat. |

## Command

| Command | Skill |
|---|---|
| `/crew:orchestrate [objective]` | `orchestrate` |

## The delegation floor

The orchestrator's own turns take these kinds of action, and no others: single-command
probes; writing briefs, dispositions, and the handoff; reading the seats' report files;
deciding; conversing with the operator and the workers; executing single authorized
mutations. If an answer needs more than one command's output, it is dispatched to a
verifier session.

## Roles

| Role | Seat | Class |
|---|---|---|
| Orchestrator | this session — the operator launches it | |
| Implementer, planned | a seat the project file names | `contract`, and the default when unclassified |
| Implementer, fast | a seat the project file names | `bounded` |
| Reviewer | a seat with `slash-commands` for `/code-review <PR> <LEVEL>`, or its agent's `review:` command; once | |
| Verifier | a seat the project file names — the work-item verify; read-only probes and mechanical runs may take a lighter one. Read-only | |
| Operator | the human: the merge word | |

Seats are names the operator's two configuration files define — `references/config.md` is
the authority. The skill never substitutes `claude --model`.

## Session budget

One implementer seat and one verifier seat per work item; one reviewer per PR. A fix
round may re-use the verifier seat, and a context-rotation replacement occupies the seat
it replaces. Beyond those, the budget admits three kinds of seat: a role the operator
declares in the project file, for that role's dispatch only and against the allowance the
file declares; a `doctor session`, one per `/ossify:doctor` dispatch, released on return;
and, on an activated spine, the four seats below. Any other session is a planning defect,
and the orchestrator stops to re-plan the item. The authority is the skill's
`references/roles.md`. The implementer is retained across consecutive work items until it
passes half its context window (checked by `/context` at each task boundary for a seat
that can answer the probe — one that cannot rotates at its item boundary instead,
`references/roles.md`) or the harness auto-compacts; the next item starts fresh with the
handoff the orchestrator writes from the inputs in its report file. An activated spine adds
four seats outside that budget
— the spine session, a close session, one work-PR session per returned PR, and a
close-review writer.

## With ossify

ossify's ceremonies (`start`, `adopt`, `plan-release`, `plan-spine`, `wayfinder`,
`challenge`, `handoff`, `handoff-resume`) run in the orchestrator session. Its execution
lanes (`run-spine`, `work-item`, `close`, `work-pr`, `doctor`) are dispatched to herdr
sessions. No ossify contract changes.

`run-spine` is dispatched on its own by default. When this session has just planned the
spine — and only then; installation, an environment variable, or a project file found on
disk activate nothing — the phase in `references/ossify-execution.md` applies instead:
the operator approves one implementer and one verifier seat per work item plus the
coordinator seats, the set is injected into one spine session's brief, and that session
launches a fresh tab and pane per item seat — the implementer and the verifier each in
its own tab. Only the top talks to the operator; every other seat asks upward, one hop
per layer, in its report file, and every dispatched session returns a checkable artifact
— a PR list, a ledger comment id, a merge SHA — never narrative.

## Placement

One tab per seat and one full-size pane per tab: crew places a seat with
`herdr tab create` and **never `pane split`**, because panes sharing a tab make a
multi-agent screen unreadable. That overrides `herdr --skill`, whose "Start and
coordinate an agent" defaults to a sibling split in the current tab — a seat reading
that guide does not split. A run of five seats is five readable tabs. The orchestrator
stays in the pane the operator launched it in, and crew does not move it.

## Seat marking

Every launch that places a seat in a herdr pane marks it, in the pane, before the command
(the layer's `Seat marking`): an implementer, verifier or reviewer seat is
marked with its role and `SEAT_MODS_ALLOW`; a coordinator seat — the spine, close or work-PR
session, the doctor session, the lane driver — with `SEAT_MODS_ROLE=coordinator`; and
the top's rotation successor with `SEAT_MODS_ROLE=orchestrator`. The two free roles
carry no `SEAT_MODS_ALLOW` except for an OMP coordinator (config.md), which adds each hosting repo's `.worktrees` root (colon-separated roots). Never through `settings.json`'s `env`, a shell profile or a
`command:` line. The operator's own top is launched by the operator, through an alias that
sets `orchestrator`; crew launches no top but a rotation successor.
Since 0.2.18, an OMP launcher reads autonomic 0.7.0's live mode file via `AUTONOMIC_MODE_FILE`;
Claude Code keeps reading `AUTONOMIC_EFFECTIVE_MODE`. Only an exact `autopilot` marks a child; unset, missing or older autonomic is manual.

Since 0.2.17, OMP coordinator and worker seats launch through `omp-seat` (see `references/config.md`); OMP seats fill the lane driver (default-lane spine session), close, doctor or worker seats, and, since 0.2.19, the orchestrator top and its rotation successor (`omp-seat orchestrator --via omp-glm`; omp-roles 0.4.0, seat-mods 0.4.4); since 0.2.23, also the activated spine session (`omp-seat crew-spine`) and the work-PR session (`omp-seat crew-work-pr`; omp-roles 0.6.0), which run 788 lifted (#788).

Since 0.6.0, crew sets no ledger, pain-path or mode variable in the launch export, which ends at the molt marking, and no longer reads the launcher's mode; the enrolled OMP authority text is gone from the skill and its briefs.

**Known limit.** `seat-mods` 0.1.0 does not know the two free roles: it reads either as an
invalid role and denies every tool call, so 0.2.7 and later —
the pre-rename line and every `crew` release — need `seat-mods` 0.2.0.
An operator-declared role with no `replaces:` is marked a guarded `implementer` and runs
under implementer rails.

## Readiness and completion

**Readiness is derived, never declared.** herdr answers live which path a seat takes:
whether `herdr agent list` returns a record for the pane. A seat herdr detects waits on
a typed agent state; a seat it does not (an `mcode-*` lane, with no detection manifest)
waits on a screen pattern. A detection manifest landing later therefore moves a seat to
the typed path with no edit anywhere.

**Completion is a report file.** herdr's typed state carries no body, so the file at the
`REPORT_PATH=` the brief names is the contract and the state is only the doorbell. A
coordinator seat — a spine session, a work-PR session, or a `run-spine` lane driver, each
running work of its own in the background — reads ready before its report exists, so it is
waited on through its report file directly. The top is not waited on: it is the one that
waits, and it has no report file of its own. Every file a run keeps is placed outside every
seat's worktree, so removing a worktree never takes one.

**Every wait is one call that returns once** — a background call where the host has one,
the wait in the foreground inside that host's cap where it does not — never a loop, and
never a re-entry after an empty timeout. A round of N parallel items is N such waits, one
per pane, each waking the session when it exits; the round's barrier closes when every
item's report file is in hand.

**A worker also pings.** Every brief names `NOTIFY_RUN` (the run file whose `run.orchestrator` the worker pings) — the
dispatcher's own run file only when herdr detects its pane and the seat shares its machine, otherwise
the sentinel `none` — and after every atomic report rename the worker sends one literal
`[crew report <role>] <task> <kind> <path>` line to the pane read then, single-quoted as one argument and skipped
when the run file is `none`, its read fails or its machine differs from `NOTIFY_MACHINE`: one send, no `--wait`, no retry, and a failed send leaves the report
intact. A brief older than 0.3.1 still sends the legacy `REPORT READY: <task> <kind> <path>` line,
and the reader accepts either form. A skipped or failed send is never an answer: after a plan or a question the worker waits at that gate (#810). A parent herdr cannot target keeps the report-file wait and this heartbeat, no push
promised. The parent consumes a given hash/identity generation once and retires that
dispatch's wait when it does; a ping naming a path other than the briefed report path is
surfaced, never read.
**The heartbeat backstop** is one background timer of about 15 minutes per session holding a
live herdr-pane dispatch — a typed-wait seat included: one
health check per live seat per tick, never a completion wait and never a
re-entry, catching a stopped, blocked or unreadable seat whose wait missed its wake. It is
stopped at teardown and at a rotation's stand-down, and the successor arms a fresh one; a host
with no background timer keeps the wait/ping fallback, never a rolling foreground loop.

## The run's state

A run's state lives in a dagr `run.json`. `bin/crew-run` (bash and jq) takes the attempt transitions
(`open`, `settle`, `send-back`) and any whole document (`commit`), each ending in dagr's producer loop: a temp file
beside the run file, `dagr check --strict`, and the rename only when clean (exit 0 written, 1 findings, 2 refused).
OMP gets it on `PATH` through the marketplace's `bin-path` loader. Codex has no plugin `bin/`, and a file that is not
`"dagr": 3` is outside the writer: there the loop is written by hand (`references/lifecycle.md`, step 1).
**Binding** an existing one is naming its path — and rebinding its `run.orchestrator`
block to the binding session's own pane — and one run is one file per objective. **Creating** one is dagr's producer contract — a temp-file
write, `dagr check --strict`, then the rename (`references/lifecycle.md`, step 1). The top
binds the run's file; a spine session creates a nested one of its own, which keeps item
traffic out of the top's.

## Context ceiling

One fail-open hook, gated on the layer's Identity, tells a seat in a pane its own context
figure once it reaches the `context_ceiling` setting (default 500000 tokens): finish the
unit in hand and start no new one, and a coordinator seat rotates at the next boundary. Any number ≥ 1 is accepted; a fractional ceiling fires at the next whole token (100000.5 at 100001); invalid or sub-1 settings use the default.
It never allows, denies or asks, is inert outside a seat's pane, and reports an unreadable figure as
unavailable rather than guessing. The rotation itself is prose, in
`references/lifecycle.md`. Since 0.2.6 the hook is silent in a session where the `molt` mod
is active, because `molt` owns the context boundary there. Since 0.2.8, every child seat is
launched as a molt child (`MOLT_HANDOFF=parent`): at molt's warnings it pings its parent and
hands off at its next boundary, and molt never clears it; only the top molts in place
(`references/lifecycle.md`, "Where molt runs"). Install molt 0.2.0 with `crew` — the
pre-rename 0.2.8 and later mark their children. Since 0.2.9, the same launch export carries `autonomic`'s three variables: every
Claude Code child (autonomic is a Claude Code mod) writes the run's one ledger and its own pain file beside its report, and runs in
autopilot only when its launcher does (the layer's `Seat marking`). Since 0.2.10, the
launcher's mode is autonomic's live `AUTONOMIC_EFFECTIVE_MODE`, never its record file, which can be
stale after a failed write. Since 0.2.11, the suite `tests/test-launch-site-marking.sh` selects the launch
shapes its own header lists and fails a selected site whose own paragraph or list item
carries no seat-mods marking clause (the layer's `Seat marking`); the shapes it does not select are named under
NOT COVERED in that header. Test tooling only — no shipped behaviour changes. That hook and `crew-run` are the only deterministic code a run executes: a run
has **no `lib/`, no state directory of its own, no parser** — `agents.md` and `roles.md` are read as
prose and nothing parses them. The suites and the eval harness under `tests/` are
build-and-test tooling; the plugin never runs them on a user's path.

## Configuration

Two operator-owned markdown files, read as prose — nothing parses them.
`~/.claude/crew/agents.md` is the machine file: the agents this machine can
launch, one block each, with the field table in `skills/orchestrate/references/config.md`
saying what each means and where it travels. `<project root>/.crew/roles.md` is the
project file: which agent fills each role, the operator's own roles, and the conditions
that choose between seats — it wins for anything it names. Its first non-heading line is the
mandatory layer line — `layer: herdr` or `layer: orca`, and a missing or unknown value stops the run
with one question. With neither file the
session's own work needs no setup, and the first delegated dispatch halts naming the file
to add; a seat name neither defines halts the run.

Only those two paths are read: the project file is found by walking up from the
session's working directory looking for `.crew/roles.md`, and the machine file
has one fixed path.

## Requirements

- The project's layer running, and the orchestrator session itself running inside one of
  its seats: the layer's Health step is the check (`references/layers/herdr.md`, Health, for
  herdr 0.9.1+), and its Identity step gives this session the address the context-ceiling hook
  reads (`references/layers/herdr.md`, Identity), because every seat is
  placed relative to the seat the operator launched this session in.
- The **`herdr-dagr`** plugin's `dagr` binary on PATH, to create and lint the run's
  `run.json`: dagr's producer contract resolves that validator *before* anything is
  written, and with none available the run starts no run file — not an unvalidated one.
- `jq` on PATH for the context-ceiling hook and `crew-run`; without it the hook reports the figure as
  unavailable and `crew-run` cannot run.
- The agents named in `~/.claude/crew/agents.md` resolvable where their pane
  runs; one that is not shows `command not found` and stops that dispatch.
- The review command (`/code-review` by default, or the agent's `review:`) available to the reviewer session. If it is unavailable, the
  reviewer reports that in its report file and the operator decides.
- The target repository's ruleset requires conversation resolution before merge, so
  GitHub itself refuses a merge while any review thread is open.

## Tests

```bash
bash crew/run-tests.sh
```

Every suite under `tests/` (`test-*.sh` — the runner globs them rather than listing them):
frontmatter and invocation posture across the three surfaces; five fidelity pins, each
exactly once; the brief envelope's layer-Send lines; the herdr mechanics contract; the
layer boundary, which sweeps the shared files for a layer's commands and the thirteen step
headings a layer file must carry; the config contract, including the sweep for a personal
name across the shipped prose surfaces; the launch sites' seat-mods marking clause; the
ossify spine-execution contract; and the context-ceiling hook's behaviour at its interface.
A session-driven eval harness for the spine-execution surface lives under `tests/eval/` and
is run by hand from its RUNBOOK — the runner does not execute it.
