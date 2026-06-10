# foundrymtr-launcher-dist

**FoundryMTR Launcher** — distribution, updates, and release tooling. Repo 2 of 2 for the
[FoundryMTR](https://foundrymtr.com) project (a modded Minecraft Transit Railway survival server).

The launcher is an Electron app (a [HeliosLauncher](https://github.com/dscalzi/HeliosLauncher)
fork — upstream MIT license retained in `launcher/LICENSE.txt` and `launcher/NOTICE`). It
auto-installs Fabric loader 0.19.3 + the FoundryMTR mod set for Minecraft 1.21.4, verified by
checksum, and self-updates from Cloudflare R2.

## Layout

| Folder | Contents |
|---|---|
| `launcher/` | The Electron app source (vendored; build output and `node_modules` are never committed) |
| `distribution/` | Helios `distribution.json` staging + the MD5/size filler tool |
| `branding/` | Theme CSS, news widget JS, station background, SVG sources, PNG renderer |
| `scripts/` | Build/deploy drivers (`build-windows.ps1`, `build-unix.sh`, `deploy-foundrymtr-redesign.ps1`, `apply-foundrymtr-redesign.ps1`) |
| `docs/` | The planning/reference docs (integration plan, release runbook, rebrand spec) |

## Quick start (development)

```powershell
# from the repo root
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1            # install + theme + npm start
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -BuildInstaller   # build dist\FoundryMTR-Setup-<ver>.exe
```

Theme changes: edit sources in `branding\`, then run `scripts\deploy-foundrymtr-redesign.ps1`
(self-verifying PASS/FAIL). See `QUICK-START.md` and `CLAUDE.md` for the workflow rules.

## Hard rules

- **No binaries in git.** Mod jars (the MTR-NextGen jar is ~137 MB, over GitHub's 100 MB hard
  limit), installers, and blockmaps live in Cloudflare R2 (`files.foundrymtr.com`) only.
- **Releases follow `docs/RELEASE_WORKFLOW_PLAN.md`:** binaries first → verify hash/size →
  manifests last → purge → test. Versioned R2 keys are write-once.
- **The legacy brand is gone.** The complete rename map and verification gate live in
  `docs/REBRAND_TO_FOUNDRYMTR.md` — the only file allowed to quote the old strings.
