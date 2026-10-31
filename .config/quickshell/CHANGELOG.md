# Changelog

## [Unreleased]

### Added

- `bench/run`: benchmark of the bar (startup, idle cost, open time and CPU per dropdown) in an isolated nested compositor with one bar per output (`bench/env`, `--outputs`), optionally with a QML profiler pass (`--profile`); the bar's `perf` IPC target supplies the measurements.
- `QS_BENCH_INSTANCE=<id>` runs independent bench stacks in parallel (own state and runtime dirs, scopes and report directory).

### Changed

- Dropdowns open faster: each bar keeps one dropdown window (1x1 and click-through while closed) instead of creating one per open.
- The CPU and memory dropdowns show their process lists right away instead of after about a second; hovering the module prepares the list.
- Usage meters and CPU core bars in the dropdowns jump to each new sample instead of animating.
- Less CPU while idle: outside the GPU dropdown, nvidia-smi polls only GPU utilization.
- The disk dropdown refreshes filesystem usage every 15 s instead of every 2 s.
- The Wi-Fi list re-sorts by signal strength 1.5 s after a change instead of on every scan update.
- The bar renders with Qt Quick's software renderer, which needs much less memory than an OpenGL context per window; set `QT_QUICK_BACKEND` (empty for OpenGL) to override it.
- The audio dropdown's level meters update at 30 Hz.

### Fixed

- The Bluetooth dropdown no longer repaints continuously while it is open.
