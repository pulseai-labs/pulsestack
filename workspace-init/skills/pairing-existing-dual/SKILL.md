---
name: pairing-existing-dual
description: Use when the user says "pair my existing workspace", "wire up an existing AI workspace", "both repos already exist", or runs /pair-existing-dual (Scenario C, populated AI workspace and populated canonical) — writes the pairing manifest and installs the trace-filter commit-msg hook; never creates, seeds, stubs, or overwrites existing AI-workspace content.
---

# Skill — pairing-existing-dual

## 1. Overview

This skill handles **Scenario C** (per **SPEC §9** — the third pairing scenario, alongside Scenario A `pairing-canonical-repo` and the deferred Scenario B): **both repos already exist and are populated.** A project that pre-dates the plugins often grew a memory-bank, specs, and handoffs in a sibling AI-workspace directory before the user installed workspace-init and ossify. The canonical holds production code. Neither was created by workspace-init, and there is no pairing manifest tying them together yet.

This skill does the minimum to wire them up: it **writes the `.workspace/pairing.json` manifest** into the existing AI workspace and **installs the trace-filter `commit-msg` hook** (always in canonical; also in the AI workspace when it is itself a git repo). It does NOT create the AI workspace, seed its subdirectories, write AGENTS.md / README.md stubs, or seed a memory bank — that content already exists and is the user's. **Nothing under the existing AI workspace is overwritten.**

Auto-invokes on phrases like "pair my existing AI workspace", "both repos already exist, wire them up", "add a manifest to my existing dual-repo setup". Also runs via `/pair-existing-dual <ai-workspace-abs-path> <canonical-abs-path>`.

**Difference from Scenario A (`pairing-canonical-repo`):** Scenario A creates a *fresh* AI workspace and *aborts* if the canonical contains AI-scaffolding markers. Scenario C is the inverse — the AI workspace already exists and is *expected* to contain scaffolding markers; there is no abort, no creation, no seeding, no stubbing.

## 2. Preconditions

If any fail, exit non-zero with a clear error; do NOT write the manifest or install any hook.

Resolve the `wi` dispatcher once and hold it in `wi_bin`: `wi_bin="$(command -v wi)"` — the plugin loader puts `bin/` on `$PATH`. Every `wi` invocation below — and in this skill's references — is `"$wi_bin"`.

- `command -v jq` and `command -v git` on PATH.
- **AI workspace path absolute + exists + non-empty.** It is already populated; an empty or missing directory is the wrong target (or means the user wants Scenario A fresh-pair instead).
- **Canonical path absolute + exists + is a git repo.** `git -C "$canonical_root" rev-parse --git-dir`.
- AI workspace and canonical must be different paths (no self-pairing).

These are validated by `"$wi_bin" skeleton_preflight_existing_dual "$ai_root" "$canonical_root"` (lib/skeleton.sh) — call it through the `wi` dispatcher (`workspace-init/bin/wi`, the plugin loader puts `bin/` on `$PATH`); never `source` lib files from the skill body (under zsh `${BASH_SOURCE[0]}` is unset and the libs crash).

## 3. Input collection

For `/pair-existing-dual`, read the raw argument text after `Arguments:` in the
command prompt. For a direct skill invocation or a natural-language request,
read the value tokens from that invocation or request. Never use shell
positional parameters `\$1`/`\$2`.

Inputs (prompt when needed):

- **existing AI workspace absolute path** (already populated; first `/pair-existing-dual` arg).
- **existing canonical absolute path** (already a git repo; second `/pair-existing-dual` arg).
- **project_type** — `personal` or `work` (per **SPEC §7.1**: *"Is this a personal project or a work/company project?"*). Both enforce the trace filter; the distinction is a forward hook for v0.2.

Resolve to shell variables (canonicalize via `"$wi_bin" realpath` to avoid `/var` → `/private/var` surprises):

