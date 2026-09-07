# Review findings — Ka0s Bank Ledger — 2026-09-07

**Verdict: minor issues.** The addon is structurally strong — every LibKa0s seam is a real
descriptor + degradation stub, the degraded arms are exercised by genuinely loading without the
library, the marks convention is adopted with its own suite, and lint/tests/complexity are all
green today. Two defects are worth fixing before the next release: a global reset that leaves the
capture engine on stale settings, and a schema-migration seam that AceDB's own default-stripping
will silently disarm at the next version bump.

Standards cross-check: **performed**. Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)**, fetched
from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` and read from a scratch
path (index + all 27 section files).

---

## Measurement run (Step 0 — everything re-run from scratch today)

All commands run from `/mnt/d/Profile/Users/Tushar/Documents/GIT/BankLedger`. Scratch output under
`/tmp/claude-1000/.../scratchpad/bl/`. Nothing was written into the repo except this bundle.

| Suite | Command | Result |
|---|---|---|
| luacheck | `luacheck .` | **pass** — `Total: 0 warnings / 0 errors in 28 files` |
| Headless tests | `lua5.1 tests/run.lua` | **pass** — `831 passed, 0 failed, 0 skipped, 831 total` |
| Case inventory | `lua5.1 tests/run.lua --list` → scratch | **pass** — 944 lines, `**Total** \| **831**`; byte-identical to committed `docs/test-cases.md` (`diff` exit 0) |
| Offline perf | `lua5.1 tests/perf.lua` | **skipped (no such file)** — deliberate: this repo holds a ratified `performance-§12` no-combat-path exemption (`docs/performance.md`, `docs/ARCHITECTURE.md ▸ Documented deviations`). A skip, never a pass. |
| Complexity | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` → scratch | **pass** — `14174` NLOC, `2153` functions, avg CCN `2.0`, **0 warnings**, `No thresholds exceeded`. Highest CCN anywhere: **15**, on **four** functions. |
| `make test` | — | **skipped** — no root `Makefile`. |
| Vendor sync (`libs/LibKa0s/`) | `diff -rq libs/LibKa0s/ ../LibKa0s/LibKa0s/` | **2 files differ** — `DebugLog.lua`, `Pool.lua`. Content-identical after `tr -d '\r'`; the difference is line endings on the **source** side. See `BANKLEDGER-R-09`. |
| Vendor sync (`tests/_kit/`) | `diff -rq tests/_kit/ ../LibKa0s/testkit/` | **pass** — no differences. |
| In-repo vendor gate | `tests/test_vendor_sync.lua` (inside the suite) | **pass** — ran against the sibling checkout (not a skip); asserts `libs/LibKa0s/` and `tests/_kit/` match the tag `CLAUDE.md` names. |

### Committed artifacts vs. today's run

- `docs/test-cases.md` — **current**. Byte-identical to the fresh `--list`. 831 cases.
- `README.md` `[Tests]` badge — **current**: `Tests-831%2F831_passing`.
- `docs/automated-tests/RESULTS.md` — **stale**, in three places. Its newest table row is
  `20260825-103400` at 791/791 and 13409 NLOC; today's run is 831/831 and 14174 NLOC. Worse, its
  four narrative sections declare themselves "current as of `20260807-115101`" and quote **727**
  cases and "the largest suite in the collection", two runs behind its own newest row. Detail in
  `BANKLEDGER-R-05`.
- `docs/automated-tests/RESULTS.md` complexity watch list — **stale**. It names **five** functions at
  CCN 15 including `ensureFrame` (`modules/SessionWindow.lua`); today `ensureFrame` measures **13**
  and only **four** functions sit at 15. Its file-band table lists `modules/Browser.lua` at 1358 LOC;
  today it is **1251**.
- `docs/performance.md` — **stale in one row**. Its exemption sweep cites `core/Compat.lua`
  `LoadItem`; that primitive now lives at `core/ItemSetup.lua:64-67`. Detail in `BANKLEDGER-R-06`.
- `docs/perf-analysis/` — **absent by design**, covered by the recorded exemption. Not a finding.

In-client checks (taint, real bank events, frame behaviour, locale rendering) are deliberately not
in this block; they are in `03_SMOKE_TESTS.md`.

