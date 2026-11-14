#!/usr/bin/env bash
# Cross-file prose contracts. Prose is an executable artifact here and it has no
# other CI: nothing else in this suite can see a drift between two documents.
#
# The one guarded here is the engine's own deadlock. The callee's pre-flight
# Gate 1 treats a handoff whose Constraints omit `git_policy: STAGE-not-commit`
# or the return JSON shape as MALFORMED, and malformed is itself a gap. So the
# orchestrator-side contract that says what to write into a handoff
# (handoff-contract.md) must agree, to the byte, with the callee-side contract
# that says what will be read back (returns.md) and with the binding body
# (SKILL.md). If they drift, every dispatch returns gaps-surfaced, no work ever
# starts, and there is no runtime signal at all - the failure is two documents
# disagreeing.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/lib/pin.sh"
WI="$HERE/../skills/work-item"

# Obsolete bridge descriptions must not survive, even across line wraps.
t_capture find "$HERE/../skills" -type f -name '*.md' -exec awk '
  { text[FILENAME] = text[FILENAME] " " tolower($0) }
  END { for (f in text) if (text[f] ~ /env(-|[[:space:]]+)var[[:space:]]+bridge/) print f }
' {} +
t_assert_rc 0 'the obsolete-bridge scan reads the skills tree'
t_assert_eq "" "$T_OUT" 'ossify skills contain no obsolete bridge descriptions'

# The TEMPLATE line, not the worked example: both files also carry a filled-in
# example of each shape, and those legitimately differ. The templates are the
# ones still holding `<placeholder>` markers.
_shape() { # $1=file $2=mode
  { grep -F "\"mode\": \"$2\"" "$1" || true; } | { grep -F '<' || true; } | head -1
}

for mode in complete gaps-surfaced; do
  base="$(_shape "$WI/references/returns.md" "$mode")"
  # Non-emptiness FIRST. Two files that both fail to match would compare equal,
  # and the parity assertions below would pass while asserting nothing.
  if [ -n "$base" ]; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: returns.md declares no '$mode' template - the parity checks below are vacuous"
  fi
  for f in "$WI/SKILL.md" "$WI/references/handoff-contract.md"; do
    t_assert_eq "$base" "$(_shape "$f" "$mode")" \
      "$(basename "$f") carries the '$mode' return shape byte-identically to returns.md"
  done
done

# The other half of Gate 1's Constraints requirement. handoff-contract.md must
# carry the literal the callee looks for - a paraphrase ("stage, do not commit")
# reads fine to a human and fails the gate.
#
# D4 (#747): a `grep -Fq` presence check is blind to the deletion it guards when
# the words recur - SKILL.md states the literal twice, so deleting the
# requirement row left it green. `pin` requires EXACTLY one occurrence, and the
# needle is lengthened onto the guarded row until it is unique.
pin "$WI/SKILL.md" '`git_policy: STAGE-not-commit` **and** the return JSON shape' \
  "work-item SKILL.md's Constraints row still names the 'git_policy: STAGE-not-commit' literal Gate 1 reads"
pin "$WI/references/pre-flight.md" 'git_policy: STAGE-not-commit' \
  "pre-flight.md carries the 'git_policy: STAGE-not-commit' literal Gate 1 reads"
pin "$WI/references/handoff-contract.md" 'git_policy: STAGE-not-commit' \
  "handoff-contract.md carries the 'git_policy: STAGE-not-commit' literal Gate 1 reads"

# ---------------------------------------------------------------------------
# Memory-bank harvest contracts. The harvest has no verb since the conversion
# (close/references/harvest.md §7 — "you are the writer"), which makes these
# prose-only contracts the harvest's only mechanical surface. They were held
# by the deleted test-harvest.sh section F; deleting the producer must not
# delete the guard on what it guarded.
# ---------------------------------------------------------------------------
CLOSE="$HERE/../skills/close"

# #717: pin the operative exception, regardless of line wrapping.
_close_flat="$(mktemp)"
awk '{s=s " " $0} END {gsub(/[[:space:]]+/, " ", s); print s}' "$CLOSE/SKILL.md" > "$_close_flat"
pin "$_close_flat" 'In a paired canonical repo, use a subshell `(cd <ai-workspace> && oss …)` for every `oss` call; keep the session directory unchanged.' \
  'close sanctions a workspace subshell without changing the session directory (#717)'
rm -f "$_close_flat"
_doctor_flat="$(mktemp)"
awk '{s=s " " $0} END {gsub(/[[:space:]]+/, " ", s); print s}' "$HERE/../skills/doctor/SKILL.md" > "$_doctor_flat"
pin "$_doctor_flat" 'from a paired canonical repo, `(cd <ai-workspace> && oss …)` is a subshell, not a session `cd`.' \
  'doctor names the workspace subshell as no session cd (#717)'
rm -f "$_doctor_flat"

# The §9 heading is matched by EXACT STRING at harvest time. If the contract
# that pins it and the ceremony that greps it ever disagree, every report reads
# as "no suggestions" and the harvest is silently empty at "wrote 0".
# D4: report-contract.md states the heading four times (template, definition
# row, a second example, the rename note), so the pin goes on the row that
# DEFINES it - the one a reader acts on - and the needle is unique there.
_H9='## 9. Suggestions for memory bank'
pin "$WI/references/report-contract.md" '| `## 9. Suggestions for memory bank` | Patterns or invariants worth keeping.' \
  "report-contract.md's section table does not define the byte-exact heading '## 9. Suggestions for memory bank'"
pin "$CLOSE/references/harvest.md" "$_H9" \
  "harvest.md does not carry the byte-exact heading '$_H9'"

# Step 9 of the spine-close checklist must still route to the ceremony's only
# copy — a step that names no reference is a caller that does not call.
if grep -Fq -- 'references/harvest.md' "$CLOSE/references/spine-close.md"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: spine-close.md step 9 does not route to 'references/harvest.md'"
fi

# The two-file allowlist the apply holds in prose must name the same two files
# the ceremony tells the reader to choose between. D4: each name recurs four
# times in harvest.md, so the pin lands on the allowlist ROW itself (the name
# followed by the table's closing pipe), where it occurs once.
pin "$CLOSE/references/harvest.md" '`09-known-issues.md` |' \
  "harvest.md's allowlist does not name the allowlisted target '09-known-issues.md'"
pin "$CLOSE/references/harvest.md" '`10-decisions-log.md` |' \
  "harvest.md's allowlist does not name the allowlisted target '10-decisions-log.md'"


# --- The manifest refusal: one string, three hardcoded copies -----------------
# Skills may not `source` the libs, so a ceremony that must print the refusal
# verbatim has no choice but to carry the literal. That makes drift the default:
# #272/#310 changed the refusal to name the topology remedies and two ceremonies
# kept printing the pre-topology text, sending a topology-only project to
# /init-workspace. No runtime signal - the ceremony refuses correctly, with the
# wrong remedy. Discovered by grep rather than a fixed list, so a fourth copy is
# covered the moment it is written.
OSSLIB="$HERE/../lib"
OSSSK="$HERE/.."
_refusal_literal() { sed -n 's/^[^"]*"//; s/"$//p' "$1"; }

REF_LIB="$(sed -n 's/^OSS_MANIFEST_REFUSAL="\(.*\)"$/\1/p' "$OSSLIB/manifest.sh")"
if [ -n "$REF_LIB" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: cannot read OSS_MANIFEST_REFUSAL from lib/manifest.sh - the parity checks below are vacuous"
fi

# Every prose file printing the refusal's opening clause must print all of it.
REF_COPIES="$({ grep -rl 'ossify requires a topology declaration' "$OSSSK/skills" "$OSSSK/commands" || true; } | sort)"
REF_N="$(printf '%s\n' "$REF_COPIES" | { grep -c . || true; })"
if [ "$REF_N" -ge 3 ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: only $REF_N prose copy/copies of the manifest refusal found - expected the start, plan-release and plan-spine probes at minimum"
fi

# A pipe into `while` runs the loop in a SUBSHELL and every t_assert_eq inside
# it increments a counter that dies with it - the summary would report a clean
# run having asserted nothing. Read from a file instead.
REF_LIST="$(mktemp)"; printf '%s\n' "$REF_COPIES" > "$REF_LIST"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  # EVERY occurrence in the file, not `head -1`. A file carrying two copies had
  # only its first checked, so the second could drift silently - which is the
  # same hole one file up: this guard exists because copies drift, and a guard
  # that checks one copy per file reintroduces it within the file.
  n=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n=$((n+1))
    t_assert_eq "$REF_LIB" "$(printf '%s' "$line" | sed 's/^[^"]*"//; s/"$//')" \
      "$(basename "$(dirname "$f")")/$(basename "$f") copy #$n prints OSS_MANIFEST_REFUSAL byte-identically"
  done <<EOF
$({ grep -F 'ossify requires a topology declaration' "$f" || true; })
EOF
  if [ "$n" -gt 0 ]; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: $f matched the refusal grep but yielded no line to compare - the assertions above are vacuous"
  fi
done < "$REF_LIST"
rm -f "$REF_LIST"

# --- /start's topology probe must not halt ----------------------------------
# The block printed the refusal then `exit 0`, while the paragraph under it said
# to author a topology and carry on. A model following the block stopped; one
# following the prose proceeded - and the no-manifest project is exactly the
# case /start exists to serve, so the halt made the headline feature of
# #272/#310 unreachable through its own ceremony. Mechanical fact, mechanical
# check: the probe block carries no exit.
# The probe is no longer the first bash block — the dispatcher-resolution
# recipe precedes it — so select the block that actually carries `state_path`.
PROBE="$(awk '/^```bash$/{inb=1; buf=""; next} inb && /^```$/{if (buf ~ /state_path/) {printf "%s", buf; exit} inb=0; next} inb{buf=buf $0 "\n"}' "$OSSSK/skills/start/SKILL.md")"
if printf '%s' "$PROBE" | grep -q 'state_path'; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: no bash block in start/SKILL.md carries state_path - the exit check below is vacuous"
fi
case "$PROBE" in
  *exit*) T_FAIL=$((T_FAIL+1)); echo "FAIL: start/SKILL.md's topology probe carries an 'exit' - a refused probe must author and proceed, not halt" ;;
  *)      T_PASS=$((T_PASS+1)) ;;
esac

# --- The remote-redaction contract (PR #345 rounds 3 and 6) -------------------
#
# Two documents redact credentials out of a git remote before printing it:
# wayfinder/references/tracker.md and close/references/boundary-audit.md. The
# same defect has now been found in each of them separately - round 3 fixed
# tracker.md's lowercase-only scheme, and round 6 found boundary-audit.md still
# lowercase-only AND https-only. Fixing one site and not the other is the
# failure this check exists to stop, so the ladder runs against BOTH, extracted
# from the prose rather than restated here: a test carrying its own copy of the
# pattern passes while the shipped document rots.
_redactor() { # $1=file - the sed expression the document actually ships
  { grep -o "sed -E 's#[^']*'" "$1" || true; } | head -1
}
# The two documents redact DIFFERENT INPUT SHAPES, and feeding one the other's
# shape fails against correct prose: tracker.md filters a bare URL from
# `git remote get-url` and anchors at ^, boundary-audit.md filters whole
# `git remote -v` lines (name<TAB>url<TAB>(fetch)) and cannot anchor. The
# ladder is about credentials surviving, not about line shape, so each document
# is fed what it actually reads.
_shape_for() { case "$1" in *tracker.md) printf '%s\n' "$2" ;; *) printf 'origin\t%s\t(fetch)\n' "$2" ;; esac; }
for doc in "$OSSSK/skills/wayfinder/references/tracker.md" \
           "$OSSSK/skills/close/references/boundary-audit.md"; do
  name="$(basename "$doc")"
  red="$(_redactor "$doc")"
  # Non-emptiness FIRST: an extraction that found nothing would redact nothing
  # and every leak assertion below would pass against an empty filter.
  if [ -n "$red" ]; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: no sed redactor extracted from $name - the leak ladder below is vacuous"; continue
  fi
  # Proof the extracted filter is load-bearing at all: a plain credential must
  # not survive it. Without this, a filter that is merely INERT passes the
  # whole ladder, since every case below only asserts a secret is absent.
  plain="$(_shape_for "$doc" 'https://secret@github.com/o/r.git' | eval "$red")"
  case "$plain" in
    *secret*) T_FAIL=$((T_FAIL+1)); echo "FAIL: $name does not redact even a plain lowercase https credential" ;;
    *)        T_PASS=$((T_PASS+1)) ;;
  esac
  # Each case pairs a remote with the secret that must not survive it. Scheme
  # casing (git preserves it), non-https schemes, and a password containing '@'
  # (a greedy match to the LAST '@' before the first '/', not the first).
  while IFS='|' read -r url secret why; do
    [ -n "$url" ] || continue
    out="$(_shape_for "$doc" "$url" | eval "$red")"
    case "$out" in
      *"$secret"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: $name leaked '$secret' from $url - $why" ;;
      *)           T_PASS=$((T_PASS+1)) ;;
    esac
  done <<'EOF'
HTTPS://s3cr3t@github.com/o/r.git|s3cr3t|git preserves scheme casing, so an https?-only pattern prints it unchanged
ssh://user:p4ssw0rd@gitlab.example.com/o/r.git|p4ssw0rd|credentials are not an https-only affair
https://user:p@sstail@github.com/o/r.git|sstail|[^/@]+@ stops at the first @ and leaves the rest of the password
https://x-access-token:ghs_faketoken123@github.com/o/r.git|ghs_faketoken123|the token form git credential helpers actually write
EOF
done

# --- /adopt's completion floor (issue #303) -----------------------------------
#
# #303: two adopt pilots closed green on `oss doctor` with an empty registry -
# the state gate proves integrity, never completeness. The floor that fixes it
# lives in adopt §6 as prose, so prose tokens are its only mechanical surface.
# Pin CLAUSE FRAGMENTS, not bare nouns: round 1 of the #365 review measured the
# first version of this row vacuous for two of three refusal conditions - bare
# 'posture' and 'per-station lines' survived their bullets' deletion via the
# output-table rows. Every token below occurs exactly once in §6's span, inside
# the clause it pins; a narrowing pass that drops a refusal condition, the
# parity arm, or the waiver attribution goes red here, not in the next pilot.
_adopt6="$(awk '/^## 6\. Outputs/{f=1} /^## 7\./{f=0} f' "$OSSSK/skills/adopt/SKILL.md")"
if [ -n "$_adopt6" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: cannot extract adopt §6 - the floor checks below are vacuous"
fi
for tok in 'The completion floor comes first' 'journey table is absent' \
           'per step it marks' 'operator-confirmed' 'the posture bone is absent' \
           'outside its four' 'no closed `Release 0`' 'its stub retrospective absent' \
           'lacks the per-station lines' 'no C2 result line for a declared repo' \
           'a C2 result line per declared repo' 'a class P halt at C4, after C2 left zero `shipped` steps, is a halt'; do
  case "$_adopt6" in
    *"$tok"*) T_PASS=$((T_PASS+1)) ;;
    *) T_FAIL=$((T_FAIL+1)); echo "FAIL: adopt §6 no longer carries floor token '$tok'" ;;
  esac
done

# --- The risk-gate CSV grammar, stated once and enforced (#340) ---------------
#
# #340: the prose called controls "a free-text CSV" of "phrases" while the
# splitter cut on every bare comma — the prose invited the input that
# corrupted three of four gates on the pilot, and the append-only journal
# made it unrepairable. The grammar now lives ONCE in risk-gates.md §3; the
# verbs enforce it mechanically. This row pins both halves to each other:
# the grammar sentence must survive rewording, and the corrective verb the
# prose names must exist in the dispatcher surface.
RG="$OSSSK/skills/start/references/risk-gates.md"
for tok in 'bare `,` separates entries' 'literal comma inside an entry' \
           'risk_gate_set_controls' 'spell multiple directories as multiple entries'; do
  if /usr/bin/grep -Fq "$tok" "$RG"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: risk-gates.md no longer carries grammar token '$tok'"
  fi
done
# D4: the verb name recurs (its definition and its usage string), so pin the
# DEFINITION - `oss <verb>` dispatches to `oss_cmd_<verb>`, which is exactly what
# the prose promises the reader can call.
pin "$OSSSK/lib/commands.sh" 'oss_cmd_risk_gate_set_controls()' \
  "risk-gates.md names risk_gate_set_controls but the dispatcher defines no oss_cmd_risk_gate_set_controls - the prose promises a repair path that does not exist"

# --- /adopt authors a topology too (PR #345 round 6) --------------------------
#
# Round 6: plugin.json and /start's own refusal text both promise that /adopt
# authors .ossify/topology.json, while adopt's A1 gate read as refusal-only and
# stopped at the failed probe - the promise was unhonoured, not merely
# undocumented. The mechanical half of that is a three-document parity fact: if
# someone narrows the claim, all three must move together.
# D4 (#747): the loop's needles were the bare words `adopt` and `author`, which
# recur 39 and 13 times in adopt/SKILL.md alone - losing the promise kept the
# check green. Each document's own pairing sentence is pinned instead, once.
pin "$OSSSK/.claude-plugin/plugin.json" '/ossify:start and /ossify:adopt author .ossify/topology.json themselves' \
  "plugin.json's description no longer promises that /ossify:adopt authors .ossify/topology.json - the other two still promise it"
pin "$OSSSK/skills/start/SKILL.md" '/ossify:start and /ossify:adopt author one (.ossify/topology.json)' \
  "start/SKILL.md's topology refusal no longer promises that /ossify:adopt authors one - the other two still promise it"
pin "$OSSSK/skills/adopt/SKILL.md" '**A1 — topology declaration resolves, or is authored here.**' \
  "adopt/SKILL.md's A1 no longer says the topology declaration resolves, or is authored here"

# --- phase 2: the abandoned carve-out's own claims, held mechanically --------
#
# Three sites, each with the same failure shape this file exists for: the words
# are the whole guard, and nothing else in the suite can see them drift.
#
# (a) work-item close must READ the status before it diagnoses a missing
# worktree (#531 site 1). A direct `/close <abandoned-id>` routes into this
# document, its §1 block halts on the absent worktree, and the prose then asserts
# the CAUSE - "the lane skipped work_item_exec" - which is wrong for a withdrawn
# item (never dispatched) and sends the operator to the wrong remedy. The block
# is one of this file's D rows (deferred, never executed by the suite), so this
# assertion is its only hold.
WIC="$OSSSK/skills/close/references/work-item-close.md"
# This file grepped text until now; site (a) needs the SHARED block extractor
# (tests/lib/blocks.sh), the same one test-close.sh and test-block-ledger.sh use,
# because the claim is about a block's internals rather than a line's presence.
. "$HERE/lib/blocks.sh"
_PC_TMP="$(mktemp -d)"; _F="$_PC_TMP/wic-block.sh"
if oss_block_extract "$WIC" 'no recorded worktree for' "$_F" 2>/dev/null && [ -s "$_F" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md §1's block no longer extracts - the checks below are vacuous"
fi
# The status read and the abandoned arm must both be there, and the arm must come
# BEFORE the worktree halt: an arm placed after it is unreachable, because the
# halt exits first.
_ab_line="$(grep -n 'abandoned' "$_F" | head -1 | cut -d: -f1)"
_halt_line="$(grep -n 'no recorded worktree' "$_F" | head -1 | cut -d: -f1)"
if [ -n "$_ab_line" ] && [ -n "$_halt_line" ] && [ "$_ab_line" -lt "$_halt_line" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md §1 does not test for 'abandoned' BEFORE the missing-worktree halt (ab=${_ab_line:-none} halt=${_halt_line:-none}) - an abandoned item is told the lane skipped work_item_exec"
fi
if grep -Fq 'status' "$_F" ; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md §1's block never reads .status - it cannot tell a withdrawn item from a skipped dispatch"
fi
# The TEST, not just the word: the block must COMPARE the status against
# 'abandoned'. Asserting merely that "abandoned" appears in the block passes on
# the message text alone, so a block that reads the status and then ignores it
# (or tests something else) would satisfy the weaker form - measured by mutation.
if grep -Fq '= "abandoned"' "$_F" || grep -Fq "= 'abandoned'" "$_F"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md §1 does not COMPARE the status against 'abandoned' - naming it in a message is not testing it"
fi
# The route out must not leave the SAME trap the release-close halt did: if this
# item's spine is already closed, un-withdrawing it puts a planned item inside a
# closed spine, which release close's tag selector then accepts. And the arm may
# not prescribe reopening it either: close leaves the spine's integration branch
# landed in every hosting repo, and the lane's re-entry arm
# (round-orchestration.md section 2b) would route the un-withdrawn item onto a
# branch nothing merges again, so the arm has to name THAT obstruction and the
# route that can run - a new spine. The first form of this assertion pinned
# `spine_status`, i.e. the reopen that does not work; it was replaced when the
# round-3 review proved it out, and updated again when 1.14.0's re-entry arm
# replaced the halt.
for _lit in 'work_item_status' 'spine_add' 'round-orchestration.md' 'decomposition.md'; do
  if grep -Fq "$_lit" "$_F"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md §1's abandoned arm does not name '$_lit'"
  fi
done
# (c) THE ARM MAY NOT ASSUME THE ITEM HAS NO DISPATCH ANY MORE (P1-B, the operator's
# ruling of 2026-09-23; round-3 finding at work-item-close.md:43). The arm used to
# assert "it has no worktree by construction" and "nothing should be reconstructed
# for it" - impossible for the state the narrowing ships, because an `abandoned`
# item that records a dispatch field is exactly what the dropped mirror arm used to
# prevent and doctor's §5 exists to report. It is this file's D row (never executed
# by the suite), so this is its only hold, and the checks pull in opposite
# directions ON PURPOSE: the recorded fields must be READ and NAMED, and the
# impossibility must be GONE. Either one alone is satisfiable by a mutation.
#
# Both positive checks are scoped to the DRIFT BRANCH's own message line, not to
# the whole block: an unscoped `grep -Fq 'work_item_status $wi planned'` is
# satisfied by the CLEAN branch's identical route further down, so deleting the
# route from the branch that needs it would stay green - the substring-satisfied-
# by-another-line trap this file has now been bitten by twice (the -A 8 window in
# §5, and the field list whose explanation carried the field name).
_drift="$(grep -F 'records a dispatch field' "$_F" || true)"
_case="$(grep -A 1 'is abandoned AND records a dispatch field' "$_F" || true)"
_rec_read="$(grep -F 'select(.id==' "$_F" | grep -F 'base_sha' || true)"
if [ -n "$_case" ] && case "$_case" in *'work_item_status $wi planned'*) true;; *) false;; esac; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md §1's drift branch does not name the record repair (work_item_status \$wi planned) in its OWN message - the operator is left with a halt and no route for the one pair that needs it"
fi
# The fields must be READ, not just mentioned: the arm's state read is the line that
# selects the item and names the three fields. The read and the message are two
# different lines in the block, so each half is checked where it actually lives.
_read_ok=1
for _f3 in '.branch' '.worktree_path' '.base_sha'; do
  case "$_rec_read" in *"$_f3"*) ;; *) _read_ok=0;; esac
done
if [ "$_read_ok" = 1 ] && case "$_drift" in *'drift'*) true;; *) false;; esac; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md §1's abandoned arm does not read all three dispatch fields and name the drift pair they form - it still tells the operator to skip an item the record says was dispatched"
fi
if grep -Fq 'by construction' "$_F"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md §1's abandoned arm re-asserts 'by construction' - an abandoned item CAN record a dispatch field (the drift pair), so the impossibility claim is exactly the trap this row exists to catch"
else
  T_PASS=$((T_PASS+1))
fi

# (b) the withdrawal arm's demo-ledger remedy must WORK (#531 site 3 / F15). The
# sentence shipped in 1.11.0 said a demo line the withdrawn item alone was going
# to add "goes the same way" as a pending amendment - pointing at ledger_unplan,
# which answers rc 7 for an ordinary active line. The line stays active, its
# implementation was withdrawn, and it then blocks this spine and every later
# cumulative demo. The remedy for that case is retire/replace.
DECOMP="$OSSSK/skills/plan-spine/references/decomposition.md"
if grep -Fq 'goes the same way' "$DECOMP"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: decomposition.md §1 still says a demo line 'goes the same way' - that points at ledger_unplan, which cannot clear an active line"
else
  T_PASS=$((T_PASS+1))
fi
_wd_para="$(grep -A 14 'Any demo line the withdrawn item alone' "$DECOMP")"
case "$_wd_para" in
  *ledger_retire*|*ledger_supersede*) T_PASS=$((T_PASS+1));;
  *) T_FAIL=$((T_FAIL+1)); echo "FAIL: decomposition.md §1's withdrawal arm names neither ledger_retire nor ledger_supersede for the active-line case - the remedy is unreachable from the text";;
esac
case "$_wd_para" in
  *"rc 7"*) T_PASS=$((T_PASS+1));;
  *) T_FAIL=$((T_FAIL+1)); echo "FAIL: decomposition.md §1's withdrawal arm does not say why ledger_unplan fails there (rc 7) - the operator retries it";;
esac
# The INVOCATION, not the verb name: `ledger_retire`/`ledger_supersede` take
# <line-id> <spine-id> <reason> (lib/commands.sh declares _oss_need 3 for both),
# so the two-argument forms this paragraph shipped exit 2 and plan nothing. The
# OLD form is the search term - it is what a regression here would be phrased in.
case "$_wd_para" in
  *"ledger_retire <line-id> <spine-id>"*|*"ledger_supersede <line-id> <spine-id>"*) T_PASS=$((T_PASS+1));;
  *) T_FAIL=$((T_FAIL+1)); echo "FAIL: decomposition.md §1's remedy does not name the by-spine argument - a two-argument ledger_retire/ledger_supersede exits 2";;
esac
case "$_wd_para" in
  *"ledger_retire <line-id> <reason>"*|*"ledger_supersede <line-id> <new-line-id>"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: decomposition.md §1's remedy still shows a two-argument form (it exits 2) - or supersede's second argument as a replacement line id, which it is not";;
  *) T_PASS=$((T_PASS+1));;
esac
case "$_wd_para" in
  *"demo-amendments.md"*) T_PASS=$((T_PASS+1));;
  *) T_FAIL=$((T_FAIL+1)); echo "FAIL: decomposition.md §1's remedy does not cite demo-amendments.md - the document that owns the keying rule the amendment depends on";;
esac

