# Troubleshooting

## SwiftPM and toolchains

- Run `swift --version` and compare it with `Configuration/SupportPolicy.json`.
- Remove only package build output with `swift package clean`; do not delete shared
  Xcode or user data.
- Resolve from a clean external package with `Scripts/validate_external_client.sh
  --path .` when an import works inside the repository but not in an application.
- In Swift Playgrounds, use an App playground on a supported OS and add the package
  dependency before importing a product.

## Metal

Check the relevant `isAvailable` property before constructing P5 3D or Matter
execution. Simulators build both products, but runtime Metal availability depends on
the host. Shader, allocation, encoder, command-buffer, and device failures remain
distinct typed errors. Recreate an actor and its resources only after the application
has decided the failure is recoverable.

## Core ML and MPSGraph

Core ML expects a compiled model URL or an ML5-exported model that Core ML can compile.
Confirm input names, tensor shapes, and output task configuration. MPSGraph training
requires Metal; select an explicit CPU fallback only if a pre-training device failure
is acceptable. A numerical or graph failure after training starts is never hidden.

The iOS Simulator does not provide a reliable MPSGraph graph device and can also reject
Vision feature-print requests because no Espresso context is available. These cases
return typed ML5 errors. Use CPU training in simulator tests and run accelerator and
feature-print acceptance tests on macOS or physical Apple devices.

## Permissions and privacy

Camera, microphone, and Photos access require usage descriptions in the host app and
user authorization. Package privacy manifests describe package behavior but do not
replace the application's `Info.plist` strings. Treat denied and restricted states as
normal UI states, not fatal programmer errors.

## Reporting a reproducible failure

Include the product, package revision, OS, architecture, `swift --version`, Xcode
version, minimal code, typed error case, and whether the failure reproduces after
`bash Scripts/validate.sh --skip-xcode`.
