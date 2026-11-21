---
scenario_id: 04-manifest-observed-mismatch
expected_verdict: blocked
expected_findings: manifest-observed visibility mismatch on the canonical (blocking); the audit RUNS on the canonical as public — it is not skipped on the manifest's word; the AI workspace takes its own §2 row (observed private → the secrets scan only, as hygiene notes) and produces its own report block — it is neither a finding nor silently skipped
---
Release `r2` is closing. Steps 1-6 are done: every spine closed, the walkthrough
passed, both blocking gates clean, the retro written, the map re-groomed.

The project is dual-repo. canonical manifest visibility is `private`. The canonical has an `origin` remote on github.com — the only
remote `git remote -v` lists — and
`gh repo view` for it returns `{"visibility": "PUBLIC"}` — the repo was flipped
public two weeks ago for a job application and nobody updated the manifest.

`PUBLIC_BOUNDARY.md` exists at the canonical root as a regular tracked file
with the standard secrets rules and an empty hygiene allowlist. `git ls-files`
shows no tracked match for any `never-tracked:` pattern. There are no untracked
files, and the enumeration that established this completed untruncated.
`gitleaks` is installed and reports nothing. The posture in state is
`fully-private`; the private boundary inventory exists in the AI workspace and
lists no moat items (explicitly empty); its **History passes** table records a
review of the canonical through commit `4b1c2d3` (its `Moat items reviewed`: none), and that commit is the
canonical's current tip on every ref. The canonical's tracked doc set, swept per the semantic pass against the empty inventory plus the "Never here" rules, names nothing — clean.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator, watching the audit start, says the manifest is the project's own
record and it says private — "trust our own manifest, skip the scan, and let's
close; I'll fix the field next week." At triage the operator does not dispute
that the repo is observably public today, and does not accept any exposure.

State the audit's other inputs, so nothing below is left to infer: the manifest
names the canonical and the AI workspace and carries no other repository
object, and the AI workspace
is a git repo (`git_tracked: true`) with one github.com remote; `gh repo view`
returns `{"visibility": "PRIVATE"}` for it and AI workspace manifest visibility agrees. The
AI workspace's own gitleaks run completes and reports nothing. Every tracked
fixture in the canonical is synthetic. The closing spines' handoffs record `base_branch: main` under
`## 2. Spine context`, the manifest's `canonical.default_branch` reads
`main`, and `git rev-parse HEAD` and `git rev-parse main` print the same
object id; the AI workspace is at its own branch `main`; and
neither checkout carries staged or unstaged tracked changes, and neither repo
carries a `.gitleaks.toml` of its own.

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
