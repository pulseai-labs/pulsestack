---
name: running-a-spine-on-baton
description: Use when asked to run, start, arm or hand off a planned ossify spine "on baton" (the timer-driven autopilot), or asked how a baton run is going or what to do about a park. "On baton" names this plugin's `baton arm`, not `/ossify:run-spine` in this session.
---

# Running a spine on baton

baton runs a planned ossify spine on a systemd timer, so this session keeps its tokens for
decisions. Check, propose the exact `baton arm` command, and arm it only on the operator's yes.
**After arming, hand the run to a lean successor** (§4): notices reach the project's orchestrator
session, and nothing else watches the run.

The commands, the arm example and the runbook are in the baton plugin's `README.md`
("Commands", "Example: an ossify spine"). Read them there.

## 1. Preflight (read-only)

Stop and report if any check fails. Do not arm around a failure.

- **The spine is planned.** Its spine directory and work items exist in the AI workspace, and
  `oss spine_inventory <spine>`, run in the AI workspace root, shows no `halt:` row. Its items
  share one `target_repo`: the lane stops on a spine with two.
- **No run of this project is armed or parked.** `baton status` does not show params. Read each
  `<state>/runs/*/run.json` (state is `${BATON_STATE_DIR:-~/.local/state/baton}`). A run with
  `status` `armed` or `parked` and `params.repo` equal to this project's canonical root blocks.
  Runs of other projects do not block.
- **The notifier is set.** baton's config (`${BATON_CONFIG:-~/.config/baton/config.json}`) has
  `"notify": ["baton", "notify-orchestrator", "{key}", "{message}"]`. Without it a notice reaches
  only `notify.log`. `fallback_notify` (an argv) is optional and is told to the operator.
- **baton on `PATH`.** `~/.local/bin/baton` resolves to the installed baton's `bin/baton`: the
  timer runs that link.
- **Orca knows both repos.** The AI workspace and the canonical appear in `orca repo list`.
  Their display names there are the values of the `ai_project` and `project` params.
