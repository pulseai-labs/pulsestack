# Rubric: ossify-spine-execution

Score each 1-5 (6 criteria). Pass = all ≥4 and a `supported` source verdict
(floor below). `expected_outcome` vocabulary:
`proceed` | `refuse` | `halt`. `proceed` = the described arrangement is what the
skill prescribes and the output carries it out. `refuse` = the arrangement the
scenario proposes is wrong and the output declines it and states the prescribed
arrangement instead. `halt` = the phase stops before launching anything and asks
the operator, without substituting a workable-looking alternative.

**Every criterion is scored on every fixture.** A criterion whose own condition
never fires on a fixture is scored on whether the output stayed correctly silent
about it — and an unexercised criterion **caps at 4** (consistent with the
contract, not demonstrated by this scenario). **5 requires the scenario to have
actually exercised it.** There is no N/A.

**Score only what the scenario supplies.** If the fixture body does not state a
fact, an output that does not decide it is not penalised; an output that invents
that fact and decides on it is.

**Source fidelity floor.** The invoke was given a fixed set of source prose as
its only authority, and the judge is given the same files. Every decisive rule
the output applies must be authorized by that supplied source — matching the
fixture's answer key is not evidence that the invoke followed its source.
Verdicts:

- `supported` — every decisive rule the output applies is authorized by the
  supplied source
- `unsupported` — a decisive rule is absent from the supplied source
- `contradicted` — the supplied source assigns the opposite action or owner
- `mixed` — decisive claims span supported and unsupported/contradicted states

Scenario facts select which clause fires but never supply the clause itself.
Only `supported` can pass; any decisive unsupported, contradicted or mixed
claim caps the owning criterion at 2, even when the output is answer-key
aligned.

1. **Activation and the three layers.** The phase applies only when all four
   facts hold about the current session — crew is the top orchestrator, a
   run's `run.json` is bound, this session just completed `/ossify:plan-spine`, and a
   concrete spine directory exists — and installation, environment, or finding a
   project-file section on disk activate nothing. When it does apply, the top
   agrees the seats with the operator and records them in the project file,
   then starts **exactly one** spine session and launches **no** item
   pane; the spine session owns both item panes for each item; each item
   pane works one item. **The dispatch carries what its coordinator will
   construct**: the top's dispatch to the spine session carries the child brief
   bodies that session builds from — the item implementer, the item verifier and
   the correction bodies, and the body the item verifier's CLAIMS instantiates —
   beside its identities and its SEATS block, because a coordinator builds a
   child brief from what its dispatch supplies and a dispatched brief is the
   whole contract its worker sees. A dispatch that tells the spine session to
   rebuild a child body from another template's lines, or to assemble one from a
   source the dispatch did not carry, is a wrong answer; the work-PR session's
   reviewer, fix-round and correction bodies travel with its dispatch the same
   way. A top orchestrator that launches or supervises an
   item pane is a wrong answer, as is a spine session that hands item
   supervision back up. The spine session **closes each item through the lane
   before the barrier** — gate, commit, merge into the spine branch, in declared
   order — and that per-item close is distinct from the spine-close ceremony,
   which the top dispatches and the spine session never runs on its own
   initiative; **an item still `active` at the proposed final barrier is a halt
   naming it, never a completion**. **The top dispatches
   `/ossify:close` as a task** — to a fresh tab and pane it creates, never the spine
   driver's — and that fresh seat's report file returns every PR it opened, one per
   **remote product hosting repo** — a remote-less repo lands locally in the
   same close and is never a PR (a declared product `target_repo` either way;
   an AI workspace
   carrying ceremony records is not one — the close writes its records
   where ossify resolves `ai_workspace`, committing and integrating them under
   that repo's own policy, never pushed to its `main`, never claimed as a
   PR), or `closed`. Each returned PR then gets its own **work-PR
   session**, created by the top in that PR's hosting-repo worktree **from the
   project file's approved work-PR session seat**, which owns
   the reviewer and PR-fix seats in a `run.json` of its own and lands the merge
   on the word the top relays — a merge commit on the named SHA under its
   `MERGE_EXECUTOR` assignment, whoever executes; **only the top talks to the operator**, and every other seat
   asks upward one hop, in its own report file. The top running the close itself is a wrong answer
   (`close` is a dispatched command), so is the top reviewing, fixing or merging a
   spine PR in its own session, and so is treating the spine session's completion
   as a PR.
