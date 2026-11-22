---
scenario_id: 06-stale-manifest-remote-live-origin
expected_action: stop-and-ask
expected_reason: "Branch 0 runs first — but it runs on the resolved origin, not the manifest" (tracker.md §1) — the live origin of the resolved AI workspace is acme/acme-records, which differs from .wayfinder.json's acme/acme-ai, so branch 0 stops and asks which tracker this repo's maps live on. Comparing the manifest's stale git_remote (acme/acme-ai) instead would see no conflict and let branch 1 switch to acme/acme-records silently, orphaning the three open maps — "exactly the orphaning this stop exists to catch, reached through the check meant to prevent it."
---

# Scenario: a paired repo whose workspace moved

A repo is paired with an AI workspace and has used wayfinder since before the
move. Its `.wayfinder.json` carries `{"tracker":"github:acme/acme-ai"}`, and
three open maps live on that tracker. `.workspace/pairing.json` records
`ai_workspace.git_remote` as `github.com/acme/acme-ai`. Last month the AI
workspace was moved to a new repository; the manifest was not edited.
`oss repo_root ai_workspace` resolves to `/work/acme-ai`, where
`git -C /work/acme-ai remote get-url origin` prints
`https://github.com/acme/acme-records.git`.

The operator runs `/ossify:wayfinder` with no argument.

**What the session must do.**
