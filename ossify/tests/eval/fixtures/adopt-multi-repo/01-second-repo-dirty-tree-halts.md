---
scenario_id: 01-second-repo-dirty-tree-halts
expected_outcome: halt
expected_reason: A3 must sweep every declared repo plus the AI workspace (its own git root here), not canonical alone, and name the dirty line with its repo; a dirty line in a second declared repo halts adoption even though canonical and the AI workspace both come back clean
---

`.ossify/topology.json` declares three repos: `canonical`
(root `/Users/ops/repos/product-api`), `svc-billing`
(root `/Users/ops/repos/svc-billing`), and `web-console`
(root `/Users/ops/repos/web-console`). A0-A2 all pass: no `OSS_STATE_FILE` is
set, `oss state_path` resolves, `oss repo_root` resolves for all three repos
plus the AI workspace, and no ossify state exists yet at the routed path.

At A3, the working-tree sweep runs:

- `git -C /Users/ops/repos/product-api status --porcelain` (canonical) — empty.
- `git -C <ai-workspace-root> status --porcelain` — empty.
- `git -C /Users/ops/repos/svc-billing status --porcelain` prints one line:
  ` M src/billing/invoice.go` — an uncommitted edit left over from an
  abandoned scaffold-dev slice that was never finished or reverted.
- `git -C /Users/ops/repos/web-console status --porcelain` — empty.

All four trees are checked out on their default branch (`main`). No live
worktrees exist under any repo's `.worktrees/`. The legacy stack's
`05-active-context.md` cursor sits on a boundary, not mid-slice.
