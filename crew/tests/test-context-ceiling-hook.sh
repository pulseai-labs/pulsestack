#!/usr/bin/env bash
#
# crew — the context-ceiling hook (#456), behaviour at its interface.
#
# Feeds hook-input JSON on stdin to hooks-handlers/context-ceiling.sh the way
# Claude Code does, against a transcript written per case, and checks stdout
# and the exit code. Silent cases sit beside firing controls built by the same
# fixture writers, so a handler that prints nothing cannot pass. A few cases run
# the handler against a PATH stripped of one binary, or with a jq stub that
# fails, because three of its notices are about a read it could not make at all.
#
# Usage:    bash crew/tests/test-context-ceiling-hook.sh
# Exit:     0 if every case holds; 1 otherwise.
# Deps:     bash 3.2+, jq.
# Override: CONTEXT_CEILING_HOOK=<path> runs the cases against another copy of
#           the handler (the mutation checks use it).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="${CONTEXT_CEILING_HOOK:-$PLUGIN_ROOT/hooks-handlers/context-ceiling.sh}"
BASH_BIN="$(command -v bash)"

# shellcheck source=/dev/null
. "$SCRIPT_DIR/_helpers.sh"   # counters, colours, pass/fail, report

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! command -v jq >/dev/null 2>&1; then
  fail "jq available on PATH" "the cases build hook input with jq"; report; exit 1
fi

# assistant_line <message id> <input> <cache_creation> <cache_read> [sidechain]
# One assistant record in the shape Claude Code 2.1.270 writes, trimmed to the
# keys the handler reads and their neighbours.
assistant_line() {
  jq -cn --arg id "$1" --argjson i "$2" --argjson cc "$3" --argjson cr "$4" \
    --argjson sc "${5:-false}" \
    '{parentUuid: "p", isSidechain: $sc, type: "assistant", uuid: "u",
      timestamp: "2026-09-13T00:00:00Z",
      message: {id: $id, type: "message", role: "assistant", model: "claude-opus-5",
                content: [{type: "text", text: "x"}],
                usage: {input_tokens: $i, cache_creation_input_tokens: $cc,
                        cache_read_input_tokens: $cr, output_tokens: 10}}}'
}

user_line() { jq -cn '{type: "user", message: {role: "user", content: "hi"}, uuid: "v"}'; }

# transcript <name> <total> -> path of a transcript whose latest assistant record totals <total>
transcript() {
  f="$TMP/$1.jsonl"
  { user_line; assistant_line "msg_$1" 10 90 "$(( $2 - 100 ))"; } > "$f"
  printf '%s' "$f"
}

# input <event> <transcript path> [command] -> hook input JSON for that event
input() {
  if [ "$1" = PreToolUse ]; then
    jq -cn --arg t "$2" --arg c "${3:-}" \
      '{session_id: "s", transcript_path: $t, cwd: "/tmp", hook_event_name: "PreToolUse",
        tool_name: "Bash", tool_input: {command: $c, description: "d"}}'
  else
    jq -cn --arg t "$2" \
      '{session_id: "s", transcript_path: $t, cwd: "/tmp",
        hook_event_name: "UserPromptSubmit", prompt: "next"}'
  fi
}

# run <stdin json> [NAME=value ...] -> OUT, RC
#
# The handler runs inside a herdr pane (HERDR_PANE_ID=w1:p1) with the ceiling
# option unset. A case names what it varies as NAME=value assignments, of which
# three are this suite's fixtures: PATH=<dir> — the missing-binary cases run the
# handler against a stripped PATH; HERDR_PANE_ID= (empty), the case outside a
# herdr pane; and ORCA_TERMINAL_HANDLE=<handle>, the case inside an Orca
# terminal. Both identity variables are resolved here rather than left to the
# default, so a caller's empty value is the one the handler sees whether or not
# env(1) keeps the last of a repeated name (POSIX leaves that unspecified); the
# caller's own assignment still travels in "$@", so the two cannot disagree.
run() {
  stdin="$1"; shift
  pane=w1:p1
  orca=
  for arg in "$@"; do
    case "$arg" in
      HERDR_PANE_ID=*) pane="${arg#HERDR_PANE_ID=}" ;;
      ORCA_TERMINAL_HANDLE=*) orca="${arg#ORCA_TERMINAL_HANDLE=}" ;;
    esac
  done
  OUT="$(printf '%s' "$stdin" | env -u CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING \
    HERDR_PANE_ID="$pane" ORCA_TERMINAL_HANDLE="$orca" "$@" "$BASH_BIN" "$HOOK" 2>"$TMP/stderr")"
  RC=$?
}

expect_silent() { # <label>
  if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then pass "$1"
  else fail "$1" "rc=$RC out=$OUT"; fi
}

expect_notice() { # <label> <event> [-i] <literal the line must contain>...
  label="$1"; want="$2"; shift 2
  if [ "$RC" -ne 0 ]; then fail "$label" "rc=$RC — the handler must always exit 0"; return 0; fi
  if [ "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" -ne 1 ]; then
    fail "$label" "expected exactly one output line: $OUT"; return 0; fi
  if ! printf '%s' "$OUT" | jq -e --arg e "$want" \
      '.hookSpecificOutput.hookEventName == $e
       and (.hookSpecificOutput | has("permissionDecision") | not)
       and (.hookSpecificOutput.additionalContext | type == "string")' >/dev/null 2>&1; then
    fail "$label" "not a $want additionalContext object without a decision: $OUT"; return 0; fi
  line="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext')"
  ignore_case=0
  if [ "${1:-}" = -i ]; then
    ignore_case=1; shift
    line="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"
  fi
  for lit in "$@"; do
    if [ "$ignore_case" -eq 1 ]; then lit="$(printf '%s' "$lit" | tr '[:upper:]' '[:lower:]')"; fi
    case "$line" in *"$lit"*) ;; *) fail "$label" "line lacks '$lit': $line"; return 0 ;; esac
  done
  pass "$label"
}

