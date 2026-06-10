# FoundryMTR Launcher — Quick Start

Developer quick reference. The full runbook is `docs/RELEASE_WORKFLOW_PLAN.md`;
the agent/source-of-truth doc is `CLAUDE.md`.

## Run the launcher (dev)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

That installs dependencies, enforces the canonical config (distro URL, Azure id),
deploys the theme (self-verifying), and runs `npm start`. Expected window title:
`FoundryMTR Launcher V<version> (MC 1.21.4 - MTR-NG 4.1.0)`.

## Change the theme

1. Edit sources in `branding\` (`foundrymtr-theme.css`, `foundrymtr-news.js`,
   `foundrymtr_station.jpg`).
2. Run `scripts\deploy-foundrymtr-redesign.ps1` — every check must PASS.
3. `cd launcher; npm start`.

Never hand-edit the deployed copies under `launcher\app\assets\` — the deploy
script regenerates them from `branding\`.

## Build the Windows installer

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -BuildInstaller
# output: launcher\dist\FoundryMTR-Setup-<version>.exe (+ .blockmap + latest.yml)
```

macOS/Linux: `scripts/build-unix.sh --installer` (mac builds require macOS hardware).

## Update the modpack / distribution

1. Drop the jars into `distribution\mods\` and run
   `python distribution\populate_distribution.py` (or regenerate via Nebula —
   preferred; see `docs/HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md` §3).
2. Validate per `docs/HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md` §7.
3. Release per `docs/RELEASE_WORKFLOW_PLAN.md` — binaries first, manifest last, purge, test.

## Hard rules

- `.ps1` scripts stay pure ASCII, BOM-free.
- No jars/installers in git — R2 only (`files.foundrymtr.com`).
- The legacy brand token must never reappear — gate in `docs/REBRAND_TO_FOUNDRYMTR.md` §8.
