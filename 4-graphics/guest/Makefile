CXX ?= c++
CC ?= cc
RM = rm -rf
MKDIR_P ?= mkdir -p
LN_SF ?= ln -sf

BUILD_DIR ?= ../build-guest
OBJ_DIR := $(BUILD_DIR)/obj
BIN_DIR := $(BUILD_DIR)/bin
LIB_DIR := $(BUILD_DIR)/lib

CXXFLAGS ?= -O2
CFLAGS ?= -O2
CPPFLAGS ?=
LDFLAGS ?=
LDLIBS ?=

COMMON_CXXFLAGS := $(CPPFLAGS) $(CXXFLAGS) -fPIC
COMMON_CFLAGS := $(CPPFLAGS) $(CFLAGS) -fPIC
SHARED_LDFLAGS := $(LDFLAGS) -shared -Wl,-z,defs
PROGRAM_LDFLAGS := $(LDFLAGS) -Wl,-z,defs

GUEST_RUNTIME_OBJ := $(OBJ_DIR)/GuestRuntime.o
X11_THUNK_OBJ := $(OBJ_DIR)/X11Thunk.o
GL_THUNK_OBJ := $(OBJ_DIR)/GLThunk.o
PROGRAM_OBJ := $(OBJ_DIR)/Program.o

all: $(LIB_DIR)/libGuestRuntime.so $(LIB_DIR)/libX11.so $(LIB_DIR)/libX11.so.6 \
	$(LIB_DIR)/libGL.so $(LIB_DIR)/libGL.so.1 $(BIN_DIR)/Program

$(OBJ_DIR) $(BIN_DIR) $(LIB_DIR):
	$(MKDIR_P) $@

$(GUEST_RUNTIME_OBJ): ../../2-callback/guest/GuestRuntime.c | $(OBJ_DIR)
	$(CC) $(COMMON_CFLAGS) -I../../2-callback/guest -c $< -o $@

$(X11_THUNK_OBJ): X11Thunk.c | $(OBJ_DIR)
	$(CC) $(COMMON_CFLAGS) -I../../2-callback/guest -c $< -o $@

$(GL_THUNK_OBJ): GLThunk.c | $(OBJ_DIR)
	$(CC) $(COMMON_CFLAGS) -I../../2-callback/guest -c $< -o $@

$(PROGRAM_OBJ): Program.cpp | $(OBJ_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(LIB_DIR)/libGuestRuntime.so: $(GUEST_RUNTIME_OBJ) | $(LIB_DIR)
	$(CC) $(SHARED_LDFLAGS) -o $@ $^ $(LDLIBS)

$(LIB_DIR)/libX11.so: $(X11_THUNK_OBJ) $(LIB_DIR)/libGuestRuntime.so | $(LIB_DIR)
	$(CC) $(SHARED_LDFLAGS) -Wl,-soname,libX11.so -Wl,-rpath,'$$ORIGIN' -L$(LIB_DIR) -o $@ \
		$(X11_THUNK_OBJ) -lGuestRuntime $(LDLIBS)

$(LIB_DIR)/libX11.so.6: $(LIB_DIR)/libX11.so | $(LIB_DIR)
	cd $(LIB_DIR) && $(LN_SF) libX11.so libX11.so.6

$(LIB_DIR)/libGL.so: $(GL_THUNK_OBJ) $(LIB_DIR)/libGuestRuntime.so | $(LIB_DIR)
	$(CC) $(SHARED_LDFLAGS) -Wl,-soname,libGL.so -Wl,-rpath,'$$ORIGIN' -L$(LIB_DIR) -o $@ \
		$(GL_THUNK_OBJ) -lGuestRuntime $(LDLIBS)

$(LIB_DIR)/libGL.so.1: $(LIB_DIR)/libGL.so | $(LIB_DIR)
	cd $(LIB_DIR) && $(LN_SF) libGL.so libGL.so.1

$(BIN_DIR)/Program: $(PROGRAM_OBJ) $(LIB_DIR)/libGL.so $(LIB_DIR)/libX11.so | $(BIN_DIR)
	$(CXX) $(PROGRAM_LDFLAGS) -Wl,-rpath,'$$ORIGIN/../lib' -L$(LIB_DIR) -o $@ \
		$(PROGRAM_OBJ) -lGL -lX11 -lm $(LDLIBS)

clean:
	$(RM) $(BUILD_DIR)

.PHONY: all clean
