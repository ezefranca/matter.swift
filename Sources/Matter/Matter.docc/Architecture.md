# Architecture

## Metal is the production execution path

``Engine`` is an actor that owns a ``World`` and serializes mutations. Each
``Engine/step(ticks:)`` snapshots the actor-owned body values, passes them to
``MetalBackend``, and stores the GPU result only after the command buffer
completes. Failure to obtain a device, compile the bundled kernel, allocate a
buffer, or complete the command buffer is a typed ``MetalBackendError``.

The backend uploads a tightly defined 52-byte body-state representation. The
bundled `Integration.metal` kernel performs semi-implicit Euler integration for
linear and angular motion: it applies gravity, force, torque, inverse mass, and
inverse inertia; applies configured air damping; advances position and angle;
then clears force and torque. Sleeping bodies use the same immovable kernel path
as static bodies for that tick, while preserving their distinct public state.

## Value boundaries

``Vector``, ``Bounds``, ``BodyID``, shapes, material and filter values, body
definitions, bodies, and worlds are `Sendable` value types. A caller can safely retain a ``World`` returned by
``Engine/snapshot()`` or ``Engine/step(ticks:)`` without sharing engine state.
The only mutable production ownership boundary is the ``Engine`` actor.

## Collision ownership

``CollisionDetector`` is a deterministic CPU snapshot query. Its adaptive
sweep-and-prune broad phase caches bounds, chooses the widest axis, and exposes
stable work metrics; its separating-axis narrow phase and contact generation do
not mutate the world. Narrow-phase lookup uses one body-ID index per snapshot
instead of rescanning the world for each candidate. ``CollisionSolver`` applies
sequential contact impulses and positional correction on the CPU. After each Metal integration command completes,
``Engine`` runs those CPU-owned collision phases on its actor-isolated world.

This division is fixed configuration, not a silent fallback: Metal remains
mandatory for production integration, and all Metal failures are surfaced. The
CPU constraint and collision implementations are also shared with
``ReferencePhysics`` so tests can compare complete deterministic ticks without
duplicating response behavior. An enabled sleeping pass first propagates wake
state through current islands. Each tick then integrates, detects newly formed
contacts and propagates wake state again, solves constraints, resolves
collisions, and finally classifies quiet islands.
The actor-owned ``CollisionTracker`` persists canonical pair state between ticks
and produces value-semantic events returned by ``Engine/stepWithEvents(ticks:)``.
``Runner`` is a second actor boundary that owns only wall-clock accumulation and
delegates fixed work to an engine. Its capped ``FixedStepAccumulator`` makes
interpolation and dropped catch-up time explicit rather than tying simulation
speed to display callbacks.

``WorldQuery`` operates exclusively on a caller-provided ``World`` value. Point,
region, and ray queries therefore observe one coherent snapshot, require no
actor hop, and never mutate engine-owned state.

Composites are stable references into that same world value. A ``Composite``
stores body and constraint identifiers plus one optional parent identifier; it
never duplicates mutable physics state. ``World`` owns hierarchy validation,
prevents cycles, and cleans membership when bodies, constraints, or composite
subtrees are removed.

Multi-body operations validate and prepare replacements before committing them.
``Engine/updateWorld(_:)`` extends that transactional value boundary to an
arbitrary synchronous batch in one actor hop.

``IslandManager`` derives stable dynamic-body components from nonsensor contacts
and body-to-body constraints. It excludes static bodies as graph bridges, so a
shared ground does not merge independent stacks. ``SleepingManager`` and its
value-semantic ``SleepingState`` apply simultaneous island transitions on both
the Metal engine and stateful CPU reference path.

## CPU reference path

``ReferenceIntegrator`` implements the same integrator using value semantics.
It exists to make numerical behavior deterministic in unit tests and to
provide a transparent reference implementation. The engine never chooses it
when Metal is unavailable; creation instead throws ``MetalBackendError``.

## Cancellation

Metal has no API for cancelling a command buffer once committed. The backend
checks cancellation before submission and after a checked-continuation bridge
for completion. A cancelled task therefore never returns an integration
result, while a previously committed command buffer is allowed to finish on
the GPU.
