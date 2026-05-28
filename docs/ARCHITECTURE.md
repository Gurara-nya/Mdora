# Architecture Notes

## Core Idea

Mdora should keep Markdown as the source of truth for as long as possible. Rich editing features should be layered on top of Markdown instead of replacing it too early with a proprietary document model.

The first implementation is a native macOS SwiftUI app. It uses Apple's document architecture so file ownership, open, save, duplicate, and close behavior feel familiar on macOS from the start.

## Proposed Modules

- `Sources/Mdora`: native SwiftUI app, document scene, editor, preview, export UI.
- `Sources/MdoraCore`: Markdown parser, document model, marker analyzer, and HTML renderer that can run without launching the app.

## Current Runtime Flow

1. `MarkdownDocument` owns the editable Markdown source.
2. `MarkdownParser` converts source into `ParsedMarkdownDocument`.
3. `MarkdownAnalyzer` derives outline, front matter metadata, marker indexes, diagnostics, and block distribution stats.
4. `MarkdownPreview` renders parsed blocks as native SwiftUI views.
5. `DocumentInspector` reads the same parsed document for outline, metadata, compatibility, diagnostics, block distribution, and marker recognition.
6. `MarkdownHTMLRenderer` uses the same parser for HTML export.

This keeps preview, inspection, and export aligned around one parser.

Future modules:

- `editor`: editing surface, shortcuts, selection, history.
- `markdown`: parsing, rendering, serialization, extensions.
- `preview`: document rendering, synchronized scroll, print styles.
- `workspace`: file tree, recent files, tabs, dirty state.
- `theme`: editor themes, preview themes, typography tokens.

## Editing Strategy

There are three viable levels:

1. Source editor with preview: easiest to ship and debug.
2. Source editor with inline decorations: best next step for a Typora-like feel.
3. Full rich-text block editor with Markdown serialization: most powerful, but highest risk.

The recommended path is to ship level 1, grow into level 2, and only adopt level 3 if the product needs complex block manipulation.

The current app is between level 1 and level 2: it keeps Markdown source as truth, but the editor now adds smart return continuation, and the preview already has block-level semantics for tables, callouts, tasks, code languages, diagrams, math, footnotes, definition lists, front matter, images, and document markers.

## Compatibility Surface

The parser currently recognizes:

- ATX and setext headings.
- Front matter.
- Fenced and indented code blocks.
- Diagram fences for Mermaid, Graphviz, PlantUML, sequence, and flowchart sources.
- Block and inline math markers.
- GFM-style tables and task lists.
- Blockquotes and GitHub-style callouts.
- Footnote definitions and references.
- Definition lists.
- Reference link definitions and references.
- Image reference syntax and email autolinks.
- HTML comments.
- Images, links, automatic links, wiki links, tags, mentions, and TODO-style tokens.
- Diagnostics for missing references, missing footnotes, duplicate heading anchors, and unclosed front matter, code fences, or math blocks.

## Risks

- Round-trip Markdown fidelity can break when rich editing mutates source text.
- Tables, nested lists, front matter, and mixed HTML are easy to mishandle.
- PDF export quality depends heavily on print CSS.
- Large documents need incremental parsing and careful rendering.

## Early Decisions To Make

- How far the custom parser should go before adopting a CommonMark-compatible library.
- Whether inline preview should be built inside `NSTextView` or through a richer custom text system.
- How HTML inside Markdown should be rendered and sandboxed.
- Whether the first release prioritizes writing, reading, or exporting.
