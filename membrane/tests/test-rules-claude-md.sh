#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/redact.sh"
source "$CSA_LIB_DIR/fingerprint.sh"

_csa_failed=0
_tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"
trap 'rm -rf "$_tmp"' EXIT

run_rule() { ( source "$1"; detect "$2" ); }

# Helper: create a CLAUDE.md fixture in a subdirectory
make_claude_md() {
  local subdir="$1"; local content="$2"
  local dir="$_tmp/$subdir"
  mkdir -p "$dir"
  printf '%s\n' "$content" > "$dir/CLAUDE.md"
  printf '%s' "$dir/CLAUDE.md"
}

# ---------------------------------------------------------------------------
# CLAUDE-MD-001: plaintext-secrets
# ---------------------------------------------------------------------------

test_plaintext_secrets_detects_github_token() {
  local f; f="$(make_claude_md "proj1" "Use INTERNAL_API_TOKEN=ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa to access staging.")"
  local out; out="$(run_rule "$CSA_RULES_DIR/claude-md/plaintext-secrets.sh" "$f")"
  assert_contains "$out" "CLAUDE-MD-001" || return 1
  assert_contains "$out" "***" || return 1
}

test_plaintext_secrets_negative_clean_content() {
  local f; f="$(make_claude_md "proj2" "# Standard project
This is a sample CLAUDE.md with no secrets and no internal markers.")"
  local out; out="$(run_rule "$CSA_RULES_DIR/claude-md/plaintext-secrets.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# ---------------------------------------------------------------------------
# CLAUDE-MD-002: internal-markers
# ---------------------------------------------------------------------------

test_internal_markers_detects_confidential() {
  local f; f="$(make_claude_md "proj3" "CONFIDENTIAL: This document contains proprietary information.")"
  local out; out="$(run_rule "$CSA_RULES_DIR/claude-md/internal-markers.sh" "$f")"
  assert_contains "$out" "CLAUDE-MD-002" || return 1
}

test_internal_markers_negative_clean_content() {
  local f; f="$(make_claude_md "proj4" "# Team workflow project
This project uses make + pytest. No secrets here.")"
  local out; out="$(run_rule "$CSA_RULES_DIR/claude-md/internal-markers.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# _utf8_locale — the name of an installed UTF-8 locale (C.UTF-8, en_US.UTF-8 or en_GB.UTF-8), or nothing.
_utf8_locale() {
  locale -a 2>/dev/null | awk '{ l = tolower($0); gsub(/-/, "", l) } l == "c.utf8" || l == "en_us.utf8" || l == "en_gb.utf8" { print; exit }'
}

# _lines_under <locale> <rule> <file> — the lines a rule's detect() reports in <file> under LC_ALL=<locale>, sorted
# and comma-joined; "-" when it reports none.
_lines_under() {
  local got
  got="$( (export LC_ALL="$1"; source "$2"; detect "$3") 2>/dev/null | jq -r '.line' | sort -n | paste -sd, -)"
  printf '%s' "${got:--}"
}

# CLAUDE-MD-001 and CLAUDE-MD-002 report their line 2 in a CLAUDE.md whose line 1 holds a NUL byte, in a UTF-8 locale
# and in C.
test_claude_md_rules_read_a_file_grep_calls_binary() {
  local loc u rc=0 d="$_tmp/nul"
  u="$(_utf8_locale)"; mkdir -p "$d/a" "$d/b"
  printf '# \000\nUse ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa to access staging.\n' > "$d/a/CLAUDE.md"
  printf '# \000\nCONFIDENTIAL: proprietary.\n' > "$d/b/CLAUDE.md"
  for loc in ${u:+"$u"} C; do
    assert_eq "2" "$(_lines_under "$loc" "$CSA_RULES_DIR/claude-md/plaintext-secrets.sh" "$d/a/CLAUDE.md")" "$loc: CLAUDE-MD-001" || rc=1
    assert_eq "2" "$(_lines_under "$loc" "$CSA_RULES_DIR/claude-md/internal-markers.sh" "$d/b/CLAUDE.md")" "$loc: CLAUDE-MD-002" || rc=1
  done
  return "$rc"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
csa_test_run test_plaintext_secrets_detects_github_token    || _csa_failed=$((_csa_failed + 1))
csa_test_run test_plaintext_secrets_negative_clean_content  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_internal_markers_detects_confidential     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_internal_markers_negative_clean_content   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_claude_md_rules_read_a_file_grep_calls_binary || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
