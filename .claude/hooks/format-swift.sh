#!/bin/bash
# PostToolUse hook: Format Swift files after edit

set -e

# Read hook input from stdin
INPUT=$(cat)

# Extract file path from the tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only process Swift files
if [[ "$FILE_PATH" != *.swift ]]; then
    exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Check if swift-format is available
if command -v swift-format &> /dev/null; then
    swift-format -i "$FILE_PATH" 2>/dev/null || true
fi

# Alternative: Check if swiftformat is available (from CocoaPods)
if command -v swiftformat &> /dev/null; then
    swiftformat "$FILE_PATH" --quiet 2>/dev/null || true
fi

exit 0
