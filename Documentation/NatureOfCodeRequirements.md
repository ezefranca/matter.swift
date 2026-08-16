# Nature of Code API requirements audit

The requirements reference is Daniel Shiffman's
[`nature-of-code/noc-book-2`](https://github.com/nature-of-code/noc-book-2) commit
`03b9a7eea3b56be8dfaef324736cf56455a2c5e4`. It is re-audited before a minor
release. Exhaustive example manifests and line-by-line ports are intentionally outside
scope; this checklist records reusable library capabilities only.

| Chapters | Required reusable capability | Package status |
| --- | --- | --- |
| 0–4 | vectors, seeded random/Gaussian/noise, motion, forces, particles, drawing | P5 complete |
| 5 | autonomous-agent vectors, steering, path geometry, deterministic update loops | P5 complete |
| 6 | bodies, forces, attraction, constraints, collisions, pointer interaction | Matter complete |
| 7–9 | cellular/fractal visual foundations, transforms, pixels, deterministic state | P5 complete |
| 10–11 | datasets, normalization, train/predict/classify, copy/mutate/crossover | ML5 complete |

The audit requires native safety beyond the browser examples: finite-value validation,
stable identifiers, actor isolation, cancellation, serialization revalidation, explicit
Metal/Core ML capability behavior, deterministic seeds, and immutable snapshots.

Compatibility means the packages provide the primitives needed to implement the book's
ideas in Swift. It does not promise JavaScript source compatibility, identical floating-
point output, browser APIs, bundled assets, or official affiliation. See the P5 DocC
article `The Nature of Code Compatibility` for attribution and native mapping.
