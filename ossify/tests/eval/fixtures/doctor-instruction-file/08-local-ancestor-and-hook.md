---
scenario_id: 08-local-ancestor-and-hook
expected_outcome: repair-merge-asks
expected_reason: "Exactly three `fail: claude_md` lines name the root, personal local, and ancestor files in that order. Only the root enters the repair plan; its InstructionsLoaded hook is named with the loss of firing for moved instructions. Before the yes, the plan says the remaining local and ancestor files keep Claude Code from reading AGENTS.md, so moved rules stop loading until those files are handled. After the approved merge, local and ancestor failures remain; neither file nor settings is changed."
---

Claude Code 2.1.325 invokes `/ossify:doctor interop` in `/home/cy/team/ws`;
`$HOME` is `/home/cy`.
`.workspace/pairing.json` contains exactly one JSON object:

```json
{"schema_version":"1.0","ai_workspace":{"root":"/home/cy/team/ws"},"canonical":{"root":"/home/cy/repos/api"},"well_known_paths":{}}
```

Both roots resolve to real directories and healthy git work trees. State resolves
to `/home/cy/team/ws/.ossify/project-state.json`, which exists and parses;
`OSS_STATE_FILE` is unset. The workspace's tracked instruction files are:

- `AGENTS.md`: `# ossify`, then `Review is optional.`
- `CLAUDE.md`: `Review is required.` No imports or pointer-only lines.
- `CLAUDE.local.md`: `Use my personal review checklist.`

`/home/cy/team/CLAUDE.md` exists and says `Use the team release calendar.`
`/home/cy/.claude/CLAUDE.md` and `/home/cy/team/ws/.claude/rules/style.md` exist.
No other `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` exists in the
workspace or any ancestor through `/`.

The workspace reads user, project and local Claude Code settings. User and local
settings have no hooks. Project `/home/cy/team/ws/.claude/settings.json` contains:

```json
{"hooks":{"InstructionsLoaded":[{"hooks":[{"type":"command","command":"/home/cy/tools/log-instructions"}]}]}}
```

Doctor's `/ossify:doctor interop` surface is invoked. After the read-out, the
operator answers the repair offer with an unconditional yes: "yes, go ahead".
When the merge asks which review rule to keep, the operator selects
`Review is required.`
