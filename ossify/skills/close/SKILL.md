---
name: close
description: Use when the user says close work item r1.s2.w3, close the spine, close spine r1.s2, close the release, run the close ceremony, run the impl-check gate, or /close <id> — one skill, three scopes, routed from the id shape. Not /plan-spine, /plan-release or /work-item.
---

# close

You are ossify's **close ceremony** (spec §6, §6.1, §6.2). One skill, three
scopes, and the scope is decided by the id you were given — never by asking.

`oss` (the dispatcher over `lib/*.sh`) supplies the mechanical facts: which shape
an id is, whether a command exited as declared, whether a report accounts for
every AC. The judgment — is this deviation acceptable, does this diff violate a
documented pattern, is this failure the code's fault or the criterion's — happens
here, in your reasoning. Do not stuff it inside `bash -c '...'` wrappers.

---

## 1. Overview and when to use

Where it sits: `start` → `plan-release` → `plan-spine` → execution (`work-item`)
→ **`close` (you are here)**.

Three scopes, innermost first:

| Scope | Id shape | What it closes |
|---|---|---|
| Work item | `r<N>.s<K>.w<J>` | one implementation unit: the gate, the commit, the merge into the spine branch |
| Spine | `r<N>.s<K>` | the spine: cumulative demo, critic, retro, harvest, cleanup (§5) |
| Release | `r<N>` | the release: full `user:` walkthrough and the blocking findings (§6) |

**The guarantee, and it is structural:** *core rows are never skippable in either
class — this skill executes a fixed checklist, not a judgment call* (spec §6.1).
Bone and flesh differ in the **depth** of the optional rows (grill gates, critic
depth, retro length), never in whether a core row runs. When a step in a
reference says **halt**, the ceremony stops there: no later step runs, nothing is
recorded, and the recovery is the user's to pick.

**Trigger phrases (description-match):**

- `/close <id>` (slash command — see §9 for the `$ARGUMENTS` bridge)
- "close work item r1.s2.w3", "close the spine", "close spine r1.s2", "close the
  release", "run the close ceremony", "run the impl-check gate"

**Do NOT auto-invoke when:**

- The user wants to decompose a spine, author a spec, or author demo criteria —
  that is `/plan-spine`. You *run* demo lines; you never author or edit one.
- The user wants to select spines for a release, phrase exit criteria, or declare
  a class — that is `/plan-release`.
- The user wants to execute a work item from its handoff — that is `/work-item`.
  You never run the implementer's loop, and it never runs your gate.
- **No id was given.** Refuse and list what is open rather than guessing; see §2.

---

## 2. Routing

The scope is derived **mechanically from the id's shape**. Never ask which scope
the user meant, and never infer it from the wording of the request.

Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next.

```bash
id="<the id from $ARGUMENTS>"
parts="$(oss id_parse "$id")" || parts=""
scope="$(printf '%s\n' "$parts" | awk '{print $1}')"
```

`oss id_parse` echoes **one space-separated line whose first field is the scope
and whose remaining fields are the numeric components** — `r1.s2.w3` yields
`work_item 1 2 3`, `r1.s2` yields `spine 1 2`, `r1` yields `release 1`.

**Route on the first field only.** Comparing the whole line against the bare word
`work_item` never matches, because the numeric components are on the same line.

| `scope` | Go to |
|---|---|
| `work_item` | §4 (`--pr`: §9) |
| `spine` | §5 |
| `release` | §6 |

**An unparseable id exits rc 1 with empty stdout *and* empty stderr.** The lib
says nothing at all, so the one-line error is yours to emit — name what was
passed and show the three shapes:

> `close`: `<what was passed>` is not an ossify id. Work item `r1.s2.w3`, spine
> `r1.s2`, release `r1`.

