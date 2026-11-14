---
name: doctor
description: Use when the user says run doctor, check project health, validate the spec, add a project rule, check Codex interop, find orphan worktrees, check plugin provenance, or /ossify:doctor — diagnose an ossify project and name the remedy. Not the /close gates or /start onboarding.
---

# doctor

You are ossify's **diagnostic surface** (spec §9.1, §9.2) — the sixth and last
entry skill, and the only one that is not a ceremony. Every other entry skill
*advances* the lifecycle. This one asks whether the lifecycle's records still
describe the repository they claim to describe, and names the remedy for each
way they do not. It reports, and writes only on the operator's word.

`oss` (the dispatcher over `lib/*.sh`) supplies the mechanical facts: whether the
schema parses, whether the journal replays, which worktree directories no work
item claims. Whether a rule block is well-formed is yours since the skill-first
conversion — checked by reading against the reference's field table (§6). The
judgment — is this drift the record's fault or the repo's, is this rule the
right rule for this project, is this warning worth acting on today — happens
here, in your reasoning. Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next.

---

## 1. Overview and when to use

Where it sits: **nowhere in the chain.** `start` → `plan-release` → `plan-spine`
→ `work-item` → `close` is a sequence; `doctor` is a peer to all five and runs at
any point, including before `start` has ever run.

Six surfaces:

| Surface | The question it answers | Go to |
|---|---|---|
| State inspection | Is the record intact, and does it still match the repo? | §4 |
| Spec validation | Does the lean spec still satisfy its schema? | §5 |
| Rule authoring | What rules should `03-code-patterns.md` document for the work-item gate to apply? | §6 |
| Interop check | Can Claude *and* Codex both drive this workspace safely? | §7 |
| Budget check | Does the front-loaded surface still cost what it claims? | §8 |
| Plugin provenance | Do the answering binary, the loaded doctor body, and the expected reference agree? | §13 |

**The guarantee, and it is the inverse of every other entry skill's:
`doctor` runs on a broken project.** `start` refuses when a declared repo
already carries code (it authors a topology rather than refusing for a missing
one);
`plan-release` requires an onboarded project; `close` refuses without a green
`oss doctor`. This skill **never refuses for the condition it exists to report**.
An uninitialised project, a corrupt state file, a missing manifest — each is a
*finding*, reported with its remedy, not a reason to stop. When a missing
manifest is the cause of more than one surface's skip, name it once at the top
of the read-out and mark the rest derived, so the sweep does not lead with three
consequences of one cause. The one thing you may
refuse is a request to *change* something you were not asked to change.

**`doctor` reports; it writes only on the operator's word.** Two things write:
**rule authoring** (§6), which appends to `03-code-patterns.md` and only because
the user asked for a rule, and **§7's `claude_md` repair**, only on an explicit
yes. Everything else names a remedy and stops. Running `oss state_restore`
because replay failed is not your call to make silently: surface the line, name
the verb, let the user run it.

**Trigger phrases (description-match):**

- `/ossify:doctor [surface]` (slash command — see §12 for the `$ARGUMENTS` bridge)
- "run doctor", "check project health", "is my state healthy", "what's wrong
  with this project"
- "validate the spec", "check my MASTER-SPEC"
- "add a project rule", "author a machine-checkable rule"
- "check Codex interop", "can I switch between Claude and Codex here"
- "find orphan worktrees"
- "check the skill budget"
- "check plugin provenance", "which oss version is loaded"

**Do NOT auto-invoke when:**

- The user wants to **run a gate** — the work-item gate, the cumulative demo, a
  release's blocking findings. Those are `/close`, and they halt; you do not.
- The user wants to **author or amend the spec itself**. Fresh authoring is
  `/start`, which refuses on a declared repo that already carries code; a
  project that already has code adopts via `/ossify:adopt`.
  Amending an existing spec is not this surface's job — you validate it.
