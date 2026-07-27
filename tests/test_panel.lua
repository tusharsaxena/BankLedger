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
