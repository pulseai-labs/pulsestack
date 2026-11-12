# Spine close, second pass

The spine PR is merged. First `git fetch origin` in the AI workspace, then check, in this order. Never treat the branch's own state file as the result: only `origin/main` counts.

1. If the project state file at `origin/main` (`git show origin/main:<path>`) already reads the spine closed, end the turn without rerunning close and without a commit.
2. If `close-pr.txt` exists in OUT, an earlier attempt already opened the close PR: end the turn without rerunning close. Never merge the close PR.

Whichever way the turn ends, leave the AI workspace on `main`: `git switch main`.

Otherwise run `/ossify:close <spine>` on Claude Code, `skill://close <spine>` on OMP, through its second pass: record the landing, then the demo, bone registration, audit, retro and harvest. In the same pass:

- **Review ledger.** Write merge-bar working-a-pr §5's lines into this workspace's `.claude/memory-bank/`: one `review-ledger.md` line per merged PR of the spine (each item's `pr_url` in the project state, and the spine PR), the `tech-debt.md` `[KL]` lines from each merged PR's final `## Known limits`, and a `[TD]` line for its `outside scope → #N` issue, if any. Skip a PR whose `PR #N` line is already in `review-ledger.md`, and any tech-debt line already there: a rerun writes nothing twice. Rounds come from the review files under `<Out root>/<unit>/` (`review-<n>.md`, then `review.md`), class names from those reviews, `rulings:` from the archived `operator-<n>.md` files, `report:` is the last review file's path. §5 leaves its files uncommitted; here they go in the commit below.
- **Harvest.** Write §6's numbered, tagged candidate list to `harvest.md` in OUT and under a `## Harvest candidates` heading in the close PR body, where there is one; skip §7 and finish the rest of close. Accept none and apply nothing (no §7 append): the operator accepts, and the orchestrator applies.

Commit the ledger and those memory-bank lines with the close record. Then land that commit before ending the turn:

- In a workspace that lands records only through PRs, do not push to `main`: commit on a branch, push it, open the PR, and write its URL as one line to `close-pr.txt` in OUT at once (write `close-pr.txt.tmp`, then `mv` it over), then `git switch main`. Never merge the close PR.
- Otherwise push the AI workspace commit the close made (`git push` in the AI workspace).
