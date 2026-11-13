# Eval Runbook (crew judgment surfaces)

Executed by Claude Code in an interactive session. No API runner. The harness
conventions here are ossify's — `ossify/tests/eval/README.md` and
`ossify/tests/eval/RUNBOOK.md` are the originals and stay the authority on the
shared parts; this file states what a reader needs to run **this** plugin's
surfaces and does not restate the reasoning behind the conventions.

**Working directory: the repository root**, the same place ossify's RUNBOOK is run
from. Every runnable command below is written repo-root-prefixed
(`bash crew/tests/eval/...`) so it can be pasted as-is; every bare
`tests/eval/...` path is relative to `crew/`, exactly as ossify's bare paths are
relative to `ossify/`. There is no `cd` step — introducing one here would diverge from
the file this harness copies.

## Surfaces → owning prose

| Surface | Owning prose | The judgment |
|---|---|---|
| `ossify-spine-execution` | `skills/orchestrate/SKILL.md` + `references/layers/herdr.md` + `references/ossify-execution.md` + `references/ossify-nested-run.md` + `references/ossify-briefs.md` + `references/ossify-pr-briefs.md` + `references/ossify-close-writer.md` + `references/roles.md` + `references/lifecycle.md` + `references/completion.md` | the three-layer spine execution phase: four-fact activation and who owns which layer (the top agrees the seats with the operator, records them in the project file and starts exactly one spine session, launching no item pane itself; the spine session creates a `run.json` of its own and owns both item panes per item); run routing that keeps item plan traffic and per-item completions in the spine session's own `run.json` while the top sees a relayed plan decision, spine-level questions and one final report — every one of them written by the reporting seat into its own report file, because herdr has no worker-to-orchestrator channel that carries them, and a seat that runs waits of its own (a spine session, a work-PR session) is waited on through that same file, never the typed wait, whose `done` and `idle` both mean only that a turn ended; profiles bound by the injected SEATS block — the freeze a running spine never looks past — with the model confirmed only by the launcher from the banner or screen and no unlisted dispatch-time substitution, and a missing or ambiguous row halting, except a carried conditional fallback switches on its observed condition with the same launch read and a report; pairs fresh per item, retained only through that item's corrections, never crossing items, with generic retention unchanged outside an activated spine; teardown that releases a tab seat by closing its pane and a worktree seat by removing its worktree, reads every receipt and confirms with `herdr workspace list`, never assuming; and the two no-fallback rules — nested depth `2` with a spine session that cannot launch an item session halting rather than degrading to an inherited-runtime subagent, the top's `run.json`, a replacement writer or a lane restart, and the reviewer chosen only at the PR transition |

## Procedure (Claude executes)

For each `fixture.md` in `tests/eval/fixtures/<surface>/`:

1. **Apply the judgment.** Dispatch a fresh `Agent` (general-purpose): "Read the
   owning prose for `<surface>` end to end and treat it as the only authority.
   Apply ONLY the decision procedure those documents describe to this scenario
   (paste body). Output the judgment the skill would produce. Do not improvise
   beyond the documents." Capture the output.

   **Paste the fixture BODY ONLY — strip the frontmatter.** The frontmatter is
   the answer key. The judge in step 2 sees the whole fixture; the invoke agent
   must not. And **whoever authored a surface's fixtures has read its keys and
   cannot serve as its invoke agent** — dispatch fresh agents for both steps.
   Tell the invoke agent not to read anything under `tests/eval/`.

2. **Score.** Dispatch a fresh judge `Agent`: "You are an LLM-as-judge. Read the
   owning prose for `<surface>` end to end — the same ten files the invoke
   agent read — then the RUBRIC, the complete FIXTURE (frontmatter included),
   and this pair's own SKILL OUTPUT. The fixture body supplies scenario facts
   only; every material decision rule the output applies must come from the
   supplied source prose, and matching the answer key is not evidence that it
   did. Score the output against the rubric, including its source-fidelity
   floor. Return one JSON object in exactly the shape the RUBRIC's last line
   pins — that line is the authority on the `notes` and `source_support`
   contract. Pass = all criteria ≥4 and a `supported` source verdict. JSON
   only. SOURCE: <the ten owning-prose paths the invoke read>  RUBRIC:
   <paste rubrics/<surface>.md>  FIXTURE: <paste fixture>  SKILL OUTPUT:
   <paste>."
   Write the JSON to `tests/eval/results/<surface>/<fixture_id>.json`.

After all surfaces: run `bash crew/tests/eval/lib/aggregate-scores.sh` and
report the summary.

