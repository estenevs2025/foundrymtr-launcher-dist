# deploy-foundrymtr-redesign.ps1  (v4 - self-verifying)
# -----------------------------------------------------------------------------
# Deploys the FoundryMTR theme into the vendored launcher source. It copies the
# branding assets, patches templates, enforces the window title, then RE-READS
# every file and prints PASS/FAIL so a silent no-op is impossible.
#
# Lives in scripts\; resolves everything relative to the repo layout:
#   <repo>\scripts\   (this script)
#   <repo>\branding\  (asset sources: foundrymtr-theme.css, foundrymtr-news.js,
#                      foundrymtr_station.jpg)
#   <repo>\launcher\  (the Electron app)
# Canonical values: docs\REBRAND_TO_FOUNDRYMTR.md section 2. Pure ASCII file.
# -----------------------------------------------------------------------------

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
if (-not $here) { $here = (Get-Location).Path }

$repo     = Split-Path $here -Parent
$branding = Join-Path $repo "branding"
$build    = Join-Path $repo "launcher"
if (-not (Test-Path $build)) { Write-Host "ERROR: launcher folder not found at $build" -ForegroundColor Red; exit 1 }

$app    = Join-Path $build "app"
$cssDir = Join-Path $app "assets\css"
$jsDir  = Join-Path $app "assets\js"
$bgDir  = Join-Path $app "assets\images\backgrounds"

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
$script:pass = 0; $script:fail = 0
function Check($label, $cond) {
    if ($cond) { Write-Host ("  [PASS] " + $label) -ForegroundColor Green; $script:pass++ }
    else       { Write-Host ("  [FAIL] " + $label) -ForegroundColor Red;   $script:fail++ }
}

Write-Host "=== Deploying FoundryMTR redesign into launcher ===" -ForegroundColor Cyan
Write-Host "Launcher: $build" -ForegroundColor DarkGray

