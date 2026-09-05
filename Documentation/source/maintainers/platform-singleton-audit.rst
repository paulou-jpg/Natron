.. _maint-platform-singleton-audit:

Audit: the ``appPTR`` singleton
===============================

.. note::

   **Status: measurement, not a proposal.** Numbers are counted from branch
   ``RB-2.6``. This exists to turn "127 files reach a process-wide singleton"
   into a work plan before anyone starts editing them.

Why the singleton matters
-------------------------

``appPTR`` expands to ``AppManager::instance()``. Because it is process-wide,
there is exactly one engine per process: you cannot open two projects in one
host, cannot embed the engine in a pipeline tool, and cannot test the engine
without standing up an application. None of that is a toolkit problem, and none
of it is fixed by replacing widgets.

The reach
---------

.. list-table::
   :header-rows: 1
   :widths: 20 20 20 40

   * - Module
     - Files
     - Uses
     - Note
   * - ``Gui``
     - 81
     - 485
     - **Two thirds of the reach is in the desktop client**
   * - ``Engine``
     - 46
     - 392
     - The part that blocks embedding
   * - ``App`` / ``Renderer`` / ``Global`` / ``HostSupport``
     - 0
     - 0
     - Already clean

.. important::

   The plan assigns de-singleton work to the core track, but **81 of the 127
   files are in Gui**, which is a different module and a different engineer.
   The two halves are separable and should be scheduled as separate streams,
   not as one 127-file sweep.

Gui does not use the same macro
-------------------------------

The two halves are not merely separate, they are different constructs.
``Gui/GuiApplicationManager.h`` undefines the engine's macro and replaces it
with a downcast::

    #if defined(appPTR)
    #undef appPTR
    #endif
    #define appPTR ( static_cast<GuiApplicationManager*>( AppManager::instance() ) )

So every ``appPTR`` in ``Gui`` is an **unchecked downcast of the singleton to
the GUI subclass**, not a reference to the engine object. Three consequences
matter for planning:

- It explains why ``getIcon`` never appears in ``Engine``. It cannot: it is
  declared on ``GuiApplicationManager``, not on ``AppManager``.
- The ``static_cast`` is undefined behaviour whenever the instance is not
  actually a ``GuiApplicationManager`` — exactly the headless configuration
  this whole plan is working towards. Today it is safe only because a process
  running ``Gui`` code always constructed the GUI subclass.
- Injecting an engine context is therefore not sufficient on the ``Gui`` side.
  The client depends on the singleton's *type identity*, so the coupling to
  break there is the subclass relationship, not just the global access.

What the singleton is actually used for
---------------------------------------

The reach is not 842 unrelated calls. It is dominated by a very small number of
services:

.. list-table::
   :header-rows: 1
   :widths: 34 14 14 14 24

   * - Call
     - Total
     - Engine
     - Gui
     - Nature
   * - ``getCurrentSettings``
     - 209
     - 51
     - 158
     - Application settings
   * - ``getIcon``
     - 161
     - 0
     - 161
     - **Purely a GUI concern**
   * - ``isBackground``
     - 65
     - 58
     - 7
     - Run-mode predicate
   * - ``writeToErrorLog_mt_safe``
     - 23
     - —
     - —
     - Diagnostics sink
   * - ``getAppTLS``
     - 15
     - 15
     - 0
     - Thread-local render state

The consequence for planning:

**Two extracted services cover 44% of the reach.** ``getCurrentSettings`` and
``getIcon`` together are 370 of 842 uses. Neither needs an engine context
threaded through a call chain; both are ordinary dependency injection, and
``getIcon`` never appears in ``Engine`` at all, so it can be done entirely
within the client without touching the core.

**Two thirds of what remains is a predicate and a log sink.** ``isBackground``
and ``writeToErrorLog_mt_safe`` are the next tier, and both are far cheaper to
inject than a full engine context.

**``getAppTLS`` is not this job.** Those 15 uses are the thread-local render
state, which belongs to the render-context step, not this one. They should be
left alone here so the two refactors do not collide in the same files.

Suggested sequencing
--------------------

Ordered so that each step is independently reviewable and shrinks the next:

1. **Icons out of the singleton** — 161 uses, ``Gui`` only, zero engine risk.
   The natural first batch and a good calibration of how the shim behaves.
2. **Settings as an injected service** — 209 uses across both modules; the
   single largest win, and it establishes the injection pattern.
3. **Run-mode and diagnostics** — ``isBackground``, ``writeToErrorLog_mt_safe``,
   ``setLoadingStatus``, ``hideSplashScreen``.
4. **The residue** — plug-in lookup, caches, GL context data. This is the part
   that genuinely needs an explicit engine context.
5. **Leave ``getAppTLS``** for the render-context work.

Throughout, keep the ``appPTR`` macro working behind a shim so that the tree
builds after every batch, and delete it only when the last caller is gone.

The related coupling
--------------------

Separately from ``appPTR``, the core reaches the Qt *application object* 292
times across ``Engine`` and ``Global``. The clearest instance is
``Engine/ThreadStorage.h``, which keys the renderer's per-thread state off the
existence of a GUI application::

    return ( qApp && QThread::currentThread() == qApp->thread() )
           || QThreadStorage<T>::hasLocalData();

That is the render core's state machine depending on whether a GUI application
exists. It belongs to the render-context step and is recorded here only so the
two are not confused: removing ``appPTR`` does **not** remove this.

Exit criterion
--------------

Unchanged from the plan: two independent engines run in one process, and the
engine can be constructed and driven from a unit test with no application
object. The counts above are what has to reach zero in ``Engine`` for that to
be true; the ``Gui`` counts can remain non-zero for longer, because the client
is allowed to know it is an application.

