# Example: Pair with existing clean canonical

## Scenario

The user has an existing canonical repository at `/Users/example/projects/foo` — a regular git repo
with production code (src/, tests/, docs/) that has NO AI scaffolding. It's a work project with
remote history. The user now wants to add an AI workspace alongside it.

User runs `/pair-workspace /Users/example/projects/foo` from the home directory.

## Existing canonical state (before pairing)

```
/Users/example/projects/foo/
├── src/
│   ├── main.py
│   └── utils.py
├── tests/
│   └── test_main.py
├── docs/
│   ├── README.md
│   └── ARCHITECTURE.md
├── .gitignore
├── pyproject.toml
├── .git/
│   ├── refs/
│   ├── objects/
│   ├── hooks/
│   │   ├── pre-commit           # user's existing pre-commit hook
│   │   └── (no commit-msg hook yet)
│   ├── HEAD → refs/heads/main
│   └── config                   # has [remote "origin"] set to git@github.com:example/foo.git
└── (no .claude/, no MASTER-SPEC.md, no AI scaffolding)
```

## Prompts and user inputs

The skill prompts for three inputs:

```
What is your project name? (kebab-case, can differ from canonical basename)
foo

Parent directory for the NEW AI workspace? (default: /Users/example/projects)
(user presses Enter to confirm)

Is this a personal project or a work/company project?
work
```

The skill resolves:
- **name** = `foo`
- **parent** = `/Users/example/projects` (where the AI workspace will be created as foo-ai/)
- **canonical_root** = `/Users/example/projects/foo` (provided via $ARGUMENTS; absolute path required)
- **project_type** = `work`
- **ai_root** = `/Users/example/projects/foo-ai`

## Pre-flight checks

The skill verifies all fresh-mode preconditions PLUS pair-with-specific checks:

```
✓ jq command available
✓ git command available
✓ Parent directory /Users/example/projects exists and is writable
✓ Project name 'foo' matches kebab-case regex ^[a-z0-9-]+$
✓ Canonical path is absolute: /Users/example/projects/foo
✓ Canonical exists: /Users/example/projects/foo
✓ Canonical is a git repo: git -C /Users/example/projects/foo rev-parse --git-dir ✓
✓ No AI scaffolding markers found in canonical
  - .claude/memory-bank/ does not exist ✓
  - docs/MASTER-SPEC.md does not exist ✓
  - MASTER-SPEC.md does not exist ✓
  - .claude/.onboarding-state.json does not exist ✓
✓ AI workspace dir /Users/example/projects/foo-ai does not yet exist
```

## Canonical metadata detection

_Dispatcher invocations below are `"$wi_bin" …` — the calling skill resolves `wi_bin` once (`command -v wi`; the plugin loader puts `bin/` on `$PATH`); if it is unset in your context, resolve it that way first._

Before creating the AI workspace, the skill detects the canonical's git configuration:

```bash
detected_branch="$("$wi_bin" git_detect_default_branch "/Users/example/projects/foo")"
```

The fallback chain (per SPEC §8.4) executes:
1. Try `git symbolic-ref refs/remotes/origin/HEAD` → succeeds, returns `main`
2. (no need to try further fallbacks)

```bash
detected_remote="$("$wi_bin" git_detect_remote "/Users/example/projects/foo")"
```

Returns `git@github.com:example/foo.git` (from the origin remote in .git/config).

Both values are captured and will be written to the manifest.

## Modified 8-task execution

### Task 8.1: Input collection

Already done. Values: `name=foo`, `parent=/Users/example/projects`, `canonical_root=/Users/example/projects/foo`,
`project_type=work`, `ai_root=/Users/example/projects/foo-ai`.

### Task 8.2: Create root dir (AI ONLY)

**Difference from fresh mode:** skip creating canonical (it already exists).

```bash
"$wi_bin" skeleton_create_root_ai_only "/Users/example/projects" "foo"
```

Creates `/Users/example/projects/foo-ai/` and its `.workspace/` directory, which holds the init-log.

Init-log entries:

```
MKDIR	/Users/example/projects/foo-ai
MKDIR	/Users/example/projects/foo-ai/.workspace
```

No MKDIR entry is written for the existing canonical.

### Task 8.3: Seed AI workspace subdirs

Same as fresh mode:

```bash
"$wi_bin" skeleton_seed_subdirs "/Users/example/projects/foo-ai"
```

Creates `.workspace/`, `.claude/`, `docs/`, `docs/specs/`, `.superpowers/`, `.archive/` with `.gitkeep` files
and renders `.gitignore`.

### Task 8.4: Write pairing manifest

**Difference from fresh mode:** pass detected metadata to populate canonical fields:

```bash
"$wi_bin" manifest_write "/Users/example/projects/foo-ai" \
  "/Users/example/projects/foo" \
  "work" \
  --canonical-git-remote "git@github.com:example/foo.git" \
  --default-branch "main"
```

The detected remote is the CANONICAL's — it goes to `--canonical-git-remote`.
The AI workspace's own `git_remote` stays `null` (nothing captures it at pair
time). The manifest is written to
`/Users/example/projects/foo-ai/.workspace/pairing.json` with:
- `canonical.git_remote` = `"git@github.com:example/foo.git"`
- `canonical.default_branch` = `"main"`
- `git_policy.project_type` = `"work"`

