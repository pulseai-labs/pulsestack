---
name: plan-release
description: Use when the user wants to plan a release, groom the feature map, pick spines for the next release, plan Release 0 (the skeleton), or runs /plan-release — declare each spine bone or flesh under a fail-closed critic veto and emit RELEASE.md. Needs a project onboarded via /start. Not /plan-spine.
---

# plan-release

You are the conductor of ossify's **release planning** — the ceremony that turns
a living feature map into a release: a promise phrased as *what a user can DO at
close*, delivered by spines that each cross the whole product. You plan Release 0
here too; there is no separate "skeleton mode".

Bash helpers behind the `oss` dispatcher do the bookkeeping (state CRUD, id
minting, touch-surface matching, atomic writes). The judgment work — which spines
earn this release, how the exit criteria are phrased, what the dependency graph
really is, whether a critic finding is a veto or a shrug — happens **here, in
conversation**. Do not stuff reasoning steps inside `bash -c '...'` wrappers.

---

## 1. Overview

Release planning fixes the **"no usable software early"** failure: months of
horizontal layers with nothing a user could touch. It fixes it structurally —
every release is a user-journey promise, every spine is judged against the bones
it moves, and nothing is planned in detail beyond the next release.

Where it sits: `start` (spec-core onboarding) → **`plan-release`** (you are here)
→ `plan-spine` (decomposition + demo lines) → `close` (spine, then release) →
back here for the next release.

When invoked, work §3 through §9 below in order — each numbered block is one step
of the conversation. You create releases and spines and you declare classes; you
do **not** decompose spines into work items, author demo lines, or author specs —
`plan-spine` owns those.

---

## 2. When to use

**Trigger phrases (description-match):**

- `/plan-release` (slash command — see §10 for the `$ARGUMENTS` trailing argument)
- "plan the next release", "plan Release 0", "groom the feature map", "pick the
  spines for MVP", "what's in this release?"

**Do NOT auto-invoke when:**

- The project has never been onboarded — that is `/start`. Release planning reads
  the bones registry and the feature map; without them the class judgments are
  guesses.
- The user wants to break a spine into work items, author its spec, or write demo
  lines — that is `/plan-spine`.
- The user wants to close a spine or a release — that is `close`. The feature-map
  re-groom at release close *offers* this skill; it does not replace it.
- A release with open spines already exists and the user did not explicitly ask
  for a new one. Ask first: *"Plan a new release, or amend the open one?"*

---

## 3. Pre-flight

Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next.

