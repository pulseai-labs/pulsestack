#!/usr/bin/env bash
# lib/redact.sh — secret-pattern-aware redaction for previews and the report's hook-command list.
# What is masked, and nothing else (a secret of another shape is printed as written: the README's
# "Not read, by design" list says so):
#   csa_redact            — every preview, and a finding id's excerpt: a key of one of the five shapes below
#                           keeps its first 4 and last 4 characters; the text is cut to 200 (bytes under bin/csa's
#                           LC_ALL=C, so a cut can split a multibyte character).
#   csa_mask_assignments  — SECRETS-003's preview and the hook-command list: the value of a secret-named variable.
#   csa_mask_command      — the hook-command list and a hook entry's preview: the shapes a command line carries.
#   csa_redact_command    — the three above for a hook command, cut to 200 bytes first.
# Skill-first: the masks read open input (a project's hook text, a file's lines), so they are question 3: each only
# removes text from what is printed, and a shape one misses is printed as written. The suppression count and the
# hook-command list read membrane's own output, question 2.

# csa_redact <string> — redact secret-like substrings; emit redacted form on stdout.
# Recognized patterns (regex), each kept to its first 4 and last 4 characters:
#   - sk-...             (Anthropic sk-ant-api03-..., OpenAI-style sk-...)
#   - ghp_..., gho_..., ghs_..., ghr_..., gha_..., ghu_...  (GitHub token family)
#   - eyJ...             (JWT — base64url-encoded JSON starts with {"alg":...)
#   - AKIA[0-9A-Z]{16}   (AWS access key ID)
#   - base64 credentials >= 32 chars (defensive: any contiguous [A-Za-z0-9+/=]{32+})
# A `Bearer <token>` is masked by csa_mask_command, not here: a finding id hashes this function's output, and a
# new shape here would move ids.
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
# non-space bytes after `=`, so a value holding a space keeps its tail (`--token='a b'` prints `--token=*** b'`; the
# README's limit list says so). Byte-wise in every locale. Used for SECRETS-003's preview and the report's list of hook
# commands. Skill-first question 3: it reads open text and only removes from it. Its loop is quadratic in the number
# of assignments, so every caller cuts the text to 200 bytes first.
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

