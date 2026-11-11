#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/state.sh"
source "$CSA_LIB_DIR/baseline.sh"

_csa_failed=0

# Shared sandbox — create once for the whole test file.
_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"
# record_audit reads the enabled-plugin set from $HOME; keep these tests off the host's.
export HOME="$_CSA_TMP/home"
mkdir -p "$HOME/.claude"

# ---------------------------------------------------------------------------
# 1. init creates schema_version=2 file
# ---------------------------------------------------------------------------
test_init_creates_schema_v2() {
  local root="$_CSA_TMP/t01"
  mkdir -p "$root"
  csa_state_init "$root"
  local state_file; state_file="$(csa_state_path "$root")"
  [[ -f "$state_file" ]] || { printf '    state.json not created\n' >&2; return 1; }
  local sv; sv="$(jq -r '.schema_version' "$state_file")"
  assert_eq "2" "$sv" "schema_version must be 2" || return 1
}

# ---------------------------------------------------------------------------
# 2. read missing file returns empty object
# ---------------------------------------------------------------------------
test_read_missing_returns_empty_object() {
  local root="$_CSA_TMP/t02"
  mkdir -p "$root"
  # Do NOT call csa_state_init — file should be absent.
  local out; out="$(csa_state_read "$root")"
  # Must be valid JSON (jq parses it without error).
  printf '%s' "$out" | jq '.' >/dev/null 2>&1 || { printf '    output is not valid JSON: %s\n' "$out" >&2; return 1; }
  # Must be the empty object literal (or at least jq-type == "object").
  local t; t="$(printf '%s' "$out" | jq -r 'type')"
  assert_eq "object" "$t" "csa_state_read missing file must return object" || return 1
}

# ---------------------------------------------------------------------------
# 3. record_audit appends to history
# ---------------------------------------------------------------------------
test_record_audit_appends_to_history() {
  local root="$_CSA_TMP/t03"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  csa_state_record_audit "$root" 1 ".claude/audits/2026-05-25-01.md" ""

  local state_file; state_file="$(csa_state_path "$root")"
  local len; len="$(jq '.audit_history | length' "$state_file")"
  assert_eq "1" "$len" "audit_history length must be 1 after first record_audit" || return 1
}

# ---------------------------------------------------------------------------
# 4. record_audit updates findings registry
# ---------------------------------------------------------------------------
test_record_audit_updates_findings_registry() {
  local root="$_CSA_TMP/t04"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  local findings_jsonl
  findings_jsonl='{"finding_uid":"FUID-abcd1234","rule_id":"PERM-003","severity":"medium","file":".claude/settings.json","display_id":"SA-2026-05-25-01-001"}'

  csa_state_record_audit "$root" 1 ".claude/audits/2026-05-25-01.md" "$findings_jsonl"

  local state_file; state_file="$(csa_state_path "$root")"
  local fuid; fuid="$(jq -r '.findings["FUID-abcd1234"].rule_id // empty' "$state_file")"
  assert_eq "PERM-003" "$fuid" "finding FUID-abcd1234 must appear in findings registry" || return 1
}

# ---------------------------------------------------------------------------
# record_audit reads a findings file, marks suppressed findings from suppressions.json,
# counts them apart, refreshes what a sighting carries and keeps a display id the input lacks
# ---------------------------------------------------------------------------
test_record_audit_reads_a_findings_file() {
  local root="$_CSA_TMP/t-file"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"
  local f="$_CSA_TMP/findings-file.jsonl"
  printf '%s\n' \
    '{"finding_uid":"FUID-file0001","rule_id":"PERM-001","severity":"medium","file":"a.json","display_id":"SA-F-001"}' \
    '{"finding_uid":"FUID-file0002","rule_id":"PERM-002","severity":"high","file":"b.json","display_id":"SA-F-002"}' > "$f"
  csa_state_record_audit "$root" 1 ".claude/audits/f.md" "$f" || { printf '    file form failed\n' >&2; return 1; }
  assert_eq "2" "$(jq '.findings | length' "$(csa_state_path "$root")")" "both findings in the file are registered" || return 1
  # Control: the content form records the same.
  local root2="$_CSA_TMP/t-file2"; mkdir -p "$root2/.claude/audits"; csa_state_init "$root2"
  csa_state_record_audit "$root2" 1 ".claude/audits/f.md" "$(cat "$f")" || return 1
  assert_eq "2" "$(jq '.findings | length' "$(csa_state_path "$root2")")" "the content form still records both" || return 1
  # An unreadable findings file is refused; no empty run is recorded.
  local runs_before; runs_before="$(jq '.audit_history | length' "$(csa_state_path "$root")")"
  chmod 000 "$f"
  local ec=0; csa_state_record_audit "$root" 2 ".claude/audits/f2.md" "$f" >/dev/null 2>&1 || ec=$?
  chmod 644 "$f"
  [[ "$ec" -ne 0 ]] || { printf '    an unreadable findings file recorded a run\n' >&2; return 1; }
  assert_eq "$runs_before" "$(jq '.audit_history | length' "$(csa_state_path "$root")")" "no run recorded from an unreadable file" || return 1
}

