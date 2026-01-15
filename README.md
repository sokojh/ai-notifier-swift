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

### One-liner (권장)

```bash
rm -rf /tmp/ai-notifier-swift && git clone https://github.com/sokojh/ai-notifier-swift.git /tmp/ai-notifier-swift && /tmp/ai-notifier-swift/install.sh
```

설치 스크립트가 자동으로:
1. Swift 앱 빌드 (Universal Binary)
2. `/Applications/ai-notifier.app` 설치
3. Claude Code, Gemini CLI, Codex CLI hook 자동 설정
4. 알림 권한 설정 안내

### 수동 설치

```bash
git clone https://github.com/sokojh/ai-notifier-swift.git
cd ai-notifier-swift
./build.sh
cp -r .build/ai-notifier.app /Applications/
codesign --force --deep --sign - /Applications/ai-notifier.app
# 이후 수동으로 CLI hook 설정 필요 (아래 참조)
```

## Usage

```bash
# Test notification
echo '{}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier
```

## CLI Hook Configuration (수동 설치 시)

`install.sh` 사용 시 자동 설정됨. 수동 설치한 경우만 참조하세요.

<details>
<summary>Claude Code</summary>

`~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"}]}],
    "Notification": [{"matcher": "permission_prompt", "hooks": [{"type": "command", "command": "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"}]}]
  }
}
```
</details>

<details>
<summary>Gemini CLI</summary>

`~/.gemini/settings.json`:

```json
{
  "tools": {"enableHooks": true},
  "hooks": {
    "enabled": true,
    "AfterModel": [{"hooks": [{"name": "ai-notifier", "type": "command", "command": "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier", "timeout": 5000}]}]
  }
}
```
</details>

<details>
<summary>Codex CLI</summary>

`~/.codex/config.toml`:

```toml
[notice]
notify = ["/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"]
```
</details>

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
