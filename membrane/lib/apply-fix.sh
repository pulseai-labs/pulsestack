#!/usr/bin/env bash
# lib/apply-fix.sh — auto-fix orchestrator for membrane.
# Two-flag system (RULE_AUTO_FIXABLE + RULE_MECHANICALLY_FIXABLE) with
# 5-layer defense-in-depth per SPEC §9.2 (T2-H).
# Requires: lib/helpers.sh, lib/state.sh
# Bash 3.2+ compatible (macOS portability).

# ---------------------------------------------------------------------------
# Safe-write allowlist (SPEC §9.2)
# ---------------------------------------------------------------------------

# csa_apply_safe_write_allowlist — emit the 4 allowed relative paths, one per line.
csa_apply_safe_write_allowlist() {
  printf '.gitignore\n'
  printf 'CLAUDE.md\n'
  printf '.claude/settings.json\n'
  printf '.claude/settings.local.json\n'
}

# csa_apply_is_in_allowlist <relative_path>
# Exit 0 if path is in allowlist, 1 otherwise.
csa_apply_is_in_allowlist() {
  local rel_path="$1"
  local allowed
  while IFS= read -r allowed; do
    if [[ "$rel_path" == "$allowed" ]]; then
      return 0
    fi
  done < <(csa_apply_safe_write_allowlist)
  return 1
}

# ---------------------------------------------------------------------------
# ID resolution
# ---------------------------------------------------------------------------

# csa_apply_resolve_id <project_root> <id>
# If id starts with "FUID-" → echo as-is.
# Else treat as display_id: the registry entry seen in the latest recorded run whose last_display_id
# is the id (_csa_registry_resolve_display_id, lib/state.sh). An empty id matches nothing.
# Exit 1 if not found.
csa_apply_resolve_id() {
  local root="$1"
  local id="$2"

  if [[ "$id" == FUID-* ]]; then
    printf '%s\n' "$id"
    return 0
  fi

  # Treat as display_id: resolve via state.findings.
  local state_json; state_json="$(csa_state_read "$root")"
  local resolved; resolved="$(_csa_registry_resolve_display_id "$state_json" "$id")"

  if [[ -n "$resolved" ]]; then
    printf '%s\n' "$resolved"
    return 0
  fi

  printf 'ERROR: Could not resolve id %q to a finding_uid\n' "$id" >&2
  return 1
}

# ---------------------------------------------------------------------------
# Rule validation (Layer 1: re-source + re-check both flags)
# ---------------------------------------------------------------------------

# csa_apply_validate_rule <rule_file>
# Re-source in subshell, check RULE_AUTO_FIXABLE=="true" AND RULE_MECHANICALLY_FIXABLE=="true".
# Exit 0 if both true, 1 otherwise.
csa_apply_validate_rule() {
  local rule_file="$1"

  if [[ ! -f "$rule_file" ]]; then
    printf 'ERROR: Rule file not found: %s\n' "$rule_file" >&2
    return 1
  fi

  # Re-source in a subshell to avoid polluting current env.
  local auto mech
  auto="$(bash -c "source $(printf '%q' "$rule_file") 2>/dev/null; printf '%s' \"\${RULE_AUTO_FIXABLE:-false}\"")"
  mech="$(bash -c "source $(printf '%q' "$rule_file") 2>/dev/null; printf '%s' \"\${RULE_MECHANICALLY_FIXABLE:-false}\"")"

  if [[ "$auto" != "true" ]]; then
    printf 'ERROR: Rule %s has RULE_AUTO_FIXABLE="%s" — not in safe-write allowlist for auto-fix\n' \
      "$rule_file" "$auto" >&2
    return 1
  fi

  if [[ "$mech" != "true" ]]; then
    printf 'ERROR: Rule %s has RULE_MECHANICALLY_FIXABLE="%s" — requires human judgment\n' \
      "$rule_file" "$mech" >&2
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Target validation (Layers 2-4)
# ---------------------------------------------------------------------------

