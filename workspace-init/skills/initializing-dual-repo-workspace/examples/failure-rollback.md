# Example: Failure and rollback mid-init

## Scenario

User runs `/init-workspace foo` from `/Users/example/projects/`. Both target
directories are absent and preflight passes. After the AGENTS.md task, another
process creates a directory at `foo-ai/README.md`. Task 8.7 cannot write a file
there, so the skill invokes rollback.

An existing regular README.md is not a refusal: `stub_readme` overwrites it.
This example uses a directory to exercise an actual write failure.

## Inputs and pre-flight

- **name** = `foo`
- **parent** = `/Users/example/projects` (writable)
- **project_type** = `personal`
- **ai_root** = `/Users/example/projects/foo-ai`
- **canonical_root** = `/Users/example/projects/foo`

_Resolve `wi_bin` once with `command -v wi`; the plugin loader puts `bin/` on
`$PATH`. The transcript below maps the run's project parent to
`/Users/example/projects` and its plugin checkout to
`/Users/example/projects/pulsestack`._

The bootstrap sequence through Task 8.5 succeeds without output:

```bash
"$wi_bin" skeleton_preflight "$parent" "$name"
"$wi_bin" skeleton_create_root_pair "$parent" "$name"
"$wi_bin" skeleton_seed_subdirs "$ai_root"
"$wi_bin" manifest_write "$ai_root" "$canonical_root" "$project_type"
"$wi_bin" stub_agents_md "$ai_root" "$name"
```

## Init-log state before failure

At this point, `/Users/example/projects/foo-ai/.workspace/init-log` contains:

```
MKDIR	/Users/example/projects/foo-ai
MKDIR	/Users/example/projects/foo
MKDIR	/Users/example/projects/foo-ai/.workspace
WRITE_FILE	/Users/example/projects/foo-ai/.workspace/.gitkeep
MKDIR	/Users/example/projects/foo-ai/.claude
WRITE_FILE	/Users/example/projects/foo-ai/.claude/.gitkeep
MKDIR	/Users/example/projects/foo-ai/docs
WRITE_FILE	/Users/example/projects/foo-ai/docs/.gitkeep
MKDIR	/Users/example/projects/foo-ai/docs/specs
WRITE_FILE	/Users/example/projects/foo-ai/docs/specs/.gitkeep
MKDIR	/Users/example/projects/foo-ai/.superpowers
WRITE_FILE	/Users/example/projects/foo-ai/.superpowers/.gitkeep
MKDIR	/Users/example/projects/foo-ai/.archive
WRITE_FILE	/Users/example/projects/foo-ai/.archive/.gitkeep
WRITE_FILE	/Users/example/projects/foo-ai/.gitignore
WRITE_FILE	/Users/example/projects/foo-ai/AGENTS.md
```

`manifest_write` created `.workspace/pairing.json` but did not append an entry.
The logged root-directory removal still removes it during this fresh-mode rollback.

## The failure

To reproduce the collision after preflight, create the directory, then run Task 8.7:

```bash
mkdir "$ai_root/README.md"
"$wi_bin" stub_readme "$ai_root" "$name"
```

The dispatcher returns exit code 1 and prints:

```
/Users/example/projects/pulsestack/workspace-init/lib/_helpers.sh: line 204: /Users/example/projects/foo-ai/README.md: Is a directory
ERROR: wi_stub_readme: template render failed
```

The skill catches the failure and invokes rollback:

```bash
"$wi_bin" rollback "${ai_root}/.workspace/init-log"
```

## Rollback execution log

`wi_rollback` walks the init-log in reverse order, inverts each operation, and
prints a summary, not a line per operation:

```
INFO: wi_rollback: rolled back 16 of 16 ops
```

Rollback returns exit code 0. The logged `MKDIR` inverses use `rm -rf`, so the
unlogged README.md directory and pairing manifest are removed with the AI root.

## Final clean state

Check both targets after rollback:

```bash
test ! -e "$ai_root" && printf 'foo-ai absent\n'
test ! -e "$canonical_root" && printf 'foo absent\n'
```

Output:

```
foo-ai absent
foo absent
```

Neither target remains; the pre-existing project parent is untouched. The skill
reports the failed task and stops rather than continuing to git initialization.
Rollback is best-effort: inspect any warnings before assuming another failed
run reached this clean state.
