#!/usr/bin/env bash
#
# crew — briefs go by file, mechanical facts only (#752).
#
# A brief is free text. As a shell argument the shell can word-split it, glob it or run what it
# holds, and a quoting slip in a long brief is easy to make and hard to see. So the layer files
# send a brief by file: the orchestrator writes it under the run's scratch directory and types
# one fixed line, `Read <path> and follow it.`, whose only variable part is a path the
# orchestrator itself made.
#
# Facts:
#   1. no line of SKILL.md, a shared reference or a layer file shows a send command
#      (`herdr agent prompt`, `herdr pane run`, `orca terminal send`) whose argument is a brief
#      placeholder — `<brief>`, `<the brief>`, `<brief text>`. A command whose line ends in a
#      backslash is read together with the next line;
#   2. each layer file shows the fixed pointer line as its send's argument, exactly once.
#
# What this does not claim: the check reads the shipped text, so a send written in words, or a
# placeholder on a line after a command with no continuation backslash, is not seen. It only
# adds a stop. A seat with `host:` on another machine keeps `brief_delivery: inject` (a known
# limit, `config.md`); the layer files describe that in words and show no placeholder for it.
#
# Usage:   bash crew/tests/test-brief-by-file.sh
# Exit:    0 if every fact holds; 1 otherwise.
# Deps:    bash 3.2+, awk, cp, mktemp.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORCH="$PLUGIN_ROOT/skills/orchestrate"
HERDR_MD="$ORCH/references/layers/herdr.md"
ORCA_MD="$ORCH/references/layers/orca.md"

# shellcheck source=/dev/null
. "$SCRIPT_DIR/_helpers.sh"

