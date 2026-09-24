Delta: LibKa0s v1.16.0 -> v1.54.2 (span: v1.16.0 v1.17.0 v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.43.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.54.2)

# 01 — Delta: the consolidated span bundle

Written 2026-09-24 for plan item BL-23 of the 2026-09-23 review and standards-audit remediation
(finding BankLedger-A-01, audit row BL-41), on branch `feat/2026-09-23-review-audit-remediation`.
It is the sanctioned record for a lapsed span (`audit-review-history`, standard v2.65.0): one folder
named for the first and last unrecorded tags, holding `01_DELTA.md` and `05_SUMMARY.md` only. The
re-vendors it records were each done and gated when they landed; nothing is re-vendored here and no
code changes. The per-tag deliberation files (02 to 04) are absent on purpose: a span carried by
sweeps had none to record, and per-tag back-fill folders are not written.

## The true previous base

The span's line-1 endpoints are the first and last **unrecorded** tags, not a delta base. The last
tag this store recorded before the span is **v1.15.0** (`docs/revendor/2026-08-25/`, the store's
first bundle and the audit horizon). The payload at the start of the span, vendored at `1361f22`
("chore(libs): re-vendor LibKa0s v1.15.0"), is that tag. Read as a delta, the span runs
**v1.15.0 -> v1.54.2**, and the next recorded bundle, `docs/revendor/2026-09-23-v1.55.0/`, correctly
names v1.54.2 as its base (vendored at `6b12edf`).

Seven tags inside that range already have their own bundles and are **not** in the span list:
v1.25.0 (`2026-09-03/`), v1.30.0 (`2026-09-12/`), v1.31.0, v1.32.0, v1.33.0 (`2026-09-12-v1.3x.0/`)
and v1.34.0 (`2026-09-13-v1.34.0/`). Two of the bare-dated ones name a second tag on line 1 as their
base (v1.24.0 in `2026-09-03/`, v1.29.0 in `2026-09-12/`). The audit check reads only the last tag of
a bare-dated line 1, so those two count as unrecorded and are listed here.

Tags the library cut that this addon never vendored are not in the span either, because nothing
here ever carried them: v1.20.0, v1.21.0, v1.22.0, v1.40.0, v1.41.0, v1.46.0, v1.48.0, v1.48.1,
v1.49.0, v1.49.1, v1.54.0 and v1.54.1.

## How the list was derived

The `AUDIT.md` re-vendor comparison (WowAddonStandards v2.65.0), run before this bundle existed:

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)          # -> 2026-08-25
git log --since="$horizon 00:00" --format=%H -- libs/LibKa0s tests/_kit | while read -r c; do
  git show "$c:CLAUDE.md" 2>/dev/null |
    grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' |
    grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1
