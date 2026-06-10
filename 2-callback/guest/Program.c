#include <stdio.h>
#include <stdlib.h>

#include "CallbackDemo.h"

/* Counts how often the guest comparator is reached, i.e. how many times the
   host routine re-entered the guest across the callback boundary. */
static int g_compare_calls;

static int compare_int(const void *a, const void *b) {
    g_compare_calls++;

    int ia = *(const int *) a;
    int ib = *(const int *) b;
    return (ia > ib) - (ia < ib);
}

static void print_array(const char *label, const int *data, size_t n) {
    printf("%s", label);
    for (size_t i = 0; i < n; i++) {
        printf(" %d", data[i]);
    }
    printf("\n");
}

int main(void) {
    int data[] = {42, 7, 13, 99, 1, 88, 23, 5, 64, 31};
    size_t n = sizeof(data) / sizeof(data[0]);

    print_array("Program: before sort:", data, n);

    /* qsort calls compare_int (a guest function) many times from host code. */
    my_qsort(data, n, sizeof(data[0]), compare_int);

    print_array("Program: after sort: ", data, n);

    for (size_t i = 1; i < n; i++) {
        if (data[i - 1] > data[i]) {
            fprintf(stderr, "Program: sort FAILED\n");
            return EXIT_FAILURE;
        }
    }

    /* A mix of present (23, 1, 99) and absent (100, 8) keys. */
    int keys[] = {23, 100, 1, 99, 8};
    size_t key_count = sizeof(keys) / sizeof(keys[0]);

    for (size_t i = 0; i < key_count; i++) {
        int key = keys[i];
        int *found = (int *) my_bsearch(&key, data, n, sizeof(data[0]), compare_int);

        if (found != NULL) {
            if (*found != key) {
                fprintf(stderr, "Program: bsearch returned wrong element for %d\n", key);
                return EXIT_FAILURE;
            }
            printf("Program: bsearch %3d -> found at index %ld\n", key, (long) (found - data));
        } else {
            printf("Program: bsearch %3d -> not found\n", key);
        }
    }

    printf("Program: comparator crossed the callback boundary %d times\n", g_compare_calls);
    if (g_compare_calls == 0) {
        fprintf(stderr, "Program: callback was never invoked\n");
        return EXIT_FAILURE;
    }

    puts("Program: callback demo completed successfully");
    return EXIT_SUCCESS;
}
