#!/usr/bin/env bash
#
# crew — every launch-verb site in the shipped prose carries a seat-mods
# marking clause (#663).
#
# WHAT THIS GUARDS. The seat-mods marking (a guarded role + `SEAT_MODS_ALLOW`, or
# `coordinator`, or `orchestrator`) is stated in prose at every launch site, by
# reference to the layer's Seat launch. Pinned suites catch a site that LOSES its
# clause; nothing caught a NEW launch site added without one. This suite selects the
# launch sites by the rule below and fails when a selected site's own region carries
# no marking clause — the #651 recurrence shape.
#
# THE SITE RULE (A2). A *region* is a markdown list item (its marker line through its
# deeper-indented continuation lines) when the text sits in one, else a
# blank-line-delimited paragraph. YAML frontmatter (a region starting at line 1 with
# `---`) and heading lines are skipped. `**` spans are stripped and whitespace is
# squeezed before matching, so a bold verb or article still selects. A region is a
# launch site when its stripped text matches any of:
#
#   1. `herdr tab create`
#   2. `herdr worktree create` with `--path` in the same region (the flag that names
#      the seat's new tree; a bare mention that defers its flags elsewhere is not one)
#   3. `herdr workspace create` with no `run:` in the region (the run's own workspace
#      is not a seat launch)
#   4. `launch(ed|es|ing)? {a|an|the|its|each|every|from|as|it|to|at} <0-40 chars,
#      sentence- and paren-bounded> seat(s)` — "launched from the project file's
#      close-session seat", "Launch it as the seat launch", "launches each writer as a
#      guarded seat", the `SEATS row(s)` spellings included
#   5. `launch(ed|es|ing)? from {those|them|these}`
#   6. `{launch(es|ed)?|dispatch(es|ed)?|create[sd]?|respawn(s|ed)?} [det] {fresh|new}
#      <0-20 chars, sentence- and paren-bounded> {seat(s)|pair|implementer|verifier|
#      reviewer|writer|spine session|work-PR session|close session|doctor session}`
#   7. `{fresh|new} <0-20> {seat(s)|pair} <0-20> {you create|you dispatch|you launch|
#      you spawn|to resume}`
#   8. `respawn`
# Initial capitals also match in patterns 4–6 and 8, with the same inflections.
#
# A site carries a marking clause when its own region contains any of:
# `SEAT_MODS_ROLE=`, `guarded`, `coordinator`, `orchestrator`, `step 2`, `Seat marking`.
# Tokens have no adjacent letter, digit or `_`; `SEAT_MODS_ROLE=` ends at `=`.
#
# COVERED: the three placement commands; "launch(ed) from the … seat"; "launch
# a/the/its … [fresh|new] seat|pair|…" including bold verbs and articles and the
# create/dispatch/respawn verb forms, the close-session and doctor-session nouns
# included; "launched from the … SEATS row(s)"; "every respawn … is launched from the
# same row"; "a fresh seat you create"; "a fresh seat to resume"; bare `respawn`.
#
# NOT COVERED — a new site in one of these shapes still passes, and that residual is
# accepted (naming it is the point): the bare noun "the seat launch" (it collides with
# SKILL.md §1's router sentence, which is a pointer and needs no clause); "launched at
# its point or on demand" (operator roles); a marking directive with no launch verb
# ("Mark it `coordinator` before its command", "is a guarded `implementer`"); router and
# depth descriptions ("drives a fresh tab and pane per item seat", "launches item
# sessions of its own", "launched by seat name", "start one spine session"); "create …
# from its … row" (the reviewer-row instruction, clause-carrying where it stands); a
# dispatch whose command string intervenes before the fresh noun ("dispatch
# `/ossify:close <spine-id>` to a fresh close session", SKILL.md:156 — clause-carrying
# where it stands); the elided noun "a/the fresh close" (`ossify-nested-run.md:182`,
# `ossify-close-writer.md:20` — clause-less asides whose governing launch carries its
# clause); a pronoun or preposition between the verb and the noun, "dispatch it/to a
# fresh close session" (`ossify-briefs.md:110`, `:129` — clause-less asides, and not the
# command-string shape above: no command intervenes, and selecting them would fail
# clause-less prose); a launch sentence directly under a heading with no blank line (it
# merges into the heading's region and is dropped); frontmatter whose `---` has no blank
# line after it (the skip takes the body's first region with it); a nested list item
# consumed into its parent region, where a parent's or sibling's clause satisfies an
# unmarked nested launch; a tab after a list marker (`-\t…`) not recognized as a marker,
# so adjacent items merge into one region; headings and frontmatter.
#
# CLAUSE-SIDE LOOSENING, stated: any bare mention of the clause tokens in the region
# satisfies the check (e.g. a site beside the words "the coordinator seats" passes
# without stating the marking), and `step 2` is also lifecycle's own step 2 — a site
# next to such a mention passes. That direction is deliberate: it keeps today's correct
# sites green, and test-ossify-spine-contract.sh's one-pin-per-site block holds every
# clause text the shipped prose states.
#
# FENCE BLINDNESS, stated: the scanner does not model ``` fences — a fenced template's
# prose is scanned like any paragraph. Today's green there is for the right reason (the
# spine brief's item steps carry their real guard clauses), but a template-only reword
# is judged on its own text, not on its role as a template.
#
# CONTROLS, beside the assertions they protect:
#   - B2 (red/green): a fixture copy of the shipped tree with ONE added unmarked
#     launch site must fail, naming file, line and the site text; the same site with a
#     clause must pass. The fixture lives under mktemp, never in a shipped file.
#   - bold spans: fixture paragraphs with a bold article and with a bold verb must each
#     be selected — the "bold" half of the COVERED claim above, measured.
#   - B4 (floor): the number of sites selected is printed and pinned at today's count;
#     a grammar change that silently selects fewer sites fails. Its adjacent control is
#     a fixture the same predicate must refuse: a tree below the floor is not accepted.
#     The floor is a SUMMED total, so a net-zero grammar swap (one pattern dropped, one
#     added) keeps it — the per-pattern coverage rests on the controls here.
#   - per-file death: a scanned path whose own scan dies must print SCAN-ERROR and fail
#     the run, not vanish behind the other files' counts.
#   - #721: whole-word clauses and adjacent real clauses; lowercase/initial-capital
#     verbs and inflections; second-line verb locations; failed find traversal and
#     an adjacent complete traversal.
#
# Usage: bash crew/tests/test-launch-site-marking.sh
# Env:   HERDR_CREW_PROSE_ROOT=<dir>  scan that tree instead of the plugin's — the
#        red/green runs above use it; the suite's own controls always build their own
#        fixtures.
# Deps:  bash 3.2+, awk with ERE interval expressions (`{m,n}` — gawk, or mawk 1.3.4+;
#        an older mawk fails the scan), mktemp.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCAN_ROOT="${HERDR_CREW_PROSE_ROOT:-$PLUGIN_ROOT}"

