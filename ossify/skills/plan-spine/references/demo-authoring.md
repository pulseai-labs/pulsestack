# Demo authoring — the journey-line floor

Depth for SKILL.md §8. This is the binding contract for what a spine contributes
to the **cumulative product demo ledger**.

The ledger is an **operated asset**, not a list. Every `auto:` line joins a suite
re-run at *every* future spine close; every `user:` line joins a walkthrough a
human performs at *every* release close. A line you add today is paid for
repeatedly by everyone who works on this product afterwards. That is why the floor
is a floor and not a guideline.

---

## 1. The six floors

| | Floor | Applies to |
|---|---|---|
| **F1** | Every spine contributes **≥1 demo line** | every spine |
| **F2** | A user-facing spine contributes **≥1 `user:` journey line** = verb + observable outcome. Inspector phrasing banned | user-facing spines |
| **F3** | An internal spine contributes **`auto:` lines only**, and is admitted only if it **names the committed consuming user-facing spine**, scheduled in the current or next release | internal spines |
| **F4** | A pass claiming a **measured quality** (performance, reliability, cost) states **before/after evidence** in its demo contribution | deepening passes |
| **F5** | Every `auto:` line binds to a **runnable command + declared expected** (`exit:<n>` \| `contains:<str>` \| `exit:<n>+contains:<str>`) at authoring time | every `auto:` line |
| **F6** | Release 0 contributes **≥1 automated golden-journey `auto:` line** — one command driving the release's exit-criterion journey end to end | spines in Release 0 |

An internal spine **cannot claim product value** — not in its own demo lines, not
in the release's exit criteria, not in the retro.

### The community-edition line — posture-conditional, not a seventh floor

Companion spec §4.3 is a **MUST**: for an `open-core` or `fully-open` posture the
cumulative ledger has to carry a **standing `auto:` line that builds and
smoke-runs the public repo standalone from a clean checkout**. It is not one
spine's contribution — it is the product-level guarantee that the public edition
is a real product rather than a package that only builds inside the private
composition.

