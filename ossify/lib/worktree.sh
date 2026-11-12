#!/usr/bin/env bash
# Per-work-item worktrees. rc 8 = git/worktree operation failure (see the plan's
# rc-taxonomy note); rc 2 = usage / unknown repo key; rc 1 = not found.
#
# D4: every entry point takes a REPO KEY as its first argument. `target_repo`
# has been written into state since B4 with no reader; this is its first.
# #272/#310 generalized `_oss_repo_root` to resolve any repo the manifest
# declares, not `canonical` alone - every call site and path-shape assertion
# in this file already took the parameter, so that generalization needed no
# signature change here.

_oss_repo_root() { # $1=repo-key
  local key root shape
  if [ -z "${1:-}" ]; then key="$(_oss_default_repo_key)" || return $?; else key="$1"; fi
  shape="$(_oss_shape_file)" || return 1
  if [ "$key" = "ai_workspace" ]; then
    root="$(printf '%s' "$shape" | jq -r '.workspace // empty')"
  else
    _oss_repo_key_valid "$key" || {
      echo "oss: invalid repo key '$key' - names match [a-z][a-z0-9_-]* (ai_workspace is reserved)" >&2; return 2; }
    root="$(printf '%s' "$shape" | jq -r --arg k "$key" '.repos[$k].root // empty')"
    # An unconfigured key must NOT fall back to canonical: silently building a
    # private_core worktree inside the public repo is precisely the leak the
    # companion spec exists to prevent.
    if [ -z "$root" ] || [ "$root" = "null" ]; then
      echo "oss: repo '$key' is not declared (declared: $(printf '%s' "$shape" | jq -r '.repos | keys | join(", ")'))" >&2; return 2
    fi
  fi
  # This is a RAW jq read off the shape, so a repo root stored as
  # `${HOME}/workspace` returns the token verbatim. Every consumer treats this
  # as an absolute path — `oss release_dir` composes on it, worktree paths are
  # built from it — so an unresolved token becomes a relative-looking path that
  # resolves against the caller's cwd and writes artifacts in the wrong place.
  # Resolve here, once, against the shape's own workspace root - $shape already
  # carries it (topology-declared, or translated from a pairing manifest), so
  # this does not re-discover a manifest of its own - and refuse anything still
  # holding a `${...}` rather than handing a caller a path that only looks
  # absolute.
  #
  # Unconditional as of Task 3 (#272/#310): the call used to be gated behind a
  # `*'${'*)` case, because `_oss_manifest_resolve` required
  # `.workspace/pairing.json` to exist even for a token-free string, which
  # refused every topology-only lookup outright. Task 3 made the resolver
  # source its vocabulary from the shape instead of re-discovering a pairing
  # manifest, so a plain literal root - the common case - now passes through
  # as a no-op (the substitution loop only replaces what actually appears in
  # the string) rather than failing. MEASURED, not assumed: the full suite
  # (`bash tests/run-all.sh`, 1418 assertions) was run once with the old gate
  # in place and once with it removed - identical ALL GREEN both times - before
  # this simplification was kept.
  local ai_root; ai_root="$(printf '%s' "$shape" | jq -r '.workspace // empty')"
  root="$(_oss_manifest_resolve "$ai_root" "$root")" || return 1
  # Mirrors `_oss_manifest_wellknown_guard` (#165) and shares its grammar test, so
  # the two refusals cannot drift the way their wording already did. Same reasoning:
  # the token is documented workspace-init vocabulary that ossify deliberately does
  # not resolve (#152), so the generic "unresolved token" wording reads as a typo and
  # sends the operator to workspace-init's docs, where it is legal - away from the fix.
  # A MALFORMED PLUGIN_DATA spelling is a typo and correctly falls through to the
  # generic arm below.
  if _oss_is_plugin_data_token "$root"; then
    echo "oss: repo '$key' root uses \${PLUGIN_DATA:...}, which ossify does not resolve - route it with \${ai_workspace.root}, \${canonical.root}, \${HOME}, \${USER}, or an absolute path: '$root'" >&2
    return 2
  fi
  case "$root" in
    *'${'*) echo "oss: repo '$key' root has an unresolved token: '$root'" >&2; return 2 ;;
    /*) ;;
    *) echo "oss: repo '$key' root is not absolute: '$root'" >&2; return 2 ;;
  esac
  printf '%s\n' "$root"
}

# `oss_worktree_dir` was REMOVED in v0.2.0: built in Plan C1 and never called by
# the dispatcher, another lib, a test, or any prose. Every consumer that needs
# the path composes it from `_oss_repo_root` inline, which is what the functions
# below do.

# The work-item id is the last component of every path this file builds
# (`<root>/.worktrees/<wi>`), so it must be an id and nothing else (#120). An
# unchecked `../../victim` resolved to a sibling worktree OUTSIDE .worktrees, and
# worktree_remove then removed it and deleted its merged branch. The grammar has
# no `/` and no `..`, so a valid id cannot leave the directory; lib/id.sh is the
# one owner of that grammar.
_oss_worktree_id_check() { # $1=work-item-id ; rc 0 valid, rc 2 refused
  oss_id_valid_work_item "$1" && return 0
  echo "oss: '$1' is not a work-item id (r<N>.s<N>.w<N>) - refusing to build a worktree path from it" >&2
  return 2
}

oss_worktree_add() { # $1=repo-key $2=work-item-id $3=slug $4=base-ref ; echoes abs path
  local key="$1" wi="$2" root cd lock rc=0
  _oss_worktree_id_check "$wi" || return $?
  root="$(_oss_repo_root "$key")" || return $?
  # One add per work item at a time (PR #601 review). The rollback below removes
  # what the failed call created, and "created" is only knowable if no other
  # add for the same id runs between the existence checks and the rollback:
  # otherwise the loser of two concurrent adds sees the WINNER's worktree and
  # branch, and `--force` removes them with whatever the winner has written.
  # `mkdir` is the atomic test-and-set; the lock lives in the git common dir, not
  # under .worktrees, where worktree_orphans would report it.
  cd="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || { echo "oss: cannot resolve git common dir for $root" >&2; return 8; }
  lock="$cd/ossify-worktree-add.$wi.lock"
  mkdir "$lock" 2>/dev/null || {
    echo "oss: another worktree_add for $wi is running (lock $lock) - if none is, remove the lock with: rmdir $(printf '%q' "$lock")" >&2
    return 8; }
  _oss_worktree_add_locked "$root" "$wi" "$3" "${4:-HEAD}" || rc=$?
  rmdir "$lock" 2>/dev/null || true
  return "$rc"
}

_oss_worktree_add_locked() { # $1=root $2=work-item-id $3=slug $4=base-ref ; echoes abs path
  local root="$1" wi="$2" slug="$3" base="$4" dir path branch base_sha had_branch=0
  dir="$root/.worktrees"; path="$dir/$wi"
  branch="$(oss_id_work_item_branch "$wi" "$slug")"
  [ -e "$path" ] && { echo "oss: worktree already exists at $path" >&2; return 8; }
  mkdir -p "$dir" || return 8
  _oss_worktree_ignore "$root" || true
  # Before-state for the rollback below (#122). The path was just checked absent;
  # the branch and the base commit are recorded here so a rollback never removes
  # anything this call did not create.
  if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then had_branch=1; fi
  base_sha="$(git -C "$root" rev-parse --verify --quiet "$base^{commit}" 2>/dev/null)" || base_sha=""
  # NOT `2>&1`: this function's STDOUT IS ITS RETURN VALUE (the abs path), so
  # merging git's stderr into stdout makes any warning git decides to emit become
  # part of the path the caller captures. `-q` is silent on success today, which
  # is exactly what makes this the kind of latent bug that surfaces years later
  # on someone else's git version or with a chatty hook installed. Let stderr be
  # stderr.
  if ! git -C "$root" worktree add -q -b "$branch" "$path" "$base"; then
    echo "oss: git worktree add failed for $wi (branch $branch, base $base)" >&2
    _oss_worktree_add_rollback "$root" "$path" "$branch" "$had_branch" "$base_sha" || true
    return 8
  fi
  printf '%s\n' "$path"
}

# #122: `git worktree add` can fail AFTER it has created the worktree and the
# branch - a post-checkout hook that exits nonzero is enough - and the
# already-exists guard above then refused every retry, so the work item could
# not be spawned again without hand repair. Undo exactly what the call created:
#   - the worktree at the path the guard proved absent before the call. `--force`
#     because a failing checkout hook may have left files in it, and nothing in
#     it predates the call. `git worktree remove` refuses a directory that is not
#     a registered worktree, so this cannot delete anything else - and it is
#     asked by path rather than matched against `worktree list`, which prints
#     the symlink-resolved path (macOS /tmp) and would not match.
#   - the branch, only if it did not exist before the call AND still points at
#     the base commit, so no commit can be lost. `-D` because `-d` measures
#     merged-ness against the root's HEAD, which a spine-branch base need not be
#     merged into; the tip check is what makes the force safe.
# Whatever cannot be undone safely is left in place and named, with the command
# that finishes the repair. rc 0 rolled back (or nothing to undo), rc 8 not.
_oss_worktree_add_rollback() { # $1=root $2=path $3=branch $4=had-branch(0|1) $5=base-sha
  local root="$1" path="$2" branch="$3" had="$4" base_sha="$5" tip left="" undone="" qr qp qb
  # Repair commands are printed for copying, so every interpolated value is
  # shell-quoted: a path or a branch slug may hold a quote or a metacharacter.
  qr="$(printf '%q' "$root")"; qp="$(printf '%q' "$path")"; qb="$(printf '%q' "$branch")"
  if [ -e "$path" ]; then
    git -C "$root" worktree remove --force "$path" >/dev/null 2>&1 && undone="$undone worktree" \
      || left="$left $path (inspect it; if it is the new worktree: git -C $qr worktree remove --force $qp);"
  fi
  if [ "$had" = 0 ] && git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
    tip="$(git -C "$root" rev-parse --verify --quiet "refs/heads/$branch" 2>/dev/null)" || tip=""
    if [ -n "$base_sha" ] && [ "$tip" = "$base_sha" ]; then
      git -C "$root" branch -D "$branch" >/dev/null 2>&1 && undone="$undone branch" \
        || left="$left branch $branch (git -C $qr branch -D $qb);"
    else
      left="$left branch $branch, which no longer points at the base - inspect it before deleting;"
    fi
  fi
  if [ -n "$left" ]; then
    echo "oss: the failed add left state behind that was not rolled back:$left the work item cannot be spawned again until it is gone" >&2
    return 8
  fi
  # Say so only when something was undone: a failure before git created
  # anything (an existing branch, a bad base) has nothing to roll back.
  [ -z "$undone" ] || echo "oss: rolled back the partial add (removed:$undone) - fix the cause above and retry" >&2
}

# #133: re-attach a work item's worktree whose DIRECTORY is gone but whose
# branch still holds the item's work. `git worktree add -b` cannot (the branch
# exists), and a plain add refuses while git still registers the deleted path -
# so the registrations of THIS branch are inspected first:
#   - a LIVE holder (its directory exists) is the branch in use somewhere else:
#     refuse rc 8, never touch it;
#   - a dead registration for THIS item's own path (`…/.worktrees/<wi>`, under
#     whatever root spelling recorded it) is a stale entry, cleared with `git
#     worktree remove` - rc 0 on a missing directory, measured; nothing is
#     pruned, because a sibling's stale registration is another item's evidence;
#   - a dead registration at any OTHER path belongs to something else: refuse.
# Then the add is PLAIN - no `-f`. `-f` is what used to leave a second holder
# behind (#673 E1): a pre-existing dead registration was overridden rather than
# cleared, the old holder stayed registered, and every later reattach refused
# rc 8 with no sanctioned recovery. A failed add is rolled back with the same
# helper `_oss_worktree_add` uses, preserving the pre-existing branch (#673 E2):
# a checkout hook that exits nonzero after registering the path must not leave
# a live-looking worktree that wedges the retry.
oss_worktree_reattach() { # $1=repo-key $2=wi-id $3=branch ; echoes abs path
  local key="$1" wi="$2" branch="$3" root cd lock rc=0
  _oss_worktree_id_check "$wi" || return $?
  root="$(_oss_repo_root "$key")" || return $?
  cd="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || { echo "oss: cannot resolve git common dir for $root" >&2; return 8; }
  lock="$cd/ossify-worktree-add.$wi.lock"
  mkdir "$lock" 2>/dev/null || {
    echo "oss: another worktree operation for $wi is running (lock $lock) - if none is, remove the lock with: rmdir $(printf '%q' "$lock")" >&2
    return 8; }
  _oss_worktree_reattach_locked "$root" "$wi" "$branch" || rc=$?
  rmdir "$lock" 2>/dev/null || true
  return "$rc"
}

_oss_worktree_reattach_locked() { # $1=root $2=wi-id $3=branch ; echoes abs path
  local root="$1" wi="$2" branch="$3" path holders n hp hl
  path="$root/.worktrees/$wi"
  [ -e "$path" ] && { echo "oss: $path exists - there is nothing to reattach" >&2; return 8; }
  git -C "$root" show-ref --verify --quiet "refs/heads/$branch" \
    || { echo "oss: branch '$branch' does not exist in $root - reattach cannot recover this item's work" >&2; return 8; }
  # Every registered worktree holding this branch, with whether git marks it
  # locked. The lock flag is read at the END of the entry, not when the branch
  # line goes by: `locked` FOLLOWS `branch` in the porcelain, so the obvious
  # read-at-branch form always sees lk=0 and leaves the locked arm below
  # unreachable - measured on git 2.53.0 (worktree, HEAD, branch, locked). A
  # locked registration then falls through to git's own refusal, whose message
  # advertises `add -f -f` - the one hint this function exists to avoid.
  holders="$(git -C "$root" worktree list --porcelain | awk -v b="refs/heads/$branch" '
    /^worktree /{if (hit) print p "\t" lk; p=substr($0,10); lk=0; hit=0; next}
    /^locked/{lk=1; next}
    $0=="branch " b {hit=1}
    END{if (hit) print p "\t" lk}')" || {
      # #673 G1's old form (`|| holders=""`), closed here too: an unreadable
      # list is not an empty one. A hidden live or locked holder would only
      # be re-discovered by git's own refusal one step later - or, worse,
      # overridden by the plain add below.
      echo "oss: cannot read the worktree list for $root - refusing to reattach $wi" >&2
      return 8; }
  n="$(printf '%s' "$holders" | awk 'END{print NR}')"
  if [ "$n" -gt 0 ]; then
    # PASS 1 - inspect and validate EVERY holder; mutate nothing (#673 I1).
    # The pre-fix loop removed each dead entry as it validated it, so with an
    # unlocked registration ahead of a locked one it cleared the unlocked
    # entry and THEN refused rc 8 on the lock - mutating Git metadata while
    # promising to leave the stale entries as found.
    while IFS="$(printf '\t')" read -r hp hl; do
      [ -n "$hp" ] || continue
      if [ -e "$hp" ]; then
        echo "oss: branch '$branch' is checked out at $hp - not this item's missing worktree; refusing" >&2
        return 8
      fi
      [ "$hl" = 0 ] || { echo "oss: the stale registration at $hp is locked - unlock it with git worktree unlock first" >&2; return 8; }
      case "$hp" in
        */.worktrees/"$wi") ;;
        *) echo "oss: branch '$branch' is held by a stale registration at $hp - not this item's missing worktree (…/.worktrees/$wi); refusing" >&2; return 8 ;;
      esac
    done <<HOLD
