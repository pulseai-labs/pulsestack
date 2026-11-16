# merge-bar

The pull-request lifecycle against a merge bar fixed when the PR opens.

A review loop with no finish line agreed in advance ends only when someone tires, and every
finding it cannot place becomes an issue. merge-bar writes the finish line into the PR body
before any reviewer speaks, and judges every finding against it.

## The merge bar

```
A finding blocks this PR only if it:
1. rejects valid input, or corrupts or loses state, on a path this PR touches;
2. makes the Claim above false;
3. breaks the test suite;
4. opens a security hole — injection, authentication bypass, or an exposed secret.
Everything else is non-blocking.
```

## Skills

| Skill | Command | What it does |
|---|---|---|
| `opening-a-pr` | `/merge-bar:open-pr` | Writes the seven-field body (Claim, Scope, Known limits, Merge danger, Merge bar, Evidence, Closes) and opens the PR |
| `working-a-pr` | `/merge-bar:work-pr <PR>` | Works the PR to mergeable against its own bar; merges a two-way door on your ack, or under a standing order in the project's memory bank or `AGENTS.md` that binds this role and grants merge authority; a one-way door goes to the merge holder |
| `reviewing-a-pr` | `/merge-bar:review-pr <PR>` | Reviews the PR as defect classes with every site, each sorted against its own bar, in two fresh-context axes (standards, and the Claim or spec); round 2+ reviews only the fix diff and each prior class's closure unless the bar or Claim changed. Reports only; the command has no `run` (a launcher invoking the skill may name a scratch directory with `run:` to run the suite there) |
| `running-a-retro` | `/merge-bar:retro [--last N \| --since <PR or date>] [--reports <dir>]` | Reads the project's review record over a window of merged PRs; proposes a coding-standards entry or a deterministic check for classes that repeat across two or more PRs, each citing its PRs, and reports the classes it does not propose. Writes only what you accept |
| `setting-up-reviewers` | `/merge-bar:setup-reviewers` | Once per repository: `AGENTS.md` review rules, and `.coderabbit.yaml` if public |

On Codex, invoke the skills by name.

## Install

```
/plugin install merge-bar@pulsestack
```

## The `mb` helper

`bin/mb` (bash and `jq`) does the fixed `gh` calls of a PR loop and prints facts; it never merges and
never approves. `mb threads <PR>` (unresolved threads, bot markup stripped), `mb checks <PR>`,
`mb rules`, `mb blockers <PR>`, `mb wait <PR> --head <sha> [--max-seconds N]` (bounded; exit 0 passed,
1 a check failed, 3 head moved, 4 no run appeared, 75 limit reached), `mb reply <thread> --body-file <f>`
and `mb resolve <thread>`. `mb help` names the plugin. Claude Code puts `bin/` on `PATH`; on Codex there
is no `bin/`, and `working-a-pr` falls back to plain `gh`.

## Known-limits ledger

After a merge, `working-a-pr` writes the PR's known limits as `[KL]` lines, and its one
out-of-scope issue as a `[TD]` line, to `tech-debt.md` in the paired AI workspace's routed
memory bank (`working-a-pr` §5). With no paired workspace it prints them and asks. It never
writes them into the reviewed repository. It also appends one line per merged PR to
`review-ledger.md` in that bank, found the same way and left uncommitted.
`running-a-retro` records each answered proposal in `retro-log.md` in the same bank,
so a later retro does not raise a rejected class again unless
a newer PR shows it. With no paired workspace there is no log.

## Tests

`bash merge-bar/run-tests.sh` runs the frontmatter lint, the fidelity and prose pins and the `mb` tests; CI runs it.
The behaviour evals in `tests/eval/` are session-driven and **not** run by CI — follow
`tests/eval/RUNBOOK.md` before any version bump.

## OMP

Install per the root README, including its `plugin-bin-path.ts` loader, which puts `mb` on `PATH` (`omp/bin-path.ts` is a byte-identical copy of the marketplace's). Skills are reachable as `skill://<name>`, with no `merge-bar:` prefix. No Claude Code-only parts.
