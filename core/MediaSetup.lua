local addonName, NS = ...

-- core/MediaSetup.lua — wires the addon into LibKa0s-Media-1.0 (library-stack).
--
-- The seam where this addon's monospace face, and any shared mark it draws, come from.
--
-- ── IT USED TO BE OURS, AND THAT WAS THE PROBLEM ─────────────────────────────────────────────
--
-- This addon shipped its own copy of JetBrains Mono under `media/fonts/`, beside its own OFL.txt,
-- and registered the face with LibSharedMedia itself from core/BankLedger.lua's OnInitialize. Both
-- are gone. The bytes now arrive inside the LibKa0s payload (v1.10.2, `LibKa0s-Media-1.0`) with the
-- library, because the second Ka0s addon to want a monospace column would otherwise have carried a
-- second copy — two licenses to track, two provenance stories, and two LibSharedMedia registrations
-- of the name "JetBrains Mono" against two different paths, which is precisely the collision the
-- library exists to end. The registration is the library's now, made once, below.
--
-- ── WHY THE LIBRARY HAS TO BE TOLD OUR NAME ──────────────────────────────────────────────────
--
-- A texture path is absolute from `Interface\AddOns\`, and LibKa0s is VENDORED: every consumer has
-- its own copy at its own path, and a copy cannot know which addon folder it was copied into. So
-- the library asks, and this file is where the answer lives — `addonName`, the FIRST VARARG every
-- TOC-loaded file gets. Not the frame-name prefix, not the `## Title`, not a hand-typed literal:
-- those three happen to read "BankLedger", "BankLedger" and "Ka0s Bank Ledger" here, and only the
-- first of them is the folder. A wrong folder builds a plausible path to a file that is not there,
-- which draws nothing and raises nothing.
--
-- ── WHY THIS LOADS BEFORE core/Constants.lua ─────────────────────────────────────────────────
--
-- `C.FONT_MONO` is RESOLVED from `NS.MediaFont` at load — it is no longer a string literal — and
-- core/DebugLogSetup.lua reads that constant at `lib:New` time. So the seam has to be published
-- first, and a Constants that loaded ahead of this file would resolve the console's font to the
-- client default forever. That makes this one of the few files in core/ whose TOC position is
-- load-bearing rather than conventional; BankLedger.toc says so on the line itself, and
-- tests/test_libka0s.lua pins it.
--
-- ── WHAT A DEGRADED INSTALL GETS ─────────────────────────────────────────────────────────────
--
-- No LibKa0s means no art and no face: they are inside the payload that is missing. `NS.Icon`
-- answers nil, which a caller treats as "walk down to the next rung of the art ladder", and
-- `NS.MediaFont` answers nil, which core/Constants.lua turns into the client's own
-- STANDARD_TEXT_FONT. Neither is an error. The History and session rows lose the ▲/▼ direction
-- glyphs to a box — the client default has neither — and every number stays on screen, which is the
-- trade a degraded install is owed.

local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)

--- The texture path for one shipped icon, or nil.
---
--- EXTENSIONLESS, and that is the library's contract rather than a preference: the client appends
--- the extension itself, and a path carrying `.tga` is a recorded spelling that draws NOTHING and
--- raises NOTHING.
---
--- NIL IS A REAL ANSWER, twice over: the library may be absent, and the name may not be one the
--- library ships. Both mean the same thing to a caller — draw something else — and both are far
--- better than the alternative, which is a plausible path to a texture that never loads. NEVER
--- route around a nil by building a path with `..`.
---
--- @param name string  an entry of the library's `ICONS` catalog, e.g. "close"
--- @return string|nil
function NS.Icon(name)
  if not Media then return nil end
  return Media.Icon(addonName, name)
end

--- The path of one shipped font face, or nil when the library is absent or the face is not one it
--- carries. Unlike an icon path this one KEEPS its extension: SetFont wants the real file.
---
--- @param name string  a key of the library's `FONTS`, e.g. "JetBrains Mono"
--- @return string|nil
function NS.MediaFont(name)
  if not Media then return nil end
  return Media.Font(addonName, name)
end

--- Every mark this addon asks for, by name.
---
--- NOT a lookup table and not read at runtime: nothing draws from this list. It exists so that the
--- catalog cross-check in tests/test_mediasetup.lua can enumerate what this addon SPELLS against
--- what the library SHIPS, out of game, in another repo's absence. A name is a plain string here
--- and a filename over there; a rename on either side answers nil, and a nil answer is a control
--- that quietly falls back to Blizzard art or to nothing while every suite stays green.
---
--- Add a name here the moment a surface starts drawing it. A name in the source and not in this
--- list is exactly the drift the list exists to catch.
---
---   close          modules/Browser.lua  B:MakeCloseButton — all four title bars
---   chevron-down   modules/Browser.lua  MakeDropdown's ▼, and the expanded group header
---   confirm        modules/Browser.lua  the tick on a chosen row of a multi-select menu
---   chevron-right  modules/LedgerTable.lua  the collapsed group header
---   sort-up        modules/LedgerTable.lua  the ascending column-header arrow
---   sort-down      modules/LedgerTable.lua  the descending column-header arrow
---   export         modules/Export.lua   the modal's "Export to CSV" button
---   search         modules/Browser.lua  the item-name search box
NS.ICON_NAMES = {
  "close", "chevron-down", "chevron-right", "sort-up", "sort-down", "export", "search", "confirm",
}

-- REGISTERED AT FILE LOAD, not at PLAYER_LOGIN, and not from core/BankLedger.lua's OnInitialize the
-- way this addon's own registration used to be. LibSharedMedia is vendored under libs/ and has
-- therefore already run by the time the TOC reaches core/, while defaults/ and the settings schema
-- name faces at load time too — so deferring would open a window in which a shipped default named a
-- face LSM had never heard of.
--
-- What registration buys over the bare path is the settings panel: a registered face appears in the
-- font dropdown beside every other font the player has, and a profile then stores the NAME —
-- portable across installs — rather than a path naming one addon's folder. The library's call is
-- idempotent and points every consumer at ONE set of bytes under ONE key, which is what makes two
-- Ka0s addons registering "JetBrains Mono" agree rather than collide.
if Media then Media.RegisterLSM(addonName) end
