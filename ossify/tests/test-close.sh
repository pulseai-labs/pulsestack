#!/usr/bin/env bash
# close (Task 9) — the router + the work-item close layer.
#
# SCOPE, stated plainly so nobody infers coverage that does not exist.
#
# COVERED here: the mechanical verbs the router's and the gate's prose name,
# driven through `bin/oss` (which runs `set -euo pipefail`, so a strict-mode-only
# fault is visible), plus the two producer/consumer seams this layer sits on —
# the standalone path reconstruction, and the state-recorded merge target.
#
# NOT COVERED, and not coverable by a bash test: **the router itself, the
# four-layer gate's ordering, the halt semantics and the recovery menu are
# prose contracts with no executable surface**. Task 13's bash-block harness
# checks that every `oss` verb they name resolves; beyond that they have no
# automated coverage in this release. An assertion that "each id shape routes to
# its own scope" would be testing `oss id_parse` (already covered in
# test-id.sh), not the router — the router is prose, and a test whose subject is
# a fixture written to satisfy it proves nothing.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"

# Sourced HERE, not beside the first spine-close extraction further down: the
# impl-check halt-loop extraction at §Task-13 runs earlier in the file, and a
# function defined after its first call site is a definition-after-use bug —
# the same ordering class as a guard placed after the mutation it protects.
. "$HERE/lib/blocks.sh"
_extract_block() { # $1=source-md $2=anchor identifying the block $3=out-path
  oss_block_extract "$1" "$2" "$3"
}
for lib in id state manifest commands entities registries ledger demo doctor verify worktree; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
SKILLS="$HERE/../skills"
TMP="$(mktemp -d)"

# ---------------------------------------------------------------------------
# A. Routing mechanics, through the dispatcher.
# ---------------------------------------------------------------------------
t_capture bash "$OSS" id_parse r2.s1.w3
t_assert_rc 0 "dispatcher: a work-item id parses under set -euo pipefail"
t_assert_eq "work_item 2 1 3" "$T_OUT" "id_parse echoes the scope AND the numeric components on ONE line"
t_assert_eq "work_item" "$(printf '%s\n' "$T_OUT" | awk '{print $1}')" "the routing key is the FIRST FIELD of that line"
# The trap the routing prose exists to prevent: a router that equality-tests the
# whole line against the bare scope word falls through every arm and closes
# nothing while reporting success. Assert the whole line is NOT the bare word.
if [ "$T_OUT" = "work_item" ]; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: id_parse returned a bare scope word - the first-field rule would be untestable"
else
  T_PASS=$((T_PASS+1))
fi

t_capture bash "$OSS" id_parse r2.s1
t_assert_eq "spine 2 1" "$T_OUT" "a spine id parses to scope + components"
t_assert_eq "spine" "$(printf '%s\n' "$T_OUT" | awk '{print $1}')" "spine routes on the first field"
t_capture bash "$OSS" id_parse r2
t_assert_eq "release 2" "$T_OUT" "a release id parses to scope + components"
t_assert_eq "release" "$(printf '%s\n' "$T_OUT" | awk '{print $1}')" "release routes on the first field"

# An unparseable id is rc 1 with EMPTY stdout AND EMPTY stderr - which is why the
# one-line error is the skill's to emit. t_capture merges the two streams, so
# capture them separately here or the stderr half cannot fail.
_UP_OUT="$(bash "$OSS" id_parse "VS-1.1.1" 2>/dev/null)"; _UP_RC=$?
_UP_ERR="$(bash "$OSS" id_parse "VS-1.1.1" 2>&1 >/dev/null)"
t_assert_eq "1" "$_UP_RC" "an unparseable id exits rc 1 through the dispatcher (no strict-mode abort)"
t_assert_eq "" "$_UP_OUT" "...with empty stdout"
t_assert_eq "" "$_UP_ERR" "...and empty stderr - the lib says nothing, so the skill must"

# ---------------------------------------------------------------------------
# B. The fixture, and the standalone path reconstruction the work-item layer
#    performs when it is invoked with an id and nothing else.
# ---------------------------------------------------------------------------
mkdir -p "$TMP/ws/.workspace" "$TMP/canon"
CANON="$TMP/canon"
git -C "$CANON" init -q
git -C "$CANON" config user.email t@t; git -C "$CANON" config user.name t
echo seed > "$CANON/f.txt"; git -C "$CANON" add .; git -C "$CANON" commit -qm seed
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$CANON"},"well_known_paths":{}}
EOF
cd "$TMP/ws"

bash "$OSS" init "close-fixture" >/dev/null
REL="$(bash "$OSS" release_add "first" "a goal")"
SP="$(bash "$OSS" spine_add "$REL" "ledger export" flesh)"
WI="$(bash "$OSS" work_item_add "$SP" "emit the export file")"
SPINE_SLUG="ledger-export"
WI_SLUG="emit-export-file"

AI_ROOT="$(bash "$OSS" repo_root ai_workspace)"
t_assert_eq "$TMP/ws" "$AI_ROOT" "repo_root ai_workspace resolves to the manifest's ai workspace"

