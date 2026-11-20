#!/usr/bin/env bash
# wayfinder tracker resolution (#337) - branch 1's origin normalization,
# extracted from the shipped prose and executed for real.
#
# SCOPE. block-ledger.tsv classified all FOUR of tracker.md's bash blocks as
# D ("covered by no suite") because three of them are live `gh` API calls
# with no local fixture path - see the D row this file's own change shrinks
# from 4 to 3. The ladder block (the one extracted below) is different: `oss
# repo_root` and `git remote get-url origin` are local, git-only reads, so it
# is testable without a live GitHub credential or network call.
#
# #337 found the gap this file exists to close: the sed pipeline that derives
# $OWNER_REPO from a live git origin documented three remote spellings (git@,
# ssh://, plain https) and silently missed a fourth git also produces - https
# with userinfo, e.g. an authenticated CI remote
# (https://x-access-token:TOKEN@github.com/owner/repo). None of the three sed
# rules touched that shape, so $OWNER_REPO came out as the ENTIRE credentialed
# origin - a secret bound into a variable the reachability guard, branch 4's
# stop, and branch 0's own stop message all print to the terminal on failure.
#
# ROUND 2 (same issue, review found the round-1 fix still leaked). Two more
# defects in the userinfo handling itself:
#   - the userinfo character class excluded @ as well as /, so it stopped at
#     the FIRST @ rather than the last one before the host. A password
#     containing a raw, unescaped @ (user:p@ss@github.com/...) stripped only
#     "user:p@" and left "ss@github.com/..." still credential-bearing. The
#     percent-encoded-password case below was NOT sufficient to catch this -
#     %40 is three literal characters, never a competing @ - so this file
#     shipped once already without a test that could catch it.
#   - the ssh strip was anchored to a literal github.com host, so an ssh
#     origin carrying userinfo on any OTHER host leaked untouched.
#
# ROUND 3 (same issue, third time). Rounds 1-2 fixed ssh:// then ssh://+
# https://, one rule per scheme - and each round the scheme that was NOT
# enumerated rode a credential straight through. A plain http:// origin, or
# git://, hit neither the ssh nor the https rule and leaked exactly like the
# original #337 report. The fix is now scheme-agnostic (one rule matching
# any RFC-3986-shaped scheme before `://`, not an enumeration), which is a
# shorter pipeline than round 2's AND does not miss the next scheme. The
# "http:// with userinfo" and "git:// with userinfo" cases below are what
# rounds 1 and 2 shipped without.
#
# WHAT THIS FILE DOES NOT COVER. Only branch 1 (an origin is present) is
# exercised, across all four documented spellings plus several extra
# userinfo shapes (bare-token, percent-encoded password, raw multi-@
# password, non-github ssh host, empty userinfo, http:// and git://
# schemes). Branch 0's actual conflict-stop (a mismatched .wayfinder.json)
# and branches 2/3 (no origin - dotfile read) are NOT exercised here; the
# block is one fenced unit under this ledger's convention (O rows cover a
# whole block, never a slice), so this row converts the whole ladder block
# to O while this comment - and the git history at #337 - is the honest
# record of which paths inside it a real assertion touches. The other three
# D-blocks (reachability probe, GraphQL frontier query, ticket-label check)
# are unchanged: still live `gh` calls, still uncovered here, still D.
#
# DEFERRED, logged for the final review, neither a credential issue: a
# port-bearing or IPv6 origin (github.com:443/... or [::1]/...) strips any
# credential correctly but leaves $OWNER_REPO malformed, since the literal
# `https://github\.com/` strip does not match a `github.com:443/` prefix -
# functional, since it fails closed at the reachability guard rather than
# resolving wrong. And a trailing slash after `.git` defeats the `\.git$`
# anchor. Neither is exercised below; neither leaks anything.
#
# The block is EXTRACTED from the shipped prose via oss_block_extract, never
# retyped, and run under real `set -euo pipefail` through a PATH-shimmed `oss`
# that execs the real dispatcher - so the subject under test is the artifact
# an agent will actually copy-run, not a paraphrase of it.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/lib/pin.sh"
. "$HERE/lib/blocks.sh"
SKILLS="$HERE/../skills"
OSS="$HERE/../bin/oss"
TRACKER_MD="$SKILLS/wayfinder/references/tracker.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LADDER="$TMP/ladder.sh"
oss_block_extract "$TRACKER_MD" 'repo_root ai_workspace' "$LADDER"
pin "$LADDER" 'AI_ROOT="$(oss repo_root ai_workspace 2>/dev/null || true)"' \
  'tracker ladder resolves the AI workspace before choosing a branch'

