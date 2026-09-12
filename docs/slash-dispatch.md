# Slash dispatch

`/bl`, aliased `/bankledger`. `settings/Slash.lua` is the **LibKa0s-Slash-1.0 seam**: the dispatcher,
the help renderer and the `list`/`get`/`set`/`reset`/`resetall` CLI are the library's; what stays the
host's is AceConsole registration, the four confirm dialogs, `Sl:Version`, and the full reset.

`/bl`, aliased `/bankledger`. The table below is generated from `NS.COMMANDS`, so `/bl help` and the
settings landing page both read from one place.

| Command | What it does |
|---|---|
| `/bl show` / `hide` / `toggle` | Open, close or toggle the ledger window |
| `/bl config` | Open the settings panel |
| `/bl version` | Print the addon version |
| `/bl get` / `set` / `list` / `reset` / `resetall` | Read and write settings |
| `/bl test` | Toggle a sample ledger for previewing the window |
| `/bl session` | Toggle the banking-session window (on sample data when no bank is open) |
| `/bl purge` | Delete all history (confirm-gated) |
| `/bl debug` | Toggle the console; `on`/`off` set logging |
| `/bl debug scan` | Dump the client's live container model **and its money-balance readers** into the console |
| `/bl debug panel` | Dump what the settings header's Defaults button actually is at runtime |
| `/bl help` | The help index |

`/bl test` is the renamed History-table sample data (`LT:IsTestMode`, `LT:ToggleTestMode`,
`LT:BuildTestData`, badge `TEST MODE`) — matching the Ka0s house vocabulary set by LootHistory's
`/lh test`. `/bl session`'s `previewSession` / `TogglePreview` on `NS.SessionWindow` **deliberately
keep the "preview" name**: it is a separate synthetic-data feature (placeholder movements for
positioning the Current Banking Session window away from a bank) with no LootHistory counterpart to
match, so it was left alone rather than folded into the rename.

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
