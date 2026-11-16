---
scenario_id: 12-ai-workspace-not-own-git-root-skips-sweep
expected_outcome: proceed
expected_reason: The AI workspace is in no repository (`rev-parse --show-toplevel` fails), so A3 skips only the workspace's porcelain half and names the skip for the adoption record; `git_tracked` is a hint, not the determination. Both declared repos are swept, clean and on main, and A4 and A5 raise nothing, so adoption proceeds and records a baseline table. Refusing because the workspace is not a repository is wrong.
---

The pairing manifest `.workspace/pairing.json` declares two repos: `canonical`
(root `/Users/ops/repos/atlas`, default branch `main`) and `worker` (root
`/Users/ops/repos/atlas-worker`, default branch `main`), and records
`ai_workspace.git_tracked: false`. A0-A2 pass.

At A3:

- `git -C /Users/ops/repos/atlas status --porcelain --untracked-files=all` — empty; on `main`.
- `git -C /Users/ops/repos/atlas-worker status --porcelain --untracked-files=all` — empty; on `main`.
- `git -C /Users/ops/notes/atlas-ai rev-parse --show-toplevel` (the AI
  workspace root is `/Users/ops/notes/atlas-ai`) exits 128 with
  `fatal: not a git repository (or any of the parent directories): .git`.

No directory exists under either repo's `.worktrees`, and the legacy stack's
`05-active-context.md` cursor sits on a boundary.
