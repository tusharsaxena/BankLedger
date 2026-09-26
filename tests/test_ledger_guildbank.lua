-- tests/test_ledger_guildbank.lua — the guild bank as a capture store: the tab query it needs before a
-- scan sees anything, the deposit it records, and how it arms and disarms on its frame showing and
-- hiding rather than on an open event (issue #12).
--
-- Peeled out of tests/test_ledger.lua, which sat in layout-§1's 1000-1500 band at two consecutive
-- release runs, one short of anti-pattern #53's limit. These two sections are one subject, and the
-- only thing they read from the rest of that file is BAG_ID, which tests/ledger_support.lua already
-- shares; `clearContext` is used by these cases alone and came across whole. Not one assertion changed.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = dofile("tests/ledger_support.lua")
local BAG_ID = S.BAG_ID

-- ── Guild bank ─────────────────────────────────────────────────────────────────
-- The guild bank has its own API family AND a prerequisite the container stores do not have: a tab
-- returns nothing until it has been QUERIED. Only the tab you are looking at is populated for free,
-- so without the query the scan sees an almost-empty guild bank whatever is really in it.

test("Ledger:ScanGuildBank sees nothing from a tab that was never queried", function()
  mocks.__guildQueried = {}
  assertEqual(next(NS.Ledger:ScanGuildBank()), nil, "unqueried tabs report nothing")
end)

test("Ledger:QueryGuildBankTabs asks for every tab", function()
  mocks.__guildQueried, mocks.__guildQueryCount = {}, 0
  assertEqual(NS.Ledger:QueryGuildBankTabs(), 8)
  assertEqual(mocks.__guildQueryCount, 8, "one query per tab")
end)

test("Ledger:ScanGuildBank reads a tab once it has been queried", function()
  mocks.__guildQueried = {}
  NS.Ledger:QueryGuildBankTabs()
  assertEqual(NS.Ledger:ScanGuildBank()[2589], 5)
end)

test("Ledger:OpenContext queries the guild bank tabs on open", function()
  mocks.__guildQueried, mocks.__guildQueryCount = {}, 0
  NS.Ledger:OpenContext("GUILD_BANK")
  assertEqual(mocks.__guildQueryCount, 8, "opening the frame populates every tab")
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
end)

test("Ledger:OpenContext does NOT query guild tabs for the bank frame", function()
  mocks.__guildQueried, mocks.__guildQueryCount = {}, 0
  NS.Ledger:OpenContext("BANK_FRAME")
  assertEqual(mocks.__guildQueryCount, 0)
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
end)

test("Ledger: a guild-bank deposit is recorded", function()
  local before = NS.Database:Count()
  local savedTabs = mocks.__guildTabs
  mocks.__guildTabs = { [1] = {} }
  mocks.__guildQueried = {}
  local savedBag = mocks.__containers[BAG_ID]
  mocks.__containers[BAG_ID] = { slots = 1, [1] = { itemID = 171276, count = 4 } }

  NS.Ledger:OpenContext("GUILD_BANK")
  mocks.__containers[BAG_ID][1] = nil
  mocks.__guildTabs[1][1] = { itemID = 171276, count = 4 }
  NS.Ledger:Reconcile()

  assertEqual(NS.Database:Count(), before + 1)
  local e = NS.Database:Ledger()[NS.Database:Count()]
  assertEqual(e.store, "GUILD_BANK")
  assertEqual(e.direction, "DEPOSIT")
  assertEqual(e.quantity, 4)
  assertEqual(e.guild, "Ka0s", "guild-bank rows carry the guild name")

  NS.Database:Delete(function(x) return x.itemID == 171276 end)
  mocks.__guildTabs, mocks.__containers[BAG_ID] = savedTabs, savedBag
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
end)

test("Ledger:Diagnose reports the guild-bank API and per-tab contents", function()
  mocks.__guildQueried = {}
  NS.Ledger:QueryGuildBankTabs()
  local text = table.concat(NS.Ledger:Diagnose(), "\n")
  assertTrue(text:find("guild bank API:", 1, true) ~= nil, "which globals exist")
  assertTrue(text:find("guild bank tabs=8", 1, true) ~= nil)
  assertTrue(text:find("  tab 1: 1 / 1", 1, true) ~= nil, "per-tab filled/distinct counts")
end)

test("Compat.GetGuildBankSlot survives a build with no guild-bank API", function()
  -- Both getters are guarded independently: a build that keeps one and retires the other must
  -- degrade to "no data" rather than raise part-way through a scan.
  local savedLink = mocks.GetGuildBankItemLink
  mocks.GetGuildBankItemLink = nil
  local ok, result = pcall(function() return NS.Compat.GetGuildBankSlot(1, 1) end)
  mocks.GetGuildBankItemLink = savedLink
  assertTrue(ok, "no error")
  assertEqual(result, nil)
end)

-- ── The guild bank arms itself on its frame showing, not on an open event ──────
-- GUILDBANKFRAME_OPENED is a valid event name that registers without complaint and then never
-- fires on 12.0.7, so waiting for it left the addon permanently unarmed and every guild deposit
-- unrecorded. The frame's own OnShow is the notice the client DOES give, installed the moment the
-- load-on-demand Blizzard_GuildBankUI arrives.
--
-- Tab contents arriving used to be the signal instead, and it armed a banking session in the middle
-- of a field (issue #12): the server pushes guild bank data on reload sync and whenever ANOTHER
-- guild member moves something, neither of which involves the player being at a bank. Data now arms
-- only as a backstop for a build whose OnShow never fires, and only when the window says it is
-- explicitly visible.

local function clearContext()
  NS.State.openContext, NS.State.lastSnapshot, NS.Ledger._settleSince = nil, nil, nil
end

test("Ledger: the guild-bank frame showing arms the context", function()
  clearContext()
  NS.Ledger._guildHooked = nil
  assertTrue(NS.Ledger:HookGuildBankFrame(), "the frame exists, so the hooks go on")
  mocks.__openGuildBank()
  assertEqual(NS.State.openContext, "GUILD_BANK", "the window opening is what arms it")
  assertTrue(NS.State.lastSnapshot ~= nil, "and takes a baseline")
  clearContext()
end)

test("Ledger: the guild-bank frame showing never steals an open bank context", function()
  clearContext()
  NS.Ledger._guildHooked = nil
  NS.Ledger:HookGuildBankFrame()
  NS.Ledger:OpenContext("BANK_FRAME")
  mocks.__openGuildBank()
  assertEqual(NS.State.openContext, "BANK_FRAME", "the bank frame has its own events")
  clearContext()
end)

test("Ledger:OnAddonLoaded hooks the frame when Blizzard_GuildBankUI arrives", function()
  -- The UI is load-on-demand: GuildBankFrame does not exist until the player opens a guild bank
  -- once, so this is the earliest moment OnShow can be hooked at all.
  clearContext()
  NS.Ledger._guildHooked = nil
  local savedFrame = mocks.GuildBankFrame
  mocks.GuildBankFrame = nil
  assertFalse(NS.Ledger:OnAddonLoaded("Blizzard_GuildBankUI"), "no frame yet, nothing to hook")
  mocks.GuildBankFrame = savedFrame
  assertFalse(NS.Ledger:OnAddonLoaded("SomeOtherAddon"), "only the guild bank UI matters")
  assertTrue(NS.Ledger:OnAddonLoaded("Blizzard_GuildBankUI"), "the LoD UI landing installs them")
  clearContext()
end)

-- ...and tab contents arriving is not proof of anything (issue #12).

test("Ledger:OnGuildBankData arms when the guild-bank window is explicitly visible", function()
  clearContext()
  mocks.__guildQueried, mocks.__guildVisible = {}, true
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "GUILD_BANK", "a visible window is a real visit")
  assertTrue(NS.State.lastSnapshot ~= nil, "and takes a baseline")
  clearContext()
end)

test("Ledger:OnGuildBankData does NOT arm when there is no guild-bank window", function()
  -- The reload-sync case, exactly as reported: 8 tabs queried, a GUILD_BANK session opened and a
  -- baseline of 0 kinds, all with the player nowhere near a bank. Blizzard_GuildBankUI is not
  -- loaded, so IsGuildBankVisible() answers nil -- and nil must never read as "the window is up".
  clearContext()
  local savedFrame = mocks.GuildBankFrame
  mocks.GuildBankFrame = nil
  NS.Ledger:OnGuildBankData()
  mocks.GuildBankFrame = savedFrame
  assertEqual(NS.State.openContext, nil, "a session must not open away from a bank")
  clearContext()
end)

test("Ledger:OnGuildBankData does NOT arm when the guild-bank window is hidden", function()
  -- A guildmate moving something in the vault pushes the same event to everyone in the guild.
  clearContext()
  mocks.__guildVisible = false
  NS.Ledger:OnGuildBankData()
  mocks.__guildVisible = true
  assertEqual(NS.State.openContext, nil, "someone else's deposit is not this player's visit")
  clearContext()
end)

test("Ledger:OnGuildBankData still reconciles a context that is already open", function()
  -- Demoting the arming must not demote the reconcile: tab contents arriving mid-visit is still how
  -- the guild side of a deposit is seen at all.
  clearContext()
  NS.Ledger:OpenContext("GUILD_BANK")
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "GUILD_BANK", "still armed, and still reconciling")
  clearContext()
end)

test("Ledger:OnGuildBankData queries the tabs when it arms", function()
  clearContext()
  mocks.__guildQueried, mocks.__guildQueryCount = {}, 0
  NS.Ledger:OnGuildBankData()
  assertEqual(mocks.__guildQueryCount, 8)
  clearContext()
end)

test("Ledger:OnGuildBankData never steals the context from an open bank frame", function()
  clearContext()
  NS.Ledger:OpenContext("BANK_FRAME")
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "BANK_FRAME", "the bank frame has its own events")
  clearContext()
end)

