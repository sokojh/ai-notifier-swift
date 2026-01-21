#!/bin/bash
# AI Notifier - Apple 공증 스크립트
set -e

cd "$(dirname "$0")"

echo "=== 1. DMG 생성 ==="
rm -rf dmg-staging build 2>/dev/null || true
mkdir -p build dmg-staging
cp -r .build/ai-notifier.app dmg-staging/
ln -s /Applications dmg-staging/Applications
hdiutil create -volname "AINotifier" -srcfolder dmg-staging -ov -format UDZO build/AI-Notifier.dmg

echo "=== 2. DMG 서명 ==="
codesign --force --sign "Developer ID Application: Jiho Kim (T4BG6AUM72)" build/AI-Notifier.dmg

echo "=== 3. 공증 요청 (수분 소요) ==="
xcrun notarytool submit build/AI-Notifier.dmg --keychain-profile "ai-notifier" --wait

echo "=== 4. 스테이플링 ==="
xcrun stapler staple build/AI-Notifier.dmg

echo "=== 5. 릴리즈 DMG 교체 ==="
gh release upload v1.0.4 build/AI-Notifier.dmg --clobber

echo ""
echo "✅ 완료! https://github.com/sokojh/ai-notifier-swift/releases/tag/v1.0.4"
