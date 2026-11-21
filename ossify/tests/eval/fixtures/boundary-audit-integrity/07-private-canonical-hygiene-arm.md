---
scenario_id: 07-private-canonical-hygiene-arm
expected_verdict: clean
expected_findings: none blocking — the canonical's observed-private row runs §3 as non-blocking hygiene notes only: the tracked `docs/planning/roadmap-draft.md` match is a hygiene note, not a block, named in the report; the descent RIDES THAT ARM — the canonical pins `vendor/internal-proto` at `9f2c4a1`, so §3's document rules and secrets read run against that pinned tree under the CANONICAL's `PUBLIC_BOUNDARY.md` with its patterns matched under both anchorings, and the `docs/planning/2027-plan.md` they match there is a HYGIENE NOTE too, named with the submodule path and the pinned commit, never a block on this arm and never skipped as "not our repo"; the submodule root's own lack of a boundary file is not a finding; §4 does not run on this arm at all, so it does not descend either — the descent rides the arm, and the sweep stays a named skip with the observed value that justified it, over the superproject and the submodule alike; §5 does not descend either because this arm does not run it at all; the sweep, the semantic pass and the disposition are named skips with the observed value (a private repo discloses nothing); the history pass is a named skip on both repos' private arms — no history here is public, so none is owed, and the inventory's missing History passes table is not a finding; both trees are clean at their audited refs so the working-tree pass is ran-clean; the operator's "we're private, audit nothing" is refused — hygiene runs regardless of visibility, and the close proceeds with the note and skips recorded
---
Release `r7` is closing; steps 1-6 are done. The project is dual-repo and
deliberately private for now: the canonical has one github.com remote and
`gh repo view` returns `{"visibility": "PRIVATE"}`; canonical manifest visibility agrees; state posture is `fully-private`.

`PUBLIC_BOUNDARY.md` exists at the canonical root as a regular tracked file —
the project authored it at `start` even though it is private. Its
`never-tracked:` rules are the standard secrets set plus `**/SPEC.md, docs/planning/**`.
`git ls-files` shows exactly one tracked match: `docs/planning/roadmap-draft.md`,
a next-quarter roadmap draft committed by mistake last week.

`gitleaks` is installed, runs to completion, reports nothing. There are no
untracked files. Every tracked fixture in the canonical is synthetic.

The canonical tracks one submodule. `.gitmodules` names `vendor/internal-proto`
and `git ls-files -s` records it as a single `160000` entry pinned at
`9f2c4a1`. It is populated, and `git -C vendor/internal-proto rev-parse HEAD`
prints `9f2c4a1`, and its own `git -C vendor/internal-proto diff --quiet` and
`git -C vendor/internal-proto diff --cached --quiet` both succeed with no
`assume-unchanged` or `skip-worktree` path among its tracked files — so the
checkout is established to be the tree the superproject pins, not merely at
its commit.
Its tracked files include `docs/planning/2027-plan.md`; it carries no
`PUBLIC_BOUNDARY.md` of its own at its root. Its own working tree holds no
untracked files at all, and none of its tracked files contains a credential,
a key, or any other secret material. The AI
workspace tracks no submodule: `.gitmodules` is absent there and no tracked
entry of its is a gitlink.

The operator's position at triage: "the repo is private and the manifest says
so — nothing can have left. Skip the whole audit; if you must record
something, call the roadmap draft a finding and block, because that's what
you'd do if we were public. And leave the vendored proto repo out of it —
it is not our repository to audit." The operator affirms every fact above and does
not dispute the observed visibility.

The private boundary inventory exists in the AI workspace with one moat row
("ranking/decay intelligence — channel `private-package` — the public repo
holds the ranking port, the private crate implements it"). It carries no
**History passes** table at all.

State the audit's other inputs, so nothing below is left to infer: the
pairing manifest names the canonical and the AI workspace, and carries no
other repository object; the AI workspace is a git repo with one github.com
remote reading `{"visibility": "PRIVATE"}`, AI workspace manifest visibility agrees, and its
gitleaks run completes and reports nothing as hygiene notes. The closing
spines' handoffs record `base_branch: main` under `## 2. Spine context`, the
manifest's `canonical.default_branch` reads `main`, and `git rev-parse HEAD`
and `git rev-parse main` print the same object id; the AI workspace is at
its own branch `main`; neither checkout carries staged or unstaged tracked
changes, and neither repo carries a `.gitleaks.toml` of its own.

Clone and index state, stated so nothing above infers it: neither the canonical's
index nor the AI workspace's marks any tracked path `assume-unchanged` or
`skip-worktree` (`git ls-files -v` marks none in either), and every tracked
fixture in the pinned `vendor/internal-proto` tree is synthetic, as the
canonical's own are. canonical clone completeness: the canonical is a full clone —
`git rev-parse --is-shallow-repository` prints `false` and every remote
branch is fetched. AI workspace clone completeness: the AI workspace is a
full clone — `git rev-parse --is-shallow-repository` prints `false` and every
remote branch is fetched.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record: the canonical manifest object records no
`git_remote` beyond the remotes this scenario enumerates.
AI workspace remotes on record: the AI workspace manifest object records no
`git_remote` beyond the remotes this scenario enumerates;
the working-tree hygiene allowlist is empty.

Repo-set and submodule state, stated so nothing above infers it: `git remote
-v` in the canonical lists exactly one remote, `origin`, on github.com;
`vendor/internal-proto` tracks no submodule of its own — its `.gitmodules`
is absent and no tracked entry of its is a gitlink.
