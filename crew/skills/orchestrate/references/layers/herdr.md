# herdr — the layer

`herdr --skill` and the `--help` text it points to are the command reference. This file states
only what that guide cannot, how crew composes those commands into a seat; role, retention and
run decisions stay in `roles.md`, `lifecycle.md`, `config.md` and `completion.md`. Where it
overrides the guide's default, it says so. Read each id from the JSON that made it. Every layer
file implements the same named steps; the shared files name them, hold the rules and never carry
a command, and this is the file `references/layers/<layer>.md` resolves to on `layer: herdr`.

## Health

`herdr status` answers whether the server is up; failing, it is a refused run (`SKILL.md` §7).
The heartbeat's per-tick health check reads `herdr agent get <pane>` where herdr holds a
record, else one `herdr pane read <pane>`.

## Identity

A session's own address is its pane: `$HERDR_PANE_ID`, with `$HERDR_WORKSPACE_ID` for the
workspace a rotation later needs. Its agent session is `herdr pane get "$HERDR_PANE_ID"` —
`.result.pane.agent_session.agent` and `.result.pane.agent_session.value` — written as the run
file's `{agent, id}`; with none returned, none is written. `herdr pane get <pane>` also answers
whether a pane still exists, the stand-down read (`lifecycle.md`). This server's machine is its
`hostname -s` (`Machines`).

## Run workspace

`herdr workspace create --cwd <a path that already exists> --label "run: <objective>"
--no-focus` — the first seat's tree, or a neutral path when that seat's worktree is still to
be created (Seat worktree; a nonexistent `--cwd` fails the launch). Its tab and shell pane
(`.result.tab`, `.result.root_pane`) are the first seat's when that path is its tree:
`herdr tab rename <tab> "<seat label>"`, not a second tab beside an empty one; a
seat on another machine needs its own, `--machine <label>` — ids are server-scoped.
`herdr workspace list` shows what a run still holds, and Teardown reads the same list to
confirm what closed.

## Seat worktree

**One tab per further seat.** `herdr tab create --workspace <id> --cwd <the seat's tree> --label
"<seat label>" --no-focus`; its pane is `.result.root_pane`. A seat that needs a new worktree uses
`herdr worktree create` — `--cwd <the source repo> --path <the new tree> --branch <b>
--base <base-branch> --label "<seat label>" --no-focus` — in place of this step, never the workspace
step: it opens **two** workspaces, the worktree's own and the **source repository's** checkout
(`is_linked_worktree: false`). Its `--label` names the worktree's **workspace**, so the seat's tab
needs the `herdr tab rename` the workspace step prescribes. `--cwd` is the lever that retargets
the **source** repo: without it the call resolves its source from the *calling workspace's* repo.
Read every id from the response, `result.root_pane.pane_id` included. Marking:
`Seat marking`, `Seat launch` (`roles.md`).

A seat's tree is whatever `--cwd` names, so a seat may sit in another repository: in the
dual-repo case an orchestrator in the AI workspace places an implementer in the canonical
tree — for a worktree seat, Seat worktree's `--cwd` is what makes that true. `--env` (on
`tab create` and `workspace create`) carries only a seat's own scratch, such as
`OSSIFY_SEAT`; a lane's provider variables are invoked by name through `command:`, never
replayed with `--env` — a replayed environment is the silent-reroute defect.

`--trust-repository` on `herdr worktree` grants herdr's per-request Git trust, not Claude
Code's folder-trust dialog; only for a repository the operator verified, never as a retry.

## Seat launch

No single herdr call creates a seat, starts its command and delivers its brief; a seat is the
sequence `roles.md` names, `<seat label>` being `seat: <role> (<agent>)`. This file states that
sequence's layer half — the pane and its command, the readiness wait, the model read and the
dispatch:

**Seat marking** (`Seat marking`; `roles.md`). It is one `herdr pane run <pane> "export …"`,
whose variables are the launch environment `roles.md`'s launch block states (`worktree create`
takes no `--env`; `--env` carries only a seat's own scratch). The status line `roles.md` reads
is the rendered viewport here: `--source visible` on the model read, even where a `banner`
seat's model read is the default stream; where the seat's row names a `rail:`, that rail's check runs in place of the status line.

**The seat's command.** `herdr pane run <pane> "<command:>"`, verbatim from the entry —
re-running a **launch** command into a pane whose foreground process is already that
agent's TUI delivers its line as a prompt, the mechanism the undetected seat's one-line
pointer relies on, so a stray re-run costs a live seat a turn.
**Readiness**, on whichever of the two paths below the pane takes.

