---
description: Diagnose an ossify project — state health, spec validation, rule authoring, Claude/Codex interop, the skill budgets, and plugin provenance
argument-hint: "[state|spec|rules|interop|budget|provenance]"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep
---

Parse args from `$ARGUMENTS` via a trailing argument (no positional `$1`/`$2`/`$N`),
then load the `ossify:doctor` skill body, which owns the diagnosis.

```bash
bash -c '
  set -u
  ARGS="${*:-}"
  echo "doctor: ARGS=${ARGS:-<none>}"
' _ "$ARGUMENTS"
```

Now load the skill body and follow it:

**Read `${CLAUDE_PLUGIN_ROOT}/skills/doctor/SKILL.md` (in OMP: `skill://doctor`) end to end and follow it** —
with the parsed surface name, if any. The skill body owns the routing (an
optional surface token; empty runs the full sweep) → state inspection
(`oss doctor`'s four gate lines, the remedy table, then the advisory reads the
skill performs itself — lock, ledger, fakes, patches, worktrees) → lean-spec
validation → machine-checkable-rule authoring → the Claude/Codex interop check
→ the budget check → the plugin provenance check.

It shells out to `oss` for mechanical facts **where a verb exists**. The interop
surface no longer has one: `interop_check` was 175 lines of bash that opened
files and described them, and the skill performs that surface by reading — the
manifest walk and parse, `ai_workspace`'s and every declared repo's root as
directories, a raw `git -C` probe on each declared repo, and the `AGENTS.md` /
`CLAUDE.md` scan. What stays mechanical there is path
*resolution* (`oss repo_root`, `oss state_path`), because every mutating verb
routes through it.

With no argument it runs all six surfaces and reports all six. Unlike `/close`,
nothing here halts on a failure and nothing here is a gate: `doctor` reports, and
the only things it writes are a rule block the user asked for and §7's `claude_md`
repair, on the operator's explicit yes.

It also runs on a **broken** project by design — an uninitialised project, a
corrupt state file or a missing topology declaration is the finding, not a
reason to refuse.
