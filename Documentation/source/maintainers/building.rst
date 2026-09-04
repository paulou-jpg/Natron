.. _maint-building:

Building Natron from Source
===========================

Natron builds with **CMake**. The entry point is ``CMakeLists.txt`` at the
repository root, with one ``CMakeLists.txt`` per module, and ``CMakePresets.json``
provides ready-made ``debug``, ``release`` and ``release-qt6`` configurations.
CMake ≥ 3.16 is required (≥ 3.21 to use the presets).

Third-party dependencies are declared in ``vcpkg.json`` and resolved by
`vcpkg <https://vcpkg.io>`_ in manifest mode; set ``VCPKG_ROOT`` and configure
with a preset::

    cmake --preset release
    cmake --build --preset release

.. note::

   The qmake build has been removed. ``Project.pro``, ``global.pri``,
   ``libs.pri`` and the per-module ``*.pro`` files are gone, and
   ``tools/jenkins/build-natron.sh`` drives CMake directly. Maintaining two
   build systems in lockstep taxed every source change, and CMake was already
   the more capable of the two — it is the only one that can generate the
   Shiboken/PySide bindings.

.. note::

   **C++17 is required**: ``Global/Macros.h`` fails compilation with
   ``#error "Natron 2.6+ requires C++17"`` if the standard is older. Configure
   your toolchain accordingly.

.. note::

   If you touch the source layout — add a file, add a module, rename something —
   update the relevant ``CMakeLists.txt``. Most module targets glob their
   sources, but the bundled libraries and the crash reporter list theirs
   explicitly.

Platform-specific, step-by-step instructions (including how to obtain the
third-party dependencies) live at the repository root in ``INSTALL_LINUX.md``,
``INSTALL_MACOS.md``, ``INSTALL_WINDOWS.md`` and ``INSTALL_FREEBSD.md``. This
chapter explains the *structure* of the build so those instructions make sense.

Modules and their build order
-----------------------------

``libs/CMakeLists.txt`` and the per-module ``CMakeLists.txt`` files declare the
dependency graph::

    ceres.depends    = Eigen3::Eigen glog::glog   (Eigen and glog from vcpkg)
    libmv.depends    = ceres
    openMVG.depends  = ceres
    Engine.depends   = libmv openMVG HostSupport libtess ceres hoedown
    Renderer.depends = Engine
    Gui.depends      = Engine qhttpserver
    Tests.depends    = Engine GTest::gtest GTest::gmock
    App.depends      = Gui Engine

So the build order is: the remaining in-tree libraries first (``ceres``,
``libmv``, ``openMVG``, ``hoedown``, ``libtess``), then ``HostSupport``, then
``Engine``, then the front-ends (``Renderer``, ``Gui``), then ``App``,
``Tests`` and ``PythonBin``.

Third-party dependencies
------------------------

``vcpkg.json`` declares the dependencies resolved by the package manager:
``eigen3``, ``glog`` (and ``gflags`` beneath it), plus ``gtest`` under the
``tests`` feature. The manifest pins a vcpkg ``builtin-baseline`` so every
platform resolves identical versions, and pins Eigen to 3.4.0 — the bundled
copy was 3.3.7 and the current vcpkg default is 5.0.1, which Ceres 1.12
predates by a decade.

A smaller set is still **bundled** in ``libs/`` and built from source, each for
a specific reason:

``ceres``
    Pinned at 1.12. ``libs/libmv/libmv/simple_pipeline/modal_solver.cc`` uses
    ``ceres::LocalParameterization``, removed in Ceres 2.2.
``libmv``
    No upstream package exists.
``openMVG``
    v0.9 plus four patches in ``libs/openMVG/patches/``, two of which add
    Natron-authored PROSAC estimators that upstream does not carry.
``libtess``
    A Natron fork of the SGI GLU tessellator (polygon tessellation for roto).
``hoedown``
    Markdown → HTML for the node documentation. No vcpkg port exists.
``qhttpserver``
    The internal documentation web server behind ``Gui/DocumentationManager``.
    No vcpkg port exists.

``SequenceParsing`` (image sequence detection) and ``google-breakpad`` (crash
reporting) remain git submodules.

