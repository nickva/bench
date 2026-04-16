#!/usr/bin/env bash
#
# Scheduler responsiveness benchmark. See if json encoding/decoding blocks
# schedulers.
#
# Usage:
#   bench/bench_scheduling.sh [json_mod1,,json_mod2,...]
#
# Some configuration is with env vars:
#   BENCH_JSON        (default citm-catalog.json)
#   BENCH_DURATION_MS (default 3000)
#
# Examples:
#   bench/bench_scheduling.sh
#   BENCH_JSON=canada.json bench/bench_scheduling.sh jiffy,json

set -euo pipefail

# Run from bench which should be in the jiffy directory
JIFFY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH_DIR="$JIFFY_ROOT/bench"

IMPLS="${1:-jiffy,json}"

OTP_VER=$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)])' -s init stop)
if [ "$OTP_VER" -lt 27 ]; then
    echo "ERROR: impl 'json' requires OTP 27+ (current: $OTP_VER)" >&2
    exit 1
fi

(cd "$JIFFY_ROOT" && make --quiet)
(cd "$BENCH_DIR" && mix deps.get >/dev/null && mix deps.compile >/dev/null)

cd "$BENCH_DIR"
BENCH_IMPLS="$IMPLS" mix run -e ':bench_scheduling.main()'
