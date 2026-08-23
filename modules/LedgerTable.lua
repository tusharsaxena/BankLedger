local addonName, NS = ...   -- luacheck: ignore addonName
NS.LedgerTable = NS.LedgerTable or {}
local LT = NS.LedgerTable
local C = NS.Constants
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

-- Virtualized pooled-row table over Database:Query — filter → sort → group → slice → bind.
-- Rows are pooled (events-frames-taint-§6): a 10,000-entry ledger still only ever builds as many
-- row frames as fit on screen.

local ROW_H = 18
local HEADER_H = 20
local ITEM_MIN = 150   -- minimum width of the flex (Item) column
local COL_GAP = 8      -- horizontal space between columns

-- Direction and store colors + the ▲/▼ direction glyphs live in Constants (C.DirectionRGB,
-- C.DirectionGlyph, C.StoreRGB): the filter dropdowns paint their options from the same tables, so
-- a store or a direction can never read one color in the table and another in the menu.
--
-- The glyph is drawn as a real text glyph rather than a texture, and the reason is COLOR rather
-- than alignment: it takes the direction's red or green from the same SetTextColor call that paints
-- the label beside it, where a texture would need its own tint kept in step by hand. It is the one
-- arrow pair in this addon that stayed a character — the column-header sort arrows and the group
-- expanders further down this file are the collection's marks, and they are textures.
-- It needs the MONO face: the default WoW font has no ▲/▼ and renders a box, while JetBrains Mono
-- carries both. The face is no longer this addon's own — it arrives with the LibKa0s payload and
-- C.FONT_MONO resolves to it through core/MediaSetup.lua, falling back to the client font (and so
-- to a box) only where the library is missing. That is an accepted, documented deviation: the mono
-- face is a sanctioned styling exception scoped to the debug console (debug-logging-§2), and this
-- extends it to one glyph. See docs/ARCHITECTURE.md ▸ Documented deviations.
local ARROW_SIZE, ARROW_GAP = 12, 2

-- Gold movements name themselves "Gold" in the Item column. A quality color would be a lie (gold
-- has no quality), so they take a pale gold — deliberately LIGHTER than the 1/0.82/0 the column
-- headers and window title use, so a gold row reads as data and never as a heading.
local MONEY_RGB = { 1.00, 0.91, 0.55 }

local EM_DASH = "\226\128\148"

-- ── Column model ────────────────────────────────────────────────────────────────
-- width 0 + flex = true means "absorb the remaining width" (the Item column). Character is
-- deliberately LAST; insert any new column BEFORE it so that stays true.
LT.COLUMNS = {
  { key = "date", label = "Date", width = 66, align = "LEFT",
    desc = "Date the movement happened.",
    valueFn = function(e) return NS.Util.FormatDate(e.ts) end,
    sortFn = function(e) return e.ts or 0 end },
  { key = "time", label = "Time", width = 40, align = "LEFT",
    desc = "Time of day the movement happened.",
    valueFn = function(e) return NS.Util.FormatClock(e.ts) end,
    sortFn = function(e) return e.ts or 0 end },
  { key = "direction", label = "Direction", width = 82, align = "LEFT",
    desc = "Deposit (\226\150\188) means it left your bags for the store; "
      .. "withdraw (\226\150\178) means it came back out.",
    valueFn = function(e) return C.DirectionLabel[e.direction] or e.direction or "" end,
    sortFn = function(e) return e.direction or "" end },
  { key = "store", label = "Store", width = 112, align = "LEFT",
    desc = "Which bank the movement was to or from.",
    valueFn = function(e) return C.StoreLabel[e.store] or e.store or "" end,
    sortFn = function(e) return C.StoreLabel[e.store] or e.store or "" end },
  { key = "item", label = "Item", width = 0, flex = true, align = "LEFT",
    desc = "What moved. Gold movements show as Gold. Hover for the item tooltip.",
    valueFn = function(e)
      return e.itemName or (e.itemID and ("Item " .. e.itemID)) or "?"
    end,
    sortFn = function(e) return (e.itemName or ""):lower() end },
  { key = "qty", label = "Qty", width = 92, align = "RIGHT",
    desc = "How many moved — the stack size for an item, the amount for a gold movement.",
    valueFn = function(e)
      if e.kind == C.Kind.MONEY then return NS.Util.FormatMoney(e.quantity) end
      return tostring(e.quantity or 1)
    end,
    -- Sorts on what the cell shows: a gold row by its copper amount, an item row by stack size.
    sortFn = function(e) return e.quantity or 1 end },
  { key = "quality", label = "Quality", width = 64, align = "LEFT",
    desc = "Item quality (Poor to Legendary). Gold has none, and shows a dash.",
    valueFn = function(e)
      if e.kind == C.Kind.MONEY then return EM_DASH end
      return e.quality ~= nil and NS.Compat.QualityLabel(e.quality) or ""
    end,
    sortFn = function(e) return e.quality or -1 end },
  { key = "type", label = "Type", width = 86, align = "LEFT",
    desc = "Item type. Gold movements are typed as Gold.",
    valueFn = function(e) return NS.Util.EntryType(e) end,
    sortFn = function(e) return NS.Util.EntryType(e):lower() end },
  { key = "subtype", label = "Sub-type", width = 92, align = "LEFT",
    desc = "Item sub-type (Cloth, Potion, Swords, …). Gold movements are sub-typed as Gold.",
    valueFn = function(e) return NS.Util.EntrySubType(e) end,
    sortFn = function(e) return NS.Util.EntrySubType(e):lower() end },
  -- Character is always the last column (see the order note above).
  { key = "char", label = "Character", width = 144, align = "LEFT",
    desc = "Who moved it — full Name-Realm, class-colored, behind its class icon.",
    valueFn = function(e) return NS.Util.ClassIconMarkup(e.classFile) .. (e.char or "") end,
    sortFn = function(e) return (e.char or ""):lower() end },
}

local COLUMN_BY_KEY = {}
for _, col in ipairs(LT.COLUMNS) do COLUMN_BY_KEY[col.key] = col end

