# 03 · Evidence — 2026-07-27

Every claim in `01_CURRENT_STATE.md` and `02_DEVIATIONS.md` is sourced here with `file:line`
citations. Line numbers are as of the working tree at commit `d74f2e8`.

---

## Part A — Evidence for the deviations

### BL-01 (resolved) · Logo asset

| Claim | Evidence |
|---|---|
| Runtime `.tga` ships under `media/logos/` | `media/logos/bankledger.logo.tga` present (alongside `bankledger.logo.jpg`, `.png`, `.256.jpg`) |
| Constant points at it | `core/Constants.lua:211` — `C.LOGO_PATH = "Interface\\AddOns\\BankLedger\\media\\logos\\bankledger.logo.tga"` |
| Landing page renders it at 300px | `settings/Panel.lua:28` (`LOGO_SIZE = 300`), `settings/Panel.lua:589-592` |
| README references it | `README.md:8` — `![Logo](media/logos/bankledger.logo.jpg)` |
| Asset set documented | `docs/ARCHITECTURE.md:438` — `## Logo art` |

### BL-02 · No `## Screenshots`

| Claim | Evidence |
|---|---|
| README section list has no Screenshots | `README.md` H2s: `28:## What's new in 0.1.0`, `42:## Usage`, `96:## How the ledger works`, `113:## FAQ`, `126:## Troubleshooting`, `138:## Issues and feature requests`, `145:## Version History` |
| Folder exists and is empty | `media/screenshots/` — directory present, no files |

### BL-03 · No `X-Curse-Project-ID`

| Claim | Evidence |
|---|---|
| Metadata block ends at `X-Standard` | `BankLedger.toc:11-12` — `## X-License: MIT`, `## X-Standard: https://github.com/tusharsaxena/WowAddonStandards`; `BankLedger.toc:13` is blank |
| Addon is unpublished | `git tag` returns nothing; README badge row carries no CurseForge version badge (`README.md:3-6`) |

### BL-04 · No strings route through `NS.L`

| Claim | Evidence |
|---|---|
| `NS.L` seam exists with metatable fallback | `locales/enUS.lua:6` — `NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })` |
| Deliberately empty for v0.1.0 | `locales/enUS.lua:8-13` (comment recording the scope decision) |
| Alias seam ships empty too | `locales/PostLoad.lua:6-9` |
| Labels are hardcoded English | e.g. `settings/Schema.lua:18` `label = "Enable capture"`; `settings/Panel.lua:20-21` tagline; `settings/Panel.lua:101` `btn:SetText("Defaults")` |

### BL-05 (resolved) · Collection roster

| Claim | Evidence |
|---|---|
| Row present upstream | `WowAddonStandards/standards/ADDONS.md`, in-scope table: `\| Ka0s Bank Ledger \| ../../BankLedger/ \| https://github.com/tusharsaxena/BankLedger \|` (fetched for this run) |

### BL-06 · Canvas callbacks absent

| Claim | Evidence |
|---|---|
| `createPanel` sets only `name` | `settings/Panel.lua:114-131` — `local panel = CreateFrame("Frame", nil)` / `panel.name = title` / `panel:Hide()`; no `OnCommit`/`OnDefault`/`OnRefresh` assignment |
| No such assignment anywhere in the addon | `grep -rn "OnCommit\|OnDefault\|OnRefresh" settings/ modules/ core/ tests/` → **no matches** |
| Panels are registered without them | `settings/Panel.lua:745` `Settings.RegisterCanvasLayoutCategory(mainCtx.panel, ADDON_TITLE)`; `settings/Panel.lua:775` and `:801` `Settings.RegisterCanvasLayoutSubcategory(...)` |
| Rule text | `options-ui-§1` canonical snippet: `frame.OnCommit = function() end` / `frame.OnDefault = function() NS.Schema:ResetAll() end` / `frame.OnRefresh = function() end` |
| The addon's own defaults path is the only one wired | `settings/Panel.lua:752` `ctx.panel.defaultsOnClick = function() P:RestoreDefaults() end`; `settings/Panel.lua:782-788` (Filters) |

