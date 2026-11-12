# State inspection

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

The depth behind `doctor/SKILL.md` §4. **`oss doctor` is now its four-check
gate** — the ones a close blocks a mutation on. The other **five** advisory
areas are yours to read, and this file is how.

---

## 1. What the verb does, and what you do

`oss doctor` runs four checks: `state`, `schema`, `replay`, `shape`. A healthy run
prints **three** lines — `schema`, `replay`, `shape`. `state` has only a failure
arm: if the file is not there you get `fail: state` and nothing else, because
every later check would read it. So do not count lines to decide whether a check
ran; read the tags.

Those four stayed deterministic on purpose. `close/SKILL.md` §3 refuses to run
until `schema` and `replay` are green, and **replay is not something to eyeball**
— it rebuilds the state from its base snapshot by applying every journaled
mutation in order and compares the result. That is exact-identity work, it is the
only thing that can prove the live file still agrees with its own history, and no
other verb exposes it. A rail in front of a mutation is not a read-out, whatever
it is spelled with.

**Everything else this surface reports, you read yourself** — a lock directory, a
few counts, and a per-repo orphan comparison. Those were ~210 lines of bash that
opened files and described them. They gated nothing: every one emitted `warn:` or
`skip:`, and neither ever set rc.

### The line grammar — use it for your lines too

| Tag | Meaning | Touches rc? |
|---|---|---|
| `ok:` | ran, found nothing | no |
| `warn:` | ran, found something advisory | **no** |
| `fail:` | ran, found something broken | **yes — the verb exits 1** |
| `skip:` | could not run, and says so | **no** |

Two properties are load-bearing:

