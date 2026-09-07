# Proposed changes — Ka0s Bank Ledger — 2026-09-07

Derived from `01_FINDINGS.md`. Standards cross-check **performed** against the Ka0s WoW Addon
Standard **v2.38.0 (2026-09-02)** (index + all 27 section files, fetched verbatim with `curl` to a
scratch path).

**No change in this document targets a path under `libs/` or `tests/_kit/`.**

---

## HLD — themes

### Theme A — a reset is a settings change, and must be announced like one

`BANKLEDGER-R-01`. This addon already has exactly one correct mechanism for "settings moved,
re-read them": the closed bus message `Ka0s_BankLedger_SettingsChanged`, which three modules
subscribe to on their own AceEvent targets (`architecture-§4`). Every per-row write announces itself
through it. The wholesale reset — the biggest settings change the addon can make — is the one write
path that does not.

The fix is one broadcast, not a list of things to refresh. That distinction is the whole point:
`Sl:ResetEverything` was deliberately rewritten *away* from "a purge, a schema walk, a filter-list
clear and two window carve-outs" (its own comment, `settings/Slash.lua:83-88`) because an
enumeration fails one release later when something new is stored beside the things it names. Adding
`NS.Ledger:RefreshUpvalues()` plus `NS.Browser:OnSettingsChanged()` plus
`NS.SessionWindow:OnSettingsChanged()` would rebuild exactly that enumeration in the notify half.

**Alternative considered and rejected:** have `RefreshUpvalues` read `NS.db.global.settings` on
every gate evaluation instead of caching. Rejected — the gate runs once per moved item and
`modules/Ledger.lua:50-51` documents the caching as an `events-frames-taint-§7` requirement.
Un-caching trades a correctness bug for a hot-path regression.

**Alternative considered and rejected:** have `Schema:Set` be the only writer, so the reset walks
rows. Rejected — that is the `CliResetAll` behaviour, and `options-ui-§12` plus the ratified
deviation row in `docs/ARCHITECTURE.md` require this act to be *wholesale*, not a schema walk.

### Theme B — the schema version stamp stops being an AceDB default

`BANKLEDGER-R-02`, `BANKLEDGER-R-03`. A migration runner whose input is a value AceDB is entitled to
inject and to strip is a runner that can be skipped without anyone writing a line of code. The stamp
has to be a value the store either holds or genuinely lacks.

Two halves, and they must land together: the production fix, and a harness that can see it fail.
Shipping the first without the second re-creates the exact situation that let this through — a green
gate over a mock that cannot express the failure.

**Alternative considered and rejected:** keep the default and switch the runner to
`rawget(g, "schemaVersion")`. Rejected as incomplete — `rawget` on an AceDB section reads the real
table, so it correctly returns `nil` for a stripped key, but it *also* returns `nil` on a genuinely
fresh install, which would replay v1→v2 over an empty ledger. That is the case
`defaults/Global.lua:8-13` exists to prevent. The fix has to distinguish "new store" from "stripped
key", which the default cannot do at all.

**Alternative considered and rejected:** carry the stamp in a separate SavedVariables global outside
AceDB. Rejected — `savedvariables` reserves the diagnostics-global carve-out for diagnostics, and a
second global for one integer is a worse trade than a seeded key.

### Theme C — a latch that is never cleared is not a lifecycle

`BANKLEDGER-R-04`. Three modules latch `_enabled` and the addon has no `OnDisable`. The latch is
correct (double-enable must not double-register); its missing counterpart is the defect.

### Theme D — the standing evidence catches up with the code it describes

`BANKLEDGER-R-05`, `BANKLEDGER-R-06`, `BANKLEDGER-R-11`. Two committed documents describe a tree that
has moved. One of them (`RESULTS.md`) is **regenerated at release and must not be touched here**; the
other (`performance.md`) is prose and is a normal edit.

### Theme E — comments that mislead

`BANKLEDGER-R-07`, `BANKLEDGER-R-10`. Two small precision fixes in files whose comments carry real
load-order and contract information, where a wrong sentence costs the next reader a re-derivation.

---

## Upstream change-set (lands in another repo — NOT here)

### U-1 — renormalise two files in the LibKa0s working tree  (`BANKLEDGER-R-09`)

- **Owning repo:** LibKa0s.
- **Files within the library:** `LibKa0s/DebugLog.lua`, `LibKa0s/Pool.lua`.
- **Fix:** those two working-tree files are LF under that repo's own `* text=auto eol=crlf` pin
  (`line-endings-§2`); every sibling in the folder is CRLF. Run `git add --renormalize .` there and
  commit.
- **Minor bump:** **none.** No file content changes — `diff` after `tr -d '\r'` is empty for both.
  A LibStub minor bump would be wrong here and would force nine pointless re-vendors.
