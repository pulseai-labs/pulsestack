---
scenario_id: 10-reclose-walk-equivalence
expected_outcome: proceed
expected_reason: a release re-close after a boundary-audit halt may cite the prior user walk because the retrospective records the walked commit per repo, the full changed-path list to the closing ref is shown, and the operator (who holds the demo walk) rules no listed path touches a user: surface; the ruling, lists and both commits go into the amended still-standing section; the auto: half re-runs and passes; feature_add re-adds nothing already listed; the boundary audit re-runs last and is clean; the close proceeds to the state writes without a manufactured halt or a demand to re-walk on a host that cannot run the surface
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
section records `u1` and `u2` as walked and matched, and records the canonical
at `4e5f6a7` during the walk. Its "what is still standing" section was written
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
