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
# Make a built Natron.app self-contained.
#
# A freshly built bundle links against Qt, Python and PySide6 through absolute
# paths into the build machine's Homebrew and PySide prefixes, so it only runs
# on the machine that built it. This copies those dependencies into the bundle
# and rewrites the load commands to point inside it.
#
# Natron computes its Python home as
#   <bundle>/Contents/MacOS/../Frameworks/Python.framework/Versions/<X.Y>
# (Global/PythonUtils.cpp), so the framework has to land at exactly that path
# for the embedded interpreter to find its standard library.
#
# Usage:
#   deploy-bundle.sh <path/to/Natron.app> --pyside-prefix <dir> [options]

set -euo pipefail

APP=""
PYSIDE_PREFIX=""
PY_VERSION="3.11"
QT_PREFIX="$(brew --prefix qt 2>/dev/null || echo /usr/local/opt/qt)"
PY_PREFIX=""
OCIO_CONFIGS=""

usage() {
    cat <<EOF
usage: $(basename "$0") <Natron.app> --pyside-prefix <dir> [--python-version X.Y]
                        [--python-prefix <dir>] [--qt-prefix <dir>]

  <Natron.app>          the bundle to make self-contained (modified in place)
  --pyside-prefix DIR   PySide6/shiboken6 install prefix (contains lib/pythonX.Y/site-packages)
  --python-version X.Y  Python version to bundle (default: $PY_VERSION)
  --python-prefix DIR   Python prefix (default: brew --prefix python@X.Y)
  --qt-prefix DIR       Qt prefix (default: brew --prefix qt)
  --ocio-configs DIR    OpenColorIO-Configs to bundle into Contents/Resources.
                        Without these the OCIO plug-ins have no config to load;
                        openfx-io's GenericOCIO then dereferences a null config
                        and the host crashes when a Write node is created.
                        Get them with:
                          curl -kL https://github.com/NatronGitHub/OpenColorIO-Configs/archive/Natron-v2.4.tar.gz | tar zxf -
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --pyside-prefix)  PYSIDE_PREFIX="$2"; shift 2 ;;
        --python-version) PY_VERSION="$2"; shift 2 ;;
        --python-prefix)  PY_PREFIX="$2"; shift 2 ;;
        --qt-prefix)      QT_PREFIX="$2"; shift 2 ;;
        --ocio-configs)   OCIO_CONFIGS="$2"; shift 2 ;;
        -h|--help)        usage; exit 0 ;;
        -*)               echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)                APP="$1"; shift ;;
    esac
done

if [ -z "$APP" ] || [ -z "$PYSIDE_PREFIX" ]; then
    usage >&2
    exit 1
fi
if [ ! -d "$APP/Contents/MacOS" ]; then
    echo "error: $APP is not an application bundle" >&2
    exit 1
fi

if [ -z "$PY_PREFIX" ]; then
    PY_PREFIX="$(brew --prefix "python@$PY_VERSION" 2>/dev/null || echo "/usr/local/opt/python@$PY_VERSION")"
fi

FRAMEWORKS="$APP/Contents/Frameworks"
PY_FW_SRC="$PY_PREFIX/Frameworks/Python.framework"
PY_FW_DST="$FRAMEWORKS/Python.framework"
SITE_PACKAGES="$PY_FW_DST/Versions/$PY_VERSION/lib/python$PY_VERSION/site-packages"
BIN="$APP/Contents/MacOS/Natron"

for d in "$PY_FW_SRC" "$PYSIDE_PREFIX" "$QT_PREFIX"; do
    if [ ! -d "$d" ]; then
        echo "error: missing directory: $d" >&2
        exit 1
    fi
done

echo "==> bundling Python $PY_VERSION from $PY_PREFIX"
mkdir -p "$FRAMEWORKS"
rm -rf "$PY_FW_DST"
# -R (not -a) so the framework's symlinks are followed into a plain tree; a
# bundle that keeps them still points at the Homebrew Cellar.
mkdir -p "$PY_FW_DST/Versions/$PY_VERSION"
cp -R "$PY_FW_SRC/Versions/$PY_VERSION/" "$PY_FW_DST/Versions/$PY_VERSION/"
ln -sfn "$PY_VERSION" "$PY_FW_DST/Versions/Current"
ln -sfn "Versions/Current/Python" "$PY_FW_DST/Python"
ln -sfn "Versions/Current/Resources" "$PY_FW_DST/Resources"
chmod -R u+w "$PY_FW_DST"

