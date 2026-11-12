#!/usr/bin/env bash
# Cumulative product demo ledger (spec §3, §6.1) + patch lane records.

oss_ledger_add_auto() { # $1=state $2=spine $3=text $4=command $5=expected [$6=planned|active]
  # Validate the spine exists BEFORE anything else: a demo line journaled
  # against a nonexistent spine (typo like r0.s99) is silently skipped at
  # spine close, which filters by source_spine — the line counts as authored
  # but never runs, producing phantom coverage. Same reject-before-mutate
  # shape as _oss_ledger_plan_amendment and oss_ledger_apply_pending below.
  jq -e --arg s "$2" '.spines[] | select(.id == $s)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$2' - a demo line keyed to a spine that does not exist would never be exercised at close" >&2; return 7; }
  # The `exit:` operand must be digits-only END TO END. The old glob
  # `exit:[0-9]*` was "exit:" + ONE digit + anything, so plausible authoring
  # slips ("exit:0 (tests green)", "exit:0abc", "exit:0 # green") were accepted
  # here — and the runner USED `[ "$rc" -ne "${expected#exit:}" ]` (now the fail-closed
  # `! [ -eq ]`, 1.39.0), which exits 2 on the non-numeric operand; the enclosing `if`
  # read that as FALSE: the FAIL branch was skipped and the line counted as passed. The ledger is append-only,
  # so one such line re-reports green at every future close. Same
  # `''|*[!0-9]*` idiom as state.sh's schema-version guard, for the same reason:
  # a value that is not digits makes the later numeric test error rather than
  # compare, and an erroring test reads as "condition not met".
  # #770: `exit:<n>+contains:<str>`, split at the FIRST `+contains:` (the needle may hold `+`
  # or `contains:`). This arm precedes `exit:*`, which would refuse it as non-digits. An
  # empty needle does not match the glob and falls to `exit:*`, which refuses it.
  local pre
  case "$5" in
    exit:*+contains:?*)
      pre="${5#exit:}"; pre="${pre%%+contains:*}"
      case "$pre" in ''|*[!0-9]*)
        echo "oss: expected 'exit:<n>+contains:<str>' takes digits only before '+' (got '$5')" >&2; return 2;; esac ;;
    exit:*)
      case "${5#exit:}" in ''|*[!0-9]*)
        echo "oss: expected 'exit:<n>' takes digits only (got '$5')" >&2; return 2;; esac ;;
    contains:?*) ;;
    *) echo "oss: expected must be 'exit:<n>', 'contains:<str>' or 'exit:<n>+contains:<str>'" >&2; return 2 ;;
  esac
  # #363: a line authored at plan time tests code that does not exist yet, so
  # it starts `planned` and demo_run reports it as pending until its spine's
  # close activates it. `active` stays available for the one caller whose lines
  # test code that already ships (adoption's seed lines, which Release 1's
  # spines mint).
  local st="${6:-planned}"
  case "$st" in planned|active) ;; *)
    echo "oss: a new demo line starts planned or active (got '$st') - planned until its code is built (#363)" >&2; return 2;; esac
  oss_state_mutate "$1" add_demo_line \
    "$(jq -n --arg s "$2" --arg t "$3" --arg c "$4" --arg e "$5" --arg st "$st" --arg ts "$(_oss_now)" \
      '{type:"auto",text:$t,command:$c,expected:$e,source_spine:$s,status:$st,status_reason:null,status_by:null,at:$ts}')" \
    demo
}

oss_ledger_add_user() { # $1=state $2=spine $3=text $4=outcome [$5=planned|active]
  # Same validation as add_auto: an unknown source_spine journals silently
  # and is never run at the close ceremony.
  jq -e --arg s "$2" '.spines[] | select(.id == $s)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$2' - a demo line keyed to a spine that does not exist would never be exercised at close" >&2; return 7; }
  local lower
  lower="$(printf '%s' "$3" | tr '[:upper:]' '[:lower:]')"
  lower="${lower#"${lower%%[![:space:]]*}"}"   # trim leading whitespace so " Open ..." can't evade the ban
  case "$lower" in inspect\ *|view\ *|open\ *)
    echo "oss: inspector phrasing banned in user journey lines (spec §5.3 floor) - phrase as an action the user performs for value" >&2
    return 2;; esac
  # Same default and same refusal as add_auto above: a journey line is authored
  # before the flow exists, so it starts `planned` unless the caller says the
  # flow already ships.
  local st="${5:-planned}"
  case "$st" in planned|active) ;; *)
    echo "oss: a new demo line starts planned or active (got '$st') - planned until its code is built (#363)" >&2; return 2;; esac
  oss_state_mutate "$1" add_demo_line \
    "$(jq -n --arg s "$2" --arg t "$3" --arg o "$4" --arg st "$st" --arg ts "$(_oss_now)" \
      '{type:"user",text:$t,outcome:$o,source_spine:$s,status:$st,status_reason:null,status_by:null,at:$ts}')" \
    demo
}

