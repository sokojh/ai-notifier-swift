---
allowed-tools: Bash(./build.sh:*), Bash(echo:*), Bash(pkill:*), Bash(sleep:*), Bash(tail:*), Bash(cat:*)
description: Build the app and run basic tests
---

## Context

- Build script exists: !`test -f build.sh && echo "yes" || echo "no"`
- Last build: !`ls -la .build/ai-notifier.app/Contents/MacOS/ai-notifier 2>/dev/null || echo "not found"`

## Instructions

1. **Build**: Run the build script
   ```bash
   ./build.sh
   ```

2. **Test**: Run basic functionality tests
   - Test Claude stdin mode:
     ```bash
     echo '{"hook_event_name":"Stop","cwd":"/tmp"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
     sleep 2
     pkill -f "ai-notifier.app" 2>/dev/null || true
     ```

   - Test Codex argv mode:
     ```bash
     .build/ai-notifier.app/Contents/MacOS/ai-notifier '{"event":"agent-turn-complete","cwd":"/tmp"}' &
     sleep 2
     pkill -f "ai-notifier.app" 2>/dev/null || true
     ```

3. **Check logs**: Verify notifications were sent
   ```bash
   tail -20 /tmp/ai-notifier-debug.log
   ```

4. **Report**: Summary of build and test results
