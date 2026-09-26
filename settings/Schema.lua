local _, NS = ...
NS.Schema = NS.Schema or {}
local S = NS.Schema
local C = NS.Constants
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

-- One row per setting. This single table drives the AceDB defaults check, the panel widgets, and
-- the slash get/set/list/reset dispatch (architecture-§5) — add a setting here and all three
-- surfaces pick it up with no other edit. Paths resolve against NS.db.global (account-wide).
--
-- `group` names one TAB on the page (options-ui-§13): H.RenderTabbedSchema partitions the page's
-- rows by `group` IN DECLARATION ORDER and draws one tab per distinct group, so the array's order
-- IS the tab order and a group's rows must stay CONTIGUOUS — a row filed under a group the page has
-- already left prints that tab a second time further down. Row order within a group drives the
-- two-column pairing. `wide` forces a full-width row; `solo` puts a row on its own line;
-- `subgroup` draws a heading INSIDE a tab, for a tab that mixes kinds of control (options-ui-§7);
-- `skipRender` keeps a row in the schema — so the CLI, the defaults and a reset all still see it —
-- while the panel draws it by hand. Those names are LibKa0s-Options-1.0's, not ours: the flow
-- engine reads them.
--
-- The tabs, in order: Master controls (the addon as a whole — composed, spliced in at the head from
-- settings/OptionsSetup.lua, see S:ComposeMaster below), Capture (what is recorded), Interface (what
-- is on screen), History (how much is kept, and the one way to destroy it), then Filters (both
-- item-id lists under one host-drawn tab — see S.BespokeRows).
--
-- THOSE NAMES AND THAT ORDER ARE SHARED WITH KA0S LOOT HISTORY, which draws the same five plus an
-- AH Price tab after Capture. The two addons capture and keep the same shape of record and a player
-- moves between their panels expecting the same furniture; one calling a subject Capture while the
-- other called it Collection was two names for one thing. Renaming a `group` moves no stored path
-- (options-ui-§15), which is why the convergence was a rename and not a migration.
S.Schema = {
  -- ── Capture ──
  -- What is recorded. The two kind toggles pair across one line, then the quality gate, then the
  -- per-store grid — narrowest question to widest. The master switch that used to lead this tab is
  -- "Enable Bank Ledger" on Master controls now (options-ui-§15): one control, one place.
  { path = "settings.trackItems", default = true, type = "bool", widget = "CheckBox",
    group = "Capture", label = "Track items",
    tooltip = "Record items moving between your bags and a bank.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage(NS.MSG.SETTINGS_CHANGED, "trackItems") end
    end },

  { path = "settings.trackMoney", default = true, type = "bool", widget = "CheckBox",
    group = "Capture", label = "Track gold",
    tooltip = "Record gold deposited to or withdrawn from the guild and warband banks. "
      .. "The character bank has no gold slot, so it is never counted.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage(NS.MSG.SETTINGS_CHANGED, "trackMoney") end
    end },

  { path = "settings.qualityThreshold", default = 0, type = "number", widget = "Dropdown",
    group = "Capture", label = "Minimum quality", values = C.QUALITY_OPTIONS,
    tooltip = "Only record items at or above this quality. Whitelisted items ignore this.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage(NS.MSG.SETTINGS_CHANGED, "quality") end
    end },

  -- Stored as the set of MUTED stores (excludedStores); the panel renders it inverted
  -- (invert = true) as "Record movements to and from", so a ticked box means "record this store".
  -- `skipRender` because no library maker draws a multi-select set picker, let alone an inverted
  -- one — RenderField dispatches on bool/number/string/color and answers nil for anything else. The
  -- row stays in the schema so `/bl list`, `/bl get` and every reset still see it; the panel emits
  -- the checkbox grid itself, from the Capture tab's `afterGroup` hook, which is what keeps it on
  -- the tab through a tab click (the strip re-renders the schema alone, not the page body).
  { path = "settings.excludedStores", default = {}, type = "table", widget = "MultiCheck",
    wide = true, invert = true, skipRender = true,
    group = "Capture", label = "Record movements to and from", values = C.STORE_OPTIONS,
    -- Spells the inversion out: the stored value is the MUTED set, so a ticked box means "record".
    tooltip = "Tick a store to RECORD movements to and from it. Unticking mutes that store; "
      .. "capture for every other store is unaffected.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage(NS.MSG.SETTINGS_CHANGED, "stores") end
    end },

  -- ── Interface ──
  -- Everything about what is on screen and how it looks, and it mixes two kinds of control — the
  -- windows you can switch on, and the tint of a table row — so each block carries a `subgroup`
  -- heading (options-ui-§7). Master scale left this tab for Master controls: it was never a
  -- per-window setting, both windows have always read the one key (see S.MASTER_SPEC below).
  { path = "settings.showSessionWindow", default = true, type = "bool", widget = "CheckBox",
    group = "Interface", subgroup = "Windows", label = "Session window",
    tooltip = "Show a small live window listing what you move while a bank is open. "
      .. "Turning this off never stops capture \226\128\148 only the window.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage(NS.MSG.SETTINGS_CHANGED, "sessionWindow") end
    end },

  -- The row tint pair. Both were hardcoded in TWO files each — modules/LedgerTable.lua and
  -- modules/SessionWindow.lua built every pooled row with `1,1,1,0.03` behind the even rows and
  -- `1,0.82,0,0.10` under the cursor — and they are two answers to two questions, so they are two
  -- sliders rather than one "row emphasis". Neither value is Core.SKIN's: the shared skin owns the
  -- window edge, fill, border and title, and says so byte for byte in modules/Browser.lua's
  -- B:ApplySkin note. The table interior is this addon's own.
  --
  -- Both defaults ARE the literals they replaced, so an install that touches neither is drawn
  -- exactly as it was. Both are clamped at the read (NS.Util.RowTintAlpha): these come out of
  -- SavedVariables, where a hand-edited 5 is not an error, it is a table drawn opaque white.
  { path = "settings.rowStripeAlpha", default = 0.03, type = "number", min = 0, max = 0.3,
    step = 0.01, widget = "Slider", fmt = "%.2f",
    group = "Interface", subgroup = "Table rows", label = "Row stripe opacity",
    tooltip = "How strongly every second row in the ledger and session tables is tinted. "
      .. "0 turns the banding off.",
    onChange = function() NS.Util.RefreshRowTint() end },

  { path = "settings.rowHoverAlpha", default = 0.10, type = "number", min = 0, max = 0.4,
    step = 0.01, widget = "Slider", fmt = "%.2f",
    group = "Interface", subgroup = "Table rows", label = "Row hover opacity",
    tooltip = "How strongly the row under your cursor is highlighted in the ledger and session "
      .. "tables. 0 turns the highlight off.",
    onChange = function() NS.Util.RefreshRowTint() end },

  -- ── History ──
  -- LAST of the stored tabs: what you set once and leave, and the only place anything is destroyed.
  -- The retention dropdown is the tab's one stored row; the live storage read-out and the
  -- confirm-gated Purge button beside it are bespoke and have no path, which is the named exemption
  -- to "a tab holding fewer than two visible controls is not a subject". "Reset all settings" is NOT
  -- here any more — it is the Master controls tab's closing button pair (options-ui-§15).
  { path = "settings.retentionDays", default = 30, type = "number", widget = "Dropdown",
    group = "History", label = "Keep history for", values = C.RETENTION_OPTIONS,
    tooltip = "Automatically drop movements older than this. 'Always' keeps everything.",
    onChange = function()
      if NS.Database and NS.Database.PruneOld then NS.Database:PruneOld() end
    end },
}

