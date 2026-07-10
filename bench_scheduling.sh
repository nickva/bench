#!/usr/bin/env bash
#
# Responsiveness benchmark. See if encoding/decoding blocks
# schdulers.
#
# Run as:
#   bench/bench_scheduling.sh
#   bench/bench_scheduling.sh jiffy,json
#   JIFFY_ROOT=~/src/jiffy ./bench_scheduling.sh
#
# The argument can be a comma separated list of implemenations see IMPLS
# variable and what src/bench_scheduling.erl has implemented.
#
# Locates the jiffy checkout the same way as bench.sh: the JIFFY_ROOT
# env var, then a jiffy symlink next to this script, then the parent
# directory (the classic jiffy/bench layout).

set -euo pipefail

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
JIFFY_CANDIDATE="${JIFFY_ROOT:-}"
if [ -z "$JIFFY_CANDIDATE" ]; then
    if [ -e "$BENCH_DIR/jiffy/src/jiffy.erl" ]; then
        JIFFY_CANDIDATE="$BENCH_DIR/jiffy"
    else
        JIFFY_CANDIDATE="$BENCH_DIR/.."
    fi
fi
if ! JIFFY_ROOT="$(cd "$JIFFY_CANDIDATE" 2>/dev/null && pwd)" \
        || [ ! -e "$JIFFY_ROOT/src/jiffy.erl" ]; then
    echo "ERROR: no jiffy checkout in '$JIFFY_CANDIDATE'. Either:" >&2
    echo "  - set JIFFY_ROOT=/path/to/jiffy, or" >&2
    echo "  - symlink a checkout: ln -s /path/to/jiffy '$BENCH_DIR/jiffy', or" >&2
    echo "  - put this bench directory inside jiffy as jiffy/bench" >&2
    exit 1
fi
export JIFFY_ROOT  # mix.exs locates the jiffy path dep with this

IMPLS="json,jiffy,glazer,jsone,jsx"
if [ $# -gt 0 ]; then
    IMPLS="$1"
fi
(cd "$JIFFY_ROOT" && make --quiet)
(cd "$BENCH_DIR" && mix deps.get >/dev/null)
(cd "$BENCH_DIR" && mix deps.compile >/dev/null)
cd "$BENCH_DIR"
BENCH_IMPLS="$IMPLS" mix run -e ':bench_scheduling.main()'
