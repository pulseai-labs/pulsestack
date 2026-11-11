# Composing a handoff — judgment, not gates

A handoff is the mechanism for continuing work in a fresh context. It is the
one capability that must work **everywhere** — any repo shape, any methodology
or none, mid-work when context runs out, not just at tidy boundaries. Nothing
in this ceremony blocks, validates, or rejects: quality comes from the
judgments below plus the read-out that surfaces the weakest part for a human.

The document's structure lives in `sections.md` (same directory). Read it
before writing. This file owns the judgments around the document: where it
goes, tracked or not, what enters it, and what gets said aloud.

## 1. Location — judged from evidence, stated in one line

Establish first whether this is a git repository at all. Without one, the
evidence below still chooses the *directory* (precedent, then a `docs/` tree,
then cwd), but tracked-vs-ignored and the commit are moot — say so in the same
line (failure table). In a git repo, in rough priority order:

1. **Does the repo already contain session handoffs anywhere?** The strongest
   signal. Match their directory, their naming, *and* their tracked/ignored
   status — precedent is a decision the project already made. Precedent means
   documents of this design's shape: a per-work-item execution artifact that
   happens to be named `handoff.md` (ossify's `work-<id>/handoff.md`, or any
   file whose content is a work order rather than session state) is NOT
   precedent, never a target to overwrite, and not a resume candidate.
2. **Monorepo with the work scoped to one package?** The package's own docs
   tree beats the root — scope decides before the generic tree does.
3. **Is there a `docs/` tree?** A `docs/handoffs/` (or the repo's nearest
   equivalent) is the natural home; tracked.
4. **What does `.gitignore` say** about documents of this class?

Pick, then state where and why in one line. Never ask, never configure — a
question about location is a question the evidence already answers.

## 2. Tracked vs gitignored — a first-class decision

A handoff that cannot be retrieved from another machine is a handoff you do
not have; the evidence base's founding case is a session reconstructed from a
committed handoff after its originating context became unresumable. Default:
follow the repo's precedent; absent precedent, **prefer tracked**, because the
failure mode of an uncommitted handoff is total. Whichever is chosen, state it
— a gitignored choice states the survivability tradeoff in the same breath.

**Committing follows the same precedent.** Where the repo tracks handoffs, the
ceremony includes the commit and says so; where precedent is untracked, write
and leave it. Never silent either way.

## 3. What enters the document — the reference-over-duplication test

Before anything enters §3 (Uncodified context), ask: *does a file already hold
this?* If yes it belongs in §4 as a pointer — path plus one line, never pasted
content. This single test is what keeps handoffs from bloating into
transcripts. Content that exists nowhere — conversational decisions, rejected
approaches, the thing you'd tell a colleague at the door — is what §3 is for.

For §2, the discipline is in `sections.md`: whole-claim-per-row, measured at
authoring time at the ref cited, unverifiable claims marked. Write §2 last so
every number is measured after the final edit, not before it. **Claims name
the pre-handoff ref**: the ceremony's own commit lands after measurement, so
rows that count commits or cite HEAD state the measured SHA (or say
"excluding this handoff's own commit") — a resume reading the handoff's
commit as drift is reading the ceremony, not the work.

## 4. The read-out — stated before writing, embedded after

State the read-out (template in `sections.md` §7) **in conversation before
writing the file**, blocking nothing. It is a preview the operator can react
to, not a gate. Then embed the same read-out as the document's final section.

**Never overwrite an existing handoff.** Before stating the read-out, check
the chosen name against the directory itself (`test -e`, not `git ls-files` —
an ignored file is in no index). If it is taken, use the next free name
(`sections.md`, file name), and say in the read-out's Location line that the
name was taken and which one was used.

`Weakest` is named honestly or the read-out is theater: a thin §3 on a trivial
handoff is correct; a thin §3 nobody noticed is how context dies. If the
operator gave no topic, the read-out is also where the derived topic is
surfaced.

## 5. Failure behaviour — degrade and report, never refuse

| Situation | Behaviour |
|---|---|
| Not a git repo | The location evidence still applies (precedent → docs tree → cwd); tracked and the commit are moot — say so |
| No precedent, no `docs/` tree | Repo root, say so |
| Ambiguous location | Pick, state the reasoning in one line |
| `.gitignore` absent or unclear | State the tracked/untracked choice made and why |
| Nothing uncodified to record | Lean §3 with one line saying why it is lean |
| Mid-work, tests red, branch dirty | Compose anyway — a handoff over a mess is the mess's map; §2 records the red honestly |

Every one of these is a case where the superseded v1 either hard-refused or
silently proceeded. Neither is acceptable; the replacement is identical in all
cases — judge, state in one line, continue.
