# apply-foundrymtr-redesign.ps1  (v3 - deterministic)
# -----------------------------------------------------------------------------
# Older, non-verifying variant of deploy-foundrymtr-redesign.ps1. Prefer the
# deploy script (it self-verifies with PASS/FAIL checks); keep this one for
# targeted re-application with an explicit -BuildDir.
#
# What it does:
#   1. Comments out the upstream inline base64 body background in app.ejs so
#      the FoundryMTR background actually shows (inline styles beat our sheet).
#   2. Ensures the foundrymtr-theme.css link uses ./assets/ and injects Google
#      Font <link> tags (CSP blocks CSS @import).
#   3. Copies assets, ensures brand+newspaper HTML in landing.ejs, adds news js.
#   4. Fixes the window title.
#
# Safe to re-run. Resolves the launcher relative to the repo layout; pass
# -BuildDir only to target a different tree. Pure ASCII file.
# -----------------------------------------------------------------------------

param([string]$BuildDir = "")

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
if (-not $here) { $here = (Get-Location).Path }
$repo     = Split-Path $here -Parent
$branding = Join-Path $repo "branding"

if ($BuildDir -eq "") {
    $BuildDir = Join-Path $repo "launcher"
}
if (-not (Test-Path -LiteralPath $BuildDir)) {
    Write-Host "ERROR: Could not find the launcher folder. Pass -BuildDir <path>." -ForegroundColor Red
    exit 1
}
Write-Host "Build dir: $BuildDir" -ForegroundColor Cyan

$appDir = Join-Path $BuildDir "app"
$assetsDir = Join-Path $appDir "assets"
$cssDir = Join-Path $assetsDir "css"
$jsDir  = Join-Path $assetsDir "js"
$bgDir  = Join-Path $assetsDir "images\backgrounds"

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

# --- 1. Copy assets ---
Write-Host ">> Copying assets..." -ForegroundColor Cyan
foreach ($pair in @(
    @{src="foundrymtr-theme.css";   dst=(Join-Path $cssDir "foundrymtr-theme.css")},
    @{src="foundrymtr-news.js";     dst=(Join-Path $jsDir "foundrymtr-news.js")},
    @{src="foundrymtr_station.jpg"; dst=(Join-Path $bgDir "foundrymtr_station.jpg")}
)) {
    $s = Join-Path $branding $pair.src
    if (-not (Test-Path $s)) { Write-Host "ERROR: missing $($pair.src) in $branding" -ForegroundColor Red; exit 1 }
    $dstDir = Split-Path $pair.dst -Parent
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    Copy-Item $s $pair.dst -Force
}
Write-Host "   [OK] Assets copied" -ForegroundColor Green

# --- 2. Patch app.ejs: neutralize inline background, fix CSS link, add fonts ---
Write-Host ">> Patching app.ejs (background + CSS link + fonts)..." -ForegroundColor Cyan
$appEjs = Join-Path $appDir "app.ejs"
$c = Read-Text $appEjs

