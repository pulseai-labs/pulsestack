---
scenario_id: 04-legacy-stack-stays-class-l
expected_outcome: proceed-class-l
expected_reason: Control. The AI workspace holds a scaffold-dev stack (a roadmap state and an active-context cursor on a boundary) and the canonical carries source, so the class step picks L and the legacy path runs: A4 probes .worktrees, A5 reads the cursor, and A6 does not apply. No plain-repo gate fires.
---
The operator typed `/ossify:adopt` in `/home/dev/projects/atlas-ai`, a
`/pair-workspace` workspace whose `.workspace/pairing.json` declares `canonical`
at `/home/dev/projects/atlas` (TypeScript, `src/`, 212 commits). The memory bank
at the routed path holds a `.workspace/project-roadmap.json` roadmap state and a
`05-active-context.md` whose cursor reads "slice 14 closed; next: none open".
`.worktrees` is empty. The operator confirmed `atlas` carries product source at
`HEAD`. The operator was not asked for a journey step that works today.

The ceremony is at the class step and the gates A3 to A5.
