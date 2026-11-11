#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/redact.sh"
source "$CSA_LIB_DIR/fingerprint.sh"
source "$CSA_LIB_DIR/report-render.sh"

_csa_failed=0

_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"

# ---------------------------------------------------------------------------
# 1. zero findings → renders empty summary cleanly
# ---------------------------------------------------------------------------
test_zero_findings_renders_cleanly() {
  local out; out="$(csa_report_render_chat "")"

  # Must contain the table header.
  assert_contains "$out" "| Severity |" "chat must include table header" || return 1

  # All counts must be 0.
  assert_contains "$out" "| Critical | 0 | 0 | 0 | 0 |" "Critical row must be all-zeros" || return 1
  assert_contains "$out" "| High | 0 | 0 | 0 | 0 |" "High row must be all-zeros" || return 1
  assert_contains "$out" "| Medium | 0 | 0 | 0 | 0 |" "Medium row must be all-zeros" || return 1
  assert_contains "$out" "| Low | 0 | 0 | 0 | 0 |" "Low row must be all-zeros" || return 1

  # Must NOT contain any finding detail lines (no "### " sections with finding entries).
  local finding_sections; finding_sections="$(printf '%s' "$out" | grep -c '^- SA-' || true)"
  assert_eq "0" "$finding_sections" "zero findings: no finding bullet lines expected" || return 1
}

# ---------------------------------------------------------------------------
# 2. mixed severities → counts correctly
# ---------------------------------------------------------------------------
test_mixed_severities_counts_correctly() {
  local findings_jsonl
  findings_jsonl="$(cat <<'EOF'
{"rule_id":"RULE-H1","file":"a.json","line":1,"offset":0,"preview":"x","severity":"high","finding_uid":"FUID-h1","state":"NEW"}
{"rule_id":"RULE-M1","file":"b.json","line":2,"offset":0,"preview":"y","severity":"medium","finding_uid":"FUID-m1","state":"NEW"}
{"rule_id":"RULE-M2","file":"c.json","line":3,"offset":0,"preview":"z","severity":"medium","finding_uid":"FUID-m2","state":"NEW"}
{"rule_id":"RULE-L1","file":"d.json","line":4,"offset":0,"preview":"w","severity":"low","finding_uid":"FUID-l1","state":"NEW"}
EOF
)"
  # Assign display IDs.
  local dated_findings; dated_findings="$(csa_report_assign_display_ids "$findings_jsonl" "2026-05-25")"

  local out; out="$(csa_report_render_chat "$dated_findings")"

  assert_contains "$out" "| High | 1 |" "High count must be 1" || return 1
  assert_contains "$out" "| Medium | 2 |" "Medium count must be 2" || return 1
  assert_contains "$out" "| Low | 1 |" "Low count must be 1" || return 1
}

# ---------------------------------------------------------------------------
# 3. suppressed hidden by default
# ---------------------------------------------------------------------------
test_suppressed_hidden_by_default() {
  local findings_jsonl
  findings_jsonl="$(cat <<'EOF'
{"rule_id":"RULE-M1","file":"a.json","line":1,"offset":0,"preview":"x","severity":"medium","finding_uid":"FUID-m1","state":"NEW"}
{"rule_id":"RULE-M2","file":"b.json","line":2,"offset":0,"preview":"y","severity":"medium","finding_uid":"FUID-m2","state":"SUPPRESSED"}
EOF
)"
  local dated_findings; dated_findings="$(csa_report_assign_display_ids "$findings_jsonl" "2026-05-25")"

  # Default: no verbose.
  unset CSA_VERBOSE
  local out; out="$(csa_report_render_chat "$dated_findings")"

  # NEW count = 1, Suppressed count = 1.
  assert_contains "$out" "| Medium | 1 | 0 | 1 | 1 |" "Medium row: 1 new, 0 persisted, 1 suppressed, 1 visible" || return 1

  # The suppressed finding's display_id (SA-2026-05-25-002) must NOT appear in bullet lines.
  local suppressed_in_bullets; suppressed_in_bullets="$(printf '%s' "$out" | grep '^- SA-2026-05-25-002' | wc -l | tr -d ' ')"
  assert_eq "0" "$suppressed_in_bullets" "suppressed finding display_id must not appear in bullet lines by default" || return 1
}

