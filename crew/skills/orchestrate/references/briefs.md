# Briefs

A brief is the whole contract the worker will ever see. The worker has no orchestration
context, may be launched where the project's rules do not load, and the layer delivers this
text verbatim, by file (`layers/<layer>.md`, Send) — no preamble, nothing prepended, nothing else.
Every brief carries, in this order:

1. Role, and "state your model in your first reply".
2. Placement: the absolute path the seat sits in — a worktree or a repo path — and, where
   relevant, the ref or SHA it sits at; the worktree templates carry branch and base
   besides.
3. The task, plus any project rule the worker's location will not load, pasted verbatim.
4. The report file's shape — a temp file in the same directory renamed over the path,
   never in pieces — and the forbidden actions for the role.
5. Where the worker speaks: a blocking question is written to the report file, then it
   waits; an escalation is written there, then it stops. A policy refusal is reported,
   never retried around.
6. Planned implementer only: the plan gate.

Angle brackets are slots. Fill every slot; delete nothing else. The `SEAT_` lines are
the operator's approved seat, copied into the brief at launch; a worker that finds its
model is not `SEAT_EXPECTED_MODEL` reports a failed launch and stops.

The report file is replaced whole, never appended to in pieces: the orchestrator's
doorbell compares that file's hash or its identity (`completion.md`), and it reads a
change as a finished report. Write the new content to a temp file in the same directory,
then rename it over the path: the rename is the atomic step, and opening the path is not —
it truncates the file before the content lands, and the doorbell can fire on that
truncation and parse half a report. No tool here documents an atomic rename, so the
requirement is the writer's, not the tool's. A plan, a question and a final report all
replace the file the same way.

Every report-producing brief names its dispatcher's run file as `NOTIFY_RUN` and the worker's
machine as `NOTIFY_MACHINE`, beside its report path. The dispatcher fills `NOTIFY_RUN` only when
the layer detects its pane and the seat is on its machine — otherwise the sentinel `none`, never read
and never sent to. After every rename the worker reads `run.orchestrator` from that file and sends
one line through the layer's Send to `run.orchestrator.pane` — the layer's address of the
orchestrator seat — no `--wait` and no retry, only when its machine is the worker's,
naming the file it actually renamed over. Reading the file at ping time makes every rebind
redirect every ping: a successor top needs no message to a live worker. The message is one
single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal).
The ping only wakes the parent — a parent undetected or on another server keeps the report-file wait
and the run's heartbeat, no push promised — and a skipped or failed send is left as it is: it is never an answer, so after a plan or a question the worker waits at that gate (#810). An operator's own `brief:`
is dispatched as a copy carrying the same envelope, the leaf templates' `MOLT:` line included; the stored file is
never edited, and a stored brief whose fixed run file or fixed machine differs from the run's is surfaced, not overridden; equal values are no conflict, kept as they are.

## A template is a whole contract

**A template is a whole contract.** Every brief template this plugin ships is complete
on its own: no template is defined as "take template X and replace lines Y and Z", and
no template's required content is defined only by reference to another file. Where a
coordinator constructs a child brief, the dispatch it receives carries the child
template it will construct, verbatim.

The rule's operative form is the dispatch matrix:

| Coordinator | Child briefs it constructs | Its dispatch must carry, verbatim |
|---|---|---|
| Spine session (activated) | item implementer, item verifier, correction | `ossify-briefs.md`'s three item bodies, and any body they instantiate |
| Work-PR session | reviewer, PR-fix (fix round), correction | `briefs.md`'s reviewer, fix-round and correction bodies |
| Lane driver (default `run-spine`) | none — its helpers are ossify's subagents | nothing beyond its own brief and `REPORT_PATH` |
| Close session | the demo walk | `briefs.md`'s demo-walk body (below), carried in its dispatch |
| Doctor session | none | nothing beyond its own brief and `REPORT_PATH` |

Ten dispatched templates live in this file: the generic five — planned implementer,
fast implementer, reviewer, verifier, fix round — the four dedicated dispatch
templates the ossify dispatches use — lane driver, doctor dispatch, direct work-item,
non-spine close — and the demo walk a close dispatch constructs for a `user:` entry on
another machine. The correction-request template is a send, not a session, so it carries
no seat.

**An activated ossify spine has four briefs of its own** — spine session, item
implementer, item verifier, and the correction message — in
`references/ossify-briefs.md`. They do not replace the ten here, which still govern
every other dispatch; the item verifier's CLAIMS is this file's verifier CLAIMS body,
filled into its brief by the coordinator, and `ossify-briefs.md` does not restate it.