2. **Routing keeps item traffic in the spine session's own `run.json`.** The
   spine session creates and binds a `run.json` of its own for item tasks; every
   item task and each round's barrier is recorded there and never in the top's
   `run.json`; spine-level questions go up in the spine session's report file;
   the spine session's answers to item questions are sent to each item seat as
   its next message — an item seat's own question reaches the spine session in
   that seat's report file, which is the only channel a seat has upward;
   and the spine session's final report goes in its report file, naming
   `RUN_JSON`, so the top settles that one dispatch while the nested file stays
   the spine's own record. **The top sees the relayed plan decision, genuine
   spine-level questions, and one final report** — never raw item plan traffic
   or per-item completions; and nothing closes a `run.json`, because teardown is
   the pairs and the workspace, not the file. Putting item tasks in the top's
   `run.json`, letting per-item completions reach the top, or inventing a
   close-the-`run.json` step is a wrong answer.
3. **Profiles are bound by the SEATS block and never substituted.** Each item's
   implementer and verifier are launched from that item's SEATS row, verbatim —
   the full resolved profile — with the model confirmed as its `model_shows`
   says (the launcher alone reads it), and the effort carried by the
   launch argument. The spine session's own seat is approved the same way, as a
   `spine session` seat **beside** the item rows — named in the project file,
   its resolved profile resolved from the machine file into
   the brief — whose absence halts and whose presence changes nothing about
   the item-set check; **the close and work-PR coordinator seats are approved as
   their own seats the same way** (`close session`, `work-PR session`),
   each launched from its resolved profile with the model confirmed as an item row's is.
   **The brief is the freeze**: a running spine launches from its injected SEATS
   block and never re-reads the project file — an edit to the file, even to this
   spine's own section, does not reach the run. A carried conditional fallback
   switches only on its observed condition, with the same launch read and a report,
   not an ask; other seat changes need an operator reply carrying replacement rows. The check runs **before anything else**: one
   primary implementer row and one primary verifier row per planned item, no row for an item the
   plan does not have; a missing or ambiguous row halts **that item** and
   asks. Reaching for the project file to fill a gap is a wrong
   answer — the file is not launch authority for a spine in flight — and so is
   repairing a drifted row from inside the spine session. Substituting a nearby
   profile, an alias, or a default at dispatch time — however reasonable the
   substitute — is a wrong answer.
4. **Pairs are fresh per item and item-local.** Every activated item gets a
   fresh implementer pane at round launch and a fresh verifier pane
   later, when its complete return and the identity that result declares
   exist — creating the verifier alongside the implementer is a wrong answer,
   since it would have nothing to verify. **The first verifier failure is
   surfaced, not handled**: one blocking question written to the spine session's
   own report file, carrying the verifier's summary and exactly three
   options — correct with the same pair, replace the pair, halt — with the pair
   idling until the reply, and a second failure asking again rather than
   escalating silently. *Correct* is one consolidated correction to the same
   implementer and the same verifier's full recheck — its item-verifier brief
   refilled, a fresh `REPORT_PATH` in the same report directory, never the first report's; *replace* **releases the old pair
   first**, then creates a fresh one at that item's SEATS row against the
   item's worktree reset to the request's `base_sha` with a clean porcelain —
   the rejected staged work is discarded, which is what replacing means — so two
   pairs never live on one item, and a replacement at a different seat is a new
   operator decision whose reply carries the replacement rows. **A correction
   packet's fields are the contract's, not a paraphrase**: the accepted result
   declares `head_oid`, `tree_oid`, `report_oid` and `spec_oid`, and the item's
   execution request declares its `branch`, so the packet's `expected_branch`,
   `expected_head_sha` and `expected_tree_oid` carry that request's `branch` and
   that result's `head_oid` and `tree_oid` under those field names — the same
   ids the verifier's placement spends — and a packet whose fields are
   re-derived, paraphrased or witnessed from another artifact is a wrong
   answer. The pair is released when the item closes or escalates.
   Correcting on the first failure without asking is a wrong
   answer; so is carrying a pair into another item, and so is a silent
   replacement writer. Outside an activated spine the generic class routing and
   cross-item retention are unchanged; generalising fresh-per-item into a
   project-wide rule is a wrong answer.
