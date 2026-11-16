---
scenario_id: 10-empty-and-populated-worktree-dirs-halt
expected_outcome: halt
expected_reason: A4 counts only a directory that holds an entry. `.worktrees/sprint-3/` is empty, so it is named as residue and does not refuse on its own; `.worktrees/sprint-4/` holds a work directory, so A4 refuses and names its path. The refusal asks the operator whether each named item is work in flight or residue; adoption removes neither. A ceremony that refuses on sprint-3 alone, or passes sprint-4, is wrong.
---

`.ossify/topology.json` declares one repo, `canonical` (root
`/Users/ops/repos/ledger-api`, default branch `main`). The manifest's
`.during_dev.worktrees_dir` is `/Users/ops/repos/ledger-api/.worktrees`.
A0-A2 pass.

At A3, `git -C /Users/ops/repos/ledger-api status --porcelain --untracked-files=all`
prints nothing and the repo is on `main`. The AI workspace is its own git
repository (`rev-parse --show-toplevel` prints its root) and its porcelain is
empty.

At A4, `find /Users/ops/repos/ledger-api/.worktrees -mindepth 1 -maxdepth 1`
prints two directories:

- `/Users/ops/repos/ledger-api/.worktrees/sprint-3` — `ls -A` prints nothing.
- `/Users/ops/repos/ledger-api/.worktrees/sprint-4` — `ls -A` prints
  `vs-4.2`, a directory with a checked-out tree inside.

The legacy stack's `05-active-context.md` cursor sits on a boundary.
