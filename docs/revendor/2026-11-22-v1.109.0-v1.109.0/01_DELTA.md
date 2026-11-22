Delta: LibKa0s v1.109.0 -> v1.109.0 (span: v1.109.0)

Written 2026-11-22 by K101-BL-01, beside `../2026-11-22-v1.110.0/`. A records-only back-fill: the one tag this addon vendored without a bundle. No code, library or kit file moved because of it.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-08-25
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
# -> vendored.txt ends ... v1.106.0 v1.107.0 v1.108.0 v1.109.0
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.109.0
```

v1.109.0 was vendored by `bccba40` ("FU-RV-BL: Re-vendor LibKa0s v1.109.0 (kit revision 59) ...") and `c38e2d6` (the re-copy of `Compat.lua` minor 5 and `Sim.lua` minor 4 from the re-cut tag), base v1.108.0, in the sync-followups run (Ka0sAddonsCommonTasks `docs/2026-11-21-SYNC_FOLLOWUPS/`).
