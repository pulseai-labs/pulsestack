#!/usr/bin/env bash
# Validate the Codex v0 dual-publishing contract.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE="$ROOT/.agents/plugins/marketplace.json"
CLAUDE_MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"
# seat-mods and molt are Claude Code mods (hooks.json "modules"); Codex has no mod runtime.
# baton ships a CLI, a launcher and a systemd timer, no skill: Codex has nothing to load.
DEFERRED_PLUGINS="seat-mods molt baton"

# THE INVENTORY IS THE FILESYSTEM, NOT A MARKETPLACE.
#
# Three rounds of findings landed on this derivation, and each fix moved the blind
# spot instead of closing it, because every source tried was itself a marketplace
# while the failure being caught is a marketplace omission. A hand list missed a
# plugin added to both marketplaces. Deriving from Codex missed one deleted from
# Codex. Comparing Claude against Codex missed one deleted from BOTH — the two
# agreed, and the plugin left every loop below with its manifests still on disk.
#
# The inventory is now the set of top-level directories carrying
# .claude-plugin/plugin.json. That file is the artifact a plugin cannot be
# installed without, not an index of artifacts, so the inventory cannot be
# shortened by editing a marketplace. Both marketplaces are CHECKED against it
# rather than trusted as it.
#
# What this still cannot see: deleting a whole plugin directory. Then the
# inventory, both marketplaces and both manifest sets agree on the smaller set and
# every assertion passes — correctly, since nothing in the repo claims that plugin
# exists any more. Catching that needs an expectation stored outside the tree,
# which is the hand-maintained list this shape exists to remove. A directory
# deletion is also a visible diff hunk, unlike the one-line marketplace edit above.
inventory=""
for _d in "$ROOT"/*/; do
  _n="$(basename "$_d")"
  [ -f "$_d.claude-plugin/plugin.json" ] || continue
  inventory="$inventory $_n"
done
INVENTORY="$(printf '%s\n' $inventory | sort | tr '\n' ' ')"

CLAUDE_PLUGINS="$(jq -r '[.plugins[].name] | sort | join(" ")' "$CLAUDE_MARKETPLACE" 2>/dev/null)"
CODEX_PLUGINS="$(jq -r '[.plugins[].name] | sort | join(" ")' "$MARKETPLACE" 2>/dev/null)"

# The expected Codex set is the inventory minus the declared exceptions.
expected=""
for _n in $INVENTORY; do
  case " $DEFERRED_PLUGINS " in *" $_n "*) continue ;; esac
  expected="$expected $_n"
done
EXPECTED_PLUGINS="$(printf '%s\n' $expected | sort | tr '\n' ' ')"
V0_PLUGINS="$EXPECTED_PLUGINS"

# Every top-level .codex-plugin manifest, so an extra one cannot hide either.
codex_manifests=""
for _d in "$ROOT"/*/; do
  _n="$(basename "$_d")"
  [ -f "$_d.codex-plugin/plugin.json" ] || continue
  codex_manifests="$codex_manifests $_n"
done
CODEX_MANIFESTS="$(printf '%s\n' $codex_manifests | sort | tr '\n' ' ')"

# set_diff <a> <b> — members of a absent from b. Bash 3.2: no arrays, no mapfile.
set_diff() {
  _out=""
  for _x in $1; do
    case " $2 " in *" $_x "*) ;; *) _out="$_out $_x" ;; esac
  done
  printf '%s' "$_out"
}

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  not ok  %s\n' "$1"; }

# An empty inventory would make every loop below iterate zero times and report
# ALL GREEN having checked nothing. Fail closed before any of them run.
if [[ -z "${INVENTORY// /}" ]]; then
  fail "plugin inventory derived from */.claude-plugin/plugin.json is non-empty"
  printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
  exit 1
fi
pass "plugin inventory derived from the filesystem ($(printf '%s' "$INVENTORY" | wc -w | tr -d ' ') plugins)"

# 1. Inventory vs the Claude marketplace, both directions. A plugin on disk and
#    unpublished never ships; one published without a manifest cannot install.
_m="$(set_diff "$INVENTORY" "$CLAUDE_PLUGINS")"
_e="$(set_diff "$CLAUDE_PLUGINS" "$INVENTORY")"
if [[ -z "$_m" ]]; then pass "every plugin on disk is in the Claude marketplace"
else fail "every plugin on disk is in the Claude marketplace" "absent from Claude:$_m"; fi
if [[ -z "$_e" ]]; then pass "the Claude marketplace publishes nothing that is not on disk"
else fail "the Claude marketplace publishes nothing that is not on disk" "no manifest for:$_e"; fi

