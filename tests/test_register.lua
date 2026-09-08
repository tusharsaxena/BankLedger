-- tests/test_register.lua — the deviation register's citations are checkable, so they are checked.
--
-- `documentation-§3` gives a ratified deviation exactly one home, `docs/ARCHITECTURE.md`'s
-- `## Documented deviations`, and `audit-review-history` says what a row owes: a rule citation that
-- resolves against the current standard, a re-check trigger a reader can evaluate, and an evidence
-- id that resolves. The first is a human's to read and the second is prose. The third is not, and
-- this suite is the third.

local T = _G.BL_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function readFile(path)
  local f = io.open(path, "r")
  assertTrue(f ~= nil, "cannot open " .. path .. " (tests run from the repo root)")
  local body = f:read("*a")
  f:close()
  return body
end

--- Shell glob -> list of paths. `ls` is enough: the suite already runs from a POSIX shell.
local function glob(pattern)
  local out, p = {}, io.popen("ls -1 " .. pattern .. " 2>/dev/null")
  if not p then return out end
  for line in p:lines() do
    if line ~= "" then out[#out + 1] = line end
  end
  p:close()
  return out
end

-- ── The deviation register's own citations resolve ─────────────────────────────

-- `audit-review-history`'s third MUST: an id a register row cites in **Why** has to resolve -- a
-- deviation id into `docs/audits/`, a finding id into `docs/reviews/`, an issue number onto this
-- repo. An id that resolves to nothing is worse than no citation at all, because it reads as
-- evidence and leads to none, and it survives every re-read by a maintainer who knows the shape of
-- an id and never goes looking for what it names.
--
-- The check is deliberately NOT "the string appears somewhere under `docs/audits/`". A bundle that
-- REPORTS a dead citation quotes the dead id while doing so, so a substring search goes green on
-- the very defect it was written for -- `testing-§12`'s failure mode, sitting inside the gate for
-- it. What counts is the id being ASSIGNED: standing at the head of a markdown table cell, a
-- heading or a bullet, which is where every bundle in this repo puts a row's own id, and where
-- prose that merely mentions one never puts it.
--
-- Scope is the **deviation** id -- this repo's own audit-bundle prefix, which is what
-- `documentation-§3` puts in a row's Why cell and what a bundle under `docs/audits/` assigns.

local DEVIATION_ID = { "%f[%w]BL%-[%u%-]*%d+", "%f[%w]BANKLEDGER%-[%u%-]*%d+" }

--- Every `.md` under a dated bundle directory.
local function bundleFiles()
  return glob("docs/audits/*/*.md")
end

--- Does `id` head a table cell, a heading or a bullet anywhere in `files`?
local function isAssigned(id, files)
  local function heads(s)
    return s:sub(1, #id) == id and not s:sub(#id + 1, #id + 1):match("[%w%-]")
  end
  for _, path in ipairs(files) do
    for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
      local trimmed = line:gsub("^%s+", "")
      local lead = trimmed:match("^#+%s*(.*)$") or trimmed:match("^[%-%*]%s+(.*)$")
      if lead and heads((lead:gsub("^[%s%*`%[]+", ""))) then return true end
      if trimmed:sub(1, 1) == "|" then
        for field in (trimmed .. "|"):gmatch("([^|]*)|") do
          if heads((field:gsub("^[%s%*`%[]+", ""))) then return true end
        end
      end
    end
  end
  return false
end

test("every deviation id the register cites is assigned by a bundle in docs/audits/", function()
  -- The sentinel is what lets the register be the file's LAST `##` section without the slice
  -- silently coming back nil and the case passing on an empty string.
  local body = readFile("docs/ARCHITECTURE.md") .. "\n## \n"
  local section = body:match("\n## Documented deviations\r?\n(.-)\r?\n## ")
  assertTrue(section ~= nil,
    "docs/ARCHITECTURE.md has no `## Documented deviations` section to read")

  local files = bundleFiles()
  assertTrue(#files > 0, "no bundle files under docs/audits/ -- nothing to resolve against")

  local seen, cited, offenders = {}, 0, {}
  for _, pattern in ipairs(DEVIATION_ID) do
    for pos, id in section:gmatch("()(" .. pattern .. ")") do
      -- A hyphen in front means this is the tail of a longer id (a work-item `M1-LK-11`), not a
      -- citation of a bundle row.
      if section:sub(pos - 1, pos - 1) ~= "-" and not id:find("%-R%-") and not seen[id] then
        seen[id] = true
        cited = cited + 1
        if not isAssigned(id, files) then offenders[#offenders + 1] = id end
      end
    end
  end

  assertTrue(cited > 0,
    "the register cites no deviation id at all -- either the rows changed or DEVIATION_ID did")
  assertEqual(#offenders, 0,
    "cited by a register row and assigned by no bundle under docs/audits/: "
      .. table.concat(offenders, ", "))
end)
