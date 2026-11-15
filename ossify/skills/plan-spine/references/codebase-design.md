# Codebase design — deep modules and where to cut

Depth for SKILL.md §4. Decomposition keeps making one decision that the DAG
never sees: **where the module boundaries fall** — a new port, a split of a
module that grew two jobs, the seam a work item will build against. This file
is the vocabulary for making that cut deliberately instead of inheriting it
from the first file layout that came to mind.

---

## 1. When this file applies

- Decomposition creates a **new boundary** — a port, a service, a module
  that did not exist before this spine.
- A **bone spine** is creating the architecture its ADR will record, and the
  interface is the part the ADR's one-line decision does not settle.
- A work item **extends an existing seam** and the question is whether the
  seam holds or the addition belongs inside.

Not for flesh work that lands entirely on existing bones through existing
interfaces — there is no boundary decision to make, and inventing one is
ceremony inflation.

---

## 2. Deep versus shallow — the one measure

A module is **deep** when a small interface fronts a lot of behaviour: the
caller's knowledge is small, the module's work is large, and the difference
is complexity the rest of the codebase never pays for. A module is
**shallow** when its interface restates its implementation — a wrapper whose
caller must know everything the wrapped thing knew, plus one more layer.

The measure is the ratio: **what a caller must know, over what the module
does.** Three methods hiding retry, batching, and recovery = deep. Seven
methods that each map to one internal call = a pass-through with opinions.

Interface here means the whole contract a caller depends on: signatures,
plus ordering rules, error shapes, and state assumptions. A three-method
port whose caller must call them in a documented order is wider than it
looks — the ordering is interface too.

---

## 3. Where to cut — three tests for a seam

1. **The hiding test.** Name the thing most likely to change (a vendor, a
   format, a policy). It belongs *behind* the seam; if changing it means
   touching callers, the boundary is in the wrong place.
2. **The description test.** Can you say what the module does without saying
   how? *"Persists orders, retries transient failures"* survives; *"wraps
   the Postgres client"* is an implementation with a door on it.
3. **The test-through test.** The module is testable through its interface
   alone. A test that must reach inside to set up or assert is the boundary
   confessing it leaks — and that test will break on every refactor the
   seam was supposed to make safe.

### A module boundary is not a deployment boundary

The three tests above decide where a **seam** falls. They say nothing about
whether the two sides run in the same process, and they must not be read as
if they did: every one of them is satisfied by a deep module inside a single
deployable. Splitting a seam into a **separately deployed** service — its own
process, image, pipeline and on-call surface — is a different decision with
its own bar:

> **Default to a modular single deployable.** Add a separately deployed service
> only on measured pressure, whether moving existing work into it or creating
> new work there. Evidence must require independent deployment, independent
> scaling, security isolation, failure containment, or separate ownership.
> Absent that evidence, cut the seam and keep it in-process.

"Measured" means evidence that already exists and someone can point at —
not always a number. A profile showing this component is the bottleneck, a
load figure it cannot meet in-process, an outage where its failure took the
rest down; equally an enacted compliance rule that forbids co-location, or an
ownership transfer that has actually happened. The test is that it is
contemporaneous and checkable, not that it is numeric.
**An anticipated one does not count** — "it will need to scale
independently" is the architecture astrology this bar exists to refuse, and
a seam cut cleanly today can be deployed separately later at far lower cost
than an unwind.

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

When the evidence is absent, **say so and keep the single deployable**; the
split becomes a feature-map entry, not a rejection to re-litigate. **The map
has no trigger field** — `oss feature_add` takes `name`, `value`,
`class_guess`, `source`, and a fifth argument only for an intake request's issue
number, so it refuses a trigger passed there —
and there is no update verb to add one later. Encode both halves in the `value` line —
*"<the value the split unlocks> — admitted when <the evidence>"* — because a
condition recorded nowhere is a deferral that cannot be evaluated at the next
re-groom, and a `value` overwritten by the condition loses the thing the field
is for.

When the evidence exists, name it in the spine spec — the split is a
system-shape decision, so it is `bone`-class (`plan-release/references/class-declaration.md` rung 3,
category 1), and the evidence is what its ADR records as the decision's
grounds. A bone ADR that records *that* a service was extracted without
recording *what pressure* required it leaves the next reader no way to tell a
measured split from a speculative one.

**The bar first binds at selection**, before any spine is minted
(`plan-release` §5a; `plan-release/references/feature-map-grooming.md` §3). Its class ladder re-checks it
at rung 3 (`plan-release/references/class-declaration.md`), including retirement
of a minted spine that fails. This page loads later, at decomposition; it must
not be the first place an unsupported deployment is refused.

---

## 4. Relationship to bones — decision versus craft

A **bone** records the load-bearing *decision*: "hexagonal architecture",
"one queue per tenant" — an ADR with a touch surface and a revisit trigger
(the bone contract: `start`'s `references/bones-registry.md`; the class
ladder that consumes it: `plan-release/references/class-declaration.md`). This file is the craft
*inside* that decision: the bone says a port exists; codebase-design says
the port has three methods, not seven, and the adapter hides the retry
logic.

They are referenced together when a bone-class spine creates a boundary —
and the debate belongs at **plan time**, not in review after the code
exists. The interface's written home under the current spec contract is the
**providing work item's spec** (per-item spec text is authored at its
round's start, so a same-round consumer's spec *cites* it — one home, no
duplication); the ADR records the decision and its touch surface.

---

## 5. What this buys the DAG

The seam decision is also a scheduling decision, and SKILL.md §5's round
identification consumes it directly:

- work items cut **along** seams do not share files, so rounds parallelize
  without the merge-conflict tax (`dag-rounds.md` §2's false-edge table);
- an interface **fixed in writing at plan time** (the providing item's spec,
  §4) lets a consumer item *code to* the contract before the implementation
  lands — the edge drops only when the consumer can **build and verify
  independently**; when it must compile against A's landed artifact (the
  trait, the schema, the generated package), the edge stays (`dag-rounds.md`
  §2's carve-out);
- a boundary that keeps generating cross-item edges is the DAG telling you
  the seam is in the wrong place — the same signal `dag-rounds.md` §5's
  cycle rule reads at item scale.

---

## 6. Anti-patterns

- **The mirror interface.** One public method per private function; the
  module hides nothing and doubles the reading.
- **Seven methods "for flexibility."** Every speculative method is interface
  the module must honour forever; depth comes from removing caller
  knowledge, not from anticipating callers.
- **Splitting by layer instead of by seam.** A "models module" and a
  "handlers module" is the horizontal build at module scale — the same
  failure the skeleton cut exists to prevent (`start`'s foundation-phase
  smell, recut vertically).
- **Extracting a service on an anticipated load.** Premature distribution
  buys an operational surface now against a bottleneck nobody has measured;
  the seam is the win, the separate deployable is the bill (§3).
- **Deepening a module no journey needs.** Interface polish on a module
  nothing exercises is gold-plating; the journey-line floor owns "needed".
- **Debating the boundary in code review.** By then the interface has
  callers. The spine spec was the moment; review is where that debate goes
  to lose.

---

*Prior art: mattpocock `codebase-design` (deep modules, clean seams);
superpowers `brainstorming` (the Socratic upstream of a boundary debate).
Lineage, not source — this doc is ossify's own.*
