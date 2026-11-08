#!/usr/bin/env bash
RULE_ID="SECRETS-004"
RULE_NAME="base64-credentials"
RULE_ASPECT="secrets"
RULE_SEVERITY="medium"
RULE_DESCRIPTION="Long base64-encoded blob detected; may contain embedded credentials."
RULE_AUTO_FIXABLE="false"
RULE_MECHANICALLY_FIXABLE="false"
RULE_REMEDIATION="Review the base64 blob. If it encodes a credential or private key, remove it from the file and rotate the secret."
RULE_REFERENCES=""

# A match is a run of [A-Za-z0-9+/]{40,} with up to two "=". Two kinds of run are skipped, and only these:
#   - pure hex: the whole run is [0-9a-fA-F]+ (a git SHA, a sha256 digest), unless the same line names a credential
#     (case-insensitive token, secret, passw, api_key / api-key / apikey, auth, credential, private_key / private-key):
#     "github_token": "<40 hex>" is still reported. Known limit: a hex credential on a line with no credential word
#     (dop_v1_<64 hex>, a bare key in a log) is no longer reported here. SECRETS-003 still reports NAME=value when the
#     name holds API_KEY, SECRET, TOKEN or PASSWORD; a JSON- or YAML-keyed hex token is reported only by this rule.
#     sk-..., ghp_... and AKIA... keys are not hex and are not affected; they stay SECRETS-001, and a JWT SECRETS-002.
#   - slash-heavy path: two or more "/" and every "/"-separated segment is a word shape ([A-Z]?[a-z0-9]+ or
#     [A-Z0-9]+; so no "+" and no "="), as in pulsestack/actions/runs/41344090802/rerun or ROOT/skills/orchestrate/references/roles
#     (the 0.4.x false positives: .dagr/scratch copies, plan paths, run URLs). The AWS documentation secret key
#     wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY has two slashes but a mixed-case segment, so it is still reported; so
#     is a path-shaped run with "+" or "=", a run with one slash, and any run with a camelCase or multi-capital segment.
#     Known limits: a Capitalized, UPPER-case or digit segment is a word shape, so a documentation webhook URL with XXXX
#     segments is skipped, and so is a base32 or hex token that sits as a segment between slashes
#     (.../webhooks/<32 hex>, A/B/JBSWY3DPEHPK3PXP).
# A line is dropped only when it holds at least one run and every run on it is skipped. Skill-first question 3: the
# scanner is a stop-only rail; a narrower pattern changes which stops it adds, and it still never approves anything.
# Each shape is pinned beside a control it must not skip (tests/test-rules-secrets.sh). The filter fails open: if awk
# cannot run, the unfiltered hits are reported.
_csa_b64_drop_skipped_lines() {
  LC_ALL=C awk '
    function is_path(m,   n, p, i) {
      n = split(m, p, "/")
      if (n < 3) return 0
      for (i = 1; i <= n; i++) {
        if (p[i] == "") continue
        if (p[i] !~ /^([A-Z]?[a-z0-9]+|[A-Z0-9]+)$/) return 0
      }
      return 1
    }
    {
      rest = $0; sub(/^[0-9]+:/, "", rest); keep = 0; seen = 0
      cred = (tolower(rest) ~ /token|secret|passw|api[_-]?key|auth|credential|private[_-]?key/)
      while (match(rest, /[A-Za-z0-9+\/]{40,}={0,2}/)) {
        m = substr(rest, RSTART, RLENGTH); seen = 1
        if ((m !~ /^[0-9a-fA-F]+$/ || cred) && !is_path(m)) { keep = 1; break }
        rest = substr(rest, RSTART + RLENGTH)
      }
      if (keep || !seen) print $0
    }'
}

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
  # grep rc 1 is no match; rc 2 or more is a read error: rc 2 (SCANNER-002) unless a match is already in hand,
  # which is emitted, since the engine drops a detector's stdout on rc 2 (#1089). Skill-first question 3.
  # LC_ALL=C grep -a reads the file byte by byte in every locale, as HOOK-004 does: a NUL or a byte that is not
  # UTF-8 does not make grep call the file binary and print no line. The checksum filter and the awk pass read the
  # same bytes the same way, so they cannot drop such a line either.
  local hits grc=0
  hits="$(LC_ALL=C grep -anE '[A-Za-z0-9+/]{40,}={0,2}' "$target_file" 2>/dev/null)" || grc=$?
  [[ "$grc" -le 1 ]] || [[ -n "$hits" ]] || return 2
  [[ -n "$hits" ]] || return 0
  local kept filtered
  filtered="$(printf '%s\n' "$hits" | LC_ALL=C grep -avE '(sha256:|sha1:|md5:)')" || true
  kept="$(printf '%s\n' "$filtered" | _csa_b64_drop_skipped_lines)" || kept="$filtered"
  [[ -n "$kept" ]] || return 0
  printf '%s\n' "$kept" \
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
