#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, and pipeline failures
IFS=$'\n\t'       # Stricter word splitting

# State file to track if firewall has been configured
STATE_FILE="/var/lib/firewall-configured"

# Disable IPv6 to prevent bypass of IPv4-only firewall rules
echo "Disabling IPv6..."
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1 || true

# Check if firewall is already configured
if [ -f "$STATE_FILE" ]; then
    echo "Firewall already configured (found $STATE_FILE), skipping..."
    echo "To reconfigure, delete $STATE_FILE and restart container"
    exit 0
fi

echo "Starting firewall configuration..."

# Initialize DNS resolution statistics
TOTAL_DOMAINS=0
RESOLVED_DOMAINS=0
FAILED_DOMAINS=0

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# 2. Get all Docker network interfaces BEFORE flushing (we'll need these later)
echo "Detecting Docker networks..."
DOCKER_NETWORKS=$(ip -o -f inet addr show | grep -v "127.0.0.1" | awk '{print $4}')

if [ -z "$DOCKER_NETWORKS" ]; then
    echo "ERROR: Failed to detect any Docker networks"
    exit 1
fi

# 3. Create ipset with CIDR support (do this BEFORE flushing so we can use network)
ipset destroy allowed-domains 2>/dev/null || true
ipset create allowed-domains hash:net

# Fetch GitHub meta information and aggregate + add their IP ranges
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi

echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    echo "Adding GitHub range $cidr"
    ipset add allowed-domains "$cidr" -exist
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Add Anthropic IP ranges (official published ranges from https://docs.claude.com/en/api/ip-addresses)
echo "Adding Anthropic IP ranges..."
echo "Adding Anthropic CIDR range 160.79.104.0/23"
ipset add allowed-domains "160.79.104.0/23" -exist

# Add Anthropic specific IP addresses
for ip in \
    "34.162.46.92" \
    "34.162.102.82" \
    "34.162.136.91" \
    "34.162.142.92" \
    "34.162.183.95"; do
    echo "Adding Anthropic IP $ip"
    ipset add allowed-domains "$ip" -exist
done

# Fetch and add Google Cloud/API IP ranges
echo "Fetching Google Cloud/API IP ranges..."
goog_ranges=$(curl -s https://www.gstatic.com/ipranges/goog.json)
if [ -z "$goog_ranges" ]; then
    echo "ERROR: Failed to fetch Google IP ranges"
    exit 1
fi

if ! echo "$goog_ranges" | jq -e '.prefixes' >/dev/null; then
    echo "ERROR: Google API response missing required fields"
    exit 1
fi

echo "Processing Google IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from Google: $cidr"
        exit 1
    fi
    echo "Adding Google range $cidr"
    ipset add allowed-domains "$cidr" -exist
done < <(echo "$goog_ranges" | jq -r '.prefixes[].ipv4Prefix | select(. != null)')

# Fetch and add Cloudflare CDN IP ranges
echo "Fetching Cloudflare CDN IP ranges..."
cf_ranges=$(curl -s https://api.cloudflare.com/client/v4/ips)
if [ -z "$cf_ranges" ]; then
    echo "ERROR: Failed to fetch Cloudflare IP ranges"
    exit 1
fi

if ! echo "$cf_ranges" | jq -e '.result.ipv4_cidrs' >/dev/null; then
    echo "ERROR: Cloudflare API response missing required fields"
    exit 1
fi

echo "Processing Cloudflare IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from Cloudflare: $cidr"
        exit 1
    fi
    echo "Adding Cloudflare range $cidr"
    ipset add allowed-domains "$cidr" -exist
done < <(echo "$cf_ranges" | jq -r '.result.ipv4_cidrs[]')

# Fetch and add AWS IP ranges (covers many AI services: Hugging Face, Replicate, etc.)
# Filtered for US East/West regions and EC2/CloudFront services only to limit allowlist size
echo "Fetching AWS IP ranges..."
aws_ranges=$(curl -s https://ip-ranges.amazonaws.com/ip-ranges.json)
if [ -z "$aws_ranges" ]; then
    echo "ERROR: Failed to fetch AWS IP ranges"
    exit 1
fi

if ! echo "$aws_ranges" | jq -e '.prefixes' >/dev/null; then
    echo "ERROR: AWS API response missing required fields"
    exit 1
fi

echo "Processing AWS IPs (US regions: us-east-1, us-west-2; Services: EC2, CLOUDFRONT)..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from AWS: $cidr"
        exit 1
    fi
    echo "Adding AWS range $cidr"
    ipset add allowed-domains "$cidr" -exist
done < <(echo "$aws_ranges" | jq -r '.prefixes[] | select(.region == "us-east-1" or .region == "us-west-2") | select(.service == "EC2" or .service == "CLOUDFRONT") | .ip_prefix' | aggregate -q)

# Resolve and add other allowed domains (defense-in-depth: includes DNS backup for services above)
for domain in \
    "dns.google" \
    "1.1.1.1" \
    "8.8.8.8" \
    "8.8.4.4" \
    "auth.openai.com" \
    "chatgpt.com" \
    "context7.com" \
    "unpkg.com" \
    "cdn.jsdelivr.net" \
    "opencode.ai" \
    "cdnjs.cloudflare.com" \
    "github.com" \
    "api.github.com" \
    "raw.githubusercontent.com" \
    "github.githubassets.com" \
    "collector.github.com" \
    "ghcr.io" \
    "pkg-containers.githubusercontent.com" \
    "nodejs.org" \
    "registry.npmjs.org" \
    "pypi.org" \
    "files.pythonhosted.org" \
    "astral.sh" \
    "bun.sh" \
    "crates.io" \
    "static.crates.io" \
    "index.crates.io" \
    "docker.io" \
    "registry-1.docker.io" \
    "auth.docker.io" \
    "production.cloudflare.docker.com" \
    "api.anthropic.com" \
    "docs.claude.com" \
    "api.openai.com" \
    "aistudio.google.com" \
    "accounts.google.com" \
    "oauth2.googleapis.com" \
    "www.googleapis.com" \
    "storage.googleapis.com" \
    "content.googleapis.com" \
    "generativelanguage.googleapis.com" \
    "sentry.io" \
    "statsig.anthropic.com" \
    "statsig.com" \
    "marketplace.visualstudio.com" \
    "vscode.blob.core.windows.net" \
    "update.code.visualstudio.com" \
    "docs.mcp.cloudflare.com" \
    "mcp.context7.com" \
    "vercel.com" \
    "ui.shadcn.com" \
    "tailwindcss.com" \
    "radix-ui.com" \
    "fonts.googleapis.com" \
    "fonts.gstatic.com" \
    "react.dev" \
    "reactjs.org" \
    "esm.sh" \
    "deb.debian.org" \
    "security.debian.org" \
    "archive.ubuntu.com" \
    "security.ubuntu.com" \
    "lucide.dev" \
    "openrouter.ai" \
    "api.cerebras.ai" \
    "inference.cerebras.ai" \
    "cloud.cerebras.ai" \
    "cerebras.ai" \
    "dashscope.aliyuncs.com" \
    "qwen.ai" \
    "qwenlm.ai" \
    "aliyuncs.com" \
    "alibabacloud.com" \
    "cn-hangzhou.aliyuncs.com" \
    "us-west-1.aliyuncs.com" \
    "ap-southeast-1.aliyuncs.com" \
    "api.minimax.chat" \
    "minimax.chat" \
    "z.ai" \
    "api.cohere.ai" \
    "cohere.ai" \
    "api.together.xyz" \
    "together.xyz" \
    "api.replicate.com" \
    "replicate.com" \
    "api-inference.huggingface.co" \
    "huggingface.co" \
    "api.perplexity.ai" \
    "perplexity.ai" \
    "api.mistral.ai" \
    "mistral.ai" \
    "api.deepinfra.com" \
    "deepinfra.com" \
    "api.fireworks.ai" \
    "fireworks.ai" \
    "api.groq.com" \
    "groq.com" \
    "api.lepton.ai" \
    "lepton.ai" \
    "mancer.tech" \
    "api.mancer.tech" \
    "api.deepseek.com" \
    "deepseek.com" \
    "api.lingyiwanwu.com" \
    "platform.lingyiwanwu.com"; do

    # Check if this is already an IP address
    if [[ "$domain" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Adding IP address $domain"
        ipset add allowed-domains "$domain" -exist
        continue
    fi

    # Otherwise, resolve the hostname
    TOTAL_DOMAINS=$((TOTAL_DOMAINS + 1))
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "WARNING: Failed to resolve $domain (continuing...)"
        FAILED_DOMAINS=$((FAILED_DOMAINS + 1))
        continue
    fi

    # Successfully resolved, add IPs to allowlist
    domain_resolved=false
    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "WARNING: Invalid IP from DNS for $domain: $ip (skipping)"
            continue
        fi
        echo "Adding $ip for $domain"
        ipset add allowed-domains "$ip" -exist
        domain_resolved=true
    done < <(echo "$ips")

    # Count as resolved only if at least one valid IP was added
    if [ "$domain_resolved" = true ]; then
        RESOLVED_DOMAINS=$((RESOLVED_DOMAINS + 1))
    else
        FAILED_DOMAINS=$((FAILED_DOMAINS + 1))
    fi
done

echo ""
echo "IP allowlist built successfully"
echo "DNS Resolution Summary: ${RESOLVED_DOMAINS}/${TOTAL_DOMAINS} domains resolved successfully"
if [ "$FAILED_DOMAINS" -gt 0 ]; then
    echo "  WARNING: ${FAILED_DOMAINS} domains failed to resolve"
fi
echo ""

# 4. Now flush iptables and rebuild with our allowlist
echo "Flushing existing iptables rules..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# 5. Restore Docker DNS NAT rules
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# 6. Allow DNS and localhost before setting restrictive policies
echo "Configuring base rules..."
# Allow outbound DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
# Allow inbound DNS responses
iptables -A INPUT -p udp --sport 53 -j ACCEPT
# Allow outbound SSH
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
# Allow inbound SSH responses
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
# Allow localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 7. Allow traffic to/from all Docker networks (for OTel, inter-container communication, etc.)
echo "Allowing Docker networks..."
while read -r network; do
    echo "  Allowing Docker network: $network"
    iptables -A INPUT -s "$network" -j ACCEPT
    iptables -A OUTPUT -d "$network" -j ACCEPT
done < <(echo "$DOCKER_NETWORKS")

# 8. Set default policies to DROP
echo "Setting restrictive default policies..."
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# 9. Allow established connections for already approved traffic
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 10. Allow only specific outbound traffic to allowed domains
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# 11. Explicitly REJECT all other outbound traffic for immediate feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# 12. Configure IPv6 firewall rules (defense-in-depth if IPv6 couldn't be disabled)
echo "Configuring IPv6 firewall rules..."
# Set default policies to DROP for IPv6
ip6tables -P INPUT DROP 2>/dev/null || echo "  Note: IPv6 may already be disabled"
ip6tables -P FORWARD DROP 2>/dev/null || true
ip6tables -P OUTPUT DROP 2>/dev/null || true

# Allow IPv6 localhost only
ip6tables -A INPUT -i lo -j ACCEPT 2>/dev/null || true
ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true

# Allow established IPv6 connections (for localhost)
ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
ip6tables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

# Explicitly REJECT all other IPv6 traffic
ip6tables -A INPUT -j REJECT 2>/dev/null || true
ip6tables -A OUTPUT -j REJECT 2>/dev/null || true
echo "IPv6 firewall rules configured"

echo ""
echo "Firewall configuration complete!"
echo ""
echo "Verifying firewall rules..."

# Verify IPv6 is disabled (warning only, not fatal)
if sysctl net.ipv6.conf.all.disable_ipv6 | grep -q "= 1"; then
    echo "✓ Firewall verification passed - IPv6 is disabled"
else
    echo "⚠ WARNING: IPv6 is still enabled (container restrictions may prevent disabling)"
    echo "  IPv6 traffic will be blocked by ip6tables rules as a security fallback"
    echo "  This is expected in some Docker environments and does not affect security"
fi

# Verify blocked domains
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi

# Verify GitHub API access
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi

# Verify OpenRouter API access
if ! curl --connect-timeout 5 https://openrouter.ai/api/v1/models >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://openrouter.ai"
    exit 1
else
    echo "Firewall verification passed - able to reach https://openrouter.ai as expected"
fi

# Verify Cerebras API access
if ! curl --connect-timeout 5 https://api.cerebras.ai/v1/models >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.cerebras.ai"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.cerebras.ai as expected"
fi

# Create state file to mark firewall as configured
echo "Creating state file $STATE_FILE..."
touch "$STATE_FILE"
echo "Firewall state saved - will skip configuration on subsequent container starts"
