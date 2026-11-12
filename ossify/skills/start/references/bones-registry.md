# Bones registry (forced-enumeration ADRs)

Depth for SKILL.md §7. The bones registry replaces the legacy always-Accepted
ADR-0001 blob. Every bone is **an ADR from birth**, with a declared **touch
surface** and an optional **revisit trigger**.

---

## 1. Why forced enumeration

The failure mode is not wrong answers — it is *unasked questions*. A category
silently omitted at spec-core resurfaces as an unplanned rewrite three releases
later. So every category below is answered **or explicitly marked
`not-applicable` with a one-line reason**. Never silently skipped.

`not-applicable` is a legitimate and common answer at Release 0. "No persistent
state yet — not-applicable, revisit when the first store lands" is a *complete*
answer to the data-ownership category, and it doubles as a revisit trigger.

---

## 2. The nine categories

| # | Category | The question it forces |
|---|---|---|
| 1 | **System shape & deployment topology** | What runs where? One process, client+server, desktop app, CLI, job + worker? What is the deployment unit? **Splitting work that could run in one process into a second deployable needs the measured pressure that requires it** (`plan-spine/references/codebase-design.md` §3) — "it will need to scale" is not an answer. A topology the product *imposes* — a mobile or desktop client shipped through a store, a device agent — is not a split, and needs no evidence for the deployables the platform actually forces. Judge that by the **deployment unit**, not the runtime: a browser front end served from the backend's own artifact and pipeline is one deployable, not two, so splitting it out is still a split. Every deployable beyond what the platform forces needs the evidence. |
| 2 | **Module boundaries & dependency direction** | What are the top-level modules and which way do dependencies point? Is there a core that must not depend on adapters? |
| 3 | **Data ownership & migration posture** | Who owns each piece of persistent state? What is the migration story — expand/contract, destructive, none-yet? |
| 4 | **Public contracts & compatibility policy** | What is promised to callers (API, CLI flags, file formats, DB schema)? What is the breaking-change policy? |
| 5 | **Trust boundaries & destructive operations** | Where does untrusted input enter? Which operations are irreversible (spend money, delete data, send to a third party)? |
| 6 | **Failure visibility** | How does a failure become *visible* — logs, metrics, a user-facing error, a dead-letter queue? What must never fail silently? |
| 7 | **Rollback & evolution strategy** | How is a bad release backed out? What is designed to be replaceable vs. what is deliberately load-bearing? |
| 8 | **Stack** | Language, runtime, key frameworks/crates, storage, build/test tooling — and which of those choices are reversible. |
| 9 | **Cross-cutting constraints** | Auth, tenancy, identity, licensing/posture, determinism, i18n, accessibility — whatever cuts across every module. |

The **privacy posture** (§10 of the skill body) lands as a bone in category 9 —
its decision is the posture + channel design, its touch surface is the
private-side modules plus the seam files, its revisit trigger is seeded from
revenue intent. See `references/posture-block.md`.

---

## 3. Anatomy of a bone

Each answered category produces one ADR (or occasionally two, when a category
holds two genuinely separable decisions). Four required parts:

1. **ADR reference** — the authority for accepted and minted identifiers:

   | Form | Grammar |
   |---|---|
   | Accepted ADR identifier | `ADR-[A-Za-z0-9]+`, case-insensitive, one complete value with no embedded whitespace |
   | Ossify-minted identifier | numeric only, continuing the project's ADR sequence |

   Adopted references may contain ASCII letters or digits after the prefix;
   ossify itself mints only the numeric form. Bones
   default to the **proposed-then-flip** status protocol: authored `Proposed`
   here, flipped to `Accepted` (with an empirical-validation note) once a real
   release exercised them. A bone that was never exercised has not been
   validated, and saying so in its status is honest.
2. **Title** — the decision in a noun phrase. "Hexagonal core with six port
   traits", not "Architecture".
3. **Touch surface** — the glob set that, when a later spine's plan touches it,
   reclassifies that spine to `bone`. This is the mechanical teeth of the whole
   registry (§4).
