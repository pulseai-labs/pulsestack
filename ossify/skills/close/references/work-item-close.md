# Work-item close — the innermost layer

Depth for SKILL.md §4. Six steps in **binding order**: each step's output is the
next one's input, so running them out of order does not fail — it runs the gate
against paths nobody resolved and merges a branch nobody checked.

This layer is reached two ways and must work identically in both: from the
execution lane, holding a `complete` return (`work-item/references/round-orchestration.md`
§6), and standalone as `/close <wi-id>` with nothing else in scope.

---

## 1. Resolve the three absolute paths

You need **`spec.md`**, **`report.md`** and the **worktree**. Nothing in state
holds a spec path, a report path, or a slug — a work item is
`{spine, title, target_repo, status, created_at, id, branch, worktree_path,
base_sha, spec_oid}` — so the docs paths are reconstructed, and the reconstruction is where
this layer most easily goes silently wrong.

**The worktree is the easy one**: state holds it, written by the execution lane.

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

```bash
wi="<work-item id>"
st="$(oss get ".work_items[] | select(.id==\"$wi\") | .status")"
if [ "$st" = "abandoned" ]; then
  # The dispatched-item evidence is FOUR fields, not three (#673 F3): branch,
  # worktree_path, base_sha - AND the dispatches count. An item whose dispatch
  # was counted and then died before work_item_exec records no exec field at
  # all, so a three-field read called it a clean withdrawal; the count is the
  # surviving proof it was dispatched.
  rec="$(oss get ".work_items[] | select(.id==\"$wi\") | [.branch, .worktree_path, .base_sha, (if ((.dispatches // 0) > 0) then (\"dispatches=\" + (.dispatches | tostring)) else null end)] | map(select(. != null) | tostring) | join(\", \")")"
  if [ -n "$rec" ]; then
    echo "close: $wi is abandoned AND records a dispatch field ($rec) - that pair is the drift doctor's §5 bullet reports, not a clean withdrawal, and it is NOT the skipped-work_item_exec case below: the worktree the record names may hold real work, so nothing here may skip the item as 'nothing to close'. The withdrawal is the half that is wrong, so repair the RECORD and let the work land: \"oss\" work_item_status $wi planned, then resume the round the record describes (work-item/references/round-orchestration.md §2/§3) so it lands or reports its own halt - and where it cannot run, carry the work into a NEW spine: \"oss\" spine_add <release> <name> <class> <target-repo>, then \"oss\" work_item_add it there (plan-spine/references/decomposition.md §1's whole-spine arm) - halt"
    exit 1
  fi
  echo "close: $wi is abandoned and records no dispatch field at all, which is what 'withdrawn before any dispatch' means in state - there is nothing to close. This is NOT the skipped-work_item_exec case below, and nothing should be reconstructed for it: spine close skips an abandoned item, and the withdrawal's own two obligations live in DIFFERENT owners: the demo-ledger amendment it owes is plan-spine/references/decomposition.md §1, and the repo armed for its spine - restore its checkout, or record it as parked - is spine-close.md §3, which this standalone route never reaches. To reverse the withdrawal: \"oss\" work_item_status $wi planned - but if this item's spine is ALREADY closed, that alone is not the recovery: un-withdrawing leaves a planned item inside a closed spine, and release close's tag selector takes any non-abandoned item whose spine is closed, so a later release close would tag a repo whose work was never dispatched or landed. Reopening the spine does NOT re-enable it: spine close has already landed that spine's branch in every hosting repo, and round-orchestration.md §2's re-entry arm would route the un-withdrawn item onto a branch nothing merges again. Carry the work into a NEW spine instead - \"oss\" spine_add <release> <name> <class> <target-repo>, then \"oss\" work_item_add it there (plan-spine/references/decomposition.md §1's whole-spine arm) - halt"
  exit 1
fi
wt="$(oss get ".work_items[] | select(.id==\"$wi\") | .worktree_path")"
[ -n "$wt" ] && [ "$wt" != "null" ] && [ -d "$wt" ] \
  || { echo "close: no recorded worktree for $wi - halt"; exit 1; }
```

**Test for `null`, not just emptiness.** `oss get` is `jq -r`: a field that is
absent or JSON-null prints the four characters `null`, which is non-empty and
passes `[ -n … ]`. Every state read in this layer is guarded that way, and the
merge target in step 4 is the one where it matters most — `git merge null`
resolves nothing and the guard that was supposed to catch it already passed.

