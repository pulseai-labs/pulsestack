#!/usr/bin/env bash
# lib/helpers.sh — cross-platform primitives for membrane.
# Bash 3.2+ compatible (macOS portability).

# csa_sha256 <string> — print the SHA-256 hex digest of the given string.
csa_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  fi
}

# _csa_re_bytes <string> <ere> — [[ <string> =~ <ere> ]] read byte by byte in every locale; BASH_REMATCH is set as
# by =~. In a UTF-8 locale `.` and a negated bracket ([^/]) never match a byte that is not UTF-8 (\351, a Latin-1
# e-acute), on bash 5.2 and 5.3 (#1166). LC_ALL=C is local to this function, so the caller keeps its locale. A prefix
# assignment cannot do it: `LC_ALL=C [[ ... ]]` runs a command named `[[`, rc 127, which under `if` or `||` is a
# false (with `command not found` on stderr) in every locale.
_csa_re_bytes() {
  local LC_ALL=C
  [[ "$1" =~ $2 ]]
}

# csa_is_version_name <name> — exit 0 if <name> looks like a plugin version
# directory: semver-ish (`1.2.3`, `v2.0`, `1.0.0-beta.1`), a 7-40 char lowercase
# hex commit digest, or `unknown`. Claude Code names a cached version one of
# these; the cache layout tells a version directory from a plugin directory by it.
# The ranges are read byte by byte (_csa_re_bytes), so a non-ASCII letter or digit
# is never a version character, in any locale.
csa_is_version_name() {
  local n="${1:-}"
  local semver='^v?[0-9]+(\.[0-9A-Za-z_+-]+)+$' sha='^[0-9a-f]{7,40}$'
  _csa_re_bytes "$n" "$semver" || _csa_re_bytes "$n" "$sha" || [[ "$n" == "unknown" ]]
}

# ---------------------------------------------------------------------------
# The closed-input front door (0.9.0). Skill-first question 2 for the predicates (a fixed alphabet, file kinds, a
# size bound) and question 3 for each refusal: it only adds a stop.
# ---------------------------------------------------------------------------

# csa_printable <string> — rc 0 when every byte of <string> is printable ASCII (0x20-0x7E).
csa_printable() {
  local LC_ALL=C
  [[ "$1" != *[![:print:]]* ]]
}

# csa_escape <string> — <string> with `\` written `\\`, newline, tab and carriage return written `\n` `\t` `\r`, and
# every other byte outside printable ASCII written `\xHH`, so a name from untrusted input is one printable line. One
# whole-string replacement per distinct byte (at most 256), with no subshell: linear in the length for any name.
csa_escape() {
  local LC_ALL=C s="$1" c h
  if [[ "$s" != *[![:print:]]* && "$s" != *\\* ]]; then
    printf '%s' "$s"
    return 0
  fi
  s="${s//\\/\\\\}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  while [[ "$s" == *[![:print:]]* ]]; do
    h="${s%%[![:print:]]*}"
    c="${s:${#h}:1}"
    printf -v h '\\x%02x' "'$c"
    s="${s//"$c"/"$h"}"
  done
  printf '%s' "$s"
}

# csa_root_ok <root> — rc 0 when <root> can be a project root: an absolute path to a directory, holding no byte
# below 0x20 and no 0x7F (it prefixes every target line). Otherwise one `csa:` line on stderr and rc 2.
csa_root_ok() {
  local r="${1-}" LC_ALL=C
  if [[ "$r" != /* ]]; then
    printf 'csa: the project root must be an absolute path (got %s); nothing done\n' "$(csa_escape "$r")" >&2
    return 2
  fi
  if [[ "$r" == *[[:cntrl:]]* ]]; then
    printf 'csa: the project root %s holds a control character; nothing done\n' "$(csa_escape "$r")" >&2
    return 2
  fi
  if [[ ! -d "$r" ]]; then
    printf 'csa: the project root %s is not a directory; nothing done\n' "$(csa_escape "$r")" >&2
    return 2
  fi
  return 0
}

# _csa_lead_slash <path> — <path> with a run of leading slashes cut to one. `pwd -P` keeps a leading `//` (POSIX leaves
# its meaning to the system), so a path spelled `//home/…` would never start with the root `/home/…` it lies in.
_csa_lead_slash() {
  local p="$1"
  while [[ "$p" == //* ]]; do p="${p#/}"; done
  printf '%s' "$p"
}

# csa_root_resolve <root> — csa_root_ok, then the root's physical path (`cd -P`, `pwd -P`, leading slashes cut to
# one), printed: every walk starts there, so a root that is a symlink (`cd` into a linked project dir) is walked as
# the directory it names. rc 2, with one `csa:` line, when csa_root_ok refuses or the root cannot be entered.
csa_root_resolve() {
  local r="${1-}" p
  csa_root_ok "$r" || return 2
  if ! p="$(cd -P -- "$r" 2>/dev/null && pwd -P)" || [[ -z "$p" ]]; then
    printf 'csa: the project root %s cannot be entered; nothing done\n' "$(csa_escape "$r")" >&2
    return 2
  fi
  _csa_lead_slash "$p"
}

# _csa_enum_linked_part <root> <rel> — rc 0, printing the path, when a directory on the way from <root> to <rel>
# (<rel> itself not included) is a symlink; rc 1 otherwise. The enumeration and a plugin.json hooks path use it.
_csa_enum_linked_part() {
  local p="$1" part rest="$2"
  while [[ "$rest" == */* ]]; do
    part="${rest%%/*}"; rest="${rest#*/}"
    p="$p/$part"
    if [[ -L "$p" ]]; then printf '%s' "$p"; return 0; fi
  done
  return 1
}

