#!/usr/bin/env bash
# build-eden-nx2-ps5.sh
# Compila el fork eden-nx2 (Eden + soporte experimental Switch 2) como homebrew de PS5
# usando el sistema de build de ProsperoEden (port PS5 de Eden: frontend headless/,
# ps5-opengl, RADV/Vulkan, PS5 Payload SDK y empaquetado PPSA).
#
# Requisitos: Ubuntu 26.04 (o WSL con Ubuntu 26.04), ~60 GB libres, 16 GB de RAM recomendados.
#
# Uso:
#   ./build-eden-nx2-ps5.sh                 # build de release -> dist/*.zip con la carpeta PPSA99008
#   MODE=head ./build-eden-nx2-ps5.sh       # usa eden-nx2 tal cual (sin rebasar sobre el Eden de ProsperoEden)
#   APP_TITLE=PPSA99208 ./build-eden-nx2-ps5.sh   # Title ID PS5 propio (por defecto), convive con ProsperoEden
#   APP_TITLE=PPSA99008 ./build-eden-nx2-ps5.sh   # mismo Title ID que ProsperoEden (lo sustituye)
#   PS5_HOST=192.168.1.50 ./build-eden-nx2-ps5.sh # además lo copia a la consola por FTP
#
# Variables:
#   WORKDIR        carpeta de trabajo (por defecto ./eden-nx2-ps5)
#   PROSPERO_REPO  repo(s) de ProsperoEden, separados por espacios (por defecto Swordpdf, luego mrggbond)
#   PROSPERO_REF   rama/tag de ProsperoEden (por defecto main)
#   NX2_REPO       repo de eden-nx2
#   NX2_REF        rama o tag de eden-nx2 (auto = la rama con más commits propios; nx2-2026-10-29 = la release de Windows)
#   UPSTREAM_REPO  Eden oficial, para separar los commits propios de nx2
#   MODE           rebase (defecto): commits de nx2 encima del Eden fijado por ProsperoEden
#                  head: el HEAD de eden-nx2 entero en lugar del Eden fijado
#   PINNED         commit de Eden fijado por ProsperoEden (se autodetecta de tools/deps.json)
#   JOBS           trabajos de compilación en paralelo (defecto: todos los núcleos)
#   APP_TITLE      Title ID de PS5 de la carpeta final (por defecto PPSA99208)
#   APP_NAME       nombre en el menú de la PS5 (por defecto "Eden NX2")
#   PATCHES        1 (defecto): aplica patches/*.patch a ProsperoEden; 0 si ya van en su rama
#   DIAG           1 (defecto): añade logs NX2DIAG a eden-nx2 (diag-nx2.py); 0 si ya van en su rama
#   CONTENT_ID_SUFFIX  16 caracteres finales del Content ID (defecto EDENNX2PS5000001)
#   SKIP_APT=1     no instalar paquetes con apt

set -euo pipefail

# Carpeta del script, fijada antes de cualquier cd (los parches están en ../patches)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORKDIR="${WORKDIR:-$PWD/eden-nx2-ps5}"
# Repos de ProsperoEden a probar en orden (el original de BlackBearReloaded ya no responde a git)
PROSPERO_REPOS="${PROSPERO_REPO:-https://github.com/Swordpdf/ProsperoEden.git https://github.com/mrggbond/prosperoeden.git https://github.com/blackbearreloaded/ProsperoEden.git}"
PROSPERO_REF="${PROSPERO_REF:-main}"
NX2_REPO="${NX2_REPO:-https://git.eden-emu.dev/Takoroka/eden-nx2.git}"
NX2_REF="${NX2_REF:-auto}"
UPSTREAM_REPO="${UPSTREAM_REPO:-https://git.eden-emu.dev/eden-emu/eden.git}"
MODE="${MODE:-rebase}"
JOBS="${JOBS:-$(nproc)}"
APP_TITLE="${APP_TITLE:-PPSA99208}"
APP_NAME="${APP_NAME:-Eden NX2}"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[aviso] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 1. herramientas
install_host_tools() {
  [[ "${SKIP_APT:-0}" == 1 ]] && return
  command -v apt-get >/dev/null || { warn "No hay apt; instala a mano lo que pida 'make toolchain' (o usa shell.nix)."; return; }
  log "Instalando herramientas del host (clang/lld 18, cmake, ninja, meson, glslang...)"
  sudo apt-get update
  sudo apt-get install -y \
    clang-18 lld-18 llvm-18 llvm-18-tools \
    cmake ninja-build ccache make nasm meson rsync git \
    glslang-tools spirv-tools bison flex curl wget unzip \
    python3 python3-venv python3-mako python3-yaml \
    pkg-config build-essential \
  || warn "Algún paquete no se instaló. Si falta clang-18 en tu Ubuntu, añade apt.llvm.org (llvm.sh 18)."
}

