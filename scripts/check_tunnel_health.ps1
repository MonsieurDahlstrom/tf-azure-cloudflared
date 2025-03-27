param(
    [Parameter(Mandatory=$true)]
    [string]$TunnelID,
    
    [Parameter(Mandatory=$true)]
    [string]$CloudflareAccountId,

    [Parameter(Mandatory=$true)]
    [string]$CloudflareApiToken,
    
    [Parameter(Mandatory=$false)]
    [switch]$CustomDebug
)

# Enable debug output if requested
if ($CustomDebug) {
    $VerbosePreference = "Continue"
    $DebugPreference = "Continue"
}

# Check if required parameters are provided
if ([string]::IsNullOrEmpty($TunnelID) -or [string]::IsNullOrEmpty($CloudflareAccountId) -or [string]::IsNullOrEmpty($CloudflareApiToken)) {
    Write-Error "Error: Missing required parameters"
    Write-Host "Usage: $PSCommandPath -TunnelID <tunnel_id> -CloudflareAccountId <account_id> -CloudflareApiToken <api_token>"
    exit 1
}

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Error: Azure CLI is not installed"
    exit 1
}

# Function to debug token issues
function Debug-ApiToken {
    param (
        [string]$Token
    )
    
    Write-Host "DEBUG: Token diagnostics:" -ForegroundColor Yellow
    Write-Host "  - Length: $($Token.Length)" -ForegroundColor Yellow
    Write-Host "  - First 4 chars: $($Token.Substring(0, [Math]::Min(4, $Token.Length)))..." -ForegroundColor Yellow
    Write-Host "  - Contains non-printable chars: $(($Token -match '[^\x20-\x7E]'))" -ForegroundColor Yellow
    Write-Host "  - Contains quotes: $(($Token -match '[''"]'))" -ForegroundColor Yellow
    
    # Check token format
    $isLikelyAPIKey = $Token -match '^[a-f0-9]{37}$'
    $isLikelyAPIToken = $Token -match '^[a-zA-Z0-9_-]{40,}$'
    
    if ($isLikelyAPIKey) {
        Write-Host "  - Token format: Appears to be a Global API Key" -ForegroundColor Yellow
        Write-Host "  - NOTE: Global API Keys require X-Auth-Email header" -ForegroundColor Yellow
        $script:TokenType = "GlobalAPIKey"
    } elseif ($isLikelyAPIToken) {
        Write-Host "  - Token format: Appears to be an API Token" -ForegroundColor Green
        Write-Host "  - NOTE: API Tokens use the Authorization: Bearer header" -ForegroundColor Green
        $script:TokenType = "APIToken"
    } else {
        Write-Host "  - Token format: Unknown" -ForegroundColor Red
        $script:TokenType = "Unknown"
    }
    
    if ($Token.StartsWith("Bearer ")) {
        Write-Host "  - WARNING: Token already includes 'Bearer ' prefix - this may cause auth issues" -ForegroundColor Red
    }
}

# Function to validate Cloudflare API token
function Test-CloudflareToken {
    param (
        [string]$AccountId,
        [string]$ApiToken,
        [string]$TunnelId = ""
    )

    # Original token for debugging
    $OriginalToken = $ApiToken
    
    # Clean token and account ID
    $AccountId = $AccountId.Trim("'").Trim('"')
    $TunnelId = $TunnelId.Trim("'").Trim('"')
    $ApiToken = $ApiToken.Trim("'").Trim('"')
    $ApiToken = $ApiToken -replace '[^\x20-\x7E]', ''

    Write-Host "Testing Cloudflare API token..." -ForegroundColor Cyan
    Debug-ApiToken -Token $ApiToken
    
    # Create Auth headers
    $headers = @{
        "Authorization" = "Bearer $ApiToken"
        "Content-Type" = "application/json"
    }
    
    # This script checks the tunnel directly without requiring account-level read permissions.
    # The API token only needs 'Account > Zero Trust > Read' permissions for the specific account.
    $tunnelUri = "https://api.cloudflare.com/client/v4/accounts/${AccountId}/cfd_tunnel/${TunnelId}"
    Write-Host "Checking access to tunnel: $tunnelUri" -ForegroundColor Cyan
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-RestMethod -Uri $tunnelUri -Headers $headers -Method Get -UseBasicParsing
        
        Write-Host "SUCCESS: Token has access to tunnel $TunnelId" -ForegroundColor Green
        Write-Host "Tunnel Name: $($response.result.name)" -ForegroundColor Green
        Write-Host "Tunnel Status: $($response.result.status)" -ForegroundColor Green
        
        # Store successful method
        $script:SuccessfulAuthMethod = @{
            Name = "API Token with Bearer"
            Headers = $headers
        }
        
        return $true
    } 
    catch {
        $errorMessage = $_.Exception.Message
        Write-Host "FAILED to access tunnel: $errorMessage" -ForegroundColor Red
        
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Error details: $errorBody" -ForegroundColor Red
        }
        
        Write-Host "`nLikely issue: Token doesn't have permissions for this tunnel or the tunnel doesn't exist" -ForegroundColor Yellow
        return $false
    }
}