- `ai_root="$resolved_ai_abs"`
- `canonical_root="$resolved_canonical_abs"`
- `project_type="$resolved_project_type"`

There is **no `name` or `parent` input** — unlike Scenario A, both directories already exist, and the manifest derives `ai_workspace.name` / `canonical.name` from the existing directory basenames.

## 4. Preflight + detect existing scaffolding state (no abort)

```bash
"$wi_bin" skeleton_preflight_existing_dual "$ai_root" "$canonical_root" || exit 1
```

Then **detect and surface** the existing AI-workspace scaffolding so the user can confirm this is the right directory before anything is written. Scan for (and report which are present):

- `${ai_root}/.claude/memory-bank/` (and a count of files under it)
- `${ai_root}/docs/MASTER-SPEC.md` or `${ai_root}/MASTER-SPEC.md`
- `${ai_root}/AGENTS.md`
- `${ai_root}/CLAUDE.md`
- `${ai_root}/.claude/CLAUDE.md`
- `${ai_root}/docs/specs/` (and a count of spec files under it)

Unlike Scenario A's §4 marker check, this is **NOT an abort** — finding these markers is exactly what Scenario C expects. Log them as *"existing state to preserve"* and proceed.

If `${ai_root}/.workspace/pairing.json` already exists, the workspace is already paired — surface its current `canonical.root` and ask the user to confirm before overwriting (re-pairing is allowed, but never silently).

**Optional caution (not an abort):** if the *canonical* contains AI-scaffolding markers (`.claude/memory-bank/`, `MASTER-SPEC.md`), note that this looks like a single-repo (Scenario B) rather than a true dual-repo — ask the user to confirm the canonical path is correct before proceeding.

## 5. Detect canonical metadata

Detect the default branch + remote from the existing canonical via the `wi` dispatcher (per **SPEC §8.4** the fallback chain is robust to oddly-configured repos):

```bash
detected_branch="$("$wi_bin" git_detect_default_branch "$canonical_root")"
detected_remote="$("$wi_bin" git_detect_remote "$canonical_root")"
```

`wi_git_detect_default_branch` tries `git symbolic-ref refs/remotes/origin/HEAD` → `git symbolic-ref HEAD` → `git branch --show-current` → interactive prompt → ultimate fallback `"main"`. `wi_git_detect_remote` returns `origin`'s URL if set, else empty (manifest records `null`).

## 6. Write the manifest + install the hook(s)

Two operations only — both idempotent and non-destructive to existing AI-workspace content.

### 6.1 Write the pairing manifest

```bash
# Detect whether the existing AI workspace is an installable own git repo root
# (Scenario C is the only path where it may NOT be). Use the same predicate as
# `wi trace_filter_install`, so nested subdirs, bare repos, and linked worktrees
# record false while standard repos and separate-git-dir/submodule roots record true.
if "$wi_bin" trace_filter_is_installable_repo_root "$ai_root"; then
  ai_git_tracked=true
else
  ai_git_tracked=false
fi

if [[ -n "$detected_remote" ]]; then
  "$wi_bin" manifest_write "$ai_root" "$canonical_root" "$project_type" \
    --canonical-git-remote "$detected_remote" --default-branch "$detected_branch" \
    --ai-git-tracked "$ai_git_tracked"
else
  "$wi_bin" manifest_write "$ai_root" "$canonical_root" "$project_type" \
    --default-branch "$detected_branch" \
    --ai-git-tracked "$ai_git_tracked"
fi
```

`wi_manifest_write` creates `${ai_root}/.workspace/` if absent and writes `pairing.json` atomically (tmp-then-mv). It derives `ai_workspace.name` and `canonical.name` from the directory basenames, and writes the full routing / during_dev / well_known_paths / git_policy contract per the v1.0 schema (**SPEC §6.2**).

