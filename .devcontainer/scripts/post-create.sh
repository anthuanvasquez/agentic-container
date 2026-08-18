#!/usr/bin/env bash

set -euo pipefail

echo "=== Post-create bootstrap ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$HOME/.agents/logs"
LOG_FILE="$LOG_DIR/post-create.log"

mkdir -p "$LOG_DIR"

run_step() {
    local step_name="$1"
    shift

    echo ""
    echo "--- $step_name ---"
    "$@" 2>&1 | tee -a "$LOG_FILE"
}

echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Starting post-create bootstrap" | tee "$LOG_FILE"

run_step "Install global AI CLIs" npm install -g npm@latest @earendil-works/pi-coding-agent @github/copilot @google/gemini-cli
run_step "Run bootstrap health check" bash "$REPO_ROOT/.devcontainer/scripts/health-check.sh"

echo ""
echo "✅ Post-create bootstrap complete"
echo "Log file: $LOG_FILE"
