# seat-mods

Role guards for worker seats, as a Claude Code mod. Requires Claude Code 2.1.287 or later.

An orchestrator spawns a worker seat (an implementer, a verifier or a reviewer) and sets one
environment variable on that spawn. The seat's tool calls then meet its role's rails: Edit and
Write are placed by the file system, and Bash calls are matched against the common spellings of
each rule — a best-effort catch for mistakes, not a shell parser. **The default is guarded:** a
session with `SEAT_MODS_ROLE` unset or empty runs under the implementer rails, so a forgotten
export fails closed, and its status line reads
`seat: implementer (default: SEAT_MODS_ROLE unset or empty)`.
A session that is not a worker marks itself explicitly: `SEAT_MODS_ROLE=orchestrator` for the top
orchestrator (or any session you start to drive work) and `SEAT_MODS_ROLE=coordinator` for spine,
close, work-PR and doctor sessions and lane drivers; both are unguarded except for the kill rail (below).

**Rollout: do not install 0.2.0 until every launcher you use — and your own interactive sessions —
marks its free sessions.** `crew` does — so did the pre-rename line from 0.2.7; for any other
launcher, set `SEAT_MODS_ROLE=orchestrator` yourself, e.g. in your launch alias. Until then a coordinator or a bare `claude` session starts guarded as an implementer
and cannot merge.

## The contract

Two environment variables, both set **per spawn**:

| Variable | Value | Effect |
|---|---|---|
| `SEAT_MODS_ROLE` | unset or empty | Guarded as `implementer` by default. The status line reads `seat: implementer (default: SEAT_MODS_ROLE unset or empty)`. |
| | `implementer`, `verifier`, `reviewer` | That role's guards are on. The status line shows `seat: <role>`. |
| | `orchestrator`, `coordinator` | Unguarded except the kill rail (0.14.0): no role denies, no write placement checks. On OMP an orchestrator may not spawn subagents (0.4.4). The status line shows `seat: <role>`. |
| | anything else | Fail closed. Every tool call is denied with a message that names the bad value and the valid roles (a kill-rail refusal comes first, with its own text). Respawn the seat with a valid value. |
| `SEAT_MODS_ALLOW` | `:`-separated absolute directories | Extra directories the seat may write to: its report directory and its scratch directory. Relative entries and `/` are ignored. Unset, only the worktree and the scratch places (`/tmp`, `$TMPDIR`; see below) are writable — and a reviewer, whose profile may write only in these directories and the scratch places, then writes only there. |

The pre-rename line's 0.2.2 through 0.2.6 export both in the pane of each implementer, verifier
and reviewer seat before its command and leave every other pane unset; with this release an unset
pane is a guarded implementer. 0.2.7 and every `crew` release set `SEAT_MODS_ROLE=orchestrator` on the
top's rotation successor and `coordinator` on its coordinator seats (the spine, close and work-PR
sessions, the doctor session, the lane driver). Neither directory may contain `:`, the
list separator.

**Never set either variable in `~/.claude/settings.json`'s `env` block, in a shell profile, or in a
machine-file `command:` line.** Each of those reaches the orchestrator, which must never be guarded.

## Without an orchestrator plugin

seat-mods reads only its two variables. It does not call herdr, Paseo, Orca or any other
orchestrator, and it does not need one installed. An orchestrator plugin is one launcher that sets
the variables; with none installed, you are the launcher. Set the role on each command that starts
a session:

```bash
# Sessions you drive yourself: unguarded except for the kill rail.
alias claude-orch='SEAT_MODS_ROLE=orchestrator claude'

# Worker sessions you start by hand: guarded by role.
claude-impl() {
  SEAT_MODS_ROLE=implementer SEAT_MODS_ALLOW="$HOME/seat-scratch/impl" claude "$@"
}
claude-verify() {
  SEAT_MODS_ROLE=verifier SEAT_MODS_ALLOW="$HOME/seat-scratch/verify" claude "$@"
}
claude-review() { SEAT_MODS_ROLE=reviewer SEAT_MODS_ALLOW="$HOME/seat-scratch/review" claude "$@"; }
```

A plain `claude` with no role is a guarded implementer — the default above. So start every
session you drive through the `orchestrator` launcher, or that session cannot merge, push a
deletion or write outside its worktree.

An alias or function that sets the variable on one command does not break the rule above. The
variable reaches only the session that command starts. An `export` in a shell profile reaches
every session, the orchestrator's included.

The role names are the contract between seat-mods and any launcher. A launcher that writes
`orchestrator` or `coordinator` needs seat-mods 0.2.0 or later: 0.1.0 reads both as invalid and
denies every tool call.

## The guards

Each is a `tool.call` deny on Bash, Edit or Write.

| Guard | implementer | verifier | reviewer |
|---|---|---|---|
| `git merge`, `gh pr merge` (also after `gh pr -R/--repo`) | deny | deny | deny |
| Force-push (`--force`, `-f`, `--force-with-lease`, `--mirror`, a `+` refspec); branch deletion (`git branch -D`, or `-d`/`--delete` with `-f`/`--force`; `git push --delete` / `-d` / `--prune` / `:branch`) | deny | deny | deny |
| `--no-verify` on any git command (and `git commit -n`) | deny | deny | deny |
| A commit message with `Co-Authored-By:` or `🤖 Generated with` — on the command line, in a heredoc, or in the `-F` / `--file` message file | deny | deny | deny |
| Edit or Write outside the worktree, `/tmp`, `$TMPDIR` and every `SEAT_MODS_ALLOW` directory (the deny names `/tmp`, `$TMPDIR` and those directories as the place for scratch files) | deny | deny | deny |
| `rm` outside writable places, with unresolvable operands, or removing a writable root or its ancestor (an operand it cannot read is told to spell its path out literally) | deny | deny | deny |
| `rm` inside the worktree (below its root) | allow | allow | deny |
| `rm` inside a `SEAT_MODS_ALLOW` directory, or below `/tmp` or `$TMPDIR` (below its root; see Scratch places) | allow | allow | allow |
| `git commit`, `git push`, `gh pr create` | allow | deny | deny |
| Edit or Write inside the worktree | allow | allow | deny |
| Edit or Write inside a `SEAT_MODS_ALLOW` directory, or below `/tmp` or `$TMPDIR` | allow | allow | allow |

The worktree is the git top level of the session's working directory (outside a git repository,
the working directory itself). Paths are compared after the file system resolves them, so `..` and
symbolic links land where they really point; a file in folders that do not exist yet is placed by
its nearest existing folder.

`rm` checks operands of commands it recognises, including operands beginning with `-` after `--`.
Relative operands
use the live shell directory from `$.session.cwd()` at the call. This was measured on Claude Code
2.1.294 on 2026-10-08: after a Bash `cd` into a project subdirectory, the next call's hook and
`pwd` both reported that subdirectory; after Claude reset an outside-project `cd`, both reported
the project directory. A `cd` earlier in the **same** call moves that start only as the `cd` and
variables section below reads it; any other recognised `cd`, `pushd` or `popd` makes relative
operands unresolvable and denies them. Absolute operands remain eligible. `worktreeOf()` keeps
its existing behavior: the worktree is derived from that live directory.

Operands containing a command substitution, a parameter expansion other than a plain `$NAME` or
`${NAME}` that a literal assignment in the same call gave (`${NAME:-x}`, `${#NAME}`, `${HOME}`), and
`~user`, `~+` and `~-` operands, cannot be resolved and are denied, including `rm -rf "$OLDPWD"`.
Single-quoted text and escaped characters are literal. Any other `$` in an operand is treated as
unresolvable, including an inert dollar sign. Bare `~` and `~/...` use `HOME`. A glob is placed by
the directory of its literal
prefix: `/etc/tmp.*` is outside, while `build/*.o` is placed in the live directory's `build`.
The resolver follows links in parent directories, but keeps a terminal link literal because
`rm` removes the link itself; a trailing `/` follows the directory. A writable root itself or
its ancestor cannot be removed. A glob whose literal-prefix directory has a writable root
strictly below it is denied, since it could match that root; a glob at the root is eligible when
no writable root lies below it. Unquoted `{` and a glob suffix containing a `..` component are
unresolvable and denied.
A glob component starting with `.` and containing `*`, `?` or `[` is unresolvable and denied.
Redirections, heredoc input and their destinations are excluded from `rm` operands.
An fd prefix such as `2<<EOF` supplies shell input. On every Bash rail a heredoc's delimiter is
its word after Bash's quote removal (`<<\EOF`, `<<E'OF'` and `<<"E"OF` all close at a line
`EOF`; `<<E"O\F"` closes only at `EO\F`), a body line ending in a backslash joins the next only
in an unquoted body, several heredocs on one line close in order, a heredoc inside a `$(…)` also
closes at a line that starts with its delimiter and holds a `)` after it (`EOF)`), as in Bash 5.3,
and a `<<` inside `$((…))`, `((…))` or a `#` comment opens none. Words and redirections after the
delimiter word on the opener line remain part of the command and meet the usual operand checks;
only the opener, its body and its closing line are excluded, and a single `&` separates commands
for `rm`. The exceptions are in Limits: a `$'…'` or `$"…"` delimiter, an opener line with a `$(…)`, a
backtick or a `${…}` after the delimiter word, a quoted `<<` after one of those, a `<<` inside an
unquoted `$[…]` or a `${…}`, and an `EOF)` line the reader does not see closing. Every
Bash rail skips the unquoted reserved words
`if`, `then`, `elif`, `else`, `do`, `while`, `until`, `!`, `{`, `(` and `time` at a command's
head, before assignments or execution wrappers. A path such as `/tools/if`, or `if` after
`A=1` or `env`, names a program; its arguments are not another command. The `builtin` execution
prefix is handled separately, without treating its arguments as reserved words; `builtin cd`
and `\cd` count as directory changes. A parsing or resolution exception denies the Bash call as a command
that could not be checked; forged self-referencing or excessively nested markers are rejected.

