-- tests/test_clients_shape.lua — the Retail · WoW Forever shape (WoW Forever port design, "Docs and
-- shape"; clients-§2, clients-§4, clients-§6, toc-file-§3, documentation-§1, forever-quirks-§1).
--
-- Bank Ledger ships on Retail and WoW Forever from one codebase, so the repo carries the dual-client
-- shape the standard fixes: one unsuffixed TOC with both Interface numbers and no load-gating line, a
-- README that says both clients on its badge and in its first sentence, a gate that names both kit
-- profiles, the vendored Forever quirks catalog in docs/forever-quirks.md, and a per-client feature
-- table in docs/ARCHITECTURE.md with one row per declared feature. Every case runs on both kit
-- profiles; the feature case asserts each declared feature present where declared and absent where
-- not, so a new declaration in C.FEATURE_CLIENTS with no expectation here is red.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local C = NS.Constants

local function read(path)
  local fh = io.open(path, "rb")
  assertTrue(fh ~= nil, "cannot open " .. path .. " (the suite runs from the repo root)")
  local text = fh:read("*a") or ""
  fh:close()
  return (text:gsub("\r\n", "\n"))
end

local function has(text, needle) return text:find(needle, 1, true) ~= nil end

local function tocField(key)
  for line in read("BankLedger.toc"):gmatch("[^\n]+") do
    local k, v = line:match("^## ([%w%-]+):%s*(.-)%s*$")
    if k == key then return v end
  end
end

-- ── the TOC ─────────────────────────────────────────────────────────────────────────────────

test("clients: the TOC carries the Retail and the WoW Forever number, and no load-gating line", function()
  -- red under: `## Interface: 120105` alone (the port-pending shape), or a gating line (Retail-only)
  assertEqual(tocField("Interface"), "120105, 16001")
  assertTrue(tocField("AllowLoadGameType") == nil, "no AllowLoadGameType on a Retail · Forever addon")
  assertTrue(tocField("ExcludeLoadGameType") == nil, "no ExcludeLoadGameType on a Retail · Forever addon")
end)

test("clients: the Forever number arms the kit's missing-globals scan for both clients", function()
  local CG = dofile("tests/_kit/client_globals.lua")
  -- red under: the Retail number alone (the scan checks live only)
  assertEqual(table.concat(CG.clientsFromToc(read("BankLedger.toc")), ","), "live,forever")
end)

-- ── the player-facing page ───────────────────────────────────────────────────────────────────

test("clients: the README's badge and first sentence name both clients", function()
  local readme = read("README.md")
  -- documentation-§1: both clients and both numbers on the badge, then one plain sentence opening
  -- the description. red under: the Midnight-only badge or the port-pending sentence
  assertTrue(has(readme, "![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.5_and_Forever_1.60.1-purple)"),
    "the dual-client badge")
  local body = readme:match("\n\n([^!#\n][^\n]*)")
  assertTrue(body ~= nil and body:find("^Supports Retail and WoW Forever%. ") ~= nil, tostring(body))
  assertTrue(not has(readme, "support is planned"), "no port-pending sentence left")
  -- the one feature WoW Forever lacks is named as Retail's in the player's words (clients-§4)
  assertTrue(has(readme, "warband bank (Retail only)"), "the README names the warband bank Retail only")
end)

-- ── the maintainer docs ──────────────────────────────────────────────────────────────────────

test("clients: CLAUDE.md, testing.md and DEPENDENCIES.md name both kit profiles in the gate", function()
  -- clients-§6: a suite green on one profile and red on the other is a failing suite, so the gate
  -- names both runs wherever it is written down. red under: the Retail run alone
  for _, path in ipairs({ "CLAUDE.md", "docs/testing.md", "DEPENDENCIES.md" }) do
    local text = read(path)
    assertTrue(has(text, "`lua tests/run.lua`") or has(text, "lua tests/run.lua "), path .. ": the Retail run")
    assertTrue(has(text, "KA0S_KIT_CLIENT=forever lua tests/run.lua"), path .. ": the WoW Forever run")
  end
end)

test("clients: docs/forever-quirks.md carries the vendored Forever catalog and the addon's own section", function()
  local text = read("docs/forever-quirks.md")
  -- forever-quirks-§1: the block opened and closed as /dev-copilot:wow-revendor-standards writes it,
  -- stamped with the same standard version as the Retail catalog beside it, then the own section.
  local version = text:match("<!%-%- BEGIN VENDORED: forever quirks catalog v([%d%.]+) %(source: WowAddonStandards%) %-%->")
  assertTrue(version ~= nil, "the BEGIN VENDORED marker")
  assertTrue(has(text, "<!-- END VENDORED -->"), "the END VENDORED marker")
  local retail = read("docs/midnight-quirks.md"):match("BEGIN VENDORED: quirks catalog v([%d%.]+)")
  assertEqual(version, retail, "the two catalogs come from one standard release")
  local own = text:find("\n## BankLedger-specific quirks\n", 1, true)
  assertTrue(own ~= nil and own > text:find("<!-- END VENDORED -->", 1, true), "the own section follows the block")
  -- the own section covers the bank model, the keyring, the sockets and the names (design "Docs")
  local tail = text:sub(own)
  for _, word in ipairs({ "CharacterBankTab_", "Keyring", "-2", "First Surname", "forever-probes.md" }) do
    assertTrue(has(tail, word), "the own section covers " .. word)
  end
end)

test("clients: ARCHITECTURE.md's doc map and at-a-glance row read Retail · Forever", function()
  local arch = read("docs/ARCHITECTURE.md")
  -- red under: the port-pending row ("Not applicable", "Retail (port pending)") left in the map
  assertTrue(arch:find("\n| `forever%-quirks%.md` | Present |") ~= nil, "forever-quirks.md is Present")
  assertTrue(not has(arch, "Retail (port pending)"), "no port-pending wording left")
  assertTrue(not has(arch, "Retail (Mainline) only"), "the at-a-glance row names both clients")
  assertTrue(has(arch, "`120105, 16001`"), "the at-a-glance row carries both numbers")
  assertTrue(not has(read("docs/scope.md"), "Retail (Mainline) only"), "scope.md names both clients")
end)

-- ── the declared features (clients-§4, clients-§6) ───────────────────────────────────────────

-- Each declared feature and the client it is present on. A feature declared in C.FEATURE_CLIENTS
-- without a row here, or a row with no declaration, is red: the table is how a new declaration
-- gets its present/absent expectation on each profile.
local EXPECT = {
  warbandBank = { retail = true, forever = false },
}

test("clients: every declared feature is present where declared and absent where not", function()
  local client = NS.Compat.ClientKey()
  assertTrue(client == "retail" or client == "forever", "a known kit profile: " .. tostring(client))
  for name, clients in pairs(C.FEATURE_CLIENTS) do
    local row = EXPECT[name]
    assertTrue(row ~= nil, "declared feature " .. name .. " has no expectation in this suite")
    assertEqual(C.FEATURE[name], row[client], name .. " on " .. client)
    assertEqual(C.FEATURE[name], NS.Compat.ForClient(clients), name .. " is its declaration's ForClient answer")
  end
  for name in pairs(EXPECT) do
    assertTrue(C.FEATURE_CLIENTS[name] ~= nil, "expectation " .. name .. " names no declared feature")
  end
end)

test("clients: ARCHITECTURE.md's per-client table has a row for every declared feature", function()
  local arch = read("docs/ARCHITECTURE.md")
  local from = arch:find("\n### Per-client features (clients-§4)\n", 1, true)
  assertTrue(from ~= nil, "the per-client feature section")
  local section = arch:sub(from, (arch:find("\n## ", from + 1, true) or #arch))
  assertTrue(has(section, "| Feature | Client | Gated in |"), "the table's header")
  for name, clients in pairs(C.FEATURE_CLIENTS) do
    -- a row names the declaration (`C.FEATURE_CLIENTS.<name>`) and each client token it serves
    local row = section:match("\n(|[^\n]*C%.FEATURE_CLIENTS%." .. name .. "[^\n]*)")
    assertTrue(row ~= nil, "no per-client row names C.FEATURE_CLIENTS." .. name)
    for _, token in ipairs(clients) do
      assertTrue(has(row, "| `" .. token .. "` |"), name .. "'s row names `" .. token .. "`")
    end
  end
end)
