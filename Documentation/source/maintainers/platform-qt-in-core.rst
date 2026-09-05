.. _maint-platform-qt-in-core:

Survey: Qt in the core
======================

.. note::

   **Measurement, with risk annotations.** Counted from branch ``RB-2.6`` after
   the ``qApp`` work. This exists so that "Qt out of the core" is planned
   against what the code contains rather than against a headline number.

Reach
-----

.. list-table::
   :header-rows: 1
   :widths: 22 26 52

   * - Module
     - Files including a Qt header
     - Note
   * - ``Engine``
     - 148 of 326
     - The subject of this step
   * - ``Global``
     - 4 of 19
     - Nearly clean already
   * - ``Gui``
     - 246 of 289
     - Stays. Qt is permitted here

What the usage actually is
--------------------------

.. list-table::
   :header-rows: 1
   :widths: 26 12 62

   * - Type
     - Uses
     - Replacement and risk
   * - ``QString``
     - 2932
     - ``std::string``. **The whole job, and the risky part** — see below
   * - ``QMutexLocker`` / ``QMutex``
     - 1303
     - ``std::lock_guard`` / ``std::mutex``. Mechanical
   * - ``QPointF``
     - 317
     - A two-double struct, or the existing ``Natron::Point``
   * - ``QObject``
     - 229
     - Signals and slots; a header-only event library
   * - ``QStringList``
     - 203
     - ``std::vector<std::string>``
   * - ``QThread``
     - 197
     - ``std::thread`` / ``std::this_thread``
   * - ``QReadLocker`` / ``QWriteLocker``
     - 127
     - ``std::shared_mutex`` (C++17)
   * - ``QDir`` / ``QFile`` / ``QFileInfo``
     - ~170
     - ``std::filesystem``

Ordered by risk, not by count
-----------------------------

**Mechanical and safe.** The locks are the easy win: 1303 uses of
``QMutex``/``QMutexLocker`` and 127 of the read-write lockers, against exactly
**one** use of ``QMutex::Recursive`` in the entire tree. Without recursive
mutexes to preserve, ``std::mutex``, ``std::shared_mutex`` and the standard
guards are drop-in. Filesystem and thread types are similarly direct.

**Mechanical but wide.** ``QPointF``, ``QStringList``, ``QDateTime``. Large
counts, no semantic subtlety.

**Not mechanical.** ``QString`` at 2932 uses, and the reason is visible in how
it is built: **1464 calls to** ``QString::fromUtf8`` **and 680 to**
``toStdString``. The codebase is already converting between the two
representations constantly, which is both the argument for the change — that
conversion traffic is pure overhead — and the hazard, because every one of those
call sites encodes an assumption about encoding that a blind substitution would
erase. ``QT_NO_CAST_FROM_ASCII`` is set project-wide precisely because these
assumptions matter.

**Design work, not substitution.** 229 ``QObject``, 141 ``Q_OBJECT``/
``Q_SIGNALS``/``Q_SLOTS`` and 177 ``connect`` calls. Replacing signals and slots
with a header-only event library changes threading semantics: Qt queues a
cross-thread connection by default, and a naive callback library invokes it on
the caller's thread instead. That difference is invisible at compile time and
shows up as a race.

**Small and separable.** 37 ``QtConcurrent`` uses, replaceable with the
standard library or a small task pool.

Prerequisite
------------

The plan is explicit that a golden-image corpus comes before the render-context
work, and the same applies here for a different reason. The lock and string
changes are wide enough that a compile-clean result proves very little: the
failure mode is a race or a mis-encoded path, neither of which the current
thirteen-file test suite would catch.

The ``qApp`` reduction was safe to do without that harness because 221 of its
243 substitutions were inside ``assert()`` and the rest asked a question with
one obviously correct answer. Nothing else in this survey has that property.