# ---------------------------------------------------------------------------
# 4. suppressed shown with verbose flag
# ---------------------------------------------------------------------------
test_suppressed_shown_verbose() {
  local findings_jsonl
  findings_jsonl="$(cat <<'EOF'
{"rule_id":"RULE-M1","file":"a.json","line":1,"offset":0,"preview":"x","severity":"medium","finding_uid":"FUID-m1","state":"NEW"}
{"rule_id":"RULE-M2","file":"b.json","line":2,"offset":0,"preview":"y","severity":"medium","finding_uid":"FUID-m2","state":"SUPPRESSED"}
EOF
)"
  local dated_findings; dated_findings="$(csa_report_assign_display_ids "$findings_jsonl" "2026-05-25")"

  # Verbose via env var.
  local out; out="$(CSA_VERBOSE=1 csa_report_render_chat "$dated_findings")"

  # The suppressed finding's display_id (SA-2026-05-25-002) MUST appear in bullet lines.
  local suppressed_in_bullets; suppressed_in_bullets="$(printf '%s' "$out" | grep 'SA-2026-05-25-002' | wc -l | tr -d ' ')"
  [[ "$suppressed_in_bullets" -ge 1 ]] || {
    printf '    suppressed finding SA-2026-05-25-002 not found in verbose output\n' >&2
    return 1
  }
}

# ---------------------------------------------------------------------------
# 5. markdown report includes acknowledgements footer
# ---------------------------------------------------------------------------
test_markdown_report_includes_acknowledgements() {
  local out_file; out_file="$_CSA_TMP/test-report.md"

  local findings_jsonl
  findings_jsonl="$(cat <<'EOF'
{"rule_id":"PERM-001","file":".claude/settings.json","line":14,"offset":21,"preview":"\"allow\": [\"Bash(*)\"]","severity":"medium","finding_uid":"FUID-abcd1234","state":"NEW"}
EOF
)"
  local dated_findings; dated_findings="$(csa_report_assign_display_ids "$findings_jsonl" "2026-05-25")"

  local metadata_json
  metadata_json="$(jq -n '{
    project: "pulsestack",
    date: "2026-05-25",
    run_of_day: 1,
    duration_seconds: 4.2,
    scope_summary: "project .claude/ + 2 enabled plugins"
  }')"

  csa_report_render_markdown "$dated_findings" "$metadata_json" "$out_file"

  [[ -f "$out_file" ]] || { printf '    markdown report file not created\n' >&2; return 1; }

  local content; content="$(cat "$out_file")"
  assert_contains "$content" "Acknowledgements" "markdown must include ## Acknowledgements section" || return 1
  assert_contains "$content" "AgentShield" "markdown must mention AgentShield" || return 1
}

# ---------------------------------------------------------------------------
# #1034: findings under an enabled plugin's fixtures/ or tests/ and under the project's .dagr/scratch/
# are one count line in chat; the report lists them at full severity, tagged with their group.
# ---------------------------------------------------------------------------
_P_ROOT="$_CSA_TMP/proj"
_PLUG="$_CSA_TMP/home/.claude/plugins/cache/mkt/plug/1.0.0"

# _group_findings <fixture-file> <scratch-file> <real-file> <own-tests-file> — one finding each
_group_findings() {
  jq -nc --arg a "$1" --arg b "$2" --arg c "$3" --arg d "$4" '
    {rule_id:"HOOK-001",file:$a,line:3,offset:0,preview:"p1",severity:"critical",finding_uid:"FUID-aaaaaaaa",state:"NEW"},
    {rule_id:"SECRETS-004",file:$b,line:5,offset:0,preview:"p2",severity:"medium",finding_uid:"FUID-bbbbbbbb",state:"NEW"},
    {rule_id:"PERM-001",file:$c,line:7,offset:0,preview:"p3",severity:"high",finding_uid:"FUID-cccccccc",state:"NEW"},
    (if $d == "" then empty else {rule_id:"CLAUDE-MD-001",file:$d,line:9,offset:0,preview:"p4",severity:"high",finding_uid:"FUID-dddddddd",state:"PERSISTED"} end)'
}

test_group_is_one_count_line_in_chat() {
  export CSA_PROJECT_ROOT="$_P_ROOT"
  local f; f="$(csa_report_assign_display_ids "$(_group_findings "$_PLUG/fixtures/x/CLAUDE.md" "$_P_ROOT/.dagr/scratch/a/n.md" "$_P_ROOT/.claude/settings.json" "")" "2026-11-05")"
  local out; out="$(csa_report_render_chat "$f" "/r.md")"
  assert_contains "$out" "2 findings in plugin fixtures/tests and agent scratch copies (1 critical, 0 high, 1 medium); listed in the report" "the count line" || return 1
  assert_contains "$out" "PERM-001 at $_P_ROOT/.claude/settings.json:7" "the real finding is listed" || return 1
  [[ "$out" != *"HOOK-001 at"* ]] || { printf '    a fixture finding is listed in chat\n' >&2; return 1; }
  [[ "$out" != *"SECRETS-004 at"* ]] || { printf '    a scratch finding is listed in chat\n' >&2; return 1; }
}

