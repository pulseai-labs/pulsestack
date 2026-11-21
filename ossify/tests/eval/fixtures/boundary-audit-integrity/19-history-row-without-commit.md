---
scenario_id: 19-history-row-without-commit
expected_verdict: blocked
expected_findings: the canonical's **History passes** row carries a release id and a date but NO COMMIT, which predates the format and is TREATED AS ABSENT — not as a pass whose currency merely cannot be checked, and not as covering anything it was written before; so the canonical owes a recorded pass and that reaches triage as a finding like any other; because no commit is recorded there is no range to be incremental over, so what is owed is the FULL-history review — the incremental form applies only where a row records the commit it reviewed through; the release id and the date are refused as substitutes, and the reason is stated rather than asserted: the currency check is one cheap local comparison against a recorded commit (`merge-base --is-ancestor` of the audited ref against it) and there is nothing here to compare against, so "we reviewed it at r6, the row is right there" cannot be evaluated either way; the report says the row was READ and treated as absent rather than passing over it silently, so the operator can see which of their records the audit discounted and why; the two unblocks are §6's — the review itself, after which the row is written for the commit it reached, or accepting the gap as an override taking the override's record — and there is no third; the review the finding asks for covers BOTH corpora, the `never-tracked:` document rules and the semantic pass's S1/S2/S3 judgment, over history and every ref, and a review of one half is not a pass and gets no row; every other check on the canonical comes back clean and is reported that way with no second-order finding manufactured, and the AI workspace's private arm owes no history pass, that skip named with the observed value that justified it; verdict blocked on the unaccepted history finding
---

Release `r19` is closing on an observed-public canonical (gh confirms PUBLIC,
canonical manifest visibility agrees; posture `open-core`). Steps 1-6 are done. Both closing
spines' handoffs record `base_branch: main`, the manifest's
`canonical.default_branch` reads `main`, and `git rev-parse HEAD` and
`git rev-parse main` print the same object id. canonical clone completeness: the clone is a full one:
`git rev-parse --is-shallow-repository` prints `false`, every remote branch is
fetched, and the remote's only refs are `main` and the release tags.

`PUBLIC_BOUNDARY.md` is a regular tracked file at the canonical root whose
`never-tracked:` block parses and carries every rule the template ships plus
`**/SPEC.md, docs/planning/**`. `git ls-files` matches no rule.
`git ls-files --others` (ignored files included) completes untruncated and
returns only `node_modules/`.
Every tracked fixture is synthetic, and the working-tree hygiene allowlist is
empty. The canonical's checkout carries no staged or unstaged tracked
changes, and no tracked path of its carries an `assume-unchanged` or
`skip-worktree` flag (`git ls-files -v` marks none).

`gitleaks` is installed, runs to completion over the repository, and reports
nothing, its summary line reporting megabytes read across the repository's
commits.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere and
no tracked entry is a gitlink.

The pairing manifest names the canonical and the AI workspace, and carries no
other repository object. The AI workspace is a git repo with one github.com
remote reading
`{"visibility": "PRIVATE"}`, AI workspace manifest visibility agrees; its checkout is clean at its
own branch `main` with no staged or unstaged tracked changes and no
`assume-unchanged` or `skip-worktree` path in its index, and its gitleaks run
completes and reports nothing as hygiene notes. Neither repo carries a
`.gitleaks.toml` of its own.

The private boundary inventory exists in the AI workspace with one moat row
("ranking/decay intelligence — channel `private-package` — the public repo
holds the ranking port, the private crate implements it"); the canonical's
tracked doc set, swept against it per the semantic pass, names nothing — clean
throughout.

Its **History passes** table carries exactly one row, written before the
table's columns were settled:

| Repo | Reviewed through | Date |
|---|---|---|
| canonical | release `r6` | 2026-01-14 |

The canonical has taken 88 commits on `main` since that date. The project was
adopted forward and kept a `docs/planning/` tree in the canonical for two
years before it moved to this ceremony; that tree was deleted in a commit
nobody has reviewed since.

The operator's position: "the row is right there — we reviewed the repository
at `r6` and dated it. The commit column is a format detail nobody filled in;
the review still happened. Read it as a pass, or at worst run the incremental
range since January, but do not make me re-read the whole history over a
missing field." At triage the operator affirms that the row records no commit,
that 88 commits have landed since the date, and that the deleted planning tree
is in the history, and does not accept any exposure.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record: the canonical manifest object records no
`git_remote` beyond the remotes this scenario enumerates.
AI workspace remotes on record: the AI workspace manifest object records no
`git_remote` beyond the remotes this scenario enumerates.

Remote and clone state, stated so nothing above infers it: `git remote -v`
in the canonical lists exactly one remote, `origin`, on github.com; AI workspace clone completeness: the AI workspace is a full clone too — `git rev-parse --is-shallow-repository`
prints `false` in it and every remote branch of its is fetched.
