# Midnight quirks

This file has two parts: the collection's client-quirks catalog, vendored whole from the Ka0s WoW Addon Standard between the markers below and never edited here, and then this addon's own quirks under `## BankLedger-specific quirks`.

<!-- BEGIN VENDORED: quirks catalog v2.102.2 (source: WowAddonStandards) -->
> Part of the **[Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards/blob/master/standards/STANDARDS.md)** — the split standard. This section is vendored whole into every addon's `docs/midnight-quirks.md` (§1), so its links are absolute. Cross-references use the `filename-§N` form (see the index's section map).

## Client quirks

The client behaviors the collection paid for more than once. Each entry here was discovered
**independently in two or more Ka0s repositories**, written up in each, and promoted by a harvest so the
next addon reads it instead of rediscovering it. A behavior one repo found stays in that repo's
`docs/midnight-quirks.md` until a second repo meets it.

*Why this section exists.* By 2026-11-06 eleven addons kept a private `docs/midnight-quirks.md`, 2,073
lines and about 133 entries between them, and about 81 of those entries were 21 behaviors written up
independently two to eight times. Nine of the eleven opened with their own restatement of the 12.0 secret
rules. Three write-ups contradicted this standard, and one contradiction was this standard's own error
(events-frames-taint-§2, *The combat-start edge*). A catalog was proposed and deferred twice, on
2026-08-25 and 2026-09-22, because an inventory rots; the build stamp per entry (§1) is the answer to that
objection (WowAddonStandards `harvests/2026-11-06/02_FINDINGS.md`, F3-01; every write-up quoted in
`harvests/2026-11-06/03_EVIDENCE.md`, Part A).

### 1. How an entry is written, and how it expires (MUST)

Every entry **MUST** carry:

- **The behavior**, stated as what the client does, not as advice.
- **Measured:** the client build or date it was observed on, where any write-up recorded one. An entry with
  no measurement says *not measured*; that is a weaker entry, not a missing field.
- **Cost:** what happened to an addon that did not know it.
- **Do:** the workaround, as a rule an addon can follow.
- **Source:** the deepest write-up — the repo and document that probed furthest — and the harvest that
  promoted it. Every version is quoted in that harvest's `03_EVIDENCE.md`.

**Expiry.** An entry describes a client, and clients move. When the retail interface number moves past the
newest *Measured* stamp in an entry and an addon observes otherwise, the entry is corrected in a standard
release — not worked around in the addon. An entry nobody can reproduce moves to §6 as an open probe rather
than being deleted, because the behavior may only have moved.

**What an addon does with this section (MUST): carry it as a vendored block.** This section is the one
part of the standard an addon carries a **copy** of, because it is reference data about the game client
that a working addon needs offline, next to the code that works around it — not a rule, which is only ever
pointed at. Every addon's `docs/midnight-quirks.md` (documentation-§3) is two parts: the vendored block,
opened by a `BEGIN VENDORED` HTML comment naming the catalog's version and source and closed by an
`END VENDORED` HTML comment, each spelled exactly as `/dev-copilot:wow-revendor-standards` writes it; then
the addon's own section. The markers are described here rather than shown, because this text travels
inside them: a literal marker in the vendored copy would give the file a second end marker for the next
re-vendor to cut at.

```markdown
[the BEGIN VENDORED comment, stamped quirks catalog v<X.Y.Z>]
… this section, whole …
[the END VENDORED comment]

## <Addon>-specific quirks

… the addon's own quirks: one no second repo has met, its per-event costs, its own probe tables …
```

