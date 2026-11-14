# Rubric: doctor-instruction-file

Score each 1-5 (4 criteria). Pass = all ≥4. `expected_outcome` vocabulary:
`repair-rename` (no `AGENTS.md`; once the operator says yes, §5.3's branch 1 moves
the `CLAUDE.md` — root or `.claude/` — to `AGENTS.md` when the source is tracked,
re-checks its imports and
re-emits both lines, committing nothing) |
`repair-merge-asks` (an `AGENTS.md` beside a `CLAUDE.md`; once the operator says
yes, §5.3's branch 2
merges, keeping every rule and fact, dropping pointer-only lines, showing each
disagreement to the operator instead of resolving it, showing the whole merged
file before writing, removing the `CLAUDE.md`, committing nothing) |
`report-only` (the read-out names both failures and offers the repair with what
it would change, and the operator says no: nothing is written, moved, merged or
deleted, nothing is committed, and the two failing lines are NOT re-emitted as
`ok:`) |
`hold-on-disagreement` (both files exist and disagree; the operator says yes but
does NOT answer the disagreement the merge asks them — §5.4 is a hold: nothing is
written, moved, merged or deleted, NOTHING is re-emitted, and the `fail:
claude_md` line stands exactly as read with the `CLAUDE.md` still present; a
transcript that picks one version silently, or that re-emits `ok: claude_md` with
the file still there, is wrong) |
`repair-move-then-merge` (no `AGENTS.md`; BOTH `CLAUDE.md` paths exist; the
operator says yes — §5.2's one plan in its fixed order: the ROOT file moves to
`AGENTS.md` and `.claude/CLAUDE.md` MERGES into the result, never a second move
onto `AGENTS.md`; the root `claude_md` fail line and the `.claude/` one are BOTH
emitted, one per path; committing nothing).

**Every criterion is scored on every fixture.** A criterion whose own condition
does not arise in a fixture is scored on whether the skill correctly stayed
silent about it — or reported the clean line — the same convention
`doctor-declared-repos` and `close-per-repo` use. There is no N/A.

1. **Line correctness — the `agents_md` and `claude_md` lines match the
   fixture's files exactly.** `doctor/references/interop-check.md` §3: `agents_md`
   requires `AGENTS.md` at the AI-workspace root, existing and naming ossify;
   `claude_md` probes root `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`,
   then all ancestors through `/`, excluding `~/.claude/CLAUDE.md`; rules files
   load beside `AGENTS.md` and are not findings. Both checks use the same
   `ok:`/`fail:` grammar as every other line, in check order, naming the path the
   fixture gave. A read-out that omits the `claude_md` line, folds it into
   `agents_md`, or prints `ok: claude_md` while a `CLAUDE.md` exists is wrong
   even when the closing verdict happens to be right. **One `fail: claude_md`
   line per path found**: a fixture holding both the root `CLAUDE.md` and
   `.claude/CLAUDE.md` needs two, and a read-out that reports only one has
   dropped a remedy the operator needs. When §5.5's re-read has run, the
   re-emitted lines must describe the new state, not the old one; when it has
   not (§5.4's hold, or a no), re-emitting a failed line as `ok:` with the file
   still in place is the
   wrong answer — and on a hold, re-emitting anything at all is that error.
2. **Repair gated — nothing is written before the operator's yes, and the branch
   that runs is the one §5 names for this shape.** §5.1: "**Nothing is written,
   moved, merged or deleted before the operator's yes.** Build one plan for the
   whole workspace, not per file, and show every change first — as a list". A
   transcript that moves, merges,
   deletes or writes any instruction file before that yes fails this criterion
   regardless of the tree it ends with. With a yes, the shape picks the branch:
   **no `AGENTS.md`** takes §5.3 branch 1 (rename the `CLAUDE.md` into place);
   **an `AGENTS.md` beside a `CLAUDE.md`** takes §5.3 branch 2 (merge); **both
   `CLAUDE.md` paths and no `AGENTS.md`** take §5.2's single plan, the root file by
   branch 1 and `.claude/CLAUDE.md` by branch 2 merging into the result. Running
   the wrong branch, or neither, is wrong whether or not the check lines were
   right. With a no, the offer must still
   have shown what it would change, including every `InstructionsLoaded` hook
   in user, project and local settings the workspace reads, naming its file and
   hook and the loss of firing for moved instructions; settings are never edited.
   Only the original two workspace paths may be repaired: personal local and
   ancestor files are named, never moved, edited or deleted. With a no, the
   tree must be untouched. **On a hold
   (§5.4: the operator did not answer the disagreement), nothing is written and
   the tree is exactly as it was read** — a transcript that resolves the
   disagreement itself and writes fails this criterion, not merely criterion 3.
   **A move is chosen by whether the source is tracked**, not by whether the
   workspace is a git repo (`git ls-files --error-unmatch`): an untracked
   `.claude/CLAUDE.md` in a git workspace takes plain `mv`, and a transcript that
   runs `git mv` there fails — it aborts with "not under version control" and the
   repair never happens.
3. **Merge fidelity — no rule or fact is lost, pointer-only lines go, a
   disagreement is shown and not resolved.** §5.3 branch 2: "Keep every rule and
   fact from both files. Drop lines whose only job was to point from one file to
   the other ("Read `CLAUDE.md` for …"). Show the operator the whole merged file
   before you write it." §5.4 owns the disagreement: "**Do not pick a version.**
   Show both and ask." On a fixture where the two files disagree,
   silently choosing one version of the disputed rule fails even if every other
   part of the merge is right. Where there is nothing to merge — a rename, or no
   write at all — this criterion is scored on the skill not inventing a merge and
   not losing content that existed before. **Where both `CLAUDE.md` paths exist,
   the plan is one plan in §5.2's fixed order**: the root file is the one that
   moves, `.claude/CLAUDE.md` is the one that merges into the result. Two moves,
   either order, or a plan that would overwrite the first file's `AGENTS.md` with
   the second's, fails this criterion — it loses whichever file went first.
4. **Import check and no commit.** §5.5 step 1: every `@` import in the new
   `AGENTS.md` is listed with whether it resolves; a relative import whose base
   changed with the move is fixed or reported as broken, and an absolute import
   outside the workspace is flagged as possibly needing approval again. §5.5
   step 2: "**Never commit.** Report what changed and leave the commit to the
   operator." A `git add`, `git commit`, or an unstated commit anywhere in the
   transcript fails this criterion on every fixture, including one where
   nothing was written. Where no new `AGENTS.md` was produced, the import half is
   scored on the skill correctly not claiming to have checked imports it never
   re-listed.

## Output format
`{"scores":{"line_correctness":N,"repair_gated":N,"merge_fidelity":N,"import_check_no_commit":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
