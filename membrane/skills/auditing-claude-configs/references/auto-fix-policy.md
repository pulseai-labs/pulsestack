# Auto-fix policy (v0.1)

Distilled from SPEC §9.2, §9.5, §7.1, §7.4. Read before authoring fix functions.

## Two-flag system (T2-H)

| Flag | Meaning |
|---|---|
| `RULE_AUTO_FIXABLE` | Target file path is in the safe-write allowlist (write-permission gate). |
| `RULE_MECHANICALLY_FIXABLE` | Fix recipe is derivable without human judgment. |

**Both flags must be `true` for `/apply-fix` to act.** A rule may have one but not the other:
- `AUTO=true, MECH=false` → writable file but fix needs judgment (e.g., narrowing `Bash(*)` — what to narrow to is user intent). `/apply-fix` refuses; verbal remediation is the only path.
- `AUTO=false, MECH=true` → fix exists but target is attacker-controlled (never the case in practice — if MECH=true the rule author should write a safe-target equivalent).

## Safe-write allowlist (RULE_AUTO_FIXABLE=true targets)

| Path | Allowed | Notes |
|---|---|---|
| `.gitignore` (project) | ✅ | Always-correct fixes only (append/dedup) |
| `CLAUDE.md` (project's own) | ✅ | Redact a leaked secret (replace with placeholder + warn user to rotate) |
| `.claude/settings.json` | ✅ | User-owned; fixes target this user's intent |
| `.claude/settings.local.json` | ✅ | User-owned; fixes target this user's intent |
| `~/.claude/settings.json` | ❌ | Out of project scope |
| `.claude/hooks.json`, hook scripts | ❌ | Attacker-controlled if from a plugin |
| `.claude/agents/*.md` | ❌ | Attacker-controlled; prompt-injection risk |
| `.claude/commands/*.md` | ❌ | Attacker-controlled |
| `.claude/mcp/*.json`, `.mcp.json` | ❌ | Attacker-controlled endpoint |
| `.claude-plugin/marketplace.json` | ❌ | Trust-root change too consequential to auto-apply |
| Anything under `~/.claude/plugins/cache/` | ❌ | Plugin files owned by plugin; auto-fix corrupts install state |

## Defense-in-depth re-validation in apply-fix.sh

Before invoking a rule's `fix` function:
1. Re-check `RULE_AUTO_FIXABLE` AND `RULE_MECHANICALLY_FIXABLE` (a malicious rule could lie OR be overwritten between detection and apply).
2. Re-resolve fix recipe's target path; verify still in safe-write allowlist.
3. Refuse symlinks at target path (attacker could symlink `.gitignore` → `~/.ssh/authorized_keys`).
4. Refuse paths that resolve OUTSIDE project root (catches `..` traversal).
5. Log to `state.json.applied_fixes` BEFORE the write; update to `failed` rather than remove if write fails.

## First-audit gitignore bootstrap (T1-D)

Triggers when `.claude/audits/state.json` does not exist. Logic:

```
if .gitignore exists in project root:
    if .gitignore does NOT contain pattern matching .claude/audits/:
        append "\n# claude-security-audit\n.claude/audits/\n"
        print "Added .claude/audits/ to your .gitignore"
    else:
        do nothing silently
elif no .gitignore exists:
    if .git directory exists somewhere up the tree:
        create .gitignore at git-root with the entry
        print "Created .gitignore with .claude/audits/ entry"
    else:
        # not a git repo
        print Info "No git repository found; .claude/audits/ will not be gitignored"
else:
    # .gitignore exists but unwritable
    print High "Cannot write to .gitignore — add '.claude/audits/' manually"
```

## Self-tamper detection (T1-F)

Three checks, run by `csa state_check_tamper "$PWD"` (skipped silently on first-ever run when state.json doesn't exist). `/security-audit` does not run them today: they run only when `csa state_check_tamper` is called, and they compare against what `csa state_update_self_integrity "$PWD"` last recorded.

- **Check 1 — state.json mtime drift**: if actual mtime ≠ `state.json.self_integrity.state_mtime_at_last_audit`, emit `TAMPER-001` (High). The finding carries only its message and the file; it shows no diff, and none is to be made with `git` (Check 3).
- **Check 2 — suppressions.json mtime drift**: same pattern → `TAMPER-002` (High).
- **Check 3 — git-tracked status drift**: whether state.json and suppressions.json are tracked by git; if tracked-status changed since last audit → `TAMPER-003` (High). Read it only through `csa state_check_tamper "$PWD"`; never run `git` in the audited project yourself (`git check-ignore`, `git ls-files`, or any other): git reads that project's config, which can name a command git runs (`core.fsmonitor`). `csa` turns that key off for its own call.

Where the checks are used, record with `csa state_update_self_integrity "$PWD"` IMMEDIATELY AFTER the audit's own write (it sets `self_integrity.state_mtime_at_last_audit` and the tracked status).

**Race-window suppression refusal**: when user runs `/security-audit --suppress <id>`, check `findings[finding_uid].first_seen`. If within 60 seconds of current time, refuse with the message in SPEC §9.5. Blocks attacker who introduces malicious file + immediately pre-suppresses the finding.

**Limitations**: an attacker who can write to .claude/audits/ can also forge mtime. v0.1 catches *opportunistic* tampering; *deliberate* tampering needs the v0.2 signed-state mechanism.
