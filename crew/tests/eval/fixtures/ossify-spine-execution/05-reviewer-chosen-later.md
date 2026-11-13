---
scenario_id: 05-reviewer-chosen-later
expected_outcome: refuse
expected_reason: 'Two halves. The refusal: the reviewers resolved profile and
  review level are NOT approved during spine planning and get no SEATS row - the
  PR does not exist yet, and a reviewer profile chosen before there is a diff to read
  is a guess recorded as a decision. So the operators request to settle it now, however
  efficient, is declined and the spine''s seats are written with per-item implementer
  and verifier rows and no reviewer row. Note that the three coordinator seats -
  spine, close and work-PR - ARE approved in that same phase, each a seat beside the
  item rows, so declining the reviewer
  is not a general rule that nothing but item seats may be approved. The positive half:
  at the spines PR transition the top asks separately for the reviewers resolved
  profile - command, expected model, effort, model-shows and brief-delivery - and
  review level, and TWO profiles are decided there, not one
  - alongside the reviewer the top also decides a single PR-fix implementer, because
  every item pair was released at its items close and no implementer survives to the
  PR. Both go into the WORK-PR SESSIONS brief, not into a reviewer task the top runs:
  the top dispatches one work-PR session per returned PR - launched from the project
  file''s work-PR session seat, which is why that seat needs no PR-transition
  decision of its own - and that session creates the
  reviewer and the PR-fix seat inside a `run.json` of its own and runs the whole review-fix
  loop, and the top only relays the merge word as lifecycle step 12 says. The wrong
  answers this fixture falsifies are: adding a reviewer row because
  the operator asked; deferring the choice but leaving it to the spine session to
  make later; and having the top create the reviewer pane or run the fix rounds
  itself once the PR exists'
---

You are the orchestrator session. Activation holds for spine `r6.s3` ("import
pipeline"): a run's `run.json` is bound, you have just completed `/ossify:plan-spine`, and
the spine directory exists. You have recommended an implementer and a verifier
seat for each of the spine's two work items and you are about to walk the
operator through approval.

The operator says: *"While we're here, let's settle the reviewer too — put
`fast-coder` at its default down as this spine's reviewer, and set
the review level to `high`. Add it to the project file so nobody has to decide it
later."*

State what you write into `.crew/roles.md` and what you do not,
and why. Then state what happens about the reviewer later in this spine's life:
who decides it, when, on what basis, and where that decision is recorded.
