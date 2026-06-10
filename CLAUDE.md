# CLAUDE.md — FoundryMTR Launcher (foundrymtr-launcher-dist)

> Read automatically by Claude Code on startup. Single source of truth for this
> repo's context, workflow rules, and the gotchas that have already cost real
> debugging time. Read it fully before touching anything.

## 1. What this project is

The **FoundryMTR Launcher** — a custom-branded Minecraft launcher for
**FoundryMTR**, a modded Minecraft Transit Railway (MTR / MTR-NextGen) survival
server. Fork of dscalzi's HeliosLauncher (Electron; upstream MIT retained in
`launcher/LICENSE.txt` + `launcher/NOTICE`). Players install it, it
auto-downloads Fabric loader + the mod set, and launches straight into the server.

**Canonical target (do not "correct" from web searches):**
- Minecraft **1.21.4** (the server is live on it)
- Fabric loader **0.19.3** (explicit pin; QA gate = verify it resolves on the
  Fabric Maven before any release; never silently substitute)
- MTR-NextGen **4.1.0** (beta jar `mtr-nextgen-fabric-mc1.21.4-mtr4.1.0-beta.1-ng.dev1.jar`, pin by hash)
- The **7-mod client set**: mtr-nextgen, fabric-api 0.119.4, sodium 0.6.13,
  lithium 0.15.3, ferritecore 7.1.3, Debugify 1.1, modmenu 13.0.4
- Server profile id: `foundrymtr-1.21.4` · display name `FoundryMTR`
- Autoconnect address: `<SERVER_ADDRESS>` — confirm with the owner at publish
- Java 21 (MC 1.21.4 requirement)

**Canonical identity** (full table: `docs/REBRAND_TO_FOUNDRYMTR.md` §2):
productName `FoundryMTR Launcher` · appId `com.foundrymtr.launcher` ·
publisher `FoundryMC Services LLC` · data dir `.foundrymtrlauncher` (one-time
migration from the legacy dir is in `configmanager.js`) · internal prefix `fmtr`.

**Canonical URLs (Cloudflare R2 — never `.r2.dev`, never GitHub Pages):**
- Distribution: `https://files.foundrymtr.com/helios/distribution.json`
- News feed: `https://files.foundrymtr.com/news/news.txt`
- Self-update: `https://files.foundrymtr.com/launcher/releases/{win,mac,linux}/latest*.yml`
  (versioned installers in `<version>/` subfolders — `FoundryMTR-Setup-<ver>.*`)

## 2. Repo layout