# Build the docs tree from the ID GRAMMAR's own layout function, not from a path
# this test invents - so the reconstruction recipe below is cross-checked against
# an independent producer rather than against itself.
SPINE_DIR_REL="$(bash "$OSS" spine_dir "$REL" "$SP" "$SPINE_SLUG")"
case "$SPINE_DIR_REL" in
  /*) T_FAIL=$((T_FAIL+1)); echo "FAIL: spine_dir returned an ABSOLUTE path - the recipe prefixes it with the ai root";;
  *)  T_PASS=$((T_PASS+1));;
esac
mkdir -p "$AI_ROOT/$SPINE_DIR_REL/work-$WI"

# The recipe: id components -> release id + spine id -> glob for the slug.
PARTS="$(bash "$OSS" id_parse "$WI")"
REL_ID="r$(printf '%s\n' "$PARTS" | awk '{print $2}')"
SPINE_ID="$REL_ID.s$(printf '%s\n' "$PARTS" | awk '{print $3}')"
t_assert_eq "$REL" "$REL_ID" "the release id recomposed from id_parse's components matches the minted release id"
t_assert_eq "$SP" "$SPINE_ID" "the spine id recomposed from id_parse's components matches the minted spine id"

MATCHES="$(find "$AI_ROOT/docs/specs/$REL_ID" -maxdepth 1 -type d -name "$SPINE_ID-*" 2>/dev/null)"
NMATCH="$(printf '%s\n' "$MATCHES" | grep -c . || true)"
t_assert_eq "1" "$NMATCH" "the glob finds exactly one spine directory (zero or two is a halt, never head -1)"
RESOLVED_WI_DIR="$MATCHES/work-$WI"
if [ -d "$RESOLVED_WI_DIR" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the standalone reconstruction ($RESOLVED_WI_DIR) does not point at the directory the id grammar names"
fi
# The slug recovery the spine-branch name depends on.
RECOVERED_SLUG="$(basename "$MATCHES")"; RECOVERED_SLUG="${RECOVERED_SLUG#"$SPINE_ID-"}"
t_assert_eq "$SPINE_SLUG" "$RECOVERED_SLUG" "the spine slug is recoverable from the directory name (nothing persists it)"

SPEC="$RESOLVED_WI_DIR/spec.md"
REPORT="$RESOLVED_WI_DIR/report.md"
# The arrow is U+2192; the AC grammar splits on it and an ASCII '->' does not parse.
printf '%s\n' \
  '## 5. Acceptance criteria' \
  '- [ ] AC-1 auto: `true` → expected: exit 0' \
  '- [ ] AC-2 auto: `false` → expected: exit 0' \
  '- [X] AC-3 auto: `echo ready` → expected: output contains ready' \
  '- [ ] AC-4 user: run the export and see the file appear' > "$SPEC"

t_capture bash "$OSS" verify_acs "$SPEC"
t_assert_rc 0 "the resolved spec feeds verify_acs - rc 0, not rc 2 'spec not found'"
# Negative control: drop the slug (the one segment nothing persists) and the same
# call is rc 2. This is what makes the glob load-bearing rather than decorative.
t_capture bash "$OSS" verify_acs "$AI_ROOT/docs/specs/$REL_ID/$SPINE_ID/work-$WI/spec.md"
t_assert_rc 2 "dropping the spine slug yields 'spec not found' rc 2 - the glob is load-bearing"

# Cross-file prose contract: the work-item docs path shape is declared in two
# skills - the lane that WRITES the handoff there and the layer that READS the
# spec back. A drift between them has no runtime signal at all; the close layer
# just resolves to a directory that has never existed.
_PATH_SHAPE='docs/specs/<release-id>/<spine-id>-<spine-slug>/work-<wi-id>'
for f in "$SKILLS/close/references/work-item-close.md" "$SKILLS/work-item/references/round-orchestration.md"; do
  if grep -Fq "$_PATH_SHAPE" "$f"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: $(basename "$f") does not declare the work-item docs path shape '$_PATH_SHAPE'"
  fi
done

# The orphan rule - every references/*.md under a skill must be pointed at from
# that skill's own SKILL.md - is enforced in test-skill-bash-blocks.sh (check 5),
# across all five skills rather than close/ alone. The loop that lived here
# covered 10 of the 43 reference files; two enforcers of one rule is one too
# many, so this one was removed when the harness landed.

# ---------------------------------------------------------------------------
# C. The spine branch, the worktree, and the gate's two mechanical layers.
# ---------------------------------------------------------------------------
BASE_BRANCH="$(git -C "$CANON" rev-parse --abbrev-ref HEAD)"
SPINE_BRANCH="$(bash "$OSS" branch_name "$SP" "$SPINE_SLUG")"
git -C "$CANON" checkout -q -b "$SPINE_BRANCH"
# A commit only the spine branch has, made BEFORE the worktree is spawned -
# otherwise every reachability assertion below is vacuously true.
echo spine-only > "$CANON/spine.txt"
git -C "$CANON" add spine.txt; git -C "$CANON" commit -qm "spine-only commit"

WT="$(bash "$OSS" worktree_add canonical "$WI" "$WI_SLUG" "$SPINE_BRANCH")"
bash "$OSS" work_item_exec "$WI" "$(git -C "$WT" rev-parse --abbrev-ref HEAD)" "$WT" "$(git -C "$WT" rev-parse HEAD)" >/dev/null

# Layer 1 composes: EVERY row verify_acs emits must be grammar-valid to
# verify_step. If the expectation extraction ever drifts (leaving the raw
# '→ expected:' text in the field), every row comes back rc 2 "unrecognized
# expectation" and the whole gate fails closed on every AC - green rows and
# broken rows alike. Neither half's own unit test can see that: they are each
# driven with hand-written arguments.
_ROWS=0; _MALFORMED=0
while IFS="$(printf '\t')" read -r _label _cmd _exp; do
  [ -n "$_label" ] || continue
  _ROWS=$((_ROWS+1))
  bash "$OSS" verify_step "$WT" "$_cmd" "$_exp" >/dev/null 2>&1
  [ $? -eq 2 ] && _MALFORMED=$((_MALFORMED+1))
done < <(bash "$OSS" verify_acs "$SPEC")
t_assert_eq "3" "$_ROWS" "verify_acs emits one row per auto: AC and skips the user: row"
t_assert_eq "0" "$_MALFORMED" "every row verify_acs emits is grammar-valid to verify_step (never rc 2)"

AC2_CMD="$(bash "$OSS" verify_acs "$SPEC" | awk -F'\t' '$1=="AC-2"{print $2}')"
AC2_EXP="$(bash "$OSS" verify_acs "$SPEC" | awk -F'\t' '$1=="AC-2"{print $3}')"
t_assert_eq "false" "$AC2_CMD" "the command field arrives backtick-stripped and directly runnable"
t_assert_eq "exit 0" "$AC2_EXP" "the expectation field is the bare grammar, not the raw '→ expected:' text"
t_capture bash "$OSS" verify_step "$WT" "$AC2_CMD" "$AC2_EXP"
t_assert_rc 1 "a failing row driven with verify_acs's OWN output is rc 1 - distinguishable from a malformed rc 2, which is what lets halt-on-first-fail route to the right recovery option"

# The halt itself, executed FROM THE SHIPPED PROSE rather than from a copy of it
# retyped here. The loop is extracted out of impl-check.md and run under real
# strict mode against a spec whose second row fails and whose third row would
# leave a file behind - so "no later row ran" is a concrete observable, and the
# subject of the assertion is the file the ceremony actually ships.
#
# Both idioms in that block are silently wrong when written the obvious way:
# `oss verify_acs … | while …` puts the loop in a subshell (the halt is lost),
# and `if ! oss verify_step …; then rc=$?` captures the negation's zero (the
# halt never fires). Either mistake sails past a failing AC into layer 2 at rc 0.
SHIM="$TMP/shim"; mkdir -p "$SHIM"
printf '#!/usr/bin/env bash\nexec bash "%s" "$@"\n' "$OSS" > "$SHIM/oss"; chmod +x "$SHIM/oss"
# Extracted blocks invoke the dispatcher as `oss` by name — bind that name to the shim so
# every `env "PATH=$SHIM:$PATH" bash -c '. <block>'` below runs the real dispatcher.
export PATH="$SHIM:$PATH"
HALT_SPEC="$TMP/halt-spec.md"
printf '%s\n' \
  '- [ ] AC-1 auto: `true` → expected: exit 0' \
  '- [ ] AC-2 auto: `false` → expected: exit 0' \
  '- [ ] AC-3 auto: `touch third-row-ran` → expected: exit 0' > "$HALT_SPEC"
HALT_DIR="$TMP/halt-run"; mkdir -p "$HALT_DIR"
BLOCK="$TMP/halt-block.sh"
# Was a hand-rolled awk; now the shared harness like the other ten, so every
# extraction in this file is one `_extract_block <source-var> <anchor> <out>`
# line. test-block-ledger.sh check 4 resolves that source variable back to the
# ledger's file, which it cannot do when the path sits on a different line from
# the anchor.
IMPL_CHECK="$SKILLS/close/references/impl-check.md"
_extract_block "$IMPL_CHECK" 'while IFS=' "$BLOCK"
if grep -q 'verify_step' "$BLOCK" && grep -q 'while IFS=' "$BLOCK"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract the halt loop from impl-check.md - the assertions below are vacuous"
fi
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; wt='$HALT_DIR'; spec='$HALT_SPEC'; . '$BLOCK'"
t_assert_rc 1 "the shipped halt loop exits nonzero when a row fails - the halt reaches the caller"
t_assert_contains "$T_OUT" "[AC] AC-2" "...tagged [AC] and naming the failing row"
if [ -e "$HALT_DIR/third-row-ran" ]; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the row AFTER the failure still ran - halt-on-first-fail is not halting"
else
  T_PASS=$((T_PASS+1))
fi

# #951 D5: the verifier mutates in place, so close fingerprints the worktree
# before the dispatch and compares after the return. Executed from the shipped
# block: a clean restore compares equal; an unrestored edit to a staged file, a
# further edit to an already partly-staged file, and a stray file each halt.
VI_WT="$TMP/vi-wt"; mkdir -p "$VI_WT"
git -C "$VI_WT" init -q && printf 'a\n' > "$VI_WT/f" && printf 'p\n' > "$VI_WT/g" \
  && git -C "$VI_WT" add f g && git -C "$VI_WT" -c user.email=t@t -c user.name=t commit -qm base \
  && printf 'b\n' > "$VI_WT/f" && git -C "$VI_WT" add f && printf 'q\n' > "$VI_WT/g" && git -C "$VI_WT" add g && printf 'r\n' > "$VI_WT/g"
VI_BLOCK="$TMP/vi-block.sh"
VI_WIC="$SKILLS/close/references/work-item-close.md"
_extract_block "$VI_WIC" 'verifier identity:' "$VI_BLOCK"
t_capture bash -c "set -uo pipefail; wt='$VI_WT'; . '$VI_BLOCK'"
t_assert_rc 0 "verifier identity: the before-dispatch run succeeds"
VI_ID="${T_OUT#verifier identity: }"
case "$VI_ID" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: verifier identity block printed no hash: $T_OUT";; esac
VI_CMP="$TMP/vi-cmp.sh"; sed "s/^before=\"\"/before=\"$VI_ID\"/" "$VI_BLOCK" > "$VI_CMP"
t_assert_eq 1 "$(grep -c "^before=\"$VI_ID\"" "$VI_CMP")" "verifier identity: the compare copy carries the recorded value"
_vi_run() { t_capture bash -c "set -uo pipefail; wt='$VI_WT'; . '$VI_CMP'"; }
_vi_run; t_assert_rc 0 "verifier identity: an untouched worktree compares equal"
cp "$VI_WT/f" "$TMP/vi-f"; printf 'mutant\n' > "$VI_WT/f"; _vi_run
t_assert_rc 1 "verifier identity: an unrestored edit to a staged file halts"
t_assert_contains "$T_OUT" "close: verifier left $VI_WT changed - halt" "...with the named halt"
cp "$TMP/vi-f" "$VI_WT/f"; _vi_run; t_assert_rc 0 "verifier identity: a restore from the saved copy compares equal again"
cp "$VI_WT/g" "$TMP/vi-g"; printf 'mutant\n' > "$VI_WT/g"; _vi_run
t_assert_rc 1 "verifier identity: an edit to an already partly-staged file halts (status alone would not see it)"
cp "$TMP/vi-g" "$VI_WT/g"; : > "$VI_WT/stray"; _vi_run
t_assert_rc 1 "verifier identity: a stray file left in the worktree halts"
rm -f "$VI_WT/stray"
# #973.3f: a real non-repository reaches the cannot-fingerprint arm.
VI_NOT_GIT="$TMP/vi-not-git"; mkdir -p "$VI_NOT_GIT"
t_capture env "GIT_CEILING_DIRECTORIES=$TMP" bash -c "set -euo pipefail; wt='$VI_NOT_GIT'; . '$VI_BLOCK'"
t_assert_rc 1 "B13-F: cannot fingerprint a non-git worktree halts"
t_assert_contains "$T_OUT" "close: cannot fingerprint $VI_NOT_GIT for the verifier - halt" \
  "B13-F: cannot fingerprint names the worktree"

# #993: with --verdict the close recomputes the identity and compares it to the
# verdict's. Executed from the shipped block: a verdict written for this exact
# worktree passes; any change after the verdict (edit, stray file) halts, and the
# halt names both hashes.
VD_BLOCK="$TMP/vd-block.sh"
_extract_block "$VI_WIC" 'close: verdict identity' "$VD_BLOCK"
t_capture bash -c "set -uo pipefail; wt='$VI_WT'; . '$VI_BLOCK'"
VD_ID="${T_OUT#verifier identity: }"
t_capture bash -c "set -uo pipefail; wt='$VI_WT'; . '$VD_BLOCK'"
t_assert_rc 1 "verdict identity: a verdict carrying no identity halts"
_vd_run() { sed "s/^vid=\"\"/vid=\"${1}\"/" "$VD_BLOCK" > "$TMP/vd-cmp.sh"; t_capture bash -c "set -uo pipefail; wt='$VI_WT'; . '$TMP/vd-cmp.sh'"; }
_vd_run "$VD_ID"; t_assert_rc 0 "verdict identity: a verdict for this exact worktree passes"
_vd_run "deadbeef"; t_assert_rc 1 "verdict identity: a verdict for another state halts"
t_assert_contains "$T_OUT" "close: verdict identity deadbeef does not match" "...naming the verdict's identity"
printf 'x\n' > "$VI_WT/stray"; _vd_run "$VD_ID"
t_assert_rc 1 "verdict identity: a file added after the verdict halts"
rm -f "$VI_WT/stray"
_vd_run "$VD_ID"; t_assert_rc 0 "verdict identity: removing it restores the match"

# #434: close compares the spec with the blob id recorded at dispatch, before the gate.
# Executed from the shipped block (work-item-close.md §1). The fixture records the id through
# the real dispatcher, the way round-orchestration.md §3 does, and a sentinel line written
# AFTER the block stands for "the gate ran": a halt must stop before it.
SO_WI="$(bash "$OSS" work_item_add "$SP" "spec oid fixture")"
SO_DIR="$MATCHES/work-$SO_WI"; mkdir -p "$SO_DIR"
SO_SPEC="$SO_DIR/spec.md"; printf '## 5. Acceptance criteria\n- [ ] AC-1 auto: `true` → expected: exit 0\n' > "$SO_SPEC"
SO_BLOCK="$TMP/so-block.sh"
_extract_block "$VI_WIC" 'now_oid=' "$SO_BLOCK"
SO_GATE="$TMP/so-gate-ran"
_so_run() { rm -f "$SO_GATE"; t_capture bash -c "set -uo pipefail; cd '$TMP/ws'; export PATH='$HERE/../bin':\$PATH; wi='$SO_WI'; spec='$SO_SPEC'; . '$SO_BLOCK'; printf '%s' \"\$spec_note\" > '$TMP/so-note'; : > '$SO_GATE'"; }
# absent: a visible note, not a halt, and the note is kept for verify.md
_so_run
t_assert_rc 0 "spec check: an item with no recorded spec_oid still closes"
t_assert_contains "$T_OUT" "no dispatch-time spec value for $SO_WI: the spec check did not run" "spec check: ...and the note is printed"
t_assert_eq "no dispatch-time spec value for $SO_WI: the spec check did not run" "$(cat "$TMP/so-note")" "spec check: ...and held in \$spec_note for verify.md"
[ -e "$SO_GATE" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: spec check: the absent case did not reach the gate"; }
# recorded and equal: silent, continues
bash "$OSS" work_item_exec "$SO_WI" "work/$SO_WI" "$TMP/wt-so" "sha-so" "$(bash "$OSS" spec_oid "$SO_SPEC")" >/dev/null
_so_run
t_assert_rc 0 "spec check: an unchanged spec passes"
t_assert_eq "" "$T_OUT" "spec check: ...silently"
t_assert_eq "" "$(cat "$TMP/so-note")" "spec check: ...with no note"
# different: the named halt, both ids, both routes, and the gate is never reached
SO_REC="$(bash "$OSS" spec_oid "$SO_SPEC")"
cp "$SO_SPEC" "$TMP/so-spec.orig"; printf -- '- [ ] AC-2 auto: `true` → expected: exit 0\n' >> "$SO_SPEC"
SO_NOW="$(bash "$OSS" spec_oid "$SO_SPEC")"
_so_run
t_assert_rc 1 "spec check: an edited spec halts"
t_assert_contains "$T_OUT" "halt:spec-changed" "spec check: ...with the named halt"
t_assert_contains "$T_OUT" "$SO_NOW" "spec check: ...naming the id of the spec as it is now"
t_assert_contains "$T_OUT" "$SO_REC" "spec check: ...and the id dispatched"
t_assert_contains "$T_OUT" "restore the dispatched spec" "spec check: ...route 1, restore"
t_assert_contains "$T_OUT" "work_item_status $SO_WI planned" "spec check: ...route 2, return the item to planned"
[ -e "$SO_GATE" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: spec check: a changed spec still reached the gate"; } || T_PASS=$((T_PASS+1))
# an unreadable state is a halt (fails closed), not the "did not run" note
rm -f "$SO_GATE"; printf 'not json' > "$TMP/so-bad-state"
t_capture bash -c "set -uo pipefail; cd '$TMP/ws'; export PATH='$HERE/../bin':\$PATH OSS_STATE_FILE='$TMP/so-bad-state'; wi='$SO_WI'; spec='$SO_SPEC'; . '$SO_BLOCK'; : > '$SO_GATE'"
t_assert_rc 1 "spec check: an unreadable state halts"
t_assert_contains "$T_OUT" "cannot read $SO_WI's recorded spec value from state" "spec check: ...with the named read error"
case "$T_OUT" in *"did not run"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: spec check: a state read error printed the did-not-run note";; *) T_PASS=$((T_PASS+1));; esac
[ -e "$SO_GATE" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: spec check: an unreadable state still reached the gate"; } || T_PASS=$((T_PASS+1))
# the finish-merge row runs the same block with spec set from the spine dir, then the gate
t_capture bash -c "set -uo pipefail; cd '$TMP/ws'; export PATH='$HERE/../bin':\$PATH; wi='$SO_WI'; spec_dir='$MATCHES'; spec=\"\$spec_dir/work-\$wi/spec.md\"; . '$SO_BLOCK'; echo GATE"
t_assert_rc 1 "spec check: the finish-merge spelling (spec from the spine dir) halts on a mismatch too"
case "$T_OUT" in *GATE*) T_FAIL=$((T_FAIL+1)); echo "FAIL: spec check: finish-merge reached the gate after a mismatch";; *) T_PASS=$((T_PASS+1));; esac
# the dispatcher's recorded value is unchanged by the failed close (no in-place refresh)
t_assert_eq "$SO_REC" "$(bash "$OSS" get ".work_items[] | select(.id==\"$SO_WI\") | .spec_oid")" "spec check: the halt did not touch the recorded value"
# restored: equal again
cp "$TMP/so-spec.orig" "$SO_SPEC"
_so_run
t_assert_rc 0 "spec check: the restored spec passes again"
t_assert_eq "" "$T_OUT" "spec check: ...silently (so the halt above was caused by the edit)"
# a repair re-dispatch with 4 arguments keeps the value, so the check still sees the edit
bash "$OSS" work_item_exec "$SO_WI" "work/$SO_WI" "$TMP/wt-so2" "sha-so2" >/dev/null
printf 'x\n' >> "$SO_SPEC"; _so_run
t_assert_rc 1 "spec check: after a 4-argument re-dispatch the recorded id is still compared"
cp "$TMP/so-spec.orig" "$SO_SPEC"
# the fixture item must not leave an incomplete item behind for the spine-close tests below
bash "$OSS" work_item_status "$SO_WI" complete >/dev/null

# Layer 2 - report cross-check. Assert the LIB's real message; the
# `[report cross-check]` prefix is the skill's surfacing convention and appears
# in no lib, so a ceremony grepping for it would find nothing forever.
printf '%s\n' '| AC | Status |' '| AC-1 | pass |' '| AC-3 | pass |' > "$REPORT"
t_capture bash "$OSS" report_cross_check "$REPORT" "$SPEC"
t_assert_rc 1 "report_cross_check fails when the report omits an auto: AC"
t_assert_contains "$T_OUT" "oss: report does not account for:" "...with the lib's real message"
t_assert_contains "$T_OUT" "AC-2" "...naming the missing AC"
case "$T_OUT" in
  *'[report cross-check]'*) T_FAIL=$((T_FAIL+1)); echo "FAIL: the lib emitted the skill's surfacing tag - prose may now legitimately grep for it";;
  *) T_PASS=$((T_PASS+1));;
esac
printf '%s\n' '| AC-2 | fail |' >> "$REPORT"
t_capture bash "$OSS" report_cross_check "$REPORT" "$SPEC"
t_assert_rc 0 "...and passes once every auto: AC is accounted for (so the failing case above failed for the stated reason)"

# ---------------------------------------------------------------------------
# D. The merge seam: the target this layer hands `git merge` comes from STATE,
#    written by the execution lane. A merge onto the wrong branch is rc 0.
# ---------------------------------------------------------------------------
# `oss get` is `jq -r`: an absent field prints the four characters `null`, which
# is non-empty. A bare `[ -n "$b" ]` guard passes it straight through to
# `git merge null`, so the guard has to reject the literal too.
STATE_BRANCH="$(bash "$OSS" get ".work_items[] | select(.id==\"$WI\") | .branch")"
if [ -n "$STATE_BRANCH" ] && [ "$STATE_BRANCH" != "null" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: work_items[].branch is '$STATE_BRANCH' - close has no merge target and cannot recover one"
fi
t_assert_eq "$(bash "$OSS" work_item_branch "$WI" "$WI_SLUG")" "$STATE_BRANCH" "the recorded merge target matches the id grammar's own branch name"
if git -C "$CANON" rev-parse --verify --quiet "refs/heads/$STATE_BRANCH" >/dev/null; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the recorded merge target '$STATE_BRANCH' does not name a real ref"
fi

echo item > "$WT/item.txt"
git -C "$WT" add item.txt
t_assert_contains "$(git -C "$WT" diff --cached --name-only)" "item.txt" "the staging proof sees a non-empty index before the commit"
git -C "$WT" commit -qm "work item"
WI_SHA="$(git -C "$WT" rev-parse HEAD)"

t_assert_eq "$SPINE_BRANCH" "$(git -C "$CANON" rev-parse --abbrev-ref HEAD)" "canonical is parked on the spine branch when the merge runs (the guard's precondition)"
if git -C "$CANON" merge-base --is-ancestor "$WI_SHA" "$SPINE_BRANCH"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: fixture is vacuous - the work-item commit is already on the spine branch before the merge"
else
  T_PASS=$((T_PASS+1))
fi
t_capture git -C "$CANON" merge --no-ff -m "merge $WI" "$STATE_BRANCH"
t_assert_rc 0 "merging the STATE-recorded branch onto the parked spine branch succeeds"
if git -C "$CANON" merge-base --is-ancestor "$WI_SHA" "$SPINE_BRANCH"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the work-item commit is NOT reachable from the spine branch after the merge"
fi
if git -C "$CANON" merge-base --is-ancestor "$WI_SHA" "$BASE_BRANCH"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: negative control is vacuous - the commit reached $BASE_BRANCH without a merge there"
else
  T_PASS=$((T_PASS+1))
fi

# The cleanup-ordering claim work-item-close.md §6 makes, as a contrast rather
# than a single rc: a MERGED work-item branch removes cleanly, an unmerged one
# refuses rc 8. (The standalone rc-8 case is also asserted in test-worktree.sh;
# here it is the pairing that carries the meaning - cleanup can only succeed
# AFTER this layer's merge has landed.)
t_capture bash "$OSS" worktree_remove canonical "$WI"
t_assert_rc 0 "after the merge, worktree_remove succeeds and takes the branch with it"
if git -C "$CANON" show-ref --verify --quiet "refs/heads/$STATE_BRANCH"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the merged work-item branch survived cleanup"
else
  T_PASS=$((T_PASS+1))
fi
WI2="$(bash "$OSS" work_item_add "$SP" "second item")"
WT2="$(bash "$OSS" worktree_add canonical "$WI2" "second-item" "$SPINE_BRANCH")"
echo two > "$WT2/two.txt"; git -C "$WT2" add two.txt; git -C "$WT2" commit -qm "unmerged work"
# Round 4 (U-15p): cleanup now takes the branch from state, so record the
# exec first - without it the refusal below would come from the missing
# record, and this test would stop exercising the UNMERGED-branch refusal.
bash "$OSS" work_item_exec "$WI2" "$(git -C "$WT2" rev-parse --abbrev-ref HEAD)" "$WT2" "$(git -C "$WT2" rev-parse HEAD)" >/dev/null
t_capture bash "$OSS" worktree_remove canonical "$WI2"
t_assert_rc 8 "an UNMERGED work-item branch refuses cleanup rc 8 - which is why cleanup runs after the merge, not before"

# ---------------------------------------------------------------------------
# E. Spine close (Task 10). Every block below is EXTRACTED FROM THE SHIPPED
#    PROSE and executed under real strict mode, so the subject of each assertion
#    is the file the ceremony ships rather than a copy retyped here.
#
#    NOT COVERED, and not coverable: "apply-pending runs before the demo" and "a
#    failing demo halts before the critic, the harvest and cleanup" are orderings
#    of prose steps with no executable surface. A script that calls apply-pending
#    then demo_run asserts nothing about the ceremony - it tests a fixture
#    written to pass. Task 13's harness checks that every `oss` verb the prose
#    names resolves; beyond that those orderings have no coverage in this release.
# ---------------------------------------------------------------------------
SPINE_CLOSE="$SKILLS/close/references/spine-close.md"
# `_extract_block` is defined at the TOP of this file (see the note there).
# It delegates to the shared harness (#138), which REFUSES an anchor matching
# more than one block: the old inline awk stopped at the first match, so a
# duplicated anchor bound silently to whichever came first and would have
# silently REBOUND if a block were inserted above it. Every anchor used below
# is asserted unique, and bound to its source file, by test-block-ledger.sh.
OPEN_BLOCK="$TMP/spine-open.sh";  _extract_block "$SPINE_CLOSE" 'work items that are not complete' "$OPEN_BLOCK"
# The merge pass anchors on 'merge --no-ff', not 'is-ancestor' (#339): the PR
# record pass added its own --is-ancestor lineage guard, and the harness refuses
# an anchor matching two blocks — a duplicated 'is-ancestor' would bind to
# whichever block came first and silently REBIND when the other is edited.
MERGE_BLOCK="$TMP/spine-merge.sh"; _extract_block "$SPINE_CLOSE" 'merge --no-ff' "$MERGE_BLOCK"
PRRECORD_BLOCK="$TMP/spine-prrecord.sh"; _extract_block "$SPINE_CLOSE" 'mergeCommit' "$PRRECORD_BLOCK"
TOUCH_BLOCK="$TMP/spine-touch.sh"; _extract_block "$SPINE_CLOSE" 'touch_check' "$TOUCH_BLOCK"
for _pair in "$OPEN_BLOCK:work_items" "$MERGE_BLOCK:merge --no-ff" "$PRRECORD_BLOCK:mergeCommit" "$TOUCH_BLOCK:touch_check"; do
  _bf="${_pair%%:*}"; _bn="${_pair#*:}"
  if [ -s "$_bf" ] && grep -Fq "$_bn" "$_bf"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract '$_bn' from spine-close.md - the assertions below are vacuous"
  fi
done

# E1. Step 1 refuses and NAMES the offenders. `oss get` is jq -r without -e: a
# select matching nothing exits 0, so a block testing the rc instead of the
# output would close a spine with two unfinished items. Both ids must appear.
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; spine_id='$SP'; . '$OPEN_BLOCK'"
t_assert_rc 1 "step 1 halts when a work item is not complete"
t_assert_contains "$T_OUT" "$WI" "...naming the first offender by id"
t_assert_contains "$T_OUT" "$WI2" "...and the second - join(\", \") lists every one, not just the first"
bash "$OSS" work_item_status "$WI" complete >/dev/null
bash "$OSS" work_item_status "$WI2" complete >/dev/null
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; spine_id='$SP'; . '$OPEN_BLOCK'"
t_assert_rc 0 "...and passes once every item is complete (so the refusal above fired for the stated reason)"
t_assert_eq "" "$T_OUT" "...silently - a passing gate says nothing"

# E1b. The two EMPTY arms of the same gate (#533 half B), and the completeness of
# the route out the all-withdrawn halt names (#531 site 2, F15). Both fixtures live
# in their OWN workspace: a release minted in the E workspace would take the next
# id and shift the r1/r2/r3 the expiry fixtures below assert by name, and their own
# workspace also keeps the spine set of $REL untouched.
#   - a spine with NO work items ran nothing, exactly like a fully-withdrawn one;
#     before this the gate passed, the landing loop iterated an empty set, and the
#     session learned there was nothing to close only at step 5's changed-path
#     guard (or step 4's demo), with the harvest eight steps on.
#   - the withdrawn halt named only spine_status/work_item_status: it left out the
#     demo-ledger obligation (ledger_unplan for a pending amendment, but
#     ledger_retire/ledger_supersede for an ordinary active line whose only
#     implementation was withdrawn - ledger_unplan answers rc 7 there, which is the
#     wrong remedy this row pins) and the parked-repo restoration that the section
#     after next makes a property of the armed repos.
P2WS="$TMP/p2ws"; mkdir -p "$P2WS/.workspace"
printf '{"schema_version":"1.0","ai_workspace":{"root":"%s"},"canonical":{"root":"%s"},"well_known_paths":{}}\n' \
  "$P2WS" "$CANON" > "$P2WS/.workspace/pairing.json"
( cd "$P2WS" && bash "$OSS" init "phase-2 fixtures" >/dev/null )
P2REL="$(cd "$P2WS" && bash "$OSS" release_add "the empty arms" "fixtures")"
SPZERO="$(cd "$P2WS" && bash "$OSS" spine_add "$P2REL" "never decomposed" flesh)"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$P2WS'; set -euo pipefail; spine_id='$SPZERO'; . '$OPEN_BLOCK'"
t_assert_rc 1 "step 1 halts on a spine with NO work items"
t_assert_contains "$T_OUT" "no work items" "...naming the zero-item case as its own cause, not the withdrawn one"
t_assert_contains "$T_OUT" "work_item_add" "...and naming the way to give it items"
# With the repo argument NAMED: work_item_add's target_repo is optional only where
# the workspace declares a single repo (`_oss_default_repo_key` refuses to guess
# among several), so the bare two-argument form fails on any multi-repo project.
t_assert_contains "$T_OUT" "work_item_add $SPZERO <title> <target-repo>" "...with the target repo the verb requires once more than one is declared"
t_assert_contains "$T_OUT" "spine_status" "...and the retirement route, as the withdrawn arm does"
SPABAND="$(cd "$P2WS" && bash "$OSS" spine_add "$P2REL" "planned then emptied" flesh)"
WIA="$(cd "$P2WS" && bash "$OSS" work_item_add "$SPABAND" "withdrawn before dispatch")"
( cd "$P2WS" && bash "$OSS" work_item_status "$WIA" abandoned >/dev/null )
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$P2WS'; set -euo pipefail; spine_id='$SPABAND'; . '$OPEN_BLOCK'"
t_assert_rc 1 "step 1 halts when every item was withdrawn"
t_assert_contains "$T_OUT" "$WIA" "...naming the withdrawn item by id"
t_assert_contains "$T_OUT" "ledger_unplan" "...and naming the demo-ledger obligation for a PENDING amendment"
t_assert_contains "$T_OUT" "ledger_retire" "...and the retire/replace route for an ordinary active line (F15: ledger_unplan answers rc 7 there)"
# The ARITY and the KEY, both of which the shipped message got wrong: the verbs
# take <line> <by-spine> <reason> (lib/commands.sh declares _oss_need 3), and the
# amendment they record is applied by the CLOSE of the spine named there - so
# naming the retiring spine, as the first form did, leaves it pending forever.
t_assert_contains "$T_OUT" "ledger_retire <line-id> <spine-id> <reason>" "...with the by-spine argument the dispatcher requires, not the two-argument form that exits 2"
t_assert_contains "$T_OUT" "demo-amendments.md" "...and citing the document that owns the keying rule, so the operator can read why"
t_assert_contains "$T_OUT" "parked" "...and the parked-repo restoration §3 owns"
t_assert_contains "$T_OUT" "SPINE.md" "...and the medium that record goes to, since this halt writes no close record"
t_assert_contains "$T_OUT" "decomposition.md" "...and pointing at the whole-spine arm that owns the demo-ledger half"
# G2: the halted account has TWO owners and the message must name both - the
# armed-repo half lives in §3, which this halt exits before reaching, so a
# pointer to decomposition.md alone names a document that does not hold it.
t_assert_contains "$T_OUT" "3 below owns the armed-repo half" "...and at §3 for the armed-repo half, which the halt exits before reaching"
# ADJACENT CONTROL: the SAME workspace's spine with one PLANNED item still halts
# on the not-complete arm, so the two new arms did not swallow it, and a spine with
# one live item plus one withdrawn item still passes the gate (the loosening is
# EMPTY, not withdrawn - a partially withdrawn spine closes as before).
SPMIX="$(cd "$P2WS" && bash "$OSS" spine_add "$P2REL" "mixed" flesh)"
WIM1="$(cd "$P2WS" && bash "$OSS" work_item_add "$SPMIX" "live one")"
WIM2="$(cd "$P2WS" && bash "$OSS" work_item_add "$SPMIX" "withdrawn one")"
( cd "$P2WS" && bash "$OSS" work_item_status "$WIM2" abandoned >/dev/null )
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$P2WS'; set -euo pipefail; spine_id='$SPMIX'; . '$OPEN_BLOCK'"
t_assert_rc 1 "...a spine with a PLANNED item still halts on the not-complete arm"
t_assert_contains "$T_OUT" "$WIM1" "...naming the live offender"
( cd "$P2WS" && bash "$OSS" work_item_exec "$WIM1" "work/$WIM1" "$P2WS/.worktrees/$WIM1" "sha-wim1" >/dev/null )  # complete needs a dispatch (#563)
( cd "$P2WS" && bash "$OSS" work_item_status "$WIM1" complete >/dev/null )
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$P2WS'; set -euo pipefail; spine_id='$SPMIX'; . '$OPEN_BLOCK'"
t_assert_rc 0 "...and a spine with one completed and one withdrawn item PASSES the gate - the refusal is empty, not partially withdrawn"
t_assert_contains "$T_OUT" "withdrew work items before dispatch" "...with the note naming what it dropped, in the shipped wording"

# Move the BASE branch forward, the way a sibling spine closing first would.
# This is what makes the changed-path assertions in E5 non-vacuous: with the base
# still at the fork point every candidate computation agrees.
git -C "$CANON" checkout -q "$BASE_BRANCH"
echo sibling > "$CANON/sibling.txt"
git -C "$CANON" add sibling.txt; git -C "$CANON" commit -qm "a sibling spine landed on base"
git -C "$CANON" checkout -q "$SPINE_BRANCH"
SPINE_TIP="$(git -C "$CANON" rev-parse "$SPINE_BRANCH")"
if git -C "$CANON" merge-base --is-ancestor "$SPINE_TIP" "$BASE_BRANCH"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: fixture is vacuous - the spine tip is already on $BASE_BRANCH before any spine-close merge"
else
  T_PASS=$((T_PASS+1))
fi

_spine_unreached() { # $1=label ; the spine must NOT have landed on base
  if git -C "$CANON" merge-base --is-ancestor "$SPINE_TIP" "$BASE_BRANCH"; then
    T_FAIL=$((T_FAIL+1)); echo "FAIL: $1 - the spine reached $BASE_BRANCH anyway"
  else
    T_PASS=$((T_PASS+1))
  fi
}

# E2-E5 inject `repo_base_branches`, one "<repo>:<base_branch>" line per hosting
# repo, instead of a bare `base_branch` - Task 9 (#272/#310) turned the once-per-
# spine merge into a loop over every repo hosting the spine's items, keyed off
# `oss get .work_items[].target_repo`. This fixture declares one repo
# ("canonical"), and both $WI and $WI2 default to it, so the block's own loop
# resolves the very same single iteration the old single-repo form ran - the
# assertions below exercise the loop body's guards against that one hosting
# repo, not the multi-repo iteration itself (the same scope note
# round-orchestration.md's `checkout -q -b` row carries in block-ledger.tsv).
# The messages are BYTE-IDENTICAL to the old single-`canonical` wording,
# because the block interpolates the resolved repo NAME ("canonical") in
# exactly the position the old block hardcoded the literal word.

# E2. Canonical parked somewhere other than the spine branch. This is the guard
# the whole step turns on: reading the branch off HEAD instead of deriving it
# makes the switch-back a no-op, the merge "Already up to date" at rc 0, and
# every later step green against a tree the spine never reached. The reachability
# check CANNOT catch it - on a self-merge the tip is trivially its own ancestor.
git -C "$CANON" checkout -q "$BASE_BRANCH"
t_assert_eq "$BASE_BRANCH" "$(git -C "$CANON" rev-parse --abbrev-ref HEAD)" "the wrong-branch fixture really is parked off the spine branch (the guard's precondition)"
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches='canonical:$BASE_BRANCH'; . '$MERGE_BLOCK'"
t_assert_rc 1 "a spine close with canonical parked elsewhere halts BEFORE the merge"
t_assert_contains "$T_OUT" "canonical is on '$BASE_BRANCH', not '$SPINE_BRANCH'" "...naming both the branch it found and the branch it derived"
_spine_unreached "wrong-branch halt"

# E3. base_branch unresolvable for the hosting repo. The plan doc's
# spine-context section is the only record of it, so an empty read is
# reachable. Unguarded, `git checkout -q ""` fails at rc 128 and the ceremony
# merges the spine branch into ITSELF at rc 0.
git -C "$CANON" checkout -q "$SPINE_BRANCH"
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches=''; . '$MERGE_BLOCK'"
t_assert_rc 1 "an unresolvable base_branch halts"
t_assert_contains "$T_OUT" "no base_branch recorded for $SP" "...naming the spine whose base branch is missing"
t_assert_eq "$SPINE_BRANCH" "$(git -C "$CANON" rev-parse --abbrev-ref HEAD)" "...leaving canonical where it was"
_spine_unreached "empty base_branch halt"

# E3b. base_branch naming a branch that does not exist (a typo in the plan doc's
# spine-context line). The checkout fails, and its rc must be read.
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches='canonical:no-such-base'; . '$MERGE_BLOCK'"
t_assert_rc 1 "a base_branch naming no ref halts"
t_assert_contains "$T_OUT" "cannot check out base branch 'no-such-base'" "...from the checkout's own rc, naming the branch it could not reach"
_spine_unreached "missing base_branch halt"

# E4. base_branch resolving to a TRACKED FILE rather than a branch. `git checkout
# -q <tracked-file>` restores that file and exits 0 WITHOUT moving HEAD, so the
# checkout's rc says nothing - only asserting HEAD actually moved catches it.
git -C "$CANON" rev-parse --verify --quiet "refs/heads/f.txt" >/dev/null \
  && { T_FAIL=$((T_FAIL+1)); echo "FAIL: 'f.txt' names a branch here - the tracked-file case is not what this exercises"; }
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches='canonical:f.txt'; . '$MERGE_BLOCK'"
t_assert_rc 1 "a base_branch naming a tracked file halts even though the checkout exits 0"
t_assert_contains "$T_OUT" "switch-back left canonical on '$SPINE_BRANCH', not 'f.txt'" "...from the post-checkout HEAD assertion, not from the checkout's rc"
_spine_unreached "tracked-file base_branch halt"

# E5. The happy path, and the changed-path list the touch check reads. Both
# blocks run in ONE shell so $merge_shas really crosses the seam from step 2 to
# step 5 (repo:sha pairs, one per hosting repo - never a bash associative array)
# rather than being handed over by this test.
#
# Two bones make the path computation observable:
#   ADR-0101 covers the file only the SPINE changed  -> must HIT
#   ADR-0102 covers the file only the BASE changed   -> must NOT hit
# `git diff --name-only $base..$spine` after the merge names sibling.txt and NOT
# spine.txt - exactly inverted - so this pair fails loudly on that computation.
bash "$OSS" bone_add ADR-0101 "the surface the spine moved" "spine.txt" >/dev/null
bash "$OSS" bone_add ADR-0102 "a surface the spine never touched" "sibling.txt" >/dev/null
git -C "$CANON" checkout -q "$SPINE_BRANCH"
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches='canonical:$BASE_BRANCH'; . '$MERGE_BLOCK'; . '$TOUCH_BLOCK'"
t_assert_rc 0 "the merge block plus the touch block run clean end to end"
t_assert_eq "$BASE_BRANCH" "$(git -C "$CANON" rev-parse --abbrev-ref HEAD)" "the switch-back left canonical on the base branch"
if git -C "$CANON" merge-base --is-ancestor "$SPINE_TIP" "$BASE_BRANCH"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the spine tip is NOT reachable from $BASE_BRANCH after the merge"
fi
if git -C "$CANON" cat-file -e "$BASE_BRANCH:spine.txt" 2>/dev/null; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the spine's own file is absent from $BASE_BRANCH - the merge moved a ref but landed no content"
fi
t_assert_contains "$T_OUT" "bone ADR-0101" "the changed-path list contains the file the SPINE changed (the merge's own first-parent diff)"
case "$T_OUT" in
  *"ADR-0102"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: the changed-path list named a file only the BASE branch changed - this is 'git diff \$base..\$spine', which is inverted after the merge";;
  *) T_PASS=$((T_PASS+1));;
esac

# E5b. RESUME. E5 left canonical merged and parked on its base branch - exactly
# the state a close halted at step 5 leaves behind. Re-entering the merge block
# used to be impossible: it asserted HEAD == $spine_branch and halted on a repo
# it had itself finished, and $merge_shas (a shell variable) was gone, so §6's
# touch check had nothing to compute a first-parent diff from. The resume arm
# now lives inside the loop, so this is the same block run twice.
FIRST_MERGE="$(git -C "$CANON" rev-parse "$BASE_BRANCH")"
MERGES_BEFORE="$(git -C "$CANON" rev-list --merges --count "$BASE_BRANCH")"
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='$SP'; spine_slug='$SPINE_SLUG'; repo_base_branches='canonical:$BASE_BRANCH'; . '$MERGE_BLOCK'; printf 'PAIRS%s\n' \"\$merge_shas\""
t_assert_rc 0 "resume: the merge block re-runs clean against an already-landed repo"
t_assert_contains "$T_OUT" "already landed at $FIRST_MERGE" "resume: the landed repo is recognised and its merge sha reconstructed from history"
t_assert_contains "$T_OUT" "canonical:$FIRST_MERGE" "resume: \$merge_shas is repopulated for the landed repo - the touch check reads it"
t_assert_eq "$MERGES_BEFORE" "$(git -C "$CANON" rev-list --merges --count "$BASE_BRANCH")" "resume: no second, spurious merge commit was created"
t_assert_eq "$BASE_BRANCH" "$(git -C "$CANON" rev-parse --abbrev-ref HEAD)" "resume: the repo is left on its base branch"

# E5c. A PARTIAL changed-path list must halt, not read as clean. The per-repo
# diff loop used to sit inside a process substitution, so the outer loop saw its
# stdout and never its exit status: a repo failing AFTER an earlier one emitted
# paths contributed nothing silently, `$#` stayed non-zero, and touch_check ran
# over a list missing that repo's changes. The good pair comes FIRST here on
# purpose - that is the ordering the old form could not detect.
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; merge_shas='canonical:$FIRST_MERGE
nosuchrepo:$FIRST_MERGE'; . '$TOUCH_BLOCK'"
t_assert_rc 1 "a repo failing after another already emitted paths halts the touch check"
t_assert_contains "$T_OUT" "INCOMPLETE" "...and says the changed-path list would be incomplete"
case "$T_OUT" in
  *"touch check: clean"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: touch_check reported CLEAN over a partial path list - the exact false negative this guard exists to prevent";;
  *) T_PASS=$((T_PASS+1));;
esac

# E6. touch_check's three exit codes across four cases (zero paths, hit,
# clean, unreadable registry), read straight off the dispatcher.
t_capture bash "$OSS" touch_check
t_assert_rc 2 "touch_check with ZERO paths is rc 2 (could-not-check), NOT rc 1 (clean)"
t_assert_contains "$T_OUT" "needs at least one path" "...saying why"
t_capture bash "$OSS" touch_check spine.txt
t_assert_rc 0 "a path on a registered surface is rc 0 - a HIT, not a failure"
t_assert_eq "bone ADR-0101" "$T_OUT" "...printing the kind and the ref, which is what the reclassification reason quotes"
t_capture bash "$OSS" touch_check docs/unrelated.md
t_assert_rc 1 "a path on no registered surface is rc 1 - clean"
t_assert_eq "" "$T_OUT" "...with nothing on stdout"
BROKEN="$TMP/broken-state.json"; printf '%s\n' '{"schema_version":2}' > "$BROKEN"
t_capture env "OSS_STATE_FILE=$BROKEN" bash "$OSS" touch_check spine.txt
t_assert_rc 2 "a state whose bones registry is unreadable is rc 2 - INCONCLUSIVE, never clean"
t_assert_contains "$T_OUT" "INCONCLUSIVE, not clean" "...saying so in the lib's own words"

# E7. The shipped block's rc-2 arm: inconclusive must HALT, not fall through to
# the clean branch. Driven by pointing the block's touch_check at that same
# unreadable state. `merge_shas` is one "<repo>:<sha>" pair - the aggregation
# form §6 now reads, never a bare `merge_sha`/`canonical` pair (Task 9).
MERGE_SHA="$(git -C "$CANON" rev-parse "$BASE_BRANCH")"
t_capture env "PATH=$SHIM:$PATH" "OSS_STATE_FILE=$BROKEN" bash -c \
  "set -euo pipefail; merge_shas='canonical:$MERGE_SHA'; . '$TOUCH_BLOCK'"
t_assert_rc 1 "the shipped block HALTS on touch_check rc 2 rather than treating it as clean"
t_assert_contains "$T_OUT" "INCONCLUSIVE, not clean - halt" "...with the halt naming the reason"

# E8. A merge that changed no paths in the one hosting repo. touch_check would
# answer rc 2 for it, so the block halts BEFORE the call and says which of the
# two rc-2 causes this is.
git -C "$CANON" checkout -q -b empty-spine "$BASE_BRANCH"
echo transient > "$CANON/transient.txt"; git -C "$CANON" add transient.txt
git -C "$CANON" commit -qm "add a file"
git -C "$CANON" rm -q transient.txt; git -C "$CANON" commit -qm "and take it away again"
git -C "$CANON" checkout -q "$BASE_BRANCH"
git -C "$CANON" merge --no-ff empty-spine -m "a spine that netted no change" >/dev/null
EMPTY_MERGE="$(git -C "$CANON" rev-parse HEAD)"
t_assert_eq "" "$(git -C "$CANON" diff --name-only "$EMPTY_MERGE^1" "$EMPTY_MERGE")" "the empty-merge fixture really does change no path (the guard's precondition)"
t_capture env "PATH=$SHIM:$PATH" bash -c \
  "set -euo pipefail; merge_shas='canonical:$EMPTY_MERGE'; . '$TOUCH_BLOCK'"
t_assert_rc 1 "a merge that changed no paths halts"
t_assert_contains "$T_OUT" "the merge changed no paths" "...distinguishing the empty-input cause from an unreadable registry"

# ---------------------------------------------------------------------------
# F. Release close (Task 11). The two blocking gates, and THE FIXTURE SET IS THE
#    POINT.
#
#    The gates are read-only selectors, so unlike §E there is a real executable
#    subject here — but a selector test is worthless unless its fixtures
#    DISCRIMINATE. Three defective selectors are each individually green over the
#    obvious fixture pair:
#      * `status == "active"` alone      - green unless a RENEWED fake sits AT its
#                                          expiry (fixture b)
#      * `expiry == release` (identity)  - green unless an outstanding fake sits
#                                          BEFORE the closing release (fixture c)
#      * a STRING comparison of ids      - green until r10, because "r1" <= "r10"
#                                          is true and only "r2" <= "r10" is false
#                                          (fixture f)
#    Every assertion below names a concrete row, not a substring or a bare rc.
# ---------------------------------------------------------------------------
REL2="$(bash "$OSS" release_add "second" "a second goal")"
REL3="$(bash "$OSS" release_add "third" "a third goal")"
REL4="$(bash "$OSS" release_add "fourth" "a fourth goal")"
# Releases mint from r0 - the skeleton IS Release 0 - while spines and work
# items start at 1. The expiry fixtures below are keyed to these real ids, so
# pin the convention rather than assuming the r1-first shape the other two
# levels use.
t_assert_eq "r0" "$REL"  "the first release mints r0 - the skeleton is Release 0"
t_assert_eq "r1" "$REL2" "...and the second r1 (the expiry fixtures below name real releases)"
t_assert_eq "r2" "$REL3" "...and the third r2 - the closing release for the fixture set"
t_assert_eq "r3" "$REL4" "...and the fourth r3 - the at-or-before arm's second vantage point"

# The seven fixtures, built through the real verbs so the STORED shape is the
# subject - not a hand-written state blob that could disagree with what
# fake_add/fake_status actually write.
bash "$OSS" fake_add "f-active-at-r2"  fake "no sandbox yet"  "the vendor ships a sandbox" r2 >/dev/null
bash "$OSS" fake_add "f-renewed-at-r2" fake "no sandbox yet"  "the first live order"       r1 >/dev/null
bash "$OSS" fake_status "f-renewed-at-r2" renewed "still needed, one more release" r2 >/dev/null
bash "$OSS" fake_add "f-active-at-r1"  fake "deferred wiring" "the first second account"   r1 >/dev/null
bash "$OSS" fake_add "f-renewed-to-r5" fake "still too early" "the first paying user"      r1 >/dev/null
bash "$OSS" fake_status "f-renewed-to-r5" renewed "pushed out with a reason" r5 >/dev/null
bash "$OSS" fake_add "f-replaced-at-r2" fake "shell for now"  "the real adapter lands"     r2 >/dev/null
bash "$OSS" fake_status "f-replaced-at-r2" replaced "the real adapter landed in r1.s1" >/dev/null
bash "$OSS" fake_add "f-no-expiry"     fake "never dated"     "nobody wrote a condition"   "" >/dev/null

# PRECONDITIONS. A fixture that does not carry the property under test makes
# every assertion below vacuous - which is exactly how the old plan's fixture
# pair stayed green under the broken selector.
_fk() { bash "$OSS" get ".fakes[] | select(.boundary==\"$1\") | .$2"; }
t_assert_eq "renewed" "$(_fk f-renewed-at-r2 status)"          "fixture (b) really carries status=renewed"
t_assert_eq "r2"      "$(_fk f-renewed-at-r2 expiry_release)"  "...AND its expiry really moved to r2 - both halves, or (b) discriminates nothing"
t_assert_eq "active"  "$(_fk f-active-at-r1 status)"           "fixture (c) is outstanding"
t_assert_eq "r1"      "$(_fk f-active-at-r1 expiry_release)"   "...and expired BEFORE the closing release"
t_assert_eq "renewed" "$(_fk f-renewed-to-r5 status)"          "fixture (d) is renewed"
t_assert_eq "r5"      "$(_fk f-renewed-to-r5 expiry_release)"  "...to a LATER expiry - the renewal that legitimately does not block"
t_assert_eq "replaced" "$(_fk f-replaced-at-r2 status)"        "fixture (e) is the resolving status"
t_assert_eq "r2"      "$(_fk f-replaced-at-r2 expiry_release)" "...AT the closing release - so only .status can be excluding it"

# The r2 close. Assert the EXACT rows, tab-separated, not that output "contains"
# a boundary name.
TAB="$(printf '\t')"
t_capture bash "$OSS" expired_fakes r2
t_assert_rc 1 "expired_fakes returns rc 1 when the blocking set is NON-EMPTY (0=clean is the opposite polarity to touch_check)"
t_assert_eq "4" "$(printf '%s\n' "$T_OUT" | grep -c . || true)" "exactly four fakes block at r2 - a broader or narrower selector moves this number"
t_assert_contains "$T_OUT" "f-active-at-r2${TAB}active${TAB}r2${TAB}the vendor ships a sandbox" "(a) an ACTIVE fake at its expiry blocks, and the row carries boundary/status/expiry/trigger"
t_assert_contains "$T_OUT" "f-renewed-at-r2${TAB}renewed${TAB}r2${TAB}the first live order" "(b) THE DISCRIMINATING FIXTURE: a RENEWED fake at its expiry also blocks - an active-only selector drops exactly this row"
t_assert_contains "$T_OUT" "f-active-at-r1${TAB}active${TAB}r1${TAB}the first second account" "(c) an outstanding fake that expired EARLIER still blocks - an identity comparison drops exactly this row"
t_assert_contains "$T_OUT" "f-no-expiry${TAB}active${TAB}unparseable-expiry" "an expiry that cannot be parsed BLOCKS, marked - it can never fire, so skipping it makes the fake permanent"
case "$T_OUT" in
  *f-renewed-to-r5*) T_FAIL=$((T_FAIL+1)); echo "FAIL: (d) a fake renewed to a LATER expiry blocked - the gate is not reading expiry_release";;
  *) T_PASS=$((T_PASS+1));;
esac
case "$T_OUT" in
  *f-replaced-at-r2*) T_FAIL=$((T_FAIL+1)); echo "FAIL: (e) a REPLACED fake at its expiry blocked - replaced is the only resolving status";;
  *) T_PASS=$((T_PASS+1));;
esac

# (c) again at r3, the framing the at-or-before arm is named for: an r1 expiry
# two releases later.
t_capture bash "$OSS" expired_fakes r3
t_assert_rc 1 "...and at r3's close the gate still blocks"
t_assert_contains "$T_OUT" "f-active-at-r1${TAB}active${TAB}r1" "(c) an r1 expiry still blocks at r3 - at-or-before, not identity"

# (f) THE NUMERIC GUARD. jq evaluates "r2" <= "r10" as FALSE, so a string
# comparison silently stops blocking r2 expiries from the tenth release on.
# "r1" <= "r10" is TRUE, so fixture (c) canNOT catch this - only an r2-at-r10 row
# discriminates, which is why this assertion names f-active-at-r2 specifically.
t_assert_eq "false" "$(jq -n '"r2" <= "r10"')" "the lexicographic trap this fixture exists for is real (the guard's precondition)"
t_capture bash "$OSS" expired_fakes r10
t_assert_rc 1 "the gate blocks at r10"
t_assert_contains "$T_OUT" "f-active-at-r2${TAB}active${TAB}r2" "(f) an r2 expiry blocks at r10 - a STRING comparison drops exactly this row"
t_assert_contains "$T_OUT" "f-renewed-to-r5${TAB}renewed${TAB}r5" "...and the r5 renewal is due by r10 too, so the r10 set is genuinely wider than the r2 set"

# rc 0 = CLEAN, on a state with no outstanding fakes. Captured with stderr
# dropped: OSS_STATE_FILE emits an override notice that t_capture would merge in.
CLEANST="$TMP/clean-state.json"; printf '%s\n' '{"schema_version":2,"fakes":[],"demo_ledger":[]}' > "$CLEANST"
_CL_OUT="$(env "OSS_STATE_FILE=$CLEANST" bash "$OSS" expired_fakes r2 2>/dev/null)"; _CL_RC=$?
t_assert_eq "0" "$_CL_RC" "an empty blocking set is rc 0 - CLEAN (so every rc 1 above fired for the stated reason)"
t_assert_eq "" "$_CL_OUT" "...with nothing on stdout"

# rc 2, both causes, kept distinguishable from rc 1.
t_capture bash "$OSS" expired_fakes 3
t_assert_rc 2 "a bare release number is rc 2 on the fakes gate too (#759: one grammar on all three gates)"
t_capture bash "$OSS" expired_fakes "rX"
t_assert_rc 2 "a release argument that is not r<N> is rc 2 - could-not-check, never clean"
t_assert_contains "$T_OUT" "needs a release id of the form r<N>" "...saying why"
t_capture env "OSS_STATE_FILE=$BROKEN" bash "$OSS" expired_fakes r2
t_assert_rc 2 "a state whose fakes registry is unreadable is rc 2 - INCONCLUSIVE, never clean"
t_assert_contains "$T_OUT" "INCONCLUSIVE, not clean" "...in the lib's own words"

# (g) The quarantine twin.
bash "$OSS" ledger_add_auto "$SP" "the export still runs"  "true" "exit:0" >/dev/null
bash "$OSS" ledger_add_auto "$SP" "the report still opens" "true" "exit:0" >/dev/null
bash "$OSS" ledger_add_auto "$SP" "the archive still lists" "true" "exit:0" >/dev/null
bash "$OSS" ledger_quarantine d1 "flaky upstream, unrelated to any open spine" r1 >/dev/null
bash "$OSS" ledger_quarantine d2 "raised during this very release" r2 >/dev/null
bash "$OSS" ledger_quarantine d3 "nobody passed a release" "" >/dev/null

# THE FIELD-NAME TRAP, pinned so nobody "fixes" the selector back to `.release`.
# oss_ledger_quarantine builds a payload keyed `release`, but _oss_apply_op
# writes it onto the LINE as `.quarantined_in_release`. A selector written from
# the payload shape reads a key that exists on no line and every quarantine
# escapes at rc 0, forever.
t_assert_eq "r1" "$(bash "$OSS" get '.demo_ledger[] | select(.id=="d1") | .quarantined_in_release')" "the quarantine release is stored as .quarantined_in_release"
t_assert_eq "null" "$(bash "$OSS" get '.demo_ledger[] | select(.id=="d1") | .release')" "...and NOT as .release - the payload key is not the record key"
t_assert_eq "null" "$(bash "$OSS" get '.demo_ledger[] | select(.id=="d3") | .quarantined_in_release')" "an anchorless quarantine records no release key at all (the guard's precondition)"

t_capture bash "$OSS" expired_quarantines r2
t_assert_rc 1 "expired_quarantines is rc 1 when a ticket is owed - same polarity as the fake gate"
t_assert_eq "2" "$(printf '%s\n' "$T_OUT" | grep -c . || true)" "exactly two quarantines block at r2"
t_assert_contains "$T_OUT" "d1${TAB}r1${TAB}flaky upstream, unrelated to any open spine" "(g) a quarantine from an EARLIER release blocks, with its release and reason"
t_assert_contains "$T_OUT" "d3${TAB}no-release-anchor" "an anchorless quarantine blocks - a ticket with no release can never come due"
case "$T_OUT" in
  *d2*) T_FAIL=$((T_FAIL+1)); echo "FAIL: a quarantine raised in THIS release blocked - the comparison must be strictly earlier, or a close can never quarantine anything";;
  *) T_PASS=$((T_PASS+1));;
esac
_QC_OUT="$(env "OSS_STATE_FILE=$CLEANST" bash "$OSS" expired_quarantines r2 2>/dev/null)"; _QC_RC=$?
t_assert_eq "0" "$_QC_RC" "an empty quarantine set is rc 0 - CLEAN"
t_assert_eq "" "$_QC_OUT" "...with nothing on stdout"
t_capture bash "$OSS" expired_quarantines "r"
t_assert_rc 2 "a malformed release argument is rc 2 on the quarantine gate too"

# ---------------------------------------------------------------------------
# F2. The shipped branch blocks, EXTRACTED FROM THE PROSE and run under real
#     strict mode. The polarity is inverted relative to touch_check, so the arm
#     the ceremony actually branches on is the thing worth executing.
# ---------------------------------------------------------------------------
RELEASE_CLOSE="$SKILLS/close/references/release-close.md"
PATCH_LANE="$SKILLS/close/references/patch-lane.md"
SPINEGATE_BLOCK="$TMP/rel-spinegate.sh"; _extract_block "$RELEASE_CLOSE" 'spines that are not closed' "$SPINEGATE_BLOCK"
FAKEGATE_BLOCK="$TMP/rel-fakegate.sh";   _extract_block "$RELEASE_CLOSE" 'expired_fakes' "$FAKEGATE_BLOCK"
QUARGATE_BLOCK="$TMP/rel-quargate.sh";   _extract_block "$RELEASE_CLOSE" 'expired_quarantines' "$QUARGATE_BLOCK"
PATCH_BLOCK="$TMP/patch-touch.sh";       _extract_block "$PATCH_LANE"    'touch_check'         "$PATCH_BLOCK"
for _pair in "$SPINEGATE_BLOCK:open_spines" "$FAKEGATE_BLOCK:expired_fakes" "$QUARGATE_BLOCK:expired_quarantines" "$PATCH_BLOCK:touch_check"; do
  _bf="${_pair%%:*}"; _bn="${_pair#*:}"
  if [ -s "$_bf" ] && grep -Fq "$_bn" "$_bf"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract '$_bn' - the assertions below are vacuous"
  fi
done

# Step 1's gate. `oss get` is jq -r without -e, so a select matching nothing
# exits 0 - a block testing the rc closes a release with every spine still open.
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; rel='$REL'; . '$SPINEGATE_BLOCK'"
t_assert_rc 1 "step 1 halts when a spine is not closed"
t_assert_contains "$T_OUT" "$SP (planned)" "...naming the offender AND its status - planned and active are different problems"
bash "$OSS" spine_status "$SP" closed >/dev/null
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; rel='$REL'; . '$SPINEGATE_BLOCK'"
t_assert_rc 0 "...and passes once every spine is closed (so the refusal above fired for the stated reason)"
t_assert_eq "" "$T_OUT" "...silently. This is also the strict-mode trap: the block's LAST command is the abandoned test, and an '[ -n ] && echo' form would return 1 here and abort a clean close"

# The abandoned arm: not closed, but neither a silent pass nor a hard halt.
SP_AB="$(bash "$OSS" spine_add "$REL" "a spine we gave up on" flesh)"
bash "$OSS" spine_status "$SP_AB" abandoned >/dev/null
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; rel='$REL'; . '$SPINEGATE_BLOCK'"
t_assert_rc 0 "an abandoned spine does NOT hard-halt the release (it never reaches a close, so a refusal would be permanent)"
t_assert_contains "$T_OUT" "contains abandoned spines: $SP_AB" "...but it IS surfaced by name for an explicit confirmation - abandoned is not closed"

# Both blocking gates' branch arms, through the shipped case statements.
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; rel='r2'; . '$FAKEGATE_BLOCK'"
t_assert_rc 1 "the shipped fake-gate block HALTS on rc 1 - it does not read rc 1 as 'clean' the way a touch_check-shaped copy would"
t_assert_contains "$T_OUT" "f-renewed-at-r2" "...printing the blocking rows, including the renewed one"
t_assert_contains "$T_OUT" "replace or explicitly renew each" "...and naming the only two unblocks"
t_capture env "PATH=$SHIM:$PATH" "OSS_STATE_FILE=$CLEANST" bash -c "set -euo pipefail; rel='r2'; . '$FAKEGATE_BLOCK'"
t_assert_rc 0 "...and proceeds on rc 0"
t_assert_contains "$T_OUT" "fake expiry: clean" "...saying so"
t_capture env "PATH=$SHIM:$PATH" "OSS_STATE_FILE=$BROKEN" bash -c "set -euo pipefail; rel='r2'; . '$FAKEGATE_BLOCK'"
t_assert_rc 1 "the shipped block HALTS on rc 2 rather than degrading to clean"
t_assert_contains "$T_OUT" "INCONCLUSIVE, not clean - halt" "...with the halt naming the reason"

t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; rel='r2'; . '$QUARGATE_BLOCK'"
t_assert_rc 1 "the shipped quarantine block halts on an owed ticket"
t_assert_contains "$T_OUT" "quarantines owed from an earlier release" "...naming the finding"
t_capture env "PATH=$SHIM:$PATH" "OSS_STATE_FILE=$BROKEN" bash -c "set -euo pipefail; rel='r2'; . '$QUARGATE_BLOCK'"
t_assert_rc 1 "...and halts on rc 2 too"
t_assert_contains "$T_OUT" "INCONCLUSIVE, not clean - halt" "...distinguishing could-not-check from a real finding"

# The patch lane's mechanical two thirds. rc 0 is a HIT here - the opposite of
# the two gates above - so running the block proves the arms are not copied.
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; . '$PATCH_BLOCK' spine.txt"
t_assert_rc 0 "the patch-lane block runs clean over a path on a declared surface"
t_assert_contains "$T_OUT" "it is a spine, not a patch" "...and routes a bone-touching path AWAY from the lane (touch_check rc 0 is a HIT)"
t_capture env "PATH=$SHIM:$PATH" bash -c "set -euo pipefail; . '$PATCH_BLOCK' docs/unrelated.md"
t_assert_contains "$T_OUT" "the mechanical two thirds pass" "...and lets a path on no declared surface through (rc 1 is clean)"
t_capture env "PATH=$SHIM:$PATH" "OSS_STATE_FILE=$BROKEN" bash -c "set -euo pipefail; . '$PATCH_BLOCK' spine.txt"
t_assert_contains "$T_OUT" "route it as a spine" "...and resolves an INCONCLUSIVE check AGAINST the permissive lane"

# ---------------------------------------------------------------------------
# W1/W2: the two WRONG-BRANCH guards, which had zero executable coverage.
#
# A merge onto the wrong branch succeeds at rc 0. That shape caused three
# separate P0s in this series, and the guards written to stop it were themselves
# untested: deleting either left all 24 test files green. Both blocks are
# EXTRACTED from the shipped prose (never retyped) and run under real
# `set -euo pipefail`, so the subject is the artifact an agent will execute.
# ---------------------------------------------------------------------------
WIC="$SKILLS/close/references/work-item-close.md"
ROUND="$SKILLS/work-item/references/round-orchestration.md"

W_GUARD="$TMP/wi-guard.sh"; _extract_block "$WIC" 'abbrev-ref' "$W_GUARD"
# Anchored on `repo_bases` (the block's mktemp mapping), not on `checkout -q -b`
# as before: the re-entry arm's cut-missing repair also runs `checkout -q -b`,
# so that anchor now matches two blocks and oss_block_extract correctly refuses
# it as ambiguous (rc 2). `repo_bases` is scaffolding: it is created before the
# checks and consumed after them, so it survives the guards this test removes.
W_CUT="$TMP/spine-cut.sh";  _extract_block "$ROUND" 'repo_bases' "$W_CUT"
for _pair in "$W_GUARD:rev-parse --abbrev-ref" "$W_CUT:repo_bases"; do
  _bf="${_pair%%:*}"; _bn="${_pair#*:}"
  if [ -s "$_bf" ] && grep -Fq "$_bn" "$_bf"; then
    T_PASS=$((T_PASS+1))
  else
    T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract '$_bn' - the W1/W2 assertions below are vacuous"
  fi
done

# Both blocks resolve `canonical` via `oss repo_root`, so a caller-injected
# value is overwritten. Shim the resolver verbs to point at the scratch repo
# and delegate everything else to the real dispatcher. $3 doubles as the `oss
# get` return for whichever call site is under test: W1's guard now makes TWO
# `oss get` calls (Task 9, #272/#310 - `.target_repo` first, to resolve the
# item's own repo, then `.branch`), and only the second is $3's job - the
# first must answer "canonical" regardless of $3 so the guard's own
# `oss repo_root "$target_repo"` call lands on the first case arm below,
# exactly as W2's per-repo loop (round-orchestration.md §2) already needs for
# its one `target_repo` value to iterate. A case arm matching on the literal
# substring "target_repo" wins over the generic `"get "*` arm (case tries arms
# in order), so it answers BOTH calls the same way without knowing which test
# is running - and it does not disturb W2, whose own $3 was already
# "canonical" for the exact query this arm now intercepts.
_wshim() { # $1=dir-to-return $2=spine-branch $3=wi-branch-or-repo $4=shim-dir
  mkdir -p "$4"
  { printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/args.log"\ncase "$1 $2" in\n' "$4"
    printf '  "repo_root canonical") echo %s ;;\n' "$1"
    printf '  "branch_name "*)       echo %s ;;\n' "$2"
    printf '  *"target_repo"*)       echo canonical ;;\n'
    # #673 A6: the arm selector's second probe reads recorded execution state
    # (its jq names `dispatches`); "0" keeps this fixture on the fresh arm.
    printf '  *"dispatches"*)        echo 0 ;;\n'
    printf '  "spine_base_set "*)    : ;;\n'
    printf '  "get "*)               echo %s ;;\n' "$3"
    printf '  *) exec bash "%s" "$@" ;;\nesac\n' "$OSS"
  } > "$4/oss"; chmod +x "$4/oss"
}

# W1 — the work-item merge guard fires when canonical is parked elsewhere.
W1="$TMP/w1"; mkdir -p "$W1"; git -C "$W1" init -q
git -C "$W1" config user.email t@t; git -C "$W1" config user.name t
echo seed > "$W1/f"; git -C "$W1" add .; git -C "$W1" commit -qm seed
W1_BASE="$(git -C "$W1" rev-parse --abbrev-ref HEAD)"
git -C "$W1" branch "spine/r0.s1-ledger-export"
# A REAL work-item worktree with a REAL staged change, so the block can proceed
# past `git commit` and actually reach the merge. Without this the block dies on
# the placeholder commit and the rc assertion below passes for the wrong reason —
# the merge never runs, so removing the guard changes nothing observable.
W1_WT="$TMP/w1-wt"
git -C "$W1" worktree add -q -b "work/r0.s1.w1-emit" "$W1_WT" "spine/r0.s1-ledger-export"
echo emitted > "$W1_WT/export.txt"; git -C "$W1_WT" add export.txt
t_assert_eq "$W1_BASE" "$(git -C "$W1" rev-parse --abbrev-ref HEAD)" \
  "W1 setup: canonical is parked on the base branch, not the spine branch (the guard's precondition)"
t_assert_contains "$(git -C "$W1_WT" diff --cached --name-only)" "export.txt" \
  "W1 setup: the worktree has a staged change, so the block reaches the merge rather than dying at commit"
_wshim "$W1" "spine/r0.s1-ledger-export" "work/r0.s1.w1-emit" "$TMP/shim-w1"

t_capture env "PATH=$TMP/shim-w1:$PATH" bash -c \
  "set -euo pipefail; wi='r0.s1.w1'; wt='$W1_WT'; spine_id='r0.s1'; spine_slug='ledger-export'; . '$W_GUARD'"
t_assert_rc 1 "W1: the merge block HALTS when canonical is not on the spine branch"
t_assert_contains "$T_OUT" "not 'spine/r0.s1-ledger-export'" "W1: ...naming the branch it expected"
# THE LOAD-BEARING ASSERTION. A merge onto the wrong branch succeeds at rc 0, so
# an rc-only check cannot see it. Assert the base branch tip did not move: with
# the guard deleted the merge lands here and this is what goes red.
t_assert_eq "seed" "$(git -C "$W1" show -s --format=%s "$W1_BASE")" \
  "W1: the base branch tip is UNCHANGED - nothing was merged onto the wrong branch"
t_assert_eq "" "$(git -C "$W1" log --oneline "$W1_BASE" --grep='merge r0.s1.w1' 2>/dev/null)" \
  "W1: ...and no work-item merge commit exists on it"

# W2 — the spine cut must (a) CHECK OUT the branch rather than merely
# creating it, (b) cut from wherever the repo is CURRENTLY parked (HEAD), and
# (c) RECORD that observed base in state (#133) BEFORE the cut, so the re-entry
# arm's `cut-missing` repair has a recorded base to re-cut from. `git branch`
# leaves the repo on its previous branch and every downstream step still
# returns rc 0, which is precisely how the spine silently never receives the
# work.
W2="$TMP/w2"; mkdir -p "$W2"; git -C "$W2" init -q
git -C "$W2" config user.email t@t; git -C "$W2" config user.name t
echo seed > "$W2/f"; git -C "$W2" add .; git -C "$W2" commit -qm seed
W2_BASE="$(git -C "$W2" rev-parse --abbrev-ref HEAD)"
# Park canonical on a branch carrying a commit the default branch does not, so
# "cut from HEAD" is observably distinct from "cut from the default branch" and
# the sha assertion below cannot pass by coincidence.
git -C "$W2" checkout -q -b w2-parked
echo parked > "$W2/parked.txt"; git -C "$W2" add parked.txt
git -C "$W2" commit -qm parked
W2_PARKED_SHA="$(git -C "$W2" rev-parse w2-parked)"
# "canonical" is the value the per-repo loop's `oss get ... | .target_repo`
# must yield here - the loop calls `oss repo_root "$repo"` on whatever comes
# back, and only "canonical" resolves through this shim's first case arm.
_wshim "$W2" "spine/r0.s9-demo" "canonical" "$TMP/shim-w2"
# RUN IT WITH NOTHING INJECTED. An earlier revision of this test passed
# `base_branch=...` into the block, which made it blind to the block not
# assigning the variable at all - the lane then halted on every fresh run and
# every assertion here still passed. Under `set -u` a self-sufficient block is
# the thing under test, so supply it nothing.
t_capture env "PATH=$TMP/shim-w2:$PATH" bash -c "set -euo pipefail; . '$W_CUT'"
t_assert_rc 0 "W2: the shipped spine cut runs clean on a clean canonical with NOTHING injected"
t_assert_eq "spine/r0.s9-demo" "$(git -C "$W2" rev-parse --abbrev-ref HEAD)" \
  "W2: ...and leaves canonical CHECKED OUT on the spine branch - 'git branch' alone would leave it on w2-parked"
t_assert_eq "$W2_PARKED_SHA" "$(git -C "$W2" rev-parse spine/r0.s9-demo)" \
  "W2: ...cut from the branch canonical was parked on (the fresh arm cuts from HEAD and records it as the base)"
t_assert_contains "$(cat "$TMP/shim-w2/args.log")" "spine_base_set <spine-id> canonical w2-parked" \
  "W2: the fresh arm RECORDS each repo's base (#133) - the branch it was parked on"

# W2b — the fresh-arm block still refuses an existing spine branch: re-entry is
# a DIFFERENT block (§2's re-entry arm), chosen by the arm selector, never a
# half-reuse here. The message routes to that arm instead of an open issue.
t_capture env "PATH=$TMP/shim-w2:$PATH" bash -c "set -euo pipefail; . '$W_CUT'"
t_assert_rc 1 "W2b: a second fresh-arm run HALTS because the spine branch already exists"
t_assert_contains "$T_OUT" "already exists" "W2b: ...naming the collision"
t_assert_contains "$T_OUT" "re-entry arm" "W2b: ...and routing to the re-entry arm"

# W2c — a DETACHED HEAD has no branch name to record, so the lane must halt
# rather than cut a spine whose base_branch would be the literal string "HEAD".
W2C="$TMP/w2c"; mkdir -p "$W2C"; git -C "$W2C" init -q
git -C "$W2C" config user.email t@t; git -C "$W2C" config user.name t
echo seed > "$W2C/f"; git -C "$W2C" add .; git -C "$W2C" commit -qm seed
git -C "$W2C" checkout -q --detach HEAD
_wshim "$W2C" "spine/r0.s9-demo" "canonical" "$TMP/shim-w2c"
t_capture env "PATH=$TMP/shim-w2c:$PATH" bash -c "set -euo pipefail; . '$W_CUT'"
t_assert_rc 1 "W2c: a DETACHED HEAD halts - there is no branch name to record as base_branch"
t_assert_contains "$T_OUT" "DETACHED HEAD" "W2c: ...naming the condition"
t_assert_eq "" "$(git -C "$W2C" branch --list 'spine/*')" \
  "W2c: ...and cut no spine branch on the way out"

# W5 — the ARM SELECTOR (#362): an existing spine branch in any hosting repo
# selects re-entry; none selects fresh. Extracted from the shipped prose.
W_ARM="$TMP/arm.sh"; _extract_block "$ROUND" 'arm=' "$W_ARM"
[ -s "$W_ARM" ] && grep -Fq 'arm=' "$W_ARM" && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract the arm selector - W5 is vacuous"; }
W5="$TMP/w5"; mkdir -p "$W5"; git -C "$W5" init -q; git -C "$W5" config user.email t@t; git -C "$W5" config user.name t
echo s > "$W5/f"; git -C "$W5" add .; git -C "$W5" commit -qm s
_wshim "$W5" "spine/r0.s9-demo" "canonical" "$TMP/shim-w5"
t_capture env "PATH=$TMP/shim-w5:$PATH" bash -c "set -euo pipefail; . '$W_ARM'"
t_assert_rc 0 "W5: the selector runs clean with nothing injected"
t_assert_contains "$T_OUT" "arm=fresh" "W5: no spine branch -> fresh"
git -C "$W5" branch spine/r0.s9-demo
t_capture env "PATH=$TMP/shim-w5:$PATH" bash -c "set -euo pipefail; . '$W_ARM'"
t_assert_contains "$T_OUT" "arm=re-entry" "W5: an existing spine branch -> re-entry (the #362 per-round case)"
t_assert_eq "" "$(git -C "$W5" status --porcelain)" "W5: the selector mutates nothing"

# W5c (#673 A6) — the spine refs GONE while recorded execution state survives:
# the ref test alone picks `fresh`, whose §2a would record bases and CUT a new
# spine branch before §3's worktree_add collided with the surviving work -
# mutation before the promised halt. The second probe must halt instead.
W5C="$TMP/w5c"; mkdir -p "$W5C"; git -C "$W5C" init -q
git -C "$W5C" config user.email t@t; git -C "$W5C" config user.name t
echo s > "$W5C/f"; git -C "$W5C" add .; git -C "$W5C" commit -qm s
W5CS="$TMP/shim-w5c"; mkdir -p "$W5CS"
{ printf '#!/usr/bin/env bash\ncase "$1 $2" in\n'
  printf '  "repo_root canonical") echo %s ;;\n' "$W5C"
  printf '  "branch_name "*)       echo spine/r0.s9-demo ;;\n'
  printf '  *"target_repo"*)       echo canonical ;;\n'
  printf '  *"dispatches"*)        echo 1 ;;\n'
  printf '  "get "*)               echo canonical ;;\n'
  printf '  *) exec bash "%s" "$@" ;;\nesac\n' "$OSS"
} > "$W5CS/oss"; chmod +x "$W5CS/oss"
t_capture env "PATH=$W5CS:$PATH" bash -c "set -euo pipefail; . '$W_ARM'"
t_assert_rc 1 "W5c: recorded execution state with NO spine branch HALTS (not a fresh re-cut)"
t_assert_contains "$T_OUT" "refs are gone" "W5c: ...naming the surviving state"
t_assert_eq "" "$(git -C "$W5C" branch --list 'spine/*' | tr -d ' *')" "W5c: ...and cut nothing"
case "$T_OUT" in
  *arm=fresh*) T_FAIL=$((T_FAIL+1)); echo "FAIL: W5c: the deleted-ref shape still picked the fresh arm";;
  *) T_PASS=$((T_PASS+1));;
esac

# W5b (fix round 1, I1) — a failed work-item read HALTS; the selector must not
# pick an arm off an empty list. The pre-fix form read the repos inside the
# here-doc substitution, where `get`'s rc is uncatchable — reproduced with a
# shim that answers `get` with rc 2.
W5B="$TMP/shim-w5b"; mkdir -p "$W5B"
{ printf '#!/usr/bin/env bash\ncase "$1 $2" in\n'
  printf '  "branch_name "*) echo spine/r0.s9-demo ;;\n'
  printf '  *"target_repo"*) echo "oss: get: unreadable state" >&2; exit 2 ;;\n'
  printf '  *) exec bash "%s" "$@" ;;\nesac\n' "$OSS"
} > "$W5B/oss"; chmod +x "$W5B/oss"
t_capture env "PATH=$W5B:$PATH" bash -c "set -euo pipefail; . '$W_ARM'"
t_assert_rc 1 "W5b: a failed work-item read HALTS (not rc 0 with an empty list)"
t_assert_contains "$T_OUT" "cannot read the spine's work items" "W5b: ...naming the unreadable state"
case "$T_OUT" in
  *arm=fresh*) T_FAIL=$((T_FAIL+1)); echo "FAIL: W5b: the failed read still picked the fresh arm";;
  *) T_PASS=$((T_PASS+1));;
esac

# ---------------------------------------------------------------------------
# D1-D4: the cumulative-demo MEASUREMENT block. Timing is advisory; the demo
# result is the gate. Written as a bare `oss demo_run` with the budget report
# after it, the block's status becomes the trailing echo's — so a FAILING demo
# returns 0 and the close walks past the one gate it must not. Same shape as the
# W1/W2 wrong-branch class: the failure is invisible to an rc-only reading, so
# these assert the re-raised status, not just that the block ran.
# ---------------------------------------------------------------------------
CUMDEMO="$SKILLS/close/references/cumulative-demo.md"
# Anchor on `elapsed=`, not on `demo_rc`: the anchor has to survive the very
# regression these tests exist to catch, or removing the status capture would
# make the block unfindable and the failure would read as "vacuous" instead of
# as the wrong behaviour it is.
DEMO_BLOCK="$TMP/cum-demo.sh"; _extract_block "$CUMDEMO" 'elapsed=' "$DEMO_BLOCK"
if [ -s "$DEMO_BLOCK" ] && grep -Fq 'oss demo_run' "$DEMO_BLOCK"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract the demo measurement block - D1-D4 are vacuous"
fi

_dshim() { # $1=budget-to-echo $2=demo_run-rc $3=shim-dir
  mkdir -p "$3"
  { printf '#!/usr/bin/env bash\ncase "$1" in\n'
    printf '  get)      echo %s ;;\n' "$1"
    printf '  demo_run) exit %s ;;\n' "$2"
    printf '  *) exec bash "%s" "$@" ;;\nesac\n' "$OSS"
  } > "$3/oss"; chmod +x "$3/oss"
}

_dshim '60s' 0 "$TMP/shim-d0"
t_capture env "PATH=$TMP/shim-d0:$PATH" bash -c ". '$DEMO_BLOCK'"
t_assert_rc 0 "D1: a PASSING cumulative demo leaves the measurement block green"
t_assert_contains "$T_OUT" "within the 60s budget" "D1: ...and reports the timing"

# THE LOAD-BEARING ASSERTION. Drop the `|| demo_rc=$?` capture and the re-raise
# and this is the one that goes red - D1 stays green either way.
_dshim '60s' 1 "$TMP/shim-d1"
t_capture env "PATH=$TMP/shim-d1:$PATH" bash -c ". '$DEMO_BLOCK'"
t_assert_rc 1 "D2: a FAILING cumulative demo RE-RAISES its status - the close gate does not pass"
t_assert_contains "$T_OUT" "within the 60s budget" "D2: ...after the timing was still reported"
t_assert_contains "$T_OUT" "FAILED rc 1" "D2: ...naming the failure"

# D3 - the runner's exact status survives rather than being flattened to 1, and
# the no-budget branch does not mask it.
_dshim 'null' 3 "$TMP/shim-d3"
t_capture env "PATH=$TMP/shim-d3:$PATH" bash -c ". '$DEMO_BLOCK'"
t_assert_rc 3 "D3: the runner's exact status survives an absent budget"
t_assert_contains "$T_OUT" "no budget recorded" "D3: ...with the no-budget branch still taken"

# D4 - the capture must also survive `errexit`, where an unprotected `oss
# demo_run` would abort the block before the timing is ever reported.
_dshim '60s' 1 "$TMP/shim-d4"
t_capture env "PATH=$TMP/shim-d4:$PATH" bash -c "set -euo pipefail; . '$DEMO_BLOCK'"
t_assert_rc 1 "D4: the same failing demo re-raises under errexit"
t_assert_contains "$T_OUT" "within the 60s budget" "D4: ...and the timing is still reported first"

# ---------------------------------------------------------------------------
# #461/#496-F3: the quarantine-comparison block disposes of its per-invocation
# evidence dir on EVERY path. The mktemp -d holds full head/parent command
# output; left behind it accumulates one directory of (possibly sensitive)
# output per close. These drive the EXTRACTED block through its three exits -
# same output, differing output, and a halt mid-detach - and count the temp
# entries each leaves behind. The anchor is `evd=` (the mechanism), which
# survives the regression under test (a missing disposal).
# ---------------------------------------------------------------------------
QBLOCK="$TMP/quar-block.sh"; _extract_block "$CUMDEMO" 'evd=' "$QBLOCK"
if [ -s "$QBLOCK" ] && grep -Fq 'oss-head.txt' "$QBLOCK"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract the quarantine-comparison block - the F3 tests are vacuous"
fi

# A real repo with a merge commit: side changes f.txt, main adds main.txt, the
# --no-ff merge has a clean first parent. `cat f.txt` differs between the
# merge (side) and its first parent (base) without any conflict surgery.
QREPO="$TMP/qrepo"; mkdir -p "$QREPO"
git -C "$QREPO" init -q
git -C "$QREPO" config user.email t@t; git -C "$QREPO" config user.name t
echo base > "$QREPO/f.txt"; git -C "$QREPO" add f.txt; git -C "$QREPO" commit -qm base
git -C "$QREPO" checkout -qb side; echo side > "$QREPO/f.txt"; git -C "$QREPO" commit -qam side
git -C "$QREPO" checkout -q -; echo mainwork > "$QREPO/main.txt"
git -C "$QREPO" add main.txt; git -C "$QREPO" commit -qm main
git -C "$QREPO" merge --no-ff -qm "merge side" side
QSHA="$(git -C "$QREPO" rev-parse HEAD)"; QBR="$(git -C "$QREPO" rev-parse --abbrev-ref HEAD)"

# Shim `oss`: demo_workdir -> the repo (composition root); get -> the demo
# line's command; repo_root -> the repo path for the declared name, refusing
# anything else so a bad $merge_shas entry halts like the real verb.
_qshim() { # $1=shim-dir $2=command the demo line runs
  mkdir -p "$1"
  { printf '#!/usr/bin/env bash\ncase "$1" in\n'
    printf '  demo_workdir) echo "%s" ;;\n' "$QREPO"
    printf '  get) echo "%s" ;;\n' "$2"
    printf '  repo_root) [ "$2" = myrepo ] && echo "%s" || exit 1 ;;\n' "$QREPO"
    printf '  *) exit 2 ;;\nesac\n'
  } > "$1/oss"; chmod +x "$1/oss"
}

_qcount() { find "$QTMP" -mindepth 1 | wc -l | tr -d ' '; }
QTMP="$TMP/qtmp"; mkdir -p "$QTMP"

# Path 1 - same output on both trees: the diff is empty, the block is green,
# and nothing is left in TMPDIR.
_qshim "$TMP/qshim-same" 'echo same-output'
t_capture env "TMPDIR=$QTMP" "PATH=$TMP/qshim-same:$PATH" "merge_shas=myrepo:$QSHA" "QBLOCK=$QBLOCK" \
  bash -c 'set -euo pipefail; . "$QBLOCK"'
t_assert_rc 0 "F3a: same head/parent output closes the block green"
t_assert_eq "0" "$(_qcount)" "F3a: the evidence dir is disposed on the green path"
t_assert_eq "$QBR" "$(git -C "$QREPO" rev-parse --abbrev-ref HEAD)" "F3a: the repo is restored to its branch"

# Path 2 - genuinely different output: the diff is nonzero AND still the
# block's answer, and the evidence is still disposed on the differing path
# (an rm placed after a bare `diff` would never run there).
_qshim "$TMP/qshim-diff" 'cat f.txt'
t_capture env "TMPDIR=$QTMP" "PATH=$TMP/qshim-diff:$PATH" "merge_shas=myrepo:$QSHA" "QBLOCK=$QBLOCK" \
  bash -c 'set -euo pipefail; . "$QBLOCK"'
t_assert_rc 1 "F3b: a real head/parent difference still propagates the nonzero diff"
t_assert_eq "0" "$(_qcount)" "F3b: the evidence dir is disposed on the differing path too"
t_assert_eq "$QBR" "$(git -C "$QREPO" rev-parse --abbrev-ref HEAD)" "F3b: the repo is restored to its branch"

# Path 3 - a halt INSIDE the detach loop (second repo undeclared): the first
# repo is already detached when the block exits, so this asserts the trap
# restores it AND disposes of the evidence.
_qshim "$TMP/qshim-halt" 'cat f.txt'
t_capture env "TMPDIR=$QTMP" "PATH=$TMP/qshim-halt:$PATH" "merge_shas=myrepo:$QSHA
otherrepo:$QSHA" "QBLOCK=$QBLOCK" \
  bash -c 'set -euo pipefail; . "$QBLOCK"'
t_assert_rc 1 "F3c: an undeclared repo halts the block"
t_assert_contains "$T_OUT" "undeclared repo" "F3c: ...naming it"
t_assert_eq "0" "$(_qcount)" "F3c: the evidence dir is disposed on the halt path"
t_assert_eq "$QBR" "$(git -C "$QREPO" rev-parse --abbrev-ref HEAD)" "F3c: the half-detached repo is restored"

# Path 4 - the head/parent COMMAND failing is the NORMAL case: this block
# exists to investigate a quarantined (failing) demo line. Under `set -e` a
# bare `(...); echo rc=$?` capture aborts before the echo AND before the
# trap is armed - the dir leaks and the rc is never reported (R3-1). The
# capture must survive errexit and still print the command's status.
_qshim "$TMP/qshim-fail" 'echo err-out; exit 3'
t_capture env "TMPDIR=$QTMP" "PATH=$TMP/qshim-fail:$PATH" "merge_shas=myrepo:$QSHA" "QBLOCK=$QBLOCK" \
  bash -c 'set -euo pipefail; . "$QBLOCK"'
t_assert_rc 0 "F3d: a command failing identically on both trees still closes green (same evidence)"
t_assert_contains "$T_OUT" "head rc=3" "F3d: ...after REPORTING the head command's status"
t_assert_contains "$T_OUT" "parent rc=3" "F3d: ...and the parent command's"
t_assert_eq "0" "$(_qcount)" "F3d: the evidence dir is disposed on the failing-command path"
t_assert_eq "$QBR" "$(git -C "$QREPO" rev-parse --abbrev-ref HEAD)" "F3d: the repo is restored to its branch"

# Path 5 - a failing command whose OUTPUT differs between the trees: the
# diff is nonzero, and both statuses are still reported.
_qshim "$TMP/qshim-faildiff" 'cat f.txt; exit 3'
t_capture env "TMPDIR=$QTMP" "PATH=$TMP/qshim-faildiff:$PATH" "merge_shas=myrepo:$QSHA" "QBLOCK=$QBLOCK" \
  bash -c 'set -euo pipefail; . "$QBLOCK"'
t_assert_rc 1 "F3e: a failing command with differing output reports the difference"
t_assert_contains "$T_OUT" "head rc=3" "F3e: ...after reporting the head status"
t_assert_contains "$T_OUT" "parent rc=3" "F3e: ...and the parent status"
t_assert_eq "0" "$(_qcount)" "F3e: the evidence dir is disposed on the failing-differing path"
t_assert_eq "$QBR" "$(git -C "$QREPO" rev-parse --abbrev-ref HEAD)" "F3e: the repo is restored to its branch"

# Path 6 - the command lookup itself failing: a bare `cmd="$(...)"` would
# proceed with an EMPTY command under `set -u` (a false-green comparison of
# nothing), so the `||` guard halts before any evidence is created.
mkdir -p "$TMP/qshim-noget"
{ printf '#!/usr/bin/env bash\ncase "$1" in\n'
  printf '  demo_workdir) echo "%s" ;;\n' "$QREPO"
  printf '  get) exit 1 ;;\n'
  printf '  repo_root) [ "$2" = myrepo ] && echo "%s" || exit 1 ;;\n' "$QREPO"
  printf '  *) exit 2 ;;\nesac\n'
} > "$TMP/qshim-noget/oss"; chmod +x "$TMP/qshim-noget/oss"
t_capture env "TMPDIR=$QTMP" "PATH=$TMP/qshim-noget:$PATH" "merge_shas=myrepo:$QSHA" "QBLOCK=$QBLOCK" \
  bash -c 'set -euo pipefail; . "$QBLOCK"'
t_assert_rc 1 "F3f: an unresolvable demo command halts the block"
t_assert_contains "$T_OUT" "cannot resolve the demo command" "F3f: ...naming it"
t_assert_eq "0" "$(_qcount)" "F3f: nothing is left behind on the lookup-failure path"

# Path 7 - a signal DURING the diff (round 4): the diff reads both captured
# outputs, which can be large, so it is the plausible place a close gets
# killed. The `diff` shim SIGTERMs the block's own subshell; with the EXIT
# trap still armed through the diff the cleanup disposes of the evidence dir,
# with the trap disarmed beforehand it leaks exactly when the run is killed.
# rc 143 = 128+SIGTERM.
_qshim "$TMP/qshim-sig" 'echo same-output'
printf '#!/usr/bin/env bash\nkill -TERM "$PPID"\nsleep 2\n' > "$TMP/qshim-sig/diff"; chmod +x "$TMP/qshim-sig/diff"
t_capture env "TMPDIR=$QTMP" "PATH=$TMP/qshim-sig:$PATH" "merge_shas=myrepo:$QSHA" "QBLOCK=$QBLOCK" \
  bash -c 'set -euo pipefail; . "$QBLOCK"'
t_assert_rc 143 "F3g: a signal mid-diff terminates the block (128+15)"
t_assert_eq "0" "$(_qcount)" "F3g: the evidence dir is still disposed when the diff is killed"
t_assert_eq "$QBR" "$(git -C "$QREPO" rev-parse --abbrev-ref HEAD)" "F3g: the repo is restored to its branch"

# ---------------------------------------------------------------------------
# P-series — the PR tier at spine close (#339). A repo WITH a remote merges
# spine -> base by PR through /ossify:work-pr; the local --no-ff merge survives
# only where no remote exists (the E-series above already drives that arm on a
# repo with no origin). Every fixture here is a standalone repo with a BARE
# origin standing in for GitHub, plus a gh stub whose behavior is staged
# entirely from $GH_STATE files — the stub never touches a network, and each
# scenario stages its own remote reality.
# ---------------------------------------------------------------------------
PR_BRANCH="spine/r0.s5-tier"
GHSTUB="$TMP/ghbin"; mkdir -p "$GHSTUB"
# A quoted heredoc, NOT a printf format string: the stub's own printfs carry %s
# directives, and generating it through printf lets the OUTER format consume
# them - the stub lands with empty holes and every arm emits invalid JSON.
cat > "$GHSTUB/gh" <<'GHSTUB_EOF'
#!/usr/bin/env bash
# gh stub for the P-series: staged from $GH_STATE, no network.
set -u
st="${GH_STATE:?GH_STATE not set}"
# The blocks pin every call with a leading --repo <owner/repo> (T17): consume
# it the way the real gh does, and record it so a test can prove the pin.
while [ "${1:-}" = "--repo" ]; do
  printf '%s\n' "$2" > "$st/gh_repo"
  shift 2
done
case "$1" in
  pr)
    case "$2" in
      list)
        [ -f "$st/nongithub" ] && { echo "gh: HTTP 404 - not a GitHub repository" >&2; exit 1; }
        # Honor --base the way the real gh does, so a probe filtered to the
        # recovered base cannot see a PR that targets another branch.
        want_base=""; while [ $# -gt 0 ]; do case "$1" in --base) want_base="$2"; shift 2 ;; *) shift ;; esac; done
        if [ -f "$st/pr" ]; then
          pb="$(cat "$st/pr_base" 2>/dev/null || printf 'main')"
          if [ -n "$want_base" ] && [ "$pb" != "$want_base" ]; then
            printf '[]\n'
          else
            n="$(awk '{print $1}' "$st/pr")"; s="$(awk '{print $2}' "$st/pr")"
            printf '[{"number": %s, "state": "%s"}]\n' "$n" "$s"
          fi
        else
          printf '[]\n'
        fi ;;
      create)
        [ -f "$st/nongithub" ] && { echo "gh: HTTP 404 - not a GitHub repository" >&2; exit 1; }
        printf '%s\n' "$*" > "$st/create_args"
        body=""; while [ $# -gt 0 ]; do case "$1" in --body) body="$2"; shift 2 ;; *) shift ;; esac; done
        printf '%s\n' "$body" | awk '/^pushed-tip: /{print $2}' > "$st/pushed_tip"
        n="$(cat "$st/create_number" 2>/dev/null || printf '7')"
        printf '%s %s\n' "$n" OPEN > "$st/pr"
        # The REAL gh prints the PR's URL, never its number (#716). Printing the
        # number here let the ceremony's `pr_num=` capture pass on a shape gh
        # never produces, so the whole P-series was blind to the URL. `$st/create_number`
        # picks the number the URL carries; `$st/create_prints` stages any other
        # stdout verbatim, for outputs that are not PR URLs at all. The stdout is
        # kept in $st/create_out so a test can assert the SHAPE it staged.
        if [ -f "$st/create_prints" ]; then cat "$st/create_prints" > "$st/create_out"
        else printf 'https://github.com/owner/repo/pull/%s\n' "$n" > "$st/create_out"; fi
        cat "$st/create_out" ;;
      view)
        s="$(awk '{print $2}' "$st/pr")"
        m="$(cat "$st/merge_commit" 2>/dev/null || true)"
        h="$(cat "$st/head_oid" 2>/dev/null || true)"
        pt="$(cat "$st/pushed_tip" 2>/dev/null || true)"
        pb="$(cat "$st/pr_base" 2>/dev/null || printf 'main')"
        printf '{"state": "%s", "baseRefName": "%s", "mergeCommit": {"oid": "%s"}, "headRefOid": "%s", "body": "spine close\\npushed-tip: %s\\n"}\n' "$s" "$pb" "$m" "$h" "$pt" ;;
      *) echo "stub: unhandled gh pr $2" >&2; exit 64 ;;
    esac ;;
  *) echo "stub: unhandled gh $1" >&2; exit 64 ;;
esac
GHSTUB_EOF
chmod +x "$GHSTUB/gh"

_pr_fixture() { # $1=name — sets PR_REPO/PR_ORIGIN/PR_STATE/PR_SHIM; repo parked on the spine branch
  PR_REPO="$TMP/$1"; PR_ORIGIN="$TMP/$1-origin.git"; PR_STATE="$TMP/$1-gh"; PR_SHIM="$TMP/$1-shim"
  mkdir -p "$PR_REPO" "$PR_STATE"
  git -C "$PR_REPO" init -q
  git -C "$PR_REPO" config user.email t@t; git -C "$PR_REPO" config user.name t
  echo seed > "$PR_REPO/seed.txt"; git -C "$PR_REPO" add seed.txt; git -C "$PR_REPO" commit -qm seed
  git -C "$PR_REPO" branch -m main
  git -C "$PR_REPO" branch "$PR_BRANCH"
  git -C "$PR_REPO" checkout -q "$PR_BRANCH"
  echo spine > "$PR_REPO/spine.txt"; git -C "$PR_REPO" add spine.txt; git -C "$PR_REPO" commit -qm spine
  git init -q --bare "$PR_ORIGIN"
  git -C "$PR_REPO" remote add origin "$PR_ORIGIN"
  # The RAW configured URL carries the host the selector derivation reads
  # (hostless local paths are refused, T35); insteadOf keeps every push and
  # fetch on the local bare - no fixture touches a network.
  git -C "$PR_REPO" remote set-url origin git@github.com:owner/repo.git
  git -C "$PR_REPO" config "url.$PR_ORIGIN.insteadOf" "git@github.com:owner/repo.git"
  git -C "$PR_REPO" push -q origin main
  git --git-dir="$PR_ORIGIN" symbolic-ref HEAD refs/heads/main
  _wshim "$PR_REPO" "$PR_BRANCH" "canonical" "$PR_SHIM"
}

# The remote "GitHub" merges the PR: the merge is made in a SEPARATE clone and
# pushed to the bare origin, so the ceremony repo stays BEHIND its base and the
# record pass's fast-forward is real work, not a no-op. Also stages the gh
# state a merged PR reports.
_pr_simulate_merge() { # $1=spine-tip-the-PR-merged (the headRefOid)
  local clone="$TMP/sim-clone"; rm -rf "$clone"
  git clone -q "$PR_ORIGIN" "$clone"
  git -C "$clone" config user.email t@t; git -C "$clone" config user.name t
  git -C "$clone" checkout -q main
  git -C "$clone" merge --no-ff "$1" -m "merge r0.s5" >/dev/null
  git -C "$clone" push -q origin main
  git -C "$clone" rev-parse main > "$PR_STATE/merge_commit"
  printf "%s\n" "$1" > "$PR_STATE/head_oid"
  printf "7 MERGED\n" > "$PR_STATE/pr"
  rm -rf "$clone"
}

_pr_main_unreached() { # $1=label — the spine must NOT be on the LOCAL main
  if git -C "$PR_REPO" merge-base --is-ancestor "$PR_BRANCH" main 2>/dev/null; then
    T_FAIL=$((T_FAIL+1)); echo "FAIL: $1 - the spine reached local main anyway"
  else
    T_PASS=$((T_PASS+1))
  fi
}

# P1. ARM CHOICE: a remote exists, so the merge pass PUSHES and OPENS a PR — it
# must not merge locally. Against the old block this is RED in the intended
# direction: the old ceremony merges local main at rc 0 and never calls gh.
_pr_fixture p1
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'; printf 'PRLINES%s\n' \"\$pr_lines\""
t_assert_rc 0 "P1: the PR-arm pass runs clean on a repo with a remote"
t_assert_contains "$T_OUT" "PR #7 opened against main" "P1: ...announcing the PR it opened for /ossify:work-pr"
t_assert_contains "$T_OUT" "canonical:7" "P1: ...and recording repo:pr pairs for the record pass"
# #716: the pair and the message must carry the NUMBER. gh prints a URL, and the
# old `pr_num="$(gh pr create …)"` kept it whole - so every later step that uses
# `$pr_num` as a number (`$repo:$pr_num` lines, `gh pr view "$pr_num"`, the record
# pass's messages) received `https://github.com/owner/repo/pull/7`.
t_assert_eq 1 "$(grep -c '^https://github.com/.*/pull/7$' "$PR_STATE/create_out")" \
  "P1: the fixture is non-vacuous - gh's create really printed the URL shape (#716)"
case "$T_OUT" in
  *github.com*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P1: the URL gh printed reached the close's own output - \$pr_num was never reduced to the number";;
  *) T_PASS=$((T_PASS+1));;
