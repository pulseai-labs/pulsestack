---
description: Execute one ossify work item from its handoff doc (pre-flight gates, RED gate, TDD per AC, verification, ten-section report, stage-never-commit, structured JSON return)
argument-hint: "<absolute-handoff-path>"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep, Skill
---

Parse args from `$ARGUMENTS` via a trailing argument (no positional `$1`/`$2`/`$N`),
then load the `ossify:work-item` skill body, which owns work-item execution.

```bash
bash -c '
  set -u
  ARGS="${*:-}"
  echo "work-item: ARGS=${ARGS:-<none>}"
' _ "$ARGUMENTS"
```

Now load the skill body and follow it:

**Read `${CLAUDE_PLUGIN_ROOT}/skills/work-item/SKILL.md` (in OMP: `skill://work-item`) end to end and follow
it** — with the parsed absolute handoff path. The skill body owns the pre-flight
gates (handoff + spec read end-to-end, a clean worktree on the declared branch,
the ambiguity scan) → the RED gate per command-bearing AC → the TDD loop in
declared AC order → every verification command run without halting → the
ten-section `report.md` → `git add -A` in the worktree → one structured JSON
return. It never commits; the commit boundary belongs to the caller.

This is the manual-dispatch path. The same body is the system prompt of the
`ossify:implementer-agent` subagent, and the contract is identical either way.
