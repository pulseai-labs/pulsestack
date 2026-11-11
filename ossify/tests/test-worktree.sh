#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor worktree; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"

mkdir -p "$TMP/ws/.workspace" "$TMP/canon"
git -C "$TMP/canon" init -q
git -C "$TMP/canon" config user.email t@t; git -C "$TMP/canon" config user.name t
echo seed > "$TMP/canon/f.txt"
# A TRACKED .gitignore, because that is the realistic case and it is what makes
# the "does not touch the project's own file" assertion below able to fail.
printf 'node_modules/\n' > "$TMP/canon/.gitignore"
git -C "$TMP/canon" add .; git -C "$TMP/canon" commit -qm seed
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
cd "$TMP/ws"

t_capture _oss_repo_root canonical
t_assert_eq "$TMP/canon" "$T_OUT" "canonical repo root resolves"
t_capture _oss_repo_root private_core
t_assert_rc 2 "an unconfigured repo key is rc 2, never a silent canonical default"
t_capture _oss_repo_root nonsense
t_assert_rc 2 "an unknown repo key is rc 2"

# --- #165, second half: a root field holding ${PLUGIN_DATA:...} must be refused
# as UNSUPPORTED, not as malformed. The token is documented workspace-init
# vocabulary ossify deliberately does not resolve (#152 wontfix), and the guard in
# manifest.sh was fixed first; this is the same class on the adjacent refusal,
# found by the pre-open sweep. Fixed here rather than deferred because worktree.sh
# STAYS deterministic — unlike interop.sh, which converts to prose.
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"\${PLUGIN_DATA:ossify}/notes"},"well_known_paths":{}}
EOF
PD_ROOT_ERR="$(_oss_repo_root canonical 2>&1 >/dev/null)"
t_capture _oss_repo_root canonical
t_assert_rc 2 "#165: a \${PLUGIN_DATA:...} repo root is still REFUSED (rc 2), it only reworded"
t_assert_contains "$PD_ROOT_ERR" "does not resolve" "#165: the root refusal says ossify does not resolve it"
t_assert_contains "$PD_ROOT_ERR" 'ai_workspace.root' "#165: the root refusal names a supported token instead"
# CONTROL — the new arm must not swallow the generic case, and must not claim
# PLUGIN_DATA for a token that is not it.
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"\${NOPE:x}/notes"},"well_known_paths":{}}
EOF
OTHER_ROOT_ERR="$(_oss_repo_root canonical 2>&1 >/dev/null)"
t_assert_contains "$OTHER_ROOT_ERR" "unresolved token" "#165 control: an unrelated token still gets the generic root refusal"
if [ "${OTHER_ROOT_ERR#*PLUGIN_DATA}" != "$OTHER_ROOT_ERR" ]; then R_PD=yes; else R_PD=no; fi
t_assert_eq "no" "$R_PD" "#165 control: the generic root refusal does NOT mention PLUGIN_DATA"
# restore the fixture manifest for everything below
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
t_capture _oss_repo_root canonical
t_assert_eq "$TMP/canon" "$T_OUT" "fixture restored: canonical resolves again for the rest of the file"

# #673 round 4 (U-15p): worktree_remove's branch now comes from STATE, never
# the live worktree HEAD, so the clean-removal fixtures below need records for
# the ids they clean up. Ids and slugs are fixed by this file; the records are
# read (branch only) by the cleanup calls that name OSS_STATE_FILE="$MSTATE".
MSTATE="$TMP/main-state.json"
cat > "$MSTATE" <<EOF
{"schema_version":"1.0","work_items":[
 {"id":"r0.s1.w1","status":"active","target_repo":"canonical","branch":"work/r0.s1.w1-add-ticket","worktree_path":"$TMP/canon/.worktrees/r0.s1.w1","base_sha":""},
 {"id":"r0.s1.w2","status":"active","target_repo":"canonical","branch":"work/r0.s1.w2-hook-check","worktree_path":"$TMP/canon/.worktrees/r0.s1.w2","base_sha":""},
 {"id":"r0.s1.w3","status":"active","target_repo":"canonical","branch":"work/r0.s1.w3-second-ticket","worktree_path":"$TMP/canon/.worktrees/r0.s1.w3","base_sha":""},
 {"id":"r0.s2.w1","status":"active","target_repo":"canonical","branch":"work/r0.s2.w1-dispatch-ticket","worktree_path":"$TMP/canon/.worktrees/r0.s2.w1","base_sha":""},
 {"id":"r0.s3.w1","status":"active","target_repo":"canonical","branch":"work/r0.s3.w1-hook-fails","worktree_path":"$TMP/canon/.worktrees/r0.s3.w1","base_sha":""},
 {"id":"r0.s3.w4","status":"active","target_repo":"canonical","branch":"work/r0.s3.w4-locked","worktree_path":"$TMP/canon/.worktrees/r0.s3.w4","base_sha":""},
 {"id":"r0.s3.w5","status":"active","target_repo":"canonical","branch":"work/r0.s3.w5-unlocked","worktree_path":"$TMP/canon/.worktrees/r0.s3.w5","base_sha":""}]}
EOF

