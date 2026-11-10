#!/usr/bin/env bash
RULE_ID="PERM-001"
RULE_NAME="broad-allow"
RULE_ASPECT="permissions"
RULE_SEVERITY="medium"
RULE_DESCRIPTION="Overly broad allow rule detected (Bash(*), Read(*), or Write(*)) — grants unrestricted tool access."
RULE_REMEDIATION="Scope allow rules to specific commands or paths. Replace Bash(*) with Bash(git:*), Bash(npm:*), etc. Replace Read(*)/Write(*) with specific path patterns."
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
  case "$bn" in
    settings.json|settings.local.json) ;;
    *) return 0 ;;
  esac

  # Ensure parseable JSON
  # Not JSON is rc 2 (SCANNER-002), not a clean read (#1089). Skill-first question 3: only adds a stop.
  jq empty "$target_file" 2>/dev/null || return 2

  jq -r '.permissions.allow[]? // empty' "$target_file" 2>/dev/null \
    | grep -E '^(Bash|Read|Write)\(\*\)$' \
    | while read -r entry; do
        local match; match="$entry"
        local fuid; fuid="$(csa_finding_uid_raw "$RULE_ID" "$target_file" "$match")"
        jq -nc \
          --arg rule_id "$RULE_ID" \
          --arg file "$target_file" \
          --argjson line 1 \
          --argjson offset 0 \
          --arg preview "permissions.allow contains broad rule: $match" \
          --arg severity "$RULE_SEVERITY" \
          --arg fuid "$fuid" \
          '{rule_id: $rule_id, file: $file, line: $line, offset: $offset, preview: $preview, severity: $severity, finding_uid: $fuid}'
      done
}
