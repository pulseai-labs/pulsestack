---
description: Resume from a session handoff — verify its claims against the live repo, report drift, then follow its sequence; never refuses
argument-hint: "[path]"
allowed-tools: Bash(git status:*), Bash(git rev-parse:*), Bash(git ls-files:*), Bash(gh issue view:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(test:*), Bash(ls:*), Read, Glob, Grep
---

Handoff to resume, if one was named: $ARGUMENTS

Read `${CLAUDE_PLUGIN_ROOT}/skills/handoff-resume/SKILL.md` (in OMP: `skill://handoff-resume`) end to end and follow it.
