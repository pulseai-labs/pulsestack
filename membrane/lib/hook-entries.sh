#!/usr/bin/env bash
# lib/hook-entries.sh — structural reader for hook entries declared in JSON (#427).
# Requires: jq; lib/helpers.sh (csa_sha256), lib/redact.sh, lib/fingerprint.sh for
# the finding helpers. Bash 3.2+ compatible (macOS portability).
#
# Skill-first (docs/conventions/skill-first.md): this is question 3. Walking a
# JSON structure is mechanical work on open input (attacker-chosen command
# text). It can only add a stop: every readable command goes through the same
# common-pattern HOOK rules as a hook script, every piece it cannot read is a
# High finding, and what it misses goes on to the operator's own reading exactly
# as if this reader were absent. No model reads hook text, and nothing here
# approves anything.

# Idempotent: the engine and every HOOK rule source this file.
if [[ -n "${_CSA_HOOK_ENTRIES_LOADED:-}" ]]; then return 0; fi
_CSA_HOOK_ENTRIES_LOADED=1

# Walks .hooks.<Event>[i].hooks[j] only. $base is the json_path prefix of the
# event map. The text a pattern sees for a command entry is `command` joined by
# spaces with each string of `args` (exec form).
_CSA_HOOK_JQ_DEFS='
def pk: if test("^[A-Za-z_][A-Za-z0-9_]*$") then "." + . else "[" + tojson + "]" end;
def inc($p; $why): {json_path: $p, inconclusive: $why};
def walk_events($base):
  if type != "object" then inc($base; "hooks value is not an object")
  else to_entries[] | .key as $ev | .value as $gs | ($base + ($ev | pk)) as $ep
    | if ($gs | type) != "array" then inc($ep; "event value is not an array")
      else ($gs | to_entries[]) | .key as $i | .value as $g | ($ep + "[" + ($i | tostring) + "]") as $gp
        | if ($g | type) != "object" then inc($gp; "matcher group is not an object")
          elif ($g.hooks | type) != "array" then inc($gp + ".hooks"; "hooks of a matcher group is not an array")
          else ($g.hooks | to_entries[]) | .key as $j | .value as $h | ($gp + ".hooks[" + ($j | tostring) + "]") as $hp
            | if ($h | type) != "object" then inc($hp; "hook entry is not an object")
              elif ($h.type | type) != "string" then inc($hp + ".type"; "hook entry has no string type")
              elif $h.type != "command" then {json_path: $hp, type: $h.type}
              elif ($h.command | type) != "string" then inc($hp + ".command"; "command is missing or not a string")
              elif ($h | has("args")) and (($h.args | type) != "array") then inc($hp + ".args"; "args is not an array")
              elif (($h.args // []) | map(select(type != "string")) | length) > 0 then inc($hp + ".args"; "args holds a non-string item")
              else {json_path: ($hp + ".command"), type: "command", text: (([$h.command] + ($h.args // [])) | join(" "))}
              end
          end
      end
  end;
'

_CSA_HOOK_JQ_WRAPPED='
  if type != "object" then inc("$"; "file is not a JSON object")
  elif has("hooks") | not then empty
  else .hooks | walk_events("hooks")
  end'

_CSA_HOOK_JQ_MANIFEST='
  if type != "object" then inc("$"; "file is not a JSON object")
  elif has("hooks") | not then empty
  else .hooks as $h
    | if ($h | type) == "object" then $h | walk_events("hooks")
      elif ($h | type) == "string" then {ref: $h, base: "hooks"}
      elif ($h | type) == "array" then
        ($h | to_entries[]) | .key as $i | .value as $v | ("hooks[" + ($i | tostring) + "]") as $bp
        | if ($v | type) == "object" then $v | walk_events($bp)
          elif ($v | type) == "string" then {ref: $v, base: $bp}
          else inc($bp; "hooks array item is neither an event map nor a path")
          end
      else inc("hooks"; "hooks field is neither an object, a path nor an array")
      end
  end'

# _csa_hook_inc <json_path> <why> — one inconclusive line.
_csa_hook_inc() {
  jq -nc --arg p "$1" --arg w "$2" '{json_path: $p, inconclusive: $w}'
}

# _csa_hook_wrapped_lines <file> — wrapped-mode lines for one file.
_csa_hook_wrapped_lines() {
  local file="$1"
  if [[ ! -f "$file" || ! -r "$file" ]]; then
    _csa_hook_inc '$' "file is not a readable regular file"
    return 0
  fi
  if ! jq empty "$file" >/dev/null 2>&1; then
    _csa_hook_inc '$' "file is not valid JSON"
    return 0
  fi
  jq -c "$_CSA_HOOK_JQ_DEFS $_CSA_HOOK_JQ_WRAPPED" "$file" 2>/dev/null \
    || _csa_hook_inc '$' "hooks could not be walked"
  return 0
}

# _csa_hook_walk_ref <manifest> <ref> <base> — a plugin.json hooks path: resolved
# inside the plugin root (the manifest's grandparent) with a physical containment
# check, then walked in wrapped mode. Prints inconclusive lines on failure.
_csa_hook_walk_ref() {
  local manifest="$1" ref="$2" base="$3"
  local root rootp dir phys prefix
  root="$(dirname -- "$(dirname -- "$manifest")")"
  if [[ -z "$ref" || "$ref" == /* ]]; then
    _csa_hook_inc "$base" "hooks path is empty or absolute; not read"
    return 0
  fi
  rootp="$(cd -P -- "$root" 2>/dev/null && pwd -P)" || { _csa_hook_inc "$base" "plugin root cannot be entered"; return 0; }
  dir="$(cd -P -- "$(dirname -- "$root/$ref")" 2>/dev/null && pwd -P)" \
    || { _csa_hook_inc "$base" "hooks path $ref is missing"; return 0; }
  phys="$dir/$(basename -- "$ref")"
  case "$phys" in
    "$rootp"/?*) : ;;
    *) _csa_hook_inc "$base" "hooks path $ref escapes the plugin root; not read"; return 0 ;;
  esac
  if [[ -L "$phys" ]]; then
    _csa_hook_inc "$base" "hooks path $ref is a symlink; not followed"
    return 0
  fi
  if [[ ! -f "$phys" || ! -r "$phys" ]]; then
    _csa_hook_inc "$base" "hooks path $ref is missing or not a readable regular file"
    return 0
  fi
  # hooks/hooks.json is a scan target of its own: reading it here would double it.
  [[ "$phys" == "$rootp/hooks/hooks.json" ]] && return 0
  prefix="$base->$ref:"
  _csa_hook_wrapped_lines "$phys" | jq -c --arg p "$prefix" '.json_path = $p + .json_path'
}

# csa_hook_entries <file> <wrapped|plugin-hooks|plugin-manifest>
# One JSON line per hook entry:
#   {json_path, type: "command", text}   a command entry, decoded
#   {json_path, type}                    any other type: counted, not inspected
#   {json_path, module}                  a modules path, resolved inside hooks/ (plugin-hooks only)
#   {json_path, inconclusive: "<why>"}   a piece that could not be read
# wrapped reads the top-level `hooks` key (settings.json, settings.local.json).
# plugin-hooks is wrapped plus the `modules` list of a plugin's hooks/hooks.json.
# plugin-manifest reads plugin.json's `hooks` field: an inline event map (no
# wrapper), a path inside the plugin root, or an array of both.
csa_hook_entries() {
  local file="${1-}" mode="${2-}" line ref base
  case "$mode" in
    wrapped) _csa_hook_wrapped_lines "$file"; return 0 ;;
    plugin-hooks) _csa_hook_wrapped_lines "$file"; _csa_hook_module_lines "$file"; return 0 ;;
    plugin-manifest) : ;;
    *) printf 'csa_hook_entries: unknown mode %s\n' "$mode" >&2; return 2 ;;
  esac
  if [[ ! -f "$file" || ! -r "$file" ]]; then
    _csa_hook_inc '$' "file is not a readable regular file"
    return 0
  fi
  if ! jq empty "$file" >/dev/null 2>&1; then
    _csa_hook_inc '$' "file is not valid JSON"
    return 0
  fi
  local lines
  lines="$(jq -c "$_CSA_HOOK_JQ_DEFS $_CSA_HOOK_JQ_MANIFEST" "$file" 2>/dev/null)" \
    || { _csa_hook_inc '$' "hooks could not be walked"; return 0; }
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in
      '{"ref":'*)
        ref="$(printf '%s' "$line" | jq -r .ref)"
        base="$(printf '%s' "$line" | jq -r .base)"
        _csa_hook_walk_ref "$file" "$ref" "$base"
        ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <<< "$lines"
  return 0
}

# csa_hook_entry_command <entry-json> — print the decoded command text of a
# command entry; rc 1 (and no output) for anything else; rc 2 when jq itself
# fails, so a caller can tell "not a command" from "could not read it" (#1072 C10).
csa_hook_entry_command() {
  local t
  t="$(printf '%s' "$1" | jq -j 'select(.type == "command" and (.text | type) == "string") | .text' 2>/dev/null)" || return 2
  [[ -n "$t" ]] || return 1
  printf '%s' "$t"
}

# csa_hook_entry_emit <rule_id> <severity> <entry-json> <file> — one finding for
# a command entry. line 0, offset 0, context.json_path. The preview is the
# redacted command. The uid takes the first 24 hex characters of the sha256 of
# json_path plus the FULL decoded command, short enough that csa_redact (which
# csa_finding_uid applies) neither masks nor truncates it, so path and command
# length never hide a difference. csa_finding_uid itself keeps 32 bits (8 hex
# characters), so two different commands share a uid only by a 32-bit collision
# (about 1 in 4.3 billion per pair); reformatting the file changes nothing.
csa_hook_entry_emit() {
  local rule_id="$1" sev="$2" entry="$3" file="$4" text jp preview digest fuid sep
  text="$(csa_hook_entry_command "$entry")" || return $?
  jp="$(printf '%s' "$entry" | jq -r '.json_path // ""')"
  preview="$(csa_redact "$text")"
  sep="$(printf '\xe2\x90\x9f')"
  digest="$(csa_sha256 "${jp}${sep}${text}")"
  # 24 hex characters: under csa_redact's 32-character mask and 200-character cap,
  # so the whole digest reaches the uid however long the json path is.
  fuid="$(csa_finding_uid "$rule_id" "$file" "${digest:0:24}")"
  jq -nc --arg rule_id "$rule_id" --arg file "$file" --arg preview "$preview" \
    --arg severity "$sev" --arg fuid "$fuid" --arg jp "$jp" \
    '{rule_id: $rule_id, file: $file, line: 0, offset: 0, preview: $preview, severity: $severity, finding_uid: $fuid, context: {json_path: $jp}}'
}

# --- Hook handler code (0.8.0) ------------------------------------------------------
# Skill-first question 3: path tests on open input (file names, an attacker-written JSON list) that can only add a
# stop. A file they do not read is unread exactly as before 0.8.0 and goes to the operator's own reading; a modules
# path they cannot place is a HOOK-005 stop. The suffix and directory lists are a closed vocabulary (question 2).

# _csa_hook_code_suffix <name> — rc 0 when <name> ends in a suffix a hook runtime loads as code: the Claude Code
# module loader's (.ts .tsx .jsx .js .mjs .cjs .mts .cts) and .py.
_csa_hook_code_suffix() {
  case "$1" in
    *.ts|*.tsx|*.jsx|*.js|*.mjs|*.cjs|*.mts|*.cts|*.py) return 0 ;;
  esac
  return 1
}

# _csa_hook_rel_skipped <rel> — rc 0 when a path below a hooks/ dir sits under tests/, test/, fixtures/ or
# node_modules/: test and vendored copies are not handlers.
_csa_hook_rel_skipped() {
  case "/$1" in
    */tests/*|*/test/*|*/fixtures/*|*/node_modules/*) return 0 ;;
  esac
  return 1
}

# _csa_hook_rel_is_code <rel> — rc 0 when a path below a hooks/ dir is handler code: a code suffix, not a .d.ts,
# *.test.* or *.spec.* file, and not under a skipped dir.
_csa_hook_rel_is_code() {
  local name="${1##*/}"
  _csa_hook_rel_skipped "$1" && return 1
  case "$name" in
    *.d.ts|*.test.*|*.spec.*) return 1 ;;
  esac
  _csa_hook_code_suffix "$name"
}

# csa_hook_handler_file <target> — rc 0 when HOOK-001 to HOOK-004 read <target> as a hook handler beyond the
# surfaces they read already (`*.sh`, `.opencode/`, an executable `.claude/hooks/` file, JSON hook entries):
#   - handler code under an enabled plugin's hooks/ dir (normalized @plugin:<plugin>@<marketplace>:hooks/...): a
#     Claude Code hooks module, every file it imports from there, and the node or python handlers a hook command
#     runs from there;
#   - an executable regular file under a plugin's hooks/ dir with no code suffix (hooks/session-start,
#     hooks/run-hook.cmd), as an executable .claude/hooks/ file has been read since 0.1.6;
#   - handler code under the project's own .claude/hooks/ (the audit root's, by full path), whatever its mode
#     (settings run `python3 .claude/hooks/x.py`).
# By the layout the runtime reads, never by a path parsed out of command text. A plugin file is judged by the plugin
# layout only, so a plugin's fixtures/ copy of a .claude/hooks/ is not read, nor is any other .claude/hooks/ dir (a
# local/ plugin's). A handler outside hooks/ (a command that runs scripts/x.mjs, a module importing ../lib/x.ts) is
# not read, exactly as before.
csa_hook_handler_file() {
  local t="$1" n="" rel root="${_CSA_ENGINE_ROOT:-${CSA_PROJECT_ROOT:-}}"
  # Both branches below need a /hooks/ segment: a cheap test first, before the path is normalized.
  [[ "$t" == */hooks/* ]] || return 1
  declare -F csa_normalize_path >/dev/null 2>&1 && n="$(csa_normalize_path "$t")"
  if [[ "$n" == @plugin:* ]]; then
    _csa_re_bytes "$n" '^@plugin:[^:/]+@[^:/]+:hooks/(.+)$' || return 1
    rel="${BASH_REMATCH[1]}"
    _csa_hook_rel_is_code "$rel" && return 0
    _csa_hook_rel_skipped "$rel" && return 1
    _csa_hook_code_suffix "${rel##*/}" && return 1
    [[ -f "$t" && ! -L "$t" && -x "$t" ]]
    return
  fi
  while [[ "$root" == ?*/ ]]; do root="${root%/}"; done
  [[ -n "$root" && "$t" == "$root/.claude/hooks/"?* ]] || return 1
  _csa_hook_rel_is_code "${t#"$root/.claude/hooks/"}"
}

# A plugin hooks/hooks.json's "modules" list: one path per Claude Code hooks module, relative to the file. One line
# per item, {json_path, mod} for a string; an inconclusive line for a value that is not a list, an item that is not a
# string, or a string holding a control character (it cannot be resolved as written).
_CSA_HOOK_JQ_MODULES='
  if type != "object" then empty
  elif has("modules") | not then empty
  elif (.modules | type) != "array" then inc("modules"; "modules is not a list")
  else .modules | to_entries[] | ("modules[" + (.key | tostring) + "]") as $p
    | if (.value | type) != "string" then inc($p; "module path is not a string")
      elif (.value | test("[\u0000-\u001f\u007f]")) then inc($p; "module path holds a control character; not read")
      else {json_path: $p, mod: .value}
      end
  end'

# _csa_hook_module_line <hooks-json> <json_path> <path> — one line for one modules item: {json_path, module: <path
# below hooks/>} when it resolves to a regular file physically inside the plugin's hooks/ dir that HOOK-001 to
# HOOK-004 read as handler code (the module is then read as its own target); otherwise an inconclusive line, a
# HOOK-005 stop. Resolved as _csa_hook_walk_ref resolves a plugin.json hooks path: physical containment, and a
# symlink is never followed. Skill-first question 3: a JSON manifest's paths are open input, and this can only add
# a stop; a path it cannot place is a HOOK-005, never a pass.
_csa_hook_module_line() {
  local file="$1" jp="$2" ref="$3" hdir hooksp dir phys rel
  if [[ -z "$ref" || "$ref" == /* ]]; then
    _csa_hook_inc "$jp" "module path is empty or absolute; not read"
    return 0
  fi
  hdir="$(dirname -- "$file")"
  hooksp="$(cd -P -- "$hdir" 2>/dev/null && pwd -P)" || { _csa_hook_inc "$jp" "hooks dir cannot be entered"; return 0; }
  dir="$(cd -P -- "$(dirname -- "$hdir/$ref")" 2>/dev/null && pwd -P)" \
    || { _csa_hook_inc "$jp" "module path $ref is missing"; return 0; }
  phys="$dir/$(basename -- "$ref")"
  case "$phys" in
    "$hooksp"/?*) : ;;
    *) _csa_hook_inc "$jp" "module path $ref is outside the plugin's hooks/ dir; not read"; return 0 ;;
  esac
  if [[ -L "$phys" ]]; then
    _csa_hook_inc "$jp" "module path $ref is a symlink; not followed"
    return 0
  fi
  if [[ ! -f "$phys" || ! -r "$phys" ]]; then
    _csa_hook_inc "$jp" "module path $ref is missing or not a readable regular file"
    return 0
  fi
  rel="${phys#"$hooksp"/}"
  if ! _csa_hook_rel_is_code "$rel"; then
    _csa_hook_inc "$jp" "module path $ref is not handler code the audit reads; not read"
    return 0
  fi
  jq -nc --arg p "$jp" --arg m "$rel" '{json_path: $p, module: $m}'
}

# _csa_hook_module_lines <hooks-json> — the module lines of a plugin hooks/hooks.json. A file that is not readable
# JSON prints nothing here: the hooks walk of the same file reports it.
_csa_hook_module_lines() {
  local file="$1" lines line jp ref
  [[ -f "$file" && -r "$file" ]] || return 0
  jq empty "$file" >/dev/null 2>&1 || return 0
  lines="$(jq -c "$_CSA_HOOK_JQ_DEFS $_CSA_HOOK_JQ_MODULES" "$file" 2>/dev/null)" \
    || { _csa_hook_inc 'modules' "modules could not be read"; return 0; }
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$(printf '%s' "$line" | jq -r 'has("mod")')" != "true" ]]; then
      printf '%s\n' "$line"
      continue
    fi
    jp="$(printf '%s' "$line" | jq -r .json_path)"
    ref="$(printf '%s' "$line" | jq -r .mod)"
    _csa_hook_module_line "$file" "$jp" "$ref"
  done <<< "$lines"
  return 0
}
