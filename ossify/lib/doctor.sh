#!/usr/bin/env bash
# oss doctor - state health checks (spec §9.2 + §9.1 doctor entry).

# Read one advisory COUNT, and treat an unreadable field as UNREADABLE rather
# than as zero. The old `jq ... || echo 0` form was survivable only while these
# advisories printed nothing on a zero count: a corrupt `.demo_ledger` produced
# "0" and therefore silence. Once the clean `ok:` arms were added (round 2), the
# identical fallback started printing "ok: ledger - no pending amendments" over
# data it had failed to read - a check ASSERTING cleanliness about a field it
# could not parse, which is worse than the silence it replaced and contradicts
# the `skip:` contract every other check here follows.
#
# A count must also LOOK like a count: `jq -r` exits 0 while echoing `null` for
# a missing field, and `[ null -gt 0 ]` is a syntax error, not a zero.
#
# Every caller's expression opens with `_arr(f)`, which ERRORS unless the field
# is an array. That is not belt-and-braces: `jq`'s `length` is defined for
# almost everything, so `.patch_records | length` on an OBJECT quietly returns
# its key count and on a NUMBER returns its absolute value. Neither is a record
# count, and neither fails - so without the type guard a structurally wrong
# field produces a confident wrong number instead of a `skip:`. (Measured, when
# a test fixture using `{"a":1}` was expected to fail and reported `warn:
# patches - 1` instead.) (Codex P2, PR #149 round 3.)
# SLIMMED TO THE GATE (PR #184). doctor used to emit eight checks; the four that
# remain are the ones `close` blocks a MUTATION on, and they are the only ones
# that are not diagnosis:
#
#   state   the file is there at all
#   schema  oss_state_check_version - version legibility
#   replay  oss_state_replay - rebuild from the base snapshot, compare
#   shape   every required top-level key is present
#
# Replay is the reason this half stays deterministic. It reconstructs state by
# applying every journaled op to a base snapshot in sequence and comparing the
# result - exact-identity work, and the deterministic column names it. Nothing
# else in the plugin exposes it, and `close/SKILL.md` §3 requires schema and
# replay green before it writes. A rail before a mutation is not a read-out,
# whatever it is spelled with (PR #178's lesson, applied deliberately here).
#
# The OTHER four checks - lock, ledger/fakes/patches counts, and the repo-vs-state
# worktree comparison - were ~210 lines that opened files and described what they
# found. They are prose now, in doctor/references/state-inspection.md. They gated
# nothing: every one emitted `warn:` or `skip:`, neither of which ever set rc.
oss_cmd_doctor() { # $1=state-file (optional; resolves via manifest/OSS_STATE_FILE when omitted)
  _oss_need 0 doctor "[state-file]" "$@" || return 2
  local sf rc=0 out; sf="$(_oss_resolve_state "${1:-}")" || return $?
  [ -f "$sf" ] || { echo "fail: state - not found at $sf"; return 1; }

  # Each check below is called inside an `if ...; then ... else ...; fi` (or
  # an equivalent tested position) so a failing check's nonzero rc is
  # captured into `rc`/an echoed line WITHOUT tripping `errexit` and aborting
  # the remaining checks - that suspension covers the whole invoked function
  # body, not just the top-level call (verified: a function called from an
  # `if` condition keeps `set -e` suspended through its own internal command
  # substitutions too). `rc` only accumulates; we never `return` early on a
  # single check's failure.
  if out="$(oss_state_check_version "$sf" 2>&1)"; then
    echo "ok: schema - v$(jq -r '.schema_version' "$sf")"
  else
    echo "fail: schema - $out"; rc=1
  fi

  # Replay depends on a valid schema, so it's gated on the schema check. But
  # "gated out" must still emit ONE line (a skip notice) rather than silently
  # dropping the check - an operator debugging a broken state file needs to
  # see that replay was intentionally not run, not a missing line. `skip:`
  # (like `warn:`) never sets rc.
  if [ "$rc" -eq 0 ]; then
    if out="$(oss_state_replay "$sf" 2>&1)"; then
      echo "ok: replay - $out"
    else
      echo "fail: replay - $out"; rc=1
    fi
  else
    echo "skip: replay - skipped (schema check failed)"
  fi

  # Shape is schema-independent (pure key presence), so it ALWAYS reports:
  # the detection loop runs unconditionally and the positive summary is
  # printed whenever no key was actually missing (tracked by a local flag,
  # NOT by the overall rc - a prior schema/replay failure must not suppress
  # a legitimately-green shape line).
  local key shape_ok=1
  for key in schema_version project counters releases spines work_items demo_ledger bones risk_gates fakes feature_map patch_records class_overrides veto_dispositions close_records mutations; do
    if ! jq -e --arg k "$key" 'has($k)' "$sf" >/dev/null 2>&1; then
      echo "fail: shape - missing key '$key'"; rc=1; shape_ok=0
    fi
  done
  [ "$shape_ok" -eq 1 ] && echo "ok: shape - all required keys present"


  return "$rc"
}