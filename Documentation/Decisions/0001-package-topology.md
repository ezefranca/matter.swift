# ADR 0001: One package with three independent library products

- Status: Superseded by ADR 0002
- Date: 2026-08-15

## Context

The project implements native Swift counterparts to p5.js, Matter.js, and
ml5.js. The libraries must be independently consumable, but the Nature of Code
examples combine them and benefit from a coordinated compatibility and release
process.

A Git-backed Swift package is resolved from the repository root. Splitting the
libraries into nested manifests would make local development possible, but it
would not give remote consumers three independently resolvable package URLs.
True independent versioning would therefore require three repositories, three
release histories, and a compatibility matrix between their versions.

## Decision

Keep one root Swift package named `p5.swift` with three public library products:

- `P5`
- `Matter`
- `ML5`

The products share one semantic version and release tag. They remain independent
at the module boundary:

- no production target imports or depends on either of the other products;
- clients add and build only the products they use;
- each product has its own tests, DocC catalog, Xcode scheme, coverage gate,
  API baseline, and compatibility table;
- cross-product adapters live in examples or a future explicitly named
  integration product, never as hidden dependencies.

Public writing calls these “library products” or “modules,” not three separately
versioned Swift packages.

## Consequences

Benefits:

- one compatible version across the creative-coding stack;
- atomic changes when a book example reveals an integration requirement;
- one dependency URL and one release process for users;
- shared CI, documentation landing page, contribution policy, and examples.

Tradeoffs:

- a release tag advances all three products together;
- Swift Package Index presents one package entry with multiple products;
- urgent fixes in one product still create a coordinated package release.

## Reconsideration criteria

Revisit this decision only if independent release cadence becomes more valuable
than atomic compatibility, or if SwiftPM gains first-class remote subpackage
resolution and independent versioning within a repository.