$holders
HOLD
    # PASS 2 - the whole set is acceptable; only now clear the dead entries,
    # so the add below can be plain and cannot mint a second holder.
    while IFS="$(printf '\t')" read -r hp hl; do
      [ -n "$hp" ] || continue
      git -C "$root" worktree remove "$hp" \
        || { echo "oss: cannot clear the stale registration at $hp - git worktree remove failed" >&2; return 8; }
    done <<HOLD
$holders
HOLD
  fi
  git -C "$root" worktree add -q "$path" "$branch" \
    || { echo "oss: git worktree add failed reattaching $wi on $branch" >&2
         _oss_worktree_add_rollback "$root" "$path" "$branch" 1 "" || true
         return 8; }
  printf '%s\n' "$path"
}

# The worktree root lives INSIDE the repo, so without this every spawn leaves
# `?? .worktrees/` in that repo's status - a dirty tree ossify itself
# created, in the very repo whose cleanliness the close ceremony checks. The
# leading dot already keeps most test runners out (pytest's default
# `norecursedirs` includes `.*`; `go test ./...` skips dirs beginning with `.`
# or `_`), so this closes the reporting half, not a demo-integrity hole.
#
# `.git/info/exclude`, NOT `.gitignore` - and this was verified empirically, not
# reasoned about. `.gitignore` is TRACKED in any real project, so appending to it
# leaves ` M .gitignore` and produces exactly the dirty tree this exists to
# prevent (measured: appending to a tracked .gitignore yields ` M .gitignore`;
# writing to .git/info/exclude yields an EMPTY status). `info/exclude` is
# repo-local, never tracked, never pushed, and is the idiomatic place for an
# ignore the tool owns rather than the project. Never edit a file the project
# owns to make a tool's own artifact disappear.
_oss_worktree_ignore() { # $1=repo-root ; best-effort, never fatal
  # Resolve the real git common dir rather than assuming `.git` is a directory.
  # A repo created with `git init --separate-git-dir` (or a submodule) has a
  # `.git` FILE pointing elsewhere — its info/exclude lives at the common dir,
  # not at `$1/.git/info/exclude`. The old `[ -d "$1/.git" ] || return 0`
  # guard skipped those repos, leaving `.worktrees/` permanently un-excluded
  # and that repo's tree dirty on every spawn. (Codex P2 finding #5.)
  local cd
  cd="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || { echo "oss: cannot resolve git common dir for $1 - .worktrees/ not excluded" >&2; return 1; }
  local ex="$cd/info/exclude"
  mkdir -p "$cd/info" || return 1
  [ -f "$ex" ] && grep -qxF '.worktrees/' "$ex" && return 0
  printf '%s\n' '.worktrees/' >> "$ex" 2>/dev/null || return 1
}