# --- 1. COPY ASSETS ---
Write-Host "`n>> Copying assets..." -ForegroundColor Cyan
foreach ($d in @($cssDir, $jsDir, $bgDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }

Copy-Item (Join-Path $branding "foundrymtr-theme.css")   (Join-Path $cssDir "foundrymtr-theme.css")   -Force
Copy-Item (Join-Path $branding "foundrymtr-news.js")     (Join-Path $jsDir  "foundrymtr-news.js")     -Force
Copy-Item (Join-Path $branding "foundrymtr_station.jpg") (Join-Path $bgDir  "foundrymtr_station.jpg") -Force

# Verify by re-reading
$cssBack = Read-Text (Join-Path $cssDir "foundrymtr-theme.css")
Check "foundrymtr-theme.css copied (theme header)" ($cssBack -match "STATION-BOARD SIGNAGE THEME")
$jsBack = Read-Text (Join-Path $jsDir "foundrymtr-news.js")
Check "foundrymtr-news.js copied (collapsible)"    ($jsBack -match "fmtrWireToggle")
Check "foundrymtr_station.jpg copied (>1KB)"       ((Get-Item (Join-Path $bgDir "foundrymtr_station.jpg")).Length -gt 1024)

# --- 2. PATCH app.ejs: kill inline bg, add css+font links, fix title ---
Write-Host "`n>> Patching app.ejs..." -ForegroundColor Cyan
$appEjs = Join-Path $app "app.ejs"
$c = Read-Text $appEjs

# 2a. neutralize the upstream inline base64 background (it beats external CSS)
$c = [regex]::Replace($c, "background-image:\s*url\('data:image/jpeg;base64,[^']*'\);", "/* FoundryMTR: inline bg disabled */")

# 2b. remove any prior theme/font links, then inject fresh before </head>
$c = [regex]::Replace($c, "\s*<link[^>]*foundrymtr-theme\.css[^>]*>", "")
$c = [regex]::Replace($c, "\s*<link[^>]*fonts\.(googleapis|gstatic)\.com[^>]*>", "")
$inject = @'
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Oswald:wght@400;500;600;700&family=Spectral:ital,wght@0,400;0,500;0,600;1,400&family=Archivo+Black&display=swap">
    <link type="text/css" rel="stylesheet" href="./assets/css/foundrymtr-theme.css">
'@
$headClose = "<" + "/head>"
$c = $c.Replace($headClose, $inject + "`n" + $headClose)

# 2c. force the <title> tag (handles <%= lang(...) %> or literal)
$c = [regex]::Replace($c, "<title>.*?</title>", "<title>FoundryMTR Launcher</title>")

Write-Text $appEjs $c

$cBack = Read-Text $appEjs
Check "app.ejs inline base64 bg removed"        (-not ($cBack -match "background-image:\s*url\('data:image/jpeg;base64"))
Check "app.ejs has foundrymtr-theme.css link"   ($cBack -match "foundrymtr-theme\.css")
Check "app.ejs has font link"                   ($cBack -match "fonts\.googleapis\.com")
Check "app.ejs title = FoundryMTR Launcher"     ($cBack -match "<title>FoundryMTR Launcher</title>")

# --- 3. PATCH landing.ejs: brand + collapsible Dispatch + news.js ---
Write-Host "`n>> Patching landing.ejs..." -ForegroundColor Cyan
$landing = Join-Path $app "landing.ejs"
$L = Read-Text $landing

# remove any prior block so we always inject the latest structure
$L = [regex]::Replace($L, "<!-- FOUNDRYMTR REDESIGN START -->.*?<!-- FOUNDRYMTR REDESIGN END -->", "", "Singleline")
$L = [regex]::Replace($L, "\s*<script[^>]*foundrymtr-news\.js[^>]*></script>", "")

$block = @'
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

if ($L -match '(<div id="landingContainer"[^>]*>)') {
    $L = $L -replace '(<div id="landingContainer"[^>]*>)', ("`$1`n" + $block)
} else {
    $L = $block + "`n" + $L
}
$L = $L.TrimEnd() + "`n" + '<script src="./assets/js/foundrymtr-news.js"></script>' + "`n"
Write-Text $landing $L

$LBack = Read-Text $landing
Check "landing.ejs has brand block"        ($LBack -match "fmtrBrandTitle")
Check "landing.ejs has Dispatch tab"       ($LBack -match "fmtrNewsTab")
Check "landing.ejs has news.js script tag" ($LBack -match "foundrymtr-news\.js")

# --- 4. STRIP upstream branding in frame.ejs (logo/seal) ---
Write-Host "`n>> Stripping upstream branding from frame.ejs..." -ForegroundColor Cyan
$frame = Join-Path $app "frame.ejs"
if (Test-Path $frame) {
    $F = Read-Text $frame
    # Comment out any seal/logo image element (best-effort, non-destructive)
    $F2 = [regex]::Replace($F, '(<img[^>]*(seal|logo)[^>]*>)', '<!-- FoundryMTR: $1 -->')
    if ($F2 -ne $F) { Write-Text $frame $F2; Write-Host "  [OK] frame.ejs logo/seal commented" -ForegroundColor Green }
    else { Write-Host "  [..] no seal/logo <img> found in frame.ejs (may live elsewhere)" -ForegroundColor DarkGray }
}

# --- 5. WINDOW TITLE in index.js / main process ---
Write-Host "`n>> Fixing window title in index.js..." -ForegroundColor Cyan
$idx = Join-Path $build "index.js"
if (Test-Path $idx) {
    $J = Read-Text $idx
    $J2 = $J -replace "title:\s*['`"][^'`"]*['`"]", "title: 'FoundryMTR Launcher'"
    if ($J2 -ne $J) { Write-Text $idx $J2; Write-Host "  [OK] index.js BrowserWindow title set" -ForegroundColor Green }
    else { Write-Host "  [..] no title field in index.js (the title comes from _custom.toml)" -ForegroundColor DarkGray }
}

# --- 6. Lang files: targeted title enforcement only ---
# NOTE: deliberately NOT a blanket title regex. _custom.toml [ejs.app] title is
# the real decorated window title (carries version info) and must not be
# clobbered; en_US.toml has many unrelated title keys. We only sweep stray
# upstream literals and verify the canonical strings are present.
Write-Host "`n>> Checking lang files..." -ForegroundColor Cyan
$langDir = Join-Path $app "assets\lang"
if (Test-Path $langDir) {
    Get-ChildItem $langDir -File | ForEach-Object {
        $T = Read-Text $_.FullName
        $T2 = $T -replace 'Helios Launcher', 'FoundryMTR Launcher'
        if ($T2 -ne $T) { Write-Text $_.FullName $T2; Write-Host ("  [OK] swept upstream literal in " + $_.Name) -ForegroundColor Green }
    }
    $stillUpstream = Get-ChildItem $langDir -File | ForEach-Object { Read-Text $_.FullName } | Select-String "Helios Launcher" -Quiet
    Check "no 'Helios Launcher' left in lang files" (-not $stillUpstream)
    $customTitle = Read-Text (Join-Path $langDir "_custom.toml")
    Check "_custom.toml title starts with FoundryMTR Launcher" ($customTitle -match '(?m)^title\s*=\s*"FoundryMTR Launcher')
}

# --- SUMMARY ---
Write-Host "`n=================================" -ForegroundColor Cyan
Write-Host ("RESULT: {0} passed, {1} failed" -f $script:pass, $script:fail) -ForegroundColor $(if ($script:fail -eq 0) { "Green" } else { "Red" })
Write-Host "=================================" -ForegroundColor Cyan
if ($script:fail -eq 0) {
    Write-Host "`nLaunch:" -ForegroundColor White
    Write-Host "  cd `"$build`"; npm start" -ForegroundColor White
} else {
    Write-Host "`nSome checks failed - paste this output and do NOT launch yet." -ForegroundColor Yellow
}
