# baton

A recipe-driven engine. On a systemd timer it launches model sessions on a host when a unit is
due, waits on closed signals (a done-file, a thread's turn end, a PR's checks) at no token cost,
merges a pull request only by the recipe's rule, and notifies on parks, stalls and a host outage.
A merge-stage park on red checks or a conflict names the PR and the failing checks in its notice.
A recipe with a `driver` stage sends the operator only what a driver could not settle (see Driver).
It judges nothing: anything that needs judgment is a session the recipe launches. It ships a CLI,
a claim launcher, a timer and one skill (see Skill). It runs workers in Orca terminals (see Orca
host). Needs `bun`.

## Install

Install the plugin, then link `baton` onto `PATH`:

    ln -sf <plugin root>/bin/baton ~/.local/bin/baton

`bin/baton-seat` is not linked: the Orca host runs it from the plugin root (see Orca host). The
timer's unit runs `~/.local/bin/baton tick`, so re-point the symlink after a plugin update and the
timer follows. `baton timer install` writes `baton.service` and `baton.timer` under
`~/.config/systemd/user` and enables the timer (it ticks 2 min after boot, then every 90 s);
`baton arm` does the same unless it gets `--no-timer`. `baton timer remove` undoes it.
The service keeps `BATON_STATE_DIR` and `BATON_CONFIG` as they were set at install time; change
either and run `baton timer install` again.

## Orca host

Orca is the only host: each worker runs in an Orca terminal. No `host` key, or `"host": "orca"`,
selects it; any other value, `"t3"` included (the T3 host was removed in 0.6.0), fails `arm` and
the tick with `config: host must be "orca"`. A thread is a terminal: its id is the terminal handle,
and the title ends with `[baton <nonce>]`.
A recipe's `project` (and the example's `ai_project`) names an Orca repo by its display name; none,
or two, with that name refuses the launch.

Config keys (all optional; the `orca` block sits beside `host`):