A missing `worktree_path` means the lane skipped `oss work_item_exec` — or
recorded a half-write, `work_item_exec <wi> "" "" <sha>`, which journals `base_sha`
alone and names no worktree either. Both are a
halt, not something to reconstruct: `oss worktree_resolve <target_repo> <wi>`
will happily echo a conventional path whether or not it is the one this item was
built in. **The block tests one other cause first**: an item withdrawn before any
dispatch is `abandoned`, and *that* is why it has no worktree — it was never
dispatched, so there is nothing to reconstruct and nothing to close. That is
three cases, not two: **an `abandoned` item that still records a dispatch field** —
`branch`, `worktree_path`, `base_sha`, or a `dispatches` count above zero —
was dispatched and *then* withdrawn (the
pair `references/state-inspection.md` §5 reports as drift, and the state a
pre-1.12 journal can hold), so its worktree may be real work that no close path
skips for it: the block reads those fields and names them, sends the operator to
repair the record and resume the round, and keeps the new-spine route for where
the round cannot run. An `abandoned` item with **no** recorded field is the plan
that deliberately dropped the item — the case this layer must not reconstruct.
The three want different actions (a broken lane, a dropped item, a dispatch that
has to land), which is why the record is read before the diagnosis rather than
after it.

### Route A — in the round flow

The report's *content* reaches close only as a file — a `report_text` in the
return was written to `report_path` by the lane first
(`work-item/references/round-orchestration.md` §6) — and
`report_path` **is** in the return, guaranteed absolute and ending in `report.md`
(`work-item/references/returns.md` §2). `spec.md` is its sibling: `work-item/SKILL.md`
§7 authors the report next to `spec.md` and `handoff.md` in the work item's
directory.

```bash
report="<report_path from the complete return>"
spec="$(dirname "$report")/spec.md"
```

Route A gives you the paths and nothing else. Step 4 additionally needs the
**spine branch**, which a round-flow caller already holds — it cut and checked it
out before round 1 (`work-item/references/round-orchestration.md` §2). A standalone caller has neither,
and recovers both from Route B.

### Route B — standalone

Reconstruct from the id alone. The directory shape is the one the execution lane
writes the handoff into (`work-item/references/round-orchestration.md` §4) — the two must stay
byte-identical, because a drift between them has no runtime signal:

```text
<ai-workspace>/docs/specs/<release-id>/<spine-id>-<spine-slug>/work-<wi-id>/
```

The release and spine ids come out of
`oss id_parse`'s numeric components (`routing.md` §2); the **spine slug** does
not — nothing persists one (spines store `name`, work items store `title`), so it
is recovered by globbing the spine directory, exactly as the execution lane
recovers it for the spine branch.

```bash
parts="$(oss id_parse "$wi")" || parts=""
rel_id="r$(printf '%s\n' "$parts" | awk '{print $2}')"
spine_id="$rel_id.s$(printf '%s\n' "$parts" | awk '{print $3}')"
rel_dir="$(oss release_dir "$rel_id")"   # ABSOLUTE, ai_workspace-rooted

matches="$(find "$rel_dir" -maxdepth 1 -type d -name "$spine_id-*" 2>/dev/null)"
n="$(printf '%s\n' "$matches" | grep -c . || true)"
[ "$n" -eq 1 ] || { echo "close: expected exactly one spine dir for $spine_id, found $n - halt"; exit 1; }

spine_dir_abs="$matches"
spine_slug="$(basename "$spine_dir_abs")"; spine_slug="${spine_slug#"$spine_id-"}"
wi_dir="$spine_dir_abs/work-$wi"
spec="$wi_dir/spec.md"
report="$wi_dir/report.md"
```

Three things that look like shortcuts and are not:

- **`oss spine_dir` returns a RELATIVE path** — `docs/specs/<rel>/<spine>-<slug>`
  — and it takes the slug as an argument, so it cannot *find* the directory. Once
  the glob has recovered the slug it re-composes the same relative path, which
  makes it a useful cross-check against `$spine_dir_abs`; it is never the way in.
- **Do not recover the slug from `work_items[].branch`.** That carries the
  *work-item* slug (`work/<wi-id>-<slug>`). Feeding it to a spine path builds a
  directory name that has never existed.
- **`$n` must be exactly 1.** Zero means the spine was never planned here; two
  means a rename left a stale directory, and `head -1` would pick one at random.

