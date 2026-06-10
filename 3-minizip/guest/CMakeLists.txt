cmake_minimum_required(VERSION 3.19)

project(guest)

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

# Configure GuestRuntime
add_library(GuestRuntime SHARED
    ../../2-callback/guest/GuestRuntime.c
)

# Configure ZlibThunk
add_library(ZlibThunk SHARED
    ZlibThunk.c
)
target_link_libraries(ZlibThunk
    GuestRuntime
)
set_target_properties(ZlibThunk
    PROPERTIES
    OUTPUT_NAME z
)
add_custom_command(
    TARGET ZlibThunk POST_BUILD
    COMMAND ln -s $<TARGET_FILE:ZlibThunk> $<TARGET_FILE:ZlibThunk>.1
)

# set(MINIZIP_BUILD_STATIC FALSE)
# set(MINIZIP_BUILD_TESTING FALSE)
# set(MINIZIP_ENABLE_BZIP2 FALSE)
# set(MINIZIP_INSTALL FALSE)
# add_subdirectory(minizip)
