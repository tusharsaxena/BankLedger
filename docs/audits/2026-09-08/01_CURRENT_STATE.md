# 01 · Current state — Ka0s Bank Ledger — 2026-09-08

**Audited against the Ka0s WoW Addon Standard v2.39.0 (2026-09-07).** Resolved from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` with `curl -fsSL`: line 1
of `standards/STANDARDS.md` reads `# Ka0s WoW Addon Standard (v2.39.0, 2026-09-07)`. All **26**
section files listed under `## Sections` were fetched and read, plus `AUDIT.md` and
`standards/ADDONS.md`.

**Repo state.** `master` at `40c4f866621d8fab6fd0bdd2dd20cb5ed573bd48`
(*Merge branch 'feat/2026-09-07-audit-review-remediation'*), working tree clean.

**Rule set used.** This repo has a `.toc` (`BankLedger.toc`), so it is audited as an **addon** —
the full section list — and not against `library-stack-§7`'s library applicability list
(`AUDIT.md` step 1).

**Why this run exists.** It is work item `M5-06` of the 2026-09-07 collection remediation cycle: the
measurement pass that checks the fifteen v2.39.0 amendments describe reality in the repository they
govern. Sixteen of those amendments were verified during M1 by grepping the standard for its own
keyword, which proves only that a token was typed.

---

## Layout (`layout`)

The mandated modular tree, whole: `core/` (13 files), `defaults/` (1), `settings/` (4), `locales/`
(2), `modules/` (8), `libs/`, `media/`, `tests/`, `docs/`. Folder casing is lower-case throughout.

`media/` holds **only** `logos/` and `screenshots/` — no `fonts/`, `icons/` or `textures/`, because
the monospace face and the mark catalog arrive inside `libs/LibKa0s/media/`
(`core/MediaSetup.lua:9-15` records that this addon used to ship its own copy and no longer does).

**The 1500-line cap, measured over the scope `layout-§1` now states** — every authored `.lua` the
repository tracks, `tests/` included, with `libs/` and `tests/_kit/` the carve-outs: **0 files over
the cap**, 3 in the 1000–1500 on-notice band (`tests/test_ledger.lua` 1478, `modules/Browser.lua`
1251, `modules/LedgerTable.lua` 1096). All three are recorded with dispositions in
`docs/automated-tests/RESULTS.md`.

## TOC (`toc-file`)

`BankLedger.toc` carries the metadata block in `toc-file-§1`'s exact order with no blank lines
inside it: `Interface: 120007` (single, latest Retail), `Title: Ka0s Bank Ledger`, `Notes`,
`Author`, `Version: 1.0.0`, `IconTexture`, `SavedVariables: BankLedgerDB`, `OptionalDeps`,
`DefaultState`, `Category-enUS: Misc`, `X-License: MIT`, `X-Standard`, `X-Curse-Project-ID: 1629058`.

`SavedVariables` declares **one** global, which is what `toc-file-§2` requires of an addon holding a
ratified `performance-§12` exemption — two when wired, one when exempt.

The file listing is `#`-sectioned in load order: `# Libraries`, `# Locales`, `# Core`, `# Defaults`,
`# Modules`, `# Settings`. `libs\LibKa0s\LibKa0s.xml` is listed **once**, last in `# Libraries`, with
a comment giving the reason; no individual `LibKa0s` `.lua` file appears.

**Position annotations, measured against `toc-file-§5`'s own denominator** (the set of positions that
actually are load-bearing, established by reading the seam files, not by counting lines): six
positions carry a comment naming what resolves — `libs\LibKa0s\LibKa0s.xml`, `core\ItemSetup.lua`,
`core\MediaSetup.lua`, `core\CoreSetup.lua`, `core\DebugLogSetup.lua`, `settings\OptionsSetup.lua` —
and two carry the conventional form, saying the position is free and why (`core\EnvSetup.lua`,
`core\PoolSetup.lua`). One load-bearing position is **not** annotated: see `BL-36`.

## Libraries (`library-stack`)

Vendored and committed, no `externals:`. Every vendored library is **reached**, by one of the three
ways `library-stack-§3` now names:

| Library | How it is reached |
|---|---|
| LibStub | `libs\LibStub\LibStub.lua`, everything else |
| CallbackHandler-1.0 | vendored lib → vendored lib (2 `LibStub("CallbackHandler-1.0")` sites under `libs/`) |
| AceAddon-3.0 | direct `LibStub` (`core/BankLedger.lua:3`) |
| AceEvent-3.0 | direct `LibStub` **and** the `NewAddon` mixin name string |
| AceTimer-3.0, AceConsole-3.0 | the `NewAddon` mixin name strings (`core/BankLedger.lua:4`) |
| AceDB-3.0 | direct `LibStub` (`core/Database.lua:6`) |
| AceGUI-3.0 | reached by `LibKa0s` Options at panel-build time (26 sites under `libs/LibKa0s/`) |
| LibSharedMedia-3.0 | reached by `LibKa0s-Media-1.0` |
| LibDataBroker-1.1, LibDBIcon-1.0 | direct `LibStub` |
| LibKa0s | nine majors wired; see below |

