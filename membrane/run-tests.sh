#!/usr/bin/env bash
# run-tests.sh — discovers and runs all tests in tests/test-*.sh.
# Exit 0 if all pass; non-zero with summary if any fail.

set -u
cd "$(dirname "$0")"

# The whole run's temp files land in one directory that one trap removes (lib/helpers.sh's csa_tmp_scope, the helper
# bin/csa and tests/_helpers.sh use), so a suite run leaves nothing under the caller's TMPDIR.
# shellcheck source=/dev/null
source lib/helpers.sh
csa_tmp_scope suite || { printf 'run-tests.sh: cannot create a temp directory\n' >&2; exit 1; }

declare -i total=0 failed=0
for test_file in tests/test-*.sh; do
  [[ -f "$test_file" ]] || continue
  printf '\n=== %s ===\n' "$test_file"
  if bash "$test_file"; then
    total=$((total + 1))
  else
    total=$((total + 1))
    failed=$((failed + 1))
  fi
done

printf '\n--- Summary: %d files, %d failed ---\n' "$total" "$failed"
[[ "$failed" -eq 0 ]] || exit 1
