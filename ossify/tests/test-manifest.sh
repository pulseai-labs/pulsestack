#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/manifest.sh"
TMP="$(mktemp -d)"

# Fixture workspace with a pairing manifest at .workspace/pairing.json.
mkdir -p "$TMP/ws/.workspace"
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON

# Discovery + convention default (walk up from a nested dir).
# NOTE: cd directly rather than `( cd DIR; ... )` — t_capture/t_assert_* mutate
# the T_PASS/T_FAIL globals, and a `(...)` subshell forks a child process whose
# mutations never propagate back, which would silently undercount failures
# (verified: with oss_manifest_discover deliberately broken, subshell-wrapped
# assertions still print "FAIL: ..." but the final tally stayed pass=1 fail=0
# and exit 0 — a vacuous-green trap for this very suite). cd back to $HERE
# after each block instead.
mkdir -p "$TMP/ws/sub/deep"
cd "$TMP/ws/sub/deep"
t_capture oss_manifest_discover
t_assert_rc 0 "manifest discovered from nested dir"
t_assert_eq "$TMP/ws/.workspace/pairing.json" "$T_OUT" "discovered path"
t_capture oss_manifest_state_path
t_assert_rc 0 "state path resolved"
t_assert_eq "$TMP/ws/.ossify/project-state.json" "$T_OUT" "convention default state path"
cd "$HERE"

# Honor an explicit well_known_paths.project_state with a resolvable token.
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"project_state":"\${ai_workspace.root}/.ossify/ps.json"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_state_path
t_assert_rc 0 "routed state path resolved"
t_assert_eq "$TMP/ws/.ossify/ps.json" "$T_OUT" "routed path token resolved"
cd "$HERE"

# The silent-literal trap: an UNKNOWN token must be refused, not passed through.
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"project_state":"\${private_core.root}/ps.json"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_state_path
t_assert_rc 1 "unresolved token refused (not passed through as literal)"
t_assert_contains "$T_OUT" "unresolved" "refusal names the unresolved path"
cd "$HERE"

# No manifest anywhere → require refuses with both slash-command tokens.
cd "$TMP"
t_capture oss_manifest_require
t_assert_rc 1 "require refuses when no manifest"
t_assert_contains "$T_OUT" "/init-workspace" "refusal keeps /init-workspace token"
t_assert_contains "$T_OUT" "/pair-workspace" "refusal keeps /pair-workspace token"
t_assert_contains "$T_OUT" 'In a paired canonical repo, run from the AI workspace' 'canonical refusal names the workspace remedy (#717)'
t_assert_contains "$T_OUT" '(cd <ai-workspace> && oss …)' 'canonical refusal gives the subshell form (#717)'
cd "$HERE"

# _oss_resolve_state precedence: explicit > OSS_STATE_FILE.
t_capture _oss_resolve_state "/explicit/x.json"
t_assert_eq "/explicit/x.json" "$T_OUT" "explicit path wins"
export OSS_STATE_FILE="/env/y.json"
t_capture _oss_resolve_state
t_assert_eq "/env/y.json" "$T_OUT" "OSS_STATE_FILE used when no explicit path"
unset OSS_STATE_FILE

# Dispatcher-path smoke check: `oss state_path` must work through bin/oss under
# REAL strict mode (set -euo pipefail) — sourced-only tests can miss
# strict-mode bugs that only surface via the dispatcher (repo lesson).
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON
OSS="$HERE/../bin/oss"
cd "$TMP/ws"
t_capture "$OSS" state_path
t_assert_rc 0 "oss state_path works through the dispatcher under strict mode"
t_assert_eq "$TMP/ws/.ossify/project-state.json" "$T_OUT" "dispatcher state_path matches convention default"
cd "$HERE"

# The `oss manifest_get` VERB was removed in v0.2.0 (zero prose consumers, and
# it bypassed the token substitution every real field needs). The lib function
# it wrapped is load-bearing - `_oss_repo_root` is built on it - so the coverage
# moves here rather than being deleted, and is exercised through the dispatcher
# via `repo_root`, which is the supported way to ask.
cd "$TMP/ws"
t_capture oss_manifest_get '.ai_workspace.root'
t_assert_rc 0 "lib: manifest_get ok"
t_assert_eq "$TMP/ws" "$T_OUT" "lib: manifest_get reads a manifest field"
t_capture oss_manifest_get '.no_such_key'
t_assert_rc 1 "lib: manifest_get rc 1 on a missing/null field"
t_capture "$OSS" repo_root ai_workspace
t_assert_rc 0 "dispatcher: repo_root is the supported way to read a root"
t_assert_eq "$TMP/ws" "$T_OUT" "dispatcher: repo_root resolves ai_workspace through bin/oss"
# The removed verb must be GONE, not merely unused - a stale wrapper would keep
# handing callers unresolved `${ai_workspace.root}` tokens.
t_capture "$OSS" manifest_get '.ai_workspace.root'
t_assert_rc 2 "dispatcher: the removed manifest_get verb is unknown (rc 2)"
cd "$HERE"