oss_worktree_resolve() { # $1=repo-key $2=work-item-id
  local root path
  _oss_worktree_id_check "$2" || return $?
  root="$(_oss_repo_root "$1")" || return $?
  path="$root/.worktrees/$2"
  [ -d "$path" ] || { echo "oss: no worktree for '$2' under $root/.worktrees" >&2; return 1; }
  printf '%s\n' "$path"
}

# Orphan detection - the ONE real use of the enumeration verb v0.2 retired (see
# the `oss_cmd_worktree_list` tombstone in lib/commands.sh, which named this
# requirement and said to build the primitive against it rather than before it).
#
# This is deliberately NOT that verb rebuilt. The tombstone's objection to
# enumeration was that a filesystem listing "answers a question no ceremony asks
# and can disagree with state". Both halves still hold - so what ships is the
# DISAGREEMENT ITSELF: the set of directories under <repo>/.worktrees that no
# work item in state claims. That set is the finding, and it is the only form of
# the question `doctor` has to ask.
#
# A directory is CLAIMED when a work item's journaled `worktree_path` is exactly
# it, or when its basename is a work item's id. The second arm is not slack.
# `oss_worktree_add` names the directory for its work item, but nothing writes
# `worktree_path` into state until `work_item_exec` journals one - so matching on
# the path alone reports every freshly-spawned worktree as an orphan, i.e. it is
# loudest precisely when the project is behaving correctly.
#
# PURE SELECTOR: the finding is the OUTPUT, never the rc. rc 0 means the check
# RAN, not that the tree is clean; a caller branching on rc reports every project
# as orphan-free. That is the same polarity the doctor SURFACE uses for
# quarantines, fakes and patch records - counted, surfaced as `warn:`, never
# folded into an exit code. (Those were doctor.sh checks until PR #184 slimmed
# the verb to its gate; they are skill prose now, and the polarity travelled with
# them.) It deliberately does NOT copy `oss touch_check`'s rc-0-is-a-hit
# polarity, which close/SKILL.md §7 already lists as a trap for exactly this
# reason.
oss_worktree_orphans() { # $1=repo-key [$2=state-file] ; echoes one abs path per orphan
  local key root sf dir path default_key
  if [ -z "${1:-}" ]; then key="$(_oss_default_repo_key)" || return $?; else key="$1"; fi
  root="$(_oss_repo_root "$key")" || return $?
  sf="$(_oss_resolve_state "${2:-}")" || return $?
  [ -f "$sf" ] || { echo "oss: state file not found at $sf" >&2; return 1; }
  # Parse the state ONCE, up front, and fail loudly if it does not parse.
  # Without this the per-directory `jq -e … || printf` treats a PARSE ERROR
  # (jq rc 5) exactly like a false predicate, so a corrupt state file makes
  # every worktree look orphaned - and `oss doctor` then stacks a
  # deletion-flavoured warning on top of the corrupt-state finding that is the
  # real problem. A selector that cannot read its input has not found zero
  # matches; it has failed. (Codex P2, PR #149.)
  # Two structural preconditions, both checked ONCE up front, because the
  # per-directory predicate below cannot tell an evaluation ERROR from a false
  # result - `jq -e … || printf` reports "unclaimed" for both.
  #
  #   1. the file parses at all (malformed JSON: jq rc 5);
  #   2. `.work_items` is an ARRAY. A parseable, replay-consistent state whose
  #      `.work_items` is a string or object makes jq error while iterating, so
  #      every directory reports as orphaned and the selector still exits 0 -
  #      the same deletion-flavoured false positive as (1), reached from a state
  #      that (1) happily accepts. `// []` does not cover this: a string is
  #      truthy, so the alternative never fires.
  # (Codex P2, PR #149 rounds 1 and 3.)
  jq -e . "$sf" >/dev/null 2>&1 || {
    echo "oss: state file at $sf is not valid JSON - cannot tell an orphan from a claimed worktree" >&2
    return 1
  }
  # `.work_items` shape is NOT checked here. It is validated inside the single
  # jq expression below, together with the computation it guards - see the note
  # there for why splitting them was the thing that kept going wrong.
  # A CONFIGURED ROOT THAT DOES NOT EXIST HAS NOT BEEN INSPECTED, and must not
  # reach the early return below. `_oss_repo_root` validates the manifest VALUE
  # - non-empty, token-free, absolute - but never that the directory is
  # there, so an unmounted volume or a moved repo resolved cleanly, failed
  # `[ -d "$dir" ]`, and exited 0 with no output. That is indistinguishable from
  # "inspected, nothing orphaned", and it violates this function's own contract
  # that rc 0 means the check RAN. `oss doctor` printed
  # `ok: worktrees(private_core) - none orphaned` about a repository absent from
  # the machine - the same false assurance #156 fixed, one level in, and
  # reachable on every repo key at once. (Codex P1, PR #160.)
  #
  # rc 2 deliberately: this is the same "cannot use this repo" class as an
  # unconfigured key, so every caller that already handles `_oss_repo_root`'s
  # rc 2 handles this with no new branch - including doctor's skip arm.
  [ -d "$root" ] || { echo "oss: repo '$key' root does not exist at $root" >&2; return 2; }
  # EXISTS is not the same as CAN BE INSPECTED, and the difference is invisible
  # to `-d`. On a root the caller cannot traverse, `[ -d "$root" ]` is TRUE while
  # `[ -d "$root/.worktrees" ]` is FALSE - not because the directory is absent
  # but because the stat cannot be performed - so a private checkout mounted
  # with restrictive permissions walked past the guard above straight into the
  # "nothing spawned yet" arm and reported clean. (Measured: with mode 000,
  # `-d root` true, `-x root` false, `-d root/.worktrees` false while the
  # directory demonstrably exists.) Same false-clean class as a missing root,
  # reached by permissions instead of absence. (Codex, PR #160 round 2.)
  #
  # EXECUTE ONLY, deliberately. This guard first demanded `-r` as well, and that
  # was an OVER-CORRECTION: reaching `$root/.worktrees` needs TRAVERSAL, while
  # read on the root is what LISTING the root would need - and this selector
  # never lists the root, it composes the `.worktrees` path directly. So a
  # mode-0111 root is fully inspectable and was being skipped. (Measured
  # 2026-08-13: at 0111, `-x root` true, `-r root` FALSE, `-d root/.worktrees`
  # true, and the orphan under it enumerable.) A false SKIP is milder than the
  # false CLEAN above - it says "did not look", which is honest - but it still
  # stops doctor reporting genuine orphans on a repo it can read. #162, from the
  # Codex review that landed six minutes after PR #160 merged.
  #
  # The minimum each operation actually needs is the rule here: traversal on the
  # root, read AND traversal on `.worktrees`, which is the directory enumerated.
  [ -x "$root" ] \
    || { echo "oss: repo '$key' root at $root cannot be traversed (permissions)" >&2; return 2; }
  dir="$root/.worktrees"
  # Nothing spawned yet is not a finding. Reachable only once the root above is
  # known to exist AND to be traversable, which is what keeps this arm meaning
  # what it says rather than absorbing two different failures.
  [ -d "$dir" ] || return 0
  # The same distinction one level down: `.worktrees` itself can be unreadable
  # while `-d` succeeds through the parent's execute bit. The glob below would
  # then match nothing, leave `cands` empty, and return 0 - clean, from a
  # directory never listed.
  { [ -x "$dir" ] && [ -r "$dir" ]; } \
    || { echo "oss: repo '$key' worktree dir at $dir cannot be read (permissions)" >&2; return 2; }

  local -a cands=()
  for path in "$dir"/*; do
    # An unmatched glob leaves the PATTERN itself as the single iteration value;
    # `-d` rejects it. `nullglob` would be tidier and is deliberately not set -
    # it is a shell-wide option and every other function the dispatcher sources
    # was written without it, so turning it on here changes their behaviour too.
    [ -d "$path" ] || continue
    cands+=("$path")
  done
  # Guarded BEFORE expansion: under `set -u`, bash 3.2 errors on "${a[@]}" for an
  # empty array, and bash 3.2 is what macOS ships.
  [ "${#cands[@]}" -gt 0 ] || return 0

  # ONE jq invocation over the whole candidate set - not one per directory, and
  # this shape is the fix for a CLASS rather than for a case.
  #
  # The previous form ran `jq -e … || printf` per directory, and that `||`
  # cannot distinguish jq returning FALSE (this directory is unclaimed: a
  # finding) from jq ERRORING (the state could not be inspected: not a finding).
  # So every malformed shape reported EVERY directory as an orphan, at rc 0,
  # with a deletion-flavoured message. It was patched three times for three
  # shapes - malformed JSON, a non-array `.work_items`, a non-object element -
  # and a fourth shape would have done it again.
  #
  # With a single call, jq's exit status IS the error signal, once: rc 0 means
  # the claims were inspected and the output is the finding; nonzero means they
  # were not, and NOTHING is reported.
  #
  # Validation lives in the same expression as the computation, deliberately.
  # Splitting them into separate bash pre-guards is what kept going wrong: each
  # guard covered the one shape that had just been reported, and the next shape
  # walked straight past all of them into the `||`. Here the shape checks
  # `error()` out through the same channel the computation uses, so an
  # unvalidated shape cannot reach the finding path at all - and a junk record
  # is REFUSED rather than silently skipped, because "some records are garbage"
  # is not evidence that a directory is unclaimed.
  #
  # SCOPED TO THIS REPO KEY. Without the `target_repo` filter, a private_core
  # work item whose id happens to be `r0.s1.w1` makes
  # `canonical/.worktrees/r0.s1.w1` look claimed - which suppresses exactly the
  # wrong-repository directory the repo-key design exists to expose, and in the
  # worst case leaves private work sitting under the public canonical root.
  # Items predating the field default to the sole-repo default rule's answer,
  # matching how `oss_cmd_work_item_add` defaults it (#272/#310 Task 4 - was a
  # literal `canonical`).
  #
  # LAZY, deliberately: `default_key` is only needed when some record actually
  # lacks `target_repo` - never, for anything written since #272/#310 Task 4,
  # because `oss_entity_add_work_item` now always fills the field (explicit or
  # resolved). Computing it UNCONDITIONALLY would make every orphan check
  # refuse outright under N>1 declared repos, even one scoped to a perfectly
  # valid EXPLICIT key with no legacy record in sight - the declared-membership
  # check above already proved `$key` is real; ambiguity in the DEFAULT must
  # not veto a call that never asked for the default. (Measured: this broke
  # `private_core`-scoped orphan detection under the two-repo PRIV/QRT fixtures
  # in test-worktree.sh when implemented as the brief's literal unconditional
  # precompute - fixed here rather than left broken.)
  local needs_default
  needs_default="$(jq -r '([.work_items[]? | select(.target_repo == null)] | length) > 0' "$sf" 2>/dev/null)" || needs_default=true
  if [ "$needs_default" = "true" ]; then
    # The refusal itself is the spec's fail-safe rule (#272/#310 Task 4): a
    # record predating `target_repo` is genuinely ambiguous under N>1 and
    # guessing a repo for it is worse than stopping. What was wrong is the
    # MESSAGE. `_oss_default_repo_key` says "no repo key given" - and here one
    # WAS given; the ambiguity is in the legacy records, not in the call. A
    # caller who reads that refusal re-runs with the key they already passed.
    if ! default_key="$(_oss_default_repo_key 2>/dev/null)"; then
      echo "oss: $(jq -r '[.work_items[]? | select(.target_repo == null)] | length' "$sf" 2>/dev/null) work item(s) in '$sf' carry no target_repo, and with [$(printf '%s' "$(_oss_shape_file 2>/dev/null)" | jq -r '.repos | keys | join(", ")' 2>/dev/null)] declared there is no safe repo to attribute them to - refusing rather than guessing. This is not about the repo key you passed. Set target_repo on those records (they predate the field) and re-run." >&2
      return 2
    fi
  else
    default_key=""
  fi
  printf '%s\n' "${cands[@]}" | jq -R -s -r --arg k "$key" --arg dk "$default_key" --slurpfile st "$sf" '
      ($st[0].work_items // []) as $all
      | (if ($all | type) != "array" then
           error(".work_items is not an array")
         elif ($all | any(type != "object")) then
           error(".work_items holds a record that is not an object")
         elif ($all | any(
                  (.id            != null and (.id            | type) != "string")
               or (.target_repo   != null and (.target_repo   | type) != "string")
               or (.worktree_path != null and (.worktree_path | type) != "string"))) then
           error(".work_items holds a record whose id, target_repo or worktree_path is not a string")
         else . end)
      | ($all | map(select((.target_repo // $dk) == $k))) as $mine
      | split("\n") | map(select(length > 0))
      | map(select(
          . as $p
          | ($p | split("/") | last) as $b
          | ($mine | any((.worktree_path // "") == $p or (.id // "") == $b)) | not))
      | .[]' || {
    echo "oss: cannot inspect work-item claims in $sf - refusing to report orphans from unreadable state" >&2
    return 1
  }
}

# D9: HALT on a dirty worktree; never `--force`. The source retries with --force
# (discarding uncommitted work) and swallows the branch delete with `|| true`,
# while its own skill prose promises a halt and the close ceremony asserts no
# work-* branch survives. Both halves are fixed here.
#
# #673 A5: the worktree DIRECTORY may already be gone - a crash after a delete,
# or a close that halted after this loop cleaned an earlier item. The pre-fix
# form resolved through `worktree_resolve` (which requires `-d`) and refused
# rc 1, wedging cleanup at its LAST step for exactly the shapes the re-entry
# inventory routes `skip` / `finish-status` (a merged item whose worktree was
# deleted). Tolerate it: the registration, if one survives, is a stale entry
# (`git worktree remove` clears it; measured rc 0 on a missing directory - no
# prune, no --force needed), and the branch is recovered from STATE, the same
# `work_items[].branch` the close's merge target already trusts. A branch that
# is already gone is not an error either: `git branch -d`, the only sanctioned
# deleter, refuses an unmerged branch, so a deleted one WAS merged.
# #673 L5: the physical spelling of a directory. A repo reached through a
# symlink (`ln -s` roots; macOS /tmp) must compare equal to its resolved form,
# or the removal guard below would refuse the item's own registration; a path
# that no longer exists compares textually.
_oss_worktree_phys() { # $1=dir ; echoes the physical path when resolvable
  local p
  if [ -d "$1" ]; then
    p="$(cd -P "$1" 2>/dev/null && pwd)" && { printf '%s\n' "$p"; return 0; }
  fi
  printf '%s\n' "$1"
}

# #706: the read-only half of oss_worktree_remove's conv-absent arm, shared with
# the inventory's complete-arm verdict so both decide from one list read. Writes
# nothing. rc 0 ok (registrations to remove in _OSS_WT_KEPT, one per line) ·
# 1 the list could not be read · 2 a `/.worktrees/<wi>` registration under
# neither the derived nor the recorded root (path in _OSS_WT_BAD) · 3 a
# registration cleanup would remove is LOCKED (path in _OSS_WT_BAD).
_oss_worktree_cleanup_scan() { # $1=root $2=wi $3=recorded worktree_path (may be empty)
  local root="$1" wi="$2" recpath="$3" list rows row lk holdpath hp_root derived_root rec_root locked=""
  _OSS_WT_KEPT=""; _OSS_WT_BAD=""
  list="$(git --no-optional-locks -C "$root" worktree list --porcelain)" || return 1
  # The registration paths AS GIT PRINTS THEM (symlink-resolved on macOS
  # /tmp), matched on the `/.worktrees/<wi>` suffix - a whole-string compare
  # against the conventional path would miss that spelling. Each row is
  # `<locked 0|1> <path>`.
  rows="$(printf '%s\n' "$list" | awk -v s="/.worktrees/$wi" '
    function flush() { if (p != "") print lk " " p; p="" }
    /^worktree /{flush(); p=substr($0,10); lk=0
      if (!(length(p)>=length(s) && substr(p, length(p)-length(s)+1)==s)) p=""; next}
    /^locked/{lk=1; next}
    END{flush()}')" || return 1
  # #673 L5: only registrations under THIS item's own root are this verb's
  # to clear - its RECORDED worktree_path's root or the derived one, compared
  # physically so a symlinked spelling still matches. The pre-fix suffix-only
  # match also caught a worktree of a same-named path under a DIFFERENT root
  # (work-item ids repeat across workspaces) and `git worktree remove` would
  # have deleted it - live or dead. Validate the WHOLE set first; a match at
  # any other root refuses with nothing removed.
  derived_root="$(_oss_worktree_phys "$root")"
  rec_root=""
  case "$recpath" in
    */.worktrees/"$wi") rec_root="$(_oss_worktree_phys "${recpath%/.worktrees/$wi}")" ;;
  esac
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    lk="${row%% *}"; holdpath="${row#* }"
    hp_root="${holdpath%/.worktrees/$wi}"
    hp_root="$(_oss_worktree_phys "$hp_root")"
    if [ "$hp_root" = "$derived_root" ] || { [ -n "$rec_root" ] && [ "$hp_root" = "$rec_root" ]; }; then
      _OSS_WT_KEPT="$_OSS_WT_KEPT$holdpath"$'\n'
      [ "$lk" = 0 ] || [ -n "$locked" ] || locked="$holdpath"
    else
      _OSS_WT_BAD="$holdpath"; return 2
    fi
  done <<HOLD
