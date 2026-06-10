#include "GuestRuntime.h"

#include <dlfcn.h>
#include <errno.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __x86_64__
#  include "Arch/x86_64/Syscall_x86_64.h"
#elif defined(__aarch64__)
#  include "Arch/aarch64/Syscall_aarch64.h"
#elif defined(__riscv) && __riscv_xlen == 64
#  include "Arch/riscv64/Syscall_riscv64.h"
#else
#  error "Unsupported architecture"
#endif

/* The magic system call number for pass-through. */
enum {
    SyscallPathThroughNumber = 4096,
};

/* The pass-through call ID. */
enum SyscallPassThroughID {
    SPID_GetHostAttribute,
    SPID_LoadLibrary,
    SPID_GetProcAddress,
    SPID_FreeLibrary,
    SPID_GetLibraryError,
    SPID_InvokeProc,
};

static void *pCommonProcEntry;

/* Priority 101: run before demo constructors (e.g. CallbackDemo at 102) so that
   pCommonProcEntry is ready before any of them issues an InvokeProc. */
static __attribute__((constructor(101))) void init() {
    const char *emu = GetHostAttribute("emu");
    if (emu == NULL || strcmp(emu, "qemu") != 0) {
        fprintf(stderr, "GuestRuntime: null or unsupported emu backend\n");
        abort();
    }

    void *hostRuntimeHandle = LoadLibrary("libHostRuntime.so", RTLD_NOW);
    if (hostRuntimeHandle == NULL) {
        fprintf(stderr, "GuestRuntime: failed to load libHostRuntime.so: %s\n", GetLibraryError());
        abort();
    }

    void *commonInvocationEntry = GetProcAddress(hostRuntimeHandle, "__CommonProcEntry");
    if (commonInvocationEntry == NULL) {
        fprintf(stderr, "GuestRuntime: failed to get __CommonProcEntry: %s\n", GetLibraryError());
        abort();
    }
    pCommonProcEntry = commonInvocationEntry;

    printf("GuestRuntime: initialized\n");
}

const char *GetHostAttribute(const char *key) {
    const char *ret = NULL;
    uint64_t sysret =
        syscall3(SyscallPathThroughNumber, SPID_GetHostAttribute, (uint64_t) key, (uint64_t) &ret);
    if (sysret == ENOSYS) {
        return NULL;
    }
    return ret;
}

void *LoadLibrary(const char *path, int flags) {
    void *ret;
    (void) syscall4(SyscallPathThroughNumber, SPID_LoadLibrary, (uint64_t) path, (uint64_t) flags,
                    (uint64_t) &ret);
    return ret;
}

void *GetProcAddress(void *handle, const char *name) {
    void *ret;
    (void) syscall4(SyscallPathThroughNumber, SPID_GetProcAddress, (uint64_t) handle,
                    (uint64_t) name, (uint64_t) &ret);
    return ret;
}

int FreeLibrary(void *handle) {
    int ret;
    (void) syscall3(SyscallPathThroughNumber, SPID_FreeLibrary, (uint64_t) handle, (uint64_t) &ret);
    return ret;
}

const char *GetLibraryError() {
    const char *ret;
    (void) syscall2(SyscallPathThroughNumber, SPID_GetLibraryError, (uint64_t) &ret);
    return ret;
}

enum InvocationID {
    IID_Call = 0,
    IID_Resume,
};

void InvokeProc(const InvocationArguments *ia) {
    ReentryArguments *ra = NULL;

    int ret;
    void *opaque[] = {
        (void *) ia,
        &ra,
        &ret,
    };
    (void) syscall4(SyscallPathThroughNumber, SPID_InvokeProc, (uint64_t) pCommonProcEntry,
                    IID_Call, (uint64_t) opaque);
    while (ret != 0) {
        typedef void (*Func)(void * /*callback*/, void * /*args*/, void * /*ret*/);

        /* Execute the reentry. */
        Func func = (Func) ra->proc;
        func(ra->callback, ra->args, ra->ret);

        /* Wait for the reentry or the completion. */
        (void) syscall4(SyscallPathThroughNumber, SPID_InvokeProc, (uint64_t) pCommonProcEntry,
                        IID_Resume, (uint64_t) &ret);
    }
}