## Planned implementer

`<owner/repo>` is the repository the call targets, read from its own checkout: `gh repo view "$(git -C "<repo-root>" remote get-url origin)" --json nameWithOwner -q .nameWithOwner`. `<repo-root>` is that repository's checkout, not the directory you are in: a PR lives in the canonical even when you run from the AI workspace. Never build the name from a folder name: an AI workspace's folder and its GitHub repo often differ.

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

SEAT_COMMAND=<the command this seat was launched with, verbatim from agents.md> — a record of your own launch: you are already that seat, never run it
SEAT_EXPECTED_MODEL=<the model the banner or screen must show>; if the model you are running is not it, that is a failed launch — report it and stop
SEAT_EFFORT=<the effort this seat was launched at>
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report implementer] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
SCRATCH_DIR=<this seat's scratch directory: scratch output and commit-message files go here>
PR_BODY_TEMPLATE=<the installed merge-bar's `skills/opening-a-pr/references/pr-body.md`, pasted verbatim; ossify's `skills/work-pr/references/pr-body.md` where only ossify is installed; `none` only where neither is>
ROLE: implementer. State the model you are running in your first reply, then continue.

PLACEMENT: worktree <abs-path>, branch <branch>, base <base-branch>. Use git -C for every
git command; cd does not persist.

TASK: <objective in two or three sentences, with the acceptance criteria and the test
command that proves them>.
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

PLAN GATE: before your first edit, write your plan (files to touch, order, tests first)
to your report file at REPORT_PATH, then wait. Implement only what the orchestrator's
reply approves.

DONE: commit on <branch> with messages written to a file under SCRATCH_DIR and `git commit -F`; push;
write the PR body to a file under SCRATCH_DIR — every section of the repository's own PR
template first, if it has one, kept and filled; then PR_BODY_TEMPLATE's headings in order,
the Merge bar block word for word, each field filled as its "Filling each field" line says,
Evidence only from commands you ran (where it is `none`: what changed and the test commands
with their results) — and open the PR from the worktree with `gh pr create --repo
<owner/repo> --base <base-branch> --head <branch> --title "<title>" --body-file <that file>`.
Then write your report file with this body:
  Changed: <commit SHAs and the count of files touched>
  Evidence: <each test command with its pass and fail counts; full output in the report>
  PR: <number and head SHA>
  Open: <issue or finding ids, one per line>
  Files: <paths touched, plus any separate file holding longer narrative>

MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt implementer] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: merge, delete a branch, force-push, edit files outside the worktree, or run any
subagent — your report file at REPORT_PATH and files under SCRATCH_DIR are the exceptions
outside it, as the ossify
briefs say. When blocked, write the question to your report file and wait; when stuck,
write an escalation there and stop.
If a tool or policy refuses you, report it verbatim and stop that step.
```

## Fast implementer

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

SEAT_COMMAND=<the command this seat was launched with, verbatim from agents.md> — a record of your own launch: you are already that seat, never run it
SEAT_EXPECTED_MODEL=<the model the banner or screen must show>; if the model you are running is not it, that is a failed launch — report it and stop
SEAT_EFFORT=<the effort this seat was launched at>
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report implementer] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
SCRATCH_DIR=<this seat's scratch directory: scratch output and commit-message files go here>
PR_BODY_TEMPLATE=<the installed merge-bar's `skills/opening-a-pr/references/pr-body.md`, pasted verbatim; ossify's `skills/work-pr/references/pr-body.md` where only ossify is installed; `none` only where neither is>
ROLE: implementer. State the model you are running in your first reply, then continue.

PLACEMENT: worktree <abs-path>, branch <branch>, base <base-branch>. Use git -C for every
git command; cd does not persist.

TASK: <one bounded change, with the exact test command that proves it>.
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: commit with a message written to a file under SCRATCH_DIR and `git commit -F`; push; <write
the PR body to a file under SCRATCH_DIR — every section of the repository's own PR template
first, if it has one, kept and filled; then PR_BODY_TEMPLATE's headings in order, the Merge
bar block word for word, each field filled as its "Filling each field" line says, Evidence only
from commands you ran (where it is `none`: what changed and the test commands with their
results) — and open the PR from the worktree with `gh pr create --repo <owner/repo> --base
<base-branch> --head <branch> --title "<title>" --body-file <that file>` | push to the existing
PR>. Then write your report file with this body:
  Changed / Evidence / PR / Open / Files as ids, SHAs, counts and a report path.

MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt implementer] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: merge, delete a branch, force-push, edit files outside the worktree, or run any
subagent — your report file at REPORT_PATH and files under SCRATCH_DIR are the exceptions
outside it. When blocked,
write the question to your report file and wait; when stuck, write an escalation there and
stop; report refusals verbatim.
```

