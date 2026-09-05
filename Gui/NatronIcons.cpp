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

// ***** BEGIN PYTHON BLOCK *****
// from <https://docs.python.org/3/c-api/intro.html#include-files>:
// "Since Python may define some pre-processor definitions which affect the standard headers on some systems, you must include Python.h before any standard headers are included."
#include <Python.h>
// ***** END PYTHON BLOCK *****

#include "NatronIcons.h"

#include <QPixmap>

#include "Gui/GuiApplicationManager.h"
#include "Gui/NatronIcons.h"

NATRON_NAMESPACE_ENTER

namespace NatronIcons {
void
get(PixmapEnum e,
    QPixmap* pix)
{
    // The one place the desktop client's icon lookup depends on the
    // process-wide singleton. Replacing appPTR with an injected provider is a
    // change to these two functions.
    NatronIcons::get(e, pix);
}

void
get(PixmapEnum e,
    int size,
    QPixmap* pix)
{
    NatronIcons::get(e, size, pix);
}
} // namespace NatronIcons

NATRON_NAMESPACE_EXIT
