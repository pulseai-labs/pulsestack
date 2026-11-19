#!/usr/bin/env bash
#
# sage — frontmatter lint (v2.0 contract)
#
# Asserts each skills/*/SKILL.md complies with the v2.0 Anthropic-canonical
# frontmatter convention (SPEC-ai-mentor-v2.md §4):
#
#   - YAML frontmatter fenced by ---
#   - Exactly 2 fields: `name` and `description`
#   - NO `version` field
#   - NO `when_to_use` field
#   - `description` value ≤1024 chars
#   - `name` is kebab-case (lowercase letters, digits, hyphens; no leading hyphen)
#
# Usage:   bash sage/tests/test-frontmatter-lint.sh
# Exit:    0 if every skill passes every check; 1 if any check fails.
# Deps:    bash 3.2+ (no GNU-isms), awk. No jq, no yq required.
#
# RED-state note (Phase 1, sage v2.0):
#   This test currently FAILS for skills/grill-me/SKILL.md because the v1.3
#   body still ships `when_to_use:` and `version:` lines. Phase 2 makes it pass.

set -u  # we manage failures explicitly via counters; do not `set -e`

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$PLUGIN_ROOT/skills"

PASS=0
FAIL=0
FAILED=()

# ── color helpers (degrade to plain if not a tty) ──────────────────────────
if [ -t 1 ]; then
  GREEN=$(printf '\033[32m'); RED=$(printf '\033[31m'); DIM=$(printf '\033[2m'); RST=$(printf '\033[0m')
else
  GREEN=""; RED=""; DIM=""; RST=""
fi

pass() { PASS=$((PASS+1)); printf '  %s✓%s %s\n' "$GREEN" "$RST" "$1"; }
fail() {
  FAIL=$((FAIL+1)); FAILED=("${FAILED[@]:-}" "$1")
  printf '  %s✗%s %s\n' "$RED" "$RST" "$1"
  [ -n "${2:-}" ] && printf '      %s%s%s\n' "$DIM" "$2" "$RST"
}

# Extract the YAML frontmatter block (between the first two `---` lines) from
# a file. Prints nothing if no valid frontmatter. POSIX-friendly awk.
extract_frontmatter() {
  awk '
    BEGIN { state = 0 }
    /^---[[:space:]]*$/ {
      if (state == 0) { state = 1; next }
      else if (state == 1) { state = 2; exit }
    }
    state == 1 { print }
  ' "$1"
}

# Extract just the key names (left of the first colon) from frontmatter. One per line.
# Skips blank lines and comment lines. Does NOT handle nested YAML (we expect flat).
extract_keys() {
  printf '%s\n' "$1" | awk -F: '
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    NF >= 2 {
      key = $1
      sub(/^[[:space:]]+/, "", key)
      sub(/[[:space:]]+$/, "", key)
      if (key != "") print key
    }
  '
}

# Extract the raw value of a given key from frontmatter. Returns the value as
# a single line (rest-of-line after the first colon). Does NOT handle multi-line
# YAML scalars — flat single-line values only, which is our convention.
extract_value() {
  fm="$1"; key="$2"
  printf '%s\n' "$fm" | awk -v k="$key" -F: '
    {
      # split on the FIRST colon only
      idx = index($0, ":")
      if (idx == 0) next
      this_key = substr($0, 1, idx - 1)
      this_val = substr($0, idx + 1)
      sub(/^[[:space:]]+/, "", this_key)
      sub(/[[:space:]]+$/, "", this_key)
      if (this_key == k) {
        sub(/^[[:space:]]+/, "", this_val)
        sub(/[[:space:]]+$/, "", this_val)
        print this_val
        exit
      }
    }
  '
}

# Check a name value is kebab-case: lowercase letters, digits, hyphens; no leading/trailing hyphen.
is_kebab_case() {
  case "$1" in
    "" ) return 1 ;;
    -*|*-) return 1 ;;
    *[!a-z0-9-]* ) return 1 ;;
    *) return 0 ;;
  esac
}

