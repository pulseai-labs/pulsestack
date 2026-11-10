#!/usr/bin/env bash
RULE_ID="PROMPT-INJ-001"
RULE_NAME="agent-exfiltration"
RULE_ASPECT="prompt-injection"
RULE_SEVERITY="critical"
RULE_DESCRIPTION="Agent or command prompt contains exfiltration phrasing — likely attacker-injected instruction to leak credentials or SSH keys."
RULE_REMEDIATION="Remove the attacker-controlled phrasing. If the agent prompt came from an untrusted source (marketplace, user input), rotate any credentials accessible to the agent and audit its run history."
RULE_REFERENCES=""

# Resolve lib dir robustly: BASH_SOURCE works for normal invocations;
# fall back to CSA_LIB_DIR (set by harness) when sourced inside a subshell.
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

  # Only scan agent/command markdown files under .claude/agents/ or .claude/commands/
  if [[ "$target_file" != */.claude/agents/*.md && "$target_file" != */.claude/commands/*.md ]]; then
    return 0
  fi

  # grep rc 1 is no match; rc 2 or more is a read error: rc 2 (SCANNER-002) unless a match is already in hand,
  # which is emitted, since the engine drops a detector's stdout on rc 2 (#1089). Skill-first question 3.
  # LC_ALL=C grep -a reads the file byte by byte in every locale, as HOOK-004 does: a NUL or a byte that is not
  # UTF-8 does not make grep call the file binary and print no line.
  local hits grc=0
  hits="$(LC_ALL=C grep -aniE \
    'read[[:space:]]+.*~/\.ssh|cat[[:space:]]+.*~/\.ssh|(POST|send|exfil).*attacker|curl[[:space:]]+.*(http|https)://.*~/\.' \
    "$target_file" 2>/dev/null)" || grc=$?
  [[ "$grc" -le 1 ]] || [[ -n "$hits" ]] || return 2
  [[ -n "$hits" ]] || return 0
  # LC_ALL=C on read only: in a UTF-8 locale, bash 5.2 joins a line that ends in an invalid byte to the next.
  printf '%s\n' "$hits" \
    | while LC_ALL=C IFS=: read -r line_no match; do
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
