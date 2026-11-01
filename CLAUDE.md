# Eden NX2 for PS5: build and test

## Current workflow: Colab runs, the repo holds the logic

The build keeps running in Google Colab, but the logic lives in this repo (not in the notebook). The Mac-local build described further down is optional and unverified.

| Path | What |
|---|---|
| `scripts/setup-host.sh` | Host tools (LLVM 18/21, LLVMSPIRVLib, cmake/ninja/meson…). Extracted from the notebook's cell 3. |
| `scripts/build-eden-nx2-ps5.sh` | The full build. Extracted verbatim from the notebook's heredoc. |
| `patches/folder-games-<commit>.patch` | Patches on ProsperoEden so the library lists folder games (see Testing, step 3). One per ProsperoEden version: `e9f30ae` (mrggbond copy) and `a26ba78` (Swordpdf/ProsperoEden main, 01.005.000). The build applies the first that fits. |
| `colab/eden-nx2-ps5.ipynb` | Thin runner: mounts Drive, clones or pulls this repo, restores `estado-completo.zip`, runs the scripts, saves results. Set `REPO_URL` in cell 1. |

Loop: edit `scripts/` here, push to the remote, then in Colab re-run cell 1 (it does `git pull`) and the build cells. Changes to ProsperoEden or eden-nx2 themselves go in our own forks, or as patches applied by `build-eden-nx2-ps5.sh` (`PROSPERO_REPO` / `NX2_REPO` point the build at them).

## Source branches (since 2026-11-01)

The emulator and PS5 code now live as real commits on two branches **of this same GitHub repo** (unrelated histories, no forks):

| Branch | Base | Our commits |
|---|---|---|
| `prospero-nx2-ps5` | Swordpdf/ProsperoEden `a26ba78` | folder games in the library (was `patches/folder-games-a26ba78.patch`) |
| `eden-nx2-ps5` | Takoroka/eden-nx2 `50fa86b` (branch `eden-nx2`) | NX2DIAG logging (was `scripts/diag-nx2.py`) |

Local clones for editing and resolving conflicts: `~/Downloads/ps5-src/ProsperoEden` (branch `nx2-ps5`) and `~/Downloads/ps5-src/eden-nx2` (branch `ps5`). Publish with `git push <url-with-token> nx2-ps5:prospero-nx2-ps5` / `ps5:eden-nx2-ps5` (token only in the URL, never `-u`, check `.git/config` after). `main` holds scripts and notebook. Colab cell 3 has `USE_BRANCHES=True`, which sets `PROSPERO_REPO/NX2_REPO=<this repo>`, the two refs, `MODE=head`, `PATCHES=0`, `DIAG=0`. With `USE_BRANCHES=False` the old way (upstream repos + `patches/` + `diag-nx2.py`) still works. Not compiled with the PS5 toolchain after this change.

## Eglantine build (branch `eglantine`, since 2026-11-01)

Second product, separate from the eden-nx2 one above: **Eglantine** (github.com/Djihads80/Eglantine, branch `nx2`, GPL-3, a Switch 2 emulator derived from Eden/Yuzu/Sudachi that diverged from Takoroka's eden-nx2) with the ProsperoEden frontend on top, rebranded. It builds the same way (ProsperoEden's Eden directory is swapped for the emulator tree, then `make package`).

| Piece | Where |
|---|---|
| Emulator | cloned fresh at its latest `nx2` commit on every run (`--depth 1`, no fork) |
| Frontend | branch `eglantine-ui` of this repo (the earlier `eglantine-frontend` is obsolete: it renamed `/data` paths; delete it): Swordpdf/ProsperoEden `a26ba78` + folder-games commit + visual rebrand commit + pink look commit |
| Rebrand (visual only) | `eglantine/brand.py <ProsperoEden checkout>`: the word in UI strings and `titleName` only. Paths, file names, identifiers, URLs, log lines and BlackBearReloaded credits are left alone. Idempotent: re-run after merging a newer ProsperoEden, commit the result |
| Logo | `eglantine/logo.py <ProsperoEden checkout>` (needs Pillow) builds `ui/art/brand.tga` and `sce_sys/icon0.png` from `eglantine/logo.png` (256 px, so upscaled) |
| Pink look | `eglantine/recolor.py` (needs Pillow) recolours `ui/art/backdrop*.tga`; the theme `canopy` (id kept, shown as "Eglantine") has a pink palette and accents in `pe/ui/theme.cpp`, and the loading screen palette is in `headless/loading_scene.glsl`. Not recoloured: `sce_sys/pic0.dds`/`pic1.dds` (PS5 home-screen backgrounds) and the `-source.png` files (`icon-source.png` is still the old leaf icon) |
| Build | `scripts/build-eglantine.sh` (settings) -> `scripts/build-eden-nx2-ps5.sh` (shared logic) |
| Notebook | `colab/eglantine.ipynb`, Drive folder `eglantine-ps5/`, work dir `/content/work-eglantine`, files `/content/eglantine.*` |
| Output | `PPSA99308`, name "Eglantine", content id `UP9000-PPSA99308_00-EGLANTINEPS50001`. Data on the console: `/data/prosperoeden/...`, **shared** with ProsperoEden on purpose so both can be tested side by side (do not rename paths) |

