# Bootstrap build container

A pinned Linux environment that builds Natron 2.6 from a clean checkout, used to
establish a known-green baseline before build-system changes land.

## Why a container

The Qt5 binding toolchain Natron currently depends on is no longer installable
on a modern machine:

- `shiboken6_generator` is not on PyPI at any version.
- The PySide6 wheels ship runtime modules only — no CMake config, no headers,
  no generator.
- Ubuntu 24.04 removed the Qt5 `libshiboken2-dev` / `libpyside2-dev` packages.

Ubuntu 22.04 is the last distro carrying them, so it is pinned here.

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