test_record_audit_marks_suppressed_findings() {
  local root="$_CSA_TMP/t-mark"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"
  printf '%s\n' '{"schema_version":1,"suppressions":[{"finding_uid":"FUID-mark0001","suppressed_by":"t","suppressed_at":"2026-01-01T00:00:00Z","note":"n"}]}' \
    > "$root/.claude/audits/suppressions.json"
  # The input carries no suppression state of its own: the mark comes from suppressions.json.
  local findings
  findings="$(printf '%s\n' \
    '{"finding_uid":"FUID-mark0001","rule_id":"PERM-001","severity":"medium","file":"a.json","state":"NEW"}' \
    '{"finding_uid":"FUID-mark0002","rule_id":"PERM-001","severity":"medium","file":"b.json","state":"NEW"}' \
    '{"finding_uid":"FUID-mark0003","rule_id":"PERM-002","severity":"high","file":"c.json","state":"NEW"}')"
  csa_state_record_audit "$root" 1 ".claude/audits/m.md" "$findings" || return 1
  local st; st="$(csa_state_path "$root")"
  assert_eq "true" "$(jq -r '.findings["FUID-mark0001"].suppressed' "$st")" "listed uid is marked" || return 1
  assert_eq "false" "$(jq -r '.findings["FUID-mark0002"].suppressed' "$st")" "unlisted uid is not marked" || return 1
  assert_eq "1 1 1" "$(jq -r '[.audit_history[-1].finding_counts.medium, .audit_history[-1].finding_counts.high, .audit_history[-1].finding_counts.suppressed] | join(" ")' "$st")" "buckets exclude the suppressed finding, which is counted apart" || return 1
  # A listed Critical is not hidden (suppress_filter shows it), so it is not marked and counts as critical.
  printf '%s\n' '{"schema_version":1,"suppressions":[{"finding_uid":"FUID-markcrit","suppressed_by":"t","suppressed_at":"2026-01-01T00:00:00Z","note":"n"}]}' \
    > "$root/.claude/audits/suppressions.json"
  csa_state_record_audit "$root" 2 ".claude/audits/m1.md" \
    '{"finding_uid":"FUID-markcrit","rule_id":"HOOK-002","severity":"critical","file":"h.sh","state":"NEW"}' || return 1
  assert_eq "false" "$(jq -r '.findings["FUID-markcrit"].suppressed' "$st")" "a listed Critical is not marked" || return 1
  assert_eq "1 0" "$(jq -r '[.audit_history[-1].finding_counts.critical, .audit_history[-1].finding_counts.suppressed] | join(" ")' "$st")" "a listed Critical counts as critical, not suppressed" || return 1
  # An unreadable suppressions file marks nothing and does not stop the write.
  # A two-document suppressions file, read with the libs sourced, marks nothing and keeps state.json whole.
  printf '%s\n%s\n' '{"schema_version":1,"suppressions":[{"finding_uid":"FUID-mark0001"}]}' '{"schema_version":1,"suppressions":[]}' \
    > "$root/.claude/audits/suppressions.json"
  csa_state_record_audit "$root" 3 ".claude/audits/m3.md" "$findings" 2>/dev/null || { printf '    refused on a two-document suppressions file\n' >&2; return 1; }
  assert_eq "false 3" "$(jq -r '[.findings["FUID-mark0001"].suppressed, (.audit_history | length)] | join(" ")' "$st")" "two-document file marks nothing; state.json is whole" || return 1
  printf '{ not json' > "$root/.claude/audits/suppressions.json"
  csa_state_record_audit "$root" 4 ".claude/audits/m2.md" "$findings" || { printf '    refused on a bad suppressions file\n' >&2; return 1; }
  assert_eq "false" "$(jq -r '.findings["FUID-mark0001"].suppressed' "$st")" "bad suppressions file marks nothing" || return 1
}

test_record_audit_refreshes_a_sighting_and_keeps_the_display_id() {
  local root="$_CSA_TMP/t-refresh"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"
  csa_state_record_audit "$root" 1 ".claude/audits/r1.md" \
    '{"finding_uid":"FUID-refr0001","rule_id":"PERM-001","severity":"medium","file":"a.json","display_id":"SA-R-001"}' || return 1
  # Second sighting: severity and file changed, and no display id (a suppressed finding gets none).
  csa_state_record_audit "$root" 2 ".claude/audits/r2.md" \
    '{"finding_uid":"FUID-refr0001","rule_id":"PERM-001","severity":"high","file":"b.json"}' || return 1
  local e; e="$(jq -c '.findings["FUID-refr0001"]' "$(csa_state_path "$root")")"
  assert_eq "high b.json SA-R-001 2" "$(jq -r '[.severity, .file, .last_display_id, .last_run_index] | join(" ")' <<<"$e")" "severity and file refreshed, display id kept" || return 1
}

# ---------------------------------------------------------------------------
# 6. GC evicts finding absent for > 10 runs (gap = 11)
# ---------------------------------------------------------------------------
test_gc_evicts_after_10_run_absence() {
  local root="$_CSA_TMP/t06"
  mkdir -p "$root/.claude/audits"

  # Craft state.json directly: finding last_run_index = 5, current run = 16 → gap 11.
  local state_file; state_file="$(csa_state_path "$root")"
  jq -n '{
    schema_version: 2,
    last_audit: null,
    self_integrity: {
      state_mtime_at_last_audit: 0,
      suppressions_mtime_at_last_audit: 0,
      git_tracked_check: { state_json_tracked: false, suppressions_json_tracked: false, checked_at: null }
    },
    findings: {
      "FUID-evict001": {
        rule_id: "PERM-003",
        severity: "medium",
        file: ".claude/settings.json",
        first_seen: "2026-01-01T00:00:00Z",
        last_seen: "2026-01-01T00:00:00Z",
        seen_in_runs: 1,
        last_run_index: 5,
        last_display_id: "SA-old"
      }
    },
    audit_history: [],
    applied_fixes: []
  }' > "$state_file"

  csa_state_gc_findings "$root" 16

  local present; present="$(jq -r '.findings["FUID-evict001"] // "null"' "$state_file")"
  assert_eq "null" "$present" "finding must be evicted when gap > 10" || return 1
}

# ---------------------------------------------------------------------------
# 7. GC keeps finding within 10-run window (gap = 10, NOT > 10)
# ---------------------------------------------------------------------------
test_gc_keeps_within_10_run_window() {
  local root="$_CSA_TMP/t07"
  mkdir -p "$root/.claude/audits"

  local state_file; state_file="$(csa_state_path "$root")"
  jq -n '{
    schema_version: 2,
    last_audit: null,
    self_integrity: {
      state_mtime_at_last_audit: 0,
      suppressions_mtime_at_last_audit: 0,
      git_tracked_check: { state_json_tracked: false, suppressions_json_tracked: false, checked_at: null }
    },
    findings: {
      "FUID-keep001": {
        rule_id: "PERM-003",
        severity: "medium",
        file: ".claude/settings.json",
        first_seen: "2026-01-01T00:00:00Z",
        last_seen: "2026-01-01T00:00:00Z",
        seen_in_runs: 1,
        last_run_index: 5,
        last_display_id: "SA-old"
      }
    },
    audit_history: [],
    applied_fixes: []
  }' > "$state_file"

  # current = 15, gap = 10 (NOT > 10) → should NOT be evicted.
  csa_state_gc_findings "$root" 15

  local rule_id; rule_id="$(jq -r '.findings["FUID-keep001"].rule_id // empty' "$state_file")"
  assert_eq "PERM-003" "$rule_id" "finding must NOT be evicted when gap == 10" || return 1
}

# ---------------------------------------------------------------------------
# 8–15. The first audit's .gitignore line: only <root>/.gitignore, only appended, only at a repository root
# ---------------------------------------------------------------------------
_GI_TAIL=$'# claude-security-audit\n.claude/audits/'

