---
allowed-tools: Bash(git:*), Bash(gh:*)
argument-hint: [commit-message]
description: Commit changes, push to remote, and create a PR
---

## Context

- Current git status: !`git status --short`
- Current branch: !`git branch --show-current`
- Staged changes: !`git diff --cached --stat`
- Recent commits: !`git log --oneline -5`

## Instructions

Based on the current changes:

1. **Commit**: Create a clear commit message
   - If `$ARGUMENTS` is provided, use it as the commit message
   - Otherwise, generate a descriptive message based on the diff
   - Use conventional commits format (feat, fix, docs, refactor, etc.)

2. **Push**: Push to the current branch
   - Set upstream if needed

3. **PR**: Create a pull request
   - Use a clear title summarizing the changes
   - Add description with:
     - Summary of changes
     - Testing done
     - Any breaking changes

Commit message should end with:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```