# 2. Each declared exception must name a plugin that exists — a stale name would
#    silently shrink the expectation. Existence ONLY: group 4 owns manifests.
for deferred in $DEFERRED_PLUGINS; do
  case " $INVENTORY " in
    *" $deferred "*) pass "deferred exception '$deferred' names a plugin that exists" ;;
    *)               fail "deferred exception '$deferred' names a plugin that exists" "not in the inventory — stale exception" ;;
  esac
done

# 3. Expected set vs the Codex marketplace, both directions. Sole owner of Codex
#    marketplace membership, deferred plugins included.
_m="$(set_diff "$EXPECTED_PLUGINS" "$CODEX_PLUGINS")"
_e="$(set_diff "$CODEX_PLUGINS" "$EXPECTED_PLUGINS")"
if [[ -z "$_m" ]]; then pass "every expected plugin is published to the Codex marketplace"
else fail "every expected plugin is published to the Codex marketplace" "absent from Codex:$_m"; fi
if [[ -z "$_e" ]]; then pass "the Codex marketplace publishes nothing beyond the expected set"
else fail "the Codex marketplace publishes nothing beyond the expected set" "unexpected in Codex:$_e"; fi

# 4. Expected set vs the .codex-plugin manifests on disk, both directions. Sole
#    owner of manifest presence and extras, deferred plugins included.
_m="$(set_diff "$EXPECTED_PLUGINS" "$CODEX_MANIFESTS")"
_e="$(set_diff "$CODEX_MANIFESTS" "$EXPECTED_PLUGINS")"
if [[ -z "$_m" ]]; then pass "every expected plugin carries a .codex-plugin manifest"
else fail "every expected plugin carries a .codex-plugin manifest" "no manifest for:$_m"; fi
if [[ -z "$_e" ]]; then pass "no .codex-plugin manifest exists outside the expected set"
else fail "no .codex-plugin manifest exists outside the expected set" "unexpected manifest:$_e"; fi

json_get() {
  jq -r "$1" "$2" 2>/dev/null
}

assert_file() {
  if [[ -f "$1" ]]; then pass "$2"; else fail "$2"; fi
}

