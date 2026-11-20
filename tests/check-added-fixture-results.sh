#!/usr/bin/env bash
# Stops on added/modified fixtures and changed rubrics without refreshed results
# in the PR range (#1013, #231). Pure fixture/rubric moves keep existence-only coverage.
# Usage: check-added-fixture-results.sh <base-rev> <head-rev>
# rc 0 = covered, 1 = missing/outdated results, 2 = could not check.
# ossify and merge-bar only: crew has no results at this path. Unchanged older
# fixtures with no result remain out of scope unless their rubric changes.
# Refreshed means added/modified with a blob absent from that plugin's base results/.
# This checks content/range membership, not score correctness or pre-PR staleness.
# At fetch-depth: 2, a fixture edited again after its rerun within one PR passes.
# Mode-only fixture edits require refreshed results; symlink type changes (T) are skipped.

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
unavailable() { echo "$1; eval inputs are NOT checked" >&2; exit 2; }
# Cache complete base trees: cross-surface result moves must not look refreshed.
for plugin in ossify merge-bar; do
  git --literal-pathspecs ls-tree -r -z "$base" -- "$plugin/tests/eval/" >"$work/base-$plugin" \
    || unavailable "cannot read base eval tree: $plugin"
done
blob_at() {
  git --literal-pathspecs ls-tree --full-tree --format='%(objectname)' "$1" -- "$2"
}
base_has_blob() {
  local kind="$1" blob="$2" entry header path
  while IFS= read -r -d '' entry; do
    header="${entry%%$'\t'*}"; path="${entry#*$'\t'}"
    case "$path" in "$plugin/tests/eval/$kind/"*)
      [[ "${header##* }" != "$blob" ]] || return 0 ;;
    esac
  done <"$work/base-$plugin"
  return 1
}
# A byte-identical fixture move is exempt only if its source rubric is unchanged.
pure_move() {
  local fixture_blob current_rubric entry header source source_rest source_rubric
  fixture_blob="$(blob_at "$head" "$path")" || unavailable "cannot read fixture blob: $path"
  current_rubric="$(blob_at "$head" "$plugin/tests/eval/rubrics/${rest%%/*}.md")" \
    || unavailable "cannot read current rubric: $path"
  while IFS= read -r -d '' entry; do
    header="${entry%%$'\t'*}"; source="${entry#*$'\t'}"
    [[ "${header##* }" == "$fixture_blob" ]] || continue
    case "$source" in "$plugin/tests/eval/fixtures/"*/*.md)
      source_rest="${source#"$plugin/tests/eval/fixtures/"}"
      case "$source_rest" in */*/*) continue ;; esac
      source_rubric="$(blob_at "$base" "$plugin/tests/eval/rubrics/${source_rest%%/*}.md")" \
        || unavailable "cannot read source rubric: $source"
      [[ "$source_rubric" != "$current_rubric" ]] || return 0 ;;
    esac
  done <"$work/base-$plugin"
  return 1
}
# Keep NUL boundaries through both walks; no line-oriented path membership.
: >"$work/results"
while IFS= read -r -d '' status && IFS= read -r -d '' path; do
  case "$path" in
    ossify/tests/eval/results/*/*.json|merge-bar/tests/eval/results/*/*.json)
      printf '%s\0' "$path" >>"$work/results" ;;
  esac
done <"$work/changes"
updated() {
  local changed blob
  while IFS= read -r -d '' changed; do
    if [[ "$changed" == "$1" ]]; then
      blob="$(blob_at "$head" "$1")" || unavailable "cannot read result blob: $1"
      base_has_blob results "$blob" && return 1
      return 0
    fi
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
        if pure_move; then
          if ! git cat-file -e "$head:$result" 2>/dev/null; then
            echo "added fixture has no result: $path (wanted $result)"
            missing=1
          fi
        elif ! updated "$result"; then
          echo "added fixture has no updated result: $path (wanted $result)"
          missing=1
        fi
      elif [[ "$status" == M ]] && ! updated "$result"; then
        echo "modified fixture has no updated result: $path (wanted $result)"
        missing=1
      fi ;;
    ossify/tests/eval/rubrics/*.md|merge-bar/tests/eval/rubrics/*.md)
      # A renamed rubric is A under --no-renames; unchanged copies need no rerun.
      plugin="${path%%/*}"
      surface="${path#"$plugin"/tests/eval/rubrics/}"; surface="${surface%.md}"
      case "$surface" in */*) continue ;; esac
      if [[ "$status" == A ]]; then
        rubric_blob="$(blob_at "$head" "$path")" || unavailable "cannot read rubric blob: $path"
        base_has_blob rubrics "$rubric_blob" && continue
      fi
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
