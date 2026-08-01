local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local P = NS.Panel

-- Registration is idempotent (`registered` guard), so one call at load time gives every case in this
-- suite the same three canvas frames the game would get. The bodies are NOT built here: each panel's
-- content is lazy on first OnShow (options-ui-§1), which never fires headless.
P:Register()

local function panel(name)
  local p = mocks.__settingsPanels[name]
  assertTrue(p ~= nil, "panel '" .. name .. "' was registered")
  return p
end

-- ── The Settings framework contract (options-ui-§1) ────────────────────────────

test("Panel: every registered canvas frame is handed to the Settings framework", function()
  assertTrue(mocks.__settingsPanels["Ka0s Bank Ledger"] ~= nil, "landing page")
  assertTrue(mocks.__settingsPanels["General"] ~= nil, "General subcategory")
  assertTrue(mocks.__settingsPanels["Filters"] ~= nil, "Filters subcategory")
end)

-- Blizzard's Settings window calls all three on the registered canvas — OnCommit on apply, OnDefault
-- from its own footer defaults control, OnRefresh on re-show. A missing one is an error surface the
-- addon cannot see, so every panel carries all three.
test("Panel: each canvas frame defines OnCommit, OnDefault and OnRefresh", function()
  for _, name in ipairs({ "Ka0s Bank Ledger", "General", "Filters" }) do
    local p = panel(name)
    assertEqual(type(p.OnCommit),  "function", name .. " OnCommit")
    assertEqual(type(p.OnDefault), "function", name .. " OnDefault")
    assertEqual(type(p.OnRefresh), "function", name .. " OnRefresh")
  end
end)

test("Panel: the landing page's OnDefault is inert — it manages no settings", function()
  local p = panel("Ka0s Bank Ledger")
  assertTrue(p.defaultsOnClick == nil, "no defaults action parked on the landing page")
  p.OnDefault()   -- must not raise
end)

-- The header Defaults button and Blizzard's own defaults control must be ONE implementation, not two
-- that can drift. setDefaultsAction sets both from a single closure; this pins that identity.
test("Panel: OnDefault is the same closure as the header Defaults button", function()
  for _, name in ipairs({ "General", "Filters" }) do
    local p = panel(name)
    assertTrue(p.defaultsOnClick ~= nil, name .. " parks a defaults action")
    assertEqual(p.OnDefault, p.defaultsOnClick, name .. " shares one defaults implementation")
  end
end)

-- Blizzard's footer control is NOT confirm-gated the way the body's "Reset all" button is, so the
-- General page's defaults action must stay non-destructive: settings and window geometry only, never
-- the ledger. The destructive path stays behind KA0S_BANKLEDGER_RESETALL.
test("Panel: the General defaults action resets settings but never the ledger", function()
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end

  NS.Schema:Set("settings.qualityThreshold", 4)
  local before = NS.Database:Count()

  local ok, err = pcall(function() panel("General").OnDefault() end)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end

  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0, "settings returned to stock")
  assertEqual(NS.Database:Count(), before, "the ledger is untouched")
end)

test("Panel: OnCommit and OnRefresh are inert — writes land immediately and OnShow refreshes", function()
  for _, name in ipairs({ "Ka0s Bank Ledger", "General", "Filters" }) do
    local p = panel(name)
    p.OnCommit()
    p.OnRefresh()
  end
end)

-- ── Refresh on write (options-ui-§11 / §41) ────────────────────────────────────
--
-- An open panel MUST reflect live state after a mutation, and the write seam is where that
-- belongs. It was nowhere: NS.Schema:Set fired the row's onChange and stopped, so `/bl set` with
-- the settings window open left every widget showing the old value until the window was closed and
-- reopened. P:Refresh also walked P.general alone, so even once wired, every OTHER page stayed
-- stale — and the next page added would have inherited that silently.
--
-- The panel bodies are lazy and never build headless, so these drive the contract rather than the
-- widgets: a fake page is registered through the same registry the real ones use.

-- Register a throwaway page whose refresher just counts, and return { count, show, hide, remove }.
local function fakePage(shown)
  local ran = 0
  local ctx = { panel = mocks.__stubFrame(), refreshers = { function() ran = ran + 1 end } }
  ctx.panel.name = "Fake"
  if shown then ctx.panel:Show() else ctx.panel:Hide() end
  local reg = P.__pagesForTest()
  reg[#reg + 1] = ctx
  return {
    count  = function() return ran end,
    remove = function() reg[#reg] = nil end,
  }
end

test("Panel: a schema write refreshes an open page", function()
  local page = fakePage(true)
  local before = page.count()
  NS.Schema:Set("settings.enabled", not NS.Schema:Get("settings.enabled"))
  assertTrue(page.count() > before,
    "NS.Schema:Set must repaint an open panel — this is what `/bl set` was missing")
  page.remove()
end)

test("Panel: a schema write does NOT refresh a hidden page", function()
  -- One of General's refreshers walks the whole ledger to estimate the SavedVariables size, so an
  -- off-screen refresh is pure cost (F-018). The Blizzard window shows one subcategory at a time.
  local page = fakePage(false)
  local before = page.count()
  NS.Schema:Set("settings.enabled", not NS.Schema:Get("settings.enabled"))
  assertEqual(page.count(), before, "a hidden page must not be refreshed")
  page.remove()
end)

test("Panel: Refresh walks EVERY registered page, not just General", function()
  local a, b = fakePage(true), fakePage(true)
  local a0, b0 = a.count(), b.count()
  P:Refresh()
  assertTrue(a.count() > a0 and b.count() > b0, "both open pages refresh")
  b.remove(); a.remove()
end)

test("Panel: a bulk reset coalesces into exactly ONE refresh", function()
  -- Ten schema rows through the write seam would be ten refreshes, and ten ledger walks.
  local page = fakePage(true)
  local before = page.count()
  P:Batch(function()
    for _, row in ipairs(NS.Schema.Schema) do NS.Schema:Set(row.path, NS.Schema:Default(row.path)) end
  end)
  assertEqual(page.count() - before, 1, "one refresh for the whole batch")
  page.remove()
end)

test("Panel: Batch unwinds its depth on the error path", function()
  -- Latched above zero, the panel silently stops refreshing for the rest of the session and only
  -- /reload recovers it (options-ui-§189 makes the same point about a re-entrancy guard).
  local page = fakePage(true)
  local ok = pcall(function() P:Batch(function() error("boom") end) end)
  assertTrue(not ok, "Batch must re-raise")
  local before = page.count()
  NS.Schema:Set("settings.enabled", not NS.Schema:Get("settings.enabled"))
  assertTrue(page.count() > before, "refreshes must resume after a raising batch")
  page.remove()
end)

test("Panel: /bl resetall repaints, and only once", function()
  local page = fakePage(true)
  local before = page.count()
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  NS.Slash:CliResetAll()
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  assertEqual(page.count() - before, 1, "the whole reset is one repaint")
  page.remove()
end)

test("Panel: a refresher that raises does not stop the others", function()
  local reg = P.__pagesForTest()
  local ran = 0
  local ctx = { panel = mocks.__stubFrame(),
    refreshers = { function() error("bad widget") end, function() ran = ran + 1 end } }
  ctx.panel.name = "Fake"
  ctx.panel:Show()
  reg[#reg + 1] = ctx
  P:Refresh()
  assertEqual(ran, 1, "each refresher is pcall'd — one dead widget must not take the UI with it")
  reg[#reg] = nil
end)
