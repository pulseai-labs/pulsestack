# membrane

Static-analysis security audit for Claude Code and Codex project configurations and enabled plugins.

> **Inspired by AgentShield in [Everything Claude Code](https://github.com/affaan-m/everything-claude-code)** (Mustafa, 2026; MIT). This implementation is an independent, focused MIT-licensed audit tool tailored to composable plugin marketplaces.

## Read this first: what a clean audit means

membrane matches **common, unobfuscated patterns** with bash, jq and regular expressions, in the files it reads and nowhere else. A determined adversary who obfuscates a payload (base64, `eval` of a variable, a split string, a command built at run time) evades the rules.

**Treat a clean audit as:** "doesn't trip the common-pattern rules in the files membrane reads."
**NOT as:** "this plugin or config is safe to trust."

Every report says what was not read: each path below that is a stop is a High finding naming it, the report lists every hook command it read for you to read yourself, and [Not read, by design](#not-read-by-design) lists what an audit never looks at.

## What it reads

The audited trees: the project's `.claude/` (not `.claude/audits/`), `.opencode/`, `.codex/`, every `CLAUDE.md` and `*/.codex-plugin/plugin.json` below the project root, the single files `AGENTS.md`, `.mcp.json`, `package.json`, `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json` at the root, `~/.codex/config.toml` when the project has a Codex surface, and every file of each enabled plugin. A path there is read only when

- every byte of it below the tree is printable ASCII (0x20 to 0x7E),
- it is a regular file, reached through no symlink, and
- it is 1 MiB (1,048,576 bytes) or smaller.

Anything else is **one stop**: a High finding that names the path (escaped: `\n`, `\t`, `\xe9`) and says why, and the file is not read. Below a plugin's `hooks/` or the project's `.claude/hooks/` (not below a `node_modules/` there) the stop is HOOK-005; anywhere else it is SCANNER-003. A symlink or a file that is not regular is a stop wherever it sits in a walked tree; a name or a size is a stop only for a file the audit would read. A project `.claude/settings.json` or `.claude/settings.local.json` that is a symlink, or that exists and is not valid JSON, and a `~/.claude/settings.json` that is not valid JSON, refuse the whole audit (exit 2): which plugins are enabled is then unknown.

## What it catches

- **Plaintext secrets** in `CLAUDE.md`, `AGENTS.md`, `.claude/`, `.codex/` and plugin files (Anthropic, OpenAI, GitHub and AWS keys, JWTs, a value of 12 or more characters assigned to a variable whose name holds `API_KEY`, `SECRET`, `TOKEN` or `PASSWORD`, long base64 runs). A preview shows a variable's name and `***` for its value, and masks a key to its first and last four characters.
- **Permission grants**: `Bash(*)`, `Read(*)` or `Write(*)` in `allow`; such a grant with an empty or missing `deny` (Critical for `Bash(*)`); and a `settings.local.json` that grants what `settings.json` does not.
- **Hook injection** patterns (`curl … | bash`, `rm -rf` of an absolute path, unbounded `eval`, plaintext network exfiltration) in hook scripts, **in hook handler code** (an enabled plugin's `hooks/` module and node or python handlers, executable files there, and code under the project's `.claude/hooks/` whatever its mode) **and in hook commands declared in JSON**: the project's `.claude/settings.json` and `.claude/settings.local.json`, and an enabled plugin's `hooks/hooks.json` and `.claude-plugin/plugin.json`. A hook entry or a `hooks.json` `modules` path that cannot be read is a High finding (HOOK-005); hooks of another type are counted (HOOK-006). Every report states how many hook entries were checked, flagged, not inspected and unreadable, and how many `modules` entries resolved (`modules=N` counts entries, not distinct files); `flagged` counts pattern matches only. The report then lists every hook command it read, redacted, under **Hook commands read**: they run automatically, and no finding does not mean a command is safe.
- **MCP server misconfiguration** (an `http://` endpoint, no auth, a literal secret in `env`) in the project's root `.mcp.json` and any `.mcp.json` or `mcp.json` among the files read.
- **Prompt injection** in the project's agent definitions and slash commands (common patterns).
- **`settings.local.json` silent broadening** (a gitignored file that grants more than the committed one).

**Hook limits.** The hook patterns are the same common-pattern regexes everywhere, so the clean-audit caveat above covers hook commands too. Also not read:
- a handler outside `.claude/hooks/` and outside a plugin's `hooks/` (codex's `scripts/*.mjs`), and a file a hooks module imports from outside `hooks/` (the command that calls a handler is checked; a `modules` path outside `hooks/` is HOOK-005);
- in handler code, code-shaped forms: `fetch` or `$.http.fetch` of a file read, a path built with `homedir()` or concatenation, an argv `rm`, `fs.rmSync`, `eval(`; HOOK-001 to HOOK-003 read a command written as a string, and HOOK-004 also reads one written as quoted argv words. A guard or prompt that names what it looks for fires, and so does an executable doc file under a plugin's `hooks/` (`hooks/README.md`), which is read as a handler;
- a non-executable handler with another suffix (`.bash .zsh .rb .pl .ps1`, run as `bash hooks/x.bash`), in a plugin's `hooks/` or the project's `.claude/hooks/`;
- handler code (`.ts … .py`) below `hooks/tests/`, `test/`, `fixtures/` or `node_modules/`, and a `.d.ts`, `*.test.*` or `*.spec.*` file (a `.sh` file, or an executable file under the project's `.claude/hooks/`, is still read there as before), and OMP extensions;
- `http`, `prompt`, `agent` and `mcp_tool` hooks (counted, not inspected);
- hooks declared in skill or agent frontmatter, inline hooks in a marketplace entry, managed-policy hooks, and Codex or OpenCode hook formats;
- a plugin installed outside the `cache/<marketplace>/<plugin>/<version>/` layout (a `local/` plugin, a two-level `cache/<plugin>/<version>/` install, or an install record that points elsewhere): its `hooks/hooks.json` and `plugin.json` are not read as hook entries, or hook code;
- a `plugin.json` hooks path or a `hooks.json` `modules` path that is a symlink, escapes the plugin root (for a module, its `hooks/`) or is missing: reported as HOOK-005, not followed;
- `rm -rf "$HOME"/x`: HOOK-002 matches only `rm -rf` of an absolute path, in files and in hook entries alike.

Realistic value:
1. Catching accidental friendly-fire (secrets committed to CLAUDE.md)
2. Naive-malicious teammate PRs
3. Pre-publish hygiene before open-sourcing a Claude project
4. The common-pattern subset of compromised-plugin attacks

## The front door

Every call goes through `bin/csa`, which fixes the run's environment before any library loads. The audit runs inside a session of the project it audits, so a project's settings `env` block can reach the caller's environment; `bin/csa` does not read it for these:

- **Locale:** `LC_ALL=C` for the whole run, so every regex, glob, `read` and `sort` is byte-wise.
- **Temp files:** one directory of its own under the caller's `TMPDIR`, removed by one `trap` on exit and on INT, TERM and HUP. A run leaves nothing behind. The test suite uses the same helper (`csa_tmp_scope` in `lib/helpers.sh`).
- **Its own paths:** `CSA_PLUGIN_ROOT`, `CSA_LIB_DIR`, `CSA_RULES_DIR` and `CSA_FIXTURES_DIR` are set from `bin/csa`'s own location, and `CSA_PROJECT_ROOT` and `CSA_REDACT_MAX_LEN` are unset. A caller's value is never read. The test suite reaches its own rule fixtures by sourcing the libraries directly in a child `bash`, never through `bin/csa`; that is the only way to point the engine at other rules.
- **Tools:** each command the engine runs (`jq`, `grep`, `find`, `awk` and the rest) is resolved once, from the caller's `PATH`, to an absolute path, and `PATH` is cut to the directories those tools sit in, in the caller's order. A tool that resolves inside the working directory or inside a directory an argument names (the audited root), directly or through a symlink, refuses the run (exit 2, one line naming it). A Homebrew `jq` on macOS is found as any other.
- **Root:** the project root must be an absolute directory with no control character; anything else refuses (exit 2), and nothing is written.

What this does not stop: anything that already runs code in the session before `bin/csa` does. A project hook, a `bin/` directory the session puts on `PATH` ahead of membrane's, a `BASH_ENV` that bash reads before `bin/csa`'s first line, or an edited membrane file can source the libraries with any values, or replace `bin/csa` itself.

## Release policy after 0.9.0

0.9.0 closes membrane's input to the set above, and membrane is frozen after it. **A membrane issue becomes a release only if the engine changes a user's file wrongly, hides a finding on input inside the narrowed set that an ordinary config could hold, or Claude Code moves or reshapes a file the engine reads.** A new odd-input form is a stop or a line in the list below, not new code.

## Not read, by design

Each of these is a permanent limit. An audit says nothing about them, so a clean audit says nothing about them either.

- **Names outside printable ASCII, symlinks, files that are not regular, files over 1 MiB:** one stop each, never read (see [What it reads](#what-it-reads)). A symlinked directory elsewhere in the project, outside the walked trees, is not followed by the project-wide `CLAUDE.md` and `.codex-plugin/plugin.json` walks, so a match below it is neither read nor a stop.
- **macOS and BSD tools:** the suite runs on Linux (GNU tools, bash 5.2 and 5.3) only. BSD `grep`, `sed`, `awk`, `find` and `date`, and macOS bash 3.2, are untested until it runs there.
- **User-level config:** `~/.claude/settings.json` is read only for `enabledPlugins`; its hooks, permissions and `env`, `~/.claude.json`, `~/.claude/CLAUDE.md` and user-level agents and commands are not read. A value in `enabledPlugins` that is not a boolean, beside ones that are, is dropped without a word.
- **Plugin components other than hooks:** a plugin's `agents/`, `commands/` and `skills/` are read by the secrets rules but not by the prompt-injection rules; MCP servers declared inline in `plugin.json`, `monitors/monitors.json`, `.lsp.json` and `lspServers`, executables in `bin/` (on the session's `PATH`), and `` !`…` `` shell in a command file are not read as code that runs.
- **Settings that run a command and are not hooks:** `statusLine.command` and `apiKeyHelper` are not read.
- **Permission and secret shapes outside the lists:** bare `Bash`, `Edit`, `Bash(:*)`, `mcp__*`, `defaultMode: bypassPermissions` and `additionalDirectories: ["/"]` are not flagged; a key or token shape the secrets rules do not list is not found, and neither is a value under 12 characters assigned to a secret-named variable (`PASSWORD=hunter2`) or a password not assigned to one.
- **A checkout that already ran in the session that audits it:** its hooks and its settings `env` took effect before the audit started (see [The front door](#the-front-door) for what that can reach).
- **The project-wide walks prune nothing:** every `CLAUDE.md` and `.codex-plugin/plugin.json` below the root is read, worktree copies, `node_modules/` and vendored trees included; an unreadable directory there is not a stop.
- **A plugin whose marketplace or plugin name holds a byte that is not valid UTF-8** is a PROVENANCE-002 and is not scanned.
- **Writes follow a symlinked `.claude/audits/`:** the report, `state.json` and `suppressions.json` are written through it.
- **Two audits of one project at once:** each writes `state.json` by rename; the last one to finish wins.

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
- `state.json` — durable finding registry + audit history
- `<date>-<NN>.md` — per-run report with stable finding IDs
- `suppressions.json` — your dismissed findings (gitignored per-developer)

The **first audit run** appends `# claude-security-audit` and `.claude/audits/` to the project's own `.gitignore` when no line there is exactly `.claude/audits/`, creating the file when it is absent. It writes only `<project>/.gitignore`, and only at a repository root (a `.git` file or directory there). Anywhere else, or when `.gitignore` is a symlink or not a regular file, it writes nothing and prints the line to add. It never looks above the project.

**Suppressions.** Chat and the report always say how many findings `suppressions.json` hid, 0 included, and the report lists each hidden one marked SUPPRESSED. A checkout can ship its own `suppressions.json`, and finding ids can be computed from the files, so when the file is already there before this machine has recorded an audit of the project, chat and the report say so: read it before you trust what it hides.

## Findings reference

| Severity | Meaning | Examples |
|---|---|---|
| Critical | Immediate action | hook running `curl ... \| bash`; plaintext production API key |
| High | Fix this session | MCP with no auth; settings.local.json broadens; a path the audit did not read |
| Medium | Fix within sessions | `Bash(*)` instead of `Bash(git:*)`; agent prompt with vague injection signals |
| Low | Hygiene | localhost dev URLs; permissions slightly too broad |
| Info | Observation | "N plugins in cache not enabled here"; "no audit baseline yet" |

Scanner failures are findings too, not a clean read: SCANNER-001 (a rule failed to load, High), SCANNER-002 (a rule's check failed on a target, for example an `.mcp.json`, or a `settings.json` nested below `.claude/`, that is not JSON, High) and SCANNER-003: High for a path outside the narrowed input (a symlink, a file that is not regular, a name outside printable ASCII, a file over 1 MiB; see [What it reads](#what-it-reads)), Medium for a target this process cannot read (one per target) and for a directory of an enabled plugin or below the project's `.claude/` that it could not read, except `.claude/audits/` (not scanned) and `.claude/hooks/`, where an unreadable directory still refuses the audit. The project's own `.claude/settings.json` and `.claude/settings.local.json` are not scanned when they are not JSON: the audit refuses (see [What it reads](#what-it-reads)).

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

**Upgrading to 0.8.2.** A security fix: the tamper checks' git-tracked read (`csa state_update_self_integrity` and `csa state_check_tamper`, which `/security-audit` does not run) no longer runs a command that the audited repository's git config names through `core.fsmonitor`, set in `.git/config`, through `include.path` or `includeIf`, or in the gitdir a `.git` file points at; the skill's references no longer tell the reader to run `git` in the project. A failing `fix()` under `/apply-fix` is reported and its audit-trail entry marked `failed` (or the report says the mark could not be written), and an audit trail that is not a list or cannot be written refuses before the fix runs; no shipped rule can be applied, so nothing changes for a recorded finding. The file rules (HOOK-001 to HOOK-003, SECRETS-001 to SECRETS-004, MCP-001, CLAUDE-MD-001 and -002, PROMPT-INJ-001 and -002) read a file byte by byte, so a NUL byte or a line that is not valid UTF-8 no longer hides a match; byte-wise, `| shé` fires HOOK-001, a non-ASCII space (an em space) is not a space, a case-insensitive rule no longer folds a non-ASCII letter such as `ſ` to `s` (SECRETS-003, PROMPT-INJ-001 and -002, SECRETS-004's credential word), and `[A-Za-z]` no longer matches `é` in a collating locale such as `en_US.UTF-8` (a key, JWT or base64 run holding such a letter, `rm -érf`). SECRETS-003 counts any non-ASCII byte as a value byte, so `PASSWORD=Müllerpass1234` fires in every locale. A hook command read from JSON is matched as before. A plugin whose install record path holds `\` resolves from the record. The unused `CSA_GLOB_*` defaults are gone. Expect new findings on such files and plugins; no existing finding changes its id. See the CHANGELOG.

**Upgrading to 0.8.3.** Docs only: the skill no longer says an audit records the tamper checks' baseline. `/security-audit` neither runs the tamper checks nor records a value in `self_integrity` (a new `state.json` holds zeros there), as in 0.8.2. Nothing else changes. See the CHANGELOG.

**Upgrading to 0.8.4.** `csa state_update_self_integrity` records the `state.json` mtime that the file it writes keeps, so `csa state_check_tamper` no longer reports TAMPER-001 on a `state.json` nobody edited; run the check before any other membrane call and the record after the last one, since any later write to either file, membrane's own included, is reported. `/security-audit` still runs neither. On bash 5.2 (Ubuntu 24.04) in a UTF-8 locale, a file or directory name that ends in a byte that is not valid UTF-8 (Latin-1 text, say) no longer hides the next name from the audit or drops itself: every executable below `.claude/hooks/` and `.opencode/` that an audit reads is read, and every hook symlink, unreadable directory and plugin `hooks/` file named with a newline that an audit stops on is a stop (the `node_modules/` exclusions above are unchanged). Expect new findings only where such a name hid one before; a PROVENANCE-002 for a plugin whose only version dir has such a name goes away. No existing finding changes its id. See the CHANGELOG.

**Upgrading to 0.8.5.** In a UTF-8 locale, on bash 5.2 and 5.3, a plugin file whose path below the plugin cache holds a byte that is not valid UTF-8 (Latin-1 text, say) is read as any other plugin file. Its handler code under `hooks/` is a hook target, a plugin whose version dir holds one has its `hooks/hooks.json` and `plugin.json` hook entries read, and its findings get the `@plugin:…` id that survives a plugin update. Such a finding gets a new durable id once: it reads NEW in the next audit, and the old entry in `.claude/audits/suppressions.json` matches nothing. A full audit lists it, and `/security-audit --unsuppress <FUID>` removes it. In a multibyte locale that is not UTF-8 (EUC-JP, Big5), a plugin path holding a valid UTF-8 character that locale cannot decode (`中文`, `Straße`) moves the same way, to the id `C.UTF-8` already gives. Expect new findings only on such paths. Every other finding keeps its id, and under `LC_ALL=C` nothing changes. See the CHANGELOG.

**Upgrading to 0.9.0.** `/apply-fix`, the tamper checks, MARKETPLACE-001 and -002 and PERM-005 are gone: their findings stop showing, and a suppression of one is listed as matching no finding (`/security-audit --unsuppress <FUID>` removes it). SECRETS-001 no longer fires on a kebab-case word holding `sk-`. Expect new High findings, one for each path the audit does not read (see [What it reads](#what-it-reads)), and MCP findings on the project's root `.mcp.json`. A HOOK-005 for a hook file named with a newline or tab gets a new id once. An audit refuses (exit 2) when a project `settings.json` or `settings.local.json` is a symlink or not JSON, when `~/.claude/settings.json` is not JSON, and when a tool it runs resolves inside the project. Chat and the report now print how many findings `suppressions.json` hid. See the CHANGELOG.

## Composition

`membrane` is fully standalone. It runs in any Claude Code project, with or without other plugins. It has no integration with any other plugin in v0.1.

## License

MIT. See `LICENSE`.
