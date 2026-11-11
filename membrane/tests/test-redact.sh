#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/redact.sh"

_csa_failed=0

test_redact_anthropic_key() {
  local input="sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAxyz1"
  local out; out="$(csa_redact "$input")"
  assert_contains "$out" "sk-a" || return 1
  assert_contains "$out" "***" || return 1
  assert_contains "$out" "xyz1" || return 1
  if [[ "$out" == *"AAAAAAAAAAAAAAA"* ]]; then return 1; fi
}

test_redact_jwt() {
  local input="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NSJ9.signature123"
  local out; out="$(csa_redact "$input")"
  assert_contains "$out" "eyJh" || return 1
  assert_contains "$out" "***" || return 1
  if [[ "$out" == *"InR5cCI6IkpXVCJ9"* ]]; then return 1; fi
}

test_redact_github_pat() {
  local input="The token is ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa for prod"
  local out; out="$(csa_redact "$input")"
  assert_contains "$out" "ghp_" || return 1
  assert_contains "$out" "***" || return 1
  if [[ "$out" == *"aaaaaaaaaaaaaaaaaaaaaaaa"* ]]; then return 1; fi
}

test_redact_aws_key() {
  local input="aws_access_key_id = AKIAIOSFODNN7EXAMPLE"
  local out; out="$(csa_redact "$input")"
  assert_contains "$out" "AKIA" || return 1
  assert_contains "$out" "***" || return 1
}

test_redact_base64_blob() {
  local input="data=YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5"
  local out; out="$(csa_redact "$input")"
  assert_contains "$out" "***" || return 1
}

test_redact_passes_through_non_secret() {
  local input="this is a normal line with no secrets, just words like permission and allow"
  local out; out="$(csa_redact "$input")"
  assert_eq "$input" "$out"
}

test_redact_length_cap() {
  local long
  long="$(printf 'x%.0s' {1..500})"
  CSA_REDACT_MAX_LEN=200 out="$(csa_redact "$long")"
  assert_contains "$out" "truncated" || return 1
  [[ "${#out}" -lt 250 ]] || return 1
}

# csa_mask_command: each shape's value is `***`, the rest of the command as written. Each shape sits beside a control
# that must stay as written: a word that only holds the shape's text.
test_mask_command_bearer() {
  assert_eq "curl -H 'Authorization: Bearer ***' https://api.example/x" \
    "$(csa_mask_command "curl -H 'Authorization: Bearer FAKEtok0123456789' https://api.example/x")" "with Authorization:" || return 1
  assert_eq 'x "bearer ***" BEARER *** y' "$(csa_mask_command 'x "bearer abc.def" BEARER zz y')" "any case, no Authorization:" || return 1
  assert_eq 'unbearer xyz' "$(csa_mask_command 'unbearer xyz')" "control: a word ending in bearer is not the shape" || return 1
}

test_mask_command_user_password() {
  assert_eq 'curl -u admin:*** https://ci.example/h' "$(csa_mask_command 'curl -u admin:FAKEhunter2 https://ci.example/h')" "-u user:password" || return 1
  assert_eq 'curl --user=al:*** x; curl --user al:*** x; curl -ual:*** x' \
    "$(csa_mask_command 'curl --user=al:pw1 x; curl --user al:pw2 x; curl -ual:pw3 x')" "--user= , --user, attached -u" || return 1
  assert_eq 'git clone https://bob:***@git.example/r.git' "$(csa_mask_command 'git clone https://bob:pw0rd@git.example/r.git')" "URL credentials" || return 1
  assert_eq 'mysql -u root x; curl https://host:8080/p' "$(csa_mask_command 'mysql -u root x; curl https://host:8080/p')" \
    "control: -u with no colon, a URL port with no @" || return 1
}

test_mask_command_secret_flags() {
  assert_eq 'deploy --token *** --password *** --passwd *** --secret *** --api-key *** --apikey *** --auth ***' \
    "$(csa_mask_command "deploy --token T1 --password 'two words' --passwd \"q x\" --secret S --api-key K --apikey K2 --auth A:B")" "--flag value" || return 1
  assert_eq 'deploy --token=*** --password=*** x' "$(csa_mask_command 'deploy --token=T1 --password=P2 x')" "--flag=value" || return 1
  assert_eq 'x --auth-type basic --tokens 3 a--token b' "$(csa_mask_command 'x --auth-type basic --tokens 3 a--token b')" \
    "control: a longer flag, or the flag glued to a word" || return 1
}

test_mask_command_mysql_password() {
  assert_eq 'mysql -u root -p*** -e x' "$(csa_mask_command 'mysql -u root -pFAKEpassw0rd -e x')" "mysql" || return 1
  assert_eq 'DB=1 /usr/bin/mysqldump -p*** db && mysqladmin -p***;echo -pQ' \
    "$(csa_mask_command 'DB=1 /usr/bin/mysqldump -pS3cret db && mysqladmin -pZ;echo -pQ')" "mysqldump after an assignment, mysqladmin" || return 1
  assert_eq 'ls -pX; grep -pattern f; mysql -p x' "$(csa_mask_command 'ls -pX; grep -pattern f; mysql -p x')" \
    "control: -p in another command, and a bare -p" || return 1
}

# csa_redact_command cuts first, then masks: a command of any length costs one 200-byte pass, and a cut command
# says so.
test_redact_command_cuts_before_masking() {
  local s; s="$(printf 'X_TOKEN=abcdefghij %.0s' $(seq 1 50000))"
  local t0=$EPOCHREALTIME out t1
  out="$(csa_redact_command "$s")"; t1=$EPOCHREALTIME
  assert_eq "1" "$(awk -v a="$t0" -v b="$t1" 'BEGIN { print (b - a < 2) ? 1 : 0 }')" "a 1 MB command in under 2 s" || return 1
  assert_contains "$out" "X_TOKEN=*** X_TOKEN=***" "masked" || return 1
  assert_contains "$out" "…(truncated)" "cut, and says so" || return 1
  if [[ "$out" == *abcdefghij* ]]; then printf '    a value is printed\n' >&2; return 1; fi
  assert_eq 'deploy --token ***' "$(csa_redact_command 'deploy --token T1')" "control: a short command is not cut" || return 1
}

csa_test_run test_redact_anthropic_key            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_redact_jwt                      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_redact_github_pat               || _csa_failed=$((_csa_failed + 1))
csa_test_run test_redact_aws_key                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_redact_base64_blob              || _csa_failed=$((_csa_failed + 1))
csa_test_run test_redact_passes_through_non_secret || _csa_failed=$((_csa_failed + 1))
csa_test_run test_redact_length_cap               || _csa_failed=$((_csa_failed + 1))
csa_test_run test_mask_command_bearer             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_mask_command_user_password      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_mask_command_secret_flags       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_mask_command_mysql_password     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_redact_command_cuts_before_masking || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
