#!/usr/bin/env bash
# Manifest / state-path resolution for ossify. Ports scaffold-dev's manifest
# discovery + resolver, and adds the unresolved-token guard the companion §1
# "silent-literal-path" trap requires. Reads its own topology declaration
# (<ai-root>/.ossify/topology.json) first, then falls back to the EXISTING
# workspace-init pairing manifest (<ai-root>/.workspace/pairing.json),
# translated into the same internal shape on read; never writes either.

OSS_MANIFEST_REFUSAL="ossify requires a topology declaration (none found on the walk-up path). /ossify:start and /ossify:adopt author one (.ossify/topology.json); an existing dual-repo workspace can instead pair via /init-workspace or /pair-workspace. In a paired canonical repo, run from the AI workspace: (cd <ai-workspace> && oss …). On Codex, invoke the ossify skills start or adopt - that surface publishes skills, not commands."

# Resolve the effective ${USER} value without ever propagating a failed `id`
# call into a caller's `set -e` context: this function's own exit status is
# always 0 (the trailing printf), so embedding it in a substitution is safe.
_oss_current_user() {
  local u="${USER:-}"
  if [ -z "$u" ]; then
    u="$(id -un 2>/dev/null)" || true
  fi
  printf '%s' "$u"
}

# A repo name is [a-z][a-z0-9_-]*. This is an INJECTION BOUNDARY, not style:
# the name is interpolated into jq expressions and filesystem paths, so it
# must refuse metacharacters ('x|hack'), leading digits, empty, and uppercase
# before any jq read. The closed enum this replaces was accidentally that
# boundary; this one is deliberate (#272 design section 3, adjacent to #120).
#
# The sets are ENUMERATED, not written as `[a-z]`. A bracket RANGE is
# collation-ordered outside the C locale, and every UTF-8 collation interleaves
# the cases - so `*[!a-z0-9_-]*` admitted `svcA` on the operator's macOS shell
# and refused it under CI's C locale. A boundary whose shape depends on $LANG is
# not a boundary. The leading-character arm is enumerated for the same reason,
# and it refuses a leading `-` or `_` as well as a leading digit: the grammar
# says the first character is a letter, and a key starting `-` is an argument to
# every command this name is interpolated into.
_oss_repo_key_valid() { # $1=key ; rc 0 valid
  case "$1" in
    *[!abcdefghijklmnopqrstuvwxyz0123456789_-]*) return 1 ;;
    [abcdefghijklmnopqrstuvwxyz]*)               return 0 ;;
    *)                                           return 1 ;;
  esac
}

# Walk up from $PWD to find .workspace/pairing.json. Echoes the abs path; rc 1.
oss_manifest_discover() {
  local dir="$PWD"
  # `[ "$dir" != "/" ]` as the loop CONDITION never inspected "/" itself, so a
  # workspace at the filesystem root - or any run started beneath one - was
  # reported as having no declaration at all. Break AFTER checking instead.
  while [ -n "$dir" ]; do
    if [ -f "$dir/.workspace/pairing.json" ]; then
      echo "$dir/.workspace/pairing.json"; return 0
    fi
    [ "$dir" = "/" ] && break
    dir="$(dirname "$dir")" || return 1
  done
  return 1
}

# Walk up from $PWD for .ossify/topology.json FIRST, then fall back to the
# pairing walk. The topology check is for the FILE, never the directory: a
# legacy workspace's .ossify/project-state.json cannot satisfy it, so no
# workspace is half-migrated by accident. When both exist anywhere on the
# walk-up, topology wins - the operator's own declaration beats the legacy
# fallback (#272 design section 2).
oss_topology_discover() {
  local dir="$PWD"
  # Checks "/" itself - see oss_manifest_discover's note on the same shape.
  while [ -n "$dir" ]; do
    if [ -f "$dir/.ossify/topology.json" ]; then
      echo "$dir/.ossify/topology.json"; return 0
    fi
    [ "$dir" = "/" ] && break
    dir="$(dirname "$dir")" || return 1
  done
  oss_manifest_discover
}

