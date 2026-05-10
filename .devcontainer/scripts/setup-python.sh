#!/bin/bash
set -e

echo "=== Python 3.14 Setup ==="

# Install Python 3.14 via uv
echo "Installing Python 3.14..."
/home/node/.local/bin/uv python install 3.14

# Pin Python 3.14 for the project
echo "Pinning Python 3.14..."
cd /workspaces/$localWorkspaceFolderBasename
/home/node/.local/bin/uv python pin 3.14

# Get Python 3.14 path
PYTHON314_PATH=$(/home/node/.local/bin/uv python find 3.14)
echo "Python 3.14 installed at: $PYTHON314_PATH"

# Create system symlink and update alternatives (requires sudo)
sudo ln -sf "$PYTHON314_PATH" /usr/local/bin/python3.14
sudo update-alternatives --install /usr/bin/python python /usr/local/bin/python3.14 100
sudo update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.14 100

# Verify installation
echo "Verifying Python installation..."
python --version
python3 --version
echo ""
echo "Available Python versions:"
/home/node/.local/bin/uv python list

echo "✅ Python 3.14 configured as default"
