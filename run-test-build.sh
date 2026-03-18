#!/bin/bash
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

# Copy .sql files to sql/ directory for pg_regress
# Note: [ -f ] guards against no glob matches (bash returns the literal
# glob string "*.sql" rather than nothing when no files match).
for file in "$BUILD_DIR"/*.sql; do
	[ -f "$file" ] || continue
	cp "$file" "$SQL_DIR/$(basename "$file")"
done

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