A deny reads `seat-mods (<role>): <rule> — this seat may not <action>; report it instead.`

### What the Bash rails stop, and what they leave to the next judge

seat-mods reads free shell text, so it can miss a command, and it can only add a stop. A call it
passes is not approved: it goes on to the next judge (the brief, the permission mode, git hooks,
the server) exactly as if seat-mods were absent. For each way the reader looks at a command:

- **Substitutions and backticks.** Stops a ruled command inside `$(…)` or a backtick span, on every
  rail (the `rm` operands and the `-F` message file too): unquoted, in double quotes, on a heredoc
  opener line or in an unquoted heredoc body, nested up to 8 deep. Leaves single-quoted text and
  quoted heredoc bodies, which are text in Bash; a command inside a Bash 5.3 funsub (`${ …; }`,
  `${| …; }`), which no rail reads; and the shapes in Limits where the reader loses a span's end.
  A command nested more than 8 substitutions deep is refused, reported as `no force-push`. That is
  an accepted false stop: no honest command nests that deep.
- **Heredocs.** Stops a ruled command on a heredoc's opener line after the delimiter
  (`cat <<EOF; git push --force`), on the line after its closing line, and after a `<<` inside
  `$((…))`, `((…))` or a `#` comment, which open no heredoc. Leaves the body and the closing line,
  which are text, and the fallbacks in Limits: when an opener line holds a `$(…)`, a backtick or a
  `${…}` after the delimiter word, a ruled command after the substitution on that line stays hidden,
  as in 0.9.0 (an `rm` there is still read, though the `cd` walk does not start); and a `<<` in an
  unquoted `$[…]` or a `${…}` still opens a heredoc.
