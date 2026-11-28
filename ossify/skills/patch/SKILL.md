---
name: patch
description: Use when handed issue numbers or a described defect to fix outside any spine, a small request from another project it cannot fake, or /ossify:patch — ship a versioned patch off the default branch, reproduce-first or AC-first, then PR and tag. Not new scope (intake queue), not a large request (/plan-spine), not a change nothing observes (close's direct-commit lane).
---

# patch

A running spine is never reopened. Work that arrives mid-release either waits in
the intake queue for the next spine planning, or — when it is a defect in
behaviour that already shipped, or a small request another project cannot fake —
ships here, as a patch release off the default branch. This skill decides whether
the work belongs here, fixes it by the procedure its kind needs, and lands it as a
versioned PR and a tag.

It writes no ossify state. The `fix/` branch, the PR and the tag are the record;
release close finds them in git (`close/references/release-close.md` §6).

---

## 1. Is this a patch? Refuse the wrong lane, loudly, with the route

Read the input — issue numbers (`gh issue view <n> --repo "<owner/repo>" --json number,title,body,labels,url`)
or the described defect — and place it in exactly one lane. An issue number belongs
to the repo the fix goes into, so pass that repo explicitly: a bare `gh issue view`
resolves against whatever checkout this session is in, which may be the AI
workspace or another project. If the invocation does not say which repo, ask.
Every later `gh` call on the issue (§3's AC comment, §6's adoption comment) uses
the same `--repo`. `<owner/repo>` is the repository the call targets, read from its own checkout: `gh repo view "$(git -C "<repo-root>" remote get-url origin)" --json nameWithOwner -q .nameWithOwner`. `<repo-root>` is that repository's checkout, not the directory you are in: a PR lives in the canonical even when you run from the AI workspace. On an ossify project, `oss repo_root canonical` (or `ai_workspace`) gives it. Never build the name from a folder name: an AI workspace's folder and its GitHub repo often differ.

| The work | Lane |
|---|---|
| A **defect in shipped behaviour** — a released version does something its docs, its tests or its users rely on it not doing | **here** — §3's defect arm |
| A **small request from another project that it cannot fake** — one work item's worth, the yardstick `plan-spine` §4 uses, and no admissible glue on the requester's side (`plan-spine/references/fake-ledger-discipline.md` §1) | **here** — §3's request arm |
| A **large** can't-fake request — more than one work item | **refuse** → plan a spine for it now: `/ossify:plan-release` first (amend the open release, or plan one), which creates the spine, then `/ossify:plan-spine` on that spine's id |
| A request the requester **can** fake, or **new scope** with no defect behind it | **refuse** → the intake queue, an issue labelled `from:<requesting project>` (`plan-spine/references/intake-and-ledger.md` §1). The project's own idea, with no requester, goes on the feature map at the next `/ossify:plan-release` |
| A change **nothing observes** — a typo, a comment, a formatter run | **refuse** → close's direct-commit patch lane (`close/references/patch-lane.md`); it needs no version |

A refusal names the lane and stops: no branch, no commit, no version. **Never** add
the work to a running spine — not as a work item, not as an AC — whatever its size
or urgency.

"Small" is judgment, and doubt resolves against this lane: if you cannot say in
one line which single work item the patch would have been, it is a spine.

## 2. Read what the patch will touch

Name the repo the fix goes into and the paths it will touch. Then:

- **The ledger.** Read the tech-debt ledger lines overlapping those paths and give
  each a disposition (`plan-spine/references/intake-and-ledger.md` §2). A line
  this patch resolves is pulled in as one of its ACs.
- **Bones and risk gates**, on an ossify project — a topology resolves; call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next. Run
  `oss touch_check` with the paths, one argument per path: rc 0 is a hit
  (stdout names it), rc 1 is clean, rc 2 could not check and is never clean. A
  `risk_gate` hit makes that gate's controls (`oss get '.risk_gates'`)
  required ACs of this patch. A `bone` hit is allowed only when the fix keeps the
  decision the bone's ADR records; a fix that changes that decision is a spine —
  refuse it as §1's large arm. On rc 2, say so and ask the operator before going on.

These are the paths you expect to touch. Before §5 opens the PR, take the paths the
fix actually changed (`git diff --no-renames --name-only "origin/<default-branch>...HEAD"`,
so a renamed file lists its old path as well as its new one),
re-read the ledger lines overlapping the changed paths, and run `touch_check` on them
again on an ossify project. Treat a new line or a new hit exactly as above.

## 3. Fix it — by kind

**Check before you write.** Check every precondition before the first write: each file you edit exists and each text you replace is there exactly once; each file you create does not exist yet. Give every check a message that names what failed. A script that asserts after it writes leaves the edit half-applied.

**Cut the branch first (§4), and do all of this section inside it.** When the
repo's checkout is parked on a spine or work-item branch, that means the separate
worktree §4 creates — the reproduction and the fix are never written into a
checkout a running spine owns, and never tested against its unshipped code.

**Defect.** Reproduce first. Write the failing test — or, where no test can reach
it, record the failing command and its output — and run it to watch it fail for
the reported reason. Then find the root cause with the loop in
`work-item/references/debugging.md` §2: reliable red, minimize, hypothesize,
instrument. Fix at the root, not at the symptom. Prove it: the reproduction now
passes, it fails again with the fix reverted, and the full suite is green.

**Small request.** Write the acceptance criteria from the requester's issue first —
each one a checkable statement, keeping the requester's words where they are
precise — and post them on the issue so the requester can object before the work
lands. Then build them test-first, one AC at a time: the discipline in
`work-item/references/tdd-loop.md`, without a spine handoff document. Finish on
the full suite green.

Either way, keep a record of every command you ran and what it showed. The PR's
Evidence is built from that record and nothing else.

## 4. Branch and version

Cut `fix/<plugin-or-project>-<version>`, where `<version>` is the patch version
this will ship as, from the **freshly fetched** default branch, in a **clean**
checkout. If the repo's checkout is parked on a spine or work-item branch, or is
dirty, do not switch it or stash it — a running spine owns it. Cut the branch in
a separate worktree. This lane, like merge-bar, expects the repo's remote to be
named `origin` and to be on GitHub, because §5's PR and §6's tag go through `gh`.
If `git -C "<repo-root>" remote` lists no `origin`, or
`gh repo view "$(git -C "<repo-root>" remote get-url origin)" --json url`
does not resolve it, say so and stop before cutting anything. Push URLs can
differ from the fetch URL, so run the same `gh repo view` on every URL
`git -C "<repo-root>" remote get-url --push --all origin` prints, and stop the same
way unless each resolves to the same `url` as the fetch URL, host included. The remedy is the
operator's: add or rename the remote, or land the fix by hand outside this lane.

```bash
git -C "<repo-root>" fetch origin "<default-branch>"
git -C "<repo-root>" worktree add -b "fix/<plugin-or-project>-<version>" "<new-worktree-path>" "origin/<default-branch>"
```

Bump the **patch** version on every surface the project carries it. Find them with
`git grep -n -F "<current version>"`, read each hit, and bump the ones that
declare this project's version: manifests, lockfile entries for the project
itself, changelogs, READMEs. If the project's releases carry no patch version,
ask the operator how this one is numbered; do not invent a scheme.

Commit following the repository's own rules for commit text (its `CLAUDE.md`,
`AGENTS.md` or `CONTRIBUTING.md`).