# (c) doctor's zero-match touch-surface sweep (#523). This is the DETECTOR the
# 1.11.0 re-point verbs never had, and it is agent-performed prose, so the facts
# without which it is unexecutable must be present IN THE RECIPE: the semantics
# oracle (touch_check - never a hand-rolled glob match, because a shell `*`
# crosses `/`, so a matcher written there would disagree with the verb that
# decides reclassification) and the corpus (git ls-files, per declared repo). The
# exclusion must be present too, or every deliberately-matching-nothing surface
# becomes a false finding. Asserting the block's own content rather than a
# mention somewhere in the file: measured by mutation, a file-level grep passes
# while the recipe no longer calls the oracle.
SKILLS="$HERE/../skills"
SI="$SKILLS/doctor/references/state-inspection.md"
_SW="$_PC_TMP/sweep-block.sh"
if oss_block_extract "$SI" 'ls-files -z' "$_SW" 2>/dev/null && [ -s "$_SW" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: state-inspection.md §5's touch-surface sweep block no longer extracts - the checks below are vacuous"
fi
# The INVOCATION form, not the word: the block's own comment explains what the
# oracle is, so a word-grep passes on the comment while the recipe no longer
# calls it - measured by mutation.
if grep -Fq 'oss touch_check' "$_SW" && grep -Fq 'ls-files' "$_SW"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the §5 sweep recipe does not INVOKE both the oracle (oss touch_check) and the corpus (git ls-files)"
fi
# D4: `not-applicable` occurs three times in the file (a comment and two prose
# paragraphs), so the pin lands on the paragraph that states the exclusion - the
# one a reader acts on (state-inspection.md §5's shape rules).
pin "$SI" 'a surface whose list carries `not-applicable`' \
  "state-inspection.md's surface sweep does not name 'not-applicable' - every deliberate placeholder becomes a false finding"


# (d) the §5 sweep must RUN, and must not read a failure as an absence (#523).
# It shipped classified ILLUSTRATIVE, and the review of #555 found two defects
# in its logic that no execution could see: `$repos` was never assigned anywhere
# in the doctor skill, and an unreadable repo read as a zero-match. Either one
# turns EVERY bone and gate into a finding - the false-positive cascade the
# check exists to prevent, inverted. The block is OPERATIVE by the ledger's own
# rule (control flow, rc handling, and a variable one step assigns and a later
# step consumes), so it is extracted AND executed here against a real repo.
# That is what moves its ledger row from I to O.
#
# Run with NOTHING injected that the caller does not genuinely supply
# (tests/lib/blocks.sh): `oss` on `$PATH`, `repos` and `sf` ARE the caller's — the last
# because §2 resolves it once for the whole read-out and §5 consumes it, never
# re-deriving the precedence (#561 round 1, R14). Everything else the block must
# establish itself.
OSS="$HERE/../bin/oss"
OSSDIR="$(dirname "$OSS")"   # the extracted blocks call `oss` by name, so the dispatcher goes on PATH
SWWS="$_PC_TMP/sweepws"; mkdir -p "$SWWS/.ossify" "$SWWS/canon"
SWS="$SWWS/state.json"
# The state is ROUTED at $SWS and also exported as $OSS_STATE_FILE - the same
# project either way, which is the pairing #561's gate accepts. An override that
# is NOT this directory's manifest-routed state must skip the sweep instead, and
# so must a route that cannot be resolved at all (the round-1 R1 bypass).
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s"},"gone":{"root":"%s"}},"well_known_paths":{"project_state":"%s"}}\n' \
  "$SWWS/canon" "$SWWS/absent" "$SWS" > "$SWWS/.ossify/topology.json"
( cd "$SWWS/canon" && git init -q . && : > tracked.txt && git add tracked.txt \
  && git -c user.email=t@t -c user.name=t commit -qm fixture ) >/dev/null 2>&1
( cd "$SWWS" && OSS_STATE_FILE="$SWS" bash "$OSS" init "sweep" ) >/dev/null 2>&1
( cd "$SWWS" && OSS_STATE_FILE="$SWS" bash "$OSS" bone_add ADR-9091 "on a tracked file" "tracked.txt" ) >/dev/null 2>&1
( cd "$SWWS" && OSS_STATE_FILE="$SWS" bash "$OSS" bone_add ADR-9092 "on nothing" "nowhere/at/all/**" ) >/dev/null 2>&1
( cd "$SWWS" && OSS_STATE_FILE="$SWS" bash "$OSS" risk_gate_add RG-7 "also/nowhere/**" "packages/core/**" ) >/dev/null 2>&1
# cd in the MAIN shell, not a subshell: t_capture/t_assert mutate the T_PASS/
# T_FAIL globals, and a subshell's mutations never propagate (test-manifest.sh
# documents the vacuous-green trap this avoids).
cd "$SWWS"
t_capture env OSS_STATE_FILE="$SWS" "PATH=$OSSDIR:$PATH" sf="$SWS" repos="$(printf 'canonical\ngone')" bash -c \
  "set -euo pipefail; . '$_SW'; printf 'HITS%s\n' \"\$(cat \"\$hits\")\"; printf 'SKIPPED[%s]\n' \"\$skipped\"; printf 'ROSTER%s\n' \"\$roster\"; printf 'KINDS%s\n' \"\$(printf '%s' \"\$roster\" | jq -r '[.[].kind]|join(\",\")')\"; printf 'INHITS%s\n' \"\$(grep -c ADR-9092 \"\$hits\" 2>/dev/null || true)\""
cd "$HERE"
t_assert_rc 0 "(d) the sweep COMPLETES with a declared repo unreadable - it reports the skip rather than exiting the whole run"
t_assert_contains "$T_OUT" "skip: touch(gone)" "(d) ... naming the unreadable repo by key, in the §1 grammar"
t_assert_contains "$T_OUT" "bone ADR-9091" "(d) ... recording the surface that matched a tracked file"
t_assert_contains "$T_OUT" "INHITS0" "(d) ... and the zero-match surface is NOT among the hits - counted from the file itself, so the roster naming the same id cannot mask it"
t_assert_contains "$T_OUT" "SKIPPED[ gone]" "(d) ... and feeding \$skipped, which the prose's partial-corpus rule reads"
# The ROSTER: touch_check answers "<kind> <id>" per match and never the glob,
# so a warn line naming "the id and the glob list" has no other source. Without
# this read the report's second half is unfillable and the `not-applicable`
# exclusion is unreadable - the same unassigned-variable class as $repos.
t_assert_contains "$T_OUT" "ADR-9092" "(d) ... and $roster carrying a surface that matched NOTHING, which is exactly the one a warn line names"
t_assert_contains "$T_OUT" "nowhere/at/all/**" "(d) ... with its glob list, which touch_check's own output cannot supply"
# #561 (1): the roster must ALSO carry the surface KIND. It is what decides
# which re-point verb a warn line's remedy names (`bone_set_touch` vs
# `risk_gate_set_touch`), and for a surface that matched NOTHING `touch_check`
# emits no line at all, so the kind has no other source. Both branches of the
# projection are exercised: two bones and a risk gate.
t_assert_contains "$T_OUT" "KINDSbone,bone,risk_gate" "(d) ... and the KIND of every surface, in touch_check's own vocabulary - the only thing that picks the re-point verb"
# G4: with EVERY declared repo unreadable the read set is EMPTY, and the sweep
# must report that rather than one absence per surface. Run from the workspace so
# the route resolves: this arm is about the corpus loop, and the foreign-state
# gate above would refuse first from a directory with no manifest (round 1, R1).
cd "$SWWS"
t_capture env OSS_STATE_FILE="$SWS" "PATH=$OSSDIR:$PATH" sf="$SWS" repos="gone" bash -c "set -euo pipefail; . '$_SW'; echo DONE"
t_assert_rc 0 "(d) a read set that came back EMPTY does not abort the sweep"
t_assert_contains "$T_OUT" "no declared repo could be read" "(d) ... it reports that the sweep inspected nothing, rather than reporting every healthy surface as unmatched"
# The corpus arm: `repos` UNSET under strict mode. This is the shipped defect
# (an unassigned variable), so it is run with NOTHING injected.
t_capture env OSS_STATE_FILE="$SWS" "PATH=$OSSDIR:$PATH" sf="$SWS" bash -c "set -euo pipefail; . '$_SW'; echo DONE"
t_assert_rc 0 "(d) an unset \$repos does not abort the sweep under strict mode"
t_assert_contains "$T_OUT" "skip: touch - the declared repo keys could not be read" "(d) ... it says the sweep did not run, instead of sweeping an empty corpus and reporting every surface"
cd "$HERE"
# The registry arm: a batch that is INCONCLUSIVE leaves no hits either, so an
# unreadable registry must not read as a whole-corpus absence. The workspace's
# OWN route resolves to the broken state, so the foreign-state gate above is
# satisfied and this arm still reaches touch_check's rc 2 (round 1, R1: an
# unresolvable route now refuses before this point).
SWBRK="$_PC_TMP/brokenroute"; mkdir -p "$SWBRK/.ossify"
printf '%s\n' '{"schema_version":2}' > "$SWBRK/broken-state.json"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{"project_state":"%s/broken-state.json"}}\n' \
  "$SWBRK" "$SWBRK" > "$SWBRK/.ossify/topology.json"
cd "$SWBRK"
t_capture env -u OSS_STATE_FILE "PATH=$OSSDIR:$PATH" sf="$SWBRK/broken-state.json" repos="canonical" bash -c "set -euo pipefail; . '$_SW'; echo DONE"
cd "$HERE"
t_assert_rc 0 "(d) an unreadable registry does not abort the sweep"
t_assert_contains "$T_OUT" "registry could not be read" "(d) ... it reports the registry failure, so an empty \$hits is not read as every surface matching nothing"
# The resolver arm: touch_check returns its RESOLVER's rc 1 before it ever looks
# at the registry - measured, so rc 1 there is indistinguishable from "clean" and
# the rc alone cannot catch it. Only a second probe can, which is why one exists.
SWBR="$_PC_TMP/badroute"; mkdir -p "$SWBR/.ossify"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s"}},"well_known_paths":{"project_state":"${repos.nosuch.root}/ps.json"}}\n' \
  "$SWBR/canon" > "$SWBR/.ossify/topology.json"
cd "$SWBR"
t_capture env -u OSS_STATE_FILE "PATH=$OSSDIR:$PATH" repos="canonical" bash -c "set -euo pipefail; . '$_SW'; echo DONE"
cd "$HERE"
t_assert_rc 0 "(d) an unresolvable state route does not abort the sweep"
t_assert_contains "$T_OUT" "state could not be resolved or read" "(d) ... it reports that instead of an absence, even though touch_check's rc 1 there looks exactly like clean"
# #561 (2): the sweep must NOT run when the state in play is not this
# directory's manifest-routed state. That is §4's worktree gate, and it is this
# block's own hazard: with $OSS_STATE_FILE pointing at ANOTHER workspace's state,
# every surface THAT state knows and these repos do not is reported as matching
# no tracked file, after inspecting the wrong corpus, with every command exiting
# 0. An unset `hits` and an unset `roster` are the signature of "did not run".
SWF="$_PC_TMP/foreignws"; mkdir -p "$SWF/.ossify" "$SWF/canon"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{"project_state":"%s/state.json"}}\n' \
  "$SWF" "$SWF" > "$SWF/.ossify/topology.json"
( cd "$SWF" && env -u OSS_STATE_FILE bash "$OSS" init foreign >/dev/null && env -u OSS_STATE_FILE bash "$OSS" bone_add ADR-7777 "a foreign-only surface" "foreign/only/**" ) >/dev/null 2>&1
cd "$SWWS"
t_capture env OSS_STATE_FILE="$SWF/state.json" "PATH=$OSSDIR:$PATH" sf="$SWF/state.json" repos="canonical" bash -c \
  "set -euo pipefail; . '$_SW'; printf 'HITS[%s]\n' \"\${hits:-unset}\"; printf 'ROSTER[%s]\n' \"\${roster:-unset}\""
cd "$HERE"
t_assert_rc 0 "#561: a foreign state does not abort the sweep"
t_assert_contains "$T_OUT" "skip: touch - the state in play" "#561 ... it refuses the run in the §1 grammar, naming the state in play against the routed answer"
t_assert_contains "$T_OUT" "HITS[unset]" "#561 ... and nothing was swept: \$hits was never created"
t_assert_contains "$T_OUT" "ROSTER[unset]" "#561 ... and no foreign registry was read, so no warn line can be composed from it"
# ROUND 1, R1: the gate must not be bypassed by a route that resolves to
# NOTHING. A topology whose `project_state` value is relative makes
# `oss state_path` refuse, and the old gate read that empty answer as
# consent (its `[ -n "$routed" ] &&` guard) and swept a foreign registry against
# this directory's repos. "Cannot be compared" is not "the same project".
SWREL="$_PC_TMP/relroute"; mkdir -p "$SWREL/.ossify" "$SWREL/canon"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{"project_state":"./state.json"}}\n' \
  "$SWREL" > "$SWREL/.ossify/topology.json"
cd "$SWREL"
t_capture env OSS_STATE_FILE="$SWF/state.json" "PATH=$OSSDIR:$PATH" sf="$SWF/state.json" repos="canonical" bash -c \
  "set -euo pipefail; . '$_SW'; printf 'HITS[%s]\n' \"\${hits:-unset}\""
cd "$HERE"
t_assert_rc 0 "#561 R1: an unresolvable route does not abort the sweep"
t_assert_contains "$T_OUT" "is not this directory's manifest-routed state" "#561 R1 ... it refuses: an empty routed answer is not consent to compare"
t_assert_contains "$T_OUT" "unresolved" "#561 R1 ... and the line says the route could not be resolved"
t_assert_contains "$T_OUT" "HITS[unset]" "#561 R1 ... and nothing was swept against this directory's repos"
# CONTROL: with NO override the same fixture still sweeps - the gate refuses a
# foreign state, not every run, and the routed state's roster still fills.
cd "$SWWS"
t_capture env -u OSS_STATE_FILE "PATH=$OSSDIR:$PATH" sf="$SWS" repos="canonical" bash -c \
  "set -euo pipefail; . '$_SW'; printf 'HITS%s\n' \"\$(cat \"\$hits\")\"; printf 'KINDS%s\n' \"\$(printf '%s' \"\$roster\" | jq -r '[.[].kind]|join(\",\")')\""
cd "$HERE"
t_assert_contains "$T_OUT" "bone ADR-9091" "#561 control: no override, so the routed state sweeps its corpus"
t_assert_contains "$T_OUT" "KINDSbone,bone,risk_gate" "#561 control: ... and the roster comes from the routed state"
# #558 / ledger line 87, both halves, resolved here.
# (i) the block never removed its `$hits` temp file. The removal is prose the
# agent performs once the warn lines are written, so it must be present OUTSIDE
# the fence and absent INSIDE it - an in-fence removal would empty the report's
# own source.
if grep -Fq 'rm -f "$hits"' "$_SW"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the §5 sweep block deletes \$hits itself - the warn lines are composed FROM that file"
else
  T_PASS=$((T_PASS+1))
fi
if grep -Fq 'once the warn lines are written' "$SI" && grep -Fq 'rm -f "$hits"' "$SI"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the §5 sweep never removes its \$hits temp file - the leak stays open (#558)"
fi
# (ii) the arbitrary fixed batch: xargs splits at the system's own argument
# limit, so `-n 200` only multiplies dispatcher spawns per corpus.
if grep -Fq 'xargs -0 -n 200' "$_SW"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the §5 sweep still batches at a fixed 'xargs -n 200' - one dispatcher per 200 tracked paths (#558)"
else
  T_PASS=$((T_PASS+1))
fi
# R2-2: the legacy key set must exclude ai_workspace, or a planning file under it
# can satisfy a stale product glob and suppress a real warning.
if grep -Fq 'OTHER than `ai_workspace`' "$_SW"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the sweep's corpus comment does not exclude ai_workspace from the legacy pairing-manifest key set - a planning file then satisfies a stale product glob and the zero-match warning is suppressed"
fi
# --- phase (e): §3's bones drift check compares SETS, not counts (#154) -------
#
# Shipped as a cardinality comparison - `.bones | length` against section 4's row
# count - which cannot tell the two documented directions apart. Replace a
# registered bone's index row with a DIFFERENT hand-written id and both counts
# stay at 1 while *both* directions are present, so the check reported clean on
# exactly the drift it exists to find. The block is OPERATIVE by the ledger's
# rule (control flow, a refusal arm, temp files, and a set difference), so it is
# extracted AND executed here, and the fixture asserts its own shape (equal
# counts) so the pin cannot drift into a trivially-unequal case that proves
# nothing.
_E_SVMD="$SKILLS/doctor/references/spec-validation.md"
_E_SV="$_PC_TMP/sv-block.sh"
if oss_block_extract "$_E_SVMD" 'only_reg=' "$_E_SV" 2>/dev/null && [ -s "$_E_SV" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: spec-validation.md §3's drift block no longer extracts - the checks below are vacuous"
fi
_E_WS="$_PC_TMP/driftws"; mkdir -p "$_E_WS/.ossify" "$_E_WS/canon" "$_E_WS/docs"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{"master_spec":"%s/docs/MASTER-SPEC.md","project_state":"%s/.ossify/project-state.json"}}\n' \
  "$_E_WS" "$_E_WS" "$_E_WS" > "$_E_WS/.ossify/topology.json"
( cd "$_E_WS" && env -u OSS_STATE_FILE bash "$OSS" init drift >/dev/null && env -u OSS_STATE_FILE bash "$OSS" bone_add ADR-0002 "the registered bone" "packages/core/**" >/dev/null ) >/dev/null 2>&1
_e_spec() { # $1=ws ; remaining args = section-4 table rows
  local ws="$1"; shift
  {
    printf '# MASTER-SPEC\n\n## 1. Vision\nx\n\n## 2. Posture & boundary\nx\n\n## 3. Feature map\nx\n\n## 4. Bones-registry index\n\n| ADR | Title |\n|---|---|\n'
    printf '%s\n' "$@"
    printf '\n## 5. Journeys\nx\n'
  } > "$ws/docs/MASTER-SPEC.md"
}
_e_run() { ( cd "$1" && PATH="$OSSDIR:$PATH" bash -c "set -euo pipefail; . '$_E_SV'" ); }
# The fixture's own shape: the two counts the OLD rule compared are EQUAL here,
# so a regression back to cardinality reads this fixture as clean and fails (e1).
_e_spec "$_E_WS" '| ADR-9999 | the hand-written row |'
t_assert_eq "$(jq -r '.bones | length' "$_E_WS/.ossify/project-state.json")" \
            "$(awk '/^## 4\./ {f=1; next} /^## / {f=0} f' "$_E_WS/docs/MASTER-SPEC.md" | grep -cE '^[[:space:]]*\|[[:space:]]*ADR-' || true)" \
            "(e) the fixture carries EQUAL registry and index counts - without that this pin stops exercising #154"
# (e1) THE DEFECT: equal counts, both directions present -> BOTH are named.
t_capture _e_run "$_E_WS"
t_assert_rc 0 "(e) the drift check runs to completion on an equal-count mismatch"
t_assert_contains "$T_OUT" "registry entry with no index row: ADR-0002" "(e) ... naming the registered bone the index lost - the direction a count comparison cannot see"
t_assert_contains "$T_OUT" "index row with no registry entry: ADR-9999" "(e) ... AND naming the hand-written row in the same run: equal counts is not a match"
# (e2) CONTROL: the matched pair is clean, and the clean case SPEAKS (doctor's
# own rule: silence is indistinguishable from a pass).
_e_spec "$_E_WS" '| ADR-0002 | the registered bone |'
t_capture _e_run "$_E_WS"
t_assert_rc 0 "(e) the matched spec runs clean"
t_assert_contains "$T_OUT" "ok: spec - bones index matches the registry" "(e) ... and it emits its line rather than staying silent"
if printf '%s' "$T_OUT" | grep -Fq 'no index row'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) the matched fixture still produced a drift finding - the set difference is wrong in the other direction"
else
  T_PASS=$((T_PASS+1))
fi
# (e3) CONTROL: one direction at a time. A comparison that reports both
# directions whenever either fires is a count check wearing a set's clothes, and
# the two directions have different remedies in the table.
_e_spec "$_E_WS" '| ADR-0002 | the registered bone |' '| ADR-0007 | the extra row |'
t_capture _e_run "$_E_WS"
t_assert_contains "$T_OUT" "index row with no registry entry: ADR-0007" "(e) an extra index row alone is named"
if printf '%s' "$T_OUT" | grep -Fq 'registry entry with no index row'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) a one-way mismatch also reported the OTHER direction - the halves are not being compared as sets"
else
  T_PASS=$((T_PASS+1))
fi
# (e3b) ROUND 1, R2: the two halves are compared case-insensitively. An adopted
# series may spell ids either way; the old block upper-cased neither, so a
# lowercase pair matched nothing on both sides and printed a false
# "0 entries, 0 rows" clean, while a mixed-case valid pair read as drift.
_E_WS4="$_PC_TMP/driftws4"; mkdir -p "$_E_WS4/.ossify" "$_E_WS4/canon" "$_E_WS4/docs"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{"master_spec":"%s/docs/MASTER-SPEC.md","project_state":"%s/.ossify/project-state.json"}}\n' \
  "$_E_WS4" "$_E_WS4" "$_E_WS4" > "$_E_WS4/.ossify/topology.json"
( cd "$_E_WS4" && env -u OSS_STATE_FILE bash "$OSS" init lower >/dev/null && env -u OSS_STATE_FILE bash "$OSS" bone_add adr-0002 "a lowercase registry id" "packages/core/**" ) >/dev/null 2>&1
_e_spec "$_E_WS4" '| adr-0002 | the same id, lowercase |'
t_capture _e_run "$_E_WS4"
t_assert_rc 0 "(e) R2: a lowercase pair runs clean"
t_assert_contains "$T_OUT" "matches the registry: 1 entries, 1 rows" "(e) R2 ... it reads the pair as the ONE bone it is, not as the old false clean (\"0 entries, 0 rows\")"
_e_spec "$_E_WS4" '| ADR-0002 | the same id, upper |'
t_capture _e_run "$_E_WS4"
t_assert_contains "$T_OUT" "matches the registry: 1 entries, 1 rows" "(e) R2 ... and a mixed-case valid pair is not reported as drift"
# (e3c) ROUND 1, C1: "one row per registry entry" is the invariant, so a
# duplicated index row is a finding even though the SET is unchanged.
_e_spec "$_E_WS4" '| ADR-0002 | first copy |' '| ADR-0002 | the copy left behind |'
t_capture _e_run "$_E_WS4"
t_assert_rc 0 "(e) C1: duplicate index rows do not abort the check"
t_assert_contains "$T_OUT" "carries more than one row for: ADR-0002" "(e) C1 ... a set comparison that collapses duplicates must still report them"
if printf '%s' "$T_OUT" | grep -Fq 'ok: spec - bones index matches'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) C1: duplicated rows read as a clean match - sort -u hides the second row"
else
  T_PASS=$((T_PASS+1))
fi
# (e3d) ROUND 1, R13: no temp files in this block at all - the comparison runs
# over the two variables, and a mktemp pair is the machinery (and the leak) the
# round-1 review rejected.
if grep -Fq 'mktemp' "$_E_SV" || grep -Fq 'rm -f' "$_E_SV"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) R13: the drift block still round-trips through temp files - comm over the variables needs none"
else
  T_PASS=$((T_PASS+1))
fi
if grep -Fq 'comm -23' "$_E_SV" && grep -Fq 'comm -13' "$_E_SV"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) R13: the block does not compare the two halves with comm"
fi
# (e4) REFUSAL ARM: an index half that cannot be READ is not an EMPTY one. The
# heading is what this recipe reads section 4 by, so its absence must refuse.
printf '# MASTER-SPEC\n\n## Bones\n\n| ADR | Title |\n|---|---|\n| ADR-0002 | x |\n' > "$_E_WS/docs/MASTER-SPEC.md"
t_capture _e_run "$_E_WS"
t_assert_rc 0 "(e) a spec with no readable section-4 heading does not abort the run"
t_assert_contains "$T_OUT" "section 4 carries no" "(e) ... it refuses the comparison instead of reading the index as empty - the same failure-read-as-absence class §5's sweep names"
if printf '%s' "$T_OUT" | grep -Fq 'no index row'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) an unreadable index half was reported as a registry-only mismatch - that is the defect class this pin exists for"
else
  T_PASS=$((T_PASS+1))
fi
# (e5) REFUSAL ARM: the registry half unreadable (jq cannot read `.bones[].adr`),
# which must refuse rather than compare against an empty registry.
_E_WS2="$_PC_TMP/driftws2"; mkdir -p "$_E_WS2/.ossify" "$_E_WS2/canon" "$_E_WS2/docs"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{"master_spec":"%s/docs/MASTER-SPEC.md","project_state":"%s/.ossify/project-state.json"}}\n' \
  "$_E_WS2" "$_E_WS2" "$_E_WS2" > "$_E_WS2/.ossify/topology.json"
printf '%s\n' '{"schema_version":9}' > "$_E_WS2/.ossify/project-state.json"
_e_spec "$_E_WS2" '| ADR-0002 | x |'
t_capture _e_run "$_E_WS2"
t_assert_rc 0 "(e) an unreadable registry does not abort the run"
t_assert_contains "$T_OUT" "could not read the registry half" "(e) ... it names the HALF that failed instead of claiming both, so \"registry rc 5, spec rc 0\" is never printed under a both-halves claim"
if printf '%s' "$T_OUT" | grep -Fq 'both halves'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) R10: the refusal claims both halves while only one failed"
else
  T_PASS=$((T_PASS+1))
fi
if printf '%s' "$T_OUT" | grep -Fq 'no registry entry'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) an unreadable registry read as an EMPTY one - every index row was reported as a hand-written row"
else
  T_PASS=$((T_PASS+1))
fi
# (e7) ROUND 1, C4: a legal NON-NUMERIC ref is compared as a complete value.
# `bone_add` accepts `ADR-C2` (the registry suite's own fixture mints it), so the
# old numeric-substring extractor dropped it from BOTH halves and printed
# "ok: 0 entries, 0 rows" over a registry that has an entry - the same
# failure-read-as-absence class as R2/C1, one step further out.
_E_WS5="$_PC_TMP/driftws5"; mkdir -p "$_E_WS5/.ossify" "$_E_WS5/canon" "$_E_WS5/docs"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{"master_spec":"%s/docs/MASTER-SPEC.md","project_state":"%s/.ossify/project-state.json"}}\n' \
  "$_E_WS5" "$_E_WS5" "$_E_WS5" > "$_E_WS5/.ossify/topology.json"
( cd "$_E_WS5" && env -u OSS_STATE_FILE bash "$OSS" init c4 >/dev/null && env -u OSS_STATE_FILE bash "$OSS" bone_add ADR-C2 "a permitted non-numeric ref" "packages/core/**" ) >/dev/null 2>&1
_e_spec "$_E_WS5"
t_capture _e_run "$_E_WS5"
t_assert_rc 0 "(e) C4: a non-numeric registry ref does not abort the check"
t_assert_contains "$T_OUT" "registry entry with no index row: ADR-C2" "(e) C4 ... it is COMPARED, so its missing row is reported - the old substring extractor printed a false clean"
if printf '%s' "$T_OUT" | grep -Fq 'ok: spec'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) C4: a non-numeric ref was dropped and the registry read as empty"
else
  T_PASS=$((T_PASS+1))
fi
# CONTROLS: the same id compares equal when its row is present, and the numeric
# series reads clean beside it.
_e_spec "$_E_WS5" '| ADR-C2 | the non-numeric ref |'
t_capture _e_run "$_E_WS5"
t_assert_contains "$T_OUT" "matches the registry: 1 entries, 1 rows" "(e) C4 control: the non-numeric id compares equal when its row is present"
( cd "$_E_WS5" && env -u OSS_STATE_FILE bash "$OSS" bone_add ADR-0002 "a numeric ref" "packages/core/**" ) >/dev/null 2>&1
_e_spec "$_E_WS5" '| ADR-C2 | the non-numeric ref |' '| ADR-0002 | the numeric ref |'
t_capture _e_run "$_E_WS5"
t_assert_contains "$T_OUT" "matches the registry: 2 entries, 2 rows" "(e) C4 control: the numeric series still reads clean beside it"
# (e8) C4's refusal arm: a value that is not an ADR reference at all refuses the
# comparison instead of being filtered out of it.
( cd "$_E_WS5" && env -u OSS_STATE_FILE bash "$OSS" bone_add "RFC-2119" "not an adr ref" "packages/core/**" ) >/dev/null 2>&1
t_capture _e_run "$_E_WS5"
t_assert_rc 0 "(e) C4: a non-ADR registry value does not abort the check"
t_assert_contains "$T_OUT" "not an ADR reference ('RFC-2119')" "(e) C4 ... it REFUSES and names the value, instead of dropping it from the comparison"

# (e9) ROUND 2, C6: a duplicate REGISTRY record is reported, not collapsed. A
# legacy or hand-edited state can hold two bone records for one ref; the index
# then has one row, and the old `sort -u` reduced the registry to a set and
# printed ok. Reproduced live before the fix.
_E_WS6="$_PC_TMP/driftws6"; mkdir -p "$_E_WS6/.ossify" "$_E_WS6/canon" "$_E_WS6/docs"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{"master_spec":"%s/docs/MASTER-SPEC.md","project_state":"%s/.ossify/project-state.json"}}\n' \
  "$_E_WS6" "$_E_WS6" "$_E_WS6" > "$_E_WS6/.ossify/topology.json"
( cd "$_E_WS6" && env -u OSS_STATE_FILE bash "$OSS" init r2 >/dev/null && env -u OSS_STATE_FILE bash "$OSS" bone_add ADR-0002 "the record" "packages/core/**" ) >/dev/null 2>&1
jq '.bones += [.bones[0]]' "$_E_WS6/.ossify/project-state.json" > "$_E_WS6/dup.json" && mv "$_E_WS6/dup.json" "$_E_WS6/.ossify/project-state.json"
_e_spec "$_E_WS6" '| ADR-0002 | the row |'
t_capture _e_run "$_E_WS6"
t_assert_rc 0 "(e) C6: duplicate registry records do not abort the check"
t_assert_contains "$T_OUT" "the registry carries more than one bone record for: ADR-0002" "(e) C6 ... the duplicate registration is reported"
if printf '%s' "$T_OUT" | grep -Fq 'ok: spec'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) C6: a duplicate registry record collapsed to a set and the check printed ok"
else
  T_PASS=$((T_PASS+1))
fi
# (e10) ROUND 2, C7: a section-4 data row whose first cell is not an ADR
# reference is reported, never filtered out of the comparison.
jq '.bones = [.bones[0]]' "$_E_WS6/.ossify/project-state.json" > "$_E_WS6/one.json" && mv "$_E_WS6/one.json" "$_E_WS6/.ossify/project-state.json"
_e_spec "$_E_WS6" '| ADR-0002 | the row |' '| RFC-2119 | not a bone ref |'
t_capture _e_run "$_E_WS6"
t_assert_rc 0 "(e) C7: an unnameable data row does not abort the check"
t_assert_contains "$T_OUT" "section 4 carries a row whose first cell is not an ADR reference: RFC-2119" "(e) C7 ... it is reported rather than skipped"
if printf '%s' "$T_OUT" | grep -Fq 'ok: spec'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) C7: an unnameable row was filtered out and the check printed ok"
else
  T_PASS=$((T_PASS+1))
fi
# ... and the underscore variant, which is the other shape the reviewer named.
_e_spec "$_E_WS6" '| ADR-0002 | the row |' '| ADR_9999 | malformed separator |'
t_capture _e_run "$_E_WS6"
t_assert_contains "$T_OUT" "not an ADR reference: ADR_9999" "(e) C7 ... an ADR_9999-style cell is reported too"
# (e11) CONTROL, adjacent to the two checks above: a clean pair still prints ok,
# and the header/separator cells are NOT mistaken for data rows.
_e_spec "$_E_WS6" '| ADR-0002 | the row |'
t_capture _e_run "$_E_WS6"
t_assert_contains "$T_OUT" "ok: spec - bones index matches the registry: 1 entries, 1 rows" "(e) C6/C7 control: a clean registry/index pair still reads clean"
printf '# MASTER-SPEC\n\n## 4. Bones-registry index\n\n| adr | title |\n| :--- | ---: |\n| ADR-0002 | the row |\n\n## 5. Journeys\nx\n' > "$_E_WS6/docs/MASTER-SPEC.md"
t_capture _e_run "$_E_WS6"
t_assert_contains "$T_OUT" "ok: spec - bones index matches the registry: 1 entries, 1 rows" "(e) C6/C7 control: a lowercase header and a colon-dash separator are passed over, not reported as unnameable rows"

