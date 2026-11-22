# Derived input set — `doctor-provenance`

These are the inputs `rubrics/doctor-provenance.md` reads. Every fixture body
must declare every class because every criterion is scored on every fixture.
The rubric is authoritative; re-derive this file whenever the rubric changes.

| ID | Input class | Criteria |
|---|---|---|
| I1 | invocation route: bare doctor or targeted `provenance` | 1 |
| I2 | host, absolute working directory, git-worktree root, and whether that root carries `ossify/.claude-plugin/plugin.json` | 1, 2 |
| I3 | `command -v oss` output; whether it is absolute/executable; resolved symlink target; plugin-root manifest path and version when resolvable | 1, 2 |
| I4 | loaded doctor path and whether its evidence came from host base-directory metadata or an actual prior Read; owning plugin-root manifest and version | 1, 2 |
| I5 | installed-record availability, candidate count, scope and `projectPath`, version, install path, root readability, and root-manifest version | 1, 2 |
| I6 | prior `oss` verbs evidenced before this doctor invocation | 3 |
| I7 | prior loaded ossify prose paths, their owning roots, and the bodies on both sides at the expected relative paths, stated as facts | 3 |
| I8 | whether conversation history is complete or compacted for the prior-use interval | 3 |
| I9 | health of the other five doctor surfaces when the invocation is bare | 1 |
| I10 | the failures present — a stale loaded body, a wrong binary, an unresolved role (criterion 4 scores the remedy each names: plugin update plus fresh session, PATH repair, the unresolved role(s) named; a body never states the remedy) | 4 |
| I11 | no body input: criterion 4 also scores that the read-out contains no mutation, update, restart, ceremony-safety certification, or rerun command; a body never states this | 4 |

Inputs are facts, not verdicts: state paths, versions, file contents, tool-call
history, and command outputs. Do not declare `warn`, `clean`, `partial`,
`different`, or `safe` in a fixture body when the rubric is meant to derive it.
