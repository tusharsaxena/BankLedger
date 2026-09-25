# Debug verbs

The console itself is **`LibKa0s-DebugLog-1.0`**'s, wired by `core/DebugLogSetup.lua`: the window,
the buffer, the **Copy** box, the `on`/`off` seam and the chat acknowledgment are the library's, and
`/bl debug`, `/bl debug on` and `/bl debug off` drive it the way they drive every Ka0s console
(`debug-logging`; the in-game walk is `S-14` in [smoke-tests.md](smoke-tests.md)).

This page covers what the library does not: the two **addon-owned** verbs that write structured
dumps into that console.

| Verb | Runs | Console tag | Answers |
|---|---|---|---|
| `/bl debug scan` | `NS.Ledger:Diagnose()` (`modules/Ledger.lua`) | `[Scan]` | What the client's container, money and guild-bank model actually is, and which events registered |
| `/bl debug panel` | `NS.Panel:Diagnose()` (`settings/Panel.lua`) | `[Panel]` | What the settings header's **Defaults** button actually is at runtime |

Both are wired in the `debug` row of `NS.COMMANDS` (`settings/Schema.lua`). Each opens the console
first, then appends one line per entry of the array its `Diagnose()` returns. `Diagnose()` returns
plain strings rather than printing, which is what lets `tests/` assert on them.

## The raw-append rule

Both verbs write through **`NS.DebugLog:Add(tag, line)`**, the library's raw append, and **not**
through the gated sink `NS.Debug`. So they print whether logging is on or off: you do not need
`/bl debug on` first, and turning logging on adds nothing to them. A dump the player asked for
explicitly is not idle cost, and a console that stays empty because the flag happened to be off
reads as a broken verb (`debug-logging-§4`).

Two consequences follow:

- `debug` is one of the reserved verbs (`slash-commands-§2`), so both dumps still answer while the
  addon is **disabled**. `/bl debug scan` then describes a stood-down addon (see the event record
  below).
- Without LibKa0s, `core/DebugLogSetup.lua`'s degraded stub keeps the verb from raising: `Show`
  prints the one "debug console window is unavailable" line and `Add` is a no-op, so neither dump
  has anywhere to go.

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

## When to paste which into an issue

Reproduce with `/bl debug on`, open the console with `/bl debug`, press **Copy**, and paste the log.
Then add:

- **`/bl debug scan`**, run at the bank involved, for anything about **capture**: a movement that
  was not recorded or was filed against the wrong store, a gold row missing or wrong, a guild-bank
  visit that was never noticed, or a session that never opened or never closed. Also for any
  report from a new client build, since the scan is what shows a changed `Enum.BagIndex` or a
  retired event.
- **`/bl debug panel`** for anything about how the settings panel's **Defaults** button looks,
  typically it rendering as the red stone button, or looking different with a UI skin loaded.

Neither dump contains anything from your SavedVariables beyond whether a snapshot is held; the
scan does print your purse and bank balances, so trim those if you would rather not share them.
