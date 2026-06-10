#/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="$SCRIPT_DIR/archive.bin"

export QEMU=/home/overworld/Documents/rover2024/qemu2/build/release/qemu-x86_64
export PLUGIN=/home/overworld/Documents/rover2024/qemu2/build/release/contrib/plugins/libpassthrough.so
export LD_LIBRARY_PATH=$SCRIPT_DIR/build-host/lib

if [[ ! -f "$ARCHIVE" ]]; then
    python3 "$SCRIPT_DIR/GenerateArchive.py" "$ARCHIVE" 512M
fi

$QEMU -plugin $PLUGIN -E LD_LIBRARY_PATH=$SCRIPT_DIR/build-guest/lib \
    /usr/bin/minizip \
    -8 -o "$ARCHIVE.zip" "$ARCHIVE"
