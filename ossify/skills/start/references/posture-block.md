# Posture block — posture, moat channels, boundary artifacts

Depth for SKILL.md §10. Implements the companion spec (public/private boundary,
2026-07-12) §3, §3.1, §5. Asked alongside bones-registry authoring, because its
output **is** a bone.

This file carries the decision procedure. Apply it in order — the steps are
ordered so that the fail-safe cases resolve before the judgment cases.

---

## 1. The two inputs

Collect both before deciding anything. They are different kinds of evidence and
they routinely disagree.

**(a) Observable facts** — what is true of the project *today*:
repo layout (single repo? public/private siblings?), what is already tracked and
where, existing boundary artifacts (`PUBLIC_BOUNDARY.md`, `.gitignore` rules),
override seams already documented in code, files present-but-untracked in a
public working tree, how docs are routed.

**(b) The owner's intent signal** — what the owner *wants*, asked directly:

> "Where do you want this to end up: nothing published, source visible but
> restricted, an open core with private intelligence, or fully open? And is
> there a revenue intent — none, license, or SaaS?"

Facts describe an accident of history. Intent describes the target. **When they
conflict, intent wins** (§2, rule P2).

---

## 2. Step 1 — Derive the posture

Apply these rules **in order**; the first that matches decides.

**P1 — No intent signal → `fully-private`.**
If the owner has not decided ("undecided", "figure it out later", "haven't
thought about it"), or the signal is ambiguous or self-contradictory, the
posture is **`fully-private`**. This is the **default-private fail-safe**
(companion §2 decision #3) and it is not a judgment call:

> private → public is **one later ceremony** (a posture-supersede with a
> full-history secrets scan, a full boundary audit, and a semantic moat scan).
> public → private is **impossible** — history is already out.

Never resolve an undecided posture to a public value "because the code looks
harmless". Ambiguity resolves private, always.

**P2 — Intent overrides observable facts.**
Where the facts read one posture and the stated intent reads another, derive
from the **intent**. Record the conflict as a note in the private boundary
inventory ("facts currently read `<X>`; intent is `<Y>`; the gap is a migration,
out of scope for this block") — but do not let it change the answer. A project
whose files sit in a public repo today and whose owner wants everything private
is **`fully-private`**, and the public repo is a migration task, not a posture.

**P3 — With a clear, non-conflicting intent, read the posture off this table.**

| Posture | The owner's position | Typical revenue intent |
|---|---|---|
| `fully-private` | Nothing published. Every repo private. | `none`, or `saas` (the service is the product) |
| `source-available` | Source visible but not freely usable (PolyForm-style restriction). | `license` |
| `open-core` | The core is open; specific **intelligence** stays private. | `license` (e.g. AGPL + commercial dual-license) |
| `fully-open` | All code open; no functionality moat. Doc routing may still tighten. | `none` |

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

Record it:

```bash
oss posture_set "<fully-private|source-available|open-core|fully-open>"
```

**Revenue intent → revisit trigger.** Revenue intent is not stored as its own
field; it seeds the posture bone's `revisit_trigger` (§5). `saas` → "revisit when
the SaaS decision lands"; `license` → "revisit when the first commercial license
is negotiated"; `none` → "revisit if a revenue intent appears".

---

## 3. Step 2 — Moat inventory

Name every item worth protecting. Candidates:

- **Data corpora** — prompts, strategies, price tables, tuned configs, curated
  datasets, personal settings.
- **Algorithms / specs** — ranking, decay, scoring, pricing logic; and the
  *written spec* of an algorithm, which is often more valuable than the code.
- **Downstream strategy** — plans, roadmaps, competitive analysis, orchestration
  planning docs.
- **Credentials and personal data** — never a moat item; these are secrets, and
  secrets are handled by the never-here rules (§6), not by a channel.

The inventory may legitimately be **empty**: a fully-open project with no
functionality moat has nothing to map. Say so explicitly rather than inventing
an item.

The inventory itself is **private** — it lives in the AI workspace (§7), never
in `PUBLIC_BOUNDARY.md`.

---

## 4. Step 3 — Map each moat item to a channel

> **The posture does not determine the channel.** Choose the channel from the
> **carrier** of the moat item — what physically holds the protected value —
> not from how private the project is. A `fully-private` project can still have
> a `data-overlay` channel; `repo-private` is *not* the automatic answer for a
> private project.

Apply in order; first match wins.

**C0 — Inventory empty → `none`.**
Nothing is worth protecting (a fully-open project with no functionality moat).
The channel is `none`. Tightening *doc routing* — keeping PRD/backlog/planning
docs in the private AI workspace and publishing only user-facing docs — is the
§7 artifact-routing rule, **not** a moat channel. Do not invent a channel for it.

**C1 — Runtime-loaded data → `data-overlay`.**
The item is files or DB rows that the public/shipped code **loads at runtime**
(prompts, strategies, price tables, personal configs), and the public code has —
or can be given — a **named override seam** pointing at a private location.
Choose this whenever the moat can travel as data, even if the project is fully
private: the seam is what keeps the boundary flip cheap later, and what keeps
the Release-0 clean-checkout test honest (a *declared* overlay env var counts as
configuration, not manual repair).

Record the seam:

```bash
oss overlay_set '<seam>'      # e.g. oss overlay_set '$PULSE_PROMPT_DIR'
```

Also record, in the private inventory: the overlay location, the loader file
that reads the seam, and the demo-env wiring.

**C2 — Code that must execute → `private-package`.**
The item is logic or a spec that cannot be carried as data — it has to run — and
the public side exposes (or can expose) a **port/trait** that a private
implementation satisfies, linked at the composition root. Choose this when the
public core stays genuinely useful without the private implementation.

**C3 — Otherwise → `repo-private`.**
No narrower seam isolates the moat: the value is diffuse, the whole repo *is*
the boundary, or nothing has been enumerated because the posture came from the
P1 fail-safe. `repo-private` subsumes the other channels — the whole repo is
private. This is the correct channel for an undecided greenfield project: there
is no enumerated moat item and therefore no seam to name.

**Multiple items.** Each item keeps its own channel row in the private
inventory. The project's headline channel is the channel of the item carrying
the **primary** protected value.

---

## 5. Step 4 — The posture is a bone

Register it in the bones registry (category 9, cross-cutting):

```bash
oss bone_add "<ADR-ref>" "Privacy posture: <posture> via <channel>" \
  "<seam files, private modules, composition root globs>" \
  "<revisit trigger seeded from revenue intent>"
```

Touch surface = the private-side modules/crates **plus the seam files** (ports,
override loaders, composition root). Free consequences, no new machinery: a
flesh spine touching the boundary auto-reclassifies to bone; the critic vetoes
misclassification; posture changes become bone-supersede ceremonies with
mandatory citation re-verification.

---

## 6. Step 5 — `PUBLIC_BOUNDARY.md` (public-safe, one per public repo)

**No moat item is ever named here.** This file is public. A public file
enumerating every private asset is self-defeating — that was the v1 draft's
defect. Rules, patterns, and prose only.

**Routing:** one file per public-facing repo root — every declared product
repo (`canonical` when a project names one that; any other, however named),
and any product-adjacent repo the pairing carries (`tooling_repo`) at its own
root when the project volunteers one; never the AI workspace or a
`private_core`, which hold the moat by design. Even a fully-private project
authors the file (hygiene is independent of visibility), so "public-facing"
names where the file lives, not the repo's observed visibility.

Three blocks:

```markdown
# PUBLIC_BOUNDARY.md

## Machine-checkable rules
<!-- Executed by the release-close boundary audit
     (close/references/boundary-audit.md) at every release close. That file
     is authoritative for which repos run these rules, which trees they are
     matched against, and what each arm does with a finding — do not restate
     any of it here. Authored at onboarding so the file exists from day
     one. -->
never-tracked: **/.env, **/.env.*, **/*.pem, **/*.key, **/id_rsa*
never-tracked: **/secrets/**, **/credentials.json
never-tracked: **/SPEC.md, docs/planning/**
fixtures-must-be: synthetic

## Working-tree hygiene allowlist
<!-- Classes of untracked sensitive files known to exist in local clones,
     named by PATTERN only — never by content description. -->
- `SPEC.md` (untracked, gitignored)
- `.env*` (untracked)
- `docs/private/**` (untracked)

## Never here (prose rules)
- No secrets, tokens, or credentials of any kind.
- No downstream strategy, roadmap, or competitive material.
- No non-synthetic fixtures — no real user data, ever.
- No AI-workspace material (specs-in-progress, planning docs, agent transcripts).
- No private-side implementation of a declared port; the public repo holds the
  port, never its private implementation.
```

The machine-checkable block is what the release-close boundary audit
**executes** (`close/references/boundary-audit.md` §3) — that file states which
trees each rule is matched against and on which repos, and this file does not
restate it. Author it at onboarding so the first release close has something to
read.

**Even a fully-private project authors this file** with the standard secrets
rules (companion §2 decision #5: hygiene is independent of visibility). That is
precisely what keeps a later posture flip to *one* ceremony.

---

## 7. Step 6 — The private boundary inventory (AI workspace)

The second artifact, routed to the **AI workspace** (private). A table:

| Moat item | Channel | Where it lives | Override / injection seam | Leak-risk note |
|---|---|---|---|---|

Plus the composition root and the overlay wiring. **It lives at
`<ai-workspace>/docs/private-boundary-inventory.md`** — `docs/` beneath the root
`oss repo_root ai_workspace` answers, beside the MASTER-SPEC. That address is
a **convention, not a route**: no `well_known_paths` key and no
`project-state.json` field records it and no verb writes it, which is why the
release-close boundary audit locates it by this path and reports INCONCLUSIVE
rather than guessing when it is not there. This is the file that names things; it
is consumed by that audit and by the phase-2 `migrate` flow. An adopted project
may already hold it under another name — read what is there, never create a
second one.

**Placement rule (hard):** the **AI workspace never holds product code**. Private
code requires a `private_core` repo. An implementer may not shortcut private
crates into the `-internal` docs repo.

### Accepted disclosures

A second table in the same file, **written by the release-close boundary audit,
not at `start`-time** (`close/references/boundary-audit.md` §6). It does not
exist until the first override is accepted; the audit creates it then.

| Release | Finding | Surface covered (pinned) | Reason | Date |
|---|---|---|---|---|

**The surface column is the load-bearing one, and what makes it checkable is
the audit's contract, not this file's** — `close/references/boundary-audit.md`
**§6** states what a row must pin and the two bounds every override carries,
and its **§5** states how a row is read back: matched only on the surface it
pins, and covering nothing when it pins nothing checkable. Both live there
because the audit is what writes a row and what later decides whether a hit is
the covered surface or a fresh finding. **Do not restate those rules here**;
two copies of one contract drift, and the drift would be silent on both sides.

What belongs here is the artifact: this table lives in the AI workspace with
the moat table above it, and **pruning a row is a deliberate `start`-time
edit** — never something an audit does to quiet its own output.

### History passes

A third table in the same file, also **written by the release-close boundary
audit and not at `start`-time** (`close/references/boundary-audit.md` §3). It
does not exist until the first history **review is confirmed**; the audit
creates it then. Disposing of a history finding some other way writes nothing
here — a rejection leaves any existing row standing, and an accepted gap is an
Accepted disclosures row above, not a row in this table.

| Repo | Reviewed through (commit) | Date | Moat items reviewed |
|---|---|---|---|

The last column names the moat table's `Moat item` cells the semantic half asked
about, or `none` when empty, never read as an item name.

**Commit and moat-item currency are the audit's rules, not this file's** —
`close/references/boundary-audit.md` **§3** states which repos owe a pass, what a
row must carry, and how it is read back at a later close. **Do not restate those
rules here**, for the same reason the table above does not restate its own.

Pruning a row is the same deliberate `start`-time edit — an audit does not
quiet its own output by editing what it reads.

---

## 8. Stack packaging patterns (for `private-package`)

- **Rust** — a private git-dep crate depending on the public core crate; the
  composition root (the binary) lives in the **private** repo. Mind the
  crates.io arrow constraint: a published crate cannot depend on a git dep, so
  the public core must not depend on the private crate — only the reverse.
  Math-path crates participate in the determinism fingerprint.
- **Python** — a private package (git dep or private index); wiring via
  entry-points or explicit injection at the app's composition module.
- **TypeScript** — a private npm scope or git dep; injection at the app entry
  point.

In all three the shape is identical: **public ports, private implementation,
composition at the private root.**

---

## 9. Provisioning is deferred to Plan D

When the derived channel is `private-package` and the project has no
`private_core` repo yet, **record the intent and stop**:

- Note it in the private inventory: *"`private_core` repo required for the
  `<item>` channel — provisioning deferred to Plan D."*
- Emit the same note to the user in the block's recap.
- Do **NOT** call `add-private-core` — that workspace-init helper does not exist
  until Plan D.
- Do **NOT** edit the pairing manifest. ossify writes `project-state.json`;
  workspace-init owns the manifest. This boundary is not negotiable.

The same applies to `visibility` fields on manifest repo objects: recorded as
intent here, written by workspace-init later.

---

## 10. Composition root

**With more than one declared repo, this is REQUIRED and it must be absolute.**
The rule used to read the other way round — set it only when Release 0 is
"trivially single-repo" — which is exactly backwards: one declared repo is the
case the demo runner already defaults correctly, and N>1 is the case where it
cannot. The cumulative demo is a mandatory gate at spine and release close and
it is invoked as a bare `oss demo_run`, so a multi-repo project onboarded under
the old rule could not close at all.

```bash
oss composition_set "/abs/path/to/composition/root"   # N>1: required, absolute
oss composition_set "<repo-relative composition root>" # exactly one repo: optional
```

**The value is a PATH, not a repo key** — the working directory the cumulative
demo runs from, which `oss demo_run` refuses when it does not exist: the
repo root when the binary sits at it, or the crate/workspace directory *inside*
the repo that holds it (`crates/app`). For a Rust workspace those differ, and this
field names the directory, never the repo.

Absolute under N>1 because a relative value composes against the sole declared
repo's root, and there is no sole repo. With exactly one declared repo the field
stays optional and a repo-relative value is correct; unset means the repo root.

A wrong composition root silently misdirects the demo runner at release close,
so it is worth asking rather than guessing — but under N>1 leaving it unset is
not the safe choice, it is the one that blocks the close.

---

## 11. Release-0 minimum

The posture block may be as small as: *"default-private, revisit at MVP"* — one
`oss posture_set fully-private`, an empty moat inventory, a `PUBLIC_BOUNDARY.md`
with the standard secrets rules, and one bone with a revisit trigger. That is a
complete Release-0 posture block.

---

## 12. Worked examples

These are the companion spec's own design fixtures (§2 decision #1), worked
through the procedure above.

**A. pulse-trader — facts say one thing, intent says another.**
*Facts:* public/private sibling repos; `src/agent/config.rs` documents a
`$PULSE_PROMPT_DIR` override ("the private-workspace override"); standing
discipline "moat in DATA, not code"; the system prompt currently sits in public
source. Facts alone read `source-available`.
*Intent:* the owner wants **both repos fully private**; the prompt corpus is the
moat, carried at runtime through the declared seam. Revenue: `none`.
→ **P2** (intent overrides facts): posture **`fully-private`**.
→ Moat item: the prompt corpus — runtime-loaded data with an already-declared
override seam → **C1**, channel **`data-overlay`**; `oss overlay_set
'$PULSE_PROMPT_DIR'`. Note that C3 is *not* reached: the moat is isolable behind
the seam even though the repo is private, and keeping the seam declared is what
makes a later flip cheap.

**B. PulseDB — open core, private intelligence.**
*Facts:* decay/re-rank implementations public, their spec (`DECAY_SPEC.md`)
private; a large `SPEC.md` untracked-but-present in the public working tree
(gitignored); a written `PUBLIC_BOUNDARY.md` exists.
*Intent:* core DB open, the ranking/decay intelligence + spec stay private.
Revenue: `license` (AGPL + commercial dual-license).
→ **P3**: posture **`open-core`**.
→ Moat item: the decay/re-rank intelligence + its spec — logic that must
execute, behind existing port traits → **C2**, channel **`private-package`**
(a private crate implementing the public ranking port). The untracked `SPEC.md`
belongs in the working-tree hygiene allowlist by **pattern**, never by content.
→ Revisit trigger seeded from `license`.

**C. PulseHive — fully open, doc routing only.**
*Facts:* orchestration prompts in public source; PRD/Backlog publicly tracked;
a written `PUBLIC_BOUNDARY.md` exists.
*Intent:* code **fully open**, no functionality moat; tighten doc routing so only
user-facing docs are public (PRD/Backlog/orchestration-planning docs → private
AI workspace). Revenue: `none`.
→ **P3**: posture **`fully-open`**.
→ Moat inventory **empty** — the doc-routing tightening is §7 artifact routing,
not a moat → **C0**, channel **`none`**. Add the planning-doc paths to the
`PUBLIC_BOUNDARY.md` machine-checkable never-tracked rules.

**D. Fresh greenfield tool — undecided.**
*Facts:* single repo, no boundary artifacts yet.
*Intent:* **not decided** ("figure it out later").
→ **P1** fail-safe: posture **`fully-private`**. Not `fully-open` because the
code looks harmless; not "defer the question".
→ No moat item has been enumerated and there is no seam to name → C1 and C2 do
not apply → **C3**, channel **`repo-private`** (the whole repo is the boundary).
→ Still author `PUBLIC_BOUNDARY.md` with the standard secrets rules (§6), so the
posture can flip in one ceremony.

---

## 13. Anti-patterns

- **Naming a moat item in `PUBLIC_BOUNDARY.md`.** The file is public. Patterns
  and rules only.
- **Resolving an undecided posture to anything public.** P1 is a fail-safe, not
  a suggestion.
- **Deriving from observable facts when intent contradicts them.** P2.
- **Reading the channel off the posture.** A private project can be
  `data-overlay`; an open-core project is not `repo-private`.
- **Calling `add-private-core` or editing the pairing manifest.** §9.
- **Skipping `PUBLIC_BOUNDARY.md` because the project is private.** Hygiene is
  independent of visibility (companion §2 decision #5).
- **Treating a secret as a moat item.** Secrets are never-here rules, not a
  channel.