# A repository root's .gitignore without the line gets it appended; every line it had is kept as it was.
test_bootstrap_gitignore_appends_to_existing() {
  local root="$_CSA_TMP/t11"
  mkdir -p "$root/.git"
  printf 'node_modules/\n.env\n' > "$root/.gitignore"
  csa_state_bootstrap_gitignore "$root" >/dev/null || return 1
  assert_eq $'node_modules/\n.env\n\n'"$_GI_TAIL" "$(cat "$root/.gitignore")" "the old lines, then the comment and the line" || return 1
}

# The whole line must be there: a line that only holds the text (a comment, a longer path) is not the entry, so the
# entry is appended. Control: the exact line already there leaves the file byte for byte as it was.
test_bootstrap_gitignore_matches_a_whole_line() {
  local root="$_CSA_TMP/t11b" before
  mkdir -p "$root/.git"
  printf '# not .claude/audits/ here\n.claude/audits/old/\n' > "$root/.gitignore"
  csa_state_bootstrap_gitignore "$root" >/dev/null || return 1
  assert_eq $'# not .claude/audits/ here\n.claude/audits/old/\n\n'"$_GI_TAIL" "$(cat "$root/.gitignore")" "a partial match is not the line" || return 1
  before="$(cat "$root/.gitignore"; printf x)"
  csa_state_bootstrap_gitignore "$root" >/dev/null || return 1
  assert_eq "$before" "$(cat "$root/.gitignore"; printf x)" "control: a second run with the line present writes nothing" || return 1
}

# No .gitignore at a repository root: it is created with the comment and the line.
test_bootstrap_gitignore_creates_one_at_a_repository_root() {
  local root="$_CSA_TMP/t11c"
  mkdir -p "$root/.git"
  csa_state_bootstrap_gitignore "$root" >/dev/null || return 1
  assert_eq "$_GI_TAIL" "$(cat "$root/.gitignore")" "created with the two lines" || return 1
}

# A project below a repository root: nothing is written there or above; the line to add is printed. The ancestor's
# .gitignore keeps its four lines (it was replaced by membrane's two, and the project's own .claude/audits/ was not
# even ignored by them).
test_bootstrap_gitignore_never_writes_above_the_root() {
  local repo="$_CSA_TMP/t11d/repo" out
  mkdir -p "$repo/.git" "$repo/pkg/app"
  printf 'node_modules/\n.env\nsecrets/\n*.pem\n' > "$repo/.gitignore"
  out="$(csa_state_bootstrap_gitignore "$repo/pkg/app")" || return 1
  assert_eq $'node_modules/\n.env\nsecrets/\n*.pem' "$(cat "$repo/.gitignore")" "the ancestor's .gitignore is untouched" || return 1
  [[ ! -e "$repo/pkg/app/.gitignore" && ! -e "$repo/pkg/.gitignore" ]] || { printf '    a .gitignore was created\n' >&2; return 1; }
  assert_contains "$out" "nothing written" "says nothing was written" || return 1
  assert_contains "$out" ".claude/audits/" "prints the line to add" || return 1
}

# A git worktree's .git is a file: its root is a repository root, so its own .gitignore is written and the main
# checkout's is not touched.
test_bootstrap_gitignore_takes_a_git_file_as_a_root() {
  local main="$_CSA_TMP/t11e/main" wt
  wt="$main/.worktrees/wt"
  mkdir -p "$main/.git" "$wt"
  printf 'gitdir: %s/.git/worktrees/wt\n' "$main" > "$wt/.git"
  printf 'node_modules/\n' > "$main/.gitignore"
  csa_state_bootstrap_gitignore "$wt" >/dev/null || return 1
  assert_eq "node_modules/" "$(cat "$main/.gitignore")" "the main checkout's .gitignore is untouched" || return 1
  assert_eq "$_GI_TAIL" "$(cat "$wt/.gitignore" 2>/dev/null)" "the worktree's own .gitignore holds the line" || return 1
}

# A relative root is refused at once (it looped forever: the dirname of . is .).
test_bootstrap_gitignore_refuses_a_relative_root() {
  local d="$_CSA_TMP/t11f" rc=0
  mkdir -p "$d/.git"
  (cd "$d" && timeout 5 bash -c 'source "$1/helpers.sh"; source "$1/state.sh"; csa_state_bootstrap_gitignore .' _ "$CSA_LIB_DIR") >/dev/null 2>&1 || rc=$?
  assert_eq 2 "$rc" "rc 2, not a loop" || return 1
  [[ ! -e "$d/.gitignore" ]] || { printf '    a .gitignore was written\n' >&2; return 1; }
}

