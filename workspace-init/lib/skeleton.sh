#!/usr/bin/env bash
# lib/skeleton.sh — directory skeleton creation + init-log entries.
# Per SPEC §8.1 (preflight validation), §8.2 (root dir creation),
# §8.3 (subdir seeding + .gitignore render).
#
# All filesystem operations append TAB-separated entries to
# <ai-root>/.workspace/init-log so Phase 3g rollback can replay them in reverse.
#
# Requires: lib/_helpers.sh (wi_log_*, wi_log_op).
# Bash 3.2+ compatible (stock macOS).

set -u

if ! declare -F wi_log_op >/dev/null 2>&1; then
  source "$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_helpers.sh"
fi

# Internal: derive the init-log path from the AI workspace root.
_wi_skeleton_log() {
  local ai_root="$1"
  echo "${ai_root}/.workspace/init-log"
}

# Internal: append unless a line already has field 1 == OP and field 2 == PATH,
# compared as whole strings; a third (detail) field is ignored.
_wi_skeleton_log_once() {
  local log="$1"
  local op="$2"
  local target_path="$3"
  # #834: ENVIRON preserves backslashes that awk -v would interpret.
  if [[ -f "$log" ]] && WI_LOG_OP="$op" WI_LOG_PATH="$target_path" awk -F '\t' '
    $1 "" == ENVIRON["WI_LOG_OP"] && $2 "" == ENVIRON["WI_LOG_PATH"] { found = 1 }
    END { exit !found }' "$log" 2>/dev/null; then
    return 0
  fi
  wi_log_op "$log" "$op" "$target_path"
}

# wi_git_is_linked_worktree <dir>
#
# True (exit 0) when <dir> is a LINKED git worktree (created via `git worktree add`):
# its `.git` redirects to the main repo's `.git/worktrees/<name>`, so `<dir>/.git/hooks`
# does not exist and the trace-filter commit-msg hook would silently fail to install
# (#71). We reject these at preflight rather than half-supporting them — pair against
# the main working tree. Returns non-zero for a standalone repo, a non-repo, or an
# empty arg.
#
# A LINKED worktree is the ONLY repo shape where --git-dir (…/.git/worktrees/<name>)
# differs from --git-common-dir (…/.git). A standalone repo whose `.git` is a FILE — a
# `--separate-git-dir` checkout or a submodule — keeps the two EQUAL and has a working
# hooks dir, so matching on `.git`-is-a-file alone would wrongly reject it (#84). Compare
# the two dirs instead.
wi_git_is_linked_worktree() {
  local dir="${1:-}"
  [[ -n "$dir" ]] || return 1
  local git_dir common_dir
  git_dir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null)" || return 1
  common_dir="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)" || return 1
  [[ "$git_dir" != "$common_dir" ]]
}

