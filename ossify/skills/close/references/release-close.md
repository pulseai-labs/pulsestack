# Release close — the outer layer

Depth for SKILL.md §6 (spec §6.2, plus the two §6.1 contracts that only become
enforceable at a release boundary). Eight steps in **binding order**: the
walkthrough measures the set the amendments produced, the blocking findings are
read against a product the walkthrough has already exercised, the retro
aggregates artifacts the spine closes wrote, and the boundary audit is the last
refusal before anything is recorded.

This layer is reached as `/close <release-id>` — `r1`, three characters, no dots
(SKILL.md §2). Nothing routes here automatically: a spine close ends at its own
step 11 and never escalates.

---

## 1. What this release ships, and what it deliberately does not

Spec §6.2 lists seven steps; the companion boundary spec appends an eighth.
**This ceremony runs steps 1-4, the two blocking §6.1 findings, the release
tag (§9), and the companion's boundary audit. Two of the spec's steps are not
here**, and each is named rather than left to read as executed:

| Spec §6.2 step | Status here |
|---|---|
| 1. All spines closed | **built** — §2 |
| 2. Full cumulative walkthrough | **built** — §3 |
| 3. Release retrospective | **built** — §6 |
| 4. Feature-map re-groom + next-release sketch | **built** — §7 |
| **5. Docs increment (spec §8)** | **not shipped.** The trigger table lives in spec §8 and has no executable surface yet |
| **6. Handoff cleanup for the closed release** | **not shipped.** `/ossify:handoff` authors session handoffs as a standalone utility, but it has no retention policy by design — handoffs accumulate and the user prunes — so there is nothing for a close to clean up; the same non-wiring `spine-close.md` §9 records for the spine boundary |
| **7. Release tag / PR gate** | **shipped as the tag half (#339).** The tier question is settled: the PR gate lives at the **spine** boundary — spine close lands each hosting repo by PR through `/ossify:work-pr` (`spine-close.md` §3), work-item merges stay local — so a release needs no merge of its own; this ceremony tags the merged `main` (§9). A release branch would add a third merge with no reviewer, and does not exist |
| **8. Boundary audit (companion §6)** | **built — core scope over the full repo set** — §8, full depth in `references/boundary-audit.md`. Re-derived under the skill-first freeze: prose driving `git`/`gh`/`gitleaks` plus agent judgment, **every manifest repo object audited with per-role arms, observed-visibility gated**, fail-closed — the tracked-file audit, the secrets scan, the scan-first untracked sweep, the semantic pass over tracked prose, the recorded history pass and the working-tree pass over uncommitted tracked modifications, each tracked submodule's pinned tree audited by that same arm. Confirmed findings block the close; the one other unblock is a recorded accepted-disclosure override. The dimensions this scope still omits — divergence on public refs other than the audited one after a recorded history pass, and every submodule pin but the audited ref's together with a non-manifest pinned submodule repository's own history — are named in that file's own not-shipped table |

A missing step and a step that silently does nothing are indistinguishable to
every later reader, which is why they are a table rather than an omission.

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

**Every step here is per-repo except the boundary audit and the release
ladder.** Spines and work items carry a `target_repo`, and Tasks 8/9 (#272/#310)
made the spine and work-item close layers merge each item's work into that
item's own repo (`work-item-close.md` §4, `spine-close.md` §3) — so the
walkthrough (§3) and all three blocking gates (§4/§5/§5b) below are already repo-general
the moment those merges are: they read state `oss demo_user_lines`,
`oss expired_fakes`, `oss expired_quarantines`, `oss expired_deferrals` write and select from, never a
checkout, so a spine that landed across three repos contributes to them exactly
as one confined to canonical would — nothing in this file has to loop over
repos for that to be true, because the state it reads already spans however
many are declared. The companion design gives a release close a pin/publish
step before the walkthrough for open-core postures, and one PR per touched repo
at the gate; neither is built, and both attach to steps this file does not
ship. The one step that does read checkouts, the boundary audit, reads **every
repo the resolved topology declares** — `.ossify/topology.json` first, a
translated `.workspace/pairing.json` as the fallback, which is the same order
`references/boundary-audit.md` §2 walks — each with per-role arms (git
repos via `git -C`, never a worktree; a plain non-repo root via its
filesystem-only policy, determined per the audit's own §2 whatever the
manifest field says) — that step alone iterates the repo set explicitly,
because it audits the manifest's roles rather than a spine's items; the
audit's own §9 names what remains outside its shipped scope. **The release
ladder has no repo dimension at all**: Skeleton (Release 0) → MVP → v1 → vN
(`plan-release/references/rolling-wave.md` §4) is one maturity position for the
whole project, and step 6's `next_sketch` writes it there once, regardless of
how many repos the closing release actually touched.

---

## 2. Step 1 — every spine closed, or refuse and name the offender

`$rel` is the id `/close` was invoked with, carried from SKILL.md §2's routing.

```bash
open_spines="$(oss get "[.spines[] | select(.release==\"$rel\" and .status != \"closed\" and .status != \"abandoned\") | \"\(.id) (\(.status))\"] | join(\", \")")"
abandoned="$(oss get "[.spines[] | select(.release==\"$rel\" and .status == \"abandoned\") | .id] | join(\", \")")"

[ -z "$open_spines" ] \
  || { echo "close: $rel has spines that are not closed: $open_spines - halt"; exit 1; }
[ -z "$abandoned" ] \
  || echo "close: $rel contains abandoned spines: $abandoned - confirm each abandonment was deliberate before continuing"
```

**The abandoned line is `[ -z … ] || echo`, never `[ -n … ] && echo`.** An
`&&` list whose test is false returns **1**, and this is the block's last
command, so under `set -euo pipefail` the clean case — no abandoned spines —
would abort the ceremony at the gate it just passed. The `|| echo` form returns 0
on both arms.

**Test the output, never the rc.** `oss get` is `jq -r` without `-e`: a `select`
matching nothing exits **0** with an empty string, so `oss get … || halt` never
fires and a release with three open spines closes clean. This is the same trap
`spine-close.md` §2 documents for the work-item gate, one scope out.

**The status is printed alongside the id** because `planned` and `active` are
different problems: a `planned` spine was selected into the release and never
started, an `active` one is mid-flight with a worktree still on disk.

### `abandoned` does not satisfy the gate, and does not hard-halt either

The spine enum is `planned|active|closed|abandoned`, and **`abandoned` is not
`closed`**. Reading it as closed would let a release close over work someone
quietly gave up on. Halting on it forever is equally wrong: an abandoned spine by
definition never reaches a close ceremony, so a hard refusal makes the release
uncloseable.

So it is a **third arm**: surfaced by name, with an explicit confirmation from
the user that each abandonment was deliberate and recorded. **Do not
auto-confirm it** — this is the one arm of the one gate in this layer that is
not a mechanical fact, and the user is the authority (SKILL.md §8).

Nothing is dropped by that leniency: an abandoned spine's demo lines and fakes
are still live records, and steps 3 and 4 below pick them up on their own terms.

---

## 3. Step 2 — the full cumulative walkthrough

```bash
oss demo_user_lines            # NO argument - every active user: line, all spines
```

**The no-argument call is the whole difference from spine close.** With a spine
argument the verb filters to `source_spine == <spine>`; without one it returns
the entire active `user:` set (`cumulative-demo.md` §1). Passing a spine here
turns the release gate back into a spine gate and the release stops being the
first place anyone notices a regression in an older journey.

**Against the amended set, and the amendments are already applied.** `supersede`
and `retire` are planning verbs that leave the line live until a spine close runs
`oss ledger_apply_pending` (`spine-close.md` §4). Step 1 above has just proven
every spine closed, so every planned amendment in this release has been applied
by the spine that planned it. **This layer never applies amendments itself** — an
apply here would be applying a spine's intent after that spine closed, and
`oss demo_user_lines` already returns only `status == "active"` lines, so a
superseded line is gone from the walk without any action here.

The `auto:` half runs the same way it does at spine close — `oss demo_run`, every
accumulated line, halt on the first failure. Everything in `cumulative-demo.md`
§2-§5 applies unchanged: never edit a line to make it pass, a `user:` mismatch is
a failure and not a note, the wall-clock budget is surfaced and never silently
pruned.

### Grouping by feature is yours to derive, not a field to sort on

Spec §6.1 groups the release walkthrough by feature. **Demo-ledger lines carry no
feature field** — `oss ledger_add_user` writes
`{type,text,outcome,source_spine,status,status_reason,status_by,at}` and nothing
else (the payload `oss_ledger_add_user` builds in `lib/ledger.sh`). There is no
`.feature` to `group_by`, and a block of
prose implying one would send every reader looking for a lookup that does not
exist.

The grouping is **the agent's, derived**: read the feature map with
`oss feature_list`, read each line's `source_spine`, and map spine → feature
through the map's own entries. Say out loud which grouping you used before you
start the walk, so the human can correct it — a wrong grouping changes the order
of the walk, not its coverage, and every line is walked either way.

Once the walk exceeds the user's tolerance, spec §6.1 allows unchanged features
to rotate through spot-checks. **That is an explicit recorded choice, and the
default is the full walk.** This layer does not make it silently.

**Where "recorded" lands.** There is no verb and no state field for it, so the
record is the **release retrospective's walkthrough section** (§6): name which
feature groups were spot-checked rather than fully walked, and the tolerance that
drove it. Write it at the moment of the decision, not reconstructed at §6 — by
then the walk is over and "which ones did we skip" is a memory test.

Unrecorded, the rotation is indistinguishable from a full walk to every later
reader, and the next release close has no way to rotate *different* features —
which is the entire point of a rotation.

---

## 4. Step 3 — the fake-expiry blocking finding

The gate, its rc contract, both of its arms and the two ways to unblock it are
in **`references/fake-expiry.md`**. The branch this step runs — the shipped
copy (`fake-expiry.md` §2), executed from here:

```bash
ef=0; fakes_due="$(oss expired_fakes "$rel")" || ef=$?
case "$ef" in
  0) echo "fake expiry: clean" ;;
  1) printf '%s\n' "$fakes_due"
     echo "close: $rel has fakes at or past their expiry - replace or explicitly renew each - halt"; exit 1 ;;
  *) echo "close: expired_fakes could not run (rc $ef) - INCONCLUSIVE, not clean - halt"; exit 1 ;;
esac
```

**rc 0 is CLEAN here, and rc 0 is a HIT in `oss touch_check`** — three arms
always, with rc 2 halting rather than degrading to clean. The polarity trap, and
what copying the touch-check branch shape passes: `fake-expiry.md` §2.

---

## 5. Step 4 — the outstanding-quarantine blocking finding

Spec §6.1 makes a quarantine a parking ticket: a quarantined line **must be fixed
or retired by the next release close**. So every line quarantined in a release
**strictly earlier** than this one is a blocking finding.

```bash
eq=0; quarantines_due="$(oss expired_quarantines "$rel")" || eq=$?
case "$eq" in
  0) echo "quarantines: clean" ;;
  1) printf '%s\n' "$quarantines_due"
     echo "close: $rel has quarantines owed from an earlier release - fix or retire each - halt"; exit 1 ;;
  *) echo "close: expired_quarantines could not run (rc $eq) - INCONCLUSIVE, not clean - halt"; exit 1 ;;
esac
```

Same rc contract as the fake gate: **0 = clean, 1 = blocking, 2 =
could-not-check**, one TSV line per finding (`<line-id>`, the release it was
quarantined in, the reason).

**Strictly earlier — `<`, not `<=`.** A line quarantined *during this release*
is a fresh ticket that comes due at the **next** close. Folding it in would make
a close unable to quarantine anything without immediately blocking on it.

**Numerically, for the same reason the fake gate is numeric.** jq compares
strings lexicographically, and `"r2" <= "r10"` is **false**, so a string
comparison silently stops blocking at the tenth release — the release by which a
project has the most owed tickets.

**The two unblocks are fix or retire**, and both are real work:

```bash
oss ledger_retire "<line-id>" "<by-spine>" "<why it is no longer owed>"
```

`retire` is a *planning* verb: it records intent and the line stays live until a
spine close applies it (`spine-close.md` §4). At a release close there is no
spine left to apply it, so retiring here is a **decision recorded for the next
spine**, not an immediate removal — say so when you take that route rather than
reporting the ticket cleared. Fixing the line is the other route: the line goes
back to `active` by the fix landing in a spine, not by an edit here.

---

## 5b. Step 4b — deferrals and stray planned lines

A deferral is a `user:` line an operator could not walk, recorded with their words
and the release it is **due at** (`cumulative-demo.md` §4a). This close collects it,
and the same step catches the one other way a `planned` line can be stranded:

```bash
ed=0; deferrals_due="$(oss expired_deferrals "$rel")" || ed=$?
case "$ed" in
  0) [ -n "$deferrals_due" ] && printf '%s\n' "$deferrals_due"; echo "deferrals: clean" ;;
  1) printf '%s\n' "$deferrals_due"
     echo "close: $rel has deferred user lines due - walk, re-defer or retire each - halt"; exit 1 ;;
  *) echo "close: expired_deferrals could not run (rc $ed) - INCONCLUSIVE, not clean - halt"; exit 1 ;;
esac
stray="$(oss get '[.spines[] | select(.status=="closed") | .id] as $c | [.demo_ledger[] | select(.status=="planned" and (.source_spine as $s | $c | index($s)))] | map(.id) | join(" ")')"
[ -z "$stray" ] || { echo "close: planned lines of closed spines: $stray - spine close step 3 should have activated them - halt"; exit 1; }
orphan="$(oss get '[.spines[] | select(.status=="abandoned") | .id] as $a | [.demo_ledger[] | select(.status=="planned" and (.source_spine as $s | $a | index($s)))] | map(.id) | join(" ")')"
[ -z "$orphan" ] || echo "close: planned lines of abandoned spines: $orphan - surface each for retire (spine-close.md §4); that spine will never activate them"
```

Same rc contract as §5's gate — 0 = clean, 1 = blocking, 2 = could-not-check, one TSV
line per finding — except that a deferral row carries a fifth column, `source_spine`: the
line's owning spine, which `oss ledger_defer` needs for a re-defer (this close has no spine
of its own to name; columns 1–4 keep their meaning). The other two deliberate differences: a deferral names the release
it is **due at**, so the cut is `<=` where quarantine's is `<`, and a deferral with no
anchor blocks as `no-release-anchor`.

**Each due line gets one of three unblocks, and all three are real work:**

- **Walk it now.** `oss ledger_activate <line-id>`, then walk it with the operator,
  or yourself under a standing order in the project's memory bank or `AGENTS.md` that gives you the demo walk (`cumulative-demo.md` §3), like any §3 line. A failed walk halts. Under that order the release close ends by asking the operator for one nod over the walk read-out; that nod is the release close's only operator ask on the walk.
- **Defer it again.** New operator words and a later release — the call
  `cumulative-demo.md` §4a names, with the operator present; its `<spine>` is the row's column 5.
- **Retire it.** `oss ledger_retire <line-id> <by-spine> "<why>"` needs a spine that has
  **not** closed — one of the next release — because retire is a planning verb whose
  application is a spine close (`spine-close.md` §4). Until that close runs, this gate
  reports the row as `amendment pending` and does not block. **A retire owned by a
  closed spine is never applied**, so that line keeps blocking: with no open spine to
  own it, walk the line or defer it again. Say it as recorded, not as cleared, the
  same as §5.

**A `planned` line whose spine is `closed` is a halt.** Spine close step 3 activates a
spine's own planned lines before its demo (`spine-close.md` §4), so one that survives
into a closed spine is a close that skipped it, and nothing will ever run it. A planned
line whose spine is **`abandoned`** is surfaced by name for retire: that spine is not
coming back to activate it.

A line quarantined with **no release anchor** blocks too, marked
`no-release-anchor`. §6.1's ticket expires against a release, so a ticket
carrying none can never come due — and `oss ledger_quarantine`'s release argument
is optional, so an anchorless ticket is one omitted argument away.

---

## 6. Step 5 — the release retrospective

Aggregates the spine retros. **It refuses if any spine in the release lacks one,
naming the spine** — and the artifact it looks for is the file the spine
ceremony writes:

```text
<ai-workspace>/docs/specs/<release-id>/<spine-id>-<spine-slug>/retrospective.md
```

That is `retrospective.md`, exactly — the path block `retrospective.md` states
above its §1, and it is the only copy. Stating the
filename matters: a refusal gate that looks for the wrong artifact refuses every
release, forever, and the failure reads as "the spines are not closed" rather
than "this gate is looking in the wrong place".

Resolving it needs the slug, which **nothing persists** — recover it from the
directory name the way the work-item layer does (`work-item-close.md` §1), then:

```bash
ai_root="$(oss repo_root ai_workspace)"
spine_rel="$(oss spine_dir "$rel" "<spine-id>" "<spine-slug>")"   # RELATIVE
[ -f "$ai_root/$spine_rel/retrospective.md" ] \
  || { echo "close: $rel - spine <spine-id> has no retrospective.md - halt"; exit 1; }
```

**`oss spine_dir` returns a relative path**; prefix it with
`oss repo_root ai_workspace`. Feeding the relative path straight to `[ -f ... ]`
resolves it against `$PWD` and answers "absent" for every spine, which is a
refusal that looks exactly like a real finding.

The release retro itself lands beside them, in the release directory — the
**parent** of what `spine_dir` returns:

```bash
rel_dir="$(oss release_dir "$rel")"   # ABSOLUTE, ai_workspace-rooted
# e.g. docs/specs/r0/ — the retro is "$rel_dir/release-retrospective.md"
```

`oss release_dir` resolves the manifest root for you, so the
`docs/specs/r0/` in the comment above is relative to that resolved root —
a workspace **shape** is never something to paste into a command.

**What it aggregates**, drawing on the sections `retrospective.md` pins so this
is a roll-up and not a re-interview: what the release set out to do against what
shipped; the walkthrough outcome from §3, by feature group (**including which
groups were spot-checked rather than fully walked**); every spine's class and any
mid-flight reclassification; **what is still standing** — the fakes, deferrals and
quarantines each spine's own "still standing" section left owed, reconciled
against steps 3 and 4's findings above; the durable lessons; and the
carried-forward items. **Nothing arrives in the carried-forward roll-up that does
not appear above it**, the same rule the spine retro's §9 states.

**"What the release set out to do" has a source — read it, do not recall it:**

```bash
oss get ".releases[] | select(.id==\"$rel\") | {goal, exit_criteria}"
```

The goal is the one recorded at `release_add`; `exit_criteria` is what
`plan-release` phrased as user journeys and `release_set_meta` stored. `RELEASE.md`
in the release directory carries the same, in prose. Writing this section from
memory of the release is how a release quietly grades itself against what it
delivered rather than against what it promised — the one comparison the retro
exists to make.

**Patches shipped during the release come from git, not state** — `/ossify:patch`
writes none. Read every non-AI repo the resolved topology declares — the declared
repos `references/boundary-audit.md` §2 enumerates, each resolved with
`oss repo_root <repo>` — not only the repos this release's spines
landed in: a patch can ship in a repo no spine touched. Determine each root's
shape as that §2 does, and skip a root that is not a git repository (its
filesystem-only policy): it holds no tags and no PRs, so no patch. In each git
repo, fetch the tags
first from `origin`, the only remote `/ossify:patch` pushes to —
`git -C "<repo-root>" fetch --tags origin`, so a tag pushed from another clone is
counted — then list the tags created since
the release opened (its `created_at`:
`oss get ".releases[] | select(.id==\"$rel\") | .created_at"`) with
`git -C "<repo-root>" for-each-ref --sort=creatordate --format='%(creatordate:iso-strict) %(refname:short)' refs/tags`,
and, on origin's repository, the merged PRs whose head branch starts `fix/` with
`gh pr list --repo "<owner/repo>" --state merged --search "merged:>=<release-opened date>" --limit 1000 --json number,title,headRefName,mergedAt,url,closingIssuesReferences`. `<owner/repo>` is the repository the call targets, read from its own checkout: `gh repo view "$(git -C "<repo-root>" remote get-url origin)" --json nameWithOwner -q .nameWithOwner`. `<repo-root>` is that repository's checkout, not the directory you are in: a PR lives in the canonical even when you run from the AI workspace. On an ossify project, `oss repo_root canonical` (or `ai_workspace`) gives it. Never build the name from a folder name: an AI workspace's folder and its GitHub repo often differ.
If that returns 1000 rows, raise the limit: a truncated list drops patches. A repo
with no `origin` (spine close's local arm, or another remote name the patch lane
refuses) has nothing to fetch from and no PRs to list — skip the fetch and the
`gh` call there and read its local tags alone. Likewise skip the `gh pr list` call where `gh repo view` cannot resolve `origin`
(`gh repo view "$(git -C "<repo-root>" remote get-url origin)" --json url`): the
patch lane refuses a non-GitHub origin, so it has no patch PRs there; its
tags are still read. Read
both, and list each patch — its tag, its PR and the issues it closed — under the
retrospective's "what shipped" and in the close summary (SKILL.md §10). A
direct-commit patch-lane change (`references/patch-lane.md`) carries no version
and is not in this list; `patch_records` counts those.

**Two mechanics the port carried over from the sprint retro, and they are not
optional:**

- **The cross-release pattern round is confirmed with the user, not asserted.**
  When you name a pattern across spines ("every spine in this release
  underestimated the migration surface"), put it to the user before it lands in
  the document. A pattern is an interpretation of their project, and the retro is
  the record others will read; one wrong pattern stated confidently outlives the
  release.
- **Roll up the memory-bank harvest totals — and note they are not persisted.**
  Each spine close ran a harvest (`harvest.md`), which reports its four buckets
  — **applied / applied-with-edit / left-in-handoff / dropped** — **into the
  close summary only**: no state
  field holds them, and `harvest.md` §8 deliberately keeps them out of the spine
  retro. In the same session they are in scrollback; **in a later session they
  are gone**, and the honest entry is then "not recorded per spine — see each
  spine's close summary", not a reconstructed number. If you want the roll-up to
  survive, the place to put it is each spine's retro at the time of that close.
  A release that harvested nothing is a finding about the release, not a blank.

---

## 7. Step 6 — feature-map re-groom and the next-release sketch

The rolling-wave crank, and the reason this ceremony is a planning input rather
than only an accounting one.

```bash
oss feature_list                                    # the map, as JSON
oss feature_add "<name>" "<the value it unlocks>" "<bone|flesh>" release-retro
oss release_set_meta "$rel" '{"next_sketch":{"goal":"<one line>","candidates":["<spine>","<spine>"]}}'
```

Re-groom against what the release actually taught: the walkthrough's friction,
the fakes step 3 forced a decision on (a replacement that got renewed twice is a
feature competing for selection, not a footnote), and the quarantines step 4
surfaced. Write the **value**, never the task.

`next_sketch` is one of the five keys `release_set_meta` allows
(`exit_criteria`, `spine_dag`, `ledger_budget`, `next_sketch`,
`real_use_findings`). **Disallowed keys are dropped, not rejected** — the call
returns rc 0 having written nothing, so a typo'd key is silent. Read it back
before believing it landed.

The sketch is a **sketch**: a goal line and candidate spines. Selection, exit
criteria, the DAG and the class declaration all belong to `/plan-release`, which
reads this key as its starting point.

---

## 8. Step 7 — the boundary audit, the last refusal

**Every repo the resolved topology declares, each gated on its
observed visibility with per-role arms, fail-closed, and confirmed findings
block the close.** The whole step — the repo set and its visibility gate and
its two recorded deltas from the companion spec, the tracked-file audit
against `PUBLIC_BOUNDARY.md`'s machine-checkable rules, the scan-first
untracked sweep, the semantic pass over tracked prose against the private
boundary inventory, the recorded history pass and the working-tree pass over
uncommitted tracked modifications, and the high-stakes disposition where
**nothing is ever
auto-dispositioned to pass** — is in **`references/boundary-audit.md`**. Read
it before running this step; its triage is a conversation with the user, not a
checklist. The dimensions this scope still omit —
divergence on public refs other than the audited one after a recorded history
pass, and every submodule pin but the audited ref's together with a
non-manifest pinned submodule repository's own history — are named in that
file's own not-shipped table.

What matters for the ceremony's shape: this step runs **after** the
feature-map re-groom, so a blocked close still walked, retro'd and re-groomed
— all of that survives the halt as artifacts and planning input — and
**before** §9, so a blocked release is never recorded closed. Two unblocks: the
fix, or an **accepted-disclosure override** written to the private boundary
inventory with the surface it covers pinned (`boundary-audit.md` §6). An
overridden close reports under the audit's third verdict, never as `clean`
(`boundary-audit.md` §7).

**A halt here is not free, and steps 1-6 are not free to repeat.** A re-close
re-runs the full cumulative walkthrough — this ceremony's most expensive step —
and two of the steps it re-runs already wrote state. `oss feature_add` appends
**unconditionally**, so re-running §7 blind duplicates every feature it added:
read `oss feature_list` first and add only what is missing; and `oss
release_set_meta` has already stored a `next_sketch` for a release that is now
not closing. And `release-retrospective.md` is already on disk with a "what is
still standing" section written before the finding existed — **amend it** so the
boundary finding and its disposition join that section; never silently
re-author it. The audit still has to run last, because a fix has to be
re-audited.

---

## 9. Step 8 — tag the release, then the state writes, and only after every step above reached the end

**The tag first, because the tag is the release's only landing act.** The PR
tier sits at the spine boundary (#339): every spine closed means every spine's
hosting repos landed by PR and merged, so the base branches already carry the
release — there is no release branch and no release-level merge to gate. Tag
where it stands — **once per hosting repo this release landed in**, because a
cross-repo release's code lives in every repo that hosted one of its spines,
and a tag run from whatever directory the ceremony was invoked from tags
whichever repo that happens to be:

```bash
# The repo set: the distinct target_repos across this release's spines' work
# items - a repo that hosted nothing this release has no release to tag. Each
# repo's base branch is recovered EXACTLY as spine close step 2 recovers it
# (that repo's handoff `base_branch:` lines, cross-checked against SPINE.md's
# base-branch table - spine-close.md §3) and arrives in $repo_base_branches,
# one "<repo>:<base_branch>" line per repo. Nothing here guesses a default
# branch, and nothing here runs unscoped git: release close is invoked from
# the AI workspace as often as from a product repo, and a bare `git tag`
# lands in whichever of those the caller stood in.
# Root-bound, release-scoped, and read as a FAILING ASSIGNMENT (round 5,
# T22/T23/T25): inside `.work_items[]` the jq input is a single work item, so
# `.spines` must come from a captured root or jq fails - and a selector
# failure in a process substitution is invisible, the loop tags NOTHING and
# the pass still returns 0. jq variables crossing a shell double-quoted
# string need the backslash (\$root, \$s); $rel is shell-expanded on purpose.
tag_repos="$(oss get ". as \$root | .work_items[] | select(.status != \"abandoned\") | select(.spine as \$s | any(\$root.spines[]; .id == \$s and .status == \"closed\" and .release == \"$rel\")) | .target_repo" | sort -u)" \
  || { echo "close: the release-tag repo set could not be read from state - halt"; exit 1; }
# AN EMPTY SET IS NOT A CLEAN SET. The assignment above cannot fail and still
# return nothing, but it can SUCCEED with nothing: every closed spine of this
# release may hold only withdrawn items (an abandoned spine passes the release
# gate deliberately, and a spine can be closed by hand), or none at all. The loop
# below then iterates nothing, nothing is tagged, and the pass returns 0 - the
# same outcome the comment above refuses to allow through a selector failure, so
# it may not come in through this door either. The close record would say the
# release published while no tag exists anywhere, which is the audit-trail break
# this section exists to prevent.
[ -n "$tag_repos" ] \
  || { echo "close: $rel has no repo to tag - its closed spines hold no non-abandoned work item, so there is no landed line to publish. A withdrawal made by mistake returns with \"oss\" work_item_status <wi-id> planned - but that ALONE re-tags a repo whose work never landed: the selector above takes any non-abandoned item whose spine is closed, and this one's spine is closed by construction here, so a planned item is exactly what it wants. Nothing else stops it either - work_item_status keeps no parent-spine guard. Reopening the spine does NOT re-enable it, so land the work in a NEW spine instead (\"oss\" spine_add <release> <name> <class> <target-repo>, then the item there) and re-run this close: work-item/references/round-orchestration.md §2's re-entry arm would route the un-withdrawn item onto the branch spine close has already landed in every hosting repo - a branch nothing merges again; a release with nothing to publish is the operator's decision (there is no release-retirement status), so this ceremony stops here rather than deciding for them - halt"; exit 1; }

while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  repo_root="$(oss repo_root "$repo")" \
    || { echo "close: $rel names undeclared repo '$repo' - halt"; exit 1; }
  # The base must be UNAMBIGUOUS per repo: two closed spines recording
  # different bases in the same repo is a halt, not a first-wins pick - the
  # first-wins form silently tags one of the two landed lines and publishes a
  # release the other line never reached.
  _bases="$(printf '%s\n' "$repo_base_branches" | awk -F: -v r="$repo" '$1==r{print $2}' | sort -u)"
  _nbases="$(printf '%s\n' "$_bases" | awk 'END{print NR}')"
  if [ "$_nbases" -gt 1 ]; then
    echo "close: conflicting base branches recorded for $rel in $repo: $(printf '%s' "$_bases" | tr '\n' ' ')- a human decides which line to tag - halt"; exit 1
  fi
  base_branch="$_bases"
  [ -n "$base_branch" ] \
    || { echo "close: no base_branch recorded for $rel in $repo - halt"; exit 1; }

  # The remote, resolved: a SINGLE remote is used whatever its name; SEVERAL
  # halt naming them, origin preference included (T36, fork shapes). NO remote
  # at all is not an error here - it is the same no-remote world the landing
  # tier serves: the repo landed its spines by local merge all release, and
  # its tag is local too, verified by the same checks minus the remote leg.
  remotes="$(git -C "$repo_root" remote)"
  remote_name="$(printf '%s\n' "$remotes" | awk 'NR==1{first=$0} END{if(NR==1) print first; else print ""}')"
  if [ -n "$remotes" ] && [ -z "$remote_name" ]; then
    echo "close: $repo has several remotes (fork shapes included) - name the one to tag through and re-run - halt"; exit 1
  fi

  # THE BASE THE TAG WOULD MARK MUST BE THE PUBLISHED ONE (round 8, T31):
  # unpushed local commits on the base would be tagged and the tag object
  # published while the published base branch never carries the commit the
  # tag claims to mark. The same D5 discipline as the stranded base: halt,
  # name the state, name the remedy - never tag past the published line.
  if [ -n "$remote_name" ]; then
    git -C "$repo_root" fetch "$remote_name" "$base_branch" >/dev/null 2>&1 \
      || { echo "close: cannot fetch '$base_branch' from '$remote_name' in $repo - halt"; exit 1; }
    if ! git -C "$repo_root" merge-base --is-ancestor "$base_branch" "$remote_name/$base_branch"; then
      echo "close: $repo's local '$base_branch' has commits the published line does not carry - a release tag would mark a commit '$remote_name/$base_branch' never receives - push the base or reset to it - halt"; exit 1
    elif [ "$(git -C "$repo_root" rev-parse "$base_branch")" != "$(git -C "$repo_root" rev-parse "$remote_name/$base_branch")" ]; then
      # BEHIND (round 10, T37): the round-9 fast-forward mutated the base AFTER
      # the boundary audit had examined the stale tree - the tag then marked
      # commits the audit never saw. A stale checkout REFUSES instead: pull
      # and re-run the close. Nothing mutates the base after the audit.
      echo "close: $repo's local '$base_branch' is behind the published tip - a stale checkout must not tag past what its boundary audit saw - pull and re-run the close - halt"; exit 1
    fi
  fi

  # CONSULT THE REMOTE BEFORE CREATING (round 7, T28): an earlier halted
  # close may already have pushed this tag, and this checkout - fresh, or
  # cloned --no-tags - does not carry it. Creating anyway mints a second,
  # different annotated object (tagger and timestamp differ) and the push is
  # then refused as a non-fast-forward: the resume wedges on a tag that was
  # correct all along. Fetching the remote's tag in installs it, and the
  # verification below judges the REAL object.
  if ! git -C "$repo_root" rev-parse -q --verify "refs/tags/$rel" >/dev/null 2>&1 \
     && [ -n "$remote_name" ] \
     && [ -n "$(git -C "$repo_root" ls-remote "$remote_name" "refs/tags/$rel")" ]; then
    # A refspec with a DESTINATION: a bare `fetch <remote> <ref>` populates
    # only FETCH_HEAD and installs no ref, which reads back as "no local tag"
    # and re-enters the creation arm this exists to prevent.
    git -C "$repo_root" fetch "$remote_name" "refs/tags/$rel:refs/tags/$rel" \
      || { echo "close: tag '$rel' exists on '$remote_name' but cannot be fetched into $repo - halt"; exit 1; }
  fi

  if git -C "$repo_root" rev-parse -q --verify "refs/tags/$rel" >/dev/null 2>&1; then
    # RESUME: a tag from an earlier run that stopped between here and the state
    # writes. Continuable only when it points at this repo's base branch tip
    # locally AND - for a remote repo - the remote carries the same object:
    # anything else is a human decision, never a clobber. Two different shas
    # are in play and comparing the wrong pair resumes a mismatched tag: the
    # tag OBJECT (what ls-remote reports and what the remote comparison uses)
    # and its PEELED commit (what the base comparison uses - `rev-parse
    # refs/tags/x` yields the object, never the commit, for an annotated tag).
    local_obj="$(git -C "$repo_root" rev-parse "refs/tags/$rel")"
    # ANNOTATED, always - including on resume: a lightweight tag and its peel
    # both resolve to the commit, so the target check alone would accept one,
    # and the release would close over a tag with no release annotation.
    tag_type="$(git -C "$repo_root" cat-file -t "$local_obj")"
    [ "$tag_type" = "tag" ] \
      || { echo "close: existing tag '$rel' in $repo is $tag_type, not an annotated release tag - a lightweight tag names a commit and says nothing about the release - halt"; exit 1; }
    base_tip="$(git -C "$repo_root" rev-parse "$base_branch")"
    local_target="$(git -C "$repo_root" rev-parse "refs/tags/$rel^{}")"
    [ "$local_target" = "$base_tip" ] \
      || { echo "close: tag '$rel' in $repo points at $local_target, not $base_branch ($base_tip) - a human decides - halt"; exit 1; }
    if [ -n "$remote_name" ]; then
      remote_line="$(git -C "$repo_root" ls-remote "$remote_name" "refs/tags/$rel")"
      [ -n "$remote_line" ] \
        || { echo "close: tag '$rel' exists in $repo but not on '$remote_name' - push it (never force) or delete it deliberately - halt"; exit 1; }
      remote_tag="${remote_line%%[[:space:]]*}"
      [ "$remote_tag" = "$local_obj" ] \
        || { echo "close: tag '$rel' in $repo ($local_obj) and on '$remote_name' ($remote_tag) disagree - a human decides - halt"; exit 1; }
    fi
    echo "close: $repo already tagged $rel at $base_tip - not re-tagging"
  else
    # ANNOTATED, always: a lightweight tag names a commit and says nothing
    # about the release.
    git -C "$repo_root" tag -a "$rel" -m "release $rel" "$base_branch" \
      || { echo "close: cannot tag $rel at $base_branch in $repo - halt"; exit 1; }
    if [ -n "$remote_name" ]; then
      # A FULLY QUALIFIED refspec: a branch named like the release makes a
      # bare `<remote> $rel` ambiguous between refs/heads/$rel and
      # refs/tags/$rel, and the push fails to resolve its own source.
      git -C "$repo_root" push "$remote_name" "refs/tags/$rel:refs/tags/$rel" \
        || { echo "close: tag push for $rel refused in $repo - surface the refusal verbatim, never force - halt"; exit 1; }
    fi
    echo "close: $repo tagged $rel"
  fi
done <<EOF
$tag_repos
EOF
```

**Resumable by construction, and narrowly so (#339 round 8):** the flat "an
existing tag halts" rule made a re-invoked close unfinishable whenever the
earlier run stopped between the tag and the state writes — the tag had landed,
the writes had not, and the only way forward read as retagging. The recovery
claimed here is exactly the one straightforward case — the tag this close
created, matching the base tip, present locally and on the remote (fetched in
when the checkout lacks it); every other existing-tag state, and any base
ahead of the published line, halts naming the state and the manual remedy.
Broader auto-recovery is not claimed — see spine-close.md §3's resume policy
and the follow-up issue. The continuation condition is mechanical (the same
object, locally and on the remote, at the recovered base); every other
existing-tag state still halts, because a re-tag is history rewriting on a
published ref and that is the operator's call. A refused tag push (a ruleset
can protect tags the way it protects branches) surfaces the refusal verbatim
and halts like any other blocked landing: never `--force`, never
delete-and-retag.

```bash
oss release_status "$rel" closed
oss demo_record release "$rel" "<true|false>" "<line-count>" "<notes>"
```

**`demo_record` takes five arguments after the scope word**, not two: scope, id,
`passed`, the line count, and the notes. `passed` is the literal `true` or
`false` and anything else is rc 2. The scope word here is **`release`**; the same
verb also records **`spine`** closes (`spine-close.md` §9, step 11).

**Its third scope, `work_item`, has no caller in this release.** The lib accepts
`work_item|spine|release`, but no ceremony writes one: the work-item layer's
record of a close is `report.md` plus the item's `status`, and nothing reads a
`work_item` close record. `close_records` is likewise **write-only in v0.2** —
the ceremonies append to it and nothing consumes it. Both are Plan C1 groundwork
for the v0.3 records work, and saying so here is the point: an unread record that
looks read is how a later reader concludes a check exists.

`release_status` accepts `planned|active|closed` — the release enum has **no
`abandoned`**, unlike the spine enum §2 reads.

**A halt anywhere above stops the close record.** Neither of these lines runs
after a refusal, a failed demo line, either blocking finding, or a confirmed
boundary-audit finding — so nothing is ever recorded as closed. It does **not**
mean nothing was written: §7's `feature_add` and `release_set_meta` already
ran, which is what §8's re-close note is about.

---

## 10. What has no executable surface

Stated plainly so nobody infers coverage that does not exist.

**The step order, the walkthrough itself, the abandoned-spine confirmation and
the retro's aggregation are prose contracts.** A bash script that calls the
gates in order asserts nothing about the ceremony; it tests a fixture written to
pass. The harness checks that every `oss` verb this file names resolves.

The mechanical seams **are** covered in `tests/test-close.sh`: the fake-expiry and
quarantine gates' full rc contracts driven through the dispatcher under real strict
mode, the seven expiry/quarantine fixtures that discriminate a correct selector from a
broken one, and the two shipped branch blocks above extracted from this file and
executed. **The deferral gate (§5b) is not among them** — its rc contract is driven at
the same depth, through the dispatcher and against the boundary (`<=`, the anchorless
row, the pending-retire rows), in `tests/test-demo-line-status.sh`; its branch block
above is not executed by any test.

---

## 11. Anti-patterns

- **Reading `abandoned` as `closed`** — or hard-halting on it and making the
  release uncloseable (§2).
- **Gating a release-level merge.** There is none to gate: the PR tier is the
  spine boundary's, and this ceremony only tags the already-merged `main` (§1,
  §9).
- **Re-tagging, force-pushing, or delete-and-retagging a published release
  tag.** An existing tag halts; rewriting a published ref is the operator's
  call, made explicitly (§9).
- **Testing the rc of `oss get` instead of its output.** An empty `select` exits
  0 (§2).
- **Passing a spine id to `oss demo_user_lines` here.** The release walk takes no
  argument (§3).
- **Applying demo amendments at release close.** The spines already did (§3).
- **Implying a `.feature` field on demo lines.** There is none; the grouping is
  derived (§3).
- **Rotating features through spot-checks silently.** Explicit and recorded, or
  walk them all (§3).
- **Copying `touch_check`'s branch shape onto either blocking gate.** rc 0 is a
  hit there and CLEAN here (§4, §5).
- **Folding either gate's rc 2 into clean** (§4, §5).
- **Comparing release ids as strings.** `"r2" <= "r10"` is false (§5, and
  `fake-expiry.md` §3).
- **Blocking on a quarantine raised during this release.** Strictly earlier (§5).
- **Reporting a retired line as cleared.** `retire` records intent; a spine
  applies it (§5).
- **Feeding `oss spine_dir`'s relative path to a file test unprefixed** — every
  spine then looks retro-less (§6).
- **Trusting `release_set_meta` silently.** A disallowed key is dropped at rc 0
  (§7).
- **Writing `release_status closed` after any halt** (§9) — a boundary-audit
  halt included (§8).
- **Auto-dispositioning a boundary-audit finding, or closing "with a leak
  noted."** Every finding reaches the user; a confirmed one blocks until it is
  fixed or accepted on the record (`boundary-audit.md` §6).
- **Reporting an overridden close as `clean`.** An acceptance takes the audit's
  third verdict and names its inventory row (`boundary-audit.md` §7).
