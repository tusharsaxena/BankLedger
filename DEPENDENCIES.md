# Dependencies — Ka0s Bank Ledger

What you need installed to build, run, test or release this addon. Every entry below names the
thing that needs it and where that is visible in the repo; nothing here is listed on a hunch.

The development environment for the Ka0s collection is **WSL2 running Ubuntu**, so the install
commands are written for that and are meant to be pasted as they stand. This file answers *what to
install*; [`docs/testing.md`](docs/testing.md) answers *how to verify* — neither repeats the other
(documentation-§7).

---

## 1. Runtime (in-game) — what a player needs

**World of Warcraft (Retail). Nothing else.**

- The TOC targets `## Interface: 120007` (`BankLedger.toc:1`) — Midnight 12.0.7. Retail only; there
  is no Classic build.
- There is **no** `## Dependencies` line. The `## OptionalDeps` line (`BankLedger.toc:8`) names
  Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibDataBroker-1.1 and LibDBIcon-1.0, and
  every one of them is **vendored** under `libs/` and committed (`BankLedger.toc:16-29`,
  `.pkgmeta:3`). `OptionalDeps` here only asks the client to load a standalone copy *first* if the
  player happens to have one; it never means the player must install anything.
- LibKa0s ships inside the addon the same way — `libs/LibKa0s/LibKa0s.xml` (`BankLedger.toc:29`),
  v1.5.0 per `README.md:11`.
- The bundled JetBrains Mono font (`media/fonts/JetBrainsMono-Regular.ttf`) and the logo art under
  `media/logos/` are **assets, not dependencies**: they ship in the package and need no tooling to
  use.

## 2. Development — the contributor toolchain

Install all four. Everything in this section is needed to run the green gate.

### Lua 5.1 — a hard requirement, not a preference

The headless harness loads each source file and swaps its environment with **`setfenv`**
(`tests/_kit/loader.lua:31` and `:50`). `setfenv` was **removed in Lua 5.2**, so 5.2, 5.3 and 5.4
cannot run this suite at all — this is not a "5.1 is what WoW uses, so we match it" preference, it
is the interpreter the runner requires. (WoW does also run 5.1, which is why the addon code is
written to that dialect in the first place.)

```sh
sudo apt update && sudo apt install -y lua5.1
```

**Verify:** `lua5.1 -v` → `Lua 5.1.5`.

> On Ubuntu the `lua` command may be unversioned or may not exist. `docs/testing.md` and
> `tests/run.lua:2` both spell the command as `lua tests/run.lua`, so make sure plain `lua` resolves
> to 5.1 (`lua -v` should also say `Lua 5.1.5`); if it does not, run `lua5.1 tests/run.lua` instead.

### luacheck — the lint half of the green gate

`luacheck .` is one of the two commands that must pass before every commit
(`docs/testing.md:6-14`), and the repo carries a real configuration for it (`.luacheckrc`) that
declares the WoW globals and the `BankLedgerDB` SavedVariables global. It installs through
LuaRocks:

```sh
sudo apt install -y lua5.1 luarocks && sudo luarocks install luacheck
```

**Verify:** `luacheck --version` → `Luacheck: 1.2.0` (or any recent release — the version is not
pinned and nothing here depends on one).

### lizard — the complexity report

Generates `docs/complexity.md`, regenerated and reviewed **at every release** (performance-§10). It
is a report, not a gate: a missing `lizard` means the committed report is stale, not that the addon
is broken.

Ubuntu 24.04 marks its system Python **externally managed** (PEP 668), so **`pip install lizard`
fails** with an `externally-managed-environment` error. Use `pipx`:

```sh
sudo apt install -y pipx && pipx ensurepath && pipx install lizard
```

Open a new shell (or `source ~/.profile`) afterwards so `~/.local/bin` is on `PATH`.

**Verify:** `lizard --version` → `1.23.0` (any recent release; not pinned).

<details>
<summary>Documented alternative, if you would rather not use pipx</summary>

`pip3 install --user --break-system-packages lizard` also works. The flag exists precisely to
override PEP 668, and it installs into the same `~/.local/bin`. It is the alternative rather than
the instruction because it writes into the system Python's user site, which is what PEP 668 is
trying to stop.

</details>

### git and a POSIX `ls` — the suite shells out

Two suites run external commands, so they are dependencies of `lua tests/run.lua` even though no
Lua code `require`s them:

- **`git`** — `tests/test_vendor_sync.lua:53` runs `git -C <path> …` against the **sibling LibKa0s
  checkout** to compare the vendored payload against the tag the README names.
- **`ls`** — `tests/test_harness.lua:24` runs `ls tests/test_*.lua` to prove the suite list and the
  files on disk agree in both directions, and `tests/test_vendor_sync.lua:89` runs `ls -A` to list a
  vendored directory (Lua 5.1 has no directory API and this repo deliberately does not depend on
  LuaFileSystem — `tests/test_vendor_sync.lua:74-76`).

Both are present on any Ubuntu install; `git` is the only one that might not be.

```sh
sudo apt install -y git
```

**Verify:** `git --version`, and `ls --version | head -1` (GNU coreutils).

### The sibling LibKa0s checkout — optional, but the vendor gate is blind without it

`tests/test_vendor_sync.lua:38` resolves the library repo as `<repo root>/../LibKa0s`. Clone it
beside this repo if you want the vendor gate to actually compare anything:

```sh
git clone https://github.com/tusharsaxena/LibKa0s.git ../LibKa0s
```

Without it the suite still runs — `gitOut` returns `nil` and the checks report "could not answer"
rather than failing (`tests/test_vendor_sync.lua:49-58`) — so this is a **capability**, not a
blocker. `docs/testing.md`'s "The vendor gate" section needs it too: its `diff -r ../LibKa0s/…`
commands have nothing to diff against otherwise.

## 3. Release and assets — **not** needed to build, run or test

Do not install anything in this section to fix a typo, run the tests, or ship a code change. Each
item exists for one job that is done rarely and by hand.

### Python 3 + Pillow — regenerating the logo derivatives only

`media/logos/bankledger.logo.png` is the 1254×1254 master. The `.tga` the client actually loads and
the two `.jpg` renders for the project page are produced from it by a short Pillow script recorded
verbatim in **`docs/ARCHITECTURE.md:626-638`** (`from PIL import Image, ImageFilter`, `LANCZOS`
downscales, an unsharp mask on the 256). The derivatives are **committed**, so this is needed only
when the artwork changes.

**`pipx` is the wrong tool here.** `pipx` installs *applications*, and Pillow is a library with no
entry points — the `pipx` route that works for `lizard` does not work for this. Use the packaged
build, which sidesteps PEP 668 entirely:

```sh
sudo apt install -y python3 python3-pil
```

Or, if you want a newer Pillow than Ubuntu ships, a throwaway virtualenv:

```sh
python3 -m venv /tmp/pillow && /tmp/pillow/bin/pip install pillow
# then run the ARCHITECTURE.md script with /tmp/pillow/bin/python
```

**Verify:** `python3 -c "import PIL; print(PIL.__version__)"`.

### Packaging — no local tooling

`.pkgmeta` is read by the **CurseForge/BigWigs packager**, which runs on the distribution side, not
here. There is no `Makefile`, no build script, and no local packaging step: `.pkgmeta:5-18` only
lists what to exclude from the built zip (`docs`, `tests`, `_dev`, the non-`.tga` logo sources).
Nothing to install.

### Not required, despite what a glance at `media/` might suggest

- **ImageMagick, `ffmpeg`, Node/npm** — none are used anywhere. No script, config, or doc in this
  repo invokes them. If you find a reference, it is stale and should be deleted.
- **BLP tooling** — the addon ships `.tga`, which the client reads directly (`.pkgmeta:14-18`). No
  converter is needed.
- **Font tooling** — `media/fonts/JetBrainsMono-Regular.ttf` ships as-is under its OFL license
  (`media/fonts/OFL.txt`). It is not generated or subsetted here.

## 4. Am I set up correctly?

Run these from the repo root. The first two are the green gate and must both be clean; the third is
the release-time report.

```sh
lua tests/run.lua                                    # every suite green; non-zero exit on failure
luacheck .                                           # 0 errors, 0 warnings
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .    # the complexity report (performance-§10)
```

What each of them means, and the rest of the verification story — the vendor gate, the case
inventory, the release checklist — is in [`docs/testing.md`](docs/testing.md).

---

**Keeping this file honest.** It is checked at release with the rest of the doc set
(documentation-§5). A new script, a new import, or a tool that stops being used changes this file in
the **same** change — a dependency list that is wrong is the thing that makes a new contributor's
first hour their last. Listing a library here never licenses fetching it at build time: libraries
are vendored and committed (library-stack, packaging).
