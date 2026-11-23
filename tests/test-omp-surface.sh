#!/usr/bin/env bash
# OMP surface gate (spec B §5.1). Mechanical facts only, each with a planted-failure
# control: every check runs against the shipped tree (expect no findings) and against
# a fixture carrying one planted defect (expect exactly that one). A check whose
# control stays green is broken, not passing.
#
# Usage: bash tests/test-omp-surface.sh
# Deps:  bash 3.2+, jq, awk, git.
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OMP_FIVE="ossify merge-bar workspace-init remodel sage"
# The two mods (spec C): catalog entries equal their Claude entries; their text is not gated here.
OMP_MODS="seat-mods molt"
# Claude plugins also listed on OMP for an OMP top (spec D): catalog entries equal their Claude entries; text not gated.
OMP_SHARED="crew"
# Plugins that exist on OMP only: no Claude-catalog entry, no .claude-plugin/, versioned by package.json.
OMP_ONLY="omp-roles"
# Plugins whose text checks 2-4 enforce on the shipped tree. Widened per PR (spec B §4.4).
GATED_PLUGINS="$OMP_FIVE"
# The (a|b) alternation keeps this line from matching itself in check 5.
OLD_REF_RE='references/(handoff|work-pr)/'

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  not ok  %s\n' "$1"; }

fm_value() { # $1=file $2=key -> the frontmatter value, surrounding quotes removed
  awk -v k="$2" 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit}
    f && index($0, k":")==1 { v=substr($0, length(k)+2); sub(/^[ ]+/, "", v);
      if (v ~ /^".*"$/ || v ~ /^'"'"'.*'"'"'$/) v=substr(v, 2, length(v)-2); print v; exit }' "$1"
}

check_catalog() { # $1=root
  local r=$1 o="$1/.omp-plugin/marketplace.json" c="$1/.claude-plugin/marketplace.json" p v
  [ -f "$o" ] || { echo "catalog: .omp-plugin/marketplace.json missing"; return; }
  [ "$(jq -r '[.plugins[].name] | sort | join(" ")' "$o")" = "$(printf '%s\n' $OMP_FIVE $OMP_MODS $OMP_SHARED $OMP_ONLY | sort | paste -sd' ' -)" ] \
    || echo "catalog: lists $(jq -c '[.plugins[].name]' "$o"), want exactly the five, the two mods, the shared and the OMP-only plugins"
  jq -e --slurpfile c "$c" '.name == $c[0].name and .owner == $c[0].owner' "$o" >/dev/null \
    || echo "catalog: name/owner differ from the Claude catalog"
  for p in $OMP_FIVE $OMP_MODS $OMP_SHARED; do
    # The exact-list check owns missing entries; compare only entries that are present.
    jq -e --arg p "$p" '[.plugins[] | select(.name == $p)] | length == 0' "$o" >/dev/null && continue
    jq -e --arg p "$p" --slurpfile c "$c" \
      '[.plugins[] | select(.name == $p)] == [$c[0].plugins[] | select(.name == $p)]' "$o" >/dev/null \
      || echo "catalog: $p entry differs from the Claude catalog entry"
    v=$(jq -r --arg p "$p" '.plugins[] | select(.name == $p) | .version // empty' "$o")
    [ -z "$v" ] || [ "$v" = "$(jq -r .version "$r/$p/.claude-plugin/plugin.json")" ] \
      || echo "catalog: $p version $v differs from its plugin.json"
  done
  for p in $OMP_ONLY; do
    jq -e --arg p "$p" '[.plugins[] | select(.name == $p)] | length == 0' "$c" >/dev/null \
      || echo "catalog: $p must not be in the Claude catalog"
    jq -e '(.version // "") != ""' "$r/$p/package.json" >/dev/null 2>&1 \
      || echo "catalog: $p has no package.json version"
    [ ! -d "$r/$p/.claude-plugin" ] || echo "catalog: $p must not have .claude-plugin/"
  done
}

