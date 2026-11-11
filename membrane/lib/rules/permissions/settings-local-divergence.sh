#!/usr/bin/env bash
RULE_ID="PERM-003"
RULE_NAME="settings-local-divergence"
RULE_ASPECT="permissions"
RULE_SEVERITY="high"
RULE_DESCRIPTION="settings.local.json grants allow rules not present in sibling settings.json — local overrides may bypass team security policy."
RULE_REMEDIATION="Align settings.local.json with team-wide settings.json, or move the allow entry upstream if it is intentional."
RULE_REFERENCES=""

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

detect() {
  local target_file="$1"
  [[ -r "$target_file" ]] || return 0
  local bn; bn="$(basename "$target_file")"
  [[ "$bn" == "settings.local.json" ]] || return 0

  # Not JSON (this file or its sibling) is rc 2 (SCANNER-002), not a clean read (#1089). Skill-first question 3: only adds a stop.
  jq empty "$target_file" 2>/dev/null || return 2

  local sibling; sibling="$(dirname "$target_file")/settings.json"
  [[ -r "$sibling" ]] || return 0
  jq empty "$sibling" 2>/dev/null || return 2

  # Find entries in local allow that are NOT in base settings allow.
  jq -r '.permissions.allow[]? // empty' "$target_file" 2>/dev/null \
    | while read -r entry; do
        # Check if this entry exists in the base settings allow list
        local found
        found="$(jq --arg e "$entry" '.permissions.allow[]? // empty | select(. == $e)' "$sibling" 2>/dev/null)"
        if [[ -z "$found" ]]; then
          local fuid; fuid="$(csa_finding_uid_raw "$RULE_ID" "$target_file" "$entry")"
          jq -nc \
            --arg rule_id "$RULE_ID" \
            --arg file "$target_file" \
            --argjson line 1 \
            --argjson offset 0 \
            --arg preview "local allow '$entry' not present in sibling settings.json" \
            --arg severity "$RULE_SEVERITY" \
            --arg fuid "$fuid" \
            '{rule_id: $rule_id, file: $file, line: $line, offset: $offset, preview: $preview, severity: $severity, finding_uid: $fuid}'
        fi
      done
}
