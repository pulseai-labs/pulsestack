#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Layer 4 delegated-path residue gate (#507).
#
# The delegated engine (the Workflow-tool script, its selection conditions, its
# fingerprint guard, its fallback and its print contract) is deleted. Since #951
# Layer 4 runs in a registered verifier agent, or inline where none can be
# dispatched - never through that engine. This test is the tripwire against a half-deletion:
# any shipped ossify file still naming the mechanism goes RED here, naming the
# file, the line and the needle that hit.
#
# SCOPE, stated plainly:
#   - Scanned: every file under ossify/ EXCEPT this test itself and the eval
#     run records (tests/eval/results/, tests/eval/evidence/) - those are
#     historical judgment records that legitimately name the mechanism that
#     ran, exactly as field verify.md files do. Fixture prose and rubrics are
#     NOT exempt: a scenario or scoring rule describing the deleted path as
#     current behaviour is residue, not history.
#   - Outside ossify/ only the mechanism-UNIQUE needles are scanned, and only
#     over README.md: the root README carries every plugin's row, so a generic
#     word there could fail an ossify test over another plugin's text.
#
# Needles are LITERAL substrings matched with awk index(), never regex - the
# same counting discipline as test-external-executor-contract.sh. And index()
# is exactly why every needle is anchored to THIS mechanism's shape - a path,
# an env var, a schema field, a print string, a backticked tool name or a
# hyphenated compound - and why no bare English word is a needle: a substring
# cannot tell "the `.github/workflows/tests.yml` pointer" or a sentence-initial
# "Workflow" or "the release workflows" from the deleted engine, and a gate
# that flags legitimate prose trains its reader to dismiss the red. What a
# substring cannot say is carried structurally instead: the directory is gone,
# and no `allowed-tools:` line grants the tool. §4's false-positive control
# proves the needle set is clean on legitimate prose as a class, not only on
# today's tree.
#
# POSITIVE PINS ride beside the absences: the deletion must not eat the inline
# path - the handoff.md halt, the verify.md overwrite rule, the three section
# 4b lens ids and the undeclared-fidelity halt all survive, and these pins make
# an over-deletion fail rather than go quiet.
# ---------------------------------------------------------------------------
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
OSSIFY="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$OSSIFY/.." && pwd)"
SELF="$(basename "$0")"
TMPDIR_WORK="$(mktemp -d "${TMPDIR:-/tmp}/l4-residue.XXXXXX")"
trap 'chmod -R u+rwx "$TMPDIR_WORK"; rm -rf "$TMPDIR_WORK"' EXIT

WIC="$OSSIFY/skills/close/references/work-item-close.md"
IMPL="$OSSIFY/skills/close/references/impl-check.md"

# ---------------------------------------------------------------------------
# 0. The inline path survives - absence-only checks pass vacuously on an
#    over-deleted tree, so the keep-half is asserted first.
# ---------------------------------------------------------------------------
for needle in 'no handoff.md' 'overwrites `verify.md`'; do
  if awk -v needle="$needle" 'index($0, needle) { found=1; exit } END { exit !found }' "$WIC"; then T_PASS=$((T_PASS+1))
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md lost '$needle' - the inline path was deleted, not just the delegated one"; fi
done
for needle in '- `fidelity` —' '- `pattern` —' '- `absence` —' 'declared_in_report_s7: false'; do
  if awk -v needle="$needle" 'index($0, needle) { found=1; exit } END { exit !found }' "$IMPL"; then T_PASS=$((T_PASS+1))
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: impl-check.md lost '$needle' - the lenses or the halt rule were deleted with the mechanism"; fi
done

# ---------------------------------------------------------------------------
# 1. Structural residue: the directory and the dedicated suite are gone, and
#    no allowed-tools grant names the tool. The grant check is structural
#    because the substring test cannot be: the frontmatter key is anchored at
#    column 0, and "Workflow" on that line is a grant, never prose.
# ---------------------------------------------------------------------------
[ ! -d "$OSSIFY/workflows" ] && T_PASS=$((T_PASS+1)) \
  || { T_FAIL=$((T_FAIL+1)); echo "FAIL: ossify/workflows/ still exists"; }
[ ! -e "$HERE/test-workflows.sh" ] && T_PASS=$((T_PASS+1)) \
  || { T_FAIL=$((T_FAIL+1)); echo "FAIL: ossify/tests/test-workflows.sh still exists"; }

