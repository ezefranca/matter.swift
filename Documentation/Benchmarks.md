# Performance baseline methodology

Performance checks are regression tripwires, not universal throughput claims. `Configuration/PerformanceBudgets.json` gives Matter's deterministic sweep-and-prune scaling suite a broad 20-second wall-clock ceiling including test-process startup.

The 2026-08-16 Apple M4 reference completed the focused suite in 0.72 seconds; the final integrated run completed it in 0.97 seconds. Algorithmic assertions separately prove sparse linear primary-axis work, exact dense output sizing, oracle equivalence, numerical tolerances, and stable ordering. Release notes record hardware, OS, toolchain, thermal context, observed time, and budget result.

For tagged candidates, run `Scripts/run_instruments_audits.sh` with Time Profiler, Allocations, Leaks, Metal System Trace, and Power Profiler after granting the host's protected process-analysis permission. Record findings and never commit trace archives. Deterministic lifetime tests, sanitizer jobs, reusable Metal-buffer statistics, and explicit purge behavior remain CI gates.