# 1.14.1 (#648): one row-shape table owns the complete input grammar.
# Expected output is independent of the parser, including source case in every
# finding. Each case resets the state and spec, so duplicates cannot leak.
_G_WS="$_PC_TMP/grammar"; mkdir -p "$_G_WS/.ossify" "$_G_WS/docs" "$_G_WS/canon"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{"master_spec":"%s/docs/MASTER-SPEC.md","project_state":"%s/state.json"}}\n' \
  "$_G_WS" "$_G_WS" "$_G_WS" > "$_G_WS/.ossify/topology.json"
( cd "$_G_WS" && env -u OSS_STATE_FILE bash "$OSS" init grammar ) >/dev/null 2>&1
cp "$_G_WS/state.json" "$_G_WS/base.json"
while IFS=';' read -r shape registry cells expected; do
  jq --arg refs "$registry" '.bones = (if $refs == "" then [] else
    $refs | split(",") | map({adr:(if . == "<empty>" then "" else gsub("<newline>";"\n") end), title:"grammar fixture", touch:["core/**"]}) end)' \
    "$_G_WS/base.json" > "$_G_WS/state.json"
  _e_spec "$_G_WS"
  cp "$_G_WS/docs/MASTER-SPEC.md" "$_G_WS/header-only.md"
  # Insert data before section 5; an empty first cell is still a DATA row.
  awk -v cells="$cells" -v shape="$shape" '
    /^\| ADR \|/ && shape == "numeric-header" {print "| ADR 2026 | Title |"; next}
    /^\| ADR \|/ && shape == "non-adr-header" {print "| RFC-2119 | Title |"; next}
    /^\|---\|---\|$/ && shape ~ /^delimiter-/ {
      if(shape=="delimiter-one") print "|-|-|"
      if(shape=="delimiter-two") print "|--|--|"
      if(shape=="delimiter-colons") print "|:-|-:|"
      if(shape=="delimiter-aligned") print "| :-: |"
      if(shape=="delimiter-single-two") print "|--|"
      if(shape=="delimiter-invalid") print "| : | : |"
      next
    }
    /^## 5/ {n=split(cells,a,","); for(i=1;i<=n;i++) {
      c=a[i]; if(c=="<empty>") c=""; print "| " c " | fixture |"
      if(shape ~ /^adr-header/) print "|---|---|"
    }} {print}
  ' "$_G_WS/docs/MASTER-SPEC.md" > "$_G_WS/spec.tmp"
  mv "$_G_WS/spec.tmp" "$_G_WS/docs/MASTER-SPEC.md"
  if [ "$shape" = numeric-header ]; then
    if cmp -s "$_G_WS/header-only.md" "$_G_WS/docs/MASTER-SPEC.md"; then
      T_FAIL=$((T_FAIL+1)); echo "FAIL: R6 numeric-header rewrite did not change the header-only fixture"
    else
      T_PASS=$((T_PASS+1))
    fi
  fi
  t_capture _e_run "$_G_WS"
  printf 'GRAMMAR %s rc=%s: %s\n' "$shape" "$T_RC" "$T_OUT"
  t_assert_rc 0 "#648 $shape completes under strict Bash"
  expected="$(printf '%b' "$expected")"
  t_assert_eq "$expected" "$T_OUT" "#648 $shape follows the row grammar"
done <<'ROWS'
numeric;ADR-0002;ADR-0002;ok: spec - bones index matches the registry: 1 entries, 1 rows
digit-free;ADR-C;ADR-C;ok: spec - bones index matches the registry: 1 entries, 1 rows
malformed-digit-free;;RFC-FOO;fail: spec - section 4 carries a row whose first cell is not an ADR reference: RFC-FOO
malformed-digits;;RFC-2119;fail: spec - section 4 carries a row whose first cell is not an ADR reference: RFC-2119
duplicate-index;ADR-C;ADR-C,ADR-C;fail: spec - section 4 carries more than one row for: ADR-C
duplicate-registry;ADR-C,ADR-C;ADR-C;fail: spec - the registry carries more than one bone record for: ADR-C
lowercase;adr-c;adr-c;ok: spec - bones index matches the registry: 1 entries, 1 rows
mixed-case;aDr-C;AdR-c;ok: spec - bones index matches the registry: 1 entries, 1 rows
header-only;;;ok: spec - bones index matches the registry: 0 entries, 0 rows
clean-pair;ADR-C,ADR-0002;ADR-C,ADR-0002;ok: spec - bones index matches the registry: 2 entries, 2 rows
numeric-header;;;ok: spec - bones index matches the registry: 0 entries, 0 rows
empty-cell;;<empty>;fail: spec - section 4 carries a row whose first cell is not an ADR reference: [empty]
embedded-whitespace;;ADR- C;fail: spec - section 4 carries a row whose first cell is not an ADR reference: ADR- C
mixed-duplicate-index;aDr-C;AdR-c,aDR-C;fail: spec - section 4 carries more than one row for: AdR-c aDR-C
mixed-duplicate-registry;aDr-C,ADR-c;AdR-c;fail: spec - the registry carries more than one bone record for: aDr-C ADR-c
mixed-registry-only;aDr-C;;fail: spec - registry entry with no index row: aDr-C
mixed-index-only;;AdR-c;fail: spec - index row with no registry entry: AdR-c
delimiter-one;ADR-C;ADR-C;ok: spec - bones index matches the registry: 1 entries, 1 rows
delimiter-single-two;ADR-C;ADR-C;ok: spec - bones index matches the registry: 1 entries, 1 rows
delimiter-two;ADR-C;ADR-C;ok: spec - bones index matches the registry: 1 entries, 1 rows
delimiter-colons;ADR-C;ADR-C;ok: spec - bones index matches the registry: 1 entries, 1 rows
delimiter-aligned;ADR-C;ADR-C;ok: spec - bones index matches the registry: 1 entries, 1 rows
delimiter-invalid;ADR-C;ADR-C;fail: spec - section 4 carries a row whose first cell is not an ADR reference: ADR :
non-adr-header;;;ok: spec - bones index matches the registry: 0 entries, 0 rows
adr-header-empty;;AdR-c;fail: spec - section 4 carries a header whose first cell is an ADR reference: AdR-c
adr-header-matching;ADR-C;ADR-C;fail: spec - registry entry with no index row: ADR-C\nfail: spec - section 4 carries a header whose first cell is an ADR reference: ADR-C
blank-registry;<empty>;;skip: spec - the registry holds a value that is not an ADR reference ('[empty]'), and a value this check cannot name is not one it may drop
whitespace-registry;   ;;skip: spec - the registry holds a value that is not an ADR reference ('[empty]'), and a value this check cannot name is not one it may drop
invalid-suffix-registry;ADR-C<newline>RFC-2119;ADR-C;skip: spec - the registry holds a value that is not an ADR reference ('ADR-C RFC-2119'), and a value this check cannot name is not one it may drop
embedded-newline-registry;AdR-c<newline>aDR-d;ADR-C,ADR-D;skip: spec - the registry holds a value that is not an ADR reference ('AdR-c aDR-d'), and a value this check cannot name is not one it may drop
surrounding-newlines-registry;<newline>  ADR-C  <newline>;ADR-C;ok: spec - bones index matches the registry: 1 entries, 1 rows
newline-only-registry;<newline>;;skip: spec - the registry holds a value that is not an ADR reference ('[empty]'), and a value this check cannot name is not one it may drop
two-blank-registry;<empty>,<empty>;;skip: spec - the registry holds a value that is not an ADR reference ('[empty] [empty]'), and a value this check cannot name is not one it may drop
blank-with-valid-registry;ADR-C,<empty>;ADR-C;skip: spec - the registry holds a value that is not an ADR reference ('[empty]'), and a value this check cannot name is not one it may drop
ROWS

# S4: the doctor's remediation lookup must cover both new output kinds.
_remedies="$(awk '/^\| Mismatch \|/ {f=1} f && /^\|/ {print} f && /^None / {exit}' "$_E_SVMD")"
t_assert_contains "$_remedies" '| an ADR reference in a section-4 header |' "S4 ADR-header finding has a remediation row"
t_assert_contains "$_remedies" '| a blank or invalid registry ADR value |' "S4 invalid-registry refusal has a remediation row"

# (e6) ROUND 1, R3: an unresolvable route must REFUSE, not abort. Both resolver
# calls in the block are guarded, so under `set -euo pipefail` it reaches its own
# refusal arm instead of dying inside the command substitution - which is what
# the shipped block did (`sv_state="$(...)"` aborted the whole sourced read-out).
_E_WS3="$_PC_TMP/driftws3"; mkdir -p "$_E_WS3/.ossify" "$_E_WS3/canon" "$_E_WS3/docs"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{"master_spec":"%s/docs/MASTER-SPEC.md","project_state":"./state.json"}}\n' \
  "$_E_WS3" "$_E_WS3" > "$_E_WS3/.ossify/topology.json"
_e_spec "$_E_WS3" '| ADR-0002 | x |'
t_capture _e_run "$_E_WS3"
t_assert_rc 0 "(e) R3: an unresolvable state route does not abort the drift check under strict mode"
t_assert_contains "$T_OUT" "could not read" "(e) R3 ... it reaches its refusal arm and says which half it could not read"

# 1.14.2 A: locale pin RAN only after constructing the Turkish locale.
_A_LOCALE="$_PC_TMP/locales"; mkdir -p "$_A_LOCALE"
if localedef -i tr_TR -f UTF-8 "$_A_LOCALE/tr_TR.UTF-8" >"$_PC_TMP/localedef.log" 2>&1; then
  echo 'A2 locale pin RAN: tr_TR.UTF-8 (localedef)'
  jq '.bones = [{adr:"adr-i",title:"locale",touch:["x"]}]' "$_E_WS/.ossify/project-state.json" > "$_E_WS/locale.json"
  mv "$_E_WS/locale.json" "$_E_WS/.ossify/project-state.json"
  _e_spec "$_E_WS"
  t_capture env LOCPATH="$_A_LOCALE" LC_ALL=tr_TR.UTF-8 "PATH=$OSSDIR:$PATH" bash -c '
    set -euo pipefail
    cd "$1"; . "$2"
    printf "CALLER_LOCALE=%s\n" "$LC_ALL"
  ' fresh "$_E_WS" "$_E_SV"
  printf 'A2 RED/GREEN: %s\n' "$T_OUT"
  t_assert_rc 0 "A1 drift fence runs alone in a fresh shell under Turkish locale"
  t_assert_contains "$T_OUT" 'registry entry with no index row: adr-i' "A2 fail line names the original identifier under Turkish locale"
  t_assert_contains "$T_OUT" 'CALLER_LOCALE=tr_TR.UTF-8' "A1 locale remains scoped to the fence"
  _e_spec "$_E_WS" '| ADR-I | paired |'
  t_capture env LOCPATH="$_A_LOCALE" LC_ALL=tr_TR.UTF-8 "PATH=$OSSDIR:$PATH" bash -c 'set -euo pipefail; cd "$1"; . "$2"' fresh "$_E_WS" "$_E_SV"
  t_assert_contains "$T_OUT" '1 entries, 1 rows' "A1 Turkish clean case-insensitive pair control"
else
  T_FAIL=$((T_FAIL+1)); echo 'FAIL: A2 locale pin unavailable: localedef could not build tr_TR.UTF-8'
  cat "$_PC_TMP/localedef.log"
fi

# --- phase (f): §3's ADR numbering scan must read an adopted series (#301) ----
#
# The scan matched `^adr-` and `^NNNN-` only. On an adopted series in the other
# case - `ADR-001-redb-for-storage.md`, PulseDB's - it returned NOTHING, and an
# empty answer is not "start at 1": it minted `ADR-0001` over an existing
# `ADR-001`, duplicating the identifier bone citations and touch records key on.
# Two further rules lived only in prose: the minted WIDTH (`%04d` regardless of
# the series it read) and an unreadable `docs/adr/` answering like an empty one.
# The block is OPERATIVE (a loop, `exit 1`, a format chosen at runtime), so it is
# extracted AND executed.
_AD="$SKILLS/start/references/bones-registry.md"
_SC="$_PC_TMP/adr-scan.sh"
_o_extract_mint() { # checked extracts; identity is fence content, never a literal
  oss_block_extract "$1" 'narrow=' "$2" || return $?
  oss_block_extract "$1" 'scan=.*dest=' "$2.inventory" || return $?
  if ! cmp -s "$2.inventory" "$2"; then
    cat "$2.inventory" "$2" > "$2.combined" || return $?
    mv "$2.combined" "$2" || return $?
  fi
}
if _o_extract_mint "$_AD" "$_SC"; then T_PASS=$((T_PASS+1)); else
  T_FAIL=$((T_FAIL+1)); echo 'FAIL: B6 mint extraction refused'; fi
_SF="$_PC_TMP/adr-fresh.sh"
oss_block_extract "$_AD" 'narrow=' "$_SF" || exit 1
_SI="$_PC_TMP/adr-inventory.sh"
oss_block_extract "$_AD" 'scan=' "$_SI" || exit 1
# B6 semantic self-check: scan= in a comment cannot change fence identity.
cat > "$_PC_TMP/split-mint.md" <<'MD'
```bash
scan='definition'; dest=''
_b_mint() { echo ADR-0001; }
```
```bash
# scan= is a harmless comment, not the definition fence.
narrow=''
_b_mint
```
MD
t_capture _o_extract_mint "$_PC_TMP/split-mint.md" "$_PC_TMP/split-mint.sh"
t_assert_rc 0 'B6 split mint extract completes'
t_capture bash -c 'set -euo pipefail; . "$1"' fresh "$_PC_TMP/split-mint.sh"
t_assert_eq ADR-0001 "$T_OUT" 'B6 scan= comment does not skip definition join'
# Ambiguous/missing inventory extracts must be checked, not ignored.
cp "$_PC_TMP/split-mint.md" "$_PC_TMP/ambiguous-mint.md"
printf '\n```bash\nscan=second; dest=second\n```\n' >> "$_PC_TMP/ambiguous-mint.md"
t_capture _o_extract_mint "$_PC_TMP/ambiguous-mint.md" "$_PC_TMP/ambiguous.sh"
t_assert_rc 2 'B6 ambiguous inventory extract refuses'
sed '/scan=/d' "$_PC_TMP/split-mint.md" > "$_PC_TMP/missing-mint.md"
t_capture _o_extract_mint "$_PC_TMP/missing-mint.md" "$_PC_TMP/missing.sh"
t_assert_rc 1 'B6 missing inventory extract refuses'
_o_ws() { # $1=name ; echoes a workspace whose canonical repo has an empty docs/adr
  local d="$_PC_TMP/ni/$1"
  mkdir -p "$d/.ossify" "$d/canon/docs/adr"
  printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{}}\n' "$d" > "$d/.ossify/topology.json"
  printf '%s\n' "$d"
}
_o_next2() { # $1=dir $2=repos $3=destination repo (the block consumes both)
  ( cd "$1" && env -u OSS_STATE_FILE -u dest_repo -u adr_scan_mode "PATH=$OSSDIR:$PATH" repos="$2" bash -c '
    set -euo pipefail
    if [ "$2" != "[unset]" ]; then dest_repo="$2"; fi
    if [ "$3" != "[unset]" ]; then adr_scan_mode="$3"; fi
    . "$1"
  ' fresh "$_SC" "$3" "${4:-mint}" )
}
_o_next() { _o_next2 "$1" canonical canonical; }
_o_fresh() { # $1=workspace $2=mode $3=repos or [unset] $4=destination $5=invocations
  local temp="$_PC_TMP/fresh-$2-$5-$RANDOM" rc
  mkdir -p "$temp"
  ( cd "$1" && env -u OSS_STATE_FILE -u repos -u dest_repo TMPDIR="$temp" \
    "PATH=$OSSDIR:$PATH" adr_scan_mode="$2" bash -c '
      set -euo pipefail
      if [ "$2" != "[unset]" ]; then repos="$2"; fi
      if [ "$3" != "[unset]" ]; then dest_repo="$3"; fi
      for ((i=0;i<$4;i++)); do . "$1"; done
    ' fresh "$_SF" "$3" "$4" "$5" )
  rc=$?
  printf 'STATUS %s TEMPS %s\n' "$rc" "$(find "$temp" -type f | wc -l | tr -d ' ')"
}
_o_next_keep() { _o_fresh "$1" mint canonical canonical 1; }
# THE DEFECT: an uppercase three-digit series is read, and the mint continues it.
_O_U="$(_o_ws upper)"; : > "$_O_U/canon/docs/adr/ADR-001-redb-for-storage.md"; : > "$_O_U/canon/docs/adr/ADR-002-single-writer.md"
t_capture _o_next "$_O_U"
t_assert_rc 0 "#301: the numbering scan completes on an adopted series"
t_assert_contains "$T_OUT" "ADR-003" "#301 ... and CONTINUES it: ADR-001/ADR-002 are read, so the next id is ADR-003 at the series' own width"
if printf '%s' "$T_OUT" | grep -Fq 'ADR-001'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: #301 the scan minted an id that already exists - matching one case answers an empty series and restarts at 1"
else
  T_PASS=$((T_PASS+1))
fi
t_capture _o_next2 "$_O_U" canonical canonical '[unset]'
t_assert_rc 0 'R6 unset adr_scan_mode retains default mint invocation in fresh shell'
t_assert_eq ADR-003 "$T_OUT" 'R6 default mint continues the same series as explicit mint'
# 1.14.1 (#647): missing/unscanned destinations refuse, never mint at a
t_capture _o_fresh "$_O_U" mint canonical canonical 1
printf 'FRESH mint: %s\n' "$T_OUT"
t_assert_eq $'ADR-003\nSTATUS 0 TEMPS 0' "$T_OUT" "S2 mint fence works alone in a fresh shell and cleans its files"
t_capture _o_fresh "$_O_U" inventory canonical '[unset]' 2
printf 'FRESH inventory twice: %s\n' "$T_OUT"
t_assert_eq $'canonical\tADR-001-redb-for-storage.md\ncanonical\tADR-002-single-writer.md\ncanonical\tADR-001-redb-for-storage.md\ncanonical\tADR-002-single-writer.md\nSTATUS 0 TEMPS 0' "$T_OUT" "S2 inventory fence works alone and repeated invocation leaks no files"
t_capture _o_fresh "$_O_U" inventory '[unset]' canonical 1
printf 'FRESH unset repos: %s\n' "$T_OUT"
t_assert_eq $'the numbering scan refuses repos \'[unset]\': declare the repos to scan\nSTATUS 1 TEMPS 0' "$T_OUT" "S2 unset inventory repos refuse before allocating files"

# 1.14.1 (#647): missing/unscanned destinations refuse, never mint at a
# guessed width. The unset case clears the variable rather than setting it empty.
while IFS=';' read -r destination expected_rc expected; do
  t_capture _o_next2 "$_O_U" canonical "$destination"
  printf 'MINT %s rc=%s: %s\n' "$destination" "$T_RC" "$T_OUT"
  t_assert_rc "$expected_rc" "#647 destination $destination has the required status"
  t_assert_eq "$expected" "$T_OUT" "#647 destination $destination refuses or joins the scanned series"
done <<'DESTINATIONS'
canonicl;1;the numbering scan refuses dest_repo 'canonicl': it is not a scanned repo
[unset];1;the numbering scan refuses dest_repo '[unset]': it is not a scanned repo
;1;the numbering scan refuses dest_repo '[empty]': it is not a scanned repo
canonical;0;ADR-003
DESTINATIONS

# R4: adopt C3 runs inventory with no destination and mints nothing.
_SI="$_PC_TMP/adr-inventory.sh"
oss_block_extract "$_AD" 'scan=' "$_SI"
_o_adopt_scan() {
  ( cd "$1" && env -u OSS_STATE_FILE -u dest_repo "PATH=$OSSDIR:$PATH" adr_scan_mode=inventory repos="$2" bash -c \
    "set -euo pipefail; . '$_SI' | LC_ALL=C sort" )
}
t_capture _o_adopt_scan "$_O_U" canonical
printf 'ADOPT inventory rc=%s: %s\n' "$T_RC" "$T_OUT"
t_assert_rc 0 "R4 adopt C3 inventory completes without dest_repo"
t_assert_eq $'canonical\tADR-001-redb-for-storage.md\ncanonical\tADR-002-single-writer.md' "$T_OUT" "R4 adopt C3 inventories the existing series without minting"

# CONTROLS: every other form keeps working, and a non-series mints nothing from.
_O_B="$(_o_ws bare)"; : > "$_O_B/canon/docs/adr/0003-record-architecture-decisions.md"
t_capture _o_next "$_O_B"
t_assert_contains "$T_OUT" "ADR-0004" "#301 control: the bare scaffold-onboard seed is still read"
_O_L="$(_o_ws lower)"; : > "$_O_L/canon/docs/adr/adr-0007-hexagonal.md"
t_capture _o_next "$_O_L"
t_assert_contains "$T_OUT" "ADR-0008" "#301 control: the lowercase four-digit form is still read"
_O_E="$(_o_ws empty)"
t_capture _o_next "$_O_E"
t_assert_contains "$T_OUT" "ADR-0001" "#301 control: an empty series starts at ADR-0001, four digits"
_O_D="$(_o_ws decoy)"; : > "$_O_D/canon/docs/adr/README.md"; : > "$_O_D/canon/docs/adr/0001-notes.txt"
t_capture _o_next "$_O_D"
t_assert_contains "$T_OUT" "ADR-0001" "#301 control: README.md and a non-.md file are not a series to continue"
# REFUSAL ARM: an unreadable docs/adr/ must not answer like an empty one, or the
# next ADR is minted blind over whatever is in there.
_O_P="$(_o_ws perm)"; chmod 000 "$_O_P/canon/docs/adr"
# NOT ASSUMED TO BITE. Running as root ignores the mode bits, so an assertion
# that cannot fail would read as coverage: probe first and say so out loud when
# the arm is not exercised (round 1, R12/C3 - the pattern test-worktree.sh:746
# uses). The symlink-loop arm below is this arm's root-proof twin.
if ls -1 "$_O_P/canon/docs/adr" >/dev/null 2>&1; then
  echo "NOTE: chmod 000 did not restrict this user (uid $(id -u)); the unreadable-directory arm is NOT exercised here - see the symlink-loop arm below"
else
  t_capture _o_next "$_O_P"
  _o_prc=$T_RC
  t_assert_eq 1 "$_o_prc" "#301: an unreadable docs/adr/ refuses (rc 1) rather than answering as an empty series"
  t_assert_contains "$T_OUT" "could not read" "#301 ... naming the directory it could not read"
  if printf '%s' "$T_OUT" | grep -Fq 'ADR-'; then
    T_FAIL=$((T_FAIL+1)); echo "FAIL: #301 an unreadable series was answered with a minted id - a failure read as an absence"
  else
    T_PASS=$((T_PASS+1))
  fi
fi
chmod 755 "$_O_P/canon/docs/adr"
# (f4) ROUND 1, R9: a docs/adr/ that cannot even be CREATED refuses at rc 1
# naming the path. The fixture is a self-referential symlink, which fails for
# root as well as for anyone else - the root-proof half of the arm above.
_O_LP="$_PC_TMP/ni/loop"; mkdir -p "$_O_LP/.ossify" "$_O_LP/canon/docs"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"}},"well_known_paths":{}}\n' "$_O_LP" > "$_O_LP/.ossify/topology.json"
: > "$_O_LP/canon/docs/adr"   # a FILE where the directory must be: mkdir cannot succeed, as root either
t_capture _o_next "$_O_LP"
t_assert_eq 1 "$T_RC" "#301 R9: an uncreatable docs/adr/ refuses at rc 1"
t_assert_contains "$T_OUT" "$_O_LP/canon/docs/adr" "#301 R9 ... and the refusal names the path it could not create"
# (f5) ROUND 1, R6: every exit path takes the scan's temp files with it, so the
# caller is left with no populated mktemp per mint.
_O_CL="$(_o_ws clean)"; : > "$_O_CL/canon/docs/adr/adr-0001-a.md"
t_capture _o_next_keep "$_O_CL"
t_assert_contains "$T_OUT" "ADR-0002" "#301 R6 control: the mint still answers"
t_assert_contains "$T_OUT" 'STATUS 0 TEMPS 0' "#301 R6 success removes every allocated temp file"

for mode in mint inventory; do
  t_capture _o_fresh "$_O_U" "$mode" missing missing 1
  t_assert_contains "$T_OUT" "could not resolve a root for repo 'missing'" "S2 $mode root refusal names the repo"
  t_assert_contains "$T_OUT" 'STATUS 1 TEMPS 0' "S2 $mode root refusal cleans both files"
  t_capture _o_fresh "$_O_LP" "$mode" canonical canonical 1
  t_assert_contains "$T_OUT" "could not create $_O_LP/canon/docs/adr" "S2 $mode create refusal names the path"
  t_assert_contains "$T_OUT" 'STATUS 1 TEMPS 0' "S2 $mode create refusal cleans both files"
done

# S2: failures after allocation, including the SECOND mktemp, cannot orphan
# the first file. Substitute only the failing tool; run the real fence.
_O_REAL_MKTEMP="$(command -v mktemp)"
for failure in mktemp ls; do
  _O_BIN="$_PC_TMP/fail-$failure"; mkdir -p "$_O_BIN"
  if [ "$failure" = mktemp ]; then
    cat > "$_O_BIN/mktemp" <<'SH'
#!/usr/bin/env bash
if [ -e "$TMPDIR/allocated" ]; then exit 1; fi
touch "$TMPDIR/allocated"
exec "$real_mktemp"
SH
  else
    printf '#!/usr/bin/env bash\nexit 1\n' > "$_O_BIN/ls"
  fi
  chmod +x "$_O_BIN/$failure"
  for mode in mint inventory; do
    _O_TEMP="$_PC_TMP/failure-$failure-$mode"; mkdir -p "$_O_TEMP"
    t_capture env -u OSS_STATE_FILE TMPDIR="$_O_TEMP" PATH="$_O_BIN:$OSSDIR:$PATH" real_mktemp="$_O_REAL_MKTEMP" \
      repos=canonical dest_repo=canonical adr_scan_mode="$mode" bash -c \
      "cd '$_O_U'; set -euo pipefail; . '$_SF'"
    t_assert_rc 1 "S2 $mode $failure failure refuses"
    _left="$(find "$_O_TEMP" -type f ! -name allocated | wc -l | tr -d ' ')"
    t_assert_eq 0 "$_left" "S2 $mode $failure failure removes all allocated scan files"
  done
done
# (f6) ROUND 1, C2/CR2: the minted WIDTH comes from the DESTINATION repo's
# series, not from the project-wide highest. Destination `adr-0007-…` (four
# digits) with `ADR-099-…` in another repo: the number is 100 (project-wide),
# the width is the destination's 4 - so ADR-0100, not the old ADR-100.
_O_C2="$(_o_ws width)"; mkdir -p "$_O_C2/extra/docs/adr"
printf '{"schema_version":1,"repos":{"canonical":{"root":"%s/canon"},"extra":{"root":"%s/extra"}},"well_known_paths":{}}\n' \
  "$_O_C2" "$_O_C2" > "$_O_C2/.ossify/topology.json"
: > "$_O_C2/canon/docs/adr/adr-0007-hexagonal.md"
: > "$_O_C2/extra/docs/adr/ADR-099-elsewhere.md"
t_capture _o_next2 "$_O_C2" "$(printf 'canonical\nextra')" canonical
t_assert_contains "$T_OUT" "ADR-0100" "#301 C2: the width is the destination repo's, so a four-digit series elsewhere cannot force a three-digit mint"
t_assert_contains "$T_OUT" "ADR-0100" "#301 C2 control: the NUMBER is still project-wide (99 elsewhere -> 100)"

# R4 inventory covers both declared repos and all existing filename forms.
: > "$_O_C2/canon/docs/adr/0010-bare.md"
t_capture _o_adopt_scan "$_O_C2" $'canonical\nextra'
t_assert_rc 0 "R4 adopt C3 aggregates every declared repo without dest_repo"
t_assert_eq $'canonical\t0010-bare.md\ncanonical\tadr-0007-hexagonal.md\nextra\tADR-099-elsewhere.md' "$T_OUT" "R4 adopt C3 retains bare, uppercase and lowercase series across repos"

# B1/B3: the authority table's grammar is consumed, never independently guessed.
_b_ref="$(awk -F'`' '/^[[:space:]]*\| Accepted ADR identifier \|/ {print $2}' "$_AD")"
_b_consumer="$(sed -n "s/^adr_re='\(.*\)'$/\1/p" "$_E_SV")"
t_assert_eq 'ADR-[A-Za-z0-9]+' "$_b_ref" 'B1 accepted grammar lives in bones-registry anatomy'
if [ -n "$_b_ref" ]; then
  for ref in ADR-0 ADR-C aDr-c2 ADR- ADR_C ADR-C! 'ADR-C X' ' ADR-C'; do
    expected=0; actual=0
    printf '%s\n' "$ref" | LC_ALL=C awk -v re="^$_b_ref$" 'toupper($0) ~ re {ok=1} END{exit !ok}' && expected=1
    printf '%s\n' "$ref" | LC_ALL=C awk -v re="$_b_consumer" '$0 ~ re {ok=1} END{exit !ok}' && actual=1
    t_assert_eq "$expected" "$actual" "B3 grammar table agrees with consumer: $ref"
  done
fi
t_assert_contains "$(cat "$_E_SVMD")" 'bones-registry.md §3 part 1' 'B1 doctor cites the ADR grammar authority'
t_assert_eq 1 "$(awk '/sv_fold\(\)/ {n++} END{print n+0}' "$_E_SV")" 'B2 key fold/drop-empty program defined once'
t_assert_eq 1 "$(awk '/is_destination\(\)/ {n++} END{print n+0}' "$_SF")" 'B4 destination predicate stated once'
t_assert_eq 0 "$(awk '/^while IFS=.*destination/ {f=1} f {print} f && /^done/ {exit}' "$HERE/test-prose-contracts.sh" | awk '/t_capture env / {n++} END{print n+0}')" 'B5 unset destination uses _o_next2'
t_assert_contains "$(head -7 "$HERE/test-block-ledger.sh")" 'block-ledger.tsv' 'B8 deferred coverage header points at the ledger'
# B7 identical filenames retain both repo names (mint output remains pinned above).
: > "$_O_C2/extra/docs/adr/adr-0007-hexagonal.md"
t_capture _o_adopt_scan "$_O_C2" $'canonical\nextra'
t_assert_contains "$T_OUT" $'canonical\tadr-0007-hexagonal.md' 'B7 inventory names canonical holder'
t_assert_contains "$T_OUT" $'extra\tadr-0007-hexagonal.md' 'B7 inventory names second holder of same filename'

# --- phase 3: the never-strand invariant's two surfaces must agree -----------
#
# The dispatch predicate is one definition used at four sites, and one of them is
# PROSE: doctor's §5 drift bullet reports the very pair the rails refuse to
# create. If the bullet names fewer fields than the shell predicate reads, the
# report and the rail disagree about what "dispatched" means - and the
# disagreement is invisible in both directions (the bullet under-reports, the
# rail over-refuses, and each looks correct read alone). Measured: the shipped
# bullet named two fields while the guard read two, and the third (base_sha) was
# how a half-write dispatch became an abandonment.
ENT="$OSSSK/lib/entities.sh"
SI3="$OSSSK/skills/doctor/references/state-inspection.md"
# The PREDICATE's own definition, not a mention anywhere in the file: the three
# field names also appear in the dispatch payload builder, so a file-level grep
# passes while the predicate reads fewer (measured - the same trap as phase 2's
# sweep row, where a word-grep passed on a comment). Anchored to COLUMN 0 and
# required to be UNIQUE: `grep -F '…='` would take the first match, so a future
# comment carrying the literal above the definition would satisfy the field
# checks while the real predicate drifted under it (round 1, GLM seat).
_pred_n="$(grep -cE '^_OSS_DISPATCHED_JQ=' "$ENT" || true)"
if [ "$_pred_n" = "1" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: entities.sh must define the shared dispatch predicate (_OSS_DISPATCHED_JQ=) exactly once at column 0, found $_pred_n - the parity checks below are vacuous otherwise"
fi
_pred="$(grep -E '^_OSS_DISPATCHED_JQ=' "$ENT" || true)"
for _f in branch worktree_path base_sha; do
  case "$_pred" in
    *"$_f"*) T_PASS=$((T_PASS+1));;
    *) T_FAIL=$((T_FAIL+1)); echo "FAIL: the dispatch predicate's definition does not read '$_f'";;
  esac
done
# The bullet's field list, and the window is its OWN two lines. It was `-A 8`
# until this narrowing pass, and the mutation battery found why that was too wide:
# the bullet's EXPLANATION below it names `base_sha` as well (`work_item_exec <wi>
# "" "" <sha>` records it), so deleting `base_sha` from the field list itself left
# this row GREEN - the check was satisfied by the prose that explains the field,
# which is the round-1 #2 trap one level down (a check that passes on surrounding
# commentary instead of on its subject). Measured: with `-A 2` the same deletion is
# RED. The anchor below it is the bullet's own bolded heading, so this window is
# the list, not the explanation.
_bullet="$(grep -A 2 'An `abandoned` work item with a recorded' "$SI3")"
for _f in branch worktree_path base_sha; do
  case "$_bullet" in
    *"$_f"*) T_PASS=$((T_PASS+1));;
    *) T_FAIL=$((T_FAIL+1)); echo "FAIL: state-inspection.md §5's abandoned-drift bullet does not name '$_f' - the report and the rail disagree about what dispatched means";;
  esac
