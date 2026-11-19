# Evolutionary Architecture Playbook for Solo AI-First Development

> - **Status:** Accepted design reference, v0.1
> - **Audience:** Senior solo builders using AI agents
> - **Scope:** Tool-agnostic product architecture and delivery decisions
> - **Non-goal:** This document does not itself change any plugin's behavior.
> - **Delivery:** **cited source** — read where it is needed, never copied and
>   never imported. It has no plugin copy and no parity test, so nothing breaks
>   if it is edited; what depends on it is prose that cites it, currently
>   `ossify/tests/eval/README.md` §Seed provenance, whose fixtures derive from
>   this document's 10 acceptance scenarios. Re-check those fixtures if the
>   scenarios change.

## 1. Operating principle

> Map the complete journey horizontally, build one thin path vertically, then
> deepen it through evidence-driven increments.

The horizontal map shows the complete user journey and future capability
landscape. It is not a build order. The first build is a production-intent
vertical thread through the real entry point, domain behavior, required
integration seams, and observable outcome.

This playbook separates two kinds of early code:

- A **Spike/PoC** answers one uncertain question. Its code is disposable.
- A **Product Seed** is an evolvable walking skeleton. It is narrow and may use
  selective fakes, but its architecture and load-bearing behavior are real.

The distinction is code fate, not polish. If code is expected to survive, it is
not a PoC.

### 1.1 Relationship to plugin mechanics

This playbook operates one level above any plugin's mechanics. It defines what
must count as product evidence, which architecture decisions are timely, and
which controls are required before work is decomposed into sprints, work items,
or agent rounds.

## 2. Four independent axes

Never use one hierarchy to represent product maturity, work type, architecture
impact, and risk. Classify each increment on all four axes.

| Axis | Values | Question answered |
|---|---|---|
| Product maturity | Frame, Product Seed, Proof of Value, MVP, v1, Growth, Scale/Sustain, Retire | How exposed and supportable is the product? |
| Increment type | Product, Enabler, Operational, Spike | What evidence or capability does this work add? |
| Architecture delta | D0, D1, D2, D3 | How difficult is the architecture change to reverse? |
| Risk | Risk-0, Risk-1, Risk-2, Risk-3 | How much harm can failure cause? |

Sprints, work items, branches, and execution rounds are delivery containers.
They do not establish any value on these axes.

Risk tiers are always written `Risk-N`. Do not shorten them to `R1`/`R2`/`R3`:
the retired scaffold plugins used those names for their roadmap, machine-rule,
and demo contract layers, and legacy workspaces still carry them.

## 3. Decision procedure

Apply this sequence before planning implementation:

1. **State the core job.** Name the actor, trigger, and observable outcome.
2. **Choose code fate.** Learning-only work is a Spike; surviving code belongs
   to a Product Seed or later increment.
3. **Identify the current maturity stage.** Do not plan against the desired
   future stage.
4. **Classify the increment type.** Product, Enabler, Operational, or Spike.
5. **Classify architecture impact.** Choose the highest D-class touched.
6. **Classify risk.** Choose the highest plausible Risk tier until evidence safely
   lowers it.
7. **Assemble required controls.** Controls are additive:

   `required controls = stage gate + architecture-delta controls + risk controls`

8. **Plan only the current increment.** Decompose by real dependencies and
   context boundaries, not a fixed item count or LOC target.
9. **Close on evidence.** Run the appropriate journey, fitness functions, and
   promotion checks before changing maturity state.

Architecture classes and Risk tiers are cumulative: D3 inherits every D2
control, and Risk-3 inherits every Risk-2 control. No early maturity stage
waives a D2/D3 or Risk-2/Risk-3 control. A Spike using sensitive or dangerous
inputs still inherits the relevant risk controls.

## 4. Lifecycle and promotion gates

### 4.1 Frame

**Purpose:** Define the first proof of value and the smallest architecture that
can safely support it.

