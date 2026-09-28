#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${IM_RUN_LIVE_CLASSIFICATION:-0}" != "1" ]]; then
    echo 'Set IM_RUN_LIVE_CLASSIFICATION=1 to enable live Jev evaluation.'
    exit 2
fi
mkdir -p .codex-loop/jev-live
swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    Tests/test_jev_live.swift Infrastructure/API/JevDecisionClient.swift \
    -o .codex-loop/jev-live/evaluate
IM_JEV_ENABLED=1 .codex-loop/jev-live/evaluate
