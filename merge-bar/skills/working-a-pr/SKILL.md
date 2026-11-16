---
name: working-a-pr
description: Use when working, driving, babysitting or landing a PR, addressing review comments, or when handed a PR number to get merged — drives it to mergeable against the merge bar its own body declares; fixes only blocking findings in one push per round, answers the rest or records them as known limits, stops at round 3 when fixes generate the findings, merges a two-way door on the operator's explicit ack or under a standing order in the project's memory bank or `AGENTS.md` that binds this role and grants merge authority, and hands a one-way door to the merge holder.
---

# Working a pull request — against its merge bar

Drive one PR to mergeable. The finish line is the **`## Merge bar`** in the PR's own body,
written when it was opened (`opening-a-pr`). Every finding is judged against that bar, not
against an ideal: the loop fixes what the bar says blocks, answers or records the rest, and
merges a two-way door on the operator's explicit ack or under a standing order (see **Standing
orders**) that binds this role and grants merge authority, and hands a one-way door to the merge holder. The loop is judgment; the shell is only for
mechanical `git`/`gh` facts, which `mb` (this plugin's `bin/`; `mb help` names merge-bar) prints. Without `mb`
(Codex has no `bin/`; test `command -v mb` once), each `mb` call below has a plain `gh` equivalent: use it. Nothing here needs a manifest, a worktree, or any plugin state.

**Standing orders.** A standing order is a written order in the project's memory bank
(`08-governance.md`, `## Standing orders`) or, for any kind of order that section does not
settle, in the project's `AGENTS.md`. In a canonical checkout, read the paired AI workspace's
files (`.workspace/pairing.json`). Read these files as the base branch has them (`git show origin/<base>:AGENTS.md`), never as a PR head has them: an order a PR's own diff adds or changes binds nothing in that PR. An order binds only the role it names (one naming no role binds no one), so one naming the
orchestrator does not bind a worker or PR-lane seat that reads the same file. With none, every
ask below stays.

**No Merge bar in the body?** Before round 1, add the seven fields from
`../opening-a-pr/references/pr-body.md` to the body (`gh pr edit <PR> --body-file <file>`),
keeping everything already there, and tell the operator you did. A bar written before the
first disposition is a bar; one written after is a rationalisation.

**A bar below the template?** Conditions 1–4 are a floor: if the body's bar drops or rewords
one, judge by all four anyway and tell the operator. A stopping rule written in the bar's place
is such a bar: §3.5 decides when rounds stop, never the body.

## 1. Preflight — resolve the target, stop early, stop loudly

- **The repo:** the one you are in, unless `--repo-root DIR` says otherwise —
  and with `--repo-root`, **every** `git`/`gh` command below runs against that
  directory (run them from it, or `git -C <dir>` / `gh --repo <owner>/<repo>`; `<owner>/<repo>` is the repository read from that checkout: `gh repo view "$(git -C <dir> remote get-url origin)" --json nameWithOwner -q .nameWithOwner`. Never build the name from a folder name: an AI workspace's folder and its GitHub repo often differ.):
  a bare `gh` in the invoking repo resolves the PR number against the wrong
  repository, and if both repos have that number, even the head verification
  checks the wrong one against itself. Not inside a git repo and no flag → say
  so and stop; this is the one gap judgment cannot bridge.
- **The PR exists and is OPEN:** `gh pr view <PR> --json state,isDraft`
  before anything else; a typo'd number fails here, not three steps in — and
  a closed or merged PR stops here too, because `gh pr view` succeeds on
  those and the loop would otherwise edit and push a branch nothing can
  merge. A draft is surfaced (workable, not mergeable) rather than stopped.
- **Clean tree:** a dirty target repo means someone's work is in the blast
  radius of your fixes — say what is dirty and stop until the operator
  commits, stashes, or cleans. Never stash on their behalf.
- **The head you will edit:** check out the PR branch (`gh pr checkout`) and
  confirm the branch and commit you landed on are the PR's own head (`gh pr
  view --json headRefName,headRefOid` against `git rev-parse`). Editing the
  wrong branch writes fixes nowhere the PR can see; a mismatch is a stop, said
  plainly.

Each stop names what failed and what would unblock it. None of them is a
refusal to work the PR — they are the order that keeps fixes attributable.

## 2. Fetch the findings — every signal, always

Reviewers leave findings in two places, and each alone misses what the other
carries; a third is the report of the `reviewing-a-pr` reviewer:

- the **review + conversation stream** — review summaries, CI rollup, top-level
  comments (`gh pr view --comments`, `mb checks <PR>`, review listings — the
  `--comments` flag matters: the bare view omits top-level comments, and a
  finding that lives only there would silently miss the ledger);
- the **inline line-level comments** — where review bots put nearly everything
  (`mb threads <PR>` lists the unresolved threads with their ids; or `gh api --paginate
  repos/{owner}/{repo}/pulls/{n}/comments` — paginated, because a second page of findings that never loads
  is a ledger hole wearing a clean look);
- the **review report** (`reviewing-a-pr`, in the shape of its `references/report.md`) — a
  crew reviewer seat returns it; without crew, start it as a fresh-context subagent on a
  checkout prepared at the PR head. Post the report as **one** PR comment, so round 2 can
  name it.

Read all three, then build the **disposition ledger**: one line per finding, naming its
source (the report, or the reviewer or bot), every line ending in exactly one of the five dispositions in §3. The ledger is the
loop's working memory and its terminus
report; a finding missing from it was never dispositioned.

## 2.5 Read the findings as a set before each edit pass

§2 hands you a list; editing straight down it is this loop's main failure mode.
Independent fixes to overlapping prose re-anchor the sentences the next finding
cites, and round N+1 arrives built out of round N's own fixes.

So before each edit pass — the first one, and again after every re-review —
collapse the ledger into **classes**; the report's classes, with their sites, are the
starting list. A class is one
defect however many findings name it: the same mistake at several sites, two
reviewers on one site, or several symptoms of one wrong condition. Fix a class
in one commit, or record why it splits.

Three obligations follow. Each is a requirement, not a procedure — how you
satisfy it is yours:

- **You close the class, not the finding.** A finding names one site; the class
  is every site reachable at that boundary. The reviewers saw a sample, so
  enumerate the rest yourself and close them together. What you name and leave
  must be non-blocking: a member of a blocking class — one that meets the PR's
  merge bar — is fixed or the change is cut (§3), never left. A fix that closes only the cited site guarantees the class returns.
- **Grep the condition's old form first.** When a fix changes a rule, the
  defects that remain are phrased in what you replaced, not in what you wrote.
  The old form is the search term, and the fix is often deleting a stale clause
  rather than adding a new one.
- **Order by collision, not by severity.** Two fixes that rewrite the same
  prose are one edit. Where they genuinely are not, apply the one that moves
  the anchor first, then re-read the other finding against the new text before
  touching it — its quoted line may no longer exist.

A fourth obligation applies to what you just wrote. **Sweep the fix diff before
you push it**, against the same class you set out to close. Most of round N's
findings are on round N-1's fixes, so the cheapest round to remove is the one
you are about to cause.

Then ask one question of the whole set, which no single finding can answer:
**is the PR's headline claim still true?** A round of fixes can leave the
description, a changelog entry, a commit message, any doc line, or any
release-metadata field the diff touched promising work the diff no longer
does.

The ledger stays one line per finding. Classes are how you **fix**; the ledger
is how you **report**.

## 3. The disposition contract — the PR's merge bar

This section is authoritative for this lane. The bar is the `## Merge bar` section of the PR
body. A finding is **blocking** if and only if it meets one of the bar's conditions, or the
PR's one raising line. Decide by the condition, never by the reviewer's label: a bot's "P1"
that meets no condition is non-blocking, and a "nit" that meets condition 1 is blocking.
Condition 4 is the same: a finding that opens an injection, an authentication bypass or an
exposed secret is blocking however it is labelled — its severity is the bar's, not the
reviewer's or the operator's.

Every ledger line ends in exactly one of these five dispositions:

- **`fixed in <sha>`** — every blocking finding that is real. For a non-blocking finding,
  allowed only when the fix sits inside Scope and is a line or two; never required.
- **`invalid — <why>`** — the finding is wrong. The refutation is evidence-shaped — walked
  against the tree, quoted — never "disagree". Applies to blocking and non-blocking alike.
- **`answered — <condition it fails>`** — the default for a non-blocking finding. Reply in the
  review thread in one line naming which bar condition it does not meet (`mb reply <thread> --body-file <f>`). If it repeats a
  Known limit, quote the body line. A reviewer that does not read the PR body repeats
  Known limits: answer them, never fix them.
- **`limit — [KL]`** — a non-blocking finding that names a real edge case of this PR worth
  recording. Add a line to the body's `## Known limits` (`gh pr edit <PR> --body-file <file>`)
  and say so in the thread; §5 writes it to the ledger after the merge. A finding that meets condition 1 cannot be a limit, whatever it is labelled — by the reviewer, by the PR body, or by the operator.
- **`outside scope → #N`** — a real defect on a path this PR does not touch. At most one issue per PR, created with `gh issue create` and listing every such finding with its file, line
  and a link to the review comment; a later one is added to that issue as a comment. §5
  records it as a `[TD]` line.

**The blocking rail.** A blocking finding is fixed, refuted with evidence, or the change is
cut. It is never ack-to-merged, never deferred and never relabelled, no matter which round
surfaced it or who asks — "just merge it" included.

- **You drive the fix yourself:** edit and commit. The push is §3.5's one push per round — never
  one push per fix. Record `fixed in <sha>` only when the fix is on the PR head the reviewer can
  see.
- **Staleness:** a fix commit landing after a review makes that verdict stale. Re-fetch (§2)
  and re-review on the **new** head; the old verdict does not carry forward.
- **Reviewer completeness:** green CI is not proof a reviewer ran; a skipped reviewer is not
  approval. Confirm the `reviewing-a-pr` report exists for the current head; never assume it.
  If that reviewer cannot run, surface it — unless a standing order (see **Standing orders**) that
  binds this role names the fallback reviewer: then replace it and say so in the ledger.
- **Extra eyes:** CodeRabbit or any other bot or reviewer is never waited for, and its label
  never decides what blocks; judge each of its findings against the bar like any other. Say
  its state (pending, ran) in the report; it gates nothing.

Sort by failure direction before acting: a finding that the boundary **refuses a valid input**
is blocking — condition 1; a finding that it **correctly refuses an unsupported input** is
`invalid` or `answered`; a finding that it **admits what it cannot handle** and corrupts or
loses state is blocking. Incoherence this diff introduced is this diff's to fix.

## 3.5 Rounds

A round is one pass of §2 → §2.5 → §3 ending in one push. Round 1 is the first review of the
opened PR. The re-review of a pushed round is a **fresh** reviewer, never you: start it on the
new head with `--round <n> --previous <URL of the posted report comment>`, so it reviews the
fix diff and each prior class's closure. Your own sweep is a pre-push check, not the re-review.
If a round changes the body's `## Merge bar` or `## Claim` (beyond adding Known-limits lines or
Evidence), start the next review as above and tell it the bar or Claim changed: it then reviews the
whole PR as round 1 (`reviewing-a-pr` §5). The round count continues.

- **One push per round.** Commit fixes class by class, then push once, after the sweep below.
  Every push triggers another review, so each extra push buys one.
- **A fix touches only what its blocking finding needs** — the class §2.5 named, and nothing
  else. No cleanup, no rewording nearby, no fixing a non-blocking finding "while you are there".
  Every extra line is a new review target.
- **Sweep the fix diff before you push it.** Read `git diff <last pushed head>..HEAD` against the
  bar: does any line of it newly reject valid input, corrupt or lose state, or falsify the
  Claim? Most of round N's findings are on round N-1's fixes; the cheapest round to remove is
  the one you are about to cause.
- **The stop.** At round 3 or any later round, if any blocking finding sits on lines your own
  fix commits wrote (check with `git blame` against the fix SHAs), stop. Do not start another round. Surface
  the findings, the fix commits they sit on, and three options for the operator: **narrow the
  Claim** — moving an edge into Known limits, only where it does not meet condition 1 —
  **split the PR**, naming the parts, or **change the design**. Recommend the last when a stop's
  blocking class, followed back through the posted reports' `Extends:` lines, makes a chain of
  two or more: each fix adds a case to one mechanism that reads open input. Name the mechanism and the closed form that
  replaces it — refuse what it does not model, or an allowlist for a denylist; the change is
  new commits, reviewed as round 1 of the changed part. The operator chooses at every stop that no standing order settles (next sentence), and no count limits how often the design changes. Under a standing order (see **Standing orders**) that binds this role
  and settles the round stop, follow that order instead and record the
  choice in the stop report. Findings in that same round which
  sit on the PR's original commits are dispositioned on their merits alongside the stop report.
- **Not the stop:** blocking findings at round 3 or later on lines the PR's original commits
  wrote. The reviewers are excavating the design, not reacting to your fixes. Disposition each
  on its merits and continue; a count alone never ends the loop.

**Unclaiming.** Narrowing the Claim is two edits, not one: the findings behind the claim keep
their ledger lines — the unclaiming commit is the fix — and the claim itself comes out of every
artifact that promises it: the PR body, the changelog, and any README, doc or release-metadata
line the diff wrote it into. A claim baked into a commit message comes out only by rewriting
history; a rewrite re-mints every descendant sha, so remap each `fixed in <sha>` line onto the
rewritten head before the terminus. A rewrite pushes non-fast-forward, so lease it —
`git push --force-with-lease=<branch>:<current-remote-oid>`, captured immediately before the
rewrite — and a refused lease re-enters §1: someone advanced the branch.

Neither the stop nor unclaiming touches the blocking rail or bypasses staleness: they land
commits like any other fix, prior verdicts go stale, and the reviewer signal must be complete
on the head that carries the final shape before the terminus ask.

## 4. Terminus — surface everything, then ask

First resolve the review thread of every inline finding — each has its final disposition by
now (`mb resolve <thread>`; GraphQL `resolveReviewThread` without `mb`). A repository can require resolved threads to merge, and
an open one blocks it as surely as a red check.

Then, in one place, give the operator:
- the body's `## Merge danger`, quoted — or that the body has none,

- the full disposition ledger,
- CI state and per-reviewer status (ran / skipped / pending / stale),
- a mergeability verdict: clean to merge, or exactly what still blocks —
  **grounded in GitHub's own answer, fetched here** (`mb blockers <PR>`, with `mb rules` for the
  base's merge methods and up-to-date rule; else `gh pr view --json
  mergeable,mergeStateStatus,isDraft`): a draft, a conflict with the base, a
  branch the ruleset calls BEHIND, or a blocked review state each falsifies
  "clean to merge" however green CI and the reviewers look; found only after
  the ack, it solicited an impossible merge.

A one-way door, or a body with no `Door:` line (counted as one-way), is never merged by this
skill — not under a standing order, not on the operator's explicit ack; an ack is answered
that the merge holder runs `references/one-way-door.md` and merges. Surface the terminus and
hand it to the merge holder — the orchestrator where one runs, otherwise the operator — with
the reviewed head OID, the ledger, the §5 lines and `references/one-way-door.md`. After the
merge, whoever merged writes the §5 lines per §5, or prints them.

Otherwise **ask**: merge, wait, or leave open — or, under a standing order (see **Standing orders**) that binds this role
and grants merge authority, treat a clean verdict as the ack and say which order
gave it. The ack covers **the head the ledger describes**: pass the reviewed OID
(`gh pr merge --match-head-commit <oid>`, with the repo's merge convention —
ask if the convention is not evident from the repo's history or settings), so
a head that moved between the report and the answer refuses and re-enters §2
instead of merging unreviewed commits. The pin guards **commits, not
verdicts** — a blocking review or a red CI rerun can land on the *same* head
while the operator considers the ask — so after the ack and immediately
before merging, re-fetch every finding signal and the checks once more;
any new finding re-enters §2 instead of merging. On a branch governed
by a merge queue, required checks must be **finished** before accepting the
ack — with checks still pending, `gh pr merge` does not merge, it *enables
auto-merge*, and this lane never auto-merges. To wait for CI: `mb wait <PR> --head <oid>`, as a
background command where the harness has one, then end the turn; it reads checks only. Exit 0 is the
only pass; 1 a check failed, 3 head moved, 4 no run appeared, 75 limit reached (run it again). Never merge over an unresolved
blocking finding, a stale or incomplete reviewer signal, or a red gate. If the operator
leaves it open,
report the PR URL and stop — the loop does not poll.

## 5. After the merge — write the ledger

Only after the merge has succeeded: `gh pr view <PR> --json state` reads `MERGED`. Under a
merge queue `gh pr merge` returns once the PR is queued, not merged. Not `MERGED` → write
nothing; print the lines below and where they belong, for the operator to add once it merges
(a later run cannot: §1 stops on a merged PR). Collect every line of the final body's
`## Known limits` (except `None.`) — an in-review `limit — [KL]` finding already reached the
body through §3, so nothing is collected twice — and the one `outside scope → #N` issue if
there is one. Write them
as:

```
- [KL] <area/path> — <the limit> — <why accepted> — revisit when <trigger> (PR #N)
- [TD] <area/path> — <defect> → #N (PR #N)
```

**Where they go:** `tech-debt.md` in the paired AI workspace's memory bank. Find the workspace
next to this repository by `.workspace/pairing.json` whose `canonical.name` matches this repo
(commonly `<repo>-ai`), or through `.ossify/topology.json`. Absolute `root` paths may belong
to another machine — match by name and location, never by trusting them. Exactly one workspace
must match: if none or several do, print the lines and ask. In that workspace, use
the manifest's `.well_known_paths.memory_bank` (`.ossify/topology.json` first, else `.workspace/pairing.json`).
Expand `${ai_workspace.root}` to the matched workspace root, and `${HOME}` and `${USER}` from the
environment; absent a route, use `.claude/memory-bank/`. A relative route, any other token, or
an absolute route that does not exist on this host: print the lines and ask.
If the file is absent, create it with the heading `# Tech debt — <repo>`. Append the lines and
leave them **uncommitted**: tell the operator which file changed; committing belongs to that
workspace's own session.

**The review-ledger line.** Every merged PR also gets one line in `review-ledger.md` in that
same bank (same match, none-or-several rule, uncommitted):

```
- PR #N (<YYYY-MM-DD>) — rounds <n> — blocking: <class names | none> — answered: <class (disposition), … | none> — rulings: <bar overrides, each with its reason | none> — report: <path | none>
```
A PR in the workspace's canonical repo stays `PR #N`; any other repo uses `PR <owner>/<repo>#N`
in the ledger line and the parenthesized suffix above. The date is the merge date from
`gh pr view <PR> --json mergedAt`, in UTC; a line printed before the merge carries `<merge date>`.
The `answered:` field lists every non-blocking class with its disposition in parentheses:
`(answered)`, `(fixed)`, `(invalid)`, `(limit)` or `(→ #N)`.

Rounds come from §3.5, class names from the §2.5 set. A ruling is a class you dispositioned
differently from the reviewer's `Bar:` line, with the reason. A report with no `Bar:` line records
no ruling for its classes. Report is the last round's report path if it is on disk. If the file is absent, create it with the heading
`# Review ledger — <repo>`; tell the operator which files changed. Not merged, or no
workspace: print this line with the others.

Never write the ledger into the reviewed repository — it may be public, and the ledger is
process record. If no paired workspace can be found, print the lines and ask the operator
where they go.

## Anti-patterns

- **Growing the loop into tooling.** No wrapper scripts beyond `mb`, no state files — the ledger of
  dispositions lives in the conversation and the terminus report.
- **Judging a finding by its label.** "P1" and "nit" are the reviewer's words; the bar is yours.
- **Editing straight down the ledger.** N findings are not N fixes. Classify first (§2.5).
- **Fixing non-blocking findings to make them go away.** Answer them. A fix is a new review
  target.
- **Filing an issue per finding.** Out-of-scope defects share one issue; in-scope
  non-blocking findings get none.
- **Counting rounds without reading them.** A round number never stops the loop on its own: the
  stop fires only when the reading says your fixes are generating the findings.
- **Ack-to-merging a blocking finding**, or letting "just merge it" relabel one as a limit.
- **Trusting a pre-fix verdict on a post-fix head.**
- **Auto-merging.** The merge of a two-way door is the operator's explicit call, or a standing
  order's that binds this role; never a merge queue's auto-merge. A one-way door is never this skill's merge.
