#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SKILL.md bash-block harness - prose gets CI.
#
# ossify's skills ARE the product: a ceremony is prose, and a bash block inside
# it is a shipped contract. Nothing else in this suite reads that prose, so a
# skill can document a verb no dispatcher implements, a `Skill()` parameter the
# runtime does not accept, or a block that does not parse, and every gate stays
# green. This file is that gate.
#
# SCOPE - check, do not execute. Nine mechanical facts: parse-validity, verb
# resolution, Skill() arity, the command-body arg bridge, reference
# reachability, the SKILL.md line budget, shadowed Skill(ossify:) tokens, a
# fence reading `$oss_bin` it never assigns, and a fence calling an
# ossify/lib function by name.
# (Route-pointer integrity was the eighth; it was removed at #284 round 2 -
# see the tombstone at check 8's old site.) Executing skill prose would need
# a fixture per ceremony, would have side effects, and would test the fixture
# instead of the contract.
#
# WHAT IT HONESTLY DOES NOT CATCH. Check 2 resolves `oss <subcommand>` tokens -
# ossify's own dispatcher verbs. A phantom *lib function* (the `sd_rules_apply`
# class: five citations, zero definitions) is not an `oss` subcommand and does
# not pass through here; what check 2 catches is the analogous class inside
# ossify's verb surface. And a cross-skill *semantic* contract - the `[internal]`
# marker one skill sets and another reads - is not a parse or symbol fact at
# all, so no check below can see it. Nor does check 2 read bare prose: it scans
# code contexts only (fenced blocks and inline-code spans), so `oss frobnicate`
# written in a sentence without backticks is not a contract citation and is not
# resolved. Those are the boundaries; a test credited with coverage it does not
# have is how the next phantom entry point ships.
#
# THE SELF-TEST IS THE POINT. This artifact is itself a test, so an extractor
# that silently stops extracting goes green forever and takes all nine checks
# with it - and nothing downstream can notice. Every check therefore runs twice:
# once against the shipped tree (expect zero findings) and once against a
# purpose-built fixture carrying exactly one planted defect per check (expect
# exactly that one, named). A run is only meaningful because the second half
# proves the first half was still looking.
# ---------------------------------------------------------------------------
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
OSSIFY="$(cd "$HERE/.." && pwd)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/oss-blocks.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Byte-based matching everywhere: the RSTART/RLENGTH arithmetic below is byte
# arithmetic, and a UTF-8 locale would make the two disagree.
export LC_ALL=C

_count() { # line count of a captured findings blob, 0 when empty
  if [ -z "$1" ]; then echo 0; else printf '%s\n' "$1" | wc -l | tr -d ' '; fi
}
_lines() { wc -l < "$1" | tr -d ' '; }
t_assert_ge() { # $1=floor $2=actual $3=label
  if [ "$2" -ge "$1" ] 2>/dev/null; then T_PASS=$((T_PASS+1))
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (expected >= $1, got '$2')"; fi
}
t_assert_grep() { # $1=file $2=ERE $3=label
  if grep -qE "$2" "$1" 2>/dev/null; then T_PASS=$((T_PASS+1))
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (no /$2/ in $1)"; fi
}

_md_files() { # $1=ossify-root -> every markdown file the harness owns
  local r="$1" d
  # references/ included since the route gates landed: three wrappers load
  # the plugin-root references tree directly (handoff, handoff-resume,
  # work-pr), so its prose is shipped contract with the same claim to scanning
  # as skills/. Blast radius measured before widening: the four shipped files
  # carry zero bash fences, zero Skill( forms, zero oss tokens, so checks 1-3
  # widen with no new findings (Codex r1 finding on #283).
  for d in skills commands agents references; do
    [ -d "$r/$d" ] && find "$r/$d" -type f -name '*.md'
  done | sort
}

# ---------------------------------------------------------------------------
# Extractors. Written once and shared by the checks - so a break in one takes
# the fixture plants down with it and the self-test goes red, instead of the
# shipped tree going quietly clean.
# ---------------------------------------------------------------------------

