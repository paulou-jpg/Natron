# ***** BEGIN LICENSE BLOCK *****
# This file is part of Natron <https://natrongithub.github.io/>,
# (C) 2018-2023 The Natron developers
# (C) 2013-2018 INRIA and Alexandre Gauthier-Foichat
#
# Natron is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Natron is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Natron.  If not, see <http://www.gnu.org/licenses/gpl-2.0.html>
# ***** END LICENSE BLOCK *****

cmake_minimum_required(VERSION 3.16.7)

project(Natron
    VERSION "2.6.0"
    DESCRIPTION "Open Source Compositing Software"
    HOMEPAGE_URL "https://natrongithub.github.io/"
    LANGUAGES CXX C
)

set(CMAKE_CXX_STANDARD 17)

include(GNUInstallDirs)

option(NATRON_QT6 "use Qt6" OFF)
option(NATRON_BUILD_TESTS "build the Natron test suite" ON)
option(NATRON_BREAKPAD "build the breakpad crash reporter" OFF)
option(NATRON_OPENMP "build with OpenMP enabled" OFF)
option(NATRON_NO_ASSERTIONS "disable assertions and Qt debug output (release builds)" OFF)

# Build identification. These mirror global.pri's CONFIG+=snapshot/alpha/beta/RC/
# stable flags and its BUILD_NUMBER / BUILD_USER_NAME variables, so that
# tools/jenkins/build-natron.sh produces identically-tagged binaries under CMake.
set(NATRON_DEV_STATUS "" CACHE STRING
    "Release status: SNAPSHOT, ALPHA, BETA, RC, STABLE, CUSTOM, or empty")
set_property(CACHE NATRON_DEV_STATUS PROPERTY STRINGS
    "" SNAPSHOT ALPHA BETA RC STABLE CUSTOM)
set(NATRON_BUILD_NUMBER 0 CACHE STRING "Build number for ALPHA/BETA/RC builds")
set(BUILD_USER_NAME "" CACHE STRING "User/client name shown by a CUSTOM build")

set(IS_DEBUG_BUILD OFF)
if(CMAKE_BUILD_TYPE MATCHES "^(debug|Debug|DEBUG)$")
    set(IS_DEBUG_BUILD ON)
    add_definitions(-DDEBUG)

    if(WIN32)
        # Debug builds need minimal optimizations to avoid excessive link times and link errors related to Eigen.
        add_compile_options(-O)
    endif()
else()
    add_definitions(-DQT_NO_DEBUG_OUTPUT)
endif()

if(NOT DEFINED CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE STREQUAL "")
    set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING "Choose the type of build." FORCE)
    message(STATUS "Setting build type to '${CMAKE_BUILD_TYPE}' as none was specified.")
endif()

find_package(Boost COMPONENTS headers serialization CONFIG)
if(WIN32)
    # Prevent looking in the registry so that the MinGW python can be found.
    set(Python3_FIND_REGISTRY NEVER)
endif()
find_package(Python3 COMPONENTS Interpreter Development)

if(IS_DEBUG_BUILD AND WIN32)
    # Explicitly setting SHIBOKEN_PYTHON_LIBRARIES variable to avoid PYTHON_DEBUG_LIBRARY-NOTFOUND
    # link errors on Windows debug builds.
    set(SHIBOKEN_PYTHON_LIBRARIES ${Python3_LIBRARIES})
endif()

set(QT_COMPONENTS Core Gui Network Widgets Concurrent)
if(NATRON_QT6)
    list(APPEND QT_COMPONENTS OpenGLWidgets)
    find_package(Qt6 6.3 CONFIG REQUIRED COMPONENTS ${QT_COMPONENTS})
    find_package(Shiboken6 6.3 CONFIG REQUIRED COMPONENTS libshiboken6)
    find_package(Shiboken6Tools 6.3 CONFIG REQUIRED COMPONENTS shiboken6)
    find_package(PySide6 6.3 CONFIG REQUIRED COMPONENTS pyside6)
    set(QT_VERSION_MAJOR 6)
    set(PYSIDE_VERSION_MAJOR 6)

    get_target_property(PYSIDE_INCLUDE_DIRS PySide6::pyside6 INTERFACE_INCLUDE_DIRECTORIES)
    set(QTCORE_INCLUDE_DIRS ${Qt6Core_INCLUDE_DIRS})
    set(QTGUI_INCLUDE_DIRS ${Qt6Gui_INCLUDE_DIRS})
    set(QTWIDGETS_INCLUDE_DIRS ${Qt6Widgets_INCLUDE_DIRS})

    set(SHIBOKEN_EXE Shiboken6::shiboken6)
    set(SHIBOKEN_LIB Shiboken6::libshiboken)
    set(PYSIDE_LIB PySide6::pyside6)
