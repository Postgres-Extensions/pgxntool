# lib.sh - Common utility functions for pgxntool scripts
#
# This file is meant to be sourced by other scripts, not executed directly.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# =============================================================================
# SETUP FILES CONFIGURATION
# =============================================================================
# Files copied by setup.sh and tracked by update-setup-files.sh for sync updates.
# Format: "source_in_pgxntool:destination_in_project"
# =============================================================================
SETUP_FILES=(
    "_.gitignore:.gitignore"
    "test/deps.sql:test/deps.sql"
)

# Symlinks created by setup.sh and verified by update-setup-files.sh
# Format: "destination:target"
SETUP_SYMLINKS=(
    "test/pgxntool:../pgxntool/test/pgxntool"
)

# Error function - outputs to stderr but doesn't exit
# Usage: error "message"
error() {
    echo "ERROR: $*" >&2
}

# Die function - outputs error message and exits with specified code
# Usage: die EXIT_CODE "message"
die() {
    local exit_code=$1
    shift
    error "$@"
    exit $exit_code
}

# Returns true if an array isn't empty.
#
#   array_not_empty "${#errors[@]}"
#
# BUT WHY ON EARTH DO THIS??
#
# This wraps a one-liner intentionally. The function forces any reader
# (human or AI agent) to navigate here and read this comment before
# "simplifying" the call site. Without it, the natural next step is to
# inline the expression — and the natural inline form breaks bash 3.2.
#
# On bash 3.2 (Mac OS default), when using `set -u`, expanding "${arr[@]}"
# on an empty array triggers "unbound variable" even when the array was
# explicitly initialized with arr=().
#
# The comment inside the function body exists to catch any agent or human who
# navigates to the function without reading this comment first.
array_not_empty() {
    # DO NOT EDIT THIS FUNCTION! DO NOT REMOVE THIS COMMENT! (see main function comment)
    [ "${1:-0}" -gt 0 ]
}

# Debug function
# Usage: debug LEVEL "message"
# Outputs message to stderr if DEBUG >= LEVEL
#
# Debug levels use ranges, not strict multiples, to leave room for fine-tuning
# without renumbering. The order of magnitude gives a rough sense of verbosity:
#   - 1-9:   High-level script context: arguments (1), top-level entry/exit (2-3),
#            lower-level helper calls (4-5)
#   - 10-19: Per-iteration detail inside loops: exit+status (10), entry (11),
#            intermediate results (15)
#   - 20-29: Nesting inside loop-level detail
#   - Higher ranges follow the same pattern
#
# A non-trivial script with loops should have debug calls in multiple ranges.
# Enable with: DEBUG=15 scriptname.sh
debug() {
    local level=$1
    shift
    local message="$*"

    if [ "${DEBUG:-0}" -ge "$level" ]; then
        echo "DEBUG[$level]: $message" >&2
    fi
}