**The model.** `herdr pane read <pane>`, with `--source visible` (the rendered viewport)
when `model_shows: screen`, must show `expected_model:`; one showing
`command not found` — or another model — is a failed launch (`roles.md`).

**Dispatch**, sent as below.

    workspace "run: <objective>"          one per run
      tab "seat: verifier (<agent>)"      one full-size pane
      workspace "seat: implementer (<agent>)" one per worktree a seat needs, named by
                                              Seat worktree's `--label`; its tab is renamed
        tab "seat: implementer (<agent>)" one full-size pane

One tab per seat, one full-size pane per tab: **crew places a seat with `tab create`,
never `pane split`** — panes sharing a tab make a multi-agent screen unreadable — overriding
`herdr --skill`, whose "Start and coordinate an agent" defaults to a sibling split.

The orchestrator is not in that workspace: it stays in the pane the operator launched it
in, and crew does not move it, because a moved pane takes a new id.

## Readiness

herdr answers, live, which path a seat takes: whether `herdr agent list` returns a record for
the pane. That answer, never a config field, is the discriminator — a detection manifest
landing later moves a seat to the typed path with no edit anywhere. Detection after `pane
run`: a record at about a second (0.6 s, still `agent_status: unknown`, no session identity; before it, `agent list` omits the pane and `agent get`/`agent wait` answer `agent_not_found`: ask again for up to five seconds, then take the not-detected path)
and a settled state (`idle`) at about four seconds (3.8–4.0 s). The first ask, once the record
is there, chooses only the **readiness wait** below; made once the model read (`Seat launch`) has shown
`expected_model:` on the pane, a second ask of that list decides the **send's route** and with
it the **completion wait**, so the route that delivered the message is the one that can wake
it. A pane absent to that ask is undetected for the send.

**Detected** (a `claude-*` lane, `pi`): the typed wait below. Detection is not
readiness: a fresh agent's first detected state may be `blocked` on a folder-trust dialog,
which `--dangerously-skip-permissions` does not skip, and it is handled as a `blocked` wake.

**Not detected** (`mcode-*`, which herdr has no detection manifest for):
`herdr pane wait-output <pane> --match '<expected_model:>' --timeout <ms>`, with
`--source visible` when `model_shows: screen`. Every resolved profile carries
`expected_model:`, and `model_shows` says where it appears — so the model string also shows
the TUI is up. Without `--timeout` the wait has no bound. Caveat: it searches existing output
before it polls, so a seat whose own command line contains its model string matches at once —
wait on output the launch command cannot produce, or exclude the echoed command.

## Send

PING_SEND=herdr agent prompt <that pane>

This is the one statement of how the orchestrator sends a seat anything; other files say "send" and mean this. The slot `PING_SEND` a brief's `PING:` and `MOLT:` lines carry is this
file's send, filled by the dispatcher.

- **Detected:** `herdr agent prompt <pane> '<line>'` submits text and Enter as one submission. herdr adds environment such as `HERDR_PANE_ID`, never prompt text. Work takes the turn-start check below. A local slash command (`/context`, `/clear`) settles without a turn and is sent plain, without that `--wait`.
  For `/context`, note the pre-send screen; after the plain send, `herdr pane wait-output <pane>
  --regex '[0-9.]+[kKmM]? */ *[0-9.]+[kKmM]? tokens' --source visible --timeout 5000`. Then read with `herdr pane read <pane> --source visible`
  at most 5 times, with `sleep 1` between reads; accept only a figure that differs from the pre-send screen.
  No changed figure or a wait timeout means figure unavailable, treated as past half: the next item goes to a fresh seat.
- **Undetected:** no `agent` command reaches the pane; they accept only a pane hosting a detected
  agent. Send the by-file line with `herdr pane run <pane> '<line>'` (the line and Enter; only `agent
  prompt` is documented to honour bracketed paste); a seat set to `brief_delivery: inject` is reported to the operator. No turn-start check.
- **By file:** a brief, a correction request or any message past one line is written to
  `<run dir>/scratch/<role>-<n>.brief-<k>` (absolute, this machine, outside every worktree, one file per
  send); the send is `herdr agent prompt <pane> 'Read <path> and follow it.'` (a single quote in the path is written `'\''`), so no free text reaches a shell. A one-line
  nudge stays inline, as `PING:` pins. `inject` prompts the text, for a seat on another machine, whose file would sit on the wrong machine — a known limit.

**The turn-start check.** Acceptance of input is not the start of a turn, as herdr's guide
says of a successful submission; herdr's own check runs inside the send:

    herdr agent prompt <pane> '<line>' --wait --until working --until blocked --timeout <ms>

