---
scenario_id: 01-routing
expected_mode_a: chart
expected_mode_b: work-frontier
expected_mode_c: work-ticket
expected_reason: mode is decided from the argument alone, never from repo state and never asked back — (a) carries no argument, so it charts even though a map is already open, per SKILL.md's routing table binding on the invocation shape alone; (b) names a map only, so work mode runs tracker.md §2's frontier query and chooses from the eligible frontier; (c) names a map plus a ticket, so work mode skips only the frontier choice, runs the same query, and reads that ticket's unfiltered node to check membership, state, blockers, and assignees before claiming or working it (working.md §1). All three resolve the tracker first (SKILL.md §1 "Resolve the tracker first, either way").
---

# Scenario: three invocations, one skill

The operator runs, on three different days:

(a) `/ossify:wayfinder` with no argument, in a repo with one open map.
(b) `/ossify:wayfinder` naming a map by title.
(c) `/ossify:wayfinder` naming a map and one of its tickets.

**Which mode each takes, and what each does first.**
