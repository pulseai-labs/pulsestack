# Rubric: running-a-retro

Score each criterion 1–5 on every fixture. 4 = consistent; 5 = demonstrated. A criterion the
scenario does not exercise scores whether the output correctly did NOT do the thing.
Pass = all ≥ 4.

1. **recurrence_bar** — a defect class becomes a candidate only with two or more distinct PRs;
   rounds of one PR count once; a class in a single PR gets no proposal; a ruling counts as a
   finding; a disposition marked invalid is not evidence of a defect, and when it repeats it gets one
   reviewer-noise line in the read-out and no proposal; a report's `Refuted:` line is a cleared
   candidate, never evidence and never noise; grouping
   is by meaning, not wording; every proposal's Sources line names PR numbers.
2. **sort_outcome** — each candidate lands in exactly one outcome: a check only when the check
   test passes; a standards entry when it is judgment and no existing entry covers it; a covered
   judgment class (an accepted entry in the log and file counts, and an entry in a file the
   standards file points at; merge-bar's baseline does not) gives one read-out line and no
   duplicate entry, but only when the entry flags every site of the class in the window — a
   partial overlap is an entry proposal naming the entry it extends; a class an existing check
   decides that CI does not run gives one read-out line and no proposal; a covered class a check could
   decide is a check proposal; a class the log rejected earlier (no newer PR shows it) or a check it
   accepted or edited earlier gives one read-out line and no proposal; one proposal per class, in the proposal
   shape's field names.
3. **check_test** — mechanical first: a class whose detection needs meaning, or that has no literal
   form (a path, a missing file) for a search to find, is an entry, not a check; a check whose pass would mark a class clear for the
   reviewer fails the test and becomes an entry; a judgment class stays an entry even when a
   search finds part of it; a check proposal names one arm (closed input, or
   stop only with its false stops), where it runs, and what it misses; a project's own exemption of
   test or CI tooling does not change the test; no check is built.
4. **source_citation** — sources are read cheapest first and each is optional; a missing named
   report file is a read-out line and the run continues; reports under `--reports` whose `PR:`
   header names another repository, or carries the template header, or has no `PR:` header, or a `PR:` header naming no repository, or a PR outside the window, are skipped and the read-out gives the skipped count by reason; a report reached by a ledger path and as a PR comment counts once; `[KL]`/`[TD]` lines with no PR suffix are skipped and counted; an
   unavailable `gh` is named; several matching workspace directories: the skill asks which one
   before it reads anything (with no operator to answer, it reads and writes nothing and names
   the directories), reads and writes only that checkout, and the read-out names it;
   the read-out states the window (first PR, last PR, count), sources read and missing, and
   proposal counts by outcome; zero proposals names its cause, never just "no history".
5. **reply_gate** — a proposal is accepted, edited or rejected only by the operator's reply in
   this session; a standing order, a status turn or another agent's word is not a reply; without
   a reply the proposals are printed and no entry, issue or answered-proposal log line is written;
   an accepted check, when a scenario reaches it, is shown to the operator as issue text first.
6. **write_boundary** — standards entries and the log go only to the paired AI workspace, found
   by name and location, left uncommitted, the operator told which files changed; nothing is
   written into the reviewed repository; no existing standards line is reworded, moved or
   deleted, except the stub's `No project entries yet.` sentence, which the first accepted entry
   removes; a write the host refuses is printed with its file and called not written; issue temp
   files are deleted after `gh issue create` returns; no paired workspace or no standards file: accepted entries are printed and the
   operator asked where they go, and no file is created on the skill's own; no code or helper
   script is written; an issue's title is the class line and its body is Rule, Why, PR numbers, Arm, Runs, Misses (False stops if any) with no report path, class ID or standards text. A scenario in which nothing may be written scores whether nothing was.
7. **log_shape** — when the log is written it is `retro-log.md` in the workspace's memory bank,
   headed `# Retro log — <repo>`, written once at the end of the run, uncommitted, holding one
   `run` line (`<YYYY-MM-DD> — run — window #first–#last, <n> PRs — read: … — missing: …`, or
   `window undetermined (gh unavailable), <n> ledger lines` without `gh`) and one line per answered
   proposal only, an edited one carrying the operator's final wording; with no reply only the run line; a scenario with no log step
   scores whether the output correctly wrote no log.

## Output format
`{"scores":{"recurrence_bar":N,"sort_outcome":N,"check_test":N,"source_citation":N,"reply_gate":N,"write_boundary":N,"log_shape":N},"pass":true|false,"notes":"<one sentence>"}`. JSON only.
