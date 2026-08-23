-- tests/test_marks.lua — the shared marks, on this addon's own windows.
--
-- WHY A SUITE AT ALL, when tests/test_mediasetup.lua already proves the seam answers paths. Because
-- a mark fails in the one way nothing else notices: a texture that does not load draws NOTHING and
-- raises NOTHING. A misspelt catalog name, an extension left on a path, a wrapper that dropped the
-- argument carrying the addon's folder — each of those ships a title bar with no visible close
-- button, a filter row with no ▼, a column header that looks unsortable. Every other suite stays
-- green, `luacheck` stays green, and the only instrument that would have caught it is a screenshot.
--
-- So this suite asserts the PATH and the ARGUMENT, never the appearance, and it asserts both rungs:
-- what a working install draws, and what an install without LibKa0s draws instead. The lower rung
-- is the half that rots unwatched — it is the branch nobody looks at — and it is the whole reason
-- the old Blizzard art was kept rather than deleted.

local T = _G.BL_TEST
local NS = T.NS
local test = T.test
local assertEqual, assertTrue, assertNil = T.assertEqual, T.assertTrue, T.assertNil
local Loader = T.Loader
local mocks = T.mocks

local B = NS.Browser
local ICONS = "Interface\\AddOns\\BankLedger\\libs\\LibKa0s\\media\\icons\\"

-- Load a fresh, isolated addon WITHOUT the vendored library, up to and including `stop`. Same shape
-- and same reason as tests/test_mediasetup.lua's: the degraded arm runs the REAL fallback branch
-- rather than a hand-written stub, because a stub proves only that the stub works.
local function loadDegraded(stop)
  local m = T.makeMocks()
  local ns = {}
  for _, path in ipairs(Loader.tocFiles("BankLedger.toc")) do
    Loader.load(path, ns, m)
    if path == stop then break end
  end
  assertTrue(m.LibStub("LibKa0s-Media-1.0", true) == nil,
    "the degraded arm still has the library — every case built on it would prove nothing")
  return ns, m
end

local function readSource(path)
  local fh = io.open(path, "r")
  assertTrue(fh ~= nil, path .. " is not on disk")
  local src = fh:read("*a")
  fh:close()
  return src
end

-- EVERY .lua THIS ADDON SHIPS, TAKEN FROM THE TOC rather than written down here.
--
-- THE HOLE THIS CLOSES, TWICE OVER. The two scans below first walked a hardcoded four-FILE list --
-- the four files that happened to draw a mark the day they were written -- and then a hardcoded
-- three-DIRECTORY list, which still missed defaults/ and locales/. Either way the files outside the
-- list are a blind spot for exactly the failure the scans exist to catch: a `NS.Icon("eraser")`
-- appended to one of them names something in neither NS.ICON_NAMES nor the library's catalog, so it
-- answers nil forever, its `if mark then` branch never runs, no art draws, nothing raises, and the
-- whole suite stays green. Both holes were reproduced, not imagined.
--
-- The TOC is the one list that cannot go stale, because it is the same list the CLIENT loads: a file
-- this addon ships and does not name here would not run in game either. `Loader.tocFiles` already
-- drops `libs/` and normalises the separators, so what comes back is exactly the addon's own source
-- and nothing else -- defaults/ and locales/ included, and any directory added later covered from
-- the commit that makes its files load.
--
-- settings/ is in here as well as in its own case further down, which asserts that nothing under
-- settings/ resolves a mark at all. Two lenses on one directory costs nothing and means a new file
-- there is covered by both from the moment it lands.
local SOURCE_FILES = Loader.tocFiles("BankLedger.toc")
assertTrue(#SOURCE_FILES > 0,
  "the TOC listed no source files; the scan could not look and would have passed over everything")

-- ── the close control: one edit, four title bars ─────────────────────────────────────────────

test("marks: the close control on every window this addon draws is the collection's close", function()
  local btn = B:MakeCloseButton(mocks.__stubFrame(), function() end)
  assertTrue(btn.icon ~= nil, "B:MakeCloseButton drew no art")
  assertEqual(btn.icon.__texture, ICONS .. "close")
  assertNil(btn.glyph, "the × was drawn as well as the mark, not instead of it")
end)