_oss_ledger_require_line() { # $1=state $2=line-id
  jq -e --arg id "$2" '.demo_ledger[] | select(.id == $id)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown demo line '$2'" >&2; return 7; }
}

# D1: supersede/retire are PLANNING verbs. They record intent and leave the line
# live, so a sibling spine closing before this one still runs the flow, and a
# spine that is replanned or abandoned drops no coverage. `close` applies them.
_oss_ledger_plan_amendment() { # $1=state $2=line-id $3=status $4=by-spine $5=reason
  _oss_ledger_require_line "$1" "$2" || return $?
  # <by-spine> is the JOIN KEY apply_demo_pending matches on, not mere
  # provenance: a typo'd spine here means the amendment is never applied by
  # any close, silently and forever. Validate it like the line id
  # (demo-amendments.md §3 documents the same rule for readers of the prose).
  jq -e --arg s "$4" '.spines[] | select(.id == $s)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$4' - an amendment keyed to a spine that does not exist would never be applied" >&2; return 7; }
  oss_state_mutate "$1" set_demo_line_pending \
    "$(jq -n --arg id "$2" --arg st "$3" --arg by "$4" --arg r "$5" --arg ts "$(_oss_now)" \
      '{id:$id,status:$st,by:$by,reason:$r,at:$ts}')"
}
oss_ledger_supersede() { _oss_ledger_plan_amendment "$1" "$2" superseded "$3" "$4"; }
oss_ledger_retire()    { _oss_ledger_plan_amendment "$1" "$2" retired    "$3" "$4"; }

# The close-time apply. Runs AFTER merge and BEFORE the cumulative demo, so the
# demo measures the amended set against a product where the flow really is gone.
# Same reject-before-mutate shape as _oss_ledger_plan_amendment: this is the
# only mutator this task added that lacked it (F3) - an unknown or typo'd spine
# used to return rc 0 and journal a no-op, so `close` (Task 9) would report
# success while silently applying nothing.
oss_ledger_apply_pending() { # $1=state $2=spine
  jq -e --arg s "$2" '.spines[] | select(.id == $s)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$2' - apply_pending against a spine that does not exist would apply nothing while reporting success" >&2; return 7; }
  oss_state_mutate "$1" apply_demo_pending "$(jq -n --arg s "$2" '{spine:$s}')"
}

# The escape hatch: clears the CALLING spine's planned amendment on a line.
# There is no `reactivate` for an APPLIED one by design - once close has
# applied it the ledger records history.
#
# F1 (2026-07-31): a line now carries a LIST of pending amendments, one per
# spine, so "clear the pending amendment on line d1" is ambiguous - clearing
# every spine's entry indiscriminately is the same silent-coverage-loss
# footgun F1 exists to remove, just moved from set/apply to unplan. The spine
# is therefore REQUIRED, not optional, and is validated the same way the two
# planning verbs validate it: reject-before-mutate, both on an unknown line and
# on a spine that holds no pending amendment on that line (a typo'd spine here
# would otherwise silently no-op and look like it worked).
oss_ledger_unplan() { # $1=state $2=line-id $3=spine
  _oss_ledger_require_line "$1" "$2" || return $?
  jq -e --arg id "$2" --arg s "$3" \
      '.demo_ledger[] | select(.id == $id) | (.pending_amendments // []) | map(select(.by == $s)) | length > 0' \
      "$1" >/dev/null 2>&1 \
    || { echo "oss: spine '$3' holds no pending amendment on line '$2'" >&2; return 7; }
  oss_state_mutate "$1" clear_demo_pending "$(jq -n --arg id "$2" --arg s "$3" '{id:$id,spine:$s}')"
}

# Read one field of one demo line ("" when absent). The caller has already run
# _oss_ledger_require_line, so an empty answer means the field is unset.
_oss_ledger_field() { # $1=state $2=line-id $3=field
  jq -r --arg id "$2" --arg f "$3" '.demo_ledger[] | select(.id == $id) | .[$f] // ""' "$1"
}

