#!/usr/bin/env bash
# tests/test-skeleton.sh — unit tests for lib/skeleton.sh
# Covers (per SPEC §8.1/§8.2/§8.3, ~18 tests):
#   P. Preflight  (12) — name validation + writable parent + target absence + pair-with/wrapper modes
#   R. Root pair  (2) — standard + non-empty wrapper preservation
#   A. AI-only    (1) — wi_skeleton_create_root_ai_only
#   E. Existing   (3) — an existing root is refused, never logged as MKDIR
#   S. Seed       (4) — subdirs + .gitkeep + .gitignore content + idempotency

source "$(dirname "$0")/_helpers.sh"
source "$WI_LIB_DIR/_helpers.sh"
source "$WI_LIB_DIR/skeleton.sh"

# Shared sandbox — direct mktemp (avoids $() trap-loss).
_WI_TMP="$(mktemp -d "${TMPDIR:-/tmp}/wi-skeleton-test.XXXXXX")"
# Cleanup: restore any chmod -w dirs before removing, in case a test left one behind.
_wi_skeleton_cleanup() {
  # Walk and re-grant write on every dir to allow rm -rf to clean up.
  if [[ -d "$_WI_TMP" ]]; then
    chmod -R u+w "$_WI_TMP" 2>/dev/null || true
    rm -rf "$_WI_TMP"
  fi
}
trap _wi_skeleton_cleanup EXIT

# ---------------------------------------------------------------------------
# P. Preflight (10 tests)
# ---------------------------------------------------------------------------

test_P1_valid_name_writable_parent_no_existing() {
  local parent="$_WI_TMP/p1"
  mkdir -p "$parent"
  if ! wi_skeleton_preflight "$parent" "foo" 2>/dev/null; then
    echo "    expected success on valid input"
    return 1
  fi
}

test_P2_invalid_name_uppercase_symbols() {
  local parent="$_WI_TMP/p2"
  mkdir -p "$parent"
  local err rc
  err="$(wi_skeleton_preflight "$parent" "Foo!" 2>&1 >/dev/null)"
  rc=$?
  [[ $rc -ne 0 ]] || { echo "    expected non-zero exit for invalid name"; return 1; }
  assert_contains "invalid project name" "$err" || return 1
}

test_P3_invalid_name_with_space() {
  local parent="$_WI_TMP/p3"
  mkdir -p "$parent"
  if wi_skeleton_preflight "$parent" "foo bar" 2>/dev/null; then
    echo "    expected non-zero exit for name with space"
    return 1
  fi
}

test_P4_parent_not_writable() {
  local parent="$_WI_TMP/p4"
  mkdir -p "$parent"
  chmod -w "$parent"
  local err rc
  err="$(wi_skeleton_preflight "$parent" "foo" 2>&1 >/dev/null)"
  rc=$?
  chmod +w "$parent"  # restore so cleanup works
  [[ $rc -ne 0 ]] || { echo "    expected non-zero exit on unwritable parent"; return 1; }
  assert_contains "not writable" "$err" || return 1
}

test_P5_targets_already_exist_fresh_mode() {
  local parent="$_WI_TMP/p5"
  mkdir -p "$parent/foo-ai"
  if wi_skeleton_preflight "$parent" "foo" 2>/dev/null; then
    echo "    expected non-zero exit when AI target already exists"
    return 1
  fi
}

test_P6_pair_with_existing_git_repo_ok() {
  local parent="$_WI_TMP/p6"
  local canonical="$parent/foo"
  mkdir -p "$canonical"
  git -C "$canonical" init -q
  if ! wi_skeleton_preflight "$parent" "foo" --pair-with "$canonical" 2>/dev/null; then
    echo "    expected success on pair-with against existing git repo"
    return 1
  fi
}

test_P7_pair_with_missing_canonical() {
  local parent="$_WI_TMP/p7"
  mkdir -p "$parent"
  if wi_skeleton_preflight "$parent" "foo" --pair-with "$parent/nope" 2>/dev/null; then
    echo "    expected non-zero exit when --pair-with target missing"
    return 1
  fi
}

