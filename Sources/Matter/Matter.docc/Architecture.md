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
then clears force and torque.

## Value boundaries

``Vector``, ``Bounds``, ``BodyID``, shapes, material and filter values, body
definitions, bodies, and worlds are `Sendable` value types. A caller can safely retain a ``World`` returned by
``Engine/snapshot()`` or ``Engine/step(ticks:)`` without sharing engine state.
The only mutable production ownership boundary is the ``Engine`` actor.

## Collision ownership

``CollisionDetector`` is a deterministic CPU snapshot query. Its sweep-and-prune
broad phase, separating-axis narrow phase, and contact generation do not mutate
the world. ``CollisionSolver`` applies sequential contact impulses and positional
correction on the CPU. After each Metal integration command completes,
``Engine`` runs those CPU-owned collision phases on its actor-isolated world.

This division is fixed configuration, not a silent fallback: Metal remains
mandatory for production integration, and all Metal failures are surfaced. The
CPU collision implementation is also shared with ``ReferencePhysics`` so tests
can compare complete deterministic ticks without duplicating response behavior.

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
