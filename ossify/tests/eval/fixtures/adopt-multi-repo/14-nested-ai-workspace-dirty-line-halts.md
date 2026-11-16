---
scenario_id: 14-nested-ai-workspace-dirty-line-halts
expected_outcome: halt
expected_reason: The AI workspace sits inside another repository (`rev-parse --show-toplevel` prints the parent), so A3 sweeps only the workspace's own path (`status --porcelain --untracked-files=all -- .`) and names the nesting as a finding. That scoped sweep shows the uncommitted MASTER-SPEC edit, so A3 refuses, printing the line, and asks work in flight or residue. The parent's other dirty line is not the workspace's and does not refuse on its own. Skipping the workspace because it is not its own git root, which would let C5 reconcile over the hand-edit, is wrong.
---

The pairing manifest `.workspace/pairing.json` declares one repo, `canonical`
(root `/Users/ops/repos/atlas`, default branch `main`). A0-A2 pass.

At A3:

- `git -C /Users/ops/repos/atlas status --porcelain --untracked-files=all` — empty; on `main`.
- `git -C /Users/ops/notes/atlas-ai rev-parse --show-toplevel` (the AI
  workspace root is `/Users/ops/notes/atlas-ai`) prints `/Users/ops/notes`.
- `git -C /Users/ops/notes status --porcelain --untracked-files=all` prints two lines:
  ` M atlas-ai/docs/MASTER-SPEC.md` and ` M journal/2026-11.md`.
- `git -C /Users/ops/notes/atlas-ai status --porcelain --untracked-files=all -- .`
  prints one line: ` M atlas-ai/docs/MASTER-SPEC.md`. The operator started that
  hand-edit before running `/adopt` and never committed it.

No directory exists under `.worktrees`, and the legacy stack's
`05-active-context.md` cursor sits on a boundary.
