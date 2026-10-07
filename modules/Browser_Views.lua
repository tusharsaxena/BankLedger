local _, NS = ...
local B = NS.Browser
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

-- The ledger window's per-tab VIEW machinery: the saved and stock views, capturing and painting a
-- view on the shared filter bar, Save · Reset · Clear, and the per-tab live state a tab switch
-- trades. Peeled out of modules/Browser.lua (BL-R-02: that file sat at 1427 of layout-§1's 1500
-- lines, with this seam named on the RESULTS.md watch list). A MOVE, not a rewrite: every public B
-- method keeps its name and behavior, and the test seams B._STOCK_VIEW / B._savedViewOrStock keep
-- theirs.
--
-- What it needs of Browser.lua's file locals comes through ONE explicit seam table,
-- B._viewSeam, which Browser.lua publishes at file load -- never a new global. The tab on screen is
-- read through the public B:ActiveTab(), so lastTab stays owned (and written) by Browser.lua alone,
-- and the typing debounce handle stays there behind dropFilterDebounce. LOAD-BEARING order: this
-- file extends NS.Browser and captures B._viewSeam at file load, so it must load after
-- modules/Browser.lua (BankLedger.toc).
local seam = B._viewSeam
local CURRENT_CHAR, setToFilter = seam.CURRENT_CHAR, seam.setToFilter
local searchClause, dropFilterDebounce = seam.searchClause, seam.dropFilterDebounce

-- The Character filter's DEFAULT selection: the character you are on. Opening the ledger answers
-- "what did I move?" far more often than "what did all eleven of my alts move?", so the window
-- starts scoped to you and widens on demand — one step to "All", instead of everyone having to
-- narrow it every session. Test mode is the exception: its dataset is synthetic alts, so scoping
-- it to the real player would open the window on an empty table.
local function defaultCharSelection()
  if NS.LedgerTable and NS.LedgerTable:IsTestMode() then return {} end
  return { [CURRENT_CHAR] = true }
end

-- ── The view: group + sort + column filters ───────────────────────────────────
-- A "view" is everything the filter bar expresses EXCEPT the character scope: the grouping, the
-- sort, the six multi-select column filters, the date range and the search text. STOCK_VIEW is the
-- out-of-the-box baseline; the user's own baseline, once they press Save, lives in the profile at
-- NS.db.profile.savedViews[tab] -- one per tab, keyed by the TABS name ("History", "Insights").
-- Before schema v5 there was one, NS.db.profile.savedView; NS.MIGRATIONS[5] copied it into both
-- slots (core/Database.lua).
--
-- Character is deliberately NOT part of a view. "What did I move?" is the question the window is
-- opened to answer far more often than "what did all my alts move?", so the scope is a per-session
-- default of Current that widens on demand — never something a stale save can pin to one alt.
--
-- Field names match the activeFilter / Database:QueryList keys, so nothing has to translate between
-- the two shapes. An empty set means "All". `date` stores the RANGE OPTION ("7d"), never a resolved
-- timestamp, so it recomputes against each session's clock instead of freezing a week in the past.
local STOCK_VIEW = {
  groupBy = "none", sortKey = "date", sortAsc = false,
  direction = {}, store = {}, quality = {}, itemType = {}, itemSubType = {},
  date = "all", search = "",
}

-- The profile's per-tab saved views, or nil. `create` makes the table for a Save; nothing else
-- does, so "no key" keeps meaning "nothing saved on any tab" (defaults/Profile.lua). A value
-- corrupted to a scalar reads as nothing saved, and a Save replaces it.
local function savedSlots(create)
  local p = NS.db and NS.db.profile
  if not p then return nil end
  local s = p.savedViews
  if type(s) ~= "table" then
    if not create then return nil end
    s = {}
    p.savedViews = s
  end
  return s
end

-- The baseline Clear returns to on `tab` (the active tab when omitted): that tab's saved view when
-- one exists, else stock. Type-checked, so a SavedVariables value corrupted to a scalar degrades to
-- stock rather than erroring on first paint.
local function savedViewOrStock(tab)
  local s = savedSlots(false)
  local v = s and s[tab or B:ActiveTab()]
  if type(v) == "table" then return v end
  return STOCK_VIEW
end

-- Normalize a stored view field into a selection set. Tolerates a bare scalar and the "all" sentinel
-- alongside the set form — cheap insurance for a table that survives in SavedVariables across
-- versions, and it keeps a hand-edited saved view from breaking the bar.
local function asSet(v)
  local s = {}
  if type(v) == "table" then
    for k, on in pairs(v) do if on then s[k] = true end end
  elseif v ~= nil and v ~= "all" then
    s[v] = true
  end
  return s
end

