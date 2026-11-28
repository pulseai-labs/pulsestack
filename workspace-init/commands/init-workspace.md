---
description: Bootstrap a fresh dual-repo workspace (AI workspace + canonical). Wraps the initializing-dual-repo-workspace skill.
allowed-tools: ["Read", "Write", "Bash"]
---

Read `${CLAUDE_PLUGIN_ROOT}/skills/initializing-dual-repo-workspace/SKILL.md` (in OMP: `skill://initializing-dual-repo-workspace`) end to end and follow it.

Arguments: $ARGUMENTS

Accepted forms:

```
/init-workspace <name>
/init-workspace <name> --wrapper <existing-dir>
/init-workspace <name> [--wrapper <existing-dir>] --ai-dir-name <dir>
```

Pass the argument text after `Arguments:` to the skill for interpretation. The skill must
reject an unknown option, duplicate `--wrapper`, extra positional values, or a
missing/empty wrapper value with an error containing `--wrapper requires an
existing writable directory` plus the accepted forms above. It rejects a
duplicate `--ai-dir-name` or a missing/empty value for it the same way; the
value replaces the default `<name>-ai` directory name and is passed through as
typed. If no project name
is supplied, prompt for it interactively. Never use shell positional parameters,
never infer wrapper mode, and never treat the entire non-empty argument string as
the name.

Do not skip any of the 8 bootstrap tasks. Do not auto-commit (stage only). Print the next-steps message verbatim. If any task fails, invoke the rollback via `wi rollback "${ai_root}/.workspace/init-log"` (the `wi` dispatcher is on PATH; it sources lib modules under bash regardless of caller shell).