printf '%screw — context-ceiling hook%s\n' "$DIM" "$RST"

section "the ceiling"
T_BELOW="$(transcript below 499999)"
T_AT="$(transcript at 500000)"
T_PAST="$(transcript past 523114)"
run "$(input UserPromptSubmit "$T_BELOW")"
expect_silent "one token below the ceiling: silent"
run "$(input UserPromptSubmit "$T_AT")"
expect_notice "at the ceiling: notice on a prompt" UserPromptSubmit \
  "crew:" "context 500000" "ceiling 500000" "crew lifecycle.md" "Rotation past the context ceiling"
run "$(input PreToolUse "$T_PAST" 'herdr agent prompt w7:p2 "implement item 3"')"
expect_notice "past the ceiling: notice before 'agent prompt'" PreToolUse "context 523114" "ceiling 500000"

section "only commands carrying a new-work verb, only behind a layer's gate"
# <verb>|<command>: the verb is the substring the matcher keys on, and it is
# also the case's label, so deleting that substring from the handler names the
# case it turns RED. The last two carry the Orca layer's verbs (0.4.0, plan
# Task 12) in their probed forms.
for entry in 'tab create|herdr tab create --workspace ws1 --cwd /tmp --label seat' \
             'workspace create|herdr workspace create --cwd /tmp' \
             'worktree create|herdr worktree create' \
             'pane run|herdr pane run w7:p2 "claude"' \
             'agent prompt|herdr agent prompt w7:p2 "implement item 3"' \
             'terminal create|orca terminal create --worktree id:root --title "seat: implementer (claude)" --command "bash"' \
             'terminal send|orca terminal send --terminal term_de0cb52b --enter --text "go"'; do
  run "$(input PreToolUse "$T_PAST" "${entry#*|}")"
  expect_notice "past the ceiling: notice before '${entry%%|*}'" PreToolUse "context 523114"
done
# A tool_input.command that is not a string is not a shape Claude Code writes,
# but the one-pass read of the three fields must not give it a different verdict
# either: the per-field spawn printed the container and the verb's substring
# match continued. @tsv alone refuses a container — "object (...) is not valid in
# a csv row" — and one such field would take the whole pass, event included,
# down the raw path; the expression stringifies each field to prevent that.
run "$(jq -cn --arg t "$T_PAST" '{session_id: "s", transcript_path: $t, cwd: "/tmp",
  hook_event_name: "PreToolUse", tool_name: "Bash",
  tool_input: {command: {note: "herdr tab create"}, description: "d"}}')"
expect_notice "a non-string tool_input.command carrying a verb still reads a figure" \
  PreToolUse "context 523114"
