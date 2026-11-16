# Rubric: reviewing-a-pr

Score each criterion 1–5 on every fixture. 4 = consistent; 5 = demonstrated. A criterion the
scenario does not exercise scores whether the output correctly did NOT do the thing.
Pass = all ≥ 4.

1. **class_complete** — one entry per defect class, never one per site: each class names its
   defect, the rule it breaks, the sweep that found its sites (the search, run over the whole
   repository and not only the diff, with its hit count), and every site that sweep finds — no
   site dropped, including every site in the whole passage the defect sits in and in its
   sibling units, not only the cited lines, and nothing listed that the class does not cover;
   each site line names the defect at that site, and a site whose defect differs is another
   class, never covered by this one; a site outside the PR's
   Scope is listed and marked `outside scope`, never left out because the diff does not touch
   it; a class with one site says it swept and found one; a class too large to list in full
   gives its total and how many are not shown — a capped list never reads as complete.
2. **bar_sorted** — each class names the bar condition it meets (`condition 1`–`condition 4`,
   or the body's raising line) or says `non-blocking`, decided by the condition and never by
   a severity word (P0–P3, "nit", "critical", any reviewer's or author's label); blocking
   classes come first; each class names its failure direction (`refuses valid input`,
   `correctly refuses unsupported input`, `admits what it cannot handle`, or `n/a`); with no
   Merge bar in the body, the template's four conditions are used and the header says so.
3. **coverage_stated** — the report lists every file in the diff under review (round 2+: the
   fix diff, unless it runs as round 1 after a changed bar or Claim) and, per axis, `read` or `not read — <why>`; a file not read is a stated gap, and
   no axis, file or report is called clean, approved or free of findings over a gap.
4. **round_scope** — round 1 reviews the whole PR diff. Round 2+ reviews only
   `<previous head>..HEAD` plus a closure check of every prior class (`Closes: <C-id>` or
   `Still open: <sites>`), reports defects the fix diff introduced, marks a fix that adds
   behaviour rather than closing a class `New mechanism: yes — <what>`, and reports nothing in
   code the fix diff did not touch beyond that closure check; when round 2+ is requested and
   no previous report can be read, or the reviewer is told the Merge bar or Claim changed since
   the previous report, it runs round 1 on the whole PR and the header says why —
   it never reviews a fix diff with no class list.
5. **inputs_resolved** — the header names every input and where it came from: PR, head SHA,
   round, Door (`unstated (treated one-way)` when the body has none), Standards (the file
   used — the `--standards` path, the paired AI workspace's `CODING_STANDARDS.md` found by
   repository name, or the repo root's — else `baseline only — <why>`), Bar (`body` or
   `template (body has none)`), Verifier report (its path, with the Claim/Spec axis narrowed
   to the Claim and citing the report, or `none (full Spec axis)` with the diff checked
   against the spec or plan the PR names); a missing input is a fallback the header states,
   never a refusal to review; the reviewer posts, commits, edits and checks out nothing, and
   runs code only when a `run` directory is named, only inside it (default: reads only).

## Output format
`{"scores":{"class_complete":N,"bar_sorted":N,"coverage_stated":N,"round_scope":N,"inputs_resolved":N},"pass":true|false,"notes":"<one sentence>"}`. JSON only.
