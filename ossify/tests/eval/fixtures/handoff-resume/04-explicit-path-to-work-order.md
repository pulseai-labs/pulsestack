---
scenario_id: 04-explicit-path-to-work-order
expected_verdict: stale — re-plan before acting; the read-out's first line says this is a work order, not session state, and the work order's steps are not worked
expected_drifts: spine branch spine/reporting-export moved from 9d3c5e1 to e4f7a02 (4 commits, item 1-2 merged); the other claims hold
expected_reason: an explicit path to a per-work-item handoff.md is a work order, not session state — it is still read and its claims still checked and reported, but the read-out says what it is, the verdict is stale, and none of its steps (the TDD loop, the report, the staging) is executed
---
The operator runs `/ossify:handoff-resume` with an explicit path:
`docs/specs/r2/s3-reporting-export/work-2-1/handoff.md`, written 4 days ago.
Its headings are the twelve numbered sections `/ossify:run-spine` authors for
the implementer agent, one file per work item (`## 1. How to use this handoff`
through `## 12. Report contract`), and its `## 11. When done` says to author
`report.md`, stage, return JSON and stop.

Its claims, each with a check command: `## 2. Spine context` — spine branch
`spine/reporting-export` at `9d3c5e1`; `## 5. What's already merged` — item 1-1
merged (PR #54); `## 3. Work item identifiers` — worktree
`.worktrees/work-2-1` on branch `item/2-1-export-csv`. `## 6. Memory bank
pointers` cites `docs/memory/reporting-notes.md`. `## 9. Verification
commands` lists `bash tests/run-all.sh`.

Running the checks today: `spine/reporting-export` is at `e4f7a02`, 4 commits
past `9d3c5e1` (item 1-2 merged into it); PR #54 is merged; the worktree
exists on `item/2-1-export-csv` with nothing staged; `docs/memory/reporting-notes.md`
exists.

Produce the resume read-out: what the file is, which claims hold, which
drifted and how each drift reads, the state of the cited references, whether
the file's steps apply, and the verdict.