- **Re-vendor commit in this addon:** only if the stored blobs actually move. They should not. If
  they do, re-vendor the **whole** `libs/LibKa0s/` folder as its own commit, in every consumer.
- **Explicitly not:** editing `libs/LibKa0s/DebugLog.lua` or `libs/LibKa0s/Pool.lua` in this repo.
  The next whole-folder copy reverts it, and the reversion appears in no commit anyone can find.

---

## LLD — change-set

### C-1 — `Sl:ResetEverything` broadcasts on the bus  (covers `BANKLEDGER-R-01`)

- **File:** `settings/Slash.lua`, `Sl:ResetEverything` (currently lines 92-103).
- **Change:** after the defaults are merged back and before the window resets, send the settings
  message once.

```lua
   for k, v in pairs(deepcopyGlobal(NS.defaults and NS.defaults.global or {})) do g[k] = v end
 end
+-- One broadcast, never an enumeration. The wipe above replaced every table the Ledger's hot-path
+-- upvalues alias (DB_EXCLUDED, DB_BLACKLIST, DB_WHITELIST) and every scalar they cached, so the
+-- three subscribers must re-read from the store that exists now. Announced on the bus the
+-- per-row writes already use (architecture-§4), so a module added later is covered by
+-- subscribing rather than by someone remembering to extend a list here.
+if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "resetEverything") end
 print("this addon reset to defaults.")
```

- **Placement note:** *inside* nothing — at function scope, after the `if db and db.global then …
  end` block, so a call with no database still reaches the window resets unchanged.
- **Payload:** the existing sites pass a reason string (`"enabled"`, `"quality"`, `"stores"`, …).
  Match that shape with `"resetEverything"`; no subscriber reads the argument today, so it is for
  the debug trace only.
- **Risk:** `B:OnSettingsChanged` and `SW:OnSettingsChanged` now run before `NS.Browser:ResetWindow`
  / `NS.SessionWindow:ResetWindow` in the same call. Both are idempotent re-reads of the store; the
  ordering to *avoid* is the reverse (reset geometry, then have a handler re-apply a stale scale).
  Confirm in `03_SMOKE_TESTS.md` T-1.
- **Regression pressure on the suite:** this **adds** at least two cases and therefore moves the
  pass count. `docs/test-cases.md` and the README `[Tests]` badge must move in the **same** change
  (`testing-§7`), via `lua5.1 tests/run.lua --list > docs/test-cases.md` — never by hand.
  - *"ResetEverything re-arms the capture gate rather than leaving it on pre-reset settings"* —
    set `settings.enabled = false`, run `ResetEverything`, assert the Ledger's gate now permits.
    `-- red under: deleting the SendMessage line.`
  - *"ResetEverything's cleared filter lists stop being enforced immediately"* — blacklist an id,
    run `ResetEverything`, assert a movement of that id is now recorded. This is the case that
    catches the *table-identity* half, which a scalar-only assertion would miss.
    `-- red under: refreshing scalars only.`
- **Standards conformance:** `architecture-§4` (closed bus, per-consumer targets — unchanged),
  `options-ui-§12` (the act stays wholesale; its blast radius is untouched, so the ratified
  deviation row in `docs/ARCHITECTURE.md` needs no edit), `events-frames-taint-§7` (the hot-path
  upvalue caching is preserved, not removed). The rejected "read the DB per gate evaluation"
  alternative would have broken `events-frames-taint-§7`.

### C-2 — the schema stamp leaves the defaults table  (covers `BANKLEDGER-R-02`)

- **Files:** `defaults/Global.lua` (remove the key), `core/Database.lua` (`NS:RunMigrations`).
- **Change:**

```lua
-- defaults/Global.lua — the key is REMOVED from NS.defaults.global entirely.
-- Replace the current comment block with one that says why: AceDB strips a stored value equal to
-- its default at PLAYER_LOGOUT (AceDB-3.0's logoutHandler -> RegisterDefaults(nil) ->
-- removeDefaults), so a version stamp declared as a default is a stamp the runner cannot read
-- back after any logout. The stamp is seeded by the runner instead.
```

```lua
-- core/Database.lua — NS:RunMigrations
 local g = NS.db and NS.db.global
 if not g then return end
-g.schemaVersion = g.schemaVersion or 1
+-- A store that has never been stamped is one of two things, and they need opposite treatment:
+-- a FRESH install (nothing to migrate — start at the current shape) or a pre-stamp database
+-- (v1 — migrate it). `ledger` is the discriminator: an empty store has nothing a migration
+-- could touch, so seeding it at NS.SCHEMA_VERSION is both correct and a no-op either way.
+if g.schemaVersion == nil then
+  g.schemaVersion = (g.ledger == nil or next(g.ledger) == nil) and NS.SCHEMA_VERSION or 1
+end
 if g.schemaVersion < NS.SCHEMA_VERSION then
```

