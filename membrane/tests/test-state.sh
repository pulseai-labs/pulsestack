#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/state.sh"
source "$CSA_LIB_DIR/baseline.sh"

_csa_failed=0

# Shared sandbox — create once for the whole test file.
_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"
trap 'rm -rf "$_CSA_TMP"' EXIT
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
  printf '{ not json' > "$root/.claude/audits/suppressions.json"
  csa_state_record_audit "$root" 3 ".claude/audits/m2.md" "$findings" || { printf '    refused on a bad suppressions file\n' >&2; return 1; }
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
# 5. record_applied_fix appends to applied_fixes
# ---------------------------------------------------------------------------
test_record_applied_fix_appends() {
  local root="$_CSA_TMP/t05"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  csa_state_record_applied_fix "$root" "FUID-abcd1234" "SA-2026-05-25-01-001" "PERM-003" "claude-code" "Narrowed allow list"

  local state_file; state_file="$(csa_state_path "$root")"
  local len; len="$(jq '.applied_fixes | length' "$state_file")"
  assert_eq "1" "$len" "applied_fixes length must be 1" || return 1

  local stored_fuid; stored_fuid="$(jq -r '.applied_fixes[0].finding_uid' "$state_file")"
  assert_eq "FUID-abcd1234" "$stored_fuid" "applied_fixes[0].finding_uid must match" || return 1
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
# 8. First-run tamper check is silent (no state.json)
# ---------------------------------------------------------------------------
test_tamper_check_silent_on_first_run() {
  local root="$_CSA_TMP/t08"
  mkdir -p "$root"
  # No state.json exists.
  local out; out="$(csa_state_check_tamper "$root" 2>&1)"
  assert_eq "" "$out" "tamper check must produce no output on first run" || return 1
}

# ---------------------------------------------------------------------------
# 9. TAMPER-001 fires on state.json mtime drift
# ---------------------------------------------------------------------------
test_tamper_001_fires_on_state_mtime_drift() {
  local root="$_CSA_TMP/t09"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  # Record a real mtime into self_integrity.
  csa_state_update_self_integrity "$root"

  local state_file; state_file="$(csa_state_path "$root")"

  # Change mtime to something in the distant past to force drift.
  touch -m -t 200001010000 "$state_file"

  local out; out="$(csa_state_check_tamper "$root" 2>&1)"
  assert_contains "$out" "TAMPER-001" "TAMPER-001 must fire when state.json mtime drifts" || return 1
}

# ---------------------------------------------------------------------------
# 10. TAMPER-002 fires on suppressions.json mtime drift
# ---------------------------------------------------------------------------
test_tamper_002_fires_on_suppressions_mtime_drift() {
  local root="$_CSA_TMP/t10"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  # Create an empty suppressions.json so update_self_integrity records its mtime.
  local suppressions_file; suppressions_file="$(csa_suppressions_path "$root")"
  printf '{}' > "$suppressions_file"

  csa_state_update_self_integrity "$root"

  # Now change suppression file mtime to something old.
  touch -m -t 200001010000 "$suppressions_file"

  local out; out="$(csa_state_check_tamper "$root" 2>&1)"
  assert_contains "$out" "TAMPER-002" "TAMPER-002 must fire when suppressions.json mtime drifts" || return 1
}

# ---------------------------------------------------------------------------
# 11. bootstrap_gitignore appends entry on existing .gitignore
# ---------------------------------------------------------------------------
test_bootstrap_gitignore_appends_to_existing() {
  local root="$_CSA_TMP/t11"
  mkdir -p "$root"

  # Create a .gitignore that does NOT contain .claude/audits/.
  printf 'node_modules/\n' > "$root/.gitignore"

  csa_state_bootstrap_gitignore "$root"

  local content; content="$(cat "$root/.gitignore")"
  assert_contains "$content" ".claude/audits/" "bootstrap must append .claude/audits/ to existing .gitignore" || return 1
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
csa_test_run test_record_applied_fix_appends                      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_gc_evicts_after_10_run_absence                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_gc_keeps_within_10_run_window                   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tamper_check_silent_on_first_run                || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tamper_001_fires_on_state_mtime_drift           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tamper_002_fires_on_suppressions_mtime_drift    || _csa_failed=$((_csa_failed + 1))
csa_test_run test_bootstrap_gitignore_appends_to_existing         || _csa_failed=$((_csa_failed + 1))

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
