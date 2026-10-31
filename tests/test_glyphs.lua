-- tests/test_glyphs.lua — the display-glyph guard over this addon's own Lua (LibKa0s v1.82.0, kit
-- revision 45's tests/_kit/glyphs.lua; BL-02 of Ka0sAddonsCommonTasks
-- docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-19).
--
-- Ten skins draw this addon's text in a dozen faces, and a character one of them lacks is a box in
-- that skin only: the footer's "Database ≈ 1.6 MB" read "Database [] 1.6 MB" under Obsidian
-- (Expressway has no U+2248). So every string literal in a tracked .lua file outside libs/ and
-- tests/ carries only characters every shipped face draws (the kit's safe set, read from their
-- cmaps). A string drawn in the mono role carries a `glyph: mono` marker on its line (the ▲/▼
-- direction glyphs, which JetBrains Mono draws); the debug console's lines are skipped by the kit
-- (they draw in mono too).

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("glyphs: display strings use only characters every shipped skin face draws", function()
  -- red under: a ≈, →, ▼ or ▲ (or any other character outside the kit's safe set) in a string the
  -- addon paints in a skin face.
  T.assertDisplayGlyphs{ label = "BankLedger" }
end)

-- The three strings the guard found (D_GLYPHS): each now reads in ASCII, at runtime as well.

test("glyphs: the ledger window's footer estimates the size with ~, not ≈", function()
  local B = NS.Browser
  B:Show()
  local ok, err = pcall(function()
    B:UpdateDbSize()
    local text = B._dbFooter:GetText() or ""
    assertTrue(text:find("^Database ~") ~= nil, "the footer reads: " .. text)
    T.assertGlyphSafe(text, "the footer")
  end)
  B:Hide()
  if not ok then error(err, 0) end
end)

test("glyphs: the Direction column's tooltip names the directions without the arrows", function()
  local col
  for _, c in ipairs(NS.LedgerTable.COLUMNS) do if c.key == "direction" then col = c end end
  assertTrue(col ~= nil, "a direction column")
  T.assertGlyphSafe(col.desc, "the Direction tooltip")
  assertEqual(col.desc, "Deposit means it left your bags for the store; withdraw means it came back out.")
end)