Checked before building (static, on this Mac): same source layout as eden-nx2, and 158 of ProsperoEden's `old` anchors present in Eglantine like in eden-nx2 (`/tmp` script `anchors.py`; it flagged 126 broken against an unrelated tree, so it does detect). Not checked: anchors built from variables, PS5 compile, anything on a console. `DIAG=1` (default) still adds NX2DIAG logging via `scripts/diag-nx2.py`. Icon and background art in `sce_sys/` are still ProsperoEden's. The in-app updater cannot find a release for the new Title ID (`update check: result=unknown`), but do not use it.

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
3. **Folder games (Switch 2).** The stock ProsperoEden launcher only lists `.nsp`/`.xci` files in `roms/` (`ValidRomFilename`, `IsFile(...)`, `is_regular_file(selected_game)`), so we patch it: `patches/folder-games-a26ba78.patch` and `folder-games-e9f30ae.patch` (applied by `apply_prospero_patches` in `scripts/build-eden-nx2-ps5.sh`; it applies the first that fits and warns loudly, building without it, if none does). Note: ProsperoEden 01.005.000 (`a26ba78`) added its own "game folders" (`roms/<Game>/` holding an NSP/XCI plus its update, DLC, mods), which is NOT the same as an extracted ExeFS folder; our patch adds the latter. It adds `IsFolderGame` (`settings_store.h`), a recursive scanner (`headless/folder_games.h`, depth 4, needs `exefs/main` + `exefs/main.npdm`), library entries named like `MarioKart [base]` / `MarioKart [updates]` with format `DIR`, and title-ID reading from `main.npdm` in `metadata_bridge.cpp`. The entry key is the path relative to `roms/` (`MarioKart/base/exefs/main`), which is also what the emulator is given; eden-nx2 loads it as a deconstructed ROM directory (`romfs/` next to `exefs/`). Place games as `/data/prosperoeden/roms/<Game>/base/{exefs,romfs}` and `/updates/{exefs,romfs}`. Folder games get no cover or control-data title. Base and updates are separate entries: the core does not merge them. **Status:** the helper functions were unit-tested on the Mac; the patch applies cleanly to `e9f30ae` and is idempotent; the patched code has NOT been compiled with the PS5 toolchain and NOT run on a console.
4. Watch memory: eden-nx2 asks for 8 GB VRAM and 16 GB RAM on PC, and the PS5 has 16 GB shared.

**Do not use the in-app updater or `make install` for `PPSA99208`.** Both target `PPSA99008`, and `PPSA99208/lapy-manifest.json` has `"target_title": "PPSA99008"`. This would overwrite a ProsperoEden install. Copy the folder by hand.

## Rules for working here

- Treat this as build engineering: one change at a time, keep build logs, and record which `MODE`, `NX2_REF` and commit produced each output.
- Do not claim a build works until it has run on the PS5. So far it only compiled.
- Verify the dependency mirrors by SHA-256/commit, and do not replace pinned sources with unverified ones.
- Game files, keys and firmware are the user's own, in `/data/prosperoeden/`. Never add them to this folder.
- This folder is not a git repo. If you init one, keep the build outputs and `PPSA99208/` (106 MB) out of it.

## Switch 2 on PS5: known obstacles (from niakw/ProsperoEden-Encore's research docs, read 2026-10-31)

