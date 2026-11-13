#!/usr/bin/env bash
# crew's one verbatim copy, its Codex prompts, and one manifest restatement (#513).
#
#   tests/eval/lib/aggregate-scores.sh   ← ossify's, below its header
#
# The copy's own header states "keep them identical" as a manual ritual, and
# nothing else enforces it: a fix that lands in one copy only leaves the other
# silently behind. It is pinned here rather than in either plugin's suite
# because a plugin suite cannot see its sibling: crew's run-tests.sh reads
# only crew/. A repo-root script sees both trees, which is why this one
# runs from CI's repo-root steps. What the copy CONTAINS is guarded by each
# plugin's own suite; this file guards only that the two still agree.
#
# The eval-library body starts at its first `set ` line in both copies: the
# headers are per-copy by design (crew's carries the porting note), and
# everything below is not.
#
# Usage: bash tests/test-crew-parity.sh
# Deps:  bash 3.2+, diff, sed, jq.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  not ok  %s\n' "$1"; }

printf 'crew parity pins\n'

OSSIFY_LIB="$ROOT/ossify/tests/eval/lib/aggregate-scores.sh"
HERDR_LIB="$ROOT/crew/tests/eval/lib/aggregate-scores.sh"

for f in "$OSSIFY_LIB" "$HERDR_LIB"; do
  rel="${f#"$ROOT"/}"
  if [[ ! -f "$f" ]]; then fail "$rel exists"
  elif [[ ! -s "$f" ]]; then fail "$rel is non-empty"
  else pass "$rel exists and is non-empty"; fi
done

# The body is everything from the first `set ` line to EOF, in both copies: the
# headers are per-copy by design (crew's carries the porting note), and
# everything below them is not. The extraction is measured BEFORE it is compared,
# because an absent marker yields an empty body and two empty bodies are
# byte-identical — the pin would read green over a library neither copy has.
o_body="$(awk '/^set /{f=1} f' "$OSSIFY_LIB" | wc -l | tr -d ' ')"
h_body="$(awk '/^set /{f=1} f' "$HERDR_LIB" | wc -l | tr -d ' ')"
if [[ "$o_body" -eq 0 || "$h_body" -eq 0 ]]; then
  fail "both aggregate-scores.sh copies carry a set-line body to compare — an empty body compares equal to another"
elif cmp -s <(awk '/^set /{f=1} f' "$OSSIFY_LIB") <(awk '/^set /{f=1} f' "$HERDR_LIB"); then
  pass "crew/tests/eval/lib/aggregate-scores.sh is ossify's below its header"
else
  fail "tests/eval/lib/aggregate-scores.sh drifted from ossify's below its header — re-copy it; editing it is how the two stop agreeing"
fi

# The Claude manifest restates the marketplace entry's description. Nothing
# asserted they agree, so a description edit that landed in one and not the other
# shipped two different claims about the same plugin.
MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"
MANIFEST="$ROOT/crew/.claude-plugin/plugin.json"
if [[ ! -f "$MARKETPLACE" || ! -f "$MANIFEST" ]]; then
  fail "the marketplace listing and the plugin manifest both exist"
else
  # The emptiness guard uses $( ) deliberately — stripping is what "empty" means
  # here — while the EQUALITY test must not, which is why the jq expression runs
  # twice per side and the two checks use different machinery. $( ) strips
  # trailing newlines from both sides, so a description differing only in one
  # reads equal; cmp over the streams sees it. Both are hardened the same way as
  # the copy pin above.
  #
  # Note where this pin's mutations live: on the STREAM, not the file. Appending
  # a blank line to either JSON source leaves jq's output byte-identical —
  # measured — because jq re-serializes the value and the file's own trailing
  # newline never reaches it. The discriminating mutation is a `\n` INSIDE the
  # description string, which is what cmp catches and $( ) does not.
  mkt="$(jq -r '.plugins[] | select(.name == "crew") | .description' "$MARKETPLACE")"
  man="$(jq -r '.description' "$MANIFEST")"
  if [[ -z "$mkt" || -z "$man" ]]; then
    fail "the marketplace entry and the manifest both carry a description — empty on one side, and an empty string equals no other claim"
  elif cmp -s <(jq -r '.plugins[] | select(.name == "crew") | .description' "$MARKETPLACE") \
              <(jq -r '.description' "$MANIFEST"); then
    pass "the marketplace entry's description matches the plugin manifest's"
  else
    fail "the marketplace entry's description matches the plugin manifest's — the plugin is described two ways"
  fi
fi

# Each catalog must state the operative merge condition, not merely agree with a manifest.
for catalog in .claude-plugin/marketplace.json .agents/plugins/marketplace.json .omp-plugin/marketplace.json; do
  if jq -e '.plugins[] | select(.name == "crew") | .description | contains("clean gates merge under a project standing order granting this role merge authority, else on the operator'"'"'s word; operator gates and operator merge executors go to the operator")' "$ROOT/$catalog" >/dev/null 2>&1; then
    pass "#1215-catalog: $catalog requires project merge authority or the operator word"
  else
    fail "#1215-catalog: $catalog requires project merge authority or the operator word"
  fi
done

# crew's Codex prompts (#535). The `interface.defaultPrompt` array is a
# user-facing surface — the suggested actions on the Codex plugin page — and a
# whole-branch review once measured that the prompts could be reverted with
# every suite still green. The three name no layer: the project's layer is the
# project file's choice, so a prompt that promised herdr would be wrong on an
# Orca project. `cmp` over the jq streams rather than
# `[[ == ]]` on command substitution, for the reason the description pin above
# states: `$( )` strips trailing newlines from both sides.
CODEX_MANIFEST="$ROOT/crew/.codex-plugin/plugin.json"
if [[ ! -f "$CODEX_MANIFEST" ]]; then
  fail "crew's Codex manifest exists — a missing one makes the prompt pin vacuous"
else
  expected_prompts='Start an orchestrator session for this objective.
Dispatch a worker seat for this task.
Review PR 123 in a fresh seat.'
  if cmp -s <(jq -r '.interface.defaultPrompt[]' "$CODEX_MANIFEST") <(printf '%s\n' "$expected_prompts"); then
    pass "crew's Codex prompts are the layer-neutral three"
  else
    fail "crew's Codex prompts are the layer-neutral three — read: $(jq -r '.interface.defaultPrompt[]' "$CODEX_MANIFEST" | tr '\n' '|')"
  fi
fi

printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
