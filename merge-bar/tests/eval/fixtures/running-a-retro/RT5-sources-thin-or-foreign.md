---
scenario_id: RT5-sources-thin-or-foreign
expected_outcome: continue-and-name-the-cause
expected_reason: four variants, each answered on its own. A) the ledger names a report file that is not on disk: the run continues from the ledger and the other report, says the file is missing, and still proposes the class that two PRs show. B) `--reports` holds two reports whose PR header names another repository, one with the template header and one file with no `PR:` header at all: all four are skipped and counted (4 skipped), and the two reports for acme/widgets are read. C) `gh` is unavailable and the ledger is empty: zero proposals, and the read-out names those two causes, not "no history". D) `gh` is unavailable and the ledger is populated: the window is undetermined and the read-out says so (a run line, if written, reads `window undetermined (gh unavailable), <n> ledger lines`), every ledger line counts, and the class that #184 and #188 show is proposed. In every variant nothing is written without a reply
---
Four separate runs, each with its own state; answer each as its own run and label the
answers A, B, C and D. All run today, 2026-10-31, from `/home/dev/projects/widgets` of the repo
`acme/widgets`; its parent directory holds `widgets/` and `widgets-ai/`, and
`widgets-ai/.workspace/pairing.json` has `canonical.name` = "widgets" (only that directory
matches). In every variant `CODING_STANDARDS.md` in `widgets-ai/` has `## Entries` with one
entry, "Shell scripts quote every expansion"; there is no `retro-log.md`; `tech-debt.md` has no
line naming a PR in the window; the operator's only message is the command and no proposal has
been answered. Each run may write only `widgets-ai/.claude/memory-bank/retro-log.md` and, if the
operator replies, `widgets-ai/CODING_STANDARDS.md`; none writes into `widgets/`.

**Variant A.** Command: `/merge-bar:retro --last 10`. `gh` works and returns merged PRs #161 to
#170. `widgets-ai/.claude/memory-bank/review-ledger.md` has lines for #162 and #167, both
blocking "Cleanup helper deletes outside its target directory". #162's line names the report
`~/.cache/runs/162/r1/report.md`, which does not exist (the cache was cleared). #167's report
`~/.cache/runs/167/r1/report.md` exists and holds that class as C2.

**Variant B.** Command: `/merge-bar:retro --last 10 --reports /home/dev/.cache/reports`. `gh`
works and returns merged PRs #171 to #180. `review-ledger.md` is headed
`# Review ledger — widgets` and has no lines. `/home/dev/.cache/reports` holds six files:
`a.md` (`PR: acme/widgets#172`) and `b.md` (`PR: acme/widgets#176`), both holding the class
"Retry on a non-idempotent call" as C1; `c.md` and `d.md` (`PR: acme/other-service#172` and
`PR: acme/other-service#176`), both holding a different class; `e.md`, whose first line is the
unfilled template header `PR: <owner/repo#N>`; `f.md`, whose first line is `# Notes on retry policy`
and which has no `PR:` line anywhere.

**Variant C.** Command: `/merge-bar:retro`. `gh` is not available in this environment: `gh`
exits with "command not found". `review-ledger.md` exists, headed `# Review ledger — widgets`,
with no lines. There is no `--reports` flag. No other review ledger exists in `widgets-ai/`.

**Variant D.** Command: `/merge-bar:retro --last 10`. `gh` is not available: it exits with
"command not found". `review-ledger.md` has lines for #184 and #188, both blocking "Timeout
swallowed and reported as success", with reports on disk that hold the class as C3 and C1. There
is no `--reports` flag.
