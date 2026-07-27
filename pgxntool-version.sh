#!/usr/bin/env bash
#
# pgxntool-version.sh - Print the pgxntool version embedded in this project
#
# The release process (see .claude/skills/release) stamps the first line of
# HISTORY.asc with the released version number, so that line is the source
# of truth for "what version of pgxntool is this?". If this copy was synced
# from an unreleased commit rather than a tagged release, the first line
# will be "STABLE" instead of a version number -- that's printed as-is, since
# it's an accurate answer too.
#
# Usage: pgxntool-version.sh [<history-file>]
#
#   history-file  Path to HISTORY.asc to read. Defaults to the copy
#                 alongside this script (i.e. pgxntool/HISTORY.asc in a
#                 normal checkout).

set -o errexit -o errtrace -o pipefail
trap 'echo "Error on line ${LINENO}"' ERR

PGXNTOOL_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$PGXNTOOL_DIR/lib.sh"

history_file="${1:-$PGXNTOOL_DIR/HISTORY.asc}"

[[ -f "$history_file" ]] || die 1 "$history_file not found"

version=$(head -n1 "$history_file")

[[ -n "$version" ]] || die 1 "$history_file is empty"

echo "$version"
