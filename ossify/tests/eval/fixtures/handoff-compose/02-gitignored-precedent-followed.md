---
scenario_id: 02-gitignored-precedent-followed
expected_location: .scratch/handoffs/<date>-<topic>.md
expected_tracked: "no"
expected_reason: precedent is gitignored and precedent decides — but the survivability tradeoff is stated aloud in the same breath (an uncommitted handoff does not survive a machine change or reach collaborators), not silently accepted and not silently "fixed" by tracking against precedent
---
A TypeScript monorepo's auth package, halfway through swapping session storage
from cookies to opaque tokens. The operator wants a handoff before a two-week
break.

The repo: `.scratch/handoffs/` holds `2026-07-30-oauth-scopes.md` and
`2026-08-08-token-schema.md`. `.gitignore`'s first line is `.scratch/`. There
is a `docs/` tree with API references, none of it handoff-shaped. Nothing else
in the repo resembles a handoff. Neither handoff is dated today.

The work state: branch `opaque-tokens` is 11 commits ahead, two of the five
integration suites still fail (`token-refresh`, `logout-cascade`), and the
conversation settled one thing no file records: refresh rotation was
deliberately deferred to a follow-up because the mobile client pins the old
flow until its next release train.

Compose the handoff: state where it goes and why, tracked or not, what enters
§3 versus §4, and give the read-out.