Nothing else owns it: `cross-repo.md` §5 states the *principle* ("the public
edition must remain buildable and demoable on its own") without naming the ledger
line, and `close` runs the ledger without knowing a line is missing from it. A
line nobody authors is a guarantee nobody keeps.

So check it here, at every spine on a public-routed posture:

**Give the line a durable marker, and match on that — not on its wording.**
A ledger line has no `kind` field (`lib/ledger.sh`'s `add_demo_line` payload), so the
marker is a **required text prefix**: the line's `text` begins with `[community-edition]`.

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

```bash
posture="$(oss get '.project.posture')"
case "$posture" in
  open-core|fully-open)
    oss get '[.demo_ledger[] | select(.status=="active" and (.text|startswith("[community-edition]")))] | length' ;;
  *) echo "n/a - posture is $posture" ;;
esac
```

**If the posture is public-routed and the count is 0, this spine authors it:**

```bash
oss ledger_add_auto "<spine-id>" \
  "[community-edition] clone the public repo fresh, build it standalone, and smoke-run it" \
  "<the clone+build+run command>" "exit:0"
```

A prefix rather than a phrase search, because a phrase search is wrong in both
directions and both are silent. Grepping the text for *standalone* or *clean
checkout* matches any unrelated line that happens to contain those words — the
mandatory check reads as satisfied by a line that never clones anything — while
a legitimate existing line phrased *"from a fresh clone"* is missed, so **every
later spine authors another one** and the cumulative suite grows a duplicate per
spine, forever. The prefix is exact, greppable, and visible in `demo_run`'s
output, which is what makes it auditable later.

Author it once; later spines find it and move on. It is a standing line, so it
never belongs to a single spine's contribution and never counts toward F1. (If a
typed field is ever added, it supersedes the prefix.)

### Adoption's seed lines — Release 1 mints them once, outside F1 (#293)

Adoption records demo-ledger seed candidates in `"$(oss repo_root ai_workspace)/ADOPTION.md"`
(its C6) and mints none: a ledger line keys to a spine, and adoption creates no
spine. Demo lines are this skill's, so Release 1's spines mint them.

**The end state, at every Release 1 spine's planning while that file exists:** each
candidate is a ledger line or is recorded as unmintable. The line's text is the
same prefix rule as above, `[adoption-seed] ` plus the candidate's own words. A
candidate whose prefixed text is already the `text` of a ledger line — on any spine, in any status — is done.
So a resumed or amended plan, or a sibling spine planned later, mints nothing
twice, and a seed line someone retired or superseded stays that way. A candidate
that another Release 1 spine's `SPINE.md` (`spec-authoring.md` §1) records as
unmintable is done too.

```bash
oss get '[.demo_ledger[] | select(.text | startswith("[adoption-seed]")) | .text]'
```

Mint each remaining candidate that binds under F5 (§6) `active`, since it tests
surface that already ships:

```bash
oss ledger_add_auto "$spine" "[adoption-seed] <the candidate, verbatim>" "<its command>" "<its expected>" active
```

For a candidate that cannot state a runnable command and expected, this spine
records it under its `SPINE.md` demo contribution as unmintable, with the reason.
`RELEASE.md` carries no demo lines, so it is not the place.

A seed line never counts toward this spine's F1, F3 or F6. It tests what the
adoption shipped, not what this spine builds, so the spine still owes its own
lines — the same exclusion as the community-edition line. It does count against
the release's `ledger_budget` (§6), like any line.

---

## 2. The read-out

Judge the whole contribution once, out loud, before any `ledger_add_*` call:

```text
Demo contribution — <spine-id> "<name>"   [user-facing | internal]
  F1  at least one line        pass|fail       <n> lines
  F2  user: journey line       pass|fail|n/a   "<the line>"
  F3  enabler names consumer   pass|fail|n/a   <consumer spine-id> in <release-id>
  F4  measured-quality proof   pass|fail|n/a   before <x> → after <y>, via <command>
  F5  auto: lines bind         pass|fail       <command> → exit:<n>|contains:<str>|exit:<n>+contains:<str>
  F6  r0 golden-journey auto:  pass|fail|n/a   <command> drives <actor> → <outcome>
  Verdict: ACCEPT | REJECT — <the floor that decided it>
```

F1 counts neither `[community-edition]` nor `[adoption-seed]` lines: both are
standing lines, not this spine's contribution (§1).

`n/a` is specific, never a dodge:

- **F2 `n/a`** only for an *admitted internal* spine (which may not have one).
- **F3 `n/a`** only for a user-facing spine (which needs no consumer).
- **F4 `n/a`** only for a spine claiming no measured quality. A spine whose plan
  says "faster", "more reliable", "cheaper" anywhere is claiming one.
- **F6 `n/a`** only for a spine outside Release 0.

`n/a` is never a way to skip a floor that applies.

**REJECT ⇒ no ledger call.** The remedy is always to fix the contribution, never
to record it and plan a follow-up: re-phrase (F2), name a consumer or send the
spine back to the feature map (F3), measure (F4), state the command (F5), author
the golden-journey line (F6).

---

## 3. F2 — judging a `user:` journey line

### 3.1 The test

> **Who performs this action, and why?**

A **user** places a trade, exports a report, resumes a session, cancels an order,
recovers a password — for the value the action produces. A **developer** inspects
a schema, views a record, opens a file, confirms a table exists, checks that a
row was written — to verify an artifact is present.

If the line only makes sense with a developer and a debugger behind it, it is not
a journey line, whatever verb it opens with.

### 3.2 Banned shapes

- **Artifact inspection** — "inspect the schema", "view the record", "open the
  generated file".
- **Artifact existence as the outcome** — "…to confirm the table exists", "…and
  see the row is there", "…and the file is present". Existence is not an outcome
  a user came for.
- **Protocol-level evidence** — "the endpoint returns 200", "the job exits 0".
  Those are `auto:` lines wearing a `user:` label. **This bans protocol trivia,
  not the API surface itself** — see below.
- **The passive dodge** — "the report is available to the user". No actor
  performs anything; nothing is observed.
- **An outcome with no falsifiable shape** — "place a paper trade → it works".
  "It works" cannot fail; a real outcome half names the observable that would be
  *absent* if the feature were broken ("…and see the fill land in the blotter").

### 3.2b Headless products — the user is a consumer, not a person

For a library, a database, or a service there is no screen, and spec §3 is
explicit that such a product "defines its journey at its real surface — e.g. a
downstream API round trip — and no UI is invented." **Do not read the
protocol-level ban as banning that surface**; read as a blanket rule it would
leave a headless product unable to author a single legal `user:` line, which is
the opposite of the intent.

The distinction is what the line *observes*:

| Line | Verdict |
|---|---|
| "the endpoint returns 200" | **REJECT** — a status code, not an outcome |
| "the job exits 0" | **REJECT** — an exit code, not an outcome |
| "query the store through the client SDK and see the results ranked by recency" | **ACCEPT** — a consumer reaches the value it came for |
| "submit an order through the client and get back a confirmed order id" | **ACCEPT** — round trip with an observable outcome |

The consumer is the actor: an integrating service, an SDK caller, another team's
code. Both audiences are valid — the person driving a UI, and the developer
driving an interface — and what the F2 test asks in both cases is the same:
**who performs this, and for what value?** "Because the protocol said 200" is not
an answer; "to get their results ranked" is.

`plan-release/references/class-declaration.md` rung 1 states the same rule for
spine *classification*. If these two ever disagree, a headless project gets its
spines classed `internal-enabler` and its demo lines rejected — both halves of
the same mistake.

### 3.3 The ban is on the action, not on the outcome

Every journey line ends in something the user can **see** — that is exactly what
"observable outcome" means. A line whose outcome is visible is **meeting** the
floor, not violating it.

Rejecting a line because the words *see*, *appear*, *shows*, or *displays* occur
in its outcome half is the **false-reject** failure mode. It is as damaging as
letting an inspector line through, because it pushes authors toward vague lines
with no observable half at all — which is how a ledger fills with `user:` lines
nobody can actually walk.

**Read the verb the user performs, and judge that.**

### 3.4 Worked pairs

| Proposed line | Verdict | Why |
|---|---|---|
| "view the generated invoice record to confirm the totals column is populated" | **REJECT** | Inspection verb *and* artifact-existence outcome. A developer checking a column, not a user getting value |
| "export last month's invoices as a PDF and see the download land with the right totals" | **ACCEPT** | Action = exporting (value); outcome = the file the user wanted, with the number that makes it correct. The visible outcome is the floor being met |
| "open the settings file and change the retention window" | **REJECT** | The action is editing a file by hand. If retention is a product setting, the line is "change the retention window to 30 days from settings and see old records stop appearing" |
| "the search index is queryable" | **REJECT** | Passive; no actor, no action, no observed outcome |
| "search for a customer by partial name and see matching records ranked by recency" | **ACCEPT** | Verb + observable outcome, both halves present |
| "resume an interrupted upload and see it finish from where it stopped" | **ACCEPT** | The visible "finish" is the evidence; the action is resuming |
| "cancel a working order from the order book and see it drop out of the working list" | **ACCEPT** | The action is cancelling; the visible list is the evidence it worked. Rejecting this because "see" and "drop out" occur is the false-reject failure mode |
| "review the generated trade summary and approve or override it before it submits" | **ACCEPT** | Here the review *is* the value — a decision gate the user came to perform, ending in an approved or overridden order. Contrast "review the generated schema" (§3.5): a review that ends in nothing but having looked is inspection |

### 3.5 The mechanical backstop and its exact scope

`oss ledger_add_user <spine> <text> <outcome>` lowercases `<text>`, trims leading
whitespace, and rejects it **only if it begins with** `inspect `, `view `, or
`open ` — exit **2**, nothing written.

The check is **prefix-only and three words long**. All of these are accepted by
the lib and are still inspector lines you must reject yourself:

- "lets the user open the settings file" (the ban word is not first)
- "review the generated schema"
- "confirm the audit table exists"
- "check that the record was written"
- "the report is available to the user"

**A rc 0 from `ledger_add_user` is not a verdict.** The lib exists so a typo
cannot smuggle the obvious case past you; the floor lives in this document and in
your judgment. Never cite "the command accepted it" as evidence a line is a
journey line.

---

## 4. F3 — internal-spine admission

Two judgments, in order. Conflating them is how the anti-foundation-phase rule
gets defeated.

**Judgment 1 — is it internal?** The spine has no actor-to-outcome journey: its
evidence of completion is that an artifact exists. **`plan-release` makes this
call** — its own `references/class-declaration.md` owns the ladder — and declares
it at release-planning time by prefixing the spine's name with `[internal]` and
recording the admission in the `class_set` reason. **Read that, do not recall it**
(SKILL.md §3 resolves `$name` alongside `$class`):

```bash
case "$name" in "[internal]"*) echo "internal — auto: lines only" ;; esac
oss get ".class_overrides[] | select(.spine == \"$spine\") | .reason"   # the admission record
```

You may be re-entered in a session that never saw the planning conversation. The
name marker and the reason string are the only durable carriers of this fact —
`.class` is `bone|flesh` and cannot express it (`spine_add` rejects
`internal-enabler` with exit 2, so an admitted enabler is stored under its
structural class). A spine that looks internal *here* but carries neither marker
nor admission reason is a planning miss: surface it, do not quietly re-label it.
Once the operator confirms the admission, `oss spine_rename "$spine" "[internal] <name>"`
adds the marker (name only, since 1.22.0).

**Judgment 2 — is it admitted?** Admitted **only if** it names:

1. a **committed user-facing spine** that consumes it — a real spine, with an id
   or a named candidate, not a capability area; **and**
2. that spine is scheduled in the **current release or the next** — the
   one-release-ahead cap.

Check both against state, not against recollection (`$rel` is the spine's release,
resolved at SKILL.md §3):

```bash
oss spine_list | jq -r '.[] | "\(.id)\t\(.release)\t\(.name)"'          # every planned spine
oss get ".releases[] | select(.id == \"$rel\") | .next_sketch"          # next release's candidates
```

A consumer named among the current release's spines, or in the current release's
`next_sketch.candidates`, satisfies the cap. A consumer three releases out, or on
the feature map only, does not.

Both reads are `jq -r` without `-e`: a no-match is **rc 0 with empty output**, so
judge the *output*. An empty `next_sketch` means `plan-release` never sketched the
next release — then the cap has nothing to read and the enabler is **not
admitted** until it does. That is the correct fail direction: the sketch is the
data structure this rule reads, not a courtesy to the reader.

**Silence is not a named consumer.** If the plan in front of you does not name
one, the answer is *not admitted* — do not assume a consumer exists because one
plausibly could. Send it back:

```bash
oss feature_add "<name>" "<the value it would enable>" bone feature-map-return
```

If the consuming spine is later **dropped**, the internal spine returns to the
feature map too. The dependency runs both ways.

### 4.1 Worked pairs

| Proposed contribution | Verdict | Why |
|---|---|---|
| An auth-token refresh layer contributing `auto:` lines only, justified as *"the mobile app will use it eventually"* | **REJECT — not admitted** | "Eventually" names no spine and no release. This is the exact phrasing the rule exists to reject; back to the feature map |
| A search-index writer contributing `auto:` lines only, naming the committed spine "saved searches" scheduled in **this** release | **ACCEPT — admitted** | Named, committed, in range. `auto:` only; it may not claim product value |
| A session-replay store contributing `auto:` lines only, naming a committed spine scheduled in the **next** release's sketch | **ACCEPT — admitted** | The one-release-ahead cap is *inclusive* of the next release; the sketch is the recorded object the rule reads |
| A normalization layer contributing `auto:` lines only, whose consumer is "the reporting area, sometime after v1" | **REJECT — not admitted** | A capability area is not a spine, and "after v1" is outside the cap |
| An internal spine that also proposes a `user:` line so it "has product value" | **REJECT** | An internal spine contributes `auto:` only. If it genuinely has a journey, it was misclassified at release planning — go fix that, do not launder it here |

---

## 5. F4 — before/after evidence

A pass claiming a measured quality must state, in its demo contribution:

1. the **before** number, measured on the pre-spine build **during planning** —
   a number written down without running the command is a guess, not a
   baseline — with the command that produced it;
2. the **after** target, as a bound (not a hope);
3. an `auto:` line that **re-measures and fails when the bound is missed**.

Closing green on the pre-existing test suite measures nothing — the suite was
green before the spine too. That is the failure this floor exists to block.

The `expected` grammar has **no comparison form** (`exit:<n>` | `contains:<str>` |
`exit:<n>+contains:<str>` only), so **the threshold lives inside the command**: the benchmark script does
the comparison and exits non-zero when the bound is missed.

```bash
# before: recorded in the spine plan — `hyperfine ./target/release/app --json` → cold start 4.2s
oss ledger_add_auto "$spine" "cold start ≤ 2.0s (was 4.2s)" "bash scripts/bench-coldstart.sh --max 2.0" "exit:0"
```

| Proposed contribution | Verdict |
|---|---|
| "cut cold-start time in half" — closes on the existing smoke test, no numbers stated | **REJECT** — no before, no after, nothing measured |
| "cold start 4.2s → ≤2.0s", bound to `bench-coldstart.sh --max 2.0` | **ACCEPT** |
| "make the importer more reliable" — no failure-rate baseline | **REJECT** — reliability is a measured quality; measure it or drop the claim |
| "importer retries transient failures" with an `auto:` line asserting the retry path, and **no** reliability claim in the plan | **ACCEPT** — F4 is `n/a`; nothing measured is being claimed |

The last row matters: F4 is not a tax on every spine. It fires on the **claim**.
A spine that does not claim a measured quality does not owe a measurement — and a
spine that wants to keep its claim owes one.

---

## 6. F5 — `auto:` line binding

```bash
oss ledger_add_auto "$spine" "<text>" "<command>" "exit:0|contains:<str>|exit:0+contains:<str>"
```

`<expected>` is validated as `exit:<n>`, `contains:<str>` or `exit:<n>+contains:<str>`; anything else exits
**2** and writes nothing. The command must be runnable from the composition root
against **composition-root post-merge state** — not from a worktree, not with a
developer's local env var, not with a manual setup step in someone's head. If
setup is required, the command performs it.

**Which form.** `contains:<str>` reads no exit status (it refuses only a command that
could not run, rc 126 or 127), so a command that crashes after printing the needle
passes it. When both must hold, write `exit:<n>+contains:<str>` (#770, the twin of the
AC form `exit <n> and output contains <str>`): the line passes only when the rc equals
`<n>` **and** the output holds the needle, and the needle is everything after the
**first** `+contains:`, so it may hold `+` or `contains:` itself. With `<n>` = 0 on a
recognised test runner, a run of zero tests fails too. An ossify older than 1.39.0
refuses the form, and a line already in the ledger fails closed under it, so author it
only once every install that closes this project is on 1.39.0.

**A line that can't state its command doesn't enter the ledger.** "We'll figure
out how to test this later" is a rejected line, not a recorded one.

Watch the cost: `oss ledger_active_auto` lists what the ledger already carries —
**`active` lines only**, and a line authored a moment ago is `planned` until its own
spine's close, so a read over the planning window that must see the lines this release
has just authored is `oss get '[.demo_ledger[] | select(.type=="auto" and
(.status=="planned" or .status=="active"))]'`. The release's `ledger_budget` (set at
`plan-release`) is the wall-clock ceiling. A contribution that will not fit forces a
prune / parallelize / deepen decision — raise it now, with the user, rather than
letting the suite grow past its budget silently.

