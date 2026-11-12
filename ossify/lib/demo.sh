#!/usr/bin/env bash
# Cumulative auto-demo runner (spec §6.1 core row). Halt-on-first-fail.

# §6.1 + companion §4.3: the demo runs against the real product build — the
# composition root when one is declared, the sole declared repo's root
# otherwise (#272/#310 Task 4: routed through the sole-repo default rule, not
# a literal `canonical` - N>1 declared repos refuses rather than guessing).
# Resolved ONCE, BEFORE any cd, because oss_manifest_discover walks up from
# $PWD and every manifest/state read after a cd would otherwise resolve
# somewhere else.
#
# Precedence is EXPLICIT > composition_root > sole-declared-repo root, refusing
# under N>1 unless one of the first two already answered - the same
# explicit-beats-derived shape as _oss_resolve_state. An ABSOLUTE
# composition_root short-circuits BEFORE the default-repo key is ever
# consulted: it names a complete path and needs no repo root at all, so it
# answers even under N>1 declared repos. A RELATIVE composition_root still
# joins onto the DEFAULT repo's root (recorded deviation 2), so it still needs
# the lookup and still refuses under N>1 - only an absolute value or an
# explicit workdir bypasses that tier (spec section 3).
#
# The explicit leg is not a convenience: without it, every caller that omits a
# workdir would need a discoverable manifest even when it already knows
# exactly where to run, and "fall back to $PWD when there is no manifest"
# would silently reinstate the very bug this task fixes.
oss_demo_workdir() { # $1=state-file [$2=explicit-workdir]
  local sf="$1" explicit="${2:-}" root comp dk shape
  [ -n "$explicit" ] && { printf '%s\n' "$explicit"; return 0; }
  comp="$(jq -r '.project.composition_root // empty' "$sf" 2>/dev/null)" || comp=""
  # An ABSOLUTE composition_root is a complete answer on its own - short-circuit
  # before touching the default-repo tier, so it resolves even under N>1
  # declared repos.
  case "$comp" in /*) printf '%s\n' "$comp"; return 0 ;; esac
  # Under N>1 the default tier cannot answer, and the generic
  # `_oss_default_repo_key` refusal names repo keys - which is the wrong remedy
  # here. `oss demo_run` is called bare by spine close, so a caller reading
  # "name one" has nowhere to name it. The missing thing is the FIELD.
  shape="$(_oss_shape_file 2>/dev/null)" || shape=""
  if [ "$(printf '%s' "$shape" | jq -r '.repos | length' 2>/dev/null || echo 0)" -gt 1 ]; then
    # Both facts, deliberately. The declared set is what the caller needs to
    # CHOOSE a root, and the field name is what they need to record it - an
    # earlier form printed only the set, and a caller of a bare `oss demo_run`
    # had nowhere to "name one".
    echo "oss: no repo key given and [$(printf '%s' "$shape" | jq -r '.repos | keys | join(", ")')] are declared - the cumulative demo runs at the composition root, so record it rather than naming a repo here: oss composition_set /abs/path/to/composition/root${comp:+ (project.composition_root is currently '$comp', which is relative and would compose against a default repo root that does not exist - it must be absolute)}" >&2
    return 2
  fi
  dk="$(_oss_default_repo_key)" || return $?
  root="$(_oss_repo_root "$dk")" || return $?
  if [ -n "$comp" ]; then
    printf '%s\n' "$root/$comp"
  else
    printf '%s\n' "$root"
  fi
}

# #761: refuse a state whose schema this build cannot read, BEFORE the first ledger read: a newer
# schema may carry line statuses this build does not know, and a run over it would report green
# for lines it never walked. Gated on the file parsing, as oss_state_mutate is, so an unreadable
# file keeps its own "cannot read state" refusal. rc 6 and the check's own message.
_oss_demo_schema_ok() { # $1=state-file
  jq -e . "$1" >/dev/null 2>&1 || return 0
  oss_state_check_version "$1"
}

oss_demo_run_auto() { # $1=state-file [$2=explicit-workdir]
  local sf="$1" wd n i line id text cmd expected want need out rc passed=0 pending=0
  _oss_demo_schema_ok "$sf" || return $?
  wd="$(oss_demo_workdir "$sf" "${2:-}")" || return 1
  [ -d "$wd" ] || { echo "oss: demo working dir does not exist: $wd" >&2; return 1; }
  n="$(jq '[.demo_ledger[] | select(.type=="auto" and (.status=="active" or .status=="quarantined" or .status=="planned"))] | length' "$sf" 2>/dev/null)" \
    || { echo "oss: cannot read state $sf" >&2; return 1; }
  i=0
  while [ "$i" -lt "$n" ]; do
    line="$(jq -c "[.demo_ledger[] | select(.type==\"auto\" and (.status==\"active\" or .status==\"quarantined\" or .status==\"planned\"))][$i]" "$sf")"
    id="$(printf '%s' "$line" | jq -r '.id')"
    text="$(printf '%s' "$line" | jq -r '.text')"
    if [ "$(printf '%s' "$line" | jq -r '.status')" = "quarantined" ]; then
      echo "SKIP $id (quarantined) - $text"
      i=$((i+1)); continue
    fi
    # #726: a line its spine has not built yet is REPORTED, never run. Running
    # it would report the plan rather than a defect, and it is the caller's
    # business (naming the line) whether that pending line is theirs.
    if [ "$(printf '%s' "$line" | jq -r '.status')" = "planned" ]; then
      echo "PENDING $id (planned -> $(printf '%s' "$line" | jq -r '.source_spine')) - $text"
      pending=$((pending+1)); i=$((i+1)); continue
    fi
    cmd="$(printf '%s' "$line" | jq -r '.command')"
    expected="$(printf '%s' "$line" | jq -r '.expected')"
    # Subshell cd: the process cwd is never mutated, so the NEXT iteration's
    # jq reads and any later manifest resolution still see the original $PWD.
    # `if out="$(...)"; then rc=0; else rc=$?; fi` — NOT `set +e; ...; set -e`.
    # `set`'s options are process-global, not function-scoped, so the toggle
    # this function used to do reaches past its own return and mutates
    # errexit for every caller up the stack (exactly what lib/verify.sh's
    # sibling comment calls out as the fragile idiom it replaced with this
    # same `if`-capture form). Standardized here to match.
    if out="$( cd "$wd" && bash -c "$cmd" 2>&1 )"; then rc=0; else rc=$?; fi
    # Every arm FAILS CLOSED. The ledger is append-only: a line written by an
    # older, looser validator is re-run forever, so the runner cannot assume its
    # `expected` was ever validated. A `case` with no default arm silently
    # counted an unrecognized expected as a PASS, and a non-numeric `exit:`
    # operand made `[ ... -ne ... ]` exit 2 — which the `if` reads as false, so
    # the FAIL branch never ran. Both now fail the line.
    case "$expected" in
      exit:*+contains:?*)
        # #770: rc AND needle, split at the FIRST `+contains:`. Before `exit:*`, which would
        # read the whole tail as a non-digit operand. Each failure names its half.
        want="${expected#exit:}"; want="${want%%+contains:*}"; need="${expected#*+contains:}"
        case "$want" in ''|*[!0-9]*)
          echo "FAIL $id - $text (malformed expected '$expected': 'exit:' takes digits only)"; return 1;; esac
        # `! -eq`, not `-ne`: digits past the integer range make a test ERROR (rc 2), which
        # an `if -ne` reads as false and passes the line. Here an erroring test fails it.
        if ! [ "$rc" -eq "$want" ] 2>/dev/null; then
          echo "FAIL $id - $text (rc=$rc, wanted $want)"; printf '%s\n' "$out" | tail -5; return 1
        fi
        case "$out" in *"$need"*) ;; *)
          echo "FAIL $id - $text (output missing '$need')"; printf '%s\n' "$out" | tail -5; return 1;; esac
        if [ "$want" = "0" ] && printf '%s' "$out" | oss_verify_zero_tests_guard "$cmd"; then
          echo "FAIL $id - $text (vacuous-green: recognized runner executed zero tests)"; return 1
        fi ;;
      exit:*)
        want="${expected#exit:}"
        case "$want" in ''|*[!0-9]*)
          echo "FAIL $id - $text (malformed expected '$expected': 'exit:' takes digits only)"; return 1;; esac
        # `! -eq`, not `-ne`: an operand past the integer range makes the test ERROR (rc 2), which
        # an `if -ne` reads as false and passes the line (found with #770).
        if ! [ "$rc" -eq "$want" ] 2>/dev/null; then
          echo "FAIL $id - $text (rc=$rc, wanted $want)"; printf '%s\n' "$out" | tail -5; return 1
        fi
        # Vacuous-green is checked ONLY for a success expectation. The previous
        # unscoped placement ran after every arm, so a line legitimately
        # expecting exit:1 from a recognized runner was failed as vacuous.
        if [ "$want" = "0" ] && printf '%s' "$out" | oss_verify_zero_tests_guard "$cmd"; then
          echo "FAIL $id - $text (vacuous-green: recognized runner executed zero tests)"; return 1
        fi ;;
      contains:?*)
        # A command that could not run (126 not executable, 127 not found) never
        # passes an output check: the shell's own error text can carry the needle,
        # and this arm reads no exit status at all (pulse360
        # `verify-step-halt-swallowed-false-pass`). Any other nonzero exit is left
        # alone - a line may expect a refusal message from `exit 1`.
        case "$rc" in 126|127)
          echo "FAIL $id - $text (rc=$rc: the command is not invocable here; an output check never passes on it)"; printf '%s\n' "$out" | tail -5; return 1;; esac
        case "$out" in *"${expected#contains:}"*) ;; *)
          echo "FAIL $id - $text (output missing '${expected#contains:}')"; printf '%s\n' "$out" | tail -5; return 1;; esac ;;
      *)
        echo "FAIL $id - $text (unrecognized expected '$expected'; the grammar is exit:<n> | contains:<str> | exit:<n>+contains:<str>)"; return 1 ;;
    esac
    passed=$((passed+1)); i=$((i+1))
  done
  # Vacuous floor: `n` counts active, quarantined or planned auto lines, so an
  # empty, user-lines-only, or all-quarantined ledger executes nothing. A run
  # that executed zero lines is not a pass - same refusal as report_cross_check's
  # "nothing to cross-check" over a spec that yielded zero ACs. An all-planned
  # ledger is the same verdict, and the message names how many are pending so
  # the reader is not left asking whether anything was authored at all.
  if [ "$passed" -eq 0 ]; then
    echo "oss: demo ledger executed zero lines ($n auto lines: quarantined, planned or none; $pending pending) - a vacuous run is not a pass" >&2
    return 1
  fi
  echo "PASS $passed lines"
  [ "$pending" -eq 0 ] || echo "$pending pending"
}

# §6.1 spine close walks the CLOSING SPINE'S OWN user lines; §6.2 release close
# walks EVERY accumulated one. One verb, scoped by an optional spine argument.
oss_demo_user_lines() { # $1=state-file [$2=spine]
  _oss_demo_schema_ok "$1" || return $?   # #761: same refusal as demo_run, before the read
  if [ -n "${2:-}" ]; then
    jq --arg s "$2" '[.demo_ledger[] | select(.type=="user" and .status=="active" and .source_spine==$s)]' "$1"
  else
    jq '[.demo_ledger[] | select(.type=="user" and .status=="active")]' "$1"
  fi
}

oss_demo_record_close() { # $1=state $2=scope $3=id $4=passed(true|false) $5=line-count $6=notes
  case "$2" in work_item|spine|release) ;; *)
    echo "oss: close scope must be work_item|spine|release" >&2; return 2;; esac
  case "$4" in true|false) ;; *) echo "oss: passed must be true|false" >&2; return 2;; esac
  oss_state_mutate "$1" add_close_record \
    "$(jq -n --arg sc "$2" --arg id "$3" --argjson ok "$4" --argjson n "${5:-0}" \
        --arg notes "${6:-}" --arg ts "$(_oss_now)" \
      '{scope:$sc,id:$id,demo_passed:$ok,demo_lines:$n,notes:$notes,at:$ts}')"
}