- **Why the discriminator rather than `rawget`:** `rawget` distinguishes "stored" from "defaulted",
  but after C-2 there is no default to distinguish from — the key is simply absent on both a fresh
  install and a stripped one. The ledger's emptiness is the only signal that separates them, and it
  is the right one: a migration over an empty ledger is definitionally a no-op, so mis-classifying a
  fresh install as v1 would cost a wasted walk, not a wrong result. Choosing `NS.SCHEMA_VERSION` for
  the empty case preserves `defaults/Global.lua`'s original intent ("a fresh install starts at the
  current shape instead of replaying the v1->v2 pass over an empty ledger") without the default.
- **Idempotence:** preserved. A second run finds the stamp at `NS.SCHEMA_VERSION` and does nothing.
- **Ordering:** unchanged — still invoked from `NS:InitDB` before any read of `db.global.ledger`.
- **Risk:** a user whose v1 database is *empty* is stamped straight to v2 without the strip pass.
  That is correct by construction (no entries, no `vendorPrice`) and is worth a test.
- **Suite movement:** at least three cases, so `docs/test-cases.md` and the badge move with it.
  - *"a stamp-less store with entries is treated as v1 and migrated"* — `red under:` seeding
    unconditionally at `NS.SCHEMA_VERSION`.
  - *"a stamp-less EMPTY store is stamped current without replaying v1->v2"* — `red under:` seeding
    unconditionally at 1.
  - *"schemaVersion is not declared in NS.defaults.global"* — the case that stops the key being
    reinstated by a future defaults edit. `red under:` putting it back.
- **Standards conformance:** `savedvariables-§1` — the runner stays a single idempotent upgrade
  path invoked once at init, before any ledger read; only its *input* changes. No new deviation.
  `toc-file-§2`'s version-stamp requirement is still met, by a stored value rather than a defaulted
  one. The rejected "second SavedVariables global" alternative was declined against
  `savedvariables`' diagnostics-global carve-out, which is not a general licence for extra globals.

### C-3 — the local AceDB fake wraps the kit's instead of replacing it  (covers `BANKLEDGER-R-03`)

- **File:** `tests/wow_mock.lua` (Override 5, currently lines 580-590).
- **Change:** keep the base's AceDB fake and pin only what is genuinely per-addon.

```lua
-- Override 5. Account-wide addon: created in-game with defaultProfile = true, so the profile is
-- always the fixed "Default", and this suite asserts against that fixed name.
--
-- WRAPPED, NOT REPLACED — the same rule Override 11 states for AceGUI, and it matters more here.
-- The copy this replaces was `global = deepcopy(defaults.global)`: a plain table with no defaults
-- metatable, under which an absent key reads nil. Real AceDB reads the DEFAULT, which is what let
-- tests/test_database.lua's stamp-less-database case pass while the shipped code skipped the
-- migration (BANKLEDGER-R-02). A mock that cannot express the failure is a mock that certifies it.
local baseNew = libs["AceDB-3.0"].New
libs["AceDB-3.0"].New = function(self, name, defaults, ...)
  local db = baseNew(self, name, defaults, ...)
  db.GetCurrentProfile = function() return "Default" end
  return db
end
```

- **Follow-on:** the kit's base fake models `copyDefaults` merge-in-place and exposes `db.sv`
  (`tests/_kit/mock_base.lua:278-324`). If it does **not** model the `PLAYER_LOGOUT` default-strip,
  that gap is a **`[upstream]` LibKa0s testkit** item, not a local addition: raise it there, and in
  the meantime express the strip inside the *case* (delete the key from `db.sv.global` and let the
  metatable answer) rather than by re-forking the fake here.
- **Risk:** other cases in the suite may lean on the naive fake's flat-table behaviour. Expect
  collateral failures on the first run; each one is information about what the old mock was hiding.
  Fix the cases, never the assertion.
- **Standards conformance:** `testing-§8` — the addon keeps integration coverage over its own wiring
  and stops re-forking a shared fake. **Explicitly rejected:** relaxing
  `tests/test_database.lua:330` to match the mock. Weakening the test that caught it is not a remedy.

### C-4 — `addon:OnDisable` clears the enable latches  (covers `BANKLEDGER-R-04`)

- **File:** `core/BankLedger.lua`, beside `OnEnable`.
- **Change:**

