# Apple-platform behavior audit

## Accessibility and interaction

`P5SketchView` accepts normal SwiftUI accessibility modifiers. The native canvas
publishes label, value, hint, activate, increment, decrement, escape, focus, keyboard,
pointer, Pencil, multi-touch, drag/drop, clipboard, and scroll semantics. Native P5
controls inherit Dynamic Type, VoiceOver, keyboard focus, localization, pointer, and
increased-contrast behavior from SwiftUI/UIKit/AppKit. Hosts own localized display
strings and should replace continuous animation with a static or user-controlled state
when Reduce Motion is enabled. The project intentionally ships focused product samples
rather than a separate example-gallery browser.

## Display and color

P5 reports display scale separately from logical canvas size and defines pixel density,
top-left raster order, image orientation, straight/premultiplied alpha boundaries,
sRGB, Display P3, and extended-range behavior. Core Graphics follows the host's display
presentation; offscreen and export formats remain explicit. P5 Metal targets declare
their pixel format and treat texture components as linear unless the application wraps
an explicitly sRGB native texture. HDR presentation is application-owned and not
implied by a wide-gamut color value. Dark mode does not rewrite sketch colors.

## Performance, memory, and energy

Display callbacks stop on pause and scene inactivity. Media resources expose stop and
cleanup behavior. P5 renderer resources are reusable; Matter reuses its largest body
buffer and provides purge APIs; ML5 caches have bounded inventory and eviction.
Cancellation prevents publication of obsolete results even when native GPU work cannot
be retracted. Regression budgets and the required Instruments audit procedure are in
`Documentation/Benchmarks.md`.

The iOS Simulator is a compile, lifecycle, and CPU-correctness target rather than a
substitute for device accelerator validation. ML5 rejects direct MPSGraph trainer
construction there with a typed accelerator-unavailable error, allowing an explicitly
configured CPU fallback. Vision feature-print requests preserve the simulator's typed
framework failure. Metal/MPSGraph numerical conformance and successful native Vision
feature extraction remain gated on macOS and physical-device-capable environments.

## Privacy and security

Each product includes an Apple privacy manifest. P5 documents host-app usage strings
and asks for camera, microphone, or Photos authorization only at an explicit call.
Networking uses URLSession and cancellation. ML5 remote model loading requires HTTPS,
SHA-256 integrity, model provenance, ownership, and license metadata. Dependency source,
revision, license, secrets, and GitHub dependency-review checks run in CI. The packages
contain no telemetry, advertising identifiers, analytics SDK, or bundled third-party
production model.
