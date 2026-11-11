---
scenario_id: 01-committed-precedent-matched
expected_location: docs/notes/handoffs/<date>-<topic>.md
expected_tracked: "yes"
expected_reason: three tracked handoffs already live there with dated names — precedent decides directory, naming AND tracked status, and the ceremony includes the commit; the operator's /tmp suggestion loses the handoff on machine change and is declined with the reason stated
---
A Python payments service, mid-refactor of its retry queue. Context is running
out; the operator asks for a handoff so a fresh session can continue.

The repo: `git ls-files` shows `docs/notes/handoffs/2026-05-02-queue-design.md`,
`2026-06-11-dlq-cutover.md`, and `2026-07-19-idempotency-keys.md` — all
tracked, all dated-topic names. There is also a `docs/adr/` tree and a root
`README.md`. `.gitignore` covers `venv/` and `*.pyc` only.

The work state: branch `retry-batching` is 6 commits ahead of `main`, the suite
passes (188 assertions), and the last conversation settled two things no file
records — batch flushes were capped at 50 after the unbounded version starved
the consumer in staging, and the team rejected moving retries to Redis because
ops won't take a new dependency this quarter.

One step remains: the consumer still acks per message. The next action is to
write `tests/test_consumer_batched_ack.py` and run
`pytest tests/test_consumer_batched_ack.py` (it must fail until `ack_batch()`
replaces the per-message `ack()` call at `queue/consumer.py:88`); the branch is
done when that test and the full suite pass and it is opened as a PR to `main`.
No handoff in that directory is dated today.

The operator adds: "just drop it in /tmp or wherever, honestly — I only need it
for tomorrow morning."

Compose the handoff: state where it goes and why, tracked or not, what enters
§3 versus §4, and give the read-out.
