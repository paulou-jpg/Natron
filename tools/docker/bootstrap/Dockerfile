# Baseline bootstrap container for Natron.
#
# Ubuntu 22.04 is pinned as a known-good baseline, matching what CI used before
# the CMake migration. 24.04 also carries the Qt5 binding toolchain
# (libshiboken2-dev, libpyside2-dev, qtbase5-dev at 5.15.13), so moving forward
# is possible; it just has not been exercised.
#
# What genuinely is unavailable: the Shiboken generator is not published to PyPI
# at any version, and the PySide wheels ship runtime modules only -- no CMake
# config, no headers, no generator. So a distro or MacPorts/Homebrew package is
# required either way; pip cannot supply this toolchain.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake ninja-build pkg-config git ca-certificates \
      curl zip unzip tar \
      libboost-dev libboost-serialization-dev libboost-system-dev \
      libexpat1-dev libcairo2-dev \
      qt5-qmake qtbase5-dev qtdeclarative5-dev \
      python3-dev libshiboken2-dev libpyside2-dev \
      python3-pyside2.qtwidgets python3-qtpy \
      libwayland-dev libwayland-client0 libwayland-egl1 \
      libx11-dev libgl1-mesa-dev \
    `# the test suite needs a display; ctest is run under xvfb-run` \
      xvfb \
      extra-cmake-modules \
    `# shiboken2 parses headers through libclang; without the builtin include` \
    `# directory it fails to find limits.h and then segfaults.` \
      clang libclang-dev llvm-dev \
    && rm -rf /var/lib/apt/lists/*

# vcpkg supplies eigen3, glog and gtest (see vcpkg.json). Pinned to the same
# baseline the manifest declares so the container and CI resolve identically.
ARG VCPKG_BASELINE=7ff71c68261ecf3b60cdb8772f2e6759ee0a71b1
ENV VCPKG_ROOT=/opt/vcpkg
RUN git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT" \
    && git -C "$VCPKG_ROOT" checkout --detach "$VCPKG_BASELINE" \
    && "$VCPKG_ROOT"/bootstrap-vcpkg.sh -disableMetrics
ENV PATH="$VCPKG_ROOT:$PATH"

WORKDIR /src
