#!/usr/bin/env bash
RULE_ID="HOOK-004"
RULE_NAME="network-exfiltration"
RULE_ASPECT="hooks"
RULE_SEVERITY="high"
RULE_DESCRIPTION="Hook script combines a network-call command with a sensitive credential/config path — potential data exfiltration."
RULE_AUTO_FIXABLE="false"
RULE_MECHANICALLY_FIXABLE="false"
RULE_REMEDIATION="Review the hook for unintended data exfiltration. Ensure network calls do not reference SSH keys, AWS credentials, or system password files."
RULE_REFERENCES=""

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  _RULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
  _RULE_DIR="${CSA_LIB_DIR:-}"
fi
# shellcheck source=/dev/null
source "$_RULE_DIR/redact.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$_RULE_DIR/fingerprint.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$_RULE_DIR/helpers.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$_RULE_DIR/hook-entries.sh" 2>/dev/null || true

# The names are the source: each alternative is built from its name, and the excerpt's names are read from the same
# arrays, so a name cannot be dropped or shifted apart from the alternative it names (#1098). The names are their own
# arrays (not derived from the regex text) so the uid keeps the 0.5.1 names, and a file that fires on the same names
# and lines keeps its uid (#1113).
# Network names: a leading boundary (start, a byte that is not a letter, digit, "_", "." or "-", or a backslash and
# n, r or t, the escaped newline, CR or tab of a JSON, JS or $'...' string) keeps "async",
# "sync", "func", "openssh " and ".curlrc" from naming nc, ssh, curl or wget, and keeps "~/.ssh " from naming ssh.
# curl, wget and rsync end at a non-letter or the end ("curly", "curling" and "rsyncd" do not name them; "curl.exe",
# "wget2" and "curl_chrome116" do). nc, ssh and scp end at whitespace, so "ssh-keygen" and "ssh-add" do not name ssh.
# Sensitive names have their dots escaped: the "." in "~/.ssh" is a dot, not any byte or a newline. The three "~/" names
# are preceded by the home root group below.
# Lost on purpose, named in the CHANGELOG: a name after a letter, digit, "_", "." or "-" ("run_curl", "x-curl", "sh.curl(",
# "${CURL:-curl}", "curlie" and "pycurl" at their ends).
# 0.7.1 adds nc's other binary names (ncat, netcat, nc.openbsd, nc.traditional), the socat relay, sftp, ftp, tftp and
# telnet; they end at whitespace like nc, so "netcat-openbsd" and "sftp-server" do not name them, and the dot of
# "nc.openbsd" is escaped. Every whitespace-ended name also fires as a whole quoted word, a quote on both sides
# ('scp', "ssh", the argv element of spawn, execFile or subprocess), as "curl" and "rsync" already did: "use ssh",
# "ssh-keygen" and "sshd" do not. A new name that starts with n, t or f (ncat, netcat, nc.openbsd, nc.traditional,
# tftp, telnet, ftp) takes no bare backslash before it (_RULE_LEAD_NRT): "\ncat", "\telnet" and "\ftp" are an escaped
# newline, tab or form feed then "cat", "elnet" or "tp", not ncat, telnet or ftp; "\nncat", "\ttelnet" and "\nftp"
# still fire through the escape branch. nc, ssh and scp keep 0.5.2's lead. "/dev/tcp/" and "/dev/udp/" are bash's own socket call: they need the trailing slash ("/dev/tcp
# are disabled" does not fire), take no lead, and the uid names them "/dev/tcp" and "/dev/udp".
# Still silent on purpose, named in the CHANGELOG: an uppercase name or path ("CURL", "SSH", "~/.SSH"), a backtick-quoted
# name, language network APIs (fetch, requests, http.request), tool CLIs (aws s3 cp, gh gist, rclone, git push),
# "python -m http.server" and "openssl s_client".
# ERE only: no \b, \< or [[:<:]], which are not portable. Not run on bash 3.2 or BSD grep (CI is ubuntu). A backslash
# inside a bracket expression is literal in POSIX ERE, so [^\A-Za-z...] excludes it.
_RULE_NETWORK_NAMES=('curl' 'wget' 'nc' 'ssh' 'scp' 'rsync' 'ncat' 'netcat' 'nc.openbsd' 'nc.traditional' 'socat' 'sftp' 'ftp'
  'tftp' 'telnet' '/dev/tcp' '/dev/udp')
