#!/bin/bash
# Stop Interview Master without allowing the launchd job to relaunch it.
cd "$(dirname "$0")"

launch_labels=(
    "com.interviewmaster.local"
    "com.codex.interviewmaster"
)

existing_pids=$(pgrep -x InterviewMaster || true)

for label in "${launch_labels[@]}"; do
    launchctl remove "$label" 2>/dev/null || true
done

pids=$(pgrep -x InterviewMaster || true)
if [[ -z "$pids" ]]; then
    if [[ -n "$existing_pids" ]]; then
        count=$(echo "$existing_pids" | wc -l | tr -d ' ')
        echo "Stopped $count InterviewMaster instance(s)"
        exit 0
    fi

    echo "No InterviewMaster instances running"
    exit 0
fi

count=$(echo "$pids" | wc -l | tr -d ' ')
pkill -TERM -x InterviewMaster 2>/dev/null || true

for _ in {1..20}; do
    if ! pgrep -x InterviewMaster >/dev/null; then
        echo "Stopped $count InterviewMaster instance(s)"
        exit 0
    fi
    sleep 0.1
done

remaining=$(pgrep -x InterviewMaster || true)
if [[ -n "$remaining" ]]; then
    pkill -KILL -x InterviewMaster 2>/dev/null || true
fi

if pgrep -x InterviewMaster >/dev/null; then
    echo "Failed to stop InterviewMaster"
    exit 1
fi

echo "Stopped $count InterviewMaster instance(s)"
