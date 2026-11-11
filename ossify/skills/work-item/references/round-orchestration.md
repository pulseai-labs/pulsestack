# Round orchestration — the execution lane

Depth for SKILL.md §1, Mode B. This is the **caller's** half of the contract: the
lane that walks one spine's rounds, spawns a worktree per work item, dispatches
one worker per item, and owns every boundary the implementer is forbidden to
cross — the clarification loop, the commit, the merge.

It runs in the orchestrator's session, holding the state lock (spec §9.2). **An
implementer never runs any of it**, and `Task` is on the implementer's NEVER list
precisely so it cannot try.

Read this when you are driving a spine. If you are the worker executing one
handoff, this file is context, not instruction — your contract is SKILL.md §3-§9.

---

## 1. Where the rounds come from

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

The work-item rounds live in the **spine plan document** that `plan-spine`
authored, under:

```bash
# /run-spine hands you ONLY the spine id. The release id and the slug are not
# arguments — derive one, recover the other, exactly as close does (Route B in
# `close/references/work-item-close.md` §1, inlined in `close/references/harvest.md` §2).
rel_id="r$(oss id_parse "$spine_id" | awk '{print $2}')"       # r1.s2 -> r1
rel_dir="$(oss release_dir "$rel_id")"   # ABSOLUTE, ai_workspace-rooted
matches="$(find "$rel_dir" -maxdepth 1 -type d -name "$spine_id-*" 2>/dev/null)"
n="$(printf '%s\n' "$matches" | grep -c . || true)"
[ "$n" -eq 1 ] || { echo "halt: expected exactly one spine dir for $spine_id, found $n"; exit 1; }
spine_dir_abs="$matches"
spine_slug="${spine_dir_abs##*/}"; spine_slug="${spine_slug#$spine_id-}"
```

**Nothing in state holds the slug**, so the directory is recovered by glob with
an ambiguity guard and the slug falls out of the directory name. Inventing it
from the spine's `name`, or asking the user, produces a path that does not match
what `plan-spine` actually wrote.

**`oss spine_dir` returns a RELATIVE path** (`docs/specs/<release-id>/<spine-id>-<slug>`)
— it must be prefixed with the ai_workspace root, exactly as every sibling
consumer in `close` does. Used bare it resolves against whatever directory the
agent happens to be standing in, which during a round is usually a worktree
under a declared repo — so the read silently misses, or worse, finds a
different project's file. (`oss release_dir <release-id>` returns the release
level of the same tree already absolute, if that is all you need.)

Read them from there. Two ways to get this wrong, both silent:

- **Not from `releases[].spine_dag`.** That field is `plan-release`'s
  **inter-spine** DAG — it sequences whole *spines*. Reading it here yields spine
  ids where work-item ids are needed, and the mistake surfaces as an empty or
  nonsensical round list, not as an error.
  `plan-spine/references/dag-rounds.md` draws the line: same idea, finer
  altitude, different owner.
- **Not re-derived here.** The rounds are planning output. If reality disagrees
  with the plan, that is a replan — go back to `plan-spine`, re-record, and come
  back. Improvising a new order at execution time produces a spine that is wrong
  in a way nobody can see later (`plan-spine/references/dag-rounds.md` §7).

**No state field holds the work-item rounds.** `work_items[]` carries
`{spine, title, target_repo, status, created_at}`, plus the
`{branch, worktree_path, base_sha, dispatches}` this lane writes — no dependency
key, no round key. Persisting the round structure as state is **deferred**;
until it lands the plan document is the only record. Say so if a user asks where
the rounds are stored; do not imply the read is machine-backed.

---

## 2. Enter the spine — fresh cut, or re-entry

This section runs on **every** `/run-spine`. The hosting repos are the distinct
`target_repo` values across the spine's work items **other than `abandoned`
ones**, read from state — an item withdrawn before dispatch runs nowhere, so a
repo only it names gets no branch. **One observable picks the arm: does the spine
branch exist in any hosting repo?** — with a second, fail-closed probe behind it:
recorded execution state with no spine branch anywhere is a **halt**, never a
fresh re-cut (below).

```bash
spine_branch="$(oss branch_name "<spine-id>" "<spine-slug>")"
# Read the hosting-repo list in its OWN assignment, never inside the here-doc
# below: a command substitution there cannot carry its rc, so a failed state
# read would fall through to arm=fresh off an empty list. `unique[]` does the
# dedup jq-side, so no pipe stands between `get` and the `||` either.
repos="$(oss get '[.work_items[] | select(.spine=="<spine-id>" and .status != "abandoned") | .target_repo] | unique[]')" \
  || { echo "halt: cannot read the spine's work items from state"; exit 1; }
arm=fresh
while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  root="$(oss repo_root "$repo")" || exit 1     # undeclared repo halts HERE
  # --verify --quiet returns 1 for BOTH absence and malformed loose refs.
  # --exists distinguishes absence (2) from a failed lookup (1).
  ref_rc=0
  git -C "$root" show-ref --exists "refs/heads/$spine_branch" 2>/dev/null || ref_rc=$?
  # Git without --exists returns usage rc 129: retain the legacy probe only
  # there. Known limit: legacy rc 1 conflates absence and malformed loose refs.
  if [ "$ref_rc" = 129 ]; then
    ref_rc=0
    git -C "$root" show-ref --verify --quiet "refs/heads/$spine_branch" || ref_rc=$?
    [ "$ref_rc" != 1 ] || ref_rc=2
  fi
  case "$ref_rc" in
    0) git -C "$root" show-ref --verify --quiet "refs/heads/$spine_branch" \
         || { echo "halt: cannot read $spine_branch in $repo"; exit 1; }
       arm=re-entry ;;
    2) ;; # absent (or ambiguous legacy rc 1)
    *) echo "halt: cannot read $spine_branch in $repo (git show-ref rc $ref_rc)"; exit 1 ;;
  esac
done <<EOF
$repos
EOF
# THE SECOND PROBE (#673 A6). The spine refs can be GONE while durable
# execution state survives - a deleted branch, a cleaned checkout - and the ref
# test alone then selected the fresh arm: it records bases and CUTS new spine
# branches before §3's worktree_add collides with the surviving work, mutation
# before the promised halt. Recorded execution evidence - any item's branch,
# worktree_path or base_sha, a status past `planned`, or a dispatch count -
# means the spine started. With no spine branch anywhere, that is a halt.
started="$(oss get '[.work_items[] | select(.spine=="<spine-id>")  # abandoned items are DELIBERATELY included: the conjunct is for reads that must skip a withdrawn item; here a withdrawn item still proves the spine started
  | select(((.branch // "") != "") or ((.worktree_path // "") != "") or ((.base_sha // "") != "")
           or .status == "active" or .status == "complete" or ((.dispatches // 0) > 0))] | length')" \
  || { echo "halt: cannot read the spine's work items from state"; exit 1; }
if [ "$arm" = fresh ] && [ "$started" != "0" ]; then
  echo "halt: no hosting repo has $spine_branch, but state records execution for this spine (an item records a branch, a worktree_path, a base_sha, a status past planned, or a dispatch count) - the spine's refs are gone while its state survives, and re-cutting would collide with that work. Nothing was changed; a human decides which record is right"
  exit 1
fi
echo "arm=$arm"
```

