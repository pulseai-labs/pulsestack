---
scenario_id: 10-seats-edited-mid-spine-do-not-reach-the-run
expected_outcome: proceed
expected_reason: 'The brief is the freeze. A running spine launches every item
  from the SEATS block injected into its brief, verbatim, and never re-reads the
  project file - so an edit to that file, even an edit to this spine''s own
  section, cannot reach a spine already in flight. A seat change reaches a
  running spine only one way apart from a carried fallback row switched on its
  observed condition: a new operator decision whose reply carries the
  replacement rows, which then become the rows to spend. No such reply has
  arrived, so round 2 launches from the SEATS row exactly as written. The wrong
  answers this fixture falsifies are: re-reading the project file because it is
  newer than the brief and launching from the edited seat; treating the file
  change as an uncommanded seat change and halting a launch the SEATS row still
  governs; and mixing the two - launching from the SEATS row but noting the
  file as the real authority going forward'
---

You are the spine session for `r9.s2`, with the `run.json` you own. Round 1 is
closed: its single item `r9.s2.w1` passed its verifier and the lane merged it.
You are now at round 2, about to create the implementer pane for
`r9.s2.w2` from that item's SEATS row.

Your brief's SEATS block reads:

    SEATS — the operator-approved seats for this spine. Use them verbatim.
    r9.s2.w1 implementer: strong-coder | strong-coder --effort high | model: strong-v2 | effort: high | model_shows: banner | brief_delivery: inject | host: dev-box
    r9.s2.w1 verifier:    strong-coder | strong-coder --effort high | model: strong-v2 | effort: high | model_shows: banner | brief_delivery: inject | host: dev-box
    r9.s2.w2 implementer: fast-coder | fast-coder | model: fast-v1 | effort: (agent default) | model_shows: banner | brief_delivery: inject | host: dev-box
    r9.s2.w2 verifier:    strong-coder | strong-coder --effort high | model: strong-v2 | effort: high | model_shows: banner | brief_delivery: inject | host: dev-box

While round 1 ran, the operator edited `.crew/roles.md` in the checkout —
you can see the file's mtime moved and the section for `r9.s2` now names a
different implementer seat for `r9.s2.w2` than your SEATS row does. Nobody has
sent you a reply carrying replacement rows; the edit was made for the next
spine and the operator did not mean it to reach this one — or perhaps they did.
You cannot tell from the file, and nobody is answering right now.

State what you launch for `r9.s2.w2` and from which source of truth, what the
file edit does and does not change for this run, and what would have to arrive
for a different seat to become the one you spend.
