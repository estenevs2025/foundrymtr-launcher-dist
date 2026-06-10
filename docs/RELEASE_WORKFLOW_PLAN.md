# RELEASE_WORKFLOW_PLAN.md — FoundryMTR Release Runbook

> **Status:** Planning / reference document; no release has been published. This is the ordered, repeatable runbook for every release shipped from repo 2 (`foundrymtr-launcher-dist`).
> **State update (implementation pass 1, 2026-06-09):** R2 `foundrymtr-files` and D1 `foundrymtr_prod` now exist (user-created); `files.foundrymtr.com` appears proxy-attached (unverified). No objects, manifests, CORS/cache rules, tokens, or secrets exist yet.
>
> **Scope:** Cloudflare-only (Pages + D1 + R2). Budget USD 0–20/month. Hard limit of 2 repos (`foundrymtr-site`, `foundrymtr-launcher-dist`, owner `estenevs2025`). Build host is **Windows** — commands are PowerShell-first.
>
> **Canonical client target:** Minecraft `1.21.4` + MTR-NextGen `4.1.0` (pinned beta jar, `channel=beta`, pin by hash) + Fabric loader `0.19.3` (explicit, configurable; QA-gated every release).
>
> **Companion docs:**
> - `docs/HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md` (this repo) — launcher config, `distribution.json` module map, the `latest*.yml` URL-rewrite mechanics (§5 there).
> - `docs/REBRAND_TO_FOUNDRYMTR.md` (this repo) — the full rebrand mapping and the zero-legacy-token gate pattern list. Outside that doc, the legacy brand name is never written; this runbook says "the legacy launcher folder."
> - `foundrymtr-site/docs/CLOUDFLARE_SETUP_PLAN.md` (repo 1) — **canonical** R2 layout, cache rules, CORS, secrets handling. URLs and `Cache-Control` values in this doc are byte-identical to that plan.
> - `foundrymtr-site/docs/DATABASE_SCHEMA_PLAN.md` (repo 1) — the D1 tables updated in step 5.

---

## Table of contents

