#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "⚠️ Not a git repository. Skipping git hook setup."
    exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

mkdir -p "$HOOKS_DIR"

cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/usr/bin/env bash
BRANCH=$(git branch --show-current)

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    echo ""
    echo "❌ ERROR: Direct commits to '$BRANCH' are not allowed."
    echo ""
    echo "Create a feature branch instead:"
    echo "   git checkout -b feature/your-feature-name"
    echo ""
    exit 1
fi

echo "✅ Committing to branch: $BRANCH"
exit 0
EOF

chmod +x "$HOOKS_DIR/pre-commit"
echo "✅ Pre-commit hook installed at $HOOKS_DIR/pre-commit"