# 26 — measured on the tree this suite ships with (2026-10-09, #663 fix round 1): the
# count the A2 rule selects after the close-session and doctor-session nouns joined
# pattern 6 (ossify-nested-run.md's re-dispatched close and ossify-pr-briefs.md's NEVER
# aside) and after roles.md's activated-spine rows, ossify-briefs.md's item-verifier
# intro and ossify-execution.md's resumed top carry their citing clauses. A grammar
# change that selects fewer must fail the floor below; adding sites raises this constant
# deliberately.
SITE_FLOOR=26

# shellcheck source=/dev/null
. "$SCRIPT_DIR/_helpers.sh"

# ── the check ────────────────────────────────────────────────────────────────
#
# Reads every .md under <root>/skills/** and <root>/commands/** — crew's shipped
# prose — and prints, one per line:
#   FAIL <file>:<line> [<site kind>] :: <site text>   for each selected site with no clause
#   SITES <n>                            the number of sites that file selected
#   SCAN-ERROR <path>: <reason>          a path whose scan did not finish
# `line` is the first line of the region that itself carries a launch token, so the
# pointer lands on the sentence, not the paragraph's first line; `site kind` is the
# pattern that selected the region; the printed site text is the whole joined region
# with `**` stripped, capped at 400 characters. A file with no `SITES` line is a failed
# scan, never a clean one, and the caller refuses any `SCAN-ERROR`.
scan_launch_sites() { # <root>
  _root="${1:-}"
  if [ ! -d "$_root/skills" ] || [ ! -d "$_root/commands" ]; then
    printf 'SCAN-ERROR %s: needs skills/ and commands/ directories\n' "$_root"
    return 0
  fi
  # Capture find before sorting: a successful sort cannot certify a partial walk.
  if _files="$(find "$_root/skills" "$_root/commands" -name '*.md')"; then
    :
  else
    _find_status=$?
    printf 'SCAN-ERROR %s: find exited %s — skills/ or commands/ traversal did not finish\n' "$_root" "$_find_status"
    return 0
  fi
  _files="$(printf '%s\n' "$_files" | sort)"
  if [ -z "$_files" ]; then
    printf 'SCAN-ERROR %s: no .md files under skills/ or commands/\n' "$_root"
    return 0
  fi
  printf '%s\n' "$_files" | while IFS= read -r _f; do
    if [ ! -f "$_f" ] || [ ! -r "$_f" ]; then
      printf 'SCAN-ERROR %s: not a readable regular file — its scan cannot run\n' "$_f"
      continue
    fi
    _out="$(awk -v file="$_f" '
      function indent(s,   n) { n = 0; while (substr(s, n+1, 1) == " ") n++; return n }
      function is_marker(s,   t) {
        t = s; sub(/^ +/, "", t)
        return (t ~ /^[-*+] / || t ~ /^[0-9]+[.)] /)
      }
      function is_heading(s,   t) { t = s; sub(/^ +/, "", t); return t ~ /^#+ / }
      # The A2 site predicate on the region text (whitespace squeezed, `**` stripped).
      # Returns the matched pattern names, space-separated, "" when the region is not a
      # site — the names become the FAIL line'"'"'s site kind.
      function site_why(region,   w) {
        w = ""
        if (region ~ /herdr tab create/) w = w " tab-create"
        if (region ~ /herdr worktree create/ && region ~ /--path/) w = w " worktree-create"
        if (region ~ /herdr workspace create/ && region !~ /run:/) w = w " workspace-create"
        if (region ~ /[Ll]aunch(ed|es|ing)?[[:space:]]+(a|an|the|its|each|every|from|as|it|to|at)[[:space:]][^.;()]{0,40}[Ss][Ee][Aa][Tt][Ss]?([^A-Za-z]|$)/) w = w " launch-from-seat"
        if (region ~ /[Ll]aunch(ed|es|ing)? from (those|them|these)([^A-Za-z]|$)/) w = w " launch-from-those"
        if (region ~ /([Ll]aunch(es|ed)?|[Dd]ispatch(es|ed)?|[Cc]reate[sd]?|[Rr]espawn(s|ed)?)[[:space:]]+((a|an|the|its|their|another)[[:space:]]+|(that|the) item.s[[:space:]]+)?(fresh|new)([^A-Za-z]|$)[^.;()]{0,20}([Ss][Ee][Aa][Tt][Ss]?([^A-Za-z]|$)|pair([^A-Za-z]|$)|implementer|verifier|reviewer|writer|spine session|work-PR session|close session|doctor session)/) w = w " fresh-seat"
        if (region ~ /(fresh|new)[^.;()]{0,20}([Ss][Ee][Aa][Tt][Ss]?([^A-Za-z]|$)|pair([^A-Za-z]|$))[^.;()]{0,20}(you (create|dispatch|launch|spawn)|to resume)/) w = w " fresh-seat-verb"
        if (region ~ /[Rr]espawn/) w = w " respawn"
        return w
      }
      # The clause forms, tried in order, with no letter, digit or underscore at a
      # word edge (ROLE= ends at the equals sign); "" is the failure reported below.
      function clause_kind(region) {
        if (region ~ /(^|[^[:alnum:]_])SEAT_MODS_ROLE=/) return "SEAT_MODS_ROLE"
        if (region ~ /(^|[^[:alnum:]_])guarded([^[:alnum:]_]|$)/) return "guarded"
        if (region ~ /(^|[^[:alnum:]_])coordinator([^[:alnum:]_]|$)/) return "coordinator"
        if (region ~ /(^|[^[:alnum:]_])orchestrator([^[:alnum:]_]|$)/) return "orchestrator"
        if (region ~ /(^|[^[:alnum:]_])step 2([^[:alnum:]_]|$)/) return "step 2"
        if (region ~ /(^|[^[:alnum:]_])Seat marking([^[:alnum:]_]|$)/) return "Seat marking"
        return ""
      }
      function emit(a, b,   k, region, line, text, why) {
        region = ""
        for (k = a; k <= b; k++) region = region " " L[k]
        gsub(/[[:space:]]+/, " ", region)
        gsub(/\*\*/, "", region)
        sub(/^ /, "", region)
        if (is_heading(L[a])) return
        if (a == 1 && L[1] == "---") return
        why = site_why(region)
        if (why == "") return
        sites++
        if (clause_kind(region) != "") return
        line = a
        for (k = a; k <= b; k++) {
          if (L[k] ~ /[Ll]aunch|[Dd]ispatch|[Cc]reate|[Rr]espawn/ || L[k] ~ /herdr (tab|worktree|workspace) create/) { line = k; break }
        }
        text = region
        if (length(text) > 400) text = substr(text, 1, 400) " …"
        printf "FAIL %s:%d [%s] :: %s\n", file, line, substr(why, 2), text
      }
      { L[NR] = $0 }
      END {
        n = NR
        i = 1
        while (i <= n) {
          if (L[i] ~ /^[[:space:]]*$/) { i++ }
          else if (is_marker(L[i])) {
            ind = indent(L[i]); j = i + 1; last = i
            while (j <= n) {
              if (L[j] ~ /^[[:space:]]*$/) { j++ }
              else if (indent(L[j]) <= ind) { break }
              else { last = j; j++ }
            }
            emit(i, last); i = last + 1
          } else {
            j = i
            while (j <= n && L[j] !~ /^[[:space:]]*$/ && !is_marker(L[j])) j++
            emit(i, j - 1); i = j
          }
        }
        printf "SITES %d\n", sites
      }
    ' "$_f")"
    case "$_out" in
      *"SITES "*) : ;;
      *) printf 'SCAN-ERROR %s: no SITES line — that file%s scan did not finish\n' "$_f" "'" ;;
    esac
    printf '%s\n' "$_out"
  done
}

