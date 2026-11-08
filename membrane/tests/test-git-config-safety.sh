#!/usr/bin/env bash
# tests/test-git-config-safety.sh — the tracked-status check behind TAMPER-003 (state_update_self_integrity and
# state_check_tamper, the only git calls membrane makes) runs no command that the audited repository's git config
# names through core.fsmonitor: set in .git/config, through include.path, through includeIf, or in the config of a
# gitdir that a .git file points at. Every repo is a scratch repo made here, git reads no user or system config, and
# the only command any config names is a scratch script that appends a line to a marker file under the scratch dir.
set -u
source "$(dirname "$0")/_helpers.sh"

if ! command -v git >/dev/null 2>&1; then
  printf '  SKIP  git is not installed\n'
  exit 0
fi

_csa_failed=0
_T="$(mktemp -d "${TMPDIR:-/tmp}/csa-gitcfg.XXXXXX")"
trap 'rm -rf "$_T"' EXIT
_T="$(cd "$_T" && pwd -P)"
_CSA="$CSA_PLUGIN_ROOT/bin/csa"
_MARK="$_T/markers/fired"

export HOME="$_T/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
mkdir -p "$HOME" "$_T/markers" "$_T/repos" "$_T/inc" "$_T/foreign"

# The marker command: records that it ran and fails, so git falls back to reading the index itself.
printf '#!/bin/sh\nprintf "ran\\n" >> "%s"\nexit 1\n' "$_MARK" > "$_T/mark"
chmod +x "$_T/mark"
printf '[core]\n\tfsmonitor = %s\n' "$_T/mark" > "$_T/inc/fsmonitor.cfg"

# _g <args> — git for building the fixtures: no hook, no signing, and no fsmonitor of its own.
_g() { git -c user.name=t -c user.email=t@t.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null -c core.fsmonitor= "$@"; }

# _repo <name> <tracked|untracked> <with-suppressions|no-suppressions> — a scratch repo holding a state.json made by
# bin/csa (and an empty suppressions file), committed or not; prints its path.
_repo() {
  local r="$_T/repos/$1"
  mkdir -p "$r"
  _g init -q "$r" || return 1
  (cd "$r" && "$_CSA" state_init "$r") >/dev/null || return 1
  [[ "$3" == no-suppressions ]] || printf '{"suppressions":[]}\n' > "$r/.claude/audits/suppressions.json"
  printf 'x\n' > "$r/README"
  if [[ "$2" == tracked ]]; then _g -C "$r" add -A && _g -C "$r" commit -qm init || return 1
  else _g -C "$r" add README && _g -C "$r" commit -qm init || return 1; fi
  printf '%s' "$r"
}

# _fired — how many times the marker command ran since the last call; resets the count.
_fired() { local n=0; [[ -f "$_MARK" ]] && n="$(wc -l < "$_MARK" | tr -d ' ')"; rm -f "$_MARK"; printf '%s' "$n"; }

# _check <label> <repo> <want-tracked> — the fixture is live (a plain `git ls-files` in the repo runs the marker
# command), then state_update_self_integrity and state_check_tamper through bin/csa each run it 0 times, both exit 0,
# and the recorded tracked status of each file is <want-tracked>.
_check() {
  local label="$1" r="$2" want="$3" rc=0 n st="$2/.claude/audits/state.json" sp="$2/.claude/audits/suppressions.json"
  _fired >/dev/null
  git -C "$r" ls-files --error-unmatch "$st" >/dev/null 2>&1 </dev/null
  n="$(_fired)"
  [[ "$n" -gt 0 ]] || { printf '    %s: the fixture is not live: a plain git ls-files ran no marker command\n' "$label" >&2; return 1; }
  (cd "$r" && "$_CSA" state_update_self_integrity "$r") >/dev/null 2>&1 </dev/null || { printf '    %s: state_update_self_integrity failed\n' "$label" >&2; rc=1; }
  assert_eq "0" "$(_fired)" "$label: state_update_self_integrity runs no configured command" || rc=1
  (cd "$r" && "$_CSA" state_check_tamper "$r") >/dev/null 2>&1 </dev/null || { printf '    %s: state_check_tamper failed\n' "$label" >&2; rc=1; }
  assert_eq "0" "$(_fired)" "$label: state_check_tamper runs no configured command" || rc=1
  assert_eq "$want" "$(jq -r '.self_integrity.git_tracked_check.state_json_tracked' "$st")" "$label: state.json tracked" || rc=1
  if [[ -f "$sp" ]]; then
    assert_eq "$want" "$(jq -r '.self_integrity.git_tracked_check.suppressions_json_tracked' "$st")" "$label: suppressions.json tracked" || rc=1
  fi
  return "$rc"
}

