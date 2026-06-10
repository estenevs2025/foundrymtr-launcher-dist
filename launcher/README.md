<p align="center"><img src="./app/assets/images/SealCircle.png" width="150px" height="150px" alt="logo"></p>

<h1 align="center">FoundryMTR Launcher</h1>

<em><h5 align="center">A fork of Helios Launcher (upstream attribution in LICENSE.txt and NOTICE)</h5></em>

Join the FoundryMTR server without worrying about installing Java, Fabric, or the mods. The
launcher handles all of that for you: it installs the correct Minecraft version (1.21.4), the
pinned Fabric loader, and the full FoundryMTR mod set, verified by checksum, and keeps itself and
the modpack up to date.

## Features

- 🔒 Full account management (Microsoft auth) — credentials are never stored.
- 📂 Efficient asset management — file validation before every launch; corrupt or
  incorrect downloads are repaired automatically.
- ☕ Automatic Java validation and installation.
- 📰 The Dispatch — FoundryMTR news, right in the launcher.
- ⚙️ Intuitive settings management, including a Java control panel.
- Automatic updates from the FoundryMTR CDN.
- Server connection status, right on the landing screen.

## Development

This folder is the vendored app source inside the `foundrymtr-launcher-dist` repo. Do not run
builds from here directly — use the repo's drivers:

```powershell
# from the repo root
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1                   # dev (npm start)
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -BuildInstaller   # installer
```

Workflow rules, gotchas, and canonical values: `../CLAUDE.md`, `../QUICK-START.md`, and
`../docs/`. Requires Node.js 22.

## License & attribution

MIT. This launcher is a fork of HeliosLauncher by Daniel D. Scalzi; the upstream license is
preserved verbatim in `LICENSE.txt`, with additional attribution in `NOTICE`. The runtime
libraries `helios-core` and `helios-distribution-types` are upstream packages, used unmodified.
