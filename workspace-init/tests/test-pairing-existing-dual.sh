#!/usr/bin/env bash
# tests/test-pairing-existing-dual.sh — end-to-end integration test for
# PAIRING-EXISTING-DUAL (Scenario C, issue #9) mode.
#
# Scenario C: BOTH repos already exist and are populated — an AI workspace that
# grew its memory-bank/specs organically, alongside an existing canonical. The
# flow writes ONLY a manifest + installs the trace-filter hook(s); it never
# creates, seeds, or stubs the AI workspace (its content must be preserved).
#
# Drives the pipeline directly by calling the wi_* lib functions in order.
#
# Covered (~19 tests):
#   Preflight      (5) : happy, empty-AI fail, missing-AI fail, canonical-not-git
#                        fail, self-pairing fail
#   Happy path     (2) : pairing succeeds, AI content preserved (no stub clobber)
#   Manifest body  (3) : ai_workspace.name (basename, NOT name-ai), canonical.root,
#                        default_branch
#   Hooks          (2) : both repos have the baked-path hook; non-git AI skips AI hook
#   Canonical safe (2) : canonical working tree unchanged, git_remote null+url

source "$(dirname "$0")/_helpers.sh"
source "$WI_LIB_DIR/_helpers.sh"
source "$WI_LIB_DIR/skeleton.sh"
source "$WI_LIB_DIR/manifest.sh"
source "$WI_LIB_DIR/git-init.sh"
source "$WI_LIB_DIR/trace-filter.sh"

_WI_TMP="$(mktemp -d "${TMPDIR:-/tmp}/wi-existing-dual.XXXXXX")"
_wi_ed_cleanup() {
  if [[ -d "$_WI_TMP" ]]; then
    chmod -R u+rwx "$_WI_TMP" 2>/dev/null || true
    rm -rf "$_WI_TMP"
  fi
}
trap _wi_ed_cleanup EXIT

# ---------------------------------------------------------------------------
# Helper: existing canonical git repo with content + initial commit.
# ---------------------------------------------------------------------------
_make_existing_canonical() {
  local d="$1"; local name="$2"
  local canonical="$d/$name"
  mkdir -p "$canonical/src" "$canonical/docs"
  echo 'production code' > "$canonical/src/main.txt"
  echo '# Docs' > "$canonical/docs/README.md"
  git -C "$canonical" init -q
  git -C "$canonical" symbolic-ref HEAD refs/heads/main
  git -C "$canonical" -c user.email=t@t -c user.name=t add .
  git -C "$canonical" -c user.email=t@t -c user.name=t commit -q -m "initial canonical commit"
  echo "$canonical"
}

# ---------------------------------------------------------------------------
# Helper: an ALREADY-POPULATED AI workspace (memory-bank + MASTER-SPEC + CLAUDE.md
# + specs), grown organically. `as_git` controls whether it's also a git repo.
# Echoes the absolute AI-workspace path.
# ---------------------------------------------------------------------------
_make_existing_ai_workspace() {
  local d="$1"; local name="$2"; local as_git="${3:-git}"
  local ai="$d/$name"
  mkdir -p "$ai/.claude/memory-bank" "$ai/docs/specs"
  printf 'USER-AUTHORED CLAUDE.md — do not clobber\n' > "$ai/CLAUDE.md"
  printf '# Master Spec\nexisting content\n'          > "$ai/docs/MASTER-SPEC.md"
  printf '# 00 project brief\n'                        > "$ai/.claude/memory-bank/00-project-brief.md"
  printf '# 05 active context\n'                       > "$ai/.claude/memory-bank/05-active-context.md"
  printf '# VS-1.1.1 spec\n'                           > "$ai/docs/specs/VS-1.1.1-demo.md"
  if [[ "$as_git" == "git" ]]; then
    git -C "$ai" init -q
    git -C "$ai" symbolic-ref HEAD refs/heads/main
    git -C "$ai" -c user.email=t@t -c user.name=t add .
    git -C "$ai" -c user.email=t@t -c user.name=t commit -q -m "existing ai workspace"
  fi
  echo "$ai"
}

