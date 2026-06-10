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

# Detect target architecture
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

# Configure HostRuntime
add_library(HostRuntime SHARED
    ../../2-callback/host/HostRuntime.cpp
    ../../2-callback/host/Invocation.cpp
    ../../2-callback/host/Arch/${_target_arch}/Coroutine_${_target_arch}.S
)

# Configure ZlibThunkHost
add_library(ZlibThunkHost SHARED
    ZlibThunkHost.cpp
)
target_link_libraries(ZlibThunkHost
    HostRuntime
    z
)