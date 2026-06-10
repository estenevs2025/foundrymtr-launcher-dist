# REBRAND_TO_FOUNDRYMTR.md — Complete Rebrand Specification

> **Status:** Locked specification. Every decision below is **made** — this document is executable, not a questionnaire. The only genuinely open items are the four external owner actions in §9.
>
> **THIS DOCUMENT IS THE SANCTIONED EXCEPTION.** Everywhere else in this repo, the legacy brand abbreviation must never be written — say "the legacy launcher folder" and reference this file. *This* file deliberately quotes every legacy string verbatim, because these strings are the find-targets of the rename. After the rebrand executes, the verification gate (§8) expects the legacy token to survive **only** in this file and in the upstream LICENSE/NOTICE attribution.
>
> **Scope:** the fold-in rebrand of the legacy launcher tree into REPO 2 (`foundrymtr-launcher-dist`). Cloudflare-only hosting; URLs below are the canonical targets from `foundrymtr-site/docs/CLOUDFLARE_SETUP_PLAN.md`. **State (2026-06-09):** R2 `foundrymtr-files` + D1 `foundrymtr_prod` exist; no objects/manifests are published at the URLs yet.
>
> **Path conventions used below:**
> - `LEGACY\` = `C:\Users\user1\Desktop\Launcher_Site_Cloudflare_FoundryMTR\mrs-launcher\mrs-launcher\` (the legacy on-disk tree — stays **untouched as an archive** until the fold-in is verified).
> - `REPO2\` = `C:\Users\user1\Desktop\Launcher_Site_Cloudflare_FoundryMTR\foundrymtr-launcher-dist\` (the cloned target repo).
> - `BUILD\` = `LEGACY\MRSLauncher-build\` (the Electron app working tree; becomes `REPO2\launcher\`).

---

## Table of contents

1. [Decision & rationale](#1-decision--rationale)
2. [Canonical brand values (verbatim)](#2-canonical-brand-values-verbatim)
3. [The rename map](#3-the-rename-map)
4. [File & folder renames](#4-file--folder-renames)
5. [Identifier changes & coordination risks](#5-identifier-changes--coordination-risks)
6. [Gotchas — read before touching anything](#6-gotchas--read-before-touching-anything)
7. [Execution order](#7-execution-order)
8. [Verification gate](#8-verification-gate)
9. [Open owner actions](#9-open-owner-actions)

---

## 1. Decision & rationale

**The product is the *FoundryMTR Launcher*.** Not "Foundry Minecraft Launcher", not the legacy name. Rationale:

- **It matches everything that already exists:** the domain `foundrymtr.com`, both repo names (`foundrymtr-site`, `foundrymtr-launcher-dist`), and the *already-rebranded* `package.json` (`name: "foundrymtr-launcher"`, `productName: "FoundryMTR Launcher"`). Choosing anything else would re-open a rename that is half-finished in the right direction.
- **It keeps the MTR transit identity.** MTR (Minecraft Transit Railway) gameplay *is* the product. "Foundry Minecraft Launcher" would erase the rail identity that the entire station-board visual theme is built on. The rail/transit visual identity is **retained** (decision 13); only the old name dies.
- **Zero legacy tokens.** The owner explicitly wants no legacy brand string anywhere in the shipped product — not in user-facing text, not in internal DOM ids, not in CSS variables, not in file names, not on user machines (data dir). This spec therefore renames internals too, rather than taking the lower-churn "leave internal ids alone" path.

**The three brand layers problem.** The legacy tree is in a *three-layer* state that must converge to ONE brand:

| Layer | Examples still present | Fate |
|---|---|---|
| **Upstream Helios / WesterosCraft leftovers** | `appId: 'helioslauncher'`, `.helioslauncher` data dir, `-Xdock:name=HeliosLauncher`, `"Sailing to Westeros!"`, `WELCOME TO WESTEROSCRAFT`, dscalzi release/wiki URLs | Replaced (product surface) / retained only in LICENSE/NOTICE (legal attribution) |
| **The legacy brand** (the abbreviation, the full "Minecraft Railway Server" name, "Foundry SMP") | `com.mrs.launcher`, `mrs-main-1.20.4`, `mrs-theme.css`, `mrsNews*` ids, `"Foundry SMP - MRS"` titles, `estenevs2025.github.io/mrs-dist` URLs | Eliminated completely |
| **Partial FoundryMTR** | `package.json` name/productName, `_custom.toml` title `"FoundryMTR V1.0.1 (...)"` | Kept, corrected, completed |

Treat the **project-root staging files + the build/deploy scripts as source of truth** and regenerate the build dir — the build dir itself is half-rebranded and inconsistent (gotcha G11).

---

## 2. Canonical brand values (verbatim)

These strings are canonical. Anything that drifts from this table is a bug.

| Item | Canonical value | Notes |
|---|---|---|
| Product name | `FoundryMTR Launcher` | `package.json` productName (already set), `electron-builder.yml` productName, `$Config.AppName`, `APP_NAME`, NSIS installer display name |
| appId | `com.foundrymtr.launcher` | Replaces both `com.mrs.launcher` ($Config/scripts) and upstream `helioslauncher` (electron-builder.yml). No installed base has shipped → no update-channel break |
| Publisher / maintainer / vendor / author | `FoundryMC Services LLC` | electron-builder Linux maintainer+vendor, NSIS publisher, `package.json` author, `$Config.Publisher` |
| Product copyright | `Copyright (c) 2026 FoundryMC Services LLC` | **ASCII `(c)` in every `.ps1`/`.yml` — never the copyright sign in scripts.** Upstream MIT + Daniel Scalzi copyright stays in LICENSE/NOTICE |
| npm package name | `foundrymtr-launcher` | Already correct in `package.json`; never rename the `helios-core` / `helios-distribution-types` dependencies |
| Server profile id | `foundrymtr-1.21.4` | distribution.json `id`; keys the launcher's local instance folder; lockstep with server-side/Nebula generation |
| Server display name | `FoundryMTR` | distribution.json `name`, Discord large/smallImageText, `$Config.ServerName` |
| Server description | `The official FoundryMTR modded server` | distribution.json `description` |
| Autoconnect address | `<SERVER_ADDRESS>` placeholder | Confirmed by owner at publish (§9); the server is live on MC 1.21.4 |
| Discord rich-presence keys | `foundrymtr_logo` (small), `foundrymtr_seal` (large) | Must exactly match art assets uploaded in the Discord Developer Portal (§9) |
| Discord shortId | `FoundryMTR` | Rendered as `Server: {shortId}` |
| Discord clientId | `<DISCORD_CLIENT_ID>` placeholder | Owner creates the Discord application (§9). Nothing breaks now — the clientId was never set |
| User data dir | `.foundrymtrlauncher` | Renamed from `.helioslauncher` **with** a one-time startup migration (§5, code included). Justified: no public release exists, only test installs |
| Internal prefix | `fmtr` | DOM ids `fmtrBrand`, `fmtrNews*`; JS fns `fmtrParseNews`…`fmtrWireToggle`; CSS vars `--fmtr-*`; classes `fmtr-accent`, `fmtr-article`. Renamed **in lockstep** (§3.4) |
| macOS dock name | `FoundryMTR Launcher` | `processbuilder.js` `-Xdock:name=` (single argv element — the space is safe) |
| Window title (app.ejs / lang fallback / deploy force-writes) | `FoundryMTR Launcher` | Everywhere a title is *forced* |
| Decorated window title (`_custom.toml`) | `FoundryMTR Launcher V<ver> (MC 1.21.4 - MTR-NG 4.1.0)` | e.g. `V1.0.1`. The old string wrongly showed the Fabric **API** version (0.119.4) as the loader, and a wrong NG version (1.4.1) — both fixed |
| Discord launch flavor | joining = `Boarding at the platform...` / joined = `Riding the FoundryMTR network` | Replaces the upstream fantasy-realm strings |
| Distribution manifest URL | `https://files.foundrymtr.com/helios/distribution.json` | Replaces the GitHub-Pages URL family. Never a `.r2.dev` URL |
| News feed URL | `https://files.foundrymtr.com/news/news.txt` | News JS constant becomes `FOUNDRYMTR_NEWS_URL`; distribution.json `rss` points at the same URL. Cache: `max-age=300` + purge on update. Future option (documented, **not built now**): generate it from D1 `changelog_entries` (category launcher/modpack) via the site API |
| Launcher self-update | `https://files.foundrymtr.com/launcher/releases/{win,mac,linux}/latest.yml\|latest-mac.yml\|latest-linux.yml` | electron-updater generic provider; versioned installers under `{platform}/<version>/` |
| Installer artifact names | `FoundryMTR-Setup-<ver>.exe` / `FoundryMTR-Setup-<ver>-<arch>.dmg` / `FoundryMTR-Setup-<ver>.AppImage` (+ `.blockmap`) | Set via `artifactName` in electron-builder.yml (§3.1) |
| Repo / homepage / bugs | `https://github.com/estenevs2025/foundrymtr-launcher-dist` / `https://foundrymtr.com` / `https://github.com/estenevs2025/foundrymtr-launcher-dist/issues` | `package.json` repository / homepage / bugs |
| Azure client id | `6809b695-eb71-43f8-8fa5-5e9c7d7b33de` — **kept** | App identifier, not a secret. Azure approval is a pending owner action independent of the rebrand (§9) |
| Mod set / loader | MC 1.21.4 + MTR-NextGen 4.1.0 (pinned beta jar, channel=beta, pin by hash) + Fabric loader 0.19.3 + the 7-jar client set | Per the canonical target; QA gate: verify loader 0.19.3 resolves on Fabric Maven before release |

