# Citation fold-in

Depth for SKILL.md §6. Citation verification is a **mechanical step of spec
authoring** — a command you run, not a ceremony you convene.

---

## 1. The target set

ossify's spec surface is lean, so the set of things a spec may cite is small and
closed:

| Target | Example citation | Resolves against |
|---|---|---|
| **Lean MASTER-SPEC sections** | `MASTER-SPEC §3 (domain model)` | The section exists in the current lean spec |
| **Bones-registry ADRs** | `ADR-0002 (hexagonal domain boundary)` | The ADR exists and the spine's paths sit inside its declared touch surface |
| **Prior releases' increments** | `r0 increment: order port` | The release closed and the increment record exists |
| **File paths and signatures** | `src/app/orders.rs::submit_order` | The path exists; the signature matches |

A bare file path resolves against the work item's `target_repo`, or the sole
declared repo otherwise. Name any other repo in the citation
(`AI workspace: docs/design/…` or `<repo-key>: <path>`), or use an absolute path.

**Release 0 specs cite the lean spec and the bones only.** There are no prior
releases, and the predecessor stack's PRD/SRS/BACKLOG/ROADMAP are retired — a spec
citing `SRS-4.2` is citing an artifact ossify does not produce. Catch it here.

---

## 2. The check

Two kinds, and only the first is a command:

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

**Mechanical** — the path exists, the ADR id exists, the quoted signature matches:

```bash
oss get '[.bones[].adr]'                                  # the ADR ids that exist
test -f src/app/orders.rs                                 # the path exists
grep -n 'fn submit_order' src/app/orders.rs || true       # the signature is still there
```

Guard the grep with `|| true` — a no-match must report a citation miss, not abort
the check.

**Run each check against the root the citation names.** File paths and signatures
use §1's default root or explicit repo qualifier (`oss repo_root <name>`);
absolute paths stand on their own. A bare file path that resolves only in another
repo is a citation miss, not permission to search for a convenient root; the spec
does not lock. Bone ADRs use whichever declared repo the bone concerns
(`start/references/bones-registry.md`); the lean spec lives where `oss spec_path`
prints; release increments live under the AI workspace's `docs/specs/<release-id>/`
(`plan-release/references/release-md-emission.md` §1). The ambient cwd is no root declaration.

**Judgment** — does the cited section actually *say* what the spec claims it says?
A path that exists and a section that denotes something else is the harder failure,
and no command finds it. Read the cited text.

A spec does not lock with an unresolved citation. Either fix the citation, or fix
the claim — never leave it "roughly right".

---

## 3. Mandatory re-verification after a bone change

**Any bone change invalidates every live spine spec's citations**, not just the
spec that changed the bone. When a spine adds, modifies, or re-scopes a bone:

1. Re-run §2 over **every open spine's specs** — including spines planned in a
   previous session that have not closed.
2. Fix the citations that moved - **except in the spec of an item with a dispatch recorded and not
   yet `complete`** (`branch`, `worktree_path` and `base_sha` set; read it with `oss get`). That spec
   is what close compares against its dispatch-time blob id (`spec_oid`), so an in-place edit halts
   its close as `halt:spec-changed`. Record the moved citation for that item and apply it after the
   item closes, or re-plan the item through `planned` and a fresh dispatch (which records the new
   spec's id).
3. Say what changed, so the affected spines' plans get re-read rather than
   silently drifting.

This is the one place the check is **not optional**. A bone is by definition
load-bearing and hard to reverse; a spec still citing its old shape is a plan
being executed against architecture that no longer exists. Registered touch
surfaces make the blast radius findable:

```bash
oss get '.bones[] | select(.adr == "ADR-0002") | .touch'
```

---

## 4. What this is not

- **Not a critic pass.** Citations are denotation, not design. The critic argues
  about whether the plan is right; this asks whether its references point at
  something real.
- **Not a style check.** Citation format is whatever the project already uses.
  Consistency is nice; resolvability is the requirement.
- **Not a gate on the user.** A citation miss is fixed in place, in the same turn,
  by you. Surface it only if the fix changes the plan.

---

## 5. Anti-patterns

- **Citing a retired artifact** — PRD, SRS, BACKLOG, PROJECT_PLAN, a multi-year
  roadmap. ossify does not produce them; a citation to one is a copied habit (§1).
- **Citing a bone with no touch surface.** Then the blast-radius query in §3
  returns nothing and the re-verification silently covers less than it claims.
- **Skipping re-verification after a bone change** because "only one spec touched
  it" (§3).
- **Treating an existing path as a resolved citation.** The path existing is the
  cheap half; the section denoting the claim is the real check (§2).
- **An unguarded `grep` in the mechanical check** — under the dispatcher's
  `set -euo pipefail` a no-match aborts the run instead of reporting a miss (§2).
- **Deferring a citation fix to close.** It costs a minute now and a re-plan later.
