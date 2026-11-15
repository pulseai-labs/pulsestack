# Pre-flight

Depth for SKILL.md §3. Pre-flight is the first half of the **gate phase** — the
part of the run that can still stop before any work starts. The second half is
SKILL.md §4's RED gate, which runs only on the success path out of here and can
also return gaps-mode. **§3 and §4 together are where a `gaps-surfaced` return is
legal; from §5 onward it is not** (SKILL.md §10).

It re-runs **from scratch on every dispatch.** On a re-dispatch the handoff has
grown a clarifications section; reading it end to end again is exactly how those
resolutions reach you. Do not cache, do not skim because "I read this last time" —
in a fresh subagent there is no last time, and in a Mode A re-invocation the file
has changed underneath you.

---

## 1. The four hard gates

### Gate 1 — the handoff is complete

Read it with the **Read tool** against the absolute path. Not `cat`. The
orchestrator audits your tool-call log; a Read entry is evidence that you read the
file, a bash pipeline is evidence that a shell did.

Five things must resolve:

| Field | Fails how |
|---|---|
| Worktree absolute path | Nothing to `git -C`; every later step is guesswork |
| Declared branch | Gate 3 has nothing to compare against |
| Spec path | No ACs, so nothing to build or verify |
| Verification commands | SKILL.md §6 has nothing to run |
| Constraints | See below |

Constraints must carry **both** `git_policy: STAGE-not-commit` **and** the return
JSON shape. Either one missing makes the handoff malformed, and **that is itself a
gap** — return gaps-mode naming the missing field.

The temptation is to shrug and proceed: you know the policy, it is in your own
body. Resist it. A handoff that never stated the boundary may have been produced
by something that does not know the boundary exists, and the rest of that handoff
is then equally suspect.

### Gate 2 — the spec reads and its ACs parse

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

Read the spec end to end (Read tool, absolute path), then:

```bash
oss verify_acs "<abs spec path>"
```

One TSV row per `auto:` AC — `label <tab> command <tab> expectation` — in
**declared order**. That order is the working order for the whole run.