# Function to check Cloudflare tunnel status
function Get-CloudflareTunnelStatus {
    param (
        [string]$TunnelId,
        [string]$AccountId,
        [string]$ApiToken
    )

    # Remove any quotes from the parameters
    $TunnelId = $TunnelId.Trim("'").Trim('"')
    $AccountId = $AccountId.Trim("'").Trim('"')
    $ApiToken = $ApiToken.Trim("'").Trim('"')

    # Ensure there are no hidden characters or issues with encoding
    $ApiToken = $ApiToken -replace '[^\x20-\x7E]', ''
    
    # Use the authentication method that worked in the token test
    if ($script:SuccessfulAuthMethod) {
        $headers = $script:SuccessfulAuthMethod.Headers
    } else {
        # Fallback to Bearer token if no successful method was found
        $headers = @{
            "Authorization" = "Bearer $ApiToken"
            "Content-Type" = "application/json"
        }
    }

    try {
        Write-Host "Making request to Cloudflare API..." -ForegroundColor Cyan
        Write-Host "Account ID: $AccountId" -ForegroundColor Cyan
        Write-Host "Tunnel ID: $TunnelId" -ForegroundColor Cyan
        
        $uri = "https://api.cloudflare.com/client/v4/accounts/${AccountId}/cfd_tunnel/${TunnelId}"
        Write-Host "Request URI: $uri" -ForegroundColor Cyan
        Write-Host "Using authentication method: $($script:SuccessfulAuthMethod.Name)" -ForegroundColor Cyan
        
        # Try with TLS 1.2 explicitly
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -UseBasicParsing
        
        # Debug response
        Write-Host "Response received:" -ForegroundColor Green
        $response | ConvertTo-Json | Write-Host
        
        if ($response.success -eq $false) {
            Write-Host "Cloudflare API returned error:" -ForegroundColor Red
            $response.errors | ConvertTo-Json | Write-Host -ForegroundColor Red
            return "Error"
        }
        
        $status = $response.result.status
        
        if ($status -eq "healthy") {
            return "healthy"
        }
        elseif ($status -eq "null" -or $status -eq "error") {
            Write-Host "Error checking tunnel status" -ForegroundColor Red
            return "Error"
        }
        elseif ($status -eq "inactive") {
            Write-Host "Tunnel is inactive (waiting for activation)..." -ForegroundColor Yellow
            return "waiting"
        }
        else {
            Write-Host "Tunnel status: $status" -ForegroundColor Yellow
            return "waiting"
        }
    }
    catch {
        Write-Host "Error checking tunnel status: $_" -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Red
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Response body: $errorBody" -ForegroundColor Red
        }
        return "Error"
    }
}

# Script execution starts here
$script:TokenType = "Unknown"
$script:SuccessfulAuthMethod = $null

# Check for tunnel status
Write-Host "Checking tunnel health..." -ForegroundColor Cyan
$maxAttempts = 30
$attempt = 0
$sleepTime = 20

# First, validate that the API token works with this specific tunnel
if (-not (Test-CloudflareToken -AccountId $CloudflareAccountId -ApiToken $CloudflareApiToken -TunnelId $TunnelID)) {
    Write-Host "`nToken issues detected. Here's what to do:" -ForegroundColor Red
    Write-Host "1. Go to Cloudflare Dashboard > Account Profile > API Tokens" -ForegroundColor Yellow
    Write-Host "2. Create a new API token with these permissions:" -ForegroundColor Yellow
    Write-Host "   - Account > Zero Trust > Read" -ForegroundColor Yellow
    Write-Host "3. Make sure the token has access to the specific account ID" -ForegroundColor Yellow
    Write-Host "4. Try running this script again with the new token" -ForegroundColor Yellow
    
    if ($script:TokenType -eq "GlobalAPIKey") {
        Write-Host "`nYou seem to be using a Global API Key - API Tokens are recommended instead" -ForegroundColor Cyan
    }
    
    exit 1
}

while ($attempt -lt $maxAttempts) {
    $attempt++
    
    # Check tunnel status
    $tunnelStatus = Get-CloudflareTunnelStatus -TunnelId $TunnelID -AccountId $CloudflareAccountId -ApiToken $CloudflareApiToken
    
    if ($tunnelStatus -eq "healthy") {
        Write-Host "Tunnel is healthy!" -ForegroundColor Green
        exit 0
    }
    elseif ($tunnelStatus -eq "Error") {
        Write-Host "Error checking tunnel status" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Waiting for tunnel to be healthy (attempt $attempt/$maxAttempts)..." -ForegroundColor Yellow
    Start-Sleep -Seconds $sleepTime
}

Write-Host "Timeout waiting for tunnel to be healthy" -ForegroundColor Red
Write-Host "Total wait time: $($maxAttempts * $sleepTime) seconds" -ForegroundColor Red
exit 1 