---

## 3. The rename map

Grouped by category. Each row: **file → exact FROM string → exact TO string → note.** Line numbers refer to the legacy tree as audited (2026-06).

### 3.1 Runtime JS + config

| File | FROM (exact) | TO (exact) | Note |
|---|---|---|---|
| `BUILD\app\assets\js\distromanager.js` (lines 6–7) | `https://estenevs2025.github.io/mrs-dist/distribution.json` | `https://files.foundrymtr.com/helios/distribution.json` | **Two occurrences:** line 6 (commented `// Old WesterosCraft url.` note — delete the comment line entirely) and line 7 (active `exports.REMOTE_DISTRO_URL`). This is the runtime distro URL |
| `BUILD\app\assets\js\configmanager.js` (line 10) | `const dataPath = path.join(sysRoot, '.helioslauncher')` | `const dataPath = path.join(sysRoot, '.foundrymtrlauncher')` **plus the one-time migration block** (§5) | The migration block legitimately retains the literal `'.helioslauncher'` as the move-FROM constant — a sanctioned survivor in §8 |
| `BUILD\app\assets\js\processbuilder.js` (lines 375 **and** 426) | `args.push('-Xdock:name=HeliosLauncher')` | `args.push('-Xdock:name=FoundryMTR Launcher')` | **Two occurrences** (1.16-and-below and 1.17+ JVM arg paths). macOS dock name for the spawned game. Critic-found miss — do not skip |
| `BUILD\app\assets\js\ipcconstants.js` (line 3) | `// SEE https://github.com/dscalzi/HeliosLauncher/blob/master/docs/MicrosoftAuth.md` | `// Azure app registration (client id is an app identifier, not a secret). Upstream Microsoft-auth guide: see NOTICE.` | Kills the upstream doc URL from runtime source while keeping the pointer legal-clean. Line 4 `AZURE_CLIENT_ID` value is **kept** (§2) |
| `BUILD\app\assets\js\scripts\settings.js` (line 1456) | `url: 'https://github.com/dscalzi/HeliosLauncher/releases.atom',` | `url: 'https://files.foundrymtr.com/launcher/releases/win/latest.yml',` | The settings "About / latest release" check. No GitHub releases exist for this product. The response is YAML, not Atom — adjust the handler to read the `version:` field (electron-updater remains the actual update path) |
| `BUILD\app\assets\js\scripts\uicore.js` (line 51) | ``info.darwindownload = `https://github.com/dscalzi/HeliosLauncher/releases/download/v${info.version}/Helios-Launcher-setup-${info.version}${process.arch === 'arm64' ? '-arm64' : '-x64'}.dmg` `` | ``info.darwindownload = `https://files.foundrymtr.com/launcher/releases/mac/${info.version}/FoundryMTR-Setup-${info.version}${process.arch === 'arm64' ? '-arm64' : '-x64'}.dmg` `` | The `Helios-Launcher-setup` download filename family dies; the new name matches the canonical R2 layout |
| `BUILD\electron-builder.yml` (line 1) | `appId: 'helioslauncher'` | `appId: 'com.foundrymtr.launcher'` | The real appId source for installer builds — the audit's sweep never opened this file; do not miss it |
| `BUILD\electron-builder.yml` (line 2) | `productName: 'Helios Launcher'` | `productName: 'FoundryMTR Launcher'` | |
| `BUILD\electron-builder.yml` (line 3) | `artifactName: '${productName}-setup-${version}.${ext}'` | `artifactName: 'FoundryMTR-Setup-${version}.${ext}'` | Required so installers match the canonical R2 names (`FoundryMTR-Setup-<ver>.exe`). productName contains a space — do not derive the artifact from it |
| `BUILD\electron-builder.yml` (line 5) | `copyright: 'Copyright © 2018-2026 Daniel Scalzi'` | `copyright: 'Copyright (c) 2026 FoundryMC Services LLC'` | ASCII `(c)`. Upstream copyright stays in LICENSE/NOTICE |
| `BUILD\electron-builder.yml` (line 36, mac block) | `artifactName: '${productName}-setup-${version}-${arch}.${ext}'` | `artifactName: 'FoundryMTR-Setup-${version}-${arch}.${ext}'` | |
| `BUILD\electron-builder.yml` (lines 42–43) | `maintainer: 'Daniel Scalzi'` / `vendor: 'Daniel Scalzi'` | `maintainer: 'FoundryMC Services LLC'` / `vendor: 'FoundryMC Services LLC'` | Linux package metadata |
| `BUILD\electron-builder.yml` (new) | *(no `publish:` block exists)* | Add `publish: { provider: 'generic', url: 'https://files.foundrymtr.com/launcher/releases/win' }` per-platform | Full layout in `HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md`; listed here because the URL is brand-bearing |
| `BUILD\dev-app-update.yml` (whole file) | `owner: dscalzi` / `repo: HeliosLauncher` / `provider: github` | `provider: generic` + `url: https://files.foundrymtr.com/launcher/releases/win` | Dev-mode update channel; must not point at upstream GitHub |
| `BUILD\package.json` (line 6) | `"author": "Foundry Team"` | `"author": "FoundryMC Services LLC"` | |
| `BUILD\package.json` (line 7) | `"license": "MIT - FoundryMTR and FoundryMC are registered trademarks of FoundryMC Services Llc. Copyright 2025-2026"` | `"license": "MIT"` (move the trademark/copyright sentence into `NOTICE`, fixing `Llc` → `LLC`) | Keeps the field a valid SPDX id; legal text lives in NOTICE next to the upstream attribution |
| `BUILD\package.json` (line 8) | `"homepage": "https://YOUR-DOMAIN.com"` | `"homepage": "https://foundrymtr.com"` | |
| `BUILD\package.json` (line 10) | `"bugs": { "url": "https://github.com/dscalzi/HeliosLauncher/issues" }` | `"bugs": { "url": "https://github.com/estenevs2025/foundrymtr-launcher-dist/issues" }` | |
| `BUILD\package.json` (line 50) | `"repository": { "type": "git", "url": "git+https://github.com/dscalzi/HeliosLauncher.git" }` | `"repository": { "type": "git", "url": "git+https://github.com/estenevs2025/foundrymtr-launcher-dist.git" }` | |
| `BUILD\electron-install.log` | *(build artifact containing legacy paths)* | **DELETE — do not edit.** Add `electron-install.log` to `.gitignore` | Critic-found: log files embed old paths/names; they are artifacts, not source |

> **Never touch:** the npm dependencies `helios-core` / `helios-distribution-types`, every `require('helios-core/...')` / `require('helios-distribution-types')` path, and anything under `node_modules`. These are real upstream packages, not brand strings.

### 3.2 Distribution manifest (staging) + tooling

The staging `LEGACY\distribution\distribution.json` is hand-written; the production manifest is **regenerated** (server-side/Nebula lockstep — §5). Fix the staging file *and* the generator inputs so regeneration produces these values:

| File | FROM (exact) | TO (exact) | Note |
|---|---|---|---|
| `distribution\distribution.json` (line 15) | `"id": "mrs-main-1.20.4"` | `"id": "foundrymtr-1.21.4"` | Server profile id; also embeds the MC bump 1.20.4 → 1.21.4 (server is already live on 1.21.4) |
| `distribution\distribution.json` (line 16) | `"name": "Minecraft Railway Server"` | `"name": "FoundryMTR"` | |
| `distribution\distribution.json` (line 17) | `"description": "The official MRS modded server"` | `"description": "The official FoundryMTR modded server"` | |
| `distribution\distribution.json` (lines 6, 24) | `"smallImageText": "Minecraft Railway Server"` / `"largeImageText": "Minecraft Railway Server"` | `"smallImageText": "FoundryMTR"` / `"largeImageText": "FoundryMTR"` | |
| `distribution\distribution.json` (lines 7, 25) | `"smallImageKey": "mrs_logo"` / `"largeImageKey": "mrs_seal"` | `"smallImageKey": "foundrymtr_logo"` / `"largeImageKey": "foundrymtr_seal"` | Must match Discord Portal art-asset names exactly (§9) |
| `distribution\distribution.json` (line 23) | `"shortId": "MRS"` | `"shortId": "FoundryMTR"` | Shown as `Server: {shortId}` |
| `distribution\distribution.json` (clientId) | `"REPLACE_WITH_DISCORD_APP_ID_IF_YOU_WANT_RICH_PRESENCE"` | `<DISCORD_CLIENT_ID>` placeholder until the owner supplies the real id | RPC stays disabled until then; nothing breaks |
| `distribution\distribution.json` (lines 3, 18, 40, 53, 66, 79, 92, 105, 118) | `https://YOUR-DOMAIN.com/mrs/...` (icon, all module artifact urls) and `"rss": "https://YOUR-DOMAIN.com/mrs/news.xml"` | mods → `https://files.foundrymtr.com/servers/foundrymtr/mods/<jar>`; icon → `https://files.foundrymtr.com/assets/icons/SealCircle.png`; `"rss"` → `https://files.foundrymtr.com/news/news.txt` | config/resourcepacks/shaderpacks/libraries likewise under `servers/foundrymtr/`. Real MD5 + size, never placeholders |
| `distribution\distribution.json` (server address) | the old hardcoded IP:port | `<SERVER_ADDRESS>` | Confirmed at publish (§9) |
| `distribution\distribution.json` (module types) | `ForgeMod`-style types on Fabric mods | loader module type `Fabric` (Maven descriptor `net.fabricmc:fabric-loader:0.19.3`); the 7 mod jars typed **`FabricMod`** | Locked decision 15 — the draft used the wrong helios-distribution-types module type; fix during regeneration |
| `distribution\populate_distribution.py` | legacy strings / `mrs` URL prefixes / old server id | `foundrymtr-1.21.4`, `https://files.foundrymtr.com/servers/foundrymtr/...` prefixes | The MD5/size filler must emit the canonical URLs |

The 7 module jars (exact filenames): `mtr-nextgen-fabric-mc1.21.4-mtr4.1.0-beta.1-ng.dev1.jar` (~137 MB, channel=beta, **pin by hash**), `fabric-api-0.119.4+1.21.4.jar`, `sodium-fabric-0.6.13+mc1.21.4.jar`, `lithium-fabric-0.15.3+mc1.21.4.jar`, `ferritecore-7.1.3-fabric.jar`, `Debugify-1.21.4+1.1.jar`, `modmenu-13.0.4.jar`.

### 3.3 EJS templates + language files

| File | FROM (exact) | TO (exact) | Note |
|---|---|---|---|
| `BUILD\app\app.ejs` (line 4) | `<title>Foundry Launcher V1.0.0</title>` | `<title>FoundryMTR Launcher</title>` | The decorated runtime title comes from `_custom.toml`, not from here — but the forced fallback must still be on-brand |
| `BUILD\app\app.ejs` (line 12) | `/* MRS: inline background disabled */` | `/* FoundryMTR: inline background disabled */` | The inline base64 background must stay commented out (legacy gotcha — it beats external CSS) |
| `BUILD\app\app.ejs` (line 31) | `<link type="text/css" rel="stylesheet" href="./assets/css/mrs-theme.css">` | `<link type="text/css" rel="stylesheet" href="./assets/css/foundrymtr-theme.css">` | Follows the file rename (§4) |
| `BUILD\app\landing.ejs` (lines 2–16) | `<!-- MRS REDESIGN START -->` / `<!-- MRS REDESIGN END -->` markers; `<div id="mrsBrand">`; `<p id="mrsBrandTitle">FOUNDRY<span class="mrs-accent">MTR</span></p>`; `<p id="mrsBrandSub">SMP &middot; Your journey starts here</p>`; `<div id="mrsNewsTab">`…; mast-rule `<span>FOUNDRY MTR</span><span id="mrsNewsDate"></span><span>SMP</span>` | `<!-- FOUNDRYMTR REDESIGN START/END -->` markers; `fmtr*` ids per the lockstep table (§3.4); `<p id="fmtrBrandTitle">FOUNDRY<span class="fmtr-accent">MTR</span></p>`; `<p id="fmtrBrandSub">Your journey starts here</p>`; mast-rule `<span>FOUNDRYMTR</span><span id="fmtrNewsDate"></span><span>SURVIVAL</span>` | "SMP" belonged to the legacy "Foundry SMP" identity — dropped. The split FOUNDRY/MTR accent wordmark is retained (transit identity). **This block is injected by the deploy/apply scripts — change the scripts (§3.5), then regenerate; never hand-edit only the EJS** |
| `BUILD\app\landing.ejs` (line 241) | `<script src="./assets/js/mrs-news.js"></script>` | `<script src="./assets/js/foundrymtr-news.js"></script>` | Injected by the deploy script — fix the script source |
| `BUILD\app\assets\lang\en_US.toml` (line 152) | `title = "Foundry SMP - MRS"` | `title = "FoundryMTR Launcher"` | The `[js.login.error.unknown]` window/dialog fallback title. The deploy script **force-writes this exact string** — the script must change in the same pass (§3.5) or it is reintroduced |
| `BUILD\app\assets\lang\en_US.toml` (line 215) | `joining = "Sailing to Westeros!"` | `joining = "Boarding at the platform..."` | Upstream fantasy-realm Discord flavor → transit-themed FoundryMTR copy |
| `BUILD\app\assets\lang\en_US.toml` (line 216) | `joined = "Exploring the Realm!"` | `joined = "Riding the FoundryMTR network"` | |
| `BUILD\app\assets\lang\en_US.toml` (line 135) | `state = "Server: {shortId}"` | *(no change)* | `{shortId}` / `{appName}` placeholders auto-resolve — listed so nobody "fixes" them |
| `BUILD\app\assets\lang\en_US.toml` (Helios wiki/issue links) | `https://github.com/dscalzi/HeliosLauncher/wiki/Java-Management...` (javaRequiredMessage) and `https://github.com/dscalzi/HeliosLauncher/issues` (launchWrapperNotDownloaded) | `https://foundrymtr.com` | User-facing support links must not point players at the upstream tracker |
| `BUILD\app\assets\lang\_custom.toml` (line 4) | `title = "FoundryMTR V1.0.1 (MC 1.21.4 - Fabric 0.119.4 - MTR-NG 1.4.1)"` | `title = "FoundryMTR Launcher V1.0.1 (MC 1.21.4 - MTR-NG 4.1.0)"` | **Two factual bugs fixed:** `0.119.4` is the Fabric *API* version shown as if it were the loader; `1.4.1` is a wrong NG version (actual: 4.1.0). This is the actual window-title source. Bump `V<ver>` with each release |
| `BUILD\app\assets\lang\_custom.toml` (lines 18–20) | `welcomeHeader = "WELCOME TO WESTEROSCRAFT"`, the George RR Martin `welcomeDescription`, `welcomeDescCTA = "You are just a few clicks away from Westeros."` | `welcomeHeader = "WELCOME TO FOUNDRYMTR"`; description = short FoundryMTR transit-survival pitch (build the network, ride the network); `welcomeDescCTA = "You are one stop away from the FoundryMTR network."` | Upstream placeholder welcome screen never replaced |
| `BUILD\app\assets\lang\_custom.toml` (`[ejs.settings]`) | `sourceGithubLink = "#"` / `supportLink = "#"` | `sourceGithubLink = "https://github.com/estenevs2025/foundrymtr-launcher-dist"` / `supportLink = "https://foundrymtr.com"` | |

### 3.4 Theme CSS + news JS (the `fmtr` lockstep)

**The news JS is ALREADY corrupted:** `LEGACY\mrs-news.js` (and the build-dir copy) contain smart/curly quotes throughout lines 15–60 — e.g. line 15 is literally ``const MRS_NEWS_URL = ‘https://estenevs2025.github.io/mrs-dist/news.txt’`` — which is **syntactically invalid JavaScript**. Do **not** find/replace the brand into a broken file. **Rewrite the file** as `foundrymtr-news.js` with pure-ASCII quotes, applying the renames below.

**Lockstep rule:** every identifier in this table appears in **four places at once** — the deploy/apply scripts (which *inject* the HTML), the news JS (`getElementById`), the theme CSS (selectors/vars), and the generated EJS. Rename all four in the **same pass** or the news widget silently breaks.

