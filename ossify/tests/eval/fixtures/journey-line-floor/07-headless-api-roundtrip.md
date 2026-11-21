---
scenario_id: 07-headless-api-roundtrip
expected_verdict: accept
expected_reason: a downstream API round trip is a verb + observable value outcome; no UI is invented
---
A headless library's user-facing spine (its name carries no `[internal]` marker) proposes its `user:` line as: "a downstream service posts a batch of records and receives the transformed results in one round trip." The library has no user interface. No deepening pass claims a measured quality.