4. **Revisit trigger** (optional but strongly encouraged) — the *condition* that
   reopens the decision. Not a date. "Revisit when a second storage backend is
   needed", "revisit when the SaaS decision lands", "revisit at MVP".

### Recording it

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

```bash
oss bone_add "<ADR-ref>" "<title>" "<touch-glob-csv>" "<revisit trigger>"
```

Touch CSV entries follow risk-gates.md §3's grammar — a bare `,` separates entries, `\,` is a literal comma inside one; multiple directories are multiple entries (case-globs do not brace-expand). The whole list is **one** argument: quote it. Space-splitting it does not mint a shorter list and warn — the second word lands in the `[revisit trigger]` slot, so the surface silently shrinks and a glob becomes the bone's durable revisit trigger. The verb cannot tell the two apart for you: its 4th argument is optional, so it will not refuse the call. It does refuse, at rc 2, a list of more than one line, and any entry carrying leading or trailing whitespace or an invisible format character (CR, tab, NBSP, BOM, zero-width space) — which would be journaled as a glob matching no real path, leaving `touch_check` clean on the very code the bone claims to cover. It also refuses, at rc 7, a case variant of an existing reference (`adr-0007` after `ADR-0007`; the fold is ASCII) and names the existing spelling (#705).

Worked example:

```bash
oss bone_add "ADR-0002" "Hexagonal core with six port traits" \
  "src/domain/**,src/port.rs,src/adapters/**" \
  "revisit when a second storage backend is needed"

oss bone_add "ADR-0005" "No persistent state at Release 0" \
  "not-applicable" \
  "revisit when the first store lands"
```

The registry entry is the *index*; the ADR file carries the full context /
decision / consequences prose. Keep them consistent — the index is what the
mechanical checks read.

### Repointing a bone's touch surface

When the code a bone governs moves — into a `packages/` tree, a renamed module
— its registered globs match nothing, and `oss touch_check` goes silently
**clean** for every spine that touches the moved code: the spine is never
reclassified to `bone`, and nothing reports why. Re-point the surface with a
corrective append, never by editing state:

```bash
oss bone_set_touch "ADR-0002" "packages/core/src/domain/**,packages/core/src/port.rs"
```

It **replaces** the whole touch list — name every glob the bone should cover,
old ones included where they still apply. The CSV grammar is the same as
`bone_add`'s. It refuses an unknown ADR ref, a duplicate one (#305), and a list
carrying no glob at all — a blank surface would make the check clean on every
path, the defect being repaired. It also refuses, at rc 2, a list of more than
one line (a newline splits the csv into two) and any entry carrying leading or
trailing whitespace or an invisible format character — a CR, tab, NBSP, BOM or
zero-width space kept from a file composed elsewhere. Such an entry would
otherwise be journaled as a glob that matches no real path, leaving the check
clean on exactly the code you were re-pointing to cover. `bone_add` refuses the
same entries; the one thing it cannot refuse is the split list above, because its
4th argument is optional. Update the ADR file's own statement of scope in
the same change, so the index and the decision still agree.

**Nothing verifies that the new globs match live code.** The verb is a
correction you apply, not a detector: a re-point at a path that does not exist
is accepted and stays silent, exactly like the stale glob it replaced. Check the
new list yourself before relying on the repair — feed the moved code's real
paths (list them with `git ls-files`) to `oss touch_check`, whose rc 0/1
is the hit/clean verdict and is read per
`plan-release/references/bone-touch-judge.md` §2. A re-point that still reads
clean on the code it was meant to cover has repaired nothing.

### Amending a bone's title or revisit trigger

A bone's title and revisit trigger are amended the same way, by a corrective
append (1.22.0, #305): `oss bone_set_title "<adr>" "<title>"` and
`oss bone_set_revisit "<adr>" "<trigger>"`, where an empty trigger clears it.
Each changes that one field and nothing else, and refuses an unknown or
duplicate ADR ref. Quote the value: each verb takes exactly two arguments, so an
unquoted title is refused rather than cut at its first space. Update the ADR
file in the same change.

### Authoring the ADR file

`oss bone_add` writes **the index row only**. Nothing writes the ADR file, and
ossify ships no `/adr` utility — that is a settled decision, not a pending
gap — so **this section is the convention, permanently**:

**Where:** each declared repo's `docs/adr/` — resolve the repo the decision
concerns with `oss repo_root <name>` (the sole declared repo when there is
only one; under more than one, the repo the bone's touch-glob actually
covers — ask if that is not obvious from the surface named). Bones are
decisions about the *product's* architecture, so they live with the product,
not in the AI workspace beside the planning docs.

**Filename:** the file **joins the target repo's existing series** — the same
prefix form, the same case, the same zero-padding width as the files already in
that `docs/adr/`:
`adr-0002-hexagonal-core-with-six-port-traits.md` beside an `adr-` series,
`0014-…` beside scaffold-onboard's bare seed, `ADR-003-…` beside an uppercase
three-digit series. When that directory is **empty**, the default is the
prefixed, four-digit form matching the index reference:
`adr-0002-hexagonal-core-with-six-port-traits.md`. Never add the prefix to, or
strip it from, a series that already exists — a directory holding two forms at
once is the state the numbering scan below reads both forms for, and this rule
must not create it.

The forms differ by where the series came from: `scaffold-dev`'s ADR skill
writes the prefixed `adr-NNNN-kebab.md`, `scaffold-onboard`'s seed is the bare
`0001-record-architecture-decisions.md`, and an adopted project may carry the
prefixed form in either case and at any width (PulseDB's series is
`ADR-001-redb-for-storage.md`).
A project migrating to ossify already has its series, and the reason bone ADRs
live in the repo they concern is that the decision belongs with the code it
governs — **the file joins that repo's series rather than starting a rival one**
elsewhere. The NUMBER, though, comes from the project-wide sequence below.

**The destination must be one of the scanned repos.** An unset `dest_repo`
or a value that matches no name in `repos` refuses, naming that value. The
four-digit default is only for a scanned destination with no existing series;
it never substitutes for an unknown destination.

**Numbering is project-wide, across every declared repo:** the next number is
the highest existing plus one **anywhere in the project**, **counting both
forms**. The *file* still lands in the repo the decision concerns — only the
SEQUENCE is shared — so the scan takes that repo as `$dest_repo` and takes the
minted **width** from *its* series: the file must not be the odd one out in its
own directory. Read it, do not guess:

Execute this entire fence in one fresh shell invocation. It is self-contained:
`repos` is every declared repo name, one per line; `oss` resolves their roots.
The default `adr_scan_mode=mint` also requires `dest_repo` and prints the next
reference. Adoption C3 sets `adr_scan_mode=inventory` and captures `<repo-name><TAB><ADR-filename>` lines
printed to stdout (one line per directory entry; empty directories emit none), with no destination and no mint. Each invocation owns its
temp files and removes them before returning, including on refusal; a subshell
keeps its cleanup trap and variables out of the caller's shell.

```bash
(
set -euo pipefail
mode="${adr_scan_mode:-mint}"
case "$mode" in mint|inventory) ;; *) echo "the numbering scan refuses mode '$mode'" >&2; exit 1 ;; esac
# Validate inputs BEFORE allocating either temp file.
if ! printf '%s\n' "${repos:-}" | grep -q '[^[:space:]]'; then
  if [ "${repos+x}" = x ]; then shown='[empty]'; else shown='[unset]'; fi
  echo "the numbering scan refuses repos '$shown': declare the repos to scan" >&2
  exit 1
fi
is_destination() { [ "$1" = "${dest_repo:-}" ]; }
if [ "$mode" = mint ]; then
  dest_scanned=0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if is_destination "$name"; then dest_scanned=1; fi
  done <<< "$repos"
  if [ "$dest_scanned" = 0 ]; then
    if [ "${dest_repo+x}" != x ]; then shown='[unset]'; else shown="${dest_repo:-[empty]}"; fi
    echo "the numbering scan refuses dest_repo '$shown': it is not a scanned repo" >&2
    exit 1
  fi
fi
scan=""; dest=""
trap 'if [ -n "$scan" ]; then rm -f -- "$scan"; fi; if [ -n "$dest" ]; then rm -f -- "$dest"; fi' EXIT
scan="$(mktemp)"; dest="$(mktemp)"
while IFS= read -r name; do
  [ -n "$name" ] || continue
  root="$(oss repo_root "$name")" || { echo "the numbering scan could not resolve a root for repo '$name'" >&2; exit 1; }
  if ! mkdir -p "$root/docs/adr"; then
    echo "the numbering scan could not create $root/docs/adr - an incomplete inventory is not an empty series" >&2
    exit 1
  fi
  if ! listing="$(ls -1 "$root/docs/adr" 2>/dev/null)"; then
    echo "the numbering scan could not read $root/docs/adr - an incomplete inventory is not an empty series" >&2
    exit 1
  fi
  if [ "$mode" = inventory ]; then
    while IFS= read -r filename; do
      [ -n "$filename" ] || continue
      printf '%s\t%s\n' "$name" "$filename" >> "$scan"
    done <<< "$listing"
  else
    printf '%s\n' "$listing" >> "$scan"
  fi
  if is_destination "$name"; then printf '%s\n' "$listing" > "$dest"; fi
done <<< "$repos"
if [ "$mode" = inventory ]; then cat "$scan"; exit 0; fi
# Numeric-only parsing is by design: mint continues numeric filenames,
# while accepted references follow the authority in §3 part 1.
# Project-wide NUMBER: prefixed ADRs in either case and bare seed filenames.
highest="$(sed -n -e 's/^[Aa][Dd][Rr]-\([0-9][0-9]*\)-.*\.md$/\1/p' \
                    -e 's/^\([0-9][0-9]*\)-.*\.md$/\1/p' "$scan" | sort -n | tail -1)"
# WIDTH follows only the destination's existing series; an empty one -> 4.
narrow="$(sed -n -e 's/^[Aa][Dd][Rr]-\([0-9][0-9]*\)-.*\.md$/\1/p' \
                   -e 's/^\([0-9][0-9]*\)-.*\.md$/\1/p' "$dest" | sort -n | tail -1)"
if [ -z "$narrow" ]; then fmt='%04d'; else fmt="%0$(printf '%s' "$narrow" | wc -c | tr -d ' ')d"; fi
printf "ADR-${fmt}\n" "$(( 10#${highest:-0} + 1 ))"
)
```

**Why project-wide and not per repo.** A bone record stores `adr`, `title` and
repo-relative touch globs — no repo key — and `touch_check` reports a bare
`bone <adr>`. With numbering reset in every repo, two repos whose `docs/adr/`
both start empty each mint `ADR-0001`, and from then on nothing can tell the two
records apart: not a citation, not a reclassification reason, not a mechanical
touch hit. A shared sequence keeps the identifier unique by construction, which
is cheaper than qualifying it everywhere it is read. The cost is that a repo's
own series gains gaps — a repo may hold ADR-0003 and ADR-0007 and nothing
between — and that is the intended trade: gaps are legible, collisions are not.

Things this has to get right, each of which has already produced a duplicate id:

- **Every declared repo is scanned, not just the one the ADR lands in.** That is
  the whole point of the shared sequence; scanning one repo reintroduces the
  collision this block exists to prevent.
- **Every form a series can be in is scanned, case-insensitively.** A directory
  holding `adr-0002-…` or `ADR-002-…` matched only against the bare `NNNN-…`
  form — or matched case-sensitively — yields no number at all, so the scan
  restarts at 1 and mints an id that already exists: duplicating an identifier
  that bone citations and touch records both key on (#301).
- **The minted WIDTH follows the DESTINATION repo's series, not a fixed `%04d`
  and not the project-wide one.** With an `ADR-099-…` series elsewhere and
  `adr-0007-…` in the destination, a project-wide width mints `ADR-100` into a
  four-digit directory — two widths in the file the next reader must continue
  (#301, round 1 C2).
- **An unreadable `docs/adr/` refuses; it never reads as empty.** `ls` failing
  answers the same "no matches" as a first-ever ADR, and the two have opposite
  remedies — a refusal that names the path is the difference between minting the
  second id for a decision and minting a new one. A `mkdir` that cannot create
  the directory refuses the same way, also naming the path.
- **Every exit path removes the scan's temp files.** The scan is one populated
  `mktemp` per mint on the success path *and* on each refusal, so each `exit 1`
  takes them with it (round 1 R6) — the same leak class §5's sweep closes for
  its own `$hits` under #558.
- **`10#` forces base-10.** Without it `0008` is an invalid octal literal and the
  arithmetic aborts under the dispatcher's `set -e`.

**Sections (MADR-lite), in this order:**

```markdown
# ADR-NNNN — <title>

- **Status:** Proposed        <!-- bones default to proposed-then-flip (§3.1) -->
- **Date:** <YYYY-MM-DD>

## Context
What forced the decision. The constraints that were real at the time.

## Decision
What was chosen, stated in the present tense.

## Consequences
What this makes easy, what it makes hard, and what it forecloses.
```

Mint the number **before** `oss bone_add`, so the index reference and the file
agree. An index row pointing at a file that was never written is the failure
this section exists to prevent: the mechanical checks read the index and pass,
while the prose the decision actually lives in does not exist.

---

## 4. Touch-surface glob semantics

Touch surfaces are matched with **bash `case` glob semantics**, evaluated by
`oss touch_check <path>...`:

- `*` matches **any characters including `/`**. So `src/domain/**` behaves as a
  plain prefix wildcard: it matches `src/domain/order.rs` *and*
  `src/domain/pricing/rules.rs`. There is no real double-star operator — write
  `**` for readability, but understand it as "everything under here".
- `?` matches one character; `[abc]` matches a character class.
- Paths are matched as written in the spine plan — keep them repo-relative and
  consistent with how plans list changed paths.
- `oss touch_check` returns **rc 0 when a path matched** (a hit) and **rc 1 when
  clean** — the inversion is deliberate and callers depend on it. It prints
  `bone <adr>` / `risk_gate <name>` per match. **rc 2 is a third answer, not a
  clean one**: no paths were given, or the state could not be read. It says why
  on stderr; never let a two-branch `if` fold it into "clean".

**Write surfaces that are neither too tight nor too loose.** `src/**` catches
everything and makes every spine a bone (ceremony inflation). `src/domain/order.rs`
alone misses the sibling file the next change lands in. Aim at the directory or
module that embodies the decision.

### The downstream consequence (not this skill's job, but why it matters)

At release planning, a spine whose plan touches **any** registered bone or
risk-gate surface is auto-reclassified to `bone` — independently of, and in
addition to, the critic veto. That is the mechanical, non-skippable
half of class declaration. `plan-release` owns that step; `start` owns making
the surfaces exist and be accurate.

---

## 5. Release-0 minimum

**Only the bones the skeleton actually touches.** The other categories are still
*answered* — most of them with `not-applicable` plus a revisit trigger — but
they do not get elaborate ADR prose at bootstrap. A Release-0 registry of five
short ADRs and four `not-applicable` lines is a complete registry.

Bones grow at release closes, like everything else.

---

## 6. Anti-patterns

- **Skipping a category silently.** The whole point. Answer or mark
  `not-applicable`.
- **A bone with no touch surface.** Then nothing can ever detect that a spine
  moved it; it is a comment, not a bone. (`not-applicable` is the one legitimate
  placeholder — and it matches nothing, deliberately.)
- **Architecture astrology.** A bone for a decision that has no consequence in
  code this year. If you cannot name the touch surface, you are not making a
  decision, you are speculating.
- **Date-based revisit triggers.** "Revisit in Q3" is not a condition; it will
  be ignored. Name the event.
- **Authoring all nine categories at full depth on day one.** See §5.
