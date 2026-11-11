#!/usr/bin/env bash
# PR #703 round 1: fail-closed reads and cleanup paths, through real dispatch.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/lib/blocks.sh"
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"
trap 'find "$TMP" -depth -delete' EXIT
only="${1:-all}"
fixture() {
  F="$TMP/$1"; mkdir -p "$F/ws/.ossify" "$F/core" "$F/ui"
  for repo in core ui; do
    git -C "$F/$repo" init -q -b main
    git -C "$F/$repo" config user.email t@t; git -C "$F/$repo" config user.name t
    echo seed > "$F/$repo/f"; git -C "$F/$repo" add f; git -C "$F/$repo" commit -qm seed
  done
  printf '{"schema_version":1,"repos":{"core":{"root":"%s/core"},"ui":{"root":"%s/ui"}},"well_known_paths":{}}\n' "$F" "$F" > "$F/ws/.ossify/topology.json"
  oss init inv >/dev/null; oss release_add R0 g >/dev/null; oss spine_add r0 Demo bone core >/dev/null
  oss work_item_add r0.s1 One core >/dev/null
  mkdir -p "$F/ws/docs/specs/r0/r0.s1-demo"
}
oss() { (cd "$F/ws" && bash "$OSS" "$@"); }
inventory() { t_capture oss spine_inventory r0.s1; }
verdict() { printf '%s\n' "$T_OUT" | awk -F'\t' -v kind="$1" -v id="$2" -v col="$3" '$1==kind && $2==id {print $col}'; }
healthy() {
  git -C "$F/core" checkout -q -b spine/r0.s1-demo
  oss spine_base_set r0.s1 core main >/dev/null
}
spawn() {
  WT="$(oss worktree_add core r0.s1.w1 one spine/r0.s1-demo)"
  oss work_item_exec r0.s1.w1 work/r0.s1.w1-one "$WT" "$(git -C "$WT" rev-parse HEAD)" >/dev/null
  oss work_item_status r0.s1.w1 active >/dev/null
}
land() {
  echo work > "$WT/work"; git -C "$WT" add work; git -C "$WT" commit -qm work
  git -C "$F/core" merge -q --no-ff work/r0.s1.w1-one -m landing
  oss work_item_status r0.s1.w1 complete >/dev/null
}
if [ "$only" = all ] || [ "$only" = R1 ]; then
  # Physical ref failures: invalid spelling and a valid-looking missing object.
  for site in spine-fresh spine-reentry item; do
    for damage in malformed dangling; do
      fixture "r1-$site-$damage"
      ref=spine/r0.s1-demo
      if [ "$site" != spine-fresh ]; then healthy; fi
      if [ "$site" = item ]; then
        spawn; land; git -C "$F/core" worktree remove "$WT"
        ref=work/r0.s1.w1-one
      elif [ "$site" = spine-reentry ]; then
        oss work_item_add r0.s1 Two ui >/dev/null
        git -C "$F/ui" checkout -q -b spine/r0.s1-demo
        oss spine_base_set r0.s1 ui main >/dev/null
        git -C "$F/core" checkout -q main
      fi
      mkdir -p "$F/core/.git/refs/heads/${ref%/*}"
      if [ "$damage" = malformed ]; then printf 'broken-ref\n'; else printf '%040d\n' 1; fi > "$F/core/.git/refs/heads/$ref"
      inventory
      printf 'R1 %s %s rc=%s: %s\n' "$site" "$damage" "$T_RC" "$T_OUT"
      t_assert_rc 3 "R1 $site $damage halts dispatcher"
      if [ "$site" = item ]; then
        t_assert_eq halt:unreadable "$(verdict item r0.s1.w1 4)" "R1 $damage item ref never skips"
      else
        t_assert_eq halt:unreadable "$(verdict repo core 3)" "R1 $site $damage never reads absent"
      fi
    done
  done
  # Valid absence, presence, and a cleaned item retain their normal routes.
  fixture r1-absent; inventory
  t_assert_rc 0 'R1 absent control succeeds'; t_assert_eq fresh "$(verdict repo core 3)" 'R1 truly absent spine is fresh'
  healthy; inventory
  t_assert_rc 0 'R1 present control succeeds'; t_assert_eq ok "$(verdict repo core 3)" 'R1 present spine is ok'
  spawn; land; git -C "$F/core" worktree remove "$WT"; git -C "$F/core" branch -d work/r0.s1.w1-one >/dev/null
  inventory
  t_assert_rc 0 'R1 post-cleanup control succeeds'; t_assert_eq skip "$(verdict item r0.s1.w1 4)" 'R1 absent item branch still skips'
  # Simulated old Git: only --exists refuses rc129, everything else is real.
  mkdir -p "$TMP/old-git"
  REAL_GIT="$(command -v git)"; export REAL_GIT
  cat > "$TMP/old-git/git" <<'GIT'
