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
# A file passes if it either sets ON_ERROR_STOP itself, or sources
# test/pgxntool/psql.sql (which already sets it, among other things).
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

for f in "$install_dir"/*.sql; do
  [ -f "$f" ] || continue

  if grep -q 'ON_ERROR_STOP' "$f"; then
    continue
  fi
  if grep -qE '\\ir? +.*psql\.sql' "$f"; then
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
