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

# Ported from BreakpadClient.pro. Source lists are kept in the same order as the
# qmake file so the two can be diffed while both build systems exist.

set(BREAKPAD_PATH ${CMAKE_SOURCE_DIR}/libs/google-breakpad/src)

# every *nix
set(BreakpadClient_SOURCES
    ${BREAKPAD_PATH}/client/minidump_file_writer.cc
    ${BREAKPAD_PATH}/common/convert_UTF.c
    ${BREAKPAD_PATH}/common/dwarf_cfi_to_module.cc
    ${BREAKPAD_PATH}/common/dwarf_cu_to_module.cc
    ${BREAKPAD_PATH}/common/dwarf_line_to_module.cc
    ${BREAKPAD_PATH}/common/language.cc
    ${BREAKPAD_PATH}/common/md5.cc
    ${BREAKPAD_PATH}/common/module.cc
    ${BREAKPAD_PATH}/common/simple_string_dictionary.cc
    ${BREAKPAD_PATH}/common/stabs_to_module.cc
    ${BREAKPAD_PATH}/common/string_conversion.cc
)

if(APPLE)
    # launch_reporter.cc is patched to launch the executable using the same arch,
    # so it lives here rather than in the submodule.
    list(APPEND BreakpadClient_SOURCES
        ${BREAKPAD_PATH}/client/mac/crash_generation/crash_generation_client.cc
        ${BREAKPAD_PATH}/client/mac/crash_generation/crash_generation_server.cc
        ${BREAKPAD_PATH}/client/mac/handler/breakpad_nlist_64.cc
        ${BREAKPAD_PATH}/client/mac/handler/dynamic_images.cc
        ${BREAKPAD_PATH}/client/mac/handler/exception_handler.cc
        ${BREAKPAD_PATH}/client/mac/handler/minidump_generator.cc
        ${BREAKPAD_PATH}/client/mac/handler/protected_memory_allocator.cc
        ${BREAKPAD_PATH}/common/mac/arch_utilities.cc
        ${BREAKPAD_PATH}/common/mac/bootstrap_compat.cc
        ${BREAKPAD_PATH}/common/mac/file_id.cc
        common/mac/launch_reporter.cc
        ${BREAKPAD_PATH}/common/mac/macho_id.cc
        ${BREAKPAD_PATH}/common/mac/macho_reader.cc
        ${BREAKPAD_PATH}/common/mac/macho_utilities.cc
        ${BREAKPAD_PATH}/common/mac/macho_walker.cc
        ${BREAKPAD_PATH}/common/mac/string_utilities.cc
        ${BREAKPAD_PATH}/common/mac/MachIPC.mm
    )
elseif(UNIX)
    list(APPEND BreakpadClient_SOURCES
        ${BREAKPAD_PATH}/client/linux/crash_generation/crash_generation_client.cc
        ${BREAKPAD_PATH}/client/linux/crash_generation/crash_generation_server.cc
        ${BREAKPAD_PATH}/client/linux/dump_writer_common/thread_info.cc
        ${BREAKPAD_PATH}/client/linux/dump_writer_common/ucontext_reader.cc
        ${BREAKPAD_PATH}/client/linux/handler/exception_handler.cc
        ${BREAKPAD_PATH}/client/linux/handler/minidump_descriptor.cc
        ${BREAKPAD_PATH}/client/linux/log/log.cc
        ${BREAKPAD_PATH}/client/linux/microdump_writer/microdump_writer.cc
        ${BREAKPAD_PATH}/client/linux/minidump_writer/linux_core_dumper.cc
        ${BREAKPAD_PATH}/client/linux/minidump_writer/linux_dumper.cc
        ${BREAKPAD_PATH}/client/linux/minidump_writer/linux_ptrace_dumper.cc
        ${BREAKPAD_PATH}/client/linux/minidump_writer/minidump_writer.cc
        ${BREAKPAD_PATH}/common/linux/crc32.cc
        ${BREAKPAD_PATH}/common/linux/dump_symbols.cc
        ${BREAKPAD_PATH}/common/linux/elf_core_dump.cc
        ${BREAKPAD_PATH}/common/linux/elf_symbols_to_module.cc
        ${BREAKPAD_PATH}/common/linux/elfutils.cc
        ${BREAKPAD_PATH}/common/linux/file_id.cc
        ${BREAKPAD_PATH}/common/linux/google_crashdump_uploader.cc
        ${BREAKPAD_PATH}/common/linux/guid_creator.cc
        ${BREAKPAD_PATH}/common/linux/http_upload.cc
        ${BREAKPAD_PATH}/common/linux/libcurl_wrapper.cc
        ${BREAKPAD_PATH}/common/linux/linux_libc_support.cc
        ${BREAKPAD_PATH}/common/linux/memory_mapped_file.cc
        ${BREAKPAD_PATH}/common/linux/safe_readlink.cc
        ${BREAKPAD_PATH}/common/linux/synth_elf.cc
    )
elseif(WIN32)
    set(BreakpadClient_SOURCES
        ${BREAKPAD_PATH}/client/windows/crash_generation/client_info.cc
        ${BREAKPAD_PATH}/client/windows/crash_generation/crash_generation_client.cc
        ${BREAKPAD_PATH}/client/windows/crash_generation/crash_generation_server.cc
        ${BREAKPAD_PATH}/client/windows/crash_generation/minidump_generator.cc
        ${BREAKPAD_PATH}/client/windows/handler/exception_handler.cc
        ${BREAKPAD_PATH}/client/windows/sender/crash_report_sender.cc
        ${BREAKPAD_PATH}/common/windows/guid_string.cc
        ${BREAKPAD_PATH}/common/windows/http_upload.cc
        ${BREAKPAD_PATH}/common/windows/string_utils.cc
    )
endif()

add_library(BreakpadClient STATIC ${BreakpadClient_SOURCES})

# AUTOMOC is on globally, but this is plain C++ with no Qt in it.
set_target_properties(BreakpadClient PROPERTIES AUTOMOC OFF AUTORCC OFF)

target_include_directories(BreakpadClient PUBLIC ${BREAKPAD_PATH})
target_compile_definitions(BreakpadClient PUBLIC NATRON_USE_BREAKPAD)
if(WIN32)
    target_compile_definitions(BreakpadClient PUBLIC UNICODE)
endif()
if(UNIX AND NOT APPLE)
    # used by breakpad internals on Linux
    target_compile_definitions(BreakpadClient PUBLIC N_UNDF=0)
endif()

# External library: silence its warnings rather than carrying them forever.
if(MSVC)
    target_compile_options(BreakpadClient PRIVATE /w)
else()
    target_compile_options(BreakpadClient PRIVATE -w)
endif()