esac
_pr_main_unreached "P1: no local merge"
if git --git-dir="$PR_ORIGIN" rev-parse --verify -q "refs/heads/$PR_BRANCH" >/dev/null; then
  t_assert_eq "$(git --git-dir="$PR_ORIGIN" rev-parse "refs/heads/$PR_BRANCH")" "$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")" \
    "P1: the pushed branch on origin is the spine tip"
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: P1 - the spine branch was never pushed to origin"
fi
t_assert_eq "$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")" "$(cat "$PR_STATE/pushed_tip")" \
  "P1: the PR body records the pushed tip (the lineage guard's durable input)"
t_assert_eq 0 "$(grep -c '^## Merge bar$' "$PR_STATE/create_args")" \
  "P1: with no \$pr_fields (merge-bar absent) the PR body carries no merge-bar fields"

# A full valid per-repo fields file (1.36.3, #1056): the seven headings in
# template order, the six-line bar, a filled Door line. Each halt case
# below breaks exactly one piece of it.
_valid_fields() {
  cat <<'FIELDS_EOF'
## Claim
The tier spine lands.

## Scope
Touches: tier. Deliberately does not touch: the rest.

## Known limits
- None known - fixture.

## Merge danger
Door: two-way - a revert undoes all of it.
Blast radius: the tier path.

## Merge bar
A finding blocks this PR only if it:
1. rejects valid input, or corrupts or loses state, on a path this PR touches;
2. makes the Claim above false;
3. breaks the test suite;
4. opens a security hole — injection, authentication bypass, or an exposed secret.
Everything else is non-blocking.

## Evidence
Not run - fixture.

## Closes
None.
FIELDS_EOF
}

# P1b. THE MERGE-BAR SEAM (1.13.0; per repo since 1.13.1, #614): with the six
# fields composed into <pr_fields_dir>/<repo>, they land AFTER the two lines the
# record pass reads, so the pushed-tip line is still the lineage guard's input.
# P1 above is the adjacent control: pr_fields_dir unset under `set -u` must
# still open the PR.
_pr_fixture p1b
mkdir -p "$PR_STATE/fields"
_valid_fields > "$PR_STATE/fields/canonical"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; pr_fields_dir='$PR_STATE/fields'; . '$MERGE_BLOCK'"
t_assert_rc 0 "P1b: the PR-arm pass runs clean with the merge-bar fields composed"
t_assert_eq "$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")" "$(cat "$PR_STATE/pushed_tip")" \
  "P1b: the pushed-tip line still reaches the record pass with the merge-bar fields appended"
