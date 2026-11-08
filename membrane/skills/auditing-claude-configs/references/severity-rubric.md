# Severity rubric (v0.1)

Distilled from SPEC §9.3. Each rule declares severity statically; chat-summary posture follows.

## Scanner findings

The scanner reports its own failures as findings, not as a clean read. SCANNER-001: a rule failed to load (High). SCANNER-002: a rule's check failed on a target, for example a settings file that is not JSON (High). SCANNER-003: the scan could not read a target (Medium; one per target, for a scan whose rules would have read it, and it does not count toward the "rule(s) failed" banner).

## Tiers (5 static)

- **Critical** — actively dangerous; immediate action.
  *Ex:* hook executes `curl ... | bash`; `"deny": []` paired with broad allow; plaintext production API key in CLAUDE.md; agent prompt instructs reading and exfiltrating `~/.ssh/`.

- **High** — significantly risky; fix this session.
  *Ex:* MCP endpoint with no auth; `settings.local.json` silently broadens `settings.json`; plugin's hook contains base64-encoded payload that decodes to network call; settings schema typo (`"allowed"` instead of `"allow"`) silently disabling enforcement.

- **Medium** — notable; fix within a few sessions.
  *Ex:* hook references external script not in repo; `Bash(*)` instead of `Bash(git:*)`; CLAUDE.md mentions internal-only paths; agent prompt has unusual instructions that look like prompt injection but lack clear exfiltration.

- **Low** — hygiene; fix when convenient.
  *Ex:* stale comment in hook config; localhost dev URL in MCP config; permission slightly broader than needed.

- **Info** — observation, not a finding.
  *Ex:* "Plugin X v1.2.3 enabled; no issues detected"; "No audit baseline yet — this is your first audit"; INFO-PARANOID-001 (N cached-not-enabled plugins).

## Chat-summary posture

- **Critical + High**: shown with explicit counts AND alert tone ("⚠ N findings need attention").
- **Medium + Low**: aggregated as totals; no per-finding detail unless `--verbose`.
- **Info**: suppressed from chat by default; included in report file; surface in chat only with `--verbose`.
- **Plugin test files and agent scratch** (a finding under an enabled plugin's `fixtures/` or `tests/`, or under the project's `.dagr/scratch/`): not listed in chat unless `--verbose`; one line after the table gives the count and the Critical, High and Medium split. Totals and severities are unchanged, and the report lists each with a `Group:` tag.

Counts table at the top of chat output (mirrors SPEC §8.4 report header):

```
| Severity | NEW | Persisted | Suppressed | Total visible |
|---|---|---|---|---|
| Critical | 0 | 0 | 0 | 0 |
| High     | 1 | 0 | 0 | 1 |
| Medium   | 2 | 1 | 1 | 3 |
| Low      | 4 | 3 | 2 | 7 |
| Info     | (suppressed; pass --verbose) | | | |
```

## GC policy (T2-K)

`state.json.findings` registry tracks `seen_in_runs`. After every audit:
- For each `finding_uid` in the registry, increment `seen_in_runs` if seen in current run.
- Compute `runs_since_last_seen = current_run_index - last_seen_run_index`, minus the runs in that window that were focused on another aspect (#429). Each `audit_history` entry records its `focus`: `all` for a full audit, which counts for every finding, or the one aspect a focused scan covered. A finding's aspect is its rule's directory under `lib/rules/`.
- A run recorded before 0.1.7 (no `focus`) counts as a full run. A `TAMPER-*` finding has no aspect and ages on every run. A `SCANNER-*` finding carries no `finding_uid`, so it never enters the registry.
- If `runs_since_last_seen > 10`, evict the entry.
- An entry no reader can use is dropped at the next audit: one that is not an object, and one whose `last_run_index` is not a number (it cannot be aged) that does not fire in that audit. One that fires is re-sighted first, so it is kept, reads PERSISTED and keeps its `first_seen`. A `rule_id` that is not a string maps to no aspect, so the entry ages on every run. A registry that is not an object restarts empty. A finding whose entry was dropped reads NEW once.
- A suppressed finding that still fires counts as seen: step 9 records it (marked `suppressed: true`; a Critical is never marked, since the filter never hides it), so it ages only when it stops firing, like any other.
- Evicted entries silently re-appear as NEW if rediscovered (acceptable for a "what changed recently" feature).

Bootstrap: first audit run has `runs_since_last_seen = 0` for all newly-discovered findings.