# #84: wi_git_is_linked_worktree must flag ONLY genuine linked worktrees — a standalone
# repo whose .git is a FILE (--separate-git-dir, or a submodule) keeps its own hooks dir
# and must NOT be over-matched (CodeRabbit). Discriminates via --git-dir vs --git-common-dir.
test_W1_is_linked_worktree_discriminates() {
  local root="$_WI_TMP/w1"; mkdir -p "$root"
  # main repo + a linked worktree
  git -C "$root" init -q main
  git -C "$root/main" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$root/main" worktree add -q "$root/wt" 2>/dev/null || { echo "    worktree add failed"; return 1; }
  # a standalone --separate-git-dir repo (its .git is a FILE, but it's not a worktree)
  mkdir -p "$root/sep"
  git init -q --separate-git-dir="$root/sep-gitdir" "$root/sep" 2>/dev/null
  # a plain non-repo dir
  mkdir -p "$root/plain"

  wi_git_is_linked_worktree "$root/wt"   || { echo "    linked worktree not detected"; return 1; }
  if wi_git_is_linked_worktree "$root/main"; then echo "    main worktree mis-flagged"; return 1; fi
  if wi_git_is_linked_worktree "$root/sep";  then echo "    separate-git-dir repo mis-flagged (over-match)"; return 1; fi
  if wi_git_is_linked_worktree "$root/plain"; then echo "    non-repo mis-flagged"; return 1; fi
  if wi_git_is_linked_worktree ""; then echo "    empty arg mis-flagged"; return 1; fi
}

# #71: a linked git worktree passes the bare git-repo check but has no own
# .git/hooks dir, so the trace-filter hook would silently fail — reject it.
test_P8_pair_with_linked_worktree_rejected() {
  local parent="$_WI_TMP/p8"
  local main="$parent/foo"
  mkdir -p "$main"
  git -C "$main" init -q
  git -C "$main" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  local wt="$parent/foo-wt"
  git -C "$main" worktree add -q "$wt" 2>/dev/null || { echo "    could not create test worktree"; return 1; }
  if wi_skeleton_preflight "$parent" "bar" --pair-with "$wt" 2>/dev/null; then
    echo "    expected non-zero exit when --pair-with is a linked worktree"
    return 1
  fi
}

# A non-empty wrapper is a valid parent. Only the two inner repo targets are
# collision-sensitive; unrelated source material at wrapper level is preserved.
test_P9_nonempty_wrapper_is_valid_when_inner_targets_absent() {
  local wrapper="$_WI_TMP/p9-wrapper"
  mkdir -p "$wrapper"
  printf 'source material\n' > "$wrapper/PROJECT_SPEC.md"

  if ! wi_skeleton_preflight "$wrapper" "foo" 2>/dev/null; then
    echo "    expected success for a non-empty wrapper with free inner targets"
    return 1
  fi
}

test_P10_nonempty_wrapper_rejects_inner_target_collision() {
  local wrapper="$_WI_TMP/p10-wrapper"
  mkdir -p "$wrapper/foo"
  printf 'source material\n' > "$wrapper/PROJECT_SPEC.md"

  if wi_skeleton_preflight "$wrapper" "foo" 2>/dev/null; then
    echo "    expected collision failure for wrapper/foo"
    return 1
  fi
}

test_P11_wrapper_rejects_regular_file_targets_before_writes() {
  local canonical_wrapper="$_WI_TMP/p11-canonical-file"
  mkdir -p "$canonical_wrapper"
  printf 'occupied\n' > "$canonical_wrapper/foo"

  if wi_skeleton_preflight "$canonical_wrapper" "foo" 2>/dev/null; then
    echo "    expected collision failure for regular file wrapper/foo"
    return 1
  fi
  [[ ! -e "$canonical_wrapper/foo-ai" ]] || {
    echo "    preflight created the AI sibling before rejecting canonical file"
    return 1
  }

  local ai_wrapper="$_WI_TMP/p11-ai-file"
  mkdir -p "$ai_wrapper"
  printf 'occupied\n' > "$ai_wrapper/foo-ai"

  if wi_skeleton_preflight "$ai_wrapper" "foo" 2>/dev/null; then
    echo "    expected collision failure for regular file wrapper/foo-ai"
    return 1
  fi
  [[ ! -e "$ai_wrapper/foo" ]] || {
    echo "    preflight created the canonical sibling before rejecting AI file"
    return 1
  }
}