If the spec visibly has AC lines and this prints nothing, the AC grammar is
malformed — a missing or wrong checkbox (`- AC-1` or `* [ ] AC-1` instead of
`- [ ] AC-1`), or a missing `auto:` marker. A line that has the checkbox and
`auto:` but **no backticks around the command** is also malformed and is
skipped with a stderr warning (check the tool output for "no backticked
command"). That is a gap. Do **not** hand-parse the lines yourself and carry
on — you would be building against ACs the orchestrator's own gate cannot see,
and the mismatch surfaces at close instead of now.

**Rows can come back malformed too — check their shape, not just their count.**
Two malformations still produce a row: an ASCII `->` where the grammar wants
`→`, and a missing `expected:`. In both the tail of the line lands in the
**expectation** field instead of being parsed, so the row looks present and is
unusable. Check every row:

```bash
bad_exit() { # $1 = the text after 'exit ' ; returns 0 when it is NOT a usable 0-255 status
  local w="$1" m
  case "$w" in ''|*[!0-9]*) return 0;; esac
  m="${w#"${w%%[!0]*}"}"; m="${m:-0}"
  if [ "${#m}" -gt 3 ] || [ "$m" -gt 255 ]; then return 0; fi
  return 1
}
acs_rc=0; acs="$(oss verify_acs "<abs spec path>")" || acs_rc=$?
[ "$acs_rc" -eq 0 ] || echo "GAP: verify_acs exited $acs_rc - the spec did not parse"
printf '%s\n' "$acs" | while IFS=$'\t' read -r label cmd exp; do
  [ -n "$label" ] || continue
  case "$exp" in
    "exit "*" and output contains "?*)
      w="${exp#exit }"; w="${w%% and output contains *}"
      if bad_exit "$w"; then echo "GAP $label: 'exit' takes 0-255, got '$exp'"; fi ;;
    "exit "*)            if bad_exit "${exp#exit }"; then echo "GAP $label: 'exit' takes 0-255, got '$exp'"; fi ;;
    "output contains "?*) ;;
    *) echo "GAP $label: expectation '$exp' is not 'exit <n>', 'output contains <str>' or 'exit <n> and output contains <str>'" ;;
  esac
done
```

The read happens **before** the loop: `verify_acs … | while …` would run the
loop in a subshell that cannot see `verify_acs`'s own rc, so a spec that failed
to parse at all would look like a spec with zero rows.

**Any `GAP` line is a blocking gap — return gaps-mode.** Do not "fix" the AC by
reading past the garbage: the spec is what the close gate reads too, so an AC
that is wrong here is wrong there. Left alone it costs the whole TDD loop —
`oss redgate` answers rc 2 (malformed) rather than rc 0 (RED), so the loop
cannot even start honestly, and `oss verify_step` rejects the same row at rc 2
two ceremonies later at the close gate, where recovery option 1 ("re-dispatch
the implementer — the default when the code is wrong") points at code that was
never the problem.

`user:` lines are documentation for the implementer only — no ossify gate parses
a `user:` AC. The walked half lives in the demo ledger (`close`'s to run,
keyed by spine). Skip them here.

### Gate 3 — the worktree is real, clean, and on the declared branch

```bash
git -C "<worktree-abs>" status --porcelain          # MUST print nothing
git -C "<worktree-abs>" rev-parse --abbrev-ref HEAD # MUST equal the declared branch
```

Three ways this fails, all gaps:

1. **Not a worktree** — the path does not exist or git refuses it. The spawn step
   did not run, or the worktree was removed under you.
2. **Wrong branch** — usually a stale checkout left by an aborted earlier run.
3. **Dirty** — *any* line of `--porcelain` output counts: modified, staged, or
   untracked alike.

`oss work_item_branch "<work-item-id>" "<slug>"` prints the branch name the id
grammar implies, which is a cheap cross-check on what the handoff declared.

**Never clean it yourself.** No `git stash`, no `git reset`, no `git checkout --`.
Whatever is in that worktree may be the only copy of it, and deciding its fate is
the orchestrator's call, not yours. Report the dirt; do not sweep it.

### Gate 4 — no blocking ambiguity in the spec

The bar, exactly: *"can a competent implementer pick a unique correct
implementation from this spec alone?"*

- **Yes** → not a gap, even if you would personally have specified it differently.
- **No** → a gap, phrased as a concrete question someone can answer in a sentence.

This is a **shallow** scan for blockers, not a spec review. Literal markers help
as a first pass (`TBD`, `decide later`, `unclear`, `or similar`, a bare `?` left
as the entire resolution of a decision point — not every prose question mark),
but the real signal is structural: an AC referencing a name the spec never
defines, a threshold with no value, a comparison with no baseline.

Each gap entry carries three fields, and all three are load-bearing:

- `section` — where it lives: `"spec §3 — decisions"`, `"AC-2"`,
  `"pre-flight — worktree state"`.
- `question` — a concrete answerable sentence. *"Should a duplicate heading get a
  numeric suffix, or should the run exit nonzero?"* — **not** *"AC-2 unclear"*,
  which tells the reader only that you stopped.
- `severity` — `blocking` (no implementation possible until it is answered) or
  `nice-to-have` (a defensible default exists; the answer would improve the
  result, not unblock it).

A `nice-to-have`-only pre-flight does **not** stop the run. Proceed, take the
defensible default, and record both the default and the reasoning in the report.

---

## 2. The four gap archetypes

| Archetype | Looks like | The question to ask |
|---|---|---|
| **Undefined contract** | An AC names a function, flag, format or error type the spec never defines | *"What exactly does `<name>` return on an empty input — an empty list, or an error?"* |
| **Conflicting dependency** | Two sections require incompatible things; or the spec assumes a sibling work item that this round has not merged | *"Section 4 pins the reader to streaming, AC-3 expects the whole document in memory — which wins?"* |
| **Stale worktree** | Gate 3's dirty / wrong-branch / missing outcomes | *"The worktree has uncommitted changes to `<path>` — should they be kept, or should the worktree be respawned?"* |
| **Missing referenced file** | The spec cites a path, fixture, or ADR that does not exist | *"The spec cites `<path>` as the fixture — it is not in the worktree; where should it come from?"* |

The first two are spec gaps and the orchestrator resolves them with the user. The
last two are environment gaps and the orchestrator usually resolves them alone.
Both go through the same return shape.

---

## 3. What a clean pre-flight looks like

Nothing. **A clean pre-flight emits no "pre-flight passed" message** — no summary
of what you read, no checklist rendered back at the caller. You simply continue
into the RED gate.

The announcement is worse than noise. In Mode B it lands in the orchestrator's
transcript as a status update it did not ask for and cannot act on; in Mode A it
trains the user to skim your output. The evidence that pre-flight ran is the
tool-call log — two Reads, the `oss verify_acs` parse with its row-shape check,
and two `git -C` probes, in order.

---

## 4. Deliberately not checked: blocker recall

In an ossify-only repo, **every gap you surface is a fresh gap.** Ossify seeds
the memory bank's `tech-debt.md` empty and ships no writer for it
(`start/references/memory-bank-brief.md`), so reading it cannot distinguish "no
known deferrals" from "index nothing writes" — and reporting "checked known
issues, none found" off an empty index is a confident false negative. If the
orchestrator already knows about a gap, it says so on the re-dispatch. **Where
another stack maintains the index** — it exists and carries `[TD]` entries —
read it and surface an already-tracked deferral as *known*, not fresh.
