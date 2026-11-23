#!/usr/bin/env bash
#
# crew — the layer boundary, mechanical facts only.
#
# The anti-goal this file exists for (spec §2, §4.1): a herdr command left in a shared file,
# where the next layer would inherit it as an instruction. So the sweep is the point, and it
# prints EVERY hit — a truncated list reads as a shorter job than the one actually left.
#
# Four facts:
#   1. no shared `.md` under skills/orchestrate/ names a layer's commands (`herdr <word>`,
#      `HERDR_`, `orca <word>`) — `references/layers/*` is where those live, and is exempt;
#   2. both layer files carry the thirteen step headings, in order — orca.md equal to herdr.md's;
#   3. a rule true for any layer lives in ONE shared file and in no `layers/*.md` — the
#      anchors in the last section are checked absent from the layer files and present once
#      in their owner, so a layer file cannot accumulate the next layer's copy;
#   4. the orchestration-system verb pair appears nowhere under `crew/` (spec §4.3).
#
# The exemptions are a LIST with a label each, so a task that is done shrinks it rather than
# leaving a hole nobody can see:
#
#   PERMANENT  SKILL.md's frontmatter `description:` line — the trigger words an operator
#              actually types ("the herdr orchestrator session"). Not a command, and the
#              operator's own words are not something a task removes.
#
# T4's envelope entry and T5's identity entry are both gone — the `PING:`/`MOLT:`/`NOTIFY_RUN=`
# lines name the layer's Send (`test-brief-envelope.sh`), and the identity reads are the
# layer's `Identity` (`test-layer-herdr.sh`). Only the PERMANENT one stays.
#
# Usage:   bash crew/tests/test-layer-boundary.sh
# Exit:    0 if every mechanical fact holds; 1 otherwise.
# Deps:    bash 3.2+, find, awk.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REF="$PLUGIN_ROOT/skills/orchestrate"
LAYER_MD="$REF/references/layers/herdr.md"
ORCA_MD="$REF/references/layers/orca.md"

# The thirteen steps, in the order every layer file carries them.
STEPS='Health
Identity
Run workspace
Seat worktree
Seat launch
Readiness
Send
Read
Wait
Completion signal
Teardown
Machines
Host: OMP'

# shellcheck source=/dev/null
. "$SCRIPT_DIR/_helpers.sh"

# Every fixture uses ctl; restore traversal permissions even if a control aborts.
ctl=""
trap 'if [ -n "${ctl:-}" ] && [ -d "$ctl" ]; then chmod -R u+rwx "$ctl"; rm -rf "$ctl"; fi' EXIT
trap 'exit 1' HUP INT TERM

# ── the sweep ───────────────────────────────────────────────────────────────
#
# Case patterns rather than `grep -q` in a pipeline: `grep -q` exits at the first match and
# the producer takes SIGPIPE if it writes again, which fails intermittently on a true match.
# The sweep takes its root so the controls below can run it over a fixture tree.
sweep_findings() { # <skills/orchestrate dir>
  local dir="$1" f n line files find_status
  # A successful sort cannot certify a partial find traversal.
  if files="$(find "$dir" -name '*.md')"; then
    :
  else
    find_status=$?
    printf 'SCAN-ERROR sweep_findings %s: find exited %s\n' "$dir" "$find_status"
    return 0
  fi
  [ -n "$files" ] || return 0
  printf '%s\n' "$files" | sort | while IFS= read -r f; do
    case "$f" in */references/layers/*) continue ;; esac
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
      printf 'SCAN-ERROR sweep_findings %s: not a readable regular file\n' "$f"
      continue
    fi
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      case "$line" in
        *"herdr "[a-z]*|*"HERDR_"*|*"orca "[a-z]*) ;;
        *) continue ;;
      esac
      # PERMANENT — the frontmatter triggers of SKILL.md, and that line only.
      case "${f##*/}:$line" in
        SKILL.md:description:*) continue ;;
      esac
      printf '%s:%s:%s\n' "$f" "$n" "$line"
    done < "$f"
  done
}

