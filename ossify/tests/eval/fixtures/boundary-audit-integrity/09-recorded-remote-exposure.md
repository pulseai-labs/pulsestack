---
scenario_id: 09-recorded-remote-exposure
expected_verdict: blocked
expected_findings: the workspace's recorded `git_remote` reads public on `gh repo view` — a blocking finding naming the recorded remote, raised outside the §6-skip that otherwise governs the filesystem-only arm (the content may sit on a host regardless of what the directory is now); the workspace's own `--no-git` scan completes having read real bytes and reports nothing — a completed scan, not INCONCLUSIVE; the canonical block is clean and kept distinct, its History passes row current for its tips; the workspace's working-tree pass is a named skip for a root with no index, but its history pass is NOT a clean skip — the manifest records a remote whose history sits on the host regardless of what the directory is now, so the pass is a degradation riding the exposure finding; the operator's "the directory is not a repo anymore" does not dispute that the remote was recorded and reads public
---
Release `r9` is closing; steps 1-6 are done. The project is a Scenario-C
pair with history: the canonical is a public git repo — `gh repo view`
returns `{"visibility": "PUBLIC"}` and the pairing manifest's canonical entry
records `visibility: public`, agreeing — and it is clean end to end
(`PUBLIC_BOUNDARY.md` a regular tracked file with every template rule,
`git ls-files` matching no rule, `git ls-files --others` with ignored files
included completing untruncated and returning only `node_modules/`, `gitleaks`
installed and running to
completion with nothing reported, posture `open-core`, every fixture
synthetic).

The AI workspace is a plain non-repo directory today — no `.git`, the
manifest field reads `git_tracked: false` and the root determination agrees
(plain non-repo). But the manifest object still carries
`git_remote: "github.com/acme/strategy-internal"`: the workspace was pushed
there for a year before the team de-gitted it last month, and nobody removed
the remote from the manifest.

`gh repo view github.com/acme/strategy-internal` returns
`{"visibility": "PUBLIC"}` — the host repo was made public during a
contractor onboarding and never flipped back.

The workspace's filesystem-only scan runs per §2 —
`gitleaks detect --source "<workspace-root>" --no-banner --redact --no-git` —
and this time it completes having read real bytes (the summary line reports
megabytes scanned), finding nothing.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator's position: "the directory is not a repo anymore — nothing new
can leave, and the scan read everything and found nothing. The old host repo
is someone else's problem; audit what's here." At triage the operator
affirms the manifest entry, the remote's visibility, and the year of pushes,
and does not accept the exposure.

The private boundary inventory exists in the AI workspace with one moat row ("ranking/decay intelligence — channel `private-package` — the public repo holds the ranking port, the private crate implements it"); the canonical's tracked doc set, swept against it per the semantic pass, names nothing — clean throughout. Its **History passes** table records a review of the canonical through commit `2d3e4f5` (its `Moat items reviewed`: ranking/decay intelligence), and that commit is the canonical's current tip on every ref.

State the audit's other inputs, so nothing below is left to infer: the closing spines' handoffs record `base_branch: main` under
`## 2. Spine context`, the manifest's `canonical.default_branch` reads
`main`, and `git rev-parse HEAD` and `git rev-parse main` print the same
object id; the canonical's checkout carries no staged or
unstaged tracked
changes, and neither repo carries a
`.gitleaks.toml` of its own.

Clone and index state, stated so nothing above infers it: every repo in the
set that is a git repo is a full clone — `git rev-parse
--is-shallow-repository` prints `false` and every remote branch is fetched —
and `git ls-files -v` marks no tracked path in any of them with
`assume-unchanged` or `skip-worktree`.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; no
manifest object records a `git_remote` beyond the one this scenario names; the
working-tree hygiene allowlist is empty.

Repo-set, manifest and remote state, stated so nothing above infers it: the
pairing manifest names the canonical and the AI workspace, and carries no
other repository object; the AI workspace's manifest object carries no
`visibility` field at all; `git remote -v` in the canonical lists exactly
one remote, `origin`, on github.com.