-- The five multi-select column filters, as the pair of names each one goes by: the field in a view,
-- and the dropdown on the bar that holds it. ONE ordered array, read by both CaptureView and
-- ApplyView, so the two halves of the round trip can never disagree about which sets a view carries
-- — or in what order the bar is painted.
local VIEW_SETS = {
  { view = "direction",   dd = "direction" },
  { view = "store",       dd = "store" },
  { view = "quality",     dd = "quality" },
  { view = "itemType",    dd = "type" },
  { view = "itemSubType", dd = "subtype" },
}

-- The table's own share of a view — group and sort — defaulted for the build where the table module
-- is not loaded. `sortAsc` is a strict `== true`, not a truthiness pass-through.
--
-- With no table module the third return is nil, NOT false. It feeds a table constructor whose result
-- is written verbatim to SavedVariables, and a nil in a constructor leaves the KEY ABSENT from the
-- stored view — which is what master's `sortAsc = LT and LT.sortAsc == true` did. An absent key and
-- a stored `false` are different facts on disk, so the nil is load-bearing; do not tidy it to false.
local function tableViewState(LT)
  if not LT then return "none", "date", nil end
  return LT.groupBy or "none", LT.sortKey or "date", LT.sortAsc == true
end

-- Capture what is on screen as a view table. Every set is a COPY (setToFilter's fresh table), never
-- an alias of a live dropdown's set — otherwise the next toggle would silently rewrite the view the
-- user just saved, the same aliasing hazard ApplyFilter guards against (F-013).
function B:CaptureView()
  local dd, LT = self._dd, NS.LedgerTable
  local groupBy, sortKey, sortAsc = tableViewState(LT)
  local v = {
    groupBy = groupBy,
    sortKey = sortKey,
    sortAsc = sortAsc,
    date   = (dd and dd.date._value) or "all",
    search = (self._search and self._search:GetText()) or "",
  }
  for _, f in ipairs(VIEW_SETS) do
    v[f.view] = setToFilter(dd and dd[f.dd]._selected) or {}
  end
  return v
end

-- Push a view's group/sort onto the table. Guarded: a partial build can reach here without it.
local function applyTableState(view)
  if not NS.LedgerTable then return end
  NS.LedgerTable.groupBy = view.groupBy or "none"
  NS.LedgerTable.sortKey = view.sortKey or "date"
  NS.LedgerTable.sortAsc = view.sortAsc == true
end

-- Normalize a view's five column filters into selection sets, still keyed the way the view is.
local function viewSets(view)
  local s = {}
  for _, f in ipairs(VIEW_SETS) do s[f.view] = asSet(view[f.view]) end
  return s
end

-- Paint the bar itself. The character dropdown takes the session scope, not anything from the view.
local function paintDropdowns(dd, view, sets, date, chars)
  if not dd then return end
  dd.group:SelectValue(view.groupBy or "none")
  dd.date:SelectValue(date)
  for _, f in ipairs(VIEW_SETS) do dd[f.dd]:SetSelected(sets[f.view]) end
  dd.char:SetSelected(chars)
end

-- The resolved filter the table and Insights actually query with. `date == "all"` means no lower
-- bound at all (nil, never 0), and an empty or whitespace-only search means no text clause.
local function buildActiveFilter(chars, sets, date, search)
  return {
    char        = B.ResolveCharFilter(chars),
    direction   = setToFilter(sets.direction),
    store       = setToFilter(sets.store),
    quality     = setToFilter(sets.quality),
    itemType    = setToFilter(sets.itemType),
    itemSubType = setToFilter(sets.itemSubType),
    from = (date ~= "all") and NS.Util.RangeFrom(date) or nil,
    text = searchClause(search),
  }
end

-- Paint a view: the table's group/sort, every dropdown, the search box and the resolved filter. The
-- character scope is not in the view — it resets to `scope` ("all" for everyone, a selection set
-- for exactly that selection — what a tab switch restores — anything else for the current player).
-- That scope write goes last and carries the single ApplyFilterNow that paints everything set above
-- it, so a view swap costs one query, not nine.
function B:ApplyView(view, scope)
  view = view or STOCK_VIEW
  local chars
  if type(scope) == "table" then chars = scope
  elseif scope == "all" then chars = {}
  else chars = defaultCharSelection() end
  local date   = view.date or "all"
  local search = view.search or ""

  applyTableState(view)
  local sets = viewSets(view)
  paintDropdowns(self._dd, view, sets, date, chars)
  -- Set the box before rebuilding activeFilter: OnTextChanged fires on SetText and writes
  -- activeFilter.text itself, so doing it the other way round would let the widget clobber the
  -- value we just resolved.
  if self._search then self._search:SetText(search) end
  -- That SetText armed the typing debounce in the client; the apply below covers it.
  dropFilterDebounce()

  self.activeFilter = buildActiveFilter(chars, sets, date, search)
  B:ApplyFilterNow()
end

-- Return the bar to the ACTIVE TAB's baseline: that tab's saved view when there is one, else stock,
-- always scoped to the current character. This is what the Clear button, a dataset swap, a tab's
-- first visit and the first build all use, so "the view you start from" has exactly one definition.
-- The other tab's live state and saved view are not touched.
function B:ClearFilters()
  self:ApplyView(savedViewOrStock(), "current")
end

-- Save what is on screen as the ACTIVE TAB's baseline; the other tab's saved view is not touched.
-- Per PROFILE, not per character: every character shares the Default profile unless the player
-- chooses otherwise, so by default one saved view per tab serves the whole account, as the one
-- ledger does.
function B:SaveView()
  local s = savedSlots(true)
  if not s then return end
  local tab = B:ActiveTab()
  s[tab] = self:CaptureView()
  print(tab, "view saved as your default.")
end

-- Drop the ACTIVE TAB's saved baseline back to stock and apply it now; the other tab keeps its own.
-- The last slot out takes the savedViews table with it, so a profile with nothing saved stores no
-- key, as it did before anything was saved. `silent` suppresses the chat line for programmatic
-- callers; the bar's Reset button passes nothing and keeps the message.
function B:ResetView(silent)
  local s = savedSlots(false)
  if s then
    s[B:ActiveTab()] = nil
    if next(s) == nil then NS.db.profile.savedViews = nil end
  end
  self:ApplyView(STOCK_VIEW, "current")
  if not silent then print(B:ActiveTab(), "view reset to stock defaults.") end
end

-- ── Per-tab live state ────────────────────────────────────────────────────────
-- The bar is one set of widgets, but each tab keeps its OWN live filter state: switching captures
-- the outgoing tab's view AND its character selection here, and paints the incoming tab's from its
-- capture -- or, on that tab's first visit, from its baseline. Session state, never persisted: what
-- persists is each tab's saved view. The character selection is captured raw (the Current sentinel
-- unresolved), so a restored "Current" still means whoever is logged in.
local tabLive = {}

