# Threat model

Distilled from SPEC §4. Read this when authoring rules or interpreting findings.

## Primary threat — compromised marketplace plugin (common-pattern subset)

User runs `/plugin install some-thing`. Plugin's files land in `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` and are activated for subsequent sessions where the user enables them. Attacker now has hooks, agent prompts, slash commands, and MCP configs that run / influence Claude on every session.

**Catches:** direct `curl ... | bash` (in hook scripts, and in hook commands declared in JSON: see Hook entries below; HOOK-001 needs a word end after `bash`, `sh` or `zsh`, any character that is not a letter, digit or `_`, so `| shasum` and `| shellcheck` do not fire while a quoted, redirected or bracketed `| sh` does), plain-text exfiltration in agent prompts, missing MCP auth, untrusted endpoint URLs, broad permission grants the attacker can leverage, plaintext credentials in plugin files.

**Does NOT catch:** base64-encoded payloads, eval indirection, dynamic command construction, splice-via-includes, deliberately-malformed regex bait, prompt-injection that uses semantic encoding rather than literal exfiltration strings.

## Hook entries declared in JSON (0.3.0)

A hook command can live in JSON rather than a script: the project's `.claude/settings.json` and `.claude/settings.local.json`, an enabled plugin's `hooks/hooks.json`, and an inline or path-referenced `hooks` field of its `.claude-plugin/plugin.json`. The audit walks exactly those files (never a nested `.claude/**/settings.json`, never a plugin's `fixtures/` or `tests/` copy) with `jq`, reads only `.hooks.<Event>[i].hooks[j]` entries (so a URL in `env` or a `permissions` string never reaches a hook pattern), decodes the command (JSON escapes, plus exec-form `args`), and runs the HOOK-001 to HOOK-004 patterns on the whole decoded command. Each piece it cannot read is a High HOOK-005 finding; hooks of type `http`, `prompt`, `agent`, `mcp_tool` or a later type are counted (one HOOK-006 Info finding per file). The engine prints `csa: hook-coverage checked=N flagged=N not-inspected=N unreadable=N modules=N (flagged counts pattern matches only; the report lists every hook command read)`, and the report header carries it, so a zero-finding report still says what was not read. The report then lists every command entry it read under "Hook commands read": a pattern match is not a reading of a command, and those commands run automatically. Each command there, and in a hook entry's finding preview, is cut to 200 bytes (`bin/csa` runs under `LC_ALL=C`, so a cut can split a multibyte character), then the value of these shapes is `***`: an assignment to a name holding `API_KEY`, `SECRET`, `TOKEN` or `PASSWORD`; `Bearer <token>`; `user:password` after `-u` or `--user` and in `scheme://user:password@`; the value of `--token`, `--password`, `--passwd`, `--secret`, `--api-key`, `--apikey` and `--auth`; an attached `-p<value>` in a `mysql`, `mysqldump` or `mysqladmin` command; then a key of the five shapes `csa_redact` knows keeps its first and last four characters. Anything else in a command is printed as written.

This keeps the no-LLM boundary below: the walk is a mechanical check on open input that can only add a stop, so no model reads hook text and nothing is approved (skill-first question 3). A `plugin.json` hooks path is resolved inside the plugin root with a physical containment check, and is read only inside the narrowed input (printable ASCII, no symlink on its way below the plugin root, a regular file of at most 1 MiB; otherwise a HOOK-005); no handler path is parsed out of command text. User-level `~/.claude/settings.json` hooks are not read.

## Hook handler code (0.8.0)

Claude Code runs a plugin's code two ways: a hooks module that `hooks/hooks.json` names under `modules` (with every file it imports from the plugin), and a command hook's handler (`node "${CLAUDE_PLUGIN_ROOT}/hooks/x.mjs"`). The audit reads that code by the layout the runtime reads, never by a path parsed out of command text: HOOK-001 to HOOK-004 read every `.ts .tsx .jsx .js .mjs .cjs .mts .cts .py` file under an enabled plugin's `hooks/` (not a `.d.ts`, `*.test.*` or `*.spec.*` file, nothing under `tests/`, `test/`, `fixtures/` or `node_modules/`), an executable file with no code suffix there, and code under the project's own `.claude/hooks/` whatever its mode. A path there that is outside the narrowed input (see Enumerate below: a name outside printable ASCII, a symlink, a file that is not regular, a file over 1 MiB) is a High HOOK-005 naming the path, escaped, and is not read; so is either hooks dir when it is a symlink. One below a `node_modules/` under that dir is a High SCANNER-003 instead, judged relative to the hooks dir. A plugin named like a version (`unknown`, `deadbeef`) is placed by position: a version-named segment followed by a version-named one is `<plugin>/<version>/`; one whose version dir is not version-shaped (`latest`, a date, `1`) is not placed, and its hooks are not read. Each `modules` path is resolved relative to `hooks/hooks.json` with the same physical containment check; one that does not resolve to handler code inside `hooks/` is a High HOOK-005 finding, and each one that does is counted as `modules=N`. A handler outside `hooks/` (a command that runs `scripts/x.mjs`) and a file a module imports from outside `hooks/` are not read; the command that calls a handler is still checked.

The patterns are the same common-pattern regexes as for scripts. In code HOOK-001 to HOOK-003 read a command written as a string, and HOOK-004 also reads one written as quoted argv words; code-shaped forms (`fetch`, `$.http.fetch`, `homedir()` joins, an argv `rm`, `fs.rmSync`, `eval(`) need judgment and are not read. This keeps the no-LLM boundary below: the handler-file test and the `modules` read are mechanical, can only add a stop, and approve nothing (skill-first question 3).

## Secondary threats — the realistic primary value

1. **Malicious teammate PR** that isn't trying hard to hide (plain-text hook with `rm -rf`, agent definition with literal "send my data to attacker.com")
2. **Accidental friendly-fire** — API key pasted into CLAUDE.md and committed
3. **Public-repo exposure** — open-sourcing a Claude project with `.claude/` configs that contain secrets or overly-permissive grants
4. **`settings.local.json` silent broadening** — gitignored file grants `Bash(*)` while committed `settings.json` restricts to `Bash(git:*)`; code review missed it because it's not in git

## Out of the threat model

- Runtime attacks during an active Claude Code session
- Network attacks on Claude Code itself
- Side-channel attacks
- Attacks on the audit plugin's own files

## Meta-risk constraint (G3 lock)

The audit reads files that, per the threat model, may be attacker-controlled. The plugin detecting exfiltration must not itself be one:
- Static analysis only — no LLM evaluation over raw file bytes
- Findings show `file:line:offset` with redacted previews: a key of the five shapes `csa_redact` knows keeps its first and last four characters (`sk-a***xyz1`), SECRETS-003 shows `NAME=***`, and a hook command declared in JSON (in its finding's preview and in the report's list) masks the shapes listed under Hook entries above. A secret of any other shape is printed as written (the README's "Not read, by design" list says so). A finding with no line (line 0) prints the bare `file`, and one that names a JSON entry (a `json_path`) prints `file#path`
- No subagent / codex dispatch on file content

## Enumerate-targets resolution algorithm (T2-J pin)

```
0. THE NARROWED INPUT (0.9.0), one predicate for every walk below. A path below an audited
   tree is read only when every byte of it below the tree is printable ASCII (0x20-0x7E), it
   is a regular file reached through no symlink, and it is at most 1 MiB. Anything else is
   one stop naming the path (escaped) and is not read: HOOK-005 below a plugin's hooks/ or
   the project's .claude/hooks/ (not below a node_modules/ there), SCANNER-003 elsewhere,
   both High. A symlink or a file that is not regular is a stop wherever it sits in a
   walked tree; a name or a size only for a file the walk would read. The walks are
   NUL-delimited, so no name can split a target. Skill-first question 2 for the predicate
   (a fixed alphabet, file kinds, a size bound), question 3 for each stop.

1. PROJECT_TARGETS (the root: an absolute directory holding no control character, or exit 2; every
   walk starts at its physical path, so a root that is a symlink is walked as the directory it names):
   - Every file under "$PWD/.claude/" (not .claude/audits/) with a suffix the rules read
     (.md .json .sh .py .js .ts .mjs .cjs .tsx .jsx .mts .cts), and every executable file
     under .claude/hooks/
   - Every CLAUDE.md and */.codex-plugin/plugin.json below $PWD (a symlinked directory on the
     way is not followed)
   - $PWD/.claude-plugin/marketplace.json, $PWD/.mcp.json, $PWD/AGENTS.md, $PWD/package.json and
     $PWD/.agents/plugins/marketplace.json if present
   - .opencode/ and .codex/ (and ~/.codex/config.toml with a Codex surface; a symlinked ~/.codex is a stop)
   - A directory below .claude/ (not .claude/audits/ or .claude/hooks/), .codex/, .opencode/ (not
     its node_modules/ or audits/) or an enabled plugin that cannot be read is a Medium SCANNER-003

2. ENABLED_PLUGINS_SET:
   a. Read "enabledPlugins" from three files, in this order: $HOME/.claude/settings.json,
      $PWD/.claude/settings.json, $PWD/.claude/settings.local.json. Claude Code writes an
      object map, {"<plugin>@<marketplace>": true|false}; only boolean values count. An
      array of names (older files, fixtures) reads as each name true. An absent key or
      an absent file reads as empty.
   b. Merge by key, the later file wins: a project `false` disables a user `true`. The
      set is the keys left at true. Identity is the whole key, plugin@marketplace, so two
      marketplaces with one plugin name stay distinct.
   c. A value that holds entries yet yields none (a string, an array of non-strings, an
      object of non-booleans) prints one warning naming the shape. This format belongs to
      another tool and can change; an audit that skips every plugin must not read as clean.
   d. A settings file that is unreadable, not a regular file, or not valid JSON (an empty
      file, and one with anything but white space after its first value, included), a project
      settings file reached through a symlink or over 1 MiB, or an unreadable or
      unrecognised installed_plugins.json, makes the set unknown: the enumeration stops
      (rc 2). It never reads as empty.
   e. Resolve each key to a filesystem path:
      - First: $HOME/.claude/plugins/installed_plugins.json. Take this project's `local`,
        else `project`, entry (its projectPath equals the project root, compared as
        physical paths), else the `user` entry. Use its installPath only if it is a
        directory physically inside $HOME/.claude/plugins/ (a `..`, a symlink out, a
        relative or missing path fails the guard). A project's settings never contribute
        a path.
      - With no entry, for plugin@marketplace: $HOME/.claude/plugins/cache/<marketplace>/<plugin>/
        with its `.active` version or its only version. Any part holding `/` or `..` is refused.
      - A bare name (array form): $HOME/.claude/plugins/cache/<name>/<version>/, then
        $HOME/.claude/plugins/local/<name>/ (local-dev), with the same refusal.
      - If none resolves: PROVENANCE-002, a High finding that names the plugin and
        why. The engine records it in state and reports it like any finding, so a later
        audit that resolves it removes it from the report.
   f. A finding's id for a plugin file drops the version:
      @plugin:<plugin>@<marketplace>:<path inside the plugin>.

3. SCAN_SET = PROJECT_TARGETS ∪ files-under-each-ENABLED_PLUGIN-path

4. PARANOID_CANDIDATES (counted but not scanned by default):
   - Keys in installed_plugins.json, plus each cache/<marketplace>/<plugin> directory
     (as plugin@marketplace), not at true in the enabled set; a `false` key is a
     candidate. `temp_git_*` (a clone in progress) is skipped. The older flat
     cache/<name>/<version> layout lists <name>.
   - If count > 0, emit INFO-PARANOID-001 with the count
```
