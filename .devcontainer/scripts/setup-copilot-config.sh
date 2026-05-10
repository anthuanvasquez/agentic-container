#!/bin/bash
set -euo pipefail

COPILOT_HOME="/home/node/.copilot"
SETTINGS_TEMPLATE="/usr/local/share/copilot-defaults/copilot-settings.template.json"

echo "Initializing Copilot configuration..."

# Create .copilot directory if it doesn't exist
if [ ! -d "$COPILOT_HOME" ]; then
    echo "Creating $COPILOT_HOME directory..."
    mkdir -p "$COPILOT_HOME"
    chown -R node:node "$COPILOT_HOME"
fi

# Copy settings.json template if it doesn't exist
if [ ! -f "$COPILOT_HOME/settings.json" ]; then
    if [ -f "$SETTINGS_TEMPLATE" ]; then
        echo "Copying Copilot settings from template..."
        bash -c "cat '$SETTINGS_TEMPLATE' > '$COPILOT_HOME/settings.json'"
        chown -R node:node "$COPILOT_HOME/settings.json"
        ls -lah "$COPILOT_HOME/settings.json"
        echo "✓ Environment variables configured"
    fi
else
    echo "Settings already exist, preserving user settings"
fi

echo "Copilot configuration complete"