# The floor, as one predicate the real tree and its control both go through.
sites_meet_floor() { # <n>
  [ "${1:-0}" -ge "$SITE_FLOOR" ] 2>/dev/null
}

# The count from a scan stream: one `SITES <n>` line per scanned file, summed. Empty
# (`0`) is a failed scan unless a SITES line was printed at all — the caller asserts
# that separately, so a scan that never finished cannot read as a clean zero.
sites_count() { # <scan output>
  printf '%s\n' "$1" | awk '$1 == "SITES" { n += $2 } END { print n+0 }'
}

sites_lines() { # <scan output>
  printf '%s\n' "$1" | awk '$1 == "SITES" { c++ } END { print c+0 }'
}

scan_fails() { # <scan output>
  printf '%s\n' "$1" | awk '$1 == "FAIL"'
}

scan_errors() { # <scan output>
  printf '%s\n' "$1" | awk '$1 == "SCAN-ERROR"'
}

printf '%slaunch-site marking (#663)%s\n\n' "$DIM" "$RST"

section "the rule scans the shipped prose"

scan="$(scan_launch_sites "$SCAN_ROOT")"
errors="$(scan_errors "$scan")"
if [ -n "$errors" ]; then
  fail "every scanned file reports its site count" \
    "a path's scan did not finish — a missing SITES line must fail the run, never vanish behind the rest:"
  printf '%s\n' "$errors" | while IFS= read -r l; do
    printf '      %s%s%s\n' "$DIM" "$l" "$RST"
  done
  report; exit $?
