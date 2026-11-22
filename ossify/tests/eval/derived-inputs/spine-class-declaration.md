# Derived input set — `spine-class-declaration`

**What this is.** The inputs `rubrics/spine-class-declaration.md` reads,
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
silently. The deployment-evidence row (I4/I5) was added with criterion 6.

| # | Input class | Read by criteria |
|---|---|---|
| I1 | the proposed spine's scope — an architectural layer with no actor-to-outcome journey (a horizontal build) vs an actor-to-outcome journey | 1, 2 |
| I2 | the declared class — `bone` / `flesh` / `internal-enabler` / reject | 1 |
| I3 | whether the scope touches a registered bone's touch surface — a flesh claim touching a bone | 3 |
| I4 | whether a separately-deployed service (its own process, image, pipeline, and on-call surface) is proposed — moving existing work into it or creating new work there — vs work kept in-process; and whether the spine is still a candidate at selection or already minted, with its declared class | 6 |
| I5 | the measured-pressure evidence for that service — contemporaneous and checkable (a bottleneck profile, a load figure it cannot meet in-process, an outage where its failure took the rest down, an enacted compliance rule forbidding co-location, an ownership transfer that has happened) or its absence / an anticipated need only ("it will need to scale independently") | 6 |
| I6 | what the plan creates, replaces or builds on, stated as concrete facts — what it changes and what undoing it would cost (criterion 4 judges genuine flesh vs inflated to bone; a body never states that verdict, never says the plan creates a bone, and never uses rung 3's question words) | 4 |
| I7 | the facts each governing rule reads — journey presence, bone-touch hits, an enabler's named consumer, deployment-pressure evidence (criterion 5 scores which rule the rationale cites; a body never names it) | 5 |
| I8 | for an internal-enabler, the named consuming user-facing spine scheduled in the current or next release (one-release-ahead cap) | 2 |

## The two ways a declaration still fails

**Declared as an outcome rather than a fact.** "The class is bone" is
criterion 1's conclusion wearing an input's clothes — state the scope, the
touch, and the evidence, not the class the criterion derives from them.

**Omitting the deployment-evidence input on a separately-deployed service.** A
body that proposes one without stating the measured pressure (or its absence)
and whether the spine is minted yet hands criterion 6 a guess between admitting
it as bone and leaving it on the feature map.
