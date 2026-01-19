---
allowed-tools: Bash(cp:*), Bash(./build.sh:*), Bash(ls:*), Bash(test:*)
description: Build and install the app to /Applications
---

## Context

- Current installation: !`ls -la /Applications/ai-notifier.app 2>/dev/null || echo "not installed"`
- Build status: !`ls -la .build/ai-notifier.app 2>/dev/null || echo "not built"`

## Instructions

1. **Build** (if needed)
   ```bash
   ./build.sh
   ```

2. **Install** to /Applications
   ```bash
   cp -r .build/ai-notifier.app /Applications/
   ```

3. **Verify** installation
   ```bash
   ls -la /Applications/ai-notifier.app/Contents/MacOS/ai-notifier
   ```

4. **Run setup** (if first install)
   ```bash
   /Applications/ai-notifier.app/Contents/MacOS/ai-notifier --setup
   ```
