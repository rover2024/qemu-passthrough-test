# QEMU Pass-Through Test

A worked example of **calling native host functions from inside a QEMU `linux-user` guest program**, built on top of the syscall-filter plugin interface.

1. The guest issues a single *magic* system call
2. A tiny QEMU plugin (`passthrough.c`, in the QEMU tree under `contrib/plugins/`) intercepts it and performs the requested host-side operation — `dlopen`, `dlsym`, or "invoke this host function". On top of those few primitives the demos build something that looks, from the guest's point of view, like an ordinary library call.

The syscall-filter plugin interface has been merged upstream in QEMU. The pass-through plugin used here currently lives in a downstream QEMU branch:
https://github.com/rover2024/qemu/blob/minimal-passthrough-plugin/contrib/plugins/passthrough.c


This repository exists to make that mechanism **easy to understand and easy to try**, so it is split into layers that each add exactly one idea:

| Layer | Adds | Guest-visible API |
|-------|------|-------------------|
| [`1-simple/`](1-simple/)   | the bare pass-through path | `zcompress_*` → host **zlib** |
| [`2-callback/`](2-callback/) | host→guest **callbacks** (reentry) | `my_qsort` / `my_bsearch` → host **qsort/bsearch** |
| [`3-minizip/`](3-minizip/) | a **whole library**, auto-generated | drop-in **`libz.so`** → host **zlib** (runs a stock `minizip`) |
| [`4-graphics/`](4-graphics/) | **two** libraries at once, a live GUI | drop-in **`libX11.so` + `libGL.so`** → host Xlib/OpenGL |

---

## How pass-through works

### 1. A magic syscall the plugin claims

The guest's runtime makes a system call with a **reserved number, `4096`**, that no real Linux ABI uses. The first argument selects a *pass-through call ID* (`SPID`); the rest carry operands:

```
  syscall(4096, SPID, op1, op2, op3, ...)
            │     │     └────────── operands (pointers / ints)
            │     └──────────────── which operation
            └────────────────────── the magic number
```

`passthrough.c` registers a **vCPU syscall filter**. Before QEMU forwards a syscall to the host kernel, the filter runs; when it sees number `4096` it handles the call itself, writes the result, and tells QEMU the syscall is consumed (the real kernel never sees it).

The whole ABI is six primitives:

| `SPID`             | operands                       | host action                          |
|--------------------|--------------------------------|--------------------------------------|
| `GetHostAttribute` | `key`, `*out`                  | report a host attribute (e.g. `emu`) |
| `LoadLibrary`      | `path`, `flags`, `*out`        | `dlopen`                             |
| `GetProcAddress`   | `handle`, `name`, `*out`       | `dlsym`                              |
| `FreeLibrary`      | `handle`, `*out`               | `dlclose`                            |
| `GetLibraryError`  | `*out`                         | `dlerror`                            |
| `InvokeProc`       | `proc`, `arg1`, `arg2`         | call `proc(arg1, arg2)` natively     |

That is the *entire* surface exposed to the guest. Notice the plugin knows nothing about zlib, qsort, or calling conventions — only "load a library", "find a symbol", and "call a `void(void*, void*)` function". Everything ergonomic is built on top of these by the two runtimes (below).

### 2. Why the plugin can touch guest pointers

The plugin runs **inside the QEMU process**, in host address space. The demos pass ordinary pointers (a buffer to compress, an array to sort) straight through the magic syscall and the host dereferences them directly. This works because the examples assume the guest and host share an address space (identity-mapped, `guest_base == 0`) — the simple case that keeps the demos readable. Opaque values produced by the host (a `dlopen` handle, a resolved function address) are just shuttled back and forth by the guest without interpretation.

---

## Setup Environment

### Use Docker Container (Recommended)

Build image:
```bash
docker build -f docker/Dockerfile -t passthrough-image .
```

If you are in a PRC network environment, use the USTC mirror during image build:
```bash
docker build --build-arg USE_USTC_MIRROR=1 -f docker/Dockerfile -t passthrough-image .
```

Run container:
```bash
docker run --rm -it --name passthrough-container passthrough-image /bin/bash
```

The image copies this repository to `/home/user/qemu-passthrough-test`, builds the downstream QEMU tree under `/home/user/qemu`, and sets `QEMU_BUILD_DIR=/home/user/qemu/build/release`. It also handles non-x86_64 hosts by installing the x86_64 guest toolchain and the x86_64 `minizip` needed by `3-minizip`.

### Install Prerequisites Manually

If you do not want to use the Docker container, you can install the prerequisites below manually.

- Minizip 1.1
- Zlib 1.2

If you are on Ubuntu 22.04, you can install `zlib` and `minizip` with:
```bash
sudo apt install minizip zlib1g-dev
```
- GCC/G++
- GNU Make

If you are on a non-x86_64 system, you will need to install x86_64 compilers:
```bash
sudo apt install gcc-x86-64-linux-gnu g++-x86-64-linux-gnu
```

- QEMU (with `passthrough` plugin added)
```bash
git clone https://github.com/rover2024/qemu.git
cd qemu
git checkout minimal-passthrough-plugin

mkdir -p build/release
cd build/release
../../configure --target-list=x86_64-linux-user \
    --enable-plugins \
    --python=python3
cp compile_commands.json ..

# run.sh requires it 
export QEMU_BUILD_DIR=$(pwd)
```

---


## Quick Start

### `1-simple` — Borrowing the host's zlib

[`1-simple/guest/Program.c`](1-simple/guest/Program.c) is an ordinary guest program: it fills an 8 MiB buffer, compresses it, decompresses it, and checks that the round-trip matches. It does this by calling three plain functions:

```c
size_t zcompress_compress_bound(size_t source_len);
int    zcompress_compress(const void *src, size_t src_len, void *dst, size_t *dst_len, int level);
int    zcompress_uncompress(const void *src, size_t src_len, void *dst, size_t *dst_len);
```

Here is the twist: **the guest binary contains no zlib at all.** Every `zcompress_*` call is forwarded across the pass-through boundary and actually run by the **host's** real zlib (`compressBound` / `compress2` / `uncompress`). The guest gets working compression without ever linking a compression library.

The forwarding is two small halves you can read in a minute:

* **guest side** — [`ZlibDemo.c`](1-simple/guest/ZlibDemo.c) packs each call's arguments and hands them to [`GuestRuntime.c`](1-simple/guest/GuestRuntime.c), which issues the magic syscall.
* **host side** — [`ZlibDemoHost.c`](1-simple/host/ZlibDemoHost.c) receives the call, unpacks the arguments, and invokes the *real* host `compress2` / `uncompress` / `compressBound`.

Build both halves:

```sh
cd 1-simple
./build.sh
```

This compiles two separate trees:

* `build-guest/bin/Program` — the guest program, run **under QEMU**.
* `build-host/lib/*.so` — the host libraries the plugin loads natively: `libHostRuntime.so` (the pass-through runtime) and `libZlibDemoHost.so` (the adapters, linked against the real `-lz`).

Run the demo:

```sh
./run.sh
```

All `run.sh` really does is launch the guest under QEMU with the plugin attached and the host libraries on the load path:

```sh
LD_LIBRARY_PATH=build-host/lib \
    qemu-x86_64 -plugin libpassthrough.so  build-guest/bin/Program
```

Example output:

```
HostRuntime: initialized
GuestRuntime: initialized
zlib demo compressed 8388608 bytes to ... bytes
zlib demo round-tripped successfully
```

The last two lines are the proof: the guest compressed 8 MiB and recovered it byte-for-byte — using a zlib that lives entirely on the host, reached one `zcompress_*` call at a time.


### `2-callback` - Host-to-Guest Callbacks (Reentry)

See [`2-callback/README.md`](2-callback/README.md).

### `3-minizip` - Scaling to a whole library

See [`3-minizip/README.md`](3-minizip/README.md).

### `4-graphics` - Two libraries and a live GUI

See [`4-graphics/README.md`](4-graphics/README.md).

---

## Why two runtimes?

The plugin is deliberately minimal and generic. To turn its six primitives into real library calls you need code on **both sides** of the syscall boundary (For example, we want the guest program to invoke `qsort` or `compress2` in host libraries):

```
  ┌────────────────────────── guest (emulated, guest ISA) ────────────────────────────┐
  │  Program.c            ZlibDemo.c / CallbackDemo.c        GuestRuntime.c           │
  │  (uses the API)  ───► (per-demo guest glue)        ───►  (client stubs:           │
  │                                                          LoadLibrary, InvokeProc) │
  └───────────────────────────────────────────────┬───────────────────────────────────┘
                                       syscall(4096, …)   ← the only crossing point
  ┌───────────────────────────────────────────────┴───────────────────────────────────┐
  │  passthrough.c (plugin, inside QEMU)                                              │
  │       dlopen / dlsym / … / invoke_proc(proc, a1, a2)                              │
  └───────────────────────────────────────────────┬───────────────────────────────────┘
                                                  ▼  native call
  ┌────────────────────────── host (native) ──────────────────────────────────────────┐
  │  HostRuntime.{c,cpp}        ZlibDemoHost.c / CallbackDemoHost.cpp                 │
  │  (CommonProcEntry,          (per-demo host adapters: unpack args,                 │
  │   coroutine machinery)       call the real qsort / compress2 / …)                 │
  └───────────────────────────────────────────────────────────────────────────────────┘
```

* **GuestRuntime** (compiled into the guest, guest ISA) is the **client**. It wraps the magic syscall into friendly C functions (`LoadLibrary`, `GetProcAddress`, `InvokeProc`, …). The guest cannot call a host function directly — different ISA, different link namespace — so it marshals everything into syscall `4096`.

* **HostRuntime** (a native `.so`, loaded into the QEMU process via the plugin's own `dlopen`) is the **server entry**. The plugin's `invoke_proc` only knows the primitive `void(void*, void*)` shape, so it always calls one host function: `__CommonProcEntry`. That host function unpacks the real arguments and dispatches to the actual native target. In `2-callback`, HostRuntime also owns the coroutine machinery that makes callbacks possible.

The per-demo halves (`ZlibDemo`/`ZlibDemoHost`, `CallbackDemo`/`CallbackDemoHost`) are the API-specific glue layered on top. The split keeps `passthrough.c` tiny and stable: new capabilities are added by editing the two runtimes, never QEMU.

### The invocation convention

To invoke a host function the guest fills an `InvocationArguments { proc, args, ret }` and calls `InvokeProc`. By convention `args` is an array of pointers, **`args[i]` points to the i-th argument**, and the host adapter reads each with one dereference. For example `zcompress_compress_bound`:

```c
/* guest */                                  /* host adapter */
size_t n = ...;                              void __zcompress_compress_bound(void **args, void *ret) {
void *args[] = { &n };                           size_t n = *(size_t *) args[0];
InvocationArguments ia = {                       *(size_t *) ret = compressBound(n);
    .proc = host_compress_bound,             }
    .args = args,
    .ret = &result,
};
InvokeProc(&ia);
```