### BL-07 · No `defaults/Profile.lua`

| Claim | Evidence |
|---|---|
| `defaults/` holds only `Global.lua` | directory listing: `defaults/Global.lua` (42 lines) is the sole file; `BankLedger.toc:40-41` lists `# Defaults` → `defaults\Global.lua` only |
| `NS.defaults` has no `profile` table | `defaults/Global.lua:6-7` — `NS.defaults = NS.defaults or {}` / `NS.defaults.global = { … }`; no `NS.defaults.profile` anywhere in the repo |
| AceDB is still created profile-aware | `core/Database.lua:6` — `NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)` |
| Schema paths resolve against `global` | `settings/Schema.lua:9` (comment), `settings/Schema.lua:165` `S:WritePath(NS.db.global, path, …)`, `settings/Schema.lua:179` `S:ReadPath(NS.db.global, path)` |
| Rationale recorded in code | `defaults/Global.lua:3-5` — "a bank ledger is inherently cross-character … a per-character profile would split the very history the addon exists to join up" |
| Rule text | `savedvariables-§2`: "**MUST** declare in `defaults/Profile.lua`. **MUST** be the **only** place a default value is hardcoded." |
| Not currently listed as a deviation | `docs/ARCHITECTURE.md:422-437` — the *Documented deviations* section carries one entry only (the mono-font glyph) |

### BL-08 · Stale context pack

| Claim | Evidence |
|---|---|
| Pack version in the repo | `docs/agent-context.md:14` — `# New Ka0s Addon — Context Pack (v2.6.0, 2026-07-20)` |
| Current standard / pack version | `standards/STANDARDS.md:1` — `# Ka0s WoW Addon Standard (v2.11.0, 2026-07-26)`; its v2.11.0 changelog entry states the pack was "bumped to v2.7.0" |
| Missing amendment 1 (lazy Defaults button) | v2.11.0 changelog + `options-ui-§5`; the code already complies at `settings/Panel.lua:97-111` and `:755`, `:791` |
| Missing amendment 2 (glyph font exception) | v2.11.0 changelog + `debug-logging-§2`; the code already relies on it at `core/Constants.lua:74-77` |
| Re-drop is the prescribed maintenance | `docs/agent-context.md:8-11` — "When the standard moves on, re-drop this file rather than hand-editing it" |
| Four-place standards reference is otherwise intact | `docs/agent-context.md:466-474` — `## Hard rules cheat sheet (memorize)` opens with the conform-to-the-standard bullet pointing back to `../CLAUDE.md` |

### BL-09 · Stale documented deviation

| Claim | Evidence |
|---|---|
| Entry still listed as a deviation | `docs/ARCHITECTURE.md:422-437` — "**The vendored mono font is used for the direction glyph**, not only for the debug console … whose stated scope is the debug console and its copy boxes (debug-logging-§2)" |
| The glyph use in code | `core/Constants.lua:74-77` — `C.DirectionGlyph = { WITHDRAW = "\226\150\178", DEPOSIT = "\226\150\188" }` with the comment "WoW's default font has neither and renders a box" |
| Standard now sanctions it | `debug-logging-§2`, *Second sanctioned use*: "The vendored monospace font **MAY** also be used for an **individual glyph** … e.g. the ▲/▼ (`U+25B2`/`U+25BC`) direction markers in a data table's cell … An audit **MUST NOT** flag a glyph-scoped use of the vendored font." |
| The doc's own rationale is the standard's | Both cite Blizzard's uneven arrow-texture padding versus a glyph sitting on the label's baseline |

### BL-10 · `/bl reset` echo

