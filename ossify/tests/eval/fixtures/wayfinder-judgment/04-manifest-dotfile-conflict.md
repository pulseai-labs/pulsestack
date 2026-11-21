---
scenario_id: 04-manifest-dotfile-conflict
expected_action: stop-and-ask
expected_reason: "Branch 0 runs first — but it runs on the resolved origin, not the manifest" (tracker.md §1) — resolve the AI workspace with oss repo_root ai_workspace and read its live git origin, never the manifest's git_remote field. That origin resolves to acme/acme-ai while .wayfinder.json names acme/notes, so branch 0 stops and asks which tracker this repo's maps live on before either source wins silently; the two open maps on acme/notes would otherwise be orphaned.
---

# Scenario: a paired repo that already has a `.wayfinder.json`

A repo was used with wayfinder before it joined ossify. It carries
`.wayfinder.json` with `{"tracker":"github:acme/notes"}` and two open maps on
that tracker. It has since been paired, so `.workspace/pairing.json` now exists
with `ai_workspace.git_remote` pointing at `github.com/acme/acme-ai`.
`oss repo_root ai_workspace` resolves to `/work/acme-ai`, where
`git -C /work/acme-ai remote get-url origin` prints
`https://github.com/acme/acme-ai.git`.

The operator runs `/ossify:wayfinder` with no argument.

**What the session must do.**