# One internal shape from either source (#272 design section 2). The pairing
# arm promotes EVERY top-level object carrying .root except ai_workspace to a
# repos entry - canonical, private_core, tooling_repo, and any role a future
# workspace-init invents - so the writer side can never again declare a role
# the reader refuses. Unknown keys ride along ignored (pulse-trader's extended
# routing keys require exactly this).
# The `.repos` map is a BOUNDARY, not a field with a default. `repos: (.repos //
# {})` normalized a null, absent or empty map to `{}` and returned rc 0, so
# `oss state_path` succeeded on a topology declaring nothing: /start read it as
# resolved, would neither author nor overwrite it, and the first defaulted repo
# operation failed with "[] are declared" far from the cause.
#
# `ai_workspace` is likewise refused HERE rather than at `_oss_repo_key_valid`.
# The validator guards the lookup side, and `_oss_repo_root` tests the reserved
# alias BEFORE it ever calls the validator - so a declared `.repos.ai_workspace`
# was shadowed by the alias and never reached a grammar check at all. The
# pairing arm below has always excluded the key by name; this is the topology
# arm's missing half of that symmetry.
#
# rc 3, not rc 1: the caller distinguishes "found a manifest that will not
# parse" from "parsed a manifest that declares nothing usable", and emitting the
# JSON-parse message for the second sends the reader looking for a syntax error
# that is not there.
_oss_topology_shape() { # $1=manifest-path ; echoes shape JSON ; rc 1 unparseable, rc 3 invalid
  local m="$1" n
  case "$m" in
    */.ossify/topology.json)
      # PARSEABILITY FIRST. The boundary checks below are jq expressions, and on
      # an unparseable file every one of them fails - reporting "declares no
      # repos" for what is actually a syntax error, and sending the reader to
      # the wrong half of the file. rc 1 here lets the caller say so.
      jq -e . "$m" >/dev/null 2>&1 || return 1
      # EXACTLY ONE top-level value. `jq -e .` accepts a concatenated JSON
      # STREAM, so two objects in one file passed every check below once per
      # value and the projection emitted TWO shapes - `oss state_path` returned
      # a multiline "path" and `oss init` could create a directory with an
      # embedded newline in its name. `-s` slurps the stream into an array, so
      # its length is the value count.
      [ "$(jq -s 'length' "$m" 2>/dev/null)" = "1" ] || {
        echo "oss: topology '$m' holds more than one top-level JSON value - schema v1 is exactly one object" >&2; return 3; }
      jq -e 'type == "object"' "$m" >/dev/null 2>&1 || {
        echo "oss: topology '$m' is not a JSON object - schema v1 is one object carrying .schema_version, .repos and .well_known_paths" >&2; return 3; }
      # schema_version is a BOUNDARY, not a label. The projection below reads v1
      # field semantics off whatever it is handed, so a document declaring v2 -
      # or declaring nothing - resolved, /start preserved it as already
      # onboarded, and every later verb read it as v1. When v2 exists this is
      # the line that routes to a migration; until then it is the line that
      # refuses instead of guessing.
      jq -e '.schema_version == 1' "$m" >/dev/null 2>&1 || {
        echo "oss: topology '$m' declares schema_version $(jq -c '.schema_version // "nothing"' "$m" 2>/dev/null) - this ossify understands schema_version 1 only" >&2; return 3; }
      jq -e '(.repos // {}) | type == "object" and (length > 0)' "$m" >/dev/null 2>&1 || {
        echo "oss: topology '$m' declares no repos - .repos must be a non-empty object of <name>:{root}" >&2; return 3; }
      jq -e '(.repos | has("ai_workspace")) | not' "$m" >/dev/null 2>&1 || {
        echo "oss: topology '$m' declares 'ai_workspace', which is reserved for the AI workspace itself and cannot be declared as a product repo - rename that entry" >&2; return 3; }
      # EVERY ENTRY, not just the map. Validating only that `.repos` is a
      # non-empty object let an uppercase key or a `{}`/string entry through:
      # `oss state_path` succeeded, /start read the topology as resolved and
      # preserved the file, state was initialized, and the first `oss repo_root`
      # failed AFTER onboarding had partially proceeded. The name check calls
      # `_oss_repo_key_valid` rather than restating the grammar as a jq regex -
      # one grammar, one definition, or the two drift.
      while IFS= read -r _k; do
        [ -n "$_k" ] || continue
        _oss_repo_key_valid "$_k" || {
          echo "oss: topology '$m' declares '$_k', which is not a valid repo name - names match [a-z][a-z0-9_-]* (lower case, starting with a letter)" >&2; return 3; }
      done <<EOF