check_wrappers() { # $1=root $2=plugins
  local r=$1 p f x paths
  for p in $2; do for f in "$r/$p"/commands/*.md; do
    [ -f "$f" ] || continue
    paths=$(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^` )]*' "$f" | sed 's|^${CLAUDE_PLUGIN_ROOT}/||' | sort -u)
    [ -n "$paths" ] || { echo "wrapper: ${f#"$r"/} names no \${CLAUDE_PLUGIN_ROOT}/skills/<x>/SKILL.md"; continue; }
    for x in $paths; do
      case "$x" in
        skills/*/SKILL.md) x=${x#skills/}; x=${x%/SKILL.md}
          [ -f "$r/$p/skills/$x/SKILL.md" ] || echo "wrapper: ${f#"$r"/} points at missing skills/$x/SKILL.md"
          grep -Fq "skill://$x" "$f" || echo "wrapper: ${f#"$r"/} lacks skill://$x" ;;
        *) echo "wrapper: ${f#"$r"/} names a non-skill path $x" ;;
      esac
    done
  done; done
}

check_descriptions() { # $1=root $2=plugins
  local r=$1 p f d
  for p in $2; do for f in "$r/$p"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    [ "$(fm_value "$f" disable-model-invocation)" = "true" ] && continue
    d=$(fm_value "$f" description)
    case "$d" in "Use when "*) ;; *) echo "description: ${f#"$r"/} does not start with 'Use when'" ;; esac
  done; done
}

check_names() { # $1=root $2=plugins
  local r=$1 p f n
  for p in $2; do for f in "$r/$p"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    n=$(fm_value "$f" name); [ -n "$n" ] || n=$(basename "$(dirname "$f")")
    printf '%s\t%s\n' "$n" "${f#"$r"/}"
  done; done | sort | awk -F'\t' '$1==prev{print "name: " $1 " is used by " pf " and " $2} {prev=$1; pf=$2}'
}

check_paths() { # $1=root $2=plugins (the moved-reference half runs once any plugin is gated: PR 2 moves them)
  local r=$1
  if [ -n "$2" ]; then
    if git -C "$r" rev-parse --git-dir >/dev/null 2>&1; then
      git -C "$r" grep -lE "$OLD_REF_RE" -- . ':!CHANGELOG.md' ':!*/CHANGELOG.md' | sed 's|^|path: names a moved reference: |'
    else
      grep -rlE "$OLD_REF_RE" "$r" --exclude=CHANGELOG.md | sed "s|^$r/|path: names a moved reference: |"
    fi
  fi
  for p in "$r"/plugin.json "$r"/*/plugin.json; do
    [ -f "$p" ] && echo "path: root plugin.json present: ${p#"$r"/}"
  done
}

check_module() { # $1=root $2=plugins (spec B §5.1 check 6)
  local r=$1 p f
  for f in "$r"/*/omp/bin-path.ts; do
    [ -f "$f" ] || continue
    cmp -s "$f" "$r/omp/bin-path.ts" || echo "module: ${f#"$r"/} differs from omp/bin-path.ts"
  done
  for p in $2 $OMP_ONLY $OMP_SHARED; do   # OMP-only plugins are never in $2 but ship bin/ (omp-roles); crew ships one too (crew-run)
    if [ -d "$r/$p/bin" ] && [ ! -f "$r/$p/omp/bin-path.ts" ]; then echo "module: $p has bin/ but ships no omp/bin-path.ts"; fi
  done
}

check_verifier() { # $1=root $2=plugins; the verifier agent (#970): no task/ask/write, no hardcoded model, ossify's procedure and return
  local r=$1 f="$1/omp-roles/agents/verifier.md" k tools p found=false va="$1/ossify/agents/verifier-agent.md"
  [ -f "$f" ] || return 0
  tools=$(fm_value "$f" tools | tr '[:upper:]' '[:lower:]')
  for k in task ask write; do
    printf '%s\n' "$tools" | tr ',[]\"\047' '     ' | awk -v k="$k" '{for (i=1;i<=NF;i++) if ($i==k) found=1} END {exit !found}' \
      && echo "agent: omp-roles/agents/verifier.md grants $k"
  done
  [ -z "$(fm_value "$f" model)" ] || echo "agent: omp-roles/agents/verifier.md sets a model; it comes from config"
  grep -Fq 'skill://close/references/impl-check.md' "$f" || echo "agent: omp-roles/agents/verifier.md does not point at skill://close/references/impl-check.md"
  for p in $2; do [ -f "$r/$p/skills/close/references/impl-check.md" ] && found=true; done
  $found || echo "agent: omp-roles/agents/verifier.md points at impl-check.md, which no gated plugin ships"
  # One return contract in two files: the JSON lines must match ossify's verifier-agent.md exactly.
  [ -f "$va" ] || { echo "agent: ossify/agents/verifier-agent.md missing"; return 0; }
  [ -n "$(grep '^{"mode": "verified"' "$f")" ] && [ "$(grep '^{"mode":' "$f" | sort)" = "$(grep '^{"mode":' "$va" | sort)" ] \
    || echo "agent: omp-roles/agents/verifier.md return shape differs from ossify/agents/verifier-agent.md"
}

