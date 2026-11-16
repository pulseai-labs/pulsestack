---
scenario_id: 06-extra-untracked-file-still-refuses-a3
expected_outcome: refuse-a3
expected_reason: Control for the A3 exemption. Besides the topology A1 just authored, the AI workspace has a second untracked file, so A3 refuses, naming the file and its repo for the operator to rule work in flight or residue; the exemption covers only the exact topology path and does not widen to "untracked files in the AI workspace". Nothing is recorded and oss init does not run.
---
The operator made `/home/dev/projects/vault-ai` (`git init`) and typed
`/ossify:adopt` there. No topology was on the walk-up path; the skill asked which
repos hold the product, the operator named `/home/dev/projects/vault` (Go: `go.mod`,
`cmd/`, `internal/`, 27 commits, on `main`), and A1 has just authored
`.ossify/topology.json` (untracked). There is no scaffold-dev stack, and `vault` is
clean. `git -C /home/dev/projects/vault-ai status --porcelain --untracked-files=all`
prints two lines:

```text
?? .ossify/topology.json
?? scratch-notes.md
```

The operator says `scratch-notes.md` is "just my own jotting, ignore it".

The ceremony is at gate A3.
