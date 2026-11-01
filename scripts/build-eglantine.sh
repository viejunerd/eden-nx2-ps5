#!/usr/bin/env bash
# Eglantine for PS5: Djihads80/Eglantine (Switch 2 emulator, always its latest nx2 commit) with
# the ProsperoEden frontend on top, rebranded. Output: $WORKDIR/ProsperoEden/build/release/PPSA99308
#
# Runs the shared build script (build-eden-nx2-ps5.sh) with Eglantine's settings. Override any of
# these from the environment if needed, e.g. EGLANTINE_REF=<other branch>.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export WORKDIR="${WORKDIR:-$PWD/work-eglantine}"
export NX2_REPO="${EGLANTINE_REPO:-https://github.com/Djihads80/Eglantine.git}"
export NX2_REF="${EGLANTINE_REF:-nx2}"
export PROSPERO_REPO="${FRONTEND_REPO:-https://github.com/viejunerd/eden-nx2-ps5.git}"
export PROSPERO_REF="${FRONTEND_REF:-eglantine-ui}"
export MODE=head
export PATCHES=0                 # the folder-games and branding changes are commits on the frontend branch
export DIAG="${DIAG:-1}"         # NX2DIAG logging in stderr.log (scripts/diag-nx2.py)
export APP_TITLE="${APP_TITLE:-PPSA99308}"
export APP_NAME="${APP_NAME:-Eglantine}"
export CONTENT_ID_SUFFIX="EGLANTINEPS50001"
export DATA_DIR=/data/prosperoeden   # shared with ProsperoEden on purpose

exec "$HERE/build-eden-nx2-ps5.sh"
