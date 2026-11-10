#!/usr/bin/env bash
# tests/test-report-findings-file.sh — the three report functions read a findings file or take the
# findings themselves, and refuse anything that is not findings JSONL. Every row runs through the
# bin/csa dispatcher (set -euo pipefail, as the skill runs) except the one sourced row.
set -u
source "$(dirname "$0")/_helpers.sh"
CSA="$CSA_PLUGIN_ROOT/bin/csa"

_csa_failed=0
_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-rff.XXXXXX")"
_n=0

# _mk_root: sets $root to a fresh project dir with .claude/audits/.
_mk_root() { _n=$((_n + 1)); root="$_CSA_TMP/t$_n"; mkdir -p "$root/.claude/audits"; }
_c() { ( cd "$root" && HOME=/nonexistent CSA_PROJECT_ROOT="$root" "$CSA" "$@" ); }

# _line <uid> <severity> [<display_id>] : one finding line, with no display id when none is given.
_line() {
  jq -nc --arg u "$1" --arg s "$2" --arg d "${3-}" \
    '{rule_id:"PERM-002",severity:$s,file:".claude/settings.json",line:1,offset:0,preview:"p",finding_uid:$u,state:"NEW"}
     + (if $d == "" then {} else {display_id:$d} end)'
}

# ---- a findings file is read ----------------------------------------------------------------

test_renderers_read_a_findings_file() {
  _mk_root
  { _line FUID-aaaaaaa1 critical SA-2026-01-01-01-001; _line FUID-aaaaaaa2 high SA-2026-01-01-01-002; } > "$root/f.jsonl"
  local out rc=0
  out="$(_c report_render_chat "$root/f.jsonl" r.md 2>&1)" || rc=$?
  assert_eq 0 "$rc" "chat on a file exits 0" || return 1
  assert_contains "$out" "### Critical (1)" "chat lists the file's Critical" || return 1
  assert_contains "$out" "- SA-2026-01-01-01-001 — PERM-002 at .claude/settings.json:1" "chat names the Critical by its display id" || return 1
  assert_contains "$out" "— 2 findings" "chat counts the file's two findings" || return 1
  rc=0; out="$(_c report_render_markdown "$root/f.jsonl" '{}' "$root/r.md" 2>&1)" || rc=$?
  assert_eq 0 "$rc" "markdown on a file exits 0" || return 1
  assert_eq "" "$out" "markdown on a file prints nothing" || return 1
  assert_contains "$(cat "$root/r.md")" "| Critical | 1 | 0 | 0 | 1 |" "the report counts the Critical" || return 1
  assert_contains "$(cat "$root/r.md")" '**finding_uid:** `FUID-aaaaaaa2`' "the report lists the High" || return 1
  { _line FUID-aaaaaaa1 critical; printf '\n'; _line FUID-aaaaaaa2 high; } > "$root/b.jsonl"
  rc=0; out="$(_c report_assign_display_ids "$root/b.jsonl" 2026-01-01-04 2>&1)" || rc=$?
  assert_eq 0 "$rc" "assign on a file exits 0" || return 1
  assert_eq "SA-2026-01-01-04-001 SA-2026-01-01-04-002" "$(jq -r .display_id <<<"$out" | tr '\n' ' ' | sed 's/ $//')" \
    "assign numbers the file's findings, past a blank line" || return 1
  # Control: the findings themselves still work, so a caller that passes content is unchanged.
  assert_contains "$(_c report_render_chat "$(cat "$root/f.jsonl")")" "SA-2026-01-01-01-002" "content form" || return 1
  # Control: an empty file is no findings, exit 0.
  : > "$root/e.jsonl"
  rc=0; _c report_render_markdown "$root/e.jsonl" '{}' "$root/e.md" 2>/dev/null || rc=$?
  assert_eq 0 "$rc" "an empty file exits 0" || return 1
  assert_contains "$(cat "$root/e.md")" "_No findings._" "an empty file renders no findings" || return 1
}

# ---- anything else is exit 4, one message, nothing rendered -----------------------------------

