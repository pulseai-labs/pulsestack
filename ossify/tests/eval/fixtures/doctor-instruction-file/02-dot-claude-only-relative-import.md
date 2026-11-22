---
scenario_id: 02-dot-claude-only-relative-import
expected_outcome: repair-rename
expected_reason: "No `AGENTS.md` at the root; the only instruction file is `/home/bo/ws/.claude/CLAUDE.md` (2,140 B, names `ossify`), whose one import `@../docs/rules.md` resolves from `.claude/` to `/home/bo/ws/docs/rules.md`. `agents_md` fails (no `AGENTS.md`) and `claude_md` fails on the `.claude/` path, not the root. The operator says yes, so §5.3 branch 1 runs: the plan is shown, and the move is a `git mv /home/bo/ws/.claude/CLAUDE.md /home/bo/ws/AGENTS.md` because the source is tracked (`git ls-files --error-unmatch .claude/CLAUDE.md` succeeds) — not because the workspace is a git repo, which is what 06 shows the difference on. After that move the same relative import resolves from the ROOT as `/home/bo/docs/rules.md`, which does not exist — §5.1 shows the rewrite in the plan before the yes, and §5.5 step 1 applies it (`@docs/rules.md`) or reports it broken. Nothing is committed; the re-emitted lines are both `ok:`."
---

`.workspace/pairing.json` at the AI workspace root declares:

```json
{"schema_version":"1.0","ai_workspace":{"root":"/home/bo/ws"},"canonical":{"root":"/home/bo/repos/product-api"},"well_known_paths":{}}
```

Exactly one JSON object. `/home/bo/ws` and `/home/bo/repos/product-api` both
exist as real directories, and `git -C <root> rev-parse --is-inside-work-tree`
prints `true` for both. `/home/bo/ws` is a git repository with a clean work tree,
and `.claude/CLAUDE.md` below is tracked —
`git ls-files --error-unmatch .claude/CLAUDE.md` succeeds.

`$OSS_STATE_FILE` is unset. `oss state_path` resolves to
`/home/bo/ws/.ossify/project-state.json`, which exists and parses.

`/home/bo/ws` holds no `AGENTS.md` and no `CLAUDE.md` at its root — nothing
named `CLAUDE.md` outside the `.claude/` directory. It holds exactly one
instruction file, `/home/bo/ws/.claude/CLAUDE.md`: 2,140 bytes, naming `ossify`,
with exactly one import line, `@../docs/rules.md`, and no other `@` import and no
pointer line to another instruction file. Read from `.claude/`, `@../docs/rules.md`
means `/home/bo/ws/docs/rules.md`, which exists and is not empty. Read from the
root `/home/bo/ws`, the same string would mean `/home/bo/docs/rules.md`, which
does not exist and whose parent `/home/bo/docs` does not exist either.

Doctor's `/ossify:doctor interop` surface is invoked. After the read-out, the
operator answers the repair offer with an unconditional yes.
