---
description: Strict maintainability review of a branch or diff — abstraction quality, giant files, spaghetti growth, boundary leaks — pushed toward restructurings that delete complexity rather than rearrange it. One report, one disposition pass, no loop.
argument-hint: "[base-ref]"
allowed-tools: Read, Glob, Grep, Task
disable-model-invocation: true
---

Read `${CLAUDE_PLUGIN_ROOT}/skills/deep-review/SKILL.md` (in OMP: `skill://deep-review`) end to end and follow it.

Base ref to review against (may be empty — resolve per SKILL.md §1): $ARGUMENTS
