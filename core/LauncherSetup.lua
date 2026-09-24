local addonName, NS = ...

-- core/LauncherSetup.lua — wires the addon into LibKa0s-Launcher-1.0 (launcher-§1).
--
-- THE MINIMAP BUTTON AND THE BROKER PLUGIN, AS ONE OBJECT REGISTERED TWICE. LibDataBroker-1.1 is
-- handed one launcher object; LibDBIcon-1.0 draws the minimap button from it, and any broker
-- display the player runs — Titan Panel, ElvUI's data texts, Bazooka — draws its own row from the
-- very same object. One OnClick, one icon, one label, one identity.
--
-- ── IT USED TO BE OURS, AND THAT WAS THE PROBLEM ─────────────────────────────────────────────
--
-- This was `B:SetupMinimap` and `B:SetMinimapHidden` in modules/Browser.lua: thirty lines that
-- resolved both broker libraries, built the data object, wrote the click branch and drove
-- LibDBIcon's Show/Hide. Every line of it was correct here and every line of it was also written,
-- in its own spelling, in each of the other Ka0s addons — which is anti-pattern #81 and exactly
-- what the library exists to make impossible. The object's shape, the click dispatch and the
-- idempotence are the library's now; what stays below is only what is genuinely this addon's: its
-- folder name, its logo, how its settings panel opens, and which of its own verbs the menu runs.
--
-- ── THE TWO BUTTONS (launcher-§2, standard v2.67.0; Launcher minor 4) ───────────────────────
--
-- LEFT-click opens the settings panel, on every addon in the collection and in either state. The
-- three left-click rungs are retired; Bank Ledger was rung (a), whose left click toggled the ledger
-- browser, and that toggle is now the menu's *Show window* entry. RIGHT-click opens the client's
-- own context menu, built by the LIBRARY from the accessor-and-toggle pairs below: Enabled, Locked,
-- Test mode, Show window — the four the standard's ADDONS.md records against this addon, because it
-- has all four states. Neither button is a preference and there is no setting that reassigns either.
--
-- EVERY TOGGLE IS A SLASH VERB'S OWN HANDLER, looked up in NS.COMMANDS at click time (see `verb`
-- below), so the menu cannot grow a second copy of what `/bl enable`, `/bl test` or `/bl toggle`
-- does: the refusals, the combat rules and the chat lines are the verb's. While the addon is
-- disabled the library grays every entry but Enabled, so no host gate is written here.
--
-- ── WHY `name` IS THE FOLDER NAME AND NOT THE TITLE ──────────────────────────────────────────
--
-- `addonName`, the first vararg every TOC-loaded file gets — "BankLedger", not "Ka0s Bank Ledger"
-- and not "Bank Ledger". launcher-§1 fixes it because the name keys BOTH registrations, and a
-- second spelling on either one labels the broker plugin with the other name. It is the one name
-- the addon cannot change without changing what the client loads.
--
-- THE HAND-ROLLED OBJECT USED "Ka0s Bank Ledger", so this IS a rename, and the one thing a rename
-- here could cost — the angle the player dragged the button to — is not lost: LibDBIcon keys the
-- saved position off the TABLE it is handed, `db.global.minimap`, and `minimapPos` sits inside it
-- untouched. What a player does lose is a per-plugin toggle they had set in a broker display,
-- since the display keys that by plugin name. That is a one-time cost of adopting the standard's
-- name and it is smaller than carrying a spelling nothing else in the collection uses.
--
-- ── WHY `minimap` IS A FUNCTION AND NOT A TABLE ──────────────────────────────────────────────
--
-- `NS.db.global.minimap` DOES NOT EXIST at file load: `NS:InitDB` runs from OnInitialize, long
-- after the TOC has walked core/. A table captured here would be nil, and even a non-nil one would
-- be a table AceDB later replaces — leaving LibDBIcon writing `minimapPos` into a table the
-- settings row no longer reads. The library resolves the closure at Register time instead, which
-- is what keeps the object it holds and the table the Master-controls row writes the SAME table.
--
-- ── WHAT A DEGRADED INSTALL GETS ─────────────────────────────────────────────────────────────
--
-- No launcher, and no error. The stub below answers every member the addon reaches — `Register`
-- says it wired nothing, `IsShown` reads the store so the settings row still reflects what the
-- player chose, and `SetShown` is an honest no-op. NOT a hand-rolled copy of the library's
-- registration (anti-pattern #47): a host copy of vendored code is the copy that goes stale, and
-- the Master-controls row that drives this is itself composed by LibKa0s-Options and therefore
-- absent on the same arm.
--
-- A host that HAS LibKa0s but not the two broker libraries degrades inside the library instead:
-- both are resolved with `LibStub(..., true)` at Register time and a missing one is reported on
-- one line rather than raised. Both are vendored under libs/ and listed in the TOC's `# Libraries`
-- block, so that arm is the player's business, not this addon's.

local Launcher = LibStub and LibStub("LibKa0s-Launcher-1.0", true)

-- The addon's face, in the one place it is spelled. THE SAME FILE the TOC's `## IconTexture`
-- names (launcher-§4): the AddOns list, the minimap button and a broker display show one identity
-- rather than three, and tests/test_marks.lua pins the two spellings against each other.
--
-- DERIVED from `addonName` rather than typed out, for the reason core/MediaSetup.lua states at
-- length: a texture path is absolute from `Interface\AddOns\`, and only the first vararg knows
-- which folder this copy was loaded from. layout-§4 lowercases the folder name in the FILE name
-- and leaves the folder itself alone, so the two halves are spelled differently on purpose.
NS.LOGO_ICON = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.128.tga")
  :format(addonName, addonName:lower())

-- THE BRAND NAME, in the one place it is spelled after core/CoreSetup.lua's load-time
-- missing-library clause (NS.LIBKA0S_MISSING loads before this file). `Ka0s <Name>`, plain text,
-- no escape sequence of any kind. Every later surface reads it: the tooltip title (the library
-- draws it from `label`), the options parent title, both window titles and the purge popup. Two of
-- them MUST agree: the LDB object's `label` below (launcher-§1), and the disabled refusal line the
-- slash gate renders (slash-commands-§7), which drops it into a colored line and can only do so
-- safely because §1 forbids escapes here.
--
-- Declared ABOVE the degradation stub's early return, beside NS.LOGO_ICON and for the same reason:
-- the slash surface exists on both arms, so a brand name that only the live arm carried would
-- leave the degraded arm rendering `nil is disabled` at the one moment a confused player is
-- reading the line.
NS.BRAND_NAME = "Ka0s Bank Ledger"

if not Launcher then
  NS.Launcher = {
    __degraded = true,
    Register      = function() return false end,
    IsRegistered  = function() return false end,
    Object        = function() return nil end,
    IsShown       = function()
      local t = NS.db and NS.db.global and NS.db.global.minimap
      if type(t) ~= "table" then return true end
      return not t.hide
    end,
    SetShown      = function(_, shown)
      local t = NS.db and NS.db.global and NS.db.global.minimap
      if type(t) == "table" then t.hide = not shown end
      return false
    end,
  }
  return
end

-- THE MENU'S TOGGLES ARE THE SLASH VERBS' OWN HANDLERS. NS.COMMANDS (settings/Schema.lua) is the
-- one table `/bl` dispatches through, and it loads AFTER this file, so the lookup happens at click
-- time. Calling the entry's function directly, rather than NS.Slash:OnSlash, skips only the
-- dispatcher's parsing and its disabled-verb gate — and the library's graying already stands in for
-- that gate, refusing Locked / Test mode / Show window before this runs. A verb that is not there
-- does nothing, which on this addon means the table did not load.
local function verb(name, rest)
  for _, cmd in ipairs(NS.COMMANDS or {}) do
    if cmd[1] == name then return cmd[3](rest or "") end
  end
end

-- The Lock frame row's stored key, read here once for both the accessor and its toggle.
local function isLocked()
  local s = NS.db and NS.db.global and NS.db.global.settings
  return type(s) == "table" and s.locked == true
end

NS.Launcher = Launcher:New({
  name = addonName,
  icon = NS.LOGO_ICON,

  -- What a broker display prints beside the icon, BESIDE THE OTHER TEN (launcher-§1). It is the
  -- addon's BRAND NAME IN PLAIN TEXT -- `Ka0s <Name>` -- and that one field is what decides whether
  -- the collection reads as one collection in Titan Panel or as eleven unrelated addons that
  -- happen to be installed together. Nothing said what it was until v2.54.0, so across the eleven
  -- adoptions it came out three ways ("Absorb Tracker", "Ka0s KickCD", "Ka0s Pretty Chat"), and a
  -- display sorting its plugins alphabetically filed the odd one under a different letter from the
  -- rest. THIS ONE SAID "Bank Ledger" and now says the brand.
  --
  -- DELIBERATELY NOT THE TOC'S `## Title`, and the two are NOT wired to each other. A Title MAY
  -- carry color escapes and one in the collection does -- Ka0s Pretty Chat's is
  -- `Ka0s |cffff0000P|cffff9900r|cffffff00e|...` -- and handed to a display that draws the string
  -- raw it splatters across a row in which every other row is plain text, handed to one that
  -- strips escapes it arrives mangled instead. So NO escape sequence of any kind belongs here.
  --
  -- It is not the folder name either: that is the registration `name` above, which LibDBIcon keys
  -- the saved position by and which a player reads nowhere as prose. `BankLedger` is an
  -- identifier, `Ka0s Bank Ledger` is a name. Two fields, two jobs.
  label = NS.BRAND_NAME,

  -- launcher-§3: LibDBIcon's OWN table, in the GLOBAL store. Resolved at Register time — see the
  -- header. This addon has stored it there since before the section existed, so unlike Multi
  -- Meters it owes no migration.
  minimap = function() return NS.db and NS.db.global and NS.db.global.minimap end,

  -- LEFT-click, always, on every addon and in either state (Launcher minor 4). Also where the right
  -- click lands on a client with no context-menu API, since the panel holds every menu toggle.
  openSettings = function()
    if NS.Panel and NS.Panel.Open then NS.Panel:Open() end
  end,

  -- ── THE OPTIONS MENU (launcher-§2, standard v2.67.0; Launcher minor 4) ────────────────────
  --
  -- One accessor-and-toggle pair per entry, and each accessor is also a tooltip line. The library
  -- draws an entry only when BOTH halves are passed, asks every accessor on each open, and grays
  -- Locked / Test mode / Show window while `isEnabled` answers false.

  -- ENABLED. `isEnabled` reads the latch's `disabled` hold through NS.IsDisabled, the same hold the
  -- slash gate and the Master-controls checkbox read, so the three cannot disagree. `setEnabled` is
  -- handed the state to move TO and runs `/bl enable` or `/bl disable` — Sl:CliEnabled, which
  -- writes the Enable row's stored path through the one write seam and re-runs the latch.
  isEnabled = function() return not (NS.IsDisabled and NS.IsDisabled()) end,
  setEnabled = function(on) verb(on and "enable" or "disable") end,

  -- LOCKED. The Master-controls "Lock frame" row, stored at settings.locked, which core/Util.lua's
  -- ApplyMasterFrame honors. This addon has no `lock` / `unlock` verb (settings/Schema.lua says so
  -- above S.WRITE_THROUGH), so the toggle is the one verb that DOES write the row:
  -- `/bl set settings.locked <bool>`, Sl:CliSet, through the same seam and the row's own onChange.
  isLocked = isLocked,
  toggleLock = function() verb("set", "settings.locked " .. tostring(not isLocked())) end,

  -- TEST MODE. The sample ledger. `isTestMode` is the Test mode row's own `get`
  -- (settings/Schema.lua), LT:IsTestMode; the toggle is `/bl test`, which reports a refused start.
  isTestMode = function() return NS.LedgerTable ~= nil and NS.LedgerTable:IsTestMode() end,
  toggleTestMode = function() verb("test") end,

  -- SHOW WINDOW. The primary window is the ledger browser, the thing the addon exists to show. The
  -- toggle is `/bl toggle`, B:Toggle, which honors General visibility on the way up.
  isWindowShown = function()
    local f = NS.Browser and NS.Browser.GetWindow and NS.Browser:GetWindow()
    return f ~= nil and f:IsShown() and true or false
  end,
  toggleWindow = function() verb("toggle") end,

  -- ── THE STATUS TOOLTIP (launcher-§1, standard v2.66.0; Launcher minor 3) ──────────────────
  --
  -- THE LIBRARY DRAWS IT, on every hover and while the addon is disabled too, in the one shape all
  -- eleven addons share: `<label>  v<version>`, Enabled, Locked, Test mode, this addon's own lines,
  -- then the fixed `Left-click: Open settings` and `Right-click: Options menu` (minor 4). The fields
  -- only answer its questions, and each is asked on every show, never cached, so the tooltip cannot
  -- disagree with the panel.
  --
  -- The version the TOC stamps, through NS.Version (core/EnvSetup.lua): the same string `/bl
  -- version` prints, falling back to NS.version only where the manifest cannot be read.
  version = function() return NS.Version and NS.Version() end,

  -- `isEnabled`, `isLocked` and `isTestMode` above are the tooltip's three status lines too, so the
  -- menu's checkmarks and the tooltip read one set of answers. There is no *Show window* line.

  -- THIS ADDON'S OWN LINES, and only those. The library draws the title, the version, the status
  -- lines and both click hints, so drawing any of them here would be a second copy (anti-pattern
  -- #89) — which is exactly what this hook drew through Launcher minor 2, when it WAS the tooltip.
  -- The live entry count is the one number worth reading without opening anything.
  onTooltipShow = function(tt)
    local n = (NS.Database and NS.Database.Count) and NS.Database:Count() or 0
    tt:AddLine(n == 1 and "1 movement" or (n .. " movements"), 0.7, 0.7, 0.7)
  end,

  -- The shared, secret-safe, [BL]-prefixed printer, so the library's own reports read like every
  -- other line this addon emits (events-frames-taint-§8).
  print = function(line) NS.Print(line) end,

  -- debug(tag, message) — the library hands a finished string, and NS.Debug takes a format. "%s"
  -- rather than the message itself: a message carrying a stray `%` would otherwise raise inside
  -- string.format, from a log line.
  debug = function(tag, message)
    if NS.Debug then NS.Debug(tag, "%s", tostring(message)) end
  end,
})
