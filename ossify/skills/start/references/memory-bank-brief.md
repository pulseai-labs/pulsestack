# Memory-bank derivation brief (ossify-owned)

Depth for SKILL.md §13. This is **ossify's own** derivation brief — the memory
bank and `AGENTS.md` are authored here, from the lean spec sections, not by
calling scaffold-onboard. The 15-file structure and the harvest mechanics carry
over unchanged; only the *derivation source* is re-anchored.

You author these files yourself, in conversation, reading the lean MASTER-SPEC
sections named below. There is no deterministic renderer and no template
slot-fill.

---

## 1. Source mapping (lean spec → memory bank)

| Memory-bank file | Load tier | Derived from (lean spec section) |
|---|---|---|
| `index.md` | **Tier 0** | This table |
| `00-project-brief.md` | **Tier 0** | Vision narrative + skeleton cut (§1, §3) |
| `01-product-context.md` | branch | Journey map (§2) — actors, flows, ubiquitous language |
| `02-system-patterns.md` | branch | Bones categories 1, 2, 3, 4, 6, 7 + posture bone |
| `03-code-patterns.md` | branch | Bones category 8 (stack) + the **machine-checkable rules** section (seeded empty) |
| `04-tech-context.md` | branch | Bones category 8 + the verified/unverified claims from the smoke-test pass |
| `05-active-context.md` | **Tier 0 · LIVE** | Current position: "spec-core closed; Release 0 not yet planned" |
| `06-progress.md` | branch · LIVE | One dated entry: spec-core close, with class H history when §3 recorded any |
| `07-constraints.md` | branch | Risk gates + bones categories 5, 9 (trust boundaries; cross-cutting constraints) |
| `08-governance.md` | branch | Pointers: bones ADR dir, `PUBLIC_BOUNDARY.md`, private inventory, `project-state.json` + the **standing orders** section (seeded empty); also a `## Review` section per `reviewer-home.md` §4 |
| `09-known-issues.md` | **Tier 0 · LIVE** | **Unverified claims** from the smoke-test pass; any spike `inconclusive` result |
| `10-decisions-log.md` | on-demand · LIVE | Bones-registry index (one line per bone, with its revisit trigger) |
| `tech-debt.md` | branch · LIVE | Empty index. ossify adds no lines — merge-bar's `working-a-pr` writes `[KL]`/`[TD]` after a merge; `plan-spine` and `/ossify:patch` read it and delete only a line retired because its code is gone (`plan-spine/references/intake-and-ledger.md` §2) |
| `review-ledger.md` | on-demand · LIVE | Empty heading + paragraph; merge-bar `working-a-pr` §5 appends; see `reviewer-home.md` §3 |
| `WORKFLOW.md` | branch · STATIC | The ossify loop: `start` → `plan-release` → `plan-spine` → `close` |

Two files earn special attention at bootstrap:

- **`09-known-issues.md`** is where every `unverified` claim lands. This is the
  single highest-value Tier-0 line at Release 0 — it is what stops the next
  session from building on an assumption nobody checked.
- **`10-decisions-log.md`** mirrors the bones index, including
  `not-applicable` bones. A future reader needs to see the questions that were
  asked and deliberately parked, not only the ones that were answered.

---

## 2. Release-0 minimum per file

- **Tier 0 files** (`index`, `00`, `05`, `09`) get **real content**. They are
  loaded on every call; a placeholder here is actively harmful.
- **Branch files** are seeded **thin but true** — a few lines each, no
  fill-in markers, no invented detail. If a bone was `not-applicable`, the
  corresponding memory-bank section says so and names the revisit trigger.
- **`03-code-patterns.md`** ships with an empty `## Machine-checkable rules`
  section (the heading present, no rules). Rules are authored later via the
  rule-authoring flow routed from `doctor`.
- **`08-governance.md`** ships with an empty `## Standing orders` section
  (the heading present, no orders). An absent or empty section settles no kind of order, so the
  lookup goes on to `AGENTS.md` (`close/references/cumulative-demo.md` §3); with no order there
  either, the operator is asked and the human walks the demo.
- **Never emit a fill-in marker** (`TODO`, `<placeholder>`, `TBD`) into a memory
  bank file. Thin-and-true beats a marker that nobody will come back to.

The bank grows by **harvest at every spine close** — the same mechanics as
before. Bootstrap does not need to be complete; it needs to be honest.

---

## 3. `AGENTS.md`

Authored at the same time, from the same sources. Contents at Release 0:

1. **What this project is** — two lines from the vision narrative.
2. **Where things are** — the memory-bank pointer + tier convention, the bones
   ADR directory, `project-state.json` (AI workspace), `PUBLIC_BOUNDARY.md`.
3. **The loop** — this project uses ossify: `start` → `plan-release` →
   `plan-spine` → `close`; spines are `bone` or `flesh`; the cumulative demo
   ledger is the standing fitness check.
4. **Hard rules for this project** — the posture (and, if not `fully-open`, that
   the moat inventory is private and lives in the AI workspace); the placement
   rule (AI workspace never holds product code); the risk gates by name.
5. **Bones with revisit triggers** — the short list, so an agent knows which
   decisions are load-bearing before it touches them.

Keep it short. `AGENTS.md` is read on every call; the memory bank is where depth
belongs. Codex and OMP read it directly. Claude Code reads it only without
`CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` in the workspace or any
ancestor (excluding `~/.claude/CLAUDE.md`). Never author `CLAUDE.md`.

Two sections are not ours to author: when the file replaced was workspace-init's
marked stub (occupied-destinations §1a), its `## Git policy` and
`## AI-trace filter` sections are carried across verbatim. They are this
workspace's git policy and its trace-filter notice, and nothing else regenerates
them.

---

## 4. Routing

- **Memory bank + `AGENTS.md`** → the **AI workspace** (they are agent
  scaffolding, not product code).
- **`CODING_STANDARDS.md`** and **`review-ledger.md`** → the **AI workspace**, per
  `reviewer-home.md` §1.
- **`PUBLIC_BOUNDARY.md`** → each **public repo root**.
- **Lean MASTER-SPEC** → AI workspace. **EXECUTIVE-SUMMARY** → per the project's
  manifest routing.
- Resolve every destination through the topology declaration — `oss repo_root
  <name>` per declared repo, `oss repo_root ai_workspace` for the workspace.
  Never hardcode against `$(pwd)`, and never write product code into the AI
  workspace.
- **Never write over an existing file.** A destination that already holds one
  is settled per file with the operator at §3, before `oss init`
  (`occupied-destinations.md`).

---

## 5. Anti-patterns

- **Calling scaffold-onboard's `scaffolding-memory-bank`.** ossify's derivation
  is decoupled by decision; the legacy brief targets the 10-phase schema, which
  does not exist here.
- **Fill-in markers.** See §2.
- **Inventing detail to fill a thin section.** A three-line true section is
  correct at Release 0; a paragraph of plausible fiction is a hallucination that
  a future session will treat as a decision.
- **Front-loading depth into `AGENTS.md`.** Every call pays for it.
- **Omitting the unverified claims.** They are the most load-bearing content the
  bank carries at bootstrap.
