---
name: plan-spine
description: Use when the user wants to plan a spine, decompose a spine into work items, author demo criteria, start building a spine, or runs /plan-spine — 1-5 work items, rounds by DAG, a spec per round, cumulative-demo criteria. Needs a release planned via /plan-release. Not release selection or /start.
---

# plan-spine

You are the conductor of ossify's **spine planning** — the ceremony that turns one
selected spine into a buildable plan: work items, rounds, specs, the fakes it
admits, and the lines it contributes to the cumulative product demo.

Bash helpers behind the `oss` dispatcher do the bookkeeping (state CRUD, id
minting, touch-surface matching, ledger writes). The judgment work — how the spine
decomposes, which dependency edges are real, whether a demo line is a journey or
an inspection, whether a fake is admissible — happens **here, in conversation**.
Do not stuff reasoning steps inside `bash -c '...'` wrappers.

---

## 1. Overview

Where it sits: `start` (spec-core onboarding) → `plan-release` (spines, classes,
exit criteria, DAG) → **`plan-spine`** (you are here) → execution → `close`.

When invoked, work §3 through §9 below in order — each numbered block is one step
of the conversation. **This skill plans; it does not execute:** worktree spin-up,
implementer dispatch, verification, and merge belong to the execution engine
(`work-item`, whose lane is `skills/work-item/references/round-orchestration.md`); the cumulative-demo *run*, the harvest, and the retro belong to
`close`. You author the demo *criteria* here; you never run them.

---

## 2. When to use

**Trigger phrases (description-match):**

- `/plan-spine <spine-id>` (slash command — see §10 for the `$ARGUMENTS` bridge)
- "plan the spine", "decompose r1.s2", "break this spine into work items",
  "author the demo criteria", "let's start building this spine"

**Do NOT auto-invoke when:**

- No release exists — that is `/plan-release`. A spine without a release has no
  class, no DAG position, and no ledger budget to author against. Selecting
  spines, phrasing exit criteria, and declaring a class all live there too; you
  **read** the class here and never re-derive it.
- The project was never onboarded — that is `/start`.
- The user wants to close a spine or run the cumulative demo — that is `close`.
- The named spine already has work items and the user did not explicitly ask for
  a replan. Ask: *"Author a later round's specs (§6), fix up a failed round (§7),
  or replan from scratch?"* A replan **adds** items (`w4`, …). `references/decomposition.md`
  §1 keeps two **mutually exclusive** arms apart, and which one you are in is the
  whole question: a **partial** replan withdraws each never-dispatched item it
  replaces (`work_item_status <wi-id> abandoned`) and leaves the spine running; a
  **whole-spine split** retires the old spine (`spine_status <spine-id>
  abandoned`) and re-declares the halves at plan-release. Never both on one spine.
  The withdrawal is enforced rather than declared: `work_item_status <wi-id>
  abandoned` is refused (rc 7) on a dispatched, `complete` or `active` item (§1).
- **A request for a spine whose first round has started** (an item `active` or
  `complete`): its items are fixed — the request goes to the intake queue or
  `/ossify:patch` (`references/intake-and-ledger.md` §1). §7 fix-ups are unchanged.

---

## 3. Pre-flight

Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next.

All ossify lib calls go through the `oss` dispatcher (`ossify/bin/oss`), whose bash
shebang forces a bash runtime whatever the calling shell (Claude Code's Bash tool
runs zsh by default on macOS). Call form: `oss <subcommand> [args...]` resolves to
`oss_cmd_<subcommand>`. Never `source` the lib files directly from a skill body —
under zsh `BASH_SOURCE` is unset and the libs break. `oss help` lists verbs.

**Three probes, all fail-fast.**