**With no id at all, refuse and list what is open** — `oss spine_list`, or
`oss get` with a status filter. Do not close "the current thing": a close run
against the wrong scope is expensive to undo and every step of it looks fine.
And if what arrived is a change to **any declared repo** belonging to no open
spine or work item — a typo fix, a doc touch-up — it is not a close at all:
run §3's pre-flight (the lane reads the registries and mutates state too),
then route it to the patch lane (`references/patch-lane.md`), which resolves
and records which declared repo the patch targets, never a forced ceremony.
A defect in **shipped** behaviour, or a small request another project cannot
fake, is not a close either: it is `/ossify:patch`, a versioned patch by PR.
An AI-workspace edit needs no lane — no ceremony governs that repo.

Full routing rules — the id grammar, the no-argument refusal, the shapes that are
deliberately not ids, and the routing anti-patterns — in
**`references/routing.md`**.

---

## 3. Pre-flight (common to all three scopes)

Runs before any scope's first step, every time.

```bash
oss manifest_require || exit 0        # refuse: run /init-workspace or /pair-workspace first
oss doctor                            # schema + replay must be green
ai_root="$(oss repo_root ai_workspace)"
```

1. **Manifest.** `oss manifest_require` resolves `.ossify/topology.json` first
   and a workspace-init `.workspace/pairing.json` as the translated fallback; it
   fails only when neither is on the walk-up path. On failure print its refusal
   verbatim — the literal tokens **`/ossify:start`**, **`/ossify:adopt`**,
   **`/init-workspace`** and **`/pair-workspace`** are all load-bearing, and a
   refusal naming only the workspace-init pair sends a topology-only project to
   the wrong remedy. Do not paraphrase it.
2. **`oss doctor` must be green on `schema` and `replay`.** A close *mutates*
   state; running one over a drifted state compounds the drift into the record
   that every later ceremony reads.

   **The remedy differs by which line failed — echo doctor's own line rather
   than substituting a fixed one:**

   | doctor line | Remedy |
   |---|---|
   | `fail: replay` | **`oss state_restore`** — rebuilds live state from base + journal |
   | `fail: shape` | **`oss state_restore`** — a required key is missing; same rebuild |
   | `fail: schema`, version **below** this build | **`oss migrate`** — the state predates this build |
   | `fail: schema`, version **above** this build | **upgrade ossify** — `migrate` accepts v1, v2 and v3 (v3 → v4) |
   | `fail: state` | **`/ossify:start`** (a new project) or **`/ossify:adopt`** (one that already has code) — on Codex the `start`/`adopt` skills — never initialised; each runs `init` itself, and a bare `init` first leaves state both refuse |

   Naming `state_restore` for every line wedges the close on a schema failure:
   against a v1, v2 or v3 state it prints `restore: state is already clean - nothing to
   do` at **rc 0**, leaves `schema_version` untouched, and `oss doctor` fails
   identically on the retry. The operator loops. `oss migrate` is the verb that
   moves the version, and doctor already names it in its own output — which is
   why echoing the line beats paraphrasing it.

   **The tag alone does not pick the remedy.** A schema *newer* than this build
   is an ossify upgrade, not a migration; a corrupt journal or a missing base
   snapshot is refused by `state_restore` by name. Both arrive tagged exactly
   like the rows above, so read the rest of doctor's line before recommending
   anything. `doctor/references/state-inspection.md` §3, in this plugin, carries
   the full treatment.

   **`oss doctor` no longer reports the advisories.** A held lock, a pending
   amendment, an outstanding fake and out-of-spine patch records are read by the
   `doctor` SKILL now, not by the verb this pre-flight shells out to — so they
   will not appear here at all. They were never blockers; they are inputs the
   spine and release layers act on — the pending amendments at spine step 3, the
   outstanding fakes at release step 3. Do not wait for a `warn:` line from
   this command: it cannot emit one.

   **Read the lock yourself, before any scope's first step:** if
   `"$(oss state_path).lock"` exists as a directory,
   halt naming it and route to `doctor/references/state-inspection.md` §2's
   staleness rule — the close mutates, and the merge at spine step 2 precedes
   the first mutation, so a leaked lock lands the irreversible merge and then
   kills the ceremony at rc 3.
