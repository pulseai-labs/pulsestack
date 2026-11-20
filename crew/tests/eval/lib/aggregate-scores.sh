#!/usr/bin/env bash
# aggregate-scores.sh — crew copy.
#
# VERBATIM COPY below the first set line; tests/test-crew-parity.sh enforces it.
# The body derives EVAL_DIR from its own location. Re-copy rather than fork.
# aggregate-scores.sh — read per-fixture JSON results and print pass/fail summary.
# AFTER the Claude-Code-session eval run has written results/*.json, run this.

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="${EVAL_DIR}/results"
FIXTURES_DIR="${EVAL_DIR}/fixtures"

# Freshness covers exactly the fixture and the surface rubric the judge reads.
# Stated limit: skill files are NOT checked; changed skills still owe a rerun.
# A result committed with its input edit counts as current; this is not provenance.
# Symlink inputs compare target bytes against link-text blobs and can report STALE.
# Committed, unchanged results compare clean-filtered inputs with their blobs
# at the result's last commit. Fresh (modified/untracked) results use mtimes.
unavailable() { echo "STALE-CHECK UNAVAILABLE: $1"; exit 1; }
git_eval() { git --literal-pathspecs -C "$EVAL_DIR" "$@"; }
inside="$(git_eval rev-parse --is-inside-work-tree 2>/dev/null)" || unavailable "not a git work tree: $EVAL_DIR"
[[ "$inside" == true ]] || unavailable "not a git work tree: $EVAL_DIR"
shallow="$(git_eval rev-parse --is-shallow-repository)" || unavailable "cannot read clone completeness"
[[ "$shallow" == false ]] || unavailable "shallow clone: result history is truncated"
prefix="$(git_eval rev-parse --show-prefix)" || unavailable "cannot resolve eval path"

# --- unscored-fixture guard -------------------------------------------------
# This script counts result JSONs, so on its own it CANNOT detect its own
# incompleteness: a surface authored but never run is simply absent from
# results/, and the total comes back clean over fixtures nothing ever scored.
# That is a green ship gate over a surface that does not exist in the results.
#
# So the walk is over FIXTURES, which are authoritative — a fixture with no
# result is an UNSCORED fixture, never an absent one. Keying this off results/
# would reproduce the blind spot it exists to close.
unscored=""
unscored_count=0
stale=""
stale_count=0
if [[ -d "$FIXTURES_DIR" ]]; then
  for fixture_dir in "$FIXTURES_DIR"/*/; do
    [[ -d "$fixture_dir" ]] || continue
    surface="${fixture_dir%/}"; surface="${surface##*/}"
    for fixture in "$fixture_dir"*.md; do
      [[ -e "$fixture" ]] || continue
      id="${fixture##*/}"; id="${id%.md}"
      result="${RESULTS_DIR}/${surface}/${id}.json"
      if [[ ! -f "$result" ]]; then
        unscored+="  UNSCORED: ${surface}/${id} — no results/${surface}/${id}.json"$'\n'
        unscored_count=$((unscored_count + 1))
        continue
      fi
      result_path="results/${surface}/${id}.json"
      status="$(git_eval status --porcelain --untracked-files=all -- "$result_path")" || unavailable "cannot read result status: $result_path"
      revision="$(git_eval log -1 --format=%H -- "$result_path")" || unavailable "cannot read result history: $result_path"
      why=""
      for input in "fixtures/${surface}/${id}.md" "rubrics/${surface}.md"; do
        if [[ ! -f "$EVAL_DIR/$input" ]]; then
          why+="${input} is missing; "
        elif [[ -n "$status" || -z "$revision" ]]; then
          if [[ "$EVAL_DIR/$input" -nt "$result" ]]; then
            why+="${input} is newer than the fresh result; "
          fi
        else
          entry="$(git_eval ls-tree --full-tree "$revision" -- "${prefix}${input}")" || unavailable "cannot read input tree: $input"
          if [[ -z "$entry" ]]; then
            why+="${input} did not exist at result commit; "
          else
            old="$(git_eval rev-parse --verify "${revision}:${prefix}${input}")" || unavailable "cannot read input blob: $input"
            now="$(git_eval hash-object -- "$input")" || unavailable "cannot hash input: $input"
            if [[ "$old" != "$now" ]]; then
              why+="${input} differs from result commit; "
            fi
          fi
        fi
      done
      if [[ -n "$why" ]]; then
        stale+="  STALE: ${surface}/${id} — ${why%; }"$'\n'
        stale_count=$((stale_count + 1))
      fi
    done
  done
fi

total_pass=0
total_fail=0
total_files=0

for skill_dir in "$RESULTS_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill="$(basename "$skill_dir")"
  skill_pass=0
  skill_fail=0

  for result in "$skill_dir"*.json; do
    [[ -e "$result" ]] || continue
    total_files=$((total_files + 1))
    pass=$(jq -r '.pass' "$result" 2>/dev/null || echo "false")
    if [[ "$pass" == "true" ]]; then
      skill_pass=$((skill_pass + 1))
      total_pass=$((total_pass + 1))
    else
      skill_fail=$((skill_fail + 1))
      total_fail=$((total_fail + 1))
      notes=$(jq -r '.notes // ""' "$result" 2>/dev/null || echo "")
      echo "  FAIL: ${skill}/$(basename "$result" .json) — ${notes}"
    fi
  done

  echo "${skill}: ${skill_pass} pass / ${skill_fail} fail"
done

echo ""
if [[ $unscored_count -gt 0 ]]; then
  printf '%s' "$unscored"
fi
if [[ $stale_count -gt 0 ]]; then
  printf '%s' "$stale"
fi
echo "=== TOTAL: ${total_pass}/${total_files} passed ==="
if [[ $unscored_count -gt 0 ]]; then
  echo "=== GATE FAILED: ${unscored_count} fixture(s) unscored — the total above is over a PARTIAL run ==="
fi
if [[ $stale_count -gt 0 ]]; then
  echo "=== GATE FAILED: ${stale_count} fixture(s) stale — rerun against current fixture and rubric ==="
fi
if [[ $unscored_count -gt 0 || $stale_count -gt 0 ]]; then
  exit 1
fi
[[ $total_fail -eq 0 && -d "$RESULTS_DIR" ]]
