#!/bin/bash
# Stop hook: Verify the app still builds and works after changes

set -e

INPUT=$(cat)

# Check if there are Swift file changes
if ! git diff --name-only HEAD 2>/dev/null | grep -q "\.swift$"; then
    # No Swift changes, allow stop (output nothing for success)
    exit 0
fi

# Quick build check
if ! ./build.sh > /tmp/ai-notifier-build.log 2>&1; then
    echo '{"decision": "block", "reason": "Build failed. Please fix build errors before stopping."}'
    exit 0
fi

# Quick functionality check
rm -f /tmp/ai-notifier-debug.log
echo '{"hook_event_name":"Stop","cwd":"/tmp"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
PID=$!
sleep 2
kill $PID 2>/dev/null || true

if ! grep -q "Notification sent: success" /tmp/ai-notifier-debug.log 2>/dev/null; then
    echo '{"decision": "block", "reason": "Verification failed. Notifications are not being sent correctly."}'
    exit 0
fi

# All checks passed (output nothing for success)
exit 0
