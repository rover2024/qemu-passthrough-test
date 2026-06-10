# QEMU Pass-Through Test

A worked example of **calling native host functions from inside a QEMU `linux-user` guest program**, built on top of the syscall-filter plugin interface.

The guest issues a single *magic* system call; a tiny QEMU plugin (`passthrough.c`, in the QEMU tree under `contrib/plugins/`) intercepts it and performs the requested host-side operation — `dlopen`, `dlsym`, or "invoke this host function". On top of those few primitives the demos build something that looks, from the guest's point of view, like an ordinary library call.

This repository exists to make that mechanism **easy to understand and easy to try**, so it is split into layers that each add exactly one idea:

| Layer | Adds | Guest-visible API |
|-------|------|-------------------|
| [`1-simple/`](1-simple/)   | the bare pass-through path | `zcompress_*` → host **zlib** |
| [`2-callback/`](2-callback/) | host→guest **callbacks** (reentry) | `my_qsort` / `my_bsearch` → host **qsort/bsearch** |
| [`3-minizip/`](3-minizip/) | a **whole library**, auto-generated | drop-in **`libz.so`** → host **zlib** (runs a stock `minizip`) |

Start with `1-simple`, then `2-callback`, then `3-minizip`.

---

## Prerequisites

* A QEMU built **with the syscall-filter plugin interface** and the `passthrough` plugin (`qemu_plugin_register_vcpu_syscall_filter_cb`). The filter interface is the upstream hook; `passthrough.c` is the plugin that uses it.
* `cmake`, `ninja`, a C/C++ toolchain, and `zlib` development headers (for `1-simple`).
* For `3-minizip`: `clang` (its generator parses `zlib.h`), the host `zlib` library, and a stock `minizip` binary — the demo runs the distribution's `/usr/bin/minizip` **unmodified**.

Each layer ships two helper scripts. Edit the paths at the top of `run.sh` (`QEMU` and `PLUGIN`) to point at your QEMU build, then:

```sh
cd 1-simple
./build.sh      # builds the guest program and the host libraries
./run.sh        # runs the guest under QEMU with the plugin loaded
```

`build.sh` produces two trees:

* `build-guest/bin/Program` — the guest executable (guest ISA, emulated).
* `build-host/lib/lib*.so`  — the **host** runtime + demo libraries (native).

`run.sh` is essentially:

```sh
LD_LIBRARY_PATH=build-host/lib \
  qemu-x86_64 -plugin /path/to/libpassthrough.so  build-guest/bin/Program
```

Expected output (1-simple, abridged):

```
HostRuntime: initialized
GuestRuntime: initialized
zlib demo compressed 8388608 bytes to ... bytes
zlib demo round-tripped successfully
```

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

## Why two runtimes?

The plugin is deliberately minimal and generic. To turn its six primitives into real library calls you need code on **both sides** of the syscall boundary:

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
/* guest */                              /* host adapter */
size_t n = ...;                          void __zcompress_compress_bound(void **args, void *ret) {
void *args[] = { &n };                       size_t n = *(size_t *) args[0];
InvocationArguments ia = {                   *(size_t *) ret = compressBound(n);
    .proc = host_compress_bound,         }
    .args = args, .ret = &result,
};
InvokeProc(&ia);
```

---

## How callbacks work (`2-callback`)

`qsort`/`bsearch` take a **comparator** — a function the host routine calls back. Here the comparator lives in the *guest*. So mid-way through a host `qsort`, the host needs to run a guest function and use its result. The host call stack is deep inside `qsort` and cannot simply unwind, so the host **parks its entire call stack on a coroutine** and bounces control back to the guest.

`InvokeProc` is therefore not a single syscall but a small loop:

```
guest                                   plugin            host (coroutine)
─────                                   ──────            ────────────────
InvokeProc(ia)
  └─ syscall(InvokeProc, Call) ───────► CommonProcEntry
                                          └─ invoke()
                                               starts target on a new stack
                                               e.g. qsort(... host trampoline ...)
                                                        │ wants compare(a,b)
   ◄── sysret 1, ReentryArguments ◄──── reenter():  park coroutine, switch back
  while (sysret != 0):
     run dispatcher → compare(a,b)        (a guest function runs here)
     write result into ReentryArguments.ret
  └─ syscall(InvokeProc, Resume) ──────► resume(): switch back into the coroutine
                                          qsort resumes exactly where it paused
                                                        │ … more comparisons …
   ◄── sysret 0 (complete) ◄──────────── target returns, coroutine unwinds
