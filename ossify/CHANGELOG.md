# Changelog

All notable changes to the `ossify` plugin, newest first.

Up to 1.36.7 these notes were "Since x.y" paragraphs in `README.md`. They moved here word for word,
with two edits that fix a pointer to a place on the old page: 1.11.0 says "see its entry above",
not "see its section below", and 1.15.0 drops "which is why it is listed above rather than below".
The 1.24.0 entry's parenthesis about adopt and a marked stub, added in 1.35.0, said adopt replaced a stub as of 1.24.0; 1.37.1 corrects it (#1107).
Some versions have no entry. The GitHub releases tagged `ossify-v*` carry notes for the versions
they cover.

## 1.38.1

Since 1.38.1 (#704, #705, #706), the re-entry read-out names the right halt before anything mutates, and the two writers that sat behind it agree with it. A planned item with a branch recorded and no `base_sha` and its worktree gone now routes `halt:base-unknown` (it was `halt:unclassified`), as the active arm does; a stray path at the recorded location still routes `halt:planned-with-worktree` first. A recorded base ref that is corrupt, not absent, now routes `halt:unreadable` (the repo row keeps its shape); an absent one keeps `halt:base-unresolved`. A complete item the read-out would `skip` or `finish-merge` now halts `halt:worktree-held` when close's cleanup would refuse: an extra `/.worktrees/<wi>` registration under another root, an unreadable worktree list, or a locked registration cleanup would remove (the conventional path's own registration included). The read-out and `oss worktree_remove` take that verdict from one shared helper in `worktree.sh`, so they read the same list. Adopt's C3 step 1a halts on a folded ADR reference held by any two inventory files, in two repos or in one, naming each file and its repo (an `ADR-0007-a.md` beside `adr-0007-b.md` in one repo used to pass), and `bone_add` compares the ADR reference ASCII case-folded, so a case variant refuses at rc 7 and names the existing spelling. Eval fixture `adopt-multi-repo/09` pins the within-repo halt. Patch release: each change fixes shipped behaviour. Migration: `oss bone_add` refuses `adr-0007` after `ADR-0007` (rc 7; it minted a second row before), and refuses (rc 4, nothing minted) when an existing bone's `.adr` is not a string; `oss worktree_remove` refuses a locked registration at rc 8 before removing anything (a second, locked registration used to refuse after the first was already removed). Closes #704, #705 and #706. Known limits: a complete item with its conventional worktree present and an unreadable worktree list halts in the read-out although cleanup itself reads no list on that arm and might succeed; case variants already minted into a registry are not repaired, and the `bone_set_*` verbs still match the reference exactly.

## 1.38.0

Since 1.38.0 (#195, #473, #736), the handoff ceremonies carry #195's five fixes, #473's trap rule and one eval fix. `/ossify:handoff-resume` no longer pre-approves `git log`, `git diff`, `git show` or `git rev-list`: each takes `--output=<path>` and writes a file with no prompt, so a check command in a handoff the repo controls could overwrite a file unasked. The kept entries (`git status`, `rev-parse`, `ls-files`, `gh issue view`, `gh pr view`, `gh pr list`, `test`, `ls`) were each checked against their own help for a flag that writes a file, and none has one. An explicit path to a per-work-item `handoff.md` now opens the read-out with "this is a work order, not session state", gets the verdict `stale — re-plan before acting`, and its steps are not worked unless the operator says so; the drift report is still given. With no argument, undated names are ranked by the header's authored date before git history and modification time. Compose names the directory its §2 checks were run from, and never overwrites an existing handoff: a taken name gets the repo's own suffix (a letter after the date) or `-2`, `-3`, checked against the directory and not `git ls-files`, so an ignored file counts, and the read-out says which name was used. A trap that states a checkable fact also gets a §2 row, and the drift report gains `§6 traps   <n> traps · <m> state facts · <k> of those have a §2 row`; resume counts, and does not check the trap's fact. Eval fixtures `handoff-compose/01` and `04` now name a concrete remaining step, which fixes the `sequence_ordered` flake (#736); `handoff-compose/06` (a same-day, same-topic re-compose) and `handoff-resume/04` (an explicit path to a work order) are new, each with a rubric line. Pins in `test-prose-contracts.sh` hold the grant (the whole `allowed-tools` value, a closed set of eleven entries, so `Write` or `Edit` added fails too; the skill `ossify:handoff-resume` carries no `allowed-tools` key of its own), the collision rule, the work-order line, the ranking order, the execution-root line and the `§6 traps` line. The release is minor because a grant and compose's write behaviour changed. Migration: resume now prompts for `git log`, `diff`, `show` and `rev-list`; approve them per use or add them to your own allowlist. Closes #195, #473 and #736. Known limits: resume does not check a trap's fact; `git status` stays pre-approved and may refresh the index, which is not a path a handoff chooses.

## 1.37.1

Since 1.37.1 (#1121, #1107), a work item's handoff says where the spine's class comes from. `handoff-contract.md` §2 now says to copy it from `oss get '.spines[] | select(.id == "<spine-id>") | .class'` and never to derive it from the bones list, because a spine that registers no bones is `bone` whenever its plan touches a registered surface; the report contract's work-item row takes the class as the handoff's §2 states it. Before, §2 asked for the class and named no source (`base_branch` had one), and a lane seat recorded `flesh` for a `bone` spine in all three handoffs and reports. It never ran an `oss get` for the class, its reads of the spine skipped the `Class:` line, and its header text (`bones registered: none`) suggests it took the class from the spine's "Bones this spine registers: None.". That was a record defect with no behavioural effect: spine close reads the class from the state file, and nothing in ossify reads it from a handoff. Four pins in `test-prose-contracts.sh` hold the wording. The 1.24.0 entry is corrected: `/start` replaces a marked `AGENTS.md` stub from 1.24.0, and adopt merges into it until 1.35.0, as adopt's `AGENTS.md` row at ossify-v1.25.0 and ossify-v1.34.0 (merge only), the 1.35.0 entry and `plain-repo.md` §5 say. Closes #1121 and #1107. Existing handoffs and reports are not rewritten.

## 1.37.0

Since 1.37.0 (#1040), `/start`'s canonical-content gate has a rule for a run where no operator can answer: a repo with any file at `HEAD` refuses, as 1.33 did for files at `HEAD` (history alone no longer refuses, and still does not), authoring nothing, printing what it found, and saying to re-run with an operator or use `/ossify:adopt` if it is the product. Plain product source still prints the product-source refusal first. A bare scaffold (no file at `HEAD`) or a repo with no commit proceeds; the spec-core audit's non-interactive rule is a different gate and is unchanged. Class H history now lands in `06-progress.md`'s spec-core-close entry, which §3, §13 and the memory-bank brief all name. Eval fixtures pin it: 06 (docs only, no operator) refuses where the pre-1.37.0 skill proceeded, 05 is the control where product source still routes to adopt, 04 is an operator who says source is not product. This closes #1040. When `06-progress.md` is an occupied destination the operator kept, class H history goes in the §13 hand-off message to the operator. Known limits: no fixture covers that kept case, and adopt's headless refusal has no eval. The release is minor because a gate's behaviour changed, as 1.34.0 and 1.35.0 did; the other changes below ship with it.

Since 1.37.0 (refs #1042, #1007; closes #1000), spine close's fields check halts `Door: one-way<TAB>/<TAB>two-way` (a tab beside `,`, `/` or `|`), as it already halted the spaced form; one door followed by a separator and other text that does not begin with `one-way` or `two-way` still passes. The separator set around `,`, `/` or `|` is space and tab only, so the verdict does not depend on the awk or the locale (a vertical tab or form feed is not a separator). Headless, adopt's class step refuses a docs-only repo (any file at `HEAD` it does not judge product) and says to re-run with an operator, since `/start` would refuse it too; `/start`'s no-operator refusal names adopt only for a repo that is product. The reviewer home's proposal, window and result lines name the repo when more than one is declared, and the `(gh failed)` counts line says its window is `none`. The fallback work-pr loop's "redesigned once" is now pinned. Prose fixes: adopt's `ADOPTION.md` wording after a retry (move it outside the AI workspace), its line cap (500) and the eval README's class L note (#1042); the reviewer home's line count, result-line placement, proposal format, 30-PR window (by merge date, 30 per declared repo), a `gh` failure no longer reading as "no history", and which crew row names the reviewer (#1007); the close gate's `--verdict` route and a stale-verdict entry in its recovery menu (#1000; baton's close brief already passes `--verdict`). Still open: #1042's workspace-init sites (that plugin's own release); #1007's occupied-destination ask at §13 and in adopt, the hand-off carrier of a standalone refusal, the posture arm's producer, the evals (no fixture for the CI-review line, the window or the no-history and gh-failed forms) and merge-bar's `working-a-pr` §5 (the stub-sentence item is settled by reviewer-home §5's stated rule). Door forms outside the ruled set still pass as filled: `OR`, `, or`, `//`, an em dash and a non-breaking space. `.github` examples are version-free now.

## 1.36.8

Since 1.36.8 (#1073, #1071), spine close's fields check halts a `Door:` line that joins `one-way` and `two-way` with `,`, `/` or `|` (spaces optional) as well as `or` across any whitespace (a tab included), and the CRLF and heading-order checks halt with a message saying the check could not run when their awk fails, instead of passing the file on or naming the wrong problem. The fallback work-pr loop's second exit offers the design change at every such stop until the change has been redesigned once, agreeing with its "do not restructure twice", and lists changing the design among its ways out; both are pinned. The remaining changes pin behaviour already right (`two-wayFoo`, `two-way2`, `two-way_x`, a `3)` line, a numbered Evidence line, a bar line quoted under `## Claim`).

## 1.36.7

Since 1.36.7, the OMP bin-path module it ships (`omp/bin-path.ts`, VERSION 2) reads installs under the new marketplace name `pulsestack` and, for one release, under the pre-rename name; an entry under the new name wins. The marketplace was renamed (pulsestack rename). No other change.

## 1.36.6

Since 1.36.6 (#1063), spine close's fields check reads the Merge bar and the Door line under their own headings: the bar's six template lines (the lead line, four conditions and `Everything else is non-blocking.`) must be whole lines under `## Merge bar`, an extra numbered line there halts, and the `Door:` line must sit under `## Merge danger` and read `one-way` or `two-way` followed by the line's end or any character that is not an ASCII letter or digit, `_` or `-` (so `Door: one-way after the tag — …` passes; `Door: one-way or two-way`, `Door: two-way or one-way`, `Door: two-wayfoo` and `Door: two-way-ish` halt); a template bar line repeated under `## Merge bar` halts too. A fields file with CRLF line endings halts with a message naming CRLF instead of reporting a visible heading missing. Same halt point as before: before that repo's push, only where `pr_fields_dir` is set.

## 1.36.5

Since 1.36.5 (#1061), the bundled `work-pr` loop's second exit offers the design change at every such stop and recommends it when every fix extends one mechanism on open input, in step with merge-bar 0.10.1's round stop. Prose only.

## 1.36.4

Since 1.36.4 (#331), wayfinder's `task` ticket is HITL and records manual work done outside the map: absent a `Notes` override the session never does the work, and resolves the ticket by recording where and by whom it was done, so the type no longer contradicts work mode's "plan, don't do". No label change; existing maps stay valid. Prose only.

## 1.36.3

Since 1.36.3 (#1056), spine close checks each seat-written merge-bar fields file before the push: the seven `##` headings in template order, the Merge bar's lead line and four conditions as whole lines, and a `Door: one-way` or `Door: two-way` line. A missing piece halts the close before that repo's push, naming the file and the piece; a repo landed earlier in the same pass keeps its PR, and the re-run resumes it. Known limit: a stopping rule written in the raising-line slot passes; `working-a-pr` still judges by all four conditions. Only where `pr_fields_dir` is set.

## 1.36.2

Since 1.36.2 (#1047), the bundled `work-pr` loop's second exit also allows changing the change's design, once, when every fix extends one mechanism on open input; this keeps it in step with merge-bar 0.10.0's round stop. Prose only.

## 1.36.1

Since 1.36.1 (#755), the skill references that call `gh` with a repo name say where it comes from: the target repository's own `origin` (`gh repo view`), never a folder name. Prose only.

## 1.36.0

Since 1.36.0 (#434), work-item close checks that `spec.md` is the spec that was dispatched. `oss work_item_exec` takes an optional fifth
argument, the spec's blob id from the new `oss spec_oid <path>` (always sha1, from one fixed hashing context, so dispatch and close agree
whatever repository they run in); round orchestration §3 passes it, and the value is recorded in the same journal entry as the dispatch.
It is set if given and kept if absent, so a four-argument call never erases it and journal entries written before 1.36.0 replay byte-identical.
Before every gate run, `work-item-close.md` §1 compares the recorded id with the spec now. Equal continues; an item with no recorded id
prints a note, writes it into `verify.md`, and closes; a different spec halts `halt:spec-changed`, with no verifier, merge or PR. There are
two ways out, both the operator's: restore the dispatched spec and re-run close, or return the item to `planned` and re-dispatch it. The
recorded value changes only through a new dispatch. The two crash-repair rows that re-call `work_item_exec` record the spec as it is at repair
and say so. Verb: `oss spec_oid <path>`. No state schema bump.

## 1.35.0

Since 1.35.0 (#536), `/ossify:adopt` takes a plain existing-source repo, class P: product source at `HEAD` and no
scaffold-dev legacy stack. The operator makes an AI workspace (an empty directory, `git init`) and runs `/ossify:adopt`
there; A1 authors `.ossify/topology.json` with the repos the operator names, and a product repo a resolved topology does
not declare refuses with the fix. A class step after A1 decides G/H (to `/ossify:start`), L (the legacy path, which also gains the C5 stub row, the C2 re-harvest and `--untracked-files=all` in A3)
or P. Class P adds gate A6 (the operator names a step that works from a clean checkout today, else adoption refuses
before any state), probes `git worktree list --porcelain` and `status --untracked-files=all`, and closes Release 0 only
while a step is still `shipped` after C2; zero left halts with the record written. A workspace-init `AGENTS.md` stub is
replaced, not merged, for both classes. The product repo's own `CLAUDE.md`, `.claude/`, spec and memory bank are inputs,
never written. Depth: `skills/adopt/references/plain-repo.md`. No `lib/` code.

## 1.34.0

Since 1.34.0 (#809), `/ossify:start`'s canonical-content gate refuses on product source at `HEAD`, not on
history. A declared repo with commits and nothing at `HEAD` that is product (class H) proceeds as
greenfield, and the §13 hand-off records each such repo's commit count and what is at `HEAD`. A repo with
product source still routes to `/ossify:adopt` (which took only a legacy-stack project until 1.35.0, #536). The probe proposes and the operator confirms. No `lib/` code.

## 1.33.1

Since 1.33.1, the README names `challenge` as the marketplace's one adversarial audit surface: the
architect-critic plugin is retired from the marketplace, and ossify's `challenge` is what remains.
`oss critic_detect` is unchanged and answers `absent` once the plugin is gone; removing the verb is a
major release. Prose only; no state change.

## 1.33.0

Since 1.33.0 (#233), `OSSIFY_ADVERSARY` accepts `devin`. The recipe runs from an empty directory
with a no-tools prompt, because Devin run from a repo exited 0 with prose and no audit.
`OSSIFY_ADVERSARY_MODEL` picks its model, and only this recipe reads it. Its read-only tools stay
approved, so do not select it for an artifact you did not write or review.

## 1.32.5

Since 1.32.5 (#946, #1025), `work-item`'s verification runs a new git-running test once more with no
host git identity, and its rc 2 text no longer calls a missing test file the usual cause. Prose only.

## 1.32.4

Since 1.32.4 (#859), spine close reads `Bones this spine registers` at any heading level and ends it
at the next heading of its level or higher. A nested section with a prose bone used to report "no
bones"; it now halts, naming the line. No state change.

## 1.32.3

Since 1.32.3 (#909, #934), `plan-spine`'s spec rules say that an AC running a test file the item
creates tests for that file first, since `node --test` on node 22 skips a missing one. Prose only.

## 1.32.2

Since 1.32.2 (#872), `touch_check` and the three `expired_*` gates return rc 2, could not check,
when they cannot find the project's state. `touch_check` used to return rc 1, which reads as clean.
No state change.

## 1.32.1

Since 1.32.1 (#922), the gate stops two wrong greens. `oss_verify_zero_tests_guard` now reads
`node --test` as a command word, so a bare run of zero tests no longer passes `exit 0`. A plain `output contains` row whose
last command is a named test runner now fails when the runner exits nonzero; to expect that exit, write
`exit <n> and output contains <str>`. Other commands keep the plain row. One `lib/` file changes,
no state change.

## 1.32.0

Since 1.32.0 (#970), an OMP work-item close dispatches omp-roles 0.10.0's `verifier` agent
(`task` with `agent: "verifier"`) and prints `verifier: ossify:verifier-agent on <model>`. OMP's
`task` takes no model, so the model is `task.agentModelOverrides.verifier` in omp's config, else
the session's; `OSSIFY_VERIFIER_MODEL` does not apply there. No `lib/` code, no state change.

## 1.31.1

Since 1.31.1 (#971), a `[rule]` or `[mutation]` halt in `verify.md` is a durable rejection on
re-entry, as `[fidelity]` already was: the inventory routes the item `halt:close-rejected`, so a
fresh session cannot hand a rejected result back to a stochastic gate. One `lib/` reader changes,
no state change.

## 1.31.0

Since 1.31.0 (#984), `/ossify:start` and `/ossify:adopt` seed the reviewer's project home in
the AI workspace only, never overwriting an existing file: `CODING_STANDARDS.md`,
`review-ledger.md`, and a `## Review` section in `08-governance.md`. `/ossify:adopt` also runs a
history pass that drafts standards entries from review history: a class that recurs in two or
more PRs is drafted, and the operator accepts each entry. `skills/start/references/reviewer-home.md`
can be followed alone by an existing ossify project. merge-bar's `working-a-pr` (0.7.0) appends one
review-ledger line per merged PR. No `lib/` code, no state change.

## 1.30.0

Since 1.30.0 (#993), `/close <wi> --pr --verdict <file>` closes on a verifier verdict a
caller already produced (baton's `verify` stage), in place of dispatching
`ossify:verifier-agent`. The file is one JSON object, `mode: verified` with `model`,
`agent`, `work_item_id`, `identity`, `rule`, `lenses` and `mutation`; `identity` is the
worktree fingerprint (`write-tree`, `status --porcelain`, `diff --binary`, hashed) taken
after the verifier restored everything. Close recomputes it and halts on a mismatch, so
an item that changed after verify is never closed on a stale verdict, then applies the
verdicts as it would the agent's and prints `verifier: <agent> on <model>`. Without the
flag nothing changes. No `lib/` behaviour change, no state change.

## 1.29.1

Since 1.29.1 (#981, #980, #973 items 1–2), one verifier pass can halt on several tags,
and the close surfaces, records and names every one, so `[fidelity]` no longer hides
`[mutation]`; when both name the same test the `[mutation]` recovery row applies. Every
completed verifier pass writes `verify.md`, zero findings included, with the `verifier:`
line and each layer's result, so the `--external-executor` lane's close leaves a durable
record, and the spine retrospective carries each item's `verifier:` line. No `lib/`
behaviour change, no state change.

## 1.29.0

Since 1.29.0 (#978), the default lane works on a Claude Code that refuses a subagent's
Write of a `report*.md` file. The implementer's `complete` return gains one optional key,
`report_text`: as a Claude Code subagent it returns the report there instead of writing
`report.md`, and the lane writes that text verbatim to `report_path` before close runs.
A `complete` return with no report file and no `report_text` is a named halt, not a
Layer 2 failure. `report.md` keeps its name, and an `--external-executor` result still
carries the four keys. No `lib/` code, no state change.

## 1.28.0

Since 1.28.0 (#951), the implementer builds and the close verifies. `work-item` no longer
asks whether each test can fail, and report §5 carries commands and results only. Work-item
close dispatches `ossify:verifier-agent` for Layer 3, Layer 4 and a new mutation check
(`impl-check.md` §4c), in a context that did not build the item. Set `OSSIFY_VERIFIER_MODEL`
in a `settings.json` env block to run it on another model; unset, it inherits the session's
and the close says so. The close fingerprints the worktree before the dispatch and halts if
the verifier leaves it changed. A test that stays green under a mutation whose evidence holds
all three conditions halts as a fifth tag, `[mutation]`. Where no agent can be dispatched
(Codex, OMP without omp-roles' `verifier` agent, a subagent context) the close runs the same checks itself and prints
`verifier: inline`; inside an `--external-executor` lane Layers 3 and 4 stay in the closing
session and the caller's verifier owns mutation. No `lib/` code, no state change.

## 1.27.1

Since 1.27.1 (#963), that ack and that order merge a two-way door only where merge-bar's
`working-a-pr` runs: a one-way door, or a body with no `Door:` line, goes to the merge holder
(the orchestrator where one runs, otherwise the operator) with
`merge-bar/skills/working-a-pr/references/one-way-door.md`. A patch tags after its merge, so it is one-way. The bundled loop
is unchanged. No `lib/` code, no state change.

## 1.27.0

Since 1.27.0, that standing order is read from the project's own files, not a
host policy: `08-governance.md`'s `## Standing orders` section, then `AGENTS.md` for any
kind that section does not settle (a canonical checkout reads its paired AI workspace
through `.workspace/pairing.json`), as the base branch has them: an order a PR's own diff
adds binds nothing in that PR. An order binds only the role it names, and one naming
no role binds no one. `/ossify:start` seeds the section empty; with no order the human
walks, as before. No `lib/` code, no state change.

## 1.26.0

Since 1.26.0, `/ossify:run-spine <spine-id> --external-executor --detach` ends the lane
after it writes a round's requests: it counts no dispatch, validates no result and
closes or merges nothing, and the caller counts each execution and closes the items.
`oss work_item_pr <wi-id> <pr-url>` records an item's PR, and `/ossify:close <wi-id> --pr`
commits, pushes, opens the item's PR into the spine branch, records it and leaves the
item `active`. Re-entry reads such an item as `in-flight` (an `active` item with a
recorded PR and unmerged commits), and a `complete` item with a recorded PR whose
commits are not on the local spine branch halts as `halt:pr-not-local`. The inventory
reads state and git only; it does not ask the forge whether a PR was closed unmerged.
The no-flag command is unchanged.

## 1.25.0

Since 1.25.0 (#831, #832; autopilot slice 1), the merge and the demo walk take a
standing order in the autopilot policy when the session has one. work-pr's
bundled loop, `/ossify:patch` and the spine close merge on the operator's
explicit ack or on a standing order that grants merge authority — the terminus
treats a clean verdict as that ack and the ledger names which order gave it —
and the demo walk hands each `user:` line to the orchestrator: walked itself
against the merged product, evidence recorded per line, marked `walked by
orchestrator` in the read-out, the read-out to the operator, and a failing line
still halts the close. Absent such an order, every site asks exactly as it did
at 1.24.0. No `lib/` code, no state change.

## 1.24.0

Since 1.24.0 (#768, #554), `/start` and `/adopt` author `AGENTS.md`, the one
instruction file: Claude Code loads it when no `CLAUDE.md` exists, and Codex and
OMP read it directly. Neither writes `CLAUDE.md`. `/start` replaces a
workspace-init stub (marker on line 1) without asking; `adopt` merges its loop
section into an `AGENTS.md` that exists, a marked stub included (from 1.35.0 adopt replaces a marked
stub, policy sections carried), and authors one that does not. `doctor`'s
interop check fails on a leftover `CLAUDE.md` at the AI workspace root or in
`.claude/`, and its repair — offered only on the operator's explicit yes, after
showing every change, and never committed — moves or merges that file into
`AGENTS.md`.

## 1.23.0

Since 1.23.0 (#631), `oss feature_add` takes an optional fifth argument, the
intake issue number (`N`, or `'#N'` quoted: an unquoted `#` starts a shell
comment), and stores it on the feature entry as
`issue`; anything else, or an issue on any source but `intake`, is refused at
rc 2, and an entry added before 1.23.0
simply has none. Spine planning reads the request from the entry's `issue`
instead of matching titles, and every spine that takes the feature posts its own
`pulled in — <spine id>` comment. Spine close never closes an intake request: a
feature can span spines not yet planned, so it comments that its spine landed,
names the other carriers and their status, and the operator closes the request.

## 1.22.0

Since 1.22.0, the state verbs refuse new writes onto work that has not landed or
has been retired (#563): `work_item_status <wi> complete` refuses an item that
records no dispatch (rc 7, or rc 4 on a malformed dispatch field with nothing
well-formed beside it), `work_item_add` refuses an abandoned spine, and
`work_item_exec` refuses a dispatch onto an abandoned item or an item of an
abandoned spine. A wipe and every replay are unchanged, so a journal that already
holds such a shape still loads. Four name-only verbs journal a correction (#335,
#305): `oss spine_rename <spine> <name>` (how an internal-enabler admitted after
its spine was minted takes its `[internal]` marker), `oss work_item_rename <wi>
<title>`, `oss bone_set_title <adr> <title>` and `oss bone_set_revisit <adr>
<trigger>` (an empty trigger clears it).

## 1.21.1

Since 1.21.1, `/ossify:adopt`'s completion floor refuses a record with no C2
result line per declared repo: "no C2 gaps" from a clean-checkout pass that
never ran no longer closes (#367).

## 1.21.0

Since 1.21.0, Release 1's spines mint adoption's C6 seed candidates as demo lines:
once, `active`, prefixed `[adoption-seed]`, and outside each spine's own floors
(#293).

## 1.20.0

Since 1.20.0, Release 1 after an adoption reads `ADOPTION.md` before it grooms:
C1's `next` entries are this release's candidates and the `later` ones stay on
the map, deferred (#302).

## 1.19.4

Since 1.19.4, `/ossify:adopt`'s A3–A5 refusals also name how to close a legacy
slice by hand when scaffold-dev is no longer installed (#732), and
`/ossify:start`'s content gate no longer refuses a fresh project because its
declared tooling repo carries history of its own (#553).

## 1.19.3

Since 1.19.3, the dispatched `ossify:implementer-agent` is granted `Skill`, so it
composes `superpowers:test-driven-development` and
`superpowers:verification-before-completion` as the work-item body says, on both
invocation paths (#281).

## 1.19.2

Since 1.19.2, wayfinder's claim re-read runs the frontier query again, so an
assignment that landed after the first read is seen at claim time (#336), and a
`spike` ticket is dispatched only after the operator approves its contract,
which the dispatching session writes before the fan-out (#332).

## 1.19.1

Since 1.19.1, `/ossify:run-spine` prepares each item worktree's dependencies before
the handoff, so a suite that needs `node_modules/` runs there as it does in the
primary checkout (#714). A spec can declare an AC `Expected GREEN at start:`; the
lane copies that line into the handoff, and the RED gate honours it at dispatch 1
instead of after a clarification dispatch (#715).

## 1.19.0

Since 1.19.0, `close` registers the bones a spine's plan **declares**: each row of
`SPINE.md`'s `## Bones this spine registers` enters the bones registry at step 4b,
before the touch check, so the registry `touch_check` reads next matches the plan
that declared it — an already-registered ref is skipped, and a row whose ADR file
the spine never wrote halts naming the ref (#497). The landing pass also stores the
PR's **number** where `gh pr create` prints its URL, halting when what it printed is
not a PR URL (#716).

## 1.18.0

Since 1.18.0, `/ossify:run-spine` dispatches OMP work items via omp-roles' `implementer` agent.

## 1.16.0

Since 1.16.0, a demo line has three statuses beside `active`: `planned` (#363,
#726), so a line authored at plan time no longer reddens every sibling spine's
close before its code exists — `ledger_add_auto` and `ledger_add_user` write
`planned` unless the caller passes `active`, `demo_run` reports planned lines as
`PENDING` beside the pass count, and a spine's close activates its own before its
demo; `deferred` (#710), a spine's own `user:` line the operator cannot walk now,
owed to a named release and collected by `expired_deferrals` at release close; and
`escaped` (#726), a research spine's own `user:` line closed on the negative result
its `SPINE.md` declared at plan time — terminal, and not `retired`. Four new
verbs (`ledger_activate`, `ledger_activate_spine`, `ledger_defer`, `ledger_escape`)
and one new gate; both new line fields ride the existing `set_demo_line_status`
operation, so there is no schema bump and an old journal replays unchanged. The
skills say when to reach for each: plan-spine authors `planned`, the spine close
activates and walks, release close collects the deferrals. The state schema is now
**v4**: an existing project runs `oss migrate` once, and an older ossify refuses v4
state rather than misreading it.

## 1.15.2

Since 1.15.2, ossify's copy of the template says a review stopping rule is never
a bar: `working-a-pr` decides when rounds stop, and a finding that meets a
condition blocks in every round. No state schema, journal operation or command
changes.

## 1.15.1

Since 1.15.1, ossify's copy of merge-bar's PR body template
(`skills/work-pr/references/pr-body.md`) carries merge-bar 0.2.0's seventh field,
`## Merge danger`: the door (whether a revert of the merge undoes all of it) and
the blast radius. `/ossify:patch` writes it on the no-merge-bar fallback. Spine
close composes it per hosting repo, beside Scope and Known limits, only where
merge-bar is installed; without merge-bar a spine PR still carries no template
fields. No state schema, journal operation or command changes.

## 1.15.0

`wayfinder` is both at once: an entry skill with its own skill directory, and an any-repo one. It
charts a question into decision tickets on the issue tracker, or works an
existing map's frontier one ticket per session. The three utilities are skills
too since 1.15.0 (`handoff`, `handoff-resume`, `work-pr`; so is `run-spine`). Their depth lives
in each skill's `references/`, so every harness the plugin ships on has them.

## 1.14.5

Since 1.14.5, ossify no longer describes itself as an alternative to
`scaffold-onboard` + `scaffold-dev`, which left the marketplace. Both manifest
descriptions drop the install-one-or-the-other framing, and doctor's prose no
longer cites `scaffold-onboard` files as live: the interop-repair deferral calls
that repair the retired plugin's, the budget check cites only the upstream issue,
rule authoring no longer names a paired stack, and `start` no longer routes a
one-change amendment to `/amend-spec`, a command only `scaffold-onboard` shipped
(name the section and the edit instead). `/ossify:adopt` still targeted
projects onboarded with the legacy scaffold stack until 1.35.0. No state schema, journal
operation or command changes.

## 1.14.4

Since 1.14.4, ossify ships on two surfaces, Claude Code and Codex. The Devin
plugin manifest, the Devin worker skill and the Devin-only dispatcher rule are
gone, and every skill resolves `oss` with `command -v oss`. Ossify's
resolution blocks fail loud when nothing on `PATH` answers as ossify, instead of
falling through to a Devin plugin-cache search. `critic_detect` no longer reads
the OpenCode wrapper's `OSS_ARCHITECT_CRITIC_ROOT`. The manifest refusal drops
its Devin sentence. No state schema or journal operation changes.

## 1.14.3

Since 1.14.3 (#708), a spine close records a PR that landed by squash or rebase,
for a base branch that enforces linear history: the landed tree must equal the
reviewed head's, and the landed run must sit on a commit the head holds through
one-parent commits only. The record line names its proof (`merge`, `squash` or
`rebase`), and the changed-path list and the cumulative demo compare against the
proved before-point. A merge commit is still the convention where the repo
allows one; a fast-forward or any other shape still halts at record time.

## 1.14.2

Since 1.14.2 (#692, #691, #645, #646, #675), doctor's bones drift check folds
both halves under one scoped C locale, preserving identifiers in findings under
non-C locales. The ADR grammar has one prose authority; the numbering scan
shares its destination predicate and adoption inventory names the repo holding
each ADR. Adoption's fixtures and rubric follow the existing collision halt,
while distinct references from every repo still mint their own entries. Harvest
keeps text-only duplicate identity and names both sources when it skips an entry.
Spine re-entry fails closed on retained abandoned-item dispatch evidence,
unreadable base/ref/status reads, work branches below their recorded base and
occupied non-worktree paths; a branch named `unrecorded` remains a recorded base.
No state schema or journal operation changes.

## 1.14.1

Since 1.14.1 (#648, #647, #649), doctor's bones drift check identifies table
headers structurally, accepts short and aligned delimiter cells, and validates
every data row with the same complete ADR identifier grammar as the registry.
An ADR reference used as a header is reported. Registry records are trimmed and
validated as complete values before line output: surrounding newlines are
whitespace, while blank or internally multiline references refuse comparison.
Digit-free references such as `ADR-C`
compare correctly; malformed rows and duplicates on either half are reported,
with case normalized only for comparison and source spellings kept in findings.
The ADR mint refuses an unset, empty or unscanned destination repo, naming it
rather than guessing a four-digit width. Adoption and mint use one self-contained
scan fence that cleans its temp files on success or refusal; adoption selects
inventory mode without requiring a destination. The prose-contract controls and their routed
fixture setup explicitly clear inherited state overrides.

## 1.14.0

Since 1.14.0 (#133, #362), `/ossify:run-spine` re-enters a started spine on its
own — at the top of every round after the first, and mid-round after a halted
or interrupted run — and there is no resume flag: the same command is the
resume. Before anything mutates it prints a reconcile read-out from the new
read-only `oss spine_inventory` — one row per hosting repo (`fresh`, `ok`,
`base-backfill`, `cut-missing`, or a named `halt:`) and one per work item
(`skip`, `spawn`, `adopt`, `redispatch`, `close-finished`, `finish-merge`,
`finish-status`, `reattach`, `in-flight` (since 1.26.0), or a named halt, among them
`halt:pr-not-local`); any halt row stops the lane
having changed nothing, and the repairable rows are repaired before the resume
round runs. Optional state fields carry what a respawned session cannot
recover from context, and each reads as absent on a journal an earlier 1.x
wrote, so there is no schema bump: `spines[].bases`, recorded by the fresh arm
at cut time with `oss spine_base_set` and read back with `oss spine_base_get`
(a recorded base is validated — it must be a local branch that exists in that
repo — and it is evidence: a different value refuses rc 7, with
`oss spine_base_reset` named as the sanctioned operator correction, journaled
as its own op; it is never re-derived from HEAD, which is the spine branch by
then),
`work_items[].dispatches`, counted with `oss work_item_dispatched` before every
dispatch, so the 3-dispatch cap survives a session loss, and (since 1.26.0)
`work_items[].pr_url`, recorded by `/close <wi-id> --pr` with
`oss work_item_pr`, which re-entry reads to route an item as `in-flight`. `oss worktree_reattach`
re-attaches a work item's worktree whose directory was deleted but whose branch
survives, refusing a branch that is live elsewhere, a locked registration, or a
missing branch — and pruning nothing. On the external seam,
`external-executor.md` §2a binds the caller: it counts each execution the lane
did not request — a correction — with `work_item_dispatched`, reading the count
first and offering halt only at 3 or more; and on re-entry a request for a
`close-finished` item — one this session has not executed — whose worktree
already holds a staged result with `report.md` at request time is verified and
returned without executing — no implementer launched, no dispatch counted. The
1.13 claims that an existing spine branch halts rather than resumes, and that
the base is taken from HEAD, are retired.

## 1.13.4

Since 1.13.4 (#154, #561, #301, #299), four prose defects that only a careful
reader could catch are corrected, and each is pinned red-then-green. doctor's
bones-drift check compares the registry's and the spec's identifier *sets*, so a
mismatch with equal counts in both directions no longer reads clean (#154). Its
touch-surface sweep carries each surface's KIND, so the re-point remedy names
`bone_set_touch` or `risk_gate_set_touch` instead of offering both; it refuses
the run when `$OSS_STATE_FILE` points at another workspace's state instead of
reporting that project's surfaces against this repo's files; it removes its temp
file; and it batches to the system's argument limit rather than one dispatcher
per 200 paths (#561, #558). An adopted ADR series is now readable: the numbering
scan matches either case, the minted width follows the series it finds, an
unreadable `docs/adr/` refuses instead of reading as empty, and a new ADR joins
the repo's existing form rather than starting a second one; harvest's provenance
trailer admits `source: adoption` with the baseline adoption recorded (#301).
The private boundary inventory has one address —
`<ai-workspace>/docs/private-boundary-inventory.md` — the false
`project-state.json` index claim is gone from both sites that carried it,
"composition root" is defined as a path rather than a repo key, and the critic
moment's non-interactive default records that no operator answered (#299). No
`lib/` code, no state change.

## 1.13.3

Since 1.13.3 (#265, #266), `/start` never writes over an existing file. Past its
§3 gates and before `oss init`, it checks every destination — the MASTER-SPEC,
the memory bank, `CLAUDE.md` and the rest — and asks the operator, per occupied
file, to keep it or move it aside (the MASTER-SPEC: move aside or stop); there
is no default and no automatic move or merge. Its §2 ask-first guard fires on a MASTER-SPEC of any schema, not only a
lean one. doctor's and close's `fail: state` remedy names `/ossify:start` or
`/ossify:adopt`, which each run `init`, instead of a bare `init`. No `lib/`
code, no state change.

## 1.13.2

Since 1.13.2 (#628, #579, #552, #296, #397, #342), shipped prose that disagreed
with what ossify does is corrected. Spine close tells you to reconcile a resumed
PR's Known limits with its repo's fields, for a PR opened under 1.13.0.
`/ossify:patch` re-runs its changed-path ledger re-check after each review-fix
round. The never-strand rail's notes name the refusal that did not ship apart
from the `complete` clause that did, and the `active` refusal cites the doc that
carries its closed-spine caveat. `external-executor.md` no longer claims close
fingerprints the four `*_oid` values; adopt counts six gates; doctor names one
write surface; `start` §11 authors the lean MASTER-SPEC before auditing it. The
only `lib/` change is one refusal message's citation and one comment; no state
change.

## 1.13.1

Since 1.13.1 (#614), six prose defects in that lane are fixed. `/ossify:patch`
re-reads the tech-debt ledger for the paths a fix actually changed, and refuses
before cutting anything when `origin` is not a GitHub repository. Spine close
gives each hosting repo's PR only that repo's Known limits, so merge-bar no
longer writes a multi-repo spine's limits once per PR. Release close fetches
tags before listing patches and looks in every declared repo, not only the ones
a spine landed in. A request pulled in at release planning is re-dispositioned
to its spine when a spine takes it, so spine close closes the issue. No `lib/`
code, no state change.

## 1.13.0

Since 1.13.0, work that arrives mid-release has a lane that never reopens a
running spine. A request from another project is an issue in this project's repo
labelled `from:<project>` — the intake queue — which `plan-spine`'s pre-flight and
`plan-release`'s grooming read and give a disposition; `plan-spine` also reads the
tech-debt ledger merge-bar writes for the surface it plans. Once a spine's first
round has started, its work items are fixed. A consumer that needs a provider's
unshipped capability builds glue and records it as an ordinary fake. A defect in
shipped behaviour, or a small request the requester cannot fake, ships through
`/ossify:patch`: reproduce-first or acceptance-criteria-first by kind, a `fix/`
branch off the default branch, a patch version, a PR and a tag. Release close
lists those patches from git. `/ossify:work-pr` follows merge-bar's `working-a-pr`
where merge-bar is installed and the bundled loop otherwise. No `lib/` code, no
state change.

## 1.12.1

Since 1.12.1 (#120, #122, #125, #126), four mutation-side defects are fixed.
The worktree verbs refuse any id that is not a work-item id (rc 2) before they
build a path from it, so `worktree_remove canonical ../../x` can no longer remove
a worktree outside `.worktrees` or delete its branch. A `worktree_add` that git
fails after creating the worktree and branch — a failing `post-checkout` hook is
enough — now rolls both back, so the retry is no longer refused forever; the
rollback removes only what the call created, and keeps (and names) a branch that
has moved off its base. Adds for one work item run one at a time (a lock in the
git common dir; a second add refuses at rc 8), so a rollback never reaches a
concurrent add's worktree. The id check matches the whole argument, so a
multi-line value with a valid first line is refused too. `fake_add` refuses a boundary already in the ledger (rc
7, inside the state lock, like `bone_add` and `risk_gate_add`), because
`fake_status` rewrites every record carrying the boundary; a later spine records
a retained fake as `fake_status … renewed` and a replaced one as
`fake_status … replaced`. A journal that already holds a duplicate still replays.
A malformed `auto:` AC — no backtick pair, or an empty command — now fails
`verify_acs` at rc 3 wherever it sits in the spec, naming the AC, and
`report_cross_check` says so. Before, a trailing one halted close as an
"unreadable spec" and the same row anywhere else was dropped silently.

## 1.12.0

Since 1.12.0 (#529, #528, #533 half A), the never-strand **rail** guards one
transition — the withdrawal. A work item counts as dispatched when it records any
of the three fields the dispatch writer journals — `branch`, `worktree_path`,
`base_sha` — and an item that records one, or that has landed, or whose round is
`active`, is never `abandoned`. That refusal is evaluated **inside the state
lock**, so a concurrent writer's commit is visible to it (the previous read
happened before the lock, which is a check-to-append race with data loss as its
outcome), and it fails **closed** at rc 4 on a dispatch field recorded as
something other than a string rather than reading that as undispatched. One
clause survives on the dispatch write, and it is the clause the withdrawal rail
stands on: a `work_item_exec` whose payload records no dispatch at all is refused
on an item that records one, because erasing the record is how the strand is
entered. Three other refusals do **not** ship in this release (#563): the
mirror refusal (a dispatch onto a withdrawn item), the landed-provenance refusal
(marking `complete` an item that records no dispatch — a different check from the
withdrawal's `complete` clause above, which does ship) and the spine-level
retirement refusal. Two review rounds found another disagreement each time they
were tried; what the release claims is what it enforces. A
duplicate work-item id is named as a duplicate (rc 7, pointing at #305) instead
of being misreported as a state-read failure, and it is refused for every status
rather than for `abandoned` alone. No journal op, payload key or status value
changes: the rail is verb-side, so a journal that already holds an inconsistent
pair still replays clean and `doctor` reports it as drift.

## 1.11.2

Since 1.11.2, the `abandoned` carve-out is complete on the close path, and the
detector the re-point verbs never had ships as a doctor sweep. A work item
withdrawn before dispatch is diagnosed as just that when `/ossify:close` is
pointed at it, instead of being told the execution lane skipped
`work_item_exec` — the two want opposite actions, which is why the status is read
before the diagnosis. Spine close's all-withdrawn halt now names the whole route
out, including the two obligations a retirement carries: the demo-ledger
amendment the withdrawal owes (and for an ordinary active line whose only
implementation was withdrawn, retire-or-replace rather than `ledger_unplan`,
which answers rc 7 there), and any repo armed for that spine. The same gate
refuses a spine with **no** work items — it was never decomposed, and passing
used to move the discovery to a later step — step 5's changed-path guard, or
step 4's demo on a zero-line ledger. Release close halts
when its tag set is empty, instead of recording a release that published nothing.
And `doctor` reports a bone's or gate's touch surface that matches **no** tracked
file in any declared repo — per SURFACE, so a list that is only partly dead still
reads clean: a surface re-pointed at a tree that does not exist reads `clean` on
every path and the spine is never reclassified. The repair has existed since
1.11.0, and now the detection does too.

## 1.11.1

Since 1.11.1, the registries' corrective-append verbs refuse input they would
otherwise silently misinterpret. A re-point or a controls rewrite whose list
carries an entry with leading or trailing whitespace — a CR kept from a CRLF file
is the usual source — is refused at rc 2 and the entry is named with its
whitespace escaped, instead of being journaled as a glob that can never match the
path it was meant to cover; a list with no entry in it at all is refused for the
same reason, on all three verbs rather than the two that had the guard. The two
mint verbs refuse such an entry too, so a bone or gate cannot be *created* with a
surface that silently covers nothing, and a caller who space-splits a list gets a
usage refusal naming the CSV grammar instead of a silently shrunk surface — on
every list-taking verb except `bone_add`: its 4th argument is optional, so no
arity guard can tell a glob from a revisit trigger, and `bones-registry.md`
states where the second word lands instead. And
`bone_add` / `risk_gate_add` refuse a ref that already exists rather than minting
a second row for one key, which had left the operator holding a surface the
re-point verb then refused to repair — that rail runs inside the state lock, so
two ceremonies racing to mint the same key cannot produce the duplicate either.

## 1.11.0

Since 1.11.0, two states the lifecycle could not express have a verb. A work
item minted and then withdrawn before any dispatch is marked `abandoned`
(`oss work_item_status <id> abandoned`): the round walk, spine close, harvest
and release close all skip it, where before it either blocked spine close as
`planned` or recorded a merge that never happened as `complete`. The verb
refuses it on an item that was already dispatched — a recorded branch or
worktree is the dispatch, and withdrawing one would strand its work
(1.12.0 replaces this predicate; see its entry above). And a
bone's or risk gate's touch surface can be **re-pointed** after the code it
covers moves (`oss bone_set_touch`, `oss risk_gate_set_touch`). That is a
correction the caller applies, **not a detector**: nothing here notices that a
surface has gone stale, and a re-point to a glob that matches nothing is
accepted. What the verbs refuse is a list carrying no glob at all. Both are
journaled corrective appends. The op names `set_bone_touch` and
`set_risk_gate_touch`, their payloads `{adr,touch}` and `{name,touch}`, and the
status value `abandoned` are a compatibility contract: live journals written by
an earlier local build already carry them, and renaming an op is what replay
catches (`unknown op`, rc 4). A payload reshape does **not** fail replay, and it
fails in two different ways, so neither mode is a safe default to describe: a
renamed **identifier** key (`adr` → `adr_ref`) applies as a silent no-op — the
surface is left as it was — for a registry whose rows carry their key, where a
row whose key is null or absent is instead matched by the null comparison and
gets its surface overwritten; and a renamed **value** key (`touch` → `surface`)
is destructive — it writes `touch: null` at rc 0, and **one** such row makes
**every** `touch_check` answer `INCONCLUSIVE, not clean` (rc 2), not only the
damaged surface's, because the read is a single pass that the first null aborts.
The payload keys are held by this contract and by the verbs' own tests, not by
replay alone.

## 1.10.0

Since 1.10.0 (#507) Layer 4 always runs inline — the delegated multi-agent engine behind it is
removed.

## 1.9.0

Since 1.9.0, the deterministic gates close the vacuous-green family: the
zero-tests guard no longer inverts a true match past the pipe buffer, flags
only when a zero-marker has no positive-execution marker beside it (an
aggregate suite with one empty target is no longer misflagged), and
recognizes `cargo nextest` plus vitest's `No test files found` and
`Tests  0 passed` phrasings. `oss demo_run` fails a ledger that executed
zero lines - empty, user-only, or all-quarantined - instead of printing
`PASS 0 lines`, and the close ceremony's quarantine check writes its
head/parent evidence into a per-invocation tempdir rather than fixed `/tmp`
paths that collided across concurrent closes.

## 1.8.0

Since 1.8.0, `/ossify:run-spine <spine-id> --external-executor` is an optional,
provider-neutral execution seam: instead of dispatching its own nested
implementer, the lane prepares every same-round worktree and handoff, hands the
round out as one `external_execution_request` per item, and takes back one
`external_execution_result` each. It names no tool, product or model; the caller
supplies the procedure. Everything on either side of that one step is unchanged
— worktrees, handoffs, the return contract, declared-order closes, serial
merges, the round barrier, the 3-dispatch cap. The mode adds no return mode: a
rejected item is repaired through a correction continuation that returns the
same `complete` shape, and Layer 4 runs inline there as it does everywhere.
**On Claude Code, `/ossify:run-spine <spine-id>` with no flag is
completely unchanged** and still dispatches `ossify:implementer-agent`.

## 1.7.0

Since 1.7.0 (#368), every bare `doctor` sweep includes plugin provenance and
`doctor provenance` runs it alone. It reports the answering `oss` binary, the
loaded doctor body, and the expected checkout or Claude installed version
separately. A version mismatch exposes prior `oss` verbs and compares only
product prose actually loaded earlier in the session; it does not scan unused
skills or decide reruns. The guarantee starts after one update and fresh
session. Codex installed-reference resolution remains partial (#399).

## 1.6.0

Since 1.6.0 (#139) `close`'s impl-check gate gains Layer 4: a semantic review over three lenses
(fidelity, pattern, absence) at work-item close, applied inline on every harness.

## 1.5.0

Since 1.5.0 (#339) `work-pr` is also the spine-close merge lane: a spine's hosting repos land on
their base branches by PR where a remote exists (merged locally only where none does), and a release
is a tag on the merged line.

## 1.1.0

`challenge` is the grill and the adversarial critic, absorbed in-tree at 1.1.0:
the bone grill gate, the spec-core close audit, the release class veto, and the
spine plan/close audits all run on ossify alone — no sage install
required. sage remains useful standalone; ossify does not depend on it.
`challenge` is the marketplace's one adversarial audit surface. A close-depth
audit recruits an external fresh-frame adversary when one is configured via
`OSSIFY_ADVERSARY` (`skills/challenge/references/adversaries.md`); unconfigured
means host-only, by declaration.

## 1.0.0

Ossify is in the Claude and Codex marketplaces as of v1.0.0. Plan D's consolidated eval
covers all 10 acceptance scenarios; scenario 10 is a run rather than a standing
fixture, and its second run agreed **5 of 5 with no divergence** after the prose
fixes its first run prompted (#250, #251). That is two runs on one scenario, not
a measured property of the prose — #254 stands over both. The two real-project
pilots are operator-owned and post-v1.
