#!/usr/bin/env bash
# lib/redact.sh — secret-pattern-aware redaction.
# Never emit full secret material; preserve first 4 + last 4 chars for identification.

# csa_redact <string> — redact secret-like substrings; emit redacted form on stdout.
# Recognized patterns (regex):
#   - sk-ant-api03-...   (Anthropic)
#   - sk-...             (generic OpenAI-style)
#   - ghp_..., gho_..., ghs_..., ghr_...  (GitHub PAT family)
#   - eyJ...             (JWT — base64url-encoded JSON starts with {"alg":...)
#   - AKIA[0-9A-Z]{16}   (AWS access key ID)
#   - Bearer <token>     (Authorization header)
#   - base64 credentials >= 32 chars (defensive: any contiguous [A-Za-z0-9+/=]{32+})
csa_redact() {
  local input="$1"
  local max_len="${CSA_REDACT_MAX_LEN:-200}"
  # Apply length cap first.
  if [[ "${#input}" -gt "$max_len" ]]; then
    input="${input:0:$max_len}…(truncated)"
  fi
  # Use awk for regex substitutions (portable; macOS sed lacks some PCRE features).
  printf '%s' "$input" | awk '
    {
      line = $0
      # Anthropic / OpenAI sk- keys
      while (match(line, /sk-[a-zA-Z0-9_-]{20,}/)) {
        m = substr(line, RSTART, RLENGTH)
        head = substr(m, 1, 4)
        tail = substr(m, length(m) - 3, 4)
        repl = head "***" tail
        line = substr(line, 1, RSTART - 1) repl substr(line, RSTART + RLENGTH)
      }
      # GitHub PAT family
      while (match(line, /gh[psorau]_[a-zA-Z0-9]{36,}/)) {
        m = substr(line, RSTART, RLENGTH)
        head = substr(m, 1, 4)
        tail = substr(m, length(m) - 3, 4)
        repl = head "***" tail
        line = substr(line, 1, RSTART - 1) repl substr(line, RSTART + RLENGTH)
      }
      # JWT-like base64url JSON header
      while (match(line, /eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/)) {
        m = substr(line, RSTART, RLENGTH)
        head = substr(m, 1, 4)
        tail = substr(m, length(m) - 3, 4)
        repl = head "***" tail
        line = substr(line, 1, RSTART - 1) repl substr(line, RSTART + RLENGTH)
      }
      # AWS access key ID
      while (match(line, /AKIA[0-9A-Z]{16}/)) {
        m = substr(line, RSTART, RLENGTH)
        repl = "AKIA" "***" substr(m, length(m) - 3, 4)
        line = substr(line, 1, RSTART - 1) repl substr(line, RSTART + RLENGTH)
      }
      # Generic long base64-credential blob (catch-all, last; min 32 chars)
      while (match(line, /[A-Za-z0-9+\/=]{32,}/)) {
        m = substr(line, RSTART, RLENGTH)
        head = substr(m, 1, 4)
        tail = substr(m, length(m) - 3, 4)
        repl = head "***" tail
        line = substr(line, 1, RSTART - 1) repl substr(line, RSTART + RLENGTH)
      }
      print line
    }
  '
}

# csa_mask_assignments <string> — every value assigned to a name holding API_KEY, SECRET, TOKEN or PASSWORD (any case;
# `NAME=value`, `NAME = value`) replaced by `***`: the name stays, the value is gone. The value is the run of
# non-space bytes after `=`. Byte-wise in every locale. Used for SECRETS-003's preview and the report's list of hook
# commands, so a password of any length never reaches chat or the report.
csa_mask_assignments() {
  local LC_ALL=C s="$1" out=""
  local kw='[Aa][Pp][Ii]_[Kk][Ee][Yy]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Tt][Oo][Kk][Ee][Nn]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]'
  local re='^(.*[^A-Za-z0-9_]|)([A-Za-z0-9_]*('"$kw"')[A-Za-z0-9_]*)([[:space:]]*=[[:space:]]*)([^[:space:]]+)(.*)$'
  # The greedy prefix finds the last assignment: mask it, keep its tail, go on with what is before it.
  while [[ "$s" =~ $re ]]; do
    out="${BASH_REMATCH[2]}${BASH_REMATCH[4]}***${BASH_REMATCH[6]}$out"
    s="${BASH_REMATCH[1]}"
  done
  printf '%s' "$s$out"
}