# The block invokes the dispatcher as `oss` by name — bind that name to the real
# dispatcher so the extracted code runs the actual one rather than a stub.
SHIM="$TMP/shim"
mkdir -p "$SHIM"
printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$OSS" > "$SHIM/oss"
chmod +x "$SHIM/oss"

# Fixture AI workspace: a real git repo (the block reads git, never the
# manifest, for the origin) with a pairing.json so "oss repo_root
# ai_workspace" resolves to it, and deliberately NO .wayfinder.json - branch
# 0's conflict check must stay inert so the ladder falls straight through to
# whatever $OWNER_REPO the sed pipeline under test derives.
WS="$TMP/ws"
mkdir -p "$WS/.workspace"
cat > "$WS/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$WS"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON
git -C "$WS" init -q
git -C "$WS" config user.email t@t
git -C "$WS" config user.name t

_run_ladder() { # $1=origin ; sets T_OUT to "$OWNER_REPO $OWNER $REPO", T_RC to the block's rc
  git -C "$WS" remote remove origin >/dev/null 2>&1 || true
  git -C "$WS" remote add origin "$1"
  t_capture env "PATH=$SHIM:$PATH" bash -c "cd '$WS' && set -euo pipefail && . '$LADDER' && printf '%s %s %s' \"\$OWNER_REPO\" \"\$OWNER\" \"\$REPO\""
}

# The three spellings the prose already claimed - unchanged behaviour, proving
# the fix does not regress the cases it already handled.
_run_ladder "git@github.com:acme/repo.git"
t_assert_rc 0 "scp-style origin: ladder runs clean"
t_assert_eq "acme/repo acme repo" "$T_OUT" "scp-style origin normalizes to acme/repo"

_run_ladder "ssh://git@github.com/acme/repo.git"
t_assert_rc 0 "ssh:// origin: ladder runs clean"
t_assert_eq "acme/repo acme repo" "$T_OUT" "ssh:// origin normalizes to acme/repo"

_run_ladder "https://github.com/acme/repo.git"
t_assert_rc 0 "plain https origin: ladder runs clean"
t_assert_eq "acme/repo acme repo" "$T_OUT" "plain https origin normalizes to acme/repo"

# #337 - the fourth spelling: userinfo between scheme and host on an
# authenticated HTTPS remote. Pre-fix, none of the three sed rules match this
# shape, so $OWNER_REPO comes out as the entire credentialed origin string.
_run_ladder "https://x-access-token:ghs_faketoken123@github.com/acme/repo.git"
t_assert_rc 0 "credentialed https origin: ladder runs clean"
t_assert_eq "acme/repo acme repo" "$T_OUT" "credentialed https origin strips the userinfo, not just the .git suffix"
if printf '%s' "$T_OUT" | grep -q 'ghs_faketoken123'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: the token survived into \$OWNER_REPO/\$OWNER/\$REPO - #337 regressed"
else
  T_PASS=$((T_PASS+1))
fi

# #337, second half: git PRESERVES the scheme's spelling, and the redaction
# rules were lowercase-only. `HTTPS://tok@...` matched none of them, so the
# credential survived into $OWNER_REPO and the branch-0/branch-4 diagnostics
# printed it to the transcript - the exact leak #337 exists to close, reachable
# by typing the remote in caps.
for scheme in HTTPS Https hTTps; do
  _run_ladder "$scheme://x-access-token:ghs_capstoken456@github.com/acme/repo.git"
  t_assert_rc 0 "$scheme:// credentialed origin: ladder runs clean"
  t_assert_eq "acme/repo acme repo" "$T_OUT" "$scheme:// credentialed origin normalizes to acme/repo"
  if printf '%s' "$T_OUT" | grep -q 'ghs_capstoken456'; then
    T_FAIL=$((T_FAIL+1)); echo "FAIL: the token survived a $scheme:// origin - the redaction is case-sensitive"
  else
    T_PASS=$((T_PASS+1))
  fi
done
_run_ladder "GIT@GitHub.com:acme/repo.git"
t_assert_rc 0 "mixed-case scp-style origin: ladder runs clean"
t_assert_eq "acme/repo acme repo" "$T_OUT" "mixed-case scp-style origin normalizes to acme/repo"

