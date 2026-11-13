---
name: pairing-canonical-repo
description: Use when the user has an existing repo without AI scaffolding and wants to add an AI workspace alongside (Scenario A migration) — creates the sibling AI workspace and writes a manifest pointing at the existing canonical; does NOT modify the canonical except for installing the commit-msg hook.
---

# Skill — pairing-canonical-repo

## 1. Overview

This skill handles **Scenario A migration** (per **SPEC §9**): the user
already has a canonical repository (their production code, possibly with
years of history, remotes, branches) and wants to *pair* it with a brand-new
sibling AI workspace. Unlike `initializing-dual-repo-workspace` — which
creates BOTH repos from scratch — this skill creates ONLY the new AI
workspace; the existing canonical is left untouched except for one
intentional addition: a `commit-msg` git hook in `<canonical>/.git/hooks/`
that enforces the trace filter going forward. The canonical's working tree,
branches, remotes, `.gitignore`, and existing hooks (other than the one
`commit-msg`) are not modified. The skill auto-invokes on phrases like
"pair this repo with an AI workspace", "add AI workspace alongside",
"existing canonical needs scaffolding". It also runs via
`/pair-workspace <abs-path-to-canonical> [--ai-dir-name <dir>]`.

**Already have a populated AI workspace?** This skill creates a *fresh* AI
workspace. If your AI workspace already exists as a separate populated sibling
directory (memory-bank, specs, AGENTS.md or CLAUDE.md grown organically before you found the
plugins) and you only need a manifest to wire it up, use `pairing-existing-dual`
(`/pair-existing-dual <ai-workspace-abs> <canonical-abs>`, **Scenario C**)
instead — it preserves your existing content and never seeds or stubs.

## 2. Preconditions

Same as the fresh-init skill (`jq` on `$PATH`, `git` on `$PATH`, parent dir
exists + writable, project name regex `^[a-z0-9-]+$`), PLUS the
pair-with-specific checks below. If any fail, exit non-zero with a clear
error; do NOT start any tasks (per **SPEC §8.1**, **SPEC §13.3**).

- `command -v jq` and `command -v git` on PATH.
- `[[ -d "$parent" && -w "$parent" ]]` — parent dir for the NEW AI workspace.
- `[[ "$name" =~ ^[a-z0-9-]+$ ]]` — kebab-case project name.
- **Canonical path must be absolute.** Reject relative paths (`wi_realpath`
  can canonicalize, but require the user to pass absolute to avoid surprise).
- **Canonical path must exist.** `[[ -d "$canonical_root" ]]`.
- **Canonical must be a git repo.** `git -C "$canonical_root" rev-parse --git-dir >/dev/null 2>&1`.

## 3. Input collection

Inputs (prompt the user OR read from `$ARGUMENTS` for the slash command —
never positional `$1`/`$2` per the slash-command `$N` substitution bug; on
shim-less channels (`Skill()`, natural language) nothing exports `$ARGUMENTS`, so read the values
as literal tokens in the invocation/request text):

- **project name** (kebab-case). Often the user wants it to match the
  existing canonical's basename, but it doesn't have to.
- **parent dir for the NEW AI workspace** (default: `$PWD`; absolute path).
  This is where `<name>-ai/` will be created.
- **AI workspace dir name** (optional; only from `--ai-dir-name <dir>`, never
  prompted). It replaces the default `<name>-ai` — for example, to match the
  AI workspace's own remote name. Pass it through as typed — preflight refuses
  a name that is not a plain directory name, so do not rewrite it. Reject a
  duplicate `--ai-dir-name` or a missing/empty value with a usage error.
- **existing canonical absolute path** (required; supplied via `$ARGUMENTS`
  for `/pair-workspace`). This is where the user's existing repo lives.
- **project_type** — `personal` or `work` (per **SPEC §7.1** prompt:
  *"Is this a personal project or a work/company project?"*). Both
  enforce the trace filter; the distinction is a forward hook for v0.2.

Resolve to shell variables:

- `name="$resolved_name"`
- `parent="$resolved_parent"`
- `canonical_root="$resolved_canonical_abs"`
- `project_type="$resolved_project_type"`
- `ai_dir_name="$resolved_ai_dir_name"` — the `--ai-dir-name` value, or
  `${name}-ai` when the flag is absent
- `ai_root="${parent}/${ai_dir_name}"`

Resolve the `wi` dispatcher once and hold it in `wi_bin`: `wi_bin="$(command -v wi)"`
— the plugin loader puts `bin/` on `$PATH`. Every `wi` invocation below — and in this
skill's references — is `"$wi_bin"`. Then run the preflight against these values before
any task in §6:

```
"$wi_bin" skeleton_preflight "$parent" "$name" --pair-with "$canonical_root"
```

When `--ai-dir-name` was given, append `--ai-dir-name "$ai_dir_name"` to this
call and to the `skeleton_create_root_ai_only` call in §6.2; without the flag,
run both exactly as written. Preflight refuses an AI target that already
exists and, with the flag, a name that is not a plain directory name (it must
start with a letter or digit and use only letters, digits, `.`, `_` and `-`).
On a refusal nothing has been created; report it as printed and exit non-zero.

## 4. Abort-on-AI-scaffolding-marker check

Per **SPEC §9.4**, BEFORE creating anything, scan the existing canonical
for AI scaffolding markers. If ANY are present, the canonical was already
onboarded as a single-repo (Scenario B territory) and pair-with would
produce a confusing dual-repo state. Abort cleanly — nothing has been
created yet, so no rollback is needed.

Markers to check:

- `[[ -d "${canonical_root}/.claude/memory-bank" ]]`
- `[[ -f "${canonical_root}/MASTER-SPEC.md" ]]`
- `[[ -f "${canonical_root}/docs/MASTER-SPEC.md" ]]`
- `[[ -f "${canonical_root}/.claude/.onboarding-state.json" ]]`

If any are present, print this abort message (substitute the found markers):

```
ERROR: existing canonical already contains AI scaffolding.
Found markers in /abs/path/{name}:
  - .claude/memory-bank/
  - docs/MASTER-SPEC.md
Refusing to pair: this repo was already onboarded as a single-repo project.
Pairing now would create an inconsistent dual-repo state.

This is Scenario B (split existing single-repo into dual-repo), which
workspace-init does not yet automate. For now, the manual workaround is:
  1. Move .claude/memory-bank/, MASTER-SPEC.md (or docs/MASTER-SPEC.md),
     and any other scaffolding artifacts into a NEW sibling AI workspace
     directory of your choosing (e.g., <canonical>-ai/).
  2. Write the pairing manifest by hand at <ai-workspace>/.workspace/pairing.json
     using the v1.0 schema (see workspace-init SPEC §6.2).
  3. Re-run /pair-workspace once the canonical no longer has the markers.
```

Exit non-zero. Do NOT touch anything (no mkdirs, no manifest, no hook).

## 5. Detect canonical metadata

Detect default branch + remote from the existing repo via the `wi`
dispatcher (`workspace-init/bin/wi`; bash shebang forces a bash
runtime even when the calling shell is zsh), through the `wi_bin` resolved in §3. Per
**SPEC §8.4** the fallback chain is robust to oddly-configured repos:

- `detected_branch="$("$wi_bin" git_detect_default_branch "$canonical_root")"`
- `detected_remote="$("$wi_bin" git_detect_remote "$canonical_root")"`

Never `source` lib files directly from skill body — under zsh
`${BASH_SOURCE[0]}` is unset and the libs crash. Always go through `wi`.

`wi_git_detect_default_branch` tries (in order):
`git symbolic-ref refs/remotes/origin/HEAD` → `git symbolic-ref HEAD` →
`git branch --show-current` → interactive user prompt → ultimate fallback
`"main"`.

`wi_git_detect_remote` returns `origin`'s URL if set, else empty (manifest
records `null`).

## 6. Execute the modified 8 tasks

