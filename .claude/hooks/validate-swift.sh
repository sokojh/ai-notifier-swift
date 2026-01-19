#!/bin/bash
# PreToolUse hook: Validate Swift syntax before committing

set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check for git commit commands
if [[ "$COMMAND" != *"git commit"* ]]; then
    exit 0
fi

# Find all Swift files
SWIFT_FILES=$(find Sources -name "*.swift" 2>/dev/null || echo "")

if [[ -z "$SWIFT_FILES" ]]; then
    exit 0
fi

# Quick syntax check using swiftc -parse
for file in $SWIFT_FILES; do
    if ! swiftc -parse "$file" 2>/dev/null; then
        echo "Swift syntax error in $file" >&2
        exit 2  # Block the commit
    fi
done

exit 0