| Claim | Evidence |
|---|---|
| Ad-hoc, uncoloured echo | `settings/Slash.lua:247` — `print(path .. " reset to " .. Sl.FormatSchemaValue(row, def))` |
| The shared formatter exists and is used elsewhere | `settings/Slash.lua:134-136` (`Sl.FormatKV`), used at `settings/Slash.lua:170` (list rows), `:194` (`get`), `:218` (`set`) |
| `set` reads the stored value back; `reset` echoes the default it passed in | `settings/Slash.lua:218` vs `settings/Slash.lua:245-247` |
| Rule text | `slash-commands-§5`: "the coloured **`key = value`** line (gold key + white value) **MUST** come from **one shared helper** … so the colouring can never drift between them" |

---

## Part B — Evidence for the compliance claims

### Layout, TOC, libraries

| Claim | Evidence |
|---|---|
| Modular layout, nothing loose at root | Tree: `core/` (7 files), `defaults/` (1), `settings/` (3), `locales/` (2), `modules/` (9), `libs/`, `media/`, `tests/`, `docs/`; root holds only `BankLedger.toc`, `README.md`, `CLAUDE.md`, `LICENSE`, `.luacheckrc`, `.pkgmeta` |
| No file over 1500 LOC | Largest: `modules/Browser.lua` 1170, `modules/LedgerTable.lua` 972, `modules/Insights.lua` 913, `settings/Panel.lua` 817, `modules/InsightsWidgets.lua` 813 |
| Typed media subfolders, nothing loose in `media/` | `media/fonts/{JetBrainsMono-Regular.ttf,OFL.txt}`, `media/logos/*`, `media/screenshots/`; `ls media/` shows only directories |
| Exact TOC field order | `BankLedger.toc:1-12` |
| Single Retail Interface | `BankLedger.toc:1` — `## Interface: 120007` |
| `[wow]` badge in lockstep | `README.md:3` — `WoW-Midnight_12.0.7-purple` |
| `#`-sectioned file listing in mandated order | `BankLedger.toc:14` `# Libraries`, `:27` `# Locales`, `:31` `# Core`, `:40` `# Defaults`, `:43` `# Modules`, `:54` `# Settings (last …)` |
| Libraries listed directly, no `embeds.xml` | `BankLedger.toc:15-25`; no `embeds.xml` anywhere in the repo |
| All eight mandatory libs vendored | `libs/`: `LibStub`, `CallbackHandler-1.0`, `AceAddon-3.0`, `AceDB-3.0`, `AceEvent-3.0`, `AceTimer-3.0`, `AceConsole-3.0`, `AceGUI-3.0` (+ `LibSharedMedia-3.0`, `LibDataBroker-1.1`, `LibDBIcon-1.0`) |
| Optional libs are actually used | LSM: `core/BankLedger.lua:29-30`; AceTimer: `modules/Browser.lua:661-663`, `:677-679`; AceConsole: `settings/Slash.lua:82-83` |
| No AceConfig/AceDBOptions vendored | `libs/` listing — absent, and no Profiles sub-page exists |
| No hard dependencies | `BankLedger.toc:8` — `## OptionalDeps:` only; no `## Dependencies:` line |

### Architecture

