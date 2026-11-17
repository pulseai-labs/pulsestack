# What arrived since the plan — the intake queue and the tech-debt ledger

Depth for SKILL.md §3's last step, and read from two other places: `plan-release`
§4 reads §1 at release grooming, and the `patch` skill reads §2 for a patch's
paths. One procedure, three callers. The issue tracker is the queue, and the
ledger is a file in the AI workspace. The one state write is the feature-map
entry a release-level pull-in adds, which carries the request's issue number.

---

## 1. The intake queue

A request from another project is an **issue in this project's repo** carrying the
label `from:<requesting-project>` (for example `from:pulse-guard-ai`). The label is
the queue. The requester creates it the first time it files one; nothing else
registers it.

`<owner/repo>` is the repository the call targets, read from its own checkout: `gh repo view "$(git -C "<repo-root>" remote get-url origin)" --json nameWithOwner -q .nameWithOwner`. `<repo-root>` is that repository's checkout, not the directory you are in: a PR lives in the canonical even when you run from the AI workspace. On an ossify project, `oss repo_root canonical` (or `ai_workspace`) gives it. Never build the name from a folder name: an AI workspace's folder and its GitHub repo often differ.

List the open requests — every open issue with a label that starts `from:`:

```bash
gh issue list --repo "<owner/repo>" --state open --limit 1000 \
  --json number,title,url,labels \
  --jq '[.[] | select(any(.labels[]; .name | startswith("from:")))]'
```

**Never pass `--label 'from:*'`.** gh matches a label name exactly and takes the
`*` literally, so that call returns an empty list at rc 0: an empty queue that is
not empty. The prefix filter above is the only reading that finds every
requester.

**The limit is a bound, not a sample.** If
`gh issue list --repo "<owner/repo>" --state open --limit 1000 --json number --jq length`
prints `1000`, raise the limit and list again. A truncated page drops requests
silently. A closed issue is not in the queue.

A request stays open until the operator closes it, so the queue can
return one an earlier planning already took. Read its comments
(`gh issue view <n> --repo "<owner/repo>" --json comments`): one carrying a
`pulled in — <spine id>` disposition is already assigned — list it as
such, and never add it to the feature map again or pull it into a spine as new
work. A spine id has the
`r<n>.s<m>` shape. A `pulled in — <release id>` request (`r<n>`) is on the feature
map and not yet in any spine. At release planning, list it as already pulled in.
At spine planning, when this spine takes the feature it came from — whether the
request reads `pulled in` to the release or to an earlier spine — re-disposition it:
`pulled in` to this spine, recorded in `SPINE.md`'s Context and commented on the
issue as below. Find the request from the feature entry's `issue` field
(`oss feature_list`), never by matching titles. An entry with no `issue` (one
added before 1.23.0) came from a request you must confirm with the operator. If
this spine does not take that feature, leave the request as it is.

**The operator closes a request.** Several spines can take one feature, and each
posts its own `pulled in — <spine id>` comment. Spine close never closes the
request: it comments that its spine landed and tells the operator, who closes the
request by hand once the work it asked for has landed
(`close/references/spine-close.md` §3).

For each other open request, record exactly one disposition:

- **pulled in** — into this spine, as a named work item or an AC, only while the
  spine's first round has not started (SKILL.md §2). At release planning,
  pulled in means onto the feature map, with the request's issue number:
  `oss feature_add "<name>" "<value>" "<bone|flesh>" intake <issue-number>`.
- **deferred** — with the reason, and what would admit it later.
- **routed to `/ossify:patch`** — a defect in shipped behaviour, or a small
  request the requester cannot fake (`plan-spine/references/fake-ledger-discipline.md` §1).

Record each disposition twice: one line in `SPINE.md`'s Context (at release
planning, in `RELEASE.md`), and one comment on the issue, so the requesting
project sees it without asking —
`gh issue comment <n> --repo "<owner/repo>" --body "<disposition> — <spine or release id>"`.

**At release planning**, a release that serves a consumer states its exit
criterion as "<consumer> can adopt <capability set>", and the capability set stays
open until the release's last spine is planned. A spine's scope freezes when it
is planned; the release's does not.

**No queue to read.** If the repo has no GitHub remote, or `gh` cannot reach its
forge (unauthenticated, or not GitHub), say so in one line and ask the operator
which requests other projects have sent. Give each one they name a disposition
as above. "Could not list" is never "empty".

**An empty queue** is one line: `intake: no open from: requests on <owner/repo>`.

---

## 2. The tech-debt ledger

merge-bar's `working-a-pr` writes accepted known limits and out-of-scope defects,
after a merge, to the AI workspace's routed memory bank (`working-a-pr` §5), in `tech-debt.md`:

```
- [KL] <area/path> — <the limit> — <why accepted> — revisit when <trigger> (PR #N)
- [TD] <area/path> — <defect> → #N (PR #N)
```

Read it from the AI workspace: `oss repo_root ai_workspace` on an ossify
project. Outside one, use the paired workspace next to the repo — a sibling
directory whose `.workspace/pairing.json` names this repo as canonical, commonly
`<repo>-ai`. Resolve the bank as `close/references/harvest.md`, "Where the bank is", says; the line shapes and
PR-reference forms are `working-a-pr` §5's.

```bash
grep -n -E '^- \[(KL|TD)\] ' "<memory-bank>/tech-debt.md"
```

The **surface** is what is being planned. At plan-spine pre-flight, it is the
paths and areas the spine's release plan and feature entry name, plus any path
§4's decomposition adds — the pre-flight read cannot see those yet, so read the
ledger again for them before the decomposition is approved. For a patch, it is
the files the fix will touch. A line
**overlaps** when its `<area/path>` is one of those paths, a parent directory of
one, or the same named area. Overlap is judgment; list only what overlaps — a line
that does not overlap is not named at all, not even as skipped.

For each overlapping line, record exactly one disposition:

- **pulled in** — as a named work item or AC of this spine or patch.
- **still accepted** — with the reason. Say whether its `revisit when` trigger
  has fired; a fired trigger is the reason to pull it in, so accepting it anyway
  needs its own reason.
- **retired** — the code it names is gone. Only an unsuffixed line or one naming the planned repo (`PR #N` for the workspace's canonical, otherwise `PR <owner>/<repo>#N`) can be retired. Show the evidence
  (`git -C "<repo>" ls-files <path>` prints nothing, and the commit that removed
  it), delete the line from `tech-debt.md`, and note the retirement in `SPINE.md` — for a
  patch, which has no `SPINE.md` and never writes another spine's, in the PR's Evidence.
  This is the only write this section makes, and it is in the AI workspace.
- **another repo's** — always, and only, for a line whose `(PR …)` suffix names another repo: name it as not this repo's; never retire or delete it.

No ledger file, or no overlapping line → one line saying which. Never write the
ledger, or anything about it, into the product repository.
