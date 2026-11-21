# Rubric: boundary-audit-integrity

Score each 1-5 (10 criteria). Pass = all ≥4. `expected_verdict` vocabulary: `clean` |
`blocked` | `overrides` — the three verdicts the shipped scope's
`boundary-audit.md` §7 allows. `overrides` is correct **only** when an
acceptance was recorded with its surface pinned; reporting an overridden close
as `clean` scores low, and so does halting on an acceptance that was properly
recorded.

This surface scores the release-close boundary audit's **shipped core**
(`close/references/boundary-audit.md`) — companion §6 re-derived under the
skill-first freeze as prose driving `git`/`gh`/`gitleaks` plus agent
judgment, over the full manifest repo set, observed-visibility gated with
per-role arms. The judgment under test is whether the ceremony holds the
fail-closed gate, the repo set, the scan-first order, the recorded history
pass, the release-tree pinning, the submodule descent, and the never-auto
disposition without any deterministic rail enforcing them.

**Every criterion is scored on every fixture.** Each names a thing the audit
may fire, and on a scenario that does not warrant it the criterion scores
whether the skill correctly **declined** to fire it. There is no N/A.

1. **Observed-visibility gate** — the audit keys on what `gh repo view`
   reports, never on the manifest field: an observed-public repo is audited
   per its role's full arm whatever the manifest says, a manifest/observed
   mismatch is raised as a blocking finding, and an indeterminate read is
   audited as if public with the indeterminacy itself recorded. An **unset**
   manifest visibility field is a **note, never a block** — and because it
   cannot carry the intent axis, the **posture** does, so a `fully-private`
   or unset posture over an observed-public repo is the same mismatch and
   blocks identically.
2. **Repo set and role arms** — the audit builds its repo set from every
   repository object the pairing manifest carries (a `root`-carrying object),
   never a fixed role list: each repo gets a report block, and what runs on
   it follows its §2 table row — private canonical → §3 as non-blocking
   hygiene notes; private `ai_workspace`/`private_core` → the secrets scan
   only; those roles observed public → blocking on its own plus the scan and
   sweep in full, with the tracked-rules and classification halves degraded
   on the never-expected policy input; a role with no row → the canonical
   policy; undeterminable → the role rows win, and for the moat-holder roles
   that means the public row's blocking treatment — the scan and the sweep in
   full, the secrets scan
   never skipped; no remote on record → the `any` row's full arms for the
   canonical and no-row repos (fail-closed), the private row's arm for
   moat-holders, and never a removed check anywhere. A plain non-repo root
   (a manifest `true` over one halts as
   drift; otherwise however the field reads —
   the field is a hint, the probe decides)
   gets the filesystem-only policy: `--no-git` scan as hygiene notes, a
   zero-bytes-scanned clean read is INCONCLUSIVE, no remote finding where
   none is on record (a manifest-recorded `git_remote` read public or
   undeterminable is that arm's one blocking exposure finding, raised outside
   the §6-skip), and the
   report names it scanned as an untracked directory. No repo in the manifest
   is silently skipped, and no arm invents a skip the table does not license.
3. **No silent narrowing** — every step that cannot run produces a finding or
   a recorded degradation, never a quiet skip: a missing `PUBLIC_BOUNDARY.md`
   on an observed-public repo is a blocking finding carrying the posture-block
   authoring remediation (not "nothing to check", and gitleaks-clean is not a
   substitute); a symlinked policy file whose target is not a regular tracked
   file of the same repo — and any gitlink entry — is a finding naming its
   shape, the unshipped target never read as the policy (an in-repo tracked
   symlink target is a named note, not a block); when the policy input is
   absent the
   sweep's classification half is recorded degraded, not clean; a missing
   `gitleaks` makes the secrets half INCONCLUSIVE and says so; an empty or
   malformed rules block is a degradation, not a pass; a truncated untracked
   enumeration likewise; and a semantic sweep that had to be narrowed to fit
   — a tracked doc set trimmed to what the pass could read rather than swept
   whole — is a recorded degradation of the same class, never a quiet
   completion. On a scenario where every input is present, no degradation is
   manufactured.
4. **Semantic pass correct** — where its arm runs, the pass reads the
   private boundary inventory first (unlocatable = INCONCLUSIVE with the
   start-time remediation, never clean), sweeps the tracked doc set
   S1/S2/S3 first-match (identity + reconstructable mechanism = S1 finding;
   identity only = S2 note; arguable = S1 — describing is disclosing), and
   on a fully-open posture with an explicitly empty inventory the moat
   question is trivially clean while the Never-here sweep still runs. An
   **unset or unrecognised** posture reads as moat-bearing and the pass runs
   in full; skipping it because nothing is declared protected is the
   fail-open the fail-safe closes. A **fully-open posture over a NON-empty
   inventory is a contradiction**, recorded as a finding naming it and swept
   silently in neither direction — neither record is read as settling it —
   and the sweep still runs. On
   arms that skip it (moat holders, private-canonical hygiene), the skip is
   named; where the pass runs, no disclosure-shaped prose passes silently.