Other dependencies must be present on the system: **Qt** (5 or 6), **Boost**
(notably ``boost::serialization``), **Python 3** plus **Shiboken/PySide**,
**cairo** (roto/paint rasterization), **OpenColorIO**, and OpenGL. The reader
and writer plug-ins pull in **OpenImageIO** and **FFmpeg**, but those live in
the separate ``openfx-io`` repository, not here.

Qt 5 and Qt 6
-------------

The CMake build already exposes a Qt version switch::

    option(NATRON_QT6 "use Qt6" OFF)

- With ``-DNATRON_QT6=OFF`` (default) it builds against **Qt 5.15**,
  **Shiboken2** and **PySide2**.
- With ``-DNATRON_QT6=ON`` it builds against **Qt 6.3+**, **Shiboken6** and
  **PySide6**, and additionally requires the ``OpenGLWidgets`` component
  (``QOpenGLWidget`` moved into its own module in Qt 6).

Completing and stabilizing Qt 6 support is an active work item; see
:ref:`maint-qt6`.

Two compile definitions set in the CMake build are worth knowing about because
they affect how you must write code:

- ``QT_NO_CAST_FROM_ASCII`` — you cannot implicitly build a ``QString`` from a
  ``const char*``. Natron treats all strings as UTF-8, so wrap literals in
  ``QString::fromUtf8("…")`` (or the ``tr()`` machinery for translatable text).
- ``QT_NO_DEBUG_OUTPUT`` (release builds) — ``qDebug()`` output is compiled out
  of release builds.

Build type, sanitizers and debugging
------------------------------------

- CMake defaults to ``RelWithDebInfo`` when no build type is given; a ``Debug``
  build additionally defines ``DEBUG``.
- ``DEBUG`` builds enable **floating-point exception trapping** at startup (see
  ``Global/FloatingPointExceptions.h`` and the ``main()`` functions) so that a
  stray ``NaN`` or division by zero aborts immediately instead of silently
  propagating through the image pipeline.
- ``-DNATRON_BREAKPAD=ON`` builds the Breakpad crash reporter
  (``BreakpadClient``, ``NatronCrashReporter`` and
  ``NatronRendererCrashReporter``). It is off by default, and the bundled
  google-breakpad predates glibc 2.26's ``ucontext_t`` rename, so it does not
  compile on a modern Linux host.
- ``-DNATRON_NO_ASSERTIONS=ON`` disables assertions and Qt debug/warning output,
  and ``-DNATRON_OPENMP=ON`` enables OpenMP. Release builds made by
  ``tools/jenkins/build-natron.sh`` set both.
- ``-DNATRON_DEV_STATUS=`` (``SNAPSHOT``/``ALPHA``/``BETA``/``RC``/``STABLE``/
  ``CUSTOM``) together with ``-DNATRON_BUILD_NUMBER=`` and ``-DBUILD_USER_NAME=``
  tag a build the way the release pipeline expects.

Code style and the pre-commit hook
----------------------------------

Natron enforces a consistent C++ style with **astyle**. The exact invocation is
pinned in ``.git-hooks/pre-commit``::

    astyle -p -H -f -j -z2 -c -k3 -U -A8

The hook runs on every staged ``.c``/``.cpp``/``.h`` file under ``Global/``,
``Engine/``, ``Gui/``, ``Readers/`` and ``Writers/`` and **rejects the commit**
if the file is not already formatted. Install it once per clone::

    cd Natron
    mkdir -p .git/hooks
    ln -s ../../.git-hooks/pre-commit .git/hooks/pre-commit

If the hook complains, re-format and re-stage the offending file::

    astyle -p -H -f -j -z2 -c -k3 -U -A8 -n path/to/File.cpp
    git add path/to/File.cpp

A ``.clang-format`` file is also provided for editor integration, but astyle is
the authoritative formatter used by the hook.

Verifying a build
-----------------

The ``Tests`` module builds a Google Test / Google Mock suite
(``Curve_Test``, ``Lut_Test``, ``Image_Test``, ``Hash64_Test``,
``KnobFile_Test``, ``Tracker_Test``, ``FileSystemModel_Test``,
``OSGLContext_Test``). With CMake,
tests are registered with CTest (``enable_testing()``) and built unless you pass
``-DNATRON_BUILD_TESTS=OFF``. Run them after building to confirm your toolchain
and your change are sane before opening a pull request.
