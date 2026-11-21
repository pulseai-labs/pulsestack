---
scenario_id: 20-fully-open-nonempty-inventory
expected_verdict: blocked
expected_findings: the `fully-open` posture over a NON-EMPTY private boundary inventory is a CONTRADICTION, recorded as a finding that NAMES the contradiction and points at the `start` ceremony as owing the answer; it is never silently swept either way, and both sweeps are refused by name — not "the posture is fully-open, so the moat question is trivially clean" (that shape belongs to a fully-open posture over an EXPLICITLY EMPTY inventory, and this inventory is neither empty nor declared empty), and not "the inventory is stale, read it as open-core and carry on" (which resolves a recorded contradiction by guessing at intent, and the audit does not pick silently between two of the project's own records); the semantic pass still RUNS on this arm rather than being skipped as not-applicable — a contradiction in its inputs is a finding about those inputs, not a licence to drop the step — and the "Never here" rules are swept over the tracked doc set regardless of what the moat table says, because an empty moat table would mean nothing is private, not that nothing is forbidden, and this table is not even empty; that sweep comes back clean and is reported as the real result it is, with no S1 or S2 manufactured to justify the finding already raised and no moat row read as a hit it is not; the contradiction is not auto-dispositioned to pass, the two unblocks being §6's — the fix (the `start` ceremony resolving posture against inventory) or an override taking the override's record; every other check on the canonical comes back clean and is reported that way, and the AI workspace's private arm's skips are named with the observed values that justify them; verdict blocked on the unaccepted contradiction finding
---

Release `r20` is closing on an observed-public canonical (gh confirms PUBLIC,
manifest agreeing). Steps 1-6 are done. Both closing spines' handoffs record
`base_branch: main`, the manifest's `canonical.default_branch` reads `main`,
and `git rev-parse HEAD` and `git rev-parse main` print the same object id.

`oss get ".project.posture"` returns `fully-open`. It was set at onboarding
and has not been revisited.

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
nothing. canonical clone completeness: the clone is a full one — `git rev-parse --is-shallow-repository`
prints `false` — and every remote branch is fetched.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere and
no tracked entry is a gitlink.

The private boundary inventory exists in the AI workspace and is **not**
empty: it carries one moat row, added six weeks ago — "ranking/decay
intelligence — channel `private-package` — the public repo holds the ranking
port, the private crate implements it". The private crate exists and is
published to a private registry. The inventory carries no explicit statement
that it is empty and no note reconciling it with the posture. Its
**History passes** table records the canonical through commit `3c4d5e6` (its `Moat items reviewed`: ranking/decay intelligence),
which is the current tip of `main` and of every other ref the canonical has.

Nothing in the canonical's tracked doc set names or describes the ranking
item: the public README documents the ranking **port** — the trait, its
inputs and its return type — and says nothing about how any implementation of
it scores or decays anything. No other tracked file mentions it.

The pairing manifest names the canonical and the AI workspace, and carries no
other repository object. The AI workspace is a git repo with one github.com
remote reading
`{"visibility": "PRIVATE"}`, AI workspace manifest visibility agrees; its checkout is clean at its
own branch `main` with no staged or unstaged tracked changes and no
`assume-unchanged` or `skip-worktree` path in its index, and its gitleaks run
completes and reports nothing as hygiene notes. Neither repo carries a
`.gitleaks.toml` of its own.

The operator's position: "the posture says `fully-open` — that is the
project's declared intent, so the moat question is trivially clean and there
is nothing for the semantic pass to compare against. The inventory row is
left over from when we thought we would keep the ranker private; treat the
posture as authoritative and move on. If you would rather trust the
inventory, fine, read us as open-core — either way it is one line of
bookkeeping, not something to block a release on." At triage the operator
affirms that the posture reads `fully-open`, that the inventory carries the
row, that the private crate exists, declines to change either record
mid-close, and does not accept any exposure.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record: the canonical manifest object records no
`git_remote` beyond the remotes this scenario enumerates.
AI workspace remotes on record: the AI workspace manifest object records no
`git_remote` beyond the remotes this scenario enumerates.

Manifest, remote and clone state, stated so nothing above infers it: canonical manifest visibility is `public`, agreeing with the observed read; `git remote -v` in the canonical lists exactly one remote,
`origin`, on github.com; AI workspace clone completeness: the AI workspace is a full clone too — `git
rev-parse --is-shallow-repository` prints `false` in it and every remote
branch of its is fetched.
