#!/usr/bin/env bash
# crew test helpers — sourced by every suite in this directory.
#
# Three plugins in this marketplace — remodel, merge-bar and this one — keep
# the colour setup, pass/fail and the report line in a `_helpers.sh` rather than one copy per
# suite; the other plugins' `_helpers.sh` carry a different set of primitives
# (`assert_*` and temp helpers). This follows the first shape rather than inventing
# a third one.
#
# The literal counters and the pin/present wrappers live here for a different
# reason (#514, L1): this plugin had grown four definitions of one awk loop across
# the suites plus three more inline in test-config-contract.sh, and one of the four
# had already lost the `[ -f ]` guard the other three carry — which is what a copy
# does when nothing asserts the shape. Measured when this was written: no sibling
# `_helpers.sh` in this marketplace defines them, so this is the first hoist of its
# kind here rather than a house shape.

PASS=0
FAIL=0

if [ -t 1 ]; then
  GREEN=$(printf '\033[32m'); RED=$(printf '\033[31m'); DIM=$(printf '\033[2m'); RST=$(printf '\033[0m')
else
  GREEN=""; RED=""; DIM=""; RST=""
fi

pass() { PASS=$((PASS+1)); printf '  %s✓%s %s\n' "$GREEN" "$RST" "$1"; }

fail() {
  FAIL=$((FAIL+1))
  printf '  %s✗%s %s\n' "$RED" "$RST" "$1"
  [ -n "${2:-}" ] && printf '      %s%s%s\n' "$DIM" "$2" "$RST"
  return 0
}

section() { printf '\n%s%s%s\n' "$DIM" "── $1 ──" "$RST"; }

report() {
  # The structural half runs once more here, after the suite body: a definition made after the
  # suite asked assert_hoisted_counters — or a suite that never asks — is caught by this call and
  # by nothing else. Measured before it existed: a `pin() ( : )` inserted immediately before this
  # call left the suite reporting clean (#602 review round 2, finding 4).
  # The caller is read once, guarded, for the label: a shell that calls report
  # with no caller frame at all has no BASH_SOURCE[1], and an unguarded read
  # aborts under set -u instead of reporting (#602 F7).
  _caller="${BASH_SOURCE[1]:-}"
  hoisted_definitions_intact "no hoisted counter was redefined while ${_caller##*/} ran"
  printf '\n%s──%s %d passed, %d failed\n' "$DIM" "$RST" "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ] || return 1
  return 0
}

# ── literal counting ────────────────────────────────────────────────────────
#
# One loop, one definition, four joins. index() is a LITERAL substring test, so
# it is NOT equivalent to grep -E, grep -w or grep -x; every counter below is
# literal on purpose. `grep -c` counts matching LINES rather than occurrences, so
# it cannot see a duplicate on one line, and `… | grep -q` in a pipeline can fail
# on a true match under pipefail.
#
# An empty needle is REFUSED, not counted: index(line, "") always returns 1 and
# substr(line, 1) returns the whole line, so the loop never advances — the count
# climbs forever and the suite hangs instead of failing.
count_literal() { # <needle> — the text to search arrives on stdin
  if [ -z "${1:-}" ]; then printf 'empty needle\n' >&2; return 1; fi
  awk -v needle="$1" '
    { line = $0
      while ((i = index(line, needle)) > 0) { n++; line = substr(line, i + length(needle)) } }
    END { print n+0 }'
}

# Occurrences of a literal substring, counted PER LINE: a needle that spans a
# markdown line wrap reads as absent rather than as present, so a passing pin is
# provably on one line. A file that cannot be opened is REFUSED rather than
# counted — a count is what a clean file returns, so returning 0 for a file
# nobody opened would certify it.
occurrences() { # <file> <needle>
  if [ -z "${2:-}" ]; then printf 'empty needle\n' >&2; return 1; fi
  [ -f "${1:-}" ] || { printf 'no such file: %s\n' "${1:-}" >&2; return 1; }
  count_literal "$2" < "$1"
}

