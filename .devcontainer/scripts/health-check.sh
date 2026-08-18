#!/usr/bin/env bash
set -euo pipefail

echo "=== Agentic Container health check ==="

STATUS_FILE="$HOME/.agents/bootstrap-health.status"
mkdir -p "$(dirname "$STATUS_FILE")"

failures=0

check_command() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✅ Command available: $cmd"
    else
        echo "❌ Command missing: $cmd"
        failures=$((failures + 1))
    fi
}

echo "Checking required CLIs..."
check_command npm
check_command gh
check_command copilot

echo ""
if [ "$failures" -eq 0 ]; then
    printf '[%s] OK\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$STATUS_FILE"
    echo "✅ Health check passed"
    exit 0
fi

printf '[%s] FAIL (%s issues)\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$failures" > "$STATUS_FILE"
echo "❌ Health check failed with $failures issue(s)"
exit 1