All ossify lib calls go through the `oss` dispatcher (`ossify/bin/oss`, on `$PATH`
because Claude Code adds each plugin's `bin/` automatically; the dispatcher's bash
shebang forces a bash runtime under it regardless of the calling shell — required
because Claude Code's Bash tool runs zsh by default on macOS). Call form:
`oss <subcommand> [args...]` resolves to `oss_cmd_<subcommand>`. Never `source` the
lib files directly from a skill body — under zsh `BASH_SOURCE` is unset and the
libs break. Use `oss help` for discovery.

**Two probes, both fail-fast.**

```bash
if ! sp="$(oss state_path 2>/dev/null)"; then
  printf '%s\n' "ossify requires a topology declaration (none found on the walk-up path). /ossify:start and /ossify:adopt author one (.ossify/topology.json); an existing dual-repo workspace can instead pair via /init-workspace or /pair-workspace. In a paired canonical repo, run from the AI workspace: (cd <ai-workspace> && oss …). On Codex, invoke the ossify skills start or adopt - that surface publishes skills, not commands."
  exit 0
fi
# Later bare verbs resolve state alone and would honor this override —
# refuse it: the whole ceremony binds to the manifest's project.
if [ -n "${OSS_STATE_FILE:-}" ]; then
  printf '%s\n' "plan-release plans the manifest's project; OSS_STATE_FILE='${OSS_STATE_FILE}' is set - unset it and re-run."
  exit 0
fi
bones="$(oss get '.bones | length' "$sp" 2>/dev/null)" || bones=""
printf 'bones=%s\n' "${bones:-<no state>}"
```

The literal tokens `/init-workspace` and `/pair-workspace` are load-bearing — do
not paraphrase the refusal.

`oss state_path` echoes the path whether or not the file exists, so it proves the
*manifest*, not the project. The second probe is what proves the project: if
`bones` comes back empty (no state file) or `0` (state with an empty registry),
the project was never onboarded. Refuse with:
*"No ossify project state with a bones registry here — run `/start` first;
release planning needs the bones' touch surfaces to declare spine classes."*
Author nothing, create no release, stop.

Both probes are manifest-proof, and the second one only because it is written
this way. `oss state_path` reads the manifest and nothing else, so an exported
`$OSS_STATE_FILE` cannot satisfy it. `oss get` routes through `_oss_resolve_state`
(precedence `explicit-arg > $OSS_STATE_FILE > manifest`) — so calling it bare
would let a stale `OSS_STATE_FILE` from an unrelated session answer the bones
probe from *that* project's state and report a false "onboarded". Passing `"$sp"`
— the path the manifest already resolved — takes the explicit-arg branch and puts
both probes on the same project by construction. **Keep the argument.** Dropping
it reintroduces a silent cross-project read that looks exactly like success.

`oss doctor` is available at any point, but it is the state **gate** — `state`,
`schema`, `replay`, `shape` — not a read-out. It says nothing about pending
amendments, quarantined lines, outstanding fakes, patch records, a held lock or
orphan worktrees. Run it if the state itself looks inconsistent; invoke **`ossify:doctor`** (OMP: `skill://doctor`)
if you want the advisory surfaces, which this skill does not invoke.

**Wayfinder pre-flight.** If a map exists for this repo, its resolved decisions
pre-fill stations below rather than being re-elicited. Branch logic:
`skills/wayfinder/references/preflight.md` (relative to the plugin root) — do not restate it here.

---

## 4. Inputs

Collect all five before selecting a single spine. Three are read from state, one
from the issue tracker, and one is asked.

| Input | Source | Release 0 |
|---|---|---|
| **Feature map** | `oss feature_list` | may be three lines — legitimate |
| **Bones registry + risk gates** (touch surfaces) | `oss get '.bones'` / `oss get '.risk_gates'` | seeded by `/start` |
| **Previous release retro** | the closed release's retrospective | `oss release_dir "<prev>"` → `release-retrospective.md` |
| **Real-use findings since the last release** | **ask the user — mandatory** | **n/a** |
| **Intake queue** — requests from other projects | open issues labelled `from:<project>`, read and dispositioned per `plan-spine/references/intake-and-ledger.md` §1 | usually empty — legitimate |

**Real-use findings are a mandatory input, not a nicety.** What broke, what
annoyed, what you reached for and did not find while *actually using* the product
since the last release. This is the motivation loop feeding back into planning;
a release planned without it is planned from memory of the plan rather than from
the product. Record them:

```bash
oss release_set_meta "<release-id>" '{"real_use_findings":["<finding>","<finding>"]}'
```

(Chronology note: the release record must exist before you can patch it — collect
the findings now, write them in §5 once `oss release_add` has minted the id.)

Findings that describe missing or broken value become feature-map entries
immediately, so they compete for selection like everything else:

```bash
oss feature_add "<name>" "<one-line user value>" "<bone|flesh>" real-use
```

Full input contract in `references/real-use-findings.md`.

---

## 5. Select spines + exit criteria + ledger budget

**5a. Groom, then select.** Rank the feature map against the release's goal and
pick the spines that fit. Prefer breadth-first thin spines; a deepening pass is
selected when it is *earned* (evidence from the real-use findings), not because
polish feels overdue. A candidate that is one architectural layer is not a spine
— split it along a journey or leave it on the map. Full method in
`references/feature-map-grooming.md`; after an adoption, Release 1 also reads
`ADOPTION.md` first (its §8, #302).

**5b. Phrase the exit criteria as user journeys.** One line per criterion, in the
form:

```text
At close, a <actor> can <action> and <observable outcome>.
```

Never "the persistence layer exists", never "the API is complete". If a criterion
cannot be said in that sentence, it is not an exit criterion — it is an
implementation note. The banned shapes are `plan-spine/references/demo-authoring.md`
§3.2's, verbatim — artifact existence, protocol-level evidence, the passive dodge,
an outcome with no falsifiable shape — and §3.2b's headless carve-out applies here
too: a consumer reaching a value through a real API surface is a journey. Re-read
the criteria after §7a lands: a spine the ladder verdicts `internal-enabler`
cannot claim product value in any of them
(`references/class-declaration.md` §4), and this is the last cheap moment to
strike it.

**5c. Create the release and its spines.**

```bash
rel="$(oss release_add "<name>" "<goal phrased as what a user can do at close>")"
sid="$(oss spine_add "$rel" "<spine name>" "<bone|flesh>")"   # one per spine; keep each id
oss release_set_meta "$rel" '{"exit_criteria":["At close, a trader can …"]}'
```

`oss release_add` prints the minted release id (`r0`, `r1`, …); `oss spine_add`
prints the minted spine id (`r0.s1`, …). Capture both — every later call is keyed
by them. `spine_add`'s class argument accepts **only** `bone` or `flesh` (anything
else exits 2); the class you pass here is the *declared* class, and §7 may
overrule it. The 4th argument sets `target_repo`. It is **optional only when exactly
one repo is declared** — the default resolves to that sole repo. With **two or
more declared it is REQUIRED**, and omitting it refuses at rc 2 *after* the
release has been created, leaving a release with no spines: pass the target's
key on every `spine_add` in a multi-repo project.

**Release 0:** normal ceremony, no shortcuts — with the **skeleton spine
pre-seeded** from `start`'s skeleton-cut. It is `bone` class by definition (it
creates the skeleton), its exit criterion is the cut's sentence, the retro input
is n/a, and the feature map may be sparse.