# Occurrences in the file read as ONE logical line: every whitespace run is
# squeezed to a single space first, which reassembles the space a markdown wrap
# broke at. `pin` counts per line, which is right for its pins; this counter is
# for a pin whose SUBJECT is a phrase a restatement may break anywhere, where a
# per-line count would report "defined once" for a file that defines the phrase
# twice, wrapped differently. Note the join is by SQUEEZING, not by deleting the
# newline: the phrase's words are separated by the very space the wrap consumed.
# (A name is space-less, so the config suite's personal-name sweep deletes
# newlines instead — it funnels through count_literal for the loop, not this.)
#
# Two bounds come with that join, both accepted: an ABSENCE pin over a squeezed
# line also catches a reintroduction that wraps differently, which a per-line pin
# would miss; and a false POSITIVE needs the surrounding prose to spell the needle
# across a line boundary, which a restatement does and arbitrary text does not.
#
# The join is CAPTURED, not piped. A pipeline's status is its LAST command's, and
# count_literal succeeds on empty input — so an awk that could not open the file
# (an existing but unreadable one, which the `[ -f ]` guard above lets through)
# came back as `0` with rc=0, and a flat ABSENCE check certified a file nobody
# read. Capturing makes awk's failure this function's failure.
occurrences_flat() { # <file> <needle>
  if [ -z "${2:-}" ]; then printf 'empty needle\n' >&2; return 1; fi
  [ -f "${1:-}" ] || { printf 'no such file: %s\n' "${1:-}" >&2; return 1; }
  _flat="$(awk '{ buf = buf " " $0 }
    END { gsub(/[[:space:]]+/, " ", buf); print buf }' "$1")" || {
    printf 'cannot read: %s\n' "${1:-}" >&2; return 1; }
  printf '%s\n' "$_flat" | count_literal "$2"
}

count_of() { # <file> <needle> [line|flat]
  if [ "${3:-line}" = flat ]; then occurrences_flat "$1" "$2"; else occurrences "$1" "$2"; fi
}

# pin <file> <needle> <label> [line|flat] — the needle must occur EXACTLY once.
# The zero-count message is MODE-AWARE. Per line, a wrap is the common way a pin
# that is still true stops being counted, so it names that. In flat mode the join
# squeezes every whitespace run, so a wrap cannot be the cause of a zero — naming
# one there would send the investigator after a phantom.
pin() {
  c="$(count_of "$1" "$2" "${4:-line}")" || { fail "$3" "unreadable file or empty needle: $1"; return 0; }
  if [ "$c" -eq 1 ]; then pass "$3"
  elif [ "$c" -eq 0 ]; then
    if [ "${4:-line}" = flat ]; then
      fail "$3" "not found in ${1##*/}, however it wraps — the flat count squeezes every whitespace run, so this is a reworded-away clause, not a wrap. pin: $2"
    else
      fail "$3" "not found in ${1##*/} — reworded away, or the pin now spans a line wrap. pin: $2"
    fi
  else fail "$3" "found $c times in ${1##*/}; a pin must be unique. pin: $2"
  fi
}

# present <file> <needle> <label> [line|flat] — at least once.
present() {
  c="$(count_of "$1" "$2" "${4:-line}")" || { fail "$3" "unreadable file or empty needle: $1"; return 0; }
  if [ "$c" -ge 1 ]; then pass "$3"; else fail "$3" "not found in ${1##*/}: $2"; fi
}

# ── the hoisted definitions cannot be re-copied silently ────────────────────
#
# A suite-local definition SHADOWS the one above: every assertion that calls it
# keeps passing, so a re-copied loop is invisible until the day it drifts — which
# is how the fourth copy lost its guard. Two halves assert the shape, split by
# whose answer can differ:
#
#   assert_hoisted_counters  THIS suite, so it stays with the caller: its own file
#                            read by one awk pass for the counts, and the definitions
#                            bash resolved in the running shell compared against the
#                            ones this file loaded (the half spelling cannot fool)
#   assert_hoist_shape       the whole directory, whose answer cannot differ
#                            between callers, so it is called ONCE per full run
#                            rather than repeating the same violation three times
#
HOISTED_FNS="count_literal occurrences occurrences_flat count_of pin present"

