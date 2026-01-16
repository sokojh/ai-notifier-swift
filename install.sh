#!/bin/bash
# AI Notifier - 자동 설치 스크립트
# Claude Code, Gemini CLI, Codex CLI 지원
set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${BLUE}🔔 AI Notifier 설치${NC}"
echo "========================================"
echo ""
echo "지원 CLI:"
echo "  • Claude Code (Anthropic)"
echo "  • Codex CLI (OpenAI)"
echo "  • Gemini CLI (Google)"
echo ""

# ===========================================
# [1/4] 시스템 요구사항 확인
# ===========================================
echo -e "${BLUE}📦 [1/4] 시스템 요구사항 확인 중...${NC}"

# macOS 확인
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ 이 스크립트는 macOS에서만 지원됩니다.${NC}"
    exit 1
fi
echo "✓ macOS 확인됨"

# Swift 컴파일러 확인
if ! command -v swiftc &> /dev/null; then
    echo ""
    echo -e "${YELLOW}📦 Xcode Command Line Tools 설치 중...${NC}"
    xcode-select --install 2>/dev/null || true
    echo ""
    echo "   설치 팝업이 뜨면 '설치'를 클릭하세요."
    echo "   설치가 완료되면 이 스크립트를 다시 실행해주세요."
    exit 1
fi
SWIFT_VERSION=$(swiftc --version 2>&1 | head -1 | grep -o "Swift version [0-9.]*" || echo "Swift")
echo "✓ $SWIFT_VERSION"

# ===========================================
# [2/4] Swift 앱 빌드 및 설치
# ===========================================
echo ""
echo -e "${BLUE}🔨 [2/4] Swift 앱 빌드 중...${NC}"

APP_NAME="ai-notifier"
MIN_MACOS="11.0"
BUILD_DIR="$SCRIPT_DIR/.build"

cd "$SCRIPT_DIR"

# 빌드 디렉토리 생성
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ARM64 빌드
echo "   ARM64 빌드 중..."
swiftc -O -target arm64-apple-macosx${MIN_MACOS} -o "$BUILD_DIR/${APP_NAME}-arm64" Sources/main.swift 2>/dev/null

# x86_64 빌드
echo "   x86_64 빌드 중..."
swiftc -O -target x86_64-apple-macosx${MIN_MACOS} -o "$BUILD_DIR/${APP_NAME}-x86_64" Sources/main.swift 2>/dev/null

# Universal Binary 생성
echo "   Universal Binary 생성 중..."
lipo -create "$BUILD_DIR/${APP_NAME}-arm64" "$BUILD_DIR/${APP_NAME}-x86_64" -output "$BUILD_DIR/${APP_NAME}"
rm -f "$BUILD_DIR/${APP_NAME}-arm64" "$BUILD_DIR/${APP_NAME}-x86_64"

# .app 번들 생성
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/${APP_NAME}" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
rm -f "$BUILD_DIR/${APP_NAME}"

# 아이콘 복사
if [ -d "$SCRIPT_DIR/Resources" ]; then
    cp "$SCRIPT_DIR/Resources/"*.png "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
fi

# Info.plist 생성
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.sokojh.ai-notifier</string>
    <key>CFBundleName</key>
    <string>AI Notifier</string>
    <key>CFBundleDisplayName</key>
    <string>AI Notifier</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# /Applications에 설치
echo "   앱 설치 중..."
INSTALLED_APP="/Applications/${APP_NAME}.app"
rm -rf "$INSTALLED_APP"
cp -r "$APP_BUNDLE" "$INSTALLED_APP"
codesign --force --deep --sign - "$INSTALLED_APP" 2>/dev/null

NOTIFIER_PATH="$INSTALLED_APP/Contents/MacOS/${APP_NAME}"
echo "✓ 앱 설치 완료"

# ===========================================
# [3/4] CLI Hook 설정
# ===========================================
echo ""
echo -e "${BLUE}⚙️  [3/4] CLI Hook 설정 중...${NC}"

# Claude Code 설정
if [ -d "$HOME/.claude" ]; then
    python3 << PYTHON
import json
from pathlib import Path

settings_path = Path.home() / ".claude" / "settings.json"
settings = {}

if settings_path.exists():
    try:
        settings = json.load(open(settings_path))
    except:
        pass

notifier_path = "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"
hook_cmd = {"type": "command", "command": notifier_path}

if "hooks" not in settings:
    settings["hooks"] = {}

# 기존 ai-notify 관련 hook 제거 후 새로 추가
stop_hooks = [h for h in settings["hooks"].get("Stop", [])
              if "ai-notify" not in str(h) and "ai-notifier" not in str(h)]
stop_hooks.append({"hooks": [hook_cmd]})
settings["hooks"]["Stop"] = stop_hooks

# Notification hooks - permission_prompt만 설정
notification_hooks = [
    h for h in settings["hooks"].get("Notification", [])
    if h.get("matcher") not in ("idle_prompt", "permission_prompt")
       and "ai-notify" not in str(h) and "ai-notifier" not in str(h)
]
notification_hooks.append({"matcher": "permission_prompt", "hooks": [hook_cmd]})
settings["hooks"]["Notification"] = notification_hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print("   ✓ Claude Code")
PYTHON
else
    echo "   - Claude Code (미설치)"