# ── per-skill assertions ───────────────────────────────────────────────────
check_skill() {
  skill_md="$1"
  skill_name="$(basename "$(dirname "$skill_md")")"
  rel_path="skills/$skill_name/SKILL.md"

  printf '\n%s%s%s\n' "$DIM" "── $rel_path ──" "$RST"

  if [ ! -f "$skill_md" ]; then
    fail "$rel_path: file exists" "no file at $skill_md"
    return
  fi

  fm="$(extract_frontmatter "$skill_md")"
  if [ -z "$fm" ]; then
    fail "$rel_path: has YAML frontmatter fenced by ---" "no frontmatter block found"
    return
  fi
  pass "$rel_path: has YAML frontmatter fenced by ---"

  keys="$(extract_keys "$fm")"
  key_count=$(printf '%s\n' "$keys" | awk 'NF' | wc -l | awk '{print $1}')

  # Required keys present
  has_name=$(printf '%s\n' "$keys" | awk '$0=="name"' | wc -l | awk '{print $1}')
  has_desc=$(printf '%s\n' "$keys" | awk '$0=="description"' | wc -l | awk '{print $1}')
  if [ "$has_name" -ge 1 ]; then pass "$rel_path: has 'name' field"; else fail "$rel_path: has 'name' field" "missing"; fi
  if [ "$has_desc" -ge 1 ]; then pass "$rel_path: has 'description' field"; else fail "$rel_path: has 'description' field" "missing"; fi

  # Banned keys absent
  has_ver=$(printf '%s\n' "$keys" | awk '$0=="version"' | wc -l | awk '{print $1}')
  has_wtu=$(printf '%s\n' "$keys" | awk '$0=="when_to_use"' | wc -l | awk '{print $1}')
  if [ "$has_ver" -eq 0 ]; then pass "$rel_path: no 'version' field"; else fail "$rel_path: no 'version' field" "found banned key 'version' (non-standard per SPEC §4)"; fi
  if [ "$has_wtu" -eq 0 ]; then pass "$rel_path: no 'when_to_use' field"; else fail "$rel_path: no 'when_to_use' field" "found banned key 'when_to_use' (non-standard per SPEC §4; fold into description)"; fi

  # Exactly 2 keys total
  if [ "$key_count" -eq 2 ]; then
    pass "$rel_path: exactly 2 frontmatter fields"
  else
    extras=$(printf '%s\n' "$keys" | awk 'NF && $0!="name" && $0!="description"' | tr '\n' ',' | sed 's/,$//')
    fail "$rel_path: exactly 2 frontmatter fields" "found $key_count fields; extras: [$extras]"
  fi

  # name kebab-case
  name_val="$(extract_value "$fm" name)"
  if is_kebab_case "$name_val"; then
    pass "$rel_path: 'name' is kebab-case ('$name_val')"
  else
    fail "$rel_path: 'name' is kebab-case" "name='$name_val' (expected lowercase letters/digits/hyphens, no leading/trailing hyphen)"
  fi

  # name matches directory name (sanity)
  if [ "$name_val" = "$skill_name" ]; then
    pass "$rel_path: 'name' matches directory ('$skill_name')"
  else
    fail "$rel_path: 'name' matches directory" "directory='$skill_name' but name='$name_val'"
  fi

  # description length ≤1024 chars
  desc_val="$(extract_value "$fm" description)"
  desc_len=$(printf '%s' "$desc_val" | awk '{ total += length($0) } END { print total+0 }')
  if [ "$desc_len" -le 1024 ] && [ "$desc_len" -gt 0 ]; then
    pass "$rel_path: 'description' length ${desc_len}/1024 chars"
  elif [ "$desc_len" -eq 0 ]; then
    fail "$rel_path: 'description' is non-empty" "description is empty"
  else
    fail "$rel_path: 'description' length ≤1024 chars" "actual=${desc_len} chars (over by $((desc_len-1024)))"
  fi
}

# ── main ────────────────────────────────────────────────────────────────────
printf '%ssage frontmatter lint — v2.0 contract%s\n' "$DIM" "$RST"
printf '%sskills dir: %s%s\n' "$DIM" "$SKILLS_DIR" "$RST"

if [ ! -d "$SKILLS_DIR" ]; then
  printf '%s✗%s skills directory missing at %s\n' "$RED" "$RST" "$SKILLS_DIR"
  exit 1
fi

# Iterate skills/*/SKILL.md (POSIX glob, no GNU-isms)
found_any=0
for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  [ -e "$skill_md" ] || continue
  found_any=1
  check_skill "$skill_md"
done

if [ "$found_any" -eq 0 ]; then
  printf '\n%s✗%s no skills found under %s/*/SKILL.md\n' "$RED" "$RST" "$SKILLS_DIR"
  exit 1
fi

# ── shipped README links stay inside the plugin (#146) ───────────────────
# Repo-root docs/ does not ship with /plugin install, so a `](../docs/` link in
# the README is dead for every installed copy. CHANGELOG history keeps its citations.
if grep -n '](\.\./' "$PLUGIN_ROOT/README.md" >/dev/null; then
  fail "README.md links outside the plugin: $(grep -n '](\.\./' "$PLUGIN_ROOT/README.md" | cut -c1-80)"
else
  pass "README.md has no link outside the plugin (#146)"
fi

# ── summary ────────────────────────────────────────────────────────────────
printf '\n%s──────────────────────────────────────%s\n' "$DIM" "$RST"
printf 'Passed: %s%d%s   Failed: %s%d%s\n' "$GREEN" "$PASS" "$RST" "$RED" "$FAIL" "$RST"

if [ "$FAIL" -gt 0 ]; then
  printf '\n%sFailing checks:%s\n' "$RED" "$RST"
  for f in "${FAILED[@]}"; do
    [ -n "$f" ] && printf '  - %s\n' "$f"
  done
  exit 1
fi

exit 0
