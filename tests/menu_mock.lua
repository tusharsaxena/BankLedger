-- tests/menu_mock.lua — a headless stand-in for the client's context-menu API (11.0+).
--
-- MODELED ON LibKa0s's own tests/mock_menu.lua (v1.58.0), which is repo-local to the library and
-- deliberately not in the kit: the Launcher's version-4 doc tells a host suite that pins its menu
-- entries to install its own fake `MenuUtil`, shaped like that file, and to drive the menu through
-- `NS.Launcher:Object().OnClick(frame, "RightButton")`. That is what this is. It is a support file,
-- not a suite (tests/run.lua's SUITES lists `test_*` basenames only), so the harness never runs it on
-- its own; tests/test_launcher.lua and tests/test_disabled.lua `dofile` it.
--
-- LibKa0s-Launcher-1.0 minor 4 (launcher-§2) opens `MenuUtil.CreateContextMenu(owner, generator)`.
-- The generator is handed a root description and builds on it: `root:CreateTitle(text)` and
-- `root:CreateCheckbox(text, isSelected, setSelected, data)`, the second answering an element whose
-- `SetEnabled(false)` grays the entry. Clicking an enabled checkbox calls `setSelected(data)`.
--
-- FIDELITY, the two things a convenient fake would get wrong and the library's mock gets right:
--   * a grayed element is never clicked. `Click` refuses it as the client does; `ForceClick` reaches
--     the library's own gate behind the gray, and a case that uses it says so;
--   * the generator runs once per open, so a state cached across opens reads stale here too.
--
-- NOT installed on construction, unlike the library's copy: this suite shares one mock environment
-- with thirty-odd others, and a MenuUtil left in it would turn every later right click into a menu.
-- A case calls `install()` and `remove()` around itself; with it removed the right click takes the
-- library's degraded path and opens the settings panel, which is itself a checkable fact.

return function(mocks)
  local M = { menus = {}, opens = 0 }

  local RESPONSE = { Close = 1, Refresh = 2, Open = 3 }

  local function newRoot(owner)
    local menu = { owner = owner, titles = {}, entries = {} }
    local root = {}
    function root.CreateTitle(_, text)
      menu.titles[#menu.titles + 1] = text
      return {}
    end
    function root.CreateCheckbox(_, text, isSelected, setSelected, data)
      local entry = { text = text, isSelected = isSelected, setSelected = setSelected,
        data = data, enabled = true }
      local element = {}
      function element.SetEnabled(_, on) entry.enabled = on and true or false end
      function element.IsEnabled() return entry.enabled end
      menu.entries[#menu.entries + 1] = entry
      return element
    end

    --- The entries' texts, in order.
    function menu:Texts()
      local out = {}
      for i, e in ipairs(self.entries) do out[i] = e.text end
      return out
    end
    --- The entry whose text starts with `prefix`, or nil.
    function menu:Find(prefix)
      for _, e in ipairs(self.entries) do
        if e.text:sub(1, #prefix) == prefix then return e end
      end
    end
    --- Whether an entry draws checked, as the client asks it.
    function menu:Checked(prefix)
      local e = self:Find(prefix)
      return e and e.isSelected(e.data) and true or false
    end
    --- Click an entry as a player can: a grayed one does nothing and answers nil.
    function menu:Click(prefix)
      local e = assert(self:Find(prefix), "no menu entry " .. prefix)
      if not e.enabled then return nil end
      return e.setSelected(e.data)
    end
    --- Run an entry's handler regardless of its gray, to reach the library's own gate.
    function menu:ForceClick(prefix)
      local e = assert(self:Find(prefix), "no menu entry " .. prefix)
      return e.setSelected(e.data)
    end
    return root, menu
  end

  M.MenuUtil = {
    CreateContextMenu = function(owner, generator)
      if owner == nil then error("CreateContextMenu: an owner region is required", 2) end
      local root, menu = newRoot(owner)
      M.opens = M.opens + 1
      generator(owner, root)
      M.menus[#M.menus + 1] = menu
      M.last = menu
      return menu
    end,
  }

  function M.install()
    mocks.MenuUtil = M.MenuUtil
    mocks.MenuResponse = RESPONSE
  end
  function M.remove()
    mocks.MenuUtil = nil
    mocks.MenuResponse = nil
  end
  function M.reset()
    M.menus, M.opens, M.last = {}, 0, nil
  end

  M.RESPONSE = RESPONSE
  return M
end