$(jq -r '.repos | keys[]' "$m" 2>/dev/null)
EOF
      jq -e '.repos | to_entries | all((.value | type) == "object" and (.value.root | type) == "string" and (.value.root | length) > 0)' "$m" >/dev/null 2>&1 || {
        echo "oss: topology '$m' has a repo entry that is not {\"root\": \"<path>\"} - every declared repo needs an object carrying a non-empty root: $(jq -r '[.repos | to_entries[] | select(((.value|type) != "object") or ((.value.root|type) != "string") or ((.value.root|length) == 0)) | .key] | join(", ")' "$m" 2>/dev/null)" >&2; return 3; }
      # `well_known_paths` when present must be an OBJECT. `(.well_known_paths
      # // {})` preserved a string or array verbatim; the later
      # `.well_known_paths.project_state` read then errors, the error is
      # swallowed as an empty route, and /start initializes state at the default
      # path instead of refusing a malformed routing declaration.
      jq -e '(.well_known_paths == null) or ((.well_known_paths | type) == "object")' "$m" >/dev/null 2>&1 || {
        echo "oss: topology '$m' has a well_known_paths that is not an object - it routes named artifacts, so it must be {} or a map of <key>:<path>" >&2; return 3; }
      jq -c --arg ws "$(dirname "$(dirname "$m")")" '{schema_version,
          repos: .repos, well_known_paths: (.well_known_paths // {}),
          workspace: $ws, source: "topology"}' "$m" 2>/dev/null || return 1 ;;
    *)
      jq -c --arg ws "$(jq -r '.ai_workspace.root // empty' "$m" 2>/dev/null)" \
        '{repos: (to_entries | map(select((.value|type)=="object"
             and .value.root != null and .key != "ai_workspace")) | from_entries),
          well_known_paths: (.well_known_paths // {}),
          workspace: $ws, source: "pairing"}' "$m" 2>/dev/null || return 1 ;;
  esac
}

_oss_shape_file() { # discover + shape ; emits a diagnostic and returns 1 whether nothing
                     # was found (the refusal) or a manifest was found but failed to parse
  local m
  m="$(oss_topology_discover)" || { echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1; }
  # rc 3 means _oss_topology_shape already said precisely what is wrong; adding
  # the JSON-parse line on top of it would contradict its own diagnostic.
  _oss_topology_shape "$m" && return 0
  [ "$?" = 3 ] && return 1
  echo "oss: manifest '$m' could not be parsed as JSON" >&2; return 1
}

# The default repo when a caller omits the key: the SOLE declared repo when
# exactly one is declared; a listing refusal otherwise. Fail-safe by design -
# with N>1 an unset target must refuse, never silently pick (spec section 3).
_oss_default_repo_key() {
  local shape keys
  shape="$(_oss_shape_file)" || return 1
  keys="$(printf '%s' "$shape" | jq -r '.repos | keys[]')"
  if [ "$(printf '%s\n' "$keys" | grep -c .)" -eq 1 ]; then
    printf '%s\n' "$keys"
  else
    echo "oss: no repo key given and [$(printf '%s' "$shape" | jq -r '.repos | keys | join(", ")')] are declared - name one" >&2
    return 2
  fi
}

