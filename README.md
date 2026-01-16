# AI Notifier

AI 코딩 어시스턴트(Claude Code, Gemini CLI, Codex CLI, OpenCode)를 위한 네이티브 macOS 알림 앱

Swift로 작성되어 `UNUserNotificationCenter` API를 사용하며, macOS Sequoia와 Tahoe를 포함한 모든 최신 macOS 버전과 완벽 호환됩니다.

## 주요 기능

**네이티브 Swift 앱**
- 외부 의존성 없음 (terminal-notifier, Node.js 불필요)
- Universal Binary (Intel + Apple Silicon 지원)
- 최신 macOS 알림 API 사용

**Multi-CLI 지원**
- Claude Code, Gemini CLI, Codex CLI 자동 감지
- CLI별 아이콘 표시
- 응답 완료, 권한 요청, 입력 대기 등 상태별 알림

**Click-to-Focus**
- 알림 클릭 시 해당 터미널로 자동 이동
- iTerm2, Terminal.app, VSCode, Kitty 등 주요 터미널 지원
- 정확한 탭/세션 선택 (터미널별 지원 수준 상이)

**ntfy 연동** (선택)
- [ntfy.sh](https://ntfy.sh)를 통한 모바일 푸시 알림
- Self-hosted ntfy 서버 지원 (Bearer/Basic 인증)

---

## 설치

### 원라이너 설치 (권장)

```bash
rm -rf /tmp/ai-notifier-swift && \
git clone https://github.com/sokojh/ai-notifier-swift.git /tmp/ai-notifier-swift && \
/tmp/ai-notifier-swift/install.sh
```

설치 스크립트가 자동으로:
1. Swift 앱 빌드 (Universal Binary)
2. `/Applications/ai-notifier.app` 설치
3. Claude Code, Gemini CLI, Codex CLI, OpenCode 훅 자동 설정
4. 알림 권한 요청

### 수동 설치

```bash
git clone https://github.com/sokojh/ai-notifier-swift.git
cd ai-notifier-swift
./build.sh
cp -r .build/ai-notifier.app /Applications/
codesign --force --deep --sign - /Applications/ai-notifier.app

# 설정 마법사 실행 (권한 요청 + 훅 설치)
/Applications/ai-notifier.app/Contents/MacOS/ai-notifier --setup
```

---

## 알림 권한 설정

설치 후 **시스템 설정 → 알림 → AI Notifier**에서:

1. **알림 허용** 활성화
2. 알림 스타일을 **알림**(Alerts)으로 설정 (배너보다 권장)

---

## 터미널 지원

### 완벽 지원 (탭/세션 선택 가능)

| 터미널 | 방식 | 비고 |
|--------|------|------|
| **iTerm2** | `ITERM_SESSION_ID` (UUID) | 정확한 세션으로 이동 |
| **Terminal.app** | TTY 매칭 | 정확한 탭으로 이동 |

### 부분 지원 (창 활성화)

| 터미널 | 방식 | 비고 |
|--------|------|------|
| **VSCode** | `code` CLI | 폴더 창 활성화 (내부 터미널 탭 선택 불가) |
| **Kitty** | `kitten @` | 창 ID로 포커스 → **원격 제어 설정 필요** |
| **Ghostty** | AppleScript | 앱만 활성화 (세션 API 미지원) |
| **Warp** | AppleScript | 앱만 활성화 (탭 선택 불가) |

### 추가 설정이 필요한 터미널

**Kitty**: `~/.config/kitty/kitty.conf`에 추가:
```
allow_remote_control yes
```

---

## ntfy 연동 (선택)

모바일이나 다른 기기에서도 알림을 받을 수 있습니다.

### 설정

```bash
mkdir -p ~/.config/ai-notifier
cat > ~/.config/ai-notifier/config.json << 'EOF'
{
  "ntfy": {
    "enabled": true,
    "server": "https://ntfy.sh",
    "topic": "your-unique-topic-name",
    "priority": "default"
  }
}
EOF
```

### 설정 옵션

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `enabled` | ntfy 활성화 여부 | `false` |
| `server` | ntfy 서버 URL | `https://ntfy.sh` |
| `topic` | 알림을 받을 토픽 이름 (필수) | - |
| `priority` | 우선순위 (`min`, `low`, `default`, `high`, `urgent`) | `default` |
| `auth` | 인증 정보 (선택) | `null` |

### Self-hosted ntfy 인증

**Bearer 토큰:**
```json
{
  "ntfy": {
    "enabled": true,
    "server": "https://your-ntfy-server.com",
    "topic": "your-topic",
    "auth": { "type": "bearer", "token": "tk_your_token" }
  }
}
```

**Basic 인증:**
```json
{
  "ntfy": {
    "enabled": true,
    "server": "https://your-ntfy-server.com",
    "topic": "your-topic",
    "auth": { "type": "basic", "username": "user", "password": "pass" }
  }
}
```

### 모바일 앱

1. [ntfy 앱](https://ntfy.sh/#subscribe-phone) 설치 (iOS/Android)
2. 설정한 토픽 구독
3. AI 응답 완료 시 모바일에서도 알림 수신

---

## CLI 훅 설정 (수동)

`install.sh` 또는 `--setup` 사용 시 자동 설정됩니다. 수동 설정이 필요한 경우:

<details>
<summary><strong>Claude Code</strong></summary>

`~/.claude/settings.json`:
```json
{
  "hooks": {
    "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"}]}],
    "Notification": [{"matcher": "", "hooks": [{"type": "command", "command": "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"}]}]
  }
}
```
</details>

<details>
<summary><strong>Gemini CLI</strong></summary>

`~/.gemini/settings.json`:
```json
{
  "hooks": {
    "enabled": true,
    "AfterModel": [{"hooks": [{"name": "ai-notifier", "type": "command", "command": "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier", "timeout": 5000}]}],
    "Notification": [{"hooks": [{"name": "ai-notifier", "type": "command", "command": "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier", "timeout": 5000}]}]
  }
}
```
</details>

<details>
<summary><strong>Codex CLI</strong></summary>

`~/.codex/config.toml`:
```toml
[notice]
notify = ["/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"]
```
</details>

<details>
<summary><strong>OpenCode</strong></summary>

OpenCode는 플러그인 방식으로 동작합니다. `--setup` 실행 시 자동 설치됩니다.

`~/.opencode/plugin/ai-notifier.ts`:
```typescript
import { defineHook } from "opencode";
import { execSync } from "child_process";
import { basename } from "path";

function notify(eventType: string, responsePreview?: string) {
  const cwd = process.cwd();
  const data = JSON.stringify({
    hook_event_name: eventType,
    cwd: cwd,
    cli: "opencode",
    project_name: basename(cwd),
    response_preview: responsePreview || ""
  });
  execSync(`echo '${data.replace(/'/g, "'\\''")}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier`, {
    stdio: 'ignore',
    timeout: 5000
  });
}

export default defineHook({
  name: "ai-notifier",
  events: {
    "session.idle": async (ctx) => { notify("complete"); },
    "session.error": async (ctx) => { notify("error"); }
  },
  "permission.ask": async () => { notify("permission"); }
});
```

