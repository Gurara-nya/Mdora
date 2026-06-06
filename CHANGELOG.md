# Changelog

# [1.0.7] - 2026-06-07 (Public)

### Added

- Added explicit preview performance degradation indicators in the status bar so users can see why fallback mode is active.

### Changed

- Refactored preview style calculation by separating base style and resolved fallback adjustments, keeping degradation reason mapping explicit.

### Fixed

- Prevented inconsistent performance messaging when large-document auto-reduction is triggered.
- Updated public release metadata (README/release-notes/asset naming) for version alignment.

# [1.0.6] - 2026-06-07 (Public)

### Added

- Added public-facing performance degradation notice in preview for large-document mode to make fallback behavior visible to users.
- Updated release metadata to align app packaging version with README, release assets, and public documentation for this release.

### Changed

- Fine-tuned public release readiness by consolidating banner compatibility and visual alignment for performance status in the preview surface.

### Fixed

- Fixed release build regressions introduced by the new performance banner code path.

# [1.0.5] - 2026-06-07 (Public)

### Added

- Added performance-mode coordination across editor and preview (`Reduce Motion`, larger document thresholds, compact visibility window scheduling).
- Expanded task token compatibility alias coverage for task markers with more variants (`-`, `_`, and localized semantic labels).
- Added public packaging metadata and display updates for 1.0.5 release readiness.

### Changed

- Tuned highlight scheduling and preview pulse cadence to reduce high-frequency UI updates under large-document conditions.
- Updated About/Settings compatibility and compatibility-signature display to improve discoverability of supported task states.

### Fixed

- Reduced preview churn in long documents by reducing visible highlight ranges and motion-sensitive rendering.

# [1.0.4] - 2026-06-07 (Public)

### Added

- Centralized task-state semantics in `TaskState` (`cycleOrder`, `nextCycleState`, `previewToggleState`, muted/struck-through flags) for consistent behavior across parser, analyzer, editor, and preview layers.
- Extended task alias compatibility for hyphen/underscore-based state tokens in task detection.
- Added large-document adaptive preview and editor performance fallback behavior to reduce frame drops in long notes.
- Added 1.0.4 release notes and README updates for public distribution assets.

### Changed

- Tuned large-document degradation thresholds for preview animations, table/diagram/math/image limits, and editor syntax highlighting windows.

### Fixed

- Reduced local-state mismatches caused by duplicate task-state extension definitions between app and core model layers.
- Improved parsing stability for unusual task marker variants used in task workflows.

# [1.0.3] - 2026-06-07 (Public)

### Added

- Added 2.0 performance preset controls in Settings for animation, table rows, diagram nodes/edges, math token length, and image resolution.
- Expanded task marker and task state compatibility for warning/blocked/review/idea/success across parser, analyzer, and editor paths.
- Added release artifact and documentation references for the 1.0.3 public publish.

### Changed

- Updated image preview rendering behavior to use resolution-aware cache keys for mixed document scenarios.
- Added background image loading APIs to reduce blocking work in preview rendering.
- Aligned HTML and in-app preview task-state styling with shared compatibility mapping.

### Fixed

- Fixed duplicated task marker constructor/alias paths in shared model helpers.
- Reduced stale cache risks for image preview rendering with varying max image size constraints.

# [1.0.2] - 2026-06-07 (Public)

### Added

- Added release-public metadata polish for changelog, README and GitHub release display consistency.
- Added compatibility fixes around extended task-state markers across model/parser/analyzer/editor flow.

### Changed

- Updated release-facing documentation and public package links.
- Prepared stable release artifact path naming for `Mdora-1.0.2-macOS.zip`.

### Fixed

- Fixed duplicated task marker constructor paths in `TaskState` and `TaskTokenKind` shared model helpers.
- Resolved task marker compatibility gaps during parsing and editor continuation operations.

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