check_agents() { # $1=root $2=plugins whose skills may be autoloaded
  local r=$1 f k tools skill p found
  for k in implementer seat-reviewer verifier; do
    [ -f "$r/omp-roles/agents/$k.md" ] || echo "agent: omp-roles/agents/$k.md missing"
  done
  for f in "$r/omp-roles"/agents/*.md; do
    [ -f "$f" ] || continue
    for k in name description tools; do
      [ -n "$(fm_value "$f" "$k")" ] || echo "agent: ${f#"$r"/} lacks frontmatter $k"
    done
  done
  check_verifier "$r" "$2"
  f="$r/omp-roles/agents/implementer.md"
  [ -f "$f" ] || return 0
  tools=$(fm_value "$f" tools | tr '[:upper:]' '[:lower:]')
  for k in task ask; do
    printf '%s\n' "$tools" | tr ',[]\"\047' '     ' | awk -v k="$k" '{for (i=1;i<=NF;i++) if ($i==k) found=1} END {exit !found}' \
      && echo "agent: omp-roles/agents/implementer.md grants $k"
  done
  skill=$(fm_value "$f" autoloadSkills)
  # OMP's inline list must contain one bare skill name, never a plugin:name alias.
  if ! printf '%s\n' "$skill" | grep -Eq '^\[[[:space:]]*[a-zA-Z0-9_-]+[[:space:]]*\]$'; then
    echo "agent: omp-roles/agents/implementer.md autoloadSkills must contain one bare name"
    return 0
  fi
  skill=$(printf '%s' "$skill" | tr -d '[][:space:]')
  found=false
  for p in $2; do
    [ -f "$r/$p/skills/$skill/SKILL.md" ] && found=true
  done
  $found || echo "agent: omp-roles/agents/implementer.md autoloadSkills $skill is not a skill in a gated plugin"
}

# --- fixture: a minimal valid tree; each control plants one defect into a copy ---
WORK="$(mktemp -d "${TMPDIR:-/tmp}/omp-surface.XXXXXX")"; trap 'chmod -R u+rwx "$WORK"; rm -rf "$WORK"' EXIT
make_fixture() { # $1=dir
  local d=$1 p
  mkdir -p "$d/.claude-plugin" "$d/.omp-plugin"
  jq -n --arg names "$OMP_FIVE $OMP_MODS $OMP_SHARED" '{name:"m", owner:{name:"o"},
    plugins: (($names | split(" ")) | map({name:., source:("./"+.), description:"d", category:"c"}))}' \
    > "$d/.claude-plugin/marketplace.json"
  jq --arg only "$OMP_ONLY" '.plugins += (($only | split(" ")) | map({name:., source:("./"+.), description:"d", category:"c"}))' \
    "$d/.claude-plugin/marketplace.json" > "$d/.omp-plugin/marketplace.json"
  for p in $OMP_MODS; do
    mkdir -p "$d/$p/.claude-plugin"; printf '{"name":"%s","version":"1.0.0"}\n' "$p" > "$d/$p/.claude-plugin/plugin.json"
  done
  for p in $OMP_ONLY; do
    mkdir -p "$d/$p/bin" "$d/$p/omp"; printf '{"name":"%s","version":"0.1.0"}\n' "$p" > "$d/$p/package.json"
  done
  for p in $OMP_FIVE; do
    mkdir -p "$d/$p/.claude-plugin" "$d/$p/skills/$p-s" "$d/$p/commands"
    printf '{"name":"%s","version":"1.0.0"}\n' "$p" > "$d/$p/.claude-plugin/plugin.json"
    printf -- '---\nname: %s-s\ndescription: Use when testing — a fixture skill\n---\nBody.\n' "$p" > "$d/$p/skills/$p-s/SKILL.md"
    printf 'Read `${CLAUDE_PLUGIN_ROOT}/skills/%s-s/SKILL.md` (in OMP: `skill://%s-s`) end to end and follow it.\n' "$p" "$p" > "$d/$p/commands/c.md"
  done
  mkdir -p "$d/omp" "$d/ossify/bin" "$d/ossify/omp"
  printf 'export const VERSION = 1;\n' > "$d/omp/bin-path.ts"; cp "$d/omp/bin-path.ts" "$d/ossify/omp/"
  for p in $OMP_ONLY; do cp "$d/omp/bin-path.ts" "$d/$p/omp/"; done
  mkdir -p "$d/omp-roles/agents"
  printf -- '---\nname: implementer\ndescription: Execute one work item.\ntools: read, write, bash\nautoloadSkills: [ossify-s]\n---\nBody.\n' > "$d/omp-roles/agents/implementer.md"
  printf -- '---\nname: seat-reviewer\ndescription: Review a diff.\ntools: read, grep, glob, bash, write\n---\nBody.\n' > "$d/omp-roles/agents/seat-reviewer.md"
  mkdir -p "$d/ossify/agents" "$d/ossify/skills/close/references"
  printf 'impl-check\n' > "$d/ossify/skills/close/references/impl-check.md"
  printf -- '---\nname: verifier-agent\n---\n{"mode": "verified", "model": "m"}\n{"mode": "refused", "reason": "r"}\n' > "$d/ossify/agents/verifier-agent.md"
  printf -- '---\nname: verifier\ndescription: Judge a work item.\ntools: read, edit, bash, glob, grep\n---\nread skill://close/references/impl-check.md\n{"mode": "verified", "model": "m"}\n{"mode": "refused", "reason": "r"}\n' > "$d/omp-roles/agents/verifier.md"
}
findings() { # $1=root $2=plugins -> all findings of all checks
  check_catalog "$1"; check_wrappers "$1" "$2"; check_descriptions "$1" "$2"; check_names "$1" "$2"; check_paths "$1" "$2"; check_module "$1" "$2"
  check_agents "$1" "$2"
}
control() { # $1=label $2=expected finding prefix $3=planting command (run in the fixture dir)
  local d="$WORK/$1" out
  make_fixture "$d"; (cd "$d" && eval "$3")
  out=$(findings "$d" "$OMP_FIVE")
  if [ "$(printf '%s\n' "$out" | grep -c .)" -eq 1 ] && printf '%s' "$out" | grep -Fq "$2"; then pass "control $1 turns red"
  else fail "control $1: want exactly one '$2' finding, got: ${out:-<none>}"; fi
}

printf 'OMP surface gate\n'
make_fixture "$WORK/clean"
out=$(findings "$WORK/clean" "$OMP_FIVE"); [ -z "$out" ] && pass "clean fixture has no findings" || fail "clean fixture: $out"

# These consumers already fail closed: failed reads produce named findings.
# Keep the controls on fixture files, never on the shipped tree.
for scan in check_wrappers check_agents; do
  d="$WORK/read-control-$scan"; make_fixture "$d"
  case "$scan" in
    check_wrappers) f="$d/ossify/commands/c.md"; expected='wrapper: ossify/commands/c.md names no' ;;
    check_agents) f="$d/omp-roles/agents/seat-reviewer.md"; expected='agent: omp-roles/agents/seat-reviewer.md lacks frontmatter' ;;
  esac
  if [ "$(id -u)" -eq 0 ]; then
    printf '  SKIP %s unreadable-file control (uid 0 bypasses chmod 000)\n' "$scan"
  else
    chmod 000 "$f"
    out="$("$scan" "$d" "$OMP_FIVE" 2>/dev/null)"
    chmod 600 "$f"
    if printf '%s\n' "$out" | awk -v prefix="$expected" 'index($0, prefix)==1 { hit=1 } END { exit !hit }'; then
      pass "control $scan rejects an unreadable regular file by name"
    else
      fail "control $scan accepted an unreadable regular file: ${out:-<none>}"
    fi
  fi
  out="$("$scan" "$d" "$OMP_FIVE")"
  [ -z "$out" ] && pass "control $scan accepts the adjacent readable tree" \
    || fail "control $scan readable tree: $out"
done

control catalog-extra   "catalog: lists"            'jq ".plugins += [{name:\"extra\",source:\"./extra\",description:\"d\",category:\"c\"}]" .omp-plugin/marketplace.json > t && mv t .omp-plugin/marketplace.json'
# Adjacent controls: absence is the list finding; a present shared entry must still match Claude.
control catalog-shared-missing "catalog: lists" 'jq ".plugins |= map(select(.name != \"crew\"))" .omp-plugin/marketplace.json > t && mv t .omp-plugin/marketplace.json'
control catalog-shared-drift "catalog: crew entry" 'jq "(.plugins[] | select(.name==\"crew\") | .description) = \"x\"" .omp-plugin/marketplace.json > t && mv t .omp-plugin/marketplace.json'
control catalog-drift   "catalog: ossify entry"     'jq "(.plugins[] | select(.name==\"ossify\") | .description) = \"x\"" .omp-plugin/marketplace.json > t && mv t .omp-plugin/marketplace.json'
control catalog-version "catalog: ossify version"   'for c in .omp-plugin .claude-plugin; do jq "(.plugins[] | select(.name==\"ossify\")) += {version:\"9.9.9\"}" $c/marketplace.json > t && mv t $c/marketplace.json; done'
control omp-only-in-claude  "catalog: omp-roles must not be in the Claude catalog" 'jq ".plugins += [{\"name\":\"omp-roles\",\"source\":\"./omp-roles\"}]" .claude-plugin/marketplace.json > t && mv t .claude-plugin/marketplace.json'
control omp-only-no-pkg     "catalog: omp-roles has no package.json version"    'rm omp-roles/package.json'
control omp-only-claude-dir "catalog: omp-roles must not have .claude-plugin/"   'mkdir -p omp-roles/.claude-plugin'
control wrapper-ref     "names a non-skill path"    'printf "Read \`\${CLAUDE_PLUGIN_ROOT}/references/x.md\`\n" >> ossify/commands/c.md'
control wrapper-alias   "lacks skill://ossify-s"    'sed -i.bak "s|skill://ossify-s|skill://zz|" ossify/commands/c.md && rm ossify/commands/c.md.bak'
control wrapper-none    "names no"                  'printf "Invoke Skill(ossify:ossify-s).\n" > ossify/commands/c.md'
control description     "does not start with"       'sed -i.bak "s|^description: Use when testing|description: Tests|" ossify/skills/ossify-s/SKILL.md && rm ossify/skills/ossify-s/SKILL.md.bak'
control name-collision  "name: ossify-s is used by" 'mkdir -p merge-bar/skills/ossify-s && cp ossify/skills/ossify-s/SKILL.md merge-bar/skills/ossify-s/'
control old-ref         "names a moved reference"   'printf "see references/%s/loop.md\n" work-pr >> ossify/skills/ossify-s/SKILL.md'
control root-manifest   "root plugin.json present"  'printf "{}\n" > ossify/plugin.json'
control module-drift    "module: ossify/omp/bin-path.ts differs" 'printf "// drift\n" >> ossify/omp/bin-path.ts'
control module-missing  "module: ossify has bin/"   'rm ossify/omp/bin-path.ts'
control module-missing-omp-only "module: omp-roles has bin/" 'rm omp-roles/omp/bin-path.ts'
control module-missing-shared "module: crew has bin/ but ships no omp/bin-path.ts" 'mkdir -p crew/bin'
control agent-missing-implementer "agent: omp-roles/agents/implementer.md missing" 'rm omp-roles/agents/implementer.md'
control agent-missing-seat-reviewer "agent: omp-roles/agents/seat-reviewer.md missing" 'rm omp-roles/agents/seat-reviewer.md'
for key in name description tools; do
  control "agent-frontmatter-$key" "agent: omp-roles/agents/seat-reviewer.md lacks frontmatter $key" "sed -i.bak '/^$key:/d' omp-roles/agents/seat-reviewer.md && rm omp-roles/agents/seat-reviewer.md.bak"
done
control agent-missing-verifier "agent: omp-roles/agents/verifier.md missing" 'rm omp-roles/agents/verifier.md'
for tool in task ask write; do
  control "verifier-grants-$tool" "agent: omp-roles/agents/verifier.md grants $tool" "sed -i.bak 's/^tools: .*/tools: read, edit, $tool/' omp-roles/agents/verifier.md && rm omp-roles/agents/verifier.md.bak"
done
control verifier-grants-Task "agent: omp-roles/agents/verifier.md grants task" 'sed -i.bak "s/^tools: .*/tools: read, edit, Task/" omp-roles/agents/verifier.md && rm omp-roles/agents/verifier.md.bak'
control verifier-hardcoded-model "agent: omp-roles/agents/verifier.md sets a model" 'sed -i.bak "s/^tools: /model: some\/model\ntools: /" omp-roles/agents/verifier.md && rm omp-roles/agents/verifier.md.bak'
control verifier-no-pointer "does not point at skill://close/references/impl-check.md" 'sed -i.bak "s|skill://close/references/impl-check.md|nowhere|" omp-roles/agents/verifier.md && rm omp-roles/agents/verifier.md.bak'
control verifier-dangling-pointer "points at impl-check.md, which no gated plugin ships" 'rm ossify/skills/close/references/impl-check.md'
control verifier-return-drift "return shape differs" 'sed -i.bak "s/\"reason\": \"r\"/\"reason\": \"x\"/" omp-roles/agents/verifier.md && rm omp-roles/agents/verifier.md.bak'
control verifier-return-gone "return shape differs" 'sed -i.bak "/^{\"mode\"/d" omp-roles/agents/verifier.md && rm omp-roles/agents/verifier.md.bak'
for tool in task ask; do
  control "agent-tool-$tool" "agent: omp-roles/agents/implementer.md grants $tool" "sed -i.bak 's/^tools: .*/tools: read, $tool, write/' omp-roles/agents/implementer.md && rm omp-roles/agents/implementer.md.bak"
done
control agent-grants-Task "agent: omp-roles/agents/implementer.md grants task" 'sed -i.bak "s/^tools: .*/tools: read, Task, write/" omp-roles/agents/implementer.md && rm omp-roles/agents/implementer.md.bak'
control agent-grants-ASK "agent: omp-roles/agents/implementer.md grants ask" 'sed -i.bak "s/^tools: .*/tools: read, ASK, write/" omp-roles/agents/implementer.md && rm omp-roles/agents/implementer.md.bak'
control agent-autoload-missing "autoloadSkills must contain one bare name" 'sed -i.bak "/^autoloadSkills:/d" omp-roles/agents/implementer.md && rm omp-roles/agents/implementer.md.bak'
control agent-autoload-qualified "autoloadSkills must contain one bare name" 'sed -i.bak "s/\[ossify-s\]/[ossify:ossify-s]/" omp-roles/agents/implementer.md && rm omp-roles/agents/implementer.md.bak'
control agent-autoload-unknown "autoloadSkills missing-s is not a skill in a gated plugin" 'sed -i.bak "s/\[ossify-s\]/[missing-s]/" omp-roles/agents/implementer.md && rm omp-roles/agents/implementer.md.bak'
control agent-autoload-ungated "autoloadSkills mod-s is not a skill in a gated plugin" 'mkdir -p seat-mods/skills/mod-s && cp ossify/skills/ossify-s/SKILL.md seat-mods/skills/mod-s/ && sed -i.bak "s/\[ossify-s\]/[mod-s]/" omp-roles/agents/implementer.md && rm omp-roles/agents/implementer.md.bak'

# The shipped tree. Checks 2-4 apply only to GATED_PLUGINS; checks 1 and 5 always.
out=$(findings "$ROOT" "$GATED_PLUGINS")
if [ -z "$out" ]; then pass "shipped tree: no findings (gated: ${GATED_PLUGINS:-none})"
else printf '%s\n' "$out" | while IFS= read -r l; do printf '      %s\n' "$l"; done; fail "shipped tree has findings"; fi

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
