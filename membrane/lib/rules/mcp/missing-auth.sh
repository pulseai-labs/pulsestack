#!/usr/bin/env bash
RULE_ID="MCP-002"
RULE_NAME="missing-auth"
RULE_ASPECT="mcp"
RULE_SEVERITY="high"
RULE_DESCRIPTION="MCP server entry has a URL but no Authorization header or env-based auth placeholder."
RULE_REMEDIATION="Add an Authorization header or env-based token to the MCP server configuration, or confirm the endpoint is intentionally public."
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
  local basename; basename="$(basename "$target_file")"
  if [[ "$basename" != ".mcp.json" && "$basename" != "mcp.json" ]]; then
    return 0
  fi

  # Parse with jq: iterate mcpServers entries that have a "url" field but
  # no "Authorization" in headers and no env-like placeholder in headers or args.
  local servers jrc=0; servers="$(jq -r '
    .mcpServers // {} | to_entries[] |
    select(.value.url != null) |
    # Has auth if: headers.Authorization exists, or any header value looks like env-var ref, or args[] contains env-var ref
    . as $entry |
    (
      ($entry.value.headers.Authorization != null) or
      ([$entry.value.headers // {} | to_entries[] | .value | test("\\$\\{?[A-Z_]+\\}?|\\$[A-Z_]+")] | any) or
      ([$entry.value.args // [] | .[] | test("\\$\\{?[A-Z_]+\\}?|\\$[A-Z_]+")] | any)
    ) as $has_auth |
    if $has_auth then empty else .key end
  ' "$target_file" 2>/dev/null)" || jrc=$?
  # A jq failure is a SCANNER-002 (#1089), unless names were already printed before it: those are
  # findings and are emitted. Skill-first question 3: only adds a stop.
  [[ "$jrc" -eq 0 ]] || [[ -n "$servers" ]] || return 2

  [[ -n "$servers" ]] || return 0

  while IFS= read -r server_name; do
    [[ -n "$server_name" ]] || continue
    local msg="mcpServers.${server_name} has url but no Authorization header or env-based auth"
    local fuid; fuid="$(csa_finding_uid_raw "$RULE_ID" "$target_file" "$server_name")"
    jq -nc \
      --arg rule_id "$RULE_ID" \
      --arg file "$target_file" \
      --argjson line 1 \
      --argjson offset 0 \
      --arg preview "$msg" \
      --arg severity "$RULE_SEVERITY" \
      --arg fuid "$fuid" \
      '{rule_id: $rule_id, file: $file, line: $line, offset: $offset, preview: $preview, severity: $severity, finding_uid: $fuid}'
  done <<< "$servers"
}
