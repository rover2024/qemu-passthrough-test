# `3-minizip`: Scaling to a whole library

Layer 3 asks the harder question: **can a stock, unmodified program run its library calls on the host?** Yes — and without touching the program.

The target is the distribution's own `minizip`. We hand it a **drop-in `libz.so`** whose every exported symbol is a pass-through thunk: when `minizip` calls `compress2`, `deflate`, `gzopen`, … it actually reaches the *host's* real zlib. Because `minizip` is dynamically linked against `libz`, pointing the guest's `LD_LIBRARY_PATH` at our thunk library is all it takes — `minizip` never notices.

**The thunks are generated, not written.**

[`GenerateSource.py`](GenerateSource.py) parses `zlib.h`, reads the symbol list in [`Symbols.conf`](Symbols.conf), and emits both halves in the exact `2-callback` style:

* [`guest/ZlibThunk.c`](guest/ZlibThunk.c) — one exported zlib symbol per function; each packs `args[]` and calls `InvokeProc`. Built into `libz.so`.
* [`host/ZlibThunkHost.cpp`](host/ZlibThunkHost.cpp) — one `__<name>` adapter per function; each unpacks `args[]` and calls the **real** host zlib. Built into `libZlibThunkHost.so` (linked against the real `-lz`).

Crucially, layer 3 adds **no new runtime**. It reuses `2-callback`'s `GuestRuntime`, `HostRuntime`, and the `Invocation` coroutine verbatim. Most of zlib (~80 functions) is pure data pass-through; the one function with host→guest callbacks, `inflateBack`, reuses the reentry loop. Its `in`/`out` callbacks are wrapped in a trampoline only when they are *guest* pointers — the adapter compares against `qemu_address` (the guest/host address-space boundary) and calls a host function pointer directly.


## Build and Run

```sh
cd 3-minizip
./build.sh
./run.sh
```

By default, `./run.sh` runs the pass-through path: QEMU launches an x86_64 `minizip`, loads the guest `libz.so` thunk, and attaches the `passthrough` plugin. For comparison, `./run.sh emulated` disables pass-through and `./run.sh native` runs the host's native `minizip` directly.

On non-x86_64 hosts, the emulated program still needs to be an x86_64 binary. The Docker image installs that as `minizip-x86_64`; the script uses `GUEST_MINIZIP` if set, otherwise it prefers `minizip-x86_64` and falls back to `minizip`.

Expected output:

```sh
HostRuntime: initialized
GuestRuntime: initialized
MiniZip 1.1, demo of zLib + MiniZip64 package, written by Gilles Vollant
more info on MiniZip at http://www.winimage.com/zLibDll/minizip.html

creating /home/user/qemu-passthrough-test/3-minizip/archive.bin.zip
File : /home/user/qemu-passthrough-test/3-minizip/archive.bin is 536870912 bytes
```

## Compare Execution Time

Full emulation:
```bash
time ./run.sh emulated

real    0m5.403s
user    0m5.842s
sys     0m0.049s
```

Native:
```bash
time ./run.sh native

real    0m1.104s
user    0m1.153s
sys     0m0.048s
```

Pass-through:
```bash
time ./run.sh

real    0m1.173s
user    0m1.208s
sys     0m0.070s
```
