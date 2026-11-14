# omp-roles

The OMP role pack for default mode. 0.5.0 ships `omp-seat`, the launcher that pins its OMP extensions onto a seat, and the `implementer` and `seat-reviewer` agents. The launcher accepts `worker` (`omp-seat worker`) and ships the `spine-driver`, `close`, `work-pr` and `orchestrator` coordinator roles, launched with `omp-seat <role>`. Since 0.6.0 it also ships `crew-spine` and `crew-work-pr` for crew 0.3.0's activated spine session and work-PR session: their brief is the procedure, and every seat they create is a herdr pane, never a task subagent (#839). `spine-driver` and `work-pr` stay the default-lane roles. Since 0.7.0, `omp-seat` passes `seat-config.yml` to every seat as a `--config` overlay that turns off omp's todo reminders: a reminder restarts a stopped turn while todos are open, so the seat could not go idle for molt's handoff (#843). The `todo` tool stays on. Since 0.7.2 the `orchestrator` role needs crew 0.3.0 (its procedure, the `orchestrate` skill). Since 0.8.0 the `orchestrator` loads seat-mods' `omp/status-extension.ts` as the last `-e`, and needs seat-mods 0.8.0: the guard stays first and the status check runs last, so molt's stop block wins. Since 0.9.0 `omp-seat` pins two extensions, `seat-mods` and `molt`, and runs no authority preflight; the orchestrator no longer needs a second plugin beyond seat-mods and crew 0.3.0 (seat-mods 0.14.0 since omp-roles 0.11.0). OMP only: it has no `.claude-plugin/` and Claude Code never loads it.

`orchestrator`: the OMP top; needs seat-mods 0.14.0 and crew 0.3.0 (its procedure, the `orchestrate` skill), and `omp-seat` refuses the role without them. Launch with `SEAT_MODS_ROLE=orchestrator`; `omp-seat` refuses the role without it, since the #798 rail keys on it. Since 0.5.0, `omp-seat orc` is the operator's short form: it sets `SEAT_MODS_ROLE=orchestrator` when the variable is unset or empty (another value is kept and refused) and runs `omp-glm` unless `--via` names another wrapper.

The `implementer` autoloads ossify's `work-item` skill and returns its JSON after staging, without committing. Install ossify 1.18.0 for `run-spine`'s OMP dispatch by agent name. Under `omp-seat`, implementer children use seat-mods' verifier profile, which denies commit, push and PR creation. Its writes are allowed in the coordinator's checkout and under `SEAT_MODS_ALLOW`; the guard does not keep it out of the checkout. The `verifier` (0.11.1+) judges one work item at close in a context that did not build it: it reads ossify's `impl-check.md` §4, §4b and §4c through `skill://close/references/impl-check.md` and returns the JSON `ossify:verifier-agent` returns, so it needs ossify 1.32.0, whose close dispatches it by agent name. Its model is not in the plugin: set `task.agentModelOverrides.verifier` in `~/.omp/agent/config.yml`, else it runs on the session's model. It gets `edit` for the §4c mutation and no `write`, `task` or `ask`; list the item worktree in `SEAT_MODS_ALLOW`, as for the implementer. A close that cannot dispatch it (omp-roles older than 0.11.1, a subagent context) stays on the inline route. The `seat-reviewer` reads a diff and writes only the report path its brief names; its first line records the reviewed HEAD, followed by findings or `Findings: none`.

Under `omp-seat`, a `spine-driver`, `close`, `work-pr`, `crew-spine` or `crew-work-pr` launch must export `SEAT_MODS_ROLE=coordinator` (unset, seat-mods guards the session as an implementer, which denies the commits, pushes and merges the procedures need) and list each hosting repo's worktree root in `SEAT_MODS_ALLOW` (e.g. `SEAT_MODS_ROLE=coordinator SEAT_MODS_ALLOW=/path/to/repo/.worktrees omp-seat spine-driver`).

## Install

Coordinator roles need ossify 1.18.0 for `spine-driver`, `close`, `crew-spine` and `crew-work-pr`, and merge-bar for `work-pr` (and for `crew-work-pr` where its brief's stopping rule is merge-bar).

OMP does not put a plugin's `bin/` on `PATH`, so a coordinator role also needs the `plugin-bin-path.ts` loader from the root README's OMP section, installed once per machine; without it `oss` is not found. `omp-seat` does not pass `--no-extensions`, so the loader in your user extension folder still loads.

```bash
omp plugin marketplace add pulseai-labs/pulsestack
omp plugin install omp-roles@pulsestack
omp plugin install seat-mods@pulsestack
omp plugin install molt@pulsestack
omp plugin install ossify@pulsestack
omp plugin install merge-bar@pulsestack
omp plugin install crew@pulsestack   # the orchestrator role only
```

Put the launcher on `PATH`. `omp plugin list` shows the installed version; the path is in the install record:

```bash
ln -sf "$(jq -r '.plugins["omp-roles@pulsestack"] | (map(select(.scope == "user")) + .)[0].installPath' ~/.omp/plugins/installed_plugins.json)/bin/omp-seat" ~/.local/bin/omp-seat
```

Run it again after an upgrade: the link points at one version's folder. `omp-seat` needs `bun`; a `--via` wrapper that runs omp under `timeout` needs `--foreground`.

`omp-seat` needs seat-mods 0.14.0 (0.4.1 first mapped `seat-reviewer` to the reviewer profile; 0.14.0 added the kill rail, #1099) and molt 0.3.0. It refuses an older version or a missing OMP extension, naming the required minimum.

Pinned and tested on omp 18.16.0; an upgrade is a PR.
