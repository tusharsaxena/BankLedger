-- tests/test_names_client.lua — the surfaces that print a character name, sized for the client's
-- name shape (WoW Forever port, design D12; forever-quirks-§4). Retail keys are "Name-Realm" and
-- keep today's widths; WoW Forever keys are "First Surname" (Compat.PlayerName, BL-03), so the
-- Character dropdown is wider there, per client, picked once at load by ClientKey() (clients-§5).
-- The narrow Insights bar labels keep their width and truncate, with the whole name in the bar's
-- tooltip. Every case runs on both kit profiles (`KA0S_KIT_CLIENT=forever lua tests/run.lua`) and
-- asserts the client's own answer.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local B = NS.Browser
local W = NS.InsightsWidgets
local I = NS.Insights
local LT = NS.LedgerTable
local FOREVER = NS.Compat.ClientKey() == "forever"
local ELLIPSIS = "\226\128\166"

test("names: the Character dropdown width is a per-client table picked once by ClientKey()", function()
  local rows = B._CHAR_DD_W_BY_CLIENT
  assertTrue(type(rows) == "table", "B._CHAR_DD_W_BY_CLIENT")
  assertEqual(rows.retail, 140, "Retail keeps the pre-port width")
  assertTrue((rows.forever or 0) > rows.retail, "WoW Forever's is wider")
  assertEqual(B._CHAR_DD_W, rows[NS.Compat.ClientKey()])
end)

test("names: the toolbar floor counts the client's Character dropdown width", function()
  -- Row 2 is the seven dropdowns and six gaps; the floor every width test rests on must include
  -- the client's Character width, or Export and the window floor drift from what is built.
  local others = 110 + 110 + 130 + 100 + 110 + 110
  assertEqual(B._DROPDOWNS_W, others + B._CHAR_DD_W + 6 * B._DD_GAP)
  assertTrue(B:MinWidth() >= B._DROPDOWNS_W + B._DD_GAP + 110, "the floor still fits Export")
end)

test("names: the built Character dropdown has the client's width", function()
  NS.Browser:Show()
  local dd = B._dd and B._dd.char
  assertTrue(dd ~= nil, "the Character dropdown exists once the filter bar is built")
  assertEqual(dd:GetWidth(), B._CHAR_DD_W)
  NS.Browser:Hide()
end)

test("names: a sample character's closed label fits the Character dropdown on WoW Forever", function()
  if not FOREVER then return end
  -- The closed label gets the width minus 6 px left and 16 px right (the arrow), at ~6 px a glyph,
  -- behind a 12 px class icon and its space. Every sample "First Surname" must fit whole.
  for _, row in ipairs(NS.SampleCharacters()) do
    local need = 14 + #row.fullName * 6
    assertTrue(B._CHAR_DD_W - 22 >= need,
      row.fullName .. " needs " .. need .. " px, the label has " .. (B._CHAR_DD_W - 22))
  end
end)

test("names: ShortChar keeps the client's distinguishing part of the key", function()
  if FOREVER then
    -- No hyphen in a WoW Forever key: the whole "First Surname" is the name.
    assertEqual(W.ShortChar("Traxex Silentshot"), "Traxex Silentshot")
  else
    assertEqual(W.ShortChar("Traxex-Frostmourne"), "Traxex")
  end
  assertEqual(W.ShortChar(NS.Util.PlayerKey()), (NS.Compat.PlayerName()))
end)

test("names: a per-character bar truncates a long name and its tooltip keeps it whole", function()
  local key = FOREVER and "Sampleblade Mockvale" or "Samplebladeeeee-Samplerealm"
  local row = { icon = "", label = W.ShortChar(key), labelMax = 14, fullLabel = key }
  local shown = I.BarLabel(row)
  assertEqual(shown, (FOREVER and "Sampleblade M" or "Samplebladeee") .. ELLIPSIS)
  assertEqual(I.ElementTip(row.fullLabel, "7"), key .. ":  7")
end)

test("names: a stacked or split character row's tooltip carries the whole WoW Forever name", function()
  if not FOREVER then return end
  local key = "Sampleblade Mockvale"
  local rows = W.BuildStackRows({ [key] = { BANK = 3 } }, { "BANK" }, { labelOf = W.ShortChar })
  assertEqual(rows[1].label, key, "the stack row keeps the whole name for its tooltip")
  assertEqual(I.ElementTip(rows[1].fullLabel or rows[1].label, rows[1].value), key .. ":  3")
end)

test("names: Truncate never cuts inside a multibyte character", function()
  -- WoW names carry accents ("Trâxex"); a byte cut that splits one prints a broken glyph. The cut
  -- backs off to the character's first byte, so it can only come out shorter, never broken.
  local text = (W.Truncate("Tr\195\162xex Silentshot", 4))
  assertEqual(text, "Tr" .. ELLIPSIS)
  -- An ASCII cut is byte-for-byte what it always was.
  assertEqual((W.Truncate("Traxex Silentshot", 14)), "Traxex Silent" .. ELLIPSIS)
end)

test("names: the Character column describes the client's key shape", function()
  local desc = LT:Column("char").desc
  if FOREVER then
    assertTrue(not desc:find("Realm", 1, true), "no realm on WoW Forever: " .. desc)
    assertTrue(desc:find("surname", 1, true) ~= nil, "names the surname: " .. desc)
  else
    assertEqual(desc, "Who moved it \226\128\148 full Name-Realm, class-colored, behind its class icon.")
  end
end)
