# Item review

Your review file's first line is exactly `verdict: pass` or `verdict: block` — block if any finding blocks the merge bar. Its second line is `head: <sha>`, the full 40-hex head you reviewed (the PR's `headRefOid`, read before you review). The findings follow. Write it once, after the review, and end.

The bar is the body's `## Merge bar`; absent (a one-line `ossify close` body), use the four conditions of merge-bar's template (`opening-a-pr/references/pr-body.md`, "Merge bar"), blocking only on those.

If `<OUT>/bar-changed` exists, review the whole PR as round 1 against the body now, not the fix range; read its reason and say why in the findings' first line. OUT is from your message. Otherwise the `previous:` line of your message is the last round's review file. A missing file means round 1: review the whole diff. Otherwise review only the changes since its `head:` line. Still check each earlier finding is closed. Never merge, edit or push.