test_P12_wrapper_rejects_dangling_symlink_targets() {
  local canonical_wrapper="$_WI_TMP/p12-canonical-link"
  mkdir -p "$canonical_wrapper"
  ln -s "$canonical_wrapper/missing" "$canonical_wrapper/foo"
  if wi_skeleton_preflight "$canonical_wrapper" "foo" 2>/dev/null; then
    echo "    expected collision failure for dangling canonical symlink"
    return 1
  fi

  local ai_wrapper="$_WI_TMP/p12-ai-link"
  mkdir -p "$ai_wrapper"
  ln -s "$ai_wrapper/missing" "$ai_wrapper/foo-ai"
  if wi_skeleton_preflight "$ai_wrapper" "foo" 2>/dev/null; then
    echo "    expected collision failure for dangling AI symlink"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# R. Root pair (2 tests)
# ---------------------------------------------------------------------------

test_R1_create_root_pair_creates_both_and_logs() {
  local parent="$_WI_TMP/r1"
  mkdir -p "$parent"
  wi_skeleton_create_root_pair "$parent" "foo" >/dev/null 2>&1 || {
    echo "    create_root_pair failed"
    return 1
  }
  assert_dir_exists "$parent/foo-ai" || return 1
  assert_dir_exists "$parent/foo"    || return 1
  local log="$parent/foo-ai/.workspace/init-log"
  assert_file_exists "$log" || return 1
  # Both roots should appear in log
  grep -qE "^MKDIR	${parent}/foo-ai\$"  "$log" || { echo "    ai_root not in log"; return 1; }
  grep -qE "^MKDIR	${parent}/foo\$"     "$log" || { echo "    canonical not in log"; return 1; }
}

test_R2_create_root_pair_preserves_wrapper_contents() {
  local wrapper="$_WI_TMP/r2-wrapper"
  mkdir -p "$wrapper"
  printf 'keep me byte-for-byte\n' > "$wrapper/PROJECT_SPEC.md"
  local before
  before="$(cksum "$wrapper/PROJECT_SPEC.md")"

  wi_skeleton_create_root_pair "$wrapper" "foo" >/dev/null 2>&1 || {
    echo "    create_root_pair failed inside non-empty wrapper"
    return 1
  }

  assert_dir_exists "$wrapper/foo-ai" || return 1
  assert_dir_exists "$wrapper/foo" || return 1
  assert_file_exists "$wrapper/PROJECT_SPEC.md" || return 1
  assert_eq "$before" "$(cksum "$wrapper/PROJECT_SPEC.md")" || {
    echo "    wrapper source material changed"
    return 1
  }
}

# ---------------------------------------------------------------------------
# A. AI-only (1 test)
# ---------------------------------------------------------------------------

test_A1_create_root_ai_only_creates_only_ai() {
  local parent="$_WI_TMP/a1"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1 || {
    echo "    create_root_ai_only failed"
    return 1
  }
  assert_dir_exists "$parent/foo-ai" || return 1
  if [[ -d "$parent/foo" ]]; then
    echo "    canonical dir unexpectedly created"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# E. Existing roots (3 tests) — PR #829: a root that already exists is refused,
# never logged as MKDIR (rollback answers MKDIR with `rm -rf`).
# ---------------------------------------------------------------------------

# _wi_existing_root_kept <root> <log> — the sentinel survives and no MKDIR line
# names <root>.
_wi_existing_root_kept() {
  local root="$1" log="$2"
  assert_file_exists "$root/KEEP" || return 1
  if [[ -f "$log" ]] && awk -F '\t' -v p="$root" '$1 == "MKDIR" && $2 == p { found = 1 } END { exit !found }' "$log"; then
    echo "    existing root logged as MKDIR: $root"; return 1
  fi
}

test_E1_create_root_ai_only_refuses_existing_ai_root() {
  local parent="$_WI_TMP/e1" rc=0
  mkdir -p "$parent/foo-ai/.workspace"
  printf 'user data\n' > "$parent/foo-ai/KEEP"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] || { echo "    create_root_ai_only accepted an existing AI root"; return 1; }
  _wi_existing_root_kept "$parent/foo-ai" "$parent/foo-ai/.workspace/init-log"
}

test_E2_create_root_pair_refuses_existing_ai_root() {
  local parent="$_WI_TMP/e2" rc=0
  mkdir -p "$parent/foo-ai/.workspace"
  printf 'user data\n' > "$parent/foo-ai/KEEP"
  wi_skeleton_create_root_pair "$parent" "foo" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] || { echo "    create_root_pair accepted an existing AI root"; return 1; }
  _wi_existing_root_kept "$parent/foo-ai" "$parent/foo-ai/.workspace/init-log"
}