| Kind | FROM | TO |
|---|---|---|
| DOM id | `mrsBrand` | `fmtrBrand` |
| DOM id | `mrsBrandTitle` | `fmtrBrandTitle` |
| DOM id | `mrsBrandSub` | `fmtrBrandSub` |
| DOM id | `mrsNews` | `fmtrNews` |
| DOM id | `mrsNewsTab` | `fmtrNewsTab` |
| DOM id | `mrsNewsClose` | `fmtrNewsClose` |
| DOM id | `mrsNewsMast` | `fmtrNewsMast` |
| DOM id | `mrsNewsDate` | `fmtrNewsDate` |
| DOM id | `mrsNewsBody` | `fmtrNewsBody` |
| DOM id | `mrsNewsLoading` | `fmtrNewsLoading` |
| DOM id | `mrsNewsError` | `fmtrNewsError` |
| CSS class | `mrs-accent` | `fmtr-accent` |
| CSS class | `mrs-article` | `fmtr-article` |
| JS const | `MRS_NEWS_URL` (= the github.io news.txt URL) | `FOUNDRYMTR_NEWS_URL = 'https://files.foundrymtr.com/news/news.txt'` |
| JS function | `mrsParseNews` | `fmtrParseNews` |
| JS function | `mrsEscape` | `fmtrEscape` |
| JS function | `mrsRenderNews` | `fmtrRenderNews` |
| JS function | `mrsUpdateDate` | `fmtrUpdateDate` |
| JS function | `mrsWireToggle` | `fmtrWireToggle` — **and update the deploy PASS sentinel** (§3.5) |
| CSS vars (live theme: staging + `BUILD\app\assets\css`) | `--mrs-rail`, `--mrs-ink`, `--mrs-panel`, `--mrs-steel`, `--mrs-line`, `--mrs-text`, `--mrs-amber`, `--mrs-dot`, `--mrs-cream`, `--mrs-shadow` | `--fmtr-rail`, `--fmtr-ink`, `--fmtr-panel`, `--fmtr-steel`, `--fmtr-line`, `--fmtr-text`, `--fmtr-amber`, `--fmtr-dot`, `--fmtr-cream`, `--fmtr-shadow` — every usage in the same file updated |
| CSS vars (design-archive copy `branding\css`) | `--mrs-ink`, `--mrs-rail`, `--mrs-platform`, `--mrs-chalk`, `--mrs-fog`, `--mrs-signal`, `--mrs-amber`, `--mrs-green`, `--mrs-platinum` | same names with `--fmtr-` prefix | Different (older) palette — rename for token hygiene, but this copy is NOT deployed |

Text/content changes in the same files:

| File | FROM (exact) | TO (exact) | Note |
|---|---|---|---|
| `LEGACY\mrs-theme.css` + `BUILD\app\assets\css\mrs-theme.css` (header) | `FOUNDRY SMP - MRS LAUNCHER \| STATION-BOARD SIGNAGE THEME` | `FOUNDRYMTR LAUNCHER \| STATION-BOARD SIGNAGE THEME` | **The `STATION-BOARD SIGNAGE THEME` substring is the deploy PASS sentinel — it is brand-neutral and KEPT.** Only the prefix changes |
| same files | `MRS color tokens` comment; `one server (MRS)` comment; background `url(../images/backgrounds/mrs_station.jpg)` | `FoundryMTR color tokens`; `one server (FoundryMTR)`; `url(../images/backgrounds/foundrymtr_station.jpg)` | Background path stays `../images/backgrounds/` relative to the CSS (legacy path gotcha) |
| `branding\css\mrs-theme.css` (lines 2, 18, 379) | `MRS LAUNCHER — Custom Theme` / `MRS color tokens` / `one server (MRS)` | `FOUNDRYMTR LAUNCHER - Custom Theme` / `FoundryMTR color tokens` / `one server (FoundryMTR)` | Design-archive copy; renamed file per §4 |
| `LEGACY\mrs-news.js` + build copy (line 2 header) | `MRS THE DISPATCH - collapsible newspaper widget` | `FOUNDRYMTR THE DISPATCH - collapsible newspaper widget` | Part of the full ASCII rewrite |

### 3.5 Build / deploy / apply scripts

**These scripts re-introduce the brand on every run.** They re-patch `package.json` / `ipcconstants.js` / `distromanager.js` and re-copy CSS/EJS each time they execute. If a single one keeps an old value, the next build silently restores it. All four (plus the duplicate) change in the **same pass**. All `.ps1` files stay **pure ASCII and BOM-free** — ASCII `(c)`, straight quotes, hyphens only.

