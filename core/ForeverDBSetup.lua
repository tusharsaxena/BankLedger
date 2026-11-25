local _, NS = ...

-- core/ForeverDBSetup.lua — wires the addon into LibKa0s-ForeverDB-1.0 (library-stack-§7;
-- WowAddonStandards clients-§11, LibKa0s#105).
--
-- WHAT IT IS FOR. One feature reads it: the vendor buy price on a ledger row's item tooltip, on WoW
-- Forever, beside the price the client's own tooltip shows for selling the item
-- (modules/LedgerTable.lua, LT.AddVendorBuyPrice). The price is the lowest a vendor was seen asking
-- in ForeverDB's recordings. It is shown, never stored: the ledger keeps no value (schema v2 stripped
-- vendorPrice, the 2026-07-27 Insights overhaul), and nothing here changes that.
--
-- ForeverDB IS OPTIONAL. It is listed under the TOC's `## OptionalDeps` and `.pkgmeta`'s
-- `optional-dependencies`, never as a requirement. Without it, or on Retail, the tooltip simply has
-- no such line, and the settings row says the feature needs ForeverDB.
--
-- WHEN IT LOADS. Never at file load or login: the adapter loads the 12 MB data addon on its first
-- lookup, and this addon's first lookup is the first hover of an item row on WoW Forever with the
-- setting on (docs/performance.md, *ForeverDB*). Nothing in this file calls the adapter.
--
-- WHAT A DEGRADED INSTALL GETS. The stand-in the adapter's document prescribes (its *Degradation*
-- section): every member answers the all-absent value, so the feature is simply inert.
-- tests/test_surface_parity.lua holds it to the library's member manifest.

local FDB = LibStub and LibStub("LibKa0s-ForeverDB-1.0", true)

local function none() return nil end

NS.ForeverDB = FDB or {
  Available     = function() return false, "missing" end,
  IsLoaded      = function() return false end,
  Status        = function() return { present = false, loaded = false } end,
  Meta          = none,
  NPC           = none,
  Item          = none,
  Quest         = none,
  ItemSources   = none,
  VendorPrice   = function() return nil, nil end,
  Spots         = none,
  TrainerSpells = none,
}