done
# The item-level rail keeps three clauses (a recorded dispatch / `complete` /
# `active`) and it is PROSE that tells the model to walk them, so the prose must
# name all three. Round 2 (#21) is exactly this row's failure mode: the sentence
# named a dispatched or landed item and said nothing about `active`, which the same
# rail refuses - a never-dispatched item a lane had already marked in flight.
# Re-anchored by the 1.12.0 narrowing (operator ruling, 2026-09-23): the old anchor
# was the sentence that ALSO claimed the retirement was enforced, and that rail does
# not ship (#563), so the anchor is the claim that remains true.
_SK3="$OSSSK/skills/plan-spine/SKILL.md"
_sk="$(grep -A 1 'The withdrawal is enforced rather than declared' "$_SK3" || true)"
if [ -n "$_sk" ]; then
  T_PASS=$((T_PASS+1))
  for _f in dispatched complete active 'rc 7'; do
    case "$_sk" in
      *"$_f"*) T_PASS=$((T_PASS+1));;
      *) T_FAIL=$((T_FAIL+1)); echo "FAIL: plan-spine/SKILL.md's withdrawal sentence does not name '$_f' - the rail refuses on it and the prose the model follows is narrower than the rail";;
    esac
  done
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: plan-spine/SKILL.md no longer states what the withdrawal refusal is enforced ON - re-anchor this row or drop it"
fi
# ADJACENT CONTROL, and it is the loosening's own: this row went from pinning one
# exact sentence to pinning field names, so it accepts more - and what it must still
# REJECT is the claim that went with the dropped rails. A prose sentence asserting
# the retirement is enforced would be a rule the release does not keep, which is the
# same report/rail disagreement one level up.
if grep -Fq 'Both are now enforced rather than declared' "$_SK3"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: plan-spine/SKILL.md claims the retirement is enforced - that rail does not ship in 1.12.0 (#563)"
else
  T_PASS=$((T_PASS+1))
fi
# The third reader of the dispatch record is a close-path diagnosis, and it is
# one field wide if nobody holds it: work-item-close.md's halt gloss explains a
# missing worktree_path as "the lane skipped work_item_exec", which is FALSE for
# the base_sha-only half-write this phase documents - the lane dispatched and
# recorded no worktree. The halt is right either way; the diagnosis the operator
# recovers from must name both causes.
_wc="$(grep -A 3 'A missing .worktree_path. means' "$OSSSK/skills/close/references/work-item-close.md" || true)"
if [ -n "$_wc" ]; then
  case "$_wc" in
    *base_sha*) T_PASS=$((T_PASS+1));;
    *) T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md's missing-worktree_path gloss does not name the base_sha-only half-write - it tells the operator a lane broke when a dispatch is on record";;
  esac
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item-close.md no longer states the missing-worktree_path diagnosis at all - re-anchor this row or drop it"
fi

# 1.13.0 - /ossify:work-pr is a ROUTER: merge-bar's working-a-pr where that plugin
# is installed, the bundled loop otherwise. Losing either arm strands a host:
# without the fallback, an install with no merge-bar has no loop at all; without
# the route, merge-bar is never used from ossify.
_WP="$HERE/../skills/work-pr/SKILL.md"
for _lit in 'merge-bar:working-a-pr' 'references/loop.md'; do
  if grep -Fq -- "$_lit" "$_WP"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: skills/work-pr/SKILL.md no longer names '$_lit' - the router lost an arm"
  fi
done

# 1.13.0 final review - four sentences whose absence was a finding.
# (a) patch/SKILL.md: the separate worktree is cut BEFORE the reproduction and
#     the fix are written - otherwise a model following the steps in order writes
#     them into a checkout a running spine is parked on.
_PS="$HERE/../skills/patch/SKILL.md"
_wt="$(awk '/worktree/{print NR; exit}' "$_PS")"; _rp="$(awk '/Reproduce first/{print NR; exit}' "$_PS")"
if [ -n "$_wt" ] && [ -n "$_rp" ] && [ "$_wt" -lt "$_rp" ]; then T_PASS=$((T_PASS+1)); else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: patch/SKILL.md does not direct the worktree cut before 'Reproduce first' (worktree line ${_wt:-none}, reproduce line ${_rp:-none})"; fi
# (b)-(d) spine close's merge-bar seam and the barrier's own-scope paths.
_SC="$HERE/../skills/close/references/spine-close.md"
_RO="$HERE/../skills/work-item/references/round-orchestration.md"
for _pair in "$_SC|keeps the first two lines" "$_SC|pr_fields=\"\$(cat" "$_RO|§7 fix-up"; do
  _f="${_pair%%|*}"; _lit="${_pair#*|}"
  if grep -Fq -- "$_lit" "$_f"; then T_PASS=$((T_PASS+1)); else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: $(basename "$_f") does not state '$_lit'"; fi
done

# 1.13.1 (#614 items 1-6) - one pin per item, each red on 1.13.0's text.
_IL="$HERE/../skills/plan-spine/references/intake-and-ledger.md"
_RC="$HERE/../skills/close/references/release-close.md"
_pin() { # $1=ok(0/1) $2=message
  if [ "$1" = 0 ]; then T_PASS=$((T_PASS+1)); else T_FAIL=$((T_FAIL+1)); echo "FAIL: $2"; fi
}
# (1) patch §2: the re-check on the actual diff re-reads the ledger overlap, not only touch_check.
_r=1; grep -Fq 're-read the ledger lines overlapping the changed paths' "$_PS" && _r=0
_pin "$_r" "patch/SKILL.md §2's final-diff re-check does not re-read the ledger overlap - a ledger line on a path the fix touched unexpectedly goes undispositioned"
# (2) spine-close: merge-bar's fields are loaded per hosting repo INSIDE the landing loop,
#     so each repo's PR carries only its own Known limits.
_lo="$(awk '/^while IFS= read -r repo; do/{print NR; exit}' "$_SC")"
_ld="$(awk -v s="${_lo:-0}" 'NR>s && /^done <<EOF/{print NR; exit}' "$_SC")"
_lf="$(awk '/pr_fields="\$\(cat "\$pr_fields_dir\/\$repo"\)"/{print NR; exit}' "$_SC")"
_r=1; if [ -n "$_lo" ] && [ -n "$_ld" ] && [ -n "$_lf" ] && [ "$_lo" -lt "$_lf" ] && [ "$_lf" -lt "$_ld" ]; then _r=0; fi
_pin "$_r" "spine-close.md does not load \$pr_fields per repo inside the landing loop (loop ${_lo:-none}-${_ld:-none}, load ${_lf:-none}) - every hosting PR carries the spine-wide Known limits"
_r=0; grep -Fq 'one text for every' "$_SC" && _r=1
_pin "$_r" "spine-close.md still composes one \$pr_fields text for every hosting repo"
# (3) release-close: patch discovery fetches tags before listing them.
_ft="$(awk '/fetch --tags/{print NR; exit}' "$_RC")"
_fe="$(awk '/for-each-ref --sort=creatordate/{print NR; exit}' "$_RC")"
_r=1; if [ -n "$_ft" ] && [ -n "$_fe" ] && [ "$_ft" -lt "$_fe" ]; then _r=0; fi
_pin "$_r" "release-close.md lists patch tags without fetching them first (fetch ${_ft:-none}, list ${_fe:-none}) - a tag pushed from another clone is missed"
# (4) release-close: patch discovery reads every declared non-AI repo, not only the landed ones.
_r=1; grep -Fq 'every non-AI repo the resolved topology declares' "$_RC" && ! grep -Fq 'For each repo this release landed in' "$_RC" && _r=0
_pin "$_r" "release-close.md's patch discovery covers only the repos the release landed in - a patch in a declared repo no spine touched is missed"
# (5) intake-and-ledger §1: only a SPINE id assigns a request; a release-level pull-in
#     is re-dispositioned to the spine and recorded in SPINE.md when the spine takes it.
_r=1; grep -Fq 'pulled in — <spine id>` disposition is already assigned' "$_IL" && grep -Fq 're-disposition it' "$_IL" && _r=0
_pin "$_r" "intake-and-ledger.md §1 treats a release-level 'pulled in' as assigned - no SPINE.md records the request and spine close never closes it"
# (6) patch §4: origin must be a GitHub repository, checked before anything is cut.
_gh="$(awk '/remote get-url origin/{print NR; exit}' "$_PS")"
_wa="$(awk '/worktree add -b/{print NR; exit}' "$_PS")"
_r=1; if [ -n "$_gh" ] && [ -n "$_wa" ] && [ "$_gh" -lt "$_wa" ]; then _r=0; fi
_pin "$_r" "patch/SKILL.md §4 does not require a GitHub origin before the cut (check ${_gh:-none}, cut ${_wa:-none}) - a non-GitHub origin fails only at the PR step, after the commit"

# #619 round 1 - three review findings, each pinned red before its fix.
# (1b) release-close: patch discovery skips a filesystem-only root (no git, so no patch).
_r=1; grep -Fq 'skip a root that is not a git repository' "$_RC" && _r=0
_pin "$_r" "release-close.md's patch discovery runs git/gh against filesystem-only roots - release close fails on a supported topology"
# (1c) patch §2: the final-diff path list keeps a rename's old path.
_r=1; grep -Fq 'git diff --no-renames --name-only' "$_PS" && _r=0
_pin "$_r" "patch/SKILL.md §2's final-diff list drops a renamed file's old path - its ledger line goes undispositioned"
# (6b) patch §4: every origin push URL is checked, not only the fetch URL.
_r=1; grep -Fq 'remote get-url --push --all origin' "$_PS" && _r=0
_pin "$_r" "patch/SKILL.md §4 checks only origin's fetch URL - a non-GitHub pushurl passes"

# #619 round 2 - two review findings, each pinned red before its fix.
# (6c) patch §4: push and fetch URLs are compared host-and-all (gh's `url`), not by owner/repo.
# #755: §1 now names the repo with `--json nameWithOwner`, so the check reads §4 alone.
_s4="$(awk '/^## 4\. /{f=1;next} /^## 5\. /{f=0} f' "$_PS")"
_r=1; printf '%s\n' "$_s4" | grep -Fq -- '--json url' && ! printf '%s\n' "$_s4" | grep -Fq -- '--json nameWithOwner' && _r=0
_pin "$_r" "patch/SKILL.md §4 compares origin URLs by nameWithOwner - two GitHub hosts with one owner/repo pass"
# (3b) release-close: patch tags are fetched from origin, the remote /ossify:patch pushes to.
_r=1; grep -Fq 'fetch --tags origin' "$_RC" && ! grep -Fq 'fetch --tags <remote>' "$_RC" && _r=0
_pin "$_r" "release-close.md fetches patch tags from an unnamed <remote> - a multi-remote repo can miss what /ossify:patch pushed to origin"

# #619 round 3 (operator-approved) - two findings this PR introduced.
# (2b) spine-close: a repo-agnostic limit goes on a repo that OPENS a PR - a local-arm repo has none.
# D4: the phrase recurs (the resume-arm reconciliation rule states it too), so
# the pin is the guarded sentence itself.
pin "$_SC" 'goes on the first hosting repo that opens a PR, and on that PR alone' \
  "spine-close.md routes repo-agnostic Known limits to the first hosting repo, which may take the local arm and open no PR - the limit never reaches the ledger"
# (4b) release-close: skip the PR lookup where origin is not a GitHub repository.
_r=1; grep -Fq 'skip the `gh pr list` call where `gh repo view` cannot resolve `origin`' "$_RC" && _r=0
_pin "$_r" "release-close.md runs gh pr list against a non-GitHub origin in a declared repo - patch discovery fails on a supported topology"


# 1.13.2 (#628 items 1-2, #579, #552, #296, #397, #342) - one pin per defect, each red on 1.13.1's text.
_OSSR="$HERE/.."
# (#628.1) spine-close: a resumed PR's Known limits are reconciled with this repo's fields file.
_r=1; grep -Fq "reconcile the resumed PR's Known limits" "$_SC" && _r=0
_pin "$_r" "spine-close.md's resume arm never reconciles a resumed PR's body with this repo's fields - a PR opened under 1.13.0 keeps the spine-wide Known limits"
# (#628.2) patch §5: the changed-path re-check repeats after each review-fix round.
_r=1; grep -Fq "re-run §2's changed-path re-check after each review-fix round" "$_PS" && _r=0
_pin "$_r" "patch/SKILL.md does not repeat §2's changed-path re-check after review-fix rounds - a ledger line on a path a fix round touched reaches merge undispositioned"
# (#552) external-executor §4 no longer claims close fingerprints the four oids.
_r=0; grep -Fq 'same four components' "$_OSSR/skills/work-item/references/external-executor.md" && _r=1
_pin "$_r" "external-executor.md still claims work-item-close.md §2 fingerprints the four *_oid components - it computes none"
# (#296) adopt: the gates are A0-A5 (class P adds A6), never "five", in every place that counts them.
_r=0
for _f in "$_OSSR/skills/adopt/SKILL.md" "$_OSSR/commands/adopt.md" "$_OSSR/../.claude-plugin/marketplace.json"; do
  tr '\n' ' ' < "$_f" | grep -Eq 'five +(fail-closed|pre-flight) +gates|all five pass' && { _r=1; echo "  (#296 site: $(basename "$_f"))"; }
done
_pin "$_r" "adopt is still described with five gates where §3 defines A0-A5 and A6 - A0's OSS_STATE_FILE guard reads as preamble"
# (#397) doctor: the fix-finding route names the ONE write surface §1 defines.
_r=0; grep -Fq 'two explicit-write surfaces' "$_OSSR/skills/doctor/SKILL.md" && _r=1
_pin "$_r" "doctor/SKILL.md's fix-finding route excepts 'two explicit-write surfaces' - §1 defines exactly one"
# (#342) start §11 authors the lean MASTER-SPEC before auditing it.
_r=1; grep -Fq 'author the lean MASTER-SPEC here' "$_OSSR/skills/start/SKILL.md" && _r=0
_pin "$_r" "start/SKILL.md §11 audits a lean MASTER-SPEC that no step before it authors - §13 only lists it as an output"
# (#579.1) the active-clause refusal cites the doc that carries its closed-spine caveat...
_al="$(grep -F "is active - its round is declared in flight" "$_OSSR/lib/entities.sh")"
_r=1; case "$_al" in *"(close/references/work-item-close.md §1)"*) _r=0;; esac
_pin "$_r" "entities.sh's active-clause refusal cites a doc that does not carry its closed-spine caveat"
# ...and decomposition.md §1 carries the caveat beside the reversal it qualifies.
_r=1; grep -Fq 'only while its spine is still open' "$_OSSR/skills/plan-spine/references/decomposition.md" && _r=0
_pin "$_r" "decomposition.md §1 states the planned-reversal route without the closed-spine caveat"
# (#579.2) the 1.11.0 notes point at the predicate 1.12.0 replaced it with. ossify's release notes
# moved from its README to CHANGELOG.md (README rewrite, 2026-11), so the history pins read there.
_r=1; grep -Fq '1.12.0 replaces this predicate' "$_OSSR/CHANGELOG.md" && _r=0
_pin "$_r" "ossify/CHANGELOG.md's 1.11.0 entry still teaches the branch-or-worktree predicate as current"
# (#579.3) ossify's CHANGELOG names the dropped refusal so it cannot be read as the shipped complete
# clause. Neither README carries release notes any more (front-page redesign and ossify README
# rewrite, 2026-11), so both are held to the absence half only.
_r=0
grep -Fq 'landed-provenance refusal' "$_OSSR/CHANGELOG.md" || { _r=1; echo "  (#579.3 site: $_OSSR/CHANGELOG.md)"; }
for _f in "$_OSSR/CHANGELOG.md" "$_OSSR/README.md" "$_OSSR/../README.md"; do
  grep -Fq 'the landed-item refusal' "$_f" && { _r=1; echo "  (#579.3 old name still in: $_f)"; }
done
_pin "$_r" "the 1.12.0 notes name the dropped refusal and the shipped complete clause identically - they assert and deny the same transition"
# (#579.4) the guard-set comment names both guards that ship.
_r=0; grep -Fq 'One guard ships' "$_OSSR/lib/entities.sh" && _r=1
_pin "$_r" "entities.sh's rail header says one guard ships while the file defines two"

# #633 round 1 - two Codex classes, each pinned red before its fix.
# (A) start §11 authors all seven sections before the audit - section 7 applies §12's floors.
_r=1; grep -Fq "section 7 applies §12's floors" "$_OSSR/skills/start/SKILL.md" && _r=0
_pin "$_r" "start/SKILL.md §11 authors the spec from §4-§10 only - the audit reads it without section 7"
# (B) spine-close reconciliation covers a MERGED resumed PR and repo-agnostic limits.
#     Narrowed at #633 round 3 (operator): no instruction deletes ledger lines - a line
#     names its PR but not its repo, so a deletion can remove another repo's limit.
_r=1; grep -Fq 'On a MERGED resumed PR' "$_SC" && grep -Fq 'a repo-agnostic limit stays only on the first hosting repo' "$_SC" && grep -Fq 'does not repair those lines' "$_SC" && ! grep -Fq 'Remove each one that belongs to another repo' "$_SC" && _r=0
_pin "$_r" "spine-close.md's reconciliation skips a MERGED resumed PR, leaves repo-agnostic limits on every PR, or deletes ledger lines it cannot attribute to a repo"

# #633 round 2 - one Codex class, pinned red before its fix.
# (C) the reconciliation edits only the Known limits section, on open AND merged PRs.
_r=1; grep -Fq "Edit only the body's \`## Known limits\` section" "$_SC" && ! grep -Fq 'past editing' "$_SC" && _r=0
_pin "$_r" "spine-close.md's reconciliation rewrites every field after pushed-tip (discarding review edits) or calls a merged body uneditable"


# 1.13.3 (#265, #266) - one pin per defect, each red on 1.13.2's text. The
# behaviour itself is judged by the start-occupied-destination eval surface;
# these pins hold only the wiring a model would need to find it.
_SS="$_OSSR/skills/start/SKILL.md"
# (#265a) start §2's re-authoring guard fires on a MASTER-SPEC of any schema.
_r=1; grep -Fq 'A MASTER-SPEC of any schema, lean or legacy, already exists at the routing' "$_SS" && ! grep -Fq 'A lean MASTER-SPEC already exists at the routing destination' "$_SS" && _r=0
_pin "$_r" "start/SKILL.md §2's re-authoring guard is keyed on a lean MASTER-SPEC - a legacy spec walks past it into the writes"
# (#265b) start §3 settles occupied destinations before init, and §13 honours them.
_r=1; grep -Fq 'settle every occupied destination' "$_SS" && grep -Fq 'honour the per-file answers §3 collected' "$_SS" && [ -f "$_OSSR/skills/start/references/occupied-destinations.md" ] && _r=0
_pin "$_r" "start/SKILL.md has no occupied-destination rule before its first write - an existing MASTER-SPEC, CLAUDE.md or LIVE memory-bank file is overwritten"
# (#265c) the rule asks per file and never moves, merges or migrates on its own.
_OD="$_OSSR/skills/start/references/occupied-destinations.md"
_r=1; [ -f "$_OD" ] && grep -Fq 'oss repo_root ai_workspace' "$_OD" && grep -Fq 'no default, no automatic move, merge or migration' "$_OD" && grep -Fq 'Not offered for the MASTER-SPEC' "$_OD" && grep -Fq 'Never write a file whose path was' "$_OD" && _r=0
_pin "$_r" "occupied-destinations.md does not resolve the AI workspace or allows an answer the operator did not give"
# (#266) doctor's and close's fail: state remedy names the ceremonies that own init.
_r=0
for _f in "$_OSSR/skills/doctor/references/state-inspection.md" "$_OSSR/skills/close/SKILL.md"; do
  grep -Fq '`oss init <name>`' "$_f" && { _r=1; echo "  (#266 site: $(basename "$_f"))"; }
  grep -F '| `fail: state` |' "$_f" | grep -Fq '/ossify:start' || { _r=1; echo "  (#266 no /ossify:start in: $(basename "$_f"))"; }
  grep -F '| `fail: state` |' "$_f" | grep -Fq 'on Codex the `start`/`adopt` skills' || { _r=1; echo "  (#636 no Codex route in: $(basename "$_f"))"; }
done
_pin "$_r" "the fail: state remedy names a bare init - following it leaves state that /start and /adopt both refuse"

# --- 1.13.4 (#154, #561, #301, #299) -----------------------------------------
# One pin per prose rule the four fixes ship. The behavioural half of each is
# held by phases (d)-(f) above, which extract and EXECUTE the blocks; these hold
# the words a model has to find to act at all. Each is red on 1.13.3's text.
_SV4="$_OSSR/skills/doctor/references/spec-validation.md"
_SI4="$_OSSR/skills/doctor/references/state-inspection.md"
# (#154) the drift check says SETS, and refuses an unreadable half out loud.
_r=1; grep -Fq 'Compare identifier *sets*, never their counts' "$_SV4" && grep -Fq 'an unreadable half is not an empty one' "$_SV4" && ! grep -Fq 'Compare against the row count of section 4' "$_SV4" && _r=0
_pin "$_r" "spec-validation §3 still compares counts (or lost its refusal arm) - a mismatch with equal counts in both directions reads clean"
# (#561) the re-point remedy takes its verb from the roster's KIND, and §5 names
# the state-versus-manifest gate its block now applies.
_r=1; grep -Fq "chosen from the surface's own" "$_SI4" && grep -Fq 'never guessed from the id' "$_SI4" && grep -Fq "The sweep is about THIS directory's state" "$_SI4" && _r=0
_pin "$_r" "state-inspection §5 offers both re-point verbs for an unmatched surface, or does not document the state-versus-manifest gate"
# (#301) the ADR file joins the series it finds; the default is only for an EMPTY
# directory; the trailer admits adoption as a third source with adopt's baseline.
_AD4="$_OSSR/skills/start/references/bones-registry.md"
_r=1; grep -Fq 'joins the target repo' "$_AD4" && grep -Fq 'When that directory is **empty**' "$_AD4" && grep -Fq 'Never add the prefix to, or' "$_AD4" && _r=0
_pin "$_r" "bones-registry §3 prescribes one filename form regardless of the repo's series - the rule contradicts the reason bone ADRs live in that repo"
_HR4="$_OSSR/skills/close/references/harvest.md"
_r=1; grep -Fq 'source: report|handoff|adoption' "$_HR4" && grep -Fq 'a source that is exactly `report`, `handoff` or' "$_HR4" && grep -Fq 'r0 baseline <sha>' "$_HR4" && _r=0
_pin "$_r" "harvest's trailer grammar admits only report|handoff - an adopted series cannot be recorded honestly"
_r=1; grep -Fq '`source: adoption`' "$_OSSR/skills/adopt/SKILL.md" && grep -Fq 'r0 baseline <sha>' "$_OSSR/skills/adopt/SKILL.md" && _r=0
_pin "$_r" "adopt C5 routes to harvest's provenance trailer without naming its source - the actor's own site never says what to write"
# (#299) the private boundary inventory has ONE address, stated where the actor
# writes it, and the two sites that claimed a state index now say the truth.
_PB4="$_OSSR/skills/start/references/posture-block.md"
_r=1; grep -Fq '`<ai-workspace>/docs/private-boundary-inventory.md`' "$_PB4" && grep -Fq 'convention, not a route' "$_PB4" && ! grep -Fq 'indexed from `project-state.json`' "$_PB4" && _r=0
_pin "$_r" "posture-block §7 leaves the private boundary inventory unnamed (or still claims a project-state index that does not exist) - every adopter names it differently"
_r=1; ! grep -Fq 'indexed from' "$_OSSR/skills/close/references/boundary-audit.md" && grep -Fq 'docs/private-boundary-inventory.md' "$_OSSR/skills/close/references/boundary-audit.md" && grep -Fq "if it cannot be located, this step is" "$_OSSR/skills/close/references/boundary-audit.md" && _r=0
_pin "$_r" "boundary-audit still names a state index for the inventory, drops its convention path, or loses the INCONCLUSIVE arm for an adopted file"
# (#299) "root" is a PATH, not a repo key - the clause the Rust-workspace case
# needs - and the critic's non-interactive default RECORDS that nobody answered.
_r=1; grep -Fq 'The value is a PATH, not a repo key' "$_PB4" && grep -Fq 'the crate/workspace directory *inside*' "$_PB4" && _r=0
_pin "$_r" "posture-block §10 leaves 'composition root' meaning both the repo and the crate inside it"
_r=1; grep -Fq 'the audit ran with no operator answer' "$_OSSR/skills/start/SKILL.md" && grep -Fq "into §13's hand-off line, which is the record" "$_OSSR/skills/start/references/critic-moment.md" && ! grep -Fq 'record that no operator' "$_OSSR/skills/start/SKILL.md" && _r=0
_pin "$_r" "the critic moment's non-interactive default records that no operator answered with no named destination - each run invents where the record lands (round 1, R11)"
# (#299) the inventory is a CHECKED destination now, not an output nobody can
# find - occupied-destinations lists it with its path like every other output.
_r=1; grep -Fq 'and the private boundary inventory' "$_OSSR/skills/start/references/occupied-destinations.md" && grep -Fq '<ai-workspace>/docs/private-boundary-inventory.md' "$_OSSR/skills/start/references/occupied-destinations.md" && _r=0
_pin "$_r" "occupied-destinations leaves the private inventory among the outputs no route names - /start cannot check a file it cannot address"

