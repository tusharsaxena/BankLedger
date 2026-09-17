# Slash dispatch

`/bl`, aliased `/bankledger`. `settings/Slash.lua` is the **LibKa0s-Slash-1.0 seam**: the dispatcher,
the help renderer and the `list`/`get`/`set`/`reset`/`resetall` CLI are the library's; what stays the
host's is AceConsole registration, the four confirm dialogs, `Sl:Version`, and the full reset.

`/bl`, aliased `/bankledger`. The table below is generated from `NS.COMMANDS`, so `/bl help` and the
settings landing page both read from one place.

| Command | What it does |
|---|---|
| `/bl` | Open the settings panel on its landing page (runs `config`) |
| `/bl show` / `hide` / `toggle` | Open, close or toggle the ledger window. **Feature verbs**: refused on one line while the addon is disabled (see below). |
| `/bl config` | Open the settings panel |
| `/bl enable` / `disable` | Turn the addon on or off. **Aliases**, not a second switch: both write `settings.enabled` — the path the Master controls **Enable Bank Ledger** checkbox writes — through `NS.Schema:Set`, and hold no state of their own (`slash-commands-§2`). `/bl set settings.enabled true|false` is the same write by its long name. The dispatcher keeps answering while the addon is disabled, so the pair is never one-way. |
| `/bl version` | Print the addon version |
| `/bl get` / `set` / `list` / `reset` / `resetall` | Read and write settings |
| `/bl test` | Toggle a sample ledger for previewing the window (the same switch as the Master controls **Test mode** box) |
| `/bl session` | Toggle the banking-session window (on sample data when no bank is open) |
| `/bl purge` | Delete all history (confirm-gated) |
| `/bl debug` | Toggle the console; `on`/`off` set logging |
| `/bl debug scan` | Dump the client's live container model **and its money-balance readers** into the console |
| `/bl debug panel` | Dump what the settings header's Defaults button actually is at runtime |
| `/bl help` | Print the command list (the help index) |

A bare `/bl`, or one that is only whitespace, runs the `config` verb with an empty argument
(`slash-commands-§4`, LibKa0s Slash minor 11). That opens the settings panel on its landing page,
and in combat it gets the panel's own refusal line. `/bl help` is what prints the list. The
library-absent stub in `settings/Slash.lua` does the same: it runs `config` if `NS.COMMANDS`
registers one, and prints the help index only if it does not.

`/bl test` is the renamed History-table sample data (`LT:IsTestMode`, `LT:ToggleTestMode`,
`LT:BuildTestData`, badge `TEST MODE`) — matching the Ka0s house vocabulary set by LootHistory's
`/lh test`. It is one of two ways to flip one switch: `LT:ToggleTestMode` calls `LT:SetTestMode`,
the same path the Master controls **Test mode** checkbox (`state.testMode`, `options-ui-§15`) and
the combat ending take, and that path repaints an open panel so the box follows the verb. A start
refused in combat, or by General visibility, prints its one reason line, never `test mode on`. `/bl session`'s `previewSession` / `TogglePreview` on `NS.SessionWindow` **deliberately
keep the "preview" name**: it is a separate synthetic-data feature (placeholder movements for
positioning the Current Banking Session window away from a bank) with no LootHistory counterpart to
match, so it was left alone rather than folded into the rename.

## While the addon is disabled

**Disabled means the addon is not running** - every registration gone, every timer cancelled, every
window shut (`slash-commands-§7`; see [ARCHITECTURE.md](ARCHITECTURE.md) ▸ *The stand-down*). This
page is about the other half of that ruling: the command surface, which is **not** the addon.

`/bl` and every verb reachable from it stay registered while the addon is off — the dispatcher and
the settings registration are **setup**, not features, so the pair is never one-way
(`slash-commands-§2`). What changes is that a verb which **drives this addon's features** answers on
**one** tagged line naming `/bl enable`, and does nothing else.

| | Verbs |
|---|---|
| Refused while `settings.enabled` is false | `show`, `hide`, `toggle`, `session`, `test`, `purge` |
| Always live | `help`, `config`, `version`, `enable`, `disable`, `debug`, `perf`, the schema CLI — `get`, `set`, `list`, `reset`, `resetall` — and the bare `/bl`, which opens the settings panel |

