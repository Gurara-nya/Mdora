# Mdora

Mdora is a Typora-inspired Markdown editor project: local-first, distraction-free, and designed around a live editing experience where Markdown feels close to the final document.

The goal is not to copy Typora's product or interface, but to build a personal Markdown workspace with a clear architecture, open roadmap, and room for experiments.

## Current App

Mdora now starts as a native macOS SwiftUI document app.

Run it from the repository root:

```sh
swift run Mdora
```

Build it:

```sh
swift build
```

The first build includes:

- Native macOS document open/save behavior for Markdown text files.
- Editor, split, and preview layout modes.
- Native text editor with formatting commands for headings, lists, tasks, links, code, tables, images, and callouts.
- Formatting commands for strikethrough, wiki links, math blocks, diagrams, footnotes, and definition lists.
- Reference link and table-of-contents insertion commands.
- Block-based live preview for headings, paragraphs, blockquotes, callouts, lists, task lists, tables, images, code fences, diagrams, math blocks, footnotes, definition lists, HTML blocks, and front matter.
- Reference link definitions and HTML comments are parsed as visible, inspectable structures.
- Themes for system, paper, graphite, dusk, and high contrast writing modes.
- Inspector for outline, metadata, block distribution, tags, mentions, wiki links, links, automatic links, email links, images, image references, footnotes, math, code languages, diagrams, TODO-style tokens, comments, and callouts.
- Editor focus feedback with current-line highlight and richer Markdown syntax coloring for front matter, bold, italic, images, links, footnotes, URLs, emails, tables, comments, and more.
- Subtle preview update animation and animated layout changes.
- Status bar with word, character, line, link, tag, flag, and diagram counts.
- HTML export.

## Product Direction

- Local-first Markdown files, with no account required.
- Fast editor startup and smooth typing for long documents.
- Live preview editing as the core experience.
- Strong export path: HTML, PDF, and eventually DOCX.
- Themeable reading and writing modes.
- Extensible blocks for diagrams, math, tables, and code.

## Suggested Technical Path

For a first public version, avoid starting with a full WYSIWYG engine. A practical path:

1. Build a normal Markdown editor with preview.
2. Add inline live preview for headings, emphasis, links, code, math, and images.
3. Move toward a block-based editor only after the Markdown parser, file model, and export pipeline are stable.

Chosen first stack:

- Native macOS: SwiftUI.
- Package/build system: Swift Package Manager.
- Document model: SwiftUI `DocumentGroup` and `FileDocument`.
- Editor: AppKit `NSTextView` wrapped in SwiftUI for native text selection and undo.
- Parser: MdoraCore line-oriented Markdown block parser for preview, export, metadata extraction, block distribution stats, and marker detection, including GFM-style tables/tasks, callouts, math, diagrams, setext headings, indented code, footnotes, definition lists, reference links, image references, email autolinks, and HTML comments.

Future stack candidates:

- Editor engine: extend the current AppKit `NSTextView` with syntax highlighting and inline decorations.
- Markdown pipeline: unified, remark, rehype, markdown-it, or micromark.
- Rich document model later: ProseMirror, Lexical, or Milkdown.
- Export: headless browser PDF first, then Pandoc integration if needed.

## MVP Scope

- Open, edit, save `.md` files.
- Autosave with dirty-state indicator.
- Editor plus preview layout.
- Markdown syntax highlighting.
- Basic theme switcher.
- Export to HTML.
- Keyboard shortcuts for common formatting.

## Repository Status

This repository starts as planning and architecture notes. Implementation can begin once the initial shell and editor stack are selected.

## License

MIT