# --- 1.13.4 round 1 (#561 R1/R8/R14/R15): one state-path name per surface -----
# §5 consumes §2's resolved `$sf` (never a second spelling of the precedence, and
# exactly ONE resolver call for the routed half); §3 keeps its own differently
# named `sv_state` so a composed read-out cannot reassign either; and the gate's
# rationale has one owner - the §5 prose - with the block comment pointing at it
# instead of arguing a third time.
_r=1; [ "$(grep -v '^[[:space:]]*#' "$_SW" | grep -c 'state_path')" = 1 ] && ! grep -Fq 'sf="${OSS_STATE_FILE:-}"' "$_SW" && grep -Fq 'consumed, never re-derived' "$_SW" && _r=0
_pin "$_r" "state-inspection §5 re-derives the state path (a second precedence spelling, or more than one state_path call) instead of consuming §2's \$sf"
_r=1; grep -Fq 'names it **`sv_state`** and not `sf`' "$_SV4" && grep -Fq 'sv_state' "$_SI4" && _r=0
_pin "$_r" "spec-validation §3 names its manifest-routed state \$sf - the same name state-inspection §2 uses for the override-first path, so one surface can reassign the other's state"
_r=1; grep -Fq 'owned by the prose under this fence' "$_SW" && [ "$(grep -c 'as written' "$_SI4")" = 1 ] && _r=0
_pin "$_r" "state-inspection's foreign-gate rationale is argued in more than one place (or the block comment no longer points at its owner) - three independently-worded copies drift"
# The gate must not read an empty routed answer as consent: an unresolvable route
# refuses, and that arm must be reachable (the `-n "$routed"` precondition that
# bypassed it is gone).
_r=1; grep -Fq '[ -z "${sf:-}" ] || [ -z "$routed" ] || [ "$sf" != "$routed" ]' "$_SW" && ! grep -Fq 'elif [ -n "$routed" ] &&' "$_SW" && _r=0
_pin "$_r" "state-inspection §5 bypasses the foreign-state gate when the manifest route resolves to nothing (F1) - a foreign registry is swept against this directory's repos"

# --- 1.13.4 round 1 (d)(e): the inventory's other name, the rubric's third source, the last stale form
# (R5 + CR1) an adopted inventory under another name must be FOUND, not duplicated.
_OD4="$_OSSR/skills/start/references/occupied-destinations.md"
_r=1; grep -Fq 'docs/*inventor*.md' "$_OD4" && grep -Fq 'never create a second one' "$_OD4" && _r=0
_pin "$_r" "occupied-destinations checks the inventory at the convention path only - an adopted project's own inventory name gets a silently minted duplicate beside it"
# (C5, round 1) ... and a NAME match is not an equivalence: the glob also hits
# `dependency-inventory.md` / `asset-inventory.md`, so the check probes contents
# for §7's moat columns and names a name-only match to the operator as a
# POSSIBLE inventory instead of equating it (which would suppress the real one).
_r=1; grep -Fq 'A name is not' "$_OD4" && grep -Fq 'the moat columns' "$_OD4" && grep -Fq '**possible** inventory' "$_OD4" && grep -Fq 'never write the inventory past an unanswered candidate' "$_OD4" && ! grep -Fq 'A match under' "$_OD4" && _r=0
_pin "$_r" "occupied-destinations equates a filename match with the inventory - a docs/dependency-inventory.md is presented as the destination and keeping it suppresses the real moat inventory (round 1, C5)"
# (R4) the eval rubric admits adoption as the third legal source, in both directions.
_R4="$_OSSR/tests/eval/rubrics/harvest-apply-integrity.md"
_r=1; grep -Fq '`report`, `handoff` or `adoption`' "$_R4" && grep -Fq 'adoption` is a legal source' "$_R4" && ! grep -Fq 'a source outside' "$_R4" && _r=0
_pin "$_r" "the harvest-apply-integrity rubric still grades a legal adoption set as a refusal - the judge contract contradicts the shipped prose"
# (R7) no shipped site prescribes the fixed lowercase form any more.
_SP4="$_OSSR/skills/start/references/spike-contract.md"
_r=1; ! grep -Fq 'docs/adr/adr-NNNN-*.md' "$_SP4" && grep -Fq "whatever form that repo's series already uses" "$_SP4" && _r=0
_pin "$_r" "spike-contract still points at the fixed adr-NNNN-*.md form - an actor on an adopted series writes a second form into one directory"

# --- 1.14.0 (#133, #362): run-spine re-entry -------------------------------------
_RO="$HERE/../skills/work-item/references/round-orchestration.md"
_EX="$HERE/../skills/work-item/references/external-executor.md"
_HC="$HERE/../skills/work-item/references/handoff-contract.md"
_WC="$HERE/../skills/close/references/work-item-close.md"
_SA="$HERE/../skills/plan-spine/references/spec-authoring.md"
_RS="$HERE/../skills/run-spine/SKILL.md"
for _pair in "$_RO|halt: spine_inventory could not read the spine" "$_RO|The count lives in state" "$_RO|halt:out-of-order" \
             "$_EX|## 2a. Re-entry — counting, and a staged result at request time" "$_EX|The lane counts each request it issues" "$_HC|; it is the evidence." \
             "$_SA|re-entering" "$_RS|resumes"; do
  _f="${_pair%%|*}"; _lit="${_pair#*|}"
  _r=1; grep -Fq -- "$_lit" "$_f" && _r=0
  _pin "$_r" "$(basename "$_f") does not state '$_lit' (1.14.0 re-entry)"
done
# 1.26.0: an item with an open PR reads `in-flight` on re-entry (no dispatch in
# any mode; the barrier reports it, never halts), and a complete item whose PR
# merged remotely but not locally is `halt:pr-not-local`.
for _pair in "$_RO|| \`in-flight\` | nothing, in every mode" "$_RO|an \`in-flight\` row counts as" \
             "$_RO|| \`halt:pr-not-local\` — a \`complete\` item with a PR recorded" "$_RO|never merge the work branch locally — that forks the local spine branch from the remote" \
             "$_RO|An \`in-flight\` item gets no dispatch either, in every mode" "$_RO|An \`in-flight\` item (§2b) is not a" \
             "$_EX|item (its PR open, \`round-orchestration.md\` §2b) gets no request either" \
             "$_EX|the lane ends only after issuing every" "$_EX|(\`close-finished\`, \`in-flight\`, an unrepaired \`finish-merge\`), it reports them" \
             "$_EX|| \`in-flight\` | no request; reported with its PR; the caller merges it |"; do
  _f="${_pair%%|*}"; _lit="${_pair#*|}"
  _r=1; grep -Fq -- "$_lit" "$_f" && _r=0
  _pin "$_r" "$(basename "$_f") does not state '$_lit' (1.26.0 in-flight)"
done
_r=1; ! grep -Fq 'with no request to issue (`close-finished`), the lane reports them' "$_EX" && _r=0
_pin "$_r" "external-executor.md §2b still ends the detached lane on a close-finished item before issuing the round's other requests (R4)"
# 1.15.0 - the run-spine grammar rails moved with the body into the skill (Rule 2).
for _lit in 'Exactly three command shapes are accepted' 'refuse before the spine-branch cut, naming' 'refuse rather than guess'; do
  _r=1; grep -Fq -- "$_lit" "$_RS" && _r=0
  _pin "$_r" "skills/run-spine/SKILL.md does not state '$_lit' (1.15.0 grammar rails)"
done
# run-spine outside the slash command (I2), OMP's explicit implementer dispatch
# (#744), and the adjacent Codex refusal control (I3).
for _lit in 'arrive as tokens in the request' \
  'On OMP whose `task` tool lists an `implementer` agent (omp-roles 0.2.0+), dispatch each item with `task`, setting `agent: "implementer"` in every `tasks[]` entry (never `task`).' \
  'On a harness with neither (Codex, or OMP without that agent), refuse before the spine-branch cut, naming `--external-executor`.'; do
  _r=1; tr '\n' ' ' < "$_RS" | tr -s ' ' | grep -Fq -- "$_lit" && _r=0
  _pin "$_r" "skills/run-spine/SKILL.md does not state '$_lit' (1.15.0 final review)"
done
# The OMP alias belongs beside the actual default dispatch call.
_r=1; grep -Fq '(OMP: task with agent "implementer" — same handoff path in, same JSON out)' "$_RO" && _r=0
_pin "$_r" 'round-orchestration.md does not name the OMP implementer dispatch alias (#744)'
_CL="$HERE/../skills/close/SKILL.md"
_SCL="$HERE/../skills/close/references/spine-close.md"
for _f in "$_CL" "$_SCL"; do
  _r=1; grep -Fq 'skill://work-pr' "$_f" && _r=0
  _pin "$_r" "$(basename "$_f") does not hand the PR to work-pr on OMP (skill://work-pr) - 1.15.0 final review I1"
  _r=0; tr '\n' ' ' < "$_f" | tr -s ' ' | grep -Fq -e 'not published on Codex' -e 'Codex today' -e 'does not carry `/ossify:work-pr`' && _r=1
  _pin "$_r" "$(basename "$_f") still says work-pr is unavailable on Codex - false since 1.15.0, a Codex close would skip the P1 rail"
done
# Fix round 1: the staged-result rule is SCOPED to a `close-finished` item -
# one the caller has not executed in this session. A close-rejected result also
# leaves a staged worktree, and a literal reading would hand that rejected
# result back instead of running §7's correction. `close-finished` alone cannot
# pin the scope (the pre-fix paragraph already named the route in its
# parenthetical), so the pin is the scoping clause's own gloss.
for _pair in "$_EX|without executing" "$_EX|one the caller has not executed in this session"; do
  _f="${_pair%%|*}"; _lit="${_pair#*|}"
  _r=1; grep -Fq -- "$_lit" "$_f" && _r=0
  _pin "$_r" "$(basename "$_f") does not state '$_lit' (1.14.0 re-entry, fix round 1)"
done
# The old claims must be GONE - each was true of 1.13 and is false now.
for _pair in "$_RO|does not resume it" "$_RO|here or nowhere" "$_RO|is taken from HEAD in this release" \
             "$_HC|the lane takes HEAD, not the plan" "$_WC|is the open reconciliation"; do
  _f="${_pair%%|*}"; _lit="${_pair#*|}"
  _r=0; grep -Fq -- "$_lit" "$_f" && _r=1
  _pin "$_r" "$(basename "$_f") still claims '$_lit' - false since 1.14.0"
done
# Final fix wave (I1, I2, M6, M2, M1, m1). §3 must route the items §2b step 4
# repaired: an adopt item is active/clean/at-base and takes the redispatch path,
# a reattached item follows its re-run route, and an item now complete (skip,
# finish-merge, finish-status) gets no step and no second wait at §7. A literal
# reader without this sends a repaired item down the spawn path, where
# worktree_add returns rc 8. §2 of external-executor agrees: complete items get
# no request. Separately: a failed reattach halts; the §1 field list carries
# dispatches; the cut-missing repair completes a cut rather than unwinding one;
# and the external caller counts only what the lane did not request, reading
# the count before it checks it.
_r=1; grep -Fq 'takes the `redispatch` path too' "$_RO" \
  && grep -Fq 'no handoff, no request, no dispatch' "$_RO" \
  && grep -Fq 'does not wait on it again' "$_RO" && _r=0
_pin "$_r" "round-orchestration.md §3 leaves the items §2b step 4 repaired unrouted - adopt gets no redispatch path, complete gets no skip (I1)"
_r=1; grep -Fq 'takes whatever route the re-run' "$_RO" && _r=0
_pin "$_r" "round-orchestration.md §3 drops a reattached item's re-run route (I1)"
_r=1; grep -Fq 'halts naming the git error' "$_RO" \
  && grep -Fq 'never `git worktree prune`, never `-f -f`' "$_RO" && _r=0
_pin "$_r" "round-orchestration.md §2b step 4 no longer halts a failed reattach naming the git error, or reopens prune/-f -f (M6)"
_r=1; grep -Fq -- '{branch, worktree_path, base_sha, dispatches}' "$_RO" && _r=0
_pin "$_r" "round-orchestration.md §1's work_items[] field list omits dispatches while §5 reads it (M2)"
_r=1; grep -Fq 'completes now: it cuts the branch in the repos the halt never reached' "$_RO" \
  && ! grep -Fq 'unwinds now' "$_RO" && _r=0
_pin "$_r" "round-orchestration.md §2 still says the cut-missing repair unwinds the earlier cut - it completes it, from the recorded base (M1)"
_r=1; grep -Fq 'each execution the lane did not request' "$_EX" \
  && grep -Fq 'read `dispatches` first' "$_EX" \
  && ! grep -Fq 'a correction, a replacement' "$_EX" && _r=0
_pin "$_r" "external-executor.md §2a still leaves the gaps replacement on the caller's count list, or checks the count after incrementing (I2)"
_r=1; grep -Fq 'neither gets a request' "$_EX" && _r=0
_pin "$_r" "external-executor.md §2 no longer says a complete item gets no request (I1)"
_r=1; grep -Fq 'on re-entry a request for a' "$_OSSR/CHANGELOG.md" \
  && grep -Fq 'one this session has not executed' "$_OSSR/CHANGELOG.md" && _r=0
_pin "$_r" "ossify/CHANGELOG.md's 1.14.0 entry states the staged-result rule without its close-finished, not-executed-this-session scope (m1)"

# Fix round (#673), one pin per class of claim the round's findings named.
_SC="$HERE/../skills/close/references/spine-close.md"
_SI="$HERE/../skills/doctor/references/state-inspection.md"
_IC="$HERE/../skills/close/references/impl-check.md"
# A6: recorded execution state with no spine branch is a halt, not a re-cut.
_r=1; grep -Fq 'refs are gone while its state survives' "$_RO" \
  && grep -Fq 'no item records execution' "$_RO" && _r=0
_pin "$_r" "round-orchestration.md §2's arm selector does not halt on recorded execution state with no spine branch (A6)"
# C3/K1/L1/B2: the finish-merge row carries its repo-root recovery, the gate
# RE-RUN (the report-presence gate is gone - a present report proves nothing),
# and the tip recovery.
# D4: the halt name recurs (the halt table defines the row too), so the pin is
# the finish-merge cell's own decision.
pin "$_RO" 'Red → `halt:unverified-merge`, naming the item' \
  "round-orchestration.md's finish-merge row does not halt with halt:unverified-merge when its RE-RUN of close §2 comes back RED (#673 K1)"
_r=1; grep -Fq 'refs/heads/$wi_branch' "$_RO" \
  && grep -Fq 'RE-RUN close §2' "$_RO" \
  && grep -Fq 'repo_root="$(oss repo_root "$target_repo")"' "$_RO" \
  && ! grep -Fq 'as gate evidence' "$_RO" \
  && grep -Fq 'the row reads `wt=present` but state holds no `worktree_path` yet' "$_RO" && _r=0
_pin "$_r" "round-orchestration.md §2b's finish-merge row drops its repo-root recovery, the §2 gate re-run, or the tip recovery (C3/K1/L1), still claims report.md is gate evidence, or the adopt row leaves \$wt undefined again (B2)"
# C2: the rejection is durable and its route is named.
# D4: halt:close-rejected recurs (two inline mentions plus the table row), so
# the pin is the row that defines it.
pin "$_RO" '| `halt:close-rejected` | the result' \
  "round-orchestration.md's halt table no longer defines halt:close-rejected for a recorded [fidelity] rejection (#673 C2)"
_r=1; grep -Fq 'durable rejection record' "$_IC" \
  && grep -Fq 'is recorded durably' "$_WC" && _r=0
_pin "$_r" "the C2 rejection record is not named where it is written (impl-check/work-item-close)"
# D1: the correction route is named in the lane, and the setter validates.
# D4: spine_base_reset recurs (the prose above and the halt row), so the pin is
# the halt row's own repair sentence.
pin "$_RO" 'record the new name with `oss spine_base_reset' \
  "round-orchestration.md's halt:base-unresolved row no longer names spine_base_reset for a wrong recorded base (#673 D1)"
_r=1; grep -Fq 'must EXIST locally' "$_RO" && _r=0
_pin "$_r" "round-orchestration.md drops the setter's branch-exists validation note (D1)"
# F2: close §3 reads the RECORDED base; the old false claim is gone.
# D4: spine_base_get recurs three times inside §3, so the pin is the sentence
# that tells the reader to read it.
pin "$_SC" 'the checkout where a base is recorded for it (`oss spine_base_get' \
  "spine-close.md §3 does not read the recorded base (spine_base_get) (F2)"
_r=1; ! grep -Fq 'The two facts this step needs are not in state' "$_SC" && _r=0
_pin "$_r" "spine-close.md §3 still claims both facts are absent from state (F2)"
# F3: both 'was this item dispatched' enumerations carry the count.
_r=1; grep -Fq 'a `dispatches` count above zero' "$_WC" \
  && grep -Fq 'positive `dispatches` count' "$_SI" && _r=0
_pin "$_r" "the abandoned-item drift enumerations (close §1, doctor §5) omit the dispatches count again (F3)"
# Fix round 2 (G2/G3/H1/I1/I2/J1): one pin per new fail-closed claim the
# round's findings named. Each literal is a distinct row or clause a reader
# acts on; drop any one and the corresponding behavior loses its contract.
# D4: halt:base-unresolved recurs (the §2a prose and the halt table), so the pin
# is the row that defines it.
pin "$_RO" '| `halt:base-unresolved` — a repo row' \
  "round-orchestration.md's halt table no longer defines halt:base-unresolved for a recorded base that will not resolve (G2/G3)"
_r=1; grep -Fq 'a `verify.md` rejection record' "$_RO" \
  && grep -Fq 'a completed item'"'"'s dirty worktree halts here too' "$_RO" \
  && grep -Fq 'a history rewrite, never a landing' "$_RO" \
  && grep -Fq 'validation precedes every removal' "$_RO" \
  && grep -Fq 'a recorded rejection is never re-landed by a merge' "$_RO" && _r=0
_pin "$_r" "round-orchestration.md drops a fix-round-2 fail-closed claim (the verify.md read; the dirty complete-item halt; the rewrite-is-no-landing clause; reattach's validate-before-remove; the merge-arm rejection gate) (G2/G3/H1/I1/I2/J1)"
# Fix round 3 (L2/L3/L4): the guards the round added are contract claims too.
_r=1; grep -Fq 'halt:branch-unknown' "$_RO" \
  && grep -Fq 'no branch ever recorded' "$_RO" \
  && grep -Fq 'the registration is LOCKED' "$_RO" \
  && grep -Fq 'never reused for reattach, redispatch or merge' "$_RO" && _r=0
_pin "$_r" "round-orchestration.md drops a fix-round-3 guard claim: the halt:branch-unknown row, the locked-holder clause, or the foreign-branch clause (L2/L3/L4)"

# #703 R4: pins on the actor's halt table and abandoned-item instructions.
_R4_TABLE="$(sed -n '/^| Halt row |/,/^\*\*5\./p' "$_RO")"
t_assert_contains "$_R4_TABLE" 'only when neither the conventional nor a differing recorded path is occupied' 'R4 cleanup skip names occupied-path precondition'
t_assert_contains "$_R4_TABLE" 'the `spine_base_get` base getter' 'R4 unreadable row names base getter'
t_assert_contains "$_R4_TABLE" 'an `abandoned` item retaining execution evidence' 'R4 abandoned evidence halt has owning row'
t_assert_contains "$_R4_TABLE" 'The operator decides which record is right' 'R4 abandoned repair belongs to operator'
_R4_ITEMS="$(sed -n '/^## 3\. Per work item/,/^## 4\./p' "$_RO")"
t_assert_contains "$_R4_ITEMS" 'never skip that shape or dispatch it' 'R4 section3 follows abandoned evidence halt'

# C: deterministic contract checks supplement, never replace, fresh LLM evals.
_C_DIR="$HERE/eval/fixtures/adopt-multi-repo"
_C03="$(cat "$_C_DIR/03-clean-two-repo-baseline-and-aggregated-adrs.md")"
t_assert_contains "$_C03" 'ADR-0003-idempotency-key-on-charge-create.md' 'C1 fixture03 holds distinct references'
_C06="$(cat "$_C_DIR/06-same-reference-in-two-repos-halts.md" 2>/dev/null)"
t_assert_contains "$_C06" 'expected_outcome: halt' 'C2 fixture06 pins collision halt'
t_assert_contains "$_C06" 'mints no bone' 'C2 collision answer key forbids mint'
_CR="$(cat "$HERE/eval/rubrics/adopt-multi-repo.md")"
t_assert_contains "$_CR" 'reference held by two repos halts' 'C3 rubric scores collision halt'
t_assert_contains "$(cat "$SKILLS/adopt/SKILL.md")" 'repo names from the captured inventory' 'C4 collision names come from B7 inventory'

# D: source-reporting prose contract, identity remains text-only.
_D_SECTION="$(sed -n '/^## 7\./,/^## 8\./p' "$SKILLS/close/references/harvest.md")"
t_assert_contains "$_D_SECTION" "existing trailer's source" 'D1 duplicate skip names existing source'
t_assert_contains "$_D_SECTION" "skipped candidate's source" 'D1 duplicate skip names candidate source'
_D06="$(cat "$HERE/eval/fixtures/harvest-apply-integrity/06-adoption-duplicate-under-report-trailer.md" 2>/dev/null)"
t_assert_contains "$_D06" 'source: adoption' 'D2 adoption/report duplicate fixture exists'
t_assert_contains "$_D06" 'source: report' 'D2 duplicate fixture declares existing report trailer'
t_assert_contains "$(cat "$HERE/eval/rubrics/harvest-apply-integrity.md")" 'both sources' 'D2 rubric scores the skip message'

# E: no shipped file points at the deleted dispatcher rule. The file
# is gone, so a pointer sends a model hunting for `oss` (spec A, PR 1). The
# needle is split so this file does not match itself.
# Tracked files only: an installed plugin cache holds older ossify versions that
# still ship the rule, and a checkout's ignored worktrees hold old commits.
_E_RULE="rules/dispatcher""-path.md"
_E_ROOT="$(cd "$HERE/../.." && pwd)"
if git -C "$_E_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  _E_HITS="$(git -C "$_E_ROOT" grep -lF "$_E_RULE" -- . ':!CHANGELOG.md' ':!*/CHANGELOG.md')"
  _E_RC=$?
  # git grep exits 1 on no match; anything else is an error, never a pass.
  [ "$_E_RC" -le 1 ] || _E_HITS="git grep failed (rc=$_E_RC)"
  t_assert_eq "" "$_E_HITS" 'E1 no tracked file in the marketplace names the deleted dispatcher rule'
else
  echo "SKIP: E1 needs a git checkout of the marketplace ($_E_ROOT is not one)"
fi
# E2: the start skill routes a one-change amendment to no command. The only
# /amend-spec was scaffold-onboard's, deleted with it (spec A, PR 3); ossify's
# spec-validation says ossify ships none.
t_assert_eq "" "$(grep -n '/amend-spec' "$SKILLS/start/SKILL.md")" 'E2 start names no /amend-spec command'

rm -rf "$_PC_TMP"

# D7 (#749): the check-before-write block is fixed text, exactly once, in each
# skill whose actor edits files by its own steps. `pin` is the contract here: a
# hard wrap inside the block, or a second copy, is a FAIL.
CBW='**Check before you write.** Check every precondition before the first write: each file you edit exists and each text you replace is there exactly once; each file you create does not exist yet. Give every check a message that names what failed. A script that asserts after it writes leaves the edit half-applied.'
for f in work-item/SKILL.md patch/SKILL.md close/references/harvest.md adopt/SKILL.md plan-spine/SKILL.md; do
  pin "$HERE/../skills/$f" "$CBW" "check-before-write block, verbatim and once, in $f"
done
# D5, moved by #951: the implementer no longer verifies its own tests. No
# self-verification text survives in the work-item tree or its registration.
t_assert_eq "" "$(grep -rn -e 'Can each test fail' -e 'verification-before-completion' -e 'whether it can fail' "$WI" "$HERE/../agents/implementer-agent.md")" \
  "work-item and implementer-agent carry no self-verification step (#951)"
# #951: the check moved to close, run by a fresh verifier (impl-check §4c).
_IC951="$HERE/../skills/close/references/impl-check.md"
_WC951="$HERE/../skills/close/references/work-item-close.md"
_VA951="$HERE/../agents/verifier-agent.md"
pin "$_IC951" '**Can each test fail?**' "impl-check §4c carries the can-it-fail check (#951)"
pin "$_IC951" '[mutation]           <test> - stayed green with <mutation> applied on its path' \
  "impl-check §5 lists the [mutation] tag (#951 D8)"
pin "$_IC951" 'Five tags, spelled exactly as above.' "impl-check §5 says five tags (#951 D8)"
pin "$_IC951" '| `[mutation]` — §4c |' "impl-check §6's recovery table has the [mutation] row (#951 D8)"
pin "$_IC951" 'held. This **halts** with `[mutation]`.' "impl-check §4c halts only on an evidenced stayed-green (#951 D8)"
pin "$_VA951" 'tools: Bash, Read, Edit, Glob, Grep' "verifier-agent's registration grants exactly its five tools (#951 D4)"
t_assert_eq 1 "$(awk '/^tools: /{n++} END{print n+0}' "$_VA951")" "verifier-agent has one tools line (#951)"
t_assert_eq "tools: Bash, Read, Edit, Glob, Grep" "$(awk '/^tools: /{print; exit}' "$_VA951")" "verifier-agent's tools line is exact (#951 D4)"
pin "$_VA951" 'model: inherit' "verifier-agent inherits its model unless close passes one (#951 D6)"
pin "$_VA951" '§4, §4b and §4c, and follow them.' "verifier-agent points at impl-check §4, §4b and §4c (#951 D2)"
pin "$_VA951" '{"mode": "verified", "model": "<model you run>", "rule": [{"file","line","pattern","claim"}], "lenses": [<impl-check.md §4b finding schema>], "mutation": [{"test","mutation","result": "red | stayed-green | undetermined","evidence"}]}' \
  "verifier-agent restates the verified return shape (#951 D4)"
pin "$_VA951" '{"mode": "refused", "reason": "<the input you could not read>"}' "verifier-agent restates the refused return (#951 D4)"
pin "$_WC951" 'When `OSSIFY_VERIFIER_MODEL` is set' "work-item-close §2 reads OSSIFY_VERIFIER_MODEL (#951 D6)"
pin "$_WC951" '`model: inherit` applies; print `verifier model: inherited (same as this' "work-item-close §2 prints the inherited-model notice (#951 D6)"
pin "$_WC951" '`verifier: inline — <host or why>`' "work-item-close §2 names the inline fallback line (#951 D7)"
pin "$_WC951" '`verifier: ossify:verifier-agent on <model>`' "work-item-close §2 names the dispatched-verifier summary line (#951 D4)"
pin "$_WC951" '`agent: "verifier"` (omp-roles 0.10.0+), not the default `task` agent.' "work-item-close §2 dispatches the OMP verifier by agent name (#970)"
pin "$_WC951" 'OMP with no `verifier` in `task`'"'"'s agent list' "work-item-close §2 keeps the inline route for an OMP without the agent (#970)"
pin "$_WC951" '`task.agentModelOverrides.verifier`, else the session' "work-item-close §2 names OMP's model source (#970)"
t_assert_eq 1 "$(awk '/^allowed-tools:/ && /, Task$/ {n++} END{print n+0}' "$HERE/../commands/close.md")" \
  "commands/close.md grants Task so a standalone /close can dispatch the verifier (#951)"
pin "$SKILLS/close/SKILL.md" '`[mutation]`), and the `verifier:` line' "close SKILL.md §10's summary names the [mutation] tag and the verifier line (#951)"

# ---------------------------------------------------------------------------
# 1.19.0 (#497): the bones a spine's PLAN declares. plan-spine writes SPINE.md's
# `## Bones this spine registers` — the table whose columns are `oss bone_add`'s
# four arguments in its order, or the single line `None.` — and spine-close
# registers those rows before its touch check (that reader half is pinned with
# the close-side contracts above). The two surfaces must name the same section
# and the same column ORDER: bone_add is positional, so a swapped column
# registers the title where the touch surface belongs, silently.
# ---------------------------------------------------------------------------
_PS_SPINE="$SKILLS/plan-spine/SKILL.md"
_PS_SPEC="$SKILLS/plan-spine/references/spec-authoring.md"
pin "$_PS_SPINE" 'its last section is `## Bones this spine registers`' \
  "plan-spine SKILL.md finishes SPINE.md with the bones section (#497)"
pin "$_PS_SPINE" 'an ADR the plan only *cites* is not a row' \
  "plan-spine SKILL.md says a row is a bone the spine CREATES (#497)"
pin "$_PS_SPEC" '## Bones this spine registers' \
  "spec-authoring.md's pinned-sections list carries the bones section (#497)"