0. [Canonical values quick reference](#0-canonical-values-quick-reference)
1. [Release types & per-type checklists](#1-release-types--per-type-checklists)
2. [The Golden Ordering (non-negotiable)](#2-the-golden-ordering-non-negotiable)
3. [Step-by-step commands](#3-step-by-step-commands)
4. [Verification gates between every step](#4-verification-gates-between-every-step)
5. [QA test scripts: fresh install & update install](#5-qa-test-scripts-fresh-install--update-install)
6. [Rollback procedure & pruning policy](#6-rollback-procedure--pruning-policy)
7. [One-time fold-in procedure (precedes the first release)](#7-one-time-fold-in-procedure-precedes-the-first-release)
8. [Release quality-gate checklist](#8-release-quality-gate-checklist)

---

## 0. Canonical values quick reference

Use these verbatim. Anything that drifts is a bug.

| Concept | Canonical value |
|---|---|
| R2 bucket / binding | `foundrymtr-files` / `FILES_BUCKET` |
| Public base URL | `https://files.foundrymtr.com` (**never** any `.r2.dev` URL) |
| D1 database / binding | `foundrymtr_prod` / `DB` |
| Pages project | `foundrymtr-site` |
| Distribution manifest | `https://files.foundrymtr.com/helios/distribution.json` |
| Mod jars | `https://files.foundrymtr.com/servers/foundrymtr/mods/<jar>` |
| Config / packs / libs | `https://files.foundrymtr.com/servers/foundrymtr/{config,resourcepacks,shaderpacks,libraries}/<file>` |
| Launcher update manifests | `https://files.foundrymtr.com/launcher/releases/{win,mac,linux}/latest.yml` \| `latest-mac.yml` \| `latest-linux.yml` |
| Versioned installers | `https://files.foundrymtr.com/launcher/releases/<platform>/<version>/` + `FoundryMTR-Setup-<ver>.exe` \| `FoundryMTR-Setup-<ver>-<arch>.dmg` \| `FoundryMTR-Setup-<ver>.AppImage` (+ `.blockmap`) |
| News feed | `https://files.foundrymtr.com/news/news.txt` |
| MTRNG public downloads | `https://files.foundrymtr.com/public/mtrng/{latest,archive}/` |
| Server profile | id `foundrymtr-1.21.4`, name `FoundryMTR`, autoconnect address `<SERVER_ADDRESS>` (placeholder — **must be replaced with the confirmed address before publish**) |
| Cache-Control: versioned binaries | `public, max-age=31536000, immutable` |
| Cache-Control: `distribution.json` + `latest*.yml` | `public, max-age=60, must-revalidate` (+ explicit purge on release) |
| Cache-Control: `news/news.txt` | `public, max-age=300, must-revalidate` (+ purge on update) |

**The 7-mod client set** (exact jar filenames; intentional reduction from the old 11):

| Jar | Notes |
|---|---|
| `mtr-nextgen-fabric-mc1.21.4-mtr4.1.0-beta.1-ng.dev1.jar` | ~137 MB — exceeds GitHub's 100 MB hard limit; **R2 only, never git**. Beta/dev build: pinned by hash, `channel=beta`. |
| `fabric-api-0.119.4+1.21.4.jar` | |
| `sodium-fabric-0.6.13+mc1.21.4.jar` | |
| `lithium-fabric-0.15.3+mc1.21.4.jar` | |
| `ferritecore-7.1.3-fabric.jar` | |
| `Debugify-1.21.4+1.1.jar` | |
| `modmenu-13.0.4.jar` | |

**Two endpoints, two purposes — do not confuse them:**

- `https://files.foundrymtr.com/...` — the **public download** domain (proxied custom domain; Cache Rules apply). The only URL form that ever appears in manifests, the site, D1, or the launcher.
- `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` — the **private S3-compatible API endpoint** used only by release tooling for authenticated uploads (scoped R2 S3 token). This is *not* the banned `.r2.dev` development URL; it never appears in any public artifact.

**Secrets posture:** the R2 S3 token pair and the scoped `CF_PURGE_TOKEN` are handled per `CLOUDFLARE_SETUP_PLAN.md` §1/§3. They are read from the environment or a credentials store at release time, never committed, never echoed, never written into this doc.

---

## 1. Release types & per-type checklists

Three release types. All three obey the same Golden Ordering (§2); they differ only in which binaries and which manifests are touched.

### Type A — Modpack / distribution release

Trigger: the mod set changes, a mod version bumps, or server-profile config/resourcepacks change. Output: new versioned artifacts under `servers/foundrymtr/` + a regenerated `helios/distribution.json` with a bumped server-profile `version`.

- [ ] Decide the new server profile version (semver bump of the `foundrymtr-1.21.4` profile's `version` field in the staging manifest under `distribution/`).
- [ ] Stage the exact jar set locally; confirm filenames match §0 verbatim (or the intentionally changed set).
- [ ] Compute and record `sha256` + `md5` + `size_bytes` for every new/changed artifact (§3.1.3).
- [ ] **QA gate:** verify Fabric loader `0.19.3` (or the explicitly changed pin) resolves on the Fabric Maven (§3.1.4) — run this even when the loader did not change.
- [ ] Pre-check that no target R2 key already exists (write-once), then upload new artifacts direct to R2 with `Cache-Control: public, max-age=31536000, immutable` (§3.2).
- [ ] Verify uploads against R2: size via HEAD, hash via re-download spot-check (§3.3).
- [ ] Regenerate `distribution.json` from the staging manifest: **`FabricMod` module type for Fabric mods** (not the ForgeMod-style types the early draft used), real MD5 + size per module, all URLs `https://files.foundrymtr.com/...`, `rss` field = `https://files.foundrymtr.com/news/news.txt`, autoconnect address is the **real confirmed address** (the `<SERVER_ADDRESS>` placeholder must be gone).
- [ ] Placeholder/`.r2.dev` grep on the manifest passes (§4, gate G4).
- [ ] Upload `distribution.json` with `Cache-Control: public, max-age=60, must-revalidate` (§3.4).
- [ ] D1 (one batch): insert/refresh `downloads` rows for new artifacts; `helios_distributions` row `status -> 'published'` (+ `published_at`); `audit_log` insert (§3.5).
- [ ] Purge exactly `https://files.foundrymtr.com/helios/distribution.json` (§3.6).
- [ ] Fresh-install test (§5.1) and modpack-update test (§5.3) pass.
- [ ] Optional: publish a news item announcing the release (upload `news/news.txt`, purge it) and a `changelog_entries` row (category `modpack`).

### Type B — Launcher app release

Trigger: any change to the Electron app itself. Output: new installers + blockmaps under `launcher/releases/<platform>/<version>/` + rewritten `latest*.yml` per shipped platform.

- [ ] Bump the app version in `launcher/package.json` and write the changelog/release notes (§3.1.1).
- [ ] Confirm `electron-builder.yml` still carries the FoundryMTR identity (`appId: com.foundrymtr.launcher`, `productName: FoundryMTR Launcher`, `publish: generic` → the per-platform `launcher/releases/<platform>/` URL) and the window-title/version strings are accurate per `REBRAND_TO_FOUNDRYMTR.md`.
- [ ] Build per platform: `npm run dist:win` on the Windows host; mac/linux per the cross-platform notes (§3.1.2). **Only ship `latest*.yml` for platforms you actually built** — never publish a manifest for a platform with no installer behind it.
- [ ] Verify the `sha512` in each generated `latest*.yml` matches a locally recomputed SHA-512 of the installer; record `sha256` + `size_bytes` for D1 (§3.1.3).
- [ ] **Rewrite `latest*.yml` `url:`/`path:` values to `<ver>/`-prefixed relative paths** (§3.4.2 — the critical electron-builder gotcha; mechanics in `HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md` §5). Never touch `sha512`/`size`.
- [ ] Pre-check write-once keys, then upload installers + `.blockmap` files to the NEW `<version>/` keys, `Cache-Control: public, max-age=31536000, immutable` (§3.2).
- [ ] Verify against R2 (§3.3).
- [ ] Upload the rewritten `latest*.yml` per shipped platform, `Cache-Control: public, max-age=60, must-revalidate` (§3.4).
- [ ] D1 (one batch per platform, or one combined batch): clear old `is_latest`, insert new `launcher_releases` row with `is_latest = 1`, `audit_log` insert (§3.5).
- [ ] Purge exactly the shipped `latest*.yml` URLs (§3.6).
- [ ] Fresh-install test (§5.1) and update-install test (§5.2) pass.
- [ ] Optional: news item + `changelog_entries` row (category `launcher`).

### Type C — Combined release (modpack + launcher together)

Run A and B as one release with a **single** manifest phase, a **single** D1 batch, and a **single** purge call:

- [ ] All Type A binary prep/upload/verify steps complete.
- [ ] All Type B binary prep/upload/verify steps complete.
- [ ] Only then: upload `distribution.json` **and** the rewritten `latest*.yml` files (manifests still last, together).
- [ ] One D1 batch covering both: `downloads` rows + `helios_distributions` publish + `launcher_releases` insert/`is_latest` flip + audit entries.
- [ ] One purge call listing the union of exact URLs: `https://files.foundrymtr.com/helios/distribution.json` + each shipped `https://files.foundrymtr.com/launcher/releases/<platform>/latest*.yml`.
- [ ] Fresh-install test exercises both changes at once; update-install test confirms the old launcher version self-updates **and** then pulls the new distribution.

---

## 2. The Golden Ordering (non-negotiable)

Every release — A, B, or C — follows exactly this order. **Binaries first, verify second, manifests last, purge after, test always.** The ordering is what makes failure safe: until step 4, nothing public has changed, so aborting costs nothing.

| # | Step | What it means |
|---|---|---|
| 1 | **Prepare binaries** | Version bump, changelog, build installers / stage jars, compute + record all hashes and sizes locally. |
| 2 | **Upload binaries to NEW versioned R2 keys** | Direct to R2 via the S3 API or `wrangler` — **never through a Worker/Pages Function body**. New version = new key. Never overwrite an existing versioned key. |
| 3 | **Verify hashes/sizes against R2** | HEAD every uploaded key (size, Cache-Control) + re-download spot-check and re-hash. The local record from step 1 is the reference. |
| 4 | **Update manifests** | Upload `distribution.json` (modpack) and/or the rewritten `latest*.yml` + nothing else (launcher). This is the moment the release becomes visible. |
| 5 | **Update website/admin metadata in D1** | `downloads` row(s), `launcher_releases` row + `is_latest` flip, `helios_distributions` `status -> 'published'` — **one batch**, plus `audit_log`. |
| 6 | **Purge ONLY the exact manifest URLs** | URL-scoped `purge_cache` with the precise list. Never zone-wide. Versioned binaries are never purged (immutable). |
| 7 | **Test fresh install** | §5.1 on a clean machine/VM or renamed data dir. |
| 8 | **Test update install** | §5.2 (launcher self-update) and/or §5.3 (modpack update on an existing install). |

Two corollaries:

- **`latest*.yml` and `distribution.json` are the only mutable keys** in the release path. Everything versioned is write-once.
- **A failure before step 4 is a non-event** — delete nothing, fix, re-verify, continue. A failure after step 4 is handled by rollback (§6), which is itself just "repoint the manifests," because the previous binaries are still present.

---

## 3. Step-by-step commands

PowerShell-first (Windows build host). Placeholders: `<ACCOUNT_ID>` (Cloudflare account id), `$env:CF_ZONE_ID` (zone id for `foundrymtr.com`), `$env:CF_PURGE_TOKEN` (scoped purge token — set in the session from a credentials store, never committed or echoed), `$ver` (the release version).

### 3.1 Step 1 — Prepare binaries

#### 3.1.1 Version bump + changelog

```powershell
# Launcher app release (Type B/C) — from foundrymtr-launcher-dist\launcher\
npm version 1.1.0 --no-git-tag-version    # or: npm version patch|minor --no-git-tag-version
$ver = (node -p "require('./package.json').version")
```

- Modpack release (Type A/C): bump the `foundrymtr-1.21.4` profile `version` field in the staging manifest under `distribution\`.
- Write release notes: a draft `changelog_entries` row (category `launcher` or `modpack`) via the admin panel, or a notes file staged for the D1 step. Keep the decorated window-title string accurate when the version moves: `FoundryMTR Launcher V<ver> (MC 1.21.4 - MTR-NG 4.1.0)`.

#### 3.1.2 Build installers (Type B/C)

```powershell
# Windows (the build host) — from foundrymtr-launcher-dist\launcher\
npm ci
npm run dist:win
# Output in launcher\dist\: FoundryMTR-Setup-<ver>.exe, FoundryMTR-Setup-<ver>.exe.blockmap, latest.yml
```

Build with the electron-builder `publish: generic` config present (so `latest.yml` is generated) but **do not auto-publish from the builder** — uploads are the explicit, verified step 2 of this runbook.

**Cross-platform reality (no CI; manual path):**

- **macOS** — a `.dmg` (and signing/notarization) **requires macOS hardware**; electron-builder cannot produce a usable signed mac build from Windows. Manual path: on a Mac, `npm ci && npm run dist:mac`, then copy `dist\` artifacts (`.dmg`, `.dmg.blockmap`, `latest-mac.yml`) back to the Windows release-staging folder and continue the same flow. **No Mac available ⇒ ship Windows-only and do not upload `latest-mac.yml`.** **macOS self-update caveat:** electron-updater can only *apply* a mac update from a ZIP target — a DMG alone installs fresh but cannot self-update. When macOS self-update is enabled, add `zip` to the mac `target` list in `electron-builder.yml`, store the `.zip` (+ its `.blockmap`) in the same `<version>/` folder, and confirm `latest-mac.yml` lists the zip in `files[]` (mechanics in `HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md` §5.4).
- **Linux** — `npm run dist:linux` (AppImage) builds natively on a Linux box or WSL2; electron-builder's Docker image is an alternative. Same rule: no AppImage built ⇒ no `latest-linux.yml` uploaded.
- **Code signing** — no Windows code-signing certificate is currently budgeted; the `.exe` will trip SmartScreen on first run. Acceptable for now (documented user instruction); revisit within the 0–20 USD/month budget if it becomes a support burden.

#### 3.1.3 Compute and record hashes + sizes

Record every artifact into a local release record (e.g. `distribution\staging\release-<ver>.json`) — this record is the reference for every later gate.

```powershell
# SHA-256 (D1 downloads rows) + MD5 (Helios distribution.json modules) + size
$f = ".\dist\FoundryMTR-Setup-$ver.exe"           # repeat per artifact (installers, blockmaps, jars)
$sha256 = (Get-FileHash $f -Algorithm SHA256).Hash.ToLower()
$md5    = (Get-FileHash $f -Algorithm MD5).Hash.ToLower()
$size   = (Get-Item $f).Length
"$f`n  sha256=$sha256`n  md5=$md5`n  size=$size"
```

```powershell
# SHA-512 in base64 — must equal the sha512: field electron-builder wrote into latest*.yml
$fs = [System.IO.File]::OpenRead((Resolve-Path ".\dist\FoundryMTR-Setup-$ver.exe"))
try   { $h = [System.Security.Cryptography.SHA512]::Create().ComputeHash($fs) }
finally { $fs.Dispose() }
[Convert]::ToBase64String($h)   # compare to latest.yml -> sha512 (exact match required)
```

For Type A, hash all 7 jars (or the changed subset). The MTR-NextGen jar is **pinned by hash**: its recorded MD5/SHA-256 is the identity of the beta build; any byte drift = different artifact = different filename/key.

#### 3.1.4 QA gate — Fabric loader resolves on Maven

```powershell
Invoke-WebRequest -Method Head -Uri "https://maven.fabricmc.net/net/fabricmc/fabric-loader/0.19.3/fabric-loader-0.19.3.json"
Invoke-WebRequest -Method Head -Uri "https://maven.fabricmc.net/net/fabricmc/fabric-loader/0.19.3/fabric-loader-0.19.3.jar"
# Both must return 200. Failure = ABORT. Never silently substitute another loader version —
# the pin is explicit and configurable (distribution.json Fabric loader module, type 'Fabric').
```

### 3.2 Step 2 — Upload binaries direct to R2 (NEW versioned keys)

Uploads go from the build host straight to the R2 **S3 API endpoint** with the scoped R2 S3 token (or via the admin panel's presigned-PUT flow). Large files **never** pass through a Worker or Pages Function body.

**Tool choice:**

| Tool | When | Notes |
|---|---|---|
| `aws` CLI (S3-compatible) | Default for everything, required for very large files | Automatic multipart above ~8 MB. Set per-object `--cache-control` and `--content-type`. |
| `rclone` | Equivalent alternative to `aws` | `--header-upload "Cache-Control: ..."` per object. |
| `npx wrangler r2 object put` | Convenient for small/medium objects | Practical ceiling ~300 MB per object — fine for everything here, including the ~137 MB MTR-NextGen jar (which is also fine via S3 multipart). |

**One-time S3 client setup** (keys entered interactively from the R2 token created per `CLOUDFLARE_SETUP_PLAN.md` §3b — never committed, never echoed):

```powershell
aws configure --profile r2                 # paste Access Key ID + Secret when prompted
aws configure set --profile r2 region auto
# AWS CLI v2.23+ gotcha: new default integrity checksums break R2 uploads. Pin both to when_required:
aws configure set --profile r2 request_checksum_calculation when_required
aws configure set --profile r2 response_checksum_validation when_required
$env:R2_ENDPOINT = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
```

**Write-once pre-check (every versioned key, every time):**

```powershell
aws s3api head-object --bucket foundrymtr-files `
  --key "launcher/releases/win/$ver/FoundryMTR-Setup-$ver.exe" `
  --endpoint-url $env:R2_ENDPOINT --profile r2
# Expected: "Not Found" error (key is free) -> proceed.
# A 200 response means the key EXISTS -> ABORT. Versioned keys are write-once; bump the version.
```

**Upload — versioned binaries (immutable Cache-Control set per object at upload):**

```powershell
# Launcher installer + blockmap (Type B/C)
aws s3 cp ".\dist\FoundryMTR-Setup-$ver.exe" `
  "s3://foundrymtr-files/launcher/releases/win/$ver/FoundryMTR-Setup-$ver.exe" `
  --endpoint-url $env:R2_ENDPOINT --profile r2 `
  --content-type application/octet-stream `
  --cache-control "public, max-age=31536000, immutable"

aws s3 cp ".\dist\FoundryMTR-Setup-$ver.exe.blockmap" `
  "s3://foundrymtr-files/launcher/releases/win/$ver/FoundryMTR-Setup-$ver.exe.blockmap" `
  --endpoint-url $env:R2_ENDPOINT --profile r2 `
  --content-type application/octet-stream `
  --cache-control "public, max-age=31536000, immutable"
```

```powershell
# Mod jar (Type A/C) — repeat per new/changed jar; multipart kicks in automatically for the ~137 MB NG jar
aws s3 cp ".\staging\mods\mtr-nextgen-fabric-mc1.21.4-mtr4.1.0-beta.1-ng.dev1.jar" `
  "s3://foundrymtr-files/servers/foundrymtr/mods/mtr-nextgen-fabric-mc1.21.4-mtr4.1.0-beta.1-ng.dev1.jar" `
  --endpoint-url $env:R2_ENDPOINT --profile r2 `
  --content-type application/java-archive `
  --cache-control "public, max-age=31536000, immutable"
```

`rclone` equivalent:

```powershell
rclone copyto ".\dist\FoundryMTR-Setup-$ver.exe" `
  "r2:foundrymtr-files/launcher/releases/win/$ver/FoundryMTR-Setup-$ver.exe" `
  --header-upload "Cache-Control: public, max-age=31536000, immutable" --s3-no-check-bucket
```

`wrangler` equivalent (small/medium objects; ~300 MB practical ceiling):

```powershell
npx wrangler r2 object put `
  "foundrymtr-files/servers/foundrymtr/mods/modmenu-13.0.4.jar" `
  --file ".\staging\mods\modmenu-13.0.4.jar" `
  --content-type application/java-archive `
  --cache-control "public, max-age=31536000, immutable" --remote
```

### 3.3 Step 3 — Verify hashes/sizes against R2

Verify **every** uploaded key before any manifest moves. Two layers:

```powershell
# (a) HEAD via S3 API: size must equal the recorded size
aws s3api head-object --bucket foundrymtr-files `
  --key "launcher/releases/win/$ver/FoundryMTR-Setup-$ver.exe" `
  --endpoint-url $env:R2_ENDPOINT --profile r2
# Check ContentLength == recorded size. NOTE: the ETag of a multipart upload is NOT the MD5 —
# do not "verify" hashes from the multipart ETag. That is what (b) is for.
```

```powershell
# (b) Re-download spot-check over the PUBLIC domain and re-hash (do this for every NEW binary
#     on its first release; at minimum the installer + the largest jar on every release)
$url = "https://files.foundrymtr.com/launcher/releases/win/$ver/FoundryMTR-Setup-$ver.exe"
$tmp = Join-Path $env:TEMP "verify-$ver.exe"
Invoke-WebRequest -Uri $url -OutFile $tmp
(Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower()   # must equal the recorded sha256
Remove-Item $tmp -Confirm:$false
```

```powershell
# (c) Public-domain HEAD: confirm the immutable Cache-Control header rides with the object
(Invoke-WebRequest -Method Head -Uri $url).Headers["Cache-Control"]
# Expected: public, max-age=31536000, immutable
```

### 3.4 Step 4 — Update/upload the manifests (the publish moment)

#### 3.4.1 `distribution.json` (Type A/C)

Regenerate from the staging manifest with the tooling under `distribution\` (the server-side port of the populate script computes MD5 + size from the *verified* values):

- Server profile `foundrymtr-1.21.4`, display name `FoundryMTR`, description "The official FoundryMTR modded server", bumped profile `version`.
- Fabric loader module (type `Fabric`, id `net.fabricmc:fabric-loader:0.19.3`) pinning loader `0.19.3` (Maven-resolved — no loader jar in R2). Never write `FabricLoader` as the type — `helios-distribution-types` has no such enum member; the schema gate (HELIOS plan §7) exists to catch exactly that legacy mis-typing.
- **`FabricMod` module type for all 7 mod jars** (the early draft wrongly used ForgeMod-style types — corrected at regeneration, per locked decision).
- Every artifact URL starts with `https://files.foundrymtr.com/`; every module carries the verified MD5 + size.
- `rss` = `https://files.foundrymtr.com/news/news.txt`.
- Autoconnect `address` = the confirmed real server address. **If `<SERVER_ADDRESS>` is still in the file, the release stops here.**

```powershell
# Placeholder / forbidden-string gate (expected output: NOTHING)
Select-String -Path .\distribution\distribution.json `
  -Pattern '<SERVER_ADDRESS>|<DISCORD_CLIENT_ID>|YOUR-DOMAIN|PLACEHOLDER|TODO|r2\.dev'

# Upload (mutable manifest — short TTL, must-revalidate)
npx wrangler r2 object put "foundrymtr-files/helios/distribution.json" `
  --file .\distribution\distribution.json `
  --content-type application/json `
  --cache-control "public, max-age=60, must-revalidate" --remote
```

#### 3.4.2 `latest*.yml` rewrite + upload (Type B/C) — **the critical electron-builder gotcha**

electron-builder writes `url:` and `path:` as **bare filenames** relative to the feed URL (`.../launcher/releases/win/`), but our installers live one level down in `<version>/` subfolders (so they can be write-once + immutable). **Rewrite the relative paths to `<ver>/`-prefixed values before upload. Never modify `sha512` or `size`.** Full mechanics and rationale: `HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md` §5.

As generated → as uploaded:

```yaml
# generated by electron-builder            # rewritten for publication
version: 1.1.0                              version: 1.1.0
files:                                      files:
  - url: FoundryMTR-Setup-1.1.0.exe           - url: 1.1.0/FoundryMTR-Setup-1.1.0.exe
    sha512: <unchanged>                         sha512: <unchanged>
    size: <unchanged>                           size: <unchanged>
path: FoundryMTR-Setup-1.1.0.exe            path: 1.1.0/FoundryMTR-Setup-1.1.0.exe
sha512: <unchanged>                         sha512: <unchanged>
```

(electron-updater derives the `.blockmap` URL by appending `.blockmap` to the installer URL, so the blockmap sitting next to the installer inside `<ver>/` resolves automatically.)

```powershell
# Rewrite (UTF-8 without BOM, to keep the YAML parser happy)
$yml = Get-Content .\dist\latest.yml -Raw
$yml = $yml -replace '(?m)^(\s*(?:-\s*)?(?:url|path):\s*)(FoundryMTR-)', "`${1}$ver/`$2"
[System.IO.File]::WriteAllText("$PWD\dist\latest.yml", $yml, (New-Object System.Text.UTF8Encoding($false)))

# Sanity: url/path now <ver>/-prefixed; sha512/size untouched
Select-String -Path .\dist\latest.yml -Pattern 'url:|path:|sha512:'

# Upload (mutable manifest — the ONLY overwrite-in-place keys besides distribution.json/news.txt)
npx wrangler r2 object put "foundrymtr-files/launcher/releases/win/latest.yml" `
  --file .\dist\latest.yml `
  --content-type "text/yaml" `
  --cache-control "public, max-age=60, must-revalidate" --remote
# Repeat for mac/latest-mac.yml and linux/latest-linux.yml ONLY if those installers were built and uploaded.
```

### 3.5 Step 5 — Update website/admin metadata in D1 (one batch)

Schema: `foundrymtr-site/docs/DATABASE_SCHEMA_PLAN.md`. The values written here must equal the **verified** R2 reality (hash, size, URL) recorded in §3.1.3/§3.3 — D1 mirrors R2, never the other way around.

**Preferred path:** the site admin panel endpoint, which runs everything in one atomic `env.DB.batch()` (and writes `audit_log` itself).

**Bootstrap/manual fallback** (until the admin panel exists), shown for a Windows launcher release — note the order: clear `is_latest` **before** inserting the new latest, so the partial unique index `idx_launcher_latest` is never violated:

```powershell
npx wrangler d1 execute foundrymtr_prod --remote --file .\distribution\staging\release-d1.sql
```

```sql
-- release-d1.sql (illustrative; one logical batch)
UPDATE launcher_releases SET is_latest = 0
 WHERE platform = 'win' AND channel = 'stable' AND is_latest = 1;

INSERT INTO launcher_releases
  (platform, version, channel, file_url, installer_key, update_manifest_key,
   blockmap_key, sha512, size_bytes, is_latest, release_date)
VALUES
  ('win', '1.1.0', 'stable',
   'https://files.foundrymtr.com/launcher/releases/win/1.1.0/FoundryMTR-Setup-1.1.0.exe',
   'launcher/releases/win/1.1.0/FoundryMTR-Setup-1.1.0.exe',
   'launcher/releases/win/latest.yml',
   'launcher/releases/win/1.1.0/FoundryMTR-Setup-1.1.0.exe.blockmap',
   '<verified-sha512-base64>', <verified-size-bytes>, 1, date('now'));

-- Type A/C additionally: downloads row(s) for new artifacts, and
UPDATE helios_distributions SET status = 'published', published_at = CURRENT_TIMESTAMP
 WHERE server_profile_id = 'foundrymtr-1.21.4' AND status = 'validated';

INSERT INTO audit_log (actor, action, entity_type, entity_id, summary)
VALUES ('owner', 'publish', 'launcher_release', '1.1.0-win',
        'Published FoundryMTR Launcher 1.1.0 (win)');
```

### 3.6 Step 6 — Purge ONLY the exact manifest URLs

URL-scoped purge via the Cloudflare API using the scoped `CF_PURGE_TOKEN` (Zone → Cache Purge on `foundrymtr.com` only; later this is the site's purge-on-release Worker — same token, same payload). Never zone-wide; never purge immutable binaries.

```powershell
# $env:CF_PURGE_TOKEN and $env:CF_ZONE_ID set in-session from a credentials store. Never echo them.
$files = @(
  "https://files.foundrymtr.com/helios/distribution.json"                  # Type A/C
  "https://files.foundrymtr.com/launcher/releases/win/latest.yml"          # Type B/C (per shipped platform)
  # "https://files.foundrymtr.com/launcher/releases/mac/latest-mac.yml"
  # "https://files.foundrymtr.com/launcher/releases/linux/latest-linux.yml"
  # "https://files.foundrymtr.com/news/news.txt"                           # only if news was updated
)
$body = @{ files = $files } | ConvertTo-Json
$r = Invoke-RestMethod -Method Post `
  -Uri "https://api.cloudflare.com/client/v4/zones/$env:CF_ZONE_ID/purge_cache" `
  -Headers @{ Authorization = "Bearer $env:CF_PURGE_TOKEN" } `
  -ContentType "application/json" -Body $body
$r.success   # must be True
```

```powershell
# Confirm the edge now serves the new manifest
Invoke-RestMethod -Uri "https://files.foundrymtr.com/helios/distribution.json" |
  Select-Object -ExpandProperty servers | Select-Object id, version
```

### 3.7 Steps 7–8 — Test

Run §5.1 (fresh install) and §5.2/§5.3 (update install) in full. A release is not done until both pass.

---

## 4. Verification gates between every step

Every arrow in the Golden Ordering has a gate. **Failing any gate up to and including G3 is free: nothing public has changed — fix and re-run.** From G4 onward, failure handling = rollback (§6).

| Gate | What to check | Command / method | Expected result | On failure |
|---|---|---|---|---|
| **G0 → 1** (before prep) | Working tree clean; correct branch; version decided; changelog drafted | `git -C .\launcher status --short` | Empty output; version + notes agreed | Commit/stash; decide version. Nothing started. |
| **G1 → 2** (after prep) | All artifacts hashed + sized into the release record; `latest*.yml` sha512 matches local recompute; Fabric loader pin resolves | §3.1.3 hash commands; §3.1.4 Maven HEADs | Record complete; sha512 exact match; both Maven HEADs 200 | **ABORT** (nothing published). Rebuild or fix the loader pin explicitly — never substitute silently. |
| **G2a** (before each upload) | Target versioned key does not already exist | `aws s3api head-object ...` (§3.2) | "Not Found" | **ABORT** — write-once violation. Bump version / new filename; never overwrite. |
| **G2 → 3** (after uploads) | Every upload completed | Exit code of each `aws s3 cp` / `rclone` / `wrangler put` | `$LASTEXITCODE -eq 0` for all | Re-upload the failed object. Nothing published yet. |
| **G3 → 4** (verify) | R2 size == recorded size; re-downloaded hash == recorded hash; `Cache-Control` is the immutable string | §3.3 (a)(b)(c) | Exact matches; header `public, max-age=31536000, immutable` | **ABORT** — corrupt/incomplete upload. Delete the bad **unreferenced** object, re-upload, re-verify. Still nothing published. |
| **G4a** (manifest content) | No placeholders, no `.r2.dev`, all URLs on `https://files.foundrymtr.com/`, `FabricMod` types, real MD5+size, real server address; `latest*.yml` paths `<ver>/`-prefixed with untouched sha512 | `Select-String` gates in §3.4 | No matches on the forbidden patterns; visual diff of the manifest sane | **ABORT** — regenerate the manifest. The publish moment has not happened. |
| **G4 → 5** (after manifest upload) | Manifest live and parseable; sha512 in served `latest.yml` equals installer hash | `Invoke-RestMethod` the manifest URL; compare fields | New version visible; JSON/YAML parses; hashes match | **ROLLBACK** (§6): re-upload the previous manifest content, purge. Binaries are unaffected. |
| **G5 → 6** (after D1 batch) | D1 rows match R2 reality (hash, size, url); exactly one `is_latest=1` per platform/channel; `helios_distributions` shows `published` | `npx wrangler d1 execute foundrymtr_prod --remote --command "SELECT platform, version, is_latest FROM launcher_releases WHERE is_latest=1;"` | One row per shipped platform, new version; values equal the release record | Re-run the corrected batch (idempotent UPDATE+INSERT); audit-log the correction. |
| **G6 → 7** (after purge) | Purge API succeeded; edge serves new manifest immediately | `$r.success` (§3.6); fresh `Invoke-RestMethod` of each purged URL | `True`; new content served | Retry purge; if the token fails, fix token scope (Dashboard) — worst case clients wait out the 60 s TTL, but do not skip the gate. |
| **G7 → 8** (fresh install) | §5.1 passes end-to-end | Manual QA script | All steps pass | **ROLLBACK** (§6), diagnose, re-release. |
| **G8 done** (update install) | §5.2/§5.3 passes end-to-end | Manual QA script | Old version updates to new and launches | **ROLLBACK** (§6) — fresh installs may work while updates are broken (e.g. bad yml paths); the previous manifest restores both. |

---

## 5. QA test scripts: fresh install & update install

Manual scripts — run verbatim, in order. Use a clean VM where possible; the renamed-data-dir variant is the minimum bar.

### 5.1 Fresh-install test (every release)

1. **Clean slate.** On a clean Windows VM — or on the build host by renaming the user-data dirs:
   ```powershell
   if (Test-Path "$env:USERPROFILE\.foundrymtrlauncher") { Rename-Item "$env:USERPROFILE\.foundrymtrlauncher" ".foundrymtrlauncher.bak" }
   # Also neutralize the legacy data dir so the one-time migration (REBRAND_TO_FOUNDRYMTR.md) doesn't repopulate it:
   if (Test-Path "$env:USERPROFILE\.helioslauncher")     { Rename-Item "$env:USERPROFILE\.helioslauncher" ".helioslauncher.bak" }
   ```
2. **Download the installer from the exact published R2 URL** (not a local build): `https://files.foundrymtr.com/launcher/releases/win/<ver>/FoundryMTR-Setup-<ver>.exe`. Hash the download; it must equal the release record.
3. **Install + first launch.** App identifies as **FoundryMTR Launcher** `<ver>` (title bar shows `FoundryMTR Launcher V<ver> (MC 1.21.4 - MTR-NG 4.1.0)`); a fresh `.foundrymtrlauncher` data dir is created; no legacy-brand string appears anywhere in the UI.
4. **Distribution fetch.** The launcher loads the `FoundryMTR` server profile (`foundrymtr-1.21.4`) from `https://files.foundrymtr.com/helios/distribution.json`. Check DevTools/console: no CORS errors, no `.r2.dev`, no GitHub URLs.
5. **Account login.** Microsoft login works (Azure app approval is a pending owner action independent of releases — if still pending, note it and test with the available auth path).
6. **Mod download with progress.** All 7 jars download with visible progress into the instance `mods\` dir; the MTR-NextGen jar is ~137 MB and its hash matches the pin; downloads are full-speed (edge-cached, no throttling).
7. **Game launch.** Minecraft **1.21.4** boots with Fabric loader **0.19.3** (verify in the launcher/game log); all 7 mods load; no missing-dependency errors.
8. **Server join.** The autoconnect address (the confirmed real address that replaced `<SERVER_ADDRESS>`) resolves and the client reaches the live 1.21.4 server.
9. **News feed.** The launcher news panel loads from `https://files.foundrymtr.com/news/news.txt`.
10. **Restore** the renamed dirs if testing on the build host.

### 5.2 Update-install test (launcher releases — Type B/C)

Tests the electron-updater generic-provider path against R2. Requires the **previous** version's installer, which still exists at its versioned key (write-once guarantees this).

1. On the clean test machine, install the **previous** version from its versioned R2 URL: `https://files.foundrymtr.com/launcher/releases/win/<prev-ver>/FoundryMTR-Setup-<prev-ver>.exe`.
2. Launch once; confirm it runs and reports `<prev-ver>`.
3. With the new `latest.yml` already published + purged (steps 4–6 of this release), relaunch the previous version.
4. **Detection:** electron-updater fetches `latest.yml`, sees `<ver>` > `<prev-ver>`, and offers/starts the update.
5. **Differential download:** the update downloads via the `.blockmap` (differential, not full-size — watch the progress/byte count) from the `<ver>/` versioned key.
6. **Apply + relaunch:** the launcher installs the update and relaunches reporting `<ver>`; sha512 validation passed (no integrity error).
7. Post-update sanity: distribution still loads, game still launches (abbreviated §5.1 steps 4–7).

### 5.3 Modpack-update test (distribution releases — Type A/C)

1. On a machine with an **existing** install of the previous modpack state, launch the (unchanged) launcher.
2. The launcher re-fetches `distribution.json` (60 s TTL + purge means immediately), detects the bumped profile version, and downloads **only** the new/changed jars (hash-validated against the manifest MD5s).
3. Removed mods are absent from the instance after sync; MC 1.21.4 launches and joins the server.

---

## 6. Rollback procedure & pruning policy

Rollback is cheap **by design**: versioned binaries are write-once and never deleted while referenced, so rolling back is purely a manifest + metadata operation. **Never delete a binary that any published manifest references.**

### 6.1 Launcher rollback (bad app release)

1. Regenerate (or restore from the previous release's staged copy) the previous `latest*.yml` — pointing at the previous `<prev-ver>/` keys, which still exist — and upload it over the mutable manifest key with the same `Cache-Control: public, max-age=60, must-revalidate`.
2. Purge exactly the affected `latest*.yml` URL(s) (§3.6 payload, rollback edition).
3. D1, one batch: flip `is_latest` back (`UPDATE ... SET is_latest = 0` on the bad row, `SET is_latest = 1` on the previous row — clear before set), and insert an `audit_log` row recording the rollback and reason.
4. Verify: fetch `latest.yml` (shows `<prev-ver>`); a §5.2-style check confirms an updated client offers/keeps the previous version. Clients that already took the bad update will be offered the previous version only if its version compares higher — otherwise they reinstall from the previous versioned installer URL (publish a news item with that exact URL).
5. The bad version's binaries **stay in R2** (unreferenced but present) pending diagnosis; they are pruned later under §6.3.

### 6.2 Modpack rollback (bad distribution release)

1. Re-upload the previous `distribution.json` (kept in `distribution\staging\` history) — its module URLs point at the previous jars, which still exist under `servers/foundrymtr/mods/`.
2. Purge exactly `https://files.foundrymtr.com/helios/distribution.json`.
3. D1, one batch: the bad `helios_distributions` row `status -> 'retired'` (or back to `'draft'` for rework), previous row `status -> 'published'`; un-publish any new `downloads` rows (`is_public = 0`); `audit_log` insert.
4. Verify with an abbreviated §5.3: an existing install re-syncs back to the previous mod set and launches.

### 6.3 Pruning policy (the only real storage cost lever)

- **Keep: current + previous version per platform** (installers + blockmaps) and the current + previous modpack artifact set. This guarantees rollback is always one manifest write away.
- **Delete older versions only after confirming nothing references them:** check `helios/distribution.json`, all three `latest*.yml`, and the D1 `launcher_releases` / `downloads` / `helios_distributions` rows for the key. No reference anywhere = eligible.
- Prune deliberately (list candidates, confirm, delete via `aws s3 rm` / `wrangler r2 object delete`), and write an `audit_log` row for each pruning action.
- Mod jars shared by both the current and previous distribution (the common case) are referenced twice — they stay.

---

## 7. One-time fold-in procedure (precedes the first release)

The Electron launcher source currently lives in the legacy launcher folder on disk (the doubly-nested legacy tree — see `ACTIVE_DIRECTORY_AUDIT.md` in repo 1 and `REBRAND_TO_FOUNDRYMTR.md` here). It is folded into this repo **once**, fully rebranded, **before** the first release. The legacy tree stays untouched as an archive until the fold-in is verified.

**Target structure:**

```
foundrymtr-launcher-dist/
├── docs/            this plan, HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md, REBRAND_TO_FOUNDRYMTR.md
├── launcher/        the rebranded Electron app source (upstream git history dropped)
├── distribution/    distribution.json tooling + staging manifest
├── branding/        svg sources, render_branding.py, theme css source
└── scripts/         build-windows.ps1, build-unix.sh,
                     deploy-foundrymtr-redesign.ps1, apply-foundrymtr-redesign.ps1
```

**Procedure (ordered; commit only at the end):**

1. **Copy WITHOUT `.git` and `node_modules`.** The upstream fork's git history (~38 MB pack, upstream remote) is deliberately dropped; this repo's own history starts clean.
   ```powershell
   robocopy "<LEGACY_LAUNCHER_BUILD_DIR>" ".\launcher" /E /XD .git node_modules dist /XF *.jar
   # <LEGACY_LAUNCHER_BUILD_DIR> = the doubly-nested legacy build directory identified in REBRAND_TO_FOUNDRYMTR.md
   ```
2. **Apply the full rebrand DURING the copy pass**, per `REBRAND_TO_FOUNDRYMTR.md`: product name **FoundryMTR Launcher**; `appId com.foundrymtr.launcher`; FoundryMC Services LLC authorship with upstream HeliosLauncher/Daniel Scalzi MIT attribution **retained** in LICENSE/NOTICE; data-dir rename to `.foundrymtrlauncher` with the one-time startup migration; `fmtr*` DOM ids / JS functions / `--fmtr-*` CSS vars updated **in lockstep** across the deploy/apply scripts, news JS, theme CSS, and EJS (including the deploy-script PASS sentinel → `fmtrWireToggle`); distribution URL, update feed URLs, news URL (`FOUNDRYMTR_NEWS_URL`) repointed to `https://files.foundrymtr.com/...`; transit-themed flavor strings; corrected window-title string. The npm packages `helios-core` and `helios-distribution-types` are real upstream dependencies and are **never renamed**.
3. **Consolidate to ONE build script set under `scripts/`.** The legacy tree has duplicate Windows build scripts (one at its root, one in a build-scripts subfolder) — keep a single `scripts/build-windows.ps1` (plus `build-unix.sh`), delete the duplicate. Keep upstream-referenced asset *filenames* (`SealCircle.png`, `logo_320x320.png`, build `icon.ico/.icns/.png`) with re-rendered content; rename the project-added station images to `foundrymtr_station.*` (updating the theme CSS `background-image` url and the deploy-script copy step); delete stray duplicates (`* - Copy.png`, root-level station images).
4. **Verify `.gitignore`** covers at minimum: `node_modules/`, `dist/`, `.env*`, `.dev.vars`, plus binary artifact patterns: `*.jar`, `*.exe`, `*.dmg`, `*.AppImage`, `*.blockmap`, `*.asar`.
5. **CRITICAL — never commit mod jars or installers.** The MTR-NextGen jar is ~137 MB, which **exceeds GitHub's 100 MB hard file limit — the push would be rejected outright**, and history rewriting to remove it is painful. Binaries live in R2 only; this repo holds source, scripts, docs, and manifest tooling. Pre-commit check:
   ```powershell
   git status --porcelain | Select-String '\.(jar|exe|dmg|AppImage|blockmap)$'   # expected: NOTHING
   git ls-files | ForEach-Object { Get-Item $_ } | Where-Object Length -gt 50MB  # expected: NOTHING
   ```
6. **Zero-legacy-token grep gate.** The legacy-brand pattern list is defined **only** in `REBRAND_TO_FOUNDRYMTR.md` (by design — this doc never spells the legacy tokens). Run it across `launcher\`, `scripts\`, `branding\`, `distribution\`, excluding `node_modules`/`dist`. **Expected output: nothing.** Any hit = fold-in gate failed; fix and re-run. The brand-neutral "STATION-BOARD SIGNAGE THEME" CSS-header sentinel is intentionally kept and is not a hit.
7. **Build once.** `cd launcher; npm ci; npm run dist:win` completes; the artifact is named `FoundryMTR-Setup-<ver>.exe`; `latest.yml` carries the new appId/product identity.
8. **Smoke test** the built exe: installs, launches, shows FoundryMTR branding, creates `.foundrymtrlauncher` (and migrates a planted legacy data dir if present), attempts the distribution fetch (expected to fail cleanly until R2 exists — confirm the URL it tried is `https://files.foundrymtr.com/helios/distribution.json`).
9. **THEN commit** (conventional message, e.g. `feat: fold in FoundryMTR Launcher source (rebranded, history dropped)`), and push.
10. **Archive stance:** the legacy on-disk tree is left untouched until steps 7–8 are verified and the first real release ships from this repo. Only then may it be archived/removed by the owner.

---

## 8. Release quality-gate checklist

Every release — every type — signs off on every line. No exceptions.

- [ ] binaries uploaded before manifests
- [ ] hash+size verified before manifest update
- [ ] no versioned-binary overwrite
- [ ] manifests purged after update
- [ ] no .r2.dev anywhere
- [ ] no placeholder strings in published manifests
- [ ] Fabric loader 0.19.3 resolves on Maven
- [ ] D1 metadata matches R2 reality (hash, size, url)
- [ ] fresh-install + update-install tests passed
- [ ] no mod jars/installers in git
- [ ] 2-repo limit + 0-20 USD budget preserved

---

*FoundryMTR Launcher · Release runbook for `foundrymtr-launcher-dist` · 2026-06-09. This document creates and publishes nothing by itself. State: D1 + R2 bucket exist; everything else (Pages, DNS verification, CORS, cache rules, tokens, secrets, objects) is still pending. First release requires: remaining Cloudflare provisioning per `CLOUDFLARE_SETUP_PLAN.md`, the fold-in (§7) verified, and the confirmed server address in place of `<SERVER_ADDRESS>`.*
