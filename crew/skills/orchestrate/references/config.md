# Configuration

Every seat a run uses, and every value in its profile, is a value the operator
edits, not a fact the plugin hard-codes: nothing parses the two files that follow.

## The two files

`~/.claude/crew/agents.md` is the machine file — the agents this machine can
launch. It is written by the operator, with an agent's help, between runs and never
edited during one, and nothing in it is project-specific.

`.crew/roles.md` sits at the project root — which agent fills each role for the work
at hand, plus the conditions that choose between seats. The orchestrator writes it on the
operator's instruction at spine planning, and the operator approves it before use; it names
agents by name, never by command, so no machine detail reaches a repo. For a dual-repo project
the project root is the AI workspace, where orchestrators launch; a single-repo project uses
that repo.

The project file's first non-heading line states the layer — `layer: herdr` or `layer: orca`. A missing or
unknown value stops the run with one question, and there is no default. The value names the layer file the run loads, `references/layers/<layer>.md`.

Resolution is a walk up from the session's working directory; the first project file found wins. The pairing manifest is not consulted — its absolute roots can belong to another host.

The project file wins for anything it names — a seat, an extra role, a condition; it never
redefines how an agent is launched. Workers never read either file — a brief is the whole contract a worker sees.

## Agent entries

The machine file is one block per agent, named by a `###` heading. Every entry has this shape:

```markdown
### mcode-glm
command: mcode-glm
expected_model: <the model id its banner or screen must show>
effort: (agent default)
model_shows: screen
brief_delivery: file
can: —
```

Each field exists because a measured case needs it:

- `command:` — the exact command run in the seat's pane.
- `expected_model:` — the model id the seat must show where `model_shows` reads
  it — never parsed out
  of `command:`. A `--model` flag in the command must agree; a disagreement is a
  config defect named at approval, never reconciled at launch.
- `effort:` — the effort the seat runs at, and the only source for a brief's
  `SEAT_EFFORT`: the embedded flag's value, or `(agent default)`.
- `model_shows:` — where the launched model is verified, both read by the layer's
  Read: `banner` the emitted stream; `screen` the rendered screen — a
  status-bar agent returns nothing on the default read.
