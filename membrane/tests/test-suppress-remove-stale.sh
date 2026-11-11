#!/usr/bin/env bash
# tests/test-suppress-remove-stale.sh — csa suppress_remove and csa suppress_stale,
# run through the bin/csa dispatcher (which sets -euo pipefail, as the skill does).
set -u
source "$(dirname "$0")/_helpers.sh"
CSA="$CSA_PLUGIN_ROOT/bin/csa"

_csa_failed=0
_CSA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/csa-sup-rm.XXXXXX")"
_n=0

# _mk_root: sets $root to a fresh project dir with .claude/audits/.
_mk_root() { _n=$((_n + 1)); root="$_CSA_TMP/t$_n"; mkdir -p "$root/.claude/audits"; }

# _write_sup <root> <uid>... : a suppressions.json with one entry per uid, distinct notes.
_write_sup() {
  local r="$1"; shift
  local u arr='[]'
  for u in "$@"; do
    arr="$(jq -c --arg u "$u" '. + [{finding_uid:$u,suppressed_by:"tester",suppressed_at:"2026-01-01T00:00:00Z",note:("note for " + $u)}]' <<<"$arr")"
  done
  jq -n --argjson a "$arr" '{schema_version:1,suppressions:$a}' > "$r/.claude/audits/suppressions.json"
}

_scan() { # <project> <focus> > raw jsonl
  HOME=/nonexistent "$CSA" rule_engine_scan_all "$1" "$2" 2>/dev/null
}

# ---- remove ----------------------------------------------------------------

test_remove_keeps_other_entries_byte_for_byte() {
  _mk_root
  _write_sup "$root" FUID-aaaaaaaa FUID-bbbbbbbb FUID-cccccccc
  local before_a before_c
  before_a="$(jq -c '.suppressions[0]' "$root/.claude/audits/suppressions.json")"
  before_c="$(jq -c '.suppressions[2]' "$root/.claude/audits/suppressions.json")"
  "$CSA" suppress_remove "$root" FUID-bbbbbbbb || { printf '    remove failed\n' >&2; return 1; }
  assert_eq "2" "$(jq '.suppressions | length' "$root/.claude/audits/suppressions.json")" "two entries remain" || return 1
  assert_eq "$before_a" "$(jq -c '.suppressions[0]' "$root/.claude/audits/suppressions.json")" "first entry untouched" || return 1
  assert_eq "$before_c" "$(jq -c '.suppressions[1]' "$root/.claude/audits/suppressions.json")" "last entry untouched" || return 1
  assert_eq "1" "$(jq '.schema_version' "$root/.claude/audits/suppressions.json")" "schema_version kept" || return 1
  # Adjacent control: the removed uid is the only one gone.
  assert_eq "0" "$(jq '[.suppressions[] | select(.finding_uid == "FUID-bbbbbbbb")] | length' "$root/.claude/audits/suppressions.json")" "removed uid is gone" || return 1
}

test_remove_absent_uid_rc1_file_untouched() {
  _mk_root
  _write_sup "$root" FUID-aaaaaaaa
  local f="$root/.claude/audits/suppressions.json"
  touch -t 202001010000 "$f"
  local m1; m1="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")"
  local sum1; sum1="$(cksum < "$f")"
  local rc=0; "$CSA" suppress_remove "$root" FUID-zzzzzzzz 2>/dev/null || rc=$?
  assert_eq "1" "$rc" "absent uid is rc 1" || return 1
  assert_eq "$m1" "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")" "mtime unchanged" || return 1
  assert_eq "$sum1" "$(cksum < "$f")" "content unchanged" || return 1
}

test_remove_malformed_file_rc2() {
  _mk_root
  printf '{ not json' > "$root/.claude/audits/suppressions.json"
  local rc=0 err; err="$("$CSA" suppress_remove "$root" FUID-aaaaaaaa 2>&1)" || rc=$?
  assert_eq "2" "$rc" "malformed file is rc 2" || return 1
  assert_contains "$err" "not a valid suppressions file" "message names why" || return 1
  assert_eq "{ not json" "$(cat "$root/.claude/audits/suppressions.json")" "malformed file left as it was" || return 1
}

test_remove_no_file_rc1_creates_nothing() {
  _mk_root
  local rc=0; "$CSA" suppress_remove "$root" FUID-aaaaaaaa 2>/dev/null || rc=$?
  assert_eq "1" "$rc" "no file is rc 1" || return 1
  [[ ! -e "$root/.claude/audits/suppressions.json" ]] || { printf '    remove created a file\n' >&2; return 1; }
}

# ---- stale -----------------------------------------------------------------