# --- Final review M1: when OSS_STATE_FILE overrides a MANIFEST-ROUTED project,
# say so. A stale export left by an unrelated session silently redirects every
# read and write, and nothing in the output named the source. Three properties
# are asserted because each one is separately load-bearing:
#   (a) the notice never touches stdout — `_oss_resolve_state`'s stdout IS the
#       state path, and every `oss get` consumer treats stdout as a value;
#   (b) it names the env var AND the manifest path being overridden;
#   (c) it stays silent when nothing is actually being overridden (the env var
#       agrees with the manifest), so it does not become noise to tune out.
#
# #171 SETTLED 2026-08-16: the rail stays blunt and self-describing. An equivalent
# spelling STILL fires the notice — by design, and the notice's own text now says
# so ("paths compared as written") — so the assertion below pins that firing plus
# the self-description, not silence. See `_oss_resolve_state`'s header for the
# walked-and-declined alternatives (canonicalization, -ef, refuse-not-warn).
cd "$TMP/ws"
export OSS_STATE_FILE="$TMP/elsewhere/state.json"
t_capture _oss_resolve_state 2>/dev/null
OUT_ONLY="$(_oss_resolve_state 2>/dev/null)"
t_assert_eq "$TMP/elsewhere/state.json" "$OUT_ONLY" "override notice stays OFF stdout (stdout is exactly the path)"
ERR_ONLY="$(_oss_resolve_state 2>&1 >/dev/null)"
t_assert_contains "$ERR_ONLY" "OSS_STATE_FILE" "override notice names the env var as the source"
t_assert_contains "$ERR_ONLY" "$TMP/ws/.ossify/project-state.json" "override notice names the manifest-routed path being overridden"

export OSS_STATE_FILE="$TMP/ws/.ossify/project-state.json"
ERR_AGREE="$(_oss_resolve_state 2>&1 >/dev/null)"
t_assert_eq "" "$ERR_AGREE" "no notice when the env var agrees with the manifest (nothing is being overridden)"

# #171's pinned behaviour: an EQUIVALENT SPELLING of the manifest path still fires
# the notice (raw-string compare is the rail's design), and the notice's own text
# declares the bluntness so the reader is not misled into hunting real divergence.
export OSS_STATE_FILE="$TMP/ws/./.ossify/project-state.json"
ERR_EQUIV="$(_oss_resolve_state 2>&1 >/dev/null)"
t_assert_contains "$ERR_EQUIV" "OSS_STATE_FILE" "equivalent spelling still fires the blunt notice (#171 settled: by design)"
t_assert_contains "$ERR_EQUIV" "paths compared as written" "the notice self-describes its raw-string comparison (#171)"
unset OSS_STATE_FILE
cd "$HERE"

# ...and with no manifest anywhere on the walk-up path there is nothing to
# override, so the env branch stays silent there too (this is also what keeps
# the rest of the suite, which runs manifest-less, free of the notice).
cd "$TMP"
export OSS_STATE_FILE="/env/y.json"
ERR_NOMANIFEST="$(_oss_resolve_state 2>&1 >/dev/null)"
t_assert_eq "" "$ERR_NOMANIFEST" "no notice when there is no manifest to override"
unset OSS_STATE_FILE
cd "$HERE"

cd "$TMP"
export OSS_STATE_FILE="/env/y.json"
ERR_NOMANIFEST="$(_oss_resolve_state 2>&1 >/dev/null)"
t_assert_eq "" "$ERR_NOMANIFEST" "silent when there is no manifest to override"
t_assert_eq "/env/y.json" "$(_oss_resolve_state 2>/dev/null)" "manifest-less: env value still routed through"
unset OSS_STATE_FILE
cd "$HERE"

