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

set(Natron_SOURCES NatronApp_main.cpp)
if(WIN32)
    list(APPEND Natron_SOURCES ../Natron.rc)
endif()
add_executable(Natron ${Natron_SOURCES})
if(APPLE)
    # NatronInfo.plist.cmake.in mirrors the qmake template (NatronInfo.plist.in).
    # It carries the .ntp / .nps / .nl document-type associations and the
    # fr.inria bundle identifier, none of which CMake's default plist provides.
    set(MACOSX_BUNDLE_EXECUTABLE_NAME Natron)
    set(MACOSX_BUNDLE_ICON_FILE natronIcon.icns)
    set(MACOSX_BUNDLE_TYPEINFO Ntrn)

    set_target_properties(Natron PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "${PROJECT_NAME}"
        MACOSX_BUNDLE_INFO_STRING "${PROJECT_NAME} Copyright (c) 2023 The Natron Developers"
        MACOSX_BUNDLE_ICON_FILE "${MACOSX_BUNDLE_ICON_FILE}"
        MACOSX_BUNDLE_GUI_IDENTIFIER "fr.inria.Natron"
        MACOSX_BUNDLE_LONG_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_COPYRIGHT "Copyright (c) 2023 The Natron Developers"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/NatronInfo.plist.cmake.in"
    )

    # qmake's ICON= copies the icon into Resources/; CMake does not, and
    # CFBundleIconFile would otherwise name a file that is not in the bundle.
    set(NATRON_BUNDLE_ICONS
        ../Gui/Resources/Images/natronIcon.icns
        ../Gui/Resources/Images/natronProjectIcon_osx.icns
    )
    target_sources(Natron PRIVATE ${NATRON_BUNDLE_ICONS})
    set_source_files_properties(${NATRON_BUNDLE_ICONS} PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources)

    # qmake emits PkgInfo from QMAKE_PKGINFO_TYPEINFO; CMake does not.
    add_custom_command(TARGET Natron POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo_append "APPL${MACOSX_BUNDLE_TYPEINFO}"
                > "$<TARGET_BUNDLE_DIR:Natron>/Contents/PkgInfo"
        VERBATIM)
endif()
target_link_libraries(Natron
    PRIVATE
        NatronGui
        Python3::Python
)
target_include_directories(Natron
    PRIVATE
        ..
        ../Gui
        ../Engine
        ../Global
)

install(TARGETS Natron DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(FILES ../Gui/Resources/Applications/fr.natron.Natron.desktop
    DESTINATION "${CMAKE_INSTALL_DATADIR}/applications")
install(FILES ../Gui/Resources/Metainfo/fr.natron.Natron.appdata.xml
    DESTINATION "${CMAKE_INSTALL_DATADIR}/metainfo")
install(FILES ../Gui/Resources/Mime/x-natron.xml
    DESTINATION "${CMAKE_INSTALL_DATADIR}/mime")
install(FILES ../Gui/Resources/Images/natronIcon256_linux.png
    DESTINATION "${CMAKE_INSTALL_DATADIR}/pixmaps")
install(FILES ../Gui/Resources/Images/natronProjectIcon_linux.png
    DESTINATION "${CMAKE_INSTALL_DATADIR}/pixmaps")