t_assert_eq 1 "$(grep -c '^## Merge bar$' "$PR_STATE/create_args")" \
  "P1b: ...and the PR body carries the Merge bar heading"

# P1g-P1-crlf. #1056, #1063: the seat-written fields file is checked before the
# push. Each case breaks ONE piece of the valid file and asserts a halt whose
# MESSAGE names the file and the piece (an exit code alone cannot tell which check
# fired - a mutant that moves the halt to another check keeps rc 1), with nothing
# pushed and no PR opened (modelled on P1c). P1b above is the adjacent control:
# the unbroken file passes. $3 is a filter command run on the valid file.
_fields_halt_f() { # $1=case label $2=message fragment the halt must carry $3=filter command
  _pr_fixture "p1-$1"
  mkdir -p "$PR_STATE/fields"
  _valid_fields | eval "$3" > "$PR_STATE/fields/canonical"
  t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
    "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; pr_fields_dir='$PR_STATE/fields'; . '$MERGE_BLOCK'"
  t_assert_rc 1 "P1-$1: this fields file halts the close"
  t_assert_contains "$T_OUT" "$PR_STATE/fields/canonical" "P1-$1: ...naming the file"
  t_assert_contains "$T_OUT" "$2" "P1-$1: ...with the message for THIS piece"
  t_assert_eq 0 "$( [ -f "$PR_STATE/create_args" ] && echo 1 || echo 0 )" "P1-$1: ...and no PR is opened"
  t_assert_eq 0 "$(git --git-dir="$PR_ORIGIN" rev-parse --verify -q "refs/heads/$PR_BRANCH" >/dev/null && echo 1 || echo 0)" \
    "P1-$1: ...and the spine branch never reaches origin"
}
_fields_halt() { _fields_halt_f "$1" "$2" "sed -e '$3'"; }
_fields_halt heading "lacks the heading '## Known limits'" '/^## Known limits$/d'
_fields_halt heading2 "lacks the heading '## Closes'" '/^## Closes$/d'
# the heading list names all seven: a file without Merge danger must say so, not
# fall through to the order check's message
_fields_halt heading3 "lacks the heading '## Merge danger'" '/^## Merge danger$/d'
# a heading with text after it is not the heading: caught by the presence check
# (the order check would also halt, with a different message)
_fields_halt headingx "lacks the heading '## Known limits'" 's/^## Known limits$/## Known limits (none)/'
# out of order: Scope and Claim swapped by renaming the headings in place
_fields_halt order 'template order' 's/^## Claim$/## TMPH/; s/^## Scope$/## Claim/; s/^## TMPH$/## Scope/'
_fields_halt cond3 "lacks the merge-bar line '3. breaks the test suite;'" '/^3\. breaks the test suite;$/d'
_fields_halt cond2 "lacks the merge-bar line '2. makes the Claim above false;'" 's/^2\. makes the Claim above false;$/2. makes the Claim false;/'
# a condition with text appended contains the template line but is not it: whole-line match only
_fields_halt cond4 "lacks the merge-bar line '4. opens a security hole" 's/^\(4\. opens a security hole.*\)$/\1 Not after round 2./'
_fields_halt raise "lacks the merge-bar line 'A finding blocks this PR only if it:'" 's/^A finding blocks this PR only if it:$/A finding blocks this PR after round 2 only if it:/'
# #1063 C2: the stopping line is part of the bar, and the bar is read under ITS
# heading, not from anywhere in the file
_fields_halt noelse "lacks the merge-bar line 'Everything else is non-blocking.'" '/^Everything else is non-blocking\.$/d'
_bar_in_claim() { # the r0.s1 shape: lead + four conditions under ## Claim, only the stopping line left under ## Merge bar
  _valid_fields | sed -n '/^A finding blocks/,/^4\. /p' > "$PR_STATE/barlines"
  _valid_fields | sed -e '/^## Merge bar$/,/^## Evidence$/{/^A finding blocks/d;/^[1-4]\. /d;}' -e "/^## Claim\$/r $PR_STATE/barlines"
}
_fields_halt_f scope "lacks the merge-bar line 'A finding blocks this PR only if it:'" '_bar_in_claim'
_fields_halt_f extra "numbered line '3a. also blocks a typo.'" "awk '{print} /^4\\. /{print \"3a. also blocks a typo.\"}'"
# adjacent control: a numbered line under ANOTHER heading is not a bar line (the
# extra-line check must stay scoped to ## Merge bar)
_door_msg="has no 'Door: one-way' or 'Door: two-way' line"
_fields_ok() { # $1=case label $2=sed expr; the file must pass: PR opened, no Door halt
  _pr_fixture "p1-$1"
  mkdir -p "$PR_STATE/fields"
  _valid_fields | sed -e "$2" > "$PR_STATE/fields/canonical"
  t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
    "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; pr_fields_dir='$PR_STATE/fields'; . '$MERGE_BLOCK'"
  t_assert_rc 0 "P1-$1: this fields file passes the check"
  case "$T_OUT" in *"$_door_msg"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P1-$1: the Door halt message appeared";; *) T_PASS=$((T_PASS+1));; esac
  t_assert_eq 1 "$( [ -f "$PR_STATE/create_args" ] && echo 1 || echo 0 )" "P1-$1: ...and the PR is opened"
}
_fields_ok extra-elsewhere 's/^The tier spine lands\.$/1. The tier spine lands./'
_fields_halt nodoor "$_door_msg" '/^Door: /d'
_fields_halt unfilled "$_door_msg" 's/^Door: .*/Door: <one-way or two-way> - what a revert would not undo/'
# the Door line is anchored at the start (#1063 C3) and at the end (C2)
_fields_halt doorlead "$_door_msg" 's/^Door: two-way/See Door: two-way/'
_fields_halt doorboth "$_door_msg" 's/^Door: two-way.*/Door: one-way or two-way/'
_fields_halt doortail "$_door_msg" 's/^Door: two-way.*/Door: two-wayfoo/'
# a Door line under another heading is not the Merge danger's
_fields_halt doorelsewhere "$_door_msg" '/^Door: /d; s/^None\.$/Door: two-way/'
# adjacent controls for the Door check: one-way is as valid as two-way, and a
# bare Door line is as valid as one with an explanation
_fields_ok oneway 's/^Door: two-way/Door: one-way/'
_fields_ok doorbare 's/^Door: two-way.*/Door: two-way/'
# #1063 C1/C2: any character but an ASCII letter, digit, `_` or `-` ends the word; qualified lines from real
# merged bodies pass, the unfilled forms still fail (adjacent controls)
_fields_ok doorq1 's/^Door: two-way.*/Door: one-way after the tag - releases the plugin./'
_fields_ok doorq2 's/^Door: two-way.*/Door: two-way for the code - a revert undoes it./'
_fields_ok doorq3 's/^Door: two-way.*/Door: one-way once released. A tag is public./'
_fields_ok doorem 's/^Door: two-way.*/Door: two-way — a revert undoes it./'
_fields_ok doorbang 's/^Door: two-way.*/Door: two-way!/'
_fields_ok doorparen 's/^Door: two-way.*/Door: two-way)/'
_fields_ok doortab "s/^Door: two-way.*/Door: two-way$(printf '\t')because/"
_fields_halt dooror2 "$_door_msg" 's/^Door: two-way.*/Door: two-way or one-way - pick one/'
_fields_halt doorish "$_door_msg" 's/^Door: two-way.*/Door: two-way-ish/'
# #1073 r2 C10: a Door line naming both doors joined by a separator other than
# `or` is the unfilled form too (comma, slash, pipe; optional spaces)
_fields_halt doorsep1 "$_door_msg" 's/^Door: two-way.*/Door: one-way\/two-way/'
_fields_halt doorsep2 "$_door_msg" 's/^Door: two-way.*/Door: one-way, two-way/'
_fields_halt doorsep3 "$_door_msg" 's/^Door: two-way.*/Door: one-way | two-way/'
_fields_halt doorsep4 "$_door_msg" 's/^Door: two-way.*/Door: two-way , one-way - pick one/'
# the or-form takes runs of whitespace; two spaces around `or` still halt
_fields_halt doorsp2 "$_door_msg" 's/^Door: two-way.*/Door: one-way  or  two-way/'
_fields_halt doorsptab "$_door_msg" "s/^Door: two-way.*/Door: one-way$(printf '\t')or$(printf '\t')two-way/"
# ossify 1.37.0: the punctuation separators take tabs too (spine-close.md used literal spaces)
_fields_halt doorsepTab "$_door_msg" "s/^Door: two-way.*/Door: one-way$(printf '\t')\/$(printf '\t')two-way/"
# ossify 1.37.0 round 1 (PR #1097 C9): the separator set is space and tab only, so the verdict does not depend on the awk or the
# locale: a vertical tab or form feed is not a separator, and neither form halts as an or-form.
_fields_ok doorsepVT "s/^Door: two-way.*/Door: one-way$(printf '\v')\/$(printf '\v')two-way/"
_fields_ok doorsepFF "s/^Door: two-way.*/Door: one-way$(printf '\f')\/$(printf '\f')two-way/"
_fields_ok dooror_VT "s/^Door: two-way.*/Door: one-way$(printf '\v')or$(printf '\v')two-way/"
# adjacent control: one door, a tab-spaced separator, then other text still passes
_fields_ok doorsepTabc "s/^Door: two-way.*/Door: one-way$(printf '\t')\/$(printf '\t')released with the tag./"
# round 2 (PR #1097, CodeRabbit on spine-close.md): the or-form's second value takes the same word boundary as the first, so a
# filled one-way line whose text begins `two-way-sync` is not read as the unfilled form; the real or-form halts stay.
_fields_ok doorsecond 's/^Door: two-way.*/Door: one-way\/two-way-sync is disabled after migration./'
_fields_ok doorsecond2 's/^Door: two-way.*/Door: one-way or two-wayfoo is disabled after migration./'
_fields_halt doorsecond3 "$_door_msg" 's/^Door: two-way.*/Door: one-way\/two-way is disabled after migration./'
# #1073 C4a (r2 C11a-c): the word ends only at a character outside the class
_fields_halt doorcase "$_door_msg" 's/^Door: two-way.*/Door: two-wayFoo/'
_fields_halt doordigit "$_door_msg" 's/^Door: two-way.*/Door: two-way2/'
_fields_halt doorunder "$_door_msg" 's/^Door: two-way.*/Door: two-way_x/'
# adjacent controls for the separators: one door followed by a separator and other text
_fields_ok doorsepc1 's/^Door: two-way.*/Door: two-way, a revert undoes it./'
_fields_ok doorsepc2 's/^Door: two-way.*/Door: one-way \/ released with the tag./'
_fields_ok doorsepc3 's/^Door: two-way.*/Door: two-way | a revert undoes it./'
# #1073 C4b: `)` ends a numbered line too (`[.)]` -> `[.]` mutant); #1073 C5: a
# numbered Evidence line is not a bar line (the Merge bar section ends at the next heading)
_fields_halt_f extra2 "numbered line '3) also blocks a typo.'" "awk '{print} /^4\\. /{print \"3) also blocks a typo.\"}'"
_fields_ok evidence-numbered 's/^Not run - fixture\.$/1. bash run-tests.sh/'
# #1073 r2 C11e: a bar line quoted under ## Claim is not under ## Merge bar (control)
_fields_ok barquoted $'s/^The tier spine lands\\.$/&\\\n2. makes the Claim above false;\\\nEverything else is non-blocking./' # backslash-newline: GNU and BSD sed
# PR1069r1 C3: a template bar line repeated under Merge bar halts naming the line
_fields_halt_f dupbar "repeats the merge-bar line '2. makes the Claim above false;'" "awk '{print} /^2\\. /{print}'"
# #1063 C4: the fields file is a seat's Write-tool output, LF by contract; a CRLF
# file (a Windows editor or tool touched it) halts naming the line endings
# instead of reporting "lacks the heading" for a heading that is visibly there
_fields_halt_f crlf "CRLF" "awk '{ printf \"%s\\r\\n\", \$0 }'"

