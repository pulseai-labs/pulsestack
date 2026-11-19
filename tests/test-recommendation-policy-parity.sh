#!/usr/bin/env bash
# Validate the recommend-by-default policy parity contract (issue #93).
#
# docs/conventions/recommendation-policy.md is the single human-facing
# source-of-truth. Because repo-root docs/ does NOT ship on /plugin install, each
# adopting plugin carries a byte-identical copy that DOES ship. This test fails if
# any plugin copy drifts from the SoT — the only guard against the "one skill
# recommends, another doesn't" drift the policy exists to prevent. Edit the SoT
# and re-copy; never hand-edit a plugin copy.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOT="$ROOT/docs/conventions/recommendation-policy.md"

# Each plugin's shipped copy (these paths ship with /plugin install; repo-root
# docs/ does not). Keep in sync with the plugin SKILL.md references.
COPIES=(
  "$ROOT/sage/skills/grill-me/recommendation-policy.md"
  "$ROOT/sage/skills/council/recommendation-policy.md"
  "$ROOT/remodel/skills/deepen-architecture/references/recommendation-policy.md"
)

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  not ok  %s\n' "$1"; }

printf 'Recommendation-policy parity contract\n'

if [[ -f "$SOT" ]]; then
  pass "source-of-truth exists at docs/conventions/recommendation-policy.md"
else
  fail "source-of-truth exists at docs/conventions/recommendation-policy.md"
  printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
  exit 1
fi

for copy in "${COPIES[@]}"; do
  rel="${copy#"$ROOT"/}"
  if [[ ! -f "$copy" ]]; then
    fail "$rel exists"
    continue
  fi
  pass "$rel exists"
  if cmp -s "$SOT" "$copy"; then
    pass "$rel is byte-identical to the source-of-truth"
  else
    fail "$rel drifted from the SoT (re-copy docs/conventions/recommendation-policy.md)"
  fi
done

# #111: TOP SEVERITY escalates a restart-class *recommendation*, not a menu that merely offers a restart
# option (read literally, the old "restart-class options" escalated every orchestrate gate). The parity
# checks above carry this sentence to every copy.
flat="$(tr -s ' \n' '  ' < "$SOT")"
if [[ "$flat" == *"a restart-class recommendation at orchestrate gates — a restart option merely on the menu does not trip it"* ]]; then
  pass "TOP SEVERITY names a restart-class recommendation, not a restart option on the menu (#111)"
else
  fail "TOP SEVERITY names a restart-class recommendation, not a restart option on the menu (#111)"
fi

printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