# ---------------------------------------------------------------------------
# 2. The needle lists. One literal per line so a needle with spaces needs no
#    escaping. INNER applies across the ossify scan scope; OUTER is the
#    mechanism-unique subset allowed on files outside ossify/.
# ---------------------------------------------------------------------------
NEEDLES_INNER="$TMPDIR_WORK/needles-inner"
cat > "$NEEDLES_INNER" <<'NEEDLES'
verify-work-item
OSSIFY_NO_WORKFLOWS
fidelity_truncated
agents_run
pre_fp
post_fp
ossify/workflows
test-workflows
`Workflow`
layer 4: workflow
workflow unavailable
(6 agents
six-agent
NEEDLES

NEEDLES_OUTER="$TMPDIR_WORK/needles-outer"
cat > "$NEEDLES_OUTER" <<'NEEDLES'
verify-work-item
OSSIFY_NO_WORKFLOWS
fidelity_truncated
agents_run
layer 4: workflow
(6 agents
six-agent
NEEDLES

residue_files() { # $1=ossify-root $2=self basename
  local files status f
  if files="$(find "$1" -type f \
      -not -path "$1/tests/eval/results/*" \
      -not -path "$1/tests/eval/evidence/*" \
      -not -name "$2")"; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if [ ! -f "$f" ] || [ ! -r "$f" ]; then
        printf 'layer4 residue scan: %s: not a readable regular file\n' "$f" >&2
        return 1
      fi
    done <<< "$files"
    printf '%s\n' "$files" | LC_ALL=C sort
  else
    status=$?
    printf 'layer4 residue scan: %s: find exited %s\n' "$1" "$status" >&2
    return "$status"
  fi
}

residue_find_controls() {
  local root="$TMPDIR_WORK/find-control" out rc
  mkdir -p "$root/locked"
  printf '# visible\n' > "$root/visible.md"
  printf '# hidden\n' > "$root/locked/hidden.md"
  if [ "$(id -u)" -eq 0 ]; then
    echo 'SKIP: layer4 residue unreadable-directory control (uid 0 bypasses chmod 000)'
  else
    chmod 000 "$root/locked"
    out="$(residue_files "$root" "$SELF" 2>&1)"; rc=$?
    chmod 700 "$root/locked"
    if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | awk -v prefix="layer4 residue scan: $root: find exited " \
        'index($0, prefix)==1 && substr($0, length(prefix)+1) ~ /^[1-9][0-9]*$/ { hit++ } END { exit(hit != 1) }'; then
      T_PASS=$((T_PASS+1))
    else
      T_FAIL=$((T_FAIL+1)); echo "FAIL: control: layer4 residue must reject an unreadable subtree by name, root and status (rc=$rc): $out"
    fi
  fi
  out="$(residue_files "$root" "$SELF" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "$(printf '%s/locked/hidden.md\n%s/visible.md' "$root" "$root")" ]; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: control: layer4 residue must enumerate the adjacent readable tree (rc=$rc): $out"
  fi
  awk 'NR==1 { print; exit }' "$NEEDLES_INNER" > "$root/hidden.md"
  if [ "$(id -u)" -eq 0 ]; then
    echo 'SKIP: layer4 residue unreadable-file control (uid 0 bypasses chmod 000)'
  else
    chmod 000 "$root/hidden.md"
    out="$(residue_files "$root" "$SELF" 2>&1)"; rc=$?
    chmod 600 "$root/hidden.md"
    if [ "$rc" -ne 0 ] && [ "$out" = "layer4 residue scan: $root/hidden.md: not a readable regular file" ]; then
      T_PASS=$((T_PASS+1))
    else
      T_FAIL=$((T_FAIL+1)); echo "FAIL: control: layer4 residue must reject an unreadable regular file by path (rc=$rc): $out"
    fi
  fi
  printf '# clean\n' > "$root/hidden.md"
  out="$(residue_files "$root" "$SELF" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "$(printf '%s/hidden.md\n%s/locked/hidden.md\n%s/visible.md' "$root" "$root" "$root")" ]; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: control: layer4 residue must enumerate the adjacent readable-file tree (rc=$rc): $out"
  fi
}

residue_find_controls

# The inner file list: all of ossify/ minus the eval run records and this test.
FLIST="$TMPDIR_WORK/filelist"
if residue_listing="$(residue_files "$OSSIFY" "$SELF" 2>&1)"; then
  printf '%s\n' "$residue_listing" > "$FLIST"
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: $residue_listing"
  t_summary
  exit 1
fi
nfiles="$(wc -l < "$FLIST" | tr -d ' ')"
if [ "$nfiles" -ge 250 ]; then T_PASS=$((T_PASS+1))
else T_FAIL=$((T_FAIL+1)); echo "FAIL: only $nfiles files enumerated - the residue walk is broken and every zero below is vacuous"; fi

# Dead-walk control: `ossify` must appear somewhere in the enumerated set, or
# the list names the wrong tree entirely.
control="$(awk 'index($0, "ossify") { print FILENAME ":" FNR; exit }' $(cat "$FLIST"))"
if [ -n "$control" ]; then T_PASS=$((T_PASS+1))
else T_FAIL=$((T_FAIL+1)); echo "FAIL: no file under ossify/ contains the string 'ossify' - the scan is dead, not clean"; fi

# The tool grant, structurally: a column-0 `allowed-tools:` line containing
# "Workflow" is the mechanism being re-granted. Same-line only - the shipped
# grants are single-line, and a hypothetical wrapped form is covered by the
# backticked needle the moment prose names the tool.
grant_hits="$(awk '/^allowed-tools:/ && index($0, "Workflow") { print FILENAME ":" FNR }' $(cat "$FLIST"))"
if [ -z "$grant_hits" ]; then T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1))
  echo "FAIL: an allowed-tools grant re-admits the Workflow tool:"
  printf '      %s\n' $grant_hits
fi

# ---------------------------------------------------------------------------
# 3. The scan itself. Each needle is one assertion; every hit is printed so the
#    RED names exactly what was found.
# ---------------------------------------------------------------------------
while IFS= read -r needle; do
  [ -n "$needle" ] || continue
  hits="$(awk -v needle="$needle" 'index($0, needle) { print FILENAME ":" FNR }' $(cat "$FLIST"))"
  if [ -z "$hits" ]; then T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1))
    echo "FAIL: delegated-path residue - '$needle' found:"
    printf '      %s\n' $hits
  fi
done < "$NEEDLES_INNER"

# The repo-root files that named the mechanism, under the mechanism-unique
# subset only (see the header for why path-form and tool-name needles are not
# scanned here: README's own structure carries `.github/workflows` references
# for CI that have nothing to do with this mechanism).
for f in "$REPO/README.md"; do
  if [ ! -f "$f" ] || [ ! -r "$f" ]; then
    T_FAIL=$((T_FAIL+1))
    echo "FAIL: layer4 residue scan: $f: not a readable regular file"
    continue
  fi
  while IFS= read -r needle; do
    [ -n "$needle" ] || continue
    hits="$(awk -v needle="$needle" 'index($0, needle) { print FILENAME ":" FNR }' "$f")"
    if [ -z "$hits" ]; then T_PASS=$((T_PASS+1))
    else
      T_FAIL=$((T_FAIL+1))
      echo "FAIL: delegated-path residue outside ossify/ - '$needle' in ${f##*/}:"
      printf '      %s\n' $hits
    fi
  done < "$NEEDLES_OUTER"
done

# ---------------------------------------------------------------------------
# 4. The false-positive control: the same needle set over legitimate prose must
#    hit NOTHING. Without this, only today's tree is proven clean - not the
#    rule, and the next "`.github/workflows`" pointer or sentence-initial
#    "Workflow" silently re-opens the class this gate just closed.
# ---------------------------------------------------------------------------
LEGIT="$TMPDIR_WORK/legitimate-prose.md"
cat > "$LEGIT" <<'EOF'
The CI workflow list lives at `.github/workflows/tests.yml`; consult it before
changing a gate. Workflow ordering matters in that file, and the release
workflows run serially. A critic that refutes a claim has refuted it; the
reviewer is the claim's refuter, and six agents of chaos are not a mechanism.
EOF

legit_hits="$(while IFS= read -r needle; do
  [ -n "$needle" ] || continue
  awk -v needle="$needle" 'index($0, needle) { print FILENAME ":" FNR ": " needle }' "$LEGIT"
done < "$NEEDLES_INNER")"
if [ -z "$legit_hits" ]; then T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1))
  echo "FAIL: a needle matches legitimate prose - the needle is wrong, not the prose:"
  printf '      %s\n' $legit_hits
fi

t_summary
