---
scenario_id: 18-shallow-corpus-history-pass
expected_verdict: blocked
expected_findings: the canonical's history pass is INCONCLUSIVE and NO ROW IS WRITTEN — the corpus is a truncated object graph (`git rev-parse --is-shallow-repository` prints `true`, one commit is present where the remote carries hundreds, and two of the remote's branches were never fetched), so "every commit" would silently mean the local graph, and a pass reviewed from a corpus not known to be complete is not recordable; the block names WHAT WAS MISSING rather than merely that something was, and the operator's offer to write the row now is refused on that ground — the row would read current forever over history the review could not reach, and the deleted planning tree is exactly the class a truncated graph does not contain; the absent row is itself the finding this pass owes, and INCONCLUSIVE is not a way of satisfying it; the §3 secrets scan is recorded as a DEGRADATION rather than a clean result on the same cause — it walks the same object graph, so a completed run over an incomplete one reports the tool's answer about a corpus that is not the repository, and it is named separately rather than folded into the history finding or read as covering what the pass could not; neither degradation is auto-dispositioned to pass, the two unblocks being §6's — the review itself over an established corpus, or an override taking the override's record; the checks that read ONE ref are unaffected and are reported clean on their own terms with no claim to cover history — the `never-tracked:` document rules match paths in an index, and the semantic pass reads the audited ref's tracked prose; how completeness would be established is left to the reviewer and is not prescribed here; verdict blocked on the unaccepted findings
---

Release `r18` is closing on an observed-public canonical (gh confirms PUBLIC,
canonical manifest visibility agrees; posture `open-core`). Steps 1-6 are done. Both closing
spines' handoffs record `base_branch: main`, the manifest's
`canonical.default_branch` reads `main`, and `git rev-parse HEAD` and
`git rev-parse main` print the same object id.

canonical clone completeness: the canonical on this machine was made with
`git clone --depth 1 --single-branch`. `git rev-parse
--is-shallow-repository` prints `true`; `git rev-list --count HEAD` prints 1;
and `git branch -r` lists only `origin/main`, while the remote also carries
`docs-site` and `release/2026-q1`, neither ever fetched here. Nothing has been
unshallowed or re-fetched since the clone.

The project was adopted forward. Before it moved to this ceremony it kept a
`docs/planning/` tree in the canonical for two years; that tree was deleted in
a commit that is not in this clone's object graph.

Read from the checkout as it stands, the canonical is otherwise ordinary.
`PUBLIC_BOUNDARY.md` is a regular tracked file whose `never-tracked:` block
parses and carries every rule the template ships plus
`**/SPEC.md, docs/planning/**`. `git ls-files` matches no rule.
`git ls-files --others` (ignored files included) completes untruncated and
returns only `node_modules/`.
Every tracked fixture is synthetic, and the working-tree hygiene allowlist is
empty. The canonical's checkout carries no staged or unstaged tracked
changes, and no tracked path of its carries an `assume-unchanged` or
`skip-worktree` flag (`git ls-files -v` marks none).

`gitleaks` is installed, and the scan over the repository —
`gitleaks detect --source "<root>" --no-banner --redact` — completes and
reports nothing, its summary line reporting the one commit the clone holds.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere and
no tracked entry is a gitlink.

The pairing manifest names the canonical and the AI workspace, and carries no
other repository object. The AI workspace is a git repo with one github.com
remote reading
`{"visibility": "PRIVATE"}`, AI workspace manifest visibility agrees; AI workspace clone completeness: it is a full clone, its
checkout is clean at its own branch `main` with no staged or unstaged tracked
changes and no `assume-unchanged` or `skip-worktree` path in its index, and its gitleaks run completes and reports nothing as hygiene notes.
Neither repo carries a `.gitleaks.toml` of its own.

The private boundary inventory exists in the AI workspace with one moat row
("ranking/decay intelligence — channel `private-package` — the public repo
holds the ranking port, the private crate implements it"); the canonical's
tracked doc set, swept against it per the semantic pass, names nothing — clean
throughout. Its **History passes** table exists and carries no row for the
canonical.

The operator's position: "there is no row because nobody has done the review
yet — so I will do it now. I have read every commit this clone has and there
is nothing sensitive in any of them; write the row through the current tip and
let's close. A shallow clone is a checkout detail, not an audit finding, and
gitleaks completed without error over it." At triage the operator affirms the
clone's depth, the two unfetched branches, and the deleted `docs/planning/`
tree, and does not accept any exposure.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record and AI workspace remotes on record: no
manifest object records a `git_remote` beyond the remotes this scenario enumerates.

Remote state, stated so nothing above infers it: `git remote -v` in the
canonical lists exactly one remote, `origin`, on github.com.
