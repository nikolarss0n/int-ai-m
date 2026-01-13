#!/bin/bash
# Show stealth logs
LOG_FILE=~/Documents/stealth_log.txt

if [ ! -f "$LOG_FILE" ]; then
    echo "ℹ️ No logs yet. Run ./start.sh first."
    exit 0
fi

echo "📋 STEALTH LOG (~/Documents/stealth_log.txt)"
echo "============================================"
cat "$LOG_FILE"
echo ""
echo "---"
echo "🔍 Summary:"
echo "   Clicks: $(grep -c 'CLICK' "$LOG_FILE")"
echo "   Hotkeys: $(grep -c 'HOTKEY' "$LOG_FILE")"
echo "   Frontmost changes: $(grep -c 'FRONTMOST APP' "$LOG_FILE") (OK - visual only)"
keyboard_stolen=$(grep 'KEYBOARD FOCUS STOLEN' "$LOG_FILE" | wc -l | tr -d ' ')
echo ""
if [ "$keyboard_stolen" = "0" ]; then
    echo "✅ VERDICT: SAFE - Browser never lost keyboard focus"
else
    echo "🔴 VERDICT: UNSAFE - Keyboard focus was stolen $keyboard_stolen time(s)!"
fi
