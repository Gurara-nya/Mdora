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
- Block-based live preview for headings, paragraphs, blockquotes, Obsidian/GitHub callouts with custom titles and fold markers, lists, rich task lists, tables, images, code fences, diagrams, math blocks, footnotes, definition lists, HTML blocks, and YAML/TOML/JSON front matter.
- Shared inline Markdown parser for preview, marker recognition, and HTML export, covering emphasis, strong text, strikethrough, highlights, superscript, subscript, CriticMarkup review marks, inline code, links, reference links, inline images, image references, wiki links and embeds with aliases and heading/block targets, citations, resolved emoji shortcodes, keyboard tags, tags, mentions, footnotes, Markdown Extra abbreviations, raw and angle-bracket autolinks, email links, and inline math.
- Reference link definitions, abbreviation definitions, and HTML comments are parsed as visible, inspectable structures, with references, reference images, and abbreviations resolved in preview and HTML export.
- Remote images and local image files are rendered in preview, with relative paths resolved from the current Markdown file location. Standalone wiki image embeds such as `![[Assets/mockup.png|App mockup]]` use the same preview path.
- Parser source maps connect Markdown blocks back to their source line ranges for editor/preview coordination, with custom heading anchors such as `{#section-id}` and Obsidian-style block ids such as `^block-id` preserved for outlines, table of contents entries, inspection, and HTML export.
- Themes for system, paper, graphite, dusk, and high contrast writing modes.
- Writing view settings for editor font size, preview font size, preview line width, focus mode, inspector visibility, preview animation, and editor-synchronized preview scrolling.
- Inspector for outline, metadata, front matter type, block distribution, tags, mentions, wiki links, wiki embeds, block ids, custom heading anchors, abbreviations, citations, resolved emoji shortcodes, keyboard tags, links, automatic links, email links, images, image references, footnotes, highlights, superscript, subscript, CriticMarkup review marks, math, code languages, diagrams, TODO-style tokens, comments, and callouts.
- Editor focus feedback with current-line highlight and richer Markdown syntax coloring for YAML/TOML front matter, bold, italic, highlights, superscript, subscript, CriticMarkup review marks, citations, emoji shortcodes, keyboard tags, images, links, footnotes, URLs, emails, tables, comments, and more.
- Selection-aware preview feedback highlights the block that contains the editor caret and can keep that block scrolled into view.
- Smart return handling that continues lists, task lists, ordered lists, quotes, and indentation while writing.
- Live diagnostics for empty files, unclosed front matter, code fences, math blocks, missing link/image references, missing footnotes, duplicate heading anchors, and duplicate block ids.
- Optional preview update animation and animated layout changes.
- Status bar with word, character, line, caret position, reading time, link, tag, flag, diagram, focus, and diagnostic counts.
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
- Parser: MdoraCore line-oriented block parser plus shared inline parser for preview, export, metadata extraction, block distribution stats, marker detection, and diagnostics, including YAML/TOML/JSON front matter, GFM-style tables/tasks plus extended task states, Obsidian/GitHub callouts with aliases, custom titles, and fold markers, math, diagrams, setext headings, custom heading anchors, Obsidian-style block ids, indented code, footnotes, definition lists, Markdown Extra abbreviations, highlights, superscript, subscript, CriticMarkup additions/deletions/substitutions/comments/highlights, citations, resolved emoji shortcodes, keyboard tags, wiki link aliases and embeds, reference links, image references, raw and angle-bracket autolinks, email autolinks, and HTML comments.

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