# spawn
t_capture oss_worktree_add canonical r0.s1.w1 "add-ticket" "HEAD"
t_assert_rc 0 "worktree_add ok"
WT="$T_OUT"
[ -d "$WT" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: worktree dir not created"; }
t_assert_eq "$TMP/canon/.worktrees/r0.s1.w1" "$WT" "worktree path convention"
t_assert_eq "work/r0.s1.w1-add-ticket" "$(git -C "$WT" rev-parse --abbrev-ref HEAD)" "work-item branch checked out"

# The worktree root lives inside the repo, so spawning must not leave the repo
# reporting itself dirty. Assert the OUTCOME - a fully empty status - not merely
# that an ignore line was written: a line in the wrong file or with the wrong
# pattern still passes a grep and still leaves `?? .worktrees/` behind. The
# seeded .gitignore below is TRACKED, which is what makes this assertion
# meaningful: an implementation that appends to it instead of to
# .git/info/exclude leaves ` M .gitignore` and fails right here.
t_assert_eq "" "$(git -C "$TMP/canon" status --porcelain)" "spawning leaves the repo status completely clean"
t_assert_eq "node_modules/" "$(cat "$TMP/canon/.gitignore")" "spawning does not touch the .gitignore the PROJECT owns"
t_capture oss_worktree_add canonical r0.s1.w1 "add-ticket" "HEAD"
t_assert_rc 8 "spawning onto an existing worktree path is refused rc 8"
# Idempotent: repeated spawns must not append a duplicate ignore entry.
t_assert_eq "1" "$(grep -cxF '.worktrees/' "$TMP/canon/.git/info/exclude")" "the ignore entry is written exactly once"

# resolve + list
t_capture oss_worktree_resolve canonical r0.s1.w1
t_assert_eq "$WT" "$T_OUT" "worktree_resolve finds it"
t_capture oss_worktree_resolve canonical r0.s1.w9
t_assert_rc 1 "resolve on an unknown work item is rc 1"
# `worktree_list` was removed in v0.2.0: STATE holds each worktree_path (via
# work_item_exec) and spine-close removes from state, so filesystem enumeration
# answered nothing and could disagree. What still matters is that the directory
# is really there, which resolve already proves above.

# Named risk #7: oss_worktree_add's stdout IS its return value (the abs path).
# A chatty git hook (post-checkout fires on `worktree add`) must never corrupt
# it. Verified empirically: git routes a hook's own stdout onto git's stderr,
# so isolating git's stderr (no `2>&1` inside oss_worktree_add) is what keeps
# this clean - this asserts that behavior directly, on real stdout/stderr fds,
# not through t_capture (which deliberately merges both for test visibility).
mkdir -p "$TMP/canon/.git/hooks"
cat > "$TMP/canon/.git/hooks/post-checkout" <<'HOOK'
#!/bin/sh
echo "hook chatter on stdout"
HOOK
chmod +x "$TMP/canon/.git/hooks/post-checkout"
_hook_stderr="$TMP/hook-stderr.log"
_hook_out="$(oss_worktree_add canonical r0.s1.w2 "hook-check" "HEAD" 2>"$_hook_stderr")"
_hook_rc=$?
rm -f "$TMP/canon/.git/hooks/post-checkout"
if [ "$_hook_rc" -eq 0 ] && [ "$_hook_out" = "$TMP/canon/.worktrees/r0.s1.w2" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: a chatty post-checkout hook corrupted worktree_add's stdout (got '$_hook_out', rc=$_hook_rc)"
fi
OSS_STATE_FILE="$MSTATE" oss_worktree_remove canonical r0.s1.w2 >/dev/null 2>&1 || true

# D9: a DIRTY worktree must halt, never be force-discarded.
#
# Measured on git 2.52.0: `git worktree remove` (never called here with
# --force) ALSO refuses on any dirty state on its own, so if the explicit
# `[ -n "$dirty" ]` guard above is neutered, this rc and the file-survival
# assertion below stay green regardless - git's own default is the actual
# backstop against data loss. The one assertion that is genuinely sensitive to
# OUR guard is the next one: without it, the message reverts to git's generic
# "worktree remove failed" text and loses the word "uncommitted". That is real
# coverage (a neutered guard is observably worse - it no longer tells the user
# why, and its generic git fallback text mentions --force, which D9 exists to
# keep users away from) even though it is not a data-loss signal.
# The dirty refusal needs NO state record (round 4 keeps the dirty check above
# the state read), so this call deliberately runs WITHOUT one: a state-first
# order would surface here as a "cannot resolve the state file" refusal and
# this test would catch the reordering.
echo scratch > "$WT/uncommitted.txt"
t_capture oss_worktree_remove canonical r0.s1.w1
t_assert_rc 8 "removing a dirty worktree is refused rc 8"
t_assert_contains "$T_OUT" "uncommitted" "the refusal names the reason"
[ -f "$WT/uncommitted.txt" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: remove DISCARDED uncommitted work"; }

# D9, the half a "no new commits" case can't prove: `-d` and `-D` only differ
# on an UNMERGED branch. Spawn a second work item, commit inside its worktree
# (clean working tree, but the branch now carries a commit the spine lacks),
# then remove: the worktree comes out clean, so `git worktree remove` succeeds
# - but the branch must survive, because it is unmerged. `-d` refuses and
# halts; only a mutation to `-D` would silently destroy the commit. This is
# also the two-work-items-in-one-spine case from named risk #4.
t_capture oss_worktree_add canonical r0.s1.w3 "second-ticket" "HEAD"
t_assert_rc 0 "second worktree_add ok"
WT2="$T_OUT"
echo work > "$WT2/newfile.txt"
git -C "$WT2" add newfile.txt
git -C "$WT2" commit -qm "unmerged work" >/dev/null
OSS_STATE_FILE="$MSTATE" t_capture oss_worktree_remove canonical r0.s1.w3
t_assert_rc 8 "removing a worktree with an unmerged branch is refused rc 8"
t_assert_contains "$T_OUT" "not merged" "the refusal names the unmerged branch"
[ -d "$WT2" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: worktree dir survived an unmerged-branch removal"; } || T_PASS=$((T_PASS+1))
if git -C "$TMP/canon" show-ref --verify --quiet refs/heads/work/r0.s1.w3-second-ticket; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: unmerged work-item branch was destroyed"
fi

# clean removal takes the branch with it (the close ceremony asserts no work-* branch remains).
rm "$WT/uncommitted.txt"
OSS_STATE_FILE="$MSTATE" t_capture oss_worktree_remove canonical r0.s1.w1
t_assert_rc 0 "clean worktree removes"
[ -d "$WT" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: worktree dir survived removal"; } || T_PASS=$((T_PASS+1))
git -C "$TMP/canon" show-ref --verify --quiet refs/heads/work/r0.s1.w1-add-ticket \
  && { T_FAIL=$((T_FAIL+1)); echo "FAIL: work-item branch survived removal"; } || T_PASS=$((T_PASS+1))

# Dispatcher-path coverage. bin/oss runs `set -euo pipefail`; everything above
# this line only sourced the libs (no `set -e`), so a strict-mode-only fault
# in worktree.sh would be structurally invisible to it.
t_capture "$OSS" repo_root canonical
t_assert_eq "$TMP/canon" "$T_OUT" "dispatcher: repo_root canonical"
t_capture "$OSS" repo_root private_core
t_assert_rc 2 "dispatcher: unconfigured repo key is rc 2"
t_capture "$OSS" worktree_add canonical r0.s2.w1 "dispatch-ticket" "HEAD"
t_assert_rc 0 "dispatcher: worktree_add ok"
WT3="$T_OUT"
t_assert_eq "$TMP/canon/.worktrees/r0.s2.w1" "$WT3" "dispatcher: worktree path convention"
t_capture "$OSS" worktree_resolve canonical r0.s2.w1
t_assert_eq "$WT3" "$T_OUT" "dispatcher: worktree_resolve finds it"
t_capture "$OSS" worktree_list canonical
t_assert_rc 2 "dispatcher: the removed worktree_list verb is unknown (rc 2)"

# `oss release_dir` — the manifest-rooted ABSOLUTE docs path. The relative half
# (oss_id_release_dir) is unit-tested in test-id.sh; what matters here is that
# the dispatcher prefixes the ai_workspace root, because every prose consumer is
# a reader who is not standing in a known directory.
t_capture "$OSS" release_dir r2
t_assert_rc 0 "dispatcher: release_dir ok"
t_assert_eq "$TMP/ws/docs/specs/r2" "$T_OUT" "dispatcher: release_dir is ai_workspace-rooted, not canonical-rooted"
case "$T_OUT" in
  /*) T_PASS=$((T_PASS+1)) ;;
  *)  T_FAIL=$((T_FAIL+1)); echo "FAIL: release_dir returned a RELATIVE path ('$T_OUT') - the defect it exists to fix" ;;
esac
t_capture "$OSS" release_dir
t_assert_rc 2 "dispatcher: release_dir with no release id is the usage error, not an unbound-variable crash"
t_capture env OSS_STATE_FILE="$MSTATE" "$OSS" worktree_remove canonical r0.s2.w1
t_assert_rc 0 "dispatcher: clean worktree removes"
[ -d "$WT3" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: dispatcher worktree dir survived removal"; } || T_PASS=$((T_PASS+1))

# --- #120: the work-item id is a path component, so a traversal id must be
# refused before any path is built from it. The victim is a REAL, clean,
# registered worktree on a MERGED branch outside .worktrees - exactly what
# worktree_remove would otherwise remove and whose branch `-d` would delete.
# Measured before the fix: rc 0, victim worktree gone, branch gone.
git -C "$TMP/canon" worktree add -q -b victim-branch "$TMP/victim" HEAD
t_capture "$OSS" worktree_remove canonical ../../victim
t_assert_rc 2 "#120: dispatcher worktree_remove refuses a traversal id at rc 2"
t_assert_contains "$T_OUT" "not a work-item id" "#120: ...and says the id is not a work-item id"
[ -d "$TMP/victim" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: #120: the victim worktree outside .worktrees was removed"; }
git -C "$TMP/canon" show-ref --verify --quiet refs/heads/victim-branch \
  && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: #120: the victim's branch was deleted"; }
# ...and the same traversal carried on a SECOND LINE behind a valid first line
# (PR #601 review): the grammar check matched per line until it matched whole.
t_capture "$OSS" worktree_remove canonical $'r0.s1.w1\n/../../../victim'
t_assert_rc 2 "#120: a multi-line id with a valid first line is refused at rc 2"
[ -d "$TMP/victim" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: #120: a multi-line id reached the victim worktree"; }
t_capture oss_worktree_resolve canonical ../../victim
t_assert_rc 2 "#120: worktree_resolve refuses a traversal id at rc 2 (not rc 0 with the victim's path)"
# worktree_add was refused before only by accident - git rejects `work/../..`
# as a branch name, at rc 8, after mkdir and the exclude write. rc 2 is the
# check, and it answers before anything touches the repo.
t_capture oss_worktree_add canonical ../../escape slug HEAD
t_assert_rc 2 "#120: worktree_add refuses a traversal id at rc 2, before git is asked"
t_capture oss_worktree_add canonical r0.s3 slug HEAD
t_assert_rc 2 "#120: a SPINE id is not a work-item id either"
# ADJACENT CONTROL: a valid id that names no worktree still answers rc 1 (not
# found) - the check refuses the grammar, not the lookup.
t_capture oss_worktree_resolve canonical r0.s3.w9
t_assert_rc 1 "#120 control: a valid but unknown work-item id is still rc 1, not rc 2"
git -C "$TMP/canon" worktree remove "$TMP/victim" >/dev/null 2>&1
git -C "$TMP/canon" branch -D victim-branch >/dev/null 2>&1

# --- #122: `git worktree add` fails AFTER creating the worktree and the branch
# when a post-checkout hook exits nonzero. Before the fix both were left behind,
# and the already-exists guard then refused every retry at rc 8, forever.
printf '#!/bin/sh\nexit 1\n' > "$TMP/canon/.git/hooks/post-checkout"
chmod +x "$TMP/canon/.git/hooks/post-checkout"
t_capture "$OSS" worktree_add canonical r0.s3.w1 "hook-fails" HEAD
t_assert_rc 8 "#122: a failing post-checkout hook still fails the add at rc 8"
t_assert_contains "$T_OUT" "rolled back" "#122: ...and says the partial add was rolled back"
[ -e "$TMP/canon/.worktrees/r0.s3.w1" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: #122: the partial worktree was left behind"; } || T_PASS=$((T_PASS+1))
git -C "$TMP/canon" show-ref --verify --quiet refs/heads/work/r0.s3.w1-hook-fails \
  && { T_FAIL=$((T_FAIL+1)); echo "FAIL: #122: the partial branch was left behind"; } || T_PASS=$((T_PASS+1))
rm -f "$TMP/canon/.git/hooks/post-checkout"
t_capture "$OSS" worktree_add canonical r0.s3.w1 "hook-fails" HEAD
t_assert_rc 0 "#122: once the cause is fixed, the retry succeeds"
t_assert_eq "$TMP/canon/.worktrees/r0.s3.w1" "$T_OUT" "#122: ...at the conventional path"
OSS_STATE_FILE="$MSTATE" oss_worktree_remove canonical r0.s3.w1 >/dev/null 2>&1

# #122 CONTROL, the before-state half: a branch that EXISTED before the call is
# never the rollback's to delete. git refuses `-b` for an existing branch before
# creating anything, and the pre-existing branch must survive that failure.
git -C "$TMP/canon" branch work/r0.s3.w2-taken HEAD
t_capture "$OSS" worktree_add canonical r0.s3.w2 "taken" HEAD
t_assert_rc 8 "#122 control: an add onto an existing branch fails at rc 8"
case "$T_OUT" in *"rolled back"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: #122 control: claimed a rollback when git created nothing";; *) T_PASS=$((T_PASS+1));; esac
git -C "$TMP/canon" show-ref --verify --quiet refs/heads/work/r0.s3.w2-taken \
  && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: #122 control: a branch that predates the call was deleted by the rollback"; }
git -C "$TMP/canon" branch -D work/r0.s3.w2-taken >/dev/null 2>&1

# #122 CONTROL, the tip half: a hook that COMMITS before failing moves the new
# branch off the base. That commit exists nowhere else, so the branch is kept and
# named - never force-deleted - while the worktree (created by this call) goes.
cat > "$TMP/canon/.git/hooks/post-checkout" <<'HOOK'
#!/bin/sh
git -c user.email=h@h -c user.name=h commit -q --allow-empty -m "hook commit" >/dev/null 2>&1
exit 1
HOOK
chmod +x "$TMP/canon/.git/hooks/post-checkout"
t_capture "$OSS" worktree_add canonical r0.s3.w3 "hook-commits" HEAD
t_assert_rc 8 "#122 control: the committing hook fails the add at rc 8"
t_assert_contains "$T_OUT" "no longer points at the base" "#122 control: ...and names the branch it would not delete"
git -C "$TMP/canon" show-ref --verify --quiet refs/heads/work/r0.s3.w3-hook-commits \
  && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: #122 control: a branch carrying a commit was force-deleted"; }
[ -e "$TMP/canon/.worktrees/r0.s3.w3" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: #122 control: the worktree this call created was left behind"; } || T_PASS=$((T_PASS+1))
rm -f "$TMP/canon/.git/hooks/post-checkout"
git -C "$TMP/canon" branch -D work/r0.s3.w3-hook-commits >/dev/null 2>&1

# #122, the ownership half (PR #601 review): the rollback may only remove what ITS
# call created, which holds only if no second add for the same id runs between
# the existence checks and the rollback. One add per id at a time: with that
# id's lock held, an add refuses at rc 8 and touches nothing - a loser of two
# concurrent adds never reaches a rollback that could remove the winner's tree.
WTLOCK="$TMP/canon/.git/ossify-worktree-add.r0.s3.w4.lock"
mkdir "$WTLOCK"
t_capture "$OSS" worktree_add canonical r0.s3.w4 "locked" HEAD
t_assert_rc 8 "#122: an add for an id whose add lock is held refuses at rc 8"
t_assert_contains "$T_OUT" "another worktree_add for r0.s3.w4" "#122: ...and says another add holds it"
[ -e "$TMP/canon/.worktrees/r0.s3.w4" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: #122: an add created a worktree while another add held the lock"; } || T_PASS=$((T_PASS+1))
# ADJACENT CONTROL: another id is not blocked by that lock.
t_capture "$OSS" worktree_add canonical r0.s3.w5 "unlocked" HEAD
t_assert_rc 0 "#122 control: an add for a DIFFERENT id proceeds while that lock is held"
OSS_STATE_FILE="$MSTATE" oss_worktree_remove canonical r0.s3.w5 >/dev/null 2>&1
rmdir "$WTLOCK"
t_capture "$OSS" worktree_add canonical r0.s3.w4 "locked" HEAD
t_assert_rc 0 "#122 control: once released, the add proceeds"
[ -d "$WTLOCK" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: #122: a finished add left its lock behind"; } || T_PASS=$((T_PASS+1))
OSS_STATE_FILE="$MSTATE" oss_worktree_remove canonical r0.s3.w4 >/dev/null 2>&1

# The repair commands the rollback prints are for copying, so every value in
# them is shell-quoted (PR #601 review): a path with an apostrophe must come out
# as one quoted word, not break the quoting. A plain directory is not a
# worktree, so `git worktree remove` refuses it and the repair line is printed.
QDIR="$TMP/it's here/r0.s3.w6"; mkdir -p "$QDIR"
t_capture _oss_worktree_add_rollback "$TMP/canon" "$QDIR" "work/r0.s3.w6-x" 1 ""
t_assert_rc 8 "a rollback that cannot undo a path says so at rc 8"
t_assert_contains "$T_OUT" "worktree remove --force $(printf '%q' "$QDIR")" "...and the repair command quotes the path as one shell word"
[ -d "$QDIR" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: the rollback removed a directory that is not a worktree"; }
rm -rf "$TMP/it's here"

# ---------------------------------------------------------------------------
# The spine-branch lifecycle the execution lane owns: cut AND CHECK OUT the
# spine integration branch, spawn each work item off it, merge each back into
# it. `git branch` without the checkout leaves canonical on its previous
# branch, and then EVERY consequence is rc 0 - the work-item merge lands on the
# wrong branch, spine close's merge is "Already up to date", and the cumulative
# demo measures a tree assembled by accident. So every assertion below is on a
# concrete sha or a reachability fact; the rc is never the evidence.
# ---------------------------------------------------------------------------
BASE_BRANCH="$(git -C "$TMP/canon" rev-parse --abbrev-ref HEAD)"
SPINE_BRANCH="$(oss_id_branch_name r0.s3 "round-lane")"
t_assert_eq "spine/r0.s3-round-lane" "$SPINE_BRANCH" "the spine branch name comes from the id grammar"
git -C "$TMP/canon" checkout -q -b "$SPINE_BRANCH"

# A commit that exists ONLY on the spine branch, made BEFORE any worktree is
# spawned. Without it the spine tip and the base-branch tip are the same commit,
# and every reachability assertion below is vacuously true whichever branch the
# worktree was actually cut from - the fixture would never trip the precondition
# the guard exists for.
echo spine-only > "$TMP/canon/spine.txt"
git -C "$TMP/canon" add spine.txt
git -C "$TMP/canon" commit -qm "spine-only commit"
SPINE_TIP="$(git -C "$TMP/canon" rev-parse HEAD)"
BASE_TIP="$(git -C "$TMP/canon" rev-parse "$BASE_BRANCH")"
if [ "$SPINE_TIP" != "$BASE_TIP" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: fixture is vacuous - the spine tip and $BASE_BRANCH are the same commit"
fi

t_capture oss_worktree_add canonical r0.s3.w1 "first-item" "$SPINE_BRANCH"
t_assert_rc 0 "round-1 item 1 spawns off the spine branch"
WA="$T_OUT"
t_capture "$OSS" worktree_add canonical r0.s3.w2 "second-item" "$SPINE_BRANCH"
t_assert_rc 0 "dispatcher: round-1 item 2 spawns off the spine branch (non-HEAD base under set -euo pipefail)"
WB="$T_OUT"

# Two work items in ONE spine: distinct branches, distinct worktrees.
t_assert_eq "work/r0.s3.w1-first-item" "$(git -C "$WA" rev-parse --abbrev-ref HEAD)" "work item 1 gets its own branch"
t_assert_eq "work/r0.s3.w2-second-item" "$(git -C "$WB" rev-parse --abbrev-ref HEAD)" "work item 2 gets its own branch"
if [ "$WA" != "$WB" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: two work items in one spine share a worktree path"
fi

# Spawned off the SPINE branch, not off the base branch - asserted on the sha
# recorded before the spawn, not re-derived from what the spawn wrote.
t_assert_eq "$SPINE_TIP" "$(git -C "$WA" rev-parse HEAD)" "work item 1's worktree starts at the spine tip, not at $BASE_BRANCH"
t_assert_eq "$SPINE_TIP" "$(git -C "$WB" rev-parse HEAD)" "work item 2's worktree starts at the spine tip too"
t_assert_eq "$SPINE_TIP" "$(git -C "$TMP/canon" merge-base "$SPINE_BRANCH" work/r0.s3.w1-first-item)" "the spine branch is the work-item branch's merge base"

# Unit-level pin on the 4th argument. NOT a lifecycle path - the lane never
# spawns a work item off the base branch. It exists because during the real
# lifecycle canonical's HEAD *is* the spine branch, so an implementation that
# ignored `base` and used HEAD would satisfy every assertion above.
t_capture oss_worktree_add canonical r0.s3.w9 "base-ref-pin" "$BASE_BRANCH"
t_assert_rc 0 "worktree_add accepts an explicit non-HEAD base"
WP="$T_OUT"
t_assert_eq "$BASE_TIP" "$(git -C "$WP" rev-parse HEAD)" "the base-ref argument decides the start point, not canonical's HEAD"

# The merge back, with canonical still parked on the spine branch.
echo w1 > "$WA/w1.txt"
git -C "$WA" add w1.txt
git -C "$WA" commit -qm "work item 1"
W1_SHA="$(git -C "$WA" rev-parse HEAD)"
t_assert_eq "$SPINE_BRANCH" "$(git -C "$TMP/canon" rev-parse --abbrev-ref HEAD)" "canonical is still parked on the spine branch when the merge runs"
t_capture git -C "$TMP/canon" merge --no-ff -m "merge r0.s3.w1" work/r0.s3.w1-first-item
t_assert_rc 0 "the work-item branch merges into the checked-out spine branch"
if git -C "$TMP/canon" merge-base --is-ancestor "$W1_SHA" "$SPINE_BRANCH"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the work-item commit is NOT reachable from the spine branch after the merge"
fi
t_assert_eq "w1" "$(cat "$TMP/canon/w1.txt" 2>/dev/null)" "the merged work is present in canonical's tree on the spine branch"

# NEGATIVE CONTROL - this is what the checkout buys, stated as an outcome.
# Park canonical back on the base branch (the pre-correction state, where
# nothing ever checked the spine branch out) and merge the second work item.
# The merge still succeeds; the spine branch still never receives the work.
git -C "$TMP/canon" checkout -q "$BASE_BRANCH"
echo w2 > "$WB/w2.txt"
git -C "$WB" add w2.txt
git -C "$WB" commit -qm "work item 2"
W2_SHA="$(git -C "$WB" rev-parse HEAD)"
t_capture git -C "$TMP/canon" merge --no-ff -m "merge r0.s3.w2" work/r0.s3.w2-second-item
t_assert_rc 0 "merging while parked on $BASE_BRANCH ALSO returns rc 0 - which is why an rc-0 assertion proves nothing"
if git -C "$TMP/canon" merge-base --is-ancestor "$W2_SHA" "$SPINE_BRANCH"; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: negative control is vacuous - the commit reached the spine branch without the checkout"
else
  T_PASS=$((T_PASS+1))
fi
if git -C "$TMP/canon" merge-base --is-ancestor "$W2_SHA" "$BASE_BRANCH"; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: negative control did not land the commit on $BASE_BRANCH either"
fi

# ---------------------------------------------------------------------------
# `oss worktree_orphans` (v0.3) — the repo-vs-state drift `doctor` reports.
#
# Its own workspace, canonical repo and state file, deliberately reusing NOTHING
# above. The fixtures above spawn and remove worktrees in an order this check is
# sensitive to, and "a mutation disarms one fixture by changing another that set
# its precondition" is a vacuity mode this repo has already been bitten by.
# Everything below stands alone and is readable without scrolling up.
# ---------------------------------------------------------------------------
ORPH="$(mktemp -d)"
mkdir -p "$ORPH/ws/.workspace" "$ORPH/canon"
git -C "$ORPH/canon" init -q
git -C "$ORPH/canon" config user.email t@t; git -C "$ORPH/canon" config user.name t
echo seed > "$ORPH/canon/f.txt"
git -C "$ORPH/canon" add .; git -C "$ORPH/canon" commit -qm seed
# The routed state path is set EXPLICITLY to the fixture's state file, because
# `oss doctor`'s worktree check now refuses to compare a repo found via $PWD's
# manifest against a state file that manifest does not route to. Without this
# key the fixture would exercise only the skip arm, and the warn/ok arms would
# silently stop being covered while still reading as covered.
cat > "$ORPH/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$ORPH/ws"},"canonical":{"root":"$ORPH/canon"},"well_known_paths":{"project_state":"$ORPH/state.json"}}
EOF
cd "$ORPH/ws"
OS="$ORPH/state.json"
oss_state_init "$OS" orphan-demo >/dev/null
OREL="$(oss_entity_add_release "$OS" "orphan-rel" "a goal")"
OSPN="$(oss_entity_add_spine "$OS" "$OREL" "orphan-spine" flesh canonical)"
OWI="$(oss_entity_add_work_item "$OS" "$OSPN" "orphan work item" canonical)"

# (1) No `.worktrees` directory at all is not a finding. The early return that
# makes this true also keeps the unmatched-glob path off the common case.
t_capture oss_worktree_orphans canonical "$OS"
t_assert_rc 0 "orphans: a canonical with no .worktrees dir is rc 0"
t_assert_eq "" "$T_OUT" "orphans: no .worktrees dir reports nothing"

# (2) THE ARM THAT MATTERS. `worktree_add` names the directory for its work item
# but writes NOTHING to state — `worktree_path` appears only once
# `work_item_exec` journals it. So a claim test matching on the path ALONE
# reports a correctly-spawned worktree as an orphan, i.e. it is loudest exactly
# when the project is behaving. Drop the id arm from the jq and this assertion
# is the one that goes red.
OWT="$(oss_worktree_add canonical "$OWI" "orphan-slug" HEAD)"
t_assert_eq "$ORPH/canon/.worktrees/$OWI" "$OWT" "orphans: fixture spawned the worktree at the id-named path"
t_capture oss_worktree_orphans canonical "$OS"
t_assert_eq "" "$T_OUT" "orphans: a spawned-but-not-yet-journaled worktree is CLAIMED by its work item's id"

# (3) A directory no work item claims by either arm — the actual finding.
mkdir -p "$ORPH/canon/.worktrees/r9.s9.w9"
t_capture oss_worktree_orphans canonical "$OS"
t_assert_rc 0 "orphans: finding one is still rc 0 — the finding is the OUTPUT, never the rc"
t_assert_eq "$ORPH/canon/.worktrees/r9.s9.w9" "$T_OUT" "orphans: the unclaimed dir is reported, and it is the ONLY line"

# (4) The other arm: a directory whose basename is NOT a work-item id, claimed
# because a work item's journaled `worktree_path` IS it. Drop the path arm and
# this goes red while (2) stays green — the two arms cover disjoint failures.
mkdir -p "$ORPH/canon/.worktrees/hand-named-dir"
oss_entity_set_work_item_exec "$OS" "$OWI" "work/$OWI-orphan-slug" \
  "$ORPH/canon/.worktrees/hand-named-dir" "$(git -C "$ORPH/canon" rev-parse HEAD)" >/dev/null
t_capture oss_worktree_orphans canonical "$OS"
t_assert_eq "$ORPH/canon/.worktrees/r9.s9.w9" "$T_OUT" "orphans: a dir claimed by a journaled worktree_path is not reported"

# (5) An unconfigured repo key must not degrade to "canonical, probably".
t_capture oss_worktree_orphans private_core "$OS"
t_assert_rc 2 "orphans: an unconfigured repo key is rc 2, never a silent canonical fallback"

# (6) Dispatcher path — bin/oss runs `set -euo pipefail` and everything above
# only sourced the lib. The unmatched-glob guard and the `jq -e || printf` pair
# are both shapes that behave differently under strict mode.
t_capture "$OSS" worktree_orphans canonical "$OS"
t_assert_rc 0 "dispatcher: worktree_orphans under strict mode is rc 0"
t_assert_eq "$ORPH/canon/.worktrees/r9.s9.w9" "$T_OUT" "dispatcher: worktree_orphans reports the same single orphan"

# (7) was `oss doctor`'s worktree line, both arms, through the real binary. The
# verb no longer emits it (PR #184 slimmed doctor to its gate), so those
# assertions are gone; the selector itself is covered by (2)-(6) above and by the
# dispatcher run immediately preceding. The teardown stays because later sections
# assume a clean canonical .worktrees/.
rm -rf "$ORPH/canon/.worktrees/r9.s9.w9"
# This fixture's manifest configures `canonical` and `ai_workspace` and NOT
# `private_core`. An unconfigured key must still cost a LINE. Omitting it is the
# same failure as #156 one level down: a read-out that says nothing about a repo
# reads as a repo with nothing wrong, and the operator cannot tell "looked, and
# it is clean" from "never looked".

# (8) A state file this directory's manifest does NOT route to must not be
# compared against this directory's repo. Every other doctor check reads only
# the state file it was handed, so this one — the only repo-reading check — is
# the only one that can silently cross two projects: $PWD finds project A's
# canonical root while the state argument describes project B's work items, and
# A's directories get judged against B's records on no evidence at all.
# (8a) The SAME file named a different way must still be recognised as the same
# project. A raw string compare drops orphan detection on the supported relative
# spelling — a silent false negative on an otherwise healthy run, which is the
# failure this whole function exists to avoid.
# Stay inside the workspace so the manifest is still discoverable on the walk-up
# — `../state.json` from here is the SAME file the manifest routes to, spelled
# differently, which is exactly the case a string compare gets wrong.
mkdir -p "$ORPH/canon/.worktrees/r9.s9.w9"
rm -rf "$ORPH/canon/.worktrees/r9.s9.w9"

OTHER="$ORPH/other-state.json"
oss_state_init "$OTHER" other-project >/dev/null

# (9) target_repo scoping. A work item belonging to `private_core` must NOT
# claim a directory under the CANONICAL root just because the basename matches
# its id — that suppresses precisely the wrong-repository directory the repo-key
# design exists to expose, and in the worst case leaves private work sitting
# under the public root.
PWI="$(oss_entity_add_work_item "$OS" "$OSPN" "private work item" private_core)"
mkdir -p "$ORPH/canon/.worktrees/$PWI"
t_capture oss_worktree_orphans canonical "$OS"
t_assert_eq "$ORPH/canon/.worktrees/$PWI" "$T_OUT" \
  "orphans: a private_core work item does NOT claim a canonical-rooted directory of the same id"
rm -rf "$ORPH/canon/.worktrees/$PWI"

# (10) A state file that does not parse is a FAILURE, not zero matches. Before
# this guard, jq's parse error (rc 5) was indistinguishable from a false
# predicate, so every directory was reported as orphaned — a deletion-flavoured
# finding stacked on top of the corrupt state that is the real problem.
printf '{not valid json' > "$ORPH/broken-state.json"
t_capture oss_worktree_orphans canonical "$ORPH/broken-state.json"
t_assert_rc 1 "orphans: an unparseable state file is rc 1, not a silent all-orphaned report"
t_assert_contains "$T_OUT" "not valid JSON" "orphans: the parse failure names itself"
case "$T_OUT" in
  *".worktrees/"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: orphans listed directories from an unparseable state" ;;
  *) T_PASS=$((T_PASS+1)) ;;
esac

# (10b) A state that PARSES but whose .work_items is not an array. jq errors
# while iterating a string, and the `|| printf` arm cannot tell that error from
# a false predicate — so every directory reported as orphaned while the selector
# still exited 0. `// []` does not cover this: a string is truthy, so the
# alternative never fires. The parse guard above accepts this file happily.
printf '{"work_items":"oops"}' > "$ORPH/shape-state.json"
t_capture oss_worktree_orphans canonical "$ORPH/shape-state.json"
t_assert_rc 1 "orphans: a non-array .work_items is rc 1, not an all-orphaned report"
t_assert_contains "$T_OUT" "not an array" "orphans: the shape failure is distinguished from the parse failure"
case "$T_OUT" in
  *".worktrees/"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: orphans listed directories from a non-array .work_items" ;;
  *) T_PASS=$((T_PASS+1)) ;;
esac

# (10c) The THIRD shape of the same class, and the one the single-jq rewrite
# exists to end: `.work_items` IS an array but holds a non-object record.
# Property access on a string raised inside the old per-directory predicate, and
# the `|| printf` arm read that error as "unclaimed" — so every directory came
# back as a deletion-oriented orphan at rc 0. A junk record is REFUSED here
# rather than skipped: "some records are garbage" is not evidence that a
# directory is unclaimed.
printf '{"work_items":[{"id":"r0.s1.w1","target_repo":"canonical"},"junk"]}' > "$ORPH/elem-state.json"
t_capture oss_worktree_orphans canonical "$ORPH/elem-state.json"
t_assert_rc 1 "orphans: a non-object record inside .work_items is rc 1"
t_assert_contains "$T_OUT" "not an object" "orphans: the element-shape failure names itself"
case "$T_OUT" in
  *".worktrees/"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: orphans listed directories from a junk work-item record" ;;
  *) T_PASS=$((T_PASS+1)) ;;
esac

# (10d) The FOURTH shape of the same class, and the one (10c)'s guard does not
# reach: the record IS an object, but a claim field is the wrong TYPE. #155.
#
# This shape is quieter than (10a)-(10c) and that is the whole point. Those
# three ERROR — a parse failure, a string iterated as an array, a property
# access on a string — so the single-jq rewrite's "jq's exit status IS the error
# signal" catches them for free. `.id` as an ARRAY raises nothing: it simply
# compares unequal to every basename, so the record silently claims nothing and
# EVERY directory under `.worktrees` comes back as a deletion-flavoured orphan
# at rc 0. A guard that only asks `type == "object"` cannot see it.
#
# Refused rather than skipped, matching (10c): a record whose claim fields are
# unreadable is not evidence that a directory is unclaimed.
printf '{"work_items":[{"id":[],"target_repo":"canonical"}]}' > "$ORPH/type-state.json"
t_capture oss_worktree_orphans canonical "$ORPH/type-state.json"
t_assert_rc 1 "orphans: a work-item record whose id is not a string is rc 1"
t_assert_contains "$T_OUT" "not a string" "orphans: the field-TYPE failure names itself, distinctly from the element-shape one"
case "$T_OUT" in
  *".worktrees/"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: orphans listed directories from a record with a wrong-typed claim field" ;;
  *) T_PASS=$((T_PASS+1)) ;;
esac
# The guard is scoped to WRONG TYPES, not to absence. `worktree_path` is absent
# until `work_item_exec` journals it, and `target_repo` is absent on items
# predating the field — both are read through `// ""` / `// "canonical"` and
# must keep working, or this fix turns into the over-correction #162 is about.
# Asserted with a REAL claim so the rc-0 below cannot come from an empty set:
# `r9.s9.w9` is claimed by id, and the other two dirs stay reported.
printf '{"work_items":[{"id":"r9.s9.w9"}]}' > "$ORPH/sparse-state.json"
t_capture oss_worktree_orphans canonical "$ORPH/sparse-state.json"
t_assert_rc 0 "orphans: a record with absent worktree_path/target_repo is still VALID — absence is not a wrong type"
case "$T_OUT" in
  *"/.worktrees/r9.s9.w9"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: a record claiming r9.s9.w9 by id did not claim it" ;;
  *) T_PASS=$((T_PASS+1)) ;;
esac
t_assert_contains "$T_OUT" "hand-named-dir" "orphans: and the genuinely unclaimed dirs are still reported from that sparse record"

# (11) A state that PARSES but has drifted from its base and journal must not be
# used for a repo comparison either. The parse guard inside worktree_orphans
# accepts it — valid JSON — but its live `.work_items` is exactly what replay is
# telling you not to trust, so a work item deleted by a hand edit turns its
# surviving directory into a deletion-flavoured "orphan" warning for a worktree
# `oss state_restore` is about to reclaim.
mkdir -p "$ORPH/canon/.worktrees/$OWI"
jq 'del(.work_items[0])' "$OS" > "$OS.x" && mv "$OS.x" "$OS"
t_capture "$OSS" doctor "$OS"
t_assert_rc 1 "doctor: a drifted live state still fails replay"

cd /; rm -rf "$ORPH"

# ---------------------------------------------------------------------------
# (12) #156 — doctor inspects EVERY configured repo, not only `canonical`.
#
# Every fixture above configures one repo, so a canonical-hardcoded call site
# passed all of them. The bug only becomes visible once `private_core` is
# configured AND holds the orphan: doctor printed "none orphaned" having never
# looked at it. That is not a missing feature, it is a FALSE ASSURANCE in the
# one surface the public/private boundary exists to protect — private work
# accumulating under a root no ceremony and no check ever reads.
#
# The loop is driven off every repo the manifest declares rather than a
# hardcoded pair, and an unconfigured key costs a `skip:` line (asserted at (7)) rather
# than silence — so "not configured" and "configured and clean" stay
# distinguishable in the read-out.
# ---------------------------------------------------------------------------
PRIV="$(mktemp -d)"
mkdir -p "$PRIV/ws/.workspace" "$PRIV/canon" "$PRIV/priv"
git -C "$PRIV/canon" init -q
git -C "$PRIV/canon" config user.email t@t; git -C "$PRIV/canon" config user.name t
echo seed > "$PRIV/canon/f.txt"
git -C "$PRIV/canon" add .; git -C "$PRIV/canon" commit -qm seed
cat > "$PRIV/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$PRIV/ws"},"canonical":{"root":"$PRIV/canon"},"private_core":{"root":"$PRIV/priv"},"well_known_paths":{"project_state":"$PRIV/state.json"}}
EOF
cd "$PRIV/ws"
PS="$PRIV/state.json"
oss_state_init "$PS" private-demo >/dev/null
PREL="$(oss_entity_add_release "$PS" "priv-rel" "a goal")"
PSPN="$(oss_entity_add_spine "$PS" "$PREL" "priv-spine" flesh canonical)"
oss_entity_add_work_item "$PS" "$PSPN" "canonical work item" canonical >/dev/null

# THE ARM THAT MATTERS. Canonical is clean; the orphan is under the PRIVATE
# root. Before the fix this run printed a clean worktree read-out and said
# nothing whatsoever about private_core.
mkdir -p "$PRIV/priv/.worktrees/r9.s9.w9"
# doctor used to PRINT a remedy here, pinned to both the repo key and the
# inspected state, and this block ran it verbatim. The verb prints no remedy now,
# so what survives is the property that remedy existed to guarantee, asserted
# against the selector directly below: an explicit state argument beats an
# exported $OSS_STATE_FILE. The pinning rule moved to prose - doctor/SKILL.md §4
# and state-inspection.md §4 both say to pass key AND state on every call.
# (Codex P2, PR #160 round 2, for the original.)
# RUN IT rather than matching its spelling. The line claims the command names
# Executed with $OSS_STATE_FILE pointing at a path that does not exist — the
# exact condition the finding describes. An UNPINNED command resolves to that
# override and dies rc 1; a pinned one ignores it, because an explicit argument
# beats the variable (`manifest.sh:181-190`). So this fails loudly if the state
# argument is ever dropped again.
# The property is the VERB's: an EXPLICIT state argument must beat an exported
# $OSS_STATE_FILE. This used to run doctor's printed remedy verbatim; doctor
# prints no remedy now, so it exercises the same precedence directly. An
# unpinned call resolves to the bogus override and dies rc 1.
REMEDY_OUT="$( export OSS_STATE_FILE="$PRIV/no-such-state.json"; "$OSS" worktree_orphans private_core "$PS" 2>/dev/null )"; REMEDY_RC=$?
t_assert_eq "0" "$REMEDY_RC" "orphans: an explicit state argument beats a stale \$OSS_STATE_FILE"
t_assert_eq "$PRIV/priv/.worktrees/r9.s9.w9" "$REMEDY_OUT" "orphans: ...and it names the orphan from the state it was GIVEN"

# The guard that sat here read doctor's `warn: worktrees(canonical)` line out of
# $T_OUT; with doctor no longer emitting it the FAIL arm was unreachable and it
# incremented T_PASS while checking nothing. DELETED rather than re-pointed at
# the verb: canonical's .worktrees/ cannot contain a directory under the private
# root, so a verb-level version would pass structurally and be a weak duplicate.
# Cross-repo attribution is genuinely covered by (9), which plants a same-id
# directory under the CANONICAL root and asserts a private_core item does not
# claim it.
rm -rf "$PRIV/priv/.worktrees/r9.s9.w9"

# --- #272/#310 Task 4, Finding 3: the FAIL-SAFE half of the sole-repo default
# rule. A work-item record that predates the `target_repo` field (the legacy
# jq fallback in oss_worktree_orphans) is genuinely AMBIGUOUS once N>1 repos
# are declared - there is no safe repo to attribute it to, so the whole call
# must refuse rather than guess which repo it belongs to. The SUCCESS half (a
# legacy record resolves fine when exactly one repo is declared) is already
# pinned above at "orphans: a record with absent worktree_path/target_repo is
# still VALID"; this is its N>1 counterpart - nothing else in the suite
# exercises it, so the refusal half of "with N>1 an unset target must refuse"
# was previously unasserted.
mkdir -p "$PRIV/canon/.worktrees/legacy-candidate"
printf '{"work_items":[{"id":"r9.s9.w9"}]}' > "$PRIV/legacy-state.json"
t_capture oss_worktree_orphans canonical "$PRIV/legacy-state.json"
t_assert_rc 2 "orphans: a target_repo-less (legacy) work item under N>1 declared repos refuses - no safe default to fall back on"
# The refusal used to reuse `_oss_default_repo_key`'s "no repo key given"
# wording verbatim - on a call that gave one. The rc and the fail-safe rule are
# unchanged; only the diagnosis is now the legacy records rather than the
# caller's argument.
t_assert_contains "$T_OUT" "carry no target_repo" "orphans: the refusal names the legacy records as the ambiguity"
rm -rf "$PRIV/canon/.worktrees" "$PRIV/legacy-state.json"

# (12c) A CONFIGURED ROOT THAT DOES NOT EXIST HAS NOT BEEN INSPECTED.
#
# `_oss_repo_root` validates the manifest value — non-empty, token-free,
# absolute — but never that the directory is THERE. So an unmounted volume or a
# moved repo resolved fine, `[ -d "$root/.worktrees" ]` was false, and the
# "nothing spawned yet is not a finding" early return exited 0 with no output.
# doctor then printed `ok: worktrees(private_core) - none orphaned` about a
# repository that does not exist on this machine — #156's own false assurance,
# one level in, and reachable on every repo key at once. (Codex P1, PR #160.)
#
# rc 2, not rc 1: this is the same "cannot use this repo" class as an
# unconfigured key, and doctor's existing skip arm already handles it — which is
# why the fix lives in the selector and doctor needs no new branch.
rm -rf "$PRIV/priv"
t_capture oss_worktree_orphans private_core "$PS"
t_assert_rc 2 "orphans: a configured repo whose root does not exist is rc 2, not a silent clean"
t_assert_contains "$T_OUT" "does not exist" "orphans: the missing root names itself"
# The skip names BOTH cause families. `oss_worktree_orphans` returns nonzero for
# repo-side reasons (unconfigured / absent / unreadable) AND for state-side ones
# (unparseable JSON, a non-array `.work_items`, a non-object record), and one
# collapsed line stands for all of them. A message listing only the repo-side
# causes sends an operator to debug a healthy manifest while the corrupt state
# that actually stopped the check goes unnamed. (Codex P2, PR #160 round 3 —
# and a regression introduced by round 2's own message polish.)
# (The "absent root is not clean" guard that sat here read doctor's line out of
# $T_OUT and is unreachable now that doctor emits none. The property it protected
# is asserted directly above: rc 2 and "does not exist" from the verb itself.)
# The other repos are unaffected — one missing root must not degrade the keys
# that ARE inspectable, or a single unmounted volume blinds the whole surface.

# (12d) A ROOT THAT EXISTS BUT CANNOT BE TRAVERSED IS ALSO NOT INSPECTED.
#
# The (12c) guard tests `-d "$root"`, which is TRUE for a directory the caller
# has no execute permission on — while `[ -d "$root/.worktrees" ]` is FALSE,
# because the stat cannot be performed. So a private checkout mounted with
# restrictive permissions walked straight past the new guard into the "nothing
# spawned yet" arm and reported clean. Measured: with `chmod 000` on the root,
# `[ -d root ]` is true, `[ -x root ]` is false, `[ -d root/.worktrees ]` is
# false while the directory demonstrably exists. Same false-clean class as
# (12c), reached by permissions rather than absence. (Codex, PR #160 round 2 —
# filed P2, treated as P1 because a false clean here is this PR's subject.)
mkdir -p "$PRIV/priv/.worktrees/r9.s9.w9"
chmod 000 "$PRIV/priv"
# NOT ASSUMED TO BITE. Running as root ignores the mode bits, and an assertion
# that cannot fail is worse than an absent one — it reads as coverage. Probe
# first and say so out loud when the arm is not exercised.
if [ -d "$PRIV/priv/.worktrees" ]; then
  echo "NOTE: chmod 000 did not restrict this user (uid $(id -u)); traversability arm NOT exercised"
else
  t_capture oss_worktree_orphans private_core "$PS"
  t_assert_rc 2 "orphans: a root that exists but cannot be traversed is rc 2, not a silent clean"
  # "cannot be traversed", not "cannot be read": #162 narrowed this guard to the
  # `-x` the operation actually needs, so the message now names the bit that
  # failed. See (12f) for the mode that separates the two.
  t_assert_contains "$T_OUT" "cannot be traversed" "orphans: the untraversable root names the permission it lacks"
fi
chmod 755 "$PRIV/priv"
# And the ordinary case still works once permission is restored — otherwise the
# guard above could be refusing every root and the tests above would not notice.
t_capture oss_worktree_orphans private_core "$PS"
t_assert_rc 0 "orphans: a readable root with an unclaimed dir is rc 0 again once permission is restored"
t_assert_eq "$PRIV/priv/.worktrees/r9.s9.w9" "$T_OUT" "orphans: and it reports the orphan it could not see a moment ago"
rm -rf "$PRIV/priv"

# (12f) A TRAVERSAL-ONLY ROOT IS USABLE, AND MUST NOT BE SKIPPED. #162.
#
# (12d)'s fix required `-x` AND `-r` on the root. Reaching `$root/.worktrees`
# needs only EXECUTE; READ on the root would be needed to LIST the root, which
# this selector never does — it composes the `.worktrees` path directly. So a
# mode-0111 root is fully inspectable, and demanding `-r` turned it into
# `skip: worktrees(private_core)`: a false skip on a repo whose orphans are
# demonstrably enumerable. That is an OVER-CORRECTION — a guard stricter than
# the operation needs — and it was created by (12d)'s own fix. (Codex, PR #160
# round 4, in the review that landed six minutes after the merge.)
#
# MODE 0111 IS THE ONLY INPUT THAT SEPARATES THE TWO GUARDS. (12d) uses mode
# 000, which fails `-x` and `-r` alike, so it passes whether the root check is
# `-x` or `-x && -r` — it cannot distinguish the fix from the bug, and a test
# that cannot fail reads as coverage while checking nothing.
mkdir -p "$PRIV/priv/.worktrees/r9.s9.w9"
chmod 0111 "$PRIV/priv"
# Same root-user probe as (12d), for the same reason: mode bits do not restrict
# uid 0, and there the arm would silently stop being exercised.
if [ -r "$PRIV/priv" ]; then
  echo "NOTE: chmod 0111 did not restrict this user (uid $(id -u)); traversal-only arm NOT exercised"
else
  t_capture oss_worktree_orphans private_core "$PS"
  t_assert_rc 0 "orphans: a traversal-only root is INSPECTED — execute is all that reaching .worktrees needs"
  t_assert_eq "$PRIV/priv/.worktrees/r9.s9.w9" "$T_OUT" "orphans: and it reports the orphan the -r requirement was hiding"
fi
chmod 0755 "$PRIV/priv"
rm -rf "$PRIV/priv"

# (12b) The DRIFT GUARD that lived here is DELETED with doctor's repo-key loop.
# It asserted that doctor's hand-spelled `for key in ...` matched
# `_oss_repo_root`'s closed key list, because two lists that can diverge
# reintroduce #156 for whichever key only one of them knows. doctor no longer
# enumerates repo keys - the repo-vs-state comparison is prose now - so there
# is no second copy to drift from, and a guard asserting agreement between one
# list and nothing would pass while checking nothing. Key validation itself
# stays covered by (5) and (12).

cd /; rm -rf "$PRIV"

# ---------------------------------------------------------------------------
# (12e) THE PRINTED REMEDY MUST SURVIVE A PATH WITH SHELL METACHARACTERS.
#
# Round 2 pinned the state into the warn line and the prose began promising a
# command "runnable as printed" — which made the quoting part of the contract.
# Wrapping the path in `"` does not deliver it: a `$` expands, backticks and
# `$(...)` execute, and an embedded `"` ends the quoting outright, so an
# operator copying the line can select the wrong state or run something the
# line never showed them. Fixed with `printf %q`, whose whole job is this.
# (Codex P2, PR #160 round 3.)
#
# The fixture puts `$` and a space in the state filename — the mildest form of
# the problem, and enough that an unquoted `$O` would expand to nothing.
# ---------------------------------------------------------------------------
QRT="$(mktemp -d)"
mkdir -p "$QRT/ws/.workspace" "$QRT/canon" "$QRT/priv/.worktrees/r9.s9.w9"
git -C "$QRT/canon" init -q
git -C "$QRT/canon" config user.email t@t; git -C "$QRT/canon" config user.name t
echo seed > "$QRT/canon/f.txt"
git -C "$QRT/canon" add .; git -C "$QRT/canon" commit -qm seed
QS="$QRT/state \$OSS_WEIRD name.json"
cat > "$QRT/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$QRT/ws"},"canonical":{"root":"$QRT/canon"},"private_core":{"root":"$QRT/priv"},"well_known_paths":{"project_state":"$QS"}}
EOF
cd "$QRT/ws"
oss_state_init "$QS" quoted-demo >/dev/null
QREL="$(oss_entity_add_release "$QS" "q-rel" "a goal")"
QSPN="$(oss_entity_add_spine "$QS" "$QREL" "q-spine" flesh canonical)"
oss_entity_add_work_item "$QS" "$QSPN" "a work item" canonical >/dev/null

# The property is the VERB's, not the read-out's: a state path holding `$` and a
# space must still resolve. This used to extract doctor's printed remedy and run
# it verbatim; doctor prints no remedy now, so it calls the command directly and
# keeps the thing that actually regressed (Codex P2, PR #160 round 3).
QOUT="$( export OSS_WEIRD=BROKEN; "$OSS" worktree_orphans private_core "$QS" 2>/dev/null )"; QRC=$?
t_assert_eq "0" "$QRC" "quoting: worktree_orphans runs against a state path holding \$ and a space"
t_assert_eq "$QRT/priv/.worktrees/r9.s9.w9" "$QOUT" "quoting: and it names the orphan rather than a wrong or empty path"

# ===========================================================================
# TOPOLOGY TWIN (#272/#310 Task 11, spec decision O1): the repo-SCOPED
# resolution and worktree-orphan-scoping this file pins throughout against a
# .workspace/pairing.json two-role manifest ("canonical" / "private_core"),
# run again from a NATIVE .ossify/topology.json declaring two repos under
# names that are neither of those - "svc_a" / "svc_b" - so nothing below can
# pass because of a magic name. Cross-repo non-attribution is the actual
# multi-canonical feature #272/#310 ships; this is where it is proven to
# hold from a native declaration, not only from a translated legacy one.
#
# SIX orphan-scoping arms, matching the legacy ORPH fixture's own six: no
# .worktrees dir at all (:323-327), claimed-by-id (:329-338), an unclaimed
# directory is the finding (:340-344), the DISJOINT claim path - a directory
# whose basename is not a work-item id but whose PATH is journaled
# (:346-353, which the legacy comment calls out as a code path disjoint from
# the id-claim arm), cross-repo non-attribution (:397-406), and the
# dispatcher-path invocation under real `set -euo pipefail` (:359-364, whose
# own comment says the unmatched-glob guard and the `jq -e || printf` pair
# behave differently under strict mode). Review round 1, finding 2: an
# earlier draft of this twin covered only 3 of the 6 and did not name the
# other 3 as excluded - not a defensible triage, so all 6 are here now.
#
# SCOPED DELIBERATELY everywhere else, not a line-for-line replay of the
# whole file: the git-hook-chatter, dirty-worktree-halt, unmerged-branch,
# spine-branch-lifecycle, permission-bit and path-quoting assertions above
# test git/filesystem semantics that run entirely AFTER a repo root is
# already resolved - none of them touch `_oss_shape_file` or
# `_oss_repo_root`, so they behave identically regardless of manifest source
# and duplicating them here would prove nothing new (task-11-report.md's
# triage names the same reasoning for the files this task excludes
# wholesale).
# ===========================================================================
TWT="$(mktemp -d)"
mkdir -p "$TWT/ws/.ossify" "$TWT/svc_a" "$TWT/svc_b"
for r in svc_a svc_b; do
  git -C "$TWT/$r" init -q
  git -C "$TWT/$r" config user.email t@t; git -C "$TWT/$r" config user.name t
  echo seed > "$TWT/$r/f.txt"
  git -C "$TWT/$r" add .; git -C "$TWT/$r" commit -qm seed
done
cat > "$TWT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"svc_a":{"root":"$TWT/svc_a"},"svc_b":{"root":"$TWT/svc_b"}},"well_known_paths":{}}
JSON
cd "$TWT/ws"

t_capture _oss_repo_root svc_a
t_assert_eq "$TWT/svc_a" "$T_OUT" "topology twin: svc_a repo root resolves"
t_capture _oss_repo_root nonsense
t_assert_rc 2 "topology twin: an unknown repo key is rc 2"

# State minted BEFORE any worktree touches the filesystem, so the very next
# check - orphans against a repo whose .worktrees/ does not exist yet - is
# genuine, not incidentally true because state itself is absent.
TWS="$TWT/ws/.ossify/project-state.json"
oss_state_init "$TWS" "topology-twin" >/dev/null
TWREL="$(oss_entity_add_release "$TWS" "twin-rel" "a goal")"
TWSPN="$(oss_entity_add_spine "$TWS" "$TWREL" "twin-spine" flesh svc_a)"
TWWI_A="$(oss_entity_add_work_item "$TWS" "$TWSPN" "svc_a item" svc_a)"
TWWI_B="$(oss_entity_add_work_item "$TWS" "$TWSPN" "svc_b item" svc_b)"

# (0) No `.worktrees` directory at all is not a finding.
t_capture oss_worktree_orphans svc_a "$TWS"
t_assert_rc 0 "topology twin: a repo with no .worktrees dir at all is rc 0"
t_assert_eq "" "$T_OUT" "topology twin: no .worktrees dir reports nothing"

t_capture oss_worktree_add svc_a r9.s9.w1 "first-ticket" HEAD
t_assert_rc 0 "topology twin: worktree_add ok"
TWA="$T_OUT"
t_assert_eq "$TWT/svc_a/.worktrees/r9.s9.w1" "$TWA" "topology twin: worktree path convention"

t_capture "$OSS" repo_root svc_b
t_assert_eq "$TWT/svc_b" "$T_OUT" "topology twin: dispatcher repo_root resolves the second declared repo"
t_capture "$OSS" worktree_add svc_b r9.s9.w2 "second-ticket" HEAD
t_assert_rc 0 "topology twin: dispatcher worktree_add ok on the second repo"
TWB="$T_OUT"
t_assert_eq "$TWT/svc_b/.worktrees/r9.s9.w2" "$TWB" "topology twin: the second repo's worktree lands under ITS OWN root, not svc_a's"

# Both worktrees above are claimed by NOTHING TWWI_A/TWWI_B carry (different
# ids) - clean them before the orphan-scoping arms below, which start from
# an empty .worktrees/ on svc_a and assert exact output sets.
git -C "$TWT/svc_a" worktree remove --force "$TWA" >/dev/null 2>&1
git -C "$TWT/svc_b" worktree remove --force "$TWB" >/dev/null 2>&1

# (a) a spawned-but-not-yet-journaled worktree is claimed by its work item's id.
oss_worktree_add svc_a "$TWWI_A" "svc_a-slug" HEAD >/dev/null
t_capture oss_worktree_orphans svc_a "$TWS"
t_assert_eq "" "$T_OUT" "topology twin: a spawned-but-not-yet-journaled worktree is claimed by its work item's id"

# (b) a directory no work item claims, under svc_a, is the finding.
mkdir -p "$TWT/svc_a/.worktrees/x9.s9.w9"
t_capture oss_worktree_orphans svc_a "$TWS"
t_assert_eq "$TWT/svc_a/.worktrees/x9.s9.w9" "$T_OUT" "topology twin: an unclaimed directory under svc_a is reported"

# (d) the DISJOINT claim path: a directory whose basename is NOT a work-item
# id, claimed because a work item's journaled worktree_path IS it. x9.s9.w9
# from (b) stays present and stays reported - proving the path arm silences
# only hand-named-dir, not everything (drop the path arm and this assertion
# is the one that goes red while (a) stays green - the two arms cover
# disjoint failures, same as the legacy pair).
mkdir -p "$TWT/svc_a/.worktrees/hand-named-dir"
oss_entity_set_work_item_exec "$TWS" "$TWWI_A" "work/$TWWI_A-svc_a-slug" \
  "$TWT/svc_a/.worktrees/hand-named-dir" "$(git -C "$TWT/svc_a" rev-parse HEAD)" >/dev/null
t_capture oss_worktree_orphans svc_a "$TWS"
t_assert_eq "$TWT/svc_a/.worktrees/x9.s9.w9" "$T_OUT" "topology twin: a dir claimed by a journaled worktree_path is not reported"
rm -rf "$TWT/svc_a/.worktrees/x9.s9.w9" "$TWT/svc_a/.worktrees/hand-named-dir"

# (c) cross-repo non-attribution: an svc_b work item's id must NOT claim a
# same-named directory that happens to sit under svc_a's root.
mkdir -p "$TWT/svc_a/.worktrees/$TWWI_B"
t_capture oss_worktree_orphans svc_a "$TWS"
t_assert_eq "$TWT/svc_a/.worktrees/$TWWI_B" "$T_OUT" "topology twin: an svc_b work item does NOT claim an svc_a-rooted directory of the same id"
rm -rf "$TWT/svc_a/.worktrees/$TWWI_B"

# (e) dispatcher-path - bin/oss runs `set -euo pipefail`; every arm above
# only sourced the lib. The unmatched-glob guard and the `jq -e || printf`
# pair are both shapes that behave differently under strict mode.
mkdir -p "$TWT/svc_a/.worktrees/x9.s9.w9"
t_capture "$OSS" worktree_orphans svc_a "$TWS"
t_assert_rc 0 "topology twin: dispatcher worktree_orphans under strict mode is rc 0"
t_assert_eq "$TWT/svc_a/.worktrees/x9.s9.w9" "$T_OUT" "topology twin: dispatcher worktree_orphans reports the same single orphan"
rm -rf "$TWT/svc_a/.worktrees/x9.s9.w9"

# An unconfigured repo key must not degrade to a silent guess.
t_capture oss_worktree_orphans svcC "$TWS"
t_assert_rc 2 "topology twin: an unconfigured repo key is rc 2, never a silent fallback"

cd /
rm -rf "$TWT"

# ===========================================================================
# LEGACY RECORDS UNDER N>1. Every pre-#272 journal holds work items with no
# `target_repo` at all. `oss_worktree_orphans` computes a default key to
# attribute those, and under more than one declared repo `_oss_default_repo_key`
# refuses. The REFUSAL is correct and deliberate - #272/#310 Task 4's fail-safe
# rule, pinned by the PRIV fixture below: guessing a repo for an unattributable
# record is worse than stopping. What was wrong is that it borrowed
# `_oss_default_repo_key`'s "no repo key given" wording on a call that gave one,
# sending the caller to re-run with the argument they already passed.
# ===========================================================================
LGT="$(mktemp -d)"; mkdir -p "$LGT/ws/.ossify" "$LGT/canon" "$LGT/priv"
for r in canon priv; do
  git -C "$LGT/$r" init -q
  git -C "$LGT/$r" config user.email t@t; git -C "$LGT/$r" config user.name t
  echo seed > "$LGT/$r/f.txt"; git -C "$LGT/$r" add .; git -C "$LGT/$r" commit -qm seed
done
cat > "$LGT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"canonical":{"root":"$LGT/canon"},"private_core":{"root":"$LGT/priv"}},"well_known_paths":{}}
JSON
cd "$LGT/ws"
LGS="$LGT/state.json"
oss_state_init "$LGS" legacy-under-n >/dev/null
LGREL="$(oss_entity_add_release "$LGS" "legacy-rel" "a goal")"
LGSPN="$(oss_entity_add_spine "$LGS" "$LGREL" "legacy-spine" flesh canonical)"
# A pre-#272 record: no target_repo key at all, not a null one.
jq '.work_items += [{"id":"r0.s1.w9","spine":"r0.s1","title":"legacy","status":"planned","created_at":"2026-01-01T00:00:00Z"}]'   "$LGS" > "$LGS.tmp" && mv "$LGS.tmp" "$LGS"
t_assert_eq "1" "$(jq '[.work_items[] | select(.target_repo == null)] | length' "$LGS")"   "legacy fixture really holds a record with no target_repo - the arm below is otherwise vacuous"
mkdir -p "$LGT/canon/.worktrees/x9.s9.w9"
t_capture oss_worktree_orphans canonical "$LGS"
t_assert_rc 2 "legacy record under N>1 refuses - the spec's fail-safe rule, unchanged"
t_assert_contains "$T_OUT" "carry no target_repo" "the refusal names the LEGACY RECORDS as the ambiguity"
t_assert_contains "$T_OUT" "not about the repo key you passed" "and says explicitly that the explicit key was not the problem"
case "$T_OUT" in
  *"no repo key given"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: the refusal still says 'no repo key given' on a call that gave one - that message sends the caller to re-run with the argument they already passed";;
  *) T_PASS=$((T_PASS+1));;
esac
cd /; rm -rf "$LGT"

# --- worktree_reattach (#133) ---------------------------------------------------
# A worktree directory deleted by hand leaves git a stale registration and the
# branch still "checked out" there, so a plain re-add refuses. reattach re-adds on
# the EXISTING branch (no -b) and overrides only that one stale registration.
#
# FIXTURE (recorded deviation from the brief's literal placement): this block sits
# at the file's end, where the LGT teardown above left the cwd at `/` while
# `$TMP/ws` - the workspace whose manifest is the main fixture's, `canonical` ->
# `$TMP/canon` - is still on disk. `_oss_repo_root` resolves by walking up from
# $PWD, so the block re-enters that workspace first; without it every
# `canonical` lookup below resolves against no manifest at all. No assertion was
# changed.
cd "$TMP/ws"
RA_WT="$(oss_worktree_add canonical r9.s1.w1 "ra" HEAD)"
echo work > "$RA_WT/ra.txt"; git -C "$RA_WT" add ra.txt; git -C "$RA_WT" commit -qm "ra work"
RA_TIP="$(git -C "$RA_WT" rev-parse HEAD)"
rm -rf "$RA_WT"
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w1 work/r9.s1.w1-ra
t_assert_rc 0 "reattach: a deleted worktree with its branch intact re-attaches"
t_assert_eq "$TMP/canon/.worktrees/r9.s1.w1" "$T_OUT" "reattach: echoes the conventional path"
t_assert_eq "work/r9.s1.w1-ra" "$(git -C "$RA_WT" rev-parse --abbrev-ref HEAD)" "reattach: ...on the existing branch"
t_assert_eq "$RA_TIP" "$(git -C "$RA_WT" rev-parse HEAD)" "reattach: ...at its tip - no commit lost, no new branch cut"
t_assert_eq "1" "$(git -C "$TMP/canon" worktree list --porcelain | grep -c "^worktree .*/r9.s1.w1\$")" "reattach: exactly one registration for the path"

t_capture bash "$OSS" worktree_reattach canonical r9.s1.w1 work/r9.s1.w1-ra
t_assert_rc 8 "reattach: refuses when the path exists"

rm -rf "$RA_WT"
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w1 work/r9.s1.w1-nope
t_assert_rc 8 "reattach: refuses a branch that does not exist"
t_assert_contains "$T_OUT" "does not exist" "reattach: ...naming it"

# The branch is live in ANOTHER worktree: -f must never be used to steal it.
OTHER="$TMP/other-wt"; git -C "$TMP/canon" worktree prune
git -C "$TMP/canon" worktree add -q "$OTHER" work/r9.s1.w1-ra
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w1 work/r9.s1.w1-ra
t_assert_rc 8 "reattach: refuses when the branch is checked out in a different, live worktree"
# "Untouched" is FOUR facts, and the branch name alone is the weakest of them:
# a stolen branch still resolves its ref name in the victim worktree, so the
# original assertion stayed green under an implementation that overrode with
# -f and checked the same branch out a second time. Pin the worktree itself
# (.git file present), its registration incl. its branch ref, and the absence
# of any registration at the item's own path - the last is what the steal
# creates, and the one that can only pass if the refusal really refused.
t_assert_eq "work/r9.s1.w1-ra" "$(git -C "$OTHER" rev-parse --abbrev-ref HEAD)" "reattach: ...and leaves that worktree untouched"
[ -e "$OTHER/.git" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: reattach: the refused reattach destroyed the live holder's .git"; }
t_assert_eq "1" "$(git -C "$TMP/canon" worktree list --porcelain | awk '/^worktree /{w=substr($0,10)} w ~ /\/other-wt$/ && $0=="branch refs/heads/work/r9.s1.w1-ra" {c++} END{print c+0}')" "reattach: ...still registered, on its branch"
t_assert_eq "0" "$(git -C "$TMP/canon" worktree list --porcelain | grep -c "^worktree .*/\.worktrees/r9\.s1\.w1\$")" "reattach: ...and no registration for this item's path was created by the refusal"
git -C "$TMP/canon" worktree remove --force "$OTHER"

# A stale registration of ANOTHER item must survive (never prune globally).
SIB="$(oss_worktree_add canonical r9.s1.w2 "sib" HEAD)"; rm -rf "$SIB"
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w1 work/r9.s1.w1-ra
t_assert_rc 0 "reattach: works after the stale entry was already pruned (plain add path)"
t_assert_contains "$(git -C "$TMP/canon" worktree list --porcelain)" "r9.s1.w2" "reattach: a sibling's stale registration is NOT pruned"

# A LOCKED stale registration is refused by OUR check, not by git's accident.
# git's own `worktree add -f` over a locked missing registration fails too, but
# with its own wording ("is a missing but locked worktree; use 'add -f -f' to
# override") - rc 8 either way, so the rc alone proves nothing. The message is
# the discriminator: ours says what is locked and how to clear it, and never
# advertises `-f -f`, which would force past a lock its owner set deliberately.
LOCK_WT="$(oss_worktree_add canonical r9.s1.w3 "lk" HEAD)"
git -C "$TMP/canon" worktree lock "$LOCK_WT"
rm -rf "$LOCK_WT"
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w3 work/r9.s1.w3-lk
t_assert_rc 8 "reattach: refuses a LOCKED stale registration of this item's own path"
t_assert_contains "$T_OUT" "is locked" "reattach: ...and the refusal names the lock"
t_assert_contains "$T_OUT" "git worktree unlock" "reattach: ...and prints the remedy that clears it"
git -C "$TMP/canon" worktree unlock "$LOCK_WT" 2>/dev/null || true
git -C "$TMP/canon" worktree prune

# The two shapes that separate the holder guard's arms. The live-holder case
# above fails BOTH arms at once - its path exists AND it does not carry this
# item's suffix - so it cannot say which arm refuses. These two fail exactly
# ONE arm each; deleting either arm alone turns exactly its row red.
#
# (i) LIVE holder whose path DOES carry this item's suffix (it is another
# root's conventional path). The suffix arm alone overrides this with -f; only
# the existence arm refuses it.
ALT_WT="$TMP/alt-root/.worktrees/r9.s1.w4"
mkdir -p "$(dirname "$ALT_WT")"
git -C "$TMP/canon" worktree add -q -b work/r9.s1.w4-alt "$ALT_WT" HEAD
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w4 work/r9.s1.w4-alt
t_assert_rc 8 "reattach control: a LIVE holder carrying this item's suffix (another root) is refused"
t_assert_contains "$T_OUT" "not this item's missing worktree" "reattach control: ...naming it"
git -C "$TMP/canon" worktree remove --force "$ALT_WT" >/dev/null 2>&1
git -C "$TMP/canon" branch -D work/r9.s1.w4-alt >/dev/null 2>&1

# (ii) MISSING holder at a path WITHOUT this item's suffix. The existence arm
# alone lets this through and overrides the foreign registration with -f; only
# the suffix arm refuses it.
ELSE_WT="$TMP/elsewhere-wt"
git -C "$TMP/canon" worktree add -q -b work/r9.s1.w5-else "$ELSE_WT" HEAD
rm -rf "$ELSE_WT"
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w5 work/r9.s1.w5-else
t_assert_rc 8 "reattach control: a MISSING holder at a path that is not this item's is refused"
t_assert_contains "$T_OUT" "not this item's missing worktree" "reattach control: ...naming it"
git -C "$TMP/canon" worktree prune
git -C "$TMP/canon" branch -D work/r9.s1.w5-else >/dev/null 2>&1

# Review Focus 1: the repo reached through a symlink.
mkdir -p "$TMP/real"; ln -s "$TMP/real" "$TMP/link"
git -C "$TMP/real" init -q; git -C "$TMP/real" config user.email t@t; git -C "$TMP/real" config user.name t
echo s > "$TMP/real/f"; git -C "$TMP/real" add .; git -C "$TMP/real" commit -qm s
LNK_WT="$TMP/link/.worktrees/r9.s2.w1"
git -C "$TMP/link" worktree add -q -b work/r9.s2.w1-l "$LNK_WT" HEAD; rm -rf "$LNK_WT"
t_capture _oss_worktree_reattach_locked "$TMP/link" r9.s2.w1 work/r9.s2.w1-l
t_assert_rc 0 "reattach: a repo root reached through a symlink still matches its stale registration"

# --- #673 E1/E2: dead holders, dual holders, and an add that fails late ------
#
# E1: the pre-fix guard suffix-matched ANY root and then used `add -f` over the
# dead registration, leaving TWO holders behind - every later reattach refused
# rc 8 with no sanctioned recovery (§2b forbids prune and `-f -f`). The fix
# clears this item's own dead registration(s) with `git worktree remove` and
# adds PLAIN, so one holder is all that can remain.
E1_WT="$(oss_worktree_add canonical r9.s1.w6 "e1" HEAD)"
E1_MOVED="$TMP/oldroot/.worktrees/r9.s1.w6"; mkdir -p "$(dirname "$E1_MOVED")"
git -C "$TMP/canon" worktree move "$E1_WT" "$E1_MOVED"   # registered under another root spelling
rm -rf "$E1_MOVED"                                        # ...and dead there
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w6 work/r9.s1.w6-e1
t_assert_rc 0 "E1: a dead registration under ANOTHER root spelling re-attaches"
t_assert_eq "$TMP/canon/.worktrees/r9.s1.w6" "$T_OUT" "E1: ...at the conventional path"
t_assert_eq "1" "$(git -C "$TMP/canon" worktree list --porcelain | awk '/^worktree /{w=substr($0,10); if (w ~ /r9\.s1\.w6$/) c++} END{print c+0}')" "E1: ...with exactly ONE holder - the old registration was cleared, not overridden"

# E1b: the wedge the old code already created - TWO dead registrations, both
# this item's own path under different root spellings - is recovered, not
# stuck: both are cleared, then the plain add. (Constructed with `add -f` while
# the first holder was still live, exactly as the old reattach did it.)
E1B_WT="$(oss_worktree_add canonical r9.s1.w7 "e1b" HEAD)"
E1B_ALT="$TMP/altroot/.worktrees/r9.s1.w7"; mkdir -p "$(dirname "$E1B_ALT")"
git -C "$TMP/canon" worktree add -q -f "$E1B_ALT" work/r9.s1.w7-e1b
rm -rf "$E1B_WT" "$E1B_ALT"
t_assert_eq "2" "$(git -C "$TMP/canon" worktree list --porcelain | awk '/^worktree /{w=substr($0,10); if (w ~ /r9\.s1\.w7$/) c++} END{print c+0}')" "E1b setup: the dual-holder shape really holds two dead registrations"
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w7 work/r9.s1.w7-e1b
t_assert_rc 0 "E1b: the pre-existing dual-holder shape recovers"
t_assert_eq "1" "$(git -C "$TMP/canon" worktree list --porcelain | awk '/^worktree /{w=substr($0,10); if (w ~ /r9\.s1\.w7$/) c++} END{print c+0}')" "E1b: ...leaving exactly one holder"

# E2: an add that fails AFTER registering the path (a post-checkout hook that
# exits nonzero) is rolled back - the pre-fix form reported rc 8 and left the
# worktree, which the next inventory classified differently and every later
# reattach refused because the path existed.
E2_WT="$(oss_worktree_add canonical r9.s1.w8 "e2" HEAD)"
rm -rf "$E2_WT"
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/canon/.git/hooks/post-checkout"
chmod +x "$TMP/canon/.git/hooks/post-checkout"
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w8 work/r9.s1.w8-e2
t_assert_rc 8 "E2: an add that fails in the checkout returns rc 8"
t_assert_contains "$T_OUT" "rolled back" "E2: ...and reports the rollback"
[ -e "$E2_WT" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: E2: the failed reattach left the worktree path behind"; } || T_PASS=$((T_PASS+1))
t_assert_eq "present" "$(git -C "$TMP/canon" show-ref --verify --quiet refs/heads/work/r9.s1.w8-e2 && echo present || echo gone)" "E2: ...preserving the pre-existing branch"
t_assert_eq "0" "$(git -C "$TMP/canon" worktree list --porcelain | awk '/^worktree /{w=substr($0,10); if (w ~ /r9\.s1\.w8$/) c++} END{print c+0}')" "E2: ...and no registration survives"
rm -f "$TMP/canon/.git/hooks/post-checkout"
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w8 work/r9.s1.w8-e2
t_assert_rc 0 "E2 control: with the failing hook gone, the same reattach succeeds"

# I1: with SEVERAL dead registrations for one item, every holder is validated
# BEFORE any is removed. The pre-fix loop cleared entries as it went, so an
# unlocked registration ahead of a locked one was removed and the function
# still returned rc 8 - Git metadata mutated while the contract promises to
# leave stale entries as found. Order is by path (git lists worktrees sorted),
# so the fixture's unlocked entry sorts first and the locked one second - both
# asserted, so a reordering on another git cannot quietly stop this fixture
# from exercising the finding's order.
I1_UNLOCK="$TMP/i1a/.worktrees/r9.s1.w9"; I1_LOCKED="$TMP/i1z/.worktrees/r9.s1.w9"
git -C "$TMP/canon" branch work/r9.s1.w9-rd
mkdir -p "$(dirname "$I1_UNLOCK")" "$(dirname "$I1_LOCKED")"
git -C "$TMP/canon" worktree add -q "$I1_UNLOCK" work/r9.s1.w9-rd
rm -rf "$I1_UNLOCK"
git -C "$TMP/canon" worktree add -q -f "$I1_LOCKED" work/r9.s1.w9-rd
git -C "$TMP/canon" worktree lock "$I1_LOCKED"
rm -rf "$I1_LOCKED"
t_assert_eq "2" "$(git -C "$TMP/canon" worktree list --porcelain | awk -v s="/.worktrees/r9.s1.w9" '/^worktree /{w=substr($0,10); if (length(w)>=length(s) && substr(w,length(w)-length(s)+1)==s) c++} END{print c+0}')" "I1 setup: two dead registrations for one item"
t_assert_eq "$I1_UNLOCK" "$(git -C "$TMP/canon" worktree list --porcelain | awk -v s="/.worktrees/r9.s1.w9" '/^worktree /{w=substr($0,10); if (length(w)>=length(s) && substr(w,length(w)-length(s)+1)==s) {print w; exit}}')" "I1 setup: the UNLOCKED registration lists FIRST (the finding's order)"
t_assert_eq "locked" "$(git -C "$TMP/canon" worktree list --porcelain | awk -v l="$I1_LOCKED" '/^worktree /{w=substr($0,10)} /^locked/{if (w==l) print "locked"}')" "I1 setup: ...and the SECOND carries the lock"
I1_BEFORE="$(git -C "$TMP/canon" worktree list --porcelain)"
t_capture bash "$OSS" worktree_reattach canonical r9.s1.w9 work/r9.s1.w9-rd
t_assert_rc 8 "I1: a locked registration later in the set refuses the reattach"
t_assert_contains "$T_OUT" "is locked" "I1: ...naming the lock"
t_assert_eq "$I1_BEFORE" "$(git -C "$TMP/canon" worktree list --porcelain)" "I1: ...and NOTHING was removed - both stale registrations stand, as found"
git -C "$TMP/canon" worktree unlock "$I1_LOCKED" 2>/dev/null || true
git -C "$TMP/canon" worktree prune
git -C "$TMP/canon" branch -D work/r9.s1.w9-rd >/dev/null 2>&1

# I1b: an unreadable worktree list refuses (fail closed) instead of reading
# as "no holders" and adding over a hidden holder - the same old form as the
# inventory's `|| holders=""`. The shim fails ONLY `worktree list`, so the
# function's other git calls still resolve; the path is left absent.
git -C "$TMP/canon" branch work/r9.s1.w10-rd
mkdir -p "$TMP/failgit-i1"
printf '#!/usr/bin/env bash\ncase " $* " in *" worktree list "*) echo "fatal: simulated worktree list failure" >&2; exit 128;; esac\nexec %s "$@"\n' "$(command -v git)" > "$TMP/failgit-i1/git"
chmod +x "$TMP/failgit-i1/git"
t_capture env PATH="$TMP/failgit-i1:$PATH" bash "$OSS" worktree_reattach canonical r9.s1.w10 work/r9.s1.w10-rd
t_assert_rc 8 "I1b: an unreadable worktree list refuses the reattach"
t_assert_contains "$T_OUT" "cannot read the worktree list" "I1b: ...naming the read failure"
[ -e "$TMP/canon/.worktrees/r9.s1.w10" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: I1b: the refused reattach left a worktree path behind"; } || T_PASS=$((T_PASS+1))
git -C "$TMP/canon" branch -D work/r9.s1.w10-rd >/dev/null 2>&1

# --- #673 A5: worktree_remove tolerates a worktree whose DIRECTORY is gone ---
# The re-entry inventory routes a merged item with a deleted worktree `skip` /
# `finish-status`; spine close then calls worktree_remove for it at step 10,
# which used to refuse rc 1 (its resolver requires the directory) - cleanup
# wedged at its last step for exactly those shapes. State supplies the branch.
# A separate workspace: the minted item id here is r0.s1.w1, whose path the
# main fixture's canon already used.
A5WS="$TMP/a5ws"; A5CAN="$TMP/a5canon"
mkdir -p "$A5WS/.workspace" "$A5CAN"
git -C "$A5CAN" init -q -b main; git -C "$A5CAN" config user.email t@t; git -C "$A5CAN" config user.name t
echo s > "$A5CAN/f"; git -C "$A5CAN" add .; git -C "$A5CAN" commit -qm s
printf '{"schema_version":"1.0","ai_workspace":{"root":"%s"},"canonical":{"root":"%s"},"well_known_paths":{}}' "$A5WS" "$A5CAN" > "$A5WS/.workspace/pairing.json"
cd "$A5WS"
A5S="$A5WS/state.json"
oss_state_init "$A5S" a5-demo >/dev/null
A5REL="$(oss_entity_add_release "$A5S" "a5-rel" "a goal")"
A5SP="$(oss_entity_add_spine "$A5S" "$A5REL" "a5" flesh canonical)"
A5WI="$(oss_entity_add_work_item "$A5S" "$A5SP" "t1" canonical)"
A5WT="$(oss_worktree_add canonical "$A5WI" "a5" HEAD)"
echo a > "$A5WT/a"; git -C "$A5WT" add a; git -C "$A5WT" commit -qm a5
oss_entity_set_work_item_exec "$A5S" "$A5WI" "work/$A5WI-a5" "$A5WT" "$(git -C "$A5WT" rev-parse HEAD)" >/dev/null
git -C "$A5CAN" merge -q "work/$A5WI-a5" -m "merge $A5WI"
# #673 L5 (superseding round 1's clear-ALL): a second dead registration for
# the same item under ANOTHER root is NOT this verb's to delete - the suffix
# match alone also names same-basename paths in other workspaces, where the
# worktree may be live. Cleanup refuses the whole set, removing nothing.
A5ALT="$A5CAN/../a5alt/.worktrees/$A5WI"; mkdir -p "$(dirname "$A5ALT")"
git -C "$A5CAN" worktree add -q -f "$A5ALT" "work/$A5WI-a5"
rm -rf "$A5WT" "$A5ALT"
t_assert_eq "2" "$(git -C "$A5CAN" worktree list --porcelain | awk -v s="/.worktrees/$A5WI" '/^worktree /{w=substr($0,10); if (length(w)>=length(s) && substr(w,length(w)-length(s)+1)==s) c++} END{print c+0}')" "A5 setup: the dual dead-registration shape really holds two entries"
A5_BEFORE="$(git -C "$A5CAN" worktree list --porcelain)"
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI"
t_assert_rc 8 "L5: a stale registration under ANOTHER root refuses the cleanup"
t_assert_contains "$T_OUT" "not under this item's root" "L5: ...naming why; nothing was removed"
t_assert_eq "$A5_BEFORE" "$(git -C "$A5CAN" worktree list --porcelain)" "L5: ...the whole registration set stands, byte-identical"
t_assert_eq "present" "$(git -C "$A5CAN" show-ref --verify --quiet "refs/heads/work/$A5WI-a5" && echo present || echo gone)" "L5: ...and the branch survives"
# Control: with the foreign registration gone (cleared by hand, as the
# refusal's own text says to), the deleted directory at the item's OWN path
# no longer wedges cleanup - round 1's A5 outcome, now scoped to the own root.
git -C "$A5CAN" worktree remove "$A5ALT"
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI"
t_assert_rc 0 "A5 control: a deleted directory at the item's OWN path no longer wedges worktree_remove"
t_assert_eq "gone" "$(git -C "$A5CAN" show-ref --verify --quiet "refs/heads/work/$A5WI-a5" && echo present || echo gone)" "A5 control: ...and the merged branch is deleted"
t_assert_eq "0" "$(git -C "$A5CAN" worktree list --porcelain | awk -v s="/.worktrees/$A5WI" '/^worktree /{w=substr($0,10); if (length(w)>=length(s) && substr(w,length(w)-length(s)+1)==s) c++} END{print c+0}')" "A5 control: ...its registration is cleared"
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI"
t_assert_rc 0 "A5b: a second call (dir and branch both already gone) is clean"
# L5b (#673 L5): the harm itself - a LIVE worktree of this repo under ANOTHER
# root with the same basename must survive the cleanup. The pre-fix
# suffix-only loop passed it straight to `git worktree remove`, deleting the
# live worktree's directory.
A5WI3="$(oss_entity_add_work_item "$A5S" "$A5SP" "t3" canonical)"
A5BIG="$(oss_worktree_add canonical "$A5WI3" "a5b" HEAD)"
echo b > "$A5BIG/b"; git -C "$A5BIG" add b; git -C "$A5BIG" commit -qm a5b
oss_entity_set_work_item_exec "$A5S" "$A5WI3" "work/$A5WI3-a5b" "$A5BIG" "$(git -C "$A5BIG" rev-parse HEAD)" >/dev/null
git -C "$A5CAN" merge -q "work/$A5WI3-a5b" -m "merge $A5WI3"
A5LIVE="$A5CAN/../a5live/.worktrees/$A5WI3"; mkdir -p "$(dirname "$A5LIVE")"
git -C "$A5CAN" worktree move "$A5BIG" "$A5LIVE"    # LIVE, under another root
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI3"
t_assert_rc 8 "L5b: a LIVE worktree under another root refuses the cleanup"
[ -d "$A5LIVE" ] && [ -e "$A5LIVE/.git" ] \
  && T_PASS=$((T_PASS+1)) \
  || { T_FAIL=$((T_FAIL+1)); echo "FAIL: L5b: the live worktree under another root was destroyed"; }
t_assert_contains "$T_OUT" "not under this item's root" "L5b: ...naming why it refused"

# #706: a LOCKED registration cleanup would remove refuses before ANYTHING is
# removed. Two kept dead registrations (derived root, recorded root), the
# unlocked one first: the old loop removed it, then refused on the locked one.
A5WI8="$(oss_entity_add_work_item "$A5S" "$A5SP" "t8" canonical)"
A5W8="$(oss_worktree_add canonical "$A5WI8" "a5e" HEAD)"
echo e > "$A5W8/e"; git -C "$A5W8" add e; git -C "$A5W8" commit -qm a5e
A5REC8="$A5CAN/../a5rec/.worktrees/$A5WI8"; mkdir -p "$(dirname "$A5REC8")"
oss_entity_set_work_item_exec "$A5S" "$A5WI8" "work/$A5WI8-a5e" "$A5REC8" "$(git -C "$A5W8" rev-parse HEAD)" >/dev/null
git -C "$A5CAN" merge -q "work/$A5WI8-a5e" -m "merge $A5WI8"
git -C "$A5CAN" worktree add -q -f "$A5REC8" "work/$A5WI8-a5e"
git -C "$A5CAN" worktree lock "$A5REC8"
rm -rf "$A5W8" "$A5REC8"
t_assert_eq "$A5W8" "$(git -C "$A5CAN" worktree list --porcelain | awk -v s="/.worktrees/$A5WI8" '/^worktree /{w=substr($0,10); if (length(w)>=length(s) && substr(w,length(w)-length(s)+1)==s) {print w; exit}}')" "#706 setup: the UNLOCKED registration lists first"
t_assert_eq "locked" "$(git -C "$A5CAN" worktree list --porcelain | awk -v l="$(cd -P "$(dirname "$A5REC8")" && pwd)/$A5WI8" '/^worktree /{w=substr($0,10)} /^locked/{if (w==l) print "locked"}')" "#706 setup: the second registration carries the lock"
A8_BEFORE="$(git -C "$A5CAN" worktree list --porcelain)"
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI8"
t_assert_rc 8 "#706: a locked registration cleanup would remove refuses the cleanup"
t_assert_contains "$T_OUT" "has a locked registration at" "#706: ...naming the lock"
t_assert_contains "$T_OUT" "$A5WI8" "#706: ...and the item"
t_assert_contains "$T_OUT" "nothing was removed" "#706: ...and saying nothing was removed"
t_assert_eq "$A8_BEFORE" "$(git -C "$A5CAN" worktree list --porcelain)" "#706: ...the whole registration set stands, byte-identical (no partial removal)"
t_assert_eq "present" "$(git -C "$A5CAN" show-ref --verify --quiet "refs/heads/work/$A5WI8-a5e" && echo present || echo gone)" "#706: ...and the branch survives"
# Control: unlocked, the same shape cleans up.
git -C "$A5CAN" worktree unlock "$(cd -P "$(dirname "$A5REC8")" && pwd)/$A5WI8"
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI8"
t_assert_rc 0 "#706 control: with the lock gone the same cleanup succeeds"
t_assert_eq "0" "$(git -C "$A5CAN" worktree list --porcelain | awk -v s="/.worktrees/$A5WI8" '/^worktree /{w=substr($0,10); if (length(w)>=length(s) && substr(w,length(w)-length(s)+1)==s) c++} END{print c+0}')" "#706 control: ...both registrations are cleared"

# #706: the lock check covers the DERIVED root too, not only the recorded one.
A5WI9="$(oss_entity_add_work_item "$A5S" "$A5SP" "t9" canonical)"
A5W9="$(oss_worktree_add canonical "$A5WI9" "a5f" HEAD)"
echo f > "$A5W9/f"; git -C "$A5W9" add f; git -C "$A5W9" commit -qm a5f
# The recorded root differs from the derived one, so only a derived-root lock check can see this lock.
oss_entity_set_work_item_exec "$A5S" "$A5WI9" "work/$A5WI9-a5f" "$A5CAN/../a5rec9/.worktrees/$A5WI9" "$(git -C "$A5W9" rev-parse HEAD)" >/dev/null
git -C "$A5CAN" merge -q "work/$A5WI9-a5f" -m "merge $A5WI9"
git -C "$A5CAN" worktree lock "$A5W9"; rm -rf "$A5W9"
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI9"
t_assert_rc 8 "#706: a locked registration at the DERIVED root refuses the cleanup"
t_assert_contains "$T_OUT" "has a locked registration at $A5W9" "#706: ...naming the locked path"
git -C "$A5CAN" worktree unlock "$A5W9"
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI9"
t_assert_rc 0 "#706 control: unlocked, the derived-root registration is cleared"

# L6 (#673 L6): the deleted-worktree arm's STATE read fails closed. Folding a
# parse failure into an empty branch used to clear the registrations, leave
# the work branch silently alive, and return 0 while close proceeded.
A5WI4="$(oss_entity_add_work_item "$A5S" "$A5SP" "t4" canonical)"
A5W4="$(oss_worktree_add canonical "$A5WI4" "a5c" HEAD)"
echo c > "$A5W4/c"; git -C "$A5W4" add c; git -C "$A5W4" commit -qm a5c
oss_entity_set_work_item_exec "$A5S" "$A5WI4" "work/$A5WI4-a5c" "$A5W4" "$(git -C "$A5W4" rev-parse HEAD)" >/dev/null
git -C "$A5CAN" merge -q "work/$A5WI4-a5c" -m "merge $A5WI4"
rm -rf "$A5W4"
cp "$A5S" "$A5S.bak"; printf 'not json' > "$A5S"
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI4"
t_assert_rc 8 "L6: an unreadable state file refuses the cleanup"
t_assert_contains "$T_OUT" "cannot read work item" "L6: ...as the READ error it is, not as an empty record"
t_assert_eq "present" "$(git -C "$A5CAN" show-ref --verify --quiet "refs/heads/work/$A5WI4-a5c" && echo present || echo gone)" "L6: ...the branch survives - nothing was cleared"
mv "$A5S.bak" "$A5S"
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI4"
t_assert_rc 0 "L6 control: with the state readable the same cleanup succeeds"
t_assert_eq "gone" "$(git -C "$A5CAN" show-ref --verify --quiet "refs/heads/work/$A5WI4-a5c" && echo present || echo gone)" "L6 control: ...and the merged branch is deleted"
# L6b: a VALID state that records no branch for the item is a refusal too -
# the record cannot say what it is cleaning, and the silent-empty branch is
# exactly the shape this closes.
A5WI5="$(oss_entity_add_work_item "$A5S" "$A5SP" "t5" canonical)"
A5W5="$(oss_worktree_add canonical "$A5WI5" "a5d" HEAD)"; rm -rf "$A5W5"
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI5"
t_assert_rc 8 "L6b: a missing branch record refuses the cleanup"
t_assert_contains "$T_OUT" "records no branch" "L6b: ...naming it"

# --- #673 round 4 (U-15p): cleanup deletes the RECORDED branch, never the ---
# live HEAD's. A worktree switched off its branch made the old live-HEAD read
# delete a branch this item does not own - or, detached, delete NOTHING while
# the recorded branch survived and close marked the spine closed. Both shapes
# run through the DISPATCHER, so the strict-mode path is exercised too.
A5WI6="$(oss_entity_add_work_item "$A5S" "$A5SP" "t6" canonical)"
A5W6="$(oss_worktree_add canonical "$A5WI6" "r4-switch" HEAD)"
echo s > "$A5W6/s"; git -C "$A5W6" add s; git -C "$A5W6" commit -qm r4s
oss_entity_set_work_item_exec "$A5S" "$A5WI6" "work/$A5WI6-r4-switch" "$A5W6" "$(git -C "$A5W6" rev-parse HEAD)" >/dev/null
git -C "$A5CAN" merge -q "work/$A5WI6-r4-switch" -m "merge $A5WI6"
git -C "$A5W6" checkout -q -B r4-foreign     # switched OFF its recorded branch
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI6"
t_assert_rc 0 "R4-1: a worktree switched off its branch still cleans up (rc 0)"
[ -d "$A5W6" ] && { T_FAIL=$((T_FAIL+1)); echo "FAIL: R4-1: the worktree survived the cleanup"; } || T_PASS=$((T_PASS+1))
t_assert_eq "gone" "$(git -C "$A5CAN" show-ref --verify --quiet "refs/heads/work/$A5WI6-r4-switch" && echo present || echo gone)" "R4-1: ...the RECORDED branch is deleted"
t_assert_eq "present" "$(git -C "$A5CAN" show-ref --verify --quiet "refs/heads/r4-foreign" && echo present || echo gone)" "R4-1: ...and the branch the live HEAD named survives untouched"
# Detached variant: HEAD names no branch at all; the recorded branch must
# still be the one deleted (the old read returned the literal `HEAD` and
# deleted nothing, silently).
A5WI7="$(oss_entity_add_work_item "$A5S" "$A5SP" "t7" canonical)"
A5W7="$(oss_worktree_add canonical "$A5WI7" "r4-detach" HEAD)"
echo d > "$A5W7/d"; git -C "$A5W7" add d; git -C "$A5W7" commit -qm r4d
oss_entity_set_work_item_exec "$A5S" "$A5WI7" "work/$A5WI7-r4-detach" "$A5W7" "$(git -C "$A5W7" rev-parse HEAD)" >/dev/null
git -C "$A5CAN" merge -q "work/$A5WI7-r4-detach" -m "merge $A5WI7"
git -C "$A5W7" checkout -q --detach
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI7"
t_assert_rc 0 "R4-2 (detached HEAD): the cleanup still runs rc 0"
t_assert_eq "gone" "$(git -C "$A5CAN" show-ref --verify --quiet "refs/heads/work/$A5WI7-r4-detach" && echo present || echo gone)" "R4-2: ...and the RECORDED branch is deleted, not silently kept"


# `main`) must never be deleted by cleanup - the base branch is not ours.
A5WI2="$(oss_entity_add_work_item "$A5S" "$A5SP" "t2" canonical)"
A5DEFLT="$(git -C "$A5CAN" rev-parse --abbrev-ref HEAD)"
oss_entity_set_work_item_exec "$A5S" "$A5WI2" "$A5DEFLT" "$A5CAN/.worktrees/$A5WI2" "$(git -C "$A5CAN" rev-parse HEAD)" >/dev/null
t_capture env OSS_STATE_FILE="$A5S" bash "$OSS" worktree_remove canonical "$A5WI2"
t_assert_rc 0 "A5c: a record naming a foreign branch is left alone"
t_assert_contains "$T_OUT" "not a work/$A5WI2-" "A5c: ...and says so"
t_assert_eq "present" "$(git -C "$A5CAN" show-ref --verify --quiet "refs/heads/$A5DEFLT" && echo present || echo gone)" "A5c: ...the branch still exists"

cd /; rm -rf "$QRT" "$TMP"
t_summary
