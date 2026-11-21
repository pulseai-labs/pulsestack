# Derived input set — `risk-gate-registration`

**What this is.** The inputs `rubrics/risk-gate-registration.md` reads,
derived from that rubric in one pass. A fixture body on this surface must
declare every class below, because **every criterion is scored on every
fixture**. An input a criterion reads but the body never states is scored
against a guess.

**What this is not.** It is not a second copy of the rubric and states no
rule. Each row points at the criteria that read it; **the rubric is the
authority on what those criteria say**, and where the two disagree the rubric
wins. Kept out of `fixtures/<surface>/` because `lib/aggregate-scores.sh`
globs `*.md` inside each surface directory and treats every one it finds as a
fixture owing a result JSON.

**Re-derive it when the rubric changes.** A criterion edited to read something
new adds a row here; this list is downstream of the rubric and goes stale
silently.

| # | Input class | Read by criteria |
|---|---|---|
| I1 | the surface's defect character — which irreversible-harm family (money moved / data destroyed / identity-trust disclosure / silent ordering corruption) vs bounded and locally reversible | 1 |
| I2 | the proposed controls — which menu entries, and whether a human confirm names the concrete effect or is a generic "are you sure?" | 2 |
| I3 | whether a control the menu does not attach to the family is applied (ceremony inflation — e.g. paper env or progressive exposure on identity, or kill switch on destructive) or every control the menu does attach to the family is present | 2 |
| I4 | the touch surface — a glob naming the surface that reaches the hazard, or absent | 3 |
| I5 | whether the skeleton can reach the surface in Release 0 | 4 |
| I6 | whether the gate is known to be coming with a known surface (register now) vs a known-coming gate with no known surface (feature map) vs Release 0 cannot reach and no known surface | 4 |
| I7 | the planned paths a spine touches, against the surface (criterion 5 derives the bone reclassification and the inherited controls; a body never states them) | 5 |
| I8 | the release in which the surface first becomes reachable (criterion 5 derives the docs trigger; a body never states it) | 5 |
| I9 | whether a bone about the same design also applies, and whether it is already registered (criterion 6 derives what to register) | 6 |

## The two ways a declaration still fails

**Declared as an outcome rather than a fact.** "A gate is registered with
appropriate controls" is the criteria's conclusion wearing an input's clothes
— state the harm family, the proposed controls, and the touch surface, not the
verdict on them.

**Declaring the gate without the harm family.** A body that says "register a
risk gate for the payment code" without stating which irreversible-harm family
the defect produces hands criterion 2 a guess about which controls its family
attaches.