printf '%screw layer boundary%s\n\n' "$DIM" "$RST"

section "no shared file names a layer's commands"
findings="$(sweep_findings "$REF")"
if [ -z "$findings" ]; then
  pass "no herdr command or HERDR_ name in a shared file"
else
  fail "no herdr command or HERDR_ name in a shared file ($(printf '%s\n' "$findings" | wc -l | tr -d ' ') line(s)):"
  printf '%s\n' "$findings" | sed 's/^/        /'
fi

# Controls: the sweep reads a tree, so plant a tree. The clean fixture is the adjacent
# control — a sweep that reported something for everything would pass the planted one alone.
ctl="$(mktemp -d)"
mkdir -p "$ctl/references"
printf '# Roles\n\nThe seat launch is the layer step, named, never typed here.\n' > "$ctl/references/roles.md"
out="$(sweep_findings "$ctl")"
if [ -z "$out" ]; then
  pass "control: the sweep passes a shared file with no layer command"
else
  fail "control: the sweep passes a shared file with no layer command" "$out"
fi
# A listed but unreadable file must not certify a clean scan.
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP control: sweep_findings unreadable file (uid 0 bypasses chmod 000)\n'
else
  printf 'herdr pane run hidden\n' > "$ctl/hidden.md"
  chmod 000 "$ctl/hidden.md"
  out="$(sweep_findings "$ctl")"
  chmod 600 "$ctl/hidden.md"
  if [ "$out" = "SCAN-ERROR sweep_findings $ctl/hidden.md: not a readable regular file" ]; then
    pass "control: sweep_findings rejects an unreadable regular file by name"
  else
    fail "control: sweep_findings rejects an unreadable regular file by name" "got: ${out:-<none>}"
  fi
  rm "$ctl/hidden.md"
fi
# A partial walk must not certify the readable files it happened to visit.
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP control: sweep_findings unreadable traversal (uid 0 bypasses chmod 000)\n'
else
  mkdir "$ctl/locked"
  printf 'herdr pane run hidden\n' > "$ctl/locked/hidden.md"
  chmod 000 "$ctl/locked"
  out="$(sweep_findings "$ctl")"
  chmod 700 "$ctl/locked"
  if printf '%s\n' "$out" | awk -v root="$ctl" '
    index($0, "SCAN-ERROR sweep_findings " root ": find exited ") == 1 &&
      $0 ~ /: find exited [1-9][0-9]*$/ { hit++ }
    END { exit(hit == 1 ? 0 : 1) }'; then
    pass "control: sweep_findings rejects a failed traversal by name, root and status"
  else
    fail "control: sweep_findings rejects a failed traversal by name, root and status" "got: ${out:-<none>}"
  fi
  rm -rf "$ctl/locked"
fi
printf 'herdr pane run x\n' >> "$ctl/references/roles.md"
out="$(sweep_findings "$ctl")"
if [ "$(printf '%s\n' "$out" | grep -c .)" -eq 1 ] && printf '%s' "$out" | grep -F 'herdr pane run x' >/dev/null; then
  pass "control: one planted layer command is caught, by name and line"
else
  fail "control: one planted layer command is caught, by name and line" "got: ${out:-<none>}"
fi
# The layer files themselves are exempt: the same line there is not a finding.
mkdir -p "$ctl/references/layers"
mv "$ctl/references/roles.md" "$ctl/references/layers/herdr.md"
out="$(sweep_findings "$ctl")"
if [ -z "$out" ]; then
  pass "control: the same line inside references/layers/ is exempt"
else
  fail "control: the same line inside references/layers/ is exempt" "$out"
fi
rm -rf "$ctl"
if [ ! -e "$ctl" ]; then
  pass "control: the sweep controls leave no fixture behind"
else
  fail "control: the sweep controls leave no fixture behind" "$ctl survived its cleanup"