-- ── The Master controls tab (options-ui-§15) ──────────────────────────────────────────────────
--
-- COMPOSED, never typed out: the library emits the canonical eight from one declaration, which is
-- what stops nine addons drifting into nine orders (anti-pattern #73). What lives here is only the
-- part that is ours — which stored paths the canonical leaves map onto, and what each row REACTS to.
--
-- `keys` is how a composed row keeps a path this addon already ships: `scale` would otherwise emit
-- `settings.scale`, and every existing install stores its scale under `settings.windowScale`. The
-- composer must never change what is stored.
--
-- WHY `windowScale` IS THE MASTER SCALE and not a per-window one: both of this addon's scalable
-- surfaces already read that single key. Before the promotion each read it for itself, at frame
-- construction and again on a settings change; they read it through NS.Util.ApplyMasterFrame now
-- (each window's frame builder and its OnSettingsChanged: EnsureFrame and B:OnSettingsChanged in
-- modules/Browser.lua, ensureFrame and SW:OnSettingsChanged in modules/SessionWindow.lua), the same
-- one key for a third surface as well. It has been addon-wide since it was added; the tab it sat on
-- was the only thing suggesting otherwise. So this is a promotion with no second setting invented
-- beside it, which is what options-ui-§15 asks for.
-- The minimap row's CLI path, named once because FOUR places have to agree on it: the spec below,
-- the decoration underneath, the reset carve-out, and S:Register's defaults resolution. It reads in
-- the row's own sense -- `/bl set minimap.shown false` hides the button -- since standard v2.65.0
-- (launcher-§3). The PATH IS THE CLI NAME ONLY: the stored key is still db.global.minimap.hide,
-- which LibDBIcon owns and writes itself from its own right-click menu, so the decoration's get/set
-- invert onto it and nothing is ever stored at `minimap.shown`. A stored `shown` key would be a
-- second boolean beside the library's one (anti-pattern #81). The rename moved no SavedVariables
-- and needs no migration; the old CLI path `minimap.hide` now answers `Setting not found`.
S.MINIMAP_PATH = "minimap.shown"

-- ── The rows a RESET SWEEP must not reach (launcher-§3, standard v2.54.0) ───────────────────────
--
-- Named once, as data, so the two sweeps this addon ships consult one list rather than each
-- carrying its own spelling of one carve-out.
--
-- WHY THE MINIMAP ROW IS ON IT, AND WHY THAT IS A PROPERTY RATHER THAN A DERIVATION. Whether the
-- button is shown is a PER-INSTALLATION DISPLAY PREFERENCE, in the same class as the ANGLE the
-- player dragged it to -- which LibDBIcon keeps in this very table, as `minimap.minimapPos`, and
-- which no reset in the collection touches. Nobody has ever wanted *reset my settings* to mean
-- *and put the button back on my minimap, at the default angle*.
--
-- Until v2.54.0 the standard ARGUED the conclusion instead of stating it: *Reset all settings* is a
-- profile reset, the table is global, therefore the reset cannot reach it. THAT ARGUMENT WAS NEVER
-- TRUE HERE. This addon has NO PROFILE -- everything it stores is `db.global` -- so its reset empties
-- the account-wide store wholesale and merges the declared defaults back, and `minimap = { hide =
-- false }` is one of them: the wipe walked a hidden button straight back to shown. And the argument
-- only ever spoke about that one control, so the page-scoped **Defaults** button, which walks every
-- schema row carrying a default, reached the row from the other side. BOTH of this addon's resets
-- reached it; both are carved out now (settings/Slash.lua).
--
-- A TARGETED `/bl reset minimap.shown` IS NOT A SWEEP and still works. The player naming the one row
-- is asking for exactly that row, which is what the veto below is careful not to refuse: it fires
-- only inside a bulk bracket, which is what a wholesale act opens and a single-row reset does not.
S.RESET_EXEMPT = { [S.MINIMAP_PATH] = true }

-- ── The rows a host verb writes when the composer that declares them is absent (WS-02 route a) ──
--
-- `settings.enabled` is a COMPOSED row: LibKa0s-Options' MasterControls declares it, so a load
-- without that library has no row for it, and `/bl enable` / `/bl disable` -- the reserved pair,
-- which must work on every install (slash-commands-§2) -- would meet an unknown path. Listing it
-- here is options-ui-§1's route (a): the seam still stores the path, raw, through a synthetic row
-- with no validate and no onChange, so the degraded verbs re-run the latch themselves
-- (settings/Slash.lua). A path WITH a row always takes the row, so the full load is unaffected.
--
-- It is the ONE composed row a host verb writes. `settings.locked` has no verb. Test mode and the
-- debug console are session state, switched through LT:SetTestMode and NS.DebugLog, never through
-- this seam, so neither belongs here.
S.WRITE_THROUGH = { "settings.enabled" }

S.MASTER_SPEC = {
  prefix    = "settings.",
  page      = "general",
  addonName = "Bank Ledger",
  -- NOT frameless: each window's frame builder (EnsureFrame in modules/Browser.lua, ensureFrame in
  -- modules/SessionWindow.lua, EnsureFrame in modules/Export.lua) calls SetMovable(true), so every
  -- frame-only row applies.
  keys      = { scale = "windowScale" },
  -- The composer leaves the console toggle's default to the host, because "was the console open"
  -- is session state and only the host knows what it starts as. False is what this addon has always
  -- shipped, and the global reset lands on it: a session-only row is restored by name, since a
  -- store wipe cannot reach it (options-ui-§12) -- Sl:ResetEverything closes the console.
  --
  -- The same holds for test mode, which the composer emits with no default at all: `false` is what
  -- lets a reset end it (options-ui-§15, standard v2.47.0).
  defaults  = { debugConsole = false, testMode = false },
  -- Verbatim and unprefixed: session state lives outside the block's own prefix.
  debugConsolePath = "state.debugConsole",
  -- The Minimap button checkbox (launcher-§3, LibKa0s v1.39.0), FIRST column of the line below
  -- Lock frame / Debug console, with Test mode pairing beside it. Verbatim and unprefixed for a
  -- different reason than the console's: LibDBIcon's own table is GLOBAL, outside the block's
  -- `settings.` prefix, and this addon has stored it at db.global.minimap since long before the
  -- section existed — so unlike Multi Meters it owes no migration.
  --
  -- IT REPLACES A ROW RATHER THAN ADDING ONE. The Interface tab carried "Hide minimap button" over
  -- this same stored key, with the opposite sense; it is gone, because two rows over one boolean is
  -- the drift options-ui-§15 exists to end. The stored key did not move, so no player loses their
  -- choice — what changed is the label, the tab, the CLI name (`minimap.shown` since standard
  -- v2.65.0) and which way round the box reads.
  minimapPath = S.MINIMAP_PATH,
  -- The Test mode checkbox, on its own line below Lock frame / Debug console (LibKa0s v1.37.0). It
  -- switches the SAMPLE LEDGER (`/bl test`), not the session-window preview: `/bl session` stays its
  -- own verb. The owner decided that.
  testModePath = "state.testMode",
}

