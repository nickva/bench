#!/usr/bin/env bash
#
# Throughput benchmark driver. Compares jiffy branches and/or other libraries.
# Expected to be run from jiffy's directory; walks up to find the project root.
#
# Usage:
#   bench/bench.sh [base_branch] [--compare LIST]
#
# Args:
#   base_branch:  branch or tag (default: master) to compare current branch to
#
# Flags:
#   --compare LIST  other libs to include in the final comparison:
#                   "jiffy"" (default), or empty for jiffy-only, or a comma
#                   list of: json, simdjsone, jsone, jsx.
#
# Examples:
#   bench/bench.sh                          # master vs HEAD + all libs
#   bench/bench.sh v1.1.3                   # v1.1.3 vs HEAD
#   bench/bench.sh --compare jsone,jsx      # compare jiffy to two external libraries

set -euo pipefail
export PATH="$HOME/bin:$PATH"

JIFFY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH_DIR="$JIFFY_ROOT/bench"
RESULTS_DIR="$BENCH_DIR/results"
TEST_BRANCH=$(git -C "$JIFFY_ROOT" rev-parse --abbrev-ref HEAD)

BASE_BRANCH=master
COMPARE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --compare)
            [ $# -ge 2 ] || { echo "--compare requires a value" >&2; exit 2; }
            COMPARE="$2"; shift 2 ;;
        --compare=*)    COMPARE="${1#*=}"; shift ;;
        -*)             echo "unknown flag: $1" >&2; exit 2 ;;
        *)              BASE_BRANCH="$1"; shift ;;
    esac
done

if ! git -C "$JIFFY_ROOT" diff --quiet || ! git -C "$JIFFY_ROOT" diff --cached --quiet; then
    echo "ERROR: Working tree is dirty. Commit or stash before benchmarking." >&2
    exit 1
fi

# Fetch deps once. simdjsone's Makefile links its .so before creating
# priv/, so on a cold checkout the first compile fails. We try, mkdir
# the missing dir, and retry
(cd "$BENCH_DIR" && mix deps.get >/dev/null)
(cd "$BENCH_DIR" && mix deps.compile simdjsone >/dev/null 2>&1) || true
mkdir -p "$BENCH_DIR/_build/dev/lib/simdjsone/priv"
(cd "$BENCH_DIR" && mix deps.compile >/dev/null)

ORIG_REF=$(git -C "$JIFFY_ROOT" rev-parse HEAD)
mkdir -p "$RESULTS_DIR"

cleanup() {
    set +e
    echo "" >&2
    echo "Restoring branch $TEST_BRANCH..." >&2
    git -C "$JIFFY_ROOT" checkout "$TEST_BRANCH" --quiet 2>/dev/null || \
        git -C "$JIFFY_ROOT" checkout "$ORIG_REF" --quiet
    (cd "$JIFFY_ROOT" && make --quiet 2>/dev/null)
    rm -rf "$RESULTS_DIR"
}
trap cleanup EXIT

# Clean up of a bunch of benchee output looks a bit messy on non-unicode
# terminals, things like +/-, greek unit letters etc
filter_output() {
    grep -Ev '^==>|^\s*\((benchee|elixir)|^\s*warning:|^$' \
    | sed 's/μ/u/g; s/±/+\/-/g; s/#/=/g; s/\\x{3BC}/u/g; s/\\x{B1}/+\/-/g' \
    | LC_ALL=C sed "s/$(printf '\xb5')/u/g; s/$(printf '\xb1')/+\/-/g"
}

banner() {
    echo ""
    echo "================================================================"
    echo "  $*"
    echo "================================================================"
}

# build <branch>
build() {
    local branch="$1"
    banner "[$branch] Build"
    git -C "$JIFFY_ROOT" checkout "$branch" --quiet
    # Hard-wipe _build dirs instead of `make clean` / `mix deps.clean`. Older
    # tags have a shallow Makefile clean target
    (cd "$JIFFY_ROOT" && rm -rf _build && make --quiet 2>&1 | tail -3)
    (cd "$BENCH_DIR" && rm -rf _build && mix deps.get >/dev/null 2>&1)
}

# run_bench <label> [TAG=X] [SAVE=path] [LOAD=path] [COMPARE=list]
run_bench() {
    local label="$1"; shift
    local env=()
    for arg in "$@"; do env+=("$arg"); done
    banner "[$label] Bench"
    (cd "$BENCH_DIR" && env "${env[@]}" mix run bench.exs 2>&1 | grep -Ev 'Validating|Testing' | filter_output)
}

if [ "$BASE_BRANCH" = "$TEST_BRANCH" ]; then
    # Same branch on both, nothing to compare, just run once
    echo "Base == test ($BASE_BRANCH). Single run, no baseline save."
    build "$BASE_BRANCH"
    run_bench "$BASE_BRANCH" "BENCH_COMPARE=$COMPARE"
else
    # Different branches. Run baseline then again to compare.
    build "$BASE_BRANCH"
    run_bench "$BASE_BRANCH (saving baseline)" "BENCH_TAG=$BASE_BRANCH" "BENCH_SAVE=$RESULTS_DIR/baseline.benchee"
    build "$TEST_BRANCH"
    run_bench "$TEST_BRANCH vs $BASE_BRANCH" "BENCH_TAG=$TEST_BRANCH" "BENCH_LOAD=$RESULTS_DIR/baseline.benchee" "BENCH_COMPARE=$COMPARE"
fi

echo ""
echo "DONE"
