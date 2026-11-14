---
description: Plan an ossify feature spine (1-5 work items, DAG rounds, per-round specs, grill-me for bone spines, cumulative-demo criteria under the journey-line floor, fake ledger)
argument-hint: "<spine-id>"
allowed-tools: Bash(bash:*), Read, Write, Edit, Skill
---

Parse args from `$ARGUMENTS` via a trailing argument (no positional `$1`/`$2`/`$N`),
then load the `ossify:plan-spine` skill body, which owns spine planning.

```bash
bash -c '
  set -u
  ARGS="${*:-}"
  echo "plan-spine: ARGS=${ARGS:-<none>}"
' _ "$ARGUMENTS"
```

Now load the skill body and follow it:

**Read `${CLAUDE_PLUGIN_ROOT}/skills/plan-spine/SKILL.md` (in OMP: `skill://plan-spine`) end to end and follow
it** — with the parsed spine id (`r1.s2`). The skill body owns the pre-flight
probes (manifest + project + a planned release) → decomposition into 1-5 work
items with a `target_repo` → round identification via the work-item DAG →
per-round spec authoring with the citation fold-in → the grill-me gate for bone
spines only → demo authoring under the journey-line floor → fake-ledger
discipline, and shells out to `oss` for all state.
