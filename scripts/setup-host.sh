#!/usr/bin/env bash
# Host tools: LLVM 18 + 21, LLVMSPIRVLib 21, cmake/ninja/meson, glslang, python.
# Replica lo que monta el shell.nix de ProsperoEden (pensado para Ubuntu 26.04).
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get -qq update
apt-get -qq install -y lsb-release wget curl gnupg software-properties-common \
  ccache make nasm rsync git glslang-tools spirv-tools bison flex unzip zip zstd \
  xxd file patch pkg-config build-essential python3-venv >/dev/null
echo "Sistema: $(lsb_release -ds)"

# --- LLVM 18 (compilación cruzada) y LLVM 21 (SDK de la PS5, Mesa, herramientas del host)
wget -qO /tmp/llvm.sh https://apt.llvm.org/llvm.sh
for v in 18 21; do
  if ! command -v clang-$v >/dev/null; then
    echo "Instalando LLVM $v…"; bash /tmp/llvm.sh $v >/dev/null
  fi
  apt-get -qq install -y lld-$v llvm-$v llvm-$v-dev llvm-$v-tools libclang-$v-dev libclang-cpp$v-dev >/dev/null
done

# --- Python y herramientas de build recientes
python3 -m pip -q install --upgrade cmake ninja meson mako pyyaml ply packaging numpy pillow

# --- SPIRV-LLVM-Translator 21.1.8 (LLVMSPIRVLib), que necesitan las herramientas clc de Mesa
if ! pkg-config --exists LLVMSPIRVLib; then
  echo "Compilando SPIRV-LLVM-Translator 21.1.8 (unos 10-20 min)…"
  cd /tmp
  wget -qO spirv.tgz https://github.com/KhronosGroup/SPIRV-LLVM-Translator/archive/v21.1.8.tar.gz
  echo "3c5720d37a767933ccfaf521fe24e498369baafd384b599b102bc6980820c722  spirv.tgz" | sha256sum -c - \
    || { echo "El tarball no coincide con el SHA-256 de shell.nix"; exit 1; }
  rm -rf SPIRV-LLVM-Translator-21.1.8 spirv-build && tar xf spirv.tgz
  cmake -S SPIRV-LLVM-Translator-21.1.8 -B spirv-build -G Ninja \
    -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm \
    -DLLVM_INCLUDE_TESTS=OFF -DLLVM_SPIRV_INCLUDE_TESTS=OFF \
    -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local >/dev/null
  cmake --build spirv-build -j"$(nproc)" >/dev/null
  cmake --install spirv-build >/dev/null
  ldconfig
fi

# --- Nombres sin versión -> LLVM 21, igual que el shell.nix de ProsperoEden
B=/usr/local/bin
for t in clang clang++ clang-cpp; do ln -sf /usr/bin/$t-21 $B/$t; done
for t in llvm-ar llvm-nm llvm-objcopy llvm-ranlib llvm-readobj llvm-objdump llvm-symbolizer llvm-strip; do
  [ -e /usr/bin/$t-21 ] && ln -sf /usr/bin/$t-21 $B/$t
done
ln -sf /usr/bin/llvm-config-21 $B/llvm-config
ln -sf $B/clang $B/llvm-clang; ln -sf $B/clang++ $B/llvm-clang++; ln -sf $B/clang-cpp $B/llvm-clang-cpp
ln -sf /usr/bin/ld.lld-21 $B/llvm-ld.lld
# ld.lld sin versión: añade -z nodynamic-undefined-weak al enlazar el eboot (como el shell.nix)
cat > $B/ld.lld <<'EOF'
#!/bin/sh
extra=
for a in "$@"; do case "$a" in --no-dynamic-linker) extra="-z nodynamic-undefined-weak" ;; esac; done
exec /usr/bin/ld.lld-21 $extra "$@"
EOF
chmod +x $B/ld.lld

echo; echo "Comprobación:"
for t in clang-18 clang++-18 ld.lld-18 clang-21 ld.lld-21 clang llvm-config cmake ninja meson glslangValidator spirv-val nasm; do
  printf '  %-18s %s\n' "$t" "$(command -v $t || echo FALTA)"
done
echo "  llvm-config        $(llvm-config --version)"
echo "  LLVMSPIRVLib       $(pkg-config --modversion LLVMSPIRVLib || echo FALTA)"
python3 -c "import mako, yaml, ply, packaging, numpy, PIL; print('  Python: módulos OK')"
