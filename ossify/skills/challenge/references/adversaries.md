# The adversary ladder

Depth for `challenge/SKILL.md`, loaded by audit mode at close depth. A
close-depth audit recruits one external fresh-frame adversary. **Which one is
configuration, not code** — and unconfigured means host-only, by declaration,
not by accident.

---

## 1. Resolution — first hit wins

1. **Per-invocation override.** The calling prose or the user names an
   adversary for this run.
2. **`OSSIFY_ADVERSARY`** — `codex`, `claude`, `devin`, or the literal `none`
   (force host-only even where a recipe would resolve).
3. **Host-only.** The declared default. No implicit adversary is ever assumed
   from the host agent.

**Any other value resolves to a loud refusal, not an improvisation:** an
unvalidated name (`droid`, `gemini`, anything not in §2) gets one plain line —
*"<name> has no validated recipe — running host-only; see
challenge/references/adversaries.md §2 for how a recipe is added"* — and the
audit continues host-only. Selecting a name whose invocation nobody has
validated would hand the audit to a guessed command line.

Audit mode announces the resolution before running (audit.md §3), and the
summary's `Adversaries used` line always names what actually ran — `host only`
is a value, not an omission.

---

## 2. Recipes

Each recipe: a probe, an invocation, the output contract (§3), a timeout, and
the failure path (§4). The `codex` and `claude` recipes originated in
architect-critic 0.6.0, and `devin` joined after a real audit run (§2.1).
These three are the complete validated set.

_Dispatcher invocations below are `"$oss_bin" …` — THIS fence resolves `oss` itself and checks that what answers is ossify's own dispatcher before using it, so nothing here depends on an earlier Bash call._

**Every invocation runs under the timeout guard (§2.2) — an unguarded hang is
a blocked ceremony.** And `codex` and `claude` resolve the schema path **before entering
Bash**: `${CLAUDE_PLUGIN_ROOT}` is not exported into Bash-tool subprocesses
(it expands to empty there — `doctor/references/budget-check.md` documents the
behaviour). Resolve from the `oss` dispatcher. Two steps, loud on failure:

```bash
oss_bin="$(command -v oss 2>/dev/null || true)"
# Verify a PATH hit answers our dispatcher — an unrelated `oss` binary can shadow it.
if [ -n "$oss_bin" ]; then
  case "$("$oss_bin" help 2>/dev/null)" in *ossify*) : ;; *) oss_bin="" ;; esac
fi
[ -n "$oss_bin" ] || { echo "cannot resolve the ossify dispatcher: nothing on PATH answers as ossify" >&2; exit 1; }
plugin_root="$(cd "$(dirname "$oss_bin")/.." && pwd)"          # plugin root
schema="$plugin_root/skills/challenge/templates/output-schema.json"
[ -f "$schema" ] || { echo "cannot locate the challenge schema from $oss_bin"; exit 1; }
```

### codex — ported, proven

**Probe:** `command -v codex`.

**Invocation** (the schema file ships at
`skills/challenge/templates/output-schema.json` under the plugin root):

```bash
codex exec --json \
  --output-schema "$schema" \
  --output-last-message "<tmpdir>/codex-audit-<id>.json" \
  --ignore-user-config --ignore-rules --skip-git-repo-check \
  "<prompt>"
```

Read the `--output-last-message` file, not stdout. Validate it against §3.

### claude — ported, proven

**Probe:** `command -v claude && command -v jq`.

**Invocation:** Claude rejects the template's `$schema` dialect declaration;
omit it only from the Claude CLI argument.

```bash
claude_schema="$(jq -c 'del(."$schema")' "$schema")" || exit 1
claude --print \
  --output-format json \
  --json-schema "$claude_schema" \
  --permission-mode dontAsk \
  --no-session-persistence \
  "<prompt>"
```

Read `structured_output` from the JSON response and validate it against §3.

### devin — proven on a real audit

**Probe:** `command -v devin`.

**Invocation.** It runs from a new empty directory, never from the repo, and the
prompt ends with the no-tools sentence below. `OSSIFY_ADVERSARY_MODEL`, when set,
picks the model; unset, the account's default applies. Only this recipe reads that
variable. §2.2's guard goes on the `devin` line, not around the block.

