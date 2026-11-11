#!/usr/bin/env bash
# Bones / risk gates / fakes / feature map + touch-surface matching.

# CSV grammar (#340): a bare "," separates entries; "\," is a literal comma
# inside one. The escaped comma is parked on the private-use codepoint U+E000
# for the split and restored after; a RAW U+E000 in the input would silently
# become a comma, so it is refused up front (fail-closed, never rewritten).
_oss_csv_to_json() {
  # A raw U+E000 in the input would silently become a comma after the
  # round-trip; refuse it up front (fail-closed). jq runs the codepoint test
  # because neither bash 3.2 (no \uXXXX in $'...') nor zsh quoting can
  # express the codepoint reliably here.
  # \p{Co} (any private-use codepoint) rather than a U+E000 literal: jq's
  # test() refuses to match the codepoint written as an escape, while the
  # category matches - measured - and the sentinel is inside the category.
  if [ "$(printf '%s' "$1" | jq -Rr 'if test("\\p{Co}") then "raw-pua" else empty end')" = "raw-pua" ]; then
    echo "oss: input contains a private-use codepoint (U+E000-family, the internal CSV escape range) - remove it and retry" >&2
    return 2
  fi
  printf '%s\n' "$1" | jq -R '
  gsub("\\\\,"; "\uE000")
  | split(",")
  | map(gsub("\uE000"; ",") | gsub("^ +| +$";""))
  | map(select(length>0))'; }

# The read the ladder and the add-rails share: how many records match the key.
# Echoes the count; rc 1 no state (with the init remedy), rc 2 unreadable or a
# non-numeric count - the `case` arm is the belt to the `||`'s braces, because a
# jq that exits 0 with something that is not a number would otherwise reach an
# arithmetic test as a syntax error.
_oss_reg_count() { # $1=state-file $2=jq-selector(uses $v) $3=plural $4=value
  local sf="$1" sel="$2" many="$3" val="$4" n
  if [ ! -f "$sf" ]; then
    echo "oss: no state at $sf - run 'oss init <name>' first" >&2; return 1
  fi
  n="$(jq --arg v "$val" "[$sel] | length" "$sf" 2>/dev/null)" || {
    echo "oss: cannot read $many from $sf" >&2; return 2; }
  case "$n" in ''|*[!0-9]*)
    echo "oss: cannot read $many from $sf" >&2; return 2 ;;
  esac
  printf '%s\n' "$n"
}

# The resolve-and-refuse ladder, ONCE (#525). Three verbs carried it
# line-for-line - set_risk_gate_controls (#340), set_bone_touch and
# set_risk_gate_touch (1.11.0) - with only the collection, the field and the
# labels swapped. The ladder encodes a LEARNED fix rather than boilerplate: the
# explicit `2>/dev/null` routing exists because under bin/oss's errexit an
# unguarded failing assignment hard-exits with jq's raw parse error before the
# `case` below can label it (rc 5, not the intended rc 2), and that comment plus
# the numeric arm beside it is exactly the line a fourth hand-copy drops. The
# labels are arguments so every message stays byte-identical to the three it
# replaces. `read-plural` and `count-noun` are SEPARATE on purpose: the read
# messages say "risk gates" while the duplicate message said "gates", so giving
# the two one label silently reworded the duplicate refusal for both gate verbs.
# rc 1 no state, 2 unreadable, 7 unknown or duplicate.
_oss_reg_require_single() { # $1=state-file $2=jq-selector(uses $v) $3=singular $4=read-plural $5=count-noun $6=duplicate-noun $7=value
  local sf="$1" sel="$2" one="$3" many="$4" cnt="$5" dup="$6" val="$7" n
  n="$(_oss_reg_count "$sf" "$sel" "$many" "$val")" || return $?
  if [ "$n" -eq 0 ]; then
    echo "oss: unknown $one '$val'" >&2; return 7
  fi
  if [ "$n" -gt 1 ]; then
    echo "oss: $one '$val' matches $n $cnt - $dup have no supported repair yet (#305); refusing rather than guessing" >&2; return 7
  fi
}