fi

section "no shared file points at one layer's own file"

# B2 (#877): a shared file naming `layers/herdr.md` sends an `layer: orca` run to herdr's
# mechanics — the spine and work-PR briefs' `MECHANICS=` slot and every prose pointer were
# the sites. The pointer belongs to the run's layer, and `layers/<layer>.md` is the only
# path-shaped form a shared file may carry; `references/layers/*` is exempt, like the
# command sweep above.
layer_pointer_findings() { # <skills/orchestrate dir>
  local dir="$1" f n line files find_status
  # Capture before sorting so a skipped subtree is not an empty finding list.
  if files="$(find "$dir" -name '*.md')"; then
    :
  else
    find_status=$?
    printf 'SCAN-ERROR layer_pointer_findings %s: find exited %s\n' "$dir" "$find_status"
    return 0
  fi
  [ -n "$files" ] || return 0
  printf '%s\n' "$files" | sort | while IFS= read -r f; do
    case "$f" in */references/layers/*) continue ;; esac
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
      printf 'SCAN-ERROR layer_pointer_findings %s: not a readable regular file\n' "$f"
      continue
    fi
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      case "$line" in
        *"layers/herdr.md"*|*"layers/orca.md"*) printf '%s:%s:%s\n' "$f" "$n" "$line" ;;
      esac
    done < "$f"
  done
}

findings="$(layer_pointer_findings "$REF")"
if [ -z "$findings" ]; then
  pass "no shared file names one layer's own file"
else
  fail "no shared file names one layer's own file ($(printf '%s\n' "$findings" | wc -l | tr -d ' ') line(s)):"
  printf '%s\n' "$findings" | sed 's/^/        /'
fi

# Controls: the check reads a tree, so plant one — the clean fixture is the adjacent
# control, and the planted pointer is caught with its file and line.
ctl="$(mktemp -d)"
mkdir -p "$ctl/references"
printf '# Roles\n\nThe layer file says how a seat is sent a brief.\n' > "$ctl/references/roles.md"
out="$(layer_pointer_findings "$ctl")"
if [ -z "$out" ]; then
  pass "control: the check passes a shared file that names no layer file"
else
  fail "control: the check passes a shared file that names no layer file" "$out"
fi
# A listed but unreadable file must not certify a clean scan.
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP control: layer_pointer_findings unreadable file (uid 0 bypasses chmod 000)\n'
else
  printf 'See layers/herdr.md\n' > "$ctl/hidden.md"
  chmod 000 "$ctl/hidden.md"
  out="$(layer_pointer_findings "$ctl")"
  chmod 600 "$ctl/hidden.md"
  if [ "$out" = "SCAN-ERROR layer_pointer_findings $ctl/hidden.md: not a readable regular file" ]; then
    pass "control: layer_pointer_findings rejects an unreadable regular file by name"
  else
    fail "control: layer_pointer_findings rejects an unreadable regular file by name" "got: ${out:-<none>}"
  fi
  rm "$ctl/hidden.md"
fi
# Adjacent to the readable pass: losing a subtree must be a named scan error.
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP control: layer_pointer_findings unreadable traversal (uid 0 bypasses chmod 000)\n'
else
  mkdir "$ctl/locked"
  printf 'See layers/herdr.md\n' > "$ctl/locked/hidden.md"
  chmod 000 "$ctl/locked"
  out="$(layer_pointer_findings "$ctl")"
  chmod 700 "$ctl/locked"
  if printf '%s\n' "$out" | awk -v root="$ctl" '
    index($0, "SCAN-ERROR layer_pointer_findings " root ": find exited ") == 1 &&
      $0 ~ /: find exited [1-9][0-9]*$/ { hit++ }
    END { exit(hit == 1 ? 0 : 1) }'; then
    pass "control: layer_pointer_findings rejects a failed traversal by name, root and status"
  else
    fail "control: layer_pointer_findings rejects a failed traversal by name, root and status" "got: ${out:-<none>}"
  fi
  rm -rf "$ctl/locked"
fi
printf 'See `layers/herdr.md` for the send.\n' >> "$ctl/references/roles.md"
out="$(layer_pointer_findings "$ctl")"
if [ "$(printf '%s\n' "$out" | grep -c .)" -eq 1 ] && printf '%s' "$out" | grep -F 'layers/herdr.md' >/dev/null; then
  pass "control: a planted pointer is caught, by name and line"
else
  fail "control: a planted pointer is caught, by name and line" "got: ${out:-<none>}"
fi
# The layer files themselves are exempt: the same line there is not a finding.
mkdir -p "$ctl/references/layers"
mv "$ctl/references/roles.md" "$ctl/references/layers/herdr.md"
out="$(layer_pointer_findings "$ctl")"
if [ -z "$out" ]; then
  pass "control: the same pointer inside references/layers/ is exempt"
else
  fail "control: the same pointer inside references/layers/ is exempt" "$out"
fi
rm -rf "$ctl"
if [ ! -e "$ctl" ]; then
  pass "control: the pointer controls leave no fixture behind"
else
  fail "control: the pointer controls leave no fixture behind" "$ctl survived its cleanup"
fi

section "the layer files carry the thirteen steps, in order"
headings_of() { sed -n 's/^## //p' "$1"; }
if [ ! -f "$LAYER_MD" ]; then
  fail "$LAYER_MD exists" "no such file — the thirteen headings cannot be read from a file that is not there"
else
  got="$(headings_of "$LAYER_MD")"
  n_got="$(printf '%s\n' "$got" | grep -c .)"
  if [ "$n_got" -eq 0 ]; then
    fail "herdr.md has headings to compare" "the read returned nothing, and two empty lists compare equal"
  elif cmp -s <(printf '%s\n' "$got") <(printf '%s\n' "$STEPS"); then
    pass "herdr.md carries the thirteen step headings, in order ($n_got)"
  else
    fail "herdr.md carries the thirteen step headings, in order" "got: $(printf '%s' "$got" | tr '\n' '|')"
  fi
fi
if [ ! -f "$ORCA_MD" ]; then
  fail "$ORCA_MD exists" "no such file — orca.md's headings cannot be read from a file that is not there"
else
  o_got="$(headings_of "$ORCA_MD")"
  n_o="$(printf '%s\n' "$o_got" | grep -c .)"
  if [ "$n_o" -eq 0 ]; then
    fail "orca.md has headings to compare" "the read returned nothing, and two empty lists compare equal"
  elif cmp -s <(printf '%s\n' "$o_got") <(headings_of "$LAYER_MD"); then
    pass "orca.md carries herdr.md's thirteen step headings, in order ($n_o)"
  else
    fail "orca.md carries herdr.md's thirteen step headings, in order" "got: $(printf '%s' "$o_got" | tr '\n' '|')"
  fi
  # Control: the equality must fail on a dropped heading — awk deletes the
  # first "## " line, the form both GNU sed and BSD sed would disagree on.
  ctl_layer="$(mktemp)"
  awk '/^## / && !d { d = 1; next } { print }' "$ORCA_MD" > "$ctl_layer"
  if ! cmp -s <(headings_of "$ctl_layer") <(headings_of "$LAYER_MD"); then
    pass "control: a dropped heading fails the equality"
  else
    fail "control: a dropped heading fails the equality" "the fixture did not differ from the real file"
  fi
  rm -f "$ctl_layer"
fi

section "rules stay out of the layer file"

# The anti-goal one level in (spec §2, §4.1): a rule true for any terminal layer belongs in a
# shared file, not in `layers/*.md`, or the next layer's file would have to copy it. Each
# anchor below is such a rule phrase; the pair is the check — the phrase must be ABSENT from
# every `layers/*.md` AND present EXACTLY ONCE in the shared file that owns it, so a phrase
# that leaves the layer file and never lands in its home fails too.
#
# D1 (2026-10-18): the #867 send-tag rule is layer-neutral — an Orca seat's ping reaches the
# top as the same text — so the rule left `layers/herdr.md` for `completion.md`; the two
# send-tag anchors below pin it there and out of every layer file.
ANCHORS="$(printf '%s\n' \
  "the generation check governs all three	completion.md" \
  "One bounded background timer of about 15 minutes	completion.md" \
  "MOLT WARNING <pct> <task id>	completion.md" \
  "doorbell is the report file	completion.md" \
  "sends up to a parent or top session	completion.md" \
  "Sends that stay untagged	completion.md" \
  "SEAT_MODS_ROLE=coordinator	roles.md" \
  "closes last	roles.md")"

# One line per violation: a layer file carrying the phrase, or an owner not stating it once.
rule_findings() { # <skills/orchestrate dir>
  local dir="$1" phrase owner f n
  printf '%s\n' "$ANCHORS" | while IFS="$(printf '\t')" read -r phrase owner; do
    [ -n "$phrase" ] || continue
    for f in "$dir"/references/layers/*.md; do
      [ -e "$f" ] || continue
      n="$(occurrences "$f" "$phrase")" || n=unreadable
      [ "$n" = 0 ] || printf 'layer %s carries the rule "%s" (%s)\n' "${f#"$dir"/}" "$phrase" "$n"
    done
    n="$(occurrences "$dir/references/$owner" "$phrase")" || n=unreadable
    [ "$n" = 1 ] || printf 'references/%s states the rule "%s" %s time(s), not once\n' "$owner" "$phrase" "$n"
  done
}

n_anchors="$(printf '%s\n' "$ANCHORS" | grep -c .)"
findings="$(rule_findings "$REF")"
if [ -z "$findings" ]; then
  pass "every shared rule phrase is out of the layer files and stated once by its owner ($n_anchors anchors)"
else
  fail "every shared rule phrase is out of the layer files and stated once by its owner" "$findings"
fi

# Controls: the check reads a tree, so plant one. Adjacent to the real run, and in both
# directions — a clean fixture copy passes, so a check that flagged every tree would not pass
# the plant below on its own.
ctl="$(mktemp -d)"
cp -R "$REF" "$ctl/orchestrate"
out="$(rule_findings "$ctl/orchestrate")"
if [ -z "$out" ]; then
  pass "control: the rule check passes a clean fixture copy of the tree"
else
  fail "control: the rule check passes a clean fixture copy of the tree" "$out"
fi
planted='the generation check governs all three'
printf '%s\n' "$planted" >> "$ctl/orchestrate/references/layers/herdr.md"
out="$(rule_findings "$ctl/orchestrate")"
if [ "$(printf '%s\n' "$out" | grep -c .)" -eq 1 ] \
   && printf '%s' "$out" | grep -F "carries the rule \"$planted\"" >/dev/null; then
  pass "control: one planted rule phrase in a layer file fails, named"
else
  fail "control: one planted rule phrase in a layer file fails, named" "got: ${out:-<none>}"
fi
rm -rf "$ctl"
if [ ! -e "$ctl" ]; then
  pass "control: the rule controls leave no fixture behind"
else
  fail "control: the rule controls leave no fixture behind" "$ctl survived its cleanup"
fi

section "no orchestration system under crew/"

# Spec §4.3: this plugin drives Orca at the terminal and worktree level only.
# The needle is ASSEMBLED so this file does not itself carry the string it
# sweeps for; every hit is printed with its file and line.
ORC_NEEDLE="orca"' '"orchestration"

orchestration_findings() { # <root>
  local root="$1" f n line files find_status
  # The boundary covers every file, including subtrees find failed to enter.
  if files="$(find "$root" -type f)"; then
    :
  else
    find_status=$?
    printf 'SCAN-ERROR orchestration_findings %s: find exited %s\n' "$root" "$find_status"
    return 0
  fi
  [ -n "$files" ] || return 0
  printf '%s\n' "$files" | sort | while IFS= read -r f; do
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
      printf 'SCAN-ERROR orchestration_findings %s: not a readable regular file\n' "$f"
      continue
    fi
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      case "$line" in
        *"$ORC_NEEDLE"*) printf '%s:%s:%s\n' "$f" "$n" "$line" ;;
      esac
    done < "$f"
  done
}

findings="$(orchestration_findings "$PLUGIN_ROOT")"
if [ -z "$findings" ]; then
  pass "no orchestration-system command anywhere under crew/"
else
  fail "no orchestration-system command anywhere under crew/ ($(printf '%s\n' "$findings" | wc -l | tr -d ' ') line(s)):"
  printf '%s\n' "$findings" | sed 's/^/        /'
fi

# Controls: the scan reads a tree, so plant one — a clean fixture passes, a
# planted file is caught by name and line.
ctl="$(mktemp -d)"
printf 'a clean file\n' > "$ctl/clean.md"
out="$(orchestration_findings "$ctl")"
if [ -z "$out" ]; then pass "control: the scan passes a clean fixture"
else fail "control: the scan passes a clean fixture" "$out"; fi
# A listed but unreadable file must not certify a clean scan.
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP control: orchestration_findings unreadable file (uid 0 bypasses chmod 000)\n'
else
  printf '%s\n' "$ORC_NEEDLE hidden" > "$ctl/hidden.txt"
  chmod 000 "$ctl/hidden.txt"
  out="$(orchestration_findings "$ctl")"
  chmod 600 "$ctl/hidden.txt"
  if [ "$out" = "SCAN-ERROR orchestration_findings $ctl/hidden.txt: not a readable regular file" ]; then
    pass "control: orchestration_findings rejects an unreadable regular file by name"
  else
    fail "control: orchestration_findings rejects an unreadable regular file by name" "got: ${out:-<none>}"
  fi
  rm "$ctl/hidden.txt"
fi
# Adjacent to the readable pass: all file types need a complete traversal.
if [ "$(id -u)" -eq 0 ]; then
  printf '  SKIP control: orchestration_findings unreadable traversal (uid 0 bypasses chmod 000)\n'
else
  mkdir "$ctl/locked"
  printf '%s\n' "$ORC_NEEDLE hidden" > "$ctl/locked/hidden.txt"
  chmod 000 "$ctl/locked"
  out="$(orchestration_findings "$ctl")"
  chmod 700 "$ctl/locked"
  if printf '%s\n' "$out" | awk -v root="$ctl" '
    index($0, "SCAN-ERROR orchestration_findings " root ": find exited ") == 1 &&
      $0 ~ /: find exited [1-9][0-9]*$/ { hit++ }
    END { exit(hit == 1 ? 0 : 1) }'; then
    pass "control: orchestration_findings rejects a failed traversal by name, root and status"
  else
    fail "control: orchestration_findings rejects a failed traversal by name, root and status" "got: ${out:-<none>}"
  fi
  rm -rf "$ctl/locked"
fi
printf '%s\n' "the $ORC_NEEDLE dispatch verb" >> "$ctl/clean.md"
out="$(orchestration_findings "$ctl")"
if [ "$(printf '%s\n' "$out" | grep -c .)" -eq 1 ] && printf '%s' "$out" | grep -F "$ORC_NEEDLE" >/dev/null; then
  pass "control: a planted orchestration-system command is caught, by name and line"
else
  fail "control: a planted orchestration-system command is caught, by name and line" "got: ${out:-<none>}"
fi
rm -rf "$ctl"
if [ ! -e "$ctl" ]; then
  pass "control: the scan controls leave no fixture behind"
else
  fail "control: the scan controls leave no fixture behind" "$ctl survived its cleanup"
fi

report
