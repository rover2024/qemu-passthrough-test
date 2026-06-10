CXX ?= c++
CC ?= cc
RM = rm -rf
MKDIR_P ?= mkdir -p

BUILD_DIR ?= ../build-host
OBJ_DIR := $(BUILD_DIR)/obj
LIB_DIR := $(BUILD_DIR)/lib

CXXFLAGS ?= -O2
CFLAGS ?= -O2
CPPFLAGS ?=
LDFLAGS ?=
LDLIBS ?=

HOST_TRIPLET := $(shell $(CXX) -dumpmachine)
HOST_ARCH_RAW := $(firstword $(subst -, ,$(HOST_TRIPLET)))

ifeq ($(HOST_ARCH_RAW),x86_64)
HOST_ARCH := x86_64
else ifeq ($(HOST_ARCH_RAW),amd64)
HOST_ARCH := x86_64
else ifeq ($(HOST_ARCH_RAW),aarch64)
HOST_ARCH := aarch64
else ifeq ($(HOST_ARCH_RAW),arm64)
HOST_ARCH := aarch64
else ifeq ($(HOST_ARCH_RAW),riscv64)
HOST_ARCH := riscv64
else
$(error Unsupported host architecture: $(HOST_ARCH_RAW))
endif

COMMON_CXXFLAGS := $(CPPFLAGS) $(CXXFLAGS) -fPIC
COMMON_CFLAGS := $(CPPFLAGS) $(CFLAGS) -fPIC
COMMON_LDFLAGS := $(LDFLAGS) -shared -Wl,-z,defs

HOST_RUNTIME_OBJS := \
	$(OBJ_DIR)/HostRuntime.o \
	$(OBJ_DIR)/Invocation.o \
	$(OBJ_DIR)/Coroutine_$(HOST_ARCH).o
ZLIB_THUNK_HOST_OBJ := $(OBJ_DIR)/ZlibThunkHost.o

all: $(LIB_DIR)/libHostRuntime.so $(LIB_DIR)/libZlibThunkHost.so

$(OBJ_DIR) $(LIB_DIR):
	$(MKDIR_P) $@

$(OBJ_DIR)/HostRuntime.o: ../../2-callback/host/HostRuntime.cpp | $(OBJ_DIR)
	$(CXX) $(COMMON_CXXFLAGS) -I../../2-callback/host -c $< -o $@

$(OBJ_DIR)/Invocation.o: ../../2-callback/host/Invocation.cpp | $(OBJ_DIR)
	$(CXX) $(COMMON_CXXFLAGS) -I../../2-callback/host -c $< -o $@

$(OBJ_DIR)/Coroutine_$(HOST_ARCH).o: ../../2-callback/host/Arch/$(HOST_ARCH)/Coroutine_$(HOST_ARCH).S | $(OBJ_DIR)
	$(CC) $(COMMON_CFLAGS) -I../../2-callback/host -c $< -o $@

$(ZLIB_THUNK_HOST_OBJ): ZlibThunkHost.cpp | $(OBJ_DIR)
	$(CXX) $(COMMON_CXXFLAGS) -I../../2-callback/host -c $< -o $@

$(LIB_DIR)/libHostRuntime.so: $(HOST_RUNTIME_OBJS) | $(LIB_DIR)
	$(CXX) $(COMMON_LDFLAGS) -o $@ $^ $(LDLIBS)

$(LIB_DIR)/libZlibThunkHost.so: $(ZLIB_THUNK_HOST_OBJ) $(LIB_DIR)/libHostRuntime.so | $(LIB_DIR)
	$(CXX) $(COMMON_LDFLAGS) -Wl,-rpath,'$$ORIGIN' -L$(LIB_DIR) -o $@ \
		$(ZLIB_THUNK_HOST_OBJ) -lHostRuntime -lz $(LDLIBS)

clean:
	$(RM) $(BUILD_DIR)

.PHONY: all clean
