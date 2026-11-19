Delta: LibKa0s v1.106.0 -> v1.106.0 (span: v1.106.0)

Written 2026-11-19 by AF-RV-BL, beside `../2026-11-19-v1.107.0/`. A records-only back-fill: the one tag this addon vendored without a bundle. No code, library or kit file moved because of it.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-08-25
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
# -> vendored.txt ends ... v1.92.0 v1.93.0 v1.105.0 v1.106.0
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.106.0
```

v1.106.0 was vendored by `f37cc1d` ("Re-vendor LibKa0s v1.106.0", Widgets minor 28: the HUD dock guards its measurements, RangeMaster#17), base v1.105.0, as a one-file copy of `libs/LibKa0s/Widgets.lua` with the provenance roll; the kit stayed at revision 57.