## Reviewer

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

SEAT_COMMAND=<the command this seat was launched with, verbatim from agents.md> — a record of your own launch: you are already that seat, never run it
SEAT_EXPECTED_MODEL=<the model the banner or screen must show>; if the model you are running is not it, that is a failed launch — report it and stop
SEAT_EFFORT=<the effort this seat was launched at>
REVIEW_INVOCATION=<this seat's agent's `review:` from agents.md, else `/code-review <PR> <LEVEL>`, with `<PR>`, `<PR_URL>` and `<LEVEL>` filled by the orchestrator>
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report reviewer] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
ROLE: reviewer. State the model you are running in your first reply, then continue.

PLACEMENT: worktree <abs-path> checked out at PR <number>'s head <sha>.

TASK: run REVIEW_INVOCATION as given — its level is the one the orchestrator decided, not
one you pick; outside an activated ossify spine the level is `medium` unless the
orchestrator names another. Your first reply must state the model you are running; it is expected to
be SEAT_EXPECTED_MODEL, and a mismatch is a failed launch to report, not to work around.
Let the review finish, then write your report file carrying, in this order:
`Findings: none` on a clean review, or else every finding in this body, one per line
  <file>:<line> | P0|P1|P2|P3 | <claim in one sentence>
then, in either case:
  Reviewed head: <sha>
  Summary: <two sentences>
The head line is not optional on a clean review: nothing ties a verdict to a SHA
without it. When REVIEW_INVOCATION is `/merge-bar:review-pr`, your report file is instead
that command's report, whole, in merge-bar's `skills/reviewing-a-pr/references/report.md`
shape; its `Head:` line is the reviewed head.

RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt reviewer] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: edit any file other than your report file, post anything to GitHub, or run a second
review. Your findings
travel only in your report file. If REVIEW_INVOCATION refuses or errors, report its output
verbatim and stop. A blocking question goes in your report file, then wait; an
escalation goes there too, then stop.
```

## Verifier (read-only)

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

SEAT_COMMAND=<the command this seat was launched with, verbatim from agents.md> — a record of your own launch: you are already that seat, never run it
SEAT_EXPECTED_MODEL=<the model the banner or screen must show>; if the model you are running is not it, that is a failed launch — report it and stop
SEAT_EFFORT=<the effort this seat was launched at>
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report verifier] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
SCRATCH_DIR=<this seat's scratch directory: scratch output and commit-message files go here>
ROLE: verifier, read-only. State the model you are running in your first reply, then
continue.

PLACEMENT: <worktree abs-path or repo path>, at <ref or sha>. A re-check is this brief sent
again, every slot refilled: judge the tree named here, never your previous check's. Two slots
change: this line names the tree to judge now, and a fresh `REPORT_PATH` in the same report directory, never the first report's.

CLAIMS:, a numbered list the orchestrator fills from the work item's spec:
  1. [ac] <acceptance criterion or requirement>: <how to check>
  2. [diff] The diff matches the requirement: read the requirement, then the diff —
     `git diff --cached <the item's base sha>`, which covers a committed head and a staged tree.
  3. [mutation] When the item adds or changes a test: that test fails when the item's
     implementation edits, not the test, are reverted in a disposable worktree; a revert
     that changes no file is `cannot determine`, naming the paths tried. When no test is
     added or changed, or the item changes only tests, delete this claim (never `cannot determine`);
     a test-only item is deleted here, never judged an empty revert.
  4. [standards] The diff follows <standards file> and the conventions the repo follows in
     fact: name <standards file> by the path filled here, and quote the rule line, or the
     neighbouring committed file, and the hunk, each verbatim, never paraphrased. <standards file> is
     the dispatcher's fill: `CODING_STANDARDS.md` at the paired AI workspace root (the
     directory beside this repo whose `.workspace/pairing.json` has `canonical.name` equal
     to this repo's name), else at the repo root, else the ossify memory bank's
     `03-code-patterns.md`, else `none — looked at <paths>`. With none, judge
     conventions-in-fact alone; absence of a file is never `cannot determine`. Never
     delete this claim.

RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: write your report file, one line per claim, then the caveats:
  1. [<tag>] <claim>: pass | fail | cannot determine — <evidence, commands and output verbatim>
  `Cannot determine` counts as fail; the suite on the head is not a claim (its
  check-runs were read before dispatch). Caveats: <what the check could not see>

MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt verifier] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: commit or push, or edit a tracked file outside the mutation check. That check
may temporarily edit one — in the disposable worktree, reverted before the report.
Scratch output is fine — write it under SCRATCH_DIR=<the seat's scratch directory>, never
commit it — and run in a disposable worktree. Any other write: stop, and write an escalation to your report file instead.
```

## Fix round (retained implementer, after disposition)

Attach it to the same pane by sending it this brief (the layer file says how) —
there is no attach or ownership-transfer call; the same session simply receives its
next brief. It carries its own seat lines, TASK, completion body and NEVER line, and no
part of it is rebuilt from another template's.

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

SEAT_COMMAND=<the command this seat was launched with, verbatim from agents.md> — a record of your own launch: you are already that seat, never run it
SEAT_EXPECTED_MODEL=<the model the banner or screen must show>; if the model you are running is not it, that is a failed launch — report it and stop
SEAT_EFFORT=<the effort this seat was launched at>
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report implementer] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
SCRATCH_DIR=<this seat's scratch directory: scratch output and commit-message files go here>
ROLE: implementer, fix round. State the model you are running in your first reply, then
continue.

PLACEMENT: worktree <abs-path>, branch <branch>, base <base-branch>. Use git -C for every
git command; cd does not persist.

TASK: work PR <number> to zero unresolved review threads. Inputs, in priority order:
  1. Disposition: <list>. Fix every item on it as dispositioned; defer or reject
     nothing on it yourself.
  2. Every unresolved GitHub review thread on the PR, including bot reviews that arrive
     after each push. Count them with GraphQL reviewThreads, not the REST list.
  3. Review bodies and top-level PR conversation comments — reviewThreads does not
     return them — re-fetched after each push.
Fix a class in one commit, not one comment at a time. Push after each class. Resolve
threads only after the fix is on the head the reviewer can see. Every thread ends
fixed, deferred with a comment linking the tracked issue, or rejected with the
evidence; P0 and P1 are never deferred.
<With ossify installed replace this TASK with: run `/ossify:work-pr <number>
--repo-root <worktree holding the PR branch>`; the disposition above is a third finding
signal; stop at work-pr's merge ask and put its ledger in your report file —
except inside a work-PR session, whose fix seat works the fix list only
and would otherwise open a second merge loop inside the one that briefed it.>
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

A finding that arrives after the disposition is not on that list: write it to your
report file and wait, resolving it only once the orchestrator's answer arrives.

DONE: commit with a message written to a file under SCRATCH_DIR and `git commit -F`; push to the PR's
branch. Then write your report file with this body:
  Changed / Evidence / PR / Open / Files as ids, SHAs, counts and a report path.

MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt implementer] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: merge, delete a branch, force-push, edit files outside the worktree, or run any
subagent — your report file at REPORT_PATH and files under SCRATCH_DIR are the exceptions
outside it. When blocked,
write the question to your report file and wait; when stuck, write an escalation there and
stop; report refusals verbatim.
```

That last rule sits after the TASK block, so the ossify replacement and a work-PR
session's fix brief both keep it: the one clause a coordinator removes is the
replacement, never the paragraph.

## Lane driver (the default `run-spine` lane)

Dispatched to one session, which is ossify's orchestrator for that spine rather than an
implementer: its `ROLE` line is the lane driver's. It carries no `RUN_JSON` and no
`MECHANICS` identity — those belong to the activated spine brief — and orders no teardown
of item pairs: the default lane creates none.

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

SEAT_COMMAND=<the command this seat was launched with, verbatim from agents.md> — a record of your own launch: you are already that seat, never run it
SEAT_EXPECTED_MODEL=<the model the banner or screen must show>; if the model you are running is not it, that is a failed launch — report it and stop
SEAT_EFFORT=<the effort this seat was launched at>
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report coordinator] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
ROLE: lane driver for ossify spine <spine id> — ossify's orchestrator for that spine, not an
implementer. State the model you are running in your first reply, then continue.

PLACEMENT: <the tree the lane runs from — abs path>.