# Everything else a coordinator runs is not new work and stays silent.
for entry in 'agent wait|herdr agent wait w7:p2 --until idle --timeout 60000' \
             'pane read|herdr pane read w7:p2' \
             'pane list|herdr pane list' \
             'agent list|herdr agent list'; do
  run "$(input PreToolUse "$T_PAST" "${entry#*|}")"
  expect_silent "past the ceiling: silent before '${entry%%|*}'"
done
run "$(input PreToolUse "$T_PAST" 'git status --short')"
expect_silent "past the ceiling: silent before a non-herdr command"
# The gate case's adjacent control: the same fixture and event, armed, fires —
# so the silence below belongs to the gate and not to a handler that is mute anyway.
run "$(input UserPromptSubmit "$T_PAST")"
expect_notice "control: the same prompt inside a herdr pane fires" UserPromptSubmit "context 523114"
# 0.4.0 (plan Task 12): the gate reads the Orca layer's own identity variable
# too — an Orca seat is told exactly as a herdr one.
run "$(input UserPromptSubmit "$T_PAST")" HERDR_PANE_ID= ORCA_TERMINAL_HANDLE=term_de0cb52b
expect_notice "past the ceiling with only the Orca variable set: fires" UserPromptSubmit "context 523114"
run "$(input PreToolUse "$T_PAST" 'orca terminal send --terminal term_de0cb52b --enter --text "go"')" \
  HERDR_PANE_ID= ORCA_TERMINAL_HANDLE=term_de0cb52b
expect_notice "the Orca gate before 'terminal send': fires" PreToolUse "context 523114"
# The adjacent control the widening needs (CLAUDE.md's testing discipline): the
# same fixture with neither identity variable stays silent. Both are empty
# values through the helper: the gate reads `${VAR:-}`, which cannot tell an
# empty value from an unset one, and the invocation shape now lives in one place.
run "$(input UserPromptSubmit "$T_PAST")" HERDR_PANE_ID= ORCA_TERMINAL_HANDLE=
expect_silent "past the ceiling with neither identity variable: silent"

section "the figure is the latest record, never a sum"
f="$TMP/dup.jsonl"
{ user_line; for n in 1 2 3; do assistant_line msg_same 10 90 299900; done; } > "$f"
run "$(input UserPromptSubmit "$f")"
expect_silent "one message's usage repeated on three lines is not summed"
f="$TMP/dup-past.jsonl"
{ user_line; for n in 1 2 3; do assistant_line msg_same 10 90 599900; done; } > "$f"
run "$(input UserPromptSubmit "$f")"
expect_notice "control: the repeated-record writer past the ceiling fires" UserPromptSubmit "context 600000"
f="$TMP/compacted.jsonl"
{ user_line; assistant_line msg_old 10 90 699900; user_line; assistant_line msg_new 10 90 99900; } > "$f"
run "$(input UserPromptSubmit "$f")"
expect_silent "after compaction the latest record wins"
f="$TMP/sidechain.jsonl"
{ user_line; assistant_line msg_main 10 90 99900; assistant_line msg_side 10 90 899900 true; } > "$f"
run "$(input UserPromptSubmit "$f")"
expect_silent "a sidechain record does not count"

section "fail-open"
run "$(jq -cn '{session_id: "s", hook_event_name: "UserPromptSubmit", prompt: "p"}')"
expect_notice "no transcript_path in the hook input: unavailable notice" UserPromptSubmit \
  "figure unavailable (hook input has no transcript_path)" "ceiling of 500000"
run "$(input UserPromptSubmit "$TMP/never-written.jsonl")"
expect_silent "transcript not written yet: silent"
# The one-pass read escapes a tab, a newline, a carriage return and a backslash
# inside a value — jq's own @tsv definition — and decodes all four before the
# fields are used. Each of these names a real transcript, so each reads its
# figure; leave any one of the four escaped and the path names nothing the
# handler can open, so it exits silently over a figure it could have read, which
# is the class it exists to remove. One case per escape, because a single case
# cannot see the other three: the backslash case was green over the whole
# tab/CR/newline class (the verifier's rows), and a decoder that replaced `\\`
# and then `\t` in sequence passes it while failing the tab case's neighbour.
escape_case() { # <name> <the escape's name for the label> <the character itself>
  f="$TMP/escape-$1-$3.jsonl"
  { user_line; assistant_line "msg_esc_$1" 10 90 523014; } > "$f"
  run "$(input UserPromptSubmit "$f")"
  expect_notice "a transcript path containing a $2 still reads its figure" \
    UserPromptSubmit "context 523114"
}
escape_case backslash backslash '\'
escape_case tab tab "$(printf '\t')"
# $'\n', not $(printf '\n'): a command substitution strips the trailing newline,
# so the fixture would have carried no newline and the case would have passed
# against a decoder that never decoded one — measured, it did exactly that
# before this line was fixed.
escape_case newline newline $'\n'
escape_case cr "carriage return" "$(printf '\r')"
# And the second spelling this decode must not be: replacing `\\` first and then
# `\t` in sequence. A path whose own name carries a backslash followed by a `t`
# arrives escaped as `\\t`, and a chained decode turns that into a tab — a name
# that exists nowhere, so the hook goes silent. The tab case above cannot see
# this one: there the tab's own `\t` was never preceded by an escaped backslash.
f="$TMP/win\\temp.jsonl"
{ user_line; assistant_line msg_win 10 90 523014; } > "$f"
run "$(input UserPromptSubmit "$f")"
expect_notice "a transcript path whose name carries a backslash-t still reads its figure" \
  UserPromptSubmit "context 523114"
# Fix round 2, findings 1 and 2: the two rows where the round trip itself, rather
# than the escape set, moved the verdict against the base hook (`5973a7b`). Both
# are measured on both hooks in that round's report; each was RED on the head the
# finding was raised against (`db09360`) and is green here.
#
# A value whose JSON string ends in a newline. The spawns' `$( )` stripped it, so
# the name the base hook opened — and read this figure from — is the fixture's
# own path, and the decode strips it too. Keep the newline in the decoded name
# and `[ -e ]` tests a path that exists only without it: silent, over a file the
# base hook read.
f="$TMP/escape-trailing-newline.jsonl"
{ user_line; assistant_line msg_tnl 10 90 523014; } > "$f"
run "$(input UserPromptSubmit "$f"$'\n')"
expect_notice "a transcript path whose JSON string ends in a newline still reads its figure" \
  UserPromptSubmit "context 523114"
# A `\u0000` escape in the payload: the file sits at the name with the byte
# dropped, which is what `$( )` captured — a shell variable cannot hold a NUL —
# and where the base hook read this figure. `%b` read `\0` as the head of a C
# octal escape and cut the field off there (`printf -v x '%b' 'a\0b'` leaves
# `a`), so the decoded name was a prefix that names nothing: silent.
f="$TMP/escape-nul.jsonl"
{ user_line; assistant_line msg_nul 10 90 523014; } > "$f"
run "$(jq -cn --arg t "$f" '{session_id: "s",
  transcript_path: ($t | sub("\\.jsonl$"; "\u0000.jsonl")), cwd: "/tmp",
  hook_event_name: "UserPromptSubmit", prompt: "next"}')"
expect_notice "a transcript path carrying a \u0000 escape still reads its figure" \
  UserPromptSubmit "context 523114"
# The one-pass read reads .tool_input on BOTH events, where the per-field spawns
# read it only on the wake path — so a shape problem in that one field must not
# invalidate the event and the transcript beside it. `.tool_input.command` raises
# on a scalar or an array and `// ""` cannot catch a raised error, which failed
# the whole pass: on a prompt that lost the figure's own notice, and on a wake
# path that invented a "could not read" one where the old handler, whose command
# spawn failed the same way, stayed silent. Optional indexing keeps both.
run "$(jq -cn --arg t "$T_PAST" '{session_id: "s", transcript_path: $t, cwd: "/tmp",
  hook_event_name: "UserPromptSubmit", prompt: "next", tool_input: "scalar"}')"
expect_notice "a scalar tool_input on a prompt does not lose the notice" \
  UserPromptSubmit "context 523114"
run "$(jq -cn --arg t "$T_PAST" '{session_id: "s", transcript_path: $t, cwd: "/tmp",
  hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: ["herdr tab create"]}')"
expect_silent "an array tool_input on a wake does not invent a notice"
# #527 — the adjacent case: a transcript path that names something the handler
# cannot read. Before the fix the tail reads nothing, its empty output
# classifies as "none", the wc redirection fails and the integer test raises
# before the handler exits 0 having said nothing at all — a silent pass over a
# figure it could not read, which the handler's header forbids.
T_UNREADABLE="$TMP/unreadable.jsonl"
{ user_line; assistant_line msg_unreadable 10 90 523014; } > "$T_UNREADABLE"
chmod 000 "$T_UNREADABLE"
if [ -r "$T_UNREADABLE" ]; then
  # Running as root, or a filesystem that ignores 0000: no mode makes a file
  # unreadable for this uid, so swap in a broken link — the one entry no uid can
  # read. test-config-contract.sh's unreadable-file control uses the same
  # convention; the guard asserted below is the handler's readable-file guard
  # either way.
  rm -f "$T_UNREADABLE"
  ln -s "$T_UNREADABLE.absent" "$T_UNREADABLE"
fi
run "$(input UserPromptSubmit "$T_UNREADABLE")"
expect_notice "an existing transcript the handler cannot read: unavailable notice" \
  UserPromptSubmit "figure unavailable (transcript is not a readable file)"
chmod 644 "$T_UNREADABLE" 2>/dev/null
rm -f "$T_UNREADABLE"
# The other half of the same guard, and the one a non-root run would otherwise
# leave untested: an entry that is readable but not a regular file. `tail` on a
# directory fails; on a fifo it would block, which is why `-f` is part of the
# guard and not only `-r`.
mkdir "$TMP/dir-transcript.jsonl"
run "$(input UserPromptSubmit "$TMP/dir-transcript.jsonl")"
expect_notice "a transcript path that is not a regular file: unavailable notice" \
  UserPromptSubmit "figure unavailable (transcript is not a readable file)"
rmdir "$TMP/dir-transcript.jsonl"
user_line > "$TMP/fresh.jsonl"
run "$(input UserPromptSubmit "$TMP/fresh.jsonl")"
expect_silent "no assistant turn yet: silent"
{ user_line; jq -cn '{type: "assistant", isSidechain: false,
    message: {id: "m", role: "assistant", content: []}}'; } > "$TMP/drift.jsonl"
run "$(input UserPromptSubmit "$TMP/drift.jsonl")"
expect_notice "assistant records without usage (format drift): unavailable notice" UserPromptSubmit \
  "figure unavailable (no readable usage"
{ user_line; assistant_line msg_old 10 90 699900; user_line;
  jq -cn '{type: "assistant", isSidechain: false,
    message: {id: "m_new", role: "assistant", content: []}}'; } > "$TMP/drift-latest.jsonl"
run "$(input UserPromptSubmit "$TMP/drift-latest.jsonl")"
expect_notice "the latest record has no usage but an older one does: unavailable notice" \
  UserPromptSubmit "figure unavailable (no readable usage"
# #519b — a usage object that carries none of the three counters the handler
# reads. Summing them with `// 0` produced a figure of 0, which is a real figure
# to the check below: no notice, the ceiling passed in silence, and a
# coordinator already past it started more work.
{ user_line; jq -cn '{type: "assistant", isSidechain: false,
    message: {id: "m_nocounters", role: "assistant", content: [],
              usage: {input_tokens_total: 523114, output_tokens: 10,
                      cache_creation: {ephemeral_5m_input_tokens: 900}}}}'; } \
  > "$TMP/nocounters.jsonl"
run "$(input UserPromptSubmit "$TMP/nocounters.jsonl")"
expect_notice "a usage object with none of the three counters: unavailable notice" \
  UserPromptSubmit "figure unavailable (no readable usage"
# The adjacent control for that tightening: the three counters read beside keys
# the handler does not know must still produce a figure. Without it, a handler
# that refused every usage object carrying anything extra would pass the case
# above — and a format that adds a field would be refused as drift.
{ user_line; jq -cn '{type: "assistant", isSidechain: false,
    message: {id: "m_extras", role: "assistant", content: [],
              usage: {input_tokens: 10, cache_creation_input_tokens: 90,
                      cache_read_input_tokens: 523014, output_tokens: 10,
                      service_tier: "standard",
                      cache_creation: {ephemeral_5m_input_tokens: 90}}}}'; } \
  > "$TMP/extras.jsonl"
run "$(input UserPromptSubmit "$TMP/extras.jsonl")"
expect_notice "control: the three counters beside unrecognised keys still read a figure" \
  UserPromptSubmit "context 523114"
