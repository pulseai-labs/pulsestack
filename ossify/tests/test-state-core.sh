#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/state.sh"
TMP="$(mktemp -d)"; S="$TMP/.ossify/project-state.json"

t_capture oss_state_init "$S" demo-project
t_assert_rc 0 "init succeeds"
t_capture oss_state_read "$S" '.schema_version';       t_assert_eq "4" "$T_OUT" "schema v4"
t_capture oss_state_read "$S" '.project.name';         t_assert_eq "demo-project" "$T_OUT" "project name"
[ -f "$S.base.json" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: base snapshot missing"; }

t_capture oss_state_init "$S" again
t_assert_rc 1 "re-init refused"

t_capture oss_state_mutate "$S" set_posture '{"posture":"fully-private"}'
t_assert_rc 0 "mutate ok"
t_capture oss_state_read "$S" '.project.posture';      t_assert_eq "fully-private" "$T_OUT" "posture applied"
t_capture oss_state_read "$S" '.mutations | length';   t_assert_eq "1" "$T_OUT" "mutation journaled"
t_capture oss_state_read "$S" '.mutations[0].op';      t_assert_eq "set_posture" "$T_OUT" "op recorded"

mkdir "$S.lock"   # simulate a concurrent holder
t_capture oss_state_mutate "$S" set_posture '{"posture":"fully-open"}'
t_assert_rc 3 "lock contention rc=3"
rmdir "$S.lock"
t_capture oss_state_read "$S" '.project.posture';      t_assert_eq "fully-private" "$T_OUT" "state untouched under contention"

# --- Regression: the lock-leak bug CLASS (bare command-sub hard-exit under
# --- `set -e` skips cleanup, leaking the lock dir -> permanent DoS). These make
# --- the throwaway probes permanent so Task 4+ cannot silently reintroduce it.

# R1: a forced-failing internal command in the critical section, run under a
# real `set -euo pipefail` (how bin/oss sources+calls this). Shadow _oss_now to
# fail; a hard-exit here would leak the lock. Subshell isolates any hard-exit to
# this check and auto-restores the _oss_now shadow.
(
  set -euo pipefail
  _oss_now() { return 1; }
  oss_state_mutate "$S" set_posture '{"posture":"should-not-apply"}'
)
r1=$?
if [ "$r1" -ne 0 ]; then T_PASS=$((T_PASS+1)); else T_FAIL=$((T_FAIL+1)); echo "FAIL: forced-fail mutate should rc!=0 (got $r1)"; fi
[ ! -d "$S.lock" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: lock leaked after forced-fail mutate"; }
if ls "$S".tmp.* >/dev/null 2>&1; then T_FAIL=$((T_FAIL+1)); echo "FAIL: temp orphan after forced-fail mutate"; else T_PASS=$((T_PASS+1)); fi
t_capture oss_state_read "$S" '.project.posture';      t_assert_eq "fully-private" "$T_OUT" "state untouched after forced-fail mutate"

# R2: corrupt (non-JSON) source file -> mutate must abort rc 4, leave the
# original byte-unchanged, release the lock, orphan no temp.
C="$TMP/.ossify/corrupt-state.json"
printf 'THIS IS NOT VALID JSON\n' > "$C"
c_before="$(cksum < "$C")"
( set -euo pipefail; oss_state_mutate "$C" set_posture '{"posture":"x"}' )
r2=$?
t_assert_eq "4" "$r2" "corrupt-source mutate aborts rc 4"
c_after="$(cksum < "$C")"
t_assert_eq "$c_before" "$c_after" "corrupt source byte-unchanged"
[ ! -d "$C.lock" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: lock leaked after corrupt-source mutate"; }
if ls "$C".tmp.* >/dev/null 2>&1; then T_FAIL=$((T_FAIL+1)); echo "FAIL: temp orphan after corrupt-source mutate"; else T_PASS=$((T_PASS+1)); fi

# --- Final review finding 4: the §9.2 schema guard sat on NO write path. Its
# only caller was doctor — advisory and read-only — so this v1 build happily
# journaled v1-semantics ops into a state file claiming a future schema, while
# the guard's own header promised it would "refuse to operate". A version guard
# only protects the v1->v2 transition if it ships IN v1; an already-installed
# build can never be retrofitted. Run under a real `set -euo pipefail`, the way
# bin/oss does.
#
# The guard is placed BEFORE `mkdir "$lock"` deliberately: a `return 6` after
# the lock is taken would jump past the wrapper's unconditional `rmdir` and
# wedge the state file permanently — so the no-lock-left-behind assertion below
# is guarding the fix's fix, not a nicety.
V="$TMP/.ossify/future-state.json"
oss_state_init "$V" future-project >/dev/null
jq '.schema_version = 99' "$V" > "$V.x" && mv "$V.x" "$V"
v_before="$(cksum < "$V")"
( set -euo pipefail; oss_state_mutate "$V" set_posture '{"posture":"fully-private"}' ) 2>/dev/null
r3=$?
t_assert_eq "6" "$r3" "mutate against a FUTURE schema_version is refused rc 6"
t_assert_eq "$v_before" "$(cksum < "$V")" "future-schema state byte-unchanged by the refusal"
[ ! -d "$V.lock" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: lock left behind by the schema-guard refusal (state is now wedged)"; }
if ls "$V".tmp.* >/dev/null 2>&1; then T_FAIL=$((T_FAIL+1)); echo "FAIL: temp orphan after schema-guard refusal"; else T_PASS=$((T_PASS+1)); fi

# A valid-JSON but non-integer schema_version is refused the same way...
jq '.schema_version = "abc"' "$V" > "$V.x" && mv "$V.x" "$V"
( set -euo pipefail; oss_state_mutate "$V" set_posture '{"posture":"fully-private"}' ) 2>/dev/null
t_assert_eq "6" "$?" "mutate against a non-integer schema_version is refused rc 6"

# N2: digits past the integer range make the check's numeric tests ERROR; it must refuse, not pass.
jq '.schema_version = "99999999999999999999"' "$V" > "$V.x" && mv "$V.x" "$V"
t_capture oss_state_check_version "$V"
t_assert_rc 6 "check_version on a schema_version past the integer range refuses rc 6"
t_assert_contains "$T_OUT" "missing/invalid" "...with the missing/invalid message"
# Adjacent control: the current version still passes the same check.
jq --argjson v "$OSS_STATE_SCHEMA_VERSION" '.schema_version = $v' "$V" > "$V.x" && mv "$V.x" "$V"
t_capture oss_state_check_version "$V"
t_assert_rc 0 "control: check_version on the current schema_version passes"

# ...and the guard must NOT re-label the corrupt-source path, which R2 above
# pins at rc 4 (apply-failure, original untouched). Nothing overlaps.
( set -euo pipefail; oss_state_mutate "$C" set_posture '{"posture":"x"}' ) 2>/dev/null
t_assert_eq "4" "$?" "corrupt (unparseable) source still aborts rc 4, not rc 6"

rm -rf "$TMP"
t_summary
