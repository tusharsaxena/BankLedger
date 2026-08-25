# Architecture — Ka0s Bank Ledger

Engineer context for the addon, and the **hub** of its doc set: each section below summarizes and
links, it does not store (`documentation-§3`). Player-facing docs live in the root `README.md`; how to
verify it is `docs/testing.md`. The Ka0s WoW Addon Standard itself is the upstream repo linked from
`CLAUDE.md` — it is read there, never copied in here.

## At a glance

| | |
|---|---|
| Folder / TOC `Title` | `BankLedger` / `Ka0s Bank Ledger` |
| Scope | Retail (Mainline) only — a single `## Interface:` line, currently `120007` |
| SavedVariables | `BankLedgerDB`, **account-wide `global` only** (see *Documented deviations*) |
| Slash | `/bl`, aliased `/bankledger` |
| Chat tag | `NS.PREFIX` — the cyan bracketed `[BL]` tag (`\|cff00ffff[BL]\|r`) |
| Layout | `core/ defaults/ locales/ modules/ settings/`, 28 source files |
| Substrate | Ace3 + vendored `LibKa0s`, all committed under `libs/` |

## Overview

Bank Ledger records **movements**, not inventory. It never stores "what is in your bank"; it stores
"what crossed the line between your bags and a bank, when, and which way".

WoW fires no "you deposited this" event, so a movement has to be derived: the addon snapshots the bags
plus every store the open frame can reach, diffs consecutive snapshots per store, and records only
what changed on **both** sides. Gold follows the same corroboration rule at the two stores that hold
it. Capture is completely inert outside an open storage frame, which is what keeps a vendor sale or a
quest turn-in out of the book.

Full pipeline — the corroboration rule, bonus-ID survival, frames-not-stores, and the event
choreography — in **[data-flow.md](data-flow.md)**. What is deliberately out of scope is
**[scope.md](scope.md)**.

## Module Map

28 source files across `core/ defaults/ locales/ modules/ settings/`. `core/` holds the bootstrap,
the Compat firewall, the AceDB layer and the six LibKa0s seams; `modules/` holds the capture engine
and every window; `settings/` holds the schema and the three panel pages.

Load order is load-bearing in four places, and `tests/test_harness.lua` guards the order the harness
derives from the TOC. File-by-file table, load-order notes and the locale seam in
**[module-map.md](module-map.md)**; the API firewall in **[compat-layer.md](compat-layer.md)**.

## Settings Schema

Ten schema rows in `settings/Schema.lua` — the single source for the panel widgets, the
`/bl get|set|list|reset` dispatch and the defaults reset. Every write goes through `NS.Schema:Set`, so
a slash write and a panel widget take exactly the same path.

Four pieces of persisted state are **carve-outs** with no schema widget: the two windows' geometry,
the filter id-lists, and the saved ledger view. Row table and panel structure in
**[settings-panel.md](settings-panel.md)**; the stored shape and carve-out rules in
**[schema.md](schema.md)**.

## Message bus

