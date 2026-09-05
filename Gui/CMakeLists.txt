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

file(GLOB NatronEngine_HEADERS ../Engine/*.h)
file(GLOB NatronGui_HEADERS *.h)
file(GLOB NatronGui_SOURCES *.cpp)

set(PYGUI_OUT ${CMAKE_CURRENT_BINARY_DIR}/Qt${QT_VERSION_MAJOR})
set(PYGUI_INCLUDE_DIRS . .. ../Engine ../Global ../libs/OpenFX/include)
list(APPEND PYGUI_INCLUDE_DIRS ${PYSIDE_INCLUDE_DIRS} ${PYSIDE_INCLUDE_DIRS}/QtCore
    ${PYSIDE_INCLUDE_DIRS}/QtGui ${PYSIDE_INCLUDE_DIRS}/QtWidgets)
list(APPEND PYGUI_INCLUDE_DIRS ${QTCORE_INCLUDE_DIRS} ${QTGUI_INCLUDE_DIRS}
    ${QTWIDGETS_INCLUDE_DIRS} ${Python3_INCLUDE_DIRS} ${Boost_INCLUDE_DIRS})
list(TRANSFORM PYGUI_INCLUDE_DIRS PREPEND "-I" OUTPUT_VARIABLE PYGUI_INCS)
set(PYGUI_HEADER PySide${PYSIDE_VERSION_MAJOR}_Gui_Python.h)

if(NATRON_QT6)
    set(QT_OPENGLWIDGETS Qt::OpenGLWidgets)
endif()

set(shiboken_args
    "-std=c++17" "--enable-parent-ctor-heuristic" "--use-isnull-as-nb_nonzero"
    "--avoid-protected-hack" "--enable-pyside-extensions"
    ${PYGUI_INCS}
    "-T../Engine" "-T${PYSIDE_TYPESYSTEMS}" "--output-directory=${PYGUI_OUT}"
    "${PYGUI_HEADER}" "typesystem_natronGui.xml")

execute_process(COMMAND ${Python3_EXECUTABLE} ../tools/utils/sourceList.py typesystem_natronGui.xml ${PYGUI_OUT}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE PyGui_SOURCES)
set_property(SOURCE ${PyGui_SOURCES} PROPERTY SKIP_AUTOGEN ON)
add_custom_command(OUTPUT ${PyGui_SOURCES}
    COMMAND $<TARGET_FILE:${SHIBOKEN_EXE}> ${shiboken_args}
    COMMAND ${Python3_EXECUTABLE} ../tools/utils/sourceCleanup.py typesystem_natronGui.xml ${PYGUI_OUT}
    DEPENDS ${SHIBOKEN_EXE} ${PYGUI_HEADER} NatronEngine ${NatronGui_HEADERS} ../tools/utils/sourceCleanup.py typesystem_natronGui.xml
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

if(APPLE)
    list(APPEND NatronGui_SOURCES QtMac.mm TaskBarMac.mm)
endif()

list(APPEND NatronGui_SOURCES
    ${NatronGui_SOURCES}
    ${PyGui_SOURCES}
    GuiResources.qrc
)
add_library(NatronGui STATIC ${NatronGui_HEADERS} ${NatronGui_SOURCES})
target_link_libraries(NatronGui
    PUBLIC
        ${SHIBOKEN_LIB}
        ${PYSIDE_LIB}
        Qt::Core
        Qt::Concurrent
        Qt::Network
        Qt::Gui
        Qt::Widgets
        ${QT_OPENGLWIDGETS}
        Python3::Module
        NatronEngine
    PRIVATE
        qhttpserver
)
target_include_directories(NatronGui
    PRIVATE
        ${PYSIDE_INCLUDE_DIRS}/QtCore
        ${PYSIDE_INCLUDE_DIRS}/QtGui
        ${PYSIDE_INCLUDE_DIRS}/QtWidgets
        .
        ..
        ../Engine
        ../Global
        ../libs/SequenceParsing
        ../libs/qhttpserver/src
        ${CMAKE_BINARY_DIR}/Engine/Qt${QT_VERSION_MAJOR}/NatronEngine
)
target_compile_definitions(NatronGui
    PRIVATE
        NATRON_CUSTOM_BUILD_USER_TOKEN="${BUILD_USER_NAME}"
        QT_NO_KEYWORDS
)

# ---------------------------------------------------------------------------
# fontconfig configuration
#
# Ported from qmake: App.pro listed fonts.conf.in under QMAKE_SUBSTITUTES, and
# global.pri built the FC_* directory lists per platform. The packaging scripts
# copy the generated fonts.conf into the installer, so it must still be
# produced -- but into the build tree, since the CMake build is out-of-source.
if(APPLE)
    set(FC_DEFAULT_FONTS
        "<dir>/usr/local/share/fonts</dir>"           # Homebrew
        "<dir>/opt/X11/share/fonts</dir>"             # XQuartz
        "<dir>/opt/local/share/fonts</dir>"           # MacPorts
        "<dir>/System/Library/Fonts</dir>"
        "<dir>/Network/Library/Fonts</dir>"
        "<dir>/Library/Fonts</dir>"
        "<dir>~/Library/Fonts</dir>"
        "<dir>/System/Library/Assets/com_apple_MobileAsset_Font3</dir>"
        "<dir>/System/Library/Assets/com_apple_MobileAsset_Font4</dir>"
        "<dir>/System/Library/Assets/com_apple_MobileAsset_Font5</dir>")
    # There is no system-default cache directory on macOS.
    set(FC_CACHEDIR "")
elseif(WIN32)
    set(FC_DEFAULT_FONTS
        "<dir>WINDOWSFONTDIR</dir>"
        # Windows 10 introduced user fonts, the preferred install location.
        "<dir>~/AppData/Local/Microsoft/Windows/Fonts</dir>")
    set(FC_CACHEDIR "<cachedir>LOCAL_APPDATA_FONTCONFIG_CACHE</cachedir>")
else()
    set(FC_DEFAULT_FONTS
        "<dir>/usr/share/fonts</dir>"
        "<dir>/usr/X11/lib/X11/fonts</dir>"
        "<dir>/usr/X11R6/lib/X11/fonts</dir>"
        "<dir>/usr/share/X11/fonts</dir>"
        "<dir>/usr/local/share/fonts</dir>")
    set(FC_CACHEDIR "<dir>/var/cache/fontconfig</dir>")
endif()

list(JOIN FC_DEFAULT_FONTS "\n\t" FC_DEFAULT_FONTS_TEXT)
list(JOIN FC_CACHEDIR "\n\t" FC_CACHEDIR_TEXT)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/Resources/etc/fonts/fonts.conf.in" NATRON_FONTS_CONF)
string(REPLACE "$$FC_DEFAULT_FONTS" "${FC_DEFAULT_FONTS_TEXT}" NATRON_FONTS_CONF "${NATRON_FONTS_CONF}")
string(REPLACE "$$FC_CACHEDIR"      "${FC_CACHEDIR_TEXT}"      NATRON_FONTS_CONF "${NATRON_FONTS_CONF}")
# qmake's substitution also unescapes the quoting in the template.
string(REPLACE "\\\"" "\"" NATRON_FONTS_CONF "${NATRON_FONTS_CONF}")
string(REPLACE "\\'"  "'"  NATRON_FONTS_CONF "${NATRON_FONTS_CONF}")
file(WRITE "${CMAKE_BINARY_DIR}/Gui/Resources/etc/fonts/fonts.conf" "${NATRON_FONTS_CONF}")
