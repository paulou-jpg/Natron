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

Open questions
--------------

These need a decision before the surface is frozen; none of them block starting.

- **Threading and reentrancy.** Is a single ``Engine`` safe to drive from
  several Python threads, or is it single-owner with explicit handoff? The
  answer shapes the render context work.
- **Rendering from Python.** Does the module expose frame rendering directly, or
  only graph manipulation with rendering delegated to the renderer binary?
- **Image data access.** Does Python get buffer-protocol access to image planes
  (NumPy interop), or is the surface graph-and-parameters only? This is the
  largest single scope question in the document.
- **Expressions.** Node parameter expressions are evaluated in an embedded
  interpreter today. Does the new engine keep an embedded interpreter, or are
  expressions a callback into the host interpreter?
- **Undo/redo.** Is it part of the platform surface, or purely a client concern?

