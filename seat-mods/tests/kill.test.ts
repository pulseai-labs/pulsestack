import { describe, test, expect } from 'claude-code/testing'
import { killRule } from '../hooks/rules'

// The kill rail (#1099). Strings only: every row is text handed to killRule, and nothing here runs a command.
// Each refuse row has a near-miss control beside it that must stay allowed; each known limit asserts `undefined`
// so a later widening shows up as a changed row.

// [command, near-miss control]
const REFUSE: ReadonlyArray<readonly [string, string]> = [
  // the 2026-11-05 incident, and the listing forms
  ['kill $(ps -eo pid,args 2>/dev/null) 2>/dev/null; true', 'kill $(cat /tmp/job.pid)'],
  ['kill `pgrep -f herdr`', 'kill `cat /tmp/job.pid`'],
  ['kill "$(pgrep -u dev)"', 'kill "$(cat /tmp/job.pid)"'],
  ['kill -9 $(pidof node)', 'kill -9 12345'],
  ["kill $(ls /proc | grep -E '^[0-9]+$')", 'kill $(ls /tmp | head -1)'],
  ['ps -eo pid | xargs kill', 'echo 12345 | xargs kill'],
  ['pgrep -u dev | xargs -r kill -9', "printf '%s\\n' 1 2 | xargs -r kill -9"],
  ["ps aux | awk '{print $2}' | xargs kill", "awk '{print $2}' pids.txt | xargs kill"],
  ['ps -eo pid | xargs -n 1 kill -TERM', 'echo 12345 | xargs -n 1 kill -TERM'],
  ['for p in $(pgrep node); do kill $p; done', 'for p in 11 22; do kill $p; done'],
  ['P=$(pgrep x); kill $P', 'P=$(cat /tmp/job.pid); kill $P'],
  ['echo "$(kill $(pgrep x))"', 'echo "$(kill $(cat /tmp/job.pid))"'],
  // a signal to everything: -1, a negative operand with $, 0
  ['kill -1', 'kill -HUP 123'],
  ['kill -- -1', 'kill -- 123'],
  ['kill -9 -1', 'kill -9 -12'],
  ['kill -TERM -1', 'kill -TERM 123'],
  ['kill -s KILL -1', 'kill -s KILL 123'],
  ['kill -9 -$PGID', 'kill -9 -4242'],
  ['kill -- -"$PGID"', 'kill -- 4242'],
  ['kill -${PGID}', 'kill -9 "$PID"'],
  ['kill -9 -$((1))', 'kill -9 -4241'],
  ['kill 0', 'kill 10'],
  ['kill -- 0', 'kill -0 123'],
  ['kill -9 0', 'kill -s 0 123'],
  // pkill and killall: a user, no pattern, a pattern that matches everything
  ['pkill -u dev', "pkill -f 'herdr agent wait --pane wCH:p1'"],
  ['pkill -u "$USER" node', 'pkill node'],
  ['pkill -U 1000 node', 'pkill -USR2 node'],
  ['pkill -HUP .', 'pkill -HUP node'],
  ['pkill -U $(id -u) node', 'pkill -USR1 node'],
  ['pkill -fu dev node', 'pkill -f node'],
  ['pkill --euid 0 node', 'pkill -HUP node'],
  ['pkill --uid=0 node', 'pkill --full node'],
  ['killall -u dev', 'killall node'],
  ['killall --user dev node', 'killall -s USR1 node'],
  ['pkill .', 'pkill node'],
  ["pkill -f '.*'", "pkill -f 'herdr agent wait'"],
  ["pkill ''", 'pkill -x x'],
  ['pkill "[a-z]"', 'pkill "^herdr"'],
  ["pkill -x '.*'", "pkill -x 'bash -x'"],
  ['pkill -9', 'pkill -9 node'],
  ['pkill', 'pkill node'],
  ["killall -r '.*'", 'killall node'],
  ['killall -r .', 'killall -r "^herdr"'],
  ['killall', 'killall node'],
  // beyond #1099
  ['killall5', 'killall node'],
  ['killall5 -9', 'killall -9 node'],
  ['systemctl --user exit', 'systemctl --user status foo.service'],
  ['systemctl --user stop default.target', 'systemctl --user stop foo.service'],
  ['systemctl stop --user default.target', 'systemctl stop default.service'],
  ['systemctl --user isolate rescue.target', 'systemctl --user restart foo.service'],
  ['systemctl --user kill foo.service', 'systemctl kill foo.service'],
  ['XDG_RUNTIME_DIR=/run/user/1000 systemctl --user exit', 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user status x'],
  ['loginctl terminate-user dev', 'loginctl show-user dev'],
  ['loginctl kill-user dev', 'loginctl list-users'],
  ['loginctl terminate-session 3', 'loginctl show-session 3'],
  ['loginctl kill-session 3', 'loginctl list-sessions'],
  // how the command word is spelled, and what runs it
  ['/bin/kill -1', '/bin/kill 123'],
  ['command kill -1', 'command kill 123'],
  ['env kill -1', 'env kill 123'],
  ['env -i A=b kill -1', 'env -i A=b kill 123'],
  ['builtin kill -1', 'builtin kill 123'],
  ['exec kill -1', 'exec kill 123'],
  ['nohup kill -1', 'nohup kill 123'],
  ['time kill -1', 'time kill 123'],
  ['\\kill -1', '\\kill 123'],
  ["'kill' -1", "'kill' 123"],
  ['"kill" -1', '"kill" 123'],
  ['k""ill -1', 'k""ill 123'],
  ['timeout 5 kill -9 -1', 'timeout 5 kill -9 123'],
  ['timeout -s KILL 5 kill -1', 'timeout -s KILL 5 kill 123'],
  ['setsid kill -1', 'setsid kill 123'],
  ['nice -n 5 kill -1', 'nice -n 5 kill 123'],
  ['nice -5 kill -1', 'nice -5 kill 123'],
  ['ionice -c3 kill -1', 'ionice -c3 kill 123'],
  ['ionice -c 3 -n 7 kill -1', 'ionice -c 3 -n 7 kill 123'],
  ['stdbuf -oL kill -1', 'stdbuf -oL kill 123'],
  ['chrt 10 kill -1', 'chrt 10 kill 123'],
  ['taskset 1 kill -1', 'taskset 1 kill 123'],
  ['taskset -c 0,1 kill -1', 'taskset -c 0,1 kill 123'],
  ['flock /tmp/l kill -1', 'flock /tmp/l kill 123'],
  ['sudo kill -1', 'sudo kill 123'],
  ['sudo -n kill -1', 'sudo -n kill 123'],
  ['sudo -u dev kill -9 -1', 'sudo -u dev kill -9 123'],
  ['sudo --user=dev kill -1', 'sudo --user=dev kill 123'],
  ['sudo -nu dev kill -1', 'sudo -nu dev kill 123'],
  ['timeout 5 sudo -u dev nice -n 5 kill -1', 'timeout 5 sudo -u dev nice -n 5 kill 123'],
  ['{ kill -1; }', '{ kill 123; }'],
  ['( kill -1 )', '( kill 123 )'],
  ['if true; then kill -1; fi', 'if true; then kill 123; fi'],
  ['true && kill -1', 'true && kill 123'],
  ['kill -1 # note', 'kill 123 # note'],
  ['kill -1 2>/dev/null', 'kill 123 2>/dev/null'],
  ['xargs kill -1', 'xargs kill 123'],
  ['echo 1 | xargs -r -n1 kill -1', 'echo 1 | xargs -r -n1 kill 123'],
  // a literal eval or shell -c string is read once, as a command
  ["eval 'kill $(ps -eo pid)'", "eval 'echo $(ps -eo pid)'"],
  ['eval "kill -1"', 'eval "kill 123"'],
  ['eval kill -1', 'eval echo -1'],
  ["sh -c 'kill $(pgrep x)'", "sh -c 'kill $(cat /tmp/job.pid)'"],
  ['bash -c "kill -1"', 'bash -c "kill 123"'],
  ["zsh -c 'kill -1'", "zsh -c 'kill 123'"],
  ["dash -c 'kill -9 -1'", "dash -c 'kill -9 123'"],
  ["bash -lc 'kill -1'", "bash -lc 'kill 123'"],
  ["/bin/bash -c 'kill -1'", "/bin/bash -c 'kill 123'"],
  ["sudo bash -c 'kill -1'", "sudo bash -c 'kill 123'"],
  ["timeout 9 sh -c 'pkill -u dev'", "timeout 9 sh -c 'pkill node'"],
  ["xargs sh -c 'kill -1'", "xargs sh -c 'kill 123'"],
  // fix r0 B1: a user option inside a cluster (-U is found anywhere; a signal word such as -HUP or -SIGUSR1 is not an option)
  ['pkill -fU 1001', 'pkill -HUP node'],
  ['pkill -9U dev', 'pkill -SIGUSR1 x'],
  ['pkill -eU dev', 'pkill -HUP node'],
  ['pkill -cU dev', 'pkill -c node'],
  ['killall -qU dev', 'killall -q node'],
  // fix r0 B2: eval --, and shell options before or after -c
  ["eval -- 'kill -9 -1'", "eval -- 'kill -9 123'"],
  ["bash -c -- 'kill -9 -1'", "bash -c -- 'kill -9 123'"],
  ["sh -c -e 'kill -9 -1'", "sh -c -e 'kill -9 123'"],
  ["bash -c -- '-x; kill -1'", "bash -c -- '-x; kill 123'"],
  ["bash -c -x -o pipefail 'kill -1'", "bash -c -x -o pipefail 'kill 123'"],
  ["bash -c +O extglob 'kill -1'", "bash -c +O extglob 'kill 123'"],
  ["bash -O extglob -c 'kill -9 -1'", "bash -O extglob -c 'kill -9 123'"],
  ["bash +O extglob -c 'kill -9 -1'", "bash +O extglob -c 'kill -9 123'"],
  ["bash -o pipefail -c 'kill -1'", "bash -o pipefail -c 'kill 123'"],
  // fix r0 B3: time and builtin keep their options for the rail's own wrapper table
  ['time -p kill -1', 'time -p kill 123'],
  ['time -p pkill -u dev', 'time -p pkill node'],
  ['time -f %e kill -9 -1', 'time -f %e kill -9 123'],
  ['builtin -- kill -9 -1', 'builtin -- kill -9 123'],
  // the reserved `time` times a pipeline, so a head word or another `time` may follow it, after bash's `-p` and then `--`
  ['time ! kill -1', 'time ! kill 123'],
  ["sh -c 'time ! kill -1'", "sh -c 'time ! kill 123'"],
  ["sh -c 'time if kill -1; then :; fi'", "sh -c 'time if kill 123; then :; fi'"],
  ["fish -c 'time ! kill -1'", "fish -c 'time ! kill 123'"],
  ["fish -c 'time if kill -1; end'", "fish -c 'time if kill 123; end'"],
  ["fish -c 'time while kill -1; end'", "fish -c 'time while kill 123; end'"],
  ['time -p ! kill -1', 'time -p ! kill 123'],
  ['time -- ! kill -1', 'time -- ! kill 123'],
  ['time -p -- ! kill -1', 'time -p -- ! kill 123'],
  ['time { kill -1; }', 'time { kill 123; }'],
  ['time until kill -1; do :; done', 'time until kill 123; do :; done'],
  ['time ! ! kill -1', 'time ! ! kill 123'],
  ['time time ! kill -1', 'time time ! kill 123'],
  ['time ! time ! kill -1', 'time ! time ! kill 123'],
  // the other kill rules are read behind it too
  ['ps aux; time ! kill 123', 'ps aux; time ! echo 123'],
  ['time ! pkill -u dev', 'time ! pkill node'],
  ["eval 'time ! kill -1'", "eval 'time ! kill 123'"],
  // fix r0 N1: other spellings of -1 and 0, and a backtick negative operand
  ['kill -9 -01', 'kill -9 -012'],
  ['kill -- -01', 'kill -- 123'],
  ['kill -9 " -1"', 'kill -9 " 12"'],
  ['kill 00', 'kill 10'],
  ['kill -- -0', 'kill -0 123'],
  ['kill -9 -`cat /tmp/pgid`', 'kill -9 `cat /tmp/pgid`'],
  ['kill -- -"`cat /tmp/pgid`"', 'kill -- "`cat /tmp/pgid`"'],
  // fix r0 N4: an unquoted substitution reads as the pattern `$` (refused); the quoted one is not
  ['pkill $(cat /tmp/name)', 'pkill "$(cat /tmp/name)"'],
  ['killall -r $(cat /tmp/name)', 'killall -r "$(cat /tmp/name)"'],
  // fix r0 N6: pins for the mutants that survived the review
  ["pkill '[[:alpha:]]'", "pkill -x '[[:alpha:]]'"],
  ["pkill -i 'X|S|N|B'", "pkill 'X|S|N|B'"],
  ["$'kill' -1", "$'kill' 123"],
  // fix r1 C1: operands after an unquoted substitution are still operands of the same command
  ['kill -s $(echo KILL) -1', 'kill -s $(echo KILL) 123'],
  ['kill -9 $(cat p) -1', 'kill -9 $(cat p) 123'],
  ['kill 123 $(cat p) 0', 'kill 123 $(cat p) 456'],
  ['kill $(echo 5) -- -1', 'kill $(echo 5) -- 123'],
  ['kill $((1+1)) -1', 'kill $((1+1)) 123'],
  ['xargs kill $(echo 1) -1', 'xargs kill $(echo 1) 123'],
  ['killall foo $(echo) -u dev', 'killall foo $(echo) bar'],
  // fix r1 C2: a cluster that ends in o takes the next word; --rcfile and --init-file take a value
  ["bash -euo pipefail -c 'kill -1'", "bash -euo pipefail -c 'kill 123'"],
  ["bash -eo pipefail -c 'kill -1'", "bash -eo pipefail -c 'kill 123'"],
  ["bash --rcfile /dev/null -c 'kill -1'", "bash --rcfile /dev/null -c 'kill 123'"],
  ["bash --init-file x -c 'kill -1'", "bash --init-file x -c 'kill 123'"],
  ["bash --norc -c 'kill -1'", "bash --norc -c 'kill 123'"],
  ["bash -ec 'kill -1'", "bash -ec 'kill 123'"],
  // 0.14.1 (#1105): `-o1` is not read as a cluster; bash itself rejects it (`-o` takes the next word as an invalid option name), so this refusal is on input bash refuses
  ["bash -c -o1 'kill -1'", "bash -c -o1 'kill 123'"],
  // 0.14.1 (#1105): a short cluster takes one value per o or O it holds, wherever the letter sits, and a cluster holding c sets -c
  ["bash -co pipefail 'kill -1'", "bash -co pipefail 'kill 123'"],
  ["bash -oc pipefail 'kill -1'", "bash -oc pipefail 'kill 123'"],
  ["bash -cO extglob 'kill -1'", "bash -cO extglob 'kill 123'"],
  ["bash -oe pipefail -c 'kill -1'", "bash -oe pipefail -c 'kill 123'"],
  ["bash -Oc extglob 'kill -1'", "bash -Oc extglob 'kill 123'"],
  ["bash -ecO extglob 'kill -1'", "bash -ecO extglob 'kill 123'"],
  ["bash -Oe extglob -c 'kill -1'", "bash -Oe extglob -c 'kill 123'"],
  ["sh -oe pipefail -c 'kill -1'", "sh -oe pipefail -c 'kill 123'"],
  ["bash -oo pipefail errexit -c 'kill -1'", "bash -oo pipefail errexit -c 'kill 123'"],
  // PR 1108 r1: a + cluster holding c is -c in bash, dash and zsh; a non-last o after -c still takes its value
  ["bash +c 'kill -1'", "bash +c 'kill 123'"],
  ["bash +co pipefail 'kill -1'", "bash +co pipefail 'kill 123'"],
  ["bash -x +c 'kill -1'", "bash -x +c 'kill 123'"],
  ["bash -c -oe pipefail 'kill -1'", "bash -c -oe pipefail 'kill 123'"],
  ["bash -c -Oc extglob 'kill -1'", "bash -c -Oc extglob 'kill 123'"],
  // 0.14.2 (#1109): a bare - or + after -c is not the string; the shells run the next word
  ["bash -c - 'kill -1'", "bash -c - 'kill 123'"],
  ["bash -c + 'kill -1'", "bash -c + 'kill 123'"],
  ["sh -c - 'kill -1'", "sh -c - 'kill 123'"],
  ["zsh -c + 'kill -1'", "zsh -c + 'kill 123'"],
  // zsh reads the word before the bare one as the string here, so only bash's reading sees the kill
  ["bash -c -oe pipefail - 'kill -1'", "bash -c -oe pipefail - 'kill 123'"],
  ["bash -c -oe pipefail + 'kill -1'", "bash -c -oe pipefail + 'kill 123'"],
  // 0.14.2 (#1109): a bare + before a later -c: bash and dash skip it, zsh ends the options, so each reading finds a different string
  ["bash -co pipefail + -c 'kill -1'", "bash -co pipefail + -c 'kill 123'"],
  ["bash +c + -c 'kill -1'", "bash +c + -c 'kill 123'"],
  ["bash +c + -ec 'kill -1'", "bash +c + -ec 'kill 123'"],
  ["bash +ec + -c 'kill -1'", "bash +ec + -c 'kill 123'"],
  ["dash +ec + -ec 'kill -1'", "dash +ec + -ec 'kill 123'"],
  // 0.14.2 (#1109): zsh's -O takes no value, so the string comes right after the cluster
  ["zsh -cO 'kill -1'", "zsh -cO 'kill 123'"],
  ["zsh -Oc 'kill -1'", "zsh -Oc 'kill 123'"],
  ["zsh +cO 'kill -1'", "zsh +cO 'kill 123'"],
  ["zsh -c -O 'kill -1'", "zsh -c -O 'kill 123'"],
  ["zsh -c +O 'kill -1'", "zsh -c +O 'kill 123'"],
  ["sudo -u dev zsh -cO 'kill -1'", "sudo -u dev zsh -cO 'kill 123'"],
  // 0.14.2 (#1109): zsh's o takes the rest of its cluster as the option name
  ["zsh -c -xoshwordsplit 'pkill -u alice'", "zsh -c -xoshwordsplit 'pkill node'"],
  ["zsh -c -oshwordsplit 'kill -1'", "zsh -c -oshwordsplit 'kill 123'"],
  ["zsh -xoshwordsplit -c 'kill -1'", "zsh -xoshwordsplit -c 'kill 123'"],
  ["zsh -coshwordsplit 'kill -1'", "zsh -coshwordsplit 'kill 123'"],
  ["zsh -c -opipefail 'kill -1'", "zsh -c -opipefail 'kill 123'"],
  // 0.14.2 (#1109): two zsh forms whose strings a bash-only reading misses; digits are ordinary zsh option letters, and --emulate takes a value
  ["zsh -c1 'kill -1'", "zsh -c1 'kill 123'"],
  ["zsh --emulate sh -c 'kill -1'", "zsh --emulate sh -c 'kill 123'"],
  // 0.14.2 (#1109): zsh's b ends the options after its cluster, so the next word is the string even when it starts with -
  ["zsh -cb '-x; kill -1'", "zsh -cb '-x; kill 123'"],
  // 0.14.2 (#1109): zsh's bare + ends the options (bash skips it), so the next word is the string even when it starts with -
  ["zsh -c + '-x; kill -1'", "zsh -c + '-x; kill 123'"],
  // 0.14.2 (#1109): a - that ends a zsh cluster ends the options too, so the next word is the string (bash and dash reject these)
  ["zsh -c- '-x; kill -1'", "zsh -c- '-x; kill 123'"],
  ["zsh +c- '-x; kill -1'", "zsh +c- '-x; kill 123'"],
  ["zsh -xc- '-x; kill -1'", "zsh -xc- '-x; kill 123'"],
  ["zsh -fc- '-x; kill -1'", "zsh -fc- '-x; kill 123'"],
  ["zsh -c -x- '-y; kill -1'", "zsh -c -x- '-y; kill 123'"],
  ["zsh -c -f- '-y; kill -1'", "zsh -c -f- '-y; kill 123'"],
  ["zsh -c +- '-y; kill -1'", "zsh -c +- '-y; kill 123'"],
  ["sh -c- '-x; kill -1'", "sh -c- '-x; kill 123'"],
  // the zsh reading is applied under every name in KILL_SHELLS, so dropping it for any one of them fails a row
  ["sh -cO 'kill -1'", "sh -cO 'kill 123'"],
  ["dash -cO 'kill -1'", "dash -cO 'kill 123'"],
  ["bash -cO 'kill -1'", "bash -cO 'kill 123'"],
  // zsh's o ends a cluster and takes the next word, after a value-less O
  ["zsh -cOo pipefail 'kill -1'", "zsh -cOo pipefail 'kill 123'"],
  // a long option takes no value
  ["zsh -c --braceccl 'kill -1'", "zsh -c --braceccl 'kill 123'"],
  // a digit before the c is an ordinary zsh option letter too
  ["zsh -1c 'kill -1'", "zsh -1c 'kill 123'"],
  // 0.14.2 (#1109): forms 0.14.1 refused stay refused though the shell runs neither string (a false stop kept so the rail never loosens)
  ["bash - -c 'kill -1'", "bash - -c 'kill 123'"],
  ["zsh + -c 'kill -1'", "zsh + -c 'kill 123'"],
  ["zsh -cO extglob 'kill -1'", "zsh -cO extglob 'kill 123'"],
  ["zsh -c -oe pipefail 'kill -1'", "zsh -c -oe pipefail 'kill 123'"],
  // fix r1 C3: command runs its operand unless it is -v or -V
  ['command pkill -u dev', 'command -v pkill'],
  // fix r1 C6: a clean command after a refused one does not clear the refusal (one row per site)
  ['kill -1; kill 123', 'kill 123; kill 456'],
  ['pkill -u dev; pkill node', 'pkill node; pkill bash'],
  ['killall5; kill 123', 'killall node; kill 123'],
  ['systemctl --user exit; kill 123', 'systemctl --user status x; kill 123'],
  ['loginctl kill-user dev; kill 123', 'loginctl show-user dev; kill 123'],
  // round 2 C9: killall reads every name; env's own -v is skipped
  ["killall node ''", 'killall node bash'],
  ['env -v pkill -u dev', 'env -v pkill node'],
  ["killall --regexp '.*'", "killall --regexp '^herdr'"],
  ["pkill --ignore-case 'X|S|N|B'", "pkill 'X|S|N|B'"],
  ['pkill --signal HUP', 'pkill --signal HUP node'],
  // a call that both lists and signals is refused whichever way they are joined (a deliberate false stop)
  ['ps aux; kill 123', 'ps aux; echo 123'],
  ['pgrep -f foo && kill 123', 'pgrep -f foo && echo 123'],
  // every name the rail reads as a shell gets all three readings: dropping a name from KILL_SHELLS fails its row
  ["rbash -c 'kill -1'", "rbash -c 'kill 123'"],
  ["ash -c 'kill -1'", "ash -c 'kill 123'"],
  ["static-sh -c 'kill -1'", "static-sh -c 'kill 123'"],
  ["ksh -c 'kill -1'", "ksh -c 'kill 123'"],
  ["ksh93 -c 'kill -1'", "ksh93 -c 'kill 123'"],
  ["mksh -c 'kill -1'", "mksh -c 'kill 123'"],
  ["yash -c 'kill -1'", "yash -c 'kill 123'"],
  ["/bin/ksh -c 'kill -1'", "/bin/ksh -c 'kill 123'"],
  ["env yash -c 'kill -1'", "env yash -c 'kill 123'"],
  ["ksh -ec 'kill -1'", "ksh -ec 'kill 123'"],
  ["mksh -c -o pipefail 'kill -1'", "mksh -c -o pipefail 'kill 123'"],
  // each name's own grammar, read for that name only: ksh93's first operand and -o value, mksh's -T and -o values (lksh reads as mksh), yash's cmdline and its value-taking long options
  ["ksh 'kill -1'", "ksh 'kill 123'"],
  ["ksh93 -e 'kill -1'", "ksh93 -e 'kill 123'"],
  ["ksh -- 'kill -1'", "ksh -- 'kill 123'"],
  ["ksh - 'kill -1'", "ksh - 'kill 123'"],
  ["ksh + 'kill -1'", "ksh + 'kill 123'"],
  ["ksh +c 'kill -1'", "ksh +c 'kill 123'"],
  ["ksh -o -c 'kill -1'", "ksh -o -c 'kill 123'"],
  ["ksh93 -c -o -o pipefail 'kill -1'", "ksh93 -c -o -o pipefail 'kill 123'"],
  ["ksh -o - 'kill -1'", "ksh -o - 'kill 123'"],
  ["ksh -o pipefail 'kill -1'", "ksh -o pipefail 'kill 123'"],
  ["ksh93 -o -o pipefail -c 'kill -1'", "ksh93 -o -o pipefail -c 'kill 123'"],
  ["ksh --pipefail 'kill -1'", "ksh --pipefail 'kill 123'"],
  ["/bin/ksh93 'kill -1'", "/bin/ksh93 'kill 123'"],
  ["env ksh 'kill -1'", "env ksh 'kill 123'"],
  ["sudo ksh93 -e 'kill -1'", "sudo ksh93 -e 'kill 123'"],
  ["mksh -T /dev/tty2 -c 'kill -1'", "mksh -T /dev/tty2 -c 'kill 123'"],
  ["mksh -cT /dev/tty2 'kill -1'", "mksh -cT /dev/tty2 'kill 123'"],
  ["mksh -c -T /dev/tty2 'kill -1'", "mksh -c -T /dev/tty2 'kill 123'"],
  ["mksh -T /dev/tty2 -o pipefail -c 'kill -1'", "mksh -T /dev/tty2 -o pipefail -c 'kill 123'"],
  ["mksh -o -c 'kill -1'", "mksh -o -c 'kill 123'"],
  ["mksh -o +c 'kill -1'", "mksh -o +c 'kill 123'"],
  ["mksh -o '' 'kill -1'", "mksh -o '' 'kill 123'"],
  ["mksh -c - 'kill -1'", "mksh -c - 'kill 123'"],
  ["/bin/mksh -o -c 'kill -1'", "/bin/mksh -o -c 'kill 123'"],
  ["lksh -c 'kill -1'", "lksh -c 'kill 123'"],
  ["lksh -T /dev/tty2 -c 'kill -1'", "lksh -T /dev/tty2 -c 'kill 123'"],
  ["lksh -o -c 'kill -1'", "lksh -o -c 'kill 123'"],
  ["lksh -o '' 'kill -1'", "lksh -o '' 'kill 123'"],
  ["/system/bin/lksh -cT /dev/tty2 'kill -1'", "/system/bin/lksh -cT /dev/tty2 'kill 123'"],
  ["yash --profile p -c 'kill -1'", "yash --profile p -c 'kill 123'"],
  ["yash -c --prof p 'kill -1'", "yash -c --prof p 'kill 123'"],
  ["yash --rc p -c 'kill -1'", "yash --rc p -c 'kill 123'"],
  ["yash --rcfile p -c 'kill -1'", "yash --rcfile p -c 'kill 123'"],
  ["yash -o cmdline 'kill -1'", "yash -o cmdline 'kill 123'"],
  ["yash -ocmdline 'kill -1'", "yash -ocmdline 'kill 123'"],
  ["yash --cmd 'kill -1'", "yash --cmd 'kill 123'"],
  ["yash --cm 'kill -1'", "yash --cm 'kill 123'"],
  ["yash --CMD_LINE 'kill -1'", "yash --CMD_LINE 'kill 123'"],
  ["yash +o nocmdline 'kill -1'", "yash +o nocmdline 'kill 123'"],
  ["yash ++nocmdline 'kill -1'", "yash ++nocmdline 'kill 123'"],
  ["yash -c --profile p 'kill -1'", "yash -c --profile p 'kill 123'"],
  ["env yash --cmdline 'kill -1'", "env yash --cmdline 'kill 123'"],
  // ksh is also mksh (Debian and Ubuntu without ksh93), and mksh-static is the same parser as mksh
  ["ksh -cT /dev/tty2 'kill -1' x", "ksh -cT /dev/tty2 'kill 123' x"],
  ["ksh -c -T /dev/tty2 'kill -1'", "ksh -c -T /dev/tty2 'kill 123'"],
  ["ksh -T /dev/tty2 -c 'kill -1'", "ksh -T /dev/tty2 -c 'kill 123'"],
  ["ksh -c -T -o 'kill -1' x", "ksh -c -T -o 'kill 123' x"],
  ["ksh -o '' 'kill -1'", "ksh -o '' 'kill 123'"],
  ["mksh-static -c 'kill -1'", "mksh-static -c 'kill 123'"],
  ["mksh-static -T /dev/tty2 -c 'kill -1'", "mksh-static -T /dev/tty2 -c 'kill 123'"],
  ["mksh-static -o -c 'kill -1'", "mksh-static -o -c 'kill 123'"],
  ["mksh-static -o '' 'kill -1'", "mksh-static -o '' 'kill 123'"],
  ["/bin/mksh-static -cT /dev/tty2 'kill -1'", "/bin/mksh-static -cT /dev/tty2 'kill 123'"],
  // busybox runs the applet that follows: a shell, kill, killall, ps, xargs
  ["busybox sh -c 'kill -1'", "busybox sh -c 'kill 123'"],
  ["busybox ash -c 'kill -1'", "busybox ash -c 'kill 123'"],
  ["/usr/bin/busybox /bin/sh -c 'kill -1'", "/usr/bin/busybox /bin/sh -c 'kill 123'"],
  ["busybox static-sh -c 'kill -1'", "busybox static-sh -c 'kill 123'"],
  ['busybox kill -1', 'busybox kill 123'],
  ['busybox killall -u dev', 'busybox killall node'],
  ['busybox ps; kill 123', 'busybox ls; kill 123'],
  ['busybox xargs kill -1', 'busybox xargs kill 123'],
  ['sudo busybox sh -c "kill -1"', 'sudo busybox sh -c "kill 123"'],
  // busybox ash (Debian and Ubuntu builds): a - inside a cluster ends it and the options go on, so the string follows -c- -e
  ["sh -c- -e 'kill -1'", "sh -c- -e 'kill 123'"],
  ["busybox sh -c- -e 'kill -1'", "busybox sh -c- -e 'kill 123'"],
  ["ash -c-o 'kill -1' x", "ash -c-o 'kill 123' x"],
  ["ash -c- - 'kill -1'", "ash -c- - 'kill 123'"],
  ["ash -c- -o pipefail 'kill -1'", "ash -c- -o pipefail 'kill 123'"],
  ["ash -ec- -x 'kill -1'", "ash -ec- -x 'kill 123'"],
  ["ksh -c- -e 'kill -1'", "ksh -c- -e 'kill 123'"],
  ["ash -c- + 'kill -1'", "ash -c- + 'kill 123'"],
  // a --name word is a cluster busybox ends at its second -, and --rcfile takes no value
  ["busybox sh -c -b --rcfile 'kill -1' x", "busybox sh -c -b --rcfile 'kill 123' x"],
  ["sh -c -b --rcfile 'kill -1' x", "sh -c -b --rcfile 'kill 123' x"],
  // the -c or eval word as the outer shell hands it on: a backslash escape, '…', "…", $'…' (ANSI-C, a NUL ends its part)
  // and $"…" are undone, so an escaped blank, an escaped ; and mixed quoting read as the shell runs them
  ["bash -c kill\\ -1", "bash -c kill\\ 123"],
  ["sh -c kill\\ -1", "sh -c kill\\ 123"],
  ["zsh -c kill\\ -1", "zsh -c kill\\ 123"],
  ["eval kill\\ -1", "eval kill\\ 123"],
  ["bash -c time\\ !\\ kill\\ -1", "bash -c time\\ !\\ kill\\ 123"],
  ["fish -c kill\\ -1", "fish -c kill\\ 123"],
  ["eval kill \\ -1", "eval kill \\ 123"],
  ["bash -c ps\\;kill\\ 123", "bash -c ls\\;kill\\ 123"],
  ["bash -c $'kill -1'", "bash -c $'kill 123'"],
  ["bash -c $'kill\\x20-1'", "bash -c $'kill\\x20123'"],
  ["bash -c $\"kill -1\"", "bash -c $\"kill 123\""],
  ["bash -c 'kill'\\ '-1'", "bash -c 'kill'\\ '123'"],
  ["bash -c kill\\ \"-1\\\"\\\"\"", "bash -c kill\\ \"123\\\"\\\"\""],
  ["bash -c $'kill\\0x'\\ -1", "bash -c $'kill\\0x'\\ 123"],
  ["bash -c 'kill -1'\\;", "bash -c 'kill 123'\\;"],
  // zsh's reserved `repeat <count>` and `nocorrect` (unquoted), and its precommand modifiers `noglob` and `-` (quoted or
  // not), at a command's head, after assignments and after `builtin`, `exec` and `time`; `repeat` before a head word
  ["repeat 1 kill -1", "repeat 1 kill 123"],
  ["nocorrect kill -1", "nocorrect kill 123"],
  ["noglob kill -1", "noglob kill 123"],
  ["- kill -1", "- kill 123"],
  ["time repeat 1 kill -1", "time repeat 1 kill 123"],
  ["repeat 1 time ! kill -1", "repeat 1 time ! kill 123"],
  ["repeat 1 ! kill -1", "repeat 1 ! kill 123"],
  ["repeat 1 do kill -1; done", "repeat 1 do kill 123; done"],
  ["repeat 1 { kill -1 }", "repeat 1 { kill 123 }"],
  ["time noglob kill -1", "time noglob kill 123"],
  ["time nocorrect kill -1", "time nocorrect kill 123"],
  ["A=1 noglob kill -1", "A=1 noglob kill 123"],
  ["A=1 nocorrect kill -1", "A=1 nocorrect kill 123"],
  ["'noglob' kill -1", "'noglob' kill 123"],
  ["builtin noglob kill -1", "builtin noglob kill 123"],
  ["exec noglob kill -1", "exec noglob kill 123"],
  ["noglob - kill -1", "noglob - kill 123"],
  ["nocorrect noglob kill -1", "nocorrect noglob kill 123"],
  // the other kill rules are read behind them too, and inside eval and a -c word
  ["ps aux; noglob kill 123", "ls; noglob kill 123"],
  ["noglob pkill -u dev", "noglob pkill node"],
  ["eval 'repeat 1 kill -1'", "eval 'repeat 1 kill 123'"],
  ["zsh -c noglob\\ kill\\ -1", "zsh -c noglob\\ kill\\ 123"],
  // a fish -c, -C or --command= value attached to its option word gets the same quote removal as a separate one
  ["fish -ckill\\ -1", "fish -ckill\\ 123"],
  ["fish --command=kill\\ -1", "fish --command=kill\\ 123"],
  ["fish -c$'kill\\x20-1'", "fish -c$'kill\\x20123'"],
  ["fish -c'kill'\\ '-1'", "fish -c'kill'\\ '123'"],
  ["fish -Ckill\\ -1", "fish -Ckill\\ 123"],
  // $'…' decodes each escape as bash does: \c takes an escaped backslash as its character (\c\\ is one control
  // character), \u and \U, \x with at most two digits, octal with at most three digits kept to eight bits, \t, \' and \cX
  ["bash -c $'x\\c\\\\\\x3bkill -1'", "bash -c $'x\\c\\\\\\x3bkill 123'"],
  ["bash -c $'echo\\c\\\\\\nkill -1'", "bash -c $'echo\\c\\\\\\nkill 123'"],
  ["bash -c $'\\u006bill -1'", "bash -c $'\\u006bill 123'"],
  ["bash -c $'\\U0000006bill -1'", "bash -c $'\\U0000006bill 123'"],
  ["bash -c $'kill \\x2d1'", "bash -c $'kill \\x3123'"],
  ["bash -c $'\\553ill -1'", "bash -c $'\\553ill 123'"],
  ["bash -c $'\\153ill -1'", "bash -c $'\\153ill 123'"],
  ["bash -c $'kill\\t-1'", "bash -c $'kill\\t123'"],
  ["bash -c $'kill \\'-1\\''", "bash -c $'kill \\'123\\''"],
  ["bash -c $'echo hi\\cJkill -1'", "bash -c $'echo hi\\cJkill 123'"],
  // env read as GNU coreutils, busybox and uutils read it: a bare - after the options or --, and (uutils) more than one
  // and among the assignments; value options -a/--argv0 and -f/--file; a long name by any prefix; any word with = an
  // assignment
  ["env - kill -1", "env - echo hi"],
  ["env - kill -1", "env - kill 123"],
  ["env -- - kill -1", "env -- - kill 123"],
  ["env -i - kill -1", "env -i - kill 123"],
  ["env - - kill -1", "env - - kill 123"],
  ["env A=1 - kill -1", "env A=1 - kill 123"],
  ["env --uns XQ -ax kill -1", "env --uns XQ -ax kill 123"],
  ["env -a xq kill -1", "env -a xq kill 123"],
  ["env --argv0 xq kill -1", "env --argv0 xq kill 123"],
  ["env -f /dev/null kill -1", "env -f /dev/null kill 123"],
  ["env --file /dev/null kill -1", "env --file /dev/null kill 123"],
  ["env --uns XQ kill -1", "env --uns XQ kill 123"],
  ["env --ch / kill -1", "env --ch / kill 123"],
  ["env a-b=1 kill -1", "env a-b=1 kill 123"],
  // env read as FreeBSD and macOS read it: a bare - is an option among the others, and -P, -L and -U take a value
  ["env - -i kill -1", "env - -i kill 123"],
  ["env - -uXQ kill -1", "env - -uXQ kill 123"],
  ["env -P /usr/bin kill -1", "env -P /usr/bin kill 123"],
  ["env -L root kill -1", "env -L root kill 123"],
  ["env -U root kill -1", "env -U root kill 123"],
  // the other kill rules behind env's bare -: pkill by user, a listing, under xargs, and a -c string
  ["env - pkill -u dev", "env - pkill node"],
  ["ps aux; env - kill 123", "ls; env - kill 123"],
  ["xargs env - kill -1", "xargs env - kill 123"],
  ["env - bash -c 'kill -1'", "env - bash -c 'kill 123'"],
  // env behind another wrapper, or second in a chain of envs, is read with env's grammars too
  ["sudo env - kill -1", "sudo env - kill 123"],
  ["nice env -a xq kill -1", "nice env -a xq kill 123"],
  ["env -i env - kill -1", "env -i env - kill 123"],
  // each segment walks its own xargs commands: a second xargs at the same word count from the end is still read
  ["xargs echo hi; xargs kill -1", "xargs echo hi; xargs kill 123"],
  // every word of a command after the outer shell's quote removal as bash does it: the command word, its operands, a
  // wrapper, a runner name, a listing and a session verb
  ["$'\\x6bill' -1", "$'\\x6bill' 123"],
  ["kill $'\\x2d1'", "kill $'\\x3123'"],
  ["kill \\ -1", "kill \\ 123"],
  ["kill -9 $'\\x2d1'", "kill -9 $'\\x3123'"],
  ["kill $'\\t-1'", "kill $'\\t123'"],
  ["$'\\x70s' aux; kill 123", "$'\\x6cs'; kill 123"],
  ["pkill $'\\x2e'", "pkill $'\\x6eode'"],
  ["systemctl --user $'\\x65xit'", "systemctl --user $'\\x73tatus'"],
  ["$'\\x62ash' -c 'kill -1'", "$'\\x62ash' -c 'kill 123'"],
  ["env $'\\x2d' kill -1", "env $'\\x2d' kill 123"],
  ["$'k\\0zz'ill -1", "$'k\\0zz'ill 123"],
  // kill's operand as bash's kill reads a pid: blanks (space, tab, newline, vertical tab, form feed, carriage return)
  // before the sign and after the digits, whatever spells them; a word that starts with a blank is never an option
  ["kill -9 -1\\ ", "kill -9 123\\ "],
  ["kill -9 '-1 '", "kill -9 '123 '"],
  ["kill -s 9 -1\\ ", "kill -s 9 123\\ "],
  ["kill -9 -1$'\\x20'", "kill -9 123$'\\x20'"],
  ["kill -9 ' -1 '", "kill -9 ' 123 '"],
  ["kill -9 $'-1\\t'", "kill -9 $'123\\t'"],
  ["kill -9 $'-1\\n'", "kill -9 $'123\\n'"],
  ["kill -9 \\ 0", "kill -9 \\ 123"],
  ["kill -9 0\\ ", "kill -9 10\\ "],
  ["kill -9 \"0 \"", "kill -9 \"10 \""],
  ["kill -9 $'\\r0\\f'", "kill -9 $'\\r10\\f'"],
  ["kill -9 -- '-0 '", "kill -9 -- '-10 '"],
  ["kill -9 ' -0'", "kill -9 ' -10'"],
  ["kill -9 \" -$x\"", "kill -9 \" $x\""],
  // and a + sign before the digits: +0 is the caller's process group
  ["kill +0", "kill +10"],
  ["kill -9 ' +00 '", "kill -9 ' +100 '"],
  // the same words as zsh decodes them: an escape zsh does not know loses its backslash, \cX is cX, and a NUL ends the word
  ["$'\\k\\i\\l\\l' -1", "$'\\k\\i\\l\\l' 123"],
  ["$'kill\\0'x -1", "$'kill\\0'x 123"],
  ["$'system\\ctl' --user exit", "$'system\\ctl' --user status"],
  // a -c or eval word as zsh hands it on: \C-x, \Cx (control), an unknown escape's backslash dropped (zsh runs
  // kill\ -1 as kill -1), a NUL that ends the word, \x and \u with no digit a NUL, octal kept to eight bits, \cX as cX
  ["bash -c $'echo\\C-jkill -1'", "bash -c $'echo\\C-jkill 123'"],
  ["bash -c $'kill -1\\0'x", "bash -c $'kill 123\\0'x"],
  ["bash -c $'system\\ctl --user exit'", "bash -c $'system\\ctl --user status'"],
  ["bash -c $'kill\\ -1'", "bash -c $'kill\\ 123'"],
  ["bash -c $'echo\\Cjkill -1'", "bash -c $'echo\\Cjkill 123'"],
  ["eval $'echo\\C-jkill -1'", "eval $'echo\\C-jkill 123'"],
  ["bash -c $'\\k\\i\\l\\l\\ \\-1'", "bash -c $'\\k\\i\\l\\l\\ 123'"],
  ["bash -c $'kill -1\\xg'", "bash -c $'kill 123\\xg'"],
  ["bash -c $'login\\ctl kill-user dev'", "bash -c $'login\\ctl list-users'"],
  ["bash -c $'kill -1\\ug'", "bash -c $'kill 123\\ug'"],
  ["bash -c $'kill -1\\400'x", "bash -c $'kill 123\\400'x"],
  // zsh's \x reads its two characters as zstrtol does, a blank first: `\x 9` is a tab
  ["bash -c $'kill\\x 9-1'", "bash -c $'kill\\x 9123'"],
  // zsh's eval keeps a NUL inside its word, where it ends a command name: the rail reads it there as a blank
  ["eval $'kill\\0zz'$'\\ \\-1'", "eval $'kill\\0zz'$'\\ 123'"],
]

// What a seat does legitimately, and text that only mentions kill.
const ALLOW: readonly string[] = [
  'kill %1', 'kill 12345', 'kill -TERM 12345 12346', 'kill -0 12345', 'kill -9 12345', 'kill $!', 'kill "$PID"',
  'kill -s TERM "$PID"', 'kill --signal=$SIG 123', 'kill -s$SIG 123', 'kill -n$N 123',
  "pkill -x '[a-z]'", "killall '.*'", 'killall .', 'pkill -KILL node', 'pkill -SIGHUP node', 'kill -s TERM -- 12345', 'kill -l', 'kill -L',
  'kill $(cat /tmp/job.pid)', 'kill -9 $(cat /tmp/job.pid)',
  "pkill -f 'herdr agent wait --pane wCH:p1'", 'pkill -USR1 myapp', 'pkill -x node', 'pkill bash', 'killall node', 'killall -9 node',
  "echo 'kill $(ps -eo pid)'", 'echo "kill -1"', 'echo kill -1', 'git commit -m "no longer kill -1 on exit"',
  'ps aux | grep node', 'pgrep -f herdr', 'pidof node', 'ls /proc/self', 'ls /tmp',
  "cat <<'EOF'\nkill -1\nEOF", 'printf %s "kill x" > /dev/null',
  'git push origin HEAD', 'systemctl --user status foo.service', 'systemctl stop foo.service', 'loginctl list-sessions',
  'timeout 5 sleep 1', 'nice -n 5 make', 'sudo -u dev ls', 'bash -c "echo hi"', "sh -c 'ls /tmp'", 'eval "echo hi"', 'command -v kill',
  'exec bash', 'xargs echo', 'echo 123 | xargs kill',
  // fix r1 C1: words after a substitution are not a command of their own; C2/C3 controls
  'echo $(ps) kill', 'echo $(pgrep x) kill 1', 'echo $(date) kill -1', 'pkill -f foo $(echo x)',
  "bash -- -c 'kill -1'", 'command -v pkill', 'command -V pkill', 'command -pv pkill', 'command -v killall', 'command -v pgrep >/dev/null && kill 123',
  "pkill --exact '[a-z]'",
  // 0.14.1 (#1105): a word that is not an option ends the options before -c, so a script's own -c is not a shell string
  "bash -eo pipefail script.sh -c 'kill -1'", "bash -oe pipefail script.sh -c 'kill -1'",
  // after `--` the next word is the string, even one that looks like a cluster (bash runs it as the command)
  "bash -c -- -x 'kill -1'", "bash -c -- -o 'kill -1'",
  // fix r0 N4: a help or version request names no process
  'pkill --help', 'pkill -V', 'pkill -h', 'killall --version', 'killall -V', 'pkill --version',
  'time -p ls', 'builtin echo hi', 'bash -c -- \'echo hi\'', 'bash -O extglob -c \'echo hi\'',
  // `time` is reserved only unquoted at a command's head, and takes one `-p`: in each of these the word after the wrapper
  // is a program name (`!`, `-p`), so the kill is its argument and nothing is signalled
  'A=1 time ! kill -1', 'nohup ! kill -1', "'time' ! kill -1", 'time -p -p ! kill -1', 'xargs time ! kill -1',
  // `--` ends time's options, so a `-p` after it is the program's name
  'time -- -p ! kill -1',
  // one `--` only, and only the reserved word itself: a second `--`, or the time program by path, names a program
  'time -- -- ! kill -1', '/usr/bin/time ! kill -1', 'TIME ! kill -1',
  // a harmless command behind the reserved `time`, and the time program's own options before one
  'time ! true', 'time -f %e ! kill 123',
  // 0.14.2 (#1109): the same shapes with a harmless string; and after a bare - the next word is the string in every shell
  "zsh -cO 'echo hi'", "zsh -cO extglob 'echo hi'", "bash -cO extglob 'echo hi'", "zsh -c -oshwordsplit 'echo hi'",
  "bash -c - -x 'kill -1'", "zsh -c - - 'kill -1'", "zsh -c -- -x 'kill -1'", "zsh -- -c 'kill -1'",
  "zsh -c1 'echo hi'", "zsh --emulate sh -c 'echo hi'", "bash -c + 'echo hi'", "zsh -cb 'echo hi'",
  // zsh runs a word with no -c as a script path, not a string; --emulate after another option is an error in zsh; a long option takes no value, so an option-like word after it is not a string
  "zsh 'kill -1'", "zsh -- 'kill -1'", "zsh -x --emulate sh -c 'kill -1'", "zsh -c --braceccl '-x; kill -1'",
  // another name keeps its own grammar: ksh93's operand rule, mksh's -T and -o -c and yash's cmdline are not read for it, and no script is a string
  "bash -T /dev/tty2 -c 'kill -1'", "zsh -o -c 'kill -1'", "dash --cmd 'kill -1'", "bash 'kill -1'", "dash 'kill -1'", "ash 'kill -1'", "rbash 'kill -1'",
  "bash -o '' 'kill -1'", "dash --profile p -c 'kill -1'", "zsh -o cmdline 'kill -1'", "static-sh -e 'kill -1'", "busybox sh 'kill -1'",
  // mksh and yash run a first operand with no -c as a script path, not a string
  "mksh 'kill -1'", "lksh 'kill -1'", "mksh-static 'kill -1'", "yash 'kill -1'", "mksh -e 'kill -1'", "yash -e 'kill -1'", "mksh -o pipefail 'kill -1'",
  // harmless commands under each runner stay allowed
  "ksh -c 'echo ok'", "ksh93 -c 'echo ok'", "mksh -c 'echo ok'", "yash -c 'echo ok'", "rbash -c 'echo ok'", "ash -c 'echo ok'",
  "lksh -c 'echo ok'", "ksh 'echo ok'", "mksh -T /dev/tty2 -c 'echo ok'", "yash --cmd 'echo ok'", "ksh -o -c 'echo ok'",
  "static-sh -c 'echo ok'", 'busybox ls', 'busybox --list', "busybox sh -c 'echo ok'", "busybox ash -c 'echo ok'",
  'busybox kill 123', "ash -c-o pipefail 'echo ok'", "ash -c- -e 'echo ok'",
  // the narrowed ash reading is only for a cluster with an inner -: zsh runs the first string here, whose $0 is the kill text
  "zsh -cO -oshwordsplit -c 'echo S1' 'kill -1'",
  // the shell keeps these backslashes, or splits at the newline, so the string runs no kill
  "bash -c 'kill\\ -1'", "bash -c \"kill\\ -1\"", "bash -c \\\"kill\\ -1\\\"", "eval 'kill\\' -1", "bash -c $'kill\\\\ -1'",
  "bash -c $'kill\\n-1'", "bash -c echo\\ hi",
  // an attached fish value with a harmless string
  "fish -cecho\\ hi", "fish --command=echo\\ hi",
  // after any other wrapper, or under xargs, a zsh word names a program, and so does a quoted `repeat` or `nocorrect` or
  // one after an assignment
  "nohup noglob kill -1", "env noglob kill -1", "xargs noglob kill -1", "xargs repeat 1 kill -1", "command noglob kill -1",
  "'repeat' 1 kill -1", "'nocorrect' kill -1", "A=1 repeat 1 kill -1", "/usr/bin/noglob kill -1",
  // zsh rejects these or runs a program named by the next word: `noglob` and `nocorrect` are not head words
  "noglob ! kill -1", "noglob { kill -1 }", "noglob repeat 1 kill -1", "nocorrect repeat 1 kill -1", "nocorrect ! kill -1", "noglob -x kill -1",
  // a harmless command behind them
  "repeat 1 echo kill -1", "noglob echo kill -1",
  // env's grammars: a harmless command after the bare -, a -i or -- that every env runs as the command, a - that is an
  // operand of the command, and a harmless -S string
  "env - echo kill -1", "env -- -i kill -1", "env true - kill -1", "env -i -- -- kill -1", "env -S 'echo hi'",
  // quote removal on the words: a decoded word that is an operand of echo, a quoted `time` (the time program, which runs
  // a program named !), a decoded backslash, a signal name's value and an xargs command with no operand
  "echo $'\\x6bill' -1", "$'\\x74ime' ! kill -1", "kill $'\\x5c'-1", "kill -s $'\\x2d1' 123", "echo 1 | xargs $'\\x6bill'",
  // zsh's $'…': \M and \C together give 0x8a, not a newline, in either order; a NUL at the start leaves an empty word;
  // \x-1 is 0xff; zsh hands on $"…" with its $
  "bash -c $'echo\\M-\\C-jkill -1'", "bash -c $'echo\\C-\\M-jkill -1'", "bash -c $'\\0kill -1'", "eval $'kill \\x-1'",
  "bash -c $\"kill\"$'\\ -1'",
]

// Known limits: forms the rail does not read. Each is allowed here, and the README names it. A later
// widening changes one of these rows.
const LIMITS: ReadonlyArray<readonly [string, string]> = [
  ["python3 -c 'import os; os.kill(-1, 9)'", 'an interpreter'],
  ["node -e 'process.kill(-1)'", 'an interpreter'],
  ["perl -e 'kill 9, -1'", 'an interpreter'],
  ['K=kill; $K -1', 'a command word from a variable'],
  ['kill${IFS}-1', 'expansion glue in the command word'],
  ['alias k=kill; k -1', 'an alias'],
  ['k(){ kill "$@"; }; k -1', 'a function'],
  ["bash <<'X'\nkill -1\nX", 'a heredoc fed to a shell'],
  ["printf 'kill -1' > /tmp/s.sh; sh /tmp/s.sh", 'a script written, then run'],
  ['sh /tmp/s.sh', 'a script from an earlier call'],
  ['k\\\nill -1', 'a command word split by a continuation'],
  ["bash -c 'bash -c \"kill -1\"'", 'a shell string inside a shell string (one level only)'],
  ['eval "$CMD"', 'eval of a variable'],
  ['watch -n1 kill -1', 'watch'],
  ['ssh host kill -1', 'ssh'],
  ["su -c 'kill -1'", 'su -c'],
  ['parallel kill ::: 1', 'parallel'],
  ['systemd-run --user kill -1', 'systemd-run'],
  ["find /proc -maxdepth 1 -exec kill {} +", 'find -exec'],
  ['pgrep -u dev > /tmp/p', 'a PID list kept across calls (the listing half)'],
  ['kill -9 $NEG', 'a variable whose value is -1'],
  ['fuser -k /tmp/x', 'fuser -k'],
  ['pkill -s 0', 'pkill -s'],
  ['pkill -g 0', 'pkill -g'],
  ['pkill -P 1', 'pkill -P'],
  ['pkill -t pts/0', 'pkill -t'],
  ['sudo systemctl stop user@1001.service', 'system-scope systemctl stop user@<uid>'],
  ['pkill -v node', 'pkill -v (inverted match)'],
  ['pkill s', 'a pattern the probe set does not all match'],
  ['pkill "$PATTERN"', 'a pattern held in a variable'],
  ['pkill "foo("', 'a pattern that is not a regular expression'],
  ['script -c "kill -1" /dev/null', 'script -c'],
  ["env -S 'kill -1'", 'env -S (env splits the value into the command, #1173)'],
  ["env --split-string='kill -1'", 'env --split-string (#1173)'],
  ["env -S'kill -1'", 'env -S with its value attached (#1173)'],
  ["flock /tmp/l -c 'kill -1'", 'flock <file> -c'],
  ['coproc kill -1', 'coproc'],
  ['doas kill -1', 'a wrapper not in the list (doas)'],
  ['runuser -u dev kill -1', 'a wrapper not in the list (runuser)'],
  ['unshare kill -1', 'a wrapper not in the list (unshare)'],
  ['pkill -G 100', 'pkill -G'],
  ['pkill --parent 1', 'pkill --parent'],
  ['pkill --session 1', 'pkill --session'],
  ['pkill --group 0', 'pkill --group'],
  ['pkill --pidfile /tmp/p', 'pkill --pidfile'],
  ['pkill -F /tmp/pidfile', 'pkill -F'],
  ['pkill "$(cat /tmp/name)"', 'a pattern held in a quoted substitution'],
  // shells and applets outside KILL_SHELLS, and names the extra readings do not speak for (#1126, #1127)
  // fish's string grammar past its command prefixes: a fish string is read as POSIX text
  ["fish -c 'kill 123 (echo x) -1'", 'fish: an unquoted (…) substitution cuts the command'],
  ["fish -c 'kill \\x2d1'", 'fish: an escape outside quotes spells the operand'],
  ['fish -c "echo \'x\\\\\' \'; kill -1; echo \'\'"', "fish: a single quote takes \\' and runs on"],
  ["fish -c 'kill {,-1}'", 'fish: brace expansion, as under sh'],
  ["fish -c 'kill (echo -1)'", "fish: a substitution's value, as under sh"],
  ["rksh -c 'kill -1'", 'rksh (the pdksh line) is not read; unprobed, source not read'],
  ["rksh93 -c 'kill -1'", 'rksh93 (restricted ksh93) is not read by name; unprobed'],
  ["rmksh -c 'kill -1'", 'rmksh (restricted mksh) is not read by name; unprobed'],
  ["rlksh -c 'kill -1'", 'rlksh (restricted lksh) is not read by name; unprobed'],
  ["sh 'kill -1'", 'sh on a host where sh is ksh93 runs its first operand: the extra readings are keyed on the runner name'],
  ["sh -T /dev/tty2 -c 'kill -1'", 'sh on a host where sh is mksh (Android) takes -T <value>: keyed on the runner name'],
  ["env sh -o -c 'kill -1'", 'sh on a host where sh is mksh or ksh93 takes -c as the -o value: keyed on the runner name'],
  ["sh --profile p -c 'kill -1'", 'sh on a host where sh is yash takes --profile <value>: keyed on the runner name'],
  ["oksh -c 'kill -1'", 'oksh (the pdksh line) is not read; unprobed, source not read'],
  ["pdksh -c 'kill -1'", 'pdksh is not read; unprobed, source not read'],
  ["posh -c 'kill -1'", 'posh is not read; unprobed, source not read'],
  ["toybox sh -c 'kill -1'", 'toybox is not a wrapper the rail reads'],
  // round 2 C7, C8, C10
  ['kill 123 $(case x in a) echo 1;; esac) -1', "a case pattern's ) inside $(…) ends the span early"],
  ['kill 123 $(echo ${x:-)}) -1', 'a ) inside ${…} inside $(…) ends the span early'],
  ["pkill node '.*'", "a second pkill operand (procps rejects it; BSD and macOS pkill take several)"],
  ["bash -c kill\\ \\\n-1", "a -c or eval word split by a line continuation"],
  ["kill -9 -\\\n1", "an operand split by a line continuation"],
  ["A+=1 kill -1", "an append assignment before the command word (#1175)"],
  ["a[1]=x kill -1", "an array element assignment before the command word (#1175)"],
  ["{kill -1}", "zsh: a brace with no blank (#1170)"],
  ["repeat 1 {kill -1}", "zsh: a brace with no blank after repeat (#1170)"],
  ["if [[ 1 ]] kill -1", "zsh: the short if (#1170)"],
  ["while [[ 1 ]] { kill -1; break }", "zsh: the short while (#1170)"],
  ["{ true } always { kill -1 }", "zsh: an always block (#1170)"],
  ["function { kill -1 }", "zsh: an anonymous function (#1170)"],
]

describe('killRule: refuse, with a near-miss control beside each row', () => {
  for (const [command, control] of REFUSE) {
    test(`refuses ${JSON.stringify(command)}`, () => {
      const deny = killRule(command)
      expect(deny).toBeDefined()
      expect(deny).toContain('kill rail')
    })
    test(`control: allows ${JSON.stringify(control)}`, () => {
      expect(killRule(control)).toBeUndefined()
    })
  }
})

describe('killRule: what a seat does legitimately stays allowed', () => {
  for (const command of ALLOW) test(`allows ${JSON.stringify(command)}`, () => { expect(killRule(command)).toBeUndefined() })
})

describe('killRule: known limits are not read (each is in the README)', () => {
  for (const [command, why] of LIMITS) test(`${why}: ${JSON.stringify(command)} is allowed`, () => { expect(killRule(command)).toBeUndefined() })
})

// 0.14.2 (#1109): every shell name is read twice (bash's grammar and zsh's) into one scan. Where the two
// readings pick different words, one listing and the other signaling is refused as "lists and signals", though no
// shell runs both. A deliberate false stop: it can only add a refusal.
describe('killRule: the two readings share one scan (a deliberate false stop)', () => {
  test("bash -cO 'ps aux' 'kill 123': bash's reading signals, zsh's lists, so the call is refused", () => {
    expect(killRule("bash -cO 'ps aux' 'kill 123'")).toContain('lists processes and signals')
  })
  test('control: the same call with an echo in either slot is allowed', () => {
    expect(killRule("bash -cO 'ps aux' 'echo hi'")).toBeUndefined()
    expect(killRule("bash -cO 'echo hi' 'kill 123'")).toBeUndefined()
  })
})

// 0.14.2 (#1109): the rail never approves what 0.14.1 refused. LEGACY is 0.14.1's reader for the words of a
// call, frozen here as the oracle: it returns the index of the word it read as the shell string. The grid is every
// sequence of one to three option words, then two strings, run under each shell name in KILL_SHELLS and with the
// kill in either string or both. Strings only: nothing here runs a command.
const GRID_WORDS = ['-c', '+c', '-cO', '-Oc', '-co', '-coshwordsplit', '-ec', '-e', '-b', '-o', '-oshwordsplit', '-O', '+O', '+ec', '+', 'pipefail', '-', '--']
function legacyIndex(args: readonly string[]): number | undefined {
  let seenC = false
  let dashed = false
  for (let k = 0; k < args.length; k++) {
    const arg = args[k]!
    if (arg === '--rcfile' || arg === '--init-file') { k += 1; continue }
    if (!dashed && /^[-+][A-Za-z]+$/.test(arg)) {
      if (arg.includes('c')) seenC = true
      k += arg.replace(/[^oO]/g, '').length
      continue
    }
    if (!seenC) {
      if (arg === '--' || (!arg.startsWith('-') && !arg.startsWith('+'))) return undefined
      continue
    }
    if (arg === '--' && !dashed) { dashed = true; continue }
    if (!dashed && arg.length > 1 && (arg.startsWith('-') || arg.startsWith('+'))) continue
    return k
  }
  return undefined
}
const GRID_NAMES = ['sh', 'bash', 'zsh', 'dash', 'rbash', 'ash', 'static-sh', 'ksh', 'ksh93', 'mksh', 'lksh', 'mksh-static', 'yash']
describe('killRule: the grid of option forms never loosens against the 0.14.1 reader', () => {
  const forms: string[][] = []
  const grow = (prefix: string[]): void => {
    if (prefix.length > 0) forms.push([...prefix, 'S1', 'S2'])
    if (prefix.length < 3) for (const w of GRID_WORDS) grow([...prefix, w])
  }
  grow([])
  test('the grid holds 6174 forms', () => { expect(forms.length).toBe(6174) })
  for (const name of GRID_NAMES) {
    test(`${name}: every form 0.14.1 refuses is still refused (0 loosened over 3 kill placements)`, () => {
      const loosened: string[] = []
      let refusedBefore = 0
      for (const form of forms)
        for (const kill of ['S1', 'S2', 'all']) {
          const words = form.map(w => (w === 'S1' || w === 'S2') && (kill === 'all' || kill === w) ? "'kill -1'" : /^S\d$/.test(w) ? `'echo ${w}'` : w)
          const at = legacyIndex(form)
          if (at === undefined || words[at] !== "'kill -1'") continue
          refusedBefore++
          const command = `${name} ${words.join(' ')}`
          if (killRule(command) === undefined) loosened.push(command)
        }
      expect(refusedBefore).toBe(6118)
      expect({ loosened: loosened.length, first: loosened.slice(0, 3) }).toEqual({ loosened: 0, first: [] })
    })
  }
})

// The refusals of this grid under `sh`, as the reader before busybox ash was added read it: the same 8342 commands, so
// the ash reading and the new names add no refusal here. The digest is of the refused commands, one per line, in grid
// order (no grid form throws); a refusal added or dropped changes it.
// cyrb53: a 53-bit string hash (the hooks module may import nothing but its own files).
function cyrb53(str: string): number {
  let h1 = 0xdeadbeef, h2 = 0x41c6ce57
  for (let i = 0; i < str.length; i++) {
    const ch = str.charCodeAt(i)
    h1 = Math.imul(h1 ^ ch, 2654435761)
    h2 = Math.imul(h2 ^ ch, 1597334677)
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909)
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909)
  return 4294967296 * (2097151 & h2) + (h1 >>> 0)
}
const DIGEST = 5974084756761064
describe('killRule: the grid adds no refusal and every name is read alike', () => {
  const forms: string[][] = []
  const grow = (prefix: string[]): void => {
    if (prefix.length > 0) forms.push([...prefix, 'S1', 'S2'])
    if (prefix.length < 3) for (const w of GRID_WORDS) grow([...prefix, w])
  }
  grow([])
  // A throw is not a refusal: a form origin refused that now throws fails these tests.
  const refuses = (command: string): boolean => {
    try { return killRule(command) !== undefined } catch { return false }
  }
  const unreadBy = (command: string): boolean => {
    try { killRule(command); return false } catch { return true }
  }
  const commands: string[] = []
  for (const form of forms)
    for (const kill of ['S1', 'S2', 'all'])
      commands.push(form.map(w => (w === 'S1' || w === 'S2') && (kill === 'all' || kill === w) ? "'kill -1'" : /^S\d$/.test(w) ? `'echo ${w}'` : w).join(' '))
  test('the refused commands under sh are the 8342 the earlier reader refused', () => {
    const refused = commands.map(c => `sh ${c}`).filter(refuses)
    expect(commands.filter(c => unreadBy(`sh ${c}`))).toEqual([])
    expect(refused.length).toBe(8342)
    expect(cyrb53(refused.join('\n'))).toBe(DIGEST)
  })
  const base = commands.map(c => refuses(`sh ${c}`))
  // A name with its own reading refuses every form sh refuses (a throw is not a refusal) and adds a frozen set of forms:
  // the count and the digest of the set. Most of the extras are forms where the real shell runs no string at all (an
  // unknown option or value, -s, -D, -n), a deliberate false stop; the rest are forms whose string the shell runs.
  const OWN: Readonly<Record<string, readonly [number, number]>> = {
    ksh: [1283, 4786229330850382], ksh93: [1283, 1105668869864466], mksh: [241, 7812842104486236],
    lksh: [241, 4915069328647694], 'mksh-static': [241, 8961682949933950], yash: [236, 5489139783732189],
  }
  for (const name of Object.keys(OWN)) {
    test(`${name} refuses every form sh refuses, and its own reading adds the frozen set`, () => {
      const extra = commands.filter((c, k) => !base[k] && refuses(`${name} ${c}`))
      const lost = commands.filter((c, k) => base[k] && !refuses(`${name} ${c}`))
      expect({ lost: lost.length, first: lost.slice(0, 3) }).toEqual({ lost: 0, first: [] })
      expect({ count: extra.length, hash: cyrb53(extra.map(c => `${name} ${c}`).join('\n')) }).toEqual({ count: OWN[name]![0], hash: OWN[name]![1] })
    })
  }
  for (const name of [...GRID_NAMES.slice(1), 'busybox sh'].filter(n => !Object.hasOwn(OWN, n))) {
    test(`${name} gets the verdict sh gets, for every form`, () => {
      const differ = commands.filter((c, k) => refuses(`${name} ${c}`) !== base[k]).map(c => `${name} ${c}`)
      expect({ differing: differ.length, first: differ.slice(0, 3) }).toEqual({ differing: 0, first: [] })
    })
  }
})