**5d. Set the ledger wall-clock budget — here, and nowhere else.** The cumulative
demo is an operated asset: it is re-run at every spine close, so its runtime is a
tax on every future spine. Spec §6.1 puts the budget at release planning
precisely so that exceeding it forces a **prune / parallelize / deepen** decision
*at planning time*, never silent growth at close time.

```bash
oss release_set_meta "$rel" '{"ledger_budget":"600s"}'
```

Ask the user for the number; propose one if they have none (a few minutes is a
sane starting budget for a young ledger). Then check it against reality —
`oss ledger_active_auto` lists the `active` `auto:` lines the ledger already
carries, and `plan-spine/references/demo-authoring.md` §6's read adds the `planned` ones
a spine has authored and not yet built — this window is exactly when that matters;
`oss demo_run` emits no timing of its own, so time it **capturing the runner's
rc** — `start=$(date +%s); demo_rc=0; oss demo_run || demo_rc=$?; elapsed=$(( $(date +%s) - start ))` —
a nonzero `demo_rc` is a failing ledger line, and the budget conversation happens
with that fact on the table, not after it (under `errexit` the bare form aborts
before `elapsed` is assigned; without it the assignment quietly swallows the
failure). The full block, including the re-raise, is `close`'s
`references/cumulative-demo.md` §5. If the current ledger plus this release's
expected contributions will not fit
the budget, decide now, out loud, which of the three it is:

- **prune** — retire or supersede lines that no longer earn their runtime
  (`plan-spine` records the amendment; `close` applies it);
- **parallelize** — restructure the runner so lines share setup;
- **deepen** — raise the budget deliberately, with the reason recorded.

No later ceremony sets this budget. If you skip it, the release runs unbudgeted.

---

## 6. Sequence by DAG

