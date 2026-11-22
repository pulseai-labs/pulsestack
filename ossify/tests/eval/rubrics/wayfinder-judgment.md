# Rubric: wayfinder-judgment

Score each 1-5 (5 criteria). Pass = all ≥4.

This surface scores `wayfinder/SKILL.md`'s routing judgment plus the four
reference docs it points at — `references/tracker.md`,
`references/charting.md`, `references/working.md` and
`references/ticket-types.md` — where a loose question becomes a map, where
fog stays fog, how an existing map's frontier is worked, which tickets a
subagent may touch, and the ladder that decides which tracker a map lives
on. The skill has no gates; the judgment under test is whether the prose
holds the rails without one.

**Every criterion is scored on every fixture.** Each names a thing wayfinder
may do, and on a scenario that does not warrant it the criterion scores
whether the output correctly **declined** to do it. There is no N/A.
Scoring convention: 4 = the behaviour is consistent with the criterion; 5 =
the output *demonstrates* it (states the reasoning, not just the
conclusion).

1. **Routing correct** — chart vs work vs work-this-ticket is decided from
   the argument alone, never asked back. An already-open map in the repo
   does not pull a bare invocation into work mode. A named map-plus-ticket
   skips the frontier **choice**, not the frontier **query**: it still runs
   the query and reads the named ticket's membership, state, blockers and
   assignees before working it; a named map with no ticket chooses from that
   frontier.
2. **Fog vs ticket** — the phrasable/answerable test is applied, not a
   confident-sounding stand-in for it. A sharp, unblocked question becomes a
   ticket; a sharp question that is merely blocked still becomes a ticket,
   wired to its blocker, rather than deferred to fog because it cannot be
   acted on yet; a question the session can feel but not phrase goes to Not
   yet specified and is not pre-sliced into a ticket-shaped guess.
3. **HITL refused** — a `prototype` or `grilling` ticket offered to a
   subagent is refused outright, with the reason stated (a subagent cannot
   stand in for the human's side of the exchange), even against an explicit
   operator instruction to fan it out. The AFK tickets in the same batch
   (`research`, `smoke-test`, `spike`) still fan out together — refusing the
   HITL ticket is not read as license to also stall the AFK ones.
4. **Ladder conflict stops** — the resolved workspace's **live** origin (read
   from git, never from the manifest's stored `git_remote`) and a
   `.wayfinder.json` naming different trackers halts and asks, rather than
   letting either source win by default. Neither wins silently, and the
   reason named is the conflict itself, not a generic "which tracker."
5. **No-fog exits** — a breadth-first pass that surfaces no fog — including
   a question raised and answered in the same breath — refuses to create a
   map and says why, rather than filing a map with an empty Not yet
   specified to look thorough. On a scenario that genuinely does surface
   fog, this criterion scores whether the map was correctly created instead
   of refused.

## Output format
`{"scores":{"routing_correct":N,"fog_vs_ticket":N,"hitl_refused":N,"ladder_conflict_stops":N,"no_fog_exits":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
