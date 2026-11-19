#!/usr/bin/env bash
# pulsestack rename gate — the marketplace and three plugins under their new names (pulsestack
# rename, 2026-11). Facts, each owned here and nowhere else:
#   1. no tracked path lives under a renamed plugin's old directory;
#   2. every catalog publishes each new plugin at ./<new> and lists no entry under the old name;
#   3. the Claude and OMP catalogs are named after the new marketplace, the Codex one after its
#      -codex form;
#   4. no tracked file outside the survivors names an old plugin as a skill or command namespace
#      (old:skill, /old:skill) or as a path (old/...);
#   5. no tracked file outside the survivors names the old marketplace or the old repository.
#
# Survivors, each with its reason:
#   */CHANGELOG.md           — a changelog records the names a release shipped under.
#   */tests/fixtures/*       — recorded `gh` and orca output; rewriting it would fake a recording.
#   */tests/eval/evidence/*  — recorded eval runs, same reason.
#   */tests/eval/fixtures/*  — eval scenarios that replay a recorded host state, paths included.
#   omp/**/*.test.ts         — the OMP tests build install records under the old marketplace to
#                              prove the bin-path module and loader no longer read it (#1082).
#   lines marked "pre-rename" — prose that picks an install record names the old key as the
#                              fallback it reads.
#   merge-bar/tests/test-mb.sh — asserts on text read from the recorded fixtures above.
#   README.md migration lines ("Renamed from", "marketplace remove") — a move names both ends.
#   paths under .claude/<old>/ — plugin-internal state paths keep their names this release (spec:
#                              internal names stay; a follow-up issue renames them).
#
# Old names are assembled, not written, so this file never matches its own search, and this file
# is not a survivor.
#
# Usage: bash tests/test-pulsestack-rename.sh
# Deps:  bash 3.2+, git, jq, awk, sed.
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

OLD_MKT="claude-agent"'-scaffolding'
NEW_MKT="pulsestack"
# old=new pairs
PAIRS="code"'-judo=remodel ai'"-mentor=sage claude-security"'-audit=membrane'
# Renamed plugins the OMP catalog does not list (it never listed the security audit; the OMP set
# itself is owned by tests/test-omp-surface.sh).
NOT_ON_OMP="membrane"

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  not ok  %s\n' "$1"; }

# A hit "file:line:text" that a survivor rule allows.
survivor() {
  local file="$1" text="$2" old="${3:-}"
  case "$file" in
    */CHANGELOG.md|CHANGELOG.md) return 0 ;;
    */tests/fixtures/*|*/tests/eval/evidence/*|*/tests/eval/fixtures/*) return 0 ;;
    omp/*.test.ts|omp/*/*.test.ts) return 0 ;;
    merge-bar/tests/test-mb.sh) return 0 ;;
  esac
  case "$text" in *pre-rename*) return 0 ;; esac
  if [ "$file" = README.md ]; then
    case "$text" in *"Renamed from"*|*"marketplace remove"*) return 0 ;; esac
  fi
  if [ -n "$old" ]; then
    case "$text" in *".claude/$old/"*) return 0 ;; esac
  fi
  return 1
}

