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
-- folder name, its logo, what its LEFT button does, and how its settings panel opens.
--
-- ── THE RUNG (launcher-§2) ───────────────────────────────────────────────────────────────────
--
-- Bank Ledger is **rung (a)**, recorded as such in the standard's own `ADDONS.md`: it HAS a primary
-- window — the ledger browser, the thing the addon exists to show — so left-click TOGGLES it and
-- nothing else. Right-click opens the settings panel, as it does on every addon in the collection
-- whatever rung its left click sits on, which is what lets the left button be spent on something
-- better. Neither is a preference and there is no setting that reassigns either button.
--
-- The rung is expressed by the PRESENCE of `onClick` below rather than by a flag, so this addon
-- cannot declare a rung it did not implement.
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

-- THE BRAND NAME, IN THE ONE PLACE IT IS SPELLED. `Ka0s <Name>`, plain text, no escape sequence of
-- any kind. Two surfaces read it and they MUST agree: the LDB object's `label` below
-- (launcher-§1), and the disabled refusal line the slash gate renders (slash-commands-§7), which
-- drops it into a colored line and can only do so safely because §1 forbids escapes here.
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
  -- carry colour escapes and one in the collection does -- Ka0s Pretty Chat's is
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

  -- RIGHT-click, always, on every addon.
  openSettings = function()
    if NS.Panel and NS.Panel.Open then NS.Panel:Open() end
  end,

  -- THE LEFT CLICK, AND THE RUNG. B:Toggle, the same act `/bl toggle` runs, so the button and the
  -- verb can never disagree about what "open the ledger" means.
  -- REFUSED WHILE DISABLED (launcher-§2, slash-commands-§7). This addon is rung (a), and a rung-(a)
  -- left click drives a primary window, which is a feature: it prints the collection's one refusal
  -- line and does NOTHING else — in particular it writes no SavedVariables, which is what a minimap
  -- button with no disabled gate does every time it is clicked. The RIGHT click is unchanged in
  -- either state: it opens the settings panel, which slash-commands-§7 keeps standing, and the
  -- owner's ruling is about the slash surface — a mouse click is not a slash command.
  --
  -- Through NS.Slash, which renders the line from the library's own format string. The wording is
  -- the collection's, not this addon's, and re-spelling it here is exactly what that rule forbids.
  onClick = function()
    if NS.Slash and NS.Slash.RefuseIfDisabled and NS.Slash:RefuseIfDisabled() then return end
    if NS.Browser and NS.Browser.Toggle then NS.Browser:Toggle() end
  end,

  -- Ours entirely; the library passes it straight through and binds nothing about it. The live
  -- entry count is the one number worth reading without opening anything.
  onTooltipShow = function(tt)
    tt:AddLine("Ka0s Bank Ledger", 1, 0.82, 0)
    local n = (NS.Database and NS.Database.Count) and NS.Database:Count() or 0
    tt:AddLine(n == 1 and "1 movement" or (n .. " movements"), 0.7, 0.7, 0.7)
    tt:AddLine(" ")
    tt:AddLine("Left-click: open the ledger", 0.5, 0.5, 0.5)
    tt:AddLine("Right-click: open settings", 0.5, 0.5, 0.5)
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
