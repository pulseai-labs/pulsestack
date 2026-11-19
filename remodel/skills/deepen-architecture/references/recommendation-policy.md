# Recommendation policy (recommend-by-default + disposition triage)

> **Single source of truth.** This file is authored once at the marketplace root
> (`docs/conventions/recommendation-policy.md`) and shipped as a **byte-identical
> copy** inside each plugin that adopts it (repo-root `docs/` does not ship on
> `/plugin install`, so each plugin carries its own copy). The repo-root parity
> test `tests/test-recommendation-policy-parity.sh` fails if any copy drifts.
> **Edit the root copy; never hand-edit a plugin copy** — re-copy instead.

## What this is

A cross-cutting interaction convention for every skill that **surfaces a decision
to the user** — a grill question, a council verdict, an audit challenge, an
orchestration gate. By default, each surfaced decision carries a firm, expert,
vision-aligned **recommendation**, so the user can respond with guidance in hand
rather than adjudicate cold. And by default the agent itself **dispositions the
low-stakes, source-grounded decisions** (disposition triage, below), so the
user's attention goes only to the decisions that genuinely need it.

This policy governs **how** a decision is presented and **who dispositions it**,
never **what** is asked or challenged. The skill's own logic decides what to
surface; this policy only adds that a grounded recommendation rides along with
it, and that predicate-clean recommendations are applied rather than
re-confirmed.

## The rule

1. **Default-on — one firm recommendation.** Every surfaced decision carries
   **exactly one** recommended option plus a **one-line rationale** — not an
   option dump, not a balanced menu with no lean. State it plainly:
   *"Recommended: &lt;option&gt; — &lt;one-line why&gt;."*

2. **Vision-grounded, with a citation.** When a project source-of-truth is
   reachable, ground the recommendation in it and **cite the source inline**
   (e.g. `MASTER-SPEC §4.2`, the onboarding digest, a memory-bank file). When no
   source-of-truth is reachable, give a general best-practice recommendation and
   **label it as such** — *"(general best practice — no project spec found)"*.
   **Never fabricate a citation.** A recommendation the user cannot trace is worse
   than none.

3. **Accept / rebut / defer.** Every surfaced recommendation offers three
   first-class dispositions:
   - **accept** — adopt the recommendation as-is.
   - **rebut** — push back; the skill engages the rebuttal (and, where it scores
     rebuttals, scores it) before the recommendation stands or yields.
   - **defer** — valid but not now; the decision is **tracked** for later (filed as
     an issue / recorded as deferred), never silently dropped.

   Under disposition triage (below), the agent itself applies `accept` and
   `defer` recommendations that clear the escalation predicate; a
   `rebut`-recommended item is contested by definition and always escalates.

4. **Explicit opt-out.** A `--neutral` flag, or a natural-language "no
   recommendations" / "just give me the options" request, **suppresses** all
   recommendations for that invocation: surfaces revert to neutral options and the
   user adjudicates cold. Opt-out is per-invocation, not sticky. Triage has its
   own opt-out — `--walk` / *"walk them"* (see the vocabulary below); `--neutral`
   disables triage transitively (with no recommendations there is nothing
   grounded to apply).

5. **The user is the final authority.** That authority is exercised two ways:
   **directly**, on every escalated decision; and by **standing delegation** on
   decisions that clear the escalation predicate — a delegation this policy
   documents, the digest makes auditable, and any single invocation can revoke
   (`--walk`). Escalated classes never auto-apply, and an explicit user
   direction always overrides. A recommendation is still a lean, not a decision;
   what changes is that the user has pre-decided, in this policy, who
   dispositions the low-stakes class.

## Disposition triage (standing delegation)

Post-#93 evidence (pulseai-labs/pulse360#15): ~90% of surfaced recommendations
were accepted verbatim — 380 hand-typed "proceed with your recommendation" turns
across 55 sessions. The rational fix is wholesale delegation of the class the
user always accepts, with the high-stakes class escalated. Triage is
**default-on** for every adopting surface.

**The triage rule.** Classify each surfaced decision against the escalation
predicate:

- **Clears it** → apply the recommended disposition **immediately** — no user
  turn spent. Only `accept` and `defer` are auto-appliable; an auto-applied
  `defer` stays **tracked** (filed issue / deferred list), never silently
  dropped.
- **Trips it** → **escalate**: walk it with the surface's full cadence
  (recommendation attached, accept / rebut / defer, rebuttal scoring where the
  surface has it).

**Escalation predicate — escalate when ANY holds:**

1. **UNGROUNDED** — the recommendation cannot cite a reachable source-of-truth
   (MASTER-SPEC §, memory-bank file, onboarding digest, referenced issue/PR). A
   "(general best practice)" lean never auto-applies.
2. **VISION/SCOPE-TOUCHING** — the finding challenges or would change the
   vision, the scope, or a previously locked/settled decision (as recorded in
   ADRs, memory-bank settlements, or locked-decision sections of specs and grill
   exit summaries), rather than operating within them.
3. **ONE-WAY DOOR** — hard to reverse: public contracts, schema/data
   migrations, deletions, pushes or PR-merges to the canonical repo. (Local
   worktree→branch merges are reversible and do not trip this.)
4. **TOP SEVERITY** — the surface's own top class (e.g. `premise`-severity
   challenges in critique; a restart-class recommendation at orchestrate gates —
   a restart option merely on the menu does not trip it).
5. **CONTESTED** — the recommended disposition is `rebut`, or two adversaries
   (host + external) disagree about the finding. Agent-vs-agent disagreement
   needs a human referee.

**Audit digest.** The same turn that auto-applies emits a compact digest — the
header literal `⚡ Auto-applied` is a **stability contract** (anchor tests and
the agent-ops regression watch grep for it):

```
⚡ Auto-applied K of N
<id> · <finding one-liner> · <accept|defer> · <citation>
...
```

`reopen <ids>` pulls any auto-applied item back into a full walk — honored while
the session lives (and, where the surface persists state, before its run record
is appended).

**Vocabulary (identical across adopting surfaces; opt-outs are per-invocation,
not sticky):**

| Phrase / flag | Effect |
| --- | --- |
| `--walk` / "walk them" | Full sequential walk; triage disabled, nothing auto-applied |
| `--neutral` / "no recommendations" | Unchanged meaning: no recommendations at all → triage transitively disabled |
| `reopen <ids>` | Pull auto-applied item(s) back into a full walk |
| `accept all` / `accept all except <ids>` | Explicit bulk responses on the **escalated** set |

## Why default-on

A neutral option dump pushes the whole adjudication cost onto the user every time.
A firm, cited recommendation lets them accept fast when they agree, and gives them
something concrete to push against when they don't — itself faster than reasoning
from a blank slate. Grounding the recommendation in the project's own
source-of-truth (rather than generic best practice) is what makes it trustworthy,
and the skills that adopt this policy already have that source-of-truth in context,
so the grounding is essentially free.

Triage extends the same logic to disposition: when a recommendation is grounded,
low-stakes, and uncontested, re-confirming it costs the user a turn and buys
nothing — the delegation is a decision the user already made, repeatedly and
explicitly. The digest keeps every delegated disposition auditable and reversible
(`reopen`), so trust is verifiable rather than assumed.

## How a skill adopts this policy

Each adopting skill's `SKILL.md` references this file and describes, in a few
lines, how the policy renders on **its** surface (a grill question, a verdict, a
challenge, a gate) and which source-of-truth it grounds against — plus how
triage renders there: what auto-apply means on that surface, where the digest
appears, and which class counts as TOP SEVERITY. The universal rule above does
not change per skill; only the rendering does.