| File | FROM (exact) | TO (exact) | Note |
|---|---|---|---|
| `LEGACY\build-windows.ps1` (lines 2, 7, 9, 16) | `MRS Launcher` header; `Patches the Helios source with MRS branding`; `distribution/ folders from the MRS launcher package` | `FoundryMTR Launcher` header and FoundryMTR wording | |
| `LEGACY\build-windows.ps1` ($Config block, ~line 37–46) | `AppName = "MRS Launcher"`; `AppId = "com.mrs.launcher"`; `Publisher = "Minecraft Railway Server"`; `ServerName = "Minecraft Railway Server"`; `DistributionUrl = "https://estenevs2025.github.io/mrs-dist/distribution.json"`; clone/build target `MRSLauncher-build` | `AppName = "FoundryMTR Launcher"`; `AppId = "com.foundrymtr.launcher"`; `Publisher = "FoundryMC Services LLC"`; `ServerName = "FoundryMTR"`; `DistributionUrl = "https://files.foundrymtr.com/helios/distribution.json"`; build dir `launcher` | **PRIMARY clobber risk** — the $Config + branding step re-patches everything on every run |
| `LEGACY\build-windows.ps1` (lines ~257, 317, 362, 372) | `Installing MRS branding`; `Wiring MRS theme`; `MRS Launcher Setup ...exe`; `Window shows MRS branding` | `Installing FoundryMTR branding`; `Wiring FoundryMTR theme`; `FoundryMTR-Setup-<ver>.exe`; `Window shows FoundryMTR branding` | Installer-name expectations must match the new `artifactName` |
| `LEGACY\build-scripts\build-windows.ps1` | *(duplicate of the root script, same lines)* | **CONSOLIDATED AWAY** — exactly ONE Windows build script survives, at `REPO2\scripts\build-windows.ps1` | Two drifting copies was itself a standing hazard (gotcha G2) |
| `LEGACY\build-scripts\build-unix.sh` (lines 3, 23–24, 42, 159, 193) | `MRS Launcher — Automated Build Script`; `APP_NAME="MRS Launcher"`; `APP_ID="com.mrs.launcher"`; `BUILD_DIR="$SCRIPT_DIR/MRSLauncher-build"`; `Installing MRS branding`; `Wiring MRS theme` | `FoundryMTR Launcher - Automated Build Script`; `APP_NAME="FoundryMTR Launcher"`; `APP_ID="com.foundrymtr.launcher"`; `BUILD_DIR="$SCRIPT_DIR/../launcher"`; FoundryMTR branding/theme steps | Same clobber risk as the Windows script; also replace its `HELIOS_REPO`/`PUBLISHER`/`DISTRIBUTION_URL` config values with the §2 canon |
| `LEGACY\deploy-mrs-redesign.ps1` (lines 49–51) | `Copy-Item (Join-Path $here "mrs-theme.css") ...`; `... "mrs-news.js" ...`; `... "mrs_station.jpg" ...` | copies of `foundrymtr-theme.css` / `foundrymtr-news.js` / `foundrymtr_station.jpg` from `branding\` into `launcher\app\assets\...` | Source dir changes from repo root to `branding\` after fold-in |
| `LEGACY\deploy-mrs-redesign.ps1` (line 55) | `Check "mrs-theme.css copied (theme header)" ($cssBack -match "STATION-BOARD SIGNAGE THEME")` | same check, file name `foundrymtr-theme.css` — **sentinel string KEPT** | |
| `LEGACY\deploy-mrs-redesign.ps1` (line 57) | `Check "mrs-news.js copied (collapsible)" ($jsBack -match "mrsWireToggle")` | `Check "foundrymtr-news.js copied (collapsible)" ($jsBack -match "fmtrWireToggle")` | **The PASS sentinel is brand-coupled — renaming the function without the sentinel = false FAILs** (this exact coupling already bit the project once) |
| `LEGACY\deploy-mrs-redesign.ps1` (lines 75, 81, 87, 89) | injected `<link ... href="./assets/css/mrs-theme.css">`; `[regex]::Replace($c, "<title>.*?</title>", "<title>Foundry SMP - MRS</title>")`; checks `app.ejs has mrs-theme.css link` / `app.ejs title = Foundry SMP - MRS` | link → `foundrymtr-theme.css`; title force-write → `<title>FoundryMTR Launcher</title>`; checks updated to match | |
| `LEGACY\deploy-mrs-redesign.ps1` (lines 97–123) | `<!-- MRS REDESIGN START -->.*?<!-- MRS REDESIGN END -->` strip-regex; the injected brand block (all `mrsBrand*`/`mrsNews*` ids, `FOUNDRY<span class="mrs-accent">MTR</span>`, `SMP &middot; Your journey starts here`, mast-rule spans); `<script src="./assets/js/mrs-news.js"></script>` | `<!-- FOUNDRYMTR REDESIGN START/END -->`; the §3.3/§3.4 block with `fmtr*` ids; `foundrymtr-news.js` script tag | The injection IS the source of the EJS content |
| `LEGACY\deploy-mrs-redesign.ps1` (lines 147–164) | `title: 'Foundry SMP - MRS'` (index.js force-write); TOML title regex writing `Foundry SMP - MRS`; `"app.title"` JSON write; `-replace 'Helios Launcher', 'Foundry SMP - MRS'` | all four force-writes → `FoundryMTR Launcher` | The script force-writes the title in **three files** (app.ejs, index.js, lang) — every one must change |
| `LEGACY\deploy-mrs-redesign.ps1` (lines 8, 15–19) | header banner `deploy-mrs-redesign.ps1` / `Deploying MRS redesign`; `$build = "C:\Users\user1\Downloads\LANDrop\mrs-launcher\mrs-launcher\MRSLauncher-build"` hardcoded fallback | `deploy-foundrymtr-redesign.ps1` / `Deploying FoundryMTR redesign`; **DELETE the absolute fallback** — resolve `launcher\` relative to `$PSScriptRoot` | Hardcoded old-Downloads paths must not survive the fold-in |
| `LEGACY\apply-mrs-redesign.ps1` (lines 11, 21–22, 27, 75, 113–132, 157) | header `MRSLauncher-build / mrs-theme.css, mrs-news.js, mrs_station.jpg`; `$build = "C:\Users\user1\Downloads\LANDrop\mrs-launcher\mrs-launcher\MRSLauncher-build"`; BuildDir `MRSLauncher-build`; `/* MRS: inline background disabled */`; `<!-- MRS REDESIGN START/END -->` markers + guard regex; `<p id="mrsBrandSub">MRS &middot; ...</p>`; `<span>MRS</span>`; `title: 'Foundry SMP - MRS Launcher'` | renamed `apply-foundrymtr-redesign.ps1`; BuildDir → `launcher` (relative, fallback deleted); all markers/ids/text per §3.3–§3.4; `title: 'FoundryMTR Launcher'` | Second brand-writing script; identical re-introduction risk |

### 3.6 Branding sources + SVGs

Upstream-referenced asset **filenames are KEPT** (`SealCircle.png`, `logo_320x320.png`, `build\icon.ico|.icns|.png`, `LoadingSeal.png`, `icon_*.png`) so EJS and electron-builder references stay valid — only their rendered **content** changes via `render_branding.py`.

| File | FROM (exact) | TO (exact) | Note |
|---|---|---|---|
| `branding\render_branding.py` (lines 3, 23, 54, 98, 106) | `Generate all MRS launcher branding PNGs`; `# MRS color palette`; `Draw an MRS roundel...MRS text`; `# Wordmark "MRS"`; `text = "MRS"` | FoundryMTR equivalents; roundel center text `"FMTR"`; wordmark text `"FOUNDRYMTR"` | `FMTR` matches the sanctioned internal prefix and fits the roundel circle; it is a one-constant cosmetic change if the owner later wants a different glyph. **Re-render** `icon_*.png`, `logo_320x320.png`, `SealCircle.png`, `LoadingSeal.png`, and the `build\` icons after editing |
| `branding\svg\icon-roundel.svg` (lines 3, 25) | `MRS Roundel Mark` comment; `<text ...>MRS</text>` | `FoundryMTR Roundel Mark`; `<text ...>FMTR</text>` | |
| `branding\svg\logo-primary.svg` (lines 3, 38–39) | `MRS Launcher Primary Logo`; `Wordmark "MRS"` comment; `<text ...>MRS</text>` | `FoundryMTR Launcher Primary Logo`; wordmark `FOUNDRYMTR` | |
| `branding\svg\wordmark-horizontal.svg` (lines 3, 39) | `MRS Horizontal Wordmark`; `<text ...>MRS</text>` | `FoundryMTR Horizontal Wordmark`; `FOUNDRYMTR` | |
| `branding\html\mockup.html` (lines 5, 368, 389, 423, 425) | `<title>MRS Launcher — Visual Mockup</title>`; `MRS LAUNCHER · v1.0.0` titlebar; `<text>MRS</text>`; `MRS · MAIN NETWORK`; the hardcoded live server IP:port on line 425 | FoundryMTR equivalents; server name `FoundryMTR`; address → `<SERVER_ADDRESS>` | Static design mockup — also leaks the old live server address; scrub it |
| `BUILD\app\assets\images\` upstream fantasy-brand art (`sevenstar*.svg` etc.) | *(WesterosCraft-origin logo assets)* | Delete if unreferenced after the welcome-screen recopy (grep EJS/CSS for each filename first) | Upstream art, not legacy brand — but off-brand product surface |

### 3.7 Markdown docs (including the legacy CLAUDE.md)

| File | FROM | TO | Note |
|---|---|---|---|
| `LEGACY\CLAUDE.md` (~25 occurrences: lines 1, 11–12, 21, 34–41, 57, 84, 87, 109, 166, 186; §4 hosting; §6 config block) | Title `Foundry SMP / MRS Launcher Project`; `Minecraft Railway Server (MRS)`; `Foundry SMP — MRS`; every `MRSLauncher-build` / `MRSDistroRoot` / `mrs-theme.css` / `mrs-news.js` / `mrs_station.jpg` / `mrs-dist` path; `mrs-main-1.20.4`; the `estenevs2025.github.io/mrs-dist` URLs; the old `$Config` block; the Nebula `g server mrs-main 1.20.4 --fabric 0.19.2` command; MC `1.20.4` / Fabric `0.19.2` / the 11-mod list; old server IP | **Rewritten wholesale as the REPO 2 `CLAUDE.md`** — new paths (`foundrymtr-launcher-dist\launcher`), `foundrymtr-1.21.4`, MC 1.21.4 + MTR-NG 4.1.0 + Fabric 0.19.3 + the 7-mod set, `files.foundrymtr.com` URLs, the §2 $Config canon, renamed deploy/apply scripts, the #1 build-clobber gotcha re-stated against the new script names | Claude Code reads this on startup — it is the agent's source of truth. **Rewrite it LAST and thoroughly** (execution step 9). The old 1.20.4 facts are recorded as *archived*, not deleted history |
| `LEGACY\REBRANDING-GUIDE.md` (lines 1, 3, 22, 41–52, 87–95, 107, 126, 138, 144–145) | `# MRS Launcher — Helios Fork Rebranding Guide`; prescriptions `'Helios Launcher' -> 'MRS Launcher'`, `'helioslauncher' -> 'mrslauncher'`, appId `com.mrs.launcher`, package name `mrs-launcher`, `MRS railway theme`, `MRS logo`, etc. | FoundryMTR equivalents (`com.foundrymtr.launcher`, `foundrymtr-launcher`) — or supersede the guide with a pointer to **this** document | The guide's own instructions bake in the old brand. **Keep its explicit warning to never rename `helios-core`/`helios-distribution-types`** |
| `LEGACY\README.md` | legacy branding strings + the old `Server IP:` line | FoundryMTR branding; address `<SERVER_ADDRESS>`; MC 1.21.4 target | |
| `LEGACY\HOSTING-GUIDE.md` | the GitHub-Pages-era hosting instructions (`estenevs2025.github.io/mrs-dist`, `.r2.dev` suggestion, blanket CORS, GitHub Releases installers) | Superseded — rewrite as a pointer to `foundrymtr-site/docs/CLOUDFLARE_SETUP_PLAN.md` §5–§8 (R2 layout + cache rules are canonical there) | Keep its one correct insight: launcher CORS read must allow `*` (Electron `app://` origin) |
| `LEGACY\QUICK-START.md` / `LEGACY\WALKTHROUGH.md` | legacy brand, `MRSLauncher-build` paths, `estenevs2025.github.io` / `YOUR-DOMAIN.com/mrs` URLs, upstream clone steps | FoundryMTR equivalents, `launcher\` paths, `files.foundrymtr.com` URLs | |
| `branding\BRAND-IDENTITY.md` (lines 1, 7, 36, 69) | `# MRS Launcher — Brand Identity`; `The MRS launcher takes visual cues...`; `--mrs-signal #E8252B Signal red — the MRS identity color`; `the MRS wordmark` | FoundryMTR equivalents; var name `--fmtr-signal`; **the transit/rail metro narrative is KEPT** — MTR gameplay is the product, only the old name dies | |
| `branding\INTEGRATION-GUIDE.md` (lines 1, 62, 89–138) | `# MRS Branding`; `Helios -> MRS renames in REBRANDING-GUIDE.md`; `MRS-themed screenshots`; `window title shows "MRS Launcher" (not "Helios Launcher")` | FoundryMTR equivalents; window-title check → `FoundryMTR Launcher` | |
| `BUILD\docs\sample_distribution.json` + upstream docs | WesterosCraft example servers/text | **Left as-is** — upstream reference material, excluded from the packaged app by `electron-builder.yml` `files:` filter | The §8 fantasy-string grep sanctions hits here only |

---

## 4. File & folder renames