test_not_findings_jsonl_is_rc4_and_renders_nothing() {
  _mk_root
  local bad rc out err fn
  for bad in 'x' '[1]' '"s"' 'null' '{"a":1}{"b":2}' '{"a":1} {"b":2}' "$(_line FUID-aaaaaaa1 critical SA-1)"$'\n''garbage'; do
    printf '%s\n' "$bad" > "$root/b.jsonl"; rm -f "$root/b.md"
    rc=0; out="$(_c report_render_markdown "$root/b.jsonl" '{}' "$root/b.md" 2>"$root/err")" || rc=$?
    err="$(cat "$root/err")"
    assert_eq 4 "$rc" "markdown exit on $(printf %q "$bad")" || return 1
    [[ ! -e "$root/b.md" ]] || { printf '    a report was written for %q\n' "$bad" >&2; return 1; }
    [[ "$err" != *"jq:"* ]] || { printf '    raw jq error: %s\n' "$err" >&2; return 1; }
    assert_eq 1 "$(grep -c . "$root/err")" "one message line for $(printf %q "$bad")" || return 1
    assert_contains "$err" "$root/b.jsonl" "the message names the file" || return 1
    rc=0; out="$(_c report_render_chat "$root/b.jsonl" 2>/dev/null)" || rc=$?
    assert_eq 4 "$rc" "chat exit on $(printf %q "$bad")" || return 1
    assert_eq "" "$out" "chat prints no summary for $(printf %q "$bad")" || return 1
    rc=0; out="$(_c report_assign_display_ids "$root/b.jsonl" 2026-01-01-01 2>/dev/null)" || rc=$?
    assert_eq 4 "$rc" "assign exit on $(printf %q "$bad")" || return 1
    assert_eq "" "$out" "assign prints nothing for $(printf %q "$bad")" || return 1
  done
  # An unreadable file prints the one csa line too, never cat's own message beside it.
  if [[ "$(id -u)" -ne 0 ]]; then
    _line FUID-aaaaaaa1 high SA-1 > "$root/u.jsonl"; chmod 000 "$root/u.jsonl"
    for fn in report_render_chat report_assign_display_ids; do
      rc=0; _c "$fn" "$root/u.jsonl" 2026-01-01-01 >/dev/null 2>"$root/err" || rc=$?
      assert_eq 4 "$rc" "$fn on an unreadable file" || return 1
      assert_eq 1 "$(grep -c . "$root/err")" "$fn: one message line for an unreadable file ($(tr '\n' '|' < "$root/err"))" || return 1
    done
    rc=0; _c report_render_markdown "$root/u.jsonl" '{}' "$root/u.md" >/dev/null 2>"$root/err" || rc=$?
    assert_eq "4 1" "$rc $(grep -c . "$root/err")" "markdown on an unreadable file: exit and one line" || return 1
    [[ ! -e "$root/u.md" ]] || { printf '    a report was written for an unreadable file\n' >&2; return 1; }
    chmod 600 "$root/u.jsonl"
  fi
  # A path that does not exist is not findings either.
  for fn in report_render_chat report_assign_display_ids; do
    rc=0; _c "$fn" "$root/missing.jsonl" 2026-01-01-01 >/dev/null 2>&1 || rc=$?
    assert_eq 4 "$rc" "$fn on a missing file" || return 1
  done
  rc=0; _c report_render_markdown "$root/missing.jsonl" '{}' "$root/m.md" >/dev/null 2>&1 || rc=$?
  assert_eq 4 "$rc" "markdown on a missing file" || return 1
  [[ ! -e "$root/m.md" ]] || { printf '    a report was written for a missing file\n' >&2; return 1; }
  # Control: blank lines around valid objects are still findings.
  { printf '\n'; _line FUID-aaaaaaa1 high SA-2026-01-01-01-001; printf '  \n'; } > "$root/ok.jsonl"
  rc=0; _c report_render_markdown "$root/ok.jsonl" '{}' "$root/ok.md" 2>/dev/null || rc=$?
  assert_eq 0 "$rc" "blank lines around a finding exit 0" || return 1
}

# Sourced, with no errexit, the refusal holds too: no zero table, no report file.
test_not_findings_jsonl_is_rc4_sourced() {
  _mk_root
  printf 'x\n' > "$root/b.jsonl"
  local rc=0 out
  out="$( source "$CSA_LIB_DIR/helpers.sh"; source "$CSA_LIB_DIR/fingerprint.sh"; source "$CSA_LIB_DIR/report-render.sh"
          csa_report_render_chat "$root/missing.jsonl" 2>/dev/null )" || rc=$?
  assert_eq 4 "$rc" "sourced chat on a missing file" || return 1
  assert_eq "" "$out" "sourced chat prints no summary" || return 1
  rc=0
  ( source "$CSA_LIB_DIR/helpers.sh"; source "$CSA_LIB_DIR/fingerprint.sh"; source "$CSA_LIB_DIR/report-render.sh"
    csa_report_render_markdown "$root/b.jsonl" '{}' "$root/b.md" 2>/dev/null ) || rc=$?
  assert_eq 4 "$rc" "sourced markdown on a file that is not JSONL" || return 1
  [[ ! -e "$root/b.md" ]] || { printf '    sourced markdown wrote a report\n' >&2; return 1; }
}