3. **Resolve every path to an absolute one up front, and never `cd`.** The
   manifest walk starts at `$PWD` and the dispatcher re-runs it on every call that
   takes no explicit state path, so a `cd` mid-ceremony silently re-points the
   state file rather than failing. Probe once with `oss state_path` and
   `oss repo_root <key>`, carry the results as absolute paths, and reach every
   repo with `git -C "<abs>"`. Do **not** work around this by exporting
   `OSS_STATE_FILE`: that changes resolution precedence for every nested call and
   is not what the other lanes do.

---

## 4. Work-item close

The innermost scope, and the one the execution lane hands you directly: a
`complete` return from the implementer is not a green gate — it reports that the
loop ran (`work-item/references/round-orchestration.md` §6). Running the gate is
yours.

Six steps, in **binding order**:

1. **Resolve the three absolute paths** — `spec.md`, `report.md`, the worktree —
   by one of two routes (the round flow's return payload, or a standalone
   reconstruction from the id). Neither is optional to know: `/close <id>` is
   supported with no round in scope.
2. **Run the gate** (§4's four layers, below).
3. **Prove there is something to commit** — a green gate over an empty index
   means the work is not where the commit will look for it.
4. **On green:** commit **in the worktree**, merge its branch into the spine
   branch that item's own target repo is parked on — reading the branch from `work_items[].branch`,
   never re-deriving it from a slug you do not have — halting on conflict
   (resolution discipline: `references/merge-conflict-resolution.md`), and set
   the work item `complete` **last**, after the merge is verified landed (spine close reads
   `complete` as "this item's work is on the spine branch"). With `--pr` (§9) the
   commit is pushed and the item's PR opened instead, the item stays `active`: `references/work-item-close.md` §4a.
5. **On any failure: halt**, surface the source-tagged errors, present the
   recovery menu, and **stop — no auto-select.**
6. **Worktree cleanup does not happen here.** It is the last step of spine close.

Full step detail — both path-resolution routes, the staging proof, the merge
block with its merge-target check, and why cleanup is deliberately absent — in
**`references/work-item-close.md`**.

The gate itself — the four layers, their halt semantics, the literal error tags
and the recovery menu — is in **`references/impl-check.md`**. Read it before
running step 2; it is what "impl-check" means everywhere else in this plugin.

**A note on disposition triage (spec §6.1, #109 policy), because its scope is
easy to over-read:** spec-aligned **disposition** recommendations auto-apply and
only load-bearing escalations reach the user. That is a deliberate behavioural
change from the predecessor stack, which surfaced and waited at every decision
boundary — so state it rather than letting a reviewer "fix" it back. It governs
the **disposition rows**, which arrive with the critic findings at *spine* close.
**This layer has no disposition step, and its recovery menu is never
auto-selected**: a failed gate is a human decision, not a spec-aligned
recommendation.

---

## 5. Spine close

The middle scope, and the one the ceremony is named for (spec §6.1). Eleven
steps in **binding order**, plus **4b** (the bones registration, `spine-close.md` §5b):

1. **Every work item `complete`** — or `abandoned`, withdrawn before dispatch —
   else refuse and **name the offender**. Test the *output* of the
   `oss get` — a `select` matching nothing exits 0.
2. **Land each hosting repo on its own `base_branch` — by PR where a remote
   exists, locally where none does (#339)**. The PR arm pushes the spine branch,
   opens the PR, and hands it to work-pr (`/ossify:work-pr`; the `work-pr` skill on Codex, `skill://work-pr` in OMP)
   (`spine-close.md` §3); the record pass proves the
   remote merge locally (identity, lineage, base-contained) before anything is
   recorded. A remote `gh` cannot operate on halts — never a silent local
   fall-through. The local arm keeps all four guards: **derive the spine branch
   with `oss branch_name` and assert HEAD matches it — never read it off HEAD**;
   assert the switch-back actually moved HEAD; check reachability after the
   merge. Each catches a distinct failure that is otherwise rc 0 all the way to
   a green close. Halting on conflict (at that halt,
   `references/merge-conflict-resolution.md` is the resolution discipline —
   operator-sanctioned, never automatic). **Read `references/code-review.md`
   before the merge happens** — the last moment the spine's diff is reviewable
   as one thing, and the only reader that judges craft and fidelity rather than
   whether the ACs passed. Advisory: it yields findings and a per-finding
   decision, never a halt.
3. **`oss ledger_apply_pending <spine>`, then `oss ledger_activate_spine <spine>`** — after the
   merge, before the demo. The second makes this spine's own `planned` lines live: they
   must pass at this close.
4. **The cumulative demo**: `oss demo_run` for every active `auto:` line, then
   walk **this spine's own** `user:` lines (`oss demo_user_lines <spine>`) with
   the human, or yourself under a standing order in the project's memory bank or `AGENTS.md` that gives you the demo walk (`cumulative-demo.md` §3). **Halt on the first failure** — no later step runs.
4b. **Register the bones this spine's plan declares** (`spine-close.md` §5b):
   `SPINE.md`'s `## Bones this spine registers` rows enter the bones registry via
   `oss bone_add`. A missing ADR file halts naming the ref; `None.` or no section is a no-op.
5. **The changed-path list, then `oss touch_check`.** The list is the merge's own
   diff. **rc 0 = hit, rc 1 = clean, rc 2 = could-not-check, and rc 2 is not
   clean.** A bone hit reclassifies the spine mid-flight via `oss class_set`
   (three arguments — the reason is required).
6. **Risk-gate escalation**, distinguished from a bone hit by the printed prefix,
   and it escalates regardless of class.
7. **The adversarial audit** (`challenge`, audit mode), class-scoped: close
   depth on bone, a light host-only pass on flesh.
8. **The retrospective**, against a fixed section contract.
9. **Memory-bank harvest** — always before cleanup.
10. **Worktree + branch cleanup**, per work item. Only now.
11. **State updates**: `oss spine_status <spine> closed` and `oss demo_record`.

Full step detail — the two landing passes and their guards, the PR handoff
contract, the changed-path computation, the class-scoped critic bridge, and the
bone/flesh column from spec §6.1 as a table — in **`references/spine-close.md`**.

The demo layer — the cumulative `auto:` half, the spine-scoped `user:` half, the
halt discipline, quarantine as a parking ticket, and the ledger's wall-clock
budget — is in **`references/cumulative-demo.md`**.

The two retrospective section sets, full for bone and lean for flesh, are pinned
verbatim in **`references/retrospective.md`**. It is the only copy.

The harvest (step 9) — how the candidates are enumerated from each
**non-`abandoned`** work item's
`report.md` and `handoff.md`, the `[report]`/`[handoff]` trust tag, the two-file
allowlist, and the append rules (no `oss` verb: whole-set validation, then you
write, in one pass) — is in **`references/harvest.md`**. Also the only copy.

---

## 6. Release close

The outermost scope (spec §6.2, plus the two §6.1 contracts that only become
enforceable at a release boundary). Eight steps, in **binding order**:

1. **Every spine `closed`**, else refuse and **name the offender with its
   status**. Test the *output* of the `oss get` — a `select` matching nothing
   exits 0. **`abandoned` is not `closed`**: it neither passes silently nor
   hard-halts, it is surfaced by name for the user to confirm.
2. **The full cumulative walkthrough**: `oss demo_run` for every accumulated
   `auto:` line, then walk **every** active `user:` line with the human, or
   yourself under a standing order in the project's memory bank or `AGENTS.md` that gives you the demo walk (`cumulative-demo.md` §3) — `oss demo_user_lines` with **no argument**. The amendments are already
   applied; the spines applied them. Grouping by feature is **derived** from
   `source_spine` and `oss feature_list`, not read off a field.
3. **Blocking finding — fake expiry.** `oss expired_fakes "$rel"`, plus the
   judgment pass over each remaining fake's `replacement_trigger` (§6's second
   reference). The only unblocks are replace or explicitly renew.
4. **Blocking findings — outstanding quarantines, and deferrals coming due.**
   `oss expired_quarantines "$rel"` — every line quarantined in a **strictly
   earlier** release is a parking ticket now due. `oss expired_deferrals "$rel"` — every
   deferred `user:` line due at or before `$rel`, each walked, re-deferred or retired
   here (a retire owned by a closed spine never applies, so it keeps blocking).
5. **The release retrospective**, aggregating the spine retros. **Refuses,
   naming the spine, if any lacks `retrospective.md`.**
6. **Feature-map re-groom + next-release sketch** — the rolling-wave crank, via
   `oss feature_list` and `oss release_set_meta`.
7. **The boundary audit** (companion §6, re-derived under the skill-first
   freeze) — **every repo the resolved topology declares (`.ossify/topology.json`
   first, a translated `.workspace/pairing.json` as the fallback), each
   gated on its observed visibility with per-role arms**, fail-closed: the
   tracked rules of `PUBLIC_BOUNDARY.md`, the secrets scan, the scan-first
   untracked sweep, the semantic pass over tracked prose against the
   private boundary inventory, the recorded history pass and the working-tree
   pass over uncommitted tracked modifications, and the accepted-disclosure
   override with its inventory record, each tracked submodule's pinned tree
   audited by that same arm. The dimensions still absent — divergence on
   public refs other than the audited one after a recorded history pass, and
   every submodule pin but the audited ref's together with a non-manifest
   pinned submodule repository's own history — are
   named in the audit's own not-shipped table. **Never auto-dispositioned;
   confirmed findings block the close** (per-role arms govern what runs —
   the hygiene-note arms record non-blocking notes and skip the disposition,
   save for the recorded-remote exposure finding and a secrets-class hit,
   which block on every arm, and unaccepted degradations, which bar a clean
   verdict).
   The whole step is
   **`references/boundary-audit.md`**.
8. **The release tag, then the state writes** — tag **each hosting repo this
   release landed in**, at that repo's recovered base branch, and push the tag
   where a remote exists (a no-remote repo's tag is local, verified the same
   way minus the remote leg): the PR tier lives at the spine boundary (#339),
   so by the time every spine has closed the base branches already carry the
   release; the tag is the only release-level landing there is, and it is
   repo-scoped because a cross-repo release's code lives in every repo that
   hosted one of its spines. Then the state writes — `oss release_status <rel>
   closed` and `oss demo_record release <rel> <passed> <line-count>
   "<notes>"` — never after a halt in any step above.

**All three blocking gates are rc 0 = CLEAN / 1 = BLOCKING / 2 = could-not-check —
the opposite polarity from `oss touch_check`, where rc 0 is a hit.** Copying the
touch-check branch shape inverts the judge and passes exactly the releases the
gates exist to block. rc 2 halts in both; it is never folded into clean.

**Two of spec §6.2's steps are deliberately not shipped** and are named as
such rather than left to read as executed: the **docs increment** (§8's trigger
table), and **handoff cleanup** for the closed release (session handoffs are
`/ossify:handoff`'s, a standalone utility with no retention policy by design —
handoffs accumulate and the user prunes). The **release tag** ships: the PR tier
is settled at the spine boundary (#339 — each spine lands its hosting repos by
PR through `/ossify:work-pr`), so a release close tags the merged `main` rather
than gating a merge of its own.

Full step detail — the two-arm spine gate, the walkthrough's scoping and its
derived feature grouping, all three blocking gates' branch blocks, the retro's
refusal path and the state writes — in **`references/release-close.md`**.

The fake-expiry finding — its rc contract, why `renewed` is inside the selector,
why the comparison is at-or-before and numeric, and the **judgment arm** over
`replacement_trigger` that no selector can decide — is in
**`references/fake-expiry.md`**.

Out-of-spine work has its own lane and its own routing judgment — the
three-part test, `oss touch_check` as its mechanical two thirds, and the
`oss patch_add` record — in **`references/patch-lane.md`**. The verb already
exists; what that file adds is when to reach for it.
A versioned patch — a shipped defect or a can't-fake request — is
`/ossify:patch`'s, not this lane's; release close lists those from git
(`references/release-close.md` §6).

---

## 7. Anti-patterns (do not do these)

- **Routing on anything but the id's shape.** Not the phrasing of the request,
  not what closed last, not the branch you happen to be on (§2).
- **Comparing `oss id_parse`'s whole output against a bare scope word.** The
  numeric components share the line; take the first field (§2).
- **Guessing a scope when no id was given.** Refuse and list what is open (§2).
- **Running a layer's steps out of order.** Every layer's order is binding
  because each step's output is the next one's input — the gate reads the paths
  step 1 resolved, the merge reads the branch step 4 confirmed.
- **Treating a halt as advisory.** A halt is terminal: no later step runs, no
  status is written, nothing is recorded as closed.
- **Auto-selecting from the recovery menu** (§4).
- **Reading the spine branch off HEAD** instead of deriving it and asserting the
  match, or merging without switching every hosting repo back first (§5). Both
  failures are rc 0 and green.
- **Folding `oss touch_check`'s rc 2 into "clean"**, or reading rc 0 as clean
  (§5).
- **Copying `touch_check`'s branch shape onto `oss expired_fakes`,
  `oss expired_quarantines` or `oss expired_deferrals`.** rc 0 is a hit there and
  CLEAN here, so the copy passes precisely the releases the gates exist to block (§6).
- **Selecting expired fakes on `active` alone**, comparing the expiry for
  identity, or comparing release ids as strings — `"r2" <= "r10"` is false.
  Each one lets a fake outlive its own deadline, silently green (§6).
- **Reporting the fake gate clean after running only its mechanical arm.**
  `replacement_trigger` is free text and its pass is yours (§6).
- **Blocking on a quarantine raised during this release.** Strictly earlier
  (§6).
- **Passing a spine id to `oss demo_user_lines` at release close**, or implying
  demo lines carry a feature field to group on (§6).
- **Routing a change through the patch lane without `oss touch_check`**, or
  using diff size as the criterion (§6).
- **Running the close audit at close depth on a flesh spine**, or at shallow
  depth on a bone's (§5).
- **Closing a scope whose children are not closed** — a spine with an unfinished
  work item, a release with an open spine (§5, §6).
- **`cd`-ing mid-ceremony**, or exporting `OSS_STATE_FILE` to compensate (§3).
- **Authoring or editing a demo line, a spec, or an AC to make a gate pass.** You
  run them. A criterion that is genuinely wrong goes back through `/plan-spine`,
  recorded, with the close halted meanwhile.
- **Letting this body exceed 500 lines.** Hard cap; depth goes to `references/`.

---

## 8. Notes on tool boundaries

- **You** (Claude reading this body) make every judgment: whether a diff violates
  a documented pattern, whether a report's account of an AC is honest, which
  recovery path to *offer*, whether a deviation is acceptable.
- **`oss`** handles mechanical facts only, and holds no judgment: `id_parse`
  (the id's shape), `manifest_require`, `doctor`, `state_restore`, `state_path`,
  `repo_root`, `release_dir`, `spine_dir`, `spine_list`, `branch_name`, `get`, `verify_acs` (AC parsing),
  `verify_step` (the expectation predicate, including the vacuous-green guard),
  `report_cross_check`, `work_item_status`, `worktree_resolve`,
  `worktree_remove`, `ledger_apply_pending`, `ledger_activate_spine`, `ledger_defer`,
  `ledger_escape`, `ledger_quarantine`, `ledger_retire`, `demo_run`, `demo_user_lines`,
  `demo_record`, `touch_check`
  (glob matching — never the meaning of a match), `class_set`, `veto_add`,
  `critic_detect` (a filesystem probe), `spine_status`, `release_status`,
  `expired_fakes`, `expired_quarantines` and `expired_deferrals` (all read-only
  selectors — they compute *which* records are due, never whether it was reasonable),
  `fake_status`, `feature_list`, `feature_add`, `release_set_meta` and
  `patch_add`. The memory-bank harvest has no verb: the bank is
  manifest-routed and the appends are yours (`references/harvest.md` §7) —
  and which suggestion was worth keeping was never `oss`'s call anyway.
- **`git`** is reached only as `git -C "<absolute path>"` (§3). The commit
  boundary is yours and the implementer's never; the merge target comes from
  state, never from a slug.
- **`gh` and `gitleaks`** enter at §6 step 7 only, and each has its own failure
  semantics rather than a shared one: a visibility read `gh` cannot answer means
  the repo is audited **as public**; a `gitleaks` scan that does not complete —
  or completes but reads nothing it was pointed at —
  makes the secrets half **INCONCLUSIVE**, never clean. Both in
  `references/boundary-audit.md` §2-§3.
- **Peer entry skills:** `start` owns spec-core and the bones registry;
  `plan-release` owns spine selection, exit criteria and the class declaration;
  `plan-spine` owns decomposition, specs and demo-line authoring; `work-item`
  owns execution and stages without committing.
- **The user** is the final authority on every recovery choice and every
  override. You surface the failure with its source tag and the menu; they pick.

---

## 9. Slash-command interaction

`/close <id>` (`commands/close.md`) exports the raw argument string as
`$ARGUMENTS` through an env-var bridge — on shim-less channels (`Skill()`, natural language) nothing exports it; the id arrives as a literal
token in the invocation/request text. **Parse `$ARGUMENTS` in bash; never
reference `$1` / `$2` / `$N`** — Claude Code substitutes positional tokens in
command bodies at template-render time and silently corrupts them.

The arguments are the id and, after a work-item id only, `--pr` (`/close <wi-id> --pr`) and `--verdict <file>` (`/close <wi-id> --pr --verdict <file>`: a caller's verifier verdict replaces the close's own dispatch, `references/work-item-close.md` §2). Both apply to a work-item close only: on a spine or release id, twice, before the id, with `--verdict` and no file, or with any other token, refuse with that sentence before §3's pre-flight. With no id, emit one line, list what is open, and stop (§2).

---

## 10. The close summary

**The close summary is this ceremony's final assistant message** — the last thing
you emit when the scope's steps are done. It is a message, **not a file**: this
release ships no close-summary artifact, the same non-wiring §6 records for handoff
cleanup. The durable records are `retrospective.md`, `report.md`, `verify.md` and the state
writes; the summary is how a human reads the run without opening them.

It carries, in this order:

1. **What closed** — the id and scope, and whether every step ran or the ceremony
   halted partway.
2. **Gate outcomes** — each blocking gate with its verdict, source-tagged the way
   the step reported it (`[AC]`, `[report cross-check]`, `[rule]`, `[fidelity]`,
   `[mutation]`), and the `verifier:` line (`work-item-close.md` §2).
3. **Anything a step told you to record here.** Several steps route output
   to the summary, not to a file: `harvest.md` §2's missing-report gaps,
   §5's rule-authoring referrals, and §8's harvest outcomes. If a step says "record it in the
   close summary," this is where it lands.
4. **What the operator must do next**, if anything.

Named here rather than in each step so the phrase has one definition — several
references route to "the close summary" and none of them owns it.