// A reading whose string cannot be read (an unclosed `$(`) must not hide a refusal another reading found.
describe('killRule: a refusal from one reading survives a throw from another', () => {
  for (const command of [
    "sh -c-o '$(x' 'kill -1'", "bash -cO '$(x' 'kill -1'", "zsh -c-o '$(x' 'ps; kill 1'",
    // the throwing string comes first, and the refusal after it
    "ksh -c '$(x'; kill -1", "busybox sh -c '$(x'; kill -1", "sh -c-o '$(x'; kill -1", "mksh -c '$(x' && kill -1",
    "yash -c '$(x'; pkill -u dev", "bash -Oc 'kill -1' '$(x'", "busybox ash -c '$(x'; kill -1",
    "ksh -c '$(((((((((((x)))))))))))'; kill -1", 'xargs busybox '.repeat(9) + 'echo; kill -1',
  ])
    test(`refuses ${JSON.stringify(command)} with the kill reason, not a throw`, () => {
      expect(killRule(command)).toContain('kill rail')
    })
  test('control: a harmless unreadable string is still thrown, to be refused as unread by the glue', () => {
    expect(() => killRule("sh -c-o '$(x' 'echo ok'")).toThrow()
    expect(() => killRule("bash -cO '$(x' 'echo ok'")).toThrow()
    expect(() => killRule("ksh -c '$(x'; echo ok")).toThrow()
    expect(() => killRule("busybox sh -c '$(x'; kill 123")).toThrow()
  })
  test('control: the refusal first, then the throwing string, still refuses', () => {
    expect(killRule("kill -1; ksh -c '$(x'")).toContain('kill rail')
  })
  // A throw inside a substitution, or a substitution nested too deep, beside a refusal: each hold in killRead is read.
  const DEEP = '$('.repeat(10) + 'x' + ')'.repeat(10)
  for (const command of ['echo $(echo $(x;kill -1)', 'echo $(kill -1; echo $(x)', `echo ${DEEP}; kill -1`, `kill -1; echo ${DEEP}`])
    test(`refuses ${JSON.stringify(command)} with the kill reason, not a throw`, () => {
      expect(killRule(command)).toContain('kill rail')
    })
  test('known limit: an unclosed $( outside quotes makes its whole string unread, so a refusal before it in the same string is not found', () => {
    expect(() => killRule('kill -1; echo $(x')).toThrow()
    expect(killRule('echo $(x; kill -1')).toContain('kill rail')
  })
})

