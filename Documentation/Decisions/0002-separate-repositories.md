# ADR 0002: Three independent repositories

- Status: Accepted
- Date: 2026-08-15
- Supersedes: ADR 0001

## Context

P5, Matter, and ML5 are independent native Swift libraries with different
runtime concerns, documentation audiences, release cadences, and infrastructure
needs. Swift Package Manager also resolves packages at repository roots, so
separate package identities and versions require separate repositories.

The initial monorepo remains useful while the incomplete APIs are implemented
and tested together. The project owner has chosen independent repositories for
the finished distribution and explicitly removed exhaustive Nature of Code
example ports from the release scope.

## Decision

Complete the library implementations in the current working repository, then
split them into three history-preserving local repositories:

- `p5.swift`, exposing the `P5` product;
- `matter.swift`, exposing the `Matter` product;
- `ml5.swift`, exposing the `ML5` product.

Each repository owns its Swift package manifest, dependency lock state, tests,
DocC catalog, shared Xcode scheme and test plan, API baseline, formatting and
validation scripts, GitHub Actions workflows, Swift Package Index configuration,
release policy, changelog, contribution guide, security policy, and license
notices. Production modules remain dependency-free from the other two projects.

Each README and documentation landing page links to the other two sibling
projects and describes their complementary roles. Cross-library examples, if
added later, live in a separately versioned integration repository or sample app.

## Migration requirements

The split is complete only when:

- each new repository passes its own clean validation from its own root;
- no workflow or script relies on files outside that repository;
- package and documentation metadata use the final independent URLs;
- API histories and attribution remain traceable;
- reciprocal links are tested;
- the old combined distribution clearly points users to the three successors.

## Consequences

Each project can publish fixes and major versions independently, and Swift
Package Index presents three focused package pages. The cost is duplicated
infrastructure and an explicit compatibility policy for any future integration
sample. That duplication is intentional: a project must remain releasable when
the other two repositories are unavailable.