# _record_run <root> <findings-file> : records the findings as audit run 1 through the dispatcher,
# as step 9 does, then backdates every first_seen past the 60 s suppression window.
_record_run() {
  local r="$1" f="$_CSA_TMP/state-tmp$_n.json" st="$1/.claude/audits/state.json"
  [[ -f "$st" ]] || HOME=/nonexistent "$CSA" state_init "$r" >/dev/null
  HOME=/nonexistent "$CSA" state_record_audit "$r" 1 ".claude/audits/r.md" "$2" all >/dev/null \
    || { printf '    state_record_audit failed\n' >&2; return 1; }
  jq '.findings |= map_values(.first_seen = "2026-01-01T00:00:00Z")' "$st" > "$f" && mv "$f" "$st"
}

# Copies permissions-issue into $root and sets $live to one uid its full scan reports.
_perm_project() {
  _mk_root
  cp -R "$CSA_FIXTURES_DIR/issues/permissions-issue/." "$root/"
  mkdir -p "$root/.claude/audits"
  _scan "$root" all > "$_CSA_TMP/raw$_n.jsonl"
  live="$(jq -r 'select(.finding_uid != null) | .finding_uid' "$_CSA_TMP/raw$_n.jsonl" | head -1)"
  [[ -n "$live" ]] || { printf '    fixture scan has no finding\n' >&2; return 1; }
}

test_stale_lists_only_the_uid_the_scan_lacks() {
  local root live; _perm_project || return 1
  _write_sup "$root" "$live" FUID-deadbeef
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/raw$_n.jsonl" "$root" all)" || { printf '    stale failed\n' >&2; return 1; }
  assert_eq "FUID-deadbeef" "$(jq -r '.finding_uid' <<<"$out")" "the bogus uid is listed" || return 1
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c .)" "one line" || return 1
  # Control: the live suppression is not listed.
  [[ "$out" != *"$live"* ]] || { printf '    live uid %s listed as stale\n' "$live" >&2; return 1; }
}

test_stale_focused_scan_refuses() {
  local root live; _perm_project || return 1
  _write_sup "$root" "$live" FUID-deadbeef
  local rc=0 out
  out="$("$CSA" suppress_stale "$_CSA_TMP/raw$_n.jsonl" "$root" secrets 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || { printf '    focused scan did not refuse\n' >&2; return 1; }
  assert_contains "$out" "full scan" "message names why" || return 1
  [[ "$out" != *"FUID-deadbeef"* ]] || { printf '    refusal still listed uids\n' >&2; return 1; }
}

test_stale_scanner_finding_refuses() {
  local root live; _perm_project || return 1
  _write_sup "$root" "$live" FUID-deadbeef
  cp "$_CSA_TMP/raw$_n.jsonl" "$_CSA_TMP/partial$_n.jsonl"
  printf '%s\n' '{"rule_id":"SCANNER-003","severity":"medium","file":"x"}' >> "$_CSA_TMP/partial$_n.jsonl"
  local rc=0 out
  out="$("$CSA" suppress_stale "$_CSA_TMP/partial$_n.jsonl" "$root" all 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || { printf '    partial scan did not refuse\n' >&2; return 1; }
  assert_contains "$out" "SCANNER" "message names why" || return 1
  [[ "$out" != *"FUID-deadbeef"* ]] || { printf '    refusal still listed uids\n' >&2; return 1; }
}

test_stale_clean_scan_lists_all() {
  _mk_root
  cp -R "$CSA_FIXTURES_DIR/clean/empty-project/." "$root/"
  mkdir -p "$root/.claude/audits"
  _scan "$root" all > "$_CSA_TMP/raw$_n.jsonl"
  assert_eq "0" "$(jq -s '[.[] | select(.finding_uid != null)] | length' "$_CSA_TMP/raw$_n.jsonl")" "fixture scan is clean" || return 1
  _write_sup "$root" FUID-aaaaaaaa FUID-bbbbbbbb
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/raw$_n.jsonl" "$root" all)" || return 1
  assert_eq "2" "$(printf '%s\n' "$out" | grep -c .)" "both listed" || return 1
}

test_stale_no_file_lists_nothing() {
  _mk_root
  : > "$_CSA_TMP/empty$_n.jsonl"
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/empty$_n.jsonl" "$root" all)" || { printf '    stale failed with no file\n' >&2; return 1; }
  assert_eq "" "$out" "nothing listed" || return 1
  [[ ! -e "$root/.claude/audits/suppressions.json" ]] || { printf '    stale created a file\n' >&2; return 1; }
}

