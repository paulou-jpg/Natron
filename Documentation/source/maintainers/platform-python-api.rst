.. _maint-platform-python-api:

Specification: the Python API
=============================

.. note::

   **Status: draft for review.** This is one of the two contracts every piece of
   pipeline tooling will be written against (the other is
   :ref:`maint-platform-project-format`). It is deliberately written *before*
   the tooling exists, because once pipeline code sits on top of these surfaces
   every change to them costs a migration.

Why this document exists
------------------------

Natron already has a Python API. The question this specification answers is not
"what should we expose" — the existing surface is a reasonable answer to that —
but "what should the *shape* of the surface be, now that there is no legacy
script corpus forcing us to reproduce the current one".

Adopting the codebase from scratch removes the compatibility constraint that
would normally make this a migration. It is a design exercise instead, and this
is the one moment the surface can be shaped freely.

The surface as it exists today
------------------------------

Measured from the type system descriptions on branch ``RB-2.6``:

.. list-table::
   :header-rows: 1
   :widths: 30 20 50

   * - Module
     - Size
     - Contents
   * - ``NatronEngine``
     - 47 types, 15 enums
     - The platform surface: ``App``, ``Effect``, the ``Param`` hierarchy,
       ``Group``, ``Roto``, ``Tracker``, ``ImageLayer``, ``RectI``/``RectD``
   * - ``NatronGui``
     - 6 types
     - ``GuiApp``, ``PyViewer``, ``PyGuiApplication``, ``PyModalDialog``,
       ``PyPanel``, ``PyTabWidget``

The single most important measurement for the binding work:

.. important::

   **Exactly one Qt type is exposed across the engine's entire Python API:**
   ``QString``. Everything else is C++ primitives, standard containers and
   Natron's own types.

That is why replacing Shiboken2/PySide2 with hand-written nanobind bindings is a
contained job rather than an open-ended one. The engine API does not leak the
toolkit; only ``NatronGui`` genuinely depends on Qt, and that module belongs to
the desktop client rather than to the platform.

Design principles
-----------------

**1. The module is importable from a stock interpreter.**
``import natron`` must work in any CPython the bindings were built for, with no
Natron process running and no application object instantiated. This is the
single hardest requirement in this document, and it is what the rest of the
platform work exists to make possible: today the API is reachable only from
inside a running application because of the ``appPTR`` singleton.

**2. Contexts are explicit; there is no ambient application.**
The current API is rooted in a process-wide singleton, so there is exactly one
engine per process and the Python surface has no way to express otherwise. The
new surface takes an engine context explicitly::

    import natron

    engine = natron.Engine()            # no singleton, no GUI, no QApplication
    project = engine.open("shot.ntp")

Two independent engines in one interpreter must be a supported, tested
configuration, not an accident that happens to work.

**3. No toolkit types cross the boundary.**
``QString`` becomes ``str``. No Qt type appears in any signature. This is what
keeps the module importable without a GUI stack installed.

**4. Errors are exceptions, not status enums.**
``StatusEnum`` returns are a C++ convention. Python callers should get
exceptions carrying context, with a small typed hierarchy rooted at
``natron.Error``.

**5. The object model mirrors the node graph, not the C++ class tree.**
Callers think in projects, nodes, parameters, keyframes and layers. Where the
C++ inheritance chain and the user's mental model disagree, the API follows the
user.

**6. Naming follows Python, not C++.**
``snake_case`` methods and properties, ``CapWords`` types. Parameter access
reads as attribute access where that is unambiguous.

Proposed module layout
----------------------

A single top-level package with submodules, so that the GUI surface is
importable *only* when a client provides it::

    natron               # engine context, project I/O, errors
    natron.graph         # nodes, groups, connections
    natron.params        # the parameter hierarchy, animation curves
    natron.image         # layers, components, bit depths, rectangles
    natron.roto          # bezier/stroke items
    natron.track         # tracker items
    natron.gui           # provided by the desktop client ONLY

``natron.gui`` raising ``ImportError`` in a headless interpreter is correct
behaviour, not a defect.

What this replaces, concretely
------------------------------

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Today
     - Specified
   * - Shiboken2 + PySide2, generated from XML by a tool no longer published
     - Hand-written nanobind bindings, reviewable as ordinary source
   * - ``appPTR`` singleton reachable from 127 files
     - An explicit ``natron.Engine`` context
   * - ``QString`` in the API
     - ``str``
   * - ``StatusEnum`` return codes
     - Exceptions under ``natron.Error``
   * - Importable only inside a running Natron
     - ``import natron`` from a stock interpreter

Dependency on the rest of the plan
----------------------------------

This specification can be *written* now, and the binding technology can be
swapped now, but principle 2 cannot be *delivered* until the singleton is gone
(:ref:`maint-todo` step 03) and principle 1 cannot be fully delivered until the
render context is explicit (step 04). Sequencing the specification first is
deliberate: it tells those two refactors what shape they have to arrive at.

Decision: image data access
---------------------------

**Graph and parameters, plus one narrow read-only escape hatch: render a frame
and expose the resulting plane through the buffer protocol.** Nothing more in
v1.

Every comparable application draws this line in the same place. Nuke's ``nuke``
module is a graph-and-knobs API; the only per-pixel access is
``Node.sample(channel, x, y)``, one pixel per call through the render pipeline,
which is fine for picking a colour and unusable for processing an image. Real
pixel work goes to BlinkScript, to a C++ NDK plug-in where ``Iop::engine()``
hands over row buffers, or out of process entirely via OpenImageIO. Fusion
(Fuses/OpenCL) and After Effects (the C++ SDK) split it the same way. Blender's
``image.pixels`` is the exception that proves the rule, and is notoriously slow.

Natron is not in the same position, though, which is why this is not a straight
copy: those are *applications*, and this plan makes Natron a *library*. A farm
process doing ``import natron`` and pulling a rendered plane into NumPy is a
legitimate use that Nuke structurally cannot serve. That is what the escape
hatch is for.

The asymmetry decides the scope. Deferring the API is cheap; retracting a
published pixel API is not. A full in-Python image-processing surface would have
to stay fast forever, and would pull decisions about tiling, bit depth, colour
management and threading into the binding layer long before the render context
work (:ref:`maint-todo` step 04) has settled them.

So: no in-place pixel writes, no per-pixel accessors, no image arithmetic in the
API. If callers need those, the answer is an OpenFX plug-in or a C++ client
against the core, which is what the platform seam exists to make possible.

Open questions
--------------

These need a decision before the surface is frozen; none of them block starting.

- **Threading and reentrancy.** Is a single ``Engine`` safe to drive from
  several Python threads, or is it single-owner with explicit handoff? The
  answer shapes the render context work.
- **Render invocation.** The decision above settles that a rendered plane is
  reachable from Python; it does not settle how the render is asked for. Is it
  synchronous and blocking, or does it return a handle that can be waited on and
  cancelled? Farm use wants cancellation; the simplest binding does not have it.
- **Expressions.** Node parameter expressions are evaluated in an embedded
  interpreter today. Does the new engine keep an embedded interpreter, or are
  expressions a callback into the host interpreter?
- **Undo/redo.** Is it part of the platform surface, or purely a client concern?