| From | To | References that must be updated |
|---|---|---|
| `LEGACY\MRSLauncher-build\` (the doubly-nested build dir) | `REPO2\launcher\` | Every `$BuildDir`/`$build` constant: `build-windows.ps1` (line 37), the `build-scripts\` duplicate (line 37 — being consolidated away), `build-unix.sh` `BUILD_DIR` (line 42), `apply-mrs-redesign.ps1` (lines 21–22, 27), `deploy-mrs-redesign.ps1` (lines 8, 15–19), and the entire legacy `CLAUDE.md` path table. The upstream `.git` (38 MB Helios pack history) is **dropped** at fold-in |
| `LEGACY\` (the doubly-nested project root itself) | `REPO2\` (`docs\`, `launcher\`, `distribution\`, `branding\`, `scripts\`) | The hardcoded absolute fallbacks `C:\Users\user1\Downloads\LANDrop\mrs-launcher\mrs-launcher\MRSLauncher-build` inside `apply-mrs-redesign.ps1` (line 22) and `deploy-mrs-redesign.ps1` (line 17) are **deleted**, and the legacy `CLAUDE.md` "Project root" path is rewritten |
| `LEGACY\mrs-theme.css` (root staging — the LIVE theme) | `REPO2\branding\foundrymtr-theme.css` | Deploy script `Copy-Item` source+dest (line 49) + the theme-header PASS sentinel (line 55); `app.ejs` `<link href>` (line 31); both build scripts' theme-link injection; legacy `CLAUDE.md` theme path |
| `BUILD\app\assets\css\mrs-theme.css` (runtime copy) | `REPO2\launcher\app\assets\css\foundrymtr-theme.css` | Regenerated from staging by the deploy script; `app.ejs` link |
| `LEGACY\branding\css\mrs-theme.css` (design-archive palette) | `REPO2\branding\css\foundrymtr-theme.css` | `INTEGRATION-GUIDE.md` / `BRAND-IDENTITY.md` references. **Not deployed** — mark it clearly as design history; the deploy script reads `branding\foundrymtr-theme.css` |
| `LEGACY\mrs-news.js` (root staging) | `REPO2\branding\foundrymtr-news.js` — **full ASCII rewrite, not a copy** (§3.4) | Deploy `Copy-Item` (line 50) + the `mrsWireToggle`→`fmtrWireToggle` PASS sentinel (line 57); `landing.ejs` script tag (line 241, injected by deploy line 123); legacy `CLAUDE.md` news path |
| `BUILD\app\assets\js\mrs-news.js` (runtime copy) | `REPO2\launcher\app\assets\js\foundrymtr-news.js` | Regenerated by deploy; `landing.ejs` script tag |
| `LEGACY\mrs_station.jpg` (root staging) | `REPO2\branding\foundrymtr_station.jpg` | Deploy `Copy-Item` (line 51) + the `>1KB` PASS check; CSS `background-image: url(../images/backgrounds/foundrymtr_station.jpg)`; legacy `CLAUDE.md` station path |
| `BUILD\app\assets\images\backgrounds\mrs_station.jpg` / `mrs_station.png` | `REPO2\launcher\app\assets\images\backgrounds\foundrymtr_station.jpg` / `.png` | CSS background url; deploy copy dest; check the theme for any `.png`-variant reference |
| `LEGACY\deploy-mrs-redesign.ps1` | `REPO2\scripts\deploy-foundrymtr-redesign.ps1` | The new repo-2 `CLAUDE.md` workflow section (#1 gotcha names this script); QUICK-START/WALKTHROUGH mentions. Contents rebranded per §3.5. ASCII/BOM-free |
| `LEGACY\apply-mrs-redesign.ps1` | `REPO2\scripts\apply-foundrymtr-redesign.ps1` | Doc/script references; contents per §3.5. ASCII/BOM-free |
| `LEGACY\build-windows.ps1` **+** `LEGACY\build-scripts\build-windows.ps1` (two copies) | **ONE** file: `REPO2\scripts\build-windows.ps1` | Consolidate; delete the duplicate. Contents per §3.5 |
| `LEGACY\build-scripts\build-unix.sh` | `REPO2\scripts\build-unix.sh` | Contents per §3.5 |
| `LEGACY\distribution\` | `REPO2\distribution\` | `distribution.json` regenerated per §3.2; `populate_distribution.py` URL prefixes |
| `LEGACY\branding\` | `REPO2\branding\` | SVG/render changes per §3.6 |
| Upstream-named images (`SealCircle.png`, `logo_320x320.png`, `LoadingSeal.png`, `build\icon.ico/.icns/.png`, `icon_*.png`) | **KEPT by filename** — content re-rendered via `branding\render_branding.py` with the FoundryMTR mark (regenerate roundel/wordmark/SealCircle/icons) | None — that is the point: EJS and electron-builder references stay valid untouched |
| `LEGACY\mrs station.jpeg` (root stray, with a space) + `LEGACY\mrs_station.jpg` root duplicate beyond the staging one | **DELETE** | Stray root-level station images; the staging copy in `branding\` is the only source |
| `BUILD\app\assets\images\backgrounds\mrs_station_old.jpg` | **DELETE** | Stale variant |
| `BUILD\app\assets\images\LoadingSeal - Copy.png` | **DELETE** | `"... - Copy"` duplicate |
| `BUILD\electron-install.log` | **DELETE** (+ gitignore) | Build artifact; embeds old names/paths |
| `LEGACY\inject-fake-account.ps1`, `LEGACY\fix-fabric-loader.ps1` | Triage at fold-in: migrate to `REPO2\scripts\` only if still needed for 1.21.4 dev, else drop | Dev utilities outside the audit's brand scope; if kept, sweep them with the §8 greps like everything else |

---

## 5. Identifier changes & coordination risks

All 12, with the locked resolution for each:

| # | Identifier | From → To | Risk & resolution |
|---|---|---|---|
| 1 | **appId** | `com.mrs.launcher` (scripts) + upstream `helioslauncher` (electron-builder.yml) → `com.foundrymtr.launcher` | Normally changes installed-app identity, the Windows uninstall/registry entry, and the electron-updater channel. **No public release has ever shipped → no installed base → no update-channel break.** Change it everywhere in one pass: electron-builder.yml, `$Config.AppId`, `APP_ID`, docs |
| 2 | **Server profile id** | `mrs-main-1.20.4` → `foundrymtr-1.21.4` | **HIGH — server-side lockstep.** The id keys the launcher's per-server instance folder AND must match the server-side/Nebula distribution generation (`g server foundrymtr 1.21.4 ...`). Also embeds the MC bump (server already live on 1.21.4, Fabric 0.19.3, the 7-mod set). Regenerate and publish the manifest in lockstep |
| 3 | **Distribution URL** | `https://estenevs2025.github.io/mrs-dist/distribution.json` → `https://files.foundrymtr.com/helios/distribution.json` | **EXTERNAL ordering:** the manifest must be live at the R2 URL **before** any launcher build pointing at it ships, or every client fails to load the distro index. (The bucket exists but no manifest is published at the URL yet — this is a publish-ordering rule, not a claim) |
| 4 | **News URL** | `https://estenevs2025.github.io/mrs-dist/news.txt` (+ `rss: https://YOUR-DOMAIN.com/mrs/news.xml`) → `https://files.foundrymtr.com/news/news.txt` (both the JS constant and the `rss` field) | **EXTERNAL:** content must exist at the new URL or The Dispatch shows "Wire down." Owner action §9. Cache `max-age=300` + purge on update |
| 5 | **Discord image keys** | `mrs_logo` / `mrs_seal` → `foundrymtr_logo` / `foundrymtr_seal` | **EXTERNAL — Discord Portal:** key strings must exactly match uploaded Rich Presence art-asset names or RPC images break. Owner action §9 |
| 6 | **Discord shortId** | `MRS` → `FoundryMTR` | Cosmetic; display-only (`Server: {shortId}`) |
| 7 | **Discord clientId** | `REPLACE_WITH_DISCORD_APP_ID_IF_YOU_WANT_RICH_PRESENCE` → `<DISCORD_CLIENT_ID>` placeholder, real id from the owner | **EXTERNAL:** owner must create the Discord application. Nothing breaks today — the clientId was never set, so RPC is simply off |
| 8 | **npm package name** | guide-prescribed `mrs-launcher` → `foundrymtr-launcher` | Low — `package.json` is already correct; just align the guide. **Never** rename `helios-core` / `helios-distribution-types` deps or require() paths |
| 9 | **User data dir** | `.helioslauncher` → `.foundrymtrlauncher` **with one-time migration** | Normally a silent data-loss risk (orphans accounts/settings/game files). **Decided: rename.** Justified because no public release exists — only the owner's test installs — and the owner wants zero legacy brand on user machines. Migration code below; runs before anything reads `dataPath` |
| 10 | **Azure client id** | `6809b695-eb71-43f8-8fa5-5e9c7d7b33de` → **unchanged** | It is an app identifier, not a secret. Azure app approval is a pending owner action (§9), independent of the rebrand. Login fails as expected until Microsoft approves |
| 11 | **Autoconnect server address** | old hardcoded IP:port → `<SERVER_ADDRESS>` | Server-side coordination: confirm the live 1.21.4 server address at publish (§9). Scrub the old IP from distribution.json, mockup.html, README, CLAUDE.md |
| 12 | **Product copyright** | `Copyright © 2018-2026 Daniel Scalzi` (product field) → `Copyright (c) 2026 FoundryMC Services LLC` | **LEGAL:** only the *product* copyright field changes. The upstream HeliosLauncher MIT license and Daniel Scalzi copyright are **retained in LICENSE/NOTICE** — stripping them would violate the MIT terms |

