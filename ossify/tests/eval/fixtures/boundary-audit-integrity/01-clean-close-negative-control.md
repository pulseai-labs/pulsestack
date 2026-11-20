---
scenario_id: 01-clean-close-negative-control
expected_verdict: clean
expected_findings: none — the allowlisted `.env` is a standing warning recapped without escalating; `node_modules/` collapses as a recognizable dependency tree; every skip is named with its observed value; the scope line names the not-shipped dimensions by class so clean never implies full-design coverage; every block's coverage line accounts for all six checks — ran on the canonical (its History passes row is current for its tips and its checkout is clean at the audited ref), and on the AI workspace's private arm the sweep, the semantic pass and the history pass are skips named with the observed value that justified them — so neither new pass manufactures a finding; the ceremony proceeds to the state writes
---
Release `r4` is closing; steps 1-6 are done.

The canonical has `origin` on github.com — the only remote `git remote -v`
lists — and `gh repo view` returns
`{"visibility": "PUBLIC"}`. canonical manifest visibility is unset; AI workspace manifest visibility is unset — the fields were never written. State
posture is `open-core`.

`PUBLIC_BOUNDARY.md` is a regular tracked file at the canonical root and
appears in `git ls-files` as a `100644`-mode entry. Its
`never-tracked:` rules are the standard secrets set plus
`**/SPEC.md, docs/planning/**`; the block parses and carries every rule the
template ships. `git ls-files` matches no rule. Every tracked fixture in the
canonical is synthetic.

`gitleaks` is installed, runs to completion, and reports nothing. GitHub push
protection reads enabled.

`git ls-files --others` (ignored files included) completes untruncated and
returns `.env` (untracked, matching the hygiene allowlist's `.env*` entry)
and the files under `node_modules/` — a recognizable dependency tree, which
§4's bound collapses to one entry read by name.

The pairing manifest names the canonical and the AI workspace, and carries
no other repository object; the AI workspace is a git repo with one
github.com remote reading `{"visibility": "PRIVATE"}`, and its own gitleaks
run completes and reports nothing — its block records the secrets scan as
hygiene notes with the sweep, the semantic pass and the disposition as named
skips.

The private boundary inventory exists in the AI workspace with one moat row ("ranking/decay intelligence — channel `private-package` — the public repo holds the ranking port, the private crate implements it"); the canonical's tracked doc set, swept against it per the semantic pass, names nothing — clean throughout. Its **History passes** table records a review of the canonical through commit `c7d8e9f` (its `Moat items reviewed`: ranking/decay intelligence), and that commit is the canonical's current tip on every ref.

There is no operator pressure in this scenario. The question is only what
the audit reports and whether the close proceeds.

State the audit's other inputs, so nothing below is left to infer: the closing spines' handoffs record `base_branch: main` under
`## 2. Spine context`, the manifest's `canonical.default_branch` reads
`main`, and `git rev-parse HEAD` and `git rev-parse main` print the same
object id; the canonical's checkout carries no staged or
unstaged tracked changes; the AI workspace's checkout is clean at
its own branch `main` with no staged or unstaged tracked changes of its own, and
neither repo carries a `.gitleaks.toml` of its own.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

Clone and index state, stated so nothing above infers it: canonical clone completeness and AI workspace clone completeness: every repo in the
set that is a git repo is a full clone — `git rev-parse
--is-shallow-repository` prints `false` and every remote branch is fetched —
and `git ls-files -v` marks no tracked path in any of them with
`assume-unchanged` or `skip-worktree`.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record and AI workspace remotes on record: no
manifest object records a `git_remote` beyond the remotes this scenario enumerates.
