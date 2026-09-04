#!/bin/bash
# ***** BEGIN LICENSE BLOCK *****
# This file is part of Natron <http://www.natron.fr/>,
# Copyright (C) 2013-2018 INRIA and Alexandre Gauthier
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

set -e # Exit immediately if a command exits with a non-zero status
set -u # Treat unset variables as an error when substituting.
#set -x # Print commands and their arguments as they are executed.

# DISABLE_BREAKPAD=1: Disable automatic crash report

source common.sh
source manageBuildOptions.sh
source manageLog.sh
updateBuildOptions

NO_BUILD=0
# If Natron is already built, exit when debugging scripts
if [ "${DEBUG_SCRIPTS:-}" = "1" ]; then
    if [ -f "$TMP_BINARIES_PATH/bin/Natron" ] || [ -f "$TMP_BINARIES_PATH/Natron.app/Contents/MacOS/Natron" ]; then
        NO_BUILD=1
    fi
fi


# Setup env
if [ "$PKGOS" = "Linux" ]; then
    #export PYTHONHOME="$SDK_HOME"
    export LD_LIBRARY_PATH="$SDK_HOME/lib:$SDK_HOME/qt${QT_VERSION_MAJOR}/lib"
    export PATH="$SDK_HOME/gcc/bin:$SDK_HOME/bin:$SDK_HOME/qt${QT_VERSION_MAJOR}/bin:$HOME/.cabal/bin:$PATH"
    if [ "$ARCH" = "x86_64" ]; then
        export LD_LIBRARY_PATH="$SDK_HOME/gcc/lib64:$LD_LIBRARY_PATH"
    else
        export LD_LIBRARY_PATH="$SDK_HOME/gcc/lib:$LD_LIBRARY_PATH"
    fi
    export C_INCLUDE_PATH="${SDK_HOME}/gcc/include:${SDK_HOME}/include:${SDK_HOME}/qt${QT_VERSION_MAJOR}/include"
    export CPLUS_INCLUDE_PATH="${C_INCLUDE_PATH}"
fi

cd "$TMP_PATH"

# OpenColorIO-Configs setup
OCIO_CONFIGS_VERSION=${OCIO_CONFIGS_VERSION:-}
if [ "$NATRON_BUILD_CONFIG" = "ALPHA" ] || [ "$NATRON_BUILD_CONFIG" = "BETA" ] || [ "$NATRON_BUILD_CONFIG" = "RC" ] || [ "$NATRON_BUILD_CONFIG" = "STABLE" ]; then
    OCIO_CONFIGS_VERSION=$(echo $NATRON_GIT_BRANCH | sed 's#tags/v##;' | cut -c1-3)
elif [ "$OCIO_CONFIGS_VERSION" = "" ]; then
    case "$NATRON_GIT_BRANCH" in
        *RB-*)
            OCIO_CONFIGS_VERSION=$(echo $NATRON_GIT_BRANCH | sed 's#.*RB-##;')
            ;;
    esac
fi

if [ "$OCIO_CONFIGS_VERSION" = "" ]; then
    OCIO_CONFIGS_VERSION="3.0"
    echo "Warning: No OCIO config version found, setting to $OCIO_CONFIGS_VERSION"
fi

OCIO_CONFIGS_URL=https://github.com/NatronGitHub/OpenColorIO-Configs/archive/Natron-v${OCIO_CONFIGS_VERSION}.tar.gz

OCIO_CONFIGS_DIR="$SRC_PATH/OpenColorIO-Configs-Natron-v${OCIO_CONFIGS_VERSION}"
if [ ! -d "$OCIO_CONFIGS_DIR" ]; then
    mkdir -p "$SRC_PATH" || true
    $CURL "$OCIO_CONFIGS_URL" --output "$SRC_PATH/OpenColorIO-Configs-Natron-v${OCIO_CONFIGS_VERSION}.tar.gz"
    tar xf "$SRC_PATH/OpenColorIO-Configs-Natron-v${OCIO_CONFIGS_VERSION}.tar.gz" -C "$SRC_PATH"/
    rm -rf "$OCIO_CONFIGS_DIR/aces_1.0.1/baked" || true
    rm -rf "$OCIO_CONFIGS_DIR/aces_1.0.1/python" || true
fi

cd Natron

# color
if [ ! -d "OpenColorIO-Configs" ]; then
    ln -sf "$OCIO_CONFIGS_DIR" OpenColorIO-Configs
