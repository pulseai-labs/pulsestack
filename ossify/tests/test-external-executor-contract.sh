#!/usr/bin/env bash
# External-executor contract — mechanical facts only.
#
# The external-executor mode is prose: the judgment half (when to halt, how to
# read a result, what a correction may skip) is deliberately NOT asserted here
# and belongs to the LLM-judge rubric. What IS asserted is the mechanical
# surface a consumer parses or types:
#
#   - the exact flag grammar `/run-spine <spine-id> --external-executor`
#   - the request/result record KEY SETS, by set equality in both directions,
#     so a missing field and an extra field are equally red
#   - the DEFAULT nested dispatch surviving every edit (the no-flag control)
#   - zero subagent-invocation forms in the external branch
#   - the two-value return enum, unchanged by the correction continuation
#   - zero `orca` in ossify's shipped product surfaces
#   - the Layer 4 route: close dispatches its verifier, except inside an
#     external lane, where Layer 4 stays inline (the deleted engine's absence
#     side is test-layer4-residue.sh's, not duplicated here)
#
# COUNTING is one awk index() pass per needle. `grep -c` counts matching LINES
# and cannot see two hits on one line; `… | grep -q` can fail on a TRUE match
# under pipefail when the producer takes SIGPIPE. A needle counted exactly once
# is also provably contiguous — a pin that wrapped across a markdown line break
# would match zero times, not once.
#
# EVERY zero-count assertion carries a positive control beside it, because a
# missing or renamed file makes "zero occurrences" true for the wrong reason.
#
# Usage:  bash ossify/tests/test-external-executor-contract.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"

OSSIFY="$(cd "$HERE/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/external-contract.XXXXXX")"
trap 'chmod -R u+rwx "$WORK"; rm -rf "$WORK"' EXIT
WI="$OSSIFY/skills/work-item"
EXT="$WI/references/external-executor.md"
CORR="$WI/references/correction-continuation.md"
RUNSPINE="$OSSIFY/commands/run-spine.md"
RUNSPINE_SK="$OSSIFY/skills/run-spine/SKILL.md"
RO="$WI/references/round-orchestration.md"
WIC="$OSSIFY/skills/close/references/work-item-close.md"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# occurrences <file> <literal needle> -> count on stdout.
# An empty needle is refused rather than counted: index(line, "") returns 1
# forever and the loop would never advance, hanging the suite instead of
# failing it.
occurrences() {
  if [ -z "${2:-}" ]; then printf 'empty needle\n' >&2; return 1; fi
  [ -f "$1" ] || { printf 'no such file\n' >&2; return 1; }
  awk -v needle="$2" '
    { line = $0
      while ((i = index(line, needle)) > 0) { n++; line = substr(line, i + length(needle)) } }
    END { print n+0 }' "$1"
}

