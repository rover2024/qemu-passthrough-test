#include "ZlibDemo.h"

#include "GuestRuntime.h"

#include <dlfcn.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

enum HostProcIndex {
    HP_zcompress_compress_bound,
    HP_zcompress_compress,
    HP_zcompress_uncompress,
};

typedef struct {
    const char *name;
    void *proc;
} HostProc;

static HostProc hostProcs[3] = {
    [HP_zcompress_compress_bound] = {"__zcompress_compress_bound", NULL},
    [HP_zcompress_compress] = {"__zcompress_compress",       NULL},
    [HP_zcompress_uncompress] = {"__zcompress_uncompress",     NULL},
};

static void *hostLibHandle;

static __attribute__((constructor)) void init(void) {
    hostLibHandle = LoadLibrary("libZlibDemoHost.so", RTLD_NOW);
    if (hostLibHandle == NULL) {
        fprintf(stderr, "ZlibDemo: failed to load libZlibDemoHost.so: %s\n", GetLibraryError());
        abort();
    }

    for (int i = 0; i < 3; i++) {
        hostProcs[i].proc = GetProcAddress(hostLibHandle, hostProcs[i].name);
        if (hostProcs[i].proc == NULL) {
            fprintf(stderr, "ZlibDemo: failed to resolve %s: %s\n", hostProcs[i].name,
                    GetLibraryError());
            abort();
        }
    }
}

size_t zcompress_compress_bound(size_t source_len) {
    void *args[] = {&source_len};
    size_t ret = 0;
    InvocationArguments ia = {
        .proc = hostProcs[HP_zcompress_compress_bound].proc,
        .args = args,
        .ret = &ret,
    };
    InvokeProc(&ia);
    return ret;
}

int zcompress_compress(const void *source, size_t source_len, void *dest, size_t *dest_len,
                       int level) {
    void *args[] = {&source, &source_len, &dest, &dest_len, &level};
    int ret = -1;
    InvocationArguments ia = {
        .proc = hostProcs[HP_zcompress_compress].proc,
        .args = args,
        .ret = &ret,
    };
    InvokeProc(&ia);
    return ret;
}

int zcompress_uncompress(const void *source, size_t source_len, void *dest, size_t *dest_len) {
    void *args[] = {&source, &source_len, &dest, &dest_len};
    int ret = -1;
    InvocationArguments ia = {
        .proc = hostProcs[HP_zcompress_uncompress].proc,
        .args = args,
        .ret = &ret,
    };
    InvokeProc(&ia);
    return ret;
}