# --- #165: refusing ${PLUGIN_DATA:...} must say UNSUPPORTED, not malformed.
# The token is valid workspace-init vocabulary that ossify deliberately does not
# resolve (#152 wontfix), so the generic "unresolved path" wording sent readers to
# workspace-init's docs — where the token is legal — and away from the fix.
ERR_PD="$(_oss_manifest_wellknown_guard '${PLUGIN_DATA:foo}/x' spec 'test' 2>&1 >/dev/null)"
# NOT `t_assert_contains "$ERR_PD" "PLUGIN_DATA"` — that assertion is VACUOUS. The
# generic arm echoes the offending path back, and the path itself contains the
# literal "PLUGIN_DATA", so it passes with this fix reverted. Caught by mutation
# testing. Discriminate on the generic arm's own word instead: the named arm must
# NOT call a documented-but-unsupported token "unresolved".
if [ "${ERR_PD#*unresolved}" != "$ERR_PD" ]; then PD_SAYS_UNRESOLVED=yes; else PD_SAYS_UNRESOLVED=no; fi
t_assert_eq "no" "$PD_SAYS_UNRESOLVED" "#165: PLUGIN_DATA is NOT reported with the generic 'unresolved' wording"
t_assert_contains "$ERR_PD" "does not resolve" "#165: refusal says ossify does not resolve it (a limit, not a typo)"
t_assert_contains "$ERR_PD" 'ai_workspace.root' "#165: refusal names a supported token to use instead"

# CONTROL for the new arm — it must not swallow the generic case. An unknown
# token still gets the original wording, and must NOT be described as PLUGIN_DATA.
ERR_OTHER="$(_oss_manifest_wellknown_guard '${NOPE:foo}/x' spec 'test' 2>&1 >/dev/null)"
t_assert_contains "$ERR_OTHER" "unresolved" "#165 control: an unrelated token still gets the generic refusal"
# Substring test via parameter expansion, NOT a `case` inside $( ) — the `)` that
# closes a case pattern also closes the command substitution.
if [ "${ERR_OTHER#*PLUGIN_DATA}" != "$ERR_OTHER" ]; then MENTIONS_PD=yes; else MENTIONS_PD=no; fi
t_assert_eq "no" "$MENTIONS_PD" "#165 control: the generic refusal does NOT mention PLUGIN_DATA"
# CONTROL: both arms still REFUSE. A friendlier message that started returning 0
# would route a mutating verb at an unresolvable path.
t_capture _oss_manifest_wellknown_guard '${PLUGIN_DATA:foo}/x' spec 'test'
t_assert_rc 1 "#165 control: the PLUGIN_DATA arm still refuses (rc 1), it only reworded"

# MALFORMED spellings are TYPOS, not supported vocabulary, so they must get the
# GENERIC wording. workspace-init's grammar is ${PLUGIN_DATA:([a-zA-Z0-9_-]+)};
# a prefix-substring test also swallowed these and told the operator the token was
# a documented-but-unsupported one, which is the malformed-vs-unsupported call this
# whole change exists to get right — backwards. (Codex P2, PR #178 round 1.)
for BAD in '${PLUGIN_DATA:}/x' '${PLUGIN_DATA:foo/x' '${PLUGIN_DATA:foo.bar}/x'; do
  BAD_ERR="$(_oss_manifest_wellknown_guard "$BAD" spec 'test' 2>&1 >/dev/null)"
  t_assert_contains "$BAD_ERR" "unresolved" "#165: malformed '$BAD' gets the GENERIC unresolved wording"
  if [ "${BAD_ERR#*does not resolve}" != "$BAD_ERR" ]; then BAD_CLAIMS_PD=yes; else BAD_CLAIMS_PD=no; fi
  t_assert_eq "no" "$BAD_CLAIMS_PD" "#165: malformed '$BAD' is NOT called supported-but-unresolvable"
done

# ...and the complete grammar is still recognised in the forms workspace-init allows
# (hyphens and underscores are legal plugin-name characters).
for GOOD in '${PLUGIN_DATA:foo}/x' '${PLUGIN_DATA:my-plugin}/x' '${PLUGIN_DATA:my_plugin}/x'; do
  GOOD_ERR="$(_oss_manifest_wellknown_guard "$GOOD" spec 'test' 2>&1 >/dev/null)"
  t_assert_contains "$GOOD_ERR" "does not resolve" "#165: complete token '$GOOD' gets the unsupported-vocabulary wording"