# pin <file> <needle> <label> — exactly once.
pin() {
  c="$(occurrences "$1" "$2")" || { T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (unreadable file or empty needle: $1)"; return 0; }
  if [ "$c" -eq 1 ]; then T_PASS=$((T_PASS+1))
  elif [ "$c" -eq 0 ]; then T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 — not found in ${1##*/} (reworded away, or the pin now spans a line wrap): $2"
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 — found $c times in ${1##*/}; a pin must be unique: $2"
  fi
}

# absent <file> <needle> <label> — zero occurrences. Caller must have asserted
# the file is non-empty first; `nonempty` below is that control.
absent() {
  c="$(occurrences "$1" "$2")" || { T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (unreadable file: $1)"; return 0; }
  if [ "$c" -eq 0 ]; then T_PASS=$((T_PASS+1))
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 — '$2' occurs $c time(s) in ${1##*/}"
  fi
}

nonempty() { # <file> <label> — the control every `absent` above depends on
  if [ -s "$1" ]; then T_PASS=$((T_PASS+1))
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: $2 — $1 is missing or empty, so every zero-count against it is vacuous"; fi
}

# keyset <file> <record marker> <indent-depth> -> sorted keys of that depth,
# one per line, from the fenced block the marker opens. Depth 1 = two spaces.
# Reads to the closing bare fence so a following block cannot bleed in.
keyset() {
  awk -v marker="$2" -v want="$3" '
    index($0, marker) > 0 && !seen { seen = 1; next }
    seen && /^```[[:space:]]*$/ { exit }
    seen {
      if (match($0, /^ *[A-Za-z_][A-Za-z0-9_]*:/)) {
        ind = match($0, /[^ ]/) - 1
        if (ind % 2 == 0 && ind / 2 == want) {
          k = $0; sub(/^ +/, "", k); sub(/:.*$/, "", k); print k
        }
      }
    }' "$1" | LC_ALL=C sort
}

# assert_keyset <file> <marker> <depth> <space-separated expected> <label>
assert_keyset() {
  want="$(printf '%s\n' $4 | LC_ALL=C sort)"
  got="$(keyset "$1" "$2" "$3")"
  if [ "$got" = "$want" ]; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1))
    echo "FAIL: $5"
    echo "      expected: $(printf '%s' "$want" | tr '\n' ' ')"
    echo "      observed: $(printf '%s' "$got" | tr '\n' ' ')"
  fi
}

# ---------------------------------------------------------------------------
# 1. Flag grammar — the two command shapes a consumer types
# ---------------------------------------------------------------------------
pin "$RUNSPINE_SK" '`/run-spine <spine-id> --external-executor` — the caller supplies' \
  "control: shape 2 unchanged (run-spine/SKILL.md names the external command shape exactly once)"
pin "$RUNSPINE_SK" '/run-spine <spine-id> --external-executor --detach' "grammar: the third shape"
pin "$RUNSPINE_SK" '`--detach` without `--external-executor`' "grammar: detach alone refused"
pin "$EXT" 'the lane counts no request' "detach: the lane does not count"
pin "$EXT" 'the caller counts each execution, the first one included' "detach: the caller counts"
pin "$RO" 'except under `--detach`' "§5: the one counting exception"

ah="$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 && /^argument-hint: / {sub(/^argument-hint: /,""); print; exit}' "$RUNSPINE")"
t_assert_eq '"<spine-id> [--external-executor [--detach]]"' "$ah" \
  "run-spine.md argument-hint declares the optional flag"

# ---------------------------------------------------------------------------
# 2. The in-session protocol — key sets, both directions
# ---------------------------------------------------------------------------
nonempty "$EXT" "external-executor.md exists"

assert_keyset "$EXT" 'external_execution_request:' 1 \
  "work_item_id target_repo handoff_path spec_path worktree_path branch base_sha" \
  "external_execution_request carries exactly its seven fields"

assert_keyset "$EXT" 'external_execution_result:' 1 \
  "work_item_id coordinator_verdict implementer_return tree_oid head_oid report_oid spec_oid" \
  "external_execution_result carries exactly its seven top-level fields"

assert_keyset "$EXT" 'external_execution_result:' 2 \
  "mode report_path summary stage_status" \
  "implementer_return is the existing complete-return shape, unextended"

# A gaps-surfaced item never produced a report, a staged tree or a commit, so it
# returns a SEPARATE, smaller record under its own marker — three fields and no
# `*_oid` of any kind. Asserting it under its own marker is what lets §5a stay a
# single unbranched check list: the two shapes are different records, not one
# record checked two ways.
assert_keyset "$EXT" 'external_execution_gaps:' 1 \
  "work_item_id coordinator_verdict implementer_return" \
  "external_execution_gaps carries exactly its three fields and no oid"

assert_keyset "$EXT" 'external_execution_gaps:' 2 \
  "mode gaps" \
  "the gaps record's implementer_return is the existing gaps shape, unextended"

# ---------------------------------------------------------------------------
# 3. The no-flag control — the default nested dispatch must survive every edit
# ---------------------------------------------------------------------------
_TASKDISPATCH='Task(subagent_type="ossify:implementer-agent"'
pin "$RO" "$_TASKDISPATCH" \
  "round-orchestration.md still dispatches the nested implementer agent (no-flag default)"
pin "$WI/SKILL.md" "$_TASKDISPATCH" \
  "work-item/SKILL.md still names the nested implementer dispatch (no-flag default)"

# ---------------------------------------------------------------------------
# 4. No subagent invocation anywhere in the external branch
# ---------------------------------------------------------------------------
# Invocation FORMS only. Prose may say "the `Task` tool" in a prohibition; what
# must never appear is something that reads as a call. Both new references say
# so in their own headers so a later editor does not reintroduce one by
# quoting the ban.
for form in 'Task(' 'Agent(' 'subagent_type'; do
  absent "$EXT" "$form" "external-executor.md invokes no subagent ('$form')"
done

# ---------------------------------------------------------------------------
# 5. The return enum stays at two values
# ---------------------------------------------------------------------------
# The correction continuation reuses `complete`; it introduces no third mode.
# Harvested across every file that states a mode, so a third one anywhere is red.
modes="$(for f in "$WI/references/returns.md" "$WI/SKILL.md" "$EXT" "$CORR"; do
  [ -f "$f" ] && awk '{ line=$0
      while ((i = index(line, "\"mode\": \"")) > 0) {
        rest = substr(line, i + 9); j = index(rest, "\"")
        if (j > 1) print substr(rest, 1, j-1)
        line = substr(rest, j+1) } }' "$f"
done | LC_ALL=C sort -u)"
t_assert_eq "$(printf 'complete\ngaps-surfaced\n')" "$modes" \
  "the work-item return enum is exactly {complete, gaps-surfaced} across every file that states it"

# ---------------------------------------------------------------------------
# 6. The correction packet — key set, both directions
# ---------------------------------------------------------------------------
nonempty "$CORR" "correction-continuation.md exists"
pin "$CORR" 'OSSIFY CORRECTION CONTINUATION v1' \
  "the continuation packet declares its versioned header exactly once"
# Six fields, not five: `expected_branch` joined them because §3's identity check
# compares the checked-out branch, and a check whose expected value is not in the
# packet is a check the executor has to invent an expectation for.
assert_keyset "$CORR" 'OSSIFY CORRECTION CONTINUATION v1' 0 \
  "handoff_path work_item_id expected_branch expected_head_sha expected_tree_oid failures" \
  "the continuation packet carries exactly its six fields"
for form in 'Task(' 'Agent(' 'subagent_type'; do
  absent "$CORR" "$form" "correction-continuation.md invokes no subagent ('$form')"
done

# ---------------------------------------------------------------------------
# 7. Layer 4 route — close dispatches its verifier; external mode stays inline
# ---------------------------------------------------------------------------
nonempty "$WIC" "work-item-close.md exists"
pin "$WIC" 'the close dispatches `ossify:verifier-agent` for Layers 3 and 4 and the §4c mutation check' \
  "work-item-close.md dispatches the verifier for Layers 3, 4 and mutation (#951)"
pin "$WIC" 'lane closing its own items** Layers 3 and 4 run in this' \
  "work-item-close.md keeps Layers 3 and 4 in the closing session inside an external lane (#951 D3)"
pin "$EXT" 'mutation check in this mode (`impl-check.md` §4c): the caller' \
  "external-executor.md says close runs no mutation check in this mode (#951 D3)"
pin "$EXT" 'runs Layer 4 inline' \
  "external-executor.md still names the inline Layer 4 route under its mode"
pin "$WIC" 'dispatch no `ossify:verifier-agent` and run no' \
  "work-item-close.md: --verdict dispatches no verifier and fingerprints nothing (#993)"

# There is no route to choose any more: the contract is that no second engine
# exists. The absence half of that contract is test-layer4-residue.sh's —
# pinning the deleted tokens' absence HERE would store them in a file the
# residue gate scans, and a zero-count next to the literal needle is the
# self-match this suite's counting discipline exists to avoid.

# ---------------------------------------------------------------------------
# 8. Product-surface neutrality — no Orca inside shipped ossify
# ---------------------------------------------------------------------------
# Explicit product roots, each asserted to exist and to be found by the same
# walk that reports the zero. `ossify` is the known-present token: if the walk
# cannot find IT, the walk is dead and the `orca` zero means nothing.
PRODUCT_ROOTS="$OSSIFY/commands $OSSIFY/skills $OSSIFY/agents"
PRODUCT_FILES="$OSSIFY/.claude-plugin/plugin.json $OSSIFY/.codex-plugin/plugin.json $OSSIFY/README.md $OSSIFY/CHANGELOG.md"

for d in $PRODUCT_ROOTS; do
  if [ -d "$d" ]; then T_PASS=$((T_PASS+1))
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: product root $d is missing — the neutrality scan below would be vacuous"; fi
done
for f in $PRODUCT_FILES; do
  if [ -s "$f" ]; then T_PASS=$((T_PASS+1))
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: product file $f is missing or empty — the neutrality scan below would be vacuous"; fi
done

product_files() { # directory roots and explicit product files, one argument each
  local files status f
  if files="$(find "$@" -type f -print)"; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if [ ! -f "$f" ] || [ ! -r "$f" ]; then
        printf 'external-executor product scan: %s: not a readable regular file\n' "$f" >&2
        return 1
      fi
    done <<< "$files"
    [ -z "$files" ] || printf '%s\n' "$files"
  else
    status=$?
    printf 'external-executor product scan: %s: find exited %s\n' "$*" "$status" >&2
    return "$status"
  fi
}

product_find_controls() {
  local root="$WORK/find-control" out rc
  mkdir -p "$root/commands/locked" "$root/skills" "$root/agents"
  printf '# visible\n' > "$root/commands/visible.md"
  printf '# hidden\n' > "$root/commands/locked/hidden.md"
  if [ "$(id -u)" -eq 0 ]; then
    echo 'SKIP: external-executor product unreadable-directory control (uid 0 bypasses chmod 000)'
  else
    chmod 000 "$root/commands/locked"
    out="$(product_files "$root/commands" "$root/skills" "$root/agents" 2>&1)"; rc=$?
    chmod 700 "$root/commands/locked"
    if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | awk -v prefix="external-executor product scan: $root/commands $root/skills $root/agents: find exited " \
        'index($0, prefix)==1 && substr($0, length(prefix)+1) ~ /^[1-9][0-9]*$/ { hit++ } END { exit(hit != 1) }'; then
      T_PASS=$((T_PASS+1))
    else
      T_FAIL=$((T_FAIL+1)); echo "FAIL: control: external-executor product must reject an unreadable subtree by name, roots and status (rc=$rc): $out"
    fi
  fi
  out="$(product_files "$root/commands" "$root/skills" "$root/agents" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | LC_ALL=C sort)" = "$(printf '%s/commands/locked/hidden.md\n%s/commands/visible.md' "$root" "$root")" ]; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: control: external-executor product must enumerate the adjacent readable tree (rc=$rc): $out"
  fi
  local hidden
  printf '# clean\n' > "$WORK/explicit-product.md"
  for hidden in "$root/commands/unreadable.md" "$WORK/explicit-product.md"; do
    printf 'orca\n' > "$hidden"
    if [ "$(id -u)" -eq 0 ]; then
      echo "SKIP: external-executor product unreadable-file control for $hidden (uid 0 bypasses chmod 000)"
    else
      chmod 000 "$hidden"
      out="$(product_files "$root/commands" "$root/skills" "$root/agents" "$WORK/explicit-product.md" 2>&1)"; rc=$?
      chmod 600 "$hidden"
      if [ "$rc" -ne 0 ] && [ "$out" = "external-executor product scan: $hidden: not a readable regular file" ]; then
        T_PASS=$((T_PASS+1))
      else
        T_FAIL=$((T_FAIL+1)); echo "FAIL: control: external-executor product must reject an unreadable regular file by path (rc=$rc): $out"
      fi
    fi
    printf '# clean\n' > "$hidden"
    out="$(product_files "$root/commands" "$root/skills" "$root/agents" "$WORK/explicit-product.md" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | LC_ALL=C sort)" = "$(printf '%s\n' "$root/commands/locked/hidden.md" "$root/commands/unreadable.md" "$root/commands/visible.md" "$WORK/explicit-product.md" | LC_ALL=C sort)" ]; then
      T_PASS=$((T_PASS+1))
    else
      T_FAIL=$((T_FAIL+1)); echo "FAIL: control: external-executor product must enumerate the adjacent readable-file tree (rc=$rc): $out"
    fi
  done
}

product_find_controls

scan_list="$WORK/scan-list"
if product_listing="$(product_files $PRODUCT_ROOTS $PRODUCT_FILES 2>&1)"; then
  printf '%s\n' "$product_listing" > "$scan_list"
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: $product_listing"
  t_summary
  exit 1
fi

# One awk pass over the whole set, case-folded, literal.
_scan_hits() { # $1=lowercased needle -> "file:line" hits on stdout
  awk -v needle="$1" 'FNR==1 { } { if (index(tolower($0), needle) > 0) print FILENAME ":" FNR }' $(cat "$scan_list")
}

control_hits="$(_scan_hits 'ossify' | head -5)"
if [ -n "$control_hits" ]; then T_PASS=$((T_PASS+1))
else T_FAIL=$((T_FAIL+1)); echo "FAIL: the neutrality walk found no 'ossify' either — the scan is dead, not clean"; fi

orca_hits="$(_scan_hits 'orca')"
if [ -z "$orca_hits" ]; then T_PASS=$((T_PASS+1))
else T_FAIL=$((T_FAIL+1)); echo "FAIL: shipped ossify product surfaces name Orca:"; printf '      %s\n' $orca_hits; fi
rm -f "$scan_list"

# ---------------------------------------------------------------------------
# 9. The body budget work-item/SKILL.md holds itself to
# ---------------------------------------------------------------------------
n="$(wc -l < "$WI/SKILL.md" | tr -d ' ')"
if [ "$n" -le 450 ]; then T_PASS=$((T_PASS+1))
else T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item/SKILL.md is $n lines, over its own 450-line NEVER-list budget"; fi

t_summary