# A project's first report: the report's directory does not exist yet, so the renderer makes it.
# When it cannot, it says so and writes nothing.
test_markdown_creates_the_report_directory() {
  _mk_root
  rm -rf "$root/.claude/audits"
  _line FUID-aaaaaaa1 critical SA-2026-01-01-01-001 > "$root/f.jsonl"
  local rc=0 out
  out="$(_c report_render_markdown "$root/f.jsonl" '{}' "$root/.claude/audits/2026-01-01-01.md" 2>&1)" || rc=$?
  assert_eq 0 "$rc" "markdown with no .claude/audits/ ($out)" || return 1
  assert_contains "$(cat "$root/.claude/audits/2026-01-01-01.md")" "| Critical | 1 | 0 | 0 | 1 |" "the report holds the Critical" || return 1
  : > "$root/blocker"
  rc=0; out="$(_c report_render_markdown "$root/f.jsonl" '{}' "$root/blocker/r.md" 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || { printf '    markdown exits 0 with no directory to write to\n' >&2; return 1; }
  assert_eq "csa: cannot create $root/blocker; no report written" "$out" "one message line" || return 1
}

# The findings passed as content are refused the same way as a file that holds them.
test_not_findings_jsonl_as_content_is_rc4() {
  _mk_root
  local bad rc out
  for bad in 'x' '[1]' 'null' '{"a":1}{"b":2}' "$(_line FUID-aaaaaaa1 critical SA-1)"$'\n''garbage'; do
    rc=0; out="$(_c report_render_chat "$bad" 2>"$root/err")" || rc=$?
    assert_eq "4 " "$rc $out" "chat exit and output on content $(printf %q "$bad")" || return 1
    assert_eq 1 "$(grep -c . "$root/err")" "one message line for content $(printf %q "$bad")" || return 1
    [[ "$(cat "$root/err")" != *"jq:"* ]] || { printf '    raw jq error: %s\n' "$(cat "$root/err")" >&2; return 1; }
    rc=0; _c report_assign_display_ids "$bad" 2026-01-01-01 >/dev/null 2>&1 || rc=$?
    assert_eq 4 "$rc" "assign exit on content $(printf %q "$bad")" || return 1
    rm -f "$root/c.md"; rc=0; _c report_render_markdown "$bad" '{}' "$root/c.md" >/dev/null 2>&1 || rc=$?
    assert_eq 4 "$rc" "markdown exit on content $(printf %q "$bad")" || return 1
    [[ ! -e "$root/c.md" ]] || { printf '    a report was written for content %q\n' "$bad" >&2; return 1; }
  done
  rc=0; out="$( source "$CSA_LIB_DIR/helpers.sh"; source "$CSA_LIB_DIR/fingerprint.sh"; source "$CSA_LIB_DIR/report-render.sh"
                csa_report_render_chat '{"a":1}{"b":2}' 2>/dev/null )" || rc=$?
  assert_eq "4 " "$rc $out" "sourced chat on content that is not JSONL" || return 1
}

# A line holding only spaces or tabs is blank: it is not counted, rendered or numbered.
test_whitespace_only_line_is_blank() {
  _mk_root
  { _line FUID-aaaaaaa1 high; printf '   \n\t\n'; _line FUID-aaaaaaa2 critical; } > "$root/ws.jsonl"
  local out
  out="$(_c report_assign_display_ids "$root/ws.jsonl" 2026-01-01-02)" || return 1
  assert_eq "SA-2026-01-01-02-001 SA-2026-01-01-02-002" "$(jq -r .display_id <<<"$out" | tr '\n' ' ' | sed 's/ $//')" "numbered past the blank lines" || return 1
  assert_contains "$(_c report_render_chat "$root/ws.jsonl")" "— 2 findings" "chat counts two findings" || return 1
  _c report_render_markdown "$root/ws.jsonl" '{}' "$root/ws.md" || return 1
  assert_eq 2 "$(grep -c '^### \[' "$root/ws.md")" "the report has two finding sections" || return 1
  # Control: a file of blank lines only is no findings.
  printf '  \n\t\n' > "$root/blank.jsonl"
  _c report_render_markdown "$root/blank.jsonl" '{}' "$root/blank.md" || return 1
  assert_contains "$(cat "$root/blank.md")" "_No findings._" "a blank file renders no findings" || return 1
}

