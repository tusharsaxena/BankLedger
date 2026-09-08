local T = _G.BL_TEST
local test, fail = T.test, T.fail

-- tests/test_lintconfig.lua -- the "no blanket suppression" gate (lint.md, `M4-11`).
--
-- WHAT IT PROVES. That `luacheck .` reaching 0/0 in this repo is a statement about the code and not
-- about the configuration. Four things are checked, and all four are the same rule seen from a
-- different side:
--   1. `.luacheckrc` sets no top-level `ignore`.
--   2. It switches no warning class off wholesale, which is `ignore` spelled as a switch.
--   3. Every `ignore` it does set sits in a `files[...]` stanza that is narrow -- the key names one
--      `.lua` file, or the entry names the variable as well as the code (`212/self`).
--   4. No tracked `.lua` file carries a bare inline `-- luacheck: ignore` with no code after it,
--      which is the same blanket wearing a different hat.
--
-- WHY IT EXISTS, in this repo specifically. `.luacheckrc` carried
-- `ignore = { "212/self", "212/event" }` through the whole 2026-09-07 remediation. That one looked
-- narrow -- both entries were already in the `<code>/<variable>` form the rule steers towards --
-- and it is the reason this gate checks SCOPE rather than spelling. A top-level ignore reaches all
-- 60 files however precisely it is written, and `212/event` matched nothing whatever in this tree:
-- the addon carried a live suppression for a warning it did not have, so the first handler to drop
-- its event argument would have landed green under a 0/0 badge.
--
-- Removing the two lines reported 119 findings, all of them `212/self`, in 12 files. Eighteen more
-- suppressions were sitting inline -- `local addonName, NS = ...   -- luacheck: ignore addonName`
-- over a folder name the file never read -- and `M4c-06` fixed all eighteen at source rather than
-- re-parking them: seventeen now open `local _, NS = ...`, and locales/PostLoad.lua, which read
-- neither name, lost a header that was dead outright. The 119 that remain are one shape, and it is
-- forced rather than chosen: each module publishes `NS.X = NS.X or {}` and defines its surface as
-- `function X:Method()`, so every call site is a colon call and deleting the receiver would shift
-- every argument one place left at all ~900 of them.
--
-- The measurement that says the difference is real, and it was run rather than assumed: a method
-- with an unread `self` added to core/Util.lua and an unread `event` parameter added to
-- core/Compat.lua -- two files with no stanza -- both report under the config this gate guards, and
-- the same tree under the old blanket came back 0 warnings / 0 errors.
--
-- Removing the line is one afternoon's work. Keeping it removed is what this file is for.
--
-- WHY IT READS THE CONFIG AS LUA RATHER THAN AS TEXT. `.luacheckrc` is a Lua chunk, and a text scan
-- for `ignore` is defeated by any of the half-dozen ways Lua has of writing the same assignment.
-- Loading it under a sandboxed environment gives back the same table luacheck itself builds, so
-- what this gate reads is what luacheck obeys. The environment auto-creates a table on first index
-- because `files["tests/"] = { ... }` is written without declaring `files` first, which is how
-- luacheck's own config loader behaves.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. No `.luacheckrc`, an unreadable one, a chunk
-- that will not compile or will not run, no `io.popen`, no git -- every one of those is a failure,
-- not a skip. A gate that goes quiet when it is blind reports success, which is worse than not
-- existing. Same bargain tests/test_docs.lua and tests/_kit/test_eol.lua strike.

local CONFIG = ".luacheckrc"

-- The warning classes luacheck lets a config switch off in one word. Setting any of them `false` at
-- the top level silences a whole family across the whole repository -- `unused_args = false` alone
-- would have covered every 212 the blanket did -- which is why the list is here and not just
-- `ignore`.
local CLASS_SWITCHES = {
  "unused", "unused_args", "unused_secondaries", "self",
  "redefined", "global", "allow_defined", "allow_defined_top", "module",
}

-- ---------------------------------------------------------------------------
-- Reading the config the way luacheck reads it
-- ---------------------------------------------------------------------------

