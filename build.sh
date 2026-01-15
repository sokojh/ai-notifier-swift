#!/bin/bash
# AI Notifier - Universal Binary Build Script
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="AI Notifier"
BUNDLE_ID="com.sokojh.ai-notifier"
EXECUTABLE_NAME="ai-notifier"
VERSION="1.0.0"
MIN_MACOS="11.0"

BUILD_DIR="$SCRIPT_DIR/.build"
APP_BUNDLE="$BUILD_DIR/$EXECUTABLE_NAME.app"

echo ""
echo -e "${BLUE}Building AI Notifier${NC}"
echo "========================================"
echo ""

# Check Swift compiler
if ! command -v swiftc &> /dev/null; then
    echo -e "${RED}Swift compiler not found.${NC}"
    echo "   Install Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi

SWIFT_VERSION=$(swiftc --version | head -1)
echo "Swift: $SWIFT_VERSION"

cd "$SCRIPT_DIR"

# Create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ARM64 build
echo ""
echo -e "${BLUE}[1/5] Building ARM64...${NC}"
swiftc -O \
    -target arm64-apple-macosx${MIN_MACOS} \
    -o "$BUILD_DIR/${EXECUTABLE_NAME}-arm64" \
    Sources/main.swift

echo "ARM64 build complete"

# x86_64 build
echo ""
echo -e "${BLUE}[2/5] Building x86_64...${NC}"
swiftc -O \
    -target x86_64-apple-macosx${MIN_MACOS} \
    -o "$BUILD_DIR/${EXECUTABLE_NAME}-x86_64" \
    Sources/main.swift

echo "x86_64 build complete"

# Create Universal Binary
echo ""
echo -e "${BLUE}[3/5] Creating Universal Binary...${NC}"
lipo -create \
    "$BUILD_DIR/${EXECUTABLE_NAME}-arm64" \
    "$BUILD_DIR/${EXECUTABLE_NAME}-x86_64" \
    -output "$BUILD_DIR/${EXECUTABLE_NAME}"

# Verify architectures
ARCHS=$(file "$BUILD_DIR/${EXECUTABLE_NAME}" | grep -o "arm64\|x86_64" | sort -u | tr '\n' ' ')
echo "Universal Binary created: $ARCHS"

# Create .app bundle
echo ""
echo -e "${BLUE}[4/5] Creating App Bundle...${NC}"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/${EXECUTABLE_NAME}" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/${EXECUTABLE_NAME}"

# Copy icons
if [ -d "$SCRIPT_DIR/Resources" ]; then
    cp "$SCRIPT_DIR/Resources/"*.png "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
    cp "$SCRIPT_DIR/Resources/"*.icns "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
    echo "Icon resources copied"
fi

# Generate Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

echo "Info.plist generated"

# Code sign (ad-hoc)
echo ""
echo -e "${BLUE}[5/5] Code signing...${NC}"
codesign --force --deep --sign - "$APP_BUNDLE"
echo "Ad-hoc code signing complete"

# Clean up temp files
rm -f "$BUILD_DIR/${EXECUTABLE_NAME}-arm64"
rm -f "$BUILD_DIR/${EXECUTABLE_NAME}-x86_64"
rm -f "$BUILD_DIR/${EXECUTABLE_NAME}"

# Done
echo ""
echo -e "${GREEN}========================================"
echo "Build complete!"
echo "========================================${NC}"
echo ""
echo "App bundle: $APP_BUNDLE"
echo ""
echo "Build info:"
echo "   Bundle ID: $BUNDLE_ID"
echo "   Version: $VERSION"
echo "   Min macOS: $MIN_MACOS"
echo "   Architectures: $ARCHS"
echo ""
echo "Test:"
echo "   echo '{}' | $APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
echo ""
echo "Install:"
echo "   cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
