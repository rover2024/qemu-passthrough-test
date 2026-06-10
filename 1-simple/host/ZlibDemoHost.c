#include <stddef.h>

#include <zlib.h>

/*
 * Wrappers invoked through __CommonProcEntry with the (args, ret) convention.
 * args[i] points to the i-th argument; the order MUST match the void *args[]
 * arrays built in ZlibDemo.c.
 */

void __zcompress_compress_bound(void **args, void *ret) {
    size_t source_len = *(size_t *) args[0];

    *(size_t *) ret = (size_t) compressBound((uLong) source_len);
}

void __zcompress_compress(void **args, void *ret) {
    const void *source = *(const void **) args[0];
    size_t source_len  = *(size_t *)      args[1];
    void *dest         = *(void **)       args[2];
    size_t *dest_len   = *(size_t **)     args[3];
    int level          = *(int *)         args[4];

    uLongf dl = (uLongf) *dest_len;
    int r = compress2((Bytef *) dest, &dl, (const Bytef *) source, (uLong) source_len, level);
    *dest_len = (size_t) dl;
    *(int *) ret = r;
}

void __zcompress_uncompress(void **args, void *ret) {
    const void *source = *(const void **) args[0];
    size_t source_len  = *(size_t *)      args[1];
    void *dest         = *(void **)       args[2];
    size_t *dest_len   = *(size_t **)     args[3];

    uLongf dl = (uLongf) *dest_len;
    int r = uncompress((Bytef *) dest, &dl, (const Bytef *) source, (uLong) source_len);
    *dest_len = (size_t) dl;
    *(int *) ret = r;
}
