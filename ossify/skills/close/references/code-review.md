# Code review

Depth for SKILL.md §5, between the work-item gates and step 2's merge. The
second of v0.2's absorbed capability references.

**Runs over the spine's accumulated diff, once, before the spine branch merges
into its base.** Every work item has already passed its own gate by this point —
impl-check said the ACs pass, the report accounts for them, and no documented
pattern is violated. This is the question none of those asked: **is it good code,
and is it the code the spine was supposed to write?**

---

## 1. Where it sits, and why it is not the three things it resembles

| | Reviews | Asks |
|---|---|---|
| **challenge (audit mode)** | specs, plans, `SPINE.md` | is the *design* sound? |
| **impl-check** Layer 1/2 | AC commands, the report | did every AC *pass*? |
| **impl-check** Layer 3 | the diff vs `03-code-patterns.md` | does it violate a **documented** pattern? |
| **bone-touch judge** | changed paths vs the registry | did a flesh spine touch a **bone**? |
| **this file** | the diff vs craft + intent | is it **good** code, and the **right** code? |

The gap is real and each neighbour leaves it open on purpose:

- **The audit never sees code.** It audits `SPINE.md` before the work
  exists, so it cannot know what was built.
- **impl-check Layer 3 is bounded by what is written down.** If
  `03-code-patterns.md` is silent, Layer 3 is silent — correctly, because
  relitigating unwritten rules at a mechanical gate is how a rule set stops
  meaning anything. **Everything Layer 3 declines to judge lands here.**
- **The bone-touch judge is a classifier, not a critic.** It answers *which
  class*, never *how good*.

So a spine can pass every gate ossify has and still merge a 300-line method, a
duplicated pricing rule, and a feature the spec never asked for. That is what
this reads for.

---

## 2. Two axes, run in this order — and the order is the method

**Axis A — Standards:** does the diff meet the bar for code in this repo?
**Axis B — Spec:** does the diff faithfully implement what the spine set out to
do?

**Run A to completion before you read the spine spec for B.** The separation is
the point: an agent holding the intended behaviour in mind while judging quality
rationalizes what it sees — *"the method is long because the spec asked for six
steps"* — and a reviewer who has already decided the code is good reads the spec
looking for permission. Each axis is cheap on its own and worthless once
contaminated by the other.

> **On sub-agents:** the absorption spec sketched these as parallel sub-agent
> passes. **ossify dispatches no spine review to another agent** — its workers are
> `implementer-agent` and work-item close's `verifier-agent`, and neither reviews
> a spine (`work-item-close.md` §2). Sequence
> is what buys the separation here, not isolation: finish A, write its findings
> down, *then* open the spec. Writing A's findings before reading the spec is what
> makes the separation real rather than intended.

### Getting the diff

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

```bash
# $spine_branch and $repo_base_branches (one "<repo>:<base_branch>" pair per
# line, one line per hosting repo) are ALREADY RESOLVED by the ceremony —
# spine-close.md §3 recovers both, once, before sending you here. Reuse them;
# re-deriving either is a SECOND resolver for the same fact, which is exactly
# what "one resolver, one halt, one source of truth" below is protecting.
#
# EVERY hosting repo, never canonical alone: the distinct target_repo values
# across the spine's non-abandoned work items, the same set spine-close.md §3's
# merge loop iterates (an abandoned item wrote nothing and recorded no base).
# A cross-repo spine's diff spans every one of them, and reading
# only one repo's diff reviews PART of the spine dressed up as the whole of
# it — which is worse than skipping the review, because it reads as done.
hosting_repos="$(oss get ".work_items[] | select(.spine==\"$spine_id\" and .status != \"abandoned\") | .target_repo" | sort -u)"
[ -n "$hosting_repos" ] \
  || { echo "code-review: no work items found for $spine_id - halt, cannot scope the diff"; exit 1; }
while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  repo_root="$(oss repo_root "$repo")" \
    || { echo "code-review: $spine_id names undeclared repo '$repo' - halt"; exit 1; }
  base_branch="$(printf '%s\n' "$repo_base_branches" | awk -F: -v r="$repo" '$1==r{print $2; exit}')"
  [ -n "$base_branch" ] \
    || { echo "code-review: no base_branch recorded for $spine_id in $repo - halt"; exit 1; }
  echo "=== $repo ($base_branch...$spine_branch) ==="
  git -C "$repo_root" diff --stat "$base_branch...$spine_branch"   # scope first
  git -C "$repo_root" diff "$base_branch...$spine_branch"          # the review surface
done < <(printf '%s\n' "$hosting_repos")
```

