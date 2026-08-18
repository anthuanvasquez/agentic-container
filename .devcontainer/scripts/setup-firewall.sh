#!/usr/bin/env bash
#
# Optional egress firewall for Agentic Container.
# Activated when FIREWALL_ENABLED is set to "true".
# Allows GitHub endpoints, common package registries, DNS, and localhost;
# blocks everything else by default.
#

set -euo pipefail

STATE_FILE="/var/lib/agentic-container-firewall"

if [[ "${FIREWALL_ENABLED:-false}" != "true" ]]; then
    echo "Firewall disabled (set FIREWALL_ENABLED=true to enable). Skipping."
    exit 0
fi

if [ -f "$STATE_FILE" ]; then
    echo "Firewall already configured ($STATE_FILE). Skipping."
    exit 0
fi

echo "=== Agentic Container firewall ==="

# Resolve hostnames to IPs, skipping failures
resolve_hosts() {
    local ipset_name="$1"
    shift
    for host in "$@"; do
        if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
            echo "Adding $host"
            ipset add "$ipset_name" "$host" -exist || true
            continue
        fi

        echo "Resolving $host..."
        ips=$(dig +short A "$host" 2>/dev/null || true)
        if [ -z "$ips" ]; then
            echo "⚠️ Could not resolve $host"
            continue
        fi

        for ip in $ips; do
            if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "  Adding $ip ($host)"
                ipset add "$ipset_name" "$ip" -exist || true
            fi
        done
    done
}

# 1. Capture Docker DNS rules before flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# 2. Capture Docker networks
DOCKER_NETWORKS=$(ip -o -f inet addr show | awk '!/127\.0\.0\.1/ {print $4}')

# 3. Create ipset allowlist
ipset destroy agentic-allowlist 2>/dev/null || true
ipset create agentic-allowlist hash:net

# 4. GitHub official IP ranges
echo "Fetching GitHub IP ranges..."
gh_meta=$(curl -fsSL --connect-timeout 10 https://api.github.com/meta || true)
if [ -n "$gh_meta" ]; then
    echo "$gh_meta" | jq -r '(.web + .api + .git + .packages + .actions + .hooks + .importer + .copilot // [])[]' 2>/dev/null | sort -u | while read -r cidr; do
        if [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            ipset add agentic-allowlist "$cidr" -exist || true
        fi
    done
else
    echo "⚠️ Could not fetch GitHub IP ranges"
fi

# 5. Explicit allowed domains (registries, GitHub services, system updates).
# NOTE: We resolve domains at setup time rather than allowing entire CDN ranges,
# to keep the egress surface as small as possible. If an endpoint moves, rerun
# this script or restart the container.
resolve_hosts agentic-allowlist \
    github.com \
    api.github.com \
    raw.githubusercontent.com \
    codeload.github.com \
    gist.github.com \
    objects.githubusercontent.com \
    pkg-containers.githubusercontent.com \
    ghcr.io \
    npm.pkg.github.com \
    registry.npmjs.org \
    pypi.org \
    files.pythonhosted.org \
    bun.sh \
    crates.io \
    static.crates.io \
    index.crates.io \
    registry-1.docker.io \
    auth.docker.io \
    production.cloudflare.docker.com \
    deb.debian.org \
    security.debian.org \
    nodejs.org \
    cli.github.com \
    update.code.visualstudio.com \
    marketplace.visualstudio.com \
    vscode.blob.core.windows.net \
    astral.sh \
    install.python-poetry.org

# 7. Flush and rebuild iptables
iptables -F 2>/dev/null || true
iptables -X 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t nat -X 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -t mangle -X 2>/dev/null || true

# Restore Docker DNS NAT
if [ -n "$DOCKER_DNS_RULES" ]; then
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | while read -r rule; do
        [ -n "$rule" ] && iptables -t nat $rule || true
    done
fi

# Base rules
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Docker networks
if [ -n "$DOCKER_NETWORKS" ]; then
    echo "$DOCKER_NETWORKS" | while read -r network; do
        [ -n "$network" ] || continue
        iptables -A INPUT -s "$network" -j ACCEPT
        iptables -A OUTPUT -d "$network" -j ACCEPT
    done
fi

# Allowed destinations
iptables -A OUTPUT -m set --match-set agentic-allowlist dst -j ACCEPT

# ICMP for diagnostics
iptables -A OUTPUT -p icmp -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT

# Reject everything else with feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited
iptables -A INPUT -j REJECT --reject-with icmp-admin-prohibited

# IPv6 fallback block
ip6tables -P INPUT DROP 2>/dev/null || true
ip6tables -P FORWARD DROP 2>/dev/null || true
ip6tables -P OUTPUT DROP 2>/dev/null || true
ip6tables -A INPUT -i lo -j ACCEPT 2>/dev/null || true
ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true
ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
ip6tables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
ip6tables -A INPUT -j REJECT 2>/dev/null || true
ip6tables -A OUTPUT -j REJECT 2>/dev/null || true

# Verify
if curl -fsSL --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "✅ GitHub API reachable"
else
    echo "❌ GitHub API unreachable after firewall setup"
    exit 1
fi

if curl -fsSL --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "❌ example.com should be blocked"
    exit 1
else
    echo "✅ example.com blocked"
fi

# Mark as configured
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"
echo "✅ Firewall configured. To reconfigure, delete $STATE_FILE and restart the container."
