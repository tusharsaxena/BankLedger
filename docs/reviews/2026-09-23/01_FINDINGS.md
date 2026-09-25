# Review findings: Ka0s Bank Ledger, 2026-09-23

**Verdict: minor issues.** No blocking or Critical defects. There are two High stand-down/reset bugs, and both reproduce headlessly. A player with a normal install reaches them through documented surfaces. They are narrow in reach, but one of them writes ledger rows for movements the player made while the addon was switched off.

Reviewed at `3256d8c` on branch `feat/2026-09-23-review-audit-remediation`, against Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**. The standards cross-check ran; see `02_PROPOSED_CHANGES.md`.

## Measurement run (Step 0, re-run from scratch today)

Every run went through `~/.claude/wow-addon/bin/ka0s-bounded`. It is not on `PATH` in this shell, so it was invoked by its absolute path and the `timeout 900` fallback was not needed. All scratch output went to the session scratchpad (`…/scratchpad/BL/`). Nothing was written into the repo except this bundle.

| Suite | Result | Command (from repo root) |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 71 files | `ka0s-bounded luacheck .` |
| Headless test suite | **pass**: 1017 passed, 0 failed, 0 skipped, 1017 total | `ka0s-bounded lua5.1 tests/run.lua` |
| Test-case inventory | **ran**. Byte-identical to the committed `docs/test-cases.md` after CR-normalisation. README badge reads `1017/1017`, which agrees. | `ka0s-bounded lua5.1 tests/run.lua --list > $SCRATCH/test-cases.md` |
| Offline perf runner | **skipped**: no `tests/perf.lua`. This follows from the ratified `performance-§12` no-combat-path exemption (`docs/performance.md`). It is not a pass. | `ka0s-bounded lua5.1 tests/perf.lua` → `cannot open tests/perf.lua` |
| Complexity | **ran**: 0 warnings. Max CCN 15, NLOC 17397, 2640 functions, avg CCN 2.0 | `ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" . > $SCRATCH/complexity.txt` |
| `make test` | **skipped**: no root `Makefile` | n/a |
| Vendor sync | **pass**: `libs/LibKa0s/` is identical to `../LibKa0s/LibKa0s/`, and `tests/_kit/` is identical to `../LibKa0s/testkit/`. Both `diff -rq` runs exited 0. | `diff -rq libs/LibKa0s/ ../LibKa0s/LibKa0s/` ; `diff -rq tests/_kit/ ../LibKa0s/testkit/` |
| Cross-addon: slash tokens | **clean**: 20 roots across 10 addons (the nine plus AuraMaster), zero duplicates, zero raw `SLASH_*` in any TOC-loaded file | the two loops in the agent brief, run from the parent directory, scoped to each addon's TOC-derived load list |
| Cross-addon: vendored minors | **clean**: one line for all 10. `Bus:1 Compat:1 Core:7 DebugLog:12 Env:1 Item:1 Launcher:1 Lifecycle:1 Media:3 Options:23 Perf:12 Pool:3 Schema:1 Slash:14 Widgets:9` | `grep -rhoE 'local MAJOR, MINOR = …' <addon>/libs/LibKa0s` |
| Cross-addon: payload bytes | **clean**: `diff -rq BankLedger/libs/LibKa0s <addon>/libs/LibKa0s` is silent for all 10. BankLedger was the reference. The two PrettyChat CR stragglers in the baseline are gone. | as briefed |
| Cross-addon: `## Interface:` | **clean**: `120100` in all 10 | `grep -h '^## Interface:' */*.toc \| tr -d '\r' \| sort -u` |

**The cross-addon pass departs from the 2026-09-07 baseline only in expected ways, so it produced no finding.** The minors have moved uniformly: Options 14→23, Perf 7→12, Slash 7→14, Widgets 9, plus the new majors Bus, Compat, Launcher, Lifecycle and Schema. `## Interface:` moved uniformly from `120007` to `120100`. There are now ten addons, because AuraMaster is included. Every class is still one line and none collides.

**Where committed artifacts disagree with today's run:**

