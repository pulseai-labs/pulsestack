#!/usr/bin/env bash
#
# crew — the ossify spine execution seam, mechanical facts only.
#
# The three-layer model is judgment: when the phase activates, who owns what,
# how a plan relay is scored, what happens at depth exceeded. NONE of that is
# asserted here — pinning judgment as dozens of exact prose clauses turns a
# fidelity guard into a prose-freeze that fails on every rewording, which is the
# failure mode `test-fidelity-pins.sh`'s own header exists to prevent. Those
# belong to the semantic rubric.
#
# What IS mechanical, and is asserted:
#
#   - the SEATS contract: the injected block exists, is used verbatim, halts on
#     a missing row, and no sidecar token survives anywhere in shipped prose
#   - the reviewer's ABSENCE from that block (the seats are not where the
#     reviewer is chosen), scoped to the block itself so prose about reviewer
#     timing cannot satisfy or break it
#   - the three fixed-procedure keys, byte-exact
#   - zero subagent-invocation forms in the activated path's own references
#   - the exact command the spine session is briefed to run
#   - the identities its brief must carry: its report path, its own run.json
#     and the herdr mechanics it follows
#   - the nested run's own mechanical values: the file item bookkeeping lives
#     in, the round barrier's gate node, and the required worker depth
#   - no worker-to-orchestrator message type herdr does not have
#   - the line budget these references are held to
#
# Counting is one awk index() pass: `grep -c` counts LINES, and `… | grep -q`
# can fail on a true match under pipefail. Every zero-count has a non-empty
# control beside it.
#
# Every file this suite reads ships with the plugin: README.md, CHANGELOG.md and
# tests/eval/ included. A missing one FAILS rather than skipping. Until Task 9 the
# three that landed last were guarded by `landed`, which printed a note and
# returned 1 — a wrong path would then read as "not present yet" forever, and a
# zero-count against a file nobody opened is not a clean file.
#
# Usage:   bash crew/tests/test-ossify-spine-contract.sh
# Exit:    0 if every mechanical fact holds; 1 otherwise.
# Deps:    bash 3.2+, awk.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REF="$PLUGIN_ROOT/skills/orchestrate/references"
EXEC_MD="$REF/ossify-execution.md"
BRIEFS_MD="$REF/ossify-briefs.md"
NESTED_MD="$REF/ossify-nested-run.md"
PRBRIEFS_MD="$REF/ossify-pr-briefs.md"
WRITER_MD="$REF/ossify-close-writer.md"
LIFECYCLE_MD="$REF/lifecycle.md"
ROLES_MD="$REF/roles.md"
GENERIC_BRIEFS_MD="$REF/briefs.md"
SKILL_MD="$PLUGIN_ROOT/skills/orchestrate/SKILL.md"
CONFIG_MD="$REF/config.md"
PLUGIN_README_MD="$PLUGIN_ROOT/README.md"
COMMAND_MD="$PLUGIN_ROOT/commands/orchestrate.md"
MECHANICS_MD="$REF/layers/herdr.md"
ORCA_MD="$REF/layers/orca.md"
COMPLETION_MD="$REF/completion.md"
EVAL_DIR="$PLUGIN_ROOT/tests/eval"
EVAL_FIXTURE14="$EVAL_DIR/fixtures/ossify-spine-execution/14-close-brief-identities-and-workspace-records.md"
EVAL_RUBRIC_MD="$EVAL_DIR/rubrics/ossify-spine-execution.md"
CHANGELOG_MD="$PLUGIN_ROOT/CHANGELOG.md"

# shellcheck source=/dev/null
. "$SCRIPT_DIR/_helpers.sh"

REF_BUDGET=241          # 2026-10-28: the budget equals the longest budgeted reference (241,
                        # ossify-briefs.md), 20 lines down from 261 now that the enrolled-authority
                        # envelope has left the spine briefs. Earlier history: 2026-10-18 (Task 13)
                        # raised it to 261 for the SEATS rows' agent name and host; 0.2.9 raised it
                        # from 214 for the spine brief's 1.14.0 caller rules and re-entry seat rule;
                        # Task 4 raised it 257 -> 260 for the three `PING_SEND=` fill lines its
                        # templates gained.
                        # 0.2.7 (seat-mods 0.2.0): raised from 204 for the coordinator-marking
                        # clause each launch site gained.
                        # 0.2.8: raised for the molt clauses — nested-run §4 (211), the spine brief
                        # (214), the spine, work-PR and leaf MOLT lines.
                        # 0.2.11 (#663): raised from 230 for the two launch-site citing clauses
                        # (ossify-briefs.md's item-verifier intro took the two lines, 232).
                        # 0.2.16: the §8a caller rule lost its "(run-spine's resolved
                        # dispatcher)" parenthetical, which took ossify-briefs.md back to 231.
                        # 0.2.23 (PR #860 review F11): the gate and its adjacent control were
                        # deleted while ossify-briefs.md grew to 257 lines — the shipped briefs
                        # gained the review-round and close-out caller rules. Restored at the
                        # reviewed size rather than the file being cut to fit a stale bound; the
                        # budget still equals the longest budgeted reference, and the adjacent
                        # control below holds the gate at that minimum.

# occurrences, occurrences_flat, count_of and pin are _helpers.sh's (#514, L1);
# this suite's pin already took <file> <needle> <label> [line|flat], which is the
# shape the other suites adopted when their copies were hoisted. What is left here
# is this suite's own ten: absent, absent_any, assert_set, budget, keys, n_eq,
# nonempty, and — further down, beside the check they serve — span_of,
# commands_in_span and span_balanced.
#
# `flat` is the fourth argument of pin/present, and it is used only where the
# clause's own text is split by a line wrap today: a per-line pin could assert
# only a fragment of it and would report the clause absent. The squeezed-line
# join lives in _helpers.sh; the join is by SQUEEZING, not by the config suite's
# newline DELETION — those clauses are personal names, which are space-less,
# while these are prose whose words are separated by the very space the wrap
# consumed.

absent() {
  c="$(count_of "$1" "$2" "${4:-line}")" || { fail "$3" "unreadable file: $1"; return 0; }
  if [ "$c" -eq 0 ]; then pass "$3"
  else fail "$3" "'$2' occurs $c time(s) in ${1##*/}"; fi
}

# Every needle must count 0. For a claim whose SPELLING is not fixed, one needle
# asserts less than its label promises: T7's absence pin below counted 0 for four
# honest rewordings of the very claim it was written to keep out. The label here
# describes the whole set, the failure message names the spelling that came back,
# and an empty set is refused — a count over nothing is not a clean file.
absent_any() { # <file> <label> <line|flat> <needle>...
  _file="$1"; _label="$2"; _how="$3"; shift 3
  if [ "$#" -eq 0 ]; then fail "$_label" "no needles — an empty set certifies nothing"; return 0; fi
  _hits=""
  for _needle in "$@"; do
    _c="$(count_of "$_file" "$_needle" "$_how")" || { fail "$_label" "unreadable file: $_file"; return 0; }
    [ "$_c" -eq 0 ] || _hits="$_hits [$_needle x$_c]"
  done
  if [ -z "$_hits" ]; then pass "$_label"
  else fail "$_label" "the claim is back:$_hits"; fi
}

nonempty() {
  if [ -s "$1" ]; then pass "$2"
  else fail "$2" "$1 is missing or empty — every zero-count against it would be vacuous"; fi
}

budget() { # <file> <label>: the reference's own line count against REF_BUDGET.
  if [ ! -f "$1" ]; then fail "$2" "no such file: $1"; return 0; fi
  n="$(wc -l < "$1" | tr -d ' ')"
  if [ "$n" -le "$REF_BUDGET" ]; then pass "$2 ($n lines)"
  else fail "$2" "$n lines, over the $REF_BUDGET-line reference budget by $((n - REF_BUDGET))"; fi
}


