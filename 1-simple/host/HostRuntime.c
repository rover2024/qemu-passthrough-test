#include <stdio.h>

typedef struct {
    void *proc;
    void *args;
    void *ret;
    void *metadata;
} InvocationArguments;

static __attribute__((constructor)) void init() {
    printf("HostRuntime: initialized\n");
}

void __CommonProcEntry(void *arg1, void *arg2) {
    InvocationArguments *ia = (InvocationArguments *) arg1;
    typedef void (*Func)(void * /*args*/, void * /*ret*/);
    Func proc = (Func) ia->proc;
    proc(ia->args, ia->ret);
}