### Both routes end the same way

```bash
[ -f "$spec" ] || { echo "close: no spec.md for $wi at $spec - halt"; exit 1; }
```

**A missing or wrong spec path is a halt, named.** `oss verify_acs` returns rc 2
on a spec it cannot find, and a silently wrong path therefore fails the gate for
the wrong reason — the run reports a verification problem when what it has is a
path problem, and the recovery menu sends someone to fix code that is fine.

Carry `$spec`, `$report` and `$wt` forward as absolute paths. Nothing below
re-derives them, and nothing anywhere in this layer `cd`s (SKILL.md §3).

### The spec is the one dispatched (#434)

The work-item contract forbids an implementer to edit `spec.md`, and the gate below judges the
work against it. Round orchestration §3 records the spec's blob id in state when it dispatches
(`spec_oid`); compare it with the spec as it is now, **before every gate run**. This block runs
on every route that reaches §2: plain close, `--pr`, `--verdict` and the external re-entry all
run §1, and the `finish-merge` row of `round-orchestration.md` §2b runs it itself.

```bash
now_oid="$(oss spec_oid "$spec")" || { echo "close: cannot hash $spec for $wi - halt"; exit 1; }
rec_oid="$(oss get ".work_items[] | select(.id==\"$wi\") | .spec_oid")" || { echo "close: cannot read $wi's recorded spec value from state - halt"; exit 1; }
spec_note=""
if [ -z "$rec_oid" ] || [ "$rec_oid" = "null" ]; then
  spec_note="no dispatch-time spec value for $wi: the spec check did not run"
  echo "$spec_note"
elif [ "$now_oid" != "$rec_oid" ]; then
  echo "halt:spec-changed - $wi's spec.md is $now_oid, the spec dispatched was $rec_oid. No verifier ran, nothing merged, no PR opened. Two ways out, both yours: (1) the spec should not have changed - restore the dispatched spec (find it in the AI workspace's git history, git log -- $spec, or in the planning record), then re-run close; (2) the spec changed on purpose - \"oss\" work_item_status $wi planned, save or discard the staged work, remove the item's worktree, and re-run the round so round-orchestration.md §3 dispatches it again and records the new spec's id. There is no route that refreshes the recorded value in place - halt"
  exit 1
fi
```

- **Equal** continues. **No `spec_oid` in state** is a visible note, not a halt: an item dispatched
  before 1.36.0, or by a four-argument `work_item_exec`, still closes. `$spec_note` is carried into
  `verify.md` (§2), so a reader of the gate record sees that the check did not run.
- **A repaired dispatch records the spec as it was at repair** (`round-orchestration.md` §2b's
  `adopt` and `halt:base-unknown` rows say so when they write it); it is the one stated limit.

---

## 2. The gate

Run the four-layer implementation gate per **`references/impl-check.md`**, using
the `$spec`, `$report` and `$wt` resolved above. Never a bare placeholder: a
gate invoked on `<spec path>` runs against a file called `<spec path>`.

**Layer 4 needs one input Layers 1–3 never touch: `handoff.md`.** `$spec`,
`$report` and `$wt` are already proven to exist by step 1 and Layer 1/2's own
reads; `handoff.md` (`$(dirname "$spec")/handoff.md`) is not, and nothing below
validates it before use. Check it exists and is readable **before** running the
lenses — a missing or unreadable handoff is a halt, named
(`close: no handoff.md for $wi at <path> - halt`), not a silent empty-findings
result from a pass that never opened the file. Skipping this check does not
fail loudly: a read that never happened still produces a clean-looking
findings list, and the gate reports green having verified nothing.

**Without `--verdict`, after Layers 1 and 2, the close dispatches `ossify:verifier-agent` for Layers 3 and 4 and the §4c mutation check**
(`references/impl-check.md`), through the host's agent tool; on OMP, `task` with
`agent: "verifier"` (omp-roles 0.11.1+), not the default `task` agent. Its prompt names
absolute `$spec`, `$report`, `$wt`, the `handoff.md` path, the patterns file
(`03-code-patterns.md`, resolved as Layer 3 resolves it, or `absent`) and the
diff mode: `staged`, or `committed <base_sha>..HEAD` on a `--pr` resume (§4a).
When `OSSIFY_VERIFIER_MODEL` is non-empty (for example in a `settings.json` env block),
pass it as the tool's `model`; set-but-empty is the same as unset.
The value is whatever the host's agent tool accepts as `model` (on Claude Code,
an alias such as `sonnet` or a full model id, not a closed list).
Unset or empty, the registration's `model: inherit` applies; print `verifier model: inherited
(same as this session) — set OSSIFY_VERIFIER_MODEL to separate it`.
A tool refusal naming the model halts and names the value; a dispatch refused for lack
of a `Task` grant or in a subagent context goes inline, not a model fallback.

On OMP, instead of the model steps above, because `task` takes no model: the model is the config's `task.agentModelOverrides.verifier`, else the session's. Print
`verifier model: from omp config (task.agentModelOverrides.verifier), else this session's`, and say so if `OSSIFY_VERIFIER_MODEL` is non-empty, since it does not apply there.

Record the worktree before dispatch and compare after return; the reference is yours,
never the agent's. For an inline §4c pass, run the same fingerprint block immediately
before §4c and after restoration, with the same halt.
The fingerprint sees untracked paths but not their content, and does not see ignored files.
On a fingerprint halt, name every non-null `copy` → `file` pair from those keys and
point to `git -C "$wt" status --short`, including files generated by the test run.
Inline records each mutation's `file` and `copy` as it saves the copy in §4c;
its fingerprint halt names those pairs. Recovery is `impl-check.md` §6, never automatic.

```bash
before=""   # empty before dispatch or inline §4c; after, the value printed then
t="$(git -C "$wt" write-tree)" && s="$(git -C "$wt" status --porcelain)" && d="$(git -C "$wt" diff --binary)" \
  || { echo "close: cannot fingerprint $wt for the verifier - halt"; exit 1; }
now="$(printf '%s\n%s\n%s\n' "$t" "$s" "$d" | git hash-object --stdin)"
if [ -z "$before" ]; then echo "verifier identity: $now"
elif [ "$now" != "$before" ]; then echo "close: verifier left $wt changed - halt"; exit 1; fi
```

The agent returns one JSON object (`agents/verifier-agent.md`): `verified`,
or `refused` with a reason. A `refused` return, or anything not in that shape,
is a halt naming it. Each mutation entry must have `test`, `mutation`, `result`,
`evidence`, `file` and `copy`; a missing key halts, naming it.
`file` and `copy` must both be absolute paths, or both `null` only for `undetermined`
when no mutation was applied; otherwise halt naming the invalid key.
This `file`/`copy` check applies to agent returns and inline records only; `--verdict` is unchanged.
Apply every verdict the pass returns — `[rule]` (Layer 3), `[fidelity]` (§4b),
`[mutation]` (§4c): any one halts, and the halt names all of them.
Print `verifier: ossify:verifier-agent on <model>` using the return's `model`; when a
non-empty `OSSIFY_VERIFIER_MODEL` was passed, also print that passed value.

**With `--verdict <file>` the verdict is a caller's, and the close dispatches nothing.**
A baton `verify` stage has already run the pass in a seat of the operator's choosing.
Run Layers 1 and 2 as above; dispatch no `ossify:verifier-agent` and run no
before/after fingerprint. Read the file: it is one JSON object with `mode: verified`
and the keys `model`, `agent`, `work_item_id`, `identity`, `rule`, `lenses`,
`mutation`. Anything else, or a missing key, is a halt naming the key, and
so is an `identity` that is not a hex digest — it is pasted into the shell below. A
`work_item_id` other than `$wi` is `close: verdict is for <id>, not $wi - halt`.
Then recompute the worktree identity with the same three commands, now that no
mutation is pending:

```bash
vid=""   # the verdict's identity key, as the file carries it
t="$(git -C "$wt" write-tree)" && s="$(git -C "$wt" status --porcelain)" && d="$(git -C "$wt" diff --binary)" \
  || { echo "close: cannot fingerprint $wt for the verdict - halt"; exit 1; }
now="$(printf '%s\n%s\n%s\n' "$t" "$s" "$d" | git hash-object --stdin)"
[ "$now" = "$vid" ] || { echo "close: verdict identity $vid does not match $wt now ($now) - the item changed after verify - halt"; exit 1; }
```