# #363/#726: a line authored at plan time is `planned` until its code exists.
# activate is the one way forward; there is deliberately no way back
# (active -> planned would let a session relabel a regression "not built yet").
# A deferred line activates too: that is "walk it now" at release close.
oss_ledger_activate() { # $1=state $2=line-id
  _oss_ledger_require_line "$1" "$2" || return $?
  local st; st="$(_oss_ledger_field "$1" "$2" status)"
  case "$st" in planned|deferred) ;; *)
    echo "oss: line '$2' is '$st' - only a planned or deferred line can be activated" >&2; return 2;; esac
  # `from` re-checks the status inside the op, under the lock (#760 F2): the case
  # above is the readable refusal, this is the one that holds against a writer
  # landing between that read and this write.
  oss_state_mutate "$1" set_demo_line_status \
    "$(jq -n --arg id "$2" '{id:$id,status:"active",by:"activate",reason:null,from:["planned","deferred"]}')"
}

# Spine close step 3: the closing spine's own planned lines go active before
# the demo, so they must pass at that close. Deferred lines are left alone -
# undoing an operator's deferral is not this verb's call.
oss_ledger_activate_spine() { # $1=state $2=spine
  jq -e --arg s "$2" '.spines[] | select(.id == $s)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$2'" >&2; return 7; }
  local ids id n=0
  ids="$(jq -r --arg s "$2" '.demo_ledger[] | select(.source_spine == $s and .status == "planned") | .id' "$1")" \
    || { echo "oss: cannot read the demo ledger from '$1'" >&2; return 2; }
  for id in $ids; do
    oss_state_mutate "$1" set_demo_line_status \
      "$(jq -n --arg id "$id" --arg s "$2" '{id:$id,status:"active",by:("activate_spine:" + $s),reason:null,from:["planned"]}')" \
      || return $?
  done
  # #760 F2: count what the lock actually let through, not what this pass attempted.
  # The snapshot above is a pre-lock read, so a line deferred (or retired) while the
  # loop ran is in it and no longer `planned`; the op leaves that line alone, and the
  # count must not claim it. A successful write stamps this spine's marker, so a line
  # counts only when it is both active and marked by THIS run.
  # Known limit (#761): the count is a read-back, so two concurrent activations of one spine can
  # both count a line, and one changed between the write and the read is missed. State is never
  # wrong, and nothing reads the number to decide anything.
  for id in $ids; do
    if [ "$(_oss_ledger_field "$1" "$id" status)" = active ] \
       && [ "$(_oss_ledger_field "$1" "$id" status_by)" = "activate_spine:$2" ]; then
      n=$((n+1))
    fi
  done
  echo "activated $n"
}

# Quarantine is NOT a planned amendment: it is raised at close/doctor time when a
# line actually fails for causes unrelated to any open spine, so it applies at
# once. The release is recorded because §6.1 makes it a parking ticket that
# expires - "fixed or retired by the next release close" needs an anchor.
oss_ledger_quarantine() { # $1=state $2=line-id $3=reason $4=release
  _oss_ledger_require_line "$1" "$2" || return $?
  oss_state_mutate "$1" set_demo_line_status \
    "$(jq -n --arg id "$2" --arg st quarantined --arg by quarantine \
        --arg r "$3" --arg rel "${4:-}" \
      '{id:$id,status:$st,by:$by,reason:$r,release:$rel}')"
}

oss_ledger_active_auto() { jq '[.demo_ledger[] | select(.type == "auto" and .status == "active")]' "$1"; }