**Results predating a contract change are deleted, not reused.** When the owning
prose's contract changes — a rule added, removed, or rewritten — every JSON
under `results/<surface>/` written against the old contract is stale: it scores
the invoke against authority that no longer exists. Delete the whole directory's
JSON for the affected surface before the next run; do not carry results forward
and do not keep them for comparison. The same applies to fixture files the
change retires and to any control records under `evidence/` built on the old
contract.

Retired with no successor: `11-v1-sidecar-requires-re-ratification-halts`
guarded a sidecar-ratification seam — a state directory holding a contract blob
id that every governed launch had to prove before it was launch authority. That
whole seam is absent from this plugin: seats come from the operator's own files,
and no `lib/`, state directory or parser ships. There is nothing left for a
fixture to guard, so the gap between 10 and 12 is deliberate, not lost coverage.

## Fixture format

`fixtures/<surface>/NN-description.md` with YAML frontmatter carrying
`scenario_id`, `expected_outcome` (vocabulary pinned by the rubric) and
`expected_reason` (the answer key, including the specific wrong answer the
fixture falsifies), then a body describing the scenario. Each surface includes
at least one negative-control fixture whose expected answer is the safe or clean
one.

**A fixture body must declare every input its rubric scores, and the rubric is
the authority on which those are.** An input the body leaves unstated does not
make the fixture lenient; it makes the criterion measure the invoke agent's
guess. State inputs as facts about the scenario, never as a check's outcome.

## Rubric format

`rubrics/<surface>.md` lists that surface's criteria; the judge scores each 1-5;
**pass = ≥4 on every criterion and a `supported` source verdict**; the rubric's
last line pins the JSON output contract including the `notes` and
`source_support` contract. `lib/aggregate-scores.sh` reads only
`.pass`/`.notes` and validates neither, so that line is the whole contract.

**An unexercised criterion caps at 4** — consistent with the contract, not
demonstrated by the scenario. A 5 requires the fixture to have exercised it.

## Evidence scope

This interactive harness samples how fresh isolated agents apply the current
owning prose. Its model outputs are advisory diagnostics, not comparative or
release-gate evidence on their own.

A seat launched through herdr receives no injected lifecycle preamble: herdr
prepends nothing to a brief — it submits the text and Enter as one submission —
and what it adds to a seat is environment such as `HERDR_PANE_ID`, never prompt
text, so the brief is the whole contract. That confound is genuinely gone.

Three live channels remain, and they are why replacing only the source files
with a pre-change snapshot still does not isolate the product version:

- **the guide the seat reads.** The spine-session and work-PR briefs (`ossify-briefs.md`,
  `ossify-pr-briefs.md`) each point the seat at herdr's own skill guide, and that guide belongs
  to the installed binary, not the snapshot. It states dispatch and
  authority rules of its own, and this plugin deliberately overrides some of them:
  the guide starts an agent as a sibling pane in the current tab, where
  `layers/herdr.md` places each seat in its own tab; the guide says not to
  repeat the settled-state defaults with `--until`, where the typed wait writes
  them out; and it tells a seat to ask the user before answering a blocked UI,
  which `layers/herdr.md` adopts as its own. A seat reading it gets the live
  rules whatever the snapshot says.
- **the mechanics the seat is pointed at.** `MECHANICS=` names the installed
  orchestrate skill's `references/layers/herdr.md`, not a substituted copy, so
  the seat-launch, readiness, wait, send and teardown mechanics a seat reads come
  from the live file.
- **the installed plugin's hook.** No seat runs this plugin's own slash commands, so that
  command surface is not a channel. What does reach a seat from the installation rather
  than from the snapshot is the `context-ceiling` hook's `additionalContext` notice —
  the notice the ROTATE rule in `ossify-briefs.md` depends on.

Do not treat such a prompt-substituted run as old-contract discrimination or a
causal old/new comparison, even when its judge reads the same snapshot. A
comparative claim requires actual versioned execution under otherwise equal
runtime conditions. This runbook does not define that experiment.

## Cost

Two dispatches per fixture, one invoke and one judge. Invokes are the pacing
constraint and run in batches of no more than three; judges are light and can
overlap. Count the fixtures with
`find crew/tests/eval/fixtures -name '*.md' | wc -l` rather than reading a
total here. Re-run a single surface by deleting its `results/<surface>/*.json`
and re-running.

`aggregate-scores.sh` walks `fixtures/` and **fails on any fixture with no
result JSON**, so a partial run cannot report a clean total.

## Not run by CI

`crew/run-tests.sh` globs `tests/test-*.sh` and so runs none of this — the
eval harness is session-driven by design and is a gate someone walks by hand.
