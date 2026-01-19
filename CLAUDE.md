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

### ⚠️ 신규 설치 유저 관점 필수

**개발 시 항상 "처음 설치하는 유저" 관점에서 테스트할 것.**

자동 설치/설정 관련 기능은 기존 개발 환경에서 테스트하면 놓치기 쉬움:
- hook 자동 설정
- 권한 요청 다이얼로그
- 첫 실행 감지 로직
- config 파일 생성

**테스트 체크리스트:**
```bash
# 신규 설치 시뮬레이션
rm -f ~/.ai-notifier-configured
rm -rf /Applications/ai-notifier.app
# settings.json에서 ai-notifier 관련 hook 제거 후 테스트
```

**과거 버그 사례:**
- DMG 설치 후 앱 더블클릭 시 hook 자동 설정 안 됨 (첫 실행 감지 누락)
- install.sh와 앱 내 CLIHookInstaller 로직 불일치
- Codex hook 실행 시 매번 setup 실행됨 (argv 기반 hook 감지 누락)

---

### ⚠️ CLI별 Hook 호출 방식 (중요!)

**각 CLI마다 hook 호출 방식이 다름. 새 기능 추가 시 반드시 4개 CLI 모두 테스트할 것!**

| CLI | 데이터 전달 방식 | Hook 모드 감지 | 설정 파일/방식 |
|-----|-----------------|---------------|---------------|
| **Claude** | stdin (pipe) | `isatty(stdin) == 0` | `~/.claude/settings.json` |
| **Gemini** | stdin (pipe) | `isatty(stdin) == 0` | `~/.gemini/settings.json` |
| **Codex** | argv[1] (JSON) | `argv[1].hasPrefix("{")` | `~/.codex/config.toml` |
| **OpenCode** | stdin (pipe) | `cli:"opencode"` | `~/.config/opencode/plugin/ai-notifier.ts` (플러그인) |

**Hook 모드 감지 코드:**
```swift
let hasStdinData = isatty(stdin) == 0           // Claude, Gemini, OpenCode
let hasArgvData = argv[1].hasPrefix("{")        // Codex
let isHookMode = hasStdinData || hasArgvData
```

**CLI별 특이사항:**

