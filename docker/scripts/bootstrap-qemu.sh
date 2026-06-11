#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/user"
QEMU_DIR="${REPO_DIR}/qemu"

cd "$REPO_DIR"
if [ ! -d "$QEMU_DIR/.git" ]; then
    git clone https://github.com/rover2024/qemu.git "$QEMU_DIR"
fi

cd "$QEMU_DIR"
git checkout minimal-passthrough-plugin

mkdir -p build/release
cd build/release
../../configure --target-list=x86_64-linux-user \
    --enable-plugins \
    --python=python3
cp compile_commands.json ..

ninja
