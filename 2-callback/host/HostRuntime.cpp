#include <cstdio>
#include <cstdint>
#include <cstdlib>

#include <dlfcn.h>

#include "Invocation.h"

typedef struct {
    void *proc;
    void *args;
    void *ret;
} InvocationArguments;

typedef struct {
    void *proc;
    void *callback;
    void *args;
    void *ret;
} ReentryArguments;

enum InvocationID {
    IID_Call = 0,
    IID_Resume,
};

extern "C" void *qemu_address;

void *qemu_address = nullptr;

static __attribute__((constructor)) void init() {
    /* Store QEMU address space by looking up a symbol it exports */
    auto addr = dlsym(RTLD_DEFAULT, "qemu_plugin_register_vcpu_syscall_filter_cb");
    if (addr == nullptr) {
        printf("HostRuntime: failed to find qemu_plugin_register_vcpu_syscall_filter_cb\n");
        std::abort();
    }
    qemu_address = addr;

    printf("HostRuntime: initialized\n");
}

extern "C" void __CommonProcEntry(void *arg1, void *arg2) {
    int iid = (uint64_t) arg1;

    switch (iid) {
        case IID_Call: {
            void **opaque = (void **) arg2;
            InvocationArguments *ia = (InvocationArguments *) opaque[0];
            ReentryArguments **ra_ptr = (ReentryArguments **) opaque[1];
            int *ret_ptr = (int *) opaque[2];
            *ret_ptr = lore::utils::Invocation::invoke(ia, (void **) ra_ptr);
            return;
        }

        case IID_Resume: {
            int *ret_ptr = (int *) arg2;
            *ret_ptr = lore::utils::Invocation::resume();
            return;
        }

        default:
            break;
    }
}

namespace lore::utils {

    extern int processInvocation(const Invocation::InvocationArguments *ia) {
        InvocationArguments *ia1 = (InvocationArguments *) ia;
        typedef void (*Func)(void * /*args*/, void * /*ret*/);
        Func proc = (Func) ia1->proc;
        proc(ia1->args, ia1->ret);
        return 0;
    }

}
