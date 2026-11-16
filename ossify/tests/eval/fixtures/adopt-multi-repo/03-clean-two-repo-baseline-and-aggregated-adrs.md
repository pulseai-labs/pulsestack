---
scenario_id: 03-clean-two-repo-baseline-and-aggregated-adrs
expected_outcome: proceed
expected_reason: with every tree clean and every DECLARED repo on its recorded default branch (the AI workspace, its own git root, is checked for cleanliness only - A3 exempts it from the branch check and this scenario declares no default branch for it), A3-A5 raise nothing and adoption proceeds; the baseline must land as one SHA per declared repo (a table, not one SHA standing in for the product), and C3 must mint bones from ADRs found in BOTH repos' docs/adr/ directories, not canonical's alone
---

`.ossify/topology.json` declares two repos: `canonical`
(root `/Users/ops/repos/product-api`, default branch `main`) and
`svc-payments` (root `/Users/ops/repos/svc-payments`, default branch `main`).
A0-A2 pass. At A3, `git status --porcelain` against canonical, `svc-payments`,
and the AI workspace all print nothing, and both repos are checked out on
`main`. A4 finds no live worktrees under either repo's `.worktrees/`. A5
finds the legacy stack's active-context cursor on a boundary.

Current HEAD is `git -C /Users/ops/repos/product-api rev-parse HEAD` →
`a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1`, and
`git -C /Users/ops/repos/svc-payments rev-parse HEAD` →
`b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2`.

`/Users/ops/repos/product-api/docs/adr/` contains two files: `ADR-0001-hexagonal-core.md`
and `ADR-0002-postgres-for-ledger-storage.md`. `/Users/ops/repos/svc-payments/docs/adr/`
contains one file of its own: `ADR-0003-idempotency-key-on-charge-create.md` — a
decision recorded in `svc-payments`' own ADR sequence, unrelated in content to
canonical's `ADR-0001` and about a module (`src/payments/idempotency.rs`) that
lives only in `svc-payments`.