---

## High

### BANKLEDGER-R-01 — the global reset never tells the capture engine its settings changed  `[design]` `[ux]`

`settings/Slash.lua:92-103` (`Sl:ResetEverything`) empties `db.global` in place and merges the
declared defaults back, then calls `NS.Browser:ResetWindow`, `NS.SessionWindow:ResetWindow` and
`NS.Panel:Refresh`. It never sends `Ka0s_BankLedger_SettingsChanged`.

`modules/Ledger.lua:52-63` caches the whole capture gate in file-scope upvalues — `DB_ENABLED`,
`DB_TRACK_ITEMS`, `DB_TRACK_MONEY`, `DB_QUALITY`, `DB_EXCLUDED`, `DB_BLACKLIST`, `DB_WHITELIST` —
and re-caches them only from `L.__ev:RegisterMessage("Ka0s_BankLedger_SettingsChanged", …)`
(`modules/Ledger.lua:876-878`) or from `NS.Filters:_notify` (`modules/Filters.lua:64-71`). Neither
runs here. `modules/Browser.lua:1164` `B:OnSettingsChanged` and `modules/SessionWindow.lua:646`
`SW:OnSettingsChanged` are on the same message and are equally missed.

**Impact:** for the rest of the session the ledger records against the *pre-reset* settings while
the panel shows the post-reset ones. Reset with capture switched off and capture stays off although
the checkbox now reads on; reset with a quality threshold of Epic and everything below Epic keeps
being dropped; blacklisted item ids cleared by the reset keep being suppressed, because
`DB_BLACKLIST` still points at the *table object* the wipe discarded. Nothing tells the user, and
`/reload` silently "fixes" it — the worst possible bug report.

**Reachability:** any player who clicks Settings ▸ General ▸ Master controls ▸ **Reset all settings**
and confirms the `KA0S_BANKLEDGER_RESETALL` popup — a shipped button on the first tab of the General
page in every install (`settings/Schema.lua:240-246`). `/bl resetall` is **not** affected: it runs
`Sl:CliResetAll`, whose per-row `Schema:Set` fires the message row by row.

**Fix direction:** send `Ka0s_BankLedger_SettingsChanged` (and re-run `NS.Ledger:RefreshUpvalues`)
at the end of `Sl:ResetEverything`, before the window resets. Do **not** enumerate what to refresh —
that is the row-by-row shape this very function was rewritten to avoid; broadcast once on the bus
the three consumers already subscribe to (`architecture-§4`).

**Coverage:** `tests/test_panel.lua:709-747` pins the reset's *blast radius* and *table identity*
with proper `red under:` comments, but no case asserts that a consumer sees the new values. The
suite is green over a path it does not check.

---

### BANKLEDGER-R-02 — `schemaVersion` in the AceDB defaults disarms the migration runner  `[savedvariables]`

`defaults/Global.lua:14` declares `schemaVersion = NS.SCHEMA_VERSION` as an **AceDB default**, and
`core/Database.lua:17,21` reads it back as the runner's input:

```lua
g.schemaVersion = g.schemaVersion or 1
if g.schemaVersion < NS.SCHEMA_VERSION then …
```

AceDB-3.0's `logoutHandler` (`libs/AceDB-3.0/AceDB-3.0.lua:355-359`) calls
`db:RegisterDefaults(nil)` on `PLAYER_LOGOUT`, which runs `removeDefaults(self.global,
self.defaults.global)` (`:424-427`) and **strips every stored key whose value equals the current
default**. A database that was on schema v1 while the shipped default was `1` — the value this repo
shipped before `a6d566d`, confirmed by `git log -p -- defaults/Global.lua` — therefore loses the key
entirely at logout. On the next login under 1.0.0, whose default is `2`, `g.schemaVersion` reads
**2** through the defaults metatable, `2 < 2` is false, and the v1→v2 pass never runs.

The comment on `defaults/Global.lua:12-13` states the opposite — *"Existing profiles are untouched —
they already carry an explicit value, and AceDB only applies a default where the key is absent"* —
which is true of `New()` but not of the logout strip.