# The quarantine gate's twin of oss_reg_expired_fakes (spec §6.1 parking ticket,
# §6.2 step 4). §6.1 says a quarantined line "must be fixed or retired by the
# next release close", so the blocking set is every line quarantined in a release
# STRICTLY EARLIER than this one - `<`, not `<=`. A line quarantined during THIS
# release is a fresh ticket that comes due at the next close, and folding it in
# here would make a close unable to quarantine anything without blocking itself.
#
# THE FIELD IS `.quarantined_in_release`, NOT `.release`. `oss_ledger_quarantine`
# builds a payload keyed `release` (line 106), but `_oss_apply_op`'s
# `set_demo_line_status` writes it onto the line as `.quarantined_in_release`
# (state.sh:84) - and only when it is non-empty. A selector written from the
# payload shape reads a key that exists on no line, returns empty, and every
# quarantine escapes at rc 0 forever. The payload is the wire format; the line is
# the record.
#
# A quarantine with NO release anchor blocks, marked `no-release-anchor`: §6.1's
# ticket expires against a release, so a ticket carrying none can never come due.
# `oss ledger_quarantine` takes the release as `${3:-}` and the dispatcher passes
# `${3:-}` through, so an anchorless quarantine is one omitted argument away.
#
# Same rc polarity as the fake gate - 0 = CLEAN, 1 = BLOCKING, 2 =
# could-not-check - and the release argument is validated as r<digits> (#759).
oss_ledger_expired_quarantines() { # $1=state $2=release ; rc 0 clean, 1 blocking, 2 could-not-check
  local sf="$1" rel="$2" out
  _oss_ledger_release_ok "$rel" \
    || { echo "oss: expired_quarantines needs a release id of the form r<N> (got '$rel')" >&2; return 2; }
  out="$(jq -r --arg rel "$rel" '
      ($rel | ltrimstr("r") | tonumber) as $cut
      | .demo_ledger[]
      | select(.status == "quarantined")
      | . as $l
      | (try (.quarantined_in_release | ltrimstr("r") | tonumber) catch null) as $q
      | select($q == null or $q < $cut)
      | [ $l.id,
          (if $q == null then "no-release-anchor" else $l.quarantined_in_release end),
          ($l.status_reason // "") ] | @tsv' "$sf" 2>/dev/null)" \
    || { echo "oss: cannot read the demo ledger from '$sf' - the quarantine gate is INCONCLUSIVE, not clean" >&2; return 2; }
  [ -n "$out" ] || return 0
  printf '%s\n' "$out"
  return 1
}

_oss_ledger_release_ok() { # $1=release
  case "$1" in r[0-9]*) case "${1#r}" in *[!0-9]*) return 1;; esac; return 0;; esac
  return 1
}

# #710: a spine's own user: line that cannot be walked now is DEFERRED, still
# owed, with the operator's words and the release it is due at. Only the
# owning spine defers it; only user: lines (quarantine parks a failing auto:).
oss_ledger_defer() { # $1=state $2=line-id $3=spine $4=operator-reason $5=release
  _oss_ledger_require_line "$1" "$2" || return $?
  jq -e --arg s "$3" '.spines[] | select(.id == $s)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$3'" >&2; return 7; }
  local ty src st
  ty="$(_oss_ledger_field "$1" "$2" type)"; src="$(_oss_ledger_field "$1" "$2" source_spine)"
  st="$(_oss_ledger_field "$1" "$2" status)"
  [ "$ty" = user ] || { echo "oss: line '$2' is an $ty: line - only a user: line can be deferred (a failing auto: line is quarantined)" >&2; return 2; }
  [ "$src" = "$3" ] || { echo "oss: line '$2' belongs to spine '$src', not '$3' - a spine defers only its own user: lines" >&2; return 2; }
  case "$st" in active|planned|deferred) ;; *)
    echo "oss: line '$2' is '$st' - only an active, planned or deferred line can be deferred" >&2; return 2;; esac
  [ -n "${4//[[:space:]]/}" ] || { echo "oss: a deferral needs the operator's reason, in their words" >&2; return 2; }
  _oss_ledger_release_ok "$5" || { echo "oss: a deferral is due at a release of the form r<N> (got '$5')" >&2; return 2; }
  # `from` re-checks the status under the lock (#760 F2): the case above is the
  # readable refusal, this is the one that holds against a writer landing between
  # that read and this write.
  oss_state_mutate "$1" set_demo_line_status \
    "$(jq -n --arg id "$2" --arg s "$3" --arg r "$4" --arg rel "$5" \
        '{id:$id,status:"deferred",by:$s,reason:$r,until:$rel,from:["active","planned","deferred"]}')"
}