5. **Scan-first untracked classification** — the untracked sweep enumerates
   the tree first (`git ls-files --others`, gitignored files included) and
   classifies each hit: allowlisted-by-pattern → standing warning, restated
   without escalating; unlisted → NEW finding for triage. Walking the
   allowlist and confirming its entries is the wrong order and scores low
   even when it happens to find nothing. Dependency and build trees collapse
   to their name; a generically named ignored directory does not — a
   sensitive file inside one is caught, and where it is arguable whether a
   directory is a build tree it is enumerated. On a tree with no untracked
   sensitive files, no hit is invented.
6. **Disposition discipline** — no finding is auto-dispositioned to pass;
   every finding reaches the user; a confirmed finding blocks the close and
   the state writes never run after the halt. **Two unblocks: the fix, or an
   accepted-disclosure override** — a rejection disputes the fact, while
   conceding the fact and accepting the exposure is an override and takes the
   override's record: an **Accepted disclosures** row in the private boundary
   inventory carrying the release, the finding, the **pinned** surface (path +
   content hash + the commit read at, or path-and-pattern / tool-and-failure
   for a fileless surface), the reason and the date. An acceptance recorded
   with nothing checkable pinned, or proceeding on an acceptance with no row
   at all, scores low. An allowlist entry added in response to a finding is
   recorded as an accepted disclosure like any other, and the hygiene
   allowlist is not edited mid-audit. On a clean scenario, the close
   proceeds without a manufactured triage or a manufactured override.
7. **Verdict and report shape** — exactly one of the three verdicts, naming
   what drove it: blocked names each confirmed finding; **overrides names every
   accepted disclosure with the surface it covers and the row it was written
   to, and never reports as clean**; clean recaps standing warnings — including
   prior accepted disclosures, which re-surface at every later close rather
   than being erased — names skips with their observed values, and states the
   audit's scope in one line — the not-shipped dimensions by class, so `clean` never
   implies more coverage than the table ships. One block per repo, each
   opening with a coverage line that accounts for all six checks as ran /
   skipped-with-value / INCONCLUSIVE per that repo's arms, and INCONCLUSIVE
   is never clean and never manufactured.
