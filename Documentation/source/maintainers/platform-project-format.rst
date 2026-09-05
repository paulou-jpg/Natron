.. _maint-platform-project-format:

Specification: the project file format
======================================

.. note::

   **Status: draft for review.** This is the second of the two contracts
   pipeline tooling is written against; the first is
   :ref:`maint-platform-python-api`. Both are specified before the tooling
   exists, because changing them afterwards costs a migration.

The goal
--------

A pipeline tool must be able to **read and rewrite a comp as data** — without
linking C++, without launching Natron, and without a Python interpreter that
has Natron's bindings installed. Answering "which nodes in these 400 comps
reference this footage path" should be a script, not a render farm job.

That is not possible today.

The format as it exists today
-----------------------------

The project file is a Boost.Serialization archive: a C++ object graph written
out through ``serialize()`` members spread across **33 serialization files** in
``Engine/``, with **22 versioned classes** carrying their own independent
version macros.

The consequences are worth stating plainly, because they are the entire
motivation for changing it.

**The format is defined by C++ class layout.** There is no schema. The authority
on what a ``.ntp`` file contains is the set of ``serialize()`` templates, and
they are only executable, not readable as a specification. Adding a member in
the right place silently changes the format.

**Only Natron can read it.** Boost.Serialization archives are not a
language-neutral interchange format. Any tool that wants to inspect a comp must
link the C++ that wrote it.

**Reading a project requires an application.**
``Engine/ProjectSerialization.h`` shows this directly — the serialization root
holds a back-pointer to the running application::

    class ProjectSerialization
    {
        NodeCollectionSerialization _nodes;
        std::list<Format> _additionalFormats;
        std::list<KnobSerializationPtr> _projectKnobs;
        SequenceTime _timelineCurrent;
        qint64 _creationDate;
        AppInstanceWPtr _app;          // <-- the file format knows about the app
        unsigned int _version;
        ...
    };

**Versioning is per-class and ad hoc.** The project root alone has accumulated
six versions, each a named macro describing a structural change:

.. code-block:: c

    #define PROJECT_SERIALIZATION_INTRODUCES_NATRON_VERSION    2
    #define PROJECT_SERIALIZATION_REMOVES_NODE_COUNTERS        3
    #define PROJECT_SERIALIZATION_REMOVES_TIMELINE_BOUNDS      4
    #define PROJECT_SERIALIZATION_INTRODUCES_GROUPS            5
    #define PROJECT_SERIALIZATION_CHANGE_VERSION_SERIALIZATION 6

Multiply that by 22 classes, each versioned independently, and the real
compatibility matrix is not something anyone holds in their head.

What adopting from scratch changes
----------------------------------

.. important::

   There are **no existing comps to convert**. That removes the single most
   expensive part of a file-format change: there is no converter to write, no
   compatibility reader to carry forward, and no corpus to round-trip. The
   format change carries no data-loss exposure.

This is a design exercise, and it will not be this cheap again.

Requirements
------------

**R1 — Language-neutral.** Readable and writable from Python, and from any
language with a parser for the container format, with no Natron code linked.

**R2 — Schema'd.** The format has a written schema that is the authority, and
the C++ reader/writer is validated against it — not the other way round.

**R3 — No application dependency.** Loading a project produces a data
structure. Nothing in the reader path touches an engine, a renderer or a GUI.

**R4 — Diff- and merge-friendly.** Text, with stable key ordering, so that comps
live in version control and review as changes rather than as opaque blobs.

**R5 — One version number.** A single format version for the document, with an
explicit migration path between versions. Not 22 independent counters.

**R6 — Forward-compatible in the small.** Unknown keys are preserved on
round-trip where possible, so an older tool rewriting a comp does not silently
drop data a newer Natron wrote.

**R7 — Large data lives outside the document.** Curves, roto point sets and
tracker data can be large. The document format must not force them inline if
that makes it unusable.

Proposed structure
------------------

A text document with one root object and an explicit version::

    natron_project: 1
    metadata:
      created:  <iso-8601>
      app:      <writer version>
    settings:
      formats: [...]
      params:  {...}          # project-level knobs
    timeline:
      current: <frame>
    graph:
      nodes:
        - id:      <stable unique id>
          plugin:  { id: <ofx plugin id>, version: [maj, min] }
          label:   <string>
          inputs:  { <input name>: <node id | null> }
          params:  { <name>: <value or animation> }
          roto:    {...}      # only when present
          tracker: {...}      # only when present
        - ...
      groups:
        - id: <node id>
          graph: { ... }      # recursive

The shape mirrors what the current archive already stores — a node collection,
project knobs, additional formats and a timeline position — so this is a change
of *encoding and authority*, not of model.

Decision: the container format
------------------------------

**JSON, with a JSON Schema alongside it.** Decided; the reasoning is recorded
here because the choice is hard to reverse once tooling exists.

The candidates were not equivalent, and two ruled themselves out on grounds
that have nothing to do with taste:

**TOML is a structural mismatch.** The document is recursive -- groups contain
graphs which contain groups -- and TOML is built for flat configuration. Nested
arrays-of-tables express that badly enough to hurt every reader written against
it.

**YAML's ambiguity undermines R1.** "Any language can read it" is weaker for
YAML than it looks: implementations genuinely disagree, and the specification
has traps that corrupt data silently rather than failing loudly. An unquoted
``no`` parses as boolean false, and a version-like ``1.10`` parses as the float
1.1. Both are plausible values in a comp.

JSON wins on the requirement that matters most here. Parsers are everywhere and
agree with each other, schema tooling is mature (R2), and preserving unknown
keys across a round-trip is trivial (R6). The cost is that JSON has no comments;
that is acceptable, because comps are written by tools rather than typed by
hand.

.. warning::

   **Float fidelity must be specified, not left to the parser.** Animation
   curves, transform matrices and colour values are all floating point, and many
   JSON implementations round-trip through a double without care, drifting
   values slightly on every save. The schema fixes the representation:
   floats are written with enough significant digits to round-trip exactly
   (17 for IEEE-754 doubles), and readers must not reformat values they did not
   change.

Encoding is deliberately kept separate from the data model, so that a binary
encoding can be added later for R7 without redesigning the document. `USD
<https://openusd.org>`_ is the precedent worth following: one data model, a text
encoding for diffing and review, and a binary encoding for scale. Do not build
the binary encoding now -- but do not specify anything that would prevent it.

Decisions still open
--------------------
- **Node identity.** Stable ids are needed for R4 and R6. Are they UUIDs
  (stable but unreadable in a diff) or scoped names (readable but they change
  when a node is renamed)?
- **Parameter values vs animation.** One polymorphic ``params`` map, or separate
  static-value and animated-curve sections?
- **Where R7 applies.** Which data is large enough to move out of the document,
  and does it go into a sidecar file or a container that holds both?
- **Plug-in version policy.** What happens on load when the installed OpenFX
  plug-in version differs from the one recorded — refuse, warn, or migrate?

Relationship to the rest of the plan
------------------------------------

R3 is the requirement with a dependency: a reader that touches no application
object cannot be delivered while the serialization root holds an
``AppInstanceWPtr``. In practice the format and the de-singleton work
(:ref:`maint-todo` step 03) meet here, and this specification is what tells that
refactor where the seam has to be.

