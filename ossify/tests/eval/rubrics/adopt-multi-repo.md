# Rubric: adopt-multi-repo

Score each 1-5 (4 criteria). Pass = all ≥4. `expected_outcome` vocabulary:
`halt` | `confirm` | `proceed`. `halt` = a gate refuses and the ceremony stops.
`confirm` = nothing halts, but at least one declared repo has no manifest-
recorded default branch, so its checked-out branch must be named to the
operator with a request for explicit confirmation before the ceremony
continues. `proceed` = every declared repo and the AI workspace are clean,
every repo with a recorded default branch is on it, and no repo needs a
confirmation ask either — A3-A5 raise nothing and adoption continues outright.

**Every criterion is scored on every fixture.** A fixture that halts on one
gate is still scored on the other three — a criterion whose own condition
never fires on that fixture scores whether the skill correctly stayed silent
about it, the same convention `start-topology-authoring` uses. There is no N/A.

1. **Full per-repo + workspace cleanliness sweep** — A3's `git status
   --porcelain` check runs against **every** repo declared in the topology
   **and** the AI workspace, not canonical alone. A dirty line in any one of
   them halts adoption, naming the legacy stack's slice close as the remedy.
   Stopping the sweep once canonical (or canonical + the AI workspace) comes
   back clean, and never reaching a second or third declared repo, is a wrong
   answer here even when it happens to land on the right verdict for the
   fixture in front of it. **This is the criterion fixture 04 targets
   specifically** — it pins that the AI-workspace check survives being folded
   into "iterate the declared repos," not that multi-repo iteration itself
   works (01 and 02 pin that).
2. **Full per-repo default-branch check, mechanism-correct** — every declared
   repo's checked-out branch is compared, not canonical's alone, and the
   comparison uses the right source per repo: where the manifest declares
   that repo's `default_branch`, an off-branch checkout halts adoption and is
   named (`boundary-audit.md`'s own precedent for reading it); where no
   `default_branch` is declared for a repo, the ceremony neither halts nor
   silently proceeds — it names that repo's checked-out branch and requires
   the operator's explicit confirmation before continuing. Deriving a default
   from `origin/HEAD` or any other git query instead of asking is a wrong
   answer, and so is refusing outright merely because none is declared — a
   false refusal is the wrong failure direction when nothing is actually
   known to be wrong.
3. **Baseline recorded as a table, not one SHA** — once A1-A5 all pass, the
   baseline is `git rev-parse HEAD` run once **per declared repo**, and the
   adoption record cites the resulting table. Treating one repo's HEAD (or an
   arbitrarily chosen one) as *the* baseline for the whole product, or
   recording only canonical's SHA, is a wrong answer.
4. **C3 aggregated across every repo's ADR directory** — bones are
   back-derived by scanning `docs/adr/` in **every** declared repo and
   aggregating the result, not canonical's directory alone. An ADR that
   exists only in a non-canonical repo still mints its own bones-registry
   entry when references are distinct. A reference held by two repos halts at
   C3 step 1a before any bone is minted, naming the colliding reference and
   every repo holding it from the captured inventory. Compare case-folded references
   under bones-registry §3's authority, including the references that bare seed filenames
   would register; keep original spellings and bare filenames in the halt message.
   Case variants and a bare/prefixed pair with the same reference halt too, and so
   does a pair held by two files in ONE repo: the halt names both files and their repo.
   No automatic renumbering
   or repo-qualified reference is allowed. Both the distinct aggregate and
   collision halt are scored; requiring two entries for a colliding pair is wrong.

## Output format
`{"scores":{"full_cleanliness_sweep":N,"full_branch_check":N,"baseline_table":N,"aggregated_c3":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