fi

# Gemini CLI 설정
if command -v gemini &> /dev/null || [ -d "$HOME/.gemini" ]; then
    mkdir -p "$HOME/.gemini"

    python3 << PYTHON
import json
from pathlib import Path

settings_path = Path.home() / ".gemini" / "settings.json"
settings = {}

if settings_path.exists():
    try:
        settings = json.load(open(settings_path))
    except:
        pass

notifier_path = "/Applications/ai-notifier.app/Contents/MacOS/ai-notifier"

if "tools" not in settings:
    settings["tools"] = {}
settings["tools"]["enableHooks"] = True

if "hooks" not in settings:
    settings["hooks"] = {}
settings["hooks"]["enabled"] = True

hook_config = {
    "name": "ai-notifier",
    "type": "command",
    "command": notifier_path,
    "timeout": 5000
}

# 기존 ai-notify 관련 hook 제거
for hook_type in ["AfterModel", "Notification"]:
    if hook_type in settings["hooks"]:
        settings["hooks"][hook_type] = [
            h for h in settings["hooks"][hook_type]
            if "ai-notify" not in str(h) and "ai-notifier" not in str(h)
        ]

if "AfterModel" not in settings["hooks"]:
    settings["hooks"]["AfterModel"] = []
settings["hooks"]["AfterModel"].append({"hooks": [hook_config]})

if "Notification" not in settings["hooks"]:
    settings["hooks"]["Notification"] = []
settings["hooks"]["Notification"].append({"hooks": [hook_config]})

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print("   ✓ Gemini CLI")
PYTHON
else
    echo "   - Gemini CLI (미설치)"
fi

# Codex CLI 설정
CODEX_CONFIG="$HOME/.codex/config.toml"
if command -v codex &> /dev/null || [ -f "$CODEX_CONFIG" ]; then
    mkdir -p "$HOME/.codex"

    # 기존 ai-notifier 관련 줄 제거
    if [ -f "$CODEX_CONFIG" ]; then
        grep -v "ai-notify\|ai-notifier" "$CODEX_CONFIG" > "${CODEX_CONFIG}.tmp" 2>/dev/null || touch "${CODEX_CONFIG}.tmp"
        mv "${CODEX_CONFIG}.tmp" "$CODEX_CONFIG"
    fi

    NOTIFY_LINE="notify = [\"$NOTIFIER_PATH\"]"

    if ! grep -q "^\[notice\]$" "$CODEX_CONFIG" 2>/dev/null; then
        # [notice] 섹션이 없으면 파일 앞에 추가
        TEMP_FILE=$(mktemp)
        cat > "$TEMP_FILE" << EOF
# AI Notifier
[notice]
$NOTIFY_LINE

EOF
        if [ -f "$CODEX_CONFIG" ]; then
            cat "$CODEX_CONFIG" >> "$TEMP_FILE"
        fi
        mv "$TEMP_FILE" "$CODEX_CONFIG"
    else
        # [notice] 섹션이 있으면 그 다음 줄에 notify 추가
        TEMP_FILE=$(mktemp)
        while IFS= read -r line || [ -n "$line" ]; do
            echo "$line" >> "$TEMP_FILE"
            if [ "$line" = "[notice]" ]; then
                echo "$NOTIFY_LINE" >> "$TEMP_FILE"
            fi
        done < "$CODEX_CONFIG"
        mv "$TEMP_FILE" "$CODEX_CONFIG"
    fi
    echo "   ✓ Codex CLI"
else
    echo "   - Codex CLI (미설치)"
fi

# ===========================================
# [4/4] 알림 권한 설정
# ===========================================
echo ""
echo -e "${BLUE}🔔 [4/4] 알림 권한 설정 중...${NC}"
echo "   권한 요청 다이얼로그를 표시합니다..."
echo ""

# GUI 모드로 권한 요청 다이얼로그 표시
"$NOTIFIER_PATH" --setup 2>/dev/null
SETUP_RESULT=$?

if [ $SETUP_RESULT -eq 0 ]; then
    echo -e "   ${GREEN}✓ 알림 권한이 설정되었습니다!${NC}"
    echo ""
    echo -e "${YELLOW}💡 알림이 쌓이게 하려면:${NC}"
    echo "   시스템 설정 → 알림 → AI Notifier → 알림 스타일: '알림' 선택"
else
    echo -e "   ${YELLOW}⚠️  알림 권한이 설정되지 않았습니다.${NC}"
    echo "   나중에 다음 명령으로 다시 설정할 수 있습니다:"
    echo "   $NOTIFIER_PATH --setup"
fi

# ===========================================
# 설치 완료
# ===========================================
echo ""
echo -e "${GREEN}========================================"
echo "✅ 설치가 완료되었습니다!"
echo "========================================${NC}"
echo ""
echo "📌 알림 기능:"
echo "   • 응답 완료 시 → CLI 이름 + 프로젝트명 + 응답 미리보기"
echo "   • 권한 요청 시 → CLI 이름 + 프로젝트명 + 요청 내용"
echo ""
echo -e "${GREEN}🎉 새 CLI 세션을 시작하면 알림이 작동합니다!${NC}"
echo ""