test("Ledger:OnGuildBankData re-arms without churning the baseline once armed", function()
  clearContext()
  NS.Ledger:OnGuildBankData()
  local first = NS.State.lastSnapshot
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "GUILD_BANK")
  assertTrue(NS.State.lastSnapshot == first, "a second data event does not re-baseline")
  clearContext()
end)

test("Ledger: a guild-bank deposit is recorded with no open event at all", function()
  local before = NS.Database:Count()
  local savedTabs, savedBag = mocks.__guildTabs, mocks.__containers[BAG_ID]
  mocks.__guildTabs, mocks.__guildQueried = { [1] = {} }, {}
  mocks.__containers[BAG_ID] = { slots = 1, [1] = { itemID = 171276, count = 7 } }
  clearContext()

  NS.Ledger:OnGuildBankData()                       -- window opened; contents arrive
  mocks.__containers[BAG_ID][1] = nil               -- deposited
  mocks.__guildTabs[1][1] = { itemID = 171276, count = 7 }
  NS.Ledger:OnGuildBankData()                       -- the tab update arrives
  NS.Ledger:Reconcile()

  assertEqual(NS.Database:Count(), before + 1)
  local e = NS.Database:Ledger()[NS.Database:Count()]
  assertEqual(e.store, "GUILD_BANK")
  assertEqual(e.direction, "DEPOSIT")
  assertEqual(e.quantity, 7)

  NS.Database:Delete(function(x) return x.itemID == 171276 end)
  mocks.__guildTabs, mocks.__containers[BAG_ID] = savedTabs, savedBag
  clearContext()
end)