# The deferral gate, twin of oss_ledger_expired_quarantines. A deferral names
# the release it is DUE AT, so the cut is <= (quarantine uses <). Numeric, for
# the same r2-vs-r10 reason. A due line that already carries a pending retire
# or supersede OWNED BY A SPINE THAT CAN STILL CLOSE (planned|active) is printed
# but does not block: that spine's close applies it. An amendment owned by a
# closed or abandoned spine is never applied, so the line still blocks -
# otherwise it reads clean at every later release (Codex, PR #127).
# rc 0 clean (or only amendment-pending rows), 1 blocking, 2 could-not-check.
# Columns: id, due release, verdict, reason, and (#761) the owning source_spine, which
# `oss ledger_defer` needs for a re-defer; release close has no spine of its own.
oss_ledger_expired_deferrals() { # $1=state $2=release
  local sf="$1" rel="$2" out
  _oss_ledger_release_ok "$rel" \
    || { echo "oss: expired_deferrals needs a release id of the form r<N> (got '$rel')" >&2; return 2; }
  out="$(jq -r --arg rel "$rel" '
      ($rel | ltrimstr("r") | tonumber) as $cut
      | [.spines[] | select(.status == "planned" or .status == "active") | .id] as $open
      | .demo_ledger[]
      | select(.status == "deferred")
      | . as $l
      | (try (.deferred_until_release | ltrimstr("r") | tonumber) catch null) as $d
      | select($d == null or $d <= $cut)
      | (((.pending_amendments // []) | map(select((.status == "retired" or .status == "superseded")
                                                   and (.by as $b | $open | index($b) != null))))[0]) as $am
      | [ $l.id,
          (if $d == null then "no-release-anchor" else $l.deferred_until_release end),
          (if $am != null then "amendment pending -> " + $am.by else "due" end),
          ($l.status_reason // ""),
          ($l.source_spine // "") ] | @tsv' "$sf" 2>/dev/null)" \
    || { echo "oss: cannot read the demo ledger from '$sf' - the deferral gate is INCONCLUSIVE, not clean" >&2; return 2; }
  [ -n "$out" ] || return 0
  printf '%s\n' "$out"
  printf '%s\n' "$out" | awk -F'\t' '$3 == "due" { f = 1 } END { exit f ? 1 : 0 }'
}

# #726 part 2: a research spine planned with a time-box escape closes on an
# honest negative result. The line becomes `escaped` - terminal, never walked
# again, and distinct from `retired` (the flow is not gone; it failed under a
# pre-declared escape). The clause is quoted from SPINE.md; the words are the
# operator's. Only the owning spine, only user: lines.
oss_ledger_escape() { # $1=state $2=line-id $3=spine $4=escape-clause $5=operator-reason
  _oss_ledger_require_line "$1" "$2" || return $?
  jq -e --arg s "$3" '.spines[] | select(.id == $s)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$3'" >&2; return 7; }
  local ty src st
  ty="$(_oss_ledger_field "$1" "$2" type)"; src="$(_oss_ledger_field "$1" "$2" source_spine)"
  st="$(_oss_ledger_field "$1" "$2" status)"
  [ "$ty" = user ] || { echo "oss: line '$2' is an $ty: line - only a user: line can close under an escape" >&2; return 2; }
  [ "$src" = "$3" ] || { echo "oss: line '$2' belongs to spine '$src', not '$3'" >&2; return 2; }
  case "$st" in active|deferred) ;; *)
    echo "oss: line '$2' is '$st' - only an active or deferred line can close under an escape" >&2; return 2;; esac
  [ -n "${4//[[:space:]]/}" ] || { echo "oss: an escape needs the escape clause quoted from SPINE.md" >&2; return 2; }
  [ -n "${5//[[:space:]]/}" ] || { echo "oss: an escape needs the operator's ruling, in their words" >&2; return 2; }
  # `from` re-checks the status under the lock (#760 F2): the case above is the
  # readable refusal, this is the one that holds against a writer landing between
  # that read and this write.
  oss_state_mutate "$1" set_demo_line_status \
    "$(jq -n --arg id "$2" --arg s "$3" --arg c "$4" --arg r "$5" \
        '{id:$id,status:"escaped",by:$s,reason:$r,clause:$c,from:["active","deferred"]}')"
}

oss_ledger_add_patch() { # $1=state $2=commit $3=one-liner $4=repo-key
  local repo
  # #272/#310 Task 5: same if-form default resolution as the nine Task 4
  # sites - command substitution inside a default expansion (`${4:-$(...)}`)
  # would swallow _oss_default_repo_key's rc 2 refusal and its stderr, so the
  # caller never learns why. No state schema bump: `add_patch_record`
  # (state.sh) is untouched, and replaying an old journal produces patch
  # records with no `repo` key at all - readers treat that as `canonical`.
  if [ -z "${4:-}" ]; then repo="$(_oss_default_repo_key)" || return $?; else repo="$4"; fi
  oss_state_mutate "$1" add_patch_record \
    "$(jq -n --arg c "$2" --arg t "$3" --arg repo "$repo" --arg ts "$(_oss_now)" '{commit:$c,text:$t,repo:$repo,at:$ts}')"
}
