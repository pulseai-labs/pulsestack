---
scenario_id: 07-leftover-topology-not-this-run-refuses-a3
expected_outcome: refuse-a3
expected_reason: Control for the A3 exemption. The untracked .ossify/topology.json was authored by an earlier, refused run, not by A1 in this run, so the exemption does not apply and A3 refuses, naming it. It is residue: the operator deletes it (A1 re-authors it) or commits it; adoption does neither. Nothing is recorded and oss init does not run.
---
The operator made `/home/dev/projects/relay-ai` (`git init`) and ran `/ossify:adopt`
there yesterday; it refused at A6 ("nothing ships yet") and the operator closed the
session. Today they typed `/ossify:adopt` again. The walk-up path now resolves
`.ossify/topology.json` in `relay-ai`, declaring `canonical` at
`/home/dev/projects/relay` (Elixir, `mix.exs`, `lib/`, 52 commits, on `main`), so A1
authored nothing in this run. The operator says a step works now: "`mix relay.ping`
answers `pong`; I just ran it." `git status --porcelain --untracked-files=all` in
`relay-ai` shows only `?? .ossify/topology.json`; `relay` is clean. There is no
scaffold-dev stack.

The ceremony is at gate A3.
