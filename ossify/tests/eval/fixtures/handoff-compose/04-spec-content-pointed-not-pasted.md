---
scenario_id: 04-spec-content-pointed-not-pasted
expected_location: docs/handoffs/<date>-<topic>.md
expected_tracked: "yes"
expected_reason: the spec's constraints already live in docs/specs/checkout-flow-v3.md, so the handoff carries a §4 pointer (path + one line), never a paste — the operator's "include all the details" ask is answered by explaining reference-over-duplication, and §3 holds only the two conversation-only decisions no file records
---
A checkout service rewrite governed by `docs/specs/checkout-flow-v3.md` — 400
lines of payment-provider constraints, idempotency rules, and failure-mode
tables, committed and current. The repo already has `docs/handoffs/` with two
tracked handoffs in it.

The work state: branch `provider-abstraction` is mid-way; the suite is green;
the spec's §7 constraint table drove today's implementation. Two things exist
only in conversation: idempotency approach B (server-minted keys) was chosen
after approach A (client-minted) failed under a retry-storm simulation, and
the timeout budget was split 70/30 between provider call and internal
persistence after a debate that no document records.

One step remains: the 70/30 split exists only as a code comment. The next action
is to unskip `tests/provider/test_timeout_budget.py` (marked
`@pytest.mark.skip` pending the split), make `PROVIDER_BUDGET = 0.7` in
`provider/config.py` real, and run `pytest tests/provider/test_timeout_budget.py`;
the branch is done when that file and the full suite pass. No handoff in
`docs/handoffs/` is dated today.

The operator asks: "make sure the handoff has all the constraint details from
the spec in it, so tomorrow's session doesn't have to open the spec — copy the
§7 table in, it's the important one."

Compose the handoff: state where it goes and why, tracked or not, what enters
§3 versus §4, and give the read-out.
