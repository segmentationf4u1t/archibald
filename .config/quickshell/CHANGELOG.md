# Changelog

## [Unreleased]

### Added

- `bench/run`: benchmark of the bar (startup, idle cost, open time and CPU per dropdown) in an isolated nested compositor (`bench/env`), optionally with a QML profiler pass (`--profile`); the bar's `perf` IPC target supplies the measurements.

### Changed

- Dropdowns open faster: each bar keeps one dropdown window (1x1 and click-through while closed) instead of creating one per open.
- The CPU and memory dropdowns show their process lists right away instead of after about a second; hovering the module prepares the list.
- Usage meters and CPU core bars in the dropdowns jump to each new sample instead of animating.
- Less CPU while idle: outside the GPU dropdown, nvidia-smi polls only GPU utilization.
- The disk dropdown refreshes filesystem usage every 15 s instead of every 2 s.
- The Wi-Fi list re-sorts by signal strength 1.5 s after a change instead of on every scan update.
