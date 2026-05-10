#!/bin/bash
#
# Setup Anthuan's Skills
#
# Clones and installs custom agent skills from the personal repository.
#

set -euo pipefail

SKILLS_REPO="https://github.com/anthuanvasquez/skills"
SKILLS_DIR="/home/node/.agents/skills"

echo "=== Installing Custom Skills ==="

# Ensure the parent directory exists
mkdir -p "$(dirname "$SKILLS_DIR")"

if [ ! -d "$SKILLS_DIR" ]; then
    echo "Cloning skills repository from $SKILLS_REPO..."
    git clone "$SKILLS_REPO" "$SKILLS_DIR"
else
    echo "Skills repository already exists, pulling latest changes..."
    cd "$SKILLS_DIR"
    git pull
fi

# Run the installer if it exists
if [ -f "$SKILLS_DIR/install.sh" ]; then
    echo "Running skills installer..."
    cd "$SKILLS_DIR"
    bash ./install.sh
else
    echo "⚠️  Warning: install.sh not found in $SKILLS_DIR"
fi

# Ensure correct permissions
chown -R node:node "/home/node/.agents"

echo "✅ Skills setup complete"