done

# ---------------------------------------------------------------------------
# The RELATIVE-path trap (Codex P2, PR #149). `_oss_manifest_resolve`
# substitutes `${...}` tokens but never joins a bare relative value onto the
# workspace root, so a relative routed value came back unchanged and sailed past
# the unresolved-token guard — then resolved against whichever directory the
# session happened to start in. Two agents in two directories, two state files.
# ---------------------------------------------------------------------------
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"project_state":"ps.json"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_state_path
t_assert_rc 1 "a RELATIVE routed state path is refused, not resolved against the cwd"
t_assert_contains "$T_OUT" "not absolute" "the refusal names absoluteness, not tokens"
cd "$HERE"

# ---------------------------------------------------------------------------
# `oss spec_path` — the lean MASTER-SPEC resolver behind doctor's spec surface.
# workspace-init writes `.well_known_paths.master_spec` (default
# `${ai_workspace.root}/docs/MASTER-SPEC.md`), so a resolver that knew only the
# workspace root would miss a customized routed destination and report an
# initialised project as having no spec at all.
# ---------------------------------------------------------------------------
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_spec_path
t_assert_rc 0 "spec path resolved with no routing key"
t_assert_eq "$TMP/ws/docs/MASTER-SPEC.md" "$T_OUT" "convention default matches workspace-init's own default destination"
cd "$HERE"

# A CUSTOMIZED routed destination must win over the convention — the whole point
# of reading the key. If this returned the convention path, the finding Codex
# raised would still be live and this suite would still be green.
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"master_spec":"\${ai_workspace.root}/specs/LEAN-SPEC.md"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_spec_path
t_assert_rc 0 "routed spec path resolved"
t_assert_eq "$TMP/ws/specs/LEAN-SPEC.md" "$T_OUT" "the ROUTED destination wins over the convention"
cd "$HERE"

# The same two guards apply, because they are the same guard.
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"master_spec":"\${private_core.root}/S.md"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_spec_path
t_assert_rc 1 "an unresolved token in the spec path is refused"
cd "$HERE"
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"master_spec":"docs/S.md"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_spec_path
t_assert_rc 1 "a relative spec path is refused"
t_capture "$OSS" spec_path
t_assert_rc 1 "dispatcher: spec_path propagates the refusal under strict mode"
cd "$HERE"

# ---------------------------------------------------------------------------
# A workspace root containing `&`. `${s//needle/$repl}` is not literal in the
# replacement half: under bash 5.2's default `patsub_replacement` an `&` expands
# to the whole matched text, turning `${ai_workspace.root}/docs/S.md` back into
# an unresolved token and making the guard reject a correctly-configured
# project. The escape-based fix was measured to repair 5.2 and BREAK 3.2 (which
# macOS ships), so the substitution is done by hand instead.
#
# This assertion passes on 3.2 today for the wrong reason — 3.2 has no
# patsub_replacement — but it is the regression guard for the machines that do,
# and it fails on ANY version if the hand-rolled substituter is wrong.
# ---------------------------------------------------------------------------
mkdir -p "$TMP/amp&ws/.workspace"
cat > "$TMP/amp&ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/amp&ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"master_spec":"\${ai_workspace.root}/docs/MASTER-SPEC.md"}}
JSON
cd "$TMP/amp&ws"
t_capture oss_manifest_spec_path
t_assert_rc 0 "a workspace root containing '&' still resolves"
t_assert_eq "$TMP/amp&ws/docs/MASTER-SPEC.md" "$T_OUT" "the '&' survives verbatim instead of re-expanding to the matched token"
t_capture oss_manifest_state_path
t_assert_eq "$TMP/amp&ws/.ossify/project-state.json" "$T_OUT" "the same holds for the state resolver"
cd "$HERE"

# The substituter itself, directly — every case the token expansion relies on.
t_assert_eq "/a&b/x"  "$(_oss_subst_literal '${R}/x' '${R}' '/a&b')"  "subst: & is literal in the replacement"
t_assert_eq '/a\b/x'  "$(_oss_subst_literal '${R}/x' '${R}' '/a\b')" "subst: a backslash is literal too"
t_assert_eq "aZbZc"   "$(_oss_subst_literal 'a${T}b${T}c' '${T}' 'Z')" "subst: every occurrence is replaced"
t_assert_eq 'a${T}b'  "$(_oss_subst_literal 'a${T}b' '${T}' '${T}')" "subst: a replacement containing the needle does not re-match"
t_assert_eq "plain"   "$(_oss_subst_literal 'plain' '${T}' 'Z')"    "subst: no occurrence leaves the string alone"

