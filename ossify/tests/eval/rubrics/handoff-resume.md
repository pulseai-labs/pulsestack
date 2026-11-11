# Rubric: handoff-resume

Score each 1-5. Pass = all ≥4.

This surface scores the **resume-mode judgment** of
`ossify/skills/handoff-resume/references/resume.md` — re-verifying a handoff's claims
against the live repo, reporting drift, and rendering a verdict. Resume never
refuses; the judgment under test is whether drift is detected, read correctly,
and never invented.

**Every criterion is scored on every fixture.** Each names a thing resume may
report, and on a scenario that does not warrant it the criterion scores
whether the output correctly **declined** to report it. There is no N/A.
Scoring convention: 4 = consistent with the criterion; 5 = demonstrated (the
reasoning is stated, not just the conclusion).

1. **Drift detected** — every claim whose check now disagrees is named with
   was → now, and the *reading* is judged: drift that is the expected progress
   (a merged PR, work completed) is said to be that, and the verdict follows
   the reading — superseded steps are skipped, not re-executed; a sequence
   whose preconditions are gone is not blindly followed. On a clean scenario,
   this criterion scores the clean report's completeness (all claims checked,
   each stated as holding).
2. **No false drift** — nothing is invented: a document's age is surfaced as
   context, never converted into drift; a cited file that was *modified* but
   exists is not drift (references are verified for existence, not contents);
   a claim that holds exactly is reported as holding. Real numeric movement is
   reported as drift without being inflated into alarm.
3. **Missing reference reported** — a cited path that no longer exists is
   reported as drift, with the likely successor named when the repo's history
   shows one (a rename, a replacement file), and resume *continues* — treating
   it as fatal and silently skipping it are both wrong. On a scenario where
   every reference resolves, this criterion scores that resolution being
   checked and said (existence-only, contents unread until a step needs them).
4. **Work order recognised** — when the named file is a per-work-item
   `handoff.md` (a work order, not session state), the read-out's first line
   says it is a work order and not session state, the verdict is `stale —
   re-plan before acting`, none of the file's steps is worked, and the drift
   report is still given. For a session handoff the output does not call it a
   work order and gives no work-order verdict.

## Output format
`{"scores":{"drift_detected":N,"no_false_drift":N,"missing_reference_reported":N,"work_order_recognised":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