fi


echo "===> Building Natron $NATRON_GIT_COMMIT from $NATRON_GIT_BRANCH using $MKJOBS threads."

if [ -n "$OPENFX_IO_GIT_COMMIT" ]; then
    IO_GIT_HASH="$OPENFX_IO_GIT_COMMIT"
else
    IO_GIT_HASH="$OPENFX_IO_GIT_BRANCH"
fi
if [ -n "$OPENFX_MISC_GIT_COMMIT" ]; then
    MISC_GIT_HASH="$OPENFX_MISC_GIT_COMMIT"
else
    MISC_GIT_HASH="$OPENFX_MISC_GIT_BRANCH"
fi
if [ -n "$OPENFX_ARENA_GIT_COMMIT" ]; then
    ARENA_GIT_HASH="$OPENFX_ARENA_GIT_COMMIT"
else
    ARENA_GIT_HASH="$OPENFX_ARENA_GIT_BRANCH"
fi
if [ -n "$OPENFX_GMIC_GIT_COMMIT" ]; then
    GMIC_GIT_HASH="$OPENFX_GMIC_GIT_COMMIT"
else
    GMIC_GIT_HASH="$OPENFX_GMIC_GIT_BRANCH"
fi


if [ "${IO_GIT_HASH:-}" = "" ] || [ "${MISC_GIT_HASH:-}" = "" ] || [ "${ARENA_GIT_HASH:-}" = "" ] || [ "${GMIC_GIT_HASH:-}" = "" ]; then
    echo "PLUGINS GIT COMMIT MISSING, did you call build-plugins.sh first?"
fi

#Update GitVersion to have the correct hash
$GSED "s#__BRANCH__#${NATRON_GIT_BRANCH}#;s#__COMMIT__#${NATRON_GIT_COMMIT}#;s#__IO_COMMIT__#${IO_GIT_HASH:-}#;s#__MISC_COMMIT__#${MISC_GIT_HASH:-}#;s#__ARENA_COMMIT__#${ARENA_GIT_HASH:-}#;s#__GMIC_COMMIT__#${GMIC_GIT_HASH:-}#" "$INC_PATH/natron/GitVersion.h" > Global/GitVersion.h

# CMake build.
#
# The shiboken/pyside bindings that this script used to pre-generate by hand are
# produced by the CMake build itself, so that step is gone. The per-platform
# config.pri files are gone too: CMake discovers Qt, Shiboken, PySide, Boost and
# expat with find_package, and the SDK is pointed at with CMAKE_PREFIX_PATH.

# CWD is the Natron source tree (see "cd Natron" above). The CMake build is
# always out-of-source, unlike the qmake build it replaces.
srcdir="."
BUILD_DIR="${TMP_PATH}/Natron/build"

CMAKE_FLAGS_EXTRA=()

# build type
case "$COMPILE_TYPE" in
    debug)          CMAKE_BUILD_TYPE=Debug ;;
    release)        CMAKE_BUILD_TYPE=Release ;;
    relwithdebinfo) CMAKE_BUILD_TYPE=RelWithDebInfo ;;
    *)              CMAKE_BUILD_TYPE=RelWithDebInfo ;;
esac

# Qt version
if [ "${QT_VERSION_MAJOR:-5}" = "6" ]; then
    CMAKE_FLAGS_EXTRA+=(-DNATRON_QT6=ON)
fi

# version / release status
case "$NATRON_BUILD_CONFIG" in
    SNAPSHOT)
        CMAKE_FLAGS_EXTRA+=(-DNATRON_DEV_STATUS=SNAPSHOT)
        ;;
    ALPHA|BETA|RC)
        if [ -z "${NATRON_BUILD_NUMBER:-}" ]; then
            echo "You must supply a NATRON_BUILD_NUMBER when NATRON_BUILD_CONFIG=$NATRON_BUILD_CONFIG"
            exit 1
        fi
        CMAKE_FLAGS_EXTRA+=(-DNATRON_DEV_STATUS="$NATRON_BUILD_CONFIG"
                            -DNATRON_BUILD_NUMBER="$NATRON_BUILD_NUMBER")
        ;;
    STABLE)
        CMAKE_FLAGS_EXTRA+=(-DNATRON_DEV_STATUS=STABLE)
        ;;
    CUSTOM)
        if [ -z "${NATRON_CUSTOM_BUILD_USER_NAME:-}" ]; then
            echo "You must supply a NATRON_CUSTOM_BUILD_USER_NAME when NATRON_BUILD_CONFIG=CUSTOM"
            exit 1
        fi
        CMAKE_FLAGS_EXTRA+=(-DNATRON_DEV_STATUS=CUSTOM
                            -DBUILD_USER_NAME="$NATRON_CUSTOM_BUILD_USER_NAME")
        ;;
