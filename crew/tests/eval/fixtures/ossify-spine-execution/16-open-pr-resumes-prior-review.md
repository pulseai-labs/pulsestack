---
scenario_id: 16-open-pr-resumes-prior-review
expected_outcome: proceed
expected_reason: 'Four states, each scored on its own - a later state never rides on
  an earlier one''s answer. (a) The open: result persists the review record - whether
  the delegated review ran, its reviewed head, its clean/findings state and summary,
  and the durable ledger/comment references - and it carries the RUN_JSON path it
  continued and the pane its run.orchestrator names at writing; the next fresh
  work-PR dispatch receives that same RUN_JSON to continue and rebind (never a fresh
  one) together with the record as PRIOR_REVIEW in a fresh brief, the review
  state reused. (b) Resume, same head: the branch is taken BEFORE any reviewer
  exists - PRIOR_REVIEW''s record head equals the current PR head, so no reviewer is
  created and zero additional delegated reviews are commissioned; the session enters
  the owning work-PR procedure and runs all its gates - only the duplicate reviewer
  creation is skipped; it must not jump past the ceremony into an ad-hoc disposition
  or merge loop. (c) Resume, moved head: still zero additional reviews - the signals
  are re-fetched and the prior review with its unresolved findings remains the
  disposition baseline. The fourth beat: a record that mismatches the PR''s live
  state - wrong PR number, a ledger comment that does not exist - is neither
  re-reviewed nor guessed; the session asks upward and creates nothing. The session
  never infers initial-vs-resumed itself: it did not open the PR. The wrong answers
  this fixture falsifies are: creating a reviewer on any resumed dispatch; treating
  resume as license to skip the work-PR ceremony and its gates; and repairing or
  improvising around an inconsistent PRIOR_REVIEW'
---

You are the work-PR session for PR #34 in `product-web`. Your dispatch injects
`PRIOR_REVIEW`, `RUN_JSON=<the path that PR's prior open: return named>`, and
`MERGE_EXECUTOR=operator`. Four states reach you in sequence
over this PR's life; treat each as it arrives.

**(a)** Earlier, a previous work-PR dispatch on this same PR was relayed the
word *wait* and returned `open: <PR url> at <head sha>`. State what that result
carried with it and what your dispatch received as a result.

**(b)** Now, first dispatch after that: `PRIOR_REVIEW` holds a record — the
delegated review ran, reviewed head `c0ffee1`, `Findings: none`, summary, and
two ledger comment ids. The current PR head is still `c0ffee1`. State the first
thing you do before any seat exists, and how many delegated reviews this
dispatch commissions.

**(c)** Later dispatch: the head has moved to `dead2be` (a deferred-thread fix
was pushed meanwhile). The record still says `c0ffee1` with two unresolved
findings on the ledger. State what covers the new head and what remains the
disposition baseline, and how many delegated reviews this dispatch commissions.

**(d)** Final dispatch: `PRIOR_REVIEW` holds a record naming PR #43 and a ledger
comment id that returns 404. The live PR is #34. State what you create and what
you do not.
