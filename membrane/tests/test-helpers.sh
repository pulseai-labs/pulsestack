#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"

_csa_failed=0

_CSA_TMP="$(mktemp -d "$TMPDIR/csa-test.XXXXXX")"

# _utf8_locale — the first installed UTF-8 locale that collates (en_US, en_GB), else the first C UTF-8 one; empty if none.
_utf8_locale() {
  local l
  for l in en_US.UTF-8 en_US.utf8 en_GB.UTF-8 en_GB.utf8 C.UTF-8 C.utf8; do
    if LC_ALL="$l" bash -c '[[ "$(locale charmap 2>/dev/null)" == UTF-8 ]]' 2>/dev/null; then printf '%s' "$l"; return 0; fi
  done
}

# --- csa_sha256 ---
test_sha256_known_answer() {
  local expected="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  local actual
  actual="$(csa_sha256 "abc")"
  assert_eq "$expected" "$actual" "csa_sha256 NIST FIPS known answer for 'abc'" || return 1
}

# --- csa_printable: every byte 0x20-0x7E passes; a control byte, DEL and any byte over 0x7F do not, in a UTF-8
# locale as in C.
test_printable_is_the_ascii_print_range() {
  local all="" i loc
  for (( i = 32; i < 127; i++ )); do all="$all$(printf "\\x$(printf '%02x' "$i")")"; done
  loc="$(_utf8_locale)"
  for l in C ${loc:+"$loc"}; do
    LC_ALL="$l" csa_printable "$all" || { printf '    %s: the 95 printable bytes were refused\n' "$l" >&2; return 1; }
    LC_ALL="$l" csa_printable "" || { printf '    %s: the empty string was refused\n' "$l" >&2; return 1; }
    for b in $'\t' $'\n' $'\r' $'\x01' $'\x1f' $'\x7f' $'\x80' $'\xe9' $'\xc3\xa9' $'\xe2\x80\x83'; do
      if LC_ALL="$l" csa_printable "a${b}b"; then
        printf '    %s: a name holding %q passed\n' "$l" "$b" >&2; return 1
      fi
    done
  done
}

# --- csa_escape: one printable line for any name ---
test_escape_names_every_byte() {
  assert_eq 'plain name.json' "$(csa_escape 'plain name.json')" "a printable name is unchanged" || return 1
  assert_eq 'a\\b' "$(csa_escape 'a\b')" "a backslash is doubled" || return 1
  assert_eq 'a\nb\tc\rd' "$(csa_escape $'a\nb\tc\rd')" "newline, tab and CR are named" || return 1
  assert_eq 'caf\xe9' "$(csa_escape $'caf\351')" "a Latin-1 byte is hex" || return 1
  assert_eq 'caf\xc3\xa9' "$(LC_ALL="$(_utf8_locale)" csa_escape $'caf\xc3\xa9')" "UTF-8 is hex, byte by byte, in a UTF-8 locale" || return 1
  assert_eq 'x\x7f\x01' "$(csa_escape $'x\x7f\x01')" "DEL and a control byte are hex" || return 1
}

# csa_escape is linear: a 16 KiB name of bytes outside printable ASCII escapes in well under a second, and so does one
# with a single such byte at the end.
test_escape_is_linear() {
  local all one t0 t1
  all="$(head -c 16384 /dev/zero | tr '\0' '\351')"; one="$(head -c 16384 /dev/zero | tr '\0' a)"$'\351'
  t0=$EPOCHREALTIME; csa_escape "$all" >/dev/null; csa_escape "$one" >/dev/null; t1=$EPOCHREALTIME
  assert_eq "1" "$(awk -v a="$t0" -v b="$t1" 'BEGIN { print (b - a < 1) ? 1 : 0 }')" "two 16 KiB names in under 1 s" || return 1
  assert_eq 65536 "$(csa_escape "$all" | wc -c | tr -d ' ')" "control: every byte is escaped" || return 1
}

# --- csa_root_ok: an absolute directory with no control byte, or rc 2 ---
test_root_ok_takes_only_an_absolute_directory() {
  local d="$_CSA_TMP/root ok" nl="$_CSA_TMP/a"$'\n'"b" rc
  mkdir -p "$d" "$nl"
  : > "$_CSA_TMP/file"
  csa_root_ok "$d" || { printf '    an absolute directory was refused\n' >&2; return 1; }
  csa_root_ok "$d/" || { printf '    a trailing slash was refused\n' >&2; return 1; }
  rc=0; (cd "$_CSA_TMP" && csa_root_ok "root ok") 2>/dev/null || rc=$?
  assert_eq 2 "$rc" "a relative root is refused" || return 1
  rc=0; csa_root_ok "." 2>/dev/null || rc=$?
  assert_eq 2 "$rc" "'.' is refused" || return 1
  rc=0; csa_root_ok "$_CSA_TMP/file" 2>/dev/null || rc=$?
  assert_eq 2 "$rc" "a file is refused" || return 1
  rc=0; csa_root_ok "$_CSA_TMP/missing" 2>/dev/null || rc=$?
  assert_eq 2 "$rc" "a missing path is refused" || return 1
  rc=0; csa_root_ok "$nl" 2>/dev/null || rc=$?
  assert_eq 2 "$rc" "a root holding a newline is refused" || return 1
}

