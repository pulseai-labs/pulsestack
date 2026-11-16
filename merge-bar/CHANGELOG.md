# Changelog

All notable changes to the `merge-bar` plugin.

## 0.11.0

**Prose and contract checks (#1012, #1007, #1211, #1038 item 2).**

- `running-a-retro`: selects debt by PR suffix, skips repository-free report headers, reads report-shaped comments once, and distinguishes full coverage, partial entries (a judgment class with a searchable part stays an entry), existing checks absent from CI, and cleared candidates. Log matching uses class meaning, edited wording and round-qualified sources. Operator-free runs, refused writes, undetermined windows, temp-file cleanup and silence are explicit; the command permits directory listing.
- `working-a-pr` §5: both ledgers use the routed workspace bank, PR references distinguish noncanonical repos, dates are UTC merge dates, every non-blocking disposition is recorded, and a missing `Bar:` line supplies no ruling.
- A changed Merge bar or Claim resets the next review to round 1 on the whole PR; the actor announces it and the reviewer names why in the existing header.
- Codex's interface descriptions name PR review and retro. `mb`'s header names skill-first question 2; no executable behavior changes. Prose pins cover the new contracts and byte parity of the shipped skill-first quotation.

## 0.10.3

**Prose, tests and evals only (#1071, the non-blocking classes of #1070).** #1071's C4, ossify's "do not restructure twice" in `work-pr/references/loop.md`, is ossify's and goes to ossify 1.36.8 (#1073's patch); the CodeRabbit note on the pin file's maintainability is not addressed.

- `reviewing-a-pr`: `run` is the one input that is not a slash-command flag; the write rule reads the same in the description, the opening and the Limits (the reviewer writes the report, and with `run` each axis writes only in its own subdirectory); `run` names an existing directory; the extract is `d=$(mktemp -d "<run>/axis.XXXXXX") && git -C <checkout> archive HEAD | tar -x -C "$d"`, so each axis starts empty and the command works from outside the checkout; the skill limits only the reviewer's own writes, so the launcher must enforce the write boundary as well as any network limit.
- `/merge-bar:review-pr` says a `--run` in its arguments is ignored, never run, and the report's `Run:` header says so.
- `working-a-pr`: the round stop says the operator chooses at every stop a standing order does not settle, and no count limits how often the design changes.
- Corrects 0.10.1: its `test-prose-pins.sh` pinned only "the launcher must enforce", not the trust sentence it claimed. It now pins the trust sentence (trusted code, not a fork or unknown author, the launcher enforcing the write boundary and any network limit), "outside any git repository", the extract command, the write-boundary sentence, the `run` flag exception, the command's `--run` line and the operator-chooses clause.
- Evals: fixtures W17 (an `Extends:` chain makes the stop recommend changing the design) and R13 (`run`: a `Run:` line, nothing written outside the run directory); W4's stale result is regenerated.
- README's runner list says it runs the prose pins as well as the fidelity pins.

## 0.10.2

The marketplace is renamed `pulsestack`; the OMP bin-path module it ships (`omp/bin-path.ts`, VERSION 2) reads installs under the new marketplace name `pulsestack` and, for one release, under the old `claude-agent-scaffolding`; an entry under the new name wins. The install key is `merge-bar@pulsestack`. No other change.

## 0.10.1

**Prose and tests only (#1061, follow-up to #1060).**

- `reviewing-a-pr`: the description and the two write rules name the `run` carve-out; naming `run` is the launcher's statement that the PR's code and Evidence command are trusted, and the launcher, not the skill, must enforce any network limit; the `run` directory must be outside any git repository; the extract's subdirectory is made with `mkdir -p` first; each axis returns what it ran, so the `Run:` header line has a source.
- `/merge-bar:review-pr` stays reports-only and takes no `run`; the command and the README say so, and that a launcher invoking the skill may name a scratch directory.
- Eval fixture W4 expects three options at the round-3 stop. Its committed result predates that and is stale until the fixture is re-run.
- New `tests/test-prose-pins.sh` pins `working-a-pr`'s "change the design" option and the `run` trust and network sentence. ossify 1.36.5 aligns its bundled loop's second exit.

## 0.10.0

**Prose only (#1047, #1055).**

- `working-a-pr`'s round stop offers a third option, **change the design**, recommended when a blocking class, followed back through the posted reports' `Extends:` lines, makes a chain of two or more.
- `reviewing-a-pr` takes an optional `run: <scratch dir>` input. Without it the reviewer reads, as before. With it, the reviewer may run the PR's test command, reproduce a finding or mutate a copy, inside that directory on a `git archive` extract of the checkout (no `.git`), with `TMPDIR` and `HOME` set there, and no cold build. The report gains a `Run:` header line and optional `Reproduced:` and, in round 2+, `Extends: C<n>` lines.
- ossify 1.36.2 aligns its bundled loop's second exit.

## 0.9.1

**Text only (#755).** `working-a-pr` says where the `gh --repo <owner>/<repo>` name comes from under `--repo-root`: that checkout's own `origin` (`gh repo view`), never a folder name. No code.

## 0.9.0

`mb`: the PR loop's `gh` mechanics as one tested helper. (#750)

- New `bin/mb` (bash 3.2 and `jq`): `threads`, `checks`, `rules`, `blockers`, `wait`, `reply`,
  `resolve`, and `help`, which names the plugin. Each verb pins the fields it reads from `gh`; a
  missing field is exit 2, never an empty result. It prints facts and approves nothing: `blockers`
  ends with a count that says it is not a verdict, and prints `unknown: BLOCKED` when GitHub says
  blocked and nothing explains it.
- `mb wait <PR> --head <sha>` is bounded (default 540 seconds, no sleep past the limit) and never
  passes early: it needs a workflow run for that exact SHA, and a check list holding only skipped
  checks is not a pass. Exit 0 passed, 1 a check failed, 3 head moved, 4 no run appeared, 75 limit
  reached. A reply body comes only by `--body-file`, never as an argument.
- `working-a-pr` calls the verbs where it had inline `gh` mechanics, states the plain-`gh`
  fallback for Codex and a missing `mb` once, and keeps its rule that the loop does not poll a
  reviewer (`mb wait` reads checks only). `commands/work-pr.md` allows `Bash(mb:*)`.
- New `omp/bin-path.ts`, byte-identical to the other copies, so OMP puts `mb` on `PATH` through the
  user-level `plugin-bin-path.ts` loader. Codex has no `bin/` mechanism; it takes the prose fallback.
- Tests: `tests/test-mb.sh` runs `mb` against a fake `gh` serving recorded output of this
  repository's PRs 1028, 1029 and 1031 and its rules. The runner globs `tests/test-*.sh`, so CI runs it.
- Agent-loaded bytes against 0.8.0 (`wc -c`): `skills/working-a-pr/SKILL.md` 21174 -> 21802 (+628);
  `commands/work-pr.md` +12; the other skills are unchanged. `bin/mb` is not loaded by an agent.

## 0.8.0

Retro: repeated review findings become proposed rules, written only when the operator accepts.

- New skill `running-a-retro` and command `/merge-bar:retro [--last N | --since <PR or date>] [--reports <dir>]`
  — reads one project's review record (review ledger, review reports, tech-debt lines, PR
  comments) over a window of merged PRs, finds defect classes that repeat across two or more PRs,
  and proposes a coding-standards entry for a judgment class no entry covers and a deterministic
  check for a class that passes its check test, every proposal citing its PRs. A proposal is never a rule until the operator
  replies to it in the session; the skill writes no code and builds no check. Accepted entries go
  to the paired workspace's standards file, and each answer is recorded in `retro-log.md` beside
  the review ledger, so a later retro does not raise a rejected class again unless a newer PR shows
  it; with no paired workspace there is no log. (#985)
- The skill quotes the skill-first headline verbatim for its check test; `docs/conventions/skill-first.md`
  now names it as the one exception, because repo-root docs do not ship with a plugin.
- Evals: `running-a-retro` fixtures RT1-RT11 with a rubric, and two baselines. The behaviour evals
  are in `tests/eval/` and are session-driven: CI does not run them.
- Agent-loaded bytes, `skills/**` against 0.7.0 (`wc -c`). The skill is 137 lines against a 120
  target because the check test's two arms and the acceptance cases each need their own paragraph:
  - `skills/running-a-retro/SKILL.md` — 0 → 9151 (+9151)
  - `skills/running-a-retro/agents/openai.yaml` — 0 → 157 (+157)
  - `commands/retro.md` — 0 → 622 (+622)
  - the other skills are unchanged.

## 0.7.0

Review ledger: every merged PR leaves one line in the paired workspace's review ledger.

- `working-a-pr` §5 — after a merge, appends one review-ledger line (PR, date, rounds, blocking and
  answered classes, bar rulings, report path) to the paired AI workspace's
  `.claude/memory-bank/review-ledger.md`, creating it with its heading when absent. The write is
  uncommitted and the operator is told which file changed. A PR that is not merged, or a PR with no
  paired workspace, gets the line printed instead. The ledger is never written into the reviewed
  repository. (#984)
- Evals: rubric criterion 6 (the ledger line) added to `working-a-pr`; fixture W16 (review-ledger
  line) is new and W8 (no paired workspace) is updated. Known limit: the other 14 `working-a-pr`
  result files were scored on the five-criterion rubric and were not re-judged.
- Agent-loaded bytes, `skills/**` against 0.6.0 (`wc -c`):
  - `skills/working-a-pr/SKILL.md` — 20371 → 21174 (+803)

## 0.6.0

Our own reviewer: `reviewing-a-pr` reviews against the PR's merge bar, and `working-a-pr` reads its report.

- New skill `reviewing-a-pr` and command `/merge-bar:review-pr` — every finding is a defect
  class with every site in the repo, sorted against the body's merge bar (never a reviewer's
  label); the standards axis and the Claim/spec axis run as parallel fresh-context subagents;
  coverage is stated per file; round 2+ reviews only the fix diff plus each prior class's
  closure. It reports and never posts, commits, edits or checks out. Standards come from
  `CODING_STANDARDS.md` at the paired AI workspace root, else `references/baseline-standards.md`.
- `working-a-pr` — reads the `reviewing-a-pr` report as a review signal (a crew reviewer seat
  returns it; without crew, a fresh-context subagent); the re-review of a pushed round is a
  fresh reviewer on the fix diff; every signal is counted and ledger lines carry their source;
  CodeRabbit and other bots are extra eyes that never gate a round.
- `working-a-pr` — a one-way door, or a body with no `Door:` line, is never merged by the
  skill, under a standing order or on an ack: it goes to the merge holder with
  `references/one-way-door.md`. A two-way door merges as before.
- Evals: `reviewing-a-pr` fixtures R1–R12 with a rubric; `working-a-pr` fixtures W13 (one-way
  door), W14 (extra eyes) and W15 (reviewer report and round 2, numbered W12 on its branch).

## 0.5.0

Standing orders come from the project's memory bank or `AGENTS.md`, and bind only the role they name; the autopilot policy is gone.

- `working-a-pr` — one **Standing orders** paragraph defines where an order is read (the memory
  bank's `08-governance.md` `## Standing orders`, then `AGENTS.md`; a canonical checkout reads
  its paired AI workspace), that the files are read as the base branch has them — an order a
  PR's own diff adds binds nothing in that PR — and that it binds only the role it names. Every other site points
  to it. With no order in effect, every ask stays exactly as it is.
- Eval fixture `W11` now keeps its three orders in the workspace `AGENTS.md`, naming the
  orchestrator; new fixture `W12` has an order naming the orchestrator read by a worker seat,
  which must still ask.

## 0.4.0

Standing orders in the autopilot policy for the merge, the round stop and the reviewers.

- `working-a-pr` — under a **Merge authority** standing order, a clean terminus is the ack
  (the reviewed-OID pin and the pre-merge re-fetch still hold); under a **Round stop** order,
  the round-3 stop narrows the Claim and continues instead of asking, and a condition-1
  finding is never narrowed; under a **Reviewers** order, a reviewer that cannot run on this
  head is replaced by the fallback reviewer the project's roles file names, and the ledger
  says so. With no standing order in effect, every ask stays exactly as it is.
- New eval fixture `W11` covers the three orders in one run: narrow, replace, merge.

## 0.3.0

OMP marketplace surface.

- Wrappers name the skill by `skill://` path as well as `${CLAUDE_PLUGIN_ROOT}`; skill descriptions lead with the trigger ("Use when ...") so OMP's skill match fires; Claude Code tool names carry an OMP alias where a skill names one; the README gains an OMP note. No Claude Code-only parts.

## 0.2.1

- `opening-a-pr` — the template says a review stopping rule is not a bar and never goes in
  the Merge bar block: `working-a-pr` decides when rounds stop, and "after round 2, block only
  on X" is a lower bar. Seven PRs (#626, #653, #707, #712, #720, #722, #725) wrote a stopping
  rule in place of the four conditions, following a pre-merge-bar "2 rounds, then defer" rule.
- `working-a-pr` — a stopping rule in the bar's place is judged as a bar below the template.
- The repository `CLAUDE.md` drops its separate "agree a stopping rule" line and points at
  `working-a-pr`.

## 0.2.0

- `opening-a-pr` — the PR body has a seventh field, `## Merge danger`, between Known limits
  and Merge bar. It names the door (two-way when a revert of the merge undoes all of it,
  one-way when something outlives the revert) and the blast radius. It does not change which
  findings block.
- `working-a-pr` — the terminus report quotes the body's Merge danger, or says the body has
  none, before it asks for the merge ack.
- The `opening-a-pr` eval rubric's first criterion is renamed `body_fields` and checks seven
  headings. The committed eval results predate this change.

## 0.1.0

Initial release. Three prose skills and three slash commands, no runtime library.

- `opening-a-pr` (`/merge-bar:open-pr`) — a six-field PR body whose Merge bar fixes, at open
  time, which findings can block; a split proposal when the claim or scope is too wide; a
  condition-1 "limit" stops the PR from opening.
- `working-a-pr` (`/merge-bar:work-pr`) — ossify's work-pr loop re-anchored on the PR's own
  merge bar: five dispositions, non-blocking findings answered in the thread by default, one
  issue per PR for out-of-scope defects, one push per round, a round-3 stop when the fixes are
  generating the findings, and the known-limits ledger written to the paired AI workspace after
  merge.
- `setting-up-reviewers` (`/merge-bar:setup-reviewers`) — an `AGENTS.md` `## Code Review Rules`
  section, and a `.coderabbit.yaml` on public repositories, landed as a PR.

Ships on Claude Code and Codex. Not on Devin or in the OpenCode bundle.