# One counter of the three missing is the same defect at a smaller scale, and
# the header settles it: the figure IS input + cache_creation + cache_read, so a
# usage object that cannot supply all three cannot supply the figure. One case
# per field, so each clause of the handler's check has its own failing mutation.
for missing in input_tokens cache_creation_input_tokens cache_read_input_tokens; do
  f="$TMP/missing-$missing.jsonl"
  { user_line; jq -cn --arg m "$missing" '{
      type: "assistant", isSidechain: false,
      message: {id: "m_missing", role: "assistant", content: [],
                usage: ({input_tokens: 10, cache_creation_input_tokens: 90,
                         cache_read_input_tokens: 523014} | del(.[$m]))}}'; } > "$f"
  run "$(input UserPromptSubmit "$f")"
  expect_notice "a usage object missing $missing: unavailable notice" \
    UserPromptSubmit "figure unavailable (no readable usage"
done
printf '%s\n' '{not json' '}}}' 'still not json' > "$TMP/malformed.jsonl"
run "$(input UserPromptSubmit "$TMP/malformed.jsonl")"
expect_notice "every tail line malformed: unavailable notice" UserPromptSubmit \
  "figure unavailable (no readable assistant record"
# A >4 MB transcript whose tail opens inside the latest assistant record: the
# one record that matters is the one the tail cannot read.
{ user_line; assistant_line m_ok 10 90 523014
  printf '%s' '{"type":"assistant","isSidechain":false,"message":{"id":"m_big","role":"assistant","usage":{"input_tokens":10,"cache_creation_input_tokens":90,"cache_read_input_tokens":523014},"content":[{"type":"text","text":"'
  head -c 4100000 /dev/zero | tr '\0' 'x'
  printf '%s\n' '"}]}}'; } > "$TMP/huge.jsonl"
run "$(input UserPromptSubmit "$TMP/huge.jsonl")"
expect_notice "the tail opens inside the latest assistant record: unavailable notice" \
  UserPromptSubmit "figure unavailable (no readable assistant record"
# A >4 MB transcript whose latest assistant record predates the whole tail:
# 4100 complete 1000-byte user lines follow it, so the tail opens exactly on a
# line boundary and still holds no assistant record.
tail_line='{"type":"user","pad":""}'
tail_pad="$(head -c $(( 999 - ${#tail_line} )) /dev/zero | tr '\0' 'p')"
tail_line="{\"type\":\"user\",\"pad\":\"$tail_pad\"}"
{ assistant_line m_old 10 90 699900; yes "$tail_line" | head -n 4100; } > "$TMP/deep-tail.jsonl"
run "$(input UserPromptSubmit "$TMP/deep-tail.jsonl")"
expect_notice "the latest assistant record predates the whole tail: unavailable notice" \
  UserPromptSubmit "figure unavailable (no assistant record in the last"
{ printf '%s\n' 'e_tokens":1}}}'; user_line; assistant_line m_ok 10 90 523014; printf '%s\n' '{not json'; } \
  > "$TMP/garbled.jsonl"
run "$(input UserPromptSubmit "$TMP/garbled.jsonl")"
expect_notice "unparseable lines around a valid record: the figure is still read" UserPromptSubmit "context 523114"
# The PATH-stripped fixtures: each removes exactly the binary its case is about,
# and nothing else. NOJQ keeps cat and tail (#516b's path — with jq absent the
# input is read as text); NOTAIL keeps jq, wc and tr (fix round 1: the tail
# cannot be run at all); NOWC keeps jq, tail and tr (fix round 1: the size read
# cannot be run).
NOJQ="$TMP/nojq-bin"; mkdir -p "$NOJQ"
for b in cat tail; do ln -s "$(command -v "$b")" "$NOJQ/$b"; done
NOTAIL="$TMP/notail-bin"; mkdir -p "$NOTAIL"
for b in cat jq wc tr; do ln -s "$(command -v "$b")" "$NOTAIL/$b"; done
NOWC="$TMP/nowc-bin"; mkdir -p "$NOWC"
for b in cat jq tail tr; do ln -s "$(command -v "$b")" "$NOWC/$b"; done

# raw_input <shape> <event> <separator> <complete|truncated>
# The raw path reads the hook input as text, so its reach is a spelling list, and
# the separator is the whitespace a writer put between the event key and its
# colon. `truncated` cuts the JSON off inside a value, which is the branch where
# the jq-present path reads text too (the fourth path). For the compact
# separator these fixtures are byte-equal to `input()`'s, plus the cut.
raw_input() {
  case "$1:$4" in
    prompt:complete)  end='"prompt":"next"}' ;;
    prompt:truncated) end='"prompt":"unterminated' ;;
    wake:complete)    end='"tool_name":"Bash","tool_input":{"command":"herdr agent prompt w7:p2 \"implement item 3\"","description":"d"}}' ;;
    wake:truncated)   end='"tool_name":"Bash","tool_input":{"command":"herdr agent prompt w7:p2 \"implement item 3\""' ;;
  esac
  printf '{"session_id":"s","transcript_path":"%s","cwd":"/tmp","hook_event_name"%s"%s",%s' \
    "$T_PAST" "$3" "$2" "$end"
}

