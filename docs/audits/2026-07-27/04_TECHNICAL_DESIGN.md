# 04 · Technical design — remediation — 2026-07-27

Design for closing the open deviations in `02_DEVIATIONS.md`. Keyed to deviation IDs. This is a
**plan**; nothing here has been applied. The audit itself changed no addon code.

Two of the six open items are **decisions**, not code changes (BL-07 needs the user to choose
between accepting a deviation and raising it upstream; BL-03 is gated on first publish). The rest
are small, contained and independently landable.

---

## Shape of the work

| ID | Kind | Files touched | Test impact | Risk |
|---|---|---|---|---|
| BL-06 | Code | `settings/Panel.lua`, `tests/test_panel*`/`test_schema.lua` | New cases | Low |
| BL-10 | Code | `settings/Slash.lua`, `tests/test_slash.lua` | New case | Very low |
| BL-07 | Decision + doc (or upstream) | `docs/ARCHITECTURE.md` (or the standards repo) | None | None |
| BL-08 | Doc regeneration | `docs/agent-context.md` | None | None |
| BL-09 | Doc edit | `docs/ARCHITECTURE.md` | None | None |
| BL-02 | Media + doc | `media/screenshots/`, `README.md` | None | None |
| BL-03 | Deferred to publish | `BankLedger.toc`, `README.md` | None | None |

Nothing here touches the ledger data, the schema shape, `schemaVersion`, or any saved-variable
layout. No migration is required and `NS.SCHEMA_VERSION` stays at 2.

---

## BL-06 · Wire the canvas callbacks

**Goal.** Every frame handed to `Settings.RegisterCanvasLayout(Sub)category` carries `OnCommit`,
`OnDefault` and `OnRefresh`, so the Blizzard Settings framework's own apply / defaults / re-show
paths reach the addon instead of finding nothing, and so the framework's Defaults control and the
panel's header Defaults button share one implementation.

**Where.** `settings/Panel.lua` — `createPanel` (`:114-131`), plus the two registration blocks
(`:750-775`, `:778-801`).

**Shape.**

1. Give `createPanel` neutral defaults so *every* panel is safe the moment it is created:

   ```lua
   panel.OnCommit  = function() end
   panel.OnRefresh = function() end
   panel.OnDefault = function() end
   ```

   These are deliberately inert. `OnCommit` has nothing to do — every write already lands
   immediately through `NS.Schema:Set`, so there is no staged state to apply. `OnRefresh` is
   likewise redundant with the existing `OnShow` handler, which already calls `P:Refresh()` and the
   rebuilder gate; leaving it inert avoids a second, differently-ordered refresh path.

2. Where a panel has a real defaults action, point `OnDefault` at the **same closure** already
   parked as `panel.defaultsOnClick`, rather than writing a second implementation:

   ```lua
   -- General
   ctx.panel.defaultsOnClick = function() P:RestoreDefaults() end
   ctx.panel.OnDefault       = ctx.panel.defaultsOnClick

   -- Filters
   fctx.panel.defaultsOnClick = function() … StaticPopup_Show("KA0S_BANKLEDGER_CLEAR_FILTERS") … end
   fctx.panel.OnDefault       = fctx.panel.defaultsOnClick
   ```

   Better still, do the aliasing once inside `createPanel`'s consumer path — a two-line helper
   `local function setDefaultsAction(panel, fn) panel.defaultsOnClick = fn; panel.OnDefault = fn end`
   — so the two can never be set independently and drift.

**Why not `NS.Schema:ResetAll()`.** The `options-ui-§1` snippet shows `OnDefault` calling a schema
reset. Bank Ledger's equivalent is `P:RestoreDefaults()` (`settings/Panel.lua:721-727`), which calls
`NS.Slash:CliResetAll()` *and* recentres both windows — a strict superset with the same intent. The
`Filters` page holds no schema rows at all, so its honest default action is the confirm-gated
clear-both-lists it already uses. Pointing at the existing closures keeps one implementation per
page.