InvokeProc returns
```

The two phases (`Call` / `Resume`) and the per-architecture context switch (`coroutine_start` / `coroutine_switch`, saving the callee-saved registers in [`RegState`](2-callback/host/Arch/x86_64/RegState_x86_64.h)) live in [`Invocation.cpp`](2-callback/host/Invocation.cpp). A LIFO stack of suspended invocations lets callbacks nest.

<!-- Two details worth noting in the demo:

* **Dispatchers are registered once.** A *reentry dispatcher* is a guest stub that knows how to call a callback of a given signature (here: a comparator). The guest registers it with the host a single time, in its constructor, via a small `__initialize` call — so per-call arguments only need to carry the comparator itself, not the dispatcher.

* **The comparator is passed out-of-band.** The C `qsort` comparator signature has no user-data pointer, so the host adapter stashes the current guest comparator in a `thread_local` and the host trampoline reads it back when `qsort` asks for a comparison. -->

---

## Scaling to a whole library (`3-minizip`)

The first two layers hand-write the glue for a handful of functions. Layer 3 asks the harder question: **can a stock, unmodified program run its library calls on the host?** Yes — and without touching the program.

The target is the distribution's own `minizip`. We hand it a **drop-in `libz.so`** whose every exported symbol is a pass-through thunk: when `minizip` calls `compress2`, `deflate`, `gzopen`, … it actually reaches the *host's* real zlib. Because `minizip` is dynamically linked against `libz`, pointing the guest's `LD_LIBRARY_PATH` at our thunk library is all it takes — `minizip` never notices.

```sh
cd 3-minizip
./build.sh                  # builds guest libz.so + host libZlibThunkHost.so
./run.sh                    # runs a stock minizip under QEMU against the thunk libz
```

**The thunks are generated, not written.** [`GenerateSource.py`](3-minizip/GenerateSource.py) parses `zlib.h` with clang, reads the symbol list in [`Symbols.conf`](3-minizip/Symbols.conf), and emits both halves in the exact `2-callback` style:

* [`guest/ZlibThunk.c`](3-minizip/guest/ZlibThunk.c) — one exported zlib symbol per function; each packs `args[]` and calls `InvokeProc`. Built into `libz.so`.
* [`host/ZlibThunkHost.cpp`](3-minizip/host/ZlibThunkHost.cpp) — one `__<name>` adapter per function; each unpacks `args[]` and calls the **real** host zlib. Built into `libZlibThunkHost.so` (linked against the real `-lz`).

Crucially, layer 3 adds **no new runtime** — it reuses `2-callback`'s `GuestRuntime`, `HostRuntime`, and the `Invocation` coroutine verbatim. Most of zlib (~80 functions) is pure data pass-through; the one function with host→guest callbacks, `inflateBack`, reuses the reentry loop. Its `in`/`out` callbacks are wrapped in a trampoline only when they are *guest* pointers — the adapter compares against `qemu_address` (the guest/host address-space boundary) and calls a host function pointer directly.

<!-- Two things are deliberately out of scope — documented, not silently broken: the variadic `gzprintf`/`gzvprintf` (a generic marshaller can't forward varargs), and custom `z_stream` allocators (`zalloc`/`zfree` are assumed `Z_NULL`, so the host's default allocator is used). -->

<!-- --- -->

<!-- ## Repository layout

```
passthrough.c                 the QEMU plugin (lives in the QEMU tree)

<layer>/guest/                 compiled for the guest, run under QEMU
   GuestRuntime.{c,h}            client stubs over syscall 4096
   Arch/<arch>/Syscall_*.h       the raw `syscall` instruction per ISA
   <Demo>.{c,h}                  per-demo guest glue
   Program.c                     the test program / entry point

<layer>/host/                  native libraries, loaded into the QEMU process
   HostRuntime.{c,cpp}           __CommonProcEntry (+ coroutine glue in 2-callback)
   <Demo>Host.{c,cpp}            per-demo host adapters (call the real lib)
   Arch/<arch>/Coroutine_*.S     context switch, RegState_*.h   (2-callback only)
   Invocation.{h,cpp}            Call/Resume/reenter coroutine API (2-callback only)
``` -->
