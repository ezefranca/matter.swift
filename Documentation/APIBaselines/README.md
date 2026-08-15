# Public API baselines

`P5.json`, `Matter.json`, and `ML5.json` are compiler-generated public API
baselines. `Scripts/check_api_breakage.sh` compares every build against them
with `swift-api-digester`.

An intentional source-breaking change must be called out under **Changed** or
**Deprecated** in `CHANGELOG.md`, follow the package's semantic-version policy,
and include regenerated baselines in the same reviewed pull request:

```sh
Scripts/update_api_baselines.sh
Scripts/check_api_breakage.sh
```

Never update a baseline merely to make CI pass. Review its diff alongside the
source declaration and migration guidance. Baselines use Swift 6 language mode,
the macOS 14 deployment target, and omit local paths and compiler invocation
arguments to keep changes reviewable.
