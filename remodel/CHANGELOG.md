# Changelog

All notable changes to the `remodel` plugin (named `code-judo` through 0.2.4).

## 0.3.2

`deep-review` no longer pre-approves Bash or Git commands (#1205). It still reads the
branch diff and reports its findings; Git calls use Claude Code's normal permission checks.

## 0.3.1

The recommendation policy copy in `deepen-architecture` follows the source of truth: TOP SEVERITY's
example reads "a restart-class recommendation at orchestrate gates", so a restart option merely on the
menu does not escalate a gate (#111).

## 0.3.0

Renamed from `code-judo` to `remodel`, in the marketplace's rename to `pulsestack`. The commands
are now `/remodel:deep-review`, `/remodel:deepen-architecture`, `/remodel:codebase-design` and
`/remodel:domain-modeling`, and the install key is `remodel@pulsestack`. Behaviour is unchanged.
To move: uninstall `code-judo@claude-agent-scaffolding`, then install `remodel@pulsestack` (the
root README's *Renamed from claude-agent-scaffolding* section has every step).

## 0.2.4

Wording patch to the 0.2.3 grill (#1065). The triage sentence on a destinationless defer now says
what it meant: the agent's own lean is `defer`, which is always asked, and the policy's
`<accept|defer>` digest never carries `defer` here. The "not ready to build" ending is scoped to the
in-plugin protocol, not to whichever resolver fires. The remedy says it is a reply in the same
conversation, what survives (settled items), and that a fresh run keeps nothing. Prose only.

## 0.2.3

`deepen-architecture`'s in-plugin grill ends on every path (#391). A **defer** settles an agenda item
only when the user names where it is tracked — an issue, or a file and the line that records it;
the skill offers draft issue text and files nothing. A defer with no destination is asked rather than
auto-applied, and if one stays untracked the grill ends with "not ready to build" and nothing gets
built. Before this, a defer was neither an answer nor an auto-applied item, so the grill asked again
or stopped against its own done rule. The shared recommendation policy is unchanged. Prose only.

## 0.2.2

`deep-review` gains counterweights to abstraction, adapted from `DietrichGebert/ponytail` (MIT).
Most of its remedies add structure; these add stops on the other side. The bar and the
presumptive blockers are unchanged.

- The rubric asks whether every part of a change needs to exist, and flags speculative code:
  options, config, modes, or extension points nobody uses yet, and single-implementation
  abstractions.
- Standard 6 reaches past the codebase: the standard library, a platform feature, or an
  installed dependency before new code, and no new dependency for a few lines.
- Remedies cut along jobs, not length, and prefer the deleting fix when two fix the problem.
- Simplification never removes trust-boundary validation, data-loss handling, a security
  check, or accessibility.
- The disposition requires a concrete case for each finding, and a re-read of the lines that
  confirms its premise.

## 0.2.1

- `design-it-twice` hands each parallel brief the vocabulary source the caller resolved under
  `domain-modeling`'s *Where the model lives*, not a hard-coded `CONTEXT.md` (#392). In a repo
  whose vocabulary has another owner (an ossify repo has no `CONTEXT.md`), every brief pointed
  at a file that does not exist.
- The frontmatter lint measures a description's parsed bytes, not its whitespace-flattened copy,
  so a long literal block can no longer pass the 1024-byte cap (#390); a parser that exits
  non-zero is a lint failure instead of empty facts that a command passed (#404); kebab-case is
  checked against an explicit ASCII class, not a locale range (#404).
- A fixture suite, `tests/test-frontmatter-lint-fixtures.sh`, runs the lint on small plugin
  trees so its failure branches run in CI: the over-cap literal, an unreadable file, invalid
  UTF-8, non-ASCII and upper-case names, a whitespace-only description, and the human-only
  branch (#404). #404's parity test against orca-crew's copy no longer applies: orca-crew was
  retired (#729).

## 0.2.0

OMP marketplace surface.

- Wrappers name the skill by `skill://` path as well as `${CLAUDE_PLUGIN_ROOT}`; skill descriptions lead with the trigger ("Use when ...") so OMP's skill match fires; Claude Code tool names carry an OMP alias where a skill names one; the README gains an OMP note. No Claude Code-only parts.

## 0.1.1

- `domain-modeling`'s ADR-format reference no longer names `scaffold-dev`'s ADR skill as an owner of
  `docs/adr/`; `scaffold-dev` left the marketplace. ossify's ceremonies remain the named owner.

## 0.1.0

Initial release. Four prose skills, no runtime library.

- `deep-review` — strict maintainability review of a diff or branch. Ports the upstream
  standards, review questions, escalation list, preferred remedies, tone, prioritized output
  order, approval bar, and presumptive blockers. Human-invoked only.
- `deepen-architecture` — proactive codebase scan for deepening opportunities, rendered as a
  single HTML report in the OS temp directory and opened in the browser. Human-invoked
  only.
- `codebase-design` — the deep-module vocabulary and principles, plus the dependency
  categories, seam discipline, and the design-it-twice parallel pattern.
- `domain-modeling` — `CONTEXT.md` glossary discipline and ADR authoring, both handed off
  where another lifecycle already owns them.

Invocation posture is declared on both surfaces, because they read different files:
`disable-model-invocation: true` in SKILL.md frontmatter for Claude Code, and
`policy.allow_implicit_invocation: false` in `skills/*/agents/openai.yaml` for Codex, which
does not read the frontmatter field. The lint asserts the two agree, in both directions.

**Deliberate departures from upstream — this list is canonical; no other file restates it.**

1. `deep-review` produces one report and one categorical disposition pass and never loops,
   and its verdict is advisory rather than a merge gate.
2. The cross-skill dependency web is internalized, with the grilling step resolving softly to
   `ossify:challenge`, then `ai-mentor:grill-me`, then an in-plugin protocol.
3. `deepen-architecture` reads path-bearing history (`git log --name-only`) for its hot-spot
   scan. Upstream specifies `--oneline`, which prints commit subjects and no file names, so it
   cannot answer the question it is asked. The requirement is ported; the command is corrected.
4. `domain-modeling` **composes** ADRs but does not file them — it names the destination and
   hands off. Upstream writes the file and mints the number by scanning the directory. An ADR
   directory is a numbered sequence with one owner, and in these repos something else already
   owns it (ossify's ceremonies, and `scaffold-dev`'s ADR skill), so two tools scanning for
   "the next number" collide silently. The guarantee is that the skill's flow never mutates a
   shared sequence at all — there is no direct-write variant, because filing safely means
   creating the numbered file atomically and a prose skill cannot, so a read-then-write loses
   silently to whatever else is numbering the directory. The same rule governs the glossary: upstream writes `CONTEXT.md` unconditionally, and this
   plugin writes it only where nothing else owns the project's vocabulary — where a lifecycle
   already assigns terms an owner, it names the owner and hands the term over.

Adopts the marketplace recommend-by-default convention
(`docs/conventions/recommendation-policy.md`) for the grilling loop, shipped as a
byte-identical copy at `skills/deepen-architecture/references/recommendation-policy.md` and
guarded by the repo-root parity test `tests/test-recommendation-policy-parity.sh`.
`references/grilling.md` carries only how the policy renders on this surface.

Deferred to a later release: the OpenCode adapter surface, eval fixtures for the two review
skills, and the upstream security/correctness review axis. Tracked on #382.