test_group_does_not_change_the_totals() {
  export CSA_PROJECT_ROOT="$_P_ROOT"
  local g u
  g="$(csa_report_assign_display_ids "$(_group_findings "$_PLUG/fixtures/x/CLAUDE.md" "$_P_ROOT/.dagr/scratch/a/n.md" "$_P_ROOT/.claude/settings.json" "")" "2026-11-05")"
  u="$(csa_report_assign_display_ids "$(_group_findings "$_P_ROOT/f/CLAUDE.md" "$_P_ROOT/s/n.md" "$_P_ROOT/.claude/settings.json" "")" "2026-11-05")"
  local og ou; og="$(csa_report_render_chat "$g" | sed -n '1,/^$/p;/^| /p' | sort -u)"; ou="$(csa_report_render_chat "$u" | sed -n '1,/^$/p;/^| /p' | sort -u)"
  assert_eq "$ou" "$og" "headline and severity table equal the same findings outside the group" || return 1
  assert_contains "$og" "— 3 findings" "headline counts all three" || return 1
  assert_contains "$og" "| Critical | 1 | 0 | 0 | 1 |" "critical row" || return 1
}

test_group_controls_own_tests_listed_and_empty_group_silent() {
  export CSA_PROJECT_ROOT="$_P_ROOT"
  # a project's own tests/ is not in the group
  local f; f="$(csa_report_assign_display_ids "$(_group_findings "$_PLUG/fixtures/x/CLAUDE.md" "$_P_ROOT/.dagr/scratch/a/n.md" "$_P_ROOT/.claude/settings.json" "$_P_ROOT/tests/x.md")" "2026-11-05")"
  local out; out="$(csa_report_render_chat "$f")"
  assert_contains "$out" "CLAUDE-MD-001 at $_P_ROOT/tests/x.md:9" "the project's own tests/ finding is listed" || return 1
  assert_contains "$out" "2 findings in plugin fixtures/tests" "and the group still counts two" || return 1
  # a plugin's tests/ directory is in the group too (the first finding above sits under fixtures/)
  out="$(csa_report_render_chat "$(csa_report_assign_display_ids "$(_group_findings "$_PLUG/skills/x/tests/t.sh" "$_P_ROOT/c" "$_P_ROOT/.claude/settings.json" "")" "2026-11-05")")"
  assert_contains "$out" "1 finding in plugin fixtures/tests and agent scratch copies (1 critical, 0 high, 0 medium)" "a plugin tests/ directory is grouped" || return 1
  # a plugin file that is not under fixtures/ or tests/ is listed too, and a plugin file named like the directory is not in it
  local g; g="$(csa_report_assign_display_ids "$(_group_findings "$_PLUG/hooks/h.sh" "$_PLUG/skills/tests" "$_P_ROOT/.claude/settings.json" "")" "2026-11-05")"
  out="$(csa_report_render_chat "$g")"
  [[ "$out" != *"findings in plugin fixtures/tests"* && "$out" != *"finding in plugin fixtures/tests"* ]] || { printf '    a count line for an empty group: %s\n' "$out" >&2; return 1; }
  assert_contains "$out" "HOOK-001 at $_PLUG/hooks/h.sh:3" "plugin hook listed" || return 1
  # no group, no line
  out="$(csa_report_render_chat "$(csa_report_assign_display_ids "$(_group_findings "$_P_ROOT/a" "$_P_ROOT/b" "$_P_ROOT/c" "")" "2026-11-05")")"
  [[ "$out" != *"listed in the report"* ]] || return 1
}

test_group_without_the_path_normalizer_lists_everything() {
  # With csa_normalize_path unavailable no plugin file is grouped (listed, never hidden), and nothing aborts under set -e.
  local f; f="$(csa_report_assign_display_ids "$(_group_findings "$_PLUG/fixtures/x/CLAUDE.md" "$_P_ROOT/.dagr/scratch/a/n.md" "$_P_ROOT/.claude/settings.json" "")" "2026-11-05")"
  local out rc=0
  out="$( set -e; export CSA_PROJECT_ROOT="$_P_ROOT"; unset -f csa_normalize_path; csa_report_render_chat "$f" 2>&1 )" || rc=$?
  assert_eq "0" "$rc" "no abort without the normalizer" || return 1
  [[ "$out" != *"command not found"* ]] || { printf '    the missing normalizer is called: %s\n' "$out" >&2; return 1; }
  assert_contains "$out" "HOOK-001 at $_PLUG/fixtures/x/CLAUDE.md:3" "the plugin fixture finding is listed" || return 1
  assert_contains "$out" "1 finding in plugin fixtures/tests and agent scratch copies (0 critical, 0 high, 1 medium)" "the scratch finding is still grouped" || return 1
}

