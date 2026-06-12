# LAUNCHER_BUILD_CONTRACT — when and how the launcher APP gets built

## The rule that matters most
**Mod/modpack updates never rebuild the launcher.** Publishing mod jars updates
`https://files.foundrymtr.com/helios/distribution.json`; every installed launcher
re-reads it on start (Helios `DistroAPI` refresh in
`launcher/app/assets/js/distromanager.js`, `REMOTE_DISTRO_URL`) and downloads
changed/missing modules by MD5. No installer is involved.

**Rebuild the launcher app only when the app itself changes:** Electron/JS code,
branding/assets bundled into the installer, update-feed config
(`electron-builder.yml` publish blocks, `dev-app-update.yml`), Node/Electron
upgrades, or a deliberate version bump in `launcher/package.json`.

## Build pipeline
- Workflow: [.github/workflows/build-launcher.yml](../.github/workflows/build-launcher.yml) — **manual `workflow_dispatch` only**, never triggered by uploads or pushes.
- Inputs: `version`, `channel` (stable/beta), `build_windows`, `build_macos`, `publish_to_r2`, `release_notes`.
- Jobs: Windows NSIS x64 on `windows-latest`; macOS x64+arm64 DMG on `macos-latest` (unsigned, `CSC_IDENTITY_AUTO_DISCOVERY=false`). Both `npm ci` from the lockfile, `--publish never`, artifacts uploaded to the run.
- The website admin "build" section does **not** dispatch this workflow — no GitHub token is stored server-side (deliberate). The admin endpoint returns the manual steps + workflow link. If you later want one-click triggering, add a fine-grained PAT (actions:write on this repo only) as a Pages secret and extend `POST /api/admin/launcher-builds/trigger`.

## Required secrets
**R2 publish** (`publish_to_r2: true` only):
| Secret | Value |
|---|---|
| `R2_ACCOUNT_ID` | Cloudflare account id |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` | R2 S3 API token (scope: `foundrymtr-files` object write) |

**Windows production signing** (Azure Trusted Signing; all required or build stays unsigned-test):
| Secret | Value |
|---|---|
| `AZURE_TENANT_ID` / `AZURE_CLIENT_ID` / `AZURE_CLIENT_SECRET` | Entra app with Trusted Signing Certificate Profile Signer role |
| `TRUSTED_SIGNING_ENDPOINT` | e.g. `https://eus.codesigning.azure.net` |
| `TRUSTED_SIGNING_ACCOUNT` / `TRUSTED_SIGNING_CERT_PROFILE` | account + certificate profile names |
CI verifies with `Get-AuthenticodeSignature` and FAILS the run if signing was configured but invalid.

**macOS signing/notarization** (all of the first two for signing; all five for notarization):
| Secret | Value |
|---|---|
| `MAC_CSC_LINK` | base64 Developer ID Application .p12 |
| `MAC_CSC_KEY_PASSWORD` | .p12 password |
| `APPLE_ID` / `APPLE_APP_SPECIFIC_PASSWORD` / `APPLE_TEAM_ID` | notarytool credentials |
CI verifies with `codesign --verify` (+ `stapler validate` when notarizing).
**Gotcha (was the 2026-06-12 build failure):** never map `CSC_LINK` directly from a
possibly-empty secret — an empty string makes electron-builder resolve `''` as a
cert path → `…/launcher is not a file` / `CSC_KEY_PASSWORD is not defined`. The
workflow exports CSC vars from a shell guard only when non-empty.

Without them, download the run artifacts and publish manually:
`npx wrangler r2 object put foundrymtr-files/launcher/releases/win/<ver>/FoundryMTR-Setup-<ver>.exe --file=...` (+ `.blockmap`), then the rewritten `latest.yml` at `launcher/releases/win/latest.yml`.

## Update feed (electron-updater)
- Provider: **generic**, already configured — `electron-builder.yml` publish URLs + `dev-app-update.yml` → `https://files.foundrymtr.com/launcher/releases/<platform>`.
- `latest*.yml` `url:`/`path:` fields must be rewritten to `<version>/<file>` before upload (versioned installers live in subfolders; the workflow's publish step does this automatically).
- Channel files are cached 60 s at the edge (cache rule); installers are immutable.

## Signing reality (do not fake)
- **Windows:** unsigned NSIS. SmartScreen will warn; electron-updater itself works unsigned. SHA-512 in `latest.yml` + SHA-256 on the downloads page are the integrity story.
- **macOS:** electron-updater **requires a signed app** for auto-update. No Apple Developer certificates are configured ⇒ **macOS auto-update is blocked**; macOS users get the DMG direct download from the website. Document, don't work around.

## After a build → release checklist
1. Upload/publish installer + `.blockmap` + rewritten `latest*.yml` to `launcher/releases/<platform>/…`.
2. In the site admin **/admin/launcher**: create the release row (installer key, manifest key, SHA-512 from `latest*.yml`, size, version, channel) → **Validate** (R2 existence) → **Promote to latest** (refused until the installer object exists).
3. The public downloads page and `GET /api/launcher/update-policy` pick the promoted row up automatically.
4. Optional required-update floor: set the `launcher_min_version` settings key in /admin/content.
