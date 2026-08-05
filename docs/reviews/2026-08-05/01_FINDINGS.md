# Review findings — Ka0s Bank Ledger, 2026-08-05

**Verdict: minor issues.** No Critical findings. The addon is coherent, well-layered and the best-
evidenced repo in the collection: every out-of-game suite re-run from scratch for this review agrees
with the committed record, byte for byte. Two High findings — a wrong LibStub major name that makes a
shipped diagnostic verb always lie, and a vendor-sync gate that passes when it cannot look — plus a
cluster of dead exported members whose test coverage measures code the addon never runs.

Standards cross-check: **performed**. The living standard resolved at **v2.21.0 (2026-08-04)**, fetched
from `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md`
and cross-read against the local checkout at `WowAddonStandards@2080a8d` (identical header).

---

## Measurement run (Step 0 — all suites re-run from scratch for this review)

| Suite | Command (from repo root) | Result |
|---|---|---|
| **luacheck** | `luacheck .` | **pass** — 0 warnings / 0 errors in 24 files |
| **Headless tests** | `lua5.1 tests/run.lua` | **pass** — 726 passed, 0 failed, 726 total (exit 0) |
| **Test-case inventory** | `lua5.1 tests/run.lua --list > <scratch>/list.md` | **pass** — 819 lines; `diff docs/test-cases.md <scratch>/list.md` is **empty** |
| **Offline perf** | `lua5.1 tests/perf.lua` | **skipped** — no `tests/perf.lua` in the repo (a standing state, tracked as `BL-16`; not this review's finding) |
| **Complexity** | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" . > <scratch>/lizard.txt` | **pass** — nloc 12788, 1946 functions, avg CCN 2.1, **0 functions over CCN 15**; peak CCN 15 |
| **`make test`** | — | **skipped** — no `Makefile` in the repo |
| **Vendor sync (external `diff -r`)** | `diff -r libs/LibKa0s/ ../LibKa0s/LibKa0s/` | **not run** — out of scope for this review's single-repo constraint. See **F-002**: the in-repo substitute cannot be distinguished from a silent skip |
| **Vendor sync (in-suite)** | part of `lua5.1 tests/run.lua` | 2 cases green (`tests/test_vendor_sync.lua`) — but see **F-002** |

**Functions above CCN 15 (the review asked for every one): none.** The four at the cap, all exactly 15,
are `ensureFrame` (`modules/SessionWindow.lua:437-558`), `accumulateItemTaxonomy`
(`core/Database.lua:234-265`), `LT:UpdateHeaderArrows` (`modules/LedgerTable.lua:827-843`) and `I:Layout`
(`modules/Insights.lua:536-582`). Next highest: 14 (`W.BuildBackToBackRows`
`modules/InsightsWidgets.lua:329`, `L:GateReason` `modules/Ledger.lua:402`).

### Committed artifacts vs. today's run

| Artifact | Agreement |
|---|---|
| `docs/test-cases.md` | **current** — byte-identical to a fresh `--list` (empty diff) |
| `README.md` `[Tests]` badge (726/726) | **current** — matches the fresh run |
| `docs/automated-tests/RESULTS.md` (newest row `20260804-233144`) | **current** — 0/0 lint over 24 files, 726/726, nloc 12788, 1946 funcs, avg CCN 2.1, max CCN 15, 0 warnings all reproduce exactly |
| `docs/automated-tests/20260804-233144/complexity.txt` | **current** — the per-function table diffs clean against today's `lizard` run once CRLF is normalized (1946 rows, no drift) |
| `RESULTS.md` § *Files by `layout-§1` band* | **current** — `modules/Browser.lua` 1368, `tests/test_ledger.lua` 1361, `modules/LedgerTable.lua` 1052, `modules/Insights.lua` 1023 all confirmed |
| `docs/performance.md`, `docs/perf-runs/` | **absent** — nothing to compare; `RESULTS.md` already records `perf: skip` as permanent, with the deviation IDs |

Nothing in the committed evidence is stale. That is worth stating plainly, because it means every
number cited below is both freshly measured *and* corroborated.

In-client checks are deliberately absent from this block — they are in `03_SMOKE_TESTS.md`.

---

## High

### F-001 — `/bl debug panel` reads the wrong LibStub major and always reports `minor=nil` `[bug]`

**Where:** `settings/Panel.lua:405`

```lua
local minor = LibStub and LibStub.minors and LibStub.minors["O.AceGUI-3.0"]
```

**Problem:** the LibStub major is `"AceGUI-3.0"`. `"O.AceGUI-3.0"` is never a registered key, so `minor`
is unconditionally `nil` and the verb's first line always renders `AceGUI=yes minor=nil`.

**Impact:** `/bl debug panel` is a README-documented verb (`README.md:97`) whose entire job — per this
file's own header at `settings/Panel.lua:402-403` — is to say *which* AceGUI copy actually served the
widget, "with several addons loaded, the FIRST copy to load wins for all of them". That is the one
question the line was written to answer, and it can no longer answer it. This is the diagnostic the
comments at `settings/Panel.lua:365-370` credit with finding the options-header skinning race
(anti-patterns #42), so it matters precisely when it is needed.

**Cause is visible:** a mechanical `AceGUI` → `O.AceGUI` rename (introduced when the file started
reading AceGUI off the library instance) swept a string literal along with the identifiers. The same
sweep damaged five prose comments — see F-005.

**Coverage:** the inventory claims three cases over `P:Diagnose`
(`tests/test_panel.lua:405, 415, 424`). The one that exercises the full dump asserts this exact line
**by shape only** — `assertTrue(out[1]:find("^AceGUI=") ~= nil, ...)` at `tests/test_panel.lua:460`,
with the comment "The AceGUI preamble depends on which copy of the library actually loaded, so it is
matched by shape". So the case is awake but deliberately blind to the value, and no mutation of the
major name can redden it.

**Fix direction:** use the real major name. Do **not** hard-code the minor or synthesize it from the
vendored copy — `library-stack` is explicit that the *serving* instance is the thing worth reporting.

### F-002 — the vendor-sync gate passes when it cannot look `[tests]`

**Where:** `tests/test_vendor_sync.lua:110-118` (`siblingTag`), consumed at `:133-135` and `:137-141`

```lua
local function siblingTag()
    if not gitShow("HEAD:LibKa0s/Core.lua") then return nil end
    ...
end
...
test("libs/LibKa0s is the LibKa0s release the README says this addon bundles", function()
    local tag = siblingTag()
    if not tag then return end          -- <- silent PASS
```

**Problem:** when the sibling `../LibKa0s` checkout is absent — a fresh clone, CI, any machine but the
author's — both cases return before asserting anything and print `PASS`. The kit has no skip status
(`tests/_kit/framework.lua` at rev 6 exposes only `assertEqual/assertTrue/assertFalse/assertNil/
assertNear/assertError`), so a case that could not run is indistinguishable in the runner output, in
`docs/test-cases.md` and in the README badge from one that ran and matched.

**Impact:** this is exactly anti-patterns #45's silent shape, one level up: the check written to catch
a drift both repos stay green through, itself goes green when it cannot see. `testing-§11` is explicit
— *"MUST fail, not pass, when the gate cannot run. If the directory listing yields nothing, the check
could not look — and a gate that goes quiet when it cannot look is worse than no gate."* Two of the 726
cases in the inventory read as vendor-sync coverage unconditionally.

**Compounding it, the file's own comment is false.** `tests/test_vendor_sync.lua:105-108` claims *"A
missing sibling is the ONE case where this pair may go quiet, and it is said in the case name rather
than hidden."* Neither case name mentions the sibling, the checkout or the condition. A reader auditing
the inventory has no signal at all.

**Measurement note:** this review could not resolve which branch ran here — the single-repo constraint
forbids touching `../LibKa0s`. That ambiguity **is** the finding: a suite whose result cannot be read
back from its own output.

**Fix direction:** two parts, and the second is upstream. Locally, make the conditionality legible —
the case name must carry it, so the inventory stops overstating (`testing-§5`). Upstream in LibKa0s,
the kit framework needs an additive `Kit.skip(reason)` so a not-run case is *recorded as skipped*
rather than counted as a pass, which is the only fix that makes the runner output honest for every
consumer. Do **not** hard-fail unconditionally in the addon: a fresh clone without the sibling is a
legitimate state for a consumer, and reddening the commit gate for it would push people to
`--no-verify`, which `testing-§4` and anti-patterns #51 both name as the failure mode.

---

## Medium

### F-003 — six exported members with zero production callers, five of them carrying test coverage `[design]` `[tests]`

Verified by grep across `core/ modules/ settings/ defaults/ locales/` (vendored `libs/` and
`tests/_kit/` excluded per the review's own rule); the only references outside each definition are in
`tests/`.

| Member | Defined at | Why it is dead |
|---|---|---|
| `Compat.QualityFromLink` | `core/Compat.lua:184` | No caller anywhere — **not even a test**. Still listed as live API in `docs/ARCHITECTURE.md:139` |
| `Database:DeleteAt` | `core/Database.lua:551` | Its own comment says *"(from the table's right-click menu)"* — but the row menu at `modules/LedgerTable.lua:1005` deletes by identity through `Database:Delete(function(r) return r == entry end)`. **The comment is false.** Covered by `tests/test_database.lua:168,176` and `tests/test_ledger.lua:572` |
| `F:IsBlacklisted` / `F:IsWhitelisted` | `modules/Filters.lua:40,45` | The capture gate reads the cached hot-path upvalues directly (`modules/Ledger.lua:412-413`), never these. Covered by `tests/test_filters.lua` |
| `I.RankRows` / `I.BarFraction` | `modules/Insights.lua:30,52` | Headed *"Pure ranking helpers (unit-tested)"* at `modules/Insights.lua:26`; nothing in the addon calls either. Covered by `tests/test_stats.lua` |
| `LT:CellText` | `modules/LedgerTable.lua:98` | Comment claims *"the UI binds through the same path"*; the UI binds `col.valueFn` obtained via `LT:Column` (`modules/LedgerTable.lua:108`). Covered by `tests/test_ledgertable.lua` |

**Impact:** two separate costs. The members are surface that must be kept working, and the cases over
them are inventory that reads as coverage of shipped behavior while exercising code no user path
reaches — an inventory-integrity problem, not merely tidiness. Three of the comments actively mislead
about who calls what, which is the more expensive half: a future author reading
`core/Database.lua:550` will believe the row menu is on `DeleteAt` and change the wrong function.

**Not in scope of this finding:** `P.__pagesForTest` (`settings/Panel.lua:477`) is an explicit,
named test seam and is fine as-is; the degradation stubs in `core/DebugLogSetup.lua` and
`settings/OptionsSetup.lua` are not dead code — their callers are the same call sites the live
instances serve, and both stubs were checked against the real call-site sets and answer every member.

### F-004 — a full-ledger walk on every `LedgerChanged`, fired even when nothing changed `[perf]`

**Where:** `modules/SessionWindow.lua:158-169`, `core/Database.lua:620-636`, `core/BankLedger.lua:52-60`

`SW:PruneMissing` builds a presence set over **the entire ledger** before it looks at how many session
rows there are to prune:

```lua
function SW:PruneMissing()
  if SW.previewSession then return 0 end
  local present = {}
  for _, e in ipairs((NS.Database and NS.Database:Ledger()) or {}) do present[e] = true end   -- O(n) + one table per call
  ...
```

The common case is `#self:Entries() == 0` — no bank frame open, nothing to prune — and it pays the
whole walk anyway.

The message that drives it is fired more often than it needs to be. `Database:PruneOld`
(`core/Database.lua:620`) calls `fireLedgerChanged()` unconditionally whenever retention is enabled,
including when `removed == 0`; its own header comment at `core/Database.lua:619` says *"Fires
LedgerChanged when it actually runs"*, which reads as "when it removes something" and is not what the
code does. `PruneOld` is scheduled 5 s after every `PLAYER_ENTERING_WORLD` (`core/BankLedger.lua:55-58`),
so **every login** pays: the SessionWindow full-ledger walk above, `B:OnLedgerChanged`
(`modules/Browser.lua:1361`), an Insights refresh (`modules/Insights.lua:1021`), and — if the settings
panel happens to be open — `Database:StorageStats`, which is a second full-ledger walk
(`core/Database.lua:603-616`, reached from `settings/Panel.lua:141-157,165`). For a user who has recorded
nothing older than the retention window, all of that runs for zero rows removed.

**Unverified quantitatively, and that is itself worth recording:** the addon ships no `tests/perf.lua`
and no `docs/perf-runs/`, so there is no measured allocation or call count to cite for the hot paths
(`RESULTS.md` records `perf: skip` as a permanent state, deviations `BL-15`/`BL-16`). The cost above is
read off the code, not measured. That is a fair reason to keep this at Medium rather than High.

**Fix direction:** an early return in `PruneMissing` when there are no session entries, and make
`PruneOld` fire only when `removed > 0` (and correct the comment either way). Both are guard clauses in
the addon's own code, not new abstractions.

### F-005 — a rename swept five prose comments into nonsense `[naming]`

**Where:** `settings/Panel.lua:11, 13, 21, 23, 402`

The same `AceGUI` → `O.AceGUI` sweep behind F-001 rewrote the prose, producing sentences that no longer
parse: *"O.AceGUI is reached through `O.AceGUI` rather than a second LibStub call"* (:11), *"an O.AceGUI
absent at load may be present"* (:13), *"O.AceGUI Headings group them into sections"* (:21), *"because
O.AceGUI lays out against the panel's current width"* (:23), *"Which O.AceGUI actually served the
widget"* (:402). `O.AceGUI` is a field on this addon's options instance; the library being discussed is
AceGUI-3.0. Cosmetic on its own — listed because it is the visible trail of F-001's cause and should
move in the same change.

---

## Low

### F-006 — the frame-context axis is addressed with a store constant in two places `[naming]`

**Where:** `modules/Ledger.lua:713` and `modules/Ledger.lua:743`

```lua
  if context == C.Store.GUILD_BANK then      -- :713, inside L:OpenContext
    self:OpenContext(C.Store.GUILD_BANK)     -- :743, inside L:OnGuildBankData
```

Every other site on that axis uses `C.Context.GUILD_BANK` — `L.CONTEXT_STORES` (`modules/Ledger.lua:32`),
`disarmGuildBankIfGone` (`:615`), the `OnHide` hook (`:702`), `OPEN_EVENTS` (`:766`). Behavior is
identical **only** because `core/Constants.lua:37-40` shares the token on purpose. But that same block
states the context axis is *"deliberately NOT a C.Store value"*, and these two lines are the exception
that erodes the distinction — the next store added to `C.Store` is where it stops being harmless. Pure
rename; no behavior change.

### F-007 — extraction debris in `settings/Panel.lua` `[organization]`

**Where:** `settings/Panel.lua:39-42, 62-67, 78-80, 119-120, 172-173`, and `:469-476`

Five runs of 2–6 consecutive blank lines left where helpers were lifted out. Worse, `:469-476` carries
the *same* doc paragraph twice, reworded — *"Test seam over the private registry… is exactly how this
one shipped walking a single page for so long"* immediately followed by *"Test seam over the library's
page registry… is how this one shipped walking a single page for so long"* — and the block's opening
line ("Scalar re-sync only…") describes `P:Refresh`, which is eight lines further down at `:479`, with
`P.__pagesForTest` wedged between the comment and the function it documents.

### F-008 — the Defaults tooltip does not mention that it moves both windows `[ux]`

**Where:** `settings/Panel.lua:547-549` vs. `settings/Panel.lua:506-514`

The General page's Defaults tooltip reads *"Restore every Bank Ledger setting to its default. Your
recorded history is never touched."* `P:RestoreDefaults` also calls `NS.Browser:ResetWindow()` and
`NS.SessionWindow:ResetWindow()`, which discard the persisted geometry and recenter/resize both
standalone windows. Window layout is not a setting the panel shows, so a user who has carefully placed
the ledger window has no warning that "Defaults" undoes it. The code comment at `:510` acknowledges the
behavior; the user-facing string does not.

### F-009 — the schema carve-out note lists two of four carve-outs `[docs]`

**Where:** `settings/Schema.lua:124-125`

> `-- NOTE: settings.window (geometry) and the blacklist/whitelist id-sets are storage carve-outs,`
> `-- mutated by their owning modules rather than through Schema:Set (architecture-§5).`

Two more persisted keys are written outside the single write seam and are absent from the list:
`settings.sessionWindow` (`modules/SessionWindow.lua:256, 287`) and `savedView`
(`modules/Browser.lua:916`, cleared at `:923`). `defaults/Global.lua:24-29,43` documents both correctly,
so the two notes disagree — and `settings/Schema.lua` is the one a reader checks when asking "may I
write this directly?".

---

## Not findings (checked and clear)

Recorded so the next reviewer does not re-derive them:

- **Taint / combat.** No protected-API call, no secure-frame manipulation, no `:Hook` on a secure
  function anywhere in the addon's own code. The one `HookScript("OnHide", ...)` is on
  `GuildBankFrame`, a plain non-secure frame (`modules/Ledger.lua:698`). Combat refusal for the options
  panel is delegated to the library rather than duplicated (`settings/Panel.lua:621-626` →
  `libs/LibKa0s/Options.lua:463,637`), which is the compliant direction.
- **Deprecated APIs.** Every varying API is behind `core/Compat.lua` with a presence check.
  `C_Item.GetItemInfo` return positions are correct at `core/Compat.lua:209` and `:219`; container reads
  are `C_Container.*`; metadata is `C_AddOns.GetAddOnMetadata` with a fallback. No `UnitAura`, no
  `IsAddOnLoaded`, no `InterfaceOptions_AddCategory`.
- **`SetBackdrop`.** All 13 call sites target frames created with `"BackdropTemplate"`, including the
  two library-owned windows `B:ApplySkin` is handed (`libs/LibKa0s/DebugLog.lua:281,448`).
- **Events.** Registered in `OnEnable`, each behind an `_enabled` guard, each `RegisterEvent` isolated in
  a `pcall` so one retired name cannot silence the rest (`modules/Ledger.lua:794-799`).
  `BAG_UPDATE_DELAYED`, not `BAG_UPDATE`. Every bus consumer has its own AceEvent target.
- **Single write path.** No `db.global` write bypasses `Schema:Set` except the four documented
  architecture-§5 carve-outs (see F-009 for the note that lists only two of them).
- **Load-list rot.** `tests/run.lua:46` derives the addon's own files from the shipped TOC via
  `Loader.tocFiles`, and the eight `libs/LibKa0s/` files are spelled out in XML order (`:31-40`) with
  `tests/test_libka0s.lua` asserting the list against `LibKa0s.xml`; `tests/test_harness.lua` asserts
  the `SUITES` list against `tests/test_*.lua` on disk in both directions. Exactly what `testing-§9`
  requires.
- **Degraded-path tests.** `tests/test_libka0s.lua`'s degraded cases genuinely re-load the addon with the
  library absent, and each opens with a self-falsification guard (e.g. `:752` *"the library is present
  after all"*, `:164` *"the degraded environment still has the library — this case proves nothing"*).
  This is the shape `testing-§8` asks for and it is done right.
- **Degradation stubs.** Both were diffed against their real call-site sets. `core/DebugLogSetup.lua:26-46`
  answers all six members reached (`Add`, `Hide`, `IsShown`, `SetEnabled`, `Show`, `Toggle`) plus five
  more; `settings/OptionsSetup.lua:125-155` answers all 19 members and the three layout constants —
  and correctly returns `0` for the constants rather than copying the library's values
  (anti-patterns #47).
- **`NS.COMMANDS` ↔ README.** All 15 verbs in `settings/Schema.lua:226-286` appear in the README table
  (`README.md:82-98`), which additionally documents the two `debug` sub-verbs; no orphans either way.
- **Raw `print`.** Every call site is the shadowed `local print = NS.Print` upvalue; no bare global
  `print` anywhere in the addon's own source.
