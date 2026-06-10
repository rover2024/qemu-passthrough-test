cmake_minimum_required(VERSION 3.19)

project(host
    LANGUAGES CXX ASM
)

if(NOT DEFINED CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
endif()

if(NOT DEFINED CMAKE_LIBRARY_OUTPUT_DIRECTORY)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
endif()

if(NOT DEFINED CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
endif()

add_link_options("-Wl,-z,defs")

# Detect target architecture (for the coroutine context switch).
execute_process(
    COMMAND ${CMAKE_CXX_COMPILER} -dumpmachine
    OUTPUT_VARIABLE _target_triplet
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
string(REGEX MATCH "^[^-]+" _target_arch "${_target_triplet}")

if(_target_arch MATCHES "x86_64|amd64")
    set(_target_arch "x86_64")
elseif(_target_arch MATCHES "aarch64|arm64")
    set(_target_arch "aarch64")
elseif(_target_arch MATCHES "riscv64")
    set(_target_arch "riscv64")
endif()

# Host-side runtime (__CommonProcEntry + the InvokeProc coroutine machinery).
add_library(HostRuntime SHARED
    ../../2-callback/host/HostRuntime.cpp
    ../../2-callback/host/Invocation.cpp
    ../../2-callback/host/Arch/${_target_arch}/Coroutine_${_target_arch}.S
)

# Host adapters: unpack args -> call the REAL host Xlib / GL.
add_library(X11ThunkHost SHARED X11ThunkHost.cpp)
target_link_libraries(X11ThunkHost X11)

add_library(GLThunkHost SHARED GLThunkHost.cpp)
target_link_libraries(GLThunkHost GL)