test_stale_lists_the_former_tamper_uids() {
  _mk_root
  : > "$_CSA_TMP/empty$_n.jsonl"
  _write_sup "$root" FUID-tamper01 FUID-tamper02 FUID-tamper03 FUID-bbbbbbbb
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/empty$_n.jsonl" "$root" all)" || return 1
  assert_eq "FUID-tamper01 FUID-tamper02 FUID-tamper03 FUID-bbbbbbbb" "$(jq -r '.finding_uid' <<<"$out" | paste -sd' ' -)" \
    "the tamper checks are gone, so their fixed uids are listed like any other" || return 1
}

# A suppression whose uid moves (the finding's file is renamed, so its path and uid change)
# is stale, and the same finding under its new uid reads NEW.
test_e2e_uid_move_old_stale_new_is_new() {
  local root live; _perm_project || return 1
  local old; old="$(jq -r 'select(.rule_id == "PERM-001") | .finding_uid' "$_CSA_TMP/raw$_n.jsonl")"
  [[ -n "$old" ]] || { printf '    no PERM-001 in fixture\n' >&2; return 1; }
  _record_run "$root" "$_CSA_TMP/raw$_n.jsonl" || return 1
  "$CSA" suppress_add "$root" "$old" "e2e" || { printf '    suppress_add failed\n' >&2; return 1; }
  mv "$root/.claude/settings.json" "$root/.claude/settings.local.json"
  _scan "$root" all > "$_CSA_TMP/rescan$_n.jsonl"
  local new; new="$(jq -r 'select(.rule_id == "PERM-001") | .finding_uid' "$_CSA_TMP/rescan$_n.jsonl")"
  [[ -n "$new" && "$new" != "$old" ]] || { printf '    rename did not move the uid; setup is vacuous\n' >&2; return 1; }
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/rescan$_n.jsonl" "$root" all)" || return 1
  assert_eq "$old" "$(jq -r '.finding_uid' <<<"$out")" "old uid is stale" || return 1
  # The moved finding is no longer hidden: the rescan still emits the new uid through the filter.
  "$CSA" suppress_filter "$_CSA_TMP/rescan$_n.jsonl" "$root" > "$_CSA_TMP/filtered$_n.jsonl" || return 1
  assert_eq "1" "$(jq -r --arg u "$new" 'select(.finding_uid == $u and .state != "SUPPRESSED") | .finding_uid' "$_CSA_TMP/filtered$_n.jsonl" | grep -c .)" "new uid passes the filter unmarked" || return 1
  # Control: before the move the same suppression does hide the old uid.
  "$CSA" suppress_filter "$_CSA_TMP/raw$_n.jsonl" "$root" > "$_CSA_TMP/filtered-old$_n.jsonl" || return 1
  assert_eq "SUPPRESSED" "$(jq -r --arg u "$old" 'select(.finding_uid == $u) | .state' "$_CSA_TMP/filtered-old$_n.jsonl" | sort -u)" "old uid is marked suppressed by its suppression" || return 1
}