```bash
if ! sp="$(oss state_path 2>/dev/null)"; then
  printf '%s\n' "ossify requires a topology declaration (none found on the walk-up path). /ossify:start and /ossify:adopt author one (.ossify/topology.json); an existing dual-repo workspace can instead pair via /init-workspace or /pair-workspace. In a paired canonical repo, run from the AI workspace: (cd <ai-workspace> && oss …). On Codex, invoke the ossify skills start or adopt - that surface publishes skills, not commands."
  exit 0
fi
# Later bare verbs resolve state alone and would honor this override —
# refuse it: the whole ceremony binds to the manifest's project.
if [ -n "${OSS_STATE_FILE:-}" ]; then
  printf '%s\n' "plan-spine plans the manifest's project; OSS_STATE_FILE='${OSS_STATE_FILE}' is set - unset it and re-run."
  exit 0
fi
bones="$(oss get '.bones | length' "$sp" 2>/dev/null)" || bones=""
rels="$(oss get '.releases | length' "$sp" 2>/dev/null)" || rels=""
printf 'bones=%s releases=%s\n' "${bones:-<no state>}" "${rels:-<no state>}"
```

The literal tokens `/init-workspace` and `/pair-workspace` are load-bearing — do
not paraphrase the refusal.

1. **Manifest** — `oss state_path` echoes the path whether or not the file exists,
   so it proves the *manifest*, not the project.
2. **Project** — `bones` empty (no state file) or `0` means the project was never
   onboarded. Refuse: *"No ossify project state here — run `/start` first."*
3. **A release exists** — `rels` empty or `0` means nothing has been planned.
   Refuse with: *"No release planned — run `/plan-release` first; spine planning
   reads the spine's class, its DAG position, and the release's ledger budget."*
   Author nothing, create no work item, stop.

Then resolve the target spine and **fail loudly on an unknown id** — do not guess
the user's intent from a name:

```bash
spine="<spine-id from $ARGUMENTS>"
class="$(oss get ".spines[] | select(.id == \"$spine\") | .class" "$sp")"
rel="$(oss get ".spines[] | select(.id == \"$spine\") | .release" "$sp")"
name="$(oss get ".spines[] | select(.id == \"$spine\") | .name" "$sp")"
if [ -z "$class" ]; then
  printf '%s\n' "No spine '$spine'. Planned spines:"; oss spine_list; exit 0
fi
```

**Test the output, not the rc.** `oss get` is `jq -r` without `-e`: a `select`
that matches nothing exits **0** with an empty string, so `oss get … || …` never
fires on an unknown id and would silently plan against a typo. Only an unreadable
state file makes `oss get` itself fail — which is what probes 2 and 3 above catch.

`class` is `bone`/`flesh` as `plan-release` recorded it — §7 reads it and nothing
here re-derives it. `rel` is the spine's release (§8 reads its ledger budget).
`name` carries the `[internal]` marker `.class` cannot express — §8a F3 reads it.

The probes resolve differently, and only the first is manifest-proof:
`oss state_path` reads the manifest and nothing else, so an exported
`$OSS_STATE_FILE` cannot satisfy it. `oss get` routes through `_oss_resolve_state`
(precedence `explicit-arg > $OSS_STATE_FILE > manifest`) and *can* be satisfied
by one — a stale
export from an unrelated session makes probes 2 and 3 read *that* project, which
is why the pre-flight refuses a set `OSS_STATE_FILE` outright — passing the bound
`$sp` to the `oss get` calls above is defense in depth, not the whole guard, because
every later verb resolves state on its own. **`oss doctor` is the state GATE, not a full read-out** — four checks
(`state`, `schema`, `replay`, `shape`). It says nothing about pending
amendments, quarantined lines, outstanding fakes, patch records, a held lock or
orphan worktrees; those are the `ossify:doctor` skill's, and invoking this skill does
not invoke it. Invoke `ossify:doctor` (OMP: `skill://doctor`) when you want them.
**Then, before §4, read what arrived** since the release was planned — the intake
queue and the tech-debt ledger lines on this spine's surface — and give each a
disposition (`references/intake-and-ledger.md`) — and again for any path §4 adds.

---

## 4. Decomposition

Propose a decomposition into **1-5 work items**, surfaced as a numbered list with
one-line summaries. Each item names: what it delivers, the paths it expects to
touch, its dependencies on sibling items, and its **target repo**.

**The count is an outcome, not a target.** 1-5 is a *bound*, and the lower end is
ordinary: a spine that is genuinely one coherent change is one work item. The old
stack's "4-5 items" norm and its anti-microscope rule no longer act as **floors** —
do not split a coherent change into five to look thorough, and do not pad a thin
spine. (They remain sane *advice* against the opposite failure: a 1500-LOC mega
item behind one bullet is still one bullet hiding four items.)