- `host`: `"orca"`, the default and the only value.
- `orca.cli`: the `orca` binary, `~` expanded. Default: `orca` when it is on `PATH`, else
  `~/.config/orca/cli/bin/orca` (the timer's unit has no `orca` on its `PATH`).
- `orca.launcher`: the script the terminal runs. Default: baton's own `bin/baton-seat`.

The launcher. The host writes the launch message to a file under `<state>/orca/messages/` and runs
`orca terminal create` with the command
`cd '<cwd>' && BATON_STATE_DIR='<state dir>' exec '<launcher>' '<message file>'` (an Orca terminal
inherits orca-serve's environment, not the timer's); only those paths reach a shell.
`bin/baton-seat` reads the claim baton wrote for its directory and reads and deletes the message
file. A role stage's claim carries `BATON_ROLE` and `BATON_ROLE_TABLE` (see Seats): it execs that
role's `argv` with no shell, the message as the last argument (`brief_delivery` `inject`) or, for
`file`, the message copied to `<state>/briefs/<nonce>.md` and the last argument
`Read <state>/briefs/<nonce>.md and follow it.` (`/` in the nonce is written `%2F`). A claim without `BATON_ROLE` (a staged recipe's)
execs `omp-seat <seat> --via <via> <message>` from its `OMP_T3_SEAT` and `OMP_T3_VIA` keys (see
Known limits). It refuses with exit 78, one line on stderr and one in `<state>/claims/seat.log`, on
no claim, a bad claim line, a claim with neither a role nor a seat and via, a role table that is
missing or lacks the role or its argv, an injected message that is missing or 131072 bytes or
more, or a program it cannot run (the message file stays); it never starts a seat without its
claim. A run's message files left behind are removed
when the run finishes and on `baton disarm`.

Status and interrupt. From `orca terminal list` and `orca worktree ps`: a terminal not listed is
`gone` only when `orca terminal read` confirms it (a terminal-gone error or status `exited`), and a
host outage otherwise; an agent `working` is `active`, unless its `programStatus` is `blocked`;
`waiting` or `blocked` is `waiting`; `done` is `completed` (`interrupted` when Orca says so). A missing agent row or an unknown state is
`active`, never `completed`, and a truncated list, or one that does not cover the local host, is a
host outage, never `gone`. Interrupt sends Escape to the terminal, twice for a Devin turn at work
(see Known limits on Orca). A session end closes its
terminal before the launch directory is released, except a park (the terminal stays until `unpark`
or `disarm`) and an end after `interrupted` (it stays until the run ends); driver and
molt-parent terminals close too.

The blocked park. A worker in `waiting` with no structured question (an omp `ask` dialog shows as
`blocked` with its text but no options) parks at once, on the next tick, and keeps its terminal: no
interrupt, claim and directory stay. The notice reads
`baton <run>/<unit> blocked in <stage> (project <project>): the worker waits on a question — answer it in the worker's terminal — screen: <tail>`.
The tail is the screen's last 12 non-empty lines, at most 1500 characters. When the screen holds a
live picker (see Answering a blocked park) whose question line is not among them, as an omp `ask`
box is taller than the tail, the tail starts with it: `<question> | … | <last lines>`.
Answer in the worker's terminal in Orca; when the worker moves on, the park clears itself and the
session is watched again. `baton unpark <run> <unit>` clears it by hand, and `--to <stage>` ends
the session and moves the unit. A stop file wins, `disarm` closes the worker, no driver takes it
and no stall clock runs on it; the run summary counts it as sent to you.

A question reaches the operator, not a model: through the blocked park, and the picker it shows (see
Answering a blocked park). The known limits below name the cases the blocked park misses, where the
stall rule catches the seat.

Known limits on Orca (Orca 1.4.238, recorded in the host's fixtures):

- A picker opened between turns (an omp `/review` picker) leaves the agent row `done`, so the worker
  reads `completed`, not blocked.
- An aborted omp turn reads `completed`: Orca does not report `interrupted` for it.
- Escape aborts a plain omp turn, but a worker in an `ask` dialog or with a live async subagent may
  keep running after it (a subagent keeps the worker `working` until it ends). The first stall ends
  the session and closes its terminal, but a park (the second stall, or a stop file) keeps the
  terminal, so such a worker can keep running until `unpark` or `disarm`.
- `state` lags on two agents (Claude Code 2.1.316, Devin 3000.11.234). A Devin seat on a question
  stays `working`, so the host also reads `programStatus: blocked` on a `working` row as waiting. A
  Devin turn stopped by Escape stays `working`, so it reads `active` and runs into the stall clock.
  A Claude Code picker cancelled by Escape stays `waiting` until the next turn, so a tick that sees
  it makes a blocked park with no picker on the screen.
- Interrupt is per agent. Claude Code's turn stops on one Escape. A Devin turn at work
  (`programStatus: working`) gets two Escapes in two sends: one does nothing, and so do two in one
  send. A Devin picker gets one, which cancels it. Two at an idle prompt open a revert menu on both
  agents, which a stale row can cause on Devin; the operator closes it with Escape. A Devin turn at
  work whose row cannot be read gets one Escape, which does nothing; the stall rule catches it. A
  stopped Devin turn leaves its background shells running until the terminal closes.
- `baton disarm` leaves live (non-parked) workers running; their terminals and per-launch
  worktrees stay until you close them by hand.
- After an Orca restart the terminals and their processes survive, but a live worker has no agent
  row until its next hook event and reads `active`: a worker blocked across a restart is caught by
  the stall rule, not the blocked park.
- A process that dies leaves the terminal list and reads `gone`; a `baton-seat` refusal reads the
  same way. Orca has no failure state to map, so a `thread gone` park's notice ends with
  `— if the launcher refused it, the reason is in <state>/claims/seat.log` (the absolute path).
- The question is kept in a blocked park's screen tail only for a picker `baton screen` can parse;
  a screen of any other shape gets the plain last lines.

## Answering a blocked park

A blocked park's worker waits on a picker baton cannot answer through the host. Two commands let
a caller answer it from outside the Orca terminal, with keys checked against a fresh screen:

    baton screen <run> <unit>
    baton answer <run> <unit> --park <at> --screen <n> <label>
    baton answer <run> <unit> --park <at> --screen-text <text> --question <line>

`baton screen` prints one JSON line, `{"park_at", "thread", "screen", "picker"}`: the park's `at`
(the last part of its notice key), the worker's terminal, its screen read now, and the picker parsed
from it, `{"kind", "question", "options": [{"n", "label"}], "other"}` (`devin-ask` adds `cursor`) or `null`. It reads only:
no lock, nothing sent. rc 2 when the run is disarmed or done, the unit is not in a blocked park, an
`unpark --to` is in flight, the unit's session is not the park's thread, or the host has no
`screen`; 3 host auth, 4 host down.

Two picker kinds are known, as omp v18.11.3 draws them: `omp-ask` (the `ask` tool's box, headed
`Ask`, `○` rows, an `Other (type your own)` row last, which `other` numbers and `options` leaves
out) and `numbered` (omp's `/review` box, `Review Mode`, rows `<n>. <label>`; its question is the box
title). Only a box followed by a `⏎ select` footer is live: the `ask` call above it, an answered
picker and the free-text box read as no picker.

Two more, as Claude Code 2.1.316 and Devin 3000.11.234 draw one question with one answer:
`claude-ask` (AskUserQuestion: ` ☐ <header>`, the question, `<n>. <label>` rows, `Type something.`,
then a rule and `Chat about this`; `other` numbers the `Type something.` row) and `devin-ask`
(ask_user_question: `── <title> ──`, the question, `<n> <label>` rows, an unnumbered `Other (type your
own)`; `other` is one past the last option, and the picker also carries `cursor`, the cursor's row).
Each is live only with its own footer as the screen's last line.

`--screen` selects option `<n>` and `--screen-text` types `<text>` through the Other row. Both run
under the store lock, read the screen again, and send keys only when every check passes; each
failed check is rc 2 with one line `baton answer: <reason>` and nothing sent:

- the run is disarmed or done; the unit is missing, not in a blocked park, has an `unpark --to` in
  flight, or its session is not the park's thread;
- `--park` is not the unit's park `at` (the park was cleared and a new one opened);
- the host has no `screen` or no `keys`;
- the screen shows no live picker;
- `--screen`: option `<n>` is not labelled exactly `<label>`;
- `--screen-text`: the picker's question line is not exactly `<line>`, the picker has no Other row,
  or `<text>` is empty or holds a control byte (any byte below 0x20, and 0x7f: an Enter, an Escape
  or a tab would act on the terminal, not arrive as the answer).

The keys are fixed per kind. On `omp-ask` and `numbered`: Up once per row (the Other row counted; Up
stops at row 1), Down to the row, Enter, in one send, and free text is three sends: to the Other row
and Enter, the text, Enter. On `claude-ask` and `devin-ask` the rows wrap, and a digit selects its row
from anywhere, so an answer is one digit. Free text on `claude-ask` is the `Type something.` row's
digit (which only moves there), the text, Enter. On `devin-ask` it is Up once per cursor row, one send
each (Up from row 1 wraps to Other), the text, Enter.
An answer records `{"kind": "answered", "unit", "screen": n, "label"}` or
`{"kind": "answered", "unit", "screen_text": true}`; the text itself is not logged. rc 64 for any
other argument shape, the three-argument `baton answer <run> <unit> <label>` included (removed in 0.14.0).

Known limits:

- A picker of any other shape reads as no picker, and both answer forms refuse it. Answer it in the
  terminal. That covers two questions in one call and multi-select on Claude Code and Devin, a typed
  draft or the cursor on `Type something.` or `Chat about this` on Claude Code, and the cursor on Other
  on Devin.
- A label too long for one line reads only up to the wrap: its other lines look like a description.
  A question spans its lines, joined by one space.
- `--screen-text` needs an Other row, so it does not work on `numbered`.
- The numbered `/review` picker rarely reaches a blocked park on Orca: a picker opened between turns
  leaves the agent row `done` (see Known limits on Orca).
- The free-text sends are not checked between each other: a host failure after the first leaves the
  free-text box open, and the answer is rc 4 with no event.
- The check and the send are separate Orca calls: a picker that changes between the read and the
  send gets keys meant for the one read.

## Skill

`running-a-spine-on-baton` is for a project's orchestrator session asked to run a planned ossify
spine on baton. It runs a read-only preflight, shows the exact `baton arm` command for the
example recipe with where each value came from and the seat table it resolved from crew's
`.crew/roles.md` and `~/.claude/crew/agents.md` (see Seats), arms it only on the operator's yes, and then
hands the run to a lean successor session: baton's notices reach that orchestrator session (see
`notify-orchestrator`), which rules or asks the operator by the skill's `## Notices` table, and
status is read on request. It points here for the commands and the runbook. Claude Code
only: baton has no Codex manifest.

## Commands

    baton validate <recipe.json>
    baton arm <recipe.json> --run <id> [--param k=v]... [--seats <file>] [--no-timer]
    baton clone <run> <new-id> [--recipe <file>] [--param k=v]... [--reset <unit>[=<stage>]]... [--fresh]
    baton status [<run>]            baton report <run>
    baton disarm <run>              baton tick [--run <id>]
    baton unpark <run> [<unit>] [--to <stage>]
    baton answer <run> <unit> --park <at> --screen <n> <label>
    baton answer <run> <unit> --park <at> --screen-text <text> --question <line>
    baton screen <run> <unit>
    baton orchestrator <run> [--clear]
    baton notify-orchestrator <key> <message>
    baton timer install|remove

`orchestrator` writes `<state>/runs/<run>/orchestrator`, `{handle, incarnation}` from
`$ORCA_TERMINAL_HANDLE` and `$ORCA_RUNTIME_SOURCE_INCARNATION`, so the project's orchestrator
session registers itself for the run (it refuses when either is unset, or the run does not exist);
`--clear` removes it, and a session stands down that way first. `notify-orchestrator` is the
config's `notify` argv, not a command to type: for a run-scoped key (the key's first segment is a
run on this host) it writes the notice to `<state>/runs/<run>/notices/<key>.md` (mode 600; each
character of the key outside `A-Za-z0-9._-` becomes `_`), then
sends the registered terminal one line, `[crew message baton] baton notice <key>: read <file> and
follow running-a-spine-on-baton §Notices.`, with `orca terminal send --enter --wait-submit 5`. Each way
it fails to deliver adds a line `<iso> <key> notify-orchestrator <where>: <reason>` to
`<state>/notify.log` (the reason capped at 300 characters of Orca's message). A
queued receipt is a success. A host-wide key (`auth/<day>`, `down/<day>`), no pointer, an Orca
restarted since the pointer was written (`orca status`'s `runtime.runtimeId` differs from the
stored incarnation), or a failed send runs `fallback_notify` instead; the whole command stays
inside the 30 s bound and always exits 0. A line sent while the operator is typing in that pane can
join the operator's text.

`unpark` acts on a parked unit; a unit that is running (a live session, not parked) is refused
with rc 2. A plain `unpark` of a stage where a worker had run reads the stage's outcomes before it
launches again, and a result already in place moves the unit with no seat (a `relaunch skipped`
event); `unpark --to <stage>` enters a fresh visit and launches without reading them.

### Clone

`baton clone <run> <new-id>` makes a new run from an existing one, for a rerun or a test. Use it in
place of copying a run directory by hand. It is mechanical work on baton's own state, and it
refuses before it writes anything.

The clone holds `run.json`, `recipe.json`, `seats.json` (when the source has one), a fresh
`events.jsonl` with one `cloned` line, and empty `queue` and `out`. Nothing else is copied: not
`spine/`, whose unit files a source would read again, and not the source's own `out` files. The
recipe is the source's, byte for byte, and `recipe_sha256` is taken from the bytes the clone holds.
Units stay an object keyed by unit id.

A clone starts **parked** for the reason `cloned`. The tick does nothing for it, not even a read
of its sources, until you run `baton unpark <new-id>`. That is the one step that starts it. Clone
installs no timer and does not change the source. The source may be in any status.

Each unit keeps its group, order, vars and stage, and starts a fresh visit to that stage: no
session, thread, claim, driver or request record, no park, and zero launches and stalls. A
param or var that holds the source run's directory follows to the new one; a path under another
run's directory (`r10` beside `r1`) does not.

| Flag | Does |
|---|---|
| `--recipe <file>` | Pins the clone to another recipe instead of the source's. It must validate, name only stages the units are in, and find every role in the source's `seats.json`. A param it declares that the source lacks needs `--param`. |
| `--param k=v` | Sets a declared param. Without it the source's value stands. |
| `--reset <unit>` | Sends a seed unit back to its seed stage and vars. |
| `--reset <unit>=<stage>` | Sends any unit to that stage (`done` and `park` included). Repeatable. |
| `--fresh` | Writes the recipe's seed, as `arm` does, and drops every other unit; the first tick that runs reads the source units again from their files. Not with `--reset`. |

It refuses, with rc 2, a source that does not exist or whose `run.json` is malformed, a new id that
exists or that `arm` would refuse, a recipe that does not validate, a missing or undeclared param,
an unknown unit or stage, and a role the source's seat table lacks. A usage error is rc 64.

Known limits: clone does not check whether another run of the same project is armed or parked.
`arm` does not either; that check is in the skill's preflight. Apply it before you unpark a clone.
`--fresh` and `--reset <seed unit>` drop a unit's vars and digests; a unit that came from a source
file gets its vars back on the next read.

`baton status` prints one line per unit with these columns: the unit, its stage, launches so far,
stalls, the park reason, and the session's thread id (`-` when empty). With no argument it lists every
run, puts the run id first on each row and heads the columns (`RUN UNIT STAGE LAUNCHES STALLS PARKED
THREAD`). `baton status <run>` prints that run's rows without the run id or the header.

## Seats

A stage with a `role` (a crew role name, such as `implementer` or `verifier`) launches on the
agent the run's seat table names for that role; it needs no `instance` or `model`. `baton arm`
takes the table as `--seats <file>`, copies it byte for byte to `<run dir>/seats.json` and records
its `seats_sha256` in `run.json`. A recipe that names a role refuses to arm without `--seats`, and
a role the table lacks refuses with `role table has no role "<role>" (stage <stage>)`, writing no
run directory. Extra roles are allowed, so one table can serve several recipes. The engine never
chooses between agents: one agent per role per run, and a seat that fails to launch parks.

The table is one JSON object keyed by role:

```json
{
  "<role>": {
    "agent": "<name>",
    "argv": ["<program>", "<arg>"],
    "brief_delivery": "inject",
    "expected_model": "<model id the seat must show>",
    "effort": "<effort>",
    "env": {},
    "review": "<review command, no PR placeholder>"
  }
}
```

- `agent`, `expected_model`, `effort`: non-empty strings. A message may use `{agent.name}`.
- `argv`: a non-empty array of strings, exec'd with no shell, so its first word is a program on
  the Orca terminal's `PATH`, never a shell function or alias.
- `brief_delivery`: `"inject"` (the message is the last argument, at most 131071 bytes) or
  `"file"` (the message goes to a file and the last argument names it).
- `env`: keys the agent itself needs; the stage's env is merged over it and wins on a clash.
  `BATON_ROLE` and `BATON_ROLE_TABLE` are set by baton and refused here, as are the keys a recipe
  may not set.
- `review` (optional): the reviewer's command, rendered by `{agent.review}`; the stage appends the
  PR.

The skill writes this file from crew's two files after the operator's yes; without crew, write it
by hand.

## Driver

A recipe may carry one top-level `driver` stage (`kind: "driver"`). It takes the launch fields
(with `stall_minutes` as its time limit, default 10) plus `state_file`,
`result_file` and `ledger` (paths rendered with the unit's scope), `clearing` (a non-empty list of
names the driver may report having cleared) and `resume_to` (park stage to the stages a resume may
enter). Its message may use `{driver.stage}`, `{driver.reason}` and `{driver.launch}` (the launch's
number, `<n>` of its nonce `<run>/<unit>/driver/<n>`). `state_file` and `result_file` must contain
`{run.dir}` or `{run.id}` and `{unit.id}`, `result_file` must contain `{driver.launch}`, and the two
must differ, so a result is read only for the launch that wrote it; both may use `{driver.launch}`, the ledger (which may be shared) may not. `session`-only fields
(`outcomes`, `handoff`, `slots`, `stop_file`, `before`, `after_launch`, `watch` and the like) are
refused, and a recipe with a driver cannot name a stage `driver`.

With a driver, a park no longer sends its notice. Step 7 of the tick writes the unit's state file
(the run, the units, this park, the events since the stage entry) and launches one driver session
for it (`driver` event). The driver takes no slot and has its own claim. When it ends, baton reads
the result file rendered for that launch once (a valid one is then removed; a refused one is kept):

- `{"result":"resume","to"?:..,"cleared":..,"ledger":{..}}`: the unit is unparked in place, or into
  `to` (allowed by `resume_to` for the park's stage); `cleared` must be in `clearing`
  (`driver resume`). A unit that parks again with the same stage and reason after a driver resumed it
  goes straight to the operator.
- `{"result":"escalate","action":..,"ledger":{..}}`: the one park notice, `baton <run>/<unit> parked
  in <stage>: <reason> — <action>`, with the suffixes the park's own notice would carry: a merge-stage
  park's PR, a failed hook, the `thread gone` note (see State and config, Orca host) (`driver escalate`).
- `{"result":"stop","reason":..,"ledger":{..}}`: the run parks, `driver stop: <reason>` (`driver stop`).

`ledger` is `{q, a, why, rejected}`, all non-empty; baton appends it as one line to the recipe's
ledger file. A missing, unreadable or refused result (no file, not JSON, an unknown result, an empty
`action` or `reason`, a `cleared` or `to` not allowed, a bad ledger) or a driver that fails to launch
is an escalate whose action names the cause. A driver past its time limit is interrupted; the
`driver dropped` event names that cause, and with no result file the action reads `driver gave no
valid result (no result file)`. `unpark`
and `disarm` drop a live driver and release its claim. Without a `driver` stage every park sends its
notice, as before.

A run that finishes sends one silent summary line: units, merged PRs, parks and how they were
settled, drivers, wall time and the ledger path.

The example recipe's driver (`briefs/driver.md`) settles two parks only: a red `land` whose failing
checks are all outside the item's changed files (re-run once), and a `correct` park at the dispatch
cap with a used-up `correction.txt`. A `user:` walk, a change on `main`, a merge or any doubt goes
to the operator.

## State and config

State lives in `${BATON_STATE_DIR:-~/.local/state/baton}`: `runs/<id>/run.json` and
`events.jsonl`, `claims/` (one env file per launch directory, plus `lookup.log`), `launch/`
(per-launch worktrees), `notify.log`, and a `lock`.

`run.json` is baton's own state; every command and the tick refuse one whose top-level shape baton
never writes: not a JSON object, an `id` other than the run's directory name, a `status` other than
`armed`, `parked`, `disarmed` or `done`, or `units` that is not an object of objects each keyed by
its own `id` (an array of units, say). The error names the run and the field, for example
`run r1: run.json: units is not an object`; the file is left as it is. Copy a run directory only
with its `id` changed to match, and never turn `units` into an array (`jq '.units |= map(..)'`
does).

Config is the optional `${BATON_CONFIG:-$HOME/.config/baton/config.json}`; every key is optional:

- `host`: `"orca"` (the default and only value); `orca.cli` and `orca.launcher` (see Orca host).
- `notify`: an argv run with no shell for each notice (the orchestrator's:
  `["baton", "notify-orchestrator", "{key}", "{message}"]`), `{message}` replaced by the notice text
  and `{key}` by the notice's one-line key (a park's is `<run>/<unit>/park/<at>`), bounded at
  30 s; its failure never fails a tick. Each notice is sent once per key and is always appended
  to `<state>/notify.log`, which is the only sink when `notify` is unset.
- `fallback_notify`: an optional argv, rendered like `notify`, that `notify-orchestrator` runs when a
  notice cannot reach the orchestrator (a host-wide key, no pointer, a stale identity, a failed
  send). It is a plain notifier such as `notify-send`; baton ships no other sink.
- `slots`: per-slot caps on concurrent sessions across all runs (positive integers), over the
  recipe's `slots`, over the defaults `{"session": 2, "build": 1}`.

The `park` event in `events.jsonl` is `{kind, unit, stage, reason}` plus `thread` (the seat's
thread id, when the unit had a session); on a `stop` park, `stop_file` (the stage's stop file,
rendered: the path only, never its text, which a seat wrote); and
on `before failed`, `after_launch failed` and `run failed`, `hook` (the failed hook's 1-based place
in its list) and `argv` (its rendered argv). Those three parks' notices end with
` — hook <n> (<program>)`, the argv's first word without its directory, after the PR a merge-stage
park names: a notice leaves the host, so the rendered arguments stay in the event; an escalated driver notice carries the same suffixes. The driver adds the events
`driver`, `driver resume`, `driver escalate`, `driver stop` and `driver dropped`. A relaunch that
read a result already in place, with no seat, logs `relaunch skipped`
(`unit`, `stage`, `to`, `outcome`: the matched outcome's 1-based place); `baton report` counts them.
The event comes before the outcome's hooks run, so a move or a park (a failed hook, a `to: park`
outcome, a notice that will not render) follows it.

```json
{
  "notify": ["baton", "notify-orchestrator", "{key}", "{message}"],
  "fallback_notify": ["notify-send", "baton", "{message}"],
  "slots": { "session": 3 }
}
```

## The merge stage

A `merge` stage reads one PR (`pr`, an argv that prints its URL), waits for it, and merges it with
`gh pr merge --merge --match-head-commit <the head it merges>`. `base` and `repo` name the branch it
must target and the checkout it fast-forwards; `ordered` merges a group's units in order; `checks`
is `green` (the default) or `none-required`; `run_after` hooks run once it has landed. `outcomes`
route `merged`, `red` and `conflict`.

`expect_head` (optional) is an argv, rendered like `pr`, that prints the head the recipe means to
merge: exactly 40 lowercase hex characters and a newline. A PR whose head differs goes to
`outcomes.moved`, which is then required, checked after the base and before the checks, and the merge
is pinned to that head. An empty or malformed output parks the unit `expect head`, and an argv that
fails three ticks running does too. It only adds a stop: `expect_head` does not itself require
green checks (the stage's `checks` policy still decides), and a stage without `expect_head` is
unchanged.

## Example: an ossify spine

`examples/ossify-spine/` is a recipe that runs one planned ossify spine in Orca terminals: the detached
run-spine lane queues each round's work items, an implementer per item, gap re-entry, a `verify`
seat that writes the item's verdict file, close on that verdict (`--verdict`) and correction (back
to `verify`), a review loop on each item PR (`item_review`, `item_wait`, `item_moved`, `item_fix`: up to three
reviews, then a stop), ordered merges onto the spine branch that merge only the reviewed head, the
spine PR's review rounds (up to three reviews, then a stop), and the spine close. Every session stage
and `driver` names a crew role, so the arm needs `--seats` with a row for each of `spine session`, `implementer`, `verifier`,
`close session`, `reviewer` (with `review`), `item reviewer` (with `review`), `work-PR session` and
`driver` (see Seats). The item reviewer is its own role so the item PRs can go to a different
agent than the spine PR's `reviewer`. The briefs it names are prose; `common.md` is read first by
every seat.

The example needs at least one check that runs on its item PRs (into the spine branch) and its spine
PR: a workflow limited to `branches: [main]` runs on no item PR. A PR with no checks reads
as `none`, which is neither green nor red, so its unit waits in `item_wait`, `spine_wait` or `land`
with no park and no notice.

Copy the example outside the plugin cache first, and pass that copy's `briefs` path: a plugin
update moves the cache, and a run armed on the old path would lose its briefs.

    mkdir -p ~/baton-recipes
    cp -r <plugin root>/examples/ossify-spine ~/baton-recipes/ossify-spine
    baton arm ~/baton-recipes/ossify-spine/recipe.json --run r0-s6 \
      --param spine=r0.s6 \
      --param spine_branch=<output of: oss branch_name <spine> <slug>> \
      --param spine_dir=<absolute AI-workspace spine directory> \
      --param ai_root=<AI workspace root> \
      --param ai_project=<Orca repo display name of the AI workspace> \
      --param repo=<canonical root> \
      --param project=<Orca repo display name of the canonical> \
      --param state_file=<output of: oss state_path, run in the AI workspace root> \
      --param oss=<absolute path of <ossify plugin root>/bin/oss> \
      --param briefs=$HOME/baton-recipes/ossify-spine/briefs \
      --seats $HOME/baton-recipes/seats/r0-s6.json

Each unit's files live in `<state>/runs/<run>/out/<unit>/`. Operator runbook:

- **A stop parks the unit.** Read its `stop` file, write the ruling into the work item handoff's
  `## Clarifications` (or into the file the stop names; a close, spine-open or spine-finish stop
  takes `operator.md`, as the ruling bullet below says), delete the `stop` file, then
  `baton unpark <run> <unit>`. If the stop file is still there, `unpark` renames it to
  `<path>.consumed-<iso>`, so it does not park the unit again. To make a seat apply a ruling, unpark
  `--to <the same stage>`: a plain unpark reads the stage's outcomes first, so if the seat had already
  written its result, the unit takes it and moves on with the ruling unapplied (a close,
  spine-open, `item_fix`, `spine_work` or spine-finish stage's hook also archives `operator.md`).
- **A round barrier is a stop.** A spine planned one round at a time halts the lane at the next
  round (`no spec for <work item>`), and the lane's stop file starts `round barrier:`. Plan the round
  (plan-spine for the spine), then `baton unpark <run> lane`. An unpark before the specs exist stops
  again. The brief writes that wording; baton parses no stop text, and a notifier shows the file.
- **After a gap stop**, send the item back to its implementer: `baton unpark <run> <wi> --to implement`.
- **A ruling for a close, spine-open or spine-finish stop**: write the whole current ruling to
  `out/<unit>/operator.md` (`<unit>` is the work item for a close, `lane` for spine-open, `spine-pr`
  for spine-finish), replacing any file already there: the file holds one ruling, and a seat records
  a ruling when it applies it. Then `baton unpark <run> <unit>` (or `--to <the same stage>` when
  its result may already be written; see the stop bullet); the stage's end archives it as
  `operator-<n>.md`. Before `baton unpark <run> <unit> --to` any stage other than the one the ruling
  is for (for example `implement`, `regap`, `verify`, `correct`, `spine_review` or `item_review`,
  which name no Ruling file), move any `operator.md` aside as the next free `operator-<n>.md`: `--to`
  runs no outcome hook, and the next seat that reads the file (close, spine-open, `item_fix`,
  `spine_work` or spine-finish) would apply it. An implement, regap, verify or correct stop takes its
  ruling in the handoff's `## Clarifications`; a lane round barrier is ruled by planning the round.
- **The item review stop.** Each item PR gets at most three reviews (`item_review`, then `item_wait`
  reads the verdict and the checks; a head that moved after a pass goes to `item_moved`, which sends
  it to review until `review-2.md` exists, then parks). A block or red checks after review 1 or 2
  sends the item to `item_fix`, one `working-a-pr` round that fixes the blocking findings and pushes
  once, then back to review. A block, or red checks, once `out/<wi>/review-2.md` exists (review 3 has
  run) parks the unit in `item_wait` with reason `outcome`, and baton notifies the orchestrator. Rule
  it one of two ways. To fix more: write the ruling to `out/<wi>/operator.md` (replacing any file
  there), then `baton unpark <run> <wi> --to item_fix`; `item_fix` applies it first and its end
  archives it as `operator-<n>.md`. To accept the findings as known limits:
  `baton unpark <run> <wi> --to land`, which merges the head of the last review and nothing newer (a
  head pushed since is an `item_moved` park, below; `--to item_review` skips it and runs one more
  review). A later block parks again at once, because the review files keep counting. Each review is
  kept as `out/<wi>/review-<n>.md`; `review.md` is the latest and `review-prev.md` the one before.
  A review file whose line 1 is not a verdict or whose line 2 is not a `head:` is kept as
  `review-bad-<n>.md` and counts for nothing.
- **The spine review stop.** The spine PR gets at most three counted reviews, as an item PR does;
  stale reviews are not counted, so up to three more `spine_review` launches can run before the
  fourth stale pass parks. `spine_work`'s round end copies the review to `review-prev.md` and keeps
  it as `out/spine-pr/review-<n>.md`. A block, or red checks, once `review-2.md` exists (review 3
  has run) parks `spine-pr` in `spine_wait` with reason `outcome`, and baton notifies the
  orchestrator; after review 1 or 2 the PR goes to `spine_work` as before. A pass of a head that is
  not the PR's current head is stale: `spine_wait` copies it to `review-prev.md`, keeps it as
  `review-stale-<n>.md`, and sends the PR to `spine_review` again. A stale review takes no review
  number, so it does not count toward the three. A fourth stale pass (once `review-stale-3.md`
  exists) parks `spine-pr` in `spine_wait` with reason `outcome`, because the reviewer keeps reading
  an old head: find out why, copy `review.md` to `review-prev.md`, move it aside as the next free
  `review-stale-<n>.md`, then `--to spine_review`. `spine_ack` is entered only when `review.md`'s
  line 2 equals `head: <the PR's head>` at that moment; baton does not watch the head while
  `spine_ack` waits, and the merge pin is the merge holder's `--match-head-commit` (the ack notice
  names the head). `spine_review` accepts a review only with a 40-hex `head:` on line 2. With a
  passing review, a PR head that cannot be read as 40 hex parks `spine-pr` with `exit0 error`, never
  a match. Rule the stop: to fix more, write the ruling to `out/spine-pr/operator.md` (replacing any
  file there), then `baton unpark <run> spine-pr --to spine_work` (a later block parks at once,
  because the review files keep counting). To accept the findings, the merge holder merges the PR,
  then a plain `baton unpark <run> spine-pr` reads the merge. A round that would push no commit and
  change no PR body is a `spine_work` stop, not a round: the stop file names what is left and who
  must act (a red check on newer `main` commits needs `main` brought in, which moves the spine tip,
  so only the merge holder may). After the merge holder acts, move `review.md` aside as the conflict
  bullet below says, then `--to spine_review`.
- **An `item_ready` park** (the recorded `pr_url` is not a PR URL): fix the work item's `pr_url` in
  the ossify state and in the run's `queue/<wi>.json`, which close copied it to, then
  `baton unpark <run> <wi> --to item_ready`.
- **An `item_moved` park** (the PR's head moved after its last review and `out/<wi>/review-2.md`
  exists): nothing was merged. `baton unpark <run> <wi> --to item_review` runs one more review of the
  new head; `--to land` parks again at once while the head still differs from the reviewed one. To
  finish by hand, merge the PR yourself, then `--to land` ends the unit.
- **`item_wait` parks** on `closed` and `conflict` as well (reason `outcome`): reopen or resolve the
  conflict on the item branch (merge the base in; never rebase or force-push), push, then
  `baton unpark <run> <wi> --to item_review` so the new head is reviewed.
- **A reversal before the spine merges**: write it to `out/spine-pr/operator.md` (the same file and
  archive; replace any file there), then
  `baton unpark <run> spine-pr --to spine_work`; that round does it first, and the round's end
  archives the file as `out/spine-pr/operator-<n>.md` (the work-PR seat also writes the ruling into
  the PR body, which the reviewer reads). The previous round's review stays as
  `out/spine-pr/review-prev.md`, which the next review is told as `previous:`.
- **A spine PR conflict parks `spine-pr`** in `spine_wait`. Resolve it on the spine branch in the
  canonical root (merge the base in; never rebase or force-push), push, copy
  `out/spine-pr/review.md` to `review-prev.md` and move it aside as the next free `review-<n>.md`, then
  `baton unpark <run> spine-pr --to spine_review`.
- **The spine PR ack.** On the "passed review … merge it" notice, read the PR's needs-you list, then
  merge it as the project's governance grants (otherwise the operator merges), only the head the
  notice names (`gh pr merge <PR URL> --match-head-commit <head>`); if the PR head has moved, copy
  `out/spine-pr/review.md` to `review-prev.md`, move it aside as the next free `review-stale-<n>.md`
  and `baton unpark <run> spine-pr --to spine_review`. baton sees the merge and runs the second
  spine close. The `spine_finish` seat commits the review-ledger and tech-debt lines of every merged
  PR of the spine (merge-bar `working-a-pr` §5) with the close record, since no seat runs §5 after a
  baton merge. It writes the harvest candidates to `out/spine-pr/harvest.md` and, where there is a
  close PR, under `## Harvest candidates` in its body, and accepts and applies none: the operator
  accepts, and the orchestrator applies the accepted set (ossify harvest §7) on the close PR's
  branch before the merge, or as a follow-up commit where the workspace pushes direct.
- **A `spine_close_wait` park** (a workspace that lands records only through PRs; the finish seat
  wrote the close PR's URL to `out/spine-pr/close-pr.txt`): the PR merged but `origin/main` does not
  read the spine closed, it closed without a merge, it conflicts, or `close-pr.txt` holds no PR URL.
  Fix the PR or the record, then `baton unpark <run> spine-pr`; for a PR closed without a merge,
  reopen the PR; or replace `out/spine-pr/close-pr.txt` with a valid close-PR URL, then unpark; or
  remove it and rerun the close with `baton unpark <run> spine-pr --to spine_finish` (a plain
  unpark with the file gone parks again as `pr url`). `spine_finish` itself ends only when
  the state file at `origin/main` reads the spine closed (a fetch in the AI root; no `origin`
  remote, or a failed fetch, parks `exit0 error`; the fetch runs with `GIT_TERMINAL_PROMPT=0`, so git's
  own credential prompt fails instead of hanging; an ssh remote's prompt is not covered).
- **A `run failed` park on a session stage** (a round-end hook failed): fix the cause, then a plain
  `baton unpark` reads the stage's outcomes first: if the outcome still reads true, its hooks run again
  from the first and the unit moves on with no seat; if an earlier hook removed the file it reads
  (in a run armed before 0.18.1, `correct`'s first hook removes `corrected`: archive `correction.txt`
  by hand, then `--to verify`), the seat relaunches and reruns the round, so run the remaining steps
  by hand, then `baton unpark <run> <unit> --to <next stage>`.
- **`--to spine_work` is refused while `spine-pr` has a live session** (a review is running): wait
  for the review to end, then unpark.
- **A `land` park** names its reason. `run failed`: the canonical root is not on the spine branch
  (or the fast-forward failed); check the spine branch out there, then `baton unpark <run> <wi>`.
  `outcome`: the item PR's checks are red or it conflicts; fix it on the item branch, then unpark.
  `expect head`: the `head:` line (line 2) of `out/<wi>/review.md` is missing or is not 40 hex, or
  its read failed three times; nothing was merged; rerun the review with
  `baton unpark <run> <wi> --to item_review`.
  `pr closed`: reopen the PR and unpark, or finish the item by hand. `not landed`: the PR merged
  but its head is not on the spine branch (a squash or rebase); the recipe cannot record that
  landing, so finish the item by hand.
- **A run-level park** (`invalid record …`): fix or remove the record file, then `baton unpark <run>`.
- **A seat stopped mid-work leaves its worktree dirty.** work-item's Gate 3 refuses a dirty
  worktree on a plain `unpark` of `implement`, and a correction's packet no longer matches the
  staged tree: clean the worktree, or finish the work by hand, before you unpark.
- **A cheap build**: implementers and corrections hold the `build` slot (1 by default), so they run
  one at a time. Raise `slots.build` in the config to run more at once.

## Known limits

- A stage whose `cwd` is a project root starts by default in a detached per-launch worktree, not
  at the root, so its brief must name the paths it works in, and writes to tracked files there
  are lost on `release`. A stage that needs the real checkout sets `launch_dir: "root"`.
- Claude Code adds a plugin-registry row for a launch directory. At startup it copies each plugin
  that a tracked `.claude/settings.json` enables into `~/.claude/plugins/installed_plugins.json`
  as a `project`-scope row whose `projectPath` is the launch directory. A per-launch worktree
  (the default for the `driver` stage) of a repo with such a file can leave
  one row per launch, and `release` removing the directory does not remove it. baton cannot
  prevent this and does not edit that file. baton does not use the row, and the skill takes the row whose
  `projectPath` is the AI workspace root. A stage that sets `launch_dir: "root"` reuses the root's
  row but loses the isolation above.
- While a `launch_dir: "root"` session runs, a hand-started thread at that root reads its claim.
  A hand-started thread bound to a baton launch directory or a live item worktree also reads that
  claim.
- A coordinator seat still has bash (`crontab`, background `sleep`); its brief governs.
- A seat that clears in place without a handoff line is seen only through the quiet window.
- `findByNonce` depends on Orca keeping the terminal title.
- On Orca: see the known limits under Orca host.
- The claim keys keep their T3-era names, `OMP_T3_SEAT` and `OMP_T3_VIA`: renaming them would break
  recipes already staged. A staged recipe that still sets the retired `OMP_T3_DROP_T3_MCP` passes
  it to the seat as a plain variable that nothing reads.
- A driver's judgment is prose: a driver that picks the wrong result is caught only by the closed
  checks on its result file and by the operator reading the ledger.
- `baton unpark` during a live driver removes its claim but does not interrupt the driver thread or
  release its launch worktree; its later result is ignored.
- A live driver is not watched while the run is parked; it is handled after the run re-arms.
- A close resumed after its commit halts on a stale verdict: the verdict was taken on the staged
  tree.
- Untracked files that a test run leaves in the item worktree between `verify` and `close` change
  the worktree fingerprint, so close halts on a stale verdict. It fails closed.
- The driver guard key is `<stage>/<reason>`. A park reason that embeds a varying error message never
  repeats, so only `driver.md`'s prose stops a second driver for the same underlying failure.