# The repo key for a state WRITE. `_oss_default_repo_key` covers the omitted
# case; this covers the supplied one, which used to be trusted verbatim.
#
# Two refusals, and they are not the same check. An UNDECLARED key must refuse
# because a typo that reaches the journal fails much later, during routing, with
# nothing left to say which ceremony wrote it. `ai_workspace` must refuse
# because it RESOLVES - it is the reserved alias for the process workspace - so
# a resolution check alone admits it, and a work item or patch record targeting
# it routes a close commit and a merge into the AI workspace.
#
# Called from the THREE `oss_cmd_*` wrappers that persist a key - spine_add,
# work_item_add, patch_add - and not from the `oss_entity_*`/`oss_ledger_*`
# functions beneath them. The dispatcher is where every real caller arrives (a
# skill never sources a lib, it shells out to `oss`), so guarding there covers
# the whole reachable surface; guarding the lib functions as well would force a
# discoverable declaration on internal composition and on unit fixtures that
# legitimately have none.
#
# The six sites that resolve a key through `_oss_repo_root` on the next line are
# already guarded there, and routing them through this would refuse
# `ai_workspace` for callers (`oss repo_root ai_workspace`, the doctor re-probe)
# that legitimately ask for it.
_oss_repo_key_for_write() { # $1=explicit-key-or-empty ; echoes the key ; rc 2 refusal
  local k="${1:-}" shape
  [ -n "$k" ] || { _oss_default_repo_key; return $?; }
  [ "$k" = "ai_workspace" ] && {
    echo "oss: 'ai_workspace' is the reserved process workspace, not a hosting repo - a spine, work item or patch record must target a declared product repo" >&2
    return 2; }
  # Membership is read off the SHAPE, not via `_oss_repo_root`. Two reasons:
  # `_oss_repo_root` lives in worktree.sh, and calling it from manifest.sh made
  # every caller that sources one without the other die on `command not found`;
  # and membership is a shape question - the extra token-resolution and
  # directory checks `_oss_repo_root` performs answer a different one.
  shape="$(_oss_shape_file)" || return $?
  printf '%s' "$shape" | jq -e --arg k "$k" '.repos | has($k)' >/dev/null 2>&1 || {
    echo "oss: repo '$k' is not declared (declared: $(printf '%s' "$shape" | jq -r '.repos | keys | join(", ")'))" >&2
    return 2; }
  printf '%s\n' "$k"
}

# Read a jq expression from the discovered manifest. rc 1 if no manifest / null.
oss_manifest_get() { # $1=jq-expr
  local expr="$1" manifest out
  manifest="$(oss_manifest_discover)" || { echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1; }
  out="$(jq -r "${expr} // empty" "$manifest" 2>/dev/null)" || true
  [ -n "$out" ] || return 1
  echo "$out"
}

# Refuse to proceed when no declaration is on the walk-up path (skills call
# early). Checks topology first, then the pairing fallback - same order as
# `oss_topology_discover` itself - so this gate never refuses a workspace that
# discovery would have found.
oss_manifest_require() {
  oss_topology_discover >/dev/null 2>&1 && return 0
  echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1
}