rm -rf "$TMP"

# ===========================================================================
# TOPOLOGY TWIN (#272/#310 Task 11, spec decision O1): pairing.json is
# normalized on read into ONE internal shape, so the manifest-resolution
# mechanics this file pins against .workspace/pairing.json above must hold
# byte-for-byte against .ossify/topology.json too - if they diverged, the
# fallback would be a second dialect, not a genuine adapter.
#
# A FRESH temp tree ($TMPT, never $TMP above) and a repo named "core" -
# deliberately never "canonical" - so nothing below can pass by coincidence
# of a magic name. "ai_workspace" resolves throughout even though
# topology.json carries no `ai_workspace` KEY at all: it is derived
# structurally (the parent of `.ossify/`), not read off a field the way the
# pairing arm reads `.ai_workspace.root`.
#
# SCOPED to the assertions that actually read the manifest: discovery, the
# convention default, a routed well_known_paths token, the unresolved-token
# guard, the RELATIVE-path guard, the dispatcher smoke check, spec_path's
# convention/override/unresolved-token/relative-path refusal quartet, and
# the '&' literalness guarantee. Left untwinned, with the reason at each:
#   - _oss_resolve_state's OSS_STATE_FILE precedence and override-notice
#     wording (:59-154 above) - no manifest read at all in those assertions,
#     just a bare `/explicit/x.json` and a raw env var.
#   - the `_oss_manifest_wellknown_guard`/PLUGIN_DATA/`_oss_subst_literal`
#     blocks (:156-294 above) - pure functions over an already-resolved
#     string, no discovery, no shape, no manifest source involved.
#   - `oss_manifest_get '.ai_workspace.root'` and the removed-`manifest_get`-
#     verb coverage (:80-98 above) - `.ai_workspace.root` is pairing-specific
#     read vocabulary with no topology analog (topology has no such field to
#     read; `_oss_manifest_ai_root` reads `.workspace` off the SHAPE
#     instead, which is what this twin's own dispatcher `repo_root
#     ai_workspace` check just below already exercises for the topology
#     source.
# ===========================================================================
TMPT="$(mktemp -d)"
mkdir -p "$TMPT/ws/.ossify"
cat > "$TMPT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPT/core"}},"well_known_paths":{}}
JSON

# Discovery + convention default (walk up from a nested dir).
mkdir -p "$TMPT/ws/sub/deep"
cd "$TMPT/ws/sub/deep"
t_capture oss_topology_discover
t_assert_rc 0 "topology twin: manifest discovered from nested dir"
t_assert_eq "$TMPT/ws/.ossify/topology.json" "$T_OUT" "topology twin: discovered path"
t_capture oss_manifest_state_path
t_assert_rc 0 "topology twin: state path resolved"
t_assert_eq "$TMPT/ws/.ossify/project-state.json" "$T_OUT" "topology twin: convention default state path"
cd "$HERE"

# Honor an explicit well_known_paths.project_state with a resolvable token.
cat > "$TMPT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPT/core"}},"well_known_paths":{"project_state":"\${ai_workspace.root}/.ossify/ps.json"}}
JSON
cd "$TMPT/ws"
t_capture oss_manifest_state_path
t_assert_rc 0 "topology twin: routed state path resolved"
t_assert_eq "$TMPT/ws/.ossify/ps.json" "$T_OUT" "topology twin: routed path token resolved"
cd "$HERE"

# The silent-literal trap: an UNKNOWN token must be refused, not passed through.
cat > "$TMPT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPT/core"}},"well_known_paths":{"project_state":"\${repos.private_core.root}/ps.json"}}
JSON
cd "$TMPT/ws"
t_capture oss_manifest_state_path
t_assert_rc 1 "topology twin: unresolved token refused (not passed through as literal)"
t_assert_contains "$T_OUT" "unresolved" "topology twin: refusal names the unresolved path"
cd "$HERE"