// ksh93 turns -c off with +c and then runs its first operand as a command, so this is a true refusal, not a false stop.
describe("killRule: ksh +c runs the string as a command", () => {
  test("ksh +c 'kill -1' is refused: the first operand is run", () => {
    expect(killRule("ksh +c 'kill -1'")).toContain('kill rail')
    expect(killRule("ksh93 +c 'kill -1'")).toContain('kill rail')
  })
  test('control: the same shapes with a harmless string are allowed', () => {
    expect(killRule("ksh +c 'echo ok'")).toBeUndefined()
    expect(killRule("ksh93 +c 'kill 123'")).toBeUndefined()
  })
})

// Deliberate false stop: yash takes the + after -c as its string and runs nothing else, so the kill text is only $0.
describe('killRule: deliberate false stop of the yash grammar', () => {
  test("yash -c + 'kill -1' is refused though yash runs the + as the string", () => {
    expect(killRule("yash -c + 'kill -1'")).toContain('kill rail')
  })
  test('control: the same shape with a harmless string is allowed', () => {
    expect(killRule("yash -c + 'echo ok'")).toBeUndefined()
  })
})

// Deliberate false stops of the reserved `time`: each form runs nothing in the shell named, and is refused. `\time` reads
// as `time` (the shell runs the time program, which runs a program named `!`); `then` after `time` is a syntax error;
// zsh and fish take no `-p` or `--` after `time`; dash's `time` is not reserved, so it runs the time program; a
// redirection is dropped before the head words are read; zsh and fish take no `time` after `time`; bash and fish reserve
// `time` only at a pipeline's start.
describe('killRule: deliberate false stops of the reserved time', () => {
  const rows: ReadonlyArray<readonly [string, string]> = [
    ['\\time ! kill -1', '\\time ! kill 123'],
    ['time then kill -1', 'time then kill 123'],
    ["zsh -c 'time -p ! kill -1'", "zsh -c 'time -p ! kill 123'"],
    ["fish -c 'time -- ! kill -1'", "fish -c 'time -- ! kill 123'"],
    ["dash -c 'time ! kill -1'", "dash -c 'time ! kill 123'"],
    ['time >/dev/null ! kill -1', 'time >/dev/null ! kill 123'],
    ['>/dev/null time ! kill -1', '>/dev/null time ! kill 123'],
    ['time \\-p ! kill -1', 'time \\-p ! kill 123'],
    ["zsh -c 'time time ! kill -1'", "zsh -c 'time time ! kill 123'"],
    ["bash -c 'true | time ! kill -1'", "bash -c 'true | time ! kill 123'"],
  ]
  for (const [command, control] of rows) {
    test(`${JSON.stringify(command)} is refused`, () => { expect(killRule(command)).toContain('kill rail') })
    test(`control: ${JSON.stringify(control)} is allowed`, () => { expect(killRule(control)).toBeUndefined() })
  }
})