# Resolve the two root tokens + ${HOME}/${USER} in a string. Unknown ${x} tokens
# are LEFT IN PLACE (matching the upstream resolvers) - the CALLER detects them.
# Literal find-and-replace, without bash pattern substitution.
#
# `${s//needle/$repl}` is NOT literal in the replacement half. Under bash 5.2's
# default `patsub_replacement`, an `&` in $repl expands to the whole matched
# text - so a perfectly valid workspace root like `/home/acme&co` turns
# `${ai_workspace.root}/docs/S.md` back into `${ai_workspace.root}...`, and the
# unresolved-token guard downstream then rejects a correctly-configured project.
#
# The obvious fix does not work. Escaping as `${repl//&/\\&}` was MEASURED on
# both: it repairs bash 5.2 and BREAKS bash 3.2, which renders the backslash
# literally (`/home/acme\&co`). macOS ships bash 3.2 and this repo runs on it,
# so an escape-based fix would trade a Linux bug for a mac one. Doing the
# substitution by hand is the only form that is literal on every version.
# (Codex P2, PR #149 round 4.)
_oss_subst_literal() { # $1=haystack $2=needle $3=replacement
  local hay="$1" needle="$2" repl="$3" out="" pre
  [ -n "$needle" ] || { printf '%s' "$hay"; return 0; }
  while :; do
    case "$hay" in
      *"$needle"*)
        pre="${hay%%"$needle"*}"
        out="$out$pre$repl"
        hay="${hay#"$pre$needle"}"
        ;;
      *) out="$out$hay"; break ;;
    esac
  done
  printf '%s' "$out"
}

_oss_manifest_resolve() { # $1=ai-root $2=string
  # $1 is kept for interface stability (every call site already computes it),
  # but it is no longer the substitution source. The vocabulary now comes from
  # the shape - fetched ONCE below via `_oss_shape_file` - so this function
  # never re-discovers a pairing manifest of its own: that re-discovery is
  # exactly what left a topology-only workspace (no `.workspace/pairing.json`
  # to find) failing at a generic "manifest not found" for every token,
  # including ones a topology declaration fully supports (#272/#310 Task 3).
  # $1 and the shape's `.workspace` are the same fact by construction - both
  # trace to the one manifest this session already discovered - and even if a
  # caller's pre-substituted ai-root and the shape's raw `.workspace` disagree
  # on a still-templated `${HOME}`/`${USER}`, the substitutions later in this
  # function self-heal it: they run over the WHOLE result string, including
  # whatever this step just inserted.
  local result="$2" shape aw cn name nroot
  shape="$(_oss_shape_file)" || return 1
  aw="$(printf '%s' "$shape" | jq -r '.workspace // empty' 2>/dev/null)" || true
  [ -n "$aw" ] && result="$(_oss_subst_literal "$result" '${ai_workspace.root}' "$aw")"
  # ${repos.<name>.root} for every declared repo. `while read` off a `jq @tsv`
  # command substitution, not a `for` over it - a `for` over an unquoted
  # command substitution does not word-split under zsh, and would iterate the
  # whole TSV blob once instead of once per repo.
  #
  # $name is read straight off the shape's repo keys, never re-checked against
  # `_oss_repo_key_valid` here. That is fine, not merely tolerated: the name is
  # used only as the NEEDLE half of `_oss_subst_literal`, which does a literal
  # substring search - no eval, no glob, no shell interpretation of it - so even
  # a metacharacter-laden key can only ever build an odd-looking literal search
  # string, never an injection. (The grammar boundary in `_oss_repo_key_valid`
  # guards a DIFFERENT call site - `_oss_repo_root`'s own `--arg k` jq lookup and
  # error-message interpolation - not this one.)
  #
  # Both `$name` and `$nroot` are guarded non-empty (review round 1, Finding 1).
  # A declared-but-empty root is the same trap the ${HOME} comment below already
  # names: substituting it turns `${repos.core.root}/ps.json` into `/ps.json` -
  # a well-formed, root-anchored path manufactured out of an absent value, that
  # then sails straight past the unresolved-token guard downstream. So an empty
  # `$nroot` is treated exactly like an empty `$aw`/`$cn`/`$HOME` above and below:
  # skipped, leaving the token in place for that guard to catch by name.
  # KEYS through @tsv-free iteration, then each root fetched RAW. `@tsv` escapes
  # backslashes - a declared root of `/tmp/a\b` comes back as `/tmp/a\\b`, and
  # `read -r` preserves both characters - so the substitution produced a path
  # that does not exist and `oss init` wrote state beside the declared repo
  # rather than at its routed destination. Repo keys are grammar-checked
  # (`[a-z][a-z0-9_-]*`) so they can carry no tab, newline or backslash of their
  # own; roots can carry anything a filesystem allows, so they never go through
  # a delimiter-encoded channel.
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    nroot="$(printf '%s' "$shape" | jq -r --arg k "$name" '.repos[$k].root // empty' 2>/dev/null)" || continue
    [ -n "$nroot" ] || continue
    result="$(_oss_subst_literal "$result" "\${repos.$name.root}" "$nroot")"
  done <<EOF
$(printf '%s' "$shape" | jq -r '.repos | keys[]' 2>/dev/null)
EOF
  # Legacy alias: ${canonical.root} resolves iff a repo named canonical is
  # declared - always true under the pairing fallback, optional under a
  # topology declaration. When no such repo is declared the token is left in
  # place for the unresolved-token guard below to refuse by name.
  cn="$(printf '%s' "$shape" | jq -r '.repos.canonical.root // empty' 2>/dev/null)" || true
  [ -n "$cn" ] && result="$(_oss_subst_literal "$result" '${canonical.root}' "$cn")"
  # Two failure modes, and only substituting-when-present avoids both. Under the
  # dispatcher's `set -u` a bare `$HOME` with HOME unset is a fatal expansion
  # error raised on the REPLACEMENT side, aborting every state-resolving verb
  # before it can return a diagnostic. But substituting `${HOME:-}` is worse:
  # `${HOME}/demo` collapses to `/demo`, a well-formed path that sails past the
  # unresolved-token guard below and lets `oss init` write outside the intended
  # workspace. So substitute only when HOME is actually set, and otherwise LEAVE
  # THE TOKEN IN PLACE for that guard to reject by name.
  [ -n "${HOME:-}" ] && result="$(_oss_subst_literal "$result" '${HOME}' "$HOME")"
  result="$(_oss_subst_literal "$result" '${USER}' "$(_oss_current_user)")"
  echo "$result"
}