`libs/LibKa0s/` is the **whole** ship folder: 14 `.lua` files (the corrected v2.39.0 count),
`LibKa0s.xml`, `LICENSE` and the `media/` payload. Provenance is `CLAUDE.md:46` —
`Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT).` — and both `diff -r`
checks against the sibling checkout at tag `v1.27.0` are **empty**.

**The shared subsystems are consumed, not hand-rolled.** The addon owns a descriptor and a
degradation stub per module, in its own setup file, and nothing else: `core/CoreSetup.lua:37`,
`core/DebugLogSetup.lua:21`, `core/EnvSetup.lua:39`, `core/ItemSetup.lua:26`,
`core/MediaSetup.lua:45`, `core/PoolSetup.lua:20`, `settings/OptionsSetup.lua:26`,
`settings/Slash.lua:133`, plus `LibKa0s-Widgets-1.0` at `modules/Browser.lua:5` and
`modules/Export.lua:14`. There is no `modules/DebugLog.lua`, no widget-maker file, no dispatcher and
no local test framework. `LibKa0s-Perf-1.0` is deliberately unwired under the ratified
`performance-§12` exemption.

No `core/LSMPatch.lua`, so `library-stack-§9` / anti-pattern **#76** — new this version — does not
apply here.

## Architecture, SavedVariables

AceAddon bootstrap at `core/BankLedger.lua:3-4`; private `NS` from the file vararg; a closed message
bus carrying **4** distinct messages (`Ka0s_BankLedger_EntryAdded`, `…_LedgerChanged`,
`…_SessionChanged`, `…_SettingsChanged`), each with both a sender and a receiver.

AceDB opens account-wide at `core/Database.lua:6`; `NS:RunMigrations()` runs at `:7` before any
ledger read; `schemaVersion` is seeded and advanced at `:28-40`. `defaults/Global.lua` carries a
`global` table only — the ratified `savedvariables-§2` deviation.

## Settings panel (`options-ui`)

One registered page, `General` (`settings/Panel.lua:666`), rendered through the library's
`O.RenderTabbedSchema` (`:695`); the landing page is the host's own `buildMainContent` handed to
`O.SetMainBuilder` (`:655`), which `options-ui-§13` exempts. No Profiles sub-page (a MAY, declined).

The strip reads **Master controls · Capture · Interface · History · Filters** — five tabs, 16 rows,
6 of them composed by `H.MasterControls` and spliced to the head of `S.Schema`
(`settings/Schema.lua:248-252`). Inside `Filters` a **secondary** strip divides Blacklist from
Whitelist, its selection kept per primary tab and session-only; there is no third level.

No `type = "color"` row anywhere (`settings/OptionsSetup.lua:87` says so and says what adding one
would cost), so the class-color companion and the `disabledIf` prohibition are inapplicable. No
`LSM30_Font` / `LSM30_Border` / `LSM30_Statusbar` control and no broadcast meta row. No reorder list.
The only `InlineGroup` in `settings/` is the store-grid **inside the scroll**
(`settings/Panel.lua:74`), not a box around chrome-band controls, so anti-pattern **#72** does not
apply.

The Options degradation stub is the **hollow composer** shape v2.39.0 ratified:
`settings/OptionsSetup.lua:192` answers `MasterControls` with an empty row list and a no-op tail,
and four sibling composers are stubbed beside it. No host copy of a composed block exists.

## Slash (`slash-commands`)

`NS.COMMANDS` at `settings/Schema.lua:407` carries **15** verbs. Dispatch is
`LibKa0s-Slash-1.0`'s over that table (`settings/Slash.lua:133`); the chat tag is
`NS.PREFIX = "|cff00ffff[BL]|r"` (`core/Namespace.lua:18`) — cyan, as mandated.

## Debug console (`debug-logging`)

`LibKa0s-DebugLog-1.0`'s, wired from `core/DebugLogSetup.lua`; the descriptor carries
`name = addonName` (`:61`) and `addonName = addonName` (`:74`), which is what `debug-logging-§13`
asks for so the console's own controls resolve the shared marks. `/bl debug`, `/bl debug on|off`,
`/bl debug panel` and `/bl debug scan` all route through that one console — no debug surface of the
addon's own.

## Windows (`standalone-windows`)

Three host windows — the ledger (`modules/Browser.lua:1047`), the session window
(`modules/SessionWindow.lua:485`) and the export modal (`modules/Export.lua:362`) — each registered
into `UISpecialFrames`, none secure, so no combat gate is owed. A fourth close control belongs to
the **library's** `CopyWindow` (`modules/Export.lua:252`), which this addon does not pass a
`makeCloseButton` to and which therefore draws Core's own.

