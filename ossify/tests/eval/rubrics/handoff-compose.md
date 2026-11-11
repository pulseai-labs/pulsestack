# Rubric: handoff-compose

Score each 1-5. Pass = all ≥4.

This surface scores the **compose-mode judgment** of
`ossify/skills/handoff/references/compose.md` + `sections.md` — where a handoff goes,
tracked or not, what enters it, and what the read-out surfaces. The ceremony
has no gates; the judgment under test is whether the prose holds the rails
without one.

**Every criterion is scored on every fixture.** Each names a thing compose may
do, and on a scenario that does not warrant it the criterion scores whether the
output correctly **declined** to do it. There is no N/A. Scoring convention:
4 = the behaviour is consistent with the criterion; 5 = the output
*demonstrates* it (states the reasoning, not just the conclusion).

1. **Location correct** — the strongest evidence wins in order: existing
   handoffs (matching their directory AND naming), then the `docs/` tree, then
   stated fallback. The choice is stated with its reason in one line, and
   never asked back to the operator. An operator suggestion that loses the
   handoff (e.g. an ephemeral path outside the repo) is declined with the
   reason, not silently obeyed and not silently ignored.
2. **Tracked decision stated** — tracked/ignored follows repo precedent;
   absent precedent, tracked is the default and the choice is stated either
   way. Gitignored precedent is followed WITH the survivability tradeoff said
   aloud — following it silently and "fixing" it by tracking against precedent
   are both wrong. Where the repo tracks handoffs, the ceremony includes the
   commit and says so.
3. **References, not duplicated** — content that already lives in a file
   enters §4 as a pointer (path + one line), never pasted into §3 — including
   when the operator asks for the paste; the output explains
   reference-over-duplication rather than obeying. §3 holds only what no file
   records. On a scenario with nothing to point at, no §4 filler is invented.
4. **Claims checkable** — §2 is sketched as whole claims each paired with a
   concrete check command (git/test/suite invocations), numbers measured from
   the scenario's stated evidence, not invented; anything unverifiable is
   marked rather than asserted.
5. **Sequence ordered** — §5 is a numbered order with a concrete first step
   and what "done" looks like, drawn from the scenario's actual state (failing
   suites, remaining items), not generic advice.
6. **Weakness surfaced** — the read-out is given (location/tracked/§2/§3/§4/
   §5/Weakest) and `Weakest` names the genuinely thinnest part. On a trivial
   handoff, a lean §3 is *called correct* and the output resists the operator's
   request to pad it — manufactured depth scores this criterion down, honesty
   about thinness scores it up.
7. **Name taken, never overwritten** — the chosen file name is checked
   against the directory itself (not `git ls-files`: an ignored file is in no
   index). A name already on disk is never reused: the output takes the next
   free name (the repo's own suffix precedent where one exists, else `-2`)
   and the read-out says the name was taken and which name was used. Where
   no file of that name exists, the output uses the plain name and invents
   no suffix and no collision.

## Output format
`{"scores":{"location_correct":N,"tracked_decision_stated":N,"references_not_duplicated":N,"claims_checkable":N,"sequence_ordered":N,"weakness_surfaced":N,"name_taken_not_overwritten":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
