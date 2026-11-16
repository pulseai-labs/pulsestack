---
description: Review a pull request as defect classes with every site, each sorted against the merge bar in its own body — two axes in parallel, coverage stated per file; round 2+ reviews only the fix diff and each prior class's closure unless the bar or Claim changed. Reports only.
argument-hint: "<PR number or URL> [--round N --previous <report>] [--standards <path>] [--verifier <path>] [--head <sha>] [--body <file>]"
allowed-tools: Bash(git:*), Bash(gh:*), Bash(rg:*), Read, Glob, Grep, Write, Agent
---

Read `${CLAUDE_PLUGIN_ROOT}/skills/reviewing-a-pr/SKILL.md` (in OMP: `skill://reviewing-a-pr`) end to end and follow it. `Write` is for the report file only. This command takes no `run` (its tools cannot run a suite): a `--run` in the arguments is ignored, never run, and the report's `Run:` header says so. `run:` is for a launcher that invokes the skill with a scratch directory.

The PR to review, and any flags: $ARGUMENTS
