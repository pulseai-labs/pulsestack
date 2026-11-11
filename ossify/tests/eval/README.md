# ossify planning-judge eval harness

LLM-as-judge harness for ossify's judgment surfaces (spec §13.4). Session-driven
(no API runner); subscription-funded via Agent dispatch. Plan B authors these
fixtures + the local gate; Plan D consolidates them into THE ship gate.

## Surfaces → owning skill

| Surface | Owning skill | The judgment |
|---|---|---|
| `posture-derivation` | `start` | derive posture + moat channel from facts + intent |
| `spike-contract-integrity` | `start` | offer a disposable feasibility spike only on genuine architectural uncertainty, with a six-field contract written before any code (one hypothesis, falsifier first, timebox, `code_fate: discard`, evidence retained, the enabling bone) |
| `risk-gate-registration` | `start` | register a risk gate for an irreversible-harm surface with the controls its family attaches, a touch surface, the Release-0 minimum, and the downstream bone-reclassification + docs trigger |
| `start-topology-authoring` | `start` | the A1 topology probe (§3): the verbatim refusal, authoring `.ossify/topology.json` only at A1 and only on refusal, the full re-probe across every declared repo with a halt on any still-refusing one, and never overwriting an existing topology or pairing declaration |
| `start-occupied-destination` | `start` (§2, §3, `references/occupied-destinations.md`) | never write over an existing file: past §3's gates and before `oss init`, name every occupied destination and ask per file (keep or move aside), with no default and no automatic move or merge; §2's ask-first guard fires on a MASTER-SPEC of any schema; free destinations are written with no question |
| `start-content-gate` | `start` (§3, §13) | the canonical-content gate asks for product source at `HEAD`, not history: a declared repo with history and no product proceeds as class H and its history (repo, commit count, what is at `HEAD`) goes to `06-progress.md`'s spec-core-close entry; product source refuses and routes to `/ossify:adopt`, which takes a legacy-stack project and a plain repo alike (1.35.0); a declared `tooling_repo` is skipped; the probe proposes and the operator confirms, and where the operator says files at `HEAD` are not product the gate proceeds (1.37.0 fixture 04); with no operator to answer and any file at `HEAD` it refuses, prints what it found and what to do next (#1040, fixture 06; fixture 05 is the control where plain product source still routes to adopt) |
| `start-reviewer-home` | `start` (§13, `references/reviewer-home.md`) | the reviewer home lands only in the AI workspace: a standards stub with a header, pointers only for docs that exist and one state sentence (no entries, no `TODO`), an empty-headed review ledger, and a model-free `## Review` governance section; an occupied destination is named and asked, never overwritten; a public or declared-repo workspace root is refused |
| `adopt-reviewer-home` | `adopt` (`start/references/reviewer-home.md` §5, §6) | the history pass proposes only classes that recur in two or more PRs, each citing its PRs, a rule and a Why; only accepted entries are written; an existing `CODING_STANDARDS.md` is untouched and the proposals go to `ADOPTION.md`; the `Reviewer home:` result line is present (in `## Review` for a standalone run on an existing project); nothing lands in a declared repo |
| `adopt-plain-repo` | `adopt` (`references/plain-repo.md`) | class P (#536): the class step after A1 (no source routes to `/ossify:start`, source with a legacy stack is class L, which gains A3's `--untracked-files=all`, the C2 re-harvest, the C5 stub row and the class step, source without one is class P); A1 authors the topology in an operator-made AI workspace or refuses a product repo a resolved topology does not declare; A6 refuses before any state when no step works today; A3 exempts only the topology A1 authored this run; C4 closes Release 0 only while a step is still `shipped` after C2 |
| `adopt-multi-repo` | `adopt` | A3's per-repo-plus-workspace cleanliness sweep (dirty-tree checks run against every declared repo and the AI workspace, never canonical alone) and its default-branch check (per repo, sourced from that repo's own manifest-declared `default_branch` where one exists, else a name-and-confirm ask rather than a halt or a derived guess) — plus the two multi-repo conversions that follow the gates: a baseline recorded as one SHA per declared repo rather than one SHA for the whole product, and C3 back-deriving bones from every declared repo's `docs/adr/` directory, aggregated |
| `adopt-completion-floor` | `adopt` | §6's completion floor, run before the `oss doctor` close (its green proves integrity only): the four refusal arms — C1's journey table absent or the feature map not holding one entry per `next`/`later` step (the zero-map close exists only as an all-`shipped` waiver, operator-confirmed on the record); the posture bone absent or `posture` null or outside its four values; no closed `Release 0` in state or its stub retrospective absent; the adoption record lacking its per-station lines (verb-call counts, each C3 category `answered` or `not-applicable` operator-ruled, critic `ran`\|`skip` as the operator's typed bypass, smoke counts, a C2 result line per declared repo), a zero answered only by naming what produced it — and a legitimately thin close proceeding when every arm holds |
| `journey-line-floor` | `plan-spine` | verb+observable-outcome required; inspector phrasing banned; internal spine names its consumer |
| `spine-class-declaration` | `plan-release` | bone vs flesh vs internal-enabler vs reject-as-horizontal |
| `release-ladder-labels` | `plan-release` | the release ladder is evidence-gated not counted: v2 only on a changed promise/journey/breaking contract, MVP on independent usability, no dating, sketch labels are hypotheses |
| `bone-touch-check` | `plan-release` | a plan touching a registered touch surface auto-reclassifies to bone |
| `critic-veto-interpretation` | `plan-release` | veto→auto-bone; user override recorded; ambiguous/contradictory/stale→ESCALATE (fail-closed) |
| `run-spine-declared-repo` | `work-item` (`references/round-orchestration.md` + `references/handoff-contract.md`) | the pre-round-1 spine-branch cut as a loop over every repo hosting one of the spine's items (dirty tree, an already-existing branch, or a detached HEAD in ANY hosting repo halts, not canonical alone); the per-item spawn halt as a declared-repo check rather than a canonical-only one, so any declared repo executes; `ai_workspace` halting because it is the reserved process-record key (despite resolving at rc 0), distinct from an undeclared name halting because it was never declared at all; and each dispatched item's handoff recording `repo:` matching its own `target_repo` |
| `close-gate-integrity` | `close` | halt on a failed line; mid-flight reclassification; the fake-expiry blocking finding; quarantine vs retire; a `--verdict` file whose identity no longer matches the worktree halting the close (and a matching one closing without a dispatch); and declining to fire any of them on a clean close |
| `close-per-repo` | `close` | work-item close resolving and merging inside the ITEM's own `target_repo`, not canonical by default (`work-item-close.md` §4); spine close looping the switch-back-and-merge once per repo hosting one of the spine's items, with the spine not complete while any of them is unmerged (`spine-close.md` §3); the touch check reading ONE list built from every hosting repo's own first-parent diff, so a bone or risk-gate hit living only in a non-canonical repo still surfaces and reclassifies (`spine-close.md` §6); and the patch lane's branch guard + recorded repo key both naming the repo the patch commit actually sits in (`patch-lane.md` §5/§5b) |
| `harvest-apply-integrity` | `close` | the converted apply prose (`harvest.md` §5/§7): whole-set refusal before any write; STOP on an unresolvable bank route; identical-vs-resembling duplicate discrimination; and applying cleanly when nothing warrants any of them |
| `boundary-audit-integrity` | `close` | the release-close boundary audit's shipped core (`boundary-audit.md`): the observed-visibility gate held against the manifest's word with the posture as the intent axis; the repo set and per-role arms (every manifest repo object gets its row, the filesystem-only policy for plain non-repos, the exposed-workspace arm, the recorded-remote exposure); no silent narrowing (missing artifact / missing tool / wrong policy shape / unlocatable inventory = finding or degradation, never skip); scan-first untracked classification with the ignored-directory judgment; the semantic pass over tracked prose (S1/S2/S3 against the private boundary inventory; arguable → S1; the fully-open sweep still runs); never-auto disposition with two unblocks — the fix, or an accepted-disclosure override written to the inventory with its surface pinned, re-surfacing at every later close and never laundering a grown surface; the third verdict that keeps an overridden close out of `clean`; the recorded history pass that closes the document rules' history corpus (owed off the exposure rather than the arm, expiring when the audited ref is no longer reachable from the recorded commit, with the refs that comparison does not cover named as their own not-shipped dimension rather than as a passing check's footnote) and the working-tree pass the release-tree gate reads before it halts; the submodule descent that rides the arm (each pinned tree read by the arm's tracked-content checks under the superproject's policy and matched under both anchorings, §4 descending over the submodule's working tree while the corpus passes do not, an unaudited pin leaving the checks that could not read it INCONCLUSIVE rather than clean, and no new coverage entry); and calling a clean close clean within the stated not-shipped scope |
| `rule-authoring-integrity` | `doctor` | the converted validation prose (`rule-authoring.md` §3/§5): shape verdicts by reading (typo'd required field names the CORRECT spelling; empty values refused; per-type field sets exact); unknown types declined not re-classified, existing ones preserved; honest applied-by-agent-read enforcement language (evaluator wontfix); and appending cleanly when everything passes |
| `doctor-declared-repos` | `doctor` | the interop surface's canonical-and-ai_workspace check generalized to `ai_workspace` plus every declared repo (`interop-check.md` §3): one root-resolution `ok:`/`fail:` line per declared repo, never only two fixed names; the git-work-tree probe run against every declared repo (a bare repo or a `.git`-directory root answering `false` at rc 0, not just a nonzero rc, still fails), with `ai_workspace` alone exempt; the declared-repo set never silently truncated even when every repo is healthy, and the sole-repo case unaffected; and the closing statement naming a failure regardless of which declared repo it belongs to |
| `doctor-provenance` | `doctor` | always-on and targeted provenance: answering binary, loaded doctor body, and expected reference named separately with `ok`/`warn`/`partial`; version mismatch alone triggers prior-use reporting, limited to transcript-evidenced `oss` verbs and loaded product prose, with no unused-tree audit or rerun verdict |
| `doctor-instruction-file` | `doctor` (`SKILL.md` §7 + `references/interop-check.md`) | the `claude_md` check and the repair that runs only on the operator's yes: `AGENTS.md` and `CLAUDE.md` lines matching the fixture's files exactly (root and `.claude/`, one `fail:` line per path found); nothing written before the yes, the right §5.3 branch after it (§5.2's one plan where both `CLAUDE.md` paths exist), and a no leaving the tree untouched; merge fidelity (every rule and fact kept, pointer-only lines dropped, a disagreement shown to the operator rather than resolved silently, the whole merged file shown before the write); every `@` import listed with whether it resolves after the move, and no commit |
| `handoff-compose` | `handoff` (`references/compose.md` + `references/sections.md`) | location judged from repo evidence and stated; tracked-vs-ignored with the survivability tradeoff said aloud; reference-over-duplication (a paste request declined); checkable claim\|check rows; calling a lean §3 correct on a trivial handoff instead of padding it; and a taken file name is not overwritten (the next free name is used and the read-out says so) |
| `handoff-resume` | `handoff-resume` (`references/resume.md`, with `handoff/references/sections.md`) | drift detected with was→now and read correctly (progress vs environmental); no invented drift (age is context; a modified-but-existing reference is not drift); a missing reference reported with its successor, never fatal; a work order (an explicit path to a per-work-item `handoff.md`) is recognised as one and given the stale verdict |
| `external-executor` | `work-item` (`references/external-executor.md` + `references/correction-continuation.md` + `references/round-orchestration.md`, with `close/references/work-item-close.md` and `commands/run-spine.md`) | the optional `--external-executor` seam: the exact mode split (no flag keeps dispatching `ossify:implementer-agent`; the flag hands the round to a caller-supplied in-session procedure and calls no subagent, is never inferred, and refuses a malformed argument before the spine-branch cut); round sequencing across the seam (every same-round worktree journaled and every handoff authored in declared order before any request is built, one call of the caller procedure per round, concurrent execution permitted, results processed into close in declared decomposition order with serial merges and an unchanged barrier); result validation as a real gate whose failures are terminal (item-set equality, field parity, an `accepted` verdict, and the four-part fingerprint RECOMPUTED rather than read back from the result) with no degradation into the nested path; the one check that routes instead of halting (a `gaps-surfaced` return enters `round-orchestration.md` §6's gap loop under the 3-iteration cap and never reaches close as a result); and the two things that follow a rejection — a correction continuation to the SAME executor returning the EXISTING `complete` shape with no third mode, and Layer 4 inline under external mode, with no verifier dispatched and no mutation check; and the `--detach` mode (the lane counts no request, the caller counts executions, and the lane ends after one procedure call; without the flag the lane keeps counting and stays) |
| `work-pr-disposition` (the bundled fallback since 1.13.0) | `work-pr` (`references/loop.md`) | P1 held blocking against operator pressure; every finding dispositioned (fixed / tracked deferral / evidence-shaped `invalid`), never silently; a pre-fix verdict called stale and re-fetched on the new head (green CI ≠ reviewer ran; queued ≠ approving); terminus surfaces the ledger and stops at the merge ask |
| `patch-routing` | `patch` (+ `close/references/patch-lane.md`, `plan-spine/references/intake-and-ledger.md`, `work-pr/references/pr-body.md`) | route arrived work to exactly one lane — `/ossify:patch` for a shipped defect or a small can't-fake request, a spine planned now for a large one or a bone-decision change, the intake queue or feature map for new scope, close's direct-commit lane for a change nothing observes — then run the patch by kind (defect reproduce-first, request AC-first), cut `fix/<name>-<version>` from the fetched default branch without switching a parked spine's checkout, bump every version surface, and land it as a PR (merge-bar's lane when installed, the seven-field fallback otherwise) merged and tagged on the operator's word |
| `intake-at-planning` | `plan-spine` (`references/intake-and-ledger.md` §1) + `plan-release` (§4, `references/feature-map-grooming.md`) | list the open `from:` requests by label prefix (never a literal `from:*`), bounded and truncation-checked; give each exactly one disposition (pulled in / deferred with a reason / routed to `/ossify:patch`); record it in the planning document and on the issue; say "cannot read" and ask, never "empty", when there is no remote or no reachable forge |
| `spine-freeze` | `plan-spine` (§2, §11) + `work-item` (`references/round-orchestration.md` §7) | once a spine's first round has started, a request never becomes one of its work items, ACs or rounds — it goes to the intake queue or `/ossify:patch`; before round 1 it is plannable; the spine's own §8e amendments and §7 fix-ups are untouched |
| `ledger-read` | `plan-spine` (`references/intake-and-ledger.md` §2) + `patch` | surface only the `[KL]`/`[TD]` lines overlapping the planned surface, each pulled in / still accepted (trigger checked) / retired with evidence and deleted; one line when there is no ledger or no overlap |
| `glue-as-fake` | `plan-spine` (`references/fake-ledger-discipline.md` §1) | a consumer never waits on a provider: glue recorded as a `fake` with a provider-and-request reason, a "<provider> <version or issue> ships" trigger and a consumer-release expiry, the request filed in the provider's `from:` queue; banned fakes stay banned as glue; a shipped provider is adopted, not faked |

## Fixture format

`fixtures/<surface>/NN-description.md` with YAML frontmatter carrying the
surface's `expected_*` field(s) + a body describing the scenario the skill
judges. **Keep the body as short as full input declaration allows, and no
shorter** — the rule below governs its length, not a figure written here. (A
`≤800 tokens` cap used to stand at this spot; `boundary-audit-integrity`'s
fixtures had already outgrown it before the rule below was written down, which
is the drift a number mirrored into prose always takes. If a body runs long
enough to feel wrong, the scenario is carrying too many moving parts — split it;
do not answer by declaring less.) Frontmatter fields are per-surface (see each rubric header).
`NN-` prefixes order glob expansion only. Each surface includes at least one
negative-control fixture (expected: the safe/clean answer).

**A fixture body must declare every input its rubric scores, and the rubric is
the authority on which those are** — read it before authoring, and read it again
whenever it gains a clause, because a clause added there turns something into a
scored input across the whole surface at once. An input the body leaves unstated
does not make the fixture lenient; it makes the criterion measure the invoke
agent's guess, and the two defensible guesses — manufacture the
degradation the prose owes for a check that could not read what it needed, or
quietly assume the benign value — are indistinguishable in the score.
Measured twice on `boundary-audit-integrity`: an undeclared AI-workspace tree
state cost three criteria a point on one fixture (#220), and an undeclared
audited-ref source sat silently in fourteen of twenty-two until a judge named it.

**State inputs as facts about the scenario, never as a check's outcome.** "HEAD
is the release's audited ref" is §9's gate's conclusion wearing an input's
clothes — it hands over the answer and stops measuring the resolution. State
what the recorded base branch says, what the manifest says, and what the two
`rev-parse` calls print, and let the audit do the comparing.

**Derive the input set from the rubric in one pass; do not discover it from
judge notes.** Judges surface these one at a time, and patching one fixture per
note does not converge — the rubric is finite, so read all of its criteria, list
every input each one reads, and check the whole surface against that list at
once. `boundary-audit-integrity` took three reactive rounds and two review rounds
before this was done properly. The derivation found ten omission-classes: judges and
reviewers had already named eight of them, and two appeared in no note at all. But
the larger gap was **extent** — a class a note flagged on one or two fixtures ran to
fifteen and sixteen once the whole surface was checked against the rubric at once. A
note names a class from the instance in front of it and cannot size it.

**Where a surface has had that pass run, the result is kept** under
`derived-inputs/<surface>.md` — check a new fixture against that list rather than
re-deriving it. `boundary-audit-integrity`, `spike-contract-integrity`, `risk-gate-registration`, `release-ladder-labels`, `spine-class-declaration`, and `doctor-provenance` each have one; the remaining surfaces do not yet,
and for those the pass is still owed. The lists are downstream of the rubrics and go
stale silently, so a criterion edited to read something new owes its list a row.

## Rubric format

`rubrics/<surface>.md` lists that surface's criteria — the count is per-surface
and **each rubric is its own authority**; this file states no count and no
range, because one mirrored here drifts from the rubric that owns it, and the
parenthetical that used to stand at this spot had drifted;
the judge scores each 1-5;
**pass = ≥4 on every criterion**; the rubric's last line pins the JSON output
contract — **including the `notes` contract, which is per-surface and is
mirrored nowhere else**, so the dispatch prompt points at that line rather than
restating it. `boundary-audit-integrity` requires a note that names the CAUSE of
any criterion scored below 5 and states no length: a one-sentence cap stood
there while all 22 of its results exceeded it, and a note that names a cause is
what makes a fixture defect findable at all. The surfaces whose results do hold
to one sentence keep it. `lib/aggregate-scores.sh` reads only `.pass`/`.notes`
and validates neither, so it is surface-agnostic and the rubric line is the
whole contract — deliberately, because whether a cause was named is a judgment,
not a shape.

## Run

Session-driven — see `RUNBOOK.md`. Then `bash lib/aggregate-scores.sh`
(exit 0 = all pass, 1 = any fail — the local gate).

## Seed provenance (spec §13.4)

Fixtures seed from the evolutionary-architecture playbook's 10 acceptance
scenarios + the 3 named historical failure modes (a horizontal build dressed as
a spine; an inspector-phrased journey line; a flesh claim touching a bone) + the
3 recorded target postures (pulse-trader→fully-private, PulseDB→open-core,
PulseHive→fully-open). Scenarios 1-9 landed as fixtures in PR F2 across
`spike-contract-integrity` (1), `spine-class-declaration` (2, 4, 6),
`close-gate-integrity` + `journey-line-floor` (3, 8, 9),
`risk-gate-registration` (5), and `release-ladder-labels` (7); scenario 10
(two independent planners agree) is a post-merge agreement run — two fresh
invoke agents on one representative **classification scenario**, a judge compares
their verdicts across the playbook's four axes plus controls (§2 + §13.10) —
recorded here as evidence, not a standing fixture. The scenario is authored for
the run and is deliberately **not** a `fixtures/<surface>/NN-*.md` file: see the
record below for why lifting one measures the wrong thing. The run's full
input and both verdicts are preserved under
`evidence/scenario-10-agreement-run/`.

### Scenario 10 — the agreement run (executed 2026-08-22, post-#235)

**Scenario 10 names five things to agree on** — stage, increment type,
D-class, Risk tier, mandatory controls — and the first four are the playbook's
four independent axes (§2). ossify does not carry the playbook's vocabulary, so
the run compares each axis at the ossify judgment that answers it. Two of the
axes are answered at different rungs of the *same* ladder, which is why they are
reported separately rather than folded into one "spine class" line:

| Playbook axis (§2) | ossify judgment that answers it | Outcome |
|---|---|---|
| Product maturity (stage) | the release ladder label | **agree** — `mvp` |
| Increment type | class ladder **rung 1**, the journey gate: enabler or user-facing spine | **agree** — journey gate passes, not an `internal-enabler` |
| Architecture delta (D-class) | class ladder **rungs 2-3**, bone-ness | **agree** — `bone`, both overruling the declared `flesh` on the same rung-2 touch-surface hit |
| Risk tier | the risk gate | **agree** — warranted, family `destructive`, surface `src/retention/**,src/storage/segment.rs`, register now, `src/cli/commands.rs` excluded as entry point not hazard |
| — (mandatory controls) | the control checklist | **diverge** — whether `progressive exposure` is owed |

**Run 1 result: 4 of 5 agreed; `mandatory controls` diverged.** Run 2, against
the prose as fixed by PR #256, agreed **5 of 5 with no divergence** — the table
above is run 1's, and `evidence/scenario-10-agreement-run/README.md` carries both. That count is the
judge's own, from `evidence/scenario-10-agreement-run/judge-comparison.json` —
the judge was given the five axes and told to score increment type and D-class
separately even though one ossify ladder answers both. The planners were asked
for four judgments, and an earlier judging pass compared those four; under it
increment type was never a scored axis, so "the increment-type axis agreed"
would have been this file's reading of the planners' rung-1 text rather than a
judge verdict. The five-axis prompt is preserved because it is the one that
makes the count above a verdict.

**The mapping is coarser than the playbook's values, and the run's result
inherits that.** §13.10 names the axes to agree on; §2's table names their
values — Product / Enabler / Operational / Spike, D0-D3, Risk-0-Risk-3. ossify
carries some of these and not others: `Spike` has its own contract, and the
enabler distinction is `internal-enabler`, but there is no `Operational`, no
D-value and no Risk-N (the binding vocabulary note: D-class maps through bones, Risk tiers
through risk gates). So "the D-class axis agreed" here means both planners
reached `bone`; it does **not** mean they agreed on a D-value, because `bone`
cannot distinguish D2 from D3. The same holds for Risk — agreement is on the
gate and its family, not a Risk-N tier — and for increment type, where a binary
journey gate cannot separate Product from Operational. This is the only
granularity ossify can be measured at without importing vocabulary it
deliberately does not define — but a
reader should not read these rows as agreement on the playbook's values.
Whether a mapping that cannot express those values is sound is tracked on
**#253**, which was filed for the two-axis fold and now carries this
within-axis coarseness question too.

**That one ossify judgment answers two independent playbook axes is a design
fact, not a bookkeeping choice, and it is worth its own question** — §2 says
never use one hierarchy to represent product maturity, work type, architecture
impact and risk, and `class` spans two of those four. The run cannot settle
whether that is a violation or a deliberate compression; it is filed as **#253**.

The fold did not change any axis **verdict**: both planners passed rung 1
explicitly (increment type) and both reached `bone` on the rung-2 hit (D-class).
It is not the case that they agreed at every rung — **rung 3 is where they
split**. That moved no verdict, so the count stands; but a judgment that folds
two axes into one ladder is one that can hide a rung-level disagreement, and
this run contained one, with a second question raised alongside it.

**One further divergence sat below the five axes, plus one question that was
raised but not established.** Both concern the same thing: whether a rung the
ladder never reaches still owes its own obligations.

1. **Whether rung 3 runs once rung 2 has decided the class.** Both reached
   `bone` and both said an ADR is owed, so no axis moved — but under one reading
   rung 3 never runs, and the new bone the spine creates never gets its own
   declared touch surface, the anti-pattern `class-declaration.md` names as "the
   next spine's rung 2 cannot see it, and the registry silently stops working".
   Here the separately registered risk gate happens to cover the same paths, so
   the practical gap *largely* closes by accident rather than by rule — a gate
   over those paths is not the same record as the bone having its own declared
   surface.
2. **Whether the §7c critic-veto pass is still owed after a bone-touch hit —
   raised, but NOT established as a divergence.** `critic-veto.md` says the pass
   fires once per release-planning pass, while `class-declaration.md` introduces
   it only inside rung 4, so a reader who short-circuits at rung 2 could read the
   critic step as unreached. One planner said it is still owed and independent.
   **The other did not mention it, and silence is not disagreement** — the
   planner prompt asked for four judgments and never asked for an inventory of
   later planning obligations, so an omission is fully compatible with agreement.
   `judge-comparison.json` says so in its own words ("this is silence rather than
   a stated contrary position"). Recorded anyway because the placement question
   is real on its face and the cost of getting it wrong is real too: treating the
   pass as unreached would drop release-level feedback, since `critic-veto.md`
   §3 requires substantive non-class findings to be routed regardless. Settling
   it needs a run that asks both planners directly.

**The scenario was authored for this run rather than lifted from `fixtures/`.**
The five axes span three surfaces, and no single existing fixture
exercises them all without also stating its own dispositions in the body — the
leakage class tracked in #247. A body that hands the planner its answers would
have measured agreement-on-echo, so the run used an evidence-only scenario: a
release with the independence evidence stated and no label; a spine whose files
include a registered bone's touch surface and whose declared class is a claim,
plus one **new module, registered to nothing**, that is where the destructive
behaviour lands; and a behaviour whose defect character is derivable. That new
unregistered module is what puts rung 3 in play and what #251's consequence
rests on. No disposition appeared in the scenario.

**Both observed divergences — the compared one and the rung-3 one — were
judgment ambiguities in the shipped prose rather than misreads.** That is the
distinction the judge was asked to draw, and it is the only one it drew: a
misread is not a finding against the prose. It did **not** rule out the third
possibility, that a planner filled an undeclared gap in the scenario — see the
under-declaration paragraph below, which is why neither divergence can be
attributed to its governing sentence on this run's evidence alone.
Filed as **#250** (`risk-gates.md` §2 gives a floor of three controls and an
applicability column listing a fourth, with no rule deciding
whether an applicable control above the floor is required — and the controls CSV
is what `risk_gate_add` records and what becomes required work) and **#251**
(`class-declaration.md` §1's "an earlier rung's verdict is not revisited by a
later one" does not decide whether later rungs still *run*; only rung 1 carries
an explicit stop, and rung 3 is the sole source of the new-bone obligation, so
one reading leaves a newly created bone unregistered).

**The critic-veto question is filed as #260, and run 2 is why.** At the time of
run 1 it had no issue of its own: it was read as #251's question one rung further
on — when the ladder short-circuits, which of the later rungs' obligations
survive? — and carried there as *unestablished* rather than as a second observed
instance.

**Run 2 falsified both halves of that.** #251 is closed, fixed in PR #256, and
run 2 shows the rung-3 half did not recur — both planners ran rung 3 and both
derived the new-bone obligation. The critic-veto half *did* recur, with a
different planner pair, which is exactly the second instance run 1 could not
claim. Run 1's own note predicted this: answering #251 for rung 3 alone would
leave rung 4 with the identical gap. It did, so the gap is filed on its own.

**What this run's scenario under-declared — and what that costs the two
findings.** The scenario was built to state facts and no dispositions, and it
succeeded at that. It was less careful about stating *every* fact the judgments
turn on, which is the same declare-every-input class this suite keeps finding in
its own fixtures (#242, #247), now in a scenario written to avoid it:

- **Blast radius is not stated.** The demo line says "a series"; nothing says
  how many series a retention policy touches at once. One planner justified
  `progressive exposure` on a blast radius of "every series at once" — an
  inference, not a given. So part of the controls divergence may be an
  undeclared input rather than a prose ambiguity.
- **The scenario never says which file owns the destructive decision.** It lists
  `src/retention/policy.rs` as new and `src/storage/segment.rs` as the
  registered-surface file. A planner can read the new module as orchestration
  over an existing storage operation, or as where the new bone is created — and
  that reading, not the ladder's silence, could produce the rung-3 split.
- **The `[community-edition]` ledger state is not declared.** Both planners could
  therefore only return a conditional ("if no active line carries the prefix"),
  so that part of the controls comparison is conditional rather than derived.

**Run-1 reasoning, retained as history — both issues are now CLOSED.** #250 and
#251 were fixed by PR #256 and the premises quoted below no longer describe the
shipped prose: the destructive worked example now carries every attached control,
and `class-declaration.md` now states that every rung still runs. The paragraph
is kept because it records why each issue was held valid *at the time*, which is
what makes the run-2 result checkable rather than merely asserted.

> **#250 and #251 are not withdrawn, and here is why each survives.** #250 no
> longer rests on this run at all: its strongest evidence is that `risk-gates.md`
> §3's own `user-data-deletion` worked example sits below §2's destructive floor,
> which is a contradiction inside the file regardless of any scenario. #251's
> governing observation — that only rung 1 carries an explicit halt — is likewise
> read off the prose, not off the run. What the under-declaration costs is the
> *run's* weight as corroboration, and both issues now say so. Filed as **#254**.

**This is two runs on one scenario.** Run 1 diverged on `mandatory controls`
and on whether rung 3 still runs after rung 2 hits; both were filed as prose
findings (#250, #251), both were fixed in PR #256, and run 2 agreed on both.
That sequence is the strongest thing the series says: a divergence was traced to
a named sentence, the sentence was changed, and the divergence did not recur.

**It is still not a measured property of the prose.** n=2 on the *same*
scenario is not evidence about scenarios the series has never run, and #254
stands over both runs equally — the scenario under-declares three facts the
compared judgments turn on, so how much of the agreement is the prose and how
much is the scenario is exactly what this series cannot separate. A run on a
different scenario starts a new series and could move any axis.

**One gap outlived the fix.** Both runs split on whether the §7c critic pass is
already discharged when the scenario does not mention it. It moved no judgment
in either run, and two independent sightings are why it is filed rather than
noted.
