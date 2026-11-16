#!/usr/bin/env bash
#
# merge-bar — prose pins beyond the fidelity file's cap of ten (#1061 C8).
#
# Same rule as test-fidelity-pins.sh: a literal sentence occurs EXACTLY ONCE in its file.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/_helpers.sh"

occurrences() {
  awk -v needle="$2" '
    { line = $0
      while ((i = index(line, needle)) > 0) { n++; line = substr(line, i + length(needle)) } }
    END { print n+0 }
  ' "$1"
}

pin() {
  path="$PLUGIN_ROOT/$1"
  if [ ! -f "$path" ]; then fail "$3" "no such file: $1"; return 0; fi
  count="$(occurrences "$path" "$2")"
  if [ "$count" -eq 1 ]; then pass "$3"; else fail "$3" "found $count times in $1, want 1. pin: $2"; fi
}

section "working-a-pr round stop"
pin "skills/working-a-pr/SKILL.md" \
  "or **change the design**. Recommend the last when a stop's" \
  "the stop offers change the design as a third option, recommended on an Extends: chain"

section "reviewing-a-pr run"
pin "skills/reviewing-a-pr/SKILL.md" \
  "boundary and any network limit; the skill cannot." \
  "the network limit, with the write boundary, is the launcher's"
pin "skills/reviewing-a-pr/SKILL.md" \
  "(not a fork or unknown author)" \
  "naming run vouches only for code that is not a fork or an unknown author's"
pin "skills/reviewing-a-pr/SKILL.md" \
  "the PR's code and Evidence command are trusted" \
  "naming run states the PR's code and Evidence command are trusted"
pin "skills/reviewing-a-pr/SKILL.md" \
  "(a directory outside any git repository" \
  "the run directory is outside any git repository"
pin "skills/reviewing-a-pr/SKILL.md" \
  'd=$(mktemp -d "<run>/axis.XXXXXX") && git -C <checkout> archive HEAD | tar -x -C "$d"' \
  "each axis extracts into a fresh mktemp directory with git -C <checkout> archive"
pin "skills/reviewing-a-pr/SKILL.md" \
  "so the launcher must enforce the write" \
  "the launcher, not the skill, enforces the write boundary of the trusted code"
pin "skills/reviewing-a-pr/SKILL.md" \
  "Each except \`run\` can come as a slash-command flag" \
  "run is not a slash-command flag"

section "review-pr command"
pin "commands/review-pr.md" \
  "a \`--run\` in the arguments is ignored, never run, and the report's \`Run:\` header says so" \
  "the command ignores a --run argument and says so in the Run: header"

section "working-a-pr operator chooses"
pin "skills/working-a-pr/SKILL.md" \
  "The operator chooses at every stop that no standing order settles (next sentence), and no count" \
  "the operator chooses at every stop; merge-bar has no redesign-once cap"

# Batch 17 pins flatten whitespace; hard wraps are not behavior changes.
pin_prose() {
  local flat
  flat="$(mktemp)"
  awk '{s=s " " $0} END {gsub(/[[:space:]]+/, " ", s); print s}' "$PLUGIN_ROOT/$1" > "$flat"
  count="$(occurrences "$flat" "$2")"
  rm -f "$flat"
  if [ "$count" -eq 1 ]; then pass "$3"; else fail "$3" "found $count times in $1, want 1. pin: $2"; fi
}

