#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# --- Configuration ---
BEDROCK_REGION="${BEDROCK_REGION:-us-east-1}"

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules and delete existing ipsets
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true
ipset destroy bedrock-ips 2>/dev/null || true

# 2. Selectively restore ONLY internal Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

# IMPORTANT: Allow established connections FIRST
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS and localhost
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -p tcp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Create ipsets
ipset create allowed-domains hash:net
ipset create bedrock-ips hash:net

# Fetch GitHub meta information
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "Adding GitHub range $cidr"
        ipset add allowed-domains "$cidr"
    fi
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Standard allowed domains (excluding Bedrock)
STANDARD_DOMAINS=(
    "registry.npmjs.org"
    "api.anthropic.com"
    "sentry.io"
    "statsig.anthropic.com"
    "statsig.com"
)

# Bedrock-specific domains
BEDROCK_DOMAINS=(
    "bedrock-runtime.${BEDROCK_REGION}.amazonaws.com"
    "bedrock.${BEDROCK_REGION}.amazonaws.com"
    "sts.${BEDROCK_REGION}.amazonaws.com"
)

# Resolve standard domains
for domain in "${STANDARD_DOMAINS[@]}"; do
    echo "Resolving $domain..."
    ips=$(dig +short A "$domain" | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    
    if [ -z "$ips" ]; then
        ips=$(dig +short A "$domain" @8.8.8.8 | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    fi
    
    if [ -z "$ips" ]; then
        echo "WARNING: Failed to resolve $domain, skipping..."
        continue
    fi
    
    while read -r ip; do
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "Adding $ip for $domain"
            ipset add allowed-domains "$ip" 2>/dev/null || true
        fi
    done < <(echo "$ips")
done

# Resolve Bedrock domains to separate ipset for logging
echo "Resolving Bedrock domains (will be bypassed)..."
for domain in "${BEDROCK_DOMAINS[@]}"; do
    echo "Resolving $domain..."
    ips=$(dig +short A "$domain" | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    
    if [ -z "$ips" ]; then
        ips=$(dig +short A "$domain" @8.8.8.8 | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    fi
    
    if [ -n "$ips" ]; then
        while read -r ip; do
            if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "Adding Bedrock IP $ip for $domain"
                ipset add bedrock-ips "$ip" 2>/dev/null || true
            fi
        done < <(echo "$ips")
    fi
done

# Get host IP from default route
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

# Set up iptables rules
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# === BEDROCK BYPASS RULES ===
# Method 1: Allow all HTTPS traffic to Bedrock IPs (before DROP policy)
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set bedrock-ips dst -j ACCEPT

# Method 2: Mark packets for AWS SDK processes (alternative approach)
# This requires the process to be run with specific group ID
# groupadd -f aws-sdk
# iptables -A OUTPUT -m owner --gid-owner aws-sdk -j ACCEPT

# Method 3: Allow based on specific user (claude/node)
# iptables -A OUTPUT -m owner --uid-owner node -p tcp --dport 443 -m set --match-set bedrock-ips dst -j ACCEPT

# Log Bedrock traffic for debugging (optional)
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set bedrock-ips dst -j LOG --log-prefix "BEDROCK-ALLOW: " --log-level 6

# Allow standard domains
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Set default policies to DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

echo "Firewall configuration complete with Bedrock bypass"
echo ""
echo "=== Bedrock Bypass Status ==="
echo "Bedrock IPs in bypass list:"
ipset list bedrock-ips | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -5
echo ""
echo "Testing connectivity..."

# Test standard firewall
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "❌ ERROR: Firewall verification failed - able to reach https://example.com"
else
    echo "✅ Firewall blocking general traffic as expected"
fi

# Test GitHub
if curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "✅ GitHub API accessible"
else
    echo "❌ ERROR: Cannot reach GitHub API"
fi

# Test Bedrock (should get 403 without auth, but connection should work)
if curl --connect-timeout 5 -s -o /dev/null -w "%{http_code}" \
    "https://bedrock-runtime.${BEDROCK_REGION}.amazonaws.com/" | grep -q "403"; then
    echo "✅ Bedrock endpoint accessible (403 is expected without auth)"
else
    echo "⚠️  WARNING: Bedrock endpoint test inconclusive"
fi