# The per-entry refusal, ONCE. A REAL entry carrying a surrounding invisible
# character is not blank - it passes the emptiness arm - and its glob can never
# match a real path once that character is part of it. Measured on 602565f: a
# CR-terminated glob was journaled at rc 0 and touch_check went CLEAN on the very
# path the re-point was meant to cover, which is the defect these verbs exist to
# repair entered through their own argument handling.
#
# The edge class is `[\s\p{Cf}]`, not `\s` alone. `\s` is Unicode White_Space and
# covers the CR, tab, VT, NBSP and ideographic-space vectors - but NOT the format
# characters, and a UTF-8 BOM (U+FEFF) or a zero-width space (U+200B) sits on
# line 1 of exactly the composed-from-a-Windows-file input this rail exists for.
# Measured before this extension: a BOM-prefixed and a ZWSP-suffixed glob were
# BOTH journaled at rc 0 and touch_check answered CLEAN on the covered path - the
# #530 harm one invisible character wide of the guard. `\p{Cf}` closes the family
# (BOM, ZWSP, ZWNJ, ZWJ, soft hyphen, bidi marks).
#
# LEADING/TRAILING only, deliberately: an interior space is legal (a path can
# contain one), so this is narrower than "any whitespace". The offending entry is
# named with @json, because a CR on a terminal is invisible and "trailing
# whitespace" alone does not say which entry to fix. @json renders `\r`, `\t` and
# `\v` in escaped form but passes NBSP, U+3000, BOM and ZWSP through as raw
# UTF-8, so for those vectors the named entry reads like a clean glob; that
# fidelity gap is tracked on #551, and the refusal itself is unaffected.
#
# It is shared with the two ADD verbs because the same entry can be journaled at
# MINT, where nothing refused it and there is no re-point to repair it with: a
# bone minted on a CRLF-composed csv declared a surface that touch_check then
# answered CLEAN on, from mint day, with rc 0 and nothing to review. The mint
# takes this arm and the one-list arm - it does NOT take the emptiness arm,
# because a bone may legitimately be minted before its surface exists (pinned).
_oss_reg_refuse_contaminated() { # $1=json-list $2=noun-phrase $3=why
  local list="$1" noun="$2" ws_why="$3" bad
  # `2>/dev/null`: the one-list arm above normally rejects a non-parsing list
  # first, so this jq only ever sees a list that parses - but the arm is shared,
  # and a caller that reaches it directly must not leak jq's raw
  # "--argjson" error into a refusal that is OURS (see _oss_reg_require_one_list).
  bad="$(jq -rn --argjson t "$list" 'first($t[] | select(. != (sub("^[\\s\\p{Cf}]+";"") | sub("[\\s\\p{Cf}]+$";"")))) // empty | @json' 2>/dev/null)" || {
    echo "oss: cannot read the $noun" >&2; return 2; }
  if [ -n "$bad" ]; then
    echo "oss: the $noun has an entry with leading or trailing whitespace: $bad - trim it; $ws_why" >&2; return 2
  fi
}

# The one-list arm, ONCE (#541 round 2). The splitter is line-oriented (`jq -R`
# processes each line alone), so a csv wrapped over two lines emits TWO JSON
# values and `--argjson` cannot parse them. Both the corrective appends AND the
# two mint verbs take this arm: at the mint it is what makes a wrapped csv answer
# "not one list" instead of letting the contaminated arm's jq fail - which leaked
# `jq: invalid JSON text passed to --argjson` onto stderr and then mislabelled the
# failure "cannot read the touch list", the raw-error leak and the false cause the
# re-point path has been pinned against since 1.11.0, reproduced one verb over by
# extracting the arms apart.
_oss_reg_require_one_list() { # $1=json-list $2=noun-phrase $3=csv-name
  jq -en --argjson t "$1" 'true' >/dev/null 2>&1 || {
    echo "oss: the $2 is not one list - a $3 is a single comma-separated line, and a newline splits it into several" >&2; return 2; }
}

