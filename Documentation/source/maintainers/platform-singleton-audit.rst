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

Not all of it has to be injected
--------------------------------

Counting uses overstates the work, because much of what ``appPTR`` provides is
genuinely **process-global** and can stay that way. The exit criterion is two
independent *engines* in one process -- not the abolition of every global.

Sorting the frequent calls by what they actually describe:

.. list-table::
   :header-rows: 1
   :widths: 46 12 42

   * - Call
     - Uses
     - Nature
   * - ``isBackground``, ``getAppType``
     - 71
     - How **this process** was started
   * - ``getPluginBinary``, ``getPluginsList``, ``getPluginIDs``,
       ``getReaderPluginIDForFileType``
     - 26
     - The installed plug-in registry: a property of the machine
   * - ``getWGLData`` / ``getEGLData`` / ``getGLXData``, ``isOpenGLLoaded``,
       ``initializeOpenGLFunctionsOnce``, ``isOnWayland``
     - 52
     - The process's graphics and windowing environment
   * - ``writeToErrorLog_mt_safe``, ``setLoadingStatus``, ``hideSplashScreen``
     - 50
     - Diagnostics and startup progress
   * - ``getHardwareIdealThreadCount``
     - 5
     - A property of the hardware
   * - ``getMainModule``
     - 6
     - The embedded Python interpreter, one per process

None of those prevent two engines from coexisting. They want to become
ordinary services with clear ownership rather than reaching a god object, but
that is tidying, not the refactor the plan is paying for.

What genuinely blocks a second engine is much smaller:

``getTopLevelInstance`` (17)
    "The current app instance" is the singleton assumption stated directly.
    Any caller of this cannot be made to work with two engines.
``getCurrentSettings`` (209)
    Blocking, but only partly -- see below.
``removeFromNodeCache`` and the cache accessors (6+)
    Whether the image cache is shared between engines or owned by each is a
    real design decision, not a mechanical substitution.
``getAppTLS`` (15)
    Thread-local render state, belonging to the render-context step.

.. warning::

   **Settings cannot be substituted mechanically.** ``Settings`` is a single
   object holding fourteen knob pages, and they are not one concern: threading,
   rendering, GPU, caching, projects, plug-ins, OCIO and Python are engine
   configuration, while UI, appearance and documentation are client
   preferences. A blanket accessor -- the shortcut that worked for icons --
   would silently encode "settings are process-global" for all of them, and
   unpicking that later means revisiting all 209 call sites a second time
   because each has to choose which half it wanted.

   Split ``Settings`` into engine configuration and client preferences
   **before** touching its call sites, not after.

Suggested sequencing
--------------------

Ordered so that each step is independently reviewable and shrinks the next:

1. **Icons out of the singleton** — 161 uses, ``Gui`` only, zero engine risk.
   Done: they now go through ``Gui/NatronIcons.h``, so the dependency sits in
   one translation unit instead of twenty-five.
2. **Settings**: keep one object, matching Nuke, and gate interface-only
   behaviour on a runtime predicate rather than dividing the class. See below —
   this was originally planned as a split, and researching Nuke changed it.
3. **The ``Settings`` call sites**, once the accessor is settled. No longer
   blocked on a split.
4. **``getTopLevelInstance``** — 17 uses, but reading them shows only about
   six are what the name suggests. Eleven are message routing: the eight
   ``Dialogs`` functions and the script-editor output ask "is there a user
   interface to show this in", not "which engine am I". Those are already
   headless-safe, since each falls back to the console. The remaining handful
   -- the OCIO warning in ``Settings``, the Python entry point, and
   ``DocumentationManager`` creating nodes in a project -- are the ones that
   genuinely assume a single current engine.
5. **The cache** — decide whether it is shared or per-engine, then follow.
6. **Process-global services** — run mode, diagnostics, plug-in registry, GL
   environment. Give them clear ownership at leisure; they do not block a
   second engine.
7. **Leave ``getAppTLS``** for the render-context work.

The reordering matters: the earlier draft put settings second because it is the
biggest number. It is second-to-last in usefulness until it is split, and
splitting it is what makes the batch safe.

Throughout, keep the ``appPTR`` macro working behind a shim so that the tree
builds after every batch, and delete it only when the last caller is gone.

What is actually in ``Settings``
--------------------------------

Counted from the knob declarations in ``Engine/Settings.h``, grouped by the
page comments already in the file. 153 knobs in nineteen groups:

.. list-table::
   :header-rows: 1
   :widths: 46 12 42

   * - Page
     - Knobs
     - Belongs to
   * - Threading
     - 7
     - **Engine** — render thread counts, thread pool
   * - Rendering
     - 5
     - **Engine** — NaN handling, RGB support
   * - GPU rendering
     - 5
     - **Engine** — OpenGL contexts and renderer choice
   * - Projects setup
     - 5
     - **Engine** — project load and format behaviour
   * - Color-Management (OCIO)
     - 5
     - **Engine** — the colour pipeline
   * - Caching
     - 11
     - **Engine** — image cache sizing
   * - Plugins
     - 6
     - **Engine** — plug-in search paths
   * - Python
     - 9
     - **Engine** — project and node callbacks
   * - User Interface
     - 10
     - Client
   * - Viewer
     - 12
     - Client
   * - Nodegraph
     - 11
     - Client
   * - Documentation
     - 3
     - Client — the local documentation server
   * - Appearance (six pages)
     - 55
     - Client — fonts, stylesheet, and every colour
   * - General
     - 9
     - **Mixed** — see below

