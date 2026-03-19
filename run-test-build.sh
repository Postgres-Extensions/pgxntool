#!/usr/bin/env bash
# pgxntool/run-test-build.sh - Prepare test/build/ for the test-build target
#
# Sets up the generated sql/ directory and ensures expected/*.out files exist
# so pg_regress can run without aborting on missing files.
#
# Usage: run-test-build.sh TESTDIR
#
# Called by the test-build target in base.mk before running installcheck.

set -e

TESTDIR="${1:?Usage: run-test-build.sh TESTDIR}"
BUILD_DIR="$TESTDIR/build"
SQL_DIR="$BUILD_DIR/sql"
EXPECTED_DIR="$BUILD_DIR/expected"

mkdir -p "$SQL_DIR"
mkdir -p "$EXPECTED_DIR"

# Copy .sql files to sql/ directory for pg_regress.
# When no files match, bash leaves the glob unexpanded (literal "*.sql").
# Capture into an array first: if the first element equals the literal pattern,
# no files matched and we skip the copy.
files=("$BUILD_DIR"/*.sql)
[ "${files[0]}" = "$BUILD_DIR/*.sql" ] || cp "${files[@]}" "$SQL_DIR/"

# Create empty expected/*.out files for .sql tests (if not already present).
# pg_regress requires an expected file to exist for each test; without it
# pg_regress stops immediately rather than running the test and showing the diff.
for file in "$BUILD_DIR"/*.sql; do
	[ -f "$file" ] || continue
	out="$EXPECTED_DIR/$(basename "$file" .sql).out"
	[ -f "$out" ] || touch "$out"
done

# Create empty expected/*.out files for input/*.source tests (if not already present)
for file in "$BUILD_DIR/input"/*.source; do
	[ -f "$file" ] || continue
	out="$EXPECTED_DIR/$(basename "$file" .source).out"
	[ -f "$out" ] || touch "$out"
done
