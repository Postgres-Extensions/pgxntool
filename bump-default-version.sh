#!/usr/bin/env bash
#
# bump-default-version.sh - Set default_version in one or more .control files
#
# Usage: bump-default-version.sh <new_version> <control_file> [<control_file> ...]
#
# Rewrites each control file's default_version line to <new_version>, preserving
# everything else on that line (e.g. a trailing comment) and leaving the rest of
# the file untouched.
#
# Invoked by `make tag` (see base.mk) right after a new release tag is created,
# to move default_version to a placeholder alias (PGXNTOOL_POST_TAG_VERSION,
# default "stable") so ongoing development doesn't silently regenerate and
# overwrite the just-tagged version's versioned SQL file. Can also be run by
# hand for the same purpose.

set -o errexit -o errtrace -o pipefail
trap 'echo "Error on line ${LINENO}"' ERR

BASEDIR=$(dirname "${BASH_SOURCE[0]}")
source "$BASEDIR/lib.sh"

if [ $# -lt 2 ]; then
  die 1 "Usage: $0 <new_version> <control_file> [<control_file> ...]"
fi

new_version="$1"
shift

for control_file in "$@"; do
  [ -f "$control_file" ] || die 2 "Control file '$control_file' not found"

  # Same one-line-only requirement control.mk.sh enforces when reading
  # default_version -- keeps writing and reading in agreement about what a
  # valid control file looks like.
  count=$(grep -cE "^[[:space:]]*default_version[[:space:]]*=" "$control_file") || count=0
  if [ "$count" -ne 1 ]; then
    die 2 "Expected exactly one default_version line in '$control_file', found $count"
  fi

  # Capture the assignment prefix (indentation + "default_version = ") and
  # everything after the closing quote (e.g. a trailing comment) untouched;
  # only the quoted value itself is replaced, and always re-quoted with single
  # quotes regardless of the original quote style.
  tmp_file=$(mktemp "${control_file}.XXXXXX")
  sed -E "s/^([[:space:]]*default_version[[:space:]]*=[[:space:]]*)(['\"])[^'\"]*\\2/\\1'${new_version}'/" \
    "$control_file" > "$tmp_file"
  mv "$tmp_file" "$control_file"
  echo "Set default_version = '${new_version}' in $control_file"
done