Same skeleton as `initializing-dual-repo-workspace` but with three
pair-with-specific differences (8.2, 8.4, 8.8). The helpers append their operation
entries to `${ai_root}/.workspace/init-log`. On ANY task failure,
call `"$wi_bin" rollback "${ai_root}/.workspace/init-log" --pair-with "$canonical_root"`
(the `--pair-with` flag tells rollback to skip ops against the existing
canonical — see section 7).

### 6.1 — Task 8.1: Input

Already collected in section 3. Reference `name`, `parent`, `canonical_root`,
`project_type`, `ai_root`.

### 6.2 — Task 8.2: Create root dir (AI ONLY)

**Difference vs. fresh mode:** the canonical already exists, so skip
`mkdir <canonical>`. Only create the new AI workspace:

```
"$wi_bin" skeleton_create_root_ai_only "$parent" "$name"
```

Expected init-log entries: `MKDIR <ai_root>` and `MKDIR <ai_root>/.workspace`. No canonical MKDIR entry.

### 6.3 — Task 8.3: Seed AI workspace subdirs + .gitignore

Same as fresh mode:

```
"$wi_bin" skeleton_seed_subdirs "$ai_root"
```

Expected init-log entries: MKDIR for subdirs and WRITE_FILE for `.gitkeep` files and `.gitignore`.

### 6.4 — Task 8.4: Write the pairing manifest (with detected metadata)

**Difference vs. fresh mode:** pass the detected default branch and remote
through to `wi_manifest_write`. The detected remote is the CANONICAL's — it
belongs to `--canonical-git-remote` (the AI workspace's own `git_remote` stays
`null`; nothing captures it at pair time):

```
if [[ -n "$detected_remote" ]]; then
  "$wi_bin" manifest_write "$ai_root" "$canonical_root" "$project_type" \
    --canonical-git-remote "$detected_remote" --default-branch "$detected_branch"
else
  "$wi_bin" manifest_write "$ai_root" "$canonical_root" "$project_type" \
    --default-branch "$detected_branch"
fi
```

If `$detected_remote` is empty the flag is omitted and the helper records
`null`. If `$detected_branch` is empty the write fails — re-run
`wi git_detect_default_branch` or pass an explicit branch name.