fi

if [ "$(sites_lines "$scan")" -eq 0 ]; then
  fail "the scan reports the number of sites it selected" \
    "no SITES line — a scan that did not finish must not read as a clean one: $scan"
  report; exit $?
fi
sites="$(sites_count "$scan")"

fails="$(scan_fails "$scan")"
if [ -z "$fails" ]; then
  pass "every selected site carries a marking clause ($sites sites in $SCAN_ROOT)"
else
  n_fail="$(printf '%s\n' "$fails" | awk 'END { print NR }')"
  fail "every selected site carries a marking clause" \
    "$n_fail site(s) with no clause in their own paragraph or list item:"
  printf '%s\n' "$fails" | while IFS= read -r l; do
    printf '      %s%s%s\n' "$DIM" "$l" "$RST"
  done
fi

if sites_meet_floor "$sites"; then
  pass "the scan selects at least $SITE_FLOOR sites (selected $sites)"
else
  fail "the scan selects at least $SITE_FLOOR sites" \
    "selected $sites — the grammar stopped selecting sites it used to; the floor is today's count, not slack"
fi

section "controls beside the assertions"

# Every fixture this suite builds lives under one EXIT trap, so a later early exit
# cannot leak one of them.
tmp="$(mktemp -d)"
tmp2=""
trap 'rm -rf "$tmp"; [ -z "${tmp2:-}" ] || rm -rf "$tmp2"' EXIT

