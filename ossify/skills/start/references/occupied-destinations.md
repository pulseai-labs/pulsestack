# Occupied destinations — `/start` never writes over a file

Depth for SKILL.md §3 and §13. `/start` can run in a workspace that already
holds files at its destinations: a project scaffold-onboard set up before any
code carries a legacy MASTER-SPEC, a hand-authored `AGENTS.md` or `CLAUDE.md` and a memory
bank whose LIVE files (`05`, `06`, `09`, `10`) hold history nothing else
records. §3's canonical-content gate never sees them, because it reads declared
repos and the AI workspace is never one. This file is the rule that keeps them.

Regenerating an existing file is opt-in, per file, and always confirmed.

---

## 1. Check every destination before `oss init`

The ceremony writes before §13: bones ADRs at §7, `PUBLIC_BOUNDARY.md` at §10,
the lean MASTER-SPEC at §11. So the check runs in §3, past both gates and
before `oss init` — an operator who stops here is left with nothing
written, not with state that the next `/start` refuses.

Resolve the path of every output in §13's table (`memory-bank-brief.md` §4 —
`oss repo_root ai_workspace` for the workspace; a loop over declared repos
never reaches it) and check whether a file already exists there: the
MASTER-SPEC at `oss spec_path`, the EXECUTIVE-SUMMARY, each memory-bank
file where the bank lives (`close/references/harvest.md`, "Where the bank is"),
`AGENTS.md`, `CODING_STANDARDS.md` and `review-ledger.md` (`reviewer-home.md` §1), each `PUBLIC_BOUNDARY.md`, and the private boundary inventory —
checked **both** at `posture-block.md` §7's convention,
`<ai-workspace>/docs/private-boundary-inventory.md`, **and** for any other
`docs/*inventor*.md` beneath the `ai_workspace` root (a case-insensitive glob:
this output is named by convention, not by a routed key, so a project adopted
from another stack may hold its equivalent under its own name). **A name is not
an equivalence**: read each candidate, and treat it as this destination only when
its contents carry §7's own table — the moat columns (`Moat item`, `Channel`,
`Where it lives`, the override/injection seam, the leak-risk note). A candidate
that matches by name and **not** by structure (`docs/dependency-inventory.md`,
`docs/asset-inventory.md`, an `inventory.md` about something else) is a
**possible** inventory: name it to the operator as exactly that and ask whether
it is the inventory or a file to leave alone — never silently equate it with the
destination, and never write the inventory past an unanswered candidate, or the
moat inventory is never authored and the release-close audit has no comparison
artifact. A candidate that does carry the structure **is** this destination,
occupied, and takes the same per-file answer; never write a second inventory
beside one that already exists — §7's "read what is there, never create a second one"
is the rule this check enforces.
A MASTER-SPEC anywhere else in the workspace is not overwritten, but name it to
the operator too: two specs side by side is a question, not a default. Bones ADRs take a
fresh number from the `bones-registry.md` §3 scan, so they do not collide here;
if one ever would, the same rule applies. An output whose path no route names
yet — an EXECUTIVE-SUMMARY with no routing key — cannot be checked here; §2's
last paragraph checks it when its path is chosen.

A destination that holds nothing is written as usual, with no question.

### 1a. Two instruction-file cases

**workspace-init's stub is not occupied.** An `AGENTS.md` whose first line is
exactly `<!-- workspace-init stub: ossify:start replaces this file -->` is the
temporary file workspace-init wrote, and it counts as unoccupied: write
ossify's `AGENTS.md` over it with no question, and say in the §13 hand-off
that the workspace-init stub was replaced. The marker must be the first line.
An `AGENTS.md` with the marker anywhere else, or without it, is occupied and
takes §2's question like any other file.

**Carry the stub's two policy sections, verbatim.** The stub is not only a
placeholder: it is where workspace-init recorded this workspace's git policy and
its AI-trace filter, and ossify's `AGENTS.md` does not regenerate either. Dropping
them would let a later agent push without asking — the stub's own
`## Git policy` is the default-deny rule, and `## AI-trace filter` is why a hook
exists. So when the marked stub is replaced, copy both sections from it into
ossify's `AGENTS.md` **verbatim**, wording and bullets included, and say in the
§13 hand-off that the workspace-init stub was replaced and its `## Git policy`
and `## AI-trace filter` sections were carried across. Section names and text are
`workspace-init/templates/AGENTS.md.stub.tmpl`'s; read the file the workspace
actually holds, since a stub written by an older workspace-init may read
differently, and carry what is there rather than the template's current text.

**A leftover `CLAUDE.md` is not a destination.** `/start` never writes
`CLAUDE.md`. When the AI workspace holds one (at its root or at
`.claude/CLAUDE.md`), leave it untouched, and say in the §13 hand-off that
Claude Code loads it over `AGENTS.md` — run
`ossify:doctor` (OMP: `skill://doctor`) for the repair and any remaining suppressors.

## 2. Stop and ask, per file

When a destination is occupied, write nothing over it. Name every occupied
file to the operator, with its path and size, and ask for each one:

- **Keep** — the file stays exactly as it is. Do not write ossify's version over
  it, merge into it, or append to it. Say in the §13 hand-off which output was
  not authored because of it. **Not offered for the MASTER-SPEC:** §11 audits
  and §13 derives from the lean spec, so a kept legacy spec would feed both. For
  that file the choices are move aside, or stop the ceremony.
- **Move aside** — when that file's station comes, and not before, rename the
  existing file to a path that holds nothing, then write ossify's version at the
  destination, and say in the §13 hand-off where it went. A ceremony stopped
  earlier has moved nothing.

The operator may answer for several named files at once, or stop the ceremony
here. Nothing has been overwritten either way. Never pick an answer the
operator did not give: no default, no automatic move, merge or migration.

Every later write honours the answer for its file, and checks its destination
again just before writing: one that became occupied after §3, or one §3 could
not resolve, is asked about the same way. Never write a file whose path was
not checked.

## 3. Why the route is a question

No flow that converts a legacy spec or memory bank ships, so routing there
would strand the operator. Asking per file is a route that always runs.
