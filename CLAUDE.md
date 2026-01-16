# AI Notifier - Development Notes

## 아키텍처

### 알림 클릭 → 터미널 바로가기

**동작 방식:**
1. 알림 전송 후 앱이 백그라운드에서 계속 실행 (`app.setActivationPolicy(.accessory)`)
2. 알림 클릭 시 `UNUserNotificationCenterDelegate.didReceive` 콜백 호출
3. 콜백에서 `userInfo`에 저장된 터미널 정보로 `TerminalActivator.activate()` 실행

**핵심 코드:** `Sources/main.swift`
```swift
// 알림 전송 후 백그라운드 실행 유지
let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // 독에서 숨김
app.run()  // 이벤트 루프 실행
```

**이전 시도들 (실패):**
- delegate 콜백 3초 대기 후 `exit(0)` → 앱 종료되어 콜백 못 받음
- 세션 파일 저장 후 재실행 시 읽기 → setup mode와 충돌
- `SetupAppDelegate.applicationDidBecomeActive`에서 처리 → 타이밍 이슈

### Gemini CLI 디바운싱

Gemini CLI는 스트리밍 응답마다 hook을 호출하므로 디바운싱 필요.

- `finishReason == "STOP"` 체크
- 세션별 락 파일로 2초 디바운싱 (`/tmp/.gemini-notify-{sessionId}.lock`)

### ntfy 헤더 매핑

ntfy API 공식 문서 기준:
- **Tags**: 이모지 short code (`robot`, `sparkles`, `computer`)
- **Priority**: 숫자 1-5 (`min`→1, `low`→2, `default`→3, `high`→4, `urgent`→5)
- **Title**: `CLI명 - 프로젝트명 - 상태` 형식

---

## 터미널 지원 상세

### 터미널 감지 방식

| 터미널 | 환경변수 | 세션 식별자 |
|--------|----------|-------------|
| iTerm2 | `TERM_PROGRAM=iTerm.app` | `ITERM_SESSION_ID` (UUID) |
| Terminal.app | `TERM_PROGRAM=Apple_Terminal` | `TTY` (e.g., `/dev/ttys001`) |
| VSCode | `TERM_PROGRAM=vscode` | `PWD` (cwd) |
| Ghostty | `TERM_PROGRAM=ghostty` | 없음 |
| Warp | `TERM_PROGRAM=WarpTerminal` | 없음 |
| Kitty | `KITTY_WINDOW_ID` | `KITTY_WINDOW_ID` |

### 터미널별 활성화 방식

**iTerm2** - AppleScript로 UUID 매칭하여 정확한 세션 선택
```applescript
tell application "iTerm2"
    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                if unique id of s is "UUID" then
                    select t
                end if
            end repeat
        end repeat
    end repeat
    activate
end tell
```

**Terminal.app** - AppleScript로 TTY 매칭하여 탭 선택
```applescript
tell application "Terminal"
    repeat with w in windows
        repeat with t in tabs of w
            if tty of t is "/dev/ttys001" then
                set selected tab of w to t
            end if
        end repeat
    end repeat
    activate
end tell
```

**VSCode** - `code <cwd>` CLI 실행 후 AppleScript activate
- 주의: Electron 앱 실행으로 약간 느림
- 내부 터미널 탭 선택 불가 (폴더 창만 활성화)

**Kitty** - `kitten @ focus-window` 원격 제어
```bash
kitten @ focus-window --match id:$KITTY_WINDOW_ID
```
- **필수 설정**: `~/.config/kitty/kitty.conf`에 `allow_remote_control yes`
- 원격 제어 실패 시 AppleScript fallback

**Ghostty, Warp** - AppleScript activate만 (탭 선택 불가)
- 세션 식별 API 미지원
- 앱만 활성화되고 사용자가 수동으로 탭 선택 필요

---

## 주의사항

### VSCode fallback 버그 (수정됨)

**문제**: Unknown 터미널(Ghostty 등)에서 cwd만 있으면 VSCode로 fallback되던 버그
- 증상: Ghostty에서 알림 클릭 시 VSCode가 열림

**해결**: Unknown 터미널은 VSCode fallback 제거, 앱 활성화만 시도
```swift
case .unknown:
    if info.sessionId != nil {
        activateITerm2(sessionId: info.sessionId)
    } else if info.tty != nil {
        activateTerminalApp(tty: info.tty)
    }
    // VSCode fallback 제거
```

### Kitty 원격 제어 설정

Kitty는 기본적으로 원격 제어가 비활성화되어 있음.

```bash
# ~/.config/kitty/kitty.conf
allow_remote_control yes
```

설정하지 않으면 `kitten @ focus-window` 실패 → AppleScript fallback (앱만 활성화)

---

## 디버깅

**로그 파일:** `/tmp/ai-notifier-debug.log`

```bash
# 실시간 로그 확인
tail -f /tmp/ai-notifier-debug.log

# 실행 중인 프로세스 확인
ps aux | grep ai-notifier

# 프로세스 종료
pkill -f "ai-notifier"
```

## 테스트

```bash
# 알림 테스트 (터미널 타입별)
echo '{"hook_event_name":"Stop","cwd":"/tmp/test"}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier

# ntfy 테스트 (config 설정 필요)
echo '{"hook_event_name":"Stop"}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier

# 디버그 로그 확인
DEBUG=1 echo '{}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier
```

---

## 파일 구조

```
Sources/main.swift          # 메인 앱 코드
├── TerminalType           # 터미널 타입 enum (iTerm2, VSCode, Kitty 등)
├── TerminalInfo           # 터미널 정보 구조체 (sessionId, cwd, tty 등)
├── TerminalActivator      # 터미널 활성화 로직
├── NotificationManager    # UNUserNotificationCenter 래퍼
└── NtfyClient            # ntfy HTTP 클라이언트
```
