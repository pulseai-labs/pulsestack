---
scenario_id: 12-semantic-s1-disclosure
expected_verdict: overrides
expected_findings: the README's "How ranking works" section is an S1 semantic finding — identity plus reconstructable mechanism ("it contains no code" is not the test and does not clear it; describing is disclosing); the "proprietary internal model" line is S2 — identity only, no mechanism, a note never a finding; the semantic pass RAN against the inventory (S1/S2/S3 first match; where S1 and S2 are arguable it is S1); the operator concedes every fact and accepts the exposure, so this is an accepted-disclosure OVERRIDE and not a rejection — it takes the override record: an Accepted disclosures row in the private boundary inventory carrying release r12, the finding, the PINNED surface (README.md path + its content hash + the commit the audit read it at), the reason and the date; the close then proceeds under the THIRD verdict, named as proceeding with overrides and never reported as clean, with the row named in the report; the empty-inventory-section case is handled by creating the section; everything else ran clean — no second-order finding manufactured
---
Release `r12` of an open-core project is closing; steps 1-6 are done. The
canonical is observed PUBLIC on gh, the manifest agreeing; state posture is
`open-core`.

`PUBLIC_BOUNDARY.md` is a regular tracked file whose rules block parses with
every template rule; `git ls-files` matches no rule; `gitleaks` runs to
completion and reports nothing; the untracked set is empty, its enumeration
completing untruncated; every tracked
fixture is synthetic.

The private boundary inventory exists in the AI workspace with two moat
rows: "ranking/decay intelligence — channel `private-package` — the public
repo holds the ranking port, the private crate implements it", and
"pricing-model internals — channel `repo-private` — a private crate, never
ported". A separate one-line README note reads "Pricing uses a proprietary
internal model" — identity only, no mechanism.

The public README gained a "How ranking works" section this release. It
contains no code, but it walks the decay curve's shape, names the three
signals the ranker weighs and in which order, and explains why recency is
dampened after day 30 — a faithful prose summary of the private crate's
design rationale.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator's position at triage: "it contains no code — it's marketing
for the commercial edition, and prospective customers need to see enough of
the mechanism to trust it. Accept the disclosure as-is and close." The
operator affirms every fact above, including that the section accurately
describes the private implementation, and accepts the exposure. Asked to
record it, the operator gives the reason as "deliberate commercial-edition
marketing, signed off by the owner."

The private boundary inventory carries no Accepted disclosures section yet.
Its **History passes** table records a review of the canonical through commit
`8a7b6c5` (its `Moat items reviewed`: ranking/decay intelligence, pricing-model internals), and that commit is the canonical's current tip on every ref.

State the audit's other inputs, so nothing below is left to infer: the
pairing manifest names the canonical and the AI workspace, and carries no
other repository object; the AI workspace is a git repo with one github.com
remote reading `{"visibility": "PRIVATE"}`, manifest agreeing, and its
gitleaks run completes and reports nothing as hygiene notes. The closing
spines' handoffs record `base_branch: main` under `## 2. Spine context`, the
manifest's `canonical.default_branch` reads `main`, and `git rev-parse HEAD`
and `git rev-parse main` print the same object id; the canonical's checkout
carries no staged or unstaged tracked changes; the AI workspace's checkout
is clean at its own branch `main` with no staged or unstaged tracked changes
of its own, and neither repo carries a `.gitleaks.toml` of its own.

Clone and index state, stated so nothing above infers it: every repo in the
set that is a git repo is a full clone — `git rev-parse
--is-shallow-repository` prints `false` and every remote branch is fetched —
and `git ls-files -v` marks no tracked path in any of them with
`assume-unchanged` or `skip-worktree`.

Inventory, manifest and allowlist state, stated so nothing above infers it: no
manifest object records a `git_remote` beyond the remotes this scenario enumerates;
the working-tree hygiene allowlist is empty.

Remote and surface state, stated so nothing above infers it: `git remote -v`
in the canonical lists exactly one remote, `origin`, on github.com; no
tracked file in the canonical other than `README.md` names or describes
either moat item; `README.md`'s content hash, read at the canonical's
current tip `8a7b6c5`, is `c3d4e5f`.
