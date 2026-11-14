#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
OSS="$HERE/../bin/oss"

t_capture "$OSS" help
t_assert_rc 0 "oss help exits 0"
t_assert_contains "$T_OUT" "ossify" "help names the plugin"

t_capture "$OSS" definitely-not-a-command
t_assert_rc 2 "unknown subcommand exits 2"

# #495: help is complete and uses the usage error's own signature.
for row in \
  'zero_tests_guard|<runner-command>  # runner output on stdin' \
  'bone_add|<adr> <title> <touch-csv> [revisit]' \
  'state_path|' ; do
  verb="${row%%|*}"; args="${row#*|}"
  want="oss $verb${args:+ $args}"
  t_capture "$OSS" help "$verb"
  t_assert_rc 0 "help $verb succeeds without a manifest"
  t_assert_eq "$want" "$T_OUT" "help $verb prints its signature only"
  help_signature="$T_OUT"
  if [ "$verb" != state_path ]; then
    t_capture "$OSS" "$verb"
    t_assert_rc 2 "$verb with missing arguments is a usage error"
    t_assert_eq "$help_signature" "${T_OUT##*usage: }" "$verb help and usage print the same signature"
  fi
done

# Both hand-written upper-bound errors must read that same source too.
for verb in feature_add work_item_exec; do
  help_signature="$("$OSS" help "$verb")"
  t_capture "$OSS" "$verb" a b c d e extra
  t_assert_rc 2 "$verb rejects a sixth argument"
  usage="${T_OUT##*usage: }"; usage="${usage%%;*}"
  t_assert_eq "$help_signature" "$usage" "$verb upper-bound usage matches help"
done

# No-arg verbs accept extras today. Exercise their shared usage formatter without
# adding a new dispatcher rejection merely to obtain an error for this test.
t_capture bash -c 'for f in "$1"/lib/*.sh; do . "$f"; done; _oss_need_exact 0 state_path "" extra' _ "$HERE/.."
t_assert_rc 2 'zero-arg usage guard returns 2'
usage="${T_OUT##*usage: }"; usage="${usage%%;*}"
t_assert_eq "$("$OSS" help state_path)" "$usage" 'zero-arg help and usage print the same signature'

signatures="$("$OSS" help)"
verbs="$(awk '/^oss_cmd_[a-z_]+\(\)/ {s=$0; sub(/^oss_cmd_/, "", s); sub(/\(.*/, "", s); print s}' "$OSS" "$HERE"/../lib/*.sh | sort)"
for verb in $verbs; do
  t_capture "$OSS" help "$verb"
  t_assert_rc 0 "help covers $verb"
  t_assert_eq 1 "$(printf '%s\n' "$T_OUT" | awk -v v="$verb" '$1=="oss" && $2==v {n++} END {print n+0}')" "$verb has exactly one signature"
  t_assert_eq 1 "$(printf '%s\n' "$signatures" | awk -v s="  $T_OUT" '$0==s {n++} END {print n+0}')" "full help includes $verb's signature exactly once"
done
t_capture "$OSS" help definitely-not-a-command
t_assert_rc 2 'unknown help target is a usage error'
t_assert_contains "$T_OUT" 'unknown subcommand' 'unknown help target names the dispatch error'

# The reader must reject both missing and duplicate source signatures.
for fixture in duplicate_fixture missing_fixture; do
  t_capture bash -c '
    . "$1/lib/commands.sh"
    oss_cmd_duplicate_fixture() {
      _oss_need 0 duplicate_fixture "" "$@"
      _oss_need_exact 0 duplicate_fixture "[stale]" "$@"
    }
    oss_cmd_missing_fixture() { :; }
    _oss_signature "$2"
  ' _ "$HERE/.." "$fixture"
  t_assert_rc 2 "$fixture rejects an invalid signature count"
  t_assert_contains "$T_OUT" 'expected one signature' "$fixture names the signature-count error"
done

# #406: every bash argument bridge stays inside its Bash(bash:*) grant and
# avoids Claude's positional rendering. Execute empty and multiword controls.
bridges=0
for f in "$HERE"/../commands/*.md "$HERE/../../crew/commands/orchestrate.md"; do
  bridge="$(awk '/^```bash$/ {b=1; s=""; next} b && /^```$/ {if (s ~ /bash -c/) printf "%s", s; b=0; next} b {s=s $0 "\n"}' "$f")"
  [ -n "$bridge" ] || continue
  bridges=$((bridges+1)); name="$(basename "$f" .md)"
  t_assert_contains "$(cat "$f")" 'Bash(bash:*)' "$name grants its bridge"
  t_assert_eq 'bash -c ' "${bridge:0:8}" "$name bridge starts with the granted executable"
  t_assert_contains "$bridge" "' _ \"\$ARGUMENTS\"" "$name keeps the trailing argument and placeholder"
  t_assert_contains "$bridge" 'ARGS="${*:-}"' "$name reads the unnumbered arguments"
  for arg in '' 'hello world'; do
    t_capture env ARGUMENTS="$arg" bash -c "$bridge"
    t_assert_rc 0 "$name bridge executes"
    field=ARGS; [ "$name" != orchestrate ] || field=OBJECTIVE
    t_assert_eq "$name: $field=${arg:-<none>}" "$T_OUT" "$name preserves the argument payload"
  done
done
t_assert_eq 10 "$bridges" 'all ten bash bridges were checked'

t_summary
