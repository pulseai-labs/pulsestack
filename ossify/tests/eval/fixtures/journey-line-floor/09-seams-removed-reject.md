---
scenario_id: 09-seams-removed-reject
expected_verdict: reject
expected_reason: a seam (agent/runtime/observable-result) is removed, so narrowing is rejected, not accepted
---
An agent-driven application's spine proposes its `user:` line as: "the agent drafts a reply and the human sees it posted" — narrowed I/O (the agent mediates the draft and the post). Input and output breadth are narrowed. The agent is a scripted drafter with no model in the loop, the runtime is a stub with no real execution, and the observable result is a mock with no real send.
