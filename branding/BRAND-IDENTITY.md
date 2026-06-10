# FoundryMTR Launcher — Brand Identity

═══════════════════════════════════════════════════════════════════════════════
DESIGN DIRECTION
═══════════════════════════════════════════════════════════════════════════════

The FoundryMTR Launcher takes visual cues from real-world rapid transit systems —
specifically the design language of Transport for London, the NYC MTA, and
Tokyo Metro. The aesthetic is:

  • Infrastructural, not gamer-y
  • Confident high-contrast typography
  • Signal colors used as ACCENTS, never as fills
  • Geometric, ordered, slightly industrial
  • Dark backgrounds (the launcher runs while Minecraft loads — should feel
    like a control room, not a website)

The launcher should feel like the departure board at a station, not a video
game menu.


═══════════════════════════════════════════════════════════════════════════════
COLOR SYSTEM
═══════════════════════════════════════════════════════════════════════════════

PRIMARY PALETTE (use 95% of the time)
─────────────────────────────────────
  --fmtr-ink           #0A0E14    Deep ink black — primary background
  --fmtr-rail          #151B23    Slightly lighter, for cards/panels
  --fmtr-platform      #1F2730    Hover states, secondary panels
  --fmtr-chalk         #F2F4F7    Primary text on dark
  --fmtr-fog           #8B95A3    Secondary text, metadata

ACCENT COLORS (use sparingly — these are SIGNALS)
─────────────────────────────────────
  --fmtr-signal       #E8252B    Signal red — the FoundryMTR identity color
                                Used for: logo, primary CTA button,
                                          active server indicator
  --fmtr-amber        #F5A623    Warning/loading
  --fmtr-green        #00C896    Success, "connected", online status
  --fmtr-platinum     #C4CDD9    Borders, dividers, subtle UI

LINE COLORS (for future expansion — if you add multiple servers/networks)
─────────────────────────────────────
  Central Line       #E32017
  Piccadilly         #003688
  Victoria           #0098D4
  Jubilee            #A0A5A9
  Bakerloo           #B36305
  Northern           #000000


═══════════════════════════════════════════════════════════════════════════════
TYPOGRAPHY
═══════════════════════════════════════════════════════════════════════════════

The launcher uses ONE typeface family throughout: Inter (free, open source).
Inter is the closest free analogue to the proprietary transit faces (Johnston,
Helvetica Neue, etc.) and ships with a wide weight range.

DOWNLOAD: https://fonts.google.com/specimen/Inter
          Or use Google Fonts via CDN (already wired in the CSS)

WEIGHTS USED
─────────────────────────────────────
  Regular 400         Body text
  Medium  500         Buttons, server names, labels
  Semibold 600        Section headers
  Bold     700        Display headlines (the FoundryMTR wordmark)
  Black    900        Numerical displays (player count, version numbers)

OPTIONAL UPGRADE
─────────────────────────────────────
If you want maximum authenticity, swap Inter for "Public Sans" (free, US
government-developed, very transit-board-feeling) or pay for "Söhne" or
"GT America" for a more premium look. Inter is the safe default.


═══════════════════════════════════════════════════════════════════════════════
VOICE & TONE (copy guidelines)
═══════════════════════════════════════════════════════════════════════════════

The launcher copy reads like signage, not like a chat message.

  GOOD                              BAD
  ─────────────────────────────     ─────────────────────────────
  "READY TO BOARD"                  "Click here to play!"
  "ALL SYSTEMS NOMINAL"             "Everything's working great!"
  "CONNECTING TO NETWORK"           "Joining server..."
  "AUTHENTICATING"                  "Logging you in"
  "NEXT DEPARTURE: NOW"             "Click to join"
  "1.20.4 / FABRIC 0.15.11"         "Minecraft version 1.20.4"

Use ALL CAPS for system labels and status text. Mixed case for user-facing
descriptions and news.


═══════════════════════════════════════════════════════════════════════════════
LAYOUT PHILOSOPHY
═══════════════════════════════════════════════════════════════════════════════

  • Generous negative space — let elements breathe
  • Strict left-alignment for most text
  • Numerical data right-aligned with tabular figures
  • Borders are 1px solid, never rounded — this is signage, not Web 2.0
  • Buttons have sharp 2px corners maximum
  • No drop shadows. Use borders and color shifts for hierarchy.
  • Logo always appears at top-left, never centered
