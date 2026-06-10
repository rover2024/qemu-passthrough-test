CC ?= cc
RM = rm -rf
MKDIR_P ?= mkdir -p

BUILD_DIR ?= ../build-guest
OBJ_DIR := $(BUILD_DIR)/obj
BIN_DIR := $(BUILD_DIR)/bin
LIB_DIR := $(BUILD_DIR)/lib

CFLAGS ?= -O2
CPPFLAGS ?=
LDFLAGS ?=
LDLIBS ?=

COMMON_CFLAGS := $(CPPFLAGS) $(CFLAGS) -fPIC
SHARED_LDFLAGS := $(LDFLAGS) -shared -Wl,-z,defs
PROGRAM_LDFLAGS := $(LDFLAGS) -Wl,-z,defs

GUEST_RUNTIME_OBJ := $(OBJ_DIR)/GuestRuntime.o
CALLBACK_DEMO_OBJ := $(OBJ_DIR)/CallbackDemo.o
PROGRAM_OBJ := $(OBJ_DIR)/Program.o

all: $(LIB_DIR)/libGuestRuntime.so $(LIB_DIR)/libCallbackDemo.so $(BIN_DIR)/Program

$(OBJ_DIR) $(BIN_DIR) $(LIB_DIR):
	$(MKDIR_P) $@

$(GUEST_RUNTIME_OBJ): GuestRuntime.c | $(OBJ_DIR)
	$(CC) $(COMMON_CFLAGS) -c $< -o $@

$(CALLBACK_DEMO_OBJ): CallbackDemo.c | $(OBJ_DIR)
	$(CC) $(COMMON_CFLAGS) -c $< -o $@

$(PROGRAM_OBJ): Program.c | $(OBJ_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(LIB_DIR)/libGuestRuntime.so: $(GUEST_RUNTIME_OBJ) | $(LIB_DIR)
	$(CC) $(SHARED_LDFLAGS) -o $@ $^ $(LDLIBS)

$(LIB_DIR)/libCallbackDemo.so: $(CALLBACK_DEMO_OBJ) $(LIB_DIR)/libGuestRuntime.so | $(LIB_DIR)
	$(CC) $(SHARED_LDFLAGS) -Wl,-rpath,'$$ORIGIN' -L$(LIB_DIR) -o $@ \
		$(CALLBACK_DEMO_OBJ) -lGuestRuntime $(LDLIBS)

$(BIN_DIR)/Program: $(PROGRAM_OBJ) $(LIB_DIR)/libCallbackDemo.so | $(BIN_DIR)
	$(CC) $(PROGRAM_LDFLAGS) -Wl,-rpath,'$$ORIGIN/../lib' -L$(LIB_DIR) -o $@ \
		$(PROGRAM_OBJ) -lCallbackDemo $(LDLIBS)

clean:
	$(RM) $(BUILD_DIR)

.PHONY: all clean
