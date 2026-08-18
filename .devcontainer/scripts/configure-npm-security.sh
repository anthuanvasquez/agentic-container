#!/usr/bin/env bash
#
# Harden npm and pnpm defaults to mitigate supply-chain attacks.
# Run once at image build time as the node user.
#
set -euo pipefail

NPMRC="/home/node/.npmrc"
PNPMRC="/home/node/.pnpmrc"

cat > "$NPMRC" << 'EOF'
; Only install from the official registry by default.
registry=https://registry.npmjs.org/

; To consume a private GitHub Packages scope, uncomment and authenticate:
; @myorg:registry=https://npm.pkg.github.com/

; Reproducibility
save-exact=true
package-lock=true
engine-strict=true

; Security: do not run lifecycle scripts during install.
; Run them explicitly after reviewing the package.
ignore-scripts=true

; Reduce install noise.
fund=false

; Limit concurrent fetches to reduce exposure window.
maxsockets=1
fetch-retries=2
fetch-retry-mintimeout=10000
fetch-retry-maxtimeout=60000
EOF

cat > "$PNPMRC" << 'EOF'
; Security
ignore-scripts=true
hoist=false
strict-peer-dependencies=true
resolution-mode=lowest-direct

; Registry
registry=https://registry.npmjs.org/

; Reproducibility
save-exact=true
prefer-workspace-packages=true
EOF

chown node:node "$NPMRC" "$PNPMRC"

echo "✅ npm/pnpm security configuration written"
