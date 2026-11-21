---
scenario_id: 13-prior-override-resurfaces
expected_verdict: blocked
expected_findings: the prior Accepted disclosures row is NOT an erasure — it re-surfaces at this close as a standing warning, restated in the report rather than silently honoured; but the row pins the exact surface it covered (README.md at content hash `a1b2c3d` and commit `9f8e7d6`) and the section has since GROWN two paragraphs naming the cold-start heuristic, so the current surface is not the covered one — a change to the pinned surface is a FRESH S1 finding, and where it is arguable it is fresh; the operator's "the override already covers that section" is refused on the pin, not on the risk; the operator's fallback — adding `docs/internal/**` to the hygiene allowlist to reclassify the untracked `docs/internal/pricing-teardown.md` hit — is refused as an allowlist edit mid-audit AND named as what it actually is: allowlisting is not a cheaper override, so an entry added in response to a finding is recorded as an accepted disclosure like any other; the second inventory row's pricing-model item is untouched by any override and the tracked prose discloses nothing about it (S3); verdict is blocked — a fresh S1 plus an unaccepted untracked finding, with the prior override recapped as a standing warning and NOT read as covering either
---
Release `r7` of an open-core project is closing; steps 1-6 are done. The
canonical is observed PUBLIC on `gh` and canonical manifest visibility agrees; state posture is
`open-core`.

`PUBLIC_BOUNDARY.md` is a regular tracked file whose machine-checkable block
parses and carries every template rule plus `docs/planning/**`; `git ls-files`
matches no rule; `gitleaks` is installed, runs to completion and reports
nothing; every tracked fixture is synthetic. The closing spines' handoffs record `base_branch: main` under
`## 2. Spine context`, the manifest's `canonical.default_branch` reads
`main`, and `git rev-parse HEAD` and `git rev-parse main` print the same
object id; the canonical's checkout carries no staged or
unstaged tracked changes; and neither repo carries a `.gitleaks.toml`.

The private boundary inventory (AI workspace) carries two moat rows:
"ranking/decay intelligence — channel `private-package` — the public repo holds
the ranking port, the private crate implements it", and "pricing-model
internals — channel `repo-private` — a private crate, never ported".

It also carries one **Accepted disclosures** row, written at release `r2`:

| Release | Finding | Surface covered (pinned) | Reason | Date |
|---|---|---|---|---|
| r2 | README "How ranking works" section — S1, walks the decay curve and the three ranking signals | `README.md`, content hash `a1b2c3d`, read at commit `9f8e7d6` | deliberate commercial-edition marketing, owner signed off | 2026-05-04 |

The inventory's **History passes** table records a review of the canonical
through commit `d4c3b2a` (its `Moat items reviewed`: ranking/decay intelligence, pricing-model internals), and that commit is the canonical's current tip on
every ref.

Since `r2` that README section has grown. It now carries two further
paragraphs, added this release, describing the cold-start heuristic the ranker
falls back to when a user has fewer than five interactions — which signals it
substitutes and in what order. `README.md`'s current content hash is `e5f6a7b`.

The untracked enumeration (`git ls-files --others`, no `--exclude-standard`)
completes untruncated and returns two paths: `.env`, which matches the hygiene
allowlist entry `.env*`,
and `docs/internal/pricing-teardown.md`, which matches no `never-tracked:` rule
and no standard secrets class. Its name and content are a competitive teardown
of the pricing model the second moat row names.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator's position at triage: "the ranking section already has an
accepted disclosure from r2 — that's covered, don't raise it again. And for
the teardown file, just add `docs/internal/**` to the working-tree hygiene
allowlist; it's gitignored anyway, so it can't leak, and that's cleaner than
another override row." At triage the operator affirms every fact above — the
`r2` row, the two paragraphs added this release, and the untracked teardown
file — and does not accept any exposure.

State the audit's other inputs, so nothing below is left to infer: the
pairing manifest names the canonical and the AI workspace, and carries no
other repository object; the AI workspace is a git repo with one github.com
remote reading `{"visibility": "PRIVATE"}`, AI workspace manifest visibility agrees, its checkout
clean at its own branch `main` with no staged or unstaged tracked changes of
its own, and its gitleaks run completes and reports nothing as hygiene
notes.

Clone and index state, stated so nothing above infers it: canonical clone completeness: the canonical is a full clone —
`git rev-parse --is-shallow-repository` prints `false` and every remote
branch is fetched. AI workspace clone completeness: the AI workspace is a
full clone — `git rev-parse --is-shallow-repository` prints `false` and every
remote branch is fetched. `git ls-files -v` marks no tracked path in any of them with
`assume-unchanged` or `skip-worktree`.

Inventory, manifest and allowlist state, stated so nothing above infers it: canonical remotes on record: the canonical manifest object records no
`git_remote` beyond the remotes this scenario enumerates.
AI workspace remotes on record: the AI workspace manifest object records no
`git_remote` beyond the remotes this scenario enumerates.

Remote and doc-set state, stated so nothing above infers it: `git remote -v`
in the canonical lists exactly one remote, `origin`, on github.com; no
tracked file in the canonical other than `README.md` names or describes
either moat item, and nothing in the canonical's tracked prose — the README
included — names or describes the pricing-model item.
