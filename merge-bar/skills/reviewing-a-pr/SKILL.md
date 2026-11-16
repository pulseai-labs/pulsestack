---
name: reviewing-a-pr
description: Use when reviewing a PR, re-reviewing one after a fix push, or seated as a PR's reviewer — reports every defect as a class with every site in the repo, each sorted against the merge bar in the PR's own body, both axes (standards, and the Claim or spec) in parallel fresh-context subagents, coverage stated per file; round 2+ reviews only the fix diff plus each prior class's closure unless the bar or Claim changed. Reports only — never posts, commits, edits or checks out; writes only the report, and with `run` each axis writes only in its own subdirectory.
---

# Reviewing a pull request — classes against its merge bar

You review; you do not fix. The output is one report in the shape of `references/report.md`.
Two rules carry the design. **Every finding is a class with every site**: a review that names
one site of a pattern guarantees a later round that finds the rest. **Round 2 reviews only the
fix diff** unless the bar or Claim changed (§5): a fresh read of the whole PR each round
re-samples it. So round 1 carries the burden — whole diff, every class, every site.

You never post, commit, edit, push or check out; you write only the report; with `run`, each axis writes
only in its own subdirectory. The launcher prepared the checkout; the work-PR session posts the report.

**Inputs.** Each except `run` can come as a slash-command flag or be named in a brief:

| Input | Default |
|---|---|
| PR — number or URL | required |
| `round` | 1 |
| `previous` — the previous round's report, path or PR comment URL | none |
| `standards` — a standards file | found as in step 1 |
| `verifier` — the verifier's report for this PR | none |
| `head` — the SHA the checkout must equal | the PR's `headRefOid` |
| `body` — a file replacing the PR's body | the PR's current body |
| `run` — an existing scratch directory the launcher names | none (read only) |

## 1. Resolve the inputs

- **Body and head.** `gh pr view <PR> --json body,headRefOid,baseRefName,files` (OMP:
  `read pr://<owner>/<repo>/<N>` also works); `body` replaces the fetched body. `git rev-parse
  HEAD` must equal `head`, else `headRefOid`. A mismatch is the one stop: name both SHAs and
  that the launcher must prepare the checkout.
- **Diff.** `git merge-base HEAD origin/<baseRefName>`..`HEAD`. Round 2+: step 5.
- **Door** — the body's `## Merge danger` `Door:` line; none → `unstated (treated one-way)`.
- **Bar** — the body's `## Merge bar` and its raising line. None → the four conditions in
  `../opening-a-pr/references/pr-body.md`, and the header says `template (body has none)`.
  Conditions 1–4 are a floor: a body that drops or rewords one is judged by all four.
- **Standards** — `standards`; else `CODING_STANDARDS.md` at the paired AI workspace root (look
  next to this repo for a directory whose `.workspace/pairing.json` has `canonical.name` equal
  to this repo's name, or through `.ossify/topology.json`; match by name and location, never by
  its absolute `root` paths); no workspace matches → the repo root's. Several match, or no file
  → the header says `baseline only — <why, where you looked>`.
  `references/baseline-standards.md` applies in every case; another doc (a style guide, a
  README) is not the standards file.
- **Spec** — `verifier` → the Claim/Spec axis checks the Claim only and cites that report for
  the spec. No verifier report → the full Spec axis against the spec or plan the PR names (body,
  linked issue). A body with no Claim → check its stated intent (a summary, the issue), and say
  so.
- **Round 2+** — read `previous`, a path or a PR comment URL. A missing or unreadable file, or
  a URL with no such comment on the PR → step 5's fallback.

A missing input is a fallback the header names, never a refusal to review.

## 2. Two axes, in parallel, in fresh context

Dispatch both axes at once as fresh-context subagents (Agent tool on Claude Code, `task` on
OMP). Each gets the **whole** diff under review — never split by file — the resolved inputs,
steps 3–4, the Limits below, `run` if set, and its own instruction:

- **Standards:** does the diff meet the standards file and the baseline?
- **Claim/Spec:** is every Claim sentence true of the diff? With no verifier report, also: does
  the diff do what the spec or plan says, item by item — each item's result for the report's
  `## Spec` — and nothing outside Scope?

Each returns its classes in the report shape, every file of the diff marked `read` or `not read
— <why>`, and, with `run`, what it ran and what it showed. With no subagent tool, run the axes
one after the other, each from the diff, never from the other's findings.

