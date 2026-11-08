#!/usr/bin/env bash
# lib/baseline.sh — NEW/PERSISTED tagging for membrane.
# Requires: lib/helpers.sh, lib/state.sh
# Bash 3.2+ compatible (macOS portability).

# csa_baseline_tag <findings_jsonl_file> <project_root>
# Read findings_jsonl_file (one JSON object per line).
# For each finding, look up its finding_uid in state.json's registry (csa_registry, lib/state.sh:
# an entry that is not an object is not there).
# If present: augment with {state: "PERSISTED", first_seen: <from_state>}
# Else: augment with {state: "NEW"}
# Emit augmented findings JSONL on stdout.
csa_baseline_tag() {
  local findings_file="$1"
  local root="$2"
  local state_json; state_json="$(csa_state_read "$root")"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local fuid; fuid="$(printf '%s' "$line" | jq -r '.finding_uid // empty')"
    if [[ -z "$fuid" ]]; then
      printf '%s\n' "$line" | jq -c '. + {state: "NEW"}'
      continue
    fi
    local persisted; persisted="$(printf '%s' "$state_json" | jq -c --arg k "$fuid" "$_CSA_JQ_REGISTRY"'csa_registry[$k] // null')"
    if [[ "$persisted" == "null" ]]; then
      printf '%s\n' "$line" | jq -c '. + {state: "NEW"}'
    else
      local first_seen; first_seen="$(printf '%s' "$persisted" | jq -r '.first_seen // ""')"
      printf '%s\n' "$line" | jq -c --arg fs "$first_seen" '. + {state: "PERSISTED", first_seen: $fs}'
    fi
  done < "$findings_file"
}
