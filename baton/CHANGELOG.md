# Changelog

All notable changes to the `baton` plugin.

## 0.19.0 - 2026-11-12

The example recipe's spine PR loop gets a cap and a stricter pass edge, and the two after-merge steps that had no actor get one. The engine is unchanged. Closes #931, #1049, #1053 and #1206 (#1053's bar-raise note moved to merge-bar issue #1211).

- **Fixed (#1206, defect 1).** The spine PR loop stops. `spine_work`'s round end copies `review.md` to `review-prev.md`, keeps it as the next free `review-<n>.md`, archives the ruling, and removes `round-done` last. `spine_wait` parks once `review-2.md` exists and `review.md` blocks, or the checks are red (review 3 is the last automatic review), ahead of `checks_red` → `spine_work`, as `item_wait` does. `spine-work.md`: a round that would neither push a commit nor change the PR body is a stop, naming what is left and who must act, with no round done file. r7-s1 cycled 245 rounds on a red check no seat may fix.
- **Fixed (#1206, defect 2).** `spine_ack` only follows a review of the PR's own head. `spine_review` accepts a review only with a 40-hex `head:` on line 2 (as `item_review` does); `spine_wait`'s pass edge also needs line 2 to equal the PR's head; a pass of any other head goes back to `spine_review`, kept as `review-stale-<n>.md` (copied to `review-prev.md` first) and not counted toward the cap. Three stale reviews are kept; the fourth parks `spine_wait` (`review-stale-3.md` exists), so a reviewer that keeps reading an old head cannot loop. The head comes from the `pr` signal's `{pr.head}`, so the engine is unchanged; a head that is not 40 hex is an `exit 2` (park `exit0 error`), never a match.
- **Fixed (#1049).** The `spine_finish` seat writes working-a-pr §5's review-ledger and tech-debt lines for every merged PR of the spine into the AI workspace's `.claude/memory-bank/`, committed with the close record, and writes the harvest candidates to `harvest.md` and under `## Harvest candidates` in the close PR body. It accepts and applies none: the operator accepts, the orchestrator applies (the skill's Close harvest row says so). Both `spine_finish` notices name `harvest.md`; its message gains `Out root`.
- **Fixed (#931).** `common.md`: a seat takes the ledger line's `<UTC time>` from `date -u +%FT%TZ`.
- **Changed (#1053 C7).** `ossify-recipe.test.ts` finds every copy of the archive-and-number snippet and asserts they are byte-identical, per class (plain, item review's `$f`, stale review's); a copy changed by one character goes red.
- **Known limits.**
  - A run armed before 0.19.0 keeps its recipe and briefs: none of the above reaches it.
  - The cap counts reviews, not wall time.
  - A block review of an older head still goes to `spine_work`: only a pass is checked against the head.
  - The no-progress stop in `spine-work.md` is prose a seat follows; baton does not compare heads before and after a round.

## 0.18.1 - 2026-11-06

The example recipe's `correct` outcome archives its packet first and removes its trigger last (#1110). The engine, the briefs and every other stage are unchanged.

- **Fixed (#1110).** `correct` archives `correction.txt` before it removes `corrected`, so a hook failure leaves
  `corrected` in place: a plain `unpark` reads the outcome as true, reruns the hooks from the first and moves to
  `verify` with no second seat, and no second dispatch is spent. In 0.18.0 the first hook removed `corrected`, so a
  failure of the archive hook relaunched the seat on the same packet. Both hooks are safe to rerun. The
  outcome still ends with `rm -f corrected`: the driver brief reads `corrected` as a used packet. No outcome of
  the example recipe now removes a file it reads before its last hook.
- **Known limits.**
  - A crash or host error after the last hook and before the move still relaunches the seat (lane, `correct`,
    `item_fix`, `spine_work`): the trigger is gone by then, and no reorder closes that window.
  - `spine_work`'s last hook is one `rm -f review.md round-done operator.md`. If a per-file permission fault
    makes it fail on `review.md` while `round-done` is removed, a plain unpark relaunches the seat.
  - A run armed before 0.18.1 keeps the hook order it was armed with. There, a `correct` hook failure at the
    archive still relaunches the seat: archive `correction.txt` by hand, then `baton unpark <run> <unit> --to verify`.
- **Upgrade.** Example recipe only; briefs and engine unchanged. Armed runs keep the order they were armed with.
  Apply the swap to each project's `recipe.json` by hand, at any time (swap the two hooks of `correct`'s one
  outcome); it takes effect at that project's next `baton arm`, or on a clone made with
  `baton clone <run> <new-id> --recipe <file>`. Never `cp -r` over a customised copy.

## 0.18.0 - 2026-11-06

A stage that launches again reads its outcomes first (#1100). The engine changes; the example recipe does not.

- **Changed: a relaunch reads the outcomes before it launches (#1100).** Before a session stage launches
  again in a visit where a worker has run, baton reads its outcomes once, before the cap check and the
  `before` hooks. That means: after a no-result, a failed or gone thread or a stall; after a refused or
  orphaned relaunch that followed one of those; or after a plain `unpark` or a driver resume in place of
  such a visit. The unit carries a new `recheck` mark: set when a worker's session ends, kept by an
  in-place unpark, cleared by a launch that starts a worker and by stage entry. A retry after a refused or
  orphaned first attempt is still a first launch, because no worker ran. A match logs `relaunch skipped`
  (`baton report` counts it), then runs that outcome's hooks and takes its move or park, with no seat. A
  first launch (an outcome's move, `unpark --to`, a clone) is unchanged, so `--to <the same stage>` forces
  a fresh seat.
  An evaluation error parks as it would at a seat's end; a `pending` result waits a tick; a matched
  `to: park` outcome parks again. A no-result read in the same tick is not read twice.
- **Changed: wording.** A plain unpark after a `run failed` park reruns the hooks from the first when the
  outcome still reads true; the README and the skill say so. The stop line gains: to make a seat apply a
  ruling, `unpark --to <the same stage>`.
- **Known limits.**
  - If the seat had already written its result when a `stop` parked it, a plain unpark takes the result and
    moves on with the ruling unapplied (a close, spine-open, `item_fix`, `spine_work` or spine-finish stage's
    hook also archives `operator.md`).
  - An outcome whose hooks removed their own trigger before a failure (`correct`: its first hook removes
    `corrected`) reads false afterwards, so the seat relaunches and reruns the round. Reordering its hooks
    is #1110.
  - A result that reads true without the seat's work is taken: this is the check's failure direction, kept
    to visits where a worker has run.
  - A unit whose worker ended under 0.17.4 carries no `recheck` mark, so its next launch is a first launch
    and reruns the round, as 0.17.4 did. This covers a park left open at the upgrade and a relaunch due in
    the upgrade's first tick.
- **Upgrade.** It reaches every armed run at its next tick: the engine reads each run's frozen recipe, so no
  recipe copy is needed. Not changed: the example recipe and its briefs.

## 0.17.4 - 2026-11-06

`spine_finish` no longer takes the AI workspace's local state file as the result of a close (#1095), and the
notifier says why it failed (#1053). The example recipe changes; the engine does not.

- **Fixed: `spine_finish` (#1095).** Its done outcome reads the state file at `origin/main` after a
  `git fetch origin main` in the AI root (`origin/main` is fixed). A local file that reads closed no longer
  ends it. The fetch runs with `GIT_TERMINAL_PROMPT=0`, so git's own credential prompt fails instead of hanging; an ssh remote's passphrase or host-key prompt is not covered. An AI
  root with no `origin` remote, a failed fetch, an unknown spine or a bad file parks
  `exit0 error`. When the seat wrote `out/spine-pr/close-pr.txt` (the AI close PR's URL), the unit goes to the
  new wait stage `spine_close_wait`: it ends done when the PR is merged and `origin/main` reads the spine
  closed, and parks when the PR merged but `origin/main` does not, closed without a merge, conflicts, or
  `close-pr.txt` holds no PR URL. A PR that stays open waits with no timeout.
- **Changed: the `spine-finish.md` brief.** It fetches first; if `origin/main` already reads the spine closed,
  or `close-pr.txt` exists, it ends without rerunning close. In a workspace that lands records only through
  PRs it commits on a branch, opens the PR, writes `close-pr.txt` at once, and switches the AI root back to
  `main`. It never merges the close PR.
- **Fixed: notifier (#1053 C8).** `notify-orchestrator` appends `<iso> <key> notify-orchestrator <where>:
  <reason>` to `notify.log` at each place it failed to deliver: the six bare catches, a stale incarnation, a
  used-up budget and a send Orca did not accept; a pointer file that parses but has the wrong shape; and a
  `fallback_notify` that exits non-zero or times out. Orca's error text is capped at 300 characters. Delivery is
  unchanged.
- **Changed: wording (#1053 C4).** The README and the skill say that after a `run failed` park on a session
  stage a plain `baton unpark` relaunches the seat and reruns the round, and `--to <next stage>` skips it.
  The runbook and the skill gain a `spine_close_wait` row.
- **Tests.** A hung Orca (`FAKE_ORCA_HANG`) ends the notifier inside 30 s with the fallback run; the
  recipe's origin condition is executed on a scratch origin, with a local-only `closed` as its control; the
  end-to-end run covers a close at `origin/main`, a close PR through `spine_close_wait`, and each park.
- **Upgrade.** Copy the new recipe and briefs (`cp -r <plugin root>/examples/ossify-spine ~/baton-recipes/`)
  only when no run is armed or parked there: every armed run reads its briefs from the shared copy. A
  workspace with no `origin` remote parks at finish. Not changed: the archive snippet's ten copies (#1053
  C7; this release adds one) and a relaunch that does not re-read outcomes first (#1100).

## 0.17.3 - 2026-11-05

A sweep of the review findings left on the item review loop and the ruling files (#1079, #1075, #1053).
The example recipe changes; the engine changes only an error text.

- **Fixed: the example recipe's routing.**
  - `item_wait` takes a merged PR to `land` first. Before, a hand-merged item PR with a block verdict sent
    a fixer to a merged branch (#1079 C4).
  - At review 3 the red-checks stop now sits after `closed` and `conflict`, so checks that are still
    pending no longer hold a closed or conflicting PR in `item_wait` (#1079 C3b).
  - Every verdict signal (`item_review`, `item_wait`, `spine_review`, `spine_wait`) reads line 1 of
    `review.md` only. A later `verdict: block` line under a passing review no longer routes it, and a review
    whose line 1 is not a verdict no longer passes the gate (#1079 C5).
  - `item_ready` waits for a `pr_url` shaped like `https://<host>/.../pull/<n>`, not any string, before the
    URL reaches the reviewer's message. A recorded `pr_url` of any other shape or type parks the unit in
    `item_ready` instead of waiting with no route (#1079 C6).
  - A `review.md` that fails the line-1 and line-2 check is kept as `review-bad-<n>.md`. It no longer counts
    toward the three-review cap and is no longer copied to `review-prev.md` (#1079 C1).
  - `regap` is given the item's handoff path, and its brief reads the handoff's `## Clarifications` first, so
    a ruling for an earlier stop reaches it (#1075 PR1076r2 C9).
- **Fixed: engine.** The error for a `merge` stage whose `outcomes` is not an object names `moved` (#1079 C9).
- **Changed: wording.** `driver.md` names every stage with no brief of its own (`item_ready` and `item_moved`
  were missing; a test now derives the list from the recipe). `item-fix.md` tells the seat to write a ruling
  into the PR body, as `spine-work.md` does. `common.md` has the ledger entry quote the ruling instead of
  naming a file that is archived later. The skill gains an `item_moved` row, a `spine_finish` row that is no
  longer `user:`-only, the move-aside clause on the close, spine-open and `spine_finish` rows, and a preflight
  question: the example recipe needs at least one check that runs on item PRs (into the spine branch) and on
  the spine PR, or a unit waits in
  `item_wait`, `spine_wait` or `land` with no park. The README says the same, gives an `item_moved` park its
  own runbook bullet, states that `expect_head` does not itself require green checks, names the character
  mapping of `notices/<key>.md`, drops the retired bridge clause, and no longer reads its list of stages
  that name no Ruling file as complete (`--to` any stage but the one the ruling is for needs the move-aside).
- **Tests.** Mutation-pinned controls replace two that could not fail; every archive hook is pinned to one
  script and every close, `spine_open` and `spine_finish` outcome to its full `run` list; the notifier's
  `accepted:false`, error-envelope and used-up-budget branches have fixtures; wrapped lines no longer break a
  prose pin.
- **Upgrade.** Copy the new recipe and briefs (`cp -r <plugin root>/examples/ossify-spine ~/baton-recipes/`).
  A run armed on an older recipe keeps its snapshot; every armed run reads its briefs from the shared copy,
  so refresh it only when no run is armed or parked.

## 0.17.2 - 2026-11-04

The marketplace is renamed `pulsestack`. The arm skill reads plugin roots from the
`ossify@pulsestack` and `baton@pulsestack` install records, and on a host that has not moved yet
from the pre-rename keys. Prose only.

## 0.17.1 - 2026-11-04

- **Fixed: the example recipe's moved-head loop (#1079 C2).** A review that passed with a `head:` line that
  never matched the PR looped `item_wait`, `land`, `item_review` with no cap and no park. `land`'s moved
  outcome now goes to a new wait stage, `item_moved`: it parks once `review-2.md` exists (three reviews have
  run, the same count `item_wait` caps on), else it goes back to `item_review`. The lane's park list gains
  the stage. `--to land` after a cap park with a moved head now parks in `item_moved`; `--to item_review`
  runs one more review. The README's review-cap wording now holds on both paths.
- **Upgrade.** Copy the new recipe. A run armed on the old recipe is unchanged.

## 0.17.0 - 2026-11-04

Each item PR gets a review loop in the example recipe, and the `merge` stage can pin the head it merges (#1046).

- **Added: engine, `merge` stage.** An optional `expect_head` argv (rendered like `pr`) prints the head to
  merge: 40 lowercase hex, else the unit parks `expect head` (an argv that exits non-zero is retried and
  parks at the third failure). A PR head that differs goes to `outcomes.moved`, which is required with
  `expect_head` and refused without it; the compare runs after the base check and before the checks, and
  `gh pr merge --match-head-commit` takes the expected head. It only adds a stop (skill-first question 3):
  green checks are still required, and a stage without `expect_head` is unchanged.
- **Added: the example recipe.** `close` now goes to `item_ready` (it also writes `pr_url` into the item's
  queue record, mapped to `unit.vars.pr_url`), then `item_review` (new role `item reviewer`, which needs a
  `review` key in its seat row), `item_wait` and `item_fix` (role `work-PR session`, in the item
  worktree). Review 3 blocking, or red checks after review 2, parks in `item_wait`; the cap is counted
  from `review-<n>.md` files because `enterStage` resets launch counts. `land` merges the head named on
  line 2 of `review.md` and sends a moved head back to `item_review`. The lane's park list gains the new
  stages. `item_ready` is a one-tick wait: a session launched in the tick that moved it renders with the
  unit vars read at the tick's start, so `item_review` cannot be entered straight from `close`.
- **Added: briefs** `item-review.md` and `item-fix.md`.
- **Changed: the runbook and skill.** The item review stop, the `item_wait` parks, `item_review` in the
  `--to` list, the `item reviewer` seat row, the merge-stage reference, one Notices row.
- **Upgrade.** Copy the new recipe and briefs, and add an `item reviewer` row (with `review`) to the seat
  table. A run armed on the old recipe is unchanged.

## 0.16.1 - 2026-11-04

A ruling file holds one ruling (#1075 C2). Prose only; no recipe or engine change.

- **Changed: the runbook and skill.** Write the whole current ruling to `out/<unit>/operator.md`,
  replacing any file there; 0.16.0's advice to append handed a relaunched seat an old ruling ahead of
  the new one. Before an unpark `--to` a stage that names no Ruling file, move the file aside as the
  next free `operator-<n>.md`: `--to` runs no outcome hook, and the next seat that reads it would
  apply it. An implement, regap, verify or correct stop takes its ruling in the handoff's
  `## Clarifications`.

## 0.16.0 - 2026-11-04

An orchestrator ruling reaches the close, spine-open and spine-finish stops (#1057).

- **Changed: the example recipe.** The `close`, `spine_open` and `spine_finish` messages name
  `Ruling file: <run>/out/<unit>/operator.md` (`out/lane/` for spine-open, `out/spine-pr/` for
  spine-finish), and each outcome archives it as `operator-<n>.md` with the hook `spine_work` uses.
  `spine_work`'s `Operator file:` label is now `Ruling file:` (same path). No engine change.
- **Changed: the briefs.** `common.md` tells a seat to read a named Ruling file first, apply it, and
  record it as the operator's; `spine-work.md` step 1 says Ruling file.
- **Changed: the runbook and skill** say how to rule a close, spine-open or spine-finish stop.

## 0.15.0 - 2026-11-03

Notices go to the project's orchestrator session, not the phone (#1045).

- **Added: `baton notify-orchestrator <key> <message>`**, for the config's `notify` argv. The run is
  the key's first segment when that is a run on this host. It writes the notice to
  `<state>/runs/<run>/notices/<key>.md` (mode 600) and sends the registered terminal one
  `[crew message baton]` line that names the file, with `orca terminal send --enter --wait-submit 5`;
  no seat-written text is in the line. A queued receipt counts as sent. A host-wide key
  (`auth/<day>`, `down/<day>`), no pointer, an Orca restarted since the pointer was written, or a
  failed send runs `fallback_notify`. All of it stays inside notify.ts's 30 s bound.
- **Added: `baton orchestrator <run> [--clear]`**, which writes or removes the run's pointer
  `<state>/runs/<run>/orchestrator` (`{handle, incarnation}` from `$ORCA_TERMINAL_HANDLE` and
  `$ORCA_RUNTIME_SOURCE_INCARNATION`; refused when either is unset or the run does not exist).
- **Added: the config's optional `fallback_notify`**, an argv validated and rendered like `notify`.
- **Changed: the example recipe keeps what a round learned.** `spine_work`'s outcome copies `review.md`
  to `review-prev.md` and archives `operator.md` as `operator-<n>.md` before it removes the signal
  files, and `spine_review` is told `previous: <that file>`; its brief says a missing file is round 1.
  The work-PR brief has the seat write an operator ruling into the PR body. The `spine_ack` notice no
  longer names a phone Merge button.
- **Changed: the skill** has a `## Notices` section (what to do on each notice) and no longer says to
  spend no tokens after arming or to rely on bot-on-openbot; the README drops OpenBot as the notice path.

## 0.14.0 - 2026-11-02

A seat's question always reaches the operator: triage is removed (#1023).

- **Changed: a seat's question is never tried by a model first.** On Orca, the only host since 0.6.0,
  `OrcaHost.status` never set `pending` and the host had no `respond`, so a recipe's `triage` stage
  never launched and a waiting seat went straight to the blocked park. That is now the only path. The
  blocked park no longer checks for a request or a live triage, and the phone path (`baton screen`,
  `baton answer --park <at> --screen` and `--screen-text`) is unchanged.
- **Removed: the `triage` stage and everything behind it.** The recipe's `triage` field and its
  validation, the `{pending.*}` placeholders, the `second prompt` and `triage gave no answer` parks,
  the `pending`, `triage`, `triage answered`, `triage relaunch` and `triage dropped` events, `triaged`
  and `triage` on a unit, the triage counters in `baton report`, `pending` on the host's status and
  `respond` on the host interface. The example recipe loses its `triage` stage and `briefs/triage.md`;
  `briefs/common.md` no longer tells a seat to read a triage note.
- **Removed: `baton answer <run> <unit> <label>`.** Only the triage brief used it, and on Orca it always
  refused. Any other argument list than the two `--screen` forms is rc 64 (usage). A park event no
  longer carries `questions`.
- **Kept, so a run armed before 0.14.0 goes on: legacy `triage` is tolerated.**
  - A recipe with a top-level `triage` key validates and loads: the key is not checked, its strings are
    not walked for `{pending.*}`, and the stage never launches. This holds for `baton validate`,
    `baton arm`, `baton clone` (`recipe_sha256` is taken from the bytes as they are) and the tick, which
    reads the run's own `recipe.json`.
  - A `seats.json` with a `triage` role is accepted, and a recipe no longer needs one.
  - A `run.json` with `triaged` or `triage` on a unit loads. Neither field is read or written: they stay
    in `run.json` as they were until the run ends, and a clone drops them. A triage thread live at the
    upgrade is not ended by baton: its claim and directory stay until you close them.
  - A unit already parked for `second prompt` or `triage gave no answer` unparks with `baton unpark`
    as any park; `baton report` counts only the events it names and passes the old triage events.
- Known limit: the host interface and status no longer carry a structured request. A host that can read
  one needs a new design, not the old stage.

## 0.13.0 - 2026-11-01

Answer and interrupt Claude Code and Devin seats (#998).

- **Added: picker kinds `claude-ask` and `devin-ask`.** `baton screen` reads them and `baton answer
  --screen` and `--screen-text` answer them, with keys measured on Claude Code 2.1.316 and Devin
  3000.11.234: a digit selects, since both pickers wrap and an Up count reaches no fixed row. Two
  questions in one call, multi-select and a typed draft read as no picker, as before.
- **Fixed: a Devin seat on a question reads as blocked.** Its agent row stays `working`, so baton saw
  an active seat and the stall clock ended it. The host now reads `programStatus: blocked` on a
  `working` row as waiting, so the question reaches the operator at once.
- **Changed: an interrupt is per agent.** A Devin turn at work gets two Escapes in two sends, since one
  does nothing. Every other case still gets one.

## 0.12.0 - 2026-11-01

A supported way to clone a run (#974).

- **Added: `baton clone <run> <new-id>`.** It replaces the hand copy of a run directory, which went
  wrong three ways: `units` written as an array, `spine/` copied so a closed unit's seat launched
  again, and a live session or request record carried into the copy. A clone holds `run.json`,
  `recipe.json`, `seats.json` when the source has one, one `cloned` event and empty `queue` and
  `out`. Units stay an object. Each unit is rebuilt from an allowlist of fields (identity, stage,
  file digests) and starts a fresh visit to its stage, so a field added to a unit later is dropped
  from a clone until someone lists it. The recipe digest is taken from the bytes the clone holds.
  Flags: `--recipe` (re-pin), `--param`, `--reset <unit>[=<stage>]`, `--fresh`.
- **Added: a clone starts parked for `cloned`, and the tick does nothing for such a run.** A park
  only stops launches, so a parked run would still read sources and merge. A clone could otherwise
  start work the operator did not ask for. `baton unpark <new-id>` starts it. Clone never installs
  the timer.
- **Changed: `baton report` counts a `cloned` event as the start of the run.**
- Skill-first question 2: mechanical work on baton's own closed state (`run.json`, `recipe.json`,
  `seats.json`). Clone reads no open input and judges nothing. The new-id check is `arm`'s, shared.
- Known limits: clone does not refuse a clone alongside an armed run of the same project. Baton has
  no such rule in code (`arm` does not check; the skill's preflight does), and which param names
  the project is recipe-specific. The clone is parked, so the check is made before `unpark`.

## 0.11.0 - 2026-11-01

A stop park says where its reason is (#1018).

- **Added: `stop_file` on a `stop` park's event.** The stage's stop file, rendered: the path only,
  never its text, which a seat wrote. A notifier reads the file itself. Other parks carry none.
  `bot-on-openbot` 0.3.0 shows it. Baton parses no stop text and decides nothing from it (skill-first
  question 2: it renders a path from the recipe's own template).
- **Changed: the example lane's brief writes a round barrier plainly.** A halt `no spec for <work item>`
  (a spine planned one round at a time) is a stop whose file starts `round barrier: the next round is
  not planned yet`, says to plan it with plan-spine and then unpark, and says an unpark before the
  specs exist stops again; the halt line follows. Additive: `recipe.json` is unchanged, so an armed
  run keeps its pinned recipe, and a stop file in the old wording still shows as it is.
- **Docs: the runbook names the round barrier.**
## 0.10.2 - 2026-11-01

Three small fixes found in the #993 live acceptance.

- **Changed: bare `baton status` names each row's run and heads the columns (#1001).** Rows
  were `<unit> <stage> <launches> <stalls> <parked> <thread>` with no run id, so rows of different
  runs could not be told apart. The bare form now starts each row with the run id and prints a
  header line first. `baton status <run>` is unchanged: no run id, no header. The README names the
  columns. Nothing in this repo parses the output.
- **Changed: the skill's preflight checks who walks a spine's `user:` lines (#1003).** When the
  spine has such a line and no standing order names the `spine_finish` seat's role, the proposal
  says the run parks after the merge until the operator walks the lines or an order is added. It
  warns and does not stop the arm.
- **Documented, no code change: a driver launch can leave a project-scope row in
  `~/.claude/plugins/installed_plugins.json` (#1004).** Claude Code writes it at startup, from the
  launch directory's tracked `.claude/settings.json`. baton cannot prevent it. See Known limits in
  the README.

## 0.10.1 - 2026-11-01

Each verify round leaves its record (#1005). `examples/ossify-spine` moves the last verdict to
`out/<unit>/verdict-<n>.json` before the next verify, and a used packet to
`correction-<n>.txt` on the way back to verify. An operator can read what the verifier said in
round 1. `verify.md` still holds only the last pass.

## 0.10.0 - 2026-10-30

Seats from crew's config, any harness, a `verify` stage (#993).

- **Added: a stage `role` (crew role names verbatim).** A session stage, `triage` or `driver` with a
  `role` needs no `instance` or `model`; `recipeRoles` lists a recipe's roles.
- **Added: the role table and `baton arm --seats <file>`.** One JSON object keyed by role (`agent`,
  `argv`, `brief_delivery`, `expected_model`, `effort`, `env`, optional `review`; schema in the
  README). `arm` validates it, copies it byte for byte to `<run dir>/seats.json` and records
  `seats_sha256`. A recipe that names roles refuses to arm without `--seats`, and a role the table
  lacks refuses with `role table has no role "<role>" (stage <stage>)`, writing no run directory.
  Extra roles are allowed. `BATON_ROLE` and `BATON_ROLE_TABLE` are refused in a table's and a
  stage's env.
- **Changed: the engine launches a role stage on its role's agent.** The claim gets the role's env
  with the stage env over it (the stage wins), plus `BATON_ROLE` and `BATON_ROLE_TABLE`; a message may
  use `{agent.name}` and `{agent.review}`. A missing or invalid table, or a missing role, parks the
  unit `launch failed` (a driver escalates); no attempt is counted.
- **Changed: `bin/baton-seat` execs the table's argv** with no shell: the message as the last
  argument (`inject`, at most 131071 bytes) or `Read <state>/briefs/<nonce>.md and follow it.`
  (`file`; `/` in the nonce is written `%2F`). New refusals `norole`, `noargv`, `notable`. A claim without `BATON_ROLE` still execs
  `omp-seat` from `OMP_T3_SEAT` and `OMP_T3_VIA`, so staged recipes run unchanged.
- **Changed: the example recipe.** Every session stage, `triage` and `driver` names its crew role;
  `instance`, `model`, the `OMP_T3_` keys and the `via` param are gone. The item flow is
  implement → verify → close → land, and correct → verify (`reclose` is removed). `verify`
  (role `verifier`, `build` slot) writes `out/<unit>/verdict.json` (new `briefs/verify.md`), and close
  runs with `--verdict`. `spine_review` runs `{agent.review}`. The briefs name each skill for both
  harnesses (`/<plugin>:<skill>` on Claude Code, `skill://<skill>` on OMP).
- **Changed: `running-a-spine-on-baton`.** A seat step reads `.crew/roles.md` and
  `~/.claude/crew/agents.md`, picks one agent per role, turns a plain-program `command:` into an
  argv (a shell function or alias is a question; a Devin argv ends with `--`), drops the PR
  placeholder from `review:`, and shows a stage/role/agent/command/model/effort table with the arm
  command. A role with no row is one question and arms nothing. The seat file is written only after
  the yes. `via` is gone.
- Known limits: triage can answer, and baton can interrupt, only an OMP seat's prompt, so a stuck
  Claude Code or Devin seat stalls into a stop; a close resumed after its commit halts on a stale
  verdict; untracked files left between `verify` and `close` halt close on a stale verdict (fails
  closed).

## 0.9.0 - 2026-10-29

The follow-ups triaged on 2026-10-29: #920, #906, #930, #908, #969 and three items of #899.

- **Fixed: a malformed `run.json` is refused (#920).** `readRun` refuses a run.json that is not an
  object, whose `id` is not its directory name, whose `status` is not `armed`, `parked`, `disarmed`
  or `done`, or whose `units` is not an object of objects keyed by their own id. Before, an array of
  units loaded, lost every unit on the next save and replayed the unit files. The CLI prints the
  real error (rc 2) instead of "no such run"; the tick reports it; the file is never rewritten.
- **Changed: a hook-failure park names its hook (#906).** `before failed`, `after_launch failed` and
  `run failed` (a merge stage's `run_after` too) add `hook` (1-based) and `argv` to the park event
  and end the notice with ` — hook <n> (<program>)`; the rendered arguments, which may hold a
  param's value, stay in the event and never leave the host. The reasons are unchanged,
  so the driver guard and `driver.md` still match. A driver's escalate notice keeps the suffix.
- **Fixed: Orca message files of refused launches are removed (#930).** New optional
  `Host.endRun(runId)`: the Orca host removes the run's files under `<state>/orca/messages/` when the
  run finishes and on `disarm`.
- **Changed: a `thread gone` park points at `seat.log` (#930).** New optional `Host.goneNote()`; the
  Orca host's names `<state>/claims/seat.log`, where a launcher refusal is logged.
- **Changed: a blocked park's screen tail keeps the picker's question (#930)** when it scrolled out of
  the last 12 lines, for the pickers `parsePicker` reads.
- **Changed: the park event leaves `questions` off when the list is empty (#899).** A test pins that a
  plain `unpark` keeps a unit's triaged request ids.
- **Changed: the example recipe (#908, #899).** `correct.md`, `spine-work.md` and `lane.md` end
  with a numbered step that writes their done file with the exact command. The spine PR's ack
  notice names the phone's Merge button.
- **Fixed: `baton-seat` refuses a message it cannot read after its checks (#930)** (`nomsg`),
  instead of launching the seat with an empty prompt: a disarm's message cleanup could race a
  launch.
- **Changed: `running-a-spine-on-baton` (#969).** The bridge check reads baton's `notify` argv and the
  bridge version; the agent check reads `agents[<repo>]` first; `oss` comes from the project's
  install entry; roots fall back to `oss repo_root`; the preflight checks one `target_repo`, the
  recipe copy's first use and `~/.local/bin/baton`; values are quoted; a yes that changes a value
  shows the command again; the arm is confirmed from `run.json`.
- **Added: `tests/skill.test.ts`** pins the skill's approval stop and no-watch rule and the done-file
  briefs' last step.
- Known limits: per-hook labels are not offered (index and program only); the question is kept only for
  pickers `parsePicker` reads; `{pending.questions}` still renders `[]` for an empty list.

## 0.8.0 - 2026-10-29

baton's first skill: a project's orchestrator can take a planned ossify spine to an armed run
without this marketplace's workspace memory (#964).

- **Added: `skills/running-a-spine-on-baton/SKILL.md`.** Prose. A read-only preflight (the spine
  is planned, no run of this project is armed or parked, the bot-on-openbot bridge is up, the
  project's OpenBot agent, both repos in Orca, the shared recipe copy against the installed
  example), then the full `baton arm` command with one source line per value, then a stop for the
  operator's yes. After arming: no watching, status only on request, and the README runbook for
  parks. The skill points to this README for the commands, the arm example and the runbook.
- Known limits: the `ossify-spine` example recipe only. The seat model `via` comes from the
  operator's current rule, so a project with no recorded rule gets a question. No Codex manifest.

## 0.7.0 - 2026-10-27

A blocked park can be answered from outside the Orca terminal, through a screen check that only
refuses (README, "Answering a blocked park").

- **Added: `baton screen <run> <unit>`.** One JSON line `{park_at, thread, screen, picker}` for a
  unit in a blocked park: its screen read now and the picker parsed from it, or `picker: null`. No
  lock, nothing sent. rc 2 when the unit is not in a blocked park (or the run is disarmed or done,
  an `unpark --to` is in flight, or the host has no `screen`).
- **Added: `baton answer <run> <unit> --park <at> --screen <n> <label>` and
  `--screen-text <text> --question <line>`.** Under the store lock, they read the screen again and
  send the picker's fixed keys only while the same blocked park and the same option label (or
  question line) are on screen. Every failed check is rc 2 with one line and nothing sent.
  `--screen-text` refuses empty text and any control byte. Events: `answered` with `screen` and
  `label`, or `screen_text: true` (the text is not logged). The three-argument form is unchanged.
- **Added: `src/picker.ts`.** `parsePicker` reads one live picker of two kinds, omp's `ask` box and
  its numbered `/review` box, and only a box with a `⏎ select` footer (the `ask` call above it and
  answered pickers read as none). `keysFor` and `textKeys` are the key sequences recorded on
  omp v18.11.3 (Up over every row, Down to the row, Enter; free text through the Other row).
- **Added: `Host.keys?(threadId, text)`.** The Orca host sends the text unchanged with
  `orca terminal send --text`; a gone terminal is `AnswerRefused("terminal gone")`.
- Known limits: other picker shapes read as no picker; free text needs an Other row; the check and
  the send are separate Orca calls.

## 0.6.0 - 2026-10-27

Orca is the only host (operator ruling 2026-10-27: no move back to T3).

- **Removed: the T3 host.** `src/hosts/t3.ts`, its login (`t3-login.ts`) and its MCP client
  (`mcp.ts`) are gone, with the `baton t3 login | token-status | call` subcommands, the tick's T3
  token-expiry notice, and `bin/omp-t3-claim` (the T3 claim launcher). `bin/baton-seat` reads the
  same claim files and stays.
- **Changed: the default host is Orca.** No `host` key, or `"host": "orca"`, selects it. Any other
  value, `"t3"` included, now fails `arm` and the tick with `config: host must be "orca"`; a config
  that still names `"t3"` must drop the key or set it to `"orca"`. The `t3` config block is no
  longer read.
- **Changed: the host-auth notice is host-neutral.** A host that refuses its credentials notifies
  `host auth rejected: <error>` once a day (was the T3 text `t3 token rejected — run baton t3
  login`). Orca raises no auth error, so this path is kept for a future host.
- **Example recipe.** Every stage drops `OMP_T3_DROP_T3_MCP` (it only told `omp-t3-claim` to
  remove T3's MCP extension). The README's T3 sections (login, the `omp-t3-claim` symlink, the loss
  against T3) are gone; Install links only `bin/baton`.
- **Kept, unused on Orca:** the host interface's optional `respond` and `pending`, triage, and
  `baton answer`. Orca reports no structured question, so a triage stage never launches there and
  `baton answer` refuses with rc 2; they stay for a host that can answer.
- Known limits: the claim keys keep their T3-era names (`OMP_T3_SEAT`, `OMP_T3_VIA`), because
  renaming them would break recipes already staged. A staged recipe that still sets
  `OMP_T3_DROP_T3_MCP` passes it to the seat as a plain variable that nothing reads.

## 0.5.0 - 2026-10-27

- **Orca host.** `"host": "orca"` in the config (`"t3"` is the default and stays so; any other
  value fails `arm` and the tick with `config: host must be "t3" or "orca"`) runs workers in Orca
  terminals. `baton tick`, `disarm` (which closes kept threads) and `answer` build the host from
  that key; the `baton t3` subcommands stay. An optional `orca` block gives `cli` (default `orca`
  on `PATH`, else `~/.config/orca/cli/bin/orca`) and `launcher` (default baton's own
  `bin/baton-seat`). A thread is a terminal and its id is the terminal handle. The T3 token-expiry
  notice runs on the T3 host only. The T3 host is unchanged.
- **`bin/baton-seat`**, the launcher an Orca terminal runs: it reads the claim for its working
  directory, then execs `omp-seat <seat> --via <via> <message>` with an argv. It refuses with exit
  78 (one line on stderr, one in `claims/seat.log`) on no claim, a bad claim line, a claim with no
  seat or via, a message file that is missing or 131072 bytes or more, or an `omp-seat` it cannot
  run (the message file stays); it deletes the message file after reading it. No message text
  passes through a shell: only the working directory, state dir, launcher and message-file paths
  do.
- **Orca status** comes from recorded Orca 1.4.238 replies: a terminal not listed is `gone` only
  when `terminal read` confirms it (a terminal-gone error or status `exited`), else host down; an
  agent `working` is `active`; `waiting` or `blocked` is `waiting`; `done` is `completed`, or
  `interrupted` when Orca says so. A missing agent row or any other value is `active`, never
  `completed`. A truncated `terminal list` or `worktree ps` reply, or one that does not cover the
  local host, is host down, not `gone`. Interrupt sends Escape (`terminal send --interrupt` does
  not stop an omp turn).
- **Optional host methods `close`, `screen` and `respond`.** On a host with `close` (Orca), every
  session end closes its terminal before the launch directory is released, except a park (kept until
  `unpark` or `disarm`) and an end after an `interrupted` status (kept until the run ends). Triage,
  driver and molt-parent threads are closed too. The T3 host defines `respond` only: its sessions
  end as in 0.4.0.
- **Blocked park** (only on a host with `screen`). A worker in `waiting` with no structured question
  parks at once and keeps its session and terminal; nothing is interrupted and the claim and
  directory stay. The notice reads `baton <run>/<unit> blocked in <stage> (project <project>): the
  worker waits on a question — answer it in the worker's terminal — screen: <tail>`. The park clears
  itself when the worker moves on. `baton unpark <run> <unit>` clears it by hand and `--to <stage>`
  ends the session and moves the unit. A stop file wins over a blocked park, and `disarm` closes the
  worker. No driver takes it, no stall clock runs on it, and the run summary counts it as "sent to
  you".
- **`baton answer <run> <unit> <label>`** answers the unit's pending question by the option's exact
  label (rc 0 sent, 2 refused, 3 host auth, 4 host down). It answers one question with one option:
  a request with several questions or a multi-select, an unknown label, no pending request or a host
  with no `respond` is refused. The example recipe's triage brief now uses it in place of the raw
  T3 tool, and the triage message carries `{run.id}`.
- **Narrowing.** A T3 request with several questions used to be answerable by triage through the raw
  T3 tool; `baton answer` refuses it, so triage writes a note instead.
- Known limits on Orca: a picker opened between turns reads `done`; an aborted omp turn reads
  `completed`; a worker in an `ask` dialog or with a live async subagent may keep running after
  Escape, and a park keeps its terminal, so it can run until `unpark` or `disarm`; `disarm` leaves
  live (non-parked) workers running, with their terminals and per-launch worktrees; after an Orca
  restart a live worker reads `active` until its next hook event. Orca gives an omp question's
  text but not its options, so an Orca host has no `respond` and triage cannot answer there.

## 0.4.0 - 2026-10-25

- A recipe may carry a top-level `driver` stage. When a unit parks, a driver session reads the
  unit's state file and writes one JSON result: resume (optionally `to` a stage `resume_to` allows,
  with a `cleared` name from `clearing`), escalate, or stop. Baton checks the result's closed shape;
  any refusal, a launch failure or a timeout becomes an escalate. A unit that parks again after one
  driver resume goes to the operator. Events: `driver`, `driver resume`, `driver escalate`,
  `driver stop`, `driver dropped`. Each result appends a ledger line. The driver's `state_file` and
  `result_file` must contain `{run.dir}` or `{run.id}` and `{unit.id}`, `result_file` the launch
  number `{driver.launch}`, and the two must differ:
  baton reads only the result file rendered for that launch, and removes it once a valid result is read.
- With a driver, the escalate is the only unit-park notice
  (`baton <run>/<unit> parked in <stage>: <reason> — <action>`, with the PR suffix of a merge-stage
  park); a driver stop parks the run with its own notice.
- A finished run sends one silent summary line (units, merged PRs, parks, drivers, wall time).
- `unpark` and `disarm` drop a live driver and release its claim.
- `baton unpark` of a `stop` park consumes its stop file, for every recipe: the file is renamed
  `<stop>.consumed-<iso>` and the `unpark` event records `consumed`.
- The ossify-spine example recipe gains a driver and `briefs/driver.md`: it settles flaky-CI
  (`rerun-check`) and dispatch-cap (`remove-file`) parks only.
- A recipe without a `driver` stage sends every park notice as before; the run-end summary and
  the stop-file consumption on `unpark` apply to every recipe.

## 0.3.2 - 2026-10-24

- A merge-stage park by the `red` or `conflict` outcome names its PR. The `park` event carries `pr`
  (the URL), `pr_state` (`red` or `conflict`) and, for red, `failing` (the red checks by name: a check
  run's `name`, a status context's `context`, once each). The notice ends with
  `— red: <checks> — <PR URL>` or `— conflict — <PR URL>`. Every other park is unchanged.

## 0.3.1 - 2026-10-23

- The `notify` argv now also renders `{key}`, the notice's one-line key (for a park,
  `<run>/<unit>/park/<at>`), alongside `{message}`.
- The `park` event now carries `thread` (the parked seat's thread id, when it had a session) and,
  for the `second prompt` and `triage gave no answer` parks, `questions` (the pending request's
  questions, as a JSON string). Both are absent when unknown.

## 0.3.0 - 2026-10-23

- Triage: a seat that waits on a prompt no one will answer (an OMP `/review` picker, a question
  tool) no longer just stalls. The T3 host reports a thread's pending user-input request
  (`ThreadStatus.pending`, from `thread.pendingRequestCount`). The engine pauses that seat's stall
  clock and, when the recipe has a top-level `triage` stage, launches one triage session per
  request id per stage visit. The stage takes the launch fields plus `note_file` and
  `stall_minutes` (default 10); its message may use `{pending.thread}`, `{pending.request}`,
  `{pending.questions}` and `{pending.stage}` (`note_file` may not). `stop_file`, `watch`,
  `before` and `after_launch` are accepted and ignored there; no other stage may then be named
  `triage`.
- New events: `triage`, `triage answered`, `triage relaunch` (the triage left a note, so the seat
  is relaunched and counts toward the two-stall park), `triage dropped`, and `pending` (a request
  seen by a recipe with no triage stage). New parks: `second prompt` (another request after the
  triage) and `triage gave no answer`. A stop file the triage writes parks `stop` as before.
  `baton report` counts `triage`, `triage answered` and `triage relaunch`.
- Example recipe `ossify-spine`: a `triage` stage and `briefs/triage.md`; `common.md` has every
  seat read a `triage-note.md` first, its ledger wording is fixed, and `spine-finish.md` now
  pushes the AI record. The MCP `clientInfo.version` string now reads 0.3.0.
- README: the triage runbook.

## 0.2.1 - 2026-10-23

- Example recipe `ossify-spine`: `spine_review`'s message now puts a space, not a newline,
  after the PR URL. OMP splits a slash command's arguments on spaces and tabs only, so the
  newline joined the URL to the next word, `/review` failed to parse it, and the seat opened its
  interactive Review Mode picker under T3 and stalled (#894). A recipe test pins the URL as
  `/review`'s own argument. The MCP `clientInfo.version` string now reads 0.2.1.

## 0.2.0 - 2026-10-23

- Example recipe `examples/ossify-spine/`: runs an ossify feature spine end to end on T3 — the
  detached run-spine lane, one implementer per work item, gap re-entry, close and correction,
  ordered merges onto the spine branch, the spine PR's review rounds, and the spine close — with
  its briefs (prose; one `common.md` every seat reads first). No engine behaviour change; the MCP `clientInfo.version` string now reads 0.2.0.
- README: the "Example: an ossify spine" section — the arm command and the operator runbook.

## 0.1.0 - 2026-10-22

First release.

- Engine: a recipe (validated, frozen at `arm`) drives units through stages; `baton tick` launches
  sessions when a unit is due, reads closed signals, and merges a pull request only by the
  recipe's rule, with parking, `unpark`, `status` and `report`.
- T3 Code host over the tailnet `/mcp` endpoint, and `baton t3 login` (OAuth with PKCE, token
  file mode 600).
- `omp-t3-claim`, the launcher that applies a claim file before starting `omp-t3`.
- systemd user timer: `baton timer install|remove`, installed by `baton arm` unless `--no-timer`.
