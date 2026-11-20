---
scenario_id: 06-correction-continuation-same-executor
expected_outcome: external
expected_reason: 'The operator picked recovery option 1 (re-dispatch the implementer)
  on a Layer 1 halt, and under external mode that becomes a correction continuation
  rather than a fresh /ossify:work-item invocation - the ordinary command opens with
  a clean-tree pre-flight that correctly refuses the staged output already sitting
  in the worktree, so re-running it can never converge and only burns the cap. The
  continuation goes to the SAME executor that produced the result and carries SIX
  fields: handoff_path, work_item_id, expected_branch, expected_head_sha, expected_tree_oid
  and the consolidated failures list (not one packet per finding). The executor re-reads
  handoff/spec/report and REFUSES on any of FOUR identity mismatches, each compared
  against a value the packet carries - work item id, checked-out branch, HEAD, staged
  tree - then writes the targeted regression BEFORE the fix, reruns EVERY verification
  command rather than only the failed one, updates the SAME report, stages, and returns
  the EXISTING complete shape. The wrong answers this fixture falsifies are: inventing
  a third return mode for a correction; sending it to a fresh executor; checking an
  identity the packet does not carry, or omitting one it does; skipping any gate other
  than the initial clean pre-flight and the RED gate; and committing. The repaired item
  comes back to the lane as a fresh section 4 record and passes the whole section 5a
  validation again, identity included, rather than being accepted on the continuation
  inner shape. When its close is then green through Layer 3, the closing session applies
  the Layer 4 lenses itself, inline: it dispatches no verifier, and close runs no mutation
  check in this mode, because the verifier of the caller owns it. Routing Layer 4 to
  ossify:verifier-agent or to any multi-agent pass is a wrong answer'
---

Spine `r2.s5` ("rate limiter") is running under `--external-executor`.
`r2.s5.w1` came back accepted and complete, its fingerprint matched, and it went
to work-item close. Close ran the gate and halted at Layer 1: `AC-2`'s command
exited 1 — the limiter admits one request over the ceiling when the window
rolls. `AC-1` and `AC-3` passed.

The close surfaced the failure with its recovery menu and the operator chose the
first option: send it back to be fixed. The item's worktree still holds the
staged diff and the `report.md` from the first pass; HEAD is unchanged since the
caller finished; the executor that produced the result is still live and
addressable.

State exactly what the lane sends back, to whom, what that recipient does with
it in order, what it is allowed to skip, and what it returns. Say why re-running
the ordinary work-item command on this item would not work. Then say what the
lane does with the repaired item when it comes back and, once its close is green
through Layer 3, how the close runs Layer 4 and whether it runs a mutation check.