# core.fsmonitor in the repo's own .git/config, with and without a suppressions.json (the suppressions file is checked
# only when it exists), and with state.json tracked and untracked: no marker, and the tracked status still reads right.
test_fsmonitor_in_git_config_never_runs() {
  local r rc=0 sup tr
  for sup in no-suppressions with-suppressions; do
    for tr in tracked untracked; do
      r="$(_repo "plain-$sup-$tr" "$tr" "$sup")" || return 1
      git -C "$r" config core.fsmonitor "$_T/mark"
      _check ".git/config, $sup, $tr" "$r" "$([[ "$tr" == tracked ]] && echo true || echo false)" || rc=1
    done
  done
  return "$rc"
}

# core.fsmonitor set in a file that .git/config includes: by absolute include.path, by an include.path relative to
# .git/ that names a file inside the project, and by includeIf "gitdir:". No marker.
test_fsmonitor_through_an_include_never_runs() {
  local r rc=0
  r="$(_repo inc-abs tracked with-suppressions)" || return 1
  git -C "$r" config include.path "$_T/inc/fsmonitor.cfg"
  _check "include.path" "$r" true || rc=1
  r="$(_repo inc-rel tracked with-suppressions)" || return 1
  cp "$_T/inc/fsmonitor.cfg" "$r/.claude/fsmonitor.cfg"
  git -C "$r" config include.path ../.claude/fsmonitor.cfg
  _check "include.path inside the project" "$r" true || rc=1
  r="$(_repo inc-if tracked with-suppressions)" || return 1
  git -C "$r" config "includeIf.gitdir:$_T/repos/.path" "$_T/inc/fsmonitor.cfg"
  _check "includeIf gitdir:" "$r" true || rc=1
  return "$rc"
}

# The project's .git is a file (`gitdir: <dir>`) naming a git dir outside the project, whose config sets
# core.fsmonitor. No marker.
test_fsmonitor_in_a_gitdir_file_target_never_runs() {
  local r
  r="$(_repo gitdir-file tracked with-suppressions)" || return 1
  mv "$r/.git" "$_T/foreign/gitdir-file.git"
  printf 'gitdir: %s\n' "$_T/foreign/gitdir-file.git" > "$r/.git"
  git --git-dir="$_T/foreign/gitdir-file.git" config core.fsmonitor "$_T/mark"
  _check ".git file" "$r" true
}

# TAMPER-003 still reads a change of tracked status with core.fsmonitor set: state.json recorded tracked, then removed
# from the index, is a TAMPER-003, and no marker runs.
test_tamper_003_still_reads_tracked_status() {
  local r out
  r="$(_repo drift tracked with-suppressions)" || return 1
  git -C "$r" config core.fsmonitor "$_T/mark"
  (cd "$r" && "$_CSA" state_update_self_integrity "$r") >/dev/null 2>&1 </dev/null || return 1
  _g -C "$r" rm -q --cached .claude/audits/state.json || return 1
  _fired >/dev/null
  out="$(cd "$r" && "$_CSA" state_check_tamper "$r" 2>/dev/null </dev/null)"
  assert_contains "$out" '"rule_id":"TAMPER-003"' "untracking state.json is a TAMPER-003" || return 1
  assert_eq "0" "$(_fired)" "state_check_tamper runs no configured command" || return 1
}

csa_test_run test_fsmonitor_in_git_config_never_runs        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_fsmonitor_through_an_include_never_runs   || _csa_failed=$((_csa_failed + 1))
csa_test_run test_fsmonitor_in_a_gitdir_file_target_never_runs || _csa_failed=$((_csa_failed + 1))
csa_test_run test_tamper_003_still_reads_tracked_status     || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
