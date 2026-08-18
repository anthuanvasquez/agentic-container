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
check_command pnpm
check_command gh
check_command copilot

# Optional firewall verification
if [[ "${FIREWALL_ENABLED:-false}" == "true" ]]; then
    echo ""
    echo "Verifying firewall..."
    if curl -fsSL --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
        echo "✅ GitHub API reachable through firewall"
    else
        echo "❌ GitHub API unreachable through firewall"
        failures=$((failures + 1))
    fi

    if curl -fsSL --connect-timeout 5 https://example.com >/dev/null 2>&1; then
        echo "❌ example.com should be blocked by firewall"
        failures=$((failures + 1))
    else
        echo "✅ example.com blocked by firewall"
    fi
fi

echo ""
if [ "$failures" -eq 0 ]; then
    printf '[%s] OK\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$STATUS_FILE"
    echo "✅ Health check passed"
    exit 0
fi

printf '[%s] FAIL (%s issues)\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$failures" > "$STATUS_FILE"
echo "❌ Health check failed with $failures issue(s)"
exit 1
