---
allowed-tools: Bash(./build.sh:*), Bash(echo:*), Bash(pkill:*), Bash(sleep:*), Bash(tail:*), Bash(cat:*), Bash(test:*), Bash(ls:*)
description: Verify the app works correctly with all CLI types
---

## Context

- App bundle: !`ls -la .build/ai-notifier.app/Contents/MacOS/ai-notifier 2>/dev/null || echo "not built"`
- Debug log: !`tail -5 /tmp/ai-notifier-debug.log 2>/dev/null || echo "no logs"`

## Test Matrix

Run the following tests and report results:

### 1. Build Verification
```bash
test -f .build/ai-notifier.app/Contents/MacOS/ai-notifier && echo "✅ Build exists" || echo "❌ Build missing"
```

### 2. Claude CLI Test (stdin)
```bash
echo '{"hook_event_name":"Stop","cwd":"/tmp/claude-test"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
sleep 2
grep "Detected CLI: claude" /tmp/ai-notifier-debug.log && echo "✅ Claude detected" || echo "❌ Claude not detected"
pkill -f "ai-notifier.app" 2>/dev/null || true
```

### 3. Gemini CLI Test (stdin with debounce)
```bash
echo '{"hook_event_name":"AfterModel","finishReason":"STOP","cwd":"/tmp/gemini-test"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
sleep 2
grep "Detected CLI: gemini" /tmp/ai-notifier-debug.log && echo "✅ Gemini detected" || echo "❌ Gemini not detected"
pkill -f "ai-notifier.app" 2>/dev/null || true
```

### 4. Codex CLI Test (argv)
```bash
.build/ai-notifier.app/Contents/MacOS/ai-notifier '{"event":"agent-turn-complete","cwd":"/tmp/codex-test"}' &
sleep 2
grep "Detected CLI: codex" /tmp/ai-notifier-debug.log && echo "✅ Codex detected" || echo "❌ Codex not detected"
pkill -f "ai-notifier.app" 2>/dev/null || true
```

### 5. OpenCode CLI Test (stdin with cli field)
```bash
echo '{"hook_event_name":"complete","cwd":"/tmp/opencode-test","cli":"opencode"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
sleep 2
grep "Detected CLI: opencode" /tmp/ai-notifier-debug.log && echo "✅ OpenCode detected" || echo "❌ OpenCode not detected"
pkill -f "ai-notifier.app" 2>/dev/null || true
```

### 6. Notification Sent
```bash
grep "Notification sent: success" /tmp/ai-notifier-debug.log && echo "✅ Notifications sent" || echo "❌ Notifications failed"
```

## Expected Results

All tests should pass:
- ✅ Build exists
- ✅ Claude detected
- ✅ Gemini detected
- ✅ Codex detected
- ✅ OpenCode detected
- ✅ Notifications sent