# #516b's path, its fourth-path sibling, and fix round 1's Finding 2: the raw
# path's spelling list, pinned on BOTH raw branches (jq absent, and jq present
# with an input it cannot parse) and on BOTH events — the boundary was silent on
# all four until the enumeration was widened to the separators a writer emits.
# branch|shape|separator; the separator is in the label, so dropping that
# alternative from the handler names the two cases it turns RED.
for entry in 'nojq|prompt|:' 'nojq|prompt|: ' 'nojq|prompt| : ' \
             'nojq|wake|:' 'nojq|wake|: ' 'nojq|wake| : ' \
             'unparsed|prompt|:' 'unparsed|prompt|: ' 'unparsed|prompt| : ' \
             'unparsed|wake|:' 'unparsed|wake|: ' 'unparsed|wake| : '; do
  branch="${entry%%|*}"; rest="${entry#*|}"
  shape="${rest%%|*}"; sep="${rest#*|}"
  case "$shape" in
    prompt) event=UserPromptSubmit; shape_label=prompt ;;
    wake)   event=PreToolUse; shape_label=wake ;;
  esac
  if [ "$branch" = nojq ]; then
    branch_label='no jq'; reason='jq not found'; cut=complete
    input_text="$(raw_input "$shape" "$event" "$sep" "$cut")"
    run "$input_text" PATH="$NOJQ"
  else
    branch_label='unparseable input'; reason='jq could not read the hook input'; cut=truncated
    input_text="$(raw_input "$shape" "$event" "$sep" "$cut")"
    run "$input_text"
  fi
  expect_notice "raw path, $branch_label, $shape_label, separator '$sep': unavailable notice" \
    "$event" "figure unavailable ($reason)"
done
# The adjacent control the widening needs (CLAUDE.md's testing discipline): the
# spacing outside the three a writer emits stays silent — two spaces before the
# colon, and a tab there, which is the boundary the handler's own comment names
# and the closest neighbour of the accepted ` : `. Same machinery, same branches
# and events, opposite expectation: a widening to any whitespace would leave
# every case above green and enforce the boundary only by a comment.
TAB_SEP="$(printf '\t')"
for entry in "nojq|two spaces before the colon|  : " "unparsed|two spaces before the colon|  : " \
             "nojq|a tab before the colon|${TAB_SEP}: " "unparsed|a tab before the colon|${TAB_SEP}: "; do
  branch="${entry%%|*}"; rest="${entry#*|}"
  sep_label="${rest%%|*}"; sep="${rest#*|}"
  for shape in prompt wake; do
    case "$shape" in
      prompt) event=UserPromptSubmit ;;
      wake)   event=PreToolUse ;;
    esac
    if [ "$branch" = nojq ]; then
      branch_label='no jq'; cut=complete
      input_text="$(raw_input "$shape" "$event" "$sep" "$cut")"
      run "$input_text" PATH="$NOJQ"
    else
      branch_label='unparseable input'; cut=truncated
      input_text="$(raw_input "$shape" "$event" "$sep" "$cut")"
      run "$input_text"
    fi
    expect_silent "control: raw path, $branch_label, $shape, $sep_label stays silent"
  done
done
# The adjacent control: with jq absent the notice must still belong to the
# new-work matcher, not to every Bash call — the coordinator's ordinary commands
# learn nothing under no jq any more than they do with jq present.
run "$(input PreToolUse "$T_PAST" 'git status --short')" PATH="$NOJQ"
expect_silent "no jq on PATH: silent before a non-new-work command"
# Its adjacent control: an unparseable input that carries no new-work command is
# not the handler's business, and the fast path stops it before any of this — so
# the cases above are the event's notice, not a handler that speaks on any input
# it cannot parse.
printf '%s' '{"hook_event_name":"PreToolUse","tool_input":{"command":"git status --short"' \
  > "$TMP/malformed-nonwork.json"
run "$(cat "$TMP/malformed-nonwork.json")"
expect_silent "control: an unparseable input carrying no new-work command stays silent"
# The fourth path's other named trigger, pinned rather than asserted in a
# comment: a jq that is present and fails. The input is well-formed here, so the
# raw spelling is the only thing left that can attribute the notice — the class
# the malformed-input case does not cover.
BROKENJQ="$TMP/brokenjq-bin"; mkdir -p "$BROKENJQ"
printf '#!/bin/sh\nexit 1\n' > "$BROKENJQ/jq"; chmod +x "$BROKENJQ/jq"
run "$(input UserPromptSubmit "$T_PAST")" PATH="$BROKENJQ:$PATH"
expect_notice "a jq on PATH that fails on a well-formed input: unavailable notice" \
  UserPromptSubmit "figure unavailable (jq could not read the hook input)"
for event in UserPromptSubmit PreToolUse; do
  run "$(input "$event" "$T_PAST" 'herdr agent prompt w7:p2 next')" PATH="$BROKENJQ:$PATH" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=100000
  expect_notice "B1: broken jq leaves a non-empty setting unchecked ($event)" "$event" "setting was not checked"
  case "$OUT" in
    *500000*) fail "B1: broken jq never claims the default ($event)" "$OUT" ;;
    *) pass "B1: broken jq never claims the default ($event)" ;;
  esac
done
# Adjacent control: no setting makes the default known even when jq is broken.
run "$(input UserPromptSubmit "$T_PAST")" PATH="$BROKENJQ:$PATH"
expect_notice "control B1: an unset setting has a known default" UserPromptSubmit "ceiling of 500000 tokens"
# Fix round 1, Finding 1: the tail could not be read at all. With `tail` off PATH
# its status was invisible (the pipeline reported jq's), the empty tail fell
# through to "none", the size check passed, and the handler exited having said
# nothing — on a past-ceiling prompt and on the wake command both. The status
# guard speaks, and the guard's file-side half (a read that fails where `-r`
# passed) has no portable fixture: this is the case that exercises the guard.
run "$(input UserPromptSubmit "$T_PAST")" PATH="$NOTAIL"
expect_notice "a PATH without tail, on a prompt: unavailable notice" UserPromptSubmit \
  "figure unavailable (the transcript's tail could not be read)"
