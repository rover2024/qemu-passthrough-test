#/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$QEMU_BUILD_DIR" ]]; then
    echo "QEMU_BUILD_DIR not set. Please build QEMU first."
    exit 1
fi

export QEMU=$QEMU_BUILD_DIR/qemu-x86_64
export PLUGIN=$QEMU_BUILD_DIR/contrib/plugins/libpassthrough.so
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SCRIPT_DIR/build-host/lib

$QEMU -plugin $PLUGIN $SCRIPT_DIR/build-guest/bin/Program