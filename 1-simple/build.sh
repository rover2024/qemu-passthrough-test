#!/bin/bash

set -euo pipefail

HOST_ARCH="$(uname -m)"

HOST_CC=gcc
HOST_CXX=g++

if [[ "$HOST_ARCH" == "x86_64" ]]; then
    GUEST_CC=gcc
    GUEST_CXX=g++
else
    GUEST_CC=x86_64-linux-gnu-gcc
    GUEST_CXX=x86_64-linux-gnu-g++
fi

make -C guest CC="$GUEST_CC" CXX="$GUEST_CXX"
make -C host CC="$HOST_CC" CXX="$HOST_CXX"
