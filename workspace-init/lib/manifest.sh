#!/usr/bin/env bash
# lib/manifest.sh — pairing manifest read/write/resolve/validate
#
# Cross-plugin contract per SPEC §6.2 / §6.3 / §6.4 / §6.5.
# Consumers: ossify (reads pairing.json as a translated fallback).
#
# Bash 3.2+ compatible (stock macOS). Requires: jq.
#
# Implementation strategy:
#   - WRITE: constructed with `jq -n` using --arg / --argjson (NOT template
#            substitution). Safer for structured JSON; preserves literal
#            `${ai_workspace.root}` / `${canonical.root}` placeholders that
#            must remain unresolved at write time and be resolved at read time
#            by wi_manifest_resolve.
#   - READ:  thin `jq -r` wrapper that returns full JSON or a specific path.
#   - RESOLVE: pure-bash parameter expansion + a regex loop for ${PLUGIN_DATA:<name>}.
#
# Functions:
#   wi_plugin_data_dir <plugin-name>
#   wi_manifest_write  <ai-root> <canonical-root> <project-type> [--git-remote URL]
#                      [--canonical-git-remote URL] [--default-branch NAME]
#   wi_manifest_relocate <ai-root> [--canonical-root PATH]
#   wi_manifest_read   <ai-root> [<field-jq-path>]
#   wi_manifest_resolve <ai-root> <string-with-vars>
#   wi_manifest_validate <ai-root>

set -u

# Source helpers if not already loaded (wi_log_* etc).
if ! declare -F wi_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_helpers.sh"
fi

# ---------------------------------------------------------------------------
# Constants (per SPEC §6.5)
# ---------------------------------------------------------------------------

# Writer emits this version. Bump on breaking schema change.
WI_MANIFEST_SCHEMA_VERSION="1.0"

# Reader accepts these versions. Single value in v0.1.0; comma-separated list
# in later releases as additive versions accrue.
WI_MANIFEST_SUPPORTED_VERSIONS="1.0"

# Manifest path is always <ai-root>/.workspace/pairing.json (per SPEC §6.1).
_wi_manifest_path() {
  echo "$1/.workspace/pairing.json"
}

# wi_plugin_version — resolve the writing tool's version from the sibling plugin
# manifest. `created_by` is provenance ("which workspace-init wrote this manifest"),
# so it must reflect the actual running version, not a frozen literal (#71). The
# .claude-plugin manifest is the single source of truth and is already guarded by
# tests/test-codex-dual-publish.sh. Fallback keeps the <semver> shape if unreadable.
wi_plugin_version() {
  local libdir manifest ver="" src="${BASH_SOURCE[0]:-}"
  if [[ -n "$src" ]]; then
    libdir="$(CDPATH= cd -- "$(dirname "$src")" && pwd)"
    manifest="$libdir/../.claude-plugin/plugin.json"
    ver="$(jq -r '.version // empty' "$manifest" 2>/dev/null)"
  fi
  [[ -n "$ver" ]] || ver="0.0.0"
  printf '%s' "$ver"
}

# ---------------------------------------------------------------------------
# wi_plugin_data_dir — Claude Code plugin-data convention
# ---------------------------------------------------------------------------
#
# Discovery (2026-05-25):
#   - Claude Code sets ${CLAUDE_PLUGIN_DATA} per-process to the INVOKING
#     plugin's data dir. Useless for cross-plugin resolution (SPEC §6.3).
#   - Actual layout on disk: ~/.claude/plugins/data/<plugin>-<marketplace>/
#     (e.g. sage-pulsestack).
#   - But marketplace suffix is unknown at manifest-author time. Existing
#     plugins (e.g. sage) all
#     fall back to ${HOME}/.claude/plugins/data/<plugin> for their own data
#     paths when ${CLAUDE_PLUGIN_DATA} is unset (e.g. shell-level tests).
#
# Resolution order:
#   1. ${CLAUDE_PLUGINS_ROOT}/<plugin>/data  — if env var is set (future-proof)
#   2. ${HOME}/.claude/plugins/data/<plugin>-<marketplace> — if a directory
#       matching that prefix exists under the known plugin-data root
#       (matches the actual on-disk layout for installed plugins)
#   3. ${HOME}/.claude/plugins/data/<plugin> — convention used by existing
#       plugins' own fallbacks; always returned as the final default
#       (regardless of existence, per SPEC §13.3 — path is returned, warning
#       is optional in v0.1).
#
# Note on (2): callers may pass plugin names that aren't installed. We don't
# guarantee the returned path exists; SPEC §13.3 explicitly says the resolver
# returns a path even for missing plugins.
wi_plugin_data_dir() {
  local plugin="$1"
  if [[ -z "$plugin" ]]; then
    wi_log_error "wi_plugin_data_dir: missing plugin name"
    return 1
  fi

  # (1) Future env var hook
  if [[ -n "${CLAUDE_PLUGINS_ROOT:-}" ]]; then
    echo "${CLAUDE_PLUGINS_ROOT}/${plugin}/data"
    return 0
  fi

  # (2) Probe for actual installed-plugin marketplace-suffixed dir
  local data_root="${HOME}/.claude/plugins/data"
  if [[ -d "$data_root" ]]; then
    # Glob may leave the literal pattern if no match; guard with -d.
    local cand
    for cand in "$data_root/${plugin}"-*; do
      if [[ -d "$cand" ]]; then
        echo "$cand"
        return 0
      fi
    done
    # Also accept exact-name match (no marketplace suffix)
    if [[ -d "$data_root/${plugin}" ]]; then
      echo "$data_root/${plugin}"
      return 0
    fi
  fi

  # (3) Default fallback — convention used by existing plugins' own paths.
  # Path may not exist yet; that's fine for SPEC §13.3.
  echo "${data_root}/${plugin}"
  return 0
}

