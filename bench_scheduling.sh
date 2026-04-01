#!/usr/bin/env bash
#
# Responsiveness benchmark. See if encoding/decoding blocks
# schdulers.
#
# Run as:
#   bench/bench_scheduling.sh
#   bench/bench_scheduling.sh jiffy,json
#
# The argument can be a comma separated list of implemenations see IMPLS
# variable and what src/bench_scheduling.erl has implemented.

set -euo pipefail

JIFFY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH_DIR="$JIFFY_ROOT/bench"
IMPLS="json,jiffy,simdjsone,jsone,jsx"
if [ $# -gt 0 ]; then
    IMPLS="$1"
fi
(cd "$JIFFY_ROOT" && make --quiet)
# simdjsone's Makefile links its .so before creating priv/, so on a
# cold checkout the first compile fails. Try, mkdir the missing dir,
# retry
(cd "$BENCH_DIR" && mix deps.get >/dev/null)
(cd "$BENCH_DIR" && mix deps.compile simdjsone >/dev/null 2>&1) || true
mkdir -p "$BENCH_DIR/_build/dev/lib/simdjsone/priv"
(cd "$BENCH_DIR" && mix deps.compile >/dev/null)
cd "$BENCH_DIR"
BENCH_IMPLS="$IMPLS" mix run -e ':bench_scheduling.main()'
