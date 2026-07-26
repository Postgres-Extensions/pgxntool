#!/usr/bin/env bash
#
# check-stale-expected.sh - Catch orphaned test/expected/ files
#
# test/expected/*.out must mirror test/sql/*.sql 1:1 (likewise
# test/build/expected/*.out vs test/build/*.sql, when test-build is in use).
# It's easy to leave a stale .out behind after renaming or removing a .sql
# file; this makes `make test` fail loudly instead of letting it linger
# unnoticed.
#
# test/install/ is NOT checked here: its expected output lives alongside the
# .sql files (test/install/foo.out), not in a separate expected/
# subdirectory, so there's no 1:1 directory mirror to compare.
#
# pg_regress supports up to 10 alternate expected-output files per test
# (test.out, test_0.out .. test_9.out - see get_alternative_expectfile() in
# pg_regress.c), tried in turn when the primary doesn't match. For each
# expected file we compute the real test base name up front (falling back to
# stripping a trailing _N only when the direct name has no matching .sql),
# so there's a single existence check per file rather than a separately
# tracked found/not-found flag.
#
# Usage: check-stale-expected.sh <testdir>

set -o errexit -o errtrace -o pipefail

BASEDIR=$(dirname "$0")
source "$BASEDIR/lib.sh"

if [ $# -ne 1 ]; then
  die 1 "Usage: check-stale-expected.sh <testdir>"
fi

testdir="$1"
failed=0

# Usage: check_pair <sql_dir> <expected_dir>
check_pair() {
  local sqldir="$1" expdir="$2"
  local f base

  [ -d "$expdir" ] || return 0

  for f in "$expdir"/*.out; do
    [ -f "$f" ] || continue

    base=$(basename "$f" .out)
    case "$base" in
      *_[0-9])
        [ -f "$sqldir/$base.sql" ] || base=${base%_*}
        ;;
    esac

    if [ ! -f "$sqldir/$base.sql" ]; then
      error "$f has no corresponding $sqldir/$base.sql"
      failed=1
    fi
  done
}

check_pair "$testdir/sql" "$testdir/expected"
check_pair "$testdir/build" "$testdir/build/expected"

exit "$failed"

# vi: expandtab ts=2 sw=2
