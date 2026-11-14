---
description: Drive spec-core onboarding for a new ossify project (journey map, skeleton-cut, bones, risk gates, posture, spec-core critic)
argument-hint: "[project-name]"
allowed-tools: Bash(bash:*), Read, Write, Edit, Skill
---

Parse args from `$ARGUMENTS` via a trailing argument (no positional `$1`/`$2`/`$N`),
then load the `ossify:start` skill body, which owns spec-core onboarding.

```bash
bash -c '
  set -u
  ARGS="${*:-}"
  echo "start: ARGS=${ARGS:-<none>}"
' _ "$ARGUMENTS"
```

Now load the skill body and follow it:

**Read `${CLAUDE_PLUGIN_ROOT}/skills/start/SKILL.md` (in OMP: `skill://start`) end to end and follow it** —
with the parsed project name. The skill body owns the journey map →
skeleton-cut → bones → risk gates → smoke-test → posture block → spec-core
critic moment flow and shells out to `oss` for all state.
