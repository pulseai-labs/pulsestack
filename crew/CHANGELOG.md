# Changelog

All notable changes to the `crew` plugin.

## 0.11.4

**The ceiling accepts the manifest's numbers; wait and resume prose agrees with its contracts.** Closes #616, #587, #856 and #515.

- **Numeric ceiling (#616):** jq decides the min-1 setting and compares it without flooring; 100000.5 fires at 100001 and exponent forms are compared, not dropped. Failed setting or comparison jq yields an unavailable notice, never a default comparison or a below-ceiling verdict. Normal notices quote the number in force; an unavailable notice instead reports an unchecked setting when jq is missing or normalization yielded no value.
- **Doorbell follow-ons (#587):** dialog answers re-arm the coordinator's pair, acknowledged reports are cleared or moved before dispatch, false wakes forbid a second settled-state wait rather than the dialog companion, and file identity is inode with mtime. The already-shipped hash-or-identity wake and silent companion timeout stay unchanged; the inaccurate test-count comment is removed.
- **Resume and descriptions (#856):** an answered transcript question is applied, not re-asked; ping headers cover skipped and failed sends and hold workers at their gates; step references and the direct work-PR merge actor are explicit. Public descriptions name the run's merge word (`standing` by default), the operator gate, and the one-way/no-Door and operator-executor exceptions; the reviewer command includes its level, and the retired-command pin's label names only what it checks. The PING counter is already an anchored line count, not a copy of the literal-occurrence loop.
- **Context probe (#515):** after a plain send each layer reads the rendered screen at most five times, with `sleep 1` between reads; herdr first waits up to 5000 ms. Only a figure different from the pre-send screen is accepted; an unavailable figure sends the next item to a fresh seat. Shared files route to the layer's probe rather than restating its reads.
- **Known limits:** the existing `standing` merge default is unchanged and requires no proof of a project standing order. An unchanged figure is not freshness proof; if no changed figure is established by the bounded probe, it is unavailable. No jq means no setting validation or context comparison. The figure regex matches Claude Code's `/context` render; a `can: slash-commands` seat on another CLI with a different render fails the probe and rotates at every boundary.

## 0.11.3

**Text only (#1099).** `completion.md` (the doorbell paragraph, the stall rule, the handoff rule) and `lifecycle.md`'s stand-down name how a seat stops its own wait, companion or heartbeat: OMP `write proc://<job id>/kill`, Claude Code `TaskStop`, a shell process this session started by its exact PID or job id; never a process listing (`ps`, `pgrep`, `pidof`, `/proc`) fed to `kill`. `SKILL.md` and every coordinator brief's NEVER line carry the same refusal. No code.

## 0.11.2

The marketplace is renamed `pulsestack`; the OMP bin-path module it ships (`omp/bin-path.ts`, VERSION 2) reads installs under the new marketplace name `pulsestack` and, for one release, under the old `claude-agent-scaffolding`; an entry under the new name wins. The install key is `crew@pulsestack`. No other change.

## 0.11.1

**Text only (#755).** `lifecycle.md`, `briefs.md` and `ossify-pr-briefs.md` say where a `gh --repo` name comes from: the target repository's own `origin` (`gh repo view`), read from that repository's checkout and never built from a folder name. The dispatcher fills `PR_REPO` the same way. No code.

## 0.11.0

**`crew-run`, a small writer for the run file (#754).** `bin/crew-run` (bash and jq, `crew-run help`) writes the transitions that fail the linter most: `open` a new attempt (phase `recorded`, its full locator, liveness, an optional `--cause`; the task moves to `working`), `settle` an attempt (`--outcome` and `--tier`; the task moves to match), `send-back` (the review settles `done`, the reviewed attempt `rejected`, a new attempt opens with `cause {sent_back, by, ref, reason}`), and `commit <file>` (the existing loop for a document the seat built). Every verb stamps its times from the clock, appends its events, and ends in dagr's producer loop: a temp file beside the run file, `dagr check --strict`, the rename only when clean. Exit 0 written, 1 linter findings (run file untouched), 2 refused or bad usage. It never decides: outcome, tier, cause and locator are arguments, and free text reaches the file only as a `jq --arg` value.

- **Behaviour change: crew no longer says "no binary writes".** `crew/README.md`, the marketplace entries (Claude Code and OMP), the Claude Code and Codex manifests and the root README row state it. Codex has no plugin `bin/`, so on Codex the loop stays a hand loop.
- **`lifecycle.md` step 1 keeps the one copy of the hand loop** and names the four verbs; the spine and work-PR briefs and `ossify-nested-run.md` point there instead of restating the lint rule. The skill text is 3 bytes shorter overall (the `crew-run` pointers cost what the restated rules saved).
- **A dagr that is not contract v3 is refused**, so a dagr upgrade is loud; dagr is found by the producer contract's order (`$DAGR_BIN`, PATH, `$HERDR_PLUGIN_ROOT`) and never by `cargo run`. The transition verbs refuse a file that is not `"dagr": 3`; `commit` takes any version dagr accepts.
- **Overlapping calls lose nothing.** Every verb holds `RUN.lock`, a file bash creates with noclobber, from its read to its rename; a second call waits up to `CREW_RUN_LOCK_WAIT` seconds (30), then refuses. A lock is never taken over: a holder killed with SIGKILL leaves it, and the refusal says whether its pid still runs. `commit` refuses a candidate older than the run file, and a `--run` that is a directory.
- **`/crew:orchestrate` allows `Bash(crew-run:*)`.** `omp/bin-path.ts` ships in crew, byte-identical to the marketplace's, so OMP puts `bin/` on `PATH`.
- **Known limits:** a phase flip to `delivered`, liveness ticks, gates, directives (no directive verb: E172 stays) and plan edits stay hand edits, committed with `crew-run commit`. dagr's `$HERDR_PLUGIN_ROOT` fallback looks for `target/release/dagr` and then `bin/dagr`, where an installed herdr-dagr keeps its binary.
- **New check:** `tests/test-crew-run.sh` runs every verb through the real `dagr check --strict` (dagr missing is a failure, never a skip), covers each refusal and exit code, the lookup order, a whole lifecycle with a retry, a send-back and a rebind by `commit`, and 14 linter classes (E150, W209, E112, E132, E133, E142, E170, E181, W203, W207, E140, E141, W204, W208) as a hand-built document dagr rejects against the verb's result. CI installs dagr 0.3.1 from the pinned, checksum-verified release asset before the crew suite.

## 0.10.0

**Briefs go by file on both layers (#752).** The orchestrator writes a brief, a correction request or any message past one line to `<run dir>/scratch/<role>-<n>.brief-<k>` and sends one fixed line, `Read <path> and follow it.`; the free text never travels as a shell argument. A one-line nudge, such as the `PING:` form, stays inline.

- **Behaviour change: `brief_delivery` now defaults to `file`.** An entry with no value used to mean `inject`; it now means `file`. An entry that states `inject` or `file` keeps its meaning. `config.md`, `lifecycle.md` and both layer files carry the change, and `layers/orca.md` gains the by-file send it lacked.
- **Known limit: a seat with `host:` on another machine keeps `inject`.** Its file would sit on the wrong machine and no layer has a copy step, so such an entry states `inject` and its brief still travels as a shell argument. An entry that names such a host without it is a config defect named at approval.
- **New check:** `tests/test-brief-by-file.sh` fails if a layer file, template or shared reference shows a brief placeholder as a send's argument, and passes on the fixed pointer line.

## 0.9.2

**The shipped role list no longer names `triage` (#1023).** baton 0.14.0 removed that stage, so `config.md` lists only baton's `driver`. A project file that still fills a `triage` row is harmless: baton ignores it.

## 0.9.1

**The status block's fields can run for several lines (#994, with seat-mods 0.13.0).** `SKILL.md` §8 says so, and several decisions go one numbered item each. Text only.

## 0.9.0

**Two new built-in roles, for baton (#993).**

- **`triage` and `driver` join the shipped role list** (`config.md`). `triage` answers a stuck
  seat's prompt only when the brief decides it, else stops; `driver` settles the parks its brief
  names and escalates the rest. A project's setup asks for them, and baton reads the two config
  files through `running-a-spine-on-baton`. Crew's own orchestrate runs launch neither.

## 0.8.2

**Text only — the follow-ons from the 0.8.1 review (#987), closing #954.**

- **The rail reaches a carried seat (#954).** The `SEATS` rows and the work-PR `REVIEWER` and
  `PRFIX` rows end `[ | rail: <rail>]`, the rendered row's own tail, and both layers' model
  reads run a named rail's check in place of the `seat: <role>` status line. A seat a
  coordinator launches from a carried row records its rail, not "no guards".
- **The rail's value has a format.** One line, `<guard> — <check command>`, holding no `|`,
  which separates the row's fields. The row puts its machine after every launch field, with
  only the rail tail after it, and the check runs once per launch, at the model read.
- **A re-check names what changes.** Two slots: the tree it judges (the generic `PLACEMENT`, the
  item verifier's `head_oid` and `tree_oid` from the latest return), and a fresh `REPORT_PATH` in
  the same report directory, so the first report is kept. The spine's correct path in `ossify-nested-run.md` and the
  eval rubric say the same.
- **The calibration fixture is reconciled.** "Never edit product code" names its base checkout,
  which restores committed code in a worktree no branch receives. Its expected `fail` never
  counts toward a second fail, and the item passes only on a re-check of its real head after it.
- **A test-only item deletes the mutation claim** and is never judged an empty revert.
- **Pins** for the detached worktree at the item head and the blind re-check, each mutation-tested;
  the config suite's budget comment credits its +3 lines to the right edit.

## 0.8.1

**Text only — five verifier-pilot frictions (#952, #953, #954, #955, #979).**

- **The ping reads one line (#955).** Every `PING:` line reads the run file with
  `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"'`: pane and machine on one
  line. The two-value form printed two, and a worker's `read pane machine` took an empty machine
  and skipped its ping as a mismatch.
- **A re-check is the verifier brief, refilled (#952).** Lifecycle step 7, the generic verifier
  template and the item verifier say so: every slot refilled, the tree it now names judged, never
  the previous check's. The diff claim names one form, `git diff --cached <base sha>`, which covers
  a committed head and a staged tree, so no top edits it for a staged re-check. A revert that
  changes no file is `cannot determine`, naming the paths tried; an item that changes only tests
  drops the mutation claim.
- **Calibration fixtures have an owner (#953).** A seeded defect the verifier must fail is the
  top's own worktree mutation (delegation floor, kind 6): a detached worktree at the item head,
  seeded only by `git checkout <base> -- <path>` on a path the implementer's report names, never a
  worker's task and never on the PR branch, removed after its re-check.
- **A named rail (#954).** A machine entry may carry `rail:` — the guard the agent runs under in
  place of seat-mods and the one command that checks it. It travels as the profile row's tail, and
  the model read runs that check instead of reading the `seat: <role>` status line: a pass records
  the rail, a fail records no guards.
- **The standards claim names what it judged (#979).** Its evidence names `<standards file>` by
  the path the brief filled and quotes the rule line (or neighbour) and the hunk verbatim. The
  fixed claims carry tags — `[ac]`, `[diff]`, `[mutation]`, `[standards]` — and both verifier DONE
  shapes keep them, since an item verifier's ACs come first and move the numbers.

## 0.8.0

**Text only (#951).** The verifier brief's CLAIMS gain a fourth claim, never deleted: the diff
follows `<standards file>` and the conventions the repo follows in fact, with the rule line or
the neighbouring committed file quoted beside the hunk. The dispatcher fills `<standards file>`
in merge-bar `reviewing-a-pr`'s order — `CODING_STANDARDS.md` at the paired AI workspace root,
else at the repo root — then the ossify memory bank's `03-code-patterns.md`, else `none — looked
at <paths>`. With none, the verifier judges conventions-in-fact alone; a missing file is never
`cannot determine`. An activated spine's item verifier gets the claim through the CLAIMS body
`ossify-briefs.md` already supplies verbatim, so that file and `verifier_procedure:
all-claims-work-item-verify/v1` are unchanged. Every verifier report now carries a claim-4 line.

## 0.7.0

**Text only (#963).** `orchestrate` follows merge-bar 0.6.0. Where `REVIEW_INVOCATION` is
`/merge-bar:review-pr`, the reviewer brief's report file is that command's report, whole, in
`reviewing-a-pr`'s `references/report.md` shape, its `Head:` line the reviewed head; any other
review command keeps the `Findings:` / `Reviewed head:` / `Summary:` schema. The work-PR
session's step 3 and lifecycle step 8 accept either shape: a `reviewing-a-pr` report validates
with its `## Coverage` table and a `Bar:` line on every `### C<n>` class, no class is a clean
review, a class blocks unless its `Bar:` is `non-blocking` or it carries `Closes:` (a `Still
open:` class keeps its `Bar:`), and a `Head:` off the PR head is
historical (step 3) or fails validation (step 8), exactly as a mismatched `Reviewed head:` does.
Its fix-range re-review is a fresh seat running `/merge-bar:review-pr <PR_URL> --round <n>
--previous <previous report path>`. Where `working-a-pr` runs, the work-PR session never merges
a one-way door (`Door: one-way`, or no `Door:` line): it returns `handed off: one-way <reviewed
head OID>`, and the top, as merge holder, follows merge-bar's
`skills/working-a-pr/references/one-way-door.md` under either merge word, `standing` included,
and merges pinned to that OID. The two-way merge path is unchanged.

## 0.6.0

**Removal only.** The enrolled OMP authority text is gone from `orchestrate`: the section that
issued and bound an assignment, the authority envelope every brief template carried (the opening
line, its five startup variables, `BOUND FACTS`, `PROVENANCE`, `LIFECYCLE`, `FRESHNESS`), the
enrolled-OMP paragraphs in the roles, lifecycle, spine and config references, and the "A child's
pain" paragraph of `completion.md`. The guarded launch export, in `roles.md` and the Orca layer,
ends at `MOLT_STATUS_PATH`; the ledger, pain-path and mode variables are no longer set, and the
launcher's mode is no longer read. The `PROHIBITIONS` line keeps its operator-owned gate sentence
and the merge rule, and loses only the clause about enrolled acknowledgment. Step 12 asks for the
merge word on an `operator` run as before, and step 13's handoff notes the molt status line only.
The context-ceiling hook's comment names molt alone as owner of the context boundary.
Earlier entries are history and are not edited.

## 0.5.0

The seat and profile orders crew reads come from the project's own files. `orchestrate` takes
a standing order "in the project's memory bank or AGENTS.md" for seats and profiles where it
named the autopilot policy, and points at merge-bar's working-a-pr "Standing orders"
paragraph for where it is read and whom it binds, without restating it; only orders naming the
orchestrator role bind it, and with no standing order the ask stays.
No agent gains authority; the enrolled-authority text is unchanged.

## 0.4.3

**Text only.** autonomic 0.11.0 no longer judges a turn end, so `orchestrate`'s completion text
says a child's pain line is "a pain", not "a turn-end pain".

## 0.4.2

**The status block is checked on OMP too.** `orchestrate`'s OMP host notes say seat-mods 0.8.0
checks an OMP top's status block (one block per turn, then a warning), as on Claude Code.

## 0.4.1

**The status block's second wait field is `Waiting on operator:`** (#879). §8's block names
`Waiting on operator:` in field 5 (was `Operator decision pending:`), taking `none`,
`decision: <question>` or `action: <what the operator must do>`, and states five fields, one per
line, with a blank line between fields allowed — not "exactly five lines". seat-mods 0.7.0
enforces the label, the forms and the blank-line rule on a Claude Code top's status turn; the
same text reaches an OMP top through omp-roles 0.7.5's `orchestrator` role.

## 0.4.0

**The Orca layer ships** (spec §4.1, plan Part C). `layer: orca` now loads
`skills/orchestrate/references/layers/orca.md`, written from the 2026-10-18 Orca 1.4.229
probes; the 0.3.0 stop that refused the value is gone, and either value names the layer
file the run loads, `references/layers/<layer>.md`. The file carries what the probes
measured: the seat launch as one `--command` line over `roles.md`'s launch export — a lane
is a shell function, so `exec <lane>` leaves a shell — the `tui-idle` wait run as a
background job (a turn's end, not the work's), the same-host `PING_SEND` form with the
turn-start proof and the never-resend rule, the rendered read, the teardown that catches
the default shell terminal `worktree create` opens, and the `--environment` flow for a
seat on another machine. The layer-neutral OMP host rules move to `SKILL.md` §3, stated
once with the skill. Manifests and catalogs are 0.4.0; the Codex manifest's keywords add
`orca`.

**A seat can run on another machine, and a spine's close walks its demo there** (spec §4.5).
The machine file's agent entry gains `host:` — absent, this machine; a value is a machine name
the layer's Machines step accepts — and it travels: every resolved profile that crosses a
session carries the host and the agent's name (a spine's `SEATS` rows, the work-PR brief's
reviewer and PR-fix rows, a handoff's carried seats, the close brief's `DEMO_WALK` row), so a
session that did not resolve the seat itself starts it where the row names, and a resumed top
re-resolves a carried seat by its carried name where a row cannot give its machine. A
`user:`-type demo-ledger entry an operator assigns to another machine is walked by a
demo-walk seat on it (`briefs.md`'s `demo walk`, a bounded read-only brief), launched and
read through the layer's Machines step; the herdr layer states no cross-machine report read
(the Orca one is measured), and the close launches exactly that one seat and releases it.

**This release includes 0.3.1 and 0.3.2** — the tagged sends and the top's status block (#867), and the idle-stop rule (#876); those sections are kept whole beneath as history.

## 0.3.2

**A block that waits on nothing ends no turn** (#876). `orchestrate` §8 now says, after the status block's field list: "A block that waits on no seat and no operator decision while its Next steps names work is not a turn end: do the next step first, and write the block when something outside you holds the turn." seat-mods 0.6.0 enforces it on a Claude Code top's status turn — one nudge, then a warning line, sharing the turn's one block with the shape check — and the same sentence reaches an OMP top as text in omp-roles 0.7.4's `orchestrator` role.

## 0.3.1

**Every crew send up to a parent or top session is tagged** (#867). The `PING:` and `MOLT:` lines of every brief template now send `[crew report <role>] <task id> <kind> <path>` and `[crew molt <role>] <pct> <task id>`, `<role>` the template's own role word (`implementer`, `verifier`, `reviewer`, `coordinator`, `orchestrator`), and the correction request's re-ping is tagged too — the worker sends that ping up. `layers/herdr.md`'s `Send` states the rule and what stays untagged: everything sent down to a worker (briefs, plan-gate replies, correction requests, `/context`, delivered verbatim), and local slash commands (the rotation resume — `/ossify:handoff-resume <path>`, `skill://handoff-resume <path>` — `/context`, `/clear`), because the tag is a prefix and a prefix would break any slash command. The legacy `REPORT READY:` and `MOLT WARNING` forms stay accepted until no run in flight was dispatched from a brief older than 0.3.1 — a 0.3.1 top still receives them from workers a 0.3.0 brief dispatched.

**The status block is stated for the top** (#867). `orchestrate` gains a "Status replies" section: on a turn the operator did not start by typing, the top's reply is only the five-field status block — exactly five lines, one field per line, `none` as content — with nothing before or after; a turn the operator typed takes any shape; only the top orchestrator follows it. A status turn whose reply must end with molt's `MOLT-HANDOFF: <path>` line ends with that line instead of the block. The same rule reaches an OMP top as text in omp-roles 0.7.3's `orchestrator` role.

## 0.3.0

**`herdr-crew` becomes `crew`** (spec §4.6, clean cut). The directory, the plugin name, the skill (`/crew:orchestrate`) and all three marketplace catalogs move together in this release; no alias plugin ships, and no in-tree reference to the old name is left outside this file's history. The paths move with them: the machine file is `~/.claude/crew/agents.md` and the project file is `.crew/roles.md`. An operator still holding the old files is told the exact move.

**One orchestration prose, one file per terminal layer.** The skill keeps every decision; the commands that drive a layer move into that layer's own file, `references/layers/herdr.md`, under fixed step headings, so the next layer adds a file rather than a second copy of the rules. The rules a layer only obeys stay in the shared files and are named by the step that carries them: the seat marking and the teardown order in `roles.md`, the completion contract — the report-file doorbell, the generation check, the ping and the heartbeat — in the new `references/completion.md`. Which layer a project uses is the project file's own line, `layer: herdr` or `layer: orca` — read from the file, never guessed. 0.3.0 ships the herdr layer only: `layer: orca` stops and says the Orca layer arrives in 0.4.0.

- **This release carries herdr-crew 0.2.29 with it** (below): the standing-order seat, profile and PROHIBITIONS changes merge in before `crew` 0.3.0 ships, so the first crew release is 0.2.29 plus the rename and the layer split.

## 0.2.29

**Seats, profiles and the briefs follow the autopilot standing orders** (slice 1 of the stop-the-menus plan). `ossify-execution.md` §3's seat set, its depth confirmation and its resumed-top seat ask, §5's reviewer, PR-fix and close-review writer picks, and `ossify-nested-run.md`'s writer ask now carry the condition: under the **Seats and profiles** standing order in the autopilot policy, the top picks from the project file and continues; otherwise every ask stands exactly as it was. The PROHIBITIONS line in all sixteen brief templates moves the merge off the operator-owned list: a worker's implementation plan is the top's to approve and the merge follows `run.merge_word`; design/spec/release gates, product choices, credential values, Molt handoff, the delete/force-push/no-verify rails and the enrolled-OMP acknowledgment clause are unchanged.

## 0.2.28

**A top that molts in place on OMP re-arms its waits** (#855). omp cancels every background job a session owns when it clears that session, so on OMP the armed waits and the heartbeat do not survive a molt; molt 0.3.3's seed says so. The molt-in-place paragraph now scopes "every armed wait survives the clear" and "it arms no wait the handoff lists" to Claude Code. On OMP, after its generation check, the resumed top re-arms the wait of each dispatch still live and one fresh heartbeat.

## 0.2.27

**The reviewer's command is configurable** (operator, 2026-10-16). A machine entry may declare `review:`, the command a reviewer seat on that agent runs, with `<PR>`, `<PR_URL>` and `<LEVEL>` filled at dispatch (`/review <PR_URL>` on OMP). An entry with no `review:` keeps `/code-review <PR> <LEVEL>`. Both reviewer briefs carry the filled command as `REVIEW_INVOCATION`, which replaces the work-PR brief's `REVIEW_LEVEL`. The `can:` table's reviewer row needs `slash-commands` when the command the reviewer runs is a slash command. Lifecycle step 8, roles.md, SKILL.md and the README name the review command instead of `/code-review`.

## 0.2.26

**A run resumes after its top dies with no handoff** (#810; operator rulings 2026-10-16). Every bind now records `run.orchestrator.session`, herdr's `agent_session` for the top's pane — the top's own bind, a spine or work-PR session's, and a top that molts in place (molt's `/clear` starts a new session in the same pane). On the operator's word that the old top died, a new top told to bind the run runs three steps before the resume: it reads `run.orchestrator` before any write, stands the old top down (the operator confirms and closes a pane that still exists: never two tops on one run), and reads the dead top's transcript, found by that session id, for the step in hand, decisions in flight and the last action started. Then the rotation's resume runs with the transcript in the handoff's place: `run.json` wins on facts, a dispatch whose attempt the run records is never sent again (the resume's generation check settles it), and any other started but unconfirmed send, merge, tag or branch delete is checked for its effect before it is redone. Every brief's PING line now says a skipped or failed send is never an answer: a worker with a plan or a question waits at that gate (run B's implementer started without approval).

## 0.2.25

**A standing merge word merges with no ask** (#837). With `run.merge_word: standing`, lifecycle step 12 no longer asks anyone: the operator's standing word is the merge word, and a clean gate set on the head SHA (every check green, every finding fixed or logged as debt through merge-bar) is the agreed condition, so the top merges, pinned to that SHA. With `operator`, it still asks the operator. Live OMP tops in runs A3 and B already merged this way; the text now matches. SKILL.md's work-PR paragraph and `ossify-nested-run.md` answer a work-PR session's merge ask by the same rule.

## 0.2.24

**Seat-driving fixes from the OMP friction review** (part of #845). Every launch-record line in a brief (`SEAT_COMMAND`, `SPINE_COMMAND`, `CLOSE_COMMAND`, `WORKPR_COMMAND`, `WRITER_COMMAND`) says it records the seat's own launch and is never run: an OMP implementer ran one and started a nested console. The OMP host notes now tell the top, and an OMP coordinator for the seats it drives, to pass `timeout: 0` on every bash async job (omp's default deadline is 300 s) and never `name:`, which puts omp's bash in service mode and refuses async and timeout. The readiness text says that before detection (about a second after `pane run`) `agent list` omits the pane and `agent get`/`agent wait` answer `agent_not_found`: ask again for up to five seconds, then take the not-detected path.

## 0.2.23

**OMP may fill the activated spine session and the work-PR session** (#788, #839). Run 788 ran both on OMP (GLM-5.3) and passed. config.md's placement sentence and README's copy now allow them, through omp-roles 0.6.0's `crew-spine` and `crew-work-pr` roles. Those roles take the brief as the procedure and launch every seat as a herdr pane, so they no longer contradict it, as the default-lane `spine-driver` and `work-pr` roles did. The `can:` table's OMP doctor row now also covers the activated spine session, the ossify item implementer (`omp-seat worker`) and the work-PR session: each reaches its skill by `skill://` and needs no `slash-commands`. Both new OMP coordinators get each hosting repo's `.worktrees` root in `SEAT_MODS_ALLOW`, as the lane driver, close and doctor sessions already do.

## 0.2.22

**A rotation resumes from run state** (#819, part of #810). The rotation's resume is one procedure from `run.json`: rebind; re-ask an open `run.question`; run the generation check against `locator.seen` and re-arm each live attempt's waits; arm one heartbeat; continue at the handoff's next step, never re-running a done one. A resume after a hard stop (the top died with no handoff) is not claimed: the new top tells the operator (#810). The rotation handoff shrinks to the run path, the next step and the context the run file cannot hold, and restates no operator gate: for the merge it points at step 12 and `run.merge_word`, which step 12 now reads. Legacy run files resume with stated defaults. A molted top reads `locator.seen`. A brief sent to a seat already running now opens its attempt with phase and locator like a launch.

- The outgoing top's write/dispatch ban starts at the handoff, including wakes during successor launch.
- At `phase: recorded`, every dispatch saves an existing report's generation in the new attempt's `locator.seen`, so a retained seat's previous report is not consumed again after a resume or molt.
- Orient sends a rotation's takeover through the resume before rebinding.

## 0.2.21

**The ping follows the top; the run file carries the live facts** (#816, groundwork for #810 and #819). Every report-producing brief replaces `NOTIFY_PANE` with `NOTIFY_RUN` (the dispatcher's `run.json`) and `NOTIFY_MACHINE`: at each ping the worker reads `run.orchestrator` and pings that pane only when its machine is the worker's, so a successor top's rebind redirects every live worker's ping with no message to it. The top now writes `run.merge_word` at creation, `run.orchestrator.machine` at each bind, `run.question` around each operator ask, and per attempt `phase` (`recorded` before the brief, `delivered` after the confirmed send) and `locator` `machine`, `report`, `status`, `pain` and `seen` (the consumed report generation). `dagr check --strict` accepts every field. A live worker dispatched under 0.2.20 or earlier keeps pinging its fixed pane until its dispatch ends.

## 0.2.20

**Waits that do not page the operator for nothing** (#651, B and D; the operator's 2026-10-12 ruling). A detected coordinator's `--until blocked` companion that times out while its report-file doorbell is still armed lapses silently: no `pane read`, no report, and the doorbell (and the heartbeat, where armed) covers the rest of the dispatch. The heartbeat gains a stall rule: a seat read `working` at two consecutive ticks with no new report generation takes the next tick's one check as `herdr pane read`; a read showing only provider errors and retries is a seat failure, not a failed task: its dispatch is settled (its report-file wait and companion killed) and the fallback the project file's `## Conditions` names is launched as a fresh seat from its own row, the brief re-sent with `RESUME FROM:` the seat's last report when it wrote one. A seat a fresh session cannot resume (a work-PR seat inside a fix round; a close, work-item, lane-driver or doctor seat mid-ceremony; a reviewer before its report validates) gets no fallback, and it or a stall with no fallback named is reported to the operator once. Every timeout-is-a-checkpoint rule (`herdr-mechanics.md`'s typed wait and dead ends, `lifecycle.md` step 5) carries the companion's exception. `## Conditions` may set another bound. The mechanics reference budget rises from 370 to 385 lines.

## 0.2.19

**An OMP top for the weekly-limit fallback.** herdr-mechanics.md gains "Host: OMP"; lifecycle.md's rotation handoff records a launch command and resolved profile per host, a cross-host successor is checked against its own host's profile and resumed in its host's form, an OMP top writes its handoff with `skill://handoff`, and a new top re-arms each live pane with step 5's waits. A resume after a hard stop (no handoff) is not in this release. OMP may now fill the top and its rotation successor (omp-roles 0.4.0 `orchestrator`, seat-mods 0.4.4). herdr-crew joins the OMP catalog. Work-PR and activated-spine placement stay narrow (#788).

## 0.2.18

**OMP launcher mode follows the live file** (#769). An `omp-seat` coordinator reads
`cat "$AUTONOMIC_MODE_FILE"` (autonomic 0.7.0), because omp's bash children keep the
session-start environment; only an exact `autopilot` marks a child. Unset, a missing
file or older autonomic leaves the child manual. Claude Code keeps its live
`AUTONOMIC_EFFECTIVE_MODE` read. OMP seat placement stays narrow until a live OMP
seat-launching run lifts it (#788). The mechanics suite pins both reads and its
reference budget rises from 357 to 360 lines for the OMP route.

## 0.2.17

**OMP coordinator and worker seats.** The machine-file example launches `omp-seat`
with the three OMP extensions. OMP coordinators add each hosting repo's `.worktrees`
root to `SEAT_MODS_ALLOW` for their task children; OMP seats fill only the lane driver (default-lane spine session), close, doctor or worker seats, never the orchestrator top, its rotation successor, a work-PR session or an activated spine session until a live OMP seat-launching run lifts it (#788).

## 0.2.16

**The spine brief calls `oss` by name.** §8a's caller rule loses its "(run-spine's resolved
dispatcher)" parenthetical: ossify's fences call `oss` by name now, and the plugin loader
puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so there is no resolved-dispatcher
variable left to refer to. The contract pin follows the sentence, and the suite's reference
budget follows the file down one line (232 → 231).

## 0.2.15

**Implementer PRs open on merge-bar's template.** The planned and fast implementer briefs
gain a `PR_BODY_TEMPLATE` slot: the dispatcher pastes the installed merge-bar's PR body
template into it verbatim (ossify's copy where only ossify is installed; `none` where neither
is). Their `DONE:` line writes the PR body from that slot — every heading in order, the Merge
bar block word for word — and opens the PR with `--title` and `--body-file`, where it used to
run a bare `gh pr create`. The template reaches every seat, a non-Claude one included, without
the seat loading merge-bar's skills.

## 0.2.14

**The round stop is merge-bar's wherever `working-a-pr` runs.** Lifecycle step 11 hands the
stop to merge-bar's `working-a-pr` when the work-PR dispatch runs it (directly, or through
`/ossify:work-pr` where merge-bar is installed): the PR body's Merge bar decides what blocks,
a blocking finding is never deferred, and no separate stopping rule is agreed or written into
the bar. The old rule predated merge-bar and led seven canonical PRs to lower their bar.
Without `working-a-pr`, the generic loop keeps its default (defer remaining P2s and P3s, never
P0 or P1). The round-five process checkpoint stays on both paths. The skill's step list names
step 11 "round stop". The ossify work-PR brief's `STOPPING_RULE` slot takes `merge-bar` where
merge-bar is installed, so `/ossify:work-pr` follows `working-a-pr`'s round stop there.

## 0.2.13

**The DeepSeek Harness seat is gone, with the crews it came from.** `orca-crew`,
`paseo-crew` and `dsh-crew` are retired from the marketplace, and herdr-crew drops the
`kind: dsh-spine-driver` seat kind that needed `dsh-crew` beside it:
`references/dsh-driver.md` is deleted, and the skill, command, `config.md`,
`herdr-mechanics.md`, `lifecycle.md`, `ossify-execution.md` (§7) and
`ossify-nested-run.md` lose their dsh carve-outs. A roles file that still names a
`kind: dsh-spine-driver` agent is no longer a supported shape. The manifest descriptions
drop the dsh sentence; the README drops the orca-crew migration note. Tests lose the
dsh and Orca pins, and `REF_BUDGET` follows `herdr-mechanics.md` down to 357.

## 0.2.12

**No Devin seat in the examples.** `references/config.md` drops its `devin-impl`
example row, and `herdr-mechanics.md` and `roles.md` no longer suggest a
`devin-*` lane. Devin seats were retired on 2026-09-22. The row contract is unchanged.

## 0.2.11

**A launch site with no marking clause now fails a suite** (#663). Test tooling only: no
shipped behaviour changes and the row contract (`config.md`) is untouched.

- **`tests/test-launch-site-marking.sh`** selects launch sites in the shipped prose
  (`skills/**`, `commands/**`) by the rule stated in its header — which also names the
  shapes it does not select — and fails a selected site whose own paragraph or list item
  carries no seat-mods marking clause: the guarded
  `SEAT_MODS_ROLE` export, a guarded role, `coordinator`, `orchestrator`, or a citation of
  `herdr-mechanics.md` step 2 / "Seat marking". `**` spans are stripped before matching,
  so a bold verb or article selects. Each failure names file, line and the site text; the
  suite prints the number of sites it selected and pins today's count (26) as a floor, so
  a grammar change that silently selects fewer sites fails, and a scanned path whose own
  scan dies (an unreadable file, a directory named `*.md`) prints `SCAN-ERROR` and fails
  the run rather than vanishing behind the other files' counts.
- **What the rule covers:** the three placement commands (`tab create`; `worktree create`
  with `--path`; `workspace create` for a seat); "launch(ed) from the … seat";
  "launch a/the/its … [fresh|new] seat|pair|…" with bold verbs and articles, the
  create/dispatch/respawn verb forms, the close-session and doctor-session nouns and
  "launched from the … SEATS row(s)" included; bare `respawn`. **What it does not:** the
  bare noun "the seat launch"; "launched at its point or on demand"; marking directives
  with no launch verb ("Mark it `coordinator` before its command"); router and depth
  descriptions ("drives a fresh tab and pane per item seat", "launches item sessions of its
  own", "launched by seat name", "start one spine session"); "create … from its … row"; a
  dispatch whose command string intervenes before the fresh noun ("dispatch
  `/ossify:close <spine-id>` to a fresh close session"); the elided noun "a/the fresh
  close" ("then dispatches a fresh close", "the top dispatch the fresh close"); a
  pronoun or preposition between the verb and the noun ("dispatch it to a fresh close
  session", "dispatches to a fresh close session"); a launch sentence directly under a
  heading; frontmatter with no blank line after `---`; `kind: dsh-spine-driver` sessions
  (not panes, never marked); headings and frontmatter. A new site in one of those shapes
  still passes — the accepted residual, named in the suite's header.
- **Four launch statements gained a citing clause** — a pointer, not a second copy of the
  marking: `roles.md`'s activated-ossify-spine rows and `ossify-briefs.md`'s item-verifier
  intro now say the session that launches the seat marks it in the pane, before its
  command, as `herdr-mechanics.md` step 2 states, and `ossify-execution.md`'s resumed top
  marks each seat it launches as step 2 states; `ossify-pr-briefs.md`'s close brief names
  the fresh close session's own marking.
- **Known looseness:** any bare mention of a clause token in the site's region satisfies
  the check, and `step 2` is also lifecycle's own step 2. The clause texts themselves stay
  pinned by the sibling suites.

## 0.2.10

**A child's autopilot follows the launcher's live mode** (autonomic 0.4.0, PR #694). Install
with autonomic 0.4.0.

- **The launcher's mode** (`herdr-mechanics.md` step 2) is read from the launcher's own shell,
  `printf %s "$AUTONOMIC_EFFECTIVE_MODE"`, which autonomic 0.4.0 sets on every mode change. It
  is never the record file (0.2.9 read `jq -r .mode` from it): a record that failed to write can
  still read `autopilot` after autonomic fell back to manual. It is still never
  `$AUTONOMIC_MODE`, the spawn's input. `autopilot` marks the child; anything else, unset
  included, does not.
- **Known limit:** under an autonomic older than 0.4.0 the variable is unset, so every child
  starts manual.
- **Known limit:** autonomic 0.4.0 treats the variable as advisory under host failures: a host
  that refuses an env call while autonomic resolves or publishes the mode can leave the previous
  value (autonomic PR #694 Known limits).

## 0.2.9

**Seats carry autonomic's variables, and a spine cut mid-round is resumed** (autonomic
0.1.0's Task 16, #676; ossify 1.14.0's run-spine re-entry, #674, #678). Install with
ossify 1.14.0 or later and autonomic 0.1.0; molt 0.2.0 stays the pairing for 0.2.8's child
mode.

- **autonomic marking** (`herdr-mechanics.md` step 2). The per-pane export every child
  already takes adds `AUTONOMIC_LEDGER=<ledger> AUTONOMIC_PAIN_PATH=<REPORT_PATH>.autonomic-pain`,
  and `AUTONOMIC_MODE=autopilot` only when the launcher's own autonomic record reads
  `autopilot` — never `$AUTONOMIC_MODE`, which misses `/autopilot on` and a molt's lineage and
  can say autopilot where autonomic refused it; a missing record reads as manual. `<ledger>` is
  the launcher's own `$AUTONOMIC_LEDGER` (resolved to absolute first, and passed on only when every character is a letter, digit, `.`, `_`, `/` or `-`), else
  `<run dir>/autonomic-ledger.md`: one absolute ledger per run, outside every worktree. The top's rotation successor takes the mode and the
  ledger, no pain path. `AUTONOMIC_BELL` is never set.
- **A child's pain** (`herdr-mechanics.md`, Completion). The heartbeat and the read before a
  retained seat's next unit read each child's pain file beside its molt status file; a new
  line is the seat asking upward, never a failed task. A seat-mods deny rings nothing of its
  own. The top's handoffs carry each seat's pain path.
- **A spine cut mid-round is respawned, not relayed** (#674). ossify 1.14.0's run-spine
  re-enters a started spine, so a spine session that hands off with no `rotate:` is respawned
  as a `rotate:` is; only a halt in its reconcile read-out goes to the operator. Before
  its re-run the successor closes every item pane its predecessor left live, or halts. The spine
  brief still never stops mid-round on its own: relaxing ROTATE waits for a restarted spine
  session to prove the re-entry.
- **Spine-brief caller rules** (ossify `external-executor.md` §2a). The staged-result rule is
  scoped to a re-entry request for an item this session has not executed; a rejected
  result's worktree is the correction path. The caller counts each execution the lane did not request — a correction or a replacement — reading
  `dispatches` first. An `adopt` item arrives as an ordinary request; `finish-merge`,
  `finish-status` and `complete` items get none.
- **`dsh-driver.md`** (#678). A dsh spine session is resumed by a steered re-run of the
  spine command, `<spine-id> --external-executor` — the shape the `crew-spine` persona
  accepts — never "continue from its recorded state". paseo-crew's and orca-crew's copies carry the same text, to keep their parity
  gates; neither is re-versioned.

## 0.2.8

**Children hand off to their parent; only the top molts in place** (molt 0.2.0's child
mode). Install with molt 0.2.0, never before it.

- **Children are marked.** Step 2's one export adds `MOLT_HANDOFF=parent
  MOLT_STATUS_PATH=<REPORT_PATH>.molt-status` for every guarded seat, coordinator seat and
  operator-declared role; `roles.md`'s launch block carries the combined exports. The top and
  its rotation successor stay roots. A respawned child is a launch: step 2 runs again.
- **Parents answer** (`herdr-mechanics.md`, "A child past molt's warnings"): a `MOLT WARNING`
  ping (not a report ping) or a new status line means no new unit — the warned seat's next
  unit goes to a fresh seat; the heartbeat reads the status file each seat was launched with;
  a `handoff:` report or a `handed-off` status line respawns the seat. Every respawn takes a
  fresh `REPORT_PATH` in the same report directory, reuses the scratch directory and, for an
  implementer, the same worktree, and carries its brief plus `RESUME FROM:`.
  A spine or work-PR session cut mid-round, a close, work-item, lane-driver or doctor seat cut
  mid-ceremony, and a reviewer cut before its report validates go to the operator.
- **Templates.** The 13 leaf templates carry one `MOLT:` line (ping, finish the unit; on
  molt's command mid-unit, a hand-written handoff at `<REPORT_PATH>.molt.md`). A molt warning
  moves the spine's `ROTATE` and the work-PR's `open:` as the ceiling notice does; the spine
  still never stops mid-round. The spine brief gains the staged-result caller rule.
- **The top molts in place** (`lifecycle.md`, "Where molt runs"), carried by hand from closed
  #669: the live task ids and any held operator question in the handoff, the
  wake-after-handoff rule, no stand-down and nothing re-armed, the carried heartbeat tick, the
  hash-and-identity generation check, and "A molt is not a launch".

paseo-crew and orca-crew children stay unmarked until #666 and #667.

## 0.2.7

**Every launch marks its session for seat-mods 0.2.0.** seat-mods 0.2.0 guards a session
whose `SEAT_MODS_ROLE` is unset or empty as an implementer, and treats exactly
`orchestrator` and `coordinator` as unguarded — so herdr-crew 0.2.5's coordinator seats,
and the top's rotation successor, would have launched as guarded implementers that cannot
merge. 0.2.7 marks every seat it launches into a herdr pane — and an operator-declared
role with no `replaces:` as a guarded `implementer`.

- **The two free roles are marked at launch.** `herdr-mechanics.md` step 2 is rewritten
  from the 0.2.5 complement (coordinator seats listed as unguarded) to the marking: a guarded seat — implementer, verifier
  or reviewer, and a `replaces:` role as the role it replaces — exports its role with
  `SEAT_MODS_ALLOW`; a project-file role with no `replaces:` is marked a guarded
  `implementer`, its report and scratch directories in `SEAT_MODS_ALLOW`; a coordinator
  seat — the spine, close or work-PR session, the doctor session, the lane driver — exports
  `SEAT_MODS_ROLE=coordinator`; the top's rotation successor exports
  `SEAT_MODS_ROLE=orchestrator`; neither free role gets `SEAT_MODS_ALLOW`. The operator's
  own top is not launched here — the operator starts it through a `claude-orch` alias that
  sets `orchestrator`. Every site that orders one of these launches names the marking and
  points at step 2, as 0.2.5's guard clauses do: `ossify-execution.md`'s top column;
  `ossify-nested-run.md` §4 (the spine `rotate:` successor, the first close, a
  re-dispatched close, the work-PR session, the record pass); the close and work-PR
  sections of `ossify-pr-briefs.md`; the spine brief's header; `lifecycle.md` step 1b, the
  rotation section (the top's own successor, whose marking is `orchestrator`) and the
  `## My roles` clause; `SKILL.md` §6's lane-driver dispatch, its close/work-PR/record-pass
  transition, and its doctor, non-spine-close and direct-work-item bullets; `briefs.md`'s
  direct-work-item and non-spine-close template headers; `commands/orchestrate.md`'s spine
  start; and `roles.md`'s spine-session sentence, session budget, doctor sentence and
  launch block. The marking is a herdr pane's: a `kind: dsh-spine-driver` seat is a dsh
  session, not a pane, and is never marked (`dsh-driver.md`).
- **The #658 findings deferred from #655 are folded in.** Step 2 now defines `<run dir>` —
  the directory holding the run's `run.json`, outside every worktree; the
  missing-status-line record routes the top's own launches as well as a coordinator's (a
  coordinator records it to the top, the top to the operator) and states its disposition —
  no halt, no re-launch, never silent; the status line is read from the rendered viewport
  (`--source visible`) even where a `banner` seat's model read is the default stream; both
  budget controls' failure messages name the remedy — "lower REF_BUDGET to N" — instead of
  reading as over-budget failures; the root README's "Since 0.2.5" sentence drops the
  launch class that does not exist and adds the close-review writer; and the plugin README
  describes the marking. This is every #658 item: the altitude one is re-homed as #663
  (the marking stays at prose launch sites, so a new site added without a clause still
  passes the suite).
- **Tests and budgets.** The spine-contract suite's value sweep flips from "no
  coordinator-valued guard anywhere" to a whitelist over the exact assigned word — one of
  the five roles, or the shipped `<role>` slot, terminated by end of line, whitespace or
  its closing quote — with seeded controls for each invalid shape (a coordinator noun, a
  trailing comma, semicolon or period, an unbalanced or stray quote, an empty value, `<>`
  and `<close-session>`), for both accepted free roles, for the pane-run recipe's closing
  quote, and for the assignment-less prose control; one pin per coordinator, orchestrator
  and operator-role site sits beside 0.2.5's guard-site pins, and the plugin README's
  pane-scoped opening is pinned. The reference budgets enforce 275 for
  `herdr-mechanics.md` (272 -> 275) and 209 for the ossify references (204 -> 209), each
  raised only to the new minimum; each adjacent control still refuses a file one line over
  the real reference and now names the lowering remedy when it fires.

No runtime library, no ossify contract change. `dsh-driver.md` is untouched: dsh sessions
are not herdr panes and do not load Claude Code mods. seat-mods 0.2.1 carries this
release's docs only — the rollout wording, the "Without an orchestrator plugin" section
and a reviewer `SEAT_MODS_ALLOW` example — no seat-mods code.

**Known limit.** seat-mods 0.1.0 reads `coordinator` and `orchestrator` as invalid roles
and denies every tool call (`seat-mods/hooks/rules.ts:106-110` and `register.ts:50` at tag
`seat-mods-v0.1.0`), so herdr-crew 0.2.7 must be installed together with seat-mods 0.2.0.
paseo-crew, orca-crew and dsh-crew do not mark sessions yet. An operator-declared role
with no `replaces:` is marked a guarded `implementer` and runs under implementer rails.

## 0.2.6

**The context-ceiling hook stands down where `molt` is active.** In a session whose
`molt` marker (`~/.claude/state/molt/active/<session_id>`) is under a day old, the hook
prints nothing: `molt` hands the session off in place at its own threshold, and a second,
conflicting rotation order would leave two tops on one run. Without `molt` installed no
marker exists and nothing changes. A stale marker is ignored, a session id that is not a
plain name is never a marker, and without `jq` the id is read as text. The rotation prose
is unchanged in this release.

## 0.2.5

**The seat-mods guard reaches every launch site (#651, part 5).** The guard rule lived
only in `herdr-mechanics.md`'s launch, step 2, while a coordinator spends the rows it
receives "verbatim" — command, model, effort and delivery carry no guard — so a
replacement PR-fix seat went out unguarded in a live run.

- **Every launch site states the requirement; the mechanics stay in one place.** The
  work-PR brief guards the reviewer and the PR-fix seats (a released reviewer re-created
  for a delta re-review, guarded again), the spine brief and the nested-run round
  procedure guard the item seats and the replacement pair, and the close-review writer
  is dispatched as a guarded seat under role `implementer`. Each site names the role it
  guards and points at `herdr-mechanics.md` step 2; none restates the export. The top's
  own launch reads the same requirement from `lifecycle.md` step 3, and `roles.md`'s
  launch block shows the export line for those roles.
- **The complement is stated where the rule is.** Step 2 binds a coordinator launching
  its own child seats exactly as it binds the top, and every replacement launch; the
  coordinator seats (the spine, close or work-PR session, the doctor session, the lane
  driver) and the orchestrator — a rotation successor included — are never guarded. A
  guarded seat whose status line lacks `seat: <role>` is recorded by its coordinator in
  its report file, never silently ignored.
- **Tests and budgets.** A new section of the spine-contract suite pins every launch
  site's guard clause, the binding, complement and status-line clauses, and sweeps every
  shipped file for a coordinator-valued `SEAT_MODS_ROLE` with two seeded controls; the
  reference budgets enforce 266 for `herdr-mechanics.md` (260 -> 266) and 204 for the
  ossify references (200 -> 204), each with an adjacent control that a file one line
  over the real reference is still refused.

No runtime library, no ossify contract change. `dsh-driver.md` is untouched: dsh sessions
are not herdr panes and do not load Claude Code mods.

## 0.2.4

**The `run.orchestrator` rebind (#556).** dagr routes the operator's `m` composer to
`run.orchestrator`, and nothing rebound it: after a rotation the field still named the
pane the file was created in, so the operator's messages queued at a top that had stood
down.

- **One rule, carried to each successor's own contract.** A session that binds an
  existing `run.json` rewrites `run.orchestrator` to its own `$HERDR_PANE_ID` — dagr's
  stable-agent fallback otherwise — in the same producer loop every other write takes.
  It is stated at `lifecycle.md` step 1 and carried verbatim to the top's rotation, the
  spine brief's continue (`ossify-briefs.md`, the `rotate:` successor), and the work-PR
  brief's continue (`ossify-pr-briefs.md`, the `open:` successor), because a brief is the
  whole contract its reader sees; `ossify-nested-run.md` §4 says the new spine session
  rebinds. The contracts that build a work-PR dispatch — `lifecycle.md` step 1b and its
  rotation paragraph, `ossify-nested-run.md` §4 and `ossify-execution.md`'s top column —
  carry the predecessor's `RUN_JSON` path into a resumed dispatch, so the successor's
  continue branch and its rebind are reachable instead of a second run file being minted.
- **One writer, one router.** The handoff is the predecessor's last write; from the
  handoff on the predecessor writes nothing to the run file and takes no dispatch action,
  and the successor's rebind is its first write — the rebind does not wait on the
  stand-down, which kills waits and writes nothing. An operator message dagr queued at the
  old pane in the interval is a wake that fires anyway: read and handed to the successor,
  never acted on. The handoffs record the pane the block names at writing — lifecycle
  step 13, the rotation handoff, the spine `rotate:` return, and the work-PR `open:`
  return.
- **The #556 gap sentence is gone** from `lifecycle.md`; the plugin `README.md`'s binding
  sentence carries the rebind.
- **Tests and budgets.** `tests/test-ossify-spine-contract.sh` pins the carried sentence
  at all three sites (flat-counted), the four handoff records, the four dispatch carriers
  of a resumed work-PR `RUN_JSON`, and the gap sentence's absence as a flat, plugin-wide
  sweep; every pin was mutation-tested with a semantic mutation that applies and runs. The
  three budgeted files land at the 200-line gate (`ossify-briefs.md` 200,
  `ossify-pr-briefs.md` 200, `ossify-nested-run.md` 200) by trading lines inside each file,
  no raise. No new eval surface and no rubric criterion: the rebind sequence is checked by
  the recorded-claims walkthrough in the verification dispatch, and no eval result covers
  it.

## 0.2.3

**The worker ping and the heartbeat backstop (#640).** The orchestrator's wake was
pull-only: a wait armed on the wrong report path, or one that died, failed silently, and a
worker had no sanctioned way to say it had finished.

- **The ping.** Every report-producing brief carries `NOTIFY_PANE` — the dispatcher's own
  pane id only when herdr detects it and the seat shares its server, otherwise the sentinel
  `none` — and after every atomic report rename the worker sends one literal
  `REPORT READY: <task> <kind> <path>` line there: single-quoted as one argument so `$` and
  backticks stay data, skipped when the target is `none`, one send, no `--wait`, no retry, and
  a failed send leaves the report intact. A coordinator fills its children's slot with its own
  pane id; an operator's `brief:` gets the same envelope in the dispatched copy, never in the
  stored file. A parent herdr cannot target keeps the report-file wait and the heartbeat, no
  push promised.
- **Consumption.** One generation rule (hash or identity) comes first on any signal: the
  typed wake treats a byte-identical atomic replacement as new, exactly as the ping and the
  doorbell do; a new generation is read, noted, acted on once by kind, and retires that
  dispatch's armed wait and companion; an already-consumed one is not read, not acted on, and
  retires nothing, so a stale same-path ping never cancels the current phase's wait. A ping
  naming a path other than the briefed report path is surfaced, never read. Deduplication
  governs the report and its waits alone: a live dialog and a heartbeat tick are still handled.
- **The heartbeat.** One bounded background timer of about 15 minutes per session holding any
  live herdr-pane dispatch — a typed-wait seat included, not only a report-file wait; a dsh
  session, which has no pane or `REPORT_PATH`, keeps `dsh-driver.md`'s own route — re-armed per
  tick, not a completion wait and never a re-entry. Each tick: the
  generation check, then at most one health check per live seat; `working` asks nothing,
  `blocked` takes the dialog procedure, and idle/done with no report, `unknown` or an
  unreadable seat is surfaced once per dispatch as observed state and uncertainty — never as
  a failed task and never as a retry. Killed when the last dispatch settles, at teardown and
  at a rotation's stand-down, where the successor arms a fresh one; a host with no background
  timer keeps the wait/ping fallback, never a rolling foreground loop.
- **Reconciled prose.** `SKILL.md`'s "no keepalive" and the loop-of-waits rule now carve the
  ping and the heartbeat out explicitly; `lifecycle.md` step 5 arms and kills the heartbeat
  and step 3 fills `NOTIFY_PANE`; rotation hands the ping target over (a retained worker
  keeps the predecessor's pane until the successor's next message carries its own, its
  heartbeat covering the interval); `roles.md` and `ossify-execution.md` prefer a seat herdr
  detects where the project file offers a choice, as prose over any profile field.
- **Tests and budget.** The mechanical suites gained the `NOTIFY_PANE` slot counts and the
  narrow command-policy carve-out — the ping is the one herdr command a brief states, with
  an adjacent control proving any other agent command still fails. `herdr-mechanics.md`'s
  ceiling rose 245 → 260 for the two new mechanics, traded back twelve lines elsewhere. No
  new eval surface: the semantics are walked as recorded claims in the ordinary verifier
  dispatch.

## 0.2.2

- **Guarded seats** (`references/herdr-mechanics.md`, the launch's step 2): before an implementer,
  verifier or reviewer seat's command, its pane exports `SEAT_MODS_ROLE` and `SEAT_MODS_ALLOW` (its
  report directory and its own scratch directory, `<run dir>/scratch/<role>-<n>`, with no `:` or
  space) for the seat-mods plugin — `herdr worktree create` takes no `--env`. Coordinator
  seats and the orchestrator never get them. A guarded seat whose status line lacks `seat: <role>`
  runs unguarded, and the run record says so. An ossify implementer's list adds its handoff's
  directory, where it writes `report.md`. Neither variable ever goes in `settings.json`, a shell
  profile or a `command:` line.
- **Briefs that use scratch** (`briefs.md`: planned and fast implementer, fix round, verifier;
  `ossify-briefs.md`: item verifier) name that scratch directory as `SCRATCH_DIR`; commit-message
  files for `git commit -F` go there, and the implementer `NEVER` clauses list it beside
  `REPORT_PATH` as an exception outside the worktree. It replaces the session scratchpad, which the
  seat-mods guard cannot locate.

## 0.2.1

- **`references/dsh-driver.md` §3** recommends `.dsh-crew/roles.md`'s verifier as `driver`:
  since dsh-crew 0.3.1 the verifier always runs the driver's own route and effort. The
  implementer route and effort still come from the allow-list.
- **`references/dsh-driver.md` §5:** before each spawn the top diffs the installed
  `crew-spine` preset against the plugin's and halts on a difference, since a stale preset's
  persona cannot stop itself before run-spine's first mutation. A stop from the driver's
  pre-mutation step 0 checks is retried by sending the same first message to a fresh session,
  never by `continue` to the stopped one.

## 0.2.0

**The dsh spine driver.** A spine's spine and close seats can be a DeepSeek Harness (dsh)
session instead of a launched command. `references/dsh-driver.md` is the whole contract,
and dsh-crew 0.3.0 supplies the session, its skills and the presets.

- **The `kind: dsh-spine-driver` agent entry** has no `command:`: `preset: crew-spine`,
  a `route:` and `effort:` from `~/.dsh/settings.yaml`, the model read from the session's
  transcript, and the brief sent as one steered message through dsh-crew's `dsh-session`
  skill. Every surface the top reads before that file admits the kind: `config.md`'s
  agent entries and capability table, `lifecycle.md` step 1b, the delegation floor's
  actions and reads, `ossify-nested-run.md` §4, `ossify-execution.md` §3 and §7, and the
  command.
- **`.dsh-crew/roles.md` in place of item rows.** At spine planning the top recommends
  that file's implementer, verifier and reviewer rows in the one approval phase and
  writes it; the items get no per-item seats from this plugin.
- **dsh-crew's item procedure.** A dsh-driven spine runs its items through
  `dsh-executor`: no worker-authored plan gate, one automatic correction and then a stop
  for the operator, and no nested-depth ask.
- **Every close in a fresh dsh session**, never the spine driver's, so dsh-crew's
  reviewer pass runs at close review and a close-sent correction has its executor.
- **The top watches the transcript**: the driver's `ask_user_question` goes to the
  operator in the browser and the top relays its text; a token-free wait ends on a turn
  end, a pending question or `context_ceiling`; only a `completed` turn is a completion;
  rotation is a steered hand-off.
- **Parity pin.** `tests/test-herdr-crew-parity.sh` holds `references/dsh-driver.md`
  byte-identical to orca-crew's apart from the plugin name.
- No eval fixture is added; the dsh lane is verified by a real spine run.

## 0.1.1

The **0.1.0 port, corrected against its own first pilot**. 0.1.0 was written from
`orca-crew`'s shape; 0.1.1 is what one real run measured that shape to be wrong
about — the worktree launch, the detection figure, the workspace a teardown
leaves — plus the defects the port's own generator kept producing, and the gates
that hold the corrections. No new surface, no runtime library, and no change to
any ossify contract; `orca-crew` is unmodified by this release too.

- **A brief is a whole contract** (#539). The port's defect generator was a
  template defined as "take template X and replace lines Y and Z": three times
  that composition borrowed the wrong context and shipped a brief ordering a seat
  to do the wrong thing. `briefs.md`'s header now states the rule and carries the
  dispatch matrix that makes it checkable — which coordinator constructs which
  child briefs, and what its dispatch must carry verbatim — and four dedicated
  templates replace what composition remained: lane driver, doctor dispatch,
  direct work-item and non-spine close, each complete on its own. The fix-round
  template stands alone too, carrying its own seat lines, TASK, completion body and
  NEVER line rather than the fast-implementer brief with lines replaced. The
  non-spine close's DONE carries three results, the halt among them —
  `halted: <step> — <evidence>` and, on its own line, what it had already opened —
  because a close can halt after opening a PR in one repo, and hiding those PRs
  strands them. `SKILL.md`'s brief sections name the set and point at the
  templates instead of assembling one from another.
- **The rules a seat's location will not load are a slot** (#537). Every dispatched
  template carries `RULES THAT DO NOT LOAD HERE`, filled verbatim or `none`: a seat
  placed inside a canonical worktree — the reviewer, the verifier, the item
  verifier — gets the project's rules pasted into its brief, because a brief is the
  whole contract a worker ever sees and its own project's rules do not load where
  it sits.
- **The report file is replaced atomically, in every slot** (#540). Opening the
  path truncates it before the content lands, and the orchestrator's doorbell
  polls the file's hash, so an in-place write can wake it on half a report. The
  shape is stated in `briefs.md`'s header and in all fifteen `REPORT_PATH=` slot
  lines across the four brief files — a temp file in the same directory renamed
  over the path, never in pieces, and a plan, a question and a final report alike.
  No tool here documents an atomic rename, so the requirement is the writer's.
- **The pilot's three corrections** (#542, #543, #544). `herdr worktree create`'s
  `--label` names the worktree's **workspace**, never the seat's tab, so a worktree
  seat needs the `tab rename` the launch's step 1 prescribes. That call opens
  **two** workspaces — the worktree's own and the **source repository's** checkout
  — while `worktree remove` releases only the worktree's, so teardown names the
  source-repo workspace the run did not create and the operator's to close, the
  canonical checkout in the dual-repo case. And detection is two events, not one:
  a record at about 0.6 s still carrying `agent_status: unknown`, and a settled
  state at about 4 s — so the first ask chooses only the readiness wait, while the
  **send's route**, and the completion wait with it, comes from a second ask made
  after the model read.
- **The run's seams** (#515, #516, #517, #519, #522). The top's rotation launches
  its successor through the seat launch every other seat gets — the readiness path,
  the model read against the profile the handoff recorded, then the second
  detection ask — and sends its resume on the route that ask fixes, so a successor
  is never sent its resume before its TUI accepts input. A later launch whose
  `herdr workspace list` no longer shows the run's workspace creates it again first
  and binds the id that call returns; the handoff records a machine label beside
  every seat not on this machine, and every later operation on that pane goes
  through it, because pane ids are server-scoped. The `/context` probe at a task
  boundary is conditioned on the seat being able to answer it — the profile's
  `can: slash-commands` **and** the route the send takes — and a seat failing
  either is never sent the probe: it rotates at its item boundary on the run's own
  record instead. `mv` joins the command's allowlist, and dagr's producer contract
  is stated as the rule for every write of `run.json`, not only its creation. An
  orchestrator started outside a herdr pane is refused: with no `HERDR_PANE_ID` the
  hook is inert, and a rotation later needs a `HERDR_WORKSPACE_ID` that is absent
  too.
- **The context-ceiling hook reports what it cannot read** (#516, #519, #527). Four
  defects, all against the header's own promise that a figure which cannot be read
  is reported as unavailable, never guessed: a transcript that exists but cannot be
  read says so now, instead of producing no notice at all; a `usage` object missing
  any of its three counters no longer reads as a figure of zero, which is a figure
  the ceiling check believes; a machine with no `jq` recognises the wake path as
  well as the prompt, so a coordinator woken by a background wait is still told;
  and an input `jq` cannot parse attributes its notice to the event the raw input
  names. A `tail` that cannot run is the same class and takes the same path: its
  status is read under `pipefail`, so it reports that the transcript's tail could
  not be read rather than "none". The two separator spellings a JSON writer produces
  — compact, and one space after the colon — are read on the raw paths, with a third,
  space-on-both-sides form kept as a belt alternative; what stays outside them is
  stated where the boundary is drawn.
- **The first-run halt shows an entry to copy** (#518). Neither seat file exists on
  a fresh machine, so the halt is right — but the section named the file to add and
  never showed one complete, with the model id the seat must show a slot in all
  three illustrative entries. It now names the remedy and follows it with one
  worked machine entry, every field filled and every value obviously illustrative.
  An operator-defined role's `brief:` gains its obligation beside that: the file it
  names must carry a report envelope — a `REPORT_PATH` and a completion shape —
  checked at approval with `can:` and the block's other fields, because without one
  the role cannot return.
- **The triggers are herdr-specific** (#535). The frontmatter description claimed
  the same generic phrases `orca-crew`'s does, so while both are installed a
  generic request could select the Orca playbook mid-migration. It now triggers on
  "the herdr orchestrator session", "a herdr worker seat", "the herdr crew",
  "dispatch to a herdr session" and "execution assignments for a spine in herdr",
  and on `/herdr-crew:orchestrate`. The generic phrases return when `orca-crew`
  retires.
- **The gates the review rounds showed were missing.** The rounds reverted this
  release's clauses in turn, and every one whose revert left all six suites green is
  now pinned: the report slots by count in all four brief files, the probe's two
  conditions, the workspace recreation, both machine-label clauses, the nested
  run's identity anchor — with an absence pin that keeps #552's false "close guard
  fingerprints" claim from walking back in — and the eval fixtures' frontmatter,
  which nothing parsed before. The personal-name sweep reads each file as one line,
  because a name split by a markdown wrap was structurally invisible to a per-line
  count. Two repo-root parity pins hold this plugin's copies of `orca-crew`'s
  fidelity pins and ossify's eval aggregator to their sources while `orca-crew`
  stays installed for the migration.

## 0.1.0

The **port of the orchestrator/worker session model onto herdr**. `herdr-crew` is
`orca-crew` 0.7.0's crew on a different runtime: same roles, same briefs, same
thirteen-step run, same ossify seam, and no change to any ossify contract.
`orca-crew` is unmodified by this release and stays installed until the fleet has
moved; migration is a copy of the two configuration files to the paths below, and
nothing here reads the old ones.

- **Readiness is derived, never declared.** herdr answers live whether it detects
  the pane (`herdr agent list`): a detected seat waits on a typed agent state, a
  seat it does not (`mcode-*`, which has no detection manifest) waits on a screen
  pattern. No configuration field states the path, so a detection manifest landing
  later upgrades a seat with no edit anywhere.
- **Placement is one tab per seat and one full-size pane per tab** — never `pane
  split`. herdr's own guide defaults "Start and coordinate an agent" to a sibling
  split in the current tab; herdr-crew overrides it, because panes sharing a tab
  make a multi-agent screen unreadable. A run of five seats is five readable tabs.
- **Completion is a report file**, at the `REPORT_PATH=` the seat's brief names; the
  typed state is only the doorbell, because herdr's `done` carries no body and a
  hash tells a new report from an old one at the same path. A coordinator seat — a
  spine session, a work-PR session, or a `run-spine` lane driver whose subagents run
  in the background — is waited on through its report file, not a typed state it
  would read as ready too soon.
- **The bounded-wait narrowing.** `orca terminal wait --for tui-idle` becomes one
  `herdr agent wait <pane> --until done --until idle --until blocked --timeout <ms>`
  — run in the background where the host has a background call, in the foreground
  inside that host's cap where it does not: a single call that returns once, with
  `blocked` in the set so a dialog wakes rather than sleeping to the timeout. A round
  of N parallel items is N such waits, one per pane — never a loop of waits, and
  never a re-entry after an empty timeout.
- **The run's state lives in a dagr `run.json`** that the plugin's prose owns and no
  binary writes.
- **The configuration paths move and the format does not.** The machine file is
  `~/.claude/herdr-crew/agents.md` and the project file is `.herdr-crew/roles.md`;
  every field, every role key and every precedence rule is as it was, and both are
  still read as prose.
- **One fail-open hook, and no runtime library.** `hooks-handlers/context-ceiling.sh`,
  gated on `HERDR_PANE_ID` and inert outside a herdr pane, tells a seat its own context
  figure once it passes the `context_ceiling` setting (default 500000 tokens): finish the
  unit in hand and start no new one, and a coordinator seat rotates at its next boundary.
  A run executes no `lib/`, no state directory and no parser; that
  hook is the only deterministic code on a user's path. The suites and the eval
  harness under `tests/` are build-and-test tooling, never run by the plugin.
- **The ossify seam ports unchanged.** The spine execution-assignment phase, the
  approved SEATS block injected into one spine session's brief, the nested
  `run.json`, the three coordinator seats and the close-review writer outside the
  per-item budget, and the fixed procedures are the contract they were; the lane's
  item panes are herdr tabs.

### The verb map

| orca-crew 0.7.0 | herdr-crew |
|---|---|
| `orca terminal create --worktree <sel> --command "<cmd>"` | the run's `herdr workspace create --cwd <path> --label "run: <objective>"` once — its own tab, relabelled with `herdr tab rename`, is the first seat's; each later seat `herdr tab create --workspace <id> --cwd <path> --label "seat: <role> (<agent>)"`; a worktree seat's `herdr worktree create` replaces the tab step (a workspace of its own); then `herdr pane run <pane> "<command:>"`. One tab per seat, never `pane split` |
| `orca terminal wait --for tui-idle` | `herdr agent wait <pane> --until done --until idle --until blocked --timeout <ms>` — every detected seat's readiness, and completion for a detected seat that is not a coordinator. One call that returns once, run in the background where the host has one and in the foreground inside that host's cap where it does not; the three settled states are written out rather than inherited, and `blocked` is in the set so a dialog wakes instead of sleeping to the timeout |
| (no equivalent) | `herdr pane wait-output <pane> --match '<expected_model:>' --timeout <ms>` — an undetected seat's readiness, read from the screen when `model_shows: screen`; its completion doorbell is its report file |
| `orca terminal read` | `herdr pane read <pane>` — serves both `model_shows: banner` and `screen` |
| `orca terminal send` | detected: `herdr agent prompt <pane> "<text>"`, the `/context` send at a task boundary plain and with no `--wait`, because a local slash command settles without a turn; undetected: the message written to a file the seat can read, then a one-line pointer via `herdr pane run <pane> "<line>"` |
| `orca terminal close` | a tab seat: `herdr pane close <pane>`; a worktree seat: `herdr worktree remove --workspace <id>`, never a pane close; the run's own workspace closes last with `herdr workspace close <id>` |
| `orca terminal list` | `herdr pane list` / `herdr agent list`, which is also the readiness discriminator |
| `orca status --json` | `herdr status` |
| `orchestration dispatch --inject` | detected: `herdr agent prompt <pane> "<brief>" --wait --until working --until blocked --timeout <ms>`, that `--wait` being the turn-start check; undetected: the brief as a file, then a one-line pointer via `herdr pane run`; `brief_delivery: file` writes the brief and prompts one line pointing at it |
| `orchestration ask` / `reply` | a worker writes its question into its report file and waits; the orchestrator answers with the seat's next message — herdr has no worker-to-orchestrator channel |
| `orchestration task-list` | the run's dagr `run.json`; `dagr check --strict` lints it |
| `orchestration run-use` | naming the run's `run.json` path |
| `worker-start` | the seat launch (row 1) |
| `worker-done` | the seat's **report file**; the doorbell is the typed wait for a detected seat that is not a coordinator, and the report-file wait for an undetected or coordinator seat |
| `worker-read` | `herdr pane read`, only on a `blocked` wake, a missing or malformed report, a timeout's checkpoint, or the false wake's own read |
| `worker-release` | as `orca terminal close` above |
| `orca skills get orchestration` | `herdr --skill` |
| `ORCA_TERMINAL_HANDLE` | `HERDR_PANE_ID` — the hook gate only |
| `~/.claude/orca-crew/agents.md` | `~/.claude/herdr-crew/agents.md` |
| `.orca-crew/roles.md` | `.herdr-crew/roles.md` |

`skills/orchestrate/references/herdr-mechanics.md` is the authority for every mechanic
above and wins on any disagreement with this table.
