# pulsestack

A **plugin marketplace** published to three surfaces: Claude Code (`/plugin install`, from
`.claude-plugin/marketplace.json`), Codex (`.agents/plugins/marketplace.json`, the v0
dual-publish contract), and OMP (`.omp-plugin/marketplace.json`, nine plugins;
`tests/test-omp-surface.sh` keeps it in step). There is no application — the plugins *are* the product.

**A change to a plugin manifest or to packaging has to be carried to every surface that
plugin ships on**, and CI enforces it rather than advising it: `tests/test-codex-dual-publish.sh`
checks version and frontmatter parity across the two marketplaces. `seat-mods`, `molt`
and `baton` are deliberately absent from the Codex set — check the deferred list in
`tests/test-codex-dual-publish.sh` before assuming a plugin ships everywhere.

Shipped: `workspace-init`, `sage`, `membrane`, `ossify`,
`remodel`, `crew`, `merge-bar`, `seat-mods`, `molt`, `baton`.

This repo is the **public canonical half** of a dual-repo project. Design specs, session
handoffs, review records and process exhaust live in a private sibling workspace and must
never be added back here.

---

## The one rule that matters most

**Prose is the default. Code is allowed when the work is mechanical and its inputs are closed, or when it is a mechanical check that can only add a stop.**

@docs/conventions/skill-first.md

`docs/conventions/skill-first.md` is **authoritative** — its scope, its evidence, and the
decidable test that goes with it. The headline above is stated inline only because the import
above it is a Claude Code feature, not a property of this file: any other reader — an external
review agent, `cat`, the GitHub web view — receives that line as literal text and would
otherwise get no rule at all. **If the two ever disagree, the file wins.**

It lives there rather than here because the paired private AI workspace needs the same rule and
**this file does not load there.** Claude Code walks *up* from the working directory; the two
repos are siblings, so a session started in the workspace never sees this file. Its `AGENTS.md`
imports the same file by absolute path.

That import is **external** — outside its working directory — so Claude Code gates it behind a
one-time approval dialog per machine. Declining it, or hitting it non-interactively, disables
the import permanently and **silently**: no error, no second prompt, just a session with no
rule. If a workspace session seems not to know this rule, check `/context` for the file before
assuming anything else.

Do not paraphrase the rule in either repo beyond the headline above.

---

## Testing discipline

Tests here are load-bearing and green means nothing on its own. Before trusting a passing
test, mutation-test it, and hold all three conditions:

1. **The mutation is semantic** — a syntax-broken mutation produces misleading RED that reads
   as coverage.
2. **The mutation applied** — echo the changed line back. A no-op `sed` and a worthless test
   are indistinguishable from the pass count.
3. **The mutation EXECUTES on the tested path** — a function with early returns needs one
   mutation per branch. A mutation on a line the fixtures never reach proves nothing, and
   reads as "this test is vacuous" when the test is fine.

`tests/lib/mutate.sh <file> <from> <to> -- <suite>` checks condition 2 for you (the mutation applied) and restores from a saved copy; conditions 1 and 3 stay your judgment.

Other ways a green test lies: round-trip tautologies (the verifier re-derives its expected
value from what the code just wrote); fixtures coupled through shared state; a grep-based
check that passes on its own comment; a justifying comment treated as verified behaviour.

**A loosening needs an adjacent control.** When a change makes a check accept more, its
failure mode is that it stops detecting anything — so pin a case that must still fail, right
next to the case that must now pass.

## Shell gotchas that have cost real time here

- `bin/*` dispatchers run `set -euo pipefail`; tests source libs directly and do **not**.
  A lib change verified only by sourcing can still abort under the dispatcher — add a
  dispatcher-path test.
- Under `set -o pipefail`, `… | grep -q` can fail **on a true match** — `grep -q` exits at the
  first match and the producer takes SIGPIPE if it writes again. It fires intermittently,
  which is worse than deterministic. Replace it with a single `awk` pass.
  **When you do, preserve the predicate:** `index()` is a literal substring test, so it is not
  equivalent to `grep -E`, `-w`, or `-x`. Pick the awk form that matches the original and
  prove it on an input that separates them — the two predicates agreeing on your first fixture
  is not evidence.
