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

# Guest-side runtime (client stubs over the magic syscall).
add_library(GuestRuntime SHARED
    ../../2-callback/guest/GuestRuntime.c
)

# Drop-in libX11 -> host Xlib.
add_library(X11Thunk SHARED X11Thunk.c)
target_link_libraries(X11Thunk GuestRuntime)
set_target_properties(X11Thunk PROPERTIES OUTPUT_NAME X11)
add_custom_command(TARGET X11Thunk POST_BUILD
    COMMAND ln -sf $<TARGET_FILE_NAME:X11Thunk> $<TARGET_FILE:X11Thunk>.6)

# Drop-in libGL -> host GL/GLX.
add_library(GLThunk SHARED GLThunk.c)
target_link_libraries(GLThunk GuestRuntime)
set_target_properties(GLThunk PROPERTIES OUTPUT_NAME GL)
add_custom_command(TARGET GLThunk POST_BUILD
    COMMAND ln -sf $<TARGET_FILE_NAME:GLThunk> $<TARGET_FILE:GLThunk>.1)

# The graphics program, linked against the thunk libGL / libX11.
add_executable(Program Program.cpp)
target_link_libraries(Program GLThunk X11Thunk m)
