# Data flow

How a bank visit becomes ledger rows: the snapshot-and-diff engine, the corroboration rule that keeps
ordinary play out of the book, and the event choreography that decides when a pass runs. The shape the
rows are stored in is [schema.md](schema.md); where the code lives is [module-map.md](module-map.md).

The README's *How the ledger works* is the player-facing version of this same pipeline. The two
describe one mechanic at two levels and must not contradict each other.

Bank Ledger records **movements**, not inventory. It never stores "what is in your bank"; it stores
"what crossed the line between your bags and a bank, when, and which way".

WoW fires no "you deposited this" event, so a movement has to be derived. The addon keeps a snapshot
of the bags plus the contents of every store the open frame can reach. Each time the client reports
a change it takes a fresh snapshot and diffs the two, **per store**:

1. An item whose count **fell in the bags** and **rose in the store** is a **deposit**.
2. The reverse is a **withdrawal**.
3. A change on only one side (loot landing in the bags, a stack destroyed) is deliberately **not** a
   movement, so ordinary play never pollutes the ledger.
4. Gold is diffed the same way, and under the **same corroboration rule**, at the two stores that
   hold gold — the guild bank and the warband bank. A character-bank money change came from
   somewhere else entirely.

The corroboration in rule 4 is the whole of it: a gold row requires the player's purse **and the
store's own coin balance** to move by the same amount in opposite directions. The purse alone proves
nothing, because `BANK_FRAME` reaches the warband bank — so buying a bank tab, repairing, or a mail
COD landing mid-visit would otherwise each be recorded as a warband deposit. A store whose balance
cannot be read on both snapshots contributes no money movement at all.

`Compat.GetStoreMoney(store)` is the reader, and it returns `nil` rather than a number whenever it
cannot answer honestly. That matters more than it looks: `GetGuildBankMoney()` returns **0**, not
`nil`, when the guild bank frame is closed, so the guild read is gated on
`Compat.IsGuildBankVisible()`. The warband balance comes from
`C_Bank.FetchDepositedMoney(Enum.BankType.Account)`, which is not frame-bound.

#### Bonus IDs survive the scan

A snapshot's counts are keyed by `itemID` — that is all the diff needs, and all it sees. But an id is
not an item variant: item level, tertiaries and sockets live in a link's **bonus IDs**, and
`GetItemInfo(itemID)` can only ever answer with the base item. So the scan keeps a side table,
`snapshot.links = { [itemID] = hyperlink }` (the first link seen for an id), the diff passes it
through onto the movement as `move.link`, and `BuildEntry` prefers it over the derived link.

Two consequences worth knowing: the counts map keeps its plain `{ [itemID] = count }` shape, so the
diff and the settle check are untouched; and one id resolves to one link per snapshot, which is
exact for gear (it does not stack) and irrelevant for stackables (they carry no bonuses).

This is what lets the ledger CSV's `wowhead` column point at the variant that actually moved rather
than at the base item.

Capture is completely inert outside an open storage frame. That single gate is what keeps a vendor
sale or a quest turn-in out of the ledger.

#### Frames, not stores

The unit the addon tracks is the open **frame**, not the open store, and the distinction is
load-bearing. The retail bank window hosts the character bank **and** the warband
tabs behind a single `BANKFRAME_OPENED`, and switching between those tabs fires no event at all — so
an addon simply cannot know which tab you are looking at.

It does not need to. `L.CONTEXT_STORES` maps each frame to every store it can reach, a snapshot
measures all of them together, and each pass diffs the bags against each one in turn. The
"both sides must change" rule then decides which store you actually used: the ones you didn't touch
show no change on their side and produce no row. Tab switching becomes a non-event, because every
tab was already measured.

An earlier model picked one store from the open *event* and diffed only that. It could never see a
warband movement, because no event announces one.

