#!/usr/bin/env bash
# pgxntool/verify-results-pgtap.sh - Check pgtap results before 'make results'
#
# Scans pgtap output files for failures and plan mismatches, then checks
# regression.diffs as a fallback, ignoring entries for tests that have no
# expected output yet. Exits non-zero if any problems are found.
#
# Usage: verify-results-pgtap.sh TESTOUT
#
# Called by the verify-results target in base.mk (pgtap mode).

set -e

TESTOUT="${1:?Usage: verify-results-pgtap.sh TESTOUT}"

# Check for pgtap failures in result files (excluding TODO items)
failed=0
for f in "$TESTOUT"/results/*.out; do
	[ -f "$f" ] || continue
	if grep -q '^not ok' "$f"; then
		notok=$(grep '^not ok' "$f" | grep -v '# TODO' || true)
		if [ -n "$notok" ]; then
			echo "ERROR: pgtap failure detected in $f"
			echo "$notok"
			failed=1
		fi
	fi
	if grep -q 'Looks like you planned' "$f"; then
		echo "ERROR: pgtap plan mismatch in $f"
		grep 'Looks like you planned' "$f"
		failed=1
	fi
done
if [ $failed -ne 0 ]; then
	echo
	echo "pgtap failures detected. Cannot run 'make results'."
	exit 1
fi

# Also check regression.diffs (output mismatch even if pgtap all passed).
#
# A test whose output matched ANY of its expected files - including a
# pg_regress _N.out alternate - is left out of regression.diffs entirely, so
# every block in here is a test that matched none of them. The one exception
# is a test that has no expected output yet: pg_regress aborts outright on a
# missing expected file, so base.mk touches an empty test/expected/<name>.out
# for every test/sql/*.sql lacking one, and diffing actual output against that
# placeholder always reports a difference. Blocking on that is unwinnable -
# seeding that first expected file is precisely what `make results` is for -
# so those blocks are skipped here.
diffs="$TESTOUT/regression.diffs"
if [ -s "$diffs" ]; then
	# pg_regress heads each block with "diff <opts> <expected> <results>" (see
	# results_differ() in pg_regress.c), then appends the diff itself. Only
	# those headers and diff hunk headers can start with "diff " or "@@ "
	# unprefixed; every line carrying file content is prefixed with ' ', '+'
	# or '-'. A block whose hunks all read "@@ -0,0 +N,M @@" was diffed
	# against an empty expected file, i.e. that placeholder.
	classified=$(awk '
		function flush(   status) {
			if (results == "") return
			status = (hunks > 0 && unblessed) ? "unblessed" : "regression"
			print status "\t" results
		}
		/^diff / { flush(); results = $NF; unblessed = 1; hunks = 0; next }
		/^@@ /   { hunks++; if ($0 !~ /^@@ -0,0 /) unblessed = 0; next }
		END      { flush() }
	' "$diffs")

	blocked=
	blessable=
	while IFS="$(printf '\t')" read -r status file; do
		# An unblessed file holding a hard SQL error is not a passing test the
		# pgtap scan above was merely quiet about: ON_ERROR_STOP aborts the
		# script, so pgtap emits neither 'not ok' nor its plan-mismatch line.
		# Blessing that would make the error the baseline.
		if [ "$status" = unblessed ] && [ -r "$file" ] && ! grep -q 'ERROR:' "$file"; then
			blessable="$blessable  $file
"
		else
			blocked="$blocked  $file
"
		fi
	done <<EOF
$classified
EOF

	# Nothing recognizable in a non-empty regression.diffs: refuse to guess.
	[ -n "$classified" ] || blocked="  (unrecognized $diffs content)
"

	if [ -n "$blocked" ]; then
		echo "ERROR: Tests are failing. Cannot run 'make results'."
		echo "Fix test failures first, then run 'make results'."
		echo
		echo "Failing tests:"
		printf '%s' "$blocked"
		echo
		echo "See $diffs for details:"
		cat "$diffs"
		exit 1
	fi

	echo "NOTE: these tests have no expected output yet; 'make results' will create it:"
	printf '%s' "$blessable"
fi
