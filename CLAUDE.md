# Eden NX2 for PS5: build and test

## Current workflow: Colab runs, the repo holds the logic

The build keeps running in Google Colab, but the logic lives in this repo (not in the notebook). The Mac-local build described further down is optional and unverified.

| Path | What |
|---|---|
| `scripts/setup-host.sh` | Host tools (LLVM 18/21, LLVMSPIRVLib, cmake/ninja/meson…). Extracted from the notebook's cell 3. |
| `scripts/build-eden-nx2-ps5.sh` | The full build. Extracted verbatim from the notebook's heredoc. |
| `patches/prospero-folder-games.patch` | Patch on ProsperoEden so the library lists folder games (see Testing, step 3). |
| `colab/eden-nx2-ps5.ipynb` | Thin runner: mounts Drive, clones or pulls this repo, restores `estado-completo.zip`, runs the scripts, saves results. Set `REPO_URL` in cell 1. |

Loop: edit `scripts/` here, push to the remote, then in Colab re-run cell 1 (it does `git pull`) and the build cells. Changes to ProsperoEden or eden-nx2 themselves go in our own forks, or as patches applied by `build-eden-nx2-ps5.sh` (`PROSPERO_REPO` / `NX2_REPO` point the build at them).

The extracted scripts passed `bash -n`. The new notebook has **not been run in Colab yet**. The original notebook is still `eden_nx2_ps5_final.py`.

## Goal

Build **eden-nx2** (Eden plus experimental Switch 2 support, published only for Windows) as a native PS5 homebrew app **on this Mac**, then test it on the PS5. Until now the build ran in Google Colab (about 3 h the first time).

The approach is not to port anything by hand. eden-nx2's code is dropped into **ProsperoEden** (the PS5 port of Eden), which already handles graphics (Mesa/RADV Vulkan), input, audio, filesystem and packaging.

Background and the full chat summary are in `CONTEXT.md`. The working Colab build is `eden_nx2_ps5_final.py`. It is a Colab notebook export, so it will not run as-is: it has `!` shell lines and `# %%bash` cells.

## What is in this folder

| Path | What |
|---|---|
| `eden_nx2_ps5_final.py` | Colab notebook export. The real build logic is the `build-eden-nx2-ps5.sh` heredoc in it (cell 5, lines ~152-493) and the LLVM setup (cell 3, lines ~55-119). |
| `PPSA99208/` | Output of the last Colab build: "Eden NX2" app folder, 106 MB. **Never run on a console yet** (`console_validated: false`). |
| `CONTEXT.md` | Summary of the original claude.ai chat (Spanish source, English here). |

Do not edit `PPSA99208/` by hand. It is a build artifact and the only known-good output.

## Build pipeline (what the script does)

1. **Host tools:** LLVM 18 (cross-compilation) and LLVM 21 (PS5 SDK, Mesa, host tools), SPIRV-LLVM-Translator 21.1.8 (`LLVMSPIRVLib`, SHA-256 `3c5720d3…c722`), cmake/ninja/meson, glslang, nasm, ccache. Unversioned `clang`, `clang++`, `llvm-config` and `llvm-*` are symlinked to LLVM 21, and `ld.lld` is wrapped to add `-z nodynamic-undefined-weak` when linking the eboot. This mirrors ProsperoEden's `shell.nix`, which targets Ubuntu 26.04.
2. **Clone ProsperoEden** from the first repo that works: `Swordpdf/ProsperoEden`, `mrggbond/prosperoeden`, `blackbearreloaded/ProsperoEden`. Per the chat, only the `mrggbond` copy still exists. It must contain `Makefile` and `headless/`.
3. `make toolchain`, then **`fix_dead_urls`**, then `make deps`. BlackBearReloaded withdrew its repos, so dead URLs in `tools/deps.json` are rewritten to verified mirrors (darkxex/ps5-opengl, J7mbo/ps5-homebrew-ui, mpereiraesaa/ps5-native-app-boilerplate, ArkSama/PS5-Lapy-JB-Daemon). `deps.py` still checks the pinned SHA-256/commit.
4. **Prepare eden-nx2:** clone `https://git.eden-emu.dev/Takoroka/eden-nx2.git` (about 220 MB, full history) plus upstream `https://git.eden-emu.dev/eden-emu/eden.git`. `NX2_REF=auto` picks the branch with the most commits not in upstream, which is `eden-nx2` (172 own commits). `master` adds nothing.
5. **Mode:** `MODE=rebase` cherry-picks the nx2 commits onto the Eden commit that ProsperoEden pins (read from `tools/deps.json`). On conflict it falls back to `MODE=head`, the whole branch. The last Colab run hit a conflict in `service.cpp` and used the head branch (28 commits ahead of the pinned Eden; the pinned commit starts with `67bada77f8`).
6. **Swap and build:** rsync eden-nx2 over ProsperoEden's `.deps/.../eden` directory (original kept as `.orig`), then `make package JOBS=N`. ProsperoEden injects its PS5 patches into about 68 Eden files at configure time and fails if an anchor moved. All applied cleanly on nx2.
7. **Title ID:** output is `build/release/PPSA99008`. For `APP_TITLE != PPSA99008` it is copied to `build/release/$APP_TITLE` and `sce_sys/param.json` is rewritten: `titleId`, `conceptId`, `contentId = UP9000-<tid>_00-EDENNX2PS5000001`, `titleName`. Default is `PPSA99208` "Eden NX2", which coexists with a ProsperoEden install.

