---
allowed-tools: Bash(./build.sh:*), Bash(echo:*), Bash(pkill:*), Bash(sleep:*), Bash(tail:*), Bash(cat:*), Bash(test:*), Bash(ls:*), Bash(ps:*), Bash(rm:*), Bash(wc:*)
description: Verify the app works correctly with all CLI types
---

## Context

- App bundle: !`ls -la .build/ai-notifier.app/Contents/MacOS/ai-notifier 2>/dev/null || echo "not built"`
- Debug log: !`tail -5 /tmp/ai-notifier-debug.log 2>/dev/null || echo "no logs"`
- Running processes: !`ps aux | grep ai-notifier | grep -v grep | wc -l`

## Pre-Test Cleanup

```bash
# 기존 프로세스 및 PID 파일 정리
pkill -f "ai-notifier" 2>/dev/null || true
rm -f /tmp/.ai-notifier.pid
rm -f /tmp/ai-notifier-debug.log
sleep 1
```

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
```

### 3. Gemini CLI Test (stdin with debounce)
```bash
echo '{"hook_event_name":"AfterModel","finishReason":"STOP","cwd":"/tmp/gemini-test"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
sleep 2
grep "Detected CLI: gemini" /tmp/ai-notifier-debug.log && echo "✅ Gemini detected" || echo "❌ Gemini not detected"
```

### 4. Codex CLI Test (argv)
```bash
.build/ai-notifier.app/Contents/MacOS/ai-notifier '{"event":"agent-turn-complete","cwd":"/tmp/codex-test"}' &
sleep 2
grep "Detected CLI: codex" /tmp/ai-notifier-debug.log && echo "✅ Codex detected" || echo "❌ Codex not detected"
```

### 5. OpenCode CLI Test (stdin with cli field)
```bash
echo '{"hook_event_name":"complete","cwd":"/tmp/opencode-test","cli":"opencode"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
sleep 2
grep "Detected CLI: opencode" /tmp/ai-notifier-debug.log && echo "✅ OpenCode detected" || echo "❌ OpenCode not detected"
```

### 6. Notification Sent
```bash
grep "Notification sent: success" /tmp/ai-notifier-debug.log && echo "✅ Notifications sent" || echo "❌ Notifications failed"
```

### 7. Process Singleton Test (중복 방지)
```bash
PROC_COUNT=$(ps aux | grep ai-notifier | grep -v grep | wc -l | tr -d ' ')
if [ "$PROC_COUNT" -le "1" ]; then
    echo "✅ Single process running ($PROC_COUNT)"
else
    echo "❌ Multiple processes running ($PROC_COUNT) - 중복 프로세스 문제!"
fi
```

### 8. PID File Check
```bash
if [ -f /tmp/.ai-notifier.pid ]; then
    echo "✅ PID file exists: $(cat /tmp/.ai-notifier.pid)"
else
    echo "⚠️ PID file not found (OK if no background process)"
fi
```

## Post-Test Cleanup

```bash
pkill -f "ai-notifier" 2>/dev/null || true
rm -f /tmp/.ai-notifier.pid
```

## Expected Results

All tests should pass:
- ✅ Build exists
- ✅ Claude detected
- ✅ Gemini detected
- ✅ Codex detected
- ✅ OpenCode detected
- ✅ Notifications sent
- ✅ Single process running (0 or 1)
- ✅ PID file exists (if background running)
