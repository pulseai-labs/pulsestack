---
scenario_id: 13-stale-backup-in-workspace-halts-naming-it
expected_outcome: halt
expected_reason: A3 refuses on the AI workspace's one porcelain line and prints it with its tree. The refusal asks the operator whether it is work in flight or residue, and gives both routes - work in flight goes through the slice close (by hand, since scaffold-dev is retired); residue is removed or committed by the operator, then adoption re-runs. Adoption does not delete the file, and does not tell the operator only to close a slice, which cannot clear a stale backup.
---

`.ossify/topology.json` declares one repo, `canonical` (root
`/Users/ops/repos/pulse-trader`, default branch `main`). A0-A2 pass.
scaffold-dev is no longer installed on this host.

At A3, `git -C /Users/ops/repos/pulse-trader status --porcelain --untracked-files=all`
prints nothing and the repo is on `main`. The AI workspace is its own git
repository. `git -C <ai-workspace-root> status --porcelain --untracked-files=all`
prints one line:

`?? .workspace/pairing.json.bak-20260630`

The file is 2653 bytes, last modified 2026-06-21, and is not git-ignored.
No directory exists under `.worktrees`, and the legacy stack's
`05-active-context.md` cursor sits on a boundary.
