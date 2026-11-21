---
scenario_id: 08-public-workspace-full-arm
expected_verdict: blocked
expected_findings: the AI workspace observed public (the most-public rule over its two remotes) is a blocking finding on its own — the role is private by construction, and the manifest-private/observed-public disagreement is the same event's intent mismatch; the visibility finding blocks on visibility alone — `strategy/2027-plan.md` may be named in its why as what the mirror serves (operator-affirmed context, assessed as already disclosed: removal does not untrack the mirror's history), never as a separate "strategy finding" no shipped check produces; the exposure is never a skip and never "nothing to check there"; the tracked-rules and sweep-classification halves degrade on the never-expected policy input (no PUBLIC_BOUNDARY.md is routed to the role), named as degradations riding the exposure — never read as clean, and the workspace's history pass degrades the same way and for the same reason (its arm runs, but no policy input is routed to the role, so there are no document rules to review its history against) rather than becoming a separate absent-row finding; the canonical block is clean and kept distinct — its History passes row is current for its tips
---
Release `r8` is closing; steps 1-6 are done. The project is dual-repo. The
canonical is clean end to end: exactly one remote, `origin`, on github.com —
the only remote `git remote -v` lists there — reading
`{"visibility": "PUBLIC"}`, `PUBLIC_BOUNDARY.md` a regular tracked file with
the full template rules, no tracked or untracked hits (the untracked
enumeration completing untruncated), `gitleaks` clean,
posture `open-core`, every fixture synthetic.

The AI workspace is a git repo. AI workspace manifest visibility is `private` and its `origin` remote reads
`{"visibility": "PRIVATE"}` — but it also carries a second remote, `backup`,
pointing at a different github.com repository, and `gh repo view` for that one
returns `{"visibility": "PUBLIC"}`. Someone set up a mirror two months ago
and forgot.

The workspace's tracked files include `strategy/2027-plan.md` — next year's
pricing and partnership strategy. There is no `PUBLIC_BOUNDARY.md` in the
workspace and never has been. `gitleaks` runs to completion on the workspace
and reports nothing. The workspace's untracked set is empty, its enumeration
completing untruncated.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator's position: "origin is private and the manifest says private —
the mirror is a backup nobody reads. And the workspace isn't supposed to have
a boundary file anyway, so there's nothing to check there. Audit the
canonical, skip the workspace, close." At triage the operator affirms both
remotes and the mirror's visibility, and does not accept the exposure.

The private boundary inventory exists in the AI workspace with one moat row ("ranking/decay intelligence — channel `private-package` — the public repo holds the ranking port, the private crate implements it"); the canonical's tracked doc set, swept against it per the semantic pass, names nothing — clean throughout. Its **History passes** table records a review of the canonical through commit `7c6b5a4` (its `Moat items reviewed`: ranking/decay intelligence) — the canonical's current tip on every ref — and carries no row for the AI workspace.

State the audit's other inputs, so nothing below is left to infer: the closing spines' handoffs record `base_branch: main` under
`## 2. Spine context`, the manifest's `canonical.default_branch` reads
`main`, and `git rev-parse HEAD` and `git rev-parse main` print the same
object id; the AI workspace is at its own branch `main`; neither
checkout carries staged or unstaged tracked changes, and neither repo carries
a `.gitleaks.toml` of its own.

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
`git_remote` beyond the remotes this scenario enumerates;
the working-tree hygiene allowlist is empty.

Repo-set and manifest state, stated so nothing above infers it: the pairing
manifest names the canonical and the AI workspace, and carries no other
repository object; canonical manifest visibility is `public`, agreeing with the observed read.