Author an **explicit dependency graph at spine granularity** — not a linear list,
not work-item granularity (that is `plan-spine`'s round DAG). An edge means *this
spine cannot start until that one closes*, for a real reason you can name.

```bash
oss release_set_meta "$rel" '{"spine_dag":[["r1.s1",[]],["r1.s2",["r1.s1"]],["r1.s3",[]]]}'
```

Shape: `[[<spine-id>,[<dep-id>,…]],…]`. Every spine in the release appears exactly
once, including the ones with no dependencies (`[]` — an omitted entry reads as a
missing spine, not as an independent one). Roots are what the release starts with;
siblings at the same depth may run in parallel.

Interrogate every edge — most claimed dependencies are sequencing preferences, and
a false edge silently serializes a release. Full method, cycle handling, and the
"is this a real edge?" test in `references/spine-sequencing-dag.md`.

---

## 7. Declare class + critic veto

Three judgments run over each spine, in this order. They are **independent**: a
later one never excuses an earlier one, and a clean critic never clears a
touch-surface hit.

### 7a. Class ladder (judgment)

Ask, in order:

1. **Does the spine deliver an actor-to-outcome journey?** If it only builds an
   architectural layer — its completion evidence is that an artifact exists
   ("the migration runs and the tables exist", "the module compiles") rather than
   an actor reaching an outcome — it is an **`internal-enabler`**, never accepted
   as a user-facing bone or flesh spine. Stop the ladder.
   Whether that enabler is then **admitted** to the release is a *separate*
   judgment: it is admitted only if it names a committed user-facing spine that
   consumes it, scheduled in the current or next release (one-release-ahead cap).
   Unnamed consumer → it goes back to the feature map.
2. **Does its plan touch a registered bone or risk-gate surface?** → `bone`
   (§7b, mechanical).
3. **Does it create or modify a bone** — a load-bearing, hard-to-reverse decision
   (system shape, module boundary, data ownership, public contract, trust
   boundary, stack)? → `bone`, and it owes an ADR.
4. **Otherwise `flesh`** — entirely on existing bones. Core ceremony only.

Class is the **only** classification; there is no separate weight or size axis.
Full rules, the enabler/bone contrast, and worked examples in
`references/class-declaration.md`.

### 7b. Bone-touch judge (mechanical, independent of the critic)

For each spine, collect the paths its plan expects to change and check them:

```bash
tc=0; oss touch_check src/domain/order.rs src/ui/export.rs || tc=$?
case "$tc" in
  0) : ;;   # HIT - prints "bone <adr>" / "risk_gate <name>" per match
  1) : ;;   # clean
  *) : ;;   # rc 2 = could NOT check (stderr says why). Never proceed as clean
esac
```

**The rc is inverted on purpose: 0 means a path matched, 1 means clean.** A plan
that reads it backwards inverts the whole judge. **rc 2 is a third answer** — no
paths given, or an unreadable state — and a two-branch `if` folds it into
"clean", which is how a mechanical judge degrades to the permissive class exactly
when the state is broken. Full rc contract in `references/bone-touch-judge.md`.

On a hit, reclassify and record — regardless of the spine's declared class and
regardless of what the critic says:

```bash
oss class_set "<spine>" bone "bone-touch: <ADR-ref> (<matched surface>)"
oss veto_add  "<spine>" "bone-touch: <ADR-ref> (<matched surface>)" auto-bone "touch-surface overlap"
```

A **risk-gate** hit does the same *and* attaches that gate's control checklist
(`oss get '.risk_gates'`) to the spine's close path as required work — paper/
sandbox env, human confirm, kill switch, audit trail, progressive exposure, as
the gate lists them. Harm is orthogonal to reversibility: a one-line flesh change
inside the live-order path is still a Risk event.

On no hit: change nothing, record nothing. Full usage in
`references/bone-touch-judge.md`.

### 7c. Critic veto (fail-closed)

Submit `RELEASE.md` + the bones registry (with touch surfaces) + each spine's plan
to the internal adversarial audit — ossify's own `challenge` skill in audit
mode — and interpret its findings plugin-side. The veto is entirely our reading
of ordinary findings. **The audit always runs**; there is no plugin whose
absence skips it, so the class declaration is never critic-free.

1. **Render the draft first.** The audit reads a real file on disk, and §8's
   emission is what creates `RELEASE.md` — so emit §8's draft **now** (the
   release directory, the five-part render at the classes the ladder declared),
   audit the draft, then re-render at §8 with the veto's dispositions folded
   in. Auditing a file that does not exist yet is a halt, not a no-findings
   pass.
