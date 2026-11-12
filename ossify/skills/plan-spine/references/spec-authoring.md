# Spec authoring (per round)

Depth for SKILL.md §6. One spec per work item, authored where the DAG allows
rather than all upfront.

---

## 1. Layout

```text
<ai-workspace>/docs/specs/<release-id>/<spine-id>-<kebab-slug>/
├── SPINE.md                       # the spine plan: items, rounds, demo contribution, fakes, bones
└── work-<work-id>/
    └── spec.md                    # one per work item
```

Ids are used **verbatim**. ossify's ID grammar has one owner (spec §9.2): release
`r<N>`, spine `r<N>.s<K>`, work item `r<N>.s<K>.w<J>`, branch
`spine/<spine-id>-<kebab-slug>`. Directories, branches, worktree paths, and ledger
keys all derive from it without transformation — no re-shaping, no `VS-` forms, no
zero-padding a work-item number to look tidy.

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

The kebab slug comes from the spine's recorded name
(`oss get '.spines[] | select(.id=="…") | .name'`). If it sanitizes to empty, stop
and fix the spine's name in state rather than inventing a directory slug.

### Authoring `SPINE.md` — the step that is easy to skip

**Write it at the end of SKILL.md §5, once the rounds are settled.** No state
field holds the round structure: `oss` records spines and work items, but nothing
records *which items share a round*. Until `SPINE.md` lands, **the plan exists
only in the conversation** — and two ceremonies read it back later:

| Consumer | Reads |
|---|---|
| `close/references/spine-close.md` §3 (step 2) | `base_branch`, from the spine-context section |
| `close/references/spine-close.md` §7 (the adversarial audit) | the whole file, as the audit's artifact at spine close |
| §6 of this file | the same, for the planning-time adversarial pass |

Skipped, both fail in the same shape: the critic audits a path that does not
exist, and the merge step cannot resolve the branch it must return to.

Pinned sections, in this order:

```text
# <spine-id> — <spine name>

## Spine context          class (`bone`|`flesh` as recorded in state; add `—
                          [internal] (admitted, consumer <spine-id>)` when the
                          spine's name carries the marker), the bones this
                          spine rides, and a BASE-BRANCH TABLE: one row per
                          hosting repo, `<repo-key> | <base_branch>`
## Decomposition          the 1-5 work items, one line each: id, title, target repo
## Rounds                 Round 1: w1, w2 (parallel) / Round 2: w3 (depends on w1)
## Demo contribution      the ledger lines this spine adds (§4's ledger half)
## Fakes                  each fake with its replacement trigger and expiry release
## Bones this spine registers
                         the ADR bones this spine CREATES, one row each, or the
                         single line `None.`; the columns are `oss bone_add`'s
                         four arguments, in its order:
                           | ADR | Title | Touch surface (glob csv) | Revisit when |
```

`base_branch` is the branch the spine cuts from and merges back to, **per
hosting repo** — one row for every repo the Decomposition names, not one value
for the spine. A cross-repo spine can legitimately cut from `main` in one repo
and a release branch in another; spine close cross-checks each repo's
handoff-recorded base against the planned value **for that repo**
(`close/references/spine-close.md` §3), so a single planned value makes every
repo whose base differs a halt. Record the table at planning time, because at
close the checkout has moved and there is nothing left to derive it from.

**A row is a bone this spine *creates*; an ADR the plan only *cites* is not a row.**
Close registers every row into the bones registry before its touch check, and halts
naming the ref when the ADR file is missing — so a row is also a promise that this
spine writes that ADR (`close/references/spine-close.md` §5b). When the spine
creates none, write the single line `None.` — a complete answer, not a gap, which
close reports in one line. `Revisit when` may be empty. The other three columns are
`oss bone_add`'s required arguments, in its order — the verb is positional, so a
swapped column registers the title where the touch surface belongs, silently.

---

## 2. What a work-item spec carries

| Section | Content |
|---|---|
| **Goal** | What this item delivers, in one paragraph, in product vocabulary |
| **Context** | Which bones it rides; which registered touch surfaces (if any) it hits and the controls that came with them |
| **Target repo** | Exactly one (`cross-repo.md`) |
| **Approach** | The intended change, at the level a fresh session could execute |
| **Acceptance criteria** | `auto:` lines in the grammar below + any `user:` step. These are the item's ACs, distinct from the spine's ledger contribution (§4) |
| **Citations** | Lean MASTER-SPEC sections + bones ADRs it depends on (`citation-foldin.md`) |
| **Out of scope** | What a reader might reasonably assume is included and is not |

Never author a parallel prose AC table beside the machine-checkable lines. One AC
source of truth per item — the split is what produced the predecessor stack's
zero-ACs class of bugs.

### The AC grammar — exact, because a parser reads it

`oss verify_acs` parses these lines at the worker's pre-flight Gate 2. A line
that does not match yields **no row**, and a spec whose ACs all miss the grammar
reaches the worker as a spec with zero ACs. An `auto:` line whose command is
missing, has only one backtick, or is empty between its backticks is different:
`verify_acs` names it and exits **3**, so the gate halts instead of dropping it:

```text
- [ ] AC-<N> auto: `<command>` → expected: exit <n>
- [ ] AC-<N> auto: `<command>` → expected: output contains <string>
- [ ] AC-<N> auto: `<command>` → expected: exit <n> and output contains <string>
- [ ] AC-<N> user: <a step a human performs>  — documentation for the implementer only; not parsed, not gated
```

Five parts, each load-bearing:

| Part | Requirement | What breaks without it |
|---|---|---|
| `- [ ] ` | A markdown checkbox, exactly this | `- AC-1` or `* [ ] AC-1` yields **no row at all** |
| `AC-<N>` | The label, numbered | No row |
| `auto:` | The marker | No row. **And no ossify gate runs a `user:` AC either** — the human-walked half lives in the demo ledger (SKILL.md §8), keyed by spine, never read out of a spec |
| `` `<command>` `` | **Backticked**, before the `→` | No pair of backticks there, a lone backtick, or an empty command: `verify_acs` names the AC and exits **3** — the gate halts. A backticked word in the expectation is never taken as the command |
| `→ expected: ` | U+2192, then the literal word | An ASCII `->`, or a missing `expected:`, lands the whole tail in the expectation field: a row is emitted and it is **unusable** |

**The expectation grammar has three space-form rows — `exit <n>`,
`output contains <str>`, or `exit <n> and output contains <str>` — and no colon
anywhere.** This is the one to get wrong, because §8's ledger lines take the
**colon-form** (`exit:0`, `contains:ready`), and an agent that just authored a
batch of ledger lines will carry the habit straight into the spec. They are
different grammars read by different parsers:

| | Spec AC (`oss verify_acs`) | Ledger line (`oss ledger_add_auto`) |
|---|---|---|
| Expectation | `expected: exit 0` | `exit:0` |
| Arrow | `→` required | no arrow |
| Checkbox + label | required | none |