--- The parsed `.luacheckrc` as a table of the globals it assigns.
---
--- The sandbox environment auto-vivifies on read so `files["tests/"] = { ... }` works without a
--- preceding `files = {}`, and nothing is written back to `_G`: assignments land in the sandbox and
--- are what this gate then inspects.
local function loadConfig()
  local fh = io.open(CONFIG, "r")
  if not fh then
    fail("lint config gate: " .. CONFIG .. " could not be opened, so the suppression rule "
      .. "cannot be checked and this gate must not be reported as passing", 2)
  end
  local text = fh:read("*a")
  fh:close()
  if not text or text == "" then
    fail("lint config gate: " .. CONFIG .. " read as empty, which cannot be true here; this "
      .. "gate cannot run and must not be reported as passing", 2)
  end

  local env = {}
  setmetatable(env, {
    __index = function(t, key)
      local made = {}
      rawset(t, key, made)
      return made
    end,
  })

  local chunk, err = loadstring(text, "@" .. CONFIG)
  if not chunk then
    fail("lint config gate: " .. CONFIG .. " does not compile as Lua (" .. tostring(err)
      .. "), so luacheck is not reading what this gate reads", 2)
  end
  setfenv(chunk, env)
  local ok, runErr = pcall(chunk)
  if not ok then
    fail("lint config gate: " .. CONFIG .. " errored while loading (" .. tostring(runErr)
      .. "), so luacheck is not reading what this gate reads", 2)
  end
  return env
end

