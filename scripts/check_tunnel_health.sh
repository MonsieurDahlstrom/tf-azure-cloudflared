#!/bin/bash
# Remove 'set -e' as it causes script to exit on non-zero return codes
# set -e

# Check if all required parameters are provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 <tunnel_id> <cloudflare_account_id> <cloudflare_api_token>"
    exit 1
fi

TUNNEL_ID=$1
CLOUDFLARE_ACCOUNT_ID=$2
CLOUDFLARE_API_TOKEN=$3
DEBUG=${4:-false}

# Remove any quotes from parameters
TUNNEL_ID=$(echo "$TUNNEL_ID" | sed -e "s/^['\"]//g" -e "s/['\"]$//g")
CLOUDFLARE_ACCOUNT_ID=$(echo "$CLOUDFLARE_ACCOUNT_ID" | sed -e "s/^['\"]//g" -e "s/['\"]$//g")
CLOUDFLARE_API_TOKEN=$(echo "$CLOUDFLARE_API_TOKEN" | sed -e "s/^['\"]//g" -e "s/['\"]$//g")

# Debug token function
debug_token() {
    if [ "$DEBUG" = "true" ]; then
        local token=$1
        
        echo "DEBUG: Token diagnostics:"
        echo "  - Length: ${#token}"
        echo "  - First 4 chars: [REDACTED]..."
        
        # Check if token has Bearer prefix
        if [[ "$token" == "Bearer "* ]]; then
            echo "  - WARNING: Token already includes 'Bearer ' prefix - this may cause auth issues"
        fi
    fi
}

# Function to validate Cloudflare API token with the tunnel
validate_token() {
    if [ "$DEBUG" = "true" ]; then
        debug_token "$CLOUDFLARE_API_TOKEN"
    fi
    
    # This script checks the tunnel directly without requiring account-level read permissions.
    local tunnel_uri="https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID"
    
    local response=$(curl -s -X GET "$tunnel_uri" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$response" | jq -r '.success')
    
    if [ "$success" = "true" ]; then
        if [ "$DEBUG" = "true" ]; then
            local name=$(echo "$response" | jq -r '.result.name')
            local status=$(echo "$response" | jq -r '.result.status')
            
            echo "SUCCESS: Token has access to tunnel [REDACTED_TUNNEL]"
            echo "Tunnel Name: $name"
            echo "Tunnel Status: $status"
        fi
        return 0
    else
        echo "FAILED to access tunnel"
        
        if [ "$DEBUG" = "true" ]; then
            # Sanitize response to remove sensitive data
            local sanitized_response=$(echo "$response" | sed -E 's/(eyJ|[A-Za-z0-9_-]{20,})/[REDACTED]/g')
            echo "Error details: $sanitized_response"
            echo -e "\nLikely issue: Token doesn't have permissions for this tunnel or the tunnel doesn't exist"
            echo "1. Go to Cloudflare Dashboard > Account Profile > API Tokens"
            echo "2. Create a new API token with these permissions:"
            echo "   - Account > Zero Trust > Read"
            echo "3. Make sure the token has access to the specific account ID"
        fi
        return 1
    fi
}

# Function to check Cloudflare tunnel status
check_tunnel_status() {
    local response=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    # Debug output
    if [ "$DEBUG" = "true" ]; then
        echo "Response received:"
        # Sanitize response to remove any sensitive information
        local sanitized_response=$(echo "$response" | sed -E 's/(eyJ|[A-Za-z0-9_-]{20,})/[REDACTED]/g')
        echo "$sanitized_response" | jq .
    fi
    
    local success=$(echo "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        if [ "$DEBUG" = "true" ]; then
            echo "Cloudflare API returned error:"
            # Sanitize errors
            local sanitized_errors=$(echo "$response" | jq '.errors' | sed -E 's/(eyJ|[A-Za-z0-9_-]{20,})/[REDACTED]/g')
            echo "$sanitized_errors"
        fi
        return 1
    fi
    
    local status=$(echo "$response" | jq -r '.result.status')
    
    if [ "$status" = "healthy" ]; then
        return 0
    elif [ "$status" = "null" ] || [ "$status" = "error" ]; then
        if [ "$DEBUG" = "true" ]; then
            echo "Error checking tunnel status"
        fi
        return 1
    else
        if [ "$DEBUG" = "true" ]; then
            echo "Tunnel status: $status"
        fi
        return 2  # Continue waiting
    fi
}

# Script execution starts here
MAX_ATTEMPTS=30
ATTEMPT=0
SLEEP_TIME=20

# Validate the API token first
if ! validate_token; then
    echo "Token validation failed. Please check your API token permissions."
    exit 1
fi

# Debug mode - uncomment to see all commands executed
# set -x

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    # Check tunnel status
    check_tunnel_status
    STATUS=$?
    
    if [ "$DEBUG" = "true" ]; then
        echo "Check returned status code: $STATUS"
    fi
    
    if [ $STATUS -eq 0 ]; then
        # Tunnel is healthy
        if [ "$DEBUG" = "true" ]; then
            echo "TUNNEL IS HEALTHY! Exiting with success."
        fi
        exit 0
    elif [ $STATUS -eq 1 ]; then
        echo "Error checking tunnel status"
        exit 1
    else
        # This covers status 2 and any other status that should wait
        if [ "$ATTEMPT" -eq 1 ] || [ "$DEBUG" = "true" ] || [ $(($ATTEMPT % 5)) -eq 0 ]; then
            echo "Waiting for tunnel to be healthy (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
        fi
        sleep $SLEEP_TIME
    fi
done

echo "Timeout waiting for tunnel to be healthy"
exit 1 