**Exit evidence:**

- Product Seed Contract
- complete journey map
- proof ladder
- top risks and any required Spikes
- Architecture Envelope
- first Increment Contract

Completing documents is not product progress; it only establishes readiness to
build the first evidence-producing thread.

### 4.2 Risk Proofs

Risk Proofs are repeatable activities, not a maturity stage.

Each Spike declares:

- one hypothesis
- a falsifier
- a fixed time/resource budget
- safe test data and environment
- `code_fate: discard`
- evidence retained after code deletion
- the decision enabled by the evidence

Spike code never becomes product code through cleanup-by-accident. Reimplement
the learned behavior inside the Architecture Envelope.

### 4.3 Product Seed

**Purpose:** Establish the first evolvable product spine.

**Exit evidence:** From a clean checkout, the named actor enters through the
real entry point and reaches the observable outcome without editing storage,
invoking hidden developer operations, or receiving manual repair.

The Seed includes:

- production-intent boundaries and dependency direction
- real load-bearing domain behavior
- selective fakes only behind real integration seams
- one automated golden-journey test
- CI/build reproducibility
- end-to-end error visibility
- minimal outcome telemetry
- initial architecture fitness functions

The Seed may be narrow, visually rough, local-only, and single-user. It may not
fake the hypothesis or critical invariants it exists to test.

### 4.4 Proof of Value / Personal Alpha

**Purpose:** Show that the journey is useful, not merely executable.

**Exit evidence:**

- repeated use with representative inputs
- observed outcome evidence and qualitative feedback
- hypothesis-critical fakes replaced by real implementations
- failure and support burden recorded
- Architecture Envelope updated from empirical learning

### 4.5 MVP / Limited Pilot

MVP describes minimum product scope. Pilot describes limited exposure. A build
may be both.

**Exit evidence:** A named cohort can onboard and use the product independently,
with real secrets/data lifecycle, recovery, rollback, support path, basic SLO,
and bounded failure impact.

### 4.6 v1

**Exit evidence:**

- stable and versioned public contracts
- upgrade and migration policy
- release and rollback automation
- threat review appropriate to the risk tier
- performance/capacity baseline
- verified backup and restore where persistent state exists
- accessibility treatment appropriate to the surface
- runbooks and support ownership

### 4.7 Growth / vNext

Each Growth increment improves a measured user outcome while preserving the
golden journey. A `v2` label requires at least one of:

- changed product promise
- new primary journey, including a segment change that alters the journey or
  product promise
- intentionally breaking public contract

Accumulated features alone remain v1.x growth.

### 4.8 Scale and Sustain

Scale only in response to measured pressure: latency, throughput, data volume,
cost, isolation, security, regulation, geography, or ownership. Profile first.

Sustain work begins at Product Seed and includes dependency/security cadence,
restore drills, incident learning, cost review, deprecation, retention, and
architecture-drift checks.

### 4.9 Retire

Retirement requires a consumer inventory, export/migration path,
retention/deletion policy, deprecation communication, decommissioning, and
verification that no active consumer remains.

## 5. Core contracts

The following templates are intentionally small. Fill them for the active stage;
do not pre-author distant implementation detail.

### 5.1 Journey Map and Proof Ladder

```text
# Journey Map and Proof Ladder

Actor:
Core job:

Complete journey:
| Step | Actor action | System responsibility | Observable evidence | Seed / next / later |
|---|---|---|---|---|

Proof ladder:
| Maturity stage | Hypothesis | Required evidence | Maximum exposure | Exit decision |
|---|---|---|---|---|
```

The map captures the whole journey without turning every future step into a
committed build sequence. Mark the thinnest coherent Seed path across it.

### 5.2 Product Seed Contract

