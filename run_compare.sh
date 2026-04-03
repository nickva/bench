#!/usr/bin/env bash
#
# Use benchee bench from jason. Run benchmark against the master branch.
# Update the benchmark to compare against the built-in json
#
# Usage:
#   bench/run_compare.sh [base_branch]
#
# The default branch is "master"

set -euo pipefail

export PATH="$HOME/bin:$PATH"

JIFFY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_BRANCH="${1:-master}"
TEST_BRANCH=$(git -C "$JIFFY_ROOT" rev-parse --abbrev-ref HEAD)
BENCH_DIR="$JIFFY_ROOT/bench"
RESULTS_DIR="$BENCH_DIR/results"

if ! git -C "$JIFFY_ROOT" diff --quiet || ! git -C "$JIFFY_ROOT" diff --cached --quiet; then
    echo "ERROR: Working tree is dirty. Commit or stash changes before benchmarking." >&2
    exit 1
fi

OTP_VER=$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)])' -s init stop)
echo "Using OTP $OTP_VER"

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
    | sed 's/μ/u/g; s/±/+\/-/g; s/#/=/g'
}

build_branch() {
    local branch="$1"

    echo ""
    echo "================================================================"
    echo "  [$branch] Build"
    echo "================================================================"
    git -C "$JIFFY_ROOT" checkout "$branch" --quiet
    cd "$JIFFY_ROOT"
    rm -rf _build/default/lib/jiffy _build/bench/lib/jiffy 2>/dev/null || true
    make --quiet 2>&1 | tail -3
    cd "$BENCH_DIR"
    rm -rf _build/*/lib/jiffy 2>/dev/null || true
}

echo "Comparing jiffy: $BASE_BRANCH vs $TEST_BRANCH"
echo ""

mkdir -p "$RESULTS_DIR"

# Run baseline branch and save results
build_branch "$BASE_BRANCH"

echo ""
echo "================================================================"
echo "  [$BASE_BRANCH] Decode (saving baseline)"
echo "================================================================"
BENCH_TAG="$BASE_BRANCH" BENCH_SAVE="$RESULTS_DIR/decode-baseline.benchee" \
    mix run decode.exs 2>&1 | grep -Ev 'Checking|Testing' | filter_output

echo ""
echo "================================================================"
echo "  [$BASE_BRANCH] Encode (saving baseline)"
echo "================================================================"
BENCH_TAG="$BASE_BRANCH" BENCH_SAVE="$RESULTS_DIR/encode-baseline.benchee" \
    mix run encode.exs 2>&1 | filter_output

# Run test branch and load baseline for comparison
build_branch "$TEST_BRANCH"

echo ""
echo "================================================================"
echo "  [$TEST_BRANCH vs $BASE_BRANCH] Decode"
echo "================================================================"
BENCH_TAG="$TEST_BRANCH" BENCH_LOAD="$RESULTS_DIR/decode-baseline.benchee" \
    mix run decode.exs 2>&1 | grep -Ev 'Checking|Testing' | filter_output

echo ""
echo "================================================================"
echo "  [$TEST_BRANCH vs $BASE_BRANCH] Encode"
echo "================================================================"
BENCH_TAG="$TEST_BRANCH" BENCH_LOAD="$RESULTS_DIR/encode-baseline.benchee" \
    mix run encode.exs 2>&1 | filter_output

echo ""
echo "All done"
