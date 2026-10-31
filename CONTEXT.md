# Eden NX2 on PS5: context from the claude.ai chat

Source: pasted by the user from a claude.ai chat (the share link could not be fetched). The text is stored as written, in Spanish. The `.ipynb` notebook and the guide `eden-nx2-ps5-build.md` mentioned below are NOT in this folder yet.

---

## Final Colab cell: save all state to Drive

User asked (translated): "I already made the zip. Give me the last cell to save everything possible to Drive and make future builds faster."

```python
# Guardar TODO el estado en Drive (Mesa, Eden compilado, cachés y LLVMSPIRVLib)
import os, subprocess
from google.colab import drive
if not os.path.ismount('/content/drive'):
    drive.mount('/content/drive')
DEST = '/content/drive/MyDrive/eden-nx2-ps5'
os.makedirs(DEST, exist_ok=True)
if subprocess.run(['pgrep', '-f', 'build-eden-nx2-ps5.sh'], capture_output=True).returncode == 0:
    raise SystemExit('Hay una compilación en marcha: espera a que termine.')
!du -sh /content/work /root/.cache 2>/dev/null; df -h /content | tail -1
!rm -f /content/estado-completo.zip
!cd / && zip -q -r -y -1 /content/estado-completo.zip root/.cache content/work usr/local/lib/libLLVMSPIRVLib* usr/local/lib/pkgconfig/LLVMSPIRVLib.pc usr/local/include/LLVMSPIRVLib usr/local/bin/llvm-spirv
!ls -lh /content/estado-completo.zip
print('Copiando a Drive (puede tardar 10-20 min con varios GB)…')
!cp /content/estado-completo.zip "{DEST}/estado-completo.zip.tmp" && mv "{DEST}/estado-completo.zip.tmp" "{DEST}/estado-completo.zip"
drive.flush_and_unmount()   # asegura que Drive termina de subirlo antes de cerrar
print('✅ Guardado en Mi unidad/eden-nx2-ps5/estado-completo.zip')
```

Notes:
- It copies to a temp name and then renames, so an interrupted copy doesn't leave a broken ZIP under the real name.
- It unmounts Drive at the end to force the upload to finish. To use Drive in another cell afterwards, re-run cell 2.
- Once done, the old `cache-compilacion.zip` in Drive can be deleted, since `estado-completo.zip` includes everything.
- Expected size is 10-20 GB (not measured). Check free Drive space first.

## New notebook `eden-nx2-ps5.ipynb` (for future runs)

- Cell 2: if `estado-completo.zip` is found in Drive, it restores it. Cell 3 then skips building LLVMSPIRVLib, and cell 6 reuses Mesa and the Eden build.
- Cell 9: saves that same state when finished.
- After an environment reset, with state restored it should take about 15-30 min instead of about 3 h (estimate, untested).
- The project guide `eden-nx2-ps5-build.md` was updated with the real state: branch used, dependency copies, required environment, notebook steps.

Next step: test on the PS5. Copy `PPSA99208` to `/data/homebrew/` and check whether the library shows the Switch 2 game.

---

## Summary: what was done, repos, process

Compiled **eden-nx2** (Eden with experimental Switch 2 support, published only for Windows) as a native PS5 app. The result is the folder `PPSA99208`, named "Eden NX2". It compiled but has **not been tested on the console yet**.

### Key idea

eden-nx2 is not "made for Windows". It is cross-platform C++, and the author only ships the .exe because they only test on Windows. No manual port was needed: its code was dropped into ProsperoEden, which already handles the PS5-specific parts of Eden (graphics, controllers, audio, filesystem, packaging).

### Repos followed

| Purpose | Repo |
|---|---|
| The emulator (Switch 2) | git.eden-emu.dev/Takoroka/eden-nx2, branch `eden-nx2` (172 own commits) |
| Official Eden, as reference | git.eden-emu.dev/eden-emu/eden |
| The PS5 port | github.com/mrggbond/prosperoeden (copy of ProsperoEden; the original and Swordpdf's no longer exist) |
| Vulkan driver and PS5 SDK | mihawk-99/PS5_Mesa, PS5_Vulkan, PS5_PayloadSDK |
| Base SDK | ps5-payload-dev/sdk and pacbrew-repo |
| Copies of dead dependencies | darkxex/ps5-opengl, J7mbo/ps5-homebrew-ui, mpereiraesaa/ps5-native-app-boilerplate, ArkSama/PS5-Lapy-JB-Daemon |

The copies are checked by SHA-256 or commit, so the files are identical to the originals.

### Process, step by step

1. **Build an environment equivalent to ProsperoEden's.** Its official environment is Ubuntu 26.04 and Colab has 24.04, so we added LLVM 18 and 21, built LLVMSPIRVLib 21, and pointed clang and llvm-config at LLVM 21, as its `shell.nix` does.
2. **Recover dead dependencies.** BlackBearReloaded withdrew their repos; the script replaces each dead URL with a verified copy.
3. **Pick the Switch 2 code.** The script detected that eden-nx2's `master` adds nothing and everything is in the `eden-nx2` branch.
4. **Fit it to ProsperoEden.** First it tries to apply the 172 commits on top of the Eden that ProsperoEden pins. There was a conflict in `service.cpp`, so the whole branch was used instead (only 28 commits ahead of that Eden).
5. **Apply the PS5 patches to the nx2 code.** ProsperoEden inserts its changes into about 68 Eden files at configure time and stops with an error if any anchor point changed. With nx2 they all applied without error.
6. **Build.** Mesa/RADV (the Vulkan driver for PS5), plus Eden with the console cross-compiler. About 3 hours the first time.
7. **Package.** Generates `PPSA99008` and makes a copy, `PPSA99208` (name "Eden NX2"), with its own Title ID so it coexists with the user's ProsperoEden.
8. **Save.** The app ZIP and the full build state go to Drive, to rebuild in minutes.

### What's missing / open risks

- Test on the PS5: copy `PPSA99208` to `/data/homebrew/`, with data in `/data/prosperoeden`.
- Game format: eden-nx2 loads Switch 2 games from the extracted folder (`exefs/main`); unknown whether ProsperoEden's library shows them.
- Memory: eden-nx2 asks for 8 GB VRAM and 16 GB RAM on PC; the PS5 has 16 GB total, shared.
- Do not use the app's in-menu updater: it would install into `PPSA99008` and overwrite the user's ProsperoEden.

Everything above is also in the project guide `claude/eden-nx2-ps5-build.md`.