TASK: dispatch `/ossify:run-spine <spine id>` and let it drive. You hold the state lock,
commit at each close, and merge at the barrier; the round's items are not yours to
implement.
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: write your report file with this body:
  Spine: <spine id>
  Rounds: <each round's items and their state — closed | active | halted>
  Barrier: <the barrier's result>
  Merged: <the SHAs you merged, one per line>

MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt coordinator] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: run a second review — ossify's own gates are the lane's review; edit ossify's
contract or any other plugin; work an item yourself. Running this lane's subagents and
merging at the barrier are this seat's job, not forbidden ones. When blocked, write the
question to your report file and wait; when stuck, write an escalation there and stop;
report refusals verbatim. Never signal processes by listing them (`ps`, `pgrep`, `pidof`, `/proc`); stop your own job by its id (OMP `write proc://<id>/kill`, Claude Code `TaskStop`).
```

## Doctor dispatch

One dispatch, one session. The operator's `/ossify:doctor` surface arguments ride in the
TASK verbatim. What the dispatch may write is ossify's contract, and this file does not
adjudicate it: the brief states only what the seat returns.

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

SEAT_COMMAND=<the command this seat was launched with, verbatim from agents.md> — a record of your own launch: you are already that seat, never run it
SEAT_EXPECTED_MODEL=<the model the banner or screen must show>; if the model you are running is not it, that is a failed launch — report it and stop
SEAT_EFFORT=<the effort this seat was launched at>
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report coordinator] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
ROLE: doctor session. State the model you are running in your first reply, then continue.

PLACEMENT: <the tree the dispatch runs from — abs path>.

TASK: <the operator's dispatch verbatim, its surface arguments included>.
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: write your report file carrying that dispatch's own result, verbatim. Never a
`commit …; push; open the PR` line: this dispatch's result is its own.
MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt coordinator] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: commit, push, open a PR, or merge. Questions and escalations go in your report
file, not to the operator: when blocked, write the question there and wait; when stuck,
write an escalation there and stop; report refusals verbatim. Never signal processes by listing them (`ps`, `pgrep`, `pidof`, `/proc`); stop your own job by its id (OMP `write proc://<id>/kill`, Claude Code `TaskStop`).
```

## Direct work-item

A `/ossify:work-item <handoff path>` the operator asked for directly, with no activated
spine: no SEATS row is involved and the brief is this file's own. The unit it runs may be
read-only, so the brief never orders a commit, push or PR. Launched as a guarded `implementer`
seat — its report, scratch and handoff directories in `SEAT_MODS_ALLOW` (the layer's `Seat marking`).

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

SEAT_COMMAND=<the command this seat was launched with, verbatim from agents.md> — a record of your own launch: you are already that seat, never run it
SEAT_EXPECTED_MODEL=<the model the banner or screen must show>; if the model you are running is not it, that is a failed launch — report it and stop
SEAT_EFFORT=<the effort this seat was launched at>
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report implementer] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
ROLE: implementer, direct work item. State the model you are running in your first reply,
then continue.

PLACEMENT: worktree <the handoff's worktree — abs path>, branch <branch>, base
<base-branch>. Use git -C for every git command; cd does not persist.

TASK: run `/ossify:work-item <handoff path>` — the operator's command, verbatim — and let it
complete; its contract binds you and decides what this unit writes or stages. Never commit,
push or open a PR on its behalf: the unit may be read-only.
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: write your report file carrying that work item's own result, verbatim — its
structured return. Never a commit, push or PR line.
MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt implementer] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: commit, push, open a PR, or merge; edit files outside this worktree; or run any
subagent. The two exceptions to that scope are this item's own report.md, which the
work-item contract has you author beside the handoff and spec, and your report file at
REPORT_PATH; nothing else outside the worktree. When blocked, write the question to your
report file and wait; when stuck, write an escalation there and stop; report refusals
verbatim.
```

## Non-spine close

A `/ossify:close r1` or `r1.s2.w3` the operator asked for directly. Close-shaped, and it
carries no `SPINE_ID`: that identity belongs to the spine close brief in
`ossify-pr-briefs.md`, a different dispatch. The top marks it `coordinator` before its
command (the layer's `Seat marking`).

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

SEAT_COMMAND=<the command this seat was launched with, verbatim from agents.md> — a record of your own launch: you are already that seat, never run it
SEAT_EXPECTED_MODEL=<the model the banner or screen must show>; if the model you are running is not it, that is a failed launch — report it and stop
SEAT_EFFORT=<the effort this seat was launched at>
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report coordinator] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
ROLE: close session. State the model you are running in your first reply, then continue.

