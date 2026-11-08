# membrane

Static-analysis security audit for Claude Code and Codex project configurations and enabled plugins.

> **Inspired by AgentShield in [Everything Claude Code](https://github.com/affaan-m/everything-claude-code)** (Mustafa, 2026; MIT). This implementation is an independent, focused MIT-licensed audit tool tailored to composable plugin marketplaces.

## What it catches (v0.1)

- **Plaintext secrets** in `CLAUDE.md`, `AGENTS.md`, `.claude/`, and `.codex/` files (API keys, JWTs, GitHub PATs, AWS keys, env-var-shaped leaks)
- **Permission misconfigurations** including the high-impact **schema-validation** check that catches typo'd field names like `"allowed"` instead of `"allow"` (which Claude Code silently ignores → user has no enforcement)
- **Hook injection** patterns (curl|bash, rm -rf, unbounded eval, plaintext network exfiltration) in hook scripts, **in hook handler code** (an enabled plugin's `hooks/` module and node or python handlers, executable files there, and code under the project's `.claude/hooks/` whatever its mode) **and in hook commands declared in JSON**: the project's `.claude/settings.json` and `.claude/settings.local.json`, and an enabled plugin's `hooks/hooks.json` and `.claude-plugin/plugin.json`. A hook entry or a `hooks.json` `modules` path that cannot be read is a High finding (HOOK-005); hooks of another type are counted (HOOK-006); every report states how many hook entries were checked, flagged, not inspected and unreadable, and how many `modules` entries resolved (`modules=N` counts entries, not distinct files)
- **MCP server misconfiguration** (untrusted endpoints, missing auth, env-var leaks)
- **Prompt injection** in agent definitions and slash commands (common patterns)
- **Marketplace integrity** (non-HTTPS URLs, malformed marketplace.json, Claude `.claude-plugin/` manifests, Codex `.agents/plugins/` and `.codex-plugin/` manifests)
- **`settings.local.json` silent broadening** (gitignored file overrides committed settings)

## What it does NOT catch (v0.1)

v0.1 uses bash + jq + regex (no AST). A determined adversary who obfuscates payloads (base64, eval indirection, dynamic command construction) will evade most v0.1 rules. AST-based detection is on the v0.2 roadmap.

**Treat a clean audit as:** "doesn't trip our v0.1 common-pattern rules."
**NOT as:** "this plugin/config is safe to trust."

**Hook limits.** The hook patterns are the same common-pattern regexes everywhere, so obfuscation (base64, `eval` of a variable, a split string) still gets through; the "clean audit" caveat above covers hook commands too. Also not read:
- a handler outside `.claude/hooks/` and outside a plugin's `hooks/` (codex's `scripts/*.mjs`), and a file a hooks module imports from outside `hooks/` (the command that calls a handler is checked; a `modules` path outside `hooks/` is HOOK-005);
- in handler code, code-shaped forms: `fetch` or `$.http.fetch` of a file read, a path built with `homedir()` or concatenation, an argv `rm`, `fs.rmSync`, `eval(`; HOOK-001 to HOOK-003 read a command written as a string, and HOOK-004 also reads one written as quoted argv words. A guard or prompt that names what it looks for fires, and so does an executable doc file under a plugin's `hooks/` (`hooks/README.md`), which is read as a handler;
- a non-executable handler with another suffix (`.bash .zsh .rb .pl .ps1`, run as `bash hooks/x.bash`), in a plugin's `hooks/` or the project's `.claude/hooks/`;
- handler code (`.ts … .py`) below `hooks/tests/`, `test/`, `fixtures/` or `node_modules/`, and a `.d.ts`, `*.test.*` or `*.spec.*` file (a `.sh` file, or an executable file under the project's `.claude/hooks/`, is still read there as before), and OMP extensions;
- `http`, `prompt`, `agent` and `mcp_tool` hooks (counted, not inspected);
- user-level `~/.claude/settings.json` hooks (the audit is project-scoped);
- hooks declared in skill or agent frontmatter, inline hooks in a marketplace entry, managed-policy hooks, and Codex or OpenCode hook formats;
- a plugin installed outside the `cache/<marketplace>/<plugin>/<version>/` layout (a `local/` plugin, a two-level `cache/<plugin>/<version>/` install, or an install record that points elsewhere): its `hooks/hooks.json` and `plugin.json` are not read as hook entries, or hook code;
- a `plugin.json` hooks path or a `hooks.json` `modules` path that is a symlink, escapes the plugin root (for a module, its `hooks/`) or is missing: reported as HOOK-005, not followed;
- a symlink below an enabled plugin's `hooks/` or the project's `.claude/hooks/`, or either dir when it is a symlink: reported as HOOK-005, not followed (one below a `node_modules/` there is neither read nor reported);
- `rm -rf "$HOME"/x`: HOOK-002 matches only `rm -rf` of an absolute path, in files and in hook entries alike.

Realistic v0.1 value:
1. Catching accidental friendly-fire (secrets committed to CLAUDE.md)
2. Naive-malicious teammate PRs
3. Pre-publish hygiene before open-sourcing a Claude project
4. The common-pattern subset of compromised-plugin attacks

## Install

Via Claude Code marketplace:

```
/plugin install membrane
```

Via Codex marketplace:

```
codex plugin marketplace add github:pulseai-labs/pulsestack
```

## Usage

```
/security-audit                           # full audit
/security-audit --focus secrets           # one aspect
/security-audit --verbose                 # show Info findings
/security-audit --show-suppressed         # also show suppressed
/security-audit --suppress FUID-a3f9b21c   # dismiss a finding (refuses Critical, and an id no audit produced)
/security-audit --suppress SA-2026-05-24-01-013  # same, using the display id from the latest report
/security-audit --unsuppress FUID-a3f9b21c  # remove one suppression
/secrets-scan                             # alias for --focus secrets
/permissions-review                       # alias for --focus permissions
/apply-fix SA-2026-05-24-01-013           # apply one safe-category fix
/apply-fix FUID-a3f9b21c                  # same, using durable ID
```

## Opt-in SessionStart reminder

The plugin ships `hooks/session-start-reminder.sh` but does NOT register it. To enable a "last audit N days ago" reminder on session start, add this to your **own** `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "command": "bash $HOME/.claude/plugins/cache/<marketplace>/membrane/<version>/hooks/session-start-reminder.sh" }
    ]
  }
}
```

Why opt-in: the plugin's threat model flags plugin-installed SessionStart hooks as a Critical attack surface. Forcing the hook on every user would put the plugin's own shell into the very surface its rules treat as high-severity. Your install, your choice.

## What gets written to disk

The plugin writes audit state to `<project>/.claude/audits/` for compatibility
with the existing report/state format, even when scanning Codex surfaces:
- `state.json` — durable finding registry + audit history + tamper-detection mtimes
- `<date>-<NN>.md` — per-run report with stable finding IDs
- `suppressions.json` — your dismissed findings (gitignored per-developer)
- `.lock` — transient lock file during audit runs

The **first audit run** adds `.claude/audits/` to your `.gitignore` automatically (idempotent; handles nested git repos and missing `.gitignore`).

## Findings reference

| Severity | Meaning | Examples |
|---|---|---|
| Critical | Immediate action | hook running `curl ... \| bash`; plaintext production API key |
| High | Fix this session | MCP with no auth; settings.local.json broadens; schema typo silently disables |
| Medium | Fix within sessions | `Bash(*)` instead of `Bash(git:*)`; agent prompt with vague injection signals |
| Low | Hygiene | localhost dev URLs; permissions slightly too broad |
| Info | Observation | "N plugins in cache not enabled here"; "no audit baseline yet" |

Scanner failures are findings too, not a clean read: SCANNER-001 (a rule failed to load, High), SCANNER-002 (a rule's check failed on a target, for example a `settings.json` or `mcp.json` that is not JSON, High) and SCANNER-003 (the scan could not read a target, Medium; one per target, and one per directory of an enabled plugin or below the project's `.claude/` that it could not read, except `.claude/audits/` (not scanned) and `.claude/hooks/`, where an unreadable directory still refuses the audit). A malformed `settings.json` gives four SCANNER-002, one per permissions rule that reads it, or five when a `settings.local.json` sits beside it; that alone trips the "⚠ 4 rule(s) failed during scan" banner.

Critical findings **cannot be suppressed**; they must be remediated. A Critical finding is shown even if `suppressions.json` lists it. `--suppress` takes the id of a finding an earlier audit recorded (it reads `.claude/audits/state.json` and the shipped rules, never the caller), so run an audit first. A suppressed finding that still fires stays in `state.json`, marked `"suppressed": true`, and keeps its `first_seen`; unsuppress it and it reads PERSISTED, not NEW.

**What chat lists.** Findings in an enabled plugin's `fixtures/` or `tests/` directory and in the project's `.dagr/scratch/` are scanned like any other, but chat shows them as one line, `N findings in plugin fixtures/tests and agent scratch copies (C critical, H high, M medium); listed in the report`, and not one by one. The totals and the severity table count them, and the report lists each at full severity under a `Group:` line. `--verbose` lists them in chat. A project's own `tests/` is not in the group.

**SECRETS-004 skips two shapes.** A run of 40 or more base64 characters is not reported when it is pure hex (a git SHA, a sha256 digest) on a line that names no credential, or a slash-heavy path (two or more `/`, every segment a lower-case, digit, Capitalized or UPPER-CASE word). A hex credential on a line with no credential word (`dop_v1_<64 hex>`) is therefore no longer reported by SECRETS-004; one beside `token`, `secret`, `passw`, `api_key`, `auth`, `credential` or `private_key` still is, and SECRETS-003 reports `NAME=value`. A documentation URL with `XXXX` segments, or a base32 or hex token as a path segment, is skipped too.

**Upgrading to 0.5.0.** A finding's durable id (`FUID-...`) from the free-text rules (HOOK-001 to HOOK-003 in script files, PROMPT-INJ-001, PROMPT-INJ-002, SECRETS-001 to SECRETS-004, CLAUDE-MD-001, CLAUDE-MD-002, MCP-001 to MCP-003, MARKETPLACE-001, PERM-001, PERM-003, PERM-005, PROVENANCE-002) changes once when its excerpt is over 200 characters or holds a secret-shaped or 32-character run, so that a long match can no longer share the id of a different one. A suppression or baseline entry for such a finding reads NEW once and must be suppressed again; the old suppression matches nothing, and a full audit lists it (remove it with `/security-audit --unsuppress <FUID>`). Short findings keep their ids. See the CHANGELOG.

**Upgrading to 0.5.1.** A HOOK-004 finding in a script file (`network-exfiltration`) gets a new durable id once, because the id now follows what the rule matched (the network commands and sensitive paths that fire, and the lines that hold both) and not the first 200 characters of the file. It reads NEW in the next audit and must be suppressed again; the old entry in `.claude/audits/suppressions.json` matches nothing; a full audit lists it, and `/security-audit --unsuppress <FUID>` removes it. HOOK-004 read from `.claude/settings.json`, `.claude/settings.local.json`, or an enabled plugin's `hooks/hooks.json` or `.claude-plugin/plugin.json` keeps its id; any other file under `.claude/hooks/`, JSON included, is a script file and moves. See the CHANGELOG.

**Upgrading to 0.5.2.** HOOK-004 (`network-exfiltration`) fires on fewer files: `async`, `sync`, `curly`, `.curlrc`, `chmod 700 ~/.ssh` and the like no longer count as a network command or as a name. A finding in a script file whose names or both-lines came from such a token (a script with `rsync `, a JS or TS hook with `async `, a Go `func `, `openssh `, or a `.ssh ` as in `chmod 700 ~/.ssh `) usually gets a new durable id once, and so does a file with `nc` then an em space when audited under a UTF-8 locale; it reads NEW in the next audit and must be suppressed again, and the old entry in `.claude/audits/suppressions.json` matches nothing; a full audit lists it, and `/security-audit --unsuppress <FUID>` removes it. A finding that stops firing leaves its old suppression the same way. An id whose names and lines are unchanged keeps it, including a file that still has a real `nc `, `ssh ` or `curl`. See the CHANGELOG.

**Upgrading to 0.6.1.** HOOK-004 (`network-exfiltration`) also reads `~/.ssh`, `~/.gnupg` and `~/.aws` written as `$HOME/...`, `"$HOME"/...`, `${HOME}/...`, `/home/<user>/...`, `/Users/<user>/...` and `/root/...`, so it fires on more files. A HOOK-004 finding in a script file gets a new durable id once when such a path adds a both-line or a name it did not fire on before; it reads NEW in the next audit, and the old entry in `.claude/audits/suppressions.json` matches nothing: a full audit lists it, and `/security-audit --unsuppress <FUID>` removes it. A hook command read from JSON keeps its id. `${HOME:-x}/.ssh` and `~user/.ssh` stay silent. See the CHANGELOG.

**Upgrading to 0.7.0.** `csa suppress_add` is `csa suppress_add <root> <id> <note>`; the old four-argument form still runs and its severity is ignored. It refuses an id no recorded audit produced (exit 3) and a missing `state.json` (exit 2), and takes severity from membrane's own registry and rules, so a Critical finding cannot be suppressed by passing another severity. A suppression of a Critical finding made before 0.7.0 (or written by hand) no longer hides it: it shows again, and the entry stays in the file until `/security-audit --unsuppress <FUID>` removes it. A suppressed finding is now recorded in `state.json` on every audit, so it no longer ages out while it fires. See the CHANGELOG.

**Upgrading to 0.7.1.** HOOK-004 (`network-exfiltration`) also reads `ncat`, `netcat`, `nc.openbsd`, `nc.traditional`, `socat`, `sftp`, `ftp`, `tftp`, `telnet`, bash's `/dev/tcp/` and `/dev/udp/`, and a quoted `'nc'`, `"ssh"` or `'scp'` word (the argv form of `spawn('scp', …)`), so it fires on more files. A HOOK-004 finding in a script file gets a new durable id once when the file holds one of these forms, in code or in a comment, that adds a name or a both-line; it reads NEW in the next audit, and the old entry in `.claude/audits/suppressions.json` matches nothing: a full audit lists it, and `/security-audit --unsuppress <FUID>` removes it. A hook command read from JSON keeps its id. Uppercase names (`CURL`, `SSH`) stay silent. See the CHANGELOG.

**Upgrading to 0.7.2.** Each finding in an audit now gets a display id, `SA-<date>-<NN>-<NNN>` (the run of the day, then the finding's number in that run's report), which chat and the report print and `--suppress` and `/apply-fix` accept for a registered finding (not a SCANNER finding); it names a line of the latest recorded audit's report and resolves to nothing after the next audit, so use the `FUID-...` across sessions. No finding's durable id changes. `state.json` keeps its layout and `schema_version` 2, with one added field per registry entry, `last_display_ids`, the ids the latest audit printed for it (one finding id can stand for several lines that read alike, each printed under its own display id; every one of them resolves). A project's first audit now creates `.claude/audits/` itself. At the next audit, `state.json` registry entries that are not objects, and entries with no numeric `last_run_index` that do not fire in that audit, are dropped: a finding such an entry stood for reads NEW once. An entry with no numeric `last_run_index` whose finding fires is kept, reads PERSISTED and keeps its `first_seen`. A registry that one of those entries had stuck (every audit since then exited 5 after recording its run) runs its first working clean-up then, and may evict many entries unseen for more than 10 runs in that one audit. See the CHANGELOG.

**Upgrading to 0.8.0.** HOOK-001 to HOOK-004 also read hook handler code: every `.ts .tsx .jsx .js .mjs .cjs .mts .cts .py` file under an enabled plugin's `hooks/` (its hooks module and the node or python handlers kept there; not a `.d.ts`, `*.test.*` or `*.spec.*` file, nor anything under `tests/`, `test/`, `fixtures/` or `node_modules/`), an executable file with no code suffix there, and code under the project's `.claude/hooks/` whatever its mode. A plugin's `hooks/hooks.json` `modules` list is resolved: a path outside `hooks/`, missing, a symlink or not a string is a High HOOK-005 finding, and the coverage line ends `modules=N`. A symlink below a plugin's `hooks/` or the project's `.claude/hooks/` is a High HOOK-005 finding too, and so is a file whose name holds a newline or tab below a plugin's `hooks/`, or a code file with such a name under the project's `.claude/hooks/` (a non-executable one, or a `.py .js .ts` one in any mode). Under `.claude/hooks/`, an executable one with another suffix (`.mjs`, say, or none) still refuses the whole audit, and a `.sh` one is still a Medium SCANNER-003 on the fragment. Expect new findings the first time you audit after upgrading; they read NEW and are suppressed as usual. No existing finding changes its id. See the CHANGELOG.

**Upgrading to 0.8.1.** A security fix: `/apply-fix` no longer sources a file that `.claude/audits/state.json` names (a `rule_path` field, which membrane never wrote); it finds the rule only by the finding's `rule_id` among membrane's own rules. No shipped rule is both auto-fixable and mechanically fixable today, so `/apply-fix` refuses every finding, as before. HOOK-001 needs a word end after `bash`, `sh` or `zsh`, so `curl … | shasum`, `| shellcheck` and `|| shellish(…)` no longer fire; every real `| sh` form still does. The secrets rules also read `.mjs .cjs .tsx .jsx .mts .cts` files, in enabled plugins, `.opencode/`, `.codex/` and anywhere under the project's `.claude/`. A plugin named like a version (`unknown`, `deadbeef`, `v1.2`) (installed under a version-shaped version dir such as `1.0.0` or a commit hash; one whose version dir is `latest`, a date or a bare number like `1` is still unread, with no finding) is read as the plugin: its hook code, `hooks/hooks.json` and `modules` are read, and its existing findings get a new id once. A project root whose path holds `[` or `\` no longer has `.claude/audits/` or `.opencode/node_modules/` scanned. A directory of an enabled plugin, or below the project's `.claude/` (not `.claude/audits/`, which is not scanned, and not `.claude/hooks/`, where it still refuses the audit), that the audit cannot read is a Medium SCANNER-003, and the audit goes on. A symlink below a `node_modules/` under a hooks dir is no longer a HOOK-005. Expect new findings from the secrets rules, and on a plugin named like a version; a dropped finding stops showing, and a suppression on it, or on a moved id, is listed as matching no finding (`/security-audit --unsuppress <FUID>` removes it). See the CHANGELOG.

**Upgrading to 0.8.2.** A security fix: the tamper checks' git-tracked read (`csa state_update_self_integrity` and `csa state_check_tamper`, which `/security-audit` does not run) no longer runs a command that the audited repository's git config names through `core.fsmonitor`, set in `.git/config`, through `include.path` or `includeIf`, or in the gitdir a `.git` file points at; the skill's references no longer tell the reader to run `git` in the project. A failing `fix()` under `/apply-fix` is reported and its audit-trail entry marked `failed`, and an audit trail that is not a list or cannot be written refuses before the fix runs; no shipped rule can be applied, so nothing changes for a recorded finding. The file rules (HOOK-001 to HOOK-003, SECRETS-001 to SECRETS-004, MCP-001, CLAUDE-MD-001 and -002, PROMPT-INJ-001 and -002) read a file byte by byte, so a NUL byte or a line that is not valid UTF-8 no longer hides a match; byte-wise, `| shé` fires HOOK-001, a non-ASCII space (an em space) is not a space, and a case-insensitive rule no longer folds a non-ASCII letter such as `ſ` to `s` (SECRETS-003, PROMPT-INJ-001 and -002); a hook command read from JSON is matched as before. A plugin whose install record path holds `\` resolves from the record. The unused `CSA_GLOB_*` defaults are gone. Expect new findings on such files and plugins; no existing finding changes its id. See the CHANGELOG.

## Composition

`membrane` is fully standalone. It runs in any Claude Code project, with or without other plugins. It has no integration with any other plugin in v0.1.

## License

MIT. See `LICENSE`.
