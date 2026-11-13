# ossify spine PR briefs — the close and the work-PR sessions

The two briefs the PR lane needs. Same rules as `briefs.md`: a brief is the
whole contract its reader will ever see — fill every slot, delete nothing else.

> **Editing note.** Asserted to contain no subagent invocation form (`tests/test-ossify-spine-contract.sh`).
> Say the prohibition; never paste the call shape.

---

## Close session (one fresh seat per dispatch, created by the top)

The top marks it `coordinator` before its command (the layer's `Seat marking`).
It creates no seat but one demo-walk seat per `user:` entry `DEMO_WALK` names, and returns a
list; only the successful record pass is single and conditional.

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

ROLE: ossify spine close for SPINE_ID.

PLACEMENT: <abs path of the worktree the spine's lane ran from>.

INJECTED IDENTITIES — use these verbatim; do not rediscover them:
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report coordinator] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
SPINE_ID=<spine id>
CLOSE_COMMAND=<the command this seat was launched with, from its machine entry> — a record of your own launch: you are already that seat, never run it
CLOSE_EFFORT=<the effort this seat was launched at>
CLOSE_REVIEW_LEDGER=<every close review's ledger for this spine, oldest first,
verbatim — or "none">
DEMO_WALK=<the demo-walk seat's row> for <the `user:` entry ids it walks> — the top fills the
row with the seat's resolved profile (the row shape `config.md` defines) and the ids from the
operator's assignment; otherwise the sentinel `none`, which walks nothing and launches no seat
Everything you tell the top goes in your report file at REPORT_PATH.

TASK: run `/ossify:close SPINE_ID` and let it complete or halt. Whatever it hands
off, you do not drive: if it opens PRs and halts, that halt is your result. The
ceremony's own steps are yours to perform, including
the close review the ceremony itself runs over the accumulated diff before any PR
opens — `/ossify:close` doing its job, not a review you dispatch. Its
findings are yours to report, never to fix: ossify keeps that review advisory —
it halts no ceremony gate — but this dispatch is stricter, and a `fix now`
disposition ends this dispatch as `halted: close-review — <ledger>`,
carrying each finding, its `target_repo`, its decision and the reason; the top
dispatches the writer — per `ossify-close-writer.md`, one per affected hosting
repo — and a fresh close.

**A `user:` entry DEMO_WALK names runs on the machine its row's `host:` names** — the close
session's own or another. Build the entry's fixture there first (clone, worktree, whatever the
`user:` line needs): the close session builds it, never the walker, which only reads and walks
it. Then launch the
demo-walk seat from that row — the seat's profile, verbatim — marked `verifier` before its
command (the layer's `Seat marking`), every call for it carrying the layer's Machines step for
that host, and confirm its model as the row's `model_shows` says (the layer's model read; a mismatch is a failed launch, reported upward, never worked around); send it `briefs.md`'s `demo walk` body, carried in this dispatch, with that entry
verbatim; wait on it through the layer's Wait, read its report where it was written
(`Machines`), release the seat, and take its result as the entry's — a failing walk halts this
dispatch as the ceremony's walk does. One seat per entry, from that row only; every other
entry the ceremony walks as `/ossify:close` says.

On a record pass, write the accepted findings
CLOSE_REVIEW_LEDGER carries into the retrospective's carried-and-lessons
section, by class.

RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: write your report file, carrying exactly one of three results: EVERY PR the close opened — one line per opened PR,
`<repo> #<number> <url>`: only a remote product hosting repo (a declared
`target_repo`) gets one, a remote-less repo lands locally in the same close and is
never a PR; the single word `closed` when it recorded the spine with no PR open; or
`halted: <step> — <evidence>` when it stopped, naming the failing step and repo and,
on its own line, what it had already opened: `opened: <repo> #<n> <url> …` or
`opened: none`. A multi-repo close can halt after opening in one repo — hiding those
PRs strands them. Whenever the close review ran, carry its ledger verbatim too,
naming each finding, its `target_repo`, its decision and the reason: the record pass
cannot reconstruct it. Then: Changed / Evidence / Open / Files as ids, SHAs, counts and a report path.

MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt coordinator] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt's handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.
NEVER: create a seat — one demo-walk seat per `user:` entry its `DEMO_WALK` names is the
only exception, launched from that row, waited on and released as the TASK says — merge on
your own authority, ask the operator anything
(questions go up to the top in your report file), or re-invoke `/ossify:close` — a halt
settles this dispatch; remediated, the top dispatches a fresh close session, marked
`coordinator` before its command (the layer's `Seat marking`).
Report a refusal verbatim. Never signal processes by listing them (`ps`, `pgrep`, `pidof`, `/proc`); stop your own job by its id (OMP `write proc://<id>/kill`, Claude Code `TaskStop`).
```

---

## Work-PR session (one fresh seat per returned PR)

Created by the top **in that PR's hosting-repo worktree**, so REPO_ROOT is the path this
seat already sits in, never a fixed canonical path. Launched from the `work-PR session`
seat the project file names — marked `coordinator` before its command
(the layer's `Seat marking`) — with the top's merge-executor assignment and PRIOR_REVIEW, it
owns both PR seats inside a `run.json` of its own. The top waits on it as a coordinator
seat (`completion.md`, Completion).

```text
PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker's implementation plan is the top's to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.

ROLE: work-PR session for PR PR_NUMBER in PR_REPO, and coordinator of its two
seats.

PLACEMENT: REPO_ROOT — the worktree holding this PR's branch.

INJECTED IDENTITIES — use these verbatim; do not rediscover them:
REPORT_PATH=<the absolute path this seat writes its report to>, replaced whole — a temp file in the same directory renamed over the path, never in pieces; NOTIFY_RUN=<the absolute path of the dispatcher's run.json — filled only when the layer can address the dispatcher's seat and your pane is on the dispatcher's machine; otherwise the sentinel `none`, which is never read or sent to>; NOTIFY_MACHINE=<your pane's machine, as the dispatcher's run.json records machines>
PING_SEND=<the layer's Send, filled by the dispatcher: how one line reaches a pane on your layer>
PING: after every report rename — plan, question, escalation, late finding, final report — one send, no `--wait`, no retry, and only when NOTIFY_RUN is not `none`: read `jq -r '"\(.run.orchestrator.pane) \(.run.orchestrator.machine)"' <NOTIFY_RUN>` at that moment — one line, the pane then the machine; only when that machine equals NOTIFY_MACHINE, `<PING_SEND> '[crew report coordinator] <task id> <kind> <path>'`, one single-quoted literal argument (a single quote in it is written `'\''`; `$` and backticks stay literal). A failed read or another machine skips the send. The report file is the contract; a failed send is left as it is. A skipped or failed send is never an answer: after a plan or a question, wait at that gate as if it had been delivered (#810).
RUN_JSON=<abs path of the run.json you write and own — never the top's>
MECHANICS=<the directory this session read the orchestrate skill's SKILL.md from>/references/layers/<layer>.md
PR_REPO=<owner/repo>, which the dispatcher fills by `gh repo view "$(git -C "<the PR repository's checkout>" remote get-url origin)" --json nameWithOwner -q .nameWithOwner`, never from a folder name
PR_NUMBER=<number>
REPO_ROOT=<abs path of this seat's worktree>
WORKPR_COMMAND=<the command this seat was launched with, from its machine entry> — a record of your own launch: you are already that seat, never run it
WORKPR_EFFORT=<the effort this seat was launched at>
REVIEWER=<agent name> | <command> | model: <expected model> | effort: <effort> | model_shows: <banner|screen> | brief_delivery: <inject|file> | host: <machine>[ | rail: <rail>]
REVIEW_INVOCATION=<the reviewer's agent's `review:`, else `/code-review <PR> <LEVEL>`, with PR_NUMBER, the PR URL and the level the top decided filled in>
PRFIX=<agent name> | <command> | model: <expected model> | effort: <effort> | model_shows: <banner|screen> | brief_delivery: <inject|file> | host: <machine>[ | rail: <rail>]
PRIOR_REVIEW=<the prior dispatch's durable review record — ran, reviewed head,
clean/findings state, summary, fix rounds run, ledger/comment refs — "none", or "covered">
MERGE_EXECUTOR=<session|operator — the top's explicit assignment>
STOPPING_RULE=<`merge-bar` where merge-bar is installed; otherwise the rule agreed before the PR opened>
Everything you tell the top — a question, the round summary, the merge ask, your report —
goes in your report file at REPORT_PATH; then wait, or stop where this brief says so. Your
command's syntax comes from the layer's own guide (`references/layers/<layer>.md`). MECHANICS addresses a run's orchestrator, which for
your own seats is you: every seat you launch, send to, wait on or release follows it,
except that where it says the operator, you mean the top, through your report file.

TASK: drive PR_NUMBER to a merge on the top's word, or a one-way door to step 6's hand-off.
  1. Create RUN_JSON for your two seats, or continue it if it exists. A session that
     binds an existing `run.json` rewrites `run.orchestrator` to its own address from
     the layer's Identity — dagr's stable-agent fallback otherwise — in the same producer loop every other
     write takes. On creation and on continue/rebind, write `run.orchestrator.machine` beside the pane
     — this server's machine, per MECHANICS — and `run.orchestrator.session` from the layer's Identity, as step 1 of `lifecycle.md` beside MECHANICS says. Stay its single writer, writing as that step says.
     Nothing of yours goes in the top's run.json.
  2. Decide your startup branches BEFORE any seat exists. MERGE_EXECUTOR must read
     exactly `session` or `operator` — a missing, invalid or unknown assignment is
     asked upward and nothing is created. Then branch on PRIOR_REVIEW. `none` means
     the top dispatched you onto a PR no earlier work-PR dispatch has covered — an
     initial run, and step 3 creates the reviewer. `covered` means a dispatch worked
     this PR and left durable evidence its delegated review ran but persisted no record:
     a resumed run, no reviewer created, the current head's signals as your baseline,
     and only where that review's findings survive it — proof of execution with none is
     not `covered`: halt and ask the top. Evidence absent the value is not spent; ask. A record whose reviewed head equals
     the current PR head is a resumed run: skip only step 3's reviewer creation —
     the review already ran — and enter step 4 with the record and its unresolved
     findings as your disposition baseline. A record on a moved head is a resumed
     run too: re-fetch the GitHub signals; the prior review and its unresolved
     findings still baseline the disposition. A record inconsistent with the PR's
     live state — wrong PR, a referenced ledger that does not exist — is neither:
     ask the top and create nothing. You did not open this PR.
  3. Initial runs only: create the reviewer FIRST from its REVIEWER row — every launch or
     re-creation of it carries the guard before its command (role `reviewer`, `MECHANICS`
     Seat launch) — confirm the model as its row's `model_shows` says,
     and brief it to run REVIEW_INVOCATION. Read the findings from its
     report file — it posts nothing; that file is the only copy. Validate it against the reviewer
     brief's schema — `Findings: none` with `Reviewed head:` and `Summary:`, or finding lines plus both;
     a `/merge-bar:review-pr` report instead validates with its `## Coverage` table and a `Bar:` line on
     every `### C<n>` class, its `Head:` the reviewed head (no class is a clean review; a class blocks
     unless its `Bar:` is `non-blocking` or it carries `Closes:`, and a `Still open:` class keeps its
     `Bar:`) — before passing anything on; on a malformed body send ONE bounded correction request and
     re-validate, escalating a second malformed body to the top. A mismatched reviewed head makes the
     review historical, a `Head:` that is not the PR head included — re-fetch the GitHub signals rather
     than commissioning another; absent or untriaged signals never satisfy the merge gate.
  4. THEN run `/ossify:work-pr $PR_NUMBER --repo-root $REPO_ROOT` — initial
     runs carrying those findings in as its disposition inputs, resumed runs
     carrying the PRIOR_REVIEW baseline. It owns the whole loop — started first
     it would reach its merge ask on pre-existing signals, your review never
     run. In this seat its "drive the fixes" dispatches to the PR-fix seat —
     you edit nothing yourself — and its merge ask is your question to the top
     in step 6.
  5. Disposition every finding — the reviewer's, the bot threads, and the
     review bodies and top-level PR comments that `reviewThreads` does not
     return — post the ledger, file deferrals as tracked issues in PR_REPO, and
     dispatch fix tasks to a PR-fix seat — briefed from `briefs.md`'s fix-round
     brief but **without the ossify replacement clause**, which would start a
     second merge loop inside this one; it works the fix list you give it,
     pushes, and returns `fixed in <sha>` per finding, never running work-pr or
     asking a merge — created from its PRFIX row —
     every launch of it carries the guard before its command (role `implementer`,
     `MECHANICS` Seat launch); confirm its model as the row's `model_shows` says before the first fix task; a mismatch is a failed launch to ask about, never to work
     around. The delegated review ran once, on the head it was briefed with, and that seat is
     released after its report file validates. Each push moves the head under that verdict:
     before the next disposition round, re-fetch the GitHub review signals and the thread state
     on the new head — the bots review every push where they are installed, so the current-head
     verdict is read there; where none is, the reviewer seat is re-dispatched over the fix range
     — re-created if it was released, and guarded before its command then (role `reviewer`,
     `MECHANICS` Seat launch); a `/merge-bar:review-pr` reviewer is a fresh seat running
     `/merge-bar:review-pr <PR_URL> --round <n> --previous <previous report path>`. A post-disposition
     finding returns through a blocking question to the
     top before any seat acts on it, never fixed by you or silently deferred. Relay ONE batched
     summary per round; STOPPING_RULE decides when fixing stops, counting the fix rounds
     PRIOR_REVIEW carries. `merge-bar` means `/ossify:work-pr` runs `working-a-pr`, whose
     round stop decides and whose Merge bar is never narrowed by a stopping rule.
  6. Where merge-bar's `working-a-pr` runs, a one-way door — the body's `Door: one-way`, or no
     `Door:` line — is never merged here: at a clean gate your report hands it to the top, the merge
     holder, with the reviewed head OID, the ledger and merge-bar's
     `skills/working-a-pr/references/one-way-door.md`, then release your seats as below. Otherwise,
     when the gate is clean, ask the top for the merge word. MERGE_EXECUTOR is the top's explicit
     assignment, not something you infer — never parse permission settings, never probe by
     attempting a merge. On either reply, record the word and any granting order the reply names in the ledger.
     On `session`: on the reply, re-fetch the whole gate set once more and
     merge bound to the named SHA, as a merge commit. On `operator`: your ask
     names the operator as executor, the approved SHA and the merge-commit
     convention; on the reply you re-fetch the gates, the operator's landing
     is a merge commit on that same SHA — never a squash or rebase — and you
     confirm and report the resulting merge SHA, surfacing any deviation rather than
     adopting it. Either way a later permission denial is surfaced verbatim, never
     bypassed. Then release both seats and close the workspaces you created for them;
     as MECHANICS's Teardown says, with the layer's Run workspace list showing none of them — only what
     you can prove is yours; report any teardown you cannot complete rather than claiming it.
     You are exempt from any record-pass hold.

RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: write your report file, returning PR_REPO, PR_NUMBER and every ledger comment id, plus one
of three outcomes: the merge SHA; `handed off: one-way <reviewed head OID>`, only for step 6's
one-way door; or `open: <PR url> at <head sha>`, with RUN_JSON's path and the pane its
`run.orchestrator` names at writing, when the word you were relayed was wait or leave open, or at a fix-round boundary once the context-ceiling notice or a molt warning has fired — then stand
down your own armed waits before you return, as the top and a spine session do: one
report must wake one session (`lifecycle.md`, "Your own rotation"). On the open shape, first release both seats and close the workspaces you created for them, as step 6 does; then persist its review record —
whether the delegated review ran, its reviewed head, its clean/findings state and
summary, the fix rounds run, and the durable ledger/comment references — the next
fresh work-PR dispatch receives it as PRIOR_REVIEW in a fresh brief, the review
state reused. All three settle this dispatch; on the open shape the top does not advance to the record
pass — a later merge is a new work-PR dispatch, not a resumption of this one. Then:
Changed / Evidence / Open / Files as ids, SHAs, counts and a report path.

MOLT: if molt warns you, send one ping, `<PING_SEND> '[crew molt coordinator] <pct> <task id>'` (read as PING says; never when NOTIFY_RUN is `none`), and return `open:` at the next fix-round boundary, or, with no fix round in hand, return `open:` at once; molt never clears this session. If molt's handoff command arrives mid-round, still finish the round: a round molt's block cuts short is relayed to the operator by your parent. End the reply that writes `open:` with `MOLT-HANDOFF: <REPORT_PATH>`. A wake or message after that write is added to your report verbatim, never acted on.
NEVER: talk to the operator — every question goes up to the top; squash; merge
without the top's relayed word; delete a branch; or dispatch a second full review — one
delegated review per PR (`roles.md`, step 8); a fixed head takes one scoped delta re-review. Never signal processes by listing them (`ps`, `pgrep`, `pidof`, `/proc`); stop your own job by its id (OMP `write proc://<id>/kill`, Claude Code `TaskStop`).
```