# Every `csa <fn> ...` call SKILL.md documents, bare ones included, runs through the dispatcher
# with its placeholders filled, and does not abort on arity. The `csa <fn-suffix>` contract
# mention and `csa --list` name no function and are not matched.
test_documented_csa_calls_run_through_dispatcher() {
  _mk_root
  local skill="$CSA_PLUGIN_ROOT/skills/auditing-claude-configs/SKILL.md" calls call ran=0
  : > "$_CSA_TMP/empty$_n.jsonl"
  # The findings files hold one High finding, so a call that reads its path as the findings
  # themselves fails here instead of rendering nothing.
  local fx="$_CSA_TMP/one$_n.jsonl"
  printf '%s\n' '{"rule_id":"PERM-002","severity":"high","file":".claude/settings.json","line":3,"offset":0,"preview":"Bash(*)","finding_uid":"FUID-0a0b0c0d","state":"NEW","display_id":"SA-2026-01-01-01-001"}' > "$fx"
  calls="$(grep -oE '`csa [a-z_]+( [^`]*)?`' "$skill" | tr -d '`')"
  [[ -n "$calls" ]] || { printf '    SKILL.md documents no csa call with arguments\n' >&2; return 1; }
  while IFS= read -r call; do
    call="${call//\"\$PWD\"/\"$root\"}"
    call="${call//\"\$focus\"/all}"
    call="${call//\"<finding-id>\"/FUID-aaaaaaaa}"
    call="${call//\"<FUID>\"/FUID-aaaaaaaa}"
    call="${call//\"<id>\"/FUID-aaaaaaaa}"
    call="${call//\"<note>\"/note}"
    call="${call//<run-index>/1}"
    call="${call//<report-path>/$root/.claude/audits/r.md}"
    call="${call//<metadata-json>/\{\}}"
    call="${call//<findings>/$fx}"
    call="${call//<tagged>/$fx}"
    call="${call//<baseline>/$fx}"
    call="${call//\"<report-name>\"/2026-01-01-01}"
    call="${call//<raw-file>/$_CSA_TMP/empty$_n.jsonl}"
    call="${call//<hook-commands>/$_CSA_TMP/hooks$_n.jsonl}"
    [[ "$call" != *"<"* ]] || { printf '    unfilled placeholder in: %s\n' "$call" >&2; return 1; }
    local out rc=0
    out="$(cd "$root" && HOME=/nonexistent eval "\"$CSA\" ${call#csa }" 2>&1)" || rc=$?
    # A call that records a run must succeed and write it: the file argument it documents is read.
    if [[ "$call" == "csa state_record_audit "* ]]; then
      [[ "$rc" -eq 0 ]] || { printf '    documented call exits %s: %s -> %s\n' "$rc" "$call" "$out" >&2; return 1; }
      assert_eq "1" "$(jq '.audit_history | length' "$root/.claude/audits/state.json")" "documented state_record_audit wrote its run" || return 1
    fi
    # A call that reads a findings file must succeed, print no jq error, and use the finding it holds.
    case "$call" in
      "csa report_render_markdown "*|"csa report_render_chat "*|"csa report_assign_display_ids "*)
        [[ "$rc" -eq 0 ]] || { printf '    documented call exits %s: %s -> %s\n' "$rc" "$call" "$out" >&2; return 1; }
        [[ "$out" != *"jq:"* ]] || { printf '    documented call prints a jq error: %s -> %s\n' "$call" "$out" >&2; return 1; } ;;
    esac
    case "$call" in
      "csa report_render_chat "*) assert_contains "$out" "SA-2026-01-01-01-001 — PERM-002" "chat lists the file's finding" || return 1 ;;
      "csa report_render_markdown "*) assert_contains "$(cat "$root/.claude/audits/r.md")" "FUID-0a0b0c0d" "the report holds the file's finding" || return 1 ;;
      "csa report_assign_display_ids "*) assert_eq "SA-2026-01-01-01-001" "$(jq -r .display_id <<<"$out")" "the display id names the report" || return 1 ;;
    esac
    [[ "$out" != *"unbound variable"* && "$out" != *"Unknown function"* && "$out" != *"Usage:"* ]] \
      || { printf '    documented call aborts: %s -> %s\n' "$call" "$out" >&2; return 1; }
    ran=$((ran + 1))
  done <<<"$calls"
  [[ "$ran" -ge 12 ]] || { printf '    only %s documented calls ran\n' "$ran" >&2; return 1; }
}

# _documented_steps <root> <work-dir> <report-name> : SKILL.md audit steps 6 to 9, run in the order
# written: each call's output goes to the file its step names ("... a file, `<name>`"), and the next
# call reads it, so step 9 records whatever step 6's last call wrote into `<tagged>`. <work-dir>/raw-file
# must hold step 4's output. Sets $chat to step 8's chat summary. Returns non-zero on any call that does.
_documented_steps() {
  local root="$1" d="$2" name="$3"
  local skill="$CSA_PLUGIN_ROOT/skills/auditing-claude-configs/SKILL.md"
  local steps; steps="$(awk '/^## /{a = ($0 ~ /^## Audit mode/)} a && /^[6-9]\. /' "$skill")"
  assert_eq "6 7 8 9" "$(cut -d. -f1 <<<"$steps" | tr '\n' ' ' | sed 's/ $//')" "SKILL.md has steps 6 to 9" || return 1
  local re='`(csa [a-z_]+[^`]*)`(.*)' re_out='a file, `<([a-z-]+)>`' line rest call seg target ph rc ran=0 out
  chat=""
  while IFS= read -r line; do
    rest="$line"
    while [[ "$rest" =~ $re ]]; do
      call="${BASH_REMATCH[1]}"; rest="${BASH_REMATCH[2]}"
      # The text up to the next call says where this call's output goes, if anywhere.
      seg="${rest%%\`csa *}"; target=""
      [[ "$seg" =~ $re_out ]] && target="${BASH_REMATCH[1]}"
      call="${call//\"\$PWD\"/\"$root\"}"
      call="${call//\"\$focus\"/all}"
      call="${call//\"<report-name>\"/$name}"
      call="${call//<report-path>/$root/.claude/audits/$name.md}"
      call="${call//<metadata-json>/\{\}}"
      call="${call//<run-index>/1}"
      for ph in raw-file baseline tagged findings; do call="${call//<$ph>/$d/$ph}"; done
      call="${call//<hook-commands>/$d/hook-commands}"
      [[ "$call" != *"<"* ]] || { printf '    unfilled placeholder in: %s\n' "$call" >&2; return 1; }
      rc=0
      if [[ -n "$target" ]]; then
        (cd "$root" && HOME=/nonexistent eval "\"$CSA\" ${call#csa }" > "$d/$target" 2>"$d/err") || rc=$?
      else
        out="$(cd "$root" && HOME=/nonexistent eval "\"$CSA\" ${call#csa }" 2>"$d/err")" || rc=$?
        [[ "$call" != "csa report_render_chat "* ]] || chat="$out"
      fi
      [[ "$rc" -eq 0 ]] || { printf '    step call exits %s: %s -> %s\n' "$rc" "$call" "$(cat "$d/err")" >&2; return 1; }
      ran=$((ran + 1))
    done
  done <<<"$steps"
  [[ "$ran" -ge 6 ]] || { printf '    only %s step calls ran\n' "$ran" >&2; return 1; }
}