PLACEMENT: <the tree the close runs from — abs path>.

TASK: run `/ossify:close <id>` — the operator's command, verbatim — and let it complete or
halt. Whatever it hands off, you do not drive.
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: write your report file carrying exactly one of three results: every PR the close
returned — one line per PR, `<repo> #<number> <url>`; the single word `closed` when it
recorded with no PR open; or `halted: <step> — <evidence>` when it stopped, naming the
failing step and repo and, on its own line, what it had already opened:
`opened: <repo> #<n> <url> …` or `opened: none` — a close can halt after opening in one
repo, and hiding those PRs strands them. After the result, carry the close's own summary,
verbatim — the message the ceremony ends with — because the result alone is a protocol
token, and the report file is all the parent's contract reads. Never a `commit …; push;
open the PR` line of your own.
MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt coordinator] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: create a seat, merge on your own authority, re-invoke `/ossify:close`, or open a PR
of your own — a halt settles this dispatch, and a remediated one is a fresh session the
orchestrator dispatches.
Questions go up in your report file: when blocked, write the question there and wait; when
stuck, write an escalation there and stop; report refusals verbatim. Never signal processes by listing them (`ps`, `pgrep`, `pidof`, `/proc`); stop your own job by its id (OMP `write proc://<id>/kill`, Claude Code `TaskStop`).
```

Nothing dispatches a PR loop for this close: it is the operator's own dispatch, so its
returned list is relayed to the operator, who decides what runs next. The spine chain in
`lifecycle.md` step 1b — a work-PR session per returned PR, then the record pass — is
that step's and stays scoped to it.

## Demo walk

One `user:`-type demo-ledger entry an operator assigns to another machine, walked by a seat
on that machine: a close session drives no desktop, so the entry runs where the product's app
runs. The close dispatch constructs this brief from its `DEMO_WALK` row — one seat per entry,
from that row only — and carries this body verbatim (the dispatch matrix above). The seat is
marked a guarded `verifier` before its command (the layer's `Seat marking`): read-only, its
`SEAT_MODS_ALLOW` this report directory. This is the one dispatched template with no `MOLT:`
line: a bounded walk writes nothing outside itself and hands nothing off.

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

SEAT_COMMAND=<the command this seat was launched with, verbatim from agents.md> — a record of your own launch: you are already that seat, never run it
SEAT_EXPECTED_MODEL=<the model the banner or screen must show>; if the model you are running is not it, that is a failed launch — report it and stop
SEAT_EFFORT=<the effort this seat was launched at>
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report verifier] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
ROLE: demo walk. You are read-only, a guarded `verifier` marked before your command (the layer's `Seat marking`), its `SEAT_MODS_ALLOW` this report directory. State the model you are running in your first reply, then continue.

PLACEMENT: <the checkout the walk drives — abs path on this machine>.

DEMO ENTRY — the `user:` demo-ledger line this walk runs, verbatim:
<id> — text: <the journey, as the ledger words it>
outcome: <what the user should observe>

TASK: walk that entry against the product on this machine: perform its text, observe its
outcome, and record the evidence the walk requires — the commands you ran and their output,
and a screenshot path where a screen is involved, with the screenshot written into your
report file's own directory. You edit no product file.
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: write your report file with the entry's id, its text and its outcome, one result —
`pass`, or `fail: <what did not match>` — and the evidence above; then stop. Never a commit,
push or PR line.
NEVER: write outside the walk — your report file at REPORT_PATH and the screenshots in that
file's own directory are the only files you write; no repository edit, no product file, no
commit, no push, no seat of your own, no subagent; a question or a refusal goes in that
report file.
```

## Correction request (one send, no new session)

A malformed, incomplete, or wrongly-shaped report from a live session is corrected in
place, never by a new session: one send to that session, nothing else — the body below by file (the layer's Send).

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

Your report file for <task id> is malformed or incomplete: <the missing or wrong
field, and what is wrong with it>. The exact shape wanted: <the field, restated
from your brief>. No other work; rewrite your report file at <REPORT_PATH>, send the
tagged `[crew report <role>]` ping again after the rename as your brief's PING line says, then stop
— the orchestrator waits and rereads it.
```

If one send does not fix the report, it goes to the operator.