# ---------------------------------------------------------------------------
# wi_manifest_write
# ---------------------------------------------------------------------------
# Usage:
#   wi_manifest_write <ai-root> <canonical-root> <project-type> \
#     [--git-remote URL] [--canonical-git-remote URL] [--default-branch NAME]
#
# Writes <ai-root>/.workspace/pairing.json. Atomic via tmp-then-mv. Constructs
# JSON with `jq -n` for safety (proper escaping, no template clobber of the
# literal `${ai_workspace.root}` / `${canonical.root}` placeholders in
# during_dev + well_known_paths).
wi_manifest_write() {
  local ai_root="" canonical_root="" project_type=""
  local ai_git_remote_json="null"
  local canonical_git_remote_json="null"
  local default_branch="main"
  # ai_workspace.git_tracked: a JSON boolean literal. Defaults true (fresh-init and
  # Scenario-A create the AI workspace as a git repo); the Scenario-C pairing skill
  # passes --ai-git-tracked false when the existing AI workspace is not a git repo (#71).
  local ai_git_tracked_json="true"
  # Optional tooling_repo (#48 Stage 2 marketplace routing). Absent → key omitted.
  local tooling_root=""
  local tooling_git_remote_json="null"

  # Positional args first (3 required).
  if [[ $# -lt 3 ]]; then
    wi_log_error "wi_manifest_write: usage: wi_manifest_write <ai-root> <canonical-root> <project-type> [--flags]"
    return 1
  fi
  ai_root="$1"; canonical_root="$2"; project_type="$3"
  shift 3

  # Flags.
  while (( $# > 0 )); do
    case "$1" in
      --git-remote)
        if [[ -z "${2:-}" ]]; then
          wi_log_error "wi_manifest_write: --git-remote requires URL"
          return 1
        fi
        # Use --argjson with a JSON string so null vs "url" is preserved.
        ai_git_remote_json="$(printf '%s' "$2" | jq -R '.')"
        shift 2
        ;;
      --canonical-git-remote)
        if [[ -z "${2:-}" ]]; then
          wi_log_error "wi_manifest_write: --canonical-git-remote requires URL"
          return 1
        fi
        canonical_git_remote_json="$(printf '%s' "$2" | jq -R '.')"
        shift 2
        ;;
      --default-branch)
        if [[ -z "${2:-}" ]]; then
          wi_log_error "wi_manifest_write: --default-branch requires NAME"
          return 1
        fi
        default_branch="$2"
        shift 2
        ;;
      --ai-git-tracked)
        case "${2:-}" in
          true|false) ai_git_tracked_json="$2" ;;
          *) wi_log_error "wi_manifest_write: --ai-git-tracked requires true|false"; return 1 ;;
        esac
        shift 2
        ;;
      --tooling-repo)
        if [[ -z "${2:-}" ]]; then
          wi_log_error "wi_manifest_write: --tooling-repo requires PATH"
          return 1
        fi
        tooling_root="$2"
        shift 2
        ;;
      --tooling-repo-remote)
        if [[ -z "${2:-}" ]]; then
          wi_log_error "wi_manifest_write: --tooling-repo-remote requires URL"
          return 1
        fi
        tooling_git_remote_json="$(printf '%s' "$2" | jq -R '.')"
        shift 2
        ;;
      *)
        wi_log_error "wi_manifest_write: unknown flag: $1"
        return 1
        ;;
    esac
  done

  # Validation.
  case "$project_type" in
    personal|work) ;;
    *) wi_log_error "wi_manifest_write: invalid project_type '$project_type' (expected: personal|work)"; return 1 ;;
  esac

  # tooling_repo (optional): a remote without a root would be silently dropped at
  # emit time (the key is gated on tooling_root); and a relative root breaks the
  # later `cd "$target"` in scaffold-dev's sd_issue_create. Fail loud on both.
  if [[ "$tooling_git_remote_json" != "null" && -z "$tooling_root" ]]; then
    wi_log_error "wi_manifest_write: --tooling-repo-remote requires --tooling-repo"
    return 1
  fi
  if [[ -n "$tooling_root" && "$tooling_root" != /* ]]; then
    wi_log_error "wi_manifest_write: --tooling-repo must be an absolute path: $tooling_root"
    return 1
  fi

  if [[ ! -d "$ai_root" ]]; then
    wi_log_error "wi_manifest_write: ai_root not a directory: $ai_root"
    return 1
  fi
  # An empty canonical root (an unset shell variable, say) would be written as
  # canonical.root = "" and canonical.name = "", a manifest wi_manifest_validate
  # refuses, while the write reported success.
  if [[ -z "$canonical_root" ]]; then
    wi_log_error "wi_manifest_write: canonical root is empty"
    return 1
  fi
  # The roots are recorded as absolute paths: ${ai_workspace.root} and
  # ${canonical.root} are substituted into absolute path templates, and a
  # relative root would resolve against whatever cwd reads the manifest
  # (wi_manifest_validate refuses one). A relative argument is anchored at $PWD
  # here, as relocate does; an absolute one is recorded as given.
  [[ "$ai_root" == /* ]] || ai_root="$(wi_resolve_root "$ai_root")"
  [[ "$canonical_root" == /* ]] || canonical_root="$(wi_resolve_root "$canonical_root")"

  local ai_name canonical_name
  ai_name="$(basename "$ai_root")"
  canonical_name="$(basename "$canonical_root")"
  local tooling_name=""
  [[ -n "$tooling_root" ]] && tooling_name="$(basename "$tooling_root")"

  # ISO 8601 UTC timestamp.
  local created_at
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Ensure .workspace/ exists; mkdir -p is idempotent.
  local manifest
  manifest="$(_wi_manifest_path "$ai_root")"
  local manifest_dir
  manifest_dir="$(dirname "$manifest")"
  mkdir -p "$manifest_dir" || {
    wi_log_error "wi_manifest_write: failed to create $manifest_dir"
    return 1
  }

  # Build via `jq -n`. Tmp-then-mv for atomicity, under an unpredictable temp
  # name, created and written through one descriptor (wi_write_new, #582). The
  # temp file gets the mode a plain redirect gave pairing.json.
  local tmp
  if ! tmp="$(wi_tmpname_beside "$manifest")"; then
    wi_log_error "wi_manifest_write: could not name a temp file beside $manifest"
    return 1
  fi
  if ! wi_write_new "$tmp" "" jq -n \
      --arg schema_version           "$WI_MANIFEST_SCHEMA_VERSION" \
      --arg ai_root                  "$ai_root" \
      --arg ai_name                  "$ai_name" \
      --arg canonical_root           "$canonical_root" \
      --arg canonical_name           "$canonical_name" \
      --arg canonical_default_branch "$default_branch" \
      --arg project_type             "$project_type" \
      --arg created_at               "$created_at" \
      --arg created_by               "workspace-init@$(wi_plugin_version)" \
      --argjson ai_git_tracked       "$ai_git_tracked_json" \
      --argjson ai_git_remote        "$ai_git_remote_json" \
      --argjson canonical_git_remote "$canonical_git_remote_json" \
      --arg     tooling_root         "$tooling_root" \
      --arg     tooling_name         "$tooling_name" \
      --argjson tooling_git_remote   "$tooling_git_remote_json" \
      '{
         schema_version: $schema_version,
         topology: "dual-repo",
         ai_workspace: {
           root: $ai_root,
           name: $ai_name,
           git_tracked: $ai_git_tracked,
           git_remote: $ai_git_remote
         },
         canonical: {
           root: $canonical_root,
           name: $canonical_name,
           git_tracked: true,
           git_remote: $canonical_git_remote,
           default_branch: $canonical_default_branch
         },
         tooling_repo: (if $tooling_root != "" then {
           root: $tooling_root,
           name: $tooling_name,
           git_remote: $tooling_git_remote
         } else null end),
         routing: {
           master_spec:              "ai_workspace",
           executive_summary:        "canonical",
           memory_bank:              "ai_workspace",
           claude_md:                "ai_workspace",
           agents_md:                "ai_workspace",
           scaffold_project_outputs: "ai_workspace",
           backlog:                  "canonical",
           project_plan:             "canonical",
           roadmap:                  "canonical",
           prd:                      "canonical",
           srs:                      "canonical",
           product_adrs:             "canonical",
           process_adrs:             "ai_workspace",
           sprint_specs:             "ai_workspace",
           implementation_handoffs:  "ai_workspace",
           brainstorm_artifacts:     "ai_workspace"
         },
         during_dev: {
           worktrees_dir:        "${canonical.root}/.worktrees",
           branch_naming:        "slice/sprint-{N}-work-{NN}-{kebab-name}",
           sprint_dir_template:  "${ai_workspace.root}/docs/specs/sprint-{N}",
           slice_spec_format:    "wabash-format-b-v1"
         },
         well_known_paths: {
           master_spec:            "${ai_workspace.root}/docs/MASTER-SPEC.md",
           memory_bank:            "${ai_workspace.root}/.claude/memory-bank",
           roadmap_state:          "${ai_workspace.root}/.workspace/project-roadmap.json",
           superpowers_brainstorm: "${ai_workspace.root}/.superpowers/brainstorm"
         },
         git_policy: {
           project_type:           $project_type,
           allow_ai_local_commits: true,
           allow_ai_local_merge:   true,
           allow_ai_local_rebase:  true,
           allow_ai_fetch:         false,
           allow_ai_push:          false,
           allow_ai_pull:          false,
           trace_filter: {
             enforce: true,
             blocked_patterns: [
               "^Co-Authored-By:",
               "^🤖 Generated with",
               "<noreply@anthropic\\.com>",
               "<noreply@openai\\.com>"
             ]
           }
         },
         created_at: $created_at,
         created_by: $created_by
       }
       | (if .tooling_repo == null then del(.tooling_repo) else . end)' 2>/dev/null; then
    rm -f "$tmp"
    wi_log_error "wi_manifest_write: could not create $tmp, or jq failed building manifest at $manifest"
    return 1
  fi

  mv -f "$tmp" "$manifest" || {
    wi_log_error "wi_manifest_write: failed to mv tmp to $manifest"
    rm -f "$tmp"
    return 1
  }
  return 0
}

# ---------------------------------------------------------------------------
# wi_manifest_relocate
# ---------------------------------------------------------------------------
# Usage:
#   wi_manifest_relocate <ai-root> [--canonical-root PATH]
#
# The manifest half of repairing a MOVED workspace (#491). Re-baking the hooks
# (wi_trace_filter_install_pair) restores the filter, but pairing.json still
# records the old ai_workspace.root, and consumers resolving paths through
# wi_manifest_resolve would read the stale location.
#
# <ai-root> is the workspace's CURRENT location; its manifest moved with it.
# Rewrites ai_workspace.root and ai_workspace.name to that location, and — only
# with --canonical-root — canonical.root and canonical.name too. Every other
# field (project_type, git remotes, default_branch, git_policy, tooling_repo,
# created_at, ...) is carried through untouched. Both roots are recorded as
# absolute physical paths, matching what the hooks bake.
#
# Refuses, changing nothing, when: the root is not a directory, the manifest is
# a symlink, missing, not a single JSON object, or fails wi_manifest_validate
# (the full schema check, including every trace-filter rule the hook applies),
# --canonical-root is not a directory, or the result would record the same
# directory as both roots. The rewrite keeps the manifest's file mode. Atomic
# via tmp-then-mv. Does not touch the hooks and writes no init-log entry: it is
# a repair, not a bootstrap step, so rollback has nothing to undo.
wi_manifest_relocate() {
  if [[ $# -lt 1 || -z "${1:-}" ]]; then
    wi_log_error "wi_manifest_relocate: usage: wi_manifest_relocate <ai-root> [--canonical-root PATH]"
    return 1
  fi
  local ai_root="$1"; shift
  local canonical_root=""

  while (( $# > 0 )); do
    case "$1" in
      --canonical-root)
        if [[ -z "${2:-}" ]]; then
          wi_log_error "wi_manifest_relocate: --canonical-root requires PATH"
          return 1
        fi
        canonical_root="$2"
        shift 2
        ;;
      *)
        wi_log_error "wi_manifest_relocate: unknown argument: $1"
        return 1
        ;;
    esac
  done

  ai_root="$(wi_resolve_root "$ai_root")"
  if [[ ! -d "$ai_root" ]]; then
    wi_log_error "wi_manifest_relocate: AI workspace root is not a directory: $ai_root"
    return 1
  fi
  if [[ -n "$canonical_root" ]]; then
    canonical_root="$(wi_resolve_root "$canonical_root")"
    if [[ ! -d "$canonical_root" ]]; then
      wi_log_error "wi_manifest_relocate: canonical root is not a directory: $canonical_root"
      return 1
    fi
  fi

  local manifest
  manifest="$(_wi_manifest_path "$ai_root")"
  # A symlinked manifest (a shared or dotfile-managed file) would be replaced
  # by the tmp-then-mv below, leaving its real target stale while reporting
  # success. Refuse, as the hook installer refuses a symlinked hook (#490).
  if [[ -L "$manifest" ]]; then
    wi_log_error "wi_manifest_relocate: refusing to replace a symlinked manifest: $manifest -> $(readlink "$manifest" 2>/dev/null); relocate its target by hand, or replace the link with a copy and re-run"
    return 1
  fi
  if [[ ! -f "$manifest" ]]; then
    wi_log_error "wi_manifest_relocate: manifest not found at $manifest"
    return 1
  fi
  # Exactly one JSON object whose root blocks are objects — the same
  # single-document test the hook applies, plus the shape this edit needs.
  if ! jq -ne --arg cn "$canonical_root" '
        input as $doc
        | ([inputs] | length == 0)
          and ($doc | type == "object")
          and ($doc.ai_workspace | type == "object")
          and ($cn == "" or ($doc.canonical | type == "object"))' \
      "$manifest" >/dev/null 2>&1; then
    wi_log_error "wi_manifest_relocate: $manifest is not a single JSON object with the blocks to update; repair it first (README: Repair)"
    return 1
  fi
  # A parseable object can still be corrupt (missing schema_version, routing,
  # git_policy, ...). Relocating it would report success on a file the hook
  # and every consumer still reject, so the full schema check runs too. It
  # names the missing fields itself.
  if ! wi_manifest_validate "$ai_root"; then
    wi_log_error "wi_manifest_relocate: refusing to relocate an invalid manifest; repair it first (README: Repair)"
    return 1
  fi

  local old_root
  old_root="$(jq -r '.ai_workspace.root // "(unset)"' "$manifest" 2>/dev/null)" || old_root="(unreadable)"

  # The pair must stay a pair: refuse a result whose two roots are the same
  # directory — the self-pairing wi_skeleton_preflight_existing_dual rejects —
  # whether it comes from --canonical-root or from the recorded canonical.root.
  local final_cn
  if [[ -n "$canonical_root" ]]; then
    final_cn="$canonical_root"
  else
    final_cn="$(jq -r '.canonical.root' "$manifest" 2>/dev/null)" || final_cn=""
  fi
  if [[ -n "$final_cn" && "$(wi_realpath "$final_cn")" == "$(wi_realpath "$ai_root")" ]]; then
    wi_log_error "wi_manifest_relocate: refusing to record the same directory as both roots: $ai_root; ai_root and canonical must be different paths (pass the canonical's real location with --canonical-root)"
    return 1
  fi

  local ai_name cn_name=""
  ai_name="$(basename "$ai_root")"
  [[ -z "$canonical_root" ]] || cn_name="$(basename "$canonical_root")"

  # Build the replacement under an unpredictable temp name, created with the
  # manifest's own mode rather than the caller's umask — a 0600 manifest stays
  # 0600, and a read-only 0444 one stays 0444 though it is still written through
  # the descriptor that created it — and written only through that descriptor,
  # so a symlink planted or swapped in beside pairing.json cannot redirect the
  # write, and the rename cannot install one (wi_write_new, #582).
  local tmp mode
  if ! mode="$(wi_file_mode "$manifest")"; then
    wi_log_error "wi_manifest_relocate: could not read the mode of $manifest"
    return 1
  fi
  if ! tmp="$(wi_tmpname_beside "$manifest")"; then
    wi_log_error "wi_manifest_relocate: could not name a temp file beside $manifest"
    return 1
  fi
  if ! wi_write_new "$tmp" "$mode" jq \
      --arg ai_root   "$ai_root" \
      --arg ai_name   "$ai_name" \
      --arg cn_root   "$canonical_root" \
      --arg cn_name   "$cn_name" \
      '.ai_workspace.root = $ai_root
       | .ai_workspace.name = $ai_name
       | if $cn_root != "" then
           .canonical.root = $cn_root | .canonical.name = $cn_name
         else . end' \
      "$manifest" 2>/dev/null; then
    rm -f "$tmp"
    wi_log_error "wi_manifest_relocate: could not create $tmp, or jq failed rewriting $manifest"
    return 1
  fi
  # A file created by redirect never gets an execute bit, whatever the umask. A
  # manifest that had one gets it back here — by name, as the hook's +x is, so
  # a swap at this moment can change a link target's mode but not write to it.
  if (( 8#$mode & 8#111 )) && ! chmod "$mode" "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    wi_log_error "wi_manifest_relocate: could not restore the mode of $manifest"
    return 1
  fi
  mv -f "$tmp" "$manifest" || {
    rm -f "$tmp"
    wi_log_error "wi_manifest_relocate: failed to mv tmp to $manifest"
    return 1
  }
  wi_log_info "wi_manifest_relocate: ai_workspace.root ${old_root} -> ${ai_root}"
  if [[ -n "$canonical_root" ]]; then
    wi_log_info "wi_manifest_relocate: canonical.root -> ${canonical_root}"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# wi_manifest_read
# ---------------------------------------------------------------------------
# Usage:
#   wi_manifest_read <ai-root>                  → full JSON to stdout
#   wi_manifest_read <ai-root> <field-jq-path>  → `jq -r` of that field
#
# Returns:
#   0  on success
#   1  if manifest is missing OR (when a field is given) the field is absent / null
#
# A "missing field" is distinguished from JSON null using `jq -e`. Boolean
# false is intentionally treated as a present-with-value (not missing).
wi_manifest_read() {
  local ai_root="$1"
  local field="${2:-}"
  local manifest
  manifest="$(_wi_manifest_path "$ai_root")"

  if [[ ! -f "$manifest" ]]; then
    wi_log_error "wi_manifest_read: manifest not found: $manifest"
    return 1
  fi

  if [[ -z "$field" ]]; then
    # Full JSON.
    cat "$manifest"
    return 0
  fi

  # Field requested. Honor the contract above: a present, non-null value (INCLUDING
  # boolean false / 0) is returned; only a missing key, a non-indexable path, or JSON
  # null counts as "missing". Do NOT use `// empty` or `jq -e` here — jq's `//` and
  # `-e` both treat false/0 as falsy, which would mis-read git_tracked:false and the
  # allow_ai_* booleans (#71/#84, Devin). `try … catch null` swallows path-index
  # errors (e.g. `.does.not.exist`) the way the old `2>/dev/null` did.
  local result
  result="$(jq -r "try (${field}) catch null | if . == null then empty else . end" "$manifest" 2>/dev/null)"
  if [[ -z "$result" ]]; then
    return 1
  fi
  echo "$result"
  return 0
}

# ---------------------------------------------------------------------------
# _wi_splice_literal
# ---------------------------------------------------------------------------
# Usage: _wi_splice_literal <haystack> <needle> <replacement>
# Output: haystack with every literal occurrence of needle replaced.
#
# Splices left-to-right with %%/# ops, NOT ${var//pat/repl} or sed. Under bash
# 5.2+ patsub_replacement (and always under sed), a `&` in the replacement
# expands to the matched text, so a path carrying `&` — a real directory name —
# was corrupted in every resolved routing path, silently, with the resolver
# still exiting 0. The same splice is in lib/_helpers.sh's wi_render_template.
_wi_splice_literal() {
  local rest="$1" needle="$2" replacement="$3"
  local out=""
  [[ -n "$needle" ]] || { printf '%s' "$rest"; return 0; }
  while [[ "$rest" == *"$needle"* ]]; do
    out+="${rest%%"$needle"*}${replacement}"
    rest="${rest#*"$needle"}"
  done
  printf '%s' "${out}${rest}"
}

# ---------------------------------------------------------------------------
# wi_manifest_resolve
# ---------------------------------------------------------------------------
# Usage:
#   wi_manifest_resolve <ai-root> <string-with-vars>
#
# Resolves the four forms per SPEC §6.3, in this order:
#   1. ${ai_workspace.root}, ${canonical.root}  — manifest field refs
#   2. ${PLUGIN_DATA:<plugin-name>}             — cross-plugin data dir
#   3. ${HOME}, ${USER}                         — standard env vars
#
# Output: resolved string to stdout (no trailing newline manipulation beyond
# `echo`'s default).
#
# Returns 1 if the manifest is missing; 0 otherwise. Unresolved tokens are
# left in place (the caller can detect them by looking for `${`).
wi_manifest_resolve() {
  local ai_root="$1"
  local input="$2"
  local manifest
  manifest="$(_wi_manifest_path "$ai_root")"

  if [[ ! -f "$manifest" ]]; then
    wi_log_error "wi_manifest_resolve: manifest not found: $manifest"
    return 1
  fi

  local result="$input"

  # Form 1 — manifest field refs.
  local aw_root cn_root
  aw_root="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)"
  cn_root="$(jq -r '.canonical.root    // empty' "$manifest" 2>/dev/null)"
  if [[ -n "$aw_root" ]]; then
    result="$(_wi_splice_literal "$result" '${ai_workspace.root}' "$aw_root")"
  fi
  if [[ -n "$cn_root" ]]; then
    result="$(_wi_splice_literal "$result" '${canonical.root}' "$cn_root")"
  fi

  # Form 2 — ${PLUGIN_DATA:<name>}. Bash 3.2 supports BASH_REMATCH with [[ =~ ]].
  # Allow [a-zA-Z0-9_-] in plugin names (hyphens are common; underscores possible).
  # Bound the loop to avoid pathological inputs.
  local guard=0
  while [[ "$result" =~ \$\{PLUGIN_DATA:([a-zA-Z0-9_-]+)\} ]]; do
    local plugin="${BASH_REMATCH[1]}"
    local data_dir
    data_dir="$(wi_plugin_data_dir "$plugin")" || {
      wi_log_warn "wi_manifest_resolve: wi_plugin_data_dir failed for '$plugin'"
      # Replace with empty to avoid infinite loop.
      result="$(_wi_splice_literal "$result" "\${PLUGIN_DATA:${plugin}}" "")"
      continue
    }
    result="$(_wi_splice_literal "$result" "\${PLUGIN_DATA:${plugin}}" "$data_dir")"
    guard=$((guard + 1))
    if (( guard > 64 )); then
      wi_log_warn "wi_manifest_resolve: PLUGIN_DATA loop guard tripped (>64 substitutions)"
      break
    fi
  done

  # Form 3 — standard env vars. Limited set per SPEC §6.3 ("also supported").
  result="$(_wi_splice_literal "$result" '${HOME}' "$HOME")"
  # USER may be unset in minimal envs; fall back to id -un.
  local _user="${USER:-$(id -un 2>/dev/null)}"
  result="$(_wi_splice_literal "$result" '${USER}' "$_user")"

  echo "$result"
  return 0
}

# SPEC §6.3 refers to this resolver as `mi_manifest_resolve` (cross-plugin
# canonical name). Provided as an alias so consumers that follow the
# SPEC name verbatim find it without indirection.
mi_manifest_resolve() { wi_manifest_resolve "$@"; }

# ---------------------------------------------------------------------------
# wi_manifest_validate
# ---------------------------------------------------------------------------
# Usage:
#   wi_manifest_validate <ai-root>
#
# Checks:
#   - Manifest exists and is valid JSON
#   - schema_version is in WI_MANIFEST_SUPPORTED_VERSIONS
#   - All §6.4 "yes" required fields present, each with its schema type
#   - Roots, names and default_branch non-empty; routing selectors are
#     ai_workspace or canonical; well_known_paths entries are absolute path
#     templates using only the placeholders wi_manifest_resolve substitutes
#   - Every trace-filter rule the commit-msg hook fails closed on
#
# Returns 0 on valid, 1 with an error message to stderr otherwise. Error
# messages naming the manifest path so consumers can act on the message.
wi_manifest_validate() {
  local ai_root="$1"
  local manifest
  manifest="$(_wi_manifest_path "$ai_root")"

  if [[ ! -f "$manifest" ]]; then
    wi_log_error "wi_manifest_validate: manifest not found at $manifest"
    return 1
  fi

  # Must be valid JSON.
  if ! jq -e . "$manifest" >/dev/null 2>&1; then
    wi_log_error "wi_manifest_validate: $manifest is not valid JSON"
    return 1
  fi
  # ...and a JSON object: every field check below indexes into it, and jq
  # errors (rather than reporting a missing field) when indexing an array or
  # scalar.
  if ! jq -e 'type == "object"' "$manifest" >/dev/null 2>&1; then
    wi_log_error "wi_manifest_validate: $manifest is not a JSON object"
    return 1
  fi

  # schema_version.
  local v
  v="$(jq -r '.schema_version // empty' "$manifest" 2>/dev/null)" || v=""
  if [[ -z "$v" ]]; then
    wi_log_error "wi_manifest_validate: schema_version missing in $manifest"
    return 1
  fi
  # Membership test against comma-separated WI_MANIFEST_SUPPORTED_VERSIONS.
  local accepted=0
  local IFS=,
  local sv
  for sv in $WI_MANIFEST_SUPPORTED_VERSIONS; do
    if [[ "$sv" == "$v" ]]; then accepted=1; break; fi
  done
  unset IFS
  if (( accepted == 0 )); then
    wi_log_error "wi_manifest_validate: schema_version '$v' unsupported in $manifest (supported: $WI_MANIFEST_SUPPORTED_VERSIONS); update workspace-init"
    return 1
  fi

  # Required-field checks (per SPEC §6.4 table — "yes" rows).
  #
  # We use a single jq program for all presence checks; jq returns the
  # comma-separated names of any missing fields (or empty when all present).
  # The jq program's own exit status is checked: a required block of the wrong
  # type (e.g. "git_policy": "bad") makes an index inside it error, and an
  # unchecked capture would read that as "nothing missing" — a pass — or,
  # under the dispatcher's errexit, abort with no message.
  local missing
  if ! missing="$(jq -r '
    [
      (if has("schema_version")    then empty else "schema_version"    end),
      (if has("topology")          then empty else "topology"          end),
      (if .ai_workspace            != null then empty else "ai_workspace" end),
      (if .ai_workspace.root       != null then empty else "ai_workspace.root" end),
      (if .ai_workspace.name       != null then empty else "ai_workspace.name" end),
      (if .ai_workspace | has("git_tracked") then empty else "ai_workspace.git_tracked" end),
      (if .canonical               != null then empty else "canonical" end),
      (if .canonical.root          != null then empty else "canonical.root" end),
      (if .canonical.name          != null then empty else "canonical.name" end),
      (if .canonical | has("git_tracked")    then empty else "canonical.git_tracked" end),
      (if .canonical.default_branch != null then empty else "canonical.default_branch" end),
      # tooling_repo is OPTIONAL (#48 Stage 2); validate its sub-schema only when present.
      # Guard on object-type FIRST: a non-object value (e.g. a hand-edited string)
      # would make the .root/.name indexing throw, abort jq, and — with stderr
      # swallowed — let `missing` come back empty so an invalid manifest passes.
      (if (has("tooling_repo") and (.tooling_repo | type) != "object") then "tooling_repo (must be an object)" else empty end),
      (if (has("tooling_repo") and (.tooling_repo | type) == "object") then (if .tooling_repo.root != null then empty else "tooling_repo.root" end) else empty end),
      (if (has("tooling_repo") and (.tooling_repo | type) == "object") then (if .tooling_repo.name != null then empty else "tooling_repo.name" end) else empty end),
      (if .routing                 != null then empty else "routing" end),
      (if .routing.master_spec              != null then empty else "routing.master_spec" end),
      (if .routing.executive_summary        != null then empty else "routing.executive_summary" end),
      (if .routing.memory_bank              != null then empty else "routing.memory_bank" end),
      (if .routing.claude_md                != null then empty else "routing.claude_md" end),
      (if .routing.agents_md                != null then empty else "routing.agents_md" end),
      (if .routing.scaffold_project_outputs != null then empty else "routing.scaffold_project_outputs" end),
      (if .routing.backlog                  != null then empty else "routing.backlog" end),
      (if .routing.project_plan             != null then empty else "routing.project_plan" end),
      (if .routing.roadmap                  != null then empty else "routing.roadmap" end),
      (if .routing.prd                      != null then empty else "routing.prd" end),
      (if .routing.srs                      != null then empty else "routing.srs" end),
      (if .routing.product_adrs             != null then empty else "routing.product_adrs" end),
      (if .routing.process_adrs             != null then empty else "routing.process_adrs" end),
      (if .routing.sprint_specs             != null then empty else "routing.sprint_specs" end),
      (if .routing.implementation_handoffs  != null then empty else "routing.implementation_handoffs" end),
      (if .routing.brainstorm_artifacts     != null then empty else "routing.brainstorm_artifacts" end),
      (if .during_dev                       != null then empty else "during_dev" end),
      (if .during_dev.worktrees_dir         != null then empty else "during_dev.worktrees_dir" end),
      (if .during_dev.branch_naming         != null then empty else "during_dev.branch_naming" end),
      (if .during_dev.sprint_dir_template   != null then empty else "during_dev.sprint_dir_template" end),
      (if .during_dev.slice_spec_format     != null then empty else "during_dev.slice_spec_format" end),
      (if .git_policy                       != null then empty else "git_policy" end),
      (if .git_policy.project_type          != null then empty else "git_policy.project_type" end),
      (if .git_policy | has("allow_ai_local_commits") then empty else "git_policy.allow_ai_local_commits" end),
      (if .git_policy | has("allow_ai_local_merge")   then empty else "git_policy.allow_ai_local_merge"   end),
      (if .git_policy | has("allow_ai_local_rebase")  then empty else "git_policy.allow_ai_local_rebase"  end),
      (if .git_policy | has("allow_ai_fetch")         then empty else "git_policy.allow_ai_fetch"         end),
      (if .git_policy | has("allow_ai_push")          then empty else "git_policy.allow_ai_push"          end),
      (if .git_policy | has("allow_ai_pull")          then empty else "git_policy.allow_ai_pull"          end),
      (if .git_policy.trace_filter          != null then empty else "git_policy.trace_filter" end),
      (if .git_policy.trace_filter | has("enforce")          then empty else "git_policy.trace_filter.enforce" end),
      (if .git_policy.trace_filter | has("blocked_patterns") then empty else "git_policy.trace_filter.blocked_patterns" end),
      (if .created_at != null then empty else "created_at" end),
      (if .created_by != null then empty else "created_by" end)
    ] | join(", ")
  ' "$manifest" 2>/dev/null)"; then
    wi_log_error "wi_manifest_validate: $manifest has a required block of the wrong type; its required fields could not be checked"
    return 1
  fi

  if [[ -n "$missing" ]]; then
    wi_log_error "wi_manifest_validate: $manifest missing required fields: $missing"
    return 1
  fi

  # Every required leaf must also have its schema type — a present but
  # wrong-typed value ("canonical.root": 42) would otherwise validate and then
  # resolve as "42/..." downstream. One table covers the whole required set, so
  # the check is by type class, not by the field someone last tripped over.
  # Optional keys (the remotes, tooling_repo) are typed only when present.
  local bad_types
  if ! bad_types="$(jq -r '
    def want($path; $types):
      (getpath($path) | type) as $t
      | if ($types | index($t)) then empty
        else "\($path | join(".")) (must be \($types | join(" or ")), is \($t))" end;
    def opt($path; $types):
      if (getpath($path[0:-1]) | type) == "object" and (getpath($path[0:-1]) | has($path[-1]))
      then want($path; $types) else empty end;
    [
      ((["schema_version"], ["topology"], ["ai_workspace","root"], ["ai_workspace","name"],
        ["canonical","root"], ["canonical","name"], ["canonical","default_branch"],
        ["git_policy","project_type"], ["created_at"], ["created_by"])
         as $p | want($p; ["string"])),
      ((.routing | keys[] | ["routing", .]) as $p | want($p; ["string"])),
      ((["during_dev","worktrees_dir"], ["during_dev","branch_naming"],
        ["during_dev","sprint_dir_template"], ["during_dev","slice_spec_format"])
         as $p | want($p; ["string"])),
      ((["ai_workspace","git_tracked"], ["canonical","git_tracked"],
        ["git_policy","allow_ai_local_commits"], ["git_policy","allow_ai_local_merge"],
        ["git_policy","allow_ai_local_rebase"], ["git_policy","allow_ai_fetch"],
        ["git_policy","allow_ai_push"], ["git_policy","allow_ai_pull"])
         as $p | want($p; ["boolean"])),
      ((["ai_workspace","git_remote"], ["canonical","git_remote"])
         as $p | opt($p; ["string","null"])),
      (if has("tooling_repo") then
         ((["tooling_repo","root"], ["tooling_repo","name"]) as $p | want($p; ["string"])),
         (["tooling_repo","git_remote"] as $p | opt($p; ["string","null"]))
       else empty end),
      # well_known_paths is optional, but a present value is read as a path
      # (the retired scaffold-onboard read roadmap_state with `jq -r`), so every entry
      # must be a string: an object would be rendered as a path (#582).
      (if (.well_known_paths | type) == "object" then
         ((.well_known_paths | keys[] | ["well_known_paths", .]) as $p | want($p; ["string"]))
       else (["well_known_paths"] as $p | opt($p; ["object","null"])) end)
    ] | join(", ")
  ' "$manifest" 2>/dev/null)"; then
    wi_log_error "wi_manifest_validate: $manifest has a required block of the wrong type; its required fields could not be checked"
    return 1
  fi
  if [[ -n "$bad_types" ]]; then
    wi_log_error "wi_manifest_validate: $manifest has wrongly typed fields: $bad_types"
    return 1
  fi

  # Values, now that every type is known (#582). A string of the right type can
  # still be unusable: an empty root or name leaves ${canonical.root} unresolved
  # and consumers read it as missing, a relative root makes every template built
  # on it resolve against the reader's cwd, an empty well-known path names no file,
  # and a routing selector outside the two roots wi_manifest_resolve knows is
  # interpolated as ${<selector>.root} and used as a destination unresolved.
  local bad_values
  if ! bad_values="$(jq -r '
    def nonempty($path):
      if getpath($path) == "" then "\($path | join(".")) (must not be empty)" else empty end;
    def absroot($path):
      getpath($path) as $v
      | if $v == "" then "\($path | join(".")) (must not be empty)"
        elif ($v | startswith("/") | not)
        then "\($path | join(".")) (must be an absolute path, is \($v | tojson))"
        else empty end;
    [
      ((["ai_workspace","root"], ["canonical","root"]) as $p | absroot($p)),
      ((["ai_workspace","name"], ["canonical","name"], ["canonical","default_branch"])
         as $p | nonempty($p)),
      (if has("tooling_repo") then
         (["tooling_repo","root"] as $p | absroot($p)),
         (["tooling_repo","name"] as $p | nonempty($p))
       else empty end),
      (if (.well_known_paths | type) == "object" then
         ((.well_known_paths | keys[] | ["well_known_paths", .]) as $p | nonempty($p)),
         # README: absolute path templates. The value must resolve to an
         # absolute path, so it starts with "/" or with a placeholder that
         # expands to one (whatever follows it: ${HOME}.cache is absolute),
         # and once every placeholder wi_manifest_resolve substitutes is
         # removed, no "${" may be left: an unknown or unterminated one would
         # reach a consumer unresolved, and a relative value would resolve
         # against whatever cwd reads it.
         (.well_known_paths | to_entries[] | select(.value != "")
          | if (.value | test("^(/|\\$\\{(ai_workspace\\.root|canonical\\.root|HOME|PLUGIN_DATA:[a-zA-Z0-9_-]+)\\})") | not)
            then "well_known_paths.\(.key) (must be an absolute path template: start with / or ${ai_workspace.root}, ${canonical.root}, ${HOME} or ${PLUGIN_DATA:<name>}, is \(.value | tojson))"
            elif (.value
                  | gsub("\\$\\{(ai_workspace\\.root|canonical\\.root|HOME|USER|PLUGIN_DATA:[a-zA-Z0-9_-]+)\\}"; "")
                  | contains("${"))
            then "well_known_paths.\(.key) (has a placeholder wi_manifest_resolve does not substitute, is \(.value | tojson))"
            else empty end)
       else empty end),
      (.routing | to_entries[]
       | select(.value != "ai_workspace" and .value != "canonical")
       | "routing.\(.key) (must be ai_workspace or canonical, is \(.value | tojson))")
    ] | join(", ")
  ' "$manifest" 2>/dev/null)"; then
    wi_log_error "wi_manifest_validate: $manifest has a required block of the wrong type; its required fields could not be checked"
    return 1
  fi
  if [[ -n "$bad_values" ]]; then
    wi_log_error "wi_manifest_validate: $manifest has invalid values: $bad_values"
    return 1
  fi

  # The trace-filter policy leaves must have the types the commit-msg hook
  # requires — otherwise the manifest validates here and the hook then fails
  # closed on it. Same rules as the hook: enforce is a boolean; blocked_patterns
  # is an array of non-empty strings with no line break or NUL (#493).
  local bad_policy
  if ! bad_policy="$(jq -r '
    .git_policy.trace_filter as $tf
    | [
        (if ($tf.enforce | type) == "boolean" then empty
         else "git_policy.trace_filter.enforce (must be a boolean)" end),
        (if ($tf.blocked_patterns | type) != "array"
         then "git_policy.trace_filter.blocked_patterns (must be an array)"
         elif ($tf.blocked_patterns
               | all(type == "string" and . != "" and ((explode | any(. == 10 or . == 0)) | not)))
         then empty
         else "git_policy.trace_filter.blocked_patterns (entries must be non-empty single-line strings)" end)
      ] | join(", ")
  ' "$manifest" 2>/dev/null)"; then
    wi_log_error "wi_manifest_validate: $manifest has a required block of the wrong type; its required fields could not be checked"
    return 1
  fi
  if [[ -n "$bad_policy" ]]; then
    wi_log_error "wi_manifest_validate: $manifest has invalid values: $bad_policy"
    return 1
  fi
  # The last rule the hook applies: every pattern must be a valid extended
  # regex (grep -E exit 2 is an evaluation error, not "no match"). With this,
  # every policy check the hook fails closed on is also checked here.
  local pattern grc
  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    # `|| grc=$?`, not a bare call: grep exits 1 on the valid "no match"
    # path, which would abort the dispatcher's errexit.
    grc=0
    grep -E -e "$pattern" /dev/null >/dev/null 2>&1 || grc=$?
    if (( grc > 1 )); then
      wi_log_error "wi_manifest_validate: $manifest has invalid values: git_policy.trace_filter.blocked_patterns entry is not a valid extended regex: $pattern"
      return 1
    fi
  done < <(jq -r '.git_policy.trace_filter.blocked_patterns[]' "$manifest" 2>/dev/null)

  return 0
}
