#!/usr/bin/env bash
# The executable-prose gate (#138), skeleton layer.
#
# It does NOT execute every operative block - block-ledger.tsv names the
# deferred blocks. What it DOES guarantee is that no block can be added,
# removed, or re-fenced without someone classifying it, and that every anchor a
# test extracts on is a real, unique identity.
#
# The four defect classes this is scaffolding for were all parse-clean:
# a quoted wildcard, a cut from the wrong base, a discarded rc, and a guard
# variable nothing assigned. See tests/lib/blocks.sh for the full account.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSS_TREE="$(cd "$HERE/.." && pwd)"
LEDGER="$HERE/block-ledger.tsv"
TMPOUT="$(mktemp)"
. "$HERE/lib/blocks.sh"
FIX="$(mktemp -d)"
trap 'chmod -R u+rwx "$FIX"; rm -rf "$FIX" "$TMPOUT"' EXIT

PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $*"; }

ledger_completeness_files() { # $1=ossify-root
  local completeness_listing status file
  if completeness_listing="$(cd "$1" && find skills commands agents -name '*.md')"; then
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      if [ ! -f "$1/$file" ] || [ ! -r "$1/$file" ]; then
        printf 'ledger completeness scan: %s: not a readable regular file\n' "$1/$file" >&2
        return 1
      fi
    done <<< "$completeness_listing"
    printf '%s\n' "$completeness_listing" | sort
  else
    status=$?
    printf 'ledger completeness scan: %s: find exited %s\n' "$1" "$status" >&2
    return "$status"
  fi
}

ledger_digest_files() { # $1=ossify-root
  local digest_listing status file
  if digest_listing="$(cd "$1" && find skills commands agents -name '*.md')"; then
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      if [ ! -f "$1/$file" ] || [ ! -r "$1/$file" ]; then
        printf 'ledger digest coverage scan: %s: not a readable regular file\n' "$1/$file" >&2
        return 1
      fi
    done <<< "$digest_listing"
    printf '%s\n' "$digest_listing" | sort
  else
    status=$?
    printf 'ledger digest coverage scan: %s: find exited %s\n' "$1" "$status" >&2
    return "$status"
  fi
}

ledger_find_controls() {
  local root="$FIX/find-control" scan label out rc
  mkdir -p "$root/skills/locked" "$root/commands" "$root/agents"
  printf '# visible\n' > "$root/skills/visible.md"
  printf '# hidden\n' > "$root/skills/locked/hidden.md"
  for scan in ledger_completeness_files ledger_digest_files; do
    case "$scan" in
      ledger_completeness_files) label='ledger completeness' ;;
      ledger_digest_files) label='ledger digest coverage' ;;
    esac
    if [ "$(id -u)" -eq 0 ]; then
      echo "SKIP: $label unreadable-directory control (uid 0 bypasses chmod 000)"
    else
      chmod 000 "$root/skills/locked"
      out="$("$scan" "$root" 2>&1)"; rc=$?
      chmod 700 "$root/skills/locked"
      if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | awk -v prefix="$label scan: $root: find exited " \
          'index($0, prefix)==1 && substr($0, length(prefix)+1) ~ /^[1-9][0-9]*$/ { hit++ } END { exit(hit != 1) }'; then
        pass
      else
        fail "control: $label must reject an unreadable subtree by name, root and status (rc=$rc): $out"
      fi
    fi
    out="$("$scan" "$root" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ] && [ "$out" = "$(printf 'skills/locked/hidden.md\nskills/visible.md')" ]; then
      pass
    else
      fail "control: $label must enumerate the adjacent readable tree (rc=$rc): $out"
    fi
  done
}

ledger_file_controls() {
  local root scan label out rc
  for scan in ledger_completeness_files ledger_digest_files; do
    root="$FIX/file-control/$scan"
    mkdir -p "$root/skills" "$root/commands" "$root/agents"
    printf '# readable\n' > "$root/skills/visible.md"
    case "$scan" in
      ledger_completeness_files) label='ledger completeness' ;;
      ledger_digest_files) label='ledger digest coverage' ;;
    esac
    out="$("$scan" "$root" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ] && [ "$out" = 'skills/visible.md' ]; then
      pass
    else
      fail "control: $label must enumerate the adjacent readable file tree (rc=$rc): $out"
    fi
    printf '```bash\necho unclassified_block\n```\n' > "$root/skills/hidden.md"
    if [ "$(id -u)" -eq 0 ]; then
      echo "SKIP: $label unreadable-file control (uid 0 bypasses chmod 000)"
    else
      chmod 000 "$root/skills/hidden.md"
      out="$("$scan" "$root" 2>&1)"; rc=$?
      chmod 600 "$root/skills/hidden.md"
      if [ "$rc" -ne 0 ] && [ "$out" = "$label scan: $root/skills/hidden.md: not a readable regular file" ]; then
        pass
      else
        fail "control: $label must reject an unreadable regular file by path (rc=$rc): $out"
      fi
    fi
  done
}

