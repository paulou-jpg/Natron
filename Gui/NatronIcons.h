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

#ifndef Gui_NatronIcons_h
#define Gui_NatronIcons_h

// ***** BEGIN PYTHON BLOCK *****
// from <https://docs.python.org/3/c-api/intro.html#include-files>:
// "Since Python may define some pre-processor definitions which affect the standard headers on some systems, you must include Python.h before any standard headers are included."
#include <Python.h>
// ***** END PYTHON BLOCK *****

#include "Global/Macros.h"
#include "Global/Enums.h"

#include "Gui/GuiFwd.h"

NATRON_NAMESPACE_ENTER

/**
 * @brief Icon lookup for the desktop client.
 *
 * These forward to GuiApplicationManager, but exist so that widgets do not
 * reach the process-wide singleton to draw themselves. Icons are a client
 * resource, not engine state, and this was the single largest use of the
 * appPTR macro anywhere in the tree: 161 of the 842 uses, none of them in
 * Engine.
 *
 * The dependency now lives in one translation unit rather than 25, so
 * replacing it with an injected icon provider is a change to NatronIcons.cpp
 * instead of a change to every call site.
 *
 * See the maintainer guide's appPTR audit for the wider plan.
 **/
namespace NatronIcons {
/// Look up @p e at its natural size.
void get(PixmapEnum e, QPixmap* pix);

/// Look up @p e scaled to @p size.
void get(PixmapEnum e, int size, QPixmap* pix);
} // namespace NatronIcons

NATRON_NAMESPACE_EXIT

#endif // Gui_NatronIcons_h