A mismatch is a halt: the item changed after the verdict was written. On a `--pr`
resume (§4a: empty index, HEAD already past `$base_sha`) the commit itself moved the
tree, so a verdict written before it always lands here; say so:
`close: $wi is already committed; a verdict written before the commit cannot match - re-run /close $wi --pr without --verdict, or with a verdict written against the committed tree - halt`.
If the identities match, apply
`rule`, `lenses` and `mutation` exactly as the agent's return is applied (the same
tags, the same `verify.md`, the same correction packet), and print
`verifier: <agent> on <model>` from the file. Without `--verdict` nothing in this
section changes.

Under `--verdict` the verdict is the pass, and the close runs none of §4, §4b or §4c itself, inline or dispatched. Without it, **where no agent can be dispatched, the close runs the pass itself** — Codex,
OMP with no `verifier` in `task`'s agent list or with omp-roles older than 0.11.1, a subagent context, a refused `Task` grant. Apply §4, §4b and §4c in this
session, from the diff and never from report §5, and print
`verifier: inline — <host or why>` in the close summary. Not a halt. **Inside an
`--external-executor` lane closing its own items** Layers 3 and 4 run in this
session and no mutation check runs: the caller's verifier owns it
(`work-item/references/external-executor.md` §6). A `--detach` caller's later
`/close` is outside the lane, so it dispatches unless it passes `--verdict`.

