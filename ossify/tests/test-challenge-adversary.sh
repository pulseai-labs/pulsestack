#!/usr/bin/env bash
# Execute the shipped Claude fence; intercept only the external CLI boundary.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/lib/blocks.sh"

SKILLS="$HERE/../skills"
ADVERSARIES="$SKILLS/challenge/references/adversaries.md"
WORK="$(mktemp -d)" || exit 1
trap 'rm -rf "$WORK"' EXIT
BLOCK="$WORK/claude.sh"
ARGUMENTS="$WORK/schema-arguments.json"

oss_block_extract "$ADVERSARIES" 'claude --print' "$BLOCK" || exit 1
schema="$SKILLS/challenge/templates/output-schema.json"
claude() {
  while [ "$#" -gt 0 ]; do
    if [ "$1" = --json-schema ]; then
      [ "$#" -ge 2 ] || return 2
      printf '%s\n' "$2" >> "$ARGUMENTS" || return 1
      shift
    fi
    shift
  done
}

t_capture . "$BLOCK"
t_assert_rc 0 'the shipped Claude invocation builds its arguments'
# shellcheck disable=SC2016 # The dollar sign is part of the JSON key.
t_capture jq -se --slurpfile template "$schema" '
  length == 1 and (.[0] | type == "object" and (has("$schema") | not)
    and . == ($template[0] | with_entries(select(.key != "$schema"))))
' "$ARGUMENTS"
t_assert_rc 0 'Claude receives one valid JSON schema identical to the template except for the dialect declaration'
t_summary
