---
scenario_id: 06-same-day-recompose-name-taken
expected_location: .scratch/handoffs/2026-08-08-token-schema-2.md
expected_tracked: "no"
expected_reason: precedent is gitignored and is followed with the survivability tradeoff said aloud, as in 02 — and today's `2026-08-08-token-schema.md` is already on disk, in no git index, so compose finds it by checking the directory, never overwrites it, takes the next free name (-2, the repo has no letter-suffix precedent) and says in the read-out that the name was taken and which name it used
---
A TypeScript monorepo's auth package, same work as this morning: swapping
session storage from cookies to opaque tokens. It is 6pm on 2026-08-08. The
operator wants a fresh handoff on the same topic, `token-schema`, because the
morning one is out of date.

The repo: `.scratch/handoffs/` holds `2026-07-30-oauth-scopes.md` and
`2026-08-08-token-schema.md`, the second written at 9am today. `.gitignore`'s
first line is `.scratch/`, so `git ls-files` lists neither file. Nothing else
in the repo resembles a handoff, and no handoff name carries a letter or
numeric suffix.

The work state: branch `opaque-tokens` is 13 commits ahead, four of the five
integration suites pass and `logout-cascade` still fails; since the morning
handoff the `token-refresh` suite went green. One thing was settled in
conversation that no file records: opaque tokens stay at 32 bytes because the
mobile client's keychain slot rejects anything longer.

One step remains: the next action is to run
`npm test -w packages/auth -- logout-cascade` and fix the revoked-session
check it reports; the branch is done when all five suites pass and it is
opened as a PR to `main`.

Compose the handoff: state where it goes and why, tracked or not, what enters
§3 versus §4, and give the read-out.
