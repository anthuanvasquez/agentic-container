#!/usr/bin/env bash

set -euo pipefail

echo "=== Devcontainer health check ==="

STATUS_FILE="$HOME/.agents/bootstrap-health.status"
SKILLS_DIR="$HOME/.agents/skills"

failures=0

check_command() {
    local command_name="$1"
    if command -v "$command_name" >/dev/null 2>&1; then
        echo "✅ Command available: $command_name"
    else
        echo "❌ Command missing: $command_name"
        failures=$((failures + 1))
    fi
}

check_directory() {
    local directory_path="$1"
    if [ -d "$directory_path" ]; then
        echo "✅ Directory available: $directory_path"
    else
        echo "❌ Directory missing: $directory_path"
        failures=$((failures + 1))
    fi
}

echo "Checking required CLIs..."
check_command npm
check_command pi
check_command copilot
check_command gemini

echo ""
echo "Checking expected directories..."
check_directory "$HOME/.pi"
check_directory "$HOME/.copilot"
check_directory "$HOME/.gemini"
check_directory "$SKILLS_DIR"

echo ""
if [ "$failures" -eq 0 ]; then
    printf '[%s] OK\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$STATUS_FILE"
    echo "✅ Health check passed"
    echo "Status file: $STATUS_FILE"
    exit 0
fi

printf '[%s] FAIL (%s issues)\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$failures" > "$STATUS_FILE"
echo "❌ Health check failed with $failures issue(s)"
echo "Status file: $STATUS_FILE"
exit 1