**Optional — tooling repo (#48 Stage 2).** If the user keeps a separate *tooling/marketplace*
repo (ossify's close boundary audit then scans it like any other declared repo), append
`--tooling-repo "$tooling_root"` (and `--tooling-repo-remote "$tooling_remote"` if known).
Only ask when the user volunteers one — omit the flags otherwise and the `tooling_repo` key
is left out entirely (today's behavior, unchanged).

No init-log entry is written for the manifest; rollback removes it with the logged AI root.

### 6.5 — Task 8.5: Write the AGENTS.md stub

Renders the one instruction file, `AGENTS.md`. Claude Code 2.1.277 or later
loads it when the workspace has no `CLAUDE.md`; an older Claude Code reads only
`CLAUDE.md` and sees none of it. Codex and OMP read it directly. Its first
line is the marker `<!-- workspace-init stub: ossify:start replaces this file -->`;
ossify 1.24.0 or later replaces a file that starts with it, with no question.
Continue into ossify 1.24.0 or later: on an older ossify, stop after pairing — do
not run `/ossify:start`, `/ossify:adopt` or the `doctor` repair until 1.24.0 is
installed. workspace-init writes no `CLAUDE.md`.

```
"$wi_bin" stub_agents_md "$ai_root" "$name"
```

Expected init-log entry: `WRITE_FILE <ai_root>/AGENTS.md`.

### 6.6 — Task 8.6: (merged into 6.5)

Since 0.10.0 the `AGENTS.md` stub is the only instruction file. There is no
separate `CLAUDE.md` task.

### 6.7 — Task 8.7: Write README.md

```
"$wi_bin" stub_readme "$ai_root" "$name"
```

Expected init-log entry: `WRITE_FILE <ai_root>/README.md`.

### 6.8 — Task 8.8: git init (AI ONLY) + hooks (BOTH) + stage (AI ONLY)

**Differences vs. fresh mode:**

1. **SKIP** `git init` in canonical — it's already a git repo. Initialize
   only the AI workspace:

   ```
   "$wi_bin" git_init_ai_only "$ai_root"
   ```

2. **DO** install the commit-msg hook in BOTH AI workspace and canonical
   (the trace filter must guard canonical commits going forward):

   ```
   "$wi_bin" trace_filter_install_pair "$ai_root" "$canonical_root"
   ```

3. **STAGE ONLY** in the AI workspace; do NOT run `git add` against the
   canonical (its working tree is the user's; we never touch it):

   ```
   "$wi_bin" git_stage_ai_workspace "$ai_root"
   ```

Expected init-log entries: `GIT_INIT <ai_root>` (no canonical GIT_INIT),
`HOOK_INSTALL <ai_root>`, `HOOK_INSTALL <canonical_root>`,
`GIT_STAGE <ai_root>`.

## 7. Rollback discipline

Per **SPEC §8.9 step 3**, rollback in pair-with mode **NEVER** undoes ops
on the existing canonical. Pass the `--pair-with "$canonical_root"` flag to
`"$wi_bin" rollback`; the helper then filters out ops whose target lies under
`$canonical_root` when walking the init-log in reverse.

**Pair-with-safe to reverse** (rollback DOES undo these):

- `mkdir <ai_root>` and all subdirs under it
- All file creations inside `<ai_root>` (manifest, stubs, .gitignore, .gitkeep)
- `git init` of `<ai_root>` (removes `<ai_root>/.git/`)
- `GIT_STAGE <ai_root>` (no inverse needed — discarding `<ai_root>` discards the index too)
- Hook install at `<ai_root>/.git/hooks/commit-msg` (removed with the dir)

**Pair-with-frozen** (rollback DOES NOT undo these):

- Hook install at `<canonical_root>/.git/hooks/commit-msg` — `wi_rollback`
  leaves this in place and prints a warning telling the user how to remove
  it manually (`rm <canonical_root>/.git/hooks/commit-msg`).

**Important nuance:** the canonical hook install IS technically reversible
in the immediate failure-mid-init sense (we just wrote the file; we know
its contents; we could `rm` it safely). But to be conservative — in case
the user or another tool relied on the file we overwrote, or in case the
hook was already running successfully and only a LATER task failed —
rollback adopts a leave-in-place policy. The warning surfaces the path so
the user can opt in to removal.

This conservatism is deliberate: a destructive rollback against the user's
existing canonical is a worse failure mode than a stale hook the user can
delete in one command.

## 8. Print next-steps

After all tasks succeed, print this message verbatim. First
substitute `{name}-ai` with the AI workspace directory name (`$ai_dir_name`),
then `{name}` and `/abs/path` with resolved values; everything else stays as written —
this is the pair-with variant of **SPEC §8.8**:

```
Pair-with bootstrap complete.

  AI workspace (new):     /abs/path/{name}-ai
  Canonical (existing):   /abs/path/{name}     (untouched except .git/hooks/commit-msg)

AI workspace has skeleton + manifest + stubs staged.
Canonical's commit-msg hook installed (blocks AI-trace patterns).
Canonical's working tree NOT modified.

Next steps:
  1. cd /abs/path/{name}-ai && git status
  2. git commit -m "workspace-init: initial bootstrap (pair-with)"
  3. cd /abs/path/{name}-ai && claude      # Claude Code; on Codex, run `codex` in that directory instead
  4. Continue into ossify: a canonical that carries product source at `HEAD` goes to
     `/ossify:adopt` (ossify 1.35.0 or later), with or without the legacy scaffold stack — it
     reads that stack's roadmap state, active-context cursor and legacy spec only when they
     exist. `/ossify:start` sends such a repository to adopt; for a canonical with no product
     source, history alone included on ossify 1.34.0 or later, `/ossify:start` onboards it; with no operator to answer, ossify 1.37.0 or later refuses a canonical with any file at `HEAD`. On Codex, invoke the corresponding ossify skill — `adopt`, or `start`.
     A canonical that holds a memory bank or `MASTER-SPEC.md` makes `/pair-workspace` abort; the
     plain route does not need it — make an AI workspace yourself (an empty directory, `git init`)
     and run `/ossify:adopt` there.
     On ossify 1.35.0 or later, adopt replaces the marked `AGENTS.md` stub, carrying its
     `## Git policy` and `## AI-trace filter` sections across. Continue into
     ossify 1.24.0 or later: on an older ossify, stop after pairing — do not run `/ossify:start`,
     `/ossify:adopt` or the `doctor` repair until 1.24.0 is installed.
  5. Before `/ossify:adopt`, every participating tree must be clean: adoption refuses while any
     tree it will edit carries an uncommitted or untracked line — the AI workspace, the canonical,
     and every other repo the topology declares — with each declared repo on the default branch
     the manifest declares. This skill never touches the canonical's working tree, so uncommitted
     work there is still there when the route runs.

Manifest at: /abs/path/{name}-ai/.workspace/pairing.json
Trace filter active in: /abs/path/{name}-ai  AND  /abs/path/{name}
To override trace filter for a specific commit: git commit --no-verify
```

## 9. Discipline rules

- **DO NOT auto-commit** anywhere — not in the new AI workspace, and
  certainly not in the existing canonical (which we never stage anyway).
- **DO NOT touch canonical's working tree.** No file creates, no
  `.gitignore` edits, no README updates. The ONLY canonical-side change
  is `<canonical>/.git/hooks/commit-msg`.
- **DO NOT add a `Co-Authored-By:` trailer or AI marker** anywhere.
- **DO NOT push, pull, or fetch** against canonical. The user may have
  uncommitted work, dirty branches, or pending pushes — staying read-only
  on canonical's history is non-negotiable.
- Cite **SPEC §7.4** and **SPEC §9.3** — pair-with mode explicitly
  preserves canonical's existing state.

## 10. Failure handling

- **Parent dir not writable / project name invalid / `--ai-dir-name`
  invalid** → preflight aborts; nothing created; no rollback needed.
- **Canonical path doesn't exist or isn't absolute** → preflight aborts.
- **Canonical isn't a git repo** → preflight aborts (per **SPEC §13.3**:
  fail, or — future enhancement — offer to `git init` it; today it just
  fails).
- **Canonical has AI scaffolding markers** → section 4 abort with
  Scenario B guidance. No rollback needed; nothing created.
- **`git symbolic-ref` returns nothing** → `wi_git_detect_default_branch`
  walks the fallback chain per **SPEC §8.4**: `refs/remotes/origin/HEAD`
  → `HEAD` → `branch --show-current` → interactive prompt → ultimate
  fallback `"main"`.
- **Manifest write fails mid-operation** → `wi_rollback ... --pair-with
  "$canonical_root"` cleans up the partial AI workspace; canonical
  untouched.
- **Hook install fails** (symlink loop, permissions, `chmod +x` failure)
  → `wi_rollback ... --pair-with "$canonical_root"`. The AI workspace
  side is removed; the canonical-side hook (if it was installed before
  the failure) is LEFT IN PLACE per section 7's conservatism, with a
  warning telling the user how to remove it.
- **`jq` produces malformed JSON** during manifest write → `wi_manifest_write`
  builds via `jq -n` into a tempfile and renames only on success, so a failed
  write leaves no partial manifest; on failure, rollback.
- **Canonical already has a `commit-msg` hook** → the trace-filter install
  refuses rather than overwriting a hook it did not install (hooks written by
  workspace-init carry a marker line and are replaced). Surface the refusal;
  the user decides whether to remove or chain their existing hook.
- **Concurrent invocation** against the same canonical →
  `wi_lock_acquire` on `<ai_root>` (locks the new workspace dir). A
  separate lock on canonical isn't taken — workspace-init does not own
  canonical and shouldn't lock it; the user's other tools may need
  access concurrently.
