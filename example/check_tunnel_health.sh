#!/bin/bash
set -e

# Check if all required parameters are provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 <tunnel_id> <resource_group> <vm_name> <cloudflare_account_id> <cloudflare_api_token>"
    exit 1
fi

TUNNEL_ID=$1
RESOURCE_GROUP=$2
VM_NAME=$3
CLOUDFLARE_ACCOUNT_ID=$4
CLOUDFLARE_API_TOKEN=$5

# Function to check Cloudflare tunnel status
check_tunnel_status() {
    local response=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local status=$(echo $response | jq -r '.result.status')
    
    if [ "$status" = "healthy" ]; then
        return 0
    elif [ "$status" = "null" ] || [ "$status" = "error" ]; then
        echo "Error checking tunnel status"
        return 1
    elif [ "$status" = "inactive" ]; then
        echo "Tunnel is inactive (waiting for activation)..."
        return 0  # Changed from 2 to 0 to indicate continue waiting
    else
        echo "Tunnel status: $status"
        return 0  # Changed from 2 to 0 to indicate continue waiting
    fi
}

# Check for tunnel status
echo "Checking tunnel health..."
MAX_ATTEMPTS=30
ATTEMPT=0
SLEEP_TIME=20

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    # Check tunnel status
    check_tunnel_status
    STATUS=$?
    
    if [ $STATUS -eq 0 ]; then
        if [ "$(curl -s -X GET \
            "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" | jq -r '.result.status')" = "healthy" ]; then
            echo "Tunnel is healthy!"
            exit 0
        fi
    elif [ $STATUS -eq 1 ]; then
        echo "Error checking tunnel status"
        exit 1
    fi
    
    echo "Waiting for tunnel to be healthy (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
    sleep $SLEEP_TIME
done

echo "Timeout waiting for tunnel to be healthy"
echo "Total wait time: $((MAX_ATTEMPTS * SLEEP_TIME)) seconds"
exit 1 