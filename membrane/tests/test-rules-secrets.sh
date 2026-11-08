#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/redact.sh"
source "$CSA_LIB_DIR/fingerprint.sh"

_csa_failed=0
_tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"
trap 'rm -rf "$_tmp"' EXIT

run_rule() {
  local rule="$1"; local file="$2"
  ( source "$rule"; detect "$file" )
}

# ---------------------------------------------------------------------------
# SECRETS-001: api-keys
# ---------------------------------------------------------------------------

test_api_keys_detects_anthropic() {
  local f="$_tmp/api_keys_pos.txt"
  printf 'key: sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/secrets/api-keys.sh" "$f")"
  assert_contains "$out" "SECRETS-001" || return 1
  assert_contains "$out" "***" || return 1
}

test_api_keys_negative_normal_text() {
  local f="$_tmp/api_keys_neg.txt"
  printf 'mentioning sk and api keys conceptually without real values\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/secrets/api-keys.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# ---------------------------------------------------------------------------
# SECRETS-002: jwt
# ---------------------------------------------------------------------------

test_jwt_detects_token() {
  local f="$_tmp/jwt_pos.txt"
  # A valid-looking JWT: header.payload.signature (all base64url segments)
  printf 'auth: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/secrets/jwt.sh" "$f")"
  assert_contains "$out" "SECRETS-002" || return 1
  assert_contains "$out" "***" || return 1
}

test_jwt_negative_short_base64() {
  local f="$_tmp/jwt_neg.txt"
  # eyJ prefix but too short — not a real JWT
  printf 'eyJhbGc short fragment without two dots\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/secrets/jwt.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# ---------------------------------------------------------------------------
# SECRETS-003: env-var-leak
# ---------------------------------------------------------------------------

test_env_var_leak_detects_secret() {
  local f="$_tmp/env_pos.sh"
  printf 'API_KEY=abcdefghijklmnopqrstuvwxyz123456\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/secrets/env-var-leak.sh" "$f")"
  assert_contains "$out" "SECRETS-003" || return 1
  assert_contains "$out" "SECRETS-003" || return 1
}

test_env_var_leak_negative_placeholder() {
  local f="$_tmp/env_neg.sh"
  # Placeholder values shorter than 12 chars won't match
  printf 'API_KEY=YOUR_KEY\nSECRET=changeme\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/secrets/env-var-leak.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# ---------------------------------------------------------------------------
# SECRETS-004: base64-credentials
# ---------------------------------------------------------------------------

test_base64_creds_detects_blob() {
  local f="$_tmp/b64_pos.txt"
  # 45-char base64 blob
  printf 'credential=YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/secrets/base64-credentials.sh" "$f")"
  assert_contains "$out" "SECRETS-004" || return 1
}

test_base64_creds_negative_checksum() {
  local f="$_tmp/b64_neg.txt"
  # Checksum lines with sha256: prefix should be skipped
  printf 'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\n' > "$f"
  local out; out="$(run_rule "$CSA_RULES_DIR/secrets/base64-credentials.sh" "$f")"
  [[ -z "$out" ]] || return 1
}

# --- #1034: SECRETS-004 skips a pure-hex match and a slash-heavy path, and nothing else -------------------
# Pure hex: the whole match is [0-9a-fA-F]+ (a git SHA, a sha256 digest). Slash-heavy path: the match holds two
# or more "/", no "+" and no "=", and every "/"-separated segment is a word shape ([A-Z]?[a-z0-9]+ or [A-Z0-9]+),
# so the AWS documentation key, whose segments are mixed-case, is still a finding.

_b64_hits() {  # <line> -> the SECRETS-004 findings for a one-line file
  local f="$_tmp/b64_$RANDOM.txt"; printf '%s\n' "$1" > "$f"
  run_rule "$CSA_RULES_DIR/secrets/base64-credentials.sh" "$f" | jq -c . | wc -l | tr -d ' '
}

test_base64_skips_pure_hex() {
  assert_eq 0 "$(_b64_hits 'commit 346080b0331055824b1cb88b01494ba057fcd4bb merged')" "git sha" || return 1
  assert_eq 0 "$(_b64_hits 'digest e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')" "sha256" || return 1
  assert_eq 0 "$(_b64_hits 'ABCDEF0123456789ABCDEF0123456789ABCDEF0123')" "upper-case hex" || return 1
  # control: one non-hex character makes it a blob again
  assert_eq 1 "$(_b64_hits 'x 346080b0331055824b1cb88b01494ba057fcd4bg')" "hex plus one g" || return 1
  assert_eq 1 "$(_b64_hits 'x 346080b0331055824b1cb88b01494ba057fcd4bb0g')" "hex plus trailing g" || return 1
}

test_base64_skips_slash_heavy_path() {
  assert_eq 0 "$(_b64_hits 'see pulseai-labs/pulsestack/actions/runs/41344090802/rerun for it')" "run url path" || return 1
  assert_eq 0 "$(_b64_hits 'read ROOT/skills/orchestrate/references/roles and more')" "plan path" || return 1
  assert_eq 0 "$(_b64_hits 'Users/draco/projects/claudeagent/scaffolding/docs/superpowers/plans')" "path, one segment is a word" || return 1
  assert_eq 0 "$(_b64_hits 'hook at /Users/example/projects/foo/git/hooks/commit')" "absolute path, empty first segment" || return 1
}

test_base64_path_controls_still_match() {
  # the AWS documentation secret key: two slashes, mixed-case segments
  assert_eq 1 "$(_b64_hits 'aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY')" "AWS doc key" || return 1
  # a base64 blob with + and =
  assert_eq 1 "$(_b64_hits 'token: QUJDREVGR0hJSktMTU5P+FFSU1RVVldYWVowMTIzNDU2Nzg5YWJjZGVm==')" "blob with + and =" || return 1
  # a long base64 blob, no slash
  assert_eq 1 "$(_b64_hits 'token: QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVowMTIzNDU2Nzg5YWJjZGVm')" "blob, no slash" || return 1
  # one slash is not slash-heavy
  assert_eq 1 "$(_b64_hits 'path abcdefghijklmnopqrstuvwxyz0123456789/abcdefghij')" "one slash" || return 1
  # a path-shaped run with "=" or "+" is a blob
  assert_eq 1 "$(_b64_hits 'p aaaaaaaaaaaa/bbbbbbbbbbbbbb/cccccccccccccc/ddddddd=')" "path with =" || return 1
  assert_eq 1 "$(_b64_hits 'p aaaaaaaaaaaa/bbbbbbbbbbbbbb/cccccc+cccccccc/ddddddd')" "path with +" || return 1
  # a skipped run does not hide a real one on the same line
  assert_eq 1 "$(_b64_hits 'run pulseai-labs/pulsestack/actions/runs/41344090802/rerun key QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVowMTIzNDU2Nzg5YWJjZGVm')" "path then blob" || return 1
  assert_eq 1 "$(_b64_hits 'sha 346080b0331055824b1cb88b01494ba057fcd4bb key wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY')" "sha then AWS key" || return 1
}

# --- fix round: a pure-hex skip does not apply on a line that names a credential --------------------------
test_base64_hex_on_a_credential_line_is_reported() {
  local h40="346080b0331055824b1cb88b01494ba057fcd4bb" h64="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  assert_eq 1 "$(_b64_hits "\"github_token\": \"$h40\"")" "github_token" || return 1
  assert_eq 1 "$(_b64_hits "client_SECRET = $h64")" "SECRET, upper-case" || return 1
  assert_eq 1 "$(_b64_hits "Password: $h40")" "Password (passw)" || return 1
  assert_eq 1 "$(_b64_hits "x-api_key $h40")" "api_key" || return 1
  assert_eq 1 "$(_b64_hits "apikey=$h40")" "apikey" || return 1
  assert_eq 1 "$(_b64_hits "Authorization: $h40")" "auth" || return 1
  assert_eq 1 "$(_b64_hits "credentials $h40")" "credential" || return 1
  assert_eq 1 "$(_b64_hits "private-key $h40")" "private-key" || return 1
  assert_eq 1 "$(_b64_hits "private_key $h40")" "private_key" || return 1
  # controls: a commit OID line with none of those words is still skipped, and so is a digest line
  assert_eq 0 "$(_b64_hits "commit $h40 merged into main")" "commit OID" || return 1
  assert_eq 0 "$(_b64_hits "dop_v1_$h64 is shown in the docs")" "documented: no credential word, a known limit" || return 1
}

test_base64_path_skip_controls_for_capitals() {
  # a segment with two or more leading capitals is not a word shape: reported ([A-Z]? must not become [A-Z]*)
  assert_eq 1 "$(_b64_hits 'p ABCdefghijklmnop/QRSTuvwxyz012345/ABCD6789abcdefghij')" "multi-capital segments" || return 1
  # a Capitalized or UPPER word segment still skips (documented)
  assert_eq 0 "$(_b64_hits 'p Abcdefghijklmnop/Qrstuvwxyz012345/ABCDEFGHIJKLMNOPQ')" "Capitalized and UPPER segments" || return 1
}

test_base64_filter_failure_keeps_the_finding() {
  # A filter that cannot run adds no skip: the unfiltered finding is reported (skill-first question 3 direction).
  local d="$_tmp/fakebin"; mkdir -p "$d"; printf '#!/bin/sh\nexit 2\n' > "$d/awk"; chmod +x "$d/awk"
  local f="$_tmp/b64_awkfail.txt"; printf 'see pulseai-labs/pulsestack/actions/runs/41344090802/rerun\n' > "$f"
  local out; out="$(PATH="$d:$PATH" run_rule "$CSA_RULES_DIR/secrets/base64-credentials.sh" "$f")"
  assert_contains "$out" "SECRETS-004" "an awk that fails does not drop the finding" || return 1
}

# ---------------------------------------------------------------------------
# A file grep would call binary: a NUL byte, or a byte that is not UTF-8 (Latin-1 text)
# ---------------------------------------------------------------------------

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

# Each secrets rule reports its secret on line 2 of a file whose line 1 holds a NUL byte, and SECRETS-001 and
# SECRETS-003 report a secret on a line that also holds Latin-1 text (`café` with \xe9), in a UTF-8 locale and in C
# alike. Matching is byte-wise: a UTF-8 em space between a name and `=` is not a space, so SECRETS-003 does not fire
# on it in any locale (it fired only in a UTF-8 locale before), beside the same line with an ASCII space, which does.
test_secrets_read_a_file_grep_calls_binary() {
  local loc rc=0 d="$_tmp/binary-bytes" u row rule f want got
  u="$(_utf8_locale)"
  [[ -n "$u" ]] || printf '    note: no UTF-8 locale installed; checked under C only\n'
  mkdir -p "$d"
  printf '{"a": "\000"}\n{"k": "AKIAABCDEFGHIJKLMNOP"}\n'                                  > "$d/key-nul.json"
  printf 'caf\351 AKIAABCDEFGHIJKLMNOP\n'                                                  > "$d/key-latin1.md"
  printf '# \000\nauth: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c\n' > "$d/jwt-nul.md"
  printf '# \000\nAPI_KEY=abcdefghijklmnopqrstuvwxyz123456\n'                              > "$d/env-nul.sh"
  printf 'API_KEY=abcdefghijklmnopqrstuvwxyz123456 # caf\351\n'                            > "$d/env-latin1.sh"
  printf 'TOKEN =\342\200\203abcdefghijklmnop\n'                                           > "$d/env-emspace.sh"
  printf 'TOKEN = abcdefghijklmnop\n'                                                      > "$d/env-space.sh"
  printf '# \000\ncredential=YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY\n'                > "$d/b64-nul.txt"
  for loc in ${u:+"$u"} C; do
    for row in 'api-keys key-nul.json 2' 'api-keys key-latin1.md 1' 'jwt jwt-nul.md 2' 'env-var-leak env-nul.sh 2' \
      'env-var-leak env-latin1.sh 1' 'env-var-leak env-emspace.sh -' 'env-var-leak env-space.sh 1' \
      'base64-credentials b64-nul.txt 2'; do
      read -r rule f want <<< "$row"
      got="$(_lines_under "$loc" "$CSA_RULES_DIR/secrets/$rule.sh" "$d/$f")"
      assert_eq "$want" "$got" "$loc: $rule on $f" || rc=1
    done
  done
  return "$rc"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
csa_test_run test_api_keys_detects_anthropic      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_api_keys_negative_normal_text   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_jwt_detects_token               || _csa_failed=$((_csa_failed + 1))
csa_test_run test_jwt_negative_short_base64       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_env_var_leak_detects_secret     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_env_var_leak_negative_placeholder || _csa_failed=$((_csa_failed + 1))
csa_test_run test_base64_creds_detects_blob       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_base64_creds_negative_checksum  || _csa_failed=$((_csa_failed + 1))

csa_test_run test_base64_skips_pure_hex                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_base64_skips_slash_heavy_path          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_base64_path_controls_still_match       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_base64_filter_failure_keeps_the_finding || _csa_failed=$((_csa_failed + 1))
csa_test_run test_base64_hex_on_a_credential_line_is_reported || _csa_failed=$((_csa_failed + 1))
csa_test_run test_base64_path_skip_controls_for_capitals || _csa_failed=$((_csa_failed + 1))
csa_test_run test_secrets_read_a_file_grep_calls_binary || _csa_failed=$((_csa_failed + 1))
[[ "$_csa_failed" -eq 0 ]] || exit 1
