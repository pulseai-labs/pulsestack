#!/usr/bin/env bash
# lib/stubs.sh — render 2 top-level stub files for AI workspace root.
# Per SPEC §8.6/§8.7: AGENTS.md (the one instruction file), README.md
#
# All filesystem operations append TAB-separated entries to
# <ai-root>/.workspace/init-log so Phase 3g rollback can replay them in reverse.
#
# Requires: lib/_helpers.sh (wi_log_*, wi_log_op, wi_render_template)
#           lib/manifest.sh (wi_manifest_read)
# Bash 3.2+ compatible (stock macOS).

set -u

if ! declare -F wi_log_op >/dev/null 2>&1; then
  source "$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_helpers.sh"
fi

if ! declare -F wi_manifest_read >/dev/null 2>&1; then
  source "$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)/manifest.sh"
fi

# Internal: derive the init-log path from the AI workspace root.
_wi_stubs_log() {
  local ai_root="$1"
  echo "${ai_root}/.workspace/init-log"
}

# Internal: append a log entry only if no existing line has the exact
# `OP\tPATH` prefix. Keeps the init-log de-duplicated across idempotent reruns.
_wi_stubs_log_once() {
  local log="$1"
  local op="$2"
  local target_path="$3"
  # #834: ENVIRON preserves backslashes that awk -v would interpret.
  if [[ -f "$log" ]] && WI_LOG_OP="$op" WI_LOG_PATH="$target_path" awk -F '\t' '
    $1 == ENVIRON["WI_LOG_OP"] && $2 == ENVIRON["WI_LOG_PATH"] { found = 1 }
    END { exit !found }' "$log" 2>/dev/null; then
    return 0
  fi
  wi_log_op "$log" "$op" "$target_path"
}

# wi_stub_agents_md <ai-root> [<project-name>]
#
# Renders AGENTS.md stub from template, substituting ${PROJECT_NAME} and
# ${CANONICAL_NAME}. If <project-name> is omitted, reads it from manifest
# (ai_workspace.name). Logs WRITE_FILE to init-log. The canonical is named,
# not located: an absolute root in an instruction file is true on one host
# only (#983); the stub points at canonical.root in the manifest instead.
#
# Returns 0 on success, 1 on failure.
wi_stub_agents_md() {
  local ai_root="$1"
  local project_name="${2:-}"

  if [[ ! -d "$ai_root" ]]; then
    wi_log_error "wi_stub_agents_md: ai_root does not exist: $ai_root"
    return 1
  fi

  # If project_name not provided, read from manifest.
  if [[ -z "$project_name" ]]; then
    project_name="$(wi_manifest_read "$ai_root" '.ai_workspace.name' 2>/dev/null)" || {
      wi_log_error "wi_stub_agents_md: failed to read ai_workspace.name from manifest"
      return 1
    }
  fi

  # Read canonical.name from manifest.
  local canonical_name
  canonical_name="$(wi_manifest_read "$ai_root" '.canonical.name' 2>/dev/null)" || {
    wi_log_error "wi_stub_agents_md: failed to read canonical.name from manifest"
    return 1
  }

  local tmpl="${WI_TEMPLATES_DIR:-$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates}/AGENTS.md.stub.tmpl"
  local out="${ai_root}/AGENTS.md"

  if [[ ! -f "$tmpl" ]]; then
    wi_log_error "wi_stub_agents_md: template not found: $tmpl"
    return 1
  fi

  # Render template with substitutions.
  if ! wi_render_template "$tmpl" "$out" \
      "PROJECT_NAME=$project_name" \
      "CANONICAL_NAME=$canonical_name"; then
    wi_log_error "wi_stub_agents_md: template render failed"
    return 1
  fi

  # Log the write.
  local log
  log="$(_wi_stubs_log "$ai_root")"
  _wi_stubs_log_once "$log" WRITE_FILE "$out"

  return 0
}

# wi_stub_readme <ai-root> <project-name>
#
# Renders README.md stub from template, substituting ${PROJECT_NAME} and
# ${CANONICAL_NAME}. Reads canonical.name from manifest (assumes manifest
# exists and is valid). Logs WRITE_FILE to init-log.
#
# Returns 0 on success, 1 on failure.
wi_stub_readme() {
  local ai_root="$1"
  local project_name="$2"

  if [[ ! -d "$ai_root" ]]; then
    wi_log_error "wi_stub_readme: ai_root does not exist: $ai_root"
    return 1
  fi

  # Read canonical.name from manifest.
  local canonical_name
  canonical_name="$(wi_manifest_read "$ai_root" '.canonical.name' 2>/dev/null)" || {
    wi_log_error "wi_stub_readme: failed to read canonical.name from manifest"
    return 1
  }

  local tmpl="${WI_TEMPLATES_DIR:-$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates}/README.md.tmpl"
  local out="${ai_root}/README.md"

  if [[ ! -f "$tmpl" ]]; then
    wi_log_error "wi_stub_readme: template not found: $tmpl"
    return 1
  fi

  # Render template with substitutions.
  if ! wi_render_template "$tmpl" "$out" \
      "PROJECT_NAME=$project_name" \
      "CANONICAL_NAME=$canonical_name"; then
    wi_log_error "wi_stub_readme: template render failed"
    return 1
  fi

  # Log the write.
  local log
  log="$(_wi_stubs_log "$ai_root")"
  _wi_stubs_log_once "$log" WRITE_FILE "$out"

  return 0
}