test_E3_create_root_pair_refuses_existing_canonical_root() {
  local parent="$_WI_TMP/e3" rc=0
  mkdir -p "$parent/foo"
  printf 'user data\n' > "$parent/foo/KEEP"
  wi_skeleton_create_root_pair "$parent" "foo" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] || { echo "    create_root_pair accepted an existing canonical root"; return 1; }
  _wi_existing_root_kept "$parent/foo" "$parent/foo-ai/.workspace/init-log"
}

# ---------------------------------------------------------------------------
# S. Seed subdirs (4 tests)
# ---------------------------------------------------------------------------

test_S1_seed_subdirs_creates_all_with_gitkeep_and_gitignore() {
  local parent="$_WI_TMP/s1"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1
  local ai="$parent/foo-ai"
  wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1 || {
    echo "    seed_subdirs failed"
    return 1
  }
  local subdirs=(".workspace" ".claude" "docs" "docs/specs" ".superpowers" ".archive")
  local sd
  for sd in "${subdirs[@]}"; do
    assert_dir_exists "$ai/$sd"          || return 1
    assert_file_exists "$ai/$sd/.gitkeep" || return 1
  done
  assert_file_exists "$ai/.gitignore" || return 1
  # Log should contain WRITE_FILE for .gitignore
  local log="$ai/.workspace/init-log"
  grep -qE "^WRITE_FILE	${ai}/\.gitignore\$" "$log" || {
    echo "    .gitignore not logged"
    return 1
  }
}

test_S2_gitignore_preserves_compat_entries_drops_dead_onboarding_state() {
  local parent="$_WI_TMP/s2"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1
  local ai="$parent/foo-ai"
  wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1
  local body; body="$(cat "$ai/.gitignore")"
  # The dead onboarding-state entry is gone; the scaffold-dev handoff escape
  # valve stays as a compatibility entry, and the OS entries are kept.
  assert_not_contains ".claude/.onboarding-state.json" "$body" || return 1
  assert_contains ".workspace/handoffs/"               "$body" || return 1
  assert_contains ".DS_Store"                          "$body" || return 1
  assert_contains "*.swp"                              "$body" || return 1
}

# The inline .gitignore fallback (used only when the template file is absent)
# must produce a file byte-identical to the template it mirrors.
test_S5_gitignore_inline_fallback_matches_template() {
  local parent="$_WI_TMP/s5"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1
  local ai="$parent/foo-ai"
  ( export WI_TEMPLATES_DIR="$_WI_TMP/no-templates"
    wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1 ) || return 1
  cmp -s "$ai/.gitignore" "$WI_PLUGIN_ROOT/templates/gitignore.tmpl" || {
    echo '    inline fallback differs from gitignore.tmpl'; return 1; }
  local body; body="$(cat "$ai/.gitignore")"
  assert_contains ".workspace/handoffs/"               "$body" || return 1
  assert_not_contains ".claude/.onboarding-state.json" "$body" || return 1
}

test_S3_seed_subdirs_idempotent_no_double_log() {
  local parent="$_WI_TMP/s3"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1
  local ai="$parent/foo-ai"
  wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1
  local log="$ai/.workspace/init-log"
  local lines_first; lines_first="$(wc -l < "$log" | tr -d ' ')"
  # Second invocation should be a no-op (no duplicate log entries)
  wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1 || {
    echo "    second seed_subdirs invocation failed"
    return 1
  }
  local lines_second; lines_second="$(wc -l < "$log" | tr -d ' ')"
  assert_eq "$lines_first" "$lines_second" || {
    echo "    log grew on idempotent re-invocation: $lines_first -> $lines_second"
    return 1
  }
  # And no path appears twice in the log
  local dups; dups="$(sort "$log" | uniq -d)"
  if [[ -n "$dups" ]]; then
    echo "    duplicate log entries found:"
    echo "$dups"
    return 1
  fi
}

