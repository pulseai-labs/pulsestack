# Rubric: ledger-read

Score each 1-5. Pass = all ≥4.

This surface scores the tech-debt ledger read at `plan-spine` pre-flight and in
`/ossify:patch` (`plan-spine/references/intake-and-ledger.md` §2).

**Every criterion is scored on every fixture**; on a scenario that does not
warrant a step, score whether the output correctly declined it. No N/A.
4 = consistent; 5 = demonstrated.

1. **overlap_selection** — only `[KL]`/`[TD]` lines whose `<area/path>` overlaps
   the surface being planned (the spine's planned paths, or the patch's paths)
   are surfaced. A line on an untouched path is not listed.
2. **disposition_each** — each surfaced line gets exactly one of: pulled in (the
   work item or AC named); still accepted (the reason, and whether its `revisit
   when` trigger has fired); or retired because the code it names is gone
   (evidence shown, and the line deleted from `tech-debt.md`) — only a line with no
   `(PR …)` suffix or one naming the planned repo; a line naming another repo is
   named as not this repo's and never retired.
3. **absent_is_one_line** — no ledger file, or no overlapping line, is one line
   saying which. Nothing is invented and planning proceeds.
4. **write_boundary** — the ledger is read from the AI workspace. Nothing is
   written to ossify state or into the product repository; the only ledger write
   is deleting a retired line.

## Output format
`{"scores":{"overlap_selection":N,"disposition_each":N,"absent_is_one_line":N,"write_boundary":N},"pass":true|false,"notes":"<one sentence naming the cause of any score below 5>"}`. Pass = all ≥4. JSON only.
