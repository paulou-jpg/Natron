/* ***** BEGIN LICENSE BLOCK *****
 * This file is part of Natron <https://natrongithub.github.io/>,
 * (C) 2018-2023 The Natron developers
 * (C) 2013-2018 INRIA and Alexandre Gauthier-Foichat
 *
 * Natron is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Natron is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Natron.  If not, see <http://www.gnu.org/licenses/gpl-2.0.html>
 * ***** END LICENSE BLOCK ***** */

#ifndef Global_MainThread_h
#define Global_MainThread_h

#include <thread>

#include "Global/Macros.h"
#include "Global/MainThread.h"

NATRON_NAMESPACE_ENTER

/**
 * @brief Whether the caller is running on the process's main thread.
 *
 * The core used to answer this by comparing the current QThread against the Qt
 * application object's thread,
 * which made a plain "am I on the main thread" question depend on a Qt
 * application object existing. That single idiom accounted for the large
 * majority of the core's references to qApp, and the great majority of those
 * were inside assert(), so the dependency was mostly a debug-build artefact
 * rather than anything the renderer needed.
 *
 * The identity is captured during static initialisation, which runs on the main
 * thread, so this is correct without any initialisation call. setMainThread()
 * exists for hosts that load Natron from a thread other than the one that ran
 * static initialisation.
 **/
namespace MainThread {
namespace detail {
/// Captured during static initialisation, i.e. on the main thread.
inline std::thread::id gMainThreadId = std::this_thread::get_id();
} // namespace detail

/// Declare the calling thread to be the main thread.
inline void
setMainThread()
{
    detail::gMainThreadId = std::this_thread::get_id();
}

inline bool
isMainThread()
{
    return std::this_thread::get_id() == detail::gMainThreadId;
}
} // namespace MainThread

NATRON_NAMESPACE_EXIT

#endif // Global_MainThread_h