| Claim | Evidence |
|---|---|
| Namespace header in every file | e.g. `core/Namespace.lua:1`, `core/Util.lua:1`, `modules/DebugLog.lua:1`, `settings/Panel.lua:1` |
| No global namespace table | `grep -rn '_G\[addonName\]' core modules settings` → no matches |
| AceAddon promotion passes `NS` first | `core/BankLedger.lua:4` — `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")` |
| `NS.Print` reclaimed after the embed | `core/BankLedger.lua:13` — `if NS.Util and NS.Util.print then NS.Print = NS.Util.print end`; real printer at `core/Util.lua:151-159` |
| Per-receiver bus targets (anti-pattern #32) | Factory `core/BankLedger.lua:20-26`; consumers `modules/Browser.lua:1162-1164`, `modules/Ledger.lua:765`, `modules/Insights.lua:911-912`, `modules/SessionWindow.lua:652-659`, `settings/Panel.lua:411-419`, `:572-580` — none registers on `NS.bus` as self |
| One sender per message | `Ka0s_BankLedger_EntryAdded` → `core/Database.lua:77`; `_LedgerChanged` → `core/Database.lua:453`; `_SettingsChanged` → `settings/Schema.lua:21,36,64,74,88,96,108` (all inside schema `onChange`); `_SessionChanged` → `modules/Ledger.lua:456` |
| Messages documented | `docs/ARCHITECTURE.md:158-169` — table of name / sender / payload / consumers |
| Schema drives everything | `settings/Schema.lua:13-110` (rows), `:157-174` (`S:Set` single seam), `:176-180` (`S:Get`), `:190-202` (boot validation) |
| Boot validation is test-asserted | `settings/Schema.lua:201` returns the unresolved count; exercised in `tests/test_schema.lua` |

### SavedVariables

| Claim | Evidence |
|---|---|
| Single global `BankLedgerDB` | `BankLedger.toc:7`; `core/Database.lua:6` |
| `schemaVersion` declared in defaults | `defaults/Global.lua:14` — `schemaVersion = NS.SCHEMA_VERSION` |
| One source for the version | `core/Namespace.lua:13` — `NS.SCHEMA_VERSION = 2` |
| Migration runner ships and runs at init | `core/Database.lua:7` (`NS:RunMigrations()`), `core/Database.lua:14-33` |
| No `SavedVariablesPerCharacter` | `BankLedger.toc` — absent |

### Options UI

| Claim | Evidence |
|---|---|
| `Settings.RegisterCanvasLayoutCategory`, not the deprecated API | `settings/Panel.lua:745`; `grep InterfaceOptions_AddCategory` → no matches |
| Eager registration at load | `core/BankLedger.lua:36` — `if NS.Panel and NS.Panel.Register then NS.Panel:Register() end` inside `OnInitialize` |
| Landing page + subcategories | `settings/Panel.lua:737` (parent), `:775` (`General`), `:801` (`Filters`) |
| Landing page contents in order | logo `settings/Panel.lua:587-594`, tagline `:596-602`, "Slash Commands" `Heading` `:604-610`, one Label per `NS.COMMANDS` `:613-618` |
| Raw AceGUI, no AceConfigDialog | `settings/Panel.lua:6` `LibStub("AceGUI-3.0", true)`; `grep AceConfig` → no matches |
| Bodies build lazily on first `OnShow` | `settings/Panel.lua:739-744` (landing), `:754-774` (General), `:790-800` (Filters) |
| Defaults button is an AceGUI `Button` | `settings/Panel.lua:99` — `AceGUI:Create("Button")` |
| …and is built lazily in `OnShow` (v2.11.0 / anti-pattern #42) | `settings/Panel.lua:97-111` (`ensureDefaultsButton`), called first thing in each `OnShow` at `:755` and `:791`; intent parked at `:78`, callbacks parked at `:752` and `:782` |
| Region-list diagnostic verb exists | `settings/Panel.lua:628-704` (`P:Diagnose`), wired to `/bl debug panel` at `settings/Schema.lua:250-258` |
| Exact layout constants, named | `settings/Panel.lua:24-34` — `PADDING_X=16`, `HEADER_TOP=20`, `HEADER_HEIGHT=54`, `DEFAULTS_W=110`, `LOGO_SIZE=300`, `ROW_VSPACER=8`, `SECTION_TOP_SPACER/BOTTOM/H = 10,6,26`, `BUTTON_PAIR_REL=0.492` |
| Header shape | title `GameFontNormalHuge` at `(PADDING_X, -HEADER_TOP)` `settings/Panel.lua:66-68`; `Options_HorizontalDivider` tinted to the title `:70-74`; breadcrumb with `common-icon-forwardarrow` `:62-63`; Defaults at `TOPRIGHT (-PADDING_X, -HEADER_TOP)` `:105` |
| Body top inset −62 | `settings/Panel.lua:122` — `-(HEADER_HEIGHT + 8)` |
| Two-column schema-driven pairing | `settings/Panel.lua:325-369`; 0.5 widths at `:355-357`; `wide`/`soloRow` handling at `:348`, `:353` |
| Paired action buttons inset (anti-pattern #31) | `settings/Panel.lua:242-248` — `makePairButton` sets `BUTTON_PAIR_REL`; used at `:384` and `:761` |
| Section headings as AceGUI `Heading`, `GameFontNormalLarge` | `settings/Panel.lua:223-233` |
| Scroll insets | `settings/Panel.lua:207-208` — `TOPLEFT (PADDING_X-4, -8)`, `BOTTOMRIGHT (-(PADDING_X+12), 8)` |
| Always-shown, inert scrollbar (anti-pattern #30) | `settings/Panel.lua:139-199`; `MoveScroll` guard `:157-162`; permanent show branch `:172-180`; park-and-grey `:181-184` |
| In-place refresh, on-screen only (anti-pattern #39) | `refreshers` list `settings/Panel.lua:130`, populated at `:256`, `:271`, `:284`, `:312`, `:406`; run only when shown `:710-719`; structural rebuilders gated `:439-443`, `:576`, `:796-798` |
| Combat refusal with canonical wording | `settings/Panel.lua:809-813` — grey `cannot open settings during combat — Blizzard's category-switch is protected`, then `return` before `Settings.OpenToCategory` at `:814-816` |
| No defer-and-replay | `grep PLAYER_REGEN_ENABLED settings/` → no matches |

### Standalone windows

| Claim | Evidence |
|---|---|
| Plain non-secure frame | `modules/Browser.lua:924` — `CreateFrame("Frame", "BankLedgerWindow", UIParent, "BackdropTemplate")` |
| Movable / resizable / clamped, with bounds | `modules/Browser.lua:934-940` |
| `UISpecialFrames` | `modules/Browser.lua:1050-1051`; also `modules/SessionWindow.lua:554-555`, `modules/DebugLog.lua:160-161`, `:282-283`, `modules/Export.lua:258-259`, `:348-349` |
| Geometry persisted and restored | `modules/Browser.lua:107-160` (`settings.window = { point, x, y, w, h }`, `ResetWindow`) |
| Scale setting applied | `modules/Browser.lua:1046`, `:1079-1084`; schema row `settings/Schema.lua:52-65` |
| Single `SKIN` + `ApplySkin` seam, stock textures | `modules/Browser.lua:21-35`, `:67-85`; reused by the console `modules/DebugLog.lua:154`, `:280` |
| Row pooling | `modules/LedgerTable.lua:533-541` (`AcquireRow`), `:673-680` (`ReleaseAllRows`), `:827-843` (bind visible slice) |
| Window verbs + launcher | `settings/Schema.lua:208-210` (`show`/`hide`/`toggle`); LibDBIcon launcher in `modules/Browser.lua` with `minimap.hide` row at `settings/Schema.lua:24-29` |

### Preview mode

| Claim | Evidence |
|---|---|
| Preview verb exists and toggles | `settings/Schema.lua:220-229` — `/bl session` → `NS.SessionWindow:TogglePreview()` |
| Refuses to override a live session | `settings/Schema.lua:223-225` — `if on == nil then print("a real banking session is open …")` |
| Same render path | `modules/SessionWindow.lua` — preview rows feed the live row renderer; covered by `tests/test_sessionwindow.lua` |

### Slash commands

| Claim | Evidence |
|---|---|
| AceConsole registration, no `SLASH_*` | `settings/Slash.lua:81-84`; `grep 'SLASH_'` → no matches |
| 2-char verb + full-name alias | `settings/Slash.lua:82-83` — `"bl"` and `"bankledger"` |
| Table-driven dispatch, no `if/elseif` chain | `settings/Slash.lua:95-97` |
| Verb lower-cased, remainder case-preserved | `settings/Slash.lua:93-94` (`input:match("^(%S+)%s*(.-)$")`, `verb:lower()`) |
| Bare `/bl` prints help | `settings/Slash.lua:89-91` |
| Unknown verb → message + help | `settings/Slash.lua:98-99` |
| `version` verb present, TOC-sourced | `settings/Schema.lua:214`; `settings/Slash.lua:230-237`; `core/Compat.lua:13-21` |
| Mandated cyan tag, single constant | `core/Namespace.lua:18` — `NS.PREFIX = "\|cff00ffff[BL]\|r"`; applied once in `core/Util.lua:153` |
| No call site bypasses the shared printer | every emitting file opens `local print = NS.Print` — `settings/Slash.lua:4`, `settings/Schema.lua:5`, `settings/Panel.lua:4`, `modules/DebugLog.lua:5`, `modules/LedgerTable.lua`; no bare global `print(` site remains |
| Help header shape | `settings/Slash.lua:105-106` — `v<version> slash commands (/bankledger is an alias for /bl)` |
| Command rows gold / em-dash / white | `settings/Slash.lua:108` |
| `list` colour scheme | `settings/Slash.lua:154` header green `33ff99`; `:167` group azure `3399ff`; `:134-136` `FormatKV` gold `ffff00` / white `ffffff` |
| Indentation two/four spaces | `settings/Slash.lua:167` (`"  "`), `:170` (`"    "`) |
| Declared, testable group order | `settings/Slash.lua:146-147`, asserted in `tests/test_slash.lua` ("every declared /bl list group actually exists in the schema") |
| Type-aware shared value formatter | `settings/Slash.lua:117-130`; `fmt = "%.2fx"` on the scale row `settings/Schema.lua:54` |
| `set` reads back the stored value | `settings/Slash.lua:216-218` |
| Unknown path / usage lines | `settings/Slash.lua:186`, `:191`, `:200`, `:205`, `:241`, `:244` |
| No trailing colons | verified across `settings/Slash.lua:104-259` — no printed literal ends in `:` |

### Localization

| Claim | Evidence |
|---|---|
| Metatable fallback | `locales/enUS.lua:6` |
| Bag groups matched on `Enum.BagIndex` member **names** | `core/Constants.lua:109-142`, with the anchored, case-sensitive patterns and the rationale at `:97-108` |
| Item identity from `itemID` in the link | `core/Compat.lua:167-170` |
| Quality from colour hex → quality **id**, label from id | `core/Compat.lua:184-190`, `:194-201` |
| Bank type read by enum member name | `core/Compat.lua:78` — `Enum.BankType.Account` |
| No localized-string branch | `grep` for English display-string comparisons across `core/`, `modules/`, `settings/` → none |

### Events, frames, taint

| Claim | Evidence |
|---|---|
| AceEvent, guarded registration | `modules/Ledger.lua:731-737` (`RegisterEventSafely` with `pcall`), used at `:746`, `:749`, `:754`, `:757` |
| No per-module event frames | `grep 'CreateFrame("Frame")' … :RegisterEvent` → none; events go through the AceAddon object |
| Hot-path upvalue refresh | `modules/Ledger.lua:55` (`L:RefreshUpvalues`), re-run on settings change `:765` |
| Secret detection probes `table.concat`, not `..` | `core/Util.lua:130-133` |
| Sentinel substitution | `core/Util.lua:139-144` |
| Chat printer routes every arg through it | `core/Util.lua:151-158` |
| Debug sink routes every arg through it | `modules/DebugLog.lua:347-357` (`parts[i] = NS.SafeToString(...)` before `fmt:format`) |
| No secure writes / no `_G.ToggleX` assignment | `grep 'SetAttribute\|_G.Toggle'` → no matches |

### Compat

| Claim | Evidence |
|---|---|
| Sole caller of varying APIs, all presence-guarded | `core/Compat.lua:13-21`, `:49-52`, `:68-83`, `:88-102`, `:107-141`, `:153-162`, `:206-230` |
| No flavour branch | `grep WOW_PROJECT_ID` → no matches; `core/Compat.lua:5-7` states the rule |

### Debug console

| Claim | Evidence |
|---|---|
| Named `BackdropTemplate` frame, 700×344, `DIALOG` strata | `modules/DebugLog.lua:36-42` |
| Title bar, divider, close glyph | `modules/DebugLog.lua:44-77` |
| Reuses the main window's skin seam | `modules/DebugLog.lua:154` |
| `ScrollingMessageFrame`, 500 lines, mono 10pt, left, no fade | `modules/DebugLog.lua:94-107` |
| Mono font vendored + registered with LSM | `core/Constants.lua:204`; `core/BankLedger.lua:30`; `media/fonts/JetBrainsMono-Regular.ttf` + `media/fonts/OFL.txt` |
| Two pure formatters, mandated colours | `modules/DebugLog.lua:173-183` (`6f8faf` timestamp, `c9a66b` tag, `\|\|` literal pipe) |
| Copy buffer is colour-free and capped | `modules/DebugLog.lua:189-190`, `:291` |
| Copy/Clear | `modules/DebugLog.lua:223-228`, `:288-296` |
| Scrollbar with two-way sync and re-entrancy guard | `modules/DebugLog.lua:114-138` (`bar`, `OnValueChanged`, `_syncing`), `:201-212` (`UpdateScrollBar`) |
| Correct mixin API only; old C getters never called | `modules/DebugLog.lua:133`, `:204-206` use `GetMaxScrollRange`/`GetScrollOffset`/`SetScrollOffset`; `grep 'GetNumLinesDisplayed\|GetCurrentScroll'` → no matches |
| Bar always shown, inert when it fits | `modules/DebugLog.lua:211` — `bar:EnableMouse(maxOffset > 0)` |
| Line counter `N / MAX lines`, on every append and on Clear | `modules/DebugLog.lua:216-220`, called at `:192` and `:227` |
| Initial sync runs last in the build | `modules/DebugLog.lua:164-167`, after `RefreshHeader` (`:157`) and `UISpecialFrames` (`:160-162`) |
| Session-only flag, never persisted | `core/State.lua:25-26`; `defaults/Global.lua:41` (comment confirming exclusion) |
| Single `SetEnabled` seam with colour-coded ack | `modules/DebugLog.lua:314-331`; ack `:320` (`40ff40` / `ff4040`) |
| Console bracket at both transitions via raw append | `modules/DebugLog.lua:324` |
| `[Init]` summary on enable | `modules/DebugLog.lua:329`; built by `NS.InitSummary` at `core/Database.lua:44` |
| Header toggle green/red | `modules/DebugLog.lua:334-340` |
| Zero-alloc gate first | `modules/DebugLog.lua:348` |
| Coverage across flows | lifecycle `core/Database.lua:35`, `:44`; capture/skip `modules/Ledger.lua:441`, `:525`, `:535`, `:556`; store arming `modules/Ledger.lua:178`, `:573`, `:640`, `:662`, `:694`; settings `settings/Schema.lua:169-171`; panel failures `settings/Panel.lua:428-434` |
| Coalesced summaries, string-building behind the gate | `modules/Ledger.lua:525` and `:535` emit one line per pass via `L.DiffSummary` / `L.MoveSummary`; `modules/Ledger.lua:573`, `:640`, `:694` gate on `NS.State.debug` before building |
| Settings logged once, at the write seam | `settings/Schema.lua:169-171` (`[Set] <path> = <value>`); no downstream reactor re-echoes |
| Debug never goes to chat (anti-pattern #18) | `modules/DebugLog.lua:356` — sink calls `D:Add`, not `print` |

### Packaging, lint, testing

| Claim | Evidence |
|---|---|
| `.pkgmeta` shape, no `externals:` | `.pkgmeta:1-11` |
| Ignores `docs`, `tests`, `_dev`, lockfiles | `.pkgmeta:6-11` |
| `.luacheckrc` base config | `.luacheckrc:1-8` (`std`, `max_line_length`, `codes`, `exclude_files`, `ignore`) |
| Write-globals justified by comment | `.luacheckrc:31-36` |
| Green gate at audit time | `lua tests/run.lua` → `567 passed, 0 failed, 567 total`; `luacheck .` → `Total: 0 warnings / 0 errors in 22 files` |
| Harness shape | `tests/run.lua` (123), `tests/loader.lua` (30), `tests/wow_mock.lua` (387), 15 × `test_*.lua` |
| Generated inventory is authoritative | `docs/test-cases.md:621` `## Totals`, `:640` `\| **Total** \| **567** \|`; generation command documented at `docs/testing.md:81` |
| Badge in lockstep | `README.md:6` — `Tests-567%2F567_passing-green` |

### Documentation

| Claim | Evidence |
|---|---|
| Root ships exactly README + CLAUDE stub + LICENSE | root listing |
| Badge row order and templates | `README.md:3` wow, `:4` license, `:5` linked standard, `:6` tests — the published-version badge correctly absent pre-publish |
| README section order | `README.md` H2s at 28 / 42 / 96 / 113 / 126 / 138 / 145 (see BL-02 for the one gap) |
| `## What's new` matches the top Version History row | `README.md:28-41` vs `README.md:145-149` — both describe the 0.1.0 first release with the same feature set |
| `## Usage` has both subsections | `README.md:44` `### Slash commands` (command table), `:77` `### Settings panel` (Tab \| Covers table) |
| `## How <it> works` present | `README.md:96` — `## How the ledger works` |
| No `## Testing` section, no contributor material | `README.md` H2 list — absent |
| `CLAUDE.md` is a stub with the compliance section | `CLAUDE.md:1` H1, `:6` `## Standards compliance (read first)`; file is short and points into `docs/` |
| `docs/` quartet + generated inventory | `docs/agent-context.md`, `docs/ARCHITECTURE.md`, `docs/testing.md`, `docs/smoke-tests.md`, `docs/test-cases.md` |
| `ARCHITECTURE.md` carries the required sections | `docs/ARCHITECTURE.md:6` Overview, `:54` Module map, `:129` Settings schema, `:158` Message bus, `:179` Slash surface, `:205` Event subscriptions, `:407` Taint notes, `:476` Known limitations |
| `testing.md` covers gate, toolchain and both pointers | `docs/testing.md:6`, `:16`, `:70` (smoke-tests link), `:75-81` (test-cases link + `--list` command) |
| No `TODO.md` | `find . -name TODO.md` → no matches |
| Four-place standards reference | `BankLedger.toc:12`; `README.md:5`; `CLAUDE.md:6`; `docs/agent-context.md:466-474` |

### Audit history, versioning

| Claim | Evidence |
|---|---|
| Prior runs retained and untouched | `docs/audits/2026-07-26/` (5 files), `docs/reviews/2026-07-27/` (5 files) — neither modified by this run |
| This run is a new dated folder | `docs/audits/2026-07-27/` |
| Semver in TOC and code, single source for the schema version | `BankLedger.toc:5`; `core/Namespace.lua:7`, `:13` |
| Version cannot drift from the manifest | `settings/Slash.lua:230-233` reads TOC metadata first; pinned by `tests/test_slash.lua` ("/bl version and the help header report the same version") |
| Trunk-based | `git log` — linear history on `main`, no topic branches |