-- Pure cell text for a column key + entry (unit-tested; the UI binds through the same path).
function LT:CellText(key, entry)
  local col = COLUMN_BY_KEY[key]
  if not col then return "" end
  return col.valueFn(entry)
end

-- The column spec behind a key (label, width, align, desc, valueFn, sortFn), or nil.
--
-- Public because the session window (modules/SessionWindow.lua) renders a SUBSET of these same
-- columns in its own slim table. Sharing the spec — rather than restating widths and valueFns there
-- — is what guarantees the Item column shows the same text and measures the same width in both
-- windows. See also LT:PaintCell for the matching color seam.
function LT:Column(key)
  return COLUMN_BY_KEY[key]
end

-- ── Pipeline ────────────────────────────────────────────────────────────────────
LT.filter = {}

-- Active sort. Default: newest movement first.
LT.sortKey = "date"
LT.sortAsc = false

-- Columns whose sortFn yields a number: a new sort on these starts descending (largest/newest
-- first); text columns start ascending (A→Z). Re-clicking the active column toggles.
local NUMERIC_SORT = { date = true, time = true, qty = true, quality = true }

-- Grouping. "none" = flat; otherwise entries are partitioned under collapsible headers.
LT.groupBy = "none"
LT.collapsed = {}
LT.groupAsc = true

-- The header sort arrows and the group-header expander, as INLINE TEXTURE MARKUP appended to a
-- FontString. Markup rather than characters because the default WoW font has no ▲/▼ and no boxed
-- +/-, and the header labels are drawn in the GAME font — only the MONO face (C.FONT_MONO, which
-- the LibKa0s payload supplies through core/MediaSetup.lua) carries the direction glyphs, and it is
-- not this font.
--
-- The marks are the collection's now, with the Blizzard textures kept as the rung below. Both
-- spellings are built HERE, as named locals, so the choice is made once at load and every draw site
-- appends a string that is already correct. Concatenating a path into an escape sequence at the
-- point of use is what turns "no LibKa0s" into a header whose label ends in a rectangle.
--
-- ":0" sizes the texture to the surrounding line height. The library's paths are EXTENSIONLESS by
-- contract and that is exactly what |T…|t wants; a path carrying ".tga" here draws nothing and
-- raises nothing, which in a column header reads as "this column does not sort".
local function markup(name, blizzard, lead, tint)
  local path = NS.Icon and NS.Icon(name)
  return (lead or "") .. "|T" .. (path or blizzard) .. ":" .. (tint or "0") .. "|t"
end

