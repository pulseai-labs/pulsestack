---
description: Adopt an existing project into ossify — for a codebase that already has product source, with or without the scaffold-dev legacy stack — fail-closed gates, six conversions, Release 0 closed retroactively. Use when onboarding a project that already shipped; /ossify:start refuses it.
argument-hint: "[project-name]"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep, Skill
---

Parse args from `$ARGUMENTS` via a trailing argument (no positional `$1`/`$2`/`$N`),
then load the adoption ceremony, whose contract you load below.

```bash
bash -c '
  set -u
  ARGS="${*:-}"
  echo "adopt: ARGS=${ARGS:-<none>}"
' _ "$ARGUMENTS"
```

Now load the skill body and follow it:

**Read `${CLAUDE_PLUGIN_ROOT}/skills/adopt/SKILL.md` (in OMP: `skill://adopt`) end to end and follow it** —
with the parsed project name. The skill body owns the whole ceremony: the
pre-flight gates (A0-A5, and A6 for a plain repo), the six conversions (C1-C6), outputs reconciled where they exist and
authored where they do not, and the adoption record. Every gate refuses fail-closed,
and nothing in a legacy stack's state files is ever written. A plain repo with no
legacy stack is class P: the skill's `references/plain-repo.md`.

This is the entry point for the project that already has code — where
`/ossify:start` refuses on its canonical-content gate; its refusal names this
command. The command registers on Claude Code only; on Codex the skill body is
the native `adopt` skill.
