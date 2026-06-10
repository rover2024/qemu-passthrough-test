cmake_minimum_required(VERSION 3.19)

project(guest)

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

# Configure GuestRuntime
add_library(GuestRuntime SHARED
    GuestRuntime.c
)

# Configure ZlibDemo
add_library(CallbackDemo SHARED
    CallbackDemo.c
)
target_link_libraries(CallbackDemo
    GuestRuntime
)

# Configure Program
add_executable(Program
    Program.c
)
target_link_libraries(Program
    CallbackDemo
)
