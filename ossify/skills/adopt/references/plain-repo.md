# Plain-repo adoption — class P (#536)

Depth for `SKILL.md` §3, §4, §5 and §6. `/adopt` takes two kinds of project that carry product source: **class L**, a
project onboarded with the scaffold-dev legacy stack (the path in `SKILL.md`), and **class P**, a plain
existing-source repo with no such stack (this file). A project with no product source is class G or H and goes
to `/ossify:start`.

This file is prose on purpose (skill-first question 1: whether `HEAD` holds product, whether a step works and
which decision is real are judgments). The one mechanical part, the git probes, runs fixed arguments on closed
input (question 2).

---

## 1. The class step — after A1, before A2

The class needs the declared repos, so it runs once A1 has resolved or authored the topology. Same order and same
scope as `/start` §3's canonical-content gate: every declared repo except one the pairing manifest declares under
`tooling_repo` (#553; in a native `.ossify/topology.json` every key is checked). The AI workspace's own history is
never an input. `git -C <root> ls-tree -r --name-only HEAD` and `git -C <root> rev-list --count HEAD` only
propose: show what you found, and the operator confirms whether `HEAD` holds product (not docs, a dead prototype
or a bare scaffold). Ask in order; the first yes decides.

1. **Does any declared repo carry product source at `HEAD`?** No: refuse, authoring nothing further, and route to **`/ossify:start`**
   (class G, no history; class H, history only). The topology A1 may have just authored stays, uncommitted, and
   `/start` resolves it. With no operator to answer, refuse a repo with any file at `HEAD` that you do not judge product, saying `re-run with an operator`: `/start` would refuse it for the same reason (start §3). A declared repo with no commit is not this answer: see the unborn-`HEAD` rule below.
2. **Yes, and the project has a scaffold-dev stack** (a roadmap state or an active-context cursor): **class L**.
   Look where A5 looks: the manifest-routed roadmap state (`well_known_paths.roadmap_state`) and memory bank's
   `05-active-context.md`; a native topology routes neither, so look at the conventional
   `<ai-workspace>/.workspace/project-roadmap.json` and `<ai-workspace>/.claude/memory-bank/05-active-context.md`.
   `SKILL.md` as written. Every declared repo goes through L's path in one run.
3. **Yes, and no stack: class P.** A partial stack (legacy files, but neither a roadmap state nor a cursor) is
   P; the adoption record names the legacy files seen.

L and P never mix: the stack's roadmap state and cursor live in the AI workspace, so the stack is project-wide. A
repo the stack never covered is a C2 gap under L, not a second adoption.

A declared repo with no commit has no baseline SHA. If it holds files, stop and name it before anything is recorded:
the operator commits them first (that is not "no product source", and it does not route to `/start`). A repo with
no files at all is left out of the declaration.

Record `Class: P` (or `L`) in the adoption record.

## 2. A1 on class P — two routes

Class P runs in an **AI workspace the operator made**: an empty directory beside the product repo, optionally `git init`,
with `/adopt` started from it. Adoption never makes a product repo its own AI workspace, and
never writes a byte in a product repo during A1.
**Check first** that the working directory is not a declared repo and is not inside one
(compare `git rev-parse --show-toplevel` with each declared or operator-named root). If it is, refuse
before authoring anything, and name the fix: make an AI workspace beside the product repo and run `/adopt` there.

- **No topology on the walk-up path:** ask which repos hold the product, confirm each root against a checkout that
  carries its code, and author `.ossify/topology.json` with each (A1's nothing-found authoring, schema and name
  rules as `/start` §3 states them).
- **A topology already resolves** (a `/pair-workspace` workspace): use it, and ask which repos hold the product.
  A product repo the declaration does not name refuses, and the refusal names the fix in the declaration's own spelling.
  A native `.ossify/topology.json` takes `.repos.<key>.root` (`lib/manifest.sh` reads only `.repos` there); a
  `.workspace/pairing.json` pairing manifest takes a top-level `{"root": "<absolute path>"}` entry under a fresh key
  (`[a-z][a-z0-9_-]*`), which the pairing shape reads as a repo. adopt does not edit a declaration it did not write.

The plain route does not need `/pair-workspace`, which declares one canonical and aborts when that repo holds a
memory bank or `MASTER-SPEC.md`.

**A3's one exemption.** In a workspace that is its own git root, A1 commits the topology it authored only after the gates pass; until then it is untracked.
A3 exempts the exact path `.ossify/topology.json` in the AI workspace, and only when A1 authored it in this run.
When that porcelain half runs, a re-run's topology is no longer "this run's": the operator deletes it (A1 re-authors it) or commits it.

## 3. A3, A4, A5 on class P

- **A3:** `git -C <root> status --porcelain --untracked-files=all` per declared repo.
  Apply `SKILL.md` A3's AI-workspace root determination and recorded skip; the exemption above stays exact.
  Print each other porcelain line with its repo and refuse; the operator names work in flight (finishes or drops it)
  or residue (removes or commits it), in the repo it touched, then re-runs. Adoption never removes it.
  The default-branch rule is unchanged; an unborn `HEAD` stops (§1).
- **A4:** `git -C <root> worktree list --porcelain` per declared repo. Name each worktree besides the main one, and
  get the operator's confirmation that none holds work in flight. The `.worktrees` probe is class L's.
- **A5:** record `A5: no legacy stack` among the gates passed.
- **A6 — something ships.** Class P only, after A5 and before `oss init`. Ask the operator to name at least one
  journey step that works from a clean checkout today, and how they know (a command, or a run they watched).
  None: refuse, before any state is written:

  > nothing ships yet: this project is pre-skeleton. ossify cannot onboard it until one step works, or until the
  > operator decides the code is a prototype and archives it.

  A6 asks; C2 verifies. The topology A1 authored stays uncommitted on a refusal here (§2: delete it to retry).

Once A0 to A6 have passed, commit the authored topology only if the AI workspace is its own git root (the baseline SHAs and `oss init` come after).

## 4. C1, C2 and C4 on class P

C1 and C2 are as `SKILL.md` has them. With no legacy roadmap, read the plan the repo carries (a roadmap, a
planning doc, its spec), then elicit the steps with the operator as `/start` §5 does and mark each against the
checkout.

**C4 closes Release 0 only when at least one step is still `shipped` after C2**, in any repo. A step that fails its
clean-checkout test is already re-marked `next` (C2), and harvested to the feature map then (C1's harvest ran
before C2), or the completion floor refuses. The release description drops `under <legacy-stack>`.

**Zero steps left `shipped`** (a stated known limit): at C4, after C3, do not call `release_add`. Write the adoption
record to that point (class, gates, baseline table, the C1 table, every C2 result and gap), then halt. The hand-off
names what to clear to retry: the file `oss state_path` prints and its `.base.json` sibling, `ADOPTION.md` moved
outside the AI workspace (C5 creates it only when absent; A3 refuses it untracked inside), and C3's uncommitted ADR files in the product repo (commit or remove
them: A3 refuses them on retry). It says what happened: A6 asked, C2 found the checkout disagrees. The
completion floor does not apply to this halt: it is a halt with its record written, not a completion.

