---
description: Pair a new AI workspace with an existing canonical repository (Scenario A). Wraps the pairing-canonical-repo skill.
allowed-tools: ["Read", "Write", "Bash"]
---

Read `${CLAUDE_PLUGIN_ROOT}/skills/pairing-canonical-repo/SKILL.md` (in OMP: `skill://pairing-canonical-repo`) end to end and follow it.

Arguments: $ARGUMENTS

Accepted form:

```
/pair-workspace <abs-path-to-canonical> [--ai-dir-name <dir>]
```

If the text after `Arguments:` ends with an `--ai-dir-name <dir>` pair, split that pair off first: `<dir>` replaces the default `<name>-ai` directory name and is passed through as typed. Treat the rest, when non-empty, as the absolute path to the existing canonical repository. Otherwise, prompt for the path interactively. Reject a duplicate `--ai-dir-name` or one with no value, quoting the accepted forms above.

Validate per SPEC §9.4 abort conditions before touching anything (refuse if the canonical already has AI scaffolding — `.claude/memory-bank/`, `MASTER-SPEC.md`, `docs/MASTER-SPEC.md`, or `.claude/.onboarding-state.json`). Do not modify the existing canonical's working tree — only install the commit-msg hook in its `.git/hooks/` and stage the new AI workspace.
