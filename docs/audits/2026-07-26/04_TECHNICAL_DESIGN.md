# 04 · Technical design — 2026-07-26

How the open deviations in `02_DEVIATIONS.md` get closed. Nothing here needs a code change beyond
one asset drop and one README insertion.

## BL-01 · Ship the logo

Everything downstream of the asset already exists, so this is purely an art drop.

| Piece | Already in place |
|---|---|
| Runtime path constant | `NS.Constants.LOGO_PATH` = `Interface\AddOns\BankLedger\media\logos\bankledger.logo.tga` |
| Landing-page slot | `buildMainContent` in `settings/Panel.lua` — a `SimpleGroup` of `LOGO_SIZE` (300) with a texture anchored top-left |
| Folder | `media/logos/` |
| README reference | `![Logo](media/logos/bankledger.logo.jpg)` |

**Work:** author the art at a power-of-two source size (512×512), export
`media/logos/bankledger.logo.tga` for runtime and keep `bankledger.logo.jpg` beside it as the
editable source. WoW cannot load `.jpg`/`.png` textures at runtime, which is why both forms ship.

**Risk:** none. A missing texture renders nothing today; a present one renders at 300×300.

## BL-02 · Add the screenshots section

**Work:** capture four images — the History tab with data, the Insights tab, Settings ▸ General and
Settings ▸ Filters — into `media/screenshots/`, then insert a `## Screenshots` section into
`README.md` **between** `## What's new in <X.Y.Z>` and `## Usage`, with a caption per image.

**Constraint:** documentation-§1 fixes the relative order of the optional sections, so it goes in
that slot and nowhere else.

## BL-03 · Add the packaging id at first publish

**Work:** in the same change that publishes to CurseForge, add
`## X-Curse-Project-ID: <id>` to the TOC — after `X-Standard`, keeping the Curse → Wago → WoWI
order — and add the live version badge to the README badge row as badge **#2**, between `[wow]` and
`[license]`:

```markdown
![CurseForge Version](https://img.shields.io/curseforge/v/<projectId>)
```

`X-Wago-ID` / `X-WoWI-ID` stay omitted unless the addon is actually listed there.

## BL-04 · Localization pass

**Work:** wrap user-facing strings at their call sites as `NS.L["English source string"]`, keeping
the English text itself as the key so a missing translation falls back to English. Add locale-gated
files (`locales/deDE.lua` and friends, each opening with
`if GetLocale() ~= "deDE" then return end`) and list them in the TOC's `# Locales` section.

**Constraint:** the addon already matches game data on stable ids and tokens — `itemID`, `classFile`,
`Enum.BagIndex` members — never on a localized display string, so the input side needs no work.

## BL-05 · Roster row

**Work:** in the `WowAddonStandards` repo, add a Bank Ledger row to `standards/ADDONS.md` matching
the surrounding rows' shape. Proposed content:

> **Bank Ledger** — `BankLedger` — a passbook of item and gold movements between the player's bags
> and the character, reagent, warband, guild and void-storage banks; snapshot-diff capture, a
> standalone browser with History and Insights tabs, and CSV export.

**Constraint:** this is a different repository, so it is a separate commit there, not here.