# --- csa_is_version_name reads bytes: in a collating UTF-8 locale [A-Za-z] matched `ß`, so `1.0.0-ß` read as a
# version there and not in C. Control: an ASCII pre-release still reads as one in both.
test_version_name_reads_bytes() {
  local loc; loc="$(_utf8_locale)"
  [[ -n "$loc" ]] || { printf '    no UTF-8 locale is installed\n' >&2; return 1; }
  for l in C "$loc"; do
    if LC_ALL="$l" csa_is_version_name $'1.0.0-\xc3\x9f'; then
      printf '    %s: 1.0.0-ß read as a version\n' "$l" >&2; return 1
    fi
    LC_ALL="$l" csa_is_version_name 1.0.0-beta.1 || { printf '    %s: 1.0.0-beta.1 not a version\n' "$l" >&2; return 1; }
    if LC_ALL="$l" csa_is_version_name $'\xef\xbd\x86\xef\xbd\x86\xef\xbd\x86\xef\xbd\x86\xef\xbd\x86\xef\xbd\x86\xef\xbd\x86'; then
      printf '    %s: seven fullwidth f read as a commit digest\n' "$l" >&2; return 1
    fi
  done
}

# --- csa_tmp_scope: one directory under the caller's TMPDIR, exported as TMPDIR, removed on exit and on INT, TERM
# and HUP, each signal exiting 128 plus its number.
test_tmp_scope_removes_its_dir_on_exit() {
  local p="$_CSA_TMP/scope-exit" out
  mkdir -p "$p"
  out="$(TMPDIR="$p" bash -c 'source "$1"; csa_tmp_scope t; d="$TMPDIR"; f="$(mktemp)"; [[ "$f" == "$d"/* ]] && printf in; : > "$d/x"' _ "$CSA_LIB_DIR/helpers.sh")"
  assert_eq in "$out" "mktemp lands in the scope" || return 1
  assert_eq "" "$(ls -A "$p")" "nothing is left after a normal exit" || return 1
}

# The scope sits at its parent's physical path: a TMPDIR reached through a symlink or spelled with `..` gives a scope
# under the directory it names, so a path a test builds from TMPDIR is the one the engine prints. Control: a plain
# TMPDIR gives a scope right under it.
test_tmp_scope_is_at_a_physical_path() {
  local real="$_CSA_TMP/scope-real" t got
  mkdir -p "$real" "$_CSA_TMP/scope-lead"
  ln -s "$real" "$_CSA_TMP/scope-link"
  for t in "$_CSA_TMP/scope-link" "$_CSA_TMP/scope-lead/../scope-real" "/$real" "$real"; do
    got="$(TMPDIR="$t" bash -c 'source "$1"; csa_tmp_scope t; printf %s "$TMPDIR"' _ "$CSA_LIB_DIR/helpers.sh")"
    assert_eq "$real" "${got%/csa-t.*}" "TMPDIR=$t" || return 1
  done
  assert_eq "" "$(ls -A "$real")" "control: each scope is removed" || return 1
}

test_tmp_scope_removes_its_dir_on_each_signal() {
  local p sig want rc
  for sig in TERM:143 INT:130 HUP:129; do
    want="${sig#*:}"; sig="${sig%%:*}"
    p="$_CSA_TMP/scope-$sig"; mkdir -p "$p"
    rc=0
    TMPDIR="$p" timeout --preserve-status -s "$sig" 0.5 bash -c 'source "$1"; csa_tmp_scope t; : > "$TMPDIR/x"; while :; do :; done' _ "$CSA_LIB_DIR/helpers.sh" || rc=$?
    assert_eq "$want" "$rc" "$sig: exit status" || return 1
    assert_eq "" "$(ls -A "$p")" "$sig: nothing is left" || return 1
  done
}

# A dir a test made unreadable (mode 000) is removed too.
test_tmp_scope_removes_an_unreadable_dir() {
  local p="$_CSA_TMP/scope-000"
  mkdir -p "$p"
  TMPDIR="$p" bash -c 'source "$1"; csa_tmp_scope t; mkdir -p "$TMPDIR/d/e"; chmod 000 "$TMPDIR/d"' _ "$CSA_LIB_DIR/helpers.sh"
  assert_eq "" "$(ls -A "$p")" "nothing is left" || return 1
}

# No test file sets an EXIT trap: it would replace the one tests/_helpers.sh sets, and the file's temp dirs would stay
# behind (each of 16 tests in one file replaced the last one's trap, so 15 dirs stayed per run).
test_no_test_file_sets_an_exit_trap() {
  local hits
  hits="$(LC_ALL=C awk '/^[[:space:]]*trap[[:space:]].*(EXIT|0)[[:space:]]*$/ { print FILENAME ":" FNR }' "$CSA_PLUGIN_ROOT"/tests/*.sh)"
  assert_eq "" "$hits" "EXIT traps in test files" || return 1
}

# One test file run alone leaves nothing under the TMPDIR it was given, bin/csa calls included.
test_a_test_file_leaves_no_temp_dir() {
  local p="$_CSA_TMP/one-file"
  mkdir -p "$p"
  TMPDIR="$p" bash "$CSA_PLUGIN_ROOT/tests/test-severity.sh" >/dev/null 2>&1 || { printf '    test-severity.sh failed\n' >&2; return 1; }
  TMPDIR="$p" "$CSA_PLUGIN_ROOT/bin/csa" --list >/dev/null 2>&1 || { printf '    bin/csa --list failed\n' >&2; return 1; }
  assert_eq "" "$(ls -A "$p")" "left behind" || return 1
}

csa_test_run test_sha256_known_answer                       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_printable_is_the_ascii_print_range        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_escape_names_every_byte                   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_escape_is_linear                          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_root_ok_takes_only_an_absolute_directory  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_version_name_reads_bytes                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tmp_scope_removes_its_dir_on_exit         || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tmp_scope_removes_its_dir_on_each_signal  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tmp_scope_is_at_a_physical_path           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tmp_scope_removes_an_unreadable_dir       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_no_test_file_sets_an_exit_trap            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_a_test_file_leaves_no_temp_dir            || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