# THE FENCE CONTRACT, and why both regexes tolerate leading whitespace:
# 8 of the shipped bash blocks are indented inside list items, and an anchored
# ^```bash$ skips them without a word. Opener ^[ \t]*```bash[ \t]*$, closer
# ^[ \t]*```[ \t]*$. The state machine also gets the nesting right - only a
# BARE fence closes a block, so a ```bash line appearing inside a ```text block
# is content, not a new opener.
cat > "$WORK/emit-blocks.awk" <<'AWK'
/^[ \t]*```/ {
  if (inblk) {
    if ($0 ~ /^[ \t]*```[ \t]*$/) { if (isbash) close(out); inblk=0; isbash=0; next }
  } else {
    info=$0; sub(/^[ \t]*```/,"",info); sub(/[ \t]*$/,"",info)
    inblk=1
    if (info=="bash") {
      n++; isbash=1; out=OUT "/blk-" n ".sh"
      printf "" >> out                       # create even a zero-line block
      print n "\t" FILENAME "\t" FNR >> MAN   # FNR = the fence line
    }
    next
  }
}
{ if (inblk && isbash) print $0 >> out }
END { print n+0 >> CNT }
AWK

# Code contexts for check 2: every content line of any fenced block, plus each
# inline-code span on lines outside fences - emitted ONE SPAN PER RECORD. Two
# spans joined by a space on one output line manufacture verbs nobody wrote
# (`bin/oss` `lib/*.sh` -> "oss lib"); that was measured, not guessed.
cat > "$WORK/code-context.awk" <<'AWK'
/^[ \t]*```/ {
  if (inblk) { if ($0 ~ /^[ \t]*```[ \t]*$/) { inblk=0; next } }
  else { inblk=1; next }
}
{
  if (inblk) { print FILENAME ":" FNR ":" $0; next }
  s=$0
  while (match(s, /`[^`]*`/)) {
    print FILENAME ":" FNR ":" substr(s,RSTART+1,RLENGTH-2)
    s=substr(s,RSTART+RLENGTH)
  }
}
AWK

# Inline-code STRIPPER for check 4: every line, with backticked spans removed,
# but only outside fenced blocks - a fenced block is real code and a positional
# in one is a real finding.
cat > "$WORK/strip-inline.awk" <<'AWK'
/^[ \t]*```/ {
  if (inblk) { if ($0 ~ /^[ \t]*```[ \t]*$/) { inblk=0; print FNR ":"; next } }
  else { inblk=1; print FNR ":"; next }
}
{
  if (inblk) { print FNR ":" $0; next }
  s=$0; r=""
  while (match(s, /`[^`]*`/)) { r = r substr(s,1,RSTART-1); s=substr(s,RSTART+RLENGTH) }
  print FNR ":" r s
}
AWK

# ---------------------------------------------------------------------------
# Check 1 - every ```bash block parses under `bash -n`.
# Reports file:SOURCE-line (bash's in-block line number mapped back through the
# fence line) so the finding points at the offending line in the shipped doc.
# ---------------------------------------------------------------------------
check_1_parse() { # $1=ossify-root $2=workdir; writes $2/blocks/{manifest.tsv,count.txt}
  local r="$1" w="$2/blocks" n f fence err bline
  rm -rf "$w"; mkdir -p "$w"; : > "$w/manifest.tsv"; : > "$w/count.txt"
  awk -v OUT="$w" -v MAN="$w/manifest.tsv" -v CNT="$w/count.txt" \
      -f "$WORK/emit-blocks.awk" $(_md_files "$r")
  [ -s "$w/count.txt" ] || echo 0 > "$w/count.txt"
  while IFS=$'\t' read -r n f fence; do
    [ -n "$n" ] || continue
    if ! err="$(bash -n "$w/blk-$n.sh" 2>&1)"; then
      bline="$(printf '%s\n' "$err" | sed -n 's/.*: line \([0-9][0-9]*\): .*/\1/p' | head -1)"
      [ -n "$bline" ] || bline=1
      echo "$f:$((fence + bline)): $(printf '%s\n' "$err" | sed -n '1p' | sed 's#^.*: line [0-9]*: ##')"
    fi
  done < "$w/manifest.tsv"
}

# An independent second opinion on the block count. Deliberately NOT the state
# machine: a plain grep for the opener, written separately, so a break in the
# extractor's indentation tolerance surfaces as a disagreement instead of two
# wrong numbers that agree with each other.
grep_fence_count() { # $1=ossify-root
  _md_files "$1" | tr '\n' '\0' | xargs -0 cat \
    | { grep -cE '^[[:space:]]*```bash[[:space:]]*$' || true; } | tr -d ' '
}

# ---------------------------------------------------------------------------
# Check 2 - every `oss <subcommand>` token in a code context resolves to a real
# oss_cmd_* in the dispatcher.
#
# TWO EXTRACTION RULES, both by rule and neither by allowlist:
#  (a) WORD BOUNDARY. `oss` must start at a non-word byte. Without it the `oss`
#      inside "acr-oss" and "l-oss" yields `oss a`, `oss all`, `oss every`,
#      `oss the`, `oss three`, `oss footgun` - 6 of the 7 false positives the
#      naive extraction produces on the shipped tree.
#  (b) WILDCARD MENTIONS. A token containing `*` or ending in `_` is a
#      deliberate family reference (`oss ledger_add_*`), not a verb. That is
#      the 7th. Excluded tokens are printed so the exclusion set stays visible
#      instead of quietly absorbing a typo.
# ---------------------------------------------------------------------------
check_2_verbs() { # $1=ossify-root $2=workdir; writes $2/check2-{verbs,ctx,tokens,excluded}.txt
  local r="$1" w="$2" loc tok
  mkdir -p "$w"
  { grep -hoE '^oss_cmd_[A-Za-z0-9_]+\(\)' "$r/bin/oss" "$r"/lib/*.sh 2>/dev/null || true; } \
    | sed -E 's/^oss_cmd_//; s/\(\)$//' | sort -u > "$w/check2-verbs.txt"
  awk -f "$WORK/code-context.awk" $(_md_files "$r") > "$w/check2-ctx.txt"
  awk '{ s=$0
         split($0, _p, ":")
         while (match(s, /(^|[^A-Za-z0-9_$])(oss|"?\$oss_bin"?)[ \t]+[A-Za-z_][A-Za-z0-9_*-]*/)) {
           tok=substr(s,RSTART,RLENGTH)
           sub(/^[^A-Za-z0-9_$]?(oss|"?\$oss_bin"?)[ \t]+/,"",tok)
           print _p[1] ":" _p[2] "\t" tok
           s=substr(s,RSTART+RLENGTH) } }' "$w/check2-ctx.txt" | sort -u > "$w/check2-tokens.txt"
  : > "$w/check2-excluded.txt"
  while IFS=$'\t' read -r loc tok; do
    [ -n "$tok" ] || continue
    case "$tok" in
      *\**|*_) echo "$loc: oss $tok" >> "$w/check2-excluded.txt"; continue ;;
    esac
    grep -qxF "$tok" "$w/check2-verbs.txt" \
      || echo "$loc: 'oss $tok' resolves to no oss_cmd_$tok in the dispatcher"
  done < "$w/check2-tokens.txt"
}

# ---------------------------------------------------------------------------
# Check 3 - no Skill() invocation carries an argument. The runtime takes a bare
# skill name; a documented `Skill(x, target=y)` is a contract nothing honours,
# and this branch has shipped exactly that. Scoped to ossify.
# ---------------------------------------------------------------------------
check_3_skill_args() { # $1=ossify-root
  local f hit
  while IFS= read -r f; do
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      echo "$f:${hit%%:*}: Skill() invocation carries an argument: ${hit#*:}"
    done < <({ grep -nE 'Skill\([^)]*,' "$f" || true; })
  done < <(_md_files "$1")
}