# ---------------------------------------------------------------------------
# Helper: drive the Scenario-C pairing pipeline (what the SKILL.md performs).
# Canonical hook always; AI hook only when the AI workspace is itself a git repo.
# ---------------------------------------------------------------------------
_run_existing_dual_pairing() {
  local ai_root="$1"; local canonical="$2"; local project_type="${3:-personal}"

  wi_skeleton_preflight_existing_dual "$ai_root" "$canonical" || return 1

  local default_branch
  default_branch="$(wi_git_detect_default_branch "$canonical" </dev/null)"
  [[ -z "$default_branch" ]] && default_branch="main"

  # Mirror SKILL.md §6.1: detect whether the AI workspace is an installable own
  # git repo root, record it in the manifest, and reuse it for the hook decision.
  local ai_git_tracked=false
  if wi_trace_filter_is_installable_repo_root "$ai_root"; then
    ai_git_tracked=true
  fi

  local detected_remote
  detected_remote="$(wi_git_detect_remote "$canonical")"
  if [[ -n "$detected_remote" ]]; then
    wi_manifest_write "$ai_root" "$canonical" "$project_type" \
      --canonical-git-remote "$detected_remote" --default-branch "$default_branch" \
      --ai-git-tracked "$ai_git_tracked" || return 1
  else
    wi_manifest_write "$ai_root" "$canonical" "$project_type" \
      --default-branch "$default_branch" \
      --ai-git-tracked "$ai_git_tracked" || return 1
  fi

  wi_trace_filter_install "$ai_root" "$canonical" || return 1
  if [[ "$ai_git_tracked" == true ]]; then
    wi_trace_filter_install "$ai_root" "$ai_root" || return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Preflight — 5 tests
# ---------------------------------------------------------------------------

test_C_preflight_happy() {
  local d="$_WI_TMP/p0"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws")"
  wi_skeleton_preflight_existing_dual "$ai" "$canonical" || { echo "    valid Scenario C preflight failed"; return 1; }
}

test_C_preflight_empty_ai_fails() {
  local d="$_WI_TMP/p1"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai="$d/empty-ws"; mkdir -p "$ai"
  local rc; ( wi_skeleton_preflight_existing_dual "$ai" "$canonical" 2>/dev/null ); rc=$?
  [[ $rc -ne 0 ]] || { echo "    empty AI workspace should fail preflight"; return 1; }
}

test_C_preflight_missing_ai_fails() {
  local d="$_WI_TMP/p2"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local rc; ( wi_skeleton_preflight_existing_dual "$d/nope" "$canonical" 2>/dev/null ); rc=$?
  [[ $rc -ne 0 ]] || { echo "    missing AI workspace should fail preflight"; return 1; }
}

test_C_preflight_canonical_not_git_fails() {
  local d="$_WI_TMP/p3"; mkdir -p "$d"
  local ai; ai="$(_make_existing_ai_workspace "$d" "proj-ws")"
  local not_git="$d/plain"; mkdir -p "$not_git"; echo x > "$not_git/f.txt"
  local rc; ( wi_skeleton_preflight_existing_dual "$ai" "$not_git" 2>/dev/null ); rc=$?
  [[ $rc -ne 0 ]] || { echo "    non-git canonical should fail preflight"; return 1; }
}

test_C_preflight_self_pairing_fails() {
  local d="$_WI_TMP/p4"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local rc; ( wi_skeleton_preflight_existing_dual "$canonical" "$canonical" 2>/dev/null ); rc=$?
  [[ $rc -ne 0 ]] || { echo "    self-pairing should fail preflight"; return 1; }
}

# #71: a linked git worktree passes the bare "is a git repo" check but has no own
# .git/hooks dir, so the trace-filter hook would silently fail. Preflight must reject
# it before any writes (preflight is non-mutating).
test_C_preflight_worktree_canonical_fails() {
  local d="$_WI_TMP/p5"; mkdir -p "$d"
  local main; main="$(_make_existing_canonical "$d" "proj")"
  local wt="$d/proj-wt"
  git -C "$main" worktree add -q "$wt" 2>/dev/null || { echo "    could not create test worktree"; return 1; }
  local ai; ai="$(_make_existing_ai_workspace "$d" "proj-ws")"
  local rc; ( wi_skeleton_preflight_existing_dual "$ai" "$wt" 2>/dev/null ); rc=$?
  [[ $rc -ne 0 ]] || { echo "    worktree canonical should fail preflight"; return 1; }
  [[ ! -e "$ai/.workspace/pairing.json" ]] || { echo "    preflight wrote a manifest on a rejected worktree"; return 1; }
}

# ---------------------------------------------------------------------------
# Happy path — 2 tests
# ---------------------------------------------------------------------------

test_C_pairing_succeeds() {
  local d="$_WI_TMP/h0"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws")"
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1 \
    || { echo "    Scenario C pairing returned non-zero"; return 1; }
  assert_file_exists "$ai/.workspace/pairing.json" || return 1
}

# The defining Scenario-C invariant: the populated AI workspace is NOT seeded or
# stubbed — pre-existing content survives byte-for-byte.
test_C_existing_ai_content_preserved() {
  local d="$_WI_TMP/h1"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws")"
  local before_claude; before_claude="$(cat "$ai/CLAUDE.md")"
  local before_spec;   before_spec="$(cat "$ai/docs/MASTER-SPEC.md")"
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1
  assert_eq "$before_claude" "$(cat "$ai/CLAUDE.md")" || { echo "    CLAUDE.md was clobbered"; return 1; }
  assert_eq "$before_spec"   "$(cat "$ai/docs/MASTER-SPEC.md")" || { echo "    MASTER-SPEC.md was clobbered"; return 1; }
  assert_file_exists "$ai/.claude/memory-bank/00-project-brief.md" || return 1
  assert_file_exists "$ai/docs/specs/VS-1.1.1-demo.md" || return 1
}

# ---------------------------------------------------------------------------
# Manifest body — 3 tests
# ---------------------------------------------------------------------------

test_C_manifest_ai_name_is_basename_not_name_ai() {
  local d="$_WI_TMP/m0"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "myworkspace")"
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1
  # Scenario C uses the EXISTING dir's basename verbatim — not a derived "<name>-ai".
  assert_eq "myworkspace" "$(jq -r '.ai_workspace.name' "$ai/.workspace/pairing.json")" || return 1
}

