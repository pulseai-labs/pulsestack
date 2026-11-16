---
scenario_id: 12-ai-workspace-not-own-git-root-skips-sweep
expected_outcome: proceed
expected_reason: The AI workspace is not its own git root (`rev-parse --show-toplevel` prints its parent), so A3 skips only the workspace's porcelain half and names the skip for the adoption record; `git_tracked` is a hint, not the determination. Both declared repos are swept, clean and on main, and A4 and A5 raise nothing, so adoption proceeds and records a baseline table. Running `git status` against the parent repo and refusing on its lines, or refusing because the workspace is not a repository, is wrong.
---

`.ossify/topology.json` declares two repos: `canonical` (root
`/Users/ops/repos/atlas`, default branch `main`) and `worker` (root
`/Users/ops/repos/atlas-worker`, default branch `main`). The pairing manifest
records `ai_workspace.git_tracked: false`. A0-A2 pass.

At A3:

- `git -C /Users/ops/repos/atlas status --porcelain --untracked-files=all` — empty; on `main`.
- `git -C /Users/ops/repos/atlas-worker status --porcelain --untracked-files=all` — empty; on `main`.
- `git -C /Users/ops/notes/atlas-ai rev-parse --show-toplevel` (the AI
  workspace root is `/Users/ops/notes/atlas-ai`) prints `/Users/ops/notes`:
  the workspace sits inside the operator's notes repository.
- `git -C /Users/ops/notes status --porcelain` would print 14 lines, all
  outside `atlas-ai/`.

No directory exists under either repo's `.worktrees`, and the legacy stack's
`05-active-context.md` cursor sits on a boundary.
