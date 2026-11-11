#!/usr/bin/env bash
# lib/fingerprint.sh — two-layer fingerprint per SPEC §9.1 + T2-I.
# Requires: lib/helpers.sh (csa_sha256, csa_is_version_name, _csa_re_bytes), lib/redact.sh (csa_redact).

# _csa_squeeze_excerpt <match_text> — whitespace runs to one space, ends trimmed. Nothing else.
_csa_squeeze_excerpt() {
  printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'
}

# csa_canonicalize_excerpt <match_text>
csa_canonicalize_excerpt() {
  local m; m="$(_csa_squeeze_excerpt "$1")"
  csa_redact "$m"
}

# csa_normalize_path <file_path>
# A plugin file's id must survive a version bump. Claude Code's cache layout is
# cache/<marketplace>/<plugin>/<version>/<rest>: that becomes
# `@plugin:<plugin>@<marketplace>:<rest>`. The older two-level layout,
# cache/<plugin>/<version>/<rest>, becomes `@plugin:<plugin>:<rest>`. The two
# differ only by depth, so the second segment decides: a version-named second
# segment means the two-level layout, and anything else is three-level, so a
# version with an unusual name (1, latest, a date) still drops out of the id.
# A version-named second segment followed by a version-named third is the
# three-level layout: a plugin named like a version (`unknown`, `deadbeef`),
# whose version dir Claude Code names a version too (#1147).
csa_normalize_path() {
  local p="$1"
  local re3='/\.claude/plugins/cache/([^/]+)/([^/]+)/([^/]+)/(.+)$'
  local re2='/\.claude/plugins/cache/([^/]+)/[^/]+/(.+)$'
  if _csa_re_bytes "$p" "$re3"; then
    # csa_is_version_name runs its own =~, which would clobber BASH_REMATCH.
    local mkt="${BASH_REMATCH[1]}" plug="${BASH_REMATCH[2]}" ver="${BASH_REMATCH[3]}" rest="${BASH_REMATCH[4]}"
    if ! csa_is_version_name "$plug" || csa_is_version_name "$ver"; then
      printf '@plugin:%s@%s:%s' "$plug" "$mkt" "$rest"
      return
    fi
  fi
  if _csa_re_bytes "$p" "$re2"; then
    printf '@plugin:%s:%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return
  fi
  # Trailing slashes off the root, as the engine does (#1072 C8); "/" stays "/".
  local root="${CSA_PROJECT_ROOT:-}"
  while [[ "$root" == ?*/ ]]; do root="${root%/}"; done
  if [[ -n "$root" && "$p" == "$root"/* ]]; then
    printf '%s' "${p#"$root"/}"
  else
    printf '%s' "$p"
  fi
}

# csa_finding_uid <rule_id> <file_path> <match_excerpt>
# DURABLE — no line number. Format: FUID-<8 hex chars>.
csa_finding_uid() {
  local rule_id="$1"; local file_path="$2"; local match="$3"
  local norm_path; norm_path="$(csa_normalize_path "$file_path")"
  local canon; canon="$(csa_canonicalize_excerpt "$match")"
  local full; full="$(csa_sha256 "${rule_id}|${norm_path}|${canon}")"
  printf 'FUID-%s' "${full:0:8}"
}

# csa_finding_uid_raw <rule_id> <file_path> <match_excerpt>
# The uid for a caller whose excerpt is free text of any length (a grep line, a JSON
# value). csa_finding_uid hashes the REDACTED excerpt, and csa_redact caps it at 200 characters (bytes under bin/csa's LC_ALL=C) and
# masks every secret-like run to its first and last four, so two long excerpts that share their first
# 200 characters, or their redacted form, share a uid, and a crafted finding can then share a suppressed
# finding's uid (#1072 C11). This one hashes the whitespace-squeezed excerpt itself, so no character
# is lost. The excerpt only ever reaches sha256: it is never printed, stored or logged; the uid keeps
# 8 hex characters. An excerpt under the cap with nothing to mask hashes as csa_finding_uid does, so
# only the capped or masked ones get a new uid. Same format, same path normalization.
# Skill-first question 2: our own digest over a closed shape (rule id, path, excerpt).
csa_finding_uid_raw() {
  local rule_id="$1"; local file_path="$2"; local match="$3"
  local norm_path; norm_path="$(csa_normalize_path "$file_path")"
  local canon; canon="$(_csa_squeeze_excerpt "$match")"
  local full; full="$(csa_sha256 "${rule_id}|${norm_path}|${canon}")"
  printf 'FUID-%s' "${full:0:8}"
}

# csa_dedup_fingerprint <rule_id> <file_path> <line_number> <match_excerpt>
# PER-RUN — includes line number. Returns full 64-char sha256.
csa_dedup_fingerprint() {
  local rule_id="$1"; local file_path="$2"; local line="$3"; local match="$4"
  local norm_path; norm_path="$(csa_normalize_path "$file_path")"
  local canon; canon="$(csa_canonicalize_excerpt "$match")"
  csa_sha256 "${rule_id}|${norm_path}|${line}|${canon}"
}
