Instructions for installing Natron from sources on FreeBSD
==========================================================

This file is supposed to guide you step by step to have working (compiling) version of
Natron on FreeBSD. 

## Install libraries

In order to have Natron compiling, first you need to install the required libraries.

```
pkg install qt5 boost-all pyside2 expat cairo pkgconf
```

### Submodules

Go under Natron and type

```
git submodule update -i --recursive
```

### Build

Natron builds with CMake. Dependency locations no longer need to be described by
hand: packages declared in `vcpkg.json` are resolved by
[vcpkg](https://vcpkg.io) in manifest mode, and Qt, Python, Shiboken/PySide,
Boost, expat and cairo are located by `find_package`.

```
export VCPKG_ROOT=/path/to/vcpkg
cmake -S <srcPath> -B <buildPath> -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
cmake --build <buildPath> --parallel 2
```

The build is always out-of-source, so `<buildPath>` must not be inside
`<srcPath>`.

For a debug build, use `-DCMAKE_BUILD_TYPE=Debug`. Other useful options are
`-DNATRON_QT6=ON`, `-DNATRON_BUILD_TESTS=OFF`, `-DNATRON_OPENMP=ON` and
`-DNATRON_NO_ASSERTIONS=ON`; see
`Documentation/source/maintainers/building.rst` for the full list. The crash
reporter (`-DNATRON_BREAKPAD=ON`) is off by default.

### Nodes

Natron's nodes are contained in separate repositories. To use the default nodes, you must also build the following repositories:

    https://github.com/NatronGitHub/openfx-misc
    https://github.com/NatronGitHub/openfx-io

You'll find installation instructions in the `README` of both these repositories. Both openfx-misc and openfx-io have submodules as well.

Plugins can be installed in `/usr/OFX/Plugins` on FreeBSD.
Or in a directory named "`Plugins`" located in the parent directory where the binary lies, e.g.:

```
bin/
    Natron
Plugins/
    IO.ofx.bundle
```
	
### OpenColorIO configs

Note that if you want Natron to find the OpenColorIO config files you will need to
place them in the appropriate location. In the repository they are located under
`Gui/Resources/OpenColorIO-Configs`.
You must copy them to a directory named `../share/OpenColorIO-Configs` relative to Natron's binary.
