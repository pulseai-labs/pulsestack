#!/usr/bin/env bash
# #703 R2: prose-to-consumer contract pins; model execution is the eval gate.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
ADOPT="$HERE/../skills/adopt/SKILL.md"
C3="$(sed -n '/^1a\./,/^2\./p' "$ADOPT")"
t_assert_contains "$C3" 'reference you will pass to `bone_add`' 'R2 compare minted references, not filename stems'
t_assert_contains "$C3" 'bare seed filename contributes its number with `ADR-` prepended' 'R2 bare-seed pair maps to colliding bone references'
t_assert_contains "$C3" 'retaining its width' 'R2 bare-seed mapping preserves significant padding'
t_assert_contains "$C3" 'Case-fold these references under `LC_ALL=C`' 'R2 ADR-C / adr-c pair compares equal under authority'
t_assert_contains "$C3" 'original reference spellings and each repo' 'R2 halt names both original spellings and owning repos'
t_assert_contains "$C3" 'Any folded reference held by two inventory files halts adoption' '#705 the halt covers any two files, not only two repos'
t_assert_contains "$C3" 'or in one: name each file and its repo' '#705 the halt names both files and their repo for a within-repo pair'
t_assert_contains "$C3" 'Distinct references still proceed' 'R2 distinct-reference control remains supported'
# The RUNBOOK consumes these fixtures and this rubric, rather than a test's
# substitute collision algorithm. Literal expectations never come from production.
for fixture in 07-case-variant-references-halt 08-bare-seed-references-halt 09-within-repo-case-variant-references-halt; do
  text="$(cat "$HERE/eval/fixtures/adopt-multi-repo/$fixture.md")"
  t_assert_contains "$text" 'expected_outcome: halt' "R2 $fixture requires halt"
  t_assert_contains "$text" 'mints no bone' "R2 $fixture forbids mutation"
done
text="$(cat "$HERE/eval/fixtures/adopt-multi-repo/03-clean-two-repo-baseline-and-aggregated-adrs.md")"
t_assert_contains "$text" 'expected_outcome: proceed' 'R2 eval distinct-reference control proceeds'
rubric="$(cat "$HERE/eval/rubrics/adopt-multi-repo.md")"
t_assert_contains "$rubric" 'case-folded references' 'R2 judge scores the case-variant halt'
t_assert_contains "$rubric" 'bare seed filenames' 'R2 judge scores the bare-seed halt'
t_assert_contains "$rubric" 'two files in ONE repo' '#705 judge scores the within-repo halt'
t_summary