# #1073 r2 C12: the CRLF check fails closed when its awk cannot run. An awk shim
# exits $2 on the CRLF program only; every other awk call runs the real awk.
_awk_shim() { # $1=shim dir $2=exit code the shimmed awk returns $3=which program: crlf (default) or order
  mkdir -p "$1"; _real_awk="$(command -v awk)"
  cat > "$1/awk" <<'SHIM_EOF'
#!/bin/sh
case "__WHICH__:$1" in crlf:*'"\r"'*|order:*'"ok" : "no"'*) exit __RC__;; esac
exec __AWK__ "$@"
SHIM_EOF
  sed -e "s|__RC__|$2|" -e "s|__AWK__|$_real_awk|" -e "s|__WHICH__|${3:-crlf}|" "$1/awk" > "$1/awk.tmp" && mv "$1/awk.tmp" "$1/awk"
  chmod +x "$1/awk"
}
_awk_shim_run() { # $1=label $2=shim exit code $3=which program (see _awk_shim)
  _pr_fixture "p1-$1"; mkdir -p "$PR_STATE/fields"
  _valid_fields > "$PR_STATE/fields/canonical"
  _awk_shim "$TMP/p1-$1-awk" "$2" "${3:-crlf}"
  t_capture env "GH_STATE=$PR_STATE" "PATH=$TMP/p1-$1-awk:$GHSTUB:$PR_SHIM:$PATH" bash -c \
    "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; pr_fields_dir='$PR_STATE/fields'; . '$MERGE_BLOCK'"
}
_awk_shim_run crlfrc2 2
t_assert_rc 1 "P1-crlfrc2: a CRLF check whose awk errors halts the close"
t_assert_contains "$T_OUT" "could not run the CRLF check" "P1-crlfrc2: ...with a message that says the check did not run"
t_assert_eq 0 "$( [ -f "$PR_STATE/create_args" ] && echo 1 || echo 0 )" "P1-crlfrc2: ...and no PR is opened"
# controls: awk rc 1 (no CR found) continues to the PR; rc 0 (CR found) halts as CRLF
_awk_shim_run crlfrc1 1
t_assert_rc 0 "P1-crlfrc1: a clean body (CRLF awk rc 1) continues"
t_assert_eq 1 "$( [ -f "$PR_STATE/create_args" ] && echo 1 || echo 0 )" "P1-crlfrc1: ...and the PR is opened"
_awk_shim_run crlfrc0 0
t_assert_rc 1 "P1-crlfrc0: awk rc 0 (CR found) halts"
t_assert_contains "$T_OUT" "has CRLF line endings" "P1-crlfrc0: ...with the CRLF message"
# the heading-order check fails closed with its own message when its awk cannot run (#1073 r2 C12)
_awk_shim_run orderrc2 2 order
t_assert_rc 1 "P1-orderrc2: a heading-order check whose awk errors halts the close"
t_assert_contains "$T_OUT" "could not run the heading-order check" "P1-orderrc2: ...with a message that says the check did not run"
case "$T_OUT" in *"out of template order"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P1-orderrc2: the out-of-order message appeared";; *) T_PASS=$((T_PASS+1));; esac

# P1c. A fields directory with no file for this repo halts before the push: a
# PR opened without its repo's fields would reach review with no merge bar.
_pr_fixture p1c
mkdir -p "$PR_STATE/fields"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; pr_fields_dir='$PR_STATE/fields'; . '$MERGE_BLOCK'"
t_assert_rc 1 "P1c: a missing per-repo fields file halts the close"
t_assert_contains "$T_OUT" "no merge-bar fields file for canonical" "P1c: ...naming the repo whose file is missing"
t_assert_eq 0 "$( [ -f "$PR_STATE/create_args" ] && echo 1 || echo 0 )" "P1c: ...and no PR is opened"
t_assert_eq 0 "$(git --git-dir="$PR_ORIGIN" rev-parse --verify -q "refs/heads/$PR_BRANCH" >/dev/null && echo 1 || echo 0)" \
  "P1c: ...and the spine branch never reaches origin - the halt has no remote side effect"

# P1d/P1e/P1f. #716: `pr_num` is a NUMBER. P1 above asserts the URL never reaches
# the close's output on the number 7; these three pin the extraction itself and
# both halt arms, each on its own fixture (the PR-existence probe reads `$st/pr`,
# which create writes - a second run on a used fixture takes the resume arm).
# P1d: the number the URL carries is what lands in the pair, whatever it is.
_pr_fixture p1d
printf '123\n' > "$PR_STATE/create_number"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'; printf 'PRLINES%s\n' \"\$pr_lines\""
t_assert_rc 0 "P1d: a PR URL with 123 in it does not halt the close"
t_assert_eq 1 "$(grep -c '^https://github.com/.*/pull/123$' "$PR_STATE/create_out")" \
  "P1d: the fixture is non-vacuous - gh printed .../pull/123"
t_assert_contains "$T_OUT" "canonical:123" "P1d: the arm stores the NUMBER the URL carries"
t_assert_contains "$T_OUT" "PR #123 opened against main" "P1d: ...in the message /ossify:work-pr is handed"
case "$T_OUT" in
  *github.com*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P1d: the URL reached the close's own output";;
  *) T_PASS=$((T_PASS+1));;
esac

# P1e. An output that is no URL at all must HALT, naming what gh printed: the
# old arm stored it as `pr_num` and the close carried on to steps that use the
# number (`gh pr view`, the record pass), failing there, obscurely and late.
_pr_fixture p1e
printf '%s\n' 'gh: could not create pull request: the branch is not on the remote' > "$PR_STATE/create_prints"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'; printf 'PRLINES%s\n' \"\$pr_lines\""
t_assert_rc 1 "P1e: an output with no trailing digits halts the close"
t_assert_contains "$T_OUT" "not a PR URL" "P1e: ...naming the shape it required"
t_assert_contains "$T_OUT" "could not create pull request" "P1e: ...and quoting what gh printed, whole"
case "$T_OUT" in
  *"PRLINES"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P1e: the close recorded a repo:pr pair from a non-URL";;
  *) T_PASS=$((T_PASS+1));;
esac

# P1f. A URL whose LAST segment is not a number (gh prints `.../pull/123/files`
# when a wrapper appends the changed-files path) is the same arm, one shape in:
# "not all digits" is the test, not "does not start with https".
_pr_fixture p1f
printf '%s\n' 'https://github.com/owner/repo/pull/123/files' > "$PR_STATE/create_prints"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 1 "P1f: a PR URL with a trailing non-numeric segment halts"
t_assert_contains "$T_OUT" "pull/123/files" "P1f: ...quoting the URL it refused"

# P2. THE THIRD LEG (A1): gh cannot operate on the remote — fail closed. The
# probe runs before any push, and the halt never falls through to a local merge.
_pr_fixture p2; touch "$PR_STATE/nongithub"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 1 "P2: a gh-inoperable remote halts the close"
t_assert_contains "$T_OUT" "silent local fall-through" "P2: ...naming that a local merge was NOT silently taken"
_pr_main_unreached "P2: no local fall-through merge"
if git --git-dir="$PR_ORIGIN" rev-parse --verify -q "refs/heads/$PR_BRANCH" >/dev/null; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: P2 - the branch was pushed although gh could not operate"
else
  T_PASS=$((T_PASS+1))
fi

# P3. THE A2 FLOW, end to end: a PR that carried ONE FIX ROUND before merging.
# work-pr lands fix commits ON the spine branch, so the merged head descends
# from — but is not equal to — the tip this close pushed. Both guards must bind
# to the merged headRefOid; an equality-shaped guard fails exactly here.
_pr_fixture p3
MAIN_BEFORE="$(git -C "$PR_REPO" rev-parse main)"
PUSHED_TIP="$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'" >/dev/null
# The loop, as work-pr drives it: a fix commit lands on the spine branch and is
# pushed to the PR head.
echo fix > "$PR_REPO/fix.txt"; git -C "$PR_REPO" add fix.txt; git -C "$PR_REPO" commit -qm "review fix"
MERGED_HEAD="$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")"
git -C "$PR_REPO" push -q origin "$PR_BRANCH"
if [ "$PUSHED_TIP" = "$MERGED_HEAD" ]; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: P3 fixture is vacuous - no fix commit beyond the pushed tip"
else
  T_PASS=$((T_PASS+1))
fi
if git -C "$PR_REPO" merge-base --is-ancestor "$PUSHED_TIP" "$MERGED_HEAD"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: P3 fixture is wrong - the merged head does not descend from the pushed tip"
fi
_pr_simulate_merge "$MERGED_HEAD"
SIM_MERGE="$(cat "$PR_STATE/merge_commit")"
# RESUME FLOW, as a re-invoked close runs it: pass one re-probes (PR exists —
# not re-opened), pass two records against freshly fetched refs.
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'; . '$PRRECORD_BLOCK'; printf 'PAIRS%s\n' \"\$merge_shas\""
t_assert_rc 0 "P3: a merged PR with a fix round records clean (ancestry, not equality)"
t_assert_contains "$T_OUT" "already has PR #7" "P3: ...the resume probe recognises the existing PR"
t_assert_contains "$T_OUT" "landed PR #7 at $SIM_MERGE" "P3: ...and records the REMOTE merge sha"
t_assert_contains "$T_OUT" "canonical:$SIM_MERGE" "P3: ...into \$merge_shas for the touch check"
t_assert_eq "$(git -C "$PR_REPO" rev-parse origin/main)" "$(git -C "$PR_REPO" rev-parse main)" \
  "P3: local main was fast-forwarded to the fetched origin"
t_assert_eq "main" "$(git -C "$PR_REPO" rev-parse --abbrev-ref HEAD)" "P3: the repo is left on its base branch"
# The seam the touch check consumes: the merge's first-parent diff carries BOTH
# the spine's own change AND the fix round's — fix-commit paths join the union.
DIFF_LIST="$(git -C "$PR_REPO" diff --name-only "$SIM_MERGE^1" "$SIM_MERGE")"
case "$DIFF_LIST" in *spine.txt*) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: P3 - the spine's own file missing from the merge diff";; esac
case "$DIFF_LIST" in *fix.txt*) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: P3 - the fix round's file missing from the merge diff (fix paths must join the union)";; esac

# P4. THE PR-OPEN HALT (D9): the operator has not merged; the ceremony halts
# recording nothing, and local main stays untouched.
_pr_fixture p4
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'; . '$PRRECORD_BLOCK'"
t_assert_rc 1 "P4: an OPEN PR halts the record pass"
t_assert_contains "$T_OUT" "still open" "P4: ...saying the merge is the operator's, via work-pr"
_pr_main_unreached "P4: no local merge while the PR is open"

# P5. HEAD IDENTITY: a PR that landed without a two-parent merge commit (a
# rebase or squash merge) halts at RECORD time — not obscurely in the touch
# check. Stage gh reporting a non-merge commit as the mergeCommit. P5-P7 reuse
# the P3 fixture — re-point the globals P4's fixture call moved.
PR_REPO="$TMP/p3"; PR_ORIGIN="$TMP/p3-origin.git"; PR_STATE="$TMP/p3-gh"; PR_SHIM="$TMP/p3-shim"
printf "%s\n" "$MAIN_BEFORE" > "$PR_STATE/merge_commit"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'; . '$PRRECORD_BLOCK'"
t_assert_rc 1 "P5: a non-merge landing halts the record pass"
t_assert_contains "$T_OUT" "two-parent merge commit" "P5: ...naming the shape the touch check needs"
case "$T_OUT" in *"landed PR"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P5 - a non-merge landing was recorded anyway";; *) T_PASS=$((T_PASS+1));; esac

# P6. LINEAGE: the merged head must DESCEND from the tip this close pushed. A
# rewritten or diverged head fails even though every other fact is real. The
# forged pushed-tip must be a commit that EXISTS but is NOT an ancestor of the
# merged head — the root commit would quietly pass, and the assertion with it.
git --git-dir="$PR_ORIGIN" rev-parse main > "$PR_STATE/merge_commit"
UNRELATED="$(git -C "$PR_REPO" commit-tree 'HEAD^{tree}' -m forged)"
printf "%s\n" "$UNRELATED" > "$PR_STATE/pushed_tip"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'; . '$PRRECORD_BLOCK'"
t_assert_rc 1 "P6: a head that does not descend from the pushed tip halts"
t_assert_contains "$T_OUT" "rewritten or diverged" "P6: ...naming the lineage failure"
# Restore honest state for P7.
printf "%s\n" "$PUSHED_TIP" > "$PR_STATE/pushed_tip"