run "$(input PreToolUse "$T_PAST" 'herdr agent prompt w7:p2 "implement item 3"')" PATH="$NOTAIL"
expect_notice "a PATH without tail, before a new-work command: unavailable notice" PreToolUse \
  "figure unavailable (the transcript's tail could not be read)"
# The adjacent control: the same transcript and the same command with `tail`
# present reaches its figure — so the notice above is the missing read, not a
# handler that cannot see the ceiling.
run "$(input UserPromptSubmit "$T_PAST")"
expect_notice "control: the same fixture with tail present reaches its figure" \
  UserPromptSubmit "context 523114"
# Fix round 1, Finding 3: the size read's own failure. With `wc` off PATH the
# guard speaks; this is the fixture that turns the size guard's mutation RED on
# its own, which the T6 report wrongly called impossible.
run "$(input UserPromptSubmit "$TMP/fresh.jsonl")" PATH="$NOWC"
expect_notice "a PATH without wc, on a fresh transcript: unavailable notice" UserPromptSubmit \
  "figure unavailable (the transcript's size could not be read)"
# The adjacent control: the same fixture with `wc` present is the ordinary silent
# case, so the notice above belongs to the missing read.
run "$(input UserPromptSubmit "$TMP/fresh.jsonl")"
expect_silent "control: the same fresh transcript with wc present is silent"

section "the setting"
T150="$(transcript s150 150000)"
run "$(input UserPromptSubmit "$T150")" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=100000
expect_notice "context_ceiling=100000 applies" UserPromptSubmit "context 150000" "ceiling 100000"
run "$(input UserPromptSubmit "$T150")"
expect_silent "control: the same transcript under the default is silent"
T600="$(transcript s600 600000)"
run "$(input UserPromptSubmit "$T600")" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=abc
expect_notice "a non-numeric setting falls back to 500000" UserPromptSubmit "ceiling 500000"
run "$(input UserPromptSubmit "$T_BELOW")" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=
expect_silent "an empty setting falls back to 500000"
run "$(input UserPromptSubmit "$T_BELOW")" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=0
expect_silent "a zero setting falls back to 500000"

# #616: exact fractions, String(number) spellings, and adjacent rejection controls.
T_FRACTION="$(transcript s-fraction 100001)"
T_ONE_BELOW="$(transcript s-one-below 100000)"
for event in UserPromptSubmit PreToolUse; do
  run "$(input "$event" "$T_FRACTION" 'herdr agent prompt w7:p2 next')" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=100000.5
  expect_notice "#616: fraction fires at 100001 ($event)" "$event" "context 100001" "ceiling 100000.5"
  run "$(input "$event" "$T_ONE_BELOW" 'herdr agent prompt w7:p2 next')" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=100000.5
  expect_silent "control #616: fraction is not floored ($event)"
  run "$(input "$event" "$T_ONE_BELOW" 'herdr agent prompt w7:p2 next')" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=100000
  expect_notice "control #616: whole ceiling fires at equality ($event)" "$event" "context 100000" "ceiling 100000"
done
for setting in '100000.5' '1e+21' 'Infinity'; do
  run "$(input UserPromptSubmit "$T_PAST")" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING="$setting"
  case "$setting" in
    100000.5) expect_notice "#616: String fraction is honoured" UserPromptSubmit "ceiling 100000.5" ;;
    *) expect_silent "#616: String large number stays above the figure ($setting)" ;;
  esac
  if [ ! -s "$TMP/stderr" ]; then pass "control #616: String number has empty stderr ($setting)"
  else fail "control #616: String number has empty stderr ($setting)" "$(cat "$TMP/stderr")"; fi
done
run "$(jq -cn '{hook_event_name: "UserPromptSubmit"}')" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=1e+21
expect_notice "#616: exponent is the ceiling in force" UserPromptSubmit -i "ceiling of 1e+21 tokens"
for setting in 'abc' '' '-5' '0' '0.5' '1e+' '1.2.3' 'bad"\\setting'; do
  run "$(input UserPromptSubmit "$T600")" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING="$setting"
  expect_notice "control #616: rejected setting uses default ($setting)" UserPromptSubmit "ceiling 500000"
  run "$(input UserPromptSubmit "$T_BELOW")" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING="$setting"
  expect_silent "control #616: rejected setting does not fire below default ($setting)"
done
# B4: baseline-green boundary control; rejects a min guard tightened to > 1.
run "$(input UserPromptSubmit "$T_PAST")" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=1
expect_notice "control B4: the minimum ceiling 1 is accepted" UserPromptSubmit "ceiling 1 tokens"
for event in UserPromptSubmit PreToolUse; do
  run "$(input "$event" "$T_PAST" 'herdr agent prompt w7:p2 next')" PATH="$NOJQ" CLAUDE_PLUGIN_OPTION_CONTEXT_CEILING=100000.5
  expect_notice "#616: no jq names unchecked setting ($event)" "$event" "figure unavailable (jq not found)" "setting was not checked"
done

section "registration"
HJ="$PLUGIN_ROOT/hooks/hooks.json"
if jq -e --arg h 'hooks-handlers/context-ceiling.sh' '
     ([.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]?.command
       | select(endswith($h))] | length == 1)
     and ([.hooks.UserPromptSubmit[]? | .hooks[]?.command | select(endswith($h))] | length == 1)' \
     "$HJ" >/dev/null 2>&1
