#!/usr/bin/env bash
RULE_ID="HOOK-005"
RULE_NAME="hook-entry-unreadable"
RULE_ASPECT="hooks"
RULE_SEVERITY="high"
RULE_DESCRIPTION="A hook declared in JSON (settings, a plugin's hooks/hooks.json or plugin.json), a hooks.json modules path, or a hook file whose name holds a newline or tab or that is a symlink could not be read, so that command, module or file was not checked."
RULE_REMEDIATION="Read the named JSON path or file by hand. Fix a malformed file or a hook entry of the wrong shape, point a hooks.json modules path at handler code inside the plugin's hooks/ dir, replace a symlink below a hook dir with the file it points at, rename a file whose name holds a newline or tab, or remove the entry, so the audit can read every hook command and module."
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

# detect never matches: this rule reads hook entries only, through detect_text,
# so one bad entry gives one finding and never one per HOOK rule.
detect() { return 1; }

# detect_text <entry-json> <file> — one finding per inconclusive entry, so the
# audit never reads clean while a hook went unread. Skill-first question 3: a
# mechanical check that can only add a stop.
detect_text() {
  local entry="$1" target_file="$2" jp why preview fuid sep has
  # A jq error is rc 2 (SCANNER-002), not "no match" (#1072 C10).
  has="$(printf '%s' "$entry" | jq -r 'has("inconclusive")' 2>/dev/null)" || return 2
  [[ "$has" == "true" ]] || return 1
  jp="$(printf '%s' "$entry" | jq -r '.json_path // ""')"
  why="$(printf '%s' "$entry" | jq -r '.inconclusive // ""')"
  preview="$(csa_redact "hook entry not read: $why")"
  sep="$(printf '\xe2\x90\x9f')"
  # Hash first: csa_finding_uid redacts its match (200-character cap), and both
  # parts can be long and attacker-chosen.
  fuid="$(csa_finding_uid "$RULE_ID" "$target_file" "$(csa_sha256 "${jp}${sep}${why}" | cut -c1-24)")"
  jq -nc --arg rule_id "$RULE_ID" --arg file "$target_file" --arg preview "$preview" \
    --arg severity "$RULE_SEVERITY" --arg fuid "$fuid" --arg jp "$jp" --arg why "$why" \
    '{rule_id: $rule_id, file: $file, line: 0, offset: 0, preview: $preview, severity: $severity, finding_uid: $fuid, context: {json_path: $jp, reason: $why}}'
}