**Do not re-parse `SPINE.md` here.** A private `grep -A5 … | sed` reads a fixed
window and a fixed shape, so a spine-context block that runs past five lines,
writes the field as a paragraph, or wraps it in Markdown emphasis yields an
empty or markup-laden value. The `git diff` calls then fail, and this review —
which is advisory and does not halt — is **silently skipped** on a spine whose
merge step resolves the same fields perfectly well one step later. One resolver,
one halt, one source of truth.

**`base...spine_branch` (three dots), not `base..spine_branch`.** Three dots diffs
against the merge base, so you see what the spine *added*; two dots also shows
everything that landed on the base branch meanwhile, which is not this spine's
work and not yours to review.

### Reading the verifier's advisories

Verifier findings and mutation results are input to the two axes below, not a third
axis — but they carry the same rationalization risk §2's axis order exists to
prevent, so read them in **two passes, not one**. Each spine work item's
`<work-item-dir>/verify.md`, if one exists, is resolved the way
`work-item-close.md` §1 Route B does (the spine dir, glob-recovered, then
`work-<wi>/`); every item has already closed by the time you run, so Route B's
reconstruction is always the one in scope here, never Route A's return
payload. Every verifier pass writes one, with zero findings too; read only its findings
and mutation lines, not its `verifier:` and layer-result lines. Absent is not a gap: a
close before ossify 1.29.1 wrote one only on findings.

**Walk the non-`abandoned` items only — the same set `hosting_repos` read
above.** A withdrawn item was never dispatched: it has no `work-<wi>/` directory
and no `verify.md`, and while a `spec.md` may survive from planning, its ACs were
deliberately never implemented. Folding either one in reports a planning decision
back as a gap in the work, and the disposition loop then churns on work the plan
withdrew. Axis B reads the same set (§4).

**Before Axis A:** read only each file's `pattern`-tagged findings and mutation lines
and fold them into your Axis A findings.

**Before Axis B, once Axis A is written down:** go back to the same files and
read the `absence` and declared-`fidelity` findings you skipped — spec
material, exactly what §2 says not to hold in mind while judging Axis A. Fold
each into your Axis B findings.

Either pass: read findings and mutation lines as evidence, not your own judgment;
do not re-print them verbatim or re-judge whether the verifier was right.

**Before folding either pass's findings or mutation lines in, revalidate against the
final tree.** Each entry is evidence about the work item's own staged diff, frozen
at its close; by spine close every item has merged, and a later item may have
reshaped or fixed the code it cites. Check only whether its cited evidence still
holds in the spine diff resolved above (`base...spine_branch`) — a mechanical
citation check, not a second judgment. If it no longer holds in that form, mark
the entry **superseded** and do not fold it into either axis as current.

**This check is deliberately citation-level, on purpose, not an oversight.**
A later item can also moot a finding's underlying claim through a different
path than the one it cites — rerouting a call through a guard added
elsewhere, for instance — leaving the citation intact while the claim no
longer holds. Re-judging that is out of scope here: it is the same
rationalization channel §2's axis order exists to prevent, reopened one
layer down. A carried advisory that survives the citation check is a lead
for your own Axis A/B judgment, never a verdict — you read the code either
way, so the failure mode of under-checking here is wasted attention, not a
wrong or missed halt. Widening this into a full re-judgment of the claim is
refusal-by-design territory; do not soften it on a future review's say-so.

---

## 3. Axis A — Standards

Two sources, in this order:

**1. The repo's own documented conventions.** `03-code-patterns.md` in the memory
bank (manifest-routed — resolve it as `harvest.md` §7 does) is the written set,
and Layer 3 already checked the diff
against it at each work-item gate. Do not re-run that check — read the file for
*context*, so your craft judgments do not contradict a rule the project made
deliberately.

**2. A smell baseline**, for everything the project has not written down. These
four carry their weight; the point of naming them is that "this feels off" is not
a reviewable finding:

| Smell | The tell |
|---|---|
| **Long method** | You cannot describe what it does without "and then". Usually several responsibilities sharing a scope |
| **Feature envy** | A method that reaches into another object's data more than its own — the behaviour wants to live where the data is |
| **Duplicated logic** | The same *decision* expressed twice. Two copies of a rule diverge; the second one is found months later, still wrong |
| **Inappropriate intimacy** | Two units that know each other's internals. Changing one silently requires changing the other, and no signature says so |

