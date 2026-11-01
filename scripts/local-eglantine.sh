#!/usr/bin/env bash
# Eglantine for PS5, built locally in Docker (Mac). Same build as the Colab notebook.
#   scripts/local-eglantine.sh            build (incremental after the first run)
# State lives in Docker volumes (eglantine-work, eglantine-cache); the app lands in ./out/PPSA99308.
# Settings: JOBS (default 6; each job can use ~1.5 GB), DIAG, EGLANTINE_REF...
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docker info >/dev/null 2>&1 || { echo "Docker is not running (open -a Docker)"; exit 1; }
docker build --platform linux/amd64 --provenance=false -t eglantine-build .
mkdir -p out
docker run --rm --platform linux/amd64 \
  -v eglantine-work:/work -v eglantine-cache:/root/.cache -v "$PWD":/repo:ro -v "$PWD/out":/out \
  -e JOBS="${JOBS:-6}" -e DIAG="${DIAG:-1}" -e SKIP_HOST_CHECKS="${SKIP_HOST_CHECKS:-1}" -e EGLANTINE_REF="${EGLANTINE_REF:-nx2}" \
  eglantine-build bash -c '
    set -e
    WORKDIR=/work/eglantine /repo/scripts/build-eglantine.sh 2>&1 | tee /work/eglantine.log
    rm -rf /out/PPSA99308 && cp -a /work/eglantine/ProsperoEden/build/release/PPSA99308 /out/
    echo "OK -> out/PPSA99308"'