# Dispatcher-path smoke check: `oss state_path` works through bin/oss under
# REAL strict mode, and `oss repo_root ai_workspace` resolves the derived key.
cat > "$TMPT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPT/core"}},"well_known_paths":{}}
JSON
cd "$TMPT/ws"
t_capture "$HERE/../bin/oss" state_path
t_assert_rc 0 "topology twin: oss state_path works through the dispatcher under strict mode"
t_assert_eq "$TMPT/ws/.ossify/project-state.json" "$T_OUT" "topology twin: dispatcher state_path matches convention default"
t_capture "$HERE/../bin/oss" repo_root ai_workspace
t_assert_rc 0 "topology twin: dispatcher repo_root resolves ai_workspace with no ai_workspace KEY in the source file"
t_assert_eq "$TMPT/ws" "$T_OUT" "topology twin: ai_workspace root, derived structurally rather than read off a field"
cd "$HERE"

# ---------------------------------------------------------------------------
# The RELATIVE-path trap: a routed value must be refused, not resolved
# against the caller's cwd.
# ---------------------------------------------------------------------------
cat > "$TMPT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPT/core"}},"well_known_paths":{"project_state":"ps.json"}}
JSON
cd "$TMPT/ws"
t_capture oss_manifest_state_path
t_assert_rc 1 "topology twin: a RELATIVE routed state path is refused, not resolved against the cwd"
t_assert_contains "$T_OUT" "not absolute" "topology twin: the refusal names absoluteness, not tokens"
cd "$HERE"

# ---------------------------------------------------------------------------
# `oss spec_path` twin - the convention default, a CUSTOMIZED routed
# destination winning over it, and the same unresolved/relative refusals.
# ---------------------------------------------------------------------------
cat > "$TMPT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPT/core"}},"well_known_paths":{}}
JSON
cd "$TMPT/ws"
t_capture oss_manifest_spec_path
t_assert_rc 0 "topology twin: spec path resolved with no routing key"
t_assert_eq "$TMPT/ws/docs/MASTER-SPEC.md" "$T_OUT" "topology twin: convention default matches workspace-init's own default destination"
cd "$HERE"

cat > "$TMPT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPT/core"}},"well_known_paths":{"master_spec":"\${ai_workspace.root}/specs/LEAN-SPEC.md"}}
JSON
cd "$TMPT/ws"
t_capture oss_manifest_spec_path
t_assert_rc 0 "topology twin: routed spec path resolved"
t_assert_eq "$TMPT/ws/specs/LEAN-SPEC.md" "$T_OUT" "topology twin: the ROUTED destination wins over the convention"
cd "$HERE"

# The same two guards apply, because they are the same guard (review round 1,
# finding 1: the legacy case tests the UNRESOLVED-token refusal at :247-254 as
# a scenario distinct from the RELATIVE-path refusal below - dropping it left
# the twin one refusal short of its original).
cat > "$TMPT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPT/core"}},"well_known_paths":{"master_spec":"\${repos.private_core.root}/S.md"}}
JSON
cd "$TMPT/ws"
t_capture oss_manifest_spec_path
t_assert_rc 1 "topology twin: an unresolved token in the spec path is refused"
cd "$HERE"

cat > "$TMPT/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPT/core"}},"well_known_paths":{"master_spec":"docs/S.md"}}
JSON
cd "$TMPT/ws"
t_capture oss_manifest_spec_path
t_assert_rc 1 "topology twin: a relative spec path is refused"
t_capture "$HERE/../bin/oss" spec_path
t_assert_rc 1 "topology twin: dispatcher spec_path propagates the refusal under strict mode"
cd "$HERE"

# ---------------------------------------------------------------------------
# A workspace root containing '&' - the hand-rolled substituter's literal-
# replacement guarantee must hold from a topology source too, not only from
# a pairing-translated one.
# ---------------------------------------------------------------------------
mkdir -p "$TMPT/amp&ws/.ossify"
cat > "$TMPT/amp&ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMPT/core"}},"well_known_paths":{"master_spec":"\${ai_workspace.root}/docs/MASTER-SPEC.md"}}
JSON
cd "$TMPT/amp&ws"
t_capture oss_manifest_spec_path
t_assert_rc 0 "topology twin: a workspace root containing '&' still resolves"
t_assert_eq "$TMPT/amp&ws/docs/MASTER-SPEC.md" "$T_OUT" "topology twin: the '&' survives verbatim instead of re-expanding to the matched token"
t_capture oss_manifest_state_path
t_assert_eq "$TMPT/amp&ws/.ossify/project-state.json" "$T_OUT" "topology twin: the same holds for the state resolver"
cd "$HERE"

rm -rf "$TMPT"
t_summary
