# Amending an open release

Depth for SKILL.md §2. Run §3's pre-flight, then resolve the release to amend.
Read the release's status from state; this arm applies only when it is not `closed`.
Add one spine to that release; repeat this arm for more.

1. Select the candidate under §5a, including measured-pressure admission, before minting.
2. Capture the new id from `oss spine_add "$rel" "<name>" <bone|flesh> [<target_repo>]`.
   The §5c `target_repo` rule applies: optional only for a sole declared repo;
   otherwise pass its key.
3. Read the current `spine_dag`, then re-write it whole with the new spine's entry,
   keeping every existing entry. `release_set_meta` replaces the key; never send
   only the new entry. Interrogate edges under §6 (`spine-sequencing-dag.md`).
4. Add a journey exit criterion under §5b, or state that this amendment adds none.
   Preserve the existing criteria when writing `exit_criteria` with `release_set_meta`.
5. Re-check the ledger budget against this spine's expected contribution (§5d).
6. Run §7 in full for the new spine only: §7a class ladder, §7b bone-touch judge,
   §7c critic veto. Do not re-judge already planned spines. §7c renders the current
   release draft as usual; scope its judgment to the new spine.
7. Re-render `RELEASE.md` from state (`release-md-emission.md` §4), never hand-edit it.
   An amendment that adds no criterion says so to the user; `RELEASE.md` renders only state.
8. If §7 retired the new spine, stop: a retired spine takes no plan.
   Otherwise `/ossify:plan-spine <new id>` plans it as usual.