# The payload half of a corrective append, ONCE (#525). The two touch re-points
# carried these refusals verbatim; set_risk_gate_controls takes the same guard
# with its own nouns (#524). TWO refusals, deliberately separate: the splitter is
# line-oriented (`jq -R` processes each line alone), so a csv wrapped over two
# lines emits TWO JSON values and `--argjson` cannot parse them - folding that
# into the emptiness test reported "the list is empty" for a list that was merely
# wrapped, and an agent following that message retries and stays stuck. The
# emptiness arm is not a `length` test: the splitter trims literal SPACES only,
# so a tab-, CR- or VT-only entry survives as an "entry" that can never match a
# real path and reproduces the silent-clean defect these verbs exist to repair.
_oss_repoint_guard() { # $1=json-list $2=noun $3=csv-name $4=needle $5=blank-why $6=whitespace-why
  local list="$1" noun="$2" csv="$3" needle="$4" blank_why="$5" ws_why="$6"
  _oss_reg_require_one_list "$list" "new $noun" "$csv" || return $?
  jq -en --argjson t "$list" 'any($t[]; test("[^\\s]"))' >/dev/null 2>&1 || {
    echo "oss: the new $noun needs at least one $needle - every entry is blank, and $blank_why" >&2; return 2; }
  _oss_reg_refuse_contaminated "$list" "new $noun" "$ws_why"
}

# #305 item 1: the add verbs refuse a ref that already exists. The ADR ref (and
# the gate name) is the key every reader uses - touch_check, the doctor shape
# gate, the registry doc - and the writer did not enforce it: a second bone_add
# for ADR-013 minted a second row for one ref (the PulseDB adopt pilot,
# 2026-08-23), after which bone_set_touch refuses the ref at rc 7 and the
# operator holds a surface they cannot repair. Nothing DETECTS a duplicate
# (doctor's four checks are state/schema/replay/shape), so the writer is the only
# place the mint can be refused. risk_gate_add carries the same rail: the two are
# one defect class - the duplicate-row fixtures in test-registries.sh were already
# labelled "#305 shape" for both - and a duplicate gate name is refused by
# set_controls/set_touch with a message naming #305, so an open gate writer would
# re-open the asymmetry #524 was filed about.
#
# The rail is handed to oss_state_mutate as its uniqueness guard, so it is
# evaluated INSIDE that function's lock. It was a count in the verb first, and
# that spelling is a check-to-append race: both ceremonies read "no such ref",
# then serialize on the lock, and the second appends a second row for one key -
# the unrepairable state this rail exists to prevent, entered by two conforming
# callers. Measured against that version: two concurrent `oss bone_add ADR-Rn`
# each returned rc 0 and left two rows for ADR-Rn (the window is the caller's own
# jq spawn between the count and the lock, and it is not narrow). The refusal is
# unchanged - same rc 7, same message byte for byte - only the moment moves.
_oss_reg_uniq_bone() { # $1=state-file $2=payload about to be minted -> 0, or 7 if the ref exists
  local adr n have
  adr="$(printf '%s' "$2" | jq -r '.adr')" || return 4
  # #705: ASCII case-folded on both sides, to match adopt C3 step 1a's LC_ALL=C fold. A
  # stored .adr that is not a string makes ascii_downcase error, so the read fails closed.
  n="$(_oss_reg_count "$1" '.bones[] | select((.adr | ascii_downcase) == ($v | ascii_downcase))' "bones" "$adr")" || return $?
  [ "$n" -eq 0 ] || {
    have="$(jq -r --arg v "$adr" 'first(.bones[] | select((.adr | ascii_downcase) == ($v | ascii_downcase)) | .adr)' "$1" 2>/dev/null)" || have="$adr"
    [ "$have" = "$adr" ] && have="" || have=" as '$have' (ADR refs compare ASCII case-insensitively)"
    echo "oss: bone '$adr' already exists$have - one ADR ref keys one bone, and duplicate refs have no supported repair yet (#305); correct its surface with 'oss bone_set_touch <adr> <touch-csv>', or mint a new ref for a second decision" >&2; return 7; }
}

_oss_reg_uniq_gate() { # $1=state-file $2=payload about to be minted -> 0, or 7 if the name exists
  local name n
  name="$(printf '%s' "$2" | jq -r '.name')" || return 4
  n="$(_oss_reg_count "$1" '.risk_gates[] | select(.name == $v)' "risk gates" "$name")" || return $?
  [ "$n" -eq 0 ] || {
    echo "oss: risk gate '$name' already exists - one name keys one gate, and duplicate names have no supported repair yet (#305); correct its surface with 'oss risk_gate_set_touch <name> <touch-csv>', or choose a new name" >&2; return 7; }
}