# _first_audit <git|nogit> : a project's first audit, as written, on a project with only a
# .claude/settings.json and no .claude/audits/ (with git: step 2's gitignore bootstrap first). The
# settings give a Critical (PERM-004) and one rule firing twice on the same text (two PERM-001 lines,
# `Bash(*)` twice, sharing a uid). Every step exits 0; the report and state.json exist and hold every finding, the
# Critical included; every display id this run printed for a registered finding resolves to it.
_first_audit() {
  _n=$((_n + 1)); local root="$_CSA_TMP/fresh$_n" d="$_CSA_TMP/flow$_n" chat
  mkdir -p "$root/.claude" "$d"
  printf '%s\n' '{"permissions":{"allow":["Bash(*)","Read(*)","Bash(*)"],"deny":[]}}' > "$root/.claude/settings.json"
  if [[ "$1" == git ]]; then
    git -C "$root" init -q || { printf '    git init failed\n' >&2; return 1; }
    (cd "$root" && HOME=/nonexistent "$CSA" state_bootstrap_gitignore "$root" >/dev/null) || { printf '    step 2 failed\n' >&2; return 1; }
    grep -qx '.claude/audits/' "$root/.gitignore" || { printf '    step 2 wrote no .gitignore entry\n' >&2; return 1; }
  fi
  [[ ! -e "$root/.claude/audits" ]] || { printf '    .claude/audits/ exists before the audit; setup is vacuous\n' >&2; return 1; }
  _scan "$root" all > "$d/raw-file" || { printf '    step 4 failed\n' >&2; return 1; }
  local name; name="$(date +%Y-%m-%d)-01"
  _documented_steps "$root" "$d" "$name" || return 1
  local st="$root/.claude/audits/state.json" rp="$root/.claude/audits/$name.md"
  [[ -f "$rp" && -f "$st" ]] || { printf '    report or state.json missing\n' >&2; return 1; }
  assert_eq PERM-004 "$(jq -r 'select(.severity == "critical") | .rule_id' "$d/raw-file")" "the scan has the Critical" || return 1
  local shared; shared="$(jq -r '.finding_uid // empty' "$d/raw-file" | sort | uniq -d)"
  [[ "$shared" == FUID-* && "$shared" != *$'\n'* ]] || { printf '    no single uid shared by two lines: %s\n' "$shared" >&2; return 1; }
  assert_eq 2 "$(jq -r --arg u "$shared" 'select(.finding_uid == $u) | .rule_id' "$d/raw-file" | grep -c PERM-001)" "two PERM-001 lines share $shared" || return 1
  assert_eq "$(jq -r '.finding_uid // empty' "$d/raw-file" | sort -u | tr '\n' ' ')" "$(jq -r '.findings | keys[]' "$st" | sort | tr '\n' ' ')" "state.json registers every uid of the scan" || return 1
  assert_eq critical "$(jq -r '.findings[] | select(.rule_id == "PERM-004") | .severity' "$st")" "state.json holds the Critical" || return 1
  assert_eq 1 "$(jq '.audit_history | length' "$st")" "the run is recorded" || return 1
  # A new state.json holds no tamper record and no applied-fix list: both features are gone.
  assert_eq '[false,false]' "$(jq -c '[has("self_integrity"), has("applied_fixes")]' "$st")" "no self_integrity, no applied_fixes" || return 1
  local did uid
  while IFS=$'\t' read -r did uid; do
    assert_contains "$(cat "$rp")" "$did" "the report prints $did" || return 1
  done < <(jq -r 'select(.finding_uid != null) | [.display_id, .finding_uid] | @tsv' "$d/findings")
  assert_eq 5 "$(jq -r 'select(.finding_uid != null) | .display_id' "$d/findings" | grep -cE "^SA-$name-[0-9]{3}\$")" "five display ids SA-<date>-<NN>-<NNN>" || return 1
  assert_contains "$chat" "(run #01)" "chat names the run" || return 1
  assert_contains "$chat" "### Critical (1)" "chat lists the Critical" || return 1
  assert_contains "$(cat "$rp")" "(Critical) — PERM-004" "the report lists the Critical" || return 1
  # --suppress takes the first of the two ids the shared uid was printed with.
  local first; first="$(jq -r --arg u "$shared" 'select(.finding_uid == $u) | .display_id' "$d/findings" | head -1)"
  uid="$shared"
  jq '.findings |= map_values(.first_seen = "2026-01-01T00:00:00Z")' "$st" > "$d/st" && mv "$d/st" "$st"
  local rc=0; (cd "$root" && "$CSA" suppress_add "$root" "$first" note >/dev/null 2>&1) || rc=$?
  assert_eq 0 "$rc" "--suppress takes $first" || return 1
  assert_eq "$uid" "$(jq -r '.suppressions[0].finding_uid' "$root/.claude/audits/suppressions.json")" "the suppression stores that finding's uid" || return 1
}

