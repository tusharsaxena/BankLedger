-- tests/degraded_env.lua — builds a SECOND addon environment with LibKa0s absent.
--
-- LibKa0s is vendored, so it can go missing: a partial unzip, a user pruning libs/, a packager that
-- dropped the folder. Every setup file in the addon carries a degradation stub for that case, and
-- the only honest way to exercise those stubs is a real load without the library — a hand-stub after
-- the fact cannot reproduce a file that failed to finish loading.
--
-- Both builders lived as file-scope locals in tests/test_libka0s.lua until M4-09 moved the four
-- stub-surface parity cases out into tests/test_surface_parity.lua. Two suites now need the same
-- environment, and two copies of an environment builder is two environments that drift. It is NOT
-- part of the vendored kit under tests/_kit/ — that folder must stay byte-identical to
-- LibKa0s/testkit — and it is not a suite, so tests/run.lua does not list it and
-- tests/test_harness.lua's `ls tests/test_*.lua` sweep does not see it; callers dofile it the way
-- they dofile tests/wow_mock.lua.
--
-- Nothing here calls InitDB, Register or Enable, so the shared suite's SavedVariables globals and
-- its message-bus subscriptions are untouched.

local T = _G.BL_TEST
local Loader = T.Loader

local M = {}

--- The WHOLE addon, loaded from the shipped TOC with libs/LibKa0s/*.lua left out of the file list.
---
--- The list is the TOC's, in the TOC's order, and it is the whole list. Both halves matter. Whole,
--- because a degradation stub that is missing a member a page file calls AT FILE LOAD takes that
--- file's rows down with it, and a list that stopped early would stay green through exactly that.
--- The TOC's own order, because several of this addon's seams are ordered on purpose —
--- settings/Schema.lua before settings/OptionsSetup.lua, core/CoreSetup.lua before every file that
--- captures NS.Print — and a reordered list would let a hoisted lookup pass here and fail in the
--- client.
function M.loadDegraded()
  local m = T.makeMocks()
  local ns = {}
  Loader.loadAll(Loader.tocFiles("BankLedger.toc"), ns, m)
  return ns, m
end

--- A fresh, isolated environment containing the TOC's files up to and INCLUDING `stop`, with the
--- vendored library in front of them or not.
---
--- The partial list is what lets a case compare the two arms of ONE seam at the same load point,
--- before a later file has had a chance to repoint anything either arm published.
function M.loadUpTo(stop, withLibrary)
  local m = T.makeMocks()
  local ns = {}
  if withLibrary then Loader.loadAll(T.libka0sFiles, ns, m) end
  for _, path in ipairs(Loader.tocFiles("BankLedger.toc")) do
    Loader.load(path, ns, m)
    if path == stop then break end
  end
  return ns, m
end

return M