pin "$_PS_SPEC" '| ADR | Title | Touch surface (glob csv) | Revisit when |' \
  "spec-authoring.md pins the bones table's four columns in oss bone_add's order (#497)"
pin "$_PS_SPEC" 'the single line `None.`' \
  "spec-authoring.md states the no-bones answer, the single line None. (#497)"
pin "$_PS_SPEC" 'A row is a bone this spine *creates*' \
  "spec-authoring.md tells the author a cited ADR is not a row (#497)"

# The reader half: spine-close's registration step, between the demo and the
# touch check. Its arms are EXECUTED against a scratch state in test-close.sh's
# B-series; these pins hold the interface the two files share - one section name,
# one column order - and the three messages the ceremony promises by name.
_SCB="$SKILLS/close/references/spine-close.md"
pin "$_SCB" '## 5b. Step 4b — register the bones this spine' \
  "spine-close.md carries the registration step between the demo (#5) and the touch check (#6) (#497)"
pin "$_SCB" '`## Bones this spine registers` table' \
  "spine-close.md reads the same section name plan-spine writes (#497)"
pin "$_SCB" 'four arguments in its order' \
  "spine-close.md names the four columns as bone_add's arguments, in its order (#497)"
pin "$_SCB" 'already registered - skipping' \
  "spine-close.md's already-registered arm skips with its one line (#497)"
pin "$_SCB" 'declares no bones - registering none' \
  "spine-close.md's no-bones arm says so in one line and never halts (#497)"
pin "$_SCB" 'the spine never wrote it' \
  "spine-close.md halts on a declared bone whose ADR file is missing (#497)"
# §1's ceremony table, and the note that keeps it honest. The registration is a
# CORE row in both columns (§5b runs in both; on a flesh spine with `None.` it is
# a no-op), and the note must still refuse to claim the standalone ADR check this
# release does not ship - registering the DECLARED bones is not that check.
pin "$_SCB" '| Bone registration' \
  "spine-close.md §1's ceremony table carries the registration row (#497)"
pin "$_SCB" '**core** (§5b) | **core** (§5b, a no-op when the plan declares `None.`) |' \
  "spine-close.md §1 makes the registration core in BOTH columns (#497)"
pin "$_SCB" '*ADR check* row is **not shipped in this release**' \
  "spine-close.md §1 still refuses to claim the standalone ADR check (§3.3)"

# ---------------------------------------------------------------------------
# Item worktree set-up (#714, #715). A new item worktree holds only tracked
# files, and a spec's start-GREEN ACs reached the handoff only after a wasted
# dispatch. Both contracts are prose across four files; these pins hold the
# lines that carry each half from the spec, through the lane, to the worker.
_RO="$WI/references/round-orchestration.md"
pin "$_RO" "**Prepare the worktree's dependencies before the handoff (#714).**" \
  "round-orchestration.md §3 prepares the item worktree's dependencies before the handoff (#714)"
pin "$_RO" "Never link the primary checkout's copy:" \
  "round-orchestration.md §3 installs per worktree and never links the primary checkout's tree (#714)"
pin "$_RO" "runs §3's dependency step again, and then goes to §5" \
  "round-orchestration.md re-entry repeats the dependency step on redispatch and adopt (#714)"
pin "$_RO" 'Run that step in the recorded worktree: set' \
  "round-orchestration.md re-entry sets \$wt from the recorded worktree_path before the dependency step (#714)"
pin "$_RO" '**Carry the spec'"'"'s start-GREEN lines into §4 (#715).**' \
  "round-orchestration.md §4 copies the spec's start-GREEN lines into the handoff at dispatch 1 (#715)"
pin "$SKILLS/plan-spine/references/spec-authoring.md" 'Expected GREEN at start: AC-<N> — <why it passes before the work>' \
  "spec-authoring.md declares the start-GREEN line the lane copies (#715)"
pin "$WI/references/handoff-contract.md" 'one the spec declares as `Expected GREEN at start:`' \
  "handoff-contract.md §4 carries spec-declared overrides from dispatch 1 (#715)"
pin "$WI/SKILL.md" 'unless the handoff'"'"'s §4 records an override for that AC (below)' \
  "work-item SKILL.md's rc table defers rc 1 to a recorded override (#715)"
pin "$WI/SKILL.md" 'An override applies only when the AC'"'"'s probe returns rc 1;' \
  "work-item SKILL.md §4 honours an override only on rc 1 (#715)"
pin "$WI/SKILL.md" 'excluding any AC whose recorded override §4 honoured' \
  "work-item SKILL.md §5 excludes only an override §4 honoured (#715)"
pin "$WI/SKILL.md" 'declared in the spec at dispatch 1 or granted on a re-dispatch' \
  "work-item SKILL.md §4 honours a spec-declared override at dispatch 1 (#715)"
pin "$HERE/../agents/implementer-agent.md" 'unless the handoff'"'"'s §4 records an override for that AC' \
  "implementer-agent.md's RED-gate row honours a recorded override (#715)"

# ---------------------------------------------------------------------------
# wayfinder's claim re-read and spike approval (#336, #332). Both were two
# shipped files contradicting each other; these pins hold the side each fix chose.
_WF="$SKILLS/wayfinder/references"
pin "$_WF/tracker.md" 'the claim re-read runs the query again (#336)' \
  "tracker.md §2 no longer lists the claim re-read as a reader of the captured response (#336)"
pin "$_WF/tracker.md" 'from a **fresh** run of this query immediately before assigning' \
  "tracker.md §2's claim re-read reads a fresh response, as working.md §1 says (#336)"
pin "$_WF/ticket-types.md" '**A `spike` is dispatched only with an approved contract (#332).**' \
  "ticket-types.md §3 writes and approves a spike's contract before the fan-out (#332)"
pin "$_WF/ticket-types.md" '| `spike` | AFK once its contract has a go (§3) |' \
  "ticket-types.md §1 qualifies spike's AFK mode by the contract's go (#332)"
pin "$_WF/charting.md" 'a `spike` whose contract the operator approved' \
  "charting.md step 6 fires only an approved spike (#332)"
pin "$_WF/tracker.md" 'The claim re-read reads them from a FRESH run of the' \
  "tracker.md §2's query recipe sends the claim re-read to a fresh run (#336)"
pin "$_WF/tracker.md" 'exception is the claim re-read: it runs the query again immediately before' \
  "tracker.md §2's one-call explanation names the claim re-read as its exception (#336)"
pin "$_WF/ticket-types.md" 'the *Decision it enables* field names the map decision the spike unblocks' \
  "ticket-types.md §3 adapts the contract's bone field for maps with no bones (#332)"
pin "$_WF/ticket-types.md" 'is neither claimed nor dispatched: it stays on the frontier' \
  "ticket-types.md §3 leaves a spike with no go unclaimed, so it stays on the frontier (#332)"

# ---------------------------------------------------------------------------
# #281: the dispatched implementer registration grants `Skill`, so the body's
# composition note holds on both invocation paths. The OpenCode adapter that
# pinned a six-tool set was retired (31eb6b9e); these pins hold the three places
# that state the grant, and the "Until #281" wording must be gone.
_AG="$HERE/../agents/implementer-agent.md"
pin "$_AG" 'tools: Bash, Read, Write, Edit, Glob, Grep, Skill' \
  "implementer-agent.md's registration grants Skill (#281)"
pin "$_AG" '`Bash`, `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Skill` — `Skill` only to compose' \
  "implementer-agent.md's binding allowlist names Skill and its one use (#281)"
pin "$WI/SKILL.md" 'the dispatched registration grants it since 1.19.3 (#281)' \
  "work-item SKILL.md §12 says the dispatched path composes too (#281)"
pin "$WI/SKILL.md" 'or the skill is not installed, §5 of this body is the' \
  "work-item SKILL.md §12 falls back to the body when the composed skill is not installed (#281, #951)"
pin "$WI/SKILL.md" 'Where a composed skill and this body disagree, this body wins:' \
  "work-item SKILL.md §12 says the body wins over a composed skill (#281)"
t_assert_eq 0 "$(awk 'index($0, "Until #281") {n++} END {print n+0}' "$WI/SKILL.md")" \
  "work-item SKILL.md no longer says 'Until #281' (#281)"

# ---------------------------------------------------------------------------
# Refusals that need a route that runs (#732, #553). adopt's A3-A5 named only
# scaffold-dev's slice close, which no longer ships; /start's content gate
# refused a declared tooling repo for carrying its own history.
_AD="$SKILLS/adopt/SKILL.md"
pin "$_AD" 'or, where scaffold-dev is no longer installed, close the slice by hand (#732):' \
  "adopt §3's A3-A5 refusals name a by-hand route when scaffold-dev is gone (#732)"
pin "$SKILLS/start/SKILL.md" 'declares under its `tooling_repo` key is not the product (#553)' \
  "start §3's content gate does not count a declared tooling repo as product content (#553)"
pin "$SKILLS/start/SKILL.md" '`.ossify/topology.json` every key is just a repo name, so every declared repo there is checked.' \
  "start §3 limits the tooling-repo exemption to the pairing manifest (#553)"
# #809: the gate reads product source at HEAD, not history. History alone
# proceeds as class H and is recorded in `06-progress.md`'s spec-core-close entry; source at HEAD refuses.
pin "$SKILLS/start/SKILL.md" 'product'"'"'s own source at `HEAD`.' \
  "start §3's content gate asks for product source at HEAD (#809)"
pin "$SKILLS/start/SKILL.md" '**No product source at `HEAD`, history or not,** and the operator confirmed it, or no file is at `HEAD`: proceed as greenfield.' \
  "start §3's content gate proceeds on history alone (#809)"
pin "$SKILLS/start/SKILL.md" '**Product source at `HEAD`:** author nothing and refuse' \
  "start §3's content gate still refuses product source at HEAD (#809)"
pin "$SKILLS/start/SKILL.md" 'only propose; whether `HEAD` holds' \
  "start §3's probe proposes and the operator confirms what HEAD holds (#809)"
pin "$SKILLS/start/SKILL.md" '`06-progress.md`'"'"'s spec-core-close entry records class H history (§3): per repo, commit count and what is at `HEAD`' \
  "start §13 records class H's history in 06-progress.md's spec-core-close entry (#809, #1040)"
pin "$SKILLS/start/SKILL.md" 'note each such repo'"'"'s commit count and what is at `HEAD` for `06-progress.md`'"'"'s spec-core-close entry (§13).' \
  "start §3 routes class H history to 06-progress.md, not to an unnamed hand-off (#1040)"
# ossify 1.37.0 (#1040, operator ruling): with no operator to answer, the content gate refuses a repo with files
# beyond the scaffold (the pre-1.34.0 behaviour), prints what it found and what to do next; it is not the audit's non-interactive rule.
pin "$SKILLS/start/SKILL.md" '- **No operator to answer** (a non-interactive run), checked after the product-source bullet' \
  "start §3's content gate has no rule for a run with no operator (#1040)"
pin "$SKILLS/start/SKILL.md" 'whose refusal and adopt route print instead when you judge the files product: a repo with any file at `HEAD` (a workspace-init pairing leaves the canonical with none) refuses (#1040);' \
  "start §3's no-operator rule does not refuse files at HEAD, or does not defer to the product-source refusal (#1040)"
pin "$SKILLS/start/SKILL.md" 'A bare scaffold (no file at `HEAD`) or a repo with no commit proceeds.' \
  "start §3's no-operator rule does not let a bare scaffold or a no-commit repo proceed (#1040)"
pin "$SKILLS/start/SKILL.md" 'beyond the scaffold and no operator confirmed they are not product - refusing' \
  "start §3's no-operator refusal does not print what it found and why (#1040)"
pin "$SKILLS/start/SKILL.md" 'or `/ossify:adopt` if it is the product (adopt owns product source; run headless it refuses a repo it does not judge product, and says to re-run with an operator).' \
  "start §3's no-operator refusal does not say what the operator does next (#1040)"
pin "$SKILLS/start/SKILL.md" '| Class H history (per repo: commit count, what is at `HEAD`) | `06-progress.md`, the spec-core-close entry |' \
  "start §13's output table does not name where class H history lands (#1040)"
pin "$SKILLS/start/references/memory-bank-brief.md" 'One dated entry: spec-core close, with class H history' \
  "memory-bank-brief's 06-progress row does not carry class H history (#1040)"
# ossify 1.37.0 (#1007, #1000): reviewer-home's crew-row rule, window, result-line placement and gh failure; impl-check's third route.
pin "$SKILLS/start/references/reviewer-home.md" 'whose `When` covers every PR; when the rows split by condition, name each row with its condition' \
  "reviewer-home §4 picks the reviewer row by first position, not by the row crew would pick (#1007)"
pin "$SKILLS/start/references/reviewer-home.md" 'in each declared repo (a `tooling_repo` skipped), 30 per repo' \
  "reviewer-home §5 leaves the multi-repo 30-PR window unstated (#1007)"
pin "$SKILLS/start/references/reviewer-home.md" 'when `gh` exited non-zero or is absent; when other sources still yield proposals, the counts line with its window replaced by `none (gh failed)`' \
  "reviewer-home §5 lets a failed gh read as no review history (#1007)"
pin "$SKILLS/start/references/reviewer-home.md" 'Record the result line after the other lines of the `## Review` section' \
  "reviewer-home §6 places the result line inconsistently with the proposals below it (#1007)"
pin "$SKILLS/close/references/impl-check.md" '### The pass — a fresh verifier, inline, or the caller'"'"'s under `--verdict`' \
  "impl-check's pass heading names two routes, not three (#1000)"
# ossify 1.37.0 round 1 (PR #1097): pins for sentences the first push left unpinned (C3), the multi-repo and gh-failed
# forms (C4), the README row (C5), adopt's headless class step (C6).
pin "$SKILLS/close/references/impl-check.md" "or by the caller's verifier under \`--verdict\` (\`work-item-close.md\` §2 owns which" \
  "impl-check's pass omits the caller's verifier under --verdict (#1000 C4)"
pin "$SKILLS/close/references/impl-check.md" 'carries no tag and needs no criterion fix: a corrected item' \
  "impl-check's recovery menu has no stale-verdict entry saying a corrected item needs a fresh verdict (#1000 C6)"
pin "$SKILLS/start/references/reviewer-home.md" 'as this run authors it at §13, three or four lines.' \
  "reviewer-home §4's line count does not match its optional CI line (#1007)"
pin "$SKILLS/start/references/reviewer-home.md" 'on the last 30 merged PRs by merge date,' \
  "reviewer-home §5's window does not say by merge date (#1007)"
pin "$SKILLS/start/references/reviewer-home.md" 'Each proposal is one line, `- <class>: <rule>. Why: <why>. PRs: #<n>, #<n>`' \
  "reviewer-home §5 gives proposals no one-line format (#1007)"
pin "$SKILLS/adopt/SKILL.md" 'exceed 500 lines (the cap `test-skill-bash-blocks.sh` enforces).' \
  "adopt's line cap is not the enforced 500 (#1042)"
pin "$SKILLS/start/references/reviewer-home.md" '(`<repo>#<n>` when more than one repo is declared)' \
  "reviewer-home §5's proposal line cannot name the repo of a multi-repo adoption (#1007)"
pin "$SKILLS/start/references/reviewer-home.md" 'With more than one declared repo, the window names each repo:' \
  "reviewer-home §5's result line cannot name each repo's window (#1007)"
pin "$SKILLS/start/references/reviewer-home.md" 'the counts line with its window replaced by `none (gh failed)`' \
  "reviewer-home §5's gh-failed counts line does not say which window it has (#1007)"
pin "$SKILLS/../README.md" 'with no operator to confirm, it refuses a repo with any file at `HEAD`.' \
  "ossify/README's /start row omits the no-operator refusal (#1040)"
pin "$SKILLS/adopt/references/plain-repo.md" 'saying `re-run with an operator`: `/start` would refuse it for the same reason' \
  "plain-repo's class step can route a headless docs-only repo to /start, which refuses it (#1040)"
pin "$SKILLS/adopt/SKILL.md" 'with no operator to answer, `plain-repo.md` §1 says when it refuses instead.' \
  "adopt's scope line sends every no-product repo to /start, headless too (#1040)"
pin "$SKILLS/adopt/references/plain-repo.md" 'With no operator to answer, refuse a repo with any file at `HEAD` that you do not judge product' \
  "plain-repo's class step does not refuse a headless repo with any file at HEAD that is not product (#1040)"
pin "$SKILLS/start/references/reviewer-home.md" '`window <repo> <first PR>–<last PR>, <repo> <first PR>–<last PR>`' \
  "reviewer-home §5's multi-repo window format is not stated per repo (#1007)"
pin "$SKILLS/start/SKILL.md" 'where `06-progress.md` is an occupied destination the operator kept, that history goes in the §13 hand-off message to the operator, as a refusal'"'"'s does.' \
  "start §13 leaves class H history nowhere when the operator keeps 06-progress.md (#1040)"
if grep -Fq 'source or its own history' "$SKILLS/start/SKILL.md"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: start §3's gate still refuses on history alone (#809)"
else
  T_PASS=$((T_PASS+1))
fi

# ---------------------------------------------------------------------------
# Adoption's horizon reaches Release 1 (#302). It is not in state; plan-release
# reads it from ADOPTION.md by pointer (skill-first: a reader of prose stays prose).
_FMG="$SKILLS/plan-release/references/feature-map-grooming.md"
pin "$_FMG" '## 8. Release 1 after an adoption (#302)' \
  "feature-map-grooming.md carries the Release-1-after-adoption section"
pin "$_FMG" 'Groom the `next` entries as this release'"'"'s candidates' \
  "feature-map-grooming.md §8 grooms next and later apart (#302)"
pin "$SKILLS/plan-release/SKILL.md" '`ADOPTION.md` first (its §8, #302)' \
  "plan-release §5a points Release 1 at ADOPTION.md"
pin "$_FMG" '`"$(oss repo_root ai_workspace)/ADOPTION.md"`' \
  "feature-map-grooming.md §8 resolves ADOPTION.md at the AI-workspace root (#302)"

# ---------------------------------------------------------------------------
# Adoption's seed candidates reach the ledger (#293). plan-spine owns demo lines,
# so Release 1's spines mint them: once (a re-plan finds them by command), active,
# and outside the spine's own floors, like the community-edition line.
_DA="$SKILLS/plan-spine/references/demo-authoring.md"
pin "$_DA" "### Adoption's seed lines — Release 1 mints them once, outside F1 (#293)" \
  "demo-authoring.md §1 carries the adoption seed-line section (#293)"
pin "$_DA" 'is already the `text` of a ledger line — on any spine, in any status — is done' \
  "demo-authoring.md: a seed candidate already in the ledger by text is never minted again (#293)"
pin "$_DA" 'A seed line never counts toward this spine'"'"'s F1, F3 or F6' \
  "demo-authoring.md: seed lines are excluded from the minting spine's floors (#293)"
pin "$_DA" 'records it under its `SPINE.md` demo contribution as unmintable, with the reason' \
  "demo-authoring.md: an unmintable seed candidate goes to SPINE.md, not RELEASE.md (#293)"
pin "$_DA" '"[adoption-seed] <the candidate, verbatim>"' \
  "demo-authoring.md: seed lines carry the [adoption-seed] text prefix (#293)"
pin "$_DA" 'F1 counts neither `[community-edition]` nor `[adoption-seed]` lines' \
  "demo-authoring.md §2: the read-out's F1 count excludes standing lines (#293)"
pin "$SKILLS/plan-spine/SKILL.md" 'mints adoption'"'"'s C6 seed candidates once (`references/demo-authoring.md` §1, #293)' \
  "plan-spine §8a points Release 1 at the seed-line section (#293)"
pin "$SKILLS/adopt/SKILL.md" 'Release 1'"'"'s spines mint them (`plan-spine/references/demo-authoring.md` §1, #293)' \
  "adopt C6 names the ceremony that mints its candidates (#293)"
_c="$(grep -c 'no ceremony' "$SKILLS/adopt/SKILL.md" || true)"
_pin "$([ "$_c" = 0 ] && echo 0 || echo 1)" "adopt C6 still says no ceremony consumes the seed candidates (#293)"

# ---------------------------------------------------------------------------
# A skipped clean-checkout pass must not read as "no C2 gaps" (#367). The C2
# station says what it records; the §6 floor tokens above pin the row and the
# refusal.
pin "$SKILLS/adopt/SKILL.md" 'Record what the pass did as the adoption record'"'"'s C2 result line (§6, #367)' \
  "adopt C2 points the station at its result line (#367)"

# #631 (1.23.0): the feature entry carries its intake issue, so spine planning
# reads the request from the entry; a release-level pull-in records the issue.
pin "$SKILLS/plan-spine/references/intake-and-ledger.md" '`oss feature_add "<name>" "<value>" "<bone|flesh>" intake <issue-number>`' \
  "a release-level pull-in records the request's issue on the feature entry (#631)"
pin "$SKILLS/plan-spine/references/intake-and-ledger.md" 'never by matching titles' \
  "spine planning reads the request from the feature entry's issue (#631)"
# Codex round 1 on PR #821: a later spine that takes the same feature posts its
# own pulled in, so the request's comments name every carrier planned so far.
pin "$SKILLS/plan-spine/references/intake-and-ledger.md" 'or to an earlier spine' \
  "a later spine that takes the same feature posts its own pulled in (#631)"
# Operator ruling at PR #821's round-5 review stop: spine close never closes an
# intake request. No spine knows when a request is done - a feature can span
# spines not yet planned, and a spine can land without the item that carried it -
# so spine close comments that it landed and the operator closes the request.
pin "$SKILLS/close/references/spine-close.md" 'Spine close never closes an intake request' \
  "spine close never closes an intake request; the operator does (#631)"
pin "$SKILLS/plan-spine/references/intake-and-ledger.md" 'The operator closes a request' \
  "intake §1 says the operator closes a request (#631)"
for _f in "$SKILLS/close/references/spine-close.md" "$SKILLS/plan-spine/references/intake-and-ledger.md" "$SKILLS/plan-spine/references/decomposition.md" "$HERE/../README.md" "$HERE/../CHANGELOG.md" "$HERE/../../README.md"; do
  _r=1; ! grep -Fq 'gh issue close <n>' "$_f" && ! grep -Fq 'withdrawn — <' "$_f" && ! grep -Fq '/permission' "$_f" && ! grep -Fq 'last carrying spine' "$_f" && ! grep -Fq 'closes an intake request only' "$_f" && _r=0
  _pin "$_r" "$(basename "$_f") still says spine close closes an intake request, or names withdrawn or a permission check (#631)"
done
# ...and the advertised '#N' form is quoted: an unquoted # starts a shell comment.
# The 1.23.0 note that advertises it moved to ossify's CHANGELOG.md (README rewrite, 2026-11).
# Neither README carries release notes any more: both are held to the absence half only.
for _f in "$HERE/../CHANGELOG.md"; do
  _r=1; grep -Fq "'#N'" "$_f" && ! grep -Fq '`N` or `#N`' "$_f" && _r=0
  _pin "$_r" "$_f advertises an unquoted #N - the shell drops it as a comment and feature_add records no issue (#631)"
done
for _f in "$HERE/../README.md" "$HERE/../../README.md"; do
  _r=1; ! grep -Fq '`N` or `#N`' "$_f" && _r=0
  _pin "$_r" "$_f advertises an unquoted #N (#631)"
done
# CodeRabbit round 6 on PR #821: a split's halves landing is not the close
# condition - another spine may carry the feature too.
pin "$SKILLS/plan-spine/references/decomposition.md" 'and any other spine that carries the feature' \
  "a whole-spine split's close guidance counts every carrier, not only the halves (#631)"
_r=1; ! grep -Fq 'accepted and silently dropped' "$SKILLS/plan-spine/references/codebase-design.md" && grep -Fq 'only for an intake request' "$SKILLS/plan-spine/references/codebase-design.md" && _r=0
_pin "$_r" "codebase-design.md still says a fifth feature_add argument is dropped - a planner's split trigger is now refused at rc 2 (#631)"

# 1.24.0 (#768, #554) - AGENTS.md is the one instruction file. One pin per
# station; behaviour is judged by the start-occupied-destination and
# doctor-instruction-file eval surfaces.
_MB="$_OSSR/skills/start/references/memory-bank-brief.md"
_OD5="$_OSSR/skills/start/references/occupied-destinations.md"
_IC="$_OSSR/skills/doctor/references/interop-check.md"
_DS="$_OSSR/skills/doctor/SKILL.md"
_AS="$_OSSR/skills/adopt/SKILL.md"
_MARK='<!-- workspace-init stub: ossify:start replaces this file -->'
_r=1; grep -Fq '## 3. `AGENTS.md`' "$_MB" && ! grep -Fq '## 3. `CLAUDE.md`' "$_MB" && grep -Fq '| Memory bank (15 files) + `AGENTS.md` + `CODING_STANDARDS.md` | AI workspace, per `references/reviewer-home.md` |' "$_SS" && _r=0
_pin "$_r" "start authors CLAUDE.md - a new workspace gets the file Codex and OMP never read"
# 1.31.0 (#984) - the reviewer project home: start seeds a standards stub, a review ledger and a
# governance Review section, all in the AI workspace. Behaviour is judged by start-reviewer-home.
_RH="$_OSSR/skills/start/references/reviewer-home.md"
pin "$_SS" '| Memory bank (15 files) + `AGENTS.md` + `CODING_STANDARDS.md` | AI workspace, per `references/reviewer-home.md` |' "start §13 routes the reviewer home"
pin "$_RH" 'Nothing here lands in a declared repo.' "reviewer home never writes a declared repo"
pin "$_MB" '| `review-ledger.md` |' "memory-bank brief lists the review ledger"
pin "$_OD5" '`CODING_STANDARDS.md`' "occupied check covers the standards stub"
pin "$_AS" 'then its `reviewer-home.md` §5 history pass' "adopt routes to the history pass"
pin "$_RH" 'A finding becomes a proposal only when it recurs in two or more PRs.' "recurrence floor"
pin "$_RH" 'Only accepted entries are written.' "operator accepts each entry"
_r=1; grep -Fq "$_MARK" "$_OD5" && grep -Fq 'first line' "$_OD5" && grep -Fq 'counts as unoccupied' "$_OD5" && _r=0
_pin "$_r" "occupied-destinations has no workspace-init stub exception - /start leaves the marked stub in place, so it never becomes ossify's AGENTS.md (#554)"
_r=1; grep -Fq 'leftover `CLAUDE.md`' "$_OD5" && grep -Fq 'ossify:doctor' "$_OD5" && _r=0
_pin "$_r" "occupied-destinations is silent on a leftover CLAUDE.md - Claude Code keeps loading it over the AGENTS.md /start just wrote"
_r=1; grep -Fq '### `claude_md`' "$_IC" && grep -Fq 'fail: claude_md' "$_IC" && grep -Fq '.claude/CLAUDE.md' "$_IC" && _r=0
_pin "$_r" "interop-check has no claude_md check - a leftover CLAUDE.md silently shadows AGENTS.md"
_r=1; grep -Fq "## 5. The repair — only on the operator's explicit yes" "$_IC" && grep -Fq 'Never commit' "$_IC" && ! grep -Fq 'Do not write or edit `AGENTS.md` yourself' "$_IC" && _r=0
_pin "$_r" "interop-check still forbids the repair, or runs it without the operator's yes, or commits it"
# The gate comes before the write, not only before the commit: workspace-init
# 0.10.0 promises the operator sees the result first.
_r=1; grep -Fq 'every change first' "$_IC" && grep -Fq 'Show the operator the whole merged file' "$_IC" && _r=0
_pin "$_r" "interop-check's repair writes before the operator has seen it - workspace-init 0.10.0 promises the result is shown first"
# doctor writes twice, each on the operator's word: §6's asked-for rule and §7's
# yes-gated repair. The older "exactly one thing writes" claim is false.
_r=1; ! grep -Fq 'Exactly one thing writes' "$_DS" && _r=0
_pin "$_r" "doctor/SKILL.md claims 'Exactly one thing writes' again - §7's repair is a second write, so the count is wrong"
_r=1; grep -Fq '`claude_md`' "$_DS" && ! grep -Fq 'do not edit `AGENTS.md` yourself' "$_DS" && _r=0
_pin "$_r" "doctor/SKILL.md §7 does not name the claude_md check or still forbids the repair its reference ships"
_r=1; grep -Fq '| `AGENTS.md` | merge ossify' "$_AS" && ! grep -Fq '| `CLAUDE.md` | merge' "$_AS" && _r=0
_pin "$_r" "adopt merges its loop section into CLAUDE.md - an adopted workspace's AGENTS.md never names ossify"
_r=1; grep -Fq 'author it when absent' "$_AS" && grep -Fq '`AGENTS.md` when present, else author' "$_AS" && _r=0
_pin "$_r" "adopt's AGENTS.md row is merge-only - a legacy workspace with no AGENTS.md leaves C5's line-234 precondition ('each file you create does not exist yet') nothing to merge into, so adopt refuses it (D31)"

# PR #836 round 1 (D1-D9). The repair is one design; one pin per finding, each
# statement pinned where the finding said the text was wrong.
_PRA="$_OSSR/skills/doctor/references/rule-authoring.md"
# D1: the check's scope is the AI workspace, and nothing about it reaches a
# declared repo - read alone, an unscoped line fails every canonical that keeps
# its own CLAUDE.md and offers to move canonical instructions into the workspace.
_r=1; grep -Fq 'Scope: the AI workspace, and only the AI workspace' "$_IC" \
  && grep -Fq 'Never look inside a declared repo' "$_IC" \
  && grep -Fq 'that workspace' "$_DS" && grep -Fq 'never a declared repo' "$_DS" && _r=0