# Shared guard for every well-known-path resolver.
#
# The token half was always here. The ABSOLUTE half is new, and it closes a trap
# that hid behind the token guard: `_oss_manifest_resolve` substitutes `${...}`
# tokens but does NOT join a bare relative value onto the AI-workspace root. So
# `.well_known_paths.project_state = "state.json"` came back unchanged, sailed
# past the token check, and then resolved against whatever directory the session
# happened to start in - two agents in two directories driving two different
# files, which is precisely the failure a well-known path exists to prevent.
# (Codex P2, PR #149.)
# rc 0 if $1 holds a COMPLETE `${PLUGIN_DATA:<name>}` token (#165).
#
# The grammar is workspace-init's, copied deliberately rather than approximated:
# `\$\{PLUGIN_DATA:([a-zA-Z0-9_-]+)\}` (workspace-init/lib/manifest.sh). A substring
# glob on the `${PLUGIN_DATA:` prefix alone was the first spelling and it was wrong -
# it also swallowed `${PLUGIN_DATA:}`, an unterminated `${PLUGIN_DATA:foo`, and
# `${PLUGIN_DATA:foo.bar}`. Those are TYPOS, not supported vocabulary, so the
# unsupported-token message made exactly the malformed-vs-unsupported distinction it
# exists to draw, backwards. Anything failing this test falls through to the generic
# unresolved-token arm, which is the correct answer for a typo.
#
# One helper, two call sites (here and `_oss_repo_root`), so the grammar cannot drift
# between the two refusals the way the wording already did.
_oss_is_plugin_data_token() { # $1=value ; rc 0 if it holds a complete PLUGIN_DATA token
  [[ "$1" =~ \$\{PLUGIN_DATA:[a-zA-Z0-9_-]+\} ]]
}