- **A check that cannot run still emits a line.** The verb prints
  `skip: replay - skipped (schema check failed)` rather than dropping it, because
  a *missing* line is indistinguishable from a clean one. **Hold your own lines to
  the same rule** — if you cannot reach a repo, say `skip:` and why. This is not
  hypothetical: the worktree check shipped in v0.3 asking only about `canonical`,
  so a project with a configured `private_core` got a clean read-out about a repo
  nobody had opened (#156).
- **`warn:` never changes the rc.** `oss doctor` exiting 0 means "nothing broken",
  not "nothing to report" — and it now says nothing at all about the five
  advisory areas. A close pre-flight that checks only the rc is still correct;
  it is deliberately not the whole picture.

---

## 2. The checks

**The verb's four**, in print order:

| Check | Reads | What it catches |
|---|---|---|
| `state` | the file | it is not there at all |
| `schema` | state file | a `schema_version` this build cannot handle |
| `replay` | journal | live state that disagrees with base + mutations |
| `shape` | state file | any of the 16 required top-level keys missing |

`replay` is gated on `schema`, because replaying against a version this build
cannot read produces noise rather than a finding. That gating is why its `skip:`
line exists.

**Yours to read.** Each is a count or a directory check; report one line each in
the same grammar. Run them after the verb, so a broken state fails first:

```bash
# ONE path for the whole read-out, and pass it to doctor too.
sf="${OSS_STATE_FILE:-$(oss state_path)}"
oss doctor "$sf"           # the gate, on the SAME state the reads below use
oss get '[.demo_ledger[] | select(((.pending_amendments // []) | length) > 0)] | length' "$sf"
oss get '[.demo_ledger[] | select(.status == "quarantined")] | length' "$sf"
oss get '[.demo_ledger[] | select(.status == "planned")] | length' "$sf"
oss get '[.demo_ledger[] | select(.status == "deferred") | "\(.id) due \(.deferred_until_release // "no-release-anchor")"]' "$sf"
oss get '[.demo_ledger[] | select(.status == "escaped")] | length' "$sf"
oss get '[.fakes[] | select(.status == "active" or .status == "renewed")] | length' "$sf"
oss get '.patch_records | length' "$sf"
```

**Resolve `sf` once, with `$OSS_STATE_FILE` first, and pass it to everything —
including `oss doctor`.** `oss state_path` alone is **wrong** here: it returns the
*manifest-routed* path and ignores the environment, while `oss doctor` resolves
through `_oss_resolve_state`, which gives an exported `$OSS_STATE_FILE`
precedence. Pin to `oss state_path` and your read-out mixes two projects — gate
lines about the override, advisories about the manifest's project. Measured: with
`OSS_STATE_FILE` pointing at another workspace, `oss doctor` reports `projB`
while `oss get … "$(oss state_path)"` reports `projA`.

Passing `"$sf"` to `oss doctor` as well is what makes this robust rather than a
transcription of its precedence: one explicit path, used everywhere, so the two
halves cannot diverge even if the resolver changes.

**This is the opposite of what `spec-validation.md` §3 does, and both are right.**
There, the bones-vs-spec comparison deliberately pins to `oss state_path`
*regardless* of the override, because it is binding two different artifacts to one
project. Here the job is to describe **the state `oss doctor` just gated**, so the
read must follow doctor's own resolution. Do not harmonise them; the difference is
the point — and §3 carries it in a differently named variable (`sv_state`), so a
composed session cannot reassign this surface's `sf` or vice versa.

| Yours | Reads | Emit |
|---|---|---|
| `lock` | `<state>.lock` dir | present → `warn: lock - held (a ceremony may be mid-mutation)`, or if the dir is **>30 min old**, `warn: lock - stale lock dir (>30min): rmdir '<state>.lock' if no ceremony is running`. Absent → `ok: lock - free` |
| `ledger` | `demo_ledger` | **up to two `warn:` lines, counted separately**, plus the counts of the lines that will not run — see below |
| `fakes` | `fakes` | count > 0 → `warn: fakes - N outstanding fake(s) carrying a replacement trigger and expiry release`. Zero → `ok: fakes - none outstanding` |
| `patches` | `patch_records` | count > 0 → `warn: patches - N out-of-spine patch record(s) on this project (the registry is append-only and is not reset at spine close)`. Zero → `ok: patches - no out-of-spine patch records` |
| `worktrees` | **the repos** | see §4 — one line per repo key |

**`ledger` is two counts sharing one clean line, and that shape matters.** Pending
amendments and quarantined lines are counted and reported *independently*:

- pending > 0 → `warn: ledger - N demo line(s) carry a pending amendment awaiting a
  spine close ('oss ledger_unplan <line-id> <spine>' to drop one)` — **carry that
  remedy**; it is the verb an operator needs and nothing else names it here.
- quarantined > 0 → `warn: ledger - N quarantined line(s); each must be fixed or
  retired by the next release close`
- **`ok: ledger - no pending amendments, no quarantined lines` only when BOTH are
  zero.** A clean line while one counter is dirty is the failure the deleted code
  guarded against explicitly, and its test named it: *"the ledger clean line fired
  while one of its two counters was dirty."*

**The three statuses read here too, and none of them is a warning.** A `planned` line
is authored and not built yet, a `deferred` one is still owed to a named release, an
`escaped` one closed on a declared negative result — all three are lines the ledger
carries that will not run, so name the counts, and each deferral's due release beside
them (`no-release-anchor` when it has none: that row blocks a release close). They
stay out of the clean line above; a `planned` line is the normal state of a line whose
spine is still open.

**Unreadable is `skip:`, never a count and never `ok:`.** All three, spelled out —
note the check name is not the field name, so do not derive one from the other:

```
skip: ledger - unavailable (.demo_ledger could not be read as a countable list)
skip: fakes - unavailable (.fakes could not be read as a countable list)
skip: patches - unavailable (.patch_records could not be read as a countable list)
```

**Check the TYPE of every counted field before you trust any count — one guard,
all three.** `jq`'s `length` is defined on strings and objects, and `[]` iterates
an **object's values**, so a structurally corrupt field returns a plausible number
at rc 0 rather than an error. Run this first and treat any non-`array` as `skip:`:

```bash
oss get '{ledger: (.demo_ledger|type), fakes: (.fakes|type), patches: (.patch_records|type)}' "$sf"
```

Measured, all three ways a corrupt field lies:

| Corruption | The count query returns | rc |
|---|---|---|
| `.patch_records = "oops"` (string) | **4** — the character count | 0 |
| `.demo_ledger = {…two entries…}` (object) | **2** — object values iterate | 0 |
| `.fakes = {…one entry…}` (object) | **1** — same | 0 |

Take any of those at face value and you report `warn: patches - 4 out-of-spine
patch record(s)` or `warn: ledger - 2 quarantined line(s)` about fields holding no
records at all. The deleted bash guarded this with a `def _arr(f): … else error`
wrapper applied to **every** count, not to one of them; the single query above is
that wrapper's replacement, and it has to cover the same three fields.

**A field that will not read as a list is `skip:`, not `ok:`** — and not `warn:`
either. Say the field could not be read as a list. Reporting a count there is the
same lie as omitting the line.

**Where is `<state>.lock`?** Beside the state file — `"$sf.lock"`, using the same
`$sf` as every other read here. **Not** `"$(oss state_path).lock"`: that is the
manifest-routed path, so under an override you would report the lock of a project
the rest of the read-out is not describing.
It is a directory, and its mtime is how you tell stale from held — more than
about half an hour old and no ceremony running means it was left behind. Do not
remove it on a hunch; say what you found and let the operator decide.

---

## 3. The remedy table

**Echo `doctor`'s own failing line rather than substituting a fixed remedy.**
The remedy differs by line, and the wrong one loops the operator:

| `doctor` line | Remedy |
|---|---|
| no tagged line, nonzero rc, refusal on stderr | echo the refusal verbatim; remedy is `/init-workspace` (new workspace) or `/pair-workspace` (existing canonical) — the manifest is missing, and no check ran |
| `fail: replay` | **`oss state_restore`** — rebuilds live state from base + journal |
| `fail: shape` | **`oss state_restore`** — a required key is missing; same rebuild |
| `fail: schema`, version **below** this build | **`oss migrate`** — the state predates this build |
| `fail: schema`, version **above** this build | **upgrade ossify.** `migrate` accepts v1, v2 and v3 (v3 → v4); there is no downgrade |
| `fail: state` | **`/ossify:start`** (a new project) or **`/ossify:adopt`** (one that already has code) — on Codex the `start`/`adopt` skills — never initialised; each runs `init` itself, and a bare `init` first leaves state both refuse |
| `warn: lock` (stale) | `rmdir '<state>.lock'`, **only** if no ceremony is running |

The rc rule SKILL.md §3 states — rc 0 unless a `fail:` line printed — holds only
once the state path resolves. A resolution refusal exits 1 with **no** check
line at all, and the surface emits `skip: state - no topology declaration, so no
state file could be resolved`.

**The table is a starting point keyed on the tag, and the tag is not the whole
finding.** Read the rest of doctor's line before recommending anything — the
same four tags cover conditions these verbs cannot repair:

- **A schema version *newer* than this build.** `oss migrate` accepts v1/v2/v3; a
  future version is an ossify upgrade, not a migration. doctor already says
  *"requires a newer ossify"* in its own line, which is exactly why you echo it.
- **A corrupt journal, or a missing base snapshot.** `oss state_restore`
  refuses both by name. Recommending it anyway sends the operator around a loop
  whose every lap looks like progress.

Why this is not pedantry: against a v1, v2 or v3 state, `oss state_restore` prints
`restore: state is already clean - nothing to do` at **rc 0**, leaves
`schema_version` untouched, and the next `oss doctor` fails identically. A
remedy that exits 0 while changing nothing is the worst kind of wrong answer,
because the operator has no signal that they are stuck.

**You never run these.** Name the verb; the user runs it. The one exception in
this whole skill is rule authoring, and the user asked for that explicitly.

---

## 4. Orphan worktrees

New in v0.3, and the only check that reads the repository rather than the state
file.

```bash
# EVERY declared repo key, plus ai_workspace, not a sample - the automatic loop that used
# to cover them is gone, so an omitted key costs its line and #156 comes back.
# READ that set from the manifest at run time rather than trusting a list written here: a
# transcribed copy is exactly the drift the deleted (12b) guard used to catch.
# ALWAYS both arguments: the repo key AND the state this run is inspecting -
# the same "$sf" the rest of the read-out uses (§2), never a fresh oss state_path.
oss worktree_orphans <key> "$sf"     # once per declared key
```

**Pass the key every time — the verb does not make you.** Omitting it resolves
to the sole declared repo under one, and refuses outright naming the declared
set under more than one (`oss_cmd_worktree_orphans` and `oss_worktree_orphans`
both default that way, #272/#310 Task 4 — never a silent guess). Relying on
that default anyway is still how #156 happened: a habit formed on a
single-repo project, carried unexamined into one with more, so a bare
`oss worktree_orphans` answers a question about whichever repo happened to be
sole when the habit formed, not the one you meant today. Making the argument
mandatory is a breaking change to a
shipped verb and is tracked separately; until then the discipline is yours, not
the tool's.

**What it reports:** directories under `<repo>/.worktrees/` that no work item
claims. A directory is *claimed* when a work item's journaled `worktree_path` is
exactly it, **or** when its basename is a work item's id — and only when that
work item's `target_repo` is the repo being asked about, so a `private_core`
item cannot claim a same-named directory sitting under the public root.

**You run the selector once per repo key, and the keys are every repo the
manifest declares, plus `ai_workspace` — resolved from the manifest at run
time; no list here to go stale** —
printing `ok:`/`warn:`/`skip: worktrees(<key>)` for each. `oss doctor` used to
do this and no longer does; the verb it called is unchanged. **Every key costs a line**, including the ones this
project does not configure. A key the manifest does not configure gets the `skip:`, as does one
whose root does not exist on this machine **or cannot be traversed** — an
unmounted volume and a checkout whose root denies `x` both land there. So does a
state whose work-item claims could not be inspected, which is a
*state-side* cause wearing the same line: the skip names both families, because
one that listed only the repo-side ones would send you to debug a healthy
manifest while the corrupt state went unnamed. None is ever silently dropped,
because "could not open it" and "opened it and found nothing" are the two states
this check exists to keep apart.

**Traversal, not read, is what the root needs** — the check reaches
`<root>/.worktrees` by composing the path and never lists the root itself. So a
traversal-only root (mode `0111`) is inspected and its orphans reported, not
skipped. `.worktrees` needs **both**, because that directory *is* enumerated.
Requiring read on the root was #162: a guard stricter than the operation, which
turned a usable repo into a skip and cost real detections.

**Two gates come before the per-key loop, and they emit one *unkeyed* line for
the whole surface**: state health being red, and the inspected state not being
this directory's manifest-routed state. Both are properties of the run, not of
any one repository, so a keyed line per repo would repeat the identical reason
three times. Read `skip: worktrees - skipped (…)` with no key as *the surface
did not run at all* — which is why it names its cause. So the contract is: keyed
lines when the comparison runs, one unkeyed line when it could not.

*Why that is worth a paragraph:* the v0.3 shipping build called the selector
with `canonical` hardcoded. The selector itself was already parameterized, so
nothing looked wrong — the read-out simply asserted `ok: worktrees - none
orphaned` for projects whose `private_core` root it had never opened. Private
work accumulating under an unchecked root is the exact failure the public/private
boundary exists to prevent, so a *false clean* here is worse than no check at
all. Fixed as #156; the per-key lines are what make the difference visible.

**Why the second arm exists:** `oss worktree_add` names the directory for its
work item but writes nothing to state — `worktree_path` appears only once
`oss work_item_exec` journals it. Matching on the path alone would report every
freshly-spawned worktree as an orphan, i.e. it would be loudest exactly when the
project is behaving correctly.

**Why it matters at all:** spine close removes worktrees by *reading state*
(`close/references/spine-close.md` step 10). A directory state does not know
about is therefore cleaned by no ceremony at all. It accumulates in the very
repo whose cleanliness `close` then checks, and the first symptom is a close
failing for a reason that has nothing to do with the spine being closed.

**The rc trap.** This is a **pure selector**: the finding is its OUTPUT.
`rc 0` means the check *ran*, not that the tree is clean. Branch on the rc and
every project reports as orphan-free. This deliberately does **not** copy
`oss touch_check`'s rc-0-is-a-hit polarity — that convention exists for a gate,
and nothing on this surface is a gate.

**The remedy is a judgment call, which is why it is not automated.** An orphan
may be:

- a leftover from a work item given up mid-flight — safe to remove, *after*
  checking it has no uncommitted work: `git -C "<orphan>" status --porcelain`;
- a worktree whose state record was lost — the directory is the *survivor*, and
  deleting it destroys the only copy;
- someone's hand-made scratch directory that happens to live there.

Never remove one on the user's behalf. Report the paths, and note that
`oss worktree_remove` refuses on a dirty worktree by design.

**The inverse drift — a state record whose directory is gone — is not part of
this check.** `oss worktree_resolve canonical <wi-id>` returns rc 1 for exactly
that case, per work item. Reach for it when a close has already failed on a
missing worktree; it is a targeted probe, not part of the sweep.

---

## 5. State-vs-repo drift that no verb can decide

This surface compares the state file against itself and, for worktrees, against
one `.worktrees/` directory per configured repo. The following are drift that
only reading can find, and they
belong in the read-out when the sweep gives you reason to look:

- **A spine marked `closed` whose branch never merged.** `close` guards this at
  close time; a state edited by hand does not get that guard.
- **A bones-registry entry with no row in the spec's bones index.** This is the
  spec-validation surface's job — see `references/spec-validation.md` §3 — but
  the *state* half of the comparison lives here.
- **A `complete` work item whose `report.md` is absent.** The harvest sweeps
  reports; a missing one silently narrows the next harvest.
- **An `abandoned` work item with a recorded dispatch field — `branch`,
  `worktree_path` or **`base_sha`** — or a positive `dispatches` count.**
  `abandoned` means withdrawn *before any
  dispatch* (`plan-spine/references/decomposition.md` §1); any of those says
  it was dispatched, so either the status or the dispatch is wrong. The third
  field is the one a two-field read missed, and it is not hypothetical:
  `oss work_item_exec <wi> "" "" <sha>` records `base_sha` alone at rc 0
  (a hand-recovered dispatch), which a `branch`-or-`worktree_path` read called
  undispatched — so the item abandoned successfully and its work was stranded.
  The rail now reads all three fields; this bullet must name all three, or the
  report and the rail disagree about what "dispatched" means. **The
  `dispatches` count (#673 F3) is the fourth evidence and belongs in this
  bullet and in close's §1 guard**: an item whose dispatch was counted and
  then died before `work_item_exec` records NO exec field, so the count is the
  only proof it was dispatched — a counted-but-unexec'd item otherwise reads
  as a clean withdrawal at close and escapes this drift bullet. Close skips an
  abandoned item entirely, so work in that worktree never reaches the spine.
- **A bone's or gate's touch surface matching NO tracked file in any declared repo.**
  Per SURFACE, not per glob: `touch_check` answers per match, so a list that is
  only PARTLY dead still records a hit and is not reported here.
  `touch_check` goes silently **clean** on such a surface, so the spine is never
  reclassified to `bone` - the reclassification is the harm, and it is real on
  its own (the release-close docs trigger that would also read it is not shipped;
  `release-close.md`'s gate table says so). The
  1.11.0 re-point verbs *repair* such a surface and nothing *detects* one — a
  re-point to a glob that matches nothing is accepted at rc 0, which is how a
  mis-guessed correction leaves the surface exactly as broken as it was. Sweep
  for it:

  ```bash
  # The corpus is every tracked path in every declared repo. `$repos` is the
  # declared repo-key list, one per line, from the manifest read doctor's interop
  # check already performs (`interop-check.md`, "`ai_workspace` and every declared
  # repo": a native topology's `.repos` object; a legacy pairing manifest's
  # top-level `.root` objects OTHER than `ai_workspace`, which the normalized
  # manifest excludes from `.repos`, so a planning file can never satisfy a stale
  # product glob) - no verb lists the keys, so this is an agent-performed read.
  # The SEMANTICS ORACLE is touch_check,
  # never a hand-rolled glob match: a shell `*` crosses `/`, so a matcher written
  # here would disagree with the verb that decides reclassification.
  #
  # Every failure that would otherwise READ AS AN ABSENCE is reported instead: an
  # unreadable registry makes every batch inconclusive, an unreadable repo
  # contributes no hits, and either one would turn every surface into a finding.
  probe_rc=0; oss touch_check . >/dev/null 2>&1 || probe_rc=$?
  state_rc=0; oss get 'true' >/dev/null 2>&1 || state_rc=$?
  # The state IN PLAY is §2's resolved "$sf" - consumed, never re-derived: this
  # block owns no copy of the precedence and makes no second resolver call. The
  # routed half comes from the ONE state_path call below, to compare against.
  # What the gate refuses, and why, is owned by the prose under this fence.
  routed="$(oss state_path 2>/dev/null)" || routed=""
  if [ -z "${repos:-}" ]; then
    echo "skip: touch - the declared repo keys could not be read, so the sweep did not run"
  elif [ "$state_rc" != 0 ]; then
    echo "skip: touch - the state could not be resolved or read, and touch_check returns its resolver's rc 1 WITHOUT checking anything, so an empty hit file would not be an absence"
  elif [ -z "${sf:-}" ] || [ -z "$routed" ] || [ "$sf" != "$routed" ]; then
    echo "skip: touch - the state in play ('${sf:-unset}') is not this directory's manifest-routed state ('${routed:-unresolved}'), so a repo-vs-state comparison would cross projects, and the sweep did not run"
  elif [ "$probe_rc" = 2 ]; then
    echo "skip: touch - the bones/risk-gate registry could not be read (touch_check answers rc 2), so no absence below would be sound"
  else
    # The roster: what each warn line NAMES, and WHICH VERB its remedy takes -
    # never from memory. `touch_check` answers "<kind> <id>" per match, says
    # nothing at all about a surface that matched nothing, and never the glob, so
    # the id-kind-and-glob half of the report has no other source; the
    # `not-applicable` exclusion below is read from it too. It is read HERE, past
    # every refusal, so a skipped sweep reads no registry at all.
    # Each branch is parenthesised: `[a[] | {…}, b[] | {…}]` binds the comma
    # INSIDE the pipe and iterates the second projection over the first's
    # elements, which answers rc 5 and empties the roster. The shape is load-
    # bearing: every entry must carry `kind`, `id` and `touch` alike.
    roster="$(oss get '[(.bones[] | {kind: "bone", id: .adr, touch: (.touch | join(", "))}), (.risk_gates[] | {kind: "risk_gate", id: .name, touch: (.touch | join(", "))})]')" \
      || roster=""
    hits="$(mktemp)"; skipped=""; read_any=""
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      listed="$(mktemp)"
      root="$(oss repo_root "$name")" \
        && git -C "$root" ls-files -z > "$listed" \
        || { echo "skip: touch($name) - the repo could not be read: no usable root, or its tracked files could not be listed"
             skipped="$skipped $name"; rm -f "$listed"; continue; }
      read_any=1
      if [ -s "$listed" ]; then
        # No `-n`: xargs splits at the system's own argument limit, so a corpus
        # costs one dispatcher per limit-sized batch rather than one per 200
        # paths (#558). Every batch's rc is discarded, as the finding below is
        # an absence rather than an exit status.
        xargs -0 oss touch_check < "$listed" >> "$hits" || :
      fi
      rm -f "$listed"
    done < <(printf '%s\n' "$repos")
    # With EVERY repo skipped, $hits is empty because nothing was READ, so the
    # absence rule below must not run - every healthy surface would be reported
    # from a sweep that inspected nothing.
    [ -n "$read_any" ] \
      || echo "skip: touch - no declared repo could be read, so the sweep inspected nothing"
  fi
  ```

  **The finding is the ABSENCE of a line, not the rc.** Each batch answers 0 for
  a hit, 1 for clean, 2 for inconclusive; `xargs` returns 123 when any batch
  answers non-zero, which is the ordinary case here and is not an error. Read
  `$hits`: every surface that appears there matched at least one tracked file.
  Every bone and gate that does **not** appear is a `warn:` line naming the id and
  the glob list —
  `warn: touch - bone ADR-0003 matches no tracked file in any declared repo: packages/ma/silver/**, packages/ma/ingestion/**`.
  **That absence is only whole-corpus when the whole corpus was read.** A repo that
  could not be read is `skip: touch(<key>) - …` in the §1 grammar and is named in
  `$skipped`; a surface missing from `$hits` may have matched a file in one of those
  repos, so with `$skipped` non-empty report the misses as *unmatched in the repos
  that were read*, naming the keys — never as matching no tracked file at all. The
  empty corpus, the unreadable registry above and a read set that came back
  EMPTY - every declared repo skipped - are the same rule at their own scale:
  each reports its own failure instead of an absence it cannot support, so a
  sweep that did not run says that, rather than reporting every surface.

  **The sweep is about THIS directory's state, and this paragraph owns the
  gate.** §2 resolved `$sf`; the block compares it against ONE `state_path`
  answer and refuses the run — §4's rule, one unkeyed line naming both paths —
  whenever they differ **or the route cannot be resolved at all**, because
  "cannot be compared" is not "the same project": a manifest whose
  `project_state` value is not absolute resolves to nothing, and a gate that
  treats that as consent sweeps a foreign registry against this directory's
  repos. Paths are compared **as written** — the blunt convention
  `_oss_resolve_state` announces — so an equivalent spelling of the same file
  refuses too: visible, never a silent false clean. The harm it prevents is
  exact: the surfaces would come from one project while the corpus comes from
  another, so every surface of the foreign state would be reported as matching
  no tracked file, after inspecting the wrong repos, with every command exiting
  0.

  **The ids, the KINDS and the glob lists come from `$roster`**, never from
  memory: it pairs every bone and gate with its kind and its touch list, and
  `touch_check`'s own output cannot supply the rest it prints `<kind> <id>` per
  match and nothing for a surface that matched nothing.
  Two exclusions, both deliberate: a surface whose list carries `not-applicable`
  is left alone (it matches nothing *on purpose* — `bones-registry.md` §2/§6),
  while a surface with an **empty** list is reported, as its own line: that is the
  §6 anti-pattern, "a comment, not a bone". The remedy is a re-point — with the
  verb chosen from the surface's own `kind`, `bone_set_touch` for a `bone` and
  `risk_gate_set_touch` for a `risk_gate`, never guessed from the id's shape —
  or a legitimate `not-applicable`, and which one it is belongs to the operator,
  per the section's closing rule.

Report these as findings with their evidence. Do not repair them. **Remove
`$hits` once the warn lines are written** — `rm -f "$hits"` — it is this
surface's only temp file (each repo's `$listed` is removed as it is read) and
nothing else cleans it up (#558).

**List the `abandoned` work items by id in the read-out** even when nothing is
wrong with them — a line, not a finding: each is work the plan withdrew, and
its spine's `SPINE.md` should say why.

---

## 6. The feature map

`oss feature_list` reads it. Inspection only.

**Settled, v0.3: the feature map does not get a persisted rank or a prune
verb.** `plan-release/references/feature-map-grooming.md` §2 left this open —
"if a persisted rank ever earns its keep, that is where the argument belongs" —
and `doctor` is the "there" it named. The argument was had and it does not
earn its keep:

- **The ranking is a grooming conversation's working order**, not an attribute
  of a feature. Its only durable output is *this release's spine selection*, and
  that already persists in `RELEASE.md`.
- **A prune means "not carried into this release"**, recorded as rationale in
  `RELEASE.md`. It does not delete the entry: the map is append-only history,
  and the reason a candidate was passed over is exactly what the next groom
  needs.
- **`doctor` existing changes nothing about that.** It makes the map
  *inspectable*, which was the only thing the deferral was waiting on. An
  inspectable append-only log does not become a ranked queue by being readable.

So the map keeps its two verbs, `oss feature_add` and `oss feature_list`. If the
question returns, it needs new evidence — a groom that demonstrably lost
information the two verbs could have kept — not a second re-litigation of the
same argument.
