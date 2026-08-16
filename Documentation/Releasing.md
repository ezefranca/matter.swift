# Release and rollback procedure

Releases are immutable semantic-version tags. A release candidate is eligible
only after the repository is clean and `Scripts/validate_release.sh` passes on
the tagged commit with full Xcode selected. The tag's version must have a dated
heading in `CHANGELOG.md` and no API change may be absent from the reviewed API
baseline.

The release workflow rebuilds and tests the tag, creates a source archive,
records SHA-256 checksums and the exact Git commit in `release-manifest.json`,
and attaches both files to the GitHub Release. Documentation and post-release
smoke workflows then verify DocC routes, Swift Package Index visibility, and a
fresh external SwiftPM client.

## Rollback and yanking

Git tags and published release artifacts are never rewritten. If a release is
unsafe:

1. Mark the GitHub Release as withdrawn and explain the affected versions and
   recovery in the release notes and security advisory when relevant.
2. Publish the smallest possible forward-fix patch from the last trusted tag.
3. If resolution must stop immediately, delete only the remote tag after
   recording its commit and checksums in the incident. Existing clones and
   caches may retain it, so this is not a substitute for a patched version.
4. Keep the changelog entry, add a withdrawal notice, and ensure documentation
   defaults to the fixed version.
5. Run the external-client, SPI, documentation, and checksum smoke tests again.

Swift Package Manager has no universal registry-yank mechanism for Git tags.
Consumers must be given an explicit safe version constraint and migration note.
