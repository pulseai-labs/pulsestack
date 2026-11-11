#!/usr/bin/env bash
RULE_ID="PERM-004"
RULE_NAME="dangerous-combo"
RULE_ASPECT="permissions"
RULE_SEVERITY="critical"
RULE_DESCRIPTION="Bash(*) allowed with no deny rules — unrestricted shell execution with zero guardrails."
RULE_REMEDIATION="Remove Bash(*) or add deny rules for at minimum Bash(rm -rf:*), Bash(curl:*), and Bash(eval:*)."
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

  # Not JSON, or a deny with no length, is rc 2 (SCANNER-002), not a clean read (#1089). Skill-first question 3: only adds a stop.
  jq empty "$target_file" 2>/dev/null || return 2

  # Check if Bash(*) is in allow list
  local has_bash_star
  has_bash_star="$(jq -r '.permissions.allow[]? // empty | select(. == "Bash(*)")' "$target_file" 2>/dev/null)"
  [[ -n "$has_bash_star" ]] || return 0

  # Check deny is empty
  local deny_len; deny_len="$(jq '.permissions.deny | length' "$target_file" 2>/dev/null)" || return 2
  [[ "$deny_len" -eq 0 ]] || return 0

  local fuid; fuid="$(csa_finding_uid "$RULE_ID" "$target_file" "Bash(*)+no-deny")"
  jq -nc \
    --arg rule_id "$RULE_ID" \
    --arg file "$target_file" \
    --argjson line 1 \
    --argjson offset 0 \
    --arg preview "Bash(*) in permissions.allow with empty permissions.deny — unrestricted shell, no guardrails" \
    --arg severity "$RULE_SEVERITY" \
    --arg fuid "$fuid" \
    '{rule_id: $rule_id, file: $file, line: $line, offset: $offset, preview: $preview, severity: $severity, finding_uid: $fuid}'
}
