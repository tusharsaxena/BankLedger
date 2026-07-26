local addonName, NS = ...   -- luacheck: ignore addonName
NS.State = NS.State or {}
local State = NS.State

-- Runtime-only state. Nothing here is ever persisted to SavedVariables — every field resets on a
-- /reload or a fresh login.

-- The store whose UI is currently open ("BANK", "GUILD_BANK", …) or nil. A movement is only
-- attributed while a store is open: that is what tells a deposit apart from a loot or a vendor buy.
State.openStore = nil

-- The last inventory snapshot taken while `openStore` was open, in the shape Ledger:Snapshot
-- returns: { [store] = { [itemID] = count }, money = <copper> }. The next snapshot is diffed
-- against it to produce ledger entries.
State.lastSnapshot = nil

-- Session flags.
State.cleanupDone = false   -- retention prune runs once per session
State.debug = false         -- session-only logging flag, independent of the console window's
                            -- visibility. /bl debug on|off; default off, never in SavedVariables.
State.testRecords = nil     -- session-only synthetic dataset published by /bl preview; when set,
                            -- every read-path query (table + Insights) resolves against it instead
                            -- of the live ledger.