Four messages, one sender each. Consumers **must** register on their own `NS.NewBusTarget()`
target, never on the shared bus-as-self: CallbackHandler keys callbacks by `(message, target)`, so
two consumers sharing a target silently clobber each other.

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_BankLedger_EntryAdded` | `Database:Add` | `entry, index` | Browser, Insights, SessionWindow, Panel (storage stats) |
| `Ka0s_BankLedger_LedgerChanged` | `Database` (delete / purge / prune / `FireLedgerChanged`) | — | Browser, Insights, SessionWindow (prunes deleted rows), Panel (storage stats + Filters page) |
| `Ka0s_BankLedger_SettingsChanged` | `Schema` row `onChange` handlers | a short reason string (`enabled`, `sessionWindow`, `windowScale`, `quality`, `trackItems`, `trackMoney`, `stores`) | Ledger (re-caches its gate upvalues), Browser, SessionWindow |
| `Ka0s_BankLedger_SessionChanged` | `Ledger` (`OpenContext` / `CloseContext` / the guild-bank self-disarm) | `active` (boolean), `context` | SessionWindow |

`SessionChanged` exists so the session window rides the span the capture engine already arms
`openContext` for, instead of re-deriving it from the open/close events — which would have missed the
guild bank entirely, since that is armed by the arrival of tab data rather than by an event, and gets
no close event at all.

`NS.Filters` deliberately does **not** introduce a fourth sender: it calls
`Database:FireLedgerChanged()` so `Database` stays the sole emitter of that message.

## Slash Commands

`/bl`, aliased `/bankledger`, generated from `NS.COMMANDS` so `/bl help`, the settings landing page
and the README all read one table. Fifteen verbs; `settings/Slash.lua` is the LibKa0s-Slash-1.0
seam. Verb table and the host/library split in **[slash-dispatch.md](slash-dispatch.md)**.

## Event Subscriptions

Eleven registrations. **Eight** are the capture engine's and all go through
`Ledger:RegisterEventSafely` — modern retail **raises** on an unknown event name, so a bare loop turns
one retired event into a silently deaf addon. The other three sit outside the engine and outside that
guard, because none of their names can go away under it: `PLAYER_ENTERING_WORLD` on the AceEvent addon
object (`core/BankLedger.lua:45`, the one-shot retention prune) and `PLAYER_LOGOUT` on each window's
own event frame (`modules/Browser.lua:1243`, `modules/SessionWindow.lua:662`, geometry flush).

Change events are debounced into one reconcile pass per user action, and the baseline is held
whenever a pass sees a one-sided change.

The guild bank is the one store with no usable open **or** close event. Full event table, the
debounce/settle contract and the guild-bank arrangement in **[data-flow.md](data-flow.md)**; the
client behavior behind each workaround in **[midnight-quirks.md](midnight-quirks.md)**.

## Taint notes

- The ledger window, the session window and the debug console are plain **non-secure** frames, so they
  touch nothing protected and need no combat gate. All three are registered in `UISpecialFrames` for
  ESC. That the session window opens off a game event is safe for the same reason: it shows a frame
  nobody protected, and it never calls a protected API.
- The settings **category** is registered eagerly at load — that never taints. Each panel **body**
  is built lazily on its first `OnShow`, as is the header's Defaults button.
- Every registered canvas frame carries `OnCommit`, `OnDefault` and `OnRefresh`, so Blizzard's
  Settings window never calls into a missing method — **stamped by `LibKa0s-Options-1.0`'s
  `CreatePanel`** (Options minor 5), not by this addon, which is what options-ui-§1 now requires.
  `OnCommit` and `OnRefresh` are inert by design — writes land immediately through `NS.Schema:Set`
  (nothing is staged), and the library's renderer already owns re-show. `OnDefault` **forwards** to
  whatever the page parked as `defaultsOnClick` (`setDefaultsAction`), so the framework's footer
  control and the addon's own header button are one implementation by construction rather than two
  that have to be kept in step. On General that action is `P:RestoreDefaults()`, which is
  non-destructive — settings and window geometry only; wiping the ledger stays behind the
  confirm-gated `KA0S_BANKLEDGER_RESETALL` popup, which Blizzard's un-gated control never reaches.
- Opening the settings panel **refuses** under combat lockdown with a gray notice and never defers:
  `Settings.OpenToCategory` is protected, and calling it under lockdown taints the panel for the
  rest of the session.
- Every chat and debug line funnels through one secret-safe printer, whose detector probes
  `table.concat` rather than `..` — the operator propagates secretness without raising, so a
  `..`-based probe would let a combat "secret" through to the real concat and crash.

## Known Limitations

- **Currency movements are not recorded, and are not planned.**
- **Guild-bank withdrawals by other players are invisible** — the addon sees only your own client.
- **The reagent bank and void storage are not stores** — Midnight removed both.
- **A store-to-store transfer is not recorded** — neither side is the bags.
- **A movement made while capture is off is lost**, not backfilled.
- **Pre-corroboration gold rows cannot be cleaned up retroactively** — nothing in a stored row
  distinguishes them.
- **An uncached item is skipped when a minimum quality is set**, and there is no name backfill.
- **Rows recorded before the link-enrichment fix keep their base-item quality** — they were written
  from the itemID, so a bonus-upgraded drop was stored at the quality its base item has. Nothing
  re-resolves a stored row, so those rows stay as recorded.
- **Two variants of one itemID in a single snapshot resolve to the same link** — the scan keeps the
  first hyperlink it sees per id and the counts map is keyed by id alone, so it cannot tell an
  upgraded copy from a base one when both are present.

Each of these is a decision with its reasoning; see **[scope.md](scope.md)**.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`). Frozen and
generated directories are named once each and never enumerated per run: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/`, `docs/revendor/`, `docs/superpowers/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `ARCHITECTURE.md` | This file — the hub: at-a-glance facts, module map, schema, bus, slash, events, deviations |
| `scope.md` | What the ledger records, and the movements it deliberately does not |
| `module-map.md` | Every non-vendored file, its responsibility, and the TOC's load order |
| `schema.md` | `BankLedgerDB`'s account-wide shape, the entry fields, carve-outs, migrations |
| `settings-panel.md` | The three pages, the ten rows, and the single `Schema:Set` write seam |
| `data-flow.md` | Snapshot → diff → corroborate → record, and the event choreography around it |
| `common-tasks.md` | Add a setting, a command, a store, a migration, a chart, an event |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `slash-dispatch.md` | Present | 15 verbs in `NS.COMMANDS` (threshold is 8) |
| `midnight-quirks.md` | Present | Client-version workarounds of the addon's own |
| `compat-layer.md` | Present | `core/Compat.lua` carries 13 addon-specific shims beyond LibKa0s |
| `message-bus.md` | Not applicable | Four messages; threshold is more than ten. The table lives in `ARCHITECTURE.md` → `## Message bus` |
| `profiles.md` | Not applicable | No AceDB profiles are user-visible — the addon is account-wide by design and the profile namespace is unused |
| `debug.md` | Not applicable | The console is `LibKa0s-DebugLog-1.0`'s, with no debug surface of the addon's own beyond `/bl debug scan` and `/bl debug panel` |
| `perf-analysis/README.md` | Not applicable | The `performance-§12` no-combat-path exemption is held — see `## Documented deviations` |

