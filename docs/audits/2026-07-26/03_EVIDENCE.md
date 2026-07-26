# 03 · Evidence — 2026-07-26

Where each conformance claim in `01_CURRENT_STATE.md` can be checked.

## Layout & TOC

| Claim | Evidence |
|---|---|
| Single modular layout | `core/ defaults/ settings/ locales/ modules/` at the repo root; no loose source files. |
| Fixed TOC field order | `BankLedger.toc` lines 1–13: Interface → Title → Notes → Author → Version → IconTexture → SavedVariables → OptionalDeps → DefaultState → Category-enUS → X-License → X-Standard. |
| Single Retail Interface | `BankLedger.toc:1` — `## Interface: 120007`. No comma list, no per-flavor TOC. |
| `#`-sectioned file listing | `BankLedger.toc` — `# Libraries` → `# Locales` → `# Core` → `# Defaults` → `# Modules` → `# Settings`, in load order. |
| Libraries listed directly | Eleven `libs\...` lines; no `embeds.xml`. |
| Libs vendored and committed | `libs/` holds all eleven folder-per-lib sets. `.pkgmeta` has no `externals:` block. |
| Lowercase subfolders | `core/`, `defaults/`, `settings/`, `locales/`, `modules/`, `libs/`, `media/`, `tests/`, `docs/`. |
| Typed media subfolders | `media/fonts/`, `media/logos/`, `media/screenshots/` — nothing loose in `media/`. |

## Architecture

| Claim | Evidence |
|---|---|
| `local addonName, NS = ...` in every file | Line 1 of all 20 first-party sources. No `_G[addonName]`. |
| Printer survives the AceConsole embed | `core/BankLedger.lua:12` reclaims `NS.Print` from `NS.Util.print` after `NewAddon`. Asserted by *"NS.Print survives the AceConsole embed"* in `test_util.lua`, against a mock that stamps the colliding `:Print`. |
| Closed message bus, one sender each | `docs/ARCHITECTURE.md` § Message bus. `NS.Filters` routes through `Database:FireLedgerChanged` rather than becoming a second sender. |
| Receivers own their bus target | `NS.NewBusTarget()` in `core/BankLedger.lua`; used by Ledger, Browser, Insights and Panel. Asserted by *"two consumers of one message both receive it"* in `test_database.lua`. |
| Schema as single source | `settings/Schema.lua` drives the panel, the slash CLI and the defaults reset; every write goes through `Schema:Set`. Boot validation asserted by *"every row's path resolves against the defaults table"*. |
| Deprecated APIs behind Compat | `core/Compat.lua` is the only file touching `C_Container`, `C_Item`, `C_AddOns`, guild-bank and void-storage globals. No `WOW_PROJECT_ID` anywhere. |
| Hot-path upvalue cache | `Ledger:RefreshUpvalues`, re-run on `SettingsChanged` and on a filter-list edit. Asserted by *"a list change re-caches the capture gate's upvalues"* in `test_filters.lua`. |

## Options UI, slash and debug

| Claim | Evidence |
|---|---|
| Eager category, lazy bodies | `Panel:Register` is called from `OnInitialize`; each panel body builds inside its first `OnShow`. |
| Landing page + subcategories | `RegisterCanvasLayoutCategory` for the landing page, `RegisterCanvasLayoutSubcategory` for General and Filters. |
| Exact layout constants | `settings/Panel.lua` — `PADDING_X 16`, `HEADER_TOP 20`, `HEADER_HEIGHT 54`, `DEFAULTS_W 110`, `LOGO_SIZE 300`, `ROW_VSPACER 8`, `BUTTON_PAIR_REL 0.492`, section spacers 10/6/26. |
| AceGUI Defaults button | `buildHeader` creates `AceGUI:Create("Button")` and reparents `btn.frame`, never a raw template button on the canvas. |
| Always-shown, inert scrollbar | `installAlwaysShownScrollbar` rebinds `FixScroll` and guards `MoveScroll`. |
| Combat refusal, not deferral | `Panel:Open` prints the canonical grey notice and returns; no `PLAYER_REGEN_ENABLED` replay anywhere. |
| Mandated chat tag | `NS.PREFIX = "\|cff00ffff[BL]\|r"` in `core/Namespace.lua`. Asserted by *"every chat line carries the cyan [BL] tag"* in `test_slash.lua`. |
| `list`/`get`/`set` output format | `Slash:BuildListLines` — green header, azure `[group]`, gold path, white value, 2/4-space indents, no trailing colon. Six assertions in `test_slash.lua`. |
| Secret-safe single printer | `NS.IsConcatSafe` probes `table.concat`, not `..`. Asserted by *"NS.Print never raises on a value that would break table.concat"* and *"NS.Debug never raises …"*. |
| Console shape | `modules/DebugLog.lua` — 700×344, DIALOG strata, `UISpecialFrames`, monospace at 10pt, `<ts> \| [tag] <msg>`, right-edge slider synced via `GetMaxScrollRange`/`GetScrollOffset`/`SetScrollOffset`, `N / 500 lines` counter, Clear + Copy. |
| Session-only debug state | `NS.State.debug`, never in SavedVariables. Asserted by *"the enabled state is never written to SavedVariables"*. |
| `[Init]` on enable, not login | `DebugLog:SetEnabled`. Asserted by *"emits an [Init] session summary on enable"* and *"emits no [Init] summary on disable"*. |
| One summary line per pass | `Ledger.MoveSummary` / `LedgerTable.RenderSummary`, both pure and both asserted. |
| Settings logged once at the seam | `Schema:Set` emits `[Set] <path> = <value>`; no reactor re-echoes it. |

## Tests, lint, packaging, docs

| Claim | Evidence |
|---|---|
| Headless harness | `tests/run.lua`, `tests/loader.lua`, `tests/wow_mock.lua`, twelve `test_*.lua` suites. |
| Green gate | `lua tests/run.lua` → 277/277; `luacheck .` → 0/0 in 20 files. |
| Generated inventory | `docs/test-cases.md`, produced by `lua tests/run.lua --list`. |
| `.pkgmeta` without externals | Root `.pkgmeta`; ignores `docs`, `tests`, `_dev`, `.luacheckrc`, `.gitignore`, `*.bak`. |
| Root docs | Full `README.md`, stub `CLAUDE.md`, `LICENSE` (MIT full text). |
| `docs/` quartet + generated doc | `agent-context.md`, `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`, `test-cases.md`. |
| No `TODO.md` | None at the root or under `docs/`. |
