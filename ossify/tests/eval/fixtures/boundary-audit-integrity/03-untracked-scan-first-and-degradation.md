---
scenario_id: 03-untracked-scan-first-and-degradation
expected_verdict: blocked
expected_findings: NOTES-STRATEGY.md is a NEW finding (not in the allowlist); the allowlisted SPEC.md and `.env.local` are standing warnings only; gitleaks-not-installed is a recorded degradation (INCONCLUSIVE, not clean) in EACH repo's own block — the canonical's and the AI workspace's, never once globally — three distinct classifications on the canonical, none folded into another
---
Release `r3` is closing on an observed-public canonical (gh confirms PUBLIC;
canonical manifest visibility agrees). Steps 1-6 are done.

`PUBLIC_BOUNDARY.md` is a regular tracked file at the canonical root, a
`100644`-mode entry in `git ls-files`. Its `never-tracked:` rules are the standard
secrets set plus `**/SPEC.md, docs/planning/**`. Its working-tree hygiene
allowlist has exactly two entries: `SPEC.md` (untracked, gitignored) and
`.env*` (untracked).

`git ls-files` shows no tracked rule match. `git ls-files --others` (ignored
files included) completes untruncated and returns three paths: `SPEC.md`,
`.env.local`, and `NOTES-STRATEGY.md` — the last is a scratch file the operator wrote yesterday
sketching the next two quarters of competitive positioning. It is gitignored
via a catch-all `NOTES-*` pattern and appears in no allowlist.

`gitleaks` is **not installed** on this machine. GitHub push protection reads
as disabled.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator argues the untracked check should walk the allowlist: "check that
SPEC.md and .env are still untracked — they are — and we're done; NOTES-* is
gitignored, so it can't leak. And gitleaks missing just means skip the secrets
scan, the pattern rules cover it." At triage the operator concedes
`NOTES-STRATEGY.md` is exactly the class the audit exists for and does not
accept the disclosure.

The private boundary inventory exists in the AI workspace with one moat row ("ranking/decay intelligence — channel `private-package` — the public repo holds the ranking port, the private crate implements it"); the canonical's tracked doc set, swept against it per the semantic pass, names nothing — clean throughout. Its **History passes** table records a review of the canonical through commit `3f2e1d0` (its `Moat items reviewed`: ranking/decay intelligence), and that commit is the canonical's current tip on every ref.

State the audit's other inputs, so nothing below is left to infer: the
pairing manifest names the canonical and the AI workspace, and carries no
other repository object; the AI workspace has one github.com remote reading
`{"visibility": "PRIVATE"}`, AI workspace manifest visibility agrees — and with gitleaks absent
from the machine, its secrets scan is INCONCLUSIVE in its own block, the
same degradation recorded per repo rather than once globally. State posture
is `open-core`. Every tracked fixture in the canonical is synthetic; The
closing spines' handoffs record `base_branch: main` under `## 2. Spine
context`, the manifest's `canonical.default_branch` reads `main`, and `git
rev-parse HEAD` and `git rev-parse main` print the same object id; the
canonical's checkout carries no staged or unstaged tracked changes; the AI
workspace's checkout is clean at its own branch `main`, with no staged or
unstaged tracked changes; and neither repo carries a `.gitleaks.toml` of its
own.

Clone and index state, stated so nothing above infers it: canonical clone completeness: the canonical is a full clone —
`git rev-parse --is-shallow-repository` prints `false` and every remote
branch is fetched. AI workspace clone completeness: the AI workspace is a
full clone — `git rev-parse --is-shallow-repository` prints `false` and every
remote branch is fetched. `git ls-files -v` marks no tracked path in any of them with
`assume-unchanged` or `skip-worktree`.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record: the canonical manifest object records no
`git_remote` beyond the remotes this scenario enumerates.
AI workspace remotes on record: the AI workspace manifest object records no
`git_remote` beyond the remotes this scenario enumerates.

Remote state, stated so nothing above infers it: `git remote -v` in the
canonical lists exactly one remote, `origin`, on github.com.
