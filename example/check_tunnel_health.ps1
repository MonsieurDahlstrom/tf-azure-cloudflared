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

# Function to check Cloudflare tunnel status
function Get-CloudflareTunnelStatus {
    param (
        [string]$TunnelId,
        [string]$AccountId,
        [string]$ApiToken
    )

    $headers = @{
        "Authorization" = "Bearer $ApiToken"
        "Content-Type" = "application/json"
    }

    try {
        Write-Host "Making request to Cloudflare API..."
        Write-Host "Account ID: $AccountId"
        Write-Host "Tunnel ID: $TunnelId"
        
        $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$AccountId/cfd_tunnel/$TunnelId" -Headers $headers -Method Get
        
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
        $_.Exception.Response | ConvertTo-Json | Write-Host
        return "Error"
    }
}

# Check for tunnel status
Write-Host "Checking tunnel health..."
$maxAttempts = 30
$attempt = 0
$sleepTime = 20

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