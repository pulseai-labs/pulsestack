# Changelog

All notable changes to the sage plugin (named ai-mentor through 2.5.0) are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

## [2.6.1]

### Fixed

- The recommendation policy's TOP SEVERITY example reads "a restart-class recommendation at orchestrate
  gates": a restart option merely on the menu does not escalate a gate (#111). Both copies, in `grill-me`
  and `council`, follow the source of truth.
- The README no longer links to `docs/SPEC-ai-mentor-v2.md` and `docs/PLAN-ai-mentor-v2.md`, which do not
  ship with the plugin (#146). Older entries below keep their citations as written.

## [2.6.0]

### Changed

- Renamed from `ai-mentor` to `sage`, in the marketplace's rename to `pulsestack`. The commands are
  now `/sage:grill-me`, `/sage:council`, `/sage:eli10` and `/sage:fool`, and the install key is
  `sage@pulsestack`. Behaviour is unchanged. To move: uninstall `ai-mentor@claude-agent-scaffolding`,
  then install `sage@pulsestack` (the root README's *Renamed from claude-agent-scaffolding* section
  has every step).

## [2.5.0] — 2026-10-11

### Changed
- OMP marketplace surface. Wrappers name the skill by `skill://` path as well as `${CLAUDE_PLUGIN_ROOT}`; skill descriptions lead with the trigger ("Use when ...") so OMP's skill match fires; Claude Code tool names carry an OMP alias where a skill names one; the README gains an OMP note. No Claude Code-only parts.

## [2.4.0] — 2026-07-10

### Added
- **`grill-me` disposition triage (pulse360#15).** SoT-answerable, predicate-clean questions are self-answered into a "Self-answered (delegated)" exit-summary section with a ⚡ Auto-applied digest; dependent chains + escalated questions stay one-question-per-turn; new `--walk` opt-out; recommendation-policy copy updated (triage + standing-delegation Rule 5).

## [2.3.0] — 2026-07-02

### Added
- **`grill-me` Rule 5 — "code contradicts the claim → resolve by mode" (#37 leg 2).** When exploring (Rule 4) surfaces a discoverable fact that contradicts the user's stated premise, grill-me now surfaces the contradiction directly rather than accepting the premise, then names the authoritative source *by mode*: in development/implementation the **code** wins (contradicting docs are flagged stale); in vision-aligned planning the **vision/spec** wins (contradicting code is flagged as drift). Ambiguous mode → ask which frame applies first. Legs 1/4/5 of #37 were declined (wontfix); leg 3 lands in scaffold-dev.

## [2.2.0] — 2026-06-30

### Changed
- **Recommend-by-default decision policy (#93).** `grill-me` and `council` now attach a firm, vision-grounded **recommendation** to every surfaced decision by default, so the user can **accept / rebut / defer** with guidance rather than adjudicate cold. `grill-me` Rule #3 flips from "recommend only when asked" to a one-line *cited* lean per question; `council` proposes a **Chairman synthesis** by default (the five voices still come first, in full) instead of always handing synthesis to the user. Grounding reuses ai-mentor's existing orientation-derivation chain (issue/PR → memory-bank → handoffs), falling back to labelled general best-practice — **no manifest dependency is added** (ai-mentor stays orthogonal). `--neutral` (or "no recommendations") suppresses recommendations per invocation and restores the prior neutral behavior. The shared policy is the marketplace convention `docs/conventions/recommendation-policy.md`, shipped as a byte-identical copy at `references/recommendation-policy.md` and guarded by the repo-root parity test `tests/test-recommendation-policy-parity.sh`. Pairs with architect-critic v0.5.0 and scaffold-dev v0.15.0, which adopt the same convention.

## [2.1.0] — 2026-06-25

### Added
- **Orientation preamble for `grill-me` and `council` (#88).** Both skills now open with a compact, agent-produced **"📍 You are here"** block — Topic / Where-it-sits + strategic weight / Why — so a resumed or context-switched session is globally anchored, not just locally coherent. Derived from available context (a referenced issue/PR, the memory-bank `00-project-brief`/MASTER-SPEC §/SPEC ledger, recent handoffs); if context is thin the agent asks for a one-line reminder rather than fabricating. Re-surfaceable on demand ("where am I?"). Skill-first and fully agent-driven — no deterministic helper, no templating, no hook. Pairs with architect-critic v0.4.0 (adopts the convention in `critiquing-spec`) and scaffold-onboard v0.11.0 (seeds it into derived projects).

## [2.0.0] — 2026-05-24

**Breaking change.** Scope-cut release: ai-mentor now ships only the surfaces the user actually invokes. See `docs/SPEC-ai-mentor-v2.md` for design rationale and `docs/PLAN-ai-mentor-v2.md` for the 8-phase implementation breakdown.

### Removed (Phase 0)
- `commands/z1.md`, `commands/z2-decide.md`, `commands/z2-build.md`, `commands/locked.md` — zone enforcement surfaces (unused).
- `commands/quiz.md` — Socratic quiz protocol (unused).
- `commands/improve.md` — prompt rewriter (unused).
- `hooks/` and `hooks-handlers/` directories — `PreToolUse` + `SessionStart` hooks (zone enforcement + 620-token per-session injection). Without zones, both are dead weight.
- `lib/state.sh` and `~/.claude/ai-mentor/state.json` — zone/submode/quiz_level persistence (no surviving consumer).
- `skills/ai-mentor/SKILL.md` — 171-line zone reference (~80% obsolete; surviving framing moves to README in Phase 6).
- `tests/test-hooks.sh` — 28 regression tests for state + hooks (both gone).

### Added (Phase 1 — RED test scaffolding)
- `tests/test-frontmatter-lint.sh` — bash automation for the v2.0 frontmatter contract (`name`+`description` only, ≤1024 chars, no `version`, no `when_to_use`, `name` kebab-case). POSIX-friendly (bash 3.2+, awk only — no jq/yq).
- `tests/test-skill-triggers.md` — 18 markdown fixtures for skill auto-invocation (grill-me / eli10 / fool / council, including negative tests like "let's grill chicken").
- `tests/test-grill-escape-valves.md` — 4 stuck-state fixtures (tangled / paralyzed / tactical-framing / no-timescale) for grill-me's cognitive-discipline escape valves.
- `tests/test-council-personas.md` — 10 fixtures for The Council output (5-persona structure + in-character markers + Historian greenfield vs priors-rich context modes).
- Rewrote `tests/README.md` documenting the hybrid test approach: bash automates the cheap structural checks; markdown checklists capture LLM-behavior fixtures honestly. `claude --print` automation noted as future work post-v2.0.

### Testing approach (v2.0)
v1.3 was pure-bash (state.sh + hook handlers); v2.0 is pure-skill-markdown with no bash code at all. The test surface changes fundamentally — most of the contract lives in LLM behavior, which bash can't natively dispatch. Picked **hybrid Option C**: bash automates the deterministic checks (~80% of the v2.0 contract is actually structural), markdown checklists capture the LLM-behavior fixtures without overclaiming automation.

### Added (Phase 2 — grill-me refinement)
- `skills/grill-me/SKILL.md` — CORE protocol posture made explicit (Curiosity → Objectivity → Reassurance → Empathy; from `.claude/ghost-notes.md` principle #3). 4 cognitive-discipline escape valves folded in: separating-concerns, widening-confidence-interval, asking-identity-question, widening-time-horizon. Each fires once when a stuck-state cue appears mid-grill, then resumes grilling.
- `skills/grill-me/escape-valves.md` — sibling reference doc with diagnostic cues, reframes, and example responses per escape valve.

### Changed (Phase 2)
- `skills/grill-me/SKILL.md` frontmatter cleaned to v2.0 contract (name + description only; 867/1024 chars; no `version`, no `when_to_use`). v1.3 references to deleted `/quiz` and `/z2-decide` removed.
- `test-frontmatter-lint.sh` goes from 6/9 (Phase 1 RED) to 9/9 GREEN.

### Added (Phase 3 — eli10 + fool promoted to skills)
- `skills/eli10/SKILL.md` — re-explanation skill at descending levels (ELI10 → ELI5 → ELI3). Re-invokable via `Want me to make it simpler?` prompt. Description 621/1024 chars.
- `skills/fool/SKILL.md` — sticky beginner's-mind mode for the conversation. Distinguishes from eli10 (eli10 = retroactive single-answer simplification; fool = prospective conversation-wide baseline). Description 639/1024 chars.
- Both skills include defensive negative-fixture clauses (eli10 NOT for first-pass explanations or code walkthroughs; fool NOT for "rewrite from scratch" code intent) to prevent over-firing on ambiguous triggers.

### Test status after Phase 3
- `test-frontmatter-lint.sh` — GREEN 27/27 across 3 skills (grill-me + eli10 + fool).

### Added (Phase 4 — The Council, NEW skill)
- `skills/council/SKILL.md` — 5-persona multi-angle idea validation (Karpathy LLM Council pattern, codebase-aware Historian variant replacing canonical Expansionist). One-shot 5-voices format vs grill-me's interactive 1-question-at-a-time. Description 858/1024 chars.
- `skills/council/personas.md` — full persona briefs (voice, hunt, opening moves, verbal tics) for The Contrarian, The First Principles Thinker, The Outsider, The Executor, The Historian (~1138 words).
- The Historian persona runs `git log` + `git log -S '<pattern>'` + Glob before composing its take. Quotes specific commits/files when priors exist; degrades gracefully on greenfield with literal "no priors found in this codebase" phrasing + pivot to "what's making you reach for THIS pattern over standard alternatives".
- Chairman synthesis prompt at the end of every Council invocation (`**Chairman, your synthesis?**`) — user either writes their own verdict or asks Claude to propose one. No pre-synthesis, no peer-review (peer-review deferred to a future version per SPEC §10).

### Test status after Phase 4
- `test-frontmatter-lint.sh` — GREEN 36/36 across 4 skills (grill-me + eli10 + fool + council).
- All structural fixtures in `test-council-personas.md` + `test-skill-triggers.md` (council section) should pass once Phase 5 slash wrappers land; manual fixture walks scheduled for Phase 7.

### Added (Phase 5 — slash command wrappers)
- `commands/grill-me.md` (NEW) — thin `$ARGUMENTS` wrapper invoking the grill-me skill. Argument-hint: `[plan or design to grill]`.
- `commands/council.md` (NEW) — thin `$ARGUMENTS` wrapper invoking the council skill. Argument-hint: `[idea or decision to validate]`.

### Changed (Phase 5)
- `commands/eli10.md` — rewritten as thin `$ARGUMENTS` wrapper over the eli10 skill (v1.3 had full behavior inline; v2.0 delegates to skill body).
- `commands/fool.md` — rewritten as thin `$ARGUMENTS` wrapper over the fool skill (v1.3 had full behavior inline; v2.0 delegates to skill body).

All 4 wrappers use `$ARGUMENTS` env-var bridge (not `$1`/`$2` positional) per the slash-command template-render fix. Each wrapper is ≤10 lines of body content.

### Changed (Phase 6 — metadata + docs rewrite)
- `plugin.json` version bumped to 2.0.0; description rewritten to reflect v2.0 surfaces.
- `README.md` (plugin) — full rewrite. New 4-surface table, "what's inside each skill" briefs, install/migration guidance for v1.x users, hybrid-test approach, composition notes.
- `.claude-plugin/marketplace.json` — ai-mentor entry description updated to v2.0.
- Root `README.md` — ai-mentor plugin table row to v2.0.0; "Quick start with ai-mentor" rewritten for natural-language + slash invocation; "compose without overlap" line reframed (was "enforces cognitive mode" → now "decision-making mentor surfaces"); layout section bumped.

### Verified (Phase 7 — automated checks)
- `bash ai-mentor/tests/test-frontmatter-lint.sh` — GREEN 36/36 (4 skills × 9 checks).
- Plugin layout matches SPEC §3 (4 skills, 4 commands, 4 test files, README + CHANGELOG + LICENSE + plugin.json).
- No residual functional references to deleted surfaces in `skills/` or `commands/` (Historian persona examples in `council/SKILL.md` + `council/personas.md` quote `PreToolUse` as historical context — intentional, not active feature usage).
- Manual smoke per SPEC §9 DoD: deferred to user, run from a fresh Claude Code session post-tag.

### Housekeeping (Phase 7)
- Added deprecation banner to `docs/SPEC-ai-mentor.md` (v1.3 SPEC, superseded by `docs/SPEC-ai-mentor-v2.md`).
- Added supersession banner to `docs/HANDOFF-ai-mentor-v14-spec.md` (v1.4 plan reshaped into v2.0 via Phase A grill-me session).
- Updated project memory: `project_thinking_discipline_content.md` reflects v2.0 reality (cognitive-discipline content folded into grill-me, not standalone skills).
- Updated project memory: `project_skill_first_retrofit_queue.md` marks ai-mentor done (shipped as v2.0 scope-cut, not skill-first retrofit); 3 plugins remain on queue.
- New project memory: `project_ai_mentor_v2_grill_settlements.md` captures the 11 grill-session decisions for future-session continuity.

### Smoke tested (Phase 7, post-release)
Six of eight DoD scenarios actively validated in a Claude Code session against the installed v2.0.0:
- **#2** eli10 auto-invoked on "explain this simpler" without slash command; produced ELI10-level helper-friends analogy.
- **#4** council fired on "council me on..."; produced 5 markdown-headed sections in exact order with distinguishable in-character voices.
- **#8** Historian quoted real commit SHAs (`2ccbc7d`, `b0a9bc9`) from this repo's git history; codebase-grounding behavior confirmed.
- **#1** grill-me activated on "grill me on..."; CORE-flavored posture (curious, not adversarial); ONE question per turn rule held.
- **#5** separating-concerns escape valve fired correctly on a tangled answer ("can't answer cleanly because every piece touches every other"); pause + split + name-the-5-concerns reframe produced; grilling resumed on the root concern.
- **#6** widening-confidence-interval escape valve fired correctly on a paralysis-flavored answer ("need to be 100% sure"); 60/40 framing + interval-widening reframe produced; reversibility pressure-test added.
- **#3** fool + **#7** slash command paths: not actively triggered; acceptable to ship (fool follows same auto-invocation pattern as eli10 which passed; slash commands are zero-logic thin wrappers).

Future-monitoring concerns (not blockers): escape-valve false-positive rate under organic conversation; Historian greenfield path (only priors-rich tested this round); council ↔ grill-me composition feel when run together (worked for testing; flag if production use feels conflicted).

### Migration from 1.x
- `~/.claude/ai-mentor/state.json` is no longer used. Safe to delete manually.
- Slash commands `/z1`, `/z2-decide`, `/z2-build`, `/locked`, `/quiz`, `/improve` will return "command not found". Intentional.

## [1.3.0] — 2026-05-03

### Added
- New `/improve` slash command: rewrites an unstructured natural-language draft into a clean coding-agent prompt (specific files, expected behavior, constraints, definition of done). Always shows the rewrite for explicit user confirmation before Claude acts on it.
- **Pass-through marker** (`<!-- already well-formed; no changes -->`) when the draft is already well-structured (named files + expected behavior + constraints + definition of done), so the command doesn't damage prompts that don't need rewriting.
- **Inventing-flag rule** — if the rewriter fills in details the user didn't mention (file paths, constraints), it must explicitly flag those for review rather than silently presenting them as ground truth.

### Architecture notes
- The rewrite happens **in the current Claude session**, not via an external `claude --print` subprocess. We tried the subprocess approach first; it had two real problems: (a) `--bare` (which would isolate the call cleanly) requires `ANTHROPIC_API_KEY` and skips OAuth/keychain auth, and (b) without `--bare`, the rewriter call inherits the user's installed skills (e.g., superpowers' `systematic-debugging`) and ignores our system prompt. The in-context approach avoids both problems and adds zero latency from process spawning.
- Trade-off: rewrite uses the active session's model (Sonnet/Opus typically) instead of cheaper Haiku. Acceptable because the rewrite is small (~500–1500 input + 200–600 output tokens) and `/improve` is opt-in (used when a draft is genuinely worth thinking about).
- No separate `ANTHROPIC_API_KEY` required. No subprocess. No subscription complications.

## [1.2.0] — 2026-04-30

### Added
- New sibling skill: `skills/grill-me/SKILL.md`. Activates on phrases like "grill me", "stress-test this", "challenge my design", "poke holes", "what am I missing". Asks one question per turn, walks the design tree across seven categories (requirements, assumptions, edge cases, trade-offs, operability, composition, reversibility), exits cleanly on user signal or convergence, summarizes locked decisions / open issues / assumptions to re-check.
- The skill is plan-and-design-shaped Socratic — distinct from `/quiz` (which tests known material at depth) and from the main `ai-mentor` skill (which manages cognitive mode). Composition documented in the skill body.

### Changed
- ai-mentor's main `SKILL.md` gets a one-line "See also" pointer to the new `grill-me` skill.

## [1.1.1] — 2026-04-27

### Added
- `ai-mentor/tests/test-hooks.sh` — 28-test regression suite (state helpers, PreToolUse hook, SessionStart source-awareness). Run with `bash ai-mentor/tests/test-hooks.sh`. Closes spec open question B4.

### Documentation
- README "Platforms" section: declared Linux/macOS only. Closes spec open question B3.
- `ai-mentor/tests/README.md`: how to run the regression suite, dependencies, when to run.

## [1.1.0] — 2026-04-26

### Changed
- **State path migrated to `${CLAUDE_PLUGIN_DATA}/state.json`** (canonical plugin-data location per Claude Code docs). Falls back to `~/.claude/ai-mentor/state.json` when the env var isn't set (e.g., shell-level testing). Survives plugin updates cleanly.
- **SessionStart hook now respects the `source` field**: state resets only on `startup` and `clear`; preserved through `resume` and `compact`. Closes a silent failure mode where context compaction would erase your active zone, leaving the spotter dead until you noticed.
- **Skill frontmatter split into `description` + `when_to_use`** for better trigger reliability against the documented ~1,536-char budget. Trigger phrase list expanded.

### Added
- Subagent scope documentation in SKILL.md and README.md. Zone enforcement applies to the main session's tool calls, not to subagent-mediated edits — this is by design (subagent isolation). The main agent's protocol discourages spawning implementation subagents in `zone=2`.
- `CHANGELOG.md` (this file).

### Fixed
- *(none — no behavioral bugs reported)*

### Notes
- Existing users on v1.0.0 with state at `~/.claude/ai-mentor/state.json` will silently migrate: on next session start, the state file at the new path is created with `ambient` defaults; the old file becomes orphaned and can be deleted manually if desired.

## [1.0.0] — 2026-04-26

### Added
- Initial release. Pillars 3 (Gym/spotter) + 4 (Fool/beginner's mind) of the 4-pillar cognitive-partner framework. Pillars 1 (DRAG) and 2 (Hill) deferred to v1.2+.
- `SessionStart` hook injecting always-on protocol context (~620 tokens).
- `PreToolUse` hook on `Edit|Write|NotebookEdit` — hard-blocks with override grammar; fail-open on any error.
- Two Curve-2 sub-modes: **`decide`** (block until `/locked`; AI is spotter on architectural thinking) and **`build`** (block unless inline override phrase; AI gives progressive L1–L4 hints).
- Slash commands: `/z1`, `/z2-decide`, `/z2-build`, `/locked` (alias `/implement`), `/quiz`, `/eli10`, `/fool`.
- Detailed `SKILL.md` with zone classification examples, hint level table, quiz protocol, beginner's-mind rules.
- State at `~/.claude/ai-mentor/state.json` (later moved in v1.1).