**4a. Record each item.**

```bash
oss work_item_add "$spine" "<title>" [target_repo]      # prints r1.s2.w1, …
```

`target_repo` defaults to the sole declared repo, refusing outright once more
than one is declared; pass the target's key (e.g.
`private_core`) for an item that lands somewhere else — any declared repo
executes (`work-item/references/round-orchestration.md` §3, in the work-item
skill, halts only an undeclared name or `ai_workspace`).
**Each work item targets exactly one
repo** — an item that spans two repos is two items. Full rules in
`references/cross-repo.md`. An unknown spine id exits **7** and writes nothing.

**4b. Iterate.** Surface the draft, attach one firm recommendation with a
one-line reason cited to the spine's plan or the lean MASTER-SPEC, and ask:
*"Accept as-is, refine (which items?), or restart?"* Loop until the user accepts.

**4c. Re-run the bone-touch check on the decomposed path set.** Release planning
judged a coarse plan; decomposition is the first moment the real file set exists.

```bash
if oss touch_check src/domain/order.rs src/ui/ticket.rs; then
  : # rc 0 = HIT (prints "bone <adr>" / "risk_gate <name>" per match)
else
  : # rc 1 = clean. rc 2 = could NOT check (stderr says why) - never read as clean
fi
```

**The rc is inverted on purpose: 0 means a path matched, 1 means clean.** Reading
it backwards inverts the whole judge. Capture **stdout as well as the rc** — the
matched surface names are what you record.

A hit on a `flesh`-class spine is **drift**, not a formality: the declared class
was made against a plan that did not include this path. Reclassify and record,
then tell the user what changed:

```bash
oss class_set "$spine" bone "bone-touch at decomposition: <ADR-ref> (<matched surface>)"
```

A **risk-gate** hit additionally attaches that gate's control checklist
(`oss get '.risk_gates'`) to the spine's close path as required work — harm is
orthogonal to reversibility.

Full worked example in `references/decomposition.md`. Where the cut creates or
splits a module boundary, `references/codebase-design.md` owns the
interface-depth vocabulary.

---

## 5. Round identification (DAG)

Run a strict-layer topological sort over the declared item-level dependencies:
round *K* holds every item whose dependencies are fully covered by rounds 1…*K-1*
(`> Round 1: w1, w2 (parallel) / Round 2: w3 (depends on w1)`). This is the
**work-item** DAG; the coarser inter-spine DAG belongs to `plan-release`.
**Interrogate every edge**, because a false edge silently serializes the spine:
loosening that violates a declared dependency is refused by name, tightening is
always allowed, empty rounds collapse and renumber, and a cross-repo pair is a
real edge in one order (public port first, then the private adapter). Full
method in `references/dag-rounds.md`, repo dimension in `references/cross-repo.md`.

**Draft `SPINE.md` now; finish it at §9.** Nothing in state holds the rounds.
Context/decomposition/rounds settle here, but **Demo contribution and Fakes are
not decided until §8-§9**, and the **bones section is written last** — so complete
it there (`spec-authoring.md` §1).

---

## 6. Spec authoring

Author a spec per work item into the spine's directory under the release:

```text
<ai-workspace>/docs/specs/<release-id>/<spine-id>-<kebab-slug>/work-<work-id>/spec.md
```

Ids are used **verbatim** — ossify's ID grammar has one owner (spec §9.2), and
directories, branch names (`spine/<spine-id>-…`, `work/<work-item-id>-…`), paths, and
ledger keys all derive from it without transformation.

**Per round, where the DAG allows.** Round 1's specs are authored now; a later
round's spec may wait for its round to start, because the rounds ahead of it will
have taught you something. What is **not** deferred is the **plan**: the critic
and the user see the full spine plan (all items, all rounds, all demo lines) even
when only round 1's spec text exists. Re-entering `/run-spine` once per round is supported: the lane's re-entry arm (`work-item/references/round-orchestration.md` §2b) picks up at the next round without a flag.