# B2, red: a fixture copy with ONE added unmarked site must fail, naming file, line and
# the site text. The fixture is a temp copy; no shipped file is ever edited to stage it.
cp -R "$PLUGIN_ROOT/skills" "$tmp/skills"
cp -R "$PLUGIN_ROOT/commands" "$tmp/commands"
planted="When the operator asks for a second opinion, launch a fresh reviewer seat from the project file's reviewer seat."
printf '\n%s\n' "$planted" >> "$tmp/skills/orchestrate/references/roles.md"

red="$(scan_launch_sites "$tmp")"
red_fails="$(scan_fails "$red")"
red_n="$(printf '%s\n' "$red_fails" | awk 'END { print NR }')"
red_sites="$(sites_count "$red")"
if [ "$red_n" -eq 1 ] \
   && printf '%s\n' "$red_fails" | awk -v f="$tmp/skills/orchestrate/references/roles.md" -v t="$planted" \
        '$1 == "FAIL" && index($2, f ":") == 1 && index($0, t) > 0 { hit = 1 } END { exit(hit ? 0 : 1) }'; then
  pass "control: an added unmarked launch site fails, named with file, line and text ($red_sites sites, 1 failure)"
else
  fail "control: an added unmarked launch site fails, named with file, line and text" \
    "expected exactly one failure naming $(basename "$tmp")/skills/orchestrate/references/roles.md and the planted text; got: $red"
fi

# B2, green: the same site with a clause passes, so the check fails on the missing
# clause and not on the paragraph's shape.
printf 'Mark it a guarded `reviewer` before its command (Seat marking).\n' \
  >> "$tmp/skills/orchestrate/references/roles.md"
green="$(scan_launch_sites "$tmp")"
green_fails="$(scan_fails "$green")"
green_sites="$(sites_count "$green")"
if [ -z "$green_fails" ] && [ "$green_sites" -eq "$red_sites" ]; then
  pass "control: the same site with a clause passes ($green_sites sites, 0 failures)"
else
  fail "control: the same site with a clause passes" \
    "expected 0 failures over $red_sites sites; got: $green"
fi

# bold spans: `**` is stripped before matching, so a bold article and a bold verb each
# still select. Both fixture paragraphs are unmarked, so each must appear as a failure
# with its sentence intact — a bold span that hid a site reads as zero failures here.
printf '\nLaunch **a** fresh reviewer seat from the project file'"'"'s reviewer seat.\n' \
  >> "$tmp/skills/orchestrate/references/roles.md"
printf '\n**You dispatch** a fresh writer seat from the project file'"'"'s work-PR session seat.\n' \
  >> "$tmp/skills/orchestrate/references/roles.md"
bold="$(scan_launch_sites "$tmp")"
bold_fails="$(scan_fails "$bold")"
bold_n="$(printf '%s\n' "$bold_fails" | awk 'END { print NR }')"
if [ "$bold_n" -eq 2 ] \
   && printf '%s\n' "$bold_fails" | awk 'index($0, "Launch a fresh reviewer seat") > 0 { a++ } END { exit(a == 1 ? 0 : 1) }' \
   && printf '%s\n' "$bold_fails" | awk 'index($0, "You dispatch a fresh writer seat") > 0 { b++ } END { exit(b == 1 ? 0 : 1) }'; then
  pass "control: bold articles and bold verbs are selected (2 failures, one per shape)"
else
  fail "control: bold articles and bold verbs are selected" \
    "expected exactly two failures, one per bold shape; got: $bold"
fi

# B4's adjacent control: the floor predicate must refuse a tree that selects fewer
# sites — a floor that cannot fail holds nothing.
tmp2="$(mktemp -d)"
mkdir -p "$tmp2/tree/skills/orchestrate/references" "$tmp2/tree/commands"
cp "$PLUGIN_ROOT/skills/orchestrate/references/roles.md" "$tmp2/tree/skills/orchestrate/references/roles.md"
small="$(scan_launch_sites "$tmp2/tree")"
small_n="$(sites_count "$small")"
if [ "$small_n" -gt 0 ] && [ "$small_n" -lt "$SITE_FLOOR" ] && ! sites_meet_floor "$small_n"; then
  pass "control: a tree below the floor is refused (selected $small_n, floor $SITE_FLOOR)"
