# Completion

One copy of how a run learns a seat finished. The layer's `Completion signal` step says how its
own terminal states are typed; every rule below holds for any layer, so it is stated here once
and the other files point here rather than restating it. The layer's steps are named, never
typed: "the layer's Wait", "the layer's Read", "the layer's Send", "the layer's Health".

## The report file is the contract

A seat's result is its report file, at the `REPORT_PATH=` its brief names; a typed terminal
state carries no body, so the file is the contract and the state is only the doorbell. Every
file the run keeps is placed outside every seat's worktree, so removing a worktree never takes
one. Before dispatch, clear or move an acknowledged report; then note what the doorbell compares — the
file's hash (`git hash-object <path>`), empty if absent, and the file's identity (inode with mtime)
— writing an existing `REPORT_PATH` file's current generation `{hash, identity}` as the
new attempt's `locator.seen` and leaving `seen` absent only when the file is absent. The worker
writes everything it says to the orchestrator there (a plan, a question, an
escalation, a late finding, its report) and replaces the file whole (`briefs.md`).

## The doorbell

For a seat the layer detects, and that is not a coordinator, the wake is the layer's typed wait
(`lifecycle.md` step 5), over the states the layer's `Wait` step lists:

- `idle` or `done`, and the file is new (absent at dispatch, or a different hash or
  identity): read it. A plan, a question or a late finding is answered with the seat's next
  message and one fresh bounded wait; an escalation goes to the operator.
