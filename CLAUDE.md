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
# 알림 테스트
echo '{"hook_event_name":"Stop","cwd":"/tmp/test"}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier

# ntfy 테스트 (config 설정 필요)
echo '{"hook_event_name":"Stop"}' | /Applications/ai-notifier.app/Contents/MacOS/ai-notifier
```
