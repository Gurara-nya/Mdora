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
- Add richer Obsidian/GitHub callout parsing for aliases, custom titles, and fold markers.
- Add custom heading anchors for stable outline, table of contents, preview, and HTML export targets.
- Add Obsidian-style block ids for block references, preview cleanup, inspector recognition, and HTML export anchors.
- Add Markdown Extra abbreviation definitions with preview, export, and inspector support.
- Add YAML/TOML/JSON front matter metadata extraction, block distribution stats, email autolinks, image references, and richer editor semantic highlighting.
- Add parser diagnostics for missing references, missing footnotes, duplicate anchors, duplicate block ids, and unclosed Markdown structures.
- Add smart return continuation for lists, task lists, ordered lists, quotes, and indentation.
- Add shared inline parsing for preview, marker analysis, and HTML export.
- Add extended inline markers for highlights, citations, emoji shortcodes, and keyboard tags.
- Render common emoji shortcodes as emoji in preview and HTML export.
- Render Obsidian-style wiki link aliases and expose heading/block targets in HTML export metadata.
- Recognize Obsidian-style `![[...]]` embeds as separate preview, export, inspector, and status markers.
- Add Typora-style superscript and subscript markers across preview, export, inspector, and editor highlighting.
- Add CriticMarkup review marks for additions, deletions, substitutions, comments, and editorial highlights.
- Add CommonMark angle-bracket autolinks for URLs and email addresses.
- Add writing view preferences for typography, preview width, focus mode, inspector visibility, and preview animation.
- Add block source maps, caret position reporting, active preview block highlighting, and synchronized preview scrolling.
- Resolve reference links and reference images through a shared normalized definition table in preview, diagnostics, and HTML export.
- Render local image paths and standalone wiki image embeds in preview relative to the current Markdown file.
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