then pass "hooks.json registers the handler on PreToolUse (Bash) and UserPromptSubmit"
else fail "hooks.json registers the handler on PreToolUse (Bash) and UserPromptSubmit" "$HJ"; fi
M="$PLUGIN_ROOT/.claude-plugin/plugin.json"
if jq -e '.userConfig.context_ceiling
          | .type == "number" and .default == 500000
            and (.title | length > 0) and (.description | length > 0)' "$M" >/dev/null 2>&1
then pass "the Claude manifest declares context_ceiling (number, default 500000)"
else fail "the Claude manifest declares context_ceiling (number, default 500000)" "$M"; fi
if [ -x "$PLUGIN_ROOT/hooks-handlers/context-ceiling.sh" ]; then pass "the handler is executable"
else fail "the handler is executable"; fi

# Task 6 (crew 0.3.0), Task 12 (crew 0.4.0): the notice is crew's and it points at
# the shared prose that defines a unit; the gate and the verb list now read both
# layers — the herdr pane and the Orca terminal — named as the layers' rather than
# as crew's own. The emitted text is asserted in "the ceiling" above; these guard
# the source strings that survived Task 1's rename.
section "the notice names crew, and the gate and verbs are the layers'"
pin "$HOOK" 'crew lifecycle.md' "the notice points at lifecycle.md by its crew path"
pin "$HOOK" 'HERDR_PANE_ID' "the gate names the herdr identity variable"
pin "$HOOK" 'ORCA_TERMINAL_HANDLE' "the gate names the Orca identity variable"
pin "$HOOK" "The two layers' new-work commands" "the verb list is named as the layers'"
# Adjacent control: the old plugin name, which the notice, the header and every comment
# must not carry again. A handler that spelled it would pass every case above and fail
# only here. Built in two pieces: this suite lives in the tree `tests/test-crew-rename.sh`
# sweeps, and the name it forbids must not appear in the sweeper's own subject either.
old_name="herdr-"; old_name="${old_name}crew"
if [ "$(occurrences "$HOOK" "$old_name")" -eq 0 ]; then pass "no old plugin name in the handler"
else fail "no old plugin name in the handler" "$(occurrences "$HOOK" "$old_name") occurrence(s)"; fi

# #514, L1: a counter re-copied into this suite would shadow the hoisted one and keep every
# assertion that calls it passing. Both halves assert the shape: this one is the per-suite
# half, and the directory-wide half runs once, from test-config-contract.sh.
section "molt is active in this session: the hook stands down (spec D9)"
# Every silent case has a control beside it that differs in one thing and must still
# fire, so a handler that prints nothing for every input cannot pass this section.
MOLT_HOME="$TMP/molt-home"; mkdir -p "$MOLT_HOME/.claude/state/molt/active"
MARK="$MOLT_HOME/.claude/state/molt/active/s"
NO_MOLT_HOME="$TMP/no-molt-home"; mkdir -p "$NO_MOLT_HOME"
touch "$MARK"
run "$(input UserPromptSubmit "$T_PAST")" HOME="$MOLT_HOME"
expect_silent "fresh molt marker for this session: silent on a prompt"
run "$(input PreToolUse "$T_PAST" 'herdr agent prompt w7:p2 "implement item 3"')" HOME="$MOLT_HOME"
expect_silent "fresh molt marker for this session: silent before 'agent prompt'"
run "$(input UserPromptSubmit "$T_PAST")" HOME="$NO_MOLT_HOME"
expect_notice "no marker: the notice still fires" UserPromptSubmit "context 523114"
run "$(input UserPromptSubmit "$T_PAST")" HOME=
expect_notice "HOME empty: no marker is read, the notice fires" UserPromptSubmit "context 523114"
touch -t 202001010000 "$MARK"
run "$(input UserPromptSubmit "$T_PAST")" HOME="$MOLT_HOME"
expect_notice "a marker older than a day is stale: the notice fires" UserPromptSubmit "context 523114"
touch "$MARK"
run "$(jq -cn --arg t "$T_PAST" '{session_id: "other", transcript_path: $t, cwd: "/tmp",
  hook_event_name: "UserPromptSubmit", prompt: "next"}')" HOME="$MOLT_HOME"
expect_notice "a marker for another session: the notice fires" UserPromptSubmit "context 523114"
run "$(jq -cn --arg t "$T_PAST" '{session_id: "../active/s", transcript_path: $t, cwd: "/tmp",
  hook_event_name: "UserPromptSubmit", prompt: "next"}')" HOME="$MOLT_HOME"
expect_notice "a session id that is a path is not a marker name: the notice fires" \
  UserPromptSubmit "context 523114"
NOJQ_FIND="$TMP/nojq-find-bin"; mkdir -p "$NOJQ_FIND"
for b in cat tail find; do ln -s "$(command -v "$b")" "$NOJQ_FIND/$b"; done
run "$(input UserPromptSubmit "$T_PAST")" HOME="$MOLT_HOME" PATH="$NOJQ_FIND"
expect_silent "no jq on PATH, fresh marker: silent (the session id is read as text)"
run "$(input UserPromptSubmit "$T_PAST")" HOME="$NO_MOLT_HOME" PATH="$NOJQ_FIND"
expect_notice "no jq on PATH, no marker: the unavailable notice still fires" \
  UserPromptSubmit "figure unavailable (jq not found)"

section "the hoisted counters are not re-copied"
assert_hoisted_counters

report
