# Item PR fix round

1. If the Ruling file exists, apply it first and write it into the PR body after step 2 adds the fields, because the reviewer reads the body and never this file. Do not edit or remove it. In steps 1–2, when the round changes the body's `## Merge bar` or `## Claim` beyond Known-limits lines or Evidence, write one line naming the change to `<OUT>/bar-changed` (OUT from your message).
2. Run merge-bar's working-a-pr for one round only (`/merge-bar:working-a-pr` on Claude Code, `skill://working-a-pr` on OMP): fix the Review file's blocking findings and red checks, nothing else. Commit and push once on the existing item branch, as a follow-up commit. Never merge, rebase, force-push or open a new PR. With no `## Merge bar`, working-a-pr adds the fields. Its round-3 stop is a stop.
3. Write the round done file, then end: `: > <Round done file from your message>`. This file is the round's only success signal.