Key variables: `WORKDIR`, `MODE` (rebase|head), `NX2_REF`, `NX2_REPO`, `UPSTREAM_REPO`, `PROSPERO_REPO`, `PROSPERO_REF`, `PINNED`, `JOBS`, `APP_TITLE`, `APP_NAME`, `SKIP_APT=1`, `LLVM_CONFIG`, `CCACHE_DIR`, `CCACHE_MAXSIZE`, optional `PS5_HOST` (FTP install, uploads PPSA99008 only).

## Local build on this Mac: constraints

Checked on this machine:

- **Apple Silicon (arm64), macOS.** The pipeline is a Linux/x86_64 flow (Colab is x86_64 Ubuntu 24.04, ProsperoEden targets Ubuntu 26.04). It cannot run natively on macOS.
- **16 GB RAM, 10 cores.** The script header recommends 16 GB. Expect a Linux VM or container to have less, and linking and Mesa can be memory-hungry.
- **About 43 GB free on disk.** The script header asks for about 60 GB, and the Colab state zip was estimated at 10-20 GB (not measured). **Free up disk first.**
- **Docker is installed** (`/usr/local/bin/docker`, an Intel-path binary, not verified running). No OrbStack, Lima, Colima or Multipass.

Not verified yet, and the first thing to find out:

- Whether the PS5 SDK toolchain that `make toolchain` fetches, and the ProsperoEden prebuilt tools, work on **arm64 Linux**. If they are x86_64-only, the build needs an `--platform linux/amd64` container under emulation, which will be much slower than native Colab.
- Whether Ubuntu 24.04 is enough or 26.04 is required (Colab built on 24.04 with the LLVM 18/21 workarounds above, and it worked).

Suggested approach: a Dockerfile based on Ubuntu 24.04 that reproduces cell 3, with the work directory and `CCACHE_DIR` on a mounted volume so rebuilds are incremental. Then extract the heredoc script into a standalone `build-eden-nx2-ps5.sh` next to it. Try arm64 first and fall back to `linux/amd64` if the SDK fails.

## Colab differences to remove when porting

- `/content/...` paths and `google.colab` Drive mounting. Use a local volume.
- `sudo` and apt inside `install_host_tools` (the Colab run used `SKIP_APT=1` and installed packages in cell 3 as root).
- Background `nohup` and `build.log` polling (cells 6, 6b): run with `tee` instead.
- Packaging and upload steps (cells 8, 9 and the final save cell): replace with copying `build/release/$APP_TITLE` out of the container.

## Testing on the PS5

Needs a jailbroken console (kstuff-lite or etaHEN) and **ShadowMountPlus**.

1. Copy the whole `PPSA99208/` folder to `/data/homebrew/` (or `/mnt/usb0/homebrew/`).
2. Keys, firmware and games (your own) go in `/data/prosperoeden/`. The path is shared with ProsperoEden.
3. **Folder games (Switch 2).** The stock ProsperoEden launcher only lists `.nsp`/`.xci` files in `roms/` (`ValidRomFilename`, `IsFile(...)`, `is_regular_file(selected_game)`), so we patch it: `patches/prospero-folder-games.patch` (written against mrggbond/prosperoeden `e9f30ae`, applied by `apply_prospero_patches` in `scripts/build-eden-nx2-ps5.sh`; it warns loudly and builds without it if it no longer applies). It adds `IsFolderGame` (`settings_store.h`), a recursive scanner (`headless/folder_games.h`, depth 4, needs `exefs/main` + `exefs/main.npdm`), library entries named like `MarioKart [base]` / `MarioKart [updates]` with format `DIR`, and title-ID reading from `main.npdm` in `metadata_bridge.cpp`. The entry key is the path relative to `roms/` (`MarioKart/base/exefs/main`), which is also what the emulator is given; eden-nx2 loads it as a deconstructed ROM directory (`romfs/` next to `exefs/`). Place games as `/data/prosperoeden/roms/<Game>/base/{exefs,romfs}` and `/updates/{exefs,romfs}`. Folder games get no cover or control-data title. Base and updates are separate entries: the core does not merge them. **Status:** the helper functions were unit-tested on the Mac; the patch applies cleanly to `e9f30ae` and is idempotent; the patched code has NOT been compiled with the PS5 toolchain and NOT run on a console.
4. Watch memory: eden-nx2 asks for 8 GB VRAM and 16 GB RAM on PC, and the PS5 has 16 GB shared.

**Do not use the in-app updater or `make install` for `PPSA99208`.** Both target `PPSA99008`, and `PPSA99208/lapy-manifest.json` has `"target_title": "PPSA99008"`. This would overwrite a ProsperoEden install. Copy the folder by hand.

## Rules for working here

- Treat this as build engineering: one change at a time, keep build logs, and record which `MODE`, `NX2_REF` and commit produced each output.
- Do not claim a build works until it has run on the PS5. So far it only compiled.
- Verify the dependency mirrors by SHA-256/commit, and do not replace pinned sources with unverified ones.
- Game files, keys and firmware are the user's own, in `/data/prosperoeden/`. Never add them to this folder.
- This folder is not a git repo. If you init one, keep the build outputs and `PPSA99208/` (106 MB) out of it.