// The -c or eval word is also read as before, with its quote characters taken off and every backslash kept, so the stops
// of that reading stay: here bash hands on `kill --\ -1`, and kill gets the one operand `-- -1`. zsh's words are read in
// every shell, and `repeat`'s count is not evaluated: `repeat 0` and a count that is not a number run nothing in zsh,
// a backslash in `repeat` or `nocorrect` names a program there (the reader drops the backslash), `nocorrect` after
// `noglob` is a program, and dash runs a program named `noglob`. A vertical tab or form feed that $'…' hands on inside a
// -c word is not a blank to the shell (kill gets the one operand `123<VT>-1`), but the rail splits at it, and so on an
// operand (`kill $'\v-1'`). Every word of a command is also read as before, with its quote characters taken off: bash
// hands on `'-1` here. bash's quote removal and zsh's are both read, in every shell: `$"kill" -1` runs `$kill` under zsh,
// and the zsh-only rows above run nothing under bash. zsh's eval keeps a NUL inside its word, and the rail reads it as a
// blank: zsh runs an empty command name in `eval $'\0 kill -1'`, and gives kill an operand that is not a number in
// `eval $'\k\i\l\l\ '$'-1\0zz'`. zsh's reading of a command's words ends each at a NUL, kill's operands too, though zsh's
// kill keeps the NUL and bash's gets `-1x`: neither runs `kill -1` for `kill $'-1\0'x`. Every reading's heads share one
// scan: bash's quote removal names `ps` and zsh's names `kill` in `$"ps" aux; $'\k\i\l\l' 123`. zsh's `noglob` is read
// beside bash's quote removal of the word after it, though bash runs a program named noglob and zsh hands on `ki$ll`:
// neither runs a kill in `noglob $'\x6b'"i"$"l""l" -1`.
describe('killRule: deliberate false stops of the quote removal and the zsh words', () => {
  const rows: ReadonlyArray<readonly [string, string]> = [
    ["bash -c k'ill '$'--\\\\ -1'", "bash -c k'ill '$'--\\\\ 123'"],
    ["kill $'\\v-1'", "kill $'\\v123'"],
    ["kill \"'\"-1", "kill \"'\"123"],
    ["$\"kill\" -1", "$\"kill\" 123"],
    ["eval $'\\0 kill -1'", "eval $'\\0 kill 123'"],
    ["eval $'\\k\\i\\l\\l\\ '$'-1\\0zz'", "eval $'\\k\\i\\l\\l\\ '$'123\\0zz'"],
    ["repeat 0 kill -1", "repeat 0 kill 123"],
    ["repeat echo kill -1", "repeat echo kill 123"],
    ["\\repeat 1 kill -1", "\\repeat 1 kill 123"],
    ["re\\peat 1 kill -1", "re\\peat 1 kill 123"],
    ["nocorrec\\t kill -1", "nocorrec\\t kill 123"],
    ["bash -c $'kill 123\\v-1'", "bash -c $'echo 123\\v-1'"],
    ["bash -c $'kill 123\\f-1'", "bash -c $'echo 123\\f-1'"],
    ["noglob nocorrect kill -1", "noglob nocorrect kill 123"],
    ["dash -c 'noglob kill -1'", "dash -c 'noglob kill 123'"],
    ["kill $'-1\\0'x", "kill $'123\\0'x"],
    ["$\"ps\" aux; $'\\k\\i\\l\\l' 123", "$\"ls\" aux; $'\\k\\i\\l\\l' 123"],
    ["noglob $'\\x6b'\"i\"$\"l\"\"l\" -1", "noglob $'\\x6b'\"i\"$\"l\"\"l\" 123"],
  ]
  for (const [command, control] of rows) {
    test(`${JSON.stringify(command)} is refused`, () => { expect(killRule(command)).toContain('kill rail') })
    test(`control: ${JSON.stringify(control)} is allowed`, () => { expect(killRule(control)).toBeUndefined() })
  }
})