| Event | Handler |
|---|---|
| `PLAYER_ENTERING_WORLD` | Deferred one-shot retention prune |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` | Re-evaluate **General visibility** at each combat edge (`addon:OnCombatChanged` → `NS.Util.ApplyVisibility`). Outside the capture pipeline entirely — no snapshot, no diff, no row |
| `BANKFRAME_OPENED`, `GUILDBANKFRAME_OPENED` | Arm the differ with a baseline snapshot of every store that frame reaches (the guild one never fires — see below) |
| `BANKFRAME_CLOSED`, `GUILDBANKFRAME_CLOSED` | Final reconcile, then disarm (the guild one never fires — see below) |
| `BAG_UPDATE_DELAYED`, `PLAYERBANKSLOTS_CHANGED`, `PLAYER_MONEY` | Schedule a debounced re-snapshot, then record what moved |
| `GUILDBANKBAGSLOTS_CHANGED` | Schedules the same debounced pass. It also **arms** the guild-bank context, but only when the guild-bank window reports itself explicitly visible — data alone is not proof of a visit, see below |
| `ADDON_LOADED` | Installs `GuildBankFrame`'s `OnShow`/`OnHide` hooks when the load-on-demand `Blizzard_GuildBankUI` arrives. Those hooks are the guild bank's open and close — see below |
| `PLAYER_LOGOUT` | Flush each window's geometry to SavedVariables (`modules/Browser.lua`, `modules/SessionWindow.lua`) |

The addon asks for no event Midnight has retired. That is not a standing guarantee — Blizzard
retires names between expansions, and modern retail **raises** on an unknown one rather than
ignoring it, so registration is isolated per event (below) and a name that goes away is recorded and
survived rather than fatal.

Change events are **debounced** into one reconcile pass per user action (`Ledger.DEBOUNCE_SECONDS`,
0.35s). A single deposit reports itself through several events that do not arrive together — the
bags update on `BAG_UPDATE_DELAYED`, the warband tabs on their own beat — so reconciling per event
split one movement across two passes and the "both sides must change" rule rejected both halves.
Debouncing lines passes up with user actions and collapses several full container scans per action
into one, but it cannot cover a gap of *seconds* — the live warband tab took over a second to catch
up after the bags. So the baseline is additionally **held whenever a pass sees a one-sided change**
(`SETTLE_TIMEOUT_SECONDS`): the pass keeps the old baseline so the half that already happened is
still visible when the other half lands. The wait is **event-driven, not polled** — a warband tab is
a container, so the client updating it fires `BAG_UPDATE_DELAYED` and drives the re-check by itself;
the timer is only a give-up deadline, re-armed on the remaining window so event traffic cannot push
it out. If it never balances — an item
looted into the bags while the bank happened to be open — the baseline re-anchors after the timeout,
so a stale delta cannot later pair with something unrelated. Closing a frame runs the pending pass
immediately rather than waiting out the window.

Event registration is **isolated per event** (`Ledger:RegisterEventSafely`). Modern retail raises
on an unknown event name rather than ignoring it, so a bare registration loop turns one retired
event into a silently deaf addon — every event after the throw goes unbound, with no visible error
unless the player has script errors switched on. Names this build rejected are recorded in
`Ledger.unavailableEvents` and reported by `/bl debug scan`.

The guild bank is the one store with **no usable open event, and no usable close event either**.
`GUILDBANKFRAME_OPENED` is a valid name that registers without complaint and never fires on 12.0.7,
and `GUILDBANKFRAME_CLOSED` is the same story. Both ends therefore hang off the frame's own scripts:

- **`GuildBankFrame`'s own `OnShow`** (`Ledger:HookGuildBankFrame`) is the open path. It fires when
  the player is demonstrably looking at the vault, which is exactly when the baseline wants taking,
  and it never steals the context from an already-open bank frame.
- **`GuildBankFrame`'s own `OnHide`** is the close path. It is the one notice the client gives, and
  it has to be a hook rather than a check inside `Reconcile`, because closing the window changes no
  container and moves no money — so no event fires and no reconcile pass runs. The hook only ends
  the guild bank's *own* context (the frame also hides whenever it is simply not the panel on
  screen).

`GuildBankFrame` lives in `Blizzard_GuildBankUI`, loaded on demand, so there is no frame to hook
until the player opens a guild bank for the first time in a session — and that first open is the one
whose `OnShow` would otherwise be missed. `Ledger:OnAddonLoaded` therefore installs both hooks the
moment that addon lands, `Ledger:Enable` tries once in case it is already loaded, and
`OnGuildBankData` tries again on every data event. All three are idempotent; a hook cannot be
removed, so it goes on once.

Tab **data** arriving (`GUILDBANKBAGSLOTS_CHANGED`) used to be the open signal, and it was wrong:
the server pushes tab contents on reload sync and whenever *another guild member* moves something,
so a banking session opened in the middle of a field and — with no frame in existence to report
itself hidden — could not end (issue #12). Data now arms only when
`Compat.IsGuildBankVisible() == true`, a backstop for a build whose `OnShow` never fires. Its
reconcile role is unchanged, and that is the half that matters: tab contents arriving mid-visit is
still the only way the guild side of a deposit is ever seen.

The close is caught a second way as well:
- **`Compat.IsGuildBankVisible() == false`, checked in `disarmGuildBankIfGone`** (a file-local in
  `modules/Ledger.lua` that `Reconcile` calls on every pass), is the backstop for a frame
  that went away without hiding, and stops the addon rescanning six 98-slot tabs on every bag update.
  That check is three-valued: `nil` means "this build cannot tell" and deliberately does not disarm.

`/bl debug scan` reports whether the frame hooks are installed — a `NOT INSTALLED` there is the
explanation for a guild session that never starts, or never ends.

The guild bank also has a prerequisite the container stores do not: a tab holds **no data until it
has been queried** (`QueryGuildBankTab`), so only the tab the player is looking at is readable for
free. Arming queries every tab; the replies arrive asynchronously and reconcile like any other
change.
