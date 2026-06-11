# `2-callback` - Host-to-Guest Callbacks (Reentry)

`qsort`/`bsearch` take a **comparator** — a function the host routine calls back. Here the comparator lives in the *guest*. So mid-way through a host `qsort`, the host needs to run a guest function and use its result. The host call stack is deep inside `qsort` and cannot simply unwind, so the host **parks its entire call stack on a coroutine** and bounces control back to the guest.

```c++
void my_qsort(void *base, size_t nmemb, size_t size,
              int (*compare)(const void *, const void *));

void *my_bsearch(const void *key, const void *base, size_t nmemb, size_t size,
                 int (*compare)(const void *, const void *));
```

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

## Build and Run

```sh
cd 2-callback
./build.sh
./run.sh
```

Expected output:

```sh
HostRuntime: initialized
GuestRuntime: initialized
Program: before sort: 42 7 13 99 1 88 23 5 64 31
Program: after sort:  1 5 7 13 23 31 42 64 88 99
Program: bsearch  23 -> found at index 4
Program: bsearch 100 -> not found
Program: bsearch   1 -> found at index 0
Program: bsearch  99 -> found at index 9
Program: bsearch   8 -> not found
Program: comparator crossed the callback boundary 41 times
Program: callback demo completed successfully
```
