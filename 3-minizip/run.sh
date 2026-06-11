#/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="$SCRIPT_DIR/archive.bin"

if [[ ! -d "$QEMU_BUILD_DIR" ]]; then
    echo "QEMU_BUILD_DIR not set. Please build QEMU first."
    exit 1
fi

export QEMU=$QEMU_BUILD_DIR/qemu-x86_64
export PLUGIN=$QEMU_BUILD_DIR/contrib/plugins/libpassthrough.so
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SCRIPT_DIR/build-host/lib

if [[ ! -f "$ARCHIVE" ]]; then
    python3 "$SCRIPT_DIR/GenerateArchive.py" "$ARCHIVE" 512M
fi

$QEMU -plugin $PLUGIN -E LD_LIBRARY_PATH=$SCRIPT_DIR/build-guest/lib \
    /usr/bin/minizip \
    -8 -o "$ARCHIVE.zip" "$ARCHIVE"
