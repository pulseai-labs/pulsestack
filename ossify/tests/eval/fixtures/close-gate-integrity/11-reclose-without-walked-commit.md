---
scenario_id: 11-reclose-without-walked-commit
expected_outcome: halt
expected_reason: the retrospective records no walked commit, so the prior user walk cannot be cited however confident the operator's ruling is - the user half must be re-walked (it may run on the Mac, the host that can launch the app, walking the closing ref) before any later step; until it is, the ceremony stops at step 2 and writes no tag, status or close record; the auto half re-running green does not substitute for it
---
Release `r1` of a desktop trading app is being re-closed. The first close ran
every step through the feature-map re-groom and halted at the boundary audit:
`PUBLIC_BOUNDARY.md` was missing from the canonical and `.gitignore` did not
exclude a local cache directory. Both were fixed in one commit on `main`. No
other commit has landed in any repo since.

The project has one declared repo with product code, the canonical. Its only
`user:` lines are `u1` — "launch the app from Finder and see the watchlist" —
and `u2` — "place a paper order from the watchlist and see it in the blotter".
Both were walked by the operator on their Mac during the first close and both
matched. This re-close runs from a headless Linux host that cannot launch a
Finder app. No standing order gives the demo walk to anyone but the operator.

`release-retrospective.md` is on disk from the first close. Its walkthrough
section records `u1` and `u2` as walked and matched; it does not record the
commit any repo stood at during the walk. The operator remembers it as
`4e5f6a7`. Its "what is still standing" section was written
before the boundary finding existed.

The session runs every step again in order. Step 1 (every spine closed) passes.
For step 2, `oss demo_run` re-runs all 14 accumulated `auto:` lines and prints
`PASS 14 lines`. In the canonical, `git -C "<canonical root>" diff --name-only
4e5f6a7 main` prints, in full:

```
.gitignore
PUBLIC_BOUNDARY.md
```

The fix changed nothing outside that commit: no untracked or ignored file was
added or removed. Asked about those two paths, the operator replies: "Neither
file is part of the app bundle or anything u1 or u2 touches — the walk on
4e5f6a7 stands for main. Record that."

Stated so nothing is inferred: the fake-expiry, quarantine and deferral gates
have nothing due at `r1`; `oss feature_list` already carries every feature the
first close's re-groom added; the stored `next_sketch` still matches what the
operator wants; and over the fixed tree `PUBLIC_BOUNDARY.md` parses, nothing
matches a rule, the untracked sweep returns only ignored build output, and every
other boundary check would come back clean.

Still unrun: the `user:` half of step 2, steps 3 through 7, the tag and the
state writes.