# P7. THE STRANDED-MERGE GUARD (D5): a local base with commits origin lacks is
# the pre-PR ceremony's signature. The halt names the repair and NEVER runs it.
echo stranded > "$PR_REPO/stranded.txt"; git -C "$PR_REPO" add stranded.txt; git -C "$PR_REPO" commit -qm stranded
STRANDED_SHA="$(git -C "$PR_REPO" rev-parse main)"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'; . '$PRRECORD_BLOCK'"
t_assert_rc 1 "P7: a local base ahead of origin halts the record pass"
t_assert_contains "$T_OUT" "reset --hard origin/main" "P7: ...naming the repair command, not running it"
t_assert_eq "$STRANDED_SHA" "$(git -C "$PR_REPO" rev-parse main)" "P7: ...and local main was left exactly as it was (never auto-reset)"

# P5b-P5h. LINEAR LANDINGS (1.14.3, #708). A base branch that enforces linear
# history cannot take a merge commit, so the record pass also accepts a squash
# or a rebase landing that it can PROVE: the landed tree equals the reviewed
# head's, and the landed tip's first-parent chain reaches a commit the head
# already holds through one-parent commits only. That commit is the
# BEFORE-POINT, carried as a third field on the $merge_shas line, and step 5
# and the cumulative demo read it instead of `$sha^1`.
#
# Each case opens the PR, lands ONE review-fix commit on the spine branch (so
# the head carries two commits and a rebase landing is longer than one commit),
# lands it on the remote, then runs the resumed close through the touch check.
_pr_land_flow() { # $1=fixture name — sets LF_BASE / LF_TIP / LF_HEAD
  _pr_fixture "$1"
  LF_BASE="$(git -C "$PR_REPO" rev-parse main)"
  LF_TIP="$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")"
  t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
    "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'" >/dev/null
  echo fix > "$PR_REPO/fix.txt"; git -C "$PR_REPO" add fix.txt; git -C "$PR_REPO" commit -qm "review fix"
  git -C "$PR_REPO" push -q origin "$PR_BRANCH"
  LF_HEAD="$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")"
}
_pr_sim_clone() { # prints the clone path, on main
  local clone="$TMP/sim-clone"; rm -rf "$clone"
  git clone -q "$PR_ORIGIN" "$clone"
  git -C "$clone" config user.email t@t; git -C "$clone" config user.name t
  git -C "$clone" checkout -q main
  printf '%s\n' "$clone"
}
_pr_sim_publish() { # $1=clone $2=headRefOid — push main and stage the merged PR
  git -C "$1" push -q origin main
  git -C "$1" rev-parse main > "$PR_STATE/merge_commit"
  printf "%s\n" "$2" > "$PR_STATE/head_oid"
  printf "7 MERGED\n" > "$PR_STATE/pr"
  rm -rf "$1"
}
_pr_simulate_squash() { # $1=head [$2=an extra file the squash adds, so its tree differs]
  local clone; clone="$(_pr_sim_clone)"
  git -C "$clone" merge -q --squash "$1" >/dev/null
  if [ -n "${2:-}" ]; then echo extra > "$clone/$2"; git -C "$clone" add "$2"; fi
  git -C "$clone" commit -qm "squash r0.s5"
  _pr_sim_publish "$clone" "$1"
}
_pr_simulate_rebase() { # $1=head — GitHub's rebase-and-merge rewrites every commit onto main
  local clone; clone="$(_pr_sim_clone)"
  git -C "$clone" checkout -q -b land "$1"
  GIT_COMMITTER_DATE='2030-01-01T00:00:00Z' git -C "$clone" rebase -q --force-rebase main
  git -C "$clone" checkout -q main; git -C "$clone" merge -q --ff-only land
  _pr_sim_publish "$clone" "$1"
}
_pr_record() { # resumed close: pass one, the record pass, then step 5's touch check
  : > "$PR_SHIM/args.log"
  t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
    "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'; . '$PRRECORD_BLOCK'; printf 'PAIRS%s\n' \"\$merge_shas\"; . '$TOUCH_BLOCK'"
  LF_TOUCH="$(awk '/^touch_check /' "$PR_SHIM/args.log")"
}
_pr_not_recorded() { # $1=label
  case "$T_OUT" in *"landed PR"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: $1 - recorded anyway";; *) T_PASS=$((T_PASS+1));; esac
}

# P5b. SQUASH: one commit, tree equal to the head's, its parent in the head's
# history. Recorded as a squash, before-point = its parent.
_pr_land_flow p5b
_pr_simulate_squash "$LF_HEAD"
SQ="$(cat "$PR_STATE/merge_commit")"
_pr_record
t_assert_contains "$T_OUT" "landed PR #7 at $SQ (squash)" "P5b: a tree-equal squash is recorded, naming its proof"
t_assert_contains "$T_OUT" "canonical:$SQ:$LF_BASE" "P5b: ...with its parent as the before-point in \$merge_shas"
case "$LF_TOUCH" in *spine.txt*fix.txt*|*fix.txt*spine.txt*) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: P5b - step 5's path list lacks the squash's files: $LF_TOUCH";; esac

# P5c. REBASE: every commit rewritten onto main. Recorded as a rebase; the
# before-point is the base tip under the rewritten run, so step 5 sees BOTH
# commits' files — `$sha^1` would see only the last one.
_pr_land_flow p5c
_pr_simulate_rebase "$LF_HEAD"
RB="$(cat "$PR_STATE/merge_commit")"
case "$(git --git-dir="$PR_ORIGIN" diff --name-only "$RB^1" "$RB")" in
  *spine.txt*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P5c fixture is vacuous - \$sha^1 alone already sees spine.txt";;
  *) T_PASS=$((T_PASS+1));;
esac
_pr_record
t_assert_contains "$T_OUT" "landed PR #7 at $RB (rebase)" "P5c: a tree-equal rebase is recorded, naming its proof"
t_assert_contains "$T_OUT" "canonical:$RB:$LF_BASE" "P5c: ...with the base tip under the run as the before-point"
case "$LF_TOUCH" in *spine.txt*) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: P5c - step 5 diffed from \$sha^1, not the before-point: $LF_TOUCH";; esac

# P5d. A MERGE COMMIT still records as one, with no third field (adjacent
# control for the default before-point).
_pr_land_flow p5d
_pr_simulate_merge "$LF_HEAD"
MG="$(cat "$PR_STATE/merge_commit")"
_pr_record
t_assert_contains "$T_OUT" "landed PR #7 at $MG (merge)" "P5d: a two-parent merge of the head records as a merge"
case "$T_OUT" in *"canonical:$MG:"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P5d - a merge commit gained a before-point field";; *) T_PASS=$((T_PASS+1));; esac

# P5e. CONTROL: a squash whose tree is NOT the head's (it adds a file nobody
# reviewed) halts.
_pr_land_flow p5e
_pr_simulate_squash "$LF_HEAD" unreviewed.txt
_pr_record
t_assert_rc 1 "P5e: a squash whose tree differs from the head halts"
t_assert_contains "$T_OUT" "tree differs from the reviewed head" "P5e: ...naming the tree mismatch"
_pr_not_recorded "P5e"

# P5f. CONTROL: a two-parent merge whose second parent is not the head (it
# merged the pushed tip, not the head with its fix round) halts.
_pr_land_flow p5f
_pr_simulate_merge "$LF_TIP"
printf "%s\n" "$LF_HEAD" > "$PR_STATE/head_oid"
_pr_record
t_assert_rc 1 "P5f: a merge commit of something other than the head halts"
t_assert_contains "$T_OUT" "second parent is not the PR's head" "P5f: ...naming the wrong second parent"
_pr_not_recorded "P5f"

# P5g. CONTROL: a fast-forward (the landed tip is the head itself) has no
# before-point to prove and halts.
_pr_land_flow p5g
FF_CLONE="$(_pr_sim_clone)"
git -C "$FF_CLONE" merge -q --ff-only "$LF_HEAD"
_pr_sim_publish "$FF_CLONE" "$LF_HEAD"
_pr_record
t_assert_rc 1 "P5g: a fast-forward landing halts"
t_assert_contains "$T_OUT" "fast-forward" "P5g: ...naming the fast-forward"
_pr_not_recorded "P5g"

# P5h. CONTROL: the landed run sits on a merge commit the head does not hold.
# The head carries the merged change by cherry-pick, so the trees ARE equal —
# only the chain walk can refuse it.
_pr_land_flow p5h
MC_CLONE="$(_pr_sim_clone)"
git -C "$MC_CLONE" checkout -q -b other main
echo other > "$MC_CLONE/other.txt"; git -C "$MC_CLONE" add other.txt; git -C "$MC_CLONE" commit -qm other
OTHER="$(git -C "$MC_CLONE" rev-parse other)"
git -C "$MC_CLONE" checkout -q main; git -C "$MC_CLONE" merge -q --no-ff other -m "merge other" >/dev/null
git -C "$MC_CLONE" fetch -q origin "$PR_BRANCH"
git -C "$MC_CLONE" checkout -q -b head2 "$LF_HEAD"; git -C "$MC_CLONE" cherry-pick "$OTHER" >/dev/null
MC_HEAD="$(git -C "$MC_CLONE" rev-parse head2)"
git -C "$MC_CLONE" push -q origin "head2:$PR_BRANCH"
git -C "$MC_CLONE" checkout -q main; git -C "$MC_CLONE" merge -q --squash "$MC_HEAD" >/dev/null 2>&1
git -C "$MC_CLONE" commit -qm "squash r0.s5"
t_assert_eq "$(git -C "$MC_CLONE" rev-parse "main^{tree}")" "$(git -C "$MC_CLONE" rev-parse "$MC_HEAD^{tree}")" \
  "P5h: the fixture's trees are equal, so only the chain walk can refuse it"
_pr_sim_publish "$MC_CLONE" "$MC_HEAD"
git -C "$PR_REPO" fetch -q origin "$PR_BRANCH"
_pr_record
t_assert_rc 1 "P5h: a run that sits on a merge commit the head lacks halts"
t_assert_contains "$T_OUT" "merge commit below the landed run" "P5h: ...naming the merge commit in the chain"
_pr_not_recorded "P5h"

# P5i. The cumulative demo's before-checkout reads the before-point too: on a
# linear run base -> one -> two, `cat f.txt` differs between the tip and the
# before-point (`base`), but not between the tip and `$sha^1` (`one`).
LREPO="$TMP/lrepo"; mkdir -p "$LREPO"; git -C "$LREPO" init -q
git -C "$LREPO" config user.email t@t; git -C "$LREPO" config user.name t
echo base > "$LREPO/f.txt"; git -C "$LREPO" add f.txt; git -C "$LREPO" commit -qm base
LBASE="$(git -C "$LREPO" rev-parse HEAD)"
echo one > "$LREPO/f.txt"; git -C "$LREPO" commit -qam one
echo two > "$LREPO/g.txt"; git -C "$LREPO" add g.txt; git -C "$LREPO" commit -qm two
LTIP="$(git -C "$LREPO" rev-parse HEAD)"
Q_SAVED="$QREPO"; QREPO="$LREPO"; _qshim "$TMP/qshim-linear" 'cat f.txt'; QREPO="$Q_SAVED"
t_capture env "TMPDIR=$QTMP" "PATH=$TMP/qshim-linear:$PATH" "merge_shas=myrepo:$LTIP:$LBASE" "QBLOCK=$QBLOCK" \
  bash -c 'set -euo pipefail; . "$QBLOCK"'
t_assert_rc 1 "P5i: the demo compares the tip against the before-point, not \$sha^1"
t_assert_contains "$T_OUT" "parent rc=0" "P5i: ...after a before-checkout that really ran (an unreadable line halts at the detach instead)"
t_capture env "TMPDIR=$QTMP" "PATH=$TMP/qshim-linear:$PATH" "merge_shas=myrepo:$LTIP" "QBLOCK=$QBLOCK" \
  bash -c 'set -euo pipefail; . "$QBLOCK"'
t_assert_rc 0 "P5i: ...and with no third field it still compares against \$sha^1 (control)"

# P8. A NON-ORIGIN REMOTE (round 2, T3/T10): the arm test selects the PR arm on
# any non-empty remote, so a repo whose only remote is named something else
# must have that remote RESOLVED and used for the push - and the PR creation
# must pin the head branch explicitly (T6): gh defaults --head to the CURRENT
# branch, which is not necessarily the spine branch this pass just pushed.
_pr_fixture p8
git -C "$PR_REPO" remote rename origin upstream
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 0 "P8: an upstream-named remote runs the PR arm, not a push failure"
t_assert_contains "$T_OUT" "PR #7 opened against main" "P8: ...opening the PR"
if git --git-dir="$PR_ORIGIN" rev-parse --verify -q "refs/heads/$PR_BRANCH" >/dev/null; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: P8 - the spine branch never reached the upstream-named remote"
fi
t_assert_contains "$(cat "$PR_STATE/create_args")" "--head $PR_BRANCH" "P8: PR creation pins the head to the spine branch (never the ambient branch)"
t_assert_contains "$(cat "$PR_STATE/create_args")" "--base main" "P8: ...and the base to the recovered base branch"
t_assert_eq "owner/repo" "$(cat "$PR_STATE/gh_repo")" "P8: every gh call is pinned to the resolved remote's repo (--repo), not gh's default"

# P9. BASE VALIDATION (round 2, T5/T9): a PR that merged into some OTHER branch
# is not this repo's landing, whatever its merge commit reaches later. Rejected
# TWICE: at discovery (the probe filters by base, so a wrong-base PR is never
# handed to the loop) and at record time (baseRefName re-proved, because a PR's
# base can be retargeted between the two).
_pr_fixture p9
printf "7 MERGED\n" > "$PR_STATE/pr"
git -C "$PR_REPO" rev-parse "$PR_BRANCH" > "$PR_STATE/head_oid"
git -C "$PR_REPO" rev-parse "$PR_BRANCH" > "$PR_STATE/merge_commit"
printf "other\n" > "$PR_STATE/pr_base"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 0 "P9: the landing pass runs clean when the only PR targets another base"
case "$T_OUT" in
  *"already has PR #7"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P9 - the probe accepted a PR targeting another base branch";;
  *) T_PASS=$((T_PASS+1));;
esac
t_assert_contains "$(cat "$PR_STATE/create_args")" "--base main" "P9: the probe's rejection led to a NEW, correctly-based PR instead"
# Re-stage the retargeted-MERGED state the record pass must catch: same PR
# number, now reported MERGED with baseRefName 'other' (the retarget-between-
# discovery-and-record case the probe cannot see).
printf "7 MERGED\n" > "$PR_STATE/pr"
printf "other\n" > "$PR_STATE/pr_base"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; pr_lines='canonical:7'; . '$PRRECORD_BLOCK'"
t_assert_rc 1 "P9: a PR merged into another base halts the record pass"
t_assert_contains "$T_OUT" "targets 'other', not 'main'" "P9: ...naming both branches"
_pr_main_unreached "P9: nothing landed locally"

# ---------------------------------------------------------------------------
# R-series — the release tag (round 2, T1/T2/T8): per hosting repo, resumable,
# and every git command scoped to that repo. The tag block's fixtures give it a
# bare origin, the same stand-in the P-series uses for GitHub.
# ---------------------------------------------------------------------------
REL_CLOSE="$SKILLS/close/references/release-close.md"
TAG_BLOCK="$TMP/rel-tag.sh"; _extract_block "$REL_CLOSE" 'git tag' "$TAG_BLOCK"
if [ -s "$TAG_BLOCK" ] && grep -Fq 'git tag' "$TAG_BLOCK"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract the release-tag block from release-close.md - R1-R3 are vacuous"
fi

_pr_fixture r1
# R1. Fresh tag: created on the repo's base, pushed, ANNOTATED, per repo.
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 0 "R1: the tag pass tags a fresh release"
t_assert_contains "$T_OUT" "tagged r9" "R1: ...saying so per repo"
if [ -n "$(git --git-dir="$PR_ORIGIN" rev-parse -q --verify 'refs/tags/r9' 2>/dev/null)" ] \
  && [ "$(git --git-dir="$PR_ORIGIN" rev-parse -q --verify 'refs/tags/r9' 2>/dev/null)" != "$(git --git-dir="$PR_ORIGIN" rev-parse -q --verify 'refs/tags/r9^{}' 2>/dev/null)" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: R1 - the pushed tag is missing or lightweight (not annotated)"
fi
t_assert_eq "$(git -C "$PR_REPO" rev-parse main)" "$(git --git-dir="$PR_ORIGIN" rev-parse -q --verify 'refs/tags/r9^{}' 2>/dev/null)" \
  "R1: the tag on the remote points at the repo's base branch tip"
TAG_BEFORE="$(git --git-dir="$PR_ORIGIN" rev-parse 'refs/tags/r9')"

# R2. RESUME (T2): an existing tag pointing at base, present on the remote, is
# continuable - the state writes failed last time, not the tag. No re-tag.
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 0 "R2: a matching existing tag resumes instead of halting"
t_assert_contains "$T_OUT" "already tagged" "R2: ...and says so"
t_assert_eq "$TAG_BEFORE" "$(git --git-dir="$PR_ORIGIN" rev-parse 'refs/tags/r9')" "R2: the tag object was not replaced"

# R3. A MISMATCHED existing tag halts (T2's other arm): the tag points
# somewhere else - that is a human decision, never a clobber.
git -C "$PR_REPO" tag -d r9 >/dev/null
git -C "$PR_REPO" tag -a r9 -m moved "$PR_BRANCH"
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 1 "R3: a tag pointing away from base halts"
t_assert_contains "$T_OUT" "points at" "R3: ...naming where it points and where it should"

# R4. THE NO-REMOTE TAG ARM (round 3, T12): a repo that landed its spines
# locally all release long - the same no-remote world the landing arm serves -
# must still be release-taggable. The tag is local; no push, no remote leg.
mkdir -p "$TMP/r4" "$TMP/r4-gh"
git -C "$TMP/r4" init -q
git -C "$TMP/r4" config user.email t@t; git -C "$TMP/r4" config user.name t
echo seed > "$TMP/r4/seed.txt"; git -C "$TMP/r4" add seed.txt; git -C "$TMP/r4" commit -qm seed
git -C "$TMP/r4" branch -m main
PR_REPO="$TMP/r4"; PR_ORIGIN=""; PR_STATE="$TMP/r4-gh"; PR_SHIM="$TMP/r4-shim"
_wshim "$PR_REPO" "$PR_BRANCH" "canonical" "$PR_SHIM"
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 0 "R4: a no-remote repo tags its release locally"
t_assert_contains "$T_OUT" "tagged r9" "R4: ...saying so, same as a remote repo"
if [ -n "$(git -C "$PR_REPO" rev-parse -q --verify 'refs/tags/r9' 2>/dev/null)" ] \
  && [ "$(git -C "$PR_REPO" rev-parse -q --verify 'refs/tags/r9' 2>/dev/null)" != "$(git -C "$PR_REPO" rev-parse -q --verify 'refs/tags/r9^{}' 2>/dev/null)" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: R4 - the local tag is missing or lightweight"
fi
t_assert_eq "$(git -C "$PR_REPO" rev-parse main)" "$(git -C "$PR_REPO" rev-parse -q --verify 'refs/tags/r9^{}')" \
  "R4: the local tag points at the base branch tip"
R4_TAG_OBJ="$(git -C "$PR_REPO" rev-parse 'refs/tags/r9')"
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 0 "R4: the no-remote resume arm continues on a matching local tag"
t_assert_contains "$T_OUT" "already tagged" "R4: ...without re-tagging"
t_assert_eq "$R4_TAG_OBJ" "$(git -C "$PR_REPO" rev-parse 'refs/tags/r9')" "R4: the tag object is unchanged by the resume"
PR_REPO="$TMP/r1"; PR_ORIGIN="$TMP/r1-origin.git"; PR_STATE="$TMP/r1-gh"; PR_SHIM="$TMP/r1-shim"

# P10. DIVERGENT RESUMED PR, pre-handoff (round 4, T15): the probe finds a
# same-head/same-base PR whose remote head was force-pushed past the pushed
# tip. Catching it in the record pass is AFTER the operator merged an
# unrelated head - the landing pass must verify lineage BEFORE the handoff.
_pr_fixture p10
printf "7 OPEN\n" > "$PR_STATE/pr"
git -C "$PR_REPO" rev-parse "$PR_BRANCH" > "$PR_STATE/head_oid"
UNRELATED10="$(git -C "$PR_REPO" commit-tree 'HEAD^{tree}' -m forged10)"
printf "%s\n" "$UNRELATED10" > "$PR_STATE/pushed_tip"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 1 "P10: a resumed PR whose head does not descend from the pushed tip halts at discovery"
t_assert_contains "$T_OUT" "rewritten or diverged" "P10: ...naming the lineage failure before work-pr touches it"
case "$T_OUT" in *"hand it to"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P10 - the divergent PR was handed to work-pr anyway";; *) T_PASS=$((T_PASS+1));; esac

# R5. A LIGHTWEIGHT existing tag is not resumable (round 4, T18/T19,
# convergent from both gates): refs/tags/x and refs/tags/x^{} both resolve to
# the commit, so the target check alone accepts it - and the release closes
# over a tag with no annotation, against the ANNOTATED-always contract.
_pr_fixture r5
git -C "$PR_REPO" tag r9 main
git -C "$PR_REPO" push -q origin r9
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 1 "R5: a lightweight existing tag halts the resume arm"
t_assert_contains "$T_OUT" "annotated" "R5: ...naming the ANNOTATED-always contract it violates"

# R6. ABANDONED SPINES ARE NOT IN THE TAG SET (round 4, T14): the selector
# filters by spine-id prefix only, so an abandoned spine's work items drag
# their repos into the tag pass. The block's selector must filter to spines
# whose landing actually completed - asserted on the query the block actually
# runs, via the shim's argument log.
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'" >/dev/null 2>&1 || true
_last_get="$(grep 'get ' "$PR_SHIM/args.log" | tail -1)"
case "$_last_get" in
  *closed*target_repo*|*target_repo*closed*) T_PASS=$((T_PASS+1));;
  *) T_FAIL=$((T_FAIL+1)); echo "FAIL: R6 - the tag-set query does not filter to closed spines: $_last_get";;
esac

# R7. CONFLICTING BASE BRANCHES IN ONE REPO (round 4, T16): two closed spines
# recording different bases in the same repo must halt - first-wins silently
# tags one of the two landed lines.
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main
canonical:release-line'; . '$TAG_BLOCK'"
t_assert_rc 1 "R7: two recorded bases for one repo halt the tag pass"
t_assert_contains "$T_OUT" "conflicting base" "R7: ...naming the conflict, not silently picking a line"

# R8. THE EMPTY TAG SET (F18, deferred from #520 into #533). A release whose
# closed spines hold only abandoned items - or no items at all - has no
# non-abandoned work item to name a repo, so `tag_repos` is empty. The block's
# own comment names the failure it was written for (a selector failure makes the
# loop tag NOTHING and the pass still return 0); the empty set reaches the same
# outcome through a door the comment does not cover. Measured on 3a4182b against
# this shim: rc 0, no tag anywhere, no halt - the close record then says the
# release published, which is the audit-trail break release-close.md §3 itself
# refuses to allow. The cause is reachable without corruption: an abandoned spine
# passes the release gate deliberately (spinegate, T1/T2) and a spine can be
# closed by hand.
F18SHIM="$TMP/f18-shim"; mkdir -p "$F18SHIM"
{ printf '#!/usr/bin/env bash\ncase "$1 $2" in\n'
  printf '  "get "*)            echo "" ;;\n'
  printf '  "repo_root "*)      echo canonical ;;\n'
  printf '  *)                  exit 0 ;;\nesac\n'
} > "$F18SHIM/oss"; chmod +x "$F18SHIM/oss"
t_capture env "PATH=$F18SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 1 "R8: an EMPTY tag set halts the tag pass"
t_assert_contains "$T_OUT" "no repo to tag" "R8: ...naming the empty set as the reason"
t_assert_contains "$T_OUT" "abandoned" "R8: ...and the cause the operator has to judge"
t_assert_contains "$T_OUT" "work_item_status" "R8: ...and the route out when a withdrawal was a mistake"
# Un-withdrawing ALONE re-tags a repo whose work never landed: the selector above
# takes any non-abandoned item in a closed spine, and this item's spine is closed
# by construction here. So the route out must reopen the spine and land the work.
t_assert_contains "$T_OUT" "spine_add <release> <name> <class> <target-repo>" "R8: ...with the NEW spine the work must move to, since reopening cannot re-enable a spine whose branch close left in place (round-orchestration.md section 2, issue #133)"
# The ADJACENT CONTROL is R1-R7 above, on the live fixtures: the same block with
# a NON-empty tag set still tags (`tagged r9`). It is not repeated here with a
# second shim - a second canned fixture would assert the shim, not the block.

# P11. A CLOSED-UNMERGED PR is not a resumable landing (round 5, T20):
# --state all selects it, creation is suppressed, work-pr refuses it and the
# record pass rejects CLOSED - a wedge. Only OPEN and MERGED resume.
_pr_fixture p11
printf "7 CLOSED\n" > "$PR_STATE/pr"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 0 "P11: a closed-unmerged PR does not wedge the landing pass"
case "$T_OUT" in
  *"already has PR"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: P11 - the probe resumed a CLOSED-unmerged PR";;
  *) T_PASS=$((T_PASS+1));;
esac
t_assert_contains "$T_OUT" "PR #7 opened against main" "P11: ...a replacement PR is opened instead"

# P12. THE GHE HOST SURVIVES the --repo derivation (round 5, T24): an
# Enterprise remote must pin the selector to ITS host, not gh's default.
_pr_fixture p12
# The remote's URL carries an Enterprise host the stub will declare
# unoperable: the slug derivation runs BEFORE the probe, and the probe before
# any push, so the block halts at the third leg with the derived selector
# already on record - no network, and the host pinning is what the stub saw.
git -C "$PR_REPO" remote set-url origin https://ghe.example.com/owner/repo.git
touch "$PR_STATE/nongithub"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 1 "P12: an unreachable Enterprise host halts at the third leg (before any push)"
t_assert_contains "$T_OUT" "silent local fall-through" "P12: ...the gh-inoperable halt, not a network attempt"
t_assert_eq "ghe.example.com/owner/repo" "$(cat "$PR_STATE/gh_repo")" "P12: the selector carries the remote's host"