### Verification and record

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The `performance-§12` exemption and the committed sweep behind it |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated, never hand-edited |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `windows.md` | The two standalone windows, the shared skin seam, and the geometry-save contract |
| `insights.md` | The Insights tab: `Database:Stats` keys, section order, and the three drawing rules |
| `media.md` | Where the mono face and the shared marks come from, which surfaces draw which mark and what each falls back to, and the logo art set with its regeneration recipe |

## Documented deviations

Accepted, deliberate departures from the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards).

**This table is the register, and it is the only place a deviation is ratified.** A departure that
is argued for somewhere else — a code comment, a GitHub issue on this repo — but has no row here is
*not* ratified, and an audit is right to file it. Every row names the rule it departs from as a
`filename-§N` reference, the date it was decided, and the **condition that ends it**: a deviation
with no re-check trigger is a permanent exemption granted by accident.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `performance-§12` | No performance harness is wired: no `core/PerfSetup.lua`, no `BankLedgerPerfDB`, no `perf` verb registration, no suspend/resume contract, no `tests/perf.lua`, no `docs/perf-analysis/`. | **The no-combat-path exemption, criterion (a) plus (b).** (a) — the whole-repo sweep of `RegisterEvent` / `SetScript("OnUpdate"` / `C_Timer` is committed at [`docs/performance.md`](./performance.md) with the per-event work named for every hit: no `OnUpdate` handler anywhere, no repeating ticker (every timer is a one-shot), and the three events that *can* fire in combat do a single `NS.State.openContext` nil check and return. (b) — the capture protocol opens its windows on the player's combat state (`performance-§7`), and this addon's entire engine is gated on a bank frame being open, which is an out-of-combat NPC interaction; every declared bucket would read `0.000` by construction. Reasoned at length in closed issue [`LIBKA0S-17`](https://github.com/tusharsaxena/BankLedger/issues/9); ratified here. | 2026-08-05 | **The first `OnUpdate` handler, repeating ticker, or in-combat event handler doing real work re-arms the full `performance` wiring MUST.** Concretely: an event handler that stops checking `NS.State.openContext` first, or a scan moved off the bank-open gate onto a bag event. |
| `savedvariables-§2` | All defaults live in `defaults/Global.lua`; **`defaults/Profile.lua` is not created**, and `layout-§1`'s tree therefore has a file missing. | Bank Ledger is **account-wide by design** — you deposit on one character and withdraw on another, so a per-character profile would split the very history the addon exists to join up. `NS.defaults` carries a `global` table only and every schema path resolves against `NS.db.global`. An empty `Profile.lua` would satisfy the filename while weakening the rule's real invariant — that there is exactly *one* place a default value is hardcoded — by standing up a second candidate home for it. | 2026-07-27 | **The first per-profile setting.** The moment one default belongs to a character rather than to the account, `defaults/Profile.lua` is created and this row is deleted. |

Detail the table cannot hold, for the `savedvariables-§2` row: AceDB still creates the profile
namespace — the addon calls `AceDB:New("BankLedgerDB", NS.defaults, true)` — it is simply unused, so
the switch to a per-profile setting is a defaults-file addition rather than a database migration.
