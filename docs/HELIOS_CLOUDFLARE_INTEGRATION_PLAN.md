# HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md — FoundryMTR Launcher ↔ Cloudflare R2

> **Status:** Planning / reference document. This is the definitive plan for making the **FoundryMTR Launcher** (Electron, HeliosLauncher fork, `helios-core` 2.x, `electron-updater` self-updates) talk to Cloudflare R2 for both **modpack distribution** and **launcher self-update**.
> **State update (implementation pass 1, 2026-06-09):** R2 bucket `foundrymtr-files` and D1 `foundrymtr_prod` now **exist** (user-created); `files.foundrymtr.com` appears proxy-attached (unverified — 404 with no objects). No objects, manifests, CORS rules, or cache rules exist yet; nothing is published.
>
> **Canonical client target:** Minecraft `1.21.4` + MTR-NextGen `4.1.0` (pinned beta jar, `channel=beta`, pinned by hash) + Fabric loader `0.19.3` (explicit and configurable; QA gate: verify it resolves on the Fabric Maven before each release).
>
> **Canonical infrastructure names** (verbatim, from `foundrymtr-site/docs/CLOUDFLARE_SETUP_PLAN.md`, which is authoritative for R2 layout and cache rules): R2 bucket `foundrymtr-files` (binding `FILES_BUCKET`), public base `https://files.foundrymtr.com`, D1 `foundrymtr_prod` (binding `DB`), Pages project `foundrymtr-site`, `PUBLIC_FILES_BASE_URL=https://files.foundrymtr.com`. **Never use a `.r2.dev` URL anywhere.**
>
> **Repos (hard limit 2):** `foundrymtr-site` (site + admin + API) and `foundrymtr-launcher-dist` (this repo: launcher source, distribution tooling, scripts, docs). GitHub owner: `estenevs2025`. The MTR-NextGen jar is ~137 MB and **exceeds GitHub's 100 MB hard file limit** — mod jars and installers are **never committed to git**; they live in R2 only.
>
> **Branding:** all rebrand decisions referenced here are locked; the exhaustive old→new rename map lives in `REBRAND_TO_FOUNDRYMTR.md`. Outside that file, this documentation refers to the pre-rebrand source only as "the legacy launcher folder."

---

## Table of contents

1. [Architecture overview](#1-architecture-overview)
2. [distribution.json — full plan (Helios v1)](#2-distributionjson--full-plan-helios-v1)
3. [How the manifest is produced](#3-how-the-manifest-is-produced)
4. [Launcher config changes (file-by-file)](#4-launcher-config-changes-file-by-file)
5. [Self-update flow (electron-updater generic provider)](#5-self-update-flow-electron-updater-generic-provider)
6. [Exact URL pattern table](#6-exact-url-pattern-table)
7. [Validation steps (pre-publish gate)](#7-validation-steps-pre-publish-gate)
8. [Dev/test loop (distribution_dev.json + draft manifest)](#8-devtest-loop-distribution_devjson--draft-manifest)
9. [Coordination risks summary](#9-coordination-risks-summary)

---

## 1. Architecture overview

The launcher has exactly **two remote dependencies**, both served from the R2 custom domain `files.foundrymtr.com` (plus the Fabric Maven for loader resolution):

1. **Modpack distribution** — at startup, `helios-core`'s `DistributionAPI` fetches `https://files.foundrymtr.com/helios/distribution.json`. From it the launcher resolves **Fabric loader 0.19.3** (via the Fabric loader module descriptor, whose library graph resolves from the Fabric Maven at `https://maven.fabricmc.net`), then downloads and validates the **7 `FabricMod` artifacts** from R2 by **MD5 + size**, then launches **Minecraft 1.21.4** and autoconnects to the FoundryMTR server.
2. **Launcher self-update** — `electron-updater` (generic provider) polls the per-platform channel file `https://files.foundrymtr.com/launcher/releases/{win|mac|linux}/latest*.yml`, validates installers by **sha512**, and applies differential updates via `.blockmap`.

```
                         FoundryMTR Launcher (Electron / helios-core 2.x)
                         =============================================
                                          |
        +---------------------------------+----------------------------------+
        |                                                                    |
        | (A) MODPACK PATH                                                   | (B) SELF-UPDATE PATH
        v                                                                    v
GET https://files.foundrymtr.com/helios/distribution.json          GET https://files.foundrymtr.com/
        |   (Cache-Control: public, max-age=60, must-revalidate;       launcher/releases/win/latest.yml
        |    purged on publish)                                        (mac/latest-mac.yml, linux/latest-linux.yml;
        v                                                              max-age=60, must-revalidate; purged on release)
parse servers[] -> select id "foundrymtr-1.21.4"                            |
        |                                                                   v
        +--> Fabric loader module (net.fabricmc:fabric-loader:0.19.3)  compare version field vs app version
        |       |                                                           |
        |       v                                                           v (newer available)
        |    resolve loader + intermediary/library graph             GET <ver>/FoundryMTR-Setup-<ver>.exe.blockmap
        |    from Fabric Maven (maven.fabricmc.net)                  + ranged GETs against
        |                                                            <ver>/FoundryMTR-Setup-<ver>.exe
        +--> 7 FabricMod modules                                     (immutable, max-age=31536000)
        |       |                                                           |
        |       v                                                           v
        |    GET https://files.foundrymtr.com/servers/foundrymtr/    verify sha512 -> stage -> install on
        |        mods/<jar>   (immutable, max-age=31536000)          restart (electron-updater)
        |       |
        |       v
        |    validate each artifact: MD5 + size (helios-core)
        |       |  (mismatch => re-download; persistent mismatch => abort launch)
        v       v
   launch Minecraft 1.21.4 (Fabric 0.19.3 + 7 mods)
        |
        v
   autoconnect to <SERVER_ADDRESS>   (confirmed before publish)

   News ("The Dispatch"): GET https://files.foundrymtr.com/news/news.txt
   (max-age=300, must-revalidate; purged on news update)
```

Key properties:

- **R2 is the only origin** for distribution, mods, installers, channel files, and news. No GitHub Pages, no GitHub Releases, no third-party CDN.
- **Manifests are mutable pointers, binaries are immutable.** Versioned binaries are write-once (`public, max-age=31536000, immutable`); `distribution.json` and `latest*.yml` are short-TTL (`public, max-age=60, must-revalidate`) and explicitly purged on publish. Manifests are always updated **last**, after binaries are uploaded and hash/size verified.
- **Two independent hash regimes:** helios-core validates modpack artifacts by **MD5**; electron-updater validates installers by **sha512**. Do not mix them up. sha256 is *additionally* tracked in D1 (`downloads.sha256`) for audit, but it is not what either client validates.

---

## 2. distribution.json — full plan (Helios v1)

The manifest follows the **Helios distribution v1 spec** as typed by the real upstream npm package `helios-distribution-types` (a dependency of the launcher — never renamed). It is served from `https://files.foundrymtr.com/helios/distribution.json`.

### 2.1 Top-level object

| Field | Value | Notes |
|---|---|---|
| `version` | `1.0.0` | Distribution format/iteration version (not the launcher version, not the loader version). |
| `rss` | `https://files.foundrymtr.com/news/news.txt` | Points at the launcher news feed. The custom Dispatch news UI reads the same URL via its own `FOUNDRYMTR_NEWS_URL` constant; keeping `rss` aligned means one canonical news endpoint. |
| `discord.clientId` | `<DISCORD_CLIENT_ID>` | **Placeholder.** The owner must create the Discord application and supply the real client id before enabling Rich Presence. Nothing breaks today because no client id was ever live. |
| `discord.smallImageText` | `FoundryMTR` | |
| `discord.smallImageKey` | `foundrymtr_logo` | Must exactly match a Rich Presence art asset uploaded to the Discord Developer Portal. |
| `servers` | array, one entry | Single-server launcher. |

### 2.2 Server object

| Field | Value |
|---|---|
| `id` | `foundrymtr-1.21.4` |
| `name` | `FoundryMTR` |
| `description` | `The official FoundryMTR modded server` |
| `icon` | `https://files.foundrymtr.com/assets/icons/SealCircle.png` |
| `version` | `1.0.0` |
| `address` | `<SERVER_ADDRESS>` — **placeholder; the autoconnect address must be confirmed before publish** |
| `minecraftVersion` | `1.21.4` |
| `discord.shortId` | `FoundryMTR` |
| `discord.largeImageText` | `FoundryMTR` |
| `discord.largeImageKey` | `foundrymtr_seal` (must match an uploaded Discord art asset) |
| `mainServer` | `true` |
| `autoconnect` | `true` |
| `modules` | Fabric loader module + 7 `FabricMod` modules (below) |

> The server `id` keys the launcher's per-server instance folder on user machines and must match the id used at manifest generation time (§3). Changing it later orphans local instance data — it is locked as `foundrymtr-1.21.4`.

> **Java note:** MC 1.21.4 requires Java 21. Nebula-generated output carries this in the server's `javaOptions` (from `servermeta.json`, `suggestedMajor: 21`). The worked example below shows the required core fields; the generated manifest is authoritative and will include `javaOptions`.

### 2.3 Modules

**Loader module.** Fabric loader `0.19.3`, declared as a module with maven-style id `net.fabricmc:fabric-loader:0.19.3`. **Schema gotcha (locked decision):** the `helios-distribution-types` `Type` enum value for the loader is **`Fabric`** — there is no `FabricLoader` enum member. The legacy hand-written staging manifest used the string `FabricLoader` for the loader and `ForgeMod` for Fabric mods; **both are wrong against the schema and are fixed at regeneration**: loader → `"type": "Fabric"`, mods → `"type": "FabricMod"`. This is exactly the class of bug the schema-validation gate (§7) exists to catch. Helios resolves the loader and its intermediary/library graph from the **Fabric Maven** via this module descriptor (the Nebula-generated form adds `subModules` — a `VersionManifest` JSON plus `Library` entries resolving from `https://maven.fabricmc.net` — under `servers/foundrymtr/libraries/` keys where files are self-hosted).

**Mod modules.** The final **7-mod client set** (an intentional reduction from the old 11), each as `type: "FabricMod"` with an `artifact` carrying `size` (bytes), `MD5` (hex), and the canonical R2 `url`. Exact jar filenames, verbatim:

| # | Jar (exact filename) | Approx size | Note |
|---|---|---|---|
| 1 | `mtr-nextgen-fabric-mc1.21.4-mtr4.1.0-beta.1-ng.dev1.jar` | ~137 MB | Pinned beta/dev build; `channel=beta`; pinned by hash. Exceeds GitHub's 100 MB limit — R2 only. |
| 2 | `fabric-api-0.119.4+1.21.4.jar` | — | |
| 3 | `sodium-fabric-0.6.13+mc1.21.4.jar` | — | |
| 4 | `lithium-fabric-0.15.3+mc1.21.4.jar` | — | |
| 5 | `ferritecore-7.1.3-fabric.jar` | — | |
| 6 | `Debugify-1.21.4+1.1.jar` | — | |
| 7 | `modmenu-13.0.4.jar` | — | |

Module `id`s are maven-style `group:artifact:version` coordinates. They control local placement/dedup in the mod store, not the download URL (the `artifact.url` does that). The generator (§3) derives the authoritative ids from each jar's `fabric.mod.json`; the worked example below shows the expected shape.

### 2.4 `required` semantics and why MD5

- **`required` defaults to true.** In the v1 spec, a module's `required` object is optional; when omitted, the module is required (`value: true`, `def: true`). Every module in this distribution is mandatory (single-server, fixed modpack), so module entries **omit `required` entirely** — the legacy staging file's explicit `"required": { "value": true }` was redundant. Optional-mod UX is deliberately out of scope.
- **Why MD5:** helios-core validates each downloaded artifact against `artifact.MD5` and `artifact.size` — that is the only hash the launcher checks for distribution modules. MD5 here is a **transfer-integrity check against a trusted HTTPS manifest**, not a standalone security boundary; the manifest itself is served over TLS from our own domain. For stronger audit and pin-by-hash bookkeeping (especially the beta MTR-NextGen jar), **sha256 is additionally computed and stored in D1** (`downloads.sha256`, with `md5` and `size_bytes` alongside) by the admin upload/verify pipeline. The D1 row is the system of record; the manifest carries the MD5 because that is what the client consumes.

### 2.5 Complete worked example

`<MD5>` = 32-char lowercase hex MD5 of the exact artifact; `<SIZE>` = exact byte count; `<SERVER_ADDRESS>` and `<DISCORD_CLIENT_ID>` = owner-confirmed values. **No placeholder may survive into the published manifest (§7).**

```json
{
  "version": "1.0.0",
  "rss": "https://files.foundrymtr.com/news/news.txt",
  "discord": {
    "clientId": "<DISCORD_CLIENT_ID>",
    "smallImageText": "FoundryMTR",
    "smallImageKey": "foundrymtr_logo"
  },
  "servers": [
    {
      "id": "foundrymtr-1.21.4",
      "name": "FoundryMTR",
      "description": "The official FoundryMTR modded server",
      "icon": "https://files.foundrymtr.com/assets/icons/SealCircle.png",
      "version": "1.0.0",
      "address": "<SERVER_ADDRESS>",
      "minecraftVersion": "1.21.4",
      "discord": {
        "shortId": "FoundryMTR",
        "largeImageText": "FoundryMTR",
        "largeImageKey": "foundrymtr_seal"
      },
      "mainServer": true,
      "autoconnect": true,
      "modules": [
        {
          "id": "net.fabricmc:fabric-loader:0.19.3",
          "name": "Fabric Loader 0.19.3",
          "type": "Fabric",
          "artifact": {
            "size": "<SIZE>",
            "MD5": "<MD5>",
            "url": "https://maven.fabricmc.net/net/fabricmc/fabric-loader/0.19.3/fabric-loader-0.19.3.jar"
          }
        },
        {
          "id": "org.mtr:mtr-nextgen-fabric:mc1.21.4-mtr4.1.0-beta.1-ng.dev1",
          "name": "MTR-NextGen (Minecraft Transit Railway)",
          "type": "FabricMod",
          "artifact": {
            "size": "<SIZE>",
            "MD5": "<MD5>",
            "url": "https://files.foundrymtr.com/servers/foundrymtr/mods/mtr-nextgen-fabric-mc1.21.4-mtr4.1.0-beta.1-ng.dev1.jar"
          }
        },
        {
          "id": "net.fabricmc:fabric-api:0.119.4+1.21.4",
          "name": "Fabric API",
          "type": "FabricMod",
          "artifact": {
            "size": "<SIZE>",
            "MD5": "<MD5>",
            "url": "https://files.foundrymtr.com/servers/foundrymtr/mods/fabric-api-0.119.4+1.21.4.jar"
          }
        },
        {
          "id": "net.caffeinemc:sodium-fabric:0.6.13+mc1.21.4",
          "name": "Sodium",
          "type": "FabricMod",
          "artifact": {
            "size": "<SIZE>",
            "MD5": "<MD5>",
            "url": "https://files.foundrymtr.com/servers/foundrymtr/mods/sodium-fabric-0.6.13+mc1.21.4.jar"
          }
        },
        {
          "id": "net.caffeinemc:lithium-fabric:0.15.3+mc1.21.4",
          "name": "Lithium",
          "type": "FabricMod",
          "artifact": {
            "size": "<SIZE>",
            "MD5": "<MD5>",
            "url": "https://files.foundrymtr.com/servers/foundrymtr/mods/lithium-fabric-0.15.3+mc1.21.4.jar"
          }
        },
        {
          "id": "malte0811:ferritecore:7.1.3-fabric",
          "name": "FerriteCore",
          "type": "FabricMod",
          "artifact": {
            "size": "<SIZE>",
            "MD5": "<MD5>",
            "url": "https://files.foundrymtr.com/servers/foundrymtr/mods/ferritecore-7.1.3-fabric.jar"
          }
        },
        {
          "id": "dev.isxander:debugify:1.21.4+1.1",
          "name": "Debugify",
          "type": "FabricMod",
          "artifact": {
            "size": "<SIZE>",
            "MD5": "<MD5>",
            "url": "https://files.foundrymtr.com/servers/foundrymtr/mods/Debugify-1.21.4+1.1.jar"
          }
        },
        {
          "id": "com.terraformersmc:modmenu:13.0.4",
          "name": "Mod Menu",
          "type": "FabricMod",
          "artifact": {
            "size": "<SIZE>",
            "MD5": "<MD5>",
            "url": "https://files.foundrymtr.com/servers/foundrymtr/mods/modmenu-13.0.4.jar"
          }
        }
      ]
    }
  ]
}
```

> `"size": "<SIZE>"` is a placeholder for a **JSON number** (e.g. `143654912`), not a string — the published manifest must carry numeric sizes. The generator emits numbers; the placeholder-scan gate (§7) catches any `<SIZE>` that survives.
>
> The loader module shown is the minimal hand-readable form; the **Nebula-generated output is authoritative** and expands it with `subModules` (Fabric `VersionManifest` JSON + intermediary/library entries). Self-hosted loader support files live under `servers/foundrymtr/libraries/` on R2; Fabric Maven URLs stay on `maven.fabricmc.net`.

---

## 3. How the manifest is produced

Two supported paths produce byte-identical *semantics* (same ids, hashes, sizes, canonical URLs). Either way the output is **validated (§7) and then uploaded to R2**, and the admin panel's D1 row tracks it.

### 3.1 Preferred: Nebula generation

[Nebula](https://github.com/dscalzi/Nebula) is the upstream Helios distribution generator — it builds the correct Fabric loader structure (`type: "Fabric"` with subModules) automatically and computes MD5 + size for every artifact.

- **Workspace location:** the existing Nebula clone and distro root live **outside this tree**, in the legacy Downloads location (see `ACTIVE_DIRECTORY_AUDIT.md` in `foundrymtr-site/docs/`). They must be **moved or recreated** — recommendation: recreate fresh next to (not inside) this repo, seeded with the canonical 7 jars. The Nebula root contains multi-hundred-MB jars and is **never committed** (gitignored if placed near the repo).
- **Flow:**
  1. `npm run start -- init root` (point Nebula at the new root).
  2. `g server foundrymtr 1.21.4 --fabric 0.19.3` → creates `servers/foundrymtr-1.21.4/`.
  3. **Known quirk:** the `--fabric` flag may not take; verify and if needed set the loader version manually in `servermeta.json`. The unrelated `1.0.0` field there is the server-meta update-tracking version, **not** the loader version — do not confuse them.
  4. Drop the 7 jars into `servers/foundrymtr-1.21.4/fabricmods/required/`.
  5. Set Nebula's `baseUrl` to `https://files.foundrymtr.com`.
  6. `g distro` → emits `distribution.json` + the `servers/<id>/...` tree with real MD5/size values.
- **Normalization step (required):** Nebula emits artifact URLs mirroring its own root layout (`servers/foundrymtr-1.21.4/fabricmods/required/...`). The canonical R2 layout is `servers/foundrymtr/mods/<jar>` (plus `config/`, `resourcepacks/`, `shaderpacks/`, `libraries/` under `servers/foundrymtr/`). The `distribution/` tooling therefore post-processes the Nebula output: re-keys every artifact URL to the canonical key, verifies MD5/size are untouched by the rewrite, and confirms the module types are `Fabric` / `FabricMod`. The upload step then places each file at its canonical key.

### 3.2 Fallback: ported hashing script

The legacy launcher folder contains a small Python script that walks a `mods/` directory, computes MD5 + size for each jar, and writes a finalized manifest (see `REBRAND_TO_FOUNDRYMTR.md` for its old name/path). That logic is **ported into this repo's `distribution/` tooling** as the fallback generator:

- Input: the staged 7 jars + a manifest template (`distribution/` holds the staging manifest).
- For each jar: compute **MD5 (hex) + exact byte size**, emit a `FabricMod` module entry with the canonical `https://files.foundrymtr.com/servers/foundrymtr/mods/<jar>` URL.
- The Fabric loader module entry for `0.19.3` is templated explicitly (loader version is a first-class configurable input, defaulting to `0.19.3`).
- Refuses to emit if any `<MD5>`/`<SIZE>`/`<SERVER_ADDRESS>`/`YOUR-DOMAIN`/`r2.dev` placeholder or token remains.

### 3.3 Publication tracking (D1)

Regardless of generator, the **admin panel** (repo 1) records the manifest in `foundrymtr_prod.helios_distributions`: `server_profile_id = foundrymtr-1.21.4`, `minecraft_version = 1.21.4`, `fabric_loader_version = 0.19.3`, `mtr_compat = 4.1.0`, `distribution_json_key`, and a `status` lifecycle of **`draft` → `validated` → `published` → `retired`**. D1 stores the *pointer and validation state*, never the manifest binary itself. The per-artifact rows in `downloads` carry `md5`, `sha256`, `size_bytes` — the verification source of truth for §7.

---

## 4. Launcher config changes (file-by-file)

Paths are post-fold-in (`foundrymtr-launcher-dist/launcher/...`). The exhaustive rename map (including theme CSS, deploy/apply script internals, EJS, DOM ids, and PASS sentinels) is in **`REBRAND_TO_FOUNDRYMTR.md`** — this table covers the Cloudflare-facing and identity-bearing changes.

| File | Change | Exact target value |
|---|---|---|
| `launcher/app/assets/js/distromanager.js` | Repoint `REMOTE_DISTRO_URL`. **Replace BOTH lines:** the active export (line 7) **and** the stale commented line above it (line 6) — the comment currently repeats the old GitHub Pages URL and will mislead future greps. | `exports.REMOTE_DISTRO_URL = 'https://files.foundrymtr.com/helios/distribution.json'` |
| `launcher/electron-builder.yml` | Rebrand identity + add publish config. `appId` (currently upstream `helioslauncher`), `productName`, `copyright` (ASCII `(c)` — never the copyright sign in `.yml`/`.ps1`), `maintainer`/`vendor` in the Linux block, per-target `artifactName`, and a **`publish` block (generic provider)** — see §4.1. | `appId: 'com.foundrymtr.launcher'` · `productName: 'FoundryMTR Launcher'` · `copyright: 'Copyright (c) 2026 FoundryMC Services LLC'` · maintainer/vendor `FoundryMC Services LLC` · win/linux `artifactName: 'FoundryMTR-Setup-${version}.${ext}'`, mac `artifactName: 'FoundryMTR-Setup-${version}-${arch}.${ext}'` |
| `launcher/dev-app-update.yml` | Replace the upstream GitHub provider (currently `owner: dscalzi / repo: HeliosLauncher / provider: github`) with the R2 generic provider for **dev-build update testing**. | `provider: generic` + `url: https://files.foundrymtr.com/launcher/releases/win` |
| `launcher/package.json` | Point project metadata at our repo/site. `repository.url` and `bugs.url` currently point at upstream; `homepage` is a `YOUR-DOMAIN.com` placeholder; `author` is informal. | `repository.url: git+https://github.com/estenevs2025/foundrymtr-launcher-dist.git` · `bugs.url: https://github.com/estenevs2025/foundrymtr-launcher-dist/issues` · `homepage: https://foundrymtr.com` · `author: FoundryMC Services LLC` |
| `launcher/app/assets/js/configmanager.js` | Rename the user-data dir (line 10) `.helioslauncher` → `.foundrymtrlauncher` **with the one-time migration** (§4.2). Justified: no public release has shipped — only test installs — and the owner wants zero legacy brand on user machines. | `dataPath = path.join(sysRoot, '.foundrymtrlauncher')` + migration snippet |
| `launcher/app/assets/js/processbuilder.js` | macOS dock name: **two occurrences** (lines 375 and 426) of `-Xdock:name=HeliosLauncher`. | `args.push('-Xdock:name=FoundryMTR Launcher')` (both) — the space is safe: each `args` element is a single argv entry passed to `spawn` (no shell splitting), and the JVM takes everything after `=`. Canonical value per `REBRAND_TO_FOUNDRYMTR.md` §2/§3.1 |
| `launcher/app/assets/js/ipcconstants.js` | **No change to the Azure client id.** The wired Azure public client id is an app identifier, not a secret, and is kept. Azure app approval for Microsoft login is a pending owner action independent of this integration. | (keep; add a comment noting approval is pending) |
| `launcher/app/assets/lang/en_US.toml` | Forced window/dialog title (line 152) and off-brand upstream flavor text: replace the fantasy-realm Discord strings with transit-themed copy (locked). | title `"FoundryMTR Launcher"` · `joining = "Boarding at the platform..."` · `joined = "Riding the FoundryMTR network"` |
| `launcher/app/assets/lang/_custom.toml` | The decorated window title (the actual title source). The old string wrongly showed the **Fabric API version (0.119.4) as if it were the loader** and a **wrong NG version (1.4.1)** — both fixed. | `title = "FoundryMTR Launcher V<ver> (MC 1.21.4 - MTR-NG 4.1.0)"` |
| `launcher/app/assets/js/foundrymtr-news.js` (renamed news JS) | News constant becomes `FOUNDRYMTR_NEWS_URL`, pointing at R2. The file is rewritten with ASCII quotes (the legacy copy is encoding-corrupted) and its internals move to the `fmtr*` prefix (`fmtrBrand`, `fmtrNews`, `fmtrNewsBody`, `fmtrNewsDate`, `fmtrNewsClose`, `fmtrNewsTab`, `fmtrNewsLoading`, `fmtrWireToggle`, `--fmtr-*` CSS vars) **in lockstep** with the deploy/apply scripts that inject the matching HTML, the theme CSS, and the EJS. | `const FOUNDRYMTR_NEWS_URL = 'https://files.foundrymtr.com/news/news.txt'` |
| `scripts/deploy-foundrymtr-redesign.ps1` / `scripts/apply-foundrymtr-redesign.ps1` | These scripts force-write titles and inject the brand block on every run — they must carry the same values or they silently revert them. Update the deploy PASS sentinel from the legacy wire-toggle function name to `fmtrWireToggle`; the brand-neutral `STATION-BOARD SIGNAGE THEME` CSS-header sentinel is kept. Title force-writes (app.ejs / index.js / lang) become `FoundryMTR Launcher`. Scripts stay pure ASCII, BOM-free. | per `REBRAND_TO_FOUNDRYMTR.md` |

### 4.1 `electron-builder.yml` publish block

`electron-updater`'s generic provider needs a **per-platform** base URL because each platform's channel file lives in its own R2 folder. electron-builder supports `publish` at top level and per-platform overrides inside the `win:`/`mac:`/`linux:` blocks — use the per-platform form so each build embeds the right feed URL in `app-update.yml`:

```yaml
appId: 'com.foundrymtr.launcher'
productName: 'FoundryMTR Launcher'
artifactName: 'FoundryMTR-Setup-${version}.${ext}'

copyright: 'Copyright (c) 2026 FoundryMC Services LLC'

win:
  target:
    - target: 'nsis'
      arch: 'x64'
  publish:
    - provider: 'generic'
      url: 'https://files.foundrymtr.com/launcher/releases/win'

mac:
  target:
    - target: 'dmg'
      arch:
        - 'x64'
        - 'arm64'
  artifactName: 'FoundryMTR-Setup-${version}-${arch}.${ext}'
  category: 'public.app-category.games'
  publish:
    - provider: 'generic'
      url: 'https://files.foundrymtr.com/launcher/releases/mac'

linux:
  target: 'AppImage'
  maintainer: 'FoundryMC Services LLC'
  vendor: 'FoundryMC Services LLC'
  publish:
    - provider: 'generic'
      url: 'https://files.foundrymtr.com/launcher/releases/linux'
```

Alternative (equivalent): keep a single `publish` and override at build time per platform with `--config` overrides (e.g. `npx electron-builder -w --config.publish.url=https://files.foundrymtr.com/launcher/releases/win`). The committed per-platform blocks are preferred — no release-time flag to forget. Note `publish` here only configures the **update feed URL baked into the app**; actual uploading to R2 is done by our release scripts (electron-builder never receives R2 credentials).

### 4.2 One-time user-data migration (`configmanager.js`)

No public release exists, so the only `.helioslauncher` dirs in the wild are the owner's test installs. The rename ships with a defensive one-time migration anyway — zero data loss, zero legacy brand left on disk:

```javascript
const sysRoot = process.env.APPDATA || (process.platform == 'darwin' ? process.env.HOME + '/Library/Application Support' : process.env.HOME)

// FoundryMTR: renamed from the upstream '.helioslauncher' data dir.
const legacyDataPath = path.join(sysRoot, '.helioslauncher')
const dataPath = path.join(sysRoot, '.foundrymtrlauncher')

// One-time migration: if a pre-rebrand test install left the legacy dir
// behind and the new dir does not exist yet, move it into place.
try {
    if(fs.existsSync(legacyDataPath) && !fs.existsSync(dataPath)){
        fs.renameSync(legacyDataPath, dataPath) // same volume: atomic dir move
    }
} catch(err){
    // Non-fatal: fall through to a fresh dataPath; the old dir is left intact for manual recovery.
    console.error('FoundryMTR data-dir migration failed; starting fresh.', err)
}
```

(Canonical snippet — kept byte-identical with `REBRAND_TO_FOUNDRYMTR.md` §5, which is the rename authority. `renameSync` is atomic here because both paths live under the same user-home volume. If a cross-volume layout ever surfaces, switch *both* docs together — `fs` is `fs-extra` in this file, so `moveSync` is available as the fallback.)

---

## 5. Self-update flow (electron-updater generic provider)

### 5.1 How the generic provider works

On launch (and on demand), `electron-updater` fetches the **channel file** from the configured generic `url`:

| Platform | Channel file URL |
|---|---|
| Windows | `https://files.foundrymtr.com/launcher/releases/win/latest.yml` |
| macOS | `https://files.foundrymtr.com/launcher/releases/mac/latest-mac.yml` |
| Linux | `https://files.foundrymtr.com/launcher/releases/linux/latest-linux.yml` |

The channel file declares the newest version and its installers:

- `version` — semver of the release; compared against the running app version.
- `files[]` — one entry per artifact: `url` (**resolved relative to the channel-file URL**), `sha512` (base64), `size` (bytes).
- `path` + `sha512` — legacy single-file duplicates of `files[0]` kept for older updater compatibility; must stay consistent with `files[]`.
- `releaseDate` — ISO 8601 timestamp.

If `version` is newer, the updater downloads the installer, verifies **sha512**, stages it, and installs on restart. Channel files are `public, max-age=60, must-revalidate` and **purged on release**; installers and `.blockmap`s are immutable (`public, max-age=31536000, immutable`) under their versioned folder and are never overwritten or purged.

### 5.2 `.blockmap` differential downloads

electron-builder emits a `.blockmap` next to each NSIS installer (and dmg) — a compressed index of content-defined chunks. On update, electron-updater fetches the **new** `.blockmap` (`<installer URL> + ".blockmap"`), compares it with the locally cached previous blockmap, and issues **HTTP Range requests** against the new installer for only the changed chunks. R2 serves ranged GETs, so differential updates work natively. Requirements: every installer upload **must** include its `.blockmap` sibling at the same versioned key prefix, and old versioned folders must remain available (write-once layout already guarantees this) so fallback full downloads of any published version keep working.

### 5.3 CRITICAL GOTCHA — rewrite `url`/`path` for versioned subfolders

**electron-builder writes `latest.yml` assuming the installer sits in the same directory as the channel file** — it emits `url: FoundryMTR-Setup-1.0.1.exe` (bare filename). Our canonical R2 layout deliberately separates them: the channel file lives at `launcher/releases/win/latest.yml`, but installers live in **versioned subfolders** `launcher/releases/win/<ver>/FoundryMTR-Setup-<ver>.exe` (write-once, immutable).

Because electron-updater resolves `files[].url` and `path` **relative to the channel-file URL**, the release step **MUST rewrite** those fields to the version-prefixed relative path before uploading the channel file:

- `FoundryMTR-Setup-1.0.1.exe` → `1.0.1/FoundryMTR-Setup-1.0.1.exe`

The rewrite applies to every entry in `files[]` and to the legacy `path` field, in all three channel files (`latest.yml`, `latest-mac.yml`, `latest-linux.yml`). `sha512`/`size` are untouched. The `.blockmap` URL needs no separate entry — the updater derives it by appending `.blockmap` to the (now version-prefixed) installer URL, which lands correctly inside the versioned folder. If this step is skipped, the updater 404s on `launcher/releases/win/FoundryMTR-Setup-1.0.1.exe` and every self-update fails. This rewrite is a mandatory, scripted step in `RELEASE_WORKFLOW_PLAN.md` — never hand-edited.

### 5.4 Worked `latest.yml` example (Windows, version 1.0.1, post-rewrite)

```yaml
version: 1.0.1
files:
  - url: 1.0.1/FoundryMTR-Setup-1.0.1.exe
    sha512: <BASE64_SHA512>
    size: <SIZE_BYTES>
path: 1.0.1/FoundryMTR-Setup-1.0.1.exe
sha512: <BASE64_SHA512>
releaseDate: '2026-06-09T00:00:00.000Z'
```

Resolved by the client against `https://files.foundrymtr.com/launcher/releases/win/latest.yml` → installer at `https://files.foundrymtr.com/launcher/releases/win/1.0.1/FoundryMTR-Setup-1.0.1.exe`, blockmap at the same URL + `.blockmap`. The macOS and Linux channel files follow the same pattern with their artifact names (`FoundryMTR-Setup-<ver>-<arch>.dmg`, `FoundryMTR-Setup-<ver>.AppImage`).

> **Flagged platform caveats (QA items, not layout changes):** (a) electron-updater's macOS updater requires a **ZIP** target in `files[]` to actually apply updates — a DMG alone installs fine but cannot self-update; if/when macOS self-update is enabled, add a `zip` mac target and store it in the same `<ver>/` folder, updating `latest-mac.yml` accordingly (track in `RELEASE_WORKFLOW_PLAN.md`). (b) Unsigned Windows builds update fine via sha512 but trigger SmartScreen on first install; code signing is a future owner decision, independent of R2.

---

## 6. Exact URL pattern table

All URLs are rooted at the R2 custom domain. **Never `.r2.dev`, never GitHub Pages, never `YOUR-DOMAIN`.** Byte-consistent with `foundrymtr-site/docs/CLOUDFLARE_SETUP_PLAN.md` §5–§6.

| Artifact | Canonical URL | Cache-Control |
|---|---|---|
| Helios distribution manifest | `https://files.foundrymtr.com/helios/distribution.json` | `public, max-age=60, must-revalidate` + purge on publish |
| Draft distribution manifest (§8) | `https://files.foundrymtr.com/helios/distribution-draft.json` | `public, max-age=60, must-revalidate` + purge on draft update |
| Mod jar | `https://files.foundrymtr.com/servers/foundrymtr/mods/<jar>` (e.g. `.../mods/mtr-nextgen-fabric-mc1.21.4-mtr4.1.0-beta.1-ng.dev1.jar`) | `public, max-age=31536000, immutable` |
| Server config / resourcepacks / shaderpacks / libraries | `https://files.foundrymtr.com/servers/foundrymtr/{config,resourcepacks,shaderpacks,libraries}/<file>` | `public, max-age=31536000, immutable` |
| Windows update channel file | `https://files.foundrymtr.com/launcher/releases/win/latest.yml` | `public, max-age=60, must-revalidate` + purge on release |
| Windows installer (versioned) | `https://files.foundrymtr.com/launcher/releases/win/<ver>/FoundryMTR-Setup-<ver>.exe` (+ `.blockmap`) | `public, max-age=31536000, immutable` |
| macOS update channel file | `https://files.foundrymtr.com/launcher/releases/mac/latest-mac.yml` | `public, max-age=60, must-revalidate` + purge on release |
| macOS installer (versioned) | `https://files.foundrymtr.com/launcher/releases/mac/<ver>/FoundryMTR-Setup-<ver>-<arch>.dmg` (+ `.blockmap`) | `public, max-age=31536000, immutable` |
| Linux update channel file | `https://files.foundrymtr.com/launcher/releases/linux/latest-linux.yml` | `public, max-age=60, must-revalidate` + purge on release |
| Linux installer (versioned) | `https://files.foundrymtr.com/launcher/releases/linux/<ver>/FoundryMTR-Setup-<ver>.AppImage` | `public, max-age=31536000, immutable` |
| Launcher news feed ("The Dispatch") | `https://files.foundrymtr.com/news/news.txt` | `public, max-age=300, must-revalidate` + purge on news update |
| MTR-NextGen public download (latest) | `https://files.foundrymtr.com/public/mtrng/latest/<file>` | per release policy |
| MTR-NextGen public download (archive) | `https://files.foundrymtr.com/public/mtrng/archive/<file>` | `public, max-age=31536000, immutable` |
| Server icon / assets | `https://files.foundrymtr.com/assets/icons/SealCircle.png` · `https://files.foundrymtr.com/assets/{images,icons}/<file>` | long TTL |
| Fabric loader (external, resolved by Helios) | `https://maven.fabricmc.net/net/fabricmc/fabric-loader/0.19.3/...` | upstream-controlled |

**News pipeline note (locked):** `news.txt` is uploaded to R2 and purged on update. The `rss` field in `distribution.json` and the news JS `FOUNDRYMTR_NEWS_URL` point at the **same** URL. Future option, documented but **not built now**: generate `news.txt` from the D1 `changelog_entries` rows (`category` in `launcher`/`modpack`) via the site API, so the admin changelog feeds the Dispatch panel automatically.

---

## 7. Validation steps (pre-publish gate)

Run in order; **any failure stops the publish**. The manifest is uploaded only after every gate passes; this is the doc-level summary — the operational runbook with the full test matrix is `RELEASE_WORKFLOW_PLAN.md`.

1. **Schema-validate** the candidate `distribution.json` against `helios-distribution-types` (the real npm package is already a launcher dependency; the validator script in `distribution/` loads the types/spec and checks structure plus the `Type` enum values — this is the gate that catches the legacy `FabricLoader`/`ForgeMod` mis-typings).
2. **HEAD every artifact URL** referenced by the manifest (all 7 mod jars + any self-hosted loader/library/icon keys): expect `200` and a `Content-Length` exactly equal to the module's `size`.
3. **Re-download and verify** each artifact from the public URL (not from the local staging copy): MD5 must match `artifact.MD5`; size must match `artifact.size`; sha256 must match the D1 `downloads.sha256` row. This proves what the *edge actually serves*, catching wrong-key uploads and truncated transfers.
4. **Verify Fabric loader `0.19.3` resolves on the Fabric Maven** (the explicit, configurable pinned version): the loader artifact and metadata must exist under `https://maven.fabricmc.net/net/fabricmc/fabric-loader/0.19.3/`. This is the standing QA gate for the pinned loader — no silent substitution if it fails; stop and escalate.
5. **Placeholder/token scan:** the manifest (and channel files) must contain **no** `.r2.dev`, no `<SERVER_ADDRESS>`, no `<MD5>`, no `<SIZE>`, no `<DISCORD_CLIENT_ID>` (if Discord RPC is enabled in this release), and no `YOUR-DOMAIN`. The autoconnect `address` must be the confirmed live server address.
6. **THEN upload the manifest** to `helios/distribution.json` (manifests always last, after binaries are verified) with `Cache-Control: public, max-age=60, must-revalidate`.
7. **Update D1 in one batch** — flip the `helios_distributions` row to `published` together with the related `downloads` / `launcher_releases` rows and the `audit_log` insert (this is Golden Ordering step 5 in `RELEASE_WORKFLOW_PLAN.md` §2).
8. **Purge exactly** the changed manifest URLs (URL-scoped, never zone-wide) via the purge Worker/token described in `CLOUDFLARE_SETUP_PLAN.md` §6.
9. **Fresh-install test + update test:** clean machine/VM fresh install through to autoconnect on MC 1.21.4, and an update-in-place from the previous launcher version via `latest*.yml`. Full platform matrix and pass criteria live in `RELEASE_WORKFLOW_PLAN.md`.

---

## 8. Dev/test loop (`distribution_dev.json` + draft manifest)

Helios has first-class support for a **local dev distribution**: when the launcher runs un-packaged (`npm start`), `helios-core`'s `DistributionAPI` operates in dev mode and reads **`distribution_dev.json`** from the launcher's data directory instead of fetching the remote manifest. This gives a full test loop that never touches the published pointer:

1. Generate the candidate manifest (§3).
2. Upload it to the **draft R2 key**: `helios/distribution-draft.json` (same short-TTL cache profile; D1 row status `draft`). Artifacts referenced by it are the *real* immutable R2 objects — drafts share binaries with production by design (write-once keys make this safe).
3. Copy the draft locally as `distribution_dev.json` into the launcher data dir (`.foundrymtrlauncher`) and run the launcher with `npm start` from `launcher/`.
4. Verify: manifest parses; loader 0.19.3 + all 7 mods download and MD5-validate against the real R2 URLs; game launches on 1.21.4; autoconnect hits the confirmed address; Dispatch news loads from `news/news.txt`.
5. Run the §7 gate against the draft key (it validates the same bytes that will be promoted).
6. **Promote:** server-side copy `helios/distribution-draft.json` → `helios/distribution.json`, purge the production manifest URL, flip the D1 row `draft → validated → published`.

Self-update dev testing follows the same philosophy: `dev-app-update.yml` (`provider: generic`, `url: https://files.foundrymtr.com/launcher/releases/win`) lets a dev build exercise the real channel file; a pre-release channel file can be staged under a draft key and copied into place the same way.

---

## 9. Coordination risks summary

Distilled from the rebrand audit's identifier-change analysis (`REBRAND_TO_FOUNDRYMTR.md` holds the full map). The unifying rule: **publish the thing being pointed at before shipping the thing that points.**

| # | Item | Risk if mis-ordered | Ordering rule / owner action |
|---|---|---|---|
| 1 | **Distribution URL** (`distromanager.js` → `helios/distribution.json`) | Every client fails to load the distro index at startup — launcher is dead on arrival. | `distribution.json` must be live (and §7-validated) on R2 **before** any launcher build pointing at it ships. The dev loop (§8) proves it first. |
| 2 | **Server profile id `foundrymtr-1.21.4`** | Id keys the launcher's local instance folder **and** must match the generated manifest; drift breaks instance reuse and config targeting. | Locked string; manifest generation (Nebula `g server foundrymtr 1.21.4`) and any server-side tooling use it verbatim. Never change post-publish without a migration note. |
| 3 | **`<SERVER_ADDRESS>` autoconnect placeholder** | Clients launch then fail to connect (or connect to a dead host). | Confirm the live 1.21.4 server address with the owner at publish time; placeholder scan (§7 step 5) blocks publish until replaced. |
| 4 | **Discord application** (`<DISCORD_CLIENT_ID>`, art assets `foundrymtr_logo` / `foundrymtr_seal`, shortId `FoundryMTR`) | RPC images/presence silently broken if the client id is fake or asset key names don't match the Developer Portal uploads. | Owner creates the Discord application and uploads art assets named **exactly** `foundrymtr_logo` and `foundrymtr_seal` **before** RPC is enabled. Nothing breaks today — the client id was never set. |
| 5 | **Azure / Microsoft login** | Login fails for all users (expected pre-approval). | The wired Azure public client id is kept (app identifier, not a secret). Azure app approval is a pending owner action, independent of the rebrand and of this R2 integration. |
| 6 | **`latest*.yml` URL rewrite** (§5.3) | All self-updates 404. | Release script rewrites `files[].url` + `path` to `<ver>/...` before upload; channel file uploads last, then purge. |
| 7 | **News feed `news/news.txt`** | Dispatch panel shows no bulletins on first launch. | Upload an initial `news.txt` to R2 before the first launcher release; purge on every news update. |
| 8 | **appId `com.foundrymtr.launcher` + data dir `.foundrymtrlauncher`** | An appId change normally forks the installed-app identity/update channel; a data-dir rename normally orphans user data. | Safe **now and only now**: no public release has shipped. Test installs are covered by the one-time migration (§4.2). After v1.0 ships publicly, both identifiers are frozen. |
| 9 | **Manifest-last ordering** (global invariant) | A purged/updated manifest referencing not-yet-uploaded or unverified binaries bricks every launch/update until fixed. | Binaries uploaded → hash/size verified from the edge → manifests (`distribution.json`, `latest*.yml`) written **last** → exact-URL purge. Versioned keys are write-once; rollback = repoint manifest at the previous, still-present version and purge. |

---

*FoundryMTR Launcher · Cloudflare R2 integration · This document is the plan. State (2026-06-09): R2 `foundrymtr-files` + D1 `foundrymtr_prod` exist; no objects/manifests published; CORS/cache rules pending. Companion docs: `RELEASE_WORKFLOW_PLAN.md` (operational runbook), `REBRAND_TO_FOUNDRYMTR.md` (exhaustive rename map), `foundrymtr-site/docs/CLOUDFLARE_SETUP_PLAN.md` (canonical R2 layout + cache rules).*
