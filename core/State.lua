local addonName, NS = ...   -- luacheck: ignore addonName
NS.State = NS.State or {}
local State = NS.State

-- Runtime-only state. Nothing here is ever persisted to SavedVariables — every field resets on a
-- /reload or a fresh login.

-- Which storage FRAME is currently open ("BANK_FRAME" or "GUILD_BANK") or nil. A
-- movement is only attributed while one is open: that is what tells a deposit apart from a loot or
-- a vendor buy.
--
-- This is a frame, not a store, and the distinction is the whole point: the retail bank frame hosts
-- the character bank, the reagent tab AND the warband tabs behind a single BANKFRAME_OPENED, and
-- switching between those tabs fires no event at all. So the addon can never know "which store is
-- open" — it knows which frame is open, and reconciles every store that frame can reach.
State.openContext = nil

-- The last inventory snapshot taken while a frame was open, in the shape Ledger:Snapshot returns:
-- { bags = { [itemID] = count }, stores = { [store] = { [itemID] = count } }, money = <copper> }.
-- The next snapshot is diffed against it, per store, to produce ledger entries.
State.lastSnapshot = nil

-- Session flags.
State.cleanupDone = false   -- retention prune runs once per session
State.debug = false         -- session-only logging flag, independent of the console window's
                            -- visibility. /bl debug on|off; default off, never in SavedVariables.
State.testRecords = nil     -- session-only synthetic dataset published by /bl preview; when set,
                            -- every read-path query (table + Insights) resolves against it instead
                            -- of the live ledger.
