#!/usr/bin/env bash
#
# Use benchee bench from jason. Run benchmark against the master branch.
# Update the benchmark to compare against the built-in json
#
# Usage:
#   bench/bench.sh [base_branch] [--native]
#
# The default branch is "master". When --native is passed, a third
# run added to the test branch rebuilt with CFLAGS=-march=native.

set -euo pipefail

export PATH="$HOME/bin:$PATH"

JIFFY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH_DIR="$JIFFY_ROOT/bench"
RESULTS_DIR="$BENCH_DIR/results"
TEST_BRANCH=$(git -C "$JIFFY_ROOT" rev-parse --abbrev-ref HEAD)

BASE_BRANCH=master
WITH_NATIVE=0
for arg in "$@"; do
    case "$arg" in
        --native) WITH_NATIVE=1 ;;
        -*)       echo "unknown flag: $arg" >&2; exit 2 ;;
        *)        BASE_BRANCH="$arg" ;;
    esac
done

if ! git -C "$JIFFY_ROOT" diff --quiet || ! git -C "$JIFFY_ROOT" diff --cached --quiet; then
    echo "ERROR: Working tree is dirty. Commit or stash changes before benchmarking." >&2
    exit 1
fi

OTP_VER=$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)])' -s init stop)
echo "Using OTP $OTP_VER"

# On first run after clone...
(cd "$BENCH_DIR" && mix deps.get >/dev/null && mix deps.compile >/dev/null)

ORIG_REF=$(git -C "$JIFFY_ROOT" rev-parse HEAD)

cleanup() {
    set +e
    echo "" >&2
    echo "Restoring branch $TEST_BRANCH..." >&2
    git -C "$JIFFY_ROOT" checkout "$TEST_BRANCH" --quiet 2>/dev/null || git -C "$JIFFY_ROOT" checkout "$ORIG_REF" --quiet
    cd "$JIFFY_ROOT" && make --quiet 2>/dev/null
    rm -rf "$RESULTS_DIR"
}
trap cleanup EXIT

# Bench dumps out a bunch of fancy non-ascii symbols and uses `#` for section delimiters
# so fix it up to remove those. Cleanup a bunch of elixir compiler warnings as well
#
filter_output() {
    grep -v '^==>' \
    | grep -Ev '^\s*\((benchee|elixir)|^\s*warning:|^$' \
    | sed 's/μ/u/g; s/±/+\/-/g; s/#/=/g' \
    | sed 's/\\x{3BC}/u/g; s/\\x{B1}/+\/-/g'
}

build_branch() {
    local branch="$1"
    local extra_cflags="${2:-}"
    local label="$branch"
    [ -n "$extra_cflags" ] && label="$branch [$extra_cflags]"

    echo ""
    echo "================================================================"
    echo "  [$label] Build"
    echo "================================================================"
    git -C "$JIFFY_ROOT" checkout "$branch" --quiet

    # Export CFLAGS so rebar3's port compiler picks it up
    export CFLAGS="$extra_cflags"

    cd "$JIFFY_ROOT"
    make clean --quiet >/dev/null
    make --quiet 2>&1 | tail -3

    # Clean bench's own copy of the jiffy dep so mix rebuilds it
    cd "$BENCH_DIR"
    mix deps.clean jiffy --build >/dev/null 2>&1 || true
}

if [ "$WITH_NATIVE" -eq 1 ]; then
    echo "Comparing jiffy: $BASE_BRANCH vs $TEST_BRANCH vs $TEST_BRANCH [-march=native]"
else
    echo "Comparing jiffy: $BASE_BRANCH vs $TEST_BRANCH"
fi
echo ""

mkdir -p "$RESULTS_DIR"

# 1. Baseline branch, default CFLAGS
build_branch "$BASE_BRANCH"

echo ""
echo "================================================================"
echo "  [$BASE_BRANCH] Bench (saving baseline)"
echo "================================================================"
BENCH_TAG="$BASE_BRANCH" BENCH_SAVE="$RESULTS_DIR/baseline.benchee" \
    mix run bench.exs 2>&1 | grep -Ev 'Checking|Testing' | filter_output

# 2. Test branch, with default CFLAGS. If --native arg is not given, this is
# the final run and loads the baseline. If --native is set, this saves its
# result so the third run can load both as baselines for a 3-way comparison.
build_branch "$TEST_BRANCH"

echo ""
echo "================================================================"
echo "  [$TEST_BRANCH vs $BASE_BRANCH] Bench"
echo "================================================================"
if [ "$WITH_NATIVE" -eq 1 ]; then
    # Only save here so test.benchee contains this run
    # alone. We don't want to combine the results yet.
    BENCH_TAG="$TEST_BRANCH" \
    BENCH_SAVE="$RESULTS_DIR/test.benchee" \
        mix run bench.exs 2>&1 | grep -Ev 'Checking|Testing' | filter_output

    build_branch "$TEST_BRANCH" "-march=native"

    echo ""
    echo "================================================================"
    echo "  [$TEST_BRANCH -march=native vs $TEST_BRANCH vs $BASE_BRANCH] Bench"
    echo "================================================================"
    BENCH_TAG="$TEST_BRANCH native" \
    BENCH_LOAD="$RESULTS_DIR/baseline.benchee:$RESULTS_DIR/test.benchee" \
        mix run bench.exs 2>&1 | grep -Ev 'Checking|Testing' | filter_output
else
    BENCH_TAG="$TEST_BRANCH" BENCH_LOAD="$RESULTS_DIR/baseline.benchee" \
        mix run bench.exs 2>&1 | grep -Ev 'Checking|Testing' | filter_output
fi

echo ""
echo "DONE"
