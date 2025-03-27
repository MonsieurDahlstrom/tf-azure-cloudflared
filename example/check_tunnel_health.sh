#!/bin/bash
# Remove 'set -e' as it causes script to exit on non-zero return codes
# set -e

# Check if all required parameters are provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 <tunnel_id> <cloudflare_account_id> <cloudflare_api_token> [cloudflare_email]"
    exit 1
fi

TUNNEL_ID=$1
CLOUDFLARE_ACCOUNT_ID=$2
CLOUDFLARE_API_TOKEN=$3
CLOUDFLARE_EMAIL=$4  # Optional

# Remove any quotes from parameters
TUNNEL_ID=$(echo "$TUNNEL_ID" | sed -e "s/^['\"]//g" -e "s/['\"]$//g")
CLOUDFLARE_ACCOUNT_ID=$(echo "$CLOUDFLARE_ACCOUNT_ID" | sed -e "s/^['\"]//g" -e "s/['\"]$//g")
CLOUDFLARE_API_TOKEN=$(echo "$CLOUDFLARE_API_TOKEN" | sed -e "s/^['\"]//g" -e "s/['\"]$//g")

# Debug token function
debug_token() {
    local token=$1
    
    echo "DEBUG: Token diagnostics:"
    echo "  - Length: ${#token}"
    echo "  - First 4 chars: ${token:0:4}..."
    
    # Check if token has Bearer prefix
    if [[ "$token" == "Bearer "* ]]; then
        echo "  - WARNING: Token already includes 'Bearer ' prefix - this may cause auth issues"
    fi
}

# Function to validate Cloudflare API token with the tunnel
validate_token() {
    debug_token "$CLOUDFLARE_API_TOKEN"
    
    # This script checks the tunnel directly without requiring account-level read permissions.
    # The API token only needs 'Account > Zero Trust > Read' permissions for the specific account.
    local tunnel_uri="https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID"
    
    echo "Checking access to tunnel: $tunnel_uri"
    
    local response=$(curl -s -X GET "$tunnel_uri" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$response" | jq -r '.success')
    
    if [ "$success" = "true" ]; then
        local name=$(echo "$response" | jq -r '.result.name')
        local status=$(echo "$response" | jq -r '.result.status')
        
        echo "SUCCESS: Token has access to tunnel $TUNNEL_ID"
        echo "Tunnel Name: $name"
        echo "Tunnel Status: $status"
        return 0
    else
        echo "FAILED to access tunnel"
        echo "Error details: $response"
        
        echo -e "\nLikely issue: Token doesn't have permissions for this tunnel or the tunnel doesn't exist"
        echo "1. Go to Cloudflare Dashboard > Account Profile > API Tokens"
        echo "2. Create a new API token with these permissions:"
        echo "   - Account > Zero Trust > Read"
        echo "3. Make sure the token has access to the specific account ID"
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
    echo "Response received:"
    echo "$response" | jq .
    
    local success=$(echo "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        echo "Cloudflare API returned error:"
        echo "$response" | jq '.errors'
        return 1
    fi
    
    local status=$(echo "$response" | jq -r '.result.status')
    
    if [ "$status" = "healthy" ]; then
        echo "Tunnel is healthy!"
        return 0
    elif [ "$status" = "null" ] || [ "$status" = "error" ]; then
        echo "Error checking tunnel status"
        return 1
    elif [ "$status" = "inactive" ]; then
        echo "Tunnel is inactive (waiting for activation)..."
        return 2  # Continue waiting
    else
        echo "Tunnel status: $status"
        return 2  # Continue waiting
    fi
}

# Script execution starts here
echo "Checking tunnel health..."
MAX_ATTEMPTS=30
ATTEMPT=0
SLEEP_TIME=20

# Validate the API token first
if ! validate_token; then
    exit 1
fi

# Debug mode - uncomment to see all commands executed
# set -x

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "Attempt $ATTEMPT of $MAX_ATTEMPTS"
    
    # Check tunnel status
    check_tunnel_status
    STATUS=$?
    
    echo "Check returned status code: $STATUS"
    
    if [ $STATUS -eq 0 ]; then
        # Tunnel is healthy
        echo "TUNNEL IS HEALTHY! Exiting with success."
        exit 0
    elif [ $STATUS -eq 1 ]; then
        echo "Error checking tunnel status"
        exit 1
    else
        # This covers status 2 and any other status that should wait
        echo "Waiting for tunnel to be healthy (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
        echo "Sleeping for $SLEEP_TIME seconds..."
        sleep $SLEEP_TIME
    fi
done

echo "Timeout waiting for tunnel to be healthy"
echo "Total wait time: $((MAX_ATTEMPTS * SLEEP_TIME)) seconds"
exit 1 