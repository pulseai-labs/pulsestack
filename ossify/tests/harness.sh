#!/usr/bin/env bash
# Minimal test harness. Source from test files. Never enables -e itself:
# tests must observe failures, not die on them.
T_PASS=0; T_FAIL=0; T_OUT=""; T_RC=0
# Harness is sourced by test files that never enable `set -e`, so command
# substitution captures a non-zero rc without aborting. t_capture does NOT
# touch `set -e` (doing so would make later bare commands abort mid-test).
t_capture() { T_OUT="$("$@" 2>&1)"; T_RC=$?; }
t_assert_eq() { if [ "$1" = "$2" ]; then T_PASS=$((T_PASS+1)); else T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (expected '$1' got '$2')"; fi; }
t_assert_contains() { case "$1" in *"$2"*) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (no '$2' in output)";; esac; }
t_assert_rc() { t_assert_eq "$1" "$T_RC" "$2"; }
t_summary() { echo "pass=$T_PASS fail=$T_FAIL"; [ "$T_FAIL" -eq 0 ]; }

t_pty_available() {
  if ! command -v script >/dev/null 2>&1 || [[ $(script --version </dev/null 2>/dev/null) != *util-linux* ]]; then
    echo "  SKIP: read-only state PTY tests need util-linux script"
  elif (( EUID == 0 )); then
    echo "  SKIP: read-only state PTY tests need an unprivileged user (root can write mode 444)"
  else
    return 0
  fi
  return 1
}

# Like workspace-init's W6/L11: the child gets a terminal with EOF even when
# the suite is piped. Bound the run where timeout is available.
t_on_pty() {
  local cmd
  local -a deadline=()
  command -v timeout >/dev/null 2>&1 && deadline=(timeout 10)
  printf -v cmd '%q ' "$@"
  SHELL="$BASH" "${deadline[@]}" script -eqc "test -t 0 && exec $cmd" /dev/null </dev/null
}
