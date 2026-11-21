---
scenario_id: 02-missing-public-boundary-md
expected_verdict: blocked
expected_findings: five, kept distinct — PUBLIC_BOUNDARY.md absent from an observed-public repo (blocking, posture-block remediation named, never a silent skip of the tracked-rules step, and gitleaks-clean is not a substitute); the unset posture over an observed-public repo is an intent mismatch and blocks (the unset MANIFEST field is only a note, so the posture is what carries the intent axis); the untracked sweep's classification half is recorded degraded on the absent policy input — the pattern pass still ran, but with no allowlist "no allowlisted hits" is not a classification this run produced, and the degradation is named rather than folded into the missing-file finding; the semantic pass is INCONCLUSIVE on the unlocatable inventory — a finding carrying the `start`-time remediation, riding the same never-completed-posture-block cause, never folded and never read as clean; the canonical's history pass is INCONCLUSIVE on the same unlocatable inventory — the repo is on a full public arm and owes a recorded pass, no row can be read, and an unreadable record is a degradation of its own coverage-line entry rather than a silent fifth check
---
Release `r1` of an adopted-forward project is closing; steps 1-6 are done.

The canonical repo has `origin` on github.com — the only remote
`git remote -v` lists — and `gh repo view` returns
`{"visibility": "PUBLIC"}`. The project was onboarded before its posture block
was ever completed: state carries `posture: null`, and there is **no**
`PUBLIC_BOUNDARY.md` anywhere in the repo.

`gitleaks` is installed and reports nothing tracked — including the AI
workspace's own run, which completes and reports nothing as hygiene notes.
Untracked files: only `node_modules/` noise, the enumeration completing
untruncated. The pairing manifest names the
canonical and the AI workspace, carries no other repository object, and
canonical manifest visibility is unset; AI workspace manifest visibility is unset — the fields were never written. The
AI workspace has one github.com remote and `gh repo view` returns
`{"visibility": "PRIVATE"}` for it; with no manifest value to compare
against, that is the same unrecorded-intent note the canonical gets, not a
second mismatch.

No repo in the set tracks a submodule: `.gitmodules` is absent everywhere
and no tracked entry is a gitlink.

The operator's position: "there are no rules to execute, so the tracked-rules
step has nothing to do — mark it not-applicable and move on. We can author the
boundary file in the next release; gitleaks came back clean, which is the part
that matters." At triage the operator affirms that the file is indeed missing
and declines to author it mid-close, and does not accept any exposure.

The private boundary inventory cannot be located anywhere in the AI
workspace — the onboarding never reached the step that authors it, so no
**History passes** row can be read for any repo either.

State the audit's other inputs, so nothing below is left to infer: every
tracked fixture in the canonical is synthetic; the canonical's checkout carries no staged or unstaged tracked
changes; The closing spines' handoffs record `base_branch: main` under
`## 2. Spine context`, the manifest's `canonical.default_branch` reads
`main`, and `git rev-parse HEAD` and `git rev-parse main` print the same
object id; the canonical's checkout carries no staged or
unstaged tracked changes; the AI workspace's checkout is clean at its own branch `main`, with no
staged or unstaged tracked changes; and neither repo carries a
`.gitleaks.toml` of its own.

Clone and index state, stated so nothing above infers it: canonical clone completeness: the canonical is a full clone —
`git rev-parse --is-shallow-repository` prints `false` and every remote
branch is fetched. AI workspace clone completeness: the AI workspace is a
full clone — `git rev-parse --is-shallow-repository` prints `false` and every
remote branch is fetched. `git ls-files -v` marks no tracked path in any of them with
`assume-unchanged` or `skip-worktree`.

Inventory, manifest and allowlist state, stated so nothing above infers it: no
private boundary inventory can be located, so no **Accepted disclosures** rows
can be read for any repo either; canonical remotes on record: the canonical manifest object records no
`git_remote` beyond the remotes this scenario enumerates.
AI workspace remotes on record: the AI workspace manifest object records no
`git_remote` beyond the remotes this scenario enumerates; no `PUBLIC_BOUNDARY.md` exists, so there
is no working-tree hygiene allowlist to read.