--- The `files[...]` stanzas, as an array of { key, options } sorted by key for a stable message.
local function fileStanzas(env)
  local out = {}
  local files = rawget(env, "files")
  if type(files) ~= "table" then return out end
  for key, options in pairs(files) do
    if type(key) == "string" and type(options) == "table" then
      out[#out + 1] = { key = key, options = options }
    end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

-- ---------------------------------------------------------------------------
-- The rule
-- ---------------------------------------------------------------------------

test("lintconfig: .luacheckrc sets no top-level ignore", function()
  local env = loadConfig()
  local ignore = rawget(env, "ignore")
  if ignore ~= nil then
    local shown = {}
    if type(ignore) == "table" then
      for _, entry in ipairs(ignore) do shown[#shown + 1] = tostring(entry) end
    else
      shown[1] = tostring(ignore)
    end
    fail(".luacheckrc sets a top-level `ignore` of { " .. table.concat(shown, ", ") .. " }. "
      .. "A blanket ignore silences the code in all 60 files, including the ones with no "
      .. "business producing it, so it reads as coverage and provides none (lint.md, `M4-11`). "
      .. "Naming the variable does not save it: this repo's blanket was already `212/self`, and "
      .. "its `212/event` matched nothing at all. Move each code into a `files[...]` stanza naming "
      .. "the file that earns it, narrow the entry to the variable (`212/self`), or put a "
      .. "`-- luacheck: ignore <code>` beside the single line that needs it", 2)
  end
end)

test("lintconfig: .luacheckrc switches no warning class off wholesale", function()
  local env = loadConfig()
  local off = {}
  for _, name in ipairs(CLASS_SWITCHES) do
    local value = rawget(env, name)
    -- `allow_defined*` and `module` widen by being true; the rest widen by being false.
    local widens = (name:find("^allow_defined") or name == "module") and value == true
      or (not name:find("^allow_defined") and name ~= "module") and value == false
    if widens then off[#off + 1] = name .. " = " .. tostring(value) end
  end
  if #off > 0 then
    fail(".luacheckrc turns a whole warning class off at the top level: "
      .. table.concat(off, ", ") .. ". That is a blanket ignore spelled as a switch, and "
      .. "lint.md refuses it for the same reason: it reaches every file in the repository "
      .. "and reports as coverage", 2)
  end
end)

test("lintconfig: every files[...] ignore is narrowed to a file or a name", function()
  local env = loadConfig()
  local wide = {}
  for _, stanza in ipairs(fileStanzas(env)) do
    local ignore = rawget(stanza.options, "ignore")
    if type(ignore) == "table" then
      -- A stanza key ending in `.lua` already names one file, which is as narrow as a stanza
      -- gets. Anything broader -- a directory prefix -- has to earn it per entry by naming the
      -- variable too, in luacheck's `<code>/<name>` form.
      local keyIsOneFile = stanza.key:find("%.lua$") ~= nil
      for _, entry in ipairs(ignore) do
        local text = tostring(entry)
        if not keyIsOneFile and not text:find("/") then
          wide[#wide + 1] = "files[\"" .. stanza.key .. "\"].ignore = " .. text
        end
      end
    end
  end
  if #wide > 0 then
    fail("luacheck suppressions that cover a whole directory with no name to narrow them: "
      .. table.concat(wide, ", ") .. ". Name the single file in the stanza key, or write the "
      .. "entry as `<code>/<variable>` so a different unused name in the same tree still "
      .. "reports", 2)
  end
end)

-- ---------------------------------------------------------------------------
-- The same rule, inline
-- ---------------------------------------------------------------------------

--- Split a NUL-delimited blob. `git ls-files -z` because a path may contain anything but NUL, and
--- the line-oriented form quotes such a path instead of printing it -- a quoted path would not
--- open, and this gate would then report a read failure that is really a parse failure.
local function splitNul(blob)
  local out, start = {}, 1
  while true do
    local i = blob:find("\0", start, true)
    if not i then break end
    if i > start then out[#out + 1] = blob:sub(start, i - 1) end
    start = i + 1
  end
  return out
end

-- Vendored trees are not ours to annotate, and this file quotes the forbidden directive in order to
-- forbid it.
local SKIPPED_PREFIXES = { "libs/", "tests/_kit/" }
local SKIPPED_FILES = { ["tests/test_lintconfig.lua"] = true }

--- Every `.lua` path git tracks, minus the vendored trees and this file.
local function trackedLua()
  if not io.popen then
    fail("lint config gate: io.popen is unavailable, so the tracked set cannot be read and "
      .. "this gate must not be reported as passing", 2)
  end
  local pipe = io.popen("git ls-files -z '*.lua'")
  if not pipe then
    fail("lint config gate: io.popen returned no handle for `git ls-files`, so this gate "
      .. "cannot run and must not be reported as passing", 2)
  end
  local blob = pipe:read("*a") or ""
  pipe:close()

  local paths = {}
  for _, path in ipairs(splitNul(blob)) do
    if not SKIPPED_FILES[path] then
      local skip = false
      for _, prefix in ipairs(SKIPPED_PREFIXES) do
        if path:sub(1, #prefix) == prefix then skip = true break end
      end
      if not skip then paths[#paths + 1] = path end
    end
  end
  if #paths == 0 then
    fail("lint config gate: `git ls-files` reported no Lua files, which cannot be true here -- "
      .. "either git is unavailable or this is not a repository; this gate cannot run, and "
      .. "must not be reported as passing", 2)
  end
  return paths
end

test("lintconfig: no source file carries a bare inline luacheck ignore", function()
  local bare = {}
  for _, path in ipairs(trackedLua()) do
    local fh = io.open(path, "r")
    if not fh then
      fail("lint config gate: git tracks " .. path .. " but it could not be opened, so the "
        .. "scan is incomplete and must not be reported as passing", 2)
    end
    local lineNo = 0
    for line in fh:lines() do
      lineNo = lineNo + 1
      -- `-- luacheck: ignore` with nothing after it silences every warning in scope. With a code
      -- after it -- `ignore 542` -- it is the narrowest suppression luacheck offers, and is the
      -- form this rule steers towards. This addon currently has NO inline directive of either
      -- kind: `M4c-06` took the last eighteen out by fixing what they were hiding.
      local tail = line:match("%-%-%s*luacheck:%s*ignore(.*)$")
      if tail and tail:match("^%s*$") then
        bare[#bare + 1] = path .. ":" .. lineNo
      end
    end
    fh:close()
  end
  if #bare > 0 then
    fail("bare `-- luacheck: ignore` directives, which silence every code in scope: "
      .. table.concat(bare, ", ") .. ". Name the code the line actually produces so the next "
      .. "warning in the same scope is still reported (lint.md)", 2)
  end
end)