### Data-dir migration (the exact code)

In `launcher\app\assets\js\configmanager.js`, replacing line 10 — this must execute at module load, before any other code touches `dataPath`:

```javascript
// FoundryMTR data dir, with one-time migration from the legacy upstream dir.
// '.helioslauncher' below is the historical on-disk name (the move source),
// not branding — it is the sanctioned literal documented in REBRAND_TO_FOUNDRYMTR.md.
const legacyDataPath = path.join(sysRoot, '.helioslauncher')
const dataPath = path.join(sysRoot, '.foundrymtrlauncher')
try {
    if (fs.existsSync(legacyDataPath) && !fs.existsSync(dataPath)) {
        fs.renameSync(legacyDataPath, dataPath) // same volume: atomic dir move
    }
} catch (err) {
    // Never crash the launcher on migration. Worst case: a fresh data dir.
    console.error('One-time data dir migration failed; starting fresh.', err)
}
```

Rules: migrate only when the old dir exists **and** the new one does not (idempotent; never overwrites); a failed rename degrades to a fresh start, never a crash.

---

## 6. Gotchas — read before touching anything

All thirteen. Each one is real and most have already cost debugging time.

1. **G1 — BUILD SCRIPTS RE-INTRODUCE THE OLD BRAND ON EVERY RUN.** `build-windows.ps1` (root **and** the `build-scripts\` duplicate), `build-unix.sh`, `deploy-mrs-redesign.ps1`, and `apply-mrs-redesign.ps1` each have their own branding step that re-patches `package.json` / `ipcconstants.js` / `distromanager.js` and re-copies CSS/EJS on every run. The deploy script literally force-writes the title `Foundry SMP - MRS` **three times** (app.ejs, index.js, lang files). Update the `$Config` blocks AND the literal branding strings in **all** of these in the same pass, or the next rebuild silently restores `com.mrs.launcher`, the GitHub-Pages distro URL, and the old titles.
2. **G2 — TWO COPIES OF THE WINDOWS BUILD SCRIPT.** Root `build-windows.ps1` and `build-scripts\build-windows.ps1` carry identical old config. **Consolidate to exactly one** (`scripts\build-windows.ps1`); a forgotten stale copy re-brands on its next run.
3. **G3 — ALL `.ps1` FILES MUST STAY PURE ASCII AND BOM-FREE.** PowerShell 5.1 mangles non-ASCII; the deploy script even strips a leading BOM on read. No em-dashes, no curly quotes, no copyright sign in any script — write `Copyright (c)` in `.ps1`/`.yml` strings. (Markdown docs may keep em-dashes; scripts may not.)
4. **G4 — THE NEWS JS IS ALREADY ENCODING-CORRUPTED.** The staging news JS contains smart/curly quotes throughout (lines 15–60) — it is **syntactically invalid** today. Rewrite `foundrymtr-news.js` with ASCII quotes; a naive brand find/replace ships broken JS.
5. **G5 — KEEP UPSTREAM MIT + DANIEL SCALZI ATTRIBUTION.** Never strip the HeliosLauncher MIT license or Scalzi copyright from LICENSE/NOTICE. Rebrand only the *product* copyright/maintainer/vendor fields. Never rename the `helios-core` / `helios-distribution-types` npm packages or their `require()` paths, and never touch `node_modules`.
6. **G6 — SERVER PROFILE ID + AUTOCONNECT NEED SERVER-SIDE LOCKSTEP.** `foundrymtr-1.21.4` must match the server-side/Nebula-generated distribution (the real manifest is generated, not the hand-written staging file), and the MC bump means Fabric loader 0.19.3 + the 7-mod set, not the archived 1.20.4/0.19.2/11-mod facts. The autoconnect address is independent of branding — confirm `<SERVER_ADDRESS>` at publish.
7. **G7 — NEWS + DISTRIBUTION URLS MOVE TO R2.** The `estenevs2025.github.io/mrs-dist` family is replaced by `files.foundrymtr.com` endpoints. Publish content at the new URLs **before** shipping a launcher that points at them, or clients fail to load the distro and The Dispatch shows nothing. Never a `.r2.dev` URL anywhere.
8. **G8 — THE LEGACY CLAUDE.md IS ITSELF FULL OF THE OLD BRAND.** ~25 occurrences: title, server narrative, every build-dir/distro path, the old server id, the GitHub identity + hosting URLs, the `$Config` block, asset filenames, the Nebula command, and the workflow gotchas. It is read by Claude Code on startup — rewrite it **last and thoroughly** as the repo-2 `CLAUDE.md` (execution step 9).
9. **G9 — DEPLOY PASS SENTINELS ARE BRAND-COUPLED.** The deploy script verifies itself by matching the CSS header substring `STATION-BOARD SIGNAGE THEME` (brand-neutral — **KEPT**) and the JS function name `mrsWireToggle` (renamed → **update the sentinel to `fmtrWireToggle`**). Renaming the function without the sentinel produces false FAILs — this exact coupling already bit the project once.
10. **G10 — DOM IDs RENAME IN LOCKSTEP OR THE WIDGET SILENTLY BREAKS.** The injected brand block ids (`mrsBrand`, `mrsBrandTitle`, `mrsBrandSub`, `mrsNews`, `mrsNewsTab`, `mrsNewsClose`, `mrsNewsMast`, `mrsNewsDate`, `mrsNewsBody`, `mrsNewsLoading`, `mrsNewsError`) live in the **deploy/apply scripts** (the injection source), the news JS (`getElementById`), the theme CSS, and the generated EJS. The owner rejected the "leave internals alone" path — rename every one to `fmtr*` in all four places in the same pass (full table §3.4).
11. **G11 — THE BUILD DIR IS HALF-REBRANDED ACROSS THREE LAYERS.** `package.json` already says FoundryMTR while `electron-builder.yml` still says `helioslauncher`/Scalzi; `landing.ejs` mixes FOUNDRY/MTR/SMP/legacy; `app.ejs` says `Foundry Launcher V1.0.0`; `_custom.toml` says FoundryMTR (with wrong versions) while `en_US.toml` says `Foundry SMP - MRS`; the staging distribution.json is fully legacy-branded. **Treat staging + scripts as source of truth and regenerate the build dir** — never assume any build-dir file is clean.
12. **G12 — UPSTREAM FANTASY-REALM LEFTOVERS EXIST TOO.** `Sailing to Westeros!` / `Exploring the Realm!` (replaced with the transit flavor, §3.3), the `WELCOME TO WESTEROSCRAFT` welcome block (replaced), and upstream wiki/issue links (repointed). The upstream `docs\sample_distribution.json` reference material stays as-is — it is not shipped (excluded by the electron-builder `files:` filter).
13. **G13 — THE DATA-DIR RENAME IS A SILENT DATA-LOSS RISK CLASS.** Renaming `.helioslauncher` orphans existing users' accounts/settings/game files. Decided and de-risked here: no public release exists, and the one-time migration in §5 ships in the same commit as the rename. Do not ship the rename without the migration.

Plus the standing repo rule: **hardcoded absolute fallback paths to the old Downloads location** (`C:\Users\user1\Downloads\LANDrop\...` in both redesign scripts) are deleted, not repointed — scripts resolve paths relative to `$PSScriptRoot`.

---

## 7. Execution order

The rebrand happens **during the fold-in**. The legacy tree (`LEGACY\`) is never modified — it stays as the untouched archive until step 13 is verified.

1. **Copy source** — `BUILD\` → `REPO2\launcher\` (excluding `node_modules`, `dist`, the upstream `.git` history, `electron-install.log`); `LEGACY\distribution\` → `REPO2\distribution\`; `LEGACY\branding\` → `REPO2\branding\`; staging theme/news/station files → `REPO2\branding\`; scripts → `REPO2\scripts\`; docs → `REPO2\docs\`.
2. **Folder/file renames** — apply every row of §4 (theme/news/station/script filenames, deletions, the single surviving Windows build script).
3. **Config files** — `electron-builder.yml` (appId, productName, artifactName x2, copyright, maintainer/vendor, publish blocks), `package.json` (author, license, homepage, bugs, repository), `dev-app-update.yml` (generic provider → R2).
4. **Runtime JS** — `distromanager.js` (distro URL x2), `configmanager.js` (data dir + migration block), `processbuilder.js` (Xdock x2), `ipcconstants.js` (comment; Azure id untouched), `settings.js` (release-check URL), `uicore.js` (darwindownload URL).
5. **EJS + lang** — `app.ejs`, `landing.ejs` (via the scripts where injected), `en_US.toml` (fallback title, flavor strings, support links), `_custom.toml` (decorated title with corrected versions, welcome block, settings links).
6. **Theme CSS + news JS** — rename + rebrand both theme copies and the design-archive copy; **rewrite** the news JS in pure ASCII; apply the full `fmtr*` lockstep (§3.4) across CSS vars, classes, ids, functions, and the `FOUNDRYMTR_NEWS_URL` constant.
7. **Build/deploy/apply scripts** — `$Config` blocks, literal branding steps, copy sources/dests, injected HTML block, title force-writes, PASS sentinels (`fmtrWireToggle`; STATION-BOARD header kept), deletion of absolute fallbacks. ASCII/BOM-free check on every `.ps1`.
8. **Branding sources** — `render_branding.py`, the three SVGs, `mockup.html`; then **re-render** all PNGs/icons (filenames unchanged).
9. **Docs** — README, REBRANDING-GUIDE, HOSTING-GUIDE (supersede → Cloudflare plan), QUICK-START, WALKTHROUGH, BRAND-IDENTITY, INTEGRATION-GUIDE; **finally rewrite the legacy `CLAUDE.md` as the repo-2 `CLAUDE.md`** (new paths, new canon, new workflow names).
10. **Delete stale artifacts** — `electron-install.log`, `LoadingSeal - Copy.png`, `mrs_station_old.jpg`, root-level stray station images (`mrs station.jpeg` etc.); triage the two leftover dev `.ps1` utilities.
11. **VERIFY** — run the full §8 gate. Zero unsanctioned hits or stop and fix.
12. **Build + smoke test** — `npm install` in `launcher\`; run `scripts\deploy-foundrymtr-redesign.ps1` (expect all PASS); `npm start` (title check); `npm run dist:win` (installer name check); data-dir migration check.
13. **Commit** — single fold-in commit in `foundrymtr-launcher-dist`. Only after this is verified may the legacy archive tree be retired.

---

## 8. Verification gate

Run from `C:\Users\user1\Desktop\Launcher_Site_Cloudflare_FoundryMTR\foundrymtr-launcher-dist`. **Every grep below must come back empty unless a sanctioned survivor is listed.**

### 8.1 The legacy-token sweep (the big one)

```powershell
rg -i "mrs" --hidden `
  --glob '!node_modules' --glob '!.git' `
  --glob '!LICENSE*' --glob '!NOTICE*' `
  --glob '!docs/REBRAND_TO_FOUNDRYMTR.md'
```

**Expected: ZERO hits** (rg exit code 1). The only sanctioned survivors of the legacy token in the whole repo are (a) the upstream LICENSE/NOTICE attribution files if they happen to contain it (they should not — they carry Helios/Scalzi text, not the legacy brand) and (b) **this document**, which quotes the find-targets by design. Any other hit is an unfinished rename. This catches `mrsNews*`, `mrs-theme`, `com.mrs.launcher`, `MRSLauncher-build`, `--mrs-*`, `mrs_station`, `mrs-dist` — everything.

### 8.2 The companion sweeps

```powershell
# Old GitHub-Pages identity URL family — expect ZERO hits anywhere (incl. this doc's exclusion lifted):
rg -i "estenevs2025\.github\.io" --glob '!node_modules' --glob '!.git' --glob '!docs/REBRAND_TO_FOUNDRYMTR.md'

# Placeholder-domain leftovers — expect ZERO:
rg "YOUR-DOMAIN" --glob '!node_modules' --glob '!.git' --glob '!docs/REBRAND_TO_FOUNDRYMTR.md'

# Upstream appId/data-dir token — expected hits ONLY:
#   LICENSE / NOTICE (upstream attribution),
#   launcher/app/assets/js/configmanager.js (the single '.helioslauncher' migration move-source literal),
#   docs/REBRAND_TO_FOUNDRYMTR.md (this file).
rg -i "helioslauncher" --glob '!node_modules' --glob '!.git'

# Upstream author/repo URLs — expected hits ONLY in LICENSE / NOTICE (and lockfile metadata if any):
rg -i "dscalzi" --glob '!node_modules' --glob '!.git' --glob '!docs/REBRAND_TO_FOUNDRYMTR.md'

# Upstream fantasy-realm strings — expected hits ONLY under launcher/docs/ (unshipped upstream samples):
rg -i "Westeros|Sailing to|Exploring the Realm" --glob '!node_modules' --glob '!.git' --glob '!docs/REBRAND_TO_FOUNDRYMTR.md'

# Old title and old appId — expect ZERO:
rg "Foundry SMP" --glob '!node_modules' --glob '!.git' --glob '!docs/REBRAND_TO_FOUNDRYMTR.md'

# Forbidden host — expect ZERO anywhere, ever:
rg "r2\.dev" --glob '!node_modules' --glob '!.git'

# Smart-quote corruption is gone — expect ZERO in all shipped JS/CSS:
rg -n "[‘’“”]" launcher/app/assets/js launcher/app/assets/css branding
```

> Note: `helios-core` / `helios-distribution-types` in `package.json`/lockfile do **not** match the `helioslauncher` pattern — they are real dependency names and are untouched by design.

### 8.3 Script hygiene (ASCII + BOM)

```powershell
Get-ChildItem scripts -Filter *.ps1 | ForEach-Object {
  $bytes = [IO.File]::ReadAllBytes($_.FullName)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { "BOM: $($_.Name)" }
  if (($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) { "NON-ASCII: $($_.Name)" }
}
```

**Expected: no output.**

### 8.4 Build + runtime checks

```powershell
# 1. Deploy pass — every check must PASS (incl. the fmtrWireToggle and STATION-BOARD sentinels):
powershell -ExecutionPolicy Bypass -File scripts\deploy-foundrymtr-redesign.ps1

# 2. Launch:
Set-Location launcher; npm start
```

- **Window title check:** the title bar reads exactly `FoundryMTR Launcher V1.0.1 (MC 1.21.4 - MTR-NG 4.1.0)` (version per `package.json`). No Fabric-API-as-loader string, no `1.4.1`.
- The Dispatch tab renders (the rewritten ASCII JS parses; with no feed published yet it shows its empty/wire-down state, not a script error in DevTools).

```powershell
# 3. Installer filename check:
Set-Location launcher; npm run dist:win
Get-ChildItem dist\FoundryMTR-Setup-*.exe, dist\*.blockmap
```

**Expected:** `FoundryMTR-Setup-<ver>.exe` + `.blockmap` — matching the canonical R2 key `launcher/releases/win/<version>/FoundryMTR-Setup-<ver>.exe`.

```powershell
# 4. Data-dir migration check (one-time rename):
New-Item -ItemType Directory "$env:USERPROFILE\.helioslauncher" -Force | Out-Null
Set-Content "$env:USERPROFILE\.helioslauncher\migration-canary.txt" "canary"
if (Test-Path "$env:USERPROFILE\.foundrymtrlauncher") { Rename-Item "$env:USERPROFILE\.foundrymtrlauncher" ".foundrymtrlauncher.bak" }
# launch the app once, quit, then:
Test-Path "$env:USERPROFILE\.foundrymtrlauncher\migration-canary.txt"   # must be True
Test-Path "$env:USERPROFILE\.helioslauncher"                             # must be False
```

(Restore your real data dir from `.foundrymtrlauncher.bak` afterwards if you made one.)

### 8.5 Release-time QA reminders (from the Cloudflare plan)

- Verify Fabric loader `0.19.3` resolves on the Fabric Maven before any release.
- Manifests (`distribution.json`, `latest*.yml`, `news.txt`) are uploaded **last**, after binaries are uploaded and hash/size verified; versioned keys are write-once; purge the exact manifest URLs on publish.
- No artifact, page, or manifest may contain `r2.dev`.

---

## 9. Open owner actions

Everything in §1–§8 is decided and executable by an agent. These four items are genuinely external and block only their own feature — nothing else:

| # | Action | Blocks | Detail |
|---|---|---|---|
| 1 | **Create the Discord application** and upload Rich Presence art assets named exactly `foundrymtr_logo` and `foundrymtr_seal`; supply the application id to replace `<DISCORD_CLIENT_ID>` | Discord rich presence only | Until then RPC is simply disabled (the clientId was never set historically — nothing regresses) |
| 2 | **Azure app approval** for Microsoft login (submission via `aka.ms/mce-reviewappid`) | Real Microsoft login | The wired client id `6809b695-eb71-43f8-8fa5-5e9c7d7b33de` is kept (app identifier, not a secret); approval is independent of the rebrand |
| 3 | **Confirm the autoconnect server address** to replace `<SERVER_ADDRESS>` before `distribution.json` is published | Publishing the manifest | The server is confirmed live on MC 1.21.4; only the address string needs confirmation at publish time |
| 4 | **Publish news content** at `https://files.foundrymtr.com/news/news.txt` (once the R2 bucket + custom domain exist per the Cloudflare plan — none created yet) | The Dispatch panel content | Format unchanged from the legacy feed; future option (not built now): generate from D1 `changelog_entries` via the site API |

---

*FoundryMTR Launcher — rebrand specification. This file is the single sanctioned home of the legacy brand strings. After execution, the §8 gate is the law: zero legacy tokens outside this document and the upstream license attribution.*