test_C_manifest_canonical_root_points_at_existing() {
  local d="$_WI_TMP/m1"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws")"
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1
  local v; v="$(jq -r '.canonical.root' "$ai/.workspace/pairing.json")"
  assert_eq "$(wi_realpath "$canonical")" "$(wi_realpath "$v")" || return 1
}

test_C_manifest_default_branch_detected() {
  local d="$_WI_TMP/m2"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws")"
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1
  assert_eq "main" "$(jq -r '.canonical.default_branch' "$ai/.workspace/pairing.json")" || return 1
}

# #71: a git AI workspace records ai_workspace.git_tracked: true …
test_C_manifest_ai_git_tracked_true_for_git_ai() {
  local d="$_WI_TMP/m3"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws")"   # as_git → git repo
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1
  jq -e '.ai_workspace.git_tracked == true' "$ai/.workspace/pairing.json" >/dev/null \
    || { echo "    git AI workspace should record git_tracked: true"; return 1; }
}

# … and a NON-git AI workspace records git_tracked: false (the #71 fix: the manifest
# stops cosmetically claiming true). This is the path the Scenario-C skill threads.
test_C_manifest_ai_git_tracked_false_for_nongit_ai() {
  local d="$_WI_TMP/m4"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws" nogit)"   # NOT a git repo
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1
  jq -e '.ai_workspace.git_tracked == false' "$ai/.workspace/pairing.json" >/dev/null \
    || { echo "    non-git AI workspace should record git_tracked: false"; return 1; }
}

# A separate-git-dir AI workspace has `.git` as a file, but it is still an own
# repo root with its own hooks dir, so Scenario C should track it and install.
test_C_manifest_ai_git_tracked_true_for_separate_git_dir_ai() {
  local d="$_WI_TMP/m5"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws" nogit)"
  git init -q --separate-git-dir="$d/proj-ws-gitdir" "$ai" 2>/dev/null
  git -C "$ai" -c user.email=t@t -c user.name=t add .
  git -C "$ai" -c user.email=t@t -c user.name=t commit -q -m "existing ai workspace"
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1
  jq -e '.ai_workspace.git_tracked == true' "$ai/.workspace/pairing.json" >/dev/null \
    || { echo "    separate-git-dir AI workspace should record git_tracked: true"; return 1; }
  assert_file_exists "$d/proj-ws-gitdir/hooks/commit-msg" || return 1
}