**Optional — tooling repo (#48 Stage 2).** If the user keeps a separate *tooling/marketplace* repo (ossify's close boundary audit then scans it like any other declared repo), append `--tooling-repo "$tooling_root"` (and `--tooling-repo-remote "$tooling_remote"` if known). Ask only when the user volunteers one; omit otherwise and the `tooling_repo` key is left out entirely (today's behavior, unchanged).

### 6.2 Install the trace-filter commit-msg hook(s)

The canonical hook is the load-bearing one (it guards the production repo's commits going forward). The AI-workspace hook is installed only when the AI workspace is itself a git repo:

```bash
"$wi_bin" trace_filter_install "$ai_root" "$canonical_root"          # canonical: always
if [[ "$ai_git_tracked" == true ]]; then
  "$wi_bin" trace_filter_install "$ai_root" "$ai_root"               # AI workspace: only if a git repo
fi
```

If the AI workspace is **not** a git repo, skip its hook and say so — do NOT `git init` the user's existing workspace (that's their call). Note in the summary that the AI-workspace trace filter can be added later by `git init`-ing it and re-running this skill. The manifest records the real `ai_workspace.git_tracked` value (`false` here) — `--ai-git-tracked` is threaded from §6.1's detection.

If either repo already has a `commit-msg` hook, the trace-filter install refuses rather than overwriting a hook it did not install — hooks written by workspace-init carry a `# workspace-init:managed-hook` marker (or the pre-0.5.1 auto-installed header) and are replaced; anything else, including a dangling symlink, is preserved byte-for-byte. Surface the refusal verbatim, leave the manifest and all user content in place, and tell the user the foreign hook was kept: they decide whether to remove it, chain it, or keep it and skip the filter for that repo. The deterministic retry after they move their hook aside is `"$wi_bin" trace_filter_install "$ai_root" <repo>` for that one repo.

## 7. What this skill does NOT do (the Scenario-C contract)

- **No `mkdir` of the AI workspace or canonical** — both already exist.
- **No `skeleton_seed_subdirs`** — the AI workspace already has its layout.
- **No `stub_agents_md` / `stub_readme`** — those files already exist and are the user's; overwriting them is the cardinal Scenario-C sin.
- **No memory-bank seed** — already populated.
- **No `git init` of either repo, no staging, no commit.**

The only filesystem writes are `${ai_root}/.workspace/pairing.json` (+ the `.workspace/` dir if absent), the init-log under `.workspace/`, and the `commit-msg` hook file(s).

## 8. Failure handling (conservative — never destructive)

Because the AI workspace is already populated with the user's content, this skill **never runs a destructive rollback** that could remove existing files. The footprint is tiny and both operations are idempotent:

- **Preflight fails** → nothing written; surface the specific failure (missing/empty AI workspace, canonical not a git repo, self-pairing) and stop.
- **Manifest write fails** → atomic write leaves no partial file; surface the error and stop. Re-running is safe.
- **Hook install fails** (permissions, symlink loop, `chmod +x`) → the manifest is already valid and stays in place; surface which hook failed and the manual remediation (`"$wi_bin" trace_filter_install` can be re-run, or the user can inspect `.git/hooks/`). Do NOT delete the manifest or any AI-workspace content.
- **Hook install refuses a foreign `commit-msg`** → the trace-filter install refuses rather than overwriting a hook it did not install; the foreign hook (even a dangling symlink) is preserved, and a symlinked `commit-msg` is never replaced whatever it points to. The manifest stays valid and in place; surface the refusal and let the user decide whether to remove or chain their hook — after they move it aside, `"$wi_bin" trace_filter_install "$ai_root" <repo>` retries that repo only.
- **`pairing.json` already present** → §4 surfaced it and got confirmation; the atomic write overwrites only that one file.

## 9. Surface summary + next steps

After the writes succeed, print a summary substituting resolved values:

```text
Existing dual-repo paired.

  AI workspace (existing):  /abs/path/<ai-workspace>   (content preserved — nothing seeded or overwritten)
  Canonical (existing):     /abs/path/<canonical>      (untouched except .git/hooks/commit-msg)

Preserved AI-workspace state:
  - memory-bank: <N> files
  - MASTER-SPEC.md: <present | absent>
  - specs: <M> files

Manifest written at: /abs/path/<ai-workspace>/.workspace/pairing.json
Trace filter active in: <canonical>  [AND <ai-workspace> if it is a git repo]

Next steps:
  1. Prepare the AI workspace for adoption: `cd /abs/path/<ai-workspace> && git status`, then
     commit the pairing changes — `.workspace/pairing.json` and the init-log beside it — so
     neither is left uncommitted or untracked. If it is not a git repo yet, `git init` it first
     (your call, not this skill's), re-run this skill so the manifest records the real
     `ai_workspace.git_tracked` value and the AI-side trace filter is installed (§6.2), then
     commit.
  2. Open the workspace in Claude/Codex; ossify resolves pairing.json as topology.
  3. Make `AGENTS.md` the workspace's one instruction file before you continue. ossify's interop
     check fails while `AGENTS.md` is missing or never names ossify — that is its `agents_md` check,
     and it is real. Claude Code loads `CLAUDE.md` and ignores `AGENTS.md` whenever both exist, so a
     leftover `CLAUDE.md` (root or `.claude/`) shadows this file until it is gone.
     - **ossify 1.24.0 or later:** run `/ossify:doctor` (on Codex or OMP, the `doctor` skill) and
       accept its interop repair. It moves or merges `CLAUDE.md` into `AGENTS.md` and shows you the
       result first; review and commit before step 4.
     - **An older ossify:** leave the leftover `CLAUDE.md` exactly where it is. Continue into
       ossify 1.24.0 or later: on an older ossify, stop after pairing — do not run `/ossify:start`,
       `/ossify:adopt` or the `doctor` repair until 1.24.0 is installed.
     This skill writes no project guidance.
  4. Run `/ossify:adopt` (ossify 1.35.0 or later) if the canonical carries product source at `HEAD`, with or
     without the legacy scaffold stack, or
     `/ossify:start` if the canonical has no product source (history alone is fine on ossify 1.34.0 or later; with no operator to answer, ossify 1.37.0 or later refuses a canonical with any file at `HEAD`); on Codex, invoke the corresponding ossify skill — `adopt`, or `start`.
     - **`/ossify:start` (no product source at `HEAD`):** on ossify 1.24.0 or later it replaces the marked
       `AGENTS.md`; it is the route that writes the one instruction file.
     - **`/ossify:adopt` (product source at `HEAD`):** on ossify 1.24.0 or later, adopt merges
       its loop section into `AGENTS.md`. Continue into ossify 1.24.0 or later: on an older ossify,
       stop after pairing — do not run `/ossify:start`, `/ossify:adopt` or the `doctor` repair
       until 1.24.0 is installed.
  5. Adoption refuses while any tree it will edit is dirty: the AI workspace, the canonical, and
     every repo the topology declares must all be clean — tracked and untracked — with each
     declared repo on the default branch the manifest declares (otherwise adoption names the
     checked-out branch and asks for confirmation before proceeding).
```

## 10. Discipline rules

- **NEVER overwrite existing AI-workspace files** (AGENTS.md, CLAUDE.md, README.md, memory-bank, specs). The only file this skill authors inside the AI workspace is `.workspace/pairing.json` (+ init-log).
- **NEVER touch the canonical working tree.** The ONLY canonical-side change is `<canonical>/.git/hooks/commit-msg`.
- **NEVER `git init` the user's existing AI workspace** — if it is not a git repo, skip its hook and note it; the user decides whether to make it one.
- **NEVER auto-commit, push, pull, or fetch** in either repo.
- **NEVER add a `Co-Authored-By:` trailer or AI marker** anywhere.
- Cite **SPEC §7.4** and **SPEC §9.3** — pairing preserves both repos' existing state.
