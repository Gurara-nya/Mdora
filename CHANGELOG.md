# Changelog

## [1.0.1] - 2026-06-07

### Added

- Added a dedicated Performance settings panel with high-performance mode and animation threshold controls.
- Added expanded task-token support for compatibility: warning, blocked, review, idea, success, done.
- About page now reads version/build from bundle metadata and links directly to repository, releases, and issue tracker.

### Changed

- Improved preview performance gating by limiting animated characters under large documents and large block counts.
- Tuned editor highlight scheduling and introduced fast-path highlighting when performance mode is enabled.

### Fixed

- Adjusted task-token regex generation to stay in sync with supported marker definitions automatically.

## [1.0.0] - 2026-06-07

### Added

- Native macOS document app foundation using SwiftUI and `DocumentGroup`.
- Native Markdown editor with live preview, formatting shortcuts, and split/preview/editor modes.
- Full CommonMark/Markdown feature coverage including links, tables, images, task states, diagrams, math, and code.
- Inspector dashboard for metadata, front matter, tags, block ids, footnotes, diagnostics, and parse stats.
- Preview/editor synchronization, source-map-based navigation, and responsive render pipeline.
- HTML export and shared parser pipeline for preview/diagnostics/export.
- App icon packaging and distribution bundle via local build script.

### Changed

- Release target version is aligned to `1.0.0` for the first public build.

### Notes

- This is the first public release and is suitable for day-to-day markdown note-taking and document editing in local-first workflows.
