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

# Remaining in-tree third-party code, and why each one is still here:
#   ceres    - pinned to 1.12; libmv uses the pre-2.2 LocalParameterization API
#   libmv    - no upstream package exists
#   openMVG  - v0.9 plus four Natron patches, two of them Natron-authored
#   libtess  - a Natron fork of the SGI GLU tessellator
#   hoedown  - no vcpkg port exists
#   qhttpserver - no vcpkg port exists; backs Gui/DocumentationManager
add_subdirectory(hoedown)
add_subdirectory(libtess)
add_subdirectory(ceres)
add_subdirectory(libmv)
add_subdirectory(openMVG)
add_subdirectory(qhttpserver)