- **`docs/automated-tests/RESULTS.md`** is stale against today. Its newest run `20260916-184426` (sha `076f674`, v1.1.0) records 943/0/943 tests, NLOC 16380 and 2498 functions. Today's run gives 1017 tests, NLOC 17397 and 2640 functions. Its band table is missing `modules/Insights.lua` (1002 LOC today), and it records `modules/Browser.lua` at 1208, which is 1220 today. See F-008.
- **`docs/test-cases.md`** agrees with the fresh `--list` output.
- **`docs/performance.md`** contains no measured numbers, because the addon is exempt. Its sweep table makes one claim about the code that the code contradicts (F-006).

**LOC census** uses the default scope: tracked, authored Lua, excluding `libs/` and `tests/_kit/`, with `tests/` included. Command: `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | tr '\n' '\0' | xargs -0 wc -l`. Result: 0 files over 1500. Four files are in the 1000–1500 band: `modules/Browser.lua` 1220, `modules/LedgerTable.lua` 1132, `tests/test_ledger.lua` 1028 and `modules/Insights.lua` 1002.

**Line endings** are an observation only, per `line-endings-§2`. `.gitattributes` carries `* text=auto eol=crlf`, `*.sh text eol=lf` and the binary set. A per-file CR-vs-LF count over `git ls-files`, skipping binaries, found zero stragglers.

**Headless repro** for F-001 and F-002. The script is `$SCRATCH/repro.lua`. It loads the addon the same way `tests/run.lua` does and was run with `ka0s-bounded lua5.1`. Its output:

```
before disable: count 0  ctx BANK_FRAME
after disable: stoodDown true  ctx BANK_FRAME  snapshot true
after enable: ctx BANK_FRAME
rows recorded for a deposit made WHILE DISABLED: 1  count 1
after ResetEverything while disabled: stored enabled = true  IsDisabled = true  IsStoodDown = true
```

## Conventions detected (sweep)

- **Chat prefix.** `NS.PREFIX = "|cff00ffff[BL]|r"` is at `core/Namespace.lua:18`. `NS.Print` comes from LibKa0s-Core (`core/CoreSetup.lua:141-151`). Every loaded file that calls `print(` binds `local print = NS.Print`, and no raw bypass was found.
- **`NS.COMMANDS`** is at `settings/Schema.lua:641`. The LibKa0s-Slash dispatcher walks it. The README's verbs and the table agree.
- **Single write seam.** `NS.Schema:Set` → `NS.SchemaRuntime.Set`, which is LibKa0s-Schema. The flat-row schema lives in `settings/Schema.lua`.
- **No `docs/CLAUDE_SECRET_VALUES.md`.** The addon reads no secret-bearing APIs, so none is needed.
- **LibKa0s v1.55.0 is vendored whole.** The majors wired through setup files are Core, DebugLog, Env, Item, Media, Pool, Launcher, Lifecycle, Slash, Options, Schema and Bus (Catalog only). Perf is declined under the `performance-§12` exemption. `tests/_kit/` is vendored too.
- **Evidence on disk:** the gate suite plus `docs/test-cases.md`, the `docs/automated-tests/` record with 11 bundles, and `docs/performance.md` (exemption page). There is no `tests/perf.lua` and no `docs/perf-analysis/`, both by exemption.
- **Marks.** The addon's close, sort, chevron, search and export controls resolve through `NS.Icon` (LibKa0s-Media). The host close factory is a registered deviation. Nothing new to flag.

---

## High

### F-001: Standing down leaves the capture context armed, so a later stand-up records movements made while disabled `[design]` `[savedvariables]`

- **Where:** `core/BankLedger.lua:146-191` (`NS.StandDown`); `modules/Ledger.lua:750-815` (`OpenContext` / `CloseContext`); `core/State.lua:16,21,41`.
- **Problem:** `NS.StandDown` unregisters every event, cancels timers and drops the bus targets. It never clears `NS.State.openContext`, `NS.State.lastSnapshot`, `L._settleSince` or `NS.State.sessionActive`, and its steps 1–5 contain no reference to any of them.
- **Impact:** Three outcomes follow, all reproduced or traced.
  - **Rows for movements made while disabled.** The player disables at a bank, moves items and re-enables while the bank is still open. The next `BAG_UPDATE_DELAYED` then diffs the pre-disable baseline against the current state and writes permanent ledger rows for movements the player made with the addon off. The headless repro above shows **1 row**. This breaks `slash-commands-§7`'s "it stops writing" in the most user-visible way: the history now contains rows from a period when capture was off.
  - **A context left armed for the rest of the session.** The player disables at a bank, closes it (the `BANKFRAME_CLOSED` registration is already gone, so `CloseContext` never runs), then re-enables anywhere. `openContext` stays `BANK_FRAME` for the rest of the session. Every `BAG_UPDATE_DELAYED` / `PLAYER_MONEY`, including those in combat, schedules a full rescan of bags, bank and warband tabs. That is exactly the "scan moved off the bank-open gate onto a bag event" which `docs/performance.md` names as the thing that ends its `performance-§12` exemption. What the bank containers read back while the frame is closed on 12.1 is **unverified**. If they read empty, loot matching a banked item id would diff as a false withdrawal.
  - **The session window keeps the old visit.** `sessionActive` stays `true`, so movements made after a re-enable are appended to the pre-disable visit's session list.