```text
# Product Seed Contract

Actor and context:
Trigger:
Core job:
Observable outcome:
Success measure:
Maximum time-to-value:

Golden journey:
1.
2.
3.

Safety boundary:
Critical invariants:

Real-versus-fake matrix:
| Boundary | Real / fake / deferred | Reason | Replacement trigger | Contract evidence |
|---|---|---|---|---|

Explicit non-goals:
Cold-start invocation or interaction:
```

### 5.3 Architecture Envelope

```text
# Architecture Envelope

Runtime/deployment topology:
Domain boundary and dependency direction:
Data ownership, identity, and migration posture:
Public contracts and compatibility policy:
Trust boundaries and destructive operations:
Critical domain and quality invariants:
Provider/integration seams:
Failure visibility:
Rollback/evolution strategy:

Decision register:
| Decision | locked-now / provisional-next / hypothesis-later / not-applicable | Evidence | Revisit trigger |
|---|---|---|---|

Fitness functions:
| Invariant | Automated evidence | Frequency | Failure owner |
|---|---|---|---|
```

The initial fitness-function inventory must consider dependency direction,
provider contract tests, schema compatibility, data integrity and determinism,
security controls, performance/resource budgets, every golden journey, and
deploy/rollback smoke checks. Mark a category `not-applicable` rather than
silently omitting it.

Default to a modular single deployable. Add a separately deployed service,
whether existing work moves into it or new work is created there, only when
evidence requires independent deployment, scaling, security isolation, failure
containment, or ownership. AI providers are volatile external boundaries and
remain behind a product-owned swappable interface; this does not justify
speculative interfaces around unrelated internal algorithms.

### 5.4 Increment Contract

```text
# Increment Contract

Maturity stage:
Increment type:
Actor outcome or consuming Product increment:
Hypothesis:
Observable evidence:

Real/fake/deferred changes:
Architecture delta class:
Risk tier:
Required controls:
Fitness functions changed:

Rollout/exposure:
Rollback/failure containment:
Explicit exclusions:
Golden-journey regression:
```

### 5.5 Risk Ledger

```text
# Risk Ledger

| Risk/hypothesis | Uncertainty | Impact | Risk tier | Treatment | Evidence or trigger | Owner |
|---|---|---|---|---|---|---|
```

Risk entries describe uncertainty or harm, not generic tasks. A treatment is
one of: accept, avoid, reduce through a Product/Operational increment, transfer,
or investigate through a disposable Spike.

### 5.6 Promotion Evidence

```text
# Promotion Evidence

Current stage -> proposed stage:
Gate evidence:
Representative users/inputs:
Outcome telemetry:
Known limitations and fakes:
Recovery/rollback evidence:
Open D2/D3 decisions:
Open Risk-2/Risk-3 risks:
Decision: promote / remain / retire
```

## 6. Increment classification and closure

| Type | Admission rule | Closure rule |
|---|---|---|
| Product | Starts at a real actor entry point and improves an observable outcome | Manual journey from the real entry point, automated golden journey, outcome evidence, and preserved fitness functions |
| Enabler | Names the next committed Product increment that consumes it | Consumer remains scheduled, relevant fitness function is added, and the golden journey remains green; it cannot claim product value |
| Operational | Names a measured quality, risk, or SLO | Before/after evidence shows the intended quality change and no journey regression |
| Spike | Names one uncertain hypothesis and falsifier | Evidence and decision recorded; code discarded |

Before a golden journey exists, a component-only or locally demoable slice is an
Enabler even when it produces something visible. The first Product increment is
the increment that closes the actor-to-outcome journey.

After a Product Seed exists, later Product increments add, extend, or improve a
journey while preserving all existing golden journeys. Enablers stay at most one
committed Product increment ahead. If the consuming Product increment is
removed, the Enabler returns to the backlog unless a Risk-2/Risk-3 control
independently requires it.

## 7. Selective-fake rules

Selective fakes reduce breadth, not truth.

### Allowed when outside the tested hypothesis

