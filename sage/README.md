# sage

> Decision-making mentor for project work. The user owns the decisions; sage provides the prompts, simplifications, interrogations, and perspectives that make decisions sharper. AI never decides for the user; AI helps the user decide.

**v2.0.0** is a scope-cut release. v1.x shipped a 4-pillar cognitive-partner framework with mechanical edit-blocking hooks, a quiz protocol, prompt rewriting, and ~620 tokens of per-session protocol injection. In ~12 months of v1.x use, only one surface (`grill-me`) actually earned its keep. v2.0 deletes everything that didn't, sharpens `grill-me` with cognitive-discipline content, promotes the two simpler surfaces that still see use, and adds one new surface (`council`) for multi-angle idea validation.

The sections below describe what ships; the v2 design spec and plan were working documents of this repository and are not part of the plugin.

## The four surfaces

| Skill | Shape | When it fires |
|---|---|---|
| **`grill-me`** | Interactive, one question at a time, walks the decision tree | "grill me on this plan", "pressure-test this", "challenge my design", "poke holes", "what am I missing" |
| **`council`** | One-shot, 5 advisor personas in a single response, Chairman-synthesis at end | "council me on this", "is this a good idea?", "validate this from multiple angles", "should I do X?" |
| **`eli10`** | Re-explain the current topic simpler (ELI10 → ELI5 → ELI3) | "explain in simpler terms", "I don't get it", "make it simpler", "too complex" |
| **`fool`** | Sticky beginner's-mind mode for the whole conversation | "consider me a beginner", "no jargon", "beginner's mind", "explain like I'm new to this" |

All four auto-invoke on natural-language triggers — no slash command required. Slash commands (`/grill-me`, `/council`, `/eli10`, `/fool`) exist as explicit handles for the moments you want to be unambiguous.

## What's inside each skill

**`grill-me`** — Senior-peer interrogation with **CORE posture** (Curiosity → Objectivity → Reassurance → Empathy). One question per turn, surface don't lecture, recommend only when asked, explore before asking. Walks 7 categories: requirements & users, assumptions, edge cases & failure modes, trade-offs, operability, composition, reversibility. Detects stuck-state mid-grill and applies one of 4 **escape valves** (`separating-concerns`, `widening-confidence-interval`, `asking-identity-question`, `widening-time-horizon`) before resuming. Exits with a "Locked / Open / Worth re-checking" summary.

**`council`** — Karpathy's LLM Council pattern, with one variant: the canonical "Expansionist" persona is replaced by **The Historian**, a codebase-aware seat that greps your git history and quotes specific commits/files. The five personas (in fixed order: Contrarian, First Principles Thinker, Outsider, Executor, Historian) each give a 2-3 paragraph in-character take on your idea, then prompt you (as Chairman) for synthesis.

**`eli10`** — Re-explanation, not first-explanation. Assumes there's a current topic on the table. Each re-invocation drops a level: ELI10 (concrete analogies, short sentences) → ELI5 (story shape, no abstractions) → ELI3 (everyday objects only, two sentences max). Ends with `Want me to make it simpler?` so you can re-invoke without remembering the slash command.

**`fool`** — Sticky mode lasting the whole conversation. No assumed background, surface vocabulary as introduced, welcome obvious questions, model the same beginner's mind yourself. Distinct from `eli10`: `eli10` is retroactive single-answer simplification; `fool` is prospective conversation-wide baseline.

## Install

```
/plugin marketplace add github:pulseai-labs/pulsestack
/plugin install sage@pulsestack
```

For local development:

```
/plugin marketplace add /path/to/pulsestack
/plugin install sage@pulsestack
```

## Migrating from v1.x

v2.0 is a breaking change. If you were on v1.x:

- **Removed surfaces**: `/z1`, `/z2-decide`, `/z2-build`, `/locked` (zone enforcement); `/quiz` (Socratic quiz); `/improve` (prompt rewriter). Hooks (`PreToolUse`, `SessionStart`) and state file (`state.json`) are gone with them. Slash commands return "command not found" — intentional.
- **No data migration needed**. `~/.claude/ai-mentor/state.json` is no longer used; safe to delete manually.
- **What survives**: `grill-me` (refined), `eli10` (promoted to skill, slash kept), `fool` (promoted to skill, slash kept). All three behave as before, with `eli10` and `fool` now auto-invoking on natural-language triggers in addition to their slash commands.
- **What's new**: `council` skill.

## Tests

```
bash sage/tests/test-frontmatter-lint.sh
```

Bash automation verifies the v2.0 frontmatter contract (2 fields only, ≤1024 chars, no `version`, no `when_to_use`, kebab-case names). No `jq`/`yq` dependencies; bash 3.2+ and `awk` only.

LLM-behavior fixtures (skill auto-invocation, grill-me escape valves, council 5-persona output) live in markdown checklists at `tests/test-skill-triggers.md`, `tests/test-grill-escape-valves.md`, `tests/test-council-personas.md`. Walk them by hand in a fresh Claude session, or paste into a Claude Code session and ask it to run each fixture. See [`tests/README.md`](./tests/README.md) for the full hybrid-test rationale.

## Composition with other plugins

sage stays orthogonal — no manifest dependencies, no shared state. Other plugins (remodel) probe for sage's surfaces via natural-language invocation in their own workflows; sage itself doesn't probe back. Don't run `grill-me` and `council` in the same session (different interaction shapes — pick one).

## Platforms

Linux and macOS. The only bash code that ships is the optional `tests/test-frontmatter-lint.sh` lint, which is POSIX-friendly. Windows works for the skills and commands themselves; only the test script needs a bash shell.

## License

MIT — see [`LICENSE`](./LICENSE).

## OMP

Install per the root README. Skills are reachable as `skill://<name>`, with no `sage:` prefix. No Claude Code-only parts.
