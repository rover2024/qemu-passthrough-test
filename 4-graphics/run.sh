#/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export QEMU=/home/overworld/Documents/rover2024/qemu2/build/release/qemu-x86_64
export PLUGIN=/home/overworld/Documents/rover2024/qemu2/build/release/contrib/plugins/libpassthrough.so
export LD_LIBRARY_PATH=$SCRIPT_DIR/build-host/lib

$QEMU -plugin $PLUGIN $SCRIPT_DIR/build-guest/bin/Program