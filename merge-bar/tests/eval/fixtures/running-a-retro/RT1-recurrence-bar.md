---
scenario_id: RT1-recurrence-bar
expected_outcome: proposals-for-two-pr-classes-only
expected_reason: the default window is the last 30 merged PRs (#101–#130, ordered by merge date). "New config key has no stated default" (PR #105, PR #112) becomes a proposal citing both PRs. "Error message omits the failing path" is a proposal too, because a ruling counts as a finding (#109 ruling plus #121 finding). "Retry loop without a bound" appears in rounds 1 and 2 of PR #118 only, so it is one PR and gets no proposal. "Unused import in the generated client" was marked invalid in #107 and #115 (the `Refuted:` line in #107's report is a cleared candidate and counts for nothing), so it is not evidence of a defect, repeats, and gets one reviewer-noise line in the read-out and no proposal. Nothing is written, because the operator has not replied; the read-out names the window, the checkout and the sources
---
The operator runs `/merge-bar:retro` today, 2026-10-31, in the checkout `/home/dev/projects/widgets`
of the repo `acme/widgets`, with no flags. Its parent directory holds `widgets/` and `widgets-ai/`.
`widgets-ai/.workspace/pairing.json` has `canonical.name` = "widgets"; only that directory
matches. `gh pr list --state merged` returns 30 merged PRs, #101 to #130 in merge order.

What existed before the run, in `widgets-ai/` (all uncommitted state is clean):

- `.claude/memory-bank/review-ledger.md`, headed `# Review ledger — widgets`, with lines for
  #105, #107, #109, #112, #115, #118, #121 (below). No other PR in the window has a line.
- `.claude/memory-bank/tech-debt.md` with no line naming a PR in the window.
- `CODING_STANDARDS.md` with the heading `## Entries` and three entries: "Public functions have
  a docstring", "Shell scripts quote every expansion", "A new CLI flag is listed in `--help`".
- No `retro-log.md`.

The ledger lines:

```
- PR #105 (2026-10-02) — rounds 1 — blocking: New config key has no stated default — answered: none — rulings: none — report: ~/.cache/runs/105/r1/report.md
- PR #107 (2026-10-04) — rounds 1 — blocking: none — answered: Unused import in the generated client (invalid) — rulings: none — report: ~/.cache/runs/107/r1/report.md
- PR #109 (2026-10-06) — rounds 2 — blocking: none — answered: none — rulings: Error message omits the failing path (reviewer Bar: non-blocking; ruled blocking because the body's bar names silent failure) — report: ~/.cache/runs/109/r2/report.md
- PR #112 (2026-10-09) — rounds 1 — blocking: New config key has no stated default — answered: none — rulings: none — report: ~/.cache/runs/112/r1/report.md
- PR #115 (2026-10-11) — rounds 1 — blocking: none — answered: Unused import in the generated client (invalid) — rulings: none — report: ~/.cache/runs/115/r1/report.md
- PR #118 (2026-10-14) — rounds 2 — blocking: Retry loop without a bound — answered: none — rulings: none — report: ~/.cache/runs/118/r2/report.md
- PR #121 (2026-10-17) — rounds 1 — blocking: Error message omits the failing path — answered: none — rulings: none — report: ~/.cache/runs/121/r1/report.md
```

The report files all exist. #105 C2 and #112 C4 are the config-key class, each with a `Rule:` of
"a new config key states its default and its reader". #107's report has the line `Refuted:
unused import in the generated client — the file is generated and excluded by the lint config`.
#118's round 1 report is at `~/.cache/runs/118/r1/report.md` (the ledger names only round 2's) and lists "Retry loop without a bound" as C3 and its round 2 report lists the
same class as `Still open` under C1; no other PR's report names it. #121 C1 is the
error-message class.

`gh` works. The operator's only message is the command; no proposal has been answered. The run
may write only `widgets-ai/.claude/memory-bank/retro-log.md` and, if the operator replies,
`widgets-ai/CODING_STANDARDS.md`; it writes nothing into `widgets/`.
