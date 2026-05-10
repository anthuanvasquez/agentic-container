#!/usr/bin/env bash
#
# Pi Configuration Initialization Script
#
# Purpose: Initialize Pi configuration for devcontainer environment
# This script runs during container creation (postCreateCommand) to set up
# Pi's configuration directory and provide default settings.
#
# Pi is provider-agnostic and supports:
# - Anthropic
# - OpenAI
# - Google Gemini
# - GitHub Copilot
# - Local models
#
# Users should configure their preferred provider via:
# - Environment variables (ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY, etc.)
#
# SEE: https://pi.dev/docs/latest/providers#api-keys

set -e

echo "🔧 Initializing Pi configuration..."

# Ensure Pi config directory exists
PI_DIR="/home/node/.pi"
if [ ! -d "$PI_DIR" ]; then
    echo "📁 Creating Pi config directory: $PI_DIR"
    mkdir -p "$PI_DIR"
    chown -R node:node "$PI_DIR"
fi

echo "✅ Pi configuration initialized"
echo ""
echo "📝 To configure Pi, set your preferred AI provider:"
echo ""
echo "   Option 1: Anthropic"
echo "   export ANTHROPIC_API_KEY=your_api_key"
echo ""
echo "   Option 2: OpenAI"
echo "   export OPENAI_API_KEY=your_api_key"
echo ""
echo "   Option 3: Google Gemini"
echo "   export GEMINI_API_KEY=your_api_key"
echo ""
echo "   Use /login in interactive mode, then select a provider:"
echo "     ChatGPT Plus/Pro (Codex)"
echo "     Claude Pro/Max"
echo "     GitHub Copilot"
echo ""
