#!/usr/bin/env bash
# Compatibility entry point for existing Gemini-only shortcuts.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_COMMIT_PROVIDER=gemini
exec bash "$SCRIPT_DIR/ai-commit.sh" "$@"
