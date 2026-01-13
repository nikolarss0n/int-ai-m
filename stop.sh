#!/bin/bash
# Stop ALL Interview Master instances
count=$(pgrep -f InterviewMaster | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
    pkill -9 -f InterviewMaster
    echo "✅ Killed $count instance(s)"
else
    echo "ℹ️ No instances running"
fi
