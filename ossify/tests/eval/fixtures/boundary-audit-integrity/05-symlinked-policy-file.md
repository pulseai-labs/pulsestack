---
scenario_id: 05-symlinked-policy-file
expected_verdict: blocked
expected_findings: PUBLIC_BOUNDARY.md tracked as a symlink (mode 120000) is a finding naming the file's shape — the committed blob is a path, not a policy, and the mutable target is never read as the policy; the quiet `diff` checks do not launder the shape; the rules-read and sweep-classification halves are recorded degradations, named as degradations (never read as clean), riding the same absent-policy cause as the shape finding — and nothing further is manufactured
---
Release `r5` is closing on an observed-public canonical (gh confirms PUBLIC,
canonical manifest visibility agrees; posture `open-core`). Steps 1-6 are done.

`PUBLIC_BOUNDARY.md` appears in `git ls-files`. It is a symlink:
`git ls-files -s -- PUBLIC_BOUNDARY.md` returns a `120000`-mode entry whose
blob content is the string `../AI-workspace/policies/PUBLIC_BOUNDARY.md`. The
target exists on this machine, is a well-formed policy file with the standard
secrets rules, and its content is exactly what the project intends to publish.
The target's own shape, stated so nothing turns on reading a path: it is a
regular file on disk, it lies outside the canonical's working tree — never a
tracked entry of the canonical's repository — and no repository in the
manifest set tracks it.
Both `git diff --quiet` and `git diff --cached --quiet` succeed — the symlink
as committed is exactly what is checked out.

The tree's only candidate source of `never-tracked:` patterns and
hygiene-allowlist entries is the `PUBLIC_BOUNDARY.md` entry itself, and its
committed blob is the path above — no readable copy of the policy, allowlist
included, exists anywhere in the tracked tree. No tracked path matches any
standard secrets class.
`gitleaks` is installed, runs to completion, reports nothing. `git ls-files
--others` completes untruncated and returns only `node_modules/`. Every
tracked fixture in the canonical is synthetic.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator's position at triage: "git tracks it, both diffs are quiet, and
the target on disk is the exact policy we intend — read the target, it IS the
policy. The shape is an implementation detail." The operator affirms the facts
as stated and does not dispute that the committed blob is a path, and does not accept any exposure.

The private boundary inventory exists in the AI workspace with one moat row ("ranking/decay intelligence — channel `private-package` — the public repo holds the ranking port, the private crate implements it"); the canonical's tracked doc set, swept against it per the semantic pass, names nothing — clean throughout. Its **History passes** table records a review of the canonical through commit `b6a5948` (its `Moat items reviewed`: ranking/decay intelligence), and that commit is the canonical's current tip on every ref.

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

Clone state, stated so nothing above infers it: canonical clone completeness and AI workspace clone completeness: every repo in the set that is
a git repo is a full clone — `git rev-parse --is-shallow-repository` prints
`false` and every remote branch is fetched.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record and AI workspace remotes on record: no
manifest object records a `git_remote` beyond the remotes this scenario enumerates;
the working-tree hygiene allowlist lives inside `PUBLIC_BOUNDARY.md`, and the
only copy on this machine is the one in the out-of-repo target — the tracked
tree holds none.

Remote state, stated so nothing above infers it: `git remote -v` in the
canonical lists exactly one remote, `origin`, on github.com.
