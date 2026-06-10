# build-windows.ps1 - FoundryMTR Launcher build driver (Windows)
# -----------------------------------------------------------------------------
# The launcher source is VENDORED at <repo>\launcher\ - this script no longer
# clones anything from upstream. It installs dependencies, enforces the
# canonical configuration (idempotent re-patch so drift cannot survive a
# build), deploys the FoundryMTR theme, then launches or packages.
#
# Switches:
#   -Clean           remove node_modules and dist before installing
#   -SkipInstall     skip npm install
#   -BuildInstaller  run `npm run dist:win` instead of `npm start`
#
# Canonical values: docs\REBRAND_TO_FOUNDRYMTR.md section 2. Pure ASCII file.
# -----------------------------------------------------------------------------

param(
    [switch]$Clean,
    [switch]$SkipInstall,
    [switch]$BuildInstaller
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
if (-not $here) { $here = (Get-Location).Path }
$repo     = Split-Path $here -Parent
$launcher = Join-Path $repo "launcher"
if (-not (Test-Path $launcher)) { Write-Host "ERROR: launcher folder not found at $launcher" -ForegroundColor Red; exit 1 }

# Canonical configuration - the single source of enforcement values.
$Config = @{
    AzureClientId   = "6809b695-eb71-43f8-8fa5-5e9c7d7b33de"
    DistributionUrl = "https://files.foundrymtr.com/helios/distribution.json"
    AppName         = "FoundryMTR Launcher"
    AppId           = "com.foundrymtr.launcher"
    Publisher       = "FoundryMC Services LLC"
    ServerName      = "FoundryMTR"
}

function Read-Text($p) {
    $b = [System.IO.File]::ReadAllBytes($p)
    $t = [System.Text.Encoding]::UTF8.GetString($b)
    if ($t.Length -gt 0 -and [int][char]$t[0] -eq 65279) { $t = $t.Substring(1) }
    return $t
}
function Write-Text($p, $c) {
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($p, $c, $enc)
}

Write-Host "=== FoundryMTR Launcher build ===" -ForegroundColor Cyan
Write-Host "Launcher: $launcher" -ForegroundColor DarkGray

# --- 1. Clean ---
if ($Clean) {
    Write-Host "`n>> Cleaning node_modules and dist..." -ForegroundColor Cyan
    foreach ($d in @("node_modules", "dist")) {
        $p = Join-Path $launcher $d
        if (Test-Path $p) { Remove-Item $p -Recurse -Force -Confirm:$false }
    }
}

# --- 2. Install ---
if (-not $SkipInstall) {
    Write-Host "`n>> Installing dependencies..." -ForegroundColor Cyan
    Push-Location $launcher
    try {
        if (Test-Path (Join-Path $launcher "package-lock.json")) { npm ci } else { npm install }
        if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
}

# --- 3. Enforce canonical configuration (idempotent) ---
Write-Host "`n>> Enforcing canonical configuration..." -ForegroundColor Cyan

# 3a. distromanager.js: REMOTE_DISTRO_URL must equal the canonical manifest URL.
$distro = Join-Path $launcher "app\assets\js\distromanager.js"
$d = Read-Text $distro
$d2 = [regex]::Replace($d, "exports\.REMOTE_DISTRO_URL\s*=\s*'[^']*'", ("exports.REMOTE_DISTRO_URL = '" + $Config.DistributionUrl + "'"))
if ($d2 -ne $d) { Write-Text $distro $d2; Write-Host "  [OK] distromanager.js distro URL enforced" -ForegroundColor Green }
else { Write-Host "  [OK] distromanager.js already canonical" -ForegroundColor Green }

# 3b. ipcconstants.js: AZURE_CLIENT_ID must equal the canonical id.
$ipc = Join-Path $launcher "app\assets\js\ipcconstants.js"
$i = Read-Text $ipc
$i2 = [regex]::Replace($i, "exports\.AZURE_CLIENT_ID\s*=\s*'[^']*'", ("exports.AZURE_CLIENT_ID = '" + $Config.AzureClientId + "'"))
if ($i2 -ne $i) { Write-Text $ipc $i2; Write-Host "  [OK] ipcconstants.js Azure client id enforced" -ForegroundColor Green }
else { Write-Host "  [OK] ipcconstants.js already canonical" -ForegroundColor Green }

# 3c. package.json + electron-builder.yml: verify (warn-only; source of truth is the repo).
$pkg = Read-Text (Join-Path $launcher "package.json")
if ($pkg -notmatch '"productName":\s*"FoundryMTR Launcher"') { Write-Host "  [WARN] package.json productName drifted from canon" -ForegroundColor Yellow }
$eb = Read-Text (Join-Path $launcher "electron-builder.yml")
if ($eb -notmatch [regex]::Escape($Config.AppId)) { Write-Host "  [WARN] electron-builder.yml appId drifted from canon" -ForegroundColor Yellow }

# --- 4. Deploy the FoundryMTR theme (self-verifying) ---
Write-Host "`n>> Deploying FoundryMTR theme..." -ForegroundColor Cyan
& (Join-Path $here "deploy-foundrymtr-redesign.ps1")

# --- 5. Launch or package ---
Push-Location $launcher
try {
    if ($BuildInstaller) {
        Write-Host "`n>> Building Windows installer (npm run dist:win)..." -ForegroundColor Cyan
        npm run dist:win
        if ($LASTEXITCODE -ne 0) { throw "electron-builder failed (exit $LASTEXITCODE)" }
        Write-Host "`nExpected output: dist\FoundryMTR-Setup-<version>.exe (+ .blockmap + latest.yml)" -ForegroundColor White
        Get-ChildItem (Join-Path $launcher "dist") -Filter "FoundryMTR-Setup-*" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ("  " + $_.Name) -ForegroundColor Green }
    } else {
        Write-Host "`n>> Launching (npm start)..." -ForegroundColor Cyan
        Write-Host "Window title should read: FoundryMTR Launcher V<version> (MC 1.21.4 - MTR-NG 4.1.0)" -ForegroundColor White
        npm start
    }
} finally { Pop-Location }
