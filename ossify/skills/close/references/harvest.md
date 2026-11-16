# Memory-bank harvest — spine close step 9

Depth for `spine-close.md` §9 and SKILL.md §5. This is the **only copy** of the
harvest ceremony: the entry shape, the two-file allowlist, the tagging
convention and the append rules live here and nowhere else.

The harvest is a **core row in both classes** (spec §6.1) — bone and flesh differ
in the depth of the optional rows, never in whether this one runs. What it does
is narrow and worth stating up front: it moves a handful of durable lines out of
artifacts nobody re-reads (`report.md`, `handoff.md`) and into the two live
memory-bank files that every future session loads. Everything else in the bank is
derived from the lean spec and is off limits here.

---

## 1. Where it sits, and why the order is what it is

Step 8 authors the retrospective. **Step 9 is this.** Step 10 is worktree +
branch cleanup. The harvest runs **before cleanup, always**.

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

**The reason is that cleanup is terminal, not that the inputs live in the
worktree.** They do not: `report.md` and `handoff.md` sit beside `spec.md` in the
work item's docs directory under the AI workspace (`work-item/SKILL.md` §7), which
worktree removal never touches. `oss worktree_remove` runs `git branch -d`, refuses
an unmerged branch at rc 8 and a **dirty** worktree at rc 8 rather than forcing
(an rc 8 there is a real signal, never something to force past), and once it
succeeds the branch is gone — so every step
that might still need to **halt** must run first. That is the whole ordering
argument; do not restate the false one.

**The harvest never removes a handoff.** It reads them and leaves them where they
are. Nothing in this release deletes a handoff at either scope.

---

## 2. Enumerate the inputs — this is the step that silently returns nothing

A ceremony that cannot find its inputs refuses everything, applies nothing, and
reports an honest `wrote 0`. That reads exactly like "there was nothing to
harvest". Resolve the paths deliberately.

**The work items come from state:**

```bash
items="$(oss get "[.work_items[] | select(.spine==\"$spine_id\" and .status != \"abandoned\") | .id] | join(\" \")")"
[ -n "$items" ] || { echo "close: no work items recorded for $spine_id - halt"; exit 1; }
```

**Test the output, never the rc.** `oss get` is `jq -r` without `-e`: a `select`
matching nothing exits **0** with an empty string (`routing.md` §4).

**`abandoned` items are left out.** Withdrawn before dispatch, they have no
`report.md` and no per-item handoff, so enumerating them would name a missing
report for each — a gap in the record that is not one. `spine-close.md` §2
already named them in the close.

**The directory comes from a glob, and it is hoisted once per spine.** Nothing in
state holds a spine slug, so the spine directory is recovered exactly as
`work-item-close.md` §1 **Route B** recovers it — including its ambiguity guard,
which is the part that matters:

```bash
parts="$(oss id_parse "$spine_id")" || parts=""
rel_id="r$(printf '%s\n' "$parts" | awk '{print $2}')"
rel_dir="$(oss release_dir "$rel_id")"   # ABSOLUTE, ai_workspace-rooted

matches="$(find "$rel_dir" -maxdepth 1 -type d -name "$spine_id-*" 2>/dev/null)"
n="$(printf '%s\n' "$matches" | grep -c . || true)"
[ "$n" -eq 1 ] || { echo "close: expected exactly one spine dir for $spine_id, found $n - halt"; exit 1; }
spine_dir_abs="$matches"
```

Route B derives that directory from a **single work-item id**; running it
literally per item re-globs N times for one answer. Hoist it, then compose each
item's paths:

```text
<spine_dir_abs>/work-<wi-id>/report.md
<spine_dir_abs>/work-<wi-id>/handoff.md
```

`oss spine_dir "<release-id>" "<spine-id>" "<slug>"` re-composes the same path
**relatively** once the glob has recovered the slug, which makes it a useful
cross-check against `$spine_dir_abs`. Prefix it with `oss repo_root ai_workspace`;
it is never the way in.

A work item whose `report.md` is missing is **named, not skipped silently** — a
`complete` item with no report is a gap in the record, and the close summary is
where it belongs. (**The close summary** is the ceremony's final assistant
message, defined in `close/SKILL.md` §10 — a message, not a file. This reference
routes three things there; that section is what they route to.)

---

## 3. What `handoff` means in this release

**Only the per-work-item `handoff.md`** — the one the execution lane writes at
`<ai-workspace>/docs/specs/<release-id>/<spine-id>-<spine-slug>/work-<wi-id>/handoff.md`
(`work-item/references/handoff-contract.md`). Session handoffs are a different
artifact — the standalone `/ossify:handoff` utility authors them wherever the
host repo's evidence says they live, outside any ceremony. Scope the read to
the per-work-item files and do not go looking for session handoffs: **they are
not harvest inputs at either scope** (`spine-close.md` §9), they have no fixed
location for a sweep to enumerate, and a sweep that expects them mis-reports an
empty harvest as a finding.