## 5. C5 on class P

- **`AGENTS.md`:** a workspace-init stub (first line `<!-- workspace-init stub: ossify:start replaces this file
  -->`) is replaced, not merged, per `../../start/references/occupied-destinations.md` §1a, carrying its
  `## Git policy` and `## AI-trace filter` sections verbatim; the hand-off says so. Any other `AGENTS.md` merges
  as `SKILL.md` says. (Class L benefits too: before this, adopt merged into the stub and kept its marker line.)
- **Files inside a declared repo are inputs only:** its `CLAUDE.md`, `AGENTS.md`, `.claude/`, a spec or design
  doc, a memory bank. Read them for Vision, C1 and the memory-bank harvest. Never write, move or delete one. The
  adoption record lists each one read and each conflict with the AI workspace's `AGENTS.md`; the operator decides
  what to retire. (The `docs/adr/` and `PUBLIC_BOUNDARY.md` rows of C5's table are the only writes into a declared
  repo.)
- `MASTER-SPEC.md`, the memory bank and the other AI-workspace rows: authored where absent, per C5's table.

## 6. Other stations that differ

- **Vision:** elicited as `/start` §4 does, after reading the README and §5's inputs. Class L still confirms.
- **Smoke:** class P with no test suite runs `/start` §9 in full. A repo with one keeps the narrowed smoke.
- **C3:** a repo with no `docs/adr/` gets the forced-enumeration questions as today. An answer that names a real
  decision gets an ADR from `bones-registry.md` §3's mint scan with `dest_repo` set to that repo, minted
  `Accepted`. These files land after the baseline SHA and stay **uncommitted** in the product repo; the hand-off
  names them for the operator to commit.
- **Floor:** C2 may leave zero `shipped` steps (§4); that halt and C3's collision halt (`SKILL.md` C3 1a) are the
  outcomes besides completion.