section "batch 17 retro contracts"
pin_prose commands/retro.md 'Bash(ls:*)' 'B17-01 permits parent-directory listing'
retro=skills/running-a-retro/SKILL.md
work=skills/working-a-pr/SKILL.md
review=skills/reviewing-a-pr/SKILL.md
pin_prose "$retro" 'A host-refused write, including the run line, is printed with its destination file and named as not written in the read-out.' 'B17-02 discloses refused writes including the run line'
pin_prose "$work" '- [TD] <area/path> — <defect> → #N (PR #N)' 'B17-03a TD carries a PR suffix'
pin_prose "$retro" 'by their `(PR #N)` or `(PR <owner>/<repo>#N)` suffix; skip and count older lines with no PR suffix.' 'B17-03b selects debt by PR suffix and counts older lines'
pin_prose "$retro" 'a header with no repository (`no repository in header`)' 'B17-04a counts repository-free headers separately'
pin_prose "$retro" 'reports skipped (no header, no repository in header,' 'B17-04b reports the repository-free skip reason'
pin_prose "$retro" 'A comment in the report shape (a `PR:` header line) is read as a report; the same report reached by a ledger path and a comment counts once.' 'B17-05a reads comment reports once'
pin_prose "$retro" 'Other comments are read by meaning, as findings.' 'B17-05b reads prose comments by meaning'
pin_prose "$retro" 'only when its rule flags every site of the class in the window' 'B17-06a coverage requires every site'
pin_prose "$retro" 'Partial overlap is a standards-entry proposal naming the entry it extends.' 'B17-06b extends partially covering entries'
pin_prose "$retro" 'Entries in files under `## Read these where they live` count; merge-bar’s baseline does not: a recurring baseline class gets an entry citing the baseline.' 'B17-06c distinguishes pointed entries from the baseline'
pin_prose "$retro" 'A judgment class never becomes one, even when a search finds part of it: it is a standards entry (the check test, step 1).' 'B17-07 a judgment class with a searchable part is an entry, not a check'
pin_prose "$retro" 'one read-out line, `check exists, CI does not run it: <check>`, no proposal.' 'B17-08 reports existing unrun checks without proposing'
pin_prose "$retro" 'A report’s `Refuted:` line is a cleared candidate, never evidence or reviewer noise.' 'B17-09a excludes refuted candidates from evidence and noise'
pin_prose "$retro" 'Only a disposition marked `invalid` by `working-a-pr` counts toward reviewer noise' 'B17-09b restricts noise to invalid dispositions'
pin_prose "$retro" '`P<n>` numbers are per run; match the log by the class line’s meaning and take its outcome; when unsure, show the logged line beside the proposal.' 'B17-10a matches logged meaning instead of proposal numbers'
pin_prose "$retro" 'An `edited` log line uses the operator’s final wording as its class.' 'B17-10b logs the edited class wording'
pin_prose "$retro" 'add the round when present (`#a r2 C2`)' 'B17-10c disambiguates repeated class IDs by round'
pin_prose "$retro" 'With no operator (a status turn or `-p` run), read nothing, write nothing, and name the matching directories.' 'B17-11a refuses ambiguous workspace reads without an operator'
pin_prose "$retro" 'With no operator, otherwise run normally, accept no proposal, write only the run line, and print the proposals.' 'B17-11b permits only the run line without an operator'
pin_prose "$retro" '“When none comes” means the run ends with a proposal unanswered.' 'B17-11c defines the end of an unanswered run'
pin_prose "$retro" 'First PR is the earliest `mergedAt` in the window; last PR is the latest.' 'B17-12a orders window endpoints by merge date'
pin_prose "$retro" 'An undetermined window uses `window undetermined (gh unavailable), <n> ledger lines`.' 'B17-12b defines the gh-unavailable run line'
pin_prose "$retro" 'Delete both temp files after `gh issue create` returns, whatever its exit status.' 'B17-13 cleans issue temp files on success or failure'
pin_prose "$retro" 'One run’s silence on a class is not evidence it does not repeat; runs vary.' 'B17-14 disclaims silence as evidence'

# Already-met control: two correctly shaped copies agree on the base. Byte parity
# (not a prose pin) must reject a one-word change to EITHER copy.
rule_parity() {
  local headline quote
  headline="$(awk '/^\*\*Prose is the default\./ {sub(/^\*\*/, ""); sub(/\*\*$/, ""); print}' "$1")"
  quote="$(awk '/^"Prose is the default\./ {sub(/^"/, ""); sub(/"$/, ""); print}' "$2")"
  [ -n "$headline" ] && [ -n "$quote" ] && [ "$headline" = "$quote" ]
}
section "skill-first parity"
if rule_parity "$PLUGIN_ROOT/../docs/conventions/skill-first.md" "$PLUGIN_ROOT/$retro"; then
  pass 'B17-16 rule quote equals the authoritative bold headline byte for byte'
else
  fail 'B17-16 rule quote equals the authoritative bold headline byte for byte'
fi

section "batch 17 routing and round contracts"
pin_prose .codex-plugin/plugin.json 'Open, work and review PRs against their merge bar; run a retro' 'B17-17a Codex short description names review and retro'
pin_prose .codex-plugin/plugin.json 'reviews a PR as defect classes in two fresh-context axes, and runs a retro on recurring review findings' 'B17-17b Codex long description names review and retro'
pin_prose "$work" 'the manifest’s `.well_known_paths.memory_bank` (`.ossify/topology.json` first, else `.workspace/pairing.json`)' 'B17-19a routes both ledgers using manifest precedence'
pin_prose "$work" 'Expand `${ai_workspace.root}` to the matched workspace root; absent a route, use `.claude/memory-bank/`. Any other token: print the lines and ask.' 'B17-19b expands only the known route token and asks on others'
pin_prose "$retro" 'Read the ledger, `tech-debt.md` and `retro-log.md` from the bank §5 resolves.' 'B17-19c retro consumes the same routed bank'
pin_prose "$work" 'A PR in the workspace’s canonical repo stays `PR #N`; any other repo uses `PR <owner>/<repo>#N` in the ledger line and the parenthesized suffix above.' 'B17-19d qualifies noncanonical references in both ledgers'
pin_prose "$work" 'The `answered:` field lists every non-blocking class with its disposition in parentheses: `(answered)`, `(invalid)`, `(limit)` or `(→ #N)`.' 'B17-19e records every nonblocking disposition'
pin_prose "$work" 'A report with no `Bar:` line records no ruling for its classes.' 'B17-19f never infers a ruling from a missing Bar'
pin_prose "$work" 'The date is the merge date from `gh pr view <PR> --json mergedAt`, in UTC.' 'B17-19g records UTC merge date'
pin_prose "$work" 'If a round changes the body’s `## Merge bar` or `## Claim` (beyond adding Known-limits lines or Evidence), start the next review as round 1 on the whole PR and say the bar or Claim changed.' 'B17-20a actor launches a whole-PR round after a changed contract'
pin_prose "$review" 'Told the bar or Claim changed since the previous report, review the whole PR as round 1 against the body now and say why in the header.' 'B17-20b reviewer resets to whole-PR round one when told'
pin_prose bin/mb '# Skill-first question 2: mechanical, closed input — fixed `gh` calls with a PR number and a head SHA.' 'B17-21 names the helper skill-first question'

report
