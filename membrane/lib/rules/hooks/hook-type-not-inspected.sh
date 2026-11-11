#!/usr/bin/env bash
RULE_ID="HOOK-006"
RULE_NAME="hook-type-not-inspected"
RULE_ASPECT="hooks"
RULE_SEVERITY="info"
RULE_DESCRIPTION="A JSON file declares hooks of a type the audit counts but does not inspect (http, prompt, agent, mcp_tool or a type added later)."
RULE_REMEDIATION="Read these hooks by hand. Only command hooks are checked against the HOOK patterns."
RULE_REFERENCES=""
# detect_text receives ALL of a file's entries at once (one JSON line each):
# one finding per file, not one per entry.
RULE_TEXT_SCOPE="file"

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  _RULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
  _RULE_DIR="${CSA_LIB_DIR:-}"
fi
# shellcheck source=/dev/null
source "$_RULE_DIR/redact.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$_RULE_DIR/fingerprint.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$_RULE_DIR/helpers.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$_RULE_DIR/hook-entries.sh" 2>/dev/null || true

# detect never matches: this rule reads hook entries only, through detect_text.
detect() { return 1; }

# detect_text <entries-jsonl> <file> — one Info finding per file with per-type
# counts. Skill-first question 3: a mechanical report that can only add a stop. A jq
# error is rc 2 (SCANNER-002), not rc 1: "nothing to report" is only an empty count.
# json_path "hooks" names the key the entries sit under, so a report prints
# file#hooks and not file:0:0.
detect_text() {
  local entries="$1" target_file="$2" counts preview fuid
  counts="$(printf '%s\n' "$entries" | jq -rs '
    [.[] | select(has("inconclusive") | not) | select(has("module") | not) | select(.type != "command") | .type]
    | group_by(.) | map("\(.[0])=\(length)") | join(", ")' 2>/dev/null)" || return 2
  [[ -n "$counts" ]] || return 1
  preview="$(csa_redact "hook entries not inspected: $counts")"
  # Hash first, as HOOK-005 does: the counts hold attacker-chosen type names, and
  # csa_finding_uid redacts and caps its match at 200 bytes under bin/csa's LC_ALL=C.
  fuid="$(csa_finding_uid "$RULE_ID" "$target_file" "$(csa_sha256 "$counts" | cut -c1-24)")"
  jq -nc --arg rule_id "$RULE_ID" --arg file "$target_file" --arg preview "$preview" \
    --arg severity "$RULE_SEVERITY" --arg fuid "$fuid" --arg counts "$counts" \
    '{rule_id: $rule_id, file: $file, line: 0, offset: 0, preview: $preview, severity: $severity, finding_uid: $fuid, context: {types: $counts, json_path: "hooks"}}'
}
