#!/usr/bin/env bash
# Record one interview question from the default mic, then run the latency bench.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SECONDS_TO_RECORD="${1:-8}"

python3 "$ROOT_DIR/Scripts/bench-voice-latency.py" --record "$SECONDS_TO_RECORD" --compare --runs 1