- **Reachability:** Any player who switches the addon off with the *Enable Bank Ledger* checkbox, `/bl disable` or `/bl set settings.enabled false` while a bank, warband-bank or guild-bank frame is open. All three are documented. Every outcome needs that player to switch it back on later in the same session.
- **Coverage:** `tests/test_disabled.lua` has 11 cases (`:159`–`:546`) and **none opens a storage context** before disabling. The inventory claims the stand-down is covered, but this path is not.
- **Fix direction (compliant):** `NS.StandDown` should drop the capture context in the same turn as the write, alongside the other survivors. Add one Ledger member that clears the three fields and ends the session over the bus before the bus targets go (`slash-commands-§7` *What MUST stand down*). Do not add a second teardown path.

### F-002: "Reset all settings" while disabled restores `enabled = true` in the store but leaves the `disabled` hold taken `[design]` `[ux]`

- **Where:** `settings/Slash.lua:161-197` (`Sl:ResetEverything`). The only other paths that move the latch are `settings/Schema.lua:222-226` (the row's onChange) and `core/LifecycleSetup.lua:107-110` (`NS.ReevaluateEnabled`).
- **Problem:** `ResetEverything` wipes `db.global` in place and merges the defaults back (`:184-186`), which makes `settings.enabled = true`. The write bypasses the row's onChange and never calls `NS.ReevaluateEnabled`. The latch therefore stays down while the store, the panel checkbox and `/bl get settings.enabled` all say enabled. The repro above shows `stored enabled = true, IsDisabled = true`.
- **Impact:** For the rest of the session the player sees an enabled addon that records nothing. Feature verbs and the minimap left-click tell them the addon *is disabled*, and the checkbox beside them says it is not. Bank movements in that window are lost from the history. It self-heals at `/reload`, or when the player writes the path again with `/bl enable` or by toggling the checkbox.
- **Reachability:** A player who has disabled the addon, opens the panel (which the standard keeps live while disabled), and confirms **Master controls ▸ Reset all settings**. Documented surface, uncommon order.
- **Coverage:** `tests/test_panel.lua` pins `ResetEverything` in eight cases (`:411`–`:720`). None runs it while disabled.
- **Fix direction (compliant):** after the wipe, re-evaluate the stored switch the way AceDB's `OnProfileReset` path does (`NS.ReevaluateEnabled`). `options-ui-§12` requires the global-only translation to produce a state "indistinguishable from a fresh install", and `slash-commands-§7` requires re-evaluation whenever the stored switch can change under the addon.

## Medium

### F-003: "Reset all settings" wipes the ledger without announcing `LedgerChanged` `[design]`

- **Where:** `settings/Slash.lua:184-196`. The sole sender is `core/Database.lua:575-577` (`Database:FireLedgerChanged`, documented as the single sender per `architecture-§4`).
- **Problem:** The wipe replaces `g.ledger` with the default `{}` and sends only `SETTINGS_CHANGED "reset"`. Four places refresh only on `LEDGER_CHANGED`/`ENTRY_ADDED`: the Insights tab (`modules/Insights.lua:1000`), the History table, footer and filter options (`modules/Browser.lua:1185-1193`), the session window's prune (`modules/SessionWindow.lua:668`) and the panel's storage read-out (`settings/Panel.lua:170`). None of them hears about the wipe.
- **Impact:** After confirming the reset, an open ledger window, its Insights charts and an open session window keep showing movements that no longer exist until something else repaints them. The settings panel repaints through `refreshAfterReset`, but whether that reaches the storage read-out is **unverified**.
- **Reachability:** Any player who confirms *Reset all settings* with the ledger window or session window open.
- **Fix direction:** announce the wipe through `NS.Database:FireLedgerChanged()` so that Database stays the one sender. This is a single message per act (`debug-logging-§10`, `architecture-§4`).

### F-004: Default retention silently deletes history older than 30 days, and the README never says so `[ux]`

- **Where:** `defaults/Global.lua:47` (`retentionDays = 30`); `settings/Schema.lua:118`; the prune at `core/BankLedger.lua:216-228` → `core/Database.lua:656-675`.
- **Problem:** The addon calls itself "a passbook of every item and gold movement" (TOC `## Notes`, README). On the shipped default, every login prunes rows older than 30 days, permanently. The README has 164 lines, and neither its prose nor its FAQ mentions retention. The only disclosure is the dropdown's tooltip on the History settings tab.
- **Impact:** A player who never opens settings finds their history ends a month ago, with no warning and no export offered. The deletion is working as designed. The defect is that the design is undisclosed.
- **Reachability:** Every player on a default profile, at the first login more than 30 days after their oldest row.
- **Fix direction:** disclose it in the README, with a FAQ row pointing to *Settings ▸ History ▸ Keep history for*. Whether the default should become `0` ("Always") is an owner decision, recorded in `02_PROPOSED_CHANGES.md` as an option rather than a prescription.

## Low

### F-005: The guild-bank open/close events are registered although the code records that they never fire `[deprecated-api]`

- **Where:** `modules/Ledger.lua:819-826` (`GUILDBANKFRAME_OPENED` / `GUILDBANKFRAME_CLOSED`). The file's own comment at `:697` says `GUILDBANKFRAME_CLOSED` "registers without complaint and never fires on 12.0.7".
- **Problem:** Two registrations are kept for events the author documented as dead. The real signal is `GuildBankFrame`'s `OnShow`/`OnHide` hook on a load-on-demand frame (`:713-736`). Since 10.0 the modern retail open/close signal for NPC interaction frames is `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`_HIDE`, with `Enum.PlayerInteractionType.GuildBanker`, and the addon does not use it. Whether it fires for the guild vault on 12.1 is **unverified in client**.
- **Impact:** The registrations do nothing at runtime. Each one inflates the registration list, the `/bl debug scan` "events registered" line and `docs/ARCHITECTURE.md`'s count of fourteen, and each suggests to a reader that the guild bank has an open event.
- **Reachability:** No runtime effect. It affects maintainers and the diagnostic output only.

### F-006: `Util.ApplyVisibility` allocates a table on every combat edge, and `docs/performance.md` claims "No allocation" `[perf]` `[docs]`

- **Where:** `core/Util.lua:277` (`pairs({ Browser = NS.Browser, SessionWindow = NS.SessionWindow })`). Also `:240` in `ApplyMasterChrome`. The claim is at `docs/performance.md:46`: "No allocation, no scan, no timer."
- **Problem:** Each call builds a two-entry table, on the default `always` mode as well. The allocation is trivial, but the exemption's evidence page asserts the opposite of what the code does.
- **Impact:** None measurable. The problem is that the committed sweep, which is the evidence behind `performance-§12`, states something false about the one row that arrived after ratification.
- **Reachability:** Every player, twice per fight. No observable cost.

### F-007: Prose line citations have rotted `[docs]` `[naming]`

- **Where, with each claim against the line it actually lands on:**

  | Citation | Claimed | Actual |
  |---|---|---|
  | `docs/ARCHITECTURE.md:378` | `core/BankLedger.lua:45` is the `PLAYER_ENTERING_WORLD` registration | it is at `:87` |
  | `docs/ARCHITECTURE.md:379` | `core/BankLedger.lua:49-50` is the combat pair | it is at `:91-92` |
  | `docs/ARCHITECTURE.md:384` | `modules/Browser.lua:1206` is `PLAYER_LOGOUT` | it is at `:1218`; the text also says "each window's own event frame" when it is the module's private bus target |
  | `docs/ARCHITECTURE.md:504` | `modules/Browser.lua:98` is `B:MakeCloseButton` | `:98` is `local _, class = UnitClass("player")`; the factory is at `:95` |
  | `docs/ARCHITECTURE.md:504` | `modules/Browser.lua:1047` is the ledger's close call | `:1047` is `testBadge:Hide()`; the call is at `:1056` |
  | `docs/ARCHITECTURE.md:504` | `modules/Browser.lua:104` is the `NS.Icon` resolve | `:104` is `art:SetPoint("CENTER")`; the resolve is at `:101` |
  | `core/Database.lua:581` | the test at `tests/test_ledger.lua:572` uses `DeleteAt` | `:572` is `test("Ledger.MoveSummary …`; `DeleteAt` is at `:564` |

- **Impact:** A reader following the register row's evidence lands on the wrong line.
- **Reachability:** Documentation and comments only. No runtime effect.

### F-008: The committed complexity record predates two watch-list movements `[complexity]`

- **Where:** `docs/automated-tests/RESULTS.md`, newest bundle `20260916-184426` (manifest `git.sha` `076f674`).
- **Problem:** Today's `lizard` plus the LOC census show that `modules/Insights.lua` has **entered** the 1000–1500 band at 1002 LOC and has no watch-list row. `modules/Browser.lua` has grown from 1208 to 1220 under its tracked `BL-24` disposition, which the record describes as "moving the right way". Tests went from 943 to 1017. Max CCN is still 15 and there are 0 warnings.
- **Impact:** The next release run will produce a blank-disposition row for `Insights.lua`, and the Browser note "−44 this run, moving the right way" is no longer true.
- **Reachability:** Evidence record only. No runtime effect.

### F-009: The once-per-session retention prune is latched before its timer, so a stand-down in that window skips it for the session `[design]`

- **Where:** `core/BankLedger.lua:216-228`. The latch `NS.State.cleanupDone = true` is set at `:218` before `C_Timer.After(5, …)` at `:220`. The body checks `IsStoodDown()` at `:225` and returns without resetting the latch.
- **Impact:** If the addon is disabled within five seconds of the first loading screen, retention does not run until the next session. Nothing is lost; the prune is only postponed.
- **Reachability:** A player who toggles the addon off within five seconds of login.

### F-010: The brand name is spelled out twice beside the constant declared to be its one spelling `[naming]`

- **Where:** `core/LauncherSetup.lua:163` (`tt:AddLine("Ka0s Bank Ledger", …)`) and `settings/OptionsSetup.lua:24` (`PARENT_TITLE = "Ka0s Bank Ledger"`). The constant is `NS.BRAND_NAME` at `core/LauncherSetup.lua:89`, whose header at `:80` says "THE BRAND NAME, IN THE ONE PLACE IT IS SPELLED".
- **Impact:** A rename would need three edits, and the comment's claim is false today.
- **Reachability:** Maintainers only. All three strings are identical today.

## Upstream

None. No defect was found under `libs/` or `tests/_kit/`, and both are byte-identical to their LibKa0s sources.

## Not findings (checked and clean)

- The stub/descriptor surface matches every call site. The grep census over the TOC load list found:
  - `NS.Item` uses `ItemIDFromLink`, `LoadItem` and `QualityLabel`, and the stub carries all three.
  - `NS.Pool` uses `New`, `Acquire` and `ReleaseAll`, and the stub carries all three.
  - `NS.DebugLog` uses `Add`, `Hide`, `IsShown`, `SetEnabled`, `Show` and `Toggle`, and the stub carries all six.
  - The `NS.Launcher` stub carries `Register`, `IsShown` and `SetShown`.
  - The Slash stub covers every `Sl:` member called.
- Every bus consumer registers on its own private target (`NS.NewBusTarget`), and `StandDown` drops all four.
- The `HookScript` bodies on `GuildBankFrame` gate on `IsStoodDown()`, which is the sanctioned one-way-hook shape.
- The pooled Insights/table widgets (`W.Acquire` over `NS.Pool`) do not call `CreateFrame` per refresh.
- The CSV field quoting (`modules/Export.lua:22-27`) is RFC-4180-correct. `gsub`'s second return is truncated inside the concatenation, so it does not leak.
- `docs/ARCHITECTURE.md ▸ Known Limitations` already records that the itemID-keyed diff cannot tell two variants of one item apart in a single snapshot. It is not re-filed here.