_RULE_SENSITIVE_NAMES=('~/.ssh' '~/.gnupg' '~/.aws' '/etc/passwd')
_RULE_LEAD='(^|[^A-Za-z0-9_.-]|\\[nrt])'
_RULE_LEAD_NRT='(^|[^\A-Za-z0-9_.-]|\\[nrt])'
# The three dot-dirs match under any home root, for any user: "~", "$HOME" and "${HOME}" (each optionally followed by a
# closing quote, as in "$HOME"/.ssh), "/home/<one segment>", "/Users/<one segment>" and "/root". The names above stay
# "~/.ssh" etc., so the names part of the uid is unchanged. "/etc/passwd" has no root. The bracket forms [$] and [{]
# keep the pattern free of backslash escapes, which bash and grep read the same way. A root is not anchored on the left ("/var/root/.ssh" fires).
# Silent on purpose, named in the CHANGELOG: "${HOME:-x}", "~user", "$HOMEDIR", "$HOME_OLD" and a project path such as
# "/home/me/proj/.ssh" (a second segment), and any path held in a variable, "os.homedir()" or "Path.home()".
_RULE_HOME_ROOT='(~|[$]HOME"?|[$][{]HOME[}]"?|/home/[^/[:space:]]+|/Users/[^/[:space:]]+|/root)'
_RULE_NETWORK_ALTS=()
for _n in "${_RULE_NETWORK_NAMES[@]}"; do
  _e="${_n//./\\.}"
  case "$_n" in
    curl|wget|rsync)           _RULE_NETWORK_ALTS+=("${_RULE_LEAD}${_e}([^A-Za-z]|\$)") ;;
    /dev/tcp|/dev/udp)         _RULE_NETWORK_ALTS+=("${_e}/") ;;
    nc|ssh|scp|socat|sftp)     _RULE_NETWORK_ALTS+=("(${_RULE_LEAD}${_e}[[:space:]]|['\"]${_e}['\"])") ;;
    *)                         _RULE_NETWORK_ALTS+=("(${_RULE_LEAD_NRT}${_e}[[:space:]]|['\"]${_e}['\"])") ;;
  esac
done
unset _e
_RULE_SENSITIVE_ALTS=()
for _n in "${_RULE_SENSITIVE_NAMES[@]}"; do
  case "$_n" in
    '~/'*) _n="${_n#\~}"; _RULE_SENSITIVE_ALTS+=("${_RULE_HOME_ROOT}${_n//./\\.}") ;;
    *)     _RULE_SENSITIVE_ALTS+=("${_n//./\\.}") ;;
  esac
done
unset _n
RULE_NETWORK_RE="$(IFS='|'; printf '%s' "${_RULE_NETWORK_ALTS[*]}")"
RULE_SENSITIVE_RE="$(IFS='|'; printf '%s' "${_RULE_SENSITIVE_ALTS[*]}")"

# _csa_hook004_excerpt <content> — what the uid hashes (#1098): the names of the alternatives that fire
# ("net=..;path=.."), then, when some line holds both a network and a sensitive match, ";lines=" and the sha256 of
# those lines. The line bytes are kept exact: a trailing CR is dropped, leading and trailing spaces and tabs are
# trimmed, and the set is byte-sorted without duplicates. Nothing is squeezed inside a line, so two lines that
# differ inside their trimmed ends never share a digest, and the digest holds no whitespace, so the squeeze in
# csa_finding_uid_raw cannot equate two line sets. One test per alternative and no loop over matches (that is
# quadratic on a file of many matches).
# The whole function runs under a local LC_ALL=C, as _csa_hook004_match does for detection, so the names and the line part
# are both byte-wise and give the same uid in every locale. Bash 3.2's restore of a local LC_ALL is unverified (measured
# on bash 5.3 only).
# Skill-first: the names part is question 2, membrane's own fixed alternatives. The line part reads open text, but
# it can only split a uid relative to the names part, so what it mishandles either reads NEW, an extra stop (a quote
# change, any whitespace change inside a line), or adds no line and leaves the uid on the names floor (a command
# split across lines, a path in a variable). The caller hashes this with
# csa_finding_uid_raw: the plain form would cap it at 200 characters. The lines go only to sha256, never to output.
_csa_hook004_excerpt() {
  local LC_ALL=C c="$1" i a net="" path="" lines cr=$'\r' tab=$'\t'
  for i in "${!_RULE_NETWORK_ALTS[@]}"; do
    a="${_RULE_NETWORK_ALTS[$i]}"
    [[ "$c" =~ $a ]] && net+="${net:+,}${_RULE_NETWORK_NAMES[$i]}"
  done
  for i in "${!_RULE_SENSITIVE_ALTS[@]}"; do
    a="${_RULE_SENSITIVE_ALTS[$i]}"
    [[ "$c" =~ $a ]] && path+="${path:+,}${_RULE_SENSITIVE_NAMES[$i]}"
  done
  lines="$(printf '%s\n' "$c" | { LC_ALL=C grep -aE "$RULE_NETWORK_RE" || true; } | { LC_ALL=C grep -aE "$RULE_SENSITIVE_RE" || true; } \
    | LC_ALL=C sed -E "s/${cr}\$//; s/^[ ${tab}]+//; s/[ ${tab}]+\$//" | LC_ALL=C sort -u)"
  printf 'net=%s;path=%s' "$net" "$path"
  [[ -z "$lines" ]] || printf ';lines=%s' "$(csa_sha256 "$lines")"
}