From a non-working state, `--wait` requires an observed `working` or `blocked` within five
seconds of submission, and `--until working --until blocked` returns at that first
observation, so the call stays a dispatch and the completion wait the one long wait; its
timeout counts from before submission, a few seconds above the five-second gate.

- `agent_prompt_stalled`: no activity within five seconds of submission. `herdr agent get
  <pane>` gives the state. `working`: it started. `blocked`: a `blocked` wake. `idle` or
  `done`: `herdr pane send-keys <pane> enter` submits what sits in the composer (`enter`
  submits; herdr's help names only `esc`). `unknown`: report it to the operator. A `timeout`
  is read the same way (`roles.md`, the never-resend rule).
- `agent_blocked` (nothing was sent) and `blocked` (the turn opened on one) are both a
  `blocked` wake; a cleared `agent_blocked` re-sends the brief with the turn-start check.

## Read

The layer's read forms: `herdr pane read <pane>` (the rendered screen, `--source visible` when
the profile says `model_shows: screen`), `herdr pane wait-output <pane> --match '<pattern>'
--timeout <ms>` (output), or `--regex '<pattern>' --source visible --timeout <ms>` for `/context`, and the detection asks `Readiness` states. Each use states its flags
where it is used — `Readiness` for both wait paths, `Seat launch` for the model read,
`Completion signal` for the health check. No read is licensed
by the layer: the shared files say which reads a turn may spend.

## Wait

Every `herdr agent wait` crew issues names the same three settled states, except one
companion wait a detected coordinator needs, which selects `blocked` alone (`completion.md`):

    herdr agent wait <pane> --until done --until idle --until blocked --timeout <ms>

The set is stated here; `roles.md` and `lifecycle.md` name this step rather than repeating the command.
It is herdr's default set, written out rather than inherited; `--until` narrows: without
`blocked`, a wait sleeps through a dialog to its timeout, and only `idle`, `done` and
`blocked` are proved settled — `done` fires for a Claude Code pane as `idle` does.
`--timeout` bounds it; a timeout is the checkpoint `completion.md` states (a doorbell
companion's excepted: it lapses).

**A `blocked` wake** means herdr recognised an approval or question dialog. A blocked
agent rejects `herdr agent prompt` with `agent_blocked`, sending nothing. The dialog is read
with `herdr pane read <pane>`, the answer sent with `herdr agent send-keys <pane> <keys>`;
`lifecycle.md` step 5 owns when a `blocked` wake is answered that way. A question written to
the report file is not a dialog; it rings that doorbell (`completion.md`).

## Completion signal

herdr types a seat's terminal state, and the three settled states are the ones `Wait` lists;
`done` fires for a Claude Code pane as `idle` does. The doorbell and what it rings are
`completion.md`'s. The health read is `herdr agent get <pane>` where herdr holds a record, else
one `herdr pane read <pane>`; a seat herdr does not detect is read through its report file
(`completion.md`).

## Teardown

A seat in a tab of the run's workspace is released with `herdr pane close <pane>`; a worktree
seat is not: its workspace holds only its tab and pane, closing that pane may take the workspace
with it or be refused, and its id is the only selector of `herdr worktree remove --workspace
<id>`. That remove releases only the worktree's own workspace: `herdr workspace list` still
shows the **source repository's** checkout Seat worktree's `worktree create` opened — in the
dual-repo case the canonical checkout. The run's own workspace is `herdr workspace close <id>`;
a failed call is JSON on stderr, exit 1, and a last pane's close may take its tab and workspace
too. Confirm what closed with `herdr workspace list`. The
order, and what a refused remove does, are `roles.md`'s Teardown order.

## Machines

A `machine` is a remote server's `herdr machine list` label; this server's machine is its `hostname -s`.
Every command for a seat on that machine carries `herdr --machine <label>`, with its ids
discovered there: ids and agent names are scoped to one server, and `--current` reaches no
remote pane. The operator names a seat's machine in the machine file's `host:`, with one of
these labels; this server's own name needs no `--machine`. A seat on another machine
writes its report file there, and this layer names no route that reads it from here: that
read is measured on the Orca layer only (`layers/orca.md`, Machines) — a known limit.

## Host: OMP

An OMP top (`omp-seat orchestrator --via omp-glm`, omp-roles 0.4.0) runs this skill as written, with these
substitutions; so does an OMP coordinator for the seats it drives. Background call: omp's bash async job (`async.enabled`, on by default); pass `timeout: 0` on every one
(omp's default deadline is 300 s and a nonzero value is clamped; 0 disables it), so herdr's `--timeout` bounds the wait; never pass `name:`, which puts omp's bash in service mode and refuses async and timeout.
Its result returns to the session as a turn, so every readiness and completion wait, and the heartbeat, runs as one.
