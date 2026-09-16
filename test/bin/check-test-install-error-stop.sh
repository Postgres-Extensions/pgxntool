#!/usr/bin/env bash
#
# check-test-install-error-stop.sh - Ensure test/install/*.sql files set
# ON_ERROR_STOP
#
# test/install/*.sql files run in pg_regress's own self-comparing entry (see
# the test/install comments in base.mk): actual output lands on top of the
# expected file, so there's no real diff to catch a bad result. The only
# thing that still fails the build is psql itself exiting non-zero -- which
# only happens if ON_ERROR_STOP is set. Without it, a hard SQL error is
# printed and swallowed, and the file "passes". This scans for that safety
# net so its absence is caught at build time instead of discovered the hard
# way (issue #97).
#
# A file passes if it explicitly turns ON_ERROR_STOP on at some point --
# directly (`\set ON_ERROR_STOP on`/true/1/yes) or by sourcing
# test/pgxntool/psql.sql (which already turns it on, among other things). A
# later explicit turn-off doesn't undo an earlier turn-on. A file that only
# ever turns it off, or never mentions it at all, fails: a bare substring
# match on "ON_ERROR_STOP" would wrongly pass a file that only turns it off,
# so each `\set` needs its value read, in file order.
#
# Usage: check-test-install-error-stop.sh <testdir>

set -o errexit -o errtrace -o pipefail

BASEDIR=$(dirname "$0")
source "$BASEDIR/../../lib.sh"

if [ $# -ne 1 ]; then
  die 1 "Usage: check-test-install-error-stop.sh <testdir>"
fi

testdir="$1"
install_dir="$testdir/install"
missing=()

# Scans $1 in file order, tracking whether ON_ERROR_STOP has been explicitly
# turned on. Succeeds (exit 0) once an on-value is seen; a later off-value
# doesn't reset that. Sourcing psql.sql counts as turning it on, wherever it
# occurs in the file.
file_turns_error_stop_on() {
  local f="$1" line value
  while IFS= read -r line; do
    if [[ "$line" =~ \\ir?[[:space:]]+.*psql\.sql ]]; then
      return 0
    fi
    if [[ "$line" =~ \\set[[:space:]]+ON_ERROR_STOP[[:space:]]+([^[:space:]]+) ]]; then
      value="${BASH_REMATCH[1],,}"
      case "$value" in
        on|true|1|yes) return 0 ;;
      esac
    fi
  done < "$f"
  return 1
}

for f in "$install_dir"/*.sql; do
  [ -f "$f" ] || continue

  if file_turns_error_stop_on "$f"; then
    continue
  fi

  missing+=("$f")
done

if [ "${#missing[@]}" -gt 0 ]; then
  error "the following test/install/*.sql files don't set ON_ERROR_STOP:"
  printf '  %s\n' "${missing[@]}" >&2
  error "test/install files run in their own self-comparing pg_regress entry" \
    "(see the test/install comments in base.mk) -- without ON_ERROR_STOP, a" \
    "hard SQL error is silently swallowed instead of failing the build."
  die 1 "Add '\\set ON_ERROR_STOP on' near the top of the file, or" \
    "'\\i test/pgxntool/psql.sql' (which already sets it)."
fi

# vi: expandtab ts=2 sw=2
