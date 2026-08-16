# Matter.js Compatibility and Native Differences

Map Matter.js concepts to typed, deterministic Swift values.

| Matter.js concept | Matter type | Native difference |
| --- | --- | --- |
| `Engine`, `Runner` | ``Engine``, ``Runner`` | Actors serialize mutable timing and world state. |
| `Bodies`, `Body` | ``Bodies``, ``Body`` | Validated value factories replace mutable JavaScript object bags. |
| `Composite`, `Constraint` | ``Composite``, ``Constraint`` | Stable typed identifiers define ownership. |
| `Events` | ``Events`` and ``CollisionEvent`` | Ordered `AsyncSequence` delivery is cancellation-aware. |
| `Query` | ``WorldQuery`` | Queries consume immutable snapshots. |
| `MouseConstraint` | ``MouseConstraint`` | Input arrives as native coordinate values; Matter does not depend on P5. |
| rendering helpers | ``MatterDrawingAdapter`` | Value drawing commands let the host choose P5, Core Graphics, or another renderer. |

The authoritative upstream reference is the
[Matter.js API documentation](https://brm.io/matter-js/docs/). Compatibility is
conceptual, not serialized-state or bit-for-bit solver compatibility. Matter uses
Swift validation, deterministic ordering, bounded continuous-collision substeps,
and a fixed Metal-integration/CPU-collision ownership model. JavaScript plugins,
DOM events, canvas rendering, and arbitrary mutation of engine internals do not
map directly.

``Vector``, body/world snapshots, collision results, and configuration values are
`Sendable`. Metal and runner state are actor-owned. Invalid dimensions, masses,
filters, iterations, or nonfinite values throw before state is committed.