- one provider instead of many
- one fixture or representative input instead of broad coverage
- an in-memory adapter behind a real persistence boundary
- a scripted external actor in CI paired with one real acceptance run
- narrow output formats, workflows, or environments
- deferred polish, scale, and optional integrations

### Not allowed

- faking the core hypothesis or actor outcome
- bypassing the real entry point or a load-bearing integration seam
- replacing critical domain, safety, money, identity, or ordering invariants
- hiding failure signals or requiring manual state repair
- using a fake with different semantics from its planned replacement
- adding speculative abstractions solely to make something mockable

Every replaceable fake records a replacement trigger and shares contract evidence
with the real adapter. Introduce a port only where a real external or ownership
boundary exists; do not abstract internal algorithms without evidence.

## 8. Architecture-delta classes

| Class | Definition | Mandatory controls |
|---|---|---|
| D0 — Local | No Architecture Envelope change | Local design and normal tests |
| D1 — Reversible boundary adjustment | Internal boundary changes that are cheap to undo | All D0 controls plus a short design note and updated fitness function |
| D2 — Contractual | Persistent data, public interface, trust boundary, deployment topology, consistency rule, or critical quality budget changes | All D1 controls plus an ADR, compatibility/migration plan, rollback path, fitness function, and architecture review |
| D3 — One-way/high blast radius | Difficult-to-reverse or broadly destructive change | All D2 controls plus a disposable experiment, alternatives analysis, independent review, staged migration, and progressive rollout |

For D2/D3 evolution, prefer expand/contract, branch by abstraction, strangler
replacement, or another staged technique that keeps the product deployable.

## 9. Risk tiers

| Tier | Examples | Mandatory controls |
|---|---|---|
| Risk-0 | Reversible local computation, no durable side effects | Standard tests |
| Risk-1 | User-visible or persistent change with low harm | All Risk-0 controls plus integration/E2E evidence and rollback |
| Risk-2 | Sensitive data, identity, money calculations, external contracts | All Risk-1 controls plus threat review, recovery tests, failure injection, auditability, and observability |
| Risk-3 | Real money movement, destructive automation, safety or regulatory exposure | All Risk-2 controls plus simulation/paper environment, human confirmation, kill switch, independent review, progressive exposure, runbook, rollback, and immutable audit trail |

Risk tier describes harm; architecture delta describes reversibility. They are
independent. A new public API can be D2/Risk-1. A local change inside an existing
live-order kill switch can be D0/Risk-3. Apply both sets of controls.

## 10. Stage-aware onboarding and documentation

Keep all ten onboarding lenses, but tag answers by decision horizon:

- `locked-now` — required for the current Product Seed or a one-way decision
- `provisional-next` — likely within the next one to three increments
- `hypothesis-later` — vision context, not an implementation commitment
- `not-applicable`

Only `locked-now` and necessary `provisional-next` answers feed current specs.

Roadmap depth is progressive:

- **Now:** next one to three increments are decision-complete.
- **Next:** outcomes, dependencies, and risks only.
- **Later:** capabilities and hypotheses only.

Generate documents when their trigger appears:

| Trigger | Required document/evidence |
|---|---|
| Always | Product Seed Contract, Proof Ladder, Architecture Envelope, Risk Ledger, active Increment Contract, ADR index |
| Persistent state | Data ownership, migration, backup/restore contract |
| Risk-2/Risk-3 exposure | Threat model, failure model, audit and recovery plan |
| Pilot | Onboarding, support path, runbook, telemetry/privacy contract |
| v1 | Release/rollback, compatibility, SLO, accessibility, operational ownership |
| Scale/Retire | Capacity/cost, deprecation, export, retention, decommission plan |

## 11. AI-assisted operating loop

Use a depth-first loop for each increment:

1. Orient on the current stage, Product Seed Contract, and live code.
2. Classify type, D-class, and Risk tier.
3. Lock the Increment Contract and required controls.
4. Invoke architecture critique only for Architecture Envelope close, D2/D3,
   maturity promotion, or post-incident redesign.