The live set is the standard's, and its reasoning is that a player must be able to **read and repair
settings**, and to **reach the panel**, while the addon is off — which is precisely when they are most
likely to need to — and **`enable` above all**. `debug` and `perf` are diagnostics rather than
features; the usual reason to reach for either is that the addon is misbehaving. `perf` is on the
list although this addon registers no `perf` verb (the `performance-§12` exemption): a verb is
reserved always and registered when wired, so arming the harness later is a registration rather
than a rename. Typed today, `/bl perf` answers `unknown command 'perf'` and the index **in either
state**: from `LibKa0s-Slash-1.0` minor 14 (LibKa0s v1.42.0) the gate refuses only a verb the host
ships, so a reserved verb with no `COMMANDS` entry behind it is not made to look as though the
disabled state swallowed it.

**The gate is the library's, and the host's copy is gone.** `settings/Slash.lua` used to carry its
own `ALWAYS_LIVE` table, its own stored-path read and its own refusal wording. From
`LibKa0s-Slash-1.0` minor 14 the whole adoption is two descriptor fields — `isEnabled`, asked at
dispatch time and never cached, and `brandName`, the plain-text brand the broker row already wears
(spelled once, in `core/LauncherSetup.lua`). The library keeps `lib.LIVE_VERBS` and renders the line
from `lib.DISABLED_LINE_FORMAT`.

**No `liveVerbs` is passed, deliberately.** That field narrows or widens the live set, and this
addon wants neither. Standard v2.56.0 *did* narrow the disabled surface to `enable` and `help`, and
v2.57.0 reversed it the same day: the bare `/bl` on a disabled addon answered with a refusal instead
of opening the settings panel, which is the one surface a player uses to switch it back on by hand.
Passing nothing is what keeps this addon on the restored side of that reversal.

An **unknown** verb is never refused: the gate sits **after** the `COMMANDS` lookup, so a word this
addon does not ship still gets `unknown command '<verb>'` and the index. Telling a player who
mistyped that the addon is disabled is a true sentence and the wrong answer — it says their spelling
was fine. `/bl help` prints its index **in full**, with the refusal line under the header: that line
is a statement about the feature rows below it, not a refusal of `help`, and the player has to be
able to see `enable` in the list. A bare `/bl` is the `config` verb, which is live.

**The wording is the collection's, not this addon's.** It reads
`[BL] Ka0s Bank Ledger is disabled — enable it with /bl enable`, one line, the command in gold. It
is **not** routed through `NS.L`: the standard says in as many words that the `L` override does not
reach it, and the entry that used to sit in `locales/enUS.lua` was deleted rather than translated.

**The minimap button takes the same refusal.** Bank Ledger is launcher rung (a), so its left click
drives the ledger window — a feature — and while the addon is disabled it prints that same line,
built by the same member, and writes nothing. Right-click opens the settings panel in either state
(`launcher-§2`).

## What the host supplies to the library

- **`groupKey`** — this schema groups by `group`, not by `page`, so the help renderer is told which
  field to bucket on. `group` also names the panel **tab** the row draws on (`options-ui-§13`), so
  `/bl list`'s headings and the settings strip are the same partition read two ways — *Master
  controls*, *Capture*, *Interface*, *History*, in declaration order. *Master controls* leads because
  `S:ComposeMaster` splices the composed rows at the **head** of `S.Schema`; in a degraded install
  the composer emits nothing and that heading is simply absent from `/bl list` along with its rows.
- **A `format` hook** for the set-typed `settings.excludedStores` row, which has no scalar rendering.
- **A `parse` override** that refuses a chat edit of that same row by name — a muted-store set is not
  something a `set` line can express unambiguously.
- **A `CliResetAll` wrapper**, so the two pieces of state with no Schema widget are still reset. The
  filter lists, an `architecture-§5` registry, are reset through their writer, `NS.Filters:ClearAll`.
  The saved ledger view, a carve-out, goes back to its stock state. The library only knows about schema
  rows.
- **The bulk bracket** (`bulkBegin` / `bulkEnd`, Slash minor 8), so a reset logs one line
  (`debug-logging-§10`). Both are `settings/Schema.lua`'s `S.BulkBegin` / `S.BulkEnd`. While the
  library's `CliResetAll` walks the rows, the write seam mutes its per-row `[Set]` line and counts the
  rows whose value changed. The walk then logs exactly `[Set] reset all: N rows`, which is `0 rows`
  when everything was already at its default. A walk that raises part-way logs the same line once
  with ` (stopped by an error)` appended, then the error is re-raised. The library hands `bulkEnd`
  `err = nil` for a raise of nil or false, so that raise gets no marker. The degraded fallback
  `CliResetAll` brackets its own walk the same way, and marks every error it catches.

Adding a verb is one entry in `NS.COMMANDS` (`settings/Schema.lua`); `/bl help` and the settings
landing page both read from that one table.
