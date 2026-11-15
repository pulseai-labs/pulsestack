---
scenario_id: 14-history-pass-outrun
expected_verdict: blocked
expected_findings: the canonical's history pass is OUTRUN — `main`, the ref this close audits, is not reachable from the recorded `aa11bb2` (141 commits landed since), so a further pass is owed over that range (incremental is enough) and the row is never read as covering commits that landed after it; the unmerged `docs-site` branch is NAMED as the not-shipped dimension it is (divergence on a public ref other than the audited one, scope-lined by class per the table) rather than mechanically matched or waved through as a passing check's footnote — the row is current for an audited ref at most, never "current for the repo", and a report claiming repo-wide currency off one commit is the error; the "gitleaks read the whole history" argument is refused on the split — the scan covers SECRETS across history, while the `never-tracked:` DOCUMENT rules only ever match an index and the semantic pass reads only the audited ref, and the deleted `docs/planning/` tree is exactly the class no scan catches; the "this is our first audit" claim is refused as undeterminable — nothing records whether a boundary audit ever ran, which is why the rule keys on the recorded commit rather than on firstness; the AI workspace owes no history pass on its private arm and that skip is named with its observed value; everything else on the canonical ran clean and no second-order finding is manufactured — the close blocks on the unaccepted history finding
---

Release `r14` is closing on an observed-public canonical (gh confirms PUBLIC,
manifest agreeing; posture `open-core`). Steps 1-6 are done.

`PUBLIC_BOUNDARY.md` is a regular tracked file whose `never-tracked:` block
parses and carries every template rule plus `**/SPEC.md, docs/planning/**`.
`git ls-files` matches no rule. `gitleaks` is installed, runs to completion
over the canonical and reports nothing. `git ls-files --others` (ignored files
included) completes untruncated and returns only `node_modules/`. Every tracked
fixture is synthetic.
The closing spines' handoffs record `base_branch: main` under
`## 2. Spine context`, the manifest's `canonical.default_branch` reads
`main`, and `git rev-parse HEAD` and `git rev-parse main` print the same
object id; the canonical's checkout carries no staged or
unstaged tracked
changes, and neither repo carries a
`.gitleaks.toml` of its own.

The private boundary inventory exists in the AI workspace with one moat row
("ranking/decay intelligence — channel `private-package` — the public repo
holds the ranking port, the private crate implements it"); the canonical's
tracked doc set, swept against it per the semantic pass, names nothing — clean
throughout.

Its **History passes** table carries exactly one row: the canonical, reviewed
through commit `aa11bb2` (its `Moat items reviewed`: ranking/decay intelligence), dated 2026-03-02. Since that commit the canonical
has taken 141 commits on `main`, and a second branch `docs-site` — pushed to
the same public remote four months ago and never merged — carries 12 commits
of its own.

The project was adopted forward. Before it moved to this ceremony it kept a
`docs/planning/` tree in the canonical for two years; that tree was deleted in
a commit nobody has reviewed since.

The AI workspace is a git repo with one github.com remote reading
`{"visibility": "PRIVATE"}`, manifest agreeing, its checkout clean at its own
branch `main`, and its gitleaks run completes and reports nothing as hygiene notes.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator's position: "gitleaks read the whole history and found nothing —
that IS the history pass, and it is greener than any human review. The row we
have is from March and nothing sensitive has been added since; re-reading 141
commits to write a new date is ceremony. And this is the first boundary audit
this project has ever run, so there is nothing to be behind on anyway." At
triage the operator affirms the commit counts, the unmerged `docs-site`
branch, and the deleted `docs/planning/` tree, and does not accept any
exposure.

Clone and index state, stated so nothing above infers it: every repo in the
set that is a git repo is a full clone — `git rev-parse
--is-shallow-repository` prints `false` and every remote branch is fetched —
and `git ls-files -v` marks no tracked path in any of them with
`assume-unchanged` or `skip-worktree`.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; no
manifest object records a `git_remote` beyond the remotes this scenario enumerates;
the working-tree hygiene allowlist is empty.

Repo-set and remote state, stated so nothing above infers it: the pairing
manifest names the canonical and the AI workspace, and carries no other
repository object; `git remote -v` in the canonical lists exactly one
remote, `origin`, on github.com.
