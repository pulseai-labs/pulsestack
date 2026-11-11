The user wants to run a security audit on the current Claude Code project.

Invoke the `auditing-claude-configs` skill in audit mode.

Pass `$ARGUMENTS` (which may contain flags like `--focus <aspect>`, `--verbose`, `--show-suppressed`, `--suppress <id>`, `--unsuppress <FUID>`) to the skill so it can parse and dispatch correctly.

If `$ARGUMENTS` contains `--suppress <id>`, route to suppression mode (refuses Critical findings, ids no recorded audit produced, and findings discovered <60s ago per the race-window rule).

If `$ARGUMENTS` contains `--unsuppress <FUID>`, route to unsuppress mode (removes that one suppression; the finding shows again if it still fires).

If `$ARGUMENTS` is empty, run a full audit across all 6 aspects.