# 2a. Comment out the upstream inline base64 background-image line so ours wins.
if ($c -match "background-image:\s*url\('data:image/jpeg;base64") {
    $c = [System.Text.RegularExpressions.Regex]::Replace(
        $c,
        "background-image:\s*url\('data:image/jpeg;base64,[^']*'\);",
        "/* FoundryMTR: inline background disabled */",
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    Write-Host "   [OK] Neutralized upstream inline base64 background" -ForegroundColor Green
} else {
    Write-Host "   [..] No inline base64 background found (may already be patched)" -ForegroundColor DarkGray
}

# 2b. Fix the theme href to ./assets/ and ensure it loads last in head.
$c = [System.Text.RegularExpressions.Regex]::Replace($c, "\s*<link[^>]*foundrymtr-theme\.css[^>]*>", "")
$c = [System.Text.RegularExpressions.Regex]::Replace($c, "\s*<link[^>]*fonts\.googleapis\.com[^>]*>", "")
$c = [System.Text.RegularExpressions.Regex]::Replace($c, "\s*<link[^>]*fonts\.gstatic\.com[^>]*>", "")

$inject = @'
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Oswald:wght@400;500;600;700&family=Spectral:ital,wght@0,400;0,500;0,600;1,400&family=Archivo+Black&display=swap">
    <link type="text/css" rel="stylesheet" href="./assets/css/foundrymtr-theme.css">
'@

# Insert right before </head> so it loads AFTER the upstream inline <style>.
$headClose = "<" + "/head>"
if ($c.Contains($headClose)) {
    $c = $c.Replace($headClose, $inject + "`n" + $headClose)
    Write-Host "   [OK] CSS + font links injected before </head>" -ForegroundColor Green
} else {
    Write-Host "   [!!] </head> not found in app.ejs!" -ForegroundColor Yellow
}
Write-Text $appEjs $c

# --- 3. Ensure brand + newspaper HTML + news js in landing.ejs ---
Write-Host ">> Checking landing.ejs..." -ForegroundColor Cyan
$landingPath = Join-Path $appDir "landing.ejs"
$landing = Read-Text $landingPath

$brandHtml = @'
<!-- FOUNDRYMTR REDESIGN START -->
<div id="fmtrBrand">
    <p id="fmtrBrandTitle">FOUNDRY<span class="fmtr-accent">MTR</span></p>
    <p id="fmtrBrandSub">Your journey starts here</p>
</div>
<div id="fmtrNewsTab"><span class="tab-dot"></span>The Dispatch</div>
<div id="fmtrNews">
    <button id="fmtrNewsClose">&times;</button>
    <div id="fmtrNewsMast">
        <p class="mast-title">The Dispatch</p>
        <div class="mast-rule"><span>FOUNDRYMTR</span><span id="fmtrNewsDate"></span><span>SURVIVAL</span></div>
    </div>
    <div id="fmtrNewsBody"><div id="fmtrNewsLoading">Setting the press...</div></div>
</div>
<!-- FOUNDRYMTR REDESIGN END -->
'@

if ($landing -notmatch 'FOUNDRYMTR REDESIGN START') {
    if ($landing -match '(<div id="landingContainer"[^>]*>)') {
        $landing = $landing -replace '(<div id="landingContainer"[^>]*>)', ("`$1`n" + $brandHtml)
        Write-Host "   [OK] Brand + newspaper injected" -ForegroundColor Green
    } else {
        $landing = $brandHtml + "`n" + $landing
        Write-Host "   [!!] landingContainer not found; prepended" -ForegroundColor Yellow
    }
} else {
    Write-Host "   [OK] Brand + newspaper already present" -ForegroundColor Green
}

if ($landing -notmatch 'foundrymtr-news\.js') {
    $landing = $landing.TrimEnd() + "`n" + '<script src="./assets/js/foundrymtr-news.js"></script>' + "`n"
    Write-Host "   [OK] news js script tag added" -ForegroundColor Green
} else {
    Write-Host "   [OK] news js already linked" -ForegroundColor Green
}
Write-Text $landingPath $landing

# --- 4. Window title ---
Write-Host ">> Fixing window title..." -ForegroundColor Cyan
$rootIndex = Join-Path $BuildDir "index.js"
if (Test-Path $rootIndex) {
    $j = Read-Text $rootIndex
    $j2 = $j -replace "title:\s*['`"][^'`"]*['`"]", "title: 'FoundryMTR Launcher'"
    if ($j2 -ne $j) { Write-Text $rootIndex $j2; Write-Host "   [OK] index.js title patched" -ForegroundColor Green }
    else { Write-Host "   [..] no title field matched in index.js (title comes from _custom.toml)" -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host "DONE. Prefer scripts\deploy-foundrymtr-redesign.ps1 (self-verifying) for the standard workflow." -ForegroundColor Green