**Impact:** today, `vendorPrice` survives forever in every pre-upgrade entry while the database
reports itself as v2. That field is inert on the read paths (`Database:Export` filters it), so the
present cost is stale bytes plus a lying version stamp. The structural cost is the real one: **every
future migration is pre-disarmed by the same mechanism.** At v2→v3, users sitting on v2 will have
had the `2` stripped, will read the new default `3`, and the v2→v3 pass will not run either — for a
seam whose entire purpose is to be the one place that cannot be skipped (`savedvariables-§1`).

**Reachability:** every player upgrading across a schema bump who logged out at least once on the
previous version — i.e. all of them, on the ordinary upgrade path. Not Critical: no data is lost and
nothing user-visible breaks today.

**Fix direction:** the version stamp must not be a default. Remove `schemaVersion` from
`NS.defaults.global` and have `NS:RunMigrations` seed it explicitly — `if rawget(g,
"schemaVersion") == nil then g.schemaVersion = <the version a fresh install starts at> end` — or,
equivalently, key the runner off a sentinel AceDB will never inject. Keep the runner idempotent, and
keep it running before any read of `db.global.ledger` (`savedvariables-§1`). Note that the fix is
subtly *not* "read `rawget`" alone: a fresh install must still land on the current version rather
than replaying v1→v2 over an empty ledger, which is the requirement `defaults/Global.lua:8-13` was
written to satisfy.

---

### BANKLEDGER-R-03 — the case that pins `BANKLEDGER-R-02` is asleep: the local AceDB mock has no defaults  `[tests]`

`tests/test_database.lua:330` — *"RunMigrations treats a database with no schemaVersion key at all as
v1"* — sets `NS.db.global.schemaVersion = nil` and asserts the upgrade runs. It passes only because
`tests/wow_mock.lua:582-590` replaces the kit's AceDB fake with

```lua
libs["AceDB-3.0"] = {
  New = function(_, _name, defaults)
    return { global = deepcopy(defaults and defaults.global or {}), … }
```

— a plain deep copy with **no defaults metatable**, so an absent key reads `nil`. Under real AceDB it
reads the default `2` and the assertion fails. The case is a faithful statement of the intended
behaviour that the harness cannot falsify.