- The Bash tool runs zsh; `run-all.sh` forces bash. An unmatched glob aborts the whole
  command line under zsh, and `shopt` does not exist.
- BSD `date`: **every option must precede the operand.** `-v` and `-f` may appear in either
  order — `date -j -f %Y-%m-%d -v+1d 2024-01-01 +%F` prints `2024-01-02` correctly, and so
  does the `-v`-first spelling. What fails is an option placed *after* the date string:
  `date -j -f %Y-%m-%d 2024-01-01 -v+1d +%F` silently drops **both** the adjustment and the
  output format, printing the default `Mon Jan  1 …`. An earlier draft of this bullet claimed
  `-v` must precede `-f`; that is not a real constraint, and chasing it reorders flags without
  fixing the actual bug. Measured on Darwin 25.5.0.
- Never compute a test's expected date with the lib's own command — that is a tautology.
- `${CLAUDE_PLUGIN_ROOT}` is not exported into Bash-tool subprocesses.
- **Commit messages here quote shell, so never pass one through `git commit -m "…"`.**
  Backticks and `$` are substituted *before git sees the string*: a message quoting a
  command in backticks runs it and pastes the output into the commit. It happened on the
  `boundary-audit` branch and captured a full environment dump — unpushed, so nothing
  escaped, but on a pushed branch that is a credential-shaped leak into public history.
  An unquoted heredoc expands them too. Write the message to a file and use
  `git commit -F <file>`. **Repair depends entirely on whether it was pushed.**
  Unpushed: `--amend -F <file>`, then
  `git reflog expire --expire-unreachable=now --all && git gc --prune=now` —
  unreachable objects are never pushed, so that is the whole fix. **Pushed: the
  local rewrite fixes nothing on its own.** The object stays reachable on the
  remote (and in any fork, PR ref, or clone) until the branch is force-pushed
  and GitHub is asked to purge the ref, and **any credential the expansion
  exposed must be treated as compromised and rotated immediately** — rewriting
  history does not un-disclose a secret that was published.

---

## Git policy

- **Never squash.** Merge commits or rebase only. Enforced by ruleset `20492634`
  (`allowed_merge_methods = [merge, rebase]`), not just convention.
- **Never push to `main` directly.** Branch + PR always.
- **No `Co-Authored-By:` or `🤖 Generated with` trailers.** This is a **policy you must
  follow, not a guarantee the repo enforces.** A `commit-msg` trace filter blocks them, but
  git hooks live in `.git/hooks/` and are **not tracked** — a fresh clone, a CI checkout, or
  any machine that never ran workspace-init has no filter at all. Do not rely on being
  stopped. If a commit *is* blocked, the message is wrong — never `--no-verify` past it.
- **Determining whether a branch is merged — see the block below.** This has been wrong four
  times; do not improvise a fifth spelling.
- `branches/main/protection` returns 404 — the gate is a *ruleset*, not branch protection.
- Take reviewer thread counts from **GraphQL** (`reviewThreads.totalCount`); REST undercounts.

### Is `origin/<branch>` merged?

Two facts are needed, and every single-fact answer tried here has been wrong:

```bash
gh pr list --state merged --head <branch> --json number,mergedAt,headRefOid
git ls-remote origin refs/heads/<branch>
```

**Merged iff a merged PR exists AND its `headRefOid` equals the branch tip.** If a merged PR
comes back but the OIDs differ, the branch name was **reused** — the current incarnation is
unmerged work, and deleting it destroys it.

The four spellings that failed, so nobody re-derives one:

| Spelling | Why it is wrong |
|---|---|
| `git merge-base --is-ancestor` | squashed *and* rebased branches are never ancestors — reports merged branches unmerged forever |
| `git diff origin/main origin/<branch>` | compares endpoint trees, so any unrelated commit on `main` makes a fully-merged branch look unmerged |
| `git cherry` | compares patch-ids per commit; against a squash merge every commit of a merged branch reports `+` |
| `gh pr list --state merged` (unqualified) | `--limit` defaults to 30; this repo passed 56 merged PRs on 2026-08-14, so the oldest silently vanish |

## Reviewing and being reviewed

- A prescribed remedy — in an issue or a review comment — is a **hypothesis**, not an
  instruction. Before implementing it, check that its premise holds at *this* call site and
  that it covers the whole class the finding names. Both failure modes have shipped defects
  here.
- After the first review round, deep-scan and fix all similar issues in **one** pass. Never
  grind one-at-a-time.
- If a function draws a finding in more than one round, **restructure it** rather than
  patching again. Three findings on one function means the shape is wrong.
- The review loop is merge-bar's `working-a-pr`. The body's Merge bar, written when the PR
  opens, decides what blocks, and that skill decides when rounds stop. Do not agree a separate
  stopping rule, and never write one into the bar.

---

## Commands

**`.github/workflows/tests.yml` is the authoritative list of what must pass.** Read it and run
the steps that cover what you changed, including each step's `env:` and any install step above
it — several fail or silently weaken without them.

This section deliberately does **not** restate that list. An earlier revision did, and drew a
fresh "you omitted X" finding in three consecutive review rounds: a hand-maintained prose
mirror of a machine-readable file drifts from it by construction, which is the same
over-specification this file warns about above. The workflow is the source of truth; what
follows is only what reading it will not tell you.

**Run the suite for the plugin you changed.** `ossify/tests/run-all.sh` is not a proxy for the
others — it exercises none of their code, so an ossify-only run reports ALL GREEN on a
merge-bar change that was never tested. Plus the repo-root `tests/` set, which catches
cross-plugin parity breaks no single plugin suite can see.

**Some gates do not run themselves, and CI does not run them either.** Several plugins ship
validation that both `tests.yml` and the plugin's own `run-tests.sh` skip — session-driven
LLM-judge harnesses under `tests/eval/` (ossify), behavioural checklists
walked by hand (sage's five `tests/*.md`, required before a version bump). A green CI run
says nothing about any of them, and a plugin's own runner can miss them too: `ossify/tests/run-all.sh`
never runs `ossify/tests/eval/`, so its evaluator does not run from the runner.

**Before bumping a plugin's version, list that plugin's `tests/` and `evals/` trees and compare
them against what its own runner actually executes.** Whatever the runner does not execute is
a gate you walk by hand.

**Do not expect a consistent filename.** Across the shipped plugins the gate document is
variously a `RUNBOOK.md`, a `tests/README.md`, or a directory of markdown fixtures — and some
have none at all. That is why this says *look* rather than naming a file to open:
naming one is how the deleted command block started, and a pointer to a file that does not
exist fails the same way a stale list does.

```bash
bash ossify/tests/eval/lib/aggregate-scores.sh  # reads results/*.json — evaluates NOTHING
```

That script only summarises per-fixture JSON that a **prior Claude-Code session** wrote; its
own header says "Run AFTER the eval run has written `results/*.json`." Run it after changing a
fixture or rubric and it reports STALE; a skill-only change still re-reads the *committed*
results and can report green, having evaluated none of the change. The evaluation itself is the session-driven pass in the RUNBOOK (dispatch
an agent per fixture, then a judge against `rubrics/<surface>.md`, writing
`results/<surface>/<id>.json`) — `run-evals.sh` prints that instruction rather than performing
it. Treat a green aggregate as valid only when the results files were regenerated after the
change under test.

`docs/conventions/` and `docs/assets/readme/` (the pictures of the root README and ossify's README, and the source of the repository's social preview image) are the only `docs/`
content tracked here, because they are shipped convention and the project's public images rather
than process exhaust. Delivery differs per convention file; each one's header states its own.
