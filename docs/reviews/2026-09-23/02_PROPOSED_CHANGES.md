# Proposed changes: Ka0s Bank Ledger, 2026-09-23

**Standard resolved:** Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**. It was fetched verbatim with `curl` from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`: the index plus every section file it links. The section files were cross-checked byte-for-byte against the local clone at `e68795f`. The standards cross-check **ran**, and every change below was vetted against it as a constraint on remediation. This is not an audit.

## HLD: themes

### T1. The stand-down owns the capture context (F-001)

**What:** The capture context is the open storage frame, its baseline snapshot, the settle deadline and the live banking session. It becomes one more thing `NS.StandDown` stands down. The change is a **single new step inside the existing body**, reached through one new Ledger member, `L:DropContext()`.

**Why:** `slash-commands-§7` requires that "disabled" stops writing. Today the next stand-up resumes a diff against a baseline taken before the player switched the addon off, and that writes rows for the disabled period. It also leaves the context armed after the bank closes. That is the exact premise `docs/performance.md` says ends the `performance-§12` exemption: a bag event triggering a full scan away from the bank.

**Alternatives considered:**

- **Flush with `L:CloseContext()` instead of dropping.** This would record the in-flight debounced pass (movements made *while still enabled*) and then disarm. **Rejected.** It writes SavedVariables from inside the stand-down. It also only works because of an ordering subtlety: `DB_ENABLED` is still `true` at that moment only because `settings/Schema.lua:224-225` releases the hold *before* broadcasting `SETTINGS_CHANGED`. A future reorder would silently turn the flush into a gate-skip. What it gives up is at most one debounce window (0.35 s) of a movement made the instant before disabling. That is acceptable, and the player caused it.
- **Re-arm on stand-up if a bank frame is visibly open.** This would be the symmetric fix, but it needs a reliable "is the bank frame shown" probe per context. It is **deferred as a follow-up**, not required: after this change a re-enable at the bank is simply unarmed until the next open, which is the conservative failure.
- **A separate `Ledger:StandDown` called from the Lifecycle descriptor.** **Rejected.** That would be a second teardown path, the parallel-lifecycle anti-pattern that `slash-commands-§7` names. The step belongs inside the one `NS.StandDown` body that both arms (the latch and `OnDisable`) already reach.

**Trade-off:** none worth recording beyond the lost 0.35 s described above.

### T2. The global reset is a fresh install, including the latch and the ledger announcement (F-002, F-003)

**What:** `Sl:ResetEverything` gains two calls after its in-place wipe. The first, `NS.Database:FireLedgerChanged()`, announces the ledger that was just emptied. The second, `NS.ReevaluateEnabled()`, re-runs the latch decision against the restored `settings.enabled = true`.

**Why:** `options-ui-§12` translates the global reset for a global-only addon as "indistinguishable from a fresh install". A fresh install is running and shows an empty ledger. The profile-reset form of the same rule reaches the host's profile handler, and here that is `NS.ReevaluateEnabled`, which is already wired to `OnProfileReset` in `core/Database.lua:18-23`. `slash-commands-§7` requires that re-evaluation whenever the stored switch can change under the addon.

**Alternatives considered:**

- **Write `settings.enabled` through `NS.Schema:Set` after the wipe.** **Rejected.** It logs a per-row `[Set]` line beside the act's one summary line (`debug-logging-§10`), and it treats one row specially inside a reset that is deliberately *not* a key list (`options-ui-§12`: "MUST NOT enumerate the keys to clear").
- **Fire `LEDGER_CHANGED` directly from `settings/Slash.lua` with `NS.bus:SendMessage`.** **Rejected** because it breaks `architecture-§4`'s one-sender-per-message invariant. `Database:FireLedgerChanged` exists for exactly this case.

### T3. Documentation matches the code (F-004, F-006, F-007, F-010)

- The README discloses the 30-day default retention.
- The exemption sweep's "No allocation" is made true in code, not in prose.
- Line-number citations in prose become symbol citations, so they cannot rot again.
- The brand name has one spelling.

**Owner decision recorded, not prescribed:** whether `retentionDays` should default to `0` ("Always").

- **For:** a "passbook of every movement" that forgets after a month surprises people.
- **Against:** unbounded SavedVariables growth. The panel shows an estimated size, so the cost is visible.
- **Consequence to note:** AceDB strips a stored value equal to its default at logout, so a player who never touched the dropdown is stored as "absent". Changing the default to `0` therefore silently moves them to "Always". That is the safe direction, since it keeps more data, and it needs **no migration** (`savedvariables-§1`).

### T4. Small correctness and hygiene items (F-005, F-008, F-009)

- The guild-bank open/close verification is left to the client.
- The watch-list movements are noted for release.
- The prune latch moves into its timer.

## Upstream change-set

**None.** No defect was found in `libs/LibKa0s/` or `tests/_kit/`, and both are byte-identical to `../LibKa0s` today. No entry below touches either path.

## LLD: change-set per finding

### C-01: Drop the capture context on stand-down (F-001)

**`modules/Ledger.lua`:** add below `L:CloseContext` (currently `:803-815`):

```lua
--- The stand-down's half of the capture engine (slash-commands-§7). NOT CloseContext: nothing is
--- reconciled and nothing is written. The baseline predates the switch, and a later stand-up that
--- diffed against it would record movements made while the addon was off. Ends the session over
--- the bus so the session window, whose target is still subscribed at this point, closes its visit.
function L:DropContext()
  local context = NS.State.openContext
  self:CancelPendingReconcile()
  NS.State.openContext, NS.State.lastSnapshot, L._settleSince = nil, nil, nil
  if context then fireSessionChanged(false, context) end