**Citation fold-in is a mechanical step, not a ceremony.** Every citation resolves
against the current target set — lean MASTER-SPEC sections, bones registry ADRs,
prior releases' increments; Release 0 specs cite the spec and the bones only.
Re-verification is **mandatory across every live spine spec after any bone
change**. Full rules in `references/citation-foldin.md`.

**Adversarial pass (optional, at the full plan).** Run ossify's own audit —
read `skills/challenge/references/audit.md` (relative to the plugin root) end to end
and follow it with the spine plan as the artifact at close depth. The audit
always runs; the adversary ladder decides whether an external fresh-frame
joins. Placement and detail in `references/spec-authoring.md` §6.

---

## 7. Grill-me gate — bone spines only

The gate fires at two moments: once **after the decomposition settles** (§4), and
again on **any fix-up replan** (a round that failed verification and is being
re-planned). Both are offers, never auto-invocation.

**It is offered for `bone` spines only, and skipped for `flesh`.** Read the class
from state (§3) — do not re-derive it, and do not offer the gate because the spine
"feels architectural". Adding grill gates to a flesh spine is ceremony inflation,
and ceremony inflation is what trains people to skip checklists wholesale.

On **yes**, run ossify's own interview: read
`skills/challenge/references/interview.md` (relative to the plugin root) end to end and
follow it, then loop back to §4 with whatever it surfaced. The grill ships with
ossify, so it always resolves — the offer, and the user's yes/no, are the whole
contract. On **no**, record the skip and proceed.

---

## 8. Demo authoring — the journey-line floor

Demo criteria are authored **here**, at planning time, with implementation context
in hand. The ledger is **cumulative**: every `auto:` line is re-run at every future
spine close, every `user:` line walked by a human at every release close. You spend
runtime against the release's ledger budget — set at `plan-release`, read here with
`oss get ".releases[] | select(.id == \"$rel\") | .ledger_budget"` — and attention
against the release-close walkthrough. Author accordingly.

### 8a. The floor rules (binding)

- **Every spine MUST contribute ≥1 demo line** to the cumulative ledger. A spine
  that changes nothing a demo can observe is not a spine.
- **A user-facing spine MUST contribute ≥1 `user:` journey line** = a **verb +
  observable outcome** (an action the user performs for value). Inspector phrasing
  ("inspect", "view", "open the record/file/schema") is banned — `oss ledger_add_user`
  rejects the obvious case mechanically (rc 2); phrase for value.
- **An internal spine** (rare; declared at release planning) **may contribute
  `auto:` lines only**, and is admitted **ONLY** if it names the committed
  user-facing spine that consumes it, scheduled in the **current or next release**
  (the one-release-ahead cap); else it returns to the feature map. It **cannot
  claim product value**.
- **A deepening pass claiming a measured quality** (performance, reliability,
  cost) **MUST state before/after evidence** in its demo contribution.
- **Every `auto:` line binds to a runnable command + a declared expected**
  (`exit:<n>` | `contains:<str>` | `exit:<n>+contains:<str>`) at authoring time — a
  line that can't state its command doesn't enter the ledger.
- **Release 0 MUST contribute ≥1 automated golden-journey `auto:` line** — one
  command driving the release's exit-criterion journey end to end, so the journey
  is a standing regression test and not a walkthrough someone performs once
  (`start` derives the skeleton cut against this bar and hands the obligation
  here). The r0 spine owning the journey's entry point authors it; any other r0
  spine either finds it in the ledger (the `planned`-inclusive read of
  `demo-authoring.md` §6) or names the spine that will. Release 0 does not close without it.
- **Release 1 after an adoption** also mints adoption's C6 seed candidates once (`references/demo-authoring.md` §1, #293):
  `active`, prefixed `[adoption-seed]`, and outside this spine's own floors.

### 8b. Emit the floor read-out before you write anything

**Check before you write.** Check every precondition before the first write: each file you edit exists and each text you replace is there exactly once; each file you create does not exist yet. Give every check a message that names what failed. A script that asserts after it writes leaves the edit half-applied.

The read-out template, its per-floor `n/a` rules, and the rule that a REJECT stops every `ledger_add_*` call, are **`references/demo-authoring.md` §2**: emit the read-out there, against all six floors, out loud, before the first write.

### 8c. Judging a `user:` line

