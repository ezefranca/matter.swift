# Third-party notices and attribution

## Source lineage

p5.swift is an expanded fork of Juan Hurtado's P5Swift. The MIT copyright notice for
that work is preserved in `LICENSE`. Later P5, Matter, and ML5 implementation work in
this repository is also distributed under the MIT License.

## Conceptual references

- [p5.js](https://p5js.org/) informs P5 terminology and behavior.
- [Matter.js](https://brm.io/matter-js/) informs Matter's conceptual API vocabulary.
- [ml5.js](https://ml5js.org/) informs ML5's approachable workflow vocabulary.
- Daniel Shiffman's [The Nature of Code](https://natureofcode.com/) informs the
  reusable capability audit.

No Matter.js, ml5.js, or Nature of Code source/example corpus is distributed in the
package. Names identify compatibility inspiration and do not imply affiliation,
sponsorship, or endorsement.

## Build and test dependencies

The package manifest pins `swift-testing` and its transitive `swift-syntax` dependency
for test targets only. Both are distributed by the Swift project under Apache License
2.0. Exact sources, revisions, scope, and license policy are machine checked from
`Configuration/DependencyPolicy.json`. Production library targets have no package
dependencies.

## Test resources

`Tests/ML5Tests/Resources/BundledModel.model-fixture` is a plain-text, repository-authored
fixture used to exercise bundle lookup and failure boundaries; it contains no trained
weights or third-party model material. The bundled Metal shaders are original package
source and ship under the repository MIT License.
