---
description: Pair an already-populated AI workspace with an already-populated canonical repository (Scenario C). Wraps the pairing-existing-dual skill.
allowed-tools: ["Read", "Write", "Bash"]
---

Read `${CLAUDE_PLUGIN_ROOT}/skills/pairing-existing-dual/SKILL.md` (in OMP: `skill://pairing-existing-dual`) end to end and follow it.

Arguments: $ARGUMENTS

The text after `Arguments:` should carry two absolute paths: the existing (already-populated) AI workspace, then the existing canonical git repo — e.g. `/abs/path/my-workspace /abs/path/my-canonical`. If either is missing, prompt for it interactively.

This is the both-repos-already-exist case: write the `.workspace/pairing.json` manifest into the existing AI workspace and install the trace-filter commit-msg hook (always in canonical; also in the AI workspace if it is a git repo). NEVER create, seed, stub, or overwrite any existing AI-workspace content — the only file authored inside it is `.workspace/pairing.json`. NEVER touch the canonical working tree beyond installing `.git/hooks/commit-msg`. NEVER `git init` the user's existing AI workspace.
