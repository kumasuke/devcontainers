#!/bin/bash
# refresh-firewall.sh - Refresh DNS resolutions for AWS endpoints
# Run this script if you experience timeout issues with Amazon Bedrock API

set -euo pipefail
IFS=$'\n\t'

BEDROCK_REGION="${BEDROCK_REGION:-us-east-1}"

echo "Refreshing firewall rules for Amazon Bedrock endpoints..."

# Critical domains that need to be refreshed
REFRESH_DOMAINS=(
    "bedrock-runtime.${BEDROCK_REGION}.amazonaws.com"
    "bedrock.${BEDROCK_REGION}.amazonaws.com"
    "sts.${BEDROCK_REGION}.amazonaws.com"
)

# Clear existing entries for these domains
for domain in "${REFRESH_DOMAINS[@]}"; do
    echo "Refreshing $domain..."
    
    # Get current IPs
    old_ips=$(ipset list allowed-domains | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' || true)
    
    # Resolve new IPs
    new_ips=$(dig +short A "$domain" | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    
    if [ -z "$new_ips" ]; then
        echo "WARNING: Failed to resolve $domain, trying alternative DNS..."
        new_ips=$(dig +short A "$domain" @8.8.8.8 | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    fi
    
    if [ -z "$new_ips" ]; then
        echo "ERROR: Failed to resolve $domain"
        continue
    fi
    
    # Add new IPs
    while read -r ip; do
        echo "Adding/updating $ip for $domain"
        ipset add allowed-domains "$ip" 2>/dev/null || true
    done <<< "$new_ips"
done

echo "Firewall refresh complete"

# Test connectivity
echo "Testing Amazon Bedrock connectivity..."
if curl --connect-timeout 5 -s -o /dev/null -w "%{http_code}" \
    "https://bedrock-runtime.${BEDROCK_REGION}.amazonaws.com/" | grep -q "403"; then
    echo "✓ Amazon Bedrock endpoint is reachable (403 is expected without auth)"
else
    echo "⚠ WARNING: Could not reach Amazon Bedrock endpoint"
fi