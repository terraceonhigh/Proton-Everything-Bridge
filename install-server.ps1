#Requires -Version 5.1
<#
.SYNOPSIS
    Proton DAV Server - Guided installer for Windows (Docker Desktop)
.DESCRIPTION
    Mirrors install-server.sh for Windows 10 25H2+ with Docker Desktop (WSL2 backend).
    Sets up the shared infrastructure (Caddy + dashboard).
    Account management is done via the web dashboard after install.
.PARAMETER Status
    Check server and container status.
.PARAMETER Uninstall
    Stop and remove all containers and volumes.
.EXAMPLE
    .\install-server.ps1
    .\install-server.ps1 -Status
    .\install-server.ps1 -Uninstall
.NOTES
    install-server.sh is the source of truth for the installer logic.
    This PowerShell port mirrors it for Windows. When changing installer
    behavior, update install-server.sh first, then port changes here.

    If blocked by execution policy, run once:
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
#>
[CmdletBinding()]
param(
    [switch]$Status,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$ComposeFile = "docker-compose.caddy.yml"

# -- Helpers ----------------------------------------------------------------

function Write-Info  { param([string]$Msg) Write-Host "  >>  $Msg" -ForegroundColor Blue }
function Write-Ok    { param([string]$Msg) Write-Host "  [OK]  $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "  [!]  $Msg" -ForegroundColor Yellow }
function Write-Step  { param([string]$Msg) Write-Host "`n==  $Msg" -ForegroundColor White }
function Write-Err {
    param([string]$Msg)
    Write-Host "`n  [X]  ERROR: $Msg`n" -ForegroundColor Red
    exit 1
}

function Test-DockerReady {
    try {
        $null = docker info 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-DockerComposeReady {
    try {
        $null = docker compose version 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# -- Status Mode ------------------------------------------------------------

if ($Status) {
    Write-Host "`nProton DAV Server - status check`n" -ForegroundColor White

    $dockerExists = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerExists) {
        Write-Ok "docker found at $($dockerExists.Source)"
    } else {
        Write-Host "  [X]  docker not found" -ForegroundColor Red
    }

    if (Test-DockerComposeReady) {
        Write-Ok "docker compose available"
    } else {
        Write-Host "  [X]  docker compose not available" -ForegroundColor Red
    }

    Write-Host ""
    if ($dockerExists) {
        Write-Host "  Shared infrastructure:" -ForegroundColor White
        Push-Location $ScriptDir
        docker compose -f $ComposeFile ps 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warn "Not running" }
        Pop-Location

        Write-Host "`n  User stacks:" -ForegroundColor White
        $projects = docker compose ls --format json 2>$null | ConvertFrom-Json
        $userProjects = $projects | Where-Object { $_.Name -like 'user-*' }
        if ($userProjects) {
            $userProjects | ForEach-Object { Write-Host "    $($_.Name)  $($_.Status)" }
        } else {
            Write-Info "No user stacks found"
        }
    }
    Write-Host ""
    exit 0
}

# -- Uninstall Mode ---------------------------------------------------------

if ($Uninstall) {
    Write-Host "`nProton DAV Server - uninstall`n" -ForegroundColor White
    Push-Location $ScriptDir

    # Stop user stacks
    try {
        $projects = docker compose ls --format json 2>$null | ConvertFrom-Json
        $projects | Where-Object { $_.Name -like 'user-*' } | ForEach-Object {
            Write-Info "Stopping user stack: $($_.Name)"
            docker compose -p $_.Name -f docker-compose.user.yml down 2>$null
        }
    } catch {}

    Write-Info "Stopping shared infrastructure..."
    docker compose -f $ComposeFile down 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Ok "Infrastructure stopped" } else { Write-Warn "Not running" }

    docker network rm proton-shared 2>$null

    Write-Host ""
    $response = Read-Host "  Remove all data volumes (credentials, caches)? [y/N]"
    if ($response -match '^[Yy]$') {
        try {
            $projects = docker compose ls --format json 2>$null | ConvertFrom-Json
            $projects | Where-Object { $_.Name -like 'user-*' } | ForEach-Object {
                docker compose -p $_.Name -f docker-compose.user.yml down -v 2>$null
            }
        } catch {}
        docker compose -f $ComposeFile down -v 2>$null
        Write-Ok "Volumes removed"
    } else {
        Write-Info "Volumes preserved."
    }

    Pop-Location
    Write-Host "`n  Done.`n" -ForegroundColor Green
    exit 0
}

# -- Full Install -----------------------------------------------------------

Clear-Host
Write-Host @"

  ============================================================
       Proton DAV Server  -  Guided Setup (Windows)
  ============================================================

  This script will:
    1.  Install Docker Desktop (if needed)
    2.  Configure access control (localhost/LAN/whitelist/internet)
    3.  Set up authentication credentials
    4.  Build and start the server

  After setup, open the dashboard to add your Proton accounts.

  Platform: Windows $([System.Environment]::OSVersion.Version)

"@

# -- Step 1: Docker ---------------------------------------------------------

Write-Step "Step 1 / 4 - Installing Docker"

if ((Test-DockerReady) -and (Test-DockerComposeReady)) {
    Write-Ok "Docker and Docker Compose already installed"
} else {
    $wingetExists = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetExists) {
        Write-Err "winget not found. Install Docker Desktop manually from https://docker.com/products/docker-desktop"
    }

    Write-Info "Installing Docker Desktop via winget..."
    winget install Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Docker Desktop installation failed. Install manually from https://docker.com/products/docker-desktop"
    }

    Write-Ok "Docker Desktop installed"
    Write-Warn "Please open Docker Desktop from the Start Menu and wait for it to start."
    Write-Host ""

    $retries = 0
    while ($retries -lt 5) {
        Read-Host "  Press Enter once Docker Desktop shows 'Engine running'"
        if (Test-DockerReady) {
            Write-Ok "Docker is running"
            break
        }
        $retries++
        if ($retries -lt 5) {
            Write-Warn "Docker not ready yet. Make sure Docker Desktop is open and fully started."
            # Check for WSL2 issue
            $wslCheck = wsl --status 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "WSL2 may not be enabled. Docker Desktop requires WSL2."
                Write-Warn "If prompted, enable WSL2 and restart your computer, then re-run this script."
            }
        } else {
            Write-Err "Docker failed to start after multiple attempts. Please start Docker Desktop and re-run this script."
        }
    }
}