# ---- the chat header's run number --------------------------------------------------------------

test_chat_header_reads_the_run_number_from_the_display_ids() {
  _mk_root
  { _line FUID-aaaaaaa1 high SA-2026-01-02-03-001; _line FUID-aaaaaaa2 high SA-2026-01-02-03-002; } > "$root/f.jsonl"
  assert_contains "$(_c report_render_chat "$root/f.jsonl")" "## Security audit — 2026-01-02 (run #03) — 2 findings" "run number from the ids" || return 1
  # A first line with no display id does not hide the run number the others carry.
  { _line FUID-aaaaaaa0 high; _line FUID-aaaaaaa1 high SA-2026-01-02-07-001; } > "$root/g.jsonl"
  assert_contains "$(_c report_render_chat "$root/g.jsonl")" "## Security audit — 2026-01-02 (run #07)" "run number past a line with no id" || return 1
  # Control: an id in the form with no run number reads as run #01, and so does no id at all.
  _line FUID-aaaaaaa1 high SA-2026-01-02-005 > "$root/o.jsonl"
  assert_contains "$(_c report_render_chat "$root/o.jsonl")" "## Security audit — 2026-01-02 (run #01)" "the old form is run #01" || return 1
  _line FUID-aaaaaaa1 high > "$root/n.jsonl"
  assert_contains "$(_c report_render_chat "$root/n.jsonl")" "(run #01) — 1 findings" "no display id is run #01" || return 1
}

# A findings file far larger than a pipe buffer (64 KiB) renders whole: nothing reads only its first
# line and leaves the writer to die of SIGPIPE under pipefail. A short first line and a 1 MB second
# one, so a reader that stops after line 1 leaves the writer blocked on a full pipe every time.
test_findings_file_over_a_pipe_buffer_renders() {
  _mk_root
  head -c 1000000 /dev/zero | tr '\0' 'p' > "$root/pad"
  { _line FUID-aaaaaaa1 high SA-2026-01-02-05-001
    _line FUID-aaaaaaa2 critical SA-2026-01-02-05-002 | jq -c --rawfile p "$root/pad" '.preview = $p'; } > "$root/big.jsonl"
  [[ "$(wc -c < "$root/big.jsonl")" -gt 1000000 ]] || { printf '    fixture is not over 1 MB\n' >&2; return 1; }
  local out rc=0
  out="$(_c report_render_chat "$root/big.jsonl" 2>&1)" || rc=$?
  assert_eq 0 "$rc" "chat on a file over a pipe buffer" || return 1
  assert_contains "$out" "## Security audit — 2026-01-02 (run #05) — 2 findings" "the header" || return 1
  assert_contains "$out" "- SA-2026-01-02-05-002 — PERM-002" "the Critical is listed" || return 1
  rc=0; _c report_render_markdown "$root/big.jsonl" '{}' "$root/big.md" >/dev/null 2>&1 || rc=$?
  assert_eq 0 "$rc" "markdown on a file over a pipe buffer" || return 1
  rc=0; out="$(_c report_assign_display_ids "$root/big.jsonl" 2026-01-02-06 2>/dev/null)" || rc=$?
  assert_eq "0 2" "$rc $(grep -c 'SA-2026-01-02-06-00[12]' <<<"$out")" "assign on a file over a pipe buffer" || return 1
}

csa_test_run test_renderers_read_a_findings_file                       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_findings_file_over_a_pipe_buffer_renders             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_not_findings_jsonl_is_rc4_and_renders_nothing         || _csa_failed=$((_csa_failed + 1))
csa_test_run test_not_findings_jsonl_is_rc4_sourced                     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_not_findings_jsonl_as_content_is_rc4                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_whitespace_only_line_is_blank                         || _csa_failed=$((_csa_failed + 1))
csa_test_run test_markdown_creates_the_report_directory                 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_chat_header_reads_the_run_number_from_the_display_ids || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