// env is read three ways, and the rail refuses if any reading does. An option an env rejects is read as a flag, though
// that env runs nothing: an unknown letter, -0 with a command, a GNU-only option beside a BSD-only one. The generic
// reading keeps its own stops: GNU runs -1 with argv0 `kill` in `env -a kill -1`, and every env runs -i in
// `env A=1 -i kill -1`.
describe("killRule: deliberate false stops of env's grammars", () => {
  const rows: ReadonlyArray<readonly [string, string]> = [
    ['env -x kill -1', 'env -x kill 123'],
    ['env - -0 kill -1', 'env - -0 kill 123'],
    ['env -ax -P /usr/bin kill -1', 'env -ax -P /usr/bin kill 123'],
    ['env -a kill -1', 'env -a kill 123'],
    ['env A=1 -i kill -1', 'env A=1 -i kill 123'],
  ]
  for (const [command, control] of rows) {
    test(`${JSON.stringify(command)} is refused`, () => { expect(killRule(command)).toContain('kill rail') })
    test(`control: ${JSON.stringify(control)} is allowed`, () => { expect(killRule(control)).toBeUndefined() })
  }
})

// A name speaks only for its own grammar: a form another name's reading refuses is not refused under it.
describe('killRule: an extra reading speaks for its own name only', () => {
  const forms = ["'kill -1'", "-e 'kill -1'", "-o -c 'kill -1'", "-T /dev/tty2 -c 'kill -1'", "-o '' 'kill -1'", "--profile p -c 'kill -1'", "--cmd 'kill -1'", "-o cmdline 'kill -1'", "+ 'kill -1'"]
  for (const name of ['sh', 'bash', 'zsh', 'dash', 'ash', 'rbash', 'static-sh'])
    test(`${name} gets the verdict sh gets for each own-name form`, () => {
      expect(forms.map(f => `${name} ${f}`).map(c => killRule(c) !== undefined)).toEqual(forms.map(f => killRule(`sh ${f}`) !== undefined))
    })
  for (const name of ['lksh', 'mksh-static'])
    test(`${name} reads as mksh`, () => {
      for (const f of forms) expect(killRule(`${name} ${f}`) !== undefined).toBe(killRule(`mksh ${f}`) !== undefined)
    })
})

