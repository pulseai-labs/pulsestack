# workspace-init changelog

## 0.10.7

Closes #834, #835 and #841.

### Fixed
- **Init-log dedupe compares exact fields at both sites.** The stub and skeleton log-once helpers compare OP and path as literal TSV fields, preserving backslashes and ignoring an optional detail field. Paths containing ERE metacharacters no longer produce duplicate entries or suppress a different path's entry.
- **The failure-and-rollback example shows a real run.** It uses a directory at README.md to force a write failure, shows the actual WRITE_FILE entries and summary tally, and no longer promises per-entry output. An existing regular README.md is overwritten, not refused; rollback output is unchanged.
- **A repo-level parity gate spans the AGENTS.md stub marker.** CI compares the template's first line with ossify's exact-first-line contract in §1a.

### Known limits
- A path containing a tab or newline still breaks the TSV init-log format. This patch does not add path validation or change the format.
- Rollback remains best-effort and emits warnings on failed inverse operations; the example's clean outcome is not a guarantee for every failure.

## 0.10.6

Routing prose follows ossify 1.37.0 (#1042). The fresh-bootstrap next steps and their example put adopt's replacement of a marked `AGENTS.md` stub under "ossify 1.24.0 or later"; it is from 1.35.0, and on 1.24.0-1.34.x adopt merges into the stub. A headless `/ossify:start` (no operator to answer) refuses a canonical with any file at `HEAD` from ossify 1.37.0 (#1040); every place that sends a canonical with no product source to `/ossify:start` now says so: both READMEs, both stubs, and the next steps of the three skills with their examples. Prose only.

## 0.10.5

The marketplace is renamed `pulsestack`; the OMP bin-path module it ships (`omp/bin-path.ts`, VERSION 2) reads installs under the new marketplace name `pulsestack` and, for one release, under the old `claude-agent-scaffolding`; an entry under the new name wins. The install key is `workspace-init@pulsestack`, and `ai-mentor` is `sage` in the README stub. No other change.

## 0.10.4 (2026-11-02)

Routing prose follows ossify 1.35.0.

### Changed
- **`/ossify:adopt` takes a canonical with product source and no legacy stack (#536).** The Scenario A and C next steps, the fresh-bootstrap block, both READMEs and the AGENTS and README stubs say: a canonical with product source at `HEAD` goes to `/ossify:adopt` (ossify 1.35.0 or later), with or without the legacy scaffold stack; with no product source, `/ossify:start`. The Scenario A text notes that `/pair-workspace` aborts when the canonical holds a memory bank or `MASTER-SPEC.md`, and that the plain route does not need it: make an AI workspace by hand and run `/ossify:adopt` there. The AGENTS.md stub's adopt line says adopt replaces the stub, carrying `## Git policy` and `## AI-trace filter` across.

## 0.10.3 (2026-11-02)

Routing prose follows ossify 1.34.0.

### Changed
- **`/ossify:start` takes a canonical with history but no product source (#809).** The Scenario A and C next steps, the fresh-bootstrap block, both READMEs and the AGENTS and README stubs say `/ossify:start` is for a canonical with no product source at `HEAD`, history alone included. A canonical with product source goes to `/ossify:adopt`, which today adopts only a project onboarded with the legacy scaffold stack (plain repos: #536).
- **The fresh-bootstrap next steps drop the tooling-repo line.** It said a recorded tooling repo with history refuses the `/ossify:start` route; ossify 1.19.4 (#553) stopped counting a declared tooling repo as product content.

## 0.10.2 (2026-11-02)

The bootstrapped README no longer lists the retired architect-critic plugin.

### Changed
- `templates/README.md.tmpl` drops its `architect-critic` line from "Plugins involved"; the plugin is retired from the marketplace. A workspace bootstrapped before this release keeps the line it was rendered with.
- `lib/manifest.sh` comments and two `tests/test-manifest.sh` fixtures name `ai-mentor` where they named the retired plugin. No behaviour change.

## 0.10.1 (2026-10-29)

The commit-msg hook finds the manifest from the repo it runs in (#983).

### Fixed
- **#983 — the hook no longer depends on an absolute path valid on one host.** It baked the AI workspace's absolute path at install, so a pair carried to another host (the #951 pilot, installed on the MacBook and run on Linux) named a path that did not exist there. Hooks from before 0.5.1 then printed `trace filter disabled` and let every commit through; hooks from 0.5.1 to 0.10.0 blocked every commit. The installer now records a reference: `self` for the AI workspace's own hook, `sibling:<dir>` for a canonical whose AI workspace sits beside it, and `abs:<path>` only for a pair that is neither, or for a repo whose `.git` is a file. The hook resolves `self` and `sibling` from its repository's main worktree, the parent of `git rev-parse --git-common-dir`, so the pair keeps its filter wherever the two repos move together, linked worktrees included. Every pair `/init-workspace` creates is side by side, and so is every `/pair-workspace` pair whose AI workspace takes the default parent. The installer bakes `self` or `sibling` only when the target's physical common git dir is exactly `<target>/.git`, the same test the hook's resolution relies on. A `.git` file, a `.git` symlink, or a `.git` directory belonging to another parent therefore gets `abs:`, and the README's "re-run the install" remedy cannot loop (review C1, C5). Every `cd` in `hooks/` and `lib/` clears `CDPATH`, so an exported `CDPATH` can neither redirect the hook's relative `.git` nor add a line to a captured path (review C2). Skill-first: the hook and installer code is question 2 (a reference the plugin mints, one git command with fixed arguments), and the hook as a whole is question 3 (it can only block).
- **It still fails closed, and now names an escape.** A reference it cannot resolve, a workspace that is gone and a missing manifest each block the commit with the reason, as before. Each block now also names `WI_TRACE_FILTER_MANIFEST`: set it to the manifest's path for one commit and the hook reads that manifest and still runs every check, announcing the override on stderr. `--no-verify` remains, and switches the filter off. Closed rather than loud because a trailer that reaches public history cannot be taken back, while a blocked commit costs one repair command; the escape keeps that cost to one environment variable.
- **The repair rewrites old hooks.** `wi trace_filter_install_pair <ai-workspace> <canonical>` already replaced a hook carrying the managed marker or the pre-0.5.1 header; it now writes the reference form over both. Installed hooks are not touched until it runs. There is no `/init-workspace --repair`. The old fail-open warning named it, and no release has shipped it.
- **The stubs name the canonical instead of locating it.** `AGENTS.md` and `README.md` rendered `canonical.root`, an absolute path, into the workspace's instruction file. They now render `canonical.name` and point at `canonical.root` in `.workspace/pairing.json`.

### Tests
- New `tests/test-hook-portable.sh` (11 tests) runs the installed hook through real `git commit` in fixture repos where the install-time path is gone: a pair moved to another parent, from both repos and a linked worktree; a legacy fail-open hook carrying a dead path, rewritten by the repair; a missing workspace and a missing manifest failing closed and naming the escape; the escape still blocking a trailer; the `abs:` form for a pair that is not side by side; a `.git` turned into a file; an unrecognised reference; a symlinked `.git`, where the re-install remedy clears the block; an exported `CDPATH` holding a `.git`, through install, commit and `wi_realpath`; a `.git` belonging to another parent. Each new assertion was mutation-tested with `tests/lib/mutate.sh` (21 mutants on the hook, installer and `wi_realpath`, all killed).
- `test_K1`, `test_PK1`, `test_F3`, `test_M1`, `test_H5`, `test_Q5` and `test_Q6` assert the baked reference rather than an absolute path. `test_E8` and `test_SC9` track the renamed placeholder. `test_A1`, `test_A6` and `test_R1` assert that the stubs name the canonical and contain no fixture path. Against the 0.10.0 renderer and templates those three fail.
- Plugin suite: 13 files, 330 passed, 0 failed (319 before this release).

## 0.10.0 (2026-10-16)

One instruction file: AGENTS.md.

### Changed
- **#768 — the two stub files fold into one `AGENTS.md`.** `templates/AGENTS.md.stub.tmpl` takes the content the two stubs carried — the topology and pairing manifest, the git policy and its one-line AI-trace rule from the old `AGENTS.md` stub, and the `## AI-trace filter` section plus the canonical-and-ossify continuation sections from the old `CLAUDE.md` stub. It renders `${PROJECT_NAME}` **and** `${CANONICAL_ROOT}`, and its **first line** is exactly `<!-- workspace-init stub: ossify:start replaces this file -->`. OMP, Codex and other agents read `AGENTS.md`; Claude Code **2.1.277 or later** loads it as project instructions when no `CLAUDE.md` exists, and an older Claude Code reads only `CLAUDE.md` and sees none of it — the fallback shipped in 2.1.277. A workspace therefore has one instruction file, not a `CLAUDE.md` that three of four agents cannot see. Task 8.5 and Task 8.6 of `initializing-dual-repo-workspace` become one step, and the two pairing skills follow.
- **`wi stub_claude_md` and `templates/CLAUDE.md.stub.tmpl` are removed.** `wi stub_agents_md` and `wi stub_readme` are the stub verbs; calling the retired one is an unknown-function error, not a silent no-op. No path writes a `CLAUDE.md` any more.
- **A legacy `CLAUDE.md` is detected, preserved and routed, never written.** `pairing-existing-dual` scans `${ai_root}/AGENTS.md`, `${ai_root}/CLAUDE.md` and `${ai_root}/.claude/CLAUDE.md` when it detects existing AI scaffolding, so a workspace that predates 0.10.0 still counts as populated and its file is not clobbered; its pointer paragraph in `pairing-canonical-repo` §1 names "`AGENTS.md` or `CLAUDE.md` grown organically" as the signal to use `pairing-existing-dual` rather than a fresh pair. `pairing-canonical-repo`'s §4 abort list is unchanged and names neither file — it tests the canonical for `.claude/memory-bank/`, `MASTER-SPEC.md`, `docs/MASTER-SPEC.md` and `.claude/.onboarding-state.json`. `pairing-existing-dual`'s next steps send a leftover `CLAUDE.md` to `/ossify:doctor`'s interop repair on ossify 1.24.0 or later; on an older ossify the file stays where it is, and the route stops after pairing.
- **#768 — 0.10.0 continues into ossify 1.24.0 or later only.** Every stub, skill, example and printed block names 1.24.0 or later for the marker replacement, the adopt destination and the `doctor` interop repair. On an older ossify the route stops after pairing: no `/ossify:start`, `/ossify:adopt` or `doctor` repair, and no by-hand `CLAUDE.md` merge — that instruction is gone, because shipped 1.23.0's adopt merges into `CLAUDE.md` and refuses a workspace whose file step 3 removed, so a hand-merge route would break the very project it claims to help. This narrows what 0.10.0 says; nothing about 1.24.0's own behaviour changed.

### Tests
- `test_A4_no_claude_md_written` and `test_A5_dispatcher_path_renders_marker` (`test-stubs.sh`) — no `CLAUDE.md` on any path, `wi_stub_claude_md` undefined in the sourced lib and refused by the dispatcher, and the marker rendered through `bin/wi` under `set -euo pipefail` (sourcing the lib does not reproduce that). `test_A1` now asserts the marker is line 1, `${CANONICAL_ROOT}` is substituted, the trace-filter text is present and no `Read \`CLAUDE.md\`` pointer survives.
- `test_H6_no_claude_md` (`test-init-fresh.sh`) and the Scenario A guard in `test-pair-with-existing.sh` — the fresh and pairing pipelines write no `CLAUDE.md`.
- `test_no_claude_md_stub_on_any_surface` and `test_existing_dual_scans_both_instruction_files` (`test-skills-pressure.sh`) — no skill, example, template or README names a `CLAUDE.md` stub or the retired verb, with a positive control that both skills still name `stub_agents_md`; and Scenario C names both instruction files in its scan list and routes the leftover to `/ossify:doctor`.
- Plugin suite 12 files / 319 passed / 0 failed (306 before this release). Independent verification: Tasks 1 and 2 each mutation-tested against a disposable worktree (V1 7/7, V2 8/8).
- The root catalog row's version is read from `.claude-plugin/plugin.json` by the pressure test and asserted there, so a bump that misses the row fails the suite instead of shipping a stale literal.

## 0.9.0 (2026-10-15)

Choose the AI workspace's directory name; the launcher step names Codex too.

### Added
- **#174 — `--ai-dir-name <dir>`** on `/init-workspace` and `/pair-workspace` names the AI workspace directory in place of `<name>-ai`, so a workspace whose own remote has another name need not keep a mismatched directory. `wi skeleton_preflight`, `wi skeleton_create_root_pair` and `wi skeleton_create_root_ai_only` take the flag. The name must start with a letter or digit and use only letters, digits, `.`, `_` and `-`; anything else — empty, `.`, `..`, a `/`, a leading `-` — is refused, never rewritten, as are a missing value and a repeated flag. Fresh mode also refuses a name equal to the project name (compared without case, for case-insensitive filesystems), which would put both repos in one directory. The manifest records the chosen name as `ai_workspace.name`, and rollback removes that directory. Without the flag every helper behaves exactly as before. The Scenario A skill now names the `skeleton_preflight --pair-with` call its failure list already relied on. `pairing-existing-dual` is unchanged: it pairs two directories that already exist.

### Fixed
- **#538 — the fresh and Scenario A next-steps no longer tell a Codex user to launch `claude`.** The launcher step names both CLIs, and the Scenario A route names the Codex skill form (`adopt`, or `start`) as the fresh and Scenario C blocks already did. The two examples mirror both blocks.
- **`wi skeleton_create_root_pair` and `wi skeleton_create_root_ai_only` refuse a root that already exists.** They used `mkdir -p`, so an existing AI or canonical root was logged as `MKDIR` and a later rollback ran `rm -rf` on it. They now use plain `mkdir` for the roots; the `.workspace` subdir and the init-log lines of a fresh run are unchanged.
- **The Scenario A skill resolves `wi_bin` before its preflight call**, so a run that follows the skill in order no longer calls an empty dispatcher path.
- **#146 (this plugin's README)** — the Pointers section no longer links to `../docs/SPEC-workspace-init.md` and `../docs/PLAN-workspace-init.md`, which never ship; it points at the plugin's own `skills/` and `lib/`.

### Tests
- New `tests/test-ai-dir-name.sh` (17 tests): the no-flag control, the override through preflight, both create helpers and the manifest, each refusal, rollback of the custom directory, and the `bin/wi` dispatcher path under `set -euo pipefail`.
- `test-skills-pressure.sh` adds three checks: both launcher steps and their example mirrors name Codex, the flag reaches both skills and both commands, and the README carries no `../docs/` link.

## 0.8.0 (2026-10-11)

OMP marketplace surface.

### Changed
- Wrappers name the skill by `skill://` path as well as `${CLAUDE_PLUGIN_ROOT}`; skill descriptions lead with the trigger ("Use when ...") so OMP's skill match fires; Claude Code tool names carry an OMP alias where a skill names one; the README gains an OMP note.

### Added
- **`omp/bin-path.ts`** — puts the plugin's `bin/` (`wi`) on `PATH` for OMP sessions, which have no plugin `bin/` mechanism. A byte-identical copy of the marketplace's source at `omp/bin-path.ts`; the user-level loader imports the newest installed copy.

## 0.7.3 (2026-10-11)

The scaffold stack (`scaffold-onboard`, `scaffold-dev`, `scaffold`) left the marketplace.

### Changed
- **The optional tooling repo no longer promises `/defer --tooling`.** That command was `scaffold-dev`'s. The three pairing skills and `templates/pairing.json.tmpl` now give the key's surviving use: ossify reads `tooling_repo` as a declared repo, and its close boundary audit scans it. The `tooling_repo` schema is unchanged; retiring the other scaffold-only pairing keys is #521.
- `lib/manifest.sh` comments no longer name the removed plugins as present consumers.

### Tests
- `test-skills-pressure.sh` adds `/defer` to `_retired_route_patterns` and checks the root README row for it, and the README overview check asserts the retired chain is absent.

## 0.7.2 (2026-10-11)

Devin is no longer a surface.

### Removed
- **`rules/dispatcher-path.md`** (Devin-only). The skills resolve `wi` with `command -v wi`.
- **The Devin next-steps line** in the fresh-bootstrap summary and its example mirror, and the Devin arms of the dispatcher and `$ARGUMENTS` notes.
- **`.devin-plugin/`.**

## 0.7.1 (2026-09-27)

The four `pairing.json` gaps deferred from the 0.7.0 review (#582). None were introduced by 0.7.0; the validator never checked these values, and two writers still used the predictable temp name 0.7.0 removed from `manifest_relocate`.

### Fixed
- **#582 — `wi_manifest_validate` rejects values a consumer cannot use.** It already checked each required field's type; it now also checks that the value is usable, and names every field that is not:
  - **`well_known_paths` entries must be absolute path templates**, as the README documents them. The block is optional, but consumers read a present value as a path (scaffold-onboard reads `roadmap_state` with `jq -r`), so `{"bad": true}` used to validate and be rendered as a filesystem path. Each entry must now be a non-empty string that starts with `/` or with `${ai_workspace.root}`, `${canonical.root}`, `${HOME}` or `${PLUGIN_DATA:<name>}`, and leaves no `${` behind once those and `${USER}` are substituted. A relative value would resolve against whatever directory its reader runs in, and any other or unterminated `${` would reach the consumer unresolved. A plain absolute path, one through `..`, and a leading placeholder with a suffix (`${HOME}.cache/…`) are all still valid. The block itself, when present, must be an object (or `null`).
  - **`routing` selectors must be `ai_workspace` or `canonical`**, the two roots `wi_manifest_resolve` knows. `routing.prd = "elsewhere"` used to validate, and scaffold-onboard then used `${elsewhere.root}/PRD.md`, unresolved, as a destination. Only the values are checked; `routing`'s keys and shape are unchanged.
  - **Roots, names and `canonical.default_branch` must be non-empty**, as must `tooling_repo.root` and `tooling_repo.name` when `tooling_repo` is present. An empty `canonical.root` used to validate, `manifest_relocate` accepted it, and consumers then read it as missing and left `${canonical.root}` unresolved.
  - **`ai_workspace.root`, `canonical.root` and `tooling_repo.root` must be absolute paths.** Every `well_known_paths` template built on `${ai_workspace.root}` or `${canonical.root}` is absolute only if the root is, and scaffold-dev `cd`s into `tooling_repo.root`; a relative root resolved against whatever directory its reader ran in.

  `manifest_relocate` runs the same validator, so it refuses these manifests too, changing nothing.
- **#582 — the three tmp-then-rename writers can no longer be redirected through a symlink.** `wi_manifest_write` and `wi_trace_filter_install` wrote to `<target>.tmp.<pid>` with a plain redirect, so anyone able to write the directory could plant a symlink there first: the redirect followed it, overwriting its target, and the rename installed the result. `manifest_relocate` had used `mktemp` since 0.7.0, but a random name only makes the symlink harder to place: the file was created by name and then written by name (`cp -p`, a redirect), so a watcher of the directory could swap it for a symlink in between. All three now pick an unused random name, create the file there with `O_EXCL` (bash's `noclobber`), which refuses any existing entry including a symlink, refuse anything but a regular file, and write only through that one descriptor. The mode is set at creation, so the installed file keeps the mode it had before: `pairing.json` from `manifest_write` is 0666 less the umask, a relocated `pairing.json` keeps its own mode (0600 and read-only 0444 included), and the hook adds `+x`. A redirect cannot create an execute bit, so the hook's `+x`, and any execute bit a relocated manifest had, are added by a `chmod` afterwards. That is the one step that still names the path, since bash has no `fchmod`; a swap at that moment can change the link target's mode but cannot write to it.
- **`wi_manifest_write` records a relative root as an absolute path**, anchored at the caller's directory as `manifest_relocate` already does. An absolute root is recorded exactly as given. An empty canonical root is refused instead of being written as `""` with success reported.

### Compatibility
- A hand-edited `pairing.json` carrying an empty required string, a relative root, a routing selector other than the two roots, or a `well_known_paths` entry that is not an absolute path template now fails `wi manifest_validate` (and `manifest_relocate`) with the field named. Manifests written by workspace-init with absolute roots, which every skill passes, are unaffected; one written from a relative root argument by an earlier version fails until its roots are absolute. `manifest_relocate` refuses it like any invalid manifest, so set `ai_workspace.root` and `canonical.root` to absolute paths by hand, or rewrite it with `wi manifest_write` as README → Repair describes. The commit-msg hook does not run the validator, so commits are not blocked meanwhile.

## 0.7.0 (2026-09-24)

The six workspace-init issues deferred from the 0.5.1 cycle (#482, #488, #490, #491, #492, #493): the dispatched default-branch probe no longer aborts, both hook installers validate the AI root before writing, a symlinked hook is never replaced, the moved-workspace repair can rewrite the manifest's recorded roots, and an empty blocked pattern fails closed.

### Added
- **#491 — `wi manifest_relocate <ai-root> [--canonical-root PATH]`** completes the moved-workspace repair. Re-baking the hooks restored the filter but left `pairing.json` naming the old `ai_workspace.root`, so consumers resolving paths through `wi_manifest_resolve` read a stale location. The new verb rewrites `ai_workspace.root`/`name` (and, only with the flag, `canonical.root`/`name`) to absolute physical paths and carries every other field through unchanged — `project_type`, remotes, `default_branch`, a customised `git_policy`, `tooling_repo`, `created_at`. It refuses, changing nothing, on a missing or corrupt manifest (it runs the full `wi_manifest_validate` schema check first) or a root that is not a directory, writes atomically, and adds no init-log entry. The README's Repair section runs it after the hook re-bake.

### Fixed
- **#482 — `wi git_detect_default_branch` no longer exits 128 through the dispatcher.** On a canonical with an `origin` remote but no `origin/HEAD` (a plain `git init` + `git remote add`, which is where a Scenario A pairing starts), step 1's failing `git symbolic-ref` aborted the function under `set -euo pipefail` before the documented fallbacks ran. Every probe's expected failure is now absorbed and the chain moves on; dispatcher-path tests cover no-`origin/HEAD`, `origin/HEAD` set, and a non-repo.
- **#492 — the single-target `wi trace_filter_install` validates the AI root before any write.** It now applies the pair installer's check (the directory exists and holds a `pairing.json` that is a single JSON object) through one shared validator, so a mistyped root fails instead of baking a dead path into the hook, creating `<typo>/.workspace`, and returning success.
- **#490 — a symlinked `commit-msg` is never replaced.** A valid symlink whose target is a copy of our hook read as ours through the link, and the install moved a regular file over it, dropping the user's link. The install now refuses any symlink — dangling or valid — naming its target, and `wi_rollback`'s HOOK_INSTALL inverse leaves any symlink in place.
- **#493 — an empty-string entry in `blocked_patterns` fails closed.** `[""]` used to read as allow-all, and so did an entry containing a line break (`["\n"]`), which collapses into empty records when the patterns travel one per line. The hook now blocks and names either; an explicit `[]` or `enforce: false` remain the ways to allow everything. Hooks installed before 0.7.0 keep the old behaviour until re-baked with `wi trace_filter_install_pair`. The README Repair section's read-first probe now reads `project_type` from `git_policy.project_type`, where it lives, instead of printing `null`.
- **`wi_manifest_validate` no longer passes a manifest whose required block has the wrong type.** A value like `"git_policy": "bad"` made its required-field `jq` program error; the unchecked capture read that as "nothing missing" and passed (or, through the dispatcher, aborted with no message). It now checks that program's exit status and that the document is a JSON object, and refuses with a reason either way. It also checks every required field's schema type (strings, booleans, and the string-or-null remotes, plus `tooling_repo` when present) rather than only its presence, and the two policy values the commit-msg hook enforces, with the hook's own rules — `git_policy.trace_filter.enforce` is a boolean and `blocked_patterns` an array of non-empty, single-line strings, each a valid extended regex — so a manifest can no longer validate and then be refused by the hook. `manifest_relocate` inherits all of it, and additionally refuses a symlinked `pairing.json` rather than replacing the link with a regular file and leaving its target stale, refuses a result that would record the same directory as both roots (the self-pairing the pairing preflight rejects), and keeps the manifest's file mode instead of taking the caller's umask. Its temp file is created with `mktemp` under a random name, so a symlink planted at a predictable temp path cannot redirect the write or be renamed over `pairing.json`.
- **#488 — the render-failure tests hold under any uid.** They forced a failure with a `chmod 000` template that root can still read. `WI_HOOKS_DIR` is now a strict override (a set override with no template fails the render instead of falling back to the shipped one), and the tests point it at a directory with no template.

### Compatibility
- `WI_HOOKS_DIR` is a test-only override; with it unset, template lookup is unchanged.
- The pair installer's AI-root error now names the resolved absolute path rather than the argument as typed.

## 0.6.0 (2026-09-22)

Lifecycle handoff to ossify: workspace-init stays the topology bootstrap — it creates or pairs the dual-repo layout, writes `pairing.json`, installs the AI-trace commit-msg filters, and prints next steps — but every generated stub, printed block, and example now routes the user to `/ossify:start` (empty canonical) or `/ossify:adopt` (projects previously onboarded with the legacy scaffold stack — a repository that arrives with source or history but no such stack has no supported ossify continuation yet) instead of the retired scaffold-onboard/scaffold-dev chain (#308).

### Changed
- **Generated `CLAUDE.md` stub** declares what workspace-init wrote and hands off to ossify; the `## Next steps` block names both `/ossify:start` and `/ossify:adopt` with the canonical-content rule, and the generated-file footer no longer stamps a hardcoded plugin version.
- **Generated `AGENTS.md` stub** routes lifecycle work through ossify, so the generated file satisfies ossify doctor's `agents_md` check.
- **Generated `README.md` stub** describes the topology and bootstrap records the workspace actually holds, and lists ossify as the lifecycle continuation.
- **Printed next-steps** in `initializing-dual-repo-workspace` and `pairing-canonical-repo` (and the `pairing-existing-dual` summary) route to `/ossify:start` for an empty canonical and `/ossify:adopt` for a project previously onboarded with the legacy scaffold stack; suggested commit messages no longer embed plugin version strings, and the remaining deferral notes are version-neutral.
- **Examples** for fresh bootstrap and pair-with show the same ossify next steps, version-neutral `created_by` values, and a created-paths inventory listing exactly what bootstrap writes — the decorative trees claiming pre-seeded `memory-bank/`, `process-adrs/`, and brainstorm directories are gone.
- **Marketplace and root catalog** describe the plugin by capability and name ossify as the continuation.
- **Scenario C** continues to ossify — in scope today only for a project previously onboarded with the legacy scaffold stack, since a workspace without that stack has no supported ossify continuation yet — with its pairing manifest as the topology: ossify resolves the `.workspace/pairing.json` the pair writes, so no second declaration is authored — and the printed next steps now prepare the workspace for adoption's clean-tree gate (commit the pairing changes, `git init`-ing the workspace first where it is not a repo yet).

### Removed
- **`well_known_paths.principles_user_global`** deleted from the manifest writer, the reference `pairing.json.tmpl`, and the fresh-bootstrap example — a duplicate pointer with zero consumers after architect-critic moved its principles to `$HOME/.claude/architect-critic/`. The generic `${PLUGIN_DATA:<name>}` resolver is unchanged.
- **`.claude/.onboarding-state.json` gitignore entry** deleted from the template and the inline fallback (now byte-identical to the template again); `.workspace/handoffs/` stays ignored as a compatibility entry for the still-shipped handoff flow.

### Compatibility
- **Deliberate residual:** the pairing schema stays v1.0 and retains the Shape-D routing, `during_dev`, and `roadmap` fields until the schema diet lands; generic `${PLUGIN_DATA:<name>}` token resolution is unchanged, and this release makes no repair/unpair or #272 change.

### Verification
- Release gates run locally under both jq 1.8.1 and 1.7: `workspace-init/run-tests.sh` plus the repo-root `test-codex-dual-publish.sh`, `test-devin-publish.sh`, `test-recommendation-policy-parity.sh`, and the OpenCode adapter unit suite. The OpenCode 1.18.13 live-loader gate is left to CI, which installs that exact version.

## 0.5.1 (2026-09-19)

Trace-filter hardening: the hook installs safely, renders any path, and fails closed instead of silently going dark (#457, #458, #481), plus a Scenario A manifest-write flag fix (#173).

### Fixed
- **#457 — installing the `commit-msg` hook can no longer destroy a foreign hook.** `wi_trace_filter_install` renders to a temp file and moves it into place only after a successful render, so a render failure leaves the existing hook byte-identical. It now refuses to overwrite any existing hook it did not write, recognising its own by a `# workspace-init:managed-hook` marker line (or the pre-0.5.1 `auto-installed` header) so a previously installed filter stays re-bakeable. `wi_rollback`'s HOOK_INSTALL inverse now removes only a hook carrying that ownership evidence — a foreign `commit-msg` is left in place with a warning instead of being deleted.
- **#458 — the baked AI-workspace path survives any character.** `wi_trace_filter_render` replaces `sed` substitution with a left-to-right splice of the shell-quoted path (`printf %q`), so paths containing `&`, `|`, `\`, `"`, `$`, backticks, spaces, or `'` render literally — `&` no longer expands to the matched text, `"` no longer produces an unparseable hook, and a path containing the literal placeholder text terminates cleanly.
- **#481 — the hook fails closed and names a real repair.** A missing manifest, malformed JSON, a missing or non-boolean `git_policy.trace_filter.enforce`, or unreadable `blocked_patterns` now blocks the commit with the specific reason and a pointer to the README's **Repair** section — replacing the previous fail-open warning that pointed at the non-existent `/init-workspace --repair`. (The repair wording itself was narrowed in the round-2 entry below.)
- **#173 — Scenario A records the canonical remote under the right flag.** `pairing-canonical-repo` §6.4 and the `pair-with-existing-clean` example now pass the detected remote via `--canonical-git-remote` instead of `--git-remote`, so it lands on `canonical.git_remote` rather than `ai_workspace.git_remote`.
- **Review round 1 — the manifest must be exactly one JSON object.** `jq empty` accepts a stream, so a 0-byte, whitespace-only, or multi-document `pairing.json` slipped through to the enforce check and read as "not true" — an allow. The hook now asserts a single top-level JSON object; empty, whitespace-only, concatenated-document, and non-object manifests all block.
- **Review round 1 — regex evaluation errors fail closed.** `grep -qE` exit status 2 (invalid ERE) was read as "no match"; an invalid `blocked_patterns` entry now blocks the commit naming the pattern. Non-string pattern entries (numbers, nested arrays) fail the extraction check instead of rendering as literal text. A missing `jq` is detected explicitly and reported as missing rather than as a JSON error.
- **Review round 1 — every block names a repair that fixes that exact condition.** Superseded by the round-2 narrowing below.
- **Review round 2 — the hook reports; the README repairs.** Per skill-first, the repair hint was computation in a read-and-report path: the hook no longer derives repair commands or paths at all (no `git rev-parse` worktree resolution, no baked `wi` path, no quoting). Each fail-closed branch states that the filter fails closed, gives the specific reason, and points at the README's new **Repair** section, which documents per-reason repairs in prose — including how to rewrite a corrupt manifest without losing `project_type`, `canonical.git_remote`, `canonical.default_branch`, or a customised `git_policy`. `wi_trace_filter_install` still canonicalises both roots to absolute physical paths (a relative hand-typed repair works), and `wi_trace_filter_install_pair` still repairs the load-bearing canonical hook first — but now validates the AI root (directory exists; `.workspace/pairing.json` present and a single JSON object) before touching either hook, so a mistyped or moved path can't leave canonical guarded by a dead path.
- **Review round 1 — a dangling symlink hook is never destroyed.** `-e`/`[[ -f ]]` follow links and miss a dangling `commit-msg` symlink; both the install guard and `wi_rollback`'s HOOK_INSTALL inverse now test `-e || -L`, so a foreign symlink survives byte-for-byte whether or not its target exists. `pairing-existing-dual` now documents the foreign-hook refusal (mirroring Scenario A), and the README names the real `/workspace-init:pair-workspace` command.

### Removed
- **`wi_guarded_jq_write` deleted.** The helper had no production callers — `wi_manifest_write` has always written via its own `jq -n` tempfile path — and the skill prose claiming it guarded manifest writes now describes the actual mechanism.

## 0.5.0 (2026-07-10)

### Added
- **#103 — explicit nested-wrapper bootstrap mode.** `/init-workspace <name> --wrapper <existing-dir>` now treats an existing writable outer directory as the resolved parent, creates only `<name>/` and `<name>-ai/` inside it, collision-checks only those inner targets, and preserves all wrapper-level source material. Wrapper mode is never auto-detected and does not add a redundant manifest field; canonical and AI root paths remain the topology source of truth.

### Fixed
- **#103 — fresh repositories now always initialize on `main`.** `wi_git_init` passes an explicit initial branch to Git 2.28+ and uses a plain-init plus symbolic-HEAD fallback on older Git, so a machine-level `init.defaultBranch=master` can no longer leave the real repository branch inconsistent with `canonical.default_branch: "main"` in the pairing manifest. Idempotent calls still skip existing repositories without renaming their current branch.
- **#103 — preflight rejects every inner target collision before writing.** Fresh and wrapper modes now reject files and symlinks as well as directories at `<parent>/<name>` or `<parent>/<name>-ai`, preventing a half-created sibling when one target is a non-directory entry.

## 0.4.1 (2026-07-02)

Trace-filter hook install now works for a `--separate-git-dir` / submodule canonical (#85).

### Fixed
- **`wi_trace_filter_install` accepts a canonical whose `.git` is a file (#85).** The install gated on `[[ -d "$target_repo/.git" ]]` and hardcoded the hooks dir as `$target_repo/.git/hooks`, so a `--separate-git-dir` checkout or a submodule (where `.git` is a *file* pointing at a separate git dir) passed preflight but then failed hook install with "not a git repo." It now requires an installable own git worktree root, resolves the repo-local hooks dir from `git rev-parse --git-dir`, and deliberately ignores `core.hooksPath`. The shared predicate rejects non-repos, nested subdirs, bare repos, and linked worktrees, while Scenario C AI-workspace git detection now uses the same predicate so separate-git-dir AI workspaces record `git_tracked: true` and receive a hook. Adds `test-trace-filter.sh` coverage for separate-git-dir, standard-repo, custom-hooksPath, subdir, bare, linked-worktree, and non-repo targets (the suite previously never exercised install at all).

## 0.4.0 (2026-06-21)

PR #70 review follow-ups (#71) — manifest-writer provenance + a non-git AI workspace flag + a linked-worktree preflight guard.

### Added
- **`--ai-git-tracked <true|false>` flag on `wi_manifest_write` (#71).** Sets `ai_workspace.git_tracked` (defaults `true`; canonical stays a validated git repo so its `git_tracked` is unchanged). The `pairing-existing-dual` skill (Scenario C — the only path where the existing AI workspace may not be a git repo) detects the AI workspace's git status once and threads it both into the manifest and the hook decision, so the manifest no longer cosmetically records `true` for a non-git AI workspace. Removed the corresponding "known v0.2 limitation" note from the skill.

### Changed
- **`created_by` is now provenance, not a frozen literal (#71).** `wi_manifest_write` stamps `workspace-init@<running version>`, resolved at write time from the sibling `.claude-plugin/plugin.json` (single source of truth, already guarded by the dual-publish parity test) via the new `wi_plugin_version` helper. Previously hardcoded `workspace-init@0.1.0`. `test-manifest.sh` now asserts the `workspace-init@<semver>` shape **and** parity with the manifest version, so it never needs touching on a version bump.

### Fixed
- **Reject a linked git worktree as the canonical (#71).** A `git worktree add` checkout passes the bare "is a git repo" preflight check (`git rev-parse --git-dir` succeeds) but has no own `.git/hooks` dir, so the trace-filter `commit-msg` hook would silently fail to install. Both canonical preflights — `wi_skeleton_preflight_existing_dual` (Scenario C) and `wi_skeleton_preflight --pair-with` (Scenario A) — now detect a linked worktree (new `wi_git_is_linked_worktree` helper) and fail early with a clear "pair against its main working tree" message, before any writes. The helper discriminates precisely via `--git-dir` vs `--git-common-dir`, so a standalone `--separate-git-dir` repo or a submodule (whose `.git` is also a file but which keeps its own hooks dir) is **not** over-matched (#84). (The AI-workspace-as-worktree case is out of scope — AI workspaces are created as standard repos.)
- **Scenario-C AI-workspace git detection requires its OWN repo root (#84).** The `pairing-existing-dual` skill detected the AI workspace's git status with `git rev-parse --git-dir`, which also succeeds for a plain subdirectory nested inside a parent repo — recording `git_tracked: true` and then failing hook install (`$ai_root/.git` absent). Switched to `[[ -d "$ai_root/.git" ]]`, the exact gate `wi_trace_filter_install` uses, so detection and install never disagree (a nested workspace now records `false` and cleanly skips its hook).
- **`wi_manifest_read` returns a present boolean `false` instead of treating it as missing (#84).** The reader's `jq -e -r "<field> // empty"` violated its own documented contract ("false is present-with-value"): jq's `//` and `-e` both treat `false`/`0` as falsy, so reading a `false` field returned exit 1. Rewritten with `try (<field>) catch null` + an explicit null check. Latent before this release (no consumer read a boolean field by path); the new `git_tracked: false` value makes it reachable, and the existing `allow_ai_*: false` fields are fixed too.

### Notes
- All items are PR #70 deferred non-blocking review findings tracked in #71. Co-shipped with `claude-security-audit` 0.1.3 (CI perf-benchmark gate) and the repo CI SHA-pin.

## 0.3.0 (2026-06-20)

### Added
- **Optional `tooling_repo` manifest field (#48 Stage 2).** `wi_manifest_write` gains `--tooling-repo <root>` and `--tooling-repo-remote <url>` flags; when given, it emits a `tooling_repo` object (`{ root, name, git_remote }`, `name` = basename of root) right after `canonical`, mirroring canonical's sub-schema. Absent by default → the key is omitted **entirely** (not `null`), so existing manifests and behavior are unchanged (additive; schema stays `1.0`). `wi_manifest_validate` validates `tooling_repo.root` + `tooling_repo.name` only when the key is present. The three init/pair skills (`initializing-dual-repo-workspace`, `pairing-canonical-repo`, `pairing-existing-dual`) document the optional flags so they record a tooling repo when the user volunteers one. This is the workspace-init half of marketplace routing — scaffold-dev's `/defer --tooling` resolves `.tooling_repo.root` to file tech-debt there instead of the project repo. 5 new tests (`tests/test-manifest.sh`).

### Notes
- Design-of-record: `docs/SPEC-lean-index-CDEF.md` §3.5. Pairs with scaffold-dev v0.10.0 (the routing consumer). Part of closing #48.

## 0.2.0 (2026-06-15)

### Added
- **`pairing-existing-dual` skill + `/pair-existing-dual` command (Scenario C, #9).** Pairs an already-populated AI workspace with an already-populated canonical — the case where a project grew its memory-bank/specs organically (in a sibling AI-workspace directory) before the plugins were discovered, and just needs a manifest to wire it up. Writes ONLY `.workspace/pairing.json` into the existing AI workspace and installs the trace-filter `commit-msg` hook (always in canonical; also in the AI workspace when it is itself a git repo). **Never creates, seeds, stubs, or overwrites** existing AI-workspace content — distinct from Scenario A (`pairing-canonical-repo`), which creates a *fresh* AI workspace and aborts on canonical AI-scaffolding markers. New lib preflight `wi_skeleton_preflight_existing_dual` (AI exists + non-empty; canonical exists + is a git repo; paths differ); conservative failure handling (no destructive rollback against populated content). 13 integration tests (`tests/test-pairing-existing-dual.sh`). SPEC §9.5. `pairing-canonical-repo` now cross-references this skill for the already-populated case.

## 0.1.2 (2026-05-30)

### Added
- **`well_known_paths.roadmap_state` (#28 Phase 2).** The pairing manifest now routes the structured roadmap state — `${ai_workspace.root}/.workspace/project-roadmap.json` — alongside the existing `master_spec` / `memory_bank` paths. scaffold-onboard publishes the structured roadmap there; scaffold-dev's orchestrator will field-read `id` + `sprint_id` from it (the #28 cross-plugin slice-ID contract fix) instead of grepping rendered `#### VS-…:` headings. Older manifests without the key are handled by consumer-side fallback (forward-compat, per the `routing.roadmap` §10.4 precedent).

## 0.1.1 (2026-05-26)

### Fixed
- **Shell portability (zsh compatibility):** Claude Code's Bash tool runs zsh by default on macOS; skill bodies that `source lib/*.sh` then inherited zsh, where `${BASH_SOURCE[0]}` is unset and lib self-location crashed. Added `bin/wi` dispatcher with `#!/usr/bin/env bash` shebang — the kernel forces bash on direct execution regardless of caller shell. Skill bodies (`initializing-dual-repo-workspace`, `pairing-canonical-repo`) and `/init-workspace` command now invoke `wi <fn-suffix> [args...]` instead of `source && fn`. `wi --list` enumerates dispatchable functions. The dispatcher is auto-discoverable via `$PATH` (Claude Code adds each plugin's `bin/` to PATH automatically), so callers don't need to know the plugin root.

## 0.1.0 (2026-05-25)

Initial release. Bootstrap a dual-repo workspace (AI workspace + canonical) with pairing manifest and AI-trace commit-msg filter. Run-once plugin; first in the scaffolding chain (workspace-init → scaffold-onboard → scaffold-dev). 145 tests across 10 suites.

### Added
- Skills: `initializing-dual-repo-workspace`, `pairing-canonical-repo` (skill-first per Pass D).
- Slash commands: `/init-workspace`, `/pair-workspace` (thin `$ARGUMENTS` wrappers per feedback_slash_command_dollar_n_bug).
- `lib/` bookkeeping: manifest read/write/resolve (`mi_manifest_resolve` alias per SPEC §6.3), skeleton, stubs, git-init with default-branch fallback chain, trace-filter hook install, transactional rollback.
- `commit-msg` git hook template with baked AI workspace path per SPEC §7.3.
- Pairing manifest schema v1.0 at `<ai-workspace>/.workspace/pairing.json`.
- Scenario A migration (`--pair-with <existing-canonical>`).
- 145 tests across 10 suites; `run-tests.sh` runner.

### Deferred to v0.2
- Git remotes auto-setup (per project_workspace_init_v02_deferrals).
- User-global workspace registry (per project_workspace_init_v02_deferrals).
- Scenario B migration (split existing scaffold-onboard'd single-repo).
- `/repair-workspace` command.
- `core.hooksPath`-based tracked hook (survives clones).

### Schema versions
- Pairing manifest: 1.0