# A .gitignore that is a symlink is not written through.
test_bootstrap_gitignore_does_not_write_through_a_symlink() {
  local root="$_CSA_TMP/t11g" out
  mkdir -p "$root/.git"
  printf 'keep\n' > "$_CSA_TMP/t11g-target"
  ln -s "$_CSA_TMP/t11g-target" "$root/.gitignore"
  out="$(csa_state_bootstrap_gitignore "$root")" || return 1
  assert_eq "keep" "$(cat "$_CSA_TMP/t11g-target")" "the link's target is untouched" || return 1
  assert_contains "$out" "nothing written" "says nothing was written" || return 1
}

# ---------------------------------------------------------------------------
# 12–17. Focused scans age only the aspects they scanned (#429)
# ---------------------------------------------------------------------------
_CSA_PERM_FINDING='{"finding_uid":"FUID-perm0001","rule_id":"PERM-003","severity":"medium","file":".claude/settings.json","display_id":"SA-x-001"}'
_CSA_SEC_FINDING='{"finding_uid":"FUID-sec00001","rule_id":"SECRETS-001","severity":"critical","file":"CLAUDE.md","display_id":"SA-x-002"}'

# _csa_record <root> <run_index> <findings_jsonl> [<focus>]
_csa_record() {
  if [[ $# -ge 4 ]]; then
    csa_state_record_audit "$1" "$2" ".claude/audits/run-$2.md" "$3" "$4"
  else
    csa_state_record_audit "$1" "$2" ".claude/audits/run-$2.md" "$3"
  fi
}

# The issue's sequence, with its control in the same run: a full scan records a
# permissions finding and a secrets finding; 11 secrets-only scans that miss both
# keep the permissions finding (never scanned) and evict the secrets one (scanned
# 11 times and absent); a later full scan keeps the permissions finding's identity.
test_focused_scans_do_not_age_unscanned_aspects() {
  local root="$_CSA_TMP/t12"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"
  local state_file; state_file="$(csa_state_path "$root")"

  _csa_record "$root" 1 "$(printf '%s\n%s' "$_CSA_PERM_FINDING" "$_CSA_SEC_FINDING")" all || return 1
  local first_seen; first_seen="$(jq -r '.findings["FUID-perm0001"].first_seen' "$state_file")"

  local i
  for i in 2 3 4 5 6 7 8 9 10 11 12; do
    _csa_record "$root" "$i" "" secrets || return 1
  done

  assert_eq "PERM-003" "$(jq -r '.findings["FUID-perm0001"].rule_id // "evicted"' "$state_file")" \
    "11 secrets-only scans must not evict a permissions finding" || return 1
  assert_eq "evicted" "$(jq -r '.findings["FUID-sec00001"].rule_id // "evicted"' "$state_file")" \
    "control: a secrets finding absent from 11 secrets scans must still age out" || return 1

  local tagged_in="$_CSA_TMP/t12-findings.jsonl"
  printf '%s\n' "$_CSA_PERM_FINDING" > "$tagged_in"
  local tag; tag="$(csa_baseline_tag "$tagged_in" "$root" | jq -r '.state')"
  assert_eq "PERSISTED" "$tag" "the next full scan must not relabel it NEW" || return 1

  _csa_record "$root" 13 "$_CSA_PERM_FINDING" all || return 1
  assert_eq "$first_seen" "$(jq -r '.findings["FUID-perm0001"].first_seen' "$state_file")" \
    "a later full scan keeps first_seen" || return 1
  assert_eq "2" "$(jq -r '.findings["FUID-perm0001"].seen_in_runs' "$state_file")" \
    "a later full scan continues the same registry entry" || return 1
}

# Full audits keep 0.1.6's aging exactly: gap 10 stays, gap 11 goes.
test_full_scans_age_as_before() {
  local root="$_CSA_TMP/t13"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"
  local state_file; state_file="$(csa_state_path "$root")"

  _csa_record "$root" 1 "$_CSA_PERM_FINDING" || return 1
  local i
  for i in 2 3 4 5 6 7 8 9 10 11; do
    _csa_record "$root" "$i" "" || return 1
  done
  assert_eq "PERM-003" "$(jq -r '.findings["FUID-perm0001"].rule_id // "evicted"' "$state_file")" \
    "gap 10 after full scans must keep the finding" || return 1
  _csa_record "$root" 12 "" all || return 1
  assert_eq "evicted" "$(jq -r '.findings["FUID-perm0001"].rule_id // "evicted"' "$state_file")" \
    "gap 11 after full scans must evict the finding" || return 1
}

# Each audit record stores the aspect it scanned as `focus`; a full audit (or no
# focus argument) records `all`.
test_record_audit_stores_focus() {
  local root="$_CSA_TMP/t14"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"
  local state_file; state_file="$(csa_state_path "$root")"

  _csa_record "$root" 1 "" secrets || return 1
  _csa_record "$root" 2 "" all || return 1
  _csa_record "$root" 3 "" || return 1
  assert_eq '["secrets","all","all"]' "$(jq -c '[.audit_history[].focus]' "$state_file")" \
    "each run records its focus; no focus argument records all" || return 1
}

# A run index above the current one is outside the window and never counts as
# a skipped run.
test_gc_window_ignores_later_run_indices() {
  local root="$_CSA_TMP/t18"
  _csa_write_legacy_state "$root"
  local state_file; state_file="$(csa_state_path "$root")"
  jq '.audit_history += [{run_index: 17, focus: "secrets"}]' "$state_file" > "$state_file.new" \
    && mv "$state_file.new" "$state_file"
  csa_state_gc_findings "$root" 16
  assert_eq "evicted" "$(jq -r '.findings["FUID-perm0001"].rule_id // "evicted"' "$state_file")" \
    "a later focused run must not shorten the gap (gap 11)" || return 1
}

# An unknown focus is refused before state is written.
test_record_audit_refuses_unknown_focus() {
  local root="$_CSA_TMP/t15"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"
  local state_file; state_file="$(csa_state_path "$root")"
  _csa_record "$root" 1 "$_CSA_PERM_FINDING" all || return 1
  cp "$state_file" "$_CSA_TMP/t15-before.json"

  local f
  for f in secret ../rules ""; do
    assert_exits_with 2 csa_state_record_audit "$root" 2 ".claude/audits/run-2.md" "" "$f" || return 1
  done
  cmp -s "$state_file" "$_CSA_TMP/t15-before.json" \
    || { printf '    state.json changed after a refused focus\n' >&2; return 1; }
}

# _csa_write_legacy_state <root> — a 0.1.6 state: runs 1..15 recorded with no
# focus field, a permissions finding last seen in run 5.
_csa_write_legacy_state() {
  local state_file; state_file="$(csa_state_path "$1")"
  mkdir -p "$(dirname "$state_file")"
  jq -n '{
    schema_version: 2,
    last_audit: null,
    self_integrity: {
      state_mtime_at_last_audit: 0,
      suppressions_mtime_at_last_audit: 0,
      git_tracked_check: { state_json_tracked: false, suppressions_json_tracked: false, checked_at: null }
    },
    findings: {
      "FUID-perm0001": {
        rule_id: "PERM-003", severity: "medium", file: ".claude/settings.json",
        first_seen: "2026-01-01T00:00:00Z", last_seen: "2026-01-01T00:00:00Z",
        seen_in_runs: 1, last_run_index: 5, last_display_id: "SA-old"
      }
    },
    audit_history: [range(1; 16) | {run_index: ., date: "2026-01-01T00:00:00Z",
      report_path: ".claude/audits/old.md",
      finding_counts: {critical: 0, high: 0, medium: 0, low: 0, info: 0}}],
    applied_fixes: []
  }' > "$state_file"
}

# Upgrade input class: runs recorded by 0.1.6 and earlier read as full runs.
test_legacy_runs_read_as_full_runs() {
  local root="$_CSA_TMP/t16a" state_file
  _csa_write_legacy_state "$root"
  state_file="$(csa_state_path "$root")"
  _csa_record "$root" 16 "" all || return 1
  assert_eq "evicted" "$(jq -r '.findings["FUID-perm0001"].rule_id // "evicted"' "$state_file")" \
    "legacy runs plus one full run age a finding exactly as 0.1.6 (gap 11)" || return 1

  root="$_CSA_TMP/t16b"
  _csa_write_legacy_state "$root"
  state_file="$(csa_state_path "$root")"
  _csa_record "$root" 16 "" secrets || return 1
  assert_eq "PERM-003" "$(jq -r '.findings["FUID-perm0001"].rule_id // "evicted"' "$state_file")" \
    "legacy runs count as full; only the new secrets run is skipped (gap 10)" || return 1
}

# A finding whose rule_id names no shipped rule (SCANNER-*, TAMPER-*) has no
# aspect, so it ages on every run, as in 0.1.6.
test_unmapped_rule_id_ages_on_every_run() {
  local root="$_CSA_TMP/t17"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"
  local state_file; state_file="$(csa_state_path "$root")"
  _csa_record "$root" 1 '{"finding_uid":"FUID-scan0001","rule_id":"SCANNER-002","severity":"high","file":"x.sh","display_id":"SA-x-003"}' all || return 1
  local i
  for i in 2 3 4 5 6 7 8 9 10 11 12; do
    _csa_record "$root" "$i" "" secrets || return 1
  done
  assert_eq "evicted" "$(jq -r '.findings["FUID-scan0001"].rule_id // "evicted"' "$state_file")" \
    "an unmapped finding ages on focused runs too" || return 1
}


# #825: the audit records the enabled set it saw (the SessionStart reminder
# compares against it), not a hardcoded empty list.
test_record_audit_writes_the_enabled_set_snapshot() {
  local root="$_CSA_TMP/snap1"
  mkdir -p "$root/.claude/audits"
  printf '%s\n' '{"enabledPlugins":{"b@m":true,"a@m":true,"off@m":false}}' > "$root/.claude/settings.json"
  printf '%s\n' '{"enabledPlugins":["bare"]}' > "$HOME/.claude/settings.json"
  csa_state_init "$root"
  csa_state_record_audit "$root" 1 ".claude/audits/2026-05-25-01.md" ""
  local got; got="$(jq -c '.last_audit.enabled_plugins_snapshot' "$(csa_state_path "$root")")"
  rm -f "$HOME/.claude/settings.json"
  assert_eq '[{"name":"a@m"},{"name":"b@m"},{"name":"bare"}]' "$got" "snapshot holds the enabled keys, sorted, as {name}"
}

test_record_audit_refuses_when_the_enabled_set_is_unknown() {
  local root="$_CSA_TMP/snap2" rc=0
  mkdir -p "$root/.claude/audits"
  mkdir "$root/.claude/settings.json"
  csa_state_init "$root"
  csa_state_record_audit "$root" 1 ".claude/audits/2026-05-25-01.md" "" 2>/dev/null || rc=$?
  assert_eq "2" "$rc" "an unreadable settings path is rc 2" || return 1
  local len; len="$(jq '.audit_history | length' "$(csa_state_path "$root")")"
  assert_eq "0" "$len" "nothing was recorded"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
csa_test_run test_init_creates_schema_v2                          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_read_missing_returns_empty_object               || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_appends_to_history                 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_updates_findings_registry          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_reads_a_findings_file                || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_marks_suppressed_findings            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_refreshes_a_sighting_and_keeps_the_display_id || _csa_failed=$((_csa_failed + 1))
csa_test_run test_gc_evicts_after_10_run_absence                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_gc_keeps_within_10_run_window                   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bootstrap_gitignore_appends_to_existing         || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bootstrap_gitignore_matches_a_whole_line        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bootstrap_gitignore_creates_one_at_a_repository_root || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bootstrap_gitignore_never_writes_above_the_root || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bootstrap_gitignore_takes_a_git_file_as_a_root  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bootstrap_gitignore_refuses_a_relative_root     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bootstrap_gitignore_does_not_write_through_a_symlink || _csa_failed=$((_csa_failed + 1))

csa_test_run test_focused_scans_do_not_age_unscanned_aspects      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_full_scans_age_as_before                        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_stores_focus                       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_refuses_unknown_focus              || _csa_failed=$((_csa_failed + 1))
csa_test_run test_legacy_runs_read_as_full_runs                   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_unmapped_rule_id_ages_on_every_run              || _csa_failed=$((_csa_failed + 1))
csa_test_run test_gc_window_ignores_later_run_indices             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_writes_the_enabled_set_snapshot    || _csa_failed=$((_csa_failed + 1))
csa_test_run test_record_audit_refuses_when_the_enabled_set_is_unknown || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