// Throw-first forms: a string no reading can finish (an unclosed `$(`) beside a refusal, in either order, under every
// runner spelling and several option forms. Every command refused before busybox and the new names were read is in the
// refused set below (checked against that reader when it was frozen); a form that throws and also carries a refusal
// fails here, because the refused set would lose it.
describe('killRule: a throw in a runner string never hides a refusal elsewhere in the call', () => {
  const NAMES = ['sh', 'bash', 'zsh', 'dash', 'rbash', 'ash', 'static-sh', 'ksh', 'ksh93', 'mksh', 'yash', 'busybox sh', 'busybox ash']
  const OPTS = ['-c', '-c-o', '-cO', '-c- -e', '-Oc', '-ec']
  const TAILS = ['; kill -1', ' && kill -1', '; pkill -u dev', '; ps; kill 1', ' | xargs kill -1', '; echo ok']
  const commands: string[] = []
  for (const n of NAMES)
    for (const o of OPTS) {
      for (const t of TAILS) commands.push(`${n} ${o} '$(x'${t}`)
      commands.push(`${n} ${o} '$(x' 'kill -1'`, `${n} ${o} 'kill -1' '$(x'`, `${n} ${o} '$(x' 'echo ok'`)
    }
  const refused: string[] = []
  const unread: string[] = []
  for (const c of commands) {
    try { if (killRule(c) !== undefined) refused.push(c) } catch { unread.push(c) }
  }
  test('702 forms: 507 refused, and the other 195 throw only because nothing in them refuses', () => {
    expect(commands.length).toBe(702)
    expect({ refused: refused.length, hash: cyrb53(refused.join('\n')) }).toEqual({ refused: 507, hash: 2828278963702788 })
    expect({ unread: unread.length, hash: cyrb53(unread.join('\n')) }).toEqual({ unread: 195, hash: 2579890534524799 })
  })
})

