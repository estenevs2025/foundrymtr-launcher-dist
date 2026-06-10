# FoundryMTR Branding — Where Every File Goes

After cloning your Helios fork (per REBRANDING-GUIDE.md), drop these files
in their target locations. Paths are relative to the repo root.

═══════════════════════════════════════════════════════════════════════════════
LOGO AND ICON ASSETS
═══════════════════════════════════════════════════════════════════════════════

From this branding package          →   In your Helios fork
─────────────────────────────────       ──────────────────────────────────────
png/logo_320x320.png                →   app/assets/images/logo_320x320.png
png/SealCircle.png                  →   app/assets/images/SealCircle.png
png/wordmark.png                    →   app/assets/images/wordmark.png  (new)
png/icon_1024.png                   →   build/icon.png  (Linux app icon)

For the Windows .ico (multi-resolution icon), you need to combine multiple
PNG sizes into one .ico file. Use this command on your machine after
installing ImageMagick:

  magick png/icon_16.png png/icon_32.png png/icon_48.png png/icon_64.png \
         png/icon_128.png png/icon_256.png build/icon.ico

For the macOS .icns:

  Use https://cloudconvert.com/png-to-icns (upload icon_1024.png), OR
  if you're on a Mac: use iconutil with an .iconset folder.

═══════════════════════════════════════════════════════════════════════════════
CSS THEME
═══════════════════════════════════════════════════════════════════════════════

From                                →   In your Helios fork
─────────────────────────────────       ──────────────────────────────────────
css/foundrymtr-theme.css                   →   app/assets/css/foundrymtr-theme.css

Then add this <link> tag to every .ejs file that already includes launcher.css,
immediately AFTER the existing launcher.css link. Files to update:

  app/landing.ejs
  app/login.ejs
  app/welcome.ejs
  app/settings.ejs
  app/overlay.ejs

Add this line (after the existing CSS <link>):

  <link rel="stylesheet" href="assets/css/foundrymtr-theme.css">

═══════════════════════════════════════════════════════════════════════════════
HTML MOCKUP (REFERENCE ONLY)
═══════════════════════════════════════════════════════════════════════════════

html/mockup.html is NOT part of the launcher. It's a standalone visual preview
so you can see what the design looks like in a browser before doing the
Helios integration. Open it in any browser to see the target aesthetic.

═══════════════════════════════════════════════════════════════════════════════
COPY DECK — STRING REPLACEMENTS
═══════════════════════════════════════════════════════════════════════════════

In addition to the upstream-name  "FoundryMTR" renames per docs/REBRAND_TO_FOUNDRYMTR.md,
update these specific strings in app/assets/lang/en_US.toml (and optionally
_custom.toml) for the transit-board voice:

  Default Helios string                  Replace with
  ──────────────────────────────         ────────────────────────────────
  "Play"                                  "BOARD TRAIN"
  "Launch"                                "DEPART"
  "Joining server..."                     "CONNECTING TO NETWORK"
  "Logging in..."                         "AUTHENTICATING"
  "Server is offline"                     "NETWORK OFFLINE"
  "Server is online"                      "ALL SYSTEMS NOMINAL"
  "Players online"                        "PASSENGERS ABOARD"
  "Welcome back!"                         "WELCOME, PASSENGER"
  "Sign in with Microsoft"                "AUTHENTICATE WITH MICROSOFT"
  "Loading mods..."                       "VERIFYING MANIFEST"
  "Validating files..."                   "PRE-DEPARTURE CHECKS"

You can do all of these in one sitting with VS Code's Find & Replace
(Ctrl+Shift+H) — make sure to search across the whole `app/assets/lang/`
directory.

═══════════════════════════════════════════════════════════════════════════════
BACKGROUND IMAGES
═══════════════════════════════════════════════════════════════════════════════

Helios ships with backgrounds in app/assets/images/backgrounds/. Replace these
with FoundryMTR-themed screenshots. Ideal source images:

  • In-game screenshots of major FoundryMTR stations (Kingsbridge Crossing!)
  • Wide platform shots with trains
  • Atmospheric tunnel views
  • Train cab POV shots

Each background should be:
  • 1920x1080 minimum (2560x1440 ideal for high-DPI displays)
  • JPEG format, ~80% quality (keep file size reasonable)
  • Slightly darkened in the lower half — the bottom is where the
    Helios UI overlays text. Apply a subtle gradient darken in any
    image editor.

Drop in at least 3-5 backgrounds so the launcher cycles through them.

═══════════════════════════════════════════════════════════════════════════════
IMAGES I CAN'T GENERATE FOR YOU
═══════════════════════════════════════════════════════════════════════════════

The following need to come from you (or a graphic designer if you'd rather
hire one). For each, I've noted what's needed:

  1. BACKGROUNDS (5+ images, 1920x1080)
     Screenshots from inside FoundryMTR. The current Helios default backgrounds
     are generic; replace them with your actual server's stations and
     trains. This is what makes the launcher feel personal.

  2. SERVER ICON (256x256 PNG, optional)
     Used on the server card. If not provided, the launcher uses the
     roundel. Can be a stylized version of your logo or a specific FoundryMTR
     station insignia.

  3. WINDOWS CODE SIGNING CERT (optional but recommended)
     Without one, users see "Windows protected your PC" on first launch.
     They click "More info" → "Run anyway" and it's fine, but it's a
     friction point. Cost: ~$200/year (Sectigo, DigiCert).

  4. DISCORD APP ICON ASSETS (if using Discord rich presence)
     Upload icon_512.png and icon_1024.png to your Discord application's
     "Art Assets" → "Rich Presence Assets" page. The asset KEY you give
     them goes in distribution.json (smallImageKey, largeImageKey).

═══════════════════════════════════════════════════════════════════════════════
QUICK QA AFTER INTEGRATION
═══════════════════════════════════════════════════════════════════════════════

Once you've dropped all files in and run `npm start`:

  □ The window title shows "FoundryMTR Launcher" (not "Helios Launcher")
  □ The taskbar icon is the red roundel
  □ Main screen background is dark (--fmtr-ink), not the Helios default
  □ The PLAY button is signal red with white sharp-cornered styling
  □ Hover states on buttons reverse the colors (red→white)
  □ Status indicators in the right panel are square, not round
  □ Server card has a 4px red left border
  □ Font is Inter (check by inspecting an element)

If any of these look wrong, the foundrymtr-theme.css <link> probably isn't being
loaded — verify the path is correct in the .ejs files.
