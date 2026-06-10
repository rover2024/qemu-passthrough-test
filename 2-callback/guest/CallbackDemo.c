#include "CallbackDemo.h"

#include "GuestRuntime.h"

#include <dlfcn.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

enum HostProcIndex {
    HP_initialize,
    HP_my_qsort,
    HP_my_bsearch,
};

typedef struct {
    const char *name;
    void *proc;
} HostProc;

static HostProc hostProcs[3] = {
    [HP_initialize]       = {"__initialize",       NULL},
    [HP_my_qsort]   = {"__my_qsort",   NULL},
    [HP_my_bsearch] = {"__my_bsearch", NULL},
};

static void *hostLibHandle;

/*
 * Reentry dispatcher. While a host routine (qsort/bsearch) runs, it hands control
 * back to the guest's InvokeProc loop, which calls this with:
 *   callback = the guest comparator,
 *   args     = { a, b } (the two element pointers to compare),
 *   ret      = where to store the int result.
 * Registered with the host once, in init() below.
 */
static void reentry_compare(void *callback, void *args, void *ret) {
    typedef int (*Compare)(const void *, const void *);

    Compare compare = (Compare) callback;
    void **ab = (void **) args;
    *(int *) ret = compare(ab[0], ab[1]);
}

/* Priority 102: run after GuestRuntime's constructor (101) so that InvokeProc
   (used below to register dispatchers) is already usable. */
static __attribute__((constructor(102))) void init(void) {
    hostLibHandle = LoadLibrary("libCallbackDemoHost.so", RTLD_NOW);
    if (hostLibHandle == NULL) {
        fprintf(stderr, "CallbackDemo: failed to load libCallbackDemoHost.so: %s\n",
                GetLibraryError());
        abort();
    }

    for (size_t i = 0; i < sizeof(hostProcs) / sizeof(hostProcs[0]); i++) {
        hostProcs[i].proc = GetProcAddress(hostLibHandle, hostProcs[i].name);
        if (hostProcs[i].proc == NULL) {
            fprintf(stderr, "CallbackDemo: failed to resolve %s: %s\n", hostProcs[i].name,
                    GetLibraryError());
            abort();
        }
    }

    /* Register the reentry dispatchers with the host once. The argument order
       MUST match the host's DispatcherIndex enum (DI_compare first). */
    void *compare_dispatcher = (void *) reentry_compare;
    void *args[] = {&compare_dispatcher};
    InvocationArguments ia = {
        .proc = hostProcs[HP_initialize].proc,
        .args = args,
        .ret  = NULL,
    };
    InvokeProc(&ia);
}

void my_qsort(void *base, size_t nmemb, size_t size,
                    int (*compare)(const void *, const void *)) {
    void *comparator = (void *) compare;
    void *args[] = {&base, &nmemb, &size, &comparator};

    InvocationArguments ia = {
        .proc = hostProcs[HP_my_qsort].proc,
        .args = args,
        .ret  = NULL,
    };
    InvokeProc(&ia);
}

void *my_bsearch(const void *key, const void *base, size_t nmemb, size_t size,
                       int (*compare)(const void *, const void *)) {
    void *comparator = (void *) compare;
    void *found = NULL;
    void *args[] = {&key, &base, &nmemb, &size, &comparator};

    InvocationArguments ia = {
        .proc = hostProcs[HP_my_bsearch].proc,
        .args = args,
        .ret  = &found,
    };
    InvokeProc(&ia);
    return found;
}
