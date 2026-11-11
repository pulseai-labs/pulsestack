---
scenario_id: 09-within-repo-case-variant-references-halt
expected_outcome: halt
expected_reason: C3 step 1a folds ADR-0007 and adr-0007 to one reference although both files sit in canonical, names ADR-0007-a.md and adr-0007-b.md and their repo, mints no bone and asks the operator to reconcile the collision
---

The topology declares canonical and svc-payments, both on recorded default
branch main. A0–A5 and C1–C2 passed; every repo and the AI workspace are clean,
no legacy worktrees survive, and the baseline table records each repo's HEAD.

canonical's docs/adr holds ADR-0007-a.md and adr-0007-b.md. The files describe
different decisions. svc-payments' docs/adr is empty. The bones registry is
empty. Continue adoption through C3.
