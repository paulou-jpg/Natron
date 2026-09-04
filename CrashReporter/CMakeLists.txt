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

# Ported from CrashReporter.pro.
# The binary name is NatronCrashReporter here; deployment renames it.

set(CrashReporter_HEADERS
    CrashDialog.h
    CallbacksManager.h
    ../Global/Macros.h
    ../Global/ProcInfo.h
    ../Global/StrUtils.h
)
set(CrashReporter_SOURCES
    CrashDialog.cpp
    main.cpp
    CallbacksManager.cpp
    ../Global/ProcInfo.cpp
    ../Global/StrUtils.cpp
    ../Gui/GuiResources.qrc
)

add_executable(NatronCrashReporter ${CrashReporter_HEADERS} ${CrashReporter_SOURCES})

target_link_libraries(NatronCrashReporter
    PRIVATE
        BreakpadClient
        Qt::Core
        Qt::Network
        Qt::Gui
        Qt::Widgets
)
target_include_directories(NatronCrashReporter
    PRIVATE
        ..
        ../Global
)
if(WIN32)
    target_sources(NatronCrashReporter PRIVATE ../Natron.rc)
    # google-breakpad uses _DEBUG to determine whether the build is a debug one.
    target_compile_definitions(NatronCrashReporter PRIVATE $<$<CONFIG:Debug>:_DEBUG>)
endif()
