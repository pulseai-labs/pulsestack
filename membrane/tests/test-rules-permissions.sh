#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/redact.sh"
source "$CSA_LIB_DIR/fingerprint.sh"

_csa_failed=0
_tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"

run_rule() {
  local rule="$1"; local file="$2"
  ( source "$rule"; detect "$file" )
}

# ---------------------------------------------------------------------------
# PERM-001: broad-allow
# ---------------------------------------------------------------------------

test_broad_allow_detects_bash_star() {
  local f="$_tmp/perm001_pos/settings.json"
  mkdir -p "$(dirname "$f")"
  printf '{"permissions":{"allow":["Bash(*)"],"deny":["Bash(rm -rf:*)"]}}\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/permissions/broad-allow.sh" "$f")"
  assert_contains "$out" "PERM-001" || return 1
}

test_broad_allow_negative_scoped() {
  local f="$_tmp/perm001_neg/settings.json"
  mkdir -p "$(dirname "$f")"
  printf '{"permissions":{"allow":["Bash(git:*)","Bash(npm:*)"],"deny":["Bash(rm -rf:*)"]}}\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/permissions/broad-allow.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# ---------------------------------------------------------------------------
# PERM-002: missing-deny
# ---------------------------------------------------------------------------

test_missing_deny_detects_broad_allow_no_deny() {
  local f="$_tmp/perm002_pos/settings.json"
  mkdir -p "$(dirname "$f")"
  printf '{"permissions":{"allow":["Bash(*)"],"deny":[]}}\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/permissions/missing-deny.sh" "$f")"
  assert_contains "$out" "PERM-002" || return 1
}

test_missing_deny_negative_scoped_allow_no_deny() {
  # Scoped allow with empty deny is acceptable — should not flag
  local f="$_tmp/perm002_neg/settings.json"
  mkdir -p "$(dirname "$f")"
  printf '{"permissions":{"allow":["Bash(git:*)"],"deny":[]}}\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/permissions/missing-deny.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# ---------------------------------------------------------------------------
# PERM-003: settings-local-divergence
# ---------------------------------------------------------------------------

test_local_divergence_detects_extra_allow() {
  local d="$_tmp/perm003_pos"
  mkdir -p "$d"
  printf '{"permissions":{"allow":["Bash(git:*)"],"deny":[]}}\n' > "$d/settings.json"
  printf '{"permissions":{"allow":["Bash(git:*)","Bash(*)"],"deny":[]}}\n' > "$d/settings.local.json"
  local out; out="$(run_rule "$CSA_RULES_DIR/permissions/settings-local-divergence.sh" "$d/settings.local.json")"
  assert_contains "$out" "PERM-003" || return 1
}

test_local_divergence_negative_same_allow() {
  local d="$_tmp/perm003_neg"
  mkdir -p "$d"
  printf '{"permissions":{"allow":["Bash(git:*)","Bash(make:*)"],"deny":["Bash(rm -rf:*)"]}}\n' > "$d/settings.json"
  printf '{"permissions":{"allow":["Bash(git:*)","Bash(make:*)"],"deny":["Bash(rm -rf:*)"]}}\n' > "$d/settings.local.json"
  local out; out="$(run_rule "$CSA_RULES_DIR/permissions/settings-local-divergence.sh" "$d/settings.local.json")"
  [[ -z "$out" ]] || return 1
}

# ---------------------------------------------------------------------------
# PERM-004: dangerous-combo
# ---------------------------------------------------------------------------

test_dangerous_combo_detects_bash_star_no_deny() {
  local f="$_tmp/perm004_pos/settings.json"
  mkdir -p "$(dirname "$f")"
  printf '{"permissions":{"allow":["Bash(*)"],"deny":[]}}\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/permissions/dangerous-combo.sh" "$f")"
  assert_contains "$out" "PERM-004" || return 1
  assert_contains "$out" "critical" || return 1
}

test_dangerous_combo_negative_with_deny() {
  local f="$_tmp/perm004_neg/settings.json"
  mkdir -p "$(dirname "$f")"
  printf '{"permissions":{"allow":["Bash(*)"],"deny":["Bash(rm -rf:*)"]}}\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/permissions/dangerous-combo.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
csa_test_run test_broad_allow_detects_bash_star          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_broad_allow_negative_scoped            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_missing_deny_detects_broad_allow_no_deny || _csa_failed=$((_csa_failed + 1))
csa_test_run test_missing_deny_negative_scoped_allow_no_deny || _csa_failed=$((_csa_failed + 1))
csa_test_run test_local_divergence_detects_extra_allow   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_local_divergence_negative_same_allow   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_dangerous_combo_detects_bash_star_no_deny || _csa_failed=$((_csa_failed + 1))
csa_test_run test_dangerous_combo_negative_with_deny     || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
