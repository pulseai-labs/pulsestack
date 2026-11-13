#!/usr/bin/env bash
# #841: the producer's first-line marker must equal ossify's §1a contract.
# Repo-root because a plugin suite cannot read its sibling plugin.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/workspace-init/templates/AGENTS.md.stub.tmpl"
CONSUMER="$ROOT/ossify/skills/start/references/occupied-destinations.md"
PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  not ok  %s\n' "$1"; }

printf 'AGENTS.md stub marker parity\n'
marker="$(awk 'NR == 1 { print; exit }' "$TEMPLATE")"
if [[ "$marker" == '<!-- '*' -->' ]]; then
  pass "template line 1 is an HTML comment"
else
  fail "template line 1 must be an HTML comment"
fi

if WI_STUB_MARKER="$marker" awk '
  /^### 1a[.] / { section = 1; next }
  section && /^##/ { section = 0 }
  section && index($0, "exactly `" ENVIRON["WI_STUB_MARKER"] "`") { found = 1 }
  END { exit !found }
' "$CONSUMER"; then
  pass "ossify §1a requires exactly the template marker in backticks"
else
  fail "ossify §1a must require exactly the template marker in backticks"
fi

printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
