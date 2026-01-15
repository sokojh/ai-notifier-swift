#!/bin/bash
# AI Notifier - DMG 생성 스크립트
set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="AI Notifier"
DMG_NAME="AI-Notifier"
VERSION="1.0.0"

BUILD_DIR="$SCRIPT_DIR/.build"
DMG_DIR="$SCRIPT_DIR/dmg-staging"
OUTPUT_DIR="$SCRIPT_DIR/build"

echo ""
echo -e "${BLUE}📦 Creating DMG for $APP_NAME${NC}"
echo "========================================"
echo ""

# 1. 먼저 앱 빌드
if [ ! -d "$BUILD_DIR/ai-notifier.app" ]; then
    echo -e "${YELLOW}앱이 없습니다. 먼저 빌드합니다...${NC}"
    "$SCRIPT_DIR/build.sh"
fi

# 2. DMG 스테이징 디렉토리 준비
echo -e "${BLUE}[1/3] DMG 스테이징 준비...${NC}"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
mkdir -p "$OUTPUT_DIR"

# 앱 복사
cp -r "$BUILD_DIR/ai-notifier.app" "$DMG_DIR/"

# Applications 바로가기 생성
ln -s /Applications "$DMG_DIR/Applications"

# 설치 안내 파일 추가
cat > "$DMG_DIR/READ ME - Install Guide.txt" << 'EOF'
========================================
   AI Notifier - Installation Guide
========================================

   STEP 1: Drag app to Applications

        [ai-notifier.app] ---> [Applications]

   STEP 2: Double-click the app (IMPORTANT!)

        Open Applications folder
        Double-click ai-notifier.app
        Click "Allow" for notifications

   STEP 3: Done!

========================================

Supported CLI:
  - Claude Code (Anthropic)
  - Gemini CLI (Google)
  - Codex CLI (OpenAI)

Auto-configure hooks:
  Run ./install.sh from the repository

GitHub: https://github.com/sokojh/ai-notifier-swift
EOF

echo "✓ 스테이징 완료"

# 3. DMG 생성
echo ""
echo -e "${BLUE}[2/3] DMG 생성 중...${NC}"

DMG_PATH="$OUTPUT_DIR/${DMG_NAME}.dmg"
rm -f "$DMG_PATH"

# 임시 DMG 생성
TEMP_DMG="$OUTPUT_DIR/temp_${DMG_NAME}.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDRW "$TEMP_DMG"

# DMG 마운트
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$TEMP_DMG" | grep "/Volumes/" | sed 's/.*\(\/Volumes\/.*\)/\1/')
echo "   마운트됨: $MOUNT_DIR"

# Finder 설정 (아이콘 위치, 윈도우 크기 등)
echo "   Finder 설정 중..."
osascript << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 900, 450}
        set viewOptions to icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80

        -- 아이콘 위치 설정
        set position of item "ai-notifier.app" of container window to {120, 200}
        set position of item "Applications" of container window to {380, 200}
        set position of item "READ ME - Install Guide.txt" of container window to {250, 80}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# 동기화 및 언마운트
sync
hdiutil detach "$MOUNT_DIR"

# 최종 DMG 변환 (압축)
echo ""
echo -e "${BLUE}[3/3] DMG 압축 중...${NC}"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$TEMP_DMG"

# 정리
rm -rf "$DMG_DIR"

# 완료
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo -e "${GREEN}========================================"
echo "✅ DMG 생성 완료!"
echo "========================================${NC}"
echo ""
echo "파일: $DMG_PATH"
echo "크기: $DMG_SIZE"
echo ""
echo "배포 방법:"
echo "  1. GitHub Releases에 업로드"
echo "  2. 사용자는 DMG를 열고 앱을 Applications로 드래그"
echo "  3. 앱을 더블클릭하면 권한 설정 GUI가 자동 실행"
echo ""