// An unreadable string (an unclosed `$(`) that a name's own reading takes as a string, beside a refusal in a later
// command: the refusal is found, and with nothing to refuse the call is thrown or allowed, never refused. Every head
// here throws on its own (checked below), so each row holds a real throw; the second block lists heads that never read
// the string, where the refusal has no throw to survive.
const THROWING_HEADS: Readonly<Record<string, readonly string[]>> = {
  ksh: ['', '-e', '-o -c', '-cT /dev/tty2', '-T /dev/tty2 -c', '-o pipefail -c', '--cmd', '-o cmdline', '+o nocmdline', '--', '-'],
  ksh93: ['', '-e', '-o -c', '-o pipefail -c', '--cmd', '-o cmdline', '+o nocmdline', '--', '-'],
  mksh: ['-o -c', '-cT /dev/tty2', '-T /dev/tty2 -c', '-o pipefail -c', '--cmd'],
  lksh: ['-o -c', '-cT /dev/tty2', '-T /dev/tty2 -c', '-o pipefail -c', '--cmd'],
  'mksh-static': ['-o -c', '-cT /dev/tty2', '-T /dev/tty2 -c', '-o pipefail -c', '--cmd'],
  yash: ['-o -c', '-o pipefail -c', '--cmd', '-o cmdline', '--profile p -c', '+o nocmdline'],
}
const QUIET_HEADS: Readonly<Record<string, readonly string[]>> = {
  ksh: ['--profile p -c'], ksh93: ['-cT /dev/tty2', '-T /dev/tty2 -c', '--profile p -c'],
  mksh: ['', '-e', '-o cmdline', '--profile p -c', '+o nocmdline', '--', '-'], lksh: ['', '-e', '-o cmdline', '--profile p -c', '--'],
  'mksh-static': ['', '-e', '-o cmdline', '--profile p -c', '--'], yash: ['', '-e', '-cT /dev/tty2', '-T /dev/tty2 -c', '--', '-'],
}
const throwRows = (heads: Readonly<Record<string, readonly string[]>>): Array<readonly [string, boolean]> => {
  const rows: Array<readonly [string, boolean]> = []
  for (const [n, opts] of Object.entries(heads))
    for (const o of opts) {
      const head = `${n} ${o}`.replace(/ +$/, '')
      for (const t of ['; kill -1', ' && pkill -u dev', '; ps; kill 1']) rows.push([`${head} '$(x'${t}`, true])
      rows.push([`${head} '$(x'; echo ok`, false], [`${head} '$(x' 'echo ok'`, false])
    }
  return rows
}
const verdict = (command: string): string => {
  try { return killRule(command) !== undefined ? 'refused' : 'allowed' } catch { return 'thrown' }
}
describe("killRule: a throw never hides a refusal under a name's own reading", () => {
  const rows = throwRows(THROWING_HEADS)
  test('every head throws on an unreadable string by itself', () => {
    const calm = Object.entries(THROWING_HEADS).flatMap(([n, opts]) => opts.map(o => `${n} ${o}`.replace(/ +$/, ''))).filter(h => verdict(`${h} '$(x'`) !== 'thrown')
    expect(calm).toEqual([])
  })
  test('every form with a refusal after the throwing string is refused, and none without one is', () => {
    const wrong = rows.filter(([command, refusal]) => refusal !== (verdict(command) === 'refused')).map(([command]) => command)
    expect(wrong).toEqual([])
    expect(rows.length).toBe(205)
  })
  test('control: a form that runs the unreadable string and refuses nothing is thrown', () => {
    for (const command of ["ksh '$(x'; echo ok", "ksh93 -e '$(x'", "mksh -T /dev/tty2 -c '$(x'", "lksh -o -c '$(x'", "yash --profile p -c '$(x'", "yash -o cmdline '$(x'", "ksh -cT /dev/tty2 '$(x'"])
      expect(() => killRule(command)).toThrow()
  })
})
describe("killRule: a refusal after a string a name's own reading never takes as a string", () => {
  test('the heads read nothing unreadable, and the refusal after them is still found', () => {
    const rows = throwRows(QUIET_HEADS)
    const thrown = Object.entries(QUIET_HEADS).flatMap(([n, opts]) => opts.map(o => `${n} ${o}`.replace(/ +$/, ''))).filter(h => verdict(`${h} '$(x'`) === 'thrown')
    expect(thrown).toEqual([])
    const wrong = rows.filter(([command, refusal]) => refusal !== (verdict(command) === 'refused')).map(([command]) => command)
    expect(wrong).toEqual([])
  })
})