# keys <file> <from-literal> <to-literal-or-empty> -> sorted `key:` names of
# zero-indent `key: value` lines in that span. An empty <to> runs to the first
# line starting with '## ' after the span opened.
keys() {
  awk -v from="$2" -v to="$3" '
    !seen && index($0, from) > 0 { seen = 1; next }
    seen && to != "" && index($0, to) > 0 { exit }
    seen && to == "" && /^## / { exit }
    seen && /^```[[:space:]]*$/ { exit }
    seen && /^[a-z_]+:/ { k = $0; sub(/:.*$/, "", k); print k }
  ' "$1" | LC_ALL=C sort
}

assert_set() { # <observed> <expected space-separated> <label>
  want="$(printf '%s\n' $2 | LC_ALL=C sort)"
  if [ "$1" = "$want" ]; then pass "$3"
  else
    fail "$3" "expected [$(printf '%s' "$want" | tr '\n' ' ')] — observed [$(printf '%s' "$1" | tr '\n' ' ')]"
  fi
}

printf '%screw — ossify spine execution seam (mechanical)%s\n\n' "$DIM" "$RST"

section "the seats contract"

nonempty "$EXEC_MD" "references/ossify-execution.md exists"

# Seats reach a spine session in its brief, not through a file. These are the
# mechanical halves of that: the block exists, it is used verbatim, a missing
# row halts, and no sidecar path survives anywhere in shipped prose.
pin "$BRIEFS_MD" 'SEATS — the operator-approved seats for this spine' \
  "the spine brief carries the seats block"
pin "$BRIEFS_MD" 'A seat this block does not list halts the item and asks' \
  "a missing seat row halts rather than substituting"
for f in "$EXEC_MD" "$NESTED_MD" "$BRIEFS_MD" "$PRBRIEFS_MD" "$WRITER_MD" \
         "$ROLES_MD" "$LIFECYCLE_MD" "$GENERIC_BRIEFS_MD" "$SKILL_MD" \
         "$PLUGIN_README_MD" "$COMMAND_MD"; do
  rel="${f#"$PLUGIN_ROOT"/}"
  # A count of zero from a file nobody read is not a clean file. README.md is
  # swept here like every other carrier — no skip, so a moved or renamed README
  # fails rather than reporting itself absent.
  if [ ! -r "$f" ]; then
    fail "no sidecar reference survives in $rel" "missing or unreadable — the sweep cannot certify a file it cannot open"
    continue
  fi
  gone=0
  for needle in 'sidecar' 'orca-execution.md' 'SIDECAR_OID' 'ORCA_EXECUTION_PATH' 'spine_plan_oid' 'orca-execution/v2'; do
    c="$(occurrences "$f" "$needle")" || c=0
    gone=$((gone + c))
  done
  if [ "$gone" -eq 0 ]; then pass "no sidecar reference survives in $rel"
  else fail "no sidecar reference survives in $rel" "$gone occurrence(s)"; fi
done

pin "$EXEC_MD" 'one implementer and one verifier seat per item' \
  "the top recommends one implementer and one verifier seat per item"
pin "$EXEC_MD" 'the approved seats travel in the brief' \
  "the freeze is the injected brief, not a file on disk"
pin "$EXEC_MD" 'names agents, never commands' \
  "the project file records agent names; the SEATS block resolves the triple"
# The lifecycle never launches a seat by delivering a brief: the launch is
# roles.md's sequence, where delivery is the step after readiness.
pin "$LIFECYCLE_MD" 'is `roles.md`'"'"'s "The launch,"' \
  "the lifecycle launches a seat through roles.md's launch sequence"

# The three procedures were never the sidecar's: they survive the deletion
# byte-exact, still recorded so the spine session checks rather than chooses.
assert_set "$(keys "$EXEC_MD" '## Fixed procedures' '')" \
  "implementation_plan_gate implementer_entrypoint verifier_procedure" \
  "the fixed-procedure block carries exactly its three keys"

pin "$EXEC_MD" 'implementation_plan_gate: worker-authored/top-orchestrator-approved' \
  "the plan gate's value is byte-exact"
pin "$EXEC_MD" 'implementer_entrypoint: /ossify:work-item <handoff path>' \
  "the implementer entry point's value is byte-exact"
# #435: an angle-bracket slot, not a $NAME nothing injects.
absent "$EXEC_MD" '$HANDOFF_PATH' \
  "the entry point spends no uninjected \$NAME"
pin "$EXEC_MD" 'verifier_procedure: all-claims-work-item-verify/v1' \
  "the verifier procedure's value is byte-exact"

section "the reviewer is not in the seats"

# Scoped to the SEATS block, so prose stating WHEN the reviewer is chosen
# neither satisfies nor breaks this. Extract it, then assert on the extract.
tmpl="$(mktemp)"
awk '!seen && index($0, "SEATS — the operator-approved") > 0 { seen = 1 }
     seen && /^[[:space:]]*$/ { exit }
     seen { print }' "$BRIEFS_MD" > "$tmpl"
nonempty "$tmpl" "the SEATS block extracts (control for the counts below)"
for k in 'reviewer' 'code_review'; do
  absent "$tmpl" "$k" "the SEATS block carries no '$k' row"
done
rm -f "$tmpl"

section "no subagent invocation in the activated path"

nonempty "$BRIEFS_MD" "references/ossify-briefs.md exists"
nonempty "$NESTED_MD" "references/ossify-nested-run.md exists"
nonempty "$PRBRIEFS_MD" "references/ossify-pr-briefs.md exists"
nonempty "$WRITER_MD" "references/ossify-close-writer.md exists"
for f in "$EXEC_MD" "$NESTED_MD" "$BRIEFS_MD" "$PRBRIEFS_MD" "$WRITER_MD"; do
  for form in 'Task(' 'Agent(' 'subagent_type'; do
    absent "$f" "$form" "${f##*/} invokes no subagent ('$form')"
  done
done

section "the spine session's briefed command and identities"

pin "$BRIEFS_MD" '/ossify:run-spine $SPINE_ID --external-executor' \
  "the spine-session brief names the external command shape exactly once"
# SPINE_ID is in this list because the brief's TASK spends it — `/ossify:run-spine
# $SPINE_ID --external-executor` — and a brief that spends a name it never injects
# leaves the worker to rediscover it, which is the one thing the block forbids.
# S3a/#446 RF9: the lifecycle id slots are GONE, and herdr prepends nothing to a
# brief, so no id arrives any other way. What the spine session needs from above
# is where to write (REPORT_PATH, one per brief the file holds), the run.json it
# owns (RUN_JSON) and how herdr is driven (MECHANICS). The absence controls live
# one section down.
for id in RUN_JSON SPINE_ID MECHANICS; do
  pin "$BRIEFS_MD" "$id=" "the spine brief injects $id exactly once"
done
n_eq() { c="$(occurrences "$1" "$2")"; if [ "$c" -eq "$3" ]; then pass "$4 ($c)"; else fail "$4" "found $c, expected $3"; fi; }
n_eq "$BRIEFS_MD" 'REPORT_PATH=' 3 \
  "the spine, item implementer and item verifier briefs each name a report path"
# D24: the approved model the banner must match. D28's per-launch revalidation
# becomes the verbatim rule: every item seat launches from its SEATS row.
pin "$BRIEFS_MD" 'SPINE_EXPECTED_MODEL=' \
  "the spine brief injects the approved expected model exactly once"
pin "$BRIEFS_MD" 'SPINE_COMMAND=' \
  "the spine brief injects its own command exactly once"
pin "$BRIEFS_MD" 'SPINE_EFFORT=' \
  "the spine brief injects its own effort exactly once"
pin "$BRIEFS_MD" 'from its SEATS row, verbatim' \
  "every item launch spends its SEATS row, not a re-read file"

section "no lifecycle id slots: every brief names its report path"

# S3a/#446 RF9 + #454 + #447/#450 + #449, mechanical only: the removed declaration
# slots are gone, the new injected identities exist exactly once, the close-review
# halt has a result shape, the contradiction is deleted, and the spine brief
# releases its seats as layers/herdr.md's Teardown says (#455's requirement,
# which named the exact close command). The BEHAVIOUR around each (who validates
# what, which branch runs first) is the rubric's, not this file's.
absent "$BRIEFS_MD" 'SPINE_TASK_ID=' \
  "the spine brief no longer declares its own task id"
absent "$BRIEFS_MD" 'SPINE_DISPATCH_ID=' \
  "the spine brief no longer declares its own dispatch id"
for k in 'CLOSE_TASK_ID=' 'CLOSE_DISPATCH_ID=' 'WORKPR_TASK_ID=' 'WORKPR_DISPATCH_ID='; do
  absent "$PRBRIEFS_MD" "$k" "the PR briefs no longer declare '$k'"
done
# The parent's run id routed a question and a completion upward; herdr has no
# channel for either, so the report file replaces it in every coordinator brief.
for f in "$BRIEFS_MD" "$PRBRIEFS_MD" "$WRITER_MD"; do
  absent "$f" 'PARENT_RUN_ID' "${f##*/} carries no parent run id"
done
n_eq "$PRBRIEFS_MD" 'REPORT_PATH=' 2 \
  "the close and work-PR briefs each name a report path"
pin "$WRITER_MD" 'REPORT_PATH=' \
  "the close-review writer's brief names its report path"
# The ping target rides the report-path slot line, one per report-producing
# template: three spine-layer sessions, two PR-layer, one writer. A template
# missing its slot lowers the count, which is what makes the count the check.
n_eq "$BRIEFS_MD" 'NOTIFY_RUN=' 3 \
  "all three spine briefs carry the run file the ping reads"
n_eq "$PRBRIEFS_MD" 'NOTIFY_RUN=' 2 \
  "the close and work-PR briefs carry the run file the ping reads"
pin "$WRITER_MD" 'NOTIFY_RUN=' \
  "the close-review writer's brief carries the run file the ping reads"
n_eq "$BRIEFS_MD" 'NOTIFY_MACHINE=' 3 \
  "all three spine briefs carry the worker's machine"
n_eq "$PRBRIEFS_MD" 'NOTIFY_MACHINE=' 2 \
  "the close and work-PR briefs carry the worker's machine"
pin "$WRITER_MD" 'NOTIFY_MACHINE=' \
  "the close-review writer's brief carries the worker's machine"
for f in "$BRIEFS_MD" "$PRBRIEFS_MD" "$WRITER_MD" "$GENERIC_BRIEFS_MD" "$MECHANICS_MD" "$LIFECYCLE_MD" "$SKILL_MD" "$CONFIG_MD" "$PLUGIN_README_MD" "$EXEC_MD" "$NESTED_MD" "$ROLES_MD"; do
  absent "$f" 'NOTIFY_PANE' "${f##*/} names no fixed ping target"
done
# #816: the ping goes only to a pane on the worker's own server. The comparison is
# the rule that keeps a cross-host rotation from pinging a pane id from another server.
pin "$COMPLETION_MD" 'only when `run.orchestrator.machine` equals `NOTIFY_MACHINE`' \
  "the ping compares the top's machine with the worker's" flat
pin "$GENERIC_BRIEFS_MD" 'a stored brief whose fixed run file or fixed machine differs from the run'"'"'s is surfaced, not overridden; equal values are no conflict, kept as they are.' \
  "a stored brief conflicts on either fixed run file or fixed machine, not equal values" flat
for id in RUN_JSON MECHANICS; do
  pin "$PRBRIEFS_MD" "$id=" "the work-PR brief injects $id exactly once"
done
# One mechanic, one statement: the byte-identical anchor the briefs point at.
pin "$MECHANICS_MD" '## Teardown' \
  "layers/herdr.md carries the Teardown section the briefs defer to"
pin "$PRBRIEFS_MD" 'CLOSE_EXPECTED_MODEL=' \
  "the close brief injects its ratified expected model exactly once"
pin "$PRBRIEFS_MD" 'WORKPR_EXPECTED_MODEL=' \
  "the work-PR brief injects its ratified expected model exactly once"
pin "$PRBRIEFS_MD" 'PRIOR_REVIEW=' \
  "the work-PR brief injects the prior review record exactly once"
pin "$PRBRIEFS_MD" '"covered"' \
  "PRIOR_REVIEW has a third value for a covered-but-recordless PR"
# N1 (Codex, round 2): "covered" is evidence-gated — a dispatch that crashed
# before its reviewer existed cannot be labelled covered, or the PR merges
# with zero reviews.
pin "$PRBRIEFS_MD" 'durable evidence its delegated review ran' \
  "'covered' is spent only on durable evidence the review ran"
pin "$PRBRIEFS_MD" 'MERGE_EXECUTOR=' \
  "the work-PR brief injects the top's merge-executor assignment exactly once"
pin "$PRBRIEFS_MD" 'halted: close-review' \
  "a close-review halt has its own result shape"
# #449/R3+C1+C2: the close-review writer is a contracted seat — a brief of
# its own with a model gate, budgeted in roles.md, allocated one per affected
# hosting repo. Mechanical: the file exists, the gate is injected once, and the
# allocation rule is stated where the halt remediation lives.
pin "$WRITER_MD" 'WRITER_EXPECTED_MODEL=' \
  "the writer brief gates its ratified expected model"
# N5/#467: REPO= takes the declared target_repo identifier, which exists for a
# remote-less hosting repo too — owner/name assumed a remote.
pin "$WRITER_MD" 'declared `target_repo` identifier' \
  "the writer's REPO= takes the declared target_repo, not owner/name"
absent "$WRITER_MD" 'owner/name' \
  "the owner/name slot wording is gone"
# PR #470 row 3: the writer groups findings by the declared `target_repo` —
# the key the nested-run slice uses — never by the repo a file lives in.
pin "$WRITER_MD" 'by their declared `target_repo`' \
  "writer findings group by the declared target_repo key"
absent "$WRITER_MD" 'each file lives in' \
  "the by-file-location grouping is gone"
pin "$NESTED_MD" 'one writer per affected hosting repo' \
  "fix-now findings spanning repos get a writer each"
absent "$PRBRIEFS_MD" 'per spine at most' \
  "the close-dispatch cap contradiction is gone"
pin "$BRIEFS_MD" 'as MECHANICS'"'"'s Teardown says' \
  "the spine brief releases its seats as layers/herdr.md's Teardown says"
pin "$BRIEFS_MD" 'the layer'"'"'s Run workspace list showing none of them' \
  "the spine brief's teardown check is none of its own, not none at all"
# R7: the halt path and the completion bullet must name the report file, not
# the deleted declaration slots' phrase.
absent "$BRIEFS_MD" 'injected parent ids' \
  "the spine brief's halt path names no 'injected parent ids'"
absent "$NESTED_MD" 'injected parent ids' \
  "the nested run's halt path names no 'injected parent ids'"
absent "$NESTED_MD" 'the **injected parent**' \
  "the nested run's completion bullet no longer names the injected parent"
pin "$GENERIC_BRIEFS_MD" 'Reviewed head: <sha>' \
  "the reviewer DONE carries its reviewed-head line exactly once"

section "the nested run's mechanical values"

# Mechanical, not judgment: an exact file, an exact node kind and an exact
# number. The prose that carries them moved out of ossify-execution.md, so
# without these the split would leave them asserted nowhere.
pin "$NESTED_MD" 'recorded in `RUN_JSON`, never in your `run.json`' \
  "item bookkeeping lives in the spine session's own run.json"
# dagr keeps one run per file and links none to another: "nested" is the
# session hierarchy, never a dagr feature.
pin "$NESTED_MD" 'links no run to another' \
  "the nested run.json is a separate file, not a dagr link"
pin "$NESTED_MD" 'a gate node (`kind: gate`)' \
  "the round barrier is a gate node in the spine session's run.json"
pin "$NESTED_MD" 'must be `2`' \
  "the required worker depth is byte-exact"

section "no worker-to-orchestrator message type herdr lacks"

# herdr has no worker-to-orchestrator channel: a seat's plan, question,
# escalation and report all go in its report file. The message types of the
# runtime this plugin was ported from must not survive as instructions.
for f in "$EXEC_MD" "$NESTED_MD" "$BRIEFS_MD" "$PRBRIEFS_MD" "$WRITER_MD"; do
  for t in '`ask`' '`escalation`' '`send`' '`reply`'; do
    absent "$f" "$t" "${f##*/} names no $t message type"
  done
done

section "one mechanic, one statement"

# Every launch, send, wait, read and release is stated in layers/herdr.md
# and deferred to. Two names are sanctioned as deferrals: `herdr --skill`, the
# entry point, and `herdr workspace list`, the teardown check — neither of them
# here. Task 4 (crew 0.3.0, spec §4.4): the envelope's layer part is the `<PING_SEND>` slot,
# defined once in the layer's `Send`, so a brief file states NO layer command at all — the
# quality this block asserted while the ping line named `herdr agent prompt` is now the
# absence it always wanted. The adjacent control below proves the fence still flags one.
PING_CMD='herdr agent prompt <that pane>'
no_layer_command() { # <file>
  _a="$(count_of "$1" 'herdr agent ')" || return 1
  [ "$_a" -eq 0 ]
}
for f in "$EXEC_MD" "$NESTED_MD" "$BRIEFS_MD" "$PRBRIEFS_MD" "$WRITER_MD" "$GENERIC_BRIEFS_MD"; do
  for g in 'herdr pane ' 'herdr tab ' 'herdr worktree '; do
    absent "$f" "$g" "${f##*/} restates no '$g' command"
  done
done
for f in "$EXEC_MD" "$NESTED_MD" "$BRIEFS_MD" "$PRBRIEFS_MD" "$WRITER_MD" "$GENERIC_BRIEFS_MD"; do
  if no_layer_command "$f"; then pass "${f##*/} states no herdr-agent command"
  else fail "${f##*/} states no herdr-agent command" "an agent command is back"; fi
done
# Adjacent control: the fence admits the slot and flags the command it replaced.
ctl_extra="$(mktemp)"; ctl_ping="$(mktemp)"
printf '%s\n%s\n' "$PING_CMD" 'herdr agent wait w9:p1 --until idle' > "$ctl_extra"
printf '%s\n' "<PING_SEND> '[crew report implementer] <task id> <kind> <path>'" > "$ctl_ping"
if no_layer_command "$ctl_extra"; then fail "control: an agent command is still flagged" "accepted it"
else pass "control: an agent command is still flagged"; fi
if no_layer_command "$ctl_ping"; then pass "control: the ping slot alone is accepted"
else fail "control: the ping slot alone is accepted" "refused it"; fi
rm -f "$ctl_extra" "$ctl_ping"
# #574, the generic layer's half: briefs.md is where a brief-writer meets the doorbell, so
# it must name what the doorbell compares — the hash or the file's identity — while still
# deferring to layers/herdr.md for the rule. The mechanics file states it once (its own
# suite pins that); this pin holds the deferral, not a second statement.
pin "$GENERIC_BRIEFS_MD" 'doorbell compares that file'"'"'s hash or its identity (`completion.md`)' \
  "briefs.md names what the doorbell compares and still defers to completion.md (#574)"

section "the seats block is the freeze, not a file"

# R1-1. The value checks used to pass on an edited-but-still-valid row; now
# there is no file to re-read at all — the block in the brief is the whole
# authority, and a change moves only through the top's reply.
pin "$NESTED_MD" 'Every item launch spends its SEATS row verbatim' \
  "the injected seats block gates every item launch"
pin "$NESTED_MD" 'its reply carries the replacement rows' \
  "a seat change moves through the top's reply, not by re-reading"
pin "$NESTED_MD" 'never re-read the project file' \
  "the spine session does not re-open the project file mid-run"

section "the resolved profile is one contract, stated once"

# Round 2, findings 1-5: a resolved profile carries all five launch fields
# wherever it travels — config.md defines the row once and every carrier
# conforms rather than restating a field list that can drift. Task 13 adds the
# agent name, which a resumed top re-resolves a carried seat by, and the host,
# which is what stops a launcher that did not resolve the seat from putting it
# on its own machine by inference.
ROW='<agent name> | <command> | model: <expected model> | effort: <effort> | model_shows: <banner|screen> | brief_delivery: <inject|file> | host: <machine>'
pin "$CONFIG_MD" "$ROW" "config.md defines the resolved-profile row"
n_eq "$BRIEFS_MD" "$ROW" 2 "the SEATS rows carry the full resolved profile, name and host included"
n_eq "$PRBRIEFS_MD" "$ROW" 2 "the work-PR launched profiles carry the full resolved profile, name and host included"
# Any profile carrier anywhere is complete — no partial rows, and no partial
# enumerations either: prose listing "command, expected model …" without the
# delivery fields is the same defect in a sentence, and since Task 13 a row
# without its `host: ` is partial too: the row is the only place a launcher that
# did not resolve the seat learns which machine it runs on. The sweep runs over
# every shipped surface and the evals, so a seventh site cannot land. The list is
# unconditional: an unmatched fixture glob stays literal and fails the readability
# guard below, rather than being skipped for a directory that has not arrived.
CARRIERS=("$REF"/*.md "$SKILL_MD" "$COMMAND_MD" "$PLUGIN_README_MD"
          "$EVAL_DIR"/fixtures/ossify-spine-execution/*.md "$EVAL_RUBRIC_MD")
for f in "${CARRIERS[@]}"; do
  if [ ! -r "$f" ]; then fail "no partial profile carrier in ${f##*/}" "missing or unreadable: $f"; continue; fi
  n=$(awk 'index($0, "| model:") > 0 && (index($0, "brief_delivery") == 0 || index($0, "host: ") == 0)' "$f" | wc -l | tr -d ' ')
  m=$(awk 'index($0, "command, expected model") + index($0, "expected model and effort") > 0 && index($0, "brief-delivery") + index($0, "brief_delivery") == 0' "$f" | wc -l | tr -d ' ')
  if [ "$n" -eq 0 ] && [ "$m" -eq 0 ]; then pass "no partial profile carrier in ${f##*/}"
  else fail "no partial profile carrier in ${f##*/}" "$n partial row(s) (delivery or host missing), $m partial enumeration(s)"; fi
done
# The handoff persists the coordinator profiles beside the item rows — a
# resumed top launches them all without a fresh read.
pin "$EXEC_MD" 'resolved coordinator profiles' \
  "the handoff persists the coordinator profiles beside the item rows"
pin "$LIFECYCLE_MD" 'resolved coordinator' \
  "lifecycle's handoff persists the coordinator profiles"

section "a seat's machine and name travel with its row (Task 13)"

# The key ships with its first user, the demo walk, and every surface that carries a
# resolved profile across a session carries the host and the agent name with it: the
# spine's SEATS rows and the work-PR rows (the ROW pins above), a handoff's carried
# seats, and the close brief's demo-walk row. The consumer is where the value matters:
# the launcher that did not resolve the seat starts it on the machine the row names,
# and the name is what a resumed top re-resolves a carried seat by.
pin "$EXEC_MD" 'each item row and each of the three resolved coordinator profiles beside its agent'"'"'s name' \
  "the handoff carries each seat beside its agent's name" flat
pin "$EXEC_MD" 'with the machine its `host:` names' \
  "the handoff carries each seat's machine" flat
pin "$EXEC_MD" 're-resolves that seat by its carried name' \
  "a carried row that cannot give its machine is re-resolved by the carried name" flat
pin "$EXEC_MD" 'a carried name that file does not define halts and is asked' \
  "an undefined carried name halts rather than being guessed at"
pin "$ROLES_MD" 'runs every step above on that machine' \
  "roles.md runs a host seat's launch on its machine" flat
pin "$ROLES_MD" 'A seat with no `host:` runs here' \
  "a seat with no host runs here"
pin "$MECHANICS_MD" 'with one of these labels' \
  "herdr's Machines maps the host value to its own labels" flat
pin "$MECHANICS_MD" 'this layer names no route that reads it' \
  "herdr states that the cross-machine report read is not stated for it"
pin "$ORCA_MD" 'a seat'"'"'s `host:` value is one of those names' \
  "orca's Machines says a host value is a name its list answers with"
pin "$ORCA_MD" 'is read where it is written' \
  "orca's Machines says where a remote seat's report file is read"
pin "$ORCA_MD" "needs the operator's own allow for that host in their harness settings" \
  "the ssh read names the operator allow it depends on" flat
pin "$ORCA_MD" 'a refused read halts the dispatch with one question to the operator' \
  "a refused read halts with one question, never a silent wait" flat

section "the demo walk runs on the machine its row names (Task 13)"

pin "$PRBRIEFS_MD" 'DEMO_WALK=' \
  "the close brief injects the demo-walk row exactly once"
pin "$PRBRIEFS_MD" 'for <the `user:` entry ids it walks>' \
  "the slot binds the row to the entry ids it walks"
pin "$PRBRIEFS_MD" 'runs on the machine its row'"'"'s `host:` names' \
  "a bound entry runs on the machine its row names"
pin "$PRBRIEFS_MD" 'marked `verifier` before its command (the layer'"'"'s `Seat marking`)' \
  "the walk seat is marked a guarded verifier before its command" flat
pin "$PRBRIEFS_MD" 'wait on it through the layer'"'"'s Wait' \
  "the close waits on the walk seat through the layer"
pin "$PRBRIEFS_MD" 'read its report where it was written' \
  "the close reads the walk report where it was written"
pin "$PRBRIEFS_MD" 'release the seat' \
  "the walk seat is released once its report is read"
pin "$PRBRIEFS_MD" 'One seat per entry, from that row only' \
  "the exception is narrow: one seat per entry, from that row only"
pin "$EXEC_MD" 'creating any seat but the demo-walk seat a `user:` entry its `DEMO_WALK` names needs — one per entry' \
  "the close's own row states the seat-creation exception, one demo-walk seat per entry"
pin "$PRBRIEFS_MD" 'one demo-walk seat per `user:` entry its `DEMO_WALK` names' \
  "the close's NEVER states the same exception, one demo-walk seat per entry"

section "the demo walk is a whole contract (Task 13)"

pin "$GENERIC_BRIEFS_MD" '## Demo walk' \
  "briefs.md ships the demo-walk template"
pin "$GENERIC_BRIEFS_MD" 'DEMO ENTRY' \
  "the walk template carries the entry verbatim"
pin "$GENERIC_BRIEFS_MD" 'fail: <what did not match>' \
  "the walk returns pass or a named failure"
pin "$GENERIC_BRIEFS_MD" 'write outside the walk' \
  "the walk's NEVER bounds what it writes"
pin "$GENERIC_BRIEFS_MD" '| Close session | the demo walk |' \
  "the dispatch matrix carries the demo-walk body to the close"
pin "$GENERIC_BRIEFS_MD" 'Ten dispatched templates live in this file' \
  "the template count is ten"
# The walk's template carries no handoff line — the one template without one (the walk is
# bounded; spec §4.5: molt is not required for one, and its NEVER has no handoff
# exception). Scoped to the section, so the other templates' lines neither satisfy nor
# break the check; the control below refuses to read a section that did not extract.
tmpl="$(mktemp)"
awk '/^## Demo walk/ { seen = 1 } seen && /^## / && !/^## Demo walk/ { exit } seen { print }' "$GENERIC_BRIEFS_MD" > "$tmpl"
nonempty "$tmpl" "the demo-walk section extracts (control for the check below)"
m_lines="$(awk '/^MOLT:/ { t++ } END { print t+0 }' "$tmpl")"
if [ "$m_lines" -eq 0 ]; then pass "the demo-walk template carries no MOLT line"
else fail "the demo-walk template carries no MOLT line" "$m_lines line(s)"; fi
rm -f "$tmpl"
# can: is a per-role approval check, not a reviewer-only one.
pin "$CONFIG_MD" 'a role whose shipped or declared brief invokes a slash command' \
  "the can: requirement is per role, checked at approval"
n_eq "$CONFIG_MD" '/ossify:run-spine' 3 \
  "the capability table names the spine session's command"
# The effort cell names a seat choice, never a runtime override.
pin "$ROLES_MD" 'the machine entry is the only source of effort' \
  "a marked item is a seat choice, not a command edit"
# The close-review writer is a halt-time profile, not a project-file seat.
pin "$CONFIG_MD" 'close session, work-PR session)' \
  "the writer is not a project-file seat"
# All three missing-file states are stated, not inferred.
pin "$CONFIG_MD" 'Machine file only' "the machine-only state is stated"
pin "$CONFIG_MD" 'Project file only' "the project-only state is stated"

# Round 3, finding 2: a machine-entry field list that names the
# launch-transport fields must name the launch fields too — a partial
# enumeration is the same defect as a partial row.
for f in "${CARRIERS[@]}"; do
  if [ ! -r "$f" ]; then fail "no partial field-name enumeration in ${f##*/}" "missing or unreadable: $f"; continue; fi
  l=$(awk 'index($0, "| model:") > 0 { next }
      { c = (index($0,"command")>0) + (index($0,"expected_model")>0) + (index($0,"effort")>0) + (index($0,"model_shows")>0) + (index($0,"brief_delivery")>0)
        if (c >= 3 && c < 5) print }' "$f" | wc -l | tr -d ' ')
  if [ "$l" -eq 0 ]; then pass "no partial field-name enumeration in ${f##*/}"
  else fail "no partial field-name enumeration in ${f##*/}" "$l line(s) name some launch fields but not all"; fi
done

section "declared roles, capabilities, dispatched commands"

# Round 4 cut: declared roles fire on the top's own paths only — the carry
# mechanism is deferred to issue #500, and the limit is stated where the
# declarer reads it. A return of the mechanism must not silently skip the
# delegated paths again.
pin "$LIFECYCLE_MD" 'not yet carried into a delegated spine or work-PR session' \
  "lifecycle states declared roles do not fire inside delegated sessions"
pin "$LIFECYCLE_MD" 'issue #500' \
  "the limit names the issue holding the work"
absent "$BRIEFS_MD" 'OPERATOR_ROLES' \
  "the spine brief carries no delegated-role slot"
absent "$PRBRIEFS_MD" 'OPERATOR_ROLES' \
  "the work-PR brief carries no delegated-role slot"
absent "$EXEC_MD" 'OPERATOR_ROLES' \
  "the top injects no declared role blocks"

# Round 3, finding 3: the approval check covers every capability a role's
# shipped brief needs — the default run-spine lane spawns subagents.
n_eq "$CONFIG_MD" 'subagents' 5 \
  "the can: vocabulary covers the default lane's Agent tool"
pin "$CONFIG_MD" 'spine session, default lane' \
  "the capability table names the default lane's need"
pin "$CONFIG_MD" 'spine session, external-executor lane' \
  "the capability table names the external lane's need"

# Round 3, finding 4: every dispatched command resolves to a role the project
# file can fill — doctor gets its own seat.
n_eq "$CONFIG_MD" 'doctor session' 3 \
  "doctor session is a project-file role and in the capability table"
pin "$ROLES_MD" 'A `doctor session` — one fresh tab and pane' \
  "the seat budget grants a doctor session" flat
# Next-instance gate: every command SKILL.md lists as dispatched to a herdr
# session must name its `/ossify:` invocation in config.md — a dispatched
# command with no role to fill is the same defect. An anchor that no longer
# matches, or a list that parses to nothing, would pass with nothing checked,
# so both are failures here.
#
# Three pieces, each with its own control below, because this extractor's failure
# mode is a RED that names the wrong fault (#514, L5).
# The bullet's own lines, up to the ITEM's end — following markdown's rule rather than
# stopping at the first line that looks like a break. A blank line ends the item only when
# the next non-blank line is not indented (an indented continuation paragraph is the same
# item), a heading ends the section, and a sibling LIST ITEM at column 0 ends the item.
#
# Two rules are CommonMark's and are not approximations of it, because each was a P1 on its own:
# a heading is the ATX form (0-3 spaces, then 1-6 `#`, then a blank, a tab or the end of the
# line) and never a line inside a fenced code block (#602 F1), and a list item is any bullet
# (`-`, `*`, `+`) or any ordered marker (`N.`, `N)`, 1-9 digits, then a blank, a tab or the end
# of the line), read the same way by the carve AND by the block below, because a marker this
# missed let a dispatched command through in silence (#602 F2). The fence gate comes FIRST in
# every loop that walks lines — the carve, the scan that picks the block's first line, and the
# block scan itself — so a fenced line is read by that check alone and no classifier below it can
# be reached with one: not a heading, not a list item, not a blank line, not an indented
# continuation and not the column-0 line that ends a block (#602 F9). Gating the classifiers one
# at a time is what left the blank test ABOVE the gate, and a blank line inside a code sample
# then ended the item and dropped the command after it with rc 0 (#602 F13): the ordering is the
# rule, not another predicate. `heading_at` and `list_item_at` keep their own gate as well, for
# the lines the loops do not walk — the `j + 1` lookahead of both blank branches, and `follow` in
# the refusal test.
#
# A carve that stops while a backticked token still sits after the span, in a position the
# carve cannot certify as outside this bullet, REFUSES: rc 1, with a message naming the carve,
# the file and the line it refused on. TWO concepts decide it, one rule each:
#
#   the BLOCK after the span — the first non-blank line after it, plus the lines that still
#   belong to the same markdown block: a list run continues across a blank line (a loose
#   list) and over indented continuations, and a paragraph continues over indented lines but
#   ends at a blank one. A heading ends the block, and so does a column-0 line that is neither
#   a list item nor an indented continuation.
#
#   the PREDICATE — the block's lines JOINED to one text (the join commands_in_span performs)
#   carrying a backticked PAIR. Joining is what makes a token the wrap splits still one token:
#   a per-line test missed the second half of `- `gamma-` / `  three`, dispatched…` and let a
#   command in a later item of the same list through (#602 review round 1, finding 3).
#
# The block is exempt when a heading ends the span, or when the block's first line IS a heading:
# a heading is where the document says a section ends, whether or not a blank line came first
# (#602 review round 1, finding 2). Two bounds are measured rather than implied. The BLOCK's
# end: a list item after an intervening column-0 prose line is outside it only when a BLANK line
# separates them — a list item directly under prose is still part of the block and its command is
# still refused, which is the conservative direction — and reading past column-0 prose would
# refuse the shipped file, whose own later bullets name `run-spine`, `/ossify:close <spine-id>`
# and `references/…`. C11 pins the blank-separated case. The PREDICATE's: a lone unpaired
# backtick in the block is not a token and does not refuse (C14); the balance gate is where an
# unpaired backtick inside the SPAN is caught.
#
# THE MARKDOWN SHAPES THIS CARVE CERTIFIES, each one pinned by a control in this file rather than
# asserted here in prose alone:
#
#   a blank line ends the item unless the next non-blank line is indented       C4
#   a sibling list item ends it, in every CommonMark marker (`- * +`, `N. N)`)  C20, C22
#   an ATX heading ends the section, 0-3 spaces in, and is exempt there         C8, C12, C15, C16
#   `#597 backlog note` and `####### seven` are not headings                    C17
#   fenced code is no structure at all — not a heading, not a list item         C18, C19, C24
#   a blank line INSIDE fenced code ends nothing, in the carve or the block     C28, C30, C33, C34
#   a list item directly under prose is in the block; a blank line fixes that   C23, C11, C23b
#   the block's JOINED text decides the refusal                                 C13, C14
#
# OUTSIDE THAT MODEL, named here rather than modelled, both deferred to #603: an HTML comment
# (`<!--`, `# not a heading`, `-->`) stops the block scan at its `#`-shaped line, and a list item
# directly under a MULTI-LINE prose paragraph is not read, because the scan breaks on the second
# consecutive prose line. Measured on this tree, both come back rc 0 with the command in the list
# under them never checked — the same silent shape, in constructs this carve does not model. They
# are the class #603 exists for, and this round states them and changes neither.
span_of() { # <file> <start-line>
  awk -v s="$2" '
    # An ATX heading by CommonMark: up to three leading spaces, then one to six `#`, then a
    # blank, a tab or the end of the line. `#597 backlog note` and `####### seven` are neither
    # of them headings, and treating them as ones ended the span and exempted what followed
    # (#602 F1).
    function is_heading(s,   k, h, c) {
      k = 0
      while (k < 3 && substr(s, k + 1, 1) == " ") k++
      h = 0
      while (substr(s, k + h + 1, 1) == "#") h++
      if (h < 1 || h > 6) return 0
      c = substr(s, k + h + 1, 1)
      return c == "" || c == " " || c == "\t"
    }
    # The fence a line opens with — three or more backticks or tildes, up to three spaces in —
    # or "" for a line that opens none.
    function fence_marker(s,   k, c, n, r) {
      k = 0
      while (k < 3 && substr(s, k + 1, 1) == " ") k++
      c = substr(s, k + 1, 1)
      if (c != "`" && c != "~") return ""
      n = 0
      while (substr(s, k + n + 1, 1) == c) n++
      if (n < 3) return ""
      r = ""
      while (n-- > 0) r = r c
      return r
    }
    # A list item marker at column 0: `-`, `*` or `+`, or 1-9 digits then `.` or `)`, each
    # followed by a blank, a tab or the end of the line. `2.NoSpace` is not a marker (#602 F2).
    function is_list_item(s,   c, n, d) {
      c = substr(s, 1, 1)
      if (c == "-" || c == "*" || c == "+") {
        d = substr(s, 2, 1)
        return d == "" || d == " " || d == "\t"
      }
      n = 0
      while (n < 9 && substr(s, n + 1, 1) ~ /[0-9]/) n++
      if (n == 0) return 0
      c = substr(s, n + 1, 1)
      if (c != "." && c != ")") return 0
      d = substr(s, n + 2, 1)
      return d == "" || d == " " || d == "\t"
    }
    function heading_at(i) { return !fenced[i] && is_heading(line[i]) }
    # A list item, by the same rule and with the same fence gate: a `- ` line INSIDE fenced code
    # is code, not Markdown structure, so it neither ends the carve nor extends the block. The
    # gate belongs on every predicate that classifies a line — the round-1 fix gated the heading
    # test and left this one open, which is exactly the defect #602 F9 names.
    function list_item_at(i) { return !fenced[i] && is_list_item(line[i]) }
    { line[NR] = $0
      # Fenced code first, over the whole file: a line between a fence and its close is code,
      # and code is never a heading. The close is a fence of the same character, at least as
      # long as the opener, with nothing but blanks after it; an unclosed fence runs to the end
      # of the file, which is what CommonMark does too.
      if (in_fence == 0) {
        f = fence_marker($0)
        if (f != "") { in_fence = 1; fence_char = substr(f, 1, 1); fence_len = length(f); fenced[NR] = 1 }
      } else {
        k = 0
        while (k < 3 && substr($0, k + 1, 1) == " ") k++
        n = 0
        while (substr($0, k + n + 1, 1) == fence_char) n++
        if (n >= fence_len && substr($0, k + n + 1) ~ /^[[:space:]]*$/) in_fence = 0
        fenced[NR] = 1
      }
    }
    END {
      if (s < 1 || s > NR) {
        printf "span_of refuses: %s has no line %d to carve from — no span, and an empty span certifies nothing\n", FILENAME, s
        exit 1
      }
      end_at = NR; stopped_at_heading = 0
      for (i = s + 1; i <= NR; i++) {
        # FIRST, in every loop that walks lines: a fenced line is handled by this check ALONE.
        # Here it is absorbed into the span and no classifier below it ever sees the line — which
        # is the point, because gating the classifiers one at a time left the blank test ungated
        # and a blank line inside a code sample ended the item (#602 F13).
        if (fenced[i]) continue
        if (heading_at(i)) { end_at = i - 1; stopped_at_heading = 1; break }
        if (line[i] ~ /^[[:space:]]*$/) {
          j = i
          while (j < NR && line[j + 1] ~ /^[[:space:]]*$/) j++
          if (j < NR && !heading_at(j + 1) && line[j + 1] ~ /^[[:space:]]/) { i = j; continue }
          end_at = i - 1; break
        }
        if (list_item_at(i)) { end_at = i - 1; break }
      }
      follow = 0
      # The first line of the block is its first non-blank, NON-FENCED line: a fence there is
      # code like any other fenced line, and taking it for the start of the block hid the line
      # behind it — measured, a blank between the fence and the bullet then left the bullet and
      # its command unread (#602 F13).
      for (i = end_at + 1; i <= NR; i++) if (!fenced[i] && line[i] !~ /^[[:space:]]*$/) { follow = i; break }
      region_end = 0
      if (follow > 0) {
        region_end = follow
        in_run = list_item_at(follow)
        for (i = follow + 1; i <= NR; i++) {
          # FIRST here too: a fenced line neither ends the block nor joins it, and no classifier
          # below — the blank test, the heading, the list item, the indent, the column-0 prose
          # break — runs on it. The blank test was above this check until #602 F13, and a blank
          # line inside a code sample ended the block.
          if (fenced[i]) continue
          if (line[i] ~ /^[[:space:]]*$/) {
            if (!in_run) break                       # a paragraph ends at a blank line; a list does not
            j = i
            while (j < NR && line[j + 1] ~ /^[[:space:]]*$/) j++
            if (j < NR && (list_item_at(j + 1) || line[j + 1] ~ /^[[:space:]]/)) { i = j; region_end = j; continue }
            break
          }
          if (heading_at(i)) break                   # a heading ends the section
          if (list_item_at(i) || line[i] ~ /^[[:space:]]/) { region_end = i; continue }
          break                                      # column-0 prose ends the block
        }
      }
      text = ""
      # Fenced lines contribute NO text either: the backticks a fence is made of are code, and
      # letting them into the joined text would make the predicate fire on the fence instead of
      # on a command (#602 F9, the second half of the gate).
      for (i = follow; i <= region_end; i++) if (!fenced[i]) text = text " " line[i]
      if (!stopped_at_heading && region_end > 0 && !heading_at(follow) && text ~ /`[^`]*`/) {
        printf "span_of refuses: the bullet at %s:%d ends at line %d, and the block after it (from line %d) carries a backticked token — the carve cannot tell whether that command belongs to this bullet, so it stops here rather than certify the commands before the break\n", FILENAME, s, end_at, follow
        exit 1
      }
      for (i = s; i <= end_at; i++) print line[i]
    }' "$1"
}
# One backticked command per line. The span is joined to ONE line first, so a
# token the wrap splits is still one token, then each `…` pair is matched whole by
# a single grep -o. The spelling this replaces converted newlines to spaces,
# converted the backtick to newlines, kept only the EVEN-numbered fields and
# stripped spaces and commas — an even-field assumption that one unpaired
# backtick flips for every token after it. `tr -d '` ,'` reproduces the old token
# shape: a token holding a space or a comma had them removed.
commands_in_span() { # the span arrives on stdin
  tr '\n' ' ' | grep -o '`[^`]*`' | tr -d '` ,'
}
# The span's backtick count must be EVEN, and an odd one is refused with the count
# rather than parsed. Measured: the live span is even (10). An odd count is ONE way
# to produce a misleading RED — every token after the stray backtick pairs wrongly,
# so prose fragments reach the config.md check and the per-command failures name a
# fault that is not there. It is the way this gate covers, not the only way a span
# can mislead: `span_of`'s own carve can drop a command with the check still green,
# and that is decided by the carve's own controls below — C4 to C8 — where the carve
# captures a continuation and refuses a break it cannot certify.
# `grep -o` alone does NOT remove the odd case: on a fixture with one unpaired
# backtick, measured, both spellings lose the real tokens and both feed a prose
# fragment to the check. The balance gate is what turns that into a RED naming the
# actual defect.
span_balanced() { # the span arrives on stdin
  _ticks="$(tr -cd '`' | wc -c | tr -d ' ')"
  [ $((_ticks % 2)) -eq 0 ] || { printf '%s' "$_ticks"; return 1; }
  return 0
}
start=$(awk '/Dispatched to a seat session/{print NR; exit}' "$SKILL_MD")
missing=0
parsed=0
span=""
if [ -z "$start" ]; then
  fail "SKILL.md's dispatched-command list is found" "no line reads 'Dispatched to a seat session'"
elif ! span="$(span_of "$SKILL_MD" "$start")"; then
  # The carve refused, and its message names the carve, the file and both line numbers.
  # Nothing below runs: the per-command check would otherwise certify the commands before
  # the break, which is the silent truncation the refusal exists to prevent.
  fail "SKILL.md's dispatched-command bullet is carved whole" "$span"
  span=""
elif [ -z "$span" ]; then
  fail "SKILL.md's dispatched-command bullet is carved whole" \
    "span_of returned nothing for the anchor at line $start — an empty span certifies no command"
elif ! ticks="$(printf '%s\n' "$span" | span_balanced)"; then
  fail "SKILL.md's dispatched-command span is a balanced list" \
    "$ticks backticks — an unpaired one flips every token after it, so the per-command failures below would name the wrong fault"
else
  for cmd in $(printf '%s\n' "$span" | commands_in_span); do
    [ -n "$cmd" ] || continue
    parsed=$((parsed+1))
    if [ "$(occurrences "$CONFIG_MD" "/ossify:$cmd")" -eq 0 ]; then
      missing=$((missing+1)); fail "dispatched command '$cmd' resolves to a role" "no /ossify:$cmd in config.md"
    fi
  done
  if [ "$parsed" -eq 0 ]; then fail "SKILL.md's dispatched-command list parses" "no backticked command after the anchor"
  elif [ "$missing" -eq 0 ]; then pass "every dispatched command resolves to a role in config.md ($parsed)"; fi
fi

# ── the extractor's controls ────────────────────────────────────────────────
#
# Synthetic spans, shaped like the shipped bullet — a bold lead-in, comma-separated
# backticked commands, a trailing sentence — so each control decides the extractor
# and never the shipped list's content (a literal freeze of that list would fail on
# the next legitimate command). They are fed straight to the extractor as span text,
# so the controls below decide the token extraction and the balance gate.
#
# What they do NOT decide is `span_of`'s own carve — a command on a line the carve takes
# for the break used to be dropped with the check still green — so the carve has controls
# of its own below: C4 the continuation a blank line does not end, and C5/C6 the two ways a
# command can sit after the carve's break, which the carve must REFUSE rather than certify
# around. C7 and C8 are their adjacent controls: the two shapes that must NOT be refused,
# because a carve that refused everything would satisfy C5 and C6 just as well. Those
# controls are what #597 asked for; the carve was fixed with them.
# Every expected value below is a literal, not something the code under test wrote.

# C1 — the wrap. A token the line wrap splits is recovered WHOLE, and its halves
# are not emitted as commands of their own. What this pins is the JOIN — without it no
# backtick pair spans the break. It does not pin the join's SEPARATOR, because nothing
# downstream can see one: measured, a separator-less join (`tr -d '\n'` in place of
# `tr '\n' ' '`) leaves this control GREEN, the extractor's last stage deleting every
# space a token holds, the wrap's included. Remove the join stage instead and this
# control goes RED by TOTAL LOSS — measured, the fixture then emits ONE EMPTY TOKEN
# (the single pair that still forms, on the second line) and neither half arrives: not
# as a token of its own, not at all.
ctl_wrap='- **Dispatched to a seat session:** `alpha-
  one`, `beta-two`.'
c1="$(printf '%s\n' "$ctl_wrap" | commands_in_span | tr '\n' '|')"
if [ "$c1" = 'alpha-one|beta-two|' ]; then
  pass "control: a command split by the line wrap is recovered whole"
else
  fail "control: a command split by the line wrap is recovered whole" \
    "emitted [$c1], expected [alpha-one|beta-two|] — a lost or split token, not a wrap-joined one"
fi

# C2 — the even-field assumption. With ONE unpaired backtick in the span, every
# token the extractor feeds the config.md check must be the content of a backtick
# PAIR of that span. The old spelling additionally emits the sentence's trailing
# `.`, which lies outside every pair, and that prose fragment is what the
# per-command RED then names. The pair contents are computed here by walking the
# span's own backticks — not by re-running the extractor — so the expectation comes
# from the fixture rather than from the code under test. This is deliberately NOT a
# claim that the real tokens survive an unpaired backtick: measured, they do not, and
# no pairing-based extractor can recover them (the balance gate above is for that).
ctl_unpaired='- **Dispatched to a herdr `session:**
  `alpha-one`, `beta-two`.'
ctl_joined="$(printf '%s\n' "$ctl_unpaired" | tr '\n' ' ')"
ctl_pairs="$(printf '%s' "$ctl_joined" | awk '{
  s = $0
  while ((i = index(s, "`")) > 0) {
    rest = substr(s, i + 1); j = index(rest, "`")
    if (j == 0) break
    body = substr(rest, 1, j - 1); gsub(/[ ,]/, "", body)
    if (body != "") print body
    s = substr(rest, j + 1)
  }
}')"
c2_n="$(printf '%s\n' "$ctl_unpaired" | commands_in_span | awk '{ if ($0 == "") next; n++ } END { print n+0 }')"
c2_outside="$(printf '%s\n' "$ctl_unpaired" | commands_in_span | awk -v pairs="$ctl_pairs" '
  { if ($0 == "") next
    m = split(pairs, p, "\n"); found = 0
    for (i = 1; i <= m; i++) if (p[i] == $0) { found = 1; break }
    if (!found) bad++ }
  END { print bad+0 }')"
if [ "$c2_n" -eq 0 ]; then
  fail "control: an unpaired backtick feeds no prose from outside a pair" \
    "the fixture emitted nothing at all — a control over an empty list certifies nothing"
elif [ "$c2_outside" -eq 0 ]; then
  pass "control: an unpaired backtick feeds no prose from outside a pair ($c2_n emitted, each one a pair's content)"
else
  fail "control: an unpaired backtick feeds no prose from outside a pair" \
    "$c2_outside of $c2_n emitted tokens are not the content of any backtick pair in the span"
fi

# C3 — the balance gate itself. The fixture half must FIRE; the live half is the
# adjacent control, because a gate that refused every span would satisfy the first
# half alone and would make the shipping check above vacuous.
if ticks="$(printf '%s\n' "$ctl_unpaired" | span_balanced)"; then
  fail "control: the balance gate refuses an unpaired backtick" \
    "it passed a span whose backtick count is odd"
else
  pass "control: the balance gate refuses an unpaired backtick ($ticks backticks)"
fi
# The live half reads the span the shipping check bound. When the anchor is missing
# there is no span, and that must FAIL here rather than pass over empty input: the
# suite is red above for the missing anchor, and this keeps the second RED honest
# about what it is measuring.
span="${span:-}"
if [ -z "$span" ]; then
  fail "control: the balance gate does not refuse the live span" \
    "there is no live span to check — the anchor line is missing, so this control would otherwise pass over empty input"
elif printf '%s\n' "$span" | span_balanced; then
  pass "control: the balance gate does not refuse the live span"
else
  fail "control: the balance gate does not refuse the live span" \
    "the shipped span measures unbalanced — the gate is refusing a valid state, and the check above would be skipped"
fi

# ── the carve's own controls (#597) ─────────────────────────────────────────
#
# `span_of` decides which lines the check above even looks at, so a carve that stops early
# certifies the commands before the break and reports the list green. Each fixture below is
# a synthetic bullet in the shipped shape, written to a file because the carve reads a file;
# the expectations are literals, never something the carve wrote.
ctl_carve="$(mktemp -d)"

# C4 — a continuation paragraph after a blank line is the SAME bullet in markdown, so the
# command in it is captured. Measured before this change: the carve stopped at the blank line
# and emitted `alpha-one` and `beta-two` only, with rc 0 — the command below it was never
# checked and the shipping check stayed green.
printf -- '- **Dispatched to a seat session:** `alpha-one`, `beta-two`.\n\n  `gamma-three` is also dispatched to a herdr session.\n' \
  > "$ctl_carve/continuation.md"
if c4_span="$(span_of "$ctl_carve/continuation.md" 1)"; then
  c4="$(printf '%s\n' "$c4_span" | commands_in_span | tr '\n' '|')"
  if [ "$c4" = 'alpha-one|beta-two|gamma-three|' ]; then
    pass "control: a command in an indented continuation paragraph is captured"
  else
    fail "control: a command in an indented continuation paragraph is captured" \
      "emitted [$c4], expected [alpha-one|beta-two|gamma-three|] — the carve truncated the bullet"
  fi
else
  fail "control: a command in an indented continuation paragraph is captured" \
    "the carve refused a continuation it has to capture: $c4_span"
fi

# C5 and C6 — the two ways a command can sit after the carve's break. Neither can be
# captured: the first is a command in a new paragraph the bullet does not indent, the second
# one in a SIBLING bullet, which is a different item — and folding the rest of the section
# into the span would feed this file's own later prose and file paths to the per-command
# check (measured: SKILL.md's section names `/ossify:close <spine-id>`, `references/…` and
# `commit …; push; open the PR` after the span). So the carve REFUSES, and what the control
# decides is that the refusal names the carve rather than returning a quiet rc 0.
printf -- '- **Dispatched to a seat session:** `alpha-one`, `beta-two`.\n\n`gamma-three` is also dispatched to a herdr session.\n' \
  > "$ctl_carve/after-blank.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`, `beta-two`.\n- `gamma-three`, dispatched to a herdr session.\n' \
  > "$ctl_carve/sibling-bullet.md"
for c5_fixture in after-blank sibling-bullet; do
  case "$c5_fixture" in
    after-blank)      c5_label="a command after a blank line" ;;
    sibling-bullet)   c5_label="a command in a sibling bullet" ;;
  esac
  if c5_out="$(span_of "$ctl_carve/$c5_fixture.md" 1)"; then
    fail "control: the carve refuses $c5_label it cannot certify" \
      "it returned [$c5_out] with rc 0 — the command after the break is dropped in silence"
  elif printf '%s' "$c5_out" | grep -F 'span_of refuses' >/dev/null &&
       printf '%s' "$c5_out" | grep -F 'the carve cannot tell' >/dev/null; then
    pass "control: the carve refuses $c5_label it cannot certify"
  else
    fail "control: the carve refuses $c5_label it cannot certify" \
      "it refused, but not with a message naming the carve and the line: [$c5_out]"
  fi
done

# C7 and C8 — the adjacent controls, the two shapes that must NOT be refused. C5/C6 alone
# would be satisfied by a carve that refused every span, so the same call has to come back
# with a span here. C8 is the heading rule: this fixture's heading line carries the backtick
# that would otherwise refuse it, and the control asserts that fixture property itself, so it
# cannot pass by accident on a heading that carries none.
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n- Runs in this session instead.\n' \
  > "$ctl_carve/sibling-plain.md"
if c7_span="$(span_of "$ctl_carve/sibling-plain.md" 1)" &&
   [ "$(printf '%s\n' "$c7_span" | commands_in_span | tr '\n' '|')" = 'alpha-one|' ]; then
  pass "control: a sibling bullet that carries no command does not refuse the span"
else
  fail "control: a sibling bullet that carries no command does not refuse the span" \
    "got [$c7_span] — a carve that refuses every bullet after the anchor cannot be told from one that refuses only the ones carrying a command"
fi
ctl_carve_heading='- **Dispatched to a seat session:** `alpha-one`.
## `Refusals`
- `herdr status` fails: say so and stop.'
printf '%s\n' "$ctl_carve_heading" > "$ctl_carve/heading-break.md"
if ! printf '%s\n' "$ctl_carve_heading" | awk 'NR == 2 { exit !index($0, "`") }'; then
  fail "control: a span whose end a heading caused is not refused" \
    "the fixture's heading line carries no backtick — this control would pass without deciding the heading rule"
elif c8_span="$(span_of "$ctl_carve/heading-break.md" 1)"; then
  pass "control: a span whose end a heading caused is not refused"
else
  fail "control: a span whose end a heading caused is not refused" "$c8_span"
fi

rm -rf "$ctl_carve"
if [ ! -e "$ctl_carve" ]; then
  pass "control: the carve controls leave no fixture behind"
else
  fail "control: the carve controls leave no fixture behind" \
    "$ctl_carve survived its cleanup — a fixture was not removed"
fi

# C9 and C10 — the bullet RUN, from #602's review round 1 finding 2. C5/C6 decided the first
# line after the break; measured before this change, a command in a LATER item of the same
# list came back rc 0 with only the anchor, so it was never checked. C9 is that case and C10
# is its adjacent control, because a carve that refused every bullet run would satisfy C9
# alone and would refuse the shipped file the day its bullet grows a sibling.
ctl_run="$(mktemp -d)"
printf -- '- **Dispatched to a seat session:** `alpha-one`.
- Runs in this session instead.
- `gamma-three`, dispatched to a herdr session.
' > "$ctl_run/run-with-command.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.
- Runs in this session instead.
- Another item of this list, carrying no command.
' > "$ctl_run/run-plain.md"
if c9_span="$(span_of "$ctl_run/run-with-command.md" 1)"; then
  fail "control: the carve refuses a command in a later item of the same bullet run" \
    "rc 0 with [$c9_span] — the later item's command is dropped in silence"
elif printf '%s' "$c9_span" | grep -F 'span_of refuses' >/dev/null; then
  pass "control: the carve refuses a command in a later item of the same bullet run"
else
  fail "control: the carve refuses a command in a later item of the same bullet run" "$c9_span"
fi
if c10_span="$(span_of "$ctl_run/run-plain.md" 1)" &&
   [ "$(printf '%s\n' "$c10_span" | commands_in_span | tr '\n' '|')" = 'alpha-one|' ]; then
  pass "control: a bullet run that carries no command does not refuse the span"
else
  fail "control: a bullet run that carries no command does not refuse the span" \
    "got [$c10_span] — refusing every run cannot be told from refusing the ones that carry a command"
fi
# C11 — the BOUND, pinned rather than implied: a command in a bullet after an intervening
# column-0 prose line is NOT refused, because reading past that prose is what would refuse the
# shipped file (measured: its own later bullets name `run-spine`, `/ossify:close <spine-id>`
# and `references/…`). If a later change widens the carve past prose, this control goes RED
# and the bound in span_of's comment has to move with it, deliberately.
printf -- '- **Dispatched to a seat session:** `alpha-one`.

These cases are named because they look like clashes and are not:

- `gamma-four`, dispatched to a herdr session.
' > "$ctl_run/prose-then-bullet.md"
if c11_span="$(span_of "$ctl_run/prose-then-bullet.md" 1)" &&
   [ "$(printf '%s\n' "$c11_span" | commands_in_span | tr '\n' '|')" = 'alpha-one|' ]; then
  pass "control: the carve's bound holds — a bullet after column-0 prose is not read"
else
  fail "control: the carve's bound holds — a bullet after column-0 prose is not read" \
    "got [$c11_span] — the shipped file's own section has this shape, so reading past it refuses the live span"
fi
rm -rf "$ctl_run"
if [ ! -e "$ctl_run" ]; then
  pass "control: the bullet-run controls leave no fixture behind"
else
  fail "control: the bullet-run controls leave no fixture behind" \
    "$ctl_run survived its cleanup — a fixture was not removed"
fi

# C12–C14 — review round 1's findings 2 and 3 on the refusal's reach, and the predicate's own
# bound. C12: a heading exempts the block whether or not a blank line came first (its heading
# line carries the backtick that would otherwise refuse it, and the control asserts that
# fixture property itself). Measured before this change: rc 1, the heading refused — a FALSE
# refusal, so C12 is a loosening, and C5 is its adjacent control: a command line after a blank
# line, which is not a heading and must still refuse. C13: a token the WRAP splits, in a later
# item of the run, is still a token — measured before this change, only a per-line pair was
# seen, so the command came back rc 0 with the anchor alone. C14: a lone unpaired backtick in
# the block is not a token (C9 is its adjacent control: a pair on one line still refuses).
ctl_block="$(mktemp -d)"
printf -- '- **Dispatched to a seat session:** `alpha-one`.

## `Refusals`
- `herdr status` fails: say so and stop.
' > "$ctl_block/blank-then-heading.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.
- Runs in this session instead.
- `gamma-
  three`, dispatched to a herdr session.
' > "$ctl_block/wrapped-in-run.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.
- Runs in this session instead.
- A stray ` backtick opens no pair.
' > "$ctl_block/lone-backtick.md"
if ! printf -- '- **Dispatched to a seat session:** `alpha-one`.

## `Refusals`
- `herdr status` fails: say so and stop.
' | awk 'NR == 3 { exit !index($0, "`") }'; then
  fail "control: a heading exempts the block across a blank line" \
    "the fixture's heading line carries no backtick — this control would pass without deciding the rule"
elif c12_span="$(span_of "$ctl_block/blank-then-heading.md" 1)" &&
     [ "$(printf '%s\n' "$c12_span" | commands_in_span | tr '\n' '|')" = 'alpha-one|' ]; then
  pass "control: a heading exempts the block across a blank line"
else
  fail "control: a heading exempts the block across a blank line" \
    "got [$c12_span] — a heading is where the section ends, blank line or not"
fi
if c13_span="$(span_of "$ctl_block/wrapped-in-run.md" 1)"; then
  fail "control: the carve refuses a token the wrap splits in a later item" \
    "rc 0 with [$c13_span] — a per-line test sees half a token and certifies the list"
elif printf '%s' "$c13_span" | grep -F 'span_of refuses' >/dev/null; then
  pass "control: the carve refuses a token the wrap splits in a later item"
else
  fail "control: the carve refuses a token the wrap splits in a later item" "$c13_span"
fi
if c14_span="$(span_of "$ctl_block/lone-backtick.md" 1)" &&
   [ "$(printf '%s\n' "$c14_span" | commands_in_span | tr '\n' '|')" = 'alpha-one|' ]; then
  pass "control: a lone unpaired backtick in the block is not a token"
else
  fail "control: a lone unpaired backtick in the block is not a token" \
    "got [$c14_span] — the predicate is a backticked PAIR; the span's balance gate owns unpaired ticks"
fi
rm -rf "$ctl_block"
if [ ! -e "$ctl_block" ]; then
  pass "control: the block controls leave no fixture behind"
else
  fail "control: the block controls leave no fixture behind" \
    "$ctl_block survived its cleanup — a fixture was not removed"
fi

# C15 — an INDENTED heading, from #602 review round 2 finding 4. An ATX heading may carry up to
# three leading spaces, and this one ends the section like any other: measured before the fix,
# the carve read `   ## `Refusals`` as an indented continuation, swallowed the next section, and
# refused on its first bullet — a false refusal of a valid document. C12 is the adjacent
# control (a column-0 heading after a blank line, which must stay exempt).
ctl_indent="$(mktemp -d)"
printf -- '- **Dispatched to a seat session:** `alpha-one`.

   ## `Refusals`
- `herdr status` fails: say so and stop.
' > "$ctl_indent/indented-heading.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.

    ## `Refusals`
' > "$ctl_indent/four-space-line.md"
if c15_span="$(span_of "$ctl_indent/indented-heading.md" 1)" &&
   [ "$(printf '%s\n' "$c15_span" | commands_in_span | tr '\n' '|')" = 'alpha-one|' ]; then
  pass "control: an indented heading ends the section, so the span stops at the anchor"
else
  fail "control: an indented heading ends the section, so the span stops at the anchor" \
    "got [$c15_span] — the span swallowed the next section and its tokens read as commands"
fi
# The adjacent control for the indentation rule: four spaces is NOT a heading (markdown's own
# limit), so this line is item content and the carve keeps it. Without this, widening the heading
# test to any indent would pass the control above and swallow indented content.
if c16_span="$(span_of "$ctl_indent/four-space-line.md" 1)" &&
   [ "$(printf '%s\n' "$c16_span" | commands_in_span | tr '\n' '|')" = 'alpha-one|Refusals|' ]; then
  pass "control: four leading spaces is not a heading, so the line stays in the span"
else
  fail "control: four leading spaces is not a heading, so the line stays in the span" \
    "got [$c16_span] — markdown's three-space limit is part of the rule, not an implementation detail"
fi
rm -rf "$ctl_indent"
if [ ! -e "$ctl_indent" ]; then
  pass "control: the heading controls leave no fixture behind"
else
  fail "control: the heading controls leave no fixture behind" \
    "$ctl_indent survived its cleanup — a fixture was not removed"
fi

# C17–C19 — #602 F1: the heading test is CommonMark's ATX rule and nothing looser. Measured on
# faa3dd3, each of these pseudo-headings ended the span and EXEMPTED the block, so the command
# under it was dropped with rc 0 — the silent direction the refusal exists to close. C8 and C12
# are the adjacent controls: a real ATX heading still ends the span and is still exempt.
ctl_atx="$(mktemp -d)"
printf -- '- **Dispatched to a seat session:** `alpha-one`.

#597 backlog note, and `gamma-three` is dispatched to a herdr session.
' > "$ctl_atx/hash-then-digit.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.

####### seven hashes, and `gamma-three` is dispatched to a herdr session.
' > "$ctl_atx/seven-hashes.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.

  ```
  # init is code here
  ```
  `gamma-three`, dispatched to a herdr session.
' > "$ctl_atx/fenced-init.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.

  ~~~
  # init is code here
  ~~~
  `gamma-three`, dispatched to a herdr session.
' > "$ctl_atx/fenced-init-tilde.md"
for c17 in hash-then-digit seven-hashes; do
  if c17_out="$(span_of "$ctl_atx/$c17.md" 1)"; then
    fail "control: a pseudo-heading does not exempt the block ($c17)" \
      "rc 0 with [$c17_out] — the command under it is dropped and never checked"
  elif printf '%s' "$c17_out" | grep -F 'span_of refuses' >/dev/null; then
    pass "control: a pseudo-heading does not exempt the block ($c17)"
  else
    fail "control: a pseudo-heading does not exempt the block ($c17)" "$c17_out"
  fi
done
# The backtick fence is asserted by CONTAINMENT, not by tokens: the fence itself is three
# backticks inside the span, and the tokenizer pairs them like any other pair, which is the
# extractor's own property and not this carve's. The tilde fence has no backticks, so there the
# token list is the whole assertion.
if c18_span="$(span_of "$ctl_atx/fenced-init.md" 1)" &&
   printf '%s\n' "$c18_span" | grep -F 'gamma-three' >/dev/null; then
  pass "control: a # line inside a backtick-fenced block is not a heading, so the span keeps going"
else
  fail "control: a # line inside a backtick-fenced block is not a heading, so the span keeps going" \
    "got [$c18_span] — a fenced line ended the span early and the command after the fence was lost"
fi
if c19_span="$(span_of "$ctl_atx/fenced-init-tilde.md" 1)" &&
   [ "$(printf '%s\n' "$c19_span" | commands_in_span | tr '\n' '|')" = 'alpha-one|gamma-three|' ]; then
  pass "control: the same fence rule holds for a tilde fence"
else
  fail "control: the same fence rule holds for a tilde fence" \
    "got [$c19_span] — the fence character is not the deciding factor"
fi
rm -rf "$ctl_atx"
if [ ! -e "$ctl_atx" ]; then
  pass "control: the ATX controls leave no fixture behind"
else
  fail "control: the ATX controls leave no fixture behind" \
    "$ctl_atx survived its cleanup — a fixture was not removed"
fi

# C20–C22 — #602 F2: every CommonMark list marker ends the carve and extends the block, in both
# places `span_of` reads one. Measured on faa3dd3, and the two shapes differed: the four RUN
# fixtures below (ordered `1.`, its `1)`, `*` and `+`) came back rc 0 with only the anchor, so the
# command in the second item was never checked, while the `*` SIBLING fixture came back rc 0 with
# the item swallowed INTO the span instead — two lines, over-capture rather than a drop, and still
# not a refusal. C22 is the adjacent control: a column-0 line that merely starts with digits and a
# dot is NOT a marker, so a rule that dropped the blank/tab/end-of-line requirement would refuse a
# document that is not ambiguous.
ctl_marker="$(mktemp -d)"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n1. ordinary item\n2. `gamma-three`, dispatched to a herdr session.\n' > "$ctl_marker/ordered-dot.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n1) ordinary item\n2) `gamma-three`, dispatched to a herdr session.\n' > "$ctl_marker/ordered-paren.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n* ordinary item\n* `gamma-three`, dispatched to a herdr session.\n' > "$ctl_marker/star.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n+ ordinary item\n+ `gamma-three`, dispatched to a herdr session.\n' > "$ctl_marker/plus.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n* `gamma-three`, dispatched to a herdr session.\n' > "$ctl_marker/star-sibling.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n1. ordinary item\n2.NoSpace `gamma-three`, dispatched to a herdr session.\n' > "$ctl_marker/no-space-after-dot.md"
for c20 in ordered-dot ordered-paren star plus star-sibling; do
  if c20_out="$(span_of "$ctl_marker/$c20.md" 1)"; then
    fail "control: every list marker is read as one ($c20)" \
      "rc 0 with [$c20_out] — the second item's command is dropped and never checked"
  elif printf '%s' "$c20_out" | grep -F 'span_of refuses' >/dev/null; then
    pass "control: every list marker is read as one ($c20)"
  else
    fail "control: every list marker is read as one ($c20)" "$c20_out"
  fi
done
if c22_span="$(span_of "$ctl_marker/no-space-after-dot.md" 1)" &&
   [ "$(printf '%s\n' "$c22_span" | commands_in_span | tr '\n' '|')" = 'alpha-one|' ]; then
  pass "control: digits and a dot without a blank after it are not a list marker"
else
  fail "control: digits and a dot without a blank after it are not a list marker" \
    "got [$c22_span] — the marker rule needs its blank, a tab or the end of the line"
fi
rm -rf "$ctl_marker"
if [ ! -e "$ctl_marker" ]; then
  pass "control: the marker controls leave no fixture behind"
else
  fail "control: the marker controls leave no fixture behind" \
    "$ctl_marker survived its cleanup — a fixture was not removed"
fi

# C23 — the behaviour half of the sentence #602 F8 corrected, pinned as behaviour rather than
# left in prose: a list item DIRECTLY under a column-0 prose line is still part of the block, so
# its command is refused. C11 is the adjacent control for the other side: with a BLANK line
# between the prose and the item the block has ended and the span is certified, which is the
# shape the shipped file has.
ctl_prose="$(mktemp -d)"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\nProse line with no backticks.\n- `gamma-three`, dispatched to a herdr session.\n'   > "$ctl_prose/direct.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\nProse line with no backticks.\n\n- `gamma-three`, dispatched to a herdr session.\n' > "$ctl_prose/blank-separated.md"
if c23_out="$(span_of "$ctl_prose/direct.md" 1)"; then
  fail "control: a list item directly under prose is still in the block" \
    "rc 0 with [$c23_out] — reading it as outside the block would certify the list without it"
elif printf '%s' "$c23_out" | grep -F 'span_of refuses' >/dev/null; then
  pass "control: a list item directly under prose is still in the block"
else
  fail "control: a list item directly under prose is still in the block" "$c23_out"
fi
if c23b_span="$(span_of "$ctl_prose/blank-separated.md" 1)" &&
   [ "$(printf '%s\n' "$c23b_span" | commands_in_span | tr '\n' '|')" = 'alpha-one|' ]; then
  pass "control: a blank line between the prose and a list item ends the block"
else
  fail "control: a blank line between the prose and a list item ends the block" \
    "got [$c23b_span] — a blank line is what the shipped file has, and it must not refuse"
fi
rm -rf "$ctl_prose"
if [ ! -e "$ctl_prose" ]; then
  pass "control: the prose controls leave no fixture behind"
else
  fail "control: the prose controls leave no fixture behind" \
    "$ctl_prose survived its cleanup — a fixture was not removed"
fi

# C24 — #602 F9: a line inside fenced code is never Markdown structure, so it is not a heading,
# not a list item and not the column-0 line that ends a block. Measured on 411997c, where only
# the heading test carried the fence gate: the `- code bullet` INSIDE the fence ended the carve,
# the span came back two lines long, and `gamma-three` under the fence was never checked against
# config.md. C25 is the adjacent control, the same fixture with a code line that is not list
# shaped, whose verdict must not move.
ctl_fence="$(mktemp -d)"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n```\n- code bullet\n```\n`gamma-three`, dispatched to a herdr session.\n' > "$ctl_fence/fence-list-under-anchor.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n```\nx code bullet\n```\n`gamma-three`, dispatched to a herdr session.\n' > "$ctl_fence/fence-plain-under-anchor.md"
c24_out="$(span_of "$ctl_fence/fence-list-under-anchor.md" 1)" && c24_rc=0 || c24_rc=$?
if [ "$c24_rc" -ne 0 ] || printf '%s\n' "$c24_out" | grep -F 'gamma-three' >/dev/null; then
  pass "control: a list-shaped line inside a fence does not end the carve, so the command after it is checked"
else
  fail "control: a list-shaped line inside a fence does not end the carve, so the command after it is checked" \
    "rc 0 with [$c24_out] — the span ends inside the fence and gamma-three is never checked"
fi
c25_out="$(span_of "$ctl_fence/fence-plain-under-anchor.md" 1)" && c25_rc=0 || c25_rc=$?
if [ "$c25_rc" -eq 0 ] && printf '%s\n' "$c25_out" | grep -F 'gamma-three' >/dev/null; then
  pass "control: the same fixture with a non-list code line keeps its verdict"
else
  fail "control: the same fixture with a non-list code line keeps its verdict" \
    "rc=$c25_rc, out=[$c25_out] — the fence gate must not change a verdict it was not aimed at"
fi
rm -rf "$ctl_fence"
if [ ! -e "$ctl_fence" ]; then
  pass "control: the fence-gate controls leave no fixture behind"
else
  fail "control: the fence-gate controls leave no fixture behind" \
    "$ctl_fence survived its cleanup — a fixture was not removed"
fi

# C26 and C27 — the second half of F9, in the BLOCK scan. Fenced lines are skipped there rather
# than ending the block, and they contribute no text to the predicate either: a fence is code, and
# the backticks it is made of are not a command. Measured on 411997c and on the first cut of this
# fix, both fixture below REFUSED for that wrong reason — the predicate paired the fence own
# backticks — so C27 is the control for the exclusion and C26 is its adjacent pair: with the
# exclusion, the item that carries a command still refuses and the one that carries none does not.
ctl_fenceblock="$(mktemp -d)"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n```\nx code\n```\n- `gamma-three`, dispatched to a herdr session.\n' > "$ctl_fenceblock/fence-then-bullet.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n```\nx code\n```\n- an item carrying no command\n' > "$ctl_fenceblock/fence-then-plain.md"
if c26_out="$(span_of "$ctl_fenceblock/fence-then-bullet.md" 1)"; then
  fail "control: a bullet after a fence is still read as the block's own" \
    "rc 0 with [$c26_out] — the fence hid the item and its command went unchecked"
elif printf '%s' "$c26_out" | grep -F 'span_of refuses' >/dev/null; then
  pass "control: a bullet after a fence is still read as the block's own"
else
  fail "control: a bullet after a fence is still read as the block's own" "$c26_out"
fi
if c27_span="$(span_of "$ctl_fenceblock/fence-then-plain.md" 1)"; then
  pass "control: a fence in the block contributes no text, so an item with no command does not refuse"
else
  fail "control: a fence in the block contributes no text, so an item with no command does not refuse" \
    "refused: [$c27_span] — the backticks the fence is made of were read as a backticked token"
fi
rm -rf "$ctl_fenceblock"
if [ ! -e "$ctl_fenceblock" ]; then
  pass "control: the block-fence controls leave no fixture behind"
else
  fail "control: the block-fence controls leave no fixture behind" \
    "$ctl_fenceblock survived its cleanup — a fixture was not removed"
fi

# C28–C34 — #602 F13: the blank-line predicate was the one classifier still ungated, because
# two rounds of gating the classifiers one at a time never moved the gate. The fix is the ORDER:
# the fence check comes first in every loop in `span_of` that walks lines — the carve, the scan
# that picks the block's first line, and the block scan itself — so a blank line inside a fenced
# code sample is handled by that check alone and no classifier below it ever reads the line.
# Measured on 2d9c389 before the fix: a fence holding a blank line dropped the dispatched command
# after it with rc 0, in paragraph mode (the `!in_run` break) and in list-run mode (the blank
# branch's lookahead, on a non-indented fence), and the carve stopped inside the fence on an item
# whose continuation carried the command — a false refusal. The paragraph and list-run fixtures
# each differ from their refusing control only by the fenced blank, C26's shape.
#
# C28 is the paragraph fixture: measured on 2d9c389, rc 0 with a one-line span and `gamma-three`
# never read. C29 is its adjacent control — the same fixture without the fenced blank, which
# refused there and must keep refusing: the fenced blank is the whole difference between them, so
# the verdict cannot be read as following the fence instead of the blank line above the gate.
ctl_f13="$(mktemp -d)"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n```\n\n```\n- `gamma-three`, dispatched to a herdr session.\n' > "$ctl_f13/fence-blank-para.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n```\n```\n- `gamma-three`, dispatched to a herdr session.\n' > "$ctl_f13/fence-noblank-para.md"
if c28_out="$(span_of "$ctl_f13/fence-blank-para.md" 1)"; then
  fail "control: a blank line inside a fence does not end the block (paragraph)" \
    "rc 0 with [$c28_out] — the fence hid the bullet after it and its command went unchecked"
elif printf '%s' "$c28_out" | grep -F 'span_of refuses' >/dev/null; then
  pass "control: a blank line inside a fence does not end the block (paragraph)"
else
  fail "control: a blank line inside a fence does not end the block (paragraph)" "$c28_out"
fi
if c29_out="$(span_of "$ctl_f13/fence-noblank-para.md" 1)"; then
  fail "control: the paragraph fixture without the fenced blank still refuses" \
    "rc 0 with [$c29_out] — the blank line is what the verdict must not hang on"
elif printf '%s' "$c29_out" | grep -F 'span_of refuses' >/dev/null; then
  pass "control: the paragraph fixture without the fenced blank still refuses"
else
  fail "control: the paragraph fixture without the fenced blank still refuses" "$c29_out"
fi

# C30–C32 decide the list-run half, where the fence sits INSIDE the scanned block rather than in
# front of it. C30 measured on 2d9c389: rc 0 with a one-line span and `delta-nine` never read.
# C31 is the same run with no command after the fence, and it is what keeps the fence's own
# backticks out of the joined text with the fence inside the scanned range — C27's property one
# position along: measured, letting fenced lines into the text refuses it. C32 is C30's adjacent
# control without the fenced blank.
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n- an item carrying no command\n```\n\n```\n- `delta-nine`, dispatched to a herdr session.\n' > "$ctl_f13/fence-blank-run.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n- an item carrying no command\n```\n\n```\n- an item carrying no command either\n' > "$ctl_f13/fence-blank-run-plain.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n- an item carrying no command\n```\n```\n- `delta-nine`, dispatched to a herdr session.\n' > "$ctl_f13/fence-noblank-run.md"
if c30_out="$(span_of "$ctl_f13/fence-blank-run.md" 1)"; then
  fail "control: a blank line inside a fence does not end the block (list run)" \
    "rc 0 with [$c30_out] — the fence hid the item after it and its command went unchecked"
elif printf '%s' "$c30_out" | grep -F 'span_of refuses' >/dev/null; then
  pass "control: a blank line inside a fence does not end the block (list run)"
else
  fail "control: a blank line inside a fence does not end the block (list run)" "$c30_out"
fi
if c31_span="$(span_of "$ctl_f13/fence-blank-run-plain.md" 1)"; then
  pass "control: a fence inside the scanned block contributes no text, so an item with no command does not refuse"
else
  fail "control: a fence inside the scanned block contributes no text, so an item with no command does not refuse" \
    "refused: [$c31_span] — the backticks the fence is made of were read as a backticked token"
fi
if c32_out="$(span_of "$ctl_f13/fence-noblank-run.md" 1)"; then
  fail "control: the list-run fixture without the fenced blank still refuses" \
    "rc 0 with [$c32_out] — the blank line is what the verdict must not hang on"
elif printf '%s' "$c32_out" | grep -F 'span_of refuses' >/dev/null; then
  pass "control: the list-run fixture without the fenced blank still refuses"
else
  fail "control: the list-run fixture without the fenced blank still refuses" "$c32_out"
fi

# C33 and C34 pin the fix's other two loops, which the same finding names and which neither the
# paragraph nor the list-run fixture reaches. C33 is the CARVE: a fenced blank, then an indented
# continuation of the item carrying the command. Measured on 2d9c389, where the carve loop had no
# gate at all: rc 1, a false refusal of a valid document — the carve stopped at the fence, and the
# item's own continuation was then read as the block after it. Measured after the fix: rc 0 with
# `gamma-three` inside the span, which is the command the document dispatches.
# C34 is the scan that picks the block's FIRST line: the paragraph fixture with a BLANK between
# the fence and the command bullet. Measured on 2d9c389: rc 0 with the command never read, the
# same silent shape by the other route.
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n```\n\n```\n   `gamma-three`, dispatched to a herdr session.\n' > "$ctl_f13/fence-blank-carve.md"
printf -- '- **Dispatched to a seat session:** `alpha-one`.\n\n```\n\n```\n\n- `gamma-three`, dispatched to a herdr session.\n' > "$ctl_f13/fence-blank-separated.md"
c33_out="$(span_of "$ctl_f13/fence-blank-carve.md" 1)" && c33_rc=0 || c33_rc=$?
if [ "$c33_rc" -eq 0 ] && printf '%s\n' "$c33_out" | grep -F 'gamma-three' >/dev/null; then
  pass "control: a fenced blank does not end the carve, so an indented continuation keeps its command"
else
  fail "control: a fenced blank does not end the carve, so an indented continuation keeps its command" \
    "rc=$c33_rc, out=[$c33_out] — the carve stopped inside the fence and read the item's own continuation as the block after it"
fi
if c34_out="$(span_of "$ctl_f13/fence-blank-separated.md" 1)"; then
  fail "control: a blank line between the fence and the bullet does not hide the bullet's command" \
    "rc 0 with [$c34_out] — the scan took the fence for the block's first line and the command after it went unchecked"
elif printf '%s' "$c34_out" | grep -F 'span_of refuses' >/dev/null; then
  pass "control: a blank line between the fence and the bullet does not hide the bullet's command"
else
  fail "control: a blank line between the fence and the bullet does not hide the bullet's command" "$c34_out"
fi
rm -rf "$ctl_f13"
if [ ! -e "$ctl_f13" ]; then
  pass "control: the fenced-blank controls leave no fixture behind"
else
  fail "control: the fenced-blank controls leave no fixture behind" \
    "$ctl_f13 survived its cleanup — a fixture was not removed"
fi

section "the handoff carries the approved seats"

# R2-1/R2-3, re-expressed: the child is never the source of its own seats — the
# top approves them and injects them; the handoff persists them so a resumed top
# launches from what was approved, not from a fresh read of an edited file.
pin "$EXEC_MD" 'carries the approved seats verbatim' \
  "a top handoff persists the approved seats"
pin "$EXEC_MD" 'asks the operator before any launch that spends an approved seat' \
  "a resumed top without the seats asks before spending one"
# PR #470 row 2: the handoff is the carrier — lifecycle's step 13 lists the
# approved seats and the accumulated close-review ledger on an activated spine,
# and the ask's subject is the resumed top, not the handoff.
pin "$LIFECYCLE_MD" 'the spine'"'"'s approved `SEATS` block' \
  "the top's handoff lists the approved seats block"
pin "$LIFECYCLE_MD" 'close-review ledger' \
  "the top's handoff lists the accumulated close-review ledger"
pin "$EXEC_MD" 'A resumed top whose handoff lacks them asks the operator' \
  "the resumed top, not the handoff, asks before spending a seat"

section "the first verifier failure blocks and asks"

# D25. Mechanical, not judgment: an exact option SET, an exact ORDER (release
# before create), and the absence of the silent path this replaces.
pin "$NESTED_MD" 'correct with the same pair, replace the pair, halt' \
  "the first-failure ask carries exactly its three options"
pin "$NESTED_MD" 'blocks: the pair idles' \
  "the ask blocks; nothing on that item runs until the reply"
pin "$NESTED_MD" 'the old pair is released first' \
  "a replacement releases before it creates"
pin "$NESTED_MD" 'never two pairs live on one item' \
  "one pair per item survives the replacement exception"
pin "$NESTED_MD" 'the top relays the approved row' \
  "a replacement at a different seat goes back through the operator"
# The obvious needle here, 'A second failure escalates to you', spans a line wrap
# in the prose it is meant to forbid, so it would have passed while the sentence
# was still there. Pinned to the contiguous half instead, which counts 1 today.
absent "$NESTED_MD" 'A second failure escalates' \
  "the silent first correction and second-failure escalation are gone"

# R1-3. A fresh pair cannot adopt a staged tree: the ordinary entry point's
# pre-flight requires an empty porcelain, and the correction packet is
# same-executor by construction. So *replace* resets and restarts.
pin "$NESTED_MD" 'the rejected staged work is discarded' \
  "a replacement discards the staged work rather than adopting it"
pin "$NESTED_MD" 'The correction packet is for' \
  "the correction packet is scoped to the correct branch of the ask"

section "halt is a terminal state, and the cap ends in halt only"

# R2-8/R2-12. The third option had no behaviour, and the cap counts executions.
pin "$NESTED_MD" 'halt-shaped report' \
  "a halted item returns a halt-shaped report in the spine session's report file"
pin "$BRIEFS_MD" 'halt-shaped report' \
  "the spine brief carries the same halt return"
pin "$NESTED_MD" 'the ask offers halt only' \
  "an exhausted cap leaves one option"
pin "$BRIEFS_MD" 'the ask offers halt only' \
  "the spine brief carries the exhausted-cap rule"

section "the PR lane runs the review before the command that consumes it"

# R1-2/R1-4/R1-7/R1-10. Order, the second model confirmation, the close's third
# result shape, and the full signal set a disposition covers.
pin "$PRBRIEFS_MD" 'carrying those findings in as its disposition inputs' \
  "the reviewer runs before work-pr, whose disposition takes its findings"
pin "$PRBRIEFS_MD" 'its model as the row'"'"'s `model_shows` says and by the worker'"'"'s own check' \
  "the PR-fix seat's ratified model is spent, not merely injected"
pin "$PRBRIEFS_MD" 'halted: <step>' \
  "the close brief has a third result shape for a halt before any PR opens"
pin "$PRBRIEFS_MD" 'review bodies and top-level PR comments' \
  "a disposition covers all three finding sources, not the bot threads alone"

# R2-2/R2-7. The reviewer body is the sole copy of its findings, and a pushed head
# invalidates the verdict that preceded it.
# R3-1. briefs.md's fix-round brief swaps its TASK for /ossify:work-pr when ossify is
# installed; inside a work-PR session that recurses into a second merge loop.
pin "$PRBRIEFS_MD" 'without the ossify replacement clause' \
  "the PR-fix seat gets the fix-round brief with the recursion removed"
pin "$PRBRIEFS_MD" 'fixed in <sha>' \
  "the fix seat returns per-finding evidence, not a merge"
pin "$GENERIC_BRIEFS_MD" 'except inside a work-PR session' \
  "the replacement clause excludes the seat that would recurse"

# R3-3. work-pr's loop can end at wait or leave-open; DONE could only carry a merge.
pin "$PRBRIEFS_MD" 'open: <PR url> at <head sha>' \
  "an unmerged outcome has a result shape and settles the dispatch"

pin "$PRBRIEFS_MD" 'ONE bounded correction request' \
  "a malformed reviewer body is corrected once, then escalated"
# R3-2 reverts to exactly-once: the reviewer template and lifecycle step 8 forbid a
# second review, so a compliant reviewer would refuse. Staleness is answered by
# re-fetching GitHub's own signals, which the bots regenerate on every push.
pin "$PRBRIEFS_MD" 'released after its report file validates' \
  "the delegated review runs once and its seat is released"
pin "$PRBRIEFS_MD" 're-fetch the GitHub review signals' \
  "each new head is covered by re-fetching the signals, not by a second review"
# N8/#467: the work-PR session's seats get the #455 teardown — release what it
# created as layers/herdr.md's Teardown says, then prove the list shows none
# of it. The list is named byte-identical to that file's confirmation.
pin "$PRBRIEFS_MD" 'as MECHANICS'"'"'s Teardown says' \
  "the work-PR session releases its seats as layers/herdr.md's Teardown says"
pin "$PRBRIEFS_MD" 'the layer'"'"'s Run workspace list' \
  "the work-PR session verifies what it created is gone"
pin "$MECHANICS_MD" 'Confirm what closed with `herdr workspace list`' \
  "the confirming list is layers/herdr.md's own"
# PR #470 row 4 (settles ledger row 9): the list always shows the top's
# workspaces as well as this session's — the check is none OF THEM, never none
# at all.
pin "$PRBRIEFS_MD" 'the layer'"'"'s Run workspace list showing none of them' \
  "the teardown check is none of the session's own, not none at all"
# PR #470 row 5: the budget ate the close seat's question target — restore it.
pin "$PRBRIEFS_MD" 'questions go up to the top in your report file' \
  "the close seat's questions still route to the top"
absent "$PRBRIEFS_MD" 'review a head twice' \
  "the per-head review that contradicted the reviewer template is gone"

# R2-4/R2-5/R2-9/R2-11. The close seat: partial halts, the ceremony own review,
# the ledger the record pass needs, and the route out of a halt.
pin "$PRBRIEFS_MD" 'opened: none' \
  "a halt names the PRs already opened, even when there are none"
pin "$PRBRIEFS_MD" 'the close review the ceremony itself runs' \
  "the ceremony's own review is the seat's work, not a /code-review"
absent "$PRBRIEFS_MD" 'run a review or a fix' \
  "the NEVER no longer forbids the ceremony its own review"
pin "$PRBRIEFS_MD" 'CLOSE_REVIEW_LEDGER=' \
  "the record pass receives the close-review ledger exactly once"
# R1/R15: the halt rule reconciles with ossify's advisory-review prose instead
# of contradicting it. N6/#467: the ledger slot is cumulative — every close
# review's ledger for the spine, oldest first, verbatim — so a clean retry
# drops nothing an earlier review accepted.
pin "$PRBRIEFS_MD" 'ossify keeps that review advisory' \
  "the halt rule names its relation to the ceremony's advisory review"
pin "$PRBRIEFS_MD" 'oldest first' \
  "the ledger slot accumulates every close review's ledger, oldest first"
absent "$PRBRIEFS_MD" 'the most recent close' \
  "the newest-only ledger choice is gone"
# N4/#467: a close-review ledger row names the repo its finding lands in, so a
# multi-repo close splits fix-now findings into per-writer ledgers cleanly.
pin "$PRBRIEFS_MD" 'carrying each finding, its `target_repo`' \
  "the halted close-review ledger names each finding's target_repo"
pin "$PRBRIEFS_MD" 'naming each finding, its `target_repo`' \
  "the verbatim ledger carry names each finding's target_repo"
pin "$NESTED_MD" 'the accepted findings whose `target_repo` is that repo' \
  "a writer's ledger slice is the findings landing in its repo"
# R5: the close DONE's PR-list rule carries the product-hosting-repo
# qualifier (RF7), not the bare phrase every other site had to disambiguate.
absent "$PRBRIEFS_MD" 'one line per hosting repo' \
  "the close DONE counts product hosting repos only"
pin "$PRBRIEFS_MD" 'the top dispatches a fresh close session' \
  "a halt settles the dispatch; the top re-dispatches after remediation"
absent "$PRBRIEFS_MD" 're-invoke close after a halt' \
  "the dead-end NEVER clause is gone"
pin "$NESTED_MD" 'a complete PR list or `closed`' \
  "nothing downstream starts on a partial close"
pin "$NESTED_MD" 'one SUCCESSFUL record pass' \
  "single means one that succeeded, not one attempt"
# #466: the AI-workspace record arm claims no "record branch" — the close writes
# its records where ossify resolves `ai_workspace`, and that repo's own policy
# governs them outside the returned PR list.
pin "$NESTED_MD" 'where ossify resolves `ai_workspace`' \
  "workspace records land where ossify resolves ai_workspace"
absent "$NESTED_MD" 'record branch' \
  "the never-established record-branch claim is gone"
# PR #470 row 1: the eval oracle tracks the same #466 contract — records are
# written where ossify resolves ai_workspace, never a "record branch" no step
# establishes. The rubric wraps the old claim across a line, so its pin is the
# contiguous tail of the old wording. A missing fixture or rubric fails here.
nonempty "$EVAL_FIXTURE14" "eval fixture 14 exists"
pin "$EVAL_FIXTURE14" 'where ossify resolves ai_workspace' \
  "fixture 14's oracle lands records where ossify resolves ai_workspace"
absent "$EVAL_FIXTURE14" 'record branch' \
  "fixture 14's record-branch claim is gone"
nonempty "$EVAL_RUBRIC_MD" "the spine-execution rubric exists"
pin "$EVAL_RUBRIC_MD" 'where ossify resolves `ai_workspace`' \
  "rubric criterion 1 lands records where ossify resolves ai_workspace"
absent "$EVAL_RUBRIC_MD" 'branch under its own policy' \
  "rubric criterion 1's record-branch wording is gone"

section "four seats, one voice"

# D26. Mechanical: the close seat's freshness, the record pass's precondition,
# the exact work-pr invocation the brief injects, and the two names without which
# that invocation cannot be built.
pin "$NESTED_MD" 'always a fresh seat' \
  "the close session is a fresh seat, never the spine driver's"
pin "$NESTED_MD" 'once every returned PR has merged' \
  "the record pass waits for every returned PR"
absent "$NESTED_MD" 'retention threshold' \
  "the close no longer reuses the spine driver under retention"
pin "$PRBRIEFS_MD" 'REPO_ROOT=' \
  "the work-PR brief injects the repo root exactly once"
pin "$PRBRIEFS_MD" '/ossify:work-pr $PR_NUMBER --repo-root $REPO_ROOT' \
  "the work-PR brief names its invocation exactly once"
pin "$PRBRIEFS_MD" 'REVIEW_INVOCATION=<the reviewer'"'"'s agent'"'"'s `review:`, else `/code-review <PR> <LEVEL>`, with PR_NUMBER, the PR URL and the level the top decided filled in>' \
  "the work-PR brief injects the reviewer's filled review command"
pin "$PRBRIEFS_MD" 'brief it to run REVIEW_INVOCATION.' \
  "the work-PR session briefs the reviewer with the filled review command"
absent "$PRBRIEFS_MD" '/code-review PR_NUMBER' "the work-PR brief omits the retired /code-review PR_NUMBER spelling"
pin "$PRBRIEFS_MD" 'merge bound to the named SHA' \
  "the work-PR session merges bound to the SHA the top relayed"
pin "$PRBRIEFS_MD" 'never a squash or rebase' \
  "the operator merge path is bound to the merge-commit convention too"
# #963: a reviewing-a-pr report is the second accepted shape. The loosening has its
# adjacent control in each validator: a `Head:` off the PR head still fails.
pin "$GENERIC_BRIEFS_MD" 'When REVIEW_INVOCATION is `/merge-bar:review-pr`, your report file is instead that command'"'"'s report, whole' \
  "a merge-bar reviewer returns that command's report whole (#963)" flat
pin "$GENERIC_BRIEFS_MD" 'its `Head:` line is the reviewed head' \
  "a merge-bar report's Head: is its reviewed head (#963)" flat
pin "$PRBRIEFS_MD" 'a `/merge-bar:review-pr` report instead validates with its `## Coverage` table and a `Bar:` line on every `### C<n>` class, its `Head:` the reviewed head' \
  "the work-PR session accepts a reviewing-a-pr report (#963)" flat
pin "$PRBRIEFS_MD" 'A mismatched reviewed head makes the review historical, a `Head:` that is not the PR head included' \
  "control: a reviewing-a-pr report off the PR head is historical (#963)" flat
pin "$PRBRIEFS_MD" 'a class blocks unless its `Bar:` is `non-blocking`' \
  "the work-PR session reads blocking from each class's Bar: (#963)" flat
pin "$PRBRIEFS_MD" '`/merge-bar:review-pr <PR_URL> --round <n> --previous <previous report path>`' \
  "the fix-range re-review of a merge-bar reviewer is its round 2+ command (#963)" flat
pin "$PRBRIEFS_MD" 'a one-way door — the body'"'"'s `Door: one-way`, or no `Door:` line — is never merged here' \
  "the work-PR session never merges a one-way door (#963)" flat
pin "$PRBRIEFS_MD" 'skills/working-a-pr/references/one-way-door.md' \
  "a one-way door goes to the top with merge-bar's checklist (#963)" flat
pin "$LIFECYCLE_MD" 'or a `/merge-bar:review-pr` report with its `## Coverage` table and a `Bar:` line on every `### C<n>` class' \
  "step 8 accepts a reviewing-a-pr report (#963)" flat
pin "$LIFECYCLE_MD" 'with the reviewed head — that report'"'"'s `Head:` — equal to the PR head' \
  "control: step 8 holds a reviewing-a-pr report to the PR head (#963)" flat
# #965 round 1: a round 2+ class that closes a prior one does not block; a still-open
# one keeps its Bar. The one-way hand-off has a return shape and a receiver.
pin "$PRBRIEFS_MD" 'or it carries `Closes:`, and a `Still open:` class keeps its' \
  "the work-PR session reads a Closes: class as not blocking (#965)"
pin "$LIFECYCLE_MD" 'or it carries `Closes:`, and a `Still open:` class keeps its `Bar:`' \
  "step 8 reads a Closes: class as not blocking (#965)" flat
pin "$PRBRIEFS_MD" '`handed off: one-way <reviewed head OID>`, only for step 6'"'"'s' \
  "the work-PR session returns a one-way door as a hand-off (#965)"
pin "$LIFECYCLE_MD" 'under either word, `standing` included' \
  "step 12 runs one-way-door.md for a one-way door even under standing (#965)"
pin "$LIFECYCLE_MD" 'dispatch a work-PR session' \
  "1b dispatches a work-PR session per returned PR"
pin "$SKILL_MD" 'the spine'"'"'s seats in `.crew/roles.md`' \
  "SKILL.md's write set names the project file"
pin "$ROLES_MD" 'four seats' \
  "roles.md budgets four seats outside the per-item budget"
pin "$ROLES_MD" 'a close-review writer' \
  "the budget names the close-review writer seat"
pin "$ROLES_MD" 'the allowance the project file declares' \
  "the budget grants declared operator roles an explicit allowance"

# R-8. `replaces:` names one identifier set in both files — `implementer`,
# `verifier`, `reviewer` and no synonyms — and the named seat is suppressed, not
# run beside the operator's role.
pin "$CONFIG_MD" '`implementer`, `verifier`, `reviewer`' \
  "the replaces contract names its only valid targets in config.md"
pin "$LIFECYCLE_MD" '`implementer`, `verifier`, `reviewer`' \
  "the replaces contract names its only valid targets in lifecycle.md"
pin "$LIFECYCLE_MD" 'the named seat is not launched' \
  "a replaced built-in is suppressed, not run beside"

# R1-5/R1-6/R1-9. The record pass has a precondition a `closed` return fails; the
# spine seat is launched from its ratified block, not the generic policy; and the
# close is named in ossify's namespace everywhere.
pin "$LIFECYCLE_MD" 'a closed return skips the record pass' \
  "a close that recorded outright goes straight to teardown"
# R2-10. The teardown gate names a merged PR; a `closed` spine never had one.
pin "$LIFECYCLE_MD" 'closed spine has no PR to confirm' \
  "teardown after a closed return validates the local landing instead"
pin "$ROLES_MD" 'the `spine session` seat the project file names' \
  "roles.md launches the spine seat from the project file"
pin "$BRIEFS_MD" 'the `spine session` seat the project file names' \
  "the spine brief header launches from the project file"
absent "$NESTED_MD" '/close <' \
  "the close is always named /ossify:close, never a bare /close"

section "the record pass is conditional and single"

# D27 and the two brief clauses that ride with it (#438, #441).
pin "$NESTED_MD" 'only when the first returned at its open-PR halt' \
  "the record pass has a precondition, not a schedule"
pin "$NESTED_MD" 'is the whole ceremony' \
  "a close that recorded outright gets no second dispatch"
pin "$GENERIC_BRIEFS_MD" 'the level is `medium` unless' \
  "the ordinary reviewer path has a defined default level"
pin "$BRIEFS_MD" 'exactly as found before you write your report file' \
  "the item verifier leaves the worktree as it found it"

section "the release is declared once and agreed everywhere"

# The CHANGELOG's head version is the single declaration; both manifests are
# checked AGAINST it rather than against a literal repeated here, so a bump edits
# one file. The literal below is what stops that from being a round trip. The
# per-issue pins of the plugin this one was ported from record that plugin's
# history, not this one's, so none of them carries over. A missing CHANGELOG
# fails the pin outright rather than reporting itself not present yet.
pin "$CHANGELOG_MD" '## 0.1.0' "the CHANGELOG opens a 0.1.0 section"
head_ver="$(awk '/^## /{sub(/^## /, ""); print; exit}' "$CHANGELOG_MD")"
for m in "$PLUGIN_ROOT/.claude-plugin/plugin.json" "$PLUGIN_ROOT/.codex-plugin/plugin.json"; do
  mv_="$(awk -F'"' '/"version"/{print $4; exit}' "$m")"
  if [ -n "$mv_" ] && [ "$mv_" = "$head_ver" ]; then pass "${m%/*.json} manifest version matches the CHANGELOG head ($mv_)"
  else fail "${m%/*.json} manifest version matches the CHANGELOG head" "manifest '$mv_' vs CHANGELOG '$head_ver'"; fi
done

section "rotation past the context ceiling"

pin "$LIFECYCLE_MD" "## Rotation past the context ceiling" "lifecycle.md carries the rotation section"
pin "$LIFECYCLE_MD" 'resumes by naming the parent'"'"'s `run.json` path' \
  "a new top binds the parent run by naming its run.json path"
pin "$LIFECYCLE_MD" 'so after the rebind a worker on the successor'"'"'s machine pings the successor. A stale ping — tagged `[crew report <role>]`, or the legacy `REPORT READY: <task id> <kind> <path>` from a brief older than 0.3.1 — that reaches this pane after the rebind, like a `[DAGR OPERATOR MESSAGE]` envelope dagr queued here before the rebind, is read and handed to the successor, never acted on.' \
  "same-machine pings follow the rebind and stale pings are handed to the successor" flat
pin "$BRIEFS_MD" "HANDOFF_PATH=<" "the spine brief takes HANDOFF_PATH"
pin "$BRIEFS_MD" "rotate: <handoff path>" "the spine brief returns rotate: past the ceiling"
pin "$NESTED_MD" "rotate: <handoff path>" "the top's spine-completion step handles rotate:"
pin "$PRBRIEFS_MD" "context-ceiling notice" "the work-PR brief returns open: past the ceiling"

# #556: the rebind. One statement — a session that binds a `run.json` it did not
# create rewrites `run.orchestrator` to its own pane — carried to each successor's
# own contract: the top's rotation, the spine brief's continue (the rotate
# successor), and the work-PR brief's continue (the `open:` successor). The
# handoffs record the pane the block names at writing; the gap sentence is gone.
# The sequence's judgment — who writes when, the queued-message interval — is not
# parsed here and has no rubric criterion; it is checked by the recorded-claims
# walkthrough in the verification dispatch (no eval result covers it).
REBIND='A session that binds an existing `run.json` rewrites `run.orchestrator` to its own address from the layer'"'"'s Identity — dagr'"'"'s stable-agent fallback otherwise — in the same producer loop every other write takes.'
if ! rebind_life="$(count_of "$LIFECYCLE_MD" "$REBIND" flat)"; then
  fail "lifecycle states the rebind rule at step 1 and carries it to the rotation" "count failed — unreadable file or empty needle"
elif [ "$rebind_life" -eq 2 ]; then pass "lifecycle states the rebind rule at step 1 and carries it to the rotation (2)"
else fail "lifecycle states the rebind rule at step 1 and carries it to the rotation" "found $rebind_life, expected 2"; fi
pin "$BRIEFS_MD" "$REBIND" "the spine brief rebinds a continued RUN_JSON (rotate successor)" flat
pin "$PRBRIEFS_MD" "$REBIND" "the work-PR brief rebinds a continued RUN_JSON (open successor)" flat
pin "$NESTED_MD" 'rebinding `run.orchestrator` to its own pane' "nested-run §4 says the rotate successor rebinds" flat
pin "$LIFECYCLE_MD" 'the pane `run.orchestrator` names at writing, and the next step' "step 13's handoff records the pane the block names" flat
pin "$BRIEFS_MD" 'the path of RUN_JSON and the pane `run.orchestrator` names at writing' "the spine rotate return records the pane the block names" flat
pin "$PRBRIEFS_MD" "RUN_JSON's path and the pane its \`run.orchestrator\`" "the work-PR open return records the pane the block names" flat
# #556 round 1, finding 6: the gap sentence's absence is plugin-wide and must be
# wrap-proof. Flat mode reassembles a phrase a markdown wrap broke; the sweep reads
# every shipped carrier plus the manifests, fixtures and rubric — CHANGELOG included
# (its 0.2.4 entry names the issue, never the sentence). This test file is the
# reader, so its own pin arguments are not swept.
gap_absent() { # <file>
  gap_rel="${1#"$PLUGIN_ROOT"/}"
  if [ ! -r "$1" ]; then fail "no #556 gap text in $gap_rel" "missing or unreadable: $1"; return 0; fi
  gap_hits=0
  for gap_needle in 'does not rebind it' 'issue #556 holds that gap'; do
    gap_c="$(occurrences_flat "$1" "$gap_needle")" || { fail "no #556 gap text in $gap_rel" "unreadable file: $1"; return 0; }
    gap_hits=$((gap_hits + gap_c))
  done
  if [ "$gap_hits" -eq 0 ]; then pass "no #556 gap text in $gap_rel"
  else fail "no #556 gap text in $gap_rel" "$gap_hits occurrence(s)"; fi
}
GAP_CARRIERS=("$PLUGIN_ROOT/README.md" "$SKILL_MD" "$COMMAND_MD" "$REF"/*.md \
  "$PLUGIN_ROOT/CHANGELOG.md" "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
  "$PLUGIN_ROOT/.codex-plugin/plugin.json" \
  "$EVAL_DIR"/fixtures/ossify-spine-execution/*.md "$EVAL_RUBRIC_MD")
for gap_f in "${GAP_CARRIERS[@]}"; do gap_absent "$gap_f"; done

# #556 round 1, finding 1: the work-PR `open:` successor's dispatch must carry the
# predecessor's RUN_JSON path, or its continue branch and rebind are unreachable and
# it mints a second run file. One phrase per top-facing contract that builds that
# dispatch: lifecycle step 1b, lifecycle's rotation paragraph, nested-run §4, and
# ossify-execution.md's top column.
pin "$LIFECYCLE_MD" 'the `RUN_JSON` path that PR'"'"'s last `open:` return named' \
  "lifecycle step 1b carries the resumed work-PR dispatch's RUN_JSON" flat
pin "$LIFECYCLE_MD" 'with that same `RUN_JSON`' \
  "lifecycle's rotation carries RUN_JSON into the work-PR successor" flat
pin "$NESTED_MD" 'the `RUN_JSON` path that return named' \
  "nested-run §4 carries RUN_JSON into a resumed work-PR dispatch" flat
pin "$EXEC_MD" 'the `RUN_JSON` path that record'"'"'s return named' \
  "ossify-execution's top column carries RUN_JSON into a resumed work-PR dispatch" flat

section "the run file carries the live facts (#810, #816, #819)"
# Spec §3/§5: each fact a successor needs is written at the step that learns it.
pin "$LIFECYCLE_MD" '`run.merge_word` — `standing` unless the brief or the operator sets a merge gate for this run, then `operator`' \
  "step 1 writes the run's merge authority at creation" flat
pin "$LIFECYCLE_MD" 'Every creation and every bind writes `run.orchestrator.machine` beside its pane' \
  "step 1 writes the top's machine on creation and binding" flat
pin "$MECHANICS_MD" 'A `machine` is a remote server'"'"'s `herdr machine list` label; this server'"'"'s machine is its `hostname -s`' \
  "every coordinator can read the shared machine-label rule" flat
for f in "$BRIEFS_MD" "$PRBRIEFS_MD"; do
  pin "$f" 'On creation and on continue/rebind, write `run.orchestrator.machine` beside the pane — this server'"'"'s machine, per MECHANICS' \
    "${f##*/} writes its machine on creation and continuation" flat
done
pin "$NESTED_MD" 'On that rebind it writes `run.orchestrator.machine` beside the pane — this server'"'"'s machine, per the layer file' \
  "the nested spine successor writes its machine on rebind" flat
pin "$NESTED_MD" 'On creation and on continue/rebind it writes `run.orchestrator.machine` beside the pane — this server'"'"'s machine, per the layer file' \
  "the nested work-PR dispatch writes its machine on creation and continuation" flat
pin "$LIFECYCLE_MD" 'with `phase: recorded` and its full locator before the brief goes' \
  "step 3 records the attempt before the send" flat
pin "$LIFECYCLE_MD" '`phase: delivered` once the send is confirmed' \
  "step 3 marks delivery after the send" flat
pin "$COMPLETION_MD" 'writing an existing `REPORT_PATH` file'"'"'s current generation `{hash, identity}` as the new attempt'"'"'s `locator.seen` and leaving `seen` absent only when the file is absent' \
  "every dispatch records its existing report baseline before sending" flat
pin "$LIFECYCLE_MD" 'writes `run.question` before it asks and removes it on the answer' \
  "an operator ask is recorded in the run" flat
pin "$LIFECYCLE_MD" '`{text, asked_at, task, message_id?}`' \
  "an operator question records the exact object keys" flat
pin "$COMPLETION_MD" 'and recorded as the attempt'"'"'s `locator.seen`' \
  "the generation check records the consumed generation in the run" flat
pin "$COMPLETION_MD" '`{hash, identity}`' \
  "the consumed generation records the exact object keys" flat

section "a rotation and a hard stop resume from run state (#819, #810)"
# Ruling 18 (split): the hard-stop resume moved out of 0.2.22 to #810; pin retired with its clause.
pin "$LIFECYCLE_MD" 'From the handoff on, this session writes nothing to the run file and takes no dispatch action; a wake that reaches it before it stands down is handed to the successor, never acted on.' \
  "the outgoing top stops writing and dispatching at handoff and relays every intervening wake" flat
# Ruling 18 (split): the hard-stop resume moved out of 0.2.22 to #810; pin retired with its clause.
pin "$LIFECYCLE_MD" 'write nothing more to the run file and take no dispatch action' \
  "stand-down keeps the outgoing top from writing or dispatching" flat
pin "$LIFECYCLE_MD" 'It writes `run.orchestrator.machine` and `.session` beside the pane (lifecycle step 1).' \
  "resume step 2 writes the successor's machine beside its pane" flat
# Ruling 18 (split): the hard-stop resume moved out of 0.2.22 to #810; pin retired with its clause.
pin "$LIFECYCLE_MD" 'Binding a run another top drove through a rotation runs **The resume** (Rotation past the context ceiling) first; its step 2 is this rebind.' \
  "Orient routes a rotation's takeover through the resume before rebinding" flat
pin "$LIFECYCLE_MD" 'is resumed only on the operator'"'"'s word that it died' \
  "a hard stop resumes only on the operator's word (#810)" flat
pin "$LIFECYCLE_MD" 'and `run.orchestrator.session` from the layer'"'"'s Identity' \
  "every bind records the top's session from the layer's Identity for a later transcript read (#810)" flat
pin "$LIFECYCLE_MD" 'Read `run.orchestrator` — pane, machine, session — before any write' \
  "a hard stop reads the old top before the rebind overwrites it (#810)" flat
pin "$LIFECYCLE_MD" 'Never two tops on one run.' \
  "a hard stop stands the old top down first (#810)" flat
pin "$LIFECYCLE_MD" 'OMP `~/.omp/agent/sessions/*/*_<id>.jsonl`' \
  "the transcript is found by session id on both hosts (#810)" flat
pin "$LIFECYCLE_MD" 'where it and `run.json` disagree on a fact, `run.json` wins' \
  "the transcript is context; run.json wins on facts (#810)" flat
pin "$LIFECYCLE_MD" 'is checked for its effect first' \
  "a started-but-unconfirmed action is checked before it is redone (#810)" flat
pin "$LIFECYCLE_MD" 'A dispatch whose attempt the run records is never sent again: step 4 settles it' \
  "a hard stop never re-sends a recorded dispatch; resume step 4 settles it (#810)" flat
pin "$LIFECYCLE_MD" 'Binding one whose top died with no handoff runs **A hard stop**'"'"'s three steps before it.' \
  "Orient routes a hard-stop takeover through its three steps before the rebind (#810)" flat
pin "$LIFECYCLE_MD" 'Claude `~/.claude/projects/*/<id>.jsonl`' \
  "the transcript is found by session id on Claude Code too (#810)" flat
pin "$LIFECYCLE_MD" 'With no session recorded, no file found, or the old top on another machine, ask the operator once for the transcript path or the next step.' \
  "a hard stop with no transcript asks the operator once (#810)" flat
pin "$LIFECYCLE_MD" 'it always rewrites `run.orchestrator.session` (lifecycle step 1), since molt'"'"'s `/clear` starts a new session in this pane' \
  "a top that molts in place records its new session (#810)" flat
for f in "$BRIEFS_MD" "$PRBRIEFS_MD"; do
  pin "$f" 'and `run.orchestrator.session` from the layer'"'"'s Identity' \
    "${f##*/} records its session on creation and continuation (#810)" flat
done
pin "$NESTED_MD" 'On that rebind it writes `run.orchestrator.machine` beside the pane — this server'"'"'s machine, per the layer file — and `run.orchestrator.session`' \
  "the nested spine successor records its session on rebind (#810)" flat
pin "$NESTED_MD" 'On creation and on continue/rebind it writes `run.orchestrator.machine` beside the pane — this server'"'"'s machine, per the layer file — and `run.orchestrator.session`' \
  "the nested work-PR dispatch records its session (#810)" flat
# Ruling 18 (split): the hard-stop resume moved out of 0.2.22 to #810; pin retired with its clause.
# Ruling 12: automatic relaunch retired; an unstarted worker is the operator's decision.
# Ruling 12: relaunch cause retired with the automatic relaunch path.
pin "$LIFECYCLE_MD" 'Per working attempt, first run the generation check against `locator.seen`, for both `phase: recorded` and `phase: delivered`.' \
  "resume checks the generation baseline before deciding recorded delivery" flat
pin "$LIFECYCLE_MD" 'A new report generation proves delivery: set a recorded attempt `delivered`, then read the generation once, record it and act on it by kind.' \
  "a new report proves recorded delivery and is consumed once by kind" flat
# Ruling 12: agent-list absence retired as evidence that a recorded brief was not delivered.
# Ruling 12: pane-snapshot delivery branches retired; every recorded attempt with no new generation is re-armed.
pin "$LIFECYCLE_MD" 'With no new generation and `phase: recorded`, treat the attempt as `delivered` and re-arm it like any delivered attempt.' \
  "a recorded attempt without a new generation is delivered and re-armed" flat
pin "$LIFECYCLE_MD" 'Never relaunch it automatically.' \
  "resume never automatically relaunches a recorded attempt" flat
pin "$LIFECYCLE_MD" 'The re-armed wait’s timeout checkpoint (step 5) reports a worker that never started to the operator, who decides on a relaunch; never run two workers on one attempt.' \
  "the timeout reports an unstarted worker for the operator's relaunch decision without duplicating the attempt" flat
pin "$LIFECYCLE_MD" 'Re-arm step 5’s waits only for an attempt still live after its generation check; a final report consumed on resume settles that dispatch, so it gets no wait.' \
  "resume re-arms only live attempts and never waits on consumed final reports" flat
pin "$LIFECYCLE_MD" 'It arms one fresh heartbeat only if at least one dispatch is still live.' \
  "resume arms no heartbeat after its last dispatch settles" flat
pin "$LIFECYCLE_MD" 'If `run.question` is present, ask again only if the hard-stop transcript has no answer; otherwise apply the recorded answer and remove `run.question`.' \
  "#8562: resume uses the transcript answer instead of re-asking" flat
pin "$LIFECYCLE_MD" 'A `done` task is never re-run' \
  "the resume never re-runs a done task" flat
pin "$LIFECYCLE_MD" 'It continues at the fresh handoff'"'"'s next step.' \
  "a rotation continues at its fresh handoff's next step" flat
# Ruling 18 (split): the hard-stop resume moved out of 0.2.22 to #810; pin retired with its clause.
pin "$LIFECYCLE_MD" 'and the next step, the head SHA, and, per live seat, the last molt status line noted.' \
  "step 13 preserves the head SHA and each live seat's status cursor" flat
pin "$LIFECYCLE_MD" 'The run file holds those files’ paths, not the read cursors.' \
  "handoff distinguishes durable status paths from their last-noted lines" flat
pin "$LIFECYCLE_MD" 'Write the handoff step 13 states, plus a resolved profile beside a launch command for each host' \
  "rotation inherits step 13's head SHA and live-seat cursors" flat
pin "$LIFECYCLE_MD" 'The handoff restates no operator gate' \
  "the rotation handoff restates no operator gate (#819)" flat
pin "$LIFECYCLE_MD" 'step 12 and `run.merge_word`' \
  "the handoff points at the merge rule instead of restating it" flat
pin "$LIFECYCLE_MD" 'With `operator`, the ask says that this run'"'"'s brief or the operator set an operator merge gate:' \
  "step 12 states an operator gate explicitly" flat
pin "$LIFECYCLE_MD" 'a clean gate set on that SHA is the agreed condition, so merge with no ask (#837)' \
  "under a standing merge word the top merges a clean gate with no ask (#837)" flat
pin "$LIFECYCLE_MD" 'With `standing` (the default), a clean gate set on that SHA is the agreed condition, so merge with no ask' "#8561: the default grants merge without claiming a prior operator word" flat
pin "$SKILL_MD" 'and you merge it under step 12' "#8566: direct work-pr names its merge actor" flat
pin "$LIFECYCLE_MD" 'merge executor is the operator (`MERGE_EXECUTOR=operator`) still goes to the operator' \
  "an operator merge executor is reached under a standing word too (#837 round 1)" flat
pin "$LIFECYCLE_MD" 'A run file older than 0.2.21' \
  "the resume names the legacy run-file rules" flat
pin "$LIFECYCLE_MD" 'no `phase` counts as `delivered`' \
  "legacy: an attempt with no phase is delivered" flat
# Ruling 18 (split): the hard-stop resume moved out of 0.2.22 to #810; pin retired with its clause.
# Ruling 12: legacy read-once default retired; an unbaselined report does not prove the live attempt's result.
pin "$LIFECYCLE_MD" 'For a live dispatch with no `seen` and no fresh handoff generation, the existing report is ambiguous: the top reads it but does not act on it until the operator confirms it belongs to the live attempt.' \
  "legacy: an ambiguous report is read but requires operator confirmation before action" flat
pin "$LIFECYCLE_MD" 'A fresh handoff'"'"'s noted hash and identity, where present, are the baseline.' \
  "legacy: a fresh handoff supplies the generation baseline where present" flat
pin "$LIFECYCLE_MD" 'no `merge_word` counts as `standing`' \
  "legacy: no merge_word is standing" flat
pin "$LIFECYCLE_MD" 'against the attempt'"'"'s `locator.seen`' \
  "the molted top's generation check reads seen from run.json" flat

section "waits and completion bodies"

# The typed wait is stated ONCE, in layers/herdr.md; the shared files name that step
# rather than repeating the command — a second copy of a rule is the split's own
# anti-goal (spec §2). The absence counts are the half that moved: before Task 3 the
# command stood byte-identical in three files.
TYPED_WAIT='herdr agent wait <pane> --until done --until idle --until blocked --timeout <ms>'
pin "$MECHANICS_MD" "$TYPED_WAIT" "layers/herdr.md states the typed wait once"
n_eq "$LIFECYCLE_MD" 'herdr agent wait' 0 "lifecycle names the layer'"'"'s wait instead of repeating its command"
n_eq "$ROLES_MD" 'herdr agent wait' 0 "roles.md names the layer'"'"'s wait instead of repeating its command"
pin "$SKILL_MD" 'One bounded wait (the' \
  "SKILL.md's wait primitive is one bounded wait of the layer's"
# Each dispatched brief names the file its report is written to. Ten templates:
# the generic five, the four dedicated dispatch templates in the same file, and the
# demo walk the close dispatch constructs (Task 13).
n_eq "$GENERIC_BRIEFS_MD" 'REPORT_PATH=<the absolute path this seat writes its report to>' 10 \
  "every dispatched brief names its report path"

section "the clauses the milestone proved revertible"

# T2's and T4's reviewers measured these by mutation: each revert left ALL SIX
# SUITES GREEN. One pin per clause, and the label names the clause rather than
# the count, so a RED reads as a fact. `flat` (the fourth argument) is used only
# where the clause's own text is split by a markdown wrap in the file as it
# stands — the three sites that qualify are named in their comments. A pin whose
# needle has no reachable mutation is noise and none is written here: every pin
# below reverts to a real one-clause edit.

# T2 M-A. The spine dispatch's supply list names the correction body beside the
# two item templates; deleting `and correction templates` left the suite green.
pin "$EXEC_MD" 'item verifier and correction templates' \
  "the spine dispatch's supply list names the correction body"

# T2 M-B. The six atomic-rename REPORT_PATH slots — three spine-layer, two
# PR-layer, one close-review-writer. The `REPORT_PATH=` count pins above count the
# PREFIX, which a revert to a non-atomic mechanism leaves untouched; this is the
# mechanism itself. The writer's slot was the sixth and escaped T2 entirely: its
# finding named five, so "5/5 identical" was measured over the five it knew, and
# this file's slot kept the pre-fix wording for a whole milestone (T7b).
ATOMIC='replaced whole — a temp file in the same directory renamed over the path, never in pieces'
n_eq "$BRIEFS_MD" "$ATOMIC" 3 "all three spine-layer report slots rename atomically"
n_eq "$PRBRIEFS_MD" "$ATOMIC" 2 "both PR-layer report slots rename atomically"
n_eq "$WRITER_MD" "$ATOMIC" 1 "the close-review writer's report slot renames atomically"
# The generic layer's ten, added with the writer's slot in T7b and the demo walk's
# in Task 13. Not part of the six T2's finding named, but the same class and the
# same file set: measured, a revert of ONE of these left every suite green, exactly
# the hole the writer's slot was. The set is now 10+3+2+1 = all sixteen slot lines
# in shipped prose, so a revert of any one of them goes RED. The counter is the
# plain one — measured, this needle sits whole on one line in all sixteen, so no
# `flat` is needed here.
n_eq "$GENERIC_BRIEFS_MD" "$ATOMIC" 10 "all ten generic brief slots rename atomically"

# T2 M-E. The identity anchor: reverting it to a four-part "fingerprint" left the
# suite green. The four ids straddle a wrap, so this is two contiguous halves —
# the capture, then the ids and the contract that declares them.
pin "$NESTED_MD" 'capture the item'"'"'s identity as the result declares it — `head_oid`,' \
  "the nested run's step 5 captures the item identity the result declares"
pin "$NESTED_MD" '`tree_oid`, `report_oid` and `spec_oid`, the four ids the external-executor result envelope' \
  "the identity anchor names all four ids and the contract that declares them"
# #552, and the half that must NOT walk back in: the anchor once claimed these
# four are "the same four the close guard fingerprints", which is false of
# `close/references/work-item-close.md` — it compares no oid. `flat`: the removed
# sentence wrapped between "four the" and "close", so only the squeezed count
# catches a reintroduction that breaks the line somewhere else.
#
# THREE needles, not one, and the label is narrowed to what they assert. Review of
# T7 measured the one-needle form counting 0 for `close-guard fingerprints` (the
# hyphenated spelling that form's own label taught), `close guard's fingerprints`,
# `close guard fingerprint covers` and `fingerprinted by the close guard` — four
# honest rewordings of the claim the pin exists to exclude, each of which it would
# have called absent. The set below catches all four, and both wrap-break positions
# of the hyphenated form (`close-guard` broken at its hyphen squeezes to
# `close- guard`). So the label says the guard is NAMED nowhere rather than that no
# such claim exists. What that still leaves uncovered, and why it is accepted: a
# spelling that makes the claim without naming the guard in any of these three
# forms. Any realistic reintroduction names it, and the residual failure direction
# is the loud one — a future TRUE sentence that merely mentions the close guard
# false-REDs, which its author sees at once.
absent_any "$NESTED_MD" \
  "the identity anchor names no close guard, so it cannot carry the fingerprint claim" flat \
  'close guard' 'close-guard' 'close- guard'

# T4 G1. Reverting roles.md wholesale dropped all of these: the #516c probe
# conditioning — pinned in both of its halves, the profile's and the route's —
# the pilot's F2 precondition, and the teardown pointer.
pin "$ROLES_MD" 'Both files must exist before this sequence is run' \
  "roles.md's launch states the both-files precondition (pilot F2)"
pin "$ROLES_MD" 'a seat is sent one only when' \
  "the context probe is conditioned, not sent to every retained seat"
pin "$ROLES_MD" 'the send route that reaches it' \
  "the probe's second condition is the route, not the profile's can: alone"
pin "$ROLES_MD" 'A seat is released as the Teardown order below says' \
  "roles.md points teardown at its own Teardown order instead of restating it"

# T8b. The shipped summaries of that conditioning, pinned next door to the rule
# they summarise. T8 rewrote the two it could reach to carry the condition and the
# fallback — the README's parenthetical had asserted a check the excluded class never
# gets — and then MEASURED that reverting both left all six suites green (527/0): the
# rule is pinned above, its summaries were pinned by nothing, so a later edit could
# restore the false reading in silence. `flat` on both, measured rather than assumed:
# each clause's own text is split by a markdown wrap in the file as it stands (per-line
# count 0, squeezed count 1), and the shorter fragment that DOES sit whole on one
# line is a prefix of the clause — what this suite's header says a pin must not
# assert on its own. The needle carries the `roles.md` pointer too, because the
# pointer is half of what the fix is: the summary points, it does not restate.
pin "$PLUGIN_README_MD" 'checked by `/context` at each task boundary for a seat that can answer the probe — one that cannot rotates at its item boundary instead, `references/roles.md`)' \
  "README's retained-implementer summary carries the conditioned probe and its fallback" flat
pin "$SKILL_MD" 'the one `/context` reply at each task boundary for a seat that can answer the probe — one that cannot rotates at its item boundary instead (`references/roles.md`)' \
  "SKILL.md's bounded-reads list conditions the probe and gives the fallback" flat

# Fix round 2, on the whole-branch review's finding 3 and the controller's ruling: the
# third site of the same three, `lifecycle.md` step 5 — the only one that still carried
# one condition until the round above two-conditioned it, and the Open item that round
# flagged rather than pinned, because its brief named two. The ruling: the asymmetry is
# worse than the extra assertion, and a revert of this one would leave the suite green,
# which is the class this milestone spent its last four tasks closing. Same shape, same
# counter, measured the same way: this clause is wrap-split in the file as it stands
# (per-line count 0, squeezed count 1), so `flat`. The needle is the conditioned subject
# and not the sentence's action: `send /context … before attaching the next task` is text
# this fix did not touch, and asserting it would buy false REDs on an honest rewording of
# the action for no extra claim. Not the shorter fragment either (`whose profile can run a
# local slash command and whose send route carries one` measures 1 too) — that is a prefix
# of the clause, which this suite's header says a pin must not assert on its own.
pin "$LIFECYCLE_MD" 'for a retained implementer whose profile can run a local slash command and whose send route carries one' \
  "lifecycle step 5's probe sentence names both conditions the rule turns on" flat

# The whole-branch review's finding 1: README's What-ships row for `briefs.md` counted
# five dispatched templates where the file ships ten — the dedicated dispatch
# templates absent from the listing surface a reader opens first. Measured on a scratch
# copy before this pin existed: with the row reverted to "Five dispatched brief
# templates …", the whole suite stayed green (528/0 — 55 in config, the one assertion a
# standalone clone skips being the repo-root marketplace sweep), so the row was
# revertible in silence, exactly as the reviewer reported. The needle is the clause and
# not the count alone: it names the five templates, because their absence was half the
# finding. Per-line, and it sits whole on the row's one line; a later reword of the row
# fails it loudly rather than silently, which is the direction this suite accepts.
pin "$PLUGIN_README_MD" 'Ten dispatched brief templates — the generic five (planned implementer, fast implementer, reviewer, verifier, fix round) and the five dedicated dispatch templates the ossify dispatches use (lane driver, doctor dispatch, direct work-item, non-spine close, demo walk)' \
  "README's What-ships row counts the ten dispatched templates and names the five dedicated ones, the demo walk included"

# T4 G2. Deleting these from lifecycle.md left the suite green. The last is
# `flat` because the file breaks its line inside the clause today.
pin "$LIFECYCLE_MD" 'creates it again first and binds the id that call returns' \
  "a launch whose run workspace is gone recreates it and rebinds the returned id"
# 0.2.22 (#810): the handoff no longer lists per-seat panes, machines, molt or pain lines — run.json holds them (steps 1, 3, 5); pins retired.
pin "$LIFECYCLE_MD" 'through `locator.machine`' \
  "a resumed top re-arms each remote pane through locator.machine" flat

# T4 G3 and the P3 it drew. "`mv`, which this command allows" is a CROSS-FILE
# truth: the dagr write's own sentence and the top's command allowlist are two
# halves of one claim, so both are pinned and they sit together. `flat`: the
# sentence is split at its comma by a wrap in the file as it stands.
pin "$LIFECYCLE_MD" '`mv`, which this command allows' \
  "lifecycle's dagr write names the mv the top's own command allows" flat
pin "$COMMAND_MD" 'Bash(mv:*)' \
  "commands/orchestrate.md's allowlist is what permits that mv"

# T9b. The item verifier is the seat `roles.md` places in a canonical worktree for
# a fresh frame (#537) — the location whose project rules do not load, which is the
# slot's whole purpose — and its template was the one session brief in this file
# without the RULES slot. T1 added the slot to `briefs.md`'s generic reviewer and
# verifier and left this file's item verifier to "a later task"; no later brief
# carried it, and T9's walk found the gap. Measured, the absence was unguarded: at
# that head, with this template's slot missing (199 lines), all six suites were
# green. A count over the file's three session briefs, not a `pin`: the slot line
# is byte-for-byte the same in all three, so there is no unique needle on the line
# itself. The correction message is a send, not a session, and carries none.
# Residual, stated: a slot MOVED between templates in this file would keep the
# count — closing that needs a span helper this suite does not have, and a move is
# not the one-line revert this pin exists to catch. The slot sits flush under
# CLAIMS with the blank line before DONE because the file is at its 200-line gate
# and only one net line fit: measured over the plugin's fifteen shipped slots, the
# blank that FOLLOWS a slot is universal while the leading one is absent in eight,
# so the trailing one is the one to keep.
n_eq "$BRIEFS_MD" 'RULES THAT DO NOT LOAD HERE' 3 \
  "all three session briefs carry the rules slot"

# 0.8.0 (#951): the verifier's standards claim. ossify-briefs.md's item verifier
# inherits briefs.md's CLAIMS body verbatim, so the claim is pinned where it is written.
# Three halves: the claim and its verbatim evidence, the lookup order (merge-bar
# reviewing-a-pr's, then the memory bank), and the absence rule that keeps a missing
# file from failing the claim. `flat`: the claim wraps.
pin "$GENERIC_BRIEFS_MD" '4. [standards] The diff follows <standards file> and the conventions the repo follows in fact:' \
  "the verifier CLAIMS carry the standards claim" flat
pin "$GENERIC_BRIEFS_MD" '`CODING_STANDARDS.md` at the paired AI workspace root (the directory beside this repo whose `.workspace/pairing.json` has `canonical.name` equal to this repo'"'"'s name), else at the repo root, else the ossify memory bank'"'"'s `03-code-patterns.md`, else `none — looked at <paths>`.' \
  "the standards claim resolves workspace, repo root, memory bank, then none" flat
pin "$GENERIC_BRIEFS_MD" 'With none, judge conventions-in-fact alone; absence of a file is never `cannot determine`. Never delete this claim.' \
  "a missing standards file is never cannot-determine, and the claim is never deleted" flat

# 0.8.1 (#979): the standards claim's evidence names the file it judged and quotes both
# halves. The #951 pilot's verifier wrote the bare file name and paraphrased the hunk, under
# a claim that said "quote ... and the hunk".
pin "$GENERIC_BRIEFS_MD" 'name <standards file> by the path filled here, and quote the rule line, or the neighbouring committed file, and the hunk, each verbatim, never paraphrased.' \
  "the standards claim's evidence carries the resolved path and the verbatim hunk" flat
# 0.8.1 (#979): a claim is found by its tag, not its number — an item verifier's ACs come
# first, so the fixed claims' numbers move. Each fixed claim carries its tag, and both DONE
# shapes keep it.
for _t in '1. [ac] <acceptance' '2. [diff] The diff matches' '3. [mutation] When the item' \
          '4. [standards] The diff follows'; do
  pin "$GENERIC_BRIEFS_MD" "$_t" "the verifier claim carries its tag: $_t"
done
pin "$GENERIC_BRIEFS_MD" '1. [<tag>] <claim>: pass | fail | cannot determine' \
  "the generic verifier's DONE line keeps each claim's tag"
pin "$BRIEFS_MD" 'one line per claim, its [tag] first' \
  "the item verifier's DONE line keeps each claim's tag"
# 0.8.1 (#952): a re-check is the verifier brief sent again, refilled — never a hand-edited
# copy — and it judges the tree it now names. One pin per carrier: the generic template,
# the item verifier, lifecycle step 7 and the spine's correct path.
pin "$GENERIC_BRIEFS_MD" 'A re-check is this brief sent again, every slot refilled: judge the tree named here, never your previous check'"'"'s.' \
  "the generic verifier brief says what a re-check is" flat
pin "$BRIEFS_MD" 'A re-check is this brief sent again, refilled: judge the tree named above, never your previous check'"'"'s.' \
  "the item verifier brief says what a re-check is"
pin "$LIFECYCLE_MD" 'verifier — its brief sent again, every slot refilled (`briefs.md`)' \
  "lifecycle step 7's re-check names the brief it sends" flat
# 0.8.2 (#988 r1): the spine's correct path is a re-check too — a fresh report path in the
# same report directory, which the retained verifier's SEAT_MODS_ALLOW holds from launch.
pin "$BRIEFS_MD" 'the full recheck — this file'"'"'s item-verifier brief, refilled, a fresh `REPORT_PATH` in the same report directory — to the' \
  "the spine's correct path names the re-check's brief and a fresh report path in the same directory" flat
# 0.8.1 (#952): one diff form for a committed head and a staged tree, so no top edits the
# diff command for a staged re-check; and an empty revert is named, not passed.
pin "$GENERIC_BRIEFS_MD" '`git diff --cached <the item'"'"'s base sha>`, which covers a committed head and a staged tree.' \
  "the diff claim names one diff form for a committed head and a staged tree" flat
pin "$GENERIC_BRIEFS_MD" 'a revert that changes no file is `cannot determine`, naming the paths tried.' \
  "the mutation claim says what an empty revert is" flat
# 0.8.1 (#953): a calibration fixture has an owner and a place.
pin "$LIFECYCLE_MD" 'is the top'"'"'s own worktree mutation, never a worker'"'"'s task and never on the PR branch' \
  "a calibration fixture is the top's, never a worker's, never on the PR branch" flat
pin "$LIFECYCLE_MD" 'seeded only by `git checkout <base> -- <path>` on a path the implementer'"'"'s report names' \
  "a calibration fixture is seeded only by a base checkout of a reported path" flat
pin "$SKILL_MD" 'worktree (a calibration fixture'"'"'s included, `lifecycle.md` step 7)' \
  "the delegation floor admits the calibration fixture's worktree" flat
# 0.8.2 (#987): the 0.8.1 behaviours that had no pin a mutation kills — the fixture is a
# detached worktree at the item head, re-checked blind — and the rule the fixture needs
# beside "never edit product code", its expected fail and the real head's re-check after it.
pin "$LIFECYCLE_MD" 'a detached worktree at the item head' \
  "a calibration fixture is a detached worktree at the item head" flat
pin "$LIFECYCLE_MD" 're-checked without saying what was seeded, then removed.' \
  "a calibration fixture is re-checked without saying what was seeded" flat
pin "$LIFECYCLE_MD" 'Its `fail` is the expected answer, never counted toward a second fail; the item passes only on a re-check of its real head after it.' \
  "a calibration fixture's fail counts toward no second fail, and the real head is re-checked after it" flat
pin "$SKILL_MD" 'edit product code (a calibration fixture'"'"'s base checkout is not an edit: it restores committed code in a worktree no branch receives)' \
  "the never-edit-product-code rule names the calibration fixture's base checkout" flat
# 0.8.2 (#987): claim 3's delete clause wins for a test-only item — reverting its
# implementation edits changes no file, which the empty-revert clause would call
# `cannot determine`.
pin "$GENERIC_BRIEFS_MD" 'or the item changes only tests, delete this claim (never `cannot determine`); a test-only item is deleted here, never judged an empty revert.' \
  "a test-only item deletes the mutation claim, never judged an empty revert" flat
# 0.8.2 (#987): a re-check names the slots it changes; a new REPORT_PATH keeps the first
# report, which reusing the path would replace. The spine's correct path and the eval
# rubric carry the same re-check.
pin "$GENERIC_BRIEFS_MD" 'Two slots change: this line names the tree to judge now, and a fresh `REPORT_PATH` in the same report directory, never the first report'"'"'s.' \
  "the generic verifier's re-check names the two slots that change" flat
pin "$BRIEFS_MD" 'Two slots change: ROLE'"'"'s `head_oid` and `tree_oid`, from the latest return, and a fresh `REPORT_PATH` in the same report directory, never the first report'"'"'s.' \
  "the item verifier's re-check names the two slots that change"
pin "$NESTED_MD" 'the full recheck — `ossify-briefs.md`'"'"'s item-verifier brief, refilled, a fresh `REPORT_PATH` in the same report directory — to the same verifier.' \
  "nested-run's correct path names the re-check's brief and a new report path" flat
pin "$EVAL_RUBRIC_MD" 'the same verifier'"'"'s full recheck — its item-verifier brief refilled, a fresh `REPORT_PATH` in the same report directory, never the first report'"'"'s' \
  "the eval rubric's correct path names the re-check's brief and a new report path" flat
# 0.8.2 (#987, #954's other half): every carrier row takes the rail tail, so a seat a
# coordinator launches from a carried row records its rail, not "no guards"; and each
# layer's model read runs the rail's check in place of the status line.
RAIL_ROW='| host: <machine>[ | rail: <rail>]'
n_eq "$BRIEFS_MD" "$RAIL_ROW" 2 "the SEATS rows carry the rail tail"
n_eq "$PRBRIEFS_MD" "$RAIL_ROW" 2 "the work-PR reviewer and PR-fix rows carry the rail tail"
pin "$CONFIG_MD" "$RAIL_ROW" "config.md's rendered row carries the rail tail"
pin "$MECHANICS_MD" 'where the seat'"'"'s row names a `rail:`, that rail'"'"'s check runs in place of the status line.' \
  "herdr's model read runs a named rail's check in place of the status line" flat
pin "$ORCA_MD" 'where the seat'"'"'s row names a `rail:`, that rail'"'"'s check runs in place of the status line.' \
  "orca's model read runs a named rail's check in place of the status line" flat

section "the seat-mods guard reaches every launch site"

# The guard is a launch-time export (`layers/herdr.md`, the launch's step 2), and the
# rows a coordinator receives name no such thing ("verbatim from its row" wins), so every
# site that orders one of those launches must order the guard beside it. One pin per
# site; the label names the site, so a removal reads as that site. 0.2.7's
# coordinator-marking pins sit beside these, one per site.
pin "$ROLES_MD" '`Seat marking` writes these into the seat'"'"'s pane' \
  "the launch block states every launch's marking, one copy"
pin "$ROLES_MD" 'into the seat'"'"'s pane, before the seat'"'"'s command' \
  "the launch block binds the marking to the launch, before the command" flat
pin "$ROLES_MD" 'the spine, close or work-PR session, the doctor session, the lane driver' \
  "the launch block enumerates the coordinator seats" flat
pin "$ROLES_MD" 'one with no `replaces:` is a guarded `implementer`' \
  "the launch block marks an operator role with no replaces as a guarded implementer" flat
pin "$ROLES_MD" 'is that variant with `SEAT_MODS_ROLE=orchestrator`' \
  "the launch block marks the top's rotation successor orchestrator" flat
pin "$ROLES_MD" '`SEAT_MODS_ROLE=coordinator`' \
  "the launch block names the coordinator seat's export once"
# 0.2.19: scope to the launch export; T11 (ruling A) moved the Host rules shared with
# every layer to SKILL.md, so the rail is named there.
pin "$SKILL_MD" 'blocks them for `SEAT_MODS_ROLE=orchestrator`' \
  "the OMP host names the role's rail once (SKILL.md)"
pin "$ROLES_MD" 'The operator'"'"'s own first top is not launched here' \
  "the launch block says the operator launches its own top" flat
pin "$ROLES_MD" 'the directory holding the run'"'"'s `run.json`, outside every worktree' \
  "the launch block defines <run dir> (#658)" flat
pin "$MECHANICS_MD" '`--source visible` on the model read, even where a `banner`' \
  "the status line reads the viewport on a banner seat (#658)" flat
pin "$ROLES_MD" 'the top records one from its own launches to the operator' \
  "the missing-status-line record routes the top's own launches too (#658)" flat
pin "$ROLES_MD" 'halts no seat, re-launches none' \
  "a missing status line halts nothing and re-launches nothing (#658)" flat
pin "$ROLES_MD" 'also reads its status line for `seat: <role>`' \
  "the model read also reads the guarded seat's status line" flat
pin "$ROLES_MD" 'records that in its report file (to the top)' \
  "a missing status line is recorded in the coordinator's report file" flat
pin "$MECHANICS_MD" 'one `herdr pane run <pane> "export …"`' \
  "the layer spells the guard as the send into the seat's pane"
pin "$ROLES_MD" 'names one of those guarded roles is guarded as that role' \
  "a replacing project-file role is guarded as the role it replaces"

pin "$ROLES_MD" 'The launch environment' \
  "roles.md carries the launch environment every layer sets, one copy"
pin "$ROLES_MD" '`SEAT_MODS_ALLOW` — the colon-separated paths a guarded seat may write' \
  "roles.md scopes the allow list to the guarded roles"

pin "$LIFECYCLE_MD" 'runs the guarded-seat export `roles.md`'"'"'s launch block states' \
  "lifecycle step 3 requires the guard and points at roles.md's launch block"

pin "$BRIEFS_MD" 'Guard it before its command as' \
  "the spine brief guards the item implementer launch (step 3)"
pin "$BRIEFS_MD" 'verifier command — guard it before its command as' \
  "the spine brief guards the item verifier launch (step 5)"
pin "$BRIEFS_MD" 'two fresh seats guarded exactly as the initial pair'"'"'s were' \
  "the spine brief guards a replacement pair" flat

pin "$NESTED_MD" '`brief_delivery` says. Guard it' \
  "the nested run guards the implementer launch (step 3)"
pin "$NESTED_MD" 'Guard it before its command as the layer'"'"'s `Seat marking` says — role `verifier`' \
  "the nested run guards the verifier launch (step 5)" flat
pin "$NESTED_MD" 'Both replacement seats are guarded exactly as the first pair'"'"'s were' \
  "the nested run guards a replacement pair" flat

pin "$PRBRIEFS_MD" 'every launch or re-creation of it carries the guard before its command (role `reviewer`' \
  "the work-PR brief guards the reviewer launch and its re-creation" flat
pin "$PRBRIEFS_MD" 'every launch of it carries the guard before its command (role `implementer`' \
  "the work-PR brief guards the PR-fix launch" flat
pin "$PRBRIEFS_MD" 're-created if it was released, and guarded before its command then (role `reviewer`, `MECHANICS` Seat launch)' \
  "a resumed run's re-created reviewer carries its own guard requirement" flat

pin "$WRITER_MD" 'launches each writer' \
  "the close-review writer is dispatched as a guarded seat"
pin "$WRITER_MD" 'as a guarded seat: role `implementer`' \
  "the close-review writer's guard role is implementer"

# 0.2.7 (seat-mods 0.2.0): the two free roles are marked at launch, never left absent. Every site
# that orders a coordinator seat's launch names `coordinator` beside it, the top's own
# successor `orchestrator`; each points at step 2. One pin per site; the label names the
# site, so a removal reads as that site.
pin "$EXEC_MD" 'launching the spine session from that seat'"'"'s resolved profile, verbatim — marked `coordinator`' \
  "ossify-execution.md §2 marks the spine session it launches" flat
pin "$EXEC_MD" 'each launched from its project-file seat — marked `coordinator`' \
  "ossify-execution.md §2 marks the close and work-PR launches" flat
pin "$NESTED_MD" 'spine-session seat — marked `coordinator`' \
  "nested-run §4 marks the rotated spine session" flat
pin "$NESTED_MD" 'never the spine driver'"'"'s — marked' \
  "nested-run §4 marks the first close session" flat
pin "$NESTED_MD" '**fresh** close session — marked `coordinator`' \
  "nested-run §4 marks a re-dispatched fresh close" flat
pin "$NESTED_MD" '`work-PR session` seat — marked `coordinator`' \
  "nested-run §4 marks the work-PR session" flat
pin "$NESTED_MD" 'to another fresh close session — marked `coordinator`' \
  "nested-run §4 marks the record-pass close" flat
pin "$PRBRIEFS_MD" 'The top marks it `coordinator` before its command' \
  "the close template states the coordinator marking" flat
pin "$PRBRIEFS_MD" 'seat the project file names — marked `coordinator` before its command' \
  "the work-PR template states the coordinator marking" flat
pin "$BRIEFS_MD" 'and marked `coordinator` before its command' \
  "the spine-session brief states the coordinator marking" flat
pin "$LIFECYCLE_MD" 'start **one** spine session — marked `coordinator` before its command' \
  "lifecycle step 1b marks the spine session" flat
pin "$LIFECYCLE_MD" 'close-session seat, marked `coordinator` before its' \
  "lifecycle step 1b marks the first close" flat
pin "$LIFECYCLE_MD" 'seat, marked `coordinator` before its command (the layer'"'"'s `Seat marking`),' \
  "lifecycle step 1b marks the work-PR dispatch" flat
pin "$LIFECYCLE_MD" 'a second close, marked `coordinator` before' \
  "lifecycle step 1b marks the record pass" flat
pin "$LIFECYCLE_MD" 'launches a fresh seat to resume, marked `coordinator` before its' \
  "lifecycle's rotation marks the coordinator successors" flat
pin "$LIFECYCLE_MD" 'marked `orchestrator` before its command' \
  "lifecycle's own rotation marks the top's successor orchestrator" flat
pin "$SKILL_MD" 'Mark it `coordinator` before its command' \
  "SKILL.md §6 marks the default lane driver" flat
pin "$SKILL_MD" 'record pass — each marked `coordinator` before its command' \
  "SKILL.md §6 marks the default lane's close, work-PR and record pass" flat
pin "$ROLES_MD" 'for that spine — marked `coordinator` before its command' \
  "roles.md marks the spine session's launch" flat
pin "$ROLES_MD" '`work-PR session`), marked `coordinator` before its command' \
  "roles.md's budget marks the close and work-PR launches" flat
pin "$ROLES_MD" 'seat of the same name, marked `coordinator`' \
  "roles.md marks the doctor session's launch" flat
pin "$ROLES_MD" 'the same list with `SEAT_MODS_ROLE=coordinator` **in place of** `<role>`' \
  "the launch block shows the coordinator export as the guarded line's variant" flat
absent "$MECHANICS_MD" 'SEAT_MODS_ROLE=orchestrator MOLT_HANDOFF' "the top's successor export carries no molt marking"
absent "$ROLES_MD" 'SEAT_MODS_ROLE=orchestrator MOLT_HANDOFF' "roles.md carries no marked orchestrator export"
pin "$COMMAND_MD" 'start one spine session — marked `coordinator`' \
  "commands/orchestrate.md marks the spine start" flat
pin "$LIFECYCLE_MD" 'A declared role with no `replaces:` is marked a guarded `implementer`' \
  "lifecycle marks an operator role with no replaces as a guarded implementer" flat
pin "$SKILL_MD" 'The direct work-item seat is a guarded `implementer` — its report, scratch and handoff directories' \
  "SKILL.md §6 marks the direct work-item seat and its handoff directory" flat
pin "$SKILL_MD" 'a non-spine close is a coordinator seat, marked `coordinator`' \
  "SKILL.md §6 marks the non-spine close as a coordinator seat" flat
pin "$SKILL_MD" 'Mark the doctor seat `coordinator` before its command' \
  "SKILL.md §6 marks the doctor seat as a coordinator seat" flat

# 0.2.11 (#663): the citing clauses the launch-site check's selected sites carry — one
# pin per site, so a reword that keeps a clause token but drops the citation reads here.
pin "$EXEC_MD" 'marks each seat it launches as' \
  "ossify-execution.md's resumed top states the marking at its launches" flat
pin "$ROLES_MD" 'The session that launches the seat marks it in the pane, before its command, as' \
  "roles.md's activated-spine rows state the marking where the launcher acts" flat
pin "$BRIEFS_MD" 'The session that launches the seat marks it in the pane, before its command, as' \
  "ossify-briefs.md's item-verifier intro states the marking where the launcher acts" flat
# The fourth citing clause this PR adds (R8), in the close brief's NEVER aside — the
# site the launch-site check selects as `ossify-pr-briefs.md:61`. Pinned here so the
# claim that all four clause texts are pinned stays true; the needle carries the
# citation with the marking, so a reword that keeps the token and drops "before its
# command" reads red.
pin "$PRBRIEFS_MD" 'remediated, the top dispatches a fresh close session, marked `coordinator` before its command' \
  "ossify-pr-briefs.md's close-brief NEVER states the fresh close's marking where the launcher acts" flat
pin "$GENERIC_BRIEFS_MD" 'seat — its report, scratch and handoff directories in `SEAT_MODS_ALLOW`' \
  "the direct work-item template marks its handoff directory too" flat
pin "$GENERIC_BRIEFS_MD" 'The top marks it `coordinator` before its' \
  "the non-spine close template states the coordinator marking" flat
pin "$PLUGIN_README_MD" 'Every launch that places a seat in a herdr pane marks it' \
  "the plugin README scopes the marking to herdr panes"

# seat-mods 0.2.0: the role set is implementer, verifier, reviewer and the two free
# roles coordinator and orchestrator — and this is a WHITELIST over the exact assigned
# word. Only an ASSIGNMENT is read (`SEAT_MODS_ROLE=`), bare or in matching quotes;
# prose that names the variable is the rule working, so the first cut's line-based
# mention test is gone (its valid sentence "a coordinator guards its own children"
# false-RED'd). A value is valid only when the role word is followed by end of line,
# whitespace, a backtick (a code span's close), or — after an opening quote — the
# matching closing quote followed by that same terminator; a bare value may also end at
# a quote that closes an earlier-opened quote on the same line, which is the roles.md
# pane-run recipe's closing `"`. Anything else fails: `coordinator,`, `coordinator;`,
# `orchestrator.`, an unbalanced `"coordinator`, a stray trailing quote, a quoted value
# followed by junk (`"coordinator"junk`), a value outside the five, and an empty value
# (`SEAT_MODS_ROLE=` at end of line, or `""`). The only placeholder accepted is the
# shipped `<role>` slot (`<>` and `<close-session>` fail); a coordinator noun (spine,
# close, work-pr, work-PR, workpr, doctor, lane) is not a role. The seeded controls
# below prove each class; the shipped-file scan runs the same predicate.
invalid_role_value_hits() { # <file> -> count; an unreadable file is refused
  [ -r "$1" ] || return 1
  awk '
    function allowed(v) {
      return v == "implementer" || v == "verifier" || v == "reviewer" ||
             v == "coordinator" || v == "orchestrator" || v == "<role>"
    }
    function terminated(tail, prefix,   t, pc, n) {
      t = substr(tail, 1, 1)
      if (t == "" || t == " " || t == "\t" || t == "`") return 1
      if (t == "\"" || t == "\047") {
        pc = prefix; n = gsub(t, "", pc)
        if (n % 2 == 1) return 1
      }
      return 0
    }
    {
      line = $0
      while (match(line, /SEAT_MODS_ROLE=/)) {
        pre = substr(line, 1, RSTART - 1)
        rest = substr(line, RSTART + RLENGTH)
        line = rest
        q = substr(rest, 1, 1)
        quoted = (q == "\"" || q == "\047")
        if (quoted) body = substr(rest, 2); else body = rest
        v = ""
        after = body
        if (match(body, /^[A-Za-z0-9_<>-]+/)) { v = substr(body, RSTART, RLENGTH); after = substr(body, RLENGTH + 1) }
        ok = 0
        if (quoted) {
          if (substr(after, 1, 1) == q) ok = terminated(substr(after, 2), pre q v q)
        } else {
          ok = terminated(after, pre)
        }
        if (!ok || !allowed(v)) hits++
      }
    }
    END { printf "%d", hits + 0 }
  ' "$1"
}

value_control() { # <expected hits> <fixture> <label>
  printf '%s\n' "$2" > "$seed"
  _vc="$(invalid_role_value_hits "$seed")" || _vc=-1
  if [ "$_vc" -eq "$1" ]; then pass "control: $3"
  else fail "control: $3" "$_vc hit(s), expected $1"; fi
}

seed="$(mktemp)"
value_control 1 'export SEAT_MODS_ROLE=spine in its pane' "a bare coordinator-valued guard assignment is flagged"
value_control 1 'SEAT_MODS_ROLE="spine"' "a quoted coordinator-valued guard assignment is flagged"
value_control 1 "SEAT_MODS_ROLE='close'" "a single-quoted coordinator noun is flagged"
value_control 1 'SEAT_MODS_ROLE=coordinator,' "a value followed by a comma is flagged"
value_control 1 'SEAT_MODS_ROLE=coordinator;' "a value followed by a semicolon is flagged"
value_control 1 'SEAT_MODS_ROLE=orchestrator.' "a value followed by a period is flagged"
value_control 1 'SEAT_MODS_ROLE="coordinator' "an unterminated quoted value is flagged"
value_control 1 'SEAT_MODS_ROLE=coordinator"' "a stray trailing quote is flagged"
value_control 1 'SEAT_MODS_ROLE="coordinator"junk' "junk after a quoted value's closing quote is flagged"
value_control 1 "SEAT_MODS_ROLE='verifier'x" "a letter after a quoted value's closing quote is flagged"
value_control 0 'SEAT_MODS_ROLE="coordinator" X=1' "a quoted value followed by whitespace is accepted"
value_control 1 'SEAT_MODS_ROLE=' "an empty value at end of line is flagged"
value_control 1 'SEAT_MODS_ROLE=""' "an empty quoted value is flagged"
value_control 1 'SEAT_MODS_ROLE=<>' "an empty slot is flagged"
value_control 1 'SEAT_MODS_ROLE=<close-session>' "a hyphenated non-role slot is flagged"
value_control 1 'SEAT_MODS_ROLE=foo' "an assignment outside the role set is flagged"
value_control 0 'SEAT_MODS_ROLE=coordinator' "the coordinator value is accepted (the 0.2.7 flip)"
value_control 0 'SEAT_MODS_ROLE="orchestrator"' "the quoted orchestrator value is accepted"
value_control 0 'SEAT_MODS_ROLE=implementer SEAT_MODS_ALLOW=/w' "a bare valid role followed by whitespace is accepted"
value_control 0 'SEAT_MODS_ROLE=<role>' "the <role> slot placeholder is accepted"
value_control 0 'herdr pane run <pane> "export SEAT_MODS_ROLE=coordinator"' "the pane-run recipe's closing quote terminates the value"
value_control 0 'a coordinator guards its own children — it sends SEAT_MODS_ROLE to each child pane' "coordinator prose with no assignment is not flagged"
rm -f "$seed"

# Every listed path must EXIST: a missing one is a failed assertion, never a skip — a
# typo'd path (this list held hooks.json for a file at hooks/hooks.json) silently shrank
# the sweep. Each entry is a literal or a glob that must match.
SHIPPED=("$PLUGIN_ROOT"/README.md "$PLUGIN_ROOT"/CHANGELOG.md "$PLUGIN_ROOT"/LICENSE \
         "$PLUGIN_ROOT"/hooks/hooks.json "$PLUGIN_ROOT"/hooks-handlers/* \
         "$PLUGIN_ROOT"/skills/orchestrate/SKILL.md "$REF"/*.md \
         "$PLUGIN_ROOT"/skills/orchestrate/agents/* "$PLUGIN_ROOT"/commands/* \
         "$PLUGIN_ROOT"/.claude-plugin/plugin.json "$PLUGIN_ROOT"/.codex-plugin/plugin.json)
shipped_count=0
for f in "${SHIPPED[@]}"; do
  if [ -f "$f" ]; then
    shipped_count=$((shipped_count + 1))
  else
    fail "every listed shipped file exists" "missing: $f"
  fi
done
if [ "$shipped_count" -ge 15 ]; then pass "the shipped-file scan covers $shipped_count files"
else fail "the shipped-file scan covers the plugin's surfaces" "only $shipped_count file(s) — a zero-count over nothing certifies nothing"; fi
for f in "${SHIPPED[@]}"; do
  [ -f "$f" ] || continue
  h="$(invalid_role_value_hits "$f")" || { fail "no invalid SEAT_MODS_ROLE value in ${f##*/}" "unreadable file"; continue; }
  if [ "$h" -eq 0 ]; then pass "no invalid SEAT_MODS_ROLE value in ${f##*/}"
  else fail "no invalid SEAT_MODS_ROLE value in ${f##*/}" "$h occurrence(s) — the value must be implementer, verifier, reviewer, coordinator, orchestrator or the <role> slot, terminated by end of line, whitespace or its closing quote"; fi
done

# 0.2.8: molt's warnings replace the ceiling notice where molt runs (0.2.6 silences the
# hook on molt's marker). Every seat but the top hands off to its parent; the top molts
# in place. Carried by hand from closed PR #669 where marked; the rotation pins above
# are untouched (/molt off and a host without molt keep them).
section "molt (0.2.8)"
pin "$LIFECYCLE_MD" 'Where molt runs, its warnings take the notice'"'"'s place' \
  "lifecycle: the ladder replaces the notice where molt runs" flat
pin "$LIFECYCLE_MD" "**Where molt runs, you molt in place instead.**" "lifecycle: the top's molt path exists (#669)" flat
pin "$LIFECYCLE_MD" 'take your next fully acknowledged delivery with no operator question in flight, or hand off at once when nothing is in flight' \
  "lifecycle: the top's warning boundary" flat
pin "$LIFECYCLE_MD" 'add to it the id of every background task you have running' \
  "lifecycle: the top's molt handoff lists live task ids (#669)" flat
pin "$LIFECYCLE_MD" 'a wake or message that reaches you after it is added to it verbatim, never acted on' \
  "lifecycle: a wake after the top's handoff is handed over (Review Focus 5)" flat
pin "$LIFECYCLE_MD" 'There is no stand-down and no successor launch' "lifecycle: the molt path launches nothing (#669)" flat
pin "$LIFECYCLE_MD" 'On Claude Code it arms no wait and no heartbeat the handoff lists' "lifecycle: the resumed top re-arms nothing listed on Claude Code (#669, #855)" flat
pin "$LIFECYCLE_MD" 'and, on Claude Code, every armed wait survive the clear' "lifecycle: waits survive a molt on Claude Code only (#855)" flat
pin "$LIFECYCLE_MD" 'On OMP the clear cancels every background job the old session ran' "lifecycle: an OMP molt cancels the old session's jobs (#855)" flat
pin "$LIFECYCLE_MD" 'the resumed top re-arms the wait of each dispatch still live and one fresh heartbeat' "lifecycle: a top resumed on OMP re-arms its live waits and a heartbeat (#855)" flat
pin "$LIFECYCLE_MD" 'A heartbeat tick the handoff carries means that heartbeat has ended' \
  "lifecycle: a carried tick re-arms the heartbeat (#669)" flat
# Retired the handoff hash/identity pin: run.json now holds locator.seen (ruling 12).
pin "$LIFECYCLE_MD" 'With `/molt off` the marker goes, the hook speaks again, and the rotation above applies.' \
  "lifecycle: /molt off falls back to the rotation (#669)" flat
pin "$NESTED_MD" 'A spine session that rotated on a molt warning returns the same `rotate:`' \
  "nested-run §4: a molt-triggered rotate is the same rotate" flat
pin "$NESTED_MD" 'one cut mid-round returns none and is respawned the same way' \
  "nested-run §4: a mid-round cut is respawned under ossify 1.14.0 (#674)" flat
absent "$NESTED_MD" 'returns none and goes to the operator' "nested-run §4: the pre-1.14.0 relay is gone (#674)"
molt_line() { # <role>
  printf '%s\n' 'MOLT: if molt warns you, send one ping, `<PING_SEND> '"'"'[crew molt '"$1"'] <pct> <task id>'"'"'` (read as PING says; never when NOTIFY_RUN is `none`), finish this unit and start nothing new. Only on molt'"'"'s handoff command mid-unit: write your handoff by hand to `<REPORT_PATH>.molt.md` — the one file besides your report your NEVER line lets you write; never with `/ossify:handoff`, never in a repository, never committed — write `handoff: <that path>` as your report, ping as PING says, end that reply with `MOLT-HANDOFF: <that path>`, and stop. A wake or message after that is added to the handoff verbatim, never acted on.'
}
# One pin per template, labelled by name, so a miss names its site (0.2.5 and 0.2.7 were
# both caught on unnamed launch sites). The span is the Nth ```text fence of the file; the
# role is the template's own seat role (crew 0.3.1).
molt_in_template() { # <file> <fence n> <template name> <role>
  span="$(mktemp)"
  awk -v n="$2" '/^```text/{t++; if (t == n) { on = 1; next } } on && /^```$/{exit} on' "$1" >"$span"
  pin "$span" "$(molt_line "$4")" "${1##*/} — $3 carries the MOLT line" flat
  rm -f "$span"
}
molt_in_template "$GENERIC_BRIEFS_MD" 1 "Planned implementer" implementer
molt_in_template "$GENERIC_BRIEFS_MD" 2 "Fast implementer" implementer
molt_in_template "$GENERIC_BRIEFS_MD" 3 "Reviewer" reviewer
molt_in_template "$GENERIC_BRIEFS_MD" 4 "Verifier" verifier
molt_in_template "$GENERIC_BRIEFS_MD" 5 "Fix round" implementer
molt_in_template "$GENERIC_BRIEFS_MD" 6 "Lane driver" coordinator
molt_in_template "$GENERIC_BRIEFS_MD" 7 "Doctor dispatch" coordinator
molt_in_template "$GENERIC_BRIEFS_MD" 8 "Direct work-item" implementer
molt_in_template "$GENERIC_BRIEFS_MD" 9 "Non-spine close" coordinator
molt_in_template "$BRIEFS_MD" 2 "Item implementer" implementer
molt_in_template "$BRIEFS_MD" 3 "Item verifier" verifier
molt_in_template "$PRBRIEFS_MD" 1 "Close session" coordinator
molt_in_template "$WRITER_MD" 1 "Close-review writer" implementer
# Adjacent controls: exactly one line per leaf template — the Correction request (a send,
# not a session) takes none — and no template carries it twice.
n_eq "$GENERIC_BRIEFS_MD" "$(molt_line implementer)" 4 "briefs.md carries the implementer MOLT line 4 times (9 total, none in the Correction request)"
n_eq "$GENERIC_BRIEFS_MD" "$(molt_line coordinator)" 3 "briefs.md carries the coordinator MOLT line 3 times"
n_eq "$GENERIC_BRIEFS_MD" "$(molt_line reviewer)" 1 "briefs.md carries the reviewer MOLT line once"
n_eq "$GENERIC_BRIEFS_MD" "$(molt_line verifier)" 1 "briefs.md carries the verifier MOLT line once"
n_eq "$BRIEFS_MD" "$(molt_line implementer)" 1 "ossify-briefs.md carries the implementer leaf MOLT line once (item pair only)"
n_eq "$BRIEFS_MD" "$(molt_line verifier)" 1 "ossify-briefs.md carries the verifier leaf MOLT line once"
pin "$BRIEFS_MD" 'ROTATE instead once the context-ceiling notice or a molt warning has fired' \
  "spine brief: a molt warning triggers the existing ROTATE" flat
pin "$BRIEFS_MD" 'MOLT: if molt warns you, send one ping, `<PING_SEND> '"'"'[crew molt coordinator] <pct> <SPINE_ID>'"'"'` (read as PING says; never when NOTIFY_RUN is `none`), and ROTATE at the next round barrier' \
  "spine brief: the MOLT line" flat
pin "$BRIEFS_MD" 'End the reply that writes `rotate:` with `MOLT-HANDOFF: <handoff path>`' \
  "spine brief: the rotate reply names the handoff for molt (D5)" flat
pin "$BRIEFS_MD" 'If molt'"'"'s handoff command arrives mid-round, still finish the round' \
  "spine brief: never stop mid-round, molt included (D3)" flat
pin "$BRIEFS_MD" 'already holds a staged result with its `report.md`' \
  "spine brief: the staged-result caller rule (D6)" flat
pin "$BRIEFS_MD" 'A request the lane issues on re-entry for an item this session has not executed' \
  "spine brief: the staged-result rule is scoped to close-finished re-entry (a)" flat
pin "$BRIEFS_MD" 'A worktree staged by a result you rejected in this session is step 5'"'"'s correction or replacement' \
  "spine brief: a rejected result's worktree is never read as close-finished (a)" flat
pin "$BRIEFS_MD" 'you count each execution the lane did not request — a correction, or a replacement'"'"'s fresh pair' \
  "spine brief: the caller counts a correction and a caller-driven replacement (a2, PR #679 r2)" flat
absent "$BRIEFS_MD" 'you count only a correction' "spine brief: a replacement is never left uncounted (PR #679 r2)" flat
pin "$BRIEFS_MD" 'run `oss work_item_dispatched <wi-id>`, then send the correction or launch the fresh pair' \
  "spine brief: the caller counts before it sends (a2)" flat
pin "$BRIEFS_MD" 'Never count a request the lane issued, or it is counted twice' "spine brief: no double count (a2)" flat
pin "$BRIEFS_MD" 'an `adopt` item reaches you as an ordinary request' "spine brief: adopt is a redispatch (a3)" flat
pin "$BRIEFS_MD" '(`finish-merge`, `finish-status`) or one already `complete` gets none' \
  "spine brief: ossify-finished items get no request (a3)" flat
pin "$BRIEFS_MD" 'a halt row in it is a halt to report, never repaired by hand' \
  "spine brief: a re-entry halt is reported" flat
pin "$BRIEFS_MD" 'Before that re-run, close every item pane a predecessor left live' \
  "spine brief: a re-entry never runs beside a predecessor's live item seat (PR #679 r4)" flat
pin "$BRIEFS_MD" 'A predecessor pane you cannot find or close is a halt to report' \
  "spine brief: an unclosable predecessor seat halts, never co-writes (PR #679 r4)" flat
pin "$BRIEFS_MD" 'Never stop mid-round.' "spine brief: ROTATE stays strict until a restarted session proves re-entry" flat
absent "$BRIEFS_MD" 'relayed to the operator by your parent' "spine brief: a molt-cut round is re-entered, not relayed (#674)"
pin "$PRBRIEFS_MD" 'at a fix-round boundary once the context-ceiling notice or a molt warning has fired' \
  "work-PR brief: a molt warning triggers the existing open:" flat
pin "$PRBRIEFS_MD" 'and return `open:` at the next fix-round boundary' "work-PR brief: the MOLT line" flat
pin "$PRBRIEFS_MD" 'End the reply that writes `open:` with `MOLT-HANDOFF: <REPORT_PATH>`' \
  "work-PR brief: the open reply names its report for molt (D5)" flat
pin "$SKILL_MD" 'Where molt runs, its warnings replace the notice' "SKILL.md names the molt path" flat
pin "$COMPLETION_MD" 'note it and send that seat no new unit' "completion.md: a warned retained seat is replaced, not reused" flat
# PR #671 round 1.
# 0.2.22 (#810): the handoff no longer lists per-seat panes, machines, molt or pain lines — run.json holds them (steps 1, 3, 5); pins retired.
pin "$GENERIC_BRIEFS_MD" 'the leaf templates'"'"' `MOLT:` line included' \
  "briefs.md: an operator brief's envelope carries the MOLT line" flat
pin "$BRIEFS_MD" 'a `correct` decision on it first launches the item'"'"'s implementer in that worktree' \
  "spine brief: a staged result's correction has an implementer to receive it" flat
# PR #671 round 2.
pin "$BRIEFS_MD" 'sends it the item-implementer brief with the correction as its task' \
  "spine brief: the late implementer gets its whole brief" flat
pin "$PRBRIEFS_MD" 'On the open shape, first release both seats and close the workspaces you created for them' \
  "work-PR brief: the open shape releases its child seats" flat
pin "$PRBRIEFS_MD" 'with no fix round in hand, return `open:` at once' "work-PR MOLT line: an immediate exit" flat
pin "$PRBRIEFS_MD" 'If molt'"'"'s handoff command arrives mid-round, still finish the round' \
  "work-PR MOLT line: never stop mid-round, as the spine" flat
pin "$CHANGELOG_MD" '## 0.2.8' "CHANGELOG has 0.2.8"
pin "$CHANGELOG_MD" '## 0.2.9' "CHANGELOG has 0.2.9"

# ── the standing orders reach the seats and the briefs (0.2.29, slice 1) ────
#
# The old PROHIBITIONS line carried Merge acknowledgment in the operator-owned
# set and left every brief saying the merge is the operator's word, while
# lifecycle step 12 already merges on `run.merge_word`; slice 1 moves a worker's
# plan to the top. Seventeen sites change together, and a per-file COUNT is the
# right check: this line repeats once per template, so a `pin` (unique) cannot
# assert it — the counts are 11 + 3 + 2 + 1, and a missed, duplicated or extra
# site fails here. The absence pin is a loosening; its adjacent control (the
# operator-owned gate sentence, at the same counts) means deleting the whole
# line fails the control even though it would pass the absence pin.
section "the standing orders reach the seats and the briefs"

NEW_PROHIBITIONS='PROHIBITIONS: every seat-mods denial and narrower task limit wins. Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned; a worker'"'"'s implementation plan is the top'"'"'s to approve, and the merge follows run.merge_word. No delete, branch-delete, force-push, no-verify, AI-trailer or guarded-merge exception is granted.'
for pair in "$GENERIC_BRIEFS_MD:11" "$BRIEFS_MD:3" "$PRBRIEFS_MD:2" "$WRITER_MD:1"; do
  f="${pair%:*}"; want="${pair##*:}"
  n_eq "$f" 'PROHIBITIONS: ' "$want" "${f##*/} carries exactly $want PROHIBITIONS lines"
  n_eq "$f" "$NEW_PROHIBITIONS" "$want" "${f##*/} carries the new PROHIBITIONS line at all $want sites"
done
# The enrolled-authority envelope is gone from every template: the five lines that
# followed the opening line (and the opening line itself) carry no site now.
for f in "$GENERIC_BRIEFS_MD" "$BRIEFS_MD" "$PRBRIEFS_MD" "$WRITER_MD" "$EXEC_MD" "$NESTED_MD"; do
  for gone in 'OMP AUTHORITY' 'BOUND FACTS: ' 'PROVENANCE: ' 'LIFECYCLE: ' 'FRESHNESS: ' 'enrolled OMP'; do
    n_eq "$f" "$gone" 0 "${f##*/} carries no '$gone' line"
  done
done
for f in "$GENERIC_BRIEFS_MD" "$BRIEFS_MD" "$PRBRIEFS_MD" "$WRITER_MD" "$EXEC_MD" \
         "$NESTED_MD" "$LIFECYCLE_MD" "$ROLES_MD" "$SKILL_MD" \
         "$PLUGIN_README_MD" "$COMMAND_MD"; do
  absent "$f" 'Merge acknowledgment, design/spec/plan/release gates, product choices' \
    "${f##*/} carries no old PROHIBITIONS phrase"
done
for pair in "$GENERIC_BRIEFS_MD:11" "$BRIEFS_MD:3" "$PRBRIEFS_MD:2" "$WRITER_MD:1"; do
  f="${pair%:*}"; want="${pair##*:}"
  n_eq "$f" 'Design/spec/release gates, product choices, credential values and Molt handoff remain operator-owned' "$want" \
    "${f##*/} keeps the operator-owned gate sentence at all $want sites"
done
# The two fixed needles. Both wrap in the file today, so the flat join is each
# pin's mode, as this suite's header says for a wrapped clause.
pin "$EXEC_MD" 'under a standing order in the project'\''s memory bank or AGENTS.md for seats and profiles, write the recommended set and continue; otherwise present every seat' \
  "ossify-execution.md §3: the seat set is written under the order, else presented" flat
pin "$EXEC_MD" 'under that standing order, pick the reviewer and PR-fix profiles from the project file and record why; otherwise ask' \
  "ossify-execution.md §5: the reviewer and PR-fix profiles follow the order, else are asked" flat

section "reference line budgets"

budget "$EXEC_MD" "ossify-execution.md is within the reference budget"
budget "$NESTED_MD" "ossify-nested-run.md is within the reference budget"
budget "$PRBRIEFS_MD" "ossify-pr-briefs.md is within the reference budget"
budget "$BRIEFS_MD" "ossify-briefs.md is within the reference budget"
budget "$WRITER_MD" "ossify-close-writer.md is within the reference budget"
# Adjacent control (#651, fix round 1 N4): the raise must not have neutered the gate. The
# fixture is one line longer than the longest reference the budget holds, and the suite's
# own budget predicate, run in a subshell, must report the failure. A REF_BUDGET-derived
# fixture cannot see the constant move — raise REF_BUDGET and the fixture scales with it —
# so the fixture comes from the files: a gate rebuilt around a raised constant accepts it
# and this control fails. Restored with the gate in PR #860's review round (F11).
ctl="$(mktemp)"
budget_max=0
for f in "$EXEC_MD" "$NESTED_MD" "$PRBRIEFS_MD" "$BRIEFS_MD" "$WRITER_MD"; do
  b_n="$(wc -l < "$f" | tr -d ' ')"
  [ "$b_n" -gt "$budget_max" ] && budget_max="$b_n"
done
awk -v n="$((budget_max + 1))" 'BEGIN { for (i = 0; i < n; i++) print "x" }' > "$ctl"
parent_fail="$FAIL"
ctl_fail="$( budget "$ctl" "control: one line over the longest budgeted reference is refused" >/dev/null 2>&1; printf '%s' "$FAIL" )"
if [ "$ctl_fail" -eq $((parent_fail + 1)) ]; then
  pass "control: one line over the longest budgeted reference is refused"
else
  fail "control: one line over the longest budgeted reference is refused" "accepted $((budget_max + 1)) lines at REF_BUDGET=$REF_BUDGET — the longest budgeted reference is $budget_max lines; lower REF_BUDGET to $budget_max"
fi
rm -f "$ctl"

# #514, L1: the shape, asserted rather than assumed — a counter re-copied into any
# suite shadows the hoisted one and keeps passing. This suite's copies were the
# largest, so it is also the one most worth asserting from.
section "the hoisted counters are not re-copied"
assert_hoisted_counters

report
