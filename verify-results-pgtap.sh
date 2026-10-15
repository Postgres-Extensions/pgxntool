#!/usr/bin/env bash
# pgxntool/verify-results-pgtap.sh - Check pgtap results before 'make results'
#
# Scans pgtap output files for failures and plan problems (see
# test/bin/check-tap-output.sh), then checks regression.diffs as a fallback,
# ignoring entries for tests that have no expected output yet. Exits non-zero
# if any problems are found.
#
# Usage: verify-results-pgtap.sh [--pgtap-only] [--for-test] TESTOUT [FILE...]
#   FILE: additional pgtap output files to scan besides TESTOUT/results/*.out
#   --pgtap-only: a test whose result file is TAP output is judged by its TAP
#     and by having no SQL error line, not by its regression.diffs block
#   --for-test: judge regression.diffs the way `make test` does: every block
#     left fails, and the TAP scan is left to the caller
#
# Called by the verify-results target in base.mk, and by the `test` recipe
# when PGXNTOOL_VERIFY_RESULTS_MODE=pgtap-only.

set -e

pgtap_only=
for_test=
while :; do
	case ${1:-} in
	--pgtap-only) pgtap_only=1; shift ;;
	--for-test)   for_test=1; shift ;;
	*)            break ;;
	esac
done

TESTOUT="${1:?Usage: verify-results-pgtap.sh [--pgtap-only] [--for-test] TESTOUT [FILE...]}"
shift

check_tap="$(dirname "$0")/test/bin/check-tap-output.sh"

if [ -n "$for_test" ]; then
	cannot=
else
	cannot=" Cannot run 'make results'."
fi
status=0

# pg_regress feeds psql on stdin, so a failing statement in the test file
# itself reports as "ERROR:  ..." at column 0, while one inside an \i'd file
# (setup.sql, finish.sql) reports as "psql:test/pgxntool/setup.sql:3: ERROR:
# ...". Matching either position, and psql's own two spaces after the
# severity, keeps a passing test whose description merely mentions "ERROR:"
# out of it.
sql_error='(^|: )ERROR:  '

# Check for pgtap failures in result files and any extra files (base.mk passes
# the test/install actual outputs).
if [ -z "$for_test" ] && ! "$check_tap" "$TESTOUT"/results/*.out "$@"; then
	echo
	echo "pgtap failures detected.$cannot"
	exit 1
fi

# With its diff ignored, a SQL error is the one thing besides its TAP that can
# still fail a TAP test.
if [ -n "$pgtap_only" ]; then
	errored=
	while IFS= read -r f; do
		if [ -n "$f" ] && grep -qE "$sql_error" "$f"; then
			errored="$errored  $f
"
		fi
	done <<EOF
$("$check_tap" --list "$TESTOUT"/results/*.out)
EOF
	if [ -n "$errored" ]; then
		echo "ERROR: SQL errors in pgtap test output.$cannot"
		printf '%s' "$errored"
		[ -n "$for_test" ] || exit 1
		status=1
	fi
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
# so those blocks are skipped here (but not under --for-test).
diffs="$TESTOUT/regression.diffs"

# pg_regress truncates regression.diffs at startup and deletes it again on a
# clean finish with nothing to report, so an empty one means it died before
# comparing anything - an unreachable server, an interrupt. Whatever is in
# results/ is then left over from some earlier run, and base.mk's `.IGNORE:
# installcheck` means `make results` gets here anyway, so blessing it would
# bless stale output.
if [ -e "$diffs" ] && [ ! -s "$diffs" ]; then
	echo "ERROR: pg_regress did not complete.$cannot"
	echo "$diffs is empty, so nothing was actually compared;"
	echo "anything in $TESTOUT/results/ is left over from an earlier run."
	exit 1
fi

if [ -s "$diffs" ]; then
	# pg_regress heads each block with "diff <opts> <expected> <results>" (see
	# results_differ() in pg_regress.c), then appends the diff itself. Only
	# those headers and diff hunk headers can start with "diff " or "@@ "
	# unprefixed; every line carrying file content is prefixed with ' ', '+',
	# '-' or '\'. A block whose hunks all read "@@ -0,0 +N,M @@" was diffed
	# against an empty expected file, i.e. that placeholder. Anything that
	# fits none of those shapes is something this has no business
	# interpreting, so it blocks the whole file.
	#
	# Hunk headers only exist in unified diffs. PostgreSQL 12 was the first
	# to write them (11 and older use -C3 context diffs), so on those every
	# block lands in the blocked pile - the same refusal `make results` gave
	# before any of this existed.
	classified=$(awk '
		function flush(   status) {
			if (results == "") return
			status = (hunks > 0 && unblessed) ? "unblessed" : "regression"
			print status "\t" results
		}
		/^diff /   { flush(); results = $NF; unblessed = 1; hunks = 0; next }
		/^@@ /     { hunks++; if ($0 !~ /^@@ -0,0 /) unblessed = 0; next }
		/^[ +-]/   { next }
		/^\\/      { next }
		/^$/       { next }
		           { unrecognized = 1 }
		END        { flush(); if (unrecognized) print "unrecognized\t" FILENAME }
	' "$diffs")

	blocked=
	blessable=
	ignored=
	while IFS="$(printf '\t')" read -r kind file; do
		# A TAP test with a SQL error keeps its block: it already failed above,
		# and the diff shows where.
		if [ -n "$pgtap_only" ] && [ "$kind" != unrecognized ] && [ -r "$file" ] &&
			[ -n "$("$check_tap" --list "$file")" ] && ! grep -qE "$sql_error" "$file"; then
			ignored="$ignored $(basename "$file" .out)"
			continue
		fi
		case $kind in
		unblessed)
			# An unblessed file holding a hard SQL error is not a passing test
			# the pgtap scan above was merely quiet about: ON_ERROR_STOP aborts
			# the script, so pgtap emits neither 'not ok' nor its plan-mismatch
			# line. Blessing that would make the error the baseline.
			if [ -z "$for_test" ] && [ -r "$file" ] && ! grep -qE "$sql_error" "$file"; then
				blessable="$blessable  $file
"
				continue
			fi
			;;
		unrecognized)
			blocked="$blocked  (unrecognized content in $file)
"
			continue
			;;
		esac
		blocked="$blocked  $file
"
	done <<EOF
$classified
EOF

	# Nothing recognizable in a non-empty regression.diffs: refuse to guess.
	[ -n "$classified" ] || blocked="  (unrecognized $diffs content)
"

	[ -z "$ignored" ] ||
		echo "NOTE: pgtap-only mode ignored regression.diffs differences in TAP tests:$ignored"

	if [ -n "$blocked" ]; then
		if [ -n "$for_test" ]; then
			cat "$diffs"
			exit 1
		fi
		echo "ERROR: Tests are failing.$cannot"
		echo "Fix test failures first, then run 'make results'."
		echo
		echo "Failing tests:"
		printf '%s' "$blocked"
		echo
		echo "See $diffs for details:"
		cat "$diffs"
		exit 1
	fi

	if [ -n "$blessable" ]; then
		echo "NOTE: these tests have no expected output yet; 'make results' will create it:"
		printf '%s' "$blessable"
	fi
fi

exit "$status"