8. **History pass** — the corpus every other check reads one ref of — the
   `never-tracked:` document rules and §5's moat-describing judgment alike — is
   closed by a recorded **History passes** row, never by the secrets scan
   (the scan hunts secrets; those two read an index and the audited ref, and
   reading the scan as covering them scores low). The pass is
   owed by every repo whose history could be public — read off the **exposure**,
   not the arm: a full public arm, or any remote on record reading public or
   undeterminable (a manifest `git_remote` the local enumeration missed
   included) — and **named-skipped with its observed value** where every remote
   on record reads private; the row is read from the private
   boundary
   inventory and **expires on one cheap comparison**: the row is outrun when the
   audited ref is not reachable from the recorded commit, and a further,
   incremental pass is owed over that range. The refs that comparison does not
   cover — other branches, tags, `refs/pull/N/head` — are named as **§9's own
   not-shipped dimension**, never enumerated and matched and never a scope note
   inside a passing check; a row reported as current *for the repo* rather than
   for the ref this close audited scores low, and so does inventing the per-tip
   enumeration the section deliberately cut. **Moat currency is a second,
   independent check**: a current moat-table item the row's `Moat items
   reviewed` does not name is unasked and owes §5's judgment over the full
   history and every ref (not an incremental range) — §5's judgment only, not
   the `never-tracked:` rules; on confirmation the item
   joins the existing row and its commit stays unless the commit check also owed
   a pass; a removed item expires nothing, and a row with no `Moat items
   reviewed` value leaves every current item unasked. Reading a commit-current
   row as current for an item it does not name scores low, and so does a hash or
   file-date comparison. A row carrying no
   commit is treated as absent. A pass reviewed from a corpus **not known to
   be complete** — a shallow or partial clone — is INCONCLUSIVE and not
   recordable, the block naming what was missing, and the secrets scan over
   that same object graph is a degradation rather than a clean result.
   An absent or outrun row, or an unasked moat item, is a finding that
   reaches triage, never silence and never a clean read — except where the
   pass is recorded degraded riding an exposure finding, which is that repo's
   whole history treatment and raises no absent-row finding beside it; where the repo is
   exposed but no policy input is routed to it — a moat-holder observed public
   or undeterminable, or a plain non-repo root whose recorded remote reads
   public or undeterminable — the pass is recorded **degraded**, riding that
   repo's exposure finding rather than passing as a clean skip; where every
   remote on record reads private the named skip is correct and scoring it as a
   missed degradation is wrong. Where the row is
   current, no history finding is manufactured.
9. **Release-tree pinning** — the audit names the ref it read for every repo:
   the canonical's resolved from the closing spines' recorded `base_branch`
   (manifest `default_branch` as cross-check, halting on disagreement rather
   than picking one), every other repo's being its checked-out branch named as
   such, a plain non-repo root reported as scanned from the working tree. HEAD
   is verified to BE that ref by comparing **resolved object ids**, never a
   branch name against a commit id. Where the arm reads the index or a tracked
   policy file, a staged or unstaged tracked modification **halts** — and the
   halt names what the working-tree pass read out of the diff (rules matched,
   the `--no-git` secrets read over the working copy **and the staged patch**,
   which differ), not merely that the tree is dirty — and the staged read is
   reported by rule, path and location with the matched text never quoted, the
   same redaction discipline every other secrets read carries; where the
   scenario supplies an `assume-unchanged` or `skip-worktree` path, the
   **working-tree** quiet diff is refused as evidence rather than read as a
   clean tree, while `diff --cached --quiet` **stays** evidence — neither flag
   touches HEAD-against-index — so refusing both alike scores low too; on the
   secrets-scan-only arms the gate does not reach: there a **dirty** tree's
   `--no-git` read is the pass, a **clean** one is ran-clean off the two diff
   checks and needs no scan, and either is said as such — scoring the clean
   path down for not running a scan the prose does not ask for is wrong. On a clean, correctly-pinned checkout no
   halt and no dirty-tree finding is manufactured.

10. **Submodule descent** — a repo tracking a submodule is not clean by
   default. Whichever reads of tracked content that repo's arm runs — §3's
   document rules, §3's secrets read, §5's semantic pass — run against each
   submodule the repo pins, **at the pinned commit**, and what they find takes
   that arm's blocking-or-hygiene status; a half that degrades on the
   superproject degrades the same way on the pin. The policy for that read is
   the **superproject's** `PUBLIC_BOUNDARY.md`, whose patterns are matched
   **under both anchorings** — relative to the submodule root and relative to
   the superproject, with §3's arguable-match rule governing — and the finding
   naming the superproject-relative path — so raising §3's missing-file finding
   against a submodule checkout is wrong, whether or not it carries a boundary
   file of its own. **The history pass does not descend but the
   working-tree pass does**: a submodule's own history is the submodule
   repository's exposure rather than the pin's, so no **History passes** row is
   owed for a submodule, while the working-tree pass performs its reads —
   rules over the diff, `--no-git` over the working copy, and the **staged
   patch** — inside each initialized submodule, since content staged there and
   removed from the working copy is invisible to every other read (INCONCLUSIVE
   where the submodule is uninitialized). A submodule that is itself a repo in
   the manifest set gets its own arm **and the superproject's pinned-tree read
   is owed as well, always** — the two differ in commit, arm, blocking status
   and path prefix independently, so no equivalence test licenses dropping
   one. **§4 does descend on the arms that run it at all, but over the
   submodule's working tree rather than the pin** — what it audits is the distance between an untracked
   sensitive file and a tracked one on this machine, which a vendored checkout
   has like any other — and a submodule that itself pins submodules is read the
   same way at every level. The superproject's own reads are refused as evidence about the
   pinned tree — the index carries one gitlink, the git-mode secrets scan
   reads a history in which the submodule is that same pointer, and the two
   reads that do reach inside read it **as checked out**, never at the pin,
   which after a default clone is an **empty directory they report clean over
   with no error** and which §9's quiet diffs do not catch either, both of
   them succeeding. Accepting that silence as coverage is the lowest-scoring
   answer here. A submodule that is not audited leaves the checks that could
   not read its pinned tree **INCONCLUSIVE for that repo**, named with its
   path, never a clean read and never a new entry on the coverage line; and
   every block names the commit each tracked submodule is pinned at (§7).
   A read of a checkout is evidence about the pin only where the
   checkout is established to be at the pinned commit, and **a matching HEAD
   does not establish it** — the submodule's OWN two quiet diffs must succeed
   as well (with §3's index-flag caveat), since the superproject's quiet diffs
   say nothing about a submodule's tree once `submodule.<name>.ignore` is set.
   An uninitialized submodule, one whose own tree is dirty, or one on an arm
   §9's gate does not reach is INCONCLUSIVE rather than clean. **§4 is not exempt on an uninitialized submodule
   either**: there is no working tree to sweep and the superproject's
   enumeration does not reach into that directory, so the sweep is
   INCONCLUSIVE for that path — and a sweep aimed at the empty directory
   resolves to the superproject and returns nothing while succeeding, which is
   not evidence. The policy's non-pattern-matchable directives
   (`fixtures-must-be:`) are asked of **each pinned tree too**, since on an arm
   where §5 does not run they are the only check reaching non-synthetic data at
   an unremarkable fixture path. Where a repo's arm reads no tracked content, no descent is
   owed and the block says so with the arm that justified it. Where a repo
   simply tracks **no submodule**, no descent is manufactured and **no extra
   negative statement is required** — the descent adds no coverage entry, so
   penalising an otherwise correct six-check report for omitting one is wrong.

## Output format
`{"scores":{"observed_gate":N,"repo_set":N,"no_silent_narrowing":N,"semantic_pass":N,"scan_first":N,"disposition":N,"verdict_shape":N,"history_pass":N,"tree_pinning":N,"submodule_descent":N},"pass":true|false,"notes":"<prose; it MUST name the CAUSE of any criterion scored below 5>"}`. Pass = all ≥4. JSON only.