test_documented_audit_steps_on_a_first_audit() { _first_audit nogit; }
test_documented_audit_steps_on_a_first_audit_in_git() { _first_audit git; }

# ---- exit codes and exact matching -----------------------------------------

test_remove_empty_file_rc2() {
  _mk_root
  : > "$root/.claude/audits/suppressions.json"
  local rc=0; "$CSA" suppress_remove "$root" FUID-aaaaaaaa 2>/dev/null || rc=$?
  assert_eq "2" "$rc" "0-byte file is rc 2" || return 1
}

test_remove_object_without_suppressions_array_rc2() {
  _mk_root
  printf '{}' > "$root/.claude/audits/suppressions.json"
  local rc=0; "$CSA" suppress_remove "$root" FUID-aaaaaaaa 2>/dev/null || rc=$?
  assert_eq "2" "$rc" "{} is rc 2" || return 1
  assert_eq "{}" "$(cat "$root/.claude/audits/suppressions.json")" "file left as it was" || return 1
}

test_remove_matches_the_uid_exactly() {
  _mk_root
  _write_sup "$root" FUID-ab12 FUID-ab123 FUID-xab12
  "$CSA" suppress_remove "$root" FUID-ab12 || return 1
  assert_eq "FUID-ab123 FUID-xab12" "$(jq -r '[.suppressions[].finding_uid] | join(" ")' "$root/.claude/audits/suppressions.json")" "only the exact uid is gone" || return 1
}

test_stale_matches_the_uid_exactly() {
  _mk_root
  printf '%s\n' '{"rule_id":"PERM-001","finding_uid":"FUID-ab123"}' > "$_CSA_TMP/raw$_n.jsonl"
  _write_sup "$root" FUID-ab12 FUID-ab123
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/raw$_n.jsonl" "$root" all)" || return 1
  assert_eq "FUID-ab12" "$(jq -r '.finding_uid' <<<"$out")" "a longer live uid does not hide a shorter one" || return 1
}

test_stale_malformed_suppressions_rc2() {
  _mk_root
  : > "$_CSA_TMP/empty$_n.jsonl"
  local f="$root/.claude/audits/suppressions.json" rc out
  for body in '{}' '{"suppressions":[{"note":"no uid"}]}' '{ not json'; do
    printf '%s' "$body" > "$f"; rc=0
    out="$("$CSA" suppress_stale "$_CSA_TMP/empty$_n.jsonl" "$root" all 2>&1)" || rc=$?
    assert_eq "2" "$rc" "malformed suppressions ($body) is rc 2" || return 1
    assert_contains "$out" "not a valid suppressions file" "message names why ($body)" || return 1
  done
}

test_stale_missing_findings_file_rc4() {
  _mk_root
  _write_sup "$root" FUID-aaaaaaaa
  local rc=0 out; out="$("$CSA" suppress_stale "$_CSA_TMP/does-not-exist.jsonl" "$root" all 2>&1)" || rc=$?
  assert_eq "4" "$rc" "missing findings file is rc 4, not the focus refusal's 2" || return 1
  assert_contains "$out" "not findings JSONL" "message names why" || return 1
  printf 'csa: warning: some stderr text\n' > "$_CSA_TMP/notjsonl$_n.txt"
  rc=0; "$CSA" suppress_stale "$_CSA_TMP/notjsonl$_n.txt" "$root" all >/dev/null 2>&1 || rc=$?
  assert_eq "4" "$rc" "stderr text piped in as the findings file is rc 4" || return 1
}