assert_jq() {
  local expr="$1"
  local file="$2"
  local label="$3"
  if jq -e "$expr" "$file" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

assert_jq_plugin() {
  local plugin="$1"
  local expr="$2"
  local file="$3"
  local label="$4"
  if jq -e --arg p "$plugin" "$expr" "$file" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

printf 'Codex dual-publish contract\n'

assert_file "$MARKETPLACE" "Codex marketplace exists at .agents/plugins/marketplace.json"

if [[ -f "$MARKETPLACE" ]]; then
  assert_jq '.name == "pulsestack-codex"' "$MARKETPLACE" "marketplace has Codex-specific name"
  assert_jq '.interface.displayName == "Claude Agent Scaffolding for Codex"' "$MARKETPLACE" "marketplace has display name"

  for plugin in $V0_PLUGINS; do
    assert_jq_plugin "$plugin" '.plugins[] | select(.name == $p)' "$MARKETPLACE" "marketplace includes $plugin"
    assert_jq_plugin "$plugin" '.plugins[] | select(.name == $p) | .policy.installation == "AVAILABLE"' "$MARKETPLACE" "$plugin installation policy is AVAILABLE"
    assert_jq_plugin "$plugin" '.plugins[] | select(.name == $p) | .policy.authentication == "ON_INSTALL"' "$MARKETPLACE" "$plugin auth policy is ON_INSTALL"
    assert_jq_plugin "$plugin" '.plugins[] | select(.name == $p) | .source.source == "local"' "$MARKETPLACE" "$plugin source is local"
    assert_jq_plugin "$plugin" '.plugins[] | select(.name == $p) | .source.path == ("./" + $p)' "$MARKETPLACE" "$plugin source path points to top-level plugin directory"
  done

fi

for plugin in $V0_PLUGINS; do
  manifest="$ROOT/$plugin/.codex-plugin/plugin.json"
  assert_file "$manifest" "$plugin Codex manifest exists"
  [[ -f "$manifest" ]] || continue

  assert_jq_plugin "$plugin" '.name == $p' "$manifest" "$plugin manifest name matches directory"
  assert_jq '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")' "$manifest" "$plugin manifest has semver version"
  # Codex manifest version MUST match the Claude manifest — a release bump that
  # touches only .claude-plugin/plugin.json leaves Codex installs on the old
  # version (scaffold-onboard drifted 0.3.3 → through 0.3.4/0.3.5 unnoticed
  # because nothing enforced parity). Guard against silent recurrence.
  claude_manifest="$ROOT/$plugin/.claude-plugin/plugin.json"
  cv="$(json_get '.version' "$claude_manifest")"
  xv="$(json_get '.version' "$manifest")"
  if [[ -n "$cv" && "$cv" == "$xv" ]]; then
    pass "$plugin codex manifest version ($xv) matches claude manifest"
  else
    fail "$plugin codex manifest version ($xv) != claude manifest ($cv)"
  fi
  assert_jq '.skills == "./skills/"' "$manifest" "$plugin manifest exposes skills"
  assert_jq '.interface.displayName | type == "string" and length > 0' "$manifest" "$plugin has displayName"
  assert_jq '.interface.shortDescription | type == "string" and length > 0' "$manifest" "$plugin has shortDescription"
  assert_jq '.interface.longDescription | type == "string" and length > 0' "$manifest" "$plugin has longDescription"
  assert_jq '.interface.developerName | type == "string" and length > 0' "$manifest" "$plugin has developerName"
  assert_jq '.interface.category | type == "string" and length > 0' "$manifest" "$plugin has interface category"
  assert_jq '.interface.capabilities | type == "array" and length > 0' "$manifest" "$plugin declares capabilities"
  assert_jq 'has("hooks") | not' "$manifest" "$plugin manifest omits unsupported hooks field"
  assert_jq 'has("apps") | not' "$manifest" "$plugin manifest omits apps unless .app.json exists"
  assert_jq 'has("mcpServers") | not' "$manifest" "$plugin manifest omits mcpServers unless .mcp.json exists"
done

# --- SKILL.md frontmatter must parse as valid YAML (issue #35) ---
# The repo dual-publishes SKILL.md to Claude Code AND Codex; Codex's loader
# (Ruby Psych) skips any skill whose frontmatter fails to parse. Unquoted
# description: values containing ': ' (colon-space) parse as a nested mapping
# and raise Psych::SyntaxError. Assert every published SKILL.md frontmatter
# block parses. This is a mechanical parse check, not semantic linting.
assert_yaml_frontmatter() {
  local file="$1" label="$2" fm ruby_bin
  # Resolve Ruby via PATH (works with version managers / non-/usr/bin installs, e.g. mise
  # in CI). Preflight Ruby + Psych so a missing toolchain fails loudly rather than masquerading
  # as a YAML parse error.
  ruby_bin="$(command -v ruby || true)"
  if [[ -z "$ruby_bin" ]] || ! "$ruby_bin" -e 'require "psych"' >/dev/null 2>&1; then
    fail "$label (ruby+Psych unavailable on PATH — cannot validate frontmatter)"
    return
  fi
  # Extract the frontmatter block: lines between the first '---' and the next '---'.
  fm="$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f{print}' "$file")"
  if [[ -z "$fm" ]]; then
    fail "$label (no frontmatter block found)"
    return
  fi
  if printf '%s\n' "$fm" | "$ruby_bin" -ryaml -e 'Psych.parse($stdin.read)' >/dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
  fi
}

# Keep discovery independently exercisable: a partial walk must not certify YAML.
skill_frontmatter_files() { # <skills root>
  local root="$1" files find_status
  if files="$(find "$root" -name SKILL.md)"; then
    :
  else
    find_status=$?
    printf 'SKILL.md frontmatter scan %s: find exited %s\n' "$root" "$find_status"
    return "$find_status"
  fi
  [ -n "$files" ] || return 0
  printf '%s\n' "$files" | sort
}

# A real unreadable subtree, not a stubbed find. Restore access even on early exit.
find_ctl="$(mktemp -d)"
trap 'chmod -R u+rwx "$find_ctl"; rm -rf "$find_ctl"' EXIT
mkdir -p "$find_ctl/locked"
printf '%s\n' '---' 'name: control' '---' > "$find_ctl/SKILL.md"
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP frontmatter find failure control: uid 0 can read chmod 000 directories\n'
else
  chmod 000 "$find_ctl/locked"
  ctl_status=0
  ctl_files="$(skill_frontmatter_files "$find_ctl" 2>&1)" || ctl_status=$?
  chmod 700 "$find_ctl/locked"
  if [ "$ctl_status" -ne 0 ] && printf '%s\n' "$ctl_files" | awk -v root="$find_ctl" '
      index($0, "SKILL.md frontmatter scan " root ": find exited ") && /find exited [1-9][0-9]*/ { found=1 }
      END { exit !found }'; then
    pass "control: frontmatter scan rejects an unreadable subtree by scan, root and status"
  else
    fail "control: frontmatter scan rejects an unreadable subtree by scan, root and status (rc=$ctl_status; $ctl_files)"
  fi
fi
ctl_status=0
ctl_files="$(skill_frontmatter_files "$find_ctl")" || ctl_status=$?
if [ "$ctl_status" -eq 0 ] && [ "$ctl_files" = "$find_ctl/SKILL.md" ]; then
  pass "control: frontmatter scan enumerates a readable tree"
else
  fail "control: frontmatter scan enumerates a readable tree (rc=$ctl_status; $ctl_files)"
fi
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP frontmatter unreadable-file control: uid 0 bypasses chmod 000\n'
else
  printf '%s\n' '---' 'description: invalid: YAML' '---' > "$find_ctl/locked/SKILL.md"
  chmod 000 "$find_ctl/locked/SKILL.md"
  ctl_status=0
  ctl_files="$(
    before_fail="$FAIL"; before_pass="$PASS"
    assert_yaml_frontmatter "$find_ctl/locked/SKILL.md" "control/locked SKILL.md frontmatter" 2>&1
    [ "$FAIL" -eq "$((before_fail + 1))" ] && [ "$PASS" -eq "$before_pass" ]
  )" || ctl_status=$?
  # The label carries no path, so the path reaches this output only through awk's own
  # open error: the substring check proves the consumer tried this file and failed on it.
  if [ "$ctl_status" -eq 0 ] && [[ "$ctl_files" == *"control/locked SKILL.md frontmatter"* ]] \
     && [[ "$ctl_files" == *"$find_ctl/locked/SKILL.md"* ]]; then
    pass "control: frontmatter consumer rejects an unreadable regular file by name"
  else
    fail "control: frontmatter consumer rejects an unreadable regular file by name (rc=$ctl_status; $ctl_files)"
  fi
  chmod 600 "$find_ctl/locked/SKILL.md"
  printf '%s\n' '---' 'name: control' '---' > "$find_ctl/locked/SKILL.md"
  ctl_status=0
  ctl_files="$(
    before_fail="$FAIL"; before_pass="$PASS"
    assert_yaml_frontmatter "$find_ctl/locked/SKILL.md" "$find_ctl/locked/SKILL.md" 2>&1
    [ "$FAIL" -eq "$before_fail" ] && [ "$PASS" -eq "$((before_pass + 1))" ]
  )" || ctl_status=$?
  if [ "$ctl_status" -eq 0 ]; then
    pass "control: frontmatter consumer accepts the adjacent readable valid file"
  else
    fail "control: frontmatter consumer accepts the adjacent readable valid file (rc=$ctl_status; $ctl_files)"
  fi
  rm "$find_ctl/locked/SKILL.md"
fi

for plugin in $V0_PLUGINS; do
  [[ -d "$ROOT/$plugin/skills" ]] || continue
  skill_status=0
  skill_files="$(skill_frontmatter_files "$ROOT/$plugin/skills")" || skill_status=$?
  if [ "$skill_status" -ne 0 ]; then
    fail "$skill_files"
    continue
  fi
  while IFS= read -r skill_md; do
    [ -n "$skill_md" ] || continue
    skill_name="$(basename "$(dirname "$skill_md")")"
    assert_yaml_frontmatter "$skill_md" "$plugin/$skill_name SKILL.md frontmatter parses as YAML"
  done <<< "$skill_files"
done

printf '\nPassed: %d  Failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
