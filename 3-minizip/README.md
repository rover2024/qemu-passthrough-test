# `3-minizip` - Scaling to a whole library

The first two layers hand-write the glue for a handful of functions. Layer 3 asks the harder question: **can a stock, unmodified program run its library calls on the host?** Yes — and without touching the program.

The target is the distribution's own `minizip`. We hand it a **drop-in `libz.so`** whose every exported symbol is a pass-through thunk: when `minizip` calls `compress2`, `deflate`, `gzopen`, … it actually reaches the *host's* real zlib. Because `minizip` is dynamically linked against `libz`, pointing the guest's `LD_LIBRARY_PATH` at our thunk library is all it takes — `minizip` never notices.

**The thunks are generated, not written.** [`GenerateSource.py`](3-minizip/GenerateSource.py) parses `zlib.h` with clang, reads the symbol list in [`Symbols.conf`](3-minizip/Symbols.conf), and emits both halves in the exact `2-callback` style:

* [`guest/ZlibThunk.c`](3-minizip/guest/ZlibThunk.c) — one exported zlib symbol per function; each packs `args[]` and calls `InvokeProc`. Built into `libz.so`.
* [`host/ZlibThunkHost.cpp`](3-minizip/host/ZlibThunkHost.cpp) — one `__<name>` adapter per function; each unpacks `args[]` and calls the **real** host zlib. Built into `libZlibThunkHost.so` (linked against the real `-lz`).

Crucially, layer 3 adds **no new runtime** — it reuses `2-callback`'s `GuestRuntime`, `HostRuntime`, and the `Invocation` coroutine verbatim. Most of zlib (~80 functions) is pure data pass-through; the one function with host→guest callbacks, `inflateBack`, reuses the reentry loop. Its `in`/`out` callbacks are wrapped in a trampoline only when they are *guest* pointers — the adapter compares against `qemu_address` (the guest/host address-space boundary) and calls a host function pointer directly.


## Build and Run

```sh
./build.sh
./run.sh
```

Expected output:

```sh
HostRuntime: initialized
GuestRuntime: initialized
MiniZip 1.1, demo of zLib + MiniZip64 package, written by Gilles Vollant
more info on MiniZip at http://www.winimage.com/zLibDll/minizip.html

creating /home/user/qemu-passthrough-test/3-minizip/archive.bin.zip
File : /home/user/qemu-passthrough-test/3-minizip/archive.bin is 536870912 bytes
```