**A line is authored `planned`, not `active`.** Its code does not exist yet, so
nothing runs it until something makes it live: this spine's close activates its own
lines before the demo, and `oss ledger_activate <line-id>` moves one early — the
round barrier or the operator does that when a round lands the code the line tests.
`active` at authoring is the adoption seed lines' case alone (§1), since they test
surface that already ships.

**A spine planned under a time-box escape records the clause at plan time.** Its
`SPINE.md` demo contribution carries the escape verbatim — "if nothing certifies in
two weeks, close on a written negative result" — because close quotes that clause and
only it: `oss ledger_escape` takes it as an argument, and with none recorded the
failed `user:` line halts as it always did. Writing one at close is not a thing.

---

## 7. F6 — Release 0's golden-journey `auto:` line

Release 0 is judged by the **clean-checkout test** (`start`'s
`references/skeleton-cut.md` §4): from a clean checkout the named actor enters
through the real entry point and reaches the observable outcome, with no storage
editing, no hidden developer operation, no manual repair. F6 is what keeps that
judgment from being a one-off: **Release 0 owes the cumulative ledger one
automated `auto:` line that drives that same journey end to end**, so it becomes a
standing regression test instead of a ceremony someone performed once.

`start` derives the skeleton cut against this bar and explicitly hands the
authoring here — it is a planning obligation, and a close-time check would fire
after the authoring window has already shut.