Inside a handoff, the durable candidates are the appended **`## Clarifications`**
— the mid-flight answers to spec ambiguity (`work-item/references/handoff-contract.md` §3). The
retrospective reads those too, for a different purpose: the retro is this spine's
story, the memory bank is what the *next* spine needs to not re-learn.

---

## 4. Read `## 9. Suggestions for memory bank`, byte-exact

That heading is the report contract's, pinned in `work-item/references/report-contract.md`
§1, and it is matched **by exact string**. A section that reads "Memory bank
suggestions" is a section that never gets harvested. If a report is missing the
heading altogether, say so by name — a missing section reads as "not run", an
empty one reads as "considered, nothing to say", and only one of those is a
finding.

---

## 5. Categorise — two live files, and one thing that is not an append

| Candidate | Goes to |
|---|---|
| A caveat, a gotcha, an unverified claim, a landmine the next session will step on | `09-known-issues.md` |
| A decision with its rationale, a road not taken, a parked question | `10-decisions-log.md` |
| An **enforceable** pattern ("imports must…", "every handler shall…") | **neither — see below** |

`09-known-issues.md` is Tier 0 and loaded on every call; `10-decisions-log.md` is
on-demand (`start/references/memory-bank-brief.md` §1). Both are LIVE files —
dev-authored, never regenerated from the spec.

**An enforceable pattern is never a raw append.** It belongs in the
machine-checkable rules surface, and authoring one is `/ossify:doctor`'s
surface (`doctor/SKILL.md` §6). Record the referral in the close summary and
hand the pattern there; do not smuggle it into `09` as prose; a rule filed as a
caveat reads as advice and is enforced by nobody.

**Check before you write.** Check every precondition before the first write: each file you edit exists and each text you replace is there exactly once; each file you create does not exist yet. Give every check a message that names what failed. A script that asserts after it writes leaves the edit half-applied.

**Everything else in the bank is derived from the lean spec and is off limits.**
The apply (§7) refuses the **entire accepted set** if any item names a target
outside `09-known-issues.md` / `10-decisions-log.md` — no partial write, no
seeded empty file. That is a discipline, not a formality: choose the target
correctly, and fix the set before touching any file.

---

## 6. Surface the candidates — one numbered list, every entry tagged

Present the full candidate list to the user as a numbered list, and **every
entry's first line starts with the literal `[report]` or `[handoff]`**:

```text
1. [report] r1.s2.w1 - the duplicate-suffix scheme is now owned in two places.
2. [handoff] r1.s2.w3 - anchors were confirmed case-folding; recorded as a
   clarification mid-dispatch, never written down anywhere durable.
```

**The tag is a trust-calibration signal, not decoration.** A report-origin
candidate was written by the agent that had just finished the code and is
grounded in a diff; a handoff-origin one comes out of conversational context and
is likelier to be a half-remembered intention. The user is calibrating on that
difference when they accept or reject, so the tag is on the **first** line, where
it cannot be missed.

A candidate whose text carries a host-absolute path says so in the list, so the
user's edit can name the repo by key instead (`start/references/memory-bank-brief.md` §3).
Then consume the response per candidate: **accept**, **edit** (the user's text
wins verbatim), or **reject**. Do not argue a rejection back, and do not fold two
candidates into one to make the list shorter.

---

## 7. Apply the accepted set — one pass, and you are the writer

The harvest has no executable half. There is no `oss` verb here: you perform
the appends yourself, and the rules the deleted code enforced at rc 2 are now
yours to hold. Each accepted entry carries four things — its **source**
(`report`, `handoff` or `adoption`), its **source id** (the work-item id, the
handoff filename, or adoption's baseline — `r0 baseline <sha>`, one
`<repo>=<sha>` per declared repo when the adoption spans several), its
**target file**, and its **text** (verbatim; a §6 edit means the user's words,
not yours).

**Where the bank is — this paragraph is the only copy; other surfaces route
here.** Read the manifest — walk up from the cwd for `.ossify/topology.json`
first, then `.workspace/pairing.json` if no topology file is found (the same
order `oss_topology_discover` resolves through, `lib/manifest.sh`) — and take
`.well_known_paths.memory_bank`. The value
workspace-init writes is TOKEN form — `${ai_workspace.root}/.claude/memory-bank`
— and the route vocabulary is whatever `_oss_manifest_resolve` (lib/manifest.sh)
substitutes, stated as a rule rather than a list because the list grows with the
declaration: `${ai_workspace.root}`, **`${repos.<name>.root}` for every repo the
declaration names**, `${canonical.root}` as a legacy alias that resolves only
when a repo is actually named `canonical`, and `${HOME}` / `${USER}` from the
environment. Expand them before using the route; when the key is absent, the
bank is `<ai_workspace.root>/.claude/memory-bank` by convention. A route that is
relative, or that still carries a `${...}` token none of those rules cover (a
`${PLUGIN_DATA:...}`; a bare `${private_core.root}`, which has no legacy alias —
the addressable form is `${repos.private_core.root}`), is a **STOP**: surface it
and write nowhere. Never compose the route against your
own cwd — a cwd-composed path lands the writes in whichever repo you happen to
be standing in, reads as success, and the real memory bank is never touched.

