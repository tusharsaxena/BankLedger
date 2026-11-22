local T = _G.BL_TEST
local test, assertTrue = T.test, T.assertTrue

-- tests/test_docs.lua -- the structural claims this repo makes about its own smoke document.
--
-- WHAT IT PROVES, AND WHAT IT DOES NOT. That docs/smoke-tests.md still carries a section addressed
-- to a non-English client, that the section names the locale to run it on, and that it says what a
-- failure looks like rather than only what a pass does. It proves nothing whatever about that
-- section having been RUN -- a checklist is a checklist, and this repository has no client.
--
-- WHY IT IS WORTH A CASE. tests/wow_mock.lua answers enUS for every localized global it defines, so
-- a path that keys off a display string is green in this suite whether it is right or wrong: the
-- test and the bug agree with each other. This addon has three such paths and one of them --
-- entry.itemType / entry.itemSubType, which are localized display strings used as analytics keys
-- and persisted into SavedVariables -- is the collection\'s worked anti-pattern. The Non-English
-- client section (LOC-1 on) is the only place any of that is looked at, so the section going
-- missing would take the coverage with it.
--
-- The failure vocabulary is matched loosely on purpose: pinning one spelling would redden the tree
-- for a rewording.
local LOCALE_HEADING = "[Nn]on%-English client"
local FAILURE_WORDS = { "the finding", "Fail", "failure", "Failure" }

local function readFile(path)
  local fh = io.open(path, "r")
  assertTrue(fh ~= nil, "cannot open " .. path .. " (the suite runs from the repo root)")
  local text = fh:read("*a") or ""
  fh:close()
  return (text:gsub("\r\n", "\n"))
end

test("docs/smoke-tests.md carries a non-English-client section", function()
  local body = readFile("docs/smoke-tests.md")

  local capture, level, section = false, nil, {}
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    local hashes = line:match("^(#+)%s")
    if hashes and capture and #hashes <= level then break end
    if hashes and not capture and line:match(LOCALE_HEADING) then
      capture, level = true, #hashes
    end
    if capture then section[#section + 1] = line end
  end
  assertTrue(capture, "docs/smoke-tests.md has no heading naming a non-English client. The step is "
    .. "unconditional (M5-08): where an addon reads nothing localized the section still ships and "
    .. "says what it checked and why it came back empty")

  local text = table.concat(section, "\n")
  assertTrue(text:find("deDE", 1, true) or text:find("frFR", 1, true),
    "the non-English-client section names no client to run it on -- deDE and frFR are the two the "
    .. "collection\'s other locale steps use")

  local named = false
  for _, word in ipairs(FAILURE_WORDS) do
    if text:find(word, 1, true) then named = true break end
  end
  assertTrue(named, "the non-English-client section says what passing looks like and never what "
    .. "failing looks like. A step whose only outcome is \'it works\' is unfalsifiable in a client "
    .. "the operator booted specially")

  assertTrue(#section >= 10, "the non-English-client section is " .. #section .. " lines -- a "
    .. "heading with a sentence under it records the gap as coverage, which is the failure M5-08 "
    .. "was filed for")
end)

-- The WoW Forever section (WoW Forever port, BL-14; clients-§6). Bank Ledger ships on Retail and WoW
-- Forever, and what the headless suite cannot see on Forever (the real bank frame, the locked
-- warband bank, two-word names, the keyring) is looked at only in this section. The case pins its
-- shape: a numbered FOREVER theme the Index names with its true last number, each check tagged with
-- the client it runs on and carrying a Fail clause and a Result line, the absence checks for the
-- Retail-only Warband Bank (ruling R1), and the Retail regression checks for the R8 changes, which
-- alter Retail on purpose. Wording is matched on the few phrases the checks must name.
local FOREVER_NEEDLES = {
  "Banks to record",            -- the settings grid with no Warband Bank box (R1)
  "the guild bank",             -- the Record gold tooltip's Forever copy
  "Unknown scenario 'warband'", -- no warband scenario in /bl sim
  "/bl session",                -- the preview's rows off the warband bank
  "Keyring",                    -- R5
  "forever-probes.md",          -- the probes each check leans on
  "R8",                         -- the Retail regression checks
  "CanViewBank",                -- the warband-only banker (R8)
}

-- The `## WoW Forever` section of `body`, as text, or nil when there is none.
local function foreverSection(body)
  local capture, section = false, {}
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    if capture and line:match("^## ") then break end
    if not capture and line:match("^## WoW Forever%s*$") then capture = true end
    if capture then section[#section + 1] = line end
  end
  return capture and table.concat(section, "\n") or nil
end

-- The section's FOREVER checks in order, { id, body } each, asserting they are numbered 1..n.
local function foreverChecks(text)
  local starts, from = {}, 1
  while true do
    local s, e, id = text:find("\n%- %*%*FOREVER%-(%d+)%.", from)
    if not s then break end
    starts[#starts + 1] = { s = s, e = e, id = tonumber(id) }
    from = e + 1
  end
  local checks = {}
  for i, st in ipairs(starts) do
    assertTrue(st.id == i, "FOREVER checks are numbered 1.." .. #starts .. " in order; found FOREVER-"
      .. st.id .. " at position " .. i)
    local stop = starts[i + 1] and starts[i + 1].s - 1 or #text
    checks[i] = { id = st.id, body = text:sub(st.e + 1, stop) }
  end
  return checks
end

-- One check's client tag, asserting it has one and carries a Fail clause and a Result line.
local function foreverCheckClient(c)
  local client = c.body:match("Client:%s+(%a[%a%s]-)%.")
  client = client and client:gsub("%s+", " ")
  assertTrue(client == "WoW Forever" or client == "Retail" or client == "both",
    "FOREVER-" .. c.id .. " names no client (Client: WoW Forever., Client: Retail. or Client: both.)")
  assertTrue(c.body:find("Fail", 1, true) ~= nil, "FOREVER-" .. c.id .. " says no Fail")
  assertTrue(c.body:find("Result:", 1, true) ~= nil, "FOREVER-" .. c.id .. " has no Result line")
  return client
end

test("docs/smoke-tests.md carries a WoW Forever section with its absence and R8 checks", function()
  local body = readFile("docs/smoke-tests.md")
  local text = foreverSection(body)
  assertTrue(text ~= nil, "docs/smoke-tests.md has no `## WoW Forever` section")

  for _, needle in ipairs(FOREVER_NEEDLES) do
    assertTrue(text:find(needle, 1, true) ~= nil, "the WoW Forever section never says `" .. needle .. "`")
  end

  -- Every check: numbered in order, tagged with its client, falsifiable, and with a Result line.
  local checks = foreverChecks(text)
  local n = #checks
  assertTrue(n >= 10, "the WoW Forever section has " .. n .. " checks")
  local clients = {}
  for _, c in ipairs(checks) do clients[foreverCheckClient(c)] = true end
  assertTrue(clients["WoW Forever"] and clients.Retail and clients.both,
    "the section has checks for WoW Forever, for Retail (the R8 regressions) and for both")

  -- The Index row names the theme and its true last number.
  local last = body:match("| FOREVER%-1 – (%d+) |")
  assertTrue(last ~= nil, "the Index has no `FOREVER-1 – N` row")
  assertTrue(tonumber(last) == n, "the Index says FOREVER-1 – " .. tostring(last) .. " but there are " .. n)
end)