test_stale_provenance_finding_refuses() {
  _mk_root
  _write_sup "$root" FUID-aaaaaaaa
  printf '%s\n' '{"rule_id":"PROVENANCE-002","severity":"high","file":"@plugin:x@y","finding_uid":"FUID-11111111"}' > "$_CSA_TMP/prov$_n.jsonl"
  local rc=0 out; out="$("$CSA" suppress_stale "$_CSA_TMP/prov$_n.jsonl" "$root" all 2>&1)" || rc=$?
  assert_eq "3" "$rc" "a PROVENANCE-002 scan is rc 3" || return 1
  assert_contains "$out" "PROVENANCE-002" "message names why" || return 1
  [[ "$out" != *"FUID-aaaaaaaa"* ]] || { printf '    refusal still listed uids\n' >&2; return 1; }
}

test_remove_write_failure_rc5() {
  _mk_root
  _write_sup "$root" FUID-aaaaaaaa FUID-bbbbbbbb
  local f="$root/.claude/audits/suppressions.json" before; before="$(cksum < "$f")"
  chmod a-w "$root/.claude/audits"
  # Not a failure of the code: a process that ignores directory modes (root) cannot reach this branch.
  if touch "$root/.claude/audits/.probe" 2>/dev/null; then
    rm -f "$root/.claude/audits/.probe"; chmod u+w "$root/.claude/audits"
    printf '    SKIP: directory modes are not enforced for this user (running as root?)\n' >&2
    return "$CSA_SKIP"
  fi
  local rc=0 err; err="$("$CSA" suppress_remove "$root" FUID-aaaaaaaa 2>&1)" || rc=$?
  chmod u+w "$root/.claude/audits"
  assert_eq "5" "$rc" "write failure is rc 5" || return 1
  assert_contains "$err" "could not write" "message names the write failure" || return 1
  assert_eq "1" "$(printf '%s\n' "$err" | grep -c .)" "the csa line is the only stderr line" || return 1
  assert_eq "$before" "$(cksum < "$f")" "file left as it was" || return 1
}

test_stale_emits_only_the_uid() {
  _mk_root
  : > "$_CSA_TMP/empty$_n.jsonl"
  _write_sup "$root" FUID-aaaaaaaa
  local out; out="$("$CSA" suppress_stale "$_CSA_TMP/empty$_n.jsonl" "$root" all)" || return 1
  assert_eq '{"finding_uid":"FUID-aaaaaaaa"}' "$out" "one object with the uid and nothing else" || return 1
}

# ---- suppress_add and suppress_filter through the dispatcher (0.7.0) --------------------------

