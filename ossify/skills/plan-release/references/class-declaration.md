# Class declaration (bone / flesh / internal-enabler)

Depth for SKILL.md §7a. **Class is the only classification.** There is no size
axis, no weight axis, no "small bone" — a spine's class answers one question:
*does this spine move a bone?*

| Class | Definition | Ceremony |
|---|---|---|
| **bone** | Creates or modifies a bone — the skeleton itself, a new boundary, a new cross-cutting contract, a data-ownership change, a stack decision | Full: grill gates at planning, full close-depth audit with the external adversary when one is configured, full retro, ADR required |
| **flesh** | Lands entirely on existing bones — features, deepening passes, polish | Core rows only, plus a light host-only critic pass that includes a mandatory bone-touch check |
| **internal-enabler** | Not a user-facing spine at all: no actor-to-outcome journey. Rare, and admission-gated | See §4 — it is a *verdict*, and admission is a separate judgment |

Core rows (impl-check, cumulative demo, memory-bank harvest, handoff/state,
worktree cleanup) are **never skippable in either class**. Class controls the
rows *above* the core, not whether the core runs.

---

## 1. The ladder (run in this order)

Order matters, and it decides two separate things. **An earlier rung's verdict
is never overridden by a later one** — once a rung sets the class, no later rung
changes it. **Every rung still runs anyway**, because the later rungs carry
obligations of their own that an earlier verdict does not discharge — rung 3 is
the only source of the new-bone obligation, and skipping it is how the registry
rots. The one exception is rung 1: an `internal-enabler` verdict stops the
ladder outright, and its own text says so.

### Rung 1 — the journey gate

> **Does this spine deliver an actor-to-outcome journey?** A named actor performs
> an action and reaches an observable outcome they came for.

