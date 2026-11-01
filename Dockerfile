# Build image for the PS5 builds (Eglantine / eden-nx2). Always linux/amd64: the PS5 SDK ships an
# x86-64 helper (prospero-nid); on Apple Silicon it runs through Rosetta.
FROM --platform=linux/amd64 ubuntu:24.04
COPY scripts/setup-host.sh /tmp/setup-host.sh
RUN bash /tmp/setup-host.sh && rm -rf /var/lib/apt/lists/*
ENV SKIP_APT=1 LLVM_CONFIG=/usr/local/bin/llvm-config CCACHE_DIR=/root/.cache/ccache CCACHE_MAXSIZE=20G
WORKDIR /work