# ---------------------------------------------------------------------------
# Check 4 - no positional $1/$2/$N in commands/*.md, matched only OUTSIDE
# inline-code spans.
#
# All five command files carry, at line 7, the bridge convention itself -
# "no positional `$1`/`$2`/`$N`" - with the positionals inside backticks. A
# check that flags prose telling you not to do the thing is broken, not the
# prose; there is not one real positional in commands/. Hence the stripper.
# THE ACCEPTED BLIND SPOT: a real positional written inside backticks as
# example code is invisible here. Accepted because the bridge line is a shipped
# convention in all five files and a backticked positional is not a form anyone
# writes by accident. Fenced blocks are NOT stripped - a positional in one is
# real code and is reported.
# ---------------------------------------------------------------------------
check_4_positionals() { # $1=ossify-root
  local f hit
  for f in "$1"/commands/*.md; do
    [ -e "$f" ] || continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      echo "$f:${hit%%:*}: positional argument outside inline code - a command body parses \$ARGUMENTS via a trailing argument: ${hit#*:}"
    done < <(awk -f "$WORK/strip-inline.awk" "$f" | { grep -E '\$\{?([1-9][0-9]*|N)\}?' || true; })
  done
}

# ---------------------------------------------------------------------------
# Check 5 - reference reachability, two halves.
#
# ORPHANS: every references/*.md under a skill must be named by that skill's own
# SKILL.md. A pointer from a sibling reference does not make a file reachable -
# the agent reads SKILL.md, not the directory listing. This supersedes the
# per-skill loop that lived in test-close.sh, which enforced the same rule for
# one skill only.
#
# DANGLING: the resolution base, stated explicitly. A pointer written
# `references/foo.md` resolves against the SKILL DIRECTORY - not the repo root,
# and not the citing file's own directory (which for a reference file would
# give references/references/). Three pointer forms exist in the tree:
#   references/X.md                -> <skill-dir>/references/X.md
#   <skill>/references/X.md        -> <ossify-root>/skills/<skill>/references/X.md
#   skills/<skill>/references/X.md -> <ossify-root>/skills/...
# ${CLAUDE_PLUGIN_ROOT}-rooted pointers are runtime-expanded and are skipped by
# the extraction regex, which refuses a `}` or `/` immediately before the match.
#
# CROSS-SKILL, reported and not failed: some shipped pointers are written bare
# but name a sibling skill's file, with the owning skill supplied by the
# possessive prose immediately before it ("Same rules as `start`'s
# `references/bones-registry.md`"). Qualifying those would read "`start`'s
# `start/references/...`" - worse prose for no gain, since the file exists. They
# are reported as exclusions, on the same discipline as check 2, and only a
# pointer that resolves NOWHERE fails. THE ACCEPTED BLIND SPOT: an intra-skill
# typo that happens to collide with a sibling skill's filename lands in the
# reported set instead of failing.
# ---------------------------------------------------------------------------
check_5_refs() { # $1=ossify-root $2=workdir; writes $2/check5-{crossskill,pointers}.txt
  local r="$1" w="$2" sk skill ref base f p
  mkdir -p "$w"; : > "$w/check5-crossskill.txt"; : > "$w/check5-pointers.txt"
  # (a) orphans
  for sk in "$r"/skills/*/; do
    [ -d "$sk/references" ] || continue
    for ref in "$sk"references/*.md; do
      [ -e "$ref" ] || continue
      grep -Fq "references/$(basename "$ref")" "$sk/SKILL.md" 2>/dev/null \
        || echo "$ref: orphan - $(basename "${sk%/}")/SKILL.md never names references/$(basename "$ref")"
    done
  done
  # (b) dangling
  while IFS= read -r f; do
    skill=""
    case "$f" in "$r"/skills/*) skill="$r/skills/$(printf '%s' "${f#"$r"/skills/}" | cut -d/ -f1)" ;; esac
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      echo "$p" >> "$w/check5-pointers.txt"
      case "$f" in
        # A citing file under the plugin-root references/ tree: its BARE
        # references/... pointers resolve against the plugin root (Codex r1
        # on #284 - before this arm those files had base "" and every valid
        # root-relative pointer reported dangling), while the QUALIFIED forms
        # keep their generic bases (Codex r2 on #284 - the round-1 arm had
        # dropped them, dangling valid citations like start/references/x.md).
        "$r"/references/*) case "$p" in
                              references/*)   base="$r" ;;
                              skills/*)       base="$r" ;;
                              */references/*) base="$r/skills" ;;
                              *)              base="" ;;
                            esac ;;
        *) case "$p" in
             skills/*)       base="$r" ;;
             */references/*) base="$r/skills" ;;
             *)              base="$skill" ;;
           esac ;;
      esac
      if [ -n "$base" ] && [ -f "$base/$p" ]; then continue; fi
      # Bare form only: does the named file exist under some sibling skill?
      # NOT for plugin-root reference files (Codex r2 on #284): a root-relative
      # pointer that only exists under some skill is dangling at RUNTIME - the
      # root file loads by wrapper route, never through a skill dir - so the
      # sibling fallback must not swallow the miss.
      if ! case "$f" in "$r"/references/*) true ;; *) false ;; esac; then
        case "$p" in
          references/*)
            if ls "$r"/skills/*/"$p" >/dev/null 2>&1; then
              echo "$f: cross-skill pointer '$p' (resolves under a sibling skill; base named in prose)" >> "$w/check5-crossskill.txt"
              continue
            fi ;;
        esac
      fi
      echo "$f: dangling pointer '$p' resolves to no file (base ${base:-<no skill dir>})"
    done < <({ grep -ohE '(^|[^A-Za-z0-9_/${}-])(skills/)?([A-Za-z0-9_-]+/)?references/[A-Za-z0-9_.-]+\.md' "$f" || true; } \
               | sed -E 's#^[^A-Za-z0-9_]##' | sort -u)
  done < <(_md_files "$r")
}