### Tasks 8.5–8.7: Write stubs

Same as fresh mode: AGENTS.md, README.md.

### Task 8.8: Git init (AI ONLY) + hooks (BOTH) + stage (AI ONLY)

Three sub-steps:

1. **Init AI workspace only** (canonical already has .git):

   ```bash
   "$wi_bin" git_init_ai_only "/Users/example/projects/foo-ai"
   ```

   Init-log entry:

   ```
   GIT_INIT	/Users/example/projects/foo-ai
   ```

   No GIT_INIT entry is written for the existing canonical.

2. **Install commit-msg hook in BOTH repos:**

   ```bash
   "$wi_bin" trace_filter_install_pair "/Users/example/projects/foo-ai" "/Users/example/projects/foo"
   ```

   Renders the hook template (substituting the AI workspace reference — `self` for the
   workspace's own hook, `sibling:foo-ai` for the canonical's) and installs to:
   - `/Users/example/projects/foo-ai/.git/hooks/commit-msg` (executable)
   - `/Users/example/projects/foo/.git/hooks/commit-msg` (executable)

   The canonical-side hook finds the manifest beside its own repo at commit time, so the pair
   keeps its filter on any host where the two repos sit side by side.

   Init-log entries:

   ```
   HOOK_INSTALL	/Users/example/projects/foo
   HOOK_INSTALL	/Users/example/projects/foo-ai
   ```

3. **Stage AI workspace only:**

   ```bash
   "$wi_bin" git_stage_ai_workspace "/Users/example/projects/foo-ai"
   ```

   Runs `git -C /Users/example/projects/foo-ai add .` to stage all files.
   Does NOT touch canonical's working tree.

   Init-log entry:

   ```
   GIT_STAGE	/Users/example/projects/foo-ai
   ```

## Final state

### AI workspace

Newly created at `/Users/example/projects/foo-ai/` — it contains exactly:

- `.workspace/` — `.gitkeep`, `pairing.json` (manifest with detected canonical metadata), `init-log` (records bootstrap operations; manifest writing adds no entry)
- `.claude/.gitkeep`
- `docs/.gitkeep`, `docs/specs/.gitkeep`
- `.superpowers/.gitkeep`
- `.archive/.gitkeep`
- `AGENTS.md`, `README.md` — stubs
- `.gitignore` — rendered from template
- `.git/hooks/commit-msg` — trace filter (executable; not tracked by git)
- (all files staged, not committed)

Verify with `cd /Users/example/projects/foo-ai && git status`:

```
On branch main (new repo, no commits yet)

Changes to be committed:
  new file:   .claude/.gitkeep
  new file:   .superpowers/.gitkeep
  new file:   ...
  new file:   AGENTS.md
  new file:   README.md
  new file:   .gitignore
  new file:   .workspace/pairing.json
  ... (all skeleton files)
```

### Canonical (unchanged except for hook)

The canonical at `/Users/example/projects/foo/` is UNTOUCHED in its working tree:

```bash
$ cd /Users/example/projects/foo && git status
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

The ONLY new file in canonical is `.git/hooks/commit-msg` (the trace filter hook). This file is
not in the working tree; it's in `.git/hooks/` which is never tracked.

The user's existing pre-commit hook (if any) is left untouched.

### Manifest excerpt

The key fields in `/Users/example/projects/foo-ai/.workspace/pairing.json`:

```json
{
  "canonical": {
    "root": "/Users/example/projects/foo",
    "name": "foo",
    "git_tracked": true,
    "git_remote": "git@github.com:example/foo.git",
    "default_branch": "main"
  },
  "git_policy": {
    "project_type": "work",
    ...
  },
  ...
}
```

## Final next-steps message

After all tasks succeed, the skill prints:

```
Pair-with bootstrap complete.

  AI workspace (new):     /Users/example/projects/foo-ai
  Canonical (existing):   /Users/example/projects/foo     (untouched except .git/hooks/commit-msg)

AI workspace has skeleton + manifest + stubs staged.
Canonical's commit-msg hook installed (blocks AI-trace patterns).
Canonical's working tree NOT modified.

Next steps:
  1. cd /Users/example/projects/foo-ai && git status
  2. git commit -m "workspace-init: initial bootstrap (pair-with)"
  3. cd /Users/example/projects/foo-ai && claude      # Claude Code; on Codex, run `codex` in that directory instead
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

Manifest at: /Users/example/projects/foo-ai/.workspace/pairing.json
Trace filter active in: /Users/example/projects/foo-ai  AND  /Users/example/projects/foo
To override trace filter for a specific commit: git commit --no-verify
```

The user commits the AI workspace skeleton, launches Claude Code (or Codex) in the AI workspace, and continues into ossify as step 4 describes — adoption (ossify 1.35.0 or later) takes a canonical with product source, with or without the legacy scaffold stack, and it refuses any participating tree that is not clean.
The canonical repo's workflow is unaffected; the trace filter hook silently guards against AI-trace patterns in commits.
