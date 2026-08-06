# Midnight quirks

Client behavior this addon works around, and why each workaround is shaped the way it is. Every entry
here is something the client does that a reasonable reading of the API would not predict — which is
exactly why it needs writing down rather than rediscovering.

## The guild bank has no usable open event, and no usable close event either

`GUILDBANKFRAME_OPENED` is a **valid name that registers without complaint and never fires** on
12.0.7. So is `GUILDBANKFRAME_CLOSED`. Registering them costs nothing and buys nothing, and an addon
that trusts them tracks the guild bank not at all.

- **Open** is stood in for by the arrival of tab **data** — `GUILDBANKBAGSLOTS_CHANGED`. The first one
  lands as the window opens, before anything can be moved, which is exactly when the baseline wants
  taking. It never steals the context from an already-open bank frame.
- **Close** is caught two ways, because neither alone is sufficient. `GuildBankFrame`'s own `OnHide`
  (`Ledger:HookGuildBankFrame`) is the real close path — it has to be a hook rather than a check
  inside `Reconcile`, because closing the window changes no container and moves no money, so no event
  fires and no reconcile pass ever runs. `GuildBankFrame` lives in `Blizzard_GuildBankUI`, loaded on
  demand, so the hook is installed the first time the guild bank is in play, once only. The backstop
  is `Compat.IsGuildBankVisible() == false`, checked by `disarmGuildBankIfGone` on every pass, for a
  frame that went away without hiding.

`/bl debug scan` reports whether the close hook is installed. A `NOT INSTALLED` there is the
explanation for a guild session that will not end.

## A guild-bank tab holds no data until it has been queried

Unlike a container store, only the tab the player is currently looking at is readable for free.
Arming the context therefore calls `QueryGuildBankTab` for **every** tab; the replies arrive
asynchronously and reconcile like any other change. An addon that reads the tabs directly sees five
empty ones and one real one.

## `GetGuildBankMoney()` returns 0, not nil, when the frame is closed

A perfectly plausible balance that would corroborate a purse change and write a fabricated gold row.
The guild money read is gated on `Compat.IsGuildBankVisible()` for that single reason. The warband
balance has no such problem — `C_Bank.FetchDepositedMoney(Enum.BankType.Account)` is not frame-bound.

## Modern retail raises on an unknown event name

It does not ignore it. A bare registration loop therefore turns **one** retired event into a silently
deaf addon: every registration after the throw goes unbound, with no visible error unless the player
has script errors switched on. Registration is isolated per event
(`Ledger:RegisterEventSafely`), rejected names are recorded in `Ledger.unavailableEvents`, and
`/bl debug scan` reports them.

## The bank window hosts two stores behind one event

The retail bank window shows the character bank **and** the warband tabs, and switching between those
tabs fires **no event at all** — so an addon cannot know which tab is on screen. The addon does not
try: it tracks the open **frame**, measures every store that frame can reach, and lets the "both sides
must change" rule decide which store was actually used. Tab switching becomes a non-event because
every tab was already measured. See [data-flow.md](data-flow.md) → *Frames, not stores*.

## One movement arrives as several events, seconds apart

The bags update on `BAG_UPDATE_DELAYED`; the warband tabs update on their own beat, and the live
warband tab has been observed taking **over a second** to catch up. Reconciling per event splits one
movement across two passes, and the "both sides must change" rule then rejects both halves.

Two mechanisms handle it, and they are not the same mechanism:

- **Debouncing** (`Ledger.DEBOUNCE_SECONDS`, 0.35s) lines passes up with user actions and collapses
  several full container scans per action into one. It cannot cover a gap of seconds.
- **Holding the baseline** (`SETTLE_TIMEOUT_SECONDS`) is what covers that gap: a pass that sees a
  one-sided change keeps the old baseline, so the half that already happened is still visible when the
  other half lands. The wait is **event-driven, not polled** — a warband tab is a container, so the
  client updating it fires `BAG_UPDATE_DELAYED` and drives the re-check by itself; the timer is only a
  give-up deadline, re-armed on the remaining window so event traffic cannot push it out.

If it never balances — an item looted into the bags while the bank happened to be open — the baseline
re-anchors after the timeout, so a stale delta cannot later pair with something unrelated.

## `GetItemInfo(itemID)` can only ever answer with the base item

Item level, tertiaries and sockets live in a link's **bonus IDs**, and a snapshot's counts are keyed
by `itemID`. So the scan keeps a side table, `snapshot.links = { [itemID] = hyperlink }` (the first
link seen for an id), the diff passes it onto the movement as `move.link`, and `BuildEntry` prefers it
over the derived link. This is what lets the CSV's `wowhead` column point at the variant that actually
moved.

One id resolves to one link per snapshot — exact for gear, which does not stack, and irrelevant for
stackables, which carry no bonuses.

## The `..` operator propagates secretness without raising

So a secret-value detector built on `..` lets a combat-protected value through to the real concat and
crashes there. The shared secret-safe printer probes `table.concat` instead
(`events-frames-taint-§8`).

## WoW's default font has no ▲ or ▼

It renders a box for both. The History table's Direction column and the Direction filter dropdown draw
those glyphs in the vendored JetBrains Mono — sanctioned by `debug-logging-§2`, which names direction
markers in a table cell as its example and states that an audit must not flag it. The alternative is a
texture, and Blizzard's arrow art carries uneven padding (up sits low in its canvas, down sits high),
so a texture pair visibly misaligns against the row text. See [media.md](media.md).

## Void storage and the reagent bank are gone

Midnight removed both. Reagents live in the character-bank tabs now, and the client exposes neither
events nor a container for void storage. `StoresFor`'s empty-group guard is what makes a retired
container degrade to "not on this build" instead of a permanently empty store in every debug line —
and Blizzard will retire another one, so the guard stays regardless. See [scope.md](scope.md).
