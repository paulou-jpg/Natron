#!/usr/bin/env bash
# ***** BEGIN LICENSE BLOCK *****
# This file is part of Natron <http://www.natron.fr/>,
# Copyright (C) 2016 INRIA and Alexandre Gauthier
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
#
# Install built .ofx.bundle plug-ins into a Natron.app and make them loadable.
#
# Natron looks for bundled plug-ins in
#   <bundle>/Contents/Plugins/OFX/Natron
# (Engine/OfxHost.cpp), so that is where these go.
#
# openfx's osxDeploy.sh already copies most dependencies into each plug-in's
# Contents/Libraries, but it misses two cases that stop the plug-in loading:
#   - transitive @rpath dependencies it never walked (e.g. libjxl_cms via OIIO)
#   - absolute references to libraries that no longer exist at that path
#     (e.g. a Homebrew libOpenColorIO built against an older Imath)
# Both are repaired here against the copies already inside the bundle.
#
# Usage: install-ofx-plugins.sh <Natron.app> <plugin.ofx.bundle> [...]

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "usage: $(basename "$0") <Natron.app> <plugin.ofx.bundle> [...]" >&2
    exit 1
fi

APP="$1"; shift
if [ ! -d "$APP/Contents/MacOS" ]; then
    echo "error: $APP is not an application bundle" >&2
    exit 1
fi

DEST="$APP/Contents/Plugins/OFX/Natron"
mkdir -p "$DEST"

for bundle in "$@"; do
    if [ ! -d "$bundle" ]; then
        echo "error: no such plug-in bundle: $bundle" >&2
        exit 1
    fi
    name="$(basename "$bundle")"
    echo "==> installing $name"
    rm -rf "${DEST:?}/$name"
    cp -R "$bundle" "$DEST/"

    libdir="$DEST/$name/Contents/Libraries"
    [ -d "$libdir" ] || continue

    # Repoint absolute references whose target is gone at a copy inside the
    # bundle, when one with the exact same install name is present.
    for f in "$libdir"/*.dylib "$DEST/$name/Contents/MacOS/"*.ofx; do
        [ -e "$f" ] || continue
        otool -L "$f" | awk 'NR>1{print $1}' | while read -r dep; do
            case "$dep" in
                /*) ;;
                *) continue ;;
            esac
            [ -e "$dep" ] && continue
            # System libraries live in the dyld shared cache and have no file
            # on disk, so a missing path there is not a broken reference.
            case "$dep" in
                /usr/lib/*|/System/*) continue ;;
            esac
            base="$(basename "$dep")"
            if [ ! -e "$libdir/$base" ]; then
                # Homebrew upgrades move the opt/ symlink to a newer version
                # while a dependent library still names the old one (e.g. an
                # OpenColorIO built against yaml-cpp 0.8 after yaml-cpp 0.9 is
                # linked). The exact version usually survives in the Cellar as
                # an unlinked keg, so take it from there.
                for srcdir in /usr/local/opt/*/lib /usr/local/Cellar/*/*/lib; do
                    if [ -e "$srcdir/$base" ]; then
                        cp -f "$srcdir/$base" "$libdir/$base"
                        chmod u+w "$libdir/$base"
                        echo "    + $base (from ${srcdir})"
                        break
                    fi
                done
            fi
            if [ -e "$libdir/$base" ]; then
                install_name_tool -change "$dep" "@loader_path/$base" "$f" 2>/dev/null || true
            else
                echo "warning: $name: unresolved $dep"
            fi
        done
    done

    # Copy in @rpath dependencies osxDeploy.sh did not walk, repeating until
    # the set closes (a copied library brings its own dependencies with it).
    for _ in $(seq 1 12); do
        missing=""
        for f in "$libdir"/*.dylib "$DEST/$name/Contents/MacOS/"*.ofx; do
            [ -e "$f" ] || continue
            while read -r dep; do
                case "$dep" in
                    @rpath/*) ;;
                    *) continue ;;
                esac
                base="${dep#@rpath/}"
                [ -e "$libdir/$base" ] || missing="$missing $base"
            done < <(otool -L "$f" | awk 'NR>1{print $1}')
        done
        missing="$(echo "$missing" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
        [ -z "${missing// /}" ] && break
        progress=0
        for base in $missing; do
            for srcdir in /usr/local/opt/*/lib; do
                if [ -e "$srcdir/$base" ]; then
                    cp -f "$srcdir/$base" "$libdir/$base"
                    chmod u+w "$libdir/$base"
                    echo "    + $base"
                    progress=1
                    break
                fi
            done
        done
        if [ "$progress" = "0" ]; then
            echo "warning: $name: could not resolve:$missing"
            break
        fi
    done

    # Editing load commands invalidates the signature; macOS then refuses to
    # dlopen the plug-in.
    codesign --force --sign - "$libdir"/*.dylib 2>/dev/null || true
    codesign --force --sign - "$DEST/$name" 2>/dev/null || true
done

echo "==> installed into $DEST"