end
```

**`core/BankLedger.lua` `NS.StandDown` (`:146-191`):** insert a step between the current step 3 (`RefreshUpvalues`, `:168`) and step 4 (bus targets, `:171`). The session message must go out while `SessionWindow`'s private target still exists:

```lua
  -- 3b. THE CAPTURE CONTEXT. An open storage frame's baseline is state, not a registration, and
  --     UnregisterAllEvents cannot reach it: left behind, the next stand-up diffs against a
  --     snapshot taken before the switch and records what moved while the addon was off.
  if NS.Ledger and NS.Ledger.DropContext then NS.Ledger:DropContext() end
```

**Risk:** `fireSessionChanged(false)` → `SW:EndSession` → `SW:Hide()`, which is harmless because step 5 hides it anyway. The `GuildBankFrame` `OnHide` hook is gated on `IsStoodDown()`, so it cannot double-close.

**Tests** (`tests/test_disabled.lua`), each carrying a `-- red under:` comment per `testing-§12`:

1. "disabled: a stand-down with a bank open drops the context, and a deposit made while disabled is never recorded". Open `BANK_FRAME`, disable through the write seam, move stock, enable, reconcile, then assert the ledger count is unchanged and `openContext == nil`. `-- red under: removing step 3b from NS.StandDown.`
2. "disabled: the stand-down ends an open banking session". Assert `NS.State.sessionActive == false` after the disable. `-- red under: DropContext clearing the fields without firing SessionChanged.`

**Standards:** `slash-commands-§7` (*What MUST stand down*: the stand-down happens in the same turn as the write, and no second teardown path), `performance-§6` (stand-up rebuilds from current state; there is nothing to snapshot), `testing-§12`.

**Test movement:** +2 cases, 1017 → 1019. `docs/test-cases.md` and the README `[tests]` badge **move in the same commit** (`testing-§7`).

### C-02: `ResetEverything` re-runs the latch and announces the wiped ledger (F-002, F-003)

**`settings/Slash.lua` `Sl:ResetEverything` (`:161-197`):** after the existing `SETTINGS_CHANGED` send (`:195`) and before `refreshAfterReset()` (`:196`):

```lua
  -- The ledger was just emptied with the rest of db.global. Database is this message's one sender
  -- (architecture-§4), so the announcement goes through it: History, Insights, the session list and
  -- the storage read-out all refresh on LedgerChanged and on nothing else.
  if NS.Database and NS.Database.FireLedgerChanged then NS.Database:FireLedgerChanged() end
  -- A fresh install is ENABLED (options-ui-§12). The wipe restored `settings.enabled = true` without
  -- running the row's onChange, so re-run the latch decision exactly as OnProfileReset does
  -- (slash-commands-§7) -- a no-op when the addon was already up.
  if NS.ReevaluateEnabled then NS.ReevaluateEnabled() end
