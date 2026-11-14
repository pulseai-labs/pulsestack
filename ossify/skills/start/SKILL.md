---
name: start
description: Use when the user wants to start a new project, onboard a new project into ossify, kick off a skeleton-first build, or runs /start — journey map, skeleton cut, bones registry, privacy posture; produces a lean MASTER-SPEC, memory bank, bones ADRs and seed feature map. Not /plan-release, /plan-spine or amending an existing spec.
---

# start

You are the conductor of ossify's **spec-core onboarding** — station 2 of the
five-station lifecycle. You walk the user through the pre-code decisions, and
only those, then hand off to `plan-release` for Release 0. You deliberately do
**not** produce exhaustive FR/NFR enumeration, PRD/SRS/BACKLOG, a multi-year
roadmap, or PROJECT_PLAN — those are retired or grown at release closes
(`references/lean-spec-schema.md` §3).

Bash helpers behind the `oss` dispatcher do the bookkeeping (state CRUD, atomic
writes, registry entries, filesystem probes). The judgment work — what the
journey map should say, where the skeleton cut falls, which bones are real,
which posture the evidence supports — happens **here, in conversation**. Do not
stuff reasoning steps inside `bash -c '...'` wrappers.

---

## 1. Overview

The five stations: **declare the topology** (this ceremony authors
`.ossify/topology.json` itself; workspace-init's `/init-workspace` or
`/pair-workspace` is an alternative, not a prerequisite) → **spec-core
onboarding** (you are here) → **feasibility spike** (optional, §9a) →
**Release 0, the skeleton** → **rolling releases**.

When invoked, work §3 through §13 below in order — each numbered block is one
step of the conversation.

Everything here is **pre-code decisions**. You create no release, no spine, and
no work item — `plan-release` owns those.

---

## 2. When to use

**Trigger phrases (description-match):**

- `/start` (slash command — see §14 for the `$ARGUMENTS` trailing argument)
- "start a new project", "onboard this project into ossify", "kick off a
  skeleton-first build", "let's spec this out before we build"

**Do NOT auto-invoke when:**

- The user wants to plan a release or groom the feature map — that is
  `plan-release`. Release 0 itself is planned there, not here.
- The user wants to decompose a spine into work items — that is `plan-spine`.
- A lean MASTER-SPEC already exists and the user wants **one** change folded in
  — that is an amendment (name the section and the edit), not a re-run of
  spec-core.
- The user wants to close a spine or a release — that is `close`.
- A MASTER-SPEC of any schema, lean or legacy, already exists at the routing
  destination AND the user did not explicitly type `/start`. Ask first.

If it is ambiguous, ask: *"Fresh spec-core onboarding, or work with the existing
spec?"*

---

## 3. Pre-flight

All ossify lib calls go through the `oss` dispatcher (`ossify/bin/oss`):
`oss <subcommand>` → `oss_cmd_<subcommand>` under a forced bash shebang —
never `source` the libs (zsh leaves `BASH_SOURCE` unset). Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next. `oss help` for discovery.

**Topology probe (resolves, authors, or refuses fail-closed).** ossify's state lives in
the AI workspace: walk up for `.ossify/topology.json`, then `.workspace/pairing.json`:

```bash
if probe="$(oss state_path 2>&1)"; then
  printf '%s\n' "topology: resolved - author nothing, proceed to the journey map"
else
  printf '%s\n' "$probe"   # the verb's OWN diagnostic, never swallowed
  printf '%s\n' "ossify requires a topology declaration (none found on the walk-up path). /ossify:start and /ossify:adopt author one (.ossify/topology.json); an existing dual-repo workspace can instead pair via /init-workspace or /pair-workspace. In a paired canonical repo, run from the AI workspace: (cd <ai-workspace> && oss …). On Codex, invoke the ossify skills start or adopt - that surface publishes skills, not commands."
fi
```