**Who authors it.** The Release 0 spine that owns the journey's **entry point** —
in practice the skeleton spine. Any other Release 0 spine satisfies F6 by
finding the line already in the ledger — through §6's `planned`-inclusive read,
since the line the skeleton spine just authored is not yet `active` — or by
naming the spine that will author it; it does not author a second one.

```bash
oss get '[.demo_ledger[] | select(.type=="auto" and (.status=="planned" or .status=="active"))]' \
  | jq -r '.[] | "\(.id)\t\(.source_spine)\t\(.text)"'
```

**What counts.** One command, runnable from the composition root against
composition-root post-merge state, that exercises the whole journey — entry point,
through the layers the journey crosses, to the observable outcome — and exits
non-zero if any leg breaks:

```bash
oss ledger_add_auto "$spine" "the golden journey: <actor> <action> → <outcome>" \
  "bash scripts/golden-journey.sh" "exit:0"
```

**What does not count**, however green it runs:

| Proposed as the golden line | Verdict |
|---|---|
| The whole unit-test suite passing | **REJECT** — it was green before the spine too, and it crosses no journey |
| An `auto:` line per layer (parser ok, store ok, renderer ok) | **REJECT** — three layer assertions are not one journey; the seams between them are exactly what this line exists to hold |
| A command that starts at an internal function rather than the real entry point | **REJECT** — same failure the clean-checkout test rejects, wearing an `auto:` label |
| A command needing a developer's local env var or a manual setup step | **REJECT** — F5's runnability bar applies; if setup is required, the command performs it |
| One command driving the entry point to the actor's outcome, exiting non-zero on any broken leg | **ACCEPT** |