- **The command word and glued redirections.** Stops a ruled command whose head is escaped
  (`\rm -rf …`, `\git push --force`), follows a named descriptor (`{log}>f rm -rf …`), or has a
  redirection glued to a flag (`git push --force>&2`, `--force&>f`, `-f>/dev/null`). Leaves a
  quoted command word (`"rm" -rf …`, `"git" push --force`) and a subscripted or `+=` prefix
  (`A[0]=1 rm -rf …`, `A+=1 rm -rf …`), which are not read as the command (#1182).
- **Scratch places** and **`cd` and variables, for `rm`**: below.

### Scratch places

Beside the `SEAT_MODS_ALLOW` directories, every guarded role may Edit, Write and `rm` below `/tmp`
and below `$TMPDIR`, read from the seat's own environment on both hosts. Only descendants count:
`rm` of the directory itself or of an ancestor (`rm -rf /tmp`, `rm -rf /`) is still denied, and a
`..` out of it lands outside. A relative `$TMPDIR`, `/` and a directory that does not resolve name
no place. A link counts by both spellings (on macOS `/tmp` and `/private/tmp`). `rm -rf /tmp/*` is
allowed, which is the accepted cost: a seat can remove another session's scratch files. Limits
names two more limits of the scratch places.

### `cd` and variables, for `rm`

A relative operand is placed from the session's directory. Inside one call the reader follows a
literal `cd <path>` and literal `NAME=value` assignments in a plain `;`, `&&` or newline sequence
from the call's start, so `cd /w/wt && rm -rf pf/__pycache__` is placed, and so is
`WT=/w/wt; cd "$WT" && rm -rf pf/__pycache__`. With no `WT=` earlier in the call, `cd "$WT"` names an
unknown variable and the `rm` after it is unresolved.

- A `cd` before `;` or a newline may fail, and Bash then runs the next command where it stood. So
  an `rm` after one is checked in every directory it may run in, one target each, and every target
  must be writable; after `cd X &&` it runs in X only. More than four possible directories is
  unresolved.
- A `$NAME` or `${NAME}` reads the value of a literal assignment: no `$`, backtick, parenthesis or
  redirection in it, and no blank, glob, quote, brace or `~` once unquoted. A variable stays known
  only across literal assignments, a literal `cd` and a bare `rm`; any other command forgets them
  all (`WT=/w/wt; echo "$WT"; rm -rf "$WT/x"` is refused).
- Unresolved, so refused as before: a `cd` in a subshell or an `if`, after `||` or in a pipeline;
  `cd -`, `cd ..`, `cd ~` and a `cd` with an option, a glob or an unknown variable; `pushd`,
  `popd`, `command cd` and `builtin cd`; a `cd` before a Bash 5.3 funsub. `eval`, `source`,
  `export`, `read`, `printf` and the other builtins that run text or change shell state end the walk: no variable is
  read after them, and a directory a `cd` moved to is unknown. Limits lists what the walk does not
  model.

## Kill rail (#1099)

On 2026-11-05 an OMP orchestrator seat stopped one of its own background jobs by running
`kill $(ps -eo pid,args 2>/dev/null) 2>/dev/null; true` and signalled every process on the host. The
rail refuses that class of call. **It covers every role**: `orchestrator` and `coordinator`
included, unset and invalid roles, and OMP child agents; it runs before each role check. Skill-first
question 3: a mechanical check on open shell text that can only refuse. A call it passes is not approved;
it goes on to the role checks and the model exactly as if the rail were absent. On Claude Code it reads
`Bash` and `Monitor` (Monitor's `command` field, as found in Claude Code 2.1.319); on OMP it reads `bash`,
and `eval` best effort through its string literals, and an implementer's `debug` launch.

**On OMP it also reaches a plain session** (#1102). `package.json`'s `omp` manifest names `omp/kill-rail.ts`, the rail
alone (`bash` and `eval`; not `debug`), so every omp session with seat-mods enabled, unless started with `--no-extensions`, loads it after `omp plugin upgrade`, whether or not `omp-seat` launched it. That
entry ignores `SEAT_MODS_ROLE` and the agent kind: a plain session keeps every other freedom, and the role
guard stays `omp-seat`-only. An unreadable `bash` command is refused with the same stop a free role gets; an unreadable `eval` string literal passes, as a literal need not be shell; it also turns off the joined reading of the code, the one that sees an argv list, so an argv-list kill beside it goes on to the model. Under
`omp-seat` the rail runs twice, once from the manifest and once inside the guard; that is harmless, as the first
block wins. The one visible difference: for a bash command the rail cannot read, a guarded seat gets the rail's stop first,
not its role's own deny text. `omp plugin disable seat-mods` turns the ambient entry off and leaves `omp-seat` alone.

It refuses:

- **A call that both lists processes and signals.** A `ps`, `pgrep`, `pidof` or `ls /proc…` head
  anywhere in the call (substitutions, pipes and loops included) together with `kill` or
  `xargs … kill`. So `kill $(pgrep -f x)`, `ps … | xargs kill`, `for p in $(pgrep x); do kill $p; done`
  and `P=$(pgrep x); kill $P` are refused. `kill $(cat pidfile)` is not, and neither is a call that
  only lists.
- **`kill` with `-1`** in any operand position (also `-01`, and with blanks around it), **`0`** (`kill 0`,
  `kill 00`, `kill +0`, `kill -- 0`, `kill -- -0`; `kill -0 <pid>` is allowed), or **a negative operand that
  holds a `$` or a backtick** (`-$X`, `-"$X"`, `-${X}`, `-$((…))`, ``-`cat f` ``): a variable may be empty
  or `-1`. Spell a process group with its number (`kill -- -4242`). An operand is read as bash's `kill` reads a
  number: blanks (space, tab, newline, vertical tab, form feed, carriage return) before the sign and after the
  digits, however they are spelled, and a `+` sign (`kill -9 '-1 '`, `kill -9 -1\ `, `kill -9 "0 "`,
  `kill -9 -- '-0 '`, `kill -9 " -$X"`; `kill -9 '123 '` passes). A word that starts with a blank is never an option
  to bash's `kill`, so `kill -9 ' -0'` is refused without `--`. `kill`'s options are read at its first word only, as
  zsh reads them (bash reads one `-word` as the signal and ends its options at the first operand), so a `-0` after the
  first word is the pid 0 (`kill -9 -0`, `kill -s 9 -0`, `kill 123 -0`), and a later `-s`, `-n` or `--signal` is an
  operand, as is the word after it (`kill 123 -s -1`, `kill -9 -s -1`). zsh's `kill` reads a later word made only of
  digits and `-` as a pid with `atoi`: the sign and the digits up to the next `-`, held to a 64-bit long's range, then
  cut to a 32-bit int, so `kill 123 -`, `kill -9 0-1`, `kill -9 -1-`, `kill -9 123 --`, `kill 5 -- 123` and `kill 4294967295` signal 0
  or -1 there and are refused; `kill -9 -- 123`, `kill -s KILL -- -4242`, `kill -9 -12-` and `kill 4294967294` pass.
  Every operand is also read as procps-ng's `kill` reads a pid, which a path, `env`, `sudo`, `xargs` and `nohup` run:
  its options are read at any word, so `-s`, `-q`, `--signal` and `--queue` take the next word, and every word that
  does not start with `-` is read with `strtol` (C blanks and a `+` or `-` before the digits, within a long's range)
  and cast to a 32-bit `pid_t`, so `/bin/kill +4294967295`, `/bin/kill ' 4294967295'` and `env kill +4294967295`
  signal -1 there and are refused; `/bin/kill +4294967294` and `kill -s 0 1234` pass.
- **`pkill` and `killall` by user** (`-u`, `-U`, `--euid`, `--uid`, `--user`; also inside a cluster such as `-fU`),
  **with no pattern** (`--help`, `--version`, `-V` and `-h` name none and pass), or with **a
  pattern that matches every name of a fixed probe set** (`systemd`, `bash`, `node`, `x`; `.`, `.*`, `''`,
  `[a-z]`). `killall -r` gets the same test. A signal word (`-9`, `-HUP`, `-SIGUSR1`) is not read as an option.
- **`killall5`**, **`systemctl --user`** with `exit`, `isolate`, `kill` or `stop default.target` (any argument
  order), and **`loginctl`** `terminate-user`, `kill-user`, `terminate-session` or `kill-session`.

An unquoted `$(…)` or `$((…))` counts as one word of its command, so `kill 123 $(cat p) 0` is read whole. The span is bounded by counting parentheses, not by the shell's grammar: a `case` pattern's `)` or a `)` inside `${…}` ends it early (a known limit), and a `(` inside `${…}` leaves it open, so the call is refused as unread. `command -v NAME` and `command -V NAME` run nothing and pass.

It reads past assignments before the command word as bash and zsh take them: `NAME=`, `NAME+=`, `NAME[…]=` and
`NAME[…]+=`, with any characters in the subscript (`A+=1 kill -1`, `a[1]=x kill -1`, `a["]"]=1 kill -1`;
`A+=1 echo hi` passes). A word that holds `=` but is not `NAME=…` is also read as the command word, its path taken
off, as the rail read it before, so `A+=/bin/kill -1` is refused. It reads through `sudo` (with its options), `env`, `command`, `builtin`, `exec`, `nohup`, `time`, `timeout`,
`setsid`, `nice`, `ionice`, `stdbuf`, `chrt`, `taskset`, `flock` and `busybox` (the next word is the applet: `busybox sh -c '…'`, `busybox kill -1`; each with its common options, and `--`);
through a path (`/bin/kill`), a quoted command word (`'kill'`, `k""ill`) and the shell's reserved heads, among them
the reserved `time`: unquoted at a command's head, and in bash after an optional `-p` and then an optional `--`, it times a pipeline, so a head word or
another `time` after it is read through (`time ! kill -1`, `time -p if kill -1; then :; fi`, `time -- ! kill -1`,
`time time ! kill -1`). Any other `time` the rail reads as the time program with its options (bash still reserves `time -f %e ! true`, running `-f` as a command; the rail reads the kill through it, the safe direction), and a head word after it, as after any other
wrapper, names a program: `A=1 time ! kill -1`, `'time' ! kill -1`, `time -p -p ! kill -1`, `nohup ! kill -1` and
`xargs time ! kill -1` run a program named `!` or `-p`, and pass; zsh's reserved `repeat` with its count (any one word, which
the rail does not evaluate), unquoted at a command's head or after a head word or the reserved `time` (`repeat 1 kill -1`,
`time repeat 1 kill -1`, `repeat 1 time ! kill -1`, `repeat 1 do kill -1; done`, `repeat 1 { kill -1 }`); zsh's reserved
`nocorrect` (unquoted) and its precommand modifiers `noglob` and `-` (quoted or not), at a command's head, after
assignments and after `builtin`, `exec` and `time` (`nocorrect kill -1`, `time noglob kill -1`, `A=1 noglob kill -1`,
`builtin noglob kill -1`, `- kill -1`). After any other wrapper, or under `xargs`, each of these words names a program, as
in zsh, and so does a quoted `repeat` or `nocorrect` or one after an assignment: `nohup noglob kill -1`, `xargs repeat 1 kill -1`,
`'repeat' 1 kill -1` and `A=1 repeat 1 kill -1` pass; and
into a literal `eval '…'`, `sh|bash|rbash|zsh|dash|ash|static-sh|ksh|ksh93|mksh|lksh|mksh-static|yash -c '…'` or `fish -c '…'` string, once. The string is the word as the outer shell hands it on, after its quote removal: a backslash outside quotes, `'…'`, `"…"`, `$'…'` (decoded as bash decodes it, where a NUL ends its own `$'…'` part, and beside that as zsh decodes it: an escape zsh does not know loses its backslash, `\C-x`, `\Cx`, `\M-x` and `\Mx` are read, `\cX` is handed on as `cX`, `\x`, `\u` and `\U` with no digit are a NUL, `\x` takes a sign (`\x-1` is 0xff), and a NUL ends the whole word, or inside `eval` is read as a blank) and `$"…"` are undone, so `bash -c kill\ -1`, `eval kill\ -1`, `bash -c $'kill\x20-1'` and `bash -c 'kill'\ '-1'` are read as `kill -1`, `bash -c $'echo\C-jkill -1'`, `bash -c $'kill -1\0'x`, `bash -c $'kill\ -1'` and `bash -c $'system\ctl --user exit'` are read as zsh hands them on, and a fish `-c`, `-C` or `--command=` value attached to its option word gets the same (`fish -ckill\ -1`, `fish --command=kill\ -1`). The earlier reading, which takes the quote characters off and keeps every backslash, is read beside it, and the call is refused if either reading's string is. A POSIX shell's string is found three ways (and, for six names, a fourth), as bash reads
the options (before and after `-c`, one value for each `o` or `O` in a short option cluster wherever it sits, one
`--`; after `-c`, a bare `-` ends the options and a bare `+` is skipped) and as zsh reads them (`-O` takes no value, `o` takes
the rest of its cluster, a bare `-`, a bare `+`, `--`, a cluster holding `b` or a cluster ending in `-` ends the options, and a leading
`--emulate` takes a value) and, only when an option word holds a `-` after its first character (a `--name` word included, since busybox ends it at the second `-`: `busybox sh -c -b --rcfile 'kill -1' x` is refused), as Debian and Ubuntu busybox ash reads them (`-c- -e 'kill -1'`, `-c-o 'kill -1' x`: the `-` ends that cluster and the options go on), for every one of the names, and the call is refused if any string is. `rbash` is bash and was probed as such. `ksh` and `ksh93`, `mksh`, `lksh` and `mksh-static`, and `yash` get a fourth reading each, used only for that name and probed on ksh93u+m 1.0.10 (macOS ksh 93u+ agrees), mksh R59c (`lksh` parses identically on all 8420 forms tried; `mksh-static` is a static build of the same source and agreed on the `-o -c`, `-o ''`, `-o +c` and `-c -` forms probed) and yash 2.55 (#1126). `ksh` is read as both ksh93 and mksh, since on Debian and Ubuntu without ksh93 `/bin/ksh` is an alternative of mksh. ksh93 runs a first operand that names no file as a command, with `-c` or without (`ksh 'kill -1'`, `ksh -e 'kill -1'`, `ksh +c 'kill -1'`), and its `-o` takes the next word unless that word is an option (`ksh -o -c 'kill -1'`). mksh's `-T` and `-o` take the next word whatever it is, and an `-o` value of `-c`, `+c` or the empty name sets `-c` (`mksh -T /dev/tty2 -c 'kill -1'`, `mksh -o -c 'kill -1'`). yash's `-c` is also the option `cmdline`, under any prefix, any case and any punctuation (a one-letter prefix too, which yash itself rejects as ambiguous, so `yash --c 'kill -1'` is a false stop) (`yash -o cmdline 'kill -1'`, `yash --cmd 'kill -1'`, `yash ++nocmdline 'kill -1'`), and its `--profile` and `--rcfile` take the next word under any prefix (`yash --profile p -c 'kill -1'`). `fish` gets a reading of its own and not the three, probed on fish 4.2.1 (#1127): its options are read as fish reads them, with no permutation, so `--`, a bare `-` or the first operand ends them; `-c` and `-C`/`--init-command` take the rest of the cluster or else the next word, and every value is read, since fish runs every one (`fish -c 'echo ok' -c 'kill -1'`, `fish -C 'kill -1'`); a long name is any unique prefix, with `=value` or the next word (`fish --command='kill -1'`, `fish --comm 'kill -1'`, `fish --init 'kill -1'`); and `p`, `d`, `f`, `D` and `o` take a value (`fish -p -c 'kill -1'` runs nothing and is allowed). Each fish string is read as POSIX text, and again with fish's command prefixes taken off: `and`, `or`, `not` and `begin`, quoted or not (fish reads `'not'` and `n""ot` as `not`), and a block's `{`, at the head of a command: the start, after `;`, `&`, `|` or a newline, after a block's `{`, after a substitution's `(` or `$(` (inside double quotes too), and after `if`, `while`, `else`, `!` or `time`, so a `{` after a prefix is taken off too (`fish -c 'true; and kill -1'`, `fish -c 'not kill -1'`, `fish -c 'begin kill -1; end'`, `fish -c '{kill -1}'`, `fish -c 'not {kill -1}'`, `fish -c 'echo (not kill -1)'`, `fish -c "'not' kill -1"`). Every other name, `sh` included, keeps the verdict it had. A refusal says what to do instead: list first, read
the PIDs, kill by literal PID in a separate call; to stop your own job use `write proc://<id>/kill` (OMP)
or `TaskStop` (Claude Code). Those two stops are not shell, so the rail never sees them. On OMP a
guarded role may `write` an exact `proc://<id>/kill` (`^proc://[A-Za-z0-9_-]+/kill$`, as it may `local://<name>`);
omp scopes a job or agent id to its owner; a service name is stopped project-wide, as `kill <pid>` through bash already allows. Every other spelling, and `edit` of it, is placed as before.

A compound command's close ends it, and a reserved word may follow it: `}`, `fi`, `done` and `esac` at a command's
head, and a `]]` anywhere, are taken off, so `if { true; } then kill -1; fi`, `if false; then { true; } else kill -1; fi`,
`if false; then for x in 1; do :; done else kill -1; fi` and `if [[ 1 ]] then kill -1; fi` are refused (bash, dash and
zsh). zsh's brace grammar is read beside it, in one pass over a command's words: a `{` glued to a head word opens a
group (`{kill -1}`, `true;{kill -1}`, `time {kill -1}`, `repeat 1 {kill -1}`); a sole `}`, or one glued to a word's end
that closes no `{` of the word's own, closes a group while one opened at a head is open, counted over the command's
segments (`{ kill -1}`, `{ true; kill -1}`; not `${X}` or `{a,b}`, and not `kill -1}` or `echo } kill -1`, where no
group is open); the words after a `]]` or a group's `}` are read as a command (the short `if [[ 1 ]] kill -1`,
`while [[ 1 ]] { kill -1; break }`, `if { true } kill -1`, `if [[ -z 1 ]] { true } else { kill -1 }`), and so are
those after an `always` between a group's `}` and a `{` (`{ true } always { kill -1 }`); and `function`, then any
`-T` or `--`, then a `{` is an anonymous function, which runs at once (`function { kill -1 }`, `function -T { kill -1 }`).
A named function is defined, not run: `function f { kill -1 }` passes, and so do `function -x { kill -1 }` and
`function - { kill -1 }`, which define a function named `-x` or `-`. These words are read beside the reading before, and
the call is refused if either reading refuses.

`env` is read three ways, and the call is refused if any reading is: with the generic wrapper options above, as GNU
coreutils, busybox and uutils read it, and as FreeBSD and macOS read it (GNU coreutils 9.7, uutils 0.8.0 and busybox
1.37 probed; FreeBSD's and macOS's read from source). Each takes its own value options (`-u`, `-C`, `-S`,
`-a`/`--argv0`, `-f`/`--file`; BSD's `-P`, `-L`, `-U`) and any prefix of a long one (`env --uns X kill -1`), its bare
`-` (`env - kill -1`, `env -- - kill -1`, `env A=1 - kill -1` on uutils, `env - -i kill -1` on BSD) and any word that
holds `=` (`env a-b=1 kill -1`). `env - echo kill -1`, `env -- -i kill -1` (every env runs `-i`) and `env -a x echo hi`
pass. A `-S` or `--split-string` string (any prefix of the long name, attached or not, in a cluster: `env -S 'kill -1'`,
`env -S'kill -1'`, `env --sp='kill -1'`, `env -iS 'kill -1'`) is split into words as GNU, uutils and FreeBSD env split
it, and those words and the words after the string are read again as the command line after env's options, as GNU
env reads them again (`env -S 'kill\_-1'`, `env -S '-i kill -1'`, `env -S 'kill' -1`, `env -S 'bash -c "kill -1"'`).
The split is the union of the three grammars: blanks part words outside quotes; `'…'` is literal but for `\\` and
`\'`; `"…"` and bare text take `\_` (a blank inside `"…"`, else a word break), `\c` (the end), `\f`, `\n`, `\r`, `\t`
and `\v`, and any other escaped character as itself; a backslash-newline is dropped; a `#` that starts a word skips to
the next newline; `${NAME}` and `$NAME` are read empty and, beside that, as their text (GNU and uutils expand them
from env's own environment, so `PGID=1 env -S 'kill -9 -${PGID}'` is refused as `kill -9 -$PGID` is); and an open
quote runs to the end. A word that starts with `-S` among the assignments is split too, as uutils splits it
(`env A=1 -S'kill -1'`), but not after `--`. Only the first `-S` string of a walk is split: a later one, in the same
env or in a later env of the same command, is split where that line is read again (`env -S '-S kill\_-1'`,
`env -S 'env -S kill\_-1'`), and `env -S 'echo hi' env -S 'kill -1'`, where env runs `echo`, passes. A string with
no words is passed over and the walk reads on, as env does (`env -S '' env -S 'kill -1'` is refused). Each line is
read once per call, at the least nesting it is met at, after the call's own text, so a chain of `env -S` strings
takes time linear in its length. `env -S 'echo hi'`, `env -S 'echo kill -1'`, `env -S '#kill -1'`,
`env -S 'echo a; kill -1'` (env has no `;`), `env -S 'kill 123 \c -1'` and `env -- -S 'kill -1'` pass.

Every word of a command is also read after the outer shell's quote removal, as bash does it and as zsh does it, beside
the reading that takes its quote characters off: the command word, a wrapper, a runner's name and the operands
(`$'\x6bill' -1`, `kill $'\x2d1'`, `kill \ -1`, `systemctl --user $'\x65xit'`, `$'\x70s' aux; kill 123`,
`$'\x62ash' -c 'kill -1'`). zsh's decoding is the one described for a `-c` word above, and in its reading a NUL ends
the word (`$'kill\0'x -1`, `$'\k\i\l\l' -1`, `$'system\ctl' --user exit`). Reserved words are read unquoted only, so
`$'\x74ime' ! kill -1`, which runs the time program, passes, as do `echo $'\x6bill' -1` and `kill -s $'\x2d1' 123`.

A string the rail cannot finish reading (an unclosed `$(`, a nesting too deep) does not hide a refusal in another reading, segment, runner string or substitution: the rail reads the rest and refuses with the kill reason if any part refuses, and treats the call as unread only when nothing refused. An unclosed `$(` outside quotes still makes its whole string unread, so a refusal earlier in that string (`kill -1; echo $(x`) is not found; the call is unread, as before.

A `bash` command the rail cannot read is refused (on the ambient OMP entry, an `eval` literal it cannot read passes), after a guarded role's own reader has had its say: a
forged marker, text it throws on, a substitution that never closes, a substitution nested more than 8 deep, an `xargs` chain more than 8
deep (a chain that long is not walked), and an `env -S` line read again more than 8 deep (a string nested in another
more than 8 deep, or a chain of more than 8 env each with a non-empty string; a runner's string inside a line
is read at that line's nesting). A `-c` or `eval` word is held to this after its quote removal too: `bash -c echo\ \$\(` hands bash `echo $(`, a substitution that never closes, and is refused as unread, as `bash -c 'echo $('` is, and so is `bash -c $'echo \$\('`, which zsh hands on as `echo $(`.

Deliberate false stops: a call that lists and signals in one (`ps aux; kill 123`), `kill -1 <pid>`
(SIGHUP; write `kill -HUP`), and `kill -$SIG <pid>`. Split the call, or spell the number. A shell call
whose options one shell reads one way and another reads another way is refused when either reading's string is
refused, though the shell that runs it runs at most one of the strings, and often none (`zsh -cO extglob 'kill -1'`).
A bare `-` before `-c` is also skipped by the bash reading, so `bash - -c 'kill -1'` stays refused as in 0.14.1, though
no shell runs either string. Every reading's heads go into one scan, a shell's option readings and the
readings of a command's words alike, so a list found in one reading and a signal in another are refused together:
`bash -cO 'ps aux' 'kill 123'`, where one option reading lists and the other signals, and `$"ps" aux; $'\k\i\l\l' 123`,
where bash's quote removal lists and zsh's signals, are refused as calls that list and signal. `yash -c + 'kill -1'`, where yash runs the `+` and the kill text is only `$0`, is refused too. The fourth readings also refuse forms where the shell itself runs nothing (it fails on an unknown option or option value, or runs `-s`, `-D` or `-n`): on the 6174-form grid of 0.14.2, 581 forms for ksh where it is ksh93 and 679 where it is mksh (`ksh` gets both readings), 141 for mksh and 154 for yash, and none where the shell runs the other string. `lksh` shares mksh's false stops from the three generic readings (33 forms of the mksh grid where lksh runs the other string, such as `lksh -cT -o 'echo S1' 'kill -1'`). fish's reading takes a `-c` or `-C` value even where fish then runs nothing: after `-n`/`--no-execute`, beside `-v` or an unknown option (`fish -e -c 'kill -1'`), after an ambiguous prefix (`fish --i 'kill -1'`, which could be `--interactive` or `--init-command`), and when a value-taking option is left with no value (`fish -c 'kill -1' -p`): 4448 forms of the fish option grids, none where fish runs the other string. Text fish quotes and POSIX does not is read as code, so ``fish -c 'echo `kill -1`'`` (fish has no backticks) is refused. The reserved `time` is read where some shell runs nothing. The mechanism: the rail drops a backslash before a letter, digit or `-` and drops redirections before it compares `time`, `-p`, `--` and the head words, so a backslash inside one of them (`t\ime`, `time \-p`, `time i\f`) or a redirection before or between them (`>/dev/null time ! kill -1`, `time ! 2>&1 ! kill -1`) is read as if absent. The forms include: `\time ! kill -1`, since the reader takes `\time` as `time` though the shell runs the time program, which runs a program named `!`; `time then kill -1` and the like, where a word that only continues a compound command follows `time` and bash rejects the line; the `-p` and `--` after `time` under zsh and fish, which take neither (`zsh -c 'time -p ! kill -1'`, `fish -c 'time -- ! kill -1'`); dash, whose `time` is not reserved, so `dash -c 'time ! kill -1'` runs the time program too; a redirection between `time` and the head word (`time >/dev/null ! kill -1`), which no shell runs; `time time`, `time ! time` and `time ! !` under zsh, and `time time` under fish; and a `time` after `|` under bash and fish, which reserve it only at a pipeline's start (zsh times it there, so the refusal is right for zsh). bash's quote removal and zsh's are both read, in every shell, on a `-c` or `eval` word and on every word of a command, since the rail cannot know the outer shell (Claude Code's shell is zsh on macOS and is often bash on Linux), so a form one of the two shells runs is refused under the other too. Under a zsh outer shell, which hands on a `$"…"`'s `$` and its text, `bash -c $"kill -1"` and `$"kill" -1` run no kill. Under a bash outer shell, which keeps the backslash of an escape it does not know, keeps `\C-x` and `\M-x` as text, decodes `\cX`, and ends only the `$'…'` part at a NUL, `bash -c $'kill\ -1'`, `bash -c $'echo\C-jkill -1'`, `bash -c $'kill -1\0'x`, `$'\k\i\l\l' -1` and `$'kill\0'x -1` run no kill. The two shells' readings also meet in one form: zsh's `noglob`, `nocorrect` and `-` are read beside bash's quote removal of the next word, so a form neither shell runs is refused: `noglob $'\x6b'"i"$"l""l" -1` and `nocorrect ki$'\154'$"l" -1`, where bash runs a program named `noglob` or `nocorrect` and zsh hands on `ki$ll` or `kil$l`. A NUL in an `eval` word is read as a blank, as zsh's `eval` reads it where it ends a command name, so `eval $'\0 kill -1'` (zsh runs an empty command name) and a NUL inside `kill`'s operand there (`eval $'\k\i\l\l\ '$'-1\0zz'`, where kill gets an operand that is not a number) are refused. zsh's reading of a command's words ends every word at a
NUL, the builtin `kill`'s operands too, though zsh's `kill` keeps the NUL and bash's `$'…'` hands on the text after it,
so a NUL in `kill`'s operand with text after the `$'…'` part is refused, though neither shell's kill gets a number
(`kill $'-1\0'x`, where bash's kill gets `-1x`, `kill -9 $'-1\0'x`, `kill $'0\0'x`); `kill $'123\0'x` passes. A character that a `-c` or `eval` word's `$'…'` hands on and that is not a blank to the shell but is white space to the rail (a vertical tab, form feed, carriage return, or a no-break space in Latin-1 or UTF-8) is split at by the rail, as it does in `bash -c 'kill 123<VT>-1'`: `bash -c $'kill 123\v-1'`, where kill gets the one operand `123<VT>-1`, is refused, and so is the same character in an operand (`kill $'\v-1'`). The earlier reading of that word keeps its own stops (`bash -c k'ill '$'--\\ -1'`, where bash hands on `kill --\ -1` and kill gets the one operand `-- -1`), and so does the earlier reading of a command's words (`kill "'"-1`, where bash hands on `'-1`). An option an `env` rejects is read as a flag, though that env runs nothing: an unknown letter, `-0` with a command, `-S`'s string, or a GNU-only option beside a BSD-only one (`env -x kill -1`, `env - -0 kill -1`, `env -ax -P /usr/bin kill -1`); and the generic reading's stops stay (`env -a kill -1`, where GNU runs `-1`; `env A=1 -i kill -1`, where every env runs `-i`). zsh's `repeat`, `nocorrect`, `noglob` and `-` are read in every shell: in bash, dash and fish each names a program a stock host lacks, so the form runs nothing (`dash -c 'noglob kill -1'`). They are also read where zsh runs nothing: a count the rail does not evaluate (`repeat 0 kill -1`, and `repeat echo kill -1`, whose count is `echo`); a backslash in `repeat` or `nocorrect` (`\repeat`, `re\peat`, `nocorrec\t`), since the reader drops a backslash before a letter as with `\time`, though zsh then runs a program; and a chain of zsh's words that zsh rejects or where it runs a program, such as `nocorrect` or an assignment after another of them, or a word after `-` (`noglob nocorrect kill -1`, `exec nocorrect kill -1`, `nocorrect time kill -1`, `noglob A=1 kill -1`, `- noglob kill -1`, `- time kill -1`, `builtin nocorrect kill -1`, `time -p noglob kill -1`, `noglob >/dev/null kill -1`). `kill`'s options are read at its first word only, and zsh's pid reading after it, so a `-0` or a zsh pid word is refused where no shell signals: after a listing (`kill -l -0`, `kill -L -0`), after a first word bash and zsh reject (`kill - -0`, and `kill -sKILL 0-` and `kill -n9 -1-`, where zsh takes `sKILL` or `n9` as a signal name and bash's kill gets an operand that is not a number), where bash's option reading and zsh's meet in one form (`kill -9 -s '-0 '`: zsh takes `-s` as a pid, bash's number reading takes `-0 `), and where one reading of the words spells the signal and another does not (`kill $'\x2d\x39' - 1`: decoded, zsh drops the `-` and bash's kill rejects it, while the reading that only takes quotes off sees no option word, so the `-` is a zsh pid). An assignment is skipped as bash and zsh skip one, so a prefix dash and busybox sh run as the command is skipped too (`dash -c 'A+=1 kill -1'`), and so is one the rail's readings drop quotes or backslashes from (`'A+'=1 kill -1`, `"a[1]"=x kill -1`, `A\+=1 kill -1`, `a[1]\=x kill -1`), as `'A=1' kill -1` already was, and one no shell takes (`a[1][2]=x kill -1`, `a[x]]=1 kill -1`); behind `nohup` and `xargs`, which run a program named `A+=1`, `nohup A+=1 kill -1` and `xargs A+=1 kill -1` are refused, as `nohup A=1 kill -1` already was. An `env -S` string is read loosely, as the union of the three grammars, so these are refused though no env runs a kill: a `#` comment read to the next newline and a dropped backslash-newline in the separate-word form, which uutils does not split and GNU and FreeBSD end at the `#` or reject (`env -S $'#c\nkill -1'`, `env -S $'ki\\\nll -1'`); an escape or a `$NAME` GNU rejects (`env -S 'kill \q -1'`, `env -S 'kill $HOME -1'`); an open quote (`env -S 'kill "-1'`); quotes the reading that takes them off drops (`env -S "'kill -1'"`, where env runs a program named `kill -1`, and `env -S "bash -c 'echo \\'; kill -1'"`, where bash rejects the open quote of `echo '; kill -1`). A chain of more than 8 env each with a non-empty `-S` string is unread past the cap, though env runs its last command (`env -S 'A=1'` or `env -S '-i'` nine times, then `make`), and so is a chain of strings that hold only a variable, which is not empty in the reading that keeps it (`env -S '${X}'` nine times). procps's pid reading is read for the builtins too, which reject a `+` or a blank before a pid past their range (`kill +4294967295`, `kill ' 4294967296'`). The reading the rail made before of a word that holds `=` but is not `NAME=…` is kept: it is the command word, its path taken off, so `A+=/bin/kill -1`, `a[1]=/bin/ps; kill 123`, `A+=./kill -1` and `a[k]=../kill -9 -1` are refused, though bash and zsh assign the word and only dash and busybox sh run it, as a relative path no stock host has; so is a word that starts with `-S` among env's assignments read as the command word (`env -P A=1 -S'a /bin/kill' -1`, where FreeBSD runs a program named `a`). zsh's brace grammar and the close words are read in every shell (bash and dash run a program named `{kill`, so `dash -c '{kill -1}'` runs nothing), and also where zsh runs nothing: a command word right after a close, where the shell wants a separator (`[[ 1 ]] kill -1`, `{ true; } kill -1`, `if [[ 1 ]] then kill -1 fi`); a `]]` that is an argument (`echo ]] kill -1`, `if [[ x == ]] ]] kill -1`); `always` where zsh rejects it (`{ true } always { true } always { kill -1 }`, `if [[ 1 ]] { true } always { kill -1 }`, `repeat 1 { true } always { kill -1 }`, `function { true } always { kill -1 }`); zsh's `if [[ … ]] { … }` at the very end of the string, which zsh parses only when a separator follows (`if [[ 1 ]] { kill -1 }`, where `if [[ 1 ]] { kill -1 }; true` runs the kill); a backslash in `function` or `always` (`\function { kill -1 }`, `func\tion { kill -1 }`, `{ true } \always { kill -1 }`), which the reader drops as with `\time`; a redirection between a close and the reserved word after it (`if false; then if true; then true; fi 2>/dev/null else kill -1; fi`), which the reader drops as before `time`; and a glued group the line's other words make zsh reject (`{kill -1} x`, `{not,x} kill -1`, `do {kill -1}`, `{kill -1;}{true}`). The rail evaluates no condition, so `true || {kill -1}` and `{ exit 1 } always { kill -1 }` are refused, as `if true; then :; else kill -1; fi` already was.

**Known limits** (the rail does not read these; each is pinned by `tests/kill.test.ts`, except the #1102 items in the first bullet, which are not pinned in this repo; PR #1119's Evidence records a live probe of `--no-extensions` and `omp plugin disable`, and the other items are untested):

- **Seats and tools outside it.** A plain `omp` session started with `--no-extensions`, one where
  `omp plugin disable seat-mods` or a project `plugin-overrides.json` `disabled` turned the plugin off, a host
  with seat-mods installed for Claude Code only, and a session whose entry fails to import (omp starts
  without it) get no rail (#1102). Devin and Codex seats, and an operator's `!cmd` on OMP, are not seats of
  either kind. Claude Code tools other than `Bash` and `Monitor`; on OMP every tool other than
  `bash`, `eval` and an implementer's `debug` (the `debug` tool of a free role is not read; `eval`
  source is read only for the string literals it holds).
- **Text a runner will run, other than the literal one-level form.** A heredoc fed to a shell, a script
  written and then run (in this call or an earlier one), a shell string inside a shell string,
  `eval "$VAR"`, `python3 -c`, `node -e`, `perl -e`, `su -c`, `ssh host …`, `watch`, `parallel`,
  `script -c`, `systemd-run`, `find … -exec kill`, `flock <file> -c '…'`,
  `coproc`. A `trap` string, which the shell runs later as code (`trap 'kill -1' EXIT`, in bash, dash and zsh; #1187),
  and zsh code inside a word, which zsh runs as it expands the word (a glob qualifier, `echo *(e:'kill -1':)`, and the
  `(e)` parameter flag, `${(e)…}`; #1188), are misses. uutils 0.8.0's `env --split-string=X` (the full name, `=` attached) takes the first split word as a nameless
  assignment and drops it, so `env --split-string='echo kill -1'` runs `kill -1` there and is a miss (#1173). fish's string grammar past its command prefixes is read as POSIX text, so these are misses: a single quote that takes `\'` (`fish -c "echo 'x\\' '; kill -1; echo ''"`, where fish runs the `kill`), an escape outside quotes, which fish decodes (`fish -c 'kill \x2d1'`), and an unquoted `(…)` substitution among the operands (`fish -c 'kill 123 (echo x) -1'`). Brace expansion and a substitution's value are misses as they are under sh (`fish -c 'kill {,-1}'`, `fish -c 'kill (echo -1)'`, as `kill {,-1}` and `kill $(echo -1)`). Shells other than the fourteen names above are not read: `rksh`, `oksh`, `pdksh` and `posh` (unprobed, source not read), `rksh93`, `rmksh` and `rlksh` (the restricted variants, unprobed by name) and `toybox sh -c '…'` are misses. The fourth readings are keyed on the runner name, so `sh` on a host where `sh` is ksh93 or mksh (Android's `/system/bin/sh` is mksh) gets the three readings only: `sh 'kill -1'` and `sh -T /dev/tty2 -c 'kill -1'` are misses there, as is `sh --profile p -c 'kill -1'` where `sh` is yash. On Alpine, busybox rejects `-c-` and its `sh` reads options as dash does, so the third reading adds nothing there; Debian and Ubuntu busybox accepts `-c-` (`busybox sh -c- -e 'kill -1'` is refused).
- **A command word the rail cannot name.** An alias, a function, a word held in a variable
  (`$K -1`) or built by expansion (`kill${IFS}-1`, and bash's brace expansion of the command word, `{kill,-1}` and
  `{,kill} -1`, as of an operand, `kill {,-1}`; #1186), a word split by a line continuation (inside a `-c` or `eval` word
  too: `bash -c kill\ \<newline>-1`), and a wrapper not in the list above (`doas`, `runuser`, `unshare`). An operand
  split by a line continuation is a miss too (`kill -9 -\<newline>1`). An assignment whose subscript holds an unquoted
  blank (`a[1 2]=x kill -1`, `a[ 1 ]=x kill -1`; bash) or a parenthesis (`a[(i)x]=1 kill -1`; bash and zsh) is read as
  the command word, and so is the rest of an assignment whose value holds an unquoted blank inside `${…}` or `$[…]`
  (`A=${X:-a b} kill -1`, `A+=${X:-a b} kill -1`, `A=$[1 + 2] kill -1`; bash and zsh; #1184). sudo's own assignment grammar is not read: C sudo takes any word that holds `=` and does not start
  with `/` or `=` as an environment variable, among its options too, so `sudo a-b=1 kill -1` and
  `sudo A=1 -u root kill -1` are misses (#1181).
- **procps-ng 4.0.4 as released.** Its `/bin/kill` reads a later `-<digit>…` word as `-<digit>`, so on procps-ng 4.0.4
  as released `/bin/kill -9 -1234` signals -1, through a path or any wrapper (`env`, `sudo`, `xargs`, `nohup`); the
  rail reads it as the process group 1234. 4.0.5 fixed it, and Ubuntu's `2:4.0.4-9ubuntu1` carries the fix. Write
  `kill -- -1234` (#1180).
- **zsh's functions it runs by itself.** zsh runs some named functions with no call: `TRAPEXIT` and `zshexit` when
  the shell exits, `TRAPZERR` after a failed command and `TRAPDEBUG` around each command. The rail reads a named
  function as defined only, so `function TRAPEXIT { kill -1 }` and `function TRAPZERR { kill -1 }; false` are misses
  (#1185); `TRAPEXIT() { kill -1 }` is refused, as every `name() { … }` body is.
- **State across calls.** A PID list written in one call and killed from in a later one
  (`kill $(cat pidfile)` is allowed on purpose), and a variable whose value is `-1`.
- **Other ways to signal many processes.** `fuser -k`, `pkill`/`killall` selecting by `-s`, `-g`,
  `-P`, `-t`, `-G` or `-F` alone, `pkill -v` (inverted), system-scope `systemctl stop user@<uid>`.
- **Spans.** An unquoted `$(…)` span is bounded by counting parentheses: a `case` pattern's `)` or a `)` inside `${…}` ends it early, and an operand after it is missed.
- **Patterns.** A second `pkill` operand is not read: procps `pkill` rejects it, but BSD and macOS `pkill` take several, so `pkill node '.*'` is a miss there. A `pkill` or `killall -r` pattern broad in some way the four probe names do not all
  match (`s`), one held in a variable or a quoted substitution (`pkill "$(cat f)"`), and one that is not a
  regular expression in JavaScript's reading, are not refused. An unquoted `$(…)` reads as the pattern
  `$`, which matches everything, so `pkill $(cat f)` is refused.

## Status block (orchestrator)

Claude Code only. In a `SEAT_MODS_ROLE=orchestrator` session, a **status turn** — a turn the
operator did not start by typing — must end with only the five-field status block:

```
**What I ruled:** …
**What the PR(s) will carry:** …
**Next steps:** …
**Waiting on (seats live):** …
**Waiting on operator:** …
```

The labels come in that order, each at the start of a line, bold or plain, and each field has
content ("none" is content). A field holds the lines up to the next label, so a list, a table or
numbered decisions fit. Nothing comes before the first label; a line after a last field of `none`
fails. Blank lines are skipped. Waiting on operator takes `none`, `decision: <question>` or
`action: <what the operator must do>`; several decisions go one numbered item each: the question,
the options, the recommendation marked. Past a decision or action the check cannot tell a list
from narration, so that stays the model's job. Two hooks carry it, and no
`classic.*` hook does: Claude Code skips a plugin's `classic.*` hooks on an org account, with no
error (#929):

- `prompt.submit` classifies the turn and, on a status turn, adds one line of model-only context
  (tool calls only, then the block). A prompt the operator types into a running status turn makes
  that turn the operator's, and it is not checked; a queued prompt (`ctrl+x enter`, `wait: true`)
  waits for a later turn and leaves the status turn alone.
- `turn.complete` checks the reply of the main loop's turn. A miss submits **one redo turn**, a
  prompt from seat-mods with the failing reason, which starts once the turn is over; the redo is
  checked too, and its miss stands. Then one line goes under the reply:
  `⚠ seat-mods: status block missing — this status reply is not in the required form.` It changes
  neither the answer nor the transcript. An interrupted turn, a subagent's turn end and a turn that
  ends on molt's `MOLT-HANDOFF:` line are not checked.
- No redo follows a turn that never answered: an interrupted turn, an API error, a refusal.
- The redo is dropped when it arrives if another prompt started a turn first (the operator's, a
  notification), or if molt's stage file (`~/.claude/state/molt/stage/<id>`) reads `command`,
  `block` or `fallback`: molt acts on that turn end, and its handoff wins. The line shows as a toast instead. In another session (a
  `/clear` or a molt) it is dropped quietly. molt's handoff requests are not status turns; its
  seed is.
- **Known limits** (0.11.0): under `claude -p` the printed result is the redo's reply, not the
  first one; an Agent SDK host was not probed. While molt is paused, or after a child or an SDK
  root handed off, molt's stage file still reads `command` or later, so every redo in that session
  is dropped and only the toasts show.

On the same block, an **idle check** (#876) reads three fields. When both wait fields — Waiting
on (seats live) and Waiting on operator — read `none` while Next steps names work, the
block contradicts itself and does not end the turn: its redo is asked for with
`seat-mods (orchestrator): the status block says nothing waits, but Next steps names work. Do the
next step now, or name the seat, wake, or operator decision or action you wait on.`, and a miss on
the redo adds
`⚠ seat-mods: status block says nothing waits, but Next steps names work.` under the reply, the
way the shape warning sits. A field reads `none` when its content starts with the word `none`,
any case: `none. No seats are live.` counts, `nonetheless` does not. The one redo per turn is
shared with the shape check, in either order: a redo asked for idling gets no second redo for its
shape, and a redo asked for the shape takes the idle warning only, not a second redo.

The check calls no model and never calls herdr, Orca or Paseo. Only `SEAT_MODS_ROLE=orchestrator`
sessions are affected; every other role and an unset role are untouched.

A typed prompt that starts with a crew tag — `[crew report|molt|message <role>]`, crew 0.3.x — is a
status turn. So are the two legacy ping forms, `REPORT READY: ` and `MOLT WARNING `, and the two
rotation resume forms, `/ossify:handoff-resume ` and `skill://handoff-resume ` (a slash command a
tag prefix would break). The legacy forms may go only when no run in flight was dispatched from a
crew brief older than 0.3.1.

**Known limit:** an operator prompt that itself starts with `REPORT READY: ` is held to the block.
That is the accepted cost of covering briefs already dispatched from crew 0.3.0.

## Limits

- **The rails stop mistakes, not an adversary.** Bash matching is whitespace tokens split on `;`,
  `&&`, `||`, `|`, a lone `&` (the `&` of a `|&` pipe included; the `&` a redirection carries and
  the lone `&` inside an unquoted `${…}` or `$[…]` expansion are not boundaries — inside an
  expansion only that character is masked, so its `(`, `)`, `;`, `|` and a nested `$(…)` keep
  their meaning), parentheses and newlines, after quoted strings and heredoc bodies are blanked as
  text and `#` comments are dropped, so a commit message may mention `git merge` or `-n`. A quote
  or a trailing backslash in a comment pairs or joins with nothing, and an escaped quote or a
  `$'…'` string opens no string past its end. Every rule set is the union of that
  reading with the `seat-mods-v0.3.1` separator read over the same command, so the rails see
  everything 0.3.1 saw — plus a command after a lone `&`. Only the command word counts, after any
  `VAR=value` and `sudo`, `env`, `command`, `exec`, `nohup` or `time`, and the head words
  `if`, `then`, `elif`, `else`, `do`, `while`, `until`, `!`, `{`, `(` and `time` on every rail only
  as exact unquoted words before assignments or execution wrappers (`builtin` is an execution prefix);
  so `echo git merge` is not a merge, and neither are `xargs git push --force`, `bash -c "git push -f"`, `g""it push`, or a
  wrapper with its own options (`env -i git merge`, `sudo -u u git push -f`).
- **Known limit:** `time -p <cmd>` is not parsed; for example, `time -p git push --force` passes.
- **Unparsed shell forms pass:** bundled short flags (`-fqu`),
  abbreviated long options (`--mir`), value-taking git globals (`--git-dir x`) and quoted
  subcommands or flags (`git "merge"`). A trailer that opens an `-m` message, comes from
  `--trailer`, or follows a backslash-newline inside single
  quotes, also passes.
- A command inside `$(…)` or backticks is read as a command of its own when the substitution stands unquoted, in double quotes, on a heredoc opener line or in an unquoted heredoc body, except as the next lines of this list say. The reader finds a span's end by counting parentheses and quotes, not by parsing, so a `)` Bash does not count ends it early and the rest of that span is not read: a `case` pattern's `)` in a double-quoted `$(…)`, a `)` inside a `${…}` there (`"$(echo ${x:-)} "it's")" && git push --force 'x'`), and a backslash-newline between `$` and `(`. A command nested more than 8 substitutions deep is refused as `no force-push`, whatever it runs.
- A backtick inside a quoted heredoc body inside a backtick span closes the span in Bash, and the text after it runs; the reader keeps the body whole, so a command there hides: `` x=`cat <<'EOF' ``, a newline, `` a ` ; git push --force ; ` ``, a newline, `EOF`, a newline and a closing backtick passes.
- **Funsubs:** a command inside a Bash 5.3 `${ …; }` or `${| …; }` runs in the current shell and is read by no rail: `X="${ git push --force; }"` and `X="${ rm -rf /etc/x; }"` pass. A funsub ends the `cd` walk: after a `cd` the directory is unknown, so a later relative `rm` is refused; with no `cd` before it a relative `rm` is placed in the session directory, as in 0.9.0, though Bash runs it wherever the funsub's own `cd` went (`X="${ cd /etc; }"; rm -rf y` passes).
- Shell options changed in the same call (`shopt`, e.g. `extglob`, `dotglob`, `nullglob`) are not modelled beyond the `**` and dot-component denials.
- `**` in an rm glob operand is unresolvable and denies; quoted literal `**` stays literal.
- **C6, grammar:** the reader splits text and does not parse it. An unexecuted shell function body (`cleanup() { rm …; }`) is checked as if it runs and may deny, and so is a command in a script Bash would refuse to run (`if git push --force; then`).
- **C5, a `&` inside a word:** only a lone `&` inside an unquoted `${…}` or `$[…]` is masked. A `&` inside any other word still splits it, so `a[foo&git push --force ]=x` and `echo @(a&git push --force )` are denied though Bash runs no `git`.
- **C8, a quoted tilde:** `rm ~""/scratch/x` and `rm ~''/scratch/x` read the tilde as `HOME`. Bash expands no tilde that is partly quoted and removes `<cwd>/~/scratch/x`. The usual outcome is a false stop; for a reviewer whose `SEAT_MODS_ALLOW` holds `$HOME/scratch`, the rm is placed there and passes while Bash removes in the session directory. A tilde quoted whole (`"~"/x`) reads as a relative name.
- One-word runners beyond the recognised wrappers (`timeout`, `nice`, `stdbuf`, `setsid`, `xargs`) can hide `rm`.
- A heredoc opener line holding a `$(…)`, a backtick or a `${…}` after the delimiter word is read as in 0.9.0: the rest of that line goes with the heredoc, so a ruled command after the substitution on that line stays hidden (`cat <<EOF $(date); git push --force`, then a body line and `EOF`). So does a quoted `<<` after one of those on its line, as in the `"$(cat <<'EOF' … )"` commit form. Any other quoted `<<` is text, as in Bash. An `rm` on that line is still read for its operands, as in 0.9.0, but a relative one is not placed through a `cd`.
- On such a line only the first opener is read, even when a second one stands before the substitution, so the second heredoc's body reads as commands, toward a stop: `cat <<A <<'B' "$(date)"`, then `a`, `A`, `rm -rf /etc/x` and `B` is refused, though Bash removes nothing.
- An arithmetic `$((…))` that spans lines on such a line leaves the reader counting its parentheses past the heredoc, so a later quote or comment can hide a ruled command: `cat <<EOF $(date) $((1 +`, a newline, `2))`, a body line and `EOF`, then `echo hi # it's` and `git push --force 'x'` passes.
- A `$'…'` or `$"…"` heredoc delimiter is read with its `$`, so its heredoc never closes at `EOF` and the lines after it can hide commands.
- A `<<` inside an unquoted `$[…]` or inside a `${…}` still opens a heredoc for the reader (`X=$[1<<2]`, `echo ${x/<<a/b}`), though Bash runs it as arithmetic or a pattern. The lines after it, up to one that equals its delimiter word (`2]` and `a/b}` in those two examples), read as body, so a ruled command there is hidden: `X=$[1<<2]` then a newline and `git push --force` passes, and so does `rm -rf /etc/x` there.
- Inside a double-quoted `$(…)`, a `#` after a blank in an inner quoted string still reads as a comment, as in 0.9.0, so the rest of that line is hidden (`git commit -m "$(echo "a # b")" && …`).
- A heredoc inside a `$(…)` closes, as in Bash 5.3, at a body line that starts with its delimiter and holds a `)` after it, and the rest of that line is read as commands (`EOF)` in `git commit -m "$(cat <<'EOF' … EOF)" && git push --force`). The reader sees that close only when the `$(` opens on the heredoc's logical line, the heredoc is the last one the reader opens on that line, and no backslash joins the closing line to the one before it. The logical line starts after the last newline outside quotes, so a quoted string or a backslash-newline that spans lines is read whole, or where the reader resumed after an earlier heredoc's body; when it resumed inside a quote, the close is read only if the line is inside a `$(` read both in that quote and without it, since the reader does not nest quotes inside `"$(…)"`. Otherwise the heredoc is not seen closing, and the commands after it can hide: `x=$(`, a newline, `cat <<EOF`, a body line and `EOF) && git push --force` passes, and so does `git commit -m "$(cat <<'A'`, `a`, `A`, `cat <<'EOF'`, a body line and `EOF)" && git push --force`. After `echo "$(echo "'")" ; cat <<'X'`, `x` and `X` the reader takes the `'` as still open, so a next line `x=$(cat <<EOF`, a body line and `EOF) ; git push --force` passes too. A process substitution `<(…)` or `>(…)` gets no such close: `cat <(cat <<EOF`, a body line and `EOF) /dev/null ; git push --force` passes. A backslash-newline inside a word reads as a blank where Bash deletes it: `r\<newline>m -rf /etc/x` is not read as an `rm`, and `git push --for\<newline>ce` is a push but not a force-push.
- Paths changed earlier in the same call (`ln -s`, `mv`, `mkdir` before `rm`) are checked against the filesystem as it stands before the call runs.
- **A scratch directory that holds the seat's own worktree is not a scratch place for that seat.** A seat whose worktree lies under `/tmp` gets no `/tmp` place, and one under `$TMPDIR` gets no `$TMPDIR` place; a scratch directory that does not hold its tree still applies. An allowed directory outranks the worktree, so adding the one that holds it would let a reviewer edit its own tree. Writes there keep the refusals the seat had.
- **A broad scratch directory opens other trees.** Other seats' worktrees under `/tmp`, or under a broad `$TMPDIR` such as `/home/dev`, are writable by any guarded seat whose own tree is elsewhere, the same as putting that value in `SEAT_MODS_ALLOW`. A `$TMPDIR` inside the worktree opens that subtree to a reviewer. `rm -rf /tmp/*` is allowed, so a seat can remove another session's scratch files.
- **The `cd` walk does not model the environment.** A `CDPATH` in the seat's environment (one assigned in the call ends the walk), a `cd` alias, any function or alias from the shell snapshot that changes directory (zoxide's `z`, for one) and zsh's `cd` behaviour are not read, and any of them can leave a later relative `rm` where the walk does not look.
- Glob matches are not enumerated: a matched parent symlink can lead outside writable places, as in `rm -rf <worktree>/*/node_modules`.
- `$` outside literal quoting/escaping, other than a `$NAME` a literal assignment gave, and leading `~+`/`~-` are unresolvable, even when Bash could resolve them.
- **Quoted command words:** a quoted command word (`"rm" -rf /etc/x`, `r'm' -rf /etc/x`, `"git" push --force`) and a subscripted or `+=` assignment prefix (`A[0]=1 rm -rf /etc/x`, `A+=1 git push --force`) are not read as the command, so the rails pass them (#1182; the kill rail reads both). A quoted `"cd"` does count as a directory change.
- `POSIXLY_CORRECT` operand ordering and a backslash-newline inside double quotes are not modelled.
- **The guarded launch needs a POSIX shell in the seat's pane.** crew sets the variables
  with `export`; a pane whose shell is Nushell leaves them unset, and the session runs under the
  default implementer rails — the status line reads `seat: implementer (default: SEAT_MODS_ROLE
  unset or empty)`.
- **A trailer counts only at a line start**, as the repository's commit-msg hook reads it.
- **`git pull` is not guarded.** A pull that merges is not on the merge rail; the briefs' prose
  rule covers it.
- **`implementer` is one profile for every implementer brief.** Briefs that stage and never
  commit (ossify's work-item implementer, the direct work item) keep that rule as prose; the mod
  allows `git commit`, `git push` and `gh pr create` for every implementer.
  An AI trailer is looked for only in the commit's own command and its message file.
- **A `-F` message file is read from the session's working directory.** A relative path after a
  `cd`, or a path in a shell variable, is not found and reads as empty, so a trailer in it passes.
  The repository's commit-msg hook remains the backstop.
- **The Bash placement rail covers only `rm`.** `rmdir`, `unlink`, `find -delete`, `git rm`, `git clean`,
  `xargs rm`, `bash -c '...'`, `mv` over a file, and other Bash writes such as `cat >` and `sed -i`
  remain outside it. These rails stop mistakes, not an adversary; precise shell parsing remains
  out of scope. A same-call `cd` the walk follows is checked in every directory the `rm` may run in; any
  other earlier recognised `cd`, `pushd` or `popd` conservatively denies relative `rm` operands even if
  that directory change fails. Cross-call directory changes use the live cwd measured above.
- **A default-guarded session writes only inside the worktree, `/tmp`, `$TMPDIR` and the
  `SEAT_MODS_ALLOW` directories** — and outside a git repository the worktree is its working
  directory — so Claude Code's own writes outside them, such as memory files under `~/.claude/projects/*/memory` and
  plan files under `~/.claude/plans`, are denied. That is the intended shape: a default-guarded
  session is a worker, and an operator session marks itself `orchestrator`.
- **A failed `git rev-parse --show-toplevel` is read as "not a repository".** Any failure of that
  spawn — a non-zero exit, git missing, a rejected spawn — makes the session's working directory
  the worktree, so a default-guarded session whose git spawn fails gets everything under its cwd
  writable. Pre-existing behaviour, now reachable by more sessions.
- **The runtime can fail open.** If the module does not load, or a hook throws outside the guarded
  Bash check, Claude Code skips it and
  the seat runs unguarded. The sign is a missing `seat: <role>` in the status line; the debug log
  (`claude --debug`) names the plugin and the reason. Claude Code also holds installed plugins'
  hooks modules behind a rollout flag (`tengu_plugin_hooks_modules`).
- Claude Code only. Codex has no mod runtime.

## OMP

Under `SEAT_MODS_ROLE=orchestrator`, the OMP guard blocks the `task` tool and every `before_subagent_spawn` (eval `agent()`, workpool) with a #798 denial directing the top to dispatch a herdr seat; other tools stay free, coordinator and every guarded role are unchanged, and the Claude Code hook is unchanged.

`omp/status-extension.ts` (0.8.0) is the status-block check and idle stop for an OMP orchestrator, over the same `hooks/status.ts`: one block per turn, then the warning as an OMP notification. `omp-seat` loads it last, after molt, for the orchestrator only, so its `session_stop` blocks win as they do beneath seat-mods on Claude Code; the guard stays first. OMP's `input` cannot tell typing from a herdr send, so a turn is status by its crew tag, or when no input started it (a job completion, an idle wake). **Known limit:** a turn that no prompt starts gets the check but not the status-turn context line.

`omp/extension.ts` is the same guard for OMP, over the same `hooks/rules.ts`, so the Bash reading, the scratch places (`$TMPDIR` from the seat's environment) and the `cd` walk above apply to a `bash` call there as they do on Claude Code. The guard loads only through `omp-roles`' `omp-seat` (`-e`, never ambient), so a plain `omp` session has no role guard. The kill rail alone, `omp/kill-rail.ts`, loads in every omp session through the plugin's `package.json` `omp` manifest (#1102), and omp loads each file once. The main session follows `SEAT_MODS_ROLE`; a `task` child inherits its parent's env, so the guard reads the child's agent name:

| Child agent | Rails |
|---|---|
| `implementer`, `task`, any other name | verifier: no commit, push or PR; writes in the worktree, the scratch places and `SEAT_MODS_ALLOW` (an `implementer` child stages and never commits) |
| `seat-reviewer`, `reviewer`, `scout` | reviewer: writes only in `SEAT_MODS_ALLOW` and the scratch places; `eval` and `debug` blocked |

Under any guarded role, a tool call passes only if its name is on the allow list in `GUARDED_TOOLS` (omp 18.8.9's tools); any other name, an MCP or extension tool included, is denied:

| Tools | Guarded rails |
|---|---|
| `read`, `grep`, `glob`, `find`, `ast_grep`, `web_search`, `recall`, `todo`, `wait`, `yield`, `think`, `advise` | allowed |
| `ask`, `goal`, `task` | the top-level session only; a child is denied |
| `bash`, `eval` | the command rules; `eval` source read best effort, and blocked for a reviewer. The kill rail reads both first, for every role |
| `write`, `edit` (and its `apply_patch` wire name), `ast_edit` | every target placed as omp reads it: a `[path#HHHH]` header unwrapped, `~`, `@/`, `:/` and `file://` expanded, any other `scheme:/` outside; since 0.4.5 (#844) `write` to an exact `local://<name>` is allowed for every guarded role: omp's per-session scratch, which omp confines itself; since 0.14.0 (#1099) so is `write` to an exact `proc://<id>/kill`, which cancels a job or agent the caller owns, or a named service (project-wide) |
| `lsp` | omp's read-only actions only (`diagnostics`, `definition`, `type_definition`, `implementation`, `references`, `hover`, `symbols`, `status`, `capabilities`) |
| `github` | omp's read-only ops; `pr_create`/`pr_push` follow the PR and push rails; `pr_checkout` and every other op denied; `forceWithLease` is a force-push |
| `debug` | an implementer only, its launch read like `eval`; denied for a verifier or reviewer |

A child may not spawn (`task`, eval `agent()` and workpool workers are blocked). omp's advisor and `/tan` clones count as children, so they get the verifier rails even under a coordinator. **Known limit:** helper calls inside `eval` fire no `tool_call`, so the guard reads `eval` source as best-effort command text; git hooks stay the rail for the rest. **Known limit:** the guard reads omp's path dialect only as far as the table says; omp's other path selectors (a SQLite `file.sqlite:table:row`, and any later one) are read as plain paths, so one routed through a symlink that points outside the worktree is not caught. Bash redirections, `cp`, `mv` and `ln` are not placed either. The guard catches a seat's mistakes; it is not a sandbox.

## Tests

```bash
bash seat-mods/run-tests.sh   # claude plugin validate + claude plugin test
bun test omp/                 # repo root: the OMP guard (omp/tests/seat-mods.test.ts) and status check (omp/tests/seat-mods-status.test.ts)
```