done | sort -uV > vendored.txt                                        # 38 tags
# recorded.txt: the recorded-side loop over docs/revendor/*/           # 9 tags
grep -vxF -f recorded.txt vendored.txt                                 # 29 tags, the span above
```

Every in-scope commit resolved a tag from its `CLAUDE.md` provenance line, so no README.md
fallback was needed. After this bundle, the same comparison prints nothing.

**Correction to the item text.** BL-23 and the audit (BL-41) named 25 tags, v1.18.0 to v1.53.0, and
36 commits. That count used a bare-date `--since`, which drops the horizon day's own commits
(v1.16.0 and v1.17.0 on 2026-08-25), and walked `libs/LibKa0s` alone, which misses the kit-only
v1.43.0 and v1.54.2 re-vendors. The v2.65.0 comparison finds 29 tags in 33 commits. The folder is
named for the span it actually covers, `2026-09-24-v1.16.0-v1.54.2`, not the item's
`v1.18.0-v1.53.0`.

## The 33 vendoring commits

"Sweep" means the same tag was re-vendored the same day into the sibling Ka0s addons, as read from
each sibling's `git log -- libs/LibKa0s tests/_kit` subjects (the count is how many of the ten
siblings name the tag in a subject). "Folded" means the copy rode inside a BankLedger feature
commit rather than standing alone (`versioning-git` makes that a SHOULD, not a MUST).

| Tag | Commit | Date | Subject | Carried by |
|---|---|---|---|---|
| v1.16.0 | `4455ea6` | 2026-08-25 | Re-vendor LibKa0s v1.16.0 | sweep, 8 siblings |
| v1.17.0 | `8bde943` | 2026-08-25 | Re-vendor LibKa0s v1.17.0 | sweep, 3 siblings |
| v1.18.0 | `4077fb1` | 2026-08-26 | Adopt options-ui-§12: Reset Everything is wholesale, not a list of things | folded; sweep, 3 siblings |
| v1.18.1 | `c9ced65` | 2026-08-26 | Re-vendor LibKa0s v1.18.1: the landing logo stops pooling its texture | sweep, 8 siblings |
| v1.19.0 | `8a1c7c6` | 2026-08-27 | Carry LibKa0s v1.19.0 | sweep, 8 siblings |
| v1.23.0 | `bd16e58` | 2026-09-01 | Carry LibKa0s v1.23.0 | sweep, 8 siblings |
| v1.24.0 | `ab62071` | 2026-09-02 | feat(settings): master controls, and the Filters page folded into General | folded (settings-revamp-v2 branch, merged `0aec078`) |
| v1.26.0 | `92df67f` | 2026-09-08 | M3-05: re-vendor LibKa0s v1.26.0 | 2026-09-07 remediation plan (merged `40c4f86`); sweep, 8 siblings |
| v1.27.0 | `c9ac140` | 2026-09-08 | M4-01: adopt LibKa0s v1.27.0, and wire the gate that came with it | 2026-09-07 remediation plan; sweep, 8 siblings |
| v1.28.0 | `3676707` | 2026-09-09 | re-vendor LibKa0s v1.28.0 — the perf usage block renders correctly | sweep, 8 siblings |
| v1.29.0 | `5ba82ca` | 2026-09-09 | re-vendor LibKa0s v1.29.0 — the JSON dump folds into the report step | sweep, 8 siblings |
| v1.35.0 | `b4e0a04` | 2026-09-13 | Re-vendor LibKa0s v1.35.0 (Options 18.16.5.3, kit 20) | feat/2026-09-13-idlist (merged `fca36b2`); sweep, 9 siblings |
| v1.35.0 | `a91c384` | 2026-09-13 | Re-vendor LibKa0s v1.35.0 (re-cut: IdList quality color, load batching, clear before onAdd) | same branch, tag re-cut |
| v1.35.0 | `f2164c9` | 2026-09-13 | Re-vendor LibKa0s v1.35.0 (re-cut: autocomplete #31, name lookup beyond the bags) | same branch, tag re-cut |
| v1.35.0 | `710fa93` | 2026-09-14 | Re-vendor LibKa0s v1.35.0 (re-cut at 80b8d15: shared names the bags carry, stale highlight) | same branch, tag re-cut |
| v1.35.0 | `958e2b6` | 2026-09-14 | Re-vendor LibKa0s v1.35.0 (re-cut: host kinds inherit a base kind's decorations) | same branch, tag re-cut |
| v1.36.0 | `73733e2` | 2026-09-15 | Re-vendor LibKa0s v1.36.0 | chore/2026-09-14-revendor-v1.36.0 (merged `47f4c39`); sweep, 9 siblings |
| v1.36.1 | `b97fab0` | 2026-09-15 | Re-vendor LibKa0s v1.36.1: fix pooled CheckBox gold-fill leak | same branch; sweep, 9 siblings |
| v1.36.2 | `8a43e84` | 2026-09-15 | Re-vendor LibKa0s v1.36.2: drop grid-cell yellow fill, ASCII-only strings | same branch; sweep, 9 siblings |
| v1.37.0 | `c2391e5` | 2026-09-16 | Re-vendor LibKa0s v1.37.0 | sweep, 10 siblings |
| v1.38.0 | `beaf599` | 2026-09-16 | Re-vendor LibKa0s v1.38.0: a bare /bl opens the settings panel | sweep, 10 siblings |
| v1.39.0 | `08c14b6` | 2026-09-16 | Re-vendor LibKa0s v1.39.0: the launcher major arrives | sweep, 10 siblings |
| v1.42.0 | `a769125` | 2026-09-17 | Disabling the addon stands it down, and a perf run takes the same latch | folded (the stand-down feature) |
| v1.43.0 | `8a7856c` | 2026-09-17 | Re-vendor LibKa0s v1.43.0: kit revision 23 bounds every run and stops holding built instances | sweep, 10 siblings (kit only) |
| v1.44.0 | `26d6e7e` | 2026-09-19 | Re-vendor LibKa0s v1.44.0 | chore/libka0s-v1.44.0 (merged `68a1bb0`); sweep, 10 siblings |
| v1.45.0 | `7b464c2` | 2026-09-19 | Re-vendor LibKa0s v1.45.0 | chore/libka0s-v1.45.0 (merged `78e0cd0`); sweep, 9 siblings |
| v1.46.1 | `7fea97d` | 2026-09-19 | Re-vendor LibKa0s v1.46.1 | chore/libka0s-v1.46.1 (merged `0edcff4`); sweep, 10 siblings |
| v1.47.0 | `f5ed237` | 2026-09-20 | Re-vendor LibKa0s v1.47.0 | chore/revendor-libka0s-v1.47.0 (merged `77ae6f2`); sweep, 9 siblings |
| v1.50.0 | `3e9e5f5` | 2026-09-21 | Re-vendor LibKa0s v1.50.0 | sweep, 10 siblings |
| v1.51.0 | `2cd25c4` | 2026-09-22 | Re-vendor LibKa0s v1.51.0 | sweep, 10 siblings |
| v1.52.0 | `82df6e3` | 2026-09-22 | Re-vendor LibKa0s v1.52.0 | sweep, 10 siblings |
| v1.53.0 | `cb79c2c` | 2026-09-22 | Re-vendor LibKa0s v1.53.0 | sweep, 10 siblings |
| v1.54.2 | `6b12edf` | 2026-09-22 | Adopt the kit's US-English gate, and delete the copy this repo was keeping | folded (kit revision 24; library bytes identical to v1.53.0) |

v1.24.0, v1.42.0 and v1.54.2 show no sibling subject naming the tag. A copy folded into a feature
commit does not name its tag in the subject, so the table claims no sweep for them either way.

Each commit copied both payloads whole from the tag and rolled the provenance line in the same
commit, which `tests/test_vendor_sync.lua` enforces. Each was green on lint and the headless suite
when it landed; the commit bodies record the counts.
