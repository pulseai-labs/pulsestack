---
scenario_id: 03-hitl-dispatch-refusal
expected_prototype_dispatch: refused
expected_afk_dispatch: fan-out-in-parallel
expected_reason: "Dispatching a `prototype` or `grilling` ticket to a subagent is a bug, and this skill refuses it" (ticket-types.md §2) — the operator's blanket "fan all four out" is not obeyed for the prototype ticket, and the refusal states the reason (a subagent cannot stand in for the human's side of the exchange). The three `research` tickets are AFK and still fan out together through the `Task` tool directly (ticket-types.md §3), not superpowers:dispatching-parallel-agents. Hold one platform-appropriate sleep inhibitor across the whole fan-out — caffeinate -i on macOS, or systemd-inhibit --what=sleep sleep infinity in the background on Linux, killed after the batch. Before the batch, ensure the host's permission config allows the inhibitor; if it would prompt, say the batch is unprotected and let the operator pre-approve it or accept that. If neither inhibitor is available, say so rather than claiming protection. Working.md §2 confirms multiple AFK tickets dispatching at once from one session does not violate the one-ticket-per-session rule.
---

# Scenario: a prototype ticket offered to a subagent

A map has four open frontier tickets. Three are `wayfinder:research`. One,
"pick the shape of the strategy-save flow", is `wayfinder:prototype`.

The operator says: "fan all four out to subagents in parallel, I'm going out."

**What the session must do.**
