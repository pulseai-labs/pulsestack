#!/usr/bin/env bash
# Real temporary histories exercise the aggregate gate, not eval judgments.
set -euo pipefail
SOURCE="$(cd "$(dirname "$0")" && pwd)/eval/lib/aggregate-scores.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PASS=0 FAIL=0
new_repo() {
  repo="$WORK/$1"; mkdir -p "$repo/eval/"{lib,fixtures/s,results/s,rubrics}
  cp "$SOURCE" "$repo/eval/lib/aggregate-scores.sh"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@t
  git -C "$repo" config user.name t
  printf 'original\n' > "$repo/eval/fixtures/s/a.md"
  printf 'rubric\n' > "$repo/eval/rubrics/s.md"
  printf '{"pass":true}\n' > "$repo/eval/results/s/a.json"
  commit base
}
commit() { git -C "$repo" add -A; git -C "$repo" commit -qm "$1"; }
expect() {
  local label="$1" wanted="$2" needle="$3" out rc=0
  out="$(bash "$repo/eval/lib/aggregate-scores.sh" 2>&1)" || rc=$?
  if [[ "$rc" == "$wanted" && "$out" == *"$needle"* ]]; then
    PASS=$((PASS+1)); printf 'ok: %s\n' "$label"
  else
    FAIL=$((FAIL+1)); printf 'FAIL: %s (rc %s wanted %s)\n%s\n' "$label" "$rc" "$wanted" "$out"
  fi
}
new_repo 'space repo'
expect 'unchanged committed result' 0 '1/1 passed'
printf 'edited\n' > "$repo/eval/fixtures/s/a.md"; commit edit
expect 'committed fixture edit is STALE' 1 'fixtures/s/a.md'
printf 'original\n' > "$repo/eval/fixtures/s/a.md"; commit revert-content
expect 'fixture changed back is current despite newer commit' 0 '1/1 passed'
printf 'local\n' > "$repo/eval/fixtures/s/a.md"
expect 'uncommitted fixture edit against committed result is STALE' 1 'fixtures/s/a.md'
printf 'original\n' > "$repo/eval/fixtures/s/a.md"
printf 'new rubric\n' > "$repo/eval/rubrics/s.md"
expect 'uncommitted rubric edit is STALE' 1 'rubrics/s.md'
commit rubric
expect 'committed rubric edit is STALE' 1 'rubrics/s.md'
printf 'rubric\n' > "$repo/eval/rubrics/s.md"; commit rubric-reverted
# A modified result uses mtimes, not its previous committed judgment.
printf '{"pass":true,"notes":"fresh"}\n' > "$repo/eval/results/s/a.json"
touch -t 202001010000 "$repo/eval/fixtures/s/a.md" "$repo/eval/rubrics/s.md"
touch -t 202101010000 "$repo/eval/results/s/a.json"
expect 'modified fresh result newer than inputs' 0 '1/1 passed'
touch -t 202201010000 "$repo/eval/fixtures/s/a.md"
expect 'modified fresh result older than fixture' 1 'fixtures/s/a.md'
touch -t 202001010000 "$repo/eval/fixtures/s/a.md"
touch -t 202201010000 "$repo/eval/rubrics/s.md"
expect 'modified fresh result older than rubric' 1 'rubrics/s.md'
new_repo untracked
mv "$repo/eval/fixtures/s/a.md" "$repo/eval/fixtures/s/odd [x] name.md"
mv "$repo/eval/results/s/a.json" "$repo/eval/results/s/odd [x] name.json"
commit odd-path
printf 'changed\n' > "$repo/eval/fixtures/s/odd [x] name.md"; commit odd-edit
expect 'literal path containing spaces and brackets' 1 'fixtures/s/odd [x] name.md'
printf 'original\n' > "$repo/eval/fixtures/s/odd [x] name.md"; commit odd-revert
expect 'literal odd path changed back is current' 0 '1/1 passed'
# Without literal pathspecs, this sibling's result commit is mistaken for the
# bracketed result's commit and launders its simultaneous fixture edit.
printf 'changed\n' > "$repo/eval/fixtures/s/odd [x] name.md"
printf '{"pass":true}\n' > "$repo/eval/results/s/odd x name.json"; commit sibling-result
expect 'wildcard sibling result cannot refresh another judgment' 1 'fixtures/s/odd [x] name.md'
new_repo new-result
git -C "$repo" rm -q eval/results/s/a.json; commit result-removed
mkdir -p "$repo/eval/results/s"
printf '{"pass":true}\n' > "$repo/eval/results/s/a.json"
touch -t 202001010000 "$repo/eval/fixtures/s/a.md" "$repo/eval/rubrics/s.md"
touch -t 202101010000 "$repo/eval/results/s/a.json"
expect 'untracked result newer than inputs' 0 '1/1 passed'
touch -t 202201010000 "$repo/eval/fixtures/s/a.md"
expect 'untracked result older than fixture' 1 'fixtures/s/a.md'
new_repo missing-input
git -C "$repo" rm -q eval/rubrics/s.md; commit no-rubric
expect 'missing current rubric fails closed' 1 'rubrics/s.md'
mkdir -p "$repo/eval/rubrics"
printf 'rubric\n' > "$repo/eval/rubrics/s.md"; commit restored-rubric
# The result commit predates this input even though its bytes equal the original.
printf '{"pass":true,"notes":"at missing rubric"}\n' > "$repo/eval/results/s/a.json"
git -C "$repo" rm -q eval/rubrics/s.md; commit judged-without-rubric
mkdir -p "$repo/eval/rubrics"
printf 'rubric\n' > "$repo/eval/rubrics/s.md"; commit added-rubric
expect 'input absent at result commit is STALE' 1 'did not exist at result commit'
new_repo merge
base_branch="$(git -C "$repo" symbolic-ref --short HEAD)"
git -C "$repo" checkout -qb side
printf 'side\n' > "$repo/eval/fixtures/s/a.md"; commit side
side="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" checkout -q "$base_branch"
printf 'unrelated\n' > "$repo/readme"; commit main
# A real two-parent merge mentions the fixture in its first-parent history but
# deliberately retains the already-judged bytes (the production false positive).
git -C "$repo" merge --no-commit --no-ff "$side" >/dev/null 2>&1
printf 'original\n' > "$repo/eval/fixtures/s/a.md"; commit identical-merge
expect 'merge touched fixture with identical content is current' 0 '1/1 passed'
# Git stores cleaned blobs, not the CRLF bytes in a clean checkout.
for mode in autocrlf attributes; do
  new_repo "$mode"
  if [[ "$mode" == autocrlf ]]; then
    git -C "$repo" config core.autocrlf true
  else
    printf '*.md text eol=crlf\n' > "$repo/.gitattributes"; commit attributes
  fi
  rm "$repo/eval/fixtures/s/a.md" "$repo/eval/rubrics/s.md"
  git -C "$repo" checkout-index -f -- eval/fixtures/s/a.md eval/rubrics/s.md
  [[ "$(cat "$repo/eval/fixtures/s/a.md")" == *$'\r' ]] || exit 1
  expect "$mode unchanged CRLF checkout is current" 0 '1/1 passed'
  printf 'real edit\r\n' >> "$repo/eval/fixtures/s/a.md"
  expect "$mode real content edit is STALE" 1 'differs from result commit'