# -- Step 2: Access Control -------------------------------------------------

Write-Step "Step 2 / 4 - Configuring access control"

Write-Host @"

  Who should be able to connect to this server?

    1) localhost  - Only this machine (safest)
    2) lan        - Devices on your local network
    3) whitelist  - Specific IP addresses you choose
    4) internet   - Anyone on the internet (requires a domain)

"@

$AccessChoice = Read-Host "  Choose [1-4, default 1]"
if ([string]::IsNullOrWhiteSpace($AccessChoice)) { $AccessChoice = "1" }

$Domain = "localhost"

switch ($AccessChoice) {
    "2" {
        $AccessMode = "lan"
        $AllowedRanges = "192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 fd00::/8"
        $BindAddress = "0.0.0.0"
        Write-Ok "Access mode: LAN (private networks only)"
    }
    "3" {
        $AccessMode = "whitelist"
        Write-Host ""
        $AllowedIps = Read-Host "  Enter allowed IPs/CIDRs (space-separated)"
        if ([string]::IsNullOrWhiteSpace($AllowedIps)) { Write-Err "No IPs provided." }
        $AllowedRanges = $AllowedIps
        $BindAddress = "0.0.0.0"
        Write-Ok "Access mode: whitelist ($AllowedIps)"
    }
    "4" {
        $AccessMode = "internet"
        $AllowedRanges = "0.0.0.0/0 ::/0"
        $BindAddress = "0.0.0.0"
        Write-Warn "Internet mode selected - anyone can reach your server."
        Write-Warn "Make sure you use a strong password and a real domain for TLS."
        Write-Host ""
        $Domain = Read-Host "  Enter your domain name (e.g., proton.example.com)"
        if ([string]::IsNullOrWhiteSpace($Domain)) { Write-Err "A domain is required for internet mode." }
        Write-Ok "Access mode: internet (domain: $Domain)"
    }
    default {
        $AccessMode = "localhost"
        $AllowedRanges = "127.0.0.1/32 ::1/128"
        $BindAddress = "127.0.0.1"
        Write-Ok "Access mode: localhost (this machine only)"
    }
}

