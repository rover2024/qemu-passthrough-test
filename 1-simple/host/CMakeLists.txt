cmake_minimum_required(VERSION 3.19)

project(host)

if (NOT DEFINED CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
endif()

if (NOT DEFINED CMAKE_LIBRARY_OUTPUT_DIRECTORY)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
endif()

if (NOT DEFINED CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
endif()

add_link_options("-Wl,-z,defs")

# Configure HostRuntime
add_library(HostRuntime SHARED
    HostRuntime.c
)

# Configure ZlibDemoHost
add_library(ZlibDemoHost SHARED
    ZlibDemoHost.c
)
target_link_libraries(ZlibDemoHost
    HostRuntime
    z
)