**Judge the diff, not the file.** Pre-existing smell in untouched code is a note
in passing, never a finding against this spine. A spine is responsible for what it
added and what it made worse.

**A finding needs a location and a consequence.** *"`submit_order` is 180 lines"*
is an observation; *"`submit_order` at `src/orders/api.rs:88` folds validation,
pricing and persistence into one scope, so the pricing rule cannot be tested
without a database"* is a finding. The second names what it costs, so the author
can weigh it.

---

## 4. Axis B — Spec

Now read the spine's `SPINE.md` and each **non-`abandoned`** work item's
`spec.md`, and ask **three**
questions of the diff:

1. **Does it do what was asked?** Every AC passed mechanically — that is the
   floor, not the answer. An AC can pass against an implementation that satisfies
   the letter of its command and not the behaviour the spec described.
2. **Does it do anything that was NOT asked?** Scope creep at close is expensive:
   unrequested code was designed by nobody, reviewed against nothing, and is now
   the project's to maintain. Name it and let the operator decide — extra work is
   not automatically welcome work.
3. **Did the intent drift?** The spec said *"cache the last N quotes"* and the
   diff caches everything with no bound. It works, it may even be better, and it
   is **not what was agreed** — which matters because the DAG, the demo lines and
   the next spine were all planned against the agreed version.

**Drift is the finding this axis exists for.** Questions 1 and 2 are usually
obvious; drift is not, because the code is coherent, the tests pass, and only the
spec says otherwise. It is also the one nothing else in ossify can catch: the
demo runs behaviour, not intent.

---

## 5. Merging the findings, and what stops the merge

Report both axes together, each finding tagged with its axis and location:

```
[standards] src/orders/api.rs:88 — submit_order folds validation, pricing and
            persistence into one scope; the pricing rule cannot be tested alone
[spec]      src/quotes/cache.rs:24 — caches unbounded; spec.md §3 asked for the
            last N. Works, but the memory profile the spine was planned against
            no longer holds
```

**This review is advisory — it does not halt the close by itself.** The blocking
gates are impl-check, the cumulative demo, the fake-expiry gate and the
quarantine gate, and adding a fifth that turns on taste would make every close
negotiable. What it produces is a decision for the operator, on each finding:

- **fix now**, before the merge — the default when the finding is small and the
  spine is still open;
- **file it** (`oss feature_add "<name>" "<value>" "<bone|flesh>" feature-map-return`) — when it
  is real but not this spine's job;
- **accept it**, recorded in the retro's §8 with the reason.

**Findings do not evaporate — but where they land depends on the spine's class.**
A **bone** spine's full retro has §8 (durable lessons) and §9 (carried forward);
a **flesh** spine's lean set has neither (`retrospective.md` §2). So:

- **bone** → accepted findings to §8, carried-forward ones to §9.
- **flesh** → both to the lean set's own carried-forward section, and if the
  lean set has no home for a durable lesson, that is a signal the finding is
  worth a tracked issue rather than a retro line.

A review whose output lives only in the transcript did not happen; pick the
heading that exists for the class you are closing rather than the one this
paragraph would prefer.

**One exception that does halt:** if Axis B finds the diff does something the
spine's **class** does not admit — a flesh spine that turned out to modify a bone
— that is not a code-review finding at all. Stop and take it to the bone-touch
judge and the critic veto (`plan-release/references/critic-veto.md`), which is
the machinery that owns it.

---

## 6. Anti-patterns

- **Reading the spec first.** The single most common way this review produces
  nothing: you learn the intent, then read the code as its explanation.
- **Re-running Layer 3.** The documented-pattern check already ran per work item.
  Repeating it here buys nothing and buries your craft findings in noise.
- **Reviewing the whole file instead of the diff.** Scope is what the spine
  changed, plus what it made worse.
- **Findings with no location.** "Consider refactoring the order module" is not
  actionable and will be ignored, correctly.
- **Blocking the close on taste.** Advisory means advisory; the blocking gates are
  named above, and this is not one of them.
- **Rewriting the code yourself mid-review.** You are reading a diff, not
  authoring one. A fix is a decision the operator makes and the implementer
  executes.
- **Letting a finding die in the transcript.** If it is worth saying, it is worth
  the retro.