| What | Path |
|---|---|
| Electron app (vendored source) | `launcher\` |
| EJS templates | `launcher\app\` (app.ejs, frame.ejs, landing.ejs, …) |
| Theme CSS (deployed copy) | `launcher\app\assets\css\foundrymtr-theme.css` |
| News JS "The Dispatch" (deployed copy) | `launcher\app\assets\js\foundrymtr-news.js` |
| Station background (deployed copy) | `launcher\app\assets\images\backgrounds\foundrymtr_station.jpg` |
| Window-title lang file | `launcher\app\assets\lang\_custom.toml` (`[ejs.app] title`) |
| **Theme/news/station SOURCES** | `branding\` (edit here, then deploy) |
| Distribution staging + hashing tool | `distribution\` |
| Build/deploy scripts | `scripts\` |
| Planning docs (integration, release, rebrand) | `docs\` |

The legacy pre-rebrand tree lives outside this repo as an untouched archive in
the parent working directory (its path is recorded in
`docs/REBRAND_TO_FOUNDRYMTR.md`) — never edit it, never copy from it without
applying that rename spec.

## 3. THE #1 GOTCHA — scripts write the brand/theme into the build

`scripts\build-windows.ps1` enforces the canonical config (distro URL, Azure id)
and `scripts\deploy-foundrymtr-redesign.ps1` re-copies CSS/JS and re-patches the
EJS **on every run**. Hand edits to deployed copies under `launcher\app\assets\`
are overwritten.

### The correct workflow (follow exactly)
1. Edit theme/news sources in **`branding\`**, scripts in **`scripts\`**.
2. Run **`scripts\deploy-foundrymtr-redesign.ps1`** — self-verifying; every
   check must PASS. Its sentinels: the CSS header substring
   `STATION-BOARD SIGNAGE THEME` and the JS function `fmtrWireToggle`. If you
   rename either, update the script's Check lines in the same pass.
3. Launch with `npm start` from `launcher\`.
4. The `fmtr*` DOM ids / CSS vars / function names are **lockstep-coupled**
   across the deploy script (injection source), `foundrymtr-news.js`,
   `foundrymtr-theme.css`, and `landing.ejs`. Rename in all four at once or the
   news widget silently breaks.

### Other resolved gotchas (do not re-introduce)
- The upstream inline base64 `<style>` background in `app.ejs` beats external
  CSS — it must stay commented out (the deploy script enforces this).
- CSS background path must be `../images/backgrounds/` (relative to the CSS at
  `app/assets/css/`).
- The real window title comes from `_custom.toml` `title=` —
  `FoundryMTR Launcher V<ver> (MC 1.21.4 - MTR-NG 4.1.0)`. The deploy script
  deliberately does NOT blanket-rewrite lang titles (a legacy regex once
  clobbered them all).
- Fonts load via Google Fonts `<link>` (CSP blocks `@import`).
- All `.ps1` files stay **pure ASCII, BOM-free** (PowerShell 5.1 mangles
  non-ASCII). ASCII `(c)`, straight quotes, hyphens. Markdown may keep
  em-dashes; scripts may not.
- `[DEP0040] punycode` deprecation warning on launch is harmless.

## 4. Distribution / hosting

- The production `distribution.json` is **generated** (Nebula preferred — the
  workspace must be recreated; see `docs/HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md`
  §3) or filled by `distribution\populate_distribution.py` (staging fallback).
- Module types: the loader module is type **`Fabric`** (id
  `net.fabricmc:fabric-loader:0.19.3`); mods are **`FabricMod`**. There is no
  `FabricLoader` type in `helios-distribution-types` — that mis-typing is what
  the schema-validation gate catches.
- Hosting is **Cloudflare R2 only** (`files.foundrymtr.com`). Release ordering
  is law: binaries → verify hash/size → manifests LAST → purge exact URLs →
  fresh-install + update tests. Versioned keys are write-once.
  Full runbook: `docs/RELEASE_WORKFLOW_PLAN.md`.
- **No jars/installers in git** — the NG jar (~137 MB) exceeds GitHub's 100 MB
  hard limit; everything binary lives in R2.

## 5. Never touch

- `helios-core` / `helios-distribution-types` npm packages and their
  `require()` paths — real upstream dependencies, not brand strings.
- `launcher/LICENSE.txt` and the upstream attribution in `launcher/NOTICE`
  (MIT terms).
- `launcher/docs/` upstream reference material (unshipped; excluded by the
  electron-builder `files:` filter).
- The legacy brand token must never reappear anywhere except
  `docs/REBRAND_TO_FOUNDRYMTR.md` (the sanctioned spec) — run its §8 grep gate
  after any sweeping change.

## 6. Open / pending items (owner actions)

1. **Discord application** — create it, upload Rich Presence art named exactly
   `foundrymtr_logo` / `foundrymtr_seal`, supply the client id to replace
   `<DISCORD_CLIENT_ID>` in `distribution\distribution.json`.
2. **Azure app approval** for Microsoft login (`aka.ms/mce-reviewappid`). The
   wired client id is kept; login fails until Microsoft approves.
3. **Confirm `<SERVER_ADDRESS>`** before the first `distribution.json` publish.
4. **Publish `news.txt`** at the canonical URL or The Dispatch shows "Wire down."
5. **Re-render brand PNGs** — run `branding\render_branding.py` (needs Python +
   Pillow + a bold TTF) to regenerate `icon_*.png`, `logo_320x320.png`,
   `SealCircle.png`, `wordmark.png` with the FMTR/FOUNDRYMTR marks; then refresh
   `launcher\build\` icons and `launcher\app\assets\images\SealCircle.*`.
   Until then the rendered art still shows the OLD wordmark (content, not filenames).

## 7. Working style

- Edit in `branding\`/`scripts\`, deploy with the deploy script, test with
  `npm start` from `launcher\`.
- When something breaks, read the actual file and console output before
  changing anything — most past bugs were file-transfer or stale-assumption
  errors, not logic errors.
- Companion repo: `foundrymtr-site` (the website/admin/D1/R2 control plane).
  Canonical Cloudflare values live in its `docs/CLOUDFLARE_SETUP_PLAN.md`.
