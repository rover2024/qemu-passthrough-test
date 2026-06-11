#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="$SCRIPT_DIR/archive.bin"
MODE="${1:-passthrough}"
NATIVE_MINIZIP="${NATIVE_MINIZIP:-$(command -v minizip || true)}"
GUEST_MINIZIP="${GUEST_MINIZIP:-$(command -v minizip-x86_64 || command -v minizip || true)}"

if [[ ! -d "${QEMU_BUILD_DIR:-}" ]]; then
    echo "QEMU_BUILD_DIR not set. Please build QEMU first."
    exit 1
fi

if [[ ! -x "$NATIVE_MINIZIP" ]]; then
    echo "Native Minizip not found. Please install native minizip first."
    exit 1
fi

if [[ ! -x "$GUEST_MINIZIP" ]]; then
    echo "Guest Minizip not found. Please install minizip-x86_64 or set GUEST_MINIZIP."
    exit 1
fi

export QEMU=$QEMU_BUILD_DIR/qemu-x86_64
export PLUGIN=$QEMU_BUILD_DIR/contrib/plugins/libpassthrough.so
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:$SCRIPT_DIR/build-host/lib"

if [[ ! -f "$ARCHIVE" ]]; then
    python3 "$SCRIPT_DIR/GenerateArchive.py" "$ARCHIVE" 512M
fi

if [[ "$MODE" == "native" ]]; then
    "$NATIVE_MINIZIP" -8 -o "$ARCHIVE.zip" "$ARCHIVE"
elif [[ "$MODE" == "emulated" ]]; then
    $QEMU "$GUEST_MINIZIP" \
        -8 -o "$ARCHIVE.zip" "$ARCHIVE"
else
    $QEMU -plugin $PLUGIN -E LD_LIBRARY_PATH=$SCRIPT_DIR/build-guest/lib \
        "$GUEST_MINIZIP" \
        -8 -o "$ARCHIVE.zip" "$ARCHIVE"
fi