$rows
HOLD
  [ -z "$locked" ] || { _OSS_WT_BAD="$locked"; return 3; }
  return 0
}

# #706: is the registration for directory $2 locked? rc 0 no · 1 yes · 2 the
# list could not be read. The conv-present arm's cleanup is a non-forced
# `git worktree remove`, which refuses a locked worktree.
_oss_worktree_reg_locked() { # $1=root $2=dir
  local list p
  list="$(git --no-optional-locks -C "$1" worktree list --porcelain)" || return 2
  p="$(_oss_worktree_phys "$2")"
  printf '%s\n' "$list" | awk -v p="$p" '
    /^worktree /{cur=(substr($0,10)==p); next}
    /^locked/{if (cur) hit=1}
    END{exit hit ? 1 : 0}' || return $?
}

oss_worktree_remove() { # $1=repo-key $2=work-item-id
  local key="$1" wi="$2" root path branch dirty sf holdpath recpath scan_rc
  _oss_worktree_id_check "$wi" || return $?
  root="$(_oss_repo_root "$key")" || return $?
  path="$root/.worktrees/$wi"
  branch=""
  # #673 L6 (class): a failed status read must not fold into the benign
  # empty value - an unreadable status left the branch silently undeleted
  # while close proceeded. The dirty check runs FIRST, before any state read:
  # nothing is ever removed, and no state is consulted, for a dirty worktree.
  if [ -d "$path" ]; then
    dirty="$(git -C "$path" status --porcelain 2>/dev/null)" || {
      echo "oss: cannot read the worktree status at $path - refusing to remove it" >&2; return 8; }
    if [ -n "$dirty" ]; then
      echo "oss: worktree $path has uncommitted changes - refusing to remove it" >&2
      printf '%s\n' "$dirty" >&2
      return 8
    fi
  fi
  # #673 round 4 (U-15p): the branch this verb deletes is NEVER the live
  # worktree HEAD's. Deriving it from the HEAD made a worktree switched off its
  # recorded branch delete a branch this item does not own - or, detached,
  # delete nothing while the recorded work branch silently survived and close
  # proceeded to mark the spine closed. The RECORDED branch is the only one
  # cleanup owns; the state read is hoisted above BOTH arms and fails closed
  # (#673 L6): an unresolvable, unreadable or recordless state refuses before
  # anything - worktree or registration - is touched.
  sf="$(_oss_resolve_state 2>/dev/null)" || {
    echo "oss: cannot resolve the state file for work item $wi - refusing to clean up $path" >&2; return 8; }
  [ -f "$sf" ] || { echo "oss: no state file at $sf - refusing to clean up $path" >&2; return 8; }
  branch="$(jq -r --arg w "$wi" 'first(.work_items[] | select(.id == $w) | .branch // empty) // ""' "$sf" 2>/dev/null)" || {
    echo "oss: cannot read work item $wi from $sf - refusing to clean up $path" >&2; return 8; }
  [ -n "$branch" ] || {
    echo "oss: work item $wi records no branch in $sf - refusing to clean up $path (a cleanup with no branch record cannot know what it is cleaning)" >&2; return 8; }
  if [ -d "$path" ]; then
    git -C "$root" worktree remove "$path" || { echo "oss: git worktree remove failed for $path" >&2; return 8; }
  else
    recpath="$(jq -r --arg w "$wi" 'first(.work_items[] | select(.id == $w) | .worktree_path // empty) // ""' "$sf" 2>/dev/null)" || {
      echo "oss: cannot read work item $wi's worktree_path from $sf - refusing to clean up $path" >&2; return 8; }
    # #706: validate the whole set (list read, roots, locks) before removing any.
    scan_rc=0; _oss_worktree_cleanup_scan "$root" "$wi" "$recpath" || scan_rc=$?
    case "$scan_rc" in
      0) ;;
      1) echo "oss: cannot read the worktree list for $root - refusing to clean up $path" >&2; return 8 ;;
      2) echo "oss: work item $wi has a registration at $_OSS_WT_BAD, which is not under this item's root - refusing; nothing was removed (inspect with: git -C $(printf '%q' "$root") worktree list)" >&2
         return 8 ;;
      *) echo "oss: work item $wi has a locked registration at $_OSS_WT_BAD - refusing; nothing was removed (inspect with: git -C $(printf '%q' "$root") worktree list)" >&2
         return 8 ;;
    esac
    while IFS= read -r holdpath; do
      [ -n "$holdpath" ] || continue
      git -C "$root" worktree remove "$holdpath" || { echo "oss: git worktree remove failed for the stale registration at $holdpath" >&2; return 8; }
    done <<HOLD
