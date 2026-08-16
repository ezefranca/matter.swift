# Security policy

## Supported versions

Security fixes are applied to the latest released minor version. Pre-1.0 releases may
include source-compatible hardening between minors; a necessary breaking fix is called
out in the security advisory and changelog.

## Report privately

Use GitHub private vulnerability reporting for the affected repository. Do not open a
public issue for an undisclosed vulnerability. Include:

- affected product, version, platform, and toolchain;
- minimal reproduction and required permissions or model/input data;
- confidentiality, integrity, availability, privacy, or supply-chain impact;
- known mitigations and whether public disclosure already occurred.

Maintainers will acknowledge receipt, reproduce and assess severity, prepare a fix and
tests, coordinate disclosure, and publish an advisory and patched semantic version.
There is no guaranteed response-time SLA for this volunteer project.

## Security boundaries

P5 processes untrusted images, text/tables, OBJ data, media URLs, and persisted values.
Matter decodes potentially untrusted world snapshots. ML5 processes model packages,
archives, datasets, and remote URLs. Validation, bounded allocation, cancellation, and
typed failures reduce risk but do not make arbitrary media or models trustworthy.

ML5 accepts remote model sources only over HTTPS with a caller-provided SHA-256 digest
and model provenance. Applications remain responsible for server trust, model behavior,
privacy review, and sandbox permissions. Never include credentials in a package URL,
diagnostic, test fixture, issue, or trace.