# One line per violation, `<file>:<line>`, reading the skill directory <dir> (SKILL.md,
# references/*.md, references/layers/*.md). A directory, not the real tree, so the controls
# below run the same predicate over a fixture.
inline_brief_findings() { # <skills/orchestrate dir>
  local dir="$1" f
  for f in "$dir"/SKILL.md "$dir"/references/*.md "$dir"/references/layers/*.md; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
      printf 'SCAN-ERROR inline_brief_findings %s: not a readable regular file\n' "$f"
      continue
    fi
    awk -v name="${f#"$dir"/}" '
      function bad(s) { return s ~ /(herdr agent prompt|herdr pane run|orca terminal send)/ && s ~ /<[^<>]*brief[^<>]*>/ }
      { line = $0; start = NR }
      line ~ /\\$/ { getline nxt; line = line " " nxt }
      bad(line) { print name ":" start }
    ' "$f"
  done
}

printf '%screw briefs by file%s\n\n' "$DIM" "$RST"

section "no shipped send carries a brief placeholder"
out="$(inline_brief_findings "$ORCH")"
if [ -z "$out" ]; then
  pass "no layer file, template or shared reference sends a brief placeholder as an argument"
else
  fail "no layer file, template or shared reference sends a brief placeholder as an argument" "$out"
fi

section "each layer sends the fixed pointer line"
pin "$HERDR_MD" "herdr agent prompt <pane> 'Read <path> and follow it.'" \
  "herdr's by-file send is the fixed pointer line, once"
pin "$ORCA_MD" "orca terminal send --terminal <h> --enter --text 'Read <path> and follow it.'" \
  "orca's by-file send is the fixed pointer line, once"

section "controls: the predicate passes the fixed line and still fails an inline brief"
# A small tree of its own, not a copy of the shipped one: a defect in the shipped files turns
# fact 1 red alone, and these controls keep saying what the predicate can and cannot see.
ctl="$(mktemp -d)"
trap 'if [ -d "$ctl" ]; then chmod -R u+rwx "$ctl"; rm -rf "$ctl"; fi' EXIT
C="$ctl/orchestrate"
mkdir -p "$C/references/layers"
reset_fixture() {
  printf '%s\n' "# skill" > "$C/SKILL.md"
  printf '%s\n' "# briefs" "PING: after every rename, one send: <PING_SEND> '[crew report implementer] <task id>'" > "$C/references/briefs.md"
  printf '%s\n' "# lifecycle" > "$C/references/lifecycle.md"
  printf '%s\n' "# herdr" "- herdr agent prompt <pane> 'Read <path> and follow it.'" > "$C/references/layers/herdr.md"
  printf '%s\n' "# orca" "- orca terminal send --terminal <h> --enter --text 'Read <path> and follow it.'" > "$C/references/layers/orca.md"
}
reset_fixture

out="$(inline_brief_findings "$C")"
if [ -z "$out" ]; then
  pass "control: a tree whose sends carry the fixed pointer line has no finding"
else
  fail "control: a tree whose sends carry the fixed pointer line has no finding" "$out"
fi

# The unread file holds a real violation; losing its read must be named, not clean.
printf '%s\n' 'herdr pane run <pane> "<brief>"' > "$C/references/hidden.md"
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP control: inline_brief_findings unreadable file (uid 0 bypasses chmod 000)\n'
else
  chmod 000 "$C/references/hidden.md"
  out="$(inline_brief_findings "$C" 2>&1)"
  chmod 600 "$C/references/hidden.md"
  if [ "$out" = "SCAN-ERROR inline_brief_findings $C/references/hidden.md: not a readable regular file" ]; then
    pass "control: inline_brief_findings rejects an unreadable file by name"
  else
    fail "control: inline_brief_findings rejects an unreadable file by name" "$out"
  fi
fi
out="$(inline_brief_findings "$C")"
if [ "$out" = 'references/hidden.md:1' ]; then
  pass "control: inline_brief_findings reads the adjacent readable violation"
else
  fail "control: inline_brief_findings reads the adjacent readable violation" "$out"
fi
rm "$C/references/hidden.md"
empty="$ctl/empty"; mkdir "$empty"
out="$(inline_brief_findings "$empty")"
if [ -z "$out" ]; then pass "control: inline_brief_findings skips unmatched globs"
else fail "control: inline_brief_findings skips unmatched globs" "$out"; fi

# The pass case beside the failing ones: the fixed pointer line with flags after it is no finding.
printf '%s\n' "herdr agent prompt <pane> 'Read <path> and follow it.' --wait --until working" >> "$C/references/briefs.md"
out="$(inline_brief_findings "$C")"
if [ -z "$out" ]; then
  pass "control: the fixed pointer line as a send's argument is accepted in a template"
else
  fail "control: the fixed pointer line as a send's argument is accepted in a template" "$out"
fi
reset_fixture

# A brief placeholder on a line that sends nothing is prose, not a send.
printf '%s\n' 'The worker reads `<brief>` as the whole contract.' >> "$C/references/briefs.md"
out="$(inline_brief_findings "$C")"
if [ -z "$out" ]; then
  pass "control: a placeholder in prose, with no send command, is not a finding"
else
  fail "control: a placeholder in prose, with no send command, is not a finding" "$out"
fi
reset_fixture

# Each of these must still fail, by file and line. The last two are the shapes a rewording reaches for.
plant() { # <relative file> <planted line> <label>
  local rel="$1" text="$2" label="$3"
  printf '%s\n' "$text" >> "$C/$rel"
  out="$(inline_brief_findings "$C")"
  if [ "$out" = "$rel:$(wc -l < "$C/$rel" | tr -d ' ')" ]; then
    pass "$label"
  else
    fail "$label" "got: ${out:-<none>}"
  fi
  reset_fixture
}
plant references/layers/herdr.md 'herdr agent prompt <pane> "<brief>" --wait --until working --until blocked' \
  "control: an inline brief in herdr's detected send fails"
plant references/layers/herdr.md 'herdr pane run <pane> "<brief>"' \
  "control: an inline brief in herdr's undetected send fails"
plant references/layers/orca.md 'orca terminal send --terminal <h> --enter --text "<brief>"' \
  "control: an inline brief in orca's send fails"
plant references/briefs.md 'herdr agent prompt <pane> "<the brief>"' \
  "control: a template that sends '<the brief>' fails"
plant references/lifecycle.md 'orca terminal send --terminal <h> --text <brief text>' \
  "control: a shared reference that sends '<brief text>' fails"
plant SKILL.md 'herdr pane run <pane> "<brief>"' \
  "control: SKILL.md that sends '<brief>' fails"
printf '%s\n' 'herdr agent prompt <pane> \' '  "<brief>"' >> "$C/references/layers/herdr.md"
out="$(inline_brief_findings "$C")"
n="$(wc -l < "$C/references/layers/herdr.md" | tr -d ' ')"
if [ "$out" = "references/layers/herdr.md:$((n - 1))" ]; then
  pass "control: a placeholder on the continuation line of a send fails"
else
  fail "control: a placeholder on the continuation line of a send fails" "got: ${out:-<none>}"
fi

rm -rf "$ctl"
if [ ! -e "$ctl" ]; then
  pass "control: the by-file controls leave no fixture behind"
else
  fail "control: the by-file controls leave no fixture behind" "$ctl survived its cleanup"
fi

section "the hoisted counters are not re-copied"
assert_hoisted_counters

report
exit $?