ledger_find_controls
ledger_file_controls

echo "-- ossify tree: $OSS_TREE"

# ---------------------------------------------------------------------------
# check 1 - the ledger parses, and every row is one of the three known types.
# ---------------------------------------------------------------------------
rows=0
while IFS=$'\t' read -r kind file c4 c5 c6; do
  case "$kind" in ''|'#'*) continue ;; esac
  rows=$((rows+1))
  case "$kind" in
    O) [ -n "${c5:-}" ] || fail "O row for $file has no covered-by" ;;
    D|I) case "${c4:-}" in ''|*[!0-9]*) fail "$kind row for $file has a non-numeric count: '${c4:-}'" ;; esac ;;
    H) [ -n "${c4:-}" ] || fail "H row for $file has no digest" ;;
    *) fail "unknown ledger row type '$kind' (expected O, D, I or H)" ;;
  esac
done < "$LEDGER"
[ "$rows" -gt 0 ] && pass || fail "check 1: the ledger is empty - every assertion below would be vacuous"
echo "-- check 1: $rows ledger rows"

# ---------------------------------------------------------------------------
# check 2 - THE COMPLETENESS INVARIANT.
# Per file: O-rows + D-count + I-count must equal the blocks actually present.
# This is what makes uncovered surface DECLARED rather than assumed, and what
# turns any inserted or deleted block into a red test until it is classified.
# ---------------------------------------------------------------------------
declare_counted() { # $1=file ; echoes "O D I" totals from the ledger
  awk -F'\t' -v f="$1" '
    $1=="O" && $2==f { o++ }
    $1=="D" && $2==f { d += $3 }
    $1=="I" && $2==f { i += $3 }
    END { print (o+0), (d+0), (i+0) }
  ' "$LEDGER"
}

# Enumerate every shipped markdown file that HAS a bash block, from the tree -
# never from the ledger. Driving this loop off the ledger would make a file
# that is missing from the ledger entirely invisible, which is the one gap this
# check exists to close.
shipped=0; accounted=0
if completeness_files="$(ledger_completeness_files "$OSS_TREE" 2>&1)"; then
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  actual="$(oss_block_count "$OSS_TREE/$rel")"
  # NO `continue` ON ZERO. A file that still exists but whose last block was
  # removed or re-fenced used to skip completeness entirely, leaving a stale
  # D row claiming debt for a block that is gone. (Codex P2 round 4 on PR #144,
  # reproduced by re-fencing commands/close.md and updating its H digest to the
  # empty-file value: `159 blocks accounted for`, fail=0.) A file with no blocks
  # must have no rows, and that is an assertion, not a skip.
  if [ "$actual" -eq 0 ]; then
    read -r o d i <<<"$(declare_counted "$rel")"
    if [ $((o+d+i)) -eq 0 ]; then pass; else
      fail "check 2: $rel has no bash blocks but the ledger still claims $((o+d+i)) (O=$o D=$d I=$i) - remove its rows"
    fi
    continue
  fi
  shipped=$((shipped+1))
  read -r o d i <<<"$(declare_counted "$rel")"
  sum=$((o+d+i))
  if [ "$sum" -eq "$actual" ]; then
    accounted=$((accounted+actual)); pass
  else
    fail "check 2: $rel has $actual blocks but the ledger accounts for $sum (O=$o D=$d I=$i) - classify the difference"
  fi
done <<< "$completeness_files"
else
  fail "$completeness_files"
fi

echo "-- check 2: $shipped files with blocks, $accounted blocks accounted for"

# check 2b - THE REVERSE DIRECTION. The walk above visits the tree, so deleting
# a file whole removes it from the walk and its D/I rows are simply never read.
# Verified: `rm commands/close.md` left 47 files / 159 blocks and fail=0,
# because the count stayed above the floor. (Codex P2 on PR #144.)
# Every path the ledger names must therefore still exist.
while IFS= read -r lf; do
  if [ -f "$OSS_TREE/$lf" ]; then pass; else
    fail "check 2b: the ledger names $lf, which no longer exists - delete its rows or restore the file"
  fi