The test (who performs the action, and why), the banned shapes, the headless-consumer surface, the ban's scope, worked accept/reject pairs, the mechanical backstop's scope, and the false-reject failure mode that reading the ban as a word-list causes (§11): **`references/demo-authoring.md` §3**.

### 8d. Record the accepted lines

```bash
oss ledger_add_user "$spine" "cancel a working order from the order book and see it drop out of the working list" "the order leaves the working list and its margin is released"
oss ledger_add_auto "$spine" "a cancelled order round-trips the matching engine" "cargo test --test cancel_order" "exit:0"
```

Each call **prints the minted line id** (`d7`, `d8`, …) — capture it; amendments
(§8e) key by that id, not the text. Both verbs write the line **`planned`** (its code
not built yet): this spine's close activates it before the demo, `ledger_activate
<line-id>` moves it early when a round lands it, and `active` at authoring is
the adoption seed lines' case only. `ledger_add_auto` validates `<expected>` as `exit:<n>`, `contains:<str>`
or `exit:<n>+contains:<str>` (rc **and** output must hold; exit **2** else), no comparison form — a threshold ("p50 under 40ms")
lives inside the command, which exits non-zero when missed; that is how F4's
after-number becomes machine-checkable.

**The mechanical floor is a backstop, not the judge.** `oss ledger_add_user`
rejects **prefix-only** — `inspect `, `view `, or `open ` at the *start* of the
text, rc 2 — so *"review the generated schema"* or *"confirm the audit table exists"*
passes the lib and is still an inspector line. **A rc 0 is not a verdict; the
judgment is yours.** Full depth in `references/demo-authoring.md`: the six floors (§1),
the backstop's scope and accepted-but-still-inspector list (§3.5), the internal-spine
admission (§4), F4 evidence (§5), F5 runnability + budget (§6), F6 (§7).

### 8e. Amendments

A spine's plan may declare that it **supersedes** or **retires** accumulated lines
whose flow this spine changes — with a reason. They are **recorded now and
applied at this spine's close**, so a sibling spine closing first still runs the
line. `oss ledger_unplan <line-id> <spine>` clears this spine's one if replanned:

```bash
oss ledger_supersede d3 "$spine" "the order ticket replaced the CLI entry point"
oss ledger_retire    d5 "$spine" "the CSV export flow was removed by this spine"
```

Full rules, and why quarantine is not a planning verb, in
`references/demo-amendments.md`.

---

## 9. Fake-ledger discipline

Selective fakes reduce **breadth, not truth**. Any work item that introduces or
retains a shell or fake records a fake-ledger entry — no exceptions, including
fakes inherited from the skeleton and left in place:

```bash
oss fake_add "<boundary>" "<real|fake|deferred>" "<reason>" "<replacement trigger>" "<expiry release>"
```

The channel is validated against `real|fake|deferred` (exit **2** otherwise). A
boundary already in the ledger exits **7**: record it with `fake_status` `renewed`
or `replaced` instead (`references/fake-ledger-discipline.md` §1). Both
the **replacement trigger** (a condition, never a date) and the **expiry release**
are mandatory: a fake whose trigger has fired, or whose expiry release closes
without a replacement, becomes a **blocking release-close finding**. Deferred
truth never becomes permanent silently.

Feed the trigger back into planning so the replacement competes for selection:

```bash
oss feature_add "<replace the <boundary> fake>" "<the value the real one unlocks>" "<bone|flesh>" fake-replacement
```

**Banned fakes** — never admissible, whatever the schedule pressure: faking the
core hypothesis or the actor's outcome · bypassing the real entry point or a
load-bearing integration seam · replacing a safety / money / identity / ordering
invariant · hiding failure signals or requiring manual state repair · a fake whose
semantics differ from its planned replacement · a speculative abstraction added
solely to make something mockable. AI providers are volatile external boundaries
and always sit behind a product-owned swappable interface — which does **not**
license speculative interfaces around unrelated internal algorithms.

Full list with the reasoning and worked cases in
`references/fake-ledger-discipline.md`.

**`SPINE.md` is finished here, and its last section is `## Bones this spine registers`** — the
ADR bones this spine **creates**, one table row each (an ADR the plan only *cites* is not a row),
or the single line `None.` when it creates none. The columns, in `oss bone_add`'s order, and the
rule that close registers these rows before its touch check — halting on a row whose ADR file is
missing, so a row is a promise — are `spec-authoring.md` §1 and `close/references/spine-close.md` §5b.