**The reasoned decline of the `MakeCloseButton` wrapper was checked against all four conditions
`standalone-windows` now states**, and all four hold: (1) host windows only; (2) the same catalog
`close` mark through `NS.Icon` (`modules/Browser.lua:104`); (3) exactly one host factory
(`modules/Browser.lua:98`) with every host title bar reaching it and no two-argument
`lib.MakeCloseButton(...)` anywhere outside `libs/`; (4) a register row, added this cycle. Nothing
is filed against the decline itself. What is filed is a set of in-code and doc claims that
contradict condition 1 — `BL-38`.

## Tests, lint, records

- `luacheck .` → **`Total: 0 warnings / 0 errors in 61 files`**. `.luacheckrc:10`'s `exclude_files`
  is byte-identical to `lint`'s v2.39.0 template, and the harness global sits in a
  `files["tests/"]` stanza (`:70-72`), not in top-level `read_globals`. No top-level `ignore`; the
  12 narrowed `212/self` stanzas each name one file and one variable.
- `lua tests/run.lua` → **`849 passed, 0 failed, 0 skipped, 849 total`**. `docs/test-cases.md`
  carries 849 entries and `README.md:7`'s badge reads `849%2F849`.
- Kit revision **15** (`tests/_kit/framework.lua:20`), so `tests/_kit/test_eol.lua` — the gate
  `line-endings-§7` now MUSTs — is present and green.
- `docs/automated-tests/` holds 8 frozen bundles; the newest, `20260908-181253/`, was produced today
  at commit `14c86de` and carries an `ANALYSIS.md` that notes, once, how many earlier bundles carry
  none.

## `.gitattributes` (`line-endings`)

Present at the repo root, 81 lines, CRLF. The pin is `* text=auto eol=crlf` at `:26` — correct for a
repo that ships Lua to the client. `*.sh text eol=lf` at `:34`. 20 `binary` marks. The first 81
lines are **byte-identical** to `line-endings-§5`'s canonical client-bound body, and there is nothing
below them — no `line-endings-§5 appendix`, and no register row written for one.

## Root doc set

`README.md`, `CLAUDE.md`, `DEPENDENCIES.md`, `LICENSE`, and no fourth doc. No `CHANGELOG.md`, no
`TODO.md`.

Three cheap checks `AUDIT.md` step 3 asks for, all clean: the standard badge is the **bare**
`![Standard](…)` at `README.md:6` and is not wrapped in a link; the README carries **no**
bundled-library inventory — no `## Libraries`-family heading, no roll-call in the intro prose, no
`## Credits` at all; and the LibKa0s provenance line is in `CLAUDE.md:46` and **not** in `README.md`.

`CLAUDE.md` carries `## Standards compliance (read first)` and points at the register as the single
home of a ratified deviation.

## `docs/` shape (`documentation-§3`)

19 live `.md` files. **Tier 1** — all six present under their canonical names. **Tier 2** — three
present (`slash-dispatch.md` at 15 verbs against a threshold of 8; `midnight-quirks.md`;
`compat-layer.md` at **13** shims, counted with `documentation-§3`'s own published grep against the
new threshold of three) and four carrying a *Not applicable* row whose trigger is stated and, checked
against the code, has not fired (`message-bus.md` — 4 messages against >10; `profiles.md` — no
profile control ships; `debug.md` — no surface beyond the library console; `perf-analysis/README.md`
— the `performance-§12` exemption).

`## Documentation map` is present at `docs/ARCHITECTURE.md:169` with **four** tables in order —
Required, Conditional, **Verification and record**, Addon-specific. The fourth holds exactly the six
rows `documentation-§3` names. Every live `.md` under `docs/` appears in exactly one table; frozen
and generated directories are named once each; no row points at a file that does not exist. No
justification note for the extra table survives, which is what v2.39.0 asks a repo to delete rather
than the table. The hub registers itself, which is a **MAY** an audit must not file in either
direction, so it is not filed.

Hub shape: 238 lines against the ~400 guide; the longest mandated section is `## Documentation map`
at 48 lines against ~60. No retired `file-index.md`, `conventions.md`, `complexity.md`, or
`docs/perf-runs/`. No `docs/pending/LEDGER.md`.

## The recorded-deviation register

`docs/ARCHITECTURE.md:218` carries five ratified rows: `performance-§12`, `savedvariables-§2`,
`localization-§1`, `standalone-windows`, `options-ui-§12`. Two of them — `localization-§1` and
`standalone-windows` — were added this cycle and close `BL-04` and `BL-28`. All three
`audit-review-history` MUSTs were run; the results are in `03_EVIDENCE.md`.

The issue store is GitHub issues on this repo: 15 issues, every one carrying a `state:` label and a
`severity:` label, and not one carrying a `[status]` title prefix.
