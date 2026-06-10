#pragma once

#include <stddef.h>

/*
 * Thin wrappers around the host C library's qsort/bsearch. The comparator is a
 * guest function, so every comparison the host routine performs re-enters the
 * guest through the pass-through callback (reentry) mechanism.
 */

/* Sort nmemb elements of size bytes at base, using a guest comparator. */
void my_qsort(void *base, size_t nmemb, size_t size,
                    int (*compare)(const void *, const void *));

/* Binary-search base[0..nmemb) for key, using a guest comparator. */
void *my_bsearch(const void *key, const void *base, size_t nmemb, size_t size,
                       int (*compare)(const void *, const void *));