**Not a halt — the block carries no `exit`.** The only halt here is a re-probe
that still refuses AFTER authoring. **Read `$probe` first:** a declaration that
exists but is INVALID (bad repo name, entry with no root, empty `.repos`) refuses
with its own message naming the file, and the fix is that file. Authoring is only
for the nothing-found case; it never overwrites. Print the refusal's tokens verbatim even so — they name the
alternatives and the Codex surface. To author: `.ossify/topology.json` at the
AI-workspace root, schema v1 `{schema_version, repos:{<name>:{root}},
well_known_paths:{}}`, names `[a-z][a-z0-9_-]*`, roots absolute, from the repo
set the journey-map station asks about next (`canonical` only if that is
genuinely the name). Then re-probe `oss state_path` and `oss repo_root <name>`
for every declared repo, halting only if one still refuses.

**Canonical-content gate (refuses fail-fast).** `/start` is pre-code ceremony: establish whether any declared repo (`oss repo_root <name>` per name) carries the product's own source at `HEAD`. A repo the pairing manifest (`.workspace/pairing.json`) declares under its `tooling_repo` key is not the product (#553): it carries its own history by nature, so this gate skips it. In a native
`.ossify/topology.json` every key is just a repo name, so every declared repo there is checked. `git -C <root> ls-tree -r --name-only HEAD` and `git -C <root> rev-list --count HEAD` only propose; whether `HEAD` holds product (not docs, a dead prototype or a bare pairing scaffold) is your judgment, so for a repo with history or files beyond the scaffold, show what you found and ask the operator to confirm. A repo with no commit has neither: name it.
- **Product source at `HEAD`:** author nothing and refuse, naming what you found and routing to **`/ossify:adopt`** — the adopt-forward path for a project that already has code (native `adopt` on Codex), which takes a project onboarded with the legacy scaffold stack and a plain repo with product source alike (#536; ossify 1.35.0 or later).
- **No product source at `HEAD`, history or not,** and the operator confirmed it, or no file is at `HEAD`: proceed as greenfield. History alone is class H (#809): note each such repo's commit count and what is at `HEAD` for `06-progress.md`'s spec-core-close entry (§13).
- **No operator to answer** (a non-interactive run), checked after the product-source bullet, whose refusal and adopt route print instead when you judge the files product: a repo with any file at `HEAD` (a workspace-init pairing leaves the canonical with none) refuses (#1040); 1.33 refused history alone too, and this rule does not. Author nothing and print `start: <repo> has <n> commits and files at HEAD beyond the scaffold and no operator confirmed they are not product - refusing`, then say what to do: run `/start` with an operator to confirm, or `/ossify:adopt` if it is the product (adopt owns product source; run headless it refuses a repo it does not judge product, and says to re-run with an operator). A bare scaffold (no file at `HEAD`) or a repo with no commit proceeds. This is not the audit's non-interactive rule (§11).

Those tokens are load-bearing too. Past both gates, settle every occupied destination
(`references/occupied-destinations.md`), then `oss init "<project-name>"`, which refuses
if ossify state already exists — the "already onboarded" signal; route per §2, never force past it.

**Wayfinder pre-flight.** If a map exists for this repo, its resolved decisions
pre-fill stations below rather than being re-elicited. Branch logic:
`skills/wayfinder/references/preflight.md` (relative to the plugin root) — do not restate it here.

---

## 4. Product vision → narrative

Ask for the vision and capture it as **narrative prose**: the problem, the
actor, the shape of the product in five years, what would make it obviously
worth having. A page is plenty.

**Zero execution semantics.** Nothing sequences by the vision — no IDs are
minted from it, no release derives from it, no ceremony reads it as input. The
demotion is deliberate: in the predecessor stack the vision fed a multi-year
roadmap that was obsolete within a sprint and then quietly ignored.

Its only structured descendants are feature-map entries harvested from the
conversation (`oss feature_add ... spec`).

While you are here, you are also choosing **which questions to ask at all**.
Upfront: vision, domain model + data ownership, security/trust boundaries +
destructive ops, architecture/system shape, posture. Moved to release time:
UX detail, per-feature implementation approach, DevOps, quality/eval strategy,
operations. Two or three cuts are genuinely contested (how much security is
Release-0 minimum; whether Release 0 needs a deployment story; whether the data
model is a bone now) — **escalate those to the user, never apply the default
silently**.

Full framing in `references/lean-spec-schema.md`; full question split in
`references/onboarding-question-subset.md`.

---

## 5. Journey map

Author the journey map with the user. Each step is one line with three
mandatory parts:

```text
<actor action>  |  <system responsibility>  |  <observable evidence>
```

Then mark every step **`skeleton`**, **`next`**, or **`later`**. An unmarked
step is a bug in the map.

The map is **NOT a build order** and not a backlog. It is the derivation
instrument for the skeleton cut and the seed of the feature map.

Reject lines with no actor, no observable evidence, or inspector phrasing
("inspect the schema", "the API returns 200") — the actor is a user, not a
developer with a debugger.

**Harvest before moving on.** Every step not marked `skeleton` becomes a
candidate spine:

```bash
oss feature_add "<name>" "<one-line user value>" "<bone|flesh>" journey-map
```

Full grammar + worked example in `references/journey-map.md`.

---

## 6. Skeleton-cut

**Validate** §5's `skeleton` marks as the **thinnest coherent path** — §5 marks,
this step checks, and a correction goes back to §5 (its harvest already ran).
Read it back: *"At Release 0 close, a `<actor>` can `<action>` and `<outcome>`."*

This answer defines **Release 0**, **not the MVP** — the rename from the legacy
"MVP cut" question exists to kill that terminology collision. Release 0 is
deliberately *less* than an MVP; MVP scope belongs on the map as `next`.

The cut must pass: end-to-end (not end-to-layer), real entry point, real
outcome, one journey rather than a capability list. It will be judged at close
by the **clean-checkout test** — from a clean checkout the actor reaches the
outcome without editing storage, invoking hidden developer operations, or
receiving manual repair.

Do **not** create the release here. The cut pre-seeds `plan-release`; that skill
runs the normal ceremony with the skeleton spine (bone class by definition)
pre-seeded.

Full derivation in `references/skeleton-cut.md`.

---

## 7. Bones registry

Walk the **forced-enumeration checklist**. Every category is answered, or
explicitly marked `not-applicable` with a one-line reason. Never silently
omitted — the failure mode is unasked questions, not wrong answers.

1. System shape & deployment topology
2. Module boundaries & dependency direction
3. Data ownership & migration posture
4. Public contracts & compatibility policy
5. Trust boundaries & destructive operations
6. Failure visibility
7. Rollback & evolution strategy
8. Stack
9. Cross-cutting constraints (auth / tenancy / posture / determinism)

Each answered category becomes **an ADR from birth** (default status protocol:
`Proposed`, flipped to `Accepted` once a release exercises it) with a declared
**touch surface** and an optional **revisit trigger** — a *condition*, never a
date.

```bash
oss bone_add "<ADR-ref>" "<title>" "<touch-glob-csv>" "<revisit trigger>"
```

Touch surfaces use bash `case` glob semantics (`*` matches `/`, so
`src/domain/**` is a prefix wildcard). They are the registry's mechanical teeth:
at release planning, a spine whose plan touches any registered surface
auto-reclassifies to `bone`, independently of the critic. Write them at module
granularity — `src/**` makes everything a bone; a single file misses the sibling.

Full checklist in `references/bones-registry.md`. The terms a bone's decision
defines are vocabulary with an owner — challenging and defining them is
`references/domain-modeling.md`.

---

## 8. Risk gates

Record each hazard whose harm a test failure cannot undo — **money**,
**destructive**, **identity/trust**, **ordering/correctness-critical** — with a
touch surface and **the controls its family attaches**:

```bash
oss risk_gate_add "<name>" "<touch-glob-csv>" "<controls-csv>"
```

Control menu: paper/sandbox env · human confirm (naming the concrete effect) ·
kill switch · audit trail · progressive exposure. **Every control the menu
attaches to the gate's family is required; one it does not attach is ceremony
inflation.** The attachment table is `references/risk-gates.md` §2 — read it
there, and do not restate it here.

A spine touching a gate's surface reclassifies to `bone` **and** inherits the
gate's controls as required work.

Full rules in `references/risk-gates.md`.

---

## 9. Smoke-test pass

Every technology claim a bone rests on — crate/package names, versions, API
surfaces, integration assumptions, platform facts — is either **verified by a
minimal isolated smoke test** (20-50 lines, throwaway worktree, code discarded)
or **explicitly marked `unverified`** in that bone's ADR, with a revisit trigger.

Silence is the defect, not the uncertainty. Record the outcome in the ADR:
`### Verified claims` / `### Unverified claims`.

Smoke-test code never enters the project tree. Time-box the pass; a claim eating
more than ~15 minutes is architectural uncertainty (→ §9a), not a fact check.

Full protocol in `references/smoke-test-pass.md`. A claim that needs *reading*
rather than *running* — a comparison, a constraint, a behavioural fact no
20-50-line script reaches — is research, not a smoke test:
`references/research.md`.

---

## 9a. Feasibility spike (optional, explicit)

When spec-core surfaces **genuine architectural uncertainty** — you cannot
responsibly write the bone because you do not know whether the shape works at
all — offer a disposable feasibility spike. This is lifecycle station 3. Most
projects do not need one; offer it explicitly, with the cost attached, and
accept "no" as the default.

The contract, written **before** any code: **one hypothesis** · **one falsifier**
(written first, or the spike always succeeds) · a **timebox** · **`code_fate:
discard`** · the evidence retained after deletion · the bone decision it enables.

`code_fate: discard` is non-negotiable: scratch branch, never merged, learned
behavior **reimplemented** under normal spine ceremony. "It's already written,
let's just tidy it up" is prototype laundering — the failure mode this contract
blocks. Spikes inherit applicable risk-gate controls and never touch live
money or destructive surfaces.

Distinct from §9: a smoke test asks *"is this external fact true?"*; a spike
asks *"can this architecture work at all?"*.

Full contract in `references/spike-contract.md`. When the uncertainty is
*experiential* rather than technical — "which shape is right?" has no
falsifier; someone must see it — the sibling contract is
`references/prototype.md`.

---

## 10. Posture block

Asked alongside bones authoring, because its output **is** a bone. The canonical
decision procedure — the two inputs, the P-rules, the moat inventory, the
channel C-table, the two boundary artifacts, stack packaging (§8), and four
worked examples (§12) — is `references/posture-block.md`. **Read it and work
§1-§10 in order**; never derive a posture from this summary alone.

Three rules decide the outcome and are load-bearing:

- **P1 — no or ambiguous intent signal → `fully-private`.** The default-private
  fail-safe: private → public is one later ceremony, public → private is
  **impossible**. Never resolve an undecided posture to a public value.
- **P2 — intent overrides observable facts.** When the facts read one posture
  and the stated intent reads another, follow the intent and record the gap as a
  migration note. Facts are an accident of history; intent is the target.
- **Map each moat item to a channel by its carrier, never by the posture** —
  `none` | `data-overlay` | `private-package` | `repo-private`, first match wins
  (posture-block §3-§4; the inventory may legitimately be **empty**, and it is
  private — AI workspace only). A `fully-private` project can absolutely be
  `data-overlay`.

With a clear, non-conflicting intent the posture reads off the value set
`fully-private` | `source-available` | `open-core` | `fully-open`:

```bash
oss posture_set "<posture>"
```

Revenue intent (`none|license|saas`) is not its own field — it seeds the posture
bone's revisit trigger. On a `data-overlay` channel, record the seam:

```bash
oss overlay_set '<seam>'      # e.g. '$PULSE_PROMPT_DIR'
```

Then, per posture-block §5-§10: register the posture as a bone (`oss bone_add`;
touch surface = private-side modules + the seam files + composition root,
revisit trigger from the revenue intent); author `PUBLIC_BOUNDARY.md` at **each
public repo root** — **no moat item is ever named there**, and even a
fully-private project authors it; route the **private boundary inventory** (item
→ channel → location → seam → leak-risk) to the AI workspace. Provisioning is
deferred to Plan D: never call `add-private-core`, never edit the pairing
manifest (ossify writes `project-state.json`; workspace-init owns the manifest).
Set `project.composition_root` — **required and absolute** when more than one repo is declared, optional when exactly one is (posture-block §10)
and the root is unambiguous (then `oss composition_set "<root>"`).

---

## 11. Spec-core critic moment

Fires **once**, at spec-core close: first author the lean MASTER-SPEC here, all
seven sections (section 7 applies §12's floors; §13 lists the spec as an output,
not a later step), then audit it **before the bones harden**. The audit is ossify's own
`challenge` skill in audit mode; it always runs — no plugin's absence skips it.

1. **Announce**, then end the turn: *"Spec-core close — running a close-depth
   audit on the lean MASTER-SPEC + bones registry + skeleton-cut before the
   bones harden. Type `skip` to bypass."*
2. **Wait.** If the user types `skip` (case-insensitive), continue to §12 and
   say so in §13's hand-off; in a non-interactive run, proceed and say the same
   — the audit ran with no operator answer. That line is the record.
3. **Run the audit.** Read
   `skills/challenge/references/audit.md` (relative to the plugin root) end to end and
   follow it: the lean MASTER-SPEC is the artifact, the depth is `close`.
   Whether an external fresh-frame adversary joins is the adversary ladder's
   decision (`challenge/references/adversaries.md`), and the audit's summary
   names what ran.
4. **On return, disposition-triage** the standing challenges: auto-accept
   spec-aligned ones (fold into the spec + bones ADRs and say what you
   folded); escalate load-bearing / vision-touching ones to the user; reject
   out-of-scope ones (the retired artifacts) with a stated reason; escalate
   anything ambiguous. Surface a short digest of the triage.

**Advisory, never a gate.** A standing challenge the user declines is recorded
and the flow continues.

Full mechanism — the audit contract and the disposition asymmetry with the
release veto — in `references/critic-moment.md`.

---

## 12. Lean-bootstrap Release-0 minimums

Onboarding-to-first-code is measured in **days**. Recap the floors with the user
before closing, so nobody mistakes thinness for incompleteness — journey map:
one core journey; bones: only what the skeleton touches (the rest answered
`not-applicable` + a revisit trigger); risk gates: only what the skeleton can
reach; fake ledger: skeleton shells only; feature map: may be three lines;
posture: may be "default-private, revisit at MVP"; memory bank: Tier-0 real,
the rest thin but true.

A close with four `not-applicable` bones and a five-line feature map is a
**successful** close — provided every category was asked.

Full minima in `references/lean-spec-schema.md`.

---

## 13. Outputs

| Output | Routed to |
|---|---|
| Lean MASTER-SPEC (7 sections) | AI workspace |
| EXECUTIVE-SUMMARY | per manifest routing |
| Memory bank (15 files) + `AGENTS.md` + `CODING_STANDARDS.md` | AI workspace, per `references/reviewer-home.md` |
| Bones-registry ADRs | the project's ADR directory |
| Seed feature map | `project-state.json` (already written via `oss feature_add`) |
| `PUBLIC_BOUNDARY.md` | **each public repo root** |
| Private boundary inventory | AI workspace — `docs/private-boundary-inventory.md` |
| Class H history (per repo: commit count, what is at `HEAD`) | `06-progress.md`, the spec-core-close entry |

The memory bank + `AGENTS.md` are authored **by ossify**, in conversation, from
the lean spec sections — not by calling scaffold-onboard, whose brief targets the
retired 10-phase schema. Never emit fill-in markers; thin-and-true beats a `TODO`.
**Never write over an existing file:** honour the per-file answers §3 collected (`references/occupied-destinations.md`). `06-progress.md`'s spec-core-close entry records class H history (§3): per repo, commit count and what is at `HEAD`; where `06-progress.md` is an occupied destination the operator kept, that history goes in the §13 hand-off message to the operator, as a refusal's does.

Full derivation brief in `references/memory-bank-brief.md`; section schema in `references/lean-spec-schema.md`.

Before handing off, run the state gate and surface anything it reports:

```bash
oss doctor
```

**That is the gate, not a sweep** — `state`, `schema`, `replay`, `shape`, and
nothing else. A fresh project has no ledger, fakes or patch records to report
anyway, so the gate is the right check here; if you want the advisory surfaces
(a held lock, orphan worktrees), say so and run the **`ossify:doctor`** skill (OMP: `skill://doctor`), which is a
different skill and is not invoked by running this one.

Then close by naming the next step: **`/plan-release`** to plan Release 0 with
the skeleton spine pre-seeded from the cut.

---

## 14. Slash-command interaction

The `/start` slash command (`commands/start.md`) passes `$ARGUMENTS` to `bash -c`
as a trailing argument — on shim-less channels (`Skill()`,
natural language), read the name from the invocation text.
**Parse `$ARGUMENTS` in bash; never reference `$1`/`$2`/`$N`** — Claude Code
substitutes positionals at render time and corrupts them.

The only argument is an optional project name, passed to `oss init`. When it is
absent, ask for it before initializing — the name is the project's identity in
state and is awkward to change later.

---

## 15. Anti-patterns (do not do these)

- **Enumerating exhaustive FR/NFR, or authoring PRD/SRS/BACKLOG/PROJECT_PLAN or
  a multi-year roadmap.** Retired or grown at release closes. If the user asks,
  the answer is *"that's a release-close artifact — it will describe what
  actually shipped."*
- **Naming a moat item in `PUBLIC_BOUNDARY.md`.** The file is public. Patterns
  and prose rules only; the inventory is private.
- **Resolving an undecided posture to anything public**, or deriving posture
  from observable facts when the owner's intent contradicts them.
- **Reading the moat channel off the posture** instead of off the item's carrier.
- **Calling `add-private-core` or editing the pairing manifest.** Plan D owns
  provisioning; workspace-init owns the manifest.
- **Skipping a bones category silently.** Answer or `not-applicable`.
- **A bone with no touch surface**, or a date-based revisit trigger.
- **Assuming a crate name/version instead of smoke-testing it**, or leaving a
  claim neither verified nor marked `unverified`.
- **Merging a spike.** Disposable by contract; reimplement, never launder.
- **Reintroducing a "tracer" / "semi-disposable prototype" track.** Rejected on
  record (spec §15 decision #11) — it reintroduces the laundering seam. The
  disposable spike plus a lean Release 0 covers both tracks.
- **Treating the critic moment as a gate**, or firing it more than once.
- **Creating releases, spines, or work items here.** `plan-release` owns them.
- **Letting this body exceed 500 lines.** Hard cap; ossify's whole premise is a
  small front-loaded skill surface. Move depth into `references/`.

---

## 16. Notes on tool boundaries

- **You** (Claude reading this body) make every judgment call: how to phrase a
  journey line, where the skeleton cut falls, whether a category is genuinely
  `not-applicable`, whether an uncertainty deserves a spike, which posture the
  intent signal supports, how to triage a critic challenge.
- **`oss`** (the dispatcher over `lib/*.sh`) handles mechanical state only —
  the verbs `oss help` lists: state CRUD, registry adds, and probes. It holds
  no judgment and never should.
- **`challenge` (audit mode)** is ossify's own critic. As a ceremony caller
  it hands back every consolidated finding unwalked — no internal rebuttal —
  and the disposition pass below is where those findings are ruled on.
- **Peer entry skills:** `plan-release` owns Release 0, spine classes, and the
  critic veto; `plan-spine` owns decomposition and demo lines. `doctor` **ships
  as of v0.3** and owns state inspection, lean-spec validation, machine-checkable
  rule authoring, the Claude/Codex interop check and the budget check — route
  there rather than re-deriving any of them here. This file's §11 stays the
  spec's authoring-time check; `doctor` is the one that runs later, against a
  spec that already exists.
- **The user** is the final authority. You surface candidate maps, cuts, bones,
  postures, and critic challenges; they accept, edit, or skip. Never auto-finalize
  a decision the user has not seen — and always escalate the contested cuts.
