# Eval Runbook (ossify planning judges)

Executed by Claude Code in an interactive session. No API runner.

## Procedure (Claude executes)

For each `surface` in `[posture-derivation, spike-contract-integrity, risk-gate-registration, start-topology-authoring, start-occupied-destination, start-content-gate, start-reviewer-home, adopt-plain-repo, adopt-reviewer-home, adopt-multi-repo, adopt-completion-floor, journey-line-floor, spine-class-declaration, release-ladder-labels, bone-touch-check, critic-veto-interpretation, run-spine-declared-repo, close-gate-integrity, close-per-repo, harvest-apply-integrity, rule-authoring-integrity, doctor-declared-repos, doctor-provenance, doctor-instruction-file, boundary-audit-integrity, handoff-compose, handoff-resume, work-pr-disposition, external-executor, patch-routing, intake-at-planning, spine-freeze, ledger-read, glue-as-fake]`:

  For each `fixture.md` in `tests/eval/fixtures/<surface>/`:

  1. **Apply the judgment.** Dispatch `Agent` (general-purpose): "Read the owning skill's SKILL.md + the relevant `references/*.md` for `<surface>` end-to-end. Apply ONLY that skill's documented decision procedure to this fixture scenario (paste body). Output the judgment the skill would produce (e.g. the derived posture+channel, the accept/reject verdict + reason, the declared class, the veto disposition, or — for `close-gate-integrity` — what the ceremony does next and what it records). Do not improvise beyond the skill body." Capture the output.

  **Two 1.13.0 surfaces span several skills** — point the invoke agent at every
  file the README's Surfaces table names for them. `spine-freeze` reads
  `plan-spine/SKILL.md`, `plan-spine/references/intake-and-ledger.md` and
  `work-item/references/round-orchestration.md`; `ledger-read` reads
  `plan-spine/SKILL.md`, `plan-spine/references/intake-and-ledger.md` and
  `patch/SKILL.md`.

  **Paste the fixture BODY ONLY — strip the frontmatter.** The frontmatter is the answer key. The judge in step 2 sees the whole fixture; the invoke agent must not. And **whoever authored a surface's fixtures has read its keys and cannot serve as its invoke agent** — dispatch fresh agents for both steps.

  2. **Score.** Dispatch a fresh judge `Agent`: "You are an LLM-as-judge. Score the SKILL OUTPUT against the RUBRIC. Return one JSON object in exactly the shape the RUBRIC's last line pins — that line is the authority on the `notes` contract, which differs per surface. Pass = all criteria ≥4. JSON only. RUBRIC: <paste rubrics/<surface>.md>  FIXTURE: <paste fixture>  SKILL OUTPUT: <paste>." Write the JSON to `tests/eval/results/<surface>/<fixture_id>.json`.

After all surfaces: run `bash ossify/tests/eval/lib/aggregate-scores.sh` and report the summary.

## Cost

Every fixture costs two dispatches — one invoke, one judge — so a full run is twice the fixture count. Count the fixtures with `find ossify/tests/eval/fixtures -name '*.md' | wc -l` from the repository root rather than reading a total here; one written down drifts from the tree that owns it.

**The invokes are the pacing constraint**, at roughly 4-8 minutes each, and run in batches of no more than three; judges are light (roughly 35-90 seconds) and can overlap. A full run is hours, not minutes. Re-run a single surface by deleting its `results/<surface>/*.json` and re-running.

`aggregate-scores.sh` walks `fixtures/` and **fails on any fixture with no result
JSON**, so a partial run cannot report a clean total. It also fails on **STALE**
results when the fixture or surface rubric changed (content at the result's last
commit for unchanged committed results; mtimes for fresh uncommitted results).
Rerun the invoke and judge against the current inputs; touching a result is not
a rerun. Skill-file changes are outside this mechanical freshness check and
still owe the relevant eval reruns. See `README.md` for the full gate contract.
