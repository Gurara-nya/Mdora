# Roadmap

## Phase 0: Project Foundation

- Choose app shell: native macOS SwiftUI.
- Choose editor base: AppKit `NSTextView` wrapped in SwiftUI.
- Define file model, document state, and save behavior.
- Create design principles for reading, writing, and exporting.

## Phase 1: Markdown Editor MVP

- Open and save local Markdown files.
- Add editor and preview layout modes.
- Add editor formatting controls.
- Add block-based preview for common Markdown structures.
- Add basic theming.
- Add document outline and marker inspection.
- Add math, diagram, footnote, definition list, wiki link, and TODO-style marker recognition.
- Add reference link definitions, HTML comment recognition, current-line focus feedback, and generated table of contents insertion.
- Add front matter metadata extraction, block distribution stats, email autolinks, image references, and richer editor semantic highlighting.
- Add parser diagnostics for missing references, missing footnotes, duplicate anchors, and unclosed Markdown structures.
- Add smart return continuation for lists, task lists, ordered lists, quotes, and indentation.
- Add shared inline parsing for preview, marker analysis, and HTML export.
- Add export to HTML.

## Phase 2: Live Preview Editing

- Render headings, emphasis, links, inline code, code fences, blockquotes, lists, and images inside the editing surface.
- Keep Markdown source round-trippable.
- Add math and diagram support.
- Add robust undo and redo behavior.

## Phase 3: Desktop Polish

- File tree and recent files.
- Tabs or workspaces.
- Global search.
- Command palette.
- PDF export.
- App settings and theme marketplace.

## Phase 4: Advanced Documents

- Tables with rich editing controls.
- References, footnotes, and backlinks.
- Plugin API.
- Custom blocks.
- Optional sync layer.

## Guiding Principle

Start boring and stable, then make it magical. The hard part is not rendering Markdown; it is preserving text fidelity while the editor feels visual and calm.
