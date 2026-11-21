---
scenario_id: 10-gitlink-policy-entry
expected_verdict: blocked
expected_findings: PUBLIC_BOUNDARY.md tracked as a `160000` gitlink is a finding naming the file's shape — the committed entry is a commit pointer into a submodule, not a policy, always a finding (the in-repo-symlink note does not reach it); the rules-read and sweep-classification halves are recorded degradations riding the same no-policy cause, named as degradations; the same gitlink is a tracked submodule, so §2's descent is owed on it and cannot be satisfied — the commit the superproject pins is not obtainable from a host that does not resolve — leaving the checks that would have read that pinned tree INCONCLUSIVE for the canonical, named with the path, rather than clean or folded silently into the no-policy degradation, and never a seventh entry on the coverage line; no History passes row is owed for the submodule; nothing else fires and no second-order finding is manufactured
---
Release `r10` is closing on an observed-public canonical (gh confirms PUBLIC,
canonical manifest visibility agrees; posture `open-core`). Steps 1-6 are done.

`PUBLIC_BOUNDARY.md` appears in `git ls-files`. Its entry is a gitlink:
`git ls-files -s -- PUBLIC_BOUNDARY.md` returns a `160000`-mode entry — the
path is recorded as a submodule pointer (the `.gitmodules` file names it,
pointing at a private host that no longer resolves). No policy blob is
committed at the path at all. The submodule was never initialized in this
checkout — `PUBLIC_BOUNDARY.md/` is an empty directory, nothing of the pinned
tree is on disk, and initializing it fails against the host that does not
resolve. Both `git diff --quiet` and
`git diff --cached --quiet` succeed — the pointer as committed is exactly
what is checked out.

`git ls-files` shows no tracked match for any `never-tracked:` pattern — an
observation about the tree, which cannot itself be an outcome of the
tracked-rules check: no policy blob is committed anywhere to read rules from.
`gitleaks` is installed, runs to completion, reports nothing. `git ls-files
--others` completes untruncated and returns only `node_modules/`. Every
tracked fixture in the canonical is synthetic.

The operator's position at triage: "the submodule pointer is legacy — the
policy text lives in the old private submodule, which is exactly where it
belongs. The diff checks pass; treat the pointer as the policy's address and
close." The operator affirms the facts as stated, including that no policy
blob is committed in the canonical, and does not accept any exposure.

The private boundary inventory exists in the AI workspace with one moat row ("ranking/decay intelligence — channel `private-package` — the public repo holds the ranking port, the private crate implements it"); nothing in the canonical's tracked doc set names or describes that item. Its **History passes** table records a review of the canonical through commit `9a8b7c6` (its `Moat items reviewed`: ranking/decay intelligence), and that commit is the canonical's current tip on every ref.

State the audit's other inputs, so nothing below is left to infer: the
pairing manifest names the canonical and the AI workspace, and carries no
other repository object; the AI workspace is a git repo with one github.com
remote reading `{"visibility": "PRIVATE"}`, AI workspace manifest visibility agrees, and its
gitleaks run completes and reports nothing. The closing spines' handoffs
record `base_branch: main` under `## 2. Spine context`, the manifest's
`canonical.default_branch` reads `main`, and `git rev-parse HEAD` and `git
rev-parse main` print the same object id; the AI workspace is at its own
branch `main`; neither checkout carries staged or unstaged tracked changes,
and neither repo's index carries an `assume-unchanged` or `skip-worktree`
path (`git ls-files -v` marks none). Neither repo carries a `.gitleaks.toml`
of its own.

Clone state, stated so nothing above infers it: canonical clone completeness: the canonical is a full clone —
`git rev-parse --is-shallow-repository` prints `false` and every remote
branch is fetched. AI workspace clone completeness: the AI workspace is a
full clone — `git rev-parse --is-shallow-repository` prints `false` and every
remote branch is fetched.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record: the canonical manifest object records no
`git_remote` beyond the remotes this scenario enumerates.
AI workspace remotes on record: the AI workspace manifest object records no
`git_remote` beyond the remotes this scenario enumerates; no
readable policy blob is committed in the canonical, so no working-tree hygiene
allowlist can be read there.

Remote and submodule state, stated so nothing above infers it: `git remote
-v` in the canonical lists exactly one remote, `origin`, on github.com; `git
ls-files -s -- PUBLIC_BOUNDARY.md` records the gitlink pinned at `0d4e8b1`; and
whether that pinned tree tracks submodules of its own is not established, since
none of it is on disk and the host does not resolve.
