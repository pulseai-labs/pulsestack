#!/usr/bin/env bash
# Stops on added fixtures without results (#1013), or PR-modified fixtures and
# rubrics whose affected results were not added/modified in the range (#231).
# Usage: check-added-fixture-results.sh <base-rev> <head-rev>
# rc 0 = covered, 1 = missing/outdated results, 2 = could not check.
# ossify and merge-bar only: crew has no results at this path. Unchanged older
# fixtures with no result remain out of scope unless their rubric changes.
# This checks range membership, not score correctness or pre-PR staleness.

set -u
[ "$#" -eq 2 ] || { echo "usage: $0 <base-rev> <head-rev>" >&2; exit 2; }
base="$1" head="$2"

# --no-renames: a moved fixture needs a result at its new path too. -z: git otherwise
# quotes an odd path, and a quoted or split path would match no fixture below.
work="$(mktemp -d)" || exit 2
trap 'rm -rf "$work"' EXIT
if ! git diff -z --name-status --no-renames --diff-filter=AM "$base" "$head" >"$work/changes"; then
  echo "cannot diff $base..$head; eval inputs are NOT checked" >&2
  exit 2
fi
# Keep NUL boundaries through both walks; no line-oriented path membership.
: >"$work/results"
while IFS= read -r -d '' status && IFS= read -r -d '' path; do
  case "$path" in
    ossify/tests/eval/results/*/*.json|merge-bar/tests/eval/results/*/*.json)
      printf '%s\0' "$path" >>"$work/results" ;;
  esac
done <"$work/changes"
updated() {
  local changed
  while IFS= read -r -d '' changed; do
    [[ "$changed" != "$1" ]] || return 0
  done <"$work/results"
  return 1
}
missing=0
while IFS= read -r -d '' status && IFS= read -r -d '' path; do
  case "$path" in
    ossify/tests/eval/fixtures/*/*.md|merge-bar/tests/eval/fixtures/*/*.md)
      plugin="${path%%/*}"
      rest="${path#"$plugin"/tests/eval/fixtures/}"
      case "$rest" in */*/*) continue ;; esac
      result="$plugin/tests/eval/results/${rest%.md}.json"
      if [[ "$status" == A ]]; then
        if ! git cat-file -e "$head:$result" 2>/dev/null; then
          echo "added fixture has no result: $path (wanted $result)"
          missing=1
        fi
      elif [[ "$status" == M ]] && ! updated "$result"; then
        echo "modified fixture has no updated result: $path (wanted $result)"
        missing=1
      fi ;;
    ossify/tests/eval/rubrics/*.md|merge-bar/tests/eval/rubrics/*.md)
      [[ "$status" == M ]] || continue
      plugin="${path%%/*}"
      surface="${path#"$plugin"/tests/eval/rubrics/}"; surface="${surface%.md}"
      case "$surface" in */*) continue ;; esac
      prefix="$plugin/tests/eval/fixtures/$surface/"
      if ! git --literal-pathspecs ls-tree -r -z --name-only "$head" -- "$prefix" >"$work/fixtures"; then
        echo "cannot read fixtures for $path; eval inputs are NOT checked" >&2
        exit 2
      fi
      while IFS= read -r -d '' fixture; do
        id="${fixture#"$prefix"}"
        case "$id" in */*|*.txt) continue ;; *.md) ;; *) continue ;; esac
        result="$plugin/tests/eval/results/$surface/${id%.md}.json"
        if ! updated "$result"; then
          echo "modified rubric has no updated result: $path ($fixture wanted $result)"
          missing=1
        fi
      done <"$work/fixtures" ;;
  esac
done <"$work/changes"
exit "$missing"
