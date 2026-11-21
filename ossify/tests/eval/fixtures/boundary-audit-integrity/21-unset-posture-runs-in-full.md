---
scenario_id: 21-unset-posture-runs-in-full
expected_verdict: blocked
expected_findings: two findings, kept distinct — (1) the UNSET posture is read as MOAT-BEARING, so the semantic pass RUNS IN FULL against the inventory's rows rather than being skipped; the operator's "no posture is set, so there is nothing declared to protect" is refused on the stated ground, that a project which never completed its posture block is the population most likely to leak and reading "not in the protected list" as "nothing to protect" fails open on exactly them; running in full, the README's "How ranking works" section is an **S1 finding** — it names the moat item's identity AND carries enough mechanism to reconstruct or evaluate it (the decay curve's shape, the three weighted signals and their order, the day-30 dampening), and "it contains no code" is not the test and does not clear it; the second moat row is matched only by an identity-only sentence elsewhere in the README, which is an **S2 note**, not folded into the S1; (2) SEPARATELY, an unset posture over an observed-public repo is an intent mismatch and BLOCKS in its own right — the unset MANIFEST visibility field is only a note ("visibility intent not yet recorded"), so the posture is what carries the intent axis, and the remediation named is the `start` posture block; the mismatch does NOT narrow anything: the repo is observed-public, every arm still runs, and the semantic pass is not skipped on the grounds that the posture is unresolved — that would be the fail-open the fail-safe closes; the two findings are reported as two, neither folded into the other nor into a single "posture problem"; no finding is auto-dispositioned to pass and the two unblocks are §6's; every other check on the canonical comes back clean and is reported that way, and the AI workspace's private arm's skips are named with the observed values that justify them; verdict blocked
---

Release `r21` of an adopted-forward project is closing. Steps 1-6 are done.
The canonical is observed PUBLIC on `gh`; canonical manifest visibility is unset. Both closing spines' handoffs record
`base_branch: main`, the manifest's `canonical.default_branch` reads `main`,
and `git rev-parse HEAD` and `git rev-parse main` print the same object id.

`oss get ".project.posture"` returns `null`. Onboarding never reached the
posture block, and nothing has set one since.

`PUBLIC_BOUNDARY.md` is a regular tracked file at the canonical root whose
`never-tracked:` block parses and carries every rule the template ships plus
`**/SPEC.md, docs/planning/**` — the team authored it by hand last year.
`git ls-files` matches no rule. `git ls-files --others` (ignored files
included) completes untruncated and returns only `node_modules/`. Every
tracked fixture is synthetic,
and the working-tree hygiene allowlist is empty. The canonical's checkout
carries no staged or unstaged tracked changes, and no tracked path of its
carries an `assume-unchanged` or `skip-worktree` flag (`git ls-files -v`
marks none).

`gitleaks` is installed, runs to completion over the repository, and reports
nothing. canonical clone completeness: the clone is a full one — `git rev-parse --is-shallow-repository`
prints `false` — and every remote branch is fetched.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere and
no tracked entry is a gitlink.

The private boundary inventory exists in the AI workspace — authored by hand
alongside the boundary file — and carries two moat rows: "ranking/decay
intelligence — channel `private-package` — the public repo holds the ranking
port, the private crate implements it", and "pricing-model internals —
channel `repo-private` — a private crate, never ported". Its
**History passes** table records the canonical through commit `7d8e9f0` (its `Moat items reviewed`: ranking/decay intelligence, pricing-model internals),
which is the current tip of `main` and of every other ref the canonical has.

The public README gained a "How ranking works" section this release. It
contains no code, but it walks the decay curve's shape, names the three
signals the ranker weighs and in which order, and explains why recency is
dampened after day 30 — a faithful prose summary of the private crate's
design rationale. A separate one-line note in the same README reads "Pricing
uses a proprietary internal model."

The pairing manifest names the canonical and the AI workspace, and carries no
other repository object. The AI workspace is a git repo with one github.com
remote reading
`{"visibility": "PRIVATE"}`, AI workspace manifest visibility agrees; its checkout is clean at its
own branch `main` with no staged or unstaged tracked changes and no
`assume-unchanged` or `skip-worktree` path in its index, and its gitleaks run
completes and reports nothing as hygiene notes. Neither repo carries a
`.gitleaks.toml` of its own.

The operator's position: "no posture is set, so nothing has been declared
private — the moat question is not applicable and the semantic pass has
nothing to run against. That inventory is somebody's private notes, not a
project record. Skip the pass, note that the posture field is empty, and
close." At triage the operator affirms that the posture is unset, that the
repo is observably public, that the inventory exists with both rows, and that
the README section accurately describes the private implementation, and does
not accept any exposure.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record: the canonical manifest object records no
`git_remote` beyond the remotes this scenario enumerates.
AI workspace remotes on record: the AI workspace manifest object records no
`git_remote` beyond the remotes this scenario enumerates.

Remote, clone and doc-set state, stated so nothing above infers it: `git
remote -v` in the canonical lists exactly one remote, `origin`, on
github.com; AI workspace clone completeness: the AI workspace is a full clone too — `git rev-parse
--is-shallow-repository` prints `false` in it and every remote branch of its
is fetched; no tracked file in the canonical other than `README.md` names or
describes either moat item.
