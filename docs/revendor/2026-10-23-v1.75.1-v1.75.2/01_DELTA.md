Delta: LibKa0s v1.75.1 -> v1.75.2 (span: v1.75.1 v1.75.2)

# 01 — Delta, consolidated span (BankLedger)

Written 2026-10-23 by item BL-RV of the cross-repo run "sim auto-run, QC preview selector, mode
strips, MM/KCD simulators", beside the v1.76.0 bundle. Two tags were vendored on 2026-10-23 by
post-run fix branches and got no bundle of their own:

- v1.75.1 (`39dfb98`, SimPanel minor 3: a disabled row or control still shows its tip), vendored by
  `14d2709` "Re-vendor LibKa0s v1.75.1 (SimPanel minor 3)";
- v1.75.2 (`154599c`, SimPanel minor 4: the picker's scenario dropdown fits its label), vendored by
  `1db0583` "Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)".

Both were sweeps: the payload moved and the provenance line rolled in the same commit, and no
library surface was adopted.

## The listing (the re-vendor check of `AUDIT.md`, Step 3h of `/dev-copilot:wow-revendor-libka0s`)

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)        # 2026-08-25
# vendored: tags named by the provenance line at every payload commit and every line roll since
# the horizon; recorded: the tags each bundle folder (or its 01_DELTA.md line 1) names
grep -vxF -f recorded.txt vendored.txt
```

Output, before this run's copy:

```
v1.75.1
v1.75.2
```

```sh
git -C ../LibKa0s log --oneline v1.75.0..v1.75.2
```

```
154599c SimPanel minor 4: the picker's scenario dropdown fits its label (v1.75.2)
54e2bcb Merge branch 'fix/2026-10-23-sim-tooltips-pushed-loot' (LibKa0s v1.75.1: SimPanel minor 3)
39dfb98 SimPanel minor 3: a disabled row or control still shows its tip (v1.75.1)
3b22193 Merge branch 'feat/2026-10-22-libka0s-issues-45-58' (LibKa0s v1.75.0: issues #45-#58)
ba14d7e SD: sync docs before merge of the LibKa0s #45-#58 run
a0d7be5 LK-23: consumer census restamped at v1.75.0; step 8 recorded
```

`git -C ../LibKa0s diff --stat v1.75.0 v1.75.2 -- LibKa0s testkit` reports one file,
`LibKa0s/SimPanel.lua` (23 insertions, 3 deletions); kit revision 41 throughout.