| CLI | 특이사항 |
|-----|---------|
| **Claude** | `hook_event_name`: Stop, Notification / `notification_type`: idle_prompt, permission_prompt |
| **Gemini** | 스트리밍 응답마다 hook 호출 → 디바운싱 필수 (`finishReason == "STOP"` 체크) |
| **Codex** | TOML 설정 파일 사용, **`notify`는 루트 레벨**에 설정 (⚠️ `[notice]` 섹션 아님!) |
| **OpenCode** | **플러그인 방식** - `@opencode-ai/plugin` SDK 사용. `~/.config/opencode/plugin/`에 배치. 이벤트: `session.idle`→complete, `session.error`→error, `permission.ask`→permission. 참고: [opencode-notifier](https://github.com/mohak34/opencode-notifier) |

**테스트 명령어:**
```bash
# Claude (stdin)
echo '{"hook_event_name":"Stop","cwd":"/tmp"}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier

# Gemini (stdin)
echo '{"hook_event_name":"AfterModel","finishReason":"STOP","cwd":"/tmp"}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier

# Codex (argv)
/Applications/ai-notifier.app/Contents/MacOS/ai-notifier '{"event":"agent-turn-complete","cwd":"/tmp"}'

# OpenCode (stdin - plugin이 전송하는 형식)
echo '{"hook_event_name":"complete","cwd":"/tmp","cli":"opencode","project_name":"myproject","response_preview":"작업 완료 메시지"}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier
```

---

### ⚠️ OpenCode 플러그인 시스템

OpenCode는 `@opencode-ai/plugin` SDK 기반 플러그인 시스템을 사용합니다.

**플러그인 위치:** `~/.config/opencode/plugin/ai-notifier.ts`

**지원 이벤트:**
- `session.idle` → complete 알림
- `session.error` → error 알림
- `permission.ask` → permission 알림

**디버깅:**
```bash
# 플러그인 확인
cat ~/.config/opencode/plugin/ai-notifier.ts

# 플러그인 재설치
rm ~/.config/opencode/plugin/ai-notifier.ts
/Applications/ai-notifier.app/Contents/MacOS/ai-notifier --setup

# 캐시 삭제 (새 버전 적용 시)
rm -rf ~/.cache/opencode
```

**참고:** [opencode-notifier](https://github.com/mohak34/opencode-notifier)

---

### ⚠️ Codex config.toml 구조 (매우 중요!)

**`notify`는 반드시 루트 레벨에 위치해야 함. `[notice]` 섹션 안에 넣으면 작동 안 함!**

```toml
# ✅ 올바른 구조
model = "gpt-5.2-codex"
notify = ["/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"]  # 루트 레벨!

[projects."/path/to/project"]
trust_level = "trusted"

[notice]
hide_gpt5_1_migration_prompt = true  # 이건 in-product notice 설정

[notice.model_migrations]
"gpt-5.2" = "gpt-5.2-codex"
```

```toml
# ❌ 잘못된 구조 (작동 안 함!)
[notice]
notify = ["/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"]  # 여기 넣으면 안 됨!
```

**혼동하기 쉬운 이유:**
- `[notice]` 섹션은 "in-product notices" (경고, 마이그레이션 프롬프트 등) 설정용
- `notify`는 "external notification programs" 설정으로 완전히 다른 용도
- 이름이 비슷해서 착각하기 쉬움

**설치 코드에서 주의점:**
- `main.swift`의 `installCodexHook()`: 첫 번째 `[...]` 섹션 앞에 삽입
- `install.sh`: 동일하게 첫 번째 섹션 앞에 삽입
- 절대로 `[notice]` 섹션을 찾아서 그 안에 넣지 말 것!

**과거 버그:**
- `[notice]` 섹션 안에 `notify` 추가 → Codex 알림 작동 안 함
- `content.contains("[notice]")`가 `[notice.model_migrations]`도 매칭 → 잘못된 위치에 삽입

---

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

## 배포: Apple 공증 (Notarization)

### 개요

공증 없이 배포하면 Gatekeeper 경고 발생:
> "ai-notifier.app은(는) Apple에서 확인할 수 없기 때문에 열 수 없습니다."

### 전체 플로우

```
[앱 빌드] → [코드 서명] → [DMG 생성] → [DMG 서명] → [공증] → [스테이플링] → [배포]
```

### 사전 준비

| 항목 | 설명 |
|------|------|
| Apple Developer 계정 | 연 $99 (developer.apple.com) |
| Developer ID 인증서 | Keychain Access에서 확인 |
| App-specific password | appleid.apple.com → 보안 → 앱 암호 |
| Entitlements 파일 | Hardened Runtime 설정 |

### 크리덴셜 저장 (최초 1회)

```bash
xcrun notarytool store-credentials "AI_NOTIFIER_PROFILE" \
    --apple-id "your@email.com" \
    --team-id "XXXXXXXXXX" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

### 공증 명령어

```bash
# 1. 앱 코드 서명 (Hardened Runtime 필수)
codesign --force --options runtime \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --entitlements entitlements.plist \
    "ai-notifier.app"

# 2. DMG 생성 (create-dmg.sh가 처리)

# 3. DMG 코드 서명
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" \
    "AI-Notifier.dmg"

# 4. 공증 요청 (수분 소요)
xcrun notarytool submit "AI-Notifier.dmg" \
    --keychain-profile "AI_NOTIFIER_PROFILE" \
    --wait

# 5. 스테이플링 (공증 티켓 첨부)
xcrun stapler staple "AI-Notifier.dmg"
```

### 검증

```bash
# 스테이플링 확인
xcrun stapler validate "AI-Notifier.dmg"

# Gatekeeper 검증
spctl --assess --type open --context context:primary-signature -v "AI-Notifier.dmg"
```

### 공증 실패 시 디버깅

```bash
# 공증 로그 확인
xcrun notarytool log <submission-id> --keychain-profile "AI_NOTIFIER_PROFILE"

# 일반적인 실패 원인:
# - Hardened Runtime 미적용 (--options runtime 누락)
# - 서명되지 않은 바이너리 포함
# - 잘못된 entitlements
```

### 현재 상태

⚠️ `create-dmg.sh`에 공증 로직 미구현 - 수동으로 진행 필요

---

## 파일 구조

```
Sources/
├── main.swift                      # 진입점 (~100줄)
├── App/
│   └── AppController.swift         # 메인 비즈니스 로직
├── Core/
│   ├── Config.swift                # 상수 정의
│   ├── AppConfig.swift             # Codable 설정 모델
│   ├── NtfyConfig.swift            # ntfy 설정 싱글톤
│   └── NtfyClient.swift            # ntfy HTTP 클라이언트
├── CLI/
│   ├── CLISource.swift             # CLISource enum
│   ├── HookDataParser.swift        # 파서 프로토콜 + 팩토리
│   └── Parsers/
│       ├── ClaudeParser.swift      # Claude CLI 파서
│       ├── GeminiParser.swift      # Gemini CLI 파서
│       ├── CodexParser.swift       # Codex CLI 파서
│       └── OpenCodeParser.swift    # OpenCode CLI 파서
├── Terminal/
│   ├── TerminalType.swift          # TerminalType enum
│   ├── TerminalInfo.swift          # TerminalInfo struct
│   └── TerminalActivator.swift     # 터미널 활성화 로직
├── Notification/
│   ├── NotificationContent.swift   # 알림 내용 모델
│   └── NotificationManager.swift   # UNUserNotificationCenter 래퍼
├── Installation/
│   └── CLIHookInstaller.swift      # CLI별 hook 설치 로직
├── Setup/
│   └── SetupAppDelegate.swift      # --setup 모드 NSApplicationDelegate
└── Utilities/
    ├── DebugLogging.swift          # debugLog() 함수
    ├── TextUtils.swift             # 문자열 유틸리티
    ├── ProjectInfo.swift           # 프로젝트 정보 추출
    └── GeminiDebouncer.swift       # Gemini 디바운싱
```

---

## Claude Code 개발 워크플로우

### Slash Commands

`.claude/commands/` 디렉토리에 정의된 명령어들:

| 명령어 | 설명 | 사용법 |
|--------|------|--------|
| `/commit-push-pr` | 커밋, 푸시, PR 생성을 한 번에 | `/commit-push-pr "feat: add new feature"` |
| `/build-test` | 빌드 및 기본 테스트 실행 | `/build-test` |
| `/verify` | 4개 CLI 전체 알림 검증 | `/verify` |
| `/install` | 앱 빌드 후 /Applications에 설치 | `/install` |

### Sub-Agents

`.claude/agents/` 디렉토리에 정의된 에이전트들:

| 에이전트 | 용도 | 모델 |
|----------|------|------|
| `code-simplifier` | 코드 단순화 및 정리 | sonnet |
| `verify-app` | E2E 검증 (빌드→테스트→로그확인) | sonnet |
| `code-reviewer` | 코드 리뷰 (품질, 보안, Swift 베스트 프랙티스) | sonnet |

**사용 예시:**
```
Task tool로 code-reviewer 에이전트 호출하여 Sources/ 디렉토리 리뷰
```

### Hooks

`.claude/hooks/` 디렉토리에 정의된 훅들:

| 훅 | 타입 | 동작 |
|----|------|------|
| `format-swift.sh` | PostToolUse (Write\|Edit) | Swift 파일 자동 포맷팅 |
| `validate-swift.sh` | PreToolUse (Bash) | git commit 전 Swift 문법 검증 |
| `stop-verify.sh` | (비활성) | 개발자용 - 수동 설정 필요 |

### Verification Skill

`.claude/skills/verify-notification/SKILL.md`에 정의된 검증 피드백 루프:

**검증 프로세스:**
1. `./build.sh` 실행
2. `/tmp/ai-notifier-debug.log` 삭제
3. 4개 CLI 타입별 테스트 (Claude, Gemini, Codex, OpenCode)
4. 로그에서 "Notification sent: success" 확인

**빠른 검증:**
```bash
# 빌드
./build.sh

# Claude 테스트
echo '{"hook_event_name":"Stop","cwd":"/tmp"}' | .build/ai-notifier.app/Contents/MacOS/ai-notifier &
sleep 2 && pkill -f ai-notifier

# 로그 확인
grep "Notification sent" /tmp/ai-notifier-debug.log
```

### Permissions

`.claude/settings.json`에 정의된 권한:

**자동 허용:**
- `./build.sh` 실행
- git 명령어 (status, diff, log, add, commit, push)
- gh pr 명령어
- 파일 조작 (ls, cat, tail, find, tree 등)
- 프로세스 관리 (pkill, sleep)
- Swift 도구 (swiftc, swift-format)

### 개발 시 권장 워크플로우

1. **코드 수정** → PostToolUse 훅이 자동으로 Swift 포맷팅
2. **빌드 확인** → `/build-test` 또는 `./build.sh`
3. **검증** → `/verify` 또는 verification skill 사용
4. **커밋** → PreToolUse 훅이 Swift 문법 검증
5. **배포** → `/commit-push-pr "commit message"`

**Stop 훅 (비활성화됨):**
- 일반 사용자와의 충돌 방지를 위해 기본 비활성화
- 개발자가 필요 시 `~/.claude/settings.json`에 수동 추가 가능:
  ```json
  "Stop": [{"hooks": [{"type": "command", "command": "/path/to/ai-notifier/.claude/hooks/stop-verify.sh", "timeout": 120}]}]
  ```