#!/usr/bin/env bash
for arg in "$@"; do [ "$arg" != --exists ] || exit 129; done
exec "$REAL_GIT" "$@"
GIT
  chmod +x "$TMP/old-git/git"
  fixture r1-old-absent; PATH="$TMP/old-git:$PATH" inventory
  t_assert_rc 0 'R1 old Git absent control succeeds'; t_assert_eq fresh "$(verdict repo core 3)" 'R1 rc129 fallback reads true absence'
  healthy; spawn; PATH="$TMP/old-git:$PATH" inventory
  t_assert_rc 0 'R1 old Git present control succeeds'; t_assert_eq redispatch "$(verdict item r0.s1.w1 4)" 'R1 rc129 fallback reads present item'
  git -C "$F/core" pack-refs --all --prune; PATH="$TMP/old-git:$PATH" inventory
  t_assert_rc 0 'R1 old Git packed control succeeds'; t_assert_eq ok "$(verdict repo core 3)" 'R1 rc129 fallback reads packed spine'
fi
if [ "$only" = all ] || [ "$only" = R3 ]; then
  for location in conventional recorded; do
    for shape in directory symlink; do
      fixture "r3-$location-$shape"; healthy; spawn; land
      if [ "$location" = conventional ]; then
        git -C "$F/core" worktree move "$WT" "$F/alternate"
        oss work_item_exec r0.s1.w1 work/r0.s1.w1-one "$F/alternate" "$(git -C "$F/core" rev-parse main)" >/dev/null
        occupied="$WT"
      else
        git -C "$F/core" worktree remove "$WT"
        occupied="$F/alternate"
        oss work_item_exec r0.s1.w1 work/r0.s1.w1-one "$occupied" "$(git -C "$F/core" rev-parse main)" >/dev/null
      fi
      if [ "$shape" = directory ]; then mkdir -p "$occupied"; else ln -s "$F/missing" "$occupied"; fi
      inventory
      printf 'R3 %s %s rc=%s: %s\n' "$location" "$shape" "$T_RC" "$T_OUT"
      t_assert_rc 3 "R3 occupied $location $shape halts dispatcher"
      expected=halt:unclassified
      [ "$location" != conventional ] || expected=halt:worktree-held
      t_assert_eq "$expected" "$(verdict item r0.s1.w1 4)" "R3 occupied $location $shape never skips"
    done
  done
  # A live recorded worktree elsewhere also prevents branch deletion when
  # the conventional path is absent: cleanup cannot remove that holder.
  fixture r3-recorded-live; healthy; spawn; land
  git -C "$F/core" worktree move "$WT" "$F/alternate"
  oss work_item_exec r0.s1.w1 work/r0.s1.w1-one "$F/alternate" "$(git -C "$F/core" rev-parse main)" >/dev/null
  inventory
  t_assert_rc 3 'R3 live non-conventional holder halts before cleanup refuses'
  t_assert_eq halt:worktree-held "$(verdict item r0.s1.w1 4)" 'R3 absent conventional path cannot hide a live alternate holder'
  t_capture oss worktree_remove core r0.s1.w1
  t_assert_rc 8 'R3 live alternate holder really makes the owning cleanup refuse'
  # S1: cleanup owns suffix registrations under the recorded root, including
  # a physical alias of that root. The adjacent non-suffix holder still halts.
  for spelling in direct alias; do
    fixture "s1-recorded-root-$spelling"; healthy; spawn; land
    moved="$F/recorded-root/.worktrees/r0.s1.w1"
    mkdir -p "${moved%/*}"
    git -C "$F/core" worktree move "$WT" "$moved"
    recorded="$moved"
    if [ "$spelling" = alias ]; then
      ln -s "$F/recorded-root" "$F/root-alias"
      recorded="$F/root-alias/.worktrees/r0.s1.w1"
    fi
    oss work_item_exec r0.s1.w1 work/r0.s1.w1-one "$recorded" "$(git -C "$F/core" rev-parse main)" >/dev/null
    inventory
    printf 'S1 recorded-root %s rc=%s: %s\n' "$spelling" "$T_RC" "$T_OUT"
    t_assert_rc 0 "S1 recorded-root $spelling live worktree is accepted"
    t_assert_eq skip "$(verdict item r0.s1.w1 4)" "S1 recorded-root $spelling clean merged worktree skips"
    t_capture oss worktree_remove core r0.s1.w1
    t_assert_rc 0 "S1 recorded-root $spelling owning cleanup accepts the same state"
    t_assert_eq no "$(if [ -d "$moved" ]; then echo yes; else echo no; fi)" "S1 recorded-root $spelling cleanup removes the holder"
    t_capture git -C "$F/core" show-ref --verify --quiet refs/heads/work/r0.s1.w1-one
    t_assert_rc 1 "S1 recorded-root $spelling cleanup deletes the merged branch"
    inventory
    t_assert_rc 0 "S1 recorded-root $spelling post-cleanup succeeds"
    t_assert_eq skip "$(verdict item r0.s1.w1 4)" "S1 recorded-root $spelling post-cleanup still skips"
  done
  # A suffix alone is insufficient: a non-suffix record cannot authorize the
  # alternate root, even when its symlink resolves to a suffix registration.
  fixture s1-unowned-suffix; healthy; spawn; land
  moved="$F/other-root/.worktrees/r0.s1.w1"; mkdir -p "${moved%/*}"
  git -C "$F/core" worktree move "$WT" "$moved"
  ln -s "$moved" "$F/alternate"
  oss work_item_exec r0.s1.w1 work/r0.s1.w1-one "$F/alternate" "$(git -C "$F/core" rev-parse main)" >/dev/null
  inventory
  t_assert_rc 3 'S1 suffix outside derived and recorded roots still halts'
  t_assert_eq halt:worktree-held "$(verdict item r0.s1.w1 4)" 'S1 suffix alone never authorizes cleanup'
  t_capture oss worktree_remove core r0.s1.w1
  t_assert_rc 8 'S1 cleanup really refuses the unowned suffix registration'
  # #706: the complete arm decides from the facts cleanup checks. Each shape
  # halts in the read-out AND the owning cleanup really refuses (rc 8).
  mkdir -p "$TMP/failgit-list"
  printf '#!/usr/bin/env bash\ncase " $* " in *" worktree list "*) echo "fatal: simulated worktree list failure" >&2; exit 128;; esac\nexec %s "$@"\n' "$(command -v git)" > "$TMP/failgit-list/git"
  chmod +x "$TMP/failgit-list/git"
  recorded_root() { # live worktree moved to a recorded root, as the S1 pins do
    moved="$F/recorded-root/.worktrees/r0.s1.w1"; mkdir -p "${moved%/*}"
    git -C "$F/core" worktree move "$WT" "$moved"
    oss work_item_exec r0.s1.w1 work/r0.s1.w1-one "$moved" "$(git -C "$F/core" rev-parse main)" >/dev/null
  }
  for shape in foreign-root list-failure locked-recorded; do
    fixture "s6-$shape"; healthy; spawn; land; recorded_root
    case "$shape" in
      foreign-root)
        mkdir -p "$F/other-root/.worktrees"
        git -C "$F/core" worktree add -q --detach "$F/other-root/.worktrees/r0.s1.w1"
        expect_msg="not under this item's root" ;;
      list-failure) expect_msg="cannot read the worktree list" ;;
      locked-recorded) git -C "$F/core" worktree lock "$moved"; expect_msg="locked registration at" ;;
    esac
    if [ "$shape" = list-failure ]; then export PATH="$TMP/failgit-list:$PATH"; fi
    inventory
    printf 'S6 %s rc=%s: %s\n' "$shape" "$T_RC" "$T_OUT"
    t_assert_rc 3 "S6 $shape halts the read-out"
    t_assert_eq halt:worktree-held "$(verdict item r0.s1.w1 4)" "S6 $shape: the read-out names the halt cleanup would refuse"
    t_capture oss worktree_remove core r0.s1.w1
    if [ "$shape" = list-failure ]; then PATH="${PATH#"$TMP/failgit-list:"}"; fi
    t_assert_rc 8 "S6 $shape: the owning cleanup really refuses"
    t_assert_contains "$T_OUT" "$expect_msg" "S6 $shape: cleanup names the same reason"
    t_assert_eq yes "$(if [ -d "$moved" ]; then echo yes; else echo no; fi)" "S6 $shape: cleanup removed nothing"
  done
  # A locked CONVENTIONAL worktree: cleanup's non-forced remove refuses it.
  fixture s6-locked-conventional; healthy; spawn; land
  git -C "$F/core" worktree lock "$WT"
  inventory
  t_assert_rc 3 'S6 locked conventional worktree halts the read-out'
  t_assert_eq halt:worktree-held "$(verdict item r0.s1.w1 4)" 'S6 locked conventional worktree is worktree-held, never skip'
  t_capture oss worktree_remove core r0.s1.w1
  t_assert_rc 8 'S6 locked conventional worktree: the owning cleanup really refuses'
  t_assert_eq yes "$(if [ -d "$WT" ]; then echo yes; else echo no; fi)" 'S6 locked conventional worktree: cleanup removed nothing'
  # The lock check compares physically: a topology root that is a symlink to the real repo
  # must still match git's printed (resolved) registration path.
  fixture s6-locked-conventional-symroot; mv "$F/core" "$F/core-real"; ln -s "$F/core-real" "$F/core"
  healthy; spawn; land; git -C "$F/core" worktree lock "$WT"
  inventory
  t_assert_rc 3 'S6 locked conventional worktree behind a symlinked root halts the read-out'
  t_assert_eq halt:worktree-held "$(verdict item r0.s1.w1 4)" 'S6 locked conventional worktree behind a symlinked root is worktree-held, never skip'
  t_capture oss worktree_remove core r0.s1.w1
  t_assert_rc 8 'S6 locked conventional worktree behind a symlinked root: the owning cleanup really refuses'
  # Cleanup's conv-present arm reads no registration set: a foreign-root extra beside a live conventional worktree still skips.
  fixture s6-conventional-foreign; healthy; spawn; land
  mkdir -p "$F/other-root/.worktrees"; git -C "$F/core" worktree add -q --detach "$F/other-root/.worktrees/r0.s1.w1"
  inventory
  t_assert_rc 0 'S6 control: a foreign extra beside a live conventional worktree does not halt'
  t_assert_eq skip "$(verdict item r0.s1.w1 4)" 'S6 control: ...the conv-present arm checks only that worktree lock'
  # The override reaches only skip/finish-merge: a dirty locked worktree keeps its own halt.
  fixture s6-dirty-locked; healthy; spawn; land
  echo dirty > "$WT/dirty"; git -C "$F/core" worktree lock "$WT"
  inventory
  t_assert_eq halt:dirty-worktree "$(verdict item r0.s1.w1 4)" 'S6 control: a dirty locked worktree keeps halt:dirty-worktree, not worktree-held'
  # An unreadable list also halts a conventional-path item (the read-out cannot
  # show cleanup would pass); cleanup itself has no list read on this arm.
  fixture s6-list-failure-conventional; healthy; spawn; land
  PATH="$TMP/failgit-list:$PATH" inventory
  t_assert_rc 3 'S6 conventional worktree with an unreadable list halts the read-out'
  t_assert_eq halt:worktree-held "$(verdict item r0.s1.w1 4)" 'S6 conventional worktree with an unreadable list is worktree-held'
  fixture r3-live; healthy; spawn; land; inventory
  t_assert_rc 0 'R3 live clean merged control succeeds'; t_assert_eq skip "$(verdict item r0.s1.w1 4)" 'R3 live clean merged worktree still skips'
  # Alias spelling of the SAME linked worktree remains valid.
  ln -s "$F/core" "$F/core-alias"
  oss work_item_exec r0.s1.w1 work/r0.s1.w1-one "$F/core-alias/.worktrees/r0.s1.w1" "$(git -C "$F/core" rev-parse main)" >/dev/null
  inventory
  t_assert_rc 0 'R3 physical-path alias control succeeds'; t_assert_eq skip "$(verdict item r0.s1.w1 4)" 'R3 same live worktree with alias spelling still skips'
  git -C "$F/core" worktree remove "$WT"; git -C "$F/core" branch -d work/r0.s1.w1-one >/dev/null; inventory
  t_assert_rc 0 'R3 post-cleanup control succeeds'; t_assert_eq skip "$(verdict item r0.s1.w1 4)" 'R3 truly post-cleanup item still skips'
