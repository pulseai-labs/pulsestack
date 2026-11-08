The user wants to apply a safe-category auto-fix for a specific audit finding.

Invoke the `auditing-claude-configs` skill in apply-fix mode.

`$ARGUMENTS` should contain the finding identifier — either `display_id` (e.g., `SA-2026-05-24-01-013` from the latest report) or `finding_uid` (e.g., `FUID-a3f9b21c` for cross-session reference).

The skill will:
1. Resolve the ID to a finding_uid
2. Validate the rule has both `RULE_AUTO_FIXABLE=true` AND `RULE_MECHANICALLY_FIXABLE=true`
3. Re-resolve the fix recipe's target path; verify it's in the safe-write allowlist
4. Refuse symlinks and path-traversal targets
5. Execute the fix; log to `state.json.applied_fixes`

If any check fails, the skill refuses with a specific reason and shows the rule's `RULE_REMEDIATION` instructions instead.