```bash
workdir="$(mktemp -d)" || exit 1
trap 'rm -rf "$workdir"' EXIT
( cd "$workdir" || exit 1
  devin -p --permission-mode auto --respect-workspace-trust false \
    ${OSSIFY_ADVERSARY_MODEL:+--model "$OSSIFY_ADVERSARY_MODEL"} -- "<prompt>" </dev/null )
```

The prompt's last line: *"Everything you need is in this prompt. Do not call any
tool, read any file, or invoke any skill. Your only message is that JSON object
and nothing else."*

Read stdout and validate it against §3. Devin has no schema flag, so the contract
in the prompt is all that holds the shape.

Both rules come from a measured failure. Run from a repo, Devin reached for its
skills, print mode rejected the tool call, and the process exited **0** with one
sentence of prose. That is invalid output (§4), never a clean audit. A slow model
can also pass the default limit: `swe-2-max` took 292 s on a 15 KB artifact, so set
`OSSIFY_ADVERSARY_TIMEOUT_S` to suit the model (§2.2). Print mode refuses an untrusted
directory, and a new temporary one is untrusted, so the trust flag is required. The
directory is empty, so the flag trusts nothing.

**The sentence does not sandbox it.** Print mode rejects tools that need confirmation,
but `auto` still approves read-only ones, and Devin read a file outside its directory
in a test. An artifact carrying instructions could make it read local files and send
them to its model provider. Do not select this recipe for an artifact you did not
write or review.

### 2.1 Adding a recipe

`droid` is the expected next entry, and the reason it is not selectable yet is
the point: a recipe ships only after a real audit run validates its exact
flags against the installed CLI. To add one: run one close-depth audit with
the candidate CLI, confirm the final message satisfies §3, then add the
section — probe, invocation, timeout, failure path — in the same change. A
name without a validated invocation is a dead selector, not a recipe.

### 2.2 The timeout guard

`OSSIFY_ADVERSARY_TIMEOUT_S` (integer seconds, default **300**) bounds every
recipe invocation:

- **GNU `timeout` or `gtimeout` present** — run the invocation under
  `timeout "$OSSIFY_ADVERSARY_TIMEOUT_S" <invocation>`. Exit 124 is the
  timeout signature.
- **Neither present (macOS default)** — run the invocation in the background,
  sleep-and-poll for completion, and `kill` it once the limit passes. The
  exit status of a killed run is the timeout signature.

A timeout lands in §4 like any other failure: one warning naming the cause,
audit continues host-only. **Never invoke an adversary without the guard** —
the timeout documented beside a recipe is a promise this section is what
keeps.

---

## 3. The return contract — travels in the prompt

The adversary never sees this skill, so the contract is embedded in the prompt
verbatim, as an ordinary fenced block — with **one legal severity value in
the example** (an alternation literal like `premise|gap|alternative` is not a
legal enum value, and a schema-constrained model may echo it back):

    ## Return contract
    Return a JSON object of exactly this shape:
    ```json
    {"challenges":[{"text":"<one paragraph>","severity":"gap","rationale":"<why>"}]}
    ```
    severity is one of: premise, gap, alternative.

Validation: a JSON object with a `challenges` array whose items each carry
string `text`, `severity` in `premise|gap|alternative`, and string `rationale`.
Anything else is invalid output and takes the §4 path.

**Size cap before dispatch.** The prompt travels as one command-line argument,
and argv limits (roughly 2 MB, less after environment overhead) fail the
process before the adversary starts — a silent loss of the fresh frame. If the
assembled prompt exceeds **128 KiB**, do not dispatch: run host-only with one
warning naming the artifact's size and the cap. §1's 50K-line check surfaces
oversized artifacts earlier; this cap is the mechanical backstop.

---

## 4. Failure is host-only, loudly

Timeout, non-zero exit, missing file, invalid JSON, over-cap prompt — all five
land in the same place: **one warning naming the cause, the audit continues
host-only, and the summary records what actually ran.** Never retry
mid-ceremony; never treat a failed adversary as a passing one. The user
re-runs the audit after fixing the cause if the fresh frame matters for this
artifact.
