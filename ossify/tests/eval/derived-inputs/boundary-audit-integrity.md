# Derived input set — `boundary-audit-integrity`

**What this is.** The inputs `rubrics/boundary-audit-integrity.md` reads, derived from that
rubric in one pass. A fixture body on this surface must declare every class below, because
**every criterion is scored on every fixture** — including the ones it expects to decline.
An input a criterion reads but the body never states is scored against a guess.

**What this is not.** It is not a second copy of the rubric and states no rule. Each row
points at the criteria that read it; **the rubric is the authority on what those criteria
say**, and where the two disagree the rubric wins. Kept out of
`fixtures/<surface>/` because `lib/aggregate-scores.sh` globs `*.md` inside each surface
directory and treats every one it finds as a fixture owing a result JSON.

**Why it exists.** `README.md` already carries the rule — derive the input set from the
rubric in one pass, do not discover it from judge notes. The rule was written after a
partial pass and then never applied fixture-by-fixture, so the same class kept arriving a
few instances at a time: two consecutive review rounds on PR #226 were dominated by omitted
inputs, 4 findings then 4 again. The full pass (issue #229) found **55 instances across 10
classes** — the four the reviewer had reached were 4 of 55. This file is what a fixture
author checks against so that pass is not owed a third time.

**Re-derive it when the rubric changes.** A criterion edited to read something new adds a
row here; this list is downstream of the rubric and goes stale silently.

| # | Input class | Read by criteria |
|---|---|---|
| I1 | observed visibility per repo (`gh repo view`, including an indeterminate read) | 1, 2, 8 |
| I2 | manifest `visibility` field per repo — its value, or that it is unset | 1 |
| I3 | state posture, including unset and unrecognised | 1, 4 |
| I4 | the manifest's repository-object set, **that it is exhaustive**, and **each object's role value** (canonical, `ai_workspace`/`private_core`, unrecognized, undeterminable — the role selects the arm) | 2, 10 |
| I5 | root shape per object — every topology the probe distinguishes, not only git-repo vs plain non-repo: nested inside a parent repo, linked worktree, bare, and unresolved, each with its own probe facts (`--show-toplevel`, `--git-common-dir`, `--is-bare-repository`) and its own finding or scope note; and the manifest `git_tracked` hint's value, which the probe decides against (a manifest `true` over a plain non-repo halts as drift; the field is a hint, the probe decides) | 2 |
| I6 | remotes on record per repo — local enumeration **and** manifest `git_remote` — and each one's observed visibility | 2, 8 |
| I7 | `--no-git` reads: bytes scanned, and the content of every tree the read spans (tracked, untracked, gitignored) | 2, 3, 9 |
| I8 | `PUBLIC_BOUNDARY.md` presence and shape per repo — absent, `100644` **or `100755`** (either executable mode is a regular tracked entry), `120000` with its target **and the target's own shape** (mode, tracked or not, and which repo tracks it — the target decides note vs finding, not the symlink), `160000` | 3, 10 |
| I9 | rules-block parse state and contents, including non-pattern directives (`fixtures-must-be:`) | 3, 10 |
| I10 | `gitleaks` availability and per-repo run outcome; `.gitleaks.toml` **presence and, where present, its contents** | 3 |
| I11 | whether the untracked enumeration completed untruncated | 3 |
| I12 | whether the semantic sweep had to be narrowed to fit | 3 |
| I13 | private boundary inventory — locatable; its moat rows; empty, explicitly empty, or non-empty | 4 |
| I14 | the **whole** tracked doc set's content against each moat row — not only the surfaces the scenario highlights | 4 |
| I15 | the untracked file list (`git ls-files --others`, ignored files included) | 5 |
| I16 | hygiene allowlist entries, and whether one was added in response to a finding | 5, 6 |
| I17 | the character of each untracked hit — dependency/build tree vs generic ignored directory — and its contents | 5 |
| I18 | **Accepted disclosures** section — present or absent, and **every field of each row**: the release id, the finding and the surface it covers, the reason, and the date (criterion 6 treats all of them as the row; §5/criterion 7 re-read the row to resurface) | 6, 7 |
| I19 | the operator's disposition at triage — affirming or disputing the fact, **and accepting or not accepting the exposure** | 6, 7 |
| I20 | the pin fields of any surface an override would have to pin, in the shape that surface admits — tracked content: path + content hash + the commit read at; untracked or fileless finding: path + pattern; tool degradation: tool + failure | 6 |
| I21 | **History passes** row per repo — present, its recorded commit, its `Moat items reviewed` value (or none), and what the review covered | 8 |
| I22 | reachability of the audited ref from that recorded commit | 8 |
| I23 | clone completeness **per repo**, not once for the set | 8, 3 |
| I24 | audited-ref resolution — the spines' `base_branch`, manifest `default_branch`, the two `rev-parse` ids, and every other repo's checked-out branch | 9 |
| I25 | staged and unstaged tracked modifications per repo, and what each diff carries | 9 |
| I26 | `git ls-files -v` index flags per repo | 9, 10 |
| I27 | submodules tracked per repo — `.gitmodules`, gitlink entries, **and each pinned commit id** | 10 |
| I28 | submodule state — initialized or not, HEAD against the pin, its own two quiet diffs, its own index flags, its own untracked set, whether it pins submodules of its own | 10 |
| I29 | the pinned submodule tree's **tracked content** where the arm's reads reach it — document-rule matches, secrets hits, semantic-pass surfaces, and the non-pattern directives asked of each pinned tree | 3, 4, 10 |
| I30 | the superproject's **tracked-path set** the document rules execute against — `git ls-files` and the `fixtures-must-be:` non-pattern directives ask it of tracked data, so a fixture declaring the rules must also declare whether the superproject tracks a matching path or production-like fixture | 3, 10 |

## Mechanical presence contract

`lib/check-derived-inputs.py` reads only this marked table and fixture bodies,
with frontmatter removed. Each class has exactly one literal phrasing; `{repo}`
expands once for each subject below. Line wrapping is ignored, not punctuation,
case or synonyms. Repository subjects are the current surface's two manifest
objects (including plain non-repo roots), not just its git repositories. A
fixture with a different object set owes a contract update, never a silent skip.

I2, I6 and I23 use named subject labels because their existing set-wide wording
otherwise hides a declaration for only one repo. I6 and I23 include a colon
after each repo label, so a combined label cannot satisfy both repos. The labels
introduce no facts: the prose following each still declares that repo's value or
state. I4's dominant
exhaustiveness clause, I10's configuration name, I26's command and I27's filename
are presence anchors only. All seven rows remain mechanically checkable after
reading criteria 1, 2, 3, 8, 9 and 10; none is dropped. The checker does not
certify role values, complete remote enumeration, tool outcomes, clone coverage,
index flags or submodule pins — their correctness and sufficiency remain judge
work, as do all other input classes above.

<!-- presence-contract -->
Repos: canonical; AI workspace

| Class | Scope | Contract phrasing |
|---|---|---|
| I2 | per-repo | {repo} manifest visibility |
| I4 | set | carries no other repository object |
| I6 | per-repo | {repo} remotes on record: |
| I10 | set | .gitleaks.toml |
| I23 | per-repo | {repo} clone completeness: |
| I26 | set | git ls-files -v |
| I27 | set | .gitmodules |
<!-- /presence-contract -->

## The two ways a declaration still fails

**Declared as an outcome rather than a fact.** `README.md` states the rule; the failure it
names is a body that hands over a check's answer ("swept per the semantic pass, names
nothing") instead of the content the check reads. The criterion then cannot fail. Issue
#223 tracks the instances on this surface.

**Declared for one repo and read for several.** I6, I23 and I2 are per-repo inputs that read
naturally as set-wide sentences. Four fixtures declared clone completeness for the canonical
alone while the workspace's arm read it too; a sentence pinning the manifest `git_remote`
set "beyond the remotes enumerated above" appeared in **fifteen** fixtures that never enumerated
the canonical's remotes.