- `arm=fresh` — no hosting repo has the branch **and no item records execution
  state**: this is the spine's first run. Take **§2a**.
- `arm=re-entry` — some hosting repo has it: an earlier run got here first. That
  is the **normal** state at the top of every round after the first (a later
  round's spec may be authored when its round starts — `plan-spine`'s
  `spec-authoring.md` §3), and it is also the state a halted or interrupted run
  leaves. Take **§2b**. Never re-cut, never half-reuse.

### 2a. Fresh arm — check, record, cut, check out

```bash
(
repo_list=""; repo_bases=""
trap '[ -z "$repo_list" ] || rm -f -- "$repo_list"; [ -z "$repo_bases" ] || rm -f -- "$repo_bases"' EXIT
spine_branch="$(oss branch_name "<spine-id>" "<spine-slug>")"
repo_list="$(mktemp)" || exit 1; repo_bases="$(mktemp)" || exit 1
repos="$(oss get '.work_items[] | select(.spine=="<spine-id>" and .status != "abandoned") | .target_repo')" \
  || { echo "halt: cannot read the spine's work items from state"; exit 1; }
printf '%s\n' "$repos" | sort -u > "$repo_list"

# PASS 1 - CHECK every hosting repo. Mutate nothing. A halt here leaves every
# repo exactly as it was found.
while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  root="$(oss repo_root "$repo")" || exit 1     # undeclared repo halts HERE
  porcelain="$(git -C "$root" status --porcelain)" || { echo "halt: cannot read status in $repo"; exit 1; }
  [ -z "$porcelain" ] || { echo "halt: $repo is dirty"; exit 1; }
  # A failed lookup is not absence, even when quiet --verify would return 1.
  ref_rc=0
  git -C "$root" show-ref --exists "refs/heads/$spine_branch" 2>/dev/null || ref_rc=$?
  # Git without --exists returns usage rc 129: retain the legacy probe only
  # there. Known limit: legacy rc 1 conflates absence and malformed loose refs.
  if [ "$ref_rc" = 129 ]; then
    ref_rc=0
    git -C "$root" show-ref --verify --quiet "refs/heads/$spine_branch" || ref_rc=$?
    [ "$ref_rc" != 1 ] || ref_rc=2
  fi
  case "$ref_rc" in
    0) git -C "$root" show-ref --verify --quiet "refs/heads/$spine_branch" \
         || { echo "halt: cannot read $spine_branch in $repo"; exit 1; } ;;
    2) ;; # absent (or ambiguous legacy rc 1)
    *) echo "halt: cannot read $spine_branch in $repo (git show-ref rc $ref_rc)"; exit 1 ;;
  esac
  if [ "$ref_rc" = 0 ]; then
    echo "halt: $spine_branch already exists in $repo - this spine has started; take the re-entry arm (§2b), not this block."; exit 1
  fi
  base_branch="$(git -C "$root" rev-parse --abbrev-ref HEAD)"
  [ "$base_branch" != "HEAD" ] || { echo "halt: $repo is in DETACHED HEAD"; exit 1; }
  printf '%s\t%s\n' "$repo" "$base_branch" >> "$repo_bases"
done < "$repo_list"

# RECORD - every repo passed; record each base in state BEFORE any cut, so a
# crash inside PASS 2 always leaves the base the re-entry arm's `cut-missing`
# repair needs.
while IFS="$(printf '\t')" read -r repo base_branch; do
  [ -n "$repo" ] || continue
  oss spine_base_set "<spine-id>" "$repo" "$base_branch" || exit 1
done < "$repo_bases"

# PASS 2 - cut, in the same order.
while IFS="$(printf '\t')" read -r repo base_branch; do
  [ -n "$repo" ] || continue
  git -C "$(oss repo_root "$repo")" checkout -q -b "$spine_branch" || exit 1
done < "$repo_bases"
)
```

Each of these is load-bearing:

**A RECORD pass can legitimately refuse (rc 7), and the refusal names the one
correction route.** `spine_base_set` refuses when a base is already recorded and
the observed one differs — a crash inside this pass, or a hosting repo re-parked
since — because a recorded base is evidence of what the lane was about to cut
from. It validates the value before recording too: the branch must EXIST locally
in that repo, so a typo can no longer be journaled as evidence. The correction
is `oss spine_base_reset <spine-id> <repo> <branch>` (a validation-checked
replacement, journaled as `reset_spine_base`) — an OPERATOR decision about which
value is right, which the lane never makes or calls on its own.