# R8. THE TAG-SET SELECTOR against REAL STATE and DISTINCT REPOS (round 5
# T22/T23/T25; discriminating form per round 6 T26): presence assertions
# cannot tell a scoped selector from an unscoped one when every spine targets
# the same repo, so this fixture declares three - the CURRENT release's
# closed spine lands in "current", an earlier closed release's in "earlier",
# an abandoned spine's in "abandon" - and the assertion is EQUALITY. Since
# 1.11.0 a fourth repo, "withdrawn", is named ONLY by an `abandoned` work item
# inside the current release's closed spine: minted, withdrawn before dispatch,
# so nothing landed there and no base was recorded - a selector that forgets
# the work-item status names it too.
mkdir -p "$TMP/r8ws/.ossify" "$TMP/r8cur" "$TMP/r8earl" "$TMP/r8aband" "$TMP/r8wd"
cat > "$TMP/r8ws/.ossify/topology.json" <<R8TOPO
{"schema_version":1,"repos":{"current":{"root":"$TMP/r8cur"},"earlier":{"root":"$TMP/r8earl"},"abandon":{"root":"$TMP/r8aband"},"withdrawn":{"root":"$TMP/r8wd"}},"well_known_paths":{}}
R8TOPO
( cd "$TMP/r8ws"
  bash "$OSS" init r8f >/dev/null
  R8REL="$(bash "$OSS" release_add g goal)"
  R8EARLY_REL="$(bash "$OSS" release_add e "earlier goal")"
  R8EARLY_SP="$(bash "$OSS" spine_add "$R8EARLY_REL" es flesh earlier)"
  bash "$OSS" work_item_add "$R8EARLY_SP" ei earlier >/dev/null
  bash "$OSS" spine_status "$R8EARLY_SP" closed >/dev/null
  R8ABANDON_SP="$(bash "$OSS" spine_add "$R8REL" as flesh abandon)"
  bash "$OSS" work_item_add "$R8ABANDON_SP" ai abandon >/dev/null
  bash "$OSS" spine_status "$R8ABANDON_SP" abandoned >/dev/null
  R8CLOSED_SP="$(bash "$OSS" spine_add "$R8REL" cs flesh current)"
  R8CI="$(bash "$OSS" work_item_add "$R8CLOSED_SP" ci current)"
  R8WD="$(bash "$OSS" work_item_add "$R8CLOSED_SP" wd withdrawn)"
  bash "$OSS" work_item_status "$R8WD" abandoned >/dev/null
  bash "$OSS" spine_status "$R8CLOSED_SP" closed >/dev/null
  printf '%s\n' "$R8REL" > "$TMP/r8ws/.rel"
  printf '%s %s %s\n' "$R8CLOSED_SP" "$R8CI" "$R8WD" > "$TMP/r8ws/.ids"
)
R8REL="$(cat "$TMP/r8ws/.rel")"
read -r R8CLOSED_SP R8CI R8WD < "$TMP/r8ws/.ids"
# Run the assignment line AS BASH SOURCE (eval), so the shell processes the
# jq escapes exactly as the shipped script does - passing the extracted text
# through quotes leaves the backslashes as data and jq fails on \$root.
SEL_ASSIGN="$(grep 'tag_repos=' "$TAG_BLOCK" | head -1 | sed 's/ *\\$//')"
sel_rc=0; SEL_OUT="$(cd "$TMP/r8ws" && rel="$R8REL" PATH="$(dirname "$OSS"):$PATH" eval "$SEL_ASSIGN" && printf '%s' "$tag_repos")" || sel_rc=$?
# Assert on $sel_rc directly - there is no t_capture here, so T_RC would hold
# the PREVIOUS capture's status and read green or red for the wrong scenario.
t_assert_eq 0 "$sel_rc" "R8: the tag-set selector executes against real state (a jq failure would abort)"
t_assert_eq "current" "$SEL_OUT" "R8: the selector yields EXACTLY the current release's closed-spine repo (an unscoped selector would name earlier/abandon too, a status-blind one withdrawn)"

# R9. EVERY SPINE-SCOPED SELECTOR SKIPS AN `abandoned` WORK ITEM (1.11.0). The
# same fixture's closed spine holds one live item in "current" and one
# withdrawn item alone in "withdrawn". Each assignment below is read out of the
# SHIPPED file and evaluated as bash source, R8's way; each must name the live
# item's repo (or id) and never the withdrawn one. A selector that still names
# it halts the close on an unresolvable base (landing, review), cuts a branch
# nothing will use (round walk), or reports a missing report that is not one
# (harvest).
# The extraction refuses BOTH ways `oss_block_extract` does, for the same
# reason (tests/lib/blocks.sh): "not found" and "found twice" are different
# failures, and folding them together reports an ambiguous anchor as a missing
# one. `grep -F | head -1` did exactly the folding - silently binding to
# whichever occurrence came first - and an EMPTY extraction fed to `eval`
# returns 0, so an rc assertion could pass having executed nothing. (GLM seat,
# round 1 on PR #520.)
_r9_pick() { # $1=file $2=literal-anchor ; echoes the one line, rc 1=absent 2=ambiguous
  local n
  n="$(grep -cF -- "$2" "$1" 2>/dev/null)" || n=0
  if [ "$n" -eq 0 ]; then return 1; fi
  if [ "$n" -gt 1 ]; then return 2; fi
  grep -F -- "$2" "$1" | sed 's/ *\\$//'
}
_r9_extract() { # $1=file $2=anchor $3=label ; echoes the line, rc 9=absent 8=ambiguous
  local line rc
  line="$(_r9_pick "$1" "$2")"; rc=$?
  if [ "$rc" -eq 1 ]; then echo "$3-NO-LINE"; return 9; fi
  if [ "$rc" -eq 2 ]; then echo "$3-AMBIGUOUS"; return 8; fi
  printf '%s' "$line"
}
_r9_eval() { # $1=file $2=anchor $3=var-to-print ; echoes the value, rc from the eval
  local line rc
  line="$(_r9_extract "$1" "$2" R9)"; rc=$?
  if [ "$rc" -ne 0 ]; then printf '%s\n' "$line"; return "$rc"; fi
  ( cd "$TMP/r8ws" && spine_id="$R8CLOSED_SP" repo_list="$TMP/r9-list" \
      PATH="$(dirname "$OSS"):$PATH" eval "$line" && eval "printf '%s' \"\$$3\"" )
}
for _r9 in \
  "$SKILLS/close/references/spine-close.md|landing_repos=\"\$(|landing_repos|current" \
  "$SKILLS/close/references/code-review.md|hosting_repos=\"\$(|hosting_repos|current" \
  "$SKILLS/close/references/harvest.md|items=\"\$(|items|$R8CI"; do
  _f="${_r9%%|*}"; _rest="${_r9#*|}"; _anchor="${_rest%%|*}"; _rest="${_rest#*|}"; _var="${_rest%%|*}"; _want="${_rest#*|}"
  r9_rc=0; R9_OUT="$(_r9_eval "$_f" "$_anchor" "$_var")" || r9_rc=$?
  t_assert_eq 0 "$r9_rc" "R9: ${_f##*/} \$$_var executes against real state"
  t_assert_eq "$_want" "$R9_OUT" "R9: ${_f##*/} \$$_var names exactly the live item's $( [ "$_var" = items ] && echo id || echo repo ), not the withdrawn one"
done
# round-orchestration.md §2a now captures the state read before sorting it.
# Pin that shipped assignment against real state; the whole fresh fence and
# its failed-read rail run separately in test-reentry-read-guards.sh.
R9CUT_LINE="$(_r9_extract "$SKILLS/work-item/references/round-orchestration.md" "get '.work_items[] | select(.spine==" R9CUT)"; r9_cut_rc=$?
t_assert_eq 0 "$r9_cut_rc" "R9CUT: the round walk's hosting-repo assignment is extracted at all"
R9_CUT="$(printf '%s' "$R9CUT_LINE" | sed "s/<spine-id>/$R8CLOSED_SP/")"
r9_rc=0; R9_REPOS="$(cd "$TMP/r8ws" && PATH="$(dirname "$OSS"):$PATH" bash -c 'set -euo pipefail; eval "$1"; printf "%s" "$repos"' fresh "$R9_CUT")" || r9_rc=$?
t_assert_eq 0 "$r9_rc" "R9: round-orchestration.md's hosting-repo read executes against real state in a fresh shell"
t_assert_eq "current" "$R9_REPOS" "R9: the spine branch is cut only where a live item runs - never in a repo only a withdrawn item names"

# R10. THE CLASS FORM OF R9, and its limit, stated here where it can be read.
# R9 pins four files BY NAME, so a fifth spine-scoped SELECTOR written without
# the abandoned conjunct passes CI - and that is not hypothetical: the round-1
# review found readers that the named list had missed. This asserts the
# invariant over the shipped tree instead: every `work_items[]` read that
# mentions `.spine` must also mention `abandoned` (either conjunct; the
# `withdrawn=` line selects the abandoned set on purpose).
#
# WHAT IT CANNOT SEE, and why it is not a substitute for reading the readers:
# PROSE readers with no selector at all. code-review.md's Layer 4 `verify.md`
# walk and Axis B's `spec.md` read are that shape, and the same sweep missed
# both. This test closes the selector half of the class only.
R10_EXEMPT='plan-spine/references/cross-repo.md'   # a plan-time read-back: showing a withdrawn item there is the point
r10_checked=0
while IFS= read -r _hit; do
  _rf="${_hit%%:*}"; _rl="${_hit#*:}"; _rf="${_rf#./}"
  if [ "$_rf" = "$R10_EXEMPT" ]; then T_PASS=$((T_PASS+1)); continue; fi
  r10_checked=$((r10_checked+1))
  case "$_rl" in
    *abandoned*) T_PASS=$((T_PASS+1)) ;;
    *) T_FAIL=$((T_FAIL+1)); echo "FAIL: R10: $_rf has a spine-scoped work-item read with no abandoned conjunct: $(printf '%s' "$_rl" | cut -c1-110)" ;;
  esac
done < <(cd "$SKILLS" && grep -rn 'work_items\[\]' . 2>/dev/null | grep '\.spine')
# A floor, not a total: if the grep itself broke, every assertion above would be
# vacuously true. Nine sites ship today; the floor guards the walk, it does not
# pin the count.
if [ "$r10_checked" -ge 5 ]; then T_PASS=$((T_PASS+1)); else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: R10: only $r10_checked spine-scoped selectors enumerated - the sweep is broken and its assertions are vacuous"
fi

# The open-item gate itself (spine-close.md §2), on the same spine: the planned
# live item still HALTS it (the adjacent control - the loosening is abandoned
# only), the withdrawn one is never named as an offender, and once the live
# item is complete the gate passes and names the withdrawal instead.
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$TMP/r8ws' && set -euo pipefail; spine_id='$R8CLOSED_SP'; . '$OPEN_BLOCK'"
t_assert_rc 1 "R9: a planned item still halts the gate beside an abandoned one"
t_assert_contains "$T_OUT" "not complete: $R8CI - halt" "R9: ...naming only the live item"
case "$T_OUT" in *"$R8WD"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: R9: the gate named the withdrawn item $R8WD as an offender" ;; *) T_PASS=$((T_PASS+1)) ;; esac
( cd "$TMP/r8ws" && bash "$OSS" work_item_exec "$R8CI" "work/$R8CI" "$TMP/r8ws/.worktrees/$R8CI" "sha-r8ci" >/dev/null )  # complete needs a dispatch (#563)
( cd "$TMP/r8ws" && bash "$OSS" work_item_status "$R8CI" complete >/dev/null )
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$TMP/r8ws' && set -euo pipefail; spine_id='$R8CLOSED_SP'; . '$OPEN_BLOCK'"
t_assert_rc 0 "R9: complete + abandoned passes the gate - under set -e, so the withdrawn line's form is proven too"
t_assert_contains "$T_OUT" "withdrew work items before dispatch: $R8WD" "R9: ...and the close names the withdrawal"

# P13. THE CLASS SWEEP, instance 1 (T16's class, landing + record passes):
# a per-repo base mapping with TWO entries for one repo is a halt everywhere
# it is consumed - the tag pass fixed this in round 4; the landing and record
# passes still first-wins.
_pr_fixture p13
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main
canonical:release-line'; . '$MERGE_BLOCK'"
t_assert_rc 1 "P13: conflicting bases halt the LANDING pass"
t_assert_contains "$T_OUT" "conflicting base" "P13: ...naming both lines, not first-wins"
_pr_fixture p13b
printf "7 MERGED\n" > "$PR_STATE/pr"
git -C "$PR_REPO" rev-parse "$PR_BRANCH" > "$PR_STATE/head_oid"
git -C "$PR_REPO" rev-parse "$PR_BRANCH" > "$PR_STATE/merge_commit"
printf "%s\n" "$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")" > "$PR_STATE/pushed_tip"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; spine_branch='spine/r0.s5-tier'; repo_base_branches='canonical:main
canonical:release-line'; pr_lines='canonical:7'; . '$PRRECORD_BLOCK'"
t_assert_rc 1 "P13b: conflicting bases halt the RECORD pass"
t_assert_contains "$T_OUT" "conflicting base" "P13b: ...same guard, same halt"

# P14. THE CLASS SWEEP, instance 2 (T23's class, landing pass): a selector
# failure inside the process substitution silently yields ZERO repos and the
# pass succeeds having landed nothing. The repo list is read as an
# assignment whose failure aborts, never as a silent empty loop.
mkdir -p "$TMP/p14-shim"
{ printf '#!/usr/bin/env bash\ncase "$1 $2" in\n  "repo_root canonical") echo %s ;;\n  "branch_name "*) echo %s ;;\n  *"target_repo"*) exit 5 ;;\n  *) exit 5 ;;\nesac\n' "$TMP/p13" "$PR_BRANCH"; } > "$TMP/p14-shim/oss"
chmod +x "$TMP/p14-shim/oss"
t_capture env "PATH=$TMP/p14-shim:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
if [ "$T_RC" -eq 0 ]; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: P14 - a repo-list read failure succeeded silently, landing nothing"
else
  T_PASS=$((T_PASS+1))
fi

# P15. A RESUMED PR WHOSE HEAD EXISTS ONLY REMOTELY (round 7, T27): work-pr or
# a hand-driven loop can push fix commits from ANOTHER checkout, so gh reports
# a headRefOid this checkout does not have. The pre-handoff lineage check must
# fetch the head before judging it, or every such resume halts on "unknown
# revision".
_pr_fixture p15
# The spine branch must be on the remote before the clone can build on it;
# _pr_fixture leaves it local-only (the landing pass is what pushes it).
git -C "$PR_REPO" push -q origin "$PR_BRANCH"
# A commit on the spine branch made and pushed from a SEPARATE clone - the
# ceremony checkout never sees it locally.
CL15="$TMP/p15-clone"; rm -rf "$CL15"; git clone -q "$PR_ORIGIN" "$CL15"
git -C "$CL15" config user.email t@t; git -C "$CL15" config user.name t
git -C "$CL15" checkout -q "$PR_BRANCH"
echo remotefix > "$CL15/remotefix.txt"; git -C "$CL15" add remotefix.txt; git -C "$CL15" commit -qm remotefix
git -C "$CL15" push -q origin "$PR_BRANCH"
REMOTE_HEAD15="$(git -C "$CL15" rev-parse "$PR_BRANCH")"
if git -C "$PR_REPO" cat-file -e "$REMOTE_HEAD15" 2>/dev/null; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: P15 fixture is vacuous - the ceremony checkout already has the remote head"
else
  T_PASS=$((T_PASS+1))
fi
printf "7 OPEN\n" > "$PR_STATE/pr"
printf "%s\n" "$REMOTE_HEAD15" > "$PR_STATE/head_oid"
P15_LOCAL_TIP="$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")"
git -C "$PR_REPO" rev-parse "$PR_BRANCH" > /tmp/p15-tip; mv /tmp/p15-tip "$PR_STATE/pushed_tip"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 0 "P15: a remotely-only resumed head is fetched and lineage-checked, not halted as unknown"
t_assert_contains "$T_OUT" "already has PR #7" "P15: ...and the resume proceeds to the handoff"
t_assert_eq "$P15_LOCAL_TIP" "$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")" \
  "P15: ...without moving the local spine branch (the fetch installed the object, nothing more)"

# R9. THE TAG THAT EXISTS ONLY ON THE REMOTE (round 7, T28): an earlier
# multi-repo close pushed the tag and halted; the resumed close runs from a
# fresh, no-tags checkout. Local-only existence testing takes the creation
# arm, mints a different annotated object, and the push is refused - the
# resume wedges. The remote must be consulted before creating.
_pr_fixture r9
CL9="$TMP/r9-clone"; rm -rf "$CL9"; git clone -q "$PR_ORIGIN" "$CL9"
git -C "$CL9" config user.email t@t; git -C "$CL9" config user.name t
git -C "$CL9" checkout -q main
# A DIFFERENT message than the block's own "release $rel" mint: two annotated
# tags minted in the same second with identical tagger and message produce the
# SAME object sha, the push then reads "up-to-date", and the fixture loses its
# discrimination entirely.
git -C "$CL9" tag -a r9 -m "tagged by the earlier halted close" main
git -C "$CL9" push -q origin r9
R9_REMOTE_TAG="$(git --git-dir="$PR_ORIGIN" rev-parse 'refs/tags/r9')"
if git -C "$PR_REPO" rev-parse -q --verify 'refs/tags/r9' >/dev/null 2>&1; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: R9 fixture is vacuous - the local checkout already has the tag"
else
  T_PASS=$((T_PASS+1))
fi
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 0 "R9: a remote-only existing tag is fetched and resumed, not re-created"
t_assert_contains "$T_OUT" "already tagged" "R9: ...through the same verification arm"
t_assert_eq "$R9_REMOTE_TAG" "$(git -C "$PR_REPO" rev-parse 'refs/tags/r9')" "R9: the remote tag object stands - no second annotation was minted"

# P16. THE RESUMED PR MUST CONTAIN THE CURRENT TIP (round 8, T32): the
# pre-handoff check proves the PUSHED tip's ancestry, but the local spine
# branch can have advanced after the PR was opened - merging the old PR would
# close the spine while silently omitting the newer commits. A halt naming
# both tips, never a guess about which to keep.
_pr_fixture p16
git -C "$PR_REPO" push -q origin "$PR_BRANCH"
CL16="$TMP/p16-clone"; rm -rf "$CL16"; git clone -q "$PR_ORIGIN" "$CL16"
git -C "$CL16" config user.email t@t; git -C "$CL16" config user.name t
git -C "$CL16" checkout -q "$PR_BRANCH"
printf "7 OPEN\n" > "$PR_STATE/pr"
P16_PUBLISHED_TIP="$(git -C "$PR_REPO" rev-parse "$PR_BRANCH")"
printf "%s\n" "$P16_PUBLISHED_TIP" > "$PR_STATE/pushed_tip"
printf "%s\n" "$P16_PUBLISHED_TIP" > "$PR_STATE/head_oid"
# The local spine branch advances AFTER the PR was opened - not pushed.
echo late > "$PR_REPO/late.txt"; git -C "$PR_REPO" add late.txt; git -C "$PR_REPO" commit -qm "late local work"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 1 "P16: a resumed PR missing the current local tip halts"
t_assert_contains "$T_OUT" "advanced past" "P16: ...naming the local tip the PR does not contain"

# R10. A BRANCH NAMED LIKE THE RELEASE (round 8, T30): refs/heads/r9 and
# refs/tags/r9 coexist, and a bare `git push <remote> r9` cannot resolve the
# source. The push uses a fully qualified tag refspec.
_pr_fixture r10
git -C "$PR_REPO" branch r9
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 0 "R10: the tag push resolves under a branch/tag name collision"
t_assert_contains "$T_OUT" "tagged r9" "R10: ...and lands"

# R11. THE BASE AHEAD OF THE REMOTE (round 8, T31): unpushed local commits on
# the base would be TAGGED and the tag object published while the published
# base branch never carries the commit the tag claims to mark. Halt naming
# the state - the D5 discipline.
_pr_fixture r11
# The fixture parks the repo on the SPINE branch; the unpushed commit must
# land on the BASE branch or the guard is never exercised.
git -C "$PR_REPO" checkout -q main
echo unpushed > "$PR_REPO/unpushed.txt"; git -C "$PR_REPO" add unpushed.txt
git -C "$PR_REPO" commit -qm unpushed
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 1 "R11: a base ahead of the remote halts before tagging"
t_assert_contains "$T_OUT" "published line does not carry" "R11: ...naming what the tag would falsely mark"
if git -C "$PR_REPO" rev-parse -q --verify 'refs/tags/r9' >/dev/null 2>&1; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: R11 - a tag was created despite the halt"
else
  T_PASS=$((T_PASS+1))
fi

# R12. A BASE BEHIND THE PUBLISHED TIP (round 10, T37): the round-9
# fast-forward ran AFTER the boundary audit had examined the stale tree, so
# the tag marked commits the audit never saw. Behind is now a REFUSAL: halt,
# name the state, pull-and-re-run is the remedy. No mutation of the base
# after the audit, ever.
_pr_fixture r12
CL12="$TMP/r12-clone"; rm -rf "$CL12"; git clone -q "$PR_ORIGIN" "$CL12"
git -C "$CL12" config user.email t@t; git -C "$CL12" config user.name t
git -C "$CL12" checkout -q main
echo final > "$CL12/final.txt"; git -C "$CL12" add final.txt; git -C "$CL12" commit -qm "the final spine PR merged elsewhere"
git -C "$CL12" push -q origin main
R12_REMOTE_TIP="$(git --git-dir="$PR_ORIGIN" rev-parse main)"
R12_STALE_TIP="$(git -C "$PR_REPO" rev-parse main)"
t_capture env "PATH=$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; rel='r9'; repo_base_branches='canonical:main'; . '$TAG_BLOCK'"
t_assert_rc 1 "R12: a base behind the published tip halts - never mutated after the audit"
t_assert_contains "$T_OUT" "behind the published tip" "R12: ...naming the state and the pull-and-re-run remedy"
if git -C "$PR_REPO" rev-parse -q --verify 'refs/tags/r9' >/dev/null 2>&1; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: R12 - a tag was created despite the halt"
else
  T_PASS=$((T_PASS+1))
fi
t_assert_eq "$R12_STALE_TIP" "$(git -C "$PR_REPO" rev-parse main)" "R12: the local base was left untouched (no post-audit mutation)"

# P17. A HOSTLESS REMOTE (round 9, T35): a filesystem remote path parses into
# a plausible owner/repo selector, aiming every gh call at an unrelated
# GitHub repository. The derivation must refuse hostless URLs - the empty
# selector trips the existing non-GitHub halt, never a wrong-repo handoff.
_pr_fixture p17
git -C "$PR_REPO" config --unset "url.$PR_ORIGIN.insteadOf"
git -C "$PR_REPO" remote set-url origin "$PR_ORIGIN"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 1 "P17: a filesystem-path remote halts instead of deriving a selector"
t_assert_contains "$T_OUT" "cannot derive an owner/repo" "P17: ...naming the derivation failure, not acting on a wrong repo"
if [ -f "$PR_STATE/gh_repo" ]; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: P17 - a gh call fired despite the hostless remote"
else
  T_PASS=$((T_PASS+1))
fi

# P18. SEVERAL REMOTES HALT, origin preference included (round 10, T36): in a
# fork checkout origin is the FORK and upstream the canonical repo - an
# origin-preferring rule PRs the fork. Any multi-remote shape halts naming
# them; the single-remote case (whatever its name) is the straightforward one.
_pr_fixture p18
git -C "$PR_REPO" remote add upstream "$PR_ORIGIN"
t_capture env "GH_STATE=$PR_STATE" "PATH=$GHSTUB:$PR_SHIM:$PATH" bash -c \
  "set -euo pipefail; spine_id='r0.s5'; spine_slug='tier'; repo_base_branches='canonical:main'; . '$MERGE_BLOCK'"
t_assert_rc 1 "P18: a two-remote (fork-shaped) repo halts the landing pass"
t_assert_contains "$T_OUT" "several remotes" "P18: ...naming them, never silently preferring origin"

# ---------------------------------------------------------------------------
# B-series — step 4b, the bones this spine's plan declares (#497). The block is
# EXTRACTED FROM THE SHIPPED PROSE and executed against a real scratch ossify
# state, like the E- and P-series above: the registry it writes is what
# `touch_check` reads and what a later spine's class declaration rides, so an arm
# that quietly registers nothing is invisible twice over. The spine directory is
# the one the ceremony's own glob recovers (SPINE.md lives there), and the ADR
# files sit in the hosting repo's docs/adr, the registry's own location.
# ---------------------------------------------------------------------------
B4WS="$TMP/b4ws"; B4CANON="$TMP/b4canon"
mkdir -p "$B4WS/.workspace" "$B4CANON/docs/adr"
printf '{"schema_version":"1.0","ai_workspace":{"root":"%s"},"canonical":{"root":"%s"},"well_known_paths":{}}\n' \
  "$B4WS" "$B4CANON" > "$B4WS/.workspace/pairing.json"
git -C "$B4CANON" init -q
git -C "$B4CANON" config user.email t@t; git -C "$B4CANON" config user.name t
echo seed > "$B4CANON/seed.txt"; git -C "$B4CANON" add seed.txt; git -C "$B4CANON" commit -qm seed
( cd "$B4WS" && bash "$OSS" init "bones fixtures" >/dev/null )
B4REL="$(cd "$B4WS" && bash "$OSS" release_add "the bones arm" "fixtures")"
B4SP="$(cd "$B4WS" && bash "$OSS" spine_add "$B4REL" "registers its bones" flesh)"
( cd "$B4WS" && bash "$OSS" work_item_add "$B4SP" "the item" canonical >/dev/null )
B4DIR="$B4WS/docs/specs/$B4REL/$B4SP-registers-its-bones"; mkdir -p "$B4DIR"
B4_BLOCK="$TMP/spine-bones.sh"
_b4_sha() { git -C "$B4CANON" rev-parse HEAD; }   # §3's merge_shas value: the commit
                                                  # this close landed in the hosting repo
_extract_block "$SPINE_CLOSE" 'Bones this spine registers' "$B4_BLOCK"
if [ -s "$B4_BLOCK" ] && grep -Fq 'Bones this spine registers' "$B4_BLOCK"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: could not extract the bones registration block from spine-close.md - the assertions below are vacuous"
fi
# The hosting repo owns the ADR the row promises; the file joins the series, so it
# is found by NUMBER and not by a name the row would have to guess. TRACKED in git,
# which the registration step requires (C-series): a file only this filesystem can
# see is not a record.
printf 'the bones fixture ADR\n' > "$B4CANON/docs/adr/adr-0024-the-touch-check-surface.md"
git -C "$B4CANON" add docs/adr/adr-0024-the-touch-check-surface.md
git -C "$B4CANON" commit -qm "fixture: the touch-check-surface ADR"
# SPINE.md: the plan's own file, with the section the row is read from.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Decomposition\n\nw1 the item\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0024 | the touch-check surface | src/domain/**,src/port.rs | a second storage backend |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"

# B1. A row whose ADR file exists and whose ref is not yet registered: the four
# columns land as bone_add's four arguments, in that order - a swapped pair
# registers the title as the touch surface and nothing reports it.
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "B1: a declared bone with its ADR file registered cleanly"
t_assert_contains "$T_OUT" "ADR-0024" "B1: ...saying which bone it registered"
t_assert_eq "ADR-0024" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0024") | .adr')" \
  "B1: the ref reached the registry"
t_assert_eq "the touch-check surface" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0024") | .title')" \
  "B1: ...with the row's TITLE in the title slot, not the touch surface"
