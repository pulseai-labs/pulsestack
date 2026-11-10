#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/redact.sh"
source "$CSA_LIB_DIR/fingerprint.sh"

_csa_failed=0
_tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"

run_rule() { ( source "$1"; detect "$2" ); }
run_rule_pipefail() { ( set -o pipefail; source "$1"; detect "$2" ); }

# Helper: write a .mcp.json fixture
make_mcp() {
  local name="$1"; local content="$2"
  local f="$_tmp/$name"
  printf '%s\n' "$content" > "$f"
  printf '%s' "$f"
}

# ---------------------------------------------------------------------------
# MCP-001: untrusted-endpoint
# ---------------------------------------------------------------------------

test_untrusted_endpoint_detects_http() {
  local f; f="$(make_mcp ".mcp.json" '{
    "mcpServers": {
      "bad": { "url": "http://untrusted.example.com/mcp", "transport": "http" }
    }
  }')"
  local out; out="$(run_rule "$CSA_RULES_DIR/mcp/untrusted-endpoint.sh" "$f")"
  assert_contains "$out" "MCP-001" || return 1
}

test_untrusted_endpoint_negative_https() {
  local f; f="$(make_mcp ".mcp.json" '{
    "mcpServers": {
      "good": { "url": "https://trusted.example.com/mcp", "transport": "http" }
    }
  }')"
  local out; out="$(run_rule "$CSA_RULES_DIR/mcp/untrusted-endpoint.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# ---------------------------------------------------------------------------
# MCP-002: missing-auth
# ---------------------------------------------------------------------------

test_missing_auth_detects_unauthenticated() {
  local f; f="$(make_mcp ".mcp.json" '{
    "mcpServers": {
      "noauth": { "url": "https://api.example.com/mcp" }
    }
  }')"
  local out; out="$(run_rule "$CSA_RULES_DIR/mcp/missing-auth.sh" "$f")"
  assert_contains "$out" "MCP-002" || return 1
}

test_missing_auth_negative_with_auth_header() {
  local f; f="$(make_mcp ".mcp.json" '{
    "mcpServers": {
      "authenticated": {
        "url": "https://api.example.com/mcp",
        "headers": { "Authorization": "Bearer ${MCP_TOKEN}" }
      }
    }
  }')"
  local out; out="$(run_rule "$CSA_RULES_DIR/mcp/missing-auth.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# ---------------------------------------------------------------------------
# MCP-003: env-var-leak
# ---------------------------------------------------------------------------

test_env_var_leak_detects_literal_token() {
  local f; f="$(make_mcp ".mcp.json" '{
    "mcpServers": {
      "leaky": {
        "command": "npx",
        "args": ["my-mcp-server", "--token", "sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
      }
    }
  }')"
  local out; out="$(run_rule "$CSA_RULES_DIR/mcp/env-var-leak.sh" "$f")"
  assert_contains "$out" "MCP-003" || return 1
}

test_env_var_leak_detects_large_literal_token_under_pipefail() {
  local f="$_tmp/.mcp.json"
  {
    printf '{"mcpServers":{"leaky":{"env":{"TOKEN":"sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    awk 'BEGIN { for (i = 0; i < 1048576; i++) printf "!" }'
    printf '"}}}}\n'
  } > "$f"

  local out; out="$(run_rule_pipefail "$CSA_RULES_DIR/mcp/env-var-leak.sh" "$f")"
  assert_contains "$out" "MCP-003" \
    "large early secret-shaped MCP value under pipefail" || return 1
}

test_env_var_leak_negative_env_ref() {
  local f; f="$(make_mcp ".mcp.json" '{
    "mcpServers": {
      "safe": {
        "command": "npx",
        "args": ["my-mcp-server", "--token", "${MCP_TOKEN}"],
        "env": { "MCP_TOKEN": "${MCP_TOKEN}" }
      }
    }
  }')"
  local out; out="$(run_rule "$CSA_RULES_DIR/mcp/env-var-leak.sh" "$f")"
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

# MCP-001 reports an http:// url on line 2 of a .mcp.json whose line 1 holds a NUL byte, in a UTF-8 locale and in C.
test_untrusted_endpoint_reads_a_file_grep_calls_binary() {
  local loc u rc=0 f="$_tmp/nul/.mcp.json"
  u="$(_utf8_locale)"; mkdir -p "${f%/*}"
  printf '{"a": "\000",\n "mcpServers": {"bad": {"url": "http://untrusted.example.com/mcp"}}}\n' > "$f"
  for loc in ${u:+"$u"} C; do
    assert_eq "2" "$(_lines_under "$loc" "$CSA_RULES_DIR/mcp/untrusted-endpoint.sh" "$f")" "$loc: MCP-001" || rc=1
  done
  return "$rc"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
csa_test_run test_untrusted_endpoint_detects_http          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_untrusted_endpoint_negative_https        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_missing_auth_detects_unauthenticated     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_missing_auth_negative_with_auth_header   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_env_var_leak_detects_literal_token       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_env_var_leak_detects_large_literal_token_under_pipefail || _csa_failed=$((_csa_failed + 1))
csa_test_run test_env_var_leak_negative_env_ref            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_untrusted_endpoint_reads_a_file_grep_calls_binary || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