else()
    find_package(Qt5 5.15 CONFIG REQUIRED COMPONENTS ${QT_COMPONENTS})
    find_package(Shiboken2 5.15 CONFIG REQUIRED COMPONENTS libshiboken2 shiboken2)

    find_package(PySide2 5.15 CONFIG REQUIRED COMPONENTS pyside2)
    set(QT_VERSION_MAJOR 5)
    set(PYSIDE_VERSION_MAJOR 2)

    get_target_property(PYSIDE_INCLUDE_DIRS PySide2::pyside2 INTERFACE_INCLUDE_DIRECTORIES)
    set(QTCORE_INCLUDE_DIRS ${Qt5Core_INCLUDE_DIRS})
    set(QTGUI_INCLUDE_DIRS ${Qt5Gui_INCLUDE_DIRS})
    set(QTWIDGETS_INCLUDE_DIRS ${Qt5Widgets_INCLUDE_DIRS})

    set(SHIBOKEN_EXE Shiboken2::shiboken2)
    set(SHIBOKEN_LIB Shiboken2::libshiboken)
    set(PYSIDE_LIB PySide2::pyside2)
endif()

if(IS_DEBUG_BUILD AND WIN32)
    # Remove NDEBUG from Shiboken INTERFACE_COMPILE_DEFINITIONS so it is not inherited in debug builds.
    get_property(SHIBOKEN_DEFS TARGET ${SHIBOKEN_LIB} PROPERTY INTERFACE_COMPILE_DEFINITIONS)
    list(REMOVE_ITEM SHIBOKEN_DEFS NDEBUG)
    set_property(TARGET ${SHIBOKEN_LIB} PROPERTY INTERFACE_COMPILE_DEFINITIONS ${SHIBOKEN_DEFS})
endif()

# Some distributions build Shiboken against CPython's limited API and propagate
# Py_LIMITED_API through its imported target. Natron embeds the interpreter
# directly and calls PyRun_String, PyRun_SimpleString and Py_CompileString,
# none of which the limited API exposes, so the definition must not be
# inherited.
get_property(SHIBOKEN_DEFS TARGET ${SHIBOKEN_LIB} PROPERTY INTERFACE_COMPILE_DEFINITIONS)
if(SHIBOKEN_DEFS)
    list(FILTER SHIBOKEN_DEFS EXCLUDE REGEX "^Py_LIMITED_API")
    set_property(TARGET ${SHIBOKEN_LIB} PROPERTY INTERFACE_COMPILE_DEFINITIONS ${SHIBOKEN_DEFS})
endif()

if(NATRON_DEV_STATUS STREQUAL "CUSTOM")
    if(BUILD_USER_NAME STREQUAL "")
        message(FATAL_ERROR "BUILD_USER_NAME must be set when NATRON_DEV_STATUS=CUSTOM")
    endif()
elseif(NOT NATRON_DEV_STATUS STREQUAL "")
    add_compile_definitions(NATRON_CONFIG_${NATRON_DEV_STATUS})
endif()
add_compile_definitions(NATRON_BUILD_NUMBER=${NATRON_BUILD_NUMBER})

if(NATRON_NO_ASSERTIONS)
    # See http://doc.qt.io/qt-4.8/debug.html
    add_compile_definitions(NDEBUG QT_NO_DEBUG QT_NO_DEBUG_OUTPUT QT_NO_WARNING_OUTPUT)
endif()

