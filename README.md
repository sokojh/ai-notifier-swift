# AI Notifier

Native macOS notification app for AI coding assistants (Claude Code, Gemini CLI, Codex CLI).

Built with Swift using `UNUserNotificationCenter` for maximum compatibility with all macOS versions including Sequoia and Tahoe.

## Features

- **Native Swift**: No dependencies (no terminal-notifier, no Node.js)
- **Universal Binary**: Supports both Intel and Apple Silicon Macs
- **Modern API**: Uses `UNUserNotificationCenter` for latest macOS compatibility
- **Multi-CLI Support**: Works with Claude Code, Gemini CLI, and Codex CLI
- **CLI-specific Icons**: Shows different icons for each CLI

## Requirements

- macOS 11.0 (Big Sur) or later
- Xcode Command Line Tools (for building from source)

## Installation

### Build from source

```bash
git clone https://github.com/sokojh/ai-notifier-swift.git
cd ai-notifier-swift
./build.sh
cp -r .build/ai-notifier.app /Applications/
```

### One-liner

```bash
rm -rf /tmp/ai-notifier-swift && git clone https://github.com/sokojh/ai-notifier-swift.git /tmp/ai-notifier-swift && /tmp/ai-notifier-swift/build.sh && cp -r /tmp/ai-notifier-swift/.build/ai-notifier.app /Applications/ && codesign --force --deep --sign - /Applications/ai-notifier.app
```

## Usage

The app reads JSON data from stdin and sends a notification.

```bash
# Test notification
echo '{}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier
```

### CLI Hook Configuration

#### Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {"type": "command", "command": "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"}
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {"type": "command", "command": "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"}
        ]
      }
    ]
  }
}
```

#### Gemini CLI

Add to `~/.gemini/settings.json`:

```json
{
  "tools": {"enableHooks": true},
  "hooks": {
    "enabled": true,
    "AfterModel": [
      {
        "hooks": [
          {
            "name": "ai-notifier",
            "type": "command",
            "command": "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

#### Codex CLI

Add to `~/.codex/config.toml`:

```toml
[notice]
notify = ["/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"]
```

## Notification Permission

After installation, go to **System Settings → Notifications → AI Notifier**:

1. Enable **Allow Notifications**
2. Set notification style to **Alerts** (not Banners) to stack notifications

## Technical Details

- **Language**: Swift 5+
- **Minimum macOS**: 11.0 (Big Sur)
- **Notification API**: `UNUserNotificationCenter`
- **Architecture**: Universal Binary (arm64 + x86_64)
- **Code Signing**: Ad-hoc (local build)
- **Bundle ID**: `com.sokojh.ai-notifier`

## Why Native Swift?

- **terminal-notifier** uses deprecated `NSUserNotification` API and doesn't work on newer macOS
- **alerter** has the same issues
- **osascript** `display notification` doesn't work from Terminal on Sequoia
- This native app uses the modern `UNUserNotificationCenter` API that works everywhere

## License

MIT License
