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

# csa_realpath <path> — resolve symlinks and .. traversal; print absolute path.
csa_realpath() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1" 2>/dev/null && return 0
  fi
  local target="$1"
  if [[ -d "$target" ]]; then
    (cd "$target" 2>/dev/null && pwd)
  elif [[ -f "$target" ]]; then
    local dir; dir="$(dirname "$target")"
    local base; base="$(basename "$target")"
    (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$base")
  else
    printf '%s\n' "$target"
  fi
}

# csa_sed_inplace <sed_expr> <file> — portable in-place sed (GNU + BSD).
csa_sed_inplace() {
  local expr="$1"; local file="$2"
  if sed --version >/dev/null 2>&1; then
    sed -i "$expr" "$file"
  else
    sed -i '' "$expr" "$file"
  fi
}

# csa_mkdir_lock <lock_dir_path> <label> — atomic lock acquisition via mkdir.
# Returns 0 on first acquire, 1 if already locked.
csa_mkdir_lock() {
  local lock_dir="$1"; local label="$2"
  if mkdir "$lock_dir" 2>/dev/null; then
    {
      printf 'pid=%d\n' "$$"
      printf 'host=%s\n' "$(hostname 2>/dev/null || echo unknown)"
      printf 'iso=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf 'label=%s\n' "$label"
    } > "$lock_dir/info"
    return 0
  fi
  return 1
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
csa_is_version_name() {
  local n="${1:-}"
  local semver='^v?[0-9]+(\.[0-9A-Za-z_+-]+)+$' sha='^[0-9a-f]{7,40}$'
  [[ "$n" =~ $semver || "$n" =~ $sha || "$n" == "unknown" ]]
}
