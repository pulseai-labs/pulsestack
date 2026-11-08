#!/usr/bin/env bash
RULE_ID="MCP-001"
RULE_NAME="untrusted-endpoint"
RULE_ASPECT="mcp"
RULE_SEVERITY="high"
RULE_DESCRIPTION="MCP server configured with a non-HTTPS (http://) endpoint — traffic unencrypted and vulnerable to MITM."
RULE_AUTO_FIXABLE="false"
RULE_MECHANICALLY_FIXABLE="false"
RULE_REMEDIATION="Change the MCP server URL to use https://. Contact the server operator if an HTTPS endpoint is unavailable."
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
  # Only scan .mcp.json or mcp.json under .claude/
  local basename; basename="$(basename "$target_file")"
  if [[ "$basename" != ".mcp.json" && "$basename" != "mcp.json" ]]; then
    return 0
  fi
  # Flag any "url" value that starts with http:// (not https://)
  # grep rc 1 is no match; rc 2 or more is a read error: rc 2 (SCANNER-002) unless a match is already in hand,
  # which is emitted, since the engine drops a detector's stdout on rc 2 (#1089). Skill-first question 3.
  # LC_ALL=C grep -a reads the file byte by byte in every locale, as HOOK-004 does: a NUL or a byte that is not
  # UTF-8 does not make grep call the file binary and print no line.
  local hits grc=0
  hits="$(LC_ALL=C grep -anE '"url"[[:space:]]*:[[:space:]]*"http://' "$target_file" 2>/dev/null)" || grc=$?
  [[ "$grc" -le 1 ]] || [[ -n "$hits" ]] || return 2
  [[ -n "$hits" ]] || return 0
  printf '%s\n' "$hits" \
    | while IFS=: read -r line_no match; do
        local preview; preview="$(csa_redact "$match")"
        local fuid; fuid="$(csa_finding_uid_raw "$RULE_ID" "$target_file" "$match")"
        jq -nc \
          --arg rule_id "$RULE_ID" \
          --arg file "$target_file" \
          --argjson line "$line_no" \
          --argjson offset 0 \
          --arg preview "$preview" \
          --arg severity "$RULE_SEVERITY" \
          --arg fuid "$fuid" \
          '{rule_id: $rule_id, file: $file, line: $line, offset: $offset, preview: $preview, severity: $severity, finding_uid: $fuid}'
      done
}
