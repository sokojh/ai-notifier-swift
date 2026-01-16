# AI Notifier

Native macOS notification app for AI coding assistants (Claude Code, Gemini CLI, Codex CLI).

Built with Swift using `UNUserNotificationCenter` for maximum compatibility with all macOS versions including Sequoia and Tahoe.

## Features

- **Native Swift**: No dependencies (no terminal-notifier, no Node.js)
- **Universal Binary**: Supports both Intel and Apple Silicon Macs
- **Modern API**: Uses `UNUserNotificationCenter` for latest macOS compatibility
- **Multi-CLI Support**: Works with Claude Code, Gemini CLI, and Codex CLI
- **CLI-specific Icons**: Shows different icons for each CLI
- **ntfy Integration** (Optional): Push notifications to any device via [ntfy.sh](https://ntfy.sh)

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

## ntfy Integration (Optional)

[ntfy](https://ntfy.sh)를 통해 모바일이나 다른 기기에서도 알림을 받을 수 있습니다.

### 설정 방법

1. 설정 파일 생성:

```bash
mkdir -p ~/.config/ai-notifier
cp config.example.json ~/.config/ai-notifier/config.json
```

2. `~/.config/ai-notifier/config.json` 수정:

```json
{
  "ntfy": {
    "enabled": true,
    "server": "https://ntfy.sh",
    "topic": "your-unique-topic-name",
    "priority": "default",
    "auth": null
  }
}
```

### 설정 옵션

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `enabled` | ntfy 활성화 여부 | `false` |
| `server` | ntfy 서버 URL | `https://ntfy.sh` |
| `topic` | 알림을 받을 토픽 이름 | (필수) |
| `priority` | 알림 우선순위 (`min`, `low`, `default`, `high`, `urgent`) | `default` |
| `auth` | 인증 정보 (선택) | `null` |

### 인증 설정 (Self-hosted ntfy)

Bearer 토큰 인증:
```json
{
  "ntfy": {
    "enabled": true,
    "server": "https://your-ntfy-server.com",
    "topic": "your-topic",
    "auth": {
      "type": "bearer",
      "token": "tk_your_token_here"
    }
  }
}
```

Basic 인증:
```json
{
  "ntfy": {
    "enabled": true,
    "server": "https://your-ntfy-server.com",
    "topic": "your-topic",
    "auth": {
      "type": "basic",
      "username": "your-username",
      "password": "your-password"
    }
  }
}
```

### 모바일 앱 설정

1. [ntfy 앱](https://ntfy.sh/#subscribe-phone) 설치 (iOS/Android)
2. 설정한 토픽 구독 (예: `your-unique-topic-name`)
3. AI 알림이 모바일에서도 수신됨

## Supported Terminals (Click-to-Focus)

알림 클릭 시 해당 터미널로 자동 이동하는 기능을 지원합니다.

| 터미널 | 탭/세션 선택 | 앱 활성화 | 비고 |
|--------|:-----------:|:--------:|------|
| **iTerm2** | ✅ | ✅ | `ITERM_SESSION_ID`로 정확한 세션 선택 |
| **Terminal.app** | ✅ | ✅ | TTY로 정확한 탭 선택 |
| **VSCode** | ⚠️ | ✅ | 폴더 창만 활성화 (내부 터미널 탭 선택 불가) |
| **Ghostty** | ❌ | ✅ | 앱만 활성화 (세션 API 미지원) |
| **Warp** | ❌ | ✅ | 앱만 활성화 (AppleScript 미지원) |

### 지원 예정 / 미지원

| 터미널 | 상태 | 비고 |
|--------|------|------|
| **Kitty** | 🔜 예정 | 원격 제어 API 있음 (`kitten @`) |
| **Alacritty** | ❌ | 원격 제어 API 없음 |
| **WezTerm** | ❌ | CLI 있지만 탭 포커스 명령 없음 |
| **Hyper** | ❌ | 제한적 AppleScript만 지원 |

> **참고**: 탭/세션 선택이 ❌인 터미널은 앱이 활성화되지만, 수동으로 올바른 탭을 선택해야 합니다.

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
