#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"

_csa_failed=0

test_fixture_secrets_issue_exists() {
  grep -q 'sk-ant-api03' "$CSA_FIXTURES_DIR/issues/secrets-issue/CLAUDE.md" || return 1
}
test_fixture_permissions_issue_exists() {
  jq -e '.permissions.allow | index("Bash(*)")' "$CSA_FIXTURES_DIR/issues/permissions-issue/.claude/settings.json" >/dev/null || return 1
}
test_fixture_hook_injection_exists() {
  grep -q 'curl.*|.*bash' "$CSA_FIXTURES_DIR/issues/hook-injection/.claude/hooks-handlers/session-start.sh" || return 1
}
test_fixture_mcp_misconfigured_exists() {
  jq -e '.mcpServers.untrusted.url | startswith("http://")' "$CSA_FIXTURES_DIR/issues/mcp-misconfigured/.mcp.json" >/dev/null || return 1
}
test_fixture_claude_md_secret_exists() {
  grep -qE 'INTERNAL_API_TOKEN=ghp_' "$CSA_FIXTURES_DIR/issues/claude-md-secret/CLAUDE.md" || return 1
}
test_fixture_prompt_injection_exists() {
  grep -q '~/.ssh/id_rsa' "$CSA_FIXTURES_DIR/issues/prompt-injection-agent/.claude/agents/helper.md" || return 1
}

csa_test_run test_fixture_secrets_issue_exists           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_fixture_permissions_issue_exists       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_fixture_hook_injection_exists          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_fixture_mcp_misconfigured_exists       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_fixture_claude_md_secret_exists        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_fixture_prompt_injection_exists        || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