A `user:` walkthrough of the same journey is **also** required (F2) and does not
substitute for this. They fail differently: the walkthrough catches what a human
notices, the `auto:` line catches the regression nobody walks for.

---

## 8. Anti-patterns

- **Citing `ledger_add_user`'s rc 0 as proof a line is a journey line.** Prefix
  check, three words, backstop only (§3.5).
- **Rejecting a line because its outcome is visible** (§3.3).
- **Admitting an enabler on an unnamed or out-of-range consumer** (§4).
- **Letting an internal spine contribute a `user:` line** or claim product value.
- **A measured-quality claim that closes green on the pre-existing suite** (§5).
- **Closing Release 0 with its core journey as a human walkthrough only** — or
  offering the existing test suite, or a per-layer set of `auto:` lines, as the
  golden-journey line (§7).
- **Recording a line you intend to fix later.** The ledger is cumulative.
- **Passing `active` to `ledger_add_auto` / `ledger_add_user` at plan time** (§6).
  That is the adoption seed lines' case alone (§1); here the code does not exist yet, and the line would
  run at a sibling spine's close reporting the plan as a defect.
- **Authoring demo lines at roadmap time** — the reason they moved here is that
  roadmap time has no implementation context.
- **Running the demo here.** `close` owns the run; you author the criteria.
