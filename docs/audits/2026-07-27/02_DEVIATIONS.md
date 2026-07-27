# 02 · Deviations — 2026-07-27

Audited against **Ka0s WoW Addon Standard v2.11.0 (2026-07-26)**.

Deviation IDs are stable per-addon (`BL-NN`) and reused across runs. IDs `BL-01`…`BL-05` come from
the 2026-07-26 run; `BL-06`…`BL-10` are new this run. A resolved deviation keeps its ID and is
recorded as closed rather than deleted.

## Summary

| ID | Section | Severity | Status | Summary |
|---|---|---|---|---|
| BL-01 | options-ui-§5 / layout-§3 | MUST | **Resolved** | Logo asset now ships as `.tga` with sources beside it. |
| BL-02 | documentation-§1 item 6 | SHOULD | Open | No `## Screenshots` section — nothing captured yet. |
| BL-03 | toc-file-§1 | MUST (conditional) | Not yet applicable | No `X-Curse-Project-ID`; the addon is unpublished. |
| BL-04 | localization-§3 | SHOULD | Accepted | No user-facing string routes through `NS.L`. |
| BL-05 | *(process)* | — | **Resolved** | The addon's row is now in the collection roster. |
| BL-06 | options-ui-§1 | MUST | Open | Canvas panels define no `OnCommit` / `OnDefault` / `OnRefresh`. |
| BL-07 | savedvariables-§2 | MUST | Open (accept or fix) | No `defaults/Profile.lua`; all defaults live in `defaults/Global.lua`. |
| BL-08 | documentation-§3 / §5 | SHOULD | Open | `docs/agent-context.md` is context pack v2.6.0, one release behind. |
| BL-09 | documentation-§5 / debug-logging-§2 | SHOULD | Open | `ARCHITECTURE.md` still lists the mono-font glyph as a deviation; v2.11.0 sanctions it. |
| BL-10 | slash-commands-§5 | SHOULD | Open | `/bl reset` echoes an ad-hoc line instead of the shared `key = value` formatter. |

**Counts (open findings only): MUST failures 2 · SHOULD failures 4 · conditional/accepted 2 ·
resolved since last run 2.**

---

## BL-01 · Logo asset missing — RESOLVED

**Rule.** `options-ui-§5` requires the landing page's logo shipped as `.tga`/`.blp` under
`media/logos/` with the editable source beside it; `documentation-§1` item 3 requires it in the
README.

**State.** Closed. `media/logos/bankledger.logo.tga` now ships alongside `.jpg`, `.png` and a
256px derivative. `NS.Constants.LOGO_PATH` (`core/Constants.lua:211`) resolves, the landing page
renders it at 300px (`settings/Panel.lua:587-593`), and the README image resolves
(`README.md:8`). `docs/ARCHITECTURE.md` ▸ *Logo art* documents the asset set.

**Action.** None. Retained for history.

---

## BL-02 · No `## Screenshots` section

**Rule.** `documentation-§1` item 6 — SHOULD, and MUST once published. When present its relative
order must be preserved (immediately after `## What's new`, before `## Usage`).

**State.** Still absent. `media/screenshots/` exists and is empty. The README goes straight from
`## What's new in 0.1.0` to `## Usage`.

**Fix direction.** Capture the ledger window (History and Insights tabs), the Current Banking
Session window and both settings sub-panels; drop them in `media/screenshots/` and insert a captioned
`## Screenshots` section between `## What's new` and `## Usage`, before first publish.

---

## BL-03 · No `X-Curse-Project-ID`

**Rule.** `toc-file-§1` — a MUST **once published on CurseForge**; `X-Wago-ID` and `X-WoWI-ID` are
MAY.

**State.** Not published (no git tags, no CurseForge listing), so the line is correctly absent, as
are the two optional ids. Not a failure today.