A plain `output contains` row reads no exit status, with two exceptions that fail
it: a command that cannot run (rc 126 or 127), and a named test runner that exits
nonzero. When the exit matters, or a runner should fail, name it:
`exit 0 and output contains <str>`. The ledger has the same combined form in the
colon grammar: `exit:0+contains:<str>` (#770); a ledger `contains:` alone has no exit half.

`close/references/impl-check.md` §2 owns the runtime side of this grammar; when
the two disagree, it is authoritative. The worker's Gate 2 also shape-checks the
parsed rows (`work-item/references/pre-flight.md`), so a malformed AC is a
blocking gap **at pre-flight** rather than a confusing failure at the close gate.

**An AC that diffs against a commit names a fixed sha**, the base the spine is
planned on, never a moving ref such as `origin/main`, which holds the item's own
change once the spine lands and fails a re-run of the gate (#981).

**An AC that runs a test file the item creates tests for it first**:
`test -f tests/new.test.js && node --test tests/new.test.js tests/old.test.js`.
`node --test` on node 22 skips a named file that is missing and exits 0 on the rest,
so the RED gate stops on a green that proves nothing (#909, #934).

**An AC expected GREEN at start.** A regression guard, or a deletion check whose state the
spine starts in, passes before the work, and the RED gate stops on it
(`work-item/SKILL.md` §4). Declare each such AC below the ACs, one line each:

```text
Expected GREEN at start: AC-<N> — <why it passes before the work>
```

`/run-spine` copies each line into the handoff's §4, so dispatch 1 honours it (#715).

---

## 3. Per-round authoring, full-plan visibility

**Author round 1's specs now.** A later round's spec may be authored when its
round starts — by then the rounds ahead of it will have taught you something, and
a spec written before that is a spec written twice. Authoring later rounds is
supported by re-entering `/run-spine` once per round: the lane's re-entry arm
(`work-item/references/round-orchestration.md` §2b) picks up at the next round
without a flag.

What is **not** deferred is the **plan**. The user and the critic see the whole
spine at once: every work item, the round structure, the demo contribution, the
fakes, and the amendments. Per-round authoring relaxes *when the spec text is
written*, never *when the spine is understood*.

Two things this buys, and one thing it costs:

- Round *K*'s spec cites what rounds 1…*K-1* actually landed, not what they were
  predicted to land.
- A round that changes the plan (a gap surfaced during execution) re-plans cheaply
  — there is no stale spec text downstream to reconcile.
- The cost: someone must remember to author round *K*'s spec before round *K* is
  dispatched.

**Who authors it, and when.** **`plan-spine` does — this skill, re-entered.** Not
the execution lane: `work-item/references/round-orchestration.md` opens a round
with worktree creation and handoff authoring, and its handoff step describes
landing the handoff *beside the `spec.md` plan-spine already wrote*. The lane
dispatches workers who **read** specs; it has no spec-authoring step and should
not grow one, or the artifact and its reviewer become the same agent.

So the deferred spec is authored **between rounds**: round *K-1* clears its
barrier, `plan-spine` is re-entered to author round *K*'s specs against what
actually landed, and only then does the lane spawn round *K*.

**How the lane knows to pause.** It checks, rather than assuming. Before spawning
a round, the spec each work item names must exist and parse — that is the same
`oss verify_acs` the worker's Gate 2 runs, just run one step earlier where the
recovery is cheap. A missing or unparseable spec is **not** a gap for the worker
to surface: it means the round was dispatched before it was planned. Halt and
re-enter `plan-spine` for that round.

Left implicit, this fails in the worst available way — the worker reaches Gate 2,
finds no spec, and returns gaps-mode against an item nobody has specified yet,
which reads like an under-specified work item rather than a skipped planning step.

---

## 4. Spine ACs vs ledger lines

They are different artifacts with different lifetimes, and conflating them fills
the cumulative ledger with per-item scaffolding:

| | Work-item ACs | Ledger demo lines |
|---|---|---|
| Scope | One work item | The whole product |
| Lifetime | Until the item merges | Forever, until superseded/retired |
| Run by | `close`'s work-item gate (`close/references/impl-check.md`) | The cumulative demo, at every future spine close |
| Authored in | `spec.md` (§2) | `oss ledger_add_auto` / `ledger_add_user` (§8) |

An item AC that asserts an internal helper returns the right shape is a good AC
and a terrible ledger line. Promote to the ledger only what states something
**about the product** that must remain true.

---

## 5. Citation fold-in

A mechanical step of authoring, not a ceremony: every citation resolves, or the
spec does not lock. Full rules — the target set, the Release 0 narrowing, and the
mandatory re-verification after any bone change — in `citation-foldin.md`.

---

## 6. Adversarial pass (optional, at the full plan)

If the user wants the plan audited before build, run ossify's own audit —
`challenge` in audit mode — **against the spine plan** (`SPINE.md` plus the
specs that exist), after the plan settles.

1. **Run the audit.** Read
   `skills/challenge/references/audit.md` (relative to the plugin root) end to end and
   follow it: `SPINE.md`'s absolute path is the artifact, the depth is `close`,
   the target label is the spine id. The audit always runs — there is no
   plugin whose absence skips it. Whether an external fresh-frame adversary
   joins is the ladder's decision
   (`challenge/references/adversaries.md`), and the summary names what ran.
2. **On return, triage the standing challenges** and fold accepted ones back
   into the plan (§4 decomposition, §5 rounds, §8 demo contribution) before
   locking.

This is a **planning** audit. The bone spine's full close-depth audit with the
external adversary belongs to `close`, and it is a different moment with a
different artifact. Close depth here is deliberate all the same: this is the
plan's **lock moment** — the audit runs once, right before the plan becomes
binding, and a shallow pass at that moment wastes the one look; depth is cheap
next to re-planning a locked spine.

---

## 7. Anti-patterns

- **Authoring every round's spec upfront** because that is how it used to work
  (§3). The plan is upfront; the spec text is per round.
- **Hiding the plan from the critic** because only round 1's spec exists. The
  critic sees the full spine plan (§3).
- **A parallel prose AC table** beside the machine-checkable lines (§2).
- **Promoting per-item scaffolding ACs into the cumulative ledger** (§4).
- **Skipping the §6 audit because no external adversary is configured.**
  Host-only is the declared default, not an absence (§6).
- **Re-shaping an id for a directory name** — verbatim, always (§1).