_pin "$_r" "claude_md's scope is unstated or reaches a declared repo - a canonical's own CLAUDE.md reads as a failure of the AI workspace (D1)"
# D2: the offer must not wait for an otherwise-clean read-out; the no-AGENTS.md
# shape branch 1 exists for is exactly the one the old gate excluded.
_r=1; ! grep -Fq 'the only problem is a leftover' "$_IC" \
  && grep -Fq 'whatever else the' "$_IC" && grep -Fq 'whatever else the' "$_DS" && _r=0
_pin "$_r" "the repair is offered only when CLAUDE.md is the sole problem - the no-AGENTS.md shape branch 1 exists for is gated off (D2)"
# D3: a disagreement is a hold. No write, and above all no re-emit - the old
# text re-read on an unanswered question and printed ok: over a file still there.
_r=1; grep -Fq 'and hold' "$_IC" && grep -Fq 're-emit nothing' "$_IC" \
  && grep -Fq 'Resume only' "$_IC" && _r=0
_pin "$_r" "§5 has no hold - an unanswered disagreement re-emits ok: with the CLAUDE.md still present and nothing written (D3)"
# D5: git mv is chosen by whether the SOURCE IS TRACKED, not by whether the
# workspace is a git repo - the untracked .claude/CLAUDE.md shape fails on rc.
# Round 2 (E1): the anchor moved from "only when the source is" to "Choose the
# command **first**, by the tracking test" - the same claim, and the phrase E1's
# no-fallback rule is built on. The grep below keeps the claim pinned.
_r=1; grep -Fq 'ls-files --error-unmatch' "$_IC" && grep -Fq 'Choose the' "$_IC" \
  && grep -Fq 'by the tracking test' "$_IC" \
  && ! grep -Fq 'plain `mv` if the workspace is not a git repo' "$_IC" && _r=0
_pin "$_r" "git mv is chosen by git-repo-ness - an untracked .claude/CLAUDE.md in a git workspace fails 'not under version control' (D5)"
# D6: both files is ONE plan with a fixed order, so two runs agree; the old text
# ran a move per file and the second collided on AGENTS.md.
_r=1; grep -Fq 'that is one plan, not' "$_IC" && grep -Fq 'The root `CLAUDE.md` moves' "$_IC" \
  && grep -Fq 'merges** into that `AGENTS.md`' "$_IC" \
  && grep -Fq 'one line per path' "$_IC" && _r=0
_pin "$_r" "root and .claude/CLAUDE.md are two independent moves - the second git mv fails or a plain mv overwrites AGENTS.md (D6)"
# D8: the offer lands after the sweep's read-out; §3 forbids a mid-sweep prompt.
_r=1; grep -Fq "after the sweep's read-out, never mid-sweep" "$_IC" \
  && grep -Fq 'never mid-sweep' "$_DS" && _r=0
_pin "$_r" "the repair offer has no sweep timing - §3 forbids a mid-sweep prompt and the offer has no stated place (D8)"
# D7: the falsified write-count and never-do text the repair makes untrue.
_r=1; ! grep -Fq 'Editing `AGENTS.md` or the pairing manifest' "$_DS" \
  && ! grep -Fq 'The one surface in this skill that' "$_PRA" && _r=0
_pin "$_r" "doctor's never-do list still forbids editing AGENTS.md to make the interop check pass, or rule-authoring still calls itself the one writing surface (D7)"
# D9: replacing the marked stub must carry the stub's git policy and trace filter.
# The greps read the CARRY INSTRUCTION, not the section heading: a heading word
# `verbatim` satisfied an earlier form of this pin while the instruction itself
# could be deleted (the mutation survived - PR #836 round-2 fix).
_r=1; grep -Fq '## Git policy' "$_OD5" && grep -Fq '## AI-trace filter' "$_OD5" \
  && grep -Fq 'copy both sections from it into' "$_OD5" && _r=0
_pin "$_r" "/start's stub replacement drops the stub's Git policy and AI-trace filter sections - later agents lose the network-ops default-deny (D9)"

# PR #836 round 2 (E1, E2). Both are defects in the repair's own move path.
# E1: no fallback - the tracking test chooses the command and only that command
# runs; an `|| mv` after a failed `git mv` can overwrite an AGENTS.md that
# appeared after the plan was shown, and a bare `git mv` targets $PWD's repo.
# The `git mv` half is a NEGATIVE grep: the correct text has no bare
# `git mv "<path>"` anywhere (every git call carries -C), so this catches both
# the prose bullet and the executable block. A positive grep for the -C form
# alone did not: mutating only the block's line survived it (round-2 fix).
_r=1; grep -Fq 'Run only the command you chose' "$_IC" \
  && grep -Fq 'Do not try the' "$_IC" \
  && ! grep -Fq 'git mv "<path>"' "$_IC" \
  && ! grep -Fq '|| mv "<path>"' "$_IC" \
  && grep -Fq 'git -C "<ai_workspace.root>" ls-files --error-unmatch' "$_IC" && _r=0
_pin "$_r" "the move falls back to plain mv after a failed git mv, or runs a bare git mv without -C - the fallback overwrites an AGENTS.md that appeared, and the bare form targets the wrong repo (E1)"
# E2: the inputs are re-read after the yes, before any write - a plan approved
# against different bytes is not an approval.
# The ordering is the point: a re-read AFTER the write is no gate at all, and
# greping only the heading and the rebuild clause survived exactly that mutation
# (round-2 fix). `Before any write` is what pins the order.
_r=1; grep -Fq 'Re-read the inputs after the yes' "$_IC" \
  && grep -Fq 'Before any write' "$_IC" \
  && grep -Fq 'rebuild the plan and show it again for a new yes' "$_IC" && _r=0
_pin "$_r" "the repair writes on a plan whose inputs changed between the yes and the write - a CLAUDE.md edited, or an AGENTS.md appeared, is never noticed (E2)"

# 1.25.0 (autopilot slice 1, Tasks 3+4; #831 #832) - the merge and the demo walk
# under a standing order in the project's memory bank or AGENTS.md. The first three pins and T4-1
# are red on 1.24.0's text and green after the edits; T4-2 is the loosening's
# adjacent control (CLAUDE.md): §3's human walk stays the otherwise branch, and
# the sentence it lives in is pinned so it cannot be deleted.
_PRW_LOOP="$HERE/../skills/work-pr/references/loop.md"
_PRW_WP="$HERE/../skills/work-pr/SKILL.md"
_PRW_SC="$HERE/../skills/close/references/spine-close.md"
_PRW_CD="$HERE/../skills/close/references/cumulative-demo.md"
pin "$_PRW_LOOP" 'Then **ask**: merge, wait, or leave open — or, under a standing order in the project'"'"'s memory bank or `AGENTS.md` that binds this role and grants merge authority, treat a clean verdict as the ack and say which order gave it.' \
  "loop.md's terminus does not take a standing order's clean verdict as the merge ack (#831)"
pin "$_PRW_SC" "this ceremony does not ack on anyone's behalf; a standing order in the project's memory bank or \`AGENTS.md\` that binds this role and grants merge authority is the operator's ack, given in advance" \
  "spine-close.md does not say a standing order is the operator's ack given in advance (#831)"
pin "$_PRW_WP" "the merge is the operator's, or a standing order's in the project's memory bank or \`AGENTS.md\`" \
  "work-pr/SKILL.md's 'whichever loop runs' sentence does not carry the standing-order merge (#831)"
pin "$_PRW_CD" 'Under a standing order that gives you the demo walk, walk each line yourself' \
  "cumulative-demo.md does not hand the user: walk to the orchestrator under the Demo walk order (#832)"
pin "$_PRW_CD" 'You may not perform a `user:` line on the human'"'"'s behalf and mark it passed.' \
  "cumulative-demo.md's otherwise branch - the human's walk - is gone, so the walk reads as the orchestrator's always (#832)"

# 1.27.0 - the order's home is the project's files, and it binds only the role it names.
pin "$_PRW_CD" '(`08-governance.md`, `## Standing orders`)' \
  "cumulative-demo.md does not name the memory bank's Standing orders section as the order's home (1.27.0)"
pin "$_PRW_CD" 'for any kind of order that section does not' \
  "cumulative-demo.md does not fall back to AGENTS.md for kinds the section does not settle (1.27.0)"
pin "$_PRW_CD" '(`.workspace/pairing.json`)' \
  "cumulative-demo.md does not send a canonical checkout to the paired AI workspace's files (1.27.0)"
pin "$_PRW_CD" 'An order binds only the role it names (one naming no role' \
  "cumulative-demo.md lost the role rule - an order naming no role must bind no one (1.27.0)"
pin "$_PRW_CD" 'with none, the walk is the human' \
  "cumulative-demo.md lost the no-order branch - the human walks (1.27.0)"
_MBB="$HERE/../skills/start/references/memory-bank-brief.md"
pin "$_MBB" 'ships with an empty `## Standing orders`' \
  "memory-bank-brief.md does not seed 08-governance.md with an empty Standing orders section (1.27.0)"

# 1.27.1 (#963) - under merge-bar 0.6.0's working-a-pr a one-way door is never merged on
# the ack; it goes to the merge holder. Red on 1.27.0's text. The bundled loop's ack
# sentence (the loop.md pin above) is the control: it must not change.
pin "$_PRW_WP" '(under `working-a-pr`, a two-way door'"'"'s only: a one-way door, or a body with no `Door:` line, goes to the merge holder' \
  "work-pr/SKILL.md's 'whichever loop runs' sentence promises an ack merge working-a-pr refuses a one-way door (#963)"
pin "$_PRW_SC" 'one-way door, or a body with no `Door:` line, goes to the merge holder with `merge-bar/skills/working-a-pr/references/one-way-door.md`.' \
  "spine-close.md's merge paragraph does not hand a one-way door to the merge holder (#963)"
pin "$_PRW_SC" "(a one-way door is the merge holder's), then re-invoke close" \
  "spine-close.md's open-PR halt still prints a remedy working-a-pr refuses a one-way door (#963)"
pin "$HERE/../skills/patch/SKILL.md" 'Where `working-a-pr` runs, a patch is a one-way door (§6 tags it), so it goes to the merge holder' \
  "patch/SKILL.md does not send its one-way PR to the merge holder (#963)"

# PR #869 round 1 (disposition items 1-3, one class): the two sites the first pass
# left operator-only, conditioned in one commit. The first two pins are red on
# dceda637's text and green after the fix; the third is the loosening's adjacent
# control (CLAUDE.md): the rail gains a merge branch, so the prohibition the
# disposition says to keep - "Never auto-merge" - is pinned against deletion.
pin "$_PRW_SC" "the human, or yourself under a standing order in the project's memory bank or \`AGENTS.md\` that gives" \
  "spine-close.md's step-4 reference still gives the demo walk to the human alone (#869 disposition 1)"
pin "$_PRW_WP" "the ask — or, under a standing order in the project's memory bank or \`AGENTS.md\` that" \
  "work-pr/SKILL.md's merge rail still stops at the ask with no standing-order branch (#869 disposition 2)"
pin "$_PRW_WP" "binds this role and grants merge authority (lookup:" \
  "work-pr/SKILL.md's merge rail dropped 'binds this role and grants merge authority' - an order binds only the role it names (1.27.0)"
pin "$_PRW_LOOP" "that binds this role names" \
  "loop.md's fallback-reviewer order lost its role cue (1.27.0)"
pin "$_PRW_WP" "Never auto-merge." \
  "work-pr/SKILL.md's merge rail lost 'Never auto-merge' - a merge queue's auto-merge stays forbidden (#869 disposition 2)"

# merge-bar 0.10.1 / ossify 1.36.5 (#1061 C8, C9) - the fallback loop's second exit offers the
# design change at every stop and recommends it on one mechanism over open input (1.36.8 caps it at one redesign; merge-bar's stop has no cap).
pin "$_PRW_LOOP" 'recommended when every fix extends one' \
  "loop.md's second exit does not recommend the design change when every fix extends one mechanism (#1061 C9)"
# ossify 1.36.8 (#1071 C4, orchestrator ruling: keep the cap): the offer is "at every such stop
# until the change has been redesigned once", so it agrees with "do not restructure twice", and
# the staleness sentence lists changing the design among the ways out of the second exit.
pin "$_PRW_LOOP" 'offered at every such stop until the change has' \
  "loop.md's second exit offers the design change at every stop with no end, against its own 'do not restructure twice' (#1071 C4)"
# ossify 1.37.0 (#1091, CodeRabbit): the offer's end is pinned too (the line wrap puts it on the next line).
pin "$_PRW_LOOP" 'been redesigned once, recommended when every fix' \
  "loop.md's second exit lost the end of the design-change offer ('redesigned once') (#1091)"
# ossify 1.36.8 (#1091 r1 C1): the fields-check prose names the or-forms the Door check halts on,
# and the two "could not run" halts, so it agrees with the block below it.
pin "$_SC" 'a line naming both doors joined by `or`, `,`, `/` or `|`, and `two-wayfoo`,' \
  "spine-close.md's fields-check prose still defines a filled Door line by the pre-1.36.8 check (#1091 r1 C1)"
pin "$_SC" 'heading-order check whose awk cannot run halts too, saying so.' \
  "spine-close.md's fields-check prose omits the could-not-run halts (#1091 r1 C2)"
pin "$_PRW_LOOP" 'input; do not restructure twice, and say so.' \
  "loop.md's second exit drops its cap on a second restructure (#1071 C4)"
pin "$_PRW_LOOP" 'cutting, narrowing, changing the design, or' \
  "loop.md's staleness sentence omits changing the design from the second exit's ways out (#1071 C4)"

# --- /close <wi-id> --pr: the work item's PR instead of a local merge --------------
# Control first: the default path (section 4's local merge) is byte-for-byte what it
# was. The new arm may not edit it, and the pin counts the line exactly once, so a
# copy of it into section 4a would turn this red too.
_WCP="$HERE/../skills/close/references/work-item-close.md"
_CLP="$HERE/../skills/close/SKILL.md"
_CMD="$HERE/../commands/close.md"
pin "$_WCP" 'git -C "$repo_root" merge --no-ff "$wi_branch" -m "merge $wi" || { echo "close: merge conflict - halt"; exit 1; }' \
  "control: close section 4's local merge line is unchanged (default /close <id> behaves as before)"
pin "$_CLP" 'Both apply to a work-item close only' "close grammar: --pr on a spine or release id refuses"
pin "$_CLP" '`/close <wi-id> --pr`' "close grammar: the work-item --pr shape is named"
pin "$_WCP" '## 4a. PR mode' "work-item-close.md has section 4a"
pin "$_WCP" 'never a local merge' "4a: a missing remote leg halts, never a local merge (the #339 rule)"
pin "$_WCP" 'ls-remote --exit-code origin' "4a: the spine branch is probed on the remote before the commit"
# PR #889 round 1 B1: nothing in the lane pushes the spine branch, so 4a pushes it
# when ls-remote reports it absent (rc 2), before the item commit; any other rc
# halts. Ordering: the spine push precedes the commit line.
pin "$_WCP" 'if [ "$spine_rc" -eq 2 ]; then' "4a B1: an absent spine branch (ls-remote rc 2) takes the push arm"
pin "$_WCP" 'git -C "$repo_root" push -u origin "$spine_branch"' "4a B1: PR mode pushes the spine branch when origin lacks it"
pin "$_WCP" 'elif [ "$spine_rc" -ne 0 ]; then' "4a B1: an unreadable remote (rc other than 0/2) still halts"
_r=1; _p="$(grep -nF 'git -C "$repo_root" push -u origin "$spine_branch"' "$_WCP" | cut -d: -f1)"; _m="$(grep -nF 'close: commit failed in $wt - nothing was pushed' "$_WCP" | cut -d: -f1)"
[ -n "$_p" ] && [ -n "$_m" ] && [ "$_p" -lt "$_m" ] && _r=0
_pin "$_r" "4a B1: the spine-branch push does not run before the item commit"
pin "$_RO" 'pushes the branch when origin lacks it, as its PR'"'"'s' "RO 2a B1: the PR-mode close's spine-branch push is named as the one sanctioned early push"
pin "$_WCP" 'close: commit failed in $wt - nothing was pushed - halt' "4a: a failed commit halts before the push"
pin "$_WCP" 'is not past base $base_sha - no commit to open a PR for; nothing was pushed - halt' "4a: HEAD must be past the recorded base before the push"
pin "$_WCP" 'oss work_item_pr "$wi" "$pr_url"' "4a: the PR URL is recorded through the verb"
pin "$_WCP" 'Do **not** set `complete`' "4a: the status stays active, the merge and status are the caller's"
pin "$_WCP" 'never squash or rebase' "4a: the caller merges with a merge commit"
# Final review I1: gh takes the origin URL itself as --repo; no sed strips the
# host (an origin on a non-default host then resolved on gh's default). The
# zero-count absence check carries its positive control beside it: both gh
# calls name "$origin_url", so a deleted or renamed variable cannot leave the
# absence vacuously green.
_r=1; ! grep -Fq 'gh_repo=' "$_WCP" && ! grep -Fq "sed -E 's#^(git@" "$_WCP" && _r=0
_pin "$_r" "4a: the origin URL is taken apart with sed to build gh's --repo (the host is lost - final review I1)"
pin "$_WCP" 'pr_url="$(gh --repo "$origin_url" pr list --head "$wi_branch" --base "$spine_branch" --state open --json url' \
  "4a control: the PR lookup passes the origin URL itself as --repo"
pin "$_WCP" 'pr_url="$(gh --repo "$origin_url" pr create --base "$spine_branch" --head "$wi_branch"' \
  "4a control: the PR create passes the origin URL itself as --repo"
# Final review I2 / R6(a): section 4a resumes in place - an empty index with the
# recorded branch past base skips the commit; an open PR for the branch is
# reused, never re-created; the lookup runs before the create.
pin "$_WCP" 'elif [ "$(git -C "$wt" rev-list --count "$base_sha..HEAD")" -ge 1 ]; then' \
  "4a: an empty index with HEAD past base on the recorded branch is a resume, not a halt"
# PR #889 round 1 class A: the recorded-branch guard runs before BOTH arms (a
# worktree switched off $wi_branch committed there, then pushed $wi_branch
# without the commit), and the recorded base must be an ancestor of HEAD before
# the push. Ordering: the guard precedes the commit line.
pin "$_WCP" "[ \"\$wt_branch\" = \"\$wi_branch\" ] \\" "4a A: the recorded-branch guard is a standalone check"
pin "$_WCP" "not the recorded '\$wi_branch' - nothing was committed or pushed - halt" "4a A: a worktree off the recorded branch halts before the commit"
_r=1; _g="$(grep -nF "not the recorded '\$wi_branch' - nothing was committed" "$_WCP" | cut -d: -f1)"; _m="$(grep -nF 'close: commit failed in $wt - nothing was pushed' "$_WCP" | cut -d: -f1)"
[ -n "$_g" ] && [ -n "$_m" ] && [ "$_g" -lt "$_m" ] && _r=0
_pin "$_r" "4a A: the recorded-branch guard does not run before the commit arm"
pin "$_WCP" 'git -C "$wt" merge-base --is-ancestor "$base_sha" HEAD \' "4a A: the recorded base must be an ancestor of HEAD before the push"
_r=1; _a="$(grep -nF 'git -C "$wt" merge-base --is-ancestor "$base_sha" HEAD' "$_WCP" | cut -d: -f1)"; _u="$(grep -nF 'git -C "$wt" push -u origin "$wi_branch"' "$_WCP" | cut -d: -f1)"
[ -n "$_a" ] && [ -n "$_u" ] && [ "$_a" -lt "$_u" ] && _r=0
_pin "$_r" "4a A: the base-ancestry check does not run before the item push"
pin "$_WCP" 'resuming after the commit' "4a: the resume says it skipped the commit"
pin "$_WCP" "reusing it, not opening another" "4a: an open PR for the branch is reused"
_r=1; _l="$(grep -nF 'pr list --head "$wi_branch"' "$_WCP" | cut -d: -f1)"; _c="$(grep -nF 'pr create --base "$spine_branch" --head "$wi_branch"' "$_WCP" | cut -d: -f1)"
[ -n "$_l" ] && [ -n "$_c" ] && [ "$_l" -lt "$_c" ] && _r=0
_pin "$_r" "4a: the existing-PR lookup does not run before gh pr create"
pin "$_WCP" 'must not be re-entered over a half-done PR-mode close' "4a: a self-closing lane over a half-done PR-mode close is out of contract"
# R6(b)(c): under --detach the lane never runs the finish-merge local merge; the
# steps it runs are named, not "section 2 through 4".
pin "$_EX" '**`finish-merge` is never repaired under `--detach`.**' "EXT 2b: finish-merge is never repaired under --detach"
pin "$_EX" "| \`finish-merge\` | not repaired, nothing merged, no request; reported as awaiting the caller's close" \
  "EXT 2b: the re-entry row table has the finish-merge row"
_r=1; ! grep -Fq 'runs §2 through §4 unchanged' "$_EX" && grep -Fq 'The lane runs `round-orchestration.md` §2 (the fresh cut' "$_EX" && _r=0
_pin "$_r" "EXT 2b: still says 'runs §2 through §4 unchanged' instead of naming the round-orchestration steps"
# PR #889 round 1 N2: round-orchestration section 3's external-mode request for a
# close-finished item yields to section 2b under --detach (no request; the caller closes).
pin "$_RO" '`--detach`, where it gets no request and the caller closes it (§2b)' "RO 3 N2: close-finished under --detach gets no request, matching EXT 2b"
_ah="$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 && /^argument-hint: / {sub(/^argument-hint: /,""); print; exit}' "$_CMD")"
t_assert_eq '"<id> [--pr] [--verdict <file>]"' "$_ah" "close.md argument-hint declares the optional flag"

# #978: Claude Code refuses a subagent's Write of a `report*.md` file, so the
# dispatched implementer returns its report as `report_text` and the lane writes
# it to report_path before close. One optional key; report.md keeps its name.
_978_RO="$WI/references/round-orchestration.md"
pin "$WI/SKILL.md" 'retry it by another tool or name: return the report in `report_text` (§9)' \
  "#978 SKILL.md §7: a refused report write goes to report_text, never another tool"
pin "$WI/SKILL.md" 'Add `"report_text": "<the whole report>"` to `complete`' \
  "#978 SKILL.md §9: report_text is the one optional complete key"
pin "$WI/references/returns.md" '| `report_text` | **Optional.** The whole report as a JSON string, present only when the harness refused your report write' \
  "#978 returns.md §2: report_text row is optional and conditional"
pin "$HERE/../agents/implementer-agent.md" '**As a Claude Code subagent, do not Write `report.md`:**' \
  "#978 implementer-agent.md: the Claude Code subagent returns report_text instead of writing"
pin "$_978_RO" 'return carries `report_text`, write it with Write to `report_path` verbatim' \
  "#978 RO §6: the lane writes report_text verbatim to report_path"
pin "$_978_RO" 'any other `report_path` is a halt naming it' \
  "#978 RO §6: report_text is written only beside the item's handoff"
pin "$_978_RO" '`halt: <wi-id> returned complete with no report at <report_path> and no report_text`' \
  "#978 RO §6: no file and no report_text is a named halt"
_r=1; _w="$(grep -nF 'write it with Write to `report_path` verbatim' "$_978_RO" | cut -d: -f1)"; _h="$(grep -nF 'Then hand the item to the work-item' "$_978_RO" | cut -d: -f1)"
[ -n "$_w" ] && [ -n "$_h" ] && [ "$_w" -lt "$_h" ] && _r=0
_pin "$_r" "#978 RO §6: the report is not written before the item goes to close"
pin "$WI/references/external-executor.md" '`mode`, `report_path`, `summary`, `stage_status` — never `report_text`' \
  "#978 EXT §5a: an external result carries no report_text"
pin "$HERE/../skills/close/references/work-item-close.md" "The report's *content* reaches close only as a file" \
  "#978 close Route A: the report reaches close as a file"
# Adjacent control for the loosening: the complete TEMPLATE stays four keys, so
# handoffs and the external record's parity are unchanged.
_r=1; _t="$(_shape "$WI/references/returns.md" complete)"; [ -n "$_t" ] && case "$_t" in *report_text*) ;; *) _r=0;; esac
_pin "$_r" "#978 returns.md: the complete template gained report_text (it must stay four keys)"
_r=1; ! grep -Fq 'deliberately not in the return payload' "$HERE/../skills/close/references/work-item-close.md" && _r=0
_pin "$_r" "#978 close Route A: still says the report content is never in the return payload"
# #978 round 1 C1: a staged item with no report (a lost return, or either §6
# halt) has a named recovery that routes it close-finished, and every halt or
# repair row that can reach it points there instead of at a re-dispatch.
pin "$_978_RO" '**Recovering a staged item with no report (#978).** Never re-dispatch it.' \
  "#978 C1 RO §6: the report-less staged item has a recovery that forbids re-dispatch"
pin "$_978_RO" 'if you still hold it, else by hand from the staged diff' \
  "#978 C1 RO §6: the recovery re-creates report.md from report_text or by hand"
pin "$_978_RO" '`close-finished` (§2b), and close'"'"'s gate runs in full.' \
  "#978 C1 RO §6: the recovery re-enters as close-finished"
pin "$_978_RO" 'leave a staged item with no report; recover it as below.' \
  "#978 C1 RO §6: both new halts name the recovery"
pin "$_978_RO" 'halts `halt:dirty-worktree` too: never re-dispatch it, Gate 3 refuses a staged worktree — re-create the report per §6' \
  "#978 C1 RO §2b: the dirty-worktree repair names the report recovery"
pin "$_978_RO" 'instead, and §6'"'"'s *Recovering a staged item with no report* brings it here' \
  "#978 C1 RO §3: the close-finished recovery names the report-less case"


