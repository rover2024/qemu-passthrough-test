CC ?= cc
RM = rm -rf
MKDIR_P ?= mkdir -p

BUILD_DIR ?= ../build-host
OBJ_DIR := $(BUILD_DIR)/obj
LIB_DIR := $(BUILD_DIR)/lib

CFLAGS ?= -O2
CPPFLAGS ?=
LDFLAGS ?=
LDLIBS ?=

COMMON_CFLAGS := $(CPPFLAGS) $(CFLAGS) -fPIC
COMMON_LDFLAGS := $(LDFLAGS) -shared -Wl,-z,defs

HOST_RUNTIME_OBJ := $(OBJ_DIR)/HostRuntime.o
ZLIB_DEMO_HOST_OBJ := $(OBJ_DIR)/ZlibDemoHost.o

all: $(LIB_DIR)/libHostRuntime.so $(LIB_DIR)/libZlibDemoHost.so

$(OBJ_DIR) $(LIB_DIR):
	$(MKDIR_P) $@

$(HOST_RUNTIME_OBJ): HostRuntime.c | $(OBJ_DIR)
	$(CC) $(COMMON_CFLAGS) -c $< -o $@

$(ZLIB_DEMO_HOST_OBJ): ZlibDemoHost.c | $(OBJ_DIR)
	$(CC) $(COMMON_CFLAGS) -c $< -o $@

$(LIB_DIR)/libHostRuntime.so: $(HOST_RUNTIME_OBJ) | $(LIB_DIR)
	$(CC) $(COMMON_LDFLAGS) -o $@ $^ $(LDLIBS)

$(LIB_DIR)/libZlibDemoHost.so: $(ZLIB_DEMO_HOST_OBJ) $(LIB_DIR)/libHostRuntime.so | $(LIB_DIR)
	$(CC) $(COMMON_LDFLAGS) -Wl,-rpath,'$$ORIGIN' -L$(LIB_DIR) -o $@ \
		$(ZLIB_DEMO_HOST_OBJ) -lHostRuntime -lz $(LDLIBS)

clean:
	$(RM) $(BUILD_DIR)

.PHONY: all clean