oss_reg_add_bone() { # $1=state $2=adr-ref $3=title $4=touch-csv $5=revisit(optional)
  local sf="$1" touch
  touch="$(_oss_csv_to_json "$4")" || return $?
  _oss_reg_require_one_list "$touch" "touch list" "touch-csv" || return $?
  _oss_reg_refuse_contaminated "$touch" "touch list" \
    "a glob minted with surrounding whitespace or an invisible format character matches no real path, and touch_check then answers CLEAN on the code the bone was declared to cover" || return $?
  oss_state_mutate "$sf" add_bone \
    "$(jq -n --arg adr "$2" --arg t "$3" --argjson touch "$touch" \
        --arg rv "${5:-}" --arg ts "$(_oss_now)" \
      '{adr:$adr,title:$t,touch:$touch,revisit_trigger:(if $rv=="" then null else $rv end),at:$ts}')" \
    "" _oss_reg_uniq_bone
}

oss_reg_add_risk_gate() { # $1=state $2=name $3=touch-csv $4=controls-csv
  local sf="$1" touch c
  touch="$(_oss_csv_to_json "$3")" || return $?
  c="$(_oss_csv_to_json "$4")" || return $?
  _oss_reg_require_one_list "$touch" "touch list" "touch-csv" || return $?
  _oss_reg_refuse_contaminated "$touch" "touch list" \
    "a glob minted with surrounding whitespace or an invisible format character matches no real path, and touch_check then answers CLEAN on the code the gate was declared to cover" || return $?
  _oss_reg_require_one_list "$c" "controls list" "controls-csv" || return $?
  _oss_reg_refuse_contaminated "$c" "controls list" \
    "a control phrase with surrounding whitespace or an invisible format character is not the phrase the caller wrote" || return $?
  oss_state_mutate "$sf" add_risk_gate \
    "$(jq -n --arg n "$2" --argjson touch "$touch" \
        --argjson c "$c" --arg ts "$(_oss_now)" \
      '{name:$n,touch:$touch,controls:$c,at:$ts}')" \
    "" _oss_reg_uniq_gate
}

# Corrective append (#340): replaces a named gate's controls with a fresh
# journaled mutation — the journal is never edited, so replay stays
# authoritative and state_restore rebuilds the CORRECTED state. Duplicate
# gate names are #305's defect; this verb refuses rather than guessing.
oss_reg_set_risk_gate_controls() { # $1=state $2=name $3=controls-csv
  local sf="$1" name="$2" c
  _oss_reg_require_single "$sf" '.risk_gates[] | select(.name == $v)' \
    "risk gate" "risk gates" "gates" "duplicate names" "$name" || return $?
  c="$(_oss_csv_to_json "$3")" || return $?
  _oss_repoint_guard "$c" "controls list" "controls-csv" "control" \
    "a gate with no controls is a worry, not a gate (start/references/risk-gates.md §6)" \
    "a control phrase with surrounding whitespace is not the phrase the caller wrote" || return $?
  oss_state_mutate "$sf" set_risk_gate_controls \
    "$(jq -n --arg n "$name" --argjson c "$c" \
      '{name:$n,controls:$c}')"
}