# Definitions of any of <fn>... that OPEN a function in <file>, as
# "<total> [<fn> <count>]..." on one line — never empty on a successful read, so an
# empty result is a FAILED READ and not a clean file. That distinction is the whole
# point: an unreadable file used to yield an empty count whose arithmetic error read
# as "no copies here", skipping the file in silence.
#
# One awk pass decides it by this rule: at the START of a logical line — indentation
# aside — a NAME followed by `()`, every whitespace run around and inside the parens
# allowed to be a run of any length (`pin ( ) {` and `pin<TAB>()<TAB>{` are the same
# rule as `pin() {`), and a `{` group opening on that line or on the first line of code
# after it — blank and comment-only lines in between change nothing; or the `function`
# keyword followed by the name, with or without a body after it, a direction that
# over-counts and is the fail-closed one for a gate. Every spelling below is one that
# rule counts. A shadow does not have to look like the copy it shadows, so each was
# measured TWICE: `bash -n` accepts the fixture, and a bash that sources it defines the
# function — `declare -F` finds it. The second half is not ceremony: `bash -n` alone does
# not establish the first, and `function "pin" {` is the proof — accepted by `bash -n`,
# defines nothing.
#
#   pin() {     pin () {     pin<TAB>()<TAB>{     function pin {     function pin() {
#   function pin () {        <indented>           (any of the above)
#   pin()       + `{` on the next line, with any run of blank and comment-only lines
#               between the two
#   pin () # copied locally   + `{` on the next line
#   pin ( ) {                a whitespace RUN inside the parens, not one space exactly:
#                            `pin<TAB>(<TAB>)<TAB>{` is the same spelling
#   pin () \                 a signature split with a backslash-newline — bash removes the
#     {                      pair before it parses, so where the split falls changes
#                            nothing: between the signature and the brace, between the
#                            name and the parens (`pin \` + `() {`), inside the name
#                            (`pi\` + `n() {`) are one rule, one fixture each
#
# Each spelling here has its own fixture among test-config-contract.sh's spelling
# controls; a spelling listed without one is the same defect as a control that stops
# matching. The reverse is NOT claimed: this is a list of what the rule above counts, not
# a list of every spelling bash accepts. bash accepts more, and those belong to the other
# half, below.
#
# Heredoc bodies are scanned as code (#603). A body line must then not hide the lines
# after it. The one way it could: a heredoc terminator that ends in `\` is not joined by
# bash, but a text join carries it onto the next line and pushes a definition there off
# its line start (measured: bash's `declare -f` copy of `pin` after `END\`, and a split
# signature after one or two such chains, each counted 0 under a plain join; #603 pre-PR
# review B1, PR #1241 round 1 C1 and fresh round 1 C1). So the join pass reads each joined
# run from every one of its lines and carries every name any reading leaves waiting (see
# `scan_runs`): whichever line bash really starts the join at, one reading starts there,
# so removing the skip only raises counts (measured against origin/main's skip on the two
# review rounds' 29,000 generated files: none counts lower). The stated bound: a heredoc fixture
# whose body starts a line with a definition of a hoisted name reads as a shadow — a loud
# false RED. Write such fixtures with printf instead.
#
# WHICH HALF OWNS WHAT. This pass owns the COUNT — the exact per-name counts the
# spelling controls' `1 pin 1` assert, which a structural answer cannot express:
# bash reports that a name is defined, never how many times. What it does not own
# is SPELLING, and it never did: bash takes ANY compound command as a body and a
# definition may start anywhere a command may, so `pin() ( : )` and `if true; then pin() { :; }; fi`
# are real definitions this scan counts 0. Since #598/#600 that is `assert_hoisted_counters`'
# other half: it compares the definition bash RESOLVED against the one this file loaded, so a
# copy is caught whatever its body form, wherever its line starts, and even when the source
# never spells it as a definition at all — measured, `eval "pin() { :; }"` is counted 0 here
# and caught there. Every one of those spellings has a control beside the #598/#600 controls,
# each exercised through that half.
#
# THE BOUND THAT REMAINS for missed shadows: a copy that is byte-identical in bash's own rendering
# AND does not start its line. This pass is blind to it by the line anchor, and the structural
# half is blind by construction — an identical definition is not a different one. Measured in
# both directions on a copy built from `declare -f`: verbatim, both halves report the suite
# clean; with ONE body line dropped — the shape the four pre-hoist copies took when one of them
# lost its `[ -f ]` guard (this file's header) — this pass still counts 0 while the structural
# half reports drift. A copy cannot drift unnoticed, which is the day the bound stops being
# harmless. Both are controls.
#
# The join is the one bash performs on an UNQUOTED backslash-newline. This scan reads
# text, not a parse tree, so it also joins one inside a single-quoted string, where bash
# keeps it. The counting rule above stays quote-blind and this pass changed nothing about
# that: measured, a `pin() {` starting a line inside a multi-line quoted string still
# counts 1. Heredoc bodies follow the same quote-blind rule.
#
# A CALL (`pin "$REF" ...`), a COMMENT (`# pin() { ...`) and a bare `name()` with no
# body after it (`pin()` + `foo=1`, which bash rejects) are not definitions: that is why
# the parens, the brace or the `function` keyword are required, and why a bare `name()`
# only counts when the first line of code after it opens a BRACE GROUP — the one body form
# this text pass recognizes. The structural half above is not restricted to it.
count_shadows() { # <file> <fn>...
  awk -v names="$*" '
    BEGIN { n = split(names, a, " "); for (i = 1; i <= n; i++) want[a[i]] = 1 }
    # What one line of code is, for this rule: "blank" (empty, or a comment only), "brace"
    # (it opens a `{` group), "def <name>" (a definition opening here: the `function`
    # keyword, or `name()` with its `{` on this line), "wait <name>" (a bare `name()` whose
    # `{` must come on the next line of code), or "other".
    function kind(code,   name) {
      sub(/^[[:space:]]+/, "", code)          # an indented definition is a definition
      sub(/[[:space:]]*#.*$/, "", code)       # a trailing comment is not code
      sub(/[[:space:]]+$/, "", code)
      if (code == "") return "blank"
      if (code ~ /^\{/) return "brace"
      if (code ~ /^function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
        name = code; sub(/^function[[:space:]]+/, "", name); sub(/[^A-Za-z0-9_].*$/, "", name)
        return "def " name
      }
      if (code ~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([[:space:]]*\)[[:space:]]*\{/) {
        name = code; sub(/[[:space:]]*\(.*$/, "", name)
        return "def " name
      }
      if (code ~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([[:space:]]*\)[[:space:]]*$/) {
        name = code; sub(/[[:space:]]*\([[:space:]]*\)[[:space:]]*$/, "", name)
        return "wait " name
      }
      return "other"
    }
    # The backslash-newline join. A run is lines f..m where every line before m
    # ends in `\` (a file that ends in `\` ends its run too). bash joins a run from the
    # line after the last heredoc terminator inside it, which this scan does not locate,
    # so it reads every suffix of the run — from each of its lines — as one view, and
    # carries the SET of names any view leaves waiting into the next run. A name counts
    # once per run when any view defines it, or opens a brace while it waits.
    function scan_runs(   r, d, k, line, piece, nm, anyblank, got, nw, w) {
      split("", w)
      for (r = 1; r <= nr; r++) {
        split("", got); split("", nw); anyblank = 0
        for (d = RF[r]; d <= RM[r]; d++) {
          line = ""
          for (k = d; k <= RM[r]; k++) { piece = L[k]; sub(/\\$/, "", piece); line = line piece }
          k = kind(line)
          if (k == "blank") { anyblank = 1; continue }
          if (k == "brace") { for (nm in w) got[nm] = 1; continue }
          if (k ~ /^def /) got[substr(k, 5)] = 1
          else if (k ~ /^wait /) nw[substr(k, 6)] = 1
        }
        for (nm in got) if (nm in want) hits[nm]++
        if (!anyblank) split("", w)            # a blank view keeps bash waiting; no blank view, no wait survives
        for (nm in nw) w[nm] = 1
      }
    }
    { L[++nl] = $0 }
    END {
      nr = 0
      for (i = 1; i <= nl; i++) {
        f = i
        while (i < nl && L[i] ~ /\\$/) i++
        RF[++nr] = f; RM[nr] = i
      }
      scan_runs()
      total = 0; tail = ""
      for (i = 1; i <= n; i++) if (a[i] in hits) { total += hits[a[i]]; tail = tail " " a[i] " " hits[a[i]] }
      print total tail
    }' "$1"
}

# The hoisted definitions as BASH holds them, one entry per name in HOISTED_FNS order,
# captured when this file is sourced. assert_hoisted_counters compares each live definition
# against its entry: a definition is a definition whatever its body form and wherever on the
# line it starts, so this half is blind to spelling by construction. Both sides come from the
# same bash process, so no version skew can make an unchanged definition look drifted.
HOISTED_DEF=()
for _fn in $HOISTED_FNS; do HOISTED_DEF[${#HOISTED_DEF[@]}]="$(declare -f "$_fn")"; done

# The definitions bash RESOLVED in this shell against the ones this file loaded, as a pass or a
# fail under <label>. Two callers, and the split is the whole point: assert_hoisted_counters
# decides a suite where the suite asks, and report decides it again after the whole body has run,
# so a shadow introduced in between is caught by the second even when the first saw a clean shell.
hoisted_definitions_intact() { # <label>
  _i=0; _drift=""
  for _fn in $HOISTED_FNS; do
    [ "$(declare -f "$_fn")" = "${HOISTED_DEF[_i]}" ] || _drift="$_drift $_fn"
    _i=$((_i + 1))
  done
  if [ -z "$_drift" ]; then
    pass "$1"
  else
    fail "$1" \
      "bash holds a different definition of:$_drift — a local definition shadows the one _helpers.sh loaded, spelled in a way the line-anchored text scan cannot count"
  fi
}

# This suite's own file, from the caller that is running it. Cheap by design.
assert_hoisted_counters() {
  _self="${BASH_SOURCE[1]:-}"
  _shadows="$(count_shadows "$_self" $HOISTED_FNS)"
  if [ -z "$_shadows" ]; then
    fail "the shape scan ran over ${_self##*/}" \
      "it returned nothing — a read that failed would certify the file in silence"
  elif [ "$_shadows" = 0 ]; then
    pass "no copy of a hoisted counter in ${_self##*/}"
  else
    fail "no copy of a hoisted counter in ${_self##*/}" \
      "$_shadows — a local definition shadows the one in _helpers.sh, and every assertion that calls it keeps passing"
  fi
  # The other half of the same claim, and the one that cannot be fooled by spelling: bash
  # resolves the definition, and this compares what it resolved against what this file
  # defined. The subject is the RUNNING SHELL — this suite — not a file, so a definition
  # built by `eval`, by a command substitution or by a sourced file is caught here and is
  # unreachable from the text pass above. The text pass stays the half that owns the counts;
  # this one owns spelling, and neither substitutes for the other. It sees the shell as of THIS
  # call, which is why report calls the same comparison again at the end.
  hoisted_definitions_intact "the hoisted counters are the ones bash resolved in ${_self##*/}"
}

# The whole directory, called once per full run. The optional directory exists
# for the controls, which plant a fixture tree.
assert_hoist_shape() { # [directory]
  _dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
  _copies=0
  for _suite in "$_dir"/test-*.sh; do
    _rel="${_suite##*/}"
    if [ ! -r "$_suite" ]; then
      _copies=$((_copies + 1))
      fail "every suite is readable" \
        "$_rel cannot be read — its definitions cannot be checked, and skipping it would certify nothing about it"
      continue
    fi
    _shadows="$(count_shadows "$_suite" $HOISTED_FNS)"
    if [ -z "$_shadows" ]; then
      _copies=$((_copies + 1))
      fail "the shape scan ran over $_rel" \
        "it returned nothing — a read that failed would be skipped in silence"
    elif [ "$_shadows" != 0 ]; then
      _copies=$((_copies + 1))
      fail "no copy of a hoisted counter in $_rel" \
        "$_shadows — the shared definition in _helpers.sh is the only one"
    fi
  done
  [ "$_copies" -ne 0 ] || pass "no suite re-defines a hoisted counter"

}

# Ruby + Psych is how this repo parses YAML — tests/test-codex-dual-publish.sh
# established it, because Codex's own loader is Psych and a check that parses
# YAML some other way is not checking what will actually load the file.
# Preflight it so a missing toolchain fails loudly instead of looking like a
# parse error in the file under test.
require_ruby_psych() {
  RUBY_BIN="$(command -v ruby || true)"
  if [ -z "$RUBY_BIN" ] || ! "$RUBY_BIN" -e 'require "psych"' >/dev/null 2>&1; then
    fail "ruby + Psych available on PATH" "cannot validate YAML without the parser the loader uses"
    return 1
  fi
  return 0
}