**Fix direction.** Add `## X-Curse-Project-ID: <id>` after `## X-Standard:` — keeping the
Curse → Wago → WoWI order — in the same change as the first publish, together with the README's
CurseForge version badge (`documentation-§1` badge #2, which slots between `[wow]` and `[license]`).

---

## BL-04 · No strings route through `NS.L`

**Rule.** `localization-§3` requires `enUS.lua` at minimum; `localization-§1/§2` govern the seam's
shape. Wrapping strings is not itself mandated, but the seam exists to be used.

**State.** `locales/enUS.lua:6` ships the metatable-fallback `NS.L`; `locales/PostLoad.lua` ships the
alias seam. Both are empty — every label, tooltip and chat line is hardcoded English. This is an
**accepted scope decision for v0.1.0**, recorded in the locale file itself
(`locales/enUS.lua:8-13`). The `localization-§3` MUST (ship `enUS.lua`) is satisfied.

**Fix direction.** A later localization pass wraps call sites as `NS.L["…"]` and adds locale-gated
files. No call site has to move, which is the point of standing the seam up now.

---

## BL-05 · Not in the collection roster — RESOLVED

**Rule.** `NEW_ADDON.md` step 8 — add the addon's row to `WowAddonStandards/standards/ADDONS.md`.

**State.** Closed. `standards/ADDONS.md` now carries the row
`| Ka0s Bank Ledger | ../../BankLedger/ | https://github.com/tusharsaxena/BankLedger |`, verified in
the copy fetched for this run.

**Action.** None. Retained for history.

---

## BL-06 · Settings canvas panels define no `OnCommit` / `OnDefault` / `OnRefresh`

**Section.** `options-ui-§1` · **Severity: MUST** (the canonical pattern's entry-point contract).

**State.** `createPanel` (`settings/Panel.lua:114-131`) builds each canvas `Frame` and sets only
`panel.name`; nothing anywhere in `settings/` assigns `OnCommit`, `OnDefault` or `OnRefresh`. All
three panels — the landing page, `General` and `Filters` — are registered without them
(`settings/Panel.lua:745`, `775`, `801`).

**Why it matters.** The canonical `options-ui-§1` snippet sets all three on the frame handed to
`Settings.RegisterCanvasLayoutCategory`, because Blizzard's Settings framework invokes them on the
registered canvas: `OnCommit` when the panel is applied, `OnDefault` when the Settings window's own
footer *Defaults* control fires, `OnRefresh` when the canvas is re-shown. With them absent the
Settings-window Defaults path does not reach `NS.Schema`-backed state — the addon's own header
Defaults button (`settings/Panel.lua:752`, `782`) is the only route — and an unguarded framework
call on a missing method is an avoidable error surface.

**Fix direction.** In `createPanel`, set `panel.OnCommit = function() end`,
`panel.OnRefresh = function() end`, and `panel.OnDefault` wired to the panel's own defaults action —
`P:RestoreDefaults()` for `General`, the confirm-gated filter clear for `Filters`, a no-op for the
landing page. Reuse the already-parked `panel.defaultsOnClick` closure so the framework path and the
header button can never diverge.

---

## BL-07 · No `defaults/Profile.lua`

**Section.** `savedvariables-§2` (with `layout-§1`) · **Severity: MUST** — currently an undeclared
deviation.

**State.** `defaults/` contains only `Global.lua`. `NS.defaults` has a `global` table and no
`profile` table (`defaults/Global.lua:6-42`), and `AceDB:New("BankLedgerDB", NS.defaults, true)`
(`core/Database.lua:6`) therefore creates a profile namespace with no defaults in it. Every setting
resolves against `NS.db.global` (`settings/Schema.lua:9`, `165`, `179`).

**Why it is this way.** Deliberate and reasoned: a bank ledger is inherently cross-character — you
deposit on one alt and withdraw on another — so a per-character profile would split the very history
the addon exists to join up (`defaults/Global.lua:3-5`). The design decision is sound; what is
missing is that the standard names `defaults/Profile.lua` as the required home for defaults and the
addon does not carry a recorded deviation for departing from it.

**Fix direction — two options, the user picks.**
1. **Record it as an accepted deviation** (the likely answer): add a bullet to
   `docs/ARCHITECTURE.md` ▸ *Documented deviations* naming `savedvariables-§2` / `layout-§1` and the
   account-wide rationale, and note it in this bundle. No code change.
2. **Raise it upstream**: `savedvariables-§2` currently assumes a profile-scoped addon; an
   account-wide addon has no honest `Profile.lua` to write. Propose that the standard permit
   `defaults/Global.lua` as the sole defaults file for account-wide addons, after which Bank Ledger
   conforms as-is.

Do **not** create an empty `defaults/Profile.lua` to satisfy the letter of the rule — an empty
defaults file that nothing reads is worse than a recorded deviation.

---

## BL-08 · `docs/agent-context.md` is one context-pack release behind

**Section.** `documentation-§3` / `documentation-§5` · **Severity: SHOULD**.

**State.** The file is the standard's context pack dropped in verbatim, headed
`# New Ka0s Addon — Context Pack (v2.6.0, 2026-07-20)` (`docs/agent-context.md:14`). The standard is
now v2.11.0 (2026-07-26) and its pack is at v2.7.0. The dropped copy therefore predates the
v2.11.0 amendments — the **lazy-`OnShow` Defaults-button MUST** (`options-ui-§5`, anti-pattern #42)
and the **second sanctioned mono-font use for a missing glyph** (`debug-logging-§2`). The addon's
*code* already implements both (`settings/Panel.lua:97-111`; `core/Constants.lua:74-77`), so the
brief an agent reads is behind the code it is briefing on.

**Fix direction.** Re-fetch `standards/NEW_ADDON_CONTEXT.md` and re-drop it wholesale, preserving the
existing repo-specific HTML comment header at `docs/agent-context.md:1-12`. Do not hand-edit the
body — the header itself says to re-drop rather than patch.

---

## BL-09 · `ARCHITECTURE.md` records a deviation the standard now sanctions

**Section.** `documentation-§5` (docs in sync) with `debug-logging-§2` · **Severity: SHOULD**.

**State.** `docs/ARCHITECTURE.md:422-437` lists "*The vendored mono font is used for the direction
glyph*" under **Documented deviations**, with a rationale about baseline alignment versus Blizzard's
arrow textures. Standard v2.11.0 adopted exactly that argument: `debug-logging-§2` now sanctions the
vendored mono font for "an individual glyph the default WoW font lacks … e.g. ▲/▼ `U+25B2`/`U+25BC`
direction markers in a table cell", and states an audit **MUST NOT** flag it. What the doc calls a
deviation is now the standard's own rule.

**Fix direction.** Move the entry out of *Documented deviations* — either delete it, or restate it as
a one-line note under the mono-font discussion pointing at `debug-logging-§2` as the sanctioning
rule. If BL-07 is accepted as a deviation, that entry replaces this one in the section.

---

## BL-10 · `/bl reset` echo bypasses the shared `key = value` formatter

**Section.** `slash-commands-§5` · **Severity: SHOULD** (the no-drift intent; `reset` is not named
in the rule's `list`/`get`/`set` list).

**State.** `Sl:CliReset` (`settings/Slash.lua:247`) prints
`path .. " reset to " .. Sl.FormatSchemaValue(row, def)` — the *value* goes through the shared
formatter, but the line is assembled ad hoc and carries **no colour**, so a reset echo renders in
plain white while the byte-identical `get`/`set` echo two functions away renders gold-key /
white-value through `Sl.FormatKV` (`settings/Slash.lua:194`, `218`). Similar plain-text lines exist
for the usage/error paths, which the rule does allow.

**Fix direction.** Have `CliReset` read the value back after `NS.Schema:Set` and echo through
`Sl.FormatKV(path, Sl.FormatSchemaValue(row, NS.Schema:Get(path)))`, exactly as `CliSet` does — one
line, and it also makes the echo reflect any clamping. Extend `tests/test_slash.lua` to pin the
colour codes on the reset line.