# ---------------------------------------------------------------------------
# 1.29.1 (#981, #980, #973 items 1-2). One verifier pass can return several
# halting verdicts: every one is surfaced, recorded and named, and none hides
# another. Every completed pass writes verify.md, zero findings too, carrying
# the verifier line and the layer results, and the retro carries that line.
# ---------------------------------------------------------------------------
_981_IC="$SKILLS/close/references/impl-check.md"
_981_WC="$SKILLS/close/references/work-item-close.md"
_981_CR="$SKILLS/close/references/code-review.md"
_981_RT="$SKILLS/close/references/retrospective.md"
# absent <file> <needle> <label>: the old form is gone. The file must be
# readable and non-empty, or a missing file would pass every absence.
absent_981() {
  if [ ! -s "$1" ]; then T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (empty or unreadable: $1)"; return 0; fi
  if PIN_NEEDLE="$2" awk 'index($0, ENVIRON["PIN_NEEDLE"]) { f=1; exit } END { exit !f }' "$1"; then
    T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (still in ${1##*/}: $2)"
  else T_PASS=$((T_PASS+1)); fi
}
pin "$_981_IC" '**every halting verdict that pass returns is surfaced,' \
  "#981 impl-check: every halting verdict of one pass is surfaced"
pin "$_981_IC" 'the `[mutation]` row applies, with the fidelity claim attached' \
  "#981 impl-check §6: [fidelity] and [mutation] on one test take the [mutation] row"
pin "$_981_IC" 'verdict included — `[rule]`, `[fidelity]`, `[mutation]`.' \
  "#981 impl-check §4b: verify.md records every halting verdict"
pin "$_981_IC" 'verdicts and dropping the rest.** §1.' \
  "#973.1 impl-check §7: the anti-pattern is dropping a verdict, not gathering them"
absent_981 "$_981_IC" 'Gathering all failures before halting' "#973.1 impl-check: the gather-nothing anti-pattern is gone"
absent_981 "$_981_IC" 'first failure in any layer' "#973.1 impl-check: the halt-on-first-in-any-layer sentence is gone"
absent_981 "$_981_IC" 'deleted at zero findings' "#980 impl-check: verify.md is no longer deleted at zero findings"
pin "$_981_WC" 'any one halts, and the halt names all' \
  "#981 work-item-close §2: the halt names every verdict"
absent_981 "$_981_WC" 'Apply the verdicts in order' "#981 work-item-close §2: in-order verdicts are gone"
pin "$_981_WC" '`[rule]` included, the whole set is' \
  "#973.1 work-item-close §2: a [rule] halt still records Layer 4 and mutation"
pin "$_981_WC" '`[report cross-check]`, `[rule]`, `[fidelity]`, `[mutation]` (`impl-check.md`).' \
  "#973.2 work-item-close §5: the halt step lists all five tags"
pin "$_981_WC" '**Every completed verifier pass writes' \
  "#980 work-item-close §2: every completed pass writes verify.md"
pin "$_981_WC" 'line per layer (L1, L2, L3, L4, mutation; `not run` in an `--external-executor`' \
  "#980 work-item-close §2: verify.md carries each layer's result, external lane included"
pin "$_981_WC" 'Each halting verdict is one line that begins with its tag, or with `- `' \
  "#981 C2 work-item-close §2: names the line shape _oss_inv_rejection anchors on"
pin "$_981_WC" 'is tagged `[fidelity]`, a declared one is written as `fidelity`.' \
  "#980 work-item-close §2: [fidelity] marks only a halting finding (the rejection record)"
absent_981 "$_981_WC" 'delete the file rather than' "#980 work-item-close §2: zero findings no longer deletes verify.md"
pin "$_981_CR" '**ossify dispatches no spine review to another agent**' \
  "#973.1 code-review: the no-dispatch sentence is scoped to spine review"
absent_981 "$_981_CR" 'Absent is a clean signal' "#980 code-review: absent verify.md is no longer read as clean-by-design"
pin "$_981_RT" 'Give each item its `verifier:` line, copied from its' \
  "#980 retrospective bone §2: each item's verifier line"
pin "$_981_RT" 'and its `verifier:` line, as the bone set'"'"'s §2.' \
  "#980 retrospective flesh §1: each item's verifier line"
pin "$SKILLS/close/SKILL.md" '`report.md`, `verify.md` and the state' \
  "#980 close SKILL.md §10: verify.md is a durable record"
pin "$SKILLS/work-item/SKILL.md" '`GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 oss verify_step "<worktree-abs>" "<command>" "<expectation>"`' \
  "#946 work-item: a test that runs git also runs with no host identity"
pin "$SKILLS/work-item/SKILL.md" 'the command cannot run here yet (it exits 126 or 127' \
  "#1025 work-item: rc 2 names what the gate returns it for"
pin "$SKILLS/plan-spine/references/spec-authoring.md" '**An AC that runs a test file the item creates tests for it first**' \
  "#909 spec-authoring: an AC naming a file the item creates tests for it first"
pin "$SKILLS/plan-spine/references/spec-authoring.md" '`test -f tests/new.test.js && node --test tests/new.test.js tests/old.test.js`' \
  "#909 spec-authoring: the form guards the runner with test -f"
pin "$SKILLS/plan-spine/references/spec-authoring.md" '**An AC that diffs against a commit names a fixed sha**' \
  "#981 spec-authoring: base-relative ACs pin a sha, never a moving ref"

# ---------------------------------------------------------------------------
# 1.30.0 (#993). /close <wi> --pr --verdict <file>: a caller's verifier verdict
# replaces the close's own dispatch, bound to the worktree by an identity hash.
# ---------------------------------------------------------------------------
pin "$_981_WC" '--verdict <file>' \
  "#993 work-item-close §2: the --verdict arm exists"
pin "$_981_WC" 'close: verdict identity' \
  "#993 work-item-close §2: a stale verdict halts on its identity"
pin "$_981_WC" 'verifier: <agent> on <model>' \
  "#993 work-item-close §2: the verdict arm prints the verifier line from the file"
pin "$SKILLS/../commands/close.md" '[--verdict <file>]' \
  "#993 commands/close.md: the argument hint carries --verdict"
pin "$SKILLS/close/SKILL.md" '`--verdict <file>`' \
  "#993 close SKILL.md §9: the argument grammar names --verdict"
pin "$_981_WC" 'Under `--verdict` the verdict is the pass, and the close runs none of §4, §4b or §4c itself, inline or dispatched. Without it,' \
  "#993 work-item-close §2: the inline pass is excluded under --verdict"
pin "$_981_WC" 'close: $wi is already committed; a verdict written before the commit cannot match' \
  "#993 work-item-close §2: a --pr resume under --verdict names its own halt"
pin "$_981_WC" 'identity` that is not a hex digest' \
  "#993 work-item-close §2: a non-hex identity halts before it reaches the shell"
pin "$_981_WC" '**Without `--verdict`, after Layers 1 and 2, the close dispatches `ossify:verifier-agent`' \
  "#993 work-item-close §2: the dispatch sentence is conditional on no --verdict"

# ---------------------------------------------------------------------------
# adopt takes class P, a plain repo with product source and no legacy stack
# (#536; design 2026-11-02 sections 3 and 4, operator rulings the same day).
# Each rule is pinned where the actor reads it: the pointer in SKILL.md and the
# depth in references/plain-repo.md; the old refusal wording is pinned absent.
_AD2="$SKILLS/adopt/SKILL.md"
_PR="$SKILLS/adopt/references/plain-repo.md"
if [ -f "$_PR" ]; then T_PASS=$((T_PASS+1)); else T_FAIL=$((T_FAIL+1)); echo "FAIL: adopt/references/plain-repo.md is missing (#536)"; fi
pin "$_AD2" '- **Class step — after A1.**' \
  "adopt §3 has a class step right after A1 (#536)"
pin "$_AD2" 'L and P never mix.' \
  "adopt's class step keeps L and P apart (#536)"
pin "$_PR" 'refuse, authoring nothing further, and route to **`/ossify:start`**' \
  "plain-repo §1: no product source refuses and routes to /ossify:start (#536)"
pin "$_PR" '3. **Yes, and no stack: class P.**' \
  "plain-repo §1: source without a legacy stack is class P (#536)"
pin "$_PR" 'A declared repo with no commit has no baseline SHA. If it holds files, stop and name it before anything is recorded:' \
  "plain-repo §1: an unborn HEAD with files stops and is named, it does not route to /start (#536)"
pin "$_PR" 'the operator commits them first (that is not "no product source", and it does not route to `/start`).' \
  "plain-repo §1: an unborn HEAD is not the no-product-source answer (#536)"
pin "$_PR" 'A product repo the declaration does not name refuses, and the refusal names the fix in the declaration'"'"'s own spelling.' \
  "plain-repo §2: an undeclared product repo refuses and names the fix (#536)"
pin "$_PR" 'A native `.ossify/topology.json` takes `.repos.<key>.root`' \
  "plain-repo §2: the native-topology fix is .repos.<key>.root (#536)"
pin "$_PR" '`.workspace/pairing.json` pairing manifest takes a top-level `{"root": "<absolute path>"}` entry under a fresh key' \
  "plain-repo §2: the pairing-manifest fix is a top-level {root} entry (#536)"
pin "$_PR" 'adopt does not edit a declaration it did not write.' \
  "plain-repo §2: adopt never edits a declaration it did not write (#536)"
pin "$_PR" 'never writes a byte in a product repo during A1.' \
  "plain-repo §2: A1 writes nothing in a product repo (#536)"
pin "$_PR" '**Check first** that the working directory is not a declared repo and is not inside one' \
  "plain-repo §2: class P checks the working directory is no declared repo (#536)"
pin "$_AD2" '--untracked-files=all` each. Any line, in any one — class P exempts only the topology A1 authored this run' \
  "adopt A3 lists untracked files one by one and exempts only the authored topology (#536)"
pin "$_PR" 'A3 exempts the exact path `.ossify/topology.json` in the AI workspace, and only when A1 authored it in this run.' \
  "plain-repo §2: the A3 exemption is the exact topology path, A1-authored this run (#536)"
pin "$_PR" 'exemption above is exact. Any other line refuses, as "work in flight"' \
  "plain-repo §3: any other line than the exempt topology still refuses at A3 (#536)"
pin "$_PR" 'git -C <root> worktree list --porcelain' \
  "plain-repo §3: A4 lists linked worktrees for class P (#536)"
pin "$_AD2" 'Class P records `A5: no legacy stack`.' \
  "adopt A5 records a plain repo's absent cursor (#536)"
pin "$_AD2" '- **A6 — something ships (class P only).**' \
  "adopt has gate A6 for class P (#536)"
pin "$_PR" '> nothing ships yet: this project is pre-skeleton. ossify cannot onboard it until one step works, or until the' \
  "plain-repo §3: A6 refuses with the nothing-ships wording (#536)"
pin "$_PR" 'None: refuse, before any state is written:' \
  "plain-repo §3: A6 refuses before any state (#536)"
pin "$_PR" '**C4 closes Release 0 only when at least one step is still `shipped` after C2**' \
  "plain-repo §4: C4's rule for Release 0 (#536)"
pin "$_PR" 'clean-checkout test is already re-marked `next` (C2), and harvested to the feature map then (C1'"'"'s harvest ran' \
  "plain-repo §4: a step C2 re-marks next is harvested to the feature map (#536)"
pin "$_AD2" 'A step it re-marks `next` is harvested to the feature map then' \
  "adopt C2: a step re-marked next is harvested, for class L too (#536)"
pin "$_PR" 'at C4, after C3, do not call `release_add`' \
  "plain-repo §4: zero shipped steps after C2 mints no Release 0, and halts at C4 after C3 (#536)"
pin "$_PR" 'names what to clear to retry: the file `oss state_path` prints and its `.base.json` sibling, `ADOPTION.md` moved' \
  "plain-repo §4: the C2 halt's hand-off names the state file, its .base.json and ADOPTION.md (#536)"
pin "$_PR" 'outside the AI workspace (C5 creates it only when absent; A3 refuses it untracked inside), and C3'"'"'s uncommitted ADR files in the product repo (commit or remove' \
  "plain-repo §4: the retry hand-off names C3's uncommitted ADR files (#536)"
pin "$_AD2" 'a class P halt at C4, after C2 left zero `shipped` steps, is a halt,' \
  "adopt's completion floor accepts the C4 halt after a zero-shipped C2 as a halt (#536)"
pin "$_AD2" 'a workspace-init stub is replaced (`../start/references/occupied-destinations.md` §1a)' \
  "adopt C5 replaces a workspace-init stub, not merges into it (#536)"
pin "$_PR" 'is replaced, not merged, per `../../start/references/occupied-destinations.md` §1a, carrying its' \
  "plain-repo §5: a workspace-init stub is replaced, carrying its policy sections (#536)"
pin "$_PR" '`## Git policy` and `## AI-trace filter` sections verbatim' \
  "plain-repo §5: Git policy and AI-trace filter carry over verbatim (#536)"
pin "$_PR" 'Never write, move or delete one.' \
  "plain-repo §5: a declared repo's own files are inputs, never written (#536)"
pin "$_PR" 'each conflict with the AI workspace' \
  "plain-repo §5: the adoption record lists the conflicts (#536)"
pin "$_PR" 'elicited as `/start` §4 does' \
  "plain-repo §6: Vision is elicited for class P (#536)"
pin "$_PR" 'class P with no test suite runs `/start` §9 in full.' \
  "plain-repo §6: only a class P repo with no test suite runs the full smoke (#536)"
pin "$_AD2" 'Class P with no test suite: `/start` §9 in full.' \
  "adopt §4: the full smoke is class P's, class L keeps the narrowed smoke (#536)"
pin "$_PR" 'stay **uncommitted** in the product repo' \
  "plain-repo §6: authored ADRs stay uncommitted and are named in the hand-off (#536)"
pin "$_PR" 'mint scan with `dest_repo` set to that repo' \
  "plain-repo §6: authored ADRs are numbered by the mint scan with dest_repo (#536)"
pin "$_PR" 'that halt and C3'"'"'s collision halt (`SKILL.md` C3 1a) are the' \
  "plain-repo §6: the floor allows the C2 halt and C3's collision halt (#536)"
pin "$_AD2" 'refuse if the working directory is a declared repo' \
  "adopt A1: class P refuses when run from a declared repo (#536)"
pin "$SKILLS/start/SKILL.md" 'plain repo with product source alike (#536; ossify 1.35.0 or later)' \
  "start §3's refusal names adopt as taking a plain repo (#536)"
# The old refusal wording stays gone (each string was present at the base db0d0481 in the file named).
_c="$(grep -c -F -- 'out of scope today' "$_AD2" || true)"
_pin "$([ "$_c" = 0 ] && echo 0 || echo 1)" "adopt/SKILL.md still says 'out of scope today' (#536)"
for _old in 'plain repos: #536' 'which today takes only a project onboarded'; do
  _c="$(grep -c -F -- "$_old" "$SKILLS/start/SKILL.md" || true)"
  _pin "$([ "$_c" = 0 ] && echo 0 || echo 1)" "start/SKILL.md still says '$_old' (#536)"
done

# --- #434: close checks the spec against its dispatch-time blob id ---------------------
_434_WC="$SKILLS/close/references/work-item-close.md"
_434_RO="$SKILLS/work-item/references/round-orchestration.md"
_434_EX="$SKILLS/work-item/references/external-executor.md"
pin "$_434_WC" 'halt:spec-changed - $wi'"'"'s spec.md is $now_oid, the spec dispatched was $rec_oid.' \
  "#434 work-item-close §1: the halt is named and carries both ids"
pin "$_434_WC" '(1) the spec should not have changed - restore the dispatched spec (find it in the AI workspace'"'"'s git history' \
  "#434 work-item-close §1: route 1, restore the dispatched spec from history or the planning record"
pin "$_434_WC" '(2) the spec changed on purpose - \"oss\" work_item_status $wi planned, save or discard the staged work, remove the item'"'"'s worktree, and re-run the round' \
  "#434 work-item-close §1: route 2, planned, save or discard, remove the worktree, re-run the round"
pin "$_434_WC" 'spec_note="no dispatch-time spec value for $wi: the spec check did not run"' \
  "#434 work-item-close §1: an absent value is a visible note, not a halt"
pin "$_434_WC" 'then `$spec_note` from §1 when it is non-empty' \
  "#434 work-item-close §2: the note survives into verify.md"
pin "$_434_WC" 'before every gate run' \
  "#434 work-item-close §1: the check runs before every gate run"
pin "$_434_WC" 'the `finish-merge` row of `round-orchestration.md` §2b runs it itself' \
  "#434 work-item-close §1: the finish-merge row runs the block too"
pin "$_434_RO" '"$(git -C "$wt" rev-parse HEAD)" "$spec_oid"' \
  "#434 round-orchestration §3: the dispatch passes spec_oid as the fifth argument"
pin "$_434_RO" 'spec_oid="$(oss spec_oid "$spine_dir_abs/work-<wi-id>/spec.md")"' \
  "#434 round-orchestration §3: the dispatch computes spec_oid with the one helper"
pin "$_434_RO" 'add the fifth argument `"$(oss spec_oid "<the item'"'"'s spec.md, §3'"'"'s path>")"` and print `spec value recorded at repair, not at dispatch` (the dispatch-time spec was never recorded' \
  "#434 round-orchestration: the adopt repair row prints the recorded-at-repair note"
pin "$_434_RO" 'ONLY when state holds no `spec_oid` for the item; when it holds one, call with the four arguments above, so the dispatch-time value is kept' \
  "#434 round-orchestration: the base-unknown row passes spec_oid only when state holds none"
pin "$_434_RO" 'and halt if that read errors. Pass the fifth argument' \
  "#434 round-orchestration: the base-unknown row reads the recorded value and halts on a read error"
pin "$_434_RO" 'a recorded value is kept by the four-argument call' \
  "#434 round-orchestration: the adopt row keeps a recorded value"
pin "$_434_RO" 'it runs `work-item-close.md` §1'"'"'s spec-check block itself' \
  "#434 round-orchestration: the finish-merge row runs the spec check before its gate"
pin "$_434_RO" '| `halt:spec-changed`' "#434 round-orchestration: halt:spec-changed has a repair row"
pin "$_434_EX" 'close now also checks the tree against the spec value recorded at dispatch' \
  "#434 external-executor: §5a checks the record against the tree, close checks the tree against dispatch"
pin "$_434_WC" 'cannot read $wi'"'"'s recorded spec value from state - halt' \
  "#434 work-item-close §1: a failed read of the recorded value halts (fails closed)"
pin "$SKILLS/plan-spine/references/citation-foldin.md" 'except in the spec of an item with a dispatch recorded and not' \
  "#434 citation-foldin §3: a dispatched, not-yet-complete item's spec is not edited in place"
pin "$_434_WC" 'There is no route that refreshes the recorded value in place' \
  "#434 work-item-close §1: the halt says there is no in-place refresh"
# NEGATIVE: no refresh route exists anywhere - not in the prose, not as a verb.
for _f in "$_434_WC" "$_434_RO" "$_434_EX"; do
  for _needle in 'oss spec_refresh' 'spec_oid_refresh' 'refresh the spec' 're-record the spec' 'oss work_item_spec'; do
    absent_981 "$_f" "$_needle" "#434 no refresh route: '$_needle' is not in ${_f##*/}"
  done
done
_434_VERB="$(bash "$HERE/../bin/oss" spec_refresh 2>&1 || true)"
case "$_434_VERB" in *"unknown subcommand"*) _pin 0 "#434 no refresh route: oss has no spec_refresh verb";; *) _pin 1 "#434 no refresh route: oss spec_refresh is not an unknown subcommand";; esac

# ossify 1.37.1 (#1121): handoff §2 names the source of the spine class, as it does for base_branch; a seat that has no
# source infers the class from "bones registered: none" and records flesh for a bone spine.
pin "$WI/references/handoff-contract.md" 'select(.id == "<spine-id>") | .class' \
  "handoff-contract §2 does not name the state query for the spine class (#1121) - a writer with no source infers it"
pin "$WI/references/handoff-contract.md" '(an empty result is a wrong id: stop, write no class)' \
  "handoff-contract §2 does not stop on an empty class query (#1121) - a wrong spine id would yield an empty class"
pin "$WI/references/handoff-contract.md" 'never derive it from the spine'"'"'s `## Bones this spine registers` list' \
  "handoff-contract §2 does not say the class is never derived from the spine's bones list (#1121) - a spine that registers no bones is still bone when its plan touches a registered surface"
pin "$WI/references/report-contract.md" "its class as the handoff's §2 states it" \
  "report-contract §1 row does not take the spine class as the handoff's §2 states it (#1121) - a report may restate a class the handoff never sourced"

# ossify 1.38.0 (#195, #473): the handoff ceremonies' safety rules. Each pin is red on cbc2a49e (ossify 1.37.1).
_HR="$HERE/../skills/handoff-resume/references/resume.md"
_HC="$HERE/../skills/handoff/references/compose.md"
_HS="$HERE/../skills/handoff/references/sections.md"
_HG="$HERE/../commands/handoff-resume.md"
# #195 item 1: git log, diff, show and rev-list take --output=<path> and write a file with no prompt, so the grant holds
# none of them. The WHOLE allowed-tools value is checked as a CLOSED SET (our own file, eleven known entries: the eight
# Bash probes plus Read, Glob and Grep): an extra entry (`Write`, `Edit`, `Bash(git:*)`, `Bash(git log *)`, a bare
# `Bash`), a missing one or a respelled one fails. The line is read alone: resume.md's own sentence names the four verbs.
_hg_got="$(awk '/^allowed-tools:/' "$_HG" | sed 's/^allowed-tools:[[:space:]]*//' | tr ',' '\n' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | LC_ALL=C sort)"
_hg_want="$(printf '%s\n' 'Bash(git status:*)' 'Bash(git rev-parse:*)' 'Bash(git ls-files:*)' 'Bash(gh issue view:*)' \
  'Bash(gh pr view:*)' 'Bash(gh pr list:*)' 'Bash(test:*)' 'Bash(ls:*)' 'Read' 'Glob' 'Grep' | LC_ALL=C sort)"
if [ "$_hg_got" = "$_hg_want" ]; then _pin 0 ""; else
  _pin 1 "handoff-resume's allowed-tools is not exactly the eight read probes plus Read, Glob, Grep (#195) - extra: [$(comm -13 <(printf '%s\n' "$_hg_want") <(printf '%s\n' "$_hg_got") | tr '\n' ' ')] missing: [$(comm -23 <(printf '%s\n' "$_hg_want") <(printf '%s\n' "$_hg_got") | tr '\n' ' ')]"
fi
# The ceremony's second entry surface is the skill itself (`ossify:handoff-resume`, `skill://handoff-resume`), which
# molt, omp-roles and crew invoke by name. Its frontmatter grants nothing: any allowed-tools key there fails.
_hg_skill="$HERE/../skills/handoff-resume/SKILL.md"
if awk 'NR==1 && !/^---$/ {exit 1} NR>1 && /^---$/ {exit 1} /^allowed-tools[[:space:]]*:/ {found=1} END {exit found ? 0 : 1}' "$_hg_skill"; then
  _pin 1 "skills/handoff-resume/SKILL.md frontmatter carries an allowed-tools grant (#195) - the skill surface must grant nothing"
else _pin 0 ""; fi
pin "$_HR" '`git log`, `diff`, `show` and `rev-list`' \
  "resume.md does not say git log, diff, show and rev-list prompt on purpose (#195)"
pin "$_HR" 'prompt on purpose: each takes `--output=<path>` and writes a file (#195).' \
  "resume.md does not say git log, diff, show and rev-list prompt on purpose because each writes a file (#195)"
# #195 item 2: an explicit path to a work order is named, stale, and not worked.
pin "$_HR" '"this is a work order, not session state", the verdict is' \
  "resume.md §1 does not make an explicit path to a work order say what it is (#195)"
pin "$_HR" 'If it is a per-work-item `handoff.md`' \
  "resume.md §1 does not name a per-work-item handoff.md as the work-order trigger (#195)"
pin "$_HR" "(a work order, not session state), the read-out's first line is" \
  "resume.md §1 does not make the work-order statement the read-out's first line (#195)"
pin "$_HR" '`stale — re-plan before acting`, and its steps are not worked unless the' \
  "resume.md §1 does not give an explicit path to a work order the stale verdict (#195)"
pin "$_HR" 'operator says so. The drift report is still emitted.' \
  "resume.md §1 does not say a work order's steps wait for the operator and the drift report is still emitted (#195)"
pin "$_HR" 'the later suffix is newer); where the naming carries no date, by the' \
  "resume.md §1 does not say which of two same-date handoffs is newer (#195)"
pin "$_HR" 'outside a git repo) — most recent by the filename date (on the same date,' \
  "resume.md §1 does not rank undated-name candidates after the filename date (#195)"
pin "$_HR" 'authored date in the header; where the header carries none, by file' \
  "resume.md §1 does not rank by the header's authored date before file history (#195)"
pin "$_HR" 'history (`git log -1` per candidate); where git carries none either' \
  "resume.md §1 does not rank by git history after the header date (#195)"
pin "$_HR" '(gitignored precedent, a non-git repo), by modification time.' \
  "resume.md §1 does not rank by modification time last (#195)"
pin "$_HR" '(step 1'"'"'s precondition is gone, or the target is a work order, §1), not' \
  "resume.md §3 does not give a work order's stale verdict a second trigger (#195)"
# #195 item 5: a taken file name is never overwritten (data loss under gitignored precedent).
pin "$_HC" '**Never overwrite an existing handoff.** Before stating the read-out, check' \
  "compose.md does not forbid overwriting an existing handoff, or checks after the read-out is stated (#195)"
pin "$_HC" 'the chosen name against the directory itself (`test -e`, not `git ls-files` —' \
  "compose.md does not check the name against the directory, so an ignored handoff is overwritten (#195)"
pin "$_HC" 'an ignored file is in no index). If it is taken, use the next free name' \
  "compose.md does not say to use the next free name when the name is taken (#195)"
pin "$_HC" '(`sections.md`, file name), and say in the read-out'"'"'s Location line that the' \
  "compose.md does not say the read-out names the taken name and the one used (#195)"
pin "$_HC" 'name was taken and which one was used.' \
  "compose.md does not say the read-out names which name was taken and which one was used (#195)"
pin "$_HS" '**A name already taken is never reused.** Take the next free one: the repo'"'"'s' \
  "sections.md has no next-free-name rule (#195)"
pin "$_HS" 'own suffix precedent where there is one (a letter after the date: the next' \
  "sections.md does not follow the repo's own suffix precedent for a taken name (#195)"
pin "$_HS" 'letter unused on that date, `2026-11-09d-<topic>.md`), else `-2`, `-3` before' \
  "sections.md does not give the suffix forms for a taken name (#195)"
# #195 items 3 and 4: the header date is recorded because resume ranks by it; §2 names the root the checks ran from.
pin "$_HS" "resume needs it for §3's age and to rank candidates, and a gitignored file" \
  "sections.md does not say the header's authored date is what resume ranks candidates by (#195)"
pin "$_HS" 'Open with one line naming the directory the checks were run from: the repo' \
  "sections.md §2 does not open with a line naming the directory the checks were run from (#195)"
pin "$_HS" 'root, or the package root for a package-scoped handoff. The proven form is a' \
  "sections.md §2 does not name the package root for a package-scoped handoff (#195)"
# #473: trap facts. Compose adds the row; resume counts and does not check.
pin "$_HS" 'A trap that states a checkable fact also gets a §2 row.' \
  "sections.md §6 does not require a §2 row for a trap that states a fact (#473)"
pin "$_HR" '§6 traps   <n> traps · <m> state facts · <k> of those have a §2 row' \
  "resume.md's drift report has no §6 traps line (#473)"
pin "$_HR" '- §6 is counted, not checked: report how many traps it lists, how many state a' \
  "resume.md §2 does not say §6 is counted, not checked (#473)"
pin "$_HR" 'checkable fact, and how many of those have a §2 row (no §6: 0 traps).' \
  "resume.md §2 does not count the traps with a §2 row, or does not give a handoff with no §6 zero traps (#473)"
pin "$_HR" 'with no row is the gap this makes visible; resume does not check it.' \
  "resume.md §2 does not say resume leaves a trap fact with no row unchecked (#473)"

# --- ossify 1.39.0 (#761 items 1-2, #770, #761 item 6): the v3 migrate prose, the combined demo
# grammar at every site that states it, and the fifth deferral column. Each needle is unique in
# its file, so a deleted sentence cannot hide behind a copy elsewhere.
_SK="$HERE/../skills"
pin "$_SK/doctor/references/state-inspection.md" '`migrate` accepts v1, v2 and v3 (v3 → v4); there is no downgrade' \
  "state-inspection.md does not say migrate accepts v1, v2 and v3 (#761)"
pin "$_SK/doctor/references/state-inspection.md" 'against a v1, v2 or v3 state, `oss state_restore` prints' \
  "state-inspection.md does not say state_restore prints already-clean against a v3 state too (#761)"
pin "$_SK/close/SKILL.md" '`migrate` accepts v1, v2 and v3 (v3 → v4) |' \
  "close/SKILL.md's schema row does not say migrate accepts v1, v2 and v3 (#761)"
pin "$_SK/close/SKILL.md" 'against a v1, v2 or v3 state it prints `restore:' \
  "close/SKILL.md does not say state_restore prints already-clean against a v3 state too (#761)"
if grep -rnF 'v1/v2 only' "$_SK" >/dev/null 2>&1; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: a skill still says migrate accepts 'v1/v2 only' (#761)"
else T_PASS=$((T_PASS+1)); fi
pin "$_SK/plan-spine/SKILL.md" '(`exit:<n>` | `contains:<str>` | `exit:<n>+contains:<str>`) at authoring time' \
  "plan-spine SKILL.md §8's floor does not list the combined demo form (#770)"
pin "$_SK/plan-spine/SKILL.md" 'or `exit:<n>+contains:<str>` (rc **and** output must hold; exit **2** else)' \
  "plan-spine SKILL.md §8d does not list the combined demo form as validated (#770)"
pin "$_SK/plan-spine/references/demo-authoring.md" '(`exit:<n>` \| `contains:<str>` \| `exit:<n>+contains:<str>`) at authoring time' \
  "demo-authoring.md F5 does not list the combined demo form (#770)"
pin "$_SK/plan-spine/references/demo-authoring.md" '<command> → exit:<n>|contains:<str>|exit:<n>+contains:<str>' \
  "demo-authoring.md's read-out template does not list the combined demo form (#770)"
pin "$_SK/plan-spine/references/demo-authoring.md" '`exit:<n>+contains:<str>` only), so **the threshold lives inside the command**' \
  "demo-authoring.md's no-comparison-form sentence does not list the combined demo form (#770)"
pin "$_SK/plan-spine/references/demo-authoring.md" '"exit:0|contains:<str>|exit:0+contains:<str>"' \
  "demo-authoring.md §6's call does not show the combined demo form (#770)"
pin "$_SK/plan-spine/references/demo-authoring.md" '`<expected>` is validated as `exit:<n>`, `contains:<str>` or `exit:<n>+contains:<str>`' \
  "demo-authoring.md §6 does not list the combined demo form as validated (#770)"
pin "$_SK/plan-spine/references/demo-authoring.md" 'recognised test runner, a run of zero tests fails too. An ossify older than 1.39.0' \
  "demo-authoring.md §6 does not state the zero-tests rule and the older-ossify limit for the combined form (#770)"
pin "$_SK/plan-spine/references/spec-authoring.md" 'colon grammar: `exit:0+contains:<str>` (#770)' \
  "spec-authoring.md does not say the ledger has the combined form (#770)"
if grep -nF 'has no exit half (a follow-up issue tracks it)' "$_SK/plan-spine/references/spec-authoring.md" >/dev/null 2>&1; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: spec-authoring.md still says the ledger's contains: has no exit half pending a follow-up (#770)"
else T_PASS=$((T_PASS+1)); fi
pin "$_SK/close/references/cumulative-demo.md" 'and `exit:<n>+contains:<str>` are the whole grammar),' \
  "cumulative-demo.md's grammar list does not include the combined demo form (#770)"
pin "$_SK/close/references/cumulative-demo.md" 'A line `exit:<n>+contains:<str>` passes only when its rc equals `<n>` **and** its output' \
  "cumulative-demo.md does not say the combined form needs both halves (#770)"
pin "$_SK/close/references/release-close.md" 'line per finding — except that a deferral row carries a fifth column, `source_spine`: the' \
  "release-close.md's deferral gate prose does not name the fifth column (#761)"
pin "$_SK/close/references/release-close.md" 'its `<spine>` is the row'"'"'s column 5.' \
  "release-close.md's re-defer bullet does not point at column 5 for the owning spine (#761)"

t_summary