# Homebrew points the framework's site-packages at a symlink that escapes the
# framework (../../../../../lib/python3.11/site-packages). Copied into a bundle
# it dangles, so replace it with a real directory. Any other symlink that
# resolves outside the bundle would break relocation the same way, so report it.
if [ -L "$SITE_PACKAGES" ]; then
    rm -f "$SITE_PACKAGES"
fi
mkdir -p "$SITE_PACKAGES"
while IFS= read -r link; do
    target="$(cd "$(dirname "$link")" && python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$(basename "$link")" 2>/dev/null || true)"
    case "$target" in
        "$(cd "$APP" && pwd -P)"*) ;;
        "") ;;
        *) echo "warning: symlink escapes the bundle: ${link#$APP/} -> $target" ;;
    esac
done < <(find "$PY_FW_DST" -type l)

# The framework's own id is absolute; make it bundle-relative so anything
# linking it resolves inside the app.
PY_DYLIB="$PY_FW_DST/Versions/$PY_VERSION/Python"
install_name_tool -id "@rpath/Python.framework/Versions/$PY_VERSION/Python" "$PY_DYLIB" 2>/dev/null || true

echo "==> installing PySide6/shiboken6 into the bundle"
PYSIDE_SP="$PYSIDE_PREFIX/lib/python$PY_VERSION/site-packages"
if [ ! -d "$PYSIDE_SP" ]; then
    echo "error: no site-packages under $PYSIDE_PREFIX" >&2
    exit 1
fi
mkdir -p "$SITE_PACKAGES"
cp -R "$PYSIDE_SP/PySide6" "$SITE_PACKAGES/"
cp -R "$PYSIDE_SP/shiboken6" "$SITE_PACKAGES/"
# The extension modules load libpyside6/libshiboken6 through @rpath and expect
# them beside the package, the way the official wheels are laid out.
cp -a "$PYSIDE_PREFIX"/lib/libpyside6*.dylib "$SITE_PACKAGES/PySide6/" 2>/dev/null || true
cp -a "$PYSIDE_PREFIX"/lib/libshiboken6*.dylib "$SITE_PACKAGES/shiboken6/" 2>/dev/null || true

echo "==> installing qtpy"
# Natron's GUI scripting layer imports qtpy, and it disables site-packages
# outside the bundle, so it has to be vendored here.
"$PY_PREFIX/bin/python$PY_VERSION" -m pip install --quiet --upgrade \
    --target "$SITE_PACKAGES" qtpy 2>/dev/null \
    || echo "warning: could not install qtpy (GUI Python scripting will be limited)"

if [ -n "$OCIO_CONFIGS" ]; then
    if [ ! -d "$OCIO_CONFIGS" ]; then
        echo "error: no such OpenColorIO-Configs directory: $OCIO_CONFIGS" >&2
        exit 1
    fi
    # Settings::getDefaultOcioConfigPaths() looks beside the executable, at
    # <binary>/../Resources/OpenColorIO-Configs, on macOS.
    echo "==> bundling OpenColorIO configs"
    rm -rf "$APP/Contents/Resources/OpenColorIO-Configs"
    mkdir -p "$APP/Contents/Resources"
    cp -R "$OCIO_CONFIGS" "$APP/Contents/Resources/OpenColorIO-Configs"
fi

echo "==> running macdeployqt"
"$QT_PREFIX/bin/macdeployqt" "$APP" -always-overwrite || true

echo "==> rewriting load commands"
# Drop rpaths that point into the build tree, and add the bundle-relative one.
while read -r rp; do
    case "$rp" in
        @*) ;;
        *) install_name_tool -delete_rpath "$rp" "$BIN" 2>/dev/null || true ;;
    esac
done < <(otool -l "$BIN" | awk '/LC_RPATH/{f=1} f&&/path /{print $2; f=0}')

install_name_tool -add_rpath "@executable_path/../Frameworks" "$BIN" 2>/dev/null || true

# Point the executable at the bundled Python framework.
PY_REF="$(otool -L "$BIN" | awk '/Python\.framework/{print $1; exit}')"
if [ -n "$PY_REF" ]; then
    install_name_tool -change "$PY_REF" \
        "@rpath/Python.framework/Versions/$PY_VERSION/Python" "$BIN"
fi

# Re-sign: every load-command edit invalidates the existing signature, and
# macOS refuses to load libraries into a binary whose signature does not match.
echo "==> re-signing"
codesign --force --deep --sign - "$APP" 2>/dev/null || \
    echo "warning: could not re-sign the bundle"

echo "==> done: $APP"