- `brief_delivery:` — absent means `file`: the brief is written to a file and one line points at it (the layer's Send); `inject` sends the text as a shell argument.
  A seat on another machine states `inject` — its file would sit on the wrong machine, a known limit — and an entry naming such a `host:` without it is a config defect named at approval.
- `host:` — the machine this seat runs on; absent, this machine. A value is a machine
  name the layer file's Machines step accepts, and one that step does not know halts the
  run rather than being guessed at. A seat runs elsewhere only when the operator names one
  here: place it only on a machine that stays up and whose filesystem this run can read —
  resolve its paths on its own machine, never consuming one from a remote reply, and
  inspect the remote state before retrying, because a connection failure does not prove
  a mutation was not applied. The layer's Machines step says how to reach one.
- `can:` — what the agent is able to run, comma-separated: `slash-commands`, `subagents` (the lane's `Agent`-tool workers), or `—`. The per-role requirement, and where it is checked, are stated below.
- `rail:` — optional, one line `<guard> — <check command>` holding no `|` (the row's separator): the guard
  this agent runs under in place of seat-mods and the one command that checks it (`devin-seat guard — guard.py --selftest`); the model read takes it (`roles.md`).
- `review:` — optional: the command a reviewer seat on this agent runs, `<PR>`, `<PR_URL>` and `<LEVEL>` filled at dispatch (`/review <PR_URL>` on OMP); absent, `/code-review <PR> <LEVEL>`.
- `note:` — free prose the coordinator reads when it uses that agent.

A seat's readiness path is never a field here: it follows from the layer's own answer
to whether the pane is detected (`layers/<layer>.md`) — so a detection manifest
landing later moves a seat onto the typed path with no edit anywhere.

**OMP coordinator seats.** Put `omp-seat` on PATH with the symlink in [omp-roles' Install step](../../../../omp-roles/README.md#install); an OMP seat fills the lane driver (default-lane spine session), close, doctor or worker seats (`omp-seat worker --via <wrapper>`), and, since 0.2.19, the orchestrator top and its rotation successor (`omp-seat orchestrator --via omp-glm`; omp-roles 0.4.0, seat-mods 0.4.4); since 0.2.23, also the activated spine session (`omp-seat crew-spine`) and the work-PR session (`omp-seat crew-work-pr`; omp-roles 0.6.0), which run 788 lifted (#788). Every OMP coordinator seat adds each hosting repo's `.worktrees` root (colon-separated roots) to its `SEAT_MODS_ALLOW`: its procedure and the omp task children that inherit its env write item worktrees.
```markdown
### omp-spine-deepseek
command: omp-seat spine-driver --via omp-deepseek-go
expected_model: DeepSeek V4.1 Flash (OpenCode Go)
effort: max
model_shows: screen
brief_delivery: file
can: subagents
note: OMP coordinator (omp-roles). seat-mods and molt run as OMP extensions; mark the pane SEAT_MODS_ROLE=coordinator (the layer's `Seat marking`) and add SEAT_MODS_ALLOW=<each hosting repo>/.worktrees (colon-separated roots) to its export: omp task children (implementer, seat-reviewer) inherit the env, and the implementer must write the item worktree; herdr-restore relaunches the --via wrapper without omp-seat, its two extensions or its exports — release a restored OMP seat and relaunch through omp-seat.
```

## What a resolved profile carries

An agent name resolves through the machine file to a **profile** — the values a
launch needs. This table is the contract for which travels where: every surface
carrying a profile conforms rather than restating a field list.

| field | set by | consumed at | travels |
|---|---|---|---|
| `command:` | the machine entry | the layer's Seat launch | every resolved profile |
| `expected_model:` | the machine entry | the model read | every resolved profile |
| `effort:` | the machine entry | the launch | every resolved profile |
| `model_shows:` | the machine entry | the model read | every resolved profile — the launching session never opens this file |
| `brief_delivery:` | the machine entry | the brief's delivery | every resolved profile |
| `host:` | the machine entry | the launch | every resolved profile that crosses a session — the row names the machine, so a launcher that did not resolve the seat itself starts it where the resolver would |
| `can:` | the machine entry | the seat's approval | never — checked where a seat is approved |
| `rail:` | the machine entry | the model read | every resolved profile that names one, as the row's tail |
| `note:` | the machine entry | the coordinator's read | never |

A resolved profile renders as one row wherever it travels:

`<agent name> | <command> | model: <expected model> | effort: <effort> | model_shows: <banner|screen> | brief_delivery: <inject|file> | host: <machine>[ | rail: <rail>]`, the bracketed tail only where the entry names one

The row names its agent first and its machine after every launch field, only a rail's tail after it: a session that receives it neither
guesses a machine nor loses the name a resumed top re-resolves a carried seat by. Where the
entry names no `host:`, the row names the resolver's own machine under the layer's Machines
step's name for it — never the words `this machine`, which would mean a different host in
every session that read them.

A brief's record of its own seat's launch is the row's command and effort only —
a session launches nothing with its own profile.

`can:` is checked where a seat is approved — the project-file approval, the spine-seat approval (its fallback rows included), the PR-transition ask, the close-review halt ask — never at dispatch. The requirement is per role: a role whose shipped or declared brief invokes a slash command needs `can: slash-commands` on the agent that fills it.

| role | its brief invokes | needs |
|---|---|---|
| reviewer | its agent's `review:` command, else `/code-review` | `slash-commands` when that command is a slash command |
| implementer, verifier | no command | — |
| fix-round implementer | `/ossify:work-pr` when ossify is installed | `slash-commands` then |
| ossify item implementer | `/ossify:work-item` | `slash-commands` |
| item verifier | no command | — |
| spine session, default lane | `/ossify:run-spine`; spawns `ossify:implementer-agent` subagents through the `Agent` tool | `slash-commands, subagents` |
| OMP seat (omp-roles spine-driver), default lane | the role file carries the procedure by `skill://`; the brief's `/ossify:run-spine` reaches it as text | `subagents` |
| spine session, external-executor lane | `/ossify:run-spine` | `slash-commands` |
| close session | `/ossify:close`; for a work-item id, work-item close dispatches `ossify:verifier-agent` (inline where none can be dispatched) | `slash-commands` |
| OMP seat (omp-roles close), close session | the role file carries `skill://close` (the brief's `/ossify:close` reaches it as text); for a work-item id, work-item close dispatches `verifier` through `task` (inline where `task` lists none) | — |
| work-PR session | `/ossify:work-pr` | `slash-commands` |
| doctor session | `/ossify:doctor` | `slash-commands` |
| OMP seat: doctor session or ossify item implementer (omp-seat worker), activated spine session (omp-roles crew-spine), work-PR session (crew-work-pr) | the brief's `/ossify:<skill>` reaches it as text; the seat follows `skill://<skill>` | — |
| PR-fix seat inside work-PR | none — the clause is removed | — |
| close-review writer | no command | — |
| an operator-defined role | whatever its `brief:` invokes | as declared |

**A profile that crosses a session carries its seat's machine and its agent's name.** A
profile that crosses to another session — a spine's `SEATS` block, the work-PR brief's
reviewer and PR-fix rows, a handoff's carried seats, the close brief's demo-walk row — is the
row above, host included; the receiving session launches the seat where the row names it,
marking it as the layer's `Seat marking` states, and never infers a machine. The name each
row carries is what a resumed top re-resolves a carried seat by (`ossify-execution.md`).

## The project file

Three sections. `## Seats` is a table of role, agent name and when:

```markdown
## Seats

| Role | Agent | When |
|---|---|---|
| orchestrator | <this session's seat> | |
| implementer | strong-coder | default |
| implementer | fast-coder | the item is one file, mechanical, or read-only |
| verifier | strong-coder | |
| reviewer | sonnet-review | every PR |
| spine session | strong-coder | |
```

`## My roles` holds the operator's own roles as blocks (next section). `## Conditions`
is free text: sentences the coordinator reads when it picks a seat (a stalled seat's
fallback and bound among them, `completion.md`), and nothing parses them. The plugin ships the role list — orchestrator, implementer,
verifier, reviewer and the coordinator seats (spine session,
close session, work-PR session), plus a `doctor session` for `/ossify:doctor`
dispatches, and baton's `driver` (settles the parks its brief names). Crew's own runs do not launch it; baton reads these two files through running-a-spine-on-baton. The project file fills them and does not define new
built-ins. The close-review writer is not a project-file seat — the operator names
its profile at the halt that creates it (`ossify-close-writer.md`).

## Roles of the operator's own

A role under `## My roles` is a block:

```markdown
### security-audit
at: before-merge-ask
agent: sonnet-review
blocks: yes
brief: ./briefs/security-audit.md
```

- `at:` places the role at a named point of the run (`lifecycle.md`):
  `after-implementer`, `before-review`, `after-disposition`, `before-merge-ask`,
  `at-teardown` — or `at: on-demand`, with no fixed point, dispatched when wanted.
- `agent:` — the seat name the role launches on.
- `blocks:` — `yes` holds the run at its point until the role passes or the operator
  overrules it; anything else it returns is advice the orchestrator records.
- `brief:` — the file the coordinator sends as that role's brief. It must carry a
  report envelope — a `REPORT_PATH` and a completion shape — checked at approval
  with `can:` and the block's other fields; without one the role cannot return. The
  coordinator sends a copy carrying the run's `NOTIFY_RUN` (the run file whose `run.orchestrator` the worker pings) slot, `NOTIFY_MACHINE` and ping step beside that
  envelope (`briefs.md`), and edits no stored file: a stored brief whose fixed run file or fixed machine differs from
  the run's is a conflict surfaced to the operator, never overridden; equal values are no conflict, kept as they are.
- `replaces:` — hands the role a step the plugin owns; the valid targets are
  `implementer`, `verifier`, `reviewer` only. The named seat is not launched for
  that run — the operator's role runs at the step's point in its place, and the
  handoff states the step was the operator's, so no reader infers a guarantee not
  given. The merge ask, teardown and the coordinator's decisions are not
  replaceable; a spine's seats need none — each is already the operator's choice.

On-demand seats cost sessions: the project file says how many may exist at once, the
default is one, and anything beyond the declared number is a planning defect.

## When a file is missing

What the session does itself — reading, planning, the ceremonies it runs in its
own context — needs no setup in any state: every role falls back to the agent this session is already running, and crew works on install. Delegation meets each state's missing half — a session cannot recover its own launch command, so the first delegated dispatch halts; which file it names depends on what exists:

- Neither file — the machine file and the one entry to add, in the shape below, plus the
  project file, whose first non-heading line is its `layer:` line.
- Machine file only — agent names have launch details but no role mapping; it
  names the project file, its `layer:` line and the `## Seats` section to add.
- Project file only — roles name agents nothing resolves; it names the
  machine file and the entry to add.
- The old path only — a file left at its old name: the run stops, prints the move and reads no old file:
  `mkdir -p ~/.claude/crew && mv ~/.claude/herdr-crew/agents.md ~/.claude/crew/agents.md` (machine file), `mv .herdr-crew .crew` (project file) — the moved project file
  then needs the `layer:` line 0.3.0 introduced, before any seat is launched.

The operator writes the machine file once per machine; this is the shape to copy:

```markdown
### my-coder
command: my-coder
expected_model: my-model-1
effort: (agent default)
model_shows: banner
brief_delivery: file
can: slash-commands
```

A run never writes machine-level configuration itself. A name the files do not
define is never guessed — a seat name that neither file defines halts the run
and is reported, exactly as a missing alias did.