-- The host half of each composed row: the widget name this addon's own suite and CLI read, the
-- `fmt` its slash output uses, and the reaction. The composer owns the path, the label, the type,
-- the range and the default — everything a player sees — and deliberately knows nothing about a
-- host's bus or its debug console, so those are stamped on afterwards rather than hand-written into
-- a copy of the block.
S.MASTER_DECOR = {
  ["settings.enabled"] = { widget = "CheckBox",
    -- THE ADDON-WIDE SWITCH, AND THE ONLY PLACE THE LATCH IS DRIVEN (slash-commands-§7). The
    -- checkbox, `/bl enable`, `/bl disable` and `/bl set settings.enabled` are four surfaces onto
    -- ONE stored path and one write seam, and this onChange is what that one write runs — so the
    -- stand-down happens in the same turn as the write, whichever surface caused it, and none of
    -- them can hold a state of its own.
    --
    -- It is NOT a draw gate: NS.SetDisabledHold takes or releases the `disabled` hold, and the
    -- latch's edge is what unregisters every event, cancels every timer and shuts every window.
    onChange = function(v)
      NS.SetDisabledHold(v == false)
      if NS.bus then NS.bus:SendMessage(NS.MSG.SETTINGS_CHANGED, "enabled") end
    end },

  ["settings.visibility"] = { widget = "Dropdown",
    -- Honored in core/Util.lua's Util.VisibilityAllows, which every window's Show consults and
    -- which core/BankLedger.lua re-evaluates on each combat transition.
    onChange = function() NS.Util.ApplyVisibility() end },

  ["settings.windowScale"] = { widget = "Slider",
    fmt = "%.2fx",   -- scale → "1.00x" in the slash list/get output (slash-commands-§5)
    -- The direct calls repaint the windows the player is almost certainly looking at with no
    -- latency; the broadcast is what reaches everything ELSE that scales.
    onChange = function(v)
      if NS.Browser and NS.Browser.SetScale then NS.Browser:SetScale(v) end
      if NS.bus then NS.bus:SendMessage(NS.MSG.SETTINGS_CHANGED, "windowScale") end
    end },

  -- `min` is the ONE decoration here that overrides a value a player sees, and it narrows the
  -- composer's canonical 0 up to the floor core/Util.lua actually draws at
  -- (NS.Constants.MASTER_ALPHA_MIN). Left at 0, the slider's bottom two stops (0.00 and 0.05) both
  -- render at 0.1 and are indistinguishable — a declared setting the drawing code will not honor.
  -- The clamp stays where it is regardless: SavedVariables is hand-editable and the row is not the
  -- only way a value gets in.
  ["settings.alpha"] = { widget = "Slider", fmt = "%.2f",
    min = NS.Constants.MASTER_ALPHA_MIN,
    onChange = function() NS.Util.ApplyMasterChrome() end },

  ["settings.locked"] = { widget = "CheckBox",
    onChange = function() NS.Util.ApplyMasterChrome() end },

  -- THE ONE ROW WHOSE STORED SENSE IS THE OPPOSITE OF ITS LABEL. The row says SHOWN and
  -- LibDBIcon's key says hidden, so `get` inverts on the way up and `set` on the way down. The key
  -- is the library's -- LibDBIcon writes that same field itself when the player hides the button
  -- from its own right-click menu -- so storing the row's sense instead would be a second copy of
  -- one state, free to disagree with the library the first time either was used (anti-pattern
  -- #81). A row with its own `set` is stored by it and never by the seam's path walk, so the
  -- inversion lives here and nowhere else. `set` writes INTO the table LibDBIcon already holds
  -- (core/LauncherSetup.lua handed it over, and `minimapPos` lives in it too), creating it only if the
  -- store has none. The button itself moves from this `onChange`, which is the seam's own reaction
  -- hook and therefore the same route every other row's reaction takes: a slash write, a panel
  -- click and a reset all reach it, and none of them has to remember the inversion a second time.
  [S.MINIMAP_PATH] = { widget = "CheckBox",
    get = function()
      if NS.Launcher and NS.Launcher.IsShown then return NS.Launcher:IsShown() end
      local t = NS.db and NS.db.global and NS.db.global.minimap
      return not (type(t) == "table" and t.hide)
    end,
    set = function(v)
      local g = NS.db and NS.db.global
      if not g then return end
      if type(g.minimap) ~= "table" then g.minimap = {} end
      g.minimap.hide = not v
    end,
    onChange = function(v)
      if NS.Launcher and NS.Launcher.SetShown then NS.Launcher:SetShown(v) end
    end },

  ["state.debugConsole"] = { widget = "CheckBox",
    -- Session-only: Schema:Set skips the db.global write and calls this set() instead. Mirrors
    -- `/bl debug` with no argument. It used to be a hand-declared row on the Interface tab.
    get = function() return NS.DebugLog ~= nil and NS.DebugLog:IsShown() end,
    set = function(v)
      if not NS.DebugLog then return end
      if v then NS.DebugLog:Show() else NS.DebugLog:Hide() end
    end },

  ["state.testMode"] = { widget = "CheckBox",
    -- Session-only like the console row: Schema:Set calls this set() and writes nothing. The same
    -- switch as `/bl test`, through LT:SetTestMode, so a refused start prints why and the seam's
    -- repaint draws the box unticked again. The composer's tooltip is generic; this one says what
    -- test mode shows here.
    tooltip = "Show the ledger window on a sample ledger, so you can look around before you have "
      .. "any history of your own. Your real ledger is untouched. Combat ends it. The same as /bl test.",
    get = function() return NS.LedgerTable ~= nil and NS.LedgerTable:IsTestMode() end,
    set = function(v)
      local LT = NS.LedgerTable
      if not (LT and LT.SetTestMode) or LT:IsTestMode() == (v and true or false) then return end
      local _, refusal = LT:SetTestMode(v)
      if refusal then print(refusal) end
    end },
}

--- Compose the Master controls rows and splice them at the HEAD of S.Schema.
---
--- Called once, from settings/OptionsSetup.lua, the moment the LibKa0s-Options instance exists —
--- the composer lives on the instance and the TOC loads this file first. Idempotent, because a
--- second splice would draw the tab twice.
---
--- Stores the group's `afterGroup` hook on S.masterTail; settings/Panel.lua wires it. The GROUP NAME
--- IS THE HOOK KEY, so renaming the group silently detaches the closing button pair.
function S:ComposeMaster(O)
  if S.masterTail or not (O and O.MasterControls) then return end

  local spec = {}
  for k, v in pairs(S.MASTER_SPEC) do spec[k] = v end
  spec.onResetPosition = function() NS.Util.ResetWindowPositions() end
  -- options-ui-§12's global reset for an addon with NO PROFILE, verbatim: the confirm-gated
  -- KA0S_BANKLEDGER_RESETALL popup (whose text is that rule's second canonical wording, byte for
  -- byte), never the deed on the click. Through NS.Slash:RequestResetAll, the single entry point
  -- the page and footer Defaults and `/bl resetall` share, so every control is one act.
  spec.onResetAll = function()
    if NS.Slash and NS.Slash.RequestResetAll then NS.Slash:RequestResetAll() end
  end

  local rows, tail = O.MasterControls(spec)
  for _, row in ipairs(rows) do
    for field, value in pairs(S.MASTER_DECOR[row.path] or {}) do row[field] = value end
  end
  NS.SchemaRuntime.AddRows(rows, 1)   -- the head splice, re-indexed by the library
  S.masterTail = tail or function() end
  S.__pageRows = nil
  return rows
end

-- ── The item-id Filters tab (R3: the Filters page merged into General) ────────────────────────
--
-- ONE RENDERER-ONLY row. It carries a `group` so H.RenderTabbedSchema draws the tab, and
-- `skipRender` so the flow engine walks past it — settings/Panel.lua draws the body from that
-- group's `afterGroup` hook, exactly as the Capture store grid and the History read-out already are.
--
-- ONE ROW, NOT TWO. The blacklist and the whitelist were a primary tab each until the convergence
-- with Ka0s Loot History, which holds three such lists and had long since put them under a single
-- Filters tab with a SECONDARY strip (options-ui-§13: a list of like subjects inside one category
-- is exactly what a secondary strip is for). Two addons naming the same subject differently is the
-- drift; the sub-strip is also the shape that scales, since a third list here would otherwise be a
-- third primary tab pushing the page's own subjects along the band.
--
-- It is deliberately NOT in S.Schema and therefore NOT a setting. The lists themselves are an
-- architecture-§5 structural registry whose one writer is NS.Filters, copy-on-write (it re-caches
-- the capture gate and fires LedgerChanged); a schema row over the same key would hand `/bl set`,
-- `/bl reset` and the reset sweep a second writer that skips all of that. `allRows` still answers
-- S.Schema alone, so the CLI and every reset see exactly the settings and nothing else.
S.BespokeRows = {
  { group = "Filters", label = "Filters", widget = "IdList", skipRender = true,
    tooltip = "The item ids that are never recorded, and the ones that always are." },
}

--- The General page's rows AS RENDERED: every setting, then the host-drawn Filters tab.
---
--- Built once and cached — both halves are static after load, and a tab click re-renders the page.
function S:PageRows()
  if S.__pageRows then return S.__pageRows end
  local out = {}
  for _, row in ipairs(S.Schema) do out[#out + 1] = row end
  for _, row in ipairs(S.BespokeRows) do out[#out + 1] = row end
  S.__pageRows = out
  return out
end

-- NOTE: the debug LOGGING flag (NS.State.debug) is deliberately NOT a schema setting — it is
-- session-only, set via `/bl debug on|off`, and always off after a reload (debug-logging-§5). The
-- console WINDOW's visibility IS the `state.debugConsole` row the Master controls composer emits.
-- NOTE: four storage carve-outs are architecture-§5 named non-setting state, written by their owner
-- rather than through Schema:Set. None is a schema row, so none has a widget, a default or an
-- onChange. None has a `Documented deviations` row either: docs/schema.md ▸ Registry, recorded data
-- and named-state writers names each one's owner and every writer, and that naming is the
-- compliance. Check that list before writing a key under db.global directly, and add any new writer
-- to it. The four are:
--   1. `settings.window` — the ledger window's geometry. Owner Browser. Written by B:SaveGeometry
--      (modules/Browser.lua) on four occasions: drag-stop, resize-grip mouse-up (the grip's OnMouseUp
--      in EnsureFrame), hide and logout. Emptied by B:ResetWindow.
--   2. `settings.sessionWindow` — the session window's geometry. Owner SessionWindow. Written on the
--      same four by SW:SaveGeometry (modules/SessionWindow.lua; the grip's in ensureFrame); emptied by
--      SW:ResetWindow.
--   3. `savedView` — the account-wide column/sort baseline. Owner Browser. Written by B:SaveView
--      (modules/Browser.lua), cleared by B:ResetView.
--   4. `minimap.minimapPos` — LibDBIcon writes it on a button drag, into the table core/LauncherSetup.lua
--      hands it. That table also holds `hide`, the Minimap button row's stored key (CLI path
--      `minimap.shown`), so nothing here replaces it whole.
-- NOT on this list: `blacklist` / `whitelist`, the filter id-sets. They are an architecture-§5
-- structural registry written only by NS.Filters (F:_move, F:_remove, F:ClearList, F:ClearAll in
-- modules/Filters.lua), which then calls Database:FireLedgerChanged itself.

-- ── The runtime: LibKa0s-Schema-1.0 (architecture-§5) ───────────────────────────────────────
--
-- The rows above are this addon's. The machinery around them -- the path walk, the row index, the
-- single write seam, the bulk bracket (debug-logging-§10) and the load-time shape check -- is
-- LibKa0s-Schema-1.0's (docs/api/Schema/version-1-docs.md in LibKa0s), adopted at LibKa0s v1.55.0.
-- Every public name a caller used before is still here, bound to the instance below, so no call
-- site moved: S:Set, S:Get, S:Default, S:ApplyDefault, S:FindRow, S:ReadPath, S:WritePath,
-- S.SameValue, S.BulkBegin, S.BulkEnd and S:Register.
--
-- What the descriptor supplies is what is genuinely ours:
--   * resolveRoot -- every stored path resolves against NS.db.global. This addon has no profile
--     (savedvariables-§2), and before InitDB there is nowhere to store, which the seam refuses.
--   * announce -- the post-write repaint. An open panel MUST reflect live state after a mutation
--     (options-ui-§11), and this is "the same function /bl set calls" (options-ui-§1), so a slash
--     write, a panel widget and a reset all repaint by one route. It runs after the row's onChange,
--     for session-only rows too. P:Refresh skips every page that is not on screen, and re-syncing a
--     widget's value does not fire its OnValueChanged, so it cannot loop back through the seam.
--   * debug / debugEnabled -- the [Set] line goes to NS.Debug, read at call time, and only while the
--     session logging flag is on, so nothing is formatted with logging off.
--   * resetExempt -- launcher-§3's Minimap button row. The library honors it inside a bracket only,
--     so the sweep skips the row while `/bl reset minimap.shown`, the player naming it, still applies.
--   * L -- this addon's own refusal wording, kept from before the adoption.
--
-- WHAT THE LIBRARY DOES ON EVERY WRITE, IN THIS ORDER (the order is its contract): refuse an unknown
-- path, run the row's validate, refuse a missing root, store (a table value is COPIED in, so a
-- stored table never aliases the caller's or a row's `default`), tally the change if a bracket is
-- open, write the one [Set] line if none is, run the row's onChange, then announce.
--
-- THE ONE INVERTED PATH (launcher-§3) is the Minimap button row's own `set`, in S.MASTER_DECOR
-- above: the row says SHOWN and LibDBIcon's key says HIDDEN. A row with its own `set` is stored by
-- it and never by the path walk, so `/bl set`, the checkbox, `/bl reset` and the resetall sweep all
-- reach the inversion by the one route, and nothing else knows which way round the boolean is.

local SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true)

if not SchemaLib then
  -- Degraded: the payload is missing. THIS STUB IS A DELIBERATE, DOCUMENTED DUPLICATION -- the
  -- runtime-completing stub options-ui-§1 names, in the shape the major's own document prescribes
  -- (docs/api/Schema/version-1-docs.md, "The degradation stub"), trimmed to what this addon calls.
  -- The settings are read and written by more than the panel and the CLI: the host verbs
  -- (/bl enable, /bl disable), the degraded Reset All in settings/Slash.lua and every row's onChange
  -- all go through this seam, and slash-commands-§1 says the host verbs keep working without the
  -- library. So reads, writes, the row reaction, the repaint and the sweep veto are real here.
  --
  -- LOG-SILENT, on purpose: no [Set] line, no bracket tally, and no schema check. The degraded
  -- DebugLog stub discards any line anyway, and the check's one honest line would be a second
  -- notice beside the shared cause clause core/CoreSetup.lua has already printed once.
  --
  -- Trimmed: BulkRun, BulkAdd, InBulk, Reindex and the profile-reset count (CountOffDefault,
  -- ResetCounted, ConsumeResetCount) have no caller in this addon, which has no profile.
  -- tests/test_surface_parity.lua names each one as live-only. SetMany is the other way round: it
  -- has no caller in this addon either, and it is CARRIED, for parity -- Schema minor 2 (LibKa0s
  -- v1.56.0) adds it to the instance, and the version-2 document puts it in the stub table.
  local stub = {}
  local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
  end
  function stub.SplitPath(path)
    local parts = {}
    if path ~= nil then
      for seg in tostring(path):gmatch("[^%.]+") do parts[#parts + 1] = seg end
    end
    return parts
  end
  local function partsOf(p) return type(p) == "table" and p or stub.SplitPath(p) end
  function stub.Read(root, p, first)
    local parts, node = partsOf(p), root
    first = first or 1
    if type(root) ~= "table" or #parts < first then return nil end
    for i = first, #parts do
      if type(node) ~= "table" then return nil end
      node = node[parts[i]]
    end
    return node
  end
  function stub.Write(root, p, value, first)
    local parts, node = partsOf(p), root
    first = first or 1
    if type(root) ~= "table" or #parts < first then return end
    for i = first, #parts - 1 do
      if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
      node = node[parts[i]]
    end
    node[parts[#parts]] = value
  end
  function stub.SameValue(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not stub.SameValue(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
  end

  function stub:New(d)
    local R, depth, rows = {}, 0, d.rows
    local function words(key, path) return (d.L[key]):format(tostring(path)) end
    -- The writeThrough rows, as the library builds them: one synthetic `{ path =, writeThrough =
    -- true }` per listed path, read ONCE here and handed out by identity. No validate, no set, no
    -- onChange, so prepare/store below treat it as a plain stored row: NO_ROOT without a store,
    -- else a raw copy, then the announce.
    local throughRows = {}
    for _, p in ipairs(type(d.writeThrough) == "table" and d.writeThrough or {}) do
      if type(p) == "string" and p ~= "" and not throughRows[p] then
        throughRows[p] = { path = p, writeThrough = true }
      end
    end
    function R.AllRows() return rows end
    function R.FindRow(path)
      if type(path) ~= "string" then return nil end
      for _, row in ipairs(rows) do
        if type(row) == "table" and row.path == path then return row end
      end
    end
    function R.AddRows(list, at)
      if type(list) ~= "table" then return 0 end
      at = type(at) == "number" and math.floor(at) or #rows + 1
      if at > #rows + 1 then at = #rows + 1 elseif at < 1 then at = 1 end
      for i, row in ipairs(list) do table.insert(rows, at + i - 1, row) end
      return #list
    end
    function R.Get(path)
      local row = R.FindRow(path)
      if row and type(row.get) == "function" then return row.get() end
      if type(path) ~= "string" or (row and row.sessionOnly) then return nil end
      return stub.Read(d.resolveRoot(), path)
    end
    -- Steps 1-3 of the seam, storing nothing: refuse an unknown path (a listed writeThrough path is
    -- not unknown), validate, refuse a missing root. Answers the row and its root, or false and the
    -- refusal. Set and SetMany both prepare through it, so a batch refuses on exactly the rules a
    -- single write does.
    local function prepare(path, value)
      -- A path with a row always takes the row; a row-less path is refused unless it is listed.
      local row = R.FindRow(path) or (type(path) == "string" and throughRows[path]) or nil
      if not row then return false, words("NOT_FOUND", path) end
      local stored = type(row.set) ~= "function" and not row.sessionOnly
      local root = stored and d.resolveRoot() or nil
      if type(row.validate) == "function" then
        local ok, why = row.validate(value)
        if not ok then return false, words("INVALID", path), why end
      end
      if stored and type(root) ~= "table" then return false, words("NO_ROOT", path) end
      return row, root
    end
    -- The store alone: the row's own set, nothing for a sessionOnly row without one, else a copy.
    local function store(row, root, path, value)
      if type(row.set) == "function" then
        row.set(value)
      elseif type(root) == "table" then
        stub.Write(root, path, copy(value))
      end
    end
    -- The seam's order without its log and tally: refuse, validate, store, react, announce.
    function R.Set(path, value)
      local row, root, why = prepare(path, value)
      if not row then return false, root, why end
      store(row, root, path, value)
      if type(row.onChange) == "function" then row.onChange(value) end
      d.announce(row, path, value)
      return true
    end
    -- Phases 2-4 of the batch: every store, then every onChange, then the one announce.
    local function commit(writes)
      for _, w in ipairs(writes) do store(w.row, w.root, w.path, w.value) end
      for _, w in ipairs(writes) do
        if type(w.row.onChange) == "function" then w.row.onChange(w.value) end
      end
      if #writes == 0 then return end
      if type(d.announceBatch) == "function" then return d.announceBatch(writes) end
      for _, w in ipairs(writes) do d.announce(w.row, w.path, w.value) end
    end
    -- All or nothing: every entry is prepared before any is stored, and the first refusal answers
    -- `false, err, why, index` with nothing stored and nothing called. With opts.act the stores and
    -- reactions run inside the bracket depth, so the sweep veto reads it as the library's BulkRun.
    function R.SetMany(entries, opts)
      if type(entries) ~= "table" then entries = {} end
      if type(opts) ~= "table" then opts = {} end
      local writes = {}
      for i, e in ipairs(entries) do
        local path = type(e) == "table" and e.path or nil
        local value = type(e) == "table" and e.value or nil
        local row, root, why = prepare(path, value)
        if not row then return false, root, why, i end
        writes[#writes + 1] = { row = row, root = root, path = path, value = value }
      end
      if not opts.act then commit(writes); return true end
      depth = depth + 1
      local ok, err = pcall(commit, writes)
      if depth > 0 then depth = depth - 1 end
      if not ok then error(err, 0) end
      return true
    end
    function R.Default(path)
      local row = R.FindRow(path)
      return row and copy(row.default)
    end
    function R.ApplyDefault(row)
      if type(row) ~= "table" or type(row.path) ~= "string" or row.default == nil then return false end
      if depth > 0 and d.resetExempt[row.path] then return false end
      return R.Set(row.path, copy(row.default))
    end
    -- The bracket keeps its depth, because the sweep veto above reads it; it counts nothing.
    function R.BulkBegin() depth = depth + 1 end
    function R.BulkEnd() if depth > 0 then depth = depth - 1 end end
    function R.Validate() return 0, 0, 0 end
    return R
  end
  SchemaLib = stub
end

-- Published for introspection only: tests/test_surface_parity.lua holds the stub to the live major.
NS.__schemaLib = SchemaLib

local inst = SchemaLib:New({
  rows         = S.Schema,
  resolveRoot  = function() return NS.db and NS.db.global, 1 end,
  announce     = function() if NS.Panel and NS.Panel.Refresh then NS.Panel:Refresh() end end,
  debug        = function(tag, fmt, ...) if NS.Debug then NS.Debug(tag, fmt, ...) end end,
  debugEnabled = function() return NS.State ~= nil and NS.State.debug == true end,
  print        = function(line) print(line) end,
  resetExempt  = S.RESET_EXEMPT,
  writeThrough = S.WRITE_THROUGH,
  L = {
    NOT_FOUND = "unknown path: %s",
    INVALID   = "invalid value",
    NO_ROOT   = "no settings store yet: %s",
  },
})
NS.SchemaRuntime = inst

function S:FindRow(path) return inst.FindRow(path) end
function S:ReadPath(root, path) return SchemaLib.Read(root, path) end
function S:WritePath(root, path, value) return SchemaLib.Write(root, path, value) end
S.SameValue = SchemaLib.SameValue

-- The bulk bracket (debug-logging-§10). A bulk reset through this seam is logged as ONE
-- `[Set] <act> <scope>: N rows` line from the outermost BulkEnd, never one [Set] per row; each row's
-- validate and onChange still run. N is the rows whose READ-BACK value moved, never the Slash
-- library's `count`, which counts a row already at its default. A bracket that reports
-- `info.profileReset` logs nothing (this addon has no profile, so none does), and a walk that
-- raised part-way still logs its line, marked ` (stopped by an error)`. Dot-called values, handed
-- to the LibKa0s-Slash and LibKa0s-Options descriptors. No host route opens one today: the global
-- reset is the wholesale Sl:ResetEverything, which logs its own one line.
S.BulkBegin = inst.BulkBegin
S.BulkEnd = inst.BulkEnd

--- The single write seam. Answers `true`, or `false, reason` -- exactly two values on a refusal, as
--- it always has: the library's optional third (a validate's own reason) is not passed on, because
--- every caller of THIS method reads at most two. Only NS.Schema:Set trims. The slash CLI does not
--- come through here: its descriptor holds the instance's own Set (settings/Slash.lua), reads all
--- three of `false, err, why`, and prints the refusal (LibKa0s-Slash minor 15).
function S:Set(path, value)
  local ok, err = inst.Set(path, value)
  if ok then return true end
  return false, err
end

function S:Get(path) return inst.Get(path) end
function S:Default(path) return inst.Default(path) end

--- Restore ONE row to its declared default -- the seam every reset SWEEP writes through, and the one
--- place S.RESET_EXEMPT is honored (launcher-§3). Both the Slash and the Options descriptors hand it
--- over as `applyDefault`.
---
--- THE VETO IS BRACKET-SCOPED, DELIBERATELY, and that is the library's rule too: the Slash library
--- reaches `applyDefault` from BOTH CliReset (one named path) and its own CliResetAll (the sweep,
--- which this addon's `/bl resetall` no longer runs -- that verb is the wholesale reset), and only
--- the sweep opens the bulk bracket. Vetoing unconditionally would also refuse
--- `/bl reset minimap.shown`, which is the player naming that exact row.
function S:ApplyDefault(row) return inst.ApplyDefault(row) end

-- Boot validation (architecture-§5), through the library's Validate: every row's shape (a path,
-- one of this addon's types, a group), no path declared twice, and every stored path resolving
-- against the defaults table, so a typo in a path is caught loudly at load instead of silently
-- reading nil forever. Each failure is printed once. Answers the number of failures, which is what
-- the headless test asserts on.
--
-- A row whose path is missing from the defaults is reported WHETHER OR NOT the row carries a
-- `default` of its own. Before the adoption such a row passed silently: AceDB builds the store from
-- the defaults table, not from the rows, so its stored value would still read nil.
local VALID_TYPES = { bool = true, number = true, string = true, color = true, table = true }

--
-- THE MINIMAP ROW IS THE ONE PATH THAT IS NOT A STORED KEY. `minimap.shown` is the CLI name; the
-- store holds LibDBIcon's `minimap.hide` (S.MINIMAP_PATH above). So Validate resolves that one row
-- against a root derived from the declared hide default, rather than against a `shown` key the
-- defaults deliberately do not ship -- which keeps the check honest for the row without inventing
-- a second stored boolean to satisfy it.
local function defaultsRoot(_, row)
  local global = NS.defaults and NS.defaults.global
  if row and row.path == S.MINIMAP_PATH then
    local mm = global and global.minimap
    return { minimap = { shown = not (type(mm) == "table" and mm.hide) } }, 1
  end
  return global, 1
end

function S:Register()
  local errors, _, missing = inst.Validate({
    types        = VALID_TYPES,
    defaultsRoot = defaultsRoot,
  })
  return errors + missing
end

-- Slash command table. Dispatch lives in Slash.lua and the help index is generated from this, so
-- `/bl help` and the settings landing page can never drift
-- (slash-commands-§3).
NS.COMMANDS = {
  { "show",     "Open the ledger window",  function() NS.Browser:Show() end },
  { "hide",     "Close the ledger window", function() NS.Browser:Hide() end },
  { "toggle",   "Toggle the ledger window", function() NS.Browser:Toggle() end },
  { "config",   "Open settings",           function()
      if NS.Panel then NS.Panel:Open() end
    end },
  -- RESERVED VERBS, AND ALIASES RATHER THAN A SECOND SWITCH (slash-commands-§2). Both write the
  -- same stored path the Master-controls "Enable Bank Ledger" checkbox writes, through the same
  -- single write seam, so the checkbox and the verbs can never show the player two answers and one
  -- onChange runs whichever surface was used. They hold NO state of their own — no second key, no
  -- session flag, no NS.enabled local — and `/bl set settings.enabled true|false` is the same
  -- write by its long name.
  { "enable",   "Turn this addon on",      function() NS.Slash:CliEnabled(true) end },
  { "disable",  "Turn this addon off",     function() NS.Slash:CliEnabled(false) end },
  { "version",  "Print addon version",     function() NS.Slash:CliVersion() end },
  { "get",      "Get a setting value",     function(a) NS.Slash:CliGet(a) end },
  { "set",      "Set a setting value",     function(a) NS.Slash:CliSet(a) end },
  { "list",     "List all settings",       function() NS.Slash:CliList() end },
  { "reset",    "Reset one setting",       function(a) NS.Slash:CliReset(a) end },
  -- THE SAME ACT as the Master controls tab's "Reset all settings" button and both Defaults
  -- controls (options-ui-§12): it raises KA0S_BANKLEDGER_RESETALL, and Yes empties db.global
  -- wholesale. The words say both halves a player needs before typing it — history goes, and it
  -- asks first — the way `purge` says it.
  { "resetall", "Reset everything to defaults, including recorded history (asks first)",
    function() NS.Slash:CliResetAll() end },
  { "session",  "Toggle the banking-session window (sample data outside a bank)",
    function()
      if not NS.SessionWindow then return end
      local on = NS.SessionWindow:TogglePreview()
      if on == nil then
        print("a real banking session is open \226\128\148 showing what you actually moved.")
      else
        print("session window sample", on and "on" or "off")
      end
    end },
  { "test",     "Toggle a sample ledger",  function()
      -- Three outcomes, not two. A missing module toggled nothing, and a refused start (combat, or
      -- General visibility keeping the window shut) did not start anything, so neither may be
      -- reported as "test mode on/off": confirming an act that never ran is worse than saying
      -- nothing. The same switch as the Master controls `Test mode` checkbox, which follows it.
      local LT = NS.LedgerTable
      if not (LT and LT.ToggleTestMode) then
        print("the ledger table is not loaded \226\128\148 there is no sample to toggle.")
        return
      end
      local on, refusal = LT:ToggleTestMode()
      if refusal then print(refusal) else print("test mode", on and "on" or "off") end
    end },
  { "purge",    "Delete ALL ledger history (asks first)", function()
      if type(StaticPopup_Show) == "function" then
        StaticPopup_Show("KA0S_BANKLEDGER_PURGE")
      elseif NS.Database and NS.Database.Purge then
        NS.Database:Purge()
      end
    end },
  { "debug",    NS.L["Toggle the console; 'on'/'off' set logging; 'diagnostics' writes a report"],
    function(rest)
      -- `/bl debug` toggles the WINDOW only (the logging flag is untouched); `/bl debug on|off`
      -- sets the session-only logging flag through the DebugLog seam. Logging runs even with the
      -- console closed, so a bug can be reproduced first and the log read afterwards.
      --
      -- `diagnostics` is tested FIRST (debug-logging-§14): the second of the report's two forms,
      -- the same call as `/bl diagnostics`. No other word runs it -- `diag` is an ordinary unknown
      -- word here and toggles the window like any other.
      local arg = rest and tostring(rest):lower():match("^%s*(%S*)") or ""
      if not NS.DebugLog then return end
      if arg == "diagnostics" then NS.DebugLog:RunDiagnostics()
      elseif arg == "on" then NS.DebugLog:SetEnabled(true)
      elseif arg == "off" then NS.DebugLog:SetEnabled(false)
      elseif arg == "panel" then
        -- Structured dump of the settings header's Defaults button (debug-logging-§4). Same RAW
        -- append as `scan`, so it works whether or not logging is enabled.
        NS.DebugLog:Show()
        if NS.Panel and NS.Panel.Diagnose then
          for _, line in ipairs(NS.Panel:Diagnose()) do NS.DebugLog:Add("Panel", line) end
        else
          NS.DebugLog:Add("Panel", "settings panel not built yet \226\128\148 run /bl config first")
        end
      elseif arg == "scan" then
        -- A structured dump verb (debug-logging-§4): writes the client's real container model into
        -- the console through the RAW append, so it works whether or not logging is enabled.
        NS.DebugLog:Show()
        for _, line in ipairs(NS.Ledger:Diagnose()) do NS.DebugLog:Add("Scan", line) end
      else NS.DebugLog:Toggle() end
    end },
  -- THE DIAGNOSTICS REPORT (debug-logging-§14, a reserved verb since slash-commands-§2 v2.68.0).
  -- Everything a maintainer needs, appended to the console after the trace the player just
  -- reproduced, so one Copy carries both. Live while disabled (LibKa0s-Slash-1.0's LIVE_VERBS), and
  -- read-only: modules/Diagnostics.lua supplies the sections, the library writes the rest.
  { "diagnostics", NS.L["Write a diagnostic report to the debug console"], function()
      if NS.DebugLog then NS.DebugLog:RunDiagnostics() end
    end },
  { "help",     "Show this help",          function() NS.Slash:PrintHelp() end },
}
