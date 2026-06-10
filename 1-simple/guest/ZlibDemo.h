#pragma once

#include <stddef.h>

size_t zcompress_compress_bound(size_t source_len);

int zcompress_compress(const void *source, size_t source_len, void *dest, size_t *dest_len,
                       int level);

int zcompress_uncompress(const void *source, size_t source_len, void *dest, size_t *dest_len);
