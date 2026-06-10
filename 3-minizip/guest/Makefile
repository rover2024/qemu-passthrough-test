CC ?= cc
RM = rm -rf
MKDIR_P ?= mkdir -p
LN_SF ?= ln -sf

BUILD_DIR ?= ../build-guest
OBJ_DIR := $(BUILD_DIR)/obj
LIB_DIR := $(BUILD_DIR)/lib

CFLAGS ?= -O2
CPPFLAGS ?=
LDFLAGS ?=
LDLIBS ?=

COMMON_CFLAGS := $(CPPFLAGS) $(CFLAGS) -fPIC
SHARED_LDFLAGS := $(LDFLAGS) -shared -Wl,-z,defs

GUEST_RUNTIME_OBJ := $(OBJ_DIR)/GuestRuntime.o
ZLIB_THUNK_OBJ := $(OBJ_DIR)/ZlibThunk.o

all: $(LIB_DIR)/libGuestRuntime.so $(LIB_DIR)/libz.so $(LIB_DIR)/libz.so.1

$(OBJ_DIR) $(LIB_DIR):
	$(MKDIR_P) $@

$(GUEST_RUNTIME_OBJ): ../../2-callback/guest/GuestRuntime.c | $(OBJ_DIR)
	$(CC) $(COMMON_CFLAGS) -I../../2-callback/guest -c $< -o $@

$(ZLIB_THUNK_OBJ): ZlibThunk.c | $(OBJ_DIR)
	$(CC) $(COMMON_CFLAGS) -I../../2-callback/guest -c $< -o $@

$(LIB_DIR)/libGuestRuntime.so: $(GUEST_RUNTIME_OBJ) | $(LIB_DIR)
	$(CC) $(SHARED_LDFLAGS) -o $@ $^ $(LDLIBS)

$(LIB_DIR)/libz.so: $(ZLIB_THUNK_OBJ) $(LIB_DIR)/libGuestRuntime.so | $(LIB_DIR)
	$(CC) $(SHARED_LDFLAGS) -Wl,-soname,libz.so -Wl,-rpath,'$$ORIGIN' -L$(LIB_DIR) -o $@ \
		$(ZLIB_THUNK_OBJ) -lGuestRuntime $(LDLIBS)

$(LIB_DIR)/libz.so.1: $(LIB_DIR)/libz.so | $(LIB_DIR)
	cd $(LIB_DIR) && $(LN_SF) libz.so libz.so.1

clean:
	$(RM) $(BUILD_DIR)

.PHONY: all clean