describe('killRule: a ( inside ${…} inside $(…) leaves the span open, so the call is unread (a deliberate false stop)', () => {
  test('echo $(echo ${x:-(}) ; kill 123 throws (a throw is refused as unread by both glues; see the depth-8 glue rows)', () => {
    expect(() => killRule('echo $(echo ${x:-(}) ; kill 123')).toThrow()
  })
})

describe('killRule: the deny text says what to do instead', () => {
  const text = killRule('kill $(ps -eo pid,args 2>/dev/null) 2>/dev/null; true')!
  test('list first, read the PIDs, kill by literal PID', () => {
    expect(text).toContain('list')
    expect(text).toContain('literal PID')
  })
  test('names the job stop on each host', () => {
    expect(text).toContain('proc://<id>/kill')
    expect(text).toContain('TaskStop')
  })
  test('names the reason in its own words', () => {
    expect(killRule('kill -1')).toContain('-1')
    expect(killRule('pkill -u dev')).toContain('-u')
  })
})

// fix r0 N2 and N3: what the rail cannot bound it does not read, and a throw is the glues' fail-closed (KILL_UNCHECKED).
describe('killRule: bounds', () => {
  const nest = (depth: number): string => {
    let text = 'kill -9 -1'
    for (let i = 0; i < depth; i++) text = `echo "$(${text})"`
    return text
  }
  test('8 substitutions deep is still read and refused', () => { expect(killRule(nest(8))).toContain('kill rail') })
  test('control: 8 deep and clean is allowed', () => { expect(killRule(nest(8).replace('kill -9 -1', 'kill 123'))).toBeUndefined() })
  test('deeper than 8 substitutions is unread: it throws, so a glue refuses it', () => {
    expect(() => killRule(nest(9))).toThrow()
    expect(() => killRule(nest(9).replace('kill -9 -1', 'kill 123'))).toThrow()
  })
  test('a substitution that never closes is unread: it throws', () => {
    expect(() => killRule('kill 123 $(echo 1')).toThrow()
    expect(() => killRule('kill 123 $((1+1')).toThrow()
  })
  test('a -c or eval word whose quote removal leaves an unclosed $( is unread: it throws', () => {
    expect(() => killRule('bash -c echo\\ \\$\\(')).toThrow()
    expect(() => killRule('eval echo cost: \\$\\(5')).toThrow()
  })
  test('control: the same word with its $( closed is read and allowed', () => {
    expect(killRule('bash -c echo\\ \\$\\(true\\)')).toBeUndefined()
  })
  test('the first refusal stands: a later refused command of another kind does not replace its text', () => {
    expect(killRule('kill -1; killall5')).toContain('kill -1')
    expect(killRule('kill -1; killall5')).not.toContain('killall5')
    expect(killRule('kill -1; systemctl --user exit')).not.toContain('systemctl')
    expect(killRule('kill -1; loginctl kill-user dev')).not.toContain('loginctl')
    expect(killRule('killall5; kill -1')).toContain('killall5')
  })
  test('8 nested xargs are read; 9 are unread', () => {
    expect(killRule('ps | ' + 'xargs '.repeat(8) + 'kill 1')).toContain('kill rail')
    expect(() => killRule('ps | ' + 'xargs '.repeat(9) + 'kill 1')).toThrow()
  })
  test('a chain more than 8 deep in one reading is unread, though another reading reaches its words less deep', () => {
    // where env's generic reading takes -a as a flag and `$'\x78args'` is decoded, each unit is two xargs (10 in all);
    // where env's own grammar takes `$'\x78args'` as -a's value, each unit is one
    const chain = (units: number): string => "xargs env -a $'\\x78args' ".repeat(units) + 'echo'
    expect(() => killRule(chain(5))).toThrow()
    expect(killRule(chain(4))).toBeUndefined()
  })
  test('a ninth xargs in one reading is unread, though another reading walked its words first, less deep', () => {
    // the deepest reading has nine xargs, the last 8 deep; the one-xargs-per-unit reading reaches the same words first
    const chain = (units: number): string => "xargs env -a $'\\x78args' ".repeat(units) + 'xargs echo'
    expect(() => killRule(chain(4))).toThrow()
    expect(killRule(chain(3))).toBeUndefined()
  })
  test('a chain that branches at every level is walked once per start word', () => {
    // Each level's words put xargs's command at a different word in each reading, so walking every branch again is 9,841
    // walks of the operands (about 28 s on a quiet host) where walking each start word once is 9 (about 0.03 s). The bound
    // sits between them, far from both.
    const started = performance.now()
    try { killRule("xargs $'-\\x6e' $\"-n\" -i ".repeat(8) + 'zq' + " $'\\x61'".repeat(2000)) } catch {}
    expect(performance.now() - started).toBeLessThan(5000)
  })
  test('a 30 KB xargs chain finishes under a second', () => {
    const started = performance.now()
    try { killRule('ps | ' + 'xargs '.repeat(5000) + 'kill 1') } catch {}
    expect(performance.now() - started).toBeLessThan(1000)
  })
})