**Validate the whole set before touching any file.** Every item must name an
allowlisted target (§5), a source that is exactly `report`, `handoff` or
`adoption`, a source id, and non-blank text. One bad item stops the whole set —
no partial apply, no seeding, nothing written until every item passes. Fix the
set (the target, usually) and apply the whole thing again; applying the valid
items first is how one refusal becomes N partial states.

**Seed a missing live file with its real structure, never a bare header.**
`09-known-issues.md` opens `# Known issues` with the section
`## Caveats and gotchas`; `10-decisions-log.md` opens `# Decisions log` with
`## Decisions`; both carry a note that they are live files — grown by the
harvest at every spine close, never regenerated from the spec. Never truncate
a file that already exists.

**Skip only the identical entry.** Before appending, read the target file. The
same text already sitting under a harvest trailer is a duplicate — a prior run
of this same harvest after a halt, or identical text from another source — so
skip it. The skip line names both the existing trailer's source and the
skipped candidate's source (`report`, `handoff` or `adoption`). Identity remains
text-only: append nothing for a duplicate, including no additional trailer or
adoption baseline. An entry that merely
*resembles* an existing one is a **new entry**: append it. Duplicates are
visible and cheap; a lesson silently dropped because it "looked like" another
is the exact failure this ceremony exists to prevent, and the user already
filtered the set in §6.

**Append**: a blank line, the text verbatim, then the provenance trailer:

```text
<!-- ossify harvest: <source-id>, <YYYY-MM-DD (UTC)>; source: report|handoff|adoption -->
```

**`adoption` is the third source, and it is `adopt`'s** (`adopt/SKILL.md` §C5):
the entries an adoption pass writes into the bank carry the baseline that pass
recorded — `r0 baseline <sha>`, or one `<repo>=<sha>` per declared repo when the
adoption spans several. `close` never writes this one, so a reader can tell an
adopted history from a harvested one without reading the entries themselves
(#301).

(Entries written before the conversion also carry an `h:<hash>` field in the
trailer. It fed the deleted byte-identity check; nothing reads it now. Leave
the old trailers alone and do not add it to new ones.)

**Report `wrote <N>, skipped <M>` in the close summary** — the write-side subset
of §8's four buckets (`applied` + `applied-with-edit` = wrote; identical-entry
skips = skipped). An all-skipped apply
is the honest answer that this spine's suggestions are already in the bank —
not a failure to fix by re-running. And apply the whole accepted set in one
sitting: interleaving appends with further accept/reject turns gives the user
N count lines to reconcile instead of one.

---

## 8. Record the outcomes — and where they go

Four buckets, one line each: **applied**, **applied-with-edit**,
**left-in-handoff** (a rejection that the user wants kept where it is), and
**dropped**.

**They go in the close summary — not in the retrospective.** The retro is
authored at **step 8** and is a completed artifact by the time this step
starts; nothing here reopens it. Writing outcomes "into the retrospective"
means editing a document the ceremony already finished, which is why this file
names the destination instead of leaving it to be inferred.

---

## 9. Anti-patterns

- **Cleaning up before the harvest.** Step 10 is terminal (§1).
- **Justifying that order with "the report is in the worktree".** It is not (§1).
- **Enumerating from the directory tree instead of from state**, or trusting
  `oss get`'s rc instead of its output (§2).
- **Re-globbing the spine directory per work item**, or `head -1`-ing an
  ambiguous glob instead of halting (§2).
- **Hunting for session handoffs.** They are not harvest inputs (§3).
- **Paraphrasing the `## 9.` heading** or accepting a renamed one (§4).
- **Appending an enforceable pattern as prose** instead of routing it to the
  machine-checkable rules surface (`doctor/SKILL.md` §6) (§5).
- **Naming any target outside the two live files.** The whole set stops
  before any write, and the fix is the target, not a retry (§5).
- **Dropping the `[report]` / `[handoff]` tag**, or moving it off the first line
  (§6).
- **Applying the set piecemeal**, or applying the valid items of a set that
  contains an invalid one (§7).
- **Treating an all-skipped apply as a failure to re-run** (§7).
- **Composing the bank route against the cwd**, or writing past an unresolved
  `${...}` token (§7).
- **Skipping an entry because it resembles one already in the bank** (§7) —
  only the identical entry is a duplicate.
- **Editing an accepted candidate's text on the user's behalf** (§6).
- **Recording the outcomes into the retrospective** authored at step 8 (§8).
