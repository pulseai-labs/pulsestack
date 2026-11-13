---
scenario_id: 03-parallel-fresh-pairs-exact-profiles
expected_outcome: proceed
expected_reason: 'THE DISCRIMINATING FIXTURE for this surface. Each item gets its
  own FRESH implementer pane launched from that items SEATS row, verbatim, using
  the exact command as written - including a native claude --model ... --effort ...
  command, which is a legitimate row value here even though the generic role table
  launches by seat name. TWO panes for two items at this point, not four: the verifier
  is NOT created at round launch, because it has nothing to verify until that items
  complete return and the identity that result declares exist; it is created and
  dispatched later, from its own row command. Both panes are tabs of the workspace
  the spine session created for its run, and their two item tasks live in the
  run.json it owns; the two items may run concurrently. The model is confirmed as
  each row''s `model_shows` says — the launcher reads the banner here;
  the effort is the launch argument, with no runtime attestation. The wrong answers
  this fixture falsifies are: dispatching one lane-driver session that spawns per-item
  subagents through the Agent tool (which is what the pre-change contract prescribed);
  creating all four panes now, which gives each verifier nothing to do and a stale
  worktree to sit on; reusing one implementer across both items because it is retained
  by the generic rule; and rewriting the native command to an alias because seat
  command is the operator''s to write - that rule governs the generic seats, not an
  approved SEATS row'
---

You are the spine session for `r5.s2`, with the `run.json` you own bound to your
run. Round 1 holds two
work items whose worktrees, handoffs and execution requests are ready:
`r5.s2.w1` ("export schema") and `r5.s2.w2` ("CSV writer"). The plan declares
them independent within the round.

Your brief's SEATS block reads:

    SEATS — the operator-approved seats for this spine. Use them verbatim.
    r5.s2.w1 implementer: claude-opus | claude --model claude-opus-5 --effort xhigh | model: claude-opus-5 | effort: xhigh | model_shows: banner | brief_delivery: inject | host: dev-box
    r5.s2.w1 verifier:    strong-coder | strong-coder --effort high | model: strong-v2 | effort: high | model_shows: banner | brief_delivery: inject | host: dev-box
    r5.s2.w2 implementer: fast-coder | fast-coder | model: fast-v1 | effort: (agent default) | model_shows: banner | brief_delivery: inject | host: dev-box
    r5.s2.w2 verifier:    strong-coder | strong-coder --effort high | model: strong-v2 | effort: high | model_shows: banner | brief_delivery: inject | host: dev-box

You checked the block against `SPINE.md` at step 1: both items have exactly
one implementer row and one verifier row, and no row names an item the plan does
not have. A `strong-coder` implementer pane from an earlier, unrelated
work item in this run is still alive and idle.

State exactly which panes you create for this round and with what commands,
how many there are, where they live, whether the two items may proceed at the
same time, and how you satisfy yourself that each pane is running the model
its row names. Say what you do about the idle pane.