**A spine branch cut here is local until spine close pushes it.** The branch is
created, never pushed — rounds land work items onto it locally, and only spine
close's PR arm pushes it and opens the PR against the repo's base branch
(`close/references/spine-close.md` §3, #339). Nothing in the lane pushes. One
other step does: a PR-mode item close (`/close <wi-id> --pr`,
`work-item-close.md` §4a) pushes the branch when origin lacks it, as its PR's
base, and opens no PR for it. Spine close's resume probe looks for a PR, never
for the branch, so it pushes again and opens the spine PR as usual. Nothing
else should push it: a spine PR opened early is an artifact that probe would
then find and have to reason about.

**Check every repo before cutting a branch in any of them.** This was one loop
that checked and mutated per repo. With an earlier-sorted repo clean and a later
one dirty, detached, or already carrying the spine branch, the first repo's
branch was already cut when the halt fired — and re-running then failed that
repo's own already-exists guard, which the re-entry arm's `cut-missing` repair
(§2b) completes now: it cuts the branch in the repos the halt never reached,
from each repo's recorded base. A condition that should merely block dispatch
instead wedged the spine until someone repaired the repos by hand. The checks
are cheap and read-only; the `checkout -b` only runs once all of them have
passed.

**`$repo_bases` is a per-repo MAPPING, not a variable.** `base_branch` was a
single name overwritten on every iteration, so only the last repo's value
survived the loop — and §2a's RECORD pass must write *each* target repo's
observed base into state (`spine_base_set`), the value every handoff copies
and spine close treats as its primary merge destination. Writing one repo's
base into another repo's handoff either halts the close or merges into a
same-named branch that happens to exist there. **Handoffs read the base from
state, in both arms** — copy `base_branch:` from `oss spine_base_get
<spine-id> <repo>`; never carry a surviving `$base_branch`.

**`oss repo_root "$repo"`, never a bare `<repo-root>` placeholder.** The verb
resolves the declared repo's root from the topology declaration
(`.ossify/topology.json`, or a translated `.workspace/pairing.json` fallback)
and fails rc 2 — naming the declared set — rather than defaulting to the
working directory. A
placeholder that a reader fills in by hand is how a spine gets built in
whichever repo the session happened to start in.

**`checkout -b`, not `branch`.** `git branch` creates the ref and leaves you
standing where you were. The repo then stays on its previous branch for the
whole spine, and every consequence is rc 0:

| Step | With the checkout | With `git branch` only |
|---|---|---|
| Work-item merge (`close`) | lands on the spine branch | lands on the *previous* branch, rc 0 |
| Spine-close merge (`close`) | a real merge | "Already up to date", rc 0 |
| `oss worktree_remove` | deletes a merged branch | deletes it too — it *is* merged, into the wrong target |
| Cumulative demo | measures the spine's work | measures a tree assembled by accident, green |

Nothing in that column reports a failure. **Each hosting repo stays parked on
`$spine_branch` for the duration of the spine**, and spine close is what moves
it off, in that repo.

**The slug is not in state.** Spines store `name`, work items store `title`;
neither is a kebab slug, and nothing persists one. `plan-spine` minted the spine
slug when it created the spine directory — **recover it from that directory
name** rather than re-kebabing `name`, so the branch and the directory cannot
drift apart. For work items there is no such anchor, which is exactly why §3
writes the branch it actually created into state.

### 2b. Re-entry arm — read out, then reconcile, then continue

**1. The read-out, before any mutation.** Print the inventory. A halt row stops
the lane here, having changed nothing:

```bash
inv="$(mktemp)"; inv_rc=0
oss spine_inventory "<spine-id>" > "$inv" || inv_rc=$?
cat "$inv"; rm -f "$inv"
case "$inv_rc" in
  0) ;;
  3) echo "halt: the inventory above has halt rows - repair each one, then re-run /run-spine (it re-inventories); nothing was changed"; exit 1 ;;
  *) echo "halt: spine_inventory could not read the spine (rc $inv_rc) - state or usage is broken, not the spine; nothing was changed"; exit 1 ;;
esac
```

Show the user every row. Say for any item whose facts show no `dispatches`
field that its prior dispatches are unknown and count from zero.

**2. Map the routes onto the rounds** — still before any mutation. The rounds
come from the spine plan document (§1). The **resume round *R*** is the first
round holding an item whose route is not `skip`; an `in-flight` row counts as
not `skip`, so its round stays unfinished until its PR merges. Every item in a round after
*R* must route `spawn` (or `skip` for an `abandoned` item); anything else is
**`halt:out-of-order`** — work exists beyond an unfinished barrier. Name it and
stop. If no round holds a non-`skip` item, the rounds are done: say so and hand
over to `/close <spine-id>`, as §7 does.

**3. Repair the repos.**

- `base-backfill` (a spine cut before ossify 1.14.0 recorded no base): read
  this repo's `base_branch:` lines from the spine's existing handoffs. If they
  agree, `oss spine_base_set <spine-id> <repo> <that branch>`. If they
  disagree, halt and name the handoffs. If none exist, ask the operator once for
  the branch the spine branch was cut from, then record it the same way.
  **Never** take it from HEAD, which is the spine branch by now.
- `cut-missing` (a crash inside §2a's PASS 2). **The recorded base is validated before this loop runs**: the inventory emits `halt:base-unresolved` for a repo whose base no longer resolves, so a rename or deletion halts the read-out instead of failing here after the earlier repos were already cut (#673 G3):

```bash
spine_branch="$(oss branch_name "<spine-id>" "<spine-slug>")"
cut="$(mktemp)"
oss spine_inventory "<spine-id>" | awk -F'\t' '$1=="repo" && $3=="cut-missing" {print $2}' > "$cut"
while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  root="$(oss repo_root "$repo")" || exit 1
  base="$(oss spine_base_get "<spine-id>" "$repo")" || exit 1
  git -C "$root" checkout -q -b "$spine_branch" "$base" || exit 1
done < "$cut"
rm -f "$cut"
```

**4. Repair round *R*'s items, in declared decomposition order** — each through
the verb that already owns the step:

| Route | Do |
|---|---|
| `reattach` | `oss worktree_reattach <repo> <wi-id> <recorded branch>`; a non-zero result **halts naming the git error**, leaving the stale entry and the branch as found — never `git worktree prune`, never `-f -f`. It clears only this item's OWN dead registration (`…/.worktrees/<wi-id>` whose directory is gone, via `git worktree remove`); a live holder or a stale entry at any other path refuses rc 8 (#673 E1/E2), and validation precedes every removal, so a locked or foreign entry anywhere in the set refuses with ALL of them left as found (#673 I1). On success, re-run the inventory and act on that item's new route |
| `adopt` | the row reads `wt=present` but state holds no `worktree_path` yet and §2b defines no `$wt` for you (#673 B2): set `root="$(oss repo_root "<the item's target_repo>")"` and `wt="$root/.worktrees/<wi-id>"` (the derived path, exactly as `worktree_add` builds it) — then `oss work_item_exec <wi-id> "$(git -C "$wt" rev-parse --abbrev-ref HEAD)" "$wt" "$(git -C "$wt" rev-parse HEAD)"` and, ONLY when `oss get '.work_items[] | select(.id=="<wi-id>") | .spec_oid // ""'` reads empty (halt if that read errors), add the fifth argument `"$(oss spec_oid "<the item's spec.md, §3's path>")"` and print `spec value recorded at repair, not at dispatch` (the dispatch-time spec was never recorded, so the check this arms can only see edits made after the repair; a recorded value is kept by the four-argument call), then `oss work_item_status <wi-id> active` — the crash came between §3's spawn and its journal |
| `finish-merge` | Re-land the claim the state makes: the branch holds the item's commits and the spine branch does not. Recover, in this order, BEFORE anything merges (#673 C3/L1): `target_repo` from state (`.work_items[].target_repo`), then `repo_root="$(oss repo_root "$target_repo")"` — `$repo_root` is not otherwise in this arm's scope — then `wi_branch` from state (`work_items[].branch`) and `wi_sha="$(git -C "$repo_root" rev-parse "refs/heads/$wi_branch")"`, the work-branch tip the reachability check compares. **Then run the spec check (#434)**: this row re-runs the gate without close §1, so it runs `work-item-close.md` §1's spec-check block itself, with `spec` set to the item's `spec.md` (§3's path) and `wi` to the item, before the gate; `halt:spec-changed` stops the row with nothing merged. **Then RE-RUN close §2's gate on the item's committed tree before the merge (#673 K1)**: neither a commit on the branch nor a present `report.md` proves the gate ran — the item skill authors the report BEFORE staging — so §2's four layers (`work-item-close.md` §2, `references/impl-check.md`) run again over the branch's committed diff (read the committed tree, not a staged worktree, when the worktree is gone), against the item's `spec.md`, `handoff.md` and `report.md`. Green → close §4 from its merge onward: `git -C "$repo_root" merge --no-ff "$wi_branch"`, then `merge-base --is-ancestor "$wi_sha" HEAD`, then `work_item_status "$wi" complete`. Red → `halt:unverified-merge`, naming the item; **nothing is merged**. The gate is repeatable and records only what §2 already writes. **The durable `[fidelity]` rejection record gates this route in the read-out too (#673 J1)**: the same `verify.md` read that routes `close-finished` to `halt:close-rejected` runs here and on the complete-item arm — a recorded rejection is never re-landed by a merge, and an unreadable record halts (`halt:unreadable`) rather than reading as clear |
| `finish-status` | `oss work_item_status <wi-id> complete` — the merge landed and the status write did not |
| `in-flight` | nothing, in every mode — the item is `active` with its commit past base and `pr_url` recorded (`/close <wi-id> --pr`, `work-item-close.md` §4a), so its merge belongs to the PR. Never merge the work branch locally and never redispatch it; §3 gives it no dispatch and §7 reports it with its PR. Once the PR merges and the spine branch is fast-forwarded, the next read-out routes it `finish-status`, or `skip` once its status is `complete` |
| `redispatch`, `close-finished`, `spawn` | nothing here — §3 handles them |
| `skip` | nothing |

**Every `halt:` row owns a repair; the read-out stops the lane and the repair
runs outside it, then `/run-spine` re-inventories.** The item-level rows this
arm's own repairs can hand back, and their routes out:

| Halt row | The repair it names |
|---|---|
| `halt:state-claims-merge` — a `complete` item whose branch still sits at its recorded base | the branch holds no commits past its base, so no merge can be reconstructed from repo state: if the item's work exists elsewhere, return it to `planned` (`oss work_item_status <wi-id> planned`) and re-run its round; if it truly landed nothing, the state is the record to repair. (`complete` items whose branch holds unmerged commits now route `finish-merge` instead; a branch that is gone is the cleanup arm and routes `skip` only when neither the conventional nor a differing recorded path is occupied outside the item's live linked worktree — #673 A5) |
| `halt:base-unknown` — an ITEM row (planned or active): a branch is recorded with no `base_sha` | a half-written `work_item_exec` record; repair it with a full re-dispatch, `oss work_item_exec <wi-id> <branch> <worktree_path> <the base the branch was cut at>`, which replaces all three fields (#673 A1). First read the recorded spec id, `oss get '.work_items[] | select(.id=="<wi-id>") | .spec_oid // ""'`, and halt if that read errors. Pass the fifth argument `"$(oss spec_oid "<the item's spec.md, §3's path>")"` and print `spec value recorded at repair, not at dispatch` ONLY when state holds no `spec_oid` for the item; when it holds one, call with the four arguments above, so the dispatch-time value is kept (#434) |
| `halt:base-unresolved` — a repo row: the recorded base branch no longer resolves locally (renamed or deleted since it was recorded) | the `cut-missing` repair cuts from that ref, so re-entry would create the spine branch in the earlier repos and only then fail here — a partial mutation. Restore the branch, or, if it was renamed, record the new name with `oss spine_base_reset <spine-id> <repo> <new-branch>` (an operator decision, §2a); the lane never guesses a replacement (#673 G3) |
| `halt:branch-unknown` — a `complete` item with no branch ever recorded | nothing proves a branch existed, so the cleanup-finished `skip` reading is unearned: state, not the repos, is the record to repair. If the item truly ran, restore the full execution record (a full re-dispatch replaces all three fields, as `halt:base-unknown` says) or return it to `planned`; if it was withdrawn, mark it `abandoned` (#673 L3) |
| `halt:worktree-held` | the branch is checked out somewhere that is not this item's own missing registration (`git -C <repo-root> worktree list`) — or that list itself could not be read, which reads the same way (#673 A4/G1), or the registration is LOCKED, which reattach refuses too (#673 L4); for a complete item with the conventional path absent, cleanup also owns a live `/.worktrees/<wi>` registration under the derived or recorded root (compared physically), so a clean merged item there skips; an occupied conventional path outside that live worktree or a holder cleanup does not own still halts. On a complete item, the read-out halts here when close's cleanup would refuse (an extra registration under another root, an unreadable worktree list, or a locked registration cleanup would remove). Reconcile with the holder — the lane touches nothing on an unowned holder's behalf (#673 A4) |
| `halt:spec-changed` — the `finish-merge` row's spec check, or close §1's | the item's `spec.md` is not the one dispatched; the value changes only through a new dispatch. The two routes out are `work-item-close.md` §1's: restore the dispatched spec and re-run, or return the item to `planned` and re-dispatch it through §3 (#434) |
| `halt:unverified-merge` | the row's RE-RUN of close §2's gate came back RED on the item's committed tree (#673 K1): run the item's correction — the recovery menu's path, or the external seam's continuation — before anything merges; nothing was merged, and a `[fidelity]` finding the red run wrote routes the next read-out `halt:close-rejected` |
| `halt:close-rejected` | the result's last completed gate run recorded a `[rule]`, `[fidelity]` or `[mutation]` verdict (durable in `verify.md`); the correction must complete — the external seam's continuation or the close's recovery menu — before anything re-verifies or RE-LANDS the result. Gates `close-finished` AND every `finish-merge` arm (#673 C2/J1, #971) |
| `halt:pr-not-local` — a `complete` item with a PR recorded whose commits the local spine branch lacks | the PR merged on the remote but the local spine branch lacks it: fetch and fast-forward the spine branch (`git merge --ff-only origin/<spine-branch>`), then re-run; never merge the work branch locally — that forks the local spine branch from the remote |
| `halt:unreadable` | a repo root, a branch-presence probe, the recorded base ref, a `git status`, the `spine_base_get` base getter, a `verify.md` rejection record, or the state feed could not be read; fix that and re-run — nothing here is in the lane's hands (#673 A2/A3/G2) |
| `halt:unclassified` — an `abandoned` item retaining execution evidence | halt rather than skip: inspect the item's recorded `branch`, `worktree_path`, `base_sha` and `dispatches`, its handoff/report, and the branch and worktree in its target repo. The operator decides which record is right before retrying; never erase evidence or invent a state-editing verb to clear the halt |
| `halt:work-lost`, `halt:unclassified`, `halt:planned-with-worktree`, `halt:dirty-worktree` | state and repos disagree, or the shape is outside this table; surface both and decide — a branch no longer descended from its recorded `base_sha` is a history rewrite, never a landing: restore the expected history or re-dispatch the item (#673 H1); a completed item's dirty worktree halts here too, since cleanup's `worktree_remove` would refuse it at close (#673 I2); a recorded branch that is not this item's own `work/<wi-id>-*` is never reused for reattach, redispatch or merge (#673 L2); a staged result at its base whose `report.md` is missing (a return lost before the lane wrote it, #978) halts `halt:dirty-worktree` too: never re-dispatch it, Gate 3 refuses a staged worktree — re-create the report per §6's *Recovering a staged item with no report*, then re-run |

**5. Continue into §3 for round *R*.**

**#362's per-round re-entry is the plain case of this arm.** At the top of round
*K+1* every row is `skip` or `spawn`, so the read-out is short, steps 3–4 do
nothing, and §3 runs the round exactly as a fresh round. Every protection still
halts: a dirty or detached repo, a repo parked off the spine branch, an item
stuck `active` behind the barrier.

**`base_branch` comes from state, in both arms.** §2a records what each repo
was parked on at the cut (`spine_base_set`); every handoff copies `base_branch:`
from `oss spine_base_get <spine-id> <repo>`, never from HEAD. Park each
hosting repo on its intended base before the first run: the recorded base is
whatever it was parked on.

**Cross-check the base against the plan BEFORE the first dispatch — a mismatch
is a halt, not a note.** `plan-spine` authors a *planned* base per hosting repo
into `SPINE.md`'s base-branch table (`plan-spine/references/spec-authoring.md`
§1). Compare that repo's row against the value state holds — the base about to
be recorded in the fresh arm (§2a's RECORD, checked as PASS 1 observes it), or
the recorded base in the re-entry arm before §3 dispatches anything in that
repo. A wrong-base cut caught here costs one parked repo to re-park; caught
only at spine close §3, where the same cross-check runs, it costs the whole
spine, every round already merged onto the branch. Where `SPINE.md` carries no
row for a repo (a legacy spine), say so in the run's summary rather than
inventing one — the close still cross-checks at landing time.

---

## 3. Per work item in the round

**First, check an `abandoned` item before skipping it.** Retained execution
evidence (`branch`, `worktree_path`, `base_sha` or a positive `dispatches`
count) is §2b's `halt:unclassified`, with the operator's inspection and decision
there; never skip that shape or dispatch it. Only a clean abandoned record is
skipped. Read its status —
`oss get '.work_items[] | select(.id=="<wi-id>") | .status'` — and if it is
`abandoned` with no retained execution evidence, the item was withdrawn before dispatch
(`plan-spine/references/decomposition.md` §1) and the plan still lists it: no
spec check, no worktree, no handoff, no dispatch, and the §7 barrier does not
wait for it. This holds in both dispatch modes — `external-executor.md` §2 runs
this section for every item in the round, so an abandoned item gets no request
either. Never dispatch it to "see whether it still applies": un-withdrawing is a
planning decision (`oss work_item_status <wi-id> planned`), made in
`plan-spine`, not here.

**On re-entry, follow the item's route.** `spawn` takes the path below
unchanged. `redispatch` reuses the recorded worktree and its existing handoff
(author it now if it is missing), runs §3's dependency step again, and then goes to §5.
Run that step in the recorded worktree: set
`wt="$(oss get '.work_items[] | select(.id=="<wi-id>") | .worktree_path')"` first, and halt
naming the item if it is empty or `git -C "$wt" rev-parse --is-inside-work-tree` fails. An `adopt` item that
§2b step 4 just repaired is in exactly that shape — active, clean, at its
recorded base — so it takes the `redispatch` path too, authoring the handoff
first when it is missing. A `reattach` item takes whatever route the re-run
inventory gave it. `close-finished` skips dispatch entirely — default mode
hands it to close Route A as a complete return with the recorded `report_path`,
summary `recovered on resume: return lost with the prior session`, and
`stage_status all_staged` (close's gate runs in full). A lost return that
carried `report_text` leaves no report, so that item reads `halt:dirty-worktree`
instead, and §6's *Recovering a staged item with no report* brings it here; external mode sends it
in the round's request set (`external-executor.md` §2a), except under
`--detach`, where it gets no request and the caller closes it (§2b). An item already
`complete` — a `skip` row for a merged item, or a `finish-status` /
`finish-merge` row §2b step 4 just repaired — gets nothing here: no worktree,
no handoff, no request, no dispatch. §7 does not wait on it again (it is
complete). An `in-flight` item gets no dispatch either, in every mode: its
result is committed and its PR is open, so no worktree, no handoff, no request
and no dispatch; §7 reports it and ends the lane.

**Before spawning anything: confirm the round's specs exist and parse.**
`plan-spine` may legitimately defer a later round's specs until that round starts
(`plan-spine/references/spec-authoring.md` §3), so for round *K > 1* the spec may
not have been authored yet:

```bash
spec="$spine_dir_abs/work-<wi-id>/spec.md"
[ -f "$spec" ] || { echo "halt: no spec for <wi-id> - re-enter /plan-spine for this round"; exit 1; }
# Test the OUTPUT, not the rc. `oss verify_acs` returns 0 on a spec that yields
# zero parseable rows — the same empty-but-successful shape `report_cross_check`
# guards with `[ -n "$rows" ] || return 2`. An `|| { … }` here cannot fire for
# the condition its own message names, which is a guard that reads as coverage.
rows="$(oss verify_acs "$spec")" || { echo "halt: <wi-id>'s spec could not be read"; exit 1; }
[ -n "$rows" ] || { echo "halt: <wi-id>'s spec parses to no ACs - grammar drift, or it was never authored"; exit 1; }
```

**This lane does not author specs** — it dispatches workers who read them. A
missing spec means the round was dispatched before it was planned, so the fix is
to re-enter `plan-spine` for this round, not to write one here. Checked now, the
recovery is one skill invocation; left to the worker's Gate 2 it comes back as a
gaps-mode return that reads like an under-specified work item rather than a
skipped planning step.

Then, in **declared decomposition order** — the order the plan lists them, never
the order returns arrive.

```bash
target_repo="$(oss get '.work_items[] | select(.id=="<wi-id>") | .target_repo')"
# FIRST - before anything is created or journaled. Any DECLARED repo executes;
# ai_workspace never does (it is the process record, not an execution target).
[ "$target_repo" != "ai_workspace" ] && oss repo_root "$target_repo" >/dev/null 2>&1 \
  || { echo "halt: work item <wi-id> targets '$target_repo' - not a declared repo (or is ai_workspace)"; exit 1; }
spec_oid="$(oss spec_oid "$spine_dir_abs/work-<wi-id>/spec.md")" \
  || { echo "halt: cannot hash <wi-id>'s spec"; exit 1; }
wt="$(oss worktree_add "$target_repo" "<wi-id>" "<wi-slug>" "$spine_branch")"
branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
oss work_item_exec "<wi-id>" "$branch" "$wt" "$(git -C "$wt" rev-parse HEAD)" "$spec_oid"
oss work_item_status "<wi-id>" active
```

**The order of those two lines is the whole guard.** Placed after
`worktree_add`, it fires having already created the worktree in the wrong repo,
journaled its path through `work_item_exec`, and marked the item `active` — so
the "prevention" is a report of damage already done, and undoing it means
removing a worktree and reversing two state mutations.

- `oss worktree_add` derives and cuts `work/<wi-id>-<slug>` internally and echoes
  the worktree's absolute path. Its **stdout is its return value** — capture it,
  do not let anything else write to that stream.
- **`spec_oid` is the spec as dispatched (#434).** It goes into the same journal entry as
  the dispatch, and close compares it with the spec before every gate run
  (`work-item-close.md` §1). Only a dispatch writes it: the clarification and
  crashed-worker re-dispatches (§6) call `work_item_dispatched` alone and never refresh it,
  and a four-argument `work_item_exec` keeps the recorded value.
- **Read the branch back off the worktree; do not re-derive it.** The name git
  actually checked out is the only version that cannot be wrong.
- **`oss work_item_exec` is load-bearing beyond bookkeeping.** It persists
  `branch`, `worktree_path` and `base_sha` into state, and the work-item close
  layer reads `branch` back from there to pick its merge target. Close is invoked
  with an id and derives its scope from the id's shape — it has no slug and
  cannot re-derive the branch. Skip this call and the merge target is
  unrecoverable.
- **`target_repo` comes from state, not from you.** Any declared repo is a
  supported execution target; the assertion above is what turns an undeclared
  name — or `ai_workspace` — into a halt instead of a worktree spawned
  somewhere wrong.

  **The halt is yours to make — the lib will not make it for you**, which is
  why the assertion is the first line of the spawn block above rather than a
  note here. `_oss_repo_root` resolves `ai_workspace` as a reserved key and
  every other name against the declared repo set, so `oss worktree_add
  ai_workspace …` **returns rc 0 and creates a worktree inside the AI
  workspace** (reproduced) — the reserved key resolves exactly as a declared
  repo would, and the prose halt above is the only thing standing between a
  work item and that outcome. A genuinely undeclared name fails `oss repo_root`
  at rc 2 and is caught by the same assertion, for the different reason of
  never having been declared at all.

  Skipped, the failure is quiet and awkward to undo: the work lands in a
  worktree under the AI workspace, `.worktrees/` appears in the repo that holds
  the specs, and the spine's merge step then looks for a branch in the target
  repo that was never cut there.

**Prepare the worktree's dependencies before the handoff (#714).** A new worktree holds
only tracked files: no `node_modules/`, no virtualenv, no build output. An `auto:` command
that needs them fails in the worktree while it passes in the primary checkout. When the
item's commands need installed dependencies, install them in the worktree with the
project's own install command (for example `npm ci`). Never link the primary checkout's copy:
a virtualenv with an editable install points the worktree's tests back at the primary
checkout's source, and concurrent items would share one writable tree. Then
`git -C "$wt" status --porcelain` must print nothing. Name the set-up in the handoff's §4.
The step is safe to repeat, and re-entry repeats it (below).

---

## 4. Author the handoff

One `handoff.md` per work item, authored **against
`references/handoff-contract.md`** — its twelve sections, in order, no template
rendering. It goes in the work item's own directory, beside the `spec.md`
`plan-spine` wrote:

```text
<ai-workspace>/docs/specs/<release-id>/<spine-id>-<spine-slug>/work-<wi-id>/handoff.md
```

**Carry the spec's start-GREEN lines into §4 (#715).** For each `Expected GREEN at start:`
line in the item's spec, write a recorded override into the handoff's §4: the AC and the
spec's reason. The RED gate then honours it at dispatch 1, not after a clarification
dispatch.

**Do not pre-place a `report.md`.** The implementer authors it, and its own
contract tells it there is no placeholder to fill and to prefer Edit over Write on
a file that already exists. An orchestrator-created empty file puts the worker in
conflict with its own binding prose at the moment it writes the report. Nothing in
its pre-flight expects the file to exist.

---

## 5. Dispatch

**This step, and only this step, has two forms.** Which one you are in was
decided by the command that started you and never changes mid-spine:

- **`/run-spine <spine-id>`** — the default, below. The lane dispatches its own
  nested implementer per work item.
- **`/run-spine <spine-id> --external-executor`** — the caller supplies the
  execution procedure. **Read `references/external-executor.md` and follow it**
  instead of the block below; it owns the round sequencing, the two records, the
  validation and the halts. Come back here for §6 and §7, which it does not
  change. That mode calls no subagent and never falls back to one.

**Before every dispatch, count it.** Read `oss get
'.work_items[] | select(.id=="<wi-id>") | .dispatches // 0'`. At 3 or more, do
not dispatch — escalate as §6's cap says. Otherwise run `oss
work_item_dispatched <wi-id>`, then dispatch. This holds for the first run,
every clarification re-dispatch and every broken-envelope retry — except under `--detach`,
where the lane counts nothing and the caller counts each execution
(`external-executor.md` §2b).

### The default dispatch

```text
Task(subagent_type="ossify:implementer-agent", prompt=<invocation block naming the absolute handoff path>)
```

(OMP: task with agent "implementer" — same handoff path in, same JSON out)

**Never pass the Task tool's `isolation: "worktree"`.** The worktree already
exists — you created it in §3, in a different repo, at a path the handoff names.
Letting the harness make its own would run the item somewhere the merge never
looks and silently discard the work.

The prompt names the absolute handoff path and nothing else load-bearing. Every
behavioural rule the worker needs is in its system prompt (SKILL.md) and in the
handoff; restating rules in the invocation block creates a third copy that drifts
from both.

---

## 6. Handling the return

Two shapes come back on the normal path (`references/returns.md`). Route on
`mode` — and treat anything that is neither as a third, explicitly handled case
(below), never as a shape to be salvaged.

**`gaps-surfaced`** — pre-flight stopped the run and no work was done.

1. Surface the gaps to the user **grouped blocking-first**; nice-to-haves ride
   along so one round-trip answers both.
2. Capture the answers.
3. **Append a `## Clarifications` section to the handoff doc.** Not to the
   invocation block, not to the spec. The worker re-reads the handoff end to end
   on every dispatch, and that re-read is exactly how the resolutions reach it —
   a fresh subagent has no memory of the previous attempt.
4. Re-dispatch.

**The 3-iteration cap is orchestrator-side and binding** (spec §6): after three
total dispatches of one work item with no `complete` return, **stop**. Surface the
accumulated gap list and escalate to the user — the item is under-specified and
another round-trip will not fix it. **The worker never counts iterations**; it
cannot, because each dispatch is a fresh context that has no idea it is the third.
The count lives in state (`work_items[].dispatches`, §5), so it survives a
respawned session — a molt handoff mid-round does not reset an item's cap.

**`complete`** — the execution loop ran to the end. **First, make the report a
file (#978).** Claude Code refuses a subagent's Write of `report.md`, so the
implementer returns it as `report_text` (`references/returns.md` §2). When the
return carries `report_text`, write it with Write to `report_path` verbatim — no
edit, no note inside it — replacing any file there, and print
`report: <wi-id> written by the lane from report_text`. Only to the `report.md`
beside this item's `handoff.md`: any other `report_path` is a halt naming it. A
return with no `report_text` and no file at `report_path` halts:
`halt: <wi-id> returned complete with no report at <report_path> and no report_text`.
That is not a Layer 2 failure, and not a re-dispatch: the work is staged, so Gate
3 would refuse one. Both halts, and a session that ended before this Write,
leave a staged item with no report; recover it as below.

**Recovering a staged item with no report (#978).** Never re-dispatch it.
Re-create `report.md` beside the item's `handoff.md`: from `report_text` verbatim
if you still hold it, else by hand from the staged diff
(`git -C <worktree> diff --cached`), the handoff and the spec, with
`references/report-contract.md`'s ten sections, re-running the handoff's
verification commands for §3 and §5 and stating in §10 that the report was
re-created. Then re-enter: a clean staged result at its base with a report reads
`close-finished` (§2b), and close's gate runs in full.

Then hand the item to the work-item
close layer (`close`), which runs the gate, commits in the worktree, and merges
`work/<wi-id>-<slug>` into the spine branch you are parked on.

`complete` fires **even when verification failed** — `mode` reports the loop, not
the AC outcomes. Read `summary` and the report before deciding anything; a
`complete` return is not a green gate, and the gate is close's to run, not yours.

**Anything else — malformed, crashed, or timed out.** A payload that is not one
of the two shapes (unparseable, missing `mode`, a `mode` outside the enum, an
empty return, a subagent that died mid-run) is a **third case with its own
handling**, not a `complete` with rough edges:

1. **Do not parse around it.** Do not infer the outcome from prose in the
   payload, do not go read the worktree to decide whether it "basically
   finished", and do not treat a missing `report_path` as a green gate. A broken
   envelope means you do not know what state the work item is in, and guessing
   is how unverified work reaches a merge.
2. **Check the worktree BEFORE re-dispatching** — a crash after the worker
   started editing leaves it dirty, and a re-dispatch cannot recover from that:

   ```bash
   [ -z "$(git -C "$wt" status --porcelain)" ] || { echo "halt: <wi-id>'s worktree is dirty after a broken return"; exit 1; }
   ```

   **Two different dirty worktrees reach you by two different routes, and only
   one of them lands here.** A worktree that was *already* dirty when the worker
   reached pre-flight never produces a broken envelope at all: Gate 3 requires a
   clean worktree and SKILL.md §10 forbids the worker from tidying one, so it
   returns a **well-formed `gaps-surfaced`** envelope and you are in §5, not
   here. The halt above is for the other route — a worker that crashed
   **mid-edit**, leaving the worktree dirty *and* returning no payload. That is
   the case this step exists for, and it does fire.

   Re-dispatching into it cannot converge: every retry fails Gate 3 for a
   condition no clarification can answer, and burns the 3-dispatch cap. **Halt
   here and surface the dirty worktree to the user** — respawning it or keeping
   the partial work is their call, and neither is yours to make silently.

3. **Only if the worktree is clean, re-dispatch once** on the same handoff,
   unchanged. A crash or timeout with nothing written is usually transient, and
   the worker re-reads the handoff end to end anyway.
4. **If the second dispatch also returns a broken envelope, halt and surface it**
   to the user with the raw payload. This counts against the 3-iteration cap
   like any other dispatch.

The worktree is left exactly as the worker left it. Do not clean it up — its
state is the evidence for diagnosing what happened.

---

## 7. The round barrier

**Every work item in a round reaches `complete` before the next round starts** —
strict-order verification, spec §6. An `abandoned` item was never dispatched and
is not waited for (§3). A work item still `active` at the barrier
**halts the round**; name it and stop. An `in-flight` item (§2b) is not a
halt: its merge is pending, not failed. Once the round's other items are
through, the lane ends with a report naming the item and its PR (`pr_url`); re-run `/run-spine` once the PR has merged and the
spine branch is fast-forwarded.

The barrier is what the DAG's edges bought. Round *K+1*'s items were declared to
depend on round *K*'s, so starting one early means building against a seam that is
not merged yet — which fails as a confusing compile error inside a worker that has
no way to know why.

Items *within* a round are parallel by construction, and dispatching them
concurrently is fine. Their merges are not parallel: each one lands on the spine
branch through close, one at a time, and a conflict halts (never auto-resolve).

**Returns are processed in declared decomposition order, never arrival order.**
§3 says this about the *spawn* step, where it is nearly free — no returns exist
yet. It binds here, where it costs something: when a concurrent round's items
come back out of order, **work item N+1 is not verified, closed or merged until
N is fully committed and merged**. Hold the early return and wait.

**The barrier is identical in both dispatch forms.** An external caller may run
a round's items concurrently — that is expected, not a variation — and it
changes nothing here: the returns still queue into close in declared order, the
merges are still serial, and the next round still waits.

This is spec §6's strict-order verification, and dispatching concurrently is
exactly what makes it easy to violate — an orchestrator that closes items as
they arrive is following §3 to the letter and breaking the contract anyway. The
DAG guarantees the items do not depend on each other *logically*; it says
nothing about two of them touching the same file, which is what serial merges
onto one spine branch protect against.

**The barrier is not an intake point.** A spine's work items are fixed once its
first round has started (`plan-spine` SKILL.md §2). A request that arrives while
the rounds run — from the operator, another project, or a review — goes to the
intake queue (`plan-spine/references/intake-and-ledger.md` §1) or to
`/ossify:patch`. It never becomes a work item, an AC or a round here, however
small. The spine's own planned scope keeps its two paths, both unchanged: §7 fix-up
replans of a failed round (`plan-spine` SKILL.md §7) and its own demo-line
amendments (`plan-spine` SKILL.md §8e).

**A round that lands the code a demo line tests may activate that line here.**
The lines a spine authored are `planned` until its close activates them, so a line
whose code has just merged is one its own close will run anyway; the barrier may run
`oss ledger_activate <line-id>` for it early, and the operator may too. Optional
and never a gate: a line left `planned` is activated by its own close like every
other, and a line another spine authored is not this barrier's to activate.

**When the final round clears this barrier, the spine is ready for
`/close <spine-id>`.** That is where this lane ends — hand the baton over
explicitly rather than stopping silently.

---

## 8. What is not covered by any test

Stated plainly so nobody infers coverage that does not exist:

**The dispatch loop, the 3-iteration cap and the round barrier are prose
contracts with no executable surface.** Nothing asserts that a fourth dispatch
does not happen, or that a round waits for its stragglers. No eval fixture
exercises them either.

The mechanical half *is* covered — `tests/test-worktree.sh` asserts that a
worktree spawned off the spine branch starts at the spine branch's tip, that two
work items in one spine get distinct branches and distinct worktrees, and that a
work-item branch merged while its target repo is parked on the spine branch is
**reachable from the spine branch afterwards** (with a negative control proving
the assertion fails when it is parked anywhere else).

A bash test asserting agent behaviour here would be testing a fixture, not the
contract. The honest statement is that the judgment half is uncovered.

The re-entry classification is covered: `tests/test-spine-inventory.sh` builds
each state in real git repos and asserts its route, and runs the §2b read-out
and cut-missing blocks. The round mapping (§2b step 2) and the per-route repairs
(step 4) are prose with no executable surface.

---

## 9. Anti-patterns

- **`git branch` without the checkout** (§2). The whole failure chain is rc 0.
- **Reading rounds from `releases[].spine_dag`**, or re-deriving them (§1).
- **Skipping `oss work_item_exec`** because the worktree path is already in
  scope. Close cannot recover the branch without it (§3).
- **Passing `isolation: "worktree"` to Task** (§5).
- **Appending clarifications anywhere but the handoff** (§6).
- **Counting iterations in the worker**, or expecting it to (§6).
- **Pre-placing `report.md`** (§4).
- **Closing a `complete` return before its `report_text` is a file** (§6).
- **Starting round *K+1* with an `active` item behind you** (§7).
- **Adding a work item or an AC at the barrier** for a request that arrived
  mid-spine (§7).
- **Committing inside the worktree yourself.** The implementer stages; the
  work-item close layer commits, after its gate. A commit here is a commit that
  skipped the gate.
- **Re-cutting or half-reusing an existing spine branch** instead of taking
  §2b (§2).
- **Dispatching without counting it** (§5).