if(NATRON_OPENMP)
    find_package(OpenMP REQUIRED)
    link_libraries(OpenMP::OpenMP_CXX)
endif()

#Since in Natron and OpenFX all strings are supposed UTF-8 and that the constructor
#for QString(const char*) assumes ASCII strings, we may run into troubles
add_compile_definitions(QT_NO_CAST_FROM_ASCII)

if (MSVC)
    # Allow __cplusplus to properly reflect the c++ standard version.
    add_compile_options(/Zc:__cplusplus)
    add_compile_definitions(__STDC_LIMIT_MACROS WIN32_LEAN_AND_MEAN _USE_MATH_DEFINES)
else()
    SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wmissing-prototypes" )
    add_compile_options(-Wall -Wextra -Wmissing-declarations -Wno-multichar -Winit-self -Wno-long-long
                        -Wvla -Wdate-time -Wno-format-overflow -Wno-deprecated-copy)
    if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        add_compile_options(-Wshift-overflow=2 -Wduplicated-cond -Wno-stringop-overflow)
    endif()
endif()

# Eigen and glog are supplied by the package manager (see vcpkg.json); the
# in-tree copies have been removed. Both are pinned in the manifest: the
# bundled Eigen was 3.3.7 against a vcpkg default of 5.0.1, and the bundled
# glog was 0.3.4 against a default of 0.7.1, which moved LogMessageVoidify out
# of namespace google and so breaks libmv/logging/logging.h.
#
# Ceres deliberately stays vendored at 1.12: libmv calls
# ceres::LocalParameterization (libs/libmv/libmv/simple_pipeline/modal_solver.cc),
# which was removed in Ceres 2.2. Porting libmv to the Manifold API is a
# separate piece of work from the build system.
find_package(Eigen3 3.4 CONFIG REQUIRED)
find_package(glog CONFIG REQUIRED)

if(UNIX AND NOT APPLE)
    # Portable archive layout: binaries land in bin/, their libraries in lib/.
    # Ported from tools/jenkins/include/natron/Linux.pri.
    set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib")
    set(CMAKE_BUILD_RPATH "$ORIGIN/../lib")

    find_package(ECM NO_MODULE)
    set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_MODULE_PATH})
    find_package(X11 REQUIRED)
    find_package(Wayland COMPONENTS Client Egl)
elseif(APPLE)
    enable_language(OBJCXX)
elseif(WIN32)
    # --build-id is required by the breakpad stackwalker (mingw + binutils 2.25+).
    # Ported from tools/jenkins/include/natron/Windows.pri.
    if(NOT MSVC)
        add_link_options(-Wl,--build-id)
    endif()

    enable_language(RC)
    add_compile_definitions(WINDOWS WIN32 _UNICODE UNICODE NOMINMAX QHTTP_SERVER_STATIC)
    add_compile_definitions(COMPILED_FROM_DSP XML_STATIC) # for expat
    if (NOT MSVC)
        add_compile_options(-municode)
        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            add_compile_options(-mwindows -mthreads)
        endif()
        add_link_options(-mwindows -municode)
        set(CMAKE_RC_COMPILER_INIT windres)
        set(CMAKE_RC_COMPILE_OBJECT
            "<CMAKE_RC_COMPILER> <FLAGS> -O coff <DEFINES> -i <SOURCE> -o <OBJECT>")
    endif()
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

enable_testing()

add_subdirectory(libs)

# Must precede Engine: AppManagerPrivate.h includes breakpad's exception_handler.h
# when NATRON_USE_BREAKPAD is defined, and BreakpadClient carries that define.
if(NATRON_BREAKPAD)
    add_subdirectory(BreakpadClient)
    add_subdirectory(CrashReporter)
    add_subdirectory(CrashReporterCLI)
endif()

add_subdirectory(HostSupport)

add_subdirectory(Engine)

add_subdirectory(PythonBin)

add_subdirectory(Renderer)

add_subdirectory(Gui)

if(NATRON_BUILD_TESTS)
    find_package(GTest CONFIG REQUIRED)
    add_subdirectory(Tests)
endif()

add_subdirectory(App)
