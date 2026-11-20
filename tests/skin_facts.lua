-- tests/skin_facts.lua -- what this addon tells the kit's two skin gates (skinning-§1, kit revision
-- 50): Kit.skinValues for tests/_kit/test_skin_values.lua and Kit.skinSwitch for
-- tests/_kit/test_skin_switch.lua. Both are set from tests/run.lua.
--
-- THE TYPED-VALUE GATE. Every typed color and texture in this addon is a kit category or one of
-- `rows` (the store palette's meaning hues, and two kit row categories, kit revision 58), and a new
-- hit is a value to read through a token, or a row naming its cause id or category.
-- `calls` adds the one paint call of this addon's own: NS.SkinBar(tex, r, g, b, a).
--
-- THE SWITCH TEST. One entry per painted surface, each narrow on purpose: the kit walks an answered
-- frame's regions and children, so a whole window would pass on its title alone and prove nothing
-- about the rest. A surface answers the smallest object that draws it. From kit revision 58 each
-- setter family (texture, color, font, shadow) a surface draws has to move on its own.
--
-- The surfaces stand on a private addon over the kit's paint recorder, built on the first read, as
-- tests/test_skin_chrome.lua's are: the kit flips the owner's skin, and the shared addon's windows,
-- on a mock whose regions store nothing, have no regions or children to walk.
--
-- `paint` is the redraw the mock cannot fire: a pooled row's bind, a menu's open. A recorded
-- primitive needs none. No surface has a companion, because this addon has no HUD and none of its
-- rows follows a FromSkin key. `scope = "panel"` is the one settings-page surface. The Insights
-- faces are drawn through the pane's renderers, which set their colors on every pass, so no surface
-- needs `scope = "fonts"` any more.

return function(T)
  local OWNER = "BankLedger"
  local ns, m, Skin

  local function addon()
    if ns then return ns, m, Skin end
    m = T.makeMocks()
    dofile("tests/_kit/mock_paint.lua")(m)
    -- wow_mock.lua leaves GameTooltip nil for its headless guards; the lines surface needs one.
    local function noop() end
    m.GameTooltip = { AddLine = noop, AddDoubleLine = noop, ClearLines = noop, Hide = noop }
    ns = {}
    T.Loader.loadAll(T.libka0sFiles, ns, m)
    T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
    ns:InitDB()
    ns.Schema:Register()
    ns.Ledger:Enable()
    -- The test env loads no LSM, and a skin's face resolves through it. A stand-in after the load, so
    -- a skin key answers a path of its own and S.Font draws.
    m.__libs["LibSharedMedia-3.0"] = {
      Fetch = function(_, kind, key) return "Interface\\" .. kind .. "\\" .. key end,
    }
    Skin = m.LibStub("LibKa0s-Skin-1.0")
    return ns, m, Skin
  end

  local function ledger()
    addon()
    ns.Browser:Show()
    return ns.Browser:GetWindow()
  end

  local function session()
    addon()
    ns.SessionWindow:Show()
    return ns.SessionWindow:GetWindow()
  end

  local function export()
    addon()
    return ns.Export:Open({})
  end

  -- A row of the History table, off the pool, as LT:Bind hands one to LT:BindRow.
  local ENTRY = { kind = "item", direction = "in", count = 2, itemID = 1, ts = 1770000000, char = "A-B" }
  local HEADER = { kind = "header", label = "Character Bank", count = 3 }
  local row
  local function bind(index, item)
    ns.LedgerTable:BindRow(row, item or { entry = ENTRY }, index)
  end
  local function bound(index, item)
    ledger()
    row = row or ns.LedgerTable:BuildRow()
    bind(index, item)
    return row
  end

  local function parent()
    addon()
    return m.CreateFrame("Frame", nil, m.UIParent)
  end

  local strip, placed
  local function hud(make)
    return function()
      addon()
      return make(ns.InsightsWidgets, parent())
    end
  end

  -- The Insights pane's own renderers (modules/Insights_Render.lua), over a stand-in pane. A refresh
  -- after a switch (I:Reskin) re-runs them, and they set every label's color and paint every fill
  -- on each pass, so a surface drawn through them is drawn as the pane draws it, colors included
  -- (kit revision 58 reports a face that moves while no color is set on it). Each surface gets its
  -- own section header and pool; the repaint releases the pool and renders again, and the pool hands
  -- the first position the object it had (LibKa0s-Pool's backward park).
  local pane, sections = nil, 0
  local function insights()
    addon()
    if not pane then
      local content = parent()
      pane = setmetatable({ content = content, headers = {}, pools = {}, panelPool = ns.InsightsWidgets.NewPool() },
        { __index = ns.Insights })
    end
    return pane
  end

  -- A surface over one renderer: `render(p, key)` draws one section and answers the object to watch.
  local function rendered(spec, render)
    local key
    local function draw()
      local p = insights()
      local W = ns.InsightsWidgets
      if not key then
        sections = sections + 1
        key = "skinSurface" .. sections
        p.headers[key] = W.MakeSectionHeader(p.content, "T")
        p.pools[key] = W.NewPool()
      end
      W.ReleaseAll(p.pools[key])
      W.ReleasePanels(p.panelPool)
      return render(p, key)
    end
    spec.build = draw
    spec.paint = function() draw() end
    return spec
  end

  -- One ranked bar (I:RenderBars), in the neutral bucket's color, its label self-legending in it.
  local function rankedBar(p, key)
    p:RenderBars(key, key, { { label = "Reagent", frac = 1, value = "3" } }, 0, 400)
    return p.pools[key].active[1]
  end

  -- One Top-of-the-list row (I:RenderList), its name in text.value.
  local function listRow(p)
    p:RenderList("Title", { { name = "Linen Cloth", right = "20" } }, 0, 0, 200)
    return p.panelPool.active[1]._rows.active[1]
  end

  -- A band is the frame's own backdrop or texture, and the kit walks whatever a frame answers, so the
  -- strings on it and its children would answer for the band. For the length of a surface the frame
  -- shows the walk its textures alone; facts.reset puts its walkers back.
  local walkers = {}
  local function band(frame)
    local regions, children = rawget(frame, "GetRegions"), rawget(frame, "GetChildren")
    walkers[#walkers + 1] = function()
      rawset(frame, "GetRegions", regions)
      rawset(frame, "GetChildren", children)
    end
    rawset(frame, "GetRegions", function(self)
      local out = {}
      for _, region in ipairs({ regions(self) }) do
        if region:GetObjectType() == "Texture" then out[#out + 1] = region end
      end
      return unpack(out)
    end)
    rawset(frame, "GetChildren", function() end)
    return frame
  end

  local function surface(name, spec)
    spec.name = name
    return spec
  end

  -- No surface for the line under a title band: no window draws one (R4-SEP); each window's
  -- 1px dividerBar is an anchor with nothing on it (tests/test_skin_chrome.lua holds that).
  local surfaces = {
    surface("the window's shell", { build = function()
      addon()
      local f = m.CreateFrame("Frame", nil, m.UIParent, "BackdropTemplate")
      ns.Browser:ApplySkin(f)
      return f
    end }),
    surface("the ledger's title band", { build = function() return band(ledger().titleBar) end }),
    surface("the session window's title band", { build = function() return band(session().titleBar) end }),
    surface("the export modal's title band", { build = function() return band(export().titleBar) end }),
    surface("the ledger's title", { build = function() return ledger().title end }),
    surface("the ledger's close control", { build = function() return ledger().closeButton end }),
    surface("the ledger's test badge", { build = function() return ledger().testBadge end }),
    surface("a ledger tab", { build = function() return ledger().tabs.History end }),
    surface("the rule under the tabs", { build = function() return ledger().tabRule end }),
    surface("the footer's hairline", { build = function() return band(ledger().footer) end }),
    surface("the footer's text", { build = function()
      ledger()
      return ns.Browser._footer
    end }),
    surface("a filter bar button", { build = function()
      ledger()
      return ns.Browser._exportBtn
    end }),
    surface("the test strip", { build = function() return ledger().testStrip end }),
    surface("the History header band", { build = function()
      ledger()
      return band(ns.LedgerTable.headerFrame)
    end }),
    surface("a History header label", { build = function()
      ledger()
      local _, btn = next(ns.LedgerTable.headerFrame.buttons)
      return btn.fs
    end }),
    surface("the History empty text", { build = function()
      ledger()
      return ns.LedgerTable.emptyText
    end }),
    surface("a History row's cell", {
      build = function() return bound(1).cells.direction end,
      paint = function() bind(1) end,
    }),
    surface("a History row's stripe", {
      build = function() return bound(2).stripe end,
      paint = function() bind(2) end,
    }),
    surface("a History group header", {
      build = function() return bound(1, HEADER).header end,
      paint = function() bind(1, HEADER) end,
    }),
    surface("the session window's title", { build = function() return session().title end }),
    surface("the session window's header label", { build = function()
      session()
      local _, cell = next(ns.SessionWindow.headerFrame.cells)
      return cell.fs
    end }),
    surface("the session window's close control", { build = function() return session().closeButton end }),
    surface("the session window's header band", { build = function()
      session()
      return band(ns.SessionWindow.headerFrame)
    end }),
    surface("the session window's empty text", { build = function()
      session()
      return ns.SessionWindow.emptyText
    end }),
    surface("the export modal's title", { build = function() return export().titleFS end }),
    surface("the export modal's close control", { build = function() return export().closeBtn end }),
    surface("the export modal's dataset picker", { build = function() return export().datasetDD end }),
    surface("the export modal's button", { build = function() return export().csvBtn end }),
    surface("the row menu", {
      build = function()
        ledger()
        return ns.LedgerTable:ShowRowMenu(m.UIParent, ENTRY)
      end,
      paint = function() ns.LedgerTable:ShowRowMenu(m.UIParent, ENTRY) end,
    }),
    surface("a KPI card", { build = hud(function(W, p) return W.MakeCard(p) end) }),
    surface("a list panel", { build = hud(function(W, p) return W.MakeListPanel(p, "Title") end) }),
    surface("a section divider's title", { build = hud(function(W, p) return W.MakeSectionDivider(p, "T").fs end) }),
    surface("a bar's face", rendered({}, function(p, key) return rankedBar(p, key).label end)),
    surface("a bar's track", {
      build = hud(function(W, p)
        local bar = W.MakeBar(p)
        placed = function() W.PlaceBar(bar, p, 0, 0, 100, 0.5) end
        placed()
        return bar.track
      end),
      paint = function() placed() end,
    }),
    surface("a split bar's side", {
      build = hud(function(W, p)
        local bar = W.MakeSplitBar(p)
        local left = { label = "In", value = "1", frac = 0.5, color = W.MUTED, text = "t" }
        local right = { label = "Out", value = "1", frac = 0.5, color = W.MUTED, text = "t" }
        placed = function() W.PlaceSplitBar(bar, p, 0, 0, 100, left, right) end
        placed()
        return bar
      end),
      paint = function() placed() end,
    }),
    surface("a legend swatch", { build = hud(function(W, p) return W.MakeSwatch(p) end) }),
    surface("a list row's face", rendered({}, function(p) return listRow(p).name end)),
    surface("a strip bar's fill", {
      build = hud(function(W, p)
        local f = { fill = p:CreateTexture(nil, "ARTWORK") }
        strip = f
        W.PaintStripBar(f)
        return f.fill
      end),
      paint = function() ns.InsightsWidgets.PaintStripBar(strip) end,
    }),
    surface("a tooltip's lines", {
      build = function()
        addon()
        return m.GameTooltip
      end,
      paint = function(tip)
        tip:ClearLines()
        ns.LedgerTable.AddMoneyTooltip({ kind = "money", quantity = 10000 })
      end,
    }),
    surface("the settings page's empty line", {
      scope = "panel",
      build = function()
        addon()
        local fs = parent():CreateFontString(nil, "OVERLAY")
        fs:SetText(ns.SkinPanelEscape("text.disabled") .. "(none)|r")
        return fs
      end,
      paint = function(fs) fs:SetText(ns.SkinPanelEscape("text.disabled") .. "(none)|r") end,
    }),
  }

  -- Kit revision 58's scanner reads three-number tables and multi-assigned triples, which revision
  -- 57 did not, so these three lines are new hits with no change to the code under them.
  local STORE = "a store's identity hue in the named meaning table C.StoreRGB: the store is what the "
    .. "color tells, and skinning-§9 keeps a meaning table's hue under every skin (the skin-defaults "
    .. "audit's OVERRIDE row, LibKa0s#97)"
  local rows = {
    { file = "core/Constants.lua", substring = "BANK         = {", why = STORE, cause = "MC" },
    { file = "core/Constants.lua", substring = "WARBAND_BANK = {", why = STORE, cause = "MC" },
    { file = "core/Constants.lua", substring = "GUILD_BANK   = {", why = STORE, cause = "MC" },
    { file = "core/Constants.lua", substring = "BAGS         = {", why = STORE, cause = "MC" },
    { file = "modules/InsightsWidgets.lua", substring = "series = { { 1, 1, 1 } }",
      why = "the palette's guard for a skin with no chart.series: every skin states one, and Ka0s "
        .. "Default's fills any gap, so no player sees it",
      category = "unreachable default" },
    { file = "settings/Panel.lua", substring = "local r, g, b, a = 1, 1, 1, 1",
      why = "a texture's vertex color as the panel's diagnostic dump prints it, as numbers in a "
        .. "report; it starts at white for a texture that cannot answer and draws nothing",
      category = "not a color" },
  }

  return {
    rows = rows,
    calls = { SkinBar = { 2, 3, 4 } },
  }, {
    owner = OWNER,
    skin = function()
      addon()
      return Skin
    end,
    reset = function()
      for i = #walkers, 1, -1 do
        walkers[i]()
        walkers[i] = nil
      end
      if m.__fireTimers then m.__fireTimers() end
    end,
    surfaces = surfaces,
  }
end