```lua
-- AceAddon's disable path runs AceEvent:OnEmbedDisable, which UnregisterAllEvents on NS — so
-- every bank event modules/Ledger.lua registered on this object is gone. Without clearing the
-- latches, a subsequent Enable hits `if self._enabled then return end` and the capture engine
-- never re-arms: the addon silently records nothing for the rest of the session.
function addon:OnDisable()
  for _, m in ipairs({ NS.Ledger, NS.Browser, NS.SessionWindow }) do
    if m then m._enabled = nil end
  end
end
```

- **Note on the list:** this *is* an enumeration, and unlike C-1's it is the right shape — it names
  the three modules that own a latch, which is a fact about this file's own `OnEnable` two lines
  above, not about what happens to be stored somewhere.
- **Also check during implementation:** `L:HookGuildBankFrame`'s `L._guildHooked` latch. If the hook
  survives a disable (it is a `hooksecurefunc`-style install, not an event), leaving `_guildHooked`
  set is correct and the re-enable must not re-hook. Verify before touching it — a double hook is a
  worse bug than the one being fixed.
- **Suite movement:** one case — *"a disable followed by an enable re-arms the capture engine"* —
  so the inventory and badge move.
- **Standards conformance:** `architecture` module lifecycle. No new deviation.

### C-5 — `docs/performance.md` repoints the moved sweep row  (covers `BANKLEDGER-R-06`)

- **File:** `docs/performance.md`, the sweep table row currently reading
  `` | `core/Compat.lua` `LoadItem` | ``.
- **Change:** `core/Compat.lua` → `core/ItemSetup.lua` (the call is `core/ItemSetup.lua:67`). The
  "Work while in combat" cell is unchanged — the behaviour did not move, only the file.
- **Risk:** none. Documentation only.
- **Standards conformance:** `performance-§12` — the exemption's substance is untouched; this
  restores the page's ability to be re-verified by its own prescribed grep.

### C-6 — two comment corrections  (covers `BANKLEDGER-R-07`, `BANKLEDGER-R-10`)

- **`settings/OptionsSetup.lua:180-181`:** replace *"MasterControls is REACHED: settings/Schema.lua's
  S:ComposeMaster runs it from this file's live arm below"* with a statement that it is **not**
  reached on this path — `ComposeMaster` is called at `:227`, after the stub arm's `return` at
  `:214`. Keep the consequence paragraph verbatim; it is correct and valuable.
- **`settings/Schema.lua:438-441`:** make the `test` verb distinguish "toggled" from "unavailable",
  in the shape the `session` verb two rows above already uses, so the guard cannot print a
  confirmation for an act that did not run.
- **Risk:** none for the comment. The verb change is one branch; the existing
  `tests/test_slash.lua` coverage of `/bl test` should be extended rather than replaced.
- **Standards conformance:** `slash-commands-§3` — a verb's chat response must describe what
  happened.

### C-7 — line-ending renormalisation  (covers `BANKLEDGER-R-08`)

- **Files:** `tests/test_marks.lua`, `docs/media.md`, `docs/revendor/2026-08-25/01_DELTA.md`,
  `docs/revendor/2026-08-25/05_SUMMARY.md`.
- **Change:** `git add --renormalize .`, **in its own commit**, so it never lands mixed with a
  content change where the diff would be unreadable.
- **Standards conformance:** `line-endings-§2`. The `.gitattributes` itself is already correct —
  the CRLF pin, the `*.sh text eol=lf` carve-out and the binary markings are all present.

---

## Not proposed, deliberately

- **Regenerating `docs/automated-tests/RESULTS.md`** (`BANKLEDGER-R-05`). Its checkpoint is
  **release** — `/wow-addon:bump-version` regenerates it in place from a fresh run. Hand-editing the
  727/791/831 numbers or the watch list would make a measured document read as measured while being
  typed (`performance-§10`). C-1 through C-4 will move the pass count and should move
  `accumulateItemTaxonomy` / `L:GateReason` / `LT:UpdateHeaderArrows` not at all, and may add a
  function or two to `settings/Slash.lua` and `core/Database.lua` — **expected direction: no new
  CCN-15 function, one or two new low-CCN functions.** That is a note for the next release run to
  confirm, not a task to run `lizard` now.
- **Splitting `tests/test_ledger.lua` or `modules/Insights.lua`** (`BANKLEDGER-R-11`). Neither is
  over a `layout-§1` threshold today. Splitting pre-emptively relocates decisions without removing
  any.
- **Any edit under `libs/` or `tests/_kit/`.** See the upstream change-set.
- **Adding `tests/perf.lua` or `docs/perf-analysis/`.** The `performance-§12` no-combat-path
  exemption is ratified in `docs/ARCHITECTURE.md` and evidenced in `docs/performance.md`. Wiring a
  harness whose every declared bucket would read `0.000` is what `performance-§3` calls a lie in
  every report.