done < <(awk -F'\t' '/^[ODI]\t/ {print $2}' "$LEDGER" | sort -u)

# check 2c - the same-count SWAP the completeness invariant cannot see.
# A per-file digest over block BODIES: change any block's content and this goes
# red, even when the block count is identical. Prose edits around blocks do not
# churn it. The expected value is printed on mismatch so updating is mechanical.
digests=0
while IFS=$'\t' read -r _kind file want _rest; do
  digests=$((digests+1))
  got="$(oss_block_digest "$OSS_TREE/$file" 2>/dev/null || echo MISSING)"
  if [ "$got" = "$want" ]; then pass; else
    fail "check 2c: $file block bodies changed (ledger $want, tree $got) - re-read its blocks, confirm the O/D/I split still holds, then update the H row"
  fi
done < <(grep -E '^H'$'\t' "$LEDGER" || true)
echo "-- check 2c: $digests per-file block digests"

# EXACTLY ONE H row per shipped file, checked per path rather than by comparing
# totals. An aggregate count is satisfied when one file loses its H row and
# another is duplicated - and the file without one silently stops being digest-
# checked, which is the whole protection. (Codex P2 round 2 on PR #144.)
if digest_files="$(ledger_digest_files "$OSS_TREE" 2>&1)"; then
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  [ "$(oss_block_count "$OSS_TREE/$rel")" -gt 0 ] || continue
  n="$(awk -F'\t' -v f="$rel" '$1=="H" && $2==f {n++} END{print n+0}' "$LEDGER")"
  case "$n" in
    1) pass ;;
    0) fail "check 2c: $rel has blocks but no H row - its block bodies are unchecked" ;;
    *) fail "check 2c: $rel has $n H rows - duplicates let one file's digest stand in for another's" ;;
  esac
done <<< "$digest_files"
else
  fail "$digest_files"
fi
# A floor, not just a per-file equality: if the enumeration itself broke and
# produced zero files, every per-file assertion above would be vacuously true.
if [ "$shipped" -ge 40 ]; then pass; else fail "check 2: only $shipped files enumerated - the file walk is broken, the per-file checks above are vacuous"; fi

# ---------------------------------------------------------------------------
# check 3 - every O-row anchor resolves to EXACTLY ONE block.
# The pre-#138 extractor stopped at the first match, so a non-unique anchor
# bound silently to whichever block came first - and would silently REBIND if a
# block were inserted above it. An anchor that is not unique is not an identity.
# ---------------------------------------------------------------------------
anchors=0
while IFS=$'\t' read -r kind file anchor covered_by _guards; do
  [ "$kind" = "O" ] || continue
  anchors=$((anchors+1))
  n="$(oss_block_matches "$OSS_TREE/$file" "$anchor")"
  case "$n" in
    1) pass ;;
    0) fail "check 3: anchor '$anchor' matches NO block in $file - the extraction it names is vacuous" ;;
    *) fail "check 3: anchor '$anchor' matches $n blocks in $file - not an identity" ;;
  esac
done < <(grep -E '^O' "$LEDGER" || true)
# Report the count, not a verdict. An earlier form said "each resolving
# uniquely" unconditionally, which printed a false claim directly beneath its
# own failures - the same prose-contradicts-behaviour class this gate exists
# to catch.
echo "-- check 3: $anchors covered-block anchors checked for unique resolution"

# check 3b - two O rows in the same file must not resolve to the SAME block.
# Each row above is checked in isolation, so duplicating an O row and
# decrementing that file's D or I count keeps the completeness sum, the anchor
# uniqueness, the digest and the covered-by claims all green - while one real
# block drops out of the ledger with nothing pointing at it. Completeness
# counts O rows as distinct blocks; this is what makes that true rather than
# assumed. (Codex P2 round 2 on PR #144.)
dupes="$(
  while IFS=$'\t' read -r _k file anchor _rest; do
    printf '%s\t%s\n' "$file" "$(oss_block_index_of "$OSS_TREE/$file" "$anchor")"
  done < <(grep -E '^O'$'\t' "$LEDGER" || true) | sort | uniq -d
)"
if [ -z "$dupes" ]; then pass; else
  fail "check 3b: two O rows resolve to the same block - $(printf '%s' "$dupes" | tr '\n' ' ')"
