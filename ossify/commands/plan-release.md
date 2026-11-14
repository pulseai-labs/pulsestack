---
description: Plan an ossify release (feature-map grooming, exit criteria, spine DAG, class declaration under the fail-closed critic veto, RELEASE.md)
argument-hint: "[release-name]"
allowed-tools: Bash(bash:*), Read, Write, Edit, Skill
---

Parse args from `$ARGUMENTS` via a trailing argument (no positional `$1`/`$2`/`$N`),
then load the `ossify:plan-release` skill body, which owns release planning.

```bash
bash -c '
  set -u
  ARGS="${*:-}"
  echo "plan-release: ARGS=${ARGS:-<none>}"
' _ "$ARGUMENTS"
```

Now load the skill body and follow it:

**Read `${CLAUDE_PLUGIN_ROOT}/skills/plan-release/SKILL.md` (in OMP: `skill://plan-release`) end to end and follow
it** — with the parsed release name. The skill body owns the inputs (incl. the
mandatory real-use findings) → spine selection + exit criteria + ledger budget →
spine DAG → class declaration under the bone-touch judge and the fail-closed
critic veto → RELEASE.md → next-release sketch flow, and shells out to `oss` for
all state.