# _wi_skeleton_ai_dir_from_args <caller> <name> [--ai-dir-name NAME]
#
# Prints the AI workspace directory name (#174): NAME when `--ai-dir-name` is
# given, else `<name>-ai` — the unchanged default. NAME is typed by the user, so
# it must match one closed shape before it becomes a path component: a letter
# or digit first, then letters, digits, `.`, `_` or `-`. That refuses empty,
# `.`, `..`, any `/`, a leading `-`, and the whitespace and control characters
# the TAB-separated init-log cannot hold. It is refused, never rewritten. Also
# refuses an unknown arg, a missing value and a repeated flag.
_wi_skeleton_ai_dir_from_args() {
  local caller="$1"
  local name="$2"
  shift 2
  local ai_dir="" ai_dir_set=""
  while (( $# > 0 )); do
    case "$1" in
      --ai-dir-name)
        if (( $# < 2 )); then
          wi_log_error "$caller: --ai-dir-name requires a value"
          return 1
        fi
        if [[ -n "$ai_dir_set" ]]; then
          wi_log_error "$caller: --ai-dir-name given more than once"
          return 1
        fi
        ai_dir="$2"
        ai_dir_set=1
        shift 2
        ;;
      *)
        wi_log_error "$caller: unknown arg: $1"
        return 1
        ;;
    esac
  done

  if [[ -z "$ai_dir_set" ]]; then
    printf '%s\n' "${name}-ai"
    return 0
  fi
  if ! [[ "$ai_dir" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    wi_log_error "$caller: invalid --ai-dir-name (must match ^[A-Za-z0-9][A-Za-z0-9._-]*\$): '$ai_dir'"
    return 1
  fi
  printf '%s\n' "$ai_dir"
}

# _wi_skeleton_same_dir_name <a> <b>
#
# True when two sibling names would land on one directory. Compared without
# case, because the default macOS filesystem maps `FOO` and `foo` to one entry.
_wi_skeleton_same_dir_name() {
  local a b
  a="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  b="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
  [[ "$a" == "$b" ]]
}

# wi_skeleton_preflight <parent> <name> [--pair-with <existing-canonical>] [--ai-dir-name <dir>]
#
# Validates the inputs needed to start an init run, per SPEC §8.1:
#   - <name> matches ^[a-z0-9-]+$ (kebab-case)
#   - <parent> exists and is writable
#   - AI workspace target (<parent>/<name>-ai, or <parent>/<dir> with
#     --ai-dir-name) has no existing filesystem entry
#   - Fresh mode: canonical target (<parent>/<name>) has no existing entry, and
#     the AI target is not the canonical target
#   - Pair-with mode: --pair-with path must exist + be a git repo
#
# Returns 0 on success, non-zero on any failure (with error to stderr).
wi_skeleton_preflight() {
  local parent="$1"
  local name="$2"
  local pair_with=""
  local ai_dir_args=()
  shift 2
  while (( $# > 0 )); do
    case "$1" in
      --pair-with)
        pair_with="$2"
        shift 2
        ;;
      --ai-dir-name)
        ai_dir_args+=("$1")
        if (( $# >= 2 )); then
          ai_dir_args+=("$2")
          shift
        fi
        shift
        ;;
      *)
        wi_log_error "wi_skeleton_preflight: unknown arg: $1"
        return 1
        ;;
    esac
  done

  # Name: kebab-case
  if ! [[ "$name" =~ ^[a-z0-9-]+$ ]]; then
    wi_log_error "wi_skeleton_preflight: invalid project name (must match ^[a-z0-9-]+\$): $name"
    return 1
  fi

  # Parent: exists + writable
  if [[ ! -d "$parent" ]]; then
    wi_log_error "wi_skeleton_preflight: parent dir does not exist: $parent"
    return 1
  fi
  if [[ ! -w "$parent" ]]; then
    wi_log_error "wi_skeleton_preflight: parent dir not writable: $parent"
    return 1
  fi

  local ai_dir
  ai_dir="$(_wi_skeleton_ai_dir_from_args wi_skeleton_preflight "$name" ${ai_dir_args[@]+"${ai_dir_args[@]}"})" || return 1
  local ai_root="${parent}/${ai_dir}"
  local canonical_root="${parent}/${name}"

  if [[ -z "$pair_with" ]] && _wi_skeleton_same_dir_name "$ai_dir" "$name"; then
    wi_log_error "wi_skeleton_preflight: --ai-dir-name names the canonical target; pick a different AI workspace dir: $ai_root"
    return 1
  fi

  # Reject every target collision before root creation starts. `-d` misses
  # regular files and `-e` alone misses dangling symlinks; either shape would
  # otherwise let create_root_pair make one sibling before failing on the other.
  if [[ -e "$ai_root" || -L "$ai_root" ]]; then
    wi_log_error "wi_skeleton_preflight: AI workspace target already exists: $ai_root"
    return 1
  fi

  if [[ -n "$pair_with" ]]; then
    if [[ ! -d "$pair_with" ]]; then
      wi_log_error "wi_skeleton_preflight: --pair-with path does not exist: $pair_with"
      return 1
    fi
    if [[ ! -d "$pair_with/.git" ]] && ! git -C "$pair_with" rev-parse --git-dir >/dev/null 2>&1; then
      wi_log_error "wi_skeleton_preflight: --pair-with path is not a git repo: $pair_with"
      return 1
    fi
    # Same bug class as Scenario C (#71): a linked worktree has no own .git/hooks,
    # so the trace-filter hook would silently fail. Reject it here too.
    if wi_git_is_linked_worktree "$pair_with"; then
      wi_log_error "wi_skeleton_preflight: --pair-with is a linked git worktree (its .git is a file, not a repo dir); pair against its main working tree instead: $pair_with"
      return 1
    fi
  else
    if [[ -e "$canonical_root" || -L "$canonical_root" ]]; then
      wi_log_error "wi_skeleton_preflight: canonical target already exists: $canonical_root"
      return 1
    fi
  fi

  return 0
}

# wi_skeleton_preflight_existing_dual <ai-root> <canonical-root>
#
# Scenario C preflight (issue #9): BOTH repos already exist and are populated —
# an AI workspace that grew its memory-bank/specs organically before the user
# discovered the plugins, alongside an existing canonical. Unlike
# wi_skeleton_preflight --pair-with (which requires the AI workspace to NOT exist
# yet and CREATES it), this validates that the AI workspace ALREADY exists and is
# non-empty, and the canonical exists + is a git repo. The AI workspace may or may
# not itself be a git repo (Scenario C only writes a manifest + installs hooks; it
# never seeds or stubs). Returns 0 on success, non-zero (error to stderr) on any
# failure. Performs NO mutation.
wi_skeleton_preflight_existing_dual() {
  local ai_root="${1:-}"
  local canonical_root="${2:-}"

  if [[ -z "$ai_root" || -z "$canonical_root" ]]; then
    wi_log_error "wi_skeleton_preflight_existing_dual: usage: <ai-root> <canonical-root>"
    return 1
  fi

  # AI workspace: exists, is a dir, and is non-empty (already populated).
  if [[ ! -d "$ai_root" ]]; then
    wi_log_error "wi_skeleton_preflight_existing_dual: AI workspace does not exist: $ai_root"
    return 1
  fi
  if [[ -z "$(ls -A "$ai_root" 2>/dev/null)" ]]; then
    wi_log_error "wi_skeleton_preflight_existing_dual: AI workspace is empty (Scenario C expects an already-populated workspace): $ai_root"
    return 1
  fi

  # Canonical: exists, is a dir, is a git repo.
  if [[ ! -d "$canonical_root" ]]; then
    wi_log_error "wi_skeleton_preflight_existing_dual: canonical does not exist: $canonical_root"
    return 1
  fi
  if [[ ! -d "$canonical_root/.git" ]] && ! git -C "$canonical_root" rev-parse --git-dir >/dev/null 2>&1; then
    wi_log_error "wi_skeleton_preflight_existing_dual: canonical is not a git repo: $canonical_root"
    return 1
  fi
  # A linked worktree passes the git-repo check above but has no own .git/hooks dir,
  # so the trace-filter hook would silently fail to install. Reject it (#71).
  if wi_git_is_linked_worktree "$canonical_root"; then
    wi_log_error "wi_skeleton_preflight_existing_dual: canonical is a linked git worktree (its .git is a file, not a repo dir); pair against its main working tree instead: $canonical_root"
    return 1
  fi

  # Guard against accidental self-pairing. Canonicalize both paths first so
  # trailing slashes, relative-vs-absolute, and symlink variations of the same
  # directory are caught (both exist at this point, so wi_realpath resolves them).
  local ai_canon canonical_canon
  ai_canon="$(wi_realpath "$ai_root")"
  canonical_canon="$(wi_realpath "$canonical_root")"
  if [[ "$ai_canon" == "$canonical_canon" ]]; then
    wi_log_error "wi_skeleton_preflight_existing_dual: ai_root and canonical must be different paths: $ai_canon"
    return 1
  fi

  return 0
}

# wi_skeleton_create_root_pair <parent> <name> [--ai-dir-name <dir>]
#
# Fresh-mode root creation (SPEC §8.2): mkdir both AI workspace and canonical.
# Also creates <ai>/.workspace so the init-log has a parent. Logs all three.
# The AI workspace is <parent>/<name>-ai, or <parent>/<dir> with --ai-dir-name.
wi_skeleton_create_root_pair() {
  local parent="$1"
  local name="$2"
  shift 2
  local ai_dir
  ai_dir="$(_wi_skeleton_ai_dir_from_args wi_skeleton_create_root_pair "$name" "$@")" || return 1
  if _wi_skeleton_same_dir_name "$ai_dir" "$name"; then
    wi_log_error "wi_skeleton_create_root_pair: --ai-dir-name names the canonical target: ${parent}/${ai_dir}"
    return 1
  fi
  local ai_root="${parent}/${ai_dir}"
  local canonical_root="${parent}/${name}"

  # Plain `mkdir`, never `-p`, for the two roots: rollback answers a MKDIR
  # entry with `rm -rf`, so a root that already exists must be refused here,
  # not adopted and logged as ours.
  if ! mkdir "$ai_root"; then
    wi_log_error "wi_skeleton_create_root_pair: mkdir failed (exists or unwritable): $ai_root"
    return 1
  fi
  if ! mkdir "$canonical_root"; then
    wi_log_error "wi_skeleton_create_root_pair: mkdir failed (exists or unwritable): $canonical_root"
    return 1
  fi
  if ! mkdir -p "${ai_root}/.workspace"; then
    wi_log_error "wi_skeleton_create_root_pair: mkdir failed: ${ai_root}/.workspace"
    return 1
  fi

  local log
  log="$(_wi_skeleton_log "$ai_root")"
  _wi_skeleton_log_once "$log" MKDIR "$ai_root"
  _wi_skeleton_log_once "$log" MKDIR "$canonical_root"
  _wi_skeleton_log_once "$log" MKDIR "${ai_root}/.workspace"
  return 0
}

# wi_skeleton_create_root_ai_only <parent> <name> [--ai-dir-name <dir>]
#
# Pair-with-mode root creation (SPEC §8.2): mkdir only AI workspace. The
# canonical already exists and must NOT be touched here. The AI workspace is
# <parent>/<name>-ai, or <parent>/<dir> with --ai-dir-name.
wi_skeleton_create_root_ai_only() {
  local parent="$1"
  local name="$2"
  shift 2
  local ai_dir
  ai_dir="$(_wi_skeleton_ai_dir_from_args wi_skeleton_create_root_ai_only "$name" "$@")" || return 1
  local ai_root="${parent}/${ai_dir}"

  # Plain `mkdir`, never `-p`: an AI root that already exists is refused, not
  # logged as MKDIR for rollback's `rm -rf` (see wi_skeleton_create_root_pair).
  if ! mkdir "$ai_root"; then
    wi_log_error "wi_skeleton_create_root_ai_only: mkdir failed (exists or unwritable): $ai_root"
    return 1
  fi
  if ! mkdir -p "${ai_root}/.workspace"; then
    wi_log_error "wi_skeleton_create_root_ai_only: mkdir failed: ${ai_root}/.workspace"
    return 1
  fi

  local log
  log="$(_wi_skeleton_log "$ai_root")"
  _wi_skeleton_log_once "$log" MKDIR "$ai_root"
  _wi_skeleton_log_once "$log" MKDIR "${ai_root}/.workspace"
  return 0
}

# wi_skeleton_seed_subdirs <ai-root>
#
# SPEC §8.3: seed subdir skeleton + .gitkeep + .gitignore. Idempotent — second
# invocation on an already-seeded ai-root must not crash and must not append
# duplicate log entries (rollback replay relies on each path appearing once).
wi_skeleton_seed_subdirs() {
  local ai_root="$1"

  if [[ ! -d "$ai_root" ]]; then
    wi_log_error "wi_skeleton_seed_subdirs: ai_root does not exist: $ai_root"
    return 1
  fi

  local log
  log="$(_wi_skeleton_log "$ai_root")"

  local subdirs=(".workspace" ".claude" "docs" "docs/specs" ".superpowers" ".archive")
  local sd d gk
  for sd in "${subdirs[@]}"; do
    d="${ai_root}/${sd}"
    if ! mkdir -p "$d"; then
      wi_log_error "wi_skeleton_seed_subdirs: mkdir failed: $d"
      return 1
    fi
    _wi_skeleton_log_once "$log" MKDIR "$d"

    gk="${d}/.gitkeep"
    if [[ ! -f "$gk" ]]; then
      touch "$gk" || { wi_log_error "touch failed: $gk"; return 1; }
      _wi_skeleton_log_once "$log" WRITE_FILE "$gk"
    fi
  done

  # Render .gitignore from template (fallback to inline if template absent —
  # belt-and-braces so the plugin still works if someone deletes the template).
  local gi="${ai_root}/.gitignore"
  if [[ ! -f "$gi" ]]; then
    local tmpl="${WI_TEMPLATES_DIR:-$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates}/gitignore.tmpl"
    if [[ -f "$tmpl" ]]; then
      if ! cp "$tmpl" "$gi"; then
        wi_log_error "wi_skeleton_seed_subdirs: cp failed: $tmpl -> $gi"
        return 1
      fi
    else
      cat > "$gi" <<'EOF'
# Per-machine handoff files (legacy compatibility; not synced)
.workspace/handoffs/

# OS-level cruft
.DS_Store
*.swp
EOF
    fi
    _wi_skeleton_log_once "$log" WRITE_FILE "$gi"
  fi

  return 0
}
