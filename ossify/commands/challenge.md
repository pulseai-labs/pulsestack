---
description: Grill a plan or design, or adversarially audit a written spec/plan — ossify's internal challenge skill, with a configurable external adversary at close depth. Use for "grill me", "stress-test this", "audit this spec", or to run the critic outside a ceremony.
argument-hint: "[artifact-path]"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep
---

Parse args from `$ARGUMENTS` via a trailing argument (no positional `$1`/`$2`/`$N`),
then load the challenge skill body, whose router you load below.

```bash
bash -c '
  set -u
  ARGS="${*:-}"
  echo "challenge: ARGS=${ARGS:-<none>}"
' _ "$ARGUMENTS"
```

Now load the skill body and follow it:

**Read `${CLAUDE_PLUGIN_ROOT}/skills/challenge/SKILL.md` (in OMP: `skill://challenge`) end to end and follow
it** — with the parsed artifact path if one was given (audit mode), or against
the plan in conversation if none was (interview mode). The skill body routes;
`references/audit.md`, `references/interview.md`, and
`references/adversaries.md` carry the procedures.

This command registers on Claude Code only; on Codex the skill body is the
native `challenge` skill.