# ---------------------------------------------------------------- 2a. parches propios sobre ProsperoEden
# patches/folder-games-<commit>.patch: la biblioteca lista juegos extraídos (Juego/base/exefs/main,
# Juego/updates/exefs/main) además de .nsp/.xci. Hay uno por versión de ProsperoEden:
#   e9f30ae = mrggbond/prosperoeden main, a26ba78 = Swordpdf/ProsperoEden main (01.005.000).
# Se deshace lo aplicado en una ejecución anterior y se aplica el primero que encaje.
# Deshace los parches de patches/ que hubiera aplicados (una ejecución anterior) en el cwd.
revert_prospero_patches() {
  local dir patch
  dir="$(cd "$SCRIPT_DIR/../patches" 2>/dev/null && pwd)" || return 0
  for patch in "$dir"/*.patch; do
    [[ -f "$patch" ]] || continue
    if git apply -R --check "$patch" 2>/dev/null; then git apply -R "$patch"; fi
  done
}

# Deja el cwd (ProsperoEden) como el commit al que apunta HEAD: descarta lo modificado (parches,
# deps.json) y borra los archivos nuevos que crean los parches. No toca .deps ni build/.
clean_prospero_tree() {
  local dir patch f
  dir="$(cd "$SCRIPT_DIR/../patches" 2>/dev/null && pwd)" || dir=""
  # Primero se borran los archivos que crean los parches y después se hace el reset: así lo que
  # una rama ya trae versionado (folder_games.h en eglantine-ui) vuelve, y lo que era solo del parche no.
  if [[ -n "$dir" ]]; then
    for patch in "$dir"/*.patch; do
      [[ -f "$patch" ]] || continue
      while read -r f; do rm -f -- "$f"; done < <(awk '/^--- \/dev\/null/{getline; sub(/^\+\+\+ b\//,""); print}' "$patch")
    done
  fi
  git reset -q --hard
}

apply_prospero_patches() {
  local dir patch applied=""
  if [[ "${PATCHES:-1}" != 1 ]]; then
    log "PATCHES=0: ProsperoEden se usa tal cual ($(git rev-parse --short HEAD)); los cambios van en su rama"
    return 0
  fi
  dir="$(cd "$SCRIPT_DIR/../patches" 2>/dev/null && pwd)" \
    || { warn "No encuentro la carpeta patches/; ProsperoEden se compila sin parches propios."; return 0; }
  revert_prospero_patches
  for patch in "$dir"/*.patch; do
    [[ -f "$patch" ]] || continue
    if git apply --check "$patch" 2>/dev/null; then
      git apply "$patch"; applied="$(basename "$patch")"
      log "Parche aplicado: $applied (ProsperoEden $(git rev-parse --short HEAD))"
      break
    fi
  done
  if [[ -z "$applied" ]]; then
    warn "Ningún parche de patches/ encaja con este ProsperoEden ($(git rev-parse --short HEAD))."
    warn "Se compila sin ellos: los juegos en carpeta no saldrán en la biblioteca. Hay que rehacer el parche."
  fi
}

# ---------------------------------------------------------------- 2. ProsperoEden
fetch_prospero() {
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"
  if [[ ! -d ProsperoEden/.git ]]; then
    local ok=0 repo
    for repo in $PROSPERO_REPOS; do
      log "Clonando ProsperoEden ($PROSPERO_REF) desde $repo"
      if GIT_TERMINAL_PROMPT=0 git clone --single-branch --branch "$PROSPERO_REF" "$repo" ProsperoEden; then
        ok=1; break
      fi
      warn "No se pudo clonar $repo; pruebo el siguiente."
      rm -rf ProsperoEden
    done
    [[ $ok == 1 ]] || die "No se pudo clonar ProsperoEden desde ninguna URL. Pasa otra con PROSPERO_REPO=<url>."
    # Comprobar que es el repo con código fuente completo
    [[ -f ProsperoEden/Makefile && -d ProsperoEden/headless ]] \
      || die "El repo clonado no trae Makefile/headless (solo releases). Usa otro con PROSPERO_REPO=<url>."
  else
    log "ProsperoEden ya clonado; actualizando"
    # Primero se quitan nuestros parches (si los hay) y los cambios de deps.json, para poder
    # cambiar de repo o de rama sin conflictos con archivos sin seguimiento.
    ( cd ProsperoEden && clean_prospero_tree )
    git -C ProsperoEden remote set-url origin "${PROSPERO_REPOS%% *}"
    git -C ProsperoEden fetch origin "$PROSPERO_REF"
    git -C ProsperoEden checkout -q -B "$PROSPERO_REF" FETCH_HEAD
  fi
  cd ProsperoEden
  apply_prospero_patches
  log "Comprobando toolchain"
  make toolchain
  fix_dead_urls
  log "Descargando dependencias fijadas (PS5 SDK, ps5-opengl, Mesa/RADV, FFmpeg, Eden...)"
  make deps
}

# ---------------------------------------------------------------- 2b. URLs caídas
# BlackBearReloaded retiró sus repos de GitHub. Las descargas de deps.json que apuntan allí
# se redirigen a copias públicas; deps.py sigue verificando el SHA-256 fijado, así que
# solo se acepta un archivo idéntico al original.
fix_dead_urls() {
  log "Comprobando URLs de dependencias y usando copias si el original ya no existe"
  python3 -I - tools/deps.json <<'PY2'
import json, re, sys, urllib.request
path = sys.argv[1]
text = open(path).read()
data = json.loads(text)
# repo original -> espejos públicos (comprobados con el commit/archivo exacto que se fija)
MIRRORS = {
    "ps5-opengl": ["darkxex/ps5-opengl", "JMUtechnologies/ps5-opengl", "carlchina/ps5-opengl",
                   "KernelForgeLabs/ps5-opengl-sdk-mirror", "Skystar9999/ProsperoAI", "J7mbo/ps5-opengl"],
    "ps5-homebrew-ui": ["J7mbo/ps5-homebrew-ui", "sweenyxsky-oss/ps5-homebrew-ui",
                        "Skystar9999/ps5-homebrew-ui-mirror", "abhi245y/ps5-homebrew-ui"],
    "ps5-native-app-boilerplate": ["mpereiraesaa/ps5-native-app-boilerplate"],
    "PS5-Lapy-JB-Daemon": ["ArkSama/PS5-Lapy-JB-Daemon"],
}
def alive(url):
    try:
        req = urllib.request.Request(url, headers={"Range": "bytes=0-0", "User-Agent": "deps-check"})
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status in (200, 206)
    except Exception:
        return False
def has_commit(mirror, sha):
    return any(alive(f"https://raw.githubusercontent.com/{mirror}/{sha}/{f}")
               for f in ("README.md", "LICENSE", "Makefile", "CMakeLists.txt"))
def tag_variants(tag):
    bare = tag[1:] if tag.startswith("v") else tag
    return [tag, "sdk-" + tag, "v" + bare, "sdk-v" + bare, "mirror-opengl-sdk-" + bare]
# commit fijado para cada URL git
pins = {}
def walk(n):
    if isinstance(n, dict):
        if isinstance(n.get("url"), str) and isinstance(n.get("commit"), str):
            pins[n["url"]] = n["commit"]
        for v in n.values(): walk(v)
    elif isinstance(n, list):
        for v in n: walk(v)
walk(data)
OWN = r'(?:github\.com|raw\.githubusercontent\.com)/blackbearreloaded/'
urls = sorted(set(re.findall(r'https://' + OWN + r'[^\s"\']+', text)))
unresolved, chosen = [], {}
for url in urls:
    if alive(url):
        print("  ok      ", url); continue
    new = None
    rel = re.match(r'https://github\.com/blackbearreloaded/([^/]+)/releases/download/([^/]+)/(.+)$', url)
    raw = re.match(r'https://raw\.githubusercontent\.com/blackbearreloaded/([^/]+)/([0-9a-f]{40})/(.+)$', url)
    git = re.match(r'https://github\.com/blackbearreloaded/([^/]+?)(\.git)?$', url)
    if rel:
        repo, tag, fname = rel.groups()
        for m in MIRRORS.get(repo, []):
            for t in tag_variants(tag):
                cand = f"https://github.com/{m}/releases/download/{t}/{fname}"
                if alive(cand): new = cand; break
            if new: break
    elif raw:
        repo, sha, fpath = raw.groups()
        order = [chosen[(repo, sha)]] if (repo, sha) in chosen else []
        for m in order + [x for x in MIRRORS.get(repo, []) if x not in order]:
            cand = f"https://raw.githubusercontent.com/{m}/{sha}/{fpath}"
            if alive(cand): new = cand; chosen[(repo, sha)] = m; break
    elif git:
        repo, sha = git.group(1), pins.get(url)
        for m in MIRRORS.get(repo, []):
            if (sha and has_commit(m, sha)) or (not sha and alive(f"https://github.com/{m}.git/info/refs?service=git-upload-pack")):
                new = f"https://github.com/{m}.git"; break
    if new:
        text = text.replace(url, new)
        print("  espejo  ", url, "\n       -> ", new)
    else:
        unresolved.append(url)
        print("  CAÍDA   ", url)
open(path, "w").write(text)
if unresolved:
    print("\nSin copia conocida para:\n  " + "\n  ".join(unresolved))
    print("Pásale estas URLs a Claude para buscar espejos.")
PY2
}

# ---------------------------------------------------------------- 3. localizar Eden
find_eden_dir() {
  # El Eden fijado se descomprime dentro de .deps/. Lo reconocemos por su estructura.
  local d
  d="$(find .deps -maxdepth 4 -type d -path '*/src/video_core' -not -path '*.orig*' 2>/dev/null | head -n1 || true)"
  [[ -n "$d" ]] || die "No encuentro el Eden de ProsperoEden dentro de .deps/. Mira 'make deps-status'."
  dirname "$(dirname "$d")"
}

