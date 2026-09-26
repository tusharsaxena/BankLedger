# Debug verbs

The console itself is **`LibKa0s-DebugLog-1.0`**'s, wired by `core/DebugLogSetup.lua`: the window,
the buffer (3000 lines, `lib.MAX_BUFFER`), the **Copy** box, the `on`/`off` seam and the chat
acknowledgment are the library's, and `/bl debug`, `/bl debug on` and `/bl debug off` drive it the
way they drive every Ka0s console (`debug-logging`; the in-game walk is `S-14` in
[smoke-tests.md](smoke-tests.md)).

This page covers what the library does not: the **diagnostics report**, whose sections this addon
writes, and the two **addon-owned** topic dumps that also write into that console.

| Verb | Runs | Console tag | Answers |
|---|---|---|---|
| `/bl diagnostics` or `/bl debug diagnostics` | `NS.DebugLog:RunDiagnostics()` over `NS.Diagnostics.Sections()` (`modules/Diagnostics.lua`) | `[Diag]` markers, one tag per section | Everything a maintainer asks first: build, state, settings, filters, the ledger, the capture engine, the session, the container model, windows, the launcher and other bank addons |
| `/bl debug scan` | `NS.Ledger:Diagnose()` (`modules/Ledger.lua`) | `[Scan]` | What the client's container, money and guild-bank model actually is, and which events registered |
| `/bl debug panel` | `NS.Panel:Diagnose()` (`settings/Panel.lua`) | `[Panel]` | What the settings header's **Defaults** button actually is at runtime |

All three are wired in `NS.COMMANDS` (`settings/Schema.lua`): the report as its own `diagnostics`
row and as the first word the `debug` row tests, the two dumps as words of the `debug` row. Each
dump opens the console first, then appends one line per entry of the array its `Diagnose()`
returns. `Diagnose()` returns plain strings rather than printing, which is what lets `tests/` assert
on them, and it is also what lets the report fold the scan in as a section.

## The raw-append rule

The report and both dumps write through the library's raw append (`NS.DebugLog:Add(tag, line)`,
which `RunDiagnostics` uses too), and **not** through the gated sink `NS.Debug`. So they print
whether logging is on or off: you do not need `/bl debug on` first, and turning logging on adds
nothing to them. A dump the player asked for explicitly is not idle cost, and a console that stays
empty because the flag happened to be off reads as a broken verb (`debug-logging-§4`).

Two consequences follow:

- `debug` and `diagnostics` are reserved verbs (`slash-commands-§2`), so the report and both dumps
  still answer while the addon is **disabled**. `/bl debug scan` then describes a stood-down addon
  (see the event record below), and the report says which of its sections are stood down.
- Without LibKa0s, `core/DebugLogSetup.lua`'s degraded stub keeps the verbs from raising: `Show`
  prints the one "debug console window is unavailable" line and `Add` is a no-op, so neither dump
  has anywhere to go. `/bl diagnostics` prints `/bl diagnostics is unavailable: the LibKa0s library
  did not load.` and writes nothing. A report of a few hundred lines sent to chat instead would be
  worse than none.

## `/bl diagnostics`

The report (`debug-logging-§14`). Run it **after** reproducing the problem, not before: it is
appended below whatever the console already holds, so the trace you just produced and the state it
left behind travel in one **Copy**.

**Two forms, no third.** `/bl diagnostics` and `/bl debug diagnostics` (either case, and through
`/bankledger` as well as `/bl`) are the same call. `/bl debug` tests `diagnostics` before `on`,
`off`, `scan` and `panel`. There is no `diag`, `dump` or `dx` alias: `/bl debug diag` is an ordinary
unknown word, which toggles the console like any other.

**What it does to the console.** It never clears it, it never reads or changes the logging flag
beyond printing it, and it shows the console if it was hidden. Then it prints one chat line:
*Diagnostic report written to the debug console: N lines. Use Copy to share it.*

**The shape.** The library writes the frame and this addon writes the sections:

| Part | Tag | Written by | What it holds |
|---|---|---|---|
| Begin marker | `[Diag]` | the library | `==== Ka0s Bank Ledger diagnostics begin ====` |
| Identity header | `[Diag]` | the library | The `[Init]` summary line (build, schema, profile), the client version, build, date and interface, the locale, the debug flag, `InCombatLockdown()` and `UnitAffectingCombat("player")`, and every LibKa0s file **running** in the client with its minor. Running, because under LibStub another addon's newer copy may be the one loaded |
| `state` | `[State]` | `X.State` | Stored enabled, disabled, stood down; the Lifecycle holds; the schema version stored and in code (settings are account-wide, so there is no profile); test mode and its sample-row count; whether this session's retention prune has run or is armed |
| `settings` | `[Set]` | `X.Settings` | The six capture-critical rows always (`enabled`, `trackItems`, `trackMoney`, `qualityThreshold`, `excludedStores`, `retentionDays`), every other row only when it differs from its default, each as `path = value (default)`. `excludedStores` prints as its members, the way `/bl get` shows it |
| `filters` | `[Filter]` | `X.Filters` | The blacklist and the whitelist, each as its size and its sorted ids |
| `ledger` | `[Ledger]` | `X.Ledger` | Entry count (the real ledger, even while test mode is showing sample rows), counts by store, by direction and by kind, the oldest and newest timestamps, the retention days, and the last 20 entries as stored: timestamp, store, direction, kind, quantity, item id, item name as plain text, character |
| `capture` | `[Capture]` | `X.Capture` | `openContext`, whether a pre-move snapshot is held and what it holds (distinct items per store, money), whether a settle is pending and the debounce armed, and the gate's cached upvalues from `L:GateState()`: enabled, the two track switches, the quality floor, the excluded stores and both filter sizes |
| `session` | `[Session]` | `X.Session` | Whether a banking session is active, its entry count, and whether the session window is on preview data |
| `scan` | `[Scan]` | `X.Scan` | `NS.Ledger:Diagnose()`, line for line: everything `/bl debug scan` prints (below) |
| `windows` | `[Window]` | `X.Windows` | The ledger and session windows, each built, shown and its stored geometry; the console shown; the master window scale |
| `launcher` | `[Launcher]` | `X.Launcher` | The minimap button shown, registered, running degraded, and its stored angle |
| `environment` | `[Env]` | `X.Environment` | Which bank-replacing addons are loaded, from a fixed list (ArkInventory, AdiBags, Baganator, Bagnon, BetterBags, Combuctor, ElvUI, LiteBag, OneBag3, OneBank3). A loaded one is the first suspect when a bank visit records nothing |
| `truncated` line | `[Diag]` | the library | Only when a cap bit: `truncated: N line(s) omitted, per-list caps hit=yes/no` |
| End marker | `[Diag]` | the library | `==== Ka0s Bank Ledger diagnostics end: N line(s) ====`, counting both markers |

**Stood down.** While the addon is disabled every section still runs. `capture` and `session`
describe machinery that stand-down released, so each prints one `stood down: ...` line rather than
an idle engine that looks like a healthy one. Stored configuration (settings, filters, the ledger)
prints as normal, and `scan` shows the emptied event record the way `/bl debug scan` does.

**Caps.**

- The whole report: at most `min(lib.DIAG_MAX_LINES, lib.MAX_BUFFER - 100)` lines, markers
  included. That is **1200** at LibKa0s v1.60.0 (`min(1200, 3000 - 100)`), so a full report leaves at
  least 1800 lines of trace above it in a full console. Two lines stay reserved for the `truncated`
  line and the end marker, so a capped report still ends properly.
