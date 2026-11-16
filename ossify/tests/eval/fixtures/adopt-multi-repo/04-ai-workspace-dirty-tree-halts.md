---
scenario_id: 04-ai-workspace-dirty-tree-halts
expected_outcome: halt
expected_reason: this fixture targets ONE regression risk, not multi-repo generalization generally (01 and 02 cover that) — A3's sweep covers the AI workspace (its own git root here) as well as every declared repo, and folding "check the AI workspace" into "iterate the declared repos" must not silently drop it, since C5 edits it too and `ai_workspace` is not one of the topology's `.repos` entries; a dirty line there halts adoption even though every declared repo is clean and on its default branch. A ceremony still doing the old single-repo thing (checking canonical + a hardcoded ai_workspace) also halts here, for the same reason — this fixture does not by itself distinguish old from new behavior
---

`.ossify/topology.json` declares two repos: `canonical`
(root `/Users/ops/repos/product-api`, default branch `main`) and
`svc-billing` (root `/Users/ops/repos/svc-billing`, default branch `main`).
A0-A2 pass.

At A3, `git -C /Users/ops/repos/product-api status --porcelain` and
`git -C /Users/ops/repos/svc-billing status --porcelain` both print nothing,
and both repos are checked out on `main`. The AI workspace is its own git
repository: `git -C <ai-workspace-root> rev-parse --show-toplevel` prints
`<ai-workspace-root>`. But
`git -C <ai-workspace-root> status --porcelain` prints one line:
` M docs/MASTER-SPEC.md` — an in-progress hand-edit the operator started
before invoking `/adopt` and never committed.

No live worktrees exist under either repo's `.worktrees/`, and the legacy
stack's active-context cursor sits on a boundary.
