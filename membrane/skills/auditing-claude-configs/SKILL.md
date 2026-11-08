---
name: auditing-claude-configs
description: Static-analysis security audit for Claude Code and Codex project configurations and enabled plugins. Detects secrets, permission issues, hook injection, MCP misconfiguration, settings-schema typos, prompt-injection in agents/commands, marketplace integrity issues. Activate on "audit my claude config", "audit my codex config", "security scan my .claude", "security scan my .codex", "scan for leaked credentials", "review my permissions", "audit settings.json", "apply fix SA-...", "/security-audit", "/secrets-scan", "/permissions-review", "/apply-fix". Inspired by AgentShield in Everything Claude Code (Mustafa, 2026; MIT) — independent MIT implementation tailored to composable plugin marketplaces.
---

# auditing-claude-configs

Orchestrates the static-analysis security audit for Claude Code and Codex projects. Detection lives in `lib/rules/<aspect>/*.sh`; this skill body handles flow control, presentation, and the `/apply-fix` path.

**Lib invocation contract:** call every lib function via the `csa` dispatcher (`membrane/bin/csa`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically). The dispatcher's bash shebang forces a bash runtime for the libs even when the Bash tool subprocess is zsh (the macOS default). Form: `csa <fn-suffix> [args...]` resolves to `csa_<fn-suffix>`. Never `source` lib files directly from skill body — under zsh `${BASH_SOURCE[0]}` is unset and `${BASH_REMATCH[…]}` returns empty silently; the libs crash or silently corrupt state. Always go through `csa`. Use `csa --list` for discovery.

## Scope honesty (read this before invoking)

v0.1 catches **common, unobfuscated patterns**. A determined adversary who obfuscates payloads (base64, eval indirection, dynamic command construction) will evade most v0.1 rules. AST-based detection is v0.2. Realistic v0.1 value: catching accidental friendly-fire (committed secrets), naive-malicious teammate PRs, pre-publish hygiene, and the common-pattern subset of compromised-plugin attacks. Treat a clean audit as "doesn't trip our v0.1 common-pattern rules" — NOT as "this is safe to trust."

## Audit mode (default — `/security-audit`)

1. Parse `$ARGUMENTS` for flags: `--focus <aspect>`, `--verbose`, `--show-suppressed`. Set `focus` to the selected aspect, or `all` when absent; `/secrets-scan` and `/permissions-review` set their respective focus.
2. **First-run gitignore bootstrap** (only if `.claude/audits/state.json` does not yet exist): `csa state_bootstrap_gitignore "$PWD"` to add `.claude/audits/` to `.gitignore` (idempotent; covers nested git repos, missing gitignore, unwritable files — see references/auto-fix-policy.md).
3. Resolve scan targets: `csa enum_targets_all "$PWD"` (project `.claude/`, `CLAUDE.md`, `.claude-plugin/marketplace.json`, Codex surfaces such as `.codex/`, `AGENTS.md`, `.agents/plugins/marketplace.json`, `.codex-plugin/plugin.json`, readable `~/.codex/config.toml`, plus enabled Claude plugins per the algorithm in references/threat-model.md §enumerate).
4. Run the deterministic rule engine: `csa rule_engine_scan_all "$PWD" "$focus"` iterates concrete targets × applicable rules. Keep its stderr line `csa: hook-coverage ...` (printed for `all` and `hooks` scans) for step 8.
5. Rule findings carry their durable `finding_uid`: the rule computes it; do not recompute it. SCANNER findings carry none, so they are reported on every run and not registered.
6. Tag scanner findings NEW vs PERSISTED via `csa baseline_tag <raw-file> "$PWD"` against state.json's `findings` registry; keep the output in a file, `<baseline>`. Then number them for this run's report. The report's name, `<report-name>`, is `<date>-<NN>`: today's date and the two digits `csa report_next_run_of_day "$PWD"` prints; `<report-path>` is `.claude/audits/<report-name>.md`. Run `csa report_assign_display_ids <baseline> "<report-name>"` into a file, `<tagged>`; if it exits non-zero (4: `<baseline>` is missing or is not findings JSONL), say so in chat and stop: do not render or record the run. Each finding gets the display id `SA-<report-name>-<NNN>`, which the report and chat print. `--suppress` and `/apply-fix` accept it for a registered finding (not a SCANNER finding) until the next recorded audit renumbers the findings.
7. Filter suppressed scanner findings via `csa suppress_filter <tagged> "$PWD"` into a file, `<findings>` (unless `--show-suppressed`, when `<findings>` is `<tagged>`). A Critical finding is never filtered out.
   **Unmatched suppressions (full audits only).** Keep step 4's raw output in a file. Run it only when `focus` is `all`, step 4 exited 0 with no `csa: warning` line on its stderr, and the output holds no `SCANNER-*` or `PROVENANCE-002` finding (otherwise the scan was partial); then run `csa suppress_stale <raw-file> "$PWD" all`; it prints one JSON line, `{"finding_uid": …}`, per suppression whose uid is not in the scan. Print only uids that match `^FUID-[0-9a-f]{8}$` (the shape membrane mints) and skip any other string; `N` counts the uids you print. If it prints any such uid, add one chat line after the summary: `N suppression(s) match no finding in this scan: FUID-…, FUID-….  They may still be wanted (for example on another branch or with another plugin enabled). To remove one: /security-audit --unsuppress <FUID>`. Never run it on a focused scan, and never remove an entry yourself: the operator decides. If the command refuses, print nothing about suppressions.
