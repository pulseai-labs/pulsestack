#!/usr/bin/env bash
# #1205: pin the complete report-only grant, not a list of forbidden verbs.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_helpers.sh"

command_file="$SCRIPT_DIR/../commands/review-pr.md"
want="$(printf '%s\n' 'Bash(gh pr view:*)' Read Glob Grep Write Agent | LC_ALL=C sort)"

check_grant() {
  local got
  got="$(awk '
    NR == 1 { if ($0 != "---") exit 1; next }
    $0 == "---" { closed = 1; exit }
    { print }
    END { if (!closed) exit 1 }
  ' | ruby -rpsych -e '
    doc = Psych.parse(STDIN.read)
    exit 1 unless doc && doc.root.is_a?(Psych::Nodes::Mapping)
    grants = doc.root.children.each_slice(2).filter_map do |key, value|
      value if key.is_a?(Psych::Nodes::Scalar) && key.value == "allowed-tools"
    end
    exit 1 unless grants.size == 1 && grants.first.is_a?(Psych::Nodes::Scalar)
    puts grants.first.value.split(",", -1).map(&:strip)
  ' | LC_ALL=C sort)" || {
    printf '%s\n' 'expected one scalar allowed-tools value in the frontmatter'
    return 1
  }
  [ "$got" = "$want" ] && return 0
  printf 'extra: [%s] missing: [%s]\n' \
    "$(LC_ALL=C comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ')" \
    "$(LC_ALL=C comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ')"
  return 1
}

if detail="$(check_grant < "$command_file")"; then
  pass 'review-pr: allowed-tools is exactly the report-only grant (#1205)'
else
  fail 'review-pr: allowed-tools is exactly the report-only grant (#1205)' "$detail"
fi

if detail="$(awk '/^allowed-tools:/ { $0 = $0 ", Bash(git:*)" } { print }' "$command_file" | check_grant)"; then
  fail 'review-pr: rejects a re-added Bash(git:*)' 'the broadened grant passed'
elif [[ "$detail" == *'Bash(git:*) '* ]]; then
  pass 'review-pr: rejects a re-added Bash(git:*)'
else
  fail 'review-pr: rejects a re-added Bash(git:*)' "$detail"
fi

report
