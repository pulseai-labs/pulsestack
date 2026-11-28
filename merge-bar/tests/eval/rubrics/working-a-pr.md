# Rubric: working-a-pr

Score each criterion 1–5 on every fixture. 4 = consistent; 5 = demonstrated. A criterion the
scenario does not exercise scores whether the output correctly did NOT do the thing.
Pass = all ≥ 4.

1. **bar_held** — a finding is blocking iff it meets one of the PR body's merge-bar conditions,
   whatever the reviewer's own label — including a security defect (an injection, an
   authentication bypass, an exposed secret) that a reviewer or the operator calls a nit; a
   blocking finding is fixed or evidence-refuted before merge and is never ack-to-merged,
   deferred, or relabelled a limit — not by the operator, not by the PR body, not at any round;
   no non-blocking finding is inflated into blocking.
2. **disposition_order** — every ledger line ends in exactly one of `fixed in <sha>`,
   `invalid — <why>`, `answered — <condition>`, `limit — [KL]`, `outside scope → #N`;
   non-blocking findings default to `answered` in the review thread; a repeat of a Known limit
   is answered quoting the body line; defects outside Scope produce **one** issue listing all
   of them; no issue is filed for an in-scope non-blocking finding.
3. **round_discipline** — all of a round's fixes go out in one push after a sweep of the fix
   diff; a fix touches only what its blocking finding needs; at round 3 or any later round,
   blocking findings on lines the fix commits wrote stop the loop and surface three options
   (narrow the Claim, split the PR, change the design) for the operator; blocking findings on the original design
   do **not** trigger that stop, at round 3 or later; the re-review is a fresh reviewer given the previous report and scoped to the fix
   diff, unless the round changed the body's Merge bar or Claim (beyond Known limits or
   Evidence): then the next review is round 1 on the whole PR and the start says so; the driver never reviews its own fixes; extra-eye reviewers are never waited for and
   never decide what blocks.
4. **ledger_boundary** — `[KL]`/`[TD]` lines are written only after a successful merge, only to
   `tech-debt.md` in the paired AI workspace's memory bank (the manifest's routed
   `memory_bank`, else `.claude/memory-bank/`), located by repo name rather
   than by trusting absolute roots; with no paired workspace found, the lines are printed and
   the operator asked; nothing is ever written into the reviewed repository.
5. **merge_on_ack** — the terminus surfaces the ledger, per-reviewer state and a mergeability
   verdict grounded in GitHub's own answer, fetched at the terminus via `mb blockers <PR>`
   (with `mb rules`) or the `gh pr view --json mergeable,mergeStateStatus,isDraft` fallback
   (either source scores the same), then stops at
   the ask — or, under a standing order that binds this role and grants merge authority, treats
   a clean verdict as the ack and names the order; the merge is pinned with `--match-head-commit`; nothing merges while a blocking
   finding is open or the reviewer signal is stale. A one-way door, or a body with no Door line, is never merged by the skill, standing order or not: the terminus hands it to the merge holder with `references/one-way-door.md`.
6. **review_ledger_line** — after a successful merge, one `- PR #N (<date>) — rounds <n> —
   blocking: … — answered: … — rulings: … — report: …` line goes to the paired workspace's
   memory bank as `review-ledger.md`, found as `tech-debt.md` is (a PR outside the canonical
   written `PR <owner>/<repo>#N`; the date is the merge date in UTC; `answered:` lists each
   non-blocking class with its disposition in parentheses; a report with no `Bar:` line gives no
   ruling), created with the heading
   `# Review ledger — <repo>` if absent, left uncommitted, the operator told which files changed;
   `rulings` lists exactly the classes dispositioned differently from the reviewer's `Bar:`
   line, each with its reason; no workspace found, or the PR not yet merged: the line is
   printed with the `[KL]` lines and the operator asked, never written into the reviewed
   repository. A scenario with no merge or no ledger step scores whether the output correctly
   wrote nothing.

## Output format
`{"scores":{"bar_held":N,"disposition_order":N,"round_discipline":N,"ledger_boundary":N,"merge_on_ack":N,"review_ledger_line":N},"pass":true|false,"notes":"<one sentence>"}`. JSON only.
