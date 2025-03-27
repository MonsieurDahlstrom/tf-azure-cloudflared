param(
    [Parameter(Mandatory=$true)]
    [string]$TunnelID,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$true)]
    [string]$CloudflareAccountId,

    [Parameter(Mandatory=$true)]
    [string]$CloudflareApiToken
)

# Check if required parameters are provided
if ([string]::IsNullOrEmpty($TunnelID) -or [string]::IsNullOrEmpty($ResourceGroup) -or [string]::IsNullOrEmpty($VMName) -or 
    [string]::IsNullOrEmpty($CloudflareAccountId) -or [string]::IsNullOrEmpty($CloudflareApiToken)) {
    Write-Error "Error: Missing required parameters"
    Write-Host "Usage: $PSCommandPath -TunnelID <tunnel_id> -ResourceGroup <resource_group> -VMName <vm_name> -CloudflareAccountId <account_id> -CloudflareApiToken <api_token>"
    exit 1
}

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Error: Azure CLI is not installed"
    exit 1
}

# Function to validate Cloudflare API token
function Test-CloudflareToken {
    param (
        [string]$AccountId,
        [string]$ApiToken
    )

    # Remove any quotes and normalize
    $AccountId = $AccountId.Trim("'").Trim('"')
    $ApiToken = $ApiToken.Trim("'").Trim('"')
    $ApiToken = $ApiToken -replace '[^\x20-\x7E]', ''

    Write-Host "Testing Cloudflare API token..."
    
    $headers = @{
        "Authorization" = "Bearer $ApiToken"
        "Content-Type" = "application/json"
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Use a simple endpoint like account verification
        $uri = "https://api.cloudflare.com/client/v4/accounts/$AccountId"
        Write-Host "Sending test request to: $uri"
        
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -UseBasicParsing
        
        if ($response.success -eq $true) {
            Write-Host "API token is valid!"
            return $true
        } else {
            Write-Host "API token validation failed:"
            $response.errors | ConvertTo-Json | Write-Host
            return $false
        }
    }
    catch {
        Write-Host "Error validating API token: $_"
        Write-Host "Error details:"
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Response body: $errorBody"
        }
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

    # Debug token length (without showing the actual token)
    Write-Host "API Token length: $($ApiToken.Length)"
    Write-Host "First 4 characters of token: $($ApiToken.Substring(0, 4))..."
    
    # Ensure there are no hidden characters or issues with encoding
    $ApiToken = $ApiToken -replace '[^\x20-\x7E]', ''
    
    $headers = @{
        "Authorization" = "Bearer $ApiToken"
        "Content-Type" = "application/json"
    }

    try {
        Write-Host "Making request to Cloudflare API..."
        Write-Host "Account ID: $AccountId"
        Write-Host "Tunnel ID: $TunnelId"
        
        $uri = "https://api.cloudflare.com/client/v4/accounts/${AccountId}/cfd_tunnel/${TunnelId}"
        Write-Host "Request URI: $uri"
        
        # Debug headers (without showing the actual token)
        Write-Host "Request headers:"
        $headers.GetEnumerator() | ForEach-Object {
            if ($_.Key -eq "Authorization") {
                Write-Host "  $($_.Key): Bearer [REDACTED]"
            } else {
                Write-Host "  $($_.Key): $($_.Value)"
            }
        }
        
        # Try with TLS 1.2 explicitly
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -UseBasicParsing
        
        # Debug response
        Write-Host "Response received:"
        $response | ConvertTo-Json | Write-Host
        
        if ($response.success -eq $false) {
            Write-Host "Cloudflare API returned error:"
            $response.errors | ConvertTo-Json | Write-Host
            return "Error"
        }
        
        $status = $response.result.status
        
        if ($status -eq "healthy") {
            return "healthy"
        }
        elseif ($status -eq "null" -or $status -eq "error") {
            Write-Host "Error checking tunnel status"
            return "Error"
        }
        elseif ($status -eq "inactive") {
            Write-Host "Tunnel is inactive (waiting for activation)..."
            return "waiting"
        }
        else {
            Write-Host "Tunnel status: $status"
            return "waiting"
        }
    }
    catch {
        Write-Host "Error checking tunnel status: $_"
        Write-Host "Error details:"
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Response body: $errorBody"
        }
        return "Error"
    }
}

# Check for tunnel status
Write-Host "Checking tunnel health..."
$maxAttempts = 30
$attempt = 0
$sleepTime = 20

# First, validate that the API token works
if (-not (Test-CloudflareToken -AccountId $CloudflareAccountId -ApiToken $CloudflareApiToken)) {
    Write-Host "Failed to validate Cloudflare API token. Please check your credentials."
    exit 1
}

while ($attempt -lt $maxAttempts) {
    $attempt++
    
    # Check tunnel status
    $tunnelStatus = Get-CloudflareTunnelStatus -TunnelId $TunnelID -AccountId $CloudflareAccountId -ApiToken $CloudflareApiToken
    
    if ($tunnelStatus -eq "healthy") {
        Write-Host "Tunnel is healthy!"
        exit 0
    }
    elseif ($tunnelStatus -eq "Error") {
        Write-Host "Error checking tunnel status"
        exit 1
    }
    
    Write-Host "Waiting for tunnel to be healthy (attempt $attempt/$maxAttempts)..."
    Start-Sleep -Seconds $sleepTime
}

Write-Host "Timeout waiting for tunnel to be healthy"
Write-Host "Total wait time: $($maxAttempts * $sleepTime) seconds"
exit 1 