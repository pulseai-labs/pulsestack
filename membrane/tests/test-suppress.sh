#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"
source "$CSA_LIB_DIR/helpers.sh"
source "$CSA_LIB_DIR/state.sh"
source "$CSA_LIB_DIR/suppress.sh"

_csa_failed=0

_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"

# _seed <root> <uid> <rule_id> <severity> [<display_id>]
# A state.json whose registry holds one finding first seen long ago, as a recorded run leaves it.
_seed() {
  local root="$1" uid="$2" rule="$3" sev="$4" did="${5-SA-S-001}"
  mkdir -p "$root/.claude/audits"
  [[ -f "$(csa_state_path "$root")" ]] || csa_state_init "$root"
  local f; f="$(csa_state_path "$root")"
  jq --arg u "$uid" --arg r "$rule" --arg s "$sev" --arg d "$did" \
    '.findings[$u] = {rule_id:$r,severity:$s,file:"x.json",first_seen:"2026-01-01T00:00:00Z",last_seen:"2026-01-01T00:00:00Z",seen_in_runs:1,last_run_index:1,last_display_id:$d}' \
    "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

# ---------------------------------------------------------------------------
# 1. add basic — a recorded medium finding, three-argument call → list shows 1 with the note
# ---------------------------------------------------------------------------
test_add_basic() {
  local root="$_CSA_TMP/t01"
  mkdir -p "$root"
  _seed "$root" "FUID-001" "PERM-001" "medium"
  csa_suppress_init "$root"
  csa_suppress_add "$root" "FUID-001" "known false positive" || { printf '    add refused\n' >&2; return 1; }
  assert_eq "known false positive" "$(csa_suppress_list "$root" | jq -r '.note')" "note is the third argument" || return 1

  local count; count="$(csa_suppress_list "$root" | wc -l | tr -d ' ')"
  assert_eq "1" "$count" "list must show 1 suppression after add" || return 1

  local fuid; fuid="$(csa_suppress_list "$root" | jq -r '.finding_uid')"
  assert_eq "FUID-001" "$fuid" "suppressed finding_uid must match" || return 1
}

# ---------------------------------------------------------------------------
# 2. refuse Critical — rc 1 + stderr; list still 0, whatever severity the caller passes
# ---------------------------------------------------------------------------
test_refuse_critical() {
  local root="$_CSA_TMP/t02"
  mkdir -p "$root"
  _seed "$root" "FUID-crit" "SECRETS-001" "critical"
  csa_suppress_init "$root"

  local err_out ec=0
  err_out="$(csa_suppress_add "$root" "FUID-crit" "trying to suppress" 2>&1)" || ec=$?
  assert_eq "1" "$ec" "a Critical finding is refused with rc 1" || return 1
  assert_contains "$err_out" "critical" "stderr must mention critical" || return 1

  # The legacy four-argument call names a severity; it does not change the answer.
  ec=0; csa_suppress_add "$root" "FUID-crit" "medium" "claims it is medium" >/dev/null 2>&1 || ec=$?
  assert_eq "1" "$ec" "a Critical finding passed as medium is still refused" || return 1

  local count; count="$(csa_suppress_list "$root" | wc -l | tr -d ' ')"
  assert_eq "0" "$count" "list must remain empty after refused critical suppression" || return 1
}

# ---------------------------------------------------------------------------
# 2b. the severity is the higher of the registry's and the shipped rule's: a registry edited down
#     to medium for a Critical rule still refuses; a registry raised above its rule refuses too.
#     Controls: a High finding, and a medium one, are suppressed.
# ---------------------------------------------------------------------------
test_severity_is_registry_or_rule_whichever_is_higher() {
  local root="$_CSA_TMP/t02b"
  mkdir -p "$root"
  _seed "$root" "FUID-lowered" "SECRETS-001" "medium" "SA-S-001"
  _seed "$root" "FUID-raised" "PERM-001" "critical" "SA-S-002"
  _seed "$root" "FUID-nosev" "PERM-001" "" "SA-S-003"
  _seed "$root" "FUID-high" "SECRETS-003" "high" "SA-S-004"
  _seed "$root" "FUID-med" "PERM-001" "medium" "SA-S-005"
  local u ec
  for u in FUID-lowered FUID-raised FUID-nosev; do
    ec=0; csa_suppress_add "$root" "$u" "n" >/dev/null 2>&1 || ec=$?
    assert_eq "1" "$ec" "$u is refused" || return 1
  done
  for u in FUID-high FUID-med; do
    ec=0; csa_suppress_add "$root" "$u" "n" >/dev/null 2>&1 || ec=$?
    assert_eq "0" "$ec" "$u is suppressed" || return 1
  done
  assert_eq "FUID-high FUID-med" "$(csa_suppress_list "$root" | jq -r '.finding_uid' | tr '\n' ' ' | sed 's/ $//')" "only the two non-critical are listed" || return 1
}

# ---------------------------------------------------------------------------
# 2c. an id no recorded run produced is rc 3 and writes nothing; no state.json is rc 2;
#     a three-argument call with a note that looks like a severity is still a note
# ---------------------------------------------------------------------------
test_unknown_id_rc3_and_no_state_rc2() {
  local root="$_CSA_TMP/t02c" ec id
  mkdir -p "$root"
  ec=0; csa_suppress_add "$root" "FUID-aaaaaaaa" "n" >/dev/null 2>&1 || ec=$?
  assert_eq "2" "$ec" "no state.json is rc 2" || return 1
  [[ ! -e "$(csa_suppress_path "$root")" ]] || { printf '    rc 2 created suppressions.json\n' >&2; return 1; }
  _seed "$root" "FUID-real0001" "PERM-001" "medium"
  for id in "FUID-deadbeef" "not-a-uid at all" ""; do
    ec=0; csa_suppress_add "$root" "$id" "n" >/dev/null 2>&1 || ec=$?
    assert_eq "3" "$ec" "id '$id' is rc 3" || return 1
  done
  ec=0; csa_suppress_add "$root" "FUID-deadbeef" "medium" "n" >/dev/null 2>&1 || ec=$?
  assert_eq "3" "$ec" "an unknown id in the four-argument form is rc 3" || return 1
  [[ ! -e "$(csa_suppress_path "$root")" ]] || { printf '    rc 3 created suppressions.json\n' >&2; return 1; }
  # A registry entry whose severity cannot be read is refused, never stored.
  local st; st="$(csa_state_path "$root")"
  jq '.findings["FUID-bad00001"] = "x"' "$st" > "$st.tmp" && mv "$st.tmp" "$st"
  ec=0; csa_suppress_add "$root" "FUID-bad00001" "n" >/dev/null 2>&1 || ec=$?
  [[ "$ec" -ne 0 ]] || { printf '    a malformed registry entry was accepted\n' >&2; return 1; }
  [[ ! -e "$(csa_suppress_path "$root")" ]] || { printf '    a malformed entry created suppressions.json\n' >&2; return 1; }
  ec=0; csa_suppress_add "$root" "FUID-real0001" "critical" >/dev/null 2>&1 || ec=$?
  assert_eq "0" "$ec" "control: a recorded finding is suppressed" || return 1
  assert_eq "critical" "$(csa_suppress_list "$root" | jq -r '.note')" "the third argument is the note" || return 1
}

# ---------------------------------------------------------------------------
# 2d. the legacy four-argument form still works, and its severity argument is ignored
# ---------------------------------------------------------------------------
test_legacy_four_argument_form() {
  local root="$_CSA_TMP/t02d"
  mkdir -p "$root"
  _seed "$root" "FUID-legacy01" "PERM-001" "medium"
  csa_suppress_add "$root" "FUID-legacy01" "critical" "legacy call" || { printf '    legacy call refused\n' >&2; return 1; }
  assert_eq "legacy call" "$(csa_suppress_list "$root" | jq -r '.note')" "the fourth argument is the note" || return 1
}

# ---------------------------------------------------------------------------
# 2e. suppress_filter never marks a Critical finding suppressed, even one listed in suppressions.json;
#     the same file still marks a non-critical finding
# ---------------------------------------------------------------------------
test_filter_never_hides_critical() {
  local root="$_CSA_TMP/t02e"
  mkdir -p "$root/.claude/audits"
  csa_suppress_init "$root"
  jq '.suppressions = [{finding_uid:"FUID-crit0001",suppressed_by:"t",suppressed_at:"2026-01-01T00:00:00Z",note:"hand-written"},{finding_uid:"FUID-med00001",suppressed_by:"t",suppressed_at:"2026-01-01T00:00:00Z",note:"n"}]' \
    "$(csa_suppress_path "$root")" > "$_CSA_TMP/sup-e.json" && mv "$_CSA_TMP/sup-e.json" "$(csa_suppress_path "$root")"
  local f="$_CSA_TMP/findings-t02e.jsonl"
  printf '%s\n' \
    '{"finding_uid":"FUID-crit0001","rule_id":"SECRETS-001","severity":"critical","file":"a"}' \
    '{"finding_uid":"FUID-med00001","rule_id":"PERM-001","severity":"medium","file":"b"}' > "$f"
  local out; out="$(csa_suppress_filter "$f" "$root")"
  assert_eq "FUID-crit0001" "$(printf '%s\n' "$out" | jq -r 'select(.state != "SUPPRESSED") | .finding_uid')" "only the Critical line stays unmarked" || return 1
  assert_eq "FUID-med00001" "$(printf '%s\n' "$out" | jq -r 'select(.state == "SUPPRESSED") | .finding_uid')" "the listed Medium line is marked SUPPRESSED" || return 1
}

# ---------------------------------------------------------------------------
# 3. list emits JSONL — add 2, list returns 2 lines
# ---------------------------------------------------------------------------
test_list_emits_jsonl() {
  local root="$_CSA_TMP/t03"
  mkdir -p "$root"
  _seed "$root" "FUID-aaa" "PERM-001" "medium" "SA-S-001"
  _seed "$root" "FUID-bbb" "PERM-001" "low" "SA-S-002"
  csa_suppress_init "$root"
  csa_suppress_add "$root" "FUID-aaa" "note-a"
  csa_suppress_add "$root" "FUID-bbb" "note-b"

  local count; count="$(csa_suppress_list "$root" | wc -l | tr -d ' ')"
  assert_eq "2" "$count" "list must emit 2 lines for 2 suppressions" || return 1

  # Each line must be valid JSON.
  local line; while IFS= read -r line; do
    printf '%s' "$line" | jq '.' >/dev/null 2>&1 || {
      printf '    list line is not valid JSON: %s\n' "$line" >&2; return 1
    }
  done < <(csa_suppress_list "$root")
}

# ---------------------------------------------------------------------------
# 4. finding_uid match in filter — the suppressed finding is marked SUPPRESSED, the other is not
# ---------------------------------------------------------------------------
test_filter_excludes_suppressed() {
  local root="$_CSA_TMP/t04"
  mkdir -p "$root"
  _seed "$root" "FUID-abc" "PERM-001" "medium"
  csa_suppress_init "$root"
  csa_suppress_add "$root" "FUID-abc" "known"

  local findings_file="$_CSA_TMP/findings-t04.jsonl"
  printf '%s\n' \
    '{"finding_uid":"FUID-abc","rule_id":"PERM-001","severity":"medium","file":"f.json"}' \
    '{"finding_uid":"FUID-xyz","rule_id":"PERM-002","severity":"low","file":"g.json"}' \
    > "$findings_file"

  local out; out="$(csa_suppress_filter "$findings_file" "$root")"
  local line_count; line_count="$(printf '%s\n' "$out" | jq -s 'length')"
  assert_eq "2" "$line_count" "the filter emits every finding, so chat and the report can count what it hides" || return 1
  assert_eq "FUID-abc" "$(printf '%s\n' "$out" | jq -r 'select(.state == "SUPPRESSED") | .finding_uid')" "the listed finding is marked SUPPRESSED" || return 1
  assert_eq "FUID-xyz" "$(printf '%s\n' "$out" | jq -r 'select(.state != "SUPPRESSED") | .finding_uid')" "the other one is not" || return 1
}

# ---------------------------------------------------------------------------
# 5. dedup in suppressions — add same finding_uid twice; list shows only 1
# ---------------------------------------------------------------------------
test_dedup_same_uid() {
  local root="$_CSA_TMP/t05"
  mkdir -p "$root"
  _seed "$root" "FUID-dup" "PERM-001" "medium"
  csa_suppress_init "$root"
  csa_suppress_add "$root" "FUID-dup" "first add"
  csa_suppress_add "$root" "FUID-dup" "second add"  # should be skipped

  local count; count="$(csa_suppress_list "$root" | wc -l | tr -d ' ')"
  assert_eq "1" "$count" "duplicate add must not create second entry in suppressions" || return 1
}

# ---------------------------------------------------------------------------
# 6. race-window refusal (T1-F) — first_seen = NOW → refusal with "less than 60s"
# ---------------------------------------------------------------------------
test_race_window_refusal() {
  local root="$_CSA_TMP/t06"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  local fuid="FUID-race"
  local now_iso; now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Write state.json with finding first_seen = now.
  local state_file; state_file="$(csa_state_path "$root")"
  jq \
    --arg fuid "$fuid" \
    --arg now "$now_iso" \
    '.findings[$fuid] = {rule_id:"PERM-001",severity:"medium",file:"x.json",first_seen:$now,last_seen:$now,seen_in_runs:1,last_run_index:1,last_display_id:"SA-R-001"}' \
    "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"

  csa_suppress_init "$root"

  local err_out; err_out="$(csa_suppress_add "$root" "$fuid" "too soon" 2>&1)"
  local ec=$?

  [[ "$ec" -ne 0 ]] || { printf '    expected non-zero exit for race-window refusal\n' >&2; return 1; }
  assert_contains "$err_out" "less than 60s" "stderr must mention less than 60s" || return 1

  local count; count="$(csa_suppress_list "$root" | wc -l | tr -d ' ')"
  assert_eq "0" "$count" "list must be empty after race-window refusal" || return 1
}

# ---------------------------------------------------------------------------
# 7. display_id resolves to finding_uid
# ---------------------------------------------------------------------------
test_display_id_resolves_to_finding_uid() {
  local root="$_CSA_TMP/t07"
  mkdir -p "$root/.claude/audits"
  csa_state_init "$root"

  local fuid="FUID-display-resolved"
  local display_id="SA-X-001"
  # Use a first_seen far in the past to avoid race-window refusal. The finding was seen in recorded
  # run 1, the latest, since a display id resolves only in the latest run.
  local old_iso="2026-01-01T00:00:00Z"

  local state_file; state_file="$(csa_state_path "$root")"
  jq \
    --arg fuid "$fuid" \
    --arg did "$display_id" \
    --arg old "$old_iso" \
    '.findings[$fuid] = {rule_id:"PERM-003",severity:"medium",file:"y.json",first_seen:$old,last_seen:$old,seen_in_runs:1,last_run_index:1,last_display_id:$did}
     | .audit_history = [{run_index: 1, focus: "all"}]' \
    "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"

  csa_suppress_init "$root"

  # Call suppress_add with the display_id (not the FUID).
  csa_suppress_add "$root" "$display_id" "resolved via display_id"

  local stored_uid; stored_uid="$(csa_suppress_list "$root" | jq -r '.finding_uid')"
  assert_eq "$fuid" "$stored_uid" "finding_uid in suppressions must be the resolved FUID, not the display_id" || return 1
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
csa_test_run test_add_basic                            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_refuse_critical                      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_severity_is_registry_or_rule_whichever_is_higher || _csa_failed=$((_csa_failed + 1))
csa_test_run test_unknown_id_rc3_and_no_state_rc2      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_legacy_four_argument_form            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_filter_never_hides_critical          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_list_emits_jsonl                     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_filter_excludes_suppressed           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_dedup_same_uid                       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_race_window_refusal                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_display_id_resolves_to_finding_uid   || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