else
  fail "control: a tree below the floor is refused" \
    "the floor predicate accepted $small_n sites at SITE_FLOOR=$SITE_FLOOR; lower SITE_FLOOR to the tree it is meant to hold"
fi

# Per-file death: a scanned path whose own scan dies must print SCAN-ERROR and fail the
# run. The fixture plants a DIRECTORY named *.md — find matches it, awk cannot read it,
# and no SITES line comes back for that path; a suite that only checked for one SITES
# line anywhere would read this green.
mkdir -p "$tmp2/bad/skills/orchestrate/references/evil.md" "$tmp2/bad/commands"
bad="$(scan_launch_sites "$tmp2/bad")"
if [ "$(printf '%s\n' "$bad" | awk '$1 == "SCAN-ERROR" { c++ } END { print c+0 }')" -ge 1 ] \
   && printf '%s\n' "$bad" | awk 'index($0, "evil.md") > 0 { hit = 1 } END { exit(hit ? 0 : 1) }'; then
  pass "control: a path whose scan dies is refused by name, not dropped"
else
  fail "control: a path whose scan dies is refused by name, not dropped" \
    "expected a SCAN-ERROR naming evil.md; got: $bad"
fi

# #721: clause tokens have word edges, not substring matches. Each rejected spelling
# sits beside both `a guarded seat` and the genuine token, so refusing all clauses
# cannot satisfy the negative control. ROLE= ends at `=`: its value may start a word.
mkdir -p "$tmp2/tokens/skills" "$tmp2/tokens/commands"
for token in 'SEAT_MODS_ROLE=reviewer' guarded coordinator orchestrator 'step 2' 'Seat marking'; do
  for embedded in "x$token" "7$token" "_$token" "${token}x" "${token}7" "${token}_"; do
    case "$token:$embedded" in
      SEAT_MODS_ROLE=*:SEAT_MODS_ROLE=*) continue ;;
    esac
    printf 'launch a fresh reviewer seat. %s\n\nlaunch a fresh reviewer seat, a guarded seat.\n\nlaunch a fresh reviewer seat. (%s)\n' \
      "$embedded" "$token" > "$tmp2/tokens/skills/control.md"
    tokens="$(scan_launch_sites "$tmp2/tokens")"
    if [ "$(sites_count "$tokens")" -eq 3 ] \
       && printf '%s\n' "$tokens" | awk -v f="$tmp2/tokens/skills/control.md:1" \
         '$1 == "FAIL" { n++; if ($2 == f) hit++ } END { exit(n == 1 && hit == 1 ? 0 : 1) }'; then
      pass "control: clause rejects $embedded; a guarded seat and $token still pass"
    else
      fail "control: clause rejects $embedded; a guarded seat and $token still pass" \
        "expected three sites and only line 1 unmarked; got: $tokens"
    fi
  done
done
# The two issue spellings, including a numeric continuation of a multi-word token.
for embedded in unguarded 'step 20'; do
  printf 'launch a fresh reviewer seat. %s\n\nlaunch a fresh reviewer seat, a guarded seat.\n' \
    "$embedded" > "$tmp2/tokens/skills/control.md"
  tokens="$(scan_launch_sites "$tmp2/tokens")"
  if [ "$(sites_count "$tokens")" -eq 2 ] \
     && printf '%s\n' "$tokens" | awk -v f="$tmp2/tokens/skills/control.md:1" \
       '$1 == "FAIL" { n++; if ($2 == f) hit++ } END { exit(n == 1 && hit == 1 ? 0 : 1) }'; then
    pass "control: clause rejects $embedded; a guarded seat still passes"
  else
    fail "control: clause rejects $embedded; a guarded seat still passes" \
      "expected two sites and only line 1 unmarked; got: $tokens"
  fi
done

# #721: sentence-initial forms select just like their lowercase counterparts. The
# reviewer noun has no `seat`, so pattern 4 cannot hide a lost pattern-6 verb.
mkdir -p "$tmp2/verbs/skills" "$tmp2/verbs/commands"
while read -r lower capital; do
  for verb in "$lower" "$capital"; do
    printf '%s fresh reviewer.\n' "$verb" > "$tmp2/verbs/skills/control.md"
    verbs="$(scan_launch_sites "$tmp2/verbs")"
    if [ "$(sites_count "$verbs")" -eq 1 ] \
       && printf '%s\n' "$verbs" | awk '$1 == "FAIL" && index($0, "fresh-seat") > 0 { n++ } END { exit(n == 1 ? 0 : 1) }'; then
      pass "control: $verb selects an unmarked fresh reviewer"
    else
      fail "control: $verb selects an unmarked fresh reviewer" "expected one fresh-seat failure; got: $verbs"
    fi
  done
