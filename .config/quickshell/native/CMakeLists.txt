cmake_minimum_required(VERSION 3.21)
project(qs_native LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Qml Concurrent)

# QML 1.0 plugin loaded by bridge.qml (a directory import of a C++ module resolves through the real
# file system, which the qs: URLs of the config folder do not).
add_library(qsnativeplugin MODULE
    src/plugin.cpp
    src/native.cpp
    src/native.h
    src/procs.cpp
    src/procs.h
    src/gpu.cpp
    src/gpu.h
)
target_link_libraries(qsnativeplugin PRIVATE Qt6::Core Qt6::Qml Qt6::Concurrent ${CMAKE_DL_LIBS})
target_compile_options(qsnativeplugin PRIVATE -Wall -Wextra)
set_target_properties(qsnativeplugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/QsNative"
)