# csa_tmp_scope <label> — THE one temp helper, for the engine (bin/csa) and the tests. Makes one directory under the
# caller's TMPDIR (/tmp when it is unset, relative or not a directory), exports TMPDIR as that directory so every
# mktemp below it lands there, and removes it on EXIT, INT, TERM and HUP. A signal exits 128 plus its number after
# the removal. Call it once per process; a later `trap … EXIT` in the same shell replaces the removal.
csa_tmp_scope() {
  local parent="${TMPDIR:-/tmp}" d
  [[ "$parent" == /* && -d "$parent" ]] || parent=/tmp
  d="$(mktemp -d "${parent%/}/csa-${1:-run}.XXXXXX")" || return 1
  _CSA_TMP_SCOPE="$d"
  TMPDIR="$d"
  export TMPDIR
  trap '_csa_tmp_scope_end' EXIT
  trap '_csa_tmp_scope_end; exit 129' HUP
  trap '_csa_tmp_scope_end; exit 130' INT
  trap '_csa_tmp_scope_end; exit 143' TERM
}

# _csa_tmp_scope_end — remove the scope directory, made writable first; safe to call twice.
_csa_tmp_scope_end() {
  [[ -n "${_CSA_TMP_SCOPE:-}" ]] || return 0
  # A directory a test made unreadable (mode 000) cannot be emptied until it is readable again.
  chmod -R u+rwx "$_CSA_TMP_SCOPE" 2>/dev/null
  rm -rf "$_CSA_TMP_SCOPE" 2>/dev/null
  _CSA_TMP_SCOPE=""
}

# _CSA_TOOLS — every external command the engine runs. sha256sum or shasum is pinned separately: one of them.
_CSA_TOOLS="awk basename cat chmod cp cut date dirname find grep head jq mkdir mktemp mv rm sed sort tail tr wc"

# _csa_phys_file <path> — the physical path of <path>: each symlink followed (at most 40), directories resolved with
# `cd -P`, leading slashes cut to one (_csa_lead_slash). rc 1 when it cannot be resolved.
_csa_phys_file() {
  local p="$1" n=0 t d
  while [[ -L "$p" ]]; do
    n=$((n + 1)); [[ "$n" -le 40 ]] || return 1
    t="$(readlink -- "$p")" || return 1
    case "$t" in /*) p="$t" ;; *) p="${p%/*}/$t" ;; esac
  done
  d="$(cd -P -- "${p%/*}/" 2>/dev/null && pwd -P)" || return 1
  d="$(_csa_lead_slash "$d")"
  printf '%s/%s' "${d%/}" "${p##*/}"
}

# _csa_pin_tools <dir>... — resolve each tool in _CSA_TOOLS once, from the caller's PATH, to an absolute path, and set
# PATH to the directories those paths sit in (the caller's order), so each tool resolves to the same file for the
# rest of the run. Refuses, rc 2 and one `csa:` line, when a tool is missing, resolves to a relative path, or resolves
# (symlinks followed) inside one of <dir>... (the working directory and the audited root, which the audited project
# can write). Every path is compared with its leading slashes cut to one (_csa_lead_slash), so `//root/bin` is inside
# `/root`. Skill-first question 3: it only adds a stop.
_csa_pin_tools() {
  local t p pc phys d dirs=":" keep="" r rp e
  local -a roots=() parts=()
  for r in "$@"; do
    [[ -n "$r" && -d "$r" ]] || continue
    rp="$(cd -P -- "$r" 2>/dev/null && pwd -P)" || continue
    rp="$(_csa_lead_slash "$rp")"
    roots+=("${rp%/}")
  done
  # readlink first: _csa_phys_file runs it for every tool after it.
  local tools="readlink $_CSA_TOOLS"
  if type -P sha256sum >/dev/null 2>&1; then tools="$tools sha256sum"; else tools="$tools shasum"; fi
  for t in $tools; do
    p="$(type -P "$t" 2>/dev/null)" || p=""
    if [[ -z "$p" ]]; then
      printf 'csa: the tool %s is not on PATH; nothing done\n' "$t" >&2
      return 2
    fi
    if [[ "$p" != /* ]]; then
      printf 'csa: the tool %s resolves to the relative path %s; nothing done\n' "$t" "$(csa_escape "$p")" >&2
      return 2
    fi
    pc="$(_csa_lead_slash "$p")"
    for r in ${roots[@]+"${roots[@]}"}; do
      [[ "$r" == / || "$pc" == "$r"/* ]] || continue
      printf 'csa: the tool %s resolves to %s, inside %s, which the audited project can write; refusing to run\n' \
        "$t" "$(csa_escape "$p")" "$(csa_escape "$r")" >&2
      return 2
    done
    phys="$(_csa_phys_file "$p")" || phys="$pc"
    for r in ${roots[@]+"${roots[@]}"}; do
      [[ "$phys" == "$r"/* ]] || continue
      printf 'csa: the tool %s resolves to %s, inside %s, which the audited project can write; refusing to run\n' \
        "$t" "$(csa_escape "$phys")" "$(csa_escape "$r")" >&2
      return 2
    done
    d="${p%/*}"; while [[ "$d" == ?*/ ]]; do d="${d%/}"; done; [[ -n "$d" ]] || d=/
    dirs="$dirs$d:"
  done
  # The kept directories in the caller's PATH order, so no kept directory comes before the one a tool resolved from.
  IFS=: read -r -a parts <<< "$PATH"
  for e in ${parts[@]+"${parts[@]}"}; do
    d="$e"; while [[ "$d" == ?*/ ]]; do d="${d%/}"; done
    case "$dirs" in *":$d:"*) : ;; *) continue ;; esac
    case ":$keep:" in *":$e:"*) : ;; *) keep="${keep:+$keep:}$e" ;; esac
  done
  PATH="$keep"
  export PATH
  hash -r
}