done
new_repo full-history
printf 'edited\n' > "$repo/eval/fixtures/s/a.md"; commit fixture-edit
printf 'unrelated\n' > "$repo/readme"; commit unrelated
origin="$repo"
for depth in 1 2; do
  repo="$WORK/shallow-$depth"
  git clone -q --depth "$depth" "file://$origin" "$repo"
  expect "depth $depth clone fails closed" 1 'STALE-CHECK UNAVAILABLE: shallow clone'
done
# An ignored result has neither porcelain status nor a result-history commit.
new_repo ignored-result
mv "$repo/eval/fixtures/s/a.md" "$repo/eval/fixtures/s/ignored.md"
git -C "$repo" rm -q eval/results/s/a.json
printf 'eval/results/s/ignored.json\n' > "$repo/.gitignore"; commit ignored-result-path
mkdir -p "$repo/eval/results/s"
printf '{"pass":true}\n' > "$repo/eval/results/s/ignored.json"
touch -t 202001010000 "$repo/eval/fixtures/s/ignored.md" "$repo/eval/rubrics/s.md"
touch -t 202101010000 "$repo/eval/results/s/ignored.json"
expect 'ignored fresh result newer than inputs' 0 '1/1 passed'
touch -t 202201010000 "$repo/eval/fixtures/s/ignored.md"
expect 'ignored fresh result older than fixture' 1 'newer than the fresh result'
new_repo outside
rm -rf "$repo/.git"
expect 'not a work tree fails closed' 1 'STALE-CHECK UNAVAILABLE:'
new_repo broken-git
mkdir "$WORK/bin"
printf '#!/usr/bin/env bash\nif [[ "$*" == *" log "* ]]; then exit 128; fi\nexec %q "$@"\n' "$(command -v git)" > "$WORK/bin/git"
chmod +x "$WORK/bin/git"
PATH="$WORK/bin:$PATH" expect 'git read failure fails closed' 1 'STALE-CHECK UNAVAILABLE:'
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