5. Decompose the current increment into natural work items and dependency rounds.
6. Implement and independently verify each item.
7. Integrate continuously and rerun the golden journey.
8. Close on type-specific evidence.
9. Record learning and update `provisional-next` decisions.

Do not author all future work-item specs upfront. Do not reopen settled
`locked-now` decisions without new evidence. Do not use agents to compensate for
an undecided product or architecture contract.

## 12. Read-only validation protocol

Before translating this playbook into automation, validate it against at least
one early-stage project without changing that project:

1. Inventory actual implementation and retained Spike evidence.
2. State the project's current golden journey.
3. Classify every planned slice by increment type.
4. Identify the first planned Product increment.
5. Count consecutive Enablers before it.
6. Draft a counterfactual Product Seed Contract.
7. Build a real/fake/deferred matrix.
8. Tag planned architecture decisions by horizon.
9. Classify D-class and Risk tier.
10. Compare time-to-first-product-evidence.
11. Confirm that later capabilities can replace or extend the Seed without
    violating the Architecture Envelope.

Validation produces a conversational report only. It does not edit the target
repository, execute a new Spike, or implement the counterfactual Seed.

## 13. Acceptance scenarios

The playbook is internally consistent only if it produces these outcomes:

1. A high-uncertainty algorithm becomes a disposable Spike.
2. A technical foundation without a consuming journey becomes an Enabler.
3. A component demo cannot close a Product increment.
4. A persistent schema or public API change becomes D2.
5. Real-money or destructive behavior becomes Risk-3 at any maturity stage.
6. A separately deployed service, split out or new, without measured pressure is
   rejected.
7. Feature accumulation alone does not justify v2.
8. A headless library may define its journey as a downstream API round trip;
   no UI is invented.
9. An agent-driven application may narrow input and output breadth while keeping
   its real agent, runtime, and observable-result seams.
10. Two independent planners derive the same stage, increment type, D-class,
    Risk tier, and mandatory controls from the same evidence.

## 14. Common failure modes

| Failure | Correction |
|---|---|
| Prototype laundering | Decide code fate before the experiment; discard Spike code |
| Foundation phase | Require a named consuming Product increment for every Enabler |
| Demo theater | Close Product work only on the real actor-to-outcome journey |
| Fake-driven false proof | Make the tested hypothesis and load-bearing seams real |
| Architecture astrology | Tag distant choices `hypothesis-later` |
| Ceremony inflation | Apply controls by stage, D-class, and Risk tier rather than uniformly |
| Premature distribution or scale | Require measured exposure or bottleneck evidence |
| Version-number theater | Reserve v2 for a changed promise, primary journey, or breaking contract |
| Invisible maintenance | Begin sustain work at Product Seed and bind it to measured risk/SLOs |

## 15. References

- Andrew Hunt and David Thomas, [The Art in Computer Programming](https://media.pragprog.com/articles/other-published-articles/ArtInProgramming.pdf) — disposable prototypes and end-to-end tracer-bullet development.
- Neal Ford, Rebecca Parsons, Pramod Sadalage, and Zhamak Dehghani, [Building Evolutionary Architectures](https://www.thoughtworks.com/content/dam/thoughtworks/documents/books/bk_building_evolutionary_architectures_second_edition_free_chapter.pdf) — guided incremental change and architecture fitness functions.
- Martin Fowler, [Is Design Dead?](https://martinfowler.com/articles/designDead.html) — evolutionary design, refactoring, and reversibility.
- Jeff Patton, [The New User Story Backlog is a Map](https://jpattonassociates.com/the-new-backlog/) — mapping the whole journey while selecting thin release slices.
- Google SRE, [Canarying Releases](https://sre.google/workbook/canarying-releases/) — progressive exposure and evidence-driven rollout.