# Two more userinfo shapes: a bare token with no colon/password, and a
# percent-encoded password (the encoded %40 must not be mistaken for the
# userinfo-terminating @ and over-match into the host).
_run_ladder "https://TOKEN@github.com/acme/repo.git"
t_assert_eq "acme/repo acme repo" "$T_OUT" "bare-token (no colon) userinfo also stripped"

_run_ladder "https://user:p%40ss@github.com/acme/repo.git"
t_assert_eq "acme/repo acme repo" "$T_OUT" "percent-encoded password in userinfo stripped without over-matching"

# ROUND 2, Finding 1: a RAW, unescaped @ inside the password. The class must
# run to the LAST @ before the host, not the first - this is the case the
# percent-encoded fixture above could not exercise, since %40 never presents
# a competing @ to the regex.
_run_ladder "https://user:p@ss@github.com/acme/repo.git"
t_assert_rc 0 "https origin with a raw unescaped @ in the password: ladder runs clean"
t_assert_eq "acme/repo acme repo" "$T_OUT" "the strip runs to the LAST @ before the host, not the first"
if printf '%s' "$T_OUT" | grep -Eq '@|user:p|p@ss'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: userinfo survived into \$OWNER_REPO/\$OWNER/\$REPO for a raw multi-@ password - #337 round 2 regressed"
else
  T_PASS=$((T_PASS+1))
fi

# ROUND 2, Finding 2: userinfo on an ssh:// origin whose host is NOT
# github.com. The original ssh rule only stripped userinfo as a side effect
# of matching a literal github.com host, so any other host rode through
# untouched. This tracker only ever resolves a github.com remote in
# practice, so $OWNER_REPO ending up unresolvable here is expected - the
# only thing under test is that the credential itself never survives.
_run_ladder "ssh://user:pass@gitlab.example.com/acme/repo.git"
t_assert_rc 0 "ssh origin with userinfo on a non-github host: ladder runs clean"
if printf '%s' "$T_OUT" | grep -Fq 'user:pass'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: an ssh origin's userinfo survived when the host is not github.com - #337 round 2 Finding 2 regressed"
else
  T_PASS=$((T_PASS+1))
fi

# The two round-2 defects together: a raw multi-@ password on a non-github
# ssh host must not leak either.
_run_ladder "ssh://user:p@ss@gitlab.example.com/acme/repo.git"
if printf '%s' "$T_OUT" | grep -Eq 'user:p|p@ss'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: a raw multi-@ password on a non-github ssh host survived"
else
  T_PASS=$((T_PASS+1))
fi

# And the ssh+github.com path, now sharing the same fixed class as https,
# with a raw multi-@ password - symmetry check.
_run_ladder "ssh://user:p@ss@github.com/acme/repo.git"
t_assert_eq "acme/repo acme repo" "$T_OUT" "ssh origin with a raw @ in the password also normalizes cleanly"

# ROUND 3: a scheme neither round 1 nor round 2 enumerated. http:// and
# git:// get no github.com-specific rewrite (only ssh and https do), so
# $OWNER_REPO is not reduced to a bare owner/repo here - the only property
# under test is that the credential itself is gone.
_run_ladder "http://user:pass@github.com/acme/repo.git"
t_assert_rc 0 "http:// origin with userinfo: ladder runs clean"
if printf '%s' "$T_OUT" | grep -Fq 'user:pass'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: an http:// origin's userinfo survived - #337 round 3 regressed"
else
  T_PASS=$((T_PASS+1))
fi

_run_ladder "git://user:pass@github.com/acme/repo.git"
t_assert_rc 0 "git:// origin with userinfo: ladder runs clean"
if printf '%s' "$T_OUT" | grep -Fq 'user:pass'; then
  T_FAIL=$((T_FAIL+1)); echo "FAIL: a git:// origin's userinfo survived - #337 round 3 regressed"
else
  T_PASS=$((T_PASS+1))
fi

# Empty userinfo - a bare @ with nothing before it. The class is `[^/]*`
# (star, not plus) precisely so this still matches instead of falling
# through untouched.
_run_ladder "https://@github.com/acme/repo.git"
t_assert_eq "acme/repo acme repo" "$T_OUT" "empty userinfo (a bare @) still strips cleanly"

t_summary
