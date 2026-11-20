#!/usr/bin/env bash
#
# crew — fidelity pins
#
# The skill's value is five rules that must not be summarised away by a later
# rewording: the delegation test, alias-not-model, review once per PR, no Agent
# tool from the orchestrator, merge only on the operator's word. Each pin is one
# sentence and the list is CAPPED AT FIVE: growing it turns a fidelity guard into
# a prose-freeze that fails on every rewording. A rule that matters enough to pin
# displaces one of these; it does not extend the list.
#
# Each pin is asserted to occur EXACTLY ONCE in its file. That single check
# carries two properties:
#
#   - contiguity — a pin that spans a markdown line wrap matches zero times, so
#     a passing pin is provably on one line and is not silently checking nothing
#   - uniqueness — a pin matching twice is ambiguous about which occurrence it
#     is guarding, so an edit could delete the real one and still pass
#
# Counting is done with awk's index() in a single pass. `grep -c` counts
# matching LINES rather than occurrences, so it cannot see a duplicate on one
# line, and `grep -q` in a pipeline can fail on a true match under pipefail.
#
# Usage:   bash crew/tests/test-fidelity-pins.sh
# Exit:    0 if every pin occurs exactly once; 1 otherwise.
# Deps:    bash 3.2+, awk.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
. "$SCRIPT_DIR/_helpers.sh"   # counters, colours, pass/fail, report

PINS=0

# Count the five rules without shadowing the shared pin implementation.
counted_pin() { # <relative-path> <needle> <label>
  PINS=$((PINS+1))
  pin "$PLUGIN_ROOT/$1" "$2" "$3"
}

printf '%screw fidelity pins — five load-bearing rules%s\n\n' "$DIM" "$RST"

counted_pin "skills/orchestrate/SKILL.md" \
  "if the answer needs more than one command's output, dispatch it" \
  "1/5  the delegation test survives"

counted_pin "skills/orchestrate/SKILL.md" \
  'No `Agent` tool from the orchestrator.' \
  "2/5  the Agent-tool ban survives"

counted_pin "skills/orchestrate/references/roles.md" \
  'A seat is a name, never `--model`.' \
  "3/5  seat-name-not-model survives"

counted_pin "skills/orchestrate/references/lifecycle.md" \
  "exactly once per PR" \
  "4/5  review-once-per-PR survives"

counted_pin "skills/orchestrate/references/lifecycle.md" \
  "Merge only on that word" \
  "5/5  the operator merge word survives"

# The cap is the point of this file, so it is asserted rather than trusted.
printf '\n'
if [ "$PINS" -eq 5 ]; then
  pass "pin list is capped at 5 (found $PINS)"
else
  fail "pin list is capped at 5" "found $PINS. Adding a pin means replacing one, not appending. See the header."
fi

assert_hoisted_counters

report
