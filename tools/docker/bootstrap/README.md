# Bootstrap build container

A pinned Linux environment that builds Natron 2.6 from a clean checkout, used to
establish a known-green baseline before build-system changes land.

## Why a container

The Qt5 binding toolchain cannot be installed from PyPI:

- `shiboken6_generator` is not on PyPI at any version — Qt publishes it only
  through their own index.
- The PySide wheels ship runtime modules only: no CMake config files, no
  headers, no generator binary. `find_package(Shiboken2 CONFIG)` cannot succeed
  against them.

So the toolchain has to come from a distribution package (or MacPorts/Homebrew).
Ubuntu 22.04 is pinned here as a known-good baseline, matching what CI used
before the CMake migration. 24.04 carries the same packages
(`libshiboken2-dev`, `libpyside2-dev`, `qtbase5-dev` 5.15.13) and should also
work; it simply has not been exercised.

## Usage

    docker build -t natron-boot:22.04 tools/docker/bootstrap

    docker volume create natron-build
    docker run --rm \
      -v "$PWD":/src:ro \
      -v natron-build:/build \
      -w /build natron-boot:22.04 \
      bash -c 'cmake -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo /src && ninja -j2'

The source tree is mounted read-only and all output goes to the `natron-build`
volume, so the container cannot touch your working tree.

## Parallelism

Use `-j2` unless the Docker VM has substantially more than 8 GB. Several `Gui`
translation units need well over 1 GB each in `cc1plus`; at `-j$(nproc)` on an
8 GB VM the OOM killer terminates the compiler mid-file.

Requires submodules: `git submodule update --init --recursive`.
