#!/usr/bin/env bash
RULE_ID="HOOK-002"
RULE_NAME="rm-rf"
RULE_ASPECT="hooks"
RULE_SEVERITY="critical"
RULE_DESCRIPTION="Destructive rm -rf on absolute path detected in a hook script, handler or command."
RULE_AUTO_FIXABLE="false"
RULE_MECHANICALLY_FIXABLE="false"
RULE_REMEDIATION="Remove or scope the rm -rf command. Avoid deleting absolute paths from hook scripts; use temporary directories scoped to the build."
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
# shellcheck source=/dev/null
source "$_RULE_DIR/hook-entries.sh" 2>/dev/null || true

RULE_PATTERN='rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[[:space:]]+/'


detect() {
  local target_file="$1"
  [[ -r "$target_file" ]] || return 0
  # Only scan known hook handler and wrapper script surfaces, and hook handler code (csa_hook_handler_file).
  if [[ "$target_file" != */.claude/hooks* && "$target_file" != *.sh \
        && "$target_file" != */.opencode/bin/* && "$target_file" != */.opencode/*.js \
        && "$target_file" != */.opencode/*.ts && "$target_file" != */.opencode/*.mjs ]] \
        && ! csa_hook_handler_file "$target_file"; then
    return 0
  fi
  # Match rm with -rf or -fr flags followed by an absolute path /
  # Skip benign relative/variable paths like ./build or "$TMPDIR"
  # grep rc 1 is no match; rc 2 or more is a read error: rc 2 here (a SCANNER-002 in the engine, not a
  # clean read) unless a match is already in hand. The engine drops a detector's stdout on rc 2, so a
  # match found before the error is emitted and returned 0, never traded for the stop (#1089).
  # Skill-first question 3: only adds a stop.
  # LC_ALL=C grep -a reads the file byte by byte in every locale, as HOOK-004 does: a NUL or a byte that is not
  # UTF-8 does not make grep call the file binary and print no line.
  local hits grc=0
  hits="$(LC_ALL=C grep -anE "$RULE_PATTERN" "$target_file" 2>/dev/null)" || grc=$?
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

# detect_text <entry-json> <file> — one decoded hook command from a JSON hook
# entry (settings, hooks/hooks.json, plugin.json). Matches the WHOLE command,
# newlines included. Skill-first question 3: a check on open input that can
# only add a stop.
detect_text() {
  local entry="$1" target_file="$2" text
  text="$(csa_hook_entry_command "$entry")" || return $?
  [[ "$text" =~ $RULE_PATTERN ]] || return 1
  csa_hook_entry_emit "$RULE_ID" "$RULE_SEVERITY" "$entry" "$target_file"
}
