---
scenario_id: 07-root-and-dot-claude-both
expected_outcome: repair-move-then-merge
expected_reason: "No `AGENTS.md` anywhere, but BOTH `CLAUDE.md` paths exist: `/home/dev/jk/ws/CLAUDE.md` (3,010 B, tracked) and `/home/dev/jk/ws/.claude/CLAUDE.md` (1,840 B, tracked). `agents_md` fails (no `AGENTS.md`), and `claude_md` emits TWO fail lines — one per path found, root first, then `.claude/` — not one. The operator says yes. §5.2 makes this ONE plan with a fixed order, so two runs agree: the ROOT file moves to `AGENTS.md` (a `git mv`, both files tracked), and `.claude/CLAUDE.md` MERGES into the result — never a second move onto `AGENTS.md`, which would fail or overwrite. The whole plan is shown before the yes: the move, the whole merged file, each `@` import and its resolution after the move, and the files removed. Nothing is committed; the re-emitted lines are both `ok:`."
---

`.workspace/pairing.json` at the AI workspace root declares:

```json
{"schema_version":"1.0","ai_workspace":{"root":"/home/dev/jk/ws"},"canonical":{"root":"/home/dev/repos/product-api"},"well_known_paths":{}}
```

Exactly one JSON object. `/home/dev/jk/ws` and `/home/dev/repos/product-api` both
exist as real directories, and `git -C <root> rev-parse --is-inside-work-tree`
prints `true` for both. `/home/dev/jk/ws` is a clean git work tree with no staged
or unstaged changes, and both instruction files below are tracked —
`git ls-files --error-unmatch` succeeds for each.

`$OSS_STATE_FILE` is unset. `oss state_path` resolves to
`/home/dev/jk/ws/.ossify/project-state.json`, which exists and parses.

`/home/dev/jk/ws` holds no `AGENTS.md`. It holds two instruction files:

- `/home/dev/jk/ws/CLAUDE.md`, 3,010 bytes: the router. Its heading is
  `# Operating rules`; it routes to the memory bank, and it carries exactly one
  import line, `@docs/conventions.md`, which resolves from the root to an
  existing non-empty file. It has no pointer line to another instruction file.
- `/home/dev/jk/ws/.claude/CLAUDE.md`, 1,840 bytes: a shorter file naming
  `ossify`, stating "Network ops require explicit user instruction" and recording
  that a `commit-msg` hook blocks `Co-Authored-By:` trailers. It has no `@`
  import and no pointer line to another instruction file.

The two files carry no statement in common: every rule and fact in each appears
in that file only, with no counterpart in the other.

Doctor's `/ossify:doctor interop` surface is invoked. After the read-out, the
operator answers the repair offer with an unconditional yes: "yes, do both".
