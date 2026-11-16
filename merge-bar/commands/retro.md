---
description: Run a retro on this project's PR review record — propose coding-standards entries and deterministic checks for classes that repeat across PRs; writes only what the operator accepts.
argument-hint: "[--last N | --since <PR or date>] [--reports <dir>]"
allowed-tools: Bash(git:*), Bash(gh:*), Bash(rg:*), Bash(ls:*), Read, Glob, Grep, Edit, Write
disable-model-invocation: true
---

Read `${CLAUDE_PLUGIN_ROOT}/skills/running-a-retro/SKILL.md` (in OMP: `skill://running-a-retro`) end to end and follow it. `Edit` and `Write` are for what the operator accepts, and the retro log.

The window and any flags: $ARGUMENTS
