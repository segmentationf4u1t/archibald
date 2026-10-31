# Changelog

## [Unreleased]

### Changed

- Quickshell is started with `MALLOC_CONF=narenas:1` (one jemalloc arena), which keeps the bar's memory about 40 % lower.
