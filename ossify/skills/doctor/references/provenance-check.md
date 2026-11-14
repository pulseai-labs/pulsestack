# Provenance check

Depth for `doctor/SKILL.md` §13. This surface reads and reports; it has no
runtime verb and mutates nothing.

## 1. Resolve the three roles

**Answering binary.** Run `command -v oss`. Accept an identity only when the
result is an absolute executable path which, after symlink resolution, is the
`bin/oss` child of a readable plugin root. Read that root's
`.claude-plugin/plugin.json` for the version. A function, alias, relative path,
non-executable path, unexpected layout, unreadable manifest, or failed symlink
resolution makes this role unavailable. Never derive the version from a
cache-directory name; a cache-resident install is valid when its manifest is
read.

**Loaded doctor body.** Use the host-supplied skill base directory for this
invocation, or the concrete absolute Read-tool path that loaded this
`skills/doctor/SKILL.md`. Derive its owning plugin root from that known layout
and read the root manifest. If neither form of execution evidence exists, this
role is unavailable. Do not use the answering binary's root and do not expect
`${CLAUDE_PLUGIN_ROOT}` inside a Bash subprocess.

**Expected reference.** Resolve the current git worktree root from the absolute
working directory. If that root contains
`ossify/.claude-plugin/plugin.json`, the checkout is the selected authority:
an unreadable or invalid checkout manifest makes expected unavailable, and the
installed record is never a fallback. Otherwise, on Claude Code only, read
`~/.claude/plugins/installed_plugins.json` (under the configured Claude home)
and select records under `ossify@pulsestack` (on a host that has not moved yet, the
pre-rename key `ossify@claude-agent-scaffolding`; a record under the new key wins). A user-scope
record is applicable; a project/local record is applicable only when its
`projectPath` resolves to the current worktree root. Exactly one applicable
record must remain. It must supply `version` and a readable `installPath`, and
that root's manifest version must agree with the record. No candidate, multiple
candidates, an unreadable root, or record/manifest disagreement makes expected
unavailable.

On Codex only, when no checkout arm applies, read
`${CODEX_HOME:-~/.codex}/config.toml`. Unreadable or invalid config makes expected
unavailable. Exactly one `[plugins."ossify@<marketplace>"]` table with
`enabled = true` must exist; otherwise expected is unavailable. Use only that
marketplace, not a directory-discovered choice (currently `pulsestack-codex`;
a stale pre-rename cache is not authority). The reference root is the single
version directory under
`${CODEX_HOME:-~/.codex}/plugins/cache/<marketplace>/ossify/`; zero or several
directories make expected unavailable. Read its `.codex-plugin/plugin.json`
version as identity, never the directory name. Its `.claude-plugin/plugin.json`
must carry the same version; either manifest unreadable, invalid, or disagreeing
makes expected unavailable.

Print one line per role. A resolved line carries role, version, and path; an
unresolved line names the failed condition.

## 2. Classify detection

With all three roles resolved, compare each active version to expected:
matching is `ok`; either mismatch is `warn`. Any unresolved role makes the
surface `partial`. Preserve a binary/body disagreement as a warning inside a
partial result. Any disagreement between resolved roles — active-vs-expected
or active-vs-active, including inside a partial — is a mismatch for §3.
Version equality is the boundary: do not audit same-version content.

## 3. Inspect prior use only after mismatch

Read only execution evidence earlier than the current doctor invocation. Name
`oss` verbs from actual Bash calls. Collect ossify command wrappers,
`SKILL.md` bodies, and reference files from host loader metadata or actual Read
tool calls; a path merely mentioned in conversation is not evidence. Exclude
files loaded by the current doctor run.

For each evidenced prose file, identify its owning loaded plugin root, map its
relative path under the expected root, and report byte-identical, different,
absent from one side, or unverifiable. Do not enumerate directories or unused
skills. For prior verbs, report that they ran through the answering binary
under the detected disagreement — attribute the mismatch to no single role
when the active roles disagree or expected did not resolve; do not recursively
diff `bin/` or `lib/` and do not infer implementation impact. If history was
compacted or the expected root is unavailable, say the impact coverage is
`incomplete`: that label never changes the surface verdict and never
downgrades a detected warning.

## 4. Report the boundary and remedy

Do not update a plugin, alter PATH, restart a session, mutate project state,
certify completed work, or order a rerun. Name PATH repair when the binary is
wrong. Name plugin update plus a fresh session when the loaded body is stale.
When expected is unavailable, name only the failed condition: do not judge
which candidate is stale or prescribe a fix. Never tell the operator to rerun
doctor.
The operator judges completed work from the exposed verbs and targeted prose
deltas.

A pre-1.7.0 body cannot report this surface's absence; the guarantee begins
after one update and fresh session. A clean result describes the moment doctor
ran. Keep these limits in this reference and shipped README; do not repeat them
on every clean read-out.