2. **Run the audit.** Read
   `skills/challenge/references/audit.md` (relative to the plugin root) end to end and
   follow it: the draft `RELEASE.md` is the artifact, the depth is `close`,
   the target label is the release id. The registry and spine plans go into
   the conversation alongside it. Whether an external fresh-frame adversary
   joins is the ladder's decision (`challenge/references/adversaries.md`);
   the summary names what ran. Full submission rules in
   `references/critic-veto.md`.
3. **Interpret each finding** — the fail-closed ladder:

| Finding | Disposition | Action |
|---|---|---|
| **Clear, specific, current** veto-grade finding (the spine moves a bone / breaks a contract / crosses a trust boundary its class does not admit) | `auto-bone` | `oss class_set <spine> bone "critic veto: <finding>"` + `oss veto_add <spine> "<finding>" auto-bone "<reason>"` |
| **Ambiguous** (hedged, names no mechanism), **contradictory** (two findings that cannot both hold), or **stale** (cites scope not in the current plan) | `escalate` | `oss veto_add <spine> "<finding>" escalate "ambiguous\|contradictory\|stale - fail-closed"` **and surface it to the user.** NEVER auto-pass |
| **User explicitly overrides** an auto-bone back to flesh | `override` | `oss class_set <spine> flesh "<the user's reason>"` + `oss veto_add <spine> "<finding>" override "<the user's reason>"` — recorded, never silent |
| **No veto-grade finding at all** (clean review, or only cosmetic/`alternative`-severity remarks) | **none** | **Write nothing.** No `veto_add` call, no class change; the spine keeps its declared class |

An `escalate` row is **not finished when the record is written.** Once the user
rules — or declines to — issue the `oss class_set` call that realizes the outcome.
The fail-closed default (`bone`) is a class change, not just a note; the class in
state is what RELEASE.md and `plan-spine` read. Full resolution table in
`references/critic-veto.md` §4.6.

`none` is an answer, not a value — `oss veto_add` accepts only
`auto-bone|override|escalate` (anything else exits 2), and a spine that must exist
(exit 7 otherwise). Never manufacture a veto the critic did not raise; never let
one it did raise through as a pass.

Full input contract, the veto-grade test, and the three ESCALATE triggers in
`references/critic-veto.md`.

---

## 8. Emit RELEASE.md

Runs **twice**: §7c renders the draft the veto audits; this pass re-renders
with the dispositions folded in. Create the release spec directory and write
`RELEASE.md` into it:

```bash
rel_dir="$(oss release_dir "$rel")"   # ABSOLUTE, manifest-rooted — never paste the <ai-workspace> shape
mkdir -p "$rel_dir"                   # e.g. docs/specs/r0/RELEASE.md lives here
```

The directory name is the release id **verbatim** — ossify's ID grammar has one
owner (spec §9.2), and release directories, branch names, worktree paths, and
ledger keys all derive from it without transformation. Route the path through
`oss release_dir`, which resolves the topology declaration like every other
ossify artifact — never a hand-built path.

`RELEASE.md` carries five things and no more: the **goal** (the user-journey
promise), the **spine order + dependencies** (rendered from `spine_dag`), each
spine's **class** with the one-line reason it holds that class, the **exit
criteria** (the §5b journeys), and the **ledger budget**. Full template and the
state→document mapping in `references/release-md-emission.md`.

RELEASE.md is a **record of the plan**, not a second source of truth:
`project-state.json` is authoritative. If they disagree, state wins and the
document is re-rendered.

---

## 9. Sketch the next release

Rolling wave: **current release detailed, next release sketched, feature map
beyond.** The sketch is a goal plus candidate spines — no exit criteria, no DAG,
no classes, no specs.

```bash
oss release_set_meta "$rel" '{"next_sketch":{"goal":"<one line>","candidates":["<spine>","<spine>"]}}'
```

The sketch is the only thing entitled to look past this release, and the
one-release-ahead cap is what makes the internal-enabler consumer rule (§7a)
mechanical rather than aspirational. Full rule in `references/rolling-wave.md`.

Close by naming the next step: **`/plan-spine <spine-id>`** for the first spine
in the DAG.