# csa_mask_command <string> — the value of each of these command-line shapes replaced by `***`; everything else as
# written. Byte-wise (LC_ALL=C), one awk pass per line.
#   - `Bearer <token>`, any case, with or without `Authorization:` before it: `Bearer ***`.
#   - `-u user:password` and `--user user:password` (also `-uuser:password`, `--user=user:password`): `user:***`.
#   - `scheme://user:password@`: `scheme://user:***@`.
#   - `--token`, `--password`, `--passwd`, `--secret`, `--api-key`, `--apikey`, `--auth`, as `--flag value` or
#     `--flag=value`: `--flag ***`, `--flag=***`. A quoted value is masked up to its closing quote, except that
#     csa_mask_assignments has already masked `--token=`, `--password=` and `--secret=` up to the first space, so
#     `--token='a b'` prints `--token=*** b'`. A quoted token after `Bearer` and a quoted `-u "user:pw 1"` are
#     masked only up to a space or a quote (the README's limit list names these spellings).
#   - an attached `-p<value>` in a command whose command word (its first word that is not `NAME=value`, path
#     dropped) is `mysql`, `mysqldump` or `mysqladmin`: `-p***`. A command ends at `;`, `|` or `&`.
# Skill-first question 3: a mechanical edit of open text that only hides more of it; a shape it misses is printed as
# written, as it was before, and the limit list says so.
csa_mask_command() {
  local LC_ALL=C
  printf '%s' "$1" | awk -v q="'" -v dq='"' '
    # wordch(c) — c is a letter, digit or _.
    function wordch(c) { return c ~ /[A-Za-z0-9_]/ }
    # value_end(s, i) — the index just past a value starting at i: through the closing quote when s[i] is a quote
    # (else to the end), or up to the first space, tab or quote.
    function value_end(s, i,   c, j) {
      c = substr(s, i, 1)
      if (c == q || c == dq) {
        j = index(substr(s, i + 1), c)
        return j ? i + j + 1 : length(s) + 1
      }
      j = match(substr(s, i), "[ \t" q dq "]")
      return j ? i + j - 1 : length(s) + 1
    }
    function bearer(s,   out, m, p, k) {
      out = ""
      while (match(s, "[Bb][Ee][Aa][Rr][Ee][Rr][ \t]+[^ \t" q dq "]")) {
        p = RSTART; m = RLENGTH
        if (p > 1 && wordch(substr(s, p - 1, 1))) { out = out substr(s, 1, p); s = substr(s, p + 1); continue }
        k = p + m - 1
        out = out substr(s, 1, k - 1) "***"
        s = substr(s, value_end(s, k))
      }
      return out s
    }
    function userpass(s,   out, m, p, c) {
      out = ""
      while (match(s, "(-u|--user)(=|[ \t]*)[" q dq "]?[^ \t:" q dq "]*:[^ \t" q dq "]+")) {
        p = RSTART; m = RLENGTH
        if (p > 1 && substr(s, p - 1, 1) !~ /[ \t]/) { out = out substr(s, 1, p); s = substr(s, p + 1); continue }
        c = index(substr(s, p, m), ":")
        out = out substr(s, 1, p + c - 1) "***"
        s = substr(s, p + m)
      }
      return out s
    }
    function urlcred(s,   out, m, p, c) {
      out = ""
      while (match(s, "[A-Za-z][A-Za-z0-9+.-]*://[^:/@ \t" q dq "]*:[^@/ \t" q dq "]+@")) {
        p = RSTART; m = RLENGTH
        c = index(substr(s, p, m), "://") + 2
        c = c + index(substr(s, p + c, m - c), ":")
        out = out substr(s, 1, p + c - 1) "***@"
        s = substr(s, p + m)
      }
      return out s
    }
    function flags(s,   out, m, p, k) {
      out = ""
      while (match(s, "--(token|password|passwd|secret|api-key|apikey|auth)(=|[ \t]+)[^ \t]")) {
        p = RSTART; m = RLENGTH
        if (p > 1 && substr(s, p - 1, 1) !~ /[ \t]/) { out = out substr(s, 1, p); s = substr(s, p + 1); continue }
        k = p + m - 1
        out = out substr(s, 1, k - 1) "***"
        s = substr(s, value_end(s, k))
      }
      return out s
    }
    # A token is a run of `;`, `|` and `&` (it ends the command) or a word without them.
    function mysqlpw(s,   out, w, sep, cmd, base, t) {
      out = ""; cmd = ""
      while (match(s, /[;|&]+|[^ \t;|&]+/)) {
        sep = substr(s, 1, RSTART - 1); w = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        t = w
        if (w ~ /^[;|&]/) cmd = ""
        else if (cmd == "" && w !~ /^[A-Za-z_][A-Za-z0-9_]*=/) { base = w; sub(/.*\//, "", base); cmd = base }
        else if (cmd ~ /^(mysql|mysqldump|mysqladmin)$/ && w ~ /^-p./) t = "-p***"
        out = out sep t
      }
      return out s
    }
    { print mysqlpw(flags(urlcred(userpass(bearer($0))))) }
  '
}

# csa_redact_command <command> — a hook command as the report and a hook entry's preview print it: cut to 200
# bytes (`${#t}` counts bytes under bin/csa's LC_ALL=C; a cut can split a multibyte character), then csa_mask_assignments, csa_mask_command and csa_redact's shapes, then `…(truncated)` when it was cut.
# Cutting first bounds the masks' work, whatever the command's length.
csa_redact_command() {
  local t="$1" more="" max=200
  if [[ "${#t}" -gt "$max" ]]; then
    t="${t:0:$max}"
    more="…(truncated)"
  fi
  t="$(csa_mask_command "$(csa_mask_assignments "$t")")"
  # csa_redact cuts at the same 200: a mask can lengthen a 1- or 2-character value to `***`.
  printf '%s%s' "$(CSA_REDACT_MAX_LEN=100000 csa_redact "$t")" "$more"
}