- `idle` or `done`, and nothing new: the false wake below, one read (the layer's Read).
- `blocked`: a dialog, handled as `lifecycle.md` step 5 says. A timeout: the checkpoint below.

**An undetected seat's doorbell is the report file itself**, and so is a coordinator's: a
seat running work of its own in the background (a spine or work-PR session's waits, a lane
driver's subagents) reaches a settled typed state before its report exists — a typed wait
wakes too soon. The doorbell is one bounded background wait that returns when `REPORT_PATH`'s
hash **or** the identity noted beside it differs from the one last noted, or at its timeout —
not the loop of waits `lifecycle.md` forbids. Both are compared, not merely recorded, so a
byte-identical replacement (a retained verifier repeating the same failure) — same hash, new
inode — still wakes it: the identity noted at dispatch above.
A changed file is read as above; a timeout with no new
file is the checkpoint below, one read (the layer's Read), and a dialog it finds is reported
with the rest of the state.

A **detected coordinator** adds one wait the non-coordinator path does not need: a dialog
takes it to `blocked` and it writes no report while the dialog stands, so the doorbell above
would sleep to its timeout. Add the layer's Wait for `blocked` alone beside it; that `blocked`
wake is the dialog above, handled as any `blocked` wake is, and it ends the doorbell.
The doorbell's return — a new report or its timeout — ends the companion, so a dispatch leaves
at most one armed wait. Stop a wait, companion or heartbeat by its job id: OMP `write proc://<job id>/kill`, Claude Code
`TaskStop`, a shell process this session started by its exact PID or job id; never a process listing (`ps`, `pgrep`,
`pidof`, `/proc`) fed to `kill`. The companion's own timeout, while the doorbell is still armed, is no
checkpoint: it lapses silently, with no read and no report, and the doorbell (and the
heartbeat, where armed) covers the rest of the dispatch. An answered dialog re-arms the pair: the doorbell and its companion again, not one wait.

**The two dead ends.** *A timeout is a checkpoint* (but a doorbell companion's, which lapses;
above): one read (the layer's Read) — the seat's observed state, stopped, at a dialog or still
at work, reported to the operator (a coordinator: to the top, in its report file), and a
further wait is the operator's decision, never the orchestrator's own re-entry. *A false wake*
— its own read showing the seat still at work (the backgrounded-shell case) — is not a
timeout: the doorbell becomes the report file for the rest of that dispatch,
never a second settled-state wait (the coordinator's `blocked` companion still applies).

**Every wait runs in the background:** one shell call the host wakes the session on when it
exits (Claude Code: the Bash tool's `run_in_background`), so it spends no tokens and its
timeout can be hours. It still returns once and re-enters nothing; a round's N items are N
such waits, one per pane. A host with no background call waits in the foreground, its bound
inside that call's cap (Claude Code: 120000 ms default, 600000 max) and cannot arm the
heartbeat; a cut-off wait is neither wake nor timeout. A host with no background timer keeps
the wait/ping fallback, never a rolling foreground loop.

## The ping and the heartbeat

**The tag.** Every message crew sends up to a parent or top session — a `PING:` line's
send, a `MOLT:` line's send, a note between tops or from a rotation successor — starts
with its tag as the first text: `[crew <kind> <role>]`. `<kind>` is `report`, `molt` or
`message`; `<role>` is the sending seat's role word — `implementer`, `verifier`,
`reviewer`, `coordinator`, `orchestrator` — lowercase, letters and hyphens only. Each
brief template's `PING:` and `MOLT:` lines carry their own role word inside the tag; the
tag is what tells a receiving session a seat's message apart from the operator's typing.

**Sends that stay untagged.** What crew sends down to a worker — a brief, a plan-gate
reply, a correction request, a `/context` — is delivered verbatim (past one line, by file: the layer's Send), no preamble, and
carries no tag (`briefs.md`); the worker's re-ping after a correction is sent up, and
carries the tag. A local slash command is untagged too — the rotation resume
(`/ossify:handoff-resume <path>` to a Claude Code top, `skill://handoff-resume <path>`
to an OMP top; `lifecycle.md`, "The resume"), and `/context` or `/clear` — because the
tag is a prefix, and a prefix would break any slash command.

The worker's ping is its brief's line (`briefs.md`): after every report rename, one send, no
wait, no retry, and only when `NOTIFY_RUN` is not `none` — it reads `run.orchestrator` from
that file at that moment and sends through the layer's Send only when `run.orchestrator.machine`
equals `NOTIFY_MACHINE`: pane ids are server-scoped. One single-quoted literal argument (a
single quote in it is written `'\''`), `<path>` the file actually renamed over. Every other
dispatch keeps the report-file wait and this session's heartbeat as the whole of its push
bound. A skipped or failed read or send is never an answer: after a plan or a question the worker waits at that gate. A brief older than 0.3.1 still sends the
legacy `REPORT READY: <task id> <kind> <path>` form; read either it or the tagged
`[crew report <role>] <task id> <kind> <path>` as this ping.

A ping is one way a report announces itself, beside a completion wake and a heartbeat tick,
and the generation check governs all three: a new generation is read, noted — the pair the
dispatch note defines — and recorded as the attempt's `locator.seen`, acted on once by kind, and retires that dispatch's wait and companion; an
already-consumed one is not read, not acted on, retires nothing — a stale same-path ping never
cancels the current phase's wait. A live dialog and the tick's health check are reports of
neither kind and still run. A ping whose path is not this dispatch's `REPORT_PATH` is not
delivered — nothing is opened, no other dispatch is reached — and gets `briefs.md`'s correction
request; an unmatched ping is reported.

**The heartbeat.** One bounded background timer of about 15 minutes per session holding any
live dispatch — a typed-wait seat included, not only a report-file wait — re-armed per tick
(the layer's own Wait has no scheduler), never a completion wait and never re-entering,
restarting or extending one. Per tick, per live dispatch: the generation check, then — absent a
new report — one health check, never a second (the layer's Health read; an errored read is
unreadable, not crashed). Working stays silent but for the tick's one line; blocked takes the
dialog procedure above, its own diagnostic read included; idle, done with no new report,
`unknown` or an unreadable seat is surfaced once per dispatch, not per tick, as observed state
and uncertainty — never a failed task, never a retry. **A stall** is the one exception to a
silent `working`: a seat read `working` at two consecutive ticks with no new report generation
takes the next tick's one check as a read (the layer's Read), and a read showing only provider
errors and retries (API errors, request timeouts, rate-limit waits), nothing else advancing, is
a seat failure, not a failed task — named in the tick's line and the handoff. Settle its
dispatch first (stop its report-file wait and companion by job id: OMP `write proc://<id>/kill`, Claude Code `TaskStop`), then launch the fallback the project
file's `## Conditions` names for that seat — in a spine session its SEATS fallback row (`ossify-briefs.md`), never a re-read of the file — as a fresh seat is launched (below), from the
fallback's row, its brief re-sent whole, with `RESUME FROM:` the seat's last report when it
wrote one. A seat a fresh session cannot resume (the cuts the molt paragraph below lists) gets
no fallback; it, and a stall with no fallback named, is reported to the operator once.
`## Conditions` may set another bound. The heartbeat is stopped when the last dispatch settles,
at teardown and at stand-down, where the successor arms a fresh one.

## A child past molt's warnings

A seat marked a molt child (`Seat marking`, the layer's launch step; `roles.md` holds the marking)
is never cleared by molt.
At each of molt's two warnings it sends one ping, its brief's tagged `[crew molt <role>] <pct> <task id>`,
to the pane read from `NOTIFY_RUN` as the brief's PING line says — not a report ping: it
names no path, opens no report and gets no correction request. A brief older than 0.3.1
still sends the legacy `MOLT WARNING` form; read either as this ping. molt appends `warned <n>`, `handoff required`
and `handed-off <path>` to the status file the seat was launched with — molt's own writes,
never the seat's. Record that path per seat at launch: molt reads `MOLT_STATUS_PATH` once, so
no later brief of a retained seat moves it, whatever `REPORT_PATH` that brief names. The
heartbeat, per tick, per live seat, also reads its recorded status file, so a skipped ping
costs at most one tick while a dispatch is live. Before a retained seat's next unit, read its
recorded status file: the heartbeat ends when the last dispatch settles, so an idle seat's
warning may be noted only there. On a `[crew molt <role>]` ping, or the legacy `MOLT WARNING <pct> <task id>` ping from a
brief older than 0.3.1, or a status line not yet noted: note it and send that seat no new unit. It finishes the unit in hand; its next unit (a fix
round, a re-check, the next item) goes to a fresh seat, and the warned seat is released once
that unit's report is read. A `rotate:` or `open:` return is respawned as `lifecycle.md` says,
and the `handed-off` line beside it is that return, not a second one. On a report `handoff:
<path>`, or a last status line `handed-off <path>` whose seat has returned no `rotate:`,
`open:` or `handoff:`, settle the predecessor's dispatch first — a status-only handoff writes
no report generation, so stop its report-file wait and companion by job id (OMP `write proc://<id>/kill`, Claude Code
`TaskStop`) — then launch a fresh seat.
**A fresh seat** — every respawn, after `rotate:` and `open:` included — is launched from the
same row, marked the same, with a fresh `REPORT_PATH` in the same report directory, so its
status file starts empty; it reuses its predecessor's scratch directory (and an ossify
implementer's handoff directory) in its `SEAT_MODS_ALLOW`, since the launch marking runs again
for it; and an implementer's opens as a new tab of its predecessor's worktree workspace, never
a new `worktree create`, so it can write the tree its predecessor left. Its brief is re-sent
whole, plus one line, `RESUME FROM: <handoff path>` — the predecessor's handoff, or for a
warned seat that handed off nothing, its last report. Close the predecessor's pane only after
the new tab exists; a worktree is released only as the layer's Teardown says, once its
branch's work is safe. A spine session that hands off with no `rotate:` was cut mid-round
(ossify issue 133); ossify 1.14.0's run-spine re-enters a started spine, mid-round included,
so respawn it as a `rotate:` is (`ossify-nested-run.md` §4), its `HANDOFF_PATH` that handoff.
Its re-run prints a reconcile read-out and halts before any mutation on what it cannot
reconcile; only that halt goes to the operator. These cuts cannot be resumed by a fresh
session, so for each, relay it to the operator with its handoff path: a work-PR session that
hands off with no `open:`, cut inside a fix round; a close, work-item, lane-driver or doctor
seat that hands off mid-ceremony; and a reviewer that hands off before its report validates,
since a fresh one would run the PR's one review a second time. Without molt none of this
fires, and the ceiling hook's rotation applies.
