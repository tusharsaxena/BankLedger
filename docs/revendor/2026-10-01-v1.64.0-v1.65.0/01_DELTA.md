Delta: LibKa0s v1.64.0 -> v1.65.0 (span: v1.64.0 v1.65.0)

# 01 — Delta: the consolidated span bundle

Written 2026-10-01 by GI-BL-RV, beside `docs/revendor/2026-10-01-v1.66.0/`. Two tags this addon
vendored were never recorded: v1.64.0 (re-vendored by `2a3f637` DL-BL-01, and the re-cut final by
`99c348c` DL-BL-03) and v1.65.0 (`477c782` DG-BL-01). Each re-vendor was gated when it landed;
nothing is re-vendored here. The base before the span is v1.63.0
(`docs/revendor/2026-09-29-v1.63.0/`).

The listing (the standards audit's re-vendor check, run from the repo root before this run's copy):

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)
# vendored: the provenance tag at every payload commit and every CLAUDE.md roll since the horizon
# recorded: the tags named by every docs/revendor/ folder
grep -vxF -f recorded.txt vendored.txt
```

```
v1.64.0
v1.65.0
```