# ---------------------------------------------------------------------------
# Hooks — 1 test
# ---------------------------------------------------------------------------

test_C_both_repos_have_hook() {
  local d="$_WI_TMP/k0"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws")"   # as_git → AI is a git repo
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1
  assert_file_exists "$canonical/.git/hooks/commit-msg" || return 1
  assert_file_exists "$ai/.git/hooks/commit-msg" || return 1
  [[ -x "$canonical/.git/hooks/commit-msg" ]] || { echo "    canonical hook not +x"; return 1; }
}

# Scenario C explicitly allows a NON-git AI workspace: the canonical hook still
# installs, but the AI hook is skipped (no .git/hooks to install into) — and that
# is NOT an error.
test_C_nested_ai_workspace_records_false_and_skips_hook() {
  local d="$_WI_TMP/k2"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  # A parent git repo that merely CONTAINS the AI workspace as a subdirectory.
  local parent="$d/parent"; mkdir -p "$parent"
  git -C "$parent" init -q
  git -C "$parent" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  local ai; ai="$(_make_existing_ai_workspace "$parent" "nested-ws" nogit)"   # inside parent, no own .git
  # Fixture invariant: rev-parse --git-dir succeeds (reports the PARENT) but $ai/.git is absent.
  git -C "$ai" rev-parse --git-dir >/dev/null 2>&1 || { echo "    fixture: ai not inside parent repo"; return 1; }
  [[ ! -d "$ai/.git" ]] || { echo "    fixture: ai should not have its own .git"; return 1; }
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1 \
    || { echo "    pairing failed for a nested AI workspace"; return 1; }
  jq -e '.ai_workspace.git_tracked == false' "$ai/.workspace/pairing.json" >/dev/null \
    || { echo "    nested AI workspace should record git_tracked:false (#84 Codex)"; return 1; }
  [[ ! -e "$ai/.git/hooks/commit-msg" ]] || { echo "    AI hook installed for a nested workspace"; return 1; }
  assert_file_exists "$canonical/.git/hooks/commit-msg" || return 1   # canonical hook still installs
}

test_C_non_git_ai_workspace_skips_ai_hook() {
  local d="$_WI_TMP/k1"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws" nogit)"   # NOT a git repo
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1 \
    || { echo "    pairing failed for a non-git AI workspace"; return 1; }
  assert_file_exists "$ai/.workspace/pairing.json" || return 1
  assert_file_exists "$canonical/.git/hooks/commit-msg" || return 1     # canonical hook: installed
  if [[ -e "$ai/.git/hooks/commit-msg" ]]; then                         # AI hook: correctly skipped
    echo "    AI hook installed despite a non-git AI workspace"; return 1
  fi
}

# ---------------------------------------------------------------------------
# Canonical safety — 2 tests
# ---------------------------------------------------------------------------

_dual_working_tree_snapshot() { # <canonical root> <before|after site>
  local root="$1" site="$2" files find_status
  if files="$(cd "$root" && find . -not -path './.git' -not -path './.git/*')"; then
    [[ -z "$files" ]] || printf '%s\n' "$files" | sort
  else
    find_status=$?
    printf 'dual canonical %s snapshot %s: find exited %s\n' "$site" "$root" "$find_status" >&2
    return "$find_status"
  fi
}

test_C_snapshot_rejects_unreadable_directory() {
  local root="$_WI_TMP/snapshot-find-control" site out rc
  mkdir -p "$root/locked"
  printf 'hidden\n' > "$root/locked/hidden.txt"
  if [[ "$(id -u)" -eq 0 ]]; then
    printf '    SKIP dual snapshot unreadable-directory control: uid 0 bypasses chmod 000\n'
    return 0
  fi
  for site in before after; do
    chmod 000 "$root/locked"
    rc=0
    out="$(_dual_working_tree_snapshot "$root" "$site" 2>&1)" || rc=$?
    chmod 700 "$root/locked"
    [[ "$rc" -ne 0 ]] || { echo "    $site snapshot accepted an unreadable directory: $out"; return 1; }
    assert_contains "dual canonical $site snapshot $root: find exited $rc" "$out" || return 1
  done
}