---

## 10. Slash-command interaction

The `/plan-release` slash command (`commands/plan-release.md`) passes
`$ARGUMENTS` to `bash -c` as a trailing argument — on shim-less channels
(`Skill()`, natural language), the release name
arrives as a literal token in the invocation/request text. **Parse `$ARGUMENTS`
in bash; never reference `$1` / `$2` / `$N`** — Claude Code substitutes
positional tokens in command bodies at template-render time and silently
corrupts them.

The only argument is an optional release name (`"Release 0"`, `"MVP"`, `"v1"`),
passed to `oss release_add`. When it is absent, ask for it before creating the
release — the name is the release's identity in RELEASE.md and in every retro
that cites it.

---

## 11. Anti-patterns (do not do these)

- **Auto-passing an ambiguous, contradictory, or stale critic finding.** The
  veto's false-negative posture is fail-closed: all three ESCALATE. "Probably
  fine" is the failure mode this rule exists to block.
- **Silently overriding a veto.** An override is a user decision, recorded with
  the user's own reason via `oss veto_add … override`. An agent-initiated
  downgrade with no recorded reason is not an override, it is a deletion.
- **Manufacturing a veto the critic never raised.** A clean review resolves to
  *none* — no disposition record, no class change. A skill that escalates
  everything is as broken as one that passes everything.
- **Letting the critic clear a bone-touch hit.** Different judges. The touch check
  is mechanical and runs regardless of the critic's verdict.
- **Reading `oss touch_check`'s exit code backwards**, or folding its rc 2 into
  "clean". rc 0 = matched, 1 = clean, 2 = could not check.
- **Skipping the real-use findings input** because the last release was recent.
  It is mandatory from Release 1 onward; n/a only for Release 0.
- **Accepting a horizontal build as a spine.** No actor-to-outcome journey →
  `internal-enabler`, and admitted only with a named consuming spine in this
  release or the next.
- **Passing `internal-enabler` to `oss spine_add`.** The dispatcher accepts only
  `bone|flesh` (exit 2). The enabler judgment is a planning verdict; see
  `references/class-declaration.md` §5 for how an admitted one is recorded.
- **Detailing more than the next release.** The sketch is a goal plus candidates.
  A three-release plan is the multi-year roadmap coming back in disguise.
- **Forgetting the ledger budget.** No later ceremony sets it (§5d).
- **Decomposing spines into work items, authoring demo lines, or writing specs
  here.** That is `plan-spine`.
- **Letting this body exceed 500 lines.** Hard cap; ossify's whole premise is a
  small front-loaded skill surface. Move depth into `references/`.

---

## 12. Notes on tool boundaries

- **You** (Claude reading this body) make every judgment call: which spines earn
  the release, how an exit criterion is phrased, whether an edge in the DAG is
  real, whether a spine has an actor-to-outcome journey, whether a critic finding
  is veto-grade, and whether it is clear or ambiguous/contradictory/stale.
- **`oss`** (the dispatcher over `lib/*.sh`) handles mechanical state only —
  the verbs `oss help` lists: state CRUD, registry adds, and probes. It
  holds no judgment and never should — `touch_check` matches globs, it does not
  decide what the match means.
- **`challenge` (audit mode)** is ossify's own critic. As a ceremony caller
  it returns every consolidated finding unwalked — no internal rebuttal
  (audit.md §7) — and the veto below is **our** interpretation of that
  returned set. Do not ask it for a verdict; ask it for findings.
- **Peer entry skills:** `start` owns spec-core, the bones registry, and the
  *advisory* spec-core critic moment — do not import its disposition-triage
  semantics into this fail-closed veto, and do not export the veto's semantics
  into it. `plan-spine` owns decomposition, demo lines, and specs. `close` owns
  the cumulative demo run and the release retro.
- **The user** is the final authority. You surface candidate spine sets, exit
  criteria, DAGs, classes, and every escalated finding; they accept, edit, or
  override. An escalation is not resolved by you deciding — it is resolved by
  them ruling, and if they decline to rule, the fail-closed default (`bone`)
  stands.
