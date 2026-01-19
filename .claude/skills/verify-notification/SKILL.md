---
name: verify-notification
description: Verify notification functionality works correctly. Use after making changes to notification-related code, hook parsing, or CLI detection.
allowed-tools: Bash, Read, Grep
---

# Verify Notification Skill

This skill provides a feedback loop for verifying that the ai-notifier app works correctly after changes.

## Verification Process

### 1. Build the App
```bash
./build.sh
```

### 2. Clear Previous Logs
```bash
rm -f /tmp/ai-notifier-debug.log
```

### 3. Test Each CLI Type

Run tests in sequence, checking logs after each:

**Claude CLI (stdin mode)**
```bash
echo '{"hook_event_name":"Stop","cwd":"/tmp/claude"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
sleep 2
pkill -f ai-notifier 2>/dev/null || true
grep "Detected CLI: claude" /tmp/ai-notifier-debug.log
```

**Gemini CLI (stdin with debounce)**
```bash
echo '{"hook_event_name":"AfterModel","finishReason":"STOP","cwd":"/tmp/gemini"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
sleep 2
pkill -f ai-notifier 2>/dev/null || true
grep "Detected CLI: gemini" /tmp/ai-notifier-debug.log
```

**Codex CLI (argv mode)**
```bash
.build/ai-notifier.app/Contents/MacOS/ai-notifier '{"event":"agent-turn-complete","cwd":"/tmp/codex"}' &
sleep 2
pkill -f ai-notifier 2>/dev/null || true
grep "Detected CLI: codex" /tmp/ai-notifier-debug.log
```

**OpenCode CLI (stdin with cli field)**
```bash
echo '{"hook_event_name":"complete","cli":"opencode","cwd":"/tmp/opencode"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
sleep 2
pkill -f ai-notifier 2>/dev/null || true
grep "Detected CLI: opencode" /tmp/ai-notifier-debug.log
```

### 4. Check Notification Success
```bash
grep "Notification sent: success" /tmp/ai-notifier-debug.log
```

### 5. View Full Logs
```bash
cat /tmp/ai-notifier-debug.log
```

## Expected Results

For each CLI type, verify:
- ✅ Correct CLI detected
- ✅ Correct project name extracted from cwd
- ✅ Notification sent successfully
- ✅ Terminal info captured

## Troubleshooting

If tests fail:
1. Check build output for errors
2. Review debug logs for parsing issues
3. Verify JSON input format matches expected schema
4. Check for process cleanup issues

## Reference

See [CLAUDE.md](../../../CLAUDE.md) for CLI-specific hook formats and detection methods.
