# Repository hygiene and generated files

The repository versions only artifacts required to build, test, document, audit, or demonstrate this package from a clean checkout.

Intentionally versioned generated/configuration artifacts are `Package.resolved` for the pinned test graph, the compiler-generated API baseline, the shared Xcode scheme/test plan, and the privacy manifest. They change only through review.

SwiftPM `.build`, Xcode user state, Derived Data, indexes, result bundles, profiler traces, raw coverage, compiled Metal libraries, credentials, `.netrc`, and OS metadata are never versioned. Run `python3 Scripts/check_repository_hygiene.py` to enforce the policy.