fi
if [ "$only" = all ] || [ "$only" = R5 ]; then
  fixture r5-state-read
  oss_block_extract "$HERE/../skills/work-item/references/round-orchestration.md" repo_bases "$TMP/fresh.sh" || exit 1
  mkdir -p "$TMP/shim" "$TMP/temporaries"
  cat > "$TMP/shim/oss" <<'OSS'
#!/usr/bin/env bash
case "$1" in
  get) [ "${FAIL_GET:-}" != yes ] || { echo 'injected get rc2' >&2; exit 2; }; echo core ;;
  branch_name) echo spine/r0.s1-demo ;;
  repo_root) echo "$FIXTURE_ROOT" ;;
  spine_base_set) echo RECORD >> "$RECORD" ;;
  *) exit 2 ;;
esac
OSS
  chmod +x "$TMP/shim/oss"
  fresh() {
    env FAIL_GET="$1" FIXTURE_ROOT="$F/core" RECORD="$TMP/record" PATH="$TMP/shim:$PATH" TMPDIR="$TMP/temporaries" \
      bash -c 'set -eu; set +o pipefail; . "$1"' fresh "$TMP/fresh.sh"
  }
  # No caller pipefail: the fence owns the state-read rc itself.
  t_capture fresh yes
  printf 'R5 failed state read rc=%s: %s\n' "$T_RC" "$T_OUT"
  t_assert_rc 1 'R5 failed state read halts alone in a fresh shell without pipefail'
  t_assert_contains "$T_OUT" 'halt: cannot read' 'R5 failed state read names halt'
  t_assert_eq no "$(if [ -e "$TMP/record" ]; then echo yes; else echo no; fi)" 'R5 failed state read never RECORDs'
  t_assert_eq 0 "$(find "$TMP/temporaries" -type f | wc -l | tr -d ' ')" 'R5 halt removes both owned temp files'
  t_capture fresh no
  t_assert_rc 0 'R5 valid state control succeeds in fresh shell'
  t_assert_eq RECORD "$(cat "$TMP/record")" 'R5 valid state still RECORDs'
  t_assert_eq spine/r0.s1-demo "$(git -C "$F/core" rev-parse --abbrev-ref HEAD)" 'R5 valid state still cuts branch'
  t_assert_eq 0 "$(find "$TMP/temporaries" -type f | wc -l | tr -d ' ')" 'R5 success removes both owned temp files'
fi
t_summary
