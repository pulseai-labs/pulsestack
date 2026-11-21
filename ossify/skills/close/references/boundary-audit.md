# Boundary audit — the last finding-producing step of a release close

Depth for SKILL.md §6 step 7. Implements the companion spec (public/private
boundary, 2026-07-12) §6, **re-derived 2026-08-15 under the skill-first
freeze** (the companion's construction note governs): the spec's
"mechanical-first" wording predates the freeze, so this step ships as **prose
driving external tools plus agent judgment** — `git`, `gh` and `gitleaks` do
the enumerating, the agent does the matching and the judging, and no new
deterministic runtime code exists anywhere in it. Two deliberate deltas from
the companion's §6 text are recorded inline (both in §2), each with the reason
it is safe.

**This release ships the audit's core scope — the tracked-file audit with the
two corpus passes §3 adds to it, the secrets scan, the untracked sweep, and the
semantic pass — over the full repo set: every
repository object the pairing
manifest carries, each gated on its observed visibility with per-role arms,
and each tracked submodule's pinned tree audited by that same arm
(§2).** What is still deliberately absent — divergence on a public ref other
than the one audited after a recorded history pass, and every submodule pin but the audited
ref's together with a non-manifest pinned submodule repository's own
history — §9's table names rather than leaving it to read as executed. A dimension nobody wrote a rule for reporting clean is the
one failure shape this file exists to prevent; scope cuts get the same
treatment.

This file is blockless by intent. Every command it names is an existing
external tool invoked as written; there is nothing here for the
executable-prose harness to extract.

---

## 1. When it runs, and what a halt means

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

At **every release close**, after the feature-map re-groom and next-release
sketch, **before the state writes** — the audit is the last thing that can
refuse the close. A confirmed finding halts the ceremony, and the halt reaches
the close record: `oss release_status <rel> closed` and the `demo_record` line
never run. A release therefore cannot be closed "with a leak noted" — it is
closed after the finding is fixed, or the disclosure is accepted on the record
§6 requires — never on a note in the summary. (The second unblock, the
accepted-disclosure override, ships with its record and its bounds — §6.)

**A halt here is not free, and saying so is part of the step.** The re-close is
not free and steps 1-6 are not free to repeat — `release-close.md` §8 owns that
accounting (the unconditional `feature_add`, the stored `next_sketch`, the
amended-not-re-authored retro, the §8 walkthrough or walk-equivalence citation); read it before you halt.

---

## 2. The repo set, and the visibility gate

**Build the repo set from `ai_workspace` plus every declared repo the
manifest carries, not from a fixed list of roles** — walk up from the cwd
for `.ossify/topology.json`
**first**, then `.workspace/pairing.json` if no topology file is found — the
same order `oss_topology_discover` resolves through (`lib/manifest.sh`),
which every `oss repo_root`/`oss state_path` call this file makes already
routes on, so stopping this walk at one manifest kind would desync the
enumeration below from what those calls actually resolve. `ai_workspace` is
always in the set — `oss repo_root ai_workspace` resolves it under either
manifest kind, since it is never a `.repos` member itself (the topology arm
never assigns it there; the pairing arm filters it out). Every OTHER repo is
a declared repo, taken:
under a native topology, from every key in `.repos`; under a
legacy pairing manifest, from every top-level object that carries a `root`
other than `ai_workspace`: the
canonical (`oss repo_root canonical`, when a project names one that),
a `private_core`, and the optional `tooling_repo` workspace-init emits when a
project volunteers one. Hard-coding three role names is how a public tooling
repo ends up holding tracked secrets while the release reports clean. A role
this file states no row for in the table below is audited on the
canonical-policy row — never skipped. **A repo's manifest role is
structural** — workspace-init writes it, and it is not the pending per-repo
`visibility` field (§2's intent note below).

**Read each repo's `git_tracked` before anything else, because not every
manifest repo is a git repo.** workspace-init's Scenario C pairs an AI
workspace that is deliberately untracked (`ai_workspace.git_tracked: false`),
and every git command in this file would fail against it — turning a supported
topology into a permanently undeterminable audit with no repository fix
available. **The field is a hint, not the determination:** workspace-init
writes `git_tracked: false` for a workspace nested inside a parent repo, a
bare repo, or a linked worktree as well as a plain non-repo, the optional
`tooling_repo` object carries no `git_tracked` field, and a stale `true` can
outlive
a de-gitted directory — so wherever the field reads `true`, `false` **or**
is absent, determine the root directly — `git -C "<root>" rev-parse
--show-toplevel`, which must print the root itself: a bare
is-inside-work-tree probe answers a different question (a directory nested
inside any parent repo passes it, and every later `git -C` would then audit
the parent) — and record which you did. `git` resolves symlinks in the
output, so resolve the manifest root the same way before comparing, and
reject only when the output is a strict ancestor of the root — a directory
nested inside a
parent repo, which is neither a repo root nor a standalone tree: its content
sits in the PARENT's index, on the parent's remotes, and no arm in this file
audits the nested path as itself. Its disposition depends on the parent: **a
blocking finding naming the topology when the parent is outside the repo
set** (the manifest names a root whose content the parent may track and
expose, and nothing audits the parent); **a scope note when the parent is
itself a manifest repo in the set** — the nested paths sit inside the
parent's tree and are audited as part of its block; the nested entry adds no
arm of its own, and the note says the paths were audited as parent content,
not as a root. A linked
worktree is identified not by the toplevel but by
`git -C "<root>" rev-parse --git-dir` differing from
`git -C "<root>" rev-parse --git-common-dir` — its root is its own worktree
of another repository's git dir, the filesystem-only premise (no index, no
history) is false, and it halts and names its shape. A root where
`--show-toplevel` fails splits on
`git -C "<root>" rev-parse --is-bare-repository`: a refusal there too means
no git directory at all — the plain non-repo, the flagship Scenario-C shape —
which gets the **filesystem-only** policy; a printed `true` is a bare repo
(index and history exist, no working tree this policy assumes) and halts and
names its shape; a printed `false` after a `--show-toplevel` refusal is a
shape this tree does not otherwise name — halt and name it rather than
guess. **The field records intent; the probe records topology; and topology
governs.** A `true` over a plain directory halts and names the drift (the
manifest records the project's belief; a directory contradicting it is
drift). A `false` over a repo root resolves by the probe outcome — the
shapes workspace-init labels `false` are exactly the shapes the probe
distinguishes — with a note naming the disagreement. Otherwise — the field
absent or agreeing with the
probe — a repo
that is not a git
repo gets the **filesystem-only**
policy — except any declared repo, where §9 halts the close instead: the
product repository has nothing to audit. The policy means: no index, no
remotes and no history, so this section's
visibility gate and §3's tracked-file rules do not apply to it. **An
exposure question survives any untracking:** the manifest object itself may
carry a `git_remote` alongside a `false` or absent tracking field
(workspace-init's remote and tracking flags are independent) — a repo that
was pushed and later
untracked. Read that recorded remote with `gh repo view` (a `gh` read needs
no local git): public or undeterminable is a **blocking finding** naming the
recorded remote — the content may sit on a host regardless of what the
directory is now, and this one finding blocks the close on its own, outside
the §6-skip that otherwise governs the filesystem-only arm; private is a
note. And the recorded-remote read is not only for plain non-repo roots: for
**every** repo in the set, any `git_remote` the manifest carries that the
local enumeration did not list is read the same way — a removed local remote
is one `git remote remove` from an unaudited exposure, and the manifest
remembers it. A repo with no remote on record anywhere
— no manifest `git_remote`, no local remotes to enumerate — raises no remote
finding, and the report says so as a scoping note ("no remote on record"),
never as an impossibility claim: a de-gitted workspace can have been pushed
before pairing, and the filesystem-only arm's limits are what the coverage
line names. Run **§3's
secrets scan** over its working tree as hygiene notes — with the
secrets-class carve-out the table carries, a secrets hit blocks on every
arm — via
`gitleaks detect --source "<root>" --no-banner --redact --no-git`. **The
`--no-git` flag is load-bearing:** `gitleaks detect` defaults to walking git
history, and against a directory that is not a repo the default invocation
exits **0** with `no leaks found` after `0 commits scanned` and
`~0 bytes` — a pass that read nothing, on the repo that holds the moat by
construction; `--no-git` is what makes the scan read the working tree.
(`--redact` for the same reason §3 states it: an unredacted hit
quotes the matched secret into the transcript on the exact leak-handling
path.) And whichever invocation produced it, a run reporting zero bytes
scanned against a root that has files is INCONCLUSIVE (§3): rc 0 and
"no leaks found" are not evidence that a scan happened. §4, §5 and §6 are skipped
for the role — §4 because an untracked sweep enumerates the complement of an
index this repo does not have (a directory-tree judgment read over an
untracked workspace is named future scope in the report, never silently
clean); §5 because the semantic pass sweeps a tracked doc set this repo
does not have, and the moat holder is excluded from the pass by §2's own
rule; §6 with them. Say in the report that it
was scanned as an untracked directory. Its lack of a *local* remote is never
a finding — the exposure question for this repo is the recorded
`git_remote` above, where one exists.

### Determining observed visibility

Enumerate **every** remote, redacted — `git -C "<root>" remote -v | sed -E 's#([A-Za-z][A-Za-z0-9+.-]*://)[^/[:space:]]*@#\1***@#g'` — not just
`origin`: a remote may be named `upstream` or `github`, `origin` may be a
private fork of a public upstream, and a repo may push to both. The redaction
is not cosmetic: a remote can carry its credential inline
(`https://<token>@github.com/...`), and printing that bare puts the token
into the transcript before the audit has even started — the §3 rule reaches
the enumeration too.

**The pattern is scheme-generic and case-blind on purpose**, and each of those
three properties has its own leak behind it. Git preserves the scheme's
spelling, so an `https?://`-only pattern prints `HTTPS://secret@github.com/…`
unchanged. Credentials are not an HTTPS-only affair — `ssh://user:pass@host/…`
is a valid remote. And `[^/[:space:]]*@` reaches the LAST `@` before the first
`/`, where `[^/@]+@` stops at the first one and leaves the tail of a password
containing `@` (`https://user:p@ss@host/…` → `https://***@ss@host/…`) in the
transcript. `tracker.md` §5 redacts the same three ways for the same reasons;
these are the only two redaction sites in the plugin, and they agree. For each remote, derive
**`host/owner/name`** from the redacted form and read
`gh repo view "<host>/<owner>/<name>" --json visibility`. **Gate on the most
public answer**: one public remote makes the repo observed-public, whatever the
others say.

**Carry the host, do not drop it.** `gh`'s repository selector is
`[HOST/]OWNER/REPO`, and with the host omitted it resolves against `GH_HOST` or
its own default — so a GitHub Enterprise remote queried as bare `owner/name`
can answer about a *different* host's repo of the same name. Where that other
repo is private, an observed-public Enterprise repo is misclassified as private
and takes a private row's lighter arm. Every path in this file that quotes a
root or a
selector quotes it: manifest-resolved paths may contain whitespace, and
`close/SKILL.md` §8 already requires `git -C "<absolute path>"`.

**The gate's answer decides which row of the arms table a repo takes — and
the `any` row's full §3-§6 runs on an exact, case-insensitive `public`, an
indeterminate read, or (for a no-row repo only) no remote
on record (§2's fail-closed routing); the
role rows govern their roles as written below.**
Anything indeterminate — `internal` (GitHub Enterprise's
org-wide visibility, which is on the wrong side of this gate), an
unrecognised value, an empty result, a non-GitHub host, `gh` unauthenticated,
the API unreachable — is audited **as public**, and the inability to determine
visibility is itself recorded as a finding. Fail-closed: a repo you cannot
prove private is treated as public.

### What each outcome runs

| Role | Observed | What runs |
|---|---|---|
| any | public (or undeterminable, or — for a no-row repo only — no remote on record, §2) | §3, §4, §5 in full, findings **blocking**; §6 runs |
| `canonical`, or any other declared repo with no row of its own | private | §3 only, as **non-blocking hygiene notes for the document and strategy classes** — a missing `PUBLIC_BOUNDARY.md` is a hygiene finding here, not a blocking one. **A secrets-class hit blocks on every arm:** a tracked credential or a live secret the scan found is a rotation question, not a visibility question. §4, §5 and §6 skipped (the semantic pass: a private repo discloses nothing — named skip) |
| `ai_workspace`, `private_core` | private | §3's secrets scan only, as hygiene notes — with the same secrets-class carve-out: a secrets hit blocks. §4, §5 and §6 skipped (the semantic pass: a private repo discloses nothing — named skip) |
| `ai_workspace`, `private_core` | **public** | **blocking finding on its own** — these roles are private by construction. **The secrets scan and §4's sweep run in full, and §6 runs — §5's semantic pass never runs on the moat holders (§5)** (the tracked-rules half degrades on the never-expected policy input — §3): the repo is already exposed, and a skipped sweep means an exposed workspace is never examined |
| `ai_workspace`, `private_core` | undeterminable | the undeterminable read of an **on-record** remote is a **blocking finding on its own** — a repo you cannot prove private is treated as public, so this row is the public row above: the scan and the sweep run in full, and §6 runs — §5 never runs on the moat holders (the tracked-rules half degrades on the never-expected policy input — §3). A moat-holder with **no remote on record at all** cannot be read undeterminable — it takes the private row's arm with the no-remote rule below |

**No remote on record — enumerated or recorded (§2) — never removes a
check.** The row the repo takes still runs its secrets scan and, where that
row runs it,
§4's sweep: absence of a remote narrows the *exposure* claim, never the
scan, and the scoping note says so in the block. What the absence decides is
only *which row* a no-row repo takes — `canonical` when a project names one
that, or any other declared repo with nothing more specific to say about it:
such a repo with no
remote on record takes the `any` row's full arms — fail-closed, a repo you
cannot read private is audited as public — with the scoping note carrying
the exposure narrowing; a moat-holder with no remote on record keeps the
private row's arm, per its own row above; and a plain non-repo root never
takes the `any` row at all — §2's topology rules govern first.

**Every declared repo takes the same default policy unless a row above names
its role specifically — the row this table has always labelled `canonical`,
because a project's product repo is usually named that.** Nothing in this
table keys off the literal string: a project with more than one
product-facing repo, or one whose product repo is named something else
entirely, gets exactly this row for each of them — legacy single-canonical
behaviour is simply the translated case where one declared repo happens to
be spelled `canonical`. The optional `tooling_repo` is the other live case:
observed private, it matches neither the `any`
row (public, undeterminable, or no-remote-on-record only) nor the two private-by-construction role
rows, and would otherwise have no defined checks at all despite this section
claiming every manifest repo is audited. It is a product-adjacent repo, not a
moat holder, so it takes this same default row — §3 as hygiene notes when
private, the full §3-§6 when public.

**Role-specific rows win over the `any` row.** An undeterminable read is
audited as public (above), so an `ai_workspace` with unreadable visibility
matches three rows at once; the role rows are the answer, and the `any` row
governs every repo on the default row — `canonical` when a project names one
that, and anything else the manifest adds.

Every skip is named in the report with the observed value that justified it.

**The two corpus passes §3 adds are routed by this table too, and neither is a
new row.** The **history pass** is owed off the exposure rather than the arm
(§3). The **working-tree pass** runs on every arm that has an index: on the arms
that read the index or a tracked policy file it runs at §9's gate, and on the
secrets-scan-only arms, **where the tree is dirty**, it is the `--no-git` read
§3 prescribes — that invocation is part of this table's arm for those roles
whenever it is reached, alongside the history scan, because the history scan
cannot see an uncommitted edit. A clean tree there needs no scan: the pass is
ran-clean off the two diff checks, exactly as §3 states. Both are named in
every block's coverage line whatever they did.

**A tracked submodule is another tree this table's arms read, and it is not a
new row either.** A repo tracking one is **not clean by default**. What a
superproject publishes is the **pin** — a URL and a commit id — and whether
that commit's tree is readable turns on the submodule repository's own
visibility. **This audit does not read that visibility and raises no finding
about it**: the pinned tree is read *as if readable*, which is why the repo is
not clean by default, while the arm that classifies what the read finds is the
**superproject's**, exactly as the table above assigns it.

Nothing the audit runs over the superproject establishes anything about that
tree. The index carries the submodule as a single gitlink, so the document
rules match a commit pointer rather than the tree it names; the untracked sweep
cannot descend at all (`--recurse-submodules` is not a supported mode for
`--others` — git refuses it outright); and the secrets scan in git mode reads
the superproject's own history, where the submodule is that same pointer. Two
reads *do* reach inside — `ls-files --recurse-submodules` and the `--no-git`
scan — but both read the submodule **as it is checked out**, never the commit
the superproject pins, and after a default clone that is an **empty directory
both of them report clean over, with no error**. §9's release-tree gate does
not catch that either: an uninitialized submodule leaves both `diff --quiet`
checks succeeding, so the tree reads clean. That silence is the failure shape
this file exists to prevent.

**So the descent rides the arm: whichever reads of tracked content a repo's arm
runs — §3's document rules, §3's secrets read, §5's semantic pass — run against
each submodule that repo pins, at the pinned commit, and what they find takes
that arm's blocking-or-hygiene status.** A half that degrades on the
superproject degrades the same way on the pin. **§4 descends too on the arms
that run it at all, but over the submodule's working tree rather than the
pin**: an untracked set is a property
of a checkout and not of a commit, and what §4 audits is the distance between
an untracked sensitive file and a tracked one on the machine this close runs
on — which a vendored checkout has like any other tree. **And a submodule
that itself pins submodules is read the same way, at every level.**

**A read of a checkout is evidence about the pin only where the checkout is
established to be at the pinned commit — and a matching HEAD does not
establish it.** A submodule whose HEAD equals the pin can still have tracked
content modified or deleted in its own index or working copy, and the read
then reports on that altered tree rather than on the pin. So the submodule's
**own** `diff --quiet` and `diff --cached --quiet` must succeed too, under the
same caveat §3 carries: an `assume-unchanged` or `skip-worktree` path there
makes them succeed over a tree that differs, and where either flag is present
they clear nothing. **The superproject's quiet diffs are not evidence about a
submodule's tree at all** — `submodule.<name>.ignore` silences them, so a
superproject can read clean, and `status` report nothing, while the submodule
holds deletions the pinned tree does not. Those two submodule-side checks
establish the pin on **every** arm, including the secrets-scan-only ones §9's
release-tree gate never reaches — a repo whose pinned submodule is initialized
at the expected commit with a clean index and tree is not held INCONCLUSIVE for
want of a gate that does not apply to it. A submodule that is not audited, or
whose checkout nothing establishes to be at the pin — an uninitialized one, or
one whose own diffs do not come back quiet — leaves the checks that
could not read its pinned tree **INCONCLUSIVE for that repo** (§7), named with
the submodule's path and the commit pinned: a clean read over an unexamined
tree is the same shape as a clean read over an unrun scan. **§4's sweep never
claimed the pin, but it is not exempt either:** it sweeps a submodule's working
tree where there is one, and where the submodule is **uninitialized** there is
no working tree to sweep while the superproject's own enumeration does not
reach into that directory — so the sweep is **INCONCLUSIVE for that path**,
never clean. A sweep aimed at the empty directory is not evidence to the
contrary: with no repository there it resolves to the **superproject** (§2's
nested-parent hazard) and returns nothing while succeeding, so a sensitive file
sitting under an uninitialized submodule is invisible to both reads and both
report clean.

The **superproject's** `PUBLIC_BOUNDARY.md` is the policy for those reads — it
is the superproject that publishes the pin — so §3's missing-file finding does
not fire against a submodule checkout, whether or not that submodule carries a
boundary file of its own. Its `never-tracked:` patterns are matched against the
submodule's paths **under both anchorings**, relative to the submodule root and
relative to the superproject, with §3's rule that an arguable match **is** a
match governing the result; a finding names the superproject-relative path. The
block's non-pattern-matchable directives (`fixtures-must-be:`) are asked of
**each pinned tree too**, not only of the repo whose policy it is: the
superproject publishes that tree, and on an arm where §5 does not run they are
the only check that reaches non-synthetic data sitting at an unremarkable
fixture path — no pattern matches it and no scan calls it a secret. Where a repo's
arm reads no tracked content, no descent is owed and the block says so with the
arm that justified it.

**The history pass does not descend; the working-tree pass does.** A
submodule's own history is the submodule repository's exposure rather than the
pin's, so a submodule never adds a **History passes** row of its own — and
where that repository is not itself in the manifest set, its history is §9's
own not-shipped dimension. The **working-tree pass** is the opposite case: it
performs its reads **within each initialized submodule** — the rules over the
diff, the `--no-git` read over the working copy, and the read of the **staged
patch**. Nothing else reaches a submodule's index: the pinned-tree reads see
the commit, §4 sees untracked files, the superproject's `--no-git` scan sees
only what is on disk, and the superproject's own staged-patch read stops at the
gitlink — so content **staged inside a submodule and removed from its working
copy** is invisible to every other read this audit performs, which is exactly
the shape §3 makes the staged read mandatory for. Where a submodule is not
initialized there is no index to read and the pass is INCONCLUSIVE for that
path.

**A submodule that is itself a repo in the manifest set gets its own arm, and
the superproject's pinned-tree read is owed as well — always.** They answer
different questions: that repo's own block answers for its own exposure at its
**checked-out** ref (§9), and the superproject's block answers for the tree
this release publishes through the pin. The two can differ in commit, in arm,
in blocking-or-hygiene status, and in the prefix their paths are matched under,
and those vary independently — so no equivalence test licenses dropping one
read for the other. The descent adds **no entry to the coverage line**: it is
those same checks, run against another tree.

**No arm of this table skips the secrets scan.** Scanning does not depend on a
remote (below), so it cannot depend on being able to *read* a remote either.
The visibility finding and the secrets scan are independent; a repo whose
visibility is unknown gets both.

**Why private repos are scanned at all** (and the second delta from the
companion, which scoped the whole audit to public repos):
`start/references/posture-block.md` §6 requires **even a fully-private
project** to author `PUBLIC_BOUNDARY.md`, because hygiene is independent of
visibility and it is what keeps a later flip to *one* ceremony. A rule block
that never executes for the project's entire private life gets its first run
at the flip, when a hit means a history rewrite instead of a `git rm`. Hygiene
notes cost nothing and are the whole point of authoring the file early.

**Why `ai_workspace` and `private_core` stop at the secrets scan:** they hold
the moat by design. §3's `never-tracked:` document rules have nothing to read
there — `start` routes `PUBLIC_BOUNDARY.md` to public-facing repo roots only,
so on these roles the rules half degrades on the never-expected input (public
arm) or is skipped outright (private arm), never a missing-file block — and
§5's semantic pass never runs against the repo that holds the moat inventory
either — every finding there would be expected, which is indistinguishable
from a real one.

**Scanning does not depend on a remote.** §3 and §4 read the index and the
working tree; they need no network beyond the visibility read above. A repo
with no remote today may still have been pushed yesterday — absence of a
remote narrows the *exposure* claim, never the scan. (An earlier draft scoped
the whole step to repos with a remote "because nothing can have left the
machine". That is false for a repo whose remote was removed after a push, and
it is one `git remote remove` from defeating the audit.)

### Intent versus observation

A repo the manifest calls private that `gh` reports public is a **blocking
finding** — something is wrong at the level of intent, and no scan result makes
it safe. The audit still runs its arms: the repo is observed-public, and a
blocking mismatch does not narrow the sweep.

**Delta from companion §6, recorded:** the companion also blocks on an *unset*
manifest visibility field. That rule was written for a draft in which the
manifest field *decided which repos got audited* — unset meant skipped, which
is the fail-open the spec names. Here the decision input is **observed**
visibility, so an unset field can no longer cause a skip, and it is recorded as
a **note** ("visibility intent not yet recorded — workspace-init's visibility
fields are pending"), not a block.

**But an unset field must not silently disable the intent axis**, which is the
hole that delta would otherwise open: workspace-init does not write those
fields yet (`start/references/posture-block.md` §9 — recorded as intent, written later), so
today the field is unset in every real project and the mismatch rule above
would never fire. **So the posture is the second intent source, and it is
always present:** read `oss get ".project.posture"`. A **`fully-private` or
unset posture over an observed-public repo is the same mismatch** and blocks
identically. **And a posture that is not one of the four values reads as
unset** — `posture_set` does not validate its argument, so a slip like
`private` must not silently re-enable the hole this rule closes. Without
this, a default-private project whose canonical was flipped public — the
commonest shape there is — passes every scan and closes `clean` with its
entire codebase public.

---

## 3. Step 1 — the tracked-file audit

**`PUBLIC_BOUNDARY.md` must exist at the audited repo's root — and be
tracked, and be a regular file.** An authored-but-unstaged file is read locally
while the public repo still ships no boundary policy, and its filename matches
no sensitive-path class, so §4 will not catch the omission either. Confirm it
appears in `git -C "<root>" ls-files`; present-but-untracked is the same
finding as absent, named as such. And confirm the tracked entry's mode in
`git -C "<root>" ls-files -s -- PUBLIC_BOUNDARY.md` is a regular file's —
`100644` or `100755`. A `120000` entry is a symlink, and a `160000` entry is
a gitlink: each passes `ls-files` and both of §9's `diff --quiet` checks
while committing a path or a commit pointer instead of the policy itself. A
gitlink is always a **finding naming its shape**, with the same
`start/references/posture-block.md` §6 authoring
remediation as an absent one — the target is never read as the policy. A
symlink is a finding of the same shape **when its target is not itself a
regular tracked file of this repo** — an out-of-repo or untracked target is
material the release does not ship, and the read would follow it; a symlink
whose target IS a regular tracked file in the same repo ships a working
policy at the root, and is a **note** naming the shape (the policy is
doubly-addressed), not a block. An observed-public
repo without the file is a **blocking finding** with the remediation named —
author it via `start`'s posture block (`start/references/posture-block.md`
§6) — never a silent skip. The v1 draft's defect was exactly a missing
artifact reading as a clean pass. **Where the document rules run at all is
role-scoped:** on a private canonical running §3 as hygiene notes, a missing
file is a hygiene finding, not a blocking one (§2's table). `start`'s posture
block routes `PUBLIC_BOUNDARY.md` to public-facing repo roots — every declared
product repo (`canonical` when a project names one that; any other, however
named), and any product-adjacent repo at its own root
(`start/references/posture-block.md` §6) — so on the
`ai_workspace`/`private_core` roles no policy file is ever expected, and its
absence is not
a finding on any arm: when those roles are observed public, §3's secrets scan
and §4's sweep run in full with blocking findings (§2's table), and the
tracked-rules and classification halves degrade on the absent policy input
exactly as §4 prescribes — named, never silent.

**Execute the machine-checkable rules block by reading it.** For each
`never-tracked:` pattern in the block, list tracked files
(`git -C "<root>" ls-files`) and match them against the pattern. **Where a
pattern and a path are arguably a match, they match** — an over-match is a
finding the user rejects in one sentence; an under-match is a leak. (Glob
dialects disagree about whether a leading `**/` matches zero segments and
whether a trailing `/**` matches the directory itself; that disagreement is not
worth resolving in prose, and resolving it the safe way costs nothing.)

**An empty or malformed block is INCONCLUSIVE, not clean.** Iterating zero
`never-tracked:` entries performs zero checks and reports nothing, which is
indistinguishable from a repo that passed them — so before matching, confirm
the block parses and still carries the standard secrets rules; a block that is
empty, unparseable, **carrying a directive this step cannot execute**, or
missing a rule the template ships is a recorded degradation with the same
weight as a failed scan.

Any tracked match is a finding: the file, the rule it violates, and — because
the file is already tracked — the note that removal alone does not untrack
history; a leaked *secret* must be rotated, and a leaked *document* assessed as
already disclosed.

`fixtures-must-be: synthetic` is not pattern-matchable. **It is asked wherever
this step reads a `PUBLIC_BOUNDARY.md` at all** — non-synthetic fixture data is
a privacy leak independent of any moat, by the same reasoning that makes even
a fully-private project author the file (`start/references/posture-block.md`
§6). That includes a private canonical running
hygiene notes; it excludes the `ai_workspace`/`private_core` roles, where no
`PUBLIC_BOUNDARY.md` is ever read on any arm — a named skip, not a silent one.
A fixture
directory that looks like real user data, prices, or prompts is a finding the
same way a tracked credential is.

**Secrets scan — external tool, honest degradation.** Run
`gitleaks detect --source "<root>" --no-banner --redact` and fold its findings
in. **`--redact`, always:** when the scan finds a real credential, unredacted
output quotes the matched secret, and folding that into the transcript or the
close summary duplicates the credential into the session log on exactly the
leak-handling path. Carry rule, path and location into the report — never the
matched text. **And read the repo's own `.gitleaks.toml` before trusting a
clean result** — gitleaks auto-loads it from the scanned source, so an
allowlist entry broad enough to cover ordinary source files, or the default
rules switched off, is a **finding in its own right**: the scan completed
against rules the repo itself weakened, and that is not a clean scan of the
release. **Only a completed scan counts as a scan.** Any other outcome —
binary absent, invocation rejected or deprecated away, run aborted, output
unreadable — is INCONCLUSIVE and recorded as a degradation naming what failed.
Inconclusive is not clean: a scan that errors produces no findings, which is
byte-identical to
a scan that found nothing. **And a run that completes but read nothing it was
pointed at is the same evidence shape:** rc 0 with `no leaks found` after
`~0 bytes` against a root that has files is a pass that read nothing —
INCONCLUSIVE (§2's filesystem-only arm is where this shape lives). The user may accept a degradation at triage like
any other finding; what is forbidden is the audit *silently* narrowing to
pattern rules because a tool did not run.

**Push protection — best-effort.** Read
`gh api --hostname "<host>" "repos/<owner>/<name>" --jq .security_and_analysis`
and report what the host enforces. Unknown or unreadable is a note, not a
finding — this is the host's rail, not ours, and the audit does not depend on
it.

### The history pass — the document rules over a corpus the index cannot show

`git ls-files` is an index: it shows the audited ref's tree and nothing else. A
private document committed a year ago and later deleted is public forever at its
blob URL, and a document sitting on another public branch never reaches the
audited ref at all. Neither is visible to the rules above.

**The secrets half of that gap belongs to the tool, not to this step.**
`gitleaks detect` as invoked above reads committed history — on the build
measured here (8.30.1) it reached commits outside the audited ref's ancestry as
well as inside it — but **this step neither promises that nor leans on it**:
what the scan covers is whatever a completed run covers, the coverage line
records what it reported, and a run that did not complete is INCONCLUSIVE
exactly as above. What has no history pass at all is everything
that reads **one ref**: the `never-tracked:` **document** rules, which only ever
match paths in an index, and **§5's semantic sweep**, which reads the audited
ref's tracked prose and each pinned submodule tree (§2) — so a moat-describing
README section committed and later
deleted, or living on a branch the release never merged, is as invisible as a
deleted planning tree.

**A review reaches only the objects the clone has.** A shallow or partial clone
makes "every commit" mean the local object graph and nothing more — a `--depth 1`
clone simply does not contain the deleted planning tree this pass exists to find,
and `--single-branch` does not contain the other branches — while the row it
writes would read current forever. **A pass reviewed from a corpus that is not
known to be complete is INCONCLUSIVE, not recordable**, and the block says what
was missing. How completeness is established is the reviewer's business and
varies by clone and host; what this step fixes is that an unestablished corpus
never becomes a recorded row. The same applies to §3's secrets scan on such a
clone: it walks the same object graph, so a completed run over an incomplete one
is a degradation, not a clean result.

**Both are closed by a recorded pass, not by a scan.** Reading every commit of
a repo's history for documents the rules ban and prose that describes a moat item
is a human-scale review, not something this step performs mid-close. **Every
review that writes a row or advances its commit covers both corpora** — §3's
`never-tracked:` rules and §5's S1/S2/S3 judgment — whether it is the first
full-history pass or a commit refresh over its range. A review that covered
only one of them is not a pass and gets no row. **The one exception is the
item-scoped review for unasked moat items** (moat currency, below): it owes §5's
judgment for those items only, adds their names to an existing row, and never
creates a row or moves its commit.
The record is a **History passes** row in
the private boundary inventory (`start/references/posture-block.md` §7): the
repo, the **commit it reviewed through**, the date, and the **moat items reviewed** —
written when the user confirms the review: full history the first time;
a commit refresh needs only the range since the recorded commit, and adds no
moat item: the row keeps only names it already carries that are still current.

**The pass is owed by every repo whose history could be public — read that off
the exposure, not off the arm.** Any repo on a full public arm owes one (§2's
`any` row, and the moat-holder roles observed public or undeterminable), and so
does any repo carrying a remote on record that reads **public or
undeterminable** — including a manifest `git_remote` the local enumeration never
listed, whose history sits on that host whatever the local arm says. A repo that **has** remotes on record and whose every one of them reads private
owes none: none of its history is public, and demanding one would block every dual-repo close on a full-history
review of the AI workspace. A repo with **no** remote on record takes whatever
arm §2 gives it and owes what that arm owes — on the `any` row, a pass: absence
of a remote narrows the exposure claim and never removes a check (§2). Name
every skip with the observed value that justified it, like all the others.
On an arm that runs but where no `PUBLIC_BOUNDARY.md` is ever routed — the
moat-holder roles (§2) — there are no document rules to run over history either:
record the pass **degraded on the never-expected policy input**, riding the
exposure finding that put the repo on that arm, never clean. **That degradation
is the repo's whole history treatment:** no absent-row, outrun-row or
unasked-item finding is raised beside it, because the review those findings ask
for cannot run on this arm.

**Commit currency.** A sensitive document
committed to another public branch or tag leaves the audited tip untouched, and
both the index rules and §5's sweep only ever read the release ref, so nothing
else here would see it — which is why the review the row records covers the repo
and not one branch.
**What the row covers is what the recorded commit reaches, and nothing else** —
and the check that it is still current is deliberately **one cheap local
comparison, not an enumeration**. Ask whether the ref this close audited is
reachable from the recorded commit:
`git -C "<root>" merge-base --is-ancestor "<audited ref>" "<recorded>"`. **If it
is not, commits have landed since and a further pass is owed — incremental is
enough**, the range between the two.

**Moat currency is independent of commit currency.** Compare the current moat
table's `Moat item` names with the row's `Moat items reviewed`: any current item
the row does not name is unasked. For those items, §5's judgment is owed over
the **full history and every ref, not an incremental range**, from a clone
known to be complete (the shallow-or-partial-clone rule above). That review is
the item-scoped exception above: §5's judgment for those items only, and the
`never-tracked:` rules are not owed again. When
the user confirms that review, add those items to the existing row's column; keep its commit unless the commit check
also owed a pass. Removing an item expires nothing; a renamed item reads as new
and only adds a stop. A row with no `Moat items reviewed` value predates the
column: every current moat item is unasked.
Use item names, not a file date or hash: the audit writes its own rows into
the inventory, moving its date and content on every close that records one, and a
filesystem-only AI workspace has no history to date a change against.

**That commit comparison covers one ref; the rest is §9's scope cut.** A row
passing both currency checks is **current for the ref this close audited,
never "current for the repo"** — a document committed to another public
branch, a tag, or a `refs/pull/N/head` *after* the recorded review leaves the
audited ref an ancestor of the recorded commit, so this check stays quiet and
**nothing here detects it**. That is not a scope note inside a passing check: it
is **§9's own row**, named by class in the report's scope line like every other
dimension this release does not ship, so a `clean` verdict never stands in for
it.

A row carrying only a release id and no commit predates this format and is
**treated as absent**.

**A plain non-repo root (§2) has no local history to review and no commit to
record** — the pass is a **named skip** for that role, exactly as §4, §5 and §6
are. **Except where a recorded `git_remote` reads public or undeterminable** (§2 —
the read that makes it a blocking exposure finding; a recorded remote reading
private is a note and changes nothing here): that repo's history sits on the
host whatever the directory is now, it is the blob-URL-forever class this
section opens with, and no local read can reach it. There the pass is a
**degradation riding that exposure finding**, never a clean skip — the same
treatment, and for the same reason, as the moat-holder arm above.

**An absent or outrun row, or an unasked moat item, is a finding** — except on a
repo whose pass is recorded as a degradation riding an exposure finding (the
moat-holder roles and the non-repo root above), which raises none. It reaches triage like any other, and
the two unblocks are §6's: **the fix** is the review itself — the user confirms
it was done and the row is written or amended for the review it asked for — and accepting the gap
instead is an **override**, taking the override's record like any other
acceptance. Nothing here is a third unblock.

**The rule keys on a recorded pass rather than on "the repo's first audit"**
because
**nothing tells this step whether it is the first**: no state field records a
boundary audit, and every release that closed before this step shipped closed
without one — so "is this the first?" is undeterminable exactly where it matters
most, on an adopted-forward project with a deleted `docs/planning/` tree in its
history. Absent, outrun or unasked is determinable, and it fails safe.

### The working-tree pass — uncommitted modifications to tracked files

The rules above match paths from `git ls-files`, the secrets scan reads committed
history, and §4's sweep enumerates the index's complement — so a secret pasted
into a tracked file and left uncommitted is read by none of them. (§5's semantic
pass does read the working tree's tracked prose, but it hunts moat descriptions,
not secrets.) **This pass runs at §9's pre-flight gate, before the reads above.**

**Start from whether there is anything to read** — `git -C "<root>" diff --quiet`
and `git -C "<root>" diff --cached --quiet`. Both succeeding means the repo has no
uncommitted tracked modifications and the pass is **ran, clean**; there is nothing
here to narrow and nothing to manufacture.

**The first answer is evidence only when nothing in the index suppresses it.**
A path marked `assume-unchanged` or `skip-worktree` makes `diff --quiet` succeed
over a working copy that differs — `git -C "<root>" ls-files -v` marks the first
lowercase (`h`) and the second `S`. **If any tracked path carries either flag,
that check proves nothing about the working tree**: run the reads below anyway
and name the flagged paths in the block. (`diff --cached --quiet` compares HEAD
against the index and neither flag touches it, so it stays evidence.) A clean
answer produced by a flag whose whole purpose is to stop git looking is the
fail-open this section exists to prevent. A plain non-repo root (§2) has no index
and no tracked set, so the pass is a **named skip** like this section's other index reads.

**When either fails, the read is the same on every arm — three inputs, because
no two of them see the same thing:**

- the **paths**, `git -C "<root>" diff --name-only` and
  `git -C "<root>" diff --cached --name-only`, matched against the
  `never-tracked:` rules the way tracked paths are matched above;
- the **working tree**, `gitleaks detect --source "<root>" --no-banner --redact
  --no-git`, for the secrets classes — `--no-git` is what reads the tree instead
  of the history, the same role §2 states it for on a filesystem-only root. It
  reads the whole tree — tracked, untracked **and gitignored alike**, minus
  whatever the tool's own config skips — which is both wider than this
  dimension's own question and as expensive as the tree is big: say so in the
  block rather than reporting a narrower read than the one that ran;
- the **staged patch**, because the scan above reads the working copy and the
  index can differ from it. A secret staged and then edited back out of the
  working tree is in **neither** that scan nor the committed history, and
  committing to clear this gate is exactly what would put it into history.
  **This read is not optional on any arm** — it is the only one that sees the
  index. **There is no redacting form of this read**, and that is not a gap to
  paper over: a patch is content, and reading content is what this pass is for,
  the same way §5 reads tracked prose. What §3's redaction rule forbids is
  carrying a matched secret **onward** — so the block names the rule, the path
  and the location, and the matched text never reaches the report or the close
  summary. The scan above redacts at its source because it can; here the
  discipline is at the report.

**What differs by arm is what happens after the read, not what is read:**

- **On every arm that reads the index or a tracked policy file**, §9's clean-tree
  gate halts on exactly this condition — **and the gate reads before it halts**,
  so the halt names what is in the diff rather than merely that a diff exists.
  Hits are classified by the arm exactly as this section's other hits are
  (blocking on a public arm, a hygiene note on the private canonical's). A dirty
  tree the operator commits and re-runs is read by the rules above at the new
  tip; a dirty tree carrying a violation is a finding the operator sees at the
  halt instead of a lap later.
- **On the secrets-scan-only arms** — the moat-holder roles observed private,
  which §9's gate does not reach because they make no release-tree claim — the
  same three reads **are** this pass, under the secrets-class carve-out §2
  carries: the history scan cannot see an uncommitted or staged edit, and these
  are the reads that can. No `PUBLIC_BOUNDARY.md` is routed to those roles (§2),
  so the document half is a named skip there, never a missing-file finding.

---

## 4. Step 2 — the leak-adjacent scan (untracked files, scan-first)

This step runs on every repo whose §2 row runs it — the observed-public,
undeterminable, and no-remote-on-record repos on the `any` row (including a
no-row repo on the canonical policy), and a public or undeterminable
`ai_workspace`/
`private_core` on its role row (the exposed-workspace arm) — and on no
other.

Enumerate **all** untracked files in the working tree —
`git -C "<root>" ls-files --others`, deliberately **without**
`--exclude-standard`, because gitignored files (`.env`, a private `SPEC.md`)
are exactly the class in play. One `git add -f`, one editor "save all", one
misfired `git commit -a` is the distance between an untracked sensitive file
and a tracked one.

**The enumeration is matched, not read.** Without `--exclude-standard` this
descends into ignored directories, so on a real project it is `node_modules/`
and `target/` by the hundred thousand. Pipe it through the pattern set and
report the hit paths plus a total count; the volume never belongs in the
transcript. **If the enumeration was truncated, filtered or interrupted for any
reason, that is a recorded degradation of the same class as a failed gitleaks
run** — INCONCLUSIVE, not clean. A truncated enumeration and a clean tree
produce the same report otherwise.

**Scan first, classify second.** Match every enumerated path against the
sensitive-pattern set: the repo's own `never-tracked:` patterns plus the
standard secrets classes (`.env*`, `*.pem`, `*.key`, `id_rsa*`, credential
files). Then classify each hit:

- Matches an entry in the `PUBLIC_BOUNDARY.md` **working-tree hygiene
  allowlist** (by pattern) → a **standing warning**: named in every audit
  report, never escalating, never disappearing. It is the recurring reminder
  that a sensitive file lives one `git add -f` from public.
- **Not** in the allowlist → a **new finding** for triage.

**When the policy input is absent, the classification half is degraded, not
clean.** On the canonical (and any canonical-policy repo), §3 has already
raised the missing `PUBLIC_BOUNDARY.md` as its own finding; on the
`ai_workspace`/`private_core` public arm no policy file is ever expected (§3),
and the degradation rides the exposure finding instead. Either way the sweep
still enumerates and still pattern-matches against the
standard secrets classes, but with no allowlist to classify against, "no
allowlisted hits" is not a classification this run produced — the coverage
line records the sweep's classification half as **degraded on the absent
policy input**, so a later reader cannot mistake a pattern-only pass for a
classified one. The judgment read below still runs; it never depended on the
allowlist.

The order is the point. Iterating the allowlist and checking whether its
entries exist would never catch a file the allowlist has not heard of — the
new `SPEC.md`-class file is precisely what this step exists to catch, and it
is only ever caught by scanning the tree first.

### Patterns are the floor, not the test

**A pattern set only catches files someone already thought to name.** A
strategy memo called `NOTES-STRATEGY.md`, a credential dump called `scratch.txt`
— neither matches a `never-tracked:` rule or a standard secrets class, and both
are exactly what an untracked sweep of a public working tree exists to find.

So after the pattern pass, **read the remaining untracked set for what the
files are**, the same direction of judgment as the tracked-file rules: a name
or a peek that reads like downstream strategy, planning, credentials, or
private-inventory material is a **finding**, and where it is arguable it is a
finding.

**Bounded, or it collides with the paragraph above.** The judgment read does
not open every file a working tree can hold. Dependency and build trees —
`node_modules/`, `target/`, `dist/`, `vendor/`, a package manager's cache —
collapse to one entry each, the directory's name read in place of its
contents; the pattern pass still matches paths inside them, which is what
keeps this compatible with "matched, not read". **Every other ignored or
untracked directory keeps its file names in the read.** A generically named
`cache/` or `notes/` is not a dependency tree, and collapsing it to its name
is exactly how a credentials file called `scratch.txt` comes to sit inside an
entry nobody opens — an ignored directory is collapsed only when it is
recognizably a dependency or build tree, and **where that is arguable it is
not one: enumerate it.** Read individual file names in full, and where a name
says nothing, open the file and read it — a stray working note is small, and
a file too large to read is itself the recorded degradation. **But if what it
holds is a credential or a secret, the finding is the file's PRESENCE, never
its content**: name the class, close the file, and quote nothing — the §3
redaction rule reaches this read too, and a transcript that acquires the
secret while hunting it is the leak happening twice.
(`--exclude-standard` is not the bound: the untracked-sweep fixture's
`NOTES-STRATEGY.md` is
gitignored, and excluding ignored files drops exactly the class this step
exists to catch.)

The `PUBLIC_BOUNDARY.md` "Never here" prose rules are the vocabulary for this
judgment: they already say no downstream strategy, no roadmap, no competitive
material, no non-synthetic fixtures. The pattern block is how those rules are
enforced mechanically; this read is how they are enforced at all.

---

## 5. Step 3 — the semantic pass (agent judgment)

The question no pattern can ask: **does anything tracked in the repo
*describe* a moat item, even without containing it?** It reads the audited ref
and no other — history and every other ref are the history pass's corpus (§3),
and, where the repo pins submodules, each pinned tree too (§2's descent),
which does not restate this pass's judgment and is not restated here. This step
runs on the
repos whose §2 row runs it — the `any`-row repos, observed-public,
undeterminable, or no-remote-on-record — and on no other: the moat-holder
roles never run it (they hold the inventory; every finding there would be
expected, which is indistinguishable from a real one — §2), and the
private-canonical hygiene arm skips it as a named skip (nothing is disclosed
from a private repo).

**Read the private boundary inventory first** (`posture-block.md` §7): the
AI-workspace artifact naming moat items, channels and seams, at its convention
`<ai-workspace>/docs/private-boundary-inventory.md`. Nothing indexes it — no
`well_known_paths` key, no `project-state.json` field, no verb writes it — so an
adopted project may hold an equivalent file under another name; this step's
subject is the file, not the address. The inventory is the
comparison set for everything below; **if it cannot be located, this step is
INCONCLUSIVE** — a finding with the `start`-time remediation pointer, not a
clean pass.

**Read its Accepted disclosures rows in the same pass** (§6 — release id, the
finding and the surface it covers, reason, date). Each row is a **standing
warning** this close restates, never a fresh block and never silence: a prior
acceptance is not an erasure. Match a row to a hit **only on the surface the
row pins** — the path plus its content hash and the commit read at, or for a
fileless surface the path-and-pattern or the tool-and-failure-mode. **Where it
is arguable whether a hit is the covered one, it is a fresh finding.** A row
that pins nothing checkable covers nothing: report it as a standing warning
whose scope cannot be verified, and treat the hit as fresh.

Then read the posture (`oss get ".project.posture"`):

- Posture implies protected value (`open-core`, `source-available`, a
  `fully-private` project with declared overlay seams) **or is
  unset/unrecognised** → the pass runs in full. A `fully-private` posture
  with an **explicitly empty** inventory takes the fully-open shape below:
  the moat question trivially clean, the "Never here" sweep still runs. An unset posture is read as
  moat-bearing (§2's fail-safe reads an undecided posture as private); a
  project that never completed its posture block is the population most
  likely to leak, and treating "not in the protected list" as "nothing to
  protect" fails open on exactly them.
- A protected-value posture over an **explicitly empty** inventory takes the
  same shape — the moat rows are simply absent from the comparison, and the
  "Never here" sweep still runs.
- `fully-open` with an explicitly empty inventory → the **moat question** is
  trivially clean; say so in one line and move on. **The sweep itself still
  runs.** An empty moat table means nothing is private, not that nothing is
  forbidden: `PUBLIC_BOUNDARY.md`'s "Never here" rules still ban downstream
  strategy, roadmaps, competitive material and non-synthetic fixtures, and a
  tracked memo violating them matches no `never-tracked:` path and passes
  gitleaks. So sweep the tracked doc set against those rules, with the moat
  rows simply absent from the comparison. (`fixtures-must-be: synthetic` is
  asked wherever §3 reads a `PUBLIC_BOUNDARY.md` — §3.)

### The three rules, first match wins

Sweep the tracked doc set — READMEs, docs, design comments, specs, and
fixture directories — against the inventory's moat rows. **If the sweep had
to be narrowed to fit, that narrowing is a recorded degradation**, the same
class as a failed gitleaks run.

- **S1 — the prose names a moat item's identity *and* enough mechanism that
  a reader could reconstruct or evaluate it → finding.** A README explaining
  the rationale and structure of an algorithm whose implementation is
  private-packaged; a roadmap section naming unreleased strategy; a comment
  reconstructing a private spec in miniature; a tracked fixture that looks
  like real user data, prices, or prompts.
- **S2 — it names the identity only, no mechanism → note.** "Ranking is
  handled by a proprietary component" discloses that the component exists,
  which the port already does.
- **S3 — neither → clean.**

**Where S1 and S2 are arguable, it is S1.** An over-raised finding costs the
user one sentence at triage; an unraised disclosure is permanent. This is
the same fail-closed direction `posture-block.md` §2 states for an ambiguous
posture, and it applies at the one step of this audit that is pure judgment.

Whatever the posture, the rows above exhaust the routing: a `fully-private`
posture over a **non-empty** inventory runs the pass in full (the moat is
enumerated — posture-block §4's C3 shape is not an exemption), and a
`fully-open` posture over a non-empty inventory is a contradiction the
`start` ceremony owes an answer for — recorded as a finding naming the
contradiction, never silently swept either way.

Describing is disclosing. The test is whether a competent reader of the
repo alone ends up knowing a thing the inventory says stays private — not
whether any private file is literally present, and not whether the author
intended it.

**Worked example (S1).** Posture `open-core`; the inventory's one row reads
"ranking/decay intelligence — channel `private-package` — the public repo
holds the ranking port, the private crate implements it". The public README
gains a "How ranking works" section containing no code, which walks the
decay curve's shape, names the three signals the ranker weighs and in which
order, and explains why recency is dampened after day 30. **S1**: identity
plus mechanism, reconstructable. "It contains no code" is not the test and
does not clear it.

---

## 6. Disposition — high-stakes, never auto

**No finding from this audit is ever auto-dispositioned to pass.** State the
contrast, because the nearest precedent points the other way: spine-close
disposition triage auto-applies spec-aligned recommendations and only
escalates load-bearing conflicts (`close/SKILL.md` §4). This step is the
deliberate opposite — every finding reaches the user, because "this
information is fine to publish" is a call only the owner can make, and it is
irreversible in exactly the way the default-private fail-safe exists for:
public → private is impossible once history is out.

**A rejection disputes the fact, not the risk.** The user may reject a finding
by contradicting what it asserts — the path is not tracked, the pattern does
not match, the file is not what the name suggests — and the report records the
fact that refutes it. **If the user concedes the fact and accepts the
exposure, that is an accepted-disclosure override, not a rejection**, and it
takes the override's record. Without that record the gate reduces to the user
saying "no": one word, no trace, and a report byte-identical to a close where
nothing was found. Say which of the two happened, plainly, at triage.

A finding the user affirms is **confirmed**, and confirmed findings **block the
close** — on every arm whose row runs §6. The arms that skip §6 never reach
this paragraph — every private row and the
plain non-repo policy; their
findings are recorded as the non-blocking notes or the degradations their
rows name — with the exceptions §2 carves: the recorded-`git_remote`
exposure finding blocks on its own wherever it fires, and a secrets-class
hit blocks on every arm. And a degradation on a
§6-skipping arm, while never a §6 confirmed finding, still governs the
verdict through §7: INCONCLUSIVE is never clean, so an unaccepted
degradation halts the close unless it is accepted on the record below. Two
unblocks, both real work:

- **Fix before close** — untrack and rotate, rewrite the disclosing doc,
  resynthesize the fixture, remove the stray file. **And a fix that changes
  the repository invalidates the gates
  that ran before it**: the cumulative walkthrough (step 2) exercised a
  product this fix has now altered, so re-run every gate whose inputs the fix
  touched — at minimum the cumulative walkthrough when the fix went anywhere
  the product reads (a resynthesized
  fixture, a deleted config, a rewritten doc a demo line opens). Recording the
  release closed on a walkthrough of the pre-fix tree certifies a product
  state that no longer exists, unless the holder cleared every changed path
  under `release-close.md` §8. A fix confined to the AI workspace, or to an
  untracked file nothing loads, touches no gate's inputs — but it still
  re-enters through the §1 re-close, because the halt was terminal and no
  gate is skipped by shortcut. Any fix may cite the prior walk only under
  `release-close.md` §8's conditions; a fix whose paths the holder cannot
  clear is re-walked. The audit itself
  always re-runs — a fix is verified by the audit that re-examines it.
- **Accepted-disclosure override** — the user records, in so many words, that
  this specific disclosure is accepted, with the reason. The close proceeds
  with the override named in the report, and the verdict says so (§7).

**Where the override is recorded — delta from companion §6, recorded:** the
companion routes overrides to `project-state.json`. No state verb carries such
a record and the freeze forbids adding one, so the record lands in the
**private boundary inventory** as an **Accepted disclosures** row — release id,
the finding *and the surface it covers*, reason, date — creating that section
if the inventory has none (`start/references/posture-block.md` §7). §5 reads
those rows every close, which is what makes the re-surfacing real rather than
asserted.

**Be honest about what this record is and is not.** `project-state.json` is
verb-written, atomically mutated, journalled and doctor-checked; a row in a
private markdown file is none of those, and deleting it is undetectable by
construction. What the inventory buys instead is *discoverability* — §5 re-reads
it every close — and the close summary carries the second copy. That trade is
the reason for the delta, not a claim to have matched the state field.

Two bounds on an override, because it is the one thing here that survives a
close:

- **It covers the exact surface recorded, and the row carries whatever makes
  "exact" checkable.** For a tracked file: the path plus a verifiable pin —
  the content hash (`git -C "<root>" hash-object -- "<path>"`) and the commit
  the audit read it at. For a surface that has no file — an untracked path, or
  an accepted degradation — whatever makes it re-identifiable instead: the path
  and its pattern, or the tool and the failure mode. Otherwise an override
  launders later growth of the thing it covered. **Any change to the surface is
  a fresh finding, and where it is arguable whether a hit is the covered one,
  it is fresh.**
- **It is not an erasure.** From the next close onward the item re-surfaces as
  a standing warning, never silently and never as a fresh block.

**The hygiene allowlist is not editable mid-audit.** An audit that edits its
own inputs passes itself. An allowlist entry added in response to a finding is
a `start/references/posture-block.md` edit made deliberately outside the audit — the halt
records the triage, the entry is authored at `start`-time, and the re-close
sees the file as the standing warning it now is.

**Allowlisting is not a cheaper override.** Adding a pattern to the hygiene
allowlist in response to a finding reclassifies it to a standing warning and
reaches the same place as an override, one ceremony later, with no record. So:
**an allowlist entry added in response to a finding is recorded as an accepted
disclosure like any other.** The friction is the point, not the ceremony
boundary.

Standing warnings — hygiene-allowlisted files, prior accepted disclosures, and
**previously accepted** degradations — are recapped at the end of
every audit report. They are the audit's memory, and pruning them is a
posture-block edit made deliberately at `start`-time ceremonies, not something
an audit does to quiet its own output.

**A degradation from *this* run is a finding, not a standing warning.** The
distinction is the whole of it: a gitleaks run that failed today is an
incomplete scan of the release being closed, and §3 sends it to triage. Only
once the user has accepted it — on the override record above — does it become
memory. Filing this run's failure straight into the recap
would let a current, unaccepted, incomplete secrets scan sit under a heading
described as non-escalating, and the release would close clean without anyone
deciding anything.

---

## 7. The report

One block per repo in the set — role, **the audited ref** (§9) and **the
commit each tracked submodule is pinned at** (§2), **the coverage
line** (below), gate outcome (observed visibility per
remote, manifest and posture agreement, what ran and what was skipped),
tracked-file hits, semantic findings (S1 findings and S2 notes — §5),
untracked hits split new-vs-standing, history and working-tree findings (§3),
degradations — each
finding carrying repo, class,
the path or pattern, why it is a finding, and its remediation. Then the triage
conversation, finding by finding. Then the verdict, one of exactly three:
**clean**, **blocked** (naming each confirmed finding), or **proceeding with
overrides** — every accepted disclosure named with the surface it covers and
its reason, and the inventory row it was written to (§6). A close with an
override is not a clean close and never reports as one: the third verdict
exists precisely so that "we accepted something" cannot hide inside `clean`.

### The coverage line, and why it is not optional

Every report block opens with a **coverage read-out**: each of the six
checks — tracked rules, secrets scan, untracked sweep, semantic pass, history
pass, working-tree pass — marked
**ran**,
**skipped** with the observed value that justified it, or **INCONCLUSIVE**
with what failed. Nothing else in the block is trusted until that line
accounts for all six.

**INCONCLUSIVE has a narrow meaning, and widening it breaks the gate the other
way.** A check is **ran** when it completed against the inputs this project
actually has — and a check that ran and found nothing is *ran, clean*, never
"ran, but I could not confirm X". INCONCLUSIVE is for a check that **could not
complete**: a tool that did not run, a tool that completed but read nothing it
was pointed at, an artifact that does not exist, an enumeration that
truncated, a rule block that parsed to nothing, a corpus the check was
required to cover and could not read — an unaudited submodule's pinned tree
(§2). It is **not**
for an input you would have liked in more detail, not for a hypothetical, and
not for a condition the procedure never asked about. Do not enumerate gaps the
procedure does not require: a report padded with speculative caveats is a gate
nobody reads, and an audit that marks a complete check INCONCLUSIVE spends the
word that is supposed to stop a release.

**This inverts the step's default, and that is the point.** Every fail-open
this audit family has shipped was the same shape: an arm nobody wrote a rule
for reported clean, because the report only ever said what was *found*, never
what was *looked at*. A verdict is assembled from the coverage line, so a
check with no recorded outcome is INCONCLUSIVE by construction rather than by
someone having anticipated it — and **INCONCLUSIVE is never clean**, at any
scale, for any reason. A tool that changes its flags, a boundary file that
lost a rule: each surfaces as an unaccounted check rather than as silence.

**And the report states its scope.** One line — the repo set with each repo's
observed visibility and arm, the six shipped checks, the not-shipped
dimensions named by class (§9) — so
a `clean` verdict is never read as more coverage than this release ships.
Every skip is named in the report with the observed value that justified it.

**The report's home is the close summary** (`close/SKILL.md` §10) — it is the
ceremony's final message, not a file. The two durable records this audit writes
are both rows in the private boundary inventory: the **Accepted disclosures**
row an override adds (§6), and the **History passes** row a **confirmed history
review** writes (§3 — a rejected history finding writes no row at all, and an accepted one
writes the Accepted disclosures row above rather than a second History passes
row) — nothing else here outlives the summary.

If any part of a finding must be written where the public can read it (a
release note, a public issue), it is described by **pattern and class only**
— the `PUBLIC_BOUNDARY.md` discipline applies to the audit's own output:
naming a moat item in a public artifact is itself the leak.

---

## 8. Anti-patterns

- **Trusting the manifest over observation.** A repo the manifest calls
  private and `gh` reports public gets audited as public and raises the
  mismatch as blocking (§2).
- **Reading only `origin`.** Enumerate every remote and gate on the most
  public (§2).
- **Letting an unset manifest field disable the intent axis.** The posture is
  the second source and is always present (§2).
- **Reading a non-enum posture as carrying intent.** A posture that is not
  one of the four values reads as unset — `posture_set` does not validate its
  argument (§2).
- **Skipping a scan because the repo has no remote.** The remote decides
  exposure, not whether to look (§2).
- **Hard-coding the role list.** Every manifest repo object gets a row — a
  public `tooling_repo` skipped because it is not one of three names is the
  failure (§2).
- **Skipping the secrets scan on an arm whose visibility read failed.** The
  scan and the visibility finding are independent; no arm of the table skips
  the scan (§2).
- **Running git commands against a plain non-repo root.** The
  filesystem-only policy exists because no index, remotes, or history exist
  there — `--no-git` is the scan, and a zero-byte clean read against a root
  that has files is INCONCLUSIVE (§2).
- **Reading a superproject's clean checks as evidence about a pinned tree.**
  The index carries one gitlink, the git-mode scan reads a history in which the
  submodule is that pointer, and an uninitialized submodule is an empty
  directory every read reports clean over — that silence is INCONCLUSIVE, not a
  clean submodule (§2).
- **Reading a symlinked policy file's unshipped target.** The committed blob
  is a path, not a policy — the shape is the finding wherever the target is
  not a regular tracked file of the same repo (§3).
- **Reading a policy-absent sweep's pattern pass as a classified one.** No
  allowlist, no classification — the half is degraded (§4).
- **Reading an S1-shaped disclosure as an S2 note.** Where the mechanism is
  arguable, it is S1 — describing is disclosing, and "it contains no code"
  is not the test (§5).
- **Skipping the semantic pass on a fully-open posture.** An empty moat
  table cleans the moat question; the "Never here" rules sweep still
  runs (§5).
- **Treating an unlocatable inventory as a clean semantic pass.**
  INCONCLUSIVE, with the `start`-time remediation pointer (§5).
- **Reading "gitleaks did not complete" as clean.** Only a completed scan is
  a scan (§3).
- **Treating an empty machine-checkable block as a pass** — zero rules run is
  zero checks, not zero violations (§3).
- **Reading an untracked `PUBLIC_BOUNDARY.md` as present** (§3).
- **Iterating the allowlist instead of scanning the tree.** Scan-first is the
  only order that catches a file the allowlist has not heard of (§4).
- **Reading a truncated enumeration as a clean one** (§4).
- **Classifying the untracked set by pattern alone**, which passes any
  sensitive file nobody thought to name (§4).
- **Collapsing an ignored directory that is not a dependency or build tree**,
  which hides whatever sits inside a generically named `cache/` or `notes/`
  (§4).
- **Auto-dispositioning a finding.** The spine-close triage rule does not
  reach this step; every finding is the user's (§6).
- **Proceeding on an acceptance without writing its row** — an override with
  no inventory record is the user saying "no" with no trace (§6).
- **Reporting an overridden close as `clean`.** The third verdict exists so
  that an acceptance cannot hide inside a clean verdict (§7).
- **Writing an override row that does not pin its surface** — no hash, no
  commit, no pattern — so later growth of the covered thing is laundered by
  the old acceptance (§6).
- **Editing the hygiene allowlist mid-audit to reclassify a hit.** An audit
  that edits its own inputs passes itself (§6).
- **Filing this run's failed scan as a standing warning.** Only an accepted
  degradation is memory, and accepting one ends this close halted (§6).
- **Auditing whatever happens to be checked out on the canonical, or a dirty
  checkout.** Resolve the release's ref per §9, verify HEAD matches it with no
  staged or unstaged tracked changes, and name it. (The role repos' audited
  ref IS their checked-out branch, named as such — §9; the anti-pattern is
  auditing an unresolveable ref, not the role rule.)
- **Reading a `History passes` row as permanent.** Its commit can be outrun,
  and an unasked moat item owes a review (§3).
- **Expiring a history pass against the audited ref alone**, when another
  public branch or tag can carry what the release ref never saw (§3).
- **Reading the secrets scan as covering the document rules across history.**
  It covers secrets; the `never-tracked:` document rules only ever match an
  index (§3).
- **Halting on a dirty tree without reading it.** The gate names what is in the
  diff, not merely that a diff exists (§3's working-tree pass, §9's gate).
- **Naming a moat item in any public-facing record of a finding.** Patterns
  and classes only (§7).
- **Reporting a verdict without a coverage line**, or reading an unaccounted
  check as clean rather than INCONCLUSIVE (§7).
- **Running the state writes after a halt here** (§1, `release-close.md` §9).

---

## 9. What this audit does not cover — the not-shipped table

Stated as a table, because the sibling ceremony's rule is that a step which
silently does nothing is indistinguishable from a missing one
(`release-close.md` §1) — and a scope cut is the same shape of hazard.

| Dimension | Status |
|---|---|
| **Public refs other than the audited one, after a recorded history pass** | **not shipped.** §3's recorded review covers the repo at the commit it reviewed through, and the commit-currency check compares one ref — the one this close audits. A document committed to an unmerged branch, a tag, or a `refs/pull/N/head` after that commit leaves the audited ref untouched and raises nothing. The per-tip comparison that would catch it was tried and cut: no fetch brings PR-ref objects down by default (an explicit refspec does, which is one more thing to get right per repo) and fork or squash-merged heads are ancestors of nothing, so the check would read INCONCLUSIVE on every repo with a pull request in it, and a gate that can never read current is not a gate. The report names the refs it did not compare; the row leaves this table when a pass persists a reviewed tip **per ref** rather than one commit |
| **Every submodule pin except the one the audited ref carries, and a non-manifest pinned submodule repository's own history and other refs** | **not shipped.** §2's descent reads the tree at **the pin the audited ref carries**, and no other. Two gaps follow and both are named here rather than left to read as executed. **Every other pin:** a pin the superproject has since advanced past, and a pin still live on another public ref — a branch or tag that carries a different gitlink today — publish trees nothing here reaches. The superproject's history pass sees gitlink values and does not descend; a manifest-listed submodule's own history pass runs under **that repository's** policy, which need not carry the rule the superproject forbids the path by; and the refs row above covers changes made to other refs *after* a recorded pass, not a pin that has sat on one since before it. So a path forbidden only by the superproject stays covered by neither, whether the pin carrying it was superseded or is current on a ref this close does not audit. **Non-manifest histories:** a document committed to a pinned repository the manifest does not name and later deleted, or living on another of its refs, is that repository's own exposure. Reading every pin the repository has published, on every live ref, under the publishing superproject's policy is what would close the first gap; it is not shipped, and the report names the pinned repositories and refs it did not read |
| **Everything about the project that is not a git repo** | permanent scope, not a cut: issues, wiki, releases, Pages, Actions artifacts, published packages |

Each row is named by class in the report's scope line (§7), so a `clean`
verdict never implies more coverage than this table ships. The rows leave this
table one PR at a time, each with its own fixtures — never by quiet expansion
inside this file.

**Say which ref you audited, and audit the release's ref.** Everything above
reads the *ambient* checkout, and by the time a release closes — especially a
close resumed in a later session, or one where the operator moved HEAD after
the last spine close — that may not be the branch the release integrated into.
A clean old branch passing while the release branch carries a tracked
violation is the failure.

**Any declared repo that determines as a plain non-repo root (§2) is a halt-and-name
of its own:** the ceremony's product repository has no index, no history and
no ref to resolve — no gate in this section can run, and the close stops for
the owner to restore the repository. Nothing else in this tail applies to it.

Resolve it before §3, the way the ceremony already resolves it —
**`base_branch` is not in state**, so do not reach for `oss get`:

- Consult the **`base_branch` the closing spines' handoffs recorded** under
  `## 2. Spine context` (`spine-close.md` §3 resolves it the same way —
  handoff-primary, with `SPINE.md`'s spine-context section as the cross-check,
  halting on disagreement), with
  the manifest's `<repo>.default_branch` as a cross-check (`canonical.default_branch`
  when the repo is named that). Consult only the
  release's `closed` spines: an **`abandoned`** spine may never have run
  `/plan-spine` and so never wrote a `SPINE.md` — it contributes nothing, and
  its silence is not an error. If the recorded bases disagree with each other,
  halt and name them rather than picking one; if they agree with each other
  but contradict the manifest's `default_branch`, halt and name both readings
  — that is drift or a typo, and the audit does not pick silently; if no
  closing spine records a base at all, audit the manifest's `default_branch`
  and name that source in the report.

**A repo none of the closing spines dispatched a work item into resolves its
audited ref differently.** No spine records a base branch for a repo it never
hosted work on — `ai_workspace` always (it never executes), and any other
declared repo (a `private_core`, a `tooling_repo`, or a second product repo)
whenever no closing spine dispatched a work item into it: audit each such repo's
checked-out branch and name it as such in its block. **The predicate is
DISPATCHED, not targeted.** An `abandoned` item was withdrawn before any
dispatch (`plan-spine/references/decomposition.md` §1), and `target_repo` is set
at mint time — so a repo only an abandoned item names takes THIS arm, never the
one below. Reading `target_repo` as a dispatch is what sends such a repo down
the handoff-derived path, where no handoff exists and no base was ever recorded,
and it halts the audit on that. A repo that DID host one
of the closing spines' items resolves the same way `canonical` does above —
from that spine's handoffs, never guessed, whatever the repo is named. A
plain non-repo root (determined per §2, whatever the field
says) has no ref at all — its block says it
was scanned from the working tree, which is the whole of its policy (§2).

Then verify the checkout IS that ref, cleanly, before §3 — everything this
audit reads is ambient: `git ls-files` reads the index, the rules are read
from the working-tree file, and the sweep enumerates the index's complement.
**On any repo whose audited ref came from a spine's handoffs — canonical
always when it hosted one, and any other declared repo the closing spines
dispatched work into — halt unless
`git -C "<root>" rev-parse "$audited_ref"` equals
`git -C "<root>" rev-parse HEAD`** — compare the two RESOLVED object ids,
never a branch name against a commit id, which are never equal — **and on
every repo whose arm reads the index or a tracked policy file — a repo on the
default (canonical) policy row always; another repo whenever its arm runs
§3's tracked rules or §4's sweep,
in full or as hygiene notes — both
`git -C "<root>" diff --quiet` and `git -C "<root>" diff --cached --quiet`
must succeed** — a staged deletion or an unstaged edit to `PUBLIC_BOUNDARY.md`
can make the committed release tree differ from everything this audit just
read, and a clean verdict over a tree the release does not ship is the
failure. **And the quiet answers license this gate only under §3's caveat:** a
tracked path marked `assume-unchanged` or `skip-worktree` makes
`diff --quiet` succeed over a working copy that differs, so where either flag
is present that check does not clear the tree here either. **The gate reads
before it halts:** §3's working-tree pass states what to read out of the diff,
how a hit is classified, and when the quiet checks are evidence; this gate does
not restate any of it. A repo on a
secrets-scan-only arm makes no release-tree claim — on a git repo, gitleaks
reads committed history and neither the index nor the working tree, so an
unstaged edit is invisible to the scan and no divergence claim exists; its
block names what was read; the diff gate does not reach it. (Untracked files are §4's input by
design and do not halt this check anywhere.) **And name the audited ref in
every repo's block.** An audit that cannot say what it read is not evidence.