# Corrective append for a touch surface (1.11.0, #469/#369/#411): replaces one
# bone's or gate's touch globs with a fresh journaled mutation, the same shape
# as set_controls above. When code moves, the registered globs match nothing
# and touch_check goes silently clean; this is the repair, run on a surface the
# caller has already established is stale. **Nothing here DETECTS a surface that
# matches no files** - the start-side references say so, and no verb, doctor
# sweep or README claims otherwise.
# A re-point to nothing is not a repair, so the payload is refused unless it
# carries at least one real glob (_oss_repoint_guard, above): `[]` would make
# touch_check clean on every path forever - the defect being repaired - and so
# would a lone blank entry, which the splitter turns "", "  ", " , " and a bare
# tab into. bone_add still admits an empty surface; the refusal belongs to the
# re-point, not to the registry.
oss_reg_set_bone_touch() { # $1=state $2=adr $3=touch-csv
  local sf="$1" adr="$2" touch
  _oss_reg_require_single "$sf" '.bones[] | select(.adr == $v)' \
    "bone" "bones" "bones" "duplicate ADR refs" "$adr" || return $?
  touch="$(_oss_csv_to_json "$3")" || return $?
  _oss_repoint_guard "$touch" "touch list" "touch-csv" "glob" \
    "a blank surface makes touch_check clean on every path" \
    "a glob with surrounding whitespace matches no real path - a CR kept by reading a CRLF file is the usual source" || return $?
  oss_state_mutate "$sf" set_bone_touch \
    "$(jq -n --arg a "$adr" --argjson t "$touch" '{adr:$a,touch:$t}')"
}

# 1.22.0 (#305 item 2): a bone's title and revisit trigger, amended in place.
# Same shape as oss_reg_set_bone_touch: one row resolved before the lock, a
# first()-targeted op. An empty trigger clears it to null, as bone_add records
# an absent one.
oss_reg_set_bone_title() { # $1=state $2=adr $3=title
  local sf="$1" adr="$2"
  _oss_reg_require_single "$sf" '.bones[] | select(.adr == $v)' \
    "bone" "bones" "bones" "duplicate ADR refs" "$adr" || return $?
  oss_state_mutate "$sf" set_bone_title \
    "$(jq -n --arg a "$adr" --arg t "$3" '{adr:$a,title:$t}')"
}

oss_reg_set_bone_revisit() { # $1=state $2=adr $3=revisit (""=clear)
  local sf="$1" adr="$2"
  _oss_reg_require_single "$sf" '.bones[] | select(.adr == $v)' \
    "bone" "bones" "bones" "duplicate ADR refs" "$adr" || return $?
  oss_state_mutate "$sf" set_bone_revisit \
    "$(jq -n --arg a "$adr" --arg rv "$3" '{adr:$a,revisit_trigger:(if $rv=="" then null else $rv end)}')"
}

oss_reg_set_risk_gate_touch() { # $1=state $2=name $3=touch-csv
  local sf="$1" name="$2" touch
  _oss_reg_require_single "$sf" '.risk_gates[] | select(.name == $v)' \
    "risk gate" "risk gates" "gates" "duplicate names" "$name" || return $?
  touch="$(_oss_csv_to_json "$3")" || return $?
  _oss_repoint_guard "$touch" "touch list" "touch-csv" "glob" \
    "a blank surface makes touch_check clean on every path" \
    "a glob with surrounding whitespace matches no real path - a CR kept by reading a CRLF file is the usual source" || return $?
  oss_state_mutate "$sf" set_risk_gate_touch \
    "$(jq -n --arg n "$name" --argjson t "$touch" '{name:$n,touch:$t}')"
}

# The fake ledger's key is `boundary`: fake_status matches on it and rewrites
# EVERY matching record, and expired_fakes reports each one. A second fake_add
# for one boundary minted a second record that neither verb can tell apart
# (#125), so the mint is refused here, as the bone and gate rails above refuse
# theirs - inside the lock, on the write path only, so replay of a journal that
# already holds a duplicate is unchanged. A boundary already in the ledger
# changes through fake_status: `renewed` when a later spine keeps the fake,
# `replaced` when it builds the real one (plan-spine's fake-ledger-discipline.md §1).
_oss_reg_uniq_fake() { # $1=state-file $2=payload about to be minted -> 0, or 7 if the boundary exists
  local b n
  b="$(printf '%s' "$2" | jq -r '.boundary')" || return 4
  n="$(_oss_reg_count "$1" '.fakes[] | select(.boundary == $v)' "fakes" "$b")" || return $?
  [ "$n" -eq 0 ] || {
    echo "oss: fake boundary '$b' is already in the ledger - one boundary keys one record, and fake_status rewrites every record it matches (#125); record a retained fake with 'oss fake_status $b renewed <reason> [new-expiry]', or a real replacement with 'oss fake_status $b replaced <reason>'" >&2; return 7; }
}

