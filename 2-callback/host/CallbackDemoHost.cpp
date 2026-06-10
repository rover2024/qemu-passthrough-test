#include <cstddef>
#include <cstdlib>

#include "Invocation.h"

/*
 * Host-side adapters for qsort/bsearch. Each is invoked through __CommonProcEntry
 * with the (args, ret) convention; args[i] points to the i-th argument and the
 * layout MUST match the void *args[] arrays built in the guest's CallbackDemo.c.
 *
 * The reentry dispatchers are registered once via __initialize (called from the
 * guest's constructor). Because the C library comparator signature carries no
 * user-data pointer, the per-call guest comparator is stashed in a thread-local
 * that the host trampoline reads back when the routine compares.
 */

typedef struct {
    void *proc;     /* guest reentry dispatcher -> ReentryArguments::proc     */
    void *callback; /* guest comparator         -> ReentryArguments::callback */
    void *args;
    void *ret;
} ReentryArguments;

/* Reentry dispatchers registered by the guest; the index order MUST match the
   args[] order the guest passes to __initialize. */
enum DispatcherIndex {
    DI_compare,
};

static void *gDispatchers[1];

static thread_local void *tlsComparator;

static int hostCompareTrampoline(const void *a, const void *b) {
    void *ab[] = {(void *) a, (void *) b};
    int ret = 0;

    ReentryArguments ra = {
        gDispatchers[DI_compare],
        tlsComparator,
        ab,
        &ret,
    };
    lore::utils::Invocation::reenter(&ra);
    return ret;
}

extern "C" void *qemu_address;

extern "C" void __initialize(void **args, void *ret) {
    (void) ret;

    for (int i = 0; i < sizeof(gDispatchers) / sizeof(gDispatchers[0]); i++) {
        gDispatchers[i] = *(void **) args[i];
    }
}

extern "C" void __my_qsort(void **args, void *ret) {
    (void) ret;

    void *base       = *(void **)  args[0];
    size_t nmemb     = *(size_t *) args[1];
    size_t size      = *(size_t *) args[2];
    void *comparator = *(void **)  args[3];

    if ((uintptr_t) comparator < (uintptr_t) qemu_address) {
        tlsComparator = comparator;
        comparator = (void *) hostCompareTrampoline;
    }
    qsort(base, nmemb, size, (int (*) (const void *, const void *)) comparator);
}

extern "C" void __my_bsearch(void **args, void *ret) {
    const void *key  = *(const void **) args[0];
    void *base       = *(void **)       args[1];
    size_t nmemb     = *(size_t *)      args[2];
    size_t size      = *(size_t *)      args[3];
    void *comparator = *(void **)       args[4];

    if ((uintptr_t) comparator < (uintptr_t) qemu_address) {
        tlsComparator = comparator;
        comparator = (void *) hostCompareTrampoline;
    }
    *(void **) ret = bsearch(key, base, nmemb, size, (int (*) (const void *, const void *)) comparator);
}