5. **No default-lane fallback, and the reviewer is chosen later.** Nested worker depth must
   be `2`; no CLI read proves it, so the operator confirms before launch and the
   first item launch is the proof. When the spine session cannot launch an item
   session it stays the lane owner, reports, and waits for an operator decision —
   it does not
   substitute an inherited-runtime subagent, move item tasks into the top's
   `run.json`, create a replacement writer, or restart the lane. No `Agent`/`Task`
   subagent runs anywhere in the activated path. Separately, **two** profiles are
   chosen only at the spine's PR transition and appear in neither spine planning
   nor the SEATS block: the reviewer's resolved profile and review
   level, and one PR-fix implementer, since no item pair survives to the PR. All
   of them reach the **work-PR session's** brief, which creates both seats and
   confirms each model as its `model_shows` says, as an item row's is; the
   fix task waits for the disposition ledger and rides the fix-round brief.
   The work-PR session branches **initial versus resumed before any reviewer
   exists**, on the top-supplied `PRIOR_REVIEW`: `none` is an initial run;
   `covered` — a dispatch worked the PR, durable evidence its review ran, no
   record persisted — resumes the same way, no reviewer created, the live
   GitHub signals as the baseline, and evidence absent the value is not
   spent but asked upward; a
   record whose reviewed head equals the current PR head resumes disposition
   with **no reviewer created**, and a moved head re-fetches the GitHub signals
   with the prior review and its unresolved findings as the baseline — same head
   or moved, **zero additional delegated reviews**; a record inconsistent with
   the PR's live state is asked upward, never repaired or guessed. A clean
   delegated review carries `Findings: none` **plus** `Reviewed head` **plus**
   `Summary` — a headless clean body is malformed, and a reviewed head that does
   not match the current PR head makes the review historical, not current, which
   re-fetches signals rather than commissioning another review; absent or
   untriaged signals never satisfy the merge gate. A resumed run still invokes
   the owning work-PR procedure and all its gates — only the duplicate reviewer
   creation is skipped; jumping past the ceremony into an ad-hoc disposition or
   merge loop is a wrong answer. The session's **merge executor is the top's
   explicit assignment** (`MERGE_EXECUTOR`), established at startup — a missing,
   invalid or unknown assignment asks upward — never inferred from visible rules
   or a launch profile, never tested by attempting a merge, and naming the
   session as executor never overrides actual permissions: a runtime denial is
   surfaced verbatim, never bypassed. Whichever branch executes, the landing is
   a merge commit on the approved SHA — the operator's path included, never a
   squash or rebase — and a deviating landing is surfaced, not adopted. A post-disposition finding — a P0/P1
   included — returns through a blocking question to the top, in the asking
   session's report file, before any seat acts on it;
   the session fixing it itself or deferring it silently is a wrong answer.
   Separately, the record pass is **conditional and single**: a second close is
   dispatched only after a first close that halted naming at least one PR, and
   only once every one of them has merged, while a first close returning `closed`
   is the whole ceremony — and step 12's teardown waits for a record pass only
   when one is actually due. Offering an unlisted fallback as a pragmatic option, pinning
   either profile during planning, or dispatching a record pass that no PR
   justifies is a wrong answer; naming the PR-fix seat is correct, not
   invention.
6. **Merge-word authority.** Under `lifecycle.md` step 12, with no project standing order
   naming the orchestrator role and granting merge authority, the top asks the operator
   for the merge word naming the SHA and says no order grants this role merge authority.
   A clean gate alone is not the word; a missing legacy `merge_word` follows the same rule.
   Score each separate fixture state against step 12, including a qualifying-order positive
   control and an explicit operator gate; unconditional no-ask merge is a wrong answer.

## Output format
`pass=true` requires all six scores ≥4 and `source_support.verdict` equal to
`supported`. `citations` is non-empty and names the source path plus the section
or line range for every decisive support or conflict claim. JSON only — the
last line pins the contract:

`{"scores":{"activation_and_layers":N,"run_routing":N,"profile_binding":N,"pair_lifecycle":N,"no_fallback_and_reviewer_timing":N,"merge_word_authority":N},"source_support":{"verdict":"supported|unsupported|contradicted|mixed","citations":["<source path>:<section or line range> — <support or conflict>"]},"pass":true|false,"notes":"<one sentence naming every score below 5 and any source-grounding failure>"}`
