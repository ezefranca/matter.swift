# Performance baseline methodology

Performance checks are regression tripwires, not universal throughput claims.
`Configuration/PerformanceBudgets.json` records deliberately broad wall-clock
ceilings. `Scripts/run_performance_baselines.py` runs focused deterministic suites
for P5 Metal submission, Matter broad-phase scaling, and ML5 canonical training.

## Current local reference

Measured on 2026-08-16 using an Apple M4, macOS 26.6.1, and Apple Swift 6.3.2
(Command Line Tools); full Xcode validation uses Swift 6.3.3:

| Workload | Observed | CI ceiling |
| --- | ---: | ---: |
| P5 Metal rendering suite | 0.44 s | 15 s |
| Matter broad-phase suite | 0.72 s | 20 s |
| ML5 canonical training suite | 0.65 s | 45 s |

These values include test-process startup and vary with thermal state and runner load.
A release compares pass/fail against the checked-in ceiling and records the CI host
and toolchain in release notes. Algorithmic tests separately assert Matter sparse
linear work, dense output-sized behavior, numerical tolerances, and deterministic
ordering.

For release candidates, also profile representative applications with Instruments:
Time Profiler, Allocations, Leaks, Metal System Trace, and Energy Log. Record the app,
device, OS, duration, workload seed, and trace summary. Instrument traces are local
diagnostic artifacts and must not be committed.