# _csa_hook004_match <text> — both patterns match the text, byte-wise in every locale. LC_ALL=C is local to this
# function only, so the callers' later work (csa_redact's character cut of a preview) keeps the ambient locale.
_csa_hook004_match() {
  local LC_ALL=C
  [[ "$1" =~ $RULE_NETWORK_RE ]] && [[ "$1" =~ $RULE_SENSITIVE_RE ]]
}

detect() {
  local target_file="$1"
  [[ -r "$target_file" ]] || return 0
  # Only scan known hook handler and wrapper script surfaces, and hook handler code (csa_hook_handler_file).
  if [[ "$target_file" != */.claude/hooks* && "$target_file" != *.sh \
        && "$target_file" != */.opencode/bin/* && "$target_file" != */.opencode/*.js \
        && "$target_file" != */.opencode/*.ts && "$target_file" != */.opencode/*.mjs ]] \
        && ! csa_hook_handler_file "$target_file"; then
    return 0
  fi
  # Fire only when BOTH a network command AND a sensitive path reference are present
  # A read error is rc 2 (SCANNER-002), not an empty file or a clean prefix. Content read before the
  # error is matched, and a match is emitted, never traded for the stop; no match in what was read
  # says nothing about the rest, so that is rc 2 (#1089). Skill-first question 3: only adds a stop.
  local content crc=0; content="$(cat "$target_file" 2>/dev/null)" || crc=$?
  if [[ "$crc" -ne 0 ]] && ! _csa_hook004_match "$content"; then
    return 2
  fi
  if _csa_hook004_match "$content"; then
    # Emit a finding at line 1 (file-level rule)
    # File-level rule: one finding per file. The uid holds the rule, the file and the excerpt from
    # _csa_hook004_excerpt (the names that fire, plus a digest of the lines holding both matches), hashed raw so nothing past
    # character 200 is lost (#1098). Skill-first: the names are question 2; the line part reads open text but can
    # only split a uid, so what it mishandles reads NEW or leaves the uid on the names (see the excerpt function).
    local fuid; fuid="$(csa_finding_uid_raw "$RULE_ID" "$target_file" "$(_csa_hook004_excerpt "$content")")"
    jq -nc \
      --arg rule_id "$RULE_ID" \
      --arg file "$target_file" \
      --argjson line 1 \
      --argjson offset 0 \
      --arg preview "network command + sensitive path reference detected" \
      --arg severity "$RULE_SEVERITY" \
      --arg fuid "$fuid" \
      '{rule_id: $rule_id, file: $file, line: $line, offset: $offset, preview: $preview, severity: $severity, finding_uid: $fuid}'
  fi
}

# detect_text <entry-json> <file> — one decoded hook command: both regexes must
# match the whole command. Skill-first question 3 (can only add a stop).
detect_text() {
  local entry="$1" target_file="$2" text
  text="$(csa_hook_entry_command "$entry")" || return $?
  _csa_hook004_match "$text" || return 1
  csa_hook_entry_emit "$RULE_ID" "$RULE_SEVERITY" "$entry" "$target_file"
}