```

**Ordering note:** `ReevaluateEnabled` → latch release → `NS.StandUp` → `Ledger:Enable` → `RefreshUpvalues`, which reads the restored settings. The panel repaint in `refreshAfterReset` then shows the correct state.

**Risk:** when the addon was already enabled, `ReevaluateEnabled` is edge-only and does nothing. When it was disabled, the reset now brings it back up. That is a **behavior change**: the confirm text already promises "Reset this addon to its defaults", and enabled is the default. It is listed under API/behavior changes in `05_FINAL_SUMMARY.md`.

**Tests** (`tests/test_panel.lua`):

1. "Slash: ResetEverything while disabled stands the addon back up". Disable, reset, then assert `IsDisabled() == false` and that the registration set is non-empty. `-- red under: dropping the ReevaluateEnabled call.`
2. "Slash: ResetEverything announces LedgerChanged exactly once". `-- red under: dropping the FireLedgerChanged call, or sending it per key.`

**Standards:** `options-ui-§12` (global-only translation), `slash-commands-§7` (re-evaluate on profile callbacks, and nothing takes the hold by another route), `architecture-§4`, `debug-logging-§10` (still one `[Set]` line per act).

**Test movement:** +2, cumulative 1019 → 1021.

### C-03: Disclose default retention (F-004)

**`README.md`:** add a FAQ row. Suggested text: "Does it keep my history forever? — Not by default: movements older than 30 days are removed at login. Change it in Settings ▸ History ▸ Keep history for; 'Always' keeps everything. Export first if you are shortening it." Optionally add one sentence in the prose section near `/bl purge` (README `:92`).

**Owner decision (optional):** change `defaults/Global.lua:47` and `settings/Schema.lua:118` to `0`. This needs no migration (see T3), and the README row would change to match.

**Standards:** `documentation` (README is player-facing). No deviation is introduced.

**Test movement:** none, unless `tests/test_docs.lua` asserts README structure. Run the gate.

### C-04: Allocation-free visibility pass (F-006)

**`core/Util.lua:274-288`:** replace the per-call table literal with a module-level name list:

```lua
local VISIBILITY_OWNERS = { "Browser", "SessionWindow" }   -- NS[key] resolved at call time
function Util.ApplyVisibility()
  local allowed = Util.VisibilityAllows()
  local hidden = NS.State.hiddenByVisibility
  for _, key in ipairs(VISIBILITY_OWNERS) do
    local owner = NS[key]
    ...
```

Do the same for `ApplyMasterChrome` (`:239-244`) with `{ "Browser", "SessionWindow", "Export" }`.

**Behavior change:** none. Iteration order becomes deterministic, which is strictly better than `pairs`. No dispatch or defaults table is moved *into* the function (anti-pattern #52 does not apply).

**`docs/performance.md:46`** now becomes true as written. No prose change is needed beyond keeping the sweep current.

### C-05: Symbol citations instead of line numbers (F-007)

**`docs/ARCHITECTURE.md:378,379,384,504`** and **`core/Database.lua:579-581`:** replace `file:line` with `file` plus the symbol:

- ``core/BankLedger.lua` `NS.StandUp``
- ``modules/Browser.lua` `B:Enable``
- ``modules/Browser.lua` `B:MakeCloseButton``
- ``tests/test_ledger.lua` "undo a recorded row"`

Also correct "each window's own event frame" to "each window module's private bus target".

**Standards:** `documentation`. This is a pure doc/comment edit.

### C-06: One brand spelling (F-010)

- `core/LauncherSetup.lua:163`: change to `tt:AddLine(NS.BRAND_NAME, 1, 0.82, 0)`.
- `settings/OptionsSetup.lua:24`: change to `local PARENT_TITLE = NS.BRAND_NAME`. `core/LauncherSetup.lua` loads before `settings/` in the TOC, so the constant exists at file scope.

The rendered bytes do not change. `launcher-§1` is unaffected, because the label already uses `NS.BRAND_NAME`.

### C-07: Latch the prune inside its timer (F-009)

**`core/BankLedger.lua:216-228`:**

```lua
function addon:OnEnterWorld()
  if NS.State.cleanupDone or NS.State.cleanupPending then return end
  NS.State.cleanupPending = true
  if C_Timer and C_Timer.After then
    C_Timer.After(5, function()
      NS.State.cleanupPending = nil
      if NS.IsStoodDown and NS.IsStoodDown() then return end   -- retry on the next PEW
      NS.State.cleanupDone = true
      if NS.Database and NS.Database.PruneOld then NS.Database:PruneOld() end
    end)
  end