**Risk.** Low, but non-zero in one respect: `OnDefault` on the `General` panel now fires from
Blizzard's own footer control, which is *not* confirm-gated the way the `Reset all` body button is.
`P:RestoreDefaults()` is non-destructive — it resets settings and window geometry, never the ledger
(`settings/Panel.lua:721-727`, and `Sl:CliResetAll` at `settings/Slash.lua:254-260` explicitly
leaves the ledger alone) — so this is safe. The destructive path stays behind
`KA0S_BANKLEDGER_RESETALL`. Call this out in the smoke test.

**Tests.** Headless: assert each registered panel exposes all three fields as functions, and that
calling `panel.OnDefault()` on the General panel routes through the same code path as
`panel.defaultsOnClick()` (a shared spy). The existing `wow_mock` `Settings.*` fake already captures
registered panels, so the assertions can read them back without new mock surface.

**Smoke test.** Open Settings ▸ Ka0s Bank Ledger ▸ General, change a setting, use Blizzard's own
defaults control, confirm settings return to stock and the ledger is untouched.

---

## BL-10 · Route the `reset` echo through `FormatKV`

**Goal.** One coloured `key = value` renderer for every schema read/write echo.

**Where.** `settings/Slash.lua:239-248` (`Sl:CliReset`).

**Shape.** Replace the hand-assembled line with the same read-back-and-format pair `CliSet` uses:

```lua
NS.Schema:Set(path, def)
print(Sl.FormatKV(path, Sl.FormatSchemaValue(row, NS.Schema:Get(path))))
```

This drops the `" reset to "` prose. That is the intended outcome — `slash-commands-§5` defines one
output shape for the read/write surface, and the echo's job is to show the resulting state, not to
narrate. It also makes the echo reflect clamping or coercion, matching `set`.

**Risk.** Very low. One user-visible string changes.

**Tests.** Extend `tests/test_slash.lua` to assert the reset echo carries `|cffffff00` on the key and
`|cffffffff` on the value, and that a table-valued reset renders `(none)` rather than a table
pointer (the current behaviour worth preserving — `FormatSchemaValue` already handles it).

---

## BL-07 · Resolve the `defaults/Profile.lua` question

**This is a decision, not a code change.** Per the root `CLAUDE.md` rule, a deviation from the
standard is surfaced and the user classifies it.

**Option A — accepted deviation (recommended).** Add an entry to `docs/ARCHITECTURE.md` ▸
*Documented deviations*:

> **All defaults live in `defaults/Global.lua`; there is no `defaults/Profile.lua`.**
> `savedvariables-§2` names `defaults/Profile.lua` as the required home for defaults, and `layout-§1`
> lists it in the tree. Bank Ledger is account-wide by design — you deposit on one character and
> withdraw on another, so a per-character profile would split the very history the addon exists to
> join up. `NS.defaults` therefore carries a `global` table only, and every schema path resolves
> against `NS.db.global`. AceDB still creates the profile namespace; it is simply unused.

Cost: one doc block. No code moves, no saved-variable change, and the audit's next run reads the
deviation as recorded rather than open.

**Option B — raise it upstream.** `savedvariables-§2` is written for a profile-scoped addon and has
no wording for an account-wide one. Propose to `WowAddonStandards` that the section permit
`defaults/Global.lua` as the sole defaults file when the addon is account-wide by design, keeping
the "only place a default value is hardcoded" requirement intact. If adopted, Bank Ledger conforms
with no change at all.

**Explicitly rejected — Option C.** Creating an empty or pass-through `defaults/Profile.lua` to
satisfy the filename. It would add a file nothing reads, weaken `savedvariables-§2`'s "only place a
default is hardcoded" invariant by introducing a second candidate home, and hide the real design
decision behind a compliance prop.

---

## BL-08 · Re-drop the context pack

**Goal.** `docs/agent-context.md` reflects the current standard, so an agent's working brief is not
behind the code.

**Shape.**

1. Fetch `standards/NEW_ADDON_CONTEXT.md` (currently pack v2.7.0) from the standards repo verbatim
   with `curl`, not a summarizing fetch — the pack is the brief and must not be paraphrased.
