# The handoff document — core sections and adaptation

Six sections plus an embedded read-out. The six are a floor, not a ceiling:
extend freely per project shape, and never cut below them silently — a section
with genuinely nothing to say carries one line saying so, because an absent
section and a forgotten one are indistinguishable to the reader.

**File name:** match the repo's handoff naming precedent where one exists —
precedent covers naming, not just location (`compose.md` §1), and it wins
even when it carries ids or prefixes. Absent precedent, the default is
`<date>-<topic>.md` (e.g. `2026-08-16-auth-cutover-half-done.md`) — no ids,
no scope prefixes, no naming regex; the date sorts, the topic tells. Where
the chosen name carries no date, the header records the authored date —
resume needs it for §3's age and to rank candidates, and a gitignored file
has no history to recover it from.

**A name already taken is never reused.** Take the next free one: the repo's
own suffix precedent where there is one (a letter after the date: the next
letter unused on that date, `2026-11-09d-<topic>.md`), else `-2`, `-3` before
`.md`.

## Header — title and relations

When other handoffs exist in the repo, the header states this one's relation to
them in prose, not machinery:

- **COMPOSES WITH `<file>`** — the prior handoff remains in force; say what
  each carries so the reader knows to read both.
- **SUPERSEDES `<file>` (or named parts of it)** — the prior one is retired;
  say which parts and why they are done.

Eighteen hand-authored handoffs in this design's evidence base needed exactly
these two relations and nothing more. Forward/return chains, short-ids and
scope enums were designed, built, and never once missed after removal.

## 1. Orientation

What this handoff is for, and **the one thing to do first**. A resuming session
reads this before anything else — write it for a reader with zero context, not
for yourself tomorrow. If the work has a governing decision ("the freeze
holds", "the design is locked"), it belongs here, restated in one line even if
a reference holds the detail.

If this effort is mapped, §1 carries one line — *"this effort is mapped at
`<name+link>`; the frontier is a query, run it."* The handoff **points at the
map and never copies a decision out of it**: a handoff carries session state,
a map carries an effort's decision frontier, and a decision restated in both
drifts by construction.

## 2. State — as checkable claims

Where the work is, written so a fresh session can *verify* rather than trust.
Open with one line naming the directory the checks were run from: the repo
root, or the package root for a package-scoped handoff. The proven form is a
two-column table:

```
| Claim | How to check |
|---|---|
| canonical `main` at `7bf74f2` | `git log -1 --format='%h %s' origin/main` |
| suite ALL GREEN, 1,321 assertions | `bash tests/run-all.sh` |
| zero open PRs | `gh pr list --state open` |
| 3 tickets on the frontier of "multi-tenant billing" | run the frontier query at `${CLAUDE_PLUGIN_ROOT}/skills/wayfinder/references/tracker.md` §2 |
```

**The contract: every command tests the whole claim on its row.** A row whose
command checks half the claim reads as a full ✓ and hides the other half. The
frontier row applies that same contract, not a new one: a frontier **count**
typed into the table is stale the moment it is written — the frontier moves
every time a ticket resolves — so the row's command is the query itself, not
a recount, and a resuming session verifies the live frontier rather than
trusting a number this handoff happened to see.

Three rules earned by practice:

- **Measure at authoring time; never recall.** A number remembered from
  mid-session was measured at a different commit. One evidence-base handoff
  cited a lib total measured mid-branch in five records; it was stale by merge.
  Measure at the ref you cite.
- **A claim you could not verify is marked, not asserted.**
- **This section is what makes resume mode real.** Vague prose here leaves a
  fresh session nothing to re-verify, and the drift report becomes decorative.

## 3. Uncodified context

What is true but written nowhere else: decisions made in conversation,
approaches rejected and why, half-formed hypotheses, surprises, the pattern a
review kept finding. The entry test is §4's inverse: *does a file already hold
this?* If yes, it is a pointer in §4, not prose here.

A thin §3 on a genuinely trivial handoff is correct. Name subsections after
their lesson ("The walk-before-fix pattern paid twice"), not after artifacts —
the lesson survives the artifact.

## 4. References — pointers, not copies

Path plus a one-line "what's here", never pasted content. A receiving session
can dispatch a subagent straight at a pointer; it cannot un-bloat a transcript.
Point at the *authoritative* source (the spec, the ledger, the issue), not at a
summary of it.

## 5. Next actions, in sequence

Ordered and concrete, with what "done" looks like for each. Step 1 gets the
most detail — it is the step most likely to be executed exactly as written.
Advice about *how* to do a step (a skill to invoke, a discipline to apply)
belongs inline with that step.

## 6. Traps

What not to do, and assumptions now invalid. Carry forward any standing
constraint a resuming session could innocently violate (a freeze, a settled
decision, a command that destroys state). If a prior handoff's traps still
bite, say "everything in <file>'s §6 stands" and list only the new ones.
A trap that states a checkable fact also gets a §2 row.

## 7. Read-out (embedded)

The same read-out compose states in conversation is embedded as the final
section, fenced, so the document self-describes:

```
Handoff read-out — <topic>
  Location   <path>  (<why: precedent | docs tree | fallback>)  tracked: yes/no
  §2 State   <n> claims, each with a way to check it
  §3 Value   <one line: what is here that no file holds>
  §4 Refs    <n> pointers — nothing pasted that a path could carry
  §5 Order   <n> steps; step 1 is <x>
  Weakest    <the thinnest part, named honestly>
```

`Weakest` does the real work: v1 tried to guarantee quality by refusing to
write; v2 surfaces the weak spot and lets a human look at it.

## Two closing lines — after the read-out, the document's last lines

The read-out is the final *section*; these two lines follow its fenced block
as the document's last lines (they are part of §7, not a section of their
own — the evidence base's handoffs all end exactly this way):

- **"Self-verified before writing:"** — how §2 was measured (commands run at
  authoring time, at which ref).
- **"Stale by construction."** — the standing instruction to re-run §2 rather
  than trust any row. Every handoff is wrong eventually; this line makes that
  the reader's working assumption.

## Extension by project shape

Taught by example, never by enum: an active tracker adds *Open issues touched*;
a migration adds *Rollback state*; a research spike adds *Hypotheses tested and
rejected*; a chained effort adds a **starter prompt** — a separate, repointable
file naming which handoffs to read in what order, updated to point at the tail
(the evidence base kept one as `NEXT-SESSION-PROMPT.md`). Add what the project
needs; the six above stay.