- The user wants to **plan, decompose, or execute** anything. Those are
  `/plan-release`, `/plan-spine`, `/work-item`.
- The user asks to **fix** a finding you reported. Name the verb and let them
  run it, unless it is the rule the user asked for (§6) or §7's own repair.
- The spec and the state disagree on **what adoption did**. Read
  `<ai-workspace>/ADOPTION.md` if it exists — it is adoption's record
  (`adopt` §6); route the discrepancy there before re-deriving one side.

---

## 2. Routing

`doctor` routes on **what the user asked for**, not on state. With no surface
named, run the full sweep (§3) — that is the common case and the default for a
bare `/ossify:doctor`.

```bash
surface="<the surface token from $ARGUMENTS, lowercased; empty if none>"
```

| `surface` | Go to |
|---|---|
| *(empty)* | §3 — the full sweep |
| `state`, `health` | §4 |
| `spec` | §5 |
| `rules`, `rule` | §6 |
| `interop`, `codex` | §7 |
| `budget` | §8 |
| `provenance` | §13 |

**An unrecognised token runs the full sweep anyway**, prefaced by one line
naming what was passed and listing the six surfaces. It does **not** refuse:
a user who mistypes a surface name still wants to know whether their project is
healthy, and this is the one skill whose whole contract is that it answers.

---

## 3. The full sweep

Run all six surfaces in the order of §4 → §8 then §13, and **report every one of them.**

**No check halts another.** This is the sharpest difference between `doctor` and
`close`, and copying `close`'s halt discipline here is the mistake to avoid: a
close halts because every later step *mutates* on the assumption the earlier one
passed. No check here does, so a failed check costs nothing but its own line.
An operator with a corrupt state file still needs to know their interop is also
broken — telling them one problem at a time is how a two-hour repair becomes
three sessions.

The corollary: **a surface that cannot run still emits a line.** `oss doctor`
already models this internally with `skip:` (see §4). Do the same at skill level
— "spec validation: skipped, no MASTER-SPEC.md at the manifest-routed path" is a
result. Silence is indistinguishable from a pass, and this skill exists to make
that confusion impossible.

