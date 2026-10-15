#!/usr/bin/env bash
#
# check-tap-output.sh - Fail on TAP (pgTap) failures in pg_regress output
#
# A file that matches its expected output byte for byte still fails here if
# its TAP says the test failed, so a `not ok` blessed into an expected file
# can't pass `make test` (issue #106).
#
# A file counts as TAP output if it has a top-level test line
# (`ok N`/`not ok N`) or plan line (`1..N`); every other file passes
# untouched. A TAP file fails if:
#   - it has a `not ok` line without `# TODO`
#   - it has pgTap's "Looks like you planned" line
#   - it has no plan line: a no_plan() test that died before finish()
#   - it has more than one plan line: nothing sane to compare against
#   - its count of top-level test lines differs from the plan: a plan(N)
#     test that died partway through (`1..0` with no tests passes)
# Only unindented lines count, so subtest output is ignored.
#
# Arguments that don't exist are ignored, so an unmatched shell glob is
# harmless.
#
# Usage: check-tap-output.sh [--list] FILE...
# Exits 1 if any file fails, else 0. With --list, checks nothing: prints
# each FILE that counts as TAP output, one per line, and exits 0.

set -o errexit -o errtrace -o pipefail

list=
if [ "${1:-}" = --list ]; then
  list=1
  shift
fi

failed=0
for f in "$@"; do
  [ -f "$f" ] || continue

  # "<tests> <plans> <planned>", where <planned> is the last plan's count.
  read -r tests plans planned < <(awk '
    /^(not )?ok [0-9]/ { tests++ }
    /^1\.\.[0-9]/      { plans++; planned = substr($1, 4) + 0 }
    END                { print tests + 0, plans + 0, planned + 0 }
  ' "$f")

  [ "$tests" -gt 0 ] || [ "$plans" -gt 0 ] || continue

  if [ -n "$list" ]; then
    printf '%s\n' "$f"
    continue
  fi

  notok=$(grep '^not ok' "$f" | grep -v '# TODO' || true)
  if [ -n "$notok" ]; then
    echo "ERROR: pgtap failure detected in $f"
    echo "$notok"
    failed=1
  fi

  # One plan problem per file: pgTap's own mismatch line already says what a
  # count check would.
  if grep -q 'Looks like you planned' "$f"; then
    echo "ERROR: pgtap plan mismatch in $f"
    grep 'Looks like you planned' "$f"
    failed=1
  elif [ "$plans" -eq 0 ]; then
    echo "ERROR: pgtap output in $f has no plan line (1..N); the test likely died before finishing"
    failed=1
  elif [ "$plans" -gt 1 ]; then
    echo "ERROR: pgtap output in $f has $plans plan lines (1..N); expected exactly one"
    failed=1
  elif [ "$tests" -ne "$planned" ]; then
    echo "ERROR: pgtap plan mismatch in $f: planned $planned tests but found $tests"
    failed=1
  fi
done

exit "$failed"

# vi: expandtab ts=2 sw=2
