#!/bin/bash
# Transparent proxy solution for domain-based filtering
# This allows traffic to specific domains without IP-based filtering

set -euo pipefail
IFS=$'\n\t'

BEDROCK_REGION="${BEDROCK_REGION:-us-east-1}"

echo "Setting up transparent proxy for Amazon Bedrock..."

# Install socat if not present
if ! command -v socat &> /dev/null; then
    apt-get update && apt-get install -y socat
fi

# Function to create proxy for a domain
create_proxy() {
    local port=$1
    local domain=$2
    local target_port=${3:-443}
    
    echo "Creating proxy on port $port for $domain:$target_port"
    
    # Kill existing socat process if any
    pkill -f "socat.*:$port" || true
    
    # Start socat in background
    socat TCP-LISTEN:$port,fork,reuseaddr TCP:$domain:$target_port &
    
    echo "Proxy started on localhost:$port -> $domain:$target_port"
}

# Create proxies for Bedrock endpoints
create_proxy 8443 "bedrock-runtime.${BEDROCK_REGION}.amazonaws.com" 443
create_proxy 8444 "bedrock.${BEDROCK_REGION}.amazonaws.com" 443
create_proxy 8445 "sts.${BEDROCK_REGION}.amazonaws.com" 443

# Add hosts entries for local redirection
cat >> /etc/hosts <<EOF
# Bedrock proxy entries
127.0.0.1 bedrock-runtime.${BEDROCK_REGION}.amazonaws.local
127.0.0.1 bedrock.${BEDROCK_REGION}.amazonaws.local
127.0.0.1 sts.${BEDROCK_REGION}.amazonaws.local
EOF

echo "Transparent proxy setup complete"
echo ""
echo "To use the proxy, configure your AWS SDK to use:"
echo "  - bedrock-runtime endpoint: https://localhost:8443"
echo "  - bedrock endpoint: https://localhost:8444"
echo "  - sts endpoint: https://localhost:8445"
echo ""
echo "Or set environment variables:"
echo "  export AWS_ENDPOINT_URL_BEDROCK=https://localhost:8443"
echo "  export AWS_ENDPOINT_URL_BEDROCK_RUNTIME=https://localhost:8443"
echo "  export AWS_ENDPOINT_URL_STS=https://localhost:8445"