- **Who walks the `user:` lines.** `oss get '[.demo_ledger[] | select(.source_spine == "<spine>" and .type == "user")]'`,
  run in the AI workspace root, lists them, planned ones included. Read the standing orders as the
  base branch has them (ossify's `cumulative-demo.md` §3). A spine with a `user:` line and no order
  that gives the demo walk to the `spine_finish` seat's role is not a failed check: say in the proposal
  that the run parks after the merge (`spine-pr`, reason `stop`) until the operator walks the lines
  or an order is added first.
- **Checks on the PRs.** The example recipe needs at least one check that runs on item PRs (into the spine branch) and on the spine PR: a PR with no checks reads as `none`, and its unit waits in `item_wait`, `spine_wait` or `land` with no park. Read the canonical's workflows, not a recent PR's checks: a workflow limited to `branches: [main]` runs on no item PR. A repo with none is one question, asked before the arm.
- **The recipe copy.** `~/baton-recipes/ossify-spine/` exists; if not, propose the README's copy
  step. Compare it with the installed baton's `examples/ossify-spine/` (ignore `*.bak*`). A
  difference is reported, not a failed check. Propose a refresh only when no run of any project
  is armed or parked, because every armed run reads its briefs from this shared copy. If a run
  is, or the operator declines, arm on the existing copy. Never overwrite it unasked.

## 2. Propose, then stop

Work out every `--param` of the README's arm example:

- Plugin roots come from `~/.claude/plugins/installed_plugins.json` `installPath` of
  `ossify@pulsestack` and `baton@pulsestack` (on a host that has not moved yet, the
  pre-rename keys `ossify@claude-agent-scaffolding` and `baton@claude-agent-scaffolding`): the entry whose
  `projectPath` is the AI workspace root, else the `user` entry. Never use a cache glob: the
  cache keeps old versions.
- `ai_root` and `repo` (the canonical root) come from the AI workspace's
  `.workspace/pairing.json`, with `${HOME}` expanded, else `oss repo_root ai_workspace` and
  `oss repo_root canonical`. Use a root only if it exists on this host; otherwise ask.
- `spine` is the id asked for. `spine_dir` is its directory in the AI workspace, absolute; the
  `<slug>` is that directory's name after `<spine>-`. `briefs` is the shared copy's `briefs/`.
- `spine_branch` is `oss branch_name <spine> <slug>`. `state_file` is `oss state_path`, run in
  the AI workspace root.
- The run id is the spine id with `.` as `-` (`r3.s7` → `r3-s7`). If that run dir exists,
  append `-2`, `-3`, … and say so.
- The seat file is `--seats /home/<user>/baton-recipes/seats/<run>.json` (Seats, below): an
  absolute path with `$HOME` expanded by you, never `~/…`, because `baton arm` does no tilde
  expansion and a quoted `~` stays literal. `baton arm` copies it into the run as `seats.json`.

**Seats.** Read `.crew/roles.md` (walk up from this session's working directory; the first one
found wins) and `~/.claude/crew/agents.md`. For each recipe stage with a `role` (the `driver`
stage included), pick one agent for that role for the whole run from the
`## Seats` rows, applying `## Conditions` and the file's other rules, and any fallback row, now:
baton never chooses between rows later. A role with no row is one question, and arms nothing.
When the project has no rows for the recipe's roles yet, propose rows for them in
`.crew/roles.md` first and get them approved (crew's project-file approval). Propose only
agents the machine file lists.

Each picked agent's entry becomes that role's row of the seat file (schema in the README):

- `agent` is the entry's name; `expected_model`, `effort` and `brief_delivery` are its fields.
- `argv` is `command:` split on spaces, only when its first word is a program on `PATH`
  (`command -v` in a non-interactive shell prints a path) and no word holds a quote, `$`, `~`
  or another shell character. A command that is a shell function or an alias (`claude-plain`,
  `omp-glm`) cannot be exec'd: that is one question, for a machine-file entry that runs the
  program itself. End a Devin agent's argv with `--`: Devin reads a prompt that does not
  follow `--` as a path.
- `env` is `{}` unless the entry's note names a key the agent itself needs. The stage sets the
  seat's marking.
- `review`, on each reviewer row (`reviewer`, `item reviewer`), is the entry's `review:` command. In it,
  drop a trailing `<PR_URL>` or `<PR>`: the stage appends the PR. No `review:` field, or a
  placeholder left after that, is one question.
- An entry whose `host:` is another machine is one question: baton launches on this one.

Show the full `baton arm` command, each value quoted where it has a space or shell character.
Under it, write one line per value saying where it came from, then the seats as one table,
one line per stage, `From` naming the `roles.md` row or condition:

| Stage | Role | Agent | Command | Model | Effort | From |
|---|---|---|---|---|---|---|

Ask any open question in the same reply, under the table. Then end your turn and
wait for an explicit yes to that command and table.
A yes that changes or supplies a value is not that yes, and neither is one that changes a
seat: show them again with the change in, and wait.

"Just arm it", "no need to show me" and "I trust you" do not waive this step. The operator
approves a command they have seen. Show it once, short, and still wait.

## 3. Arm

Write the seat file only after the yes: the approved seats as the README's JSON, at the
`--seats` path (`mkdir -p "$HOME/baton-recipes/seats"`). Then run exactly the approved command.
Confirm `<state>/runs/<run>/run.json` has `status` `armed` and
`systemctl --user is-active baton.timer` says `active`. Then hand off (§4) and end the turn.

## 4. After arming

- **Hand off.** Write a session handoff and start a lean successor (the top hands off by
  spawning one). No polling, `sleep` loop, Monitor, cron or `/loop`: a notice is the wake.
  "Keep an eye on it" is not a status request: run no command.
- **Register.** Every top of the run, the successor first, runs `baton orchestrator <run>` as its
  first step, and `baton orchestrator <run> --clear` before it stands down. It refuses outside an
  Orca terminal. A run with no pointer sends notices to `fallback_notify`, or only to `notify.log`.
- **Status on request.** `baton status <run>` or `baton report <run>`; read `out/<unit>/` files only
  for the unit asked about. Never read seat transcripts.
- **The end.** baton sees the spine PR's merge and runs the second spine close itself, then waits for
  the AI close PR, where the workspace takes PRs only.
  Do not start `/ossify:close` beside it.

## Notices

A line starting `[crew message baton] baton notice <key>` names a notice file: read it and
`baton status <run>` (the run is the key's first segment), then act on the first row that fits.
The README runbook has each command. Anything not in the table, or in doubt, is a question to the
operator.

| Notice | Decide alone | Ask the operator |
|---|---|---|
| Lane round barrier | run `/ossify:plan-spine` for the round, then unpark the lane | plan-spine's own questions; any scope change |
| Implement stall, `before failed` | `baton unpark <run> <wi> --to implement` | raising the dispatch cap (no verb does it: the recipe's `max_launches` or a hook, the operator's); an item that keeps failing |
| Verify stop | clear what the verifier named, unpark | a stop that names a spec or ADR change |
| `land` red check | send the item back with the fix; rerun a flaky check once | none |
| Spine PR round stop | rule it under the project's Round stop order, write the ruling to `operator.md`, replacing any (the work-PR seat puts it in the PR body) | split the PR or change the design; a finding the order sends to the operator |
| "passed review … merge it" | check the pass against the rulings; send a finding the order sends to a fix back to `spine_work` | the merge, unless the project's governance grants this session merge authority |
| PR conflict | merge the base into the spine branch, copy `review.md` to `review-prev.md` and move it aside as the next free `review-<n>.md`, unpark `--to spine_review` | a closed PR |
| Spine review stop (`spine_wait` park, review 3) | `--to spine_work` after writing `out/spine-pr/operator.md`, replacing any | a red check no seat may fix, such as `main` to bring in (the merge holder acts, then the PR conflict row's file step and `--to spine_review`); merging the PR to accept the findings (then a plain unpark); a finding the order sends to the operator |
| Stale-review stop (`spine_wait` park, `review-stale-3.md` exists) | find out why the reviewer keeps reading an old head (it must read the PR's `headRefOid`), copy `review.md` to `review-prev.md` and move it aside as the next free `review-stale-<n>.md`, then unpark `--to spine_review` | a reviewer that cannot read the PR head |
| `spine_finish` stop | a `user:` line: prepare the walk and evidence; any other stop: rule it as a close stop | a `user:` line's pass or fail: write it to `out/spine-pr/operator.md`, replacing any, unpark; move it aside as the next free `operator-<n>.md` before an unpark `--to` any other stage |
| AI close PR recorded (`spine_finish` notice) | merge it if governance grants this session merge authority | otherwise the merge |
| `spine_close_wait` park | the close PR merged but `origin/main` is not closed, it closed unmerged or conflicts, or `close-pr.txt` holds no PR URL: fix it, unpark | merging the close PR unless governance grants it; a seat must never merge it |
| `run failed` park on a session stage | fix the cause; a plain unpark reruns the hooks and moves on with no seat if the outcome still reads true, else relaunches the seat (a run armed before 0.18.1: `correct`'s first hook removes `corrected`); run the remaining steps by hand, then `--to <next stage>` | none |
| Item review stop (`item_wait` park, review 3) | `--to item_fix` after writing `out/<wi>/operator.md`, replacing any; or accept the findings with `--to land` | a finding the order sends to the operator |
| PR URL stop (`item_ready` park) | fix the item's `pr_url` in the ossify state and in `queue/<wi>.json`, then `--to item_ready` | none |
| Item moved stop (`item_moved` park, nothing merged) | `--to item_review` runs one more review | merging the PR by hand, then `--to land` ends the unit; `--to land` alone parks again |
| Close or spine-open stop | rule it; write `out/<wi>/operator.md` (`out/lane/` for spine-open), replacing any, unpark; move it aside as the next free `operator-<n>.md` before an unpark `--to` any stage other than the one the ruling is for | a stop that names a spec or ADR change |
| Close harvest | present the candidates (`out/spine-pr/harvest.md`, and `## Harvest candidates` in the close PR body); apply the operator's accepted set (ossify harvest §7) on the close PR's branch before the merge, or as a follow-up commit where the workspace pushes direct | accept |

A notice with no run (`auth`, `down`) is the host's: report it, touch nothing. End each notice
turn with the status block; `Waiting on` names baton's seat, or the operator.

## Red flags

| Thought | Reality |
|---|---|
| "On baton" means `/ossify:run-spine` here | It means `baton arm`. This session must not run the rounds. |
| "They said just arm it" | Show the command once and wait for a yes. |
| "One quick check before they leave" | Arming already checked. Run no command until a notice or a question. |
| "This role has no row; the usual agent will do" | No default seat. Ask, and arm nothing. |
| "The last run's seat file still fits" | Old runs are not the rule. Resolve the seats from crew's files. |