# -- Step 3: Authentication -------------------------------------------------

Write-Step "Step 3 / 4 - Setting up authentication"

Write-Host "`n  These credentials protect the dashboard and all service endpoints.`n"

$AuthUser = Read-Host "  Choose a username [default: proton]"
if ([string]::IsNullOrWhiteSpace($AuthUser)) { $AuthUser = "proton" }

$AuthPass = $null
while ([string]::IsNullOrWhiteSpace($AuthPass)) {
    $SecurePass = Read-Host "  Choose a password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
    $AuthPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    if ([string]::IsNullOrWhiteSpace($AuthPass)) {
        Write-Warn "Password cannot be empty."
    }
}

Write-Info "Generating password hash..."
$AuthHash = $AuthPass | docker run --rm -i caddy:2-alpine caddy hash-password 2>$null
$AuthPass = $null
[GC]::Collect()

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($AuthHash)) {
    Write-Err "Failed to generate password hash. Is Docker running?"
}
Write-Ok "Credentials configured (user: $AuthUser)"

# -- Step 4: Write .env and start ------------------------------------------

Write-Step "Step 4 / 4 - Building and starting server"

Push-Location $ScriptDir

# Write .env with LF line endings and no BOM
$envContent = @"
# Generated by install-server.ps1 on $(Get-Date -Format o)
DOMAIN=$Domain
ACCESS_MODE=$AccessMode
ALLOWED_RANGES=$AllowedRanges
BIND_ADDRESS=$BindAddress
AUTH_USER=$AuthUser
AUTH_HASH=$AuthHash
"@
$envContent = $envContent -replace "`r`n", "`n"
$envPath = Join-Path $ScriptDir ".env"
[System.IO.File]::WriteAllText($envPath, $envContent, [System.Text.UTF8Encoding]::new($false))
Write-Ok ".env file written"

# Create shared network
docker network create proton-shared 2>$null
Write-Ok "Shared network ready"

# Build and start
Write-Info "Building containers (this may take a few minutes on first run)..."
docker compose -f $ComposeFile build 2>&1 | ForEach-Object { Write-Host "    $_" }
Write-Ok "Containers built"

Write-Info "Starting Caddy + dashboard..."
docker compose -f $ComposeFile up -d 2>&1 | ForEach-Object { Write-Host "    $_" }
Write-Ok "Server started"

Pop-Location

# -- Summary ----------------------------------------------------------------

Write-Host @"

  ============================================================
                       All done!
  ============================================================

  Your Proton DAV Server is running.

  Dashboard:   https://$Domain/
  Access:      $AccessMode
  Username:    $AuthUser

  Next step:
    Open https://$Domain/ in your browser.
    Click [+ Add Account] to add your first Proton account.

    The dashboard will guide you through bridge login and
    show you the endpoint URLs for your apps.

  Useful commands:
    Check status :  .\install-server.ps1 -Status
    View logs    :  docker compose -f $ComposeFile logs -f
    Restart      :  docker compose -f $ComposeFile restart
    Stop         :  docker compose -f $ComposeFile down
    Uninstall    :  .\install-server.ps1 -Uninstall

"@
