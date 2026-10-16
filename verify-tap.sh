#!/usr/bin/env bash
# pgxntool/verify-tap.sh - Fail if TAP (pgTAP) output shows a failed test run
#
# Usage: verify-tap.sh [--skip-non-tap] [FILE|-]...
#
# Each FILE is judged as its own TAP stream; with no arguments, or for `-`,
# stdin is read. Problems go to stderr, naming the source ("stdin" or the
# path). Exits 0 if every input passes, 1 if any fails, 2 on a usage error or
# an unreadable file (in which case nothing is judged).
#
# A stream passes only if, counting unindented lines alone (subtest output is
# ignored):
#   - no `not ok` line lacks `# TODO`
#   - there is no `Bail out!` line
#   - there is no pgTAP "# Looks like you planned" line
#   - there is exactly one plan line (`1..N`), before every test line
#     (plan(N)) or after every one (no_plan() plus finish())
#   - the number of test lines (`ok N`/`not ok N`) equals N; `1..0` with no
#     tests passes
# A stream with no plan line and no test lines fails: nothing ran. With
# --skip-non-tap, such a stream (plain SQL output, say) is skipped silently
# instead.

set -o errexit -o errtrace -o pipefail

usage() {
  echo "Usage: verify-tap.sh [--skip-non-tap] [FILE|-]..."
}

SKIP_NON_TAP=
files=()
for arg in "$@"; do
  case $arg in
  -h|--help)
    usage
    exit 0
    ;;
  --skip-non-tap)
    SKIP_NON_TAP=1
    continue
    ;;
  -) ;;
  -*)
    echo "verify-tap.sh: unknown option '$arg'" >&2
    usage >&2
    exit 2
    ;;
  *)
    if [ ! -f "$arg" ] || [ ! -r "$arg" ]; then
      echo "verify-tap.sh: cannot read '$arg'" >&2
      exit 2
    fi
    ;;
  esac
  files+=("$arg")
done
[ ${#files[@]} -gt 0 ] || files=(-)
export SKIP_NON_TAP

# Judges the stream on stdin, named $SRC. The input is redirected rather than
# passed as an awk operand so a path containing `=` isn't taken as an
# assignment.
check_stream() {
  awk '
    /^(not )?ok [0-9]/ {
      tests++
      if (!first_test) first_test = NR
      last_test = NR
    }
    /^not ok/ && !/# TODO/      { notok = notok $0 "\n" }
    /^Bail out!/                { bail = bail $0 "\n" }
    /^# Looks like you planned/ { looks = looks $0 "\n" }
    /^1\.\.[0-9]/               { plans++; plan_nr = NR; planned = substr($1, 4) + 0 }
    END {
      src = ENVIRON["SRC"]
      if (tests + plans == 0) {
        if (ENVIRON["SKIP_NON_TAP"] != "") exit 0
        print "ERROR: no TAP output in " src " (no plan line or test lines); nothing ran"
        exit 1
      }
      if (notok != "") {
        print "ERROR: pgtap failure detected in " src
        printf "%s", notok
        failed = 1
      }
      if (bail != "") {
        print "ERROR: pgtap run bailed out in " src
        printf "%s", bail
        failed = 1
      }
      # One plan problem per stream: the pgTAP mismatch line already says
      # what a count check would.
      if (looks != "") {
        print "ERROR: pgtap plan mismatch in " src
        printf "%s", looks
        failed = 1
      } else if (plans == 0) {
        print "ERROR: pgtap output in " src " has no plan line (1..N); the test likely died before finishing"
        failed = 1
      } else if (plans > 1) {
        print "ERROR: pgtap output in " src " has " plans " plan lines (1..N); expected exactly one"
        failed = 1
      } else if (tests && plan_nr > first_test && plan_nr < last_test) {
        print "ERROR: pgtap output in " src " has its plan line (1..N) between test lines; it must come first or last"
        failed = 1
      } else if (tests != planned) {
        print "ERROR: pgtap plan mismatch in " src ": planned " planned " tests but found " tests
        failed = 1
      }
      exit failed
    }
  ' >&2
}

failed=0
for arg in "${files[@]}"; do
  if [ "$arg" = - ]; then
    SRC=stdin check_stream || failed=1
  else
    SRC=$arg check_stream < "$arg" || failed=1
  fi
done

exit "$failed"

# vi: expandtab ts=2 sw=2
