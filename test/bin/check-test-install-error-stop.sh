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
# A file passes if it either:
#   - explicitly enables ON_ERROR_STOP itself (`\set ON_ERROR_STOP` on/true/1/
#     yes) anywhere; it may then also disable it anywhere, or
#   - includes test/pgxntool/psql.sql and never disables ON_ERROR_STOP
#     (`\set ON_ERROR_STOP` off/false/0/no, or `\unset ON_ERROR_STOP`).
# Every other file fails. A user who explicitly enables ON_ERROR_STOP is
# assumed to know what they're doing if they also disable it; there's no
# reason to think a user who includes psql.sql knows it enables ON_ERROR_STOP.
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

# Prints why $1 fails the rule in the header, or nothing if it passes.
error_stop_problem() {
  local f="$1" line direct_on=no psql_sql=no disabled=no
  while IFS= read -r line; do
    if [[ "$line" =~ \\ir?[[:space:]]+.*psql\.sql ]]; then
      psql_sql=yes
    elif [[ "$line" =~ \\unset[[:space:]]+ON_ERROR_STOP([[:space:]]|$) ]]; then
      disabled=yes
    elif [[ "$line" =~ \\set[[:space:]]+ON_ERROR_STOP[[:space:]]+([^[:space:]]+) ]]; then
      case "${BASH_REMATCH[1],,}" in
        on|true|1|yes) direct_on=yes ;;
        off|false|0|no) disabled=yes ;;
      esac
    fi
  done < "$f"

  if [ "$direct_on" = yes ]; then
    return
  elif [ "$psql_sql" = no ]; then
    echo "never sets ON_ERROR_STOP"
  elif [ "$disabled" = yes ]; then
    echo "includes psql.sql but also disables ON_ERROR_STOP"
  fi
}

for f in "$install_dir"/*.sql; do
  [ -f "$f" ] || continue
  problem=$(error_stop_problem "$f")
  if [ -n "$problem" ]; then
    missing+=("$f: $problem")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  error "the following test/install/*.sql files don't reliably set ON_ERROR_STOP:"
  printf '  %s\n' "${missing[@]}" >&2
  error "test/install files run in their own self-comparing pg_regress entry" \
    "(see the test/install comments in base.mk) -- without ON_ERROR_STOP, a" \
    "hard SQL error is silently swallowed instead of failing the build."
  die 1 "Add '\\set ON_ERROR_STOP on' near the top of the file. Including" \
    "test/pgxntool/psql.sql (which also sets it) is enough only if the file" \
    "never turns ON_ERROR_STOP off."
fi

# vi: expandtab ts=2 sw=2