-- The baseline a tab with no live state starts from: stock across ALL characters in test mode (the
-- synthetic alts; a saved Store/Type filter would very likely match nothing), else ClearFilters.
local function applyBaseline()
  if NS.LedgerTable and NS.LedgerTable:IsTestMode() then
    B:ApplyView(STOCK_VIEW, "all")
  else
    B:ClearFilters()
  end
end

local function forgetTabStates()
  for k in pairs(tabLive) do tabLive[k] = nil end
end

--- Trade the bar's state from tab `from` to tab `to`. A no-op on the same tab, so reopening the
--- window (B:Show re-selects the tab it closed on) keeps what was on screen.
function B:SwapTabState(from, to)
  if from == to then return end
  if from then
    local dd = self._dd
    tabLive[from] = {
      view  = self:CaptureView(),
      -- nil without a bar: there is no selection to keep, and the restore scopes to Current.
      chars = dd and (setToFilter(dd.char._selected) or {}) or nil,
    }
  end
  local live = tabLive[to]
  if live then
    self:ApplyView(live.view, live.chars or "current")
  else
    applyBaseline()
  end
end

--- Every tab back to its baseline: the live states are dropped, and the tab on screen is repainted
--- from its saved view (or stock). A profile event's repaint (core/Database.lua), so the tab off
--- screen cannot come back on a state captured under the profile it replaced.
function B:ClearAllTabs()
  forgetTabStates()
  self:ClearFilters()
end

-- Test seams: the module-locals the view machinery is built on, exposed by name rather than
-- reconstructed in the tests, so a change to either definition is caught rather than duplicated.
B._STOCK_VIEW = STOCK_VIEW
B._savedViewOrStock = savedViewOrStock

-- The dataset changed under the bar (entering/leaving test mode): rebuild the dropdowns from the
-- new data, since the old values may not exist in it. Entering test mode opens on the STOCK view
-- across ALL characters — the test data is synthetic alts, so a saved Store/Type filter would very
-- likely match nothing and the window would look broken. Leaving it restores the saved view. Every
-- tab's live state goes with the old dataset, so the other tab starts from its baseline too.
function B:OnDatasetChanged()
  self:RefreshFilterOptions()
  forgetTabStates()
  applyBaseline()
  self:UpdateFooter()
  self:UpdateDbSize()
  self:UpdateTestBadge()
  if NS.Insights and NS.Insights.Refresh then NS.Insights:Refresh() end
end