---

## 10. Slash-command interaction

The `/plan-spine` slash command (`commands/plan-spine.md`) passes
`$ARGUMENTS` to `bash -c` as a trailing argument; on shim-less channels
(`Skill()`, natural language) the spine id arrives as a literal token in
the request. **Parse `$ARGUMENTS` in bash; never reference `$1` / `$2` / `$N`** —
Claude Code substitutes positional tokens in command bodies at template-render
time and silently corrupts them. The only argument is the spine id (`r1.s2`);
when it is absent, list the planned spines (`oss spine_list`) and ask which
one — never pick for the user, never infer a spine from a name when the id missed (§3).

---

## 11. Anti-patterns (do not do these)

- **An inspector-phrased journey line.** "Inspect the schema", "view the record",
  "open the generated file". The lib catches the prefix case only; you catch the
  rest (§8d).
- **Rejecting a valid journey line because its outcome is visible.** The ban is on
  the action, not the outcome (`references/demo-authoring.md` §3.3). False rejects
  push authors toward lines with no observable half at all.
- **Applying a 4-5 item floor.** 1-5 is a bound. A 2-item spine is a normal spine,
  not an under-planned one.
- **Offering grill-me on a flesh spine.** Bone only, plus fix-up replans (§7).
- **A measured-quality claim with no before/after evidence.** "Twice as fast",
  closing green on the pre-existing suite, measures nothing. State the baseline
  and the bound, and bind both to a command.
- **Closing Release 0 with its core journey as a human walkthrough only.** r0
  owes the ledger one automated golden-journey `auto:` line (F6, §8a).
- **An internal spine with no named consumer** ("the UI will consume it someday"
  is the exact phrasing the rule exists to reject — name the spine and the
  release, current or next, or it goes back to the feature map), **or one that
  claims product value** in the exit criteria or contributes a `user:` line.
- **Recording a demo line you intend to fix later.** The ledger is cumulative; a
  bad line is re-run at every future close.
- **Adding a work item to a spine whose first round has started** for a request
  that arrived after it did. Intake queue or `/ossify:patch` (§2).
- **Deleting a demo line.** Supersede or retire it with a reason; archived, never
  deleted (§8e).
- **Reading `oss touch_check`'s exit code backwards**, or folding its rc 2 into
  "clean". rc 0 = matched, 1 = clean, 2 = could not check (§4c).
- **Re-deriving the spine's class.** `plan-release` declared it; you read it.
- **Authoring the release's exit criteria, selecting spines, or running the
  cumulative demo here.** Those belong to `plan-release` and `close`.
- **Letting this body exceed 500 lines.** Hard cap; ossify's premise is a small
  front-loaded skill surface — move depth into `references/`.

---

## 12. Notes on tool boundaries

- **You** (Claude reading this body) make every judgment call: how the spine
  decomposes, whether a dependency edge is real, whether a `user:` line is a
  journey or an inspection, whether an enabler's consumer is committed and in
  range, whether a deepening pass's evidence is evidence, whether Release 0's
  golden-journey line really drives the journey, and whether a fake is admissible.
- **`oss`** (the dispatcher over `lib/*.sh`) handles mechanical state only —
  every verb this skill and its references call is in `oss help`; none of them
  holds judgment. `ledger_add_user`'s
  prefix check is a typo guard, not the journey-line floor.
- **`challenge`** is ossify's own grill and critic: the §7 gate reads its
  `references/interview.md` and the §6 pass reads its `references/audit.md`,
  both by path. Neither mode gains a new interface here.
- **Peer entry skills:** `start` owns spec-core, the bones registry, and the
  journey map; `plan-release` owns spine selection, exit criteria, the inter-spine
  DAG, the class declaration under the critic veto, and the ledger budget; `close`
  owns the demo run, the harvest, and the retro.
- **The user** is the final authority. You surface the decomposition, the rounds,
  the specs, the floor read-out, and every fake you propose to admit; they accept,
  edit, or override. A floor a user overrides is recorded with their reason.
