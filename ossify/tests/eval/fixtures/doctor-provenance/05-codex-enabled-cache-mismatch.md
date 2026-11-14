---
scenario_id: 05-codex-enabled-cache-mismatch
expected_outcome: warn
expected_reason: "Binary and loaded body resolve independently to 1.40.0; the only enabled ossify entry selects pulsestack-codex, whose single cache directory has agreeing Codex and Claude manifests at 1.39.0. The stale disabled marketplace and misleading directory name are not authorities. All roles resolve and the mismatch warns."
---

Codex runs in `/home/dev/consumer`, an ordinary git worktree with no
`ossify/.claude-plugin/plugin.json` at its root. The user invokes only
`/ossify:doctor provenance`. `CODEX_HOME` is `/opt/codex`.

`command -v oss` prints `/opt/active/ossify/bin/oss`, an absolute executable,
not a symlink. Its readable root `.claude-plugin/plugin.json` version is `1.40.0`.
The host supplies `/opt/loaded/ossify/skills/doctor` as the loaded skill base;
that separate root's readable `.claude-plugin/plugin.json` says `1.40.0`.

`/opt/codex/config.toml` contains exactly:

```toml
[plugins."ossify@pulsestack-codex"]
enabled = true

[plugins."ossify@claude-agent-scaffolding-codex"]
enabled = false
```

`/opt/codex/plugins/cache/pulsestack-codex/ossify/` contains exactly one version
directory, `1.40.0/`. Its readable `.codex-plugin/plugin.json` says `1.39.0`,
and its readable `.claude-plugin/plugin.json` also says `1.39.0`.
The directory was renamed to `1.40.0/` by hand.
The disabled pre-rename marketplace also has a cache directory with manifests
at `1.40.0`.

The complete conversation contains no prior ossify verb or product-prose use.
