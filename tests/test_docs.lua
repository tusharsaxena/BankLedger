local T = _G.BL_TEST
local test, assertTrue = T.test, T.assertTrue

-- tests/test_docs.lua -- the one structural claim this repo makes about its own smoke document.
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
-- and persisted into SavedVariables -- is the collection\'s worked anti-pattern. S-27 is the only
-- place any of that is looked at, so the section going missing would take the coverage with it.
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
