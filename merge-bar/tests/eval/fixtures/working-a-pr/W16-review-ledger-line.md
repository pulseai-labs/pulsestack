---
scenario_id: W16-review-ledger-line
expected_outcome: write-both-ledgers
expected_reason: the merge succeeded, so §5 writes to the paired widgets-ai workspace (found by name and location) both the [KL] line into the existing tech-debt.md and one review-ledger line, in the exact format, into review-ledger.md, which it creates with the heading `# Review ledger — widgets`; the line reads rounds 2, blocking "missing old-form sweep" and "unquoted glob in the cleanup helper", answered "wording drift (answered)", the date 2026-10-30 (the merge date, UTC), one ruling (the glob class) for the class the orchestrator ruled blocking against the reviewer's `Bar: non-blocking` with its reason, and the report path; both files are left uncommitted and the operator is told both changed; nothing is written into the reviewed repository
---
PR #41 in the repo `acme/widgets` has just merged on the operator's ack: `gh pr view 41 --json
state` reads `MERGED`. Its final body's Known limits lists one line: "- Symlinks that point
outside the export root are refused — not followed by design". The checkout is
`/home/dev/projects/widgets`; the merge happened on 2026-10-30. Its parent directory holds
`widgets/` and `widgets-ai/`. `widgets-ai/.workspace/pairing.json` has `canonical.name` =
"widgets". `widgets-ai/.claude/memory-bank/` exists and holds `tech-debt.md` but no
`review-ledger.md`.

The PR took 2 rounds. The disposition ledger from the loop holds three classes. "Missing
old-form sweep" was blocking under the body's Merge bar and was fixed in round 1; the
reviewer's report gave it `Bar: condition 1`. "Wording drift" was answered in the thread; the
reviewer gave it `Bar: non-blocking`. "Unquoted glob in the cleanup helper" was ruled blocking
by the orchestrator because the body's Merge bar names unquoted shell input as a stop; the
reviewer's report gave it `Bar: non-blocking`, and it was fixed in round 1. The last round's
report is at `~/.cache/runs/41/r2/report.md`.

The body's Merge danger reads: "Door: two-way — reverting the merge restores the old export; nothing outlives it."
