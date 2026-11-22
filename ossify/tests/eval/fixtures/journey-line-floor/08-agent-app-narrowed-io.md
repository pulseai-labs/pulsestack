---
scenario_id: 08-agent-app-narrowed-io
expected_verdict: accept
expected_reason: narrowed I/O breadth but the real agent, runtime, and observable-result seams remain; a verb + observable outcome
---
An agent-driven application's user-facing spine (its name carries no `[internal]` marker) proposes its `user:` line as: "the agent reads an inbound inbox, drafts replies, and the human approves one to send; the sent reply appears in the sent folder." Input and output breadth are narrowed. A model-backed agent on the production runtime performs the read and the draft, the human approves a reply, and a send through the real mail provider places it in the sent folder. No deepening pass claims a measured quality.
