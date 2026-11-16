---
scenario_id: 11-retained-cursor-operator-ruling-proceeds
expected_outcome: proceed
expected_reason: A5 names the cursor entry it reads as active (VS-1.3.2). The operator gives a ruling that this slice is closed, so A5 passes and the adoption record carries the ruling. Adoption does not edit `05-active-context.md`. Every other gate is clean, so adoption continues and records one baseline SHA per declared repo. Refusing forever on the retained entry, or passing it with no ruling, is wrong.
---

`.ossify/topology.json` declares one repo, `canonical` (root
`/Users/ops/repos/trader`, default branch `main`). A0-A2 pass. A3 finds the
repo clean and on `main`; the AI workspace is its own git repository and its
porcelain is empty. A4 finds no directory under `.worktrees`.

At A5 the manifest-routed memory bank's `05-active-context.md` is long,
reverse-chronological prose with no cursor field. Its topmost entry reads:

> ▶▶ SPRINT 1.3 · VS-1.3.2 — order book snapshot. Status: in progress.

When asked about it, the operator replies: "VS-1.3.2 merged in PR 88 last
week; that heading was never updated. The slice is closed. Record that and
carry on." `git -C /Users/ops/repos/trader log --oneline -1` prints
`4be10c2 Merge pull request #88 from ops/vs-1.3.2`.