test("marks: the close path is EXTENSIONLESS, which is the half that fails silently", function()
  -- ".tga" on the end is a recorded spelling of a file the client will not open. It draws nothing,
  -- raises nothing, and leaves a title bar the player cannot close except with Escape.
  local btn = B:MakeCloseButton(mocks.__stubFrame(), function() end)
  assertTrue(btn.icon.__texture:match("%.%w+$") == nil,
    "the close path carries an extension: " .. tostring(btn.icon.__texture))
end)

test("marks degraded: with no library the close button is still the × it always was", function()
  local ns = loadDegraded("modules/Browser.lua")
  local clicked = false
  local btn = ns.Browser:MakeCloseButton(mocks.__stubFrame(), function() clicked = true end)
  assertNil(btn.icon, "a degraded install resolved art from a payload it does not have")
  assertTrue(btn.glyph ~= nil, "the × rung was removed — the window now has no way to close")
  btn:__fire("OnClick")
  assertTrue(clicked, "the degraded close button does not close anything")
end)

test("marks: the × is DRAWN in exactly one place, so one edit reached all four title bars", function()
  -- The ledger window, the session window and both export popups all reach the close control
  -- through B:MakeCloseButton. A second hand-rolled × anywhere in modules/ is a window that would
  -- silently keep the old glyph while the other three moved on.
  --
  -- SetText lines only, deliberately: modules/Insights.lua spells six chart titles "By Character ×
  -- Store", and that × is prose in a heading, not a control anybody clicks.
  local drawn = {}
  for _, file in ipairs({ "modules/Browser.lua", "modules/SessionWindow.lua", "modules/Export.lua",
                          "modules/LedgerTable.lua", "modules/Insights.lua",
                          "modules/InsightsWidgets.lua" }) do
    local n = 0
    for line in io.lines(file) do
      n = n + 1
      if not line:match("^%s*%-%-") and line:find('SetText("\\195\\151")', 1, true) then
        drawn[#drawn + 1] = file .. ":" .. n
      end
    end
  end
  assertEqual(#drawn, 1, "the × is drawn at: " .. table.concat(drawn, ", "))
  assertTrue(drawn[1]:match("^modules/Browser%.lua:") ~= nil,
    "the × moved out of B:MakeCloseButton's fallback rung, to " .. drawn[1])
end)

-- ── the dropdown affordance ──────────────────────────────────────────────────────────────────

test("marks: every filter dropdown wears chevron-down, through the shared factory", function()
  -- B:MakeDropdown is a forwarder onto the file-local MakeDropdown, and modules/Export.lua's Data
  -- Set dropdown is built through it. Reading the art back off the widget the FORWARDER returned is
  -- what proves the seam is carried rather than merely present.
  local dd = B:MakeDropdown(mocks.__stubFrame(), 100)
  assertEqual(dd.arrow.__texture, ICONS .. "chevron-down")
end)

test("marks degraded: the dropdown keeps Blizzard's arrow, never a ▼ character", function()
  -- The ▼ character is not in the client's default font and renders as a box, which is why the
  -- lower rung is a TEXTURE rather than the glyph it looks like.
  local ns = loadDegraded("modules/Browser.lua")
  local dd = ns.Browser:MakeDropdown(mocks.__stubFrame(), 100)
  assertEqual(dd.arrow.__texture, "Interface\\Buttons\\Arrow-Down-Up")
end)

test("marks: a chosen row of a multi-select menu wears the collection's tick", function()
  -- The button a filter menu drops from wears the flat `chevron-down`; Blizzard's beveled tick on
  -- the rows below it was the one widget in this addon where two eras of art met. It is `confirm`
  -- now. tests/test_browser.lua reads the composed markup back off a painted row, which is the draw
  -- site; what is pinned HERE is the LADDER, because the menu is a singleton opened once per run and
  -- a second suite cannot reach a degraded copy of it. Both rungs on one line, so a nil can never be
  -- concatenated into the escape and the extensionless spelling is the one that ships.
  local src = readSource("modules/Browser.lua")
  assertTrue(src:find('NS.Icon and NS.Icon("confirm")', 1, true) ~= nil,
    "the multi-select tick stopped asking the seam for the collection's mark")
  assertTrue(src:find('or "Interface\\\\Buttons\\\\UI-CheckBox-Check"', 1, true) ~= nil,
    "the tick's Blizzard rung is gone — a degraded install concatenates nil into a |T…|t escape")
end)

-- ── the inline markup: sort arrows and the group expander ────────────────────────────────────

-- The four inline marks are STRINGS appended to a FontString, not textures on a widget, so there is
-- no `.icon` to read back. They are asserted AT THE DRAW SITE anyway — LT:UpdateHeaderArrows for the
-- column header, LT:BindRow for the group header — because a mirror table of the same four strings
-- stays correct while the draw site drifts, and that is not a hypothetical: both draw sites were
-- mutated back to Blizzard's literals against exactly such a mirror and the suite stayed green.
--
-- Two minimal stand-ins, deliberately hand-built rather than mocked frames: what is under test is
-- the TEXT these two functions compose, and a stand-in that records SetText is the whole instrument.
local function stubFS()
  local fs = { text = "" }
  function fs:SetText(v) self.text = v end
  function fs:GetText() return self.text end
  return fs
end

-- Drive LT:UpdateHeaderArrows over one column button and hand back what its label ended up as. The
-- table's own sort state is parked and restored: it is shared, and every other suite reads it.
local function headerLabel(LT, key, asc)
  local frame, sortKey, sortAsc, groupBy = LT.headerFrame, LT.sortKey, LT.sortAsc, LT.groupBy
  local fs = stubFS()
  LT.headerFrame = { buttons = { [key] = { fs = fs } } }
  LT.sortKey, LT.sortAsc, LT.groupBy = key, asc, "none"
  LT:UpdateHeaderArrows()
  LT.headerFrame, LT.sortKey, LT.sortAsc, LT.groupBy = frame, sortKey, sortAsc, groupBy
  return fs:GetText()
end

-- Bind one GROUP HEADER row and hand back the text the expander went into. `kind = "header"` is the
-- only branch of BindRow that draws an expander at all.
local function groupHeaderText(LT, collapsed)
  local header = stubFS()
  header.Show = function() end
  local row = {
    stripe = { SetShown = function() end },
    dirGlyph = { Hide = function() end },
    header = header,
    cells = {},
  }
  for _, col in ipairs(LT.COLUMNS) do row.cells[col.key] = stubFS() end
  LT:BindRow(row, { kind = "header", collapsed = collapsed, label = "Character Bank", count = 3 }, 1)
  return header:GetText()
end

test("marks: the column-header sort arrow is the collection's, at the site that draws it", function()
  -- Read back off the header button's own FontString after UpdateHeaderArrows composed it, so a
  -- draw site that went back to Blizzard's Arrow-Up-Up is red here rather than green against a
  -- mirror of the right answer. Extensionless inside |T…|t for the same reason as SetTexture.
  assertEqual(headerLabel(NS.LedgerTable, "date", true), "Date |T" .. ICONS .. "sort-up:0|t")
  assertEqual(headerLabel(NS.LedgerTable, "date", false), "Date |T" .. ICONS .. "sort-down:0|t")
end)

test("marks: the group header's expander is a chevron, at the site that draws it", function()
  -- Collapsed points right, expanded points down, and the two-space gap and the gray `(count)` the
  -- header has always carried are untouched: the mark changed and the layout did not.
  assertEqual(groupHeaderText(NS.LedgerTable, true),
    "|T" .. ICONS .. "chevron-right:0|t  Character Bank  |cff808080(3)|r")
  assertEqual(groupHeaderText(NS.LedgerTable, false),
    "|T" .. ICONS .. "chevron-down:0|t  Character Bank  |cff808080(3)|r")
end)

test("marks degraded: every inline mark falls back to the exact art it used to be", function()
  -- Byte for byte, at the draw site, including the leading space on the arrow. This is the rung a
  -- player without LibKa0s sees, and it is the one that rots unwatched: nothing else looks at it.
  local ns = loadDegraded("modules/LedgerTable.lua")
  local LT = ns.LedgerTable
  assertEqual(headerLabel(LT, "date", true), "Date |TInterface\\Buttons\\Arrow-Up-Up:0|t")
  assertEqual(headerLabel(LT, "date", false), "Date |TInterface\\Buttons\\Arrow-Down-Up:0|t")
  assertEqual(groupHeaderText(LT, true),
    "|TInterface\\Buttons\\UI-PlusButton-Up:0|t  Character Bank  |cff808080(3)|r")
  assertEqual(groupHeaderText(LT, false),
    "|TInterface\\Buttons\\UI-MinusButton-Up:0|t  Character Bank  |cff808080(3)|r")
end)

-- ── marks BESIDE a label, never instead of one ───────────────────────────────────────────────

test("marks: the filter bar's Export button carries its mark BESIDE the word", function()
  B:Show()
  local btn = B._exportBtn
  assertTrue(btn ~= nil, "the filter bar was never built")
  assertEqual(btn.icon.__texture, ICONS .. "export")
  -- LEFT with an inset, so the centred label is where it always was and a nil icon leaves the
  -- button identical rather than off-centre.
  assertEqual((btn.icon:GetPoint(1)), "LEFT")
  -- AND THE WORD IS STILL THERE, read back off the built button rather than grepped for in the
  -- factory. BESIDE is a property of the CALL SITE: the factory can draw a label perfectly and the
  -- caller still hand it "", which ships a wordless 166px glyph button — and an empty one on an
  -- install with no LibKa0s to answer NS.Icon.
  assertEqual(btn.fs:GetText(), "Export",
    "the filter bar's Export button lost its word; a mark never replaces a wide action label")
end)

test("marks: the export modal's action button carries its mark BESIDE the words", function()
  local f = NS.Export:Open({})
  assertTrue(f ~= nil, "the export modal did not build, so its mark was never checked")
  local btn = f.csvBtn
  assertTrue(btn ~= nil, "the export modal has no action button to mark")
  assertEqual(btn.icon.__texture, ICONS .. "export")
  assertEqual((btn.icon:GetPoint(1)), "LEFT")
  assertEqual(btn.fs:GetText(), "Export to CSV",
    "the modal's action button lost its words; a modal whose only control is a wordless glyph is "
    .. "a modal you have to click to understand")
end)

test("marks: BESIDE means beside — the modal's button keeps the width its mark was sized for",
  function()
    -- The width and the anchors are ONE decision and this is the assertion that keeps them so. The
    -- button asks for 150 against a 372-wide modal; a TOPLEFT/TOPRIGHT pair (the shape every other
    -- control in this modal uses) silently overrides it to 340 and strands the mark at LEFT+10 with
    -- the centred label 150px away. Nothing errors, nothing is missing, and `btn.icon:GetPoint(1)`
    -- still answers "LEFT" — so the gap is invisible to every other case here. The anchor SET is
    -- what carries it: one point, by the top edge, is a button that stays 150 wide.
    --
    -- The mock resolves a FontString to its parent frame, so the label's own `SetPoint("CENTER")`
    -- lands in this list too. That is why the assertion counts HORIZONTAL EDGE anchors rather than
    -- points: CENTER and TOP are both fine, and a single LEFT or RIGHT among them is the thing that
    -- stretches a button to its parent's width.
    local f = NS.Export:Open({})
    local horiz = {}
    for _, p in ipairs(f.csvBtn.__points) do
      if p.point:find("LEFT") or p.point:find("RIGHT") then horiz[#horiz + 1] = p.point end
    end
    assertEqual(table.concat(horiz, ", "), "",
      "the modal's action button is anchored to a horizontal edge; that overrides its width and "
      .. "strands the mark at the far-left edge with the label 150px away")
    assertEqual(f.csvBtn:GetWidth(), 150,
      "the width the mark and the words were fitted to is gone")
  end)

test("marks: both button factories still draw the label unconditionally", function()
  -- The whole point of BESIDE is that the words do not depend on the art. A label moved inside the
  -- `if path then` branch would read fine and would leave a degraded install with a blank button.
  --
  -- THIS IS THE FACTORY HALF ONLY, and on its own it proves nothing about what a player sees: the
  -- factory can draw a label perfectly while the CALL SITE hands it "". The two BESIDE cases above
  -- read the words back off the built button for that half.
  for _, file in ipairs({ "modules/Browser.lua", "modules/Export.lua" }) do
    local src = readSource(file)
    assertTrue(src:find('fs:SetPoint("CENTER")', 1, true) ~= nil,
      file .. " no longer centres a button label")
    assertTrue(src:find("fs:SetText(text)", 1, true) ~= nil,
      file .. " no longer sets a button label from its own argument")
  end
end)

-- ── the search box ───────────────────────────────────────────────────────────────────────────

test("marks: the search box wears a magnifier, and its words step aside for it", function()
  B:Show()
  local box = B._search
  assertTrue(box ~= nil, "the filter bar was never built")
  assertEqual(box.icon.__texture, ICONS .. "search")
  assertEqual(box.__insets[1], 21, "the typed text did not move over to clear the mark")
end)

test("marks degraded: with no magnifier the search box's inset does not move", function()
  -- One decision owns both numbers (MakeSearchMark returns the inset), which is what stops a
  -- degraded install indenting its placeholder around art that is not there.
  local src = readSource("modules/Browser.lua")
  assertTrue(src:find("local searchInset = MakeSearchMark(search)", 1, true) ~= nil,
    "the search inset is no longer decided in one place")
  assertTrue(src:find("search:SetTextInsets(searchInset, 6, 0, 0)", 1, true) ~= nil,
    "the text inset stopped following the mark's own answer")
  assertTrue(src:find('ph:SetPoint("LEFT", searchInset, 0)', 1, true) ~= nil,
    "the placeholder stopped following the mark's own answer")
end)

-- ── the rules the collection paid for ────────────────────────────────────────────────────────

test("marks: every name this addon draws is spelled in NS.ICON_NAMES", function()
  -- tests/test_mediasetup.lua checks that list against the LIBRARY's catalog. This checks it against
  -- the SOURCE: a mark added to a window and not added to the list is invisible to that cross-check,
  -- which is the drift the list exists to catch.
  --
  -- TWO SHAPES, AND THEY ARE ALL OF THEM. `NS.Icon("…")` is every mark drawn onto a widget —
  -- including the two BESIDE marks, whose button factories take a RESOLVED PATH rather than a name
  -- precisely so the name stays here where this scan can read it. `markup("…"` is the four inline
  -- |T…|t marks. The case below is what keeps a third shape from appearing and going unseen.
  --
  -- COMMENT LINES ARE SKIPPED, the same way tests/test_mediasetup.lua's registration guard skips
  -- them: both factory comments now quote `NS.Icon("export")` while explaining why the path is
  -- resolved at the call site, and a scan that could not tell a note from a draw site would report
  -- the note.
  local declared = {}
  for _, name in ipairs(NS.ICON_NAMES or {}) do declared[name] = true end
  local missing = {}
  for _, file in ipairs(SOURCE_FILES) do
    local n = 0
    for line in io.lines(file) do
      n = n + 1
      if not line:match("^%s*%-%-") then
        for name in line:gmatch('NS%.Icon%("([%w%-]+)"%)') do
          if not declared[name] then
            missing[#missing + 1] = file .. ":" .. n .. " draws '" .. name .. "'"
          end
        end
        for name in line:gmatch('markup%("([%w%-]+)"') do
          if not declared[name] then
            missing[#missing + 1] = file .. ":" .. n .. " draws '" .. name .. "'"
          end
        end
      end
    end
  end
  assertEqual(table.concat(missing, ", "), "")
end)

test("marks: every icon name reaches NS.Icon as a LITERAL, where the scan above can read it",
  function()
    -- THE HOLE THIS CLOSES. The scan above reads NAMES out of the source, so a name that reaches
    -- NS.Icon through a variable is a name it never sees — and a mark asking for a spelling that is
    -- in neither NS.ICON_NAMES nor the library's catalog answers nil, skips its `if` branch, draws
    -- no art, raises nothing and passes every suite in this repo. That is exactly what happened
    -- while both button factories took a bare `icon` NAME as a trailing argument: `"export"` was a
    -- string in an argument list and no pattern here matched it.
    --
    -- ONE INDIRECTION IS ALLOWED, and it is counted rather than described: modules/LedgerTable.lua's
    -- file-local `markup(name, blizzard, lead)`, whose own call sites spell literals the scan
    -- above reads. A second one appearing anywhere is a name this suite has gone blind to.
    --
    -- THE DECLARATION IS NOT A CALL. Now that this walks every file the addon ships rather than the
    -- four that draw marks, it reaches core/MediaSetup.lua, where `function NS.Icon(name)` is the
    -- seam itself — a parameter list, not a name being asked for.
    local ALLOWED = { ["modules/LedgerTable.lua"] = 1 }
    local opaque = {}
    for _, file in ipairs(SOURCE_FILES) do
      local n, found = 0, 0
      for line in io.lines(file) do
        n = n + 1
        if not line:match("^%s*%-%-") and not line:match("function%s+NS%.Icon") then
          for arg in line:gmatch('NS%.Icon%s*%(%s*(.)') do
            if arg ~= '"' then
              found = found + 1
              if found > (ALLOWED[file] or 0) then
                opaque[#opaque + 1] = file .. ":" .. n
              end
            end
          end
        end
      end
      assertEqual(found, ALLOWED[file] or 0,
        file .. " has " .. found .. " NS.Icon call site(s) taking a non-literal name, not "
        .. tostring(ALLOWED[file] or 0))
    end
    assertEqual(table.concat(opaque, ", "), "")
  end)

test("marks: no mark carries a tooltip of its own", function()
  -- One shipped on a console for a single release and was removed rather than repositioned: anchored
  -- under the control, it covered the first line of the log. A mark that needs a tooltip to be
  -- understood is a label that should have stayed a label — and the two BESIDE marks here are
  -- exactly that, a label that stayed.
  B:Show()
  local f = NS.Export:Open({})
  --
  -- INDEXED AND COUNTED, not `ipairs`d: a nil at any index truncates an ipairs loop, so a close mark
  -- that stopped resolving would leave this case iterating zero times and passing — a test that
  -- would go green with the marks entirely absent, which is the shape this suite's own header says
  -- it exists to avoid.
  local arts = {
    ["the close control"]      = B:MakeCloseButton(mocks.__stubFrame(), function() end).icon,
    ["the dropdown chevron"]   = B:MakeDropdown(mocks.__stubFrame(), 100).arrow,
    ["the filter bar's Export"] = B._exportBtn and B._exportBtn.icon,
    ["the search magnifier"]   = B._search and B._search.icon,
    ["the modal's Export to CSV"] = f and f.csvBtn and f.csvBtn.icon,
  }
  local n = 0
  for what, art in pairs(arts) do
    n = n + 1
    assertTrue(art ~= nil, what .. " went missing before its tooltip was checked")
    assertNil(art:GetScript("OnEnter"), what .. "'s mark grew an OnEnter of its own")
  end
  assertEqual(n, 5, "a mark dropped out of the list this case walks")
end)

test("marks: nothing under settings/ resolves a mark — that panel is the Options library's",
  function()
    -- Its rows, its page headers and its Defaults button are LibKa0s-Options-1.0 widgets. A mark
    -- put on one of them is this addon reaching into another repo's surface, and it drifts the
    -- moment that repo restyles.
    local offenders = {}
    for _, file in ipairs({ "settings/Panel.lua", "settings/Schema.lua", "settings/Slash.lua",
                            "settings/OptionsSetup.lua" }) do
      if readSource(file):find("NS.Icon", 1, true) then offenders[#offenders + 1] = file end
    end
    assertEqual(table.concat(offenders, ", "), "")
  end)

test("marks: the art that is NOT a mark was left alone", function()
  -- The catalog is marks, not chrome, and not identity. Each of these was looked at and deliberately
  -- kept: a resize grip is a Blizzard control with a paired -Highlight state the catalog has no
  -- companion for; the class circles are full-colour art that must not be tinted; the logo and the
  -- launcher icon are this addon's face and the launcher one must match ## IconTexture.
  local kept = {
    ["modules/Browser.lua"]       = { "UI-ChatIM-SizeGrabber-Up", "inv_misc_bag_15" },
    ["modules/SessionWindow.lua"] = { "UI-ChatIM-SizeGrabber-Up" },
    ["core/Util.lua"]             = { "UI-Classes-Circles" },
    ["core/Constants.lua"]        = { "bankledger.logo.tga" },
  }
  for file, paths in pairs(kept) do
    local src = readSource(file)
    for _, p in ipairs(paths) do
      assertTrue(src:find(p, 1, true) ~= nil, file .. " lost " .. p .. ", which is not a mark")
    end
  end
end)