If **no** — the spine only builds an architectural layer, and its stated evidence
of completion is that an *artifact exists* ("the migration runs and the tables
exist", "the module compiles", "the endpoint returns 200") rather than an actor
reaching an outcome — it is an **`internal-enabler`**. It is **never** accepted as
a user-facing `flesh` or `bone` spine, no matter how much architecture it moves or
how obviously it will be needed. Stop the ladder and go to §4.

This is the mechanical anti-foundation-phase rule. "The UI will consume it
someday" no longer qualifies as product value.

**Do not over-trip this gate.** It fires on *positive evidence of a missing
journey* — an artifact-existence demo, or a plan that names no actor at all — not
on the mere presence of architecture. A spine that introduces a load-bearing
architecture **and** carries the journey that exercises it is a **bone spine**,
not an enabler. Introducing a bone is not by itself horizontal; §3's contrast
table is the discriminator.

**The actor does not have to be human.** Spec §3: a headless product — a library,
a database, a service — "defines its journey at its real surface, e.g. a
downstream API round trip, and no UI is invented." For a headless product the
actor *is* the consumer of its interface, and a spine that carries a real round
trip through that interface passes rung 1.

The ban is on **artifact-existence**, not on non-human actors. Read the anti-
example above precisely: "the endpoint returns 200" fails because a status code
is not an outcome anyone came for — **not** because an API is involved. The same
endpoint, exercised as *"a downstream service submits an order through the client
and gets back a confirmed order id"*, is a journey.

| Spine | Rung 1 |
|---|---|
| "the migration runs and the tables exist" | ✗ artifact existence |
| "the endpoint returns 200" | ✗ a status code is not an outcome |
| "the module compiles" | ✗ artifact existence |
| **"a downstream service queries the store through the client SDK and gets results ranked by recency"** | **✓ a consumer reaches an outcome through the real surface** |

Getting this wrong on a headless project mis-trips `internal-enabler` on **every
legitimate spine**, because every one of them lands at an API rather than a
screen — and an internal-enabler cannot claim product value, so the whole product
becomes unable to demonstrate any. `plan-spine/references/demo-authoring.md`
§3.2b states the same rule for demo lines; the two must agree.

### Rung 2 — the bone-touch judge (mechanical)

> **Does the spine's plan touch a registered bone or risk-gate surface?**

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

`oss touch_check <paths…>` — rc 0 means matched. A hit → **`bone`**, regardless of
the declared class, regardless of the critic. rc 2 means the judge could not run
(no paths, or an unreadable state) and is **not** a clean verdict — fix the state
before declaring. Full usage in `references/bone-touch-judge.md`.

### Rung 3 — bone by creation

> **Does the spine create or modify a load-bearing, hard-to-reverse decision?**

The bones vocabulary, verbatim from the forced-enumeration checklist: system
shape & deployment topology · module boundaries & dependency direction · data
ownership & migration posture · public contracts & compatibility policy · trust
boundaries & destructive operations · failure visibility · rollback & evolution
strategy · stack · cross-cutting constraints.

Yes → **`bone`**, and the spine owes an **ADR** (authored `Proposed`, flipped to
`Accepted` once the release exercises it) with a declared touch surface — which
is what makes the *next* spine's rung-2 check work. A new bone with no registered
surface is how the registry rots.

Rung 3 catches what rung 2 cannot: a spine that creates a bone in files nobody has
registered yet, because the bone does not exist until this spine lands.

**`System shape & deployment topology` carries an admission bar:** any spine
adding a separately deployed service — moving existing work into one or creating
a new one — needs **measured pressure** for independent deployment, scaling,
security isolation, failure containment, or separate ownership. Anticipated
pressure is not evidence; its ADR records the evidence as the decision's grounds.
Selection checks it before minting (§5a); this rung re-checks it. If a minted
spine fails, retire it with `oss spine_status "<sid>" abandoned` and return the
candidate to the feature map with the admission condition in its `value`
(`plan-spine/references/codebase-design.md` §3), as §4 does. The spine keeps its
`spine_dag` entry: its status records the retirement, and
`spine-sequencing-dag.md` §3 lists every spine exactly once.

For such a spine, persist §2's rationale with
`oss class_set "$sid" bone "<rationale>; pressure: <the measured evidence>"`
even when the declared class was already `bone`: `spine_add` stores no reason
and `RELEASE.md` is re-rendered from state.

### Rung 4 — otherwise, flesh

Entirely on existing bones. **Do not inflate it.** Bone ceremony on a genuine
flesh spine is not "being careful" — it is ceremony inflation, it costs real
hours per spine, and it trains people to skip checklists wholesale. If rungs 1-3
found nothing, the answer is `flesh` and the reason is *"lands entirely on
existing bones: <which ones it uses>"*.

Then the critic veto (`references/critic-veto.md`) may push `flesh → bone`. It
never pushes `bone → flesh`; only an explicit, recorded user override does that.

---

## 2. Stating the rationale

Every declaration carries a one-line reason naming **the rule that decided it**.
The reason is written into state (`oss class_set`'s 3rd argument, or the spine's
line in `RELEASE.md`) and read back at close.

| Rule | Reason shape |
|---|---|
| Journey gate | `internal-enabler: no actor-to-outcome journey (demo is "<artifact exists>")` |
| Bone-touch | `bone-touch: ADR-0002 (src/domain/**)` |
| Bone by creation | `creates a bone: <category> — <decision>; ADR-00NN` |
| Flesh | `lands entirely on existing bones (<bones used>); no registered surface touched` |
| Enabler admission | `internal-enabler admitted: consumed by <spine-id> in <release-id>` |

"It felt architectural" is not a rationale. Name the rung.

---

## 3. Worked contrasts

The four archetypes, including the three recorded historical failure modes.

| Spine as proposed | Rung that fires | Class | Why |
|---|---|---|---|
| "Build the persistence layer" — schema + repository + migrations, declared as a user-facing flesh spine; its demo is *"the migration runs and the tables exist"* | 1 | **internal-enabler** | Artifact-existence demo, no actor and no outcome. A horizontal build wearing a spine costume — the failure mode the methodology exists to prevent |
| "Add a second order type", declared `flesh`; plan changes `src/domain/port.rs`, listed in the hexagonal-core bone's touch surface | 2 | **bone** | The declared class is a claim; the touch surface is a fact. Facts win |
| "Add a CSV export button" — uses the existing report port and UI shell, touches no registered surface, delivers "a user exports a report and opens the file" | 4 | **flesh** | Genuine flesh. Do not inflate it because "export sounds like a contract" — nothing registered says it is |
| "Introduce the event-sourcing persistence model" — new load-bearing, hard-to-reverse persistence architecture, with an ADR and a declared touch surface | 3 | **bone** | Creates a bone. It carries the journey that exercises it, so rung 1 does **not** fire; the presence of architecture is not the enabler test |

The last two rows are the ones people get wrong in opposite directions: inflating
flesh out of caution, and demoting a real bone spine to "internal" because it
sounds infrastructural.

---

## 4. `internal-enabler`: verdict first, admission second

These are **two distinct judgments**, and conflating them is how the
anti-foundation-phase rule gets defeated. The verdict is reported as
`internal-enabler` either way — admission decides whether it enters the release,
not what it is.

**Judgment 1 — the class verdict** (rung 1): the spine has no actor-to-outcome
journey → it is an `internal-enabler`. Done. This verdict does not depend on
whether anything consumes it, and it is the answer to "what class is this spine?"
whatever judgment 2 concludes.

**Judgment 2 — admission** (spec §5.3): an internal-enabler is admitted into the
release **only if** it names the **committed user-facing spine that consumes it**,
scheduled in the **current or next release** — the one-release-ahead cap.

- Named consumer, scheduled in range → **admitted**. It must be declared as
  internal at release planning (not discovered later), it may contribute `auto:`
  demo lines only — never a `user:` journey line — and it **cannot claim product
  value** in the release's exit criteria.
- No named consumer, or the consumer is three releases out, or the consumer is
  "the UI, eventually" → **not admitted**. **Silence is not a named consumer:**
  if the plan in front of you does not name one, the answer is not-admitted — do
  not assume a consumer exists because one plausibly could. If §5c already
  minted it, retire the spine first: `oss spine_status "<sid>" abandoned` —
  there is no delete verb, and a spine left `planned` either appears in
  `spine_dag` as work nobody will do or is omitted from it, which
  `spine-sequencing-dag.md` §3 reads as *missing from the plan*. It returns to the
  feature map:

  ```bash
  oss feature_add "<name>" "<the value it would enable>" bone feature-map-return
  ```

- If the consuming spine is later **dropped**, the internal spine returns to the
  feature map too. The dependency runs both ways.

Admission is scored separately from class — `plan-spine` enforces the consumer
rule along with the demo-line floors. Do not merge them into one verdict.

---

## 5. Recording an admitted enabler

**This section applies only once judgment 2 has *admitted* the enabler.** A
non-admitted enabler never gets a spine id at all — it goes back to the feature
map (§4), and the verdict you report is `internal-enabler`, full stop.

`oss spine_add` and `oss class_set` validate their class argument against
`bone|flesh` and **exit 2** on anything else. `internal-enabler` is a planning
verdict, not a state value — do not try to write it as a class.

An **admitted** internal-enabler is therefore recorded under its structural class
— run rungs 2-4 on it to find out which — with its enabler status carried in the
spine's name and its RELEASE.md line:

```bash
sid="$(oss spine_add "$rel" "[internal] event-store schema" bone)"
oss class_set "$sid" bone "internal-enabler admitted: consumed by r1.s4 (MVP); creates a bone (data ownership)"
```

The `[internal]` marker and the reason string are what `plan-spine` reads to
enforce "`auto:` lines only". A spine minted before its verdict existed (§5c of
`plan-release` names every spine before §7a runs the ladder) takes the marker
afterwards with `oss spine_rename "$sid" "[internal] <name>"`, which changes the
name and nothing else (1.22.0). A **non-admitted** enabler is never given a spine
id at all — it goes back to the feature map (§4).

---

## 6. Release 0

The **skeleton spine** is `bone` by definition: it creates the skeleton, which is
the first bone. It passes rung 1 trivially (the skeleton cut *is* an
actor-to-outcome journey — that is what the cut question asks for) and is
declared `bone` without deliberation.

If Release 0 contains a second spine, run the full ladder on it like any other. A
Release 0 whose *only* spine is an internal-enabler is a failed skeleton cut, not
a plan — send it back to `start`'s cut question.

---

## 7. Anti-patterns

- **Accepting a horizontal build as a spine** because it is "obviously needed
  next". Rung 1 exists for exactly this.
- **Merging the enabler verdict with the admission decision.** Two judgments.
- **Admitting an enabler on "the UI will consume it someday".** Name the spine and
  the release, or it goes back to the map.
- **Inflating a flesh spine to bone out of caution.** Ceremony inflation trains
  people to skip checklists.
- **Demoting a bone spine to `flesh` because it is small.** Class is not size.
  A one-file change that moves a boundary is a bone spine.
- **Declaring class from the feature map's `class_guess` without re-running the
  ladder.** The guess was made before the plan existed; the ladder reads the plan.
- **A new bone with no touch surface.** Then the next spine's rung 2 cannot see
  it, and the registry silently stops working.
- **Passing `internal-enabler` to `oss spine_add` / `oss class_set`.** Exit 2
  (§5).