# _seed_reg <root> <uid> <rule> <severity>: one registry entry in state.json.
_seed_reg() {
  local f="$1/.claude/audits/state.json"
  [[ -f "$f" ]] || printf '{"schema_version":2,"findings":{},"audit_history":[]}\n' > "$f"
  jq --arg u "$2" --arg r "$3" --arg s "$4" \
    '.findings[$u] = {rule_id:$r,severity:$s,file:"x.json",first_seen:"2026-01-01T00:00:00Z",last_seen:"2026-01-01T00:00:00Z",seen_in_runs:1,last_run_index:1}' \
    "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

test_suppress_add_malformed_registry_via_dispatcher() {
  _mk_root
  _seed_reg "$root" FUID-good0001 PERM-001 medium
  _seed_reg "$root" FUID-crit0001 HOOK-002 critical
  local f="$root/.claude/audits/state.json" ec
  jq '.findings["FUID-bad00001"] = "x" | .findings["FUID-crit0001"].rule_id = ["HOOK-002"]' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  ec=0; "$CSA" suppress_add "$root" FUID-bad00001 n >/dev/null 2>&1 || ec=$?
  assert_eq "1" "$ec" "a non-object registry entry is refused with exit 1" || return 1
  ec=0; "$CSA" suppress_add "$root" FUID-crit0001 n >/dev/null 2>&1 || ec=$?
  assert_eq "1" "$ec" "a Critical whose rule_id is not a string is refused with exit 1" || return 1
  ec=0; "$CSA" suppress_add "$root" FUID-good0001 n >/dev/null 2>&1 || ec=$?
  assert_eq "0" "$ec" "a healthy entry beside a malformed one is suppressed" || return 1
  ec=0; "$CSA" suppress_add "$root" FUID-deadbeef n >/dev/null 2>&1 || ec=$?
  assert_eq "3" "$ec" "an unknown id is exit 3 under the dispatcher" || return 1
}

test_empty_or_multi_document_suppressions_file() {
  _mk_root
  _seed_reg "$root" FUID-good0001 PERM-001 medium
  local sup="$root/.claude/audits/suppressions.json" tagged="$_CSA_TMP/tagged.$_n" ec
  printf '%s\n' '{"finding_uid":"FUID-crit0001","rule_id":"HOOK-002","severity":"critical","file":"h.sh"}' \
    '{"finding_uid":"FUID-good0001","rule_id":"PERM-001","severity":"medium","file":"x.json"}' > "$tagged"
  : > "$sup"
  assert_eq "2" "$("$CSA" suppress_filter "$tagged" "$root" | wc -l | tr -d ' ')" "an empty suppressions file hides nothing" || return 1
  "$CSA" suppress_add "$root" FUID-good0001 n || { printf '    add on an empty file failed\n' >&2; return 1; }
  assert_eq "FUID-good0001" "$(jq -r '.suppressions[0].finding_uid' "$sup")" "add on an empty file stores the entry" || return 1
  printf '%s\n%s\n' '{"schema_version":1,"suppressions":[]}' '{"schema_version":1,"suppressions":[]}' > "$sup"
  local before; before="$(cat "$sup")"
  ec=0; "$CSA" suppress_add "$root" FUID-good0001 n >/dev/null 2>&1 || ec=$?
  assert_eq "2" "$ec" "add on a two-document file is exit 2" || return 1
  assert_eq "$before" "$(cat "$sup")" "the two-document file is unchanged" || return 1
  assert_eq "FUID-crit0001" "$("$CSA" suppress_filter "$tagged" "$root" | jq -r 'select(.severity == "critical") | .finding_uid')" "a two-document file never hides the Critical" || return 1
}

test_unreadable_suppressions_file_hides_and_marks_nothing() {
  _mk_root
  local sup="$root/.claude/audits/suppressions.json" tagged="$_CSA_TMP/tagged.$_n" st="$root/.claude/audits/state.json" ec bad
  printf '%s\n' '{"finding_uid":"FUID-crit0001","rule_id":"HOOK-002","severity":"critical","file":"h.sh"}' \
    '{"finding_uid":"FUID-good0001","rule_id":"PERM-001","severity":"medium","file":"x.json"}' > "$tagged"
  for bad in 'not json' '{}' 'null' '[1]' '{"suppressions":5}' $'{"schema_version":1,"suppressions":[{"finding_uid":"FUID-good0001"}]}\n{"schema_version":1,"suppressions":[]}'; do
    printf '%s\n' "$bad" > "$sup"
    ec=0; "$CSA" suppress_filter "$tagged" "$root" > "$_CSA_TMP/out.$_n" 2>/dev/null || ec=$?
    assert_eq "0 2" "$ec $(wc -l < "$_CSA_TMP/out.$_n" | tr -d ' ')" "filter on '$bad' shows every line" || return 1
    rm -f "$st"
    ec=0; "$CSA" state_record_audit "$root" 1 ".claude/audits/r.md" "$tagged" >/dev/null 2>&1 || ec=$?
    assert_eq "0" "$ec" "record_audit on '$bad' records the run" || return 1
    assert_eq "false false 1" "$(jq -r '[.findings["FUID-crit0001"].suppressed, .findings["FUID-good0001"].suppressed, (.audit_history | length)] | join(" ")' "$st")" "record_audit on '$bad' marks nothing" || return 1
  done
  printf '{}\n' > "$sup"
  _seed_reg "$root" FUID-good0001 PERM-001 medium   # first seen long ago, past the race window
  ec=0; "$CSA" suppress_add "$root" FUID-good0001 n >/dev/null 2>&1 || ec=$?
  assert_eq "2" "$ec" "add on an object with no suppressions array is exit 2" || return 1
}

csa_test_run test_remove_keeps_other_entries_byte_for_byte  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_absent_uid_rc1_file_untouched      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_malformed_file_rc2                 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_no_file_rc1_creates_nothing        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_lists_only_the_uid_the_scan_lacks   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_focused_scan_refuses                || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_scanner_finding_refuses             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_clean_scan_lists_all                || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_no_file_lists_nothing               || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_lists_the_former_tamper_uids        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_uid_move_old_stale_new_is_new         || _csa_failed=$((_csa_failed + 1))
csa_test_run test_documented_csa_calls_run_through_dispatcher || _csa_failed=$((_csa_failed + 1))
csa_test_run test_documented_audit_steps_on_a_first_audit || _csa_failed=$((_csa_failed + 1))
csa_test_run test_documented_audit_steps_on_a_first_audit_in_git || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_empty_file_rc2                     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_object_without_suppressions_array_rc2 || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_matches_the_uid_exactly            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_matches_the_uid_exactly             || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_malformed_suppressions_rc2          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_missing_findings_file_rc4           || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_provenance_finding_refuses          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_remove_write_failure_rc5                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_stale_emits_only_the_uid                  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_suppress_add_malformed_registry_via_dispatcher || _csa_failed=$((_csa_failed + 1))
csa_test_run test_empty_or_multi_document_suppressions_file  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_unreadable_suppressions_file_hides_and_marks_nothing || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