test("Ledger: the guild bank disarms once its window has gone", function()
  clearContext()
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "GUILD_BANK")
  mocks.__guildVisible = false
  NS.Ledger:Reconcile()
  assertEqual(NS.State.openContext, nil, "stops rescanning six tabs on every bag update")
  mocks.__guildVisible = true
  clearContext()
end)

-- Disarming on the next Reconcile is not enough on its own. Closing the guild bank changes nothing,
-- so NO event fires afterwards and no reconcile pass runs — the context (and anything watching it)
-- would sit armed until some unrelated bag update happened along, possibly minutes later. The frame's
-- own OnHide is the only notice the client actually gives.

test("Ledger: hiding the guild-bank frame disarms it there and then, with no event", function()
  clearContext()
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "GUILD_BANK")
  mocks.__closeGuildBank()          -- no event, no bag change: just the window going away
  assertEqual(NS.State.openContext, nil, "the close is noticed immediately, not on the next event")
  mocks.__guildVisible = true
  clearContext()
end)

test("Ledger: the guild-bank OnHide hook is installed once, not once per data event", function()
  clearContext()
  local before = #mocks.__guildHideHooks
  NS.Ledger:OnGuildBankData()
  NS.Ledger:OnGuildBankData()
  NS.Ledger:OnGuildBankData()
  assertTrue(#mocks.__guildHideHooks <= before + 1, "a hook must never be stacked per event")
  clearContext()
end)

test("Ledger:Diagnose reports whether the guild-bank frame hooks are installed", function()
  clearContext()
  NS.Ledger:OnGuildBankData()
  local text = table.concat(NS.Ledger:Diagnose(), "\n")
  assertTrue(text:find("guild bank frame hooks: installed", 1, true) ~= nil,
    "the one line that explains a guild session that never starts, or never ends")
  clearContext()
end)

test("Ledger: hiding the guild-bank frame leaves an open BANK frame alone", function()
  -- The guild frame hides whenever it is not the window you are looking at. Closing the character
  -- bank's session on that basis would throw away a baseline that is still in use.
  clearContext()
  NS.Ledger:OpenContext("BANK_FRAME")
  mocks.__closeGuildBank()
  assertEqual(NS.State.openContext, "BANK_FRAME", "only the guild bank's own context is ended")
  mocks.__guildVisible = true
  clearContext()
end)

test("Ledger: an unknown window state does NOT disarm the guild bank", function()
  -- A build with no guild-bank frame to inspect reports nil, meaning "cannot tell". That must not
  -- be read as "hidden", or the guild bank would disarm itself instantly and permanently there.
  clearContext()
  NS.Ledger:OnGuildBankData()
  local savedFrame = mocks.GuildBankFrame
  mocks.GuildBankFrame = nil
  NS.Ledger:Reconcile()
  assertEqual(NS.State.openContext, "GUILD_BANK", "still armed when visibility is unknowable")
  mocks.GuildBankFrame = savedFrame
  clearContext()
end)

test("Compat.IsGuildBankVisible is three-valued", function()
  mocks.__guildVisible = true
  assertEqual(NS.Compat.IsGuildBankVisible(), true)
  mocks.__guildVisible = false
  assertEqual(NS.Compat.IsGuildBankVisible(), false)
  local savedFrame = mocks.GuildBankFrame
  mocks.GuildBankFrame = nil
  assertEqual(NS.Compat.IsGuildBankVisible(), nil, "no frame means unknown, not hidden")
  mocks.GuildBankFrame, mocks.__guildVisible = savedFrame, true
end)
