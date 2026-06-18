#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/user"
QEMU_DIR="${REPO_DIR}/qemu"
QEMU_REF="${QEMU_REF:-minimal-passthrough-plugin}"

# Fetch the QEMU source as a branch tarball instead of `git clone`.
# The fork is large and a full clone is unreliable on some networks/hosts:
# flaky TLS resets mid-transfer, or `index-pack` corrupting its own heap
# (malloc(): unaligned fastbin chunk detected) while resolving deltas on
# riscv64. A single tarball HTTP download sidesteps both. Set QEMU_TARBALL_BASE
# to use a faster mirror; otherwise it falls back to github.com.
if [ ! -e "$QEMU_DIR/configure" ]; then
    mkdir -p "$QEMU_DIR"
    downloaded=0
    for base in \
        "${QEMU_TARBALL_BASE:-}" \
        "https://github.com/rover2024/qemu/archive/refs/heads"; do
        [ -n "$base" ] || continue
        if wget -c --timeout=30 --tries=5 -O /tmp/qemu-src.tgz "${base}/${QEMU_REF}.tar.gz"; then
            downloaded=1
            break
        fi
    done
    [ "$downloaded" = 1 ] || { echo "[bootstrap-qemu] failed to download QEMU source" >&2; exit 1; }
    tar xzf /tmp/qemu-src.tgz -C "$QEMU_DIR" --strip-components=1
    rm -f /tmp/qemu-src.tgz
fi

cd "$QEMU_DIR"

mkdir -p build/release
cd build/release
../../configure --target-list=x86_64-linux-user \
    --enable-plugins \
    --python=python3
cp compile_commands.json ..

ninja