test_S4_seed_subdirs_logs_each_gitkeep() {
  local parent="$_WI_TMP/s4"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1
  local ai="$parent/foo-ai"
  wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1
  local log="$ai/.workspace/init-log"
  local subdirs=(".workspace" ".claude" "docs" "docs/specs" ".superpowers" ".archive")
  local sd
  for sd in "${subdirs[@]}"; do
    grep -qE "^WRITE_FILE	${ai}/${sd}/.gitkeep\$" "$log" || {
      echo "    .gitkeep for $sd not logged"
      return 1
    }
  done
}

# #834: literal paths must dedupe without merging neighboring paths or ops.
test_L1_log_once_literal_path() {
  local log="$_WI_TMP/literal-log" path="/x/a${log_char}b" i
  : > "$log"
  for i in 1 2 3; do
    _wi_skeleton_log_once "$log" OP "$path" || return 1
  done
  assert_eq "$(printf 'OP\t%s' "$path")" "$(cat "$log")"
}

test_L2_log_once_distinct_fields() {
  local log="$_WI_TMP/fields-log"
  printf 'OP\t/x/ai\nOP\t/x/aXb\n' > "$log"
  _wi_skeleton_log_once "$log" OP /x/ai-2 || return 1
  _wi_skeleton_log_once "$log" OP /x/a.b || return 1
  _wi_skeleton_log_once "$log" OTHER /x/ai || return 1
  _wi_skeleton_log_once "$log" OP '/x/ai|other' || return 1
  assert_eq "$(printf 'OP\t/x/ai\nOP\t/x/aXb\nOP\t/x/ai-2\nOP\t/x/a.b\nOTHER\t/x/ai\nOP\t/x/ai|other')" "$(cat "$log")" || return 1
  printf 'OP\t/x/ai-2\n' > "$log"
  _wi_skeleton_log_once "$log" OP /x/ai || return 1
  assert_eq "$(printf 'OP\t/x/ai-2\nOP\t/x/ai')" "$(cat "$log")"
}

test_L3_log_once_ignores_detail() {
  local log="$_WI_TMP/detail-log"
  printf 'OP\t/x/ai\tdetail\n' > "$log"
  _wi_skeleton_log_once "$log" OP /x/ai || return 1
  assert_eq "$(printf 'OP\t/x/ai\tdetail')" "$(cat "$log")"
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------

for log_char in '+' '?' '(' ')' '|' '{' '}' '\' '[' ']' '.' '()' '{2}'; do
  printf 'Literal path character: %s\n' "$log_char"
  wi_test_run test_L1_log_once_literal_path
done
wi_test_run test_L2_log_once_distinct_fields
wi_test_run test_L3_log_once_ignores_detail

wi_test_run test_P1_valid_name_writable_parent_no_existing
wi_test_run test_P2_invalid_name_uppercase_symbols
wi_test_run test_P3_invalid_name_with_space
wi_test_run test_P4_parent_not_writable
wi_test_run test_P5_targets_already_exist_fresh_mode
wi_test_run test_P6_pair_with_existing_git_repo_ok
wi_test_run test_P7_pair_with_missing_canonical
wi_test_run test_W1_is_linked_worktree_discriminates
wi_test_run test_P8_pair_with_linked_worktree_rejected
wi_test_run test_P9_nonempty_wrapper_is_valid_when_inner_targets_absent
wi_test_run test_P10_nonempty_wrapper_rejects_inner_target_collision
wi_test_run test_P11_wrapper_rejects_regular_file_targets_before_writes
wi_test_run test_P12_wrapper_rejects_dangling_symlink_targets

wi_test_run test_R1_create_root_pair_creates_both_and_logs
wi_test_run test_R2_create_root_pair_preserves_wrapper_contents

wi_test_run test_A1_create_root_ai_only_creates_only_ai

wi_test_run test_E1_create_root_ai_only_refuses_existing_ai_root
wi_test_run test_E2_create_root_pair_refuses_existing_ai_root
wi_test_run test_E3_create_root_pair_refuses_existing_canonical_root

wi_test_run test_S1_seed_subdirs_creates_all_with_gitkeep_and_gitignore
wi_test_run test_S2_gitignore_preserves_compat_entries_drops_dead_onboarding_state
wi_test_run test_S5_gitignore_inline_fallback_matches_template
wi_test_run test_S3_seed_subdirs_idempotent_no_double_log
wi_test_run test_S4_seed_subdirs_logs_each_gitkeep

wi_test_summary
