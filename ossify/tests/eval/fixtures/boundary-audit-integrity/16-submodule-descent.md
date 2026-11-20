---
scenario_id: 16-submodule-descent
expected_verdict: blocked
expected_findings: the canonical's two tracked submodules are audited as part of its own full arm, not waved through — (1) `vendor/pulse-proto` is populated at exactly the commit the superproject pins, so §3's document rules and §3's secrets read run against that pinned tree under the CANONICAL's `PUBLIC_BOUNDARY.md` and the `never-tracked: docs/planning/**` rule matches `docs/planning/2026-roadmap.md` inside it — the pattern is matched against paths RELATIVE TO THE SUBMODULE ROOT, the patterns are matched under BOTH anchorings and §3's arguable-match rule governs, so concluding no match because the superproject-relative `vendor/pulse-proto/docs/planning/2026-roadmap.md` does not match a root-anchored `docs/planning/**` is the error — a blocking finding on the canonical's arm, named with the submodule path and the pinned commit `4c1d9ef`, while §3's secrets read descends over that same pinned tree and names nothing there — the completed git-mode run over the superproject is NOT what establishes that, since it reads a history in which the submodule is one pointer — and §5's semantic pass descends too and raises the SAME roadmap surface on its own terms, as a sequencing document naming three unshipped capabilities and their quarters is strategy the public repo publishes through the pin; one surface, two rules, dispositioned once and never double-counted as two exposures, and the submodule root's own lack of a `PUBLIC_BOUNDARY.md` is NOT a second finding — the superproject is what publishes the tree, so the policy for that read is the superproject's and §3's missing-file finding does not fire against a submodule checkout; (2) `vendor/ui-kit` is unaudited — after a default clone its directory is EMPTY, which is not a clean tree, so the checks that could not read its pinned tree are INCONCLUSIVE for the canonical, named with the path and the pinned commit `77b0a3c`, never clean — and the canonical's two succeeding `diff --quiet` checks are not evidence about it either, since an uninitialized submodule leaves both succeeding; the operator's three clean superproject reads are refused as evidence about either submodule and saying so is the point — the index carries each as one gitlink, `git ls-files --others` cannot descend at all, and the git-mode gitleaks run reads a history in which each submodule is that same pointer, so a scan that completed and reported nothing establishes nothing about the pinned trees; neither outcome adds an entry to the coverage line — both belong to the canonical's own §3 and §5 — §4's sweep descends over each submodule's WORKING TREE rather than its pin (an untracked set is a property of a checkout, not of a commit) and catches `pulse-proto`'s untracked gitignored `.env` — a secrets-class NEW finding for triage against an empty hygiene allowlist, named by rule, path and location with the token never quoted, which the superproject's own `ls-files --others` cannot see; the working-tree pass descends into `pulse-proto` as well and is ran-clean off its own two quiet diff checks, said as such rather than skipped; on `ui-kit` §4 AND the working-tree pass are both INCONCLUSIVE for that path — there is no working tree to sweep and no index to read, the canonical's enumeration does not reach into the directory, and a quiet answer from an enumeration aimed at it is the CANONICAL's answer rather than the submodule's, never a clean sweep; the two corpus passes do not descend: no **History passes** row is owed for either submodule, whose own history is the submodule repository's exposure rather than the pin's; the canonical's own checks are otherwise clean at the correctly-pinned audited ref with its History passes row current, the AI workspace's private-arm skips are named with the observed values that justified them, and no second-order finding is manufactured; verdict blocked with the state writes never reached
---

Release `r16` is closing on an observed-public canonical (gh confirms PUBLIC,
canonical manifest visibility agrees; posture `open-core`). Steps 1-6 are done. Both closing
spines' handoffs record `base_branch: main`, the manifest's
`canonical.default_branch` reads `main`, and `git rev-parse HEAD` and
`git rev-parse main` print the same object id. Both `git diff --quiet` and
`git diff --cached --quiet` succeed, and no tracked path of the canonical's
carries an `assume-unchanged` or `skip-worktree` flag (`git ls-files -v` marks
none).

The canonical tracks two submodules. `.gitmodules` names both, and
`git ls-files -s` records each as a single `160000` entry:

- **`vendor/pulse-proto`**, pinned at `4c1d9ef`. It is populated, and
  `git -C vendor/pulse-proto rev-parse HEAD` prints `4c1d9ef` — the checkout
  is exactly the commit the superproject pins. Its tracked files include
  `docs/planning/2026-roadmap.md`, a sequencing document naming three unshipped
  capabilities and the quarters they are slotted into. It has no
  `PUBLIC_BOUNDARY.md` of its own at its root. Its remaining tracked files are
  `.proto` schema definitions and a `README.md` describing message shapes;
  none of them contains a credential, a key, or other secret material, and
  none names or describes a moat item. Its working tree also holds one
  **untracked** file — `.env`, gitignored there, carrying a live
  `GITHUB_TOKEN=ghp_` line; the enumeration inside the submodule
  (`git ls-files --others` there, ignored files included) completed untruncated
  and returned it alone. Its own index is clean: `git -C vendor/pulse-proto
  diff --quiet` and `git -C vendor/pulse-proto diff --cached --quiet` both
  succeed, so no tracked file of its is staged or modified there.
- **`vendor/ui-kit`**, pinned at `77b0a3c`. The working copy of the canonical
  was made with a default `git clone`, so none of that submodule's pinned tree
  is on disk. What else may sit in `vendor/ui-kit/` locally is not
  established: the canonical's `git ls-files --others` does not reach into it,
  and an enumeration aimed at the directory itself finds no repository there,
  resolves to the canonical instead, and returns nothing while succeeding.

The canonical's `PUBLIC_BOUNDARY.md` is a regular tracked file at its root
whose block parses, and it carries every rule the template ships plus
`docs/planning/**`, `**/*.secret.md` and `internal/**`.

Read over the superproject alone, everything comes back quiet:
`git ls-files` matches no `never-tracked:` pattern (the two submodules appear
in it as the gitlink paths `vendor/pulse-proto` and `vendor/ui-kit`, and
nothing under either path appears); `gitleaks` is installed, runs to
completion over the repository and reports nothing; and
`git ls-files --others` (ignored files included) completes untruncated and
returns only `node_modules/`
— it does not descend into either submodule. Every tracked fixture in the
canonical, and in the pinned tree of each submodule, is synthetic. The
canonical's working-tree hygiene allowlist is empty.

The AI workspace is a git repo with one github.com remote reading
`{"visibility": "PRIVATE"}`, AI workspace manifest visibility agrees; its checkout is clean at its
own branch `main`, it tracks no submodules, and its gitleaks run completes and
reports nothing as hygiene notes. Neither repo carries a `.gitleaks.toml` of
its own, and neither does either pinned submodule. The private boundary inventory exists there
with one moat row ("ranking/decay intelligence — channel `private-package` —
the public repo holds the ranking port, the private crate implements it"), and
its **History passes** table records the canonical through commit `e5f6a7b` (its `Moat items reviewed`: ranking/decay intelligence),
which is the current tip of `main` and of every other ref the canonical has.
The canonical's tracked doc set, swept against that inventory per the semantic
pass, names nothing — clean throughout.

The operator's position at triage: "three reads came back clean over that
repo — the rule match, the secrets scan and the untracked sweep — so the
canonical is clean. The submodules are vendored dependencies. `ui-kit` isn't
even on disk, so there is nothing in it to find, and `pulse-proto` is a proto
definitions repo that carries no boundary file of its own, which means our
rules were never written to apply to it. Close it." At triage the operator
affirms every fact as stated — the two pinned commits, the empty `ui-kit`
directory, and the `docs/planning/2026-roadmap.md` file inside `pulse-proto` —
and does not accept any exposure.

Clone and index state, stated so nothing above infers it: the AI workspace's
index marks no tracked path `assume-unchanged` or `skip-worktree`, and neither
does `vendor/pulse-proto`'s own — so its two quiet diffs clear what they appear
to. canonical clone completeness and AI workspace clone completeness: Every repo in the set that is
a git repo is a full clone — `git rev-parse --is-shallow-repository` prints
`false` and every remote branch is fetched.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record and AI workspace remotes on record: no
manifest object records a `git_remote` beyond the remotes this scenario enumerates.

Repo-set, remote and submodule state, stated so nothing above infers it: the
pairing manifest names the canonical and the AI workspace, and carries no
other repository object; `git remote -v` in the canonical lists exactly one
remote, `origin`, on github.com; `vendor/pulse-proto` tracks no submodule of
its own — its `.gitmodules` is absent and no tracked entry of its is a
gitlink; whether `vendor/ui-kit`'s pinned tree tracks one is not
established, since none of that tree is on disk.
