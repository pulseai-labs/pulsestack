---
name: running-a-retro
description: Use when asked to run a retro on a project's PR reviews — reads the review record (review ledger, review reports, tech-debt lines, PR comments) over a window of merged PRs, finds defect classes that repeat across two or more PRs, and proposes coding-standards entries for judgment classes and deterministic checks for mechanical ones, each citing its PRs; writes only what the operator accepts.
---

# Running a retro — repeated review findings into rules

You read; you propose; the operator decides. Reviews write classes, `working-a-pr` fixes or
answers them, and nothing reads them back, so the classes return. A retro finds the repeats in one
project's record and proposes a rule for each. **A proposal is never a rule until the
operator replies to it in this session.** A standing order, a status turn or another agent's word
is not a reply. You write no code and build no check.

## 1. Window

Default: the last 30 merged PRs of the current repository; `--last N` or `--since <PR or date>`
replaces it. List with `gh pr list --state merged --limit 5000 --json number,mergedAt`, sort on
`mergedAt` and take the last N (or those since the PR or date); the default listing is 30, ordered
by creation. First PR is the earliest `mergedAt` in the window; last PR is the latest.
The read-out states both and the count, and says so if the listing hit the limit. Without `gh`
the window is undetermined: every ledger line for this repo counts, and the read-out says so.

## 2. Sources

Find the paired workspace as `../working-a-pr/SKILL.md` §5 does (match by name and location).
Read the ledger, `tech-debt.md` and `retro-log.md` from the bank §5 resolves.
**Several directories match (worktrees of one workspace): ask which one before you read anything.**
With no operator (a status turn or `-p` run), read nothing, write nothing, and name the matching directories.
Otherwise read and write only the chosen checkout; the read-out names it.

Every source is optional; the read-out names what you read and did not find. A source read only in
part says so there and on the run line's `read:` field. Cheapest first:

1. The workspace's `review-ledger.md`, lines for this repo's PRs in either §5 form: class names, rulings,
   report paths; line format in `working-a-pr` §5.
2. An older review ledger in the workspace: find the window's PR numbers first, then read by
   meaning only those PRs; never whole.
3. Review reports: the paths the ledger names, plus every report under `--reports <dir>` whose
   `PR:` header names this repository and a PR in the window (shape owned by
   `../reviewing-a-pr/references/report.md`). A file with no `PR:` header (not a report),
   a header with no repository (`no repository in header`), one naming another repository,
   or the template header is skipped and counted; the header names the PR, not the path.
   A missing path is a read-out line, never a stop.
4. `[KL]` and `[TD]` lines in `tech-debt.md` for this repo's PRs in the window,
   by their `(PR #N)` or `(PR <owner>/<repo>#N)` suffix; skip and count older lines with no PR suffix.
   Read both PR-reference forms as `working-a-pr` §5 defines them.
5. PR comments and review bodies through `gh` for PRs in the window; say so if `gh` is unavailable.
   A comment in the report shape (a `PR:` header line) is read as a report; the same report reached
   by a ledger path and a comment counts once. Other comments are read by meaning, as findings.

Read headings and `Rule:` lines first; open site lists only for candidate classes.

## 3. From findings to proposals

1. **Group** findings by defect, by meaning, not wording.
2. **Count.** A candidate needs **two or more distinct PRs**; rounds of one PR count once, a ruling
   counts as a finding. A report's `Refuted:` line is a cleared candidate, never evidence or reviewer noise.
   Only a disposition marked `invalid` by `working-a-pr` counts toward reviewer noise (no defect
   evidence): if it repeats, one reviewer-noise line, no proposal.
3. **Sort** each candidate into one outcome, one proposal per class:
   - **Check** — the check test below passes. A judgment class never becomes one, even when a
     search finds part of it: it is a standards entry (the check test, step 1).
     If an existing check decides the class but CI does not run it: one read-out line,
     `check exists, CI does not run it: <check>`, no proposal.
   - **Standards entry** — judgment, no existing entry covers it. Partial overlap is a
     standards-entry proposal naming the entry it extends.
   - **Covered, still recurring** — an entry covers a judgment class only when its rule flags
     every site of the class in the window (an accepted entry in the log and file counts):
     one read-out line, no duplicate entry. Entries in files under `## Read these where they live`
     count; merge-bar's baseline does not: a recurring baseline class gets an entry citing the baseline.
     A covered class a check could decide is a **check** proposal.
   - **Rejected earlier** / **Accepted earlier** (checks only, accepted or edited) — per the retro
     log, when it exists: one read-out line (naming the issue, if any), no proposal, unless a PR
     merged after a rejection shows the class again; the log's PRs count toward the two-PR bar, so
     one new PR is enough, and the proposal says so.