test_group_scratch_anchor_is_the_project_root() {
  export CSA_PROJECT_ROOT="$_P_ROOT"
  local f out
  f="$(csa_report_assign_display_ids "$(jq -nc --arg a "$_P_ROOT/sub/.dagr/scratch/x.md" --arg b "/elsewhere/.dagr/scratch/x.md" '
    {rule_id:"X-1",file:$a,line:1,offset:0,preview:"p",severity:"high",finding_uid:"FUID-11111111",state:"NEW"},
    {rule_id:"X-2",file:$b,line:1,offset:0,preview:"p",severity:"high",finding_uid:"FUID-22222222",state:"NEW"}')" "2026-11-05")"
  out="$(csa_report_render_chat "$f")"
  assert_contains "$out" "X-1 at $_P_ROOT/sub/.dagr/scratch/x.md:1" "a nested .dagr/scratch is listed" || return 1
  assert_contains "$out" "X-2 at /elsewhere/.dagr/scratch/x.md:1" "another tree's .dagr/scratch is listed" || return 1
  [[ "$out" != *"in plugin fixtures/tests"* ]] || { printf '    a nested scratch is grouped\n' >&2; return 1; }
}

test_group_total_equals_the_sum_of_the_buckets() {
  export CSA_PROJECT_ROOT="$_P_ROOT"
  local f out
  f="$(csa_report_assign_display_ids "$(jq -nc --arg a "$_P_ROOT/.dagr/scratch/z.md" '
    {rule_id:"X-1",file:$a,line:1,offset:0,preview:"p",severity:"bogus",finding_uid:"FUID-11111111",state:"NEW"},
    {rule_id:"X-2",file:$a,line:2,offset:0,preview:"p",finding_uid:"FUID-22222222",state:"NEW"},
    {rule_id:"X-3",file:$a,line:3,offset:0,preview:"p",severity:"medium",finding_uid:"FUID-33333333",state:"NEW"}')" "2026-11-05")"
  out="$(csa_report_render_chat "$f")"
  assert_contains "$out" "3 findings in plugin fixtures/tests and agent scratch copies (0 critical, 0 high, 1 medium, 2 other); listed in the report" "unknown and missing severity are other" || return 1
  # control: no unknown severity, no other bucket
  f="$(csa_report_assign_display_ids "$(jq -nc --arg a "$_P_ROOT/.dagr/scratch/z.md" '{rule_id:"X-3",file:$a,line:3,offset:0,preview:"p",severity:"medium",finding_uid:"FUID-33333333",state:"NEW"}')" "2026-11-05")"
  out="$(csa_report_render_chat "$f")"
  [[ "$out" != *other* ]] || { printf '    an other bucket with nothing in it: %s\n' "$out" >&2; return 1; }
}

test_group_relative_scratch_path_is_grouped() {
  export CSA_PROJECT_ROOT="$_P_ROOT"
  local f; f="$(csa_report_assign_display_ids "$(jq -nc '{rule_id:"X-1",file:".dagr/scratch/a/n.md",line:1,offset:0,preview:"p",severity:"high",finding_uid:"FUID-99999999",state:"NEW"}')" "2026-11-05")"
  assert_contains "$(csa_report_render_chat "$f")" "1 finding in plugin fixtures/tests and agent scratch copies (0 critical, 1 high, 0 medium)" "relative scratch path" || return 1
}

test_group_line_prints_for_info_only_and_singular() {
  export CSA_PROJECT_ROOT="$_P_ROOT"
  local f; f="$(csa_report_assign_display_ids "$(jq -nc --arg a "$_P_ROOT/.dagr/scratch/z.md" '{rule_id:"HOOK-006",file:$a,line:0,offset:0,preview:"p",severity:"info",finding_uid:"FUID-eeeeeeee",state:"NEW"}')" "2026-11-05")"
  local out; out="$(csa_report_render_chat "$f")"
  assert_contains "$out" "1 finding in plugin fixtures/tests and agent scratch copies (0 critical, 0 high, 0 medium, 1 info); listed in the report" "info-only group" || return 1
  f="$(csa_report_assign_display_ids "$(jq -nc --arg a "$_P_ROOT/.dagr/scratch/z.md" '{rule_id:"X-1",file:$a,line:1,offset:0,preview:"p",severity:"low",finding_uid:"FUID-ffffffff",state:"NEW"},{rule_id:"HOOK-006",file:$a,line:0,offset:0,preview:"p",severity:"info",finding_uid:"FUID-eeeeeeee",state:"NEW"}')" "2026-11-05")"
  out="$(csa_report_render_chat "$f")"
  assert_contains "$out" "2 findings in plugin fixtures/tests and agent scratch copies (0 critical, 0 high, 0 medium, 1 low, 1 info); listed in the report" "low and info" || return 1
}

test_group_suppressed_is_not_counted_and_verbose_lists_all() {
  export CSA_PROJECT_ROOT="$_P_ROOT"
  local f; f="$(csa_report_assign_display_ids "$(_group_findings "$_PLUG/fixtures/x/CLAUDE.md" "$_P_ROOT/.dagr/scratch/a/n.md" "$_P_ROOT/.claude/settings.json" "" | jq -c 'if .rule_id == "SECRETS-004" then .state = "SUPPRESSED" else . end')" "2026-11-05")"
  local out; out="$(csa_report_render_chat "$f")"
  assert_contains "$out" "1 finding in plugin fixtures/tests and agent scratch copies (1 critical, 0 high, 0 medium)" "a suppressed group finding is not counted" || return 1
  out="$(csa_report_render_chat "$f" "" true)"
  assert_contains "$out" "HOOK-001 at $_PLUG/fixtures/x/CLAUDE.md:3" "verbose lists the group finding" || return 1
  [[ "$out" != *"listed in the report"* ]] || { printf '    verbose prints the count line\n' >&2; return 1; }
}

test_group_markdown_lists_all_at_full_severity_tagged() {
  export CSA_PROJECT_ROOT="$_P_ROOT"
  local f; f="$(csa_report_assign_display_ids "$(_group_findings "$_PLUG/fixtures/x/CLAUDE.md" "$_P_ROOT/.dagr/scratch/a/n.md" "$_P_ROOT/.claude/settings.json" "")" "2026-11-05")"
  local out="$_CSA_TMP/group-report.md"
  csa_report_render_markdown "$f" '{"project":"p","date":"2026-11-05","run_of_day":1,"duration_seconds":1,"scope_summary":"s"}' "$out"
  local c; c="$(cat "$out")"
  assert_contains "$c" "(Critical) — HOOK-001" "the fixture finding keeps its severity" || return 1
  assert_contains "$c" "(Medium) — SECRETS-004" "the scratch finding keeps its severity" || return 1
  assert_contains "$c" "(High) — PERM-001" "the real finding" || return 1
  assert_eq "2" "$(grep -c '^\*\*Group:\*\*' "$out")" "two findings tagged" || return 1
  assert_contains "$c" "**Group:** plugin fixtures/tests" "fixture tag" || return 1
  assert_contains "$c" "**Group:** agent scratch" "scratch tag" || return 1
  assert_contains "$c" "| Critical | 1 | 0 | 0 | 1 |" "report table totals" || return 1
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
csa_test_run test_zero_findings_renders_cleanly        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_mixed_severities_counts_correctly    || _csa_failed=$((_csa_failed + 1))
csa_test_run test_suppressed_hidden_by_default         || _csa_failed=$((_csa_failed + 1))
csa_test_run test_suppressed_shown_verbose             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_markdown_report_includes_acknowledgements || _csa_failed=$((_csa_failed + 1))

csa_test_run test_group_is_one_count_line_in_chat      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_group_does_not_change_the_totals     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_group_controls_own_tests_listed_and_empty_group_silent || _csa_failed=$((_csa_failed + 1))
csa_test_run test_group_without_the_path_normalizer_lists_everything || _csa_failed=$((_csa_failed + 1))
csa_test_run test_group_scratch_anchor_is_the_project_root || _csa_failed=$((_csa_failed + 1))
csa_test_run test_group_total_equals_the_sum_of_the_buckets || _csa_failed=$((_csa_failed + 1))
csa_test_run test_group_relative_scratch_path_is_grouped || _csa_failed=$((_csa_failed + 1))
csa_test_run test_group_line_prints_for_info_only_and_singular || _csa_failed=$((_csa_failed + 1))
csa_test_run test_group_suppressed_is_not_counted_and_verbose_lists_all || _csa_failed=$((_csa_failed + 1))
csa_test_run test_group_markdown_lists_all_at_full_severity_tagged || _csa_failed=$((_csa_failed + 1))
[[ "$_csa_failed" -eq 0 ]] || exit 1