Encore (github.com/niakw/ProsperoEden-Encore, fork of ProsperoEden 1.000.040, firmware 13.60 target) has NO Switch 2 support in its releases. Its `docs/NS2_PS5_FEASIBILITY_2026-10-30.md` calls NS2 on PS5 "plausible long term, not demonstrated" and nothing was run on a PS5. Points that matter for us:

- The Windows reference (0x2593/Eden-NS2, same family as eden-nx2) reports about 5-8 FPS in 3D gameplay, undecoded videos and sync/memory defects. Expect a PS5 build to be slower or not run a commercial title at all.
- NS2 needs 6 guest cores (eden-nx2 already has `NUM_CPU_CORES = 6` and a 6-core exclusive monitor), LSE atomics and RETAA/RETAB/LDAPR translation in Dynarmic, ASTC and sparse-image handling, and a larger memory budget (their notes say 12 GiB).
- **Open risk in our build, not yet checked:** ProsperoEden's `headless/performance.cpp` and `main.cpp` assume 4 guest cores (`std::array<CpuSample, 4>`, `loads[4]`, "guest cores 0-2" thread pinning). With 6 cores, per-core indexing may go out of bounds. Review before a first run if it crashes at boot or in the HUD.
- Firmware 13.60: ProsperoEden's own README says the 13.60 fixes for its PS5-Lapy helper were merged upstream (PS5-Lapy-JB-Daemon PR #48 and #49), so switching to Encore is not needed for that. Our `lapy-manifest.json` still lists 12.02 as the validated firmware.
- Encore's folder layout for extracted games differs from ours: it needs `roms/<title>/main` and `main.npdm` flat, and says nested directories are not discovered. Ours reads `roms/<Game>/base/exefs/main`.

## Eglantine: what the build really compiles (found 2026-11-01)

- **ProsperoEden compiles Eden from `.deps/eden-<sha>.tar.gz`**, unpacked by `tools/prepare-build.sh` into `<cache>/ps5-eden-headless.*/source`, NOT from the `.deps/mirror-<sha>/` directory. Swapping that directory alone changed nothing: every build before this date (eden-nx2 and the first Eglantine run) was the stock pinned Eden plus ProsperoEden's patches. `swap_and_build` now repacks the tarball and removes `source/.unpacked-from` so it is unpacked again. Check a build with `grep -a EDEN_NX2_READ_TRAPS eboot.bin` (a string only the nx2 code has) and `NX2DIAG`.
- The pinned Eden is `67bada77`; Eglantine has moved away from it, so ProsperoEden's configure-time anchors broke. Ported in the frontend branch (`eglantine-ui`): `headless/CMakeLists.txt` accepts Eglantine's own `Idle`, `KSpinLock::Lock`, `GetPseudoDeviceId`, GPU worker shutdown, `MaxOpenFiles` (forced to 512) and a missing `FixSmallVectorADL`; `tools/prepare-vulkan-port.py` skips and reports (`[ANCHOR-SKIPPED]`) anchors it cannot find (`EDEN_STRICT_ANCHORS=1` fails as before). **8 Vulkan edits are skipped** (compute barriers, allocator budget retry, texture-cache download batching, pipeline cache write, frame gen, scheduler, rasterizer hooks). Eglantine has its own version of some; not reviewed one by one. The GC patch's `ReclaimedBytes` and the `FillImageViews` marks were adapted by hand.
- `SKIP_HOST_CHECKS=1` (default in the local script) comments out ProsperoEden's `check-*.py` host self-tests: the JIT ones fail under Rosetta, and `check-native-gpu-thread.py` expects one `scheduler.Push` (Eglantine has two). They did not run, so the GPU thread patch shape is unverified.
- Not run on a console. Whether Eglantine boots a Switch 2 title on the PS5 is unknown.

## Local build on the Mac (Docker), since 2026-11-01

`scripts/local-eglantine.sh` builds the `Dockerfile` image (amd64, Rosetta) and runs `scripts/build-eglantine.sh` in it; state in the volumes `eglantine-work` and `eglantine-cache`; result in `out/PPSA99308` (git-ignored). First full build about 45 min on the M4 with Docker at 10.7 GB RAM and `JOBS=6` (Colab: about 3 h); a rerun with nothing changed is about 1.5 min. `FRONTEND_LOCAL=<ProsperoEden checkout> FRONTEND_REF=<branch>` tests frontend changes without pushing. Docker Desktop memory is in `~/Library/Group Containers/group.com.docker/settings-store.json` (`MemoryMiB`).