oss_reg_add_fake() { # $1=state $2=boundary $3=channel $4=reason $5=trigger $6=expiry-release
  case "$3" in real|fake|deferred) ;; *) echo "oss: channel must be real|fake|deferred" >&2; return 2;; esac
  oss_state_mutate "$1" add_fake \
    "$(jq -n --arg b "$2" --arg c "$3" --arg r "$4" --arg tr "$5" --arg ex "$6" --arg ts "$(_oss_now)" \
      '{boundary:$b,channel:$c,reason:$r,replacement_trigger:$tr,expiry_release:$ex,status:"active",at:$ts}')" \
    "" _oss_reg_uniq_fake
}

# $6 (1.23.0, #631): the intake issue this entry came from, so spine planning
# reads the request from the entry instead of matching titles. `N` or `#N`,
# normalised to the number N; empty or absent writes no `issue` key at all, so a
# journal written before 1.23.0 replays byte-identical. Anything else is refused
# at rc 2 before any write, and so is an issue on any source but `intake`: spine
# planning reads `issue` as the request's pointer.
oss_reg_add_feature() { # $1=state $2=name $3=value $4=class-guess $5=source [$6=intake-issue]
  local issue="${6:-}"
  issue="${issue#\#}"
  case "${6:-}" in
    "") ;;
    *)
      case "$issue" in
        ""|0*|*[!0-9]*)
          echo "oss: feature_add's intake issue must be a positive issue number (N, or '#N' quoted), got '$6'" >&2
          return 2 ;;
      esac
      [ "$5" = intake ] || {
        echo "oss: feature_add takes an intake issue only for source 'intake', got source '$5'" >&2
        return 2; } ;;
  esac
  oss_state_mutate "$1" add_feature \
    "$(jq -n --arg n "$2" --arg v "$3" --arg cg "$4" --arg s "$5" --arg i "$issue" --arg ts "$(_oss_now)" \
      '{name:$n,value:$v,class_guess:$cg,source:$s} + (if $i == "" then {} else {issue:($i|tonumber)} end) + {at:$ts}')"
}

# Touch-surface matching: bones/risk_gates store touch:[glob,...]. Matches
# each given path against every stored glob via bash `case` glob semantics
# (case-globs: `*` matches `/`, so `src/domain/**` matches any path under
# src/domain/ as a plain prefix-wildcard - not a real double-star). Prints
# `bone <adr>` / `risk_gate <name>` per match, rc 0 if any path matched any
# glob, rc 1 if clean. Dedup of repeated matches is deliberately not done in
# v1 (callers act on any-match, not on the match list).
# rc 2 = "could not check" and is NEVER folded into rc 1 = "clean". Every
# documented call site is `if oss touch_check …; then HIT; else CLEAN; fi`, so a
# failure that returned 1 classified an unreadable state as a genuine clean
# verdict — the mechanical half of class declaration degrading toward `flesh`,
# the permissive class, with no stdout and no stderr to say so. The blanket
# `2>/dev/null || true` that used to wrap both jq producers is exactly what
# erased that difference. A state without `.bones`/`.risk_gates` is malformed
# (doctor's shape check flags it) and is inconclusive here, not clean; an empty
# `[]` registry is well-formed and IS clean.
oss_reg_touch_check() { # $1=state $2..=paths ; rc 0 any match, 1 clean, 2 could-not-check
  local sf="$1"; shift
  [ "$#" -gt 0 ] || { echo "oss: touch_check needs at least one path" >&2; return 2; }
  local hit=1 path glob kind name bones_tsv gates_tsv
  bones_tsv="$(jq -r '.bones[] | . as $b | .touch[] | ["bone", $b.adr, .] | @tsv' "$sf" 2>/dev/null)" \
    || { echo "oss: cannot read bones from '$sf' - touch check is INCONCLUSIVE, not clean" >&2; return 2; }
  gates_tsv="$(jq -r '.risk_gates[] | . as $g | .touch[] | ["risk_gate", $g.name, .] | @tsv' "$sf" 2>/dev/null)" \
    || { echo "oss: cannot read risk_gates from '$sf' - touch check is INCONCLUSIVE, not clean" >&2; return 2; }
  while IFS=$'\t' read -r kind name glob; do
    [ -n "$glob" ] || continue
    for path in "$@"; do
      # shellcheck disable=SC2254
      case "$path" in $glob) echo "$kind $name"; hit=0;; esac
    done
  done < <(printf '%s\n%s\n' "$bones_tsv" "$gates_tsv")
  return "$hit"
}