This is a downgrade of the shared kit, not a gap in it: `tests/_kit/mock_base.lua:278-324` ships an
AceDB fake that deliberately models "the awkward real behavior, not the convenient one" including
`copyDefaults` merge-in-place and a raw `db.sv`. The override at `wow_mock.lua:580-581` is justified
only by the fixed profile name (*"this one never [switches profiles], and its suite asserts against
that fixed name"*) — a reason that argues for pinning `GetCurrentProfile` on top of the base fake,
not for replacing it.

**Reachability:** the test inventory only; the shipped defect it fails to catch is
`BANKLEDGER-R-02`. Graded High because it is the direct cause of a real defect reaching a release
under a green gate, not for any behaviour of its own.

**Fix direction:** wrap the kit's AceDB fake rather than replacing it (the same "wrapped rather than
replaced" rule `wow_mock.lua:598-599` already states for AceGUI), and model the logout strip well
enough that a defaults-equal value disappears. Never weaken the case to match the mock.

---

## Medium

### BANKLEDGER-R-04 — no `OnDisable`, so a disable/re-enable leaves the capture engine permanently deaf  `[design]`

`modules/Ledger.lua:845-847`, `modules/Browser.lua:1226-1228` and `modules/SessionWindow.lua:654-656`
all latch on `self._enabled` and early-return. Nothing ever clears the latch: `core/BankLedger.lua`
defines `OnInitialize` and `OnEnable` and no `OnDisable`.

AceAddon's disable path runs `AceEvent:OnEmbedDisable`
(`libs/AceEvent-3.0/AceEvent-3.0.lua:112-115`), which calls `UnregisterAllEvents` on `NS`. The nine
bank events `L:Enable` registered on `NS.addon` are gone. A subsequent enable re-runs
`addon:OnEnable`, which re-registers its own three events but hits `if self._enabled then return end`
in `L:Enable` — so `BANKFRAME_OPENED`, `GUILDBANKFRAME_OPENED`, `BAG_UPDATE_DELAYED`,
`PLAYERBANKSLOTS_CHANGED`, `PLAYER_MONEY`, `GUILDBANKBAGSLOTS_CHANGED` and `ADDON_LOADED` never come
back, and the addon silently records nothing for the rest of the session.

**Reachability:** only a player or third-party addon manager that calls
`AceAddon:DisableAddon("BankLedger")` at runtime. No BankLedger UI, slash verb or settings row
reaches it, and Blizzard's own AddOns list requires a reload. Capped at Medium on that basis.

**Fix direction:** add `addon:OnDisable` that clears the three latches (and unhooks what `L:Enable`
hooked), so re-enable is a real re-arm rather than a no-op.

---

### BANKLEDGER-R-05 — `docs/automated-tests/RESULTS.md` narrative and watch list are two runs stale  `[docs]` `[complexity]`

The file's own header says its four narrative sections "describe the **current** state, as of the
newest run [`20260807-115101`]" — but its newest *table row* is `20260825-103400`, and today's tree
is further on again. Three concrete divergences from the fresh Step 0 run:

- **Test suite section** (`RESULTS.md:45-47`): "727 cases, all passing … The count has now held flat
  across three consecutive runs" and "the largest suite in the collection". Today: **831**, and the
  newest recorded row is 791. The "held flat" reading is now actively wrong — the count moved twice
  since.
- **Complexity watch list** (`RESULTS.md:112-121`): "The highest CCN measured anywhere in the tree is
  **15** … and **five** functions sit there … `ensureFrame` (`modules/SessionWindow.lua:441`),
  `I:Layout`, `accumulateItemTaxonomy`, `LT:UpdateHeaderArrows`, `L:GateReason`." Today's run:
  **four** at 15 — `I@505-551@modules/Insights.lua`, `accumulateItemTaxonomy@234-265@core/Database.lua`,
  `L@403-435@modules/Ledger.lua`, `LT@869-885@modules/LedgerTable.lua`. `ensureFrame` now measures
  **13** (`ensureFrame@439-562@modules/SessionWindow.lua`). The "no headroom on five functions"
  warning a reader budgets against is over-stated by one.
- **File band table** (`RESULTS.md:127-128`): `modules/Browser.lua` at 1358 LOC. Today: **1251** —
  the settings revamp took 107 lines out of it.

**Reachability:** a maintainer reading the record to decide where to spend a refactor; no runtime
effect. Stale is stale, not non-compliant — the bundles themselves are frozen and correct.

**Fix direction:** none here. The narrative sections move with the **next release run**
(`/wow-addon:bump-version` regenerates in place). Do not hand-edit numbers into the file — a
hand-edited report reads as measured (`performance-§10`).

---

### BANKLEDGER-R-06 — `docs/performance.md`'s exemption sweep cites a call site that has moved  `[docs]`

`docs/performance.md:39` names `` `core/Compat.lua` `LoadItem` `` → `C_Timer.After(0.4, cb)` as one
of the nine sites in the sweep that justifies the ratified `performance-§12` exemption. `LoadItem`
is no longer in `core/Compat.lua`: it moved to the LibKa0s-Item seam and now lives at
`core/ItemSetup.lua:64-67`, where the timer call is `C_Timer.After(0.4, cb)` on line 67.
`core/Compat.lua:15` even records the move.

Re-running the page's own prescribed sweep (`docs/performance.md:32`) today returns 19 hits across
`core/BankLedger.lua` (5), `core/ItemSetup.lua` (1), `modules/Browser.lua` (2), `modules/Ledger.lua`
(9) and `modules/SessionWindow.lua` (2) — same shape, one file renamed.

**Impact:** the page instructs the reader to re-run the grep and declares "the moment it grows a row
this page cannot explain, the exemption is over". A row that points at a file which no longer
contains it is exactly the state that makes that instruction unfollowable — the next reader has to
re-derive whether the exemption still holds.

**Reachability:** a maintainer or auditor verifying the exemption; no runtime effect. The exemption
itself is still sound — the work at the new location is unchanged.

**Fix direction:** repoint the row at `core/ItemSetup.lua`. Standards-compliant either way: the
exemption's substance does not move (`performance-§12`).

---

## Low

### BANKLEDGER-R-07 — `/bl test` reports a state change that did not happen  `[ux]`

`settings/Schema.lua:438-441`:

```lua
local on = NS.LedgerTable and NS.LedgerTable.ToggleTestMode
  and NS.LedgerTable:ToggleTestMode()
print("test mode " .. (on and "on" or "off"))
```

If `NS.LedgerTable` were absent the guard falls through and the verb prints `test mode off` — a
confirmation of an act that never ran, rather than a refusal. Contrast the sibling `session` verb
two rows up, which distinguishes its three outcomes properly.

**Reachability:** nobody in any shipping configuration — `modules/LedgerTable.lua` is unconditionally
in the TOC. This is a latent lie in a guard, not a live one.

**Fix direction:** make the guard say so, in the shape the `session` verb already uses.

---

### BANKLEDGER-R-08 — four working-tree line-ending stragglers under the CRLF pin  `[structure]`

`.gitattributes:26` pins `* text=auto eol=crlf` (correct for a client-bound repo, `line-endings-§2`),
with the `*.sh text eol=lf` carve-out present. `git ls-files --eol` reports four paths whose working
tree is LF against that pin: `tests/test_marks.lua`, `docs/media.md`,
`docs/revendor/2026-08-25/05_SUMMARY.md`, and `docs/revendor/2026-08-25/01_DELTA.md` (mixed).
`tests/_kit/run-automated-tests.sh` at LF is correct — that is the carve-out.

The index side is LF for all of them, which is right; only the checkout disagrees. One is a shipped
Lua file.

**Reachability:** a contributor whose next `git add` renormalises them, producing an unrelated diff.
No runtime effect. Recorded here as a **review observation** only — the authoritative rolled-up
straggler count belongs to `/wow-addon:standards-audit`.

**Fix direction:** `git add --renormalize .` in its own commit.

---

### BANKLEDGER-R-10 — a stub comment claims a member is reached that the degraded path cannot reach  `[naming]`

`settings/OptionsSetup.lua:180-181`: *"MasterControls is REACHED: settings/Schema.lua's
`S:ComposeMaster` runs it from this file's live arm below."* The stub member is defined at
`:189`; the `if not lib then … end` block ends with an unconditional `return` at `:214`, and
`NS.Schema:ComposeMaster(NS.Helpers)` is at `:227` — **after** it. So on the degraded path
`ComposeMaster` is never called and the stub's `MasterControls` is never invoked.

The consequence the same paragraph goes on to describe — Master-controls rows absent from
`NS.Schema.Schema` in a degraded install, so `/bl list`/`set`/`reset` cannot reach them — is correct,
but it follows from `ComposeMaster` not running at all, not from the stub returning `{}`.

**Reachability:** a comment; no runtime effect. Worth correcting precisely because this file's
comments are unusually load-bearing and the next reader will trust this one.

**Fix direction:** reword to "unreached on this path — `ComposeMaster` runs only on the live arm",
and keep the consequence paragraph, which stands.

---

### BANKLEDGER-R-11 — two files approaching a `layout-§1` boundary that the stale watch list does not show  `[complexity]`

Fresh `wc -l`: `tests/test_ledger.lua` **1478** (up from the 1402 the watch list records; 22 lines
from `layout-§1`'s 1500 split threshold) and `modules/Insights.lua` **992** (8 lines from entering the
1000–1500 on-notice band, and not on the list at all). `modules/Browser.lua` has moved the other way,
to 1251.

**Reachability:** a maintainer sizing the next change; no runtime effect. Neither file is over a
threshold today.

**Fix direction:** none now. `tests/test_ledger.lua` already carries its split seam in the watch
list's disposition ("Split by concern if it passes 1500"); note the two in the next release run's
analysis rather than acting pre-emptively.

---

## Upstream

### BANKLEDGER-R-09 — `[upstream]` vendored `DebugLog.lua` and `Pool.lua` diff against the LibKa0s working tree  `[upstream]`

Owning repo: **LibKa0s** (`/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s`).

`diff -rq libs/LibKa0s/ ../LibKa0s/LibKa0s/` reports `DebugLog.lua` and `Pool.lua` as differing.
They are **content-identical**: `diff <(tr -d '\r' < libs/LibKa0s/X.lua) <(tr -d '\r' <
../LibKa0s/LibKa0s/X.lua)` is empty for both. `file(1)` shows this repo's copies as *"with CRLF line
terminators"* and the LibKa0s working-tree copies as plain UTF-8 (LF), while its siblings there —
`Core.lua` among them — are CRLF. So the stragglers are on the **source** side: two files in the
LibKa0s working tree sitting at LF under that repo's own CRLF pin.

This is why the in-repo gate is green while the raw `diff` is not: `tests/test_vendor_sync.lua`
compares the working tree against `git show` at the tag with CR stripped, which is the correct
comparison and passes.

**Remediation — this is NOT a local edit.** Nothing under `libs/` is to be touched here. Renormalise
in the LibKa0s repo (`git add --renormalize .`), commit it there, and re-vendor the whole
`libs/LibKa0s/` folder into every consumer as its own commit if the payload's stored bytes change.
No LibStub minor bump is needed — no file content changes — which is exactly why this is Low and
why it must not be "fixed" by editing either checkout's vendored copy.

**Reachability:** every consumer's raw `diff -r` vendor-sync check reports two false differences,
in this repo and in each of the other eight. Nothing at runtime.

---

## Not findings (checked, clean)

Recorded so a later reader does not re-derive them:

- **Taint / protected APIs** — no `OnUpdate` handler anywhere; no protected call on a non-secure
  path; settings registration goes through `LibKa0s-Options-1.0`
  (`settings/Panel.lua:667,699`, guarded on `Settings.RegisterCanvasLayoutSubcategory`) and is eager
  at `OnInitialize` per `options-ui-§1`; the only `InCombatLockdown()` is
  `core/Util.lua:265`, on the visibility rule. No `setmetatable` on a widget. No secret-value
  sources (`C_UnitAuras`, `UnitCastingInfo`, `C_Spell.*`) are touched at all.
- **Deprecated APIs** — every legacy call is behind `core/Compat.lua` and already on the `C_*`
  form (`C_Container.GetContainerNumSlots`, `C_Item.GetItemInfo`).
- **Event registration** — in `OnEnable`, not `OnInitialize`; `BAG_UPDATE_DELAYED` rather than
  `BAG_UPDATE`; each registration isolated through `L:RegisterEventSafely`
  (`modules/Ledger.lua:838-843`) against retail's raise-on-unknown-name behaviour.
- **Single write path** — `NS.Schema:Set` is the seam and the panel reaches it through the
  descriptor (`settings/OptionsSetup.lua:52-55`). The direct `db.global` writes in
  `modules/Filters.lua`, `modules/Browser.lua` and `modules/SessionWindow.lua` are the
  `architecture-§5` carve-outs named in `defaults/Global.lua:18-30`, not bypasses.
- **Chat prefix** — every `print(` in the tree resolves to a file-scope `local print = NS.Print`;
  verified per file. No raw `print` escapes the `[BL]` tag.
- **COMMANDS ↔ README** — all 16 verbs in `NS.COMMANDS` (`settings/Schema.lua:407`) appear in the
  README table (`README.md:80-96`), and vice versa, including the two `debug` sub-verbs.
- **Marks** — `NS.Icon(...)` is used for the close, chevron, check, search and export controls;
  `media/` holds only logos and screenshots, nothing that duplicates
  `libs/LibKa0s/media/`. `tests/test_marks.lua` pins it.
- **Degraded-path tests** — genuinely load the addon with `libs/LibKa0s/*.lua` left out of the file
  list, with guard assertions ("the degraded arm still has the library — this case proves nothing").
  This is the shape `testing-§8` asks for, and it is done well.
- **Load lists** — `tests/run.lua:52` derives the addon's own files from the TOC via
  `Loader.tocFiles("BankLedger.toc")`; the LibKa0s list is spelled out in XML order and asserted
  against `LibKa0s.xml` by `tests/test_libka0s.lua`; the suite list is asserted against disk in both
  directions by `tests/test_harness.lua`. `testing-§9` satisfied.
