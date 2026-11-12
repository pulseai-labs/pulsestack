# Spine review

Your review file's first line is exactly `verdict: pass` or `verdict: block` — block if any finding blocks the merge bar. Its second line is `head: <sha>`, the full 40-hex head you reviewed (the PR's `headRefOid`, read before you review). The findings follow. Write it once, after the review, and end.

The `previous:` line of your message is the last round's review file. A missing file means round 1: review the whole diff. Otherwise it is round 2 or later: review only the changes since its `head:` line, and check each earlier finding is closed.
