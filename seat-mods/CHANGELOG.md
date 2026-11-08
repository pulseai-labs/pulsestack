# Changelog

All notable changes to the `seat-mods` plugin.

## 0.15.4 — 2026-11-09

The kill rail reads a head word after the reserved `time` (#1139). The rail took `time` as a wrapper and named the next word as the command, so in `time ! kill -1`, `time if kill -1; then :; fi` and `fish -c 'time while kill -1; end'` it named `!`, `if` or `while` and read no kill: the call went to the model as if the rail were absent. Behind the same miss sat every other kill rule (`ps aux; time ! kill 123`, `time ! pkill -u dev`), at top level, in a shell or fish string, in `eval '…'` and in an OMP `eval` literal. bash 5.3, zsh 5.9, dash and fish 4.2.1 were probed with harmless strings only.

- The reserved `time` is taken off a command's head only when a head word (`if`, `then`, `elif`, `else`, `do`, `while`, `until`, `!`, `{`, `(`) or another `time` follows it, after one `-p` and then one `--`, as bash reads them, and again after each head word it uses (`time -p ! kill -1`, `time -- ! kill -1`, `time time ! kill -1`, `time ! time ! kill -1`). Any other `time` stays the time program with its options (`time -f %e kill -9 -1`, `time -p kill -1`), read as before.
- No other wrapper changes. Only the reserved `time` takes a pipeline, so a head word after `A=1 time`, `'time'`, `/usr/bin/time`, `time -p -p`, `nohup`, `env`, `sudo` or `xargs time` names a program, which the shell runs and which does not exist: `A=1 time ! kill -1`, `nohup ! kill -1` and `xargs time ! kill -1` stay allowed.
- Deliberate false stops: `\time ! kill -1`, since the reader takes `\time` as `time`, though the shell runs the time program; `time then kill -1` and the like, which bash rejects; `-p` or `--` after `time` under zsh and fish, which take neither (`zsh -c 'time -p ! kill -1'`); every one of these forms under dash, whose `time` is not reserved (`dash -c 'time ! kill -1'`); a redirection between `time` and the head word (`time >/dev/null ! kill -1`); `time time`, `time ! time` and `time ! !` under zsh, and `time time` under fish; and a `time` after `|` under bash and fish. Each runs nothing in the shell named; the README lists them.
- No form the rail refused is now allowed: 0 of 1,760,248 commands on a differential grid of wrappers, head words, payloads and shell contexts loosened or newly throw, and the only benign payload that changes verdict sits behind `ps aux;`, where a call that lists and signals is meant to be refused.
- The role-guard rails' `time -p <cmd>` known limit and the kill rail's `coproc` known limit are unchanged.
- The omp-roles floor stays at seat-mods 0.14.0. Claude Code and OMP both read the same `killRule`, and omp needs no change.

## 0.15.3 — 2026-11-08

The kill rail reads `fish` (#1127). fish was a name the rail did not read, so `fish -c 'kill -1'` went to the model as if the rail were absent. fish 4.2.1 was probed with harmless strings only.

- `fish` gets a reading of its own, used only for that name, and not the three POSIX readings. Its options are read as fish reads them, with no permutation: `--`, a bare `-` or the first operand ends them. `-c` and `-C`/`--init-command` take the rest of the cluster or else the next word, and every value is read, since fish runs every one (`fish -c 'echo ok' -c 'kill -1'`, `fish -C 'kill -1'`). A long name is any unique prefix, with `=value` or the next word (`fish --command='kill -1'`, `fish --comm 'kill -1'`, `fish --init 'kill -1'`). `p`, `d`, `f`, `D` and `o` take a value, so `fish -p -c 'kill -1'` runs nothing and is allowed.
- Each fish string is read as POSIX text, and again with fish's command prefixes taken off: `and`, `or`, `not` and `begin`, quoted or not, since fish reads `'not'` and `n""ot` as `not`, and a block's `{`. They are taken off at the head of a command: the start, after `;`, `&`, `|` or a newline, after a block's `{`, after a substitution's `(` or `$(` (inside double quotes too), and after `if`, `while`, `else`, `!` or `time`, so a `{` after a prefix is taken off too (`fish -c 'true; and kill -1'`, `fish -c 'not kill -1'`, `fish -c 'begin kill -1; end'`, `fish -c '{kill -1}'`, `fish -c 'not {kill -1}'`, `fish -c 'echo (not kill -1)'`, `fish -c "'not' kill -1"`).
- On the probe's option grids the rail missed every string fish runs (2105, 6736 and 53) and now misses none. On its string grid it missed all 8640 kill forms fish runs; it now reads every naturally spelled one, in a POSIX-shaped context or behind a fish prefix, and the 6930 it still misses are the known limits below.
- Deliberate false stops: a `-c` or `-C` value is read even where fish then runs nothing (after `-n`/`--no-execute`, beside `-v` or an unknown option such as `-e`, after an ambiguous prefix such as `--i`, or when a value-taking option is left with no value): 4448 forms of the option grids, none where fish runs the other string. Text fish quotes and POSIX does not is read as code: ``fish -c 'echo `kill -1`'`` is refused, though fish has no backticks.
- A fish string the rail cannot read (`fish -c '$(x'`) is unread, as under sh, and does not hide a refusal elsewhere in the call.
- Known limits. fish's string grammar past the prefixes is read as POSIX text, so a single quote that takes `\'`, an escape outside quotes (fish decodes `kill \x2d1` to `kill -1`) and an unquoted `(…)` among the operands (`kill 123 (echo x) -1`) are misses. Brace expansion and a substitution's value are misses as under sh (`fish -c 'kill {,-1}'`, `fish -c 'kill (echo -1)'`).
- Other names change on nothing: every other runner name keeps its verdicts, on 1,235,520 fuzzed commands, and the suite pins the verdicts of eighteen of them on its 3762-form fish grid.
- The omp-roles floor stays at seat-mods 0.14.0. Claude Code and OMP both read the same `killRule`, and omp needs no change.

## 0.15.2 — 2026-11-07

The kill rail reads the grammar of ksh93, mksh and yash that its three readings missed (#1126). 0.15.1 read those names from source and listed three points as misses; they were probed this time, on the binaries (ksh93u+m 1.0.10, mksh R59c with its `lksh`, yash 2.55) and on macOS's ksh 93u+, with harmless strings only. The probe found more than the three points. A name it did not read is a miss: the call goes to the model as if the rail were absent.

- A fourth reading each for `ksh` and `ksh93`, for `mksh` (with `lksh` and `mksh-static`), and for `yash`, used only for that runner name. `ksh` is read as both ksh93 and mksh, since on Debian and Ubuntu without ksh93 `/bin/ksh` is an alternative of mksh. ksh93 runs a first operand that names no file as a command, with `-c` or without (`ksh 'kill -1'`, `ksh -e 'kill -1'`), and its `-o` takes the next word unless that is an option (`ksh -o -c 'kill -1'`). mksh's `-T` takes the next word (`mksh -T /dev/tty2 -c 'kill -1'`), and an `-o` value of `-c`, `+c` or the empty name sets `-c` (`mksh -o -c 'kill -1'`, `mksh -o '' 'kill -1'`). yash's `-c` is also the option `cmdline`, under any prefix, any case and any punctuation (a one-letter prefix too, which yash itself rejects as ambiguous, so `yash --c 'kill -1'` is a false stop) (`yash -o cmdline`, `yash --cmd`, `yash ++nocmdline`), and `--profile` and `--rcfile` take the next word under any prefix (`yash --profile p -c 'kill -1'`).
- `lksh` and `mksh-static` join the names the rail reads, with mksh's reading: `lksh` parsed identically on all 8420 forms of the mksh grid, and `mksh-static` (Debian's static build of the same source) agreed on the `-o -c`, `-o ''`, `-o +c` and `-c -` forms probed. `lksh` shares mksh's false stops from the three generic readings (33 forms of the mksh grid where lksh runs the other string).
- Other names change on nothing: `sh`, `bash`, `zsh`, `dash`, `ash`, `rbash` and `static-sh` keep the verdicts they had, on the 8342-refusal digest of the 6174-form grid and on every other form tried.
- Correction to 0.15.1: it said `ksh +c 'kill -1'` is a deliberate false stop because ksh turns `-c` off and runs nothing. ksh93 runs the string (`+c` is off, and the first operand is run as a command), so that refusal is a true one. `yash -c + 'kill -1'` stays a deliberate false stop: yash runs the `+`, and the kill text is only `$0`.
- The extra readings also refuse forms where the shell runs nothing (an unknown option or option value, `-s`, `-D`, `-n`): a deliberate false stop, 581 forms for ksh where it is ksh93 and 679 where it is mksh (`ksh` gets both readings), 141 for mksh and 154 for yash on the 6174-form grid, none where the shell runs the other string.
- Known limits. `sh` on a host where it is ksh93, mksh (Android) or yash gets the three readings only: the extra readings are keyed on the runner name. `rksh93`, `rmksh` and `rlksh` are not read, unprobed by name. Still unread: `rksh`, `oksh`, `pdksh`, `posh`, `toybox`; fish (#1127).
- The omp-roles floor stays at seat-mods 0.14.0. Claude Code and OMP both read the same `killRule`, and omp needs no change.

## 0.15.1 — 2026-11-07

The kill rail reads more shells and `busybox` (#1116). A name it did not read is a miss: the call goes to the model as if the rail were absent.

- Eleven names are now read as shells, up from four: `rbash`, `ash`, `static-sh`, `ksh`, `ksh93`, `mksh` and `yash` join `sh`, `bash`, `zsh` and `dash`. `rbash` is bash by another name and was probed. The others are read with bash's and zsh's grammar by analogy; ksh93, mksh and yash were read from source and not run.
- `busybox` is a wrapper: the next word is the command, so `busybox sh -c '…'`, `busybox ash -c '…'`, `busybox kill -1`, `busybox killall -u dev`, `busybox xargs kill -1` and `busybox ps; kill 123` reach the existing checks. The last four were misses nobody had recorded.
- A third reading for Debian and Ubuntu busybox ash, probed on 1:1.37.0-7ubuntu1: a `-` after the first character of a cluster ends it and the options go on (`-c- -e S`, `-c-o S x`). It speaks only for such a cluster, so on the 6174-form grid of 0.14.2 it adds no refusal, and on a 4368-form ash grid it closes the 328 forms the earlier readings missed.
- README: Alpine's busybox rejects `-c-` and its `sh` reads options as dash does. Only Debian and Ubuntu busybox accepts `-c-`. 0.14.2 said Alpine did.
- A string the rail cannot finish reading (an unclosed `$(`, a substitution or an `xargs` chain nested too deep) no longer hides a refusal in another reading, segment, runner string or substitution, before it or after it. The rail reads the rest of the call and throws only when nothing refused. One shape is left: an unclosed `$(` outside quotes makes its whole string unread, so `kill -1; echo $(x` still throws (unread on the bash tool, passed on the ambient `eval` path), as it did before. Before, `bash -cO '$(x' 'kill -1'`, `bash -Oc 'kill -1' '$(x'` and, with the new names and the ash reading, `ksh -c '$(x'; kill -1` and `sh -c-o '$(x'; kill -1` threw instead of refusing, so the bash tool gave the generic unreadable stop and the ambient OMP rail's `eval` path passed them. A call that holds an unreadable string and no refusal still throws, as before.
- Deliberate false stops added: `ksh +c 'kill -1'` and `yash -c + 'kill -1'`, where the shell does not run the string.
- Known limits. From source, unprobed: ksh93's `-o` with an optional value, mksh's `-T <value>`, yash's `--profile`/`--rcfile` and their prefixes (#1126); fish (#1127). Unprobed, source not read: the pdksh line (`rksh`, `lksh`, `oksh`, `pdksh`) and `posh`. Not a wrapper the rail reads: `toybox`.
- The omp-roles floor stays at seat-mods 0.14.0. Claude Code and OMP both read the same `killRule`.

## 0.15.0 — 2026-11-06

The kill rail reaches a plain omp session (#1102). Until now only `omp-seat`'s `-e` loaded seat-mods on OMP, so an
omp session started by hand had no rail. seat-mods now ships a `package.json` with an `omp` manifest that names
`omp/kill-rail.ts`: the rail alone, over bash's command and eval's string literals, calling the `killCheck` of
`omp/extension.ts`, so the two cannot drift. omp loads it ambiently, so it reaches every omp session with seat-mods enabled, unless started with `--no-extensions`, after `omp plugin upgrade`, with no host step.

- A plain session changes in nothing but the kill refusals: no role guard, no `SEAT_MODS_ROLE` read, no other denial.
  The role guard (`omp/extension.ts`) stays `omp-seat`-only.
- A `bash` command the rail cannot read is refused with `KILL_UNCHECKED`, as free roles are. An `eval` string literal it cannot read passes: a literal is not necessarily shell (`print("cost: $(5")`), and a miss goes on to the next judge. A literal that lists and signals is still refused. Known limit: an unreadable literal also turns off the joined reading of the whole code, the one reading that sees an argv list, so `x = "$(5"; subprocess.run(["kill","-1"])` passes on to the model.
- Under `omp-seat` the rail runs twice, from the manifest and inside the guard. Harmless: it only refuses, and the
  first block wins. The one visible difference: for a bash command the rail cannot read, a guarded seat now gets the rail's
  `KILL_UNCHECKED` stop first, not its role's own deny text. A load probe on omp 18.16.0 saw each of rail, guard and molt load once under `omp-seat`; it is recorded in PR #1119's Evidence.
- Off switch: `omp plugin disable seat-mods` turns the ambient entry off and leaves `omp-seat` alone. A session with
  `--no-extensions` does not load it.
- `package.json` carries no `version`: `.claude-plugin/plugin.json` owns it. A CI contract test pins the manifest.
- Claude Code is unchanged.

## 0.14.2 — 2026-11-06

The kill rail reads a shell call two ways (#1109). Every one of `sh|bash|zsh|dash` is now read with bash's
option grammar and with zsh's, and the call is refused if either reading finds a refused string. Both
readings use one scan. 0.14.1 read one bash-shaped grammar for all four, which missed:

- zsh's `-O`, which takes no value: `zsh -cO 'kill -1'`, `-Oc`, `+cO`, `-c -O`, `-c +O`;
- zsh's `o`, which takes the rest of its cluster as the option name: `zsh -c -xoshwordsplit '…'`, `-coshwordsplit`, `-c -opipefail`;
- a bare `-` or `+` after `-c`, which 0.14.1 returned as the string: `bash -c - 'kill -1'`, `bash -c + '…'`. Bash now reads
  `-` as the end of the options and skips `+`; zsh ends the options at either;
- a bare `+` between a word that sets `-c` and a later `-c` (`bash -co pipefail + -c '…'`, `+c + -c`, `+c + -ec`, `+ec + -c`), which 0.14.0 refused;
- two zsh forms the issue did not list: `zsh -c1 '…'` (digits are ordinary option letters) and `zsh --emulate sh -c '…'`;
- a `-` that ends a zsh cluster, which ends the options: `zsh -c- '-x; kill -1'`, `+c-`, `-xc-`, `-c -x-`, `-c +-`.

Refuse-only: a grid of 6174 option forms, run under all four names, loosens nothing against 0.14.1's reader (a test
carries it). Deliberate false stops, in the README and pinned: a call whose two readings pick different words is refused if
either string is (`zsh -cO extglob 'kill -1'`, and `bash -cO 'ps aux' 'kill 123'` as lists-and-signals), though the shell
that runs it runs at most one of the strings, and often none. Known limit: `ksh`, `mksh`, `ash`, `busybox sh`, `yash`, `rbash` and `fish` are not read (#1116), and `sh` on a busybox ash host follows a grammar neither reading covers (ash accepts `-c-` and keeps reading options).
omp-roles is unchanged; its seat-mods floor stays 0.14.0.

## 0.14.1 — 2026-11-06

The kill rail reads shell option clusters whole (#1105). In `sh|bash|zsh|dash` options before or after
`-c`, a short cluster (`-x…`, `+x…`) now takes one following word for each `o` or `O` it holds, wherever the
letter sits, and a cluster that holds `c` sets `-c` (`+c` included: bash, dash and zsh read it as `-c`). So `bash -co pipefail 'kill -1'`, `-oc`, `-cO`,
`-Oc`, `-ecO`, `-Oe extglob -c`, `bash +c 'kill -1'` and `sh -oe pipefail -c 'kill -1'` are refused like `bash -c 'kill -1'`.
0.14.0 read only a cluster ending in `o` or `O`, and the cluster limit listed there is gone, so its entry
below understates what the rail reads now. The README drops that limit. A word that is not an option still
ends the options before `-c` (`bash -eo pipefail script.sh -c …` is not a shell string). omp-roles is
unchanged; its seat-mods floor stays 0.14.0.

## 0.14.0 — 2026-11-06

The kill rail (#1099). On 2026-11-05 an OMP orchestrator seat ran `kill $(ps -eo pid,args …)` to stop
one background job and signalled every process on the host. Neither seat kind had a rail for it, and
both returned before any check for the free roles.

- **A refusal for every role.** `killRule` in `hooks/rules.ts` runs before the free-role and invalid-role
  returns in `hooks/register.ts` and `omp/extension.ts`, so `orchestrator`, `coordinator`, unset, invalid,
  guarded and child agents are all covered. It refuses a call that both lists processes (`ps`, `pgrep`,
  `pidof`, `ls /proc`) and signals (`kill`, `xargs … kill`); `kill` with `-1`, `0` or a negative operand
  holding a `$`; `pkill`/`killall` by user, with no pattern, or with a pattern that matches every name of a
  fixed probe set; `killall5`; and `systemctl --user` `exit`/`isolate`/`kill`/`stop default.target` and
  `loginctl` `terminate-user`/`kill-user`/`terminate-session`/`kill-session`. A miss changes nothing: the
  call goes on to the role checks as before. The refusal says to list first, read the PIDs and kill by
  literal PID, and to stop one's own job with `write proc://<id>/kill` (OMP) or `TaskStop` (Claude Code).
- **Three closed transforms.** A literal `eval '…'` or `sh|bash|zsh|dash -c '…'` string is read once as a
  command; quotes are removed from the command word; and the rail skips `timeout`, `setsid`, `nice`,
  `ionice`, `stdbuf`, `chrt`, `taskset`, `flock` and `sudo` with its options. The shared `WRAPPERS` the
  git, gh and rm rules use is unchanged.
- **Claude Code `Monitor`** goes through the rail (its `command` field). On OMP the rail reads `bash`,
  `eval` string literals and an implementer's `debug` launch.
- **OMP: a guarded role may `write` an exact `proc://<id>/kill`**, the stop the refusal names. omp scopes a
  job or agent id to its owner; a service name is stopped project-wide, as `kill <pid>` through bash already allows.
- **The README's "Unguarded" row** for `orchestrator` and `coordinator` now reads "unguarded except the kill
  rail". A new section lists the known limits. Ambient coverage of a plain `omp` session is #1102.
- **What the rail reads, in detail.** A user option inside a `pkill`/`killall` cluster (`-fU`); `--` and shell
  options around `-c` (`bash -O extglob -c`, `bash -c -- '…'`, `eval -- '…'`); `time -p` and `builtin --`
  with their options; `-01`, `kill 00` and `kill -- -0` as `-1` and `0`; and a backtick in a negative operand.
  A substitution nested more than 8 deep, and an `xargs` chain more than 8 deep, are refused as unread.
  Words after an unquoted `$(…)` stay operands of the command (`kill 123 $(cat p) 0`); the span is bounded by
  counting parentheses, so a `case` pattern or a paren inside `${…}` is a known limit. `bash -euo pipefail -c`
  and `--rcfile`/`--init-file` are read (a cluster holding `c` with `o`/`O`, or an `o`/`O` not last, is not); `command -v NAME` passes. `pkill --help` and `--version` pass. The rail splits each command once (the second, 0.3.1 split cuts nowhere
  the first does not).
- omp-roles 0.11.0 raises its seat-mods floor to 0.14.0, and holds the orchestrator to it too (its own
  0.8.0 minimum had replaced the floor for that role).

## 0.13.0 — 2026-10-31

The status block's fields can run for several lines (#994). Each label starts a field, and the
field holds the lines up to the next label: bullets, a short table, numbered decisions. Labels stay
five and in order, and each needs content. The idle check reads each field's first line. Text
after a last field of `none` still fails; text after a decision or action no longer can, because
it reads as part of the field. On both hosts.

## 0.12.0 — 2026-10-28

The autonomic plugin is retired (#948). seat-mods read its session record for one feature only,
and that feature is gone.

- **The waiting-on-operator notice and bell (#873) are gone; they ran only in autopilot.** A
  manual session never showed them, so nothing a manual session sees changes. Removed:
  `noticeFor`, `ring` and `BELL_TIMEOUT_MS` on Claude Code; `operatorWaiting` and the notice
  field of the stop result on OMP; `waitingOnOperator`, `WAITING_NOTICE` and `hooks/redact.ts`;
  and the record reader (`autonomicPath`, `parseAutonomic`) in `hooks/records.ts`.
- **A plugin prompt is a status turn unless it is molt's `MOLT-HANDOFF:` request.** The one
  prompt the retired plugin submitted was the operator's own choice; nothing else submits it.
- **The OMP status entry still loads last, after molt.** Its `session_stop` blocks win as before.
- `tests/test-mod-shell-parity.sh` drops the bell and redactor pairs; the shell reader pair and
  the stage path copy stay.

## 0.11.1 — 2026-10-27

#933, the test and wording follow-ups from PR #932's review. No change in behaviour.

- **`tests/test-mod-shell-parity.sh` holds `moltStagePath` to molt's `stagePath`.** A path that
  drifted would silently stop the redo drop while molt hands off.
- **`run-tests.sh` fails when its `classic.*` check cannot read `hooks/`** (grep exit 2). It passed
  silently before.
- **The README lists 0.11.0's known limits** (`claude -p`, an unprobed Agent SDK host, molt's
  pause), which only the CHANGELOG held.
- Test 15 is split: a molt stage below `command` keeps the redo (15), and so does no stage file (15b).
- Comments: the OMP status entry says OMP's `session_stop` still blocks, and the redo turn is
  Claude Code's; a comment that cited the review now gives the reason.

## 0.11.0 — 2026-10-27

#929: the orchestrator status-block check works on org accounts. Claude Code skips a plugin's
`classic.*` hooks there, with no error, so the check on `classic.Stop` never ran and status turns
came back in any shape.

- **The check moved to `turn.complete`, with one redo turn.** A status turn whose reply misses the
  block (or idles, #876) ends as it is; seat-mods then submits one prompt with the failing reason,
  which starts once the turn is over. The redo is checked too; its miss stands, with the same
  warning line as before. This is the one path on every host, personal accounts included. The
  waiting-on-operator notice and bell (#873) fire only on the turn that stands, never on a reply
  whose redo is pending.
- **No redo on a turn that never answered**: an interrupted turn, an API error or a refusal.
  `classic.Stop` did not run on those either.
- **The redo is dropped when it arrives** if another prompt started a turn first, or if molt's
  stage file reads `command`, `block` or `fallback` (molt acts on that turn end, and its handoff
  wins, operator ruling 2026-10-27). The failed reply then stands: its warning, and its
  waiting-on-operator notice and bell (#873), come as toasts. A redo that arrives in another
  session (a `/clear` or a molt) is dropped with no toast. Each redo answers the failed turn that
  submitted it, oldest first; a seat-mods prompt with none waiting (a reloaded module) is dropped,
  never run as a status turn of its own.
- **molt's handoff requests are operator turns**, like autonomic's prompts: each asks for a
  `MOLT-HANDOFF:` line, so it gets no status-block context. molt's seed stays a status turn.
- **`run-tests.sh` refuses a `classic.*` hook registration** in `hooks/`.
- Known limits: under `claude -p` the printed result is the redo's reply, not the first one; an
  Agent SDK host was not probed; a block raised by a `classic.Stop` hook beneath seat-mods is no
  longer seen; while molt is paused, or after a child or an SDK root handed off, molt's stage file
  still reads `command` or later, so every redo in that session is dropped and only the toasts
  show; a molt seed edited to carry a `MOLT-HANDOFF:` line is read as a request.

## 0.10.0 — 2026-10-26

Batch 5 (#724, #702): fewer false stops on honest work, and the hiding spellings that can be closed
without a new one. seat-mods is still a rail that only adds a stop; what it misses goes to the next
judge as before.

- **A guarded seat may write and remove below `/tmp` and `$TMPDIR`.** Six of the nine refusals in
  real baton runs were scratch files in `/tmp`. Every guarded role, reviewers included, may Edit,
  Write and `rm` descendants of `/tmp` and of an absolute `$TMPDIR`, read from the seat's own
  environment on both hosts; a symlinked `/tmp` counts by both spellings. The directory itself and
  its ancestors stay protected from `rm`, and `rm -rf /tmp/*` is allowed: the accepted cost is that
  a seat can remove another session's scratch files. A scratch directory that holds the seat's own
  worktree is not added for that seat (an allowed directory outranks the worktree), so it keeps its
  refusals there; its other scratch places still apply. Other seats' trees under a broad `$TMPDIR`
  become writable, as `SEAT_MODS_ALLOW` would make them.
- **`rm` follows a literal `cd` and literal variables in the same call.** `cd /w/wt && rm -rf
  pf/__pycache__` and `WT=/w/wt; cd "$WT" && rm -rf pf/__pycache__` are placed instead of refused;
  `cd "$WT" && rm …` with no `WT=` earlier in the call is still unresolved. A `cd` before `;` or a
  newline may fail, so the rm after it is checked in every directory it may run in; a variable stays
  known only across literal assignments, a literal `cd` and a bare `rm`. A `cd` in a subshell, an
  `if`, after `||` or in a pipeline, `cd -`, `cd ..`, `pushd`, `popd`, a `cd` before a Bash 5.3
  funsub and every other directory change stay unresolved, as before.
  A `CDPATH`, a `cd` alias, a shell-snapshot function that changes directory (zoxide's `z`) and
  zsh's `cd` are not modelled.
- **Commands inside `$(…)` and backticks are read** (C1), unquoted, in double quotes, on a heredoc
  opener line and in an unquoted heredoc body, on every rail including the `rm` and `-F` readers.
  `git commit -m "$(git push --force)"` and ``git commit -m `git push --force` `` are denied.
  A command nested more than 8 substitutions deep is refused, reported as `no force-push`: an
  accepted false stop no honest command reaches.
- **Heredocs are read closer to the way Bash reads them** (C2). The tail of an opener line is read
  (`cat <<EOF; git push --force`), a delimiter is its word after quote removal (`<<\EOF`,
  `<<E'OF'`, `<<"E"OF`), several heredocs on a line close in order, a body line ending in a
  backslash joins the next only in an unquoted body, and a `<<` in `$((…))`, `((…))` or a comment
  opens none. Inside a `$(…)` a heredoc also closes, as in Bash 5.3, at a line that starts with its
  delimiter and holds a `)` after it, so `git commit -m "$(cat <<'EOF' … EOF)" && git push --force`
  is denied. `<<E'OF'` with a body line `E` was a false stop and is allowed.
- **The command word and glued redirections are read** (C3, C4): `\rm -rf …`, `\git push --force`,
  `{log}>f rm -rf …` and `git push --force>&2` (also `&>f`, `-f>/dev/null`) are denied.
- **On OMP, an `rm` operand with a leading `@` or `:` is placed both ways.** omp reads `@/tmp/x` as
  `/tmp/x`, but the shell removes `<cwd>/@/tmp/x`, in the worktree; both places must be allowed, so a
  reviewer is refused it.
- **Deny texts.** The rm and write denials name the scratch places beside the worktree and
  `SEAT_MODS_ALLOW`, and the advice for an unreadable operand says what the guard reads now.
- **Shared reader.** `COMMANDS`, `HEREDOC`, `QUOTED`, `WRAPPERS`, `blankHeredocs`,
  `substitutionSpans`, `blank`, `commandOf`, `tokensOf`, `gitOf`, `substitutionsOf` and
  `SUBSTITUTION_TOO_DEEP` are copied byte for byte into molt 0.3.8's `hooks/shell.ts`, held by
  `tests/test-mod-shell-parity.sh`.
- **Still limits, now written down in the README.** A ruled command after a substitution on a
  heredoc opener line stays hidden, as in 0.9.0 (an `rm` there is still read); so do a `$'EOF'`
  delimiter, a `<<` inside an unquoted `$[…]` or a `${…}` (it opens a heredoc for the reader), a
  `#` after a blank in a quoted string inside `"$(…)"`, a command in a Bash 5.3 funsub, a quoted
  command word (`"rm" …`), a subscripted prefix (`A[0]=1 rm …`), a closing line `EOF)` in a `$(`
  opened before a newline outside quotes or before an earlier heredoc's body, a backslash-newline
  inside a word and the spans whose end the reader loses. C5 (a `&` inside a word) and C6
  (function bodies and syntax errors) still read wrongly toward a false stop. C8 (a partly quoted
  tilde, `rm ~""/scratch/x`) is a false stop too, but for a reviewer whose `SEAT_MODS_ALLOW` holds
  `$HOME/scratch` it passes while Bash removes `<cwd>/~/scratch/x`.

## 0.9.0 — 2026-10-20

- **The orchestrator's waiting-on-operator line rings the bell** (#873, design
  2026-10-20-873-turn-end-judge-removal-design.md §5.2). When a status turn ends with a block
  whose `Waiting on operator:` field reads `decision:` or `action:` — whether the block passed or
  was let through after its one rewrite — and autonomic's session record says `mode: autopilot`,
  seat-mods rings that record's `bell` and shows `seat-mods: waiting on operator — <text>`. On
  Claude Code the line follows the reply (and any warning) at `turn.complete`; on OMP it is
  `ctx.ui.notify(notice, 'info')`. The text is redacted by a copy of autonomic's `redact` (pinned
  byte-identical), cut to one line and 200 characters. The signal only adds a notification: it
  never approves, answers or blocks, a failing or slow bell is logged and never holds the turn,
  and `none`, a manual session, no record, a molt handoff and a non-orchestrator role are quiet.
  `hooks/records.ts` copies molt's `autonomicPath`/`parseAutonomic`, and `hooks/register.ts` copies
  molt's `BELL_TIMEOUT_MS` and `ring`; `tests/test-mod-shell-parity.sh` pins all four pairs.

## 0.8.0 — 2026-10-19

- **The status-block check runs on OMP** (AI spec 2026-10-19-omp-status-block-port-design.md). A
  second OMP entry, `omp/status-extension.ts`, gives an OMP orchestrator the Claude Code status
  check: a status turn whose reply is not the five-field block gets one block, a block that waits on
  nothing while Next steps names work gets the idle block, and a second miss in the same turn goes
  through with an OMP warning notification. It reuses `hooks/status.ts` for every check and string.
  OMP's `input` cannot tell typing from a herdr send, so a turn is status by its crew tag, or when no
  input started it. It is a separate entry because OMP stops `session_stop` and `tool_call` at the
  first block in load order: `omp-seat` (omp-roles 0.8.0) keeps the guard first and loads this entry
  last, for the orchestrator only, so molt's and autonomic's stop blocks win as on Claude Code.

## 0.7.0 — 2026-10-19

- **The status block waits on the operator, and a blank line between fields is fine** (#879). The
  fifth field is `Waiting on operator:` (was `Operator decision pending:`), taking `none`,
  `decision: <question>` or `action: <what the operator must do>` — an action only the operator
  can take (start a fresh session, /clear, a login) now has a spelling, as a decision did. It is
  the block's second wait field beside `Waiting on (seats live):`, so the idle-stop contradiction
  (#876) reads both as before. A blank (whitespace-only) line between fields no longer fails the
  block as out of order: the five labels still come in order, one field per line, nothing before
  the first label and no non-blank line after the fifth, and the trailing-text failure names the
  new label. `checkBlock` and `isIdleStop` now read the fields through one shared reader. The
  context line teaches the new field, its forms and the blank-line allowance, and the idle copy's
  last sentence becomes "Do the next step now, or name the seat, wake, or operator decision or
  action you wait on."

## 0.6.0 — 2026-10-18

- **A status block that says nothing waits no longer ends the turn** (#876). On a status turn of
  an orchestrator, a block `checkBlock` accepts is also read for the idle-stop contradiction:
  Waiting on (seats live) and Operator decision pending both read `none` (content starting with
  the word `none`, any case) while Next steps names work. The first stop is blocked once with
  `seat-mods (orchestrator): the status block says nothing waits, but Next steps names work. Do
  the next step now, or name the seat, wake or decision you wait on.`; the second lets the stop
  through and adds `⚠ seat-mods: status block says nothing waits, but Next steps names work.`
  under the reply. The one block per turn is shared with the shape check in either order: a turn
  nudged for idling gets no later shape rewrite, and a spent shape rewrite leaves the idle check
  warning only. The turn record now carries `warning` — the line of the failure that stood at the
  last stop — instead of `failedAfterRewrite`, and `STATUS_CONTEXT` gains one sentence teaching
  the rule. A finished run (all three fields `none`) ends the turn untouched; the molt exemption,
  the beneath-block rule and every role other than an orchestrator are unchanged.

## 0.5.0 — 2026-10-18

- **A status turn of an orchestrator ends with only the five-field status block** (#867). A status
  turn is one the operator did not start by typing; the block is `What I ruled:` / `What the PR(s)
  will carry:` / `Next steps:` / `Waiting on (seats live):` / `Operator decision pending:`, one
  field per line, each label bold or plain and followed on the same line by its content.
  - `prompt.submit` classifies the turn and, on a status turn, adds one line of model-only context
    (tool calls only, then the block). A prompt the operator types into a running status turn makes
    that turn free; a queued prompt (`ctrl+x enter`, `wait: true`) waits for a later turn and
    leaves the status turn alone.
  - `classic.Stop` checks `last_assistant_message` and blocks **once per turn** with a reason
    naming what failed; a second miss lets the stop through, and `turn.complete` then shows
    `⚠ seat-mods: status block missing — this status reply is not in the required form.` A block
    beneath seat-mods (autonomic's push) passes unchanged and is not seat-mods' rewrite; a
    subagent's `turn.complete` is ignored, and a turn ending on molt's `MOLT-HANDOFF:` is exempt.
  - Crew tags (`[crew report|molt|message <role>]`), the legacy ping forms (`REPORT READY: `,
    `MOLT WARNING `) and the two rotation resume forms count as status turns. The check calls no
    model; coordinator, guarded and unset roles are untouched.
  - **Known limit:** an operator prompt starting with `REPORT READY: ` is held to the block.
  - Claude Code only; the OMP extension is unchanged.

## 0.4.6 — 2026-10-18

- **Naming: the orchestrator's deny text and every launcher reference say `crew`** (crew 0.3.0's
  rename, spec §4.6). The rail's message now reads `seat-mods (orchestrator): no subagents —
  dispatch a crew seat instead (crew orchestrate; #798).`; the shared-rules comment and the
  README's rollout lines follow. No guard, profile or write-placement behaviour changes.

## 0.4.5 — 2026-10-17

- **Scratch work costs one turn, not several** (#844). A friction review of 88 OMP sessions found 12 write denials
  and 8 rm denials on scratch work.
  - OMP: a guarded seat may `write` an exact `local://<name>` file (letters, digits, `.`, `_`, `-` and `/`, no `.`
    or `..` segment). That is omp's per-session scratch, which omp itself confines: it refuses absolute paths and
    `..`, and checks real-path containment under the session's local root. Every other `local://` spelling, and
    every other tool, still places a scheme outside.
  - `/tmp` and `xd://report_issue` stay denied. A write denied outside now names the `SEAT_MODS_ALLOW` folders as
    the place for scratch files such as a commit message.
  - An `rm` operand the guard cannot read (`$VAR`, `` `…` ``, `{…}`, a relative path after `cd`) gets its own deny
    text, which says to spell the path out literally. The rail still does not resolve shell variables.

## 0.4.4

- **OMP: no subagents from an orchestrator** (#798). Under `SEAT_MODS_ROLE=orchestrator` the omp guard blocks the `task` tool and every `before_subagent_spawn` (eval `agent()`, workpool). Other tools stay free; coordinator and every guarded role are unchanged. The Claude Code hook is unchanged.

## 0.4.3 — 2026-10-14

- **OMP device transport** (#780). Only `write xd://lsp`, `xd://ast_grep` and `xd://github` are checked
  as the inner tool's own call, giving guarded seats their reads and docs. Parsed args with `[` or `.`
  in any key at any depth are denied before dispatch. Transported github `forceWithLease` and `force`
  flags add the force-push rule whenever present with a value other than JSON `false`; direct calls
  are unchanged. Other tools stay denied through `xd://` by outside-write placement. Malformed
  payloads fail closed; `xd://resolve` and `xd://reject` keep their preview-confirmation behaviour.

## 0.4.2 — 2026-10-14

- **The rm rail follows a link before the `..` after it** (#781). Claude Code's path resolve collapses `..` before it
  follows a symlink, so `rm -f <worktree>/link/../x` was placed inside the worktree while the kernel removed `x`
  beside the link's target. Probed live: a guarded implementer removed a file outside its worktree this way. The rm
  rail now walks such a path part by part, as the OMP guard does since 0.4.0 (#762); a `..` above a folder that does
  not exist stays unresolvable and is denied. Write and Edit are unchanged: those tools collapse `..` themselves, so
  the guard's placement already matches where they write.

## 0.4.1 — 2026-10-13

- Map OMP's `seat-reviewer` child to the reviewer profile, confining its write tool to
  `SEAT_MODS_ALLOW`. Keep the bundled `reviewer` and `scout` mappings.

## 0.4.0 — 2026-10-12

- **OMP guard.** `omp/extension.ts` applies the shared rules (`hooks/rules.ts`) to OMP's
  `tool_call`: `bash`, `write`, `edit`, `ast_edit` and `eval`, in the main session and in `task`
  children. A child is read by agent name: `reviewer` and `scout` get the reviewer rails; `implementer`,
  `task` and any other name get the verifier rails (no commit, push or PR). It loads only through
  `omp-roles`' `omp-seat`. Helper calls inside `eval` are a known limit. The Claude hooks module is
  unchanged.
  A child may not spawn: the `task` tool, eval `agent()` and workpool workers are all blocked
  (`before_subagent_spawn`).
  **An allow list, not a block list.** Under guarded rails a tool call passes only if its name is in
  `GUARDED_TOOLS`, which sorts every tool omp 18.8.9 can expose (its built-in and hidden registries, the edit
  tool's `apply_patch` wire name, and the tools outside them); any other name — `browser`, `computer`,
  `checkpoint`, memory and skill tools, an MCP or extension tool, a tool a later omp adds — is denied with
  one generic message. `ask`, `goal` and `task` are the top-level session's only. `lsp` passes omp's read-only
  actions only, for every guarded role. `github` passes omp's read-only ops; `pr_create` and `pr_push`
  follow the PR and push rails, `pr_checkout` (a worktree and branch outside, `force` resets one) and any
  other op are denied, and `forceWithLease` is a force-push. `debug` runs a program, so only an implementer
  may use it, its launch read like `eval`; a reviewer may not run `eval` either.
  `edit` is placed by every destination it names (`rename`, `edits[]`, hashline `MV`), and
  `bash` rm operands and `-F` files resolve against the call's own `cwd`. omp's advisor and `/tan` clones
  report `kind: "sub"`, so they get the verifier rails even under a coordinator.
  A write target carrying a URL scheme (`local://`, `vault://`, `ssh://`, `xd://<device>`, also `local:/x` and
  `dir/local://x`) is outside under guarded rails, because omp routes it to a host file the worktree check cannot see;
  only `write xd://resolve` and `xd://reject`, which apply or discard an `ast_edit` preview already checked, pass.
  **One omp path reading.** Every write-class target and a `bash` `cwd` go through one normaliser that mirrors
  omp's `expandPath`/`resolveToCwd`: a leading `:`, `@` before `/abs` or `~`, unicode spaces, `file://`, `~`,
  `~/x` and `~user`; a target is also read with write.ts's `[path#HHHH]` header unwrap and the hashline
  quote/tag strip, and an `ast_edit` scope split on `,` `;` and whitespace and placed by its glob's literal
  folder, the strictest reading winning. A `bash` or `debug` `cwd` that is an omp URL (`local://scratch`) is
  outside: `rm` there is denied and a `-F` file there cannot be checked. `rm` operands and `git commit -F` files
  take the same reading in its shell form: a `scheme:/` operand (`rm local://x`) is outside, because omp's
  embedded coreutils route it to the backing file; a `-F` file with a scheme cannot be checked; an unquoted
  `-F ~/msg` is read from HOME (and, since the quotes are not reported, also literally).
  **Known limit:** the guard reads omp's path dialect only as far as listed here. omp's other selectors
  (a SQLite `file.sqlite:table:row`, and any later one) are read as plain paths, so a selector through a
  symlink that points outside the worktree is not caught — the same reach bash writes already have.

## 0.3.2 — 2026-10-09

- **A lone `&` is a command boundary on every `COMMANDS`-split rail** (#723, a fail-open
  guard bypass). `COMMANDS` lacked Bash's background list separator, so `true & git push
  --force`, `echo & git commit -m "…Co-Authored-By: …"` and a `gh pr merge` behind `&` read
  as one command under the first head, and push, force-push, merge, AI-trailer and the
  commit-message reader never saw the second command. `COMMANDS` now splits on a lone `&` —
  the `&` of a `|&` pipe included — while `&&` and the redirections that carry `&`
  (`2>&1`, `>&2`, `&>`, `&>>`, `<&0`, `>&-`) are not boundaries, so the forms the previous
  release allowed keep their rules. Every rail that splits on `COMMANDS` now reads the
  command twice — the shared `COMMANDS` with the expansion mask, and the seat-mods-v0.3.1
  separator with no mask — and denies on the **union** of the two rule sets (and of the two
  `-F` file sets): by construction the rails see everything the previous release saw, plus a
  command after a lone `&`, and the only denies the union adds are the 0.3.1 reading's own.
  The mask itself is narrow: an `&` inside an unquoted `${…}` or `$[…]` expansion is masked
  only when it is a lone `&`, so `(`, `)`, `;` and `|` inside an expansion keep their
  `COMMANDS` meaning, a nested `$(…)` stays executable (`echo ${x:-$(git push --force)}`
  reads `push`, `force-push`), the `&` of a `$(…)` still splits, `$$` is read as one token,
  and an unterminated expansion masks nothing (the split stays, fail closed).
  `X=${x/a&b/c} git push --force` meets its rails as the previous release read it. molt is
  unchanged: its gate reads the shared split once, with no union. The `rm` rail's own split
  is a second spelling of `&` in `rules.ts`: change one and check the others. Known limits
  (#724): an `&` on a heredoc opener line is still swallowed with the heredoc body, a `&&`
  inside an expansion and a backtick substitution inside an expansion keep the previous
  release's reading, and whitespace inside an expansion behind `VAR=` can hide the command.
  The `rm` rail is otherwise unchanged: it already split on `&`.
- Mirrored byte-identically into `molt/hooks/shell.ts` under the shared-reader parity
  contract; `molt` 0.2.5 drops its interim `LONE_AMP` split.

## 0.3.1 — 2026-10-09

- Every Bash rail now walks the reserved head words already recognised by `rm`, so
  `if git push --force`, `! gh pr merge` and commits behind those heads meet the
  same role and AI-trailer checks as a bare command (#701). Shared parser declarations
  remain unchanged; no new shell forms are parsed. Reserved words are recognised only
  as exact unquoted command heads, so executable paths such as `/tools/if` and head-name
  programs after assignments or execution wrappers remain allowed.
- Heredoc bodies and closing lines supplied to `rm`, including fd-prefixed input
  such as `2<<EOF`, are excluded from operands. Words and redirections after the
  delimiter on the opener line remain part of the command: inside operands are
  allowed and outside operands denied, including after an adjacent redirection.
  Attached operands (`x<<EOF`) retain their checks; non-rm heredocs are unchanged
  (#702 item 1).
- Add molt regression pins for herestrings and path-qualified wrappers, without
  changing molt source or version (#702 item 4). Add allowed controls in the same
  `//`, `/.` and `/..` spellings beside writable-root denial tests (#702 item 5).
- #702 items 2 and 3 and its comment-thread parser limits remain open under the
  PR #644 rule: the matcher grows only for a form that ran in practice.

## 0.3.0 — 2026-10-08

- Guarded sessions are denied an `rm` the rail recognises when operands are outside their
  writable places. Implementers,
  verifiers and the unmarked default may remove things inside their worktree and `SEAT_MODS_ALLOW`;
  reviewers may remove things only inside `SEAT_MODS_ALLOW`. Every recognised operand is checked, including
  `-`-prefixed operands after `--`. Writable roots and their ancestors are protected.
- Unresolvable operands are denied, including `rm -rf "$OLDPWD"`, variables, parameter and command
  substitutions, and `~user`. Single-quoted operands are literal; `~` and `~/...` use HOME. Globs
  are placed by their literal prefix directory, so `rm -f /tmp/tmp.*` is denied. Parent symlinks
  resolve, while a terminal symlink is removed literally unless followed by `/`.
- Relative operands use the live `$.session.cwd()` (measured on Claude Code 2.1.294, 2026-10-08;
  see README). Known limit: an earlier recognised `cd`, `pushd` or `popd` in the same Bash call makes a relative
  operand unresolvable even if the change fails. Existing live-cwd worktree detection is unchanged.
- Known limits: `rmdir`, `unlink`, `find -delete`, `git rm`, `git clean`, `xargs rm`, `bash -c '...'`, `mv` over
  a file, and other Bash writes (`cat >`, `sed -i`) remain outside the rail. This is an `rm` matcher
  for mistakes, not precise shell parsing or an adversary boundary. Free roles remain unguarded;
  Bash tool calls from subagents meet the same rail.

- Review round 1: unquoted braces, glob suffix parent traversal and globs above writable roots
  fail closed. Redirections are excluded from operands; single `&`, reserved head words and
  `builtin` are recognised; `builtin cd` and `\cd` affect same-call relative operands. Parsing or
  resolution exceptions deny the Bash call, with self-reference/depth protection for markers.
- Backticks and quoted `$(rm …)` can escape recognition; bare `$(rm …)` is checked by the parentheses splitter.
- A glob component starting with `.` and containing `*`, `?` or `[` is unresolvable and denied.
- Shell options changed in the same call (`shopt`, e.g. `extglob`, `dotglob`, `nullglob`) are not modelled beyond the `**` and dot-component denials.
- `**` in an rm glob operand is unresolvable and denies; quoted literal `**` stays literal.
- An unexecuted shell function body (`cleanup() { rm …; }`) is checked as if it runs and may deny.
- A heredoc given as rm's input (`rm -i x <<EOF`) is read as an extra operand and denied.
- A named descriptor before the command (`{log}>file rm …`) hides the rm.
- One-word runners beyond the recognised wrappers (`timeout`, `nice`, `stdbuf`, `setsid`, `xargs`) can hide `rm`.
- A double-quoted `<<`, or commands after a heredoc opener or a `#` comment on the same line, can hide commands from the rail.
- Paths changed earlier in the same call (`ln -s`, `mv`, `mkdir` before `rm`) are checked against the filesystem as it stands before the call runs.
- Glob matches are not enumerated: a matched parent symlink can lead outside writable places, as in `rm -rf <worktree>/*/node_modules`.
- `$` outside literal quoting/escaping and leading `~+`/`~-` are unresolvable, even when Bash could resolve them.
- Quoted command names such as `"cd"` are not recognised as directory changes.
- `POSIXLY_CORRECT` operand ordering and a backslash-newline inside double quotes are not modelled.

- Review round 2: the existing redirect list includes `<>`, `&>>`, fd duplication/closure and
  `<<<`; herestrings no longer open heredocs. Path-qualified wrappers are recognised, a root
  worktree contains absolute descendants, and unchecked Bash commands get a Bash-specific deny.

## 0.2.1 — 2026-10-05

Docs only — no code change.

- The rollout guidance now names `herdr-crew` 0.2.7, which marks the two free roles
  (`orchestrator` and `coordinator`) at launch; `paseo-crew`, `orca-crew` and `dsh-crew`
  do not set `SEAT_MODS_ROLE` yet.
- New README section "Without an orchestrator plugin": with none installed you are the
  launcher — worked aliases and functions for the unguarded and guarded roles, and the
  note that a launcher writing `orchestrator` or `coordinator` needs seat-mods 0.2.0 or
  later.
- The README's `claude-review()` example now sets `SEAT_MODS_ALLOW`, because a reviewer
  may write only in those directories, and the `SEAT_MODS_ALLOW` table row says so for
  the reviewer profile.

## 0.2.0 — 2026-10-04

- **BREAKING** for unmarked sessions: `SEAT_MODS_ROLE` unset or empty no longer disables the mod —
  the session is guarded as an `implementer` by default, so a forgotten launcher export fails
  closed, and the status line reads `seat: implementer (default: SEAT_MODS_ROLE unset or empty)`.
  Two explicit unguarded roles are added: `orchestrator` (the top orchestrator, or any session
  started to drive work) and `coordinator` (spine, close, work-PR and doctor sessions, lane
  drivers); `implementer`, `verifier` and `reviewer` are unchanged, and any other value still
  denies every tool call. Do not install until every launcher you use — and your own interactive
  sessions — marks its free sessions: a later `herdr-crew` release will; `paseo-crew`,
  `orca-crew` and `dsh-crew` do not set `SEAT_MODS_ROLE` yet; set `SEAT_MODS_ROLE=orchestrator`
  yourself, e.g. in your launch alias. Until then a coordinator or a bare `claude` session starts
  guarded as an implementer and cannot merge. A default-guarded session writes only inside the
  worktree — outside a git repository, its working directory — and the `SEAT_MODS_ALLOW`
  directories, so Claude Code's own writes outside them (memory files, plan files) are denied;
  a default-guarded session is a worker, and an operator session marks itself `orchestrator`.

## 0.1.0 — 2026-10-03

- First release. `tool.call` guards per role (implementer, verifier, reviewer), turned on by
  `SEAT_MODS_ROLE` and inert without it; any other value denies every tool call. Writes are checked
  against the worktree and the `SEAT_MODS_ALLOW` directories. A commit message file given by `-F` is
  read for AI trailers. Quoted strings and heredoc bodies are text, not commands, and only a
  segment's command word decides what it runs. The Bash rails are a best-effort match on common
  spellings, not a shell parser; a dangling symbolic link is never written through. A Write into new
  folders is placed by its nearest existing folder.

Claude Code only (2.1.287+). Not on Codex, Devin or in the OpenCode bundle.