test_C_snapshot_reads_sorted_complete_tree() {
  local root="$_WI_TMP/snapshot-find-readable" site out
  mkdir -p "$root/locked" "$root/.git"
  printf 'hidden\n' > "$root/locked/hidden.txt"
  : > "$root/z.txt"; : > "$root/a.txt"; : > "$root/.git/ignored"
  for site in before after; do
    out="$(_dual_working_tree_snapshot "$root" "$site")" || return 1
    assert_eq $'.\n./a.txt\n./locked\n./locked/hidden.txt\n./z.txt' "$out" || return 1
  done
}

test_C_canonical_working_tree_unchanged() {
  local d="$_WI_TMP/s0"; mkdir -p "$d"
  local canonical; canonical="$(_make_existing_canonical "$d" "proj")"
  local ai;        ai="$(_make_existing_ai_workspace "$d" "proj-ws")"
  local before; before="$(_dual_working_tree_snapshot "$canonical" before)" || return 1
  local before_main; before_main="$(cat "$canonical/src/main.txt")"
  _run_existing_dual_pairing "$ai" "$canonical" personal >/dev/null 2>&1
  local after; after="$(_dual_working_tree_snapshot "$canonical" after)" || return 1
  assert_eq "$before" "$after" || { echo "    canonical working tree changed"; return 1; }
  assert_eq "$before_main" "$(cat "$canonical/src/main.txt")" || return 1
}

test_C_git_remote_null_then_url() {
  # Variant A: no origin → null.
  local da="$_WI_TMP/s1a"; mkdir -p "$da"
  local cana; cana="$(_make_existing_canonical "$da" "proj")"
  local aia;  aia="$(_make_existing_ai_workspace "$da" "proj-ws")"
  _run_existing_dual_pairing "$aia" "$cana" personal >/dev/null 2>&1
  assert_eq "null" "$(jq -r '.canonical.git_remote' "$aia/.workspace/pairing.json")" || return 1

  # Variant B: with origin → url.
  local db="$_WI_TMP/s1b"; mkdir -p "$db"
  local canb; canb="$(_make_existing_canonical "$db" "proj")"
  git -C "$canb" remote add origin "git@github.com:example/proj.git"
  local aib;  aib="$(_make_existing_ai_workspace "$db" "proj-ws")"
  _run_existing_dual_pairing "$aib" "$canb" personal >/dev/null 2>&1
  assert_eq "git@github.com:example/proj.git" "$(jq -r '.canonical.git_remote' "$aib/.workspace/pairing.json")" || return 1
}

# ---------------------------------------------------------------------------
# Run all (13 tests)
# ---------------------------------------------------------------------------

wi_test_run test_C_preflight_happy
wi_test_run test_C_preflight_empty_ai_fails
wi_test_run test_C_preflight_missing_ai_fails
wi_test_run test_C_preflight_canonical_not_git_fails
wi_test_run test_C_preflight_self_pairing_fails
wi_test_run test_C_preflight_worktree_canonical_fails

wi_test_run test_C_pairing_succeeds
wi_test_run test_C_existing_ai_content_preserved

wi_test_run test_C_manifest_ai_name_is_basename_not_name_ai
wi_test_run test_C_manifest_canonical_root_points_at_existing
wi_test_run test_C_manifest_default_branch_detected
wi_test_run test_C_manifest_ai_git_tracked_true_for_git_ai
wi_test_run test_C_manifest_ai_git_tracked_false_for_nongit_ai
wi_test_run test_C_manifest_ai_git_tracked_true_for_separate_git_dir_ai

wi_test_run test_C_both_repos_have_hook
wi_test_run test_C_nested_ai_workspace_records_false_and_skips_hook
wi_test_run test_C_non_git_ai_workspace_skips_ai_hook

wi_test_run test_C_snapshot_rejects_unreadable_directory
wi_test_run test_C_snapshot_reads_sorted_complete_tree
wi_test_run test_C_canonical_working_tree_unchanged
wi_test_run test_C_git_remote_null_then_url

wi_test_summary
