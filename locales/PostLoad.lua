local addonName, NS = ...   -- luacheck: ignore addonName NS

-- Derived-key aliases (localization-§1): strings whose translation is always the same as another
-- key's, so a translator never duplicates work. Runs after every locale file, so it reads whatever
-- the active locale resolved.
--
-- Empty in v1.0.0 — no string routes through NS.L yet (see locales/enUS.lua). The file ships as the
-- seam a later localization pass fills, e.g.:
-- NS.L["Withdraw"] = NS.L["Withdrawal"]