**지원 이벤트:**
- `session.idle` → 응답 완료 알림
- `session.error` → 오류 발생 알림
- `permission.ask` → 권한 요청 알림
</details>

---

## 동작 방식

### 알림 흐름

```
CLI 응답 완료 → Hook 실행 → ai-notifier 호출 →
  ├─ macOS 알림 표시
  └─ ntfy 전송 (설정 시)
```

### 알림 클릭 흐름

```
알림 클릭 → ai-notifier 재실행 →
  터미널 정보 복원 → 해당 터미널/세션 활성화
```

### Gemini CLI 디바운싱

Gemini CLI는 스트리밍 응답마다 훅을 호출하므로 자동 디바운싱:
- `finishReason == "STOP"` 인 경우에만 알림
- 세션별 2초 디바운싱으로 중복 알림 방지

---

## 테스트

```bash
# 기본 알림 테스트
echo '{"hook_event_name":"Stop","cwd":"/tmp/test"}' | \
  /Applications/ai-notifier.app/Contents/MacOS/ai-notifier

# 디버그 로그 확인
tail -f /tmp/ai-notifier-debug.log
```

---

## 기술 사양

| 항목 | 값 |
|------|-----|
| 언어 | Swift 5+ |
| 최소 macOS | 11.0 (Big Sur) |
| 알림 API | `UNUserNotificationCenter` |
| 아키텍처 | Universal Binary (arm64 + x86_64) |
| 코드 서명 | Ad-hoc (로컬 빌드) |
| Bundle ID | `com.sokojh.ai-notifier` |

---

## 왜 네이티브 Swift인가?

| 도구 | 문제점 |
|------|--------|
| terminal-notifier | deprecated `NSUserNotification` API, 최신 macOS 미지원 |
| alerter | 동일한 API 문제 |
| osascript | Sequoia에서 터미널 `display notification` 미작동 |

→ 최신 `UNUserNotificationCenter` API를 사용하는 네이티브 앱으로 해결

---

## 라이선스

MIT License
