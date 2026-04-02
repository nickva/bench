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

if ! git -C "$JIFFY_ROOT" diff --quiet || ! git -C "$JIFFY_ROOT" diff --cached --quiet; then
    echo "ERROR: Working tree is dirty. Commit or stash changes before benchmarking." >&2
    exit 1
fi

# OTP 27 and higher only has a built-in json module
OTP_VER=$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)])' -s init stop)
if [ "$OTP_VER" -lt 27 ] 2>/dev/null; then
    echo "ERROR: OTP 27+ required (found OTP $OTP_VER). Run: eval \"\$(mise env)\"" >&2
    exit 1
fi
echo "Using OTP $OTP_VER"

ORIG_REF=$(git -C "$JIFFY_ROOT" rev-parse HEAD)

cleanup() {
    set +e
    echo "" >&2
    echo "Restoring branch $TEST_BRANCH..." >&2
    git -C "$JIFFY_ROOT" checkout "$TEST_BRANCH" --quiet 2>/dev/null || git -C "$JIFFY_ROOT" checkout "$ORIG_REF" --quiet
    cd "$JIFFY_ROOT" && make --quiet 2>/dev/null
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

run_bench() {
    local branch="$1"

    echo ""
    echo "================================================================"
    echo "  [$branch] Build"
    echo "================================================================"
    git -C "$JIFFY_ROOT" checkout "$branch" --quiet
    cd "$JIFFY_ROOT"
    rm -rf _build/default/lib/jiffy _build/bench/lib/jiffy 2>/dev/null || true
    make --quiet 2>&1 | tail -3

    echo ""
    echo "================================================================"
    echo "  [$branch] Decode"
    echo "================================================================"
    cd "$BENCH_DIR"
    rm -rf _build/*/lib/jiffy 2>/dev/null || true
    mix run decode.exs 2>&1 | grep -Ev 'Checking|Testing' | filter_output

    echo ""
    echo "================================================================"
    echo "  [$branch] Encode"
    echo "================================================================"
    cd "$BENCH_DIR"
    mix run encode.exs 2>&1 | filter_output
}

echo "Comparing jiffy: $BASE_BRANCH vs $TEST_BRANCH"
echo ""

run_bench "$BASE_BRANCH"
run_bench "$TEST_BRANCH"

echo ""
echo "All done"