2. Replace the body of `docs/agent-context.md` **below** the existing repo-specific HTML comment
   (`docs/agent-context.md:1-12`), preserving that header exactly.
3. Verify after the swap that the `## Hard rules cheat sheet` block still opens with the
   conform-to-the-standard bullet pointing back at `../CLAUDE.md` — that bullet is one of the four
   mandated standards-reference sites (`documentation-§6` item 4), and the audit checks it.

**Risk.** None to code. The only hazard is losing the repo-specific header, which the step order
guards against.

**Cadence.** This is not a one-off. Add "re-drop the pack when the standard's minor version moves"
to the release checklist so it rides `wow-addon:sync-docs` rather than accumulating until an audit
finds it.

---

## BL-09 · Retire the stale documented deviation

**Goal.** *Documented deviations* lists only things that are actually deviations.

**Shape.** In `docs/ARCHITECTURE.md:422-437`, remove the mono-font-glyph entry from the deviations
section and, if the rationale is worth keeping (it is — it explains why a glyph beats a texture
here), restate it as a short note beside the `C.DirectionGlyph` discussion or under *Logo art* /
media notes, citing `debug-logging-§2`'s second sanctioned use as the authority.

**Sequencing.** Do this in the same change as BL-07's Option A if that is the chosen route, so the
section ends the day with exactly one honest entry rather than one stale one.

---

## BL-02 · Screenshots

**Goal.** The README shows the addon before a reader installs it.

**Shape.** Capture at 1920×1080, windowed, default UI scale, with a representative populated ledger
(use `/bl test` to publish the synthetic dataset so no real character data leaks into the images,
then toggle it off):

1. The ledger window, History tab, filters visible.
2. The Insights tab.
3. The Current Banking Session window at an open bank.
4. Settings ▸ General.
5. Settings ▸ Filters.

Save under `media/screenshots/` with descriptive lowercase names, then insert a captioned
`## Screenshots` section **between `## What's new in 0.1.0` and `## Usage`** — the position
`documentation-§1` fixes.

**Note.** `.pkgmeta` ignores `docs/` but **not** `media/`, so screenshots ship in the package. Keep
them modestly sized (PNG, ≤ ~400 kB each) so the download stays small.

---

## BL-03 · Publish metadata (deferred)

When the addon is first published on CurseForge, in **one** change:

1. `BankLedger.toc` — insert `## X-Curse-Project-ID: <id>` immediately after
   `## X-Standard:` (line 12), preserving the Curse → Wago → WoWI order. Omit the Wago and WoWI
   lines unless the addon is actually listed there.
2. `README.md` — insert the live version badge
   `![CurseForge Version](https://img.shields.io/curseforge/v/<projectId>)` as badge **#2**, between
   `[wow]` and `[license]`.
3. `README.md` — `## Screenshots` becomes a MUST at that point, so BL-02 must already be closed.

---

## Ordering constraints

- **BL-09 after (or with) BL-07.** Both edit the same *Documented deviations* section; doing them
  together avoids a doc conflict and leaves the section coherent.
- **BL-02 before BL-03.** Screenshots are a MUST once published.
- **BL-08 before any further standards-driven code work.** An agent briefed by a stale pack will
  reintroduce patterns the current standard has moved past.
- **BL-06 and BL-10 are independent** of everything else and of each other.

## What is deliberately not being changed

- **`modules/Browser.lua` at 1170 LOC.** Inside the cap, in the 1000–1500 "on notice" band. Peeling
  it is a judgement call for a future release, not a compliance action — `layout-§1` makes >1500 the
  bug.
- **The TOC's Locales-before-Core section order.** `toc-file-§5` mandates
  Libraries → Locales → Core → Defaults → Modules → Settings, which the TOC follows exactly;
  `layout-§1`'s prose load-order sentence lists locales later. The two disagree *in the standard*.
  The addon follows the section-order rule, which is the one written as a TOC requirement. No change
  — and worth flagging upstream as an editorial inconsistency if it recurs in another audit.
- **`NS.bus = addon`.** The shared object is only ever the *sender*; every receiver owns a private
  `NS.NewBusTarget()` embed, which is the shape `architecture-§4` requires.
