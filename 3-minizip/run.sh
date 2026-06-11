#/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="$SCRIPT_DIR/archive.bin"
MODE="${1:-passthrough}"
MINIZIP="$(which minizip)"

if [[ ! -d "$QEMU_BUILD_DIR" ]]; then
    echo "QEMU_BUILD_DIR not set. Please build QEMU first."
    exit 1
fi

if [[ ! -x "$MINIZIP" ]]; then
    echo "minizip not found. Please install it first."
    exit 1
fi

export QEMU=$QEMU_BUILD_DIR/qemu-x86_64
export PLUGIN=$QEMU_BUILD_DIR/contrib/plugins/libpassthrough.so
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SCRIPT_DIR/build-host/lib

if [[ ! -f "$ARCHIVE" ]]; then
    python3 "$SCRIPT_DIR/GenerateArchive.py" "$ARCHIVE" 512M
fi

if [[ "$MODE" == "native" ]]; then
    "$MINIZIP" -8 -o "$ARCHIVE.zip" "$ARCHIVE"
elif [[ "$MODE" == "emulated" ]]; then
    $QEMU "$MINIZIP" \
        -8 -o "$ARCHIVE.zip" "$ARCHIVE"
else
    $QEMU -plugin $PLUGIN -E LD_LIBRARY_PATH=$SCRIPT_DIR/build-guest/lib \
        "$MINIZIP" \
        -8 -o "$ARCHIVE.zip" "$ARCHIVE"
fi