fi
if [ "$anchors" -ge 10 ]; then pass; else fail "check 3: only $anchors anchors found - the O-row grep is broken, check 3 is vacuous"; fi

# ---------------------------------------------------------------------------
# check 4 - every covered-by claim is real: the named test file exists AND
# actually mentions the anchor. A ledger that claims coverage a test does not
# provide is worse than an honest D row.
# ---------------------------------------------------------------------------
while IFS=$'\t' read -r kind file anchor covered_by _guards; do
  [ "$kind" = "O" ] || continue
  # covered-by is ossify-relative, like every other path in the ledger.
  t="$OSS_TREE/$covered_by"
  if [ ! -f "$t" ]; then
    fail "check 4: $file claims coverage by '$covered_by', which does not exist"
    continue
  fi
  # COMMENT LINES DO NOT COUNT, and this is not fussiness. Verified by
  # mutation: repointing test-close.sh's cumulative-demo extraction from
  # `elapsed=` to `demo_rc` left the ledger's claim satisfied, because the
  # comment ABOVE the call - the one explaining the anchor rule - still said
  # `elapsed=`. A plain grep certified coverage that had just been removed.
  #
  # The anchor must appear on a line that ALSO carries an extraction construct.
  # Matching the anchor anywhere in the test file is far too weak: `is-ancestor`
  # occurs on SEVEN non-comment lines of test-close.sh, only one of which is the
  # extraction, so repointing that one left check 4 green with the coverage
  # gone. (Codex P2 on PR #144 - the same class as the comment bug below, one
  # level deeper.) Both extraction forms in use are accepted: the shared
  # `oss_block_extract`/`_extract_block` call, and impl-check's inline
  # `awk ... buf ~ /anchor/`.
  #
  # Comment lines still do not count. Verified by mutation: repointing the
  # cumulative-demo extraction from `elapsed=` to `demo_rc` left the claim
  # satisfied, because the COMMENT above the call - the one explaining the
  # anchor rule - still said `elapsed=`.
  #
  # ONE awk pass, deliberately NOT `grep -v '#' | grep -Fq`. Under this file's
  # `set -o pipefail`, the downstream `grep -q` exits on its first match and
  # SIGPIPEs the upstream grep, so the pipeline reports failure for a line that
  # genuinely matched. That form failed a TRUE coverage claim.
  # `index()` is a literal substring test, so anchors containing regex
  # metacharacters compare as themselves.
  # The extraction line must also name the LEDGER'S SOURCE FILE. Requiring only
  # anchor + extraction construct still lets a call be repointed at a different
  # markdown source with its anchor unchanged, preserving a false covered-by
  # claim. (Codex P2 round 2 on PR #144.) The tests pass the source as a shell
  # variable, so resolve `VAR="..."` assignments in the test file first, expand
  # the extraction call's first argument, and require the ledger's path to be a
  # suffix of it. This is why every extraction was normalised to a single
  # `_extract_block <source-var> <anchor> <out>` line.
  # The FULL ledger path, with the test's own root variables resolved - not a
  # suffix. Stripping the first component and suffix-matching accepted
  # "$FIXTURES/close/references/spine-close.md", so a test could extract and
  # execute a stale mirror while the O row claimed coverage of the shipped
  # markdown. (Codex P2 round 4 on PR #144.) `$SKILLS` is the tree's one
  # documented root for shipped prose, so resolve exactly that.
  tail="$file"
  if awk -v a="$anchor" -v tail="$tail" '
       # Collect VAR="value" assignments VERBATIM. Deliberately no recursive
       # expansion: substituting $VARs invites prefix collisions - $SP (a real
       # variable in test-close.sh) matches inside $SPINE_CLOSE and corrupts the
       # path. Comparing the raw value by suffix needs no expansion at all.
       /^[A-Za-z_][A-Za-z0-9_]*=/ {
         eq = index($0,"="); name = substr($0,1,eq-1); val = substr($0,eq+1)
         if (match(val, /^"[^"]*"/)) val = substr(val, RSTART+1, RLENGTH-2)
         else sub(/[[:space:];].*$/, "", val)
         v[name] = val
       }
       index($0,a) && $0 !~ /^[[:space:]]*#/ &&
       (index($0,"_extract_block") || index($0,"oss_block_extract")) {
         p = index($0,"_extract_block"); if (!p) p = index($0,"oss_block_extract")
         rest = substr($0, p); sub(/^[A-Za-z_]+[[:space:]]+/, "", rest)
         arg = rest; sub(/[[:space:]].*$/, "", arg)
         gsub(/["\047$]/, "", arg)
         src = (arg in v) ? v[arg] : arg
         # Resolve the ONE sanctioned root for shipped prose. Anything else -
         # a fixture root, a copy, a temp dir - stays unresolved and cannot
         # match the ledger path, which is the point.
         gsub(/^\$SKILLS\//, "skills/", src)
         gsub(/^\$\{SKILLS\}\//, "skills/", src)
         if (src == tail) {
           # Remember the OUT variable so check 4b can prove it is EXECUTED.
           # Take the LAST "$VAR" on the line rather than splitting on
           # whitespace: anchors contain spaces ("work items that are not
           # complete"), so positional splitting picks a word out of the middle
           # of the anchor and yields nonsense like $items or $-q.
           out = ""; s = rest
           while (match(s, /"\$[A-Za-z_][A-Za-z0-9_]*"/)) {
             out = substr(s, RSTART+2, RLENGTH-3)
             s = substr(s, RSTART+RLENGTH)
           }
           print out > "/dev/stderr"
           found = 1; exit
         }
       }
       END { exit !found }' "$t" 2>"$TMPOUT"; then pass; else
    fail "check 4: $covered_by never extracts anchor '$anchor' FROM $file - the coverage claim is false (anchor missing, not an extraction call, or pointed at another source)"
    continue
  fi

  # check 4b - EXTRACTION IS NOT EXECUTION, and an O row promises both.
  # Deleting the `t_capture … . '$OUT'` line and its assertions while leaving
  # the `_extract_block` call in place satisfied every check above, so the row
  # still claimed coverage for a block nothing ran. (Codex P2 round 3 on
  # PR #144.) Require the extraction's OUT variable to be dot-sourced somewhere
  # in the same test - which is how all eleven are actually executed.
  outvar="$(cat "$TMPOUT" 2>/dev/null | head -1)"
  if [ -z "$outvar" ]; then
    fail "check 4b: could not determine the output variable for '$anchor' in $covered_by"
  # COMMENTED-OUT EXECUTION DOES NOT COUNT — the THIRD time a comment has
  # defeated a check in this file. Commenting the `t_capture … . '$BLOCK'` line
  # and deleting its assertions left both this file and test-close.sh green,
  # the latter landing at 182 against its 180 floor. (Codex P2 round 4 on
  # PR #144.) Same single-awk-pass form as check 4, and for the same pipefail
  # reason.
  elif awk -v ov="$outvar" '
         $0 ~ /^[[:space:]]*#/ { next }
         $0 ~ ("\\.[[:space:]]+[\"'"'"']\\$" ov "[\"'"'"']") { found=1; exit }
         END { exit !found }' "$t"; then pass; else
    fail "check 4b: $covered_by extracts '$anchor' into \$$outvar but never sources it - extraction is not execution"
  fi
done < <(grep -E '^O' "$LEDGER" || true)

# ---------------------------------------------------------------------------
# check 5 - the harness itself works. A self-test, because every check above
# rests on oss_block_extract, and an extractor that silently returns nothing
# would make the whole file pass while testing air.
# ---------------------------------------------------------------------------
# FIX and its permission-restoring trap are installed before traversal controls.
cat > "$FIX/f.md" <<'EOF'
prose
```bash
alpha_marker=1
echo one
```
more prose
```bash
beta_marker=2
echo two
```
```bash
alpha_marker=3
echo three
```
EOF
[ "$(oss_block_count "$FIX/f.md")" = 3 ] && pass || fail "check 5: block count on the fixture is not 3"

out="$FIX/o.sh"
if oss_block_extract "$FIX/f.md" 'beta_marker' "$out" >/dev/null 2>&1 && grep -q 'echo two' "$out"; then pass
else fail "check 5: extracting a unique anchor failed"; fi

# ambiguity must be rc 2 and must NOT be reported as vacuous
oss_block_extract "$FIX/f.md" 'alpha_marker' "$FIX/amb.sh" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && pass || fail "check 5: a duplicated anchor returned rc $rc, expected 2 (ambiguous)"

# a missing anchor must be rc 1 (vacuous), distinct from ambiguity
oss_block_extract "$FIX/f.md" 'nothing_matches_this' "$FIX/miss.sh" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && pass || fail "check 5: a missing anchor returned rc $rc, expected 1 (vacuous)"

echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
