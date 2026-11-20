---
scenario_id: 06-untracked-dot-claude-git
expected_outcome: repair-rename
expected_reason: "No `AGENTS.md` anywhere; the only instruction file is `/home/dev/dv/ws/.claude/CLAUDE.md` (2,650 B, names `ossify`), and it is NOT tracked by git — `.claude/` is ignored in this workspace — although the workspace itself IS a clean git repository. `agents_md` fails (no `AGENTS.md`) and `claude_md` fails on the `.claude/` path, not the root. The operator says yes. §5.3 branch 1 decides the move by whether the SOURCE IS TRACKED, not by whether the workspace is a git repo: `git ls-files --error-unmatch .claude/CLAUDE.md` fails, so the move is a plain `mv`, not the `git mv` that would abort with \"not under version control\". The move is shown before the yes. The file carries one import `@../docs/rules.md`, which after the move to the root resolves as `/home/dev/dv/docs/rules.md` and does not exist — §5.1 shows that as an import that cannot be kept, and §5.5 applies the rewrite the operator approved (or reports it broken). Nothing is committed; the re-emitted lines are both `ok:`."
---

`.workspace/pairing.json` at the AI workspace root declares:

```json
{"schema_version":"1.0","ai_workspace":{"root":"/home/dev/dv/ws"},"canonical":{"root":"/home/dev/repos/product-api"},"well_known_paths":{}}
```

Exactly one JSON object. `/home/dev/dv/ws` and `/home/dev/repos/product-api` both
exist as real directories, and `git -C <root> rev-parse --is-inside-work-tree`
prints `true` for both. `/home/dev/dv/ws` is a clean git work tree with no staged
or unstaged changes — and it ignores `.claude/`, so nothing under `.claude/` is
tracked. `git ls-files --error-unmatch .claude/CLAUDE.md` exits non-zero;
`git ls-files --error-unmatch .claude` exits non-zero too.

`$OSS_STATE_FILE` is unset. `oss state_path` resolves to
`/home/dev/dv/ws/.ossify/project-state.json`, which exists and parses.

`/home/dev/dv/ws` holds no `AGENTS.md` and no `CLAUDE.md` at its root — nothing
named `CLAUDE.md` outside the `.claude/` directory. It holds exactly one
instruction file, `/home/dev/dv/ws/.claude/CLAUDE.md`: 2,650 bytes, naming
`ossify`, with exactly one import line, `@../docs/rules.md`, and no pointer line
to another instruction file. Read from `.claude/`, `@../docs/rules.md` means
`/home/dev/dv/ws/docs/rules.md`, which exists and is not empty. Read from the
root `/home/dev/dv/ws`, the same string would mean `/home/dev/dv/docs/rules.md`,
which does not exist and whose parent `/home/dev/dv/docs` does not exist either.

Doctor's `/ossify:doctor interop` surface is invoked. After the read-out, the
operator answers the repair offer with an unconditional yes: "yes, move it".

The operator approves the rewrite of `@../docs/rules.md` to `@docs/rules.md` that
the plan shows for the root location.
