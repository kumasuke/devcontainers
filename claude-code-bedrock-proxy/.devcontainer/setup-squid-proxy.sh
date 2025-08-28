#!/bin/bash
# Setup Squid proxy for domain-based filtering with dynamic DNS resolution

set -euo pipefail
IFS=$'\n\t'

echo "Setting up Squid proxy for domain-based filtering..."

# Squid is already installed and configured in Dockerfile
# Configuration file is already at /etc/squid/squid.conf

# Create log directory if it doesn't exist
mkdir -p /var/log/squid
chown proxy:proxy /var/log/squid

# Start or restart Squid
service squid restart || service squid start

echo "Squid proxy setup complete"
echo ""
echo "Configure your environment to use the proxy:"
echo "  export HTTP_PROXY=http://localhost:3128"
echo "  export HTTPS_PROXY=http://localhost:3128"
echo "  export http_proxy=http://localhost:3128"
echo "  export https_proxy=http://localhost:3128"
echo ""
echo "For AWS CLI/SDK, you may need to set:"
echo "  export AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt"
echo ""
echo "The proxy will dynamically resolve and allow connections to:"
echo "  - bedrock.us-east-1.amazonaws.com"
echo "  - bedrock-runtime.us-east-1.amazonaws.com"
echo "  - bedrock-fips.us-east-1.amazonaws.com"
echo "  - bedrock-agent.us-east-1.amazonaws.com"
echo "  - bedrock-agent-runtime.us-east-1.amazonaws.com"
echo "  - sts.us-east-1.amazonaws.com"
echo "  - GitHub domains"
echo "  - NPM registry"
echo "  - Anthropic API"