-- The gold every column header and every group header is drawn in, and the ONE place it is written
-- down: HEADER_RGB feeds the FontString calls below (SetTextColor takes 0-1) AND the tint on all
-- four marks (the escape takes 0-255), so a mark cannot drift away from the word beside it.
--
-- ALL FOUR ARE TINTED, because all four sit inside gold text — the two sort arrows in the column
-- header's label, the two expanders in the group header's. The art ships near-white by contract,
-- and near-white beside gold reads as a second colour inside one string rather than as one control.
--
-- The tint is why they carry the LONG form of the escape. ":0" alone is "size to the line and draw
-- the art as it is". Vertex colour is the LAST three arguments of the full sequence, so all eleven
-- in front of them have to be spelled: height and width 0 keep the auto-size that ":0" gave, and
-- 64:64 with 0:64:0:64 is the whole texture uncropped (the numbers are a ratio, so they hold
-- whatever the file's real dimensions are).
--
-- The tint rides on the ESCAPE, not on the art, so it survives the fall to the Blizzard rung: a
-- degraded install draws the same boxed +/- and Arrow-Up-Up it always did, in the header's gold.
local HEADER_RGB = { 1, 0.82, 0 }
local function tint255(rgb)
  local function b(v) return math.floor(v * 255 + 0.5) end
  return ("0:0:0:0:64:64:0:64:0:64:%d:%d:%d"):format(b(rgb[1]), b(rgb[2]), b(rgb[3]))
end
local HEADER_TINT = tint255(HEADER_RGB)

local ARROW_ASC   = markup("sort-up",       "Interface\\Buttons\\Arrow-Up-Up",       " ", HEADER_TINT)
local ARROW_DESC  = markup("sort-down",     "Interface\\Buttons\\Arrow-Down-Up",     " ", HEADER_TINT)
local GROUP_SHUT  = markup("chevron-right", "Interface\\Buttons\\UI-PlusButton-Up",  nil, HEADER_TINT)
local GROUP_OPEN  = markup("chevron-down",  "Interface\\Buttons\\UI-MinusButton-Up", nil, HEADER_TINT)

-- Shared by "type" and "subtype": both key on the EFFECTIVE type, so gold movements gather under
-- "Gold" exactly as the column shows them, and an untyped item reads "Unknown" rather than blank.
local function typeGroup(v)
  if v == "" then v = "Unknown" end
  return v, v
end

-- One arm per group-by mode, each returning `label, raw` — the label the header shows and the raw
-- value the namespaced key is built from.
--
-- MODULE-LEVEL, built once at file load: groupOf runs once per entry inside BuildDisplayList, over
-- a ledger that can be thousands of rows, so the dispatch must allocate nothing per call. It also
-- replaces up to eight string comparisons with one hash lookup.
local GROUP_OF = {
  store = function(e)
    return C.StoreLabel[e.store] or e.store or "Unknown", e.store or "?"
  end,
  direction = function(e)
    return C.DirectionLabel[e.direction] or e.direction or "?", e.direction or "?"
  end,
  kind = function(e)
    return C.KindLabel[e.kind] or e.kind or "?", e.kind or "?"
  end,
  type = function(e) return typeGroup(NS.Util.EntryType(e)) end,
  subtype = function(e) return typeGroup(NS.Util.EntrySubType(e)) end,
  -- Keyed on the quality id, so the group sorts Poor→Legendary rather than alphabetically. Gold
  -- has no quality; it gathers under its own group instead of vanishing into "Poor".
  quality = function(e)
    if e.quality == nil then return "None", "none" end
    return NS.Compat.QualityLabel(e.quality), tostring(e.quality)
  end,
  char = function(e)
    local c = e.char or "Unknown"
    return c, c
  end,
  -- The key stays ISO (stable, unique per calendar day); the label matches the Date column.
  day = function(e)
    return NS.Util.FormatDate(e.ts or 0), date("%Y-%m-%d", e.ts or 0)
  end,
}

-- Group identity + display label for an entry under the active group-by. The key is namespaced by
-- group mode, so the collapsed-state map can never collide across modes. \001 is an unprintable
-- separator. An unknown mode answers "?" on both halves, never nil.
local function groupOf(groupBy, e)
  local arm = GROUP_OF[groupBy]
  local label, raw = "?", "?"
  if arm then label, raw = arm(e) end
  return groupBy .. "\001" .. raw, label
end

-- groupBy mode → the table column it corresponds to (which drives the header arrow and the
-- group-order toggle) and the human prefix each group header carries.
local GROUP_COLUMN = { store = "store", direction = "direction", char = "char", day = "date",
                       type = "type", subtype = "subtype", quality = "quality" }
-- "kind" is the Item/Gold split, NOT the Type column — its prefix says so, now that Type groups too.
local GROUP_PREFIX = { store = "Store", direction = "Direction", kind = "Item/Gold",
                       char = "Character", day = "Day", type = "Type", subtype = "Sub-type",
                       quality = "Quality" }

-- Stable sort by the active column into a NEW array (entries are never mutated). Lua 5.1's
-- table.sort is not stable, so equal keys tiebreak on the original index to keep their prior order.
function LT:SortEntries(entries)
  local col = COLUMN_BY_KEY[self.sortKey]
  if not col or not col.sortFn then return entries end
  local keyFn, asc = col.sortFn, self.sortAsc
  local deco = {}
  for i = 1, #entries do
    deco[i] = { r = entries[i], i = i, k = keyFn(entries[i]) }
  end
  table.sort(deco, function(a, b)
    if a.k ~= b.k then
      if asc then return a.k < b.k end
      return a.k > b.k
    end
    return a.i < b.i
  end)
  local out = {}
  for i = 1, #deco do out[i] = deco[i].r end
  return out
end

-- Handle a header click. If the table is grouped by this column, flip the GROUP order; otherwise
-- set the row sort.
function LT:SetSort(key)
  local col = COLUMN_BY_KEY[key]
  if not col or not col.sortFn then return end
  local groupedCol = self.groupBy ~= "none" and GROUP_COLUMN[self.groupBy] or nil
  if key == groupedCol then
    self.groupAsc = not self.groupAsc
    self:UpdateHeaderArrows()
    self:Refresh()
    return
  end
  if self.sortKey == key then
    self.sortAsc = not self.sortAsc
  else
    self.sortKey = key
    self.sortAsc = not NUMERIC_SORT[key]
  end
  self:UpdateHeaderArrows()
  self:Refresh()
end

function LT:SetGroupBy(key)
  self.groupBy = key or "none"
  self:Refresh()
end

function LT:ToggleCollapse(key)
  self.collapsed[key] = (not self.collapsed[key]) or nil
  self:Refresh()
end

-- Turn an (already-sorted) entry array into the flat display list. With no grouping every entry is
-- a { kind = "row" } item; with grouping, entries are partitioned under { kind = "header" } items
-- labeled "<Column>: <Value>" with a count. A collapsed group emits only its header. The active
-- row sort still holds within each group.
function LT:GroupEntries(entries)
  local list = {}
  local groupBy = self.groupBy
  if not groupBy or groupBy == "none" then
    for _, e in ipairs(entries) do list[#list + 1] = { kind = "row", entry = e } end
    return list
  end

  local colKey = GROUP_COLUMN[groupBy]
  local col = colKey and COLUMN_BY_KEY[colKey]
  local sortFn = col and col.sortFn
  local prefix = GROUP_PREFIX[groupBy] or "?"

  local order, byKey = {}, {}
  for _, e in ipairs(entries) do
    local key, valueLabel = groupOf(groupBy, e)
    local g = byKey[key]
    if not g then
      g = { key = key, label = prefix .. ": " .. valueLabel, rows = {},
            sortKey = sortFn and sortFn(e) or valueLabel }
      byKey[key] = g
      order[#order + 1] = g
    end
    g.rows[#g.rows + 1] = e
  end

  local asc = self.groupAsc ~= false
  table.sort(order, function(a, b)
    if a.sortKey ~= b.sortKey then
      if asc then return a.sortKey < b.sortKey end
      return a.sortKey > b.sortKey
    end
    return a.key < b.key
  end)

  for _, g in ipairs(order) do
    local collapsed = self.collapsed[g.key] or false
    list[#list + 1] = { kind = "header", key = g.key, label = g.label,
                        count = #g.rows, collapsed = collapsed }
    if not collapsed then
      for _, e in ipairs(g.rows) do list[#list + 1] = { kind = "row", entry = e } end
    end
  end
  return list
end

-- The base dataset the table shows: the synthetic dataset in test mode, else the live ledger.
function LT:CurrentEntries()
  return NS.Database:ActiveLedger()
end

-- Filter → sort → group into the flat display list the virtualizer binds. matchCount is the number
-- of entries that passed the filter (the "X" the footer shows), captured before grouping inserts
-- header items.
function LT:BuildDisplayList()
  local entries = NS.Database:QueryList(self:CurrentEntries(), self.filter)
  self.matchCount = #entries
  return self:GroupEntries(self:SortEntries(entries))
end

function LT:SetFilter(filter)
  self.filter = filter or {}
  self:Refresh()
end

-- The filtered entries in the current sort/group order (group headers dropped) — the "Current View"
-- dataset the Export modal serializes, so what you export is what you see.
function LT:OrderedFilteredEntries()
  local out = {}
  for _, item in ipairs(self:BuildDisplayList()) do
    if item.kind == "row" then out[#out + 1] = item.entry end
  end
  return out
end

-- ── Test dataset (test-mode) ────────────────────────────────────────────────────
-- A synthetic ledger so the window and the Insights charts can be seen (and positioned) without
-- waiting to actually fill a bank. A deliberately NON-uniform spread so the charts read like real
-- play: weighted stores/directions/classes/zones/types/qualities/timestamps, a handful of "hot"
-- items over a long tail, and an evening-leaning hour curve. A deterministic PRNG (fixed seed,
-- NOT math.random) keeps the data byte-identical every run so the headless tests stay stable. A
-- coverage seed pass first guarantees every store, both directions, every quality and every
-- character appear and that the range spans >14 days regardless of how the dice fall.

local TEST_CLASSES = {
  "MAGE", "PALADIN", "ROGUE", "PRIEST", "DRUID", "WARRIOR", "SHAMAN", "EVOKER",
}
-- A few "mains" do most of the banking.
local TEST_CLASS_W = {
  { "MAGE", 16 }, { "PALADIN", 13 }, { "ROGUE", 11 }, { "PRIEST", 9 },
  { "DRUID", 8 }, { "WARRIOR", 8 }, { "SHAMAN", 6 }, { "EVOKER", 5 },
}
local TEST_ZONES = {
  { name = "Valdrakken",       mapID = 2112 },
  { name = "Dornogal",         mapID = 2339 },
  { name = "Orgrimmar",        mapID = 85 },
  { name = "Stormwind City",   mapID = 84 },
  { name = "Silvermoon City",  mapID = 110 },
  { name = "Boralus",          mapID = 1161 },
}
local TEST_ZONE_W = { { 1, 26 }, { 2, 20 }, { 4, 16 }, { 3, 14 }, { 5, 12 }, { 6, 8 } }
-- The character bank takes the bulk; the guild bank is the lightest.
local TEST_STORE_W = {
  { "BANK", 38 }, { "WARBAND_BANK", 30 }, { "GUILD_BANK", 24 },
}
local TEST_TYPE_W = {
  { "Tradegoods", 30 }, { "Consumable", 22 }, { "Armor", 16 }, { "Weapon", 12 },
  { "Recipe", 8 }, { "Gem", 7 }, { "Miscellaneous", 5 },
}
local TEST_SUBTYPES = {
  Tradegoods    = { "Cloth", "Herb", "Metal & Stone", "Leather", "Elemental" },
  Consumable    = { "Potion", "Flask", "Food & Drink", "Bandage" },
  Armor         = { "Cloth", "Leather", "Mail", "Plate" },
  Weapon        = { "Swords", "Daggers", "Staves", "Bows" },
  Recipe        = { "Tailoring", "Alchemy", "Blacksmithing" },
  Gem           = { "Cut Gem", "Uncut Gem" },
  Miscellaneous = { "Junk", "Other" },
}
local TEST_QUALITY_W = { { 0, 7 }, { 1, 16 }, { 2, 28 }, { 3, 22 }, { 4, 11 }, { 5, 3 } }
local TEST_HOUR_W = {}   -- evening-leaning hour-of-day curve
do
  local w = { [0] = 2, [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 1, [6] = 2, [7] = 3,
              [8] = 4, [9] = 5, [10] = 6, [11] = 6, [12] = 7, [13] = 6, [14] = 5, [15] = 5,
              [16] = 6, [17] = 8, [18] = 11, [19] = 13, [20] = 14, [21] = 12, [22] = 9, [23] = 5 }
  for h = 0, 23 do TEST_HOUR_W[#TEST_HOUR_W + 1] = { h, w[h] } end
end
-- The first 8 are "hot" (recur often), the rest a long tail, so the ranked lists have real shape.
local TEST_ITEM_NAMES = {
  "Linen Cloth", "Serevite Ore", "Dragon Isles Herb", "Spectral Flask",
  "Refreshing Healing Potion", "Silk Cloth", "Awakened Fire", "Primal Chaos",
  "Thunderfury", "Hearthstone", "Writhebark", "Hochenblume",
  "Rousing Frost", "Mireslush Hide", "Resilient Leather", "Khaz'gorite Ore",
  "Vibrant Shard", "Illimited Diamond", "Alexstraszite", "Neltharite",
  "Convincingly Realistic Jumper Cables", "Zaralek Glowspore", "Bismuth", "Ironclaw Ore",
  "Weavercloth", "Gloom Chitin", "Storm Dust", "Null Stone",
  "Arathor's Spear", "Everburning Ember",
}
local TEST_DAY = 86400
local TEST_SPAN_DAYS = 21
local TEST_HOT_ITEMS = 8

-- Minimal-standard (Park-Miller) LCG: products stay below 2^46, so the double arithmetic is exact
-- and the sequence is identical on every platform. rng(n) returns an integer in [1, n].
local function testRng(seed)
  local state = seed % 2147483647
  if state <= 0 then state = state + 2147483646 end
  return function(n)
    state = (state * 16807) % 2147483647
    return (state % n) + 1
  end
end

-- Weighted pick from a { {value, weight}, ... } table.
local function testPick(rng, weighted)
  local total = 0
  for _, e in ipairs(weighted) do total = total + e[2] end
  local roll, acc = rng(total), 0
  for _, e in ipairs(weighted) do
    acc = acc + e[2]
    if roll <= acc then return e[1] end
  end
  return weighted[#weighted][1]
end

-- THE RNG CALL SEQUENCE IS THE CONTRACT for everything below: the dataset is asserted byte-identical
-- run to run, so every helper here consumes the stream at exactly the point the one body it was cut
-- out of did. A helper that draws must therefore stay at its old position in the statement order —
-- never hoisted above a neighbor that also draws, and never sequenced by argument-evaluation order.

-- "MAGE" -> "Mage-Ravencrest". Draws nothing.
local function testCharName(cls)
  return cls:sub(1, 1) .. cls:sub(2):lower() .. "-Ravencrest"
end

-- Only guild-bank rows carry a guild. Draws nothing.
local function testGuild(store)
  return (store == "GUILD_BANK") and "Ka0s" or nil
end

-- ~45% of movements land on a hot item, the rest on the long tail. Draws once or twice.
local function testItemID(rng)
  return (rng(100) <= 45) and rng(TEST_HOT_ITEMS)
         or (TEST_HOT_ITEMS + rng(#TEST_ITEM_NAMES - TEST_HOT_ITEMS))
end

-- Gear moves one at a time; junk moves in big stacks and good stuff in small ones. Draws at most
-- once, and only on the non-gear paths — which is exactly what the original expression did.
local function testQuantity(rng, isGear, quality)
  if isGear then return 1 end
  if quality <= 1 then return 1 + rng(60) end
  return 1 + rng(8)
end

-- Build one entry from the pivot values; everything else is derived and jittered.
-- Draw order: zone -> type -> item id -> second-of-day -> quantity.
local function makeTestEntry(out, rng, now, store, dir, quality, cls, dayOffset)
  local zone = TEST_ZONES[testPick(rng, TEST_ZONE_W)]
  local ty = testPick(rng, TEST_TYPE_W)
  local isGear = (ty == "Armor" or ty == "Weapon")
  local idBase = testItemID(rng)
  local subs = TEST_SUBTYPES[ty]
  local secInto = testPick(rng, TEST_HOUR_W) * 3600 + (rng(60) - 1) * 60 + (rng(60) - 1)
  local quantity = testQuantity(rng, isGear, quality)
  out[#out + 1] = {
    ts = now - dayOffset * TEST_DAY - secInto,
    char = testCharName(cls), classFile = cls,
    kind = C.Kind.ITEM, direction = dir, store = store,
    guild = testGuild(store),
    itemID = 190000 + idBase, itemName = TEST_ITEM_NAMES[idBase], quality = quality,
    itemType = ty, itemSubType = subs[(idBase % #subs) + 1],
    quantity = quantity,
    zone = zone.name, mapID = zone.mapID,
  }
end

-- 1) Coverage seed: every store, both directions, every quality 0-5 and every class appear at least
--    once, and the timestamps walk the full window. seedN is what guarantees all four invariants
--    regardless of how the dice fall.
local function seedCoverage(out, rng, now)
  local stores = { "BANK", "WARBAND_BANK", "GUILD_BANK" }
  local seedN = math.max(#stores, #TEST_CLASSES, 6, TEST_SPAN_DAYS)
  for i = 1, seedN do
    makeTestEntry(out, rng, now,
      stores[((i - 1) % #stores) + 1],
      (i % 2 == 0) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
      (i - 1) % 6,
      TEST_CLASSES[((i - 1) % #TEST_CLASSES) + 1],
      (i - 1) % TEST_SPAN_DAYS)
  end
end

-- 2) Weighted bulk: deposits outnumber withdrawals, as a real bank does, and a third of the
--    movements cluster onto the last few days.
local function bulkMovements(out, rng, now)
  for _ = 1, 220 do
    local dayOffset = rng(TEST_SPAN_DAYS) - 1
    if rng(3) == 1 then dayOffset = rng(5) - 1 end
    makeTestEntry(out, rng, now,
      testPick(rng, TEST_STORE_W),
      (rng(10) <= 6) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
      testPick(rng, TEST_QUALITY_W), testPick(rng, TEST_CLASS_W), dayOffset)
  end
end

-- 3) Gold movements, at the two stores that hold coin.
-- Draw order: class -> zone -> ts day -> ts seconds -> direction -> amount. The store comes from
-- the loop index, not the dice.
local function goldMovements(out, rng, now)
  for i = 1, 30 do
    local store = (i % 2 == 0) and "WARBAND_BANK" or "GUILD_BANK"
    local cls = testPick(rng, TEST_CLASS_W)
    local zone = TEST_ZONES[testPick(rng, TEST_ZONE_W)]
    out[#out + 1] = {
      ts = now - (rng(TEST_SPAN_DAYS) - 1) * TEST_DAY - rng(80000),
      char = testCharName(cls), classFile = cls,
      kind = C.Kind.MONEY,
      direction = (rng(10) <= 7) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
      store = store,
      guild = testGuild(store),
      itemName = "Gold", quantity = rng(500) * 10000,
      zone = zone.name, mapID = zone.mapID,
    }
  end
end

function LT:BuildTestData()
  local now = time()
  local rng = testRng(0x0BA17ED9)   -- fixed seed -> an identical dataset every run
  local out = {}
  seedCoverage(out, rng, now)
  bulkMovements(out, rng, now)
  goldMovements(out, rng, now)
  return out
end

-- Is the sample dataset on screen? DERIVED from the one stored fact rather than tracked beside it,
-- so a flag and a dataset can never disagree — and every write path can ask the same question the
-- read paths already answer through State.
function LT:IsTestMode()
  return NS.State.testRecords ~= nil
end

-- Toggle the test dataset (`/bl test`). Publishing it to State means every read-path query -- the
-- table AND Insights -- resolves against the same data, through the real render path (test-mode).
function LT:ToggleTestMode()
  NS.State.testRecords = (not self:IsTestMode()) and self:BuildTestData() or nil
  if NS.Browser and NS.Browser.Show then NS.Browser:Show() end
  if NS.Browser and NS.Browser.OnDatasetChanged then
    NS.Browser:OnDatasetChanged()
  else
    self:Refresh()
  end
  return self:IsTestMode()
end

-- ── Pooled rows ─────────────────────────────────────────────────────────────────

local function qualityColor(q)
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

-- The Item and Quality columns share ONE painter, because they are the same rule: a gold movement
-- has no quality, so in either column it takes the pale gold rather than a quality color.
local function paintQualityCell(fs, entry)
  if entry.kind == C.Kind.MONEY then
    fs:SetTextColor(MONEY_RGB[1], MONEY_RGB[2], MONEY_RGB[3])
  else
    fs:SetTextColor(qualityColor(entry.quality))
  end
end

-- The only painter that touches the row's glyph FontString, and it sets text, color AND shown-state:
-- rows are pooled, so a glyph left over from the entry that last used this row is the failure mode.
local function paintDirectionCell(fs, entry, glyphFS)
  local rgb = C.DirectionRGB[entry.direction] or C.NEUTRAL_RGB
  fs:SetTextColor(rgb[1], rgb[2], rgb[3])
  if glyphFS then
    local glyph = C.DirectionGlyph[entry.direction]
    glyphFS:SetText(glyph or "")
    glyphFS:SetTextColor(rgb[1], rgb[2], rgb[3])
    glyphFS:SetShown(glyph ~= nil)
  end
end

local function paintStoreCell(fs, entry)
  local rgb = C.StoreRGB[entry.store] or C.NEUTRAL_RGB
  fs:SetTextColor(rgb[1], rgb[2], rgb[3])
end

-- RAID_CLASS_COLORS stays guarded: it does not exist under the headless mock, and an unknown class
-- falls back to the same flat gray every other column uses.
local function paintCharCell(fs, entry)
  local cc = RAID_CLASS_COLORS and entry.classFile and RAID_CLASS_COLORS[entry.classFile]
  if cc then fs:SetTextColor(cc.r, cc.g, cc.b) else fs:SetTextColor(0.9, 0.9, 0.9) end
end

-- Column key → the painter that colors it. MODULE-LEVEL, built once at file load: PaintCell runs
-- once per visible cell per repaint (roughly 7 columns x ~30 rows, on every scroll tick and every
-- filter change), so this must allocate nothing per call.
local CELL_PAINT = {
  item = paintQualityCell, quality = paintQualityCell, direction = paintDirectionCell,
  store = paintStoreCell, char = paintCharCell,
}

-- Paint ONE cell: set its text from the column's valueFn and its color from the shared palette.
--
-- The single definition of "what color is this cell", so the History table and the session window's
-- slim table can never disagree. `glyphFS` is the row's direction glyph FontString; pass it only for
-- the "direction" column (any other column ignores it).
function LT:PaintCell(fs, colKey, entry, glyphFS)
  local col = COLUMN_BY_KEY[colKey]
  if not (fs and col and entry) then return end
  fs:SetText(col.valueFn(entry))
  local paint = CELL_PAINT[colKey]
  -- Every column without a painter of its own gets the flat gray.
  if paint then paint(fs, entry, glyphFS) else fs:SetTextColor(0.9, 0.9, 0.9) end
end

function LT:AcquireRow()
  local pool = self.rowPool
  local row = table.remove(pool.free)
  if row then
    row:Show()
    return row
  end

  row = CreateFrame("Button", nil, self.rowHost)
  row:SetHeight(ROW_H)
  row:SetPoint("LEFT", self.rowHost, "LEFT", 0, 0)
  row:SetPoint("RIGHT", self.rowHost, "RIGHT", 0, 0)

  local stripe = row:CreateTexture(nil, "BACKGROUND")
  stripe:SetAllPoints()
  stripe:SetColorTexture(1, 1, 1, 0.03)
  row.stripe = stripe

  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0, 0.10)

  -- One FontString per data column, laid out left→right with the Item column flexing.
  row.cells = {}
  for _, col in ipairs(self.COLUMNS) do
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH(col.align)
    fs:SetHeight(ROW_H)
    fs:SetWordWrap(false)
    row.cells[col.key] = fs
  end

  -- The direction glyph, drawn to the left of the Direction text and colored with it.
  local glyph = row:CreateFontString(nil, "OVERLAY")
  glyph:SetFont(C.FONT_MONO, ARROW_SIZE, "")
  glyph:SetJustifyH("CENTER")
  glyph:SetWidth(ARROW_SIZE)
  glyph:SetHeight(ROW_H)
  glyph:Hide()
  row.dirGlyph = glyph

  -- Group-header styling; hidden for data rows.
  local header = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  header:SetPoint("LEFT", 4, 0)
  header:SetTextColor(HEADER_RGB[1], HEADER_RGB[2], HEADER_RGB[3])
  header:Hide()
  row.header = header

  row:SetScript("OnEnter", function(self2)
    local item = self2.item
    if not (item and item.kind == "row") then return end
    local e = item.entry
    if not GameTooltip then return end
    if e.itemLink then
      GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(e.itemLink)
      GameTooltip:AddLine("Shift-click to link \194\183 right-click for options", 0.5, 0.5, 0.5)
      GameTooltip:Show()
    elseif e.kind == C.Kind.MONEY then
      -- A gold movement has no item to hover, so build the tooltip by hand rather than leave the
      -- row silent: the amount is the one thing the Qty cell can truncate.
      GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
      GameTooltip:AddLine(C.KindLabel.MONEY, MONEY_RGB[1], MONEY_RGB[2], MONEY_RGB[3])
      GameTooltip:AddDoubleLine("Amount", NS.Util.FormatMoney(e.quantity), 0.9, 0.9, 0.9, 1, 1, 1)
      GameTooltip:AddLine("Right-click for options", 0.5, 0.5, 0.5)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  -- A header left-click toggles collapse. Data rows: shift-left-click links the item to chat;
  -- right-click opens the row action menu.
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:SetScript("OnClick", function(self2, button)
    local item = self2.item
    if not item then return end
    if item.kind == "header" then
      if button == "LeftButton" then LT:ToggleCollapse(item.key) end
      return
    end
    local link = item.entry.itemLink
    if button == "LeftButton" then
      if IsShiftKeyDown() and link and ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
      end
    elseif button == "RightButton" then
      LT:ShowRowMenu(self2, item.entry)
    end
  end)

  self:LayoutRowCells(row)
  return row
end

-- Width available for columns (the row host's viewport), with a fallback before first layout.
function LT:ContentWidth()
  local w = self.rowHost and self.rowHost:GetWidth()
  if not w or w <= 0 then return 900 end
  return w
end

-- The minimum window width that shows every column without truncation: fixed column widths + gaps
-- + the Item column's minimum + the scrollbar gutter + the pane margins. The Browser uses this as
-- both the default and the minimum window width, so columns can never overflow.
function LT:MinFrameWidth()
  local w = 0
  for _, col in ipairs(self.COLUMNS) do
    w = w + (col.flex and ITEM_MIN or col.width) + COL_GAP
  end
  return math.ceil(w + 24 + 12)
end

-- Position each cell by cumulative column widths; the flex column takes the slack.
function LT:LayoutRowCells(row)
  local total = self:ContentWidth()
  local fixed = 0
  for _, col in ipairs(self.COLUMNS) do
    if not col.flex then fixed = fixed + col.width + COL_GAP end
  end
  local flexW = math.max(ITEM_MIN, total - fixed)

  local x = 0
  for _, col in ipairs(self.COLUMNS) do
    local w = col.flex and flexW or col.width
    local fs = row.cells[col.key]
    fs:ClearAllPoints()
    -- The Direction cell gives its first ARROW_SIZE+ARROW_GAP pixels to the direction glyph.
    if col.key == "direction" and row.dirGlyph then
      row.dirGlyph:ClearAllPoints()
      row.dirGlyph:SetPoint("LEFT", row, "LEFT", x, 0)
      fs:SetPoint("LEFT", row, "LEFT", x + ARROW_SIZE + ARROW_GAP, 0)
      fs:SetWidth(math.max(1, w - ARROW_SIZE - ARROW_GAP))
    else
      fs:SetPoint("LEFT", row, "LEFT", x, 0)
      fs:SetWidth(w)
    end
    x = x + w + COL_GAP
  end
end

function LT:ReleaseAllRows()
  local pool = self.rowPool
  for _, row in ipairs(pool.active) do
    row:Hide()
    pool.free[#pool.free + 1] = row
  end
  for i = #pool.active, 1, -1 do pool.active[i] = nil end
end

-- ── Attach + render ─────────────────────────────────────────────────────────────

function LT:Attach(pane)
  if self.frame then return end
  self.pane = pane

  -- Header row (its right inset matches the row host, so header columns line up with data cells).
  local header = CreateFrame("Frame", nil, pane)
  header:SetPoint("TOPLEFT", 0, 0)
  header:SetPoint("TOPRIGHT", -24, 0)
  header:SetHeight(HEADER_H)
  self.headerFrame = header

  -- A FauxScrollFrame drives the scrollbar + offset. Pooled rows live in a sibling overlay
  -- (rowHost) aligned with the scroll viewport, so the ScrollFrame never clips them.
  local scroll = CreateFrame("ScrollFrame", nil, pane, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  -- The bottom is raised 16px so the scrollbar's down-arrow clears the window resize grip.
  scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -24, 16)
  scroll:SetScript("OnVerticalScroll", function(self2, offset)
    FauxScrollFrame_OnVerticalScroll(self2, offset, ROW_H, function() LT:Bind() end)
  end)
  scroll:SetScript("OnSizeChanged", function() LT:Bind() end)
  self.scroll = scroll

  local host = CreateFrame("Frame", nil, pane)
  host:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  host:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
  self.rowHost = host

  self.rowPool = { active = {}, free = {} }

  local empty = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
  empty:SetPoint("CENTER", scroll, "CENTER", 0, 0)
  empty:Hide()
  self.emptyText = empty

  self:BuildHeaderCells()
  self.frame = pane
  self:Refresh()
end

function LT:MakeHeaderButton(col)
  local btn = CreateFrame("Button", nil, self.headerFrame)
  btn:SetHeight(HEADER_H)
  local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("LEFT", 0, 0)
  fs:SetJustifyH(col.align)
  fs:SetText(col.label)
  fs:SetTextColor(HEADER_RGB[1], HEADER_RGB[2], HEADER_RGB[3])
  btn.fs = fs
  btn:SetScript("OnEnter", function(self2)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self2, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(col.label, 1, 0.82, 0)
    if col.desc then GameTooltip:AddLine(col.desc, 0.9, 0.9, 0.9, true) end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  btn:SetScript("OnClick", function() LT:SetSort(col.key) end)
  return btn
end

-- Repaint the sort arrow: the grouped column shows the group-order arrow, the row-sort column the
-- sort arrow, everything else its bare label.
function LT:UpdateHeaderArrows()
  local header = self.headerFrame
  if not header or not header.buttons then return end
  local groupedCol = self.groupBy ~= "none" and GROUP_COLUMN[self.groupBy] or nil
  for key, btn in pairs(header.buttons) do
    if btn.fs then
      local col = COLUMN_BY_KEY[key]
      local label = col and col.label or ""
      if key == groupedCol then
        label = label .. (self.groupAsc and ARROW_ASC or ARROW_DESC)
      elseif key == self.sortKey then
        label = label .. (self.sortAsc and ARROW_ASC or ARROW_DESC)
      end
      btn.fs:SetText(label)
    end
  end
end

function LT:BuildHeaderCells()
  local header = self.headerFrame
  header.buttons = header.buttons or {}
  local total = self:ContentWidth()
  local fixed = 0
  for _, col in ipairs(self.COLUMNS) do
    if not col.flex then fixed = fixed + col.width + COL_GAP end
  end
  local flexW = math.max(ITEM_MIN, total - fixed)

  local x = 0
  for _, col in ipairs(self.COLUMNS) do
    local w = col.flex and flexW or col.width
    local btn = header.buttons[col.key]
    if not btn then
      btn = self:MakeHeaderButton(col)
      header.buttons[col.key] = btn
    end
    btn:ClearAllPoints()
    btn:SetPoint("LEFT", header, "LEFT", x, 0)
    btn:SetWidth(w)
    if btn.fs then btn.fs:SetWidth(w) end
    x = x + w + COL_GAP
  end
  self:UpdateHeaderArrows()
end

-- Pure one-line render summary for the [Table] trace: one line per render pass, never one per row
-- (debug-logging-§9). filterCount is the number of active filter keys.
function LT.RenderSummary(matchCount, total, filterCount, groupBy, sortKey, sortAsc)
  return ("rendered %s/%s rows (group=%s, sort=%s %s, filters=%s)"):format(
    tostring(matchCount), tostring(total), tostring(groupBy or "none"),
    tostring(sortKey), sortAsc and "asc" or "desc", tostring(filterCount or 0))
end

-- Recompute the display list and repaint. A safe no-op before Attach.
function LT:Refresh()
  if not self.frame then return end
  self.displayList = self:BuildDisplayList()
  self:Bind()
  if NS.State.debug and NS.Debug then
    local total = #(NS.Database:ActiveLedger() or {})
    local fc = 0
    for _ in pairs(self.filter or {}) do fc = fc + 1 end
    NS.Debug("Table", "%s", LT.RenderSummary(
      self.matchCount or 0, total, fc, self.groupBy, self.sortKey, self.sortAsc))
  end
end

-- Bind the visible slice of the display list onto pooled rows.
function LT:Bind()
  if not self.frame then return end
  self:BuildHeaderCells()   -- keep header columns aligned with rows across resizes
  local list = self.displayList or {}
  local scroll = self.scroll
  local viewH = scroll:GetHeight()
  if type(viewH) ~= "number" or viewH <= 0 then viewH = ROW_H * 20 end
  local numVisible = math.max(1, math.floor(viewH / ROW_H))

  FauxScrollFrame_Update(scroll, #list, numVisible, ROW_H)
  local offset = FauxScrollFrame_GetOffset(scroll) or 0

  self:ReleaseAllRows()
  self.emptyText:SetShown(#list == 0)
  if #list == 0 then
    self.emptyText:SetText(next(self.filter or {}) and "No movements match your filters."
      or "No bank movements recorded yet. Open your bank and move something.")
    return
  end

  local pool = self.rowPool
  for i = 1, numVisible do
    local item = list[offset + i]
    if item then
      local row = self:AcquireRow()
      row:SetPoint("TOP", self.rowHost, "TOP", 0, -(i - 1) * ROW_H)
      self:LayoutRowCells(row)
      self:BindRow(row, item, offset + i)
      pool.active[#pool.active + 1] = row
    end
  end
end

function LT:BindRow(row, item, absIndex)
  row.item = item
  row.stripe:SetShown(absIndex % 2 == 0)

  if item.kind == "header" then
    for _, col in ipairs(self.COLUMNS) do row.cells[col.key]:SetText("") end
    row.dirGlyph:Hide()
    row.header:Show()
    -- The expander marks collapsed/expanded, and both spellings were resolved once at load (see
    -- GROUP_SHUT / GROUP_OPEN at the top of this file) — a chevron on a working install, Blizzard's
    -- own +/- box on one without the shared art.
    local arrow = item.collapsed and GROUP_SHUT or GROUP_OPEN
    row.header:SetText(arrow .. "  " .. (item.label or "")
      .. "  |cff808080(" .. (item.count or 0) .. ")|r")
    return
  end

  row.header:Hide()
  local e = item.entry
  for _, col in ipairs(self.COLUMNS) do
    self:PaintCell(row.cells[col.key], col.key,
      e, col.key == "direction" and row.dirGlyph or nil)
  end
end

-- ── Row context menu (right-click) ──────────────────────────────────────────────
local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"
local rowMenu
local function EnsureRowMenu()
  if rowMenu then return rowMenu end
  rowMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  rowMenu:SetFrameStrata("FULLSCREEN_DIALOG")
  rowMenu:SetBackdrop({ bgFile = WHITE8X8, edgeFile = WHITE8X8, edgeSize = 1 })
  rowMenu:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
  rowMenu:SetBackdropBorderColor(0.62, 0.5, 0.18, 1)
  rowMenu:Hide()
  rowMenu.buttons = {}

  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN")
  catcher:Hide()
  catcher:SetScript("OnClick", function() rowMenu:Hide() end)
  catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  rowMenu.catcher = catcher
  rowMenu:SetScript("OnHide", function() catcher:Hide() end)
  return rowMenu
end

-- The row menu's entries, as plain data — no frames, so the enable rules are unit-testable.
--
-- Every entry that WRITES is disabled while the sample dataset is on screen. The sample rows carry
-- synthetic item ids (190001+) that exist nowhere but State, so blacklisting one used to put a fake
-- id into the real, persisted capture filter, and Delete matched nothing in storage while still
-- broadcasting LedgerChanged — the row visibly stayed (F-002). "Link to chat" mutates nothing and
-- stays available; refusing here is right, rather than teaching Database which dataset is live.
function LT:RowMenuItems(entry)
  local live = not self:IsTestMode()
  return {
    { label = "Link to chat", enabled = entry.itemLink ~= nil, fn = function()
        if entry.itemLink and ChatEdit_InsertLink then ChatEdit_InsertLink(entry.itemLink) end
      end },
    -- Blacklisting is point-in-time: it stops FUTURE movements of this id being recorded and leaves
    -- every stored row alone. Manage the list in Settings ▸ Filters.
    { label = "Blacklist item", enabled = live and entry.itemID ~= nil, fn = function()
        if NS.Filters:AddBlacklist(entry.itemID) then
          print(("blacklisted %s. Manage in Settings \226\150\184 Filters."):format(
            entry.itemName or ("item " .. tostring(entry.itemID))))
        end
      end },
    { label = "Whitelist item", enabled = live and entry.itemID ~= nil, fn = function()
        if NS.Filters:AddWhitelist(entry.itemID) then
          print(("whitelisted %s. Manage in Settings \226\150\184 Filters."):format(
            entry.itemName or ("item " .. tostring(entry.itemID))))
        end
      end },
    { label = "|cffff5555Delete|r", enabled = live, fn = function()
        NS.Database:Delete(function(r) return r == entry end)   -- fires LedgerChanged
        LT:Refresh()
      end },
  }
end

function LT:ShowRowMenu(anchor, entry)
  local m = EnsureRowMenu()
  local MENU_ROW_H, W = 18, 160
  local items = self:RowMenuItems(entry)

  for _, b in ipairs(m.buttons) do b:Hide() end
  for i, item in ipairs(items) do
    local b = m.buttons[i]
    if not b then
      b = CreateFrame("Button", nil, m)
      b:SetHeight(MENU_ROW_H)
      local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("LEFT", 8, 0)
      fs:SetJustifyH("LEFT")
      b.fs = fs
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 0.82, 0, 0.15)
      m.buttons[i] = b
    end
    b:SetWidth(W)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 0, -4 - (i - 1) * MENU_ROW_H)
    b.fs:SetText(item.label)
    if item.enabled then
      b.fs:SetTextColor(0.9, 0.9, 0.9)
      b:EnableMouse(true)
      b:SetScript("OnClick", function() m:Hide(); item.fn() end)
    else
      b.fs:SetTextColor(0.5, 0.5, 0.5)
      b:EnableMouse(false)
      b:SetScript("OnClick", nil)
    end
    b:Show()
  end

  m:SetSize(W, #items * MENU_ROW_H + 8)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, 0)
  m.catcher:Show()
  m:Show()
end
