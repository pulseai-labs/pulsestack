---
scenario_id: 08-local-ancestor-and-hook
expected_outcome: repair-merge-asks
expected_reason: "Exactly three `fail: claude_md` lines name the root, personal local, and ancestor files in that order. Only the root enters the repair plan; its InstructionsLoaded hook is named with the loss of firing for moved instructions. After the approved merge, local and ancestor failures remain; neither file nor settings is changed."
---

Claude Code 2.1.325 invokes `/ossify:doctor interop` in `/srv/team/ws`.
`.workspace/pairing.json` contains exactly one JSON object:

```json
{"schema_version":"1.0","ai_workspace":{"root":"/srv/team/ws"},"canonical":{"root":"/srv/repos/api"},"well_known_paths":{}}
```

Both roots resolve to real directories and healthy git work trees. State resolves
to `/srv/team/ws/.ossify/project-state.json`, which exists and parses;
`OSS_STATE_FILE` is unset. The workspace's tracked instruction files are:

- `AGENTS.md`: `# ossify`, then `Review is optional.`
- `CLAUDE.md`: `Review is required.` No imports or pointer-only lines.
- `CLAUDE.local.md`: `Use my personal review checklist.`

`/srv/team/CLAUDE.md` exists and says `Use the team release calendar.` It is
outside the workspace. No other suppressing files exist at the workspace or
in any ancestor through `/`. The user file `~/.claude/CLAUDE.md` exists, and
`/srv/team/ws/.claude/rules/style.md` exists; neither is a finding.

The workspace reads user, project and local Claude Code settings. User and local
settings have no hooks. Project `/srv/team/ws/.claude/settings.json` contains:

```json
{"hooks":{"InstructionsLoaded":[{"hooks":[{"type":"command","command":"/srv/tools/log-instructions"}]}]}}
```

Doctor's `/ossify:doctor interop` surface is invoked. After the read-out, the
operator answers the repair offer with an unconditional yes: "yes, go ahead".
When the merge asks which review rule to keep, the operator selects
`Review is required.`