# Release-close blocking gate (spec §6.1 fake ledger, §6.2 step 3). Returns the
# OUTSTANDING fakes that have reached or passed their expiry release.
#
# rc contract, and it is the OPPOSITE POLARITY to oss_reg_touch_check on
# purpose: 0 = CLEAN (the blocking set is empty), 1 = BLOCKING (non-empty, one
# TSV line per fake on stdout), 2 = could-not-check. touch_check answers "did
# anything match" (0 = hit); this answers "may the close proceed" (0 = yes), the
# same polarity as oss_verify_report_cross_check. A caller that copies the
# touch_check branch shape inverts the judge and closes exactly the releases it
# exists to block, so the ceremony's `case` arms are spelled out in
# skills/close/references/fake-expiry.md §2.
#
# Selector, both arms load-bearing:
#   * STATUS - `active` OR `renewed`. `replaced` is the ONLY resolving status
#     (the status enum in oss_reg_set_fake_status, below). Selecting on
#     `active` alone lets a renewal escape its
#     own deadline: someone already pushed that deadline once, which is what
#     makes the renewal the entry MOST in need of the check, and it would fail
#     silently green.
#   * EXPIRY - AT OR BEFORE this release, compared NUMERICALLY. Identity lets
#     every fake that outlived its deadline escape forever. A string compare is
#     wrong from r10 on: jq evaluates `"r2" <= "r10"` as false, so the `r` is
#     stripped and the remainder compared as a number.
#
# A record whose `expiry_release` cannot be parsed as `r<N>` BLOCKS, marked
# `unparseable-expiry`. It is not skipped: an expiry that never compares is an
# expiry that never fires, which is precisely "deferred truth becomes permanent
# silently". `try/catch` keeps the malformed value from aborting the whole
# selector, so one bad record cannot make every other fake escape with it.
#
# The release argument is validated for SHAPE only, never for existence: this is
# a read-only selector whose release id reaches it from `oss id_parse`, and an
# existence check would add an rc-7 arm the ceremony has no branch for.
oss_reg_expired_fakes() { # $1=state $2=release ; rc 0 clean, 1 blocking, 2 could-not-check
  local sf="$1" rel="$2" out
  case "${rel#r}" in ''|*[!0-9]*)
    echo "oss: expired_fakes needs a release id of the form r<N> (got '$rel')" >&2; return 2 ;; esac
  out="$(jq -r --arg rel "$rel" '
      ($rel | ltrimstr("r") | tonumber) as $cut
      | .fakes[]
      | select(.status == "active" or .status == "renewed")
      | . as $f
      | (try (.expiry_release | ltrimstr("r") | tonumber) catch null) as $e
      | select($e == null or $e <= $cut)
      | [ $f.boundary,
          $f.status,
          (if $e == null then "unparseable-expiry" else $f.expiry_release end),
          ($f.replacement_trigger // "") ] | @tsv' "$sf" 2>/dev/null)" \
    || { echo "oss: cannot read fakes from '$sf' - the expiry gate is INCONCLUSIVE, not clean" >&2; return 2; }
  [ -n "$out" ] || return 0
  printf '%s\n' "$out"
  return 1
}

oss_reg_set_fake_status() { # $1=state $2=boundary $3=status $4=reason [$5=new-expiry]
  local sf="$1" b="$2" st="$3"
  case "$st" in active|replaced|renewed) ;; *)
    echo "oss: fake status must be active|replaced|renewed" >&2; return 2;; esac
  jq -e --arg b "$b" '.fakes[] | select(.boundary == $b)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown fake boundary '$b'" >&2; return 7; }
  oss_state_mutate "$sf" set_fake_status \
    "$(jq -n --arg b "$b" --arg st "$st" --arg r "$4" --arg ex "${5:-}" --arg ts "$(_oss_now)" \
      '{boundary:$b,status:$st,reason:$r,expiry:$ex,at:$ts}')"
}