**Merging.** A class both axes return is one entry, `Axis: Standards, Claim/Spec`, with the
union of their sites. Nothing else is reranked, dropped or downgraded across axes.

## 3. Every defect is a class

A defect is any point that holds — blocking or not, whoever raised it, whatever its label; one
that harms nothing the bar protects is still a class, sorted `non-blocking`. Only a point shown
false — the code does not do that — is left out, with one line after the classes saying why;
harmless is a sort, never a refutation. For each defect, name the
pattern and sweep the **whole repository** for it, not only the diff, by what the code or prose
does, not only by the first site's text: `ast_grep` for structure where available,
language-server references and diagnostics where available, `rg` always — a literal sweep is a
start, not the closure. Read each hit's whole passage end to end, and every sibling unit that
does the same job. The `Sweep:` line carries the search and its hit count; every hit is a site,
named with the defect at that site, or is counted out there with the reason (already guarded,
input refused upstream). A hit with a different defect is another class, or none — never a site
of this one. A line stating what the code should do — help text, a doc, a comment that agrees
with the Claim — is where the Rule comes from, never a site; the site is the code that breaks
it. Mark each site `in scope` or `outside scope` by the body's Scope; with no Scope, the diff's
paths are in scope. An outside-scope site is listed, not dropped — the work-PR session
dispositions it.

## 4. Sort each class against the bar

A class is blocking if and only if it meets a bar condition or the raising line. Name the
lowest-numbered condition met, then any others — `condition 1 (also 2)` — else
`non-blocking`. A severity word — P1, nit, critical, any reviewer's or author's — never decides.
Name the failure direction (`working-a-pr` §3): **refuses valid input** meets condition 1 on a
touched path; **correctly refuses unsupported input** is non-blocking at most; **admits what
it cannot handle** blocks when it corrupts or loses state; `n/a` otherwise.

## 5. Round 2 and later

Told the bar or Claim changed since the previous report, review the whole PR as round 1 against
the body now and say why in the header. Otherwise:

The diff under review is `<previous report's Head>..HEAD` — the fix diff. Then:

- **Closure.** Re-run each prior class's sweep on the current head: `Closes: C<n>`, or
  `Still open: <sites>`.
- **The fix diff** gets steps 3–4 like round 1. A new class takes the next free `C<n>`.
- **New mechanism.** A fix that adds behaviour rather than closing a class — a retry, a
  fallback, a new flag — is marked `New mechanism: yes — <what>`, so the work-PR session can
  cut it or split it out.
- **Extends.** A new class that is another case of the same mechanism as a class in the
  previous report (another spelling the parser misses, another input the matcher admits)
  carries `Extends: C<n>`.
- **Nothing else.** Every site of every class in the report is a line of the fix diff or a
  site of a prior class. A gap the fix leaves — new behaviour with no test — is pinned to the
  fix-diff lines that lack it, never to an untouched file; a point about code the fix diff did
  not touch is not this round's, true or not.

No previous report to read → run round 1 on the whole PR and say why in the header. Never
review a fix diff with no class list.

## 6. Write the report

Assemble it per `references/report.md`: the header, Coverage from both axes' returns, then the
classes, blocking first. A file an axis did not read is a stated gap, and nothing is called
clean over a gap. Write it to the report file the brief names, or return it.

## Limits

- No debugger. Without `run`, no running the program or its tests: a reviewer reads. With `run`
  (a directory outside any git repository, else git in the extract resolves to that repository),
  only inside it: each axis extracts the checkout's files, never its `.git`, into its own fresh
  subdirectory (`d=$(mktemp -d "<run>/axis.XXXXXX") && git -C <checkout> archive HEAD | tar -x -C "$d"`) and runs there,
  with `TMPDIR` and `HOME` set inside it — the PR body's Evidence test command or the documented
  test entry point, a reproduction of a finding, a mutation of the copy. A suite that needs a
  cold build is not run; the `Run:` header line says what ran, from the axes' returns.
- Naming `run` is the launcher's statement that the PR's code and Evidence command are trusted
  (not a fork or unknown author). The skill limits only the reviewer's own writes, not that
  code's: it can write anywhere through an absolute path, so the launcher must enforce the write
  boundary and any network limit; the skill cannot.
- A language server or check that builds obeys the host's build rules — reuse the project's
  existing build output, never start a cold build of your own.
- Never post, commit, edit, push or check out. You write only the report; with `run`, each axis
  writes only in its own subdirectory.
