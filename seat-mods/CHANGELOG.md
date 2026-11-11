# Changelog

All notable changes to the `seat-mods` plugin.

## 0.16.0 — 2026-11-11

The kill rail's last reading (#1191, #1193). A by-pattern signal whose pattern has no literal part, and a `pkill -f` pattern that matches a plain command line, went to the model as if the rail were absent: `pkill "$NAME"`, `pkill -f "$NAME"` and `killall -r "$NAME"` with the variable gone (a variable set in one tool call is gone in the next) match every process, and `pkill -f /` nearly every one (123 of 152 on this host) (an empty pattern matched all 155 of the user's processes on procps-ng 4.0.4). After this release the rail reads nothing new.

- Fixed: a `pkill` or `killall -r` pattern that holds an expansion and has fewer than three letters or digits spelled out beside it is refused, with the negative operand's reason: empty, it matches every process. An expansion is a `$` word, a `${…}`, `$[…]`, `$((…))` or `$(…)` span, a backtick span and `$$`; `'…'` and `$'…'` are literal. So `pkill "$NAME"`, `pkill -f "$NAME"`, `pkill "$A$B"`, `pkill "${NAME:-}"`, `pkill "$(cat f)"`, `pkill $NAME`, `pkill "ab$NAME"` and `killall -r "$NAME"` are refused, under a wrapper, `xargs` or a `-c` string too; `pkill -f "node $SCRIPT"`, `pkill -f "$DIR/server.js"`, `pkill "abc$NAME"` and `pkill '$NAME'` pass. A `pgrep`-fed signal (`kill $(pgrep "$X")`, `pgrep "$X" | xargs kill`) was already refused as a call that lists and signals.
- Fixed: a `pkill -f` (`--full`) pattern is also tested against one command line, a line's punctuation alone (`/ --`, a path's slash, a blank and an option's dashes). A pattern that matches it needs no letter or digit, so it can match a command line by its punctuation alone, the user manager's (`/usr/lib/systemd/systemd --user`, whose end took the session down in #1099) among them: `pkill -f /`, `pkill -f ' '`, `pkill -f -- --` and `pkill -fx '\S+ \S+'` are refused; `pkill -f 'node server.js'`, `pkill -f systemd`, `pkill -fx /` and `pkill /` pass. The probe is no longer than the longest name, `systemd` (the user manager's whole line cost up to a second per backtracking pattern in bun's regular expressions). The pattern is the user's own regular expression, so one built to backtrack costs time against the probe as it does against the names: a known limit.
- Changed: the stop line (operator ruling, 2026-11-10). The rail stops the incident's kind in its plain spellings, and reads nothing new; a later miss changes it only if a seat could type it by accident (no quoting or encoding of the command word, no construct absent from real session logs, and a default or forgotten value makes it signal widely). The README's Known limits are one flat "not read, by design" list, each item but the first pinned by `tests/kill.test.ts`; the rail's README section went from 7,567 to 7,565 words, its Known limits from 1,328 words to 1,102 with the stop line. The group-0 rule (`kill 0`) stays: it is a false stop on Claude Code, whose Bash tool shell leads its own process group, and it protects OMP, whose bash tool runs inside the omp process and shares its group (#1193).
- Deliberate false stops: the pattern test counts nothing inside an expansion, a default value included (except a double-quoted one inside a double-quoted `${…}`, which is read as literal: `pkill "${NAME:-"xyz"}"` passes), and reads a lone `$` as one, since an unquoted `$(…)` is read as `$` and the letters after it as a name: `pkill "${NAME:-xyz}"`, `pkill "${A:-${B}x}yz"`, `pkill -x ab$`, `pkill "^go$"`, `pkill $"ab"`, `pkill $(cat f)abc`. A variable set earlier in the same call is not read: `PORT=3000; pkill -f ":$PORT"`. A `-f` pattern anchored to the line probe's shape: `pkill -fx '/ --'`. A value with an expansion after `-O`, `-r`, `-q` or `--cgroup`, read as the pattern: `pkill -O "$AGE" node`. `kill 0` on Claude Code. `{ echo ${x:-(a b)} kill -1; }` joins the `${…}` family's examples (PR #1190 round 2, C18).
- Known limits, new on the list (each a `LIMITS` row): a shell fed commands another way (`echo 'kill -1' | sh`, `sh <<< '…'`, `. <(…)`, `eval "$(…)"`); wrappers not in the list (`strace`, `chroot`, `unbuffer`, `gtimeout`, `caffeinate`, `rtk`, `nsenter`, `setpriv`, `prlimit`, `systemd-inhibit`); a command word from another expansion (`$(echo kill) -1`, `/bin/kil? -1`, `${x:-kill} -1`), zsh's `=kill -1`, and another case on a case-insensitive file system (`KILL -1`); an operand after a `(`, `)` or `|` inside a word (`kill 123 <(true) -1`, `kill 123 >| f -1`); an operand's default value (`kill -9 ${x:--1}`); `pkill` criteria `--older`, `-r`, `--env`, `--cgroup`, `--inverse`, `killall -g`, macOS `killall -m`, and the value of `-O`, `-r`, `-q` or `--cgroup` read as the pattern (`pkill -O 10 "$X"`); `--full` abbreviated (`pkill --fu /`); `skill` and `snice`; listers outside the four, which are four by decision (`lsof -t`, `pstree`, `top`, `jobs -p`, `/proc/[0-9]*`, `cgroup.procs`); other ends of the session (`systemctl --user start exit.target`, `stop --all`, `poweroff`, `loginctl terminate-seat`, `busctl … Exit`); a `${…}` with a blank inside a redirection word in a zsh group closed by a glued `}` (`{ echo a <<<${x:-a b}; kill -1}`, PR #1190 round 2, C17); a `killall` name without `-r` held in a variable; and a bash 5.3 funsub (`echo "${ kill -1; }"`, #925). `for x do kill -1; done` was already a row. Not a verdict, and with no row: a `-f` pattern built to backtrack (`(\W?){200}\d`) can take seconds against the five probe strings, as against the names before.
- Migration: a by-pattern signal with no literal part is now refused; spell part of the pattern out. No form the rail refused is now allowed. Of the 566 distinct shell calls with a signalling word in this host's session logs outside the rail's own projects, none changes verdict, and none of their 47 `pkill` patterns is newly refused.
- Tests: 32 refused rows with a near-miss control each (two of them the known-limit rows `pkill "$PATTERN"` and `pkill "$(cat /tmp/name)"`; five hold NUL-delimited text that is not a marker, or a second reference to one piece), and new controls for `pkill $(cat /tmp/name)` and `killall -r $(cat /tmp/name)`; 18 allowed controls; 12 deliberate false stops with their controls (`kill 0` and C18's form among them, both refused before); 16 known-limit rows, and the two that became refused rows removed; one bounds test: 2,000 forged or repeated markers in a pattern finish under 100 ms.

## 0.15.8 — 2026-11-10

The kill rail reads zsh's brace grammar (#1170): a `{` glued to a head word, a `}` glued to a word's end, the short `if`, `while` and `until` forms, `always` blocks and anonymous functions; and a reserved word after a compound command's close in bash, dash and zsh. `{kill -1}`, `repeat 1 {kill -1}`, `if [[ 1 ]] kill -1`, `while [[ 1 ]] { kill -1; break }`, `{ true } always { kill -1 }`, `function { kill -1 }`, `{ kill -1}` (zsh) and `if { true; } then kill -1; fi`, `if false; then { true; } else kill -1; fi` (bash, dash and zsh) went to the model as if the rail were absent. zsh 5.9, bash 5.3, dash and fish 4.2.1 were probed with harmless stand-ins on a class map of 682 forms: 419 of them run in some shell, and the rail missed 301 of those. It now misses 27, each a known limit or another class (below).

- Fixed: zsh's brace grammar is read beside the reading before, in one pass over a command's words. A `{` glued to a head word opens a group, at a segment's start and after a head word, `repeat`'s count, `time`, a close or `always` (`{kill -1}`, `true;{kill -1}`, `! {kill -1}`, `time {kill -1}`, `(){kill -1}`, `for x (1) {kill -1}`, `case x { x) {kill -1} }`, `echo $({kill -1})`), and so do a sole `{` among a command's words and a `{` glued to the word right after `case WORD` or `coproc` (#1189; `time` is taken off before `case`), so the `}` of a `case x {`, a named function's body or a `coproc {` closes that group and not the one around it (`case x { x) kill -1}`, `case x {x) kill -1}`, `time case x {x) kill -1}`, `if case x {x) true } then kill -1; fi`, `{ function f { true; }; kill -1}`, `{ coproc { true; }; kill -1}`, `{ coproc {true; }; kill -1}`); `echo {x; kill -1}` and `echo {a,b}` stay words. A sole `}`, or one glued to a word's end that closes no `{` of the word's own, closes a group while one is open, counted over the command's segments (`{ kill -1}`, `{ true; kill -1}`); `${X}`, `{a,b}`, `kill -1}` and `echo } kill -1`, where no group is open, stay words. A `}` that closes a `${` the reader split at a blank, `;` or parenthesis closes no group, so `{ echo ${X:-a b} kill -1; }` and `f() { echo ${1:-no pid} kill -1; }; f` pass, where every shell runs `echo`, and `{ echo ${(U)x}; kill -1}` and `{ echo ${x:-a b}; kill -1}` are refused, where zsh runs the kill. The words after a `]]` or a group's `}` are read as a command (the short `if [[ 1 ]] kill -1`, `until [[ -z 1 ]] kill -1`, `while [[ 1 ]] { kill -1; break }`, `if { true } kill -1`, `if [[ -z 1 ]] { true } else { kill -1 }`), and so are those after an `always` between a group's `}` and a `{` (`{ true } always { kill -1 }`, `{true} always {kill -1}`). `function`, then at most one `-T` and then at most one `--`, then a `{` is an anonymous function, which zsh runs at once (`function { kill -1 }`, `function -T { kill -1 }`, `function -- { kill -1 }`, `function -T -- { kill -1 }`, `repeat 1 function { kill -1 }`). A named function is defined, not run, so `function f { kill -1 }` and `function f { kill -1}` pass, and so do `function -x { kill -1 }`, `function - { kill -1 }`, `function -- -T { kill -1 }` and `function -T -T { kill -1 }`, which define a function named `-x`, `-` or `-T`.
- Fixed: a reserved word after a compound command's close. `}`, `fi`, `done`, `esac` and zsh's `end` at a command's head, and a `]]` anywhere, are taken off, so the `then`, `else`, `elif` or `do` after them is a head word, and the command after it is read: in bash, dash and zsh, `if { true; } then kill -1; fi`, `if false; then { true; } else kill -1; fi`, `until { false; } do kill -1; done`, `if false; then case x in x) true;; esac else kill -1; fi` and `if false; then f() { true; } else kill -1; fi`; in bash and dash, `if false; then for x in 1; do :; done else kill -1; fi` (zsh rejects a reserved word right after `fi` or `done`); in bash and zsh, `if [[ 1 ]] then kill -1; fi` and `while [[ 1 ]] do kill -1; done` (dash has no `[[`); and in zsh, the short form's command after the `end` of `foreach` (`if foreach x (1); true; end kill -1`). These were misses on every Linux seat: 37 forms of the class map that bash or dash runs.
- Migration: none to do. A call that runs a kill through one of these spellings is now refused; kill by literal PID in a separate call. No form the rail refused is now allowed. On the grids none newly throws either: 0 of the new brace grid's 731,225 forms, 0 of the 0.15.7 grids' 29,264 and 0 of the 0.15.4 to 0.15.6 grids' 5,952,054. Off the grids, a command the brace reading reads where the reading before read nothing can hold text the rail cannot read; the call is then unread and refused under the README's unread rule, within the deliberate false stops below: `echo ]] bash -c '$(x'` and `{echo,x} bash -c '$(x'`, where bash runs `echo`, and a `]]` argument before a chain of more than 8 `xargs`. The six known-limit rows of #1170 become refused rows; no other allowed form the suite pinned changes. The omp-roles floor stays at seat-mods 0.14.0; the OMP rail reads the same `killRule`, and omp needs no change.
- Deliberate false stops. zsh's brace grammar and the close words are read in every shell (bash and dash run a program named `{kill`, so `dash -c '{kill -1}'` runs nothing), and also where zsh runs nothing: a command word right after a close, where the shell wants a separator (`[[ 1 ]] kill -1`, `{ true; } kill -1`, `if [[ 1 ]] then kill -1 fi`); a `]]` that is an argument (`echo ]] kill -1`); `always` where zsh rejects it (`{ true } always { true } always { kill -1 }`, `if [[ 1 ]] { true } always { kill -1 }`, `while [[ 1 ]] { true } always { kill -1 }`, `function { true } always { kill -1 }`); zsh's `if [[ … ]] { … }` at the very end of the string, which zsh parses only when a separator follows (`if [[ 1 ]] { kill -1 }`; with `; true` after it zsh runs the kill); a backslash in `function` or `always` (`\function { kill -1 }`, `{ true } \always { kill -1 }`), which the reader drops as with `\time`; a redirection between a close and the reserved word after it (`if false; then if true; then true; fi 2>/dev/null else kill -1; fi`); and a glued group the line's other words make zsh reject (`{kill -1} x`, `{not,x} kill -1`, `do {kill -1}`). The rail evaluates no condition, so `true || {kill -1}` and `{ exit 1 } always { kill -1 }` are refused, as `if true; then :; else kill -1; fi` already was. 78 forms of the class map, of the 263 that run nothing in any shell; the README lists them. A sole `{` that is an operand opens a group for the reader too, so the words after its `}` are read as a command (`echo { true } kill -1`, `echo {; kill -1}`), where bash and dash take the `{` as a word and zsh rejects the `}`; a named function's body past its first command is read as run, as a `name() { … }` body is (`function f { true; kill -1}`, as `function f { true; kill -1 }` already was); and `-p` or `--` after `time` before a glued `{` or a `case` (`time -p {kill -1}`, `time -p case x {x) kill -1}`), which zsh does not take, while bash and dash run a program named `{kill`. A command named `end` before a kill form (`end kill -1`), where bash and dash run a program named `end` and zsh and fish reject the line. The word after a sole `}` that ends a `${…}` at a command's head, read as a command as after an assignment's value (`A=${x:-a; } kill -1` runs the kill), so `{ echo ${x:-a; } kill -1}`; and a `${…}` zsh rejects or cannot expand, read as bash reads it (`{ echo ${x:-a|b}; kill -1}`, `{ echo ${x }; kill -1}`, `{ echo $${x; kill -1}`). Already refused, and now listed: a stray `}` at a head while no group is open (`true; }; { true; kill -1}`, `true; } always { kill -1 }`), a short form's `elif` or `else` that zsh rejects (`if [[ -z 1 ]] true; elif [[ 1 ]] kill -1`), zsh's `if [[ … ]] { … }` before `&`, `|`, `&&` or a redirection (`if [[ 1 ]] { kill -1 } | cat`), and a stray reserved word after a close (`if true; then true; fi else kill -1`). The sole `{` newly refuses 5,208 forms of the brace grid; of a sample of 286 of them (every 16th top-level `kill -1` form, with `echo RAN` in its place), zsh runs 2 (`if function f { true } kill -1`, read now) and bash and dash none.
- Known limits: zsh's functions it runs by itself, `TRAPEXIT`, `zshexit`, `TRAPZERR` and `TRAPDEBUG`, are read as defined only, so `function TRAPEXIT { kill -1 }` is a miss (#1185); `TRAPEXIT() { kill -1 }` is refused, as every `name() { … }` body is. bash's brace expansion of the command word (`{kill,-1}`, `{,kill} -1`) is a miss, as of an operand (#1186). A `trap` string, which the shell runs later (`trap 'kill -1' EXIT`, #1187), and zsh code inside a word (`echo *(e:'kill -1':)`, `${(e)…}`, #1188) are misses. The rest of an assignment whose value holds an unquoted blank inside `${…}` stays a miss (`A=${X:-a b} kill -1`, #1184). An anonymous function's arguments are its parameters, so `function { kill $1 } -1` is a miss, as a variable whose value is `-1` is; `() { kill $1 } -1` is refused. The other forms of the 27 the class map leaves are forms only fish runs, as an outer shell, which neither harness has (`{{kill -1}}`, `A=1 {kill -1}`), and a named function run by name or by `trap f EXIT`, an existing known limit. A `}` zsh keeps in a word is read as a group's close, so the kill after the group's own `}` is a miss: one glued to an assignment (`{ x=a}; kill -1}`), and one ending a `${…}` the rail ends earlier, where zsh nests a `{` inside it (`{ echo ${x:-{a} b}; kill -1}`), reads `$${` as a `$` and a `${` (`{ echo $${x:-a b}; kill -1}`), or where a substitution glued to a `{` in the same command turns the `${…}` reading off (`{ echo $(true){a; ${x:-a b}; kill -1}`) (#1184). A `}` glued to a redirection word is dropped with the word (`{ true 2>/dev/null} always { kill -1 }`). The reserved word after an `esac` that follows a case's plain words is not read (`if case x in esac then kill -1; fi`). An anonymous function after `time` is a miss where zsh runs it, in a pipeline or after an earlier line (`time function { kill -1 } | cat`). zsh's short forms after a command that is only assignments are not read (`if x=1 { kill -1 }; true`), nor the `{` or `do` after `for NAME` with no list (`set -- a; for x { kill -1 }`, and the older `set -- a; for x do kill -1; done`).
- Tests: 90 refused rows with a near-miss control each (six of them the known-limit rows of #1170), 62 allowed controls, 48 deliberate false stops with their controls and 21 known-limit rows (#1184 ×4, #1185 ×4, #1186 ×2, #1187, #1188 ×2, an anonymous function's argument, a form only fish runs, a `}` glued to a redirection word, `esac` after a case's plain words, an anonymous function after `time`, a short form after assignments, `for NAME` with no list ×2) in place of the six in `tests/kill.test.ts`; three forms the brace reading leaves unread, and two whose refusal wins over a throw, each with a control that throws; three bounds tests, four ratios, each side the least of three runs: 20,000 sole `}` words, alone and each before a word, against the same words with `x` (about 1 and 1.5), and 20,000 `]]` words each before a word against the same with `x` (about 2.5), each bound 50; and a glued `{`, `always`, an anonymous function and an open group before 40,000 head `}` words and a 40,000-word command, against as many `]]` words (about 0.8, bound 10); two OMP `eval` literals with their controls in `omp/tests/seat-mods-manifest.test.ts`. fish's frozen digests are unchanged.

## 0.15.7 — 2026-11-10

The kill rail reads `kill`'s options at its first word only (#1176), reads a later operand as zsh's `kill` reads a pid and every operand as procps-ng's `kill` reads one, skips `NAME+=` and `NAME[…]=` assignments before the command word (#1175), and reads `env -S` / `--split-string` (#1173). `kill -9 -0`, `kill 123 -s -1`, `kill 123 -` (zsh), `A+=1 kill -1`, `a[1]=x kill -1`, `env -S 'kill -1'`, `env -S'kill -1'`, `env -S 'kill -- -${PGID}'` and `/bin/kill +4294967295` went to the model as if the rail were absent. bash 5.3, zsh 5.9, dash and busybox 1.37 sh were probed with harmless stand-ins for the assignments, and GNU coreutils 9.7 and uutils coreutils 0.8.0 `env` for `-S`; bash's, zsh's, dash's and procps-ng's `kill` and FreeBSD's `env` were read from source, and glibc's `atoi` was called on the digit strings alone.

- Fixed: `kill`'s options are read at its first word only, as zsh reads them (bash reads one `-word` as the signal and ends its options at the first operand). The rail read `-s`, `-n` and `--signal` and their value at any position before `--`, and a later `-0` as an option, so `kill -9 -0`, `kill -s 9 -0`, `kill KILL -0`, `kill 123 -0`, `kill -9 '-0 '`, `kill 123 -s -1` (bash) and `kill -9 -s -1` (zsh), which signal 0 or -1, passed. A later `-s`, `-n` or `--signal` is now an operand, as is the word after it.
- Fixed: a later operand is read as zsh's `kill` reads a pid: a word made only of digits and `-`, read with `atoi`, the sign and the digits up to the next `-`, held to a 64-bit long's range, then cut to a 32-bit int. So `kill 123 -`, `kill -9 0-1`, `kill -9 -1-`, `kill -9 123 --`, `kill 5 -- 123` and `kill 4294967295` (each 0 or -1 to zsh) are refused; `kill -9 -- 123`, `kill -9 -12-` and `kill 4294967294` pass. On a grid of 22,764 `kill` operand forms modelled from the shells' source the rail missed 4,186 that bash, zsh or dash runs, and now misses none.
- Fixed: every operand is also read as procps-ng's `kill` reads a pid, which a path, `env`, `sudo`, `xargs` and `nohup` run: its options are read at any word (getopt moves them ahead of the operands), so `-s`, `-q`, `--signal` and `--queue` take the next word, and every word that does not start with `-` is read with `strtol` (C blanks and a `+` or `-` before the digits, within a long's range, past which procps fails) and cast to a 32-bit `pid_t`. So `/bin/kill +4294967295`, `/bin/kill ' 4294967295'`, `/bin/kill -9 ' -4294967297'`, `env kill +4294967295`, `sudo kill -9 +4294967296` and `/bin/kill -9 -- +8589934591`, each -1 or 0 there, are refused; `/bin/kill +4294967294`, `kill -s 0 1234` and `/bin/kill +9223372036854775808` pass.
- Fixed: an assignment before the command word is skipped as bash and zsh skip one: `NAME=`, `NAME+=`, `NAME[…]=` and `NAME[…]+=`, with any characters in the subscript (`A+=1 kill -1`, `a[1]=x kill -1`, `a["]"]=1 kill -1`, `A+=1 sudo kill -1`). `A+=1 echo hi` passes. The reading 0.15.6 made is kept beside it: a word that holds `=` but is not `NAME=…` is also the command word, its path taken off, so `A+=/bin/kill -1` stays refused (see the deliberate false stops). On a grid of 2,156 assignment forms the rail missed 603 that bash or zsh runs, and now misses 90, each a known limit: a shell string inside a shell string (`bash -c "A+=1 bash -c 'kill -1'"`, `bash -c "a['x y']=1 bash -c 'kill -1'"`), which the rail does not read past one level, and a subscript that holds an unquoted blank or a parenthesis (below).
- Fixed: an `env -S` or `--split-string` string (any prefix of the long name, attached or not, in a cluster) is split into words as GNU, uutils and FreeBSD env split it, and those words and the words after the string are read again as the command line after env's options, as GNU env reads them again: `env -S 'kill -1'`, `env -S'kill -1'`, `env --sp='kill -1'`, `env -iS 'kill -1'`, `env -S 'kill\_-1'`, `env -S '-i kill -1'`, `env -S 'kill' -1`, `env -S 'bash -c "kill -1"'`. A word that starts with `-S` among the assignments is split too, as uutils splits it (`env A=1 -S'kill -1'`). A variable is read empty and, beside that, as its text, so `PGID=1 env -S 'kill -9 -${PGID}'` and `env -S'kill -9 -$PGID'`, where GNU and uutils expand the variable from env's own environment, are refused as `kill -9 -$PGID` is, and `env -S 'ki${X}ll -1'` stays refused. Only the first `-S` string of a walk is split, as GNU env restarts its options there: a later one, in the same env or in a later env of the same command, is split where that line is read again (`env -S '-S kill\_-1'`, `env -S 'env -S kill\_-1'`), and `env -S 'echo hi' env -S 'kill -1'`, where env runs `echo`, passes. A string with no words in either reading is passed over, and the walk reads on, as env does, so `env -S '' env -S 'kill -1'` is refused and a chain of empty strings reads as one env. Each line is read once per call, at the least nesting it is met at, after the call's own text, so a chain of `env -S` strings takes time linear in its length. On a grid of 4,344 `env -S` forms run with a stand-in under GNU and uutils env, the rail missed 2,026 that an env runs, and now misses 2 (below).
- Migration: none to do. A call that runs a kill through one of these spellings is now refused; kill by literal PID in a separate call. No form the rail refused is now allowed, and none newly throws: 0 of the three new grids' 29,264 forms, and 0 of the 0.15.4 to 0.15.6 grids' forms. An `env -S` line read again more than 8 deep is unread and refused, as a substitution nested that deep is: a string nested in another more than 8 deep, or a chain of more than 8 env each with a non-empty string (below); a runner's string inside an `env -S` line is read at that line's nesting, so the line counts toward the 8. The one allowed form the suite pinned that changes is `kill $(echo 5) -- 123`, which zsh runs as `kill(0)` for the `--`: it is now refused. The omp-roles floor stays at seat-mods 0.14.0; the OMP rail reads the same `killRule`, and omp needs no change.
- Deliberate false stops. `kill`'s first-word reading and zsh's pid reading refuse a `-0` or a zsh pid word where no shell signals: after a listing (`kill -l -0`), after a first word bash and zsh reject (`kill - -0`, `kill -sKILL 0-`, `kill -n9 -1-`), where bash's option reading and zsh's meet in one form (`kill -9 -s '-0 '`), and where one reading of the words spells the signal and another does not (`kill $'\x2d\x39' - 1`): 1,889 forms of the `kill` grid. procps's pid reading is read for the builtins too, which reject a `+` or a blank before a pid past their range (`kill +4294967295`, `kill ' 4294967296'`). An assignment is skipped where dash and busybox sh run it as the command (`dash -c 'A+=1 kill -1'`), where the rail's readings drop its quotes or backslashes (`'A+'=1 kill -1`, `A\+=1 kill -1`), and where no shell takes it (`a[1][2]=x kill -1`): 152 forms of the assignment grid; behind `nohup` and `xargs`, which run a program named `A+=1`, `nohup A+=1 kill -1` and `xargs A+=1 kill -1` are refused, as `nohup A=1 kill -1` already was. The reading 0.15.6 made of a word that holds `=` but is not `NAME=…` is kept: it is the command word, its path taken off, so `A+=/bin/kill -1`, `a[1]=/bin/ps; kill 123`, `A+=./kill -1` and `a[k]=../kill -9 -1` stay refused, though bash and zsh assign the word and only dash and busybox sh run it, as a relative path no stock host has; so does 0.15.6's reading of a word that starts with `-S` among env's assignments as the command word (`env -P A=1 -S'a /bin/kill' -1`, where FreeBSD runs a program named `a`). An `env -S` string is read loosely, as the union of the three grammars: a `#` comment read to the next newline and a dropped backslash-newline in the separate-word form, which uutils does not split (`env -S $'#c\nkill -1'`, `env -S $'ki\\\nll -1'`), an escape or a `$NAME` GNU rejects (`env -S 'kill \q -1'`, `env -S 'kill $HOME -1'`), an open quote (`env -S 'kill "-1'`), and quotes the reading that takes them off drops (`env -S "'kill -1'"`, where env runs a program named `kill -1`): 820 forms of the `env -S` grid, half of them its `sudo` copies. A chain of more than 8 env each with a non-empty `-S` string is unread past the cap, though env runs its last command (`env -S 'A=1'` or `env -S '-i'` nine times, then `make`), and so is one whose strings hold only a variable, which is not empty in the reading that keeps it (`env -S '${X}'` nine times). Each runs nothing in the shell or `env` named; the README lists them.
- Known limits: an assignment whose subscript holds an unquoted blank or a parenthesis (`a[1 2]=x kill -1`, bash; `a[(i)x]=1 kill -1`, bash and zsh) is read as the command word. So is the rest of an assignment whose value holds an unquoted blank inside `${…}` or `$[…]` (`A=${X:-a b} …`, `A+=$[1 + 2] …`; bash and zsh; older than this release, #1184). uutils 0.8.0's `env --split-string=X` drops the first split word, so `env --split-string='echo kill -1'` runs `kill -1` there (#1173). On procps-ng 4.0.4 as released, `/bin/kill -9 -1234` signals -1; write `kill -- -1234` (#1180). sudo's own assignment grammar is not read (`sudo a-b=1 kill -1`, `sudo A=1 -u root kill -1`, #1181). The role guards read `NAME=` only, so a subscripted or `+=` assignment prefix (`A+=1 git push --force`) is not read as the command there (#1182).
- Tests: 95 refused rows with a near-miss control each (five of them the known-limit rows of #1173 ×3 and #1175 ×2), 32 allowed controls, 27 deliberate false stops with their controls and 9 known-limit rows in `tests/kill.test.ts`; the control `kill $(echo 5) -- 123` becomes a refused row, and `kill $(echo 5) 123` is its control; seven bounds tests: 8 nested `env -S` strings are read and 9 are unread; a chain of empty `env -S` strings reads as one env, and 9 non-empty ones are unread; a runner's string in an `env -S` line around 7 nested strings is read, and around 8 is unread; and four ratios, each side the least of a few runs and each bound 50: 400 `-S` words in one string against 400 plain words (about 8), `env -S` lines that branch at every level against one `-S` with the same words after it (about 10, against about 250 without the once-per-line reading), and chains of 100 `env -S` strings against the same words with `echo` (about 1.5, and 12 for strings that nest to 8 levels, against about 3,000 where every env's string is split and a line is read again less deep), and a kill operand of 100,000 digits and another character against the digits alone (about 1, against about 300 for a pid reader that retried every split point of the digits); three OMP `eval` literals with their controls in `omp/tests/seat-mods-manifest.test.ts`. fish's frozen digests are unchanged.
## 0.15.6 — 2026-11-09

The kill rail reads `env`'s own grammar (#1168), every word of a command after the outer shell's quote removal (#1169), and `$'…'` as zsh decodes it (#1171). `env - kill -1`, `env -a x kill -1`, `$'\x6bill' -1`, `kill $'\x2d1'`, `kill \ -1` and, under a zsh outer shell, `bash -c $'echo\C-jkill -1'` and `bash -c $'kill\ -1'` went to the model as if the rail were absent. GNU coreutils 9.7, uutils coreutils 0.8.0 and busybox 1.37 `env`, bash 5.3 and zsh 5.9 were probed with harmless strings only; FreeBSD's and macOS's `env` were read from source.

- Fixed: `env` is read three ways, and the call is refused if any reading is: with the generic wrapper options, as before; as GNU coreutils, busybox and uutils read it; and as FreeBSD and macOS read it. Each grammar takes its own value options (`-a`/`--argv0` and `-f`/`--file`; BSD's `-P`, `-L` and `-U`; `-u`, `-C` and `-S` in both), any prefix of a long name (`env --uns X kill -1`, `env --ch / kill -1`), its bare `-` (`env - kill -1`, `env -- - kill -1`; on uutils more than one, and among the assignments: `env A=1 - kill -1`; on FreeBSD and macOS an option among the others: `env - -i kill -1`), and any word that holds `=` as an assignment (`env a-b=1 kill -1`). On a grid of 145,015 `env` forms the rail missed 21,490 that some `env` runs, and now misses none.
- Fixed: every word of a command is also read after the outer shell's quote removal, as bash does it and as zsh does it, beside the reading that takes its quote characters off: the command word, a wrapper, a runner's name and the operands (`$'\x6bill' -1`, `kill $'\x2d1'`, `kill \ -1`, `systemctl --user $'\x65xit'`, `$'\x70s' aux; kill 123`, `$'\x62ash' -c 'kill -1'`, `env $'\x2d' kill -1`). Reserved words are read unquoted only, so `$'\x74ime' ! kill -1`, which runs the time program, passes. On a grid of 275,840 spellings the rail missed 23,879 kills bash hands on and 21,263 zsh hands on, and now misses none.
- Fixed: a `-c` or `eval` word, and every word of a command, is also decoded as zsh decodes `$'…'`: an escape zsh does not know loses its backslash (`bash -c $'kill\ -1'`, `$'\k\i\l\l' -1`); `\C-x`, `\Cx`, `\M-x` and `\Mx` are read (`bash -c $'echo\C-jkill -1'`); `\cX` is handed on as `cX` (`bash -c $'system\ctl --user exit'`); `\x`, `\u` and `\U` with no digit are a NUL, and `\x` takes a sign (`\x-1` is 0xff); and a NUL ends the whole word (`bash -c $'kill -1\0'x`, `$'kill\0'x -1`) or, inside `eval`, is read as a blank (`eval $'kill\0zz'$'\ \-1'`). On a grid of 25,196 `-c` and `eval` forms the rail missed 2,194 kills zsh hands on, and now misses none. The same forms are refused in an OMP `eval` literal (`os.system('env - kill -1')`); omp needs no change.
- Fixed: `kill`'s operand is read as bash's `kill` reads a number: blanks (space, tab, newline, vertical tab, form feed, carriage return) before the sign and after the digits, however they are spelled, and a `+` sign. The rail read a blank before `-1` only, so `kill -9 '-1 '`, `kill -9 -1\ `, `kill -s 9 -1\ `, `kill -9 -1$'\x20'`, `kill -9 \ 0`, `kill -9 "0 "`, `kill -9 -- '-0 '`, `kill +0` and `kill -9 " -$X"` went to the model as if the rail were absent. A word that starts with a blank is never an option to bash's `kill`, so `kill -9 ' -0'` is refused without `--`. `kill -9 '123 '` passes. bash 5.3's reading of a number was probed with `exit` stand-ins (a blank of each of the six kinds on either side, and `+`). On a grid of 100,680 spellings of these operands and their near misses, 25,817 forms 0.15.5 passed are refused, 14,140 of them by this reading: each is `-1` or `0` with a blank or a `+`, or a negative operand holding a `$` after a blank (`kill -9 ' -1'$"0"`, refused as `kill -9 -1$"0"` already was).
- Migration: none to do. A call that runs a kill through one of these spellings is now refused; kill by literal PID in a separate call. No form the rail refused is now allowed, and none newly throws: 0 of the three new grids' 446,051 forms and of the 100,680 spellings of a blank or a `+` in kill's operand, and 0 of the 0.15.5 grids' 1,734,860, 609,070 and 1,760,248 forms and its 1,301,145-form attached-fish grid. Off the grids, zsh's decoding of a `-c` or `eval` word can leave text the rail cannot read, which now throws and is refused as unread under the README's unread rule, as 0.15.5's `bash -c echo\ \$\(` is: `bash -c $'echo \$\('`, which zsh hands on as `echo $(` (bash hands on `echo \$\(`, which runs: a one-shell false stop), `eval $'echo cost: \$\(5'` and `bash -c $'echo \$(x'`; and a command word that quote removal makes `xargs` can make an `xargs` chain more than 8 deep (eight `xargs`, then `$'\x78args' echo hi`). The one allowed form the suite pinned that changes is `bash -c $'kill\ -1'`, which zsh runs as `kill -1`: it is now refused. The omp-roles floor stays at seat-mods 0.14.0.
- Deliberate false stops. bash's quote removal and zsh's are both read in every shell, since the rail cannot know the outer shell, so a form one shell runs is refused under the other too: under bash, `bash -c $'kill\ -1'`, `bash -c $'kill -1\0'x` and `$'\k\i\l\l' -1` run no kill (7,639 new stops of the word grid and 2,194 of the `-c` grid run only under zsh); under zsh, which hands on a `$"…"`'s `$`, `$"kill" -1` runs no kill, as `bash -c $"kill -1"` already did not (10,255 new stops of the word grid run only under bash). The two readings also meet in one form: zsh's `noglob`, `nocorrect` and `-` are read beside bash's quote removal of the next word, so a form neither shell runs is refused (`noglob $'\x6b'"i"$"l""l" -1` and `nocorrect ki$'\154'$"l" -1`, where bash runs a program named `noglob` or `nocorrect` and zsh hands on `ki$ll` or `kil$l`). A NUL in an `eval` word is read as a blank, so `eval $'\0 kill -1'`, where zsh runs an empty command name, and a NUL inside `kill`'s operand there (13 forms of the `-c` grid, such as `eval $'\k\i\l\l\ '$'-1\0zz'`) are refused. zsh's reading ends every word of a command at a NUL, the builtin `kill`'s operands too, so a NUL in `kill`'s operand with text after the `$'…'` part is refused, though zsh's `kill` keeps the NUL and bash's gets the text after it (`kill $'-1\0'x`, where bash's kill gets `-1x`; `kill -9 $'-1\0'x`, `kill $'0\0'x`). Every reading's heads go into one scan, so a list in bash's reading and a signal in zsh's are refused together (`$"ps" aux; $'\k\i\l\l' 123`, and 20 forms of the `-c` grid). A vertical tab, form feed, carriage return or no-break space that `$'…'` hands on is split at in an operand too (`kill $'\v-1'`). The reading that takes a word's quote characters off keeps its stops (`kill "'"-1`, where bash hands on `'-1`). An option an `env` rejects is read as a flag, though that env runs nothing: an unknown letter, `-0` with a command, `-S`'s string, or a GNU-only option beside a BSD-only one (`env -x kill -1`, `env - -0 kill -1`, `env -ax -P /usr/bin kill -1`; 18,382 forms of the `env` grid), and the generic reading's stops stay (`env -a kill -1`, `env A=1 -i kill -1`). Each runs nothing in the shell or `env` named; the README lists them.
- Known limits: `env -S '…'` and `--split-string`, which split their string into words with `env`'s own quoting and run them (`env -S 'kill -1'`, `env -S'kill -1'`), stay unread (#1173). zsh grammar past `repeat`, `nocorrect`, `noglob` and `-` stays unread (#1170). An append or an array element assignment before the command word (`A+=1 kill -1`, `a[1]=x kill -1`) is read as the command word, as in 0.15.5 (#1175).
- Tests: 70 refused rows with a near-miss control each, 15 allowed controls and 13 deliberate false stops with their controls in `tests/kill.test.ts`; seven known-limit rows (#1168, #1169, #1171) become refused rows and four (`env -S'kill -1'`; `kill -9 -\<newline>1`, an operand split by a line continuation, which 0.15.5 did not read either; `A+=1 kill -1` and `a[1]=x kill -1`, #1175) are added; three bounds tests: an `xargs` chain more than 8 deep in one reading stays unread though another reading reaches its words less deep, also where the ninth `xargs`'s words were walked first from less deep; and a chain whose readings branch three ways at every level is walked once per start word (9 walks of its 2,000 operands, where walking every branch again is 9,841 walks, about 28 s; the bound is 5 s); three OMP `eval` literals with their controls in `omp/tests/seat-mods-manifest.test.ts`. fish's frozen digests are unchanged.

## 0.15.5 — 2026-11-09

The kill rail reads a `-c` or `eval` word after the shell's quote removal (#1162), and reads zsh's `repeat`, `nocorrect`, `noglob` and `-` (#1160). In `bash -c kill\ -1`, `eval kill\ -1` and `bash -c time\ !\ kill\ -1` the rail kept the backslash and read one word, `kill -1`, and in `repeat 1 kill -1`, `nocorrect kill -1` and `noglob kill -1` it named `repeat`, `nocorrect` or `noglob` as the command: each call went to the model as if the rail were absent. bash 5.3, zsh 5.9, dash and fish 4.2.1 were probed with harmless strings only.

- A `-c` or `eval` word is read as the outer shell hands it on: a backslash outside quotes, `'…'`, `"…"` (with `\"`, `\\`, `\$` and `` \` `` undone), `$'…'` (decoded as bash decodes it; a NUL ends only its own `$'…'` part) and `$"…"` (read as bash reads it) are undone. So an escaped blank, tab or `;` (`bash -c ps\;kill\ 123`), `$'…'` (`bash -c $'kill\x20-1'`), `$"…"`, and mixed quoting that starts and ends with the same quote (`bash -c 'kill'\ '-1'`) are read, under every runner the rail reads (`sh`, `zsh`, `fish`, `sudo bash`, `busybox sh`, `ksh`) and in an OMP `eval` literal. A fish `-c`, `-C` or `--command=` value attached to its option word gets the same (`fish -ckill\ -1`, `fish --command=kill\ -1`). On a grid of 1,734,860 encodings checked against bash's own quote removal, the rail missed 843,440 kills and now misses none.
- The earlier reading of that word, which takes the quote characters off and keeps every backslash, is read beside the new one, and the call is refused if either reading's string is, so no form the rail refused is now allowed. Its own stops stay (`bash -c k'ill '$'--\\ -1'`, where kill gets the one operand `-- -1`).
- zsh's reserved `repeat` and its count (any one word) is taken off a command's head, after a head word and after the reserved `time` (`time repeat 1 kill -1`, `repeat 1 time ! kill -1`, `repeat 1 do kill -1; done`, `repeat 1 { kill -1 }`). zsh's reserved `nocorrect` (unquoted) and its precommand modifiers `noglob` and `-` (quoted or not) are read at a command's head, after assignments and after `builtin`, `exec` and `time` (`time noglob kill -1`, `A=1 noglob kill -1`, `'noglob' kill -1`, `exec noglob kill -1`, `- kill -1`). After any other wrapper or under `xargs` each names a program, as in zsh, and so does a quoted `repeat` or `nocorrect` or one after an assignment: `nohup noglob kill -1`, `env noglob kill -1`, `xargs repeat 1 kill -1`, `'repeat' 1 kill -1` and `A=1 repeat 1 kill -1` stay allowed.
- Deliberate false stops: `$"…"` under a zsh outer shell, which hands on the `$` and the text (`bash -c $"kill -1"` runs nothing there); zsh's words in bash, dash and fish, where each names a program a stock host lacks (`dash -c 'noglob kill -1'`); a `repeat` count the rail does not evaluate (`repeat 0 kill -1`, `repeat echo kill -1`); a backslash in `repeat` or `nocorrect` (`\repeat`, `re\peat`, `nocorrec\t`), which the reader drops; a character that `$'…'` hands on and the shell does not split at but the rail does (a vertical tab, form feed, carriage return or no-break space: `bash -c $'kill 123\v-1'`); and a chain of zsh's words that zsh rejects or where it runs a program (`noglob nocorrect kill -1`, `exec nocorrect kill -1`, `nocorrect time kill -1`, `noglob A=1 kill -1`, `- noglob kill -1`, `builtin nocorrect kill -1`). Each runs nothing in the shell named; the README lists them. The suite's frozen `eval` verdicts on the fish grid gain six forms for zsh's `-`: `eval - 'kill -1' 'echo S2'`, `eval - 'kill -1' 'kill -1'`, and the same two after `- -` and after `-- -`.
- No form the rail refused is now allowed. On the three grids none newly throws either: 0 of 1,734,860 quote-removal forms, 0 of 609,070 zsh-word forms, and 0 of the 0.15.4 grid's 1,760,248 forms, whose verdicts are all unchanged. Off the grids, a word whose quote removal leaves text the rail cannot read now throws, and is refused as unread under the README's unread rule: `bash -c echo\ \$\(`, which hands bash `echo $(`, and `eval echo cost: \$\(5`. bash rejects both texts (unexpected end of file), so each is a deliberate false stop on text the shell does not run.
- fish's command prefixes are taken off in one pass over the string, so a long run of them (`fish -c 'not not … kill -1'`) takes time linear in its length: in 0.15.4 a string of 32,000 `not` prefixes took about 10 s. No verdict changes.
- Known limits: a backslash-newline inside a `-c` or `eval` word (`bash -c kill\ \<newline>-1`), as for any word split by a line continuation; `env - kill -1` (#1168); quote removal on the command word and its operands (`$'\x6bill' -1`, `kill \ -1`, #1169); zsh grammar past these words, such as `{kill -1}`, `if [[ 1 ]] kill -1` and `function { kill -1 }` (#1170); and `$'…'` under a zsh outer shell, which decodes `\C-x` and `\M-x` ends the whole word at a NUL, and hands on `\cX` as `cX` (`bash -c $'echo\C-jkill -1'`, `bash -c $'kill -1\0'x`, `bash -c $'system\ctl --user exit'`, #1171).
- The omp-roles floor stays at seat-mods 0.14.0. Claude Code and OMP both read the same `killRule`, and omp needs no change.

## 0.15.4 — 2026-11-09

The kill rail reads a head word after the reserved `time` (#1139). The rail took `time` as a wrapper and named the next word as the command, so in `time ! kill -1`, `time if kill -1; then :; fi` and `fish -c 'time while kill -1; end'` it named `!`, `if` or `while` and read no kill: the call went to the model as if the rail were absent. Behind the same miss sat every other kill rule (`ps aux; time ! kill 123`, `time ! pkill -u dev`), at top level, in a shell or fish string, in `eval '…'` and in an OMP `eval` literal. bash 5.3, zsh 5.9, dash and fish 4.2.1 were probed with harmless strings only.

- The reserved `time` is taken off a command's head only when a head word (`if`, `then`, `elif`, `else`, `do`, `while`, `until`, `!`, `{`, `(`) or another `time` follows it, after an optional `-p` and then an optional `--`, as bash reads them, and again after each head word it uses (`time -p ! kill -1`, `time -- ! kill -1`, `time time ! kill -1`, `time ! time ! kill -1`). Any other `time` the rail still reads as the time program with its options (`time -f %e kill -9 -1`, `time -p kill -1`), read as before.
- No other wrapper changes. Only the reserved `time` takes a pipeline, so a head word after `A=1 time`, `'time'`, `/usr/bin/time`, `time -p -p`, `nohup`, `env`, `sudo` or `xargs time` names a program, which the shell runs and which does not exist: `A=1 time ! kill -1`, `nohup ! kill -1` and `xargs time ! kill -1` stay allowed.
- Deliberate false stops: `\time ! kill -1`, since the reader takes `\time` as `time`, though the shell runs the time program; `time then kill -1` and the like, which bash rejects; `-p` or `--` after `time` under zsh and fish, which take neither (`zsh -c 'time -p ! kill -1'`); every one of these forms under dash, whose `time` is not reserved (`dash -c 'time ! kill -1'`); a backslash inside `time`, `-p`, `--` or a head word (`t\ime`, `time \-p`), or a redirection before or between them (`time >/dev/null ! kill -1`, `>/dev/null time ! kill -1`), which the reader drops; `time time`, `time ! time` and `time ! !` under zsh, and `time time` under fish; and a `time` after `|` under bash and fish. Each runs nothing in the shell named; the README lists them.
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