- The block is **copied whole and replaced wholesale** by `/dev-copilot:wow-revendor-standards`, stamped with
  the standard version it came from, under the same discipline as `libs/LibKa0s/` (anti-pattern #45): never
  a subset, **never edited inside the markers**. A local edit inside them is reverted by the next revendor,
  and the behavior it fixed comes back with no cause in the addon's history; a correction belongs in the
  addon's own section, where the next harvest finds it.
- The addon's own section **MUST NOT** restate a behavior the block carries. When a harvest promotes an
  entry, the revendor prunes the addon's copy: the upstream entry is the deeper write-up, and two live
  copies of one finding is the shape that drifted three times into contradiction.
- An addon with no quirks of its own still carries the block, with an empty own section.

**Contested behaviors are not rules.** Where two repos recorded opposite behavior and nobody has probed
the difference, the entry goes in §6 with both sides and the probe that would settle it.

Behaviors this standard already states elsewhere are not repeated here: the unknown-event raise
(events-frames-taint-§1), `Settings.OpenToCategory`'s numeric ID and collapsed parent (options-ui-§2),
the protected category switch in combat (options-ui-§2, anti-pattern #88), a secret through `tostring` and
`..` (events-frames-taint-§8), lockdown at `PLAYER_REGEN_DISABLED` (events-frames-taint-§2), the spec
readers' move to `C_SpecializationInfo` (compat, `LibKa0s-Compat-1.0`) and `SendChatMessage`'s move to
`C_ChatInfo` (compat).

### 2. Secret values

**A secret boolean cannot be tested at all.** `if`, `not`, `==` and `and`/`or` on a secret boolean raise
("attempt to compare … (a secret boolean value)"); the value is unusable in Lua, not merely unprintable.
`DurationObject`'s `HasExpired`, `HasStarted`, `IsActive` and `IsZero` come back secret in combat, and an
engine button's `IsShown` has answered a secret boolean out of combat. *Measured:* 12.0.7 (probe table);
12.1 (`IsShown`). *Cost:* a raise on every refresh tick of the path that tests it. *Do:* check
`issecretvalue` before any test; route a secret boolean to a C-side consumer
(`C_CurveUtil.EvaluateColorValueFromBoolean`, `SetAlphaFromBoolean`), or treat it as the cautious answer
(a secret lockdown reads as locked, a secret restriction as active, a secret claim as no claim). Two repos
disagree on whether to gate before the C-side call; that disagreement is recorded in `LibKa0s`
`docs/api/Compat` and is not ruled here. *Source:* KickCD `docs/midnight-quirks.md`, "Secret booleans are
unusable"; seven repos (harvest 2026-11-06, Q6).

**A secret cannot be a table key.** Indexing or assigning with a secret key raises "attempted to perform
indexed assignment on a table that cannot be indexed with secret keys". `UnitGUID` on a follower-dungeon
pet (`party3pet`) answers a secret string. *Cost:* a raise on every refresh tick for a roster keyed by
GUID. *Do:* guard a key with `IsSafeKey` (`LibKa0s-Compat-1.0`) or `issecretvalue` before keying; a
secret GUID is never a handle. *Source:* MultiMeters `docs/midnight-quirks.md`, the follower-dungeon pet
GUID; seven repos (Q7).

**A secret never reaches SavedVariables, and one that does is written as `nil`.** A value captured as
secret stays secret after combat ends, and the client writes a secret to SavedVariables as `nil` — or,
where it was a key, loses the entry. *Measured:* a reload probe, 2026-10-25. *Cost:* silent data loss on
the next reload. *Do:* store a plain value or nothing; never store a captured secret to read later.
*Source:* DpsRace `docs/known-limitations.md`, the reload probe; three repos (Q21).

**A frame handed a secret has secret geometry, and so does everything anchored to it.** After
`StatusBar:SetValue(secret)` (or `SetAlphaFromBoolean`, or anchoring to an aura engine container) the
frame `HasSecretValues`: its width, points and frame level read secret, out of combat too, and the
taint runs down the anchor chain to every frame anchored to it; a tooltip showing hidden information has
secret geometry. A secret size's `type` is `"number"`, so a type check lets it through, and
`BackdropTemplate`'s own arithmetic on a secret size raises. *Cost:* a raise inside Blizzard code, or a
layout computed from a secret. *Do:* compute layout from configuration and never read geometry back from a
frame that was handed a value; keep a record of the alpha you set rather than calling `GetAlpha()`; read a
frame level under a restricted anchor through a secret-safe guard (frame-layering). *Source:* AuraMaster
`docs/midnight-quirks.md`, the aura engine container entries (measured and dated); six repos and
`LibKa0s` `docs/api/Widgets` (Q8).

**A restricted spell's cooldown: branch on `isActive`, paint with the duration object.** In a restricted
state `C_Spell.GetSpellCooldown`'s timings are secret while `isEnabled` and `isActive` stay plain
(documented NeverSecret). `GetSpellCooldownDuration` answers a **zeroed** object, not `nil`, when there is
no cooldown, and a fresh object per call. *Cost:* raw `SetCooldown` with a secret start or duration raises;
a nil check passes the zeroed object. *Do:* decide from `isActive`; paint with
`Cooldown:SetCooldownFromDurationObject`, which accepts the object from tainted code. *Source:* KickCD
`docs/midnight-quirks.md`, the cooldown probe table; four repos (Q9).

**`notInterruptible` is secret, and the interruptibility events make it plain.** The cast info's
`notInterruptible` is secret; `UNIT_SPELLCAST_INTERRUPTIBLE` / `_NOT_INTERRUPTIBLE` deliver it plain.
`CastingBarFrameTemplate`'s built-in `OnUpdate` compares `GetTime()` with a secret `maxValue` and raises
when the bar shows another unit. *Do:* split the gate — the color path takes the secret C-side, the logic
path takes the event's plain value; do not inherit `CastingBarFrameTemplate` for a unit other than the
player. *Source:* KickCD `docs/midnight-quirks.md`, "split the gate in two"; two repos (Q13).

**`InChatMessagingLockdown` can answer a secret.** *Do:* read it through a guard and treat a secret as
locked. *Source:* DropWatcher and QuickComms `core/Compat.lua` (byte-identical), DpsRace; three repos (Q27).

### 3. Events

**A valid event can register without complaint and never fire.** `GUILDBANKFRAME_OPENED` registers and
never fires (*Measured:* 12.0.7); `UNIT_SPELLCAST_SUCCEEDED` is suppressed for protected interrupts;
`UNIT_HEALTH` and `UNIT_NAME_UPDATE` never fire for compound tokens such as `party1target`;
`GET_ITEM_INFO_RECEIVED` does not fire for an item already cached. This is the inverse of the
unknown-event raise (events-frames-taint-§1) and it is silent: nothing errors. *Cost:* a feature that
never runs, with nothing in the log. *Do:* confirm a new event fires in game before building on it, and
prefer an edge with a second source (a frame's `OnShow`, a gated timer) where the event is known to be
silent. *Source:* BankLedger `docs/midnight-quirks.md`, `GUILDBANKFRAME_OPENED`; four repos (Q20).

**Client state can lag its own event, or change with no event at all.** `IsMounted()` has flipped by the
time `PLAYER_MOUNT_DISPLAY_CHANGED` arrives while `C_PlayerInfo.GetGlidingInfo`'s `canGlide` sometimes has
not; after `INSPECT_READY` some slots still answer an item id with no link; switching bank tabs fires no
event, and the live warband tab has taken over a second to catch up; chat lockdown clears with no event.
*Cost:* a read at the edge answers the old state, and the display stays wrong until the next unrelated
event. *Do:* answer at the edge **and once more after a short settle** (a fraction of a second, a bounded
retry), never a poll. *Source:* MultiMeters `docs/midnight-quirks.md`, "some client state lags its own
event"; six repos (Q19).

**An empowered cast fires `UNIT_SPELLCAST_EMPOWER_*`, not the channel events.** `UnitChannelInfo`
reports it, but `UNIT_SPELLCAST_CHANNEL_START` / `_STOP` do not fire for it, and its release fires
`UNIT_SPELLCAST_SUCCEEDED` with the same cast GUID. *Do:* register the `EMPOWER_*` events wherever channels
are tracked. *Source:* KickCD `docs/midnight-quirks.md`, empowered casts; three repos (Q12).

**`ADDON_RESTRICTION_STATE_CHANGED` fires *before* enforcement.** The `Activating` state arrives before the
restriction begins, and access is still permitted during that dispatch; a dungeon restriction type has
gone active on entry and not cleared. Read the restriction type by its `Enum.AddOnRestrictionType` member
name — a member can be missing on some builds. *Measured:* 12.1.0, 2026-09-18. *Do:* treat `Activating`
as the last moment to read, not as the start of the restriction. The payload's second argument is
contested (§6). *Source:* AuraMaster `docs/midnight-quirks.md`, the restriction types; six repos (Q10).

### 4. Combat and secure frames

**Blizzard's aura buttons are forbidden to addon code, and `IsForbidden()` can say otherwise.** In
combat every call on a Blizzard aura button's objects raises "Attempt to access forbidden object from code
tainted by an AddOn"; in an instance (seen in Mythic+) the same buttons answer `IsForbidden()` `false` and
still refuse every read, `GetChildren` included. *Do:* never read Blizzard aura buttons; where a frame
must be inspected, `pcall` the read and treat a failure as forbidden. *Source:* PartyFrameEnhanced
`docs/midnight-quirks.md`, forbidden aura buttons; three repos (Q14).

**Escape runs a protected `Hide()` in combat.** A secure or protected frame listed in `UISpecialFrames` is
hidden by `CloseSpecialWindows`, which is a protected action in combat. *Do:* list a non-secure proxy in
`UISpecialFrames` and hide the protected frame from it out of combat, or keep protected frames out of the
list. *Source:* WhatGroup `docs/midnight-quirks.md`, the escape proxy; two repos (Q24).

### 5. Item, tooltip, enum and realm data

**Item data is nil until cached, and the load event has holes.** `GetItemInfo` answers nothing for an
uncached item; `GET_ITEM_INFO_RECEIVED` does not fire on an addon's first scan for an item the client
already holds; an uncached item's tooltip is not empty but a legible `RETRIEVING_ITEM_INFO` line; a failed
load drops its wait and nothing asks again. *Cost:* a blank or wrong row that never repairs. *Do:* load
through `LibKa0s-Item-1.0`'s cache-then-callback path (library-stack-§7), treat `RETRIEVING_ITEM_INFO` as
not-yet-loaded, and re-ask after a failed load. *Source:* ConsumableMaster `docs/midnight-quirks.md`, the
first-scan hole; seven repos (Q15).

**`C_TooltipInfo` returns raw templates.** Tooltip lines can carry the unexpanded plural grammar
`|4singular:plural;` (*Measured:* 12.1.5, "for the next 3 |4hour:hrs; 49 min") and a no-break space that
Lua's `%s` does not match. *Cost:* a parser that knew only the expanded words read no duration and called a
tradeable drop expired. *Do:* expand `|4…;` before matching, and match the no-break space explicitly.
*Source:* DropWatcher `docs/midnight-quirks.md`, the trade window; two repos (Q16).

**Tooltip line text can be secret** under an addon restriction, including through `TooltipDataProcessor`.
*Do:* guard each line before matching. *Source:* DropWatcher `docs/midnight-quirks.md`; two repos (Q17).

**Blizzard renumbers enums; resolve a member by name, never by number.** One build's
`Enum.TooltipDataLineType` and bank-tab values are not the next build's, and a member can be absent on a
build. *Cost:* a numeric guess for a member the build does not expose landed on an unrelated bank
container. *Do:* read `Enum.X.Member`, and handle its absence; localization-§4 already forbids the string
spelling. *Source:* DropWatcher `docs/midnight-quirks.md`, the research's enum values; five repos (Q18).

**`GetNormalizedRealmName` is nil early in login.** *Cost:* a stored `Name-` key with no realm. *Do:* never
build a `Name-Realm` key before the realm is known; defer, or fall back to `GetRealmName` with its spaces
and hyphens removed. *Source:* DropWatcher `docs/midnight-quirks.md`, realm names; four repos (Q25).

**A template-less `FontString` with no font raises on `SetText`.** "Font not set" from a `FontString`
created without a template or `SetFontObject` takes the addon down at load; a mock that does not enforce it
passes every test. *Do:* give every bare `FontString` a font object before its first `SetText`; the kit's
mock enforces it. *Source:* MultiMeters `tests/mock_frame.lua`, the font-not-set guard; three repos and
`LibKa0s` (Q22).

### 6. Open probes — contested behaviors (not rules)

Each needs an in-game probe, recorded with the build, before any section of this standard changes.

- **`string.format` on a secret.** events-frames-taint-§8 says it raises, with three repos; two say it
  works, one with a mid-combat observation. The likely difference is the specifier (`%s` against `%d` and
  `%.1f`) or that the result is itself a secret string. Probe each specifier, in combat, on a damage-meter
  value and a `UnitHealth` value. Until then §8's rule stands.
- **`ADDON_RESTRICTION_STATE_CHANGED`'s second argument.** One repo documents an
  `Enum.AddOnRestrictionState` value; three (one measured) record a boolean as well. Handle both shapes.
  The 2026-09-22 harvest called this settled, and it is not.
- **`SetAllPoints(parent)` on a secure button at load.** One repo records "Cannot anchor protected frames
  to regions" and uses the implicit-parent form; another anchors its secure rows with `SetAllPoints(row)`
  at birth and treats it as working, with its in-game smoke check still owed.
<!-- END VENDORED -->

## BankLedger-specific quirks

Client behavior this addon works around, and why each workaround is shaped the way it is. Every entry
here is something the client does that a reasonable reading of the API would not predict — which is
exactly why it needs writing down rather than rediscovering.

## The guild bank has no usable open event, and no usable close event either

`GUILDBANKFRAME_OPENED` is a **valid name that registers without complaint and never fires** on
12.0.7. So is `GUILDBANKFRAME_CLOSED`. Registering them bought nothing but two dead rows in
`/bl debug scan`, so the addon no longer asks for them, and an addon that trusts them tracks the
guild bank not at all.

- **Open** is stood in for by `GuildBankFrame`'s own `OnShow` (`Ledger:HookGuildBankFrame`). It fires
  when the player is demonstrably looking at the vault, before anything can be moved, which is
  exactly when the baseline wants taking. It never steals the context from an already-open bank frame.
- **Close** is caught two ways, because neither alone is sufficient. The same frame's `OnHide` is the
  real close path — it has to be a hook rather than a check inside `Reconcile`, because closing the
  window changes no container and moves no money, so no event fires and no reconcile pass ever runs.
  The backstop is `Compat.IsGuildBankVisible() == false`, checked by `disarmGuildBankIfGone` on every
  pass, for a frame that went away without hiding.

`GuildBankFrame` lives in `Blizzard_GuildBankUI`, loaded on demand, so it does not exist until the
player opens a guild bank for the first time in a session — and that first open is the one whose
`OnShow` would otherwise be missed. `Ledger:OnAddonLoaded` installs both hooks the moment that addon
lands; `Enable` and `OnGuildBankData` retry, idempotently.

`/bl debug scan` reports whether the frame hooks are installed. A `NOT INSTALLED` there is the
explanation for a guild session that never starts, or never ends.

### Tab data arriving is NOT the guild bank being open

It was, until issue #12. `GUILDBANKBAGSLOTS_CHANGED` looks like a proxy for "the player is at the
vault" and is not one: the server pushes tab contents on login and reload sync, and again whenever
**another guild member** moves something. Neither involves the player being anywhere near a bank.
Arming on it opened a banking session in the middle of a field, and the session could not end —
with `Blizzard_GuildBankUI` unloaded there is no frame, `IsGuildBankVisible()` answers `nil` rather
than `false`, and the disarm backstop rightly refuses to act on `nil`. The event is now a reconcile
cue that arms only on an explicitly visible window.

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
(`NS.RegisterEventSafely`, front-gated on `C_EventUtils.IsEventValid`), rejected names are recorded
in `NS.EventRecord.unavailable`, and
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

It renders a box for both, and so do most skin faces. The History table's Direction column, the
session window's and the Direction filter dropdown draw those glyphs in JetBrains Mono, which arrives with the LibKa0s payload — sanctioned by
`debug-logging-§2`, which names direction markers in a table cell as its example and states that an
audit must not flag it.

**This is the one arrow pair that stayed a character.** The History column-header sort arrows and the
group-header expanders are textures now — the collection's `sort-up` / `sort-down` and
`chevron-right` / `chevron-down` marks, each carrying a vertex-color tail that paints it the
header's fixed gold. The direction glyph does **not** follow them, and the reason is COLOR: those
four are ONE color written down in one place, while the direction glyph takes the direction's red
or green per row from the same `SetTextColor` that paints the label beside it — a mark there would
need a second tail rebuilt per row and kept in step with it by hand. Alignment is not part of the argument — the Blizzard arrow art on the lower rung of those two
marks is what a degraded install draws and what smoke check DEGRADED-9 tells a tester is CORRECT there, so a
claim here that it sits visibly off-baseline would wave a real degraded-install regression through as
a known quirk. See [media.md](media.md).

## Void storage and the reagent bank are gone

Midnight removed both. Reagents live in the character-bank tabs now, and the client exposes neither
events nor a container for void storage. `StoresFor`'s empty-group guard is what makes a retired
container degrade to "not on this build" instead of a permanently empty store in every debug line —
and Blizzard will retire another one, so the guard stays regardless. See [scope.md](scope.md).
