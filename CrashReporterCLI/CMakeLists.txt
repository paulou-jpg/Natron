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

# Ported from CrashReporterCLI.pro. Shares its sources with CrashReporter and
# differs only by REPORTER_CLI_ONLY and the absence of a GUI.
# The binary name is NatronRendererCrashReporter here; deployment renames it.

set(CrashReporterCLI_HEADERS
    ../CrashReporter/CallbacksManager.h
    ../Global/Macros.h
    ../Global/ProcInfo.h
    ../Global/StrUtils.h
)
set(CrashReporterCLI_SOURCES
    ../CrashReporter/main.cpp
    ../CrashReporter/CallbacksManager.cpp
    ../Global/ProcInfo.cpp
    ../Global/StrUtils.cpp
)

add_executable(NatronRendererCrashReporter
    ${CrashReporterCLI_HEADERS} ${CrashReporterCLI_SOURCES})

target_link_libraries(NatronRendererCrashReporter
    PRIVATE
        BreakpadClient
        Qt::Core
        Qt::Network
)
target_include_directories(NatronRendererCrashReporter
    PRIVATE
        ..
        ../Global
        ../CrashReporter
)
target_compile_definitions(NatronRendererCrashReporter PRIVATE REPORTER_CLI_ONLY)
if(WIN32)
    target_sources(NatronRendererCrashReporter PRIVATE ../Natron.rc)
    target_compile_definitions(NatronRendererCrashReporter PRIVATE $<$<CONFIG:Debug>:_DEBUG>)
endif()