t_assert_eq "src/domain/**, src/port.rs" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0024") | .touch | join(", ")')" \
  "B1: ...and the row's glob csv as the touch list"
t_assert_eq "a second storage backend" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0024") | .revisit_trigger')" \
  "B1: ...and its revisit trigger"

# B2. RESUME: a halted close re-runs this step with its earlier rows already
# registered. bone_add refuses the duplicate at rc 7 (#305), so without the skip
# the ceremony could never be resumed past its own earlier work.
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "B2: re-running the step over a registered ref does not halt"
t_assert_contains "$T_OUT" "bone ADR-0024 already registered - skipping" "B2: ...it skips it in one line, as the ceremony promises"
t_assert_eq "1" "$(cd "$B4WS" && bash "$OSS" get '[.bones[] | select(.adr=="ADR-0024")] | length')" \
  "B2: ...and the registry still holds exactly one record for the ref"

# B3. THE PROMISE: the row names an ADR this spine never wrote. Registering the
# index entry anyway points the registry at a decision no file records, and
# touch_check then reports a surface whose reasoning nobody can read.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0031 | a decision with no ADR file | src/other/** | |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "B3: a row whose ADR file is missing halts the close"
t_assert_contains "$T_OUT" "ADR-0031" "B3: ...naming the ref the plan declared"
t_assert_eq "0" "$(cd "$B4WS" && bash "$OSS" get '[.bones[] | select(.adr=="ADR-0031")] | length')" \
  "B3: ...and registering nothing for it"

# B3b. ADJACENT CONTROL, the other non-file: a ref this step cannot resolve to a
# file at all (an ADOPTED, letters-bearing identifier - a bone the plan only
# CITES, which is not a row). Halting on it is what keeps a cited bone out of the
# spine's own registry record; a step that treated it as a row would add a second
# record for a decision this spine did not make.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-A17 | an adopted identifier | src/other/** | |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "B3b: a row that is not a ref this project mints halts"
t_assert_contains "$T_OUT" "ADR-A17" "B3b: ...naming it"
t_assert_contains "$T_OUT" "not a numeric ADR ref" "B3b: ...as a row that is not a bone the spine creates, not as a missing file: the two halts have different repairs"

# B4/B5. NOTHING TO REGISTER, two ways: `None.` (the plan looked and found none)
# and no section at all (a spine planned before 1.19.0). Both register nothing,
# say so in one line, and NEVER halt - a spine that creates no bone is normal.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Demo contribution\n\n- a line\n\n## Bones this spine registers\n\nNone.\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "B4: a plan declaring None. registers nothing and does not halt"
t_assert_contains "$T_OUT" "declares no bones" "B4: ...saying so in one line"
t_assert_eq "1" "$(cd "$B4WS" && bash "$OSS" get '.bones | length')" \
  "B4: ...with the registry unchanged (the B1 record alone)"
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Demo contribution\n\n- a line\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "B5: a SPINE.md with no bones section (pre-1.19.0 plan) does not halt"
t_assert_eq "1" "$(cd "$B4WS" && bash "$OSS" get '.bones | length')" "B5: ...and registers nothing"

# B6. A row that is not FOUR cells is the failure this step exists to prevent, one
# shape in: it would drop out of the read without a word while SPINE.md still says
# the bone exists, so the registry and the plan disagree and only the file is read
# by a human. Halt and name the row - never skip it.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0042 | a row missing its revisit column and its trailing pipe | src/short/**\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "B6: a row that is not four cells halts"
t_assert_contains "$T_OUT" "ADR-0042" "B6: ...naming the row"
t_assert_contains "$T_OUT" "not four cells" "B6: ...for its own reason, not as a missing ADR file: the repairs differ"
t_assert_eq "0" "$(cd "$B4WS" && bash "$OSS" get '[.bones[] | select(.adr=="ADR-0042")] | length')" \
  "B6: ...and registering nothing for it"

# B7. THE SHIFTED CELL. A row whose Touch surface cell is EMPTY and whose revisit
# column is not: `read` with IFS=$'\t' treats tab as IFS *whitespace*, so an empty
# middle cell collapses and the revisit text shifts one slot left, into the touch
# surface. Both the loop's guard and `oss bone_add` then see a non-empty value, the
# row registers, and a prose phrase becomes the glob set that decides every later
# touch_check - silently. The cells are validated where their boundaries are known
# (in the reader over the table), not after the shift.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0051 | a row with no touch surface | | a second storage backend |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
# Its ADR file EXISTS, so the missing-file halt cannot mask the shift: the only
# thing standing between this row and a registered bone is the row's own shape.
printf 'the shifted-cell fixture ADR\n' > "$B4CANON/docs/adr/adr-0051-a-broken-row.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "B7: a row with an empty touch cell halts"
t_assert_contains "$T_OUT" "ADR-0051" "B7: ...naming the row"
t_assert_contains "$T_OUT" "not four cells" "B7: ...as a malformed row, which is what it is"
t_assert_eq "0" "$(cd "$B4WS" && bash "$OSS" get '[.bones[] | select(.adr=="ADR-0051")] | length')" \
  "B7: ...and registering nothing - the revisit text never lands in the touch slot"

# ---------------------------------------------------------------------------
# A-series (PR #792 round 1, review item 1): a PRESENT section that is not a table
# is not "no bones". Only lines starting with `|` were read, so `TBD`, a placeholder
# or a table written without its outer pipes yielded zero rows and the step said
# "declares no bones - registering none" - a false statement about a plan that does
# declare one, which is #497's own defect wearing a green light. Inside a PRESENT
# section every non-blank line is either the exact `None.` (and then it is the only
# content line) or a table line starting with `|`; anything else halts naming the
# line. An absent section stays the legacy no-op (B5).
# ---------------------------------------------------------------------------
# A1. A table written without its outer pipes: a table to a human, and to no reader.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\nADR-0024 | the touch-check surface | src/domain/** | a second backend\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "A1: a row written without its outer pipes halts"
t_assert_contains "$T_OUT" "ADR-0024" "A1: ...naming the line"
t_assert_contains "$T_OUT" "neither a table row nor the single None." "A1: ...as neither a table row nor None."
case "$T_OUT" in
  *"declares no bones"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: A1: a present section was reported as declaring no bones";;
  *) T_PASS=$((T_PASS+1));;
esac

# A2. A placeholder where the table belongs.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\nTBD\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "A2: a placeholder line in a present section halts"
t_assert_contains "$T_OUT" "TBD" "A2: ...naming it"

# A3. A present section with an empty body: neither the table nor `None.` was
# written, so the plan is unfinished, not boneless.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "A3: a present but empty section halts"
t_assert_contains "$T_OUT" "present but empty" "A3: ...as an unfinished section, not as a boneless plan"
case "$T_OUT" in
  *"declares no bones"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: A3: an empty present section was reported as declaring no bones";;
  *) T_PASS=$((T_PASS+1));;
esac

# A4. CONTROL: the section is the same section in any case. `## Bones This Spine
# Registers` is read, and its row registers.
printf 'the case-folded fixture ADR\n' > "$B4CANON/docs/adr/adr-0060-a-case-folded-heading.md"
git -C "$B4CANON" add docs/adr/adr-0060-a-case-folded-heading.md
git -C "$B4CANON" commit -qm "fixture: the case-folded-heading ADR"
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones This Spine Registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0060 | a case-folded heading | src/fold/** | |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "A4: a case-different heading is the same section and is read"
t_assert_eq "ADR-0060" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0060") | .adr')" \
  "A4: ...its row reached the registry"

# A4b. The section nested a level down, as `### ...` under `## Spine context` with a
# sibling after it: it is read, its row registers, and the sibling ends it (#859).
printf 'the nested fixture ADR\n' > "$B4CANON/docs/adr/adr-0601-a-nested-heading.md"
printf 'the nested-then-parent fixture ADR\n' > "$B4CANON/docs/adr/adr-0602-a-nested-then-parent.md"
git -C "$B4CANON" add docs/adr/adr-0601-a-nested-heading.md docs/adr/adr-0602-a-nested-then-parent.md
git -C "$B4CANON" commit -qm "fixture: the nested-heading ADRs"
printf '# %s - registers its bones\n\n## Spine context\n\n### Base branches\n\ncanonical | main\n\n### Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0601 | a nested heading | src/nested/** | |\n\n### Risk posture\n\nlow, and this line is not a bone\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "A4b: a ### section is read, and a ### sibling ends it"
t_assert_eq "ADR-0601" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0601") | .adr')" \
  "A4b: ...its row reached the registry"

# A4c. The same section ended by a heading above it.
printf '# %s - registers its bones\n\n## Spine context\n\n### Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0602 | a nested then parent | src/parent/** | |\n\n## Decomposition\n\nw1 the item\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "A4c: a heading above a ### section ends it"
t_assert_eq "ADR-0602" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0602") | .adr')" \
  "A4c: ...its row reached the registry"

# A4d. The issue's repro: a ### section stating its bone in prose. It halts, naming
# the line, and never reports a boneless plan.
printf '# %s - registers its bones\n\n## Spine context\n\n### Bones this spine registers\n\n**ADR-0031** the prose bone\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "A4d: a prose bone in a ### section halts"
t_assert_contains "$T_OUT" "ADR-0031" "A4d: ...naming the line"
case "$T_OUT" in
  *"declares no bones"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: A4d: a prose bone was reported as declaring no bones";;
  *) T_PASS=$((T_PASS+1));;
esac

# A4e. CONTROL: a deeper heading does not end a ## section, so a line under it is
# still in the section and still halts.
printf '# %s - registers its bones\n\n## Bones this spine registers\n\nNone.\n\n### Notes\n\nADR-0099 is planned\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "A4e: a deeper heading stays inside a ## section, and its lines still halt"
t_assert_contains "$T_OUT" "### Notes" "A4e: ...naming the first stray line"

# A4f. A `#` line between rows is no section end, with or without a space: rows below
# it must not go unread. It halts, naming the line (#1026 C1).
for _a4f in '#859 note' '# a comment'; do
  printf '# %s - registers its bones\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n%s\n| ADR-0603 | a row below it | src/below/** | |\n' \
    "$B4SP" "$_a4f" > "$B4DIR/SPINE.md"
  t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
  t_assert_rc 1 "A4f: '$_a4f' between rows halts"
  t_assert_contains "$T_OUT" "$_a4f" "A4f: ...naming '$_a4f'"
done

# A4g. A fenced example of the heading above the real section: two matches, so it
# halts and registers neither, instead of reading the example as the plan's answer
# (#1026, CodeRabbit).
printf '# %s - registers its bones\n\n## Spine context\n\n```\n### Bones this spine registers\n\nNone.\n\n### Risk posture\n```\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0603 | the real row | src/real/** | |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "A4g: two matching headings halt"
t_assert_contains "$T_OUT" "## Bones this spine registers" "A4g: ...naming the second"
case "$T_OUT" in
  *"declares no bones"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: A4g: an example was read as the plan's answer";;
  *) T_PASS=$((T_PASS+1));;
esac

# A4h. CONTROL, and the PR's stated limit: a heading with other text on its line is
# not the section, so it stays the legacy no-op.
printf '# %s - registers its bones\n\n### Bones this spine registers:\n\n| ADR-0603 | a row | src/x/** | |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "A4h: a heading with a trailing colon is not the section"
t_assert_contains "$T_OUT" "declares no bones" "A4h: ...and stays the legacy no-op"

# A5. `None.` AND a table: `None.` is the whole answer, so one of the two is wrong
# and neither the step nor the registry may pick one silently.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\nNone.\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0061 | a row beside None. | src/beside/** | |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "A5: None. beside a table halts"
t_assert_contains "$T_OUT" "None." "A5: ...naming the contradiction"
t_assert_eq "0" "$(cd "$B4WS" && bash "$OSS" get '[.bones[] | select(.adr=="ADR-0061")] | length')" \
  "A5: ...and picking neither side"

# ---------------------------------------------------------------------------
# B8-B12 (PR #792 round 1, review item 3): `already registered` is a SKIP only when
# the row matches. The ref alone is not the row: a plan that changed a column after
# its bone was registered would skip in silence, leaving the registry describing a
# surface the plan no longer declares. And a ref is one ref in any case -
# `adr-0024` is `ADR-0024` - or one decision mints a second bone that no check can
# tell from the first. The registry row these fixtures test against is B1's.
# ---------------------------------------------------------------------------
# B8. CONTROL: the same row in lower case is the same bone.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| adr-0024 | the touch-check surface | src/domain/**,src/port.rs | a second storage backend |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "B8: a lower-case ref that names a registered bone is that bone"
t_assert_contains "$T_OUT" "bone ADR-0024 already registered - skipping" "B8: ...skipped under the registry's own spelling"
t_assert_eq "1" "$(cd "$B4WS" && bash "$OSS" get '[.bones[] | select(.adr=="ADR-0024")] | length')" \
  "B8: ...with one record, not a second bone for the same decision"

# B9. CONTROL: the same surface written in the other order is the same surface.
# `touch_check` matches globs one by one, so the order is not part of it.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0024 | the touch-check surface | src/port.rs,src/domain/** | a second storage backend |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "B9: a reordered touch list is the same surface and skips"
t_assert_contains "$T_OUT" "already registered - skipping" "B9: ...with the skip line"

# B10. A DIFFERENT SURFACE halts: the plan and the registry disagree about the code
# this bone governs, and the surface is what every later touch_check reads.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0024 | the touch-check surface | src/OTHER/** | a second storage backend |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "B10: a row whose touch surface differs from the registered one halts"
t_assert_contains "$T_OUT" "ADR-0024" "B10: ...naming the ref"
t_assert_contains "$T_OUT" "touch surface" "B10: ...the field that differs"
t_assert_contains "$T_OUT" "src/OTHER/**" "B10: ...the plan's value"
t_assert_contains "$T_OUT" "src/domain/**" "B10: ...and the registry's, so the two can be compared"
t_assert_contains "$T_OUT" "bone_set_touch" "B10: ...with the repair named"
t_assert_eq "src/domain/**, src/port.rs" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0024") | .touch | join(", ")')" \
  "B10: ...and the registry row is untouched"

# B11. A different TITLE halts - the adjacent control, one field over.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0024 | a renamed title | src/domain/**,src/port.rs | a second storage backend |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "B11: a row whose title differs from the registered one halts"
t_assert_contains "$T_OUT" "title" "B11: ...naming the field"
t_assert_contains "$T_OUT" "a renamed title" "B11: ...the plan's value"
t_assert_eq "the touch-check surface" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0024") | .title')" \
  "B11: ...and the registry row is untouched"

# B12. An EMPTY plan cell against a stored trigger is a difference, not "no
# trigger": the registry would keep a revisit condition the plan dropped.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0024 | the touch-check surface | src/domain/**,src/port.rs | |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "B12: a plan row that dropped the revisit trigger halts"
t_assert_contains "$T_OUT" "revisit" "B12: ...naming the field"
t_assert_eq "a second storage backend" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0024") | .revisit_trigger')" \
  "B12: ...and the registry row is untouched"

# ---------------------------------------------------------------------------
# C1-C2 (PR #792 round 1, review item 4): the ADR file must be TRACKED. Any
# directory entry with the right number passed, so a draft nobody added, or a file
# an accident created, satisfied "the spine wrote the ADR" while git had never seen
# it - and the registry cited a path no clone can read. Whether the SPINE introduced
# the file is not required (a decision can be recorded in an older commit); being in
# history is.
# ---------------------------------------------------------------------------
# C1. The file exists here and is not tracked.
printf 'the untracked fixture ADR\n' > "$B4CANON/docs/adr/adr-0070-never-added.md"
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0070 | a decision nobody added | src/untracked/** | |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "C1: an ADR file that is not tracked in git halts"
t_assert_contains "$T_OUT" "adr-0070-never-added.md" "C1: ...naming the path the registry would have cited"
t_assert_contains "$T_OUT" "not tracked" "C1: ...and why it is not a record"
t_assert_eq "0" "$(cd "$B4WS" && bash "$OSS" get '[.bones[] | select(.adr=="ADR-0070")] | length')" \
  "C1: ...and registering nothing"

# C2 (PR #792 round 2, review item 1). STAGED IS NOT LANDED. `git ls-files
# --error-unmatch` accepts a path in the index that no commit holds, and what the
# registry cites must be readable from the tree THIS CLOSE landed in that repo
# (§3's $merge_shas) - or the citation promises a file no reader of the record has.
git -C "$B4CANON" add docs/adr/adr-0070-never-added.md
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "C2: an ADR file that is staged but not committed halts"
t_assert_contains "$T_OUT" "adr-0070-never-added.md" "C2: ...naming the path"
t_assert_contains "$T_OUT" "$(_b4_sha)" "C2: ...and the landed commit it is missing from"
t_assert_eq "0" "$(cd "$B4WS" && bash "$OSS" get '[.bones[] | select(.adr=="ADR-0070")] | length')" \
  "C2: ...and registering nothing"

# C3. CONTROL: the same row registers once the file is in the landed commit. Being
# NEW was never the question; being in the tree close landed is.
git -C "$B4CANON" commit -qm "fixture: the never-added ADR, now in the landed commit"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "C3: the same row registers once its ADR file is in the landed commit"
t_assert_eq "ADR-0070" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0070") | .adr')" \
  "C3: ...into the registry"

# ---------------------------------------------------------------------------
# A6-A7 (PR #792 round 2, review items 2a/2b): the parser skips only the TEMPLATE.
# Any row whose first cell read `ADR` was taken as the header, so a real data row
# that happened to spell its ref that way vanished - and an escaped `\|` inside a
# cell was read as a cell boundary, splitting one title into two cells and shifting
# every column after it. A row is the header only when all four cells are the
# template's; a row is the separator only when every cell is `-`/`:`; a `\|` is cell
# text.
# ---------------------------------------------------------------------------
# A6. A data row whose ref is literally `ADR`, beside a valid one: the row is not
# the header, so it is validated - and `ADR` is not a ref this project mints.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0024 | the touch-check surface | src/domain/**,src/port.rs | a second storage backend |\n| ADR | a row that is not the header | src/beside/** | |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 1 "A6: a data row whose ref cell reads ADR halts"
t_assert_contains "$T_OUT" "is not a numeric ADR ref" "A6: ...as a bad ref, not as the header to skip"

# A7. An ESCAPED PIPE is cell text. The title cell carries `Postgres \| SQLite`; the
# registry must store the title with one pipe and the touch surface must stay one
# glob, not the half of a split line.
printf 'the escaped-pipe fixture ADR\n' > "$B4CANON/docs/adr/adr-0002-postgres-or-sqlite.md"
git -C "$B4CANON" add docs/adr/adr-0002-postgres-or-sqlite.md
git -C "$B4CANON" commit -qm "fixture: the escaped-pipe ADR"
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0002 | Postgres \\| SQLite | src/esc/** | |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "A7: a title carrying an escaped pipe registers"
t_assert_eq "Postgres | SQLite" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0002") | .title')" \
  "A7: ...with the pipe as cell text, not as a boundary"
t_assert_eq "src/esc/**" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0002") | .touch | join(", ")')" \
  "A7: ...and the touch surface unsplit"

# ---------------------------------------------------------------------------
# B13-B14 (PR #792 round 2, review item 3): one ADR NUMBER is one registry key.
# `ADR-24` and `ADR-0024` name one decision, and the registry keys on a string -
# so a plan row spelled differently minted a second bone for it, and the two then
# drove touch_check independently. The canonical ref is `ADR-` plus the digits
# exactly as the matched ADR FILE spells them; a registry row whose number equals
# the row's number under another spelling is the same bone.
# ---------------------------------------------------------------------------
# B13. The plan row is unpadded; the file (and the registry) spell it `0024`.
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-24 | the touch-check surface | src/domain/**,src/port.rs | a second storage backend |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "B13: an unpadded ref naming a registered bone is that bone"
t_assert_contains "$T_OUT" "bone ADR-0024 already registered - skipping" "B13: ...skipped under the registry's spelling"
t_assert_eq "1" "$(cd "$B4WS" && bash "$OSS" get '[.bones[] | select((.adr | sub("^[Aa][Dd][Rr]-0*"; "")) == "24")] | length')" \
  "B13: ...with one bone for the number, not two spellings of it"

# B14. The other direction: the REGISTRY holds the short spelling, the file spells
# `0040`, and the plan writes the file's spelling. Seeded directly, because the
# canonical form now comes from the file and only an older registry can be short.
( cd "$B4WS" && bash "$OSS" bone_add "ADR-40" "the short-form bone" "src/short-form/**" "revisit at 2.0" >/dev/null )
printf 'the short-form fixture ADR\n' > "$B4CANON/docs/adr/adr-0040-a-short-form.md"
git -C "$B4CANON" add docs/adr/adr-0040-a-short-form.md
git -C "$B4CANON" commit -qm "fixture: the short-form ADR"
printf '# %s - registers its bones\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n| ADR | Title | Touch surface (glob csv) | Revisit when |\n|---|---|---|---|\n| ADR-0040 | the short-form bone | src/short-form/** | revisit at 2.0 |\n' \
  "$B4SP" > "$B4DIR/SPINE.md"
t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$B4SP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
t_assert_rc 0 "B14: a padded ref naming a registry row spelled short is that bone"
t_assert_contains "$T_OUT" "bone ADR-40 already registered - skipping" "B14: ...skipped under the registry's spelling"
t_assert_eq "1" "$(cd "$B4WS" && bash "$OSS" get '[.bones[] | select((.adr | sub("^[Aa][Dd][Rr]-0*"; "")) == "40")] | length')" \
  "B14: ...with one bone for the number"

# ---------------------------------------------------------------------------
# R-series (PR #792 round 2, review item R): registering a bone IS a bone decision.
# 5b's own premise says so, and the touch check below only catches it when the new
# surface happens to hit this diff - a `not-applicable` or future-facing glob never
# does. So a flesh spine that registered at least one NEW bone is reclassified at the
# end of this step; a `bone` spine gets no call, and a run that only skipped
# registered rows changes nothing.
# ---------------------------------------------------------------------------
_b4_other_spine() { # $1=name $2=class $3=the bones-section body ; sets OSP/OD
  OSP="$(cd "$B4WS" && bash "$OSS" spine_add "$B4REL" "$1" "$2")"
  ( cd "$B4WS" && bash "$OSS" work_item_add "$OSP" "the item" canonical >/dev/null )
  OD="$B4WS/docs/specs/$B4REL/$OSP-$(printf '%s' "$1" | tr ' ' '-')"
  mkdir -p "$OD"
  printf '# %s - %s\n\n## Spine context\n\ncanonical | main\n\n## Bones this spine registers\n\n%s' \
    "$OSP" "$1" "$3" > "$OD/SPINE.md"
}
_b4_run_other() { # 5b, for OSP, with 3's merge_shas injected
  t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$B4WS'; set -euo pipefail; spine_id='$OSP'; merge_shas='canonical:$(_b4_sha)'; . '$B4_BLOCK'"
}
_B4_TABLE='| ADR | Title | Touch surface (glob csv) | Revisit when |
|---|---|---|---|
'

# R1. FLESH + A NEW BONE whose surface MISSES this diff: the class moves anyway, once,
# with the refs in the reason.
printf 'the registration fixture ADR\n' > "$B4CANON/docs/adr/adr-0090-registration-is-a-decision.md"
git -C "$B4CANON" add docs/adr/adr-0090-registration-is-a-decision.md
git -C "$B4CANON" commit -qm "fixture: the registration ADR"
_b4_other_spine "flesh registers a bone" flesh "$_B4_TABLE| ADR-0090 | registration is a decision | src/missed/** | |
"
t_assert_eq "flesh" "$(cd "$B4WS" && bash "$OSS" get ".spines[] | select(.id==\"$OSP\") | .class")" \
  "R1: the fixture spine really is flesh (the guard's precondition)"
_b4_run_other
t_assert_rc 0 "R1: a flesh spine registering a bone closes the step cleanly"
t_assert_eq "ADR-0090" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0090") | .adr')" \
  "R1: ...the bone is registered"
t_assert_eq "bone" "$(cd "$B4WS" && bash "$OSS" get ".spines[] | select(.id==\"$OSP\") | .class")" \
  "R1: ...and the spine is reclassified, though the glob missed the diff"
t_assert_eq "bone registered at close: ADR-0090" \
  "$(cd "$B4WS" && bash "$OSS" get ".class_overrides[] | select(.spine==\"$OSP\") | .reason")" \
  "R1: ...with the refs in the reason"
t_assert_eq "1" "$(cd "$B4WS" && bash "$OSS" get "[.class_overrides[] | select(.spine==\"$OSP\")] | length")" \
  "R1: ...once, not twice"

# R2. CONTROL: a `bone` spine gets no call - the same read 6.1 uses for its own.
printf 'the bone-spine fixture ADR\n' > "$B4CANON/docs/adr/adr-0091-a-bone-spine-row.md"
git -C "$B4CANON" add docs/adr/adr-0091-a-bone-spine-row.md
git -C "$B4CANON" commit -qm "fixture: the bone-spine ADR"
_b4_other_spine "already bone" bone "$_B4_TABLE| ADR-0091 | a bone spine row | src/also/** | |
"
_b4_run_other
t_assert_rc 0 "R2: a bone spine registering a bone closes the step cleanly"
t_assert_eq "ADR-0091" "$(cd "$B4WS" && bash "$OSS" get '.bones[] | select(.adr=="ADR-0091") | .adr')" \
  "R2: ...the bone is still registered"
t_assert_eq "0" "$(cd "$B4WS" && bash "$OSS" get "[.class_overrides[] | select(.spine==\"$OSP\")] | length")" \
  "R2: ...and no class_set entry - a bone spine has nothing to change"

# R3. CONTROL, the other side: a flesh spine whose only row SKIPPED (already
# registered, fields equal) is not reclassified - the class moves on a NEW bone, not
# on seeing the section.
_b4_other_spine "flesh skips only" flesh "$_B4_TABLE| ADR-0024 | the touch-check surface | src/domain/**,src/port.rs | a second storage backend |
"
_b4_run_other
t_assert_rc 0 "R3: a flesh spine whose row was skipped closes the step cleanly"
t_assert_eq "flesh" "$(cd "$B4WS" && bash "$OSS" get ".spines[] | select(.id==\"$OSP\") | .class")" \
  "R3: ...and stays flesh - nothing was created"

cd /; rm -rf "$TMP"

# A FLOOR ON THE ASSERTION COUNT. Every check in test-block-ledger.sh proves
# this file EXTRACTS and SOURCES each covered block; none of them can see the
# behavioural assertions around that being deleted, and a file whose assertions
# are gone reports pass=0 fail=0 and exits 0. The floor is what makes wholesale
# removal loud. Raise it when the file grows; never lower it to make a run go
# green. (Codex P2 round 3 on PR #144.) Raised 220 -> 430 with the B-series
# (#497): the floor tracks the file's size, and 430 still leaves room for an
# ordinary edit to drop or fold a handful of assertions without a false alarm.
if [ "$T_PASS" -lt 430 ]; then
  echo "FAIL: test-close.sh ran only $T_PASS assertions (floor 430) - assertions were removed, not just skipped"
  T_FAIL=$((T_FAIL+1))
fi
t_summary