# csa_apply_validate_target <target_path> <project_root>
# Layer 2: verify relative path is in the safe-write allowlist.
# Layer 3: refuse symlinks at target path.
# Layer 4: refuse if csa_realpath resolves outside project root.
# Exit 0 if all pass, 1 otherwise.
csa_apply_validate_target() {
  local target_path="$1"
  local project_root="$2"

  # Compute relative path (strip leading project_root/ prefix).
  local rel_path="$target_path"
  # Normalize: if target is absolute under project_root, strip the prefix.
  local resolved_root; resolved_root="$(csa_realpath "$project_root")"
  if [[ "$target_path" == "$resolved_root/"* ]]; then
    rel_path="${target_path#$resolved_root/}"
  elif [[ "$target_path" == "$project_root/"* ]]; then
    rel_path="${target_path#$project_root/}"
  fi

  # Layer 2: check allowlist.
  if ! csa_apply_is_in_allowlist "$rel_path"; then
    printf 'ERROR: Target path %q is not in the safe-write allowlist\n' "$rel_path" >&2
    return 1
  fi

  # Build absolute target path for further checks.
  local abs_target
  if [[ "$target_path" == /* ]]; then
    abs_target="$target_path"
  else
    abs_target="$project_root/$target_path"
  fi

  # Layer 3: refuse symlinks.
  if [[ -L "$abs_target" ]]; then
    printf 'ERROR: Target path %q is a symlink — refusing to write through symlink\n' "$rel_path" >&2
    return 1
  fi

  # Layer 4: refuse path traversal outside project root.
  # Resolve both paths (use dirname if file doesn't exist yet).
  local resolved_target
  if [[ -e "$abs_target" ]]; then
    resolved_target="$(csa_realpath "$abs_target")"
  else
    # File doesn't exist yet: resolve the parent directory + basename.
    local parent; parent="$(dirname "$abs_target")"
    local base; base="$(basename "$abs_target")"
    local resolved_parent; resolved_parent="$(csa_realpath "$parent")"
    resolved_target="$resolved_parent/$base"
  fi

  if [[ -z "$resolved_root" || -z "$resolved_target" ]]; then
    printf 'ERROR: Could not resolve paths for traversal check\n' >&2
    return 1
  fi

  # Check that resolved_target starts with resolved_root/.
  if [[ "$resolved_target" != "$resolved_root/"* && "$resolved_target" != "$resolved_root" ]]; then
    printf 'ERROR: Target path %q resolves outside project root (traversal refused)\n' "$rel_path" >&2
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

# csa_apply_run <project_root> <finding_uid_or_display_id>
# Full orchestration with 5-layer defense-in-depth.
csa_apply_run() {
  local project_root="$1"
  local id_arg="$2"

  local state_file; state_file="$(csa_state_path "$project_root")"

  # 1. Resolve to finding_uid.
  local fuid
  if ! fuid="$(csa_apply_resolve_id "$project_root" "$id_arg")"; then
    printf 'ERROR: Finding not found: %q\n' "$id_arg" >&2
    return 1
  fi

  # 2. Read the registry entry (csa_registry); if missing, or not an object → refuse.
  local state_json; state_json="$(csa_state_read "$project_root")"
  local finding_json; finding_json="$(printf '%s' "$state_json" | jq -c \
    --arg fuid "$fuid" "$_CSA_JQ_REGISTRY"'csa_registry[$fuid] // empty' 2>/dev/null)"

  if [[ -z "$finding_json" ]]; then
    printf 'ERROR: Finding not found in state: %s\n' "$fuid" >&2
    return 1
  fi

  local rule_id; rule_id="$(printf '%s' "$finding_json" | jq -r '.rule_id // empty')"
  local display_id; display_id="$(printf '%s' "$finding_json" | jq -r '.last_display_id // empty')"
  local target_rel; target_rel="$(printf '%s' "$finding_json" | jq -r '.file // empty')"
  local rule_path; rule_path="$(printf '%s' "$finding_json" | jq -r '.rule_path // empty')"

  # 7-double-apply guard: scan applied_fixes for a prior success entry.
  local prior_success; prior_success="$(printf '%s' "$state_json" | jq -r \
    --arg fuid "$fuid" \
    '[.applied_fixes[] | select(.finding_uid == $fuid and (.status == null or .status != "failed"))] | length' \
    2>/dev/null)"
  if [[ -n "$prior_success" && "$prior_success" -gt 0 ]]; then
    printf 'ERROR: Finding %s has already been applied (status != failed). Refusing duplicate apply.\n' "$fuid" >&2
    return 1
  fi

  # 3. Locate rule file.
  if [[ -z "$rule_path" || ! -f "$rule_path" ]]; then
    # Fallback: find by rule_id in CSA_RULES_DIR.
    local rules_dir="${CSA_RULES_DIR:-$CSA_LIB_DIR/rules}"
    rule_path="$(find "$rules_dir" -name "${rule_id}.sh" -type f 2>/dev/null | head -1)"
    if [[ -z "$rule_path" ]]; then
      printf 'ERROR: Rule file not found for rule_id=%s\n' "$rule_id" >&2
      return 1
    fi
  fi

  # 4. Layer 1: Validate rule (re-source, re-check both flags).
  if ! csa_apply_validate_rule "$rule_path"; then
    return 1
  fi

  # 5. Determine target path.
  if [[ -z "$target_rel" ]]; then
    printf 'ERROR: Finding %s has no file field\n' "$fuid" >&2
    return 1
  fi

  local target_abs
  if [[ "$target_rel" == /* ]]; then
    target_abs="$target_rel"
  else
    target_abs="$project_root/$target_rel"
  fi

  # 6. Layers 2-4: Validate target (allowlist + symlink + traversal).
  if ! csa_apply_validate_target "$target_rel" "$project_root"; then
    return 1
  fi

  # 8. Layer 5: Log to state.applied_fixes BEFORE the write.
  local rule_summary; rule_summary="${rule_id}: auto-fix applied"
  local applied_by="${USER:-unknown}"
  local now; now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Append a pending entry; we will mark failed if fix() returns non-zero.
  local tmp; tmp="$(dirname "$state_file")/state.json.tmp.$$"
  jq \
    --arg fuid "$fuid" \
    --arg did "$display_id" \
    --arg rid "$rule_id" \
    --arg by "$applied_by" \
    --arg summary "$rule_summary" \
    --arg now "$now" \
    '.applied_fixes += [{
      finding_uid: $fuid,
      display_id_at_apply: $did,
      rule_id: $rid,
      applied_at: $now,
      applied_by: $by,
      summary: $summary,
      status: "applied"
    }]' \
    "$state_file" > "$tmp" && mv "$tmp" "$state_file"

  # 9. Re-source rule; call fix() function.
  # We source the rule in a subshell that calls fix() and captures exit code.
  local fix_ec=0
  (
    # shellcheck disable=SC1090
    source "$rule_path" 2>/dev/null
    if ! declare -f fix >/dev/null 2>&1; then
      printf 'ERROR: Rule %s does not define a fix() function\n' "$rule_path" >&2
      exit 1
    fi
    fix "$target_abs" "$finding_json"
  )
  fix_ec=$?

  if [[ "$fix_ec" -ne 0 ]]; then
    # Update the applied_fixes entry we just wrote to status="failed".
    local state_file2; state_file2="$(csa_state_path "$project_root")"
    local tmp2; tmp2="$(dirname "$state_file2")/state.json.tmp.$$"
    jq \
      --arg fuid "$fuid" \
      --arg now "$now" \
      '(.applied_fixes | map(
        if .finding_uid == $fuid and .applied_at == $now then
          .status = "failed"
        else . end
      )) as $fixed |
      .applied_fixes = $fixed' \
      "$state_file2" > "$tmp2" && mv "$tmp2" "$state_file2"
    printf 'ERROR: fix() failed for %s (%s)\n' "$display_id" "$fuid" >&2
    return 1
  fi

  printf 'Applied %s (%s): %s\n' "$display_id" "$fuid" "$rule_summary"
  return 0
}
