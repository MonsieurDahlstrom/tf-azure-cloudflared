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

# Function to debug token issues (only used when CustomDebug is enabled)
function Debug-ApiToken {
    param (
        [string]$Token
    )
    
    if ($CustomDebug) {
        Write-Host "DEBUG: Token diagnostics:" -ForegroundColor Yellow
        Write-Host "  - Length: $($Token.Length)" -ForegroundColor Yellow
        Write-Host "  - First 4 chars: [REDACTED]..." -ForegroundColor Yellow
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
}

# Function to validate Cloudflare API token
function Test-CloudflareToken {
    param (
        [string]$AccountId,
        [string]$ApiToken,
        [string]$TunnelId = ""
    )

    # Clean token and account ID
    $AccountId = $AccountId.Trim("'").Trim('"')
    $TunnelId = $TunnelId.Trim("'").Trim('"')
    $ApiToken = $ApiToken.Trim("'").Trim('"')
    $ApiToken = $ApiToken -replace '[^\x20-\x7E]', ''

    if ($CustomDebug) {
        Write-Host "Testing Cloudflare API token..." -ForegroundColor Cyan
        Debug-ApiToken -Token $ApiToken
    }
    
    # Create Auth headers
    $headers = @{
        "Authorization" = "Bearer $ApiToken"
        "Content-Type" = "application/json"
    }
    
    # This script checks the tunnel directly without requiring account-level read permissions.
    $tunnelUri = "https://api.cloudflare.com/client/v4/accounts/[REDACTED_ACCOUNT]/cfd_tunnel/[REDACTED_TUNNEL]"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/${AccountId}/cfd_tunnel/${TunnelId}" -Headers $headers -Method Get -UseBasicParsing
        
        if ($CustomDebug) {
            Write-Host "SUCCESS: Token has access to tunnel [REDACTED_TUNNEL]" -ForegroundColor Green
            Write-Host "Tunnel Name: $($response.result.name)" -ForegroundColor Green
            Write-Host "Tunnel Status: $($response.result.status)" -ForegroundColor Green
        }
        
        # Store successful method
        $script:SuccessfulAuthMethod = @{
            Name = "API Token with Bearer"
            Headers = $headers
        }
        
        return $true
    } 
    catch {
        $errorMessage = $_.Exception.Message
        # Sanitize error message to remove potential token or sensitive information
        $sanitizedError = $errorMessage -replace '(eyJ|[A-Za-z0-9_-]{20,})', '[REDACTED]'
        Write-Error "Failed to access tunnel: $sanitizedError"
        
        if ($_.Exception.Response -and $CustomDebug) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            # Sanitize error body
            $sanitizedErrorBody = $errorBody -replace '(eyJ|[A-Za-z0-9_-]{20,})', '[REDACTED]'
            Write-Error "Error details: $sanitizedErrorBody"
        }
        
        Write-Error "Likely issue: Token doesn't have permissions for this tunnel or the tunnel doesn't exist"
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
        # Try with TLS 1.2 explicitly
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/${AccountId}/cfd_tunnel/${TunnelId}" -Headers $headers -Method Get -UseBasicParsing
        
        if ($response.success -eq $false) {
            if ($CustomDebug) {
                Write-Error "Cloudflare API returned error"
                # Sanitize errors
                $sanitizedErrors = ($response.errors | ConvertTo-Json) -replace '(eyJ|[A-Za-z0-9_-]{20,})', '[REDACTED]'
                Write-Error $sanitizedErrors
            }
            return "Error"
        }
        
        $status = $response.result.status
        
        if ($status -eq "healthy") {
            return "healthy"
        }
        elseif ($status -eq "null" -or $status -eq "error") {
            if ($CustomDebug) {
                Write-Error "Error checking tunnel status"
            }
            return "Error"
        }
        else {
            if ($CustomDebug) {
                Write-Host "Tunnel status: $status" -ForegroundColor Yellow
            }
            return "waiting"
        }
    }
    catch {
        # Sanitize error message
        $sanitizedError = $_.Exception.Message -replace '(eyJ|[A-Za-z0-9_-]{20,})', '[REDACTED]'
        Write-Error "Error checking tunnel status: $sanitizedError"
        
        if ($_.Exception.Response -and $CustomDebug) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            # Sanitize error body
            $sanitizedErrorBody = $errorBody -replace '(eyJ|[A-Za-z0-9_-]{20,})', '[REDACTED]'
            Write-Error "Response body: $sanitizedErrorBody"
        }
        return "Error"
    }
}

# Script execution starts here
$script:TokenType = "Unknown"
$script:SuccessfulAuthMethod = $null

$maxAttempts = 30
$attempt = 0
$sleepTime = 20

# First, validate that the API token works with this specific tunnel
if (-not (Test-CloudflareToken -AccountId $CloudflareAccountId -ApiToken $CloudflareApiToken -TunnelId $TunnelID)) {
    Write-Error "Token issues detected. Please create a new API token with 'Account > Zero Trust > Read' permissions."
    exit 1
}

while ($attempt -lt $maxAttempts) {
    $attempt++
    
    # Check tunnel status
    $tunnelStatus = Get-CloudflareTunnelStatus -TunnelId $TunnelID -AccountId $CloudflareAccountId -ApiToken $CloudflareApiToken
    
    if ($tunnelStatus -eq "healthy") {
        if ($CustomDebug) {
            Write-Host "Tunnel is healthy!" -ForegroundColor Green
        }
        exit 0
    }
    elseif ($tunnelStatus -eq "Error") {
        Write-Error "Error checking tunnel status"
        exit 1
    }
    
    if ($CustomDebug -or $attempt % 5 -eq 0) {
        Write-Host "Waiting for tunnel to be healthy (attempt $attempt/$maxAttempts)..." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds $sleepTime
}

Write-Error "Timeout waiting for tunnel to be healthy"
exit 1 