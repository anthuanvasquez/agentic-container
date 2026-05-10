#!/bin/bash
#
# Setup Git Hooks
#
# Installs git hooks for branch protection and safety.
# Run this after cloning the repository or rebuilding the container.
#

# Strict error handling
set -euo pipefail

# Dynamically resolve repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

# Validate git repository (works with worktrees and submodules)
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ ERROR: Not a git repository"
    echo "Current directory: $(pwd)"
    echo "Repository root: $REPO_ROOT"
    exit 1
fi

# Validate hooks directory is writable
if [ -d "$HOOKS_DIR" ] && [ ! -w "$HOOKS_DIR" ]; then
    echo "❌ ERROR: Hooks directory is not writable: $HOOKS_DIR"
    exit 1
fi

echo "=== Git Hooks Setup ==="
echo ""

# Create hooks directory if it doesn't exist
if [ ! -d "$HOOKS_DIR" ]; then
    echo "Creating hooks directory..."
    mkdir -p "$HOOKS_DIR"
fi

# Install pre-commit hook
echo "Installing pre-commit hook..."
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
#
# Git Pre-Commit Hook: Branch Protection
#
# Prevents direct commits to main/master branches.
# Encourages feature branch workflow for safety.
#

BRANCH=$(git branch --show-current)

# Block commits to protected branches
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    echo ""
    echo "❌ ERROR: Direct commits to '$BRANCH' are not allowed"
    echo ""
    echo "This is a safety measure to protect your work."
    echo ""
    echo "📝 Create a feature branch instead:"
    echo "   git checkout -b feature/your-feature-name"
    echo ""
    echo "Or for session-based work:"
    echo "   git checkout -b session/$(date +%Y%m%d-%H%M)-description"
    echo ""
    echo "💡 Need help with PR workflow? Use the git-pr-helper skill:"
    echo "   When ready to merge, ask Claude to use git-pr-helper"
    echo ""
    echo "⚠️  To bypass this hook (NOT recommended):"
    echo "   git commit --no-verify"
    echo ""
    exit 1
fi

# Success - allow commit
echo "✅ Committing to branch: $BRANCH"
exit 0
EOF

chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ Pre-commit hook installed"
echo ""

# Verify installation
if [ -x "$HOOKS_DIR/pre-commit" ]; then
    echo "✅ Hook is executable"
else
    echo "❌ Hook is not executable!"
    exit 1
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Git hooks have been installed successfully."
echo ""
echo "Features:"
echo "  • Blocks direct commits to main/master"
echo "  • Encourages feature branch workflow"
echo "  • Integrates with git-pr-helper skill"
echo ""
echo "To test the hook:"
echo "  git checkout main"
echo "  touch test.txt"
echo "  git add test.txt"
echo "  git commit -m 'test'  # Should be blocked"
echo ""