$_OSS_WT_KEPT
HOLD
  fi
  if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    # Only the item's OWN branch is this verb's to delete (#673 B-class
    # defence): `work/<wi-id>-*`, the name worktree_add cuts and the lane
    # journals from the worktree it created. A record naming anything else
    # (`main` above all, from a pre-fix adopt) is left alone with a note -
    # deleting the base branch is not cleanup.
    if ! printf '%s\n' "$branch" | awk -v p="work/$wi-" 'index($0, p) == 1 {ok=1} END{exit !ok}'; then
      echo "oss: work item $wi records branch '$branch', not a work/$wi-* branch - leaving it in place; nothing was deleted" >&2
      branch=""
    elif ! git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
      branch=""
    fi
  fi
  if [ -n "$branch" ]; then
    # `-d`, NOT `-D`. -D force-deletes an UNMERGED branch, destroying every
    # commit the implementer made. The close ceremony merges work/<wi> back into
    # the spine branch first (T9), so by the time remove runs the branch IS
    # merged and -d succeeds. If it does not, that is the signal that something
    # upstream failed to merge - surface it, never force past it.
    git -C "$root" branch -d "$branch" >/dev/null 2>&1 \
      || { echo "oss: worktree removed but branch '$branch' is not merged - refusing to force-delete it; merge or abandon it explicitly" >&2; return 8; }
  fi
}