That is **53 knobs of engine configuration against 91 of client preference**,
and the largest single block is the 55 appearance knobs: fonts, the stylesheet,
and the colours of the main window, curve editor, dope sheet, script editor and
node graph. A headless renderer has no use for any of them.

.. important::

   **Do not split the object. Nuke does not, and Natron already matches its
   shape.**

   Nuke keeps a single ``Preferences`` node whose knobs cover colour schemes,
   autosave, memory usage and node defaults together, saved to
   ``preferences.nk``. It does not divide preferences into engine and interface
   halves. Natron's ``Settings`` is already the same construct — a knob holder
   with pages — so splitting it into two classes would *diverge* from Nuke
   rather than converge on it.

   What Nuke separates instead is **when code runs**, not what the data
   contains: ``init.py`` executes in every session including terminal and
   render, while ``menu.py`` executes only in a GUI session, and scripts branch
   on ``nuke.env['gui']``. Natron already has the equivalent predicate in
   ``appPTR->isBackground()``.

   Nuke does keep a second store, ``uistate.ini``, but the line there is
   **transient window and workspace state** — window locations, panel layout,
   with a few settings such as the viewer playback cache size — not engine
   versus client.

So the table above should be read as documentation of what the pages *mean*,
useful for deciding which knobs a headless engine may ignore, rather than as a
plan to divide the class.

What follows from matching Nuke
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

- ``Settings`` stays one object. The 209 call sites do not have to choose a
  half, which removes the reason this batch was blocked.
- Behaviour that only makes sense with an interface is gated on a runtime
  predicate, the way Nuke gates on ``nuke.env['gui']``. The OCIO warning in
  ``Settings.cpp`` is exactly this case: keep the config knob, gate the warning.
- Window and workspace state is the thing worth separating, if anything is,
  and that is a different axis from the one proposed above.

The one place Natron may still need to diverge is multiple engines in one
process, since Nuke has no equivalent and therefore offers no guidance. That is
not a present requirement, so it should not drive the design now; if it becomes
one, per-engine overrides layered over a single settings object are a smaller
change than two classes.

Two consequences worth settling either way:

- **Ownership of the file.** Preferences are saved through ``QSettings`` today.
  If engine configuration is to be settable by an embedding application, it
  needs to be constructible without reading the user's desktop preferences at
  all.
- **The OCIO warning.** ``Settings.cpp`` reaches ``getTopLevelInstance`` only
  to warn the user that the OCIO config changed. Keeping one settings object
  means the knob stays put and the warning is gated on whether an interface
  exists — the ``nuke.env['gui']`` pattern applied to one of the few remaining
  genuinely per-engine call sites.

The related coupling: qApp
--------------------------

Separately from ``appPTR``, the core referenced the Qt *application object* 322
times across ``Engine`` and ``Global``. Reading those references corrects the
plan on two points.

**The headline example is dead code.** ``Engine/ThreadStorage.h`` is cited as
proof that the renderer's state machine is keyed off the existence of a GUI
application, via::

    return ( qApp && QThread::currentThread() == qApp->thread() )
           || QThreadStorage<T>::hasLocalData();

Nothing includes that header and nothing instantiates ``ThreadStorage<>``. The
similarly-named ``ClipsThreadStorageSetter`` and ``RenderThreadStorageSetter``
in ``OfxEffectInstance.cpp`` are unrelated classes. The file is not in the
render path.

**The real thread-local storage does not touch qApp at all.** ``TLSHolder``,
used by roughly ten files including ``OfxHost``, ``OfxClipInstance`` and
``Node``, contains zero references to the application object. It does use
``QThread*`` as a thread handle, which is Qt coupling and belongs to the
"Qt out of the core" step, but that is not the same thing as depending on a
GUI application.

What the 322 references actually were:

.. list-table::
   :header-rows: 1
   :widths: 60 12 28

   * - Shape
     - Count
     - Nature
   * - ``QThread::currentThread() == qApp->thread()`` inside ``assert()``
     - 221
     - Debug-only; compiled out in release
   * - The same comparison outside an assert
     - ~22
     - "Am I on the main thread"
   * - ``qApp->thread()`` where the ``QThread*`` itself is wanted
     - 36
     - Genuine Qt use, e.g. ``moveToThread``
   * - Everything else (``quit``, ``exec``, ``arguments``, app metadata)
     - ~8
     - Application lifecycle, correctly in ``AppManager``

So the dominant use was one idiom asking a question with no inherent connection
to Qt — *which thread am I on* — and most instances of it disappeared in
release builds. ``Global/MainThread.h`` now answers it with
``std::this_thread::get_id()``, and the count is down from 322 to 81.

The remaining 81 are mostly the cases that genuinely want a ``QThread*``, plus
application lifecycle in ``AppManager``. Those are ordinary Qt use rather than
evidence of a GUI dependency in the renderer.

.. note::

   This does not mean the plan's conclusion is wrong, only its most vivid piece
   of evidence. The engine still cannot run without ``AppManager``, and Qt is
   still woven through the core. But "the render core's state machine is keyed
   off the existence of a GUI application" overstated what the code did, and a
   quarter of an afternoon's mechanical substitution removed three quarters of
   it.

Exit criterion
--------------

Unchanged from the plan: two independent engines run in one process, and the
engine can be constructed and driven from a unit test with no application
object. The counts above are what has to reach zero in ``Engine`` for that to
be true; the ``Gui`` counts can remain non-zero for longer, because the client
is allowed to know it is an application.