**In a sweep, §6 runs read-only.** A bare `/ossify:doctor` carries no rule to author,
so the sweep's rule verdict is an *inspection*: how many `mcrule` blocks
`03-code-patterns.md` holds, whether each is well-formed, and whether any carry
a type this build does not recognise. It never prompts for a rule and never
writes. Authoring (§6's interactive flow) runs **only** on an explicit request
for a rule — otherwise the sweep would have to either stall soliciting an
unrelated write, or drop one of its six verdicts, and both break a contract
stated three paragraphs above this one.

Close with the read-out in §14.

---

## 4. State inspection

**Four checks are the verb's; the other five are yours.**

```bash
oss doctor
```

runs `state`, `schema`, `replay`, `shape`, tagged `ok:` / `fail:` / `skip:`, and
returns **rc 0 unless a `fail:` line was printed**. A healthy run prints **three**
lines: `state` has only a failure arm, because a missing file makes every later
check moot. Read the tags, not the line count. Those
four stayed deterministic because `close`'s pre-flight refuses to run until
`schema` and `replay` are green, and replay rebuilds the state from its base
snapshot to prove it: a rail in front of a mutation, not a read-out.

**Then you read the rest yourself** — `lock`, `ledger` (pending amendments,
quarantined lines, and the lines that will not run: planned, deferred, escaped),
`fakes`, `patches`, and `worktrees`. They were ~210 lines of
bash that opened files and counted; they gated nothing, since every one emitted
`warn:` or `skip:` and neither ever touches the rc. Use the same line grammar, and
**say plainly at the end whether anything failed** — your half has no exit code.

`references/state-inspection.md` carries the exact reads, the counts, and the one
trap worth naming here: `jq`'s `length` works on strings too, so a corrupt field
returns a plausible number at rc 0. Ask for the field's `type` before trusting a
count.

**`worktrees` is the only one that reads the *repo* rather than the state file.**
It reports directories under `<repo>/.worktrees/` that no work item claims — why
that matters at all (spine close removes worktrees by reading state) is
`references/state-inspection.md` §4's account. Being repo-reading also makes
it the only one that can be legitimately *unavailable*: with no topology
declaration resolving — neither `.ossify/topology.json` nor a
`.workspace/pairing.json` on the walk-up path — there is no repo root to look
in, so emit `skip:` rather than falling silent.

**Print one line per repository**, tagged `worktrees(<repo-key>)` — the keys are
every repo the manifest declares, plus `ai_workspace`, resolved from the
manifest at run time rather than trusted from a list written here. A key the manifest
does not configure, or whose root is not on this machine, still costs a `skip:`
line. Do not summarise the lines into one verdict; the whole point is that
"clean" and "not looked at" stay distinguishable per repo (the #156 history that
made this literal is in `references/state-inspection.md` §4).

Two gates sit *before* the per-key loop — red state health, and a state this
directory's manifest does not route to — and each emits a single **unkeyed**
`skip: worktrees` line, because the cause is the run rather than any one repo.
An unkeyed line means the surface did not run at all, and it names why.

`oss worktree_orphans <repo-key> <state>` names the directories individually.
**Pass both arguments, every time.** doctor used to print this line for you with
both pinned; it does not any more, so the discipline is yours. Omitting the
key resolves to the sole declared repo under one, and refuses outright —
naming the declared set — under more than one (#272/#310 Task 4); relying on
that default is still the #156 habit, because a project that grows a second
repo turns every omitted call into a refusal instead of the per-repo
read-out this section exists to produce. Omitting the state lets an exported
`$OSS_STATE_FILE` answer about a different project.
Pin it once with `sf="${OSS_STATE_FILE:-$(oss state_path)}"` — **override first**,
matching what `oss doctor` itself resolves — and pass `"$sf"` to every read,
including to `oss doctor`. `references/state-inspection.md` §2 carries the
measurement, and the why-override-first account with it.
**It is a pure selector: the finding is its OUTPUT — rc 0 means the check ran,
not that the tree is clean.** Branch on the rc and every project reads orphan-free.

Full detail — the four-line remedy table and why you echo doctor's own line
rather than substituting a fixed remedy, the advisory-vs-blocking split, the
state-vs-repo drift checks that `oss doctor` cannot make mechanically, the
orphan-worktree remedy, and the feature map's inspection surface — is in
**`references/state-inspection.md`**.

---

## 5. Lean-spec validation

ossify's spec is the **lean** schema (spec §13.2), not the legacy 10-phase
MASTER-SPEC. The difference is the whole point: no FR/NFR ID tables are
required, and their absence is **not** an error.

Three rules carry the weight, and each fails in a way a reader would not guess:

1. **Sections 1–7 are the required set.** Legacy phase-named sections are not
   required and their presence is not an error either.
2. **The bones index must have a row per registry entry in
   `project-state.json`.** A registry entry with no index row is spec-vs-state
   drift — a `doctor` finding, and the reason this check belongs here rather
   than in `/start`.
3. **The posture section must be present and non-empty.** An *absent* posture is
   an error rather than a default, because absence is exactly the ambiguity the
   companion spec requires to resolve private.

Full detail — the section contract, the drift check's direction, the error
format with its line number and remediation hint, and what validation
deliberately does not check — is in **`references/spec-validation.md`**.

---

## 6. Machine-checkable rule authoring

`03-code-patterns.md` ships from `/start` with an **empty**
`## Machine-checkable rules` section — the heading present, no rules. Filling it
is this surface's job; with §7's `claude_md` repair it is one of the two writes.

Four rule types, and the field sets are per-type rather than shared — the
reference's §3 table is the authoritative list; there is no verb behind it.

Validate every block **before** appending it — by reading it against that
table and the grammar (the reference's §5 checks, in their stated order). A
failing check names the one wrong line, never just "invalid block". **Shape
only**, and a rule body never enters a shell command: values are regexes full
of `$`, backticks and parentheses, and in a sweep they come out of a
repository file nobody here wrote.

Ossify evaluates no rule against a codebase mechanically, and never will —
**the evaluator is wontfix, settled 2026-08-15**: the work-item gate's Layer 3
agent read is ossify's evaluation mechanism. Tell the user that: a rule
authored today is documented, validated, and read by that gate at every
close — "read", not "applied": a rule whose check needs a measurement the
staged diff does not carry (`coverage_floor`'s threshold) is consulted, not
measured, there. (That statement speaks for ossify; what a mid-migration
project's legacy stack does with the shared artifact is that stack's own
contract — the reference's §2 has the boundary.)

**In a full sweep this surface is READ-ONLY** (§3). Authoring runs only on an
explicit rule request.

Full detail — the HTML-sentinel grammar and why fenced blocks were rejected, a
worked example per type, the per-type field table, the interactive authoring
flow, the idempotent append semantics, and the manifest-routed output path — is
in **`references/rule-authoring.md`**.

---

## 7. Workspace interop

Absorbed from `scaffold-onboard`'s `checking-workspace-interoperability` (spec
§8.1) so the unified plugin owns it and `workspace-init` stays unchanged. The
question it answers: **can this workspace be driven by Claude Code and by Codex,
interchangeably, mid-project?**

**You perform this one by reading. There is no dispatcher verb for it** — the
`interop_check` subcommand was removed. It was 175 lines of bash that opened
files and described what it found, which is work you do directly. Path
*resolution* stays deterministic (`oss repo_root`, `oss state_path`), because
every mutating verb routes through it.

Emit the same line grammar as `oss doctor` — `ok:` / `fail:` per check — and,
since there is no exit code now, **state plainly at the end whether anything
failed**. Checks, in order: the resolved topology declaration —
`.ossify/topology.json` first, `.workspace/pairing.json` as the translated
fallback, and that whichever resolves is *exactly one* JSON object — the
`ai_workspace` root and every declared repo's root
resolving to real directories, with each declared repo — never
`ai_workspace`, which is legitimately allowed to be untracked — also being a
git **work tree** (a bare repository or a `.git` directory is not
one and fails), the state path resolving and not silently
overridden, and **`AGENTS.md` existing and naming ossify**, and **no `CLAUDE.md`**
at the AI workspace root or in its `.claude/` (`claude_md`) — that workspace
only, never a declared repo, which keeps its own. `AGENTS.md` is the one
instruction file every agent reads; a `CLAUDE.md` beside it shadows it for Claude.

**What was absorbed is the question, not the checklist.** The scaffold-onboard
original requires `routing.roadmap`, `routing.sprint_specs` and
`.workspace/locks` — every one of which this stack **retired**. Carrying that key
set over would report a correctly-configured ossify project as broken for
lacking the previous stack's furniture.

**Check first, repair on a yes.** When `claude_md` fails — whatever else the
read-out found — offer §5's repair, after the read-out and never mid-sweep: whole
plan shown first, writes only on the operator's explicit yes, never commits.

Full detail — each check with what it protects, why an unrouted manifest is
deliberately not a finding, and the remedy per failing line — is in
**`references/interop-check.md`**.

---

## 8. Budget check

The progressive-disclosure design targets **0.3–0.4% of a 200k context window**
for the front-loaded entry-skill surface (spec §64). That number is a claim, and
this surface is where it gets measured against the real installed plugin rather
than against the design document.

Two distinct budgets, and conflating them is a documented, repeated error in
this project's own history:

| Budget | What it sums | Enforced by |
|---|---|---|
| **Every-call description** | the `description:` frontmatter of `commands/*.md` — what the listing loads (#263) | `check 7`, a red test |
| **SKILL.md body** | line count per `SKILL.md`, 500 each | `check 6`, a red test |

Neither is affected by `references/`, by `plugin.json`'s description, or by the
agent listing — those are *different budgets*, and trimming one to relieve
another frees exactly nothing. Before claiming any edit buys room, read the
check that enforces the budget you mean.

Full detail — both budgets with their live headroom, the third (agent-listing)
budget that nothing enforces, how to verify the whole-session figure against
Claude Code's own `/doctor`, and the measurement trap that has now produced the
same wrong claim in three documents — is in **`references/budget-check.md`**.

---

## 9. What `doctor` deliberately does not do

Named here rather than left to read as executed:

- **Migration.** Spec §9.1 allocates `doctor` the `migrate` entry point in
  **phase 2**. `oss migrate` exists and moves a state file's schema version;
  the artifact-converting `migrate` *flow* does not ship in this release.
- **Rule evaluation.** §6 authors and validates rule blocks. Running them
  against a codebase mechanically is **wontfix** (settled 2026-08-15): the
  work-item gate's Layer 3 agent read is ossify's evaluation mechanism, and
  no ossify evaluator will ship.
- **Interop repair beyond §7's one case.** Spec §9.1 allocates *check*; that
  repair — move or merge a leftover `CLAUDE.md`, on the operator's explicit yes —
  is one of `doctor`'s two writes (§6 is the other). No manifest keys, no block.
- **Vocabulary maintenance.** A term drifting is a domain-model finding, not
  a state defect — the discipline is `start`'s `references/domain-modeling.md`,
  exercised through the bone retro's lessons section and its own stumble
  trigger; nothing here scans for it.
- **Gates.** Nothing here blocks anything. `close` owns every blocking gate,
  and a `fail:` line from `doctor` is information for the operator, not a veto
  this skill enforces.
- **Repairs you were not asked for.** §1.

---

## 10. Anti-patterns (do not do these)

- **Refusing because the project is broken.** That is the finding, not an
  obstacle to reporting it (§1).
- **Halting the sweep on the first `fail:`.** No check here mutates, so nothing
  downstream is unsafe. Report all six surfaces (§3).
- **Letting a surface that could not run print nothing.** Silence reads as a
  pass (§3).
- **Branching on `oss worktree_orphans`' rc.** rc 0 means it ran. The finding is
  the output (§4).
- **Echoing `oss worktree_orphans canonical` when the warn line named a
  different repo.** The verb takes a repo key. The wrong one sends the operator
  to search a repository that has nothing wrong with it, and they come back
  believing doctor was mistaken (§4).
- **Collapsing the per-repo `worktrees(...)` lines into one verdict.** Their
  separateness *is* the finding: one repo clean and another unconfigured is not
  the same state as both clean (§4).
- **Copying `oss touch_check`'s rc polarity onto anything here.** rc 0 is a
  *hit* there. Nothing on this skill's surface shares that convention.
- **Substituting a fixed remedy for `oss doctor`'s own line.** The remedy
  differs by which line failed, and naming `state_restore` for a schema failure
  loops the operator forever (§4).
- **Running `oss state_restore`, `oss migrate`, or any repair verb on your own
  initiative.** Name it; let the user run it (§1).
- **Treating a missing FR/NFR table as a spec error.** The lean schema does not
  require one (§5).
- **Appending a rule block without validating it first**, or inventing a field
  name a type does not define (§6).
- **Telling the user an authored rule is mechanically enforced.** It is
  documented, well-formed, and read by the work-item gate's agent — the
  evaluator is wontfix (§6, §9).
- **Editing the pairing manifest to make the interop check pass.** §5's repair
  writes `AGENTS.md` and removes a `CLAUDE.md`, on the operator's yes; the
  manifest is never edited by this skill.
- **Demanding `routing.roadmap`, `routing.sprint_specs` or `.workspace/locks`.**
  Those belong to the stack ossify replaced, and a project that lacks them is
  correct, not broken (§7).
- **Claiming an edit freed budget without reading the check that enforces
  it** (§8).
- **Editing a `description:` to make room and not re-measuring.** `check 7` is
  a red test; a description edit that overruns fails the suite (§8).
- **Letting this body exceed 500 lines.** Hard cap; depth goes to `references/`.

---

## 11. Notes on tool boundaries

- **You** (Claude reading this body) make every judgment: whether a `warn:` is
  worth acting on now, whether a drift is the record's fault or the repo's,
  whether a proposed rule is the right rule, whether an interop gap matters for
  this project.
- **`oss`** handles mechanical facts only and holds no judgment: `doctor` (the
  check lines and their rc), `worktree_orphans` (the on-disk-minus-state
  difference — never whether an orphan is safe to delete),
  `state_path`, `repo_root`, `manifest_require`, `get` (arbitrary reads),
  `feature_list`, `critic_detect`, `state_restore` and `migrate` (**named to the
  user, not run by you**).
- **`git`** is reached only as `git -C "<absolute path>"`. Resolve paths once
  with `oss state_path` / `oss repo_root <key>` and never change the session directory;
  from a paired canonical repo, `(cd <ai-workspace> && oss …)` is a subshell, not a session `cd`.
  The manifest walk starts at `$PWD`, so changing directory can re-point state.
- **Peer entry skills:** `start` owns spec-core authoring and the bones registry;
  `plan-release` owns spine selection and the class declaration; `plan-spine`
  owns decomposition and demo lines; `work-item` owns execution; `close` owns
  every gate and every ceremony.
- **The user** decides what to act on. You report, rank, and name the verb.

---

## 12. Slash-command interaction

`/ossify:doctor [surface]` (`commands/doctor.md`) passes `$ARGUMENTS` to `bash -c`
as a trailing argument — on shim-less channels (`Skill()`,
natural language), read the surface token from the
invocation/request text. **Parse `$ARGUMENTS` in bash; never reference
`$1`/`$2`/`$N`** — Claude Code substitutes positionals at render time.

The only argument is an optional surface name (§2). Absent or unrecognised, run
the full sweep.

---

## 13. Plugin provenance

Run this surface in every full sweep and directly for `provenance`. Report
three roles separately — **answering binary**, **loaded doctor body**,
**expected reference** — each resolved role with its concrete path and
manifest version, never one substituted for another. All three resolved and
both active versions equal to expected is `ok`; either differing is `warn`;
any unresolved role is `partial`, with a resolved binary/body disagreement
preserved inside the partial. Detection compares versions only; never derive
a version from a cache-directory name.

Any version disagreement between resolved roles — including binary/body
disagreement while expected is unresolved — triggers prior-use inspection:
name prior `oss` verbs and compare only concrete ossify prose loaded before
this invocation. Impact coverage that could not be completed is `incomplete`
and never changes the surface verdict. Never scan unused skills, reverse-map
verbs, or decide reruns. Follow `references/provenance-check.md`; report
without updating or halting anything.

## 14. The doctor read-out

**The read-out is this skill's final assistant message.** It is a message, not a
file: `doctor` writes no report artifact.

It carries, in this order:

1. **Each surface with its verdict** — including the ones that were skipped, and
   why. The six lines are roll-ups: each is followed by that surface's own
   tagged lines verbatim. A `skip:` inside a surface never rolls up to `ok:` —
   the roll-up says `partial` and names which check did not run — and the
   `worktrees(<key>)` lines are never merged.
2. **Findings, worst first**, each with the remedy verb named literally. A
   `fail:` outranks a `warn:`; a `warn:` that blocks a close outranks one that
   does not.
3. **What is advisory** — stated as advisory, so a `warn:` is not read as a
   thing that must be fixed before work continues.
4. **What the operator must do next**, if anything — or an explicit "nothing"
   rather than trailing off, so a clean project reads as clean rather than as a
   run that stopped early.