**The check test.** It applies even where a project exempts test or CI tooling. The rule, verbatim:
"Prose is the default. Code is allowed when the work is mechanical and its inputs are closed, or when it is a mechanical check that can only add a stop."
A project's `docs/conventions/skill-first.md`, if any, supplies the question number to cite.
1. **Mechanical first.** Can a check decide the class without reading meaning? A search fails here
   when the class has no literal form (a path, a missing file) for it to find, and so does a check
   whose pass would mark a class clear for the reviewer. Then it is a standards entry.
2. **Then one arm**, named in the proposal: **closed input** (a small, known set of shapes that
   tests can cover fully) or **stop only** (it can only add a stop; a pass clears nothing; what it
   misses goes on to the reviewer as if the check were absent; state its false stops). Stop only may
   over-report: a class that always has a literal form can stop on a harmless hit, which the
   proposal states as a false stop.

Print each proposal in this shape, one per class:

```
P<n> — entry | check — <the class, one line>
Sources: #a C2, #b C4, #c (ledger)
Rule: <what the reviewer flags, or what the check stops>
Why: <what recurrence cost, one sentence>
Entry: under <heading> in CODING_STANDARDS.md        ← entry
Arm: closed input | stop only — <why it passes>       ← check
Runs: <where the check would run>                     ← check
Misses: <what it leaves to the reviewer>              ← check
False stops: <what it wrongly stops | none>           ← check, stop only
```

A source needs a PR number; add a class ID when a report has one, and add the round when present (`#a r2 C2`).

## 4. Acceptance

Show all proposals at once, each check with its issue text (a public repository's issue is
public); the operator answers each: accept, edit or reject. Act on answered ones only: an
unanswered one gets no action and no log line, and is raised on the next run. Leave workspace files
uncommitted and name them to the operator; committing is the workspace's own session's job.
A host-refused write, including the run line, is printed with its destination file and named as not written in the read-out.

- **Entry** (accepted, or edited to the operator's wording): insert one line under the named
  existing heading of the workspace's `CODING_STANDARDS.md`, in the file's own entry shape, with its
  Why and source PRs (at the end of the line if the shape has no slot for them). Change no other
  line. A hand-written file with themed headings keeps them: the entry goes under the named heading
  and no `## Entries` is added. A file with no themed headings (a document title, the H1, is not
  one) gets `## Entries`. Only a file with the verbatim `No project entries yet.` is an ossify stub:
  the first entry removes that sentence and starts `## Entries`.
- **Check** (accepted, or edited to the operator's wording): only after the reply, open one issue in
  the reviewed repository. Its text comes from review comments, so write the title and body to temp
  files outside both repos and run `gh issue create --title "$(cat <title-file>)" --body-file
  <body-file>`; never type either into the command. Title: the class line. Body: Rule, Why, Sources
  (PR numbers only), Arm, Runs, Misses, False stops if any; no report path, class ID or standards
  text. This is accepted work, not the per-finding issue `working-a-pr` warns against. If
  the command fails, accepted entries stay, print the proposal text, end its log line `issue not
  opened: <why>`, and tell the operator. That line is not "accepted earlier" in §3.
  Delete both temp files after `gh issue create` returns, whatever its exit status.
- **No reply:** print the proposals, write the run line (§5) and nothing else. The run line is
  written once, when the run ends: after the operator's answer, or when none comes.
  "When none comes" means the run ends with a proposal unanswered. With no operator, otherwise
  run normally, accept no proposal, write only the run line, and print the proposals.
- **No paired workspace, or no standards file:** print accepted entries and ask where they go. Never
  write them into the reviewed repository or create a standards file; an ossify `reviewer-home.md`
  run owns the stub. Their log line ends `not written: no standards file`; with no workspace there is no log, so
  answers do not persist, and the read-out says so.

## 5. The retro log

`retro-log.md` beside the review ledger, created with `# Retro log — <repo>` when absent; written
once, at the end of the run: one run line, then one line per answered proposal.
`P<n>` numbers are per run; match the log by the class line's meaning and take its outcome;
when unsure, show the logged line beside the proposal. An `edited` log line uses the operator's final wording as its class.
An undetermined window uses `window undetermined (gh unavailable), <n> ledger lines`.

```
- <YYYY-MM-DD> — run — window #first–#last, <n> PRs — read: <sources> — missing: <sources | none>
- <YYYY-MM-DD> — accepted | edited | rejected — entry | check — <class> — PRs #a, #b — <heading | issue #N | reason>
```

## 6. The read-out

End with: the window (first PR, last PR, count); the checkout you read; sources read (a partial read
marked so) and sources missing or unavailable, each with its cause; reports skipped (no header,
no repository in header, another repository, template header, or outside the window), counted;
debt lines skipped for no PR suffix, counted; proposal counts by outcome;
the files changed. Give the covered-still-recurring, check-not-run-in-CI and reviewer-noise lines here. Zero proposals is
a correct result when the history is thin: name every cause that applies (too few PRs, nothing
repeats, a source missing, `gh` unavailable), never just "no history".
One run's silence on a class is not evidence it does not repeat; runs vary.