end
```

Add `cleanupPending` to `core/State.lua` with a comment. The body stays gated on the latch, so there is still no write from a game event while disabled (`slash-commands-§7`).

**Test:** +1 case in `tests/test_disabled.lua` or `tests/test_database.lua`: "a stand-down inside the prune window postpones rather than cancels retention". Cumulative 1021 → 1022.

### C-08: Guild-bank open/close events, verify then adopt or drop (F-005)

**Step 1, in client:** with `/etrace` open, open and close the guild vault on 12.1. Record whether `GUILDBANKFRAME_OPENED`/`_CLOSED` and `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`_HIDE` fire, and with what argument. The checklist step is in `03_SMOKE_TESTS.md`.

**Step 2, outcome-dependent:**

- **If PIM fires with `Enum.PlayerInteractionType.GuildBanker`:** add it through `RegisterEventSafely` with a type filter, driving `OpenContext(GUILD_BANK)` and `CloseContext()`. Keep the `HookScript` path as the backstop, gated as today. Remove the two dead names, and update `docs/ARCHITECTURE.md`'s registration count and `docs/performance.md`'s sweep row in the same commit.
- **If nothing new fires:** remove `GUILDBANKFRAME_OPENED`/`_CLOSED` from `OPEN_EVENTS`/`CLOSE_EVENTS`, adjust the counts, and keep the hooks.

**Standards:** `events-frames-taint` (register in the enable path), `performance-§12`'s sweep table (must stay current: this commit edits it).

### C-09: Watch-list movements, a note for release (F-008)

No change now. The next `/wow-addon:bump-version` regeneration should:

- produce a new band row for `modules/Insights.lua` (1002, **blank Disposition**), which the owner rules on: accept it, or name the peel seam (the `I:Layout` section renderers are the obvious one);
- carry `modules/Browser.lua` 1220 under `BL-24`, with the "moving the right way" note corrected;
- report tests at 1022 if C-01, C-02 and C-07 land.

Never regenerate this into the repo outside release, and never gate commits on it (`automated-tests-§3`, `performance-§10`).

## Standards conformance summary

| Change | Rules that shaped it | Rejected option, and the rule it broke |
|---|---|---|
| C-01 | slash-commands-§7, performance-§6, testing-§12 | A second `Ledger:StandDown` teardown (parallel lifecycle, slash-commands-§7); a flush that writes SV inside the stand-down |
| C-02 | options-ui-§12, slash-commands-§7, architecture-§4, debug-logging-§10 | A row-specific `Schema:Set` inside the wholesale reset (options-ui-§12, debug-logging-§10); a direct bus send from Slash (architecture-§4) |
| C-03 | documentation | none |
| C-04 | performance-§12 (keeps the sweep true), anti-patterns #52 | none |
| C-05 | documentation | none |
| C-06 | launcher-§1 | none |
| C-07 | slash-commands-§7 | none |
| C-08 | events-frames-taint, performance-§12 | none |
| C-09 | automated-tests-§3/§4, performance-§10 | a commit-time complexity gate (documented anti-pattern) |

None of these changes introduces a new deviation. None touches `libs/` or `tests/_kit/`. None proposes editing or weakening an existing test.