detect_pinned() {
  [[ -n "${PINNED:-}" ]] && { echo "$PINNED"; return; }
  python3 -I - tools/deps.json <<'PY'
import json, re, sys
data = json.load(open(sys.argv[1]))
sha = re.compile(r'^[0-9a-f]{40}$')
def walk(node, ctx=""):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from walk(v, ctx + " " + str(k) + " " + (v if isinstance(v, str) else ""))
    elif isinstance(node, list):
        for v in node:
            yield from walk(v, ctx)
    elif isinstance(node, str):
        yield node, ctx
# Busca un hash de 40 caracteres en una entrada que mencione "eden"
for val, ctx in walk(data):
    if "eden" in ctx.lower():
        m = re.search(r'[0-9a-f]{40}', val)
        if m:
            print(m.group(0)); sys.exit(0)
sys.exit(1)
PY
}

# ---------------------------------------------------------------- 4. preparar eden-nx2
prepare_nx2() {
  local pinned="$1" src="$WORKDIR/eden-nx2" ref b n when best="" bestn=0
  # Rama concreta + MODE=head (Eglantine): solo el último commit de esa rama, sin historial
  # ni Eden oficial. Cada ejecución trae lo más nuevo y lo deja como árbol a compilar.
  if [[ "$MODE" == head && "$NX2_REF" != auto ]]; then
    if [[ -d "$src/.git" ]]; then
      git -C "$src" remote set-url origin "$NX2_REPO"
      log "Actualizando $NX2_REPO ($NX2_REF) al último commit"
      GIT_TERMINAL_PROMPT=0 git -C "$src" fetch -q --depth 1 origin "$NX2_REF"
      git -C "$src" -c advice.detachedHead=false checkout -q -B ps5-nx2 FETCH_HEAD
    else
      log "Clonando $NX2_REPO ($NX2_REF, solo el último commit)"
      GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 --branch "$NX2_REF" "$NX2_REPO" "$src"
      git -C "$src" checkout -q -B ps5-nx2
    fi
    log "Código del emulador: $(git -C "$src" log -1 --format='%h %cs %s')"
    return
  fi
  if [[ ! -d "$src/.git" ]]; then
    log "Clonando eden-nx2 (~220 MB, historial completo para poder rebasar)"
    GIT_TERMINAL_PROMPT=0 git clone "$NX2_REPO" "$src"
  fi
  cd "$src"
  git remote set-url origin "$NX2_REPO"
  log "Descargando todas las ramas de eden-nx2 y de Eden oficial"
  git fetch -q origin '+refs/heads/*:refs/remotes/origin/*' --tags
  git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_REPO"
  git fetch -q upstream '+refs/heads/*:refs/remotes/upstream/*'

  ref="$NX2_REF"
  if [[ "$ref" == auto ]]; then
    log "Buscando la rama de eden-nx2 con código propio (commits que no están en ninguna rama de Eden oficial)"
    printf '  %-6s %-12s %s\n' "propios" "último" "rama"
    while read -r b; do
      [[ "$b" == origin/HEAD ]] && continue
      n=$(git rev-list --count --no-merges "$b" --not --remotes=upstream)
      [[ "$n" -gt 0 ]] || continue
      when=$(git log -1 --format=%cs "$b")
      printf '  %-6s %-12s %s\n' "$n" "$when" "${b#origin/}"
      if [[ "$n" -gt "$bestn" ]]; then best="${b#origin/}"; bestn="$n"; fi
    done < <(git for-each-ref --format='%(refname:short)' refs/remotes/origin/)
    if [[ -z "$best" ]]; then
      warn "Ninguna rama de eden-nx2 tiene commits propios: todo su código ya está en Eden oficial."
      warn "Uso origin/master entero (MODE=head). Comprueba con Takoroka dónde está el soporte de Switch 2."
      ref=master; MODE="head"
    else
      ref="$best"
      log "Rama elegida: $ref ($bestn commits propios). Para otra, pon NX2_REF=<rama> en la celda 4."
    fi
  fi
  # NX2_REF puede ser una rama (eden-nx2) o un tag de release (nx2-2026-10-29)
  local target
  if git rev-parse -q --verify "origin/$ref^{commit}" >/dev/null; then target="origin/$ref"
  elif git rev-parse -q --verify "refs/tags/$ref^{commit}" >/dev/null; then target="refs/tags/$ref"
  else die "'$ref' no es una rama ni un tag de eden-nx2."; fi
  git -c advice.detachedHead=false checkout -q -B ps5-nx2 "$target"

  if [[ "$MODE" == head ]]; then
    log "MODE=head: se usa eden-nx2 $ref tal cual ($(git log -1 --oneline))"
    return
  fi

  git cat-file -e "${pinned}^{commit}" 2>/dev/null \
    || die "El commit fijado $pinned no está en Eden oficial. Prueba MODE=head o PINNED=<commit>."

  mapfile -t commits < <(git rev-list --reverse --no-merges "$target" --not --remotes=upstream)
  log "eden-nx2/$ref tiene ${#commits[@]} commits propios; aplicándolos sobre el Eden de ProsperoEden (${pinned:0:10})"
  [[ ${#commits[@]} -gt 0 ]] || warn "No hay commits propios: el resultado será el Eden de ProsperoEden."

  git -c advice.detachedHead=false checkout -q -B ps5-nx2 "$pinned"
  if [[ ${#commits[@]} -gt 0 ]] && ! git -c user.name="eden-nx2-ps5" -c user.email="build@localhost" cherry-pick --allow-empty --keep-redundant-commits "${commits[@]}"; then
    git cherry-pick --abort || true
    warn "Hay conflictos al rebasar eden-nx2/$ref sobre el Eden fijado."
    warn "Paso a MODE=head (la rama entera). Si el build falla en headless/inject.cmake,"
    warn "resuelve el cherry-pick a mano en $src y vuelve a lanzar con MODE=head."
    git -c advice.detachedHead=false checkout -q -B ps5-nx2 "$target"
  fi
  log "Árbol final de eden-nx2: $(git log -1 --oneline)"
}

# ---------------------------------------------------------------- 5. sustituir y compilar
swap_and_build() {
  local eden_dir="$1" src="$WORKDIR/eden-nx2"
  cd "$WORKDIR/ProsperoEden"
  if [[ ! -d "$eden_dir.orig" ]]; then
    log "Guardando el Eden original en $eden_dir.orig"
    cp -a "$eden_dir" "$eden_dir.orig"
  fi
  log "Sustituyendo $eden_dir por eden-nx2"
  rsync -a --delete --exclude '.git' "$src/" "$eden_dir/"
  if [[ "${DIAG:-1}" == 1 ]]; then
    log "Instrumentando eden-nx2 con logs NX2DIAG (DIAG=0 los quita)"
    python3 -I "$SCRIPT_DIR/diag-nx2.py" "$eden_dir" || warn "diag-nx2.py falló; se compila sin diagnóstico."
  fi
  # ProsperoEden NO compila el directorio de .deps: tools/prepare-build.sh desempaqueta
  # .deps/eden-<sha>.tar.gz en <caché>/ps5-eden-headless.*/source y compila de ahí. Hay que
  # reempaquetar el tarball con nuestro árbol e invalidar esa copia, o se compila el Eden de serie.
  local arc scratch
  arc="$(ls .deps/eden-*.tar.gz 2>/dev/null | head -n1)"
  [[ -n "$arc" ]] || die "No encuentro .deps/eden-*.tar.gz (el que desempaqueta tools/prepare-build.sh)."
  [[ -f "$arc.orig" ]] || cp -a "$arc" "$arc.orig"
  log "Reempaquetando $arc con el código del emulador ($(basename "$eden_dir"))"
  tar -czf "$arc" -C "$(dirname "$eden_dir")" "$(basename "$eden_dir")"
  scratch="$(cat .local/headless-cache 2>/dev/null || true)"
  if [[ -n "$scratch" && -d "$scratch/source" ]]; then
    rm -f "$scratch/source/.unpacked-from"   # prepare-build.sh lo vuelve a desempaquetar (conserva .cache)
  fi
  # ProsperoEden no toca lo que ya existe en .deps, así que la sustitución se respeta.
  make deps-status || true

  [[ "$APP_TITLE" =~ ^[A-Z]{4}[0-9]{5}$ ]] || die "APP_TITLE debe tener el formato PPSA12345 (4 letras y 5 cifras)."
  if [[ "${SKIP_HOST_CHECKS:-0}" == 1 ]]; then
    # Autotests x86 de ProsperoEden (JIT, afinidad, TSC...) que corren en el host tras compilar.
    # Bajo Rosetta/Docker en Mac fallan por la emulación y no tocan el binario de la PS5.
    warn "SKIP_HOST_CHECKS=1: se omiten los check-*.py del host en tools/build-headless-native.sh"
    sed -i -E 's|^( *)(python3 -B "\$root/tools/check-[a-z-]+\.py")|\1true # \2|' tools/build-headless-native.sh
  fi
  log "Compilando la app (build de release; la primera vez Eden tarda bastante)"
  make package JOBS="$JOBS"
  local rel="build/release/PPSA99008"
  [[ -f "$rel/sce_sys/param.json" ]] || die "No se generó $rel/sce_sys/param.json"
  OUT="$rel"
  if [[ "$APP_TITLE" != PPSA99008 ]]; then
    log "Creando build/release/$APP_TITLE con Title ID $APP_TITLE y nombre \"$APP_NAME\""
    rm -rf "build/release/$APP_TITLE"
    cp -a "$rel" "build/release/$APP_TITLE"
    python3 -I - "build/release/$APP_TITLE/sce_sys/param.json" "$APP_TITLE" "$APP_NAME" "${CONTENT_ID_SUFFIX:-EDENNX2PS5000001}" <<'PY3'
import json, sys
path, tid, name, suffix = sys.argv[1:5]
p = json.load(open(path))
p["titleId"] = tid
p["conceptId"] = tid[4:]
p["contentId"] = f"UP9000-{tid}_00-{suffix}"[:36]
for k, v in p.get("localizedParameters", {}).items():
    if isinstance(v, dict) and "titleName" in v:
        v["titleName"] = name
json.dump(p, open(path, "w"), indent=2)
print("  titleId", p["titleId"], "| contentId", p["contentId"], "| nombre", name)
PY3
    OUT="build/release/$APP_TITLE"
    warn "Con un Title ID distinto, no uses la opción de actualizar desde el menú de la app:"
    warn "el actualizador de ProsperoEden instala en PPSA99008. Las keys/juegos se leen de ${DATA_DIR:-/data/prosperoeden}."
  fi

  if [[ -n "${PS5_HOST:-}" ]]; then
    log "Copiando a la PS5 en $PS5_HOST por FTP (cierra ProsperoEden antes)"
    [[ "$APP_TITLE" == PPSA99008 ]] || warn "make install sube PPSA99008; para $APP_TITLE copia la carpeta a mano."
    make install PS5_HOST="$PS5_HOST"
  fi

  log "Listo. Salida en: $WORKDIR/ProsperoEden/$OUT"
  ls -la "$OUT" || true
}

# ---------------------------------------------------------------- main
install_host_tools
fetch_prospero
EDEN_DIR="$(find_eden_dir)"
if ! PINNED_SHA="$(detect_pinned)"; then
  [[ "$MODE" == head ]] || die "No he podido leer el commit de Eden en tools/deps.json. Pásalo con PINNED=<sha> o usa MODE=head."
  PINNED_SHA="desconocido"
fi
log "Eden de ProsperoEden: $EDEN_DIR @ ${PINNED_SHA:0:10}"
EDEN_ABS="$WORKDIR/ProsperoEden/$EDEN_DIR"
prepare_nx2 "$PINNED_SHA"
swap_and_build "$EDEN_ABS"