# Every finding in the checkout at $1, one line each, prefixed by its fact.
findings() (
  cd "$1" || exit 1
  local pair old new f src hit file rest text
  for pair in $PAIRS; do
    old="${pair%%=*}"; new="${pair#*=}"
    # 1
    git ls-files | awk -v o="$old/" 'index($0, o) == 1 { n++ } END { if (n) print "dir: " n " tracked file(s) under " o }'
    # 2
    for f in .claude-plugin/marketplace.json:.source .omp-plugin/marketplace.json:.source .agents/plugins/marketplace.json:.source.path; do
      src="${f#*:}"; f="${f%%:*}"
      case "$f / $NOT_ON_OMP " in .omp-plugin/*" $new "*) ;; *)
        [ "$(jq -r --arg n "$new" ".plugins[] | select(.name == \$n) | $src" "$f" 2>/dev/null)" = "./$new" ] \
          || echo "catalog: $f does not publish $new at ./$new" ;;
      esac
      jq -e --arg n "$old" '[.plugins[] | select(.name == $n)] | length == 0' "$f" >/dev/null 2>&1 \
        || echo "catalog: $f still lists $old"
    done
    # 4
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      file="${hit%%:*}"; rest="${hit#*:}"; text="${rest#*:}"
      survivor "$file" "$text" "$old" || echo "namespace: $hit"
    done < <(git grep -nE -- "(^|[^a-zA-Z0-9_.-])$old(:[a-z]|/)" -- . || true)
  done
  # 3
  [ "$(jq -r .name .claude-plugin/marketplace.json 2>/dev/null)" = "$NEW_MKT" ] || echo "marketplace: .claude-plugin/marketplace.json is not named $NEW_MKT"
  [ "$(jq -r .name .omp-plugin/marketplace.json 2>/dev/null)" = "$NEW_MKT" ] || echo "marketplace: .omp-plugin/marketplace.json is not named $NEW_MKT"
  [ "$(jq -r .name .agents/plugins/marketplace.json 2>/dev/null)" = "$NEW_MKT-codex" ] || echo "marketplace: .agents/plugins/marketplace.json is not named $NEW_MKT-codex"
  # 5
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"; rest="${hit#*:}"; text="${rest#*:}"
    survivor "$file" "$text" || echo "old-name: $hit"
  done < <(git grep -n -- "$OLD_MKT" -- . || true)
)

printf 'pulsestack rename gate\n'

if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  fail "run inside a git checkout"
  printf '        %s is not a git checkout: git ls-files and git grep would print nothing and every check would pass vacuously.\n' "$ROOT"
  printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
  exit 1
fi

out="$(findings "$ROOT")"
if [ -z "$out" ]; then pass "shipped tree has no findings"
else
  fail "shipped tree has $(printf '%s\n' "$out" | grep -c .) finding(s):"
  printf '%s\n' "$out" | sed 's/^/        /'
fi

# Controls: copy the tracked tree into a scratch checkout, plant one defect, and require that
# fact's finding. A check whose control stays green is broken, not passing.
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
make_fixture() {
  mkdir -p "$1"
  (cd "$ROOT" && git ls-files -z | xargs -0 tar -cf - 2>/dev/null) | tar -xf - -C "$1"
  (cd "$1" && git init -q && git add -A)
}
control() { # $1=label $2=expected finding text $3=planting command (run in the fixture dir)
  local d="$WORK/$1" o
  make_fixture "$d"; (cd "$d" && eval "$3" && git add -A)
  o="$(findings "$d")"
  if printf '%s' "$o" | grep -Fq -- "$2"; then pass "control $1 turns red"
  else fail "control $1: want a finding containing '$2'"; fi
}
O1="code"'-judo'
control old-dir       "tracked file(s) under $O1/" "mkdir -p $O1 && echo x > $O1/x"
control catalog-old   "catalog: .omp-plugin/marketplace.json still lists $O1" "jq '.plugins += [{name:\"$O1\",source:\"./$O1\"}]' .omp-plugin/marketplace.json > t && mv t .omp-plugin/marketplace.json"
control catalog-new   "catalog: .agents/plugins/marketplace.json does not publish sage at ./sage" "jq '.plugins |= map(select(.name != \"sage\"))' .agents/plugins/marketplace.json > t && mv t .agents/plugins/marketplace.json"
control mkt-name      "marketplace: .claude-plugin/marketplace.json is not named" "jq '.name = \"x\"' .claude-plugin/marketplace.json > t && mv t .claude-plugin/marketplace.json"
control namespace     "namespace: ossify/README.md" "printf 'Run /%s:deep-review.\n' $O1 >> ossify/README.md"
control path-ref      "namespace: ossify/README.md" "printf 'See %s/README.md.\n' $O1 >> ossify/README.md"
control old-key       "old-name: ossify/README.md" "printf 'Install ossify@%s.\n' $OLD_MKT >> ossify/README.md"
control old-url       "old-name: ossify/README.md" "printf 'https://github.com/pulseai-labs/%s\n' $OLD_MKT >> ossify/README.md"
# Adjacent control: a pre-rename fallback line is a survivor; the old-key control above, the same
# key on an unmarked line, still turns red.
d="$WORK/pre-rename"; make_fixture "$d"; (cd "$d" && printf 'Read ossify@pulsestack (pre-rename: ossify@%s).\n' "$OLD_MKT" >> ossify/README.md && git add -A)
if findings "$d" | grep -Fq "ossify/README.md"; then fail "control pre-rename: a marked fallback line must not be a finding"
else pass "control pre-rename stays green"; fi
# Adjacent control: a survivor still passes, so the sweep is not just matching everything.
d="$WORK/survivor"; make_fixture "$d"; (cd "$d" && printf 'Install ossify@%s.\n' "$OLD_MKT" >> ossify/CHANGELOG.md && git add -A)
if findings "$d" | grep -Fq "ossify/CHANGELOG.md"; then fail "control survivor: CHANGELOG history must not be a finding"
else pass "control survivor stays green"; fi

printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
