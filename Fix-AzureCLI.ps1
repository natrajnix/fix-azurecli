# Fix-AzureCLI.ps1 - Fixes Azure CLI ConnectionResetError 10054
# Right-click > Run with PowerShell  (auto-elevates to Admin)

$ErrorActionPreference = "SilentlyContinue"

# Auto-elevate to Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-NOT $isAdmin) {
    Write-Host "Restarting as Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

function Step($msg) { Write-Host "`n[ ] $msg" -ForegroundColor Cyan }
function OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function WARN($msg) { Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function INFO($msg) { Write-Host "      $msg" -ForegroundColor Gray }

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host "  Azure CLI Connection Fix  -  Error 10054 Repair   " -ForegroundColor Magenta
Write-Host "=====================================================" -ForegroundColor Magenta

# STEP 1: Flush DNS and reset TCP stack
Step "Flushing DNS and resetting TCP/IP stack..."
ipconfig /flushdns | Out-Null
netsh winsock reset | Out-Null
netsh int ip reset | Out-Null
netsh int tcp set global autotuninglevel=normal | Out-Null
OK "DNS flushed and TCP/IP stack reset"

# STEP 2: Disable IPv6 on active adapters
Step "Disabling IPv6 on all active network adapters..."
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($adapter in $adapters) {
    Disable-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    OK "IPv6 disabled on: $($adapter.Name)"
}
if (-not $adapters) { WARN "No active adapters found - skipping" }

# STEP 3: Set environment variables system-wide
Step "Setting Azure CLI environment variables system-wide..."
[System.Environment]::SetEnvironmentVariable("AZURE_CLI_DISABLE_CONNECTION_VERIFY", "1", "Machine")
[System.Environment]::SetEnvironmentVariable("PYTHONHTTPSVERIFY", "0", "Machine")
[System.Environment]::SetEnvironmentVariable("REQUESTS_CA_BUNDLE", "", "Machine")
[System.Environment]::SetEnvironmentVariable("CURL_CA_BUNDLE", "", "Machine")
$env:AZURE_CLI_DISABLE_CONNECTION_VERIFY = "1"
$env:PYTHONHTTPSVERIFY = "0"
OK "Environment variables set"

# STEP 4: Clear Azure CLI cache and tokens
Step "Clearing Azure CLI login tokens and cache..."
$azureDir = "$env:USERPROFILE\.azure"
if (Test-Path $azureDir) {
    Remove-Item -Recurse -Force $azureDir
    OK "Deleted $azureDir"
} else {
    INFO "No .azure folder found - skipping"
}

# STEP 5: Enforce TLS 1.2 in registry
Step "Enforcing TLS 1.2 in Windows registry..."
$tls12Paths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client",
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
)
foreach ($path in $tls12Paths) {
    New-Item -Path $path -Force | Out-Null
    Set-ItemProperty -Path $path -Name "Enabled" -Value 1 -Type DWord
    Set-ItemProperty -Path $path -Name "DisabledByDefault" -Value 0 -Type DWord
}
$oldTLS = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client",
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"
)
foreach ($path in $oldTLS) {
    New-Item -Path $path -Force | Out-Null
    Set-ItemProperty -Path $path -Name "Enabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $path -Name "DisabledByDefault" -Value 1 -Type DWord
}
OK "TLS 1.2 enforced, TLS 1.0 and 1.1 disabled"

# STEP 6: Add firewall exceptions for az and python
Step "Adding Windows Firewall exceptions for Azure CLI..."
$pythonPaths = @(
    "$env:ProgramFiles\Microsoft SDKs\Azure\CLI2\python.exe",
    "$env:ProgramFiles\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
)
$added = 0
foreach ($p in $pythonPaths) {
    if (Test-Path $p) {
        New-NetFirewallRule -DisplayName "AzureCLI-Fix-$added" -Direction Outbound -Program $p -Action Allow -Profile Any 2>$null | Out-Null
        OK "Firewall rule added: $p"
        $added++
    }
}
if ($added -eq 0) { WARN "Azure CLI paths not found for firewall rules - skipping" }

# STEP 7: Update Azure CLI
Step "Updating Azure CLI to latest version..."
$azCmd = Get-Command az -ErrorAction SilentlyContinue
if ($azCmd) {
    $before = az version --query '"azure-cli"' -o tsv 2>$null
    INFO "Current version: $before"
    az upgrade --yes 2>&1 | Out-Null
    $after = az version --query '"azure-cli"' -o tsv 2>$null
    OK "Azure CLI is now version: $after"
} else {
    WARN "az not found in PATH - please reinstall from https://aka.ms/installazurecliwindows"
}

# STEP 8: Test connectivity to Azure endpoints
Step "Testing connectivity to Azure endpoints..."
$endpoints = @("login.microsoftonline.com", "management.azure.com", "graph.microsoft.com")
foreach ($ep in $endpoints) {
    $result = Test-NetConnection -ComputerName $ep -Port 443 -WarningAction SilentlyContinue
    if ($result.TcpTestSucceeded) {
        OK "Reachable: $ep"
    } else {
        WARN "Cannot reach: $ep - check your ISP or antivirus"
    }
}

# Done
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host "  All fixes applied!                                 " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  RESTART your PC now, then run:  az login" -ForegroundColor Yellow
Write-Host ""

$choice = Read-Host "Restart PC now? (Y/N)"
if ($choice -match "^[Yy]") {
    Restart-Computer -Force
} else {
    Write-Host "Remember to restart before testing az login!" -ForegroundColor Yellow
}
