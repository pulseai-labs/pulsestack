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
  quoted command word (`"rm" -rf …`, `"git" push --force`) and a subscripted prefix
  (`A[0]=1 rm -rf …`), which are not read as the command.
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
  `kill 00`, `kill -- 0`, `kill -- -0`; `kill -0 <pid>` is allowed), or **a negative operand that
  holds a `$` or a backtick** (`-$X`, `-"$X"`, `-${X}`, `-$((…))`, ``-`cat f` ``): a variable may be empty
  or `-1`. Spell a process group with its number (`kill -- -4242`).
- **`pkill` and `killall` by user** (`-u`, `-U`, `--euid`, `--uid`, `--user`; also inside a cluster such as `-fU`),
  **with no pattern** (`--help`, `--version`, `-V` and `-h` name none and pass), or with **a
  pattern that matches every name of a fixed probe set** (`systemd`, `bash`, `node`, `x`; `.`, `.*`, `''`,
  `[a-z]`). `killall -r` gets the same test. A signal word (`-9`, `-HUP`, `-SIGUSR1`) is not read as an option.
- **`killall5`**, **`systemctl --user`** with `exit`, `isolate`, `kill` or `stop default.target` (any argument
  order), and **`loginctl`** `terminate-user`, `kill-user`, `terminate-session` or `kill-session`.

An unquoted `$(…)` or `$((…))` counts as one word of its command, so `kill 123 $(cat p) 0` is read whole. The span is bounded by counting parentheses, not by the shell's grammar: a `case` pattern's `)` or a `)` inside `${…}` ends it early (a known limit), and a `(` inside `${…}` leaves it open, so the call is refused as unread. `command -v NAME` and `command -V NAME` run nothing and pass.

It reads through `sudo` (with its options), `env`, `command`, `builtin`, `exec`, `nohup`, `time`, `timeout`,
`setsid`, `nice`, `ionice`, `stdbuf`, `chrt`, `taskset`, `flock` and `busybox` (the next word is the applet: `busybox sh -c '…'`, `busybox kill -1`; each with its common options, and `--`);
through a path (`/bin/kill`), a quoted command word (`'kill'`, `k""ill`) and the shell's reserved heads; and
into a literal `eval '…'`, `sh|bash|rbash|zsh|dash|ash|static-sh|ksh|ksh93|mksh|lksh|mksh-static|yash -c '…'` or `fish -c '…'` string, once. A POSIX shell's string is found three ways (and, for six names, a fourth), as bash reads
the options (before and after `-c`, one value for each `o` or `O` in a short option cluster wherever it sits, one
`--`; after `-c`, a bare `-` ends the options and a bare `+` is skipped) and as zsh reads them (`-O` takes no value, `o` takes
the rest of its cluster, a bare `-`, a bare `+`, `--`, a cluster holding `b` or a cluster ending in `-` ends the options, and a leading
`--emulate` takes a value) and, only when an option word holds a `-` after its first character (a `--name` word included, since busybox ends it at the second `-`: `busybox sh -c -b --rcfile 'kill -1' x` is refused), as Debian and Ubuntu busybox ash reads them (`-c- -e 'kill -1'`, `-c-o 'kill -1' x`: the `-` ends that cluster and the options go on), for every one of the names, and the call is refused if any string is. `rbash` is bash and was probed as such. `ksh` and `ksh93`, `mksh`, `lksh` and `mksh-static`, and `yash` get a fourth reading each, used only for that name and probed on ksh93u+m 1.0.10 (macOS ksh 93u+ agrees), mksh R59c (`lksh` parses identically on all 8420 forms tried; `mksh-static` is a static build of the same source and agreed on the `-o -c`, `-o ''`, `-o +c` and `-c -` forms probed) and yash 2.55 (#1126). `ksh` is read as both ksh93 and mksh, since on Debian and Ubuntu without ksh93 `/bin/ksh` is an alternative of mksh. ksh93 runs a first operand that names no file as a command, with `-c` or without (`ksh 'kill -1'`, `ksh -e 'kill -1'`, `ksh +c 'kill -1'`), and its `-o` takes the next word unless that word is an option (`ksh -o -c 'kill -1'`). mksh's `-T` and `-o` take the next word whatever it is, and an `-o` value of `-c`, `+c` or the empty name sets `-c` (`mksh -T /dev/tty2 -c 'kill -1'`, `mksh -o -c 'kill -1'`). yash's `-c` is also the option `cmdline`, under any prefix, any case and any punctuation (a one-letter prefix too, which yash itself rejects as ambiguous, so `yash --c 'kill -1'` is a false stop) (`yash -o cmdline 'kill -1'`, `yash --cmd 'kill -1'`, `yash ++nocmdline 'kill -1'`), and its `--profile` and `--rcfile` take the next word under any prefix (`yash --profile p -c 'kill -1'`). `fish` gets a reading of its own and not the three, probed on fish 4.2.1 (#1127): its options are read as fish reads them, with no permutation, so `--`, a bare `-` or the first operand ends them; `-c` and `-C`/`--init-command` take the rest of the cluster or else the next word, and every value is read, since fish runs every one (`fish -c 'echo ok' -c 'kill -1'`, `fish -C 'kill -1'`); a long name is any unique prefix, with `=value` or the next word (`fish --command='kill -1'`, `fish --comm 'kill -1'`, `fish --init 'kill -1'`); and `p`, `d`, `f`, `D` and `o` take a value (`fish -p -c 'kill -1'` runs nothing and is allowed). Each fish string is read as POSIX text, and again with fish's command prefixes taken off: `and`, `or`, `not` and `begin`, quoted or not (fish reads `'not'` and `n""ot` as `not`), and a block's `{`, at the head of a command: the start, after `;`, `&`, `|` or a newline, after a block's `{`, after a substitution's `(` or `$(` (inside double quotes too), and after `if`, `while`, `else`, `!` or `time`, so a `{` after a prefix is taken off too (`fish -c 'true; and kill -1'`, `fish -c 'not kill -1'`, `fish -c 'begin kill -1; end'`, `fish -c '{kill -1}'`, `fish -c 'not {kill -1}'`, `fish -c 'echo (not kill -1)'`, `fish -c "'not' kill -1"`). Every other name, `sh` included, keeps the verdict it had. A refusal says what to do instead: list first, read
the PIDs, kill by literal PID in a separate call; to stop your own job use `write proc://<id>/kill` (OMP)
or `TaskStop` (Claude Code). Those two stops are not shell, so the rail never sees them. On OMP a
guarded role may `write` an exact `proc://<id>/kill` (`^proc://[A-Za-z0-9_-]+/kill$`, as it may `local://<name>`);
omp scopes a job or agent id to its owner; a service name is stopped project-wide, as `kill <pid>` through bash already allows. Every other spelling, and `edit` of it, is placed as before.

A string the rail cannot finish reading (an unclosed `$(`, a nesting too deep) does not hide a refusal in another reading, segment, runner string or substitution: the rail reads the rest and refuses with the kill reason if any part refuses, and treats the call as unread only when nothing refused. An unclosed `$(` outside quotes still makes its whole string unread, so a refusal earlier in that string (`kill -1; echo $(x`) is not found; the call is unread, as before.

A `bash` command the rail cannot read is refused (on the ambient OMP entry, an `eval` literal it cannot read passes), after a guarded role's own reader has had its say: a
forged marker, text it throws on, a substitution that never closes, a substitution nested more than 8 deep, and an `xargs` chain more than 8
deep (a chain that long is not walked).

Deliberate false stops: a call that lists and signals in one (`ps aux; kill 123`), `kill -1 <pid>`
(SIGHUP; write `kill -HUP`), and `kill -$SIG <pid>`. Split the call, or spell the number. A shell call
whose options one shell reads one way and another reads another way is refused when either reading's string is
refused, though the shell that runs it runs at most one of the strings, and often none (`zsh -cO extglob 'kill -1'`).
A bare `-` before `-c` is also skipped by the bash reading, so `bash - -c 'kill -1'` stays refused as in 0.14.1, though
no shell runs either string. Both
readings go into one scan, so `bash -cO 'ps aux' 'kill 123'`, where one reading lists and the other signals,
is refused as a call that lists and signals. `yash -c + 'kill -1'`, where yash runs the `+` and the kill text is only `$0`, is refused too. The fourth readings also refuse forms where the shell itself runs nothing (it fails on an unknown option or option value, or runs `-s`, `-D` or `-n`): on the 6174-form grid of 0.14.2, 581 forms for ksh where it is ksh93 and 679 where it is mksh (`ksh` gets both readings), 141 for mksh and 154 for yash, and none where the shell runs the other string. `lksh` shares mksh's false stops from the three generic readings (33 forms of the mksh grid where lksh runs the other string, such as `lksh -cT -o 'echo S1' 'kill -1'`). fish's reading takes a `-c` or `-C` value even where fish then runs nothing: after `-n`/`--no-execute`, beside `-v` or an unknown option (`fish -e -c 'kill -1'`), after an ambiguous prefix (`fish --i 'kill -1'`, which could be `--interactive` or `--init-command`), and when a value-taking option is left with no value (`fish -c 'kill -1' -p`): 4448 forms of the fish option grids, none where fish runs the other string. Text fish quotes and POSIX does not is read as code, so ``fish -c 'echo `kill -1`'`` (fish has no backticks) is refused.

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
  `script -c`, `systemd-run`, `find … -exec kill`, `env -S '…'` / `--split-string`, `flock <file> -c '…'`,
  `coproc`. fish's string grammar past its command prefixes is read as POSIX text, so these are misses: a single quote that takes `\'` (`fish -c "echo 'x\\' '; kill -1; echo ''"`, where fish runs the `kill`), an escape outside quotes, which fish decodes (`fish -c 'kill \x2d1'`), and an unquoted `(…)` substitution among the operands (`fish -c 'kill 123 (echo x) -1'`). Brace expansion and a substitution's value are misses as they are under sh (`fish -c 'kill {,-1}'`, `fish -c 'kill (echo -1)'`, as `kill {,-1}` and `kill $(echo -1)`). Shells other than the fourteen names above are not read: `rksh`, `oksh`, `pdksh` and `posh` (unprobed, source not read), `rksh93`, `rmksh` and `rlksh` (the restricted variants, unprobed by name) and `toybox sh -c '…'` are misses. The fourth readings are keyed on the runner name, so `sh` on a host where `sh` is ksh93 or mksh (Android's `/system/bin/sh` is mksh) gets the three readings only: `sh 'kill -1'` and `sh -T /dev/tty2 -c 'kill -1'` are misses there, as is `sh --profile p -c 'kill -1'` where `sh` is yash. On Alpine, busybox rejects `-c-` and its `sh` reads options as dash does, so the third reading adds nothing there; Debian and Ubuntu busybox accepts `-c-` (`busybox sh -c- -e 'kill -1'` is refused).
- **A command word the rail cannot name.** An alias, a function, a word held in a variable
  (`$K -1`) or built by expansion (`kill${IFS}-1`), a word split by a line continuation, and a wrapper
  not in the list above (`doas`, `runuser`, `unshare`).
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
- **Quoted command words:** a quoted command word (`"rm" -rf /etc/x`, `r'm' -rf /etc/x`, `"git" push --force`) and a subscripted assignment prefix (`A[0]=1 rm -rf /etc/x`) are not read as the command, so the rails pass them. A quoted `"cd"` does count as a directory change.
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
