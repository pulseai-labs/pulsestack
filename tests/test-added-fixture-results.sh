#!/usr/bin/env bash
# Pins check-added-fixture-results.sh on a throwaway repo. Every stop has a control beside it.
set -u
CHECK="$(cd "$(dirname "$0")" && pwd)/check-added-fixture-results.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PASS=0 FAIL=0
expect() { # $1=label $2=wanted rc $3=wanted output substring (or "") ; runs on HEAD~1..HEAD
  local out rc=0
  out="$(bash "$CHECK" HEAD~1 HEAD 2>&1)" || rc=$?
  if [ "$rc" = "$2" ] && { [ -z "$3" ] || [[ "$out" == *"$3"* ]]; }; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); echo "FAIL: $1 (rc $rc, wanted $2; output: $out)"; fi
}
add() { mkdir -p "$(dirname "$1")"; echo x > "$1"; }
commit() { git add -A && git commit -qm "$1"; }

cd "$WORK" && git init -q && git config user.email t@t && git config user.name t
add README.md; add ossify/tests/eval/fixtures/old/01-old.md; commit base

add ossify/tests/eval/fixtures/s/01-a.md; commit no-result
expect "an added ossify fixture with no result stops" 1 "ossify/tests/eval/results/s/01-a.json"
add ossify/tests/eval/results/s/01-a.json; commit add-result
expect "control: the older fixture with no result is not this PR's" 0 ""

add ossify/tests/eval/fixtures/s/02-b.md; add ossify/tests/eval/results/s/02-b.json; commit both
expect "control: an added fixture with its result passes" 0 ""

add merge-bar/tests/eval/fixtures/m/01-c.md; commit mb
expect "an added merge-bar fixture with no result stops" 1 "merge-bar/tests/eval/results/m/01-c.json"
add merge-bar/tests/eval/results/m/01-c.json; commit mb-result

add ossify/tests/eval/fixtures/s/03-d.md; add ossify/tests/eval/results/t/03-d.json; commit other-suite
expect "a result in another suite does not count" 1 "ossify/tests/eval/results/s/03-d.json"
add ossify/tests/eval/results/s/03-d.json; commit fix

git mv ossify/tests/eval/fixtures/s/02-b.md ossify/tests/eval/fixtures/u/02-b.md 2>/dev/null \
  || { mkdir -p ossify/tests/eval/fixtures/u; git mv ossify/tests/eval/fixtures/s/02-b.md ossify/tests/eval/fixtures/u/02-b.md; }
commit moved
expect "a moved fixture needs a result at its new path" 1 "ossify/tests/eval/results/u/02-b.json"
add ossify/tests/eval/results/u/02-b.json; commit moved-result

add "ossify/tests/eval/fixtures/s/04-café.md"; commit non-ascii
expect "a non-ASCII fixture with no result stops" 1 "ossify/tests/eval/results/s/04-café.json"
add "ossify/tests/eval/results/s/04-café.json"; commit non-ascii-result
expect "control: a non-ASCII fixture with its result passes" 0 ""

nl=$'\n'
add "ossify/tests/eval/fixtures/s/05-a${nl}b.md"; commit newline
expect "a fixture name holding a newline stops" 1 "05-a"
add "ossify/tests/eval/results/s/05-a${nl}b.json"; commit newline-result
expect "control: that fixture with its result passes" 0 ""
add "docs/junk${nl}ossify/tests/eval/fixtures/s/ghost.md"; commit split
expect "control: a non-fixture name holding a fixture path on a second line is out of scope" 0 ""

add crew/tests/eval/fixtures/z/01-e.md; add ossify/tests/eval/fixtures/s/notes.txt; add ossify/tests/eval/fixtures/s/deep/01-f.md; commit out
expect "control: crew, non-markdown and deeper files are out of scope" 0 ""

echo changed >> ossify/tests/eval/fixtures/s/01-a.md; commit modified-only
expect "modified fixture without a changed result stops" 1 "modified fixture has no updated result"
echo changed >> ossify/tests/eval/fixtures/s/01-a.md
echo changed >> ossify/tests/eval/results/s/01-a.json; commit modified-both
expect "control: modified fixture and modified result pass" 0 ""
echo changed >> merge-bar/tests/eval/fixtures/m/01-c.md; commit mb-modified-only
expect "modified merge-bar fixture without updated result stops" 1 "merge-bar/tests/eval/results/m/01-c.json"
echo changed >> "ossify/tests/eval/fixtures/s/04-café.md"; commit modified-non-ascii
expect "modified odd path needs its own result" 1 "04-café.json"
echo changed >> "ossify/tests/eval/fixtures/s/05-a${nl}b.md"
echo changed >> "ossify/tests/eval/results/s/05-a${nl}b.json"; commit modified-newline-both
expect "control: modified newline path and result pass" 0 ""
add ossify/tests/eval/fixtures/r/01-first.md; add ossify/tests/eval/fixtures/r/02-second.md
add ossify/tests/eval/results/r/01-first.json; add ossify/tests/eval/results/r/02-second.json
add ossify/tests/eval/rubrics/r.md; commit rubric-base
echo changed >> ossify/tests/eval/rubrics/r.md; commit rubric-only
expect "modified rubric invalidates unchanged surface results" 1 "02-second.json"
echo changed >> ossify/tests/eval/rubrics/r.md
echo changed >> ossify/tests/eval/results/r/01-first.json; commit rubric-one-result
expect "one updated result does not cover the other fixture" 1 "02-second.json"
echo changed >> ossify/tests/eval/rubrics/r.md
echo changed >> ossify/tests/eval/results/r/01-first.json
echo changed >> ossify/tests/eval/results/r/02-second.json; commit rubric-all-results
expect "control: rubric and every surface result updated pass" 0 ""
add ossify/tests/eval/rubrics/empty.md; commit empty-rubric
echo changed >> ossify/tests/eval/rubrics/empty.md; commit empty-rubric-modified
expect "control: rubric of an empty surface owes no result" 0 ""
echo changed >> ossify/tests/eval/fixtures/old/01-old.md
add ossify/tests/eval/results/old/01-old.json; commit modified-with-added-result
expect "control: added result covers modified fixture" 0 ""
echo changed >> crew/tests/eval/fixtures/z/01-e.md; commit crew-modified
expect "control: modified crew fixture stays out of scope" 0 ""

rc=0; out="$(bash "$CHECK" no-such-rev HEAD 2>&1)" || rc=$?
if [ "$rc" = 2 ] && [[ "$out" == *"NOT checked"* ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: a bad rev is rc 2, not a pass (rc $rc)"; fi
rc=0; bash "$CHECK" HEAD >/dev/null 2>&1 || rc=$?
if [ "$rc" = 2 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: wrong argument count is rc 2 (rc $rc)"; fi

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