esac

# use breakpad?
if [ "${DISABLE_BREAKPAD:-}" = "1" ]; then
    CMAKE_FLAGS_EXTRA+=(-DNATRON_BREAKPAD=OFF)
else
    CMAKE_FLAGS_EXTRA+=(-DNATRON_BREAKPAD=ON)
fi

if [ "$COMPILER" = "clang" ]; then
    CMAKE_FLAGS_EXTRA+=(-DNATRON_OPENMP=OFF)
else
    CMAKE_FLAGS_EXTRA+=(-DNATRON_OPENMP=ON)
fi

if [ "$COMPILE_TYPE" != "debug" ]; then
    # Let us benefit from maximum optimization for release builds,
    # including non-conformant IEEE floating-point computation.
    CMAKE_FLAGS_EXTRA+=(-DNATRON_NO_ASSERTIONS=ON)
fi

# mac deployment target
if [ "$PKGOS" = "OSX" ]; then
    CMAKE_FLAGS_EXTRA+=(-DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET")
fi

# Extra CMake flags passed from the command line.
if [ -n "${NATRON_EXTRA_CMAKE_FLAGS:-}" ]; then
    # shellcheck disable=SC2206
    CMAKE_FLAGS_EXTRA+=(${NATRON_EXTRA_CMAKE_FLAGS})
fi

# Dependencies resolved by the vcpkg manifest (eigen3, glog, gtest). Optional:
# when VCPKG_ROOT is unset the build falls back to whatever the SDK provides.
if [ -n "${VCPKG_ROOT:-}" ]; then
    CMAKE_FLAGS_EXTRA+=(-DCMAKE_TOOLCHAIN_FILE="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
                        -DVCPKG_MANIFEST_FEATURES=tests)
    if [ "$PKGOS" = "Windows" ]; then
        # Keep vcpkg on the MSYS2 toolchain rather than MSVC.
        CMAKE_FLAGS_EXTRA+=(-DVCPKG_TARGET_TRIPLET=x64-mingw-dynamic
                            -DVCPKG_HOST_TRIPLET=x64-mingw-dynamic)
    fi
fi

# Where the SDK's Qt, Python, Boost and expat live.
if [ -n "${SDK_HOME:-}" ]; then
    CMAKE_FLAGS_EXTRA+=(-DCMAKE_PREFIX_PATH="${QTDIR};${SDK_HOME}")
fi

# compiler-common.sh sets CC/CXX to a command *with flags* (e.g.
# "g++ -std=c++20"), which qmake accepted as QMAKE_CXX. CMAKE_CXX_COMPILER must
# name an executable and nothing else, so split the program from its flags and
# pass the remainder through CFLAGS/CXXFLAGS.
CC_BIN="${CC%% *}";   CC_ARGS="${CC#"$CC_BIN"}"
CXX_BIN="${CXX%% *}"; CXX_ARGS="${CXX#"$CXX_BIN"}"

# build
if [ "$NO_BUILD" != "1" ]; then
    printStatusMessage "Building Natron..."
    rm -rf "$BUILD_DIR" || true
    mkdir -p "$BUILD_DIR"

    env CFLAGS="${BF:-} ${CC_ARGS}" CXXFLAGS="${BF:-} ${CXX_ARGS}" cmake -S "$srcdir" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
        -DCMAKE_C_COMPILER="$CC_BIN" \
        -DCMAKE_CXX_COMPILER="$CXX_BIN" \
        -DNATRON_BUILD_TESTS=ON \
        "${CMAKE_FLAGS_EXTRA[@]}"

    cmake --build "$BUILD_DIR" --parallel "${MKJOBS}"
fi

if [ ! -d "$TMP_BINARIES_PATH/bin" ]; then
    mkdir -p "$TMP_BINARIES_PATH/bin"
fi



# install app(s)
if [ "$NO_BUILD" != "1" ]; then
    rm -rf "$TMP_BINARIES_PATH"/Natron* || true
    rm -f "$TMP_BINARIES_PATH"/bin/Natron* "$TMP_BINARIES_PATH/bin/Tests" || true
fi

NATRON_CONVERTER="NatronProjectConverter"
NATRON_TEST="Tests"
NATRON_BIN="Natron"
NATRON_PYTHON_BIN="natron-python"
RENDERER_BIN="NatronRenderer"
CRASHGUI="NatronCrashReporter"
CRASHCLI="NatronRendererCrashReporter"
if [ "$PKGOS" = "Windows" ]; then
    # The CMake/Ninja build is single-config, so binaries sit directly in their
    # target directory rather than under a release/ or debug/ subdirectory.
    NATRON_CONVERTER="${NATRON_CONVERTER}.exe"
    NATRON_PYTHON_BIN="${NATRON_PYTHON_BIN}.exe"
    NATRON_TEST="${NATRON_TEST}.exe"
    NATRON_BIN="${NATRON_BIN}.exe"
    RENDERER_BIN="${RENDERER_BIN}.exe"
    CRASHGUI="${CRASHGUI}.exe"
    CRASHCLI="${CRASHCLI}.exe"
fi


if [ "$PKGOS" = "OSX" ]; then
    MAC_APP_PATH=/Natron.app/Contents/MacOS
    MAC_INFOPLIST=/Natron.app/Contents/Info.plist
    MAC_PKGINFO=/Natron.app/Contents/PkgInfo
    MAC_CRASH_PATH=/NatronCrashReporter.app/Contents/MacOS
fi

CP_OR_MV=cp
if [ "${MINIMIZE_DISK_USAGE:-}" = "1" ]; then
    echo "Cleaning up files to minimize disk usage..."

    # Free up some disk space before copying.
    DIRS_TO_CLEAN="Engine Gui Tests libs/openMVG libs/ceres libs/libmv"

    for dir in ${DIRS_TO_CLEAN}; do
        if [ -d "${BUILD_DIR}/${dir}" ]; then
            find "${BUILD_DIR}/${dir}" -type f \( -name '*.o' -o -name '*.a' \) -delete
        fi
    done

    # Move large files instead of copying them to minimize disk usage.
    CP_OR_MV=mv
fi


cp "$BUILD_DIR"/Tests/$NATRON_TEST "$TMP_BINARIES_PATH/bin/"
TEST_BINARY_TO_RUN="$TMP_BINARIES_PATH/bin/Tests"
if [ "$PKGOS" = "Windows" ]; then
    TEST_BINARY_TO_RUN="${TEST_BINARY_TO_RUN}.exe"
fi

${CP_OR_MV} "$BUILD_DIR"/App${MAC_APP_PATH:-}/$NATRON_BIN "$TMP_BINARIES_PATH/bin/"

# copy Info.plist and PkgInfo
if [ "$PKGOS" = "OSX" ]; then
    ls -lR "$BUILD_DIR"/App/Natron.app
    # Note: Info.plist generation only works if compiling in the sources,
    # NOT in a "build" subdir (at least in qt4).
    cp "$BUILD_DIR/App${MAC_INFOPLIST}" "$TMP_BINARIES_PATH/bin/"
    cp "$BUILD_DIR/App${MAC_PKGINFO}" "$TMP_BINARIES_PATH/bin/"
fi

${CP_OR_MV} "$BUILD_DIR"/Renderer/$RENDERER_BIN "$TMP_BINARIES_PATH/bin/"

if [ -f "$BUILD_DIR"/ProjectConverter/$NATRON_CONVERTER ]; then
    cp "$BUILD_DIR"/ProjectConverter/$NATRON_CONVERTER "${TMP_BINARIES_PATH}/bin/"
fi

if [ -f "$BUILD_DIR"/PythonBin/$NATRON_PYTHON_BIN ]; then
    ${CP_OR_MV} "$BUILD_DIR"/PythonBin/$NATRON_PYTHON_BIN "${TMP_BINARIES_PATH}/bin/"
fi

mkdir -p "$TMP_BINARIES_PATH/docs/natron" || true
cp "$srcdir"/LICENSE.txt "$TMP_BINARIES_PATH/docs/natron/"

# install crashapp(s)
if [ "${DISABLE_BREAKPAD:-}" != "1" ]; then
    ${CP_OR_MV} "$BUILD_DIR"/CrashReporter${MAC_CRASH_PATH:-}/$CRASHGUI "$TMP_BINARIES_PATH/bin/"
    ${CP_OR_MV} "$BUILD_DIR"/CrashReporterCLI/$CRASHCLI "$TMP_BINARIES_PATH/bin/"
fi

RES_DIR="$TMP_BINARIES_PATH/Resources"
if [ ! -d "$RES_DIR" ]; then
    mkdir -p "$RES_DIR"
fi

# copy everything else we need
rm -rf "$RES_DIR/OpenColorIO-Configs" || true
mkdir -p "$RES_DIR/OpenColorIO-Configs"

OCIO_CONFIGS=()
if [ "$OCIO_CONFIGS_VERSION" = "2.0" ]; then
    OCIO_CONFIGS+=(blender nuke-default)
else
    OCIO_CONFIGS+=(blender natron nuke-default)
fi

echo "*** Copying OpenColorIO profiles from $OCIO_CONFIGS_DIR to $RES_DIR/OpenColorIO-Configs (profiles: ${OCIO_CONFIGS[*]})"
for profile in "${OCIO_CONFIGS[@]}"; do
    if [ -d "$OCIO_CONFIGS_DIR/${profile}" ]; then
        cp -a "$OCIO_CONFIGS_DIR/${profile}" "$RES_DIR/OpenColorIO-Configs/"
    else
        echo "Error: $profile not found!"
        exit 1
    fi
done
echo "*** $RES_DIR/OpenColorIO-Configs now contains:"
ls "$RES_DIR/OpenColorIO-Configs"

mkdir -p "$RES_DIR/stylesheets"
cp "$srcdir"/Gui/Resources/Stylesheets/mainstyle.qss "$TMP_BINARIES_PATH/Resources/stylesheets/"

if [ "$PKGOS" != "OSX" ]; then
    mkdir -p "$RES_DIR/pixmaps" || true
fi

if [ "$PKGOS" = "Linux" ]; then
    cp "$srcdir"/Gui/Resources/Images/natronIcon256_linux.png "$RES_DIR/pixmaps/"
    cp "$srcdir"/Gui/Resources/Images/natronProjectIcon_linux.png "$RES_DIR/pixmaps/"
elif [ "$PKGOS" = "Windows" ]; then
    cp "$srcdir"/Gui/Resources/Images/natronProjectIcon_windows.ico "$RES_DIR/pixmaps/"
elif [ "$PKGOS" = "OSX" ]; then
    cp "$srcdir"/Gui/Resources/Images/*.icns "$RES_DIR/"
    cp "$srcdir"/Gui/Resources/Images/splashscreen.* "$TMP_BINARIES_PATH/"
    #cp -a App/Natron.app/Contents/Resources/etc "$RES_DIR/"
    # quickfix
    cp -a "$srcdir"/Gui/Resources/etc "$RES_DIR/"
fi

rm -rf "$TMP_BINARIES_PATH/PyPlugs" || true
mkdir -p "$TMP_BINARIES_PATH/PyPlugs"
cp "$srcdir"/Gui/Resources/PyPlugs/* "$TMP_BINARIES_PATH/PyPlugs/"
if [ "$PKGOS" = "Linux" ] || [ "$PKGOS" = "Windows" ]; then
    mkdir -p "$RES_DIR/etc/fonts/conf.d"
    cp "$srcdir"/Gui/Resources/etc/fonts/fonts.conf "$RES_DIR/etc/fonts/"
    #cp "$srcdir"/Gui/Resources/share/fontconfig/conf.avail/* "$RES_DIR/etc/fonts/conf.d/"
    cp "$srcdir"/Gui/Resources/etc/fonts/conf.d/* "$RES_DIR/etc/fonts/conf.d/"
fi

set -x
# set OCIO for Tests
export OCIO="$OCIO_CONFIGS_DIR/nuke-default/config.ocio"
export NATRON_PLUGIN_PATH="$TMP_BINARIES_PATH/PyPlugs"
export OFX_PLUGIN_PATH="$TMP_BINARIES_PATH/OFX/Plugins"
env
if [ "$PKGOS" = "Linux" ]; then
    export FONTCONFIG_FILE="$RES_DIR"/etc/fonts/fonts.conf
elif [ "$PKGOS" = "OSX" ]; then
    export FONTCONFIG_FILE="$RES_DIR"/etc/fonts/fonts.conf
fi
if [ "$PKGOS" = "Linux" ]; then
    rm -rf "$HOME/.cache/INRIA/Natron"* &> /dev/null || true
    ln -sf "$SDK_HOME"/lib .
    # Note: Several suppression files can be passed to valgrind.
    # There is an automatic tool to generate libc/libstdc++/Qt
    # suppressions at https://github.com/AlekSi/valgrind-suppressions
    env LD_LIBRARY_PATH="$SDK_HOME/gcc/lib:$SDK_HOME/gcc/lib64:$SDK_HOME/lib:$FFMPEG_PATH/lib:$LIBRAW_PATH/lib:$QTDIR/lib" $TIMEOUT -s KILL 1800 valgrind --tool=memcheck --suppressions="$INC_PATH/natron/valgrind-python${PYV}.supp" ${TEST_BINARY_TO_RUN}
    rm -f lib || true
    # ITS NOT POSSIBLE TO RUN THE WIN TESTS HERE, DO IT IN THE INSTALLER SCRIPT
elif [ "$PKGOS" = "Windows" ]; then
    mkdir tmpdll
    pushd tmpdll
    cp "$OFX_PLUGIN_PATH"/*.ofx.bundle/Contents/*/*.ofx .
    for f in *.ofx; do
        dll="${f%\.ofx}.dll"
        mv "$f" "$dll"
        echo "Dependencies for $f:"
        env PATH="$FFMPEG_PATH/bin:$LIBRAW_PATH/bin:$QTDIR/bin:$SDK_HOME/osmesa/lib:$SDK_HOME/bin:${PATH:-}" ldd "$dll"
    done
    popd
    rm -rf tmpdll
    #rm -rf /c/Users/NatronWin/AppData/Local/INRIA/Natron &> /dev/null || true
    rm -rf "$LOCALAPPDATA\\INRIA\\Natron"* &> /dev/null || true
    testfail=0
    env PYTHONHOME="$SDK_HOME" PATH="$FFMPEG_PATH/bin:$LIBRAW_PATH/bin:$QTDIR/bin:$SDK_HOME/osmesa/lib:$SDK_HOME/bin:${PATH:-}" $TIMEOUT -s KILL 1800 "${TEST_BINARY_TO_RUN}" || testfail=1
    if [ $testfail != 0 ]; then
        echo "*** WARNING: Natron tests FAILED"
    fi
    # sometimes Tests.exe just hangs. Try taskkill first, then tskill if it fails because of a message like:
    # $ taskkill -f -im Tests.exe -t
    # ERROR: The process with PID 3260 (child process of PID 3816) could not be terminated.
    # Reason: There is no running instance of the task.
    # mapfile use: see https://github.com/koalaman/shellcheck/wiki/SC2207
    mapfile -t processes < <(taskkill -f -im Tests.exe -t 2>&1 |grep "ERROR: The process with PID"| awk '{print $6}' || true)
    for p in "${processes[@]}"; do
        tskill "$p" || true
    done

elif [ "$PKGOS" = "OSX" ]; then
    rm -rf  "$HOME/Library/Caches/INRIA/Natron"* &> /dev/null || true
    # setting DYLD_LIBRARY_PATH breaks many things. We get this error on 10.9 Mavericks, because /opt/local/lib/libiconv.2.dylib and /usr/lib/libiconv.2.dylib do not contain the same symbols
    #dyld: Symbol not found: _iconv
    #  Referenced from: /usr/lib/libcups.2.dylib
    #  Expected in: /opt/local/lib/libiconv.2.dylib
    # in /usr/lib/libcups.2.dylib
    #Trace/BPT trap: 5
    # However, The universal build on OS X 10.6 requires this
    if [ "$MACOSX_DEPLOYMENT_TARGET" = "10.6" ]; then
        if [ "$COMPILER" = "gcc" ]; then
            env DYLD_LIBRARY_PATH="$SDK_HOME"/lib/libgcc:/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ImageIO.framework/Versions/A/Resources:"$SDK_HOME"/lib $TIMEOUT -s KILL 1800 ${TEST_BINARY_TO_RUN}
        else
            # be more tolerant to test fails on 10.6
            $TIMEOUT -s KILL 1800 ${TEST_BINARY_TO_RUN} || true
        fi
    else
        # Tests exit with a segfault on Qt5
        $TIMEOUT -s KILL 1800 ${TEST_BINARY_TO_RUN} || [ "$QT_VERSION_MAJOR" = 5 ]
    fi
fi
set +x

# Local variables:
# mode: shell-script
# sh-basic-offset: 4
# sh-indent-comment: t
# indent-tabs-mode: nil
# End:
