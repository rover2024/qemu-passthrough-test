#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    void *proc;
    void *args;
    void *ret;
} InvocationArguments;

/* Query host attribute by a reserved key. */
const char *GetHostAttribute(const char *key);

/* Load a host library. */
void *LoadLibrary(const char *path, int flags);

/* Get a procedure address from the host library. */
void *GetProcAddress(void *handle, const char *name);

/* Free the host library. */
int FreeLibrary(void *handle);

/* Get the last library error. */
const char *GetLibraryError();

/* Invoke a host procedure. */
void InvokeProc(const InvocationArguments *ia);

#ifdef __cplusplus
}
#endif