## 5. Open and work the PR

**Where the `merge-bar` plugin is installed** — this session lists its
`opening-a-pr` and `working-a-pr` skills — open the PR with `opening-a-pr` and
work it with `working-a-pr` (on Claude Code, `/merge-bar:open-pr` and
`/merge-bar:work-pr`; Codex publishes the skills, not the commands). Run both from
the patch worktree, `<new-worktree-path>` — they read the current directory's
branch and `HEAD`, so never from a checkout a spine is parked on.

**Otherwise**, write the seven-field body from ossify's copy of that template,
`../work-pr/references/pr-body.md`: its headings in order, and
its Merge bar block word for word. Push the branch first —
`git -C "<new-worktree-path>" push -u origin "fix/<plugin-or-project>-<version>"` —
because `gh pr create --head` does no pushing of its own. Then open it:

```bash
gh pr create --repo "<owner/repo>" --base "<default-branch>" --head "fix/<plugin-or-project>-<version>" --title "<title>" --body-file "<body-file>"
```

Then work it by `../work-pr/references/loop.md` (on Claude Code,
`/ossify:work-pr <PR>` routes there).

Either way, re-run §2's changed-path re-check after each review-fix round, and
once more before the merge ask: a fix round can touch a path the first re-check
never saw. Treat a new ledger line or a new hit exactly as §2 says.

Either way, the body carries one `Closes #<n>` line per issue this patch
resolves, one per line: GitHub closes only the first issue of `Closes #1, #2`.
**The merge is the operator's, or a standing order's in the project's memory bank or `AGENTS.md` that binds this role and grants merge authority (lookup: `close/references/cumulative-demo.md` §3).**
Where `working-a-pr` runs, a patch is a one-way door (§6 tags it), so it goes to the merge holder
(the orchestrator where one runs, otherwise the operator) with `merge-bar/skills/working-a-pr/references/one-way-door.md`.

## 6. Tag after the merge

After the merge, confirm the merge commit's tree carries the new
version, then tag that commit the way the project tags its releases. Read
`git -C "<repo-root>" tag --sort=-creatordate` for the convention (annotated or
not, the prefix, the version form) and follow it:

```bash
git -C "<repo-root>" fetch origin "<default-branch>"
git -C "<repo-root>" tag -a "<tag>" -F "<tag-message-file>" "<merge-commit>"
git -C "<repo-root>" push origin "<tag>"
```

Report the tag, the PR URL and the issues it closed. On each issue another
project filed, comment with the version that carries the fix so the requester can
adopt it.

## 7. Anti-patterns

- **Adding the work to a running spine** because it is small or urgent (§1).
- **Fixing a defect you have not reproduced.** A fix with no failing
  reproduction proves nothing (§3).
- **Writing code before the ACs** on a request (§3).
- **Switching or stashing a checkout a spine is parked on** to cut the branch (§4).
- **Reading `touch_check` rc 2 as clean**, or a `risk_gate` hit as advisory (§2).
- **Bumping one manifest** and leaving the old version on another surface (§4).
- **Merging on the operator's behalf** — a merge with neither the operator's ack
  nor a standing order in the project's memory bank or `AGENTS.md` that binds this role and grants merge authority, or, under
  `working-a-pr`, by anyone but the merge holder — or tagging before the
  merge (§5, §6).
- **Recording the patch in ossify state.** Git is the record (top of this file).

## 8. Slash-command interaction

`/ossify:patch` (`commands/patch.md`) renders the raw argument text inline after
`Invoke the patch skill with:`; there is no shell shim. On Codex, a direct skill
invocation (`Skill()`), or a natural-language request, read the literal tokens
from the invocation or request. **Never write a dollar-digit positional.** With no
argument, ask which issues or which defect; never pick one.