done <<'VERBS'
launch Launch
launches Launches
launched Launched
dispatch Dispatch
dispatches Dispatches
dispatched Dispatched
create Create
creates Creates
created Created
respawn Respawn
respawns Respawns
respawned Respawned
VERBS
for verb in respawn Respawn; do
  printf '%s the worker.\n' "$verb" > "$tmp2/verbs/skills/control.md"
  verbs="$(scan_launch_sites "$tmp2/verbs")"
  if [ "$(sites_count "$verbs")" -eq 1 ] \
     && printf '%s\n' "$verbs" | awk '$1 == "FAIL" && index($0, "[respawn]") > 0 { n++ } END { exit(n == 1 ? 0 : 1) }'; then
    pass "control: bare $verb selects an unmarked site"
  else
    fail "control: bare $verb selects an unmarked site" "expected one respawn failure; got: $verbs"
  fi
done

# #721: the first sentence is context, not the launch. Report line 2 for each verb.
for verb in dispatch Dispatch create Create respawn Respawn; do
  printf 'The operator requests another opinion.\n%s a fresh reviewer seat.\n' "$verb" \
    > "$tmp2/verbs/skills/control.md"
  locator="$(scan_launch_sites "$tmp2/verbs")"
  if [ "$(sites_count "$locator")" -eq 1 ] \
     && printf '%s\n' "$locator" | awk -v f="$tmp2/verbs/skills/control.md:2" \
       '$1 == "FAIL" { n++; if ($2 == f) hit++ } END { exit(n == 1 && hit == 1 ? 0 : 1) }'; then
    pass "control: $verb failure points to the second-line verb"
  else
    fail "control: $verb failure points to the second-line verb" "expected one failure at line 2; got: $locator"
  fi
done

# #721: find must finish even when other files were emitted successfully. chmod
# 000 exercises the real unreadable-subtree path. Root can still read it: there,
# add a dangling-link operand with a trailing slash to real find, which exits
# nonzero (a bare dangling link is not an error under find's default -P).
mkdir -p "$tmp2/find/skills/locked" "$tmp2/find/commands"
printf 'launch a fresh reviewer seat, a guarded seat.\n' > "$tmp2/find/skills/control.md"
chmod 000 "$tmp2/find/skills/locked"
find_branch=unreadable
if [ -r "$tmp2/find/skills/locked" ]; then
  find_branch=dangling
  ln -s "$tmp2/find/absent" "$tmp2/find/dangling"
  find_scan="$(
    find() { command find "$tmp2/find/dangling/" "$@"; }
    scan_launch_sites "$tmp2/find" 2>&1
  )"
else
  find_scan="$(scan_launch_sites "$tmp2/find" 2>&1)"
fi
chmod 700 "$tmp2/find/skills/locked"
if printf '%s\n' "$find_scan" | awk -v p="$tmp2/find" \
     '$1 == "SCAN-ERROR" && index($0, p ": find exited ") > 0 { hit++ } END { exit(hit == 1 ? 0 : 1) }'; then
  pass "control: find failure is a named SCAN-ERROR ($find_branch)"
else
  fail "control: find failure is a named SCAN-ERROR ($find_branch)" \
    "expected a SCAN-ERROR naming find and the scan root; got: $find_scan"
fi
# Adjacent control: removing the obstacle lets the same readable site scan cleanly.
find_clean="$(scan_launch_sites "$tmp2/find")"
if [ -z "$(scan_errors "$find_clean")" ] && [ -z "$(scan_fails "$find_clean")" ] \
   && [ "$(sites_count "$find_clean")" -eq 1 ]; then
  pass "control: a complete find still scans its marked site"
else
  fail "control: a complete find still scans its marked site" "expected one marked site and no errors; got: $find_clean"
fi

# #514, L1: the shape, asserted rather than assumed — a counter re-copied into any
# suite shadows the hoisted one and keeps passing.
section "the hoisted counters are not re-copied"
assert_hoisted_counters

report
