# ADR 0003: Public module names

- Status: Accepted
- Date: 2026-08-16

## Context

The public modules are native Swift counterparts to p5.js, Matter.js, and
ml5.js. `P5`, `Matter`, and `ML5` are concise imports and match the project
names, but `Matter` is a common word and `P5` and `ML5` resemble upstream
brands. A consumer could also define a target with the same name. Swift has no
module namespaces that would remove every possible collision.

## Decision

Keep the public module and product names `P5`, `Matter`, and `ML5` for 1.0.
There are no Apple SDK frameworks with those exact import names in the
supported iOS 17 and macOS 14 SDKs. The names preserve recognizable imports and
avoid forcing an artificial vendor prefix into every API use.

Each independent repository uses a lowercase package identity—`p5.swift`,
`matter.swift`, or `ml5.swift`—and exposes exactly one correspondingly named
library product. Documentation always qualifies conceptual references to the
JavaScript projects with `.js` and describes these implementations as
independent native counterparts, not official ports.

## Compatibility policy

Changing a module or product name is source-breaking and requires a major
version. If Apple adds a colliding framework, or ecosystem evidence shows a
material collision, the project will publish a migration guide and a
deprecated compatibility product when SwiftPM can support one safely.

Application targets should avoid reusing the imported module's name. A client
that already owns a conflicting module can use Swift's module-qualified names
or isolate the dependency behind its own adapter target.