- Each filter list: 40 ids (`LIST_CAP`, the library's default), then `(+N more)`.
- The ledger tail: the newest 20 entries (`TAIL`). The counts above it cover every entry.
- A long list on one line (holds, excluded stores, loaded addons) wraps onto indented continuation
  lines at 200 characters rather than being cut.

**What it deliberately does not read or call.**

- **No server requests.** It never calls `QueryGuildBankTab`. The guild-bank tab counts in the
  `scan` section are the client's cache, and when the guild-bank frame is shut the section says so
  on its first line (`guild bank frame closed: the tab counts below are the client's cache, not
  fact`).
- **No writes and no machinery.** No Lifecycle hold is taken or released, no event is registered,
  no timer is armed, no setting is written, and nothing is stood up. It never calls `Clear()`.
- **No protected API**, so it is safe in combat.
- **No raw values.** Every value reaches a line as an argument to the library's `out:add`, which
  stringifies it through `SafeToString` before any format sees it, so a secret value prints as
  `<secret>` instead of raising. Timestamps are tested with `out:readable` before they are compared.
  Item links are not printed: the tail carries the item id and the name as plain text, and every
  color, texture and hyperlink escape is stripped, so the **Copy** text is clean.
- **Each section under its own `pcall`.** A section that raises costs one line, `section <name>
  failed: <err>`, and the next section still runs.

Nothing is redacted: the report goes to the maintainer privately with a bug report, so it prints
what reproducing a bug needs, purse and bank balances included. Report lines are English diagnostic
text and do not go through `NS.L`; the one chat line does.

## `/bl debug scan`

Run it **with the bank window open** (or the guild bank, or the warband bank) that is misbehaving.
The dump reads, in order:

| Line | What it tells you |
|---|---|
| `openContext=… snapshot=yes/no` | Which store the engine thinks is open, and whether a pre-move snapshot is held. `nil` at a bank means the open was never noticed, so nothing will be recorded |
| `Enum.BagIndex has N members`, then `BagIndex.<name> = <id>` | Which container ids this client build actually exposes, sorted by id |
| `group BAGS / BANK / WARBAND_BANK = [...]` | What the addon's own id groups (`C.STORE_CONTAINERS`) resolved to, beside the truth above |
| `container probe` rows (`id: slots / filled / distinct ids`) | Every id from -8 to 40 that reports slots right now. This is where the bank really lives on this client |
| `money=` and the `money API:` block | The purse, which balance readers exist (`GetGuildBankMoney`, `C_Bank.FetchDepositedMoney`, `Enum.BankType`), and what each returns when called, or `absent` / `ERROR …` |
| `guild bank API:` / `guild bank frame hooks:` / `guild bank tabs=` | Which guild-bank globals exist, whether the `GuildBankFrame` show/hide hooks are installed (they are the only open and close path the guild bank has), and each tab's filled / distinct-id count |
| `events registered (N): …` / `events UNAVAILABLE (N): …` | The event record, below |

The same lines are the diagnostics report's `scan` section, so a report run at the bank carries
them already. The verb stays for a quick look without the rest of the report.

### The event record

Every registration in the addon goes through `NS.RegisterEventSafely` (`core/CoreSetup.lua`), and
every outcome lands in one table, **`NS.EventRecord`** — `registered` and `unavailable`, each a
list of event names recorded once. The scan prints both. An event in the `UNAVAILABLE` list is one
this client refused (`C_EventUtils.IsEventValid` said no, or `RegisterEvent` raised). If a
capture-critical event is there, that is why nothing is being recorded.

`NS.StandDown` (`core/BankLedger.lua`) **empties** the record when it unregisters everything, and
the next stand-up rebuilds it from what actually registered. So on a disabled addon the scan
reports `events registered (0)` and `events UNAVAILABLE (0): none`, which is correct, not a fault.

## `/bl debug panel`

Run it after the settings panel has been opened once (`/bl config`), because the General page and
its **Defaults** button are built on first show. The dump reads:

| Line | What it tells you |
|---|---|
| `AceGUI=… minor=…`, `Button widget registered=… version=…` | Which copy of AceGUI-3.0 served the widget. With several addons loaded, the first copy to load wins for all of them |
| `defaultsBtn=NIL — no button was built; anything on screen is not ours` | The page has not been built yet, or the button is someone else's. The dump stops here |
| `defaultsBtn type=… aceType=…`, then `frame objectType=… shown=… size=…` and `parent chain:` | What the widget is, and whether it really sits on this addon's canvas panel (the chain is capped at depth 6) |
| `normal:` / `highlight:` / `pushed:` | Each state texture's atlas, path and vertex color |
| `btn: N regions` and the `btn[i] <layer>` rows (and `btn.NineSlice` when present) | The full region tree. A bare 5-region button whose texture is fileID `130828` is Blizzard's unskinned red stone button; a skinned one carries extra BORDER / BACKGROUND regions |
| `label="…" color=…` | The button's text and its color |

This is the tool that found the load-order skinning race (a Defaults button built before a UI skin
hooked AceGUI): whether a button is stock art or restyled by a UI skin is invisible in code and plain in its region list.

The report does not fold this dump in: it describes one widget on a page that may never have been
built, and it matters only for how the settings panel looks.

## Which to paste

For any bug, follow the README's **Reporting a bug** steps: `/bl debug on`, reproduce the problem,
run `/bl diagnostics`, then open the console with `/bl debug` if it is not already open, press
**Copy** and include the entire output with the report. That one copy holds the trace and the whole
report, and the report already carries everything `/bl debug scan` prints.

- For anything about **capture** (a movement that was not recorded or was filed against the wrong
  store, a gold row missing or wrong, a guild-bank visit that was never noticed, a session that never
  opened or never closed), run `/bl diagnostics` **at the bank involved, with it still open**. Then
  the report's `capture` and `scan` sections describe that bank, and its guild-bank tab counts are
  live rather than cached. The same goes for any report from a new client build, since the `scan`
  section is what shows a changed `Enum.BagIndex` or a retired event.
- For anything about how the settings panel's **Defaults** button looks (typically it rendering as
  the red stone button, or looking different with a UI skin loaded), also run `/bl debug panel`
  after opening `/bl config`, before pressing **Copy**. The report does not include it.