8. Write the scanner report file `<report-path>` and return chat summary via `csa report_render_markdown <findings> <metadata-json> <report-path>` + `csa report_render_chat <findings> <report-path>`; pass the hook-coverage line from step 4 as `metadata.scope_summary`. Both read the findings file. Exit 4 means it is missing or is not findings JSONL and nothing was rendered: say so in chat and stop; do not record the run (skip step 9).
9. Update `state.json` with `csa state_record_audit "$PWD" <run-index> <report-path> <tagged> "$focus"`: pass step 6's `<tagged>`, not step 7's `<findings>`, so a suppressed finding that still fires stays in the registry and is marked `suppressed` (it ages out only when it stops firing). Here `<run-index>` is the last `audit_history` entry's `run_index` plus 1, or 1 when there is none (`jq '((.audit_history | last | .run_index) // 0) + 1' .claude/audits/state.json`), passing step 1's `focus` as its fifth argument so a focused scan ages only its own aspect (last-audit-date, scanner findings registry with GC per references/severity-rubric.md §GC, `self_integrity.state_mtime_at_last_audit` per references/auto-fix-policy.md §tamper).
10. If any rules failed to load, emit prominent chat banner: `"⚠ N rule(s) failed to load; results incomplete. See report for SCANNER-001 findings."`
11. Emit chat summary inline (per references/severity-rubric.md §chat-summary-format).

## Focused-scan mode (`/secrets-scan`, `/permissions-review`)

Identical to audit mode but with `--focus <aspect>` baked in. Skill body parses the slash command name from `$ARGUMENTS` (when wrapper passes it) or from focus flag.

## Apply-fix mode (`/apply-fix <finding-id>`)

1. Parse `$ARGUMENTS` to extract finding ID. Accept either `display_id` (e.g., `SA-2026-05-24-01-013`) or `finding_uid` (e.g., `FUID-a3f9b21c`).
2. Resolve via `csa apply_resolve_id "$PWD" "<id>"`: display_id → the registry entry that carries it in the latest recorded audit → finding_uid. An id from an older report resolves to nothing; use the `FUID-`.
3. Load finding record from `state.json`.
4. Run defense-in-depth checks per references/auto-fix-policy.md:
   - Rule has `RULE_AUTO_FIXABLE=true` AND `RULE_MECHANICALLY_FIXABLE=true`
   - Re-resolve fix recipe target path; verify still in safe-write allowlist
   - Refuse symlinks at target; refuse paths outside project root
5. Execute the rule's `fix` function with `(target_file, finding_json_context)`.
6. Update `state.json.applied_fixes` audit-trail entry (BEFORE write; updated to `failed` if write fails).
7. Emit chat confirmation: `"Applied <display_id> (<finding_uid>): <fix_summary>"`.

If any check fails, refuse with the specific message from references/auto-fix-policy.md.

## Suppression mode (`/security-audit --suppress <finding-id>`)

Call `csa suppress_add "$PWD" "<finding-id>" "<note>"`. It reads `.claude/audits/state.json` and the shipped rules, not the caller: the id must be a finding a recorded audit produced (exit 3 otherwise; exit 2 when there is no `state.json`, so run `/security-audit` first, or when `suppressions.json` is not a valid suppressions file), and a finding whose severity is Critical is refused (exit 1; the severity is the higher of the registry's and the rule's). Refuses if finding_uid was first_seen < 60s ago (exit 1; race-window protection per references/auto-fix-policy.md §tamper).

## Unsuppress mode (`/security-audit --unsuppress <FUID>`)

Calls `csa suppress_remove "$PWD" "<FUID>"`. It removes that one entry from `.claude/audits/suppressions.json` and leaves the others as they were. Exit 1 means no such suppression (or no file) and nothing was written; exit 2 means the file is not a valid suppressions file (empty, not JSON, or no `suppressions` array); exit 5 means the write failed (the file is unchanged). Takes the id as stored in `suppressions.json` (the `FUID-…` id in the stale line), matched exactly. The finding, if it still fires, shows again in the next audit.

## When the user asks naturally (no slash command)

Match phrasings like "scan my .claude for security issues", "scan my .codex for security issues", "audit my Codex config", "check for leaked credentials", "review my settings.json" — invoke this skill in the appropriate mode based on intent.

## References

- `references/threat-model.md` — what v0.1 catches and what it doesn't; enumerate algorithm
- `references/severity-rubric.md` — 5-tier rubric + chat-summary format + GC policy
- `references/auto-fix-policy.md` — safe/never categories + two-flag system + tamper detection