# ---------------------------------------------------------------------------
# Check 6 - every SKILL.md is <= 500 lines, whole-file `wc -l`. Two shipped
# files sit at exactly 499, so this is a HARD fail with no rounding headroom;
# each file's current count is reported so the ceiling is visible before an edit
# reaches it.
# ---------------------------------------------------------------------------
check_6_budget() { # $1=ossify-root $2=workdir; writes $2/check6-report.txt
  local f n
  mkdir -p "$2"; : > "$2/check6-report.txt"
  for f in "$1"/skills/*/SKILL.md; do
    [ -e "$f" ] || continue
    n="$(wc -l < "$f" | tr -d ' ')"
    echo "     $n  $(basename "$(dirname "$f")")/SKILL.md  (headroom $((500 - n)))" >> "$2/check6-report.txt"
    [ "$n" -le 500 ] || echo "$f:$n: SKILL.md is $n lines, over the 500-line budget by $((n - 500))"
  done
}

# ---------------------------------------------------------------------------
# check 7 - the EVERY-CALL listing budget, over the strings that LOAD.
#
# check 6 guards the SKILL.md *body* (500 lines), which costs nothing until a
# skill is entered. This guards the listing that loads on every single call -
# and that listing carries the COMMAND descriptions, not the SKILL.md ones:
# measured 2026-08-22 from a live session's own recorded skill_listing
# attachment (issue #263), all ten commands/*.md descriptions load verbatim
# and none of the six skills/*/SKILL.md descriptions load at all -
# commands/<name>.md shadows skills/<name>/SKILL.md on the ossify:<name>
# token, and the #274 fix changed the loading ROUTE, not the listing SOURCE.
# Until this re-point the check summed strings that never load: a green gate
# certifying nothing, the same shadowing one level up.
#
# CEILING - derived from the spec band, never from history. §9.1
# (poc-first-lifecycle-design.md :115-119, :467) targets every-call listing
# cost at 0.3-0.4% of the window: 0.4% of 200k tokens = 800 tokens; at the
# 4.0 chars/token ratio the C1 numbers embed (3121 bytes = 0.39% = 780
# tokens - internally consistent), the band edge is 800 x 4.0 = 3200 bytes.
# The previous constant 3121 was the C1 trim's LANDING POINT (4180 -> 3121,
# 0.52% -> 0.39%), 79 bytes inside the edge: a historical accident, not the
# band. Nothing enforced any of it before C1, and the trim had drifted back
# to 3135 by v0.2 planning - a budget nobody measures is not a budget.
#
# MEASUREMENT is description-only, in bytes under the LC_ALL=C exported at
# the top of this file - the same method the ceiling is derived in. The
# listing's "- ossify:<name>: " prefixes add real cost (230 bytes at the
# twelve-command set measured in #263, name-length-dependent) but are harness
# rendering this test does not own; recorded here, not measured.
#
# HONESTY LINE: the fourteen-command surface measures 2526/3200 = 0.32% of
# the window (1.13.0 added /ossify:patch) - 1.3x headroom, now inside §9.1's
# 0.3-0.4% band; three of the fourteen are standalone utilities §9.1 intended to surface
# name-only (issue #282 records that divergence and why trimming is the
# wrong fix: budget nobody is short of, traded against routing triggers).
# This check is a regression guard against growth, not a tight budget; it
# cannot fire until the surface grows another 27%. Know that is what it is.
#
# DIVERGENCES recorded here, fixed elsewhere:
#   D-2: §9.1 says "<=6 fully-described entry skills" and lists six;
#        run-spine is a de-facto seventh full entry (lifecycle baton target),
#        #267's adopt is an eighth, and Batch S's challenge is a ninth,
#        unless §9.1 is amended deliberately -
#        the amendment is #267's to make. This check enforces bytes, not
#        count, on purpose.
#   D-3: §9.1's doctor row still allocates the phase-2 migration entry point
#        the adopt-forward spec rejected on doctor's report-only contract;
#        falls to the same §9.1 amendment.
#
# The floor assertion is not decoration: a glob that silently matches nothing
# sums to 0, which sails under any ceiling. That is the same vacuity mode
# check 5 guards against, and it is why this reports rather than just totals.
# The floor moved with the glob (skills -> commands) at this re-point.
# ---------------------------------------------------------------------------
check_7_descriptions() { # $1=ossify-root $2=workdir; writes $2/check7-report.txt
  local f d n total=0
  mkdir -p "$2"; : > "$2/check7-report.txt"
  for f in "$1"/commands/*.md; do
    [ -e "$f" ] || continue
    # Frontmatter-scoped on purpose: the listing loads the frontmatter value,
    # and a `description: ` line in the BODY is prose. The old whole-file sed
    # counted body lines (Codex r1 on #283) - a wrapper whose frontmatter
    # description was lost but whose body happened to carry such a line kept
    # a green budget and a silent no-description miss.
    d="$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 && /^description: / {sub(/^description: /,""); print; exit}' "$f")"
    [ -n "$d" ] || { echo "$f: no frontmatter description"; continue; }
    echo "     ${#d}  commands/$(basename "$f")" >> "$2/check7-report.txt"
    total=$(( total + ${#d} ))
  done
  echo "     TOTAL $total  (budget 3200, headroom $((3200 - total)))" >> "$2/check7-report.txt"
  [ "$total" -le 3200 ] || echo "command descriptions total $total bytes, over the 3200 every-call budget by $(( total - 3200 ))"
  n="$(ls -1 "$1"/commands/*.md 2>/dev/null | wc -l | tr -d ' ')"
  [ "$n" -ge 14 ] || echo "check 7 saw only $n command files; the budget loop is not measuring the whole set"
}

# ---------------------------------------------------------------------------
# Check 8 - REMOVED at round 2, per the pre-agreed fallback. Route-pointer
# integrity drew seven precision findings across three review passes (#283 r1:
# non-disjoint arms; #284 r1: Read-substring match, suffix truncation,
# cross-wiring; #284 r2: no left boundary on Read, first-entry-only
# validation, backtick inconsistency between instruction regex and extractor).
# A gate still finding new ways to be wrong on its third pass is not ready to
# block every future PR. Deferred to its own issue carrying this history; the
# entry-route surface returns to unguarded, its pre-PR state, until that issue
# lands. Check 9 keeps the cheap half of the route protection.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Check 9 - no shadowed Skill(ossify:<name>) tokens anywhere the harness owns.
#
# The bare form that CAUSED #262: Skill(ossify:close) is shadowed by
# commands/close.md, so the call loads the ~20-line wrapper, not the skill
# body, and dead-ends. Check 3 catches only comma-bearing invocations
# (Skill\(x, target=y\)); a prose edit restoring a bare token - from git
# history, a regenerated wrapper, a reference doc - passes every gate
# (#263's review, finding 2). The sanctioned route is the wrapper's
# path-routing Read line or a cross-PLUGIN call into another plugin's
# skill. The scan owns the plugin-root references/
# tree too, because three wrappers load it directly (Codex r1 on #283).
#
# SHADOW-CONDITIONED (Codex r2 on #284): the dead-end exists only where
# commands/<name>.md actually shadows a same-named skill. A future skill
# with no same-named command is NOT shadowed and invoking it by token is
# legal - the check extracts the name and fires only on the collision.
# ---------------------------------------------------------------------------
check_9_shadowed_tokens() { # $1=ossify-root
  local f hit rest name
  while IFS= read -r f; do
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      rest="${hit#*:}"
      name="$(printf '%s' "$hit" | sed -nE 's/.*Skill\(ossify:([A-Za-z0-9_-]+).*/\1/p')"
      [ -n "$name" ] || continue
      [ -f "$1/commands/$name.md" ] || continue
      echo "$f:${hit%%:*}: shadowed token $rest - commands/$name.md shadows the skill this call means (#262); route by the wrapper's path-routing Read line instead"
    done < <({ grep -nE 'Skill\(ossify:[A-Za-z0-9_-]+' "$f" || true; })
  done < <(_md_files "$1")
}

# ---------------------------------------------------------------------------
# Check 10 - every `=$?` status read in a shipped bash block is errexit-guarded.
#
# Under `set -e` a bare `cmd; rc=$?` (or `cmd; echo "rc=$?"`) aborts BEFORE the
# read ever runs - the failing command is usually the expected case, so the
# block exits with the rc unreported and any cleanup unrun. Four instances
# shipped before this gate existed: cumulative-demo.md's head/parent command
# captures (#496 round 3) and its diff, bone-touch-judge.md's touch_check, and
# debugging.md's pytest probes. The guarded spellings are an `else` arm
# (`if cmd; then rc=0; else rc=$?; fi`), an explicit `||`/`&&` chain
# (`rc=0; cmd || rc=$?`), or a comment documenting the form - a comment cannot
# abort. Any other line reading `$?` is a capture that cannot survive errexit.
# A second arm sits beside the guard: a status read in the `then`/`else` arm of
# an `if !`, or after `! cmd ||`, reads the NEGATION's status, which is 0 when
# the command failed (pulse360 `verify-step-halt-swallowed-false-pass`).
# ---------------------------------------------------------------------------
check_10_errexit_captures() { # $1=blocks-dir holding blk-N.sh + manifest.tsv
  local w="$1" n f fence line ln
  while IFS=$'\t' read -r n f fence; do
    [ -n "$n" ] || continue
    while IFS= read -r line; do
      ln="${line%%:*}"; line="${line#*:}"
      # Strip every GUARDED read - `else x=$?`, `then x=$?`, `|| x=$?`,
      # `&& x=$?` (the guard must directly precede the assignment: a `cd &&
      # cmd; echo "rc=$?"` has && earlier in the line but the read still
      # aborts) - then flag whatever `=$?` remains. The strip lands in a var:
      # a `|| continue` at a pipeline tail is a subshell and cannot reach the
      # loop.
      local stripped
      stripped="$(printf '%s\n' "$line" | sed -E 's/(else|then|\|\||\&\&)[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[[:space:]]*\$\?//g')"
      [[ "$stripped" =~ =[[:space:]]*\$\? ]] || continue
      echo "$f:$((fence + ln)): unguarded '=\$?' status read - under set -e the command aborts before the read runs; use if/else or 'rc=0; cmd || rc=\$?'"
    done < <({ grep -nE '=[[:space:]]*\$\?' "$w/blk-$n.sh" || true; } | { grep -vE '^[0-9]+:[[:space:]]*#' || true; })
    # A status read in the arm of an `if !`, or after `! cmd ||`, reads the
    # negation's status (0 when the command failed), not the command's - so the
    # `else rc=$?` spelling this check's own message prescribes is exactly the
    # one that lies here (pulse360 `verify-step-halt-swallowed-false-pass`).
    # Negation is tracked across the block's lines: a line ending in `then` or
    # `else` arms the NEXT line as that arm's first statement; `fi` closes it.
    awk -v f="$f" -v fence="$fence" '
      /^[[:space:]]*#/ { next }
      {
        line = $0
        # A status read belongs to the `if !` that OWNS it. Everything after the
        # first `fi` on the line is a different command - `if ! a; then :; fi; if b;
        # then :; else rc=$?; fi` reports a read that belongs to the un-negated
        # second if (PR #772 round 1). Cut at that `fi` and look for the arm read
        # only inside the segment; the multi-line state arms only when this `if !`
        # is still open at end of line.
        if (match(line, /(^|[;&|[:space:]])if[[:space:]]+![[:space:]]/)) {
          seg = substr(line, RSTART)
          closed = match(seg, /(^|[;[:space:]])fi([;[:space:]]|$)/)
          if (closed) seg = substr(seg, 1, RSTART - 1)
          if (seg ~ /(then|else)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[[:space:]]*\$\?/) {
            printf "%s:%d: '"'"'=$?'"'"' read after a negated condition reads the negation'"'"'s status, not the command'"'"'s; use '"'"'rc=0; cmd || rc=$?'"'"'\n", f, fence + NR
          }
          if (closed) { neg = 0; arm = 0 }
          else { neg = 1; arm = (seg ~ /(then|else)[[:space:]]*$/) ? 1 : 0 }
        }
        if (neg) {
          # the read is the first statement of the then/else arm: the next line
          if (arm && line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[[:space:]]*\$\?/) {
            printf "%s:%d: '"'"'=$?'"'"' read after a negated condition reads the negation'"'"'s status, not the command'"'"'s; use '"'"'rc=0; cmd || rc=$?'"'"'\n", f, fence + NR
          }
          arm = (line ~ /(then|else)[[:space:]]*$/) ? 1 : 0
          if (line ~ /(^|[;[:space:]])fi([;[:space:]]|$)/) { neg = 0; arm = 0 }
        }
        if (line ~ /(^|[;&[:space:]])![[:space:]][^;|&]*\|\|[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[[:space:]]*\$\?/) {
          printf "%s:%d: '"'"'=$?'"'"' read after a negated condition reads the negation'"'"'s status, not the command'"'"'s; use '"'"'rc=0; cmd || rc=$?'"'"'\n", f, fence + NR
        }
      }' "$w/blk-$n.sh"
  done < "$w/manifest.tsv"
}

# ---------------------------------------------------------------------------
# Check 11 - a fence that reads $oss_bin assigns it in the same fence.
#
# Each Bash call is a fresh shell. A fence that reads `$oss_bin` set by an
# earlier fence runs `""` - rc 127, "command not found" - which reads as a
# FAIL (pulse360 `bash-lib-function-not-found-cascade`). Fences call `oss` by
# name; only a fence that checks WHICH `oss` is on $PATH holds it in a var.
# ---------------------------------------------------------------------------
check_11_oss_bin_assigned() { # $1=blocks-dir holding blk-N.sh + manifest.tsv
  local w="$1" n f fence body
  while IFS=$'\t' read -r n f fence; do
    [ -n "$n" ] || continue
    body="$(grep -vE '^[[:space:]]*#' "$w/blk-$n.sh" || true)"
    # The WHOLE name: `$oss_bin`, `"$oss_bin"`, `${oss_bin}` and `${oss_bin:-…}`
    # are reads of the variable; `$oss_binary` is a different variable and is not
    # a finding (PR #772 round 1).
    grep -qE '\$(oss_bin([^A-Za-z0-9_]|$)|\{oss_bin[}:#%/^,@-])' <<<"$body" || continue
    grep -qE '(^|[;&[:space:]])oss_bin=' <<<"$body" && continue
    echo "$f:$((fence + 1)): fence reads \$oss_bin but never assigns it - a fresh shell runs \"\" (rc 127); call 'oss' by name"
  done < "$w/manifest.tsv"
}

# ---------------------------------------------------------------------------
# Check 12 - no fence calls a function defined in ossify/lib/*.sh.
#
# A lib function does not exist in a fresh shell; only `oss <verb>` reaches
# it. Comment lines are skipped: citing a function in a comment is not a call.
# ---------------------------------------------------------------------------
check_12_no_lib_calls() { # $1=ossify-root $2=blocks-dir
  local r="$1" w="$2" n f fence names hit own body fn
  names="$({ grep -hoE '^[A-Za-z_][A-Za-z0-9_]*\(\)' "$r"/lib/*.sh 2>/dev/null || true; } | sed 's/()$//' | sort -u)"
  [ -n "$names" ] || { echo "check 12: no lib functions found under $r/lib - extractor broken"; return; }
  # COMMAND POSITION, not a mere mention. A name handed to another command as an
  # argument (`printf '%s\n' oss_verify_parse_acs`) or quoted into a message is not
  # a call, and flagging it teaches the reader to ignore the check (PR #772 round 1).
  local pos='(^|[;&|({]|\$\(|`|(then|do|else|if|while|until|time|!)[[:space:]]+)'
  while IFS=$'\t' read -r n f fence; do
    [ -n "$n" ] || continue
    body="$(grep -vE '^[[:space:]]*#' "$w/blk-$n.sh" || true)"
    hit=""
    while IFS= read -r fn; do
      [ -n "$fn" ] || continue
      grep -Eq "${pos}[[:space:]]*${fn}([[:space:]]|;|\)|$)" <<<"$body" || continue
      hit="$hit$fn"$'\n'
    done <<<"$names"
    [ -n "$hit" ] || continue
    hit="$(printf '%s' "$hit" | sort -u)"
    # A fence may define its own function that shares a lib name; calling it is fine.
    own="$({ grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\(\)' "$w/blk-$n.sh" || true; } | sed -E 's/^[[:space:]]*//; s/\(\)$//' | sort -u)"
    [ -z "$own" ] || hit="$(grep -vxFf <(printf '%s\n' "$own") <<<"$hit" || true)"
    [ -n "$hit" ] || continue
    while IFS= read -r fn; do
      echo "$f:$((fence + 1)): fence calls lib function '$fn' directly - it does not exist in a fresh shell; use 'oss <verb>'"
    done <<<"$hit"
  done < "$w/manifest.tsv"
}

# ===========================================================================
# PART 1 - the shipped tree. Expect zero findings from every check.
# ===========================================================================
echo "-- ossify tree: $OSSIFY"

# The two extractors hand their file list to awk as unquoted words, which a path
# containing whitespace would split. Assert it instead of extracting nonsense
# quietly - a silent split shows up as a *lower* block count, which is exactly
# the failure this file exists to make impossible.
t_assert_eq 0 "$(_md_files "$OSSIFY" | { grep -cE '[[:space:]]' || true; } | tr -d ' ')" \
  "no markdown path contains whitespace (the awk file-list contract)"

C1="$(check_1_parse "$OSSIFY" "$WORK/real")"
BLOCKS="$(cat "$WORK/real/blocks/count.txt")"
GREPN="$(grep_fence_count "$OSSIFY")"
echo "-- check 1: $BLOCKS bash blocks extracted (independent grep opener count: $GREPN)"
t_assert_eq 0 "$(_count "$C1")" "check 1: every shipped bash block parses under bash -n${C1:+ -- $C1}"
t_assert_eq "$GREPN" "$BLOCKS" "check 1: state-machine block count agrees with the independent grep opener count"
t_assert_ge 100 "$BLOCKS" "check 1: the block extractor is live (count has not collapsed)"

C2="$(check_2_verbs "$OSSIFY" "$WORK")"
echo "-- check 2: $(_lines "$WORK/check2-tokens.txt") oss-verb citations against $(_lines "$WORK/check2-verbs.txt") dispatcher verbs, $(_lines "$WORK/check2-excluded.txt") excluded as wildcard mentions"
[ -s "$WORK/check2-excluded.txt" ] && sed 's/^/     excluded: /' "$WORK/check2-excluded.txt"
t_assert_eq 0 "$(_count "$C2")" "check 2: every cited oss verb resolves to a dispatcher oss_cmd_*${C2:+ -- $C2}"
t_assert_ge 40 "$(_lines "$WORK/check2-tokens.txt")" "check 2: the code-context extractor is live (verb citations found)"
# The four verbs whose usage signatures this task re-quoted must STILL be visible
# to check 2. Quoting keeps those blocks inside check 1's coverage and keeps
# their verbs resolvable here; re-fencing them to ```text would have removed
# them from both, silently.
for v in ledger_supersede ledger_retire ledger_quarantine fake_status; do
  t_assert_grep "$WORK/check2-tokens.txt" "	$v\$" \
    "check 2 still resolves 'oss $v' (a re-fence or a broken extractor would hide it)"
done

C3="$(check_3_skill_args "$OSSIFY")"
t_assert_eq 0 "$(_count "$C3")" "check 3: no Skill() invocation carries an argument${C3:+ -- $C3}"

C4="$(check_4_positionals "$OSSIFY")"
t_assert_eq 0 "$(_count "$C4")" "check 4: no positional args in commands/*.md outside inline code${C4:+ -- $C4}"

C5="$(check_5_refs "$OSSIFY" "$WORK")"
echo "-- check 5: $(ls "$OSSIFY"/skills/*/references/*.md 2>/dev/null | wc -l | tr -d ' ') reference files, $(_lines "$WORK/check5-pointers.txt") pointers, $(_lines "$WORK/check5-crossskill.txt") cross-skill"
[ -s "$WORK/check5-crossskill.txt" ] && sed 's/^/     cross-skill: /' "$WORK/check5-crossskill.txt"
t_assert_eq 0 "$(_count "$C5")" "check 5: no orphaned reference and no dangling pointer${C5:+ -- $C5}"
t_assert_ge 40 "$(ls "$OSSIFY"/skills/*/references/*.md 2>/dev/null | wc -l | tr -d ' ')" "check 5: the orphan loop is not vacuous (reference files found)"
t_assert_ge 50 "$(_lines "$WORK/check5-pointers.txt")" "check 5: the dangling loop is not vacuous (pointers found)"

C6="$(check_6_budget "$OSSIFY" "$WORK")"
echo "-- check 6: SKILL.md line budgets"
cat "$WORK/check6-report.txt"
t_assert_eq 0 "$(_count "$C6")" "check 6: every SKILL.md is within the 500-line budget${C6:+ -- $C6}"
t_assert_ge 5 "$(_lines "$WORK/check6-report.txt")" "check 6: the budget loop saw every entry skill"

C7="$(check_7_descriptions "$OSSIFY" "$WORK")"
echo "-- check 7: command-description budget (the every-call listing cost)"
cat "$WORK/check7-report.txt"
t_assert_eq 0 "$(_count "$C7")" "check 7: command descriptions are within the 3200-byte every-call budget${C7:+ -- $C7}"
t_assert_ge 15 "$(_lines "$WORK/check7-report.txt")" "check 7: the description loop saw every command (14 rows + the total)"

C9="$(check_9_shadowed_tokens "$OSSIFY")"
echo "-- check 9: shadowed Skill(ossify:) tokens"
t_assert_eq 0 "$(_count "$C9")" "check 9: no shadowed Skill(ossify:) tokens anywhere the harness owns${C9:+ -- $C9}"

C10="$(check_10_errexit_captures "$WORK/real/blocks")"
echo "-- check 10: unguarded '=\$?' status reads in shipped blocks"
t_assert_eq 0 "$(_count "$C10")" "check 10: every '=\$?' read in a shipped bash block is errexit-guarded (else-arm or ||/&&)${C10:+ -- $C10}"

C11="$(check_11_oss_bin_assigned "$WORK/real/blocks")"
echo "-- check 11: fences reading \$oss_bin with no assignment"
t_assert_eq 0 "$(_count "$C11")" "check 11: every fence that reads \$oss_bin assigns it in the same fence${C11:+ -- $C11}"

C12="$(check_12_no_lib_calls "$OSSIFY" "$WORK/real/blocks")"
echo "-- check 12: bare lib-function calls in shipped fences"
t_assert_eq 0 "$(_count "$C12")" "check 12: no shipped fence calls an ossify/lib function directly${C12:+ -- $C12}"

# ===========================================================================
# PART 2 - the permanent self-test.
#
# One planted defect per check, each in its OWN file so no single mutation can
# disarm a plant by way of another one's precondition. The check-1 plant is
# deliberately INDENTED: it is extracted only if both fence regexes tolerate
# leading whitespace, so losing that tolerance costs a named RED here as well
# as the count mismatch above.
# ===========================================================================
FIX="$WORK/fixture"
mkdir -p "$FIX/bin" "$FIX/lib" "$FIX/commands" "$FIX/agents" \
         "$FIX/skills"/{c1,c2,c3,c5o,c5d,c6}/references

cat > "$FIX/bin/oss" <<'EOF'
#!/usr/bin/env bash
oss_cmd_help() { :; }
EOF
cat > "$FIX/lib/commands.sh" <<'EOF'
oss_cmd_alpha() { :; }
oss_cmd_beta() { :; }
EOF

# --- check 1 plant: an INDENTED block with an unquoted <placeholder> ---------
cat > "$FIX/skills/c1/SKILL.md" <<'EOF'
# c1
Read `references/c1ref.md`.

1. Run it:

   ```bash
   oss alpha <line-id>
   ```
EOF
echo "# c1ref" > "$FIX/skills/c1/references/c1ref.md"

# --- check 2 plant: one unresolvable verb, plus a bait for each exclusion rule
cat > "$FIX/skills/c2/SKILL.md" <<'EOF'
# c2
Read `references/c2ref.md`.

```bash
# runs across all spines, across every release, across the lines
oss alpha
oss nosuchverb "<arg>"
oss ledger_add_*
oss ledger_add_
```
EOF
echo "# c2ref" > "$FIX/skills/c2/references/c2ref.md"

# --- check 3 plant: a parameterized Skill() ---------------------------------
cat > "$FIX/skills/c3/SKILL.md" <<'EOF'
# c3
Read `references/c3ref.md`.

Invoke Skill(ossify:c3, target=spine) and wait.
EOF
echo "# c3ref" > "$FIX/skills/c3/references/c3ref.md"

# --- check 4 plant: a real positional, alongside the backticked warning ------
cat > "$FIX/commands/c4.md" <<'EOF'
# c4
Parse args from `$ARGUMENTS` via a trailing argument (no positional `$1`/`$2`/`$N`),
then hand off. This body reads $1 directly, which is the defect.
EOF

# --- check 5 plants: an orphan and a dangling pointer, in separate skills ----
cat > "$FIX/skills/c5o/SKILL.md" <<'EOF'
# c5o
Read `references/named.md`.
EOF
echo "# named" > "$FIX/skills/c5o/references/named.md"
echo "# orphan" > "$FIX/skills/c5o/references/orphan.md"

cat > "$FIX/skills/c5d/SKILL.md" <<'EOF'
# c5d
Read `references/c5dref.md`, then `references/nowhere.md`.
EOF
echo "# c5dref" > "$FIX/skills/c5d/references/c5dref.md"

# check 5 root-reference plants (Codex r1+r2 on #284): rr resolves bare
# (silent) and carries a QUALIFIED pointer that must keep its generic base
# (silent); rq dangles bare (fires); rs cites a file that exists ONLY under a
# sibling skill (fires - the sibling fallback must not swallow a root miss).
# Created HERE, before the F5 assertions run - plant order is execution order.
mkdir -p "$FIX/references"
echo "# root target" > "$FIX/references/rtarget.md"
printf -- '# rr\nSee `references/rtarget.md`; the skill-local form is `c5d/references/c5dref.md`.\n' > "$FIX/references/rr.md"
printf -- '# rq\nSee `references/rnothing.md`.\n' > "$FIX/references/rq.md"
printf -- '# rs\nSee `references/c5dref.md`.\n' > "$FIX/references/rs.md"

# --- check 6 plant: 501 lines -----------------------------------------------
{
  echo "# c6"
  echo "Read \`references/c6ref.md\`."
  i=3; while [ "$i" -le 501 ]; do echo "budget filler line $i"; i=$((i+1)); done
} > "$FIX/skills/c6/SKILL.md"
echo "# c6ref" > "$FIX/skills/c6/references/c6ref.md"

echo "# agent" > "$FIX/agents/a.md"

# --- check 7 plants: TWO DEDICATED ROOTS, deliberately not the shared $FIX ---
# The shared fixture's commands/c4.md carries no frontmatter description (it
# is check 4's plant), so running check 7 against $FIX would emit a
# no-description finding and couple this plant's count to check 4's fixture -
# the fixtures-coupled-through-shared-state vacuity mode. Separate roots keep
# the count exact and stable when a check 8 is added later.
FIX7="$WORK/fixture7"; FIX7B="$WORK/fixture7b"
_c7_command() { # $1=root $2=name $3=description-length
  mkdir -p "$1/commands"
  { echo "---"; echo "name: $2"
    printf 'description: '; printf 'd%.0s' $(seq 1 "$3"); echo
    echo "---"; echo "# $2"; } > "$1/commands/$2.md"
}
# Plant A: 14 commands = 4100 bytes (13 x 300 + 1 x 200), over the 3200 budget
# by 900 - and at the full fourteen-file count, so ONLY the ceiling arm fires.
for s in c7a c7b c7c c7d c7e c7f c7h c7i c7j c7k c7l c7n c7o; do _c7_command "$FIX7" "$s" 300; done
_c7_command "$FIX7" c7m2 200
# Plant B: only 2 commands, each comfortably under budget - the TOTAL passes,
# so the only thing that can fire is the floor guard. That is the assertion
# that makes check 7 unable to pass by measuring nothing.
for s in c7f c7g; do _c7_command "$FIX7B" "$s" 100; done
# Plant C: description only in the BODY, frontmatter empty of one - the whole
# file sed counted it and stayed green; the frontmatter-scoped extractor must
# call it what it is (no description, not counted).
FIX7C="$WORK/fixture7c"
mkdir -p "$FIX7C/commands"
printf -- '---\nname: c7m\n---\ndescription: %s\n# c7m\n' "$(printf 'd%.0s' $(seq 1 60))" > "$FIX7C/commands/c7m.md"

echo "-- self-test fixture: $FIX"

F1="$(check_1_parse "$FIX" "$WORK/fix1")"
FB="$(cat "$WORK/fix1/blocks/count.txt")"
# EXACT count, not a floor: an extractor returning zero blocks passes every
# parse check, and only an exact count on a controlled corpus can say otherwise.
t_assert_eq 2 "$FB" "self-test: exactly 2 bash blocks extracted from the fixture (one of them indented)"
t_assert_eq 1 "$(_count "$F1")" "self-test: check 1 finds exactly its 1 planted parse failure${F1:+ -- $F1}"
t_assert_contains "$F1" "c1/SKILL.md:7" "self-test: check 1 names the planted file and the mapped source line"

F2="$(check_2_verbs "$FIX" "$WORK/fix2")"
t_assert_eq 1 "$(_count "$F2")" "self-test: check 2 finds exactly its 1 planted unresolvable verb${F2:+ -- $F2}"
t_assert_contains "$F2" "'oss nosuchverb'" "self-test: check 2 names the planted verb"
t_assert_grep "$WORK/fix2/check2-excluded.txt" 'oss ledger_add_\*$' "self-test: check 2 excludes the * wildcard mention by rule"
t_assert_grep "$WORK/fix2/check2-excluded.txt" 'oss ledger_add_$' "self-test: check 2 excludes the trailing-underscore mention by rule"

F3="$(check_3_skill_args "$FIX")"
t_assert_eq 1 "$(_count "$F3")" "self-test: check 3 finds exactly its 1 planted parameterized Skill()${F3:+ -- $F3}"
t_assert_contains "$F3" "c3/SKILL.md:4" "self-test: check 3 names the planted file and line"

F4="$(check_4_positionals "$FIX")"
t_assert_eq 1 "$(_count "$F4")" "self-test: check 4 finds exactly its 1 planted positional, not the backticked warning${F4:+ -- $F4}"
t_assert_contains "$F4" "c4.md:3" "self-test: check 4 names the planted line, not line 2's backticked warning"

F5="$(check_5_refs "$FIX" "$WORK/fix5")"
t_assert_eq 4 "$(_count "$F5")" "self-test: check 5 finds exactly its 4 planted defects (1 orphan, 1 skill dangling, 1 root bare dangling, 1 sibling-swallowed root miss)${F5:+ -- $F5}"
t_assert_contains "$F5" "orphan.md: orphan" "self-test: check 5 names the planted orphan"
t_assert_contains "$F5" "dangling pointer 'references/nowhere.md'" "self-test: check 5 names the planted dangling pointer"
t_assert_contains "$F5" "dangling pointer 'references/rnothing.md'" "self-test: check 5 names the root-reference dangling pointer"
t_assert_contains "$F5" "dangling pointer 'references/c5dref.md'" "self-test: a root citation that exists only under a sibling skill still dangles"

F6="$(check_6_budget "$FIX" "$WORK/fix6")"
t_assert_eq 1 "$(_count "$F6")" "self-test: check 6 finds exactly its 1 planted over-budget SKILL.md${F6:+ -- $F6}"
t_assert_contains "$F6" "c6/SKILL.md:501" "self-test: check 6 names the planted file and its line count"

F7="$(check_7_descriptions "$FIX7" "$WORK/fix7")"
t_assert_eq 1 "$(_count "$F7")" "self-test: check 7 finds exactly its 1 planted over-budget command set${F7:+ -- $F7}"
t_assert_contains "$F7" "total 4100 bytes" "self-test: check 7 names the measured total, not just that it is over"
t_assert_contains "$F7" "over the 3200 every-call budget by 900" "self-test: check 7 names the exact overage"
# The floor guard: a root the loop under-measures must RED even though its
# total is far under budget. Without this, a glob that matched nothing would
# sum to 0 and sail through - the way a budget check ends up unable to fail.
F7B="$(check_7_descriptions "$FIX7B" "$WORK/fix7b")"
t_assert_eq 1 "$(_count "$F7B")" "self-test: check 7 fires on an under-measured set even though its total passes${F7B:+ -- $F7B}"
t_assert_contains "$F7B" "saw only 2 command files" "self-test: check 7's floor guard names how many it actually saw"
F7C="$(check_7_descriptions "$FIX7C" "$WORK/fix7c")"
t_assert_eq 2 "$(_count "$F7C")" "self-test: check 7 flags a body-only description AND its floor (2 findings, not a green budget)${F7C:+ -- $F7C}"
t_assert_contains "$F7C" "c7m.md: no frontmatter description" "self-test: check 7 names the body-only-description wrapper"
t_assert_grep "$WORK/fix7c/check7-report.txt" 'TOTAL 0 ' "self-test: the 60-byte body line is NOT counted toward the budget"

# --- check 9 plants: a DEDICATED ROOT, for the same coupling reason as check
# 7's - the shared fixture cannot host this: skills/c3's body (check 3's plant)
# literally contains Skill(ossify:c3, ...) and would cross-fire.
FIX9="$WORK/fixture9"
mkdir -p "$FIX9/skills/c9" "$FIX9/skills/c9u" "$FIX9/references" "$FIX9/commands"
printf -- '# c9\nInvoke Skill(ossify:c9) and wait.\n' > "$FIX9/skills/c9/SKILL.md"
# r9 (Codex r1 on #284): a shadowed token in the plugin-root references tree
# that _md_files did not own before the widening.
printf -- '# r9\nAlso invoke Skill(ossify:r9) here.\n' > "$FIX9/references/r9.md"
# The shadow condition (Codex r2): both plants are shadowed because their
# same-named COMMANDS exist. c9u has no command - its token is legal and must
# NOT fire; the exact-count assertion is that control.
echo "# wrapper c9" > "$FIX9/commands/c9.md"
echo "# wrapper r9" > "$FIX9/commands/r9.md"
printf -- '# c9u\nCompose Skill(ossify:c9u) freely - no command shadows it.\n' > "$FIX9/skills/c9u/SKILL.md"

F9="$(check_9_shadowed_tokens "$FIX9")"
t_assert_eq 2 "$(_count "$F9")" "self-test: check 9 fires on both shadowed plants AND stays silent on the unshadowed control (count 2, not 3)${F9:+ -- $F9}"
t_assert_contains "$F9" "c9/SKILL.md:2" "self-test: check 9 names the skills-tree plant"
t_assert_contains "$F9" "references/r9.md:2" "self-test: check 9 names the references-tree plant"

# --- check 10 plant: a DEDICATED ROOT - a planted bash block in the shared
# fixture would inflate fix1's exact block count, the same coupling check 7
# and check 9 avoid. The guarded twins sit beside the defect: they must NOT
# fire, and the exact count is the control.
FIX10="$WORK/fixture10"; mkdir -p "$FIX10/skills/c10/references"
cat > "$FIX10/skills/c10/SKILL.md" <<'EOF'
# c10
Read `references/c10ref.md`.

```bash
cd "<wt>" && pytest tests/test_x.py; echo "rc=$?"
if ( cd "<wt>" && pytest tests/test_y.py ) > out.txt 2>&1; then rc=0; else rc=$?; fi
rc=0; diff a.txt b.txt || rc=$?
# comment documenting the bad form: cmd; rc=$?
```
EOF
echo "# c10ref" > "$FIX10/skills/c10/references/c10ref.md"

check_1_parse "$FIX10" "$WORK/fix10" >/dev/null
F10="$(check_10_errexit_captures "$WORK/fix10/blocks")"
t_assert_eq 1 "$(_count "$F10")" "self-test: check 10 finds exactly its 1 planted unguarded read - the else-arm, the || chain, and the comment do not fire${F10:+ -- $F10}"
t_assert_contains "$F10" "c10/SKILL.md:5" "self-test: check 10 names the planted file and line"

# --- check 10's negated-condition plant: its OWN ROOT again - the shared
# fixture cannot host it without inflating fix1's exact block count, and FIX10
# cannot either (its exact-count assertion is the control for THIS check's
# other arm). Four negated captures must fire; the two controls beside them
# must not, and the exact count is what proves that.
FIX10N="$WORK/fixture10n"; mkdir -p "$FIX10N/skills/c10n/references"
cat > "$FIX10N/skills/c10n/references/neg.md" <<'EOF'
# c10n negated captures
```bash
if ! "$x" verify_step a b c; then rc=$?; fi
if ! false; then
  rc2=$?
fi
if ! true; then echo no; else rc3=$?; fi
rc4=0; ! false || rc4=$?
if false; then rc5=0; else rc5=$?; fi
if ! true; then echo ok; fi; rc6=0; true || rc6=$?
if ! false; then :; fi; if false; then :; else rc7=$?; fi
```
EOF

check_1_parse "$FIX10N" "$WORK/fix10n" >/dev/null
F10N="$(check_10_errexit_captures "$WORK/fix10n/blocks" | { grep -F 'after a negated condition' || true; })"
t_assert_eq 4 "$(_count "$F10N")" "self-test: check 10 flags each status read after a negated condition (if !…then, then-on-next-line, else arm, ! …||) and neither control${F10N:+ -- $F10N}"
case "$F10N" in *"neg.md:9"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: self-test: check 10 attributes a read to the if ! that owns it - line 9's else-arm belongs to a DIFFERENT, un-negated if";; *) T_PASS=$((T_PASS+1));; esac

# --- checks 11 and 12 plants: one more dedicated root. Four fences, one plant
# each plus the control that must stay quiet - the assigned `oss_bin` read
# (check 11) and the commented citation (check 12). Exact counts are the
# controls.
FIX11="$WORK/fixture11"; mkdir -p "$FIX11/skills/c11"
cat > "$FIX11/skills/c11/SKILL.md" <<'EOF'
# c11

```bash
"$oss_bin" help
```

```bash
oss_bin="$(command -v oss)"; "$oss_bin" help
```

```bash
oss_verify_parse_acs spec.md
```

```bash
# oss_verify_parse_acs is cited here
oss verify_acs spec.md
```

```bash
"$oss_binary" help
```

```bash
printf '%s\n' oss_verify_parse_acs
```
EOF

check_1_parse "$FIX11" "$WORK/fix11" >/dev/null
C11F="$(check_11_oss_bin_assigned "$WORK/fix11/blocks")"
t_assert_eq 1 "$(_count "$C11F")" "self-test: check 11 fires on the unassigned \$oss_bin read and not on the assigned control or \$oss_binary${C11F:+ -- $C11F}"
t_assert_contains "$C11F" "c11/SKILL.md:4" "self-test: check 11 names the unassigned read"
C12F="$(check_12_no_lib_calls "$OSSIFY" "$WORK/fix11/blocks")"
t_assert_eq 1 "$(_count "$C12F")" "self-test: check 12 fires on the bare lib call and not on the commented citation, the oss verb, or a NAME passed as an argument${C12F:+ -- $C12F}"
t_assert_contains "$C12F" "c11/SKILL.md:12" "self-test: check 12 names the bare lib call"

t_summary