Apply the §4b verdict rule to the findings: an undeclared `fidelity` finding
fires the `[fidelity]` halt. **Every completed verifier pass writes
`<work-item-dir>/verify.md`** — `$(dirname "$report")` on Route A, `$wi_dir` on
Route B — and echoes it in the close summary: the `verifier:` line, one result
line per layer (L1, L2, L3, L4, mutation; `not run` in an `--external-executor`
lane), then `$spec_note` from §1 when it is non-empty (a line of its own, so it is never
read as a finding and never begins with a verdict tag), then the findings and every mutation
result. An evidenced halting `stayed-green` line begins `[mutation]`; `red` and `undetermined`
are untagged `mutation: <result> <test> - <mutation>` lines.
The mutation layer-result line is `layer mutation: <summary>`.
Each halting verdict is one line that begins with its tag, or with `- `
and then the tag (`[fidelity] <file>:<line> - <claim>`); only a halting finding
is tagged `[fidelity]`, a declared one is written as `fidelity`. The summary is a message,
and in an `--external-executor` lane it belongs to the lane's session, so this
file is the item's durable gate record (#980). When the pass halts, on any tag,
`[rule]` included, the whole set is written with every halting verdict in it.
**A rejection is recorded durably (#673 C2, #971)**, because a staged
worktree after a rejection is byte-identical to a `close-finished` result otherwise — a fresh session's
re-entry would hand the rejected result back to the gate, and a stochastic
pass could accept it without the correction ever running. The re-entry
inventory reads a `[rule]`, `[fidelity]` or `[mutation]` line in `verify.md` as
exactly that record (route `halt:close-rejected`).

**Every completed verifier pass overwrites `verify.md`, even when there are zero
findings — never leave a stale one.** A retry replaces the old findings; code-review.md
reads the file as current evidence, not a fresh judgment. Overwriting also clears the
rejection record, so only a re-verified result reads as recovered.

Green → step 3. Anything else → step 5.

---

## 3. Prove there is something to commit

The gate ran against the **working tree**; the commit runs against the **index**,
and they are not the same thing.

```bash
staged="$(git -C "$wt" diff --cached --name-only)"
[ -n "$staged" ] || { echo "close: gate is green but the index is empty in $wt - halt"; exit 1; }
```

The implementer also reports `stage_status` — `all_staged`, `partial`, or `none`
(`work-item/references/returns.md` §2):

| `stage_status` | Action |
|---|---|
| `all_staged` | proceed, once the index check above passes |
| `partial` | **halt** unless the report explains it in its blockers-and-advisories section |
| `none` | **halt** |

**Never `git add` on the implementer's behalf.** Staging is its job; a silent
re-stage hides the discrepancy and commits whatever the worktree happens to hold,
including files the gate never saw.

---

## 4. On green — commit, then merge

The commit boundary is the orchestrator's: the implementer stages, this layer
commits. The merge is what actually moves the work onto the spine.

```bash
# The item's OWN repo, read from state - never a bare "canonical". A spine can
# host items across several declared repos (round-orchestration.md §2 cuts the
# spine branch in every one of them); this layer closes ONE item, so it targets
# exactly the repo that item recorded at work_item_add time.
target_repo="$(oss get ".work_items[] | select(.id==\"$wi\") | .target_repo")"
# `ai_workspace` BEFORE the resolver, because the resolver SUCCEEDS on it: it is
# the reserved alias for the process workspace, so treating resolution as proof
# of a hosting repo would route this close's commit and merge into the AI
# workspace itself. `oss work_item_add` refuses the key now, but a record
# written before that guard - or hand-edited state - still reaches here.
[ "$target_repo" != "ai_workspace" ] \
  || { echo "close: $wi targets 'ai_workspace', which is the process workspace, not a hosting repo - no ceremony governs that repo and nothing may be merged into it - halt"; exit 1; }
repo_root="$(oss repo_root "$target_repo")" || { echo "close: $wi targets undeclared repo '$target_repo' - halt"; exit 1; }

# The merge target comes from STATE, written by the execution lane.
wi_branch="$(oss get ".work_items[] | select(.id==\"$wi\") | .branch")"
[ -n "$wi_branch" ] && [ "$wi_branch" != "null" ] \
  || { echo "close: no recorded branch for $wi - halt"; exit 1; }

# The spine branch: in the round flow it is already in scope; standalone,
# recompose it from the slug step 1 recovered.
spine_branch="$(oss branch_name "$spine_id" "$spine_slug")"
head_branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)"
[ "$head_branch" = "$spine_branch" ] \
  || { echo "close: $target_repo is on '$head_branch', not '$spine_branch' - halt"; exit 1; }

git -C "$wt" commit -m "<message>"
wi_sha="$(git -C "$wt" rev-parse HEAD)"

git -C "$repo_root" merge --no-ff "$wi_branch" -m "merge $wi" || { echo "close: merge conflict - halt"; exit 1; }
git -C "$repo_root" merge-base --is-ancestor "$wi_sha" HEAD \
  || { echo "close: merge reported success but $wi_sha is not reachable from HEAD - halt"; exit 1; }

oss work_item_status "$wi" complete
```

**Read the branch from state; never re-derive it from a slug.** This layer is
invoked with an id only and derives its scope from the id's shape — it has no
work-item slug, and none is persisted. The execution lane writes the branch it
actually created into `work_items[].branch` precisely so this step can read it
back. `oss work_item_branch "$wi" "$slug"` needs a `$slug` that does not exist
here; it is the id grammar's name generator, not a lookup.

**Verify the merge target before merging.** `git merge` lands on whatever
`$target_repo` has checked out. The execution lane parks **every repo hosting
one of the spine's items** on the spine branch for the whole spine
(`round-orchestration.md` §2); if `rev-parse --abbrev-ref HEAD` in *this item's*
repo says anything else, **halt** — a merge onto the wrong branch **succeeds
silently at rc 0**, the work never reaches the spine, and the first thing that
notices is a cumulative demo measuring a tree assembled by accident.

**Status is set last, after the merge is verified landed.** Spine close reads
`complete` as "this item's work is on the spine branch" — it is the only signal
of that the status enum can carry (`planned|active|complete|abandoned`). Setting
it before the merge means a conflict halt leaves state asserting a merge that
never happened, and the next spine close believes it. **Work-item close never
sets `abandoned`.** That status belongs to an item withdrawn before any dispatch
(`plan-spine/references/decomposition.md` §1); an item that reached this
ceremony was dispatched, and its close lands or halts.

**A merge conflict halts.** Surface the conflicted paths verbatim and stop. Never
auto-resolve, never `--abort` on the user's behalf, and never `-X` a strategy
option to make it go away. If the operator says *resolve it*, the discipline is
`merge-conflict-resolution.md` — hunk by hunk, by each side's recorded intent.
Resuming after the human resolves means finishing
*this* step — the merge and its reachability check, then the status — not
re-running the layer: the commit already landed on the work-item branch, so a
re-run halts at step 3 with an empty index and reports the wrong problem.

**This merge is not optional bookkeeping.** Without it the commits live only on a
branch that spine close cannot delete — `oss worktree_remove` refuses an unmerged
branch (rc 8) — so the round halts at cleanup, *after* the cumulative demo has
already reported green against a tree in `$target_repo` that never received the
work.

---

## 4a. PR mode — `/close <wi-id> --pr`

Opt-in, for a caller that merges the item's PR itself. Steps 1 and 2 run
unchanged (paths, the four-layer gate), and so do step 3's `stage_status` table
and §4's `ai_workspace` and branch-from-state guards. Step 3's empty-index halt
is replaced by the commit-or-resume test in the block below. What differs is
the end: the commit is pushed and a PR opened into the spine branch, and
**nothing is merged here**. The default `/close <id>` is §4, untouched.

**The remote leg is checked before the commit.** `origin` must resolve, and
the spine branch must be on it — the item's PR needs it as the base. The lane
never pushes it (`round-orchestration.md` §2a), so the first `--pr` close of a
spine finds it absent (`ls-remote` rc 2) and pushes it, opening no PR. Spine
close is unaffected: its resume probe looks for a PR headed by the spine
branch, never for the branch, so with none open it pushes the branch again and
opens the spine PR as usual (`spine-close.md` §3). No `origin`, a failed push,
or an unreadable remote halts, naming which: **never a local merge** —
the work would land on the spine without the PR the caller is
waiting on (the #339 rule). `gh` takes the origin URL itself as `--repo`, and
parses it, keeping the host — this layer never takes the URL apart.

```bash
target_repo="$(oss get ".work_items[] | select(.id==\"$wi\") | .target_repo")"
[ "$target_repo" != "ai_workspace" ] \
  || { echo "close: $wi targets 'ai_workspace', which is the process workspace, not a hosting repo - halt"; exit 1; }
repo_root="$(oss repo_root "$target_repo")" || { echo "close: $wi targets undeclared repo '$target_repo' - halt"; exit 1; }
wi_branch="$(oss get ".work_items[] | select(.id==\"$wi\") | .branch")"
[ -n "$wi_branch" ] && [ "$wi_branch" != "null" ] \
  || { echo "close: no recorded branch for $wi - halt"; exit 1; }
base_sha="$(oss get ".work_items[] | select(.id==\"$wi\") | .base_sha")"
[ -n "$base_sha" ] && [ "$base_sha" != "null" ] \
  || { echo "close: no recorded base_sha for $wi - halt"; exit 1; }
title="$(oss get ".work_items[] | select(.id==\"$wi\") | .title")"
spine_branch="$(oss branch_name "$spine_id" "$spine_slug")"
head_branch="$(git -C "$repo_root" symbolic-ref --short HEAD)"
[ "$head_branch" = "$spine_branch" ] \
  || { echo "close: $target_repo is on '$head_branch', not '$spine_branch' - halt"; exit 1; }

origin_url="$(git -C "$repo_root" remote get-url origin)" \
  || { echo "close: $target_repo has no 'origin' remote - PR mode needs one and merges nothing locally - halt"; exit 1; }
spine_rc=0
git -C "$repo_root" ls-remote --exit-code origin "refs/heads/$spine_branch" >/dev/null || spine_rc=$?
if [ "$spine_rc" -eq 2 ]; then
  git -C "$repo_root" push -u origin "$spine_branch" \
    || { echo "close: origin has no '$spine_branch' and pushing it failed - nothing was committed or pushed; PR mode merges nothing locally - halt"; exit 1; }
  echo "close: pushed '$spine_branch' to origin as the PR base - no PR opened for it; spine close opens that"
elif [ "$spine_rc" -ne 0 ]; then
  echo "close: cannot read '$spine_branch' on origin (ls-remote rc $spine_rc) - nothing was committed or pushed; PR mode merges nothing locally - halt"; exit 1
fi

# Commit, or recognise a resume: an empty index with the recorded branch
# checked out and HEAD already past base is this block's own earlier commit.
staged="$(git -C "$wt" diff --cached --name-only)"
wt_branch="$(git -C "$wt" symbolic-ref --short HEAD)"
[ "$wt_branch" = "$wi_branch" ] \
  || { echo "close: $wt is on '$wt_branch', not the recorded '$wi_branch' - nothing was committed or pushed - halt"; exit 1; }
if [ -n "$staged" ]; then
  git -C "$wt" commit -m "<message>" \
    || { echo "close: commit failed in $wt - nothing was pushed - halt"; exit 1; }
elif [ "$(git -C "$wt" rev-list --count "$base_sha..HEAD")" -ge 1 ]; then
  echo "close: index empty and '$wi_branch' is already past base $base_sha - resuming after the commit"
else
  echo "close: gate is green but the index is empty in $wt and HEAD is not past base on '$wi_branch' - nothing was committed or pushed - halt"; exit 1
fi
[ "$(git -C "$wt" rev-list --count "$base_sha..HEAD")" -ge 1 ] \
  || { echo "close: HEAD in $wt is not past base $base_sha - no commit to open a PR for; nothing was pushed - halt"; exit 1; }
git -C "$wt" merge-base --is-ancestor "$base_sha" HEAD \
  || { echo "close: recorded base $base_sha is not an ancestor of HEAD in $wt - '$wi_branch' was rewritten off its base; nothing was pushed - halt"; exit 1; }
git -C "$wt" push -u origin "$wi_branch" \
  || { echo "close: push of '$wi_branch' failed - the commit is on the local branch; this run opened and recorded no PR - re-run /close $wi --pr to resume - halt"; exit 1; }
pr_url="$(gh --repo "$origin_url" pr list --head "$wi_branch" --base "$spine_branch" --state open --json url --jq '.[0].url // ""')" \
  || { echo "close: gh pr list failed - '$wi_branch' is pushed, no PR was looked up or opened - re-run /close $wi --pr to resume - halt"; exit 1; }
if [ -z "$pr_url" ]; then
  pr_url="$(gh --repo "$origin_url" pr create --base "$spine_branch" --head "$wi_branch" \
    --title "$wi: $title" \
    --body "closed by ossify work-item close in PR mode; gate green; report at $report")" \
    || { echo "close: gh pr create failed - '$wi_branch' is pushed, no PR is recorded - re-run /close $wi --pr to resume - halt"; exit 1; }
else
  echo "close: '$wi_branch' already has an open PR into '$spine_branch' - reusing it, not opening another"
fi
oss work_item_pr "$wi" "$pr_url" \
  || { echo "close: PR $pr_url is open but state refused to record it - no pr_url is recorded - re-run /close $wi --pr to resume - halt"; exit 1; }
echo "close: $wi PR $pr_url"
```

`gh` prints the PR URL on stdout; that line is what `oss work_item_pr` records
(rc 7 refuses anything that is not a `/pull/<n>` URL). Do **not** set `complete`:
the item stays `active`, with its commit past base on `$wi_branch`, pushed, and
`pr_url` recorded. Report the PR URL and end.

**Resuming** a halt after the commit is re-running `/close <wi-id> --pr`. Steps
1 and 2 run again — the gate reads the committed diff (`$base_sha..HEAD`) in
place of the staged one — and the block above skips the commit, pushes again
(a no-op when already pushed), reuses the open PR for `$wi_branch` when one
exists, and records it. Under `--verdict` the gate needs a verdict written against the
committed tree (§2). Until that records `pr_url`, the item is `active`, clean
and past base with no PR recorded — the shape re-entry reads as `finish-merge`,
whose repair is a **local** merge (`round-orchestration.md` §2b step 4). A
`--detach` lane only reports that row (`external-executor.md` §2b). A lane that
closes its own items — the default `/run-spine`, or plain `--external-executor`
— must not be re-entered over a half-done PR-mode close: mixing the two is out
of contract, a known limit.

**The merge and the status belong to the caller.** It merges the PR with a merge
commit (never squash or rebase), fast-forwards the local spine branch from the
remote, checks `git merge-base --is-ancestor <wi-commit> <spine-branch>`, and only
then runs `oss work_item_status <wi-id> complete`. Merge commits are the rule
because the ancestor check is the proof the work reached the spine, and a squash
or rebase never makes the item's commit an ancestor.

---

## 5. On any failure — halt

Terminal, at every layer. No later step runs, no status is written, nothing is
recorded as closed.

1. Surface every error with its **source tag** — `[AC]`,
   `[report cross-check]`, `[rule]`, `[fidelity]`, `[mutation]` (`impl-check.md`).
2. Present the **recovery menu**.
3. **Stop. No auto-select.** The user picks.

The disposition-triage policy that auto-applies spec-aligned recommendations
(SKILL.md §4) governs the *disposition rows* at spine close. It does not reach
here: a failed gate is a human decision, and the menu's options have different
costs and different blast radii.

---

## 6. Worktree cleanup does not happen here

It happens at **spine close, as the last step**, and the reason is the branch —
not the report.

`oss worktree_remove` refuses an unmerged branch at **rc 8**, so cleanup can
only succeed after step 4's merge — the full ordering argument, and the false
one it is often confused with, are in `harvest.md` §1.
