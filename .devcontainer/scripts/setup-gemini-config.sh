#!/bin/bash
set -euo pipefail

GEMINI_HOME="/home/node/.gemini"
SETTINGS_TEMPLATE="/usr/local/share/gemini-defaults/gemini-settings.template.json"

echo "Initializing Gemini configuration..."

# Create .gemini directory if it doesn't exist
if [ ! -d "$GEMINI_HOME" ]; then
    echo "Creating $GEMINI_HOME directory..."
    mkdir -p "$GEMINI_HOME"
    chown -R node:node "$GEMINI_HOME"
fi

# Copy settings.json template if it doesn't exist
if [ ! -f "$GEMINI_HOME/settings.json" ]; then
    if [ -f "$SETTINGS_TEMPLATE" ]; then
        echo "Copying Gemini settings from template..."
        bash -c "cat '$SETTINGS_TEMPLATE' > '$GEMINI_HOME/settings.json'"
        chown -R node:node "$GEMINI_HOME/settings.json"
        ls -lah "$GEMINI_HOME/settings.json"
        echo "✓ Environment variables configured"
    fi
else
    echo "Settings already exist, preserving user settings"
fi

echo "Gemini configuration complete"
