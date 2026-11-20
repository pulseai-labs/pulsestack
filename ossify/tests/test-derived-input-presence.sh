#!/usr/bin/env bash
# The checker reads fixture BODIES and the derived contract, never answer keys.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/eval/lib/check-derived-inputs.py"
CONTRACT="$HERE/eval/derived-inputs/boundary-audit-integrity.md"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/fixtures/boundary-audit-integrity" "$WORK/derived-inputs"
cp "$CONTRACT" "$WORK/derived-inputs/"
fixture="$WORK/fixtures/boundary-audit-integrity/odd name.md"
PASS=0 FAIL=0
body='The pairing manifest names the canonical and the AI workspace, and carries no other repository object.
canonical manifest visibility: public. AI workspace manifest visibility: private.
canonical remotes on record: origin, observed public, no manifest git_remote.
AI workspace remotes on record: origin, observed private, no manifest git_remote.
gitleaks is installed, completes cleanly; neither repo has a .gitleaks.toml.
canonical clone completeness: full clone. AI workspace clone completeness: full clone.
git ls-files -v marks no flagged path in either repo.
.gitmodules is absent and neither repo tracks a gitlink.'
expect() {
  local label="$1" wanted="$2" needle="$3" out rc=0
  out="$(python3 "$CHECK" "$WORK" 2>&1)" || rc=$?
  if [[ "$rc" == "$wanted" && "$out" == *"$needle"* ]]; then
    PASS=$((PASS+1)); printf 'ok: %s\n' "$label"
  else FAIL=$((FAIL+1)); printf 'FAIL: %s (rc %s wanted %s)\n%s\n' "$label" "$rc" "$wanted" "$out"; fi
}
printf '%s\n' "$body" > "$fixture"
expect 'complete body passes' 0 '1 fixture(s)'
printf '%s\n' "${body/.gitleaks.toml/config file}" > "$fixture"
expect 'missing one input class stops' 1 'I10'
printf '%s\n' "${body/carries no other repository object/names exactly two repos}" > "$fixture"
expect 'near synonym is not a contract declaration' 1 'I4'
printf '%s\n' "${body/AI workspace manifest visibility/workspace manifest visibility}" > "$fixture"
expect 'one repo declaration does not cover two repos' 1 'I2 (AI workspace)'
printf '%s\n' "${body/AI workspace remotes on record/workspace remotes on record}" > "$fixture"
expect 'per-repo remote declaration cannot cover the other repo' 1 'I6 (AI workspace)'
printf '%s\n' "${body/AI workspace clone completeness/workspace clone completeness}" > "$fixture"
expect 'per-repo clone declaration cannot cover the other repo' 1 'I23 (AI workspace)'
printf '%s\n' '---' 'expected: .gitleaks.toml' '---' "${body/.gitleaks.toml/config file}" > "$fixture"
expect 'frontmatter cannot declare a body input' 1 'I10'
printf '%s\n' '' '---' 'expected: .gitleaks.toml' '---' "${body/.gitleaks.toml/config file}" > "$fixture"
expect 'X2 leading blank before frontmatter cannot declare a body input' 1 'I10'
printf '%s\n' '--- ' 'expected: .gitleaks.toml' '---' "${body/.gitleaks.toml/config file}" > "$fixture"
expect 'X3 trailing whitespace on frontmatter cannot declare a body input' 1 'I10'
printf '%s\n' "${body/git ls-files -v/git ls-files
-v}" > "$fixture"
expect 'line wrapping is not a different phrasing' 0 '1 fixture(s)'
printf '%s\n' '---' 'expected: complete' > "$fixture"
expect 'unterminated frontmatter fails closed' 2 'frontmatter'
printf '%s\n' "$body" > "$fixture"
# Every missing class must stop, including those not in the minimal brief controls.
for phrase in 'git ls-files -v' '.gitmodules'; do
  printf '%s\n' "${body/"$phrase"/missing}" > "$fixture"
  expect "missing $phrase stops" 1 'MISSING:'
done
# These controls must remain rc 2, not merely a missing-declaration rc 1.
contract="$(cat "$CONTRACT")"
row='| I27 | set | .gitmodules |'
printf '%s\n' "${contract/"$row"/}" > "$WORK/derived-inputs/boundary-audit-integrity.md"
printf '%s\n' "${body/.gitmodules/missing}" > "$fixture"
expect 'deleted class row fails closed' 2 'PRESENCE-CHECK UNAVAILABLE:'
printf '%s\n' "$body" > "$fixture"
printf '%s\n' "${contract/\{repo\} manifest visibility/manifest visibility}" > "$WORK/derived-inputs/boundary-audit-integrity.md"
expect 'per-repo row without placeholder fails closed' 2 'PRESENCE-CHECK UNAVAILABLE:'
printf '%s\n' "${contract/Repos: canonical; AI workspace/Repos: canonical; canonical; AI workspace}" > "$WORK/derived-inputs/boundary-audit-integrity.md"
expect 'duplicate Repos subject fails closed' 2 'PRESENCE-CHECK UNAVAILABLE:'
printf '%s\n' "${contract/\| I4 \| set \|/| I4 | sett |}" > "$WORK/derived-inputs/boundary-audit-integrity.md"
expect 'scope typo fails closed' 2 'PRESENCE-CHECK UNAVAILABLE:'
cp "$CONTRACT" "$WORK/derived-inputs/"
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
# This is the real corpus gate; run-all.sh discovers this new test automatically.
python3 "$CHECK"
