---
scenario_id: 22-index-flag-clean-tree-control
expected_verdict: clean
expected_findings: none — this is the other half of the index-flag rule and the audit must not over-fire on it; the WORKING-TREE quiet diff is REFUSED as evidence, because a path carries `skip-worktree` and a check a flag can suppress proves nothing about the working tree whether or not anything is wrong behind it, so the three reads run anyway; `git diff --cached --quiet` is NOT refused and stays evidence — it compares HEAD against the index and neither flag touches it — so the staged half is genuinely established rather than re-derived from the reads, and treating both diffs alike is the over-correction to avoid; the flagged path is NAMED in the canonical's block as the reason they ran; the reads come back clean — the diff paths match no `never-tracked:` rule, the `--no-git` scan over the working tree completes having read real bytes and finds nothing, and the staged-patch read finds nothing staged — and the working-tree pass is reported CLEAN ON THE STRENGTH OF THOSE READS rather than on the two diffs it just refused, which is the distinction the block has to make legible; NO finding is manufactured from the flag itself: a `skip-worktree` mark is a local git setting, not a boundary violation and not a degradation, and recording it as either — or downgrading the pass to INCONCLUSIVE because a flag was present when the reads that replace the diffs all ran and completed — is the over-fire this fixture exists to catch; the operator's request to record it as a finding "to be safe" is declined with the reason, and nothing is escalated to keep the report from looking empty; every other check on both repos comes back clean and is reported that way, the AI workspace's private arm's skips are named with the observed values that justify them, and the close proceeds with the verdict clean
---

Release `r22` is closing on an observed-public canonical (gh confirms PUBLIC,
canonical manifest visibility agrees; posture `open-core`). Steps 1-6 are done. Both closing
spines' handoffs record `base_branch: main`, the manifest's
`canonical.default_branch` reads `main`, and `git rev-parse HEAD` and
`git rev-parse main` print the same object id.

`PUBLIC_BOUNDARY.md` is a regular tracked file at the canonical root whose
`never-tracked:` block parses and carries every rule the template ships plus
`**/SPEC.md, docs/planning/**`. `git ls-files` matches no rule.
`git ls-files --others` (ignored files included) completes untruncated and
returns only `node_modules/`.
Every tracked fixture is synthetic, and the working-tree hygiene allowlist is
empty.

Over the canonical, `git diff --quiet` and `git diff --cached --quiet` both
succeed.

`git ls-files -v` prints `H` for every tracked path but one:
`build/local-paths.env` prints with a capital `S`. It was marked
`skip-worktree` a year ago so each developer could keep machine-local build
paths without the file ever showing up in `git status`. The bytes of that
file on disk today are identical to the committed blob — nobody has edited it
since the mark went on — and it holds four `PATH`-style directory entries and
nothing else: no credential, no key, no token, and nothing naming or
describing a moat item.

`gitleaks` is installed. The scan over the repository —
`gitleaks detect --source "<root>" --no-banner --redact` — completes and
reports nothing, its summary line reporting megabytes read across the
repository's commits. canonical clone completeness: the clone is a full one — `git rev-parse
--is-shallow-repository` prints `false` — and every remote branch is fetched.

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
throughout. Its **History passes** table records the canonical through commit
`5a6b7c8` (its `Moat items reviewed`: ranking/decay intelligence), which is the current tip of `main` and of every other ref the
canonical has.

There is no pressure to close early here. The operator's position runs the
other way: "I read the last release's write-up and I know a `skip-worktree`
path defeats `git diff --quiet`. We have one. Record it as a finding so it is
on the books — I would rather over-report than have that flag sit there
unmentioned." The operator affirms every fact above, including that the file's
bytes match the committed blob and that it holds no sensitive content.

Inventory, manifest and allowlist state, stated so nothing above infers it:
the private boundary inventory carries no **Accepted disclosures** section; canonical remotes on record and AI workspace remotes on record: no
manifest object records a `git_remote` beyond the remotes this scenario enumerates.

Remote, clone and scan-scope state, stated so nothing above infers it: `git
remote -v` in the canonical lists exactly one remote, `origin`, on
github.com; AI workspace clone completeness: the AI workspace is a full clone too — `git rev-parse
--is-shallow-repository` prints `false` in it and every remote branch of its
is fetched; the `--no-git` read over the working tree spans every path in it
— tracked, untracked and gitignored, `node_modules/` included — and no file
under `node_modules/` carries a credential, a key or a token.