# The PLUGIN_DATA branch is ordered BEFORE the generic token arm on purpose (#165).
# That token is a documented member of workspace-init's shared manifest vocabulary
# which ossify deliberately does not resolve (#152, wontfix). Reported through the
# generic arm it reads as "you typed this wrong", so the obvious next move - checking
# the token against workspace-init's docs, where it IS valid - leads away from the fix.
# Naming it converts a confusing rejection into a documented limit; it does not fork
# the vocabulary.
_oss_manifest_wellknown_guard() { # $1=resolved $2=what $3=source ; rc 0 if usable
  if _oss_is_plugin_data_token "$1"; then
    echo "oss: $2 path uses \${PLUGIN_DATA:...}, which ossify does not resolve - route it with \${ai_workspace.root}, \${canonical.root}, \${HOME}, \${USER}, or an absolute path (from '$3')" >&2
    return 1
  fi
  case "$1" in
    '')      echo "oss: unresolved $2 path: <empty> (from '$3')" >&2; return 1 ;;
    *'${'*)  echo "oss: unresolved $2 path: '$1' (from '$3')" >&2; return 1 ;;
    /*)      return 0 ;;
    *)       echo "oss: $2 path is not absolute: '$1' (from '$3') - a well-known path that depends on the session's cwd is not well-known" >&2; return 1 ;;
  esac
}

# The AI-workspace root, token-substituted. Both resolvers below need exactly
# this and nothing else, and having it once keeps their two copies from
# drifting. Reads `.workspace` off the shape rather than raw-jqing a manifest
# file directly, so it works unchanged whether the shape came from a topology
# declaration or a translated pairing manifest (#272 design section 2).
_oss_manifest_ai_root() { # echoes the substituted workspace root
  local shape ai_root
  shape="$(_oss_shape_file)" || return 1
  ai_root="$(printf '%s' "$shape" | jq -r '.workspace // empty' 2>/dev/null)" || true
  [ -n "$ai_root" ] || { echo "oss: manifest missing ai_workspace.root" >&2; return 1; }
  [ -n "${HOME:-}" ] && ai_root="$(_oss_subst_literal "$ai_root" '${HOME}' "$HOME")"
  ai_root="$(_oss_subst_literal "$ai_root" '${USER}' "$(_oss_current_user)")"
  printf '%s\n' "$ai_root"
}

# Resolve the ossify state-file path. Honors an optional
# .well_known_paths.project_state key (Plan D may add it); else derives by
# convention <ai_workspace.root>/.ossify/project-state.json.
# Echoes the path (the file itself may not exist yet).
oss_manifest_state_path() {
  local ai_root shape routed dest
  ai_root="$(_oss_manifest_ai_root)" || return 1
  shape="$(_oss_shape_file)" || return 1
  routed="$(printf '%s' "$shape" | jq -r '.well_known_paths.project_state // empty' 2>/dev/null)" || true
  if [ -n "$routed" ]; then
    dest="$(_oss_manifest_resolve "$ai_root" "$routed")" || return 1
  else
    dest="$ai_root/.ossify/project-state.json"
  fi
  _oss_manifest_wellknown_guard "$dest" state "${routed:-convention}" || return 1
  echo "$dest"
}

# Resolve the lean MASTER-SPEC path, the same way and from the same shape.
# `.well_known_paths.master_spec` is the key workspace-init actually writes
# (default `${ai_workspace.root}/docs/MASTER-SPEC.md`), so a resolver that only
# knew the AI-workspace root would miss a customized routed destination and
# report an initialised project as having no spec. `doctor`'s spec-validation
# surface is the consumer. Echoes the path; the file may not exist yet.
oss_manifest_spec_path() {
  local ai_root shape routed dest
  ai_root="$(_oss_manifest_ai_root)" || return 1
  shape="$(_oss_shape_file)" || return 1
  routed="$(printf '%s' "$shape" | jq -r '.well_known_paths.master_spec // empty' 2>/dev/null)" || true
  if [ -n "$routed" ]; then
    dest="$(_oss_manifest_resolve "$ai_root" "$routed")" || return 1
  else
    dest="$ai_root/docs/MASTER-SPEC.md"
  fi
  _oss_manifest_wellknown_guard "$dest" spec "${routed:-convention}" || return 1
  echo "$dest"
}

# Dispatcher glue: resolve the state path for a subcommand.
# Precedence: explicit $1 > $OSS_STATE_FILE (test/override) > manifest-derived.
#
# The env branch names itself on STDERR when it is genuinely overriding a
# manifest-routed project: a stale OSS_STATE_FILE exported by an unrelated
# session silently redirects every read and every write, and nothing else in the
# output says where the path came from.
#
# Two boundaries are deliberate. The notice never goes to stdout — this
# function's stdout IS the state path, and callers consume it as a value. And it
# stays silent when there is no manifest, or when the manifest agrees: nothing is
# being overridden in either case, and a notice on every call is noise the reader
# learns to skip, which is the failure mode this is supposed to prevent.
#
# #171 SETTLED 2026-08-16: the rail stays BLUNT and now says so in its own text —
# the notice names raw-string comparison, so an equivalent spelling reads as the
# rail's known bluntness rather than as real divergence. The alternatives were each
# walked and declined: canonicalization is not coming back (deleted on PR #184 with
# its own do-not-restore note below — path normalization cost this repo four review
# rounds on PR #166 and seven findings across four more rounds on PR #182); `-ef`
# is read-identity and this function's result feeds
# mutating verbs (the exact -ef-on-a-write-target mistake PR #178 paid two P1s for);
# and a refuse-rather-than-warn redesign across all 42 callers would be new
# deterministic gating semantics, which the 2026-08-15 freeze declines. Removing the
# notice entirely was tried on PR #178 and reverted: it is a SAFETY RAIL, not a
# read-out, and docs/conventions/skill-first.md puts "safety rails the agent must
# not argue past" on the deterministic side.
_oss_resolve_state() { # [$1=explicit-path]
  if [ -n "${1:-}" ]; then echo "$1"; return 0; fi
  if [ -n "${OSS_STATE_FILE:-}" ]; then
    local _routed
    _routed="$(oss_manifest_state_path 2>/dev/null)" || _routed=""
    if [ -n "$_routed" ] && [ "$_routed" != "$OSS_STATE_FILE" ]; then
      echo "oss: state path came from \$OSS_STATE_FILE ($OSS_STATE_FILE), overriding the manifest-routed $_routed (paths compared as written; an equivalent spelling of the same file also triggers this notice)" >&2
    fi
    echo "$OSS_STATE_FILE"; return 0
  fi
  oss_manifest_state_path
}

# `_oss_canon_path` was DELETED here (PR #184), closing #151 and #168 without
# either being fixed. It canonicalized a path for identity comparison and had
# exactly two consumers: `oss_interop_check`, which became prose on PR #182, and
# `oss_cmd_doctor`'s repo-vs-state worktree check, which became prose here. With
# both gone it had no callers, so it left with them - function AND its ~21 direct
# test assertions in tests/test-manifest.sh, together.
#
# Do not bring it back. Path normalization has cost this repo four review rounds
# in the bash (PR #166) and seven findings across four more in the prose that
# briefly replaced it (PR #182), and both times the net product value was a path
# normalizer. If you need to compare two paths, prefer a blunt comparison that
# fails SAFE and says what to do about it; see doctor/references/interop-check.md.

oss_cmd_state_path() { _oss_need 0 state_path "" "$@" || return 2; oss_manifest_state_path; }   # `oss state_path` for skills/debug
oss_cmd_spec_path()  { _oss_need 0 spec_path "" "$@" || return 2; oss_manifest_spec_path; }    # `oss spec_path` for doctor